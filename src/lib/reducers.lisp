;;; FOL Library - Reducers
;;;
;;; Parallel reduction operations similar to Clojure's reducers library.
;;; Uses the internal thread pool for parallel execution.

(in-package :fol.lib.reducers)

(defun preduce (fn init coll &optional (n 64))
  "Parallel reduction over a collection.
   Splits COLL into chunks of size N.
   Each chunk is reduced serially starting with (funcall FN) as identity.
   The results are then reduced with the initial value INIT.
   Requires FN to support zero-argument calls to return an identity value."
  (let* ((total-size (length (collection-seq coll))))
    (if (<= total-size n)
        ;; Serial path
        (fol.compiler.seq-functions:reduce fn init coll)
        ;; Parallel path
        (let* ((identity (funcall fn))
               (chunks (%chunk-collection coll n))
               (work-items (mapcar (lambda (chunk)
                                     (submit-work (lambda ()
                                                    (fol.compiler.seq-functions:reduce 
                                                     fn 
                                                     identity 
                                                     chunk))
                                                  nil))
                                   chunks))
               (results (mapcar #'wait-for-work work-items)))
          ;; Combine results with initial value
          (fol.compiler.seq-functions:reduce fn init results)))))

(defun %chunk-collection (coll n)
  "Split collection into chunks of size N."
  (let ((seq (collection-seq coll))
        (chunks nil))
    (loop while seq
          do (let ((chunk nil)
                   (count 0))
               (loop while (and seq (< count n))
                     do (push (pop seq) chunk)
                        (incf count))
               (push (nreverse chunk) chunks)))
    (nreverse chunks)))

(defun fold (combine-fn reduce-fn coll &optional (n 512))
  "Parallel reduction of COLL.
   Splits COLL into chunks of size N (default 512).
   Each chunk is reduced serially using REDUCE-FN.
   The results are combined using COMBINE-FN.
   
   The COMBINE-FN should accept zero arguments to return an identity value,
   two arguments to combine results.
   
   The REDUCE-FN should accept zero arguments to return an identity value,
   two arguments to reduce elements.
   
   This implementation uses the global thread pool."
  (let* ((total-size (length (collection-seq coll))))
    (if (<= total-size n)
        ;; Serial path
        (fol.compiler.seq-functions:reduce reduce-fn (funcall reduce-fn) coll)
        ;; Parallel path
        (let* ((chunks (%chunk-collection coll n))
               (work-items (mapcar (lambda (chunk)
                                     (submit-work (lambda ()
                                                    (fol.compiler.seq-functions:reduce 
                                                     reduce-fn 
                                                     (funcall reduce-fn) 
                                                     chunk))
                                                  nil))
                                   chunks))
               (results (mapcar #'wait-for-work work-items)))
          ;; Combine results
          (fol.compiler.seq-functions:reduce combine-fn (funcall combine-fn) results)))))

;;; Alternative recursive fold for better task distribution if pool supports it
;;; (though here we just submit to the queue).

(defun fold-recursive (combine-fn reduce-fn coll &optional (n 512))
  "A recursive implementation of fold that uses divide-and-conquer strategy."
  (let ((total-size (length (collection-seq coll))))
    (labels ((recur-fold (seq size)
               (if (<= size n)
                   (fol.compiler.seq-functions:reduce reduce-fn (funcall reduce-fn) seq)
                   (let* ((mid (floor size 2))
                          (left-seq (subseq seq 0 mid))
                          (right-seq (subseq seq mid))
                          ;; Submit right half to thread pool
                          (right-task (submit-work #'recur-fold (list right-seq (- size mid))))
                          ;; Process left half in current thread
                          (left-res (recur-fold left-seq mid))
                          (right-res (wait-for-work right-task)))
                     (funcall combine-fn left-res right-res)))))
      (recur-fold (collection-seq coll) total-size))))

(defun aggregate (zero seq-op combine-op coll &optional (n 512))
  "Parallel aggregate in the style of Scala's .par.aggregate(zero)(seqOp, combOp).

   Unlike preduce/fold, SEQ-OP and COMBINE-OP may work on a different type
   from the collection elements, enabling a single parallel pass to build
   accumulators of any shape.

   ZERO       — initial accumulator value, copied fresh for every chunk via
                (funcall zero) if it is a function, or used directly otherwise.
                Use a function (e.g. (fn [] {})) when the zero value is mutable
                or should not be shared across chunks.
   SEQ-OP     — (accumulator element) -> accumulator
                Reduces one element into the chunk accumulator. Called serially
                within each chunk.
   COMBINE-OP — (accumulator accumulator) -> accumulator
                Merges two partial accumulators produced by different chunks.
                Must be associative but need not match SEQ-OP's type contract.
   COLL       — the input collection.
   N          — target chunk size (default 512). Collections smaller than N
                are reduced serially without spawning threads.

   Examples:
     ; Count and collect in one pass
     (aggregate (fn [] (list 0 []))
                (fn [[cnt elems] x] (list (inc cnt) (conj elems x)))
                (fn [[ca ea] [cb eb]] (list (+ ca cb) (concat ea eb)))
                [1 2 3 4 5])
     ; => (5 [1 2 3 4 5])

     ; Build a frequency map in parallel
     (aggregate (fn [] {})
                (fn [m x] (update m x (fnil inc 0)))
                (fn [a b] (merge-with + a b))
                [:a :b :a :c :b :a])
     ; => {:a 3 :b 2 :c 1}"
  (let* ((seq        (collection-seq coll))
         (total-size (length seq)))
    (if (<= total-size n)
        ;; Serial path — no thread overhead for small collections.
        (let ((acc (if (functionp zero) (funcall zero) zero)))
          (dolist (elem seq acc)
            (setf acc (funcall seq-op acc elem))))
        ;; Parallel path — reduce each chunk independently then combine.
        (let* ((chunks     (%chunk-collection coll n))
               (work-items (mapcar (lambda (chunk)
                                     (submit-work
                                      (lambda ()
                                        (let ((acc (if (functionp zero)
                                                       (funcall zero)
                                                       zero)))
                                          (dolist (elem chunk acc)
                                            (setf acc (funcall seq-op acc elem)))))
                                      nil))
                                   chunks))
               (partials   (mapcar #'wait-for-work work-items)))
          ;; Combine partial results left-to-right (preserves left-to-right
          ;; ordering of chunks, which matters when combine-op is not
          ;; commutative, e.g. vector concatenation).
          (cl:reduce combine-op partials)))))
