;;; Benchmark transpiled FOL simulator (fol-code/lsim.lisp)
;;; Runs the 8-bit register simulation 1000 times
;;; Updated for cl-utils (native CL data structures)

(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

;; Create simulator package with hybrid helper functions
(defpackage :fol-sim
  (:use :cl)
  (:shadow assoc map reduce)  ; Will define CL-compatible versions
  (:import-from :fol.compiler.cl-utils
                make-cl-vector make-cl-dict make-cl-set)
  (:shadowing-import-from :fol.compiler.mutable
                atom)
  (:import-from :fol.compiler.mutable
                deref reset! swap! compare-and-set!
                <atom> <atom>? ref <ref> <ref>?)
  (:import-from :fol.compiler.primitives
                truthy? falsy? make))

(in-package :fol-sim)
(sb-ext:unlock-package :cl)

;; Local CL-compatible helper functions for transpiled code
(defun get (dict key &optional default)
  "Get value from hash-table."
  (gethash key dict default))

(defun assoc (dict key value &rest kvs)
  "Add/update key-value pairs in hash-table (returns new hash-table)."
  (let ((new-ht (make-hash-table :test 'eql)))
    (maphash (lambda (k v) (setf (gethash k new-ht) v)) dict)
    (setf (gethash key new-ht) value)
    (loop for (k v) on kvs by #'cddr do
      (setf (gethash k new-ht) v))
    new-ht))

(defun update (dict key updater-fn)
  "Update a key by applying updater-fn to its current value."
  (let ((current-val (gethash key dict))
        (new-ht (make-hash-table :test 'eql)))
    (maphash (lambda (k v) (setf (gethash k new-ht) v)) dict)
    (setf (gethash key new-ht) (funcall updater-fn current-val))
    new-ht))

(defun map (fn seq)
  "Map function over sequence."
  (cl:map 'vector fn seq))

(defun reduce (fn initial-value seq)
  "Reduce sequence with function and initial value."
  (cl:reduce fn seq :initial-value initial-value))

(defun filter (pred seq)
  "Filter sequence by predicate."
  (cl:remove-if-not pred seq))

(defun concat (vec1 vec2)
  "Concatenate two vectors."
  (concatenate 'vector vec1 vec2))

(defun empty? (coll)
  "Check if collection is empty."
  (zerop (length coll)))

(defun first (seq)
  "Get first element of sequence."
  (when (cl:plusp (length seq))
    (elt seq 0)))

(defun rest (seq)
  "Get all but first element of sequence."
  (when (> (length seq) 1)
    (subseq seq 1)))

;; Load the transpiled simulator
(load "fol-code/lsim.lisp")
(load "fol-code/register-8bit.lisp")

;; Helper to create event (native CL hash-table)
(defun make-event (time node value)
  (make-cl-dict :time time :node node :value value))

(defun run-one-simulation ()
  "Run one instance of the 8-bit register simulation."
  ;; Reset simulation context (native CL data structures)
  (setf *sim-context*
        (atom (make-cl-dict
               :monitored (make-cl-set)
               :events (make-cl-vector)
               :history (make-cl-dict))))

  ;; Monitor output bits
  (funcall #'monitor 'out0 'out1 'out2 'out3 'out4 'out5 'out6 'out7)

  ;; Set up test events
  (funcall #'events
    (make-event 0 'in0 nil) (make-event 0 'in1 t)
    (make-event 0 'in2 nil) (make-event 0 'in3 t)
    (make-event 0 'in4 nil) (make-event 0 'in5 t)
    (make-event 0 'in6 nil) (make-event 0 'in7 t)
    (make-event 5 'clk t)
    (make-event 10 'clk nil)
    (make-event 15 'in0 t) (make-event 15 'in1 nil)
    (make-event 15 'in2 t) (make-event 15 'in3 nil)
    (make-event 15 'in4 t) (make-event 15 'in5 nil)
    (make-event 15 'in6 t) (make-event 15 'in7 nil)
    (make-event 20 'clk t)
    (make-event 25 'clk nil))

  ;; Run simulation
  (funcall #'run 'test-register-8bit 30))

(format t "~%=== Benchmarking Transpiled FOL Simulator ===~%")
(format t "Running 1000 simulations...~%~%")

;; Warm-up runs
(dotimes (i 10)
  (run-one-simulation))

(format t "Warm-up complete. Starting timed runs...~%~%")

;; Force GC before benchmark
(sb-ext:gc :full t)

(let ((start-time (get-internal-real-time))
      (start-run-time (get-internal-run-time))
      (initial-bytes (sb-ext:dynamic-space-size)))

  ;; Run 1000 simulations
  (dotimes (i 1000)
    (when (zerop (mod i 100))
      (format t "Progress: ~A/1000~%" i))
    (run-one-simulation))

  (let* ((end-time (get-internal-real-time))
         (end-run-time (get-internal-run-time))
         (final-bytes (sb-ext:dynamic-space-size))
         (real-seconds (/ (- end-time start-time)
                         internal-time-units-per-second))
         (run-seconds (/ (- end-run-time start-run-time)
                        internal-time-units-per-second))
         (bytes-allocated (- final-bytes initial-bytes))
         (mb-allocated (/ bytes-allocated 1048576.0)))

    (format t "~%=== Results ===~%")
    (format t "Total real time:     ~,3F seconds~%" real-seconds)
    (format t "Total CPU time:      ~,3F seconds~%" run-seconds)
    (format t "Average per run:     ~,3F ms (real time)~%"
            (* 1000 (/ real-seconds 1000)))
    (format t "Average per run:     ~,3F ms (CPU time)~%"
            (* 1000 (/ run-seconds 1000)))
    (format t "Memory allocated:    ~,2F MB~%" mb-allocated)
    (format t "Memory per run:      ~,2F KB~%"
            (/ mb-allocated 1000.0 1024))
    (format t "~%")))

(sb-ext:quit)
