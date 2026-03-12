;;; benchmarks/schema-evolution-bench.lisp
;;;
;;; Micro-benchmark: Lazy schema evolution across the T=8 overflow boundary.
;;;
;;; Schema 1: <device> — 6 native slots (all below T=8 threshold)
;;;   id, x, y, z, w, v
;;;
;;; Schema 2: <device> — 12 slots (8 native + 4 overflow)
;;;   Retained native:   id (pos 0), x (pos 1), y (pos 2)
;;;   Removed:           v
;;;   New native:        label (3), status (4), priority (5), tag (6), flags (7)
;;;   Cross-boundary (overflow + alias from Schema 1 native):
;;;     z-val :alias z  (overflow pos 0, slot pos 8)  ← crosses T=8
;;;     w-val :alias w  (overflow pos 1, slot pos 9)  ← crosses T=8
;;;   New overflow:      data0 (pos 10), data1 (pos 11)
;;;
;;; Tests:
;;;   (a) Evolution works: retained slots preserve values, removed slot absent,
;;;       alias-mapped slots (z, w) survive the native→overflow boundary crossing,
;;;       new slots start unbound, overflow read/write correct.
;;;   (b) Cost: update-slots on Schema-1 (all-native) vs Schema-2 (8-native+4-overflow),
;;;       native-slot update vs overflow-slot update, migration overhead (pass-1 vs pass-2).
;;;
;;; Run with (from repo root):
;;;   sbcl --dynamic-space-size 4096 --noinform --non-interactive \
;;;        --eval "(push (truename \"src/\") asdf:*central-registry*)" \
;;;        --load benchmarks/schema-evolution-bench.lisp

(require :asdf)
(pushnew (truename "src/") asdf:*central-registry*)
(asdf:load-asd (merge-pathnames "src/fol-compiler.asd" (truename ".")))

(asdf:load-system :fol-compiler)

(in-package :fol.compiler.persistent)

;;; ============================================================================
;;; Parameters
;;; ============================================================================

(defparameter *n*    10000 "Number of instances per batch.")
(defparameter *reps* 20    "Repetitions for steady-state benchmarks.")

(defun elapsed-µs (start-time n-ops)
  "Convert internal-time delta to µs/op."
  (* 1e6 (/ (- (get-internal-real-time) start-time)
             (* (float internal-time-units-per-second) n-ops))))

;;; ============================================================================
;;; Schema 1 — 6 native slots, all below T=8
;;; ============================================================================

(defclass <device> (<persistent-object>)
  ((id  :initarg :id)
   (x   :initarg :x)
   (y   :initarg :y)
   (z   :initarg :z)
   (w   :initarg :w)
   (v   :initarg :v))
  (:metaclass persistent-class))

;;; Create the Schema-1 population before redefining the class.
(defvar *s1-pop*
  (progn
    (format t "~%Creating ~A Schema-1 (<device> 6-slot) instances...~%" *n*)
    (loop repeat *n*
          collect (make-instance '<device>
                    :id (random 1000000)
                    :x  (random 1000) :y (random 1000)
                    :z  (random 1000) :w (random 1000)
                    :v  (random 1000)))))

;;; -------------------------------------------------------
;;; Baseline: update-slots on all-native Schema-1 instances
;;; -------------------------------------------------------
(format t "~%--- Schema-1 baseline: update-slots on native slot :x ---~%")
(let* ((t0 (get-internal-real-time)))
  (dotimes (_ *reps*)
    (dolist (inst *s1-pop*)
      (update-slots inst :x 42)))
  (format t "  ~A ops  ~,2f µs/op~%"
          (* *n* *reps*)
          (elapsed-µs t0 (* *n* *reps*))))

;;; ============================================================================
;;; Schema 2 — 12 slots (8 native + 4 overflow)
;;;
;;; SBCL marks all existing *s1-pop* instances as obsolete when this defclass
;;; executes.  Their layouts are updated lazily on the first slot access.
;;; FOL's update-instance-for-redefined-class :after method recovers z and w
;;; values via the :alias annotations even though z-val and w-val are now in
;;; the overflow zone.
;;; ============================================================================

(defclass <device> (<persistent-object>)
  ((id       :initarg :id)          ; native 0 — retained
   (x        :initarg :x)           ; native 1 — retained
   (y        :initarg :y)           ; native 2 — retained
   ;; v is REMOVED
   (label    :initarg :label)       ; native 3 — new
   (status   :initarg :status)      ; native 4 — new
   (priority :initarg :priority)    ; native 5 — new
   (tag      :initarg :tag)         ; native 6 — new
   (flags    :initarg :flags)       ; native 7 — new
   ;; Crossing the T=8 overflow boundary with alias recovery:
   (z-val    :initarg :z-val        ; overflow 0 (slot pos 8) ← z crosses T=8
             :alias z)
   (w-val    :initarg :w-val        ; overflow 1 (slot pos 9) ← w crosses T=8
             :alias w)
   ;; Pure new overflow:
   (data0    :initarg :data0)       ; overflow 2 (slot pos 10)
   (data1    :initarg :data1))      ; overflow 3 (slot pos 11)
  (:metaclass persistent-class))

;;; ============================================================================
;;; (a) Correctness verification
;;; ============================================================================

(format t "~%=== (a) Correctness: Schema-1 instance migrated via first update-slots ===~%")

(let* ((probe    (make-instance '<device>   ; fresh Schema-1 instance (before redefinition ran)
                   :id 1 :x 10 :y 20 :z 30 :w 40 :v 50))
       ;; Force SBCL lazy migration + FOL recovery by calling update-slots
       (migrated (update-slots probe :x 999)))

  (flet ((check (label got expected)
           (format t "  ~A: ~A  ~:[FAIL (expected ~A)~;OK~]~%"
                   label got (equal got expected) expected)))

    ;; Retained native slots
    (check "id retained" (slot-value migrated 'id) 1)
    (check "x updated"   (slot-value migrated 'x)  999)
    (check "y retained"  (slot-value migrated 'y)  20)

    ;; Removed slot
    (check "v absent (slot-boundp=NIL)" (slot-boundp migrated 'v) nil)

    ;; New native slots start unbound
    (check "label unbound" (slot-boundp migrated 'label) nil)

    ;; z and w cross the T=8 boundary via alias recovery
    (check "z-val recovered from z=30" (slot-value migrated 'z-val) 30)
    (check "w-val recovered from w=40" (slot-value migrated 'w-val) 40)

    ;; New overflow slots start unbound
    (check "data0 unbound" (slot-boundp migrated 'data0) nil)

    ;; Functional update of an overflow slot
    (let ((updated (update-slots migrated :z-val 300 :data0 999)))
      (check "z-val writable" (slot-value updated 'z-val) 300)
      (check "w-val preserved through overflow update"
             (slot-value updated 'w-val) 40)
      (check "data0 writable" (slot-value updated 'data0) 999))

    ;; Backward-compatible keyword routing on a Schema-2 instance
    (let* ((s2fresh (make-instance '<device>
                      :id 5 :x 1 :y 2 :z-val 100 :w-val 200))
           (via-old-kw (update-slots s2fresh :z 777)))  ; :z routes to z-val
      (check ":z keyword routes to z-val" (slot-value via-old-kw 'z-val) 777))))

;;; ============================================================================
;;; (b) Cost
;;; ============================================================================

;;; --- Migration overhead: pass 1 (migrate+update) vs pass 2 (update only) ---
(format t "~%=== (b) Cost: migration overhead ===~%")
(format t "  (pass 1 = SBCL lazy migration + FOL update-slots; pass 2+ = pure update-slots)~%")

(let* ((t1 (get-internal-real-time)))
  (dolist (inst *s1-pop*)                ; first touch — triggers SBCL migration
    (update-slots inst :x 42))
  (let* ((pass1-µs (elapsed-µs t1 *n*))
         (t2 (get-internal-real-time)))
    (dolist (inst *s1-pop*)              ; already migrated
      (update-slots inst :x 42))
    (let ((pass2-µs (elapsed-µs t2 *n*)))
      (format t "  Pass 1 (migrate + update): ~,2f µs/op~%" pass1-µs)
      (format t "  Pass 2 (update only):      ~,2f µs/op~%" pass2-µs)
      (format t "  Migration overhead:        ~,2f µs/instance~%"
              (- pass1-µs pass2-µs)))))

;;; --- Schema-2 fresh instances: native vs overflow update ---
(defvar *s2-pop*
  (progn
    (format t "~%Creating ~A fresh Schema-2 (<device> 12-slot) instances...~%" *n*)
    (loop repeat *n*
          collect (make-instance '<device>
                    :id (random 1000000)
                    :x  (random 1000)  :y     (random 1000)
                    :label "lbl"       :status 0
                    :priority 1        :tag    0    :flags 0
                    :z-val (random 1000) :w-val (random 1000)
                    :data0 (random 1000) :data1 (random 1000)))))

(format t "~%--- Schema-2: update-slots on native slot :x (no overflow rebuild) ---~%")
(let* ((t0 (get-internal-real-time)))
  (dotimes (_ *reps*)
    (dolist (inst *s2-pop*)
      (update-slots inst :x 42)))
  (format t "  ~A ops  ~,2f µs/op~%"
          (* *n* *reps*)
          (elapsed-µs t0 (* *n* *reps*))))

(format t "~%--- Schema-2: update-slots on overflow slot :z-val (overflow trie rebuild) ---~%")
(let* ((t0 (get-internal-real-time)))
  (dotimes (_ *reps*)
    (dolist (inst *s2-pop*)
      (update-slots inst :z-val 42)))
  (format t "  ~A ops  ~,2f µs/op~%"
          (* *n* *reps*)
          (elapsed-µs t0 (* *n* *reps*))))

(format t "~%--- Schema-2: update-slots via backward-compat alias :z -> z-val ---~%")
(let* ((t0 (get-internal-real-time)))
  (dotimes (_ *reps*)
    (dolist (inst *s2-pop*)
      (update-slots inst :z 42)))
  (format t "  ~A ops  ~,2f µs/op~%"
          (* *n* *reps*)
          (elapsed-µs t0 (* *n* *reps*))))

(format t "~%--- Schema-1 migrated instances (post-migration, Schema-2 layout): native :x ---~%")
(let* ((t0 (get-internal-real-time)))
  (dotimes (_ *reps*)
    (dolist (inst *s1-pop*)             ; now Schema-2 layout
      (update-slots inst :x 42)))
  (format t "  ~A ops  ~,2f µs/op~%"
          (* *n* *reps*)
          (elapsed-µs t0 (* *n* *reps*))))

(format t "~%Done.~%")
