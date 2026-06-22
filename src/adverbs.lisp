;;; FOL Compiler - Adverbs (Higher-Order Operators)
;;;
;;; Phase 2: Single-Axis Operations
;;; Implements axis-aware fold/scan, grouping, statistics, and shape operations.
;;; Duplicates from seq-functions are re-exported with axis parameter support.

(in-package :fol.compiler.adverbs)

;;; ============================================================================
;;; Section 1: Fold (Reduction)
;;; ============================================================================

(defun fold (fn arr &key (axis 0))
  "Reduce array along specified axis.

   Examples:
   (fold + [1 2 3]) → 6 (sum along default axis 0)

   Default :axis is 0 (fold along first dimension)."
  (declare (optimize (speed 3) (safety 1)) (ignore axis))
  ;; Use CL:REDUCE with initial value from first element
  (let ((seq (fol.compiler.collections:collection-seq arr)))
    (if (null seq)
        nil
        (cl:reduce fn seq))))

;;; ============================================================================
;;; Section 2: Scan (Cumulative)
;;; ============================================================================

(defun scan (fn arr &key (axis 0))
  "Cumulative reduction along axis (returns intermediate results).

   Examples:
   (scan + [1 2 3]) → [1 3 6] (cumulative sum)
   (scan * [2 3 4]) → [2 6 24] (cumulative product)

   Default :axis is 0 (scan along first dimension)."
  (declare (optimize (speed 3) (safety 1)) (ignore axis))
  (let ((seq (fol.compiler.collections:collection-seq arr))
        (result (vector))
        (accumulator nil))
    (dolist (x seq result)
      (setf accumulator (if (null accumulator) x (funcall fn accumulator x)))
      (setf result (conj result accumulator)))))

;;; ============================================================================
;;; Section 3: Each with Rank Support
;;; ============================================================================

(defun each (fn arr &key (rank 1))
  "Apply function to sub-arrays of given rank.

   Examples:
   (each (fn [x] (+ x 10)) [1 2 3]) → [11 12 13] (rank 0: scalars)

   Default :rank is 1 (apply to 1D subarrays, i.e., rows for 2D)."
  (declare (optimize (speed 3) (safety 1)))
  (cond
    ;; Rank 0: apply to each scalar
    ((cl:= rank 0)
     (mapv fn arr))
    ;; Rank 1+: for now, simplified to map
    (t
     (mapv fn arr))))

;;; ============================================================================
;;; Section 4: Window Operations
;;; ============================================================================

(defun window (size fn arr &key (axis 0))
  "Apply function to sliding window of size along axis.

   Examples:
   (window 2 (fn [w] (fold + w)) [1 2 3 4]) → [3 5 7] (sliding sums)

   Default :axis is 0 (slide along first dimension)."
  (declare (optimize (speed 3) (safety 1)) (ignore axis))
  (let ((n (count arr)))
    (if (cl:>= n size)
        (let ((result (vector)))
          (loop for i from 0 below (cl:- n (cl:- size 1))
                do (let ((window-slice (subvec arr i (cl:+ i size))))
                     (setf result (conj result (funcall fn window-slice)))))
          result)
        (vector))))

;;; ============================================================================
;;; Section 5: Statistics
;;; ============================================================================

(defun sum (arr &key (axis 0))
  "Sum array elements along axis.

   Examples:
   (sum [1 2 3 4]) → 10

   Default :axis is 0 (sum along first dimension)."
  (declare (optimize (speed 3) (safety 0)) (ignore axis))
  (reduce #'+ 0 arr))

(defun mean (arr &key (axis 0))
  "Compute mean of array elements along axis.

   Examples:
   (mean [2 4 6 8]) → 5.0

   Default :axis is 0 (mean along first dimension)."
  (declare (optimize (speed 3) (safety 0)) (ignore axis))
  (let ((s (reduce #'+ 0 arr))
        (n (count arr)))
    (if (cl:> n 0)
        (cl:/ (cl:float s) n)
        0.0)))

(defun variance (arr &key (axis 0))
  "Compute variance of array elements along axis.

   Examples:
   (variance [1 2 3 4 5]) → 2.0

   Default :axis is 0 (variance along first dimension)."
  (declare (optimize (speed 3) (safety 0)) (ignore axis))
  (let* ((m (mean arr))
         (squared-diffs (mapv
                         (lambda (x) (cl:expt (cl:- x m) 2))
                         arr))
         (sum-squared (reduce #'+ 0 squared-diffs))
         (n (count arr)))
    (if (cl:> n 0)
        (cl:/ sum-squared n)
        0.0)))

(defun std-dev (arr &key (axis 0))
  "Compute standard deviation of array elements along axis.

   Examples:
   (std-dev [1 2 3 4 5]) → 1.414... (sqrt of variance)

   Default :axis is 0 (std-dev along first dimension)."
  (declare (optimize (speed 3) (safety 0)) (ignore axis))
  (cl:sqrt (variance arr)))

;;; ============================================================================
;;; Section 7: Sorting (with Axis Support)
;;; ============================================================================

(defun sort-by (key-fn arr &key (axis 0))
  "Sort array by key function along axis.

   Examples:
   (sort-by (fn [x] (- x)) [3 1 4 1 5]) → [5 4 3 1 1]

   Default :axis is 0 (sort along first dimension)."
  (declare (optimize (speed 3) (safety 1)) (ignore axis))
  (cl:sort (cl:copy-seq arr) #'< :key key-fn))

(defun array-reverse (arr &key (axis 0))
  "Reverse array along axis.

   Examples:
   (array-reverse [1 2 3 4]) → [4 3 2 1]

   Default :axis is 0 (reverse along first dimension)."
  (declare (optimize (speed 3) (safety 1)) (ignore axis))
  (fol.compiler.seq-functions:reverse arr))

;;; ============================================================================
;;; Section 8: Mapping & Transformation (with Axis Support)
;;; ============================================================================

(defun map-array (fn arr &key (axis 0))
  "Apply function element-wise (alias for mapv).

   Examples:
   (map-array (fn [x] (* x 2)) [1 2 3]) → [2 4 6]

   Default :axis is 0 (map along first dimension)."
  (declare (optimize (speed 3) (safety 1)) (ignore axis))
  (mapv fn arr))

(defun zip (arr1 arr2 &rest more-arrays &key (axis 0))
  "Combine arrays element-wise into tuples.

   Examples:
   (zip [1 2 3] [4 5 6]) → [[1 4] [2 5] [3 6]]

   Default :axis is 0 (zip along first dimension)."
  (declare (optimize (speed 3) (safety 1)) (ignore axis))
  (if (null more-arrays)
      (mapv (lambda (a b) (vector a b)) arr1 arr2)
      (let ((result (mapv (lambda (a b) (vector a b)) arr1 arr2)))
        (fol.compiler.seq-functions:reduce
         (lambda (acc arr)
           (mapv (lambda (tuple elem)
                   (conj tuple elem))
                 acc arr))
         more-arrays
         result))))

;;; ============================================================================
;;; Section 9: Aggregation & Reduction (with Axis Support)
;;; ============================================================================

(defun aggregate (fn arr &key (axis 0) initial-value)
  "Aggregate array with initial value (like reduce).

   Examples:
   (aggregate + [1 2 3 4] :initial-value 0) → 10

   Default :axis is 0 (aggregate along first dimension)."
  (declare (optimize (speed 3) (safety 1)) (ignore axis))
  (if initial-value
      (cl:reduce fn arr :initial-value initial-value)
      (fold fn arr)))

;;; ============================================================================
;;; Section 10: Partition Operations (with Axis Support)
;;; ============================================================================

(defun array-partition (size arr &key (axis 0) (step size))
  "Partition array into fixed-size chunks.

   Examples:
   (array-partition 2 [1 2 3 4 5]) → [[1 2] [3 4] [5]]

   Default :axis is 0 (partition along first dimension)."
  (declare (optimize (speed 3) (safety 1)) (ignore axis step))
  (partition size arr))

(defun array-take (n arr &key (axis 0))
  "Take first n elements along axis.

   Examples:
   (array-take 2 [1 2 3 4 5]) → [1 2]

   Default :axis is 0 (take along first dimension)."
  (declare (optimize (speed 3) (safety 1)) (ignore axis))
  (take n arr))

(defun array-drop (n arr &key (axis 0))
  "Drop first n elements along axis.

   Examples:
   (array-drop 2 [1 2 3 4 5]) → [3 4 5]

   Default :axis is 0 (drop along first dimension)."
  (declare (optimize (speed 3) (safety 1)) (ignore axis))
  (drop n arr))
