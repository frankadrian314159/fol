;;; Manual test of array-functions and adverbs

(push (truename ".") asdf:*central-registry*)

(asdf:load-system :fol-compiler)

(in-package :fol.core)

;;; Test Phase 1: Basic arithmetic operators
(format t "~%=== Phase 1: Arithmetic Operators ===~%")
(format t "scalar + : ~a~%" (+ 1 2 3))  ;; Should be 6
(format t "scalar * : ~a~%" (* 2 3 4))  ;; Should be 24

;;; Test vector operations
(let ((v1 (vector 1 2 3))
      (v2 (vector 4 5 6)))
  (format t "vector +: ~a~%" (+ v1 v2)))  ;; Should be [5 7 9]

;;; Test broadcast
(let ((v (vector 1 2 3)))
  (format t "broadcast +: ~a~%" (+ 10 v)))  ;; Should be [11 12 13]

;;; Test Phase 2: Adverbs
(format t "~%=== Phase 2: Adverbs ===~%")

;;; Test fold
(let ((v (vector 1 2 3 4)))
  (format t "fold: ~a~%" (fold #'+ v)))  ;; Should be 10

;;; Test scan
(let ((v (vector 1 2 3 4)))
  (format t "scan: ~a~%" (scan #'+ v)))  ;; Should be [1 3 6 10]

;;; Test sum
(let ((v (vector 1 2 3 4)))
  (format t "sum: ~a~%" (sum v)))  ;; Should be 10

;;; Test mean
(let ((v (vector 2 4 6 8)))
  (format t "mean: ~a~%" (mean v)))  ;; Should be 5.0

;;; Test window
(let ((v (vector 1 2 3 4 5)))
  (format t "window: ~a~%" (window 2 #'sum v)))  ;; Should be [3 5 7]

(format t "~%All tests completed!~%")
