;;; Benchmark hand-written CL simulator (lsim.lisp)
;;; Runs the 8-bit register simulation 1000 times
;;; Updated for cl-utils (native CL data structures)

(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

;; Unlock CL package to allow lsim to define *modules*
(sb-ext:unlock-package :cl)

;; Load the hand-written simulator
(load "lsim.lisp")

(defun make-event (time node value)
  "Create event as native CL hash-table."
  (let ((ht (make-hash-table :test 'eql)))
    (setf (gethash :time ht) time)
    (setf (gethash :node ht) node)
    (setf (gethash :value ht) value)
    ht))

(defun run-one-simulation ()
  "Run one instance of the 8-bit register simulation."
  ;; Reset simulation context using property list (as in handwritten lsim.lisp)
  (setf lsim::*sim-context*
        (list :monitored nil :events nil :history nil))

  ;; Monitor output bits
  (lsim::monitor 'out0 'out1 'out2 'out3 'out4 'out5 'out6 'out7)

  ;; Set up test events (create as vector of hash-tables)
  (lsim::events
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
  (lsim::run 'test-register-8bit 30))

(format t "~%=== Benchmarking Hand-Written CL Simulator ===~%")
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
