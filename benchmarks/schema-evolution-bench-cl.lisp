;;; benchmarks/schema-evolution-bench-cl.lisp
;;;
;;; Common Lisp counterpart to schema-evolution-bench.lisp.
;;;
;;; Uses standard CLOS (standard-class, mutable in-place updates).
;;; The developer must manually write update-instance-for-redefined-class :after
;;; to recover renamed slots from the property-list.  FOL generates this
;;; automatically from :alias annotations; here it is explicit boilerplate.
;;;
;;; Schema 1: <cl-device> — 6 slots: id x y z w v
;;; Schema 2: <cl-device> — 12 slots: id x y label status priority tag flags
;;;                         z-val (renamed from z) w-val (renamed from w)
;;;                         data0 data1
;;;
;;; Tests mirror schema-evolution-bench.lisp exactly:
;;;   (a) Correctness — renamed z→z-val and w→w-val survive lazy migration
;;;   (b) Cost — migration overhead, then steady-state setf cost
;;;
;;; Run with (from repo root):
;;;   sbcl --noinform --non-interactive \
;;;        --load benchmarks/schema-evolution-bench-cl.lisp

(defpackage :fol.bench.schema-cl
  (:use :cl))
(in-package :fol.bench.schema-cl)

;;; ============================================================================
;;; Parameters
;;; ============================================================================

(defparameter *n*    10000 "Number of instances per batch.")
(defparameter *reps* 20    "Repetitions for steady-state benchmarks.")

(defun elapsed-µs (start-time n-ops)
  (* 1e6 (/ (- (get-internal-real-time) start-time)
             (* (float internal-time-units-per-second) n-ops))))

;;; ============================================================================
;;; Schema 1 — 6 slots (standard-class, all mutable)
;;; ============================================================================

(defclass <cl-device> ()
  ((id  :initarg :id  :accessor cl-device-id)
   (x   :initarg :x   :accessor cl-device-x)
   (y   :initarg :y   :accessor cl-device-y)
   (z   :initarg :z)
   (w   :initarg :w)
   (v   :initarg :v)))

;;; Create the Schema-1 probe and population before redefining the class.
;;; Once Schema-2 is defined, the old initargs :z :w :v become invalid.
(defvar *probe-s1*
  (make-instance '<cl-device> :id 1 :x 10 :y 20 :z 30 :w 40 :v 50))

(defvar *s1-pop*
  (progn
    (format t "~%Creating ~A Schema-1 (<cl-device> 6-slot) instances...~%" *n*)
    (loop repeat *n*
          collect (make-instance '<cl-device>
                    :id (random 1000000)
                    :x  (random 1000) :y (random 1000)
                    :z  (random 1000) :w (random 1000)
                    :v  (random 1000)))))

;;; ----------------------------------------------------------
;;; Baseline: setf on a native slot of Schema-1 instances
;;; ----------------------------------------------------------
(format t "~%--- Schema-1 baseline: (setf slot-value) on slot x ---~%")
(let ((t0 (get-internal-real-time)))
  (dotimes (_ *reps*)
    (dolist (inst *s1-pop*)
      (setf (slot-value inst 'x) 42)))
  (format t "  ~A ops  ~,2f µs/op~%"
          (* *n* *reps*)
          (elapsed-µs t0 (* *n* *reps*))))

;;; ============================================================================
;;; Schema 2 — 12 slots
;;;
;;; z  is renamed to z-val;  w  is renamed to w-val.
;;; SBCL marks *s1-pop* instances obsolete; they migrate lazily on first access.
;;;
;;; Unlike FOL, there is no :alias annotation — the developer must write an
;;; explicit update-instance-for-redefined-class :after method.
;;; ============================================================================

(defclass <cl-device> ()
  ((id       :initarg :id)
   (x        :initarg :x)
   (y        :initarg :y)
   (label    :initarg :label)
   (status   :initarg :status)
   (priority :initarg :priority)
   (tag      :initarg :tag)
   (flags    :initarg :flags)
   (z-val    :initarg :z-val)    ; renamed from z
   (w-val    :initarg :w-val)    ; renamed from w
   (data0    :initarg :data0)
   (data1    :initarg :data1)))

;;; Manual alias recovery — equivalent to what FOL generates automatically.
;;; Without this method, z-val and w-val would be unbound on migrated instances.
(defmethod update-instance-for-redefined-class :after
    ((instance <cl-device>) added-slots discarded-slots property-list
     &rest initargs)
  (declare (ignore added-slots discarded-slots initargs))
  ;; z → z-val
  (unless (slot-boundp instance 'z-val)
    (let ((old (getf property-list 'z :not-found)))
      (unless (eq old :not-found)
        (setf (slot-value instance 'z-val) old))))
  ;; w → w-val
  (unless (slot-boundp instance 'w-val)
    (let ((old (getf property-list 'w :not-found)))
      (unless (eq old :not-found)
        (setf (slot-value instance 'w-val) old)))))

;;; ============================================================================
;;; (a) Correctness verification
;;; ============================================================================

(format t "~%=== (a) Correctness: Schema-1 instance migrated via first setf ===~%")

(let* ((probe *probe-s1*))
  ;; First touch — triggers SBCL lazy migration + :after method
  (setf (slot-value probe 'x) 999)

  (flet ((check (label got expected)
           (format t "  ~A: ~A  ~:[FAIL (expected ~A)~;OK~]~%"
                   label got (equal got expected) expected)))
    (check "id retained"             (slot-value probe 'id)              1)
    (check "x updated"               (slot-value probe 'x)               999)
    (check "y retained"              (slot-value probe 'y)               20)
    ;; Removed slot: slot-missing is signalled in standard CL (not nil like FOL).
    ;; Use handler-case to match the FOL test's intent.
    (check "v absent (slot-missing→nil)"
           (handler-case (slot-boundp probe 'v) (error () nil))
           nil)
    (check "label unbound"           (slot-boundp probe 'label)          nil)
    (check "z-val recovered from z=30" (slot-value probe 'z-val)         30)
    (check "w-val recovered from w=40" (slot-value probe 'w-val)         40)
    (check "data0 unbound"           (slot-boundp probe 'data0)          nil)
    ;; In-place mutation of overflow-equivalent slot
    (setf (slot-value probe 'z-val) 300
          (slot-value probe 'data0) 999)
    (check "z-val writable"          (slot-value probe 'z-val)           300)
    (check "w-val preserved"         (slot-value probe 'w-val)           40)
    (check "data0 writable"          (slot-value probe 'data0)           999)))

;;; ============================================================================
;;; (b) Cost
;;; ============================================================================

(format t "~%=== (b) Cost: migration overhead ===~%")
(format t "  (pass 1 = SBCL lazy migration + :after recovery; pass 2+ = pure setf)~%")

(let ((t1 (get-internal-real-time)))
  (dolist (inst *s1-pop*)                ; first touch — triggers SBCL migration
    (setf (slot-value inst 'x) 42))
  (let* ((pass1-µs (elapsed-µs t1 *n*))
         (t2 (get-internal-real-time)))
    (dolist (inst *s1-pop*)              ; already migrated
      (setf (slot-value inst 'x) 42))
    (let ((pass2-µs (elapsed-µs t2 *n*)))
      (format t "  Pass 1 (migrate + setf):   ~,2f µs/op~%" pass1-µs)
      (format t "  Pass 2 (setf only):        ~,2f µs/op~%" pass2-µs)
      (format t "  Migration overhead:        ~,2f µs/instance~%"
              (- pass1-µs pass2-µs)))))

;;; --- Schema-2 fresh instances ---
(defvar *s2-pop*
  (progn
    (format t "~%Creating ~A fresh Schema-2 (<cl-device> 12-slot) instances...~%" *n*)
    (loop repeat *n*
          collect (make-instance '<cl-device>
                    :id (random 1000000)
                    :x  (random 1000)    :y     (random 1000)
                    :label "lbl"         :status 0
                    :priority 1          :tag    0    :flags 0
                    :z-val (random 1000) :w-val (random 1000)
                    :data0 (random 1000) :data1 (random 1000)))))

(format t "~%--- Schema-2: (setf slot-value) on native slot x ---~%")
(let ((t0 (get-internal-real-time)))
  (dotimes (_ *reps*)
    (dolist (inst *s2-pop*)
      (setf (slot-value inst 'x) 42)))
  (format t "  ~A ops  ~,2f µs/op~%"
          (* *n* *reps*)
          (elapsed-µs t0 (* *n* *reps*))))

(format t "~%--- Schema-2: (setf slot-value) on renamed slot z-val ---~%")
(let ((t0 (get-internal-real-time)))
  (dotimes (_ *reps*)
    (dolist (inst *s2-pop*)
      (setf (slot-value inst 'z-val) 42)))
  (format t "  ~A ops  ~,2f µs/op~%"
          (* *n* *reps*)
          (elapsed-µs t0 (* *n* *reps*))))

(format t "~%--- Schema-1 migrated instances (post-migration, Schema-2 layout): slot x ---~%")
(let ((t0 (get-internal-real-time)))
  (dotimes (_ *reps*)
    (dolist (inst *s1-pop*)
      (setf (slot-value inst 'x) 42)))
  (format t "  ~A ops  ~,2f µs/op~%"
          (* *n* *reps*)
          (elapsed-µs t0 (* *n* *reps*))))

(format t "~%Done.~%")
