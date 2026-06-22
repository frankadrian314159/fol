;;; FOL Compiler Tests - Adverbs (Phase 2: Single-Axis Operations)
;;;
;;; Tests for axis-aware fold, scan, each, window, group-by, and statistics.

(in-package :fol.compiler.tests)

;;; ============================================================================
;;; Test Suite: Adverbs (Phase 2)
;;; ============================================================================

(def-suite adverbs-suite
  :description "Tests for Phase 2 axis-aware adverbs"
  :in compiler-tests)

(in-suite adverbs-suite)

;;; ============================================================================
;;; Fold (Reduction)
;;; ============================================================================

(test fold-basic-vector
  "Test basic fold on vector"
  (let ((v (fol.compiler.collection-functions:vector 1 2 3 4)))
    (let ((result (fol.compiler.adverbs:fold #'cl:+ v)))
      (is (= 10 result)))))

(test fold-multiply
  "Test fold with multiplication"
  (let ((v (fol.compiler.collection-functions:vector 2 3 4)))
    (let ((result (fol.compiler.adverbs:fold #'cl:* v)))
      (is (= 24 result)))))

(test fold-single-element
  "Test fold on single-element vector"
  (let ((v (fol.compiler.collection-functions:vector 42)))
    (let ((result (fol.compiler.adverbs:fold #'cl:+ v)))
      (is (= 42 result)))))

;;; ============================================================================
;;; Scan (Cumulative)
;;; ============================================================================

(test scan-basic-vector
  "Test basic scan on vector"
  (let ((v (fol.compiler.collection-functions:vector 1 2 3 4)))
    (let ((result (fol.compiler.adverbs:scan #'cl:+ v)))
      (is (= 4 (fol.compiler.collection-functions:count result)))
      (is (= 1 (fol.compiler.collection-functions:get result 0)))
      (is (= 3 (fol.compiler.collection-functions:get result 1)))
      (is (= 6 (fol.compiler.collection-functions:get result 2)))
      (is (= 10 (fol.compiler.collection-functions:get result 3))))))

(test scan-multiply
  "Test scan with multiplication"
  (let ((v (fol.compiler.collection-functions:vector 2 3 4)))
    (let ((result (fol.compiler.adverbs:scan #'cl:* v)))
      (is (= 3 (fol.compiler.collection-functions:count result)))
      (is (= 2 (fol.compiler.collection-functions:get result 0)))
      (is (= 6 (fol.compiler.collection-functions:get result 1)))
      (is (= 24 (fol.compiler.collection-functions:get result 2))))))

;;; ============================================================================
;;; Each
;;; ============================================================================

(test each-rank-zero
  "Test each with rank 0 (scalars)"
  (let ((v (fol.compiler.collection-functions:vector 1 2 3)))
    (let ((result (fol.compiler.adverbs:each
                   (lambda (x) (cl:* x 2)) v :rank 0)))
      (is (= 3 (fol.compiler.collection-functions:count result)))
      (is (= 2 (fol.compiler.collection-functions:get result 0)))
      (is (= 4 (fol.compiler.collection-functions:get result 1)))
      (is (= 6 (fol.compiler.collection-functions:get result 2))))))

;;; ============================================================================
;;; Window
;;; ============================================================================

(test window-basic
  "Test basic window operation"
  (let ((v (fol.compiler.collection-functions:vector 1 2 3 4 5)))
    (let ((result (fol.compiler.adverbs:window
                   2
                   (lambda (w) (fol.compiler.adverbs:sum w))
                   v)))
      (is (= 4 (fol.compiler.collection-functions:count result)))
      (is (= 3 (fol.compiler.collection-functions:get result 0)))  ;; 1+2
      (is (= 5 (fol.compiler.collection-functions:get result 1)))  ;; 2+3
      (is (= 7 (fol.compiler.collection-functions:get result 2)))  ;; 3+4
      (is (= 9 (fol.compiler.collection-functions:get result 3)))))) ;; 4+5

(test window-size-three
  "Test window with size 3"
  (let ((v (fol.compiler.collection-functions:vector 1 2 3 4 5)))
    (let ((result (fol.compiler.adverbs:window
                   3
                   (lambda (w) (fol.compiler.adverbs:sum w))
                   v)))
      (is (= 3 (fol.compiler.collection-functions:count result)))
      (is (= 6 (fol.compiler.collection-functions:get result 0)))  ;; 1+2+3
      (is (= 9 (fol.compiler.collection-functions:get result 1)))  ;; 2+3+4
      (is (= 12 (fol.compiler.collection-functions:get result 2)))))) ;; 3+4+5

;;; ============================================================================
;;; Statistics: Sum, Mean, Variance, StdDev
;;; ============================================================================

(test statistics-sum-basic
  "Test sum function"
  (let ((v (fol.compiler.collection-functions:vector 1 2 3 4)))
    (let ((result (fol.compiler.adverbs:sum v)))
      (is (= 10 result)))))

(test statistics-sum-negative
  "Test sum with negative numbers"
  (let ((v (fol.compiler.collection-functions:vector -1 2 -3 4)))
    (let ((result (fol.compiler.adverbs:sum v)))
      (is (= 2 result)))))

(test statistics-mean-basic
  "Test mean function"
  (let ((v (fol.compiler.collection-functions:vector 2 4 6 8)))
    (let ((result (fol.compiler.adverbs:mean v)))
      (is (= 5.0 result)))))

(test statistics-mean-single
  "Test mean of single element"
  (let ((v (fol.compiler.collection-functions:vector 42)))
    (let ((result (fol.compiler.adverbs:mean v)))
      (is (= 42.0 result)))))

(test statistics-variance-basic
  "Test variance function"
  (let ((v (fol.compiler.collection-functions:vector 1 2 3 4 5)))
    (let ((result (fol.compiler.adverbs:variance v)))
      ;; Variance = sum((x - mean)^2) / n
      ;; mean = 3, so deviations = [-2, -1, 0, 1, 2]
      ;; squared = [4, 1, 0, 1, 4], sum = 10, variance = 10/5 = 2
      (is (< (abs (- result 2.0)) 0.0001)))))

(test statistics-std-dev-basic
  "Test standard deviation function"
  (let ((v (fol.compiler.collection-functions:vector 1 2 3 4 5)))
    (let ((result (fol.compiler.adverbs:std-dev v)))
      ;; std-dev = sqrt(variance) = sqrt(2) ≈ 1.414
      (is (< (abs (- result 1.414)) 0.01)))))

;;; ============================================================================
;;; Sorting & Searching
;;; ============================================================================

(test sorting-reverse-basic
  "Test reverse function"
  (let ((v (fol.compiler.collection-functions:vector 1 2 3 4)))
    (let ((result (fol.compiler.adverbs:array-reverse v)))
      (is (= 4 (fol.compiler.collection-functions:count result)))
      (is (= 4 (fol.compiler.collection-functions:get result 0)))
      (is (= 3 (fol.compiler.collection-functions:get result 1)))
      (is (= 2 (fol.compiler.collection-functions:get result 2)))
      (is (= 1 (fol.compiler.collection-functions:get result 3))))))

;;; ============================================================================
;;; Mapping & Transformation
;;; ============================================================================

(test mapping-map-array-basic
  "Test map-array function"
  (let ((v (fol.compiler.collection-functions:vector 1 2 3)))
    (let ((result (fol.compiler.adverbs:map-array
                   (lambda (x) (cl:* x 2)) v)))
      (is (= 3 (fol.compiler.collection-functions:count result)))
      (is (= 2 (fol.compiler.collection-functions:get result 0)))
      (is (= 4 (fol.compiler.collection-functions:get result 1)))
      (is (= 6 (fol.compiler.collection-functions:get result 2))))))

(test mapping-zip-basic
  "Test zip function"
  (let ((v1 (fol.compiler.collection-functions:vector 1 2 3))
        (v2 (fol.compiler.collection-functions:vector 4 5 6)))
    (let ((result (fol.compiler.adverbs:zip v1 v2)))
      (is (= 3 (fol.compiler.collection-functions:count result))))))

;;; ============================================================================
;;; Aggregation
;;; ============================================================================


;;; ============================================================================
;;; Partitioning
;;; ============================================================================

(test partitioning-array-partition-basic
  "Test partition function"
  (let ((v (fol.compiler.collection-functions:vector 1 2 3 4 5)))
    (let ((result (fol.compiler.adverbs:array-partition 2 v)))
      (is (>= (fol.compiler.collection-functions:count result) 2)))))

(test partitioning-array-take-basic
  "Test array-take function"
  (let ((v (fol.compiler.collection-functions:vector 1 2 3 4 5)))
    (let ((result (fol.compiler.adverbs:array-take 3 v)))
      (is (= 3 (fol.compiler.collection-functions:count result)))
      (is (= 1 (fol.compiler.collection-functions:get result 0)))
      (is (= 2 (fol.compiler.collection-functions:get result 1)))
      (is (= 3 (fol.compiler.collection-functions:get result 2))))))

(test partitioning-array-drop-basic
  "Test array-drop function"
  (let ((v (fol.compiler.collection-functions:vector 1 2 3 4 5)))
    (let ((result (fol.compiler.adverbs:array-drop 2 v)))
      (is (= 3 (fol.compiler.collection-functions:count result)))
      (is (= 3 (fol.compiler.collection-functions:get result 0)))
      (is (= 4 (fol.compiler.collection-functions:get result 1)))
      (is (= 5 (fol.compiler.collection-functions:get result 2))))))

