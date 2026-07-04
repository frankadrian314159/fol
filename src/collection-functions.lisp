;;; FOL Compiler - Collection Constructor Functions
;;;
;;; Runtime functions for constructing FOL collections.
;;; These are called directly by compiled FOL code:
;;;   (vector 1 2 3)     => <vector> of 1, 2, 3
;;;   (dict :a 1 :b 2)   => <dict> with :a->1, :b->2
;;;   (set 1 2 3)         => <set> of 1, 2, 3

(in-package :fol.compiler.collection-functions)

;;; Helpers: construct <vector> from a CL list without apply (avoids stack overflow
;;; for very large lists, e.g. 131,072+ elements in the lsim benchmark).
(defun %make-vec (lst)
  (make-instance 'fol.compiler.collections:<vector>
    :storage (fol.compiler.collection-primitives::%build-vec-t-from-list lst)))

(defun %make-coll (class-sym lst)
  (if (eq class-sym 'fol.compiler.collections:<vector>)
      (%make-vec lst)
      (apply #'fol.compiler.collections:make class-sym lst)))

(defun vector (&rest args)
  "Create a new <vector> from ARGS.
   (vector)       => empty vector
   (vector 1 2 3) => vector of 1, 2, 3"
  (apply #'make '<vector> args))

(defun vec (coll)
  "Coerce COLL to a <vector>.  If COLL is already a <vector>, returns it
   unchanged.  Otherwise converts any collection or CL sequence to a <vector>.

   Examples:
     (vec [1 2 3])              => [1 2 3]   (identity)
     (vec (list 1 2 3))         => [1 2 3]
     (vec #{1 2 3})             => [1 2 3]   (order unspecified)
     (vec {:a 1 :b 2})          => [(:a . 1) (:b . 2)]
     (vec nil)                  => []
     (vec '(4 5 6))             => [4 5 6]   (CL list)"
  (cond
   ((null coll) (vector))
   ((typep coll 'fol.compiler.collections:<vector>) coll)
   ((typep coll 'fol.compiler.collections:<collection>)
     (apply #'vector (fol.compiler.collections:collection-seq coll)))
   ((cl:listp coll)
     (apply #'vector coll))
   ((cl:vectorp coll)
     (apply #'vector (coerce coll 'cl:list)))
   (t (cl:error "vec: cannot coerce ~S to a vector" coll))))

(defun vector-of (type &rest args)
  "Create a <vector> whose elements must all satisfy TYPE.
   TYPE is a FOL type symbol (e.g. <number>, <string>) or a CL type specifier.
   Signals an error if any element does not match the type.

   Examples:
     (vector-of '<number> 1 2 3)       => [1 2 3]
     (vector-of '<string> \"a\" \"b\")     => [\"a\" \"b\"]
     (vector-of '<number> 1 \"x\" 3)     => ERROR"
  (let ((cl-type (fol.compiler.destructure:fol-type-to-cl-type type)))
    (unless cl-type
      (cl:error "vector-of: unknown type ~S" type))
    (dolist (elem args)
      (unless (typep elem cl-type)
        (cl:error "vector-of: element ~S is not of type ~S" elem type)))
    (apply #'vector args)))

(defun dict (&rest args)
  "Create a new <dict> from alternating key-value ARGS.
   (dict)            => empty dict
   (dict :a 1 :b 2)  => dict with :a->1, :b->2"
  (apply #'make '<dict> args))

(defun ordered-dict (&rest args)
  "Create a new <ordered-dict> from alternating key-value ARGS.
   Preserves insertion order of keys.
   (ordered-dict)            => empty ordered dict
   (ordered-dict :a 1 :b 2)  => ordered dict with :a->1, :b->2"
  (apply #'make '<ordered-dict> args))

(defun array-dict (&rest args)
  "Create a new <array-dict> from alternating key-value ARGS.
   Preserves insertion order of keys.  Optimized for small, dense mappings.
   (array-dict)            => empty array dict
   (array-dict :a 1 :b 2)  => array dict with :a->1, :b->2"
  (apply #'make '<array-dict> args))

(defun set (&rest args)
  "Create a new <set> from ARGS.
   (set)       => empty set
   (set 1 2 3) => set of 1, 2, 3"
  (apply #'make '<set> args))

(defun ordered-set (&rest args)
  "Create a new <ordered-set> from ARGS.
   Duplicates are silently dropped; insertion order is preserved.
   (ordered-set)       => empty ordered set
   (ordered-set 1 2 3) => ordered set of 1, 2, 3"
  (apply #'make '<ordered-set> args))

(defun sorted-set (&rest args)
  "Create a new <sorted-set>.
   First argument is a comparator function (or NIL for default numeric order).
   Remaining arguments are elements.
   (sorted-set #'my-cmp 5 3 1) => sorted set of 1, 3, 5
   (sorted-set nil 5 3 1)      => sorted set with default numeric order"
  (apply #'make '<sorted-set> args))

(defun sorted-set-by (fn &rest items)
  "Create a new <sorted-set> with comparator FN and ITEMS.
   Equivalent to (sorted-set fn item1 item2 ...).
   (sorted-set-by #'my-cmp 5 3 1) => sorted set of 1, 3, 5
   (sorted-set-by nil 5 3 1)      => sorted set with default numeric order"
  (apply #'make '<sorted-set> fn items))

(defun int-set (&rest args)
  "Create a new <int-set> from integer ARGS.
   (int-set)       => empty int set
   (int-set 5 3 1) => int set of 1, 3, 5"
  (apply #'make '<int-set> args))

(defun sorted-dict (&rest args)
  "Create a new <sorted-dict>.
   First argument is a comparator function (or NIL for default numeric order).
   Remaining arguments are alternating key-value pairs.
   (sorted-dict #'my-cmp :b 2 :a 1) => sorted dict with :a->1, :b->2
   (sorted-dict nil 2 :b 1 :a)      => sorted dict with default numeric order"
  (apply #'make '<sorted-dict> args))

(defun sorted-dict-by (fn &rest pairs)
  "Create a new <sorted-dict> with comparator FN and alternating key-value PAIRS.
   Equivalent to (sorted-dict fn key1 val1 key2 val2 ...).
   (sorted-dict-by #'my-cmp :b 2 :a 1) => sorted dict with :a->1, :b->2"
  (apply #'make '<sorted-dict> fn pairs))

(defun int-dict (&rest args)
  "Create a new <int-dict> from alternating integer-key value ARGS.
   Keys are maintained in numeric order via a hardcoded fixnum comparator.
   (int-dict)          => empty int dict
   (int-dict 1 :a 2 :b) => int dict with 1->:a, 2->:b"
  (apply #'make '<int-dict> args))

(defun int-dict-by (fn &rest pairs)
  "Create a new <int-dict> with comparator FN and alternating key-value PAIRS.
   FN must accept two integers and return a negative fixnum, zero, or positive
   fixnum.  NIL uses the default ascending fixnum comparator.
   (int-dict-by #'my-cmp 2 :b 1 :a) => int dict with custom integer ordering"
  (apply #'make '<int-dict> fn pairs))

(defun priority-dict (&rest args)
  "Create a new <priority-dict> from alternating key-priority ARGS.
   Entries are ordered by priority ascending (min-first).
   (priority-dict)            => empty priority dict
   (priority-dict :a 1 :b 3)  => priority dict with :a→1, :b→3"
  (apply #'make '<priority-dict> args))

(defun dense-int-set (&rest args)
  "Create a new <dense-int-set> from integer ARGS.
   (dense-int-set)       => empty dense int set
   (dense-int-set 5 3 1) => dense int set of 1, 3, 5"
  (apply #'make '<dense-int-set> args))

(defun bag (&rest args)
  "Create a new <bag> from ARGS.
   Duplicate elements increase the count.
   (bag)       => empty bag
   (bag 1 1 2) => bag with two 1s and one 2"
  (apply #'make '<bag> args))

(defun deque (&rest args)
  "Create a new <deque> from ARGS.
   (deque)       => empty deque
   (deque 1 2 3) => deque with 1 at front, 3 at back"
  (apply #'make '<deque> args))

(defun list (&rest args)
  "Create a new <list> from ARGS.
   (list)       => empty list
   (list 1 2 3) => list of 1, 2, 3"
  (apply #'make '<list> args))

(defun lazy-seq (thunk)
  "Create a new <lazy-seq> from THUNK (a zero-argument function).
   (lazy-seq (lambda () (make '<list> 1 2 3))) => lazy sequence"
  (make '<lazy-seq> thunk))

(defun list* (&rest args)
  "Creates a list from ARGS with the last argument used as the tail.
   The last argument should be a collection or nil; preceding arguments
   are prepended in order.

   Examples:
     (list* 1 2 3 (list 4 5))  => (1 2 3 4 5)
     (list* 1 (list 2 3))      => (1 2 3)
     (list* (list 1 2))        => (1 2)
     (list* 1 2 nil)           => (1 2)"
  (when (null args)
        (cl:error "list* requires at least one argument"))
  (if (null (cl:rest args))
      (cl:first args)
      (let* ((tail (car (cl:last args)))
             (heads (butlast args))
             (result (cond
                      ((null tail) (list))
                      ((typep tail 'fol.compiler.collections:<list>) tail)
                      ((typep tail 'fol.compiler.collections:<collection>)
                        (apply #'list
                          (fol.compiler.collections:collection-seq tail)))
                      (t (list tail)))))
        (dolist (h (cl:reverse heads))
          (setf result (fol.compiler.collections:collection-conj result h)))
        result)))

;;; ===========================================================================
;;; High-Level Collection Accessor Functions
;;; ===========================================================================

(defgeneric count (collection)
  (:documentation "Returns the number of elements in the collection."))

(defmethod count ((collection <collection>))
  "Returns the number of elements in the collection."
  (fol.compiler.collections:collection-size collection))

(defmethod count ((collection string))
  "Returns the number of elements in the string."
  (length collection))

(defmethod count ((collection null))
  "Returns 0 for nil (empty)."
  0)

(defmethod count ((collection cons))
  "Returns the number of elements in a CL list."
  (cl:length collection))

(defmethod count ((collection t))
  "Returns 1 for any non-collection scalar value."
  1)

(defun size (collection)
  "Alias for count. Returns the number of elements."
  (count collection))

(defun empty? (collection)
  "Returns true if the collection is empty."
  (zerop (count collection)))

;;; ---------------------------------------------------------------------------
;;; distinct? - Returns true if no two arguments are equal
;;; ---------------------------------------------------------------------------

(defun distinct? (&rest args)
  "Returns true if no two of the arguments are equal (via EQUAL).

   Examples:
     (distinct? 1 2 3)     => T
     (distinct? 1 2 3 1)   => NIL
     (distinct? 1)          => T
     (distinct?)            => T"
  (let ((n (cl:length args)))
    (cond
     ((cl:<= n 1) t)
     ((cl:= n 2) (not (equal (cl:first args) (cl:second args))))
     (t (let ((seen (make-hash-table :test 'equal :size n)))
          (dolist (x args t)
            (if (gethash x seen)
                (return nil)
                (setf (gethash x seen) t))))))))

;;; ---------------------------------------------------------------------------
;;; every? - Returns true if pred is true for every element
;;; ---------------------------------------------------------------------------

(defun every? (pred coll)
  "Returns true if (PRED x) is logically true for every x in COLL.

   Examples:
     (every? odd? [1 3 5])   => T
     (every? odd? [1 2 3])   => NIL
     (every? pos? [])         => T"
  (dolist (x (fol.compiler.collections:collection-seq coll) t)
    (unless (fol.compiler.primitives:truthy? (funcall pred x))
      (return nil))))

;;; ---------------------------------------------------------------------------
;;; not-every? - Returns true if pred is false for at least one element
;;; ---------------------------------------------------------------------------

(defun not-every? (pred coll)
  "Returns true if (PRED x) is logically false for at least one x in COLL.
   Complement of every?.

   Examples:
     (not-every? odd? [1 2 3])   => T
     (not-every? odd? [1 3 5])   => NIL
     (not-every? pos? [])         => NIL"
  (not (every? pred coll)))

;;; ---------------------------------------------------------------------------
;;; not-any? - Returns true if pred is false for all elements
;;; ---------------------------------------------------------------------------

(defun not-any? (pred coll)
  "Returns true if (PRED x) is logically false for every x in COLL.
   Returns false if pred is true for at least one element.

   Examples:
     (not-any? odd? [2 4 6])   => T
     (not-any? odd? [1 2 3])   => NIL
     (not-any? pos? [])         => T"
  (dolist (x (fol.compiler.collections:collection-seq coll) t)
    (when (fol.compiler.primitives:truthy? (funcall pred x))
          (return nil))))

(defun conj (collection &rest items)
  "Add items to collection. Delegates to collection-conj.
   For multiple items, reduces over collection-conj."
  (if items
      (reduce #'fol.compiler.collections:collection-conj items
        :initial-value collection)
      collection))

;;; ---------------------------------------------------------------------------
;;; first - Returns the first element of an ordered collection
;;; ---------------------------------------------------------------------------

(defgeneric first (collection)
  (:documentation "Returns the first element of an ordered collection, or nil if empty."))

(defmethod first ((coll fol.compiler.collections:<collection>))
  (let ((seq (fol.compiler.collections:collection-seq coll)))
    (when seq (cl:first seq))))

(defmethod first ((coll cl:list))
  (cl:first coll))

(defmethod first ((coll (eql nil)))
  nil)

(defmethod first ((coll fol.compiler.collections:<vector>))
  (when (cl:plusp (fol.compiler.collections:collection-size coll))
        (ref coll 0)))

(defmethod first ((coll fol.compiler.collections:<array>))
  (when (cl:plusp (fol.compiler.collections:collection-size coll))
        (ref coll 0)))

(defmethod first ((coll fol.compiler.collections:<list>))
  (fol.compiler.collections:list-first coll))

(defmethod first ((coll fol.compiler.collections:<deque>))
  (when (cl:plusp (fol.compiler.collections:collection-size coll))
        (ref coll 0)))

(defmethod first ((coll fol.compiler.collections:<lazy-seq>))
  (fol.compiler.collections:realize-lazy-seq coll)
  (when (fol.compiler.collections:lazy-seq-realized-p coll)
        (first (fol.compiler.collections:lazy-seq-cached coll))))

;; Fallback for CL lists
(defmethod first ((coll cl:list))
  (cl:first coll))

;;; ---------------------------------------------------------------------------
;;; rest - Returns all elements except the first
;;; ---------------------------------------------------------------------------

(defgeneric rest (collection)
  (:documentation "Returns all elements except the first. Returns empty collection if <= 1 element."))

(defmethod rest ((coll fol.compiler.collections:<collection>))
  (let ((seq (fol.compiler.collections:collection-seq coll)))
    (if (cl:rest seq)
        (%make-coll (class-name (class-of coll)) (cl:rest seq))
        (make-instance (class-of coll)))))

(defmethod rest ((coll cl:list))
  (cl:rest coll))

(defmethod rest ((coll (eql nil)))
  nil)

(defmethod rest ((coll fol.compiler.collections:<vector>))
  (let ((sz (fol.compiler.collections:collection-size coll)))
    (if (cl:> sz 0)
        (%make-vec (cl:rest (fol.compiler.collections:collection-seq coll)))
        (make-instance 'fol.compiler.collections:<vector>))))

(defmethod rest ((coll fol.compiler.collections:<list>))
  (fol.compiler.collections:list-rest coll))

(defmethod rest ((coll fol.compiler.collections:<lazy-seq>))
  (let ((realized (fol.compiler.collections:realize-lazy-seq coll)))
    (when (typep realized 'fol.compiler.collections:<list>)
          (fol.compiler.collections:list-rest realized))))

;; Sets don't really support rest (unordered), so just return empty set
(defmethod rest ((coll fol.compiler.collections:<set>))
  (make-instance 'fol.compiler.collections:<set>
    :dict-storage (fol.compiler.collection-primitives::%make-hamt)))

;; Fallback for CL lists
(defmethod rest ((coll cl:list))
  (cl:rest coll))

;;; ---------------------------------------------------------------------------
;;; nth - Get element at index
;;; ---------------------------------------------------------------------------

(defgeneric nth (coll index &optional not-found)
  (:documentation "Returns the element at INDEX in COLL.
   Signals an error if INDEX is out of bounds and NOT-FOUND is not supplied.
   Returns NOT-FOUND when INDEX is out of bounds and NOT-FOUND is given."))

(defmethod nth ((coll fol.compiler.collections:<list>) index
                                                       &optional (not-found nil not-found-p))
  "Walk the linked list to the INDEX-th element."
  (cl:loop with current = coll
  for i from 0 below index
  do (setf current (fol.compiler.collections:list-rest current))
    (when (or (null current)
              (cl:zerop (fol.compiler.collections:list-size current)))
          (if not-found-p
              (return-from nth not-found)
              (cl:error "Index ~D out of bounds for list of size ~D"
                index (fol.compiler.collections:list-size coll))))
  finally (if (and current
                   (cl:plusp (fol.compiler.collections:list-size current)))
              (return-from nth
                           (fol.compiler.collections:list-first current))
              (if not-found-p
                  (return-from nth not-found)
                  (cl:error "Index ~D out of bounds for list of size ~D"
                    index
                    (fol.compiler.collections:list-size coll))))))

(defmethod nth ((coll fol.compiler.collections:<vector>) index
                                                         &optional (not-found nil not-found-p))
  "Look up INDEX in the persistent vector trie."
  (if not-found-p
      (ref coll index not-found)
      (multiple-value-bind (val found-p) (fol.compiler.collections:collection-ref coll index)
        (if found-p val
            (cl:error "Index ~D out of bounds for vector of size ~D"
              index (fol.compiler.collections:collection-size coll))))))

(defmethod nth ((coll fol.compiler.collections:<deque>) index
                                                        &optional (not-found nil not-found-p))
  "Look up INDEX in a deque."
  (declare (ignore not-found-p))
  (ref coll index not-found))

;;; ---------------------------------------------------------------------------
;;; peek - Inspect the element that pop would remove
;;; ---------------------------------------------------------------------------

(defgeneric peek (coll)
  (:documentation "Returns the element that pop would remove, without modifying the collection.
   For lists, returns the first element. Returns NIL for empty collections."))

(defmethod peek ((coll fol.compiler.collections:<list>))
  "Return the first element of the list, or NIL if empty."
  (when (cl:plusp (fol.compiler.collections:list-size coll))
        (fol.compiler.collections:list-first coll)))

(defmethod peek ((coll fol.compiler.collections:<vector>))
  "Return the last element of the vector, or NIL if empty.
   Clojure semantics: peek on a vector returns the last element."
  (let ((sz (fol.compiler.collections:size coll)))
    (if (cl:plusp sz)
        (ref coll (1- sz))
        nil)))

;;; ---------------------------------------------------------------------------
;;; push - Add an element at the natural insertion point
;;; ---------------------------------------------------------------------------

(defgeneric push (coll value)
  (:documentation "Returns a new collection with VALUE added at the natural insertion point.
   For lists, prepends to the front (stack semantics)."))

(defmethod push ((coll fol.compiler.collections:<list>) value)
  "Prepend VALUE to the front of the list."
  (fol.compiler.collections:collection-conj coll value))

;;; ---------------------------------------------------------------------------
;;; pop - Remove the element that peek would return
;;; ---------------------------------------------------------------------------

(defgeneric pop (coll)
  (:documentation "Returns a new collection without the element that peek would return.
   For lists, removes the first element. Signals an error on empty collections."))

(defmethod pop ((coll fol.compiler.collections:<list>))
  "Remove the first element from the list. Signals an error if empty."
  (if (cl:plusp (fol.compiler.collections:list-size coll))
      (fol.compiler.collections:list-rest coll)
      (cl:error "Cannot pop an empty list")))

(defmethod pop ((coll fol.compiler.collections:<vector>))
  "Return a new vector without the last element. Signals an error if empty.
   Clojure semantics: pop on a vector removes from the end."
  (if (cl:plusp (fol.compiler.collections:size coll))
      (make-instance 'fol.compiler.collections:<vector>
        :storage (fol.compiler.collection-primitives::%vec-t-pop (storage coll)))
      (cl:error "Cannot pop an empty vector")))

;;; ---------------------------------------------------------------------------
;;; index-of - Find first index of a value in a collection
;;; ---------------------------------------------------------------------------

(defmethod index-of ((coll fol.compiler.collections:<list>) value
                                                            &key from-index use-regex)
  "Find the first index of VALUE in the list, starting from FROM-INDEX.
   Returns NIL if not found."
  (declare (ignore use-regex))
  (cl:loop with current = coll
  with start = (or from-index 0)
  for i from 0
  while (and current (cl:plusp (fol.compiler.collections:list-size current)))
    when (and (cl:>= i start)
              (eql (fol.compiler.collections:list-first current) value))
    return i
  do (setf current (fol.compiler.collections:list-rest current))))

(defmethod index-of ((coll fol.compiler.collections:<vector>) value
                                                              &key from-index use-regex)
  "Find the first index of VALUE in the vector, starting from FROM-INDEX.
   Returns NIL if not found."
  (declare (ignore use-regex))
  (let ((sz (fol.compiler.collections:size coll))
        (start (or from-index 0)))
    (cl:loop for i from start below sz
      when (eql (ref coll i) value)
      return i)))

;;; ---------------------------------------------------------------------------
;;; last-index-of - Find last index of a value in a collection
;;; ---------------------------------------------------------------------------

(defmethod last-index-of ((coll fol.compiler.collections:<list>) value
                                                                 &key use-regex)
  "Find the last index of VALUE in the list.
   Returns NIL if not found."
  (declare (ignore use-regex))
  (cl:loop with current = coll
  with last-idx = nil
  for i from 0
  while (and current (cl:plusp (fol.compiler.collections:list-size current)))
    when (eql (fol.compiler.collections:list-first current) value)
  do (setf last-idx i)
  do (setf current (fol.compiler.collections:list-rest current))
  finally (return last-idx)))

(defmethod last-index-of ((coll fol.compiler.collections:<vector>) value
                                                                   &key use-regex)
  "Find the last index of VALUE in the vector.
   Returns NIL if not found."
  (declare (ignore use-regex))
  (let ((sz (fol.compiler.collections:size coll)))
    (cl:loop with last-idx = nil
    for i from 0 below sz
      when (eql (ref coll i) value)
    do (setf last-idx i)
    finally (return last-idx))))

;;; ---------------------------------------------------------------------------
;;; get - Get value by key (dict) or index (seq)
;;; ---------------------------------------------------------------------------

(defgeneric get (collection key &optional default)
  (:documentation "Get value by key (dict) or index (seq). Returns default if not found."))

(defmethod get ((coll fol.compiler.collections:<dict>) key &optional default)
  (ref coll key default))

(defmethod get ((coll fol.compiler.collections:<ordered-dict>) key &optional default)
  (ref coll key default))

(defmethod get ((coll fol.compiler.collections:<sorted-dict>) key &optional default)
  (ref coll key default))

(defmethod get ((coll fol.compiler.collections:<int-dict>) key &optional default)
  (ref coll key default))

(defmethod get ((coll fol.compiler.collections:<priority-dict>) key &optional default)
  (ref coll key default))

(defmethod get ((coll fol.compiler.collections:<vector>) index &optional default)
  (ref coll index default))

(defmethod get ((coll fol.compiler.collections:<array>) index &optional default)
  (let ((sz (fol.compiler.collections:collection-size coll)))
    (if (and (cl:integerp index) (cl:>= index 0) (cl:< index sz))
        (cl:values (ref coll index) t)
        (cl:values default nil))))

(defmethod get ((coll fol.compiler.collections:<array>) (indices cl:cons) &optional default)
  "Access a multi-dimensional array element by a list of indices.
   Validates that INDICES has the same length as the array dimensions and
   that each index is within bounds.  Computes the column-major linear index
   via %index and delegates to the integer-based get method."
  (let ((dims (fol.compiler.collections:array-dimension coll)))
    (unless (cl:= (cl:length dims) (cl:length indices))
      (cl:error "Expected ~D indices but got ~D"
        (cl:length dims) (cl:length indices)))
    (get coll (%index dims indices) default)))

(defmethod get ((coll fol.compiler.collections:<set>) element &optional default)
  (ref coll element default))

(defmethod get ((coll fol.compiler.collections:<sorted-set>) element &optional default)
  (ref coll element default))

(defmethod get ((coll fol.compiler.collections:<bag>) element &optional default)
  (ref coll element default))

(defmethod get ((coll fol.compiler.collections:<deque>) index &optional default)
  (ref coll index default))

(defmethod get ((coll fol.compiler.collections:<list>) index &optional default)
  "Get element by index (linear time)."
  (let ((i 0)
        (curr coll))
    (cl:loop
      (when (cl:null curr) (cl:return (cl:values default nil)))
      (when (cl:= i index) (cl:return (cl:values (fol.compiler.collections:list-first curr) t)))
      (cl:incf i)
      (setf curr (fol.compiler.collections:list-rest curr)))))

(defmethod get ((coll <persistent-object>) key &optional default)
  "Get slot/attribute value from a persistent object.
   Works transparently for both native-slot and vector-backed objects.
   Expects key to be a keyword symbol mapped to a slot."
  (let* ((class (class-of coll))
         (slot-name (fol.compiler.persistent::slot-name-from-keyword class key)))
    (if slot-name
        (if (slot-boundp coll slot-name)
            (slot-value coll slot-name)
            default)
        default)))

;; CL hash-table: use gethash
(defmethod get ((coll cl:hash-table) key &optional default)
  (cl:gethash key coll default))

;;; ---------------------------------------------------------------------------
;;; assoc - Returns new collection with key-value pairs added/updated
;;; ---------------------------------------------------------------------------

(defgeneric assoc (collection key value &rest kvs)
  (:documentation "Returns new collection with key-value pairs added/updated.
                   For vectors, key is index. For dicts, key is dict key."))

(defmethod assoc ((coll fol.compiler.collections:<dict>) key value &rest kvs)
  (let ((new-coll (fol.compiler.collections:collection-conj coll (cons key value))))
    (if kvs
        (apply #'assoc new-coll kvs)
        new-coll)))

(defmethod assoc ((coll fol.compiler.collections:<ordered-dict>) key value &rest kvs)
  (let ((new-coll (fol.compiler.collections:collection-conj coll (cons key value))))
    (if kvs
        (apply #'assoc new-coll kvs)
        new-coll)))

(defmethod assoc ((coll fol.compiler.collections:<sorted-dict>) key value &rest kvs)
  (let ((new-coll (fol.compiler.collections:collection-conj coll (cons key value))))
    (if kvs
        (apply #'assoc new-coll kvs)
        new-coll)))

(defmethod assoc ((coll fol.compiler.collections:<array>) index value &rest ivs)
  "Update an array element, preserving array type and dimension metadata."
  (let* ((dims (cl:slot-value coll (cl:intern "DIMENSION" :fol.compiler.collections)))
         (new-vec (fol.compiler.collection-functions:assoc
                   (make-instance 'fol.compiler.collections:<vector>
                     :storage (cl:slot-value coll (cl:intern "STORAGE" :fol.compiler.collections)))
                   index value))
         (new-arr (make-instance 'fol.compiler.collections:<array>
                    :dimension dims
                    :storage (cl:slot-value new-vec (cl:intern "STORAGE" :fol.compiler.collections)))))
    (if ivs
        (apply #'assoc new-arr ivs)
        new-arr)))

(defmethod assoc ((coll fol.compiler.collections:<vector>) index value &rest ivs)
  (let ((new-coll (fol.compiler.collections:collection-assoc coll index value)))
    (if ivs
        (apply #'assoc new-coll ivs)
        new-coll)))

(defmethod assoc ((coll <persistent-object>) key value &rest kvs)
  "Update slots in a persistent object. Key should be a symbol (it will be converted to a keyword-indexed slot)."
  (let ((new-coll (update-slot coll key value)))
    (if kvs
        (apply #'assoc new-coll kvs)
        new-coll)))

;;; ---------------------------------------------------------------------------
;;; dissoc - Returns new collection with specified keys removed
;;; ---------------------------------------------------------------------------

(defgeneric dissoc (collection &rest keys)
  (:documentation "Returns new collection with specified keys removed. Dict types only."))

(defmethod dissoc ((coll fol.compiler.collections:<dict>) &rest keys)
  (let ((result coll))
    (dolist (k keys result)
      (setf result (fol.compiler.collections:collection-dissoc result k)))))

(defmethod dissoc ((coll fol.compiler.collections:<ordered-dict>) &rest keys)
  (let ((result coll))
    (dolist (k keys result)
      (setf result (fol.compiler.collections:collection-dissoc result k)))))

(defmethod dissoc ((coll fol.compiler.collections:<sorted-dict>) &rest keys)
  (let ((result coll))
    (dolist (k keys result)
      (setf result (fol.compiler.collections:collection-dissoc result k)))))

(defmethod dissoc ((coll <persistent-object>) &rest keys)
  "Functional removal of slots from a persistent object. Dissoc'd slots become unbound."
  (apply #'dissoc-slots coll keys))


;;; ---------------------------------------------------------------------------
;;; UPDATE - Functional update via function
;;; ---------------------------------------------------------------------------

(defgeneric update (collection key updater-fn)
  (:documentation "Update a key by applying updater-fn to its current value (returns new collection)."))

(defmethod update ((coll fol.compiler.collections:<dict>) key updater-fn)
  (let* ((current-val (get coll key))
         (new-val (funcall updater-fn current-val)))
    (assoc coll key new-val)))

(defmethod update ((coll fol.compiler.collections:<ordered-dict>) key updater-fn)
  (let* ((current-val (get coll key))
         (new-val (funcall updater-fn current-val)))
    (assoc coll key new-val)))

(defmethod update ((coll fol.compiler.collections:<sorted-dict>) key updater-fn)
  (let* ((current-val (get coll key))
         (new-val (funcall updater-fn current-val)))
    (assoc coll key new-val)))

(defmethod update ((coll fol.compiler.collections:<vector>) index updater-fn)
  "Apply UPDATER-FN to the element at INDEX, returning a new vector.
   Signals an error if INDEX is out of bounds."
  (let ((current-val (nth coll index))) ; nth handles bounds checking
    (let ((new-val (funcall updater-fn current-val)))
      (assoc coll index new-val))))

;;; ---------------------------------------------------------------------------
;;; MERGE - Merge dict collections
;;; ---------------------------------------------------------------------------

(defgeneric merge (coll &rest colls)
  (:documentation "Merge collections (later values win on key conflicts)."))

(defmethod merge ((coll fol.compiler.collections:<dict>) &rest colls)
  (if (null colls)
      coll
      (let ((result coll))
        (dolist (other colls result)
          (dolist (pair (fol.compiler.collections:collection-seq other))
            (setf result (fol.compiler.collections:collection-assoc result (car pair) (cdr pair))))))))

(defmethod merge ((coll fol.compiler.collections:<ordered-dict>) &rest colls)
  (if (null colls)
      coll
      (let ((result coll))
        (dolist (other colls result)
          (dolist (pair (fol.compiler.collections:collection-seq other))
            (setf result (fol.compiler.collections:collection-assoc result (car pair) (cdr pair))))))))

(defmethod merge ((coll fol.compiler.collections:<sorted-dict>) &rest colls)
  (if (null colls)
      coll
      (let ((result coll))
        (dolist (other colls result)
          (dolist (pair (fol.compiler.collections:collection-seq other))
            (setf result (fol.compiler.collections:collection-assoc result (car pair) (cdr pair))))))))

;;; ---------------------------------------------------------------------------
;;; empty and not-empty
;;; ---------------------------------------------------------------------------

(defgeneric empty (coll)
  (:documentation "Returns an empty collection of the same type as COLL."))

(defmethod empty ((coll fol.compiler.collections:<collection>))
  "Default: create empty collection using make."
  (make (class-name (class-of coll))))

(defmethod empty ((coll fol.compiler.collections:<sorted-dict>))
  "Preserve comparator when creating empty sorted-dict."
  (make-instance 'fol.compiler.collections:<sorted-dict>
    :cmp-fn (fol.compiler.collections:cmp-fn coll)))

(defmethod empty ((coll fol.compiler.collections:<int-dict>))
  "Preserve comparator when creating empty int-dict."
  (make-instance 'fol.compiler.collections:<int-dict>))

(defmethod empty ((coll fol.compiler.collections:<sorted-set>))
  "Preserve comparator when creating empty sorted-set."
  (make-instance 'fol.compiler.collections:<sorted-set>
    :cmp-fn (fol.compiler.collections:cmp-fn coll)))

(defmethod empty ((coll fol.compiler.collections:<int-set>))
  "Preserve comparator when creating empty int-set."
  (make-instance 'fol.compiler.collections:<int-set>))

(defun not-empty (coll)
  "Returns COLL if it contains elements, NIL otherwise.

   Examples:
     (not-empty (vector 1 2 3))  => #<vector [1 2 3]>
     (not-empty (vector))        => NIL
     (not-empty nil)             => NIL"
  (if (or (null coll)
          (and (typep coll 'fol.compiler.collections:<collection>)
               (empty? coll)))
      nil
      coll))

;;; ---------------------------------------------------------------------------
;;; %index - Column-major linear index for multi-dimensional arrays
;;; ---------------------------------------------------------------------------

(defun %index (dimensions indices)
  "Returns a linear index in column-major order for the given DIMENSIONS and INDICES.
   Both DIMENSIONS and INDICES must be lists of the same length.
   Signals an error if any index is negative or >= its corresponding dimension.

   Column-major order means the first index varies fastest:
     For dimensions (d0 d1 d2) and indices (i0 i1 i2):
       linear = i0 + d0*i1 + d0*d1*i2

   Examples:
     (%index '(3 4) '(1 2))       => 7   ; 1 + 3*2
     (%index '(3 4 5) '(2 1 3))   => 41  ; 2 + 3*1 + 12*3
     (%index '(10) '(5))          => 5   ; trivial 1D case"
  (let ((ndims (cl:length dimensions))
        (nidx (cl:length indices)))
    (unless (cl:= ndims nidx)
      (cl:error "Expected ~D indices but got ~D" ndims nidx)))
  (let ((linear 0)
        (stride 1))
    (cl:loop for d in dimensions
    for i in indices
    do (unless (and (integerp i) (cl:>= i 0))
         (cl:error "Index ~D is not a non-negative integer" i))
      (when (cl:>= i d)
            (cl:error "Index ~D is out of bounds for dimension of size ~D" i d))
      (cl:incf linear (cl:* i stride))
      (setf stride (cl:* stride d)))
    linear))

;;; ---------------------------------------------------------------------------
;;; bounded-size - Count at most n elements
;;; ---------------------------------------------------------------------------

(defun bounded-size (n coll)
  "If COLL has O(1) size, returns its size.  Otherwise counts at most N
   elements by traversing the sequence.  Useful for checking whether a
   potentially lazy or expensive-to-count collection has at least N elements
   without forcing a full traversal.

   Examples:
     (bounded-size 5 (vector 1 2 3))       => 3
     (bounded-size 5 (vector 1 2 3 4 5 6)) => 6
     (bounded-size 3 (lazy-seq ...))        => at most 3"
  (typecase coll
    (null 0)
    (fol.compiler.collections:<lazy-seq>
     (let ((seq (fol.compiler.collections:collection-seq coll))
           (cnt 0))
       (dolist (item seq cnt)
         (declare (ignore item))
         (incf cnt)
         (when (cl:>= cnt n)
               (return cnt)))))
    (fol.compiler.collections:<collection>
     (fol.compiler.collections:collection-size coll))
    (cl:list
      (let ((cnt 0))
        (dolist (item coll cnt)
          (declare (ignore item))
          (incf cnt)
          (when (cl:>= cnt n)
                (return cnt)))))))

;;; ---------------------------------------------------------------------------
;;; into - Pour elements from one collection into another
;;; ---------------------------------------------------------------------------

(defgeneric into (to from)
  (:documentation "Add all elements from FROM into TO using conj semantics.
   Returns a new collection of the same type as TO.
   For dicts, FROM elements must be (key . value) cons pairs.
   For lists, elements are prepended (Clojure conj semantics).

   Examples:
     (into [] #{1 2 3})        => [1 2 3]  ; order may vary
     (into #{} [1 1 2 2 3])    => #{1 2 3}
     (into {} [(:a . 1) (:b . 2)]) => {:a 1 :b 2}"))

;;; --- Base method: works for any collection via the collection protocol ---

(defmethod into ((to fol.compiler.collections:<collection>)
                 (from fol.compiler.collections:<collection>))
  (cl:reduce #'fol.compiler.collections:collection-conj
    (fol.compiler.collections:collection-seq from)
    :initial-value to))

;;; --- Vector: use generic protocol ---

(defmethod into ((to <vector>) (from fol.compiler.collections:<collection>))
  (let ((result to))
    (dolist (elem (fol.compiler.collections:collection-seq from) result)
      (setf result (fol.compiler.collections:collection-conj result elem)))))

;;; --- Deque: use generic protocol ---

(defmethod into ((to <deque>) (from fol.compiler.collections:<collection>))
  (let ((result to))
    (dolist (elem (fol.compiler.collections:collection-seq from) result)
      (setf result (fol.compiler.collections:collection-conj result elem)))))

;;; --- Array: build CL array directly ---

(defmethod into ((to <array>) (from fol.compiler.collections:<collection>))
  (let* ((old-seq (fol.compiler.collections:collection-seq to))
         (new-elems (fol.compiler.collections:collection-seq from))
         (all-elems (append old-seq new-elems))
         (total (cl:length all-elems)))
    (make-instance '<array>
      :dimension (cl:list total)
      :storage (fol.compiler.collection-primitives::%build-vec-t-from-list all-elems))))

;;; --- Dict: use generic protocol ---

(defmethod into ((to <dict>) (from fol.compiler.collections:<collection>))
  (let ((result to))
    (dolist (pair (fol.compiler.collections:collection-seq from) result)
      (setf result (fol.compiler.collections:collection-assoc result (car pair) (cdr pair))))))

;;; --- Ordered-dict: use generic protocol ---

(defmethod into ((to <ordered-dict>) (from fol.compiler.collections:<collection>))
  (let ((result to))
    (dolist (pair (fol.compiler.collections:collection-seq from) result)
      (setf result (fol.compiler.collections:collection-assoc result (car pair) (cdr pair))))))

;;; --- Array-dict: use generic protocol ---

(defmethod into ((to <array-dict>) (from fol.compiler.collections:<collection>))
  (let ((result to))
    (dolist (pair (fol.compiler.collections:collection-seq from) result)
      (setf result (fol.compiler.collections:collection-assoc result (car pair) (cdr pair))))))

;;; --- Sorted-dict: use generic protocol (also handles <int-dict>) ---

(defmethod into ((to <sorted-dict>) (from fol.compiler.collections:<collection>))
  (let ((result to))
    (dolist (pair (fol.compiler.collections:collection-seq from) result)
      (setf result (fol.compiler.collections:collection-assoc result (car pair) (cdr pair))))))

;;; --- Priority-dict: use generic protocol ---

(defmethod into ((to <priority-dict>) (from fol.compiler.collections:<collection>))
  (let ((result to))
    (dolist (pair (fol.compiler.collections:collection-seq from) result)
      (setf result (fol.compiler.collections:collection-conj result pair)))))

;;; --- Set: use generic protocol ---

(defmethod into ((to <set>) (from fol.compiler.collections:<collection>))
  (let ((result to))
    (dolist (elem (fol.compiler.collections:collection-seq from) result)
      (setf result (fol.compiler.collections:collection-conj result elem)))))

;;; --- Ordered-set: use generic protocol ---

(defmethod into ((to <ordered-set>) (from fol.compiler.collections:<collection>))
  (let ((result to))
    (dolist (elem (fol.compiler.collections:collection-seq from) result)
      (setf result (fol.compiler.collections:collection-conj result elem)))))

;;; --- Sorted-set: use generic protocol (also handles <int-set>) ---

(defmethod into ((to <sorted-set>) (from fol.compiler.collections:<collection>))
  (let ((result to))
    (dolist (elem (fol.compiler.collections:collection-seq from) result)
      (setf result (fol.compiler.collections:collection-conj result elem)))))

;;; --- Bag: use generic protocol ---

(defmethod into ((to <bag>) (from fol.compiler.collections:<collection>))
  (let ((result to))
    (dolist (elem (fol.compiler.collections:collection-seq from) result)
      (setf result (fol.compiler.collections:collection-conj result elem)))))

;;; --- List: prepend each element (Clojure conj semantics) ---

(defmethod into ((to <list>) (from fol.compiler.collections:<collection>))
  (let ((result to))
    (dolist (elem (fol.compiler.collections:collection-seq from))
      (setf result (make-instance '<list>
                     :first-elem elem
                     :rest-list result
                     :list-size (1+ (fol.compiler.collections:list-size result)))))
    result))

;;; ===========================================================================
;;; Vector-specific functions and additional generic methods
;;; ===========================================================================

;;; ---------------------------------------------------------------------------
;;; assoc-in - Nested associative update
;;; ---------------------------------------------------------------------------

(defgeneric assoc-in (coll keys value)
  (:documentation "Nested associative update. KEYS is a list of keys/indices.
   Returns a new collection with the value at the nested path set to VALUE.
   (assoc-in [{:a 1}] '(0 :a) 2) => [{:a 2}]"))

(defmethod assoc-in ((coll fol.compiler.collections:<vector>) keys value)
  "Nested assoc into a vector. First key is an index, rest recurse."
  (let ((k (cl:first keys))
        (ks (cl:rest keys)))
    (if (null ks)
        (assoc coll k value)
        (let ((nested (nth coll k)))
          (assoc coll k (assoc-in nested ks value))))))

(defmethod assoc-in ((coll fol.compiler.collections:<dict>) keys value)
  "Nested assoc into a dict."
  (let ((k (cl:first keys))
        (ks (cl:rest keys)))
    (if (null ks)
        (assoc coll k value)
        (let ((nested (get coll k)))
          (assoc coll k (assoc-in nested ks value))))))

;;; ---------------------------------------------------------------------------
;;; update-in - Nested functional update
;;; ---------------------------------------------------------------------------

(defgeneric update-in (coll keys updater-fn)
  (:documentation "Nested functional update. KEYS is a list of keys/indices.
   Applies UPDATER-FN to the value at the nested path.
   (update-in [{:a 1}] '(0 :a) #'1+) => [{:a 2}]"))

(defmethod update-in ((coll fol.compiler.collections:<vector>) keys updater-fn)
  "Nested update into a vector. First key is an index, rest recurse."
  (let ((k (cl:first keys))
        (ks (cl:rest keys)))
    (if (null ks)
        (update coll k updater-fn)
        (let ((nested (nth coll k)))
          (assoc coll k (update-in nested ks updater-fn))))))

(defmethod update-in ((coll fol.compiler.collections:<dict>) keys updater-fn)
  "Nested update into a dict."
  (let ((k (cl:first keys))
        (ks (cl:rest keys)))
    (if (null ks)
        (update coll k updater-fn)
        (let ((nested (get coll k)))
          (assoc coll k (update-in nested ks updater-fn))))))

;;; ---------------------------------------------------------------------------
;;; rseq - Return reversed sequence
;;; ---------------------------------------------------------------------------

(defgeneric rseq (coll)
  (:documentation "Returns a reversed sequence of the collection as a CL list.
   Only supported on reversible collections (vectors, sorted collections).
   Returns NIL for empty collections."))

(defmethod rseq ((coll fol.compiler.collections:<vector>))
  "Return the elements of the vector in reverse order as a CL list."
  (let ((sz (fol.compiler.collections:collection-size coll)))
    (when (cl:plusp sz)
          (cl:loop for i from (1- sz) downto 0
          collect (ref coll i)))))

;;; ---------------------------------------------------------------------------
;;; reduce-kv - Reduce with key/index and value
;;; ---------------------------------------------------------------------------

(defgeneric reduce-kv (fn init coll)
  (:documentation "Reduce a collection with a 3-argument function (fn acc key val).
   For vectors, key is the index. For dicts, key is the dict key.
   Returns the accumulated result.
   (reduce-kv (fn [acc i v] (+ acc (* i v))) 0 [10 20 30]) => 80"))

(defmethod reduce-kv (fn init (coll fol.compiler.collections:<vector>))
  "Reduce a vector with (fn acc index value)."
  (let ((sz (fol.compiler.collections:collection-size coll))
        (acc init))
    (cl:loop for i from 0 below sz
    do (setf acc (funcall fn acc i (ref coll i))))
    acc))

(defmethod reduce-kv (fn init (coll fol.compiler.collections:<dict>))
  "Reduce a dict with (fn acc key value)."
  (let ((acc init))
    (dolist (pair (fol.compiler.collections:collection-seq coll))
      (setf acc (funcall fn acc (car pair) (cdr pair))))
    acc))

;;; ---------------------------------------------------------------------------
;;; subvec - Return a sub-vector
;;; ---------------------------------------------------------------------------

(defun subvec (v start &optional end)
  "Return a new vector containing elements from START (inclusive) to END (exclusive).
   If END is not supplied, returns elements from START to the end of the vector.

   Examples:
     (subvec [1 2 3 4 5] 1 3)  => [2 3]
     (subvec [1 2 3 4 5] 2)    => [3 4 5]
     (subvec [1 2 3 4 5] 0 0)  => []"
  (let* ((sz (fol.compiler.collections:collection-size v))
         (actual-end (or end sz)))
    (unless (and (integerp start) (cl:>= start 0) (cl:<= start sz))
      (cl:error "subvec: start ~D out of bounds for vector of size ~D" start sz))
    (unless (and (integerp actual-end) (cl:>= actual-end start) (cl:<= actual-end sz))
      (cl:error "subvec: end ~D out of bounds for vector of size ~D" actual-end sz))
    (if (cl:= start actual-end)
        (vector)
        (%make-vec (cl:loop for i from start below actual-end
          collect (ref v i))))))

;;; ===========================================================================
;;; Set Operations
;;; ===========================================================================

;;; ---------------------------------------------------------------------------
;;; contains? - Test membership in a set
;;; ---------------------------------------------------------------------------

(defgeneric contains? (set element)
  (:documentation "Returns T if SET contains ELEMENT, NIL otherwise.
   (contains? #{1 2 3} 2) => T
   (contains? #{1 2 3} 5) => NIL"))

(defmethod contains? ((s fol.compiler.collections:<set>) element)
  "Test membership in a set (HAMT-backed)."
  (nth-value 1 (fol.compiler.collection-primitives::hamt-get
                (fol.compiler.collection-primitives:dict-storage s) element)))

(defmethod contains? ((s fol.compiler.collections:<ordered-set>) element)
  "Test membership in an ordered-set (HAMT-backed)."
  (nth-value 1 (fol.compiler.collection-primitives::hamt-get
                (fol.compiler.collection-primitives:dict-storage s) element)))

(defmethod contains? ((s fol.compiler.collections:<sorted-set>) element)
  "Test membership in a sorted set (btree-backed)."
  (nth-value 1 (fol.compiler.collection-primitives::btree-get
                (fol.compiler.collection-primitives::btree-dict-root
                 (fol.compiler.collection-primitives:sorted-dict-storage s))
                element (fol.compiler.collections:cmp-fn s))))

(defmethod contains? ((s fol.compiler.collections:<int-set>) element)
  "Test membership in an int set (btree-backed)."
  (nth-value 1 (fol.compiler.collection-primitives::btree-get
                (fol.compiler.collection-primitives::btree-dict-root
                 (fol.compiler.collection-primitives:sorted-dict-storage s))
                element (fol.compiler.collections:cmp-fn s))))

;;; ---------------------------------------------------------------------------
;;; disj - Remove elements from a set
;;; ---------------------------------------------------------------------------

(defgeneric disj (set &rest elements)
  (:documentation "Returns a new set with ELEMENTS removed.
   (disj #{1 2 3} 2) => #{1 3}
   (disj #{1 2 3} 2 3) => #{1}"))

(defmethod disj ((s fol.compiler.collections:<set>) &rest elements)
  "Remove ELEMENTS from a set."
  (let ((result s))
    (dolist (elem elements result)
      (setf result (fol.compiler.collections:collection-dissoc result elem)))))

(defmethod disj ((s fol.compiler.collections:<ordered-set>) &rest elements)
  "Remove ELEMENTS from an ordered-set."
  (let ((result s))
    (dolist (elem elements result)
      (setf result (fol.compiler.collections:collection-dissoc result elem)))))

(defmethod disj ((s fol.compiler.collections:<sorted-set>) &rest elements)
  "Remove ELEMENTS from a sorted set."
  (let ((result s))
    (dolist (elem elements result)
      (setf result (fol.compiler.collections:collection-dissoc result elem)))))

(defmethod disj ((s fol.compiler.collections:<int-set>) &rest elements)
  "Remove ELEMENTS from an int-set."
  (let ((result s))
    (dolist (elem elements result)
      (setf result (fol.compiler.collections:collection-dissoc result elem)))))

;;; ---------------------------------------------------------------------------
;;; union - Set union
;;; ---------------------------------------------------------------------------

(defgeneric binary-union (set1 set2)
  (:documentation "Returns a new set that is the union of SET1 and SET2."))

(defun union (set1 &rest others)
  "Returns the union of set1 and all OTHERS. Supports multiple arguments."
  (if others
      (reduce #'binary-union others :initial-value set1)
      set1))

(defmethod binary-union ((s1 fol.compiler.collections:<set>)
                         (s2 fol.compiler.collections:<set>))
  "Union of two sets."
  (let ((result s1))
    (dolist (elem (fol.compiler.collections:collection-seq s2) result)
      (setf result (fol.compiler.collections:collection-conj result elem)))))

(defmethod binary-union ((s1 fol.compiler.collections:<ordered-set>)
                         (s2 fol.compiler.collections:<ordered-set>))
  "Union of two ordered-sets. Elements from s1 come first, then novel elements from s2."
  (let ((result s1))
    (dolist (elem (fol.compiler.collections:collection-seq s2) result)
      (setf result (fol.compiler.collections:collection-conj result elem)))))

(defmethod binary-union ((s1 fol.compiler.collections:<sorted-set>)
                         (s2 fol.compiler.collections:<sorted-set>))
  "Union of two sorted sets."
  (let ((result s1))
    (dolist (elem (fol.compiler.collections:collection-seq s2) result)
      (setf result (fol.compiler.collections:collection-conj result elem)))))

(defmethod binary-union ((s1 fol.compiler.collections:<int-set>)
                         (s2 fol.compiler.collections:<int-set>))
  "Union of two int-sets."
  (let ((result s1))
    (dolist (elem (fol.compiler.collections:collection-seq s2) result)
      (setf result (fol.compiler.collections:collection-conj result elem)))))

(defmethod binary-union ((s1 fol.compiler.collections:<dense-int-set>)
                         (s2 fol.compiler.collections:<dense-int-set>))
  (int-set-union s1 s2))

;;; ---------------------------------------------------------------------------
;;; difference - Set difference
;;; ---------------------------------------------------------------------------

(defgeneric binary-difference (set1 set2)
  (:documentation "Returns a new set containing elements in SET1 but not in SET2."))

(defun difference (set1 &rest others)
  "Returns the difference of set1 and all OTHERS (elements in s1 not in others)."
  (if others
      (reduce #'binary-difference others :initial-value set1)
      set1))

(defmethod binary-difference ((s1 fol.compiler.collections:<set>)
                              (s2 fol.compiler.collections:<set>))
  "Difference of two sets."
  (let ((result s1))
    (dolist (elem (fol.compiler.collections:collection-seq s2) result)
      (setf result (fol.compiler.collections:collection-dissoc result elem)))))

(defmethod binary-difference ((s1 fol.compiler.collections:<ordered-set>)
                              (s2 fol.compiler.collections:<ordered-set>))
  "Difference of two ordered-sets. Preserves insertion order from s1."
  (let ((result s1))
    (dolist (elem (fol.compiler.collections:collection-seq s2) result)
      (setf result (fol.compiler.collections:collection-dissoc result elem)))))

(defmethod binary-difference ((s1 fol.compiler.collections:<sorted-set>)
                              (s2 fol.compiler.collections:<sorted-set>))
  "Difference of two sorted sets."
  (let ((result s1))
    (dolist (elem (fol.compiler.collections:collection-seq s2) result)
      (setf result (fol.compiler.collections:collection-dissoc result elem)))))

(defmethod binary-difference ((s1 fol.compiler.collections:<int-set>)
                              (s2 fol.compiler.collections:<int-set>))
  "Difference of two int-sets."
  (let ((result s1))
    (dolist (elem (fol.compiler.collections:collection-seq s2) result)
      (setf result (fol.compiler.collections:collection-dissoc result elem)))))

(defmethod binary-difference ((s1 fol.compiler.collections:<dense-int-set>)
                              (s2 fol.compiler.collections:<dense-int-set>))
  (int-set-difference s1 s2))

;;; ---------------------------------------------------------------------------
;;; intersection - Set intersection
;;; ---------------------------------------------------------------------------

(defgeneric binary-intersection (set1 set2)
  (:documentation "Returns a new set containing elements common to SET1 and SET2."))

(defun intersection (set1 &rest others)
  "Returns the intersection of set1 and all OTHERS. Supports multiple arguments."
  (if others
      (reduce #'binary-intersection others :initial-value set1)
      set1))

(defmethod binary-intersection ((s1 fol.compiler.collections:<set>)
                                (s2 fol.compiler.collections:<set>))
  "Intersection of two sets."
  (let ((result (empty s1)))
    (dolist (elem (fol.compiler.collections:collection-seq s1) result)
      (when (contains? s2 elem)
            (setf result (fol.compiler.collections:collection-conj result elem))))))

(defmethod binary-intersection ((s1 fol.compiler.collections:<ordered-set>)
                                (s2 fol.compiler.collections:<ordered-set>))
  "Intersection of two ordered-sets. Preserves insertion order from s1."
  (let ((result (empty s1)))
    (dolist (elem (fol.compiler.collections:collection-seq s1) result)
      (when (contains? s2 elem)
            (setf result (fol.compiler.collections:collection-conj result elem))))))

(defmethod binary-intersection ((s1 fol.compiler.collections:<sorted-set>)
                                (s2 fol.compiler.collections:<sorted-set>))
  "Intersection of two sorted sets."
  (let ((result (empty s1)))
    (dolist (elem (fol.compiler.collections:collection-seq s1) result)
      (when (contains? s2 elem)
            (setf result (fol.compiler.collections:collection-conj result elem))))))

(defmethod binary-intersection ((s1 fol.compiler.collections:<int-set>)
                                (s2 fol.compiler.collections:<int-set>))
  "Intersection of two int-sets."
  (let ((result (empty s1)))
    (dolist (elem (fol.compiler.collections:collection-seq s1) result)
      (when (contains? s2 elem)
            (setf result (fol.compiler.collections:collection-conj result elem))))))

(defmethod binary-intersection ((s1 fol.compiler.collections:<dense-int-set>)
                                (s2 fol.compiler.collections:<dense-int-set>))
  (int-set-intersection s1 s2))
;;; ---------------------------------------------------------------------------
;;; select - Filter a set by predicate
;;; ---------------------------------------------------------------------------

(defgeneric select (pred set)
  (:documentation "Returns a new set containing only elements of SET for which PRED returns true.
   (select #'evenp #{1 2 3 4}) => #{2 4}"))

(defmethod select (pred (s fol.compiler.collections:<set>))
  "Filter a set by predicate."
  (let ((result (empty s)))
    (dolist (elem (fol.compiler.collections:collection-seq s) result)
      (when (funcall pred elem)
            (setf result (fol.compiler.collections:collection-conj result elem))))))

(defmethod select (pred (s fol.compiler.collections:<ordered-set>))
  "Filter an ordered-set by predicate, preserving insertion order."
  (let ((result (empty s)))
    (dolist (elem (fol.compiler.collections:collection-seq s) result)
      (when (funcall pred elem)
            (setf result (fol.compiler.collections:collection-conj result elem))))))

(defmethod select (pred (s fol.compiler.collections:<sorted-set>))
  "Filter a sorted-set by predicate, preserving comparator."
  (let ((result (empty s)))
    (dolist (elem (fol.compiler.collections:collection-seq s) result)
      (when (funcall pred elem)
            (setf result (fol.compiler.collections:collection-conj result elem))))))

(defmethod select (pred (s fol.compiler.collections:<int-set>))
  "Filter an int-set by predicate."
  (let ((result (empty s)))
    (dolist (elem (fol.compiler.collections:collection-seq s) result)
      (when (funcall pred elem)
            (setf result (fol.compiler.collections:collection-conj result elem))))))

;;; ---------------------------------------------------------------------------
;;; subset? - Test if one set is a subset of another
;;; ---------------------------------------------------------------------------

(defgeneric subset? (set1 set2)
  (:documentation "Returns T if every element of SET1 is also in SET2.
   (subset? #{1 2} #{1 2 3}) => T
   (subset? #{1 4} #{1 2 3}) => NIL"))

(defmethod subset? ((s1 fol.compiler.collections:<set>)
                    (s2 fol.compiler.collections:<set>))
  "Test if s1 is a subset of s2."
  (dolist (elem (fol.compiler.collections:collection-seq s1) t)
    (unless (contains? s2 elem)
      (return nil))))

(defmethod subset? ((s1 fol.compiler.collections:<ordered-set>)
                    (s2 fol.compiler.collections:<ordered-set>))
  "Test if s1 is a subset of s2 (ordered-sets)."
  (dolist (elem (fol.compiler.collections:collection-seq s1) t)
    (unless (contains? s2 elem)
      (return nil))))

(defmethod subset? ((s1 fol.compiler.collections:<sorted-set>)
                    (s2 fol.compiler.collections:<sorted-set>))
  "Test if s1 is a subset of s2 (sorted sets)."
  (dolist (elem (fol.compiler.collections:collection-seq s1) t)
    (unless (contains? s2 elem)
      (return nil))))

;;; ---------------------------------------------------------------------------
;;; superset? - Test if one set is a superset of another
;;; ---------------------------------------------------------------------------

(defgeneric superset? (set1 set2)
  (:documentation "Returns T if SET1 contains every element of SET2.
   (superset? #{1 2 3} #{1 2}) => T
   (superset? #{1 2 3} #{1 4}) => NIL"))

(defmethod superset? ((s1 fol.compiler.collections:<set>)
                      (s2 fol.compiler.collections:<set>))
  "Test if s1 is a superset of s2 (hash-sets)."
  (subset? s2 s1))

(defmethod superset? ((s1 fol.compiler.collections:<ordered-set>)
                      (s2 fol.compiler.collections:<ordered-set>))
  "Test if s1 is a superset of s2 (ordered-sets)."
  (subset? s2 s1))

(defmethod superset? ((s1 fol.compiler.collections:<sorted-set>)
                      (s2 fol.compiler.collections:<sorted-set>))
  "Test if s1 is a superset of s2 (sorted tree-sets)."
  (subset? s2 s1))

;;; ---------------------------------------------------------------------------
;;; rseq - Reverse sequence for sorted-set
;;; ---------------------------------------------------------------------------

(defmethod rseq ((coll fol.compiler.collections:<sorted-set>))
  "Return the elements of the sorted-set in reverse sorted order as a CL list."
  (let ((seq (fol.compiler.collections:collection-seq coll)))
    (when seq (cl:reverse seq))))

(defmethod rseq ((coll fol.compiler.collections:<int-set>))
  "Return the elements of the int-set in reverse sorted order as a CL list."
  (let ((seq (fol.compiler.collections:collection-seq coll)))
    (when seq (cl:reverse seq))))

;;; ---------------------------------------------------------------------------
;;; subseq - Range query on sorted sets (Clojure-style API)
;;; ---------------------------------------------------------------------------

(defgeneric subseq (sc test key &optional end-test end-key)
  (:documentation "Returns a CL list of elements from sorted collection SC that satisfy
   the given range tests, in sorted order.
   TEST and END-TEST are comparison operators: >=, >, <=, <
   (subseq (sorted-set nil 1 2 3 4 5) >= 3)       => (3 4 5)
   (subseq (sorted-set nil 1 2 3 4 5) >= 2 < 5)   => (2 3 4)"))

(defmethod subseq ((sc fol.compiler.collections:<sorted-set>) test key
                                                              &optional end-test end-key)
  "Range query on a sorted tree-set."
  (let* ((cmp (fol.compiler.collections:comparator-compare sc))
         (elements (fol.compiler.collections:collection-seq sc))
         ;; Standard comparator: -1 when a<b, 1 when a>b, 0 when a=b
         (start-pred (cond
                      ((eq test '>=) (lambda (e) (cl:>= (funcall cmp e key) 0)))
                      ((eq test '>) (lambda (e) (cl:> (funcall cmp e key) 0)))
                      ((eq test '<=) (lambda (e) (cl:<= (funcall cmp e key) 0)))
                      ((eq test '<) (lambda (e) (cl:< (funcall cmp e key) 0)))
                      (t (cl:error "subseq: invalid test ~S, must be >=, >, <=, or <" test))))
         (end-pred (when end-test
                         (cond
                          ((eq end-test '>=) (lambda (e) (cl:>= (funcall cmp e end-key) 0)))
                          ((eq end-test '>) (lambda (e) (cl:> (funcall cmp e end-key) 0)))
                          ((eq end-test '<=) (lambda (e) (cl:<= (funcall cmp e end-key) 0)))
                          ((eq end-test '<) (lambda (e) (cl:< (funcall cmp e end-key) 0)))
                          (t (cl:error "subseq: invalid end-test ~S, must be >=, >, <=, or <"
                               end-test))))))
    (cl:loop for e in elements
      when (and (funcall start-pred e)
                (or (null end-pred) (funcall end-pred e)))
    collect e)))

;;; ---------------------------------------------------------------------------
;;; rsubseq - Reverse range query on sorted sets (Clojure-style API)
;;; ---------------------------------------------------------------------------

(defgeneric rsubseq (sc test key &optional end-test end-key)
  (:documentation "Returns a CL list of elements from sorted collection SC that satisfy
   the given range tests, in reverse sorted order.
   TEST and END-TEST are comparison operators: >=, >, <=, <
   (rsubseq (sorted-set nil 1 2 3 4 5) >= 3)     => (5 4 3)
   (rsubseq (sorted-set nil 1 2 3 4 5) >= 2 < 5) => (4 3 2)"))

(defmethod rsubseq ((sc fol.compiler.collections:<sorted-set>) test key
                                                               &optional end-test end-key)
  "Reverse range query on a sorted tree-set."
  (cl:reverse (subseq sc test key end-test end-key)))

(defmethod subseq ((sc fol.compiler.collections:<int-set>) test key
                                                           &optional end-test end-key)
  "Range query on an int-set."
  (let* ((cmp (fol.compiler.collections:comparator-compare sc))
         (elements (fol.compiler.collections:collection-seq sc))
         ;; Standard comparator: -1 when a<b, 1 when a>b, 0 when a=b
         (start-pred (cond
                      ((eq test '>=) (lambda (e) (cl:>= (funcall cmp e key) 0)))
                      ((eq test '>) (lambda (e) (cl:> (funcall cmp e key) 0)))
                      ((eq test '<=) (lambda (e) (cl:<= (funcall cmp e key) 0)))
                      ((eq test '<) (lambda (e) (cl:< (funcall cmp e key) 0)))
                      (t (cl:error "subseq: invalid test ~S" test))))
         (end-pred (when end-test
                         (cond
                          ((eq end-test '>=) (lambda (e) (cl:>= (funcall cmp e end-key) 0)))
                          ((eq end-test '>) (lambda (e) (cl:> (funcall cmp e end-key) 0)))
                          ((eq end-test '<=) (lambda (e) (cl:<= (funcall cmp e end-key) 0)))
                          ((eq end-test '<) (lambda (e) (cl:< (funcall cmp e end-key) 0)))
                          (t (cl:error "subseq: invalid end-test ~S" end-test))))))
    (cl:loop for e in elements
      when (and (funcall start-pred e)
                (or (null end-pred) (funcall end-pred e)))
    collect e)))

(defmethod rsubseq ((sc fol.compiler.collections:<int-set>) test key
                                                            &optional end-test end-key)
  "Reverse range query on an int-set."
  (cl:reverse (subseq sc test key end-test end-key)))

;;; ===========================================================================
;;; Dict Operations
;;; ===========================================================================

;;; ---------------------------------------------------------------------------
;;; contains? for dicts - Test if a key exists
;;; ---------------------------------------------------------------------------

(defmethod contains? ((d fol.compiler.collections:<dict>) key)
  "Returns T if dict D contains KEY."
  (nth-value 1 (ref d key)))

(defmethod contains? ((d fol.compiler.collections:<sorted-dict>) key)
  "Returns T if sorted-dict D contains KEY."
  (nth-value 1 (fol.compiler.collections:collection-ref d key)))

(defgeneric superset? (coll1 coll2)
  (:documentation "Returns T if every element in COLL2 is also in COLL1."))

(defmethod superset? ((s1 fol.compiler.collections:<set>) (s2 fol.compiler.collections:<set>))
  (subset? s2 s1))

(defmethod superset? ((s1 fol.compiler.collections:<sorted-set>) (s2 fol.compiler.collections:<sorted-set>))
  (subset? s2 s1))


;;; ---------------------------------------------------------------------------
;;; find - Look up a key and return the map entry
;;; ---------------------------------------------------------------------------

(defgeneric find (coll key)
  (:documentation "Returns the map entry (key . value) for KEY in COLL, or NIL if not found.
   (find {:a 1 :b 2} :a) => (:a . 1)
   (find {:a 1 :b 2} :c) => NIL"))

(defmethod find ((d fol.compiler.collections:<dict>) key)
  "Look up KEY in dict, returning (key . value) or NIL."
  (multiple-value-bind (val found)
      (ref d key)
    (if found (cons key val) nil)))

(defmethod find ((d fol.compiler.collections:<sorted-dict>) key)
  "Look up KEY in sorted-dict, returning (key . value) or NIL."
  (multiple-value-bind (val found)
      (fol.compiler.collections:collection-ref d key)
    (if found (cons key val) nil)))

;;; ---------------------------------------------------------------------------
;;; get-in - Nested key lookup
;;; ---------------------------------------------------------------------------

(defgeneric get-in (coll keys &optional not-found)
  (:documentation "Look up a nested path of keys in COLL. Returns NOT-FOUND if the path
   does not exist (defaults to NIL).
   (get-in {:a {:b 1}} '(:a :b))       => 1
   (get-in {:a {:b 1}} '(:a :c) :nope) => :nope"))

(defmethod get-in ((d fol.compiler.collections:<dict>) keys &optional not-found)
  "Nested lookup in a dict."
  (let ((current d))
    (dolist (k keys)
      (if (and current (typep current 'fol.compiler.collections:<collection>))
          (let ((entry (if (typep current 'fol.compiler.collections:<dict>)
                           (find current k)
                           nil)))
            (if entry
                (setf current (cdr entry))
                (return-from get-in not-found)))
          (return-from get-in not-found)))
    current))

(defmethod get-in ((v fol.compiler.collections:<vector>) keys &optional not-found)
  "Nested lookup in a vector (first key is an index, rest recurse)."
  (let ((current v))
    (dolist (k keys)
      (cond
       ((typep current 'fol.compiler.collections:<vector>)
         (let ((sz (fol.compiler.collections:collection-size current)))
           (if (and (integerp k) (cl:>= k 0) (cl:< k sz))
               (setf current (ref current k))
               (return-from get-in not-found))))
       ((typep current 'fol.compiler.collections:<dict>)
         (let ((entry (find current k)))
           (if entry
               (setf current (cdr entry))
               (return-from get-in not-found))))
       (t (return-from get-in not-found))))
    current))

;;; ---------------------------------------------------------------------------
;;; vals - Return all values from a dict
;;; ---------------------------------------------------------------------------

(defun vals (dict)
  "Return a vector of all values in DICT.

   Examples:
     (vals {:a 1 :b 2})  => [1 2]  ; order may vary for unordered dicts"
  (let ((seq (fol.compiler.collections:collection-seq dict)))
    (%make-vec (cl:mapcar #'cl:cdr seq))))

;;; ---------------------------------------------------------------------------
;;; key - Extract key from a map entry
;;; ---------------------------------------------------------------------------

(defun key (entry)
  "Return the key of a map entry (cons pair).
   (key (first (seq {:a 1}))) => :a"
  (car entry))

;;; ---------------------------------------------------------------------------
;;; val - Extract value from a map entry
;;; ---------------------------------------------------------------------------

(defun val (entry)
  "Return the value of a map entry (cons pair).
   (val (first (seq {:a 1}))) => 1"
  (cdr entry))

;;; ---------------------------------------------------------------------------
;;; merge-with - Merge dicts with a conflict-resolution function
;;; ---------------------------------------------------------------------------

(defgeneric merge-with (f coll &rest colls)
  (:documentation "Merge dicts. When a key exists in both, apply F to the existing and
   new values: (f val-in-result val-in-other).
   (merge-with #'+ {:a 1} {:a 2 :b 3}) => {:a 3 :b 3}"))

(defmethod merge-with (f (coll fol.compiler.collections:<dict>) &rest colls)
  (let ((result coll))
    (dolist (other colls result)
      (dolist (pair (fol.compiler.collections:collection-seq other))
        (let ((k (car pair)) (v (cdr pair)))
          (multiple-value-bind (existing found) (ref result k)
            (setf result (fol.compiler.collections:collection-assoc
                          result k (if found (funcall f existing v) v)))))))))

(defmethod merge-with (f (coll fol.compiler.collections:<ordered-dict>) &rest colls)
  (let ((result coll))
    (dolist (other colls result)
      (dolist (pair (fol.compiler.collections:collection-seq other))
        (let ((k (car pair)) (v (cdr pair)))
          (multiple-value-bind (existing found) (ref result k)
            (setf result (fol.compiler.collections:collection-assoc
                          result k (if found (funcall f existing v) v)))))))))

(defmethod merge-with (f (coll fol.compiler.collections:<sorted-dict>) &rest colls)
  (let ((result coll))
    (dolist (other colls result)
      (dolist (pair (fol.compiler.collections:collection-seq other))
        (let ((k (car pair)) (v (cdr pair)))
          (multiple-value-bind (existing found) (fol.compiler.collections:collection-ref result k)
            (setf result (fol.compiler.collections:collection-assoc
                          result k (if found (funcall f existing v) v)))))))))

;;; ---------------------------------------------------------------------------
;;; select-keys - Extract a subset of keys from a dict
;;; ---------------------------------------------------------------------------

(defun select-keys (dict keys)
  "Return a new dict containing only the entries whose keys are in KEYS.
   (select-keys {:a 1 :b 2 :c 3} '(:a :c)) => {:a 1 :c 3}"
  (let ((result (empty dict)))
    (dolist (k keys result)
      (multiple-value-bind (val found)
          (if (typep dict 'fol.compiler.collections:<sorted-dict>)
              (fol.compiler.collections:collection-ref dict k)
              (ref dict k))
        (when found
              (setf result (fol.compiler.collections:collection-assoc result k val)))))))

;;; ---------------------------------------------------------------------------
;;; rename-keys - Rename keys in a dict according to a mapping
;;; ---------------------------------------------------------------------------

(defun rename-keys (dict kmap)
  "Return a new dict with keys renamed according to KMAP.
   Keys not in KMAP are kept unchanged.
   (rename-keys {:a 1 :b 2} {:a :x}) => {:x 1 :b 2}"
  (let ((result (empty dict)))
    (dolist (pair (fol.compiler.collections:collection-seq dict) result)
      (let* ((k (car pair)) (v (cdr pair))
                            (new-key (multiple-value-bind (nk found) (ref kmap k)
                                       (if found nk k))))
        (setf result (fol.compiler.collections:collection-assoc result new-key v))))))

;;; ---------------------------------------------------------------------------
;;; map-invert - Swap keys and values in a dict
;;; ---------------------------------------------------------------------------

(defun map-invert (dict)
  "Return a new dict with keys and values swapped.
   (map-invert {:a 1 :b 2}) => {1 :a 2 :b}"
  (let ((result (make-instance 'fol.compiler.collections:<dict>)))
    (dolist (pair (fol.compiler.collections:collection-seq dict) result)
      (setf result (fol.compiler.collections:collection-assoc result (cdr pair) (car pair))))))

;;; ---------------------------------------------------------------------------
;;; update-keys - Transform all keys with a function
;;; ---------------------------------------------------------------------------

(defun update-keys (dict f)
  "Return a new dict with F applied to each key, values unchanged.
   (update-keys {:a 1 :b 2} #'symbol-name) => {\"A\" 1 \"B\" 2}"
  (let ((result (empty dict)))
    (dolist (pair (fol.compiler.collections:collection-seq dict) result)
      (setf result (fol.compiler.collections:collection-assoc
                    result (funcall f (car pair)) (cdr pair))))))

;;; ---------------------------------------------------------------------------
;;; update-vals - Transform all values with a function
;;; ---------------------------------------------------------------------------

(defun update-vals (dict f)
  "Return a new dict with F applied to each value, keys unchanged.
   (update-vals {:a 1 :b 2} #'1+) => {:a 2 :b 3}"
  (let ((result dict))
    (dolist (pair (fol.compiler.collections:collection-seq dict) result)
      (let ((k (cl:car pair))
            (v (cl:cdr pair)))
        (setf result (fol.compiler.collections:collection-assoc result k (funcall f v)))))))

;;; ===========================================================================
;;; Sorted Dict Operations (rseq, subseq, rsubseq)
;;; ===========================================================================

;;; ---------------------------------------------------------------------------
;;; rseq - Reverse sequence for sorted-dict
;;; ---------------------------------------------------------------------------

(defmethod rseq ((coll fol.compiler.collections:<sorted-dict>))
  "Return the entries of the sorted-dict in reverse key order as a CL list of (key . value)."
  (cl:reverse (fol.compiler.collections:collection-seq coll)))

(defmethod rseq ((coll fol.compiler.collections:<int-dict>))
  "Return the entries of the int-dict in reverse key order."
  (cl:reverse (fol.compiler.collections:collection-seq coll)))

;;; ---------------------------------------------------------------------------
;;; subseq - Range query on sorted dicts (Clojure-style API)
;;; ---------------------------------------------------------------------------

(defmethod subseq ((sc fol.compiler.collections:<sorted-dict>) test key
                                                               &optional end-test end-key)
  "Range query on a sorted tree-map. Returns a CL list of (key . value) pairs."
  (let* ((cmp (fol.compiler.collections:comparator-compare sc))
         (entries '())
         ;; Standard comparator: -1 when a<b, 1 when a>b, 0 when a=b
         (start-pred (cond
                      ((eq test '>=) (lambda (k) (cl:>= (funcall cmp k key) 0)))
                      ((eq test '>) (lambda (k) (cl:> (funcall cmp k key) 0)))
                      ((eq test '<=) (lambda (k) (cl:<= (funcall cmp k key) 0)))
                      ((eq test '<) (lambda (k) (cl:< (funcall cmp k key) 0)))
                      (t (cl:error "subseq: invalid test ~S, must be >=, >, <=, or <" test))))
         (end-pred (when end-test
                         (cond
                          ((eq end-test '>=) (lambda (k) (cl:>= (funcall cmp k end-key) 0)))
                          ((eq end-test '>) (lambda (k) (cl:> (funcall cmp k end-key) 0)))
                          ((eq end-test '<=) (lambda (k) (cl:<= (funcall cmp k end-key) 0)))
                          ((eq end-test '<) (lambda (k) (cl:< (funcall cmp k end-key) 0)))
                          (t (cl:error "subseq: invalid end-test ~S, must be >=, >, <=, or <"
                               end-test))))))
    (let ((entries '()))
      (dolist (pair (fol.compiler.collections:collection-seq sc))
        (let ((k (cl:car pair))
              (v (cl:cdr pair)))
          (when (and (funcall start-pred k)
                     (or (null end-pred) (funcall end-pred k)))
                (cl:push (cons k v) entries))))
      (nreverse entries))))

;;; ---------------------------------------------------------------------------
;;; rsubseq - Reverse range query on sorted dicts (Clojure-style API)
;;; ---------------------------------------------------------------------------

(defmethod rsubseq ((sc fol.compiler.collections:<sorted-dict>) test key
                                                                &optional end-test end-key)
  "Reverse range query on a sorted tree-map. Returns entries in reverse key order."
  (cl:reverse (subseq sc test key end-test end-key)))

;;; ===========================================================================
;;; Deque Operations
;;; ===========================================================================

;;; ---------------------------------------------------------------------------
;;; peek - Look at front element of deque
;;; ---------------------------------------------------------------------------

(defmethod peek ((coll fol.compiler.collections:<deque>))
  "Return the front element of the deque, or NIL if empty."
  (let ((sz (fol.compiler.collections:size coll)))
    (if (cl:plusp sz)
        (ref coll 0)
        nil)))

(defmethod pop ((coll fol.compiler.collections:<deque>))
  "Return a new deque without the front element. Signals an error if empty."
  (if (cl:plusp (fol.compiler.collections:size coll))
      (fol.compiler.collections:collection-pop-front coll)
      (cl:error "Cannot pop an empty deque")))

(defmethod push ((coll fol.compiler.collections:<deque>) value)
  "Add VALUE to the back of the deque."
  (fol.compiler.collections:collection-conj coll value))

(defmethod rpeek ((coll fol.compiler.collections:<deque>))
  "Return the back element of the deque, or NIL if empty."
  (let ((sz (fol.compiler.collections:size coll)))
    (if (cl:plusp sz)
        (ref coll (1- sz))
        nil)))

(defmethod rpop ((coll fol.compiler.collections:<deque>))
  "Return a new deque without the back element. Signals an error if empty."
  (if (cl:plusp (fol.compiler.collections:size coll))
      (fol.compiler.collections:collection-pop coll)
      (cl:error "Cannot rpop an empty deque")))

(defmethod rpush ((coll fol.compiler.collections:<deque>) value)
  "Add VALUE to the front of the deque."
  (fol.compiler.collections:conj-front coll value))

(defmethod rconj ((coll fol.compiler.collections:<deque>) value)
  "Add VALUE to the front of the deque."
  (fol.compiler.collections:conj-front coll value))

;;; ============================================================================
;;; Equality for FOL Collections
;;; ============================================================================

(defmethod %= ((a fol.compiler.collections:<vector>) (b fol.compiler.collections:<vector>))
  (cl:and (cl:= (size a) (size b))
    (cl:every #'%=
      (fol.compiler.collections:collection-seq a)
      (fol.compiler.collections:collection-seq b))))

(defmethod %= ((a fol.compiler.collections:<deque>) (b fol.compiler.collections:<deque>))
  (cl:and (cl:= (size a) (size b))
    (cl:every #'%=
      (fol.compiler.collections:collection-seq a)
      (fol.compiler.collections:collection-seq b))))

(defmethod %= ((a fol.compiler.collections:<list>) (b fol.compiler.collections:<list>))
  (cl:and (cl:= (size a) (size b))
    (cl:every #'%=
      (fol.compiler.collections:collection-seq a)
      (fol.compiler.collections:collection-seq b))))

(defmethod %= ((a fol.compiler.collections:<dict-mixin>) (b fol.compiler.collections:<dict-mixin>))
  (cl:and (cl:= (size a) (size b))
    (cl:every (cl:lambda (pair)
                (cl:multiple-value-bind (val found) (get a (cl:car pair))
                  (cl:and found (%= val (cl:cdr pair)))))
      (fol.compiler.collections:collection-seq b))))

(defmethod %= ((a fol.compiler.collections:<set>) (b fol.compiler.collections:<set>))
  (cl:and (cl:= (size a) (size b))
    (cl:every (cl:lambda (x)
                (cl:multiple-value-bind (val found) (get a x)
                  (cl:declare (cl:ignore val))
                  found))
      (fol.compiler.collections:collection-seq b))))

(defmethod %= ((a fol.compiler.collections:<bag>) (b fol.compiler.collections:<bag>))
  (cl:and (cl:= (size a) (size b))
    (cl:every (cl:lambda (element)
                (cl:multiple-value-bind (count-a found-a) (get a element)
                  (cl:multiple-value-bind (count-b found-b) (get b element)
                    (cl:and found-a found-b (cl:= count-a count-b)))))
      (fol.compiler.collections:collection-seq b))))

(defmethod %= ((a <persistent-object>) (b <persistent-object>))
  "Equality for persistent objects: same class and all slots %=."
  (cl:and (eq (class-of a) (class-of b))
          (cl:let* ((class (class-of a))
                    (slots (closer-mop:class-slots class)))
            (cl:every (cl:lambda (slot)
                        (cl:let ((name (closer-mop:slot-definition-name slot)))
                          (cl:if (cl:and (slot-boundp a name) (slot-boundp b name))
                                 (%= (slot-value a name) (slot-value b name))
                                 (cl:and (cl:not (slot-boundp a name))
                                         (cl:not (slot-boundp b name))))))
                      slots))))

(defmethod %/= ((a fol.compiler.collections:<collection>) (b fol.compiler.collections:<collection>))
  (cl:not (%= a b)))

(defmethod %/= ((a <persistent-object>) (b <persistent-object>))
  (cl:not (%= a b)))

;;; ---------------------------------------------------------------------------
;;; Performance Optimization: Direct assoc without generic dispatch
;;; ---------------------------------------------------------------------------

(defun inline-assoc! (obj key val)
  "Fast assoc that bypasses :around method dispatch.
   Useful in performance-critical loops where `:around` method dispatch overhead
   is significant (e.g., 100× slowdown in tight loops).

   For persistent objects, uses the primary assoc method via direct method call,
   skipping the `:around` methods that check for changes.

   Usage:
     (loop [i 0 m (make <metric> :cpu 0 :mem 0)]
       (if (< i 1000)
         (recur (inc i)
                (-> m
                    (inline-assoc! :cpu (+ i 1))
                    (inline-assoc! :mem (+ i 2))))
         m))

   Warning: This bypasses :around methods, so any side effects or invariants
   maintained by :around methods will NOT be triggered. Use only when you know
   the :around methods are not needed for correctness.

   Performance: Approximately 5-10× faster than assoc for persistent objects in loops."
  (typecase obj
    ;; Persistent objects: use update-slot directly (primary assoc path)
    (fol.compiler.persistent:<persistent-object>
      (update-slot obj key val))
    ;; Other collection types
    (fol.compiler.collections:<dict>
      (fol.compiler.collections:collection-conj obj (cons key val)))
    (fol.compiler.collections:<vector>
      (fol.compiler.collections:collection-assoc obj key val))
    ;; Fallback
    (t (assoc obj key val))))

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; Specialized Vector Accessor (Phase 2 Optimization)
;;;; ─────────────────────────────────────────────────────────────────────────

(declaim (inline vec-nth))
(defun vec-nth (v i)
  "Specialized vector accessor bypassing generic dispatch.
   Direct access to vector element without type checking.
   ~1.5-2× faster than generic get for vector-heavy loops."
  (nth v i))

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; Typed Array Constructors
;;;; ─────────────────────────────────────────────────────────────────────────

(defun f64-array (&rest args)
  "Create a 64-bit float array.
   Usage:
     (f64-array :dimensions (2 3) 1.0 2.0 3.0 4.0 5.0 6.0)
     (f64-array :dimensions (4) :initial-element 0.0)
     (f64-array 1.0 2.0 3.0)  ; 1D array with 3 elements"
  (apply (function make) 'fol.compiler.collections:<f64-array> args))

(defun f32-array (&rest args)
  "Create a 32-bit float array.
   Usage:
     (f32-array :dimensions (2 3) 1.0 2.0 3.0 4.0 5.0 6.0)
     (f32-array :dimensions (4) :initial-element 0.0)
     (f32-array 1.0 2.0 3.0)  ; 1D array with 3 elements"
  (apply (function make) 'fol.compiler.collections:<f32-array> args))

(defun fixnum-array (&rest args)
  "Create a 64-bit fixnum array (fix64-array).
   Usage:
     (fixnum-array :dimensions (2 3) 1 2 3 4 5 6)
     (fixnum-array :dimensions (4) :initial-element 0)
     (fixnum-array 1 2 3)  ; 1D array with 3 elements"
  (apply (function make) 'fol.compiler.collections:<fix64-array> args))

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; Reads on edit-tagged transients (step 3.5)
;;;; ─────────────────────────────────────────────────────────────────────────
;;;; These make GET/NTH/COUNT/SIZE/EMPTY? work mid-session on transient
;;;; collections, matching the escape-analysis read whitelist
;;;; (+transient-readable-ops+). Keep the two in sync.

(defmethod get ((coll fol.compiler.collections:<transient-dict>) key &optional default)
  (fol.compiler.collection-primitives:hamt-get-transient
   (fol.compiler.collections:transient-dict-th coll) key default))

(defmethod get ((coll fol.compiler.collections:<transient-vector>) index &optional default)
  (fol.compiler.collection-primitives:%transient-vec-t-ref
   (fol.compiler.collections:transient-vector-tv coll) index default))

(defmethod nth ((coll fol.compiler.collections:<transient-vector>) index &optional not-found)
  (fol.compiler.collection-primitives:%transient-vec-t-ref
   (fol.compiler.collections:transient-vector-tv coll) index not-found))

(defmethod count ((coll fol.compiler.collections:<transient-dict>))
  (fol.compiler.collection-primitives:transient-hamt-count
   (fol.compiler.collections:transient-dict-th coll)))

(defmethod count ((coll fol.compiler.collections:<transient-vector>))
  (fol.compiler.collection-primitives:trans-%vec-t-count
   (fol.compiler.collections:transient-vector-tv coll)))

(defmethod fol.compiler.collection-primitives:size
    ((coll fol.compiler.collections:<transient-dict>))
  (fol.compiler.collection-primitives:transient-hamt-count
   (fol.compiler.collections:transient-dict-th coll)))

(defmethod fol.compiler.collection-primitives:size
    ((coll fol.compiler.collections:<transient-vector>))
  (fol.compiler.collection-primitives:trans-%vec-t-count
   (fol.compiler.collections:transient-vector-tv coll)))

(defmethod fol.compiler.collection-primitives:empty?
    ((coll fol.compiler.collections:<transient-dict>))
  (zerop (fol.compiler.collection-primitives:transient-hamt-count
          (fol.compiler.collections:transient-dict-th coll))))

(defmethod fol.compiler.collection-primitives:empty?
    ((coll fol.compiler.collections:<transient-vector>))
  (zerop (fol.compiler.collection-primitives:trans-%vec-t-count
          (fol.compiler.collections:transient-vector-tv coll))))
