;;; Micro-benchmark: Generic function dispatch (FOL defmethod vs CLOS)

(defpackage :method-dispatch-bench
  (:use :cl))

(in-package :method-dispatch-bench)

;; ============================================================================
;; Common Lisp CLOS Implementation
;; ============================================================================

(defgeneric dispatch-clos (x)
  (:documentation "Generic function for CLOS dispatch"))

(defmethod dispatch-clos ((x fixnum))
  (list :fixnum x))

(defmethod dispatch-clos ((x string))
  (list :string (length x)))

(defmethod dispatch-clos ((x list))
  (list :list (length x)))

(defmethod dispatch-clos ((x vector))
  (list :vector (length x)))

(defmethod dispatch-clos ((x symbol))
  (list :symbol x))

(defmethod dispatch-clos (x)
  (list :other x))

;; ============================================================================
;; Test Data: Repeating cycle of 5 different types
;; ============================================================================

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

;; ============================================================================
;; Benchmark: CLOS dispatch
;; ============================================================================

(defun benchmark-clos-dispatch (&optional (iterations 3))
  "Benchmark CLOS generic function dispatch"
  (let ((times nil))
    (dotimes (run iterations)
      (let ((result 0))
        (time
         (dotimes (i (length *test-data*))
           (incf result (if (dispatch-clos (nth i *test-data*)) 1 0))))
        (push result times)))
    (format t "~&CLOS Dispatch Results:~%")
    (format t "  Runs: ~D~%" iterations)
    (format t "  Total calls per run: ~D~%" (length *test-data*))
    times))

;; ============================================================================
;; Results Formatter
;; ============================================================================

(defun print-benchmark-summary ()
  "Print summary of benchmarks"
  (format t "~&~%=== Generic Function Dispatch Benchmark ===~%")
  (format t "Test data: 200,000 calls over repeating 5-type cycle~%")
  (format t "  Type cycle: fixnum -> string -> list -> vector -> symbol~%~%"))

(defun run-all-benchmarks ()
  "Run all benchmarks"
  (print-benchmark-summary)
  (format t "~&Warming up JIT compiler...~%")
  (dotimes (i 10000)
    (dispatch-clos (nth (mod i (length *test-data*)) *test-data*)))
  (format t "~&Running CLOS dispatch benchmark (3 iterations):~%")
  (benchmark-clos-dispatch 3))

;; Run benchmarks
(run-all-benchmarks)
