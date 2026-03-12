;;; benchmarks/multi-hop-migration-bench-cl.lisp
;;;
;;; Common Lisp counterpart to multi-hop-migration-bench.lisp.
;;;
;;; Uses standard CLOS (standard-class, mutable in-place updates).
;;;
;;; Schema evolution chain — same as the FOL benchmark:
;;;   v0  id  x  y       val            (4 slots)
;;;   v1  id  x  y       val1  (renamed from val)
;;;   v2  id  x  y2      val2  (renamed from y and val1)
;;;   v3  id  x  coord-y reading  (renamed from y2 and val2)
;;;
;;; CL approach: one update-instance-for-redefined-class :after method at v3
;;; that checks ALL possible ancestor slot names in the property-list — the
;;; flattened union of all prior alias chains.  This is the idiomatic CL idiom;
;;; it works but must be written and updated by hand whenever the schema changes.
;;;
;;; FOL generates the composed alias-map automatically from the version chain
;;; stored on the metaclass.
;;;
;;; Run with (from repo root):
;;;   sbcl --noinform --non-interactive \
;;;        --load benchmarks/multi-hop-migration-bench-cl.lisp

(defpackage :fol.bench.multi-hop-cl
  (:use :cl))
(in-package :fol.bench.multi-hop-cl)

;;; ============================================================================
;;; Parameters
;;; ============================================================================

(defparameter *n*    5000 "Instances per performance population.")
(defparameter *reps* 30   "Repetitions for steady-state benchmarks.")

(defun elapsed-µs (start-time n-ops)
  (* 1e6 (/ (- (get-internal-real-time) start-time)
             (* (float internal-time-units-per-second) n-ops))))

;;; ============================================================================
;;; Version 0 — id, x, y, val
;;; ============================================================================

(defclass <cl-sensor> ()
  ((id  :initarg :id)
   (x   :initarg :x)
   (y   :initarg :y)
   (val :initarg :val)))

(defvar *probe-v0*
  (make-instance '<cl-sensor> :id 10 :x 1 :y 777 :val 999))

(defvar *pop-s0*
  (progn
    (format t "~%Creating ~A v0 instances...~%" *n*)
    (loop repeat *n*
          collect (make-instance '<cl-sensor>
                    :id (random 1000000)
                    :x  (random 1000)
                    :y  (random 1000)
                    :val (random 1000)))))

;;; ============================================================================
;;; Version 1 — rename val → val1
;;; ============================================================================

(defclass <cl-sensor> ()
  ((id   :initarg :id)
   (x    :initarg :x)
   (y    :initarg :y)
   (val1 :initarg :val1)))

(defvar *probe-v1*
  (make-instance '<cl-sensor> :id 11 :x 1 :y 777 :val1 999))

(defvar *pop-s1*
  (progn
    (format t "Creating ~A v1 instances...~%" *n*)
    (loop repeat *n*
          collect (make-instance '<cl-sensor>
                    :id (random 1000000)
                    :x  (random 1000)
                    :y  (random 1000)
                    :val1 (random 1000)))))

;;; ============================================================================
;;; Version 2 — rename y → y2, rename val1 → val2
;;; ============================================================================

(defclass <cl-sensor> ()
  ((id   :initarg :id)
   (x    :initarg :x)
   (y2   :initarg :y2)
   (val2 :initarg :val2)))

(defvar *probe-v2*
  (make-instance '<cl-sensor> :id 12 :x 1 :y2 777 :val2 999))

(defvar *pop-s2*
  (progn
    (format t "Creating ~A v2 instances...~%" *n*)
    (loop repeat *n*
          collect (make-instance '<cl-sensor>
                    :id (random 1000000)
                    :x  (random 1000)
                    :y2 (random 1000)
                    :val2 (random 1000)))))

;;; ============================================================================
;;; Version 3 — rename y2 → coord-y, rename val2 → reading
;;;
;;; The update-instance-for-redefined-class :after method must recover values
;;; under ALL prior slot names, because SBCL fires a single non-incremental
;;; migration from birth version to current version.  The property-list
;;; contains birth-version slot names, not intermediate names.
;;;
;;; The flattened alias map across the chain is:
;;;   coord-y ← y2 (v2), y (v0/v1)
;;;   reading ← val2 (v2), val1 (v1), val (v0)
;;;
;;; This method replaces what FOL's chain-replay algorithm computes automatically.
;;; Each new rename requires a manual edit here.
;;; ============================================================================

(defclass <cl-sensor> ()
  ((id      :initarg :id)
   (x       :initarg :x)
   (coord-y :initarg :coord-y)
   (reading :initarg :reading)))

;;; Manual multi-hop alias recovery.
;;; getf uses :not-found as default so we can distinguish "key absent" from
;;; a stored nil.  We walk the alias chain explicitly (or won't work with a
;;; non-nil default sentinel).
(defun %plist-find (plist &rest keys)
  "Return the first value found for any of KEYS in PLIST, or :not-found."
  (dolist (k keys :not-found)
    (let ((v (getf plist k :not-found)))
      (unless (eq v :not-found)
        (return v)))))

(defmethod update-instance-for-redefined-class :after
    ((instance <cl-sensor>) added-slots discarded-slots property-list
     &rest initargs)
  (declare (ignore added-slots discarded-slots initargs))
  ;; coord-y: check y2 (born at v2), then y (born at v0 or v1)
  (unless (slot-boundp instance 'coord-y)
    (let ((v (%plist-find property-list 'y2 'y)))
      (unless (eq v :not-found)
        (setf (slot-value instance 'coord-y) v))))
  ;; reading: check val2 (born at v2), val1 (born at v1), val (born at v0)
  (unless (slot-boundp instance 'reading)
    (let ((v (%plist-find property-list 'val2 'val1 'val)))
      (unless (eq v :not-found)
        (setf (slot-value instance 'reading) v)))))

(defvar *pop-s3*
  (progn
    (format t "Creating ~A v3 instances...~%" *n*)
    (loop repeat *n*
          collect (make-instance '<cl-sensor>
                    :id (random 1000000)
                    :x  (random 1000)
                    :coord-y (random 1000)
                    :reading (random 1000)))))

;;; ============================================================================
;;; (a) Correctness verification
;;; ============================================================================

(format t "~%=== (a) Correctness: alias recovery across hop depths ===~%")

(flet ((check (label got expected)
         (format t "  ~A: ~A  ~:[FAIL (expected ~A)~;OK~]~%"
                 label got (equal got expected) expected))
       (migrate (inst)
         (setf (slot-value inst 'x) 1)))   ; first touch triggers SBCL migration

  ;; 1-hop: v2 → v3
  (let ((m *probe-v2*))
    (migrate m)
    (format t "  1-hop (v2 → v3):~%")
    (check "    coord-y recovered from y2=777"  (slot-value m 'coord-y) 777)
    (check "    reading recovered from val2=999" (slot-value m 'reading) 999)
    (check "    id retained"                     (slot-value m 'id)      12))

  ;; 2-hop: v1 → v3
  (let ((m *probe-v1*))
    (migrate m)
    (format t "  2-hop (v1 → v3):~%")
    (check "    coord-y recovered via y→coord-y"    (slot-value m 'coord-y) 777)
    (check "    reading recovered via val1→reading"  (slot-value m 'reading) 999)
    (check "    id retained"                          (slot-value m 'id)      11))

  ;; 3-hop: v0 → v3
  (let ((m *probe-v0*))
    (migrate m)
    (format t "  3-hop (v0 → v3):~%")
    (check "    coord-y recovered via y→coord-y"   (slot-value m 'coord-y) 777)
    (check "    reading recovered via val→reading"  (slot-value m 'reading) 999)
    (check "    id retained"                         (slot-value m 'id)      10)))

;;; ============================================================================
;;; (b) Migration cost — first-touch latency by hop depth
;;; ============================================================================

(format t "~%=== (b) Migration cost — first-touch latency (µs/op) ===~%")

(let ((t0 (get-internal-real-time)))
  (dolist (inst *pop-s2*)
    (setf (slot-value inst 'x) 42))
  (format t "  1-hop (v2 → v3):  ~,2f µs/op~%" (elapsed-µs t0 *n*)))

(let ((t0 (get-internal-real-time)))
  (dolist (inst *pop-s1*)
    (setf (slot-value inst 'x) 42))
  (format t "  2-hop (v1 → v3):  ~,2f µs/op~%" (elapsed-µs t0 *n*)))

(let ((t0 (get-internal-real-time)))
  (dolist (inst *pop-s0*)
    (setf (slot-value inst 'x) 42))
  (format t "  3-hop (v0 → v3):  ~,2f µs/op~%" (elapsed-µs t0 *n*)))

;;; ============================================================================
;;; (c) Steady-state cost — post-migration setf
;;; ============================================================================

(format t "~%=== (c) Steady-state (setf slot-value) after migration (µs/op) ===~%")

(let ((ops (* *n* *reps*)))
  (let ((t0 (get-internal-real-time)))
    (dotimes (_ *reps*) (dolist (inst *pop-s3*) (setf (slot-value inst 'x) 42)))
    (format t "  v3-native (no migration):  ~A ops  ~,2f µs/op~%" ops (elapsed-µs t0 ops)))

  (let ((t0 (get-internal-real-time)))
    (dotimes (_ *reps*) (dolist (inst *pop-s2*) (setf (slot-value inst 'x) 42)))
    (format t "  v2-migrated (was 1-hop):   ~A ops  ~,2f µs/op~%" ops (elapsed-µs t0 ops)))

  (let ((t0 (get-internal-real-time)))
    (dotimes (_ *reps*) (dolist (inst *pop-s1*) (setf (slot-value inst 'x) 42)))
    (format t "  v1-migrated (was 2-hop):   ~A ops  ~,2f µs/op~%" ops (elapsed-µs t0 ops)))

  (let ((t0 (get-internal-real-time)))
    (dotimes (_ *reps*) (dolist (inst *pop-s0*) (setf (slot-value inst 'x) 42)))
    (format t "  v0-migrated (was 3-hop):   ~A ops  ~,2f µs/op~%" ops (elapsed-µs t0 ops))))

(format t "~%Done.~%")
