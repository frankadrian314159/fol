;;; benchmarks/multi-hop-migration-bench.lisp
;;;
;;; Benchmark: single-hop vs. multi-hop lazy schema migration.
;;;
;;; Schema evolution chain for <sensor> (all slots native, all <= T=8):
;;;
;;;   v0  id  x  y       val            (4 slots)
;;;   v1  id  x  y       val1 :alias val
;;;   v2  id  x  y2 :alias y  val2 :alias val1
;;;   v3  id  x  coord-y :alias y2  reading :alias val2
;;;
;;; An instance born at v0 and first touched at v3 requires a 3-hop chain:
;;;   reading → val2 → val1 → val   (current alias + 2 intermediate snapshots)
;;;   coord-y → y2   → y            (current alias + 1 intermediate snapshot)
;;;
;;; Populations (each born and held untouched until the benchmark fires):
;;;   *pop-s0*  —  born at v0  →  3-hop migration to v3
;;;   *pop-s1*  —  born at v1  →  2-hop migration to v3
;;;   *pop-s2*  —  born at v2  →  1-hop migration to v3  (single-hop baseline)
;;;   *pop-s3*  —  born at v3  →  native (no migration)
;;;
;;; Probe instances (known values: coord-y-val=777, reading-val=999 per version):
;;;   *probe-v0*  born at v0 with  y=777   val=999
;;;   *probe-v1*  born at v1 with  y=777   val1=999
;;;   *probe-v2*  born at v2 with  y2=777  val2=999
;;;
;;; Tests:
;;;   (a) Correctness — each probe recovers coord-y=777, reading=999 after migration
;;;   (b) Migration cost — first-touch µs/op by hop depth
;;;   (c) Steady-state — post-migration update-slots cost is equal for all populations
;;;
;;; Run with (from repo root):
;;;   sbcl --dynamic-space-size 4096 --noinform --non-interactive \
;;;        --eval "(push (truename \"src/\") asdf:*central-registry*)" \
;;;        --load benchmarks/multi-hop-migration-bench.lisp

(require :asdf)
(pushnew (truename "src/") asdf:*central-registry*)
(asdf:load-asd (merge-pathnames "src/fol-compiler.asd" (truename ".")))
(asdf:load-system :fol-compiler)

(in-package :fol.compiler.persistent)

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

(defclass <sensor> (<persistent-object>)
  ((id  :initarg :id)
   (x   :initarg :x)
   (y   :initarg :y)
   (val :initarg :val))
  (:metaclass persistent-class))

;;; Probe with known values — born at v0, untouched until v3 correctness check
(defvar *probe-v0*
  (make-instance '<sensor> :id 10 :x 1 :y 777 :val 999))

;;; Performance population — born at v0, untouched until migration cost benchmark
(defvar *pop-s0*
  (progn
    (format t "~%Creating ~A v0 instances...~%" *n*)
    (loop repeat *n*
          collect (make-instance '<sensor>
                    :id (random 1000000)
                    :x  (random 1000)
                    :y  (random 1000)
                    :val (random 1000)))))

;;; ============================================================================
;;; Version 1 — rename val → val1
;;; ============================================================================

(defclass <sensor> (<persistent-object>)
  ((id   :initarg :id)
   (x    :initarg :x)
   (y    :initarg :y)
   (val1 :initarg :val1 :alias val))
  (:metaclass persistent-class))

;;; Probe born at v1 — y is retained natively; val1 carries the known reading value
(defvar *probe-v1*
  (make-instance '<sensor> :id 11 :x 1 :y 777 :val1 999))

(defvar *pop-s1*
  (progn
    (format t "Creating ~A v1 instances...~%" *n*)
    (loop repeat *n*
          collect (make-instance '<sensor>
                    :id (random 1000000)
                    :x  (random 1000)
                    :y  (random 1000)
                    :val1 (random 1000)))))

;;; ============================================================================
;;; Version 2 — rename y → y2, rename val1 → val2
;;; ============================================================================

(defclass <sensor> (<persistent-object>)
  ((id   :initarg :id)
   (x    :initarg :x)
   (y2   :initarg :y2   :alias y)
   (val2 :initarg :val2 :alias val1))
  (:metaclass persistent-class))

;;; Probe born at v2 — uses the current slot names at birth
(defvar *probe-v2*
  (make-instance '<sensor> :id 12 :x 1 :y2 777 :val2 999))

(defvar *pop-s2*
  (progn
    (format t "Creating ~A v2 instances...~%" *n*)
    (loop repeat *n*
          collect (make-instance '<sensor>
                    :id (random 1000000)
                    :x  (random 1000)
                    :y2 (random 1000)
                    :val2 (random 1000)))))

;;; ============================================================================
;;; Version 3 — rename y2 → coord-y, rename val2 → reading
;;;
;;; At this point all prior populations become obsolete.  Their instances will
;;; be migrated lazily by SBCL on first slot access; our :after method replays
;;; the version chain to recover renamed values.
;;; ============================================================================

(defclass <sensor> (<persistent-object>)
  ((id      :initarg :id)
   (x       :initarg :x)
   (coord-y :initarg :coord-y :alias y2)
   (reading :initarg :reading :alias val2))
  (:metaclass persistent-class))

(defvar *pop-s3*
  (progn
    (format t "Creating ~A v3 instances...~%" *n*)
    (loop repeat *n*
          collect (make-instance '<sensor>
                    :id (random 1000000)
                    :x  (random 1000)
                    :coord-y (random 1000)
                    :reading (random 1000)))))

;;; ============================================================================
;;; (a) Correctness verification
;;;
;;; Each probe is first-touched here; update-slots triggers SBCL lazy migration
;;; which calls our update-instance-for-redefined-class :after method.
;;; Expected: coord-y=777 and reading=999 regardless of hop depth.
;;; ============================================================================

(format t "~%=== (a) Correctness: alias recovery across hop depths ===~%")

(flet ((check (label got expected)
         (format t "  ~A: ~A  ~:[FAIL (expected ~A)~;OK~]~%"
                 label got (equal got expected) expected))
       (migrate (inst)
         (update-slots inst :x 1)))  ; first touch triggers SBCL migration

  ;; 1-hop: v2 → v3.  coord-y :alias y2,  reading :alias val2.
  ;; property-list from SBCL = {y2: 777, val2: 999}.
  ;; Chain traversal: composed stays {coord-y→y2, reading→val2} (no snapshots >2).
  (let ((m (migrate *probe-v2*)))
    (format t "  1-hop (v2 → v3):~%")
    (check "    coord-y recovered from y2=777"   (slot-value m 'coord-y) 777)
    (check "    reading recovered from val2=999"  (slot-value m 'reading) 999)
    (check "    id retained"                      (slot-value m 'id)      12))

  ;; 2-hop: v1 → v3.  reading → val2 → val1.  coord-y → y2 → y.
  ;; property-list = {y: 777, val1: 999}.
  ;; Compose through snapshot(2) {val2→val1, y2→y}:
  ;;   reading→val2 + val2→val1  ⇒  reading→val1
  ;;   coord-y→y2   + y2→y       ⇒  coord-y→y
  (let ((m (migrate *probe-v1*)))
    (format t "  2-hop (v1 → v3):~%")
    (check "    coord-y recovered (y→y2→coord-y chain)" (slot-value m 'coord-y) 777)
    (check "    reading recovered (val1→val2→reading)"  (slot-value m 'reading) 999)
    (check "    id retained"                             (slot-value m 'id)      11))

  ;; 3-hop: v0 → v3.  reading → val2 → val1 → val.  coord-y → y2 → y (same).
  ;; property-list = {y: 777, val: 999}.
  ;; Compose through snapshot(2) {val2→val1, y2→y}  →  reading→val1, coord-y→y
  ;; Compose through snapshot(1) {val1→val}           →  reading→val,  coord-y→y
  (let ((m (migrate *probe-v0*)))
    (format t "  3-hop (v0 → v3):~%")
    (check "    coord-y recovered (y→y2→coord-y, 2 snaps)" (slot-value m 'coord-y) 777)
    (check "    reading recovered (val→val1→val2→reading)"  (slot-value m 'reading) 999)
    (check "    id retained"                                  (slot-value m 'id)      10)))

;;; ============================================================================
;;; (b) Migration cost — first-touch latency by hop depth
;;;
;;; Each population is untouched; calling update-slots fires SBCL migration +
;;; our chain-replay :after method for each instance.
;;; ============================================================================

(format t "~%=== (b) Migration cost — first-touch latency (µs/op) ===~%")

(let ((t0 (get-internal-real-time)))
  (dolist (inst *pop-s2*)
    (update-slots inst :x 42))
  (format t "  1-hop (v2 → v3):  ~,2f µs/op~%" (elapsed-µs t0 *n*)))

(let ((t0 (get-internal-real-time)))
  (dolist (inst *pop-s1*)
    (update-slots inst :x 42))
  (format t "  2-hop (v1 → v3):  ~,2f µs/op~%" (elapsed-µs t0 *n*)))

(let ((t0 (get-internal-real-time)))
  (dolist (inst *pop-s0*)
    (update-slots inst :x 42))
  (format t "  3-hop (v0 → v3):  ~,2f µs/op~%" (elapsed-µs t0 *n*)))

;;; ============================================================================
;;; (c) Steady-state cost — post-migration update-slots
;;;
;;; All populations are now at the v3 layout.  update-slots cost should be
;;; uniform regardless of birth version.
;;; ============================================================================

(format t "~%=== (c) Steady-state update-slots after migration (µs/op) ===~%")

(let ((ops (* *n* *reps*)))

  (let ((t0 (get-internal-real-time)))
    (dotimes (_ *reps*) (dolist (inst *pop-s3*) (update-slots inst :x 42)))
    (format t "  v3-native (no migration):  ~A ops  ~,2f µs/op~%" ops (elapsed-µs t0 ops)))

  (let ((t0 (get-internal-real-time)))
    (dotimes (_ *reps*) (dolist (inst *pop-s2*) (update-slots inst :x 42)))
    (format t "  v2-migrated (was 1-hop):   ~A ops  ~,2f µs/op~%" ops (elapsed-µs t0 ops)))

  (let ((t0 (get-internal-real-time)))
    (dotimes (_ *reps*) (dolist (inst *pop-s1*) (update-slots inst :x 42)))
    (format t "  v1-migrated (was 2-hop):   ~A ops  ~,2f µs/op~%" ops (elapsed-µs t0 ops)))

  (let ((t0 (get-internal-real-time)))
    (dotimes (_ *reps*) (dolist (inst *pop-s0*) (update-slots inst :x 42)))
    (format t "  v0-migrated (was 3-hop):   ~A ops  ~,2f µs/op~%" ops (elapsed-µs t0 ops))))

(format t "~%Done.~%")
