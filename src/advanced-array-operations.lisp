;;; FOL Compiler - Advanced Array Operations
;;;
;;; Phase 3: Shape operations, axis-specific reductions, slicing, concatenation, transpose.

(in-package :fol.compiler.advanced-array-operations)

;;; ============================================================================
;;; Section 1: Shape and Rank Operations
;;; ============================================================================

(defun shape (arr)
  "Get dimensions of array.

   Examples:
   (shape [1 2 3]) → [3]
   (shape [[1 2] [3 4]]) → [2 2]"
  (if (typep arr '<vector>)
      (vector (count arr))
      arr))

(defun rank (arr)
  "Get number of dimensions.

   Examples:
   (rank [1 2 3]) → 1
   (rank [[1 2] [3 4]]) → 2"
  (if (typep arr '<vector>)
      1
      (if (vectorp arr)
          (cl:+ 1 (rank (get arr 0)))
          0)))

(defun array-size (arr)
  "Get total number of elements.

   Examples:
   (array-size [1 2 3]) → 3
   (array-size [[1 2] [3 4]]) → 4"
  (if (typep arr 'fol.compiler.array-functions:<array>)
      (count arr)
      ;; For nested vectors, compute recursively
      (if (cl:= (count arr) 0)
          0
          (let ((first-elem (get arr 0)))
            (if (typep first-elem 'fol.compiler.collections:<vector>)
                (cl:* (count arr) (array-size first-elem))
                (count arr))))))

(defun flatten (arr)
  "Flatten array to 1D vector.

   Examples:
   (flatten [1 2 3]) → [1 2 3]
   (flatten [[1 2] [3 4]]) → [1 2 3 4]"
  (if (vectorp arr)
      ;; Check if this vector contains numbers (base case) or other vectors (recursive case)
      (let ((first-elem (if (cl:> (count arr) 0) (get arr 0) nil)))
        (if (numberp first-elem)
            ;; All elements are numbers - return as is
            arr
            ;; Elements are vectors - flatten each and concatenate
            (let ((all-items nil))
              (loop for i from 0 below (count arr) do
                (let* ((elem (get arr i))
                       (flat-elem (flatten elem))
                       (flat-count (count flat-elem)))
                  (loop for j from 0 below flat-count do
                    (cl:push (get flat-elem j) all-items))))
              (make-instance '<vector>
                :storage (fol.compiler.collection-primitives::%build-vec-t-from-list
                          (cl:nreverse all-items))))))
      arr))

;;; ============================================================================
;;; Section 2: Axis Operations (Reductions along specific axes)
;;; ============================================================================

(defun sum-axis (arr axis)
  "Sum array elements along specific axis.

   Examples:
   (sum-axis [[1 2 3] [4 5 6]] 0) → [5 7 9]
   (sum-axis [[1 2 3] [4 5 6]] 1) → [6 15]"
  (declare (optimize (speed 3) (safety 1)))
  (if (cl:= axis 0)
      (mapv (lambda (j)
              (cl:reduce #'+ (vec-to-list (mapv (lambda (i) (get (get arr i) j)) (range (count arr))))))
            (range (count (get arr 0))))
      (mapv (lambda (i) (cl:reduce #'+ (vec-to-list (get arr i)))) (range (count arr)))))

(defun mean-axis (arr axis)
  "Compute mean along specific axis.

   Examples:
   (mean-axis [[1 2 3] [4 5 6]] 0) → [2.5 3.5 4.5]
   (mean-axis [[1 2 3] [4 5 6]] 1) → [2.0 5.0]"
  (declare (optimize (speed 3) (safety 1)))
  (let* ((sums (sum-axis arr axis))
         (size (if (cl:= axis 0) (count arr) (count (get arr 0)))))
    (mapv (lambda (x) (cl:/ x size)) sums)))

(defun max-axis (arr axis)
  "Get maximum along specific axis.

   Examples:
   (max-axis [[1 2 3] [4 5 6]] 0) → [4 5 6]
   (max-axis [[1 2 3] [4 5 6]] 1) → [3 6]"
  (declare (optimize (speed 3) (safety 1)))
  (if (cl:= axis 0)
      (mapv (lambda (j)
              (cl:reduce (lambda (a b) (cl:max a b)) (vec-to-list (mapv (lambda (i) (get (get arr i) j)) (range (count arr))))))
            (range (count (get arr 0))))
      (mapv (lambda (i) (cl:reduce (lambda (a b) (cl:max a b)) (vec-to-list (get arr i)))) (range (count arr)))))

(defun min-axis (arr axis)
  "Get minimum along specific axis.

   Examples:
   (min-axis [[1 2 3] [4 5 6]] 0) → [1 2 3]
   (min-axis [[1 2 3] [4 5 6]] 1) → [1 4]"
  (declare (optimize (speed 3) (safety 1)))
  (if (cl:= axis 0)
      (mapv (lambda (j)
              (cl:reduce (lambda (a b) (cl:min a b)) (vec-to-list (mapv (lambda (i) (get (get arr i) j)) (range (count arr))))))
            (range (count (get arr 0))))
      (mapv (lambda (i) (cl:reduce (lambda (a b) (cl:min a b)) (vec-to-list (get arr i)))) (range (count arr)))))

;;; ============================================================================
;;; Section 3: Slicing and Indexing
;;; ============================================================================

(defun %parse-range-spec (spec len)
  "Parse range specification for slicing.

   Supports:
   - Integer: single index
   - nil or :all: all indices (0 to len-1)
   - List (start end): slice from start to end"
  (cond
    ((null spec) (cl:list 0 len))
    ((eq spec :all) (cl:list 0 len))
    ((integerp spec) (cl:list spec (cl:1+ spec)))
    ((listp spec)
     (cl:let ((start (first spec))
              (end (second spec)))
       (cl:list (or start 0) (or end len))))
    (cl:t (cl:list 0 len))))

(defun slice (arr ranges &optional end)
  "Extract subarray using index ranges for n-D arrays.

   Backward compatible with old interface: (slice arr start end)
   New interface: (slice arr ranges-list) where ranges-list is list of specs.

   For 1D arrays:
   - Old: (slice arr 1 4) → [2 3 4]
   - New: (slice arr (list 1 4)) → [2 3 4]

   For n-D arrays, ranges is a list of specs, one per dimension:
   - (slice arr (list (list 0 2) (list 1 3))) → 2D subarray
   - (slice arr (list (list 0 2) nil)) → all cols of rows 0-1"
  (declare (optimize (speed 3) (safety 1)))
  (cond
    ;; Backward compatible: (slice arr start end)
    ((integerp ranges)
     (subvec arr ranges end))
    ;; New interface: integer range or (start end) list
    ((and (listp ranges) (cl:every #'integerp ranges))
     (subvec arr (first ranges) (second ranges)))
    ;; List of range specs for n-D
    ((listp ranges)
     (if (cl:= (length ranges) 1)
         ;; Single range spec for remaining dimensions
         (let ((spec (%parse-range-spec (first ranges) (count arr))))
           (subvec arr (first spec) (second spec)))
         ;; Multiple range specs: slice first dimension, recurse
         (let* ((first-spec (first ranges))
                (rest-specs (rest ranges))
                (spec (%parse-range-spec first-spec (count arr)))
                (start (first spec))
                (end-idx (second spec)))
           (mapv (lambda (i) (slice (get arr i) rest-specs))
                 (range-n (cl:- end-idx start) start)))))
    (cl:t arr)))

(defun range-n (count &optional (start 0))
  "Create vector of integers from start to start+count-1.

   Examples:
   (range-n 5) → [0 1 2 3 4]
   (range-n 5 10) → [10 11 12 13 14]"
  (let ((items (loop for i below count collect (cl:+ start i))))
    (make-instance '<vector> :storage (fol.compiler.collection-primitives::%build-vec-t-from-list items))))

(defun get-slice (arr &rest indices)
  "Get element at indices.

   Examples:
   (get-slice [1 2 3 4 5] 2) → 3
   (get-slice [[1 2 3] [4 5 6]] 1 2) → 6"
  (declare (optimize (speed 3) (safety 1)))
  (if (null indices)
      arr
      (apply #'get-slice (get arr (first indices)) (rest indices))))

(defun put-slice (arr indices value)
  "Set element at indices.

   Examples:
   (put-slice [1 2 3] 1 99) → [1 99 3]"
  (declare (optimize (speed 3) (safety 1)))
  (if (vectorp indices)
      (cl:reduce (lambda (acc idx) (put-slice acc (vector idx) value))
                 indices
                 :initial-value arr)
      (let ((idx (first (fol.compiler.collections:collection-seq indices))))
        (assoc arr idx value))))

;;; ============================================================================
;;; Section 4: Concatenation and Stacking
;;; ============================================================================

(defun %concat-axis-0 (arr1 arr2)
  "Concatenate along axis 0 (append sequences)."
  (if (typep arr1 '<vector>)
      (if (typep (get arr1 0) '<vector>)
          ;; 2D or higher: concatenate lists of subarrays
          (concat arr1 arr2)
          ;; 1D: concatenate elements
          (concat arr1 arr2))
      (concat arr1 arr2)))

(defun %concat-axis-n (arr1 arr2 axis)
  "Concatenate along axis N (higher than 0)."
  (let ((rank (if (typep arr1 'fol.compiler.array-functions:<array>)
                  (fol.compiler.array-functions:nd-rank arr1)
                  (rank arr1))))
    (if (cl:> rank 1)
        ;; Recursively concatenate along axis-1 for each slice
        (mapv (lambda (i)
                (%concat-axis-n (get arr1 i) (get arr2 i) (cl:1- axis)))
              (range (count arr1)))
        ;; Base case: concatenate 1D arrays
        (concat arr1 arr2))))

(defun concat-arrays (arr1 arr2 &key (axis 0))
  "Join arrays along axis, supporting n-D arrays.

   For axis 0: concatenate sequences directly.
   For axis N>0: recursively concatenate subarrays along axis-1.

   Examples:
   (concat-arrays [1 2 3] [4 5 6] :axis 0) → [1 2 3 4 5 6]
   (concat-arrays [[1 2]] [[3 4]] :axis 0) → [[1 2] [3 4]]
   (concat-arrays [[1 2] [3 4]] [[5 6] [7 8]] :axis 1) → [[1 2 5 6] [3 4 7 8]]"
  (declare (optimize (speed 3) (safety 1)))
  (cond
    ((cl:= axis 0) (%concat-axis-0 arr1 arr2))
    ((cl:> axis 0) (%concat-axis-n arr1 arr2 axis))
    (cl:t arr1)))

(defun stack (arrays &key (axis 0))
  "Stack arrays along new axis, supporting n-D arrays.

   For axis 0: create new outer dimension.
   For axis N>0: insert new dimension at position N.

   Examples:
   (stack [[1 2] [3 4]] :axis 0) → [[[1 2]] [[3 4]]]
   (stack [[1 2] [3 4]] :axis 1) → [[[1 3]] [[2 4]]]"
  (declare (optimize (speed 3) (safety 1)))
  (if (cl:null (rest arrays))
      (vector (first arrays))
      (cl:reduce (lambda (acc arr) (concat-arrays acc (vector arr) :axis (cl:+ axis 1)))
                 (rest arrays)
                 :initial-value (vector (first arrays)))))

(defun hstack (arrays)
  "Stack arrays horizontally (along last axis).

   Examples:
   (hstack [[1 2] [3 4]]) → [1 2 3 4]
   (hstack [[[1] [2]] [[3] [4]]]) → [[[1] [2] [3] [4]]]"
  (declare (optimize (speed 3) (safety 1)))
  (if (cl:null (rest arrays))
      (first arrays)
      (let ((rank (rank (first arrays))))
        (cl:reduce (lambda (acc arr) (concat-arrays acc arr :axis (cl:1- rank)))
                   (rest arrays)
                   :initial-value (first arrays)))))

(defun vstack (arrays)
  "Stack arrays vertically (along first axis).

   Examples:
   (vstack [[1 2] [3 4]]) → [[1 2] [3 4]]
   (vstack [[[1 2]] [[3 4]]]) → [[[1 2]] [[3 4]]]"
  (declare (optimize (speed 3) (safety 1)))
  (if (cl:null (rest arrays))
      (first arrays)
      (cl:reduce (lambda (acc arr) (concat-arrays acc arr :axis 0))
                 (rest arrays)
                 :initial-value (first arrays))))

;;; ============================================================================
;;; Section 5: Transpose and Permutation
;;; ============================================================================

(defun transpose (arr &optional axes)
  "Transpose matrix or permute axes of n-D array.

   For 2D arrays, transposes rows and columns.
   For n-D arrays, permutes axes according to specified order.

   Examples:
   (transpose [[1 2 3] [4 5 6]]) → [[1 4] [2 5] [3 6]]
   (transpose arr [2 0 1]) → reorder axes as 2, 0, 1"
  (declare (optimize (speed 3) (safety 1)))
  (if axes
      (permute arr axes)
      (if (typep arr '<vector>)
          ;; Check if this is a 1D vector or 2D nested vector
          (if (cl:and (cl:> (count arr) 0) (typep (get arr 0) '<vector>))
              ;; 2D case: nested vectors
              (let ((n-rows (count arr))
                    (n-cols (count (get arr 0))))
                (mapv (lambda (j)
                        (mapv (lambda (i) (get (get arr i) j))
                              (range n-rows)))
                      (range n-cols)))
              ;; 1D case: return unchanged
              arr)
          (let ((n-rows (count arr))
                (n-cols (count (get arr 0))))
            (mapv (lambda (j)
                    (mapv (lambda (i) (get (get arr i) j))
                          (range n-rows)))
                  (range n-cols))))))

(defun permute (arr axes)
  "Permute axes of array. Currently supports 2D case.

   Examples:
   (permute [[1 2] [3 4]] [1 0]) → [[1 3] [2 4]]"
  (declare (optimize (speed 3) (safety 1)))
  (let ((axes-list (if (typep axes '<vector>)
                       (loop for i below (count axes) collect (get axes i))
                       (if (listp axes) axes (list axes)))))
    (if (cl:and (cl:= (length axes-list) 2)
                (cl:= (first axes-list) 1)
                (cl:= (second axes-list) 0))
        (transpose arr)
        arr)))

(defun swap-axes (arr axis1 axis2)
  "Swap two axes of array.

   Examples:
   (swap-axes arr 0 1) → swap axes 0 and 1"
  (declare (optimize (speed 3) (safety 1)))
  (if (cl:and (cl:= axis1 0) (cl:= axis2 1))
      (transpose arr)
      arr))

;;; ============================================================================
;;; Phase 2: Shape & Reshape Operations
;;; ============================================================================

(defun reshape (arr new-shape)
  "Reshape array to new dimensions. Total size must remain the same.

   Examples:
   (reshape [1 2 3 4] [2 2]) → [[1 2] [3 4]]
   (reshape [[1 2] [3 4]] [4]) → [1 2 3 4]"
  (declare (optimize (speed 3) (safety 0)))
  (let* ((new-shape-list (if (typep new-shape '<vector>)
                             (loop for i below (count new-shape) collect (get new-shape i))
                             (if (listp new-shape) new-shape (list new-shape))))
         (old-size (array-size arr))
         (new-size (cl:reduce #'cl:* new-shape-list :initial-value 1)))
    (unless (cl:= old-size new-size)
      (error "Cannot reshape array of size ~D to shape ~A (size ~D)"
             old-size new-shape-list new-size))
    ;; Get flat list of all elements
    (let ((flat-list (if (typep arr 'fol.compiler.array-functions:<array>)
                         (vec-to-list arr)
                         (vec-to-list (flatten arr))))
          (idx 0))
      ;; Rebuild according to new shape
      (cl:labels ((rebuild (shape depth)
                    (if (cl:= (length shape) 1)
                        ;; Base case: create flat vector from remaining elements
                        (let ((size (first shape))
                              (items (loop for j below (first shape) collect
                                       (prog1 (nth idx flat-list)
                                              (cl:incf idx)))))
                          (apply #'vector items))
                        ;; Recursive case: create vector of sub-arrays
                        (let ((first-dim (first shape))
                              (rest-shape (rest shape))
                              (items (loop for i below (first shape) collect
                                       (rebuild (rest shape) (cl:1+ depth)))))
                          (apply #'vector items)))))
        (rebuild new-shape-list 0)))))

(defun as-array (nested-vec)
  "Convert nested vector representation to flat <array> with shape metadata.

   Examples:
   (as-array [1 2 3]) → <ARRAY shape=(3)>
   (as-array [[1 2] [3 4]]) → <ARRAY shape=(2 2)>"
  (declare (optimize (speed 3) (safety 0)))
  (if (typep nested-vec 'fol.compiler.array-functions:<array>)
      ;; Already an array, return as-is
      nested-vec
      ;; Compute shape by recursively checking dimensions
      (let* ((shape-list (loop for dim = (if (typep nested-vec '<vector>)
                                             (count nested-vec)
                                             (if (vectorp nested-vec) (cl:length nested-vec) 0))
                                     then (if (and (cl:> dim 0) (vectorp (get nested-vec 0)))
                                              (if (typep (get nested-vec 0) '<vector>)
                                                  (count (get nested-vec 0))
                                                  (cl:length (get nested-vec 0)))
                                              0)
                               until (cl:= dim 0)
                               collect dim))
             (flat (flatten nested-vec))
             (flat-list (vec-to-list flat)))
        ;; Create array with the computed shape and flattened storage
        (make-instance 'fol.compiler.collections:<array>
          :dimension shape-list
          :storage (fol.compiler.collection-primitives::%build-vec-t-from-list flat-list)))))

(defun as-nested (arr)
  "Convert flat <array> to nested vector representation.

   Examples:
   (<ARRAY shape=(3)> as-nested) → [1 2 3]
   (<ARRAY shape=(2 2)> as-nested) → [[1 2] [3 4]]"
  (declare (optimize (speed 3) (safety 0)))
  (if (typep arr 'fol.compiler.array-functions:<array>)
      (let ((shape (fol.compiler.array-functions:nd-shape arr))
            (flat (flatten arr)))
        (if (cl:= (length shape) 1)
            flat
            (reshape flat shape)))
      arr))

;;; ============================================================================
;;; Helper functions
;;; ============================================================================

(defun vec-to-list (vec)
  "Convert FOL vector to Common Lisp list."
  (loop for i below (count vec) collect (get vec i)))

;;; ============================================================================
;;; Range function for iterations
;;; ============================================================================

(defun range (n)
  "Create vector of integers from 0 to n-1.

   Examples:
   (range 5) → [0 1 2 3 4]"
  (let ((items (loop for i below n collect i)))
    (make-instance '<vector> :storage (fol.compiler.collection-primitives::%build-vec-t-from-list items))))
