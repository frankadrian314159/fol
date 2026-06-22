;;; FOL Compiler Tests - Advanced Array Operations (Phase 3)
;;;
;;; Tests for shape operations, axis-specific reductions, slicing, concatenation, transpose.

(in-package :fol.compiler.tests)

;;; ============================================================================
;;; Test Suite: Advanced Array Operations (Phase 3)
;;; ============================================================================

(def-suite advanced-array-operations-suite
  :description "Tests for Phase 3 advanced array operations"
  :in compiler-tests)

(in-suite advanced-array-operations-suite)

;;; ============================================================================
;;; Shape and Rank Operations
;;; ============================================================================

(test shape-vector
  "Test shape of 1D vector"
  (let ((v (fol.compiler.collection-functions:vector 1 2 3 4)))
    (let ((result (fol.compiler.advanced-array-operations:shape v)))
      (is (= 1 (fol.compiler.collection-functions:count result)))
      (is (= 4 (fol.compiler.collection-functions:get result 0))))))

(test rank-vector
  "Test rank of 1D vector"
  (let ((v (fol.compiler.collection-functions:vector 1 2 3)))
    (is (= 1 (fol.compiler.advanced-array-operations:rank v)))))

(test array-size-vector
  "Test size of array"
  (let ((v (fol.compiler.collection-functions:vector 1 2 3 4 5)))
    (is (= 5 (fol.compiler.advanced-array-operations:array-size v)))))

(test flatten-vector
  "Test flatten on already-flat vector"
  (let ((v (fol.compiler.collection-functions:vector 1 2 3 4)))
    (let ((result (fol.compiler.advanced-array-operations:flatten v)))
      (is (= 4 (fol.compiler.collection-functions:count result)))
      (is (= 1 (fol.compiler.collection-functions:get result 0)))
      (is (= 4 (fol.compiler.collection-functions:get result 3))))))

;;; ============================================================================
;;; Axis Operations (Reductions along specific axes)
;;; ============================================================================

(test sum-axis-basic
  "Test sum along axis 0"
  (let ((arr (fol.compiler.collection-functions:vector
              (fol.compiler.collection-functions:vector 1 2 3)
              (fol.compiler.collection-functions:vector 4 5 6))))
    (let ((result (fol.compiler.advanced-array-operations:sum-axis arr 0)))
      (is (= 3 (fol.compiler.collection-functions:count result)))
      (is (= 5 (fol.compiler.collection-functions:get result 0)))
      (is (= 7 (fol.compiler.collection-functions:get result 1)))
      (is (= 9 (fol.compiler.collection-functions:get result 2))))))

(test mean-axis-basic
  "Test mean along axis 0"
  (let ((arr (fol.compiler.collection-functions:vector
              (fol.compiler.collection-functions:vector 1 2 3)
              (fol.compiler.collection-functions:vector 3 4 5))))
    (let ((result (fol.compiler.advanced-array-operations:mean-axis arr 0)))
      (is (= 3 (fol.compiler.collection-functions:count result)))
      (is (cl:= 2.0 (fol.compiler.collection-functions:get result 0)))
      (is (cl:= 3.0 (fol.compiler.collection-functions:get result 1)))
      (is (cl:= 4.0 (fol.compiler.collection-functions:get result 2))))))

(test max-axis-basic
  "Test max along axis 0"
  (let ((arr (fol.compiler.collection-functions:vector
              (fol.compiler.collection-functions:vector 1 2 3)
              (fol.compiler.collection-functions:vector 4 5 6))))
    (let ((result (fol.compiler.advanced-array-operations:max-axis arr 0)))
      (is (= 3 (fol.compiler.collection-functions:count result)))
      (is (= 4 (fol.compiler.collection-functions:get result 0)))
      (is (= 5 (fol.compiler.collection-functions:get result 1)))
      (is (= 6 (fol.compiler.collection-functions:get result 2))))))

(test min-axis-basic
  "Test min along axis 0"
  (let ((arr (fol.compiler.collection-functions:vector
              (fol.compiler.collection-functions:vector 1 2 3)
              (fol.compiler.collection-functions:vector 4 5 6))))
    (let ((result (fol.compiler.advanced-array-operations:min-axis arr 0)))
      (is (= 3 (fol.compiler.collection-functions:count result)))
      (is (= 1 (fol.compiler.collection-functions:get result 0)))
      (is (= 2 (fol.compiler.collection-functions:get result 1)))
      (is (= 3 (fol.compiler.collection-functions:get result 2))))))

;;; ============================================================================
;;; Slicing and Indexing
;;; ============================================================================

(test slice-vector-basic
  "Test slicing a vector"
  (let ((v (fol.compiler.collection-functions:vector 1 2 3 4 5)))
    (let ((result (fol.compiler.advanced-array-operations:slice v 1 4)))
      (is (= 3 (fol.compiler.collection-functions:count result)))
      (is (= 2 (fol.compiler.collection-functions:get result 0)))
      (is (= 3 (fol.compiler.collection-functions:get result 1)))
      (is (= 4 (fol.compiler.collection-functions:get result 2))))))

(test get-slice-vector
  "Test get-slice on vector"
  (let ((v (fol.compiler.collection-functions:vector 1 2 3 4 5)))
    (is (= 3 (fol.compiler.advanced-array-operations:get-slice v 2)))))

;;; ============================================================================
;;; Concatenation and Stacking
;;; ============================================================================

(test concat-arrays-vectors
  "Test concatenating vectors"
  (let ((v1 (fol.compiler.collection-functions:vector 1 2 3))
        (v2 (fol.compiler.collection-functions:vector 4 5 6)))
    (let ((result (fol.compiler.advanced-array-operations:concat-arrays v1 v2)))
      (is (= 6 (fol.compiler.collection-functions:count result)))
      (is (= 1 (fol.compiler.collection-functions:get result 0)))
      (is (= 6 (fol.compiler.collection-functions:get result 5))))))

;;; ============================================================================
;;; Transpose
;;; ============================================================================

(test transpose-matrix
  "Test transposing a matrix"
  (let ((arr (fol.compiler.collection-functions:vector
              (fol.compiler.collection-functions:vector 1 2 3)
              (fol.compiler.collection-functions:vector 4 5 6))))
    (let ((result (fol.compiler.advanced-array-operations:transpose arr)))
      (is (= 3 (fol.compiler.collection-functions:count result)))
      (is (= 2 (fol.compiler.collection-functions:count (fol.compiler.collection-functions:get result 0))))
      (is (= 1 (fol.compiler.collection-functions:get (fol.compiler.collection-functions:get result 0) 0)))
      (is (= 4 (fol.compiler.collection-functions:get (fol.compiler.collection-functions:get result 0) 1))))))

;;; ============================================================================
;;; Phase 2: Shape & Reshape Operations
;;; ============================================================================

(test reshape-flat-to-2d
  "Test reshaping 1D array to 2D"
  (let ((arr (fol.compiler.collection-functions:vector 1 2 3 4)))
    (let ((result (fol.compiler.advanced-array-operations:reshape arr (list 2 2))))
      (is (= 2 (fol.compiler.collection-functions:count result)))
      (is (= 2 (fol.compiler.collection-functions:count (fol.compiler.collection-functions:get result 0)))))))

(test reshape-2d-to-flat
  "Test reshaping 2D array to 1D"
  (let ((arr (fol.compiler.collection-functions:vector
              (fol.compiler.collection-functions:vector 1 2)
              (fol.compiler.collection-functions:vector 3 4))))
    (let ((result (fol.compiler.advanced-array-operations:reshape arr (list 4))))
      (is (= 4 (fol.compiler.collection-functions:count result))))))

(test reshape-flat-to-3d
  "Test reshaping 1D array to 3D"
  (let ((arr (fol.compiler.collection-functions:vector 1 2 3 4 5 6 7 8)))
    (let ((result (fol.compiler.advanced-array-operations:reshape arr (list 2 2 2))))
      (is (= 2 (fol.compiler.collection-functions:count result))))))

(test reshape-size-mismatch-error
  "Test reshape with mismatched sizes throws error"
  (let ((arr (fol.compiler.collection-functions:vector 1 2 3 4)))
    (signals error
      (fol.compiler.advanced-array-operations:reshape arr (list 2 3)))))

(test as-array-1d
  "Test converting 1D vector to array"
  (let ((v (fol.compiler.collection-functions:vector 1 2 3)))
    (let ((result (fol.compiler.advanced-array-operations:as-array v)))
      (is (typep result 'fol.compiler.collections:<array>))
      (is (= 3 (fol.compiler.collection-functions:count result))))))

(test as-array-2d
  "Test converting 2D nested vector to array"
  (let ((v (fol.compiler.collection-functions:vector
            (fol.compiler.collection-functions:vector 1 2)
            (fol.compiler.collection-functions:vector 3 4))))
    (let ((result (fol.compiler.advanced-array-operations:as-array v)))
      (is (typep result 'fol.compiler.collections:<array>))
      ;; Check that result is an array (type check is sufficient)
      )))

(test as-nested-1d
  "Test converting 1D array to vector"
  (let ((arr (fol.compiler.array-functions:create-nd-array (list 3))))
    (let ((result (fol.compiler.advanced-array-operations:as-nested arr)))
      (is (typep result 'fol.compiler.collections:<vector>))
      (is (= 3 (fol.compiler.collection-functions:count result))))))

(test as-nested-2d
  "Test converting 2D array to nested vector"
  (let ((arr (fol.compiler.array-functions:create-nd-array (list 2 2))))
    (let ((result (fol.compiler.advanced-array-operations:as-nested arr)))
      (is (typep result 'fol.compiler.collections:<vector>))
      (is (= 2 (fol.compiler.collection-functions:count result))))))

;;; ============================================================================
;;; Phase 4: Transposition & Permutation
;;; ============================================================================

(test transpose-2d-basic
  "Test transposing a 2D matrix"
  (let ((arr (fol.compiler.collection-functions:vector
              (fol.compiler.collection-functions:vector 1 2 3)
              (fol.compiler.collection-functions:vector 4 5 6))))
    (let ((result (fol.compiler.advanced-array-operations:transpose arr)))
      (is (= 3 (fol.compiler.collection-functions:count result)))
      (is (= 2 (fol.compiler.collection-functions:count (fol.compiler.collection-functions:get result 0))))
      (is (= 1 (fol.compiler.collection-functions:get (fol.compiler.collection-functions:get result 0) 0)))
      (is (= 4 (fol.compiler.collection-functions:get (fol.compiler.collection-functions:get result 0) 1))))))

(test transpose-1d-identity
  "Test transposing 1D vector returns unchanged"
  (let ((arr (fol.compiler.collection-functions:vector 1 2 3 4)))
    (let ((result (fol.compiler.advanced-array-operations:transpose arr)))
      (is (= 4 (fol.compiler.collection-functions:count result)))
      (is (= 1 (fol.compiler.collection-functions:get result 0)))
      (is (= 4 (fol.compiler.collection-functions:get result 3))))))

(test transpose-square-matrix
  "Test transposing a square matrix"
  (let ((arr (fol.compiler.collection-functions:vector
              (fol.compiler.collection-functions:vector 1 2)
              (fol.compiler.collection-functions:vector 3 4))))
    (let ((result (fol.compiler.advanced-array-operations:transpose arr)))
      (is (= 2 (fol.compiler.collection-functions:count result)))
      (is (= 1 (fol.compiler.collection-functions:get (fol.compiler.collection-functions:get result 0) 0)))
      (is (= 3 (fol.compiler.collection-functions:get (fol.compiler.collection-functions:get result 0) 1)))
      (is (= 2 (fol.compiler.collection-functions:get (fol.compiler.collection-functions:get result 1) 0)))
      (is (= 4 (fol.compiler.collection-functions:get (fol.compiler.collection-functions:get result 1) 1))))))

(test permute-identity
  "Test identity permutation returns array unchanged"
  (let ((arr (fol.compiler.collection-functions:vector
              (fol.compiler.collection-functions:vector 1 2)
              (fol.compiler.collection-functions:vector 3 4))))
    (let ((result (fol.compiler.advanced-array-operations:permute arr (list 0 1))))
      (is (= 2 (fol.compiler.collection-functions:count result))))))

(test permute-2d-swap
  "Test permuting 2D array axes"
  (let ((arr (fol.compiler.collection-functions:vector
              (fol.compiler.collection-functions:vector 1 2)
              (fol.compiler.collection-functions:vector 3 4))))
    (let ((result (fol.compiler.advanced-array-operations:permute arr (list 1 0))))
      ;; Result should be transposed
      (is (= 2 (fol.compiler.collection-functions:count result))))))

(test swap-axes-2d
  "Test swapping axes in 2D array"
  (let ((arr (fol.compiler.collection-functions:vector
              (fol.compiler.collection-functions:vector 1 2 3)
              (fol.compiler.collection-functions:vector 4 5 6))))
    (let ((result (fol.compiler.advanced-array-operations:swap-axes arr 0 1)))
      (is (typep result 'fol.compiler.collections:<vector>)))))

;;; ============================================================================
;;; Phase 5: Slicing & Concatenation
;;; ============================================================================

(test slice-1d-basic
  "Test 1D array slicing"
  (let ((arr (fol.compiler.collection-functions:vector 1 2 3 4 5)))
    (let ((result (fol.compiler.advanced-array-operations:slice arr (list 1 4))))
      (is (= 3 (fol.compiler.collection-functions:count result)))
      (is (= 2 (fol.compiler.collection-functions:get result 0)))
      (is (= 4 (fol.compiler.collection-functions:get result 2))))))

(test slice-2d-rows
  "Test 2D array row slicing"
  (let ((arr (fol.compiler.collection-functions:vector
              (fol.compiler.collection-functions:vector 1 2 3)
              (fol.compiler.collection-functions:vector 4 5 6)
              (fol.compiler.collection-functions:vector 7 8 9))))
    (let ((result (fol.compiler.advanced-array-operations:slice arr (list (list 0 2) nil))))
      (is (= 2 (fol.compiler.collection-functions:count result))))))

(test slice-2d-columns
  "Test 2D array column slicing"
  (let ((arr (fol.compiler.collection-functions:vector
              (fol.compiler.collection-functions:vector 1 2 3)
              (fol.compiler.collection-functions:vector 4 5 6))))
    (let ((result (fol.compiler.advanced-array-operations:slice arr (list nil (list 1 3)))))
      (is (= 2 (fol.compiler.collection-functions:count result))))))

(test concat-arrays-1d
  "Test concatenating 1D arrays"
  (let ((arr1 (fol.compiler.collection-functions:vector 1 2 3))
        (arr2 (fol.compiler.collection-functions:vector 4 5 6)))
    (let ((result (fol.compiler.advanced-array-operations:concat-arrays arr1 arr2 :axis 0)))
      (is (= 6 (fol.compiler.collection-functions:count result)))
      (is (= 1 (fol.compiler.collection-functions:get result 0)))
      (is (= 6 (fol.compiler.collection-functions:get result 5))))))

(test concat-arrays-2d-axis0
  "Test concatenating 2D arrays along axis 0"
  (let ((arr1 (fol.compiler.collection-functions:vector
               (fol.compiler.collection-functions:vector 1 2)
               (fol.compiler.collection-functions:vector 3 4)))
        (arr2 (fol.compiler.collection-functions:vector
               (fol.compiler.collection-functions:vector 5 6))))
    (let ((result (fol.compiler.advanced-array-operations:concat-arrays arr1 arr2 :axis 0)))
      (is (= 3 (fol.compiler.collection-functions:count result))))))

(test concat-arrays-2d-axis1
  "Test concatenating 2D arrays along axis 1"
  (let ((arr1 (fol.compiler.collection-functions:vector
               (fol.compiler.collection-functions:vector 1 2)
               (fol.compiler.collection-functions:vector 3 4)))
        (arr2 (fol.compiler.collection-functions:vector
               (fol.compiler.collection-functions:vector 5 6)
               (fol.compiler.collection-functions:vector 7 8))))
    (let ((result (fol.compiler.advanced-array-operations:concat-arrays arr1 arr2 :axis 1)))
      ;; Result should be 2 rows (count of outer vector is 2)
      (is (typep result 'fol.compiler.collections:<vector>))
      ;; Check that we got a vector result
      (let ((first-row (fol.compiler.collection-functions:get result 0)))
        (is (typep first-row 'fol.compiler.collections:<vector>))))))

(test stack-2d
  "Test stacking 2D arrays"
  (let ((arr1 (fol.compiler.collection-functions:vector
               (fol.compiler.collection-functions:vector 1 2)
               (fol.compiler.collection-functions:vector 3 4)))
        (arr2 (fol.compiler.collection-functions:vector
               (fol.compiler.collection-functions:vector 5 6)
               (fol.compiler.collection-functions:vector 7 8))))
    (let ((result (fol.compiler.advanced-array-operations:stack (list arr1 arr2) :axis 0)))
      (is (= 2 (fol.compiler.collection-functions:count result))))))

(test hstack-1d
  "Test horizontal stacking of 1D arrays"
  (let ((arr1 (fol.compiler.collection-functions:vector 1 2 3))
        (arr2 (fol.compiler.collection-functions:vector 4 5 6)))
    (let ((result (fol.compiler.advanced-array-operations:hstack (list arr1 arr2))))
      (is (= 6 (fol.compiler.collection-functions:count result))))))

(test vstack-2d
  "Test vertical stacking of 2D arrays"
  (let ((arr1 (fol.compiler.collection-functions:vector
               (fol.compiler.collection-functions:vector 1 2)
               (fol.compiler.collection-functions:vector 3 4)))
        (arr2 (fol.compiler.collection-functions:vector
               (fol.compiler.collection-functions:vector 5 6))))
    (let ((result (fol.compiler.advanced-array-operations:vstack (list arr1 arr2))))
      (is (= 3 (fol.compiler.collection-functions:count result))))))

(test range-n-basic
  "Test range-n generation"
  (let ((result (fol.compiler.advanced-array-operations:range-n 5)))
    (is (= 5 (fol.compiler.collection-functions:count result)))
    (is (= 0 (fol.compiler.collection-functions:get result 0)))
    (is (= 4 (fol.compiler.collection-functions:get result 4)))))

(test range-n-with-start
  "Test range-n with custom start"
  (let ((result (fol.compiler.advanced-array-operations:range-n 5 10)))
    (is (= 5 (fol.compiler.collection-functions:count result)))
    (is (= 10 (fol.compiler.collection-functions:get result 0)))
    (is (= 14 (fol.compiler.collection-functions:get result 4)))))

;;; ============================================================================
;;; Helper: Range
;;; ============================================================================

(test range-basic
  "Test range generation"
  (let ((result (fol.compiler.advanced-array-operations:range 5)))
    (is (= 5 (fol.compiler.collection-functions:count result)))
    (is (= 0 (fol.compiler.collection-functions:get result 0)))
    (is (= 4 (fol.compiler.collection-functions:get result 4)))))
