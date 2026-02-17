;;; FOL Compiler - Collection Base Class
;;;
;;; Defines the abstract base class <collection> for all FOL collection types.
;;; Subclasses of <collection> (standard-object) include standard-object as the
;;; superclass rather than the persistent metaclass because they wrap
;;; already-persistent backing stores (FSet seq, Sycamore hash-map/hash-set).
;;;
;;; The collection protocol defines four generic operations:
;;;   collection-size    - number of elements
;;;   collection-empty-p - whether the collection has no elements
;;;   collection-conj    - add an element (returns a new collection)
;;;   collection-seq     - return elements as a CL list

(in-package :fol.compiler.collections)

;;; ============================================================================
;;; Base Class
;;; ============================================================================

(defclass <collection> (standard-object)
  ((metadata :accessor collection-metadata
             :initarg :metadata :initform nil
             :documentation "Optional metadata dict associated with this collection."))
  (:documentation "Abstract base class for all FOL collections.
                   Subclasses wrap persistent backing stores (FSet, Sycamore)
                   and implement the collection protocol generics."))

;;; ============================================================================
;;; Type Predicate
;;; ============================================================================

(defgeneric <collection>? (obj)
  (:documentation "Returns T if OBJ is a FOL <collection>."))

(defmethod <collection>? (obj)
  (declare (ignore obj))
  nil)

(defmethod <collection>? ((obj <collection>))
  (declare (ignore obj))
  t)

;;; ============================================================================
;;; Collection Protocol
;;; ============================================================================

(defgeneric collection-size (collection)
  (:documentation "Return the number of elements in COLLECTION."))

(defmethod collection-size ((c <collection>))
  (declare (ignore c))
  0)

(defgeneric collection-empty-p (collection)
  (:documentation "Return T if COLLECTION has no elements."))

(defmethod collection-empty-p ((c <collection>))
  "Default: empty when size is zero."
  (zerop (collection-size c)))

(defgeneric collection-conj (collection element)
  (:documentation "Return a new collection with ELEMENT added.
                   The position of the new element depends on the collection type."))

(defmethod collection-conj ((c null) element)
  (cl:list element))

(defmethod collection-conj ((c cl:list) element)
  (cl:cons element c))

(defgeneric collection-seq (collection)
  (:documentation "Return the elements of COLLECTION as a CL list.
                   For dicts, returns a list of (key . value) cons pairs."))
                   
(defmethod collection-size ((c cl:list))
  (cl:length c))

(defmethod collection-seq ((c cl:list))
  c)

;;; ============================================================================
;;; Collection Storage
;;; ============================================================================

(defclass <collection-storage> (standard-object)
  ((items :initarg :items
          :initform nil
          :reader storage-items
          :documentation "The backing store for a collection."))
  (:documentation "Base storage class for collections.
                   Holds the underlying persistent data structure in a single slot."))
  
  (defmethod collection-size ((c <collection-storage>))
    (declare (ignore c))
    0)

;;; ============================================================================
;;; Comparator Interface
;;; ============================================================================

(defclass <comparator> (standard-object)
  ((compare :initarg :compare
            :initform (lambda (a b)
                        (cond ((< a b) -1)
                              ((> a b)  1)
                              (t        0)))
            :reader comparator-compare
            :documentation "A comparator for a sorted collection.
                            Must return a negative fixnum, zero, or positive fixnum."))
  (:documentation "Base comparator class for sorted collections.
                   The compare function returns -1, 0, or 1."))

;;; ============================================================================
;;; Unordered Collection
;;; ============================================================================

(defclass <unordered-collection> (<collection>)
  ()
  (:documentation "Abstract base class for unordered collections (dicts, sets, bags).
                   Elements have no guaranteed iteration order."))

(defgeneric <unordered-collection>? (obj)
  (:documentation "Returns T if OBJ is a FOL <unordered-collection>."))

(defmethod <unordered-collection>? (obj)
  (declare (ignore obj))
  nil)

(defmethod <unordered-collection>? ((obj <unordered-collection>))
  (declare (ignore obj))
  t)

;;; ============================================================================
;;; Ordered Collection
;;; ============================================================================

(defclass <ordered-collection> (<collection>)
  ()
  (:documentation "Abstract base class for ordered collections (vectors, lists, deques).
                   Elements maintain a defined sequence order."))

(defgeneric <ordered-collection>? (obj)
  (:documentation "Returns T if OBJ is a FOL <ordered-collection>."))

(defmethod <ordered-collection>? (obj)
  (declare (ignore obj))
  nil)

(defmethod <ordered-collection>? ((obj <ordered-collection>))
  (declare (ignore obj))
  t)

;;; ============================================================================
;;; Vector
;;; ============================================================================

(defclass <vector> (<ordered-collection> <collection-storage>)
  ()
  (:default-initargs :items (fset:empty-seq))
  (:documentation "A persistent ordered vector backed by an FSet seq."))

(defgeneric <vector>? (obj)
  (:documentation "Returns T if OBJ is a FOL <vector>."))

(defmethod <vector>? (obj)
  (declare (ignore obj))
  nil)

(defmethod <vector>? ((obj <vector>))
  (declare (ignore obj))
  t)

(defmethod make ((class (eql '<vector>)) &rest elements)
  "Create a new <vector> from ELEMENTS.
   (make '<vector>)       => empty vector
   (make '<vector> 1 2 3) => vector of 1, 2, 3"
  (make-instance '<vector>
                 :items (if elements
                            (fset:convert 'fset:seq elements)
                            (fset:empty-seq))))

;;; --- Protocol methods for <vector> ---

(defmethod collection-size ((v <vector>))
  (fset:size (storage-items v)))

(defmethod collection-conj ((v <vector>) element)
  "Append ELEMENT to the end of the vector."
  (make-instance '<vector>
                 :items (fset:with-last (storage-items v) element)))

(defmethod collection-seq ((v <vector>))
  (fset:convert 'cl:list (storage-items v)))

(defmethod collection-size ((c cl:vector))
  (cl:length c))

;;; ============================================================================
;;; Array (subclass of Vector)
;;; ============================================================================

(defclass <array> (<vector>)
  ((dimension :initarg :dimension
              :initform '(1)
              :reader array-dimension
              :documentation "List of dimension sizes, as in CL array-dimensions."))
  (:default-initargs :items (cl:make-array 0))
  (:documentation "A persistent array backed by a CL simple-vector.
                   Subclass of <vector> with O(1) indexed access and
                   a dimension slot tracking shape."))

(defgeneric <array>? (obj)
  (:documentation "Returns T if OBJ is a FOL <array>."))

(defmethod <array>? (obj)
  (declare (ignore obj))
  nil)

(defmethod <array>? ((obj <array>))
  (declare (ignore obj))
  t)

(defmethod initialize-instance :after ((a <array>) &key)
  "Validate that all dimension entries are non-negative integers."
  (dolist (d (array-dimension a))
    (unless (and (integerp d) (>= d 0))
      (error "Array dimension ~A is not a non-negative integer" d))))

(defmethod make ((class (eql '<array>)) &rest elements)
  "Create a new <array> from ELEMENTS.
   (make '<array>)       => empty array
   (make '<array> 1 2 3) => array of 1, 2, 3"
  (make-instance '<array>
                 :items (cl:make-array (length elements)
                                       :initial-contents elements)
                 :dimension (cl:list (length elements))))

;;; --- Protocol methods for <array> (override <vector> FSet-based methods) ---

(defmethod collection-size ((a <array>))
  (length (storage-items a)))

(defmethod collection-conj ((a <array>) element)
  "Append ELEMENT to the end of the array (copy-on-write)."
  (let* ((old (storage-items a))
         (n (length old))
         (new (cl:make-array (1+ n))))
    (dotimes (i n)
      (setf (aref new i) (aref old i)))
    (setf (aref new n) element)
    (make-instance '<array> :items new :dimension (cl:list (1+ n)))))

(defmethod collection-seq ((a <array>))
  (coerce (storage-items a) 'cl:list))

;;; ============================================================================
;;; Dict
;;; ============================================================================

(defclass <dict> (<unordered-collection> <collection-storage>)
  ()
  (:default-initargs :items (sycamore:make-hash-map))
  (:documentation "A persistent unordered dictionary backed by a Sycamore hash-map."))

(defgeneric <dict>? (obj)
  (:documentation "Returns T if OBJ is a FOL <dict>."))

(defmethod <dict>? (obj)
  (declare (ignore obj))
  nil)

(defmethod <dict>? ((obj <dict>))
  (declare (ignore obj))
  t)

(defmethod make ((class (eql '<dict>)) &rest args)
  "Create a new <dict> from alternating key-value ARGS.
   (make '<dict>)             => empty dict
   (make '<dict> :a 1 :b 2)  => dict with :a->1, :b->2"
  (make-instance '<dict>
                 :items (loop with m = (sycamore:make-hash-map)
                              for (k v) on args by #'cddr
                              do (setf m (sycamore:hash-map-insert m k v))
                              finally (return m))))

;;; --- Protocol methods for <dict> ---

(defmethod collection-size ((d <dict>))
  (sycamore:fold-hash-map (lambda (acc k v)
                            (declare (ignore k v))
                            (1+ acc))
                          0 (storage-items d)))

(defmethod collection-conj ((d <dict>) element)
  "Add a (key . value) cons pair to the dict."
  (make-instance '<dict>
                 :items (sycamore:hash-map-insert (storage-items d)
                                                  (car element) (cdr element))))

(defmethod collection-seq ((d <dict>))
  (sycamore:hash-map-alist (storage-items d)))

;;; ============================================================================
;;; Helpers
;;; ============================================================================

(defun %fset-seq-contains-p (seq key)
  "Return T if FSet SEQ contains KEY (compared by EQL)."
  (fset:do-seq (item seq)
    (when (eql item key)
      (return-from %fset-seq-contains-p t))))

;;; ============================================================================
;;; Ordered Dict
;;; ============================================================================

(defclass <ordered-dict> (<dict>)
  ((key-order :initarg :key-order
              :initform (fset:empty-seq)
              :reader ordered-dict-key-order))
  (:documentation "A persistent insertion-ordered dictionary.
                   Inherits the Sycamore hash-map from <dict> for O(~1) lookup.
                   Maintains an FSet seq of keys in insertion order."))

(defgeneric <ordered-dict>? (obj)
  (:documentation "Returns T if OBJ is a FOL <ordered-dict>."))

(defmethod <ordered-dict>? (obj)
  (declare (ignore obj))
  nil)

(defmethod <ordered-dict>? ((obj <ordered-dict>))
  (declare (ignore obj))
  t)

(defmethod make ((class (eql '<ordered-dict>)) &rest args)
  "Create a new <ordered-dict> from alternating key-value ARGS.
   Keys are stored in the order provided; duplicate keys keep the last value
   and retain the position of the first occurrence.
   (make '<ordered-dict>)             => empty ordered dict
   (make '<ordered-dict> :a 1 :b 2)  => ordered dict with :a->1, :b->2"
  (loop with m = (sycamore:make-hash-map)
        with keys = (fset:empty-seq)
        with seen = (make-hash-table :test 'eql)
        for (k v) on args by #'cddr
        do (setf m (sycamore:hash-map-insert m k v))
           (unless (gethash k seen)
             (setf keys (fset:with-last keys k))
             (setf (gethash k seen) t))
        finally (return (make-instance '<ordered-dict>
                                       :items m
                                       :key-order keys))))

;;; --- Protocol methods for <ordered-dict> ---

(defmethod collection-size ((d <ordered-dict>))
  (fset:size (ordered-dict-key-order d)))

(defmethod collection-conj ((d <ordered-dict>) element)
  "Add a (key . value) cons pair, preserving insertion order.
   If the key already exists, its value is updated in place."
  (let* ((key (car element))
         (val (cdr element))
         (new-items (sycamore:hash-map-insert (storage-items d) key val))
         (existing-keys (ordered-dict-key-order d))
         (new-keys (if (%fset-seq-contains-p existing-keys key)
                       existing-keys
                       (fset:with-last existing-keys key))))
    (make-instance '<ordered-dict>
                   :items new-items
                   :key-order new-keys)))

(defmethod collection-seq ((d <ordered-dict>))
  "Return entries as an alist in insertion order."
  (let ((items (storage-items d))
        (result nil))
    (fset:do-seq (k (ordered-dict-key-order d))
      (push (cons k (sycamore:hash-map-find items k)) result))
    (nreverse result)))

;;; ============================================================================
;;; Array Dict
;;; ============================================================================

(defclass <array-dict> (<dict> <ordered-collection>)
  ((key-order :initarg :key-order
              :initform (fset:empty-seq)
              :reader array-dict-key-order))
  (:documentation "A persistent insertion-ordered dictionary backed by a Sycamore
                   hash-map.  Inherits the hash-map from <dict> for O(~1) lookup
                   and adds <ordered-collection> to guarantee iteration order.
                   Best suited for small, dense key-value mappings (1-8 entries)
                   where insertion order must be preserved."))

(defgeneric <array-dict>? (obj)
  (:documentation "Returns T if OBJ is a FOL <array-dict>."))

(defmethod <array-dict>? (obj)
  (declare (ignore obj))
  nil)

(defmethod <array-dict>? ((obj <array-dict>))
  (declare (ignore obj))
  t)

(defmethod make ((class (eql '<array-dict>)) &rest args)
  "Create a new <array-dict> from alternating key-value ARGS.
   Keys are stored in the order provided; duplicate keys keep the last value
   and retain the position of the first occurrence.
   (make '<array-dict>)             => empty array dict
   (make '<array-dict> :a 1 :b 2)  => array dict with :a->1, :b->2"
  (loop with m = (sycamore:make-hash-map)
        with keys = (fset:empty-seq)
        with seen = (make-hash-table :test 'eql)
        for (k v) on args by #'cddr
        do (setf m (sycamore:hash-map-insert m k v))
           (unless (gethash k seen)
             (setf keys (fset:with-last keys k))
             (setf (gethash k seen) t))
        finally (return (make-instance '<array-dict>
                                       :items m
                                       :key-order keys))))

;;; --- Protocol methods for <array-dict> ---

(defmethod collection-size ((d <array-dict>))
  (fset:size (array-dict-key-order d)))

(defmethod collection-conj ((d <array-dict>) element)
  "Add a (key . value) cons pair, preserving insertion order.
   If the key already exists, its value is updated in place."
  (let* ((key (car element))
         (val (cdr element))
         (new-items (sycamore:hash-map-insert (storage-items d) key val))
         (existing-keys (array-dict-key-order d))
         (new-keys (if (%fset-seq-contains-p existing-keys key)
                       existing-keys
                       (fset:with-last existing-keys key))))
    (make-instance '<array-dict>
                   :items new-items
                   :key-order new-keys)))

(defmethod collection-seq ((d <array-dict>))
  "Return entries as an alist in insertion order."
  (let ((items (storage-items d))
        (result nil))
    (fset:do-seq (k (array-dict-key-order d))
      (push (cons k (sycamore:hash-map-find items k)) result))
    (nreverse result)))

;;; ============================================================================
;;; Sorted Dict
;;; ============================================================================

(defclass <sorted-dict> (<dict> <ordered-collection> <comparator>)
  ()
  (:documentation "A persistent sorted dictionary backed by a Sycamore tree-map.
                   Inherits storage from <dict> (via <collection-storage>),
                   ordering from <ordered-collection>, and comparison from <comparator>.
                   Keys are maintained in the order defined by the comparator
                   function, which must return a negative fixnum, zero, or
                   positive fixnum for less-than, equal, and greater-than
                   respectively."))

(defgeneric <sorted-dict>? (obj)
  (:documentation "Returns T if OBJ is a FOL <sorted-dict>."))

(defmethod <sorted-dict>? (obj)
  (declare (ignore obj))
  nil)

(defmethod <sorted-dict>? ((obj <sorted-dict>))
  (declare (ignore obj))
  t)

(defmethod make ((class (eql '<sorted-dict>)) &rest args)
  "Create a new <sorted-dict>.
   First argument is a comparator function (or NIL for default numeric order).
   Remaining arguments are alternating key-value pairs.
   (make '<sorted-dict> #'my-cmp)              => empty sorted dict
   (make '<sorted-dict> #'my-cmp :b 2 :a 1)   => sorted dict with :a->1, :b->2
   (make '<sorted-dict> nil 2 :b 1 :a)         => sorted dict with default numeric order"
  (let* ((cmp (or (first args)
                  (comparator-compare (make-instance '<comparator>))))
         (pairs (rest args))
         (tree (loop with tm = (sycamore:make-tree-map cmp)
                     for (k v) on pairs by #'cddr
                     do (setf tm (sycamore:tree-map-insert tm k v))
                     finally (return tm))))
    (make-instance '<sorted-dict>
                   :compare cmp
                   :items tree)))

;;; --- Protocol methods for <sorted-dict> ---

(defmethod collection-size ((d <sorted-dict>))
  (let ((n 0))
    (sycamore:map-tree-map :inorder nil
      (lambda (k v) (declare (ignore k v)) (incf n))
      (storage-items d))
    n))

(defmethod collection-conj ((d <sorted-dict>) element)
  "Add a (key . value) cons pair to the sorted dict in comparator order."
  (make-instance '<sorted-dict>
                 :compare (comparator-compare d)
                 :items (sycamore:tree-map-insert (storage-items d)
                                                   (car element) (cdr element))))

(defmethod collection-seq ((d <sorted-dict>))
  "Return entries as an alist of (key . value) pairs in comparator order."
  (sycamore:map-tree-map :inorder 'cl:list
    (lambda (k v) (cons k v))
    (storage-items d)))

;;; ============================================================================
;;; Int Dict
;;; ============================================================================

(defclass <int-dict> (<sorted-dict>)
  ()
  (:documentation "A persistent sorted dictionary specialized for integer keys.
                   Backed by a Sycamore tree-map with a hardcoded fixnum
                   comparator, avoiding the funcall overhead of a generic
                   comparator closure."))

(defgeneric <int-dict>? (obj)
  (:documentation "Returns T if OBJ is a FOL <int-dict>."))

(defmethod <int-dict>? (obj)
  (declare (ignore obj))
  nil)

(defmethod <int-dict>? ((obj <int-dict>))
  (declare (ignore obj))
  t)

(defmethod make ((class (eql '<int-dict>)) &rest args)
  "Create a new <int-dict> from alternating integer-key value ARGS.
   If the first argument is a function or NIL it is treated as a comparator
   (NIL defaults to the built-in fixnum comparator); remaining arguments
   are alternating key-value pairs.  When no comparator is supplied the
   built-in fixnum comparator is used.
   (make '<int-dict>)              => empty int dict
   (make '<int-dict> 1 :a 2 :b)   => int dict with 1->:a, 2->:b
   (make '<int-dict> #'my-cmp 1 :a) => int dict with custom comparator"
  (let* ((has-cmp (and args (or (functionp (first args)) (null (first args)))))
         (cmp (if has-cmp
                  (or (first args) #'%int-compare)
                  #'%int-compare))
         (pairs (if has-cmp (rest args) args))
         (tree (loop with tm = (sycamore:make-tree-map cmp)
                     for (k v) on pairs by #'cddr
                     do (setf tm (sycamore:tree-map-insert tm k v))
                     finally (return tm))))
    (make-instance '<int-dict>
                   :compare cmp
                   :items tree)))

;;; --- Protocol methods for <int-dict> ---

(defmethod collection-conj ((d <int-dict>) element)
  "Add a (key . value) cons pair to the int dict in comparator order."
  (make-instance '<int-dict>
                 :compare (comparator-compare d)
                 :items (sycamore:tree-map-insert (storage-items d)
                                                   (car element) (cdr element))))

;;; ============================================================================
;;; Priority Dict
;;; ============================================================================

(defclass <priority-dict> (<dict> <ordered-collection>)
  ((priority-tree :initarg :priority-tree
                  :initform nil
                  :reader priority-dict-tree
                  :documentation "Sycamore tree-map with (priority . key) composite keys
                                 for O(log n) priority ordering.")
   (priority-compare :initarg :priority-compare
                     :initform nil
                     :reader priority-dict-compare
                     :documentation "Comparator function for priority values.
                                    Returns negative/zero/positive fixnum."))
  (:documentation "A persistent priority dictionary backed by dual Sycamore structures.
                   Inherits the hash-map from <dict> for O(~1) key→priority lookup.
                   Maintains a Sycamore tree-map of (priority . key) composite keys
                   for O(log n) priority ordering, insert, update, and pop-min."))

(defgeneric <priority-dict>? (obj)
  (:documentation "Returns T if OBJ is a FOL <priority-dict>."))

(defmethod <priority-dict>? (obj)
  (declare (ignore obj))
  nil)

(defmethod <priority-dict>? ((obj <priority-dict>))
  (declare (ignore obj))
  t)

(defun %make-priority-key-cmp (pri-cmp)
  "Build a composite comparator for (priority . key) pairs from a priority comparator."
  (lambda (a b)
    (let ((result (funcall pri-cmp (car a) (car b))))
      (if (zerop result)
          ;; Tie-break by key symbol-name for deterministic ordering
          (let ((sa (if (symbolp (cdr a)) (symbol-name (cdr a))
                        (princ-to-string (cdr a))))
                (sb (if (symbolp (cdr b)) (symbol-name (cdr b))
                        (princ-to-string (cdr b)))))
            (cond ((string< sa sb) -1)
                  ((string> sa sb) 1)
                  (t 0)))
          result))))

(defun %default-priority-cmp (a b)
  "Default comparator for priority values (numeric ascending)."
  (cond ((cl:< a b) -1)
        ((cl:> a b)  1)
        (t           0)))

(defmethod make ((class (eql '<priority-dict>)) &rest args)
  "Create a new <priority-dict> from alternating key-priority ARGS.
   Entries are ordered by priority ascending (min-first).
   Duplicate keys keep the last priority.
   (make '<priority-dict>)             => empty priority dict
   (make '<priority-dict> :a 1 :b 3)  => priority dict with :a→1, :b→3"
  (let* ((pri-cmp #'%default-priority-cmp)
         (composite-cmp (%make-priority-key-cmp pri-cmp)))
    (loop with hm = (sycamore:make-hash-map)
          with tm = (sycamore:make-tree-map composite-cmp)
          for (k p) on args by #'cddr
          do (let ((old-pri (sycamore:hash-map-find hm k)))
               (when old-pri
                 (setf tm (sycamore:tree-map-remove tm (cons old-pri k))))
               (setf hm (sycamore:hash-map-insert hm k p))
               (setf tm (sycamore:tree-map-insert tm (cons p k) k)))
          finally (return (make-instance '<priority-dict>
                                         :items hm
                                         :priority-tree tm
                                         :priority-compare pri-cmp)))))

;;; --- Protocol methods for <priority-dict> ---

(defmethod collection-size ((d <priority-dict>))
  (let ((n 0))
    (sycamore:do-tree-map ((k v) (priority-dict-tree d))
      (declare (ignore k v))
      (incf n))
    n))

(defmethod collection-conj ((d <priority-dict>) element)
  "Add a (key . priority) cons pair. If the key exists, its priority is updated."
  (let* ((key (car element))
         (new-pri (cdr element))
         (hm (storage-items d))
         (tm (priority-dict-tree d))
         (old-pri (sycamore:hash-map-find hm key))
         (new-hm (sycamore:hash-map-insert hm key new-pri))
         (new-tm (if old-pri
                     (sycamore:tree-map-insert
                      (sycamore:tree-map-remove tm (cons old-pri key))
                      (cons new-pri key) key)
                     (sycamore:tree-map-insert tm (cons new-pri key) key))))
    (make-instance '<priority-dict>
                   :items new-hm
                   :priority-tree new-tm
                   :priority-compare (priority-dict-compare d))))

(defmethod collection-seq ((d <priority-dict>))
  "Return entries as an alist of (key . priority) pairs in priority order."
  (sycamore:map-tree-map :inorder 'cl:list
    (lambda (k v)
      (declare (ignore v))
      ;; k is (priority . key), return (key . priority)
      (cons (cdr k) (car k)))
    (priority-dict-tree d)))

;;; --- Priority-dict specific operations ---

(defgeneric priority-dict-peek-min (pdict)
  (:documentation "Return the (key . priority) entry with the minimum priority,
                   or NIL if the dict is empty."))

(defmethod priority-dict-peek-min ((d <priority-dict>))
  (block found
    (sycamore:do-tree-map ((k v) (priority-dict-tree d))
      (declare (ignore v))
      ;; k is (priority . key)
      (return-from found (cons (cdr k) (car k))))))

(defgeneric priority-dict-pop-min (pdict)
  (:documentation "Return a new <priority-dict> with the minimum-priority entry removed.
                   Returns the original dict if empty."))

(defmethod priority-dict-pop-min ((d <priority-dict>))
  (let ((min-entry (block found
                     (sycamore:do-tree-map ((k v) (priority-dict-tree d))
                       (declare (ignore v))
                       (return-from found k)))))
    (if (null min-entry)
        d
        ;; min-entry is (priority . key)
        (make-instance '<priority-dict>
                       :items (sycamore:hash-map-remove (storage-items d) (cdr min-entry))
                       :priority-tree (sycamore:tree-map-remove
                                       (priority-dict-tree d) min-entry)
                       :priority-compare (priority-dict-compare d)))))

;;; ============================================================================
;;; Set
;;; ============================================================================

(defclass <set> (<unordered-collection> <collection-storage>)
  ()
  (:default-initargs :items (sycamore:make-hash-set))
  (:documentation "A persistent unordered set backed by a Sycamore hash-set."))

(defgeneric <set>? (obj)
  (:documentation "Returns T if OBJ is a FOL <set>."))

(defmethod <set>? (obj)
  (declare (ignore obj))
  nil)

(defmethod <set>? ((obj <set>))
  (declare (ignore obj))
  t)

(defmethod make ((class (eql '<set>)) &rest elements)
  "Create a new <set> from ELEMENTS.
   (make '<set>)       => empty set
   (make '<set> 1 2 3) => set of 1, 2, 3"
  (make-instance '<set>
                 :items (loop with s = (sycamore:make-hash-set)
                              for e in elements
                              do (setf s (sycamore:hash-set-insert s e))
                              finally (return s))))

;;; --- Protocol methods for <set> ---

(defmethod collection-size ((s <set>))
  (length (sycamore:hash-set-list (storage-items s))))

(defmethod collection-conj ((s <set>) element)
  "Add ELEMENT to the set."
  (make-instance '<set>
                 :items (sycamore:hash-set-insert (storage-items s) element)))

(defmethod collection-seq ((s <set>))
  (sycamore:hash-set-list (storage-items s)))

;;; ============================================================================
;;; Ordered Set
;;; ============================================================================

(defclass <ordered-set> (<set> <ordered-collection>)
  ()
  (:default-initargs :items (cons (sycamore:make-hash-set) (fset:empty-seq)))
  (:documentation "A persistent ordered set that maintains insertion order.
                   Backed by a Sycamore hash-set (for O(1) membership) and
                   an FSet seq (for ordered iteration).
                   storage-items holds a cons of (hash-set . fset-seq)."))

(defgeneric <ordered-set>? (obj)
  (:documentation "Returns T if OBJ is a FOL <ordered-set>."))

(defmethod <ordered-set>? (obj)
  (declare (ignore obj))
  nil)

(defmethod <ordered-set>? ((obj <ordered-set>))
  (declare (ignore obj))
  t)

(defmethod make ((class (eql '<ordered-set>)) &rest elements)
  "Create a new <ordered-set> from ELEMENTS.
   Duplicates are silently dropped; insertion order is preserved.
   (make '<ordered-set>)       => empty ordered set
   (make '<ordered-set> 1 2 3) => ordered set of 1, 2, 3"
  (make-instance '<ordered-set>
                 :items (loop with hset = (sycamore:make-hash-set)
                              with seq = (fset:empty-seq)
                              for e in elements
                              unless (sycamore:hash-set-find hset e)
                              do (setf hset (sycamore:hash-set-insert hset e))
                                 (setf seq (fset:with-last seq e))
                              finally (return (cons hset seq)))))

;;; --- Protocol methods for <ordered-set> ---

(defmethod collection-size ((s <ordered-set>))
  (fset:size (cdr (storage-items s))))

(defmethod collection-conj ((s <ordered-set>) element)
  "Add ELEMENT to the ordered set, preserving insertion order.
   If ELEMENT is already present, returns the set unchanged."
  (let* ((items (storage-items s))
         (hset (car items))
         (seq (cdr items)))
    (if (sycamore:hash-set-find hset element)
        s
        (make-instance '<ordered-set>
                       :items (cons (sycamore:hash-set-insert hset element)
                                    (fset:with-last seq element))))))

(defmethod collection-seq ((s <ordered-set>))
  (fset:convert 'cl:list (cdr (storage-items s))))

;;; ============================================================================
;;; Sorted Set
;;; ============================================================================

(defclass <sorted-set> (<set> <ordered-collection> <comparator>)
  ()
  (:documentation "A persistent sorted set backed by a Sycamore tree-set.
                   Elements are maintained in the order defined by the comparator
                   function (inherited from <comparator>), which must return a
                   negative fixnum, zero, or positive fixnum for less-than,
                   equal, and greater-than respectively.
                   The comparator is stored in the compare slot and also used
                   to construct the Sycamore tree-set in storage-items."))

(defgeneric <sorted-set>? (obj)
  (:documentation "Returns T if OBJ is a FOL <sorted-set>."))

(defmethod <sorted-set>? (obj)
  (declare (ignore obj))
  nil)

(defmethod <sorted-set>? ((obj <sorted-set>))
  (declare (ignore obj))
  t)

(defmethod make ((class (eql '<sorted-set>)) &rest args)
  "Create a new <sorted-set>.
   First argument is a comparator function (or NIL for default numeric order).
   Remaining arguments are elements.
   (make '<sorted-set> #'my-cmp)       => empty sorted set
   (make '<sorted-set> #'my-cmp 5 3 1) => sorted set of 1, 3, 5
   (make '<sorted-set> nil 5 3 1)      => sorted set with default numeric order"
  (let* ((cmp (or (first args)
                  (comparator-compare (make-instance '<comparator>))))
         (elements (rest args))
         (tree (loop with ts = (sycamore:make-tree-set cmp)
                     for e in elements
                     do (setf ts (sycamore:tree-set-insert ts e))
                     finally (return ts))))
    (make-instance '<sorted-set>
                   :compare cmp
                   :items tree)))

;;; --- Protocol methods for <sorted-set> ---

(defmethod collection-size ((s <sorted-set>))
  (sycamore:tree-set-count (storage-items s)))

(defmethod collection-conj ((s <sorted-set>) element)
  "Add ELEMENT to the sorted set in comparator order.
   If ELEMENT is already present, returns the set unchanged."
  (let ((tree (storage-items s)))
    (if (sycamore:tree-set-member-p tree element)
        s
        (make-instance '<sorted-set>
                       :compare (comparator-compare s)
                       :items (sycamore:tree-set-insert tree element)))))

(defmethod collection-seq ((s <sorted-set>))
  (sycamore:tree-set-list (storage-items s)))

;;; ============================================================================
;;; Int Set
;;; ============================================================================

(defun %int-compare (a b)
  "Optimized fixnum comparator for <int-set>."
  (declare (optimize (speed 3) (safety 0))
           (fixnum a b))
  (cond ((< a b) -1) ((> a b) 1) (t 0)))

(defclass <int-set> (<sorted-set>)
  ()
  (:documentation "A persistent sorted set specialized for integers.
                   Backed by a Sycamore tree-set with a hardcoded fixnum
                   comparator, avoiding the funcall overhead of a generic
                   comparator closure."))

(defgeneric <int-set>? (obj)
  (:documentation "Returns T if OBJ is a FOL <int-set>."))

(defmethod <int-set>? (obj)
  (declare (ignore obj))
  nil)

(defmethod <int-set>? ((obj <int-set>))
  (declare (ignore obj))
  t)

(defmethod make ((class (eql '<int-set>)) &rest elements)
  "Create a new <int-set> from integer ELEMENTS.
   (make '<int-set>)       => empty int set
   (make '<int-set> 5 3 1) => int set of 1, 3, 5"
  (let ((tree (loop with ts = (sycamore:make-tree-set #'%int-compare)
                    for e in elements
                    do (setf ts (sycamore:tree-set-insert ts e))
                    finally (return ts))))
    (make-instance '<int-set>
                   :compare #'%int-compare
                   :items tree)))

;;; --- Protocol methods for <int-set> ---

(defmethod collection-conj ((s <int-set>) element)
  "Add integer ELEMENT to the int set in numeric order.
   If ELEMENT is already present, returns the set unchanged."
  (let ((tree (storage-items s)))
    (if (sycamore:tree-set-member-p tree element)
        s
        (make-instance '<int-set>
                       :compare #'%int-compare
                       :items (sycamore:tree-set-insert tree element)))))

;;; ============================================================================
;;; Dense Int Set
;;; ============================================================================

(defclass <dense-int-set> (<ordered-collection> <collection-storage>)
  ((offset :initarg :offset
           :initform 0
           :reader dense-int-set-offset
           :documentation "The minimum integer in the range (bit 0 = this value).")
   (count :initarg :count
          :initform 0
          :reader dense-int-set-count
          :documentation "Cached count of set bits."))
  (:default-initargs :items (make-array 0 :element-type 'bit))
  (:documentation "A persistent set of integers optimized for dense, contiguous ranges.
                   Backed by a CL bit-vector.  Bit N represents integer (offset + N).
                   Membership is O(1), iteration is O(range-size), and memory is
                   1 bit per integer in the range [offset, offset+length)."))

(defgeneric <dense-int-set>? (obj)
  (:documentation "Returns T if OBJ is a FOL <dense-int-set>."))

(defmethod <dense-int-set>? (obj)
  (declare (ignore obj))
  nil)

(defmethod <dense-int-set>? ((obj <dense-int-set>))
  (declare (ignore obj))
  t)

(defmethod make ((class (eql '<dense-int-set>)) &rest elements)
  "Create a new <dense-int-set> from integer ELEMENTS.
   (make '<dense-int-set>)       => empty dense int set
   (make '<dense-int-set> 5 3 1) => dense int set of 1, 3, 5"
  (if (null elements)
      (make-instance '<dense-int-set>)
      (let* ((lo (reduce #'min elements))
             (hi (reduce #'max elements))
             (size (1+ (- hi lo)))
             (bv (make-array size :element-type 'bit :initial-element 0))
             (n 0))
        (dolist (e elements)
          (let ((idx (- e lo)))
            (when (zerop (sbit bv idx))
              (setf (sbit bv idx) 1)
              (incf n))))
        (make-instance '<dense-int-set>
                       :items bv
                       :offset lo
                       :count n))))

;;; --- Protocol methods for <dense-int-set> ---

(defmethod collection-size ((s <dense-int-set>))
  (dense-int-set-count s))

(defmethod collection-conj ((s <dense-int-set>) element)
  "Add integer ELEMENT to the dense int set.
   If ELEMENT is already present, returns the set unchanged.
   If ELEMENT falls outside the current range, the bit-vector is extended."
  (let* ((bv (storage-items s))
         (offset (dense-int-set-offset s))
         (len (length bv))
         (cnt (dense-int-set-count s)))
    (if (zerop len)
        ;; Empty set — create a single-element set
        (let ((new-bv (make-array 1 :element-type 'bit :initial-element 1)))
          (make-instance '<dense-int-set>
                         :items new-bv :offset element :count 1))
        (let ((idx (- element offset)))
          (cond
            ;; Within range and already present
            ((and (>= idx 0) (< idx len) (= 1 (sbit bv idx)))
             s)
            ;; Within range but not present
            ((and (>= idx 0) (< idx len))
             (let ((new-bv (copy-seq bv)))
               (setf (sbit new-bv idx) 1)
               (make-instance '<dense-int-set>
                              :items new-bv :offset offset :count (1+ cnt))))
            ;; Below range — extend left
            ((< idx 0)
             (let* ((new-offset element)
                    (new-len (+ len (- idx)))
                    (new-bv (make-array new-len :element-type 'bit :initial-element 0)))
               ;; Copy old bits to their new positions
               (loop for i below len
                     do (setf (sbit new-bv (+ i (- idx))) (sbit bv i)))
               (setf (sbit new-bv 0) 1)
               (make-instance '<dense-int-set>
                              :items new-bv :offset new-offset :count (1+ cnt))))
            ;; Above range — extend right
            (t
             (let* ((new-len (1+ idx))
                    (new-bv (make-array new-len :element-type 'bit :initial-element 0)))
               (loop for i below len
                     do (setf (sbit new-bv i) (sbit bv i)))
               (setf (sbit new-bv idx) 1)
               (make-instance '<dense-int-set>
                              :items new-bv :offset offset :count (1+ cnt)))))))))

(defmethod collection-seq ((s <dense-int-set>))
  "Return elements as a sorted list of integers."
  (let ((bv (storage-items s))
        (offset (dense-int-set-offset s)))
    (loop for i below (length bv)
          when (= 1 (sbit bv i))
            collect (+ offset i))))

;;; ============================================================================
;;; Bag (Multiset)
;;; ============================================================================

(defclass <bag> (<unordered-collection> <collection-storage>)
  ()
  (:default-initargs :items (sycamore:make-hash-map))
  (:documentation "A persistent multiset (bag) backed by a Sycamore hash-map.
                   Keys are elements, values are occurrence counts."))

(defgeneric <bag>? (obj)
  (:documentation "Returns T if OBJ is a FOL <bag>."))

(defmethod <bag>? (obj)
  (declare (ignore obj))
  nil)

(defmethod <bag>? ((obj <bag>))
  (declare (ignore obj))
  t)

(defmethod make ((class (eql '<bag>)) &rest elements)
  "Create a new <bag> from ELEMENTS.
   Duplicate elements increase the count.
   (make '<bag>)         => empty bag
   (make '<bag> 1 1 2)   => bag with 1->2, 2->1"
  (make-instance '<bag>
                 :items (loop with m = (sycamore:make-hash-map)
                              for e in elements
                              do (let ((count (or (sycamore:hash-map-find m e) 0)))
                                   (setf m (sycamore:hash-map-insert m e (1+ count))))
                              finally (return m))))

;;; --- Protocol methods for <bag> ---

(defmethod collection-size ((b <bag>))
  "Total number of elements including multiplicities."
  (sycamore:fold-hash-map (lambda (acc k v)
                            (declare (ignore k))
                            (+ acc v))
                          0 (storage-items b)))

(defmethod collection-conj ((b <bag>) element)
  "Add one occurrence of ELEMENT to the bag."
  (let* ((items (storage-items b))
         (count (or (sycamore:hash-map-find items element) 0)))
    (make-instance '<bag>
                   :items (sycamore:hash-map-insert items element (1+ count)))))

(defmethod collection-seq ((b <bag>))
  "Return elements as a flat list with each element repeated by its count."
  (let ((result nil))
    (sycamore:fold-hash-map
     (lambda (acc k v)
       (declare (ignore acc))
       (dotimes (i v)
         (push k result)))
     nil (storage-items b))
    (nreverse result)))

;;; ============================================================================
;;; Deque
;;; ============================================================================

(defclass <deque> (<vector>)
  ()
  (:documentation "A persistent double-ended queue implemented using FSet sequences.
                   Inherits storage from <vector> (FSet seq).
                   Supports O(log n) operations at both ends."))

(defgeneric <deque>? (obj)
  (:documentation "Returns T if OBJ is a FOL <deque>."))

(defmethod <deque>? (obj)
  (declare (ignore obj))
  nil)

(defmethod <deque>? ((obj <deque>))
  (declare (ignore obj))
  t)

;; A deque is NOT a vector for predicate purposes
(defmethod <vector>? ((obj <deque>))
  (declare (ignore obj))
  nil)

(defmethod make ((class (eql '<deque>)) &rest elements)
  "Create a new <deque> from ELEMENTS.
   (make '<deque>)       => empty deque
   (make '<deque> 1 2 3) => deque with 1 at front, 3 at back"
  (make-instance '<deque>
                 :items (if elements
                            (fset:convert 'fset:seq elements)
                            (fset:empty-seq))))

;; Protocol methods for <deque> — override vector's to produce <deque> instances

(defmethod collection-conj ((d <deque>) element)
  "Add ELEMENT to the back of the deque."
  (make-instance '<deque>
                 :items (fset:with-last (storage-items d) element)))

;;; ============================================================================
;;; List
;;; ============================================================================

(defclass <list> (<ordered-collection>)
  ((first-elem :initarg :first-elem
               :initform nil
               :reader list-first
               :documentation "The first element of this list, or NIL if empty.")
   (rest-list :initarg :rest-list
              :initform nil
              :reader list-rest
              :documentation "The rest of this list (another <list>), or NIL if empty.")
   (list-size :initarg :list-size
              :initform 0
              :reader list-size
              :type integer
              :documentation "The number of elements in this list.  O(1) access."))
  (:documentation "A persistent singly-linked list with O(1) size access.
                   Each node contains first (head), rest (tail), and cached size.
                   conj prepends (Clojure semantics)."))

(defgeneric <list>? (obj)
  (:documentation "Returns T if OBJ is a FOL <list>."))

(defmethod <list>? (obj)
  (declare (ignore obj))
  nil)

(defmethod <list>? ((obj <list>))
  (declare (ignore obj))
  t)

(defmethod make ((class (eql '<list>)) &rest elements)
  "Create a new <list> from ELEMENTS.
   (make '<list>)       => empty list
   (make '<list> 1 2 3) => list of 1, 2, 3"
  (if (null elements)
      (make-instance '<list>)
      ;; Build right-to-left so first element is at the head
      (let ((result (make-instance '<list>)))
        (dolist (elem (cl:reverse elements))
          (setf result (make-instance '<list>
                                      :first-elem elem
                                      :rest-list result
                                      :list-size (1+ (list-size result)))))
        result)))

;;; --- Protocol methods for <list> ---

(defmethod collection-size ((l <list>))
  (list-size l))

(defmethod collection-conj ((l <list>) element)
  "Prepend ELEMENT to the front of the list (Clojure semantics)."
  (make-instance '<list>
                 :first-elem element
                 :rest-list l
                 :list-size (1+ (list-size l))))

(defmethod collection-seq ((l <list>))
  "Walk the linked structure and collect elements into a CL list."
  (loop with current = l
        while (and current (plusp (list-size current)))
        collect (list-first current)
        do (setf current (list-rest current))))

;;; ============================================================================
;;; Lazy Seq
;;; ============================================================================

(defclass <lazy-seq> (<ordered-collection>)
  ((thunk :initarg :thunk
          :initform nil
          :accessor lazy-seq-thunk
          :documentation "A zero-argument function that produces the sequence.")
   (realized :initform nil
             :accessor lazy-seq-realized-p
             :type boolean
             :documentation "T if the thunk has been called and result cached.")
   (cached :initform nil
           :accessor lazy-seq-cached
           :documentation "The cached result after realization."))
  ;; Uses standard-class (not persistent-class) because lazy sequences
  ;; need to mutate their realized and cached slots.
  (:documentation "A lazy sequence that delays computation until needed.
                   Once realized, the result is cached for subsequent access."))

(defgeneric <lazy-seq>? (obj)
  (:documentation "Returns T if OBJ is a FOL <lazy-seq>."))

(defmethod <lazy-seq>? (obj)
  (declare (ignore obj))
  nil)

(defmethod <lazy-seq>? ((obj <lazy-seq>))
  (declare (ignore obj))
  t)

(defmethod make ((class (eql '<lazy-seq>)) &rest args)
  "Create a new <lazy-seq> from a thunk (zero-argument function).
   (make '<lazy-seq> thunk) => lazy sequence"
  (make-instance '<lazy-seq> :thunk (first args)))

(defun realize-lazy-seq (ls)
  "Force realization of a lazy sequence.  Returns the underlying sequence or NIL.
   If the thunk returns another <lazy-seq>, recursively realizes it."
  (unless (lazy-seq-realized-p ls)
    (let ((result (funcall (lazy-seq-thunk ls))))
      ;; Recursively realize chained lazy-seqs
      (loop while (typep result '<lazy-seq>)
            do (setf result (realize-lazy-seq result)))
      (setf (lazy-seq-cached ls) result)
      (setf (lazy-seq-realized-p ls) t)
      ;; Clear the thunk to allow GC
      (setf (lazy-seq-thunk ls) nil)))
  (lazy-seq-cached ls))

;;; --- Protocol methods for <lazy-seq> ---

(defmethod collection-size ((ls <lazy-seq>))
  "Fully realize, then count elements."
  (let ((realized (realize-lazy-seq ls)))
    (if realized
        (collection-size realized)
        0)))

(defmethod collection-conj ((ls <lazy-seq>) element)
  "Realize the lazy-seq, then prepend ELEMENT as a new <list> node."
  (let ((realized (realize-lazy-seq ls)))
    (if realized
        (collection-conj realized element)
        (make-instance '<list>
                       :first-elem element
                       :rest-list (make-instance '<list>)
                       :list-size 1))))

(defmethod collection-seq ((ls <lazy-seq>))
  "Fully realize, then return elements as a CL list."
  (let ((realized (realize-lazy-seq ls)))
    (if realized
        (collection-seq realized)
        nil)))


;;; ============================================================================
;;; print-object methods
;;; ============================================================================

(defun %write-fol-element (item stream)
  "Write a single FOL element to STREAM, respecting *print-escape*."
  (write item :stream stream))

(defmethod print-object ((obj <vector>) stream)
  (write-char #\[ stream)
  (let ((first-p t))
    (fset:do-seq (item (storage-items obj))
      (if first-p
          (setf first-p nil)
          (write-char #\Space stream))
      (%write-fol-element item stream)))
  (write-char #\] stream))

(defmethod print-object ((obj <dict>) stream)
  (write-char #\{ stream)
  (let ((first-p t))
    (dolist (pair (collection-seq obj))
      (if first-p
          (setf first-p nil)
          (write-char #\Space stream))
      (%write-fol-element (car pair) stream)
      (write-char #\Space stream)
      (%write-fol-element (cdr pair) stream)))
  (write-char #\} stream))

(defmethod print-object ((obj <priority-dict>) stream)
  (write-char #\{ stream)
  (let ((first-p t))
    (dolist (pair (collection-seq obj))
      (if first-p
          (setf first-p nil)
          (write-char #\Space stream))
      (%write-fol-element (car pair) stream)
      (write-char #\Space stream)
      (%write-fol-element (cdr pair) stream)))
  (write-char #\} stream))

(defmethod print-object ((obj <sorted-dict>) stream)
  (write-char #\{ stream)
  (let ((first-p t))
    (dolist (pair (collection-seq obj))
      (if first-p
          (setf first-p nil)
          (write-char #\Space stream))
      (%write-fol-element (car pair) stream)
      (write-char #\Space stream)
      (%write-fol-element (cdr pair) stream)))
  (write-char #\} stream))

(defmethod print-object ((obj <set>) stream)
  (write-string "#{" stream)
  (let ((first-p t))
    (dolist (elem (collection-seq obj))
      (if first-p
          (setf first-p nil)
          (write-char #\Space stream))
      (%write-fol-element elem stream)))
  (write-char #\} stream))

(defmethod print-object ((obj <bag>) stream)
  (write-string "#M{" stream)
  (let ((first-p t))
    (dolist (elem (collection-seq obj))
      (if first-p
          (setf first-p nil)
          (write-char #\Space stream))
      (%write-fol-element elem stream)))
  (write-char #\} stream))

(defmethod print-object ((obj <deque>) stream)
  (write-string "#Q[" stream)
  (let ((first-p t))
    (dolist (elem (collection-seq obj))
      (if first-p
          (setf first-p nil)
          (write-char #\Space stream))
      (%write-fol-element elem stream)))
  (write-char #\] stream))

(defmethod print-object ((obj <list>) stream)
  (write-char #\( stream)
  (let ((first-p t))
    (dolist (elem (collection-seq obj))
      (if first-p
          (setf first-p nil)
          (write-char #\Space stream))
      (%write-fol-element elem stream)))
  (write-char #\) stream))

(defmethod print-object ((obj <lazy-seq>) stream)
  (if (lazy-seq-realized-p obj)
      (let ((cached (lazy-seq-cached obj)))
        (if cached
            (print-object cached stream)
            (write-string "()" stream)))
      (write-string "#<lazy-seq unrealized>" stream)))