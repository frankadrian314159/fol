;;; FOL Compiler - Sequence/Collection Higher-Order Functions
;;;
;;; Runtime functions for mapping, filtering, and reducing over collections.
;;; These operate on any FOL collection type.

(in-package :fol.compiler.seq-functions)

;;; ===========================================================================
;;; Thread Pool for Parallel Operations
;;; ===========================================================================

(defvar *thread-pool-size* 16
  "Number of worker threads in the global thread pool.")

(defvar *work-queue* nil
  "Queue of work items to be processed by worker threads.")

(defvar *work-queue-lock* nil
  "Lock protecting the work queue.")

(defvar *work-queue-condvar* nil
  "Condition variable for signaling work availability.")

(defvar *worker-threads* nil
  "Vector of worker threads.")

(defvar *thread-pool-shutdown* nil
  "Flag indicating thread pool should shut down.")

(defstruct work-item
  "A unit of work for the thread pool."
  (fn nil :type function)
  (args nil :type list)
  (result-box nil :type cons)  ; cons cell to store result
  (done-lock nil)
  (done-condvar nil))

(defun %worker-thread-loop ()
  "Main loop for worker threads. Pulls work from queue and executes it."
  (loop
    (let ((work nil))
      ;; Get work from queue
      (bt:with-lock-held (*work-queue-lock*)
        (loop while (and (null *work-queue*) (not *thread-pool-shutdown*))
              do (bt:condition-wait *work-queue-condvar* *work-queue-lock*))
        (when *thread-pool-shutdown*
          (return-from %worker-thread-loop))
        (when *work-queue*
          (setf work (pop *work-queue*))))

      ;; Execute work
      (when work
        (let ((result (handler-case
                          (apply (work-item-fn work) (work-item-args work))
                        (error (e)
                          (format *error-output* "~&Worker thread error: ~A~%" e)
                          :error))))
          ;; Store result and signal completion
          (setf (car (work-item-result-box work)) result)
          (bt:with-lock-held ((work-item-done-lock work))
            (bt:condition-notify (work-item-done-condvar work))))))))

(defun %initialize-thread-pool ()
  "Initialize the global thread pool with worker threads."
  (unless *worker-threads*
    (setf *work-queue* nil)
    (setf *work-queue-lock* (bt:make-lock "work-queue-lock"))
    (setf *work-queue-condvar* (bt:make-condition-variable :name "work-queue-condvar"))
    (setf *thread-pool-shutdown* nil)
    (setf *worker-threads*
          (make-array *thread-pool-size*
                      :initial-contents
                      (loop for i from 0 below *thread-pool-size*
                            collect (bt:make-thread #'%worker-thread-loop
                                                     :name (format nil "worker-~D" i)))))))

(defun %submit-work (fn args)
  "Submit work to the thread pool. Returns a work-item that can be waited on."
  (%initialize-thread-pool)  ; Ensure pool is initialized
  (let ((work (make-work-item
               :fn fn
               :args args
               :result-box (cons nil nil)
               :done-lock (bt:make-lock)
               :done-condvar (bt:make-condition-variable))))
    (bt:with-lock-held (*work-queue-lock*)
      (setf *work-queue* (nconc *work-queue* (list work)))
      (bt:condition-notify *work-queue-condvar*))
    work))

(defun %wait-for-work (work-item)
  "Wait for a work item to complete and return its result."
  (bt:with-lock-held ((work-item-done-lock work-item))
    (loop while (null (car (work-item-result-box work-item)))
          do (bt:condition-wait (work-item-done-condvar work-item)
                                (work-item-done-lock work-item))))
  (car (work-item-result-box work-item)))

;;; ===========================================================================
;;; Higher-Order Collection Functions
;;; ===========================================================================

;;; ---------------------------------------------------------------------------
;;; map - Apply function to each element of collection(s)
;;; ---------------------------------------------------------------------------

(defun map (fn coll &rest colls)
  "Apply FN to elements of COLL (and additional COLLS in parallel).
   Returns a new collection of the same type as COLL.

   Examples:
     (map inc [1 2 3])           => [2 3 4]
     (map + [1 2 3] [10 20 30])  => [11 22 33]
     (map (fn [x] (* x 2)) #{1 2 3}) => #{2 4 6}"
  (if colls
      ;; Multiple collections - zip them
      (let* ((seqs (cons (fol.compiler.collections:collection-seq coll)
                         (cl:mapcar #'fol.compiler.collections:collection-seq colls)))
             (results (apply #'cl:mapcar fn seqs)))
        (apply #'fol.compiler.collections:make (class-name (class-of coll)) results))
      ;; Single collection
      (let* ((seq (fol.compiler.collections:collection-seq coll))
             (results (cl:mapcar fn seq)))
        (apply #'fol.compiler.collections:make (class-name (class-of coll)) results))))

;;; ---------------------------------------------------------------------------
;;; mapv - map returning vector
;;; ---------------------------------------------------------------------------

(defun mapv (fn coll &rest colls)
  "Like map, but always returns a vector regardless of input collection type.

   Examples:
     (mapv inc #{1 2 3})           => [2 3 4]  ; order may vary
     (mapv + [1 2 3] [10 20 30])   => [11 22 33]"
  (if colls
      (let* ((seqs (cons (fol.compiler.collections:collection-seq coll)
                         (cl:mapcar #'fol.compiler.collections:collection-seq colls)))
             (results (apply #'cl:mapcar fn seqs)))
        (apply #'fol.compiler.collections:make 'fol.compiler.collections:<vector> results))
      (let* ((seq (fol.compiler.collections:collection-seq coll))
             (results (cl:mapcar fn seq)))
        (apply #'fol.compiler.collections:make 'fol.compiler.collections:<vector> results))))

;;; ---------------------------------------------------------------------------
;;; pmap - parallel map using thread pool
;;; ---------------------------------------------------------------------------

(defun pmap (fn coll &rest colls)
  "Parallel version of map. Applies FN to elements in parallel using a thread pool.
   Returns a new collection of the same type as COLL.

   Examples:
     (pmap expensive-fn [1 2 3 4])  ; processes in parallel"
  (if colls
      ;; Multiple collections - zip them and process in parallel
      (let* ((seqs (cons (fol.compiler.collections:collection-seq coll)
                         (cl:mapcar #'fol.compiler.collections:collection-seq colls)))
             (zipped (apply #'cl:mapcar #'list seqs))
             (work-items (cl:mapcar (lambda (args)
                                      (%submit-work fn args))
                                    zipped))
             (results (cl:mapcar #'%wait-for-work work-items)))
        (apply #'fol.compiler.collections:make (class-name (class-of coll)) results))
      ;; Single collection - process in parallel
      (let* ((seq (fol.compiler.collections:collection-seq coll))
             (work-items (cl:mapcar (lambda (elem)
                                      (%submit-work fn (list elem)))
                                    seq))
             (results (cl:mapcar #'%wait-for-work work-items)))
        (apply #'fol.compiler.collections:make (class-name (class-of coll)) results))))

;;; ---------------------------------------------------------------------------
;;; filter - Keep elements that satisfy predicate
;;; ---------------------------------------------------------------------------

(defun filter (pred coll)
  "Return a new collection containing only elements where (PRED element) is truthy.

   Examples:
     (filter odd? [1 2 3 4 5])             => [1 3 5]
     (filter (fn [x] (> x 2)) #{1 2 3 4}) => #{3 4}"
  (let* ((seq (fol.compiler.collections:collection-seq coll))
         (filtered (cl:remove-if-not (lambda (x)
                                       (fol.compiler.primitives:truthy? (funcall pred x)))
                                     seq)))
    (apply #'fol.compiler.collections:make (class-name (class-of coll)) filtered)))

;;; ---------------------------------------------------------------------------
;;; filterv - filter returning vector
;;; ---------------------------------------------------------------------------

(defun filterv (pred coll)
  "Like filter, but always returns a vector.

   Examples:
     (filterv odd? #{1 2 3 4 5})  => [1 3 5]  ; order may vary"
  (let* ((seq (fol.compiler.collections:collection-seq coll))
         (filtered (cl:remove-if-not (lambda (x)
                                       (fol.compiler.primitives:truthy? (funcall pred x)))
                                     seq)))
    (apply #'fol.compiler.collections:make 'fol.compiler.collections:<vector> filtered)))

;;; ---------------------------------------------------------------------------
;;; reduce - Reduce collection to single value
;;; ---------------------------------------------------------------------------

(defun reduce (fn init coll)
  "Reduce COLL to a single value by repeatedly applying FN.
   FN takes (accumulator, element) and returns new accumulator.
   INIT is the initial accumulator value.

   Examples:
     (reduce + 0 [1 2 3 4])                     => 10
     (reduce (fn [acc x] (conj acc (* x 2))) [] [1 2 3]) => [2 4 6]"
  (let ((seq (fol.compiler.collections:collection-seq coll)))
    (cl:reduce fn seq :initial-value init)))

;;; ---------------------------------------------------------------------------
;;; mapcat - map followed by concatenation
;;; ---------------------------------------------------------------------------

(defun mapcat (fn coll)
  "Apply FN to each element of COLL, then concatenate the results.
   FN should return a collection. Results are concatenated into same type as COLL.

   Examples:
     (mapcat (fn [x] [x (* x 2)]) [1 2 3]) => [1 2 2 4 3 6]"
  (let* ((seq (fol.compiler.collections:collection-seq coll))
         (mapped (cl:mapcar fn seq))
         (seqs (cl:mapcar #'fol.compiler.collections:collection-seq mapped))
         (flattened (apply #'cl:append seqs)))
    (apply #'fol.compiler.collections:make (class-name (class-of coll)) flattened)))

;;; ---------------------------------------------------------------------------
;;; pmapcat - parallel map followed by concatenation using thread pool
;;; ---------------------------------------------------------------------------

(defun pmapcat (fn coll)
  "Parallel version of mapcat. Apply FN to each element in parallel using a thread pool, then concatenate.
   FN should return a collection. Results are concatenated into same type as COLL.

   Examples:
     (pmapcat (fn [x] [x (* x 2)]) [1 2 3]) => [1 2 2 4 3 6]"
  (let* ((seq (fol.compiler.collections:collection-seq coll))
         (work-items (cl:mapcar (lambda (elem)
                                  (%submit-work fn (list elem)))
                                seq))
         (mapped (cl:mapcar #'%wait-for-work work-items))
         (seqs (cl:mapcar #'fol.compiler.collections:collection-seq mapped))
         (flattened (apply #'cl:append seqs)))
    (apply #'fol.compiler.collections:make (class-name (class-of coll)) flattened)))

;;; ---------------------------------------------------------------------------
;;; remove - Inverse of filter
;;; ---------------------------------------------------------------------------

(defun remove (pred coll)
  "Return a new collection containing only elements where (PRED element) is falsy.
   Inverse of filter.

   Examples:
     (remove odd? [1 2 3 4 5])         => [2 4]
     (remove (fn [x] (> x 2)) [1 2 3 4]) => [1 2]"
  (let* ((seq (fol.compiler.collections:collection-seq coll))
         (kept (cl:remove-if (lambda (x)
                               (fol.compiler.primitives:truthy? (funcall pred x)))
                             seq)))
    (apply #'fol.compiler.collections:make (class-name (class-of coll)) kept)))

;;; ---------------------------------------------------------------------------
;;; keep - map but remove nil results
;;; ---------------------------------------------------------------------------

(defun keep (fn coll)
  "Apply FN to each element of COLL and keep non-nil results.

   Examples:
     (keep (fn [x] (if (odd? x) (* x 2) nil)) [1 2 3 4 5]) => [2 6 10]"
  (let* ((seq (fol.compiler.collections:collection-seq coll))
         (results (cl:mapcar fn seq))
         (kept (cl:remove-if #'null results)))
    (apply #'fol.compiler.collections:make (class-name (class-of coll)) kept)))

;;; ---------------------------------------------------------------------------
;;; some - Test if any element satisfies predicate
;;; ---------------------------------------------------------------------------

(defun some (pred coll)
  "Return the first truthy value of (PRED element), or nil if none.

   Examples:
     (some odd? [2 4 5 6])      => t
     (some odd? [2 4 6])        => nil
     (some #'(lambda (x) (if (> x 3) x)) [1 2 4 5]) => 4"
  (let ((seq (fol.compiler.collections:collection-seq coll)))
    (cl:some (lambda (x) (funcall pred x)) seq)))

;;; ---------------------------------------------------------------------------
;;; every - Test if all elements satisfy predicate
;;; ---------------------------------------------------------------------------

(defun every (pred coll)
  "Return true if (PRED element) is truthy for all elements.

   Examples:
     (every odd? [1 3 5])       => t
     (every odd? [1 2 3])       => nil"
  (let ((seq (fol.compiler.collections:collection-seq coll)))
    (cl:every (lambda (x)
                (fol.compiler.primitives:truthy? (funcall pred x)))
              seq)))

;;; ---------------------------------------------------------------------------
;;; partition - Split collection into groups of n
;;; ---------------------------------------------------------------------------

(defun partition (n coll)
  "Split COLL into consecutive groups of N elements.
   Returns a vector of vectors.

   Examples:
     (partition 2 [1 2 3 4 5 6])     => [[1 2] [3 4] [5 6]]
     (partition 3 [1 2 3 4 5])       => [[1 2 3] [4 5]]  ; partial group at end"
  (let ((seq (fol.compiler.collections:collection-seq coll))
        (result '()))
    (loop while seq
          do (let ((group (cl:subseq seq 0 (min n (length seq)))))
               (push (apply #'fol.compiler.collections:make
                            'fol.compiler.collections:<vector> group)
                     result)
               (setf seq (cl:nthcdr n seq))))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector>
           (nreverse result))))

;;; ---------------------------------------------------------------------------
;;; take - Take first n elements
;;; ---------------------------------------------------------------------------

(defun take (n coll)
  "Return a collection of the first N elements from COLL.

   Examples:
     (take 3 [1 2 3 4 5])  => [1 2 3]
     (take 10 [1 2 3])     => [1 2 3]"
  (let* ((seq (fol.compiler.collections:collection-seq coll))
         (taken (cl:subseq seq 0 (min n (length seq)))))
    (apply #'fol.compiler.collections:make (class-name (class-of coll)) taken)))

;;; ---------------------------------------------------------------------------
;;; drop - Drop first n elements
;;; ---------------------------------------------------------------------------

(defun drop (n coll)
  "Return a collection without the first N elements from COLL.

   Examples:
     (drop 2 [1 2 3 4 5])  => [3 4 5]
     (drop 10 [1 2 3])     => []"
  (let* ((seq (fol.compiler.collections:collection-seq coll))
         (dropped (cl:nthcdr n seq)))
    (apply #'fol.compiler.collections:make (class-name (class-of coll)) dropped)))

;;; ---------------------------------------------------------------------------
;;; take-while - Take elements while predicate is true
;;; ---------------------------------------------------------------------------

(defun take-while (pred coll)
  "Return elements from COLL up to first element where PRED is falsy.

   Examples:
     (take-while (fn [x] (< x 5)) [1 2 3 4 5 6 1 2]) => [1 2 3 4]"
  (let ((seq (fol.compiler.collections:collection-seq coll))
        (result '()))
    (loop for elem in seq
          while (fol.compiler.primitives:truthy? (funcall pred elem))
          do (push elem result))
    (apply #'fol.compiler.collections:make (class-name (class-of coll)) (nreverse result))))

;;; ---------------------------------------------------------------------------
;;; drop-while - Drop elements while predicate is true
;;; ---------------------------------------------------------------------------

(defun drop-while (pred coll)
  "Drop elements from COLL up to first element where PRED is falsy.

   Examples:
     (drop-while (fn [x] (< x 5)) [1 2 3 4 5 6 1 2]) => [5 6 1 2]"
  (let ((seq (fol.compiler.collections:collection-seq coll)))
    (loop for tail on seq
          when (not (fol.compiler.primitives:truthy? (funcall pred (car tail))))
          return (apply #'fol.compiler.collections:make (class-name (class-of coll)) tail)
          finally (return (fol.compiler.collections:make (class-name (class-of coll)))))))

;;; ---------------------------------------------------------------------------
;;; concat - Concatenate multiple collections
;;; ---------------------------------------------------------------------------

(defun concat (&rest colls)
  "Concatenate multiple collections into a single vector.

   Examples:
     (concat [1 2] [3 4] [5 6])  => [1 2 3 4 5 6]
     (concat #{1 2} [3 4])       => [1 2 3 4]  ; order may vary for set"
  (let* ((seqs (cl:mapcar #'fol.compiler.collections:collection-seq colls))
         (combined (apply #'cl:append seqs)))
    (apply #'fol.compiler.collections:make 'fol.compiler.collections:<vector> combined)))

;;; ---------------------------------------------------------------------------
;;; keys - Get all keys from a dict
;;; ---------------------------------------------------------------------------

(defun keys (dict)
  "Return a vector of all keys in DICT.

   Examples:
     (keys {:a 1 :b 2 :c 3})  => [:a :b :c]  ; order may vary"
  (let ((result '()))
    (typecase dict
      (fol.compiler.collections:<dict>
       (sycamore:do-hash-map ((k v) (fol.compiler.collections:storage-items dict))
         (declare (ignore v))
         (push k result)))
      (fol.compiler.collections:<ordered-dict>
       ;; Use key-order for ordered dict
       (let ((seq (fol.compiler.collections:ordered-dict-key-order dict)))
         (return-from keys
           (apply #'fol.compiler.collections:make
                  'fol.compiler.collections:<vector>
                  (fol.compiler.collections:collection-seq seq)))))
      (fol.compiler.collections:<sorted-dict>
       (sycamore:do-tree-map ((k v) (fol.compiler.collections:storage-items dict))
         (declare (ignore v))
         (push k result)))
      (fol.compiler.collections:<priority-dict>
       (sycamore:do-hash-map ((k v) (fol.compiler.collections:storage-items dict))
         (declare (ignore v))
         (push k result)))
      (t
       (error "keys requires a dict, got ~S" dict)))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector>
           (nreverse result))))

;;; ---------------------------------------------------------------------------
;;; sort-by - Sort collection by key function
;;; ---------------------------------------------------------------------------

(defun sort-by (keyfn coll)
  "Sort COLL by applying KEYFN to each element.
   KEYFN can be a function or a keyword (for dict lookup).
   Returns a vector.

   Examples:
     (sort-by :age [{:name \"Alice\" :age 30} {:name \"Bob\" :age 25}])
       => [{:name \"Bob\" :age 25} {:name \"Alice\" :age 30}]
     (sort-by (fn [x] (- x)) [3 1 4 1 5])  => [5 4 3 1 1]"
  (let* ((seq (fol.compiler.collections:collection-seq coll))
         (key-fn (if (keywordp keyfn)
                     ;; Keyword - use as dict accessor
                     (lambda (x) (get x keyfn))
                     ;; Function - use directly
                     keyfn))
         (sorted (cl:sort (copy-list seq) #'<
                          :key (lambda (x)
                                 (let ((k (funcall key-fn x)))
                                   ;; Handle various key types
                                   (typecase k
                                     (number k)
                                     (string (string k))
                                     (symbol (symbol-name k))
                                     (t k)))))))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector>
           sorted)))
