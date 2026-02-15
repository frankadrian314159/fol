;;; Benchmark pure CL simulator with 8-bit register (comparable to FOL benchmarks)

(require 'asdf)
(asdf:load-system :alexandria)
(load "lsim-pure-cl.lisp")

(in-package :lsim-pure-cl)

;;; ===========================================================================
;;; D-Latch Component
;;; ===========================================================================

(defun make-d-latch (name clk-node d-node q-node)
  "Create a D-latch component."
  (let ((connections (make-hash-table :test 'eq))
        (delays (make-hash-table :test 'eq)))
    ;; Connections
    (setf (gethash :clk connections) clk-node)
    (setf (gethash :d connections) d-node)
    (setf (gethash :q connections) q-node)

    ;; Delays: CLK and D changes affect Q
    (let ((clk-delays (make-hash-table :test 'eq))
          (d-delays (make-hash-table :test 'eq)))
      (setf (gethash :q clk-delays) 3)  ; clk->q delay = 3
      (setf (gethash :q d-delays) 4)    ; d->q delay = 4
      (setf (gethash :clk delays) clk-delays)
      (setf (gethash :d delays) d-delays))

    ;; Logic: latch holds previous value when CLK low, captures D when CLK high
    (make-component name
                    (vector :clk :d)
                    (vector :q)
                    connections
                    delays
                    (lambda (inputs)
                      (let ((out-states (make-hash-table :test 'eq))
                            (clk (gethash :clk inputs))
                            (d (gethash :d inputs))
                            (prev-q (gethash :prev-q inputs)))  ; internal state
                        (setf (gethash :prev-q out-states)
                              (if clk d prev-q))
                        (setf (gethash :q out-states)
                              (if clk d prev-q))
                        out-states)))))

;;; ===========================================================================
;;; 8-Bit Register (8 D-latches)
;;; ===========================================================================

(defun make-8bit-register ()
  "Create an 8-bit register (8 D-latches sharing a clock)."
  (vector
   (make-d-latch 'latch0 'clk 'in0 'out0)
   (make-d-latch 'latch1 'clk 'in1 'out1)
   (make-d-latch 'latch2 'clk 'in2 'out2)
   (make-d-latch 'latch3 'clk 'in3 'out3)
   (make-d-latch 'latch4 'clk 'in4 'out4)
   (make-d-latch 'latch5 'clk 'in5 'out5)
   (make-d-latch 'latch6 'clk 'in6 'out6)
   (make-d-latch 'latch7 'clk 'in7 'out7)))

(defun make-test-events ()
  "Create test events for 8-bit register (same as FOL benchmark)."
  (vector
   ;; Initial input values at t=0
   (make-event 0 'in0 nil) (make-event 0 'in1 t)
   (make-event 0 'in2 nil) (make-event 0 'in3 t)
   (make-event 0 'in4 nil) (make-event 0 'in5 t)
   (make-event 0 'in6 nil) (make-event 0 'in7 t)
   ;; Clock pulses
   (make-event 5 'clk t) (make-event 10 'clk nil)
   ;; Change inputs at t=15
   (make-event 15 'in0 t) (make-event 15 'in1 nil)
   (make-event 15 'in2 t) (make-event 15 'in3 nil)
   (make-event 15 'in4 t) (make-event 15 'in5 nil)
   (make-event 15 'in6 t) (make-event 15 'in7 nil)
   ;; Clock pulses
   (make-event 20 'clk t) (make-event 25 'clk nil)))

(defun run-register-benchmark ()
  "Run 100-iteration benchmark of 8-bit register (comparable to FOL benchmarks)."
  (format t "~%=== 100-Iteration Benchmark (Pure CL, 8-bit Register) ===~%")

  (let ((netlist (make-8bit-register))
        (events (make-test-events))
        (monitored (let ((m (make-hash-table :test 'eq)))
                     (setf (gethash 'out0 m) t)
                     (setf (gethash 'out1 m) t)
                     (setf (gethash 'out2 m) t)
                     (setf (gethash 'out3 m) t)
                     (setf (gethash 'out4 m) t)
                     (setf (gethash 'out5 m) t)
                     (setf (gethash 'out6 m) t)
                     (setf (gethash 'out7 m) t)
                     m)))

    ;; Warmup
    (format t "Warming up...~%")
    (run-simulation netlist events 30 monitored)
    (sb-ext:gc :full t)

    ;; Benchmark 100 iterations
    (format t "Running 100 iterations...~%")
    (let ((times '())
          (start-bytes (sb-ext:get-bytes-consed)))
      (dotimes (i 100)
        (when (zerop (mod i 10))
          (format t "  Iteration ~D/100~%" i))
        (let ((start-time (get-internal-run-time)))
          (run-simulation netlist events 30 monitored)
          (let ((elapsed (/ (- (get-internal-run-time) start-time)
                           internal-time-units-per-second)))
            (push elapsed times))))

      (let* ((end-bytes (sb-ext:get-bytes-consed))
             (total-consed (- end-bytes start-bytes))
             (sorted-times (sort (copy-list times) #'<))
             (mean (/ (reduce #'+ sorted-times) (length sorted-times)))
             (median (nth (floor (length sorted-times) 2) sorted-times))
             (min-time (first sorted-times))
             (max-time (first (last sorted-times)))
             (std-dev (sqrt (/ (reduce #'+ (mapcar (lambda (x) (expt (- x mean) 2))
                                                   sorted-times))
                              (length sorted-times)))))

        (format t "~%Results (100 iterations, pure CL, 8-bit register):~%")
        (format t "  Mean:   ~,3F ms~%" (* 1000 mean))
        (format t "  Median: ~,3F ms~%" (* 1000 median))
        (format t "  Min:    ~,3F ms~%" (* 1000 min-time))
        (format t "  Max:    ~,3F ms~%" (* 1000 max-time))
        (format t "  StdDev: ~,3F ms~%" (* 1000 std-dev))
        (format t "  Total consed: ~,2F MB~%" (/ total-consed 1024.0 1024.0))
        (format t "  Per iteration: ~,2F KB~%~%" (/ total-consed 100.0 1024.0))))))

(run-register-benchmark)
(sb-ext:quit)
