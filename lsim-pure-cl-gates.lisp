;;; Pure CL simulator with 8-bit register built from NAND and NOT gates

(require 'asdf)
(asdf:load-system :alexandria)
(load "lsim-pure-cl.lisp")

(in-package :lsim-pure-cl)

;;; ===========================================================================
;;; Primitive Logic Gates
;;; ===========================================================================

(defun make-nand-gate (name in1-node in2-node out-node)
  "Create a NAND gate component."
  (let ((connections (make-hash-table :test 'eq))
        (delays (make-hash-table :test 'eq)))
    ;; Connections
    (setf (gethash :in1 connections) in1-node)
    (setf (gethash :in2 connections) in2-node)
    (setf (gethash :out connections) out-node)

    ;; Delays: both inputs affect output with delay 1
    (let ((in1-delays (make-hash-table :test 'eq))
          (in2-delays (make-hash-table :test 'eq)))
      (setf (gethash :out in1-delays) 1)
      (setf (gethash :out in2-delays) 1)
      (setf (gethash :in1 delays) in1-delays)
      (setf (gethash :in2 delays) in2-delays))

    ;; Logic: NAND(a, b) = NOT(AND(a, b))
    (make-component name
                    (vector :in1 :in2)
                    (vector :out)
                    connections
                    delays
                    (lambda (inputs)
                      (let ((out-states (make-hash-table :test 'eq)))
                        (setf (gethash :out out-states)
                              (not (and (gethash :in1 inputs)
                                       (gethash :in2 inputs))))
                        out-states)))))

(defun make-not-gate (name in-node out-node)
  "Create a NOT gate component."
  (let ((connections (make-hash-table :test 'eq))
        (delays (make-hash-table :test 'eq)))
    ;; Connections
    (setf (gethash :in connections) in-node)
    (setf (gethash :out connections) out-node)

    ;; Delays
    (let ((in-delays (make-hash-table :test 'eq)))
      (setf (gethash :out in-delays) 1)
      (setf (gethash :in delays) in-delays))

    ;; Logic: NOT(a)
    (make-component name
                    (vector :in)
                    (vector :out)
                    connections
                    delays
                    (lambda (inputs)
                      (let ((out-states (make-hash-table :test 'eq)))
                        (setf (gethash :out out-states)
                              (not (gethash :in inputs)))
                        out-states)))))

;;; ===========================================================================
;;; D-Latch Built from NAND Gates
;;; ===========================================================================
;;;
;;; A D-latch can be built from 4 NAND gates:
;;;   D ----NAND---- S
;;;         |        |
;;;        CLK    NAND------ Q
;;;         |        |
;;;   D-NOT-NAND---- R
;;;
;;; When CLK=1: S=NOT(D), R=D, so SR latch stores D
;;; When CLK=0: S=1, R=1, so SR latch holds state

(defun make-d-latch-from-gates (name-prefix clk-node d-node q-node)
  "Create a D-latch from NAND gates. Returns vector of gate components."
  (let ((components '())
        ;; Internal node names (using symbols with unique prefixes)
        (d-not (intern (format nil "~A-D-NOT" name-prefix)))
        (s (intern (format nil "~A-S" name-prefix)))
        (r (intern (format nil "~A-R" name-prefix)))
        (q-not (intern (format nil "~A-Q-NOT" name-prefix))))

    ;; NOT gate for D
    (push (make-not-gate (intern (format nil "~A-NOT-D" name-prefix))
                        d-node d-not)
          components)

    ;; Upper NAND: S = NAND(D, CLK)
    (push (make-nand-gate (intern (format nil "~A-NAND-S" name-prefix))
                         d-node clk-node s)
          components)

    ;; Lower NAND: R = NAND(D-NOT, CLK)
    (push (make-nand-gate (intern (format nil "~A-NAND-R" name-prefix))
                         d-not clk-node r)
          components)

    ;; SR latch (cross-coupled NAND gates)
    ;; Q = NAND(S, Q-NOT)
    (push (make-nand-gate (intern (format nil "~A-NAND-Q" name-prefix))
                         s q-not q-node)
          components)

    ;; Q-NOT = NAND(R, Q)
    (push (make-nand-gate (intern (format nil "~A-NAND-Q-NOT" name-prefix))
                         r q-node q-not)
          components)

    (coerce (nreverse components) 'vector)))

;;; ===========================================================================
;;; 8-Bit Register Built from NAND/NOT Gates
;;; ===========================================================================

(defun make-8bit-register-from-gates ()
  "Create an 8-bit register built from NAND and NOT gates."
  (let ((components '()))
    ;; Create 8 D-latches, each built from 5 gates
    (loop for i from 0 to 7
          do (let* ((latch-name (intern (format nil "LATCH~D" i)))
                    (d-node (intern (format nil "IN~D" i)))
                    (q-node (intern (format nil "OUT~D" i)))
                    (latch-gates (make-d-latch-from-gates latch-name 'clk d-node q-node)))
               ;; Add all gates from this latch to components
               (loop for gate across latch-gates
                     do (push gate components))))

    (coerce (nreverse components) 'vector)))

;;; ===========================================================================
;;; Test Events
;;; ===========================================================================

(defun make-test-events-gates ()
  "Create test events for gate-level 8-bit register."
  (vector
   ;; Initial input values at t=0
   (make-event 0 'in0 nil) (make-event 0 'in1 t)
   (make-event 0 'in2 nil) (make-event 0 'in3 t)
   (make-event 0 'in4 nil) (make-event 0 'in5 t)
   (make-event 0 'in6 nil) (make-event 0 'in7 t)
   ;; Clock pulses
   (make-event 10 'clk t) (make-event 20 'clk nil)
   ;; Change inputs at t=25
   (make-event 25 'in0 t) (make-event 25 'in1 nil)
   (make-event 25 'in2 t) (make-event 25 'in3 nil)
   (make-event 25 'in4 t) (make-event 25 'in5 nil)
   (make-event 25 'in6 t) (make-event 25 'in7 nil)
   ;; Clock pulses
   (make-event 30 'clk t) (make-event 40 'clk nil)))

(defun make-long-test-events-gates ()
  "Create test events spanning to time 300 for gate-level register."
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
    (loop for time from 10 to 295 by 10
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

;;; ===========================================================================
;;; Benchmark
;;; ===========================================================================

(defun run-gates-benchmark ()
  "Run 1000-iteration benchmark with gate-level 8-bit register."
  (format t "~%=== 1000-Iteration Benchmark (Pure CL, Gate-Level Register, 300 time units) ===~%")

  (let ((netlist (make-8bit-register-from-gates))
        (events (make-long-test-events-gates))
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

    (format t "Number of components: ~D~%" (length netlist))
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

        (format t "~%Results (1000 iterations, gate-level register):~%")
        (format t "  Mean:   ~,3F ms~%" (* 1000 mean))
        (format t "  Median: ~,3F ms~%" (* 1000 median))
        (format t "  Min:    ~,3F ms~%" (* 1000 min-time))
        (format t "  Max:    ~,3F ms~%" (* 1000 max-time))
        (format t "  StdDev: ~,3F ms~%" (* 1000 std-dev))
        (format t "  Total consed: ~,2F MB~%" (/ total-consed 1024.0 1024.0))
        (format t "  Per iteration: ~,2F KB~%~%" (/ total-consed 1000.0 1024.0))))))

(run-gates-benchmark)
(sb-ext:quit)
