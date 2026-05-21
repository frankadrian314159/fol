;;; Micro-benchmark: Generic function dispatch (CCL version)

(defgeneric dispatch-ccl (x)
  (:documentation "Generic function for CCL dispatch"))

(defmethod dispatch-ccl ((x fixnum))
  (list :fixnum x))

(defmethod dispatch-ccl ((x string))
  (list :string (length x)))

(defmethod dispatch-ccl ((x list))
  (list :list (length x)))

(defmethod dispatch-ccl ((x vector))
  (list :vector (length x)))

(defmethod dispatch-ccl ((x symbol))
  (list :symbol x))

(defmethod dispatch-ccl (x)
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
(defun benchmark-ccl-dispatch (&optional (iterations 3))
  "Benchmark CCL generic function dispatch"
  (let ((times nil))
    (dotimes (run iterations)
      (let ((result 0))
        (time
         (dotimes (i (length *test-data*))
           (incf result (if (dispatch-ccl (nth i *test-data*)) 1 0))))
        (push result times)))
    (format t "~&CCL Dispatch Results:~%")
    (format t "  Runs: ~D~%" iterations)
    (format t "  Total calls per run: ~D~%" (length *test-data*))
    times))

(defun print-benchmark-summary ()
  "Print summary of benchmarks"
  (format t "~&~%=== Generic Function Dispatch Benchmark (CCL) ===~%")
  (format t "Implementation: ~A ~A~%" (lisp-implementation-type) (lisp-implementation-version))
  (format t "Test data: 200,000 calls over repeating 5-type cycle~%")
  (format t "  Type cycle: fixnum -> string -> list -> vector -> symbol~%~%"))

(defun run-all-benchmarks ()
  "Run all benchmarks"
  (print-benchmark-summary)
  (format t "Warming up JIT compiler...~%")
  (dotimes (i 10000)
    (dispatch-ccl (nth (mod i (length *test-data*)) *test-data*)))
  (format t "~&Running CCL dispatch benchmark (3 iterations):~%")
  (benchmark-ccl-dispatch 3))

;; Run benchmarks
(run-all-benchmarks)
(quit)
