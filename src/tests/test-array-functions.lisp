;;; FOL Compiler Tests - Array Functions (Phase 1: Generic Operators)
;;;
;;; Tests for generic operator dispatch on scalars, vectors, and arrays.

(in-package :fol.compiler.tests)

;;; ============================================================================
;;; Test Suite: Array Functions (Phase 1)
;;; ============================================================================

(def-suite array-functions-suite
  :description "Tests for Phase 1 generic array functions"
  :in compiler-tests)

(in-suite array-functions-suite)

;;; ============================================================================
;;; Arithmetic Operators
;;; ============================================================================

(test arithmetic-addition-scalars
  "Test scalar addition with generic +"
  (is (= 6 (fol.compiler.array-functions:+ 1 2 3)))
  (is (= 10 (fol.compiler.array-functions:+ 5 5)))
  (is (= 0 (fol.compiler.array-functions:+ 0))))

(test arithmetic-addition-vectors
  "Test vector addition with generic +"
  (let ((v1 (fol.compiler.collection-functions:vector 1 2 3))
        (v2 (fol.compiler.collection-functions:vector 4 5 6)))
    (let ((result (fol.compiler.array-functions:+ v1 v2)))
      (is (= 3 (fol.compiler.collection-functions:count result)))
      (is (= 5 (fol.compiler.collection-functions:get result 0)))  ;; 1+4
      (is (= 7 (fol.compiler.collection-functions:get result 1)))  ;; 2+5
      (is (= 9 (fol.compiler.collection-functions:get result 2)))))) ;; 3+6

(test arithmetic-addition-broadcast
  "Test scalar-vector broadcast with generic +"
  (let ((v (fol.compiler.collection-functions:vector 1 2 3)))
    (let ((result (fol.compiler.array-functions:+ 10 v)))
      (is (= 3 (fol.compiler.collection-functions:count result)))
      (is (= 11 (fol.compiler.collection-functions:get result 0)))
      (is (= 12 (fol.compiler.collection-functions:get result 1)))
      (is (= 13 (fol.compiler.collection-functions:get result 2))))))

(test arithmetic-subtraction-scalars
  "Test scalar subtraction with generic -"
  (is (= -4 (fol.compiler.array-functions:- 1 2 3)))
  (is (= 0 (fol.compiler.array-functions:- 5 5)))
  (is (= -5 (fol.compiler.array-functions:- 5))))

(test arithmetic-multiplication-scalars
  "Test scalar multiplication with generic *"
  (is (= 24 (fol.compiler.array-functions:* 2 3 4)))
  (is (= 25 (fol.compiler.array-functions:* 5 5))))

(test arithmetic-division-scalars
  "Test scalar division with generic /"
  (is (= 2.0 (fol.compiler.array-functions:/ 10 5)))
  (is (= 0.5 (fol.compiler.array-functions:/ 1 2)))
  (is (< (abs (- 0.2 (fol.compiler.array-functions:/ 5))) 0.0001)))

(test arithmetic-multiplication-vectors
  "Test vector multiplication with generic *"
  (let ((v1 (fol.compiler.collection-functions:vector 2 3 4))
        (v2 (fol.compiler.collection-functions:vector 5 6 7)))
    (let ((result (fol.compiler.array-functions:* v1 v2)))
      (is (= 3 (fol.compiler.collection-functions:count result)))
      (is (= 10 (fol.compiler.collection-functions:get result 0)))  ;; 2*5
      (is (= 18 (fol.compiler.collection-functions:get result 1)))  ;; 3*6
      (is (= 28 (fol.compiler.collection-functions:get result 2))))))  ;; 4*7

;;; ============================================================================
;;; Comparison Operators
;;; ============================================================================

(test comparison-equality-scalars
  "Test scalar equality with generic ="
  (is (fol.compiler.array-functions:= 5 5))
  (is (not (fol.compiler.array-functions:= 5 6)))
  (is (fol.compiler.array-functions:= 1 1 1 1)))

(test comparison-equality-vectors
  "Test vector equality with generic ="
  (let ((v1 (fol.compiler.collection-functions:vector 1 2 3))
        (v2 (fol.compiler.collection-functions:vector 1 2 3)))
    (let ((result (fol.compiler.array-functions:= v1 v2)))
      (is (= 3 (fol.compiler.collection-functions:count result)))
      (is (fol.compiler.collection-functions:get result 0))
      (is (fol.compiler.collection-functions:get result 1))
      (is (fol.compiler.collection-functions:get result 2)))))

(test comparison-equality-broadcast
  "Test scalar-vector equality broadcast"
  (let ((v (fol.compiler.collection-functions:vector 5 5 5)))
    (let ((result (fol.compiler.array-functions:= 5 v)))
      (is (= 3 (fol.compiler.collection-functions:count result)))
      (is (fol.compiler.collection-functions:get result 0))
      (is (fol.compiler.collection-functions:get result 1))
      (is (fol.compiler.collection-functions:get result 2)))))

(test comparison-less-than-scalars
  "Test scalar < with generic <"
  (is (fol.compiler.array-functions:< 1 2 3))
  (is (not (fol.compiler.array-functions:< 3 2 1)))
  (is (not (fol.compiler.array-functions:< 5 5))))

(test comparison-less-than-vectors
  "Test vector < with generic <"
  (let ((v1 (fol.compiler.collection-functions:vector 1 2 3))
        (v2 (fol.compiler.collection-functions:vector 2 3 4)))
    (let ((result (fol.compiler.array-functions:< v1 v2)))
      (is (= 3 (fol.compiler.collection-functions:count result)))
      (is (fol.compiler.collection-functions:get result 0))
      (is (fol.compiler.collection-functions:get result 1))
      (is (fol.compiler.collection-functions:get result 2)))))

(test comparison-greater-than-scalars
  "Test scalar > with generic >"
  (is (fol.compiler.array-functions:> 3 2 1))
  (is (not (fol.compiler.array-functions:> 1 2 3)))
  (is (not (fol.compiler.array-functions:> 5 5))))

(test comparison-not-equal-scalars
  "Test scalar not= with generic not="
  (is (fol.compiler.array-functions:not= 5 6))
  (is (not (fol.compiler.array-functions:not= 5 5)))
  (is (fol.compiler.array-functions:not= 1 2 3)))

;;; ============================================================================
;;; Logical Operators
;;; ============================================================================

(test logical-and-scalars
  "Test scalar AND with generic and"
  (is (fol.compiler.array-functions:and t t))
  (is (not (fol.compiler.array-functions:and t nil)))
  (is (fol.compiler.array-functions:and t t t)))

(test logical-or-scalars
  "Test scalar OR with generic or"
  (is (fol.compiler.array-functions:or t nil))
  (is (not (fol.compiler.array-functions:or nil nil)))
  (is (fol.compiler.array-functions:or nil nil t)))

(test logical-not-scalars
  "Test scalar NOT with generic not"
  (is (not (fol.compiler.array-functions:not t)))
  (is (fol.compiler.array-functions:not nil)))

(test logical-not-vectors
  "Test vector NOT with generic not"
  (let ((v (fol.compiler.collection-functions:vector t nil t)))
    (let ((result (fol.compiler.array-functions:not v)))
      (is (= 3 (fol.compiler.collection-functions:count result)))
      (is (not (fol.compiler.collection-functions:get result 0)))
      (is (fol.compiler.collection-functions:get result 1))
      (is (not (fol.compiler.collection-functions:get result 2))))))

;;; ============================================================================
;;; Helper Functions
;;; ============================================================================

(test vector-element-wise-basic
  "Test vector-element-wise helper function"
  (let ((v1 (fol.compiler.collection-functions:vector 1 2 3))
        (v2 (fol.compiler.collection-functions:vector 10 20 30)))
    (let ((result (fol.compiler.array-functions:vector-element-wise
                   #'cl:+ v1 v2)))
      (is (= 3 (fol.compiler.collection-functions:count result)))
      (is (= 11 (fol.compiler.collection-functions:get result 0)))
      (is (= 22 (fol.compiler.collection-functions:get result 1)))
      (is (= 33 (fol.compiler.collection-functions:get result 2))))))

(test vector-broadcast-basic
  "Test vector-broadcast helper function"
  (let ((v (fol.compiler.collection-functions:vector 1 2 3)))
    (let ((result (fol.compiler.array-functions:vector-broadcast
                   #'(lambda (x) (cl:* x 2)) v)))
      (is (= 3 (fol.compiler.collection-functions:count result)))
      (is (= 2 (fol.compiler.collection-functions:get result 0)))
      (is (= 4 (fol.compiler.collection-functions:get result 1)))
      (is (= 6 (fol.compiler.collection-functions:get result 2))))))

;;; ============================================================================
;;; Varargs Reduction
;;; ============================================================================

(test varargs-addition-chain
  "Test varargs reduction with +"
  (let ((result (fol.compiler.array-functions:+ 1 2 3 4 5)))
    (is (= 15 result))))

(test varargs-multiplication-chain
  "Test varargs reduction with *"
  (let ((result (fol.compiler.array-functions:* 2 3 4)))
    (is (= 24 result))))

(test varargs-comparison-chain
  "Test varargs reduction with <"
  (is (fol.compiler.array-functions:< 1 2 3 4 5))
  (is (not (fol.compiler.array-functions:< 1 5 3 4 2))))

;;; ============================================================================
;;; Phase 1: N-Dimensional Array Functions
;;; ============================================================================

(def-suite nd-array-suite
  :description "Tests for Phase 1 n-dimensional array functions"
  :in compiler-tests)

(in-suite nd-array-suite)

(test nd-array-creation-1d
  "Test creating 1D array"
  (let ((arr (fol.compiler.array-functions:create-nd-array '(5) :initial-element 0)))
    (is (typep arr 'fol.compiler.collections:<array>))
    (is (= 5 (fol.compiler.array-functions:nd-size arr)))
    (is (= 1 (fol.compiler.array-functions:nd-rank arr)))))

(test nd-array-creation-2d
  "Test creating 2D array"
  (let ((arr (fol.compiler.array-functions:create-nd-array '(2 3) :initial-element 0)))
    (is (= 6 (fol.compiler.array-functions:nd-size arr)))
    (is (= 2 (fol.compiler.array-functions:nd-rank arr)))))

(test nd-array-creation-3d
  "Test creating 3D array"
  (let ((arr (fol.compiler.array-functions:create-nd-array '(2 3 4) :initial-element 1)))
    (is (= 24 (fol.compiler.array-functions:nd-size arr)))
    (is (= 3 (fol.compiler.array-functions:nd-rank arr)))))

(test nd-array-creation-4d
  "Test creating 4D array"
  (let ((arr (fol.compiler.array-functions:create-nd-array '(2 2 2 2) :initial-element 0)))
    (is (= 16 (fol.compiler.array-functions:nd-size arr)))
    (is (= 4 (fol.compiler.array-functions:nd-rank arr)))))

(test nd-shape-1d
  "Test getting shape of 1D array"
  (let ((arr (fol.compiler.array-functions:create-nd-array '(5) :initial-element 0)))
    (let ((shape (fol.compiler.array-functions:nd-shape arr)))
      (is (equal '(5) shape)))))

(test nd-shape-2d
  "Test getting shape of 2D array"
  (let ((arr (fol.compiler.array-functions:create-nd-array '(3 4) :initial-element 0)))
    (let ((shape (fol.compiler.array-functions:nd-shape arr)))
      (is (equal '(3 4) shape)))))

(test nd-shape-3d
  "Test getting shape of 3D array"
  (let ((arr (fol.compiler.array-functions:create-nd-array '(2 3 4) :initial-element 0)))
    (let ((shape (fol.compiler.array-functions:nd-shape arr)))
      (is (equal '(2 3 4) shape)))))

(test nd-rank-predicate
  "Test nd-rank on various arrays"
  (is (= 1 (fol.compiler.array-functions:nd-rank
            (fol.compiler.array-functions:create-nd-array '(5) :initial-element 0))))
  (is (= 2 (fol.compiler.array-functions:nd-rank
            (fol.compiler.array-functions:create-nd-array '(2 3) :initial-element 0))))
  (is (= 3 (fol.compiler.array-functions:nd-rank
            (fol.compiler.array-functions:create-nd-array '(2 3 4) :initial-element 0))))
  (is (= 4 (fol.compiler.array-functions:nd-rank
            (fol.compiler.array-functions:create-nd-array '(2 2 2 2) :initial-element 0)))))

(test nd-size-predicate
  "Test nd-size on various arrays"
  (is (= 5 (fol.compiler.array-functions:nd-size
            (fol.compiler.array-functions:create-nd-array '(5) :initial-element 0))))
  (is (= 6 (fol.compiler.array-functions:nd-size
            (fol.compiler.array-functions:create-nd-array '(2 3) :initial-element 0))))
  (is (= 24 (fol.compiler.array-functions:nd-size
             (fol.compiler.array-functions:create-nd-array '(2 3 4) :initial-element 0))))
  (is (= 16 (fol.compiler.array-functions:nd-size
             (fol.compiler.array-functions:create-nd-array '(2 2 2 2) :initial-element 0)))))

(test nd-array-default-initialization
  "Test array initialization defaults to 0"
  (let ((arr (fol.compiler.array-functions:create-nd-array '(3 3))))
    (is (= 9 (fol.compiler.array-functions:nd-size arr)))))

(test nd-array-vector-shape-arg
  "Test creating array with vector shape argument"
  (let* ((shape (fol.compiler.collection-functions:vector 2 3))
         (arr (fol.compiler.array-functions:create-nd-array shape :initial-element 1)))
    (is (= 6 (fol.compiler.array-functions:nd-size arr)))
    (is (= 2 (fol.compiler.array-functions:nd-rank arr)))))

(test nd-array-element-access-1d
  "Test accessing elements in 1D array via get"
  (let ((arr (fol.compiler.array-functions:create-nd-array '(5) :initial-element 7)))
    ;; All elements should be initialized to 7
    (is (= 7 (fol.compiler.collection-functions:get arr 0)))
    (is (= 7 (fol.compiler.collection-functions:get arr 1)))
    (is (= 7 (fol.compiler.collection-functions:get arr 4)))))

(test nd-array-element-update-1d
  "Test updating elements in 1D array via assoc"
  (let* ((arr (fol.compiler.array-functions:create-nd-array '(3) :initial-element 0))
         (arr2 (fol.compiler.collection-functions:assoc arr 1 99)))
    (is (= 0 (fol.compiler.collection-functions:get arr 1)))
    (is (= 99 (fol.compiler.collection-functions:get arr2 1)))
    (is (= 0 (fol.compiler.collection-functions:get arr2 0)))
    (is (= 0 (fol.compiler.collection-functions:get arr2 2)))))

(test nd-array-immutability
  "Test that assoc creates new array, doesn't modify original"
  (let* ((arr1 (fol.compiler.array-functions:create-nd-array '(2 2) :initial-element 0))
         (arr2 (fol.compiler.collection-functions:assoc arr1 0 99)))
    (is (not (eq arr1 arr2)))
    (is (= 0 (fol.compiler.collection-functions:get arr1 0)))
    (is (= 99 (fol.compiler.collection-functions:get arr2 0)))))

(test nd-array-different-sizes
  "Test creating arrays of different sizes"
  (let ((arr1 (fol.compiler.array-functions:create-nd-array '(10) :initial-element 1))
        (arr2 (fol.compiler.array-functions:create-nd-array '(3 3 3) :initial-element 2))
        (arr3 (fol.compiler.array-functions:create-nd-array '(2 4 3 2) :initial-element 3)))
    (is (= 10 (fol.compiler.array-functions:nd-size arr1)))
    (is (= 27 (fol.compiler.array-functions:nd-size arr2)))
    (is (= 48 (fol.compiler.array-functions:nd-size arr3)))))

(test nd-array-initialization-values
  "Test that arrays are properly initialized"
  (let ((arr0 (fol.compiler.array-functions:create-nd-array '(2 2)))
        (arr5 (fol.compiler.array-functions:create-nd-array '(2 2) :initial-element 5))
        (arr-neg (fol.compiler.array-functions:create-nd-array '(2 2) :initial-element -1)))
    (is (= 0 (fol.compiler.collection-functions:get arr0 0)))
    (is (= 5 (fol.compiler.collection-functions:get arr5 0)))
    (is (= -1 (fol.compiler.collection-functions:get arr-neg 0)))))

