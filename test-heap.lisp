(ql:quickload :pileup :silent t)
(ql:quickload :alexandria :silent t)

(load "lsim-pure-cl-heap.lisp")

(in-package :lsim-pure-cl-heap)

(format t "Testing basic component creation...~%")
(let ((gate (make-not-gate 'test-not 'in1 'out1)))
  (format t "NOT gate created: ~A~%"  (gethash :name gate)))

(format t "~%Testing D-latch creation...~%")
(let ((latch-gates (make-d-latch-from-gates 'test-latch 'clk 'd 'q)))
  (format t "D-latch has ~D gates~%" (length latch-gates)))

(format t "~%Testing 8-bit register creation...~%")
(let ((netlist (make-8bit-register-from-gates)))
  (format t "8-bit register has ~D components~%" (length netlist)))

(format t "~%Testing event creation...~%")
(let ((events (make-long-test-events)))
  (format t "Created ~D events~%" (length events)))

(format t "~%Testing simulation (short run)...~%")
(handler-case
    (let ((netlist (make-8bit-register-from-gates))
          (events (vector (make-event 0 'in0 t)
                         (make-event 10 'clk t)))
          (monitored (let ((m (make-hash-table :test 'eq)))
                      (setf (gethash 'out0 m) t)
                      m)))
      (run-simulation netlist events 20 monitored)
      (format t "Simulation completed successfully!~%"))
  (error (e)
    (format t "ERROR: ~A~%" e)
    (format t "Type: ~A~%" (type-of e))))

(sb-ext:quit)
