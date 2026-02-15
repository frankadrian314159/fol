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
                   :comparator (slot-value coll 'fol.compiler.collections::comparator))))


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
                   :comparator (slot-value coll 'fol.compiler.collections::comparator))))

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
                       :comparator (slot-value coll 'fol.compiler.collections::comparator)))))
