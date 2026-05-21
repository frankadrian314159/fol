;;; Micro-benchmark: Generic function dispatch (ABCL version)

(defgeneric dispatch-abcl (x)
  (:documentation "Generic function for ABCL dispatch"))

(defmethod dispatch-abcl ((x fixnum))
  (list :fixnum x))

(defmethod dispatch-abcl ((x string))
  (list :string (length x)))

(defmethod dispatch-abcl ((x list))
  (list :list (length x)))

(defmethod dispatch-abcl ((x vector))
  (list :vector (length x)))

(defmethod dispatch-abcl ((x symbol))
  (list :symbol x))

(defmethod dispatch-abcl (x)
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
(defun benchmark-abcl-dispatch (&optional (iterations 3))
  "Benchmark ABCL generic function dispatch"
  (let ((times nil))
    (dotimes (run iterations)
      (let ((result 0))
        (time
         (dotimes (i (length *test-data*))
           (incf result (if (dispatch-abcl (nth i *test-data*)) 1 0))))
        (push result times)))
    (format t "~&ABCL Dispatch Results:~%")
    (format t "  Runs: ~D~%" iterations)
    (format t "  Total calls per run: ~D~%" (length *test-data*))
    times))

(defun print-benchmark-summary ()
  "Print summary of benchmarks"
  (format t "~&~%=== Generic Function Dispatch Benchmark (ABCL) ===~%")
  (format t "Implementation: ~A ~A~%" (lisp-implementation-type) (lisp-implementation-version))
  (format t "Test data: 200,000 calls over repeating 5-type cycle~%")
  (format t "  Type cycle: fixnum -> string -> list -> vector -> symbol~%~%"))

(defun run-all-benchmarks ()
  "Run all benchmarks"
  (print-benchmark-summary)
  (format t "Warming up JIT compiler...~%")
  (dotimes (i 10000)
    (dispatch-abcl (nth (mod i (length *test-data*)) *test-data*)))
  (format t "~&Running ABCL dispatch benchmark (3 iterations):~%")
  (benchmark-abcl-dispatch 3))

;; Run benchmarks
(run-all-benchmarks)
(quit)
