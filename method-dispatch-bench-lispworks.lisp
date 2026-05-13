;;; Micro-benchmark: Generic function dispatch (LispWorks version)
;;; Interactive benchmark for LispWorks Personal Edition IDE
;;;
;;; Instructions:
;;; 1. Select all code in the editor (Ctrl+A)
;;; 2. Evaluate the buffer (Ctrl+E)
;;; 3. In the REPL, type: (RUN-ALL-BENCHMARKS)
;;; 4. Copy results from the output pane into your notes

(defgeneric dispatch-lispworks (x)
  (:documentation "Generic function for LispWorks dispatch"))

(defmethod dispatch-lispworks ((x fixnum))
  (list :fixnum x))

(defmethod dispatch-lispworks ((x string))
  (list :string (length x)))

(defmethod dispatch-lispworks ((x list))
  (list :list (length x)))

(defmethod dispatch-lispworks ((x vector))
  (list :vector (length x)))

(defmethod dispatch-lispworks ((x symbol))
  (list :symbol x))

(defmethod dispatch-lispworks (x)
  (list :other x))

;; Test data: 200,000 calls with 5-type repeating cycle
(defvar *test-data*
  (let ((data nil))
    (dotimes (i 200000)
      (push (case (mod i 5)
              (0 (random 1000000))           ; fixnum
              (1 "test string")              ; string
              (2 '(a b c d e))               ; list
              (3 #(1 2 3 4 5))               ; vector
              (4 'symbol))                   ; symbol
            data))
    (reverse data)))

;; Benchmark function
(defun benchmark-lispworks-dispatch (&optional (iterations 3))
  "Benchmark LispWorks generic function dispatch"
  (let ((times nil))
    (dotimes (run iterations)
      (let ((result 0)
            (start-time (get-internal-run-time)))
        (dotimes (i (length *test-data*))
          (incf result (if (dispatch-lispworks (nth i *test-data*)) 1 0)))
        (let ((elapsed (- (get-internal-run-time) start-time)))
          (format t "~&  Run ~D: ~,3F seconds~%" (1+ run) (/ elapsed internal-time-units-per-second))
          (push result times))))
    (format t "~&LispWorks Generic Function Dispatch Results:~%")
    (format t "  Iterations: ~D~%" iterations)
    (format t "  Total calls per iteration: ~D~%" (length *test-data*))
    times))

(defun print-benchmark-summary ()
  "Print summary of benchmarks"
  (format t "~&~%================================~%")
  (format t "LispWorks Method Dispatch Micro-Benchmark~%")
  (format t "================================~%")
  (format t "Implementation: ~A ~A~%" (lisp-implementation-type) (lisp-implementation-version))
  (format t "Test data: 200,000 calls over repeating 5-type cycle~%")
  (format t "  Type cycle: fixnum -> string -> list -> vector -> symbol~%~%"))

(defun run-all-benchmarks ()
  "Run all benchmarks - MAIN ENTRY POINT"
  (print-benchmark-summary)
  (format t "Warming up JIT compiler (10,000 calls)...~%")
  (dotimes (i 10000)
    (dispatch-lispworks (nth (mod i (length *test-data*)) *test-data*)))
  (format t "Warmup complete.~%~%")
  (format t "Running generic function dispatch benchmark (3 iterations):~%")
  (benchmark-lispworks-dispatch 3)
  (format t "~&================================~%")
  (format t "Benchmark Complete~%")
  (format t "================================~%"))

;; Print instructions
(format t "~&~%LispWorks Method Dispatch Benchmark~%")
(format t "===================================~%")
(format t "To run the benchmark, type: (RUN-ALL-BENCHMARKS)~%")
(format t "~%")
