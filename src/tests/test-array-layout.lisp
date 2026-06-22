;;; FOL Compiler Tests - Array Column-Major Layout Verification
;;;
;;; Tests to verify that FOL arrays use column-major (Fortran-style) memory layout
;;; where the leftmost index varies fastest.
;;;
;;; Reference: docs/ARRAY_LAYOUT_COLUMN_MAJOR.md

(in-package :fol.compiler.tests)

(in-suite collections-tests)

;;; ============================================================================
;;; Column-Major Index Calculation Verification
;;; ============================================================================

(test column-major-idx-2d-basic
  "Verify column-major indexing for 2D arrays (3x4)"
  (let ((shape (vector 3 4)))
    ;; Element (0,0) should map to flat index 0
    (is (= 0 (fol.compiler.collection-primitives::%column-major-idx shape (vector 0 0))))
    ;; Element (1,0) should map to flat index 1 (leftmost varies fastest)
    (is (= 1 (fol.compiler.collection-primitives::%column-major-idx shape (vector 1 0))))
    ;; Element (2,0) should map to flat index 2
    (is (= 2 (fol.compiler.collection-primitives::%column-major-idx shape (vector 2 0))))
    ;; Element (0,1) should map to flat index 3 (next column starts)
    (is (= 3 (fol.compiler.collection-primitives::%column-major-idx shape (vector 0 1))))
    ;; Element (2,3) should map to flat index 11 (last element)
    (is (= 11 (fol.compiler.collection-primitives::%column-major-idx shape (vector 2 3))))))

(test column-major-idx-2d-formula
  "Verify formula: flat_index = i0 + i1*d0"
  (let ((shape (vector 3 4)))
    ;; Test all 12 elements
    (dotimes (col 4)
      (dotimes (row 3)
        (let ((expected (+ row (* col 3)))
              (actual (fol.compiler.collection-primitives::%column-major-idx
                       shape (vector row col))))
          (is (= expected actual)
              (format nil "Index (~d, ~d): expected ~d, got ~d"
                      row col expected actual)))))))

(test column-major-idx-3d
  "Verify column-major indexing for 3D arrays (3x4x5)"
  (let ((shape (vector 3 4 5)))
    ;; Element (0,0,0) → 0
    (is (= 0 (fol.compiler.collection-primitives::%column-major-idx shape (vector 0 0 0))))
    ;; Element (1,0,0) → 1
    (is (= 1 (fol.compiler.collection-primitives::%column-major-idx shape (vector 1 0 0))))
    ;; Element (0,1,0) → 3 (0 + 1*3 + 0*12)
    (is (= 3 (fol.compiler.collection-primitives::%column-major-idx shape (vector 0 1 0))))
    ;; Element (0,0,1) → 12 (0 + 0*3 + 1*12)
    (is (= 12 (fol.compiler.collection-primitives::%column-major-idx shape (vector 0 0 1))))
    ;; Element (1,2,3) → 1 + 6 + 36 = 43
    (is (= 43 (fol.compiler.collection-primitives::%column-major-idx shape (vector 1 2 3))))))

(test column-major-idx-4d
  "Verify column-major indexing generalizes to 4D"
  (let ((shape (vector 2 3 4 5)))
    ;; Strides: 1, 2, 6, 24
    ;; Element (1,1,1,1) → 1 + 1*2 + 1*6 + 1*24 = 33
    (is (= 33 (fol.compiler.collection-primitives::%column-major-idx shape (vector 1 1 1 1))))
    ;; Element (0,0,0,1) → 0 + 0 + 0 + 1*24 = 24
    (is (= 24 (fol.compiler.collection-primitives::%column-major-idx shape (vector 0 0 0 1))))))

;;; ============================================================================
;;; Column-Major Memory Layout Verification
;;; ============================================================================

(test column-major-contiguity-axis-0
  "Verify that iterating along axis 0 accesses contiguous memory"
  ;; For shape (3,4), incrementing first index (row) in memory should be contiguous
  (let ((shape (vector 3 4)))
    ;; All column 0 indices (0,0), (1,0), (2,0) should map to 0, 1, 2
    (let ((col-0-indices (loop for row from 0 to 2
                               collect (fol.compiler.collection-primitives::%column-major-idx
                                        shape (vector row 0)))))
      (is (equal '(0 1 2) col-0-indices))
      ;; Verify they're truly contiguous (sequential)
      (is (= 3 (length col-0-indices)))
      (is (= 0 (first col-0-indices)))
      (is (= 1 (second col-0-indices)))
      (is (= 2 (third col-0-indices))))))

(test column-major-stride-axis-1
  "Verify that iterating along axis 1 has stride pattern"
  ;; For shape (3,4), incrementing second index (column) has stride 3
  (let ((shape (vector 3 4)))
    ;; All row 0 indices (0,0), (0,1), (0,2), (0,3) should map to 0, 3, 6, 9
    (let ((row-0-indices (loop for col from 0 to 3
                               collect (fol.compiler.collection-primitives::%column-major-idx
                                        shape (vector 0 col)))))
      (is (equal '(0 3 6 9) row-0-indices))
      ;; Verify stride is 3
      (is (= 3 (- (second row-0-indices) (first row-0-indices)))))))

;;; ============================================================================
;;; Array Creation and Access with Column-Major Layout
;;; ============================================================================

(test array-creation-and-indexing
  "Create a <f64-array> and verify column-major indexing"
  (let* ((shape '(3 4))
         ;; Column-major layout: (0,0), (1,0), (2,0), (0,1), (1,1), (2,1), ...
         (data (vector 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 11.0 12.0))
         (arr (make-instance 'fol.compiler.collections:<f64-array>
                :dimension shape
                :storage (fol.compiler.collection-primitives::%build-vec-f64-from-list
                          (coerce data 'list)))))
    ;; Verify collection-size
    (is (= 12 (fol.compiler.collections:collection-size arr)))

    ;; Verify that accessing elements via indexing uses column-major
    ;; Element (0,0) should be 1.0 (first element)
    (is (= 1.0 (fol.compiler.collection-primitives::%vec-f64-ref
                (fol.compiler.collections:storage arr)
                0)))
    ;; Element (1,0) should be 2.0 (second element)
    (is (= 2.0 (fol.compiler.collection-primitives::%vec-f64-ref
                (fol.compiler.collections:storage arr)
                1)))
    ;; Element (2,0) should be 3.0 (third element)
    (is (= 3.0 (fol.compiler.collection-primitives::%vec-f64-ref
                (fol.compiler.collections:storage arr)
                2)))
    ;; Element (0,1) should be 4.0 (first element of second column)
    (is (= 4.0 (fol.compiler.collection-primitives::%vec-f64-ref
                (fol.compiler.collections:storage arr)
                3)))))

;;; ============================================================================
;;; Documentation: Mapping Between Coordinates and Memory
;;; ============================================================================

(test column-major-documentation-2d
  "Document expected memory layout for 3x4 array"
  ;; Shape: (3, 4) = 3 rows × 4 columns
  ;; Conceptual array:
  ;;   col0 col1 col2 col3
  ;; row0  1    4    7   10
  ;; row1  2    5    8   11
  ;; row2  3    6    9   12
  ;;
  ;; Column-major memory (FOL):
  ;; [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
  ;;  0  1  2  3  4  5  6  7  8   9  10  11
  ;;
  ;; Memory is organized by COLUMNS (leftmost index varies fastest)

  (let ((shape (vector 3 4)))
    ;; Verify this layout via index calculation
    (let ((expected-flat-order
           '((0 0 . 0)  (1 0 . 1)  (2 0 . 2)   ;; Column 0
             (0 1 . 3)  (1 1 . 4)  (2 1 . 5)   ;; Column 1
             (0 2 . 6)  (1 2 . 7)  (2 2 . 8)   ;; Column 2
             (0 3 . 9)  (1 3 . 10) (2 3 . 11)))) ;; Column 3
      (loop for (row col . expected-flat) in expected-flat-order
            do (let ((actual-flat (fol.compiler.collection-primitives::%column-major-idx
                                   shape (vector row col))))
                 (is (= expected-flat actual-flat)
                     (format nil "(~d, ~d) should map to flat index ~d, got ~d"
                             row col expected-flat actual-flat)))))))

;;; ============================================================================
;;; Stride Calculation (for documentation/future use)
;;; ============================================================================

(test column-major-stride-calculation
  "Document stride calculation for column-major layout"
  ;; For 3D shape (3, 4, 5):
  ;; stride[0] = 1
  ;; stride[1] = 3
  ;; stride[2] = 3*4 = 12
  ;;
  ;; To access element (i0, i1, i2):
  ;; flat_index = i0*1 + i1*3 + i2*12

  (let ((shape (vector 3 4 5)))
    ;; Calculate strides manually
    (let ((strides (make-array 3)))
      (setf (aref strides 0) 1)
      (setf (aref strides 1) 3)  ;; 3
      (setf (aref strides 2) 12) ;; 3*4

      ;; Verify against actual calculation
      (let ((test-indices (list (vector 0 0 0)
                                (vector 1 0 0)
                                (vector 0 1 0)
                                (vector 0 0 1)
                                (vector 1 2 3))))
        (loop for indices in test-indices
              do (let* ((i0 (aref indices 0))
                        (i1 (aref indices 1))
                        (i2 (aref indices 2))
                        (expected (+ (* i0 1) (* i1 3) (* i2 12)))
                        (actual (fol.compiler.collection-primitives::%column-major-idx
                                 shape indices)))
                   (is (= expected actual))))))))

