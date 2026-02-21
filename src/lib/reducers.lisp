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
  (let* ((total-size (count coll)))
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
  (let* ((total-size (count coll)))
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
  (let ((total-size (count coll)))
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

;; We'll export the primary version which is simpler for the current thread pool architecture.
