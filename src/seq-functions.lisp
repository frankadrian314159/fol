;;; FOL Compiler - Sequence/Collection Higher-Order Functions
;;;
;;; Runtime functions for mapping, filtering, and reducing over collections.
;;; These operate on any FOL collection type.

(in-package :fol.compiler.seq-functions)


;;; ===========================================================================
;;; Transduce Infrastructure
;;; ===========================================================================

(defun completing (rf)
  "Wraps a reducing function to support 0 and 1 arity."
  (lambda (&optional (acc nil acc-p) (input nil input-p))
    (cond
     ((not acc-p) (error "Completing RF requires init via reduce"))
     ((not input-p) acc)
     (t (funcall rf acc input)))))

(defun transduce (xform f init coll)
  "Reduce over COLL with transducer XFORM applied to reducing function F."
  (let* ((rf (funcall xform (if (functionp f)
                                (completing f)
                                (completing (lambda (a b) (funcall f a b))))))
         (acc init)
         (iter (fol.compiler.collections:collection-seq coll)))
    (cl:loop for x in iter
    do (let ((res (funcall rf acc x)))
         (if (reduced? res)
             (return (unreduced res))
             (setf acc res)))
    finally (return (funcall rf acc)))))

;;; ---------------------------------------------------------------------------
;;; into - conj items from source into target, optionally via transducer
;;; ---------------------------------------------------------------------------

(defun into (to xform-or-from &optional (from nil from-p))
  "Returns a new collection consisting of TO with all items of FROM conjoined.
   (into to from)        => reduce conj over from into to
   (into to xform from)  => transduce from through xform, conj into to

   Examples:
     (into [] [1 2 3])                => [1 2 3]
     (into #{} [1 2 1 3])             => #{1 2 3}
     (into [] (map inc) [1 2 3])      => [2 3 4]
     (into {} (map (fn [x] [x (* x x)])) [1 2 3]) => {1 1, 2 4, 3 9}"
  (if from-p
      ;; 3-arity: (into to xform from) - transduced
      (transduce xform-or-from #'fol.compiler.collection-functions:conj to from)
      ;; 2-arity: (into to from) - simple conj reduction
      (let ((iter (fol.compiler.collections:collection-seq xform-or-from))
            (acc to))
        (dolist (item iter)
          (setf acc (fol.compiler.collection-functions:conj acc item)))
        acc)))

;;; ===========================================================================
;;; Higher-Order Collection Functions
;;; ===========================================================================

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
        (make-instance 'fol.compiler.collections:<vector>
          :storage (fol.compiler.collection-primitives::%build-vec-t-from-list results)))
      (let* ((seq (fol.compiler.collections:collection-seq coll))
             (results (cl:mapcar fn seq)))
        (make-instance 'fol.compiler.collections:<vector>
          :storage (fol.compiler.collection-primitives::%build-vec-t-from-list results)))))

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
                                      (fol.compiler.mutable:submit-work fn args))
                           zipped))
             (results (cl:mapcar #'fol.compiler.mutable:wait-for-work work-items)))
        (apply #'fol.compiler.collections:make (class-name (class-of coll)) results))
      ;; Single collection - process in parallel
      (let* ((seq (fol.compiler.collections:collection-seq coll))
             (work-items (cl:mapcar (lambda (elem)
                                      (fol.compiler.mutable:submit-work fn (list elem)))
                           seq))
             (results (cl:mapcar #'fol.compiler.mutable:wait-for-work work-items)))
        (apply #'fol.compiler.collections:make (class-name (class-of coll)) results))))

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
    (make-instance 'fol.compiler.collections:<vector>
      :storage (fol.compiler.collection-primitives::%build-vec-t-from-list filtered))))

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
;;; pmapcat - parallel map followed by concatenation using thread pool
;;; ---------------------------------------------------------------------------

(defun pmapcat (fn coll)
  "Parallel version of mapcat. Apply FN to each element in parallel using a thread pool, then concatenate.
   FN should return a collection. Results are concatenated into same type as COLL.

   Examples:
     (pmapcat (fn [x] [x (* x 2)]) [1 2 3]) => [1 2 2 4 3 6]"
  (let* ((seq (fol.compiler.collections:collection-seq coll))
         (work-items (cl:mapcar (lambda (elem)
                                  (fol.compiler.mutable:submit-work fn (list elem)))
                       seq))
         (mapped (cl:mapcar #'fol.compiler.mutable:wait-for-work work-items))
         (seqs (cl:mapcar #'fol.compiler.collections:collection-seq mapped))
         (flattened (apply #'cl:append seqs)))
    (apply #'fol.compiler.collections:make (class-name (class-of coll)) flattened)))

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
;;; concat - Concatenate multiple collections
;;; ---------------------------------------------------------------------------

(defun concat (&rest colls)
  "Concatenate multiple collections into a single vector.

   Examples:
     (concat [1 2] [3 4] [5 6])  => [1 2 3 4 5 6]
     (concat #{1 2} [3 4])       => [1 2 3 4]  ; order may vary for set"
  (let* ((seqs (cl:mapcar #'fol.compiler.collections:collection-seq colls))
         (combined (apply #'cl:append seqs)))
    ;; Directly construct with %build-vec-t-from-list to avoid stack overflow
    ;; from apply with huge argument lists (e.g. 131,072 elements)
    (make-instance 'fol.compiler.collections:<vector>
      :storage (fol.compiler.collection-primitives::%build-vec-t-from-list combined))))

;;; ---------------------------------------------------------------------------
;;; keys - Get all keys from a dict
;;; ---------------------------------------------------------------------------

(defun keys (dict)
  "Return a vector of all keys in DICT.
   (keys {:a 1 :b 2 :c 3}) => [:a :b :c]  ; order may vary"
  (let ((seq (fol.compiler.collections:collection-seq dict)))
    (apply #'fol.compiler.collections:make
      'fol.compiler.collections:<vector>
      (cl:mapcar #'cl:car seq))))

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
    (make-instance 'fol.compiler.collections:<vector>
      :storage (fol.compiler.collection-primitives::%build-vec-t-from-list sorted))))

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

(defun sequence (xform-or-coll &optional (coll nil coll-p))
  "Coerce to vector, or apply transducer.
   (sequence coll)        => FOL vector of coll's elements
   (sequence xform coll)  => lazy-seq of transduced coll

   Examples:
     (sequence [1 2 3])            => [1 2 3]
     (sequence (map inc) [1 2 3])  => lazy-seq of [2 3 4]
     (sequence nil)                => []"
  (if coll-p
      ;; (sequence xform coll) - apply transducer, return lazy-seq
      (make-instance 'fol.compiler.collections:<lazy-seq>
        :thunk (lambda ()
                 (transduce xform-or-coll
                            #'fol.compiler.collection-functions:conj
                            (fol.compiler.collection-functions:vector)
                            coll)))
      ;; (sequence coll) - coerce to vector
      (if (null xform-or-coll)
          (fol.compiler.collections:make 'fol.compiler.collections:<vector>)
          (let ((s (fol.compiler.collections:collection-seq xform-or-coll)))
            (cl:apply #'fol.compiler.collections:make
              'fol.compiler.collections:<vector>
              s)))))

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
         (start (if (>= len 2) (first args) 0))
         (end (if (>= len 2) (second args) (first args)))
         (step (if (>= len 3) (third args) 1)))
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
(defun line-seq (rdr)
  "Returns the lines of text from rdr as a vector of strings."
  (let ((lines '()))
    (cl:loop
    for line = (fol.compiler.streams:stream-read-line rdr)
    while line
    do (push line lines))
    (apply #'fol.compiler.collections:make
      'fol.compiler.collections:<vector>
      (nreverse lines))))
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
  "Returns a sorted collection of the same type as COLL using COMP.
   (sort [3 1 2]) => [1 2 3]"
  (let* ((seq (collection-seq coll))
         ;; For dicts, we sort the pairs based on the comparator (applied to keys usually?)
         ;; Standard sort takes elements. For dicts, elements are (k . v).
         ;; If comp is cl:<, it expects numbers.
         ;; We should probably default to sorting by key if comp is default.
         (sorted (cl:sort (copy-list seq)
                   (if (and (typep coll 'fol.compiler.collections:<dict>)
                            (eq comp #'cl:<))
                       (lambda (a b) (cl:< (car a) (car b)))
                       comp))))
    (cond
     ((typep coll 'fol.compiler.collections:<dict>)
       (apply #'fol.compiler.collections:make
         (class-name (class-of coll))
         (loop for (k . v) in sorted collect k collect v)))
     ((listp coll)
       sorted)
     ((typep coll 'fol.compiler.collections:<vector>)
       (make-instance 'fol.compiler.collections:<vector>
         :storage (fol.compiler.collection-primitives::%build-vec-t-from-list sorted)))
     (t
       (apply #'fol.compiler.collections:make
         (class-name (class-of coll))
         sorted)))))

;;; ---------------------------------------------------------------------------
;;; reverse - reverse a collection
;;; ---------------------------------------------------------------------------

(defun reverse (coll)
  "Returns a collection of the same type as COLL with items in reverse order.
   If COLL is a sorted collection, returns a new sorted collection with an inverted comparator."
  (cond
   ;; Sorted Set: Invert comparator
   ((typep coll 'fol.compiler.collections:<sorted-set>)
     (let ((old-cmp (fol.compiler.collections:comparator-compare coll))
           (name (class-name (class-of coll))))
       ;; Case for <int-set>: coerce to generic <sorted-set> because <int-set> forces ascending
       (when (eq name 'fol.compiler.collections:<int-set>)
             (setf name 'fol.compiler.collections:<sorted-set>))
       (apply #'fol.compiler.collections:make
         name
         (lambda (a b) (funcall old-cmp b a))
         (fol.compiler.collections:collection-seq coll))))

   ;; Sorted Dict: Invert comparator
   ((typep coll 'fol.compiler.collections:<sorted-dict>)
     (let ((old-cmp (fol.compiler.collections:comparator-compare coll))
           (name (class-name (class-of coll))))
       ;; Case for <int-dict>: coerce to generic <sorted-dict> if needed,
       ;; but <int-dict> supports custom comparators so we might be ok,
       ;; except the constructor might force optimal fixnum cmp if arg is nil.
       ;; Passing a lambda comparator converts it to generic tree map logic anyway.
       (apply #'fol.compiler.collections:make
         name
         (lambda (a b) (funcall old-cmp b a))
         (loop for (k . v) in (fol.compiler.collections:collection-seq coll)
               collect k collect v))))

   ;; Priority Dict
   ((typep coll 'fol.compiler.collections:<priority-dict>)
     (let ((old-cmp (or (fol.compiler.collections:priority-dict-compare coll)
                        #'cl:<))) ;; Default priority logic
       (apply #'fol.compiler.collections:make
         (class-name (class-of coll))
         (lambda (a b) (if (funcall old-cmp a b) nil t)) ;; Invert boolean predicate? Or -1/0/1?
         ;; Priority dict compare is -1/0/1 or predicate?
         ;; Definition: "Comparator function... Returns negative/zero/positive fixnum"
         ;; So we invert args.
         (lambda (a b) (funcall old-cmp b a))
         (loop for (k . v) in (fol.compiler.collections:collection-seq coll)
               collect k collect v))))

   ;; Dense Int Set -> Vector (cannot be reversed as dense-int-set)
   ((typep coll 'fol.compiler.collections:<dense-int-set>)
     (apply #'fol.compiler.collections:make
       'fol.compiler.collections:<vector>
       (cl:reverse (fol.compiler.collections:collection-seq coll))))

   ;; Standard handling for Lists/Vectors/Deques
   (t
     (let ((rev-seq (cl:reverse (collection-seq coll))))
       (cond
        ((typep coll 'fol.compiler.collections:<dict>)
          (apply #'fol.compiler.collections:make
            (class-name (class-of coll))
            (loop for (k . v) in rev-seq collect k collect v)))
        ((listp coll)
          rev-seq)
        (t
          (apply #'fol.compiler.collections:make
            (class-name (class-of coll))
            rev-seq)))))))

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
  (let* ((n (if coll-p n-or-coll 1))
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
  (let* ((seq (collection-seq coll))
         (len (length seq))
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
;;; random-sample - random subset with given probability
;;; ---------------------------------------------------------------------------

(defun random-sample (prob &rest args)
  "Select elements with probability PROB. With no collection, returns transducer.

   Examples:
     (random-sample 0.5 [1 2 3 4 5 6])  => random subset
     (random-sample 0.5)                  => transducer"
  (if (null args)
      ;; Transducer
      (filter (lambda (_) (declare (ignore _)) (< (random 1.0) prob)))
      ;; Sequence function
      (let ((coll (cl:first args)))
        (let* ((seq (collection-seq coll))
               (result (cl:loop for elem in seq
                         when (< (random 1.0) (float prob))
                       collect elem)))
          (cl:apply #'fol.compiler.collections:make
            'fol.compiler.collections:<vector> result)))))

;;; ---------------------------------------------------------------------------
;;; seque - buffered sequence (simplified eager evaluation)
;;; ---------------------------------------------------------------------------

;;; ---------------------------------------------------------------------------
;;; Blocking Queue Helper
;;; ---------------------------------------------------------------------------

(defclass %blocking-queue ()
    ((queue :initform nil :accessor bq-queue)
     (tail :initform nil :accessor bq-tail)
     (count :initform 0 :accessor bq-count)
     (capacity :initarg :capacity :accessor bq-capacity)
     (lock :initform (bordeaux-threads:make-lock "bq") :accessor bq-lock)
     (not-full :initform (bordeaux-threads:make-condition-variable :name "not-full") :accessor bq-not-full)
     (not-empty :initform (bordeaux-threads:make-condition-variable :name "not-empty") :accessor bq-not-empty)))

(defun make-%blocking-queue (capacity)
  (make-instance '%blocking-queue :capacity capacity))

(defun bq-put (bq item)
  (bordeaux-threads:with-lock-held ((bq-lock bq))
    (loop while (cl:>= (bq-count bq) (bq-capacity bq))
          do (bordeaux-threads:condition-wait (bq-not-full bq) (bq-lock bq)))
    (let ((node (cl:cons item nil)))
      (if (bq-queue bq)
          (setf (cl:cdr (bq-tail bq)) node
            (bq-tail bq) node)
          (setf (bq-queue bq) node
            (bq-tail bq) node)))
    (cl:incf (bq-count bq))
    (bordeaux-threads:condition-notify (bq-not-empty bq))))

(defun bq-take (bq)
  (bordeaux-threads:with-lock-held ((bq-lock bq))
    (loop while (cl:zerop (bq-count bq))
          do (bordeaux-threads:condition-wait (bq-not-empty bq) (bq-lock bq)))
    (let ((item (cl:pop (bq-queue bq))))
      (unless (bq-queue bq)
        (setf (bq-tail bq) nil))
      (cl:decf (bq-count bq))
      (bordeaux-threads:condition-notify (bq-not-full bq))
      item)))

;;; ---------------------------------------------------------------------------
;;; seque - buffered sequence (async with agent)
;;; ---------------------------------------------------------------------------

(defun seque (n-or-coll &optional (coll nil coll-p))
  "Returns a vector backed by an asynchronous buffered queue.
   Uses an agent to buffer elements asynchronously, then collects into a vector.

   (seque s)       => uses default buffer size 100
   (seque n s)     => uses buffer size n

   Examples:
     (seque [1 2 3])
     (seque 5 (range 100))"
  (let ((n (if coll-p n-or-coll 100))
        (s (if coll-p coll n-or-coll)))
    (when (cl:<= n 0) (setf n 1))

    (let ((bq (make-%blocking-queue n))
          (ag (agent nil))
          (eos (cl:cons :eos nil))) ;; Unique sentinel

      ;; Start the producer agent
      (send-off ag
                (lambda (state)
                  (declare (ignore state))
                  ;; Iterate and push to queue (blocks if full)
                  (run! (lambda (x) (bq-put bq x)) s)
                  ;; Push EOS
                  (bq-put bq eos)
                  nil))

      ;; Drain the queue into a vector
      (let ((result '()))
        (cl:loop
        for x = (bq-take bq)
        until (eq x eos)
        do (push x result))
        (apply #'fol.compiler.collections:make
          'fol.compiler.collections:<vector>
          (nreverse result))))))

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
