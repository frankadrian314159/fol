;;; Benchmark pure CL simulator with extended simulation (300 time units, 1000 iterations)

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

(defun make-long-test-events ()
  "Create test events spanning to time 300."
  (let ((events '()))
    ;; Initial input values at t=0
    (push (make-event 0 'in0 nil) events)
    (push (make-event 0 'in1 t) events)
    (push (make-event 0 'in2 nil) events)
    (push (make-event 0 'in3 t) events)
    (push (make-event 0 'in4 nil) events)
    (push (make-event 0 'in5 t) events)
    (push (make-event 0 'in6 nil) events)
    (push (make-event 0 'in7 t) events)

    ;; Generate clock pulses and data changes every 10 time units
    (loop for time from 5 to 295 by 10
          for pattern = 0 then (logxor pattern #xFF)
          do (progn
               ;; Clock rising edge
               (push (make-event time 'clk t) events)
               ;; Clock falling edge
               (push (make-event (+ time 5) 'clk nil) events)
               ;; Change data inputs (alternating pattern)
               (when (zerop (mod time 20))
                 (loop for i from 0 to 7
                       do (push (make-event (+ time 2)
                                           (intern (format nil "IN~D" i))
                                           (logbitp i pattern))
                               events)))))

    (coerce (nreverse events) 'vector)))

(defun run-long-benchmark ()
  "Run 1000-iteration benchmark with extended simulation (300 time units)."
  (format t "~%=== 1000-Iteration Benchmark (Pure CL, 300 time units) ===~%")

  (let ((netlist (make-8bit-register))
        (events (make-long-test-events))
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

    (format t "Number of events: ~D~%" (length events))
    (format t "Simulation duration: 300 time units~%")

    ;; Warmup
    (format t "Warming up...~%")
    (run-simulation netlist events 300 monitored)
    (sb-ext:gc :full t)

    ;; Benchmark 1000 iterations
    (format t "Running 1000 iterations...~%")
    (let ((times '())
          (start-bytes (sb-ext:get-bytes-consed)))
      (dotimes (i 1000)
        (when (zerop (mod i 100))
          (format t "  Iteration ~D/1000~%" i))
        (let ((start-time (get-internal-run-time)))
          (run-simulation netlist events 300 monitored)
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

        (format t "~%Results (1000 iterations, pure CL, 300 time units):~%")
        (format t "  Mean:   ~,3F ms~%" (* 1000 mean))
        (format t "  Median: ~,3F ms~%" (* 1000 median))
        (format t "  Min:    ~,3F ms~%" (* 1000 min-time))
        (format t "  Max:    ~,3F ms~%" (* 1000 max-time))
        (format t "  StdDev: ~,3F ms~%" (* 1000 std-dev))
        (format t "  Total consed: ~,2F MB~%" (/ total-consed 1024.0 1024.0))
        (format t "  Per iteration: ~,2F KB~%~%" (/ total-consed 1000.0 1024.0))))))

(run-long-benchmark)
(sb-ext:quit)
