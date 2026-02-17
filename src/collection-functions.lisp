;;; FOL Compiler - Collection Constructor Functions
;;;
;;; Runtime functions for constructing FOL collections.
;;; These are called directly by compiled FOL code:
;;;   (vector 1 2 3)     => <vector> of 1, 2, 3
;;;   (dict :a 1 :b 2)   => <dict> with :a->1, :b->2
;;;   (set 1 2 3)         => <set> of 1, 2, 3

(in-package :fol.compiler.collection-functions)

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

(defun count (collection)
  "Returns the number of elements in the collection."
  (fol.compiler.collections:collection-size collection))

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

(defmethod first ((coll fol.compiler.collections:<vector>))
  (let ((items (fol.compiler.collections:storage-items coll)))
    (when (cl:plusp (fset:size items))
      (fset:lookup items 0))))

(defmethod first ((coll fol.compiler.collections:<array>))
  (let ((items (fol.compiler.collections:storage-items coll)))
    (when (cl:plusp (cl:array-total-size items))
      (cl:row-major-aref items 0))))

(defmethod first ((coll fol.compiler.collections:<list>))
  (fol.compiler.collections:list-first coll))

(defmethod first ((coll fol.compiler.collections:<deque>))
  (let ((items (fol.compiler.collections:storage-items coll)))
    (when (cl:plusp (fset:size items))
      (fset:lookup items 0))))

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
        (apply #'fol.compiler.collections:make
               (class-of coll) (cl:rest seq))
        (make-instance (class-of coll)))))

(defmethod rest ((coll fol.compiler.collections:<vector>))
  (let ((items (fol.compiler.collections:storage-items coll)))
    (if (cl:> (fset:size items) 0)
        (make-instance 'fol.compiler.collections:<vector>
                       :items (fset:subseq items 1))
        (make-instance 'fol.compiler.collections:<vector>))))

(defmethod rest ((coll fol.compiler.collections:<list>))
  (fol.compiler.collections:list-rest coll))

;; Sets don't really support rest (unordered), so just return empty set
(defmethod rest ((coll fol.compiler.collections:<set>))
  (make-instance 'fol.compiler.collections:<set>
                 :items (sycamore:make-hash-set)))

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
  "Look up INDEX in the FSet seq backing the vector."
  (let ((items (fol.compiler.collections:storage-items coll)))
    (if (and (integerp index) (cl:>= index 0) (cl:< index (fset:size items)))
        (fset:lookup items index)
        (if not-found-p
            not-found
            (cl:error "Index ~D out of bounds for vector of size ~D"
                      index (fset:size items))))))

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
  (let ((items (fol.compiler.collections:storage-items coll)))
    (when (cl:plusp (fset:size items))
      (fset:lookup items (1- (fset:size items))))))

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
  (let ((items (fol.compiler.collections:storage-items coll)))
    (if (cl:plusp (fset:size items))
        (make-instance 'fol.compiler.collections:<vector>
                       :items (fset:less-last items))
        (cl:error "Cannot pop an empty vector"))))

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
  (let ((items (fol.compiler.collections:storage-items coll))
        (start (or from-index 0)))
    (cl:loop for i from start below (fset:size items)
             when (eql (fset:lookup items i) value)
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
  (let ((items (fol.compiler.collections:storage-items coll)))
    (cl:loop with last-idx = nil
             for i from 0 below (fset:size items)
             when (eql (fset:lookup items i) value)
               do (setf last-idx i)
             finally (return last-idx))))

;;; ---------------------------------------------------------------------------
;;; get - Get value by key (dict) or index (seq)
;;; ---------------------------------------------------------------------------

(defgeneric get (collection key &optional default)
  (:documentation "Get value by key (dict) or index (seq). Returns default if not found."))

(defmethod get ((coll fol.compiler.collections:<dict>) key &optional default)
  (multiple-value-bind (value found)
      (sycamore:hash-map-find (fol.compiler.collections:storage-items coll) key)
    (if found value default)))

(defmethod get ((coll fol.compiler.collections:<ordered-dict>) key &optional default)
  (multiple-value-bind (value found)
      (sycamore:hash-map-find (fol.compiler.collections:storage-items coll) key)
    (if found value default)))

(defmethod get ((coll fol.compiler.collections:<sorted-dict>) key &optional default)
  (multiple-value-bind (value found)
      (sycamore:tree-map-find (fol.compiler.collections:storage-items coll) key)
    (if found value default)))

(defmethod get ((coll fol.compiler.collections:<int-dict>) key &optional default)
  (multiple-value-bind (value found)
      (sycamore:tree-map-find (fol.compiler.collections:storage-items coll) key)
    (if found value default)))

(defmethod get ((coll fol.compiler.collections:<priority-dict>) key &optional default)
  (multiple-value-bind (value found)
      (sycamore:hash-map-find (fol.compiler.collections:storage-items coll) key)
    (if found value default)))

(defmethod get ((coll fol.compiler.collections:<vector>) index &optional default)
  (let ((items (fol.compiler.collections:storage-items coll)))
    (if (and (cl:integerp index) (cl:>= index 0) (cl:< index (fset:size items)))
        (fset:lookup items index)
        default)))

(defmethod get ((coll fol.compiler.collections:<array>) index &optional default)
  (let ((items (fol.compiler.collections:storage-items coll)))
    (if (and (cl:integerp index) (cl:>= index 0) (cl:< index (cl:array-total-size items)))
        (cl:row-major-aref items index)
        default)))

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
  (if (sycamore:hash-set-find (fol.compiler.collections:storage-items coll) element)
      element
      default))

(defmethod get ((coll fol.compiler.collections:<sorted-set>) element &optional default)
  (if (sycamore:tree-set-find (fol.compiler.collections:storage-items coll) element)
      element
      default))

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

(defmethod assoc ((coll fol.compiler.collections:<vector>) index value &rest ivs)
  (let* ((items (fol.compiler.collections:storage-items coll))
         (new-items (fset:with items index value)))
    (let ((new-coll (make-instance 'fol.compiler.collections:<vector>
                                   :items new-items)))
      (if ivs
          (apply #'assoc new-coll ivs)
          new-coll))))

;;; ---------------------------------------------------------------------------
;;; dissoc - Returns new collection with specified keys removed
;;; ---------------------------------------------------------------------------

(defgeneric dissoc (collection &rest keys)
  (:documentation "Returns new collection with specified keys removed. Dict types only."))

(defmethod dissoc ((coll fol.compiler.collections:<dict>) &rest keys)
  (let ((items (fol.compiler.collections:storage-items coll)))
    (make-instance 'fol.compiler.collections:<dict>
                   :items (reduce #'sycamore:hash-map-remove keys
                                          :initial-value items))))

(defmethod dissoc ((coll fol.compiler.collections:<ordered-dict>) &rest keys)
  (let* ((items (fol.compiler.collections:storage-items coll))
         (key-order (fol.compiler.collections:ordered-dict-key-order coll))
         (new-items (reduce #'sycamore:hash-map-remove keys :initial-value items))
         (key-set (loop with hset = (sycamore:make-hash-set)
                        for k in keys
                        do (setf hset (sycamore:hash-set-insert hset k))
                        finally (return hset)))
         (new-order (fset:filter (lambda (k) (not (sycamore:hash-set-find key-set k)))
                                 key-order)))
    (make-instance 'fol.compiler.collections:<ordered-dict>
                   :items new-items
                   :key-order new-order)))

(defmethod dissoc ((coll fol.compiler.collections:<sorted-dict>) &rest keys)
  (let ((items (fol.compiler.collections:storage-items coll)))
    (make-instance 'fol.compiler.collections:<sorted-dict>
                   :items (reduce #'sycamore:tree-map-remove keys
                                          :initial-value items)
                   :compare (fol.compiler.collections:comparator-compare coll))))


;;; ---------------------------------------------------------------------------
;;; UPDATE - Functional update via function
;;; ---------------------------------------------------------------------------

(defgeneric update (collection key updater-fn)
  (:documentation "Update a key by applying updater-fn to its current value (returns new collection)."))

(defmethod update ((coll fol.compiler.collections:<dict>) key updater-fn)
  (let* ((items (fol.compiler.collections:storage-items coll))
         (current-val (sycamore:hash-map-find items key))
         (new-val (funcall updater-fn current-val)))
    (make-instance 'fol.compiler.collections:<dict>
                   :items (sycamore:hash-map-insert items key new-val))))

(defmethod update ((coll fol.compiler.collections:<ordered-dict>) key updater-fn)
  (let* ((items (fol.compiler.collections:storage-items coll))
         (key-order (fol.compiler.collections:ordered-dict-key-order coll))
         (current-val (sycamore:hash-map-find items key))
         (new-val (funcall updater-fn current-val))
         (new-items (sycamore:hash-map-insert items key new-val))
         ;; Add key to order if it's new
         (new-order (if (sycamore:hash-map-find items key)
                        key-order
                        (fset:with-last key-order key))))
    (make-instance 'fol.compiler.collections:<ordered-dict>
                   :items new-items
                   :key-order new-order)))

(defmethod update ((coll fol.compiler.collections:<sorted-dict>) key updater-fn)
  (let* ((items (fol.compiler.collections:storage-items coll))
         (current-val (sycamore:tree-map-find items key))
         (new-val (funcall updater-fn current-val)))
    (make-instance 'fol.compiler.collections:<sorted-dict>
                   :items (sycamore:tree-map-insert items key new-val)
                   :compare (fol.compiler.collections:comparator-compare coll))))

(defmethod update ((coll fol.compiler.collections:<vector>) index updater-fn)
  "Apply UPDATER-FN to the element at INDEX, returning a new vector.
   Signals an error if INDEX is out of bounds."
  (let ((items (fol.compiler.collections:storage-items coll)))
    (unless (and (integerp index) (cl:>= index 0) (cl:< index (fset:size items)))
      (cl:error "Index ~D out of bounds for vector of size ~D" index (fset:size items)))
    (let ((new-val (funcall updater-fn (fset:lookup items index))))
      (make-instance 'fol.compiler.collections:<vector>
                     :items (fset:with items index new-val)))))

;;; ---------------------------------------------------------------------------
;;; MERGE - Merge dict collections
;;; ---------------------------------------------------------------------------

(defgeneric merge (coll &rest colls)
  (:documentation "Merge collections (later values win on key conflicts)."))

(defmethod merge ((coll fol.compiler.collections:<dict>) &rest colls)
  (if (null colls)
      coll
      (let ((result-items (fol.compiler.collections:storage-items coll)))
        (dolist (other colls)
          (sycamore:do-hash-map ((k v) (fol.compiler.collections:storage-items other))
            (setf result-items (sycamore:hash-map-insert result-items k v))))
        (make-instance 'fol.compiler.collections:<dict>
                       :items result-items))))

(defmethod merge ((coll fol.compiler.collections:<ordered-dict>) &rest colls)
  (if (null colls)
      coll
      (let ((result-items (fol.compiler.collections:storage-items coll))
            (result-order (fol.compiler.collections:ordered-dict-key-order coll)))
        (dolist (other colls)
          (sycamore:do-hash-map ((k v) (fol.compiler.collections:storage-items other))
            (setf result-items (sycamore:hash-map-insert result-items k v))
            ;; Add to order if new key
            (unless (sycamore:hash-map-find result-items k)
              (setf result-order (fset:with-last result-order k)))))
        (make-instance 'fol.compiler.collections:<ordered-dict>
                       :items result-items
                       :key-order result-order))))

(defmethod merge ((coll fol.compiler.collections:<sorted-dict>) &rest colls)
  (if (null colls)
      coll
      (let ((result-items (fol.compiler.collections:storage-items coll)))
        (dolist (other colls)
          (sycamore:do-tree-map ((k v) (fol.compiler.collections:storage-items other))
            (setf result-items (sycamore:tree-map-insert result-items k v))))
        (make-instance 'fol.compiler.collections:<sorted-dict>
                       :items result-items
                       :compare (fol.compiler.collections:comparator-compare coll)))))

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
  (let ((cmp (slot-value coll 'fol.compiler.collections::compare)))
    (make-instance 'fol.compiler.collections:<sorted-dict>
                   :items (sycamore:make-tree-map cmp)
                   :compare cmp)))

(defmethod empty ((coll fol.compiler.collections:<int-dict>))
  "Preserve comparator when creating empty int-dict."
  (make-instance 'fol.compiler.collections:<int-dict>
                 :items (sycamore:make-tree-map #'fol.compiler.collections::%int-compare)
                 :compare #'fol.compiler.collections::%int-compare))

(defmethod empty ((coll fol.compiler.collections:<sorted-set>))
  "Preserve comparator when creating empty sorted-set."
  (let ((cmp (slot-value coll 'fol.compiler.collections::compare)))
    (make-instance 'fol.compiler.collections:<sorted-set>
                   :items (sycamore:make-tree-set cmp)
                   :compare cmp)))

(defmethod empty ((coll fol.compiler.collections:<int-set>))
  "Preserve comparator when creating empty int-set."
  (make-instance 'fol.compiler.collections:<int-set>
                 :items (sycamore:make-tree-set #'fol.compiler.collections::%int-compare)
                 :compare #'fol.compiler.collections::%int-compare))

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
        (nidx  (cl:length indices)))
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

;;; --- Vector: build FSet seq directly, avoiding intermediate instances ---

(defmethod into ((to <vector>) (from fol.compiler.collections:<collection>))
  (let ((items (fol.compiler.collections:storage-items to)))
    (dolist (elem (fol.compiler.collections:collection-seq from))
      (setf items (fset:with-last items elem)))
    (make-instance '<vector> :items items)))

;;; --- Deque: build FSet seq directly, produce deque instance ---

(defmethod into ((to <deque>) (from fol.compiler.collections:<collection>))
  (let ((items (fol.compiler.collections:storage-items to)))
    (dolist (elem (fol.compiler.collections:collection-seq from))
      (setf items (fset:with-last items elem)))
    (make-instance '<deque> :items items)))

;;; --- Array: build CL array directly ---

(defmethod into ((to <array>) (from fol.compiler.collections:<collection>))
  (let* ((old (fol.compiler.collections:storage-items to))
         (old-len (cl:length old))
         (new-elems (fol.compiler.collections:collection-seq from))
         (new-len (cl:length new-elems))
         (total (cl:+ old-len new-len))
         (result (cl:make-array total)))
    (dotimes (i old-len)
      (setf (cl:aref result i) (cl:aref old i)))
    (cl:loop for elem in new-elems
             for i from old-len
             do (setf (cl:aref result i) elem))
    (make-instance '<array> :items result
                   :dimension (cl:list total))))

;;; --- Dict: build hash-map directly ---

(defmethod into ((to <dict>) (from fol.compiler.collections:<collection>))
  (let ((items (fol.compiler.collections:storage-items to)))
    (dolist (pair (fol.compiler.collections:collection-seq from))
      (setf items (sycamore:hash-map-insert items (car pair) (cdr pair))))
    (make-instance '<dict> :items items)))

;;; --- Ordered-dict: maintain hash-map and key-order ---

(defmethod into ((to <ordered-dict>) (from fol.compiler.collections:<collection>))
  (let ((items (fol.compiler.collections:storage-items to))
        (key-order (fol.compiler.collections:ordered-dict-key-order to))
        (seen (make-hash-table :test 'eql)))
    (fset:do-seq (k key-order)
      (setf (gethash k seen) t))
    (dolist (pair (fol.compiler.collections:collection-seq from))
      (let ((k (car pair)) (v (cdr pair)))
        (unless (gethash k seen)
          (setf key-order (fset:with-last key-order k))
          (setf (gethash k seen) t))
        (setf items (sycamore:hash-map-insert items k v))))
    (make-instance '<ordered-dict> :items items :key-order key-order)))

;;; --- Array-dict: maintain hash-map and key-order ---

(defmethod into ((to <array-dict>) (from fol.compiler.collections:<collection>))
  (let ((items (fol.compiler.collections:storage-items to))
        (key-order (fol.compiler.collections:array-dict-key-order to))
        (seen (make-hash-table :test 'eql)))
    (fset:do-seq (k key-order)
      (setf (gethash k seen) t))
    (dolist (pair (fol.compiler.collections:collection-seq from))
      (let ((k (car pair)) (v (cdr pair)))
        (unless (gethash k seen)
          (setf key-order (fset:with-last key-order k))
          (setf (gethash k seen) t))
        (setf items (sycamore:hash-map-insert items k v))))
    (make-instance '<array-dict> :items items :key-order key-order)))

;;; --- Sorted-dict: build tree-map directly (also handles <int-dict>) ---

(defmethod into ((to <sorted-dict>) (from fol.compiler.collections:<collection>))
  (let ((items (fol.compiler.collections:storage-items to)))
    (dolist (pair (fol.compiler.collections:collection-seq from))
      (setf items (sycamore:tree-map-insert items (car pair) (cdr pair))))
    (make-instance (class-of to)
                   :compare (fol.compiler.collections:comparator-compare to)
                   :items items)))

;;; --- Priority-dict: maintain hash-map and priority tree ---

(defmethod into ((to <priority-dict>) (from fol.compiler.collections:<collection>))
  (let ((hm (fol.compiler.collections:storage-items to))
        (tm (fol.compiler.collections:priority-dict-tree to)))
    (dolist (pair (fol.compiler.collections:collection-seq from))
      (let* ((key (car pair))
             (new-pri (cdr pair))
             (old-pri (sycamore:hash-map-find hm key)))
        (when old-pri
          (setf tm (sycamore:tree-map-remove tm (cons old-pri key))))
        (setf hm (sycamore:hash-map-insert hm key new-pri))
        (setf tm (sycamore:tree-map-insert tm (cons new-pri key) key))))
    (make-instance '<priority-dict>
                   :items hm
                   :priority-tree tm
                   :priority-compare (fol.compiler.collections:priority-dict-compare to))))

;;; --- Set: build hash-set directly ---

(defmethod into ((to <set>) (from fol.compiler.collections:<collection>))
  (let ((items (fol.compiler.collections:storage-items to)))
    (dolist (elem (fol.compiler.collections:collection-seq from))
      (setf items (sycamore:hash-set-insert items elem)))
    (make-instance '<set> :items items)))

;;; --- Ordered-set: maintain hash-set and insertion-order seq ---

(defmethod into ((to <ordered-set>) (from fol.compiler.collections:<collection>))
  (let* ((store (fol.compiler.collections:storage-items to))
         (hset (car store))
         (seq (cdr store)))
    (dolist (elem (fol.compiler.collections:collection-seq from))
      (unless (sycamore:hash-set-find hset elem)
        (setf hset (sycamore:hash-set-insert hset elem))
        (setf seq (fset:with-last seq elem))))
    (make-instance '<ordered-set> :items (cons hset seq))))

;;; --- Sorted-set: build tree-set directly (also handles <int-set>) ---

(defmethod into ((to <sorted-set>) (from fol.compiler.collections:<collection>))
  (let ((items (fol.compiler.collections:storage-items to)))
    (dolist (elem (fol.compiler.collections:collection-seq from))
      (setf items (sycamore:tree-set-insert items elem)))
    (make-instance (class-of to)
                   :compare (fol.compiler.collections:comparator-compare to)
                   :items items)))

;;; --- Bag: build count-map directly ---

(defmethod into ((to <bag>) (from fol.compiler.collections:<collection>))
  (let ((items (fol.compiler.collections:storage-items to)))
    (dolist (elem (fol.compiler.collections:collection-seq from))
      (let ((cnt (or (sycamore:hash-map-find items elem) 0)))
        (setf items (sycamore:hash-map-insert items elem (1+ cnt)))))
    (make-instance '<bag> :items items)))

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
  (let ((items (fol.compiler.collections:storage-items coll)))
    (when (cl:plusp (fset:size items))
      (cl:loop for i from (1- (fset:size items)) downto 0
               collect (fset:lookup items i)))))

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
  (let ((items (fol.compiler.collections:storage-items coll))
        (acc init))
    (cl:loop for i from 0 below (fset:size items)
             do (setf acc (funcall fn acc i (fset:lookup items i))))
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
  (let* ((items (fol.compiler.collections:storage-items v))
         (sz (fset:size items))
         (actual-end (or end sz)))
    (unless (and (integerp start) (cl:>= start 0) (cl:<= start sz))
      (cl:error "subvec: start ~D out of bounds for vector of size ~D" start sz))
    (unless (and (integerp actual-end) (cl:>= actual-end start) (cl:<= actual-end sz))
      (cl:error "subvec: end ~D out of bounds for vector of size ~D" actual-end sz))
    (if (cl:= start actual-end)
        (vector)
        (make-instance 'fol.compiler.collections:<vector>
                       :items (fset:subseq items start actual-end)))))

;;; ---------------------------------------------------------------------------
;;; replace - Replace elements in a vector according to a map
;;; ---------------------------------------------------------------------------

(defun replace (smap coll)
  "Given a map SMAP and a vector COLL, return a new vector with any elements
   that are keys in SMAP replaced by the corresponding values.

   Examples:
     (replace {2 :two 4 :four} [4 2 3 4 5])
       => [:four :two 3 :four 5]"
  (let* ((items (fol.compiler.collections:storage-items coll))
         (sz (fset:size items))
         (result items))
    (cl:loop for i from 0 below sz
             do (let ((elem (fset:lookup items i)))
                  (multiple-value-bind (replacement found)
                      (sycamore:hash-map-find
                       (fol.compiler.collections:storage-items smap) elem)
                    (when found
                      (setf result (fset:with result i replacement))))))
    (make-instance 'fol.compiler.collections:<vector> :items result)))

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
  "Test membership in a hash-set."
  (if (sycamore:hash-set-find (fol.compiler.collections:storage-items s) element)
      t nil))

(defmethod contains? ((s fol.compiler.collections:<ordered-set>) element)
  "Test membership in an ordered-set (uses the hash-set component)."
  (if (sycamore:hash-set-find
       (car (fol.compiler.collections:storage-items s)) element)
      t nil))

(defmethod contains? ((s fol.compiler.collections:<sorted-set>) element)
  "Test membership in a sorted tree-set."
  (if (sycamore:tree-set-member-p (fol.compiler.collections:storage-items s) element)
      t nil))

;;; ---------------------------------------------------------------------------
;;; disj - Remove elements from a set
;;; ---------------------------------------------------------------------------

(defgeneric disj (set &rest elements)
  (:documentation "Returns a new set with ELEMENTS removed.
   (disj #{1 2 3} 2) => #{1 3}
   (disj #{1 2 3} 2 3) => #{1}"))

(defmethod disj ((s fol.compiler.collections:<set>) &rest elements)
  "Remove ELEMENTS from a hash-set."
  (let ((items (fol.compiler.collections:storage-items s)))
    (dolist (elem elements)
      (setf items (sycamore:hash-set-remove items elem)))
    (make-instance 'fol.compiler.collections:<set> :items items)))

(defmethod disj ((s fol.compiler.collections:<ordered-set>) &rest elements)
  "Remove ELEMENTS from an ordered-set."
  (let* ((store (fol.compiler.collections:storage-items s))
         (hset (car store))
         (seq (cdr store)))
    (dolist (elem elements)
      (setf hset (sycamore:hash-set-remove hset elem)))
    (let ((new-seq (fset:filter (lambda (e) (sycamore:hash-set-find hset e)) seq)))
      (make-instance 'fol.compiler.collections:<ordered-set>
                     :items (cons hset new-seq)))))

(defmethod disj ((s fol.compiler.collections:<sorted-set>) &rest elements)
  "Remove ELEMENTS from a sorted tree-set."
  (let ((items (fol.compiler.collections:storage-items s)))
    (dolist (elem elements)
      (setf items (sycamore:tree-set-remove items elem)))
    (make-instance 'fol.compiler.collections:<sorted-set>
                   :items items
                   :compare (fol.compiler.collections:comparator-compare s))))

(defmethod disj ((s fol.compiler.collections:<int-set>) &rest elements)
  "Remove ELEMENTS from an int-set."
  (let ((items (fol.compiler.collections:storage-items s)))
    (dolist (elem elements)
      (setf items (sycamore:tree-set-remove items elem)))
    (make-instance 'fol.compiler.collections:<int-set>
                   :items items
                   :compare #'fol.compiler.collections::%int-compare)))

;;; ---------------------------------------------------------------------------
;;; union - Set union
;;; ---------------------------------------------------------------------------

(defgeneric union (set1 set2)
  (:documentation "Returns a new set that is the union of SET1 and SET2.
   (union #{1 2} #{2 3}) => #{1 2 3}"))

(defmethod union ((s1 fol.compiler.collections:<set>)
                  (s2 fol.compiler.collections:<set>))
  "Union of two hash-sets."
  (make-instance 'fol.compiler.collections:<set>
                 :items (sycamore:hash-set-union
                         (fol.compiler.collections:storage-items s1)
                         (fol.compiler.collections:storage-items s2))))

(defmethod union ((s1 fol.compiler.collections:<ordered-set>)
                  (s2 fol.compiler.collections:<ordered-set>))
  "Union of two ordered-sets. Elements from s1 come first, then novel elements from s2."
  (let* ((store1 (fol.compiler.collections:storage-items s1))
         (store2 (fol.compiler.collections:storage-items s2))
         (hset1 (car store1))
         (seq1 (cdr store1))
         (hset-result (sycamore:hash-set-union hset1 (car store2)))
         (seq-result seq1))
    ;; Append novel elements from s2 in their insertion order
    (fset:do-seq (elem (cdr store2))
      (unless (sycamore:hash-set-find hset1 elem)
        (setf seq-result (fset:with-last seq-result elem))))
    (make-instance 'fol.compiler.collections:<ordered-set>
                   :items (cons hset-result seq-result))))

(defmethod union ((s1 fol.compiler.collections:<sorted-set>)
                  (s2 fol.compiler.collections:<sorted-set>))
  "Union of two sorted tree-sets."
  (make-instance 'fol.compiler.collections:<sorted-set>
                 :items (sycamore:tree-set-union
                         (fol.compiler.collections:storage-items s1)
                         (fol.compiler.collections:storage-items s2))
                 :compare (fol.compiler.collections:comparator-compare s1)))

(defmethod union ((s1 fol.compiler.collections:<int-set>)
                  (s2 fol.compiler.collections:<int-set>))
  "Union of two int-sets."
  (make-instance 'fol.compiler.collections:<int-set>
                 :items (sycamore:tree-set-union
                         (fol.compiler.collections:storage-items s1)
                         (fol.compiler.collections:storage-items s2))
                 :compare #'fol.compiler.collections::%int-compare))

;;; ---------------------------------------------------------------------------
;;; difference - Set difference
;;; ---------------------------------------------------------------------------

(defgeneric difference (set1 set2)
  (:documentation "Returns a new set containing elements in SET1 but not in SET2.
   (difference #{1 2 3} #{2 3 4}) => #{1}"))

(defmethod difference ((s1 fol.compiler.collections:<set>)
                       (s2 fol.compiler.collections:<set>))
  "Difference of two hash-sets."
  (make-instance 'fol.compiler.collections:<set>
                 :items (sycamore:hash-set-difference
                         (fol.compiler.collections:storage-items s1)
                         (fol.compiler.collections:storage-items s2))))

(defmethod difference ((s1 fol.compiler.collections:<ordered-set>)
                       (s2 fol.compiler.collections:<ordered-set>))
  "Difference of two ordered-sets. Preserves insertion order from s1."
  (let* ((store1 (fol.compiler.collections:storage-items s1))
         (store2 (fol.compiler.collections:storage-items s2))
         (hset-result (sycamore:hash-set-difference (car store1) (car store2)))
         (seq-result (fset:filter
                      (lambda (e) (sycamore:hash-set-find hset-result e))
                      (cdr store1))))
    (make-instance 'fol.compiler.collections:<ordered-set>
                   :items (cons hset-result seq-result))))

(defmethod difference ((s1 fol.compiler.collections:<sorted-set>)
                       (s2 fol.compiler.collections:<sorted-set>))
  "Difference of two sorted tree-sets."
  (make-instance 'fol.compiler.collections:<sorted-set>
                 :items (sycamore:tree-set-difference
                         (fol.compiler.collections:storage-items s1)
                         (fol.compiler.collections:storage-items s2))
                 :compare (fol.compiler.collections:comparator-compare s1)))

(defmethod difference ((s1 fol.compiler.collections:<int-set>)
                       (s2 fol.compiler.collections:<int-set>))
  "Difference of two int-sets."
  (make-instance 'fol.compiler.collections:<int-set>
                 :items (sycamore:tree-set-difference
                         (fol.compiler.collections:storage-items s1)
                         (fol.compiler.collections:storage-items s2))
                 :compare #'fol.compiler.collections::%int-compare))

;;; ---------------------------------------------------------------------------
;;; intersection - Set intersection
;;; ---------------------------------------------------------------------------

(defgeneric intersection (set1 set2)
  (:documentation "Returns a new set containing elements common to SET1 and SET2.
   (intersection #{1 2 3} #{2 3 4}) => #{2 3}"))

(defmethod intersection ((s1 fol.compiler.collections:<set>)
                         (s2 fol.compiler.collections:<set>))
  "Intersection of two hash-sets."
  (make-instance 'fol.compiler.collections:<set>
                 :items (sycamore:hash-set-intersection
                         (fol.compiler.collections:storage-items s1)
                         (fol.compiler.collections:storage-items s2))))

(defmethod intersection ((s1 fol.compiler.collections:<ordered-set>)
                         (s2 fol.compiler.collections:<ordered-set>))
  "Intersection of two ordered-sets. Preserves insertion order from s1."
  (let* ((store1 (fol.compiler.collections:storage-items s1))
         (store2 (fol.compiler.collections:storage-items s2))
         (hset-result (sycamore:hash-set-intersection (car store1) (car store2)))
         (seq-result (fset:filter
                      (lambda (e) (sycamore:hash-set-find hset-result e))
                      (cdr store1))))
    (make-instance 'fol.compiler.collections:<ordered-set>
                   :items (cons hset-result seq-result))))

(defmethod intersection ((s1 fol.compiler.collections:<sorted-set>)
                         (s2 fol.compiler.collections:<sorted-set>))
  "Intersection of two sorted tree-sets."
  (make-instance 'fol.compiler.collections:<sorted-set>
                 :items (sycamore:tree-set-intersection
                         (fol.compiler.collections:storage-items s1)
                         (fol.compiler.collections:storage-items s2))
                 :compare (fol.compiler.collections:comparator-compare s1)))

(defmethod intersection ((s1 fol.compiler.collections:<int-set>)
                         (s2 fol.compiler.collections:<int-set>))
  "Intersection of two int-sets."
  (make-instance 'fol.compiler.collections:<int-set>
                 :items (sycamore:tree-set-intersection
                         (fol.compiler.collections:storage-items s1)
                         (fol.compiler.collections:storage-items s2))
                 :compare #'fol.compiler.collections::%int-compare))

;;; ---------------------------------------------------------------------------
;;; select - Filter a set by predicate
;;; ---------------------------------------------------------------------------

(defgeneric select (pred set)
  (:documentation "Returns a new set containing only elements of SET for which PRED returns true.
   (select #'evenp #{1 2 3 4}) => #{2 4}"))

(defmethod select (pred (s fol.compiler.collections:<set>))
  "Filter a hash-set by predicate."
  (let ((items (sycamore:make-hash-set)))
    (dolist (elem (sycamore:hash-set-list (fol.compiler.collections:storage-items s)))
      (when (funcall pred elem)
        (setf items (sycamore:hash-set-insert items elem))))
    (make-instance 'fol.compiler.collections:<set> :items items)))

(defmethod select (pred (s fol.compiler.collections:<ordered-set>))
  "Filter an ordered-set by predicate, preserving insertion order."
  (let ((hset (sycamore:make-hash-set))
        (seq (fset:empty-seq)))
    (fset:do-seq (elem (cdr (fol.compiler.collections:storage-items s)))
      (when (funcall pred elem)
        (setf hset (sycamore:hash-set-insert hset elem))
        (setf seq (fset:with-last seq elem))))
    (make-instance 'fol.compiler.collections:<ordered-set>
                   :items (cons hset seq))))

(defmethod select (pred (s fol.compiler.collections:<sorted-set>))
  "Filter a sorted-set by predicate, preserving comparator."
  (let* ((cmp (fol.compiler.collections:comparator-compare s))
         (items (sycamore:make-tree-set cmp)))
    (dolist (elem (sycamore:tree-set-list (fol.compiler.collections:storage-items s)))
      (when (funcall pred elem)
        (setf items (sycamore:tree-set-insert items elem))))
    (make-instance 'fol.compiler.collections:<sorted-set>
                   :items items :compare cmp)))

(defmethod select (pred (s fol.compiler.collections:<int-set>))
  "Filter an int-set by predicate."
  (let ((items (sycamore:make-tree-set #'fol.compiler.collections::%int-compare)))
    (dolist (elem (sycamore:tree-set-list (fol.compiler.collections:storage-items s)))
      (when (funcall pred elem)
        (setf items (sycamore:tree-set-insert items elem))))
    (make-instance 'fol.compiler.collections:<int-set>
                   :items items
                   :compare #'fol.compiler.collections::%int-compare)))

;;; ---------------------------------------------------------------------------
;;; subset? - Test if one set is a subset of another
;;; ---------------------------------------------------------------------------

(defgeneric subset? (set1 set2)
  (:documentation "Returns T if every element of SET1 is also in SET2.
   (subset? #{1 2} #{1 2 3}) => T
   (subset? #{1 4} #{1 2 3}) => NIL"))

(defmethod subset? ((s1 fol.compiler.collections:<set>)
                    (s2 fol.compiler.collections:<set>))
  "Test if s1 is a subset of s2 (hash-sets)."
  (if (sycamore:hash-set-subset-p
       (fol.compiler.collections:storage-items s1)
       (fol.compiler.collections:storage-items s2))
      t nil))

(defmethod subset? ((s1 fol.compiler.collections:<ordered-set>)
                    (s2 fol.compiler.collections:<ordered-set>))
  "Test if s1 is a subset of s2 (ordered-sets, delegate to hash-sets)."
  (if (sycamore:hash-set-subset-p
       (car (fol.compiler.collections:storage-items s1))
       (car (fol.compiler.collections:storage-items s2)))
      t nil))

(defmethod subset? ((s1 fol.compiler.collections:<sorted-set>)
                    (s2 fol.compiler.collections:<sorted-set>))
  "Test if s1 is a subset of s2 (sorted tree-sets)."
  (if (sycamore:tree-set-subset-p
       (fol.compiler.collections:storage-items s1)
       (fol.compiler.collections:storage-items s2))
      t nil))

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
  (let ((items (fol.compiler.collections:storage-items coll)))
    (when (cl:plusp (sycamore:tree-set-count items))
      (cl:reverse (sycamore:tree-set-list items)))))

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
         (elements (sycamore:tree-set-list (fol.compiler.collections:storage-items sc)))
         (start-pred (cond
                       ((eq test '>=) (lambda (e) (cl:>= (funcall cmp e key) 0)))
                       ((eq test '>)  (lambda (e) (cl:> (funcall cmp e key) 0)))
                       ((eq test '<=) (lambda (e) (cl:<= (funcall cmp e key) 0)))
                       ((eq test '<)  (lambda (e) (cl:< (funcall cmp e key) 0)))
                       (t (cl:error "subseq: invalid test ~S, must be >=, >, <=, or <" test))))
         (end-pred (when end-test
                     (cond
                       ((eq end-test '>=) (lambda (e) (cl:>= (funcall cmp e end-key) 0)))
                       ((eq end-test '>)  (lambda (e) (cl:> (funcall cmp e end-key) 0)))
                       ((eq end-test '<=) (lambda (e) (cl:<= (funcall cmp e end-key) 0)))
                       ((eq end-test '<)  (lambda (e) (cl:< (funcall cmp e end-key) 0)))
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

;;; ===========================================================================
;;; Dict Operations
;;; ===========================================================================

;;; ---------------------------------------------------------------------------
;;; contains? for dicts - Test if a key exists
;;; ---------------------------------------------------------------------------

(defmethod contains? ((d fol.compiler.collections:<dict>) key)
  "Returns T if dict D contains KEY."
  (multiple-value-bind (val found)
      (sycamore:hash-map-find (fol.compiler.collections:storage-items d) key)
    (declare (ignore val))
    (if found t nil)))

(defmethod contains? ((d fol.compiler.collections:<sorted-dict>) key)
  "Returns T if sorted-dict D contains KEY."
  (multiple-value-bind (val found-key found-p)
      (sycamore:tree-map-find (fol.compiler.collections:storage-items d) key)
    (declare (ignore val found-key))
    (if found-p t nil)))

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
      (sycamore:hash-map-find (fol.compiler.collections:storage-items d) key)
    (if found (cons key val) nil)))

(defmethod find ((d fol.compiler.collections:<sorted-dict>) key)
  "Look up KEY in sorted-dict, returning (key . value) or NIL."
  (multiple-value-bind (val found-key found-p)
      (sycamore:tree-map-find (fol.compiler.collections:storage-items d) key)
    (declare (ignore found-key))
    (if found-p (cons key val) nil)))

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
         (let ((items (fol.compiler.collections:storage-items current)))
           (if (and (integerp k) (cl:>= k 0) (cl:< k (fset:size items)))
               (setf current (fset:lookup items k))
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
  (let ((result '()))
    (typecase dict
      (fol.compiler.collections:<ordered-dict>
       (let ((key-order (fol.compiler.collections:ordered-dict-key-order dict))
             (items (fol.compiler.collections:storage-items dict))
             (vals-result '()))
         (fset:do-seq (k key-order)
           (cl:push (sycamore:hash-map-find items k) vals-result))
         (return-from vals
           (apply #'fol.compiler.collections:make
                  'fol.compiler.collections:<vector>
                  (nreverse vals-result)))))
      (fol.compiler.collections:<sorted-dict>
       (sycamore:do-tree-map ((k v) (fol.compiler.collections:storage-items dict))
         (declare (ignore k))
         (cl:push v result)))
      (fol.compiler.collections:<priority-dict>
       (sycamore:do-hash-map ((k v) (fol.compiler.collections:storage-items dict))
         (declare (ignore k))
         (cl:push v result)))
      (fol.compiler.collections:<dict>
       (sycamore:do-hash-map ((k v) (fol.compiler.collections:storage-items dict))
         (declare (ignore k))
         (cl:push v result)))
      (t
       (cl:error "vals requires a dict, got ~S" dict)))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector>
           (nreverse result))))

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
  (let ((result-items (fol.compiler.collections:storage-items coll)))
    (dolist (other colls)
      (sycamore:do-hash-map ((k v) (fol.compiler.collections:storage-items other))
        (multiple-value-bind (existing found)
            (sycamore:hash-map-find result-items k)
          (setf result-items
                (sycamore:hash-map-insert result-items k
                                          (if found (funcall f existing v) v))))))
    (make-instance 'fol.compiler.collections:<dict>
                   :items result-items)))

(defmethod merge-with (f (coll fol.compiler.collections:<ordered-dict>) &rest colls)
  (let ((result-items (fol.compiler.collections:storage-items coll))
        (result-order (fol.compiler.collections:ordered-dict-key-order coll)))
    (dolist (other colls)
      (sycamore:do-hash-map ((k v) (fol.compiler.collections:storage-items other))
        (multiple-value-bind (existing found)
            (sycamore:hash-map-find result-items k)
          (unless found
            (setf result-order (fset:with-last result-order k)))
          (setf result-items
                (sycamore:hash-map-insert result-items k
                                          (if found (funcall f existing v) v))))))
    (make-instance 'fol.compiler.collections:<ordered-dict>
                   :items result-items
                   :key-order result-order)))

(defmethod merge-with (f (coll fol.compiler.collections:<sorted-dict>) &rest colls)
  (let ((result-items (fol.compiler.collections:storage-items coll)))
    (dolist (other colls)
      (sycamore:do-tree-map ((k v) (fol.compiler.collections:storage-items other))
        (multiple-value-bind (existing found-key found-p)
            (sycamore:tree-map-find result-items k)
          (declare (ignore found-key))
          (setf result-items
                (sycamore:tree-map-insert result-items k
                                          (if found-p (funcall f existing v) v))))))
    (make-instance 'fol.compiler.collections:<sorted-dict>
                   :items result-items
                   :compare (fol.compiler.collections:comparator-compare coll))))

;;; ---------------------------------------------------------------------------
;;; select-keys - Extract a subset of keys from a dict
;;; ---------------------------------------------------------------------------

(defun select-keys (dict keys)
  "Return a new dict containing only the entries whose keys are in KEYS.
   (select-keys {:a 1 :b 2 :c 3} '(:a :c)) => {:a 1 :c 3}"
  (typecase dict
    (fol.compiler.collections:<ordered-dict>
     (let ((items (fol.compiler.collections:storage-items dict))
           (new-items (sycamore:make-hash-map))
           (new-order (fset:empty-seq)))
       (dolist (k keys)
         (multiple-value-bind (val found)
             (sycamore:hash-map-find items k)
           (when found
             (setf new-items (sycamore:hash-map-insert new-items k val))
             (setf new-order (fset:with-last new-order k)))))
       (make-instance 'fol.compiler.collections:<ordered-dict>
                      :items new-items
                      :key-order new-order)))
    (fol.compiler.collections:<sorted-dict>
     (let* ((items (fol.compiler.collections:storage-items dict))
            (cmp (fol.compiler.collections:comparator-compare dict))
            (new-items (sycamore:make-tree-map cmp)))
       (dolist (k keys)
         (multiple-value-bind (val found-key found-p)
             (sycamore:tree-map-find items k)
           (declare (ignore found-key))
           (when found-p
             (setf new-items (sycamore:tree-map-insert new-items k val)))))
       (make-instance 'fol.compiler.collections:<sorted-dict>
                      :items new-items
                      :compare cmp)))
    (fol.compiler.collections:<dict>
     (let ((items (fol.compiler.collections:storage-items dict))
           (new-items (sycamore:make-hash-map)))
       (dolist (k keys)
         (multiple-value-bind (val found)
             (sycamore:hash-map-find items k)
           (when found
             (setf new-items (sycamore:hash-map-insert new-items k val)))))
       (make-instance 'fol.compiler.collections:<dict>
                      :items new-items)))
    (t (cl:error "select-keys requires a dict, got ~S" dict))))

;;; ---------------------------------------------------------------------------
;;; rename-keys - Rename keys in a dict according to a mapping
;;; ---------------------------------------------------------------------------

(defun rename-keys (dict kmap)
  "Return a new dict with keys renamed according to KMAP.
   Keys not in KMAP are kept unchanged.
   (rename-keys {:a 1 :b 2} {:a :x}) => {:x 1 :b 2}"
  (let ((kmap-items (fol.compiler.collections:storage-items kmap)))
    (typecase dict
      (fol.compiler.collections:<ordered-dict>
       (let ((items (fol.compiler.collections:storage-items dict))
             (new-items (sycamore:make-hash-map))
             (new-order (fset:empty-seq)))
         (fset:do-seq (k (fol.compiler.collections:ordered-dict-key-order dict))
           (multiple-value-bind (new-key found)
               (sycamore:hash-map-find kmap-items k)
             (let ((actual-key (if found new-key k))
                   (val (sycamore:hash-map-find items k)))
               (setf new-items (sycamore:hash-map-insert new-items actual-key val))
               (setf new-order (fset:with-last new-order actual-key)))))
         (make-instance 'fol.compiler.collections:<ordered-dict>
                        :items new-items
                        :key-order new-order)))
      (fol.compiler.collections:<dict>
       (let ((items (fol.compiler.collections:storage-items dict))
             (new-items (sycamore:make-hash-map)))
         (sycamore:do-hash-map ((k v) items)
           (multiple-value-bind (new-key found)
               (sycamore:hash-map-find kmap-items k)
             (setf new-items (sycamore:hash-map-insert new-items
                                                        (if found new-key k) v))))
         (make-instance 'fol.compiler.collections:<dict>
                        :items new-items)))
      (t (cl:error "rename-keys requires a dict, got ~S" dict)))))

;;; ---------------------------------------------------------------------------
;;; map-invert - Swap keys and values in a dict
;;; ---------------------------------------------------------------------------

(defun map-invert (dict)
  "Return a new dict with keys and values swapped.
   (map-invert {:a 1 :b 2}) => {1 :a 2 :b}"
  (typecase dict
    (fol.compiler.collections:<dict>
     (let ((new-items (sycamore:make-hash-map)))
       (sycamore:do-hash-map ((k v) (fol.compiler.collections:storage-items dict))
         (setf new-items (sycamore:hash-map-insert new-items v k)))
       (make-instance 'fol.compiler.collections:<dict>
                      :items new-items)))
    (t (cl:error "map-invert requires a dict, got ~S" dict))))

;;; ---------------------------------------------------------------------------
;;; update-keys - Transform all keys with a function
;;; ---------------------------------------------------------------------------

(defun update-keys (dict f)
  "Return a new dict with F applied to each key, values unchanged.
   (update-keys {:a 1 :b 2} #'symbol-name) => {\"A\" 1 \"B\" 2}"
  (typecase dict
    (fol.compiler.collections:<ordered-dict>
     (let ((items (fol.compiler.collections:storage-items dict))
           (new-items (sycamore:make-hash-map))
           (new-order (fset:empty-seq)))
       (fset:do-seq (k (fol.compiler.collections:ordered-dict-key-order dict))
         (let ((new-key (funcall f k))
               (val (sycamore:hash-map-find items k)))
           (setf new-items (sycamore:hash-map-insert new-items new-key val))
           (setf new-order (fset:with-last new-order new-key))))
       (make-instance 'fol.compiler.collections:<ordered-dict>
                      :items new-items
                      :key-order new-order)))
    (fol.compiler.collections:<dict>
     (let ((new-items (sycamore:make-hash-map)))
       (sycamore:do-hash-map ((k v) (fol.compiler.collections:storage-items dict))
         (setf new-items (sycamore:hash-map-insert new-items (funcall f k) v)))
       (make-instance 'fol.compiler.collections:<dict>
                      :items new-items)))
    (t (cl:error "update-keys requires a dict, got ~S" dict))))

;;; ---------------------------------------------------------------------------
;;; update-vals - Transform all values with a function
;;; ---------------------------------------------------------------------------

(defun update-vals (dict f)
  "Return a new dict with F applied to each value, keys unchanged.
   (update-vals {:a 1 :b 2} #'1+) => {:a 2 :b 3}"
  (typecase dict
    (fol.compiler.collections:<ordered-dict>
     (let ((items (fol.compiler.collections:storage-items dict))
           (new-items (sycamore:make-hash-map)))
       (sycamore:do-hash-map ((k v) items)
         (setf new-items (sycamore:hash-map-insert new-items k (funcall f v))))
       (make-instance 'fol.compiler.collections:<ordered-dict>
                      :items new-items
                      :key-order (fol.compiler.collections:ordered-dict-key-order dict))))
    (fol.compiler.collections:<sorted-dict>
     (let* ((cmp (fol.compiler.collections:comparator-compare dict))
            (new-items (sycamore:make-tree-map cmp)))
       (sycamore:do-tree-map ((k v) (fol.compiler.collections:storage-items dict))
         (setf new-items (sycamore:tree-map-insert new-items k (funcall f v))))
       (make-instance 'fol.compiler.collections:<sorted-dict>
                      :items new-items
                      :compare cmp)))
    (fol.compiler.collections:<dict>
     (let ((new-items (sycamore:make-hash-map)))
       (sycamore:do-hash-map ((k v) (fol.compiler.collections:storage-items dict))
         (setf new-items (sycamore:hash-map-insert new-items k (funcall f v))))
       (make-instance 'fol.compiler.collections:<dict>
                      :items new-items)))
    (t (cl:error "update-vals requires a dict, got ~S" dict))))

;;; ===========================================================================
;;; Sorted Dict Operations (rseq, subseq, rsubseq)
;;; ===========================================================================

;;; ---------------------------------------------------------------------------
;;; rseq - Reverse sequence for sorted-dict
;;; ---------------------------------------------------------------------------

(defmethod rseq ((coll fol.compiler.collections:<sorted-dict>))
  "Return the entries of the sorted-dict in reverse key order as a CL list of (key . value)."
  (let ((items (fol.compiler.collections:storage-items coll))
        (result '()))
    (sycamore:do-tree-map ((k v) items)
      (cl:push (cons k v) result))
    result))

;;; ---------------------------------------------------------------------------
;;; subseq - Range query on sorted dicts (Clojure-style API)
;;; ---------------------------------------------------------------------------

(defmethod subseq ((sc fol.compiler.collections:<sorted-dict>) test key
                   &optional end-test end-key)
  "Range query on a sorted tree-map. Returns a CL list of (key . value) pairs."
  (let* ((cmp (fol.compiler.collections:comparator-compare sc))
         (entries '())
         (start-pred (cond
                       ((eq test '>=) (lambda (k) (cl:>= (funcall cmp k key) 0)))
                       ((eq test '>)  (lambda (k) (cl:> (funcall cmp k key) 0)))
                       ((eq test '<=) (lambda (k) (cl:<= (funcall cmp k key) 0)))
                       ((eq test '<)  (lambda (k) (cl:< (funcall cmp k key) 0)))
                       (t (cl:error "subseq: invalid test ~S, must be >=, >, <=, or <" test))))
         (end-pred (when end-test
                     (cond
                       ((eq end-test '>=) (lambda (k) (cl:>= (funcall cmp k end-key) 0)))
                       ((eq end-test '>)  (lambda (k) (cl:> (funcall cmp k end-key) 0)))
                       ((eq end-test '<=) (lambda (k) (cl:<= (funcall cmp k end-key) 0)))
                       ((eq end-test '<)  (lambda (k) (cl:< (funcall cmp k end-key) 0)))
                       (t (cl:error "subseq: invalid end-test ~S, must be >=, >, <=, or <"
                                    end-test))))))
    (sycamore:do-tree-map ((k v) (fol.compiler.collections:storage-items sc))
      (when (and (funcall start-pred k)
                 (or (null end-pred) (funcall end-pred k)))
        (cl:push (cons k v) entries)))
    (nreverse entries)))

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
  (let ((items (fol.compiler.collections:storage-items coll)))
    (when (cl:plusp (fset:size items))
      (fset:first items))))

;;; ---------------------------------------------------------------------------
;;; pop - Remove front element of deque
;;; ---------------------------------------------------------------------------

(defmethod pop ((coll fol.compiler.collections:<deque>))
  "Return a new deque without the front element. Signals an error if empty."
  (let ((items (fol.compiler.collections:storage-items coll)))
    (if (cl:plusp (fset:size items))
        (make-instance 'fol.compiler.collections:<deque>
                       :items (fset:less-first items))
        (cl:error "Cannot pop an empty deque"))))

;;; ---------------------------------------------------------------------------
;;; push - Add element to back of deque
;;; ---------------------------------------------------------------------------

(defmethod push ((coll fol.compiler.collections:<deque>) value)
  "Add VALUE to the back of the deque."
  (make-instance 'fol.compiler.collections:<deque>
                 :items (fset:with-last (fol.compiler.collections:storage-items coll) value)))

;;; ---------------------------------------------------------------------------
;;; rpeek - Look at back element of deque
;;; ---------------------------------------------------------------------------

(defgeneric rpeek (coll)
  (:documentation "Return the element at the opposite end from peek, without modifying.
   For deques, returns the back element."))

(defmethod rpeek ((coll fol.compiler.collections:<deque>))
  "Return the back element of the deque, or NIL if empty."
  (let ((items (fol.compiler.collections:storage-items coll)))
    (when (cl:plusp (fset:size items))
      (fset:last items))))

;;; ---------------------------------------------------------------------------
;;; rpop - Remove element from back of deque
;;; ---------------------------------------------------------------------------

(defgeneric rpop (coll)
  (:documentation "Return a new collection without the element at the opposite end from pop.
   For deques, removes the back element."))

(defmethod rpop ((coll fol.compiler.collections:<deque>))
  "Return a new deque without the back element. Signals an error if empty."
  (let ((items (fol.compiler.collections:storage-items coll)))
    (if (cl:plusp (fset:size items))
        (make-instance 'fol.compiler.collections:<deque>
                       :items (fset:less-last items))
        (cl:error "Cannot rpop an empty deque"))))

;;; ---------------------------------------------------------------------------
;;; rpush - Add element to front of deque
;;; ---------------------------------------------------------------------------

(defgeneric rpush (coll value)
  (:documentation "Add VALUE at the opposite end from push.
   For deques, adds to the front."))

(defmethod rpush ((coll fol.compiler.collections:<deque>) value)
  "Add VALUE to the front of the deque."
  (make-instance 'fol.compiler.collections:<deque>
                 :items (fset:with-first (fol.compiler.collections:storage-items coll) value)))

;;; ---------------------------------------------------------------------------
;;; rconj - Add element to front of deque
;;; ---------------------------------------------------------------------------

(defgeneric rconj (coll value)
  (:documentation "Add VALUE at the opposite end from conj.
   For deques, adds to the front."))

(defmethod rconj ((coll fol.compiler.collections:<deque>) value)
  "Add VALUE to the front of the deque."
  (make-instance 'fol.compiler.collections:<deque>
                 :items (fset:with-first (fol.compiler.collections:storage-items coll) value)))
