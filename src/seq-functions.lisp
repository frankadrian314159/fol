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
  "Return a vector of the first N elements from COLL.
   Handles infinite lazy sequences without full realization.

   Examples:
     (take 3 [1 2 3 4 5])  => [1 2 3]
     (take 10 [1 2 3])     => [1 2 3]
     (take 4 (repeat 0))   => [0 0 0 0]"
  (if (typep coll 'fol.compiler.collections:<lazy-seq>)
      ;; Lazy-seq: iterate using realize-lazy-seq to avoid full realization
      (let ((result '())
            (current coll)
            (count 0))
        (loop while (and (< count n) current
                         (typep current 'fol.compiler.collections:<lazy-seq>))
              do (let* ((realized (fol.compiler.collections:realize-lazy-seq current))
                        (head (when (typep realized 'fol.compiler.collections:<list>)
                                (fol.compiler.collections:list-first realized)))
                        (tail (when (typep realized 'fol.compiler.collections:<list>)
                                (fol.compiler.collections:list-rest realized))))
                   (push head result)
                   (incf count)
                   (setf current tail)))
        (apply #'fol.compiler.collections:make
               'fol.compiler.collections:<vector>
               (nreverse result)))
      ;; Eager collections: use collection-seq
      (let* ((seq (fol.compiler.collections:collection-seq coll))
             (taken (cl:subseq seq 0 (min n (length seq)))))
        (apply #'fol.compiler.collections:make
               'fol.compiler.collections:<vector>
               taken))))

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

;;; ===========================================================================
;;; Sequence Constructors and Coercions
;;; ===========================================================================

;;; ---------------------------------------------------------------------------
;;; seq - coerce to sequence, or nil if empty
;;; ---------------------------------------------------------------------------

(defun seq (coll)
  "Returns a CL list for COLL, or nil if COLL is nil or empty.
   Used as the iteration entry-point for doseq/for/when-first macros.

   Examples:
     (seq [1 2 3])    => (1 2 3)
     (seq [])         => NIL
     (seq nil)        => NIL
     (seq {:a 1})     => ((:a . 1))"
  (cond
    ((null coll) nil)
    ((typep coll 'fol.compiler.collections:<collection>)
     (let ((s (fol.compiler.collections:collection-seq coll)))
       (if (null s) nil s)))
    (t nil)))

;;; ---------------------------------------------------------------------------
;;; sequence - coerce a coll to a lazy-seq or eager vector
;;; ---------------------------------------------------------------------------

(defun sequence (coll)
  "Coerces COLL to a FOL vector.  Returns an empty vector for nil or empty colls.

   Examples:
     (sequence [1 2 3])      => [1 2 3]
     (sequence #{3 1 2})     => [1 2 3]  ; order may vary
     (sequence nil)          => []"
  (if (null coll)
      (fol.compiler.collections:make 'fol.compiler.collections:<vector>)
      (let ((s (fol.compiler.collections:collection-seq coll)))
        (apply #'fol.compiler.collections:make
               'fol.compiler.collections:<vector>
               s))))

;;; ---------------------------------------------------------------------------
;;; keep-indexed - keep with index
;;; ---------------------------------------------------------------------------

(defun keep-indexed (fn coll)
  "Apply FN to index and each element of COLL; keep non-nil results.
   FN takes two arguments: (index element).

   Examples:
     (keep-indexed (fn [i x] (if (odd? i) x nil)) [0 1 2 3 4]) => [1 3]"
  (let* ((s (fol.compiler.collections:collection-seq coll))
         (result (cl:loop for elem in s
                          for i from 0
                          for v = (funcall fn i elem)
                          when v collect v)))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector>
           result)))

;;; ===========================================================================
;;; Infinite / Generative Sequences (returned as eager vectors when finite,
;;; or bounded by a count when infinite)
;;; ===========================================================================

;;; ---------------------------------------------------------------------------
;;; repeat - repeat a value n times (or indefinitely up to a limit)
;;; ---------------------------------------------------------------------------

(defun repeat (n-or-x &optional (x nil x-supplied-p))
  "Returns a vector of X repeated N times, or a lazily-realized vector.
   (repeat n x) => vector of x n times
   (repeat x)   => infinite sequence stub; use take to bound.

   Examples:
     (repeat 3 :a)   => [:a :a :a]
     (repeat 5 0)    => [0 0 0 0 0]"
  (if x-supplied-p
      ;; (repeat n x) form
      (let ((n n-or-x))
        (apply #'fol.compiler.collections:make
               'fol.compiler.collections:<vector>
               (cl:make-list n :initial-element x)))
      ;; (repeat x) form - return a <lazy-seq> that yields x forever
      (labels ((make-repeat-seq (val)
                 (fol.compiler.collections:make
                  'fol.compiler.collections:<lazy-seq>
                  (lambda ()
                    (make-instance 'fol.compiler.collections:<list>
                                   :first-elem val
                                   :rest-list (make-repeat-seq val)
                                   :list-size 1)))))
        (make-repeat-seq n-or-x))))

;;; ---------------------------------------------------------------------------
;;; range - numeric range
;;; ---------------------------------------------------------------------------

(defun range (&rest args)
  "Returns a vector of numbers.
   (range end)             => 0, 1, ..., end-1
   (range start end)       => start, start+1, ..., end-1
   (range start end step)  => start, start+step, ... while in range

   Examples:
     (range 5)        => [0 1 2 3 4]
     (range 2 6)      => [2 3 4 5]
     (range 0 10 2)   => [0 2 4 6 8]
     (range 5 0 -1)   => [5 4 3 2 1]"
  (let* ((len (length args))
         (start (if (>= len 2) (first  args) 0))
         (end   (if (>= len 2) (second args) (first args)))
         (step  (if (>= len 3) (third  args) 1)))
    (when (zerop step)
      (error "range: step cannot be zero"))
    (let ((nums (cl:loop for i = start then (+ i step)
                         while (if (plusp step) (< i end) (> i end))
                         collect i)))
      (apply #'fol.compiler.collections:make
             'fol.compiler.collections:<vector>
             nums))))

;;; ---------------------------------------------------------------------------
;;; repeatedly - call a zero-arg function n times (or return lazy-seq)
;;; ---------------------------------------------------------------------------

(defun repeatedly (n-or-fn &optional (fn nil fn-supplied-p))
  "Returns results of calling FN (a zero-arg function) N times.
   (repeatedly n fn) => vector of n calls to fn
   (repeatedly fn)   => infinite lazy-seq of calls to fn.

   Examples:
     (repeatedly 3 (fn [] (rand)))  => [r1 r2 r3]"
  (if fn-supplied-p
      (let ((n n-or-fn))
        (apply #'fol.compiler.collections:make
               'fol.compiler.collections:<vector>
               (cl:loop repeat n collect (funcall fn))))
      ;; (repeatedly fn) - infinite lazy seq
      (let ((f n-or-fn))
        (labels ((make-rep-seq ()
                   (fol.compiler.collections:make
                    'fol.compiler.collections:<lazy-seq>
                    (lambda ()
                      (make-instance 'fol.compiler.collections:<list>
                                     :first-elem (funcall f)
                                     :rest-list (make-rep-seq)
                                     :list-size 1)))))
          (make-rep-seq)))))

;;; ---------------------------------------------------------------------------
;;; iterate - generate sequence by repeatedly applying a function
;;; ---------------------------------------------------------------------------

(defun iterate (f x)
  "Returns an infinite lazy seq of x, (f x), (f (f x)), etc.
   Use take to bound the result.

   Examples:
     (take 5 (iterate inc 0))    => [0 1 2 3 4]
     (take 4 (iterate (fn [x] (* x 2)) 1)) => [1 2 4 8]"
  (labels ((make-iter-seq (val)
             (fol.compiler.collections:make
              'fol.compiler.collections:<lazy-seq>
              (lambda ()
                (make-instance 'fol.compiler.collections:<list>
                               :first-elem val
                               :rest-list (make-iter-seq (funcall f val))
                               :list-size 1)))))
    (make-iter-seq x)))

;;; ---------------------------------------------------------------------------
;;; iteration - step-function-based iteration (Clojure 1.11+)
;;; ---------------------------------------------------------------------------

(defun iteration (step &key (some? #'identity) (initk nil) (kf #'identity) (vf #'identity))
  "Creates a vector by stepping through a stateful process.
   STEP is a function taking a key and returning the next state.
   SOME? tests whether iteration should continue (default: identity).
   INITK is the initial key (default: nil).
   KF extracts the next key from state (default: identity).
   VF extracts the value from state (default: identity).

   Examples:
     ;; Count up to 5
     (iteration (fn [k] (when (< k 5) (1+ k)))
                :some? #'identity :initk 0 :kf #'identity :vf #'identity)"
  (let ((result '())
        (k initk))
    (cl:loop
      for state = (funcall step k)
      while (funcall some? state)
      do (push (funcall vf state) result)
         (setf k (funcall kf state)))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector>
           (nreverse result))))

;;; ===========================================================================
;;; File and I/O Sequences
;;; ===========================================================================

;;; ---------------------------------------------------------------------------
;;; file-seq - lazy directory tree walk
;;; ---------------------------------------------------------------------------

(defun file-seq (dir)
  "Returns a vector of all files and directories under DIR (recursive).
   DIR may be a pathname or a string.

   Examples:
     (file-seq \"/tmp\")  => [\"/tmp\" \"/tmp/foo\" ...]"
  (let ((root (cl:pathname dir))
        (result '()))
    (labels ((walk (p)
               (push p result)
               (when (cl:probe-file p)
                 (when (cl:directory p)
                   (dolist (child (cl:directory
                                   (cl:make-pathname :name :wild
                                                     :type :wild
                                                     :defaults p)))
                     (walk child))))))
      (walk root))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector>
           (nreverse result))))

;;; ---------------------------------------------------------------------------
;;; line-seq - lazy seq of lines from a stream
;;; ---------------------------------------------------------------------------

(defun line-seq (stream)
  "Returns a vector of all lines read from STREAM.
   STREAM must be a CL input stream (use input-stream-stream to unwrap FOL streams).

   Examples:
     (line-seq (open \"/tmp/file.txt\"))  => [\"line1\" \"line2\" ...]"
  (let ((result '()))
    (cl:loop for line = (cl:read-line stream nil nil)
             while line
             do (push line result))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector>
           (nreverse result))))

;;; ---------------------------------------------------------------------------
;;; tree-seq - depth-first tree traversal
;;; ---------------------------------------------------------------------------

(defun tree-seq (branch? children root)
  "Returns a vector of nodes in a depth-first walk of the tree rooted at ROOT.
   BRANCH? is a predicate: returns true if a node has children.
   CHILDREN is a function: returns the children of a node.

   Examples:
     (tree-seq listp identity '(1 (2 3) (4 (5 6))))
       => ((1 (2 3) (4 (5 6))) 1 (2 3) 2 3 (4 (5 6)) 4 (5 6) 5 6)"
  (let ((result '()))
    (labels ((walk (node)
               (push node result)
               (when (funcall branch? node)
                 (let ((children-seq (funcall children node)))
                   (dolist (child (if (typep children-seq
                                             'fol.compiler.collections:<collection>)
                                      (fol.compiler.collections:collection-seq children-seq)
                                      children-seq))
                     (walk child))))))
      (walk root))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector>
           (nreverse result))))

;;; ---------------------------------------------------------------------------
;;; iterator-seq - seq from an iterator-like object
;;; ---------------------------------------------------------------------------

(defun iterator-seq (iter)
  "Creates a vector from an iterator object ITER.
   ITER must support two operations:
   - (funcall iter :has-next?) => boolean
   - (funcall iter :next)      => next value
   This covers any closure implementing the iterator protocol.

   Examples:
     (let ((i 0))
       (iterator-seq (fn [msg]
         (cond ((eq msg :has-next?) (< i 3))
               ((eq msg :next) (incf i))))))
     => [1 2 3]"
  (let ((result '()))
    (cl:loop while (funcall iter :has-next?)
             do (push (funcall iter :next) result))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector>
           (nreverse result))))

;;; ---------------------------------------------------------------------------
;;; enumeration-seq - seq from an enumeration-like object
;;; ---------------------------------------------------------------------------

(defun enumeration-seq (enum)
  "Creates a vector from an enumeration object ENUM.
   ENUM must support two operations:
   - (funcall enum :has-more?) => boolean
   - (funcall enum :next-element) => next value
   This covers any closure implementing the enumeration protocol.

   Examples:
     (let ((xs (list 1 2 3)))
       (enumeration-seq (fn [msg]
         (cond ((eq msg :has-more?) (not (null xs)))
               ((eq msg :next-element) (pop xs))))))"
  (let ((result '()))
    (cl:loop while (funcall enum :has-more?)
             do (push (funcall enum :next-element) result))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector>
           (nreverse result))))

;;; ===========================================================================
;;; Additional Sequence Operations
;;; ===========================================================================

;;; ---------------------------------------------------------------------------
;;; sort - sort a collection
;;; ---------------------------------------------------------------------------

(defun sort (coll &optional (comp #'cl:<))
  "Returns a sorted vector of COLL's elements using COMP (default: cl:<).
   COMP is a two-argument predicate returning true if first arg precedes second.

   Examples:
     (sort [3 1 4 1 5])       => [1 1 3 4 5]
     (sort [3 1 2] #'cl:>)    => [3 2 1]"
  (let* ((seq (collection-seq coll))
         (sorted (cl:sort (copy-list seq) comp)))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector> sorted)))

;;; ---------------------------------------------------------------------------
;;; reverse - reverse a collection
;;; ---------------------------------------------------------------------------

(defun reverse (coll)
  "Returns a vector of COLL's items in reverse order.

   Examples:
     (reverse [1 2 3])   => [3 2 1]
     (reverse '(a b c))  => [c b a]"
  (let ((seq (collection-seq coll)))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector>
           (cl:reverse seq))))

;;; ---------------------------------------------------------------------------
;;; map-indexed - map with index passed as first arg
;;; ---------------------------------------------------------------------------

(defun map-indexed (fn coll)
  "Apply FN to (index element) for each element of COLL. Returns a vector.

   Examples:
     (map-indexed (fn [i x] [i x]) [:a :b :c])
       => [[0 :a] [1 :b] [2 :c]]"
  (let* ((seq (collection-seq coll))
         (result (cl:loop for elem in seq
                          for i from 0
                          collect (funcall fn i elem))))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector> result)))

;;; ---------------------------------------------------------------------------
;;; distinct - remove duplicates preserving first occurrence
;;; ---------------------------------------------------------------------------

(defun distinct (coll)
  "Returns a vector of COLL's elements with duplicates removed.
   Preserves the first occurrence of each element.

   Examples:
     (distinct [1 2 1 3 2 4])  => [1 2 3 4]"
  (let ((seen (make-hash-table :test 'equal))
        (result '()))
    (dolist (elem (collection-seq coll))
      (unless (gethash elem seen)
        (setf (gethash elem seen) t)
        (push elem result)))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector> (nreverse result))))

;;; ---------------------------------------------------------------------------
;;; dedupe - remove consecutive duplicates
;;; ---------------------------------------------------------------------------

(defun dedupe (coll)
  "Returns a vector with consecutive duplicate elements removed.

   Examples:
     (dedupe [1 1 2 1 1 3 3])  => [1 2 1 3]"
  (let ((seq (collection-seq coll))
        (result '())
        (sentinel (list :dedupe-sentinel)))
    (let ((prev sentinel))
      (dolist (elem seq)
        (unless (equal elem prev)
          (push elem result)
          (setf prev elem))))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector> (nreverse result))))

;;; ---------------------------------------------------------------------------
;;; flatten - recursively flatten nested collections
;;; ---------------------------------------------------------------------------

(defun flatten (coll)
  "Recursively flattens nested collections into a single vector.

   Examples:
     (flatten [1 [2 [3 4]] 5])  => [1 2 3 4 5]"
  (let ((result '()))
    (labels ((flat (x)
               (if (typep x 'fol.compiler.collections:<collection>)
                   (dolist (elem (collection-seq x))
                     (flat elem))
                   (push x result))))
      (flat coll))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector> (nreverse result))))

;;; ---------------------------------------------------------------------------
;;; group-by - group elements by a key function
;;; ---------------------------------------------------------------------------

(defun group-by (fn coll)
  "Returns a FOL dict of {key [matching-elements]} where key = (fn element).

   Examples:
     (group-by even? [1 2 3 4 5])  => {nil [1 3 5] t [2 4]}"
  (let ((buckets (make-hash-table :test 'equal)))
    (dolist (elem (collection-seq coll))
      (let ((key (funcall fn elem)))
        (push elem (gethash key buckets nil))))
    (let ((d (fol.compiler.collections:make 'fol.compiler.collections:<dict>)))
      (maphash (lambda (k vs)
                 (setf d (fol.compiler.collection-functions:assoc
                          d k
                          (apply #'fol.compiler.collections:make
                                 'fol.compiler.collections:<vector>
                                 (nreverse vs)))))
               buckets)
      d)))

;;; ---------------------------------------------------------------------------
;;; partition-all - like partition but keeps partial final group
;;; ---------------------------------------------------------------------------

(defun partition-all (n coll)
  "Like partition but always includes a partial final group.

   Examples:
     (partition-all 3 [1 2 3 4 5])  => [[1 2 3] [4 5]]"
  (let ((seq (collection-seq coll))
        (result '()))
    (loop while seq
          do (let ((group (cl:subseq seq 0 (min n (length seq)))))
               (push (apply #'fol.compiler.collections:make
                            'fol.compiler.collections:<vector> group)
                     result)
               (setf seq (cl:nthcdr n seq))))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector> (nreverse result))))

;;; ---------------------------------------------------------------------------
;;; partition-by - partition by consecutive equal values of fn
;;; ---------------------------------------------------------------------------

(defun partition-by (fn coll)
  "Partitions COLL into groups where consecutive (fn item) values are equal.

   Examples:
     (partition-by even? [1 1 2 2 3])  => [[1 1] [2 2] [3]]"
  (let ((seq (collection-seq coll))
        (result '())
        (current-group '())
        (sentinel (list :partition-by-sentinel)))
    (let ((current-key sentinel))
      (dolist (elem seq)
        (let ((key (funcall fn elem)))
          (if (or (eq current-key sentinel) (equal key current-key))
              (push elem current-group)
              (progn
                (push (apply #'fol.compiler.collections:make
                             'fol.compiler.collections:<vector>
                             (nreverse current-group))
                      result)
                (setf current-group (list elem))))
          (setf current-key key)))
      (when current-group
        (push (apply #'fol.compiler.collections:make
                     'fol.compiler.collections:<vector>
                     (nreverse current-group))
              result)))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector> (nreverse result))))

;;; ---------------------------------------------------------------------------
;;; split-at - split at position n
;;; ---------------------------------------------------------------------------

(defun split-at (n coll)
  "Returns a two-element vector [(take n coll) (drop n coll)].

   Examples:
     (split-at 3 [1 2 3 4 5])  => [[1 2 3] [4 5]]"
  (fol.compiler.collections:make 'fol.compiler.collections:<vector>
                                 (take n coll) (drop n coll)))

;;; ---------------------------------------------------------------------------
;;; split-with - split by predicate
;;; ---------------------------------------------------------------------------

(defun split-with (pred coll)
  "Returns a two-element vector [(take-while pred coll) (drop-while pred coll)].

   Examples:
     (split-with even? [2 4 1 2 3])  => [[2 4] [1 2 3]]"
  (fol.compiler.collections:make 'fol.compiler.collections:<vector>
                                 (take-while pred coll)
                                 (drop-while pred coll)))

;;; ---------------------------------------------------------------------------
;;; shuffle - randomly reorder elements
;;; ---------------------------------------------------------------------------

(defun shuffle (coll)
  "Returns a vector of COLL's elements in a uniformly random order.
   Uses Fisher-Yates shuffle.

   Examples:
     (shuffle [1 2 3 4 5])  => [3 1 5 2 4]  ; random"
  (let* ((arr (coerce (collection-seq coll) 'cl:vector))
         (len (length arr)))
    (loop for i from (1- len) downto 1
          for j = (random (1+ i))
          do (rotatef (aref arr i) (aref arr j)))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector>
           (coerce arr 'list))))

;;; ---------------------------------------------------------------------------
;;; butlast - all but the last element
;;; ---------------------------------------------------------------------------

(defun butlast (coll)
  "Returns a vector of all but the last element of COLL.

   Examples:
     (butlast [1 2 3 4])  => [1 2 3]
     (butlast [1])        => []"
  (apply #'fol.compiler.collections:make
         'fol.compiler.collections:<vector>
         (cl:butlast (collection-seq coll))))

;;; ---------------------------------------------------------------------------
;;; drop-last - drop last n elements
;;; ---------------------------------------------------------------------------

(defun drop-last (n-or-coll &optional (coll nil coll-p))
  "Returns a vector without the last N elements (N defaults to 1).
   (drop-last coll)    => all but last element
   (drop-last n coll)  => all but last n elements

   Examples:
     (drop-last [1 2 3 4])    => [1 2 3]
     (drop-last 2 [1 2 3 4])  => [1 2]"
  (let* ((n   (if coll-p n-or-coll 1))
         (seq (collection-seq (if coll-p coll n-or-coll)))
         (len (length seq))
         (keep (max 0 (- len n))))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector>
           (cl:subseq seq 0 keep))))

;;; ---------------------------------------------------------------------------
;;; take-last - take last n elements
;;; ---------------------------------------------------------------------------

(defun take-last (n coll)
  "Returns a vector of the last N elements of COLL.

   Examples:
     (take-last 2 [1 2 3 4])  => [3 4]
     (take-last 0 [1 2 3])    => []"
  (let* ((seq  (collection-seq coll))
         (len  (length seq))
         (skip (max 0 (- len n))))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector>
           (cl:nthcdr skip seq))))

;;; ---------------------------------------------------------------------------
;;; nthrest - drop first n elements
;;; ---------------------------------------------------------------------------

(defun nthrest (coll n)
  "Returns COLL with the first N elements dropped (argument order: coll n).

   Examples:
     (nthrest [1 2 3 4 5] 2)  => [3 4 5]"
  (drop n coll))

;;; ---------------------------------------------------------------------------
;;; next - like rest but returns nil when exhausted
;;; ---------------------------------------------------------------------------

(defun next (coll)
  "Returns the rest of COLL as a CL list, or nil if empty or single-element.
   Unlike rest, always returns nil (not an empty collection) when exhausted.

   Examples:
     (next [1 2 3])  => (2 3)
     (next [1])      => nil
     (next [])       => nil"
  (cl:rest (collection-seq coll)))

;;; ---------------------------------------------------------------------------
;;; third - third element of a collection
;;; ---------------------------------------------------------------------------

(defun third (coll)
  "Returns the third element of COLL, or nil if COLL has fewer than 3 elements.

   Examples:
     (third [1 2 3 4])  => 3
     (third [1 2])      => nil"
  (cl:third (collection-seq coll)))

;;; ---------------------------------------------------------------------------
;;; fnext - first of next
;;; ---------------------------------------------------------------------------

(defun fnext (coll)
  "Returns the second element of COLL, i.e. (first (next coll)).

   Examples:
     (fnext [1 2 3])  => 2
     (fnext [1])      => nil"
  (cl:first (next coll)))

;;; ---------------------------------------------------------------------------
;;; nnext - next of next
;;; ---------------------------------------------------------------------------

(defun nnext (coll)
  "Returns (next (next coll)), i.e. COLL with first two elements dropped.

   Examples:
     (nnext [1 2 3 4])  => (3 4)
     (nnext [1 2])      => nil"
  (next (next coll)))

;;; ---------------------------------------------------------------------------
;;; cons - prepend element to a sequence
;;; ---------------------------------------------------------------------------

(defun cons (elem coll)
  "Returns a CL list with ELEM prepended to the seq of COLL.
   Compatible with seq/next/first/rest operations.

   Examples:
     (cons 0 [1 2 3])  => (0 1 2 3)
     (cons :a nil)     => (:a)"
  (cl:cons elem (when coll (collection-seq coll))))

;;; ---------------------------------------------------------------------------
;;; cycle - infinite lazy cycle through a collection
;;; ---------------------------------------------------------------------------

(defun cycle (coll)
  "Returns an infinite lazy-seq cycling through COLL's elements.
   Use take to bound the result.

   Examples:
     (take 5 (cycle [1 2 3]))  => [1 2 3 1 2]"
  (let ((seq (collection-seq coll)))
    (when (null seq)
      (error "cycle: cannot cycle an empty collection"))
    (labels ((make-cycle (remaining full-seq)
               (fol.compiler.collections:make
                'fol.compiler.collections:<lazy-seq>
                (let ((r remaining) (f full-seq))
                  (lambda ()
                    (make-instance 'fol.compiler.collections:<list>
                                   :first-elem (cl:first r)
                                   :rest-list (make-cycle (or (cl:rest r) f) f)
                                   :list-size 1))))))
      (make-cycle seq seq))))

;;; ---------------------------------------------------------------------------
;;; interleave - interleave elements from multiple collections
;;; ---------------------------------------------------------------------------

(defun interleave (&rest colls)
  "Returns a vector with elements interleaved from COLLS.
   Stops when the shortest collection is exhausted.

   Examples:
     (interleave [1 2 3] [:a :b :c])  => [1 :a 2 :b 3 :c]
     (interleave [1 2] [:a :b :c])    => [1 :a 2 :b]"
  (let ((seqs (mapcar #'collection-seq colls))
        (result '()))
    (loop while (cl:every #'identity seqs)
          do (dolist (s seqs) (push (cl:first s) result))
             (setf seqs (mapcar #'cl:rest seqs)))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector> (nreverse result))))

;;; ---------------------------------------------------------------------------
;;; interpose - insert separator between elements
;;; ---------------------------------------------------------------------------

(defun interpose (sep coll)
  "Returns a vector with SEP inserted between consecutive elements of COLL.

   Examples:
     (interpose 0 [1 2 3])           => [1 0 2 0 3]
     (interpose \", \" [\"a\" \"b\"])  => [\"a\" \", \" \"b\"]"
  (let ((seq (collection-seq coll)))
    (if (null seq)
        (fol.compiler.collections:make 'fol.compiler.collections:<vector>)
        (let ((result (list (cl:first seq))))
          (dolist (elem (cl:rest seq))
            (push sep result)
            (push elem result))
          (apply #'fol.compiler.collections:make
                 'fol.compiler.collections:<vector>
                 (nreverse result))))))

;;; ---------------------------------------------------------------------------
;;; take-nth - take every nth element
;;; ---------------------------------------------------------------------------

(defun take-nth (n coll)
  "Returns a vector of every Nth element of COLL (0-indexed first element).

   Examples:
     (take-nth 2 [1 2 3 4 5 6])  => [1 3 5]
     (take-nth 1 [1 2 3])        => [1 2 3]"
  (when (< n 1)
    (error "take-nth: n must be >= 1, got ~S" n))
  (let* ((seq (collection-seq coll))
         (result (cl:loop for elem in seq
                          for i from 0
                          when (zerop (mod i n)) collect elem)))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector> result)))

;;; ---------------------------------------------------------------------------
;;; random-sample - random subset with given probability
;;; ---------------------------------------------------------------------------

(defun random-sample (prob coll)
  "Returns a vector of elements from COLL selected with probability PROB.
   PROB should be a float between 0.0 and 1.0.

   Examples:
     (random-sample 0.5 [1 2 3 4 5 6])  => random subset"
  (let* ((seq (collection-seq coll))
         (result (cl:loop for elem in seq
                          when (< (random 1.0) (float prob))
                          collect elem)))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector> result)))

;;; ---------------------------------------------------------------------------
;;; seque - buffered sequence (simplified eager evaluation)
;;; ---------------------------------------------------------------------------

(defun seque (n-or-coll &optional (coll nil coll-p))
  "Returns a vector backed by the given sequence.
   In Clojure, seque uses an agent for async buffering; here evaluation is eager.
   (seque coll)    => vector of coll's elements
   (seque n coll)  => same (buffer size n is ignored)

   Examples:
     (seque [1 2 3])     => [1 2 3]
     (seque 16 [1 2 3])  => [1 2 3]"
  (sequence (if coll-p coll n-or-coll)))

;;; ===========================================================================
;;; Element Accessors
;;; ===========================================================================

;;; ---------------------------------------------------------------------------
;;; second - second element of a collection
;;; ---------------------------------------------------------------------------

(defun second (coll)
  "Returns the second element of COLL, or nil if COLL has fewer than 2 elements.

   Examples:
     (second [1 2 3])  => 2
     (second [1])      => nil"
  (cl:second (collection-seq coll)))

;;; ---------------------------------------------------------------------------
;;; last - last element of a collection
;;; ---------------------------------------------------------------------------

(defun last (coll)
  "Returns the last element of COLL, or nil if COLL is empty.

   Examples:
     (last [1 2 3])  => 3
     (last [42])     => 42
     (last [])       => nil"
  (cl:first (cl:last (collection-seq coll))))

;;; ---------------------------------------------------------------------------
;;; ffirst - first of first
;;; ---------------------------------------------------------------------------

(defun ffirst (coll)
  "Returns (first (first coll)), i.e. the first element of the first element.

   Examples:
     (ffirst [[1 2] [3 4]])  => 1"
  (let ((inner (cl:first (collection-seq coll))))
    (when inner
      (cl:first (collection-seq inner)))))

;;; ---------------------------------------------------------------------------
;;; nfirst - next of first (rest of first element's seq)
;;; ---------------------------------------------------------------------------

(defun nfirst (coll)
  "Returns (next (first coll)), i.e. the seq of the first element minus its first item.

   Examples:
     (nfirst [[1 2 3] [4 5]])  => (2 3)"
  (let ((inner (cl:first (collection-seq coll))))
    (when inner
      (cl:rest (collection-seq inner)))))

;;; ---------------------------------------------------------------------------
;;; nthnext - nth application of next
;;; ---------------------------------------------------------------------------

(defun nthnext (coll n)
  "Returns the nth next of COLL as a CL list. (nthnext coll 0) = (seq coll).

   Examples:
     (nthnext [1 2 3 4] 2)  => (3 4)
     (nthnext [1 2 3] 0)    => (1 2 3)
     (nthnext [1] 2)        => nil"
  (let ((s (collection-seq coll)))
    (loop repeat n
          while s
          do (setf s (cl:rest s)))
    s))

;;; ===========================================================================
;;; Lazy-Seq Utilities
;;; ===========================================================================

;;; ---------------------------------------------------------------------------
;;; realized? - test whether a lazy-seq has been realized
;;; ---------------------------------------------------------------------------

(defun realized? (x)
  "Returns true if X is not a lazy-seq or if the lazy-seq has been realized.

   Examples:
     (realized? [1 2 3])          => t   ; eager collection
     (realized? (repeat 0))       => nil ; unrealized lazy-seq
     (take 1 (repeat 0))
     (realized? (repeat 0))       => nil ; each call to repeat makes a new one"
  (if (typep x 'fol.compiler.collections:<lazy-seq>)
      (lazy-seq-realized-p x)
      t))

;;; ---------------------------------------------------------------------------
;;; dorun - force lazy seq for side effects, return nil
;;; ---------------------------------------------------------------------------

(defun dorun (coll)
  "Forces realization of a lazy sequence for side effects. Returns nil.
   Unlike doall, does not retain the head.

   Examples:
     (dorun (map println [1 2 3]))  ; prints 1 2 3, returns nil"
  (if (typep coll 'fol.compiler.collections:<lazy-seq>)
      (let ((current coll))
        (loop while (typep current 'fol.compiler.collections:<lazy-seq>)
              do (let ((realized (realize-lazy-seq current)))
                   (if (typep realized 'fol.compiler.collections:<list>)
                       (setf current (fol.compiler.collections:list-rest realized))
                       (setf current nil)))))
      ;; Eager: just force evaluation of the seq
      (collection-seq coll))
  nil)

;;; ---------------------------------------------------------------------------
;;; doall - force lazy seq, return realized vector
;;; ---------------------------------------------------------------------------

(defun doall (coll)
  "Forces realization of a lazy sequence and returns a vector of all elements.

   Examples:
     (doall (map inc (repeat 3 1)))  => [2 2 2]
     (doall [1 2 3])                 => [1 2 3]"
  (if (typep coll 'fol.compiler.collections:<lazy-seq>)
      (let ((result '())
            (current coll))
        (loop while (typep current 'fol.compiler.collections:<lazy-seq>)
              do (let ((realized (realize-lazy-seq current)))
                   (if (typep realized 'fol.compiler.collections:<list>)
                       (progn
                         (push (list-first realized) result)
                         (setf current (list-rest realized)))
                       (setf current nil))))
        (apply #'fol.compiler.collections:make
               'fol.compiler.collections:<vector>
               (nreverse result)))
      ;; Eager: return as-is (already fully realized)
      coll))

;;; ---------------------------------------------------------------------------
;;; run! - apply proc to each element for side effects, return nil
;;; ---------------------------------------------------------------------------

(defun run! (proc coll)
  "Applies PROC to each element of COLL for side effects. Returns nil.

   Examples:
     (run! println [1 2 3])  ; prints 1, 2, 3"
  (dolist (elem (collection-seq coll))
    (funcall proc elem))
  nil)

;;; ===========================================================================
;;; Random Selection
;;; ===========================================================================

;;; ---------------------------------------------------------------------------
;;; rand-nth - random element from a collection
;;; ---------------------------------------------------------------------------

(defun rand-nth (coll)
  "Returns a random element from COLL.

   Examples:
     (rand-nth [1 2 3 4 5])  => 3  ; random"
  (let ((seq (collection-seq coll)))
    (when seq
      (cl:nth (random (length seq)) seq))))

;;; ===========================================================================
;;; Key-Based Min/Max
;;; ===========================================================================

;;; ---------------------------------------------------------------------------
;;; max-key - element with maximum key value
;;; ---------------------------------------------------------------------------

(defun max-key (k x &rest more)
  "Returns the element for which (k element) is greatest.

   Examples:
     (max-key count [1 2] [1] [1 2 3])  => [1 2 3]
     (max-key abs -3 1 2)               => -3"
  (cl:reduce (lambda (a b)
               (if (cl:>= (funcall k a) (funcall k b)) a b))
             more :initial-value x))

;;; ---------------------------------------------------------------------------
;;; min-key - element with minimum key value
;;; ---------------------------------------------------------------------------

(defun min-key (k x &rest more)
  "Returns the element for which (k element) is least.

   Examples:
     (min-key count [1 2] [1] [1 2 3])  => [1]
     (min-key abs -3 1 2)               => 1"
  (cl:reduce (lambda (a b)
               (if (cl:<= (funcall k a) (funcall k b)) a b))
             more :initial-value x))

;;; ===========================================================================
;;; Zip and Reductions
;;; ===========================================================================

;;; ---------------------------------------------------------------------------
;;; zipmap - create a dict from parallel key/value sequences
;;; ---------------------------------------------------------------------------

(defun zipmap (keys vals)
  "Returns a dict with the keys mapped to the corresponding vals.
   Stops at the shorter of the two sequences.

   Examples:
     (zipmap [:a :b :c] [1 2 3])  => {:a 1 :b 2 :c 3}
     (zipmap [:a :b] [1 2 3])     => {:a 1 :b 2}"
  (let ((ks (collection-seq keys))
        (vs (collection-seq vals))
        (d (fol.compiler.collections:make 'fol.compiler.collections:<dict>)))
    (loop for k in ks for v in vs
          do (setf d (fol.compiler.collection-functions:assoc d k v)))
    d))

;;; ---------------------------------------------------------------------------
;;; reductions - sequence of intermediate reduction values
;;; ---------------------------------------------------------------------------

(defun reductions (fn init-or-coll &optional (coll nil coll-p))
  "Returns a vector of the intermediate values of a reduction.
   (reductions f init coll) starts with init.
   (reductions f coll)      uses first element of coll as init.

   Examples:
     (reductions + 0 [1 2 3])   => [0 1 3 6]
     (reductions + [1 2 3 4])   => [1 3 6 10]"
  (if coll-p
      ;; (reductions fn init coll) form
      (let* ((seq (collection-seq coll))
             (results (list init-or-coll))
             (acc init-or-coll))
        (dolist (elem seq)
          (setf acc (funcall fn acc elem))
          (push acc results))
        (apply #'fol.compiler.collections:make
               'fol.compiler.collections:<vector>
               (nreverse results)))
      ;; (reductions fn coll) form — use first element as init
      (let ((seq (collection-seq init-or-coll)))
        (if (null seq)
            (fol.compiler.collections:make 'fol.compiler.collections:<vector>)
            (let* ((init (cl:first seq))
                   (rest (cl:rest seq))
                   (results (list init))
                   (acc init))
              (dolist (elem rest)
                (setf acc (funcall fn acc elem))
                (push acc results))
              (apply #'fol.compiler.collections:make
                     'fol.compiler.collections:<vector>
                     (nreverse results)))))))
