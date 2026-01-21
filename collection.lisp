(in-package fol.collection)

;;; ============================================================================
;;; Collection Classes - Option C (Hybrid Approach)
;;; ============================================================================
;;;
;;; Collections store raw CL values internally for efficiency.
;;; When retrieving elements, raw values are returned and can be used
;;; directly with FOL operations (which accept both raw and wrapped values).
;;;
;;; Key design decisions:
;;; - Internal storage uses raw CL primitives (no wrapper objects)
;;; - Retrieval returns raw values (use fol-type-of for type reflection)
;;; - Insertion accepts both raw and wrapped values (extracts raw via fol-value)
;;; - Wrap only when you need persistence metadata on an element

;;; ============================================================================
;;; Collection Base Class
;;; ============================================================================

(defclass <collection> (<persistent-object>)
  ()
  (:metaclass persistent-class)
  (:documentation "Abstract base class for all persistent collections.
                   Inherits storage capabilities from <persistent-object>."))

(defgeneric <collection>? (obj) (:documentation "Returns T if OBJ is a FOL <collection>."))
(defmethod <collection>? (obj) nil)
(defmethod <collection>? ((obj <collection>)) t)


;;; ============================================================================
;;; Unordered Collection Class (<unordered-collection>)
;;; ============================================================================

(defclass <unordered-collection> (<collection>)
  ()
  (:metaclass persistent-class)
  (:documentation "Abstract base class for all persistent unordered collections (sets, bags, maps)."))

(defgeneric <unordered-collection>? (obj) (:documentation "Returns T if OBJ is a FOL <unordered-collection>."))
(defmethod <unordered-collection>? (obj) nil)
(defmethod <unordered-collection>? ((obj <unordered-collection>)) t)


;;; ============================================================================
;;; Ordered Collection Class (<ordered-collection>)
;;; ============================================================================

(defclass <ordered-collection> (<collection>)
  ()
  (:metaclass persistent-class)
  (:documentation "Abstract base class for all persistent ordered collections (sequences)."))

(defgeneric <ordered-collection>? (obj) (:documentation "Returns T if OBJ is a FOL <ordered-collection>."))
(defmethod <ordered-collection>? (obj) nil)
(defmethod <ordered-collection>? ((obj <ordered-collection>)) t)


;;; ============================================================================
;;; Dictionary Class (<dict>)
;;; ============================================================================

(defclass <dict> (<unordered-collection>)
  ((items :initarg :items
          :initform (fset:empty-map)
          :documentation "The underlying FSet map holding the key-value pairs."))
  (:metaclass persistent-class)
  (:documentation "A persistent dictionary mapping keys to values."))

(defun make-dict (&rest pairs)
  "Create a new <dict> populated with the given key-value pairs.
   Values are stored as raw CL primitives (unwrapped)."
  (let ((map (fset:empty-map)))
    (loop for (key val) on pairs by #'cddr
          do (setf map (fset:with map
                                  (fol.wrappers:fol-value key)
                                  (fol.wrappers:fol-value val))))
    (make-instance '<dict> :items map)))

(defgeneric <dict>? (obj) (:documentation "Returns T if OBJ is a FOL <dict>."))
(defmethod <dict>? (obj) nil)
(defmethod <dict>? ((obj <dict>)) t)

(defmethod print-object ((obj <dict>) stream)
  (format stream "{")
  (let ((items (pslot-value obj 'items))
        (first t))
    (fset:do-map (key val items)
      (unless first (format stream " "))
      (setf first nil)
      (flet ((safe-print (item)
               (cond ((eq item t) (format stream "#t"))
                     ((eq item nil) (format stream "#f"))
                     ((keywordp item) (format stream "~S" item))
                     ((symbolp item)  (format stream "'~S" item))
                     (t (format stream "~S" item)))))
        (safe-print key)
        (format stream " ")
        (safe-print val))))
  (format stream "}"))


;;; ============================================================================
;;; Bag Class (<bag>)
;;; ============================================================================

(defclass <bag> (<dict>)
  ()
  (:metaclass persistent-class)
  (:documentation "A persistent bag (multiset) implemented as a dictionary where
                   keys are elements and values are their counts."))

(defun make-bag (&rest elements)
  "Create a new <bag> from the given elements.
   Elements are stored as raw CL primitives."
  (let ((map (fset:empty-map)))
    (dolist (item elements)
      (let* ((raw-item (fol.wrappers:fol-value item))
             (count (fset:lookup map raw-item)))
        (setf map (fset:with map raw-item (if count (1+ count) 1)))))
    (make-instance '<bag> :items map)))

(defgeneric <bag>? (obj) (:documentation "Returns T if OBJ is a FOL <bag>."))
(defmethod <bag>? (obj) nil)
(defmethod <bag>? ((obj <bag>)) t)

(defmethod print-object ((obj <bag>) stream)
  (format stream "#M{")
  (let ((items (pslot-value obj 'items))
        (first t))
    (fset:do-map (elem count items)
      (dotimes (i count)
        (unless first (format stream " "))
        (setf first nil)
        (cond ((eq elem t) (format stream "#t"))
              ((eq elem nil) (format stream "#f"))
              ((keywordp elem) (format stream "~S" elem))
              ((symbolp elem)  (format stream "'~S" elem))
              (t (format stream "~S" elem))))))
  (format stream "}"))


;;; ============================================================================
;;; Set Class (<set>)
;;; ============================================================================

(defclass <set> (<dict>)
  ()
  (:metaclass persistent-class)
  (:documentation "A persistent set implemented as a dictionary where keys are elements and values are T."))

(defun make-set (&rest elements)
  "Create a new <set> from the given elements.
   Elements are stored as raw CL primitives."
  (let ((map (fset:empty-map)))
    (dolist (item elements)
      (setf map (fset:with map (fol.wrappers:fol-value item) t)))
    (make-instance '<set> :items map)))

(defgeneric <set>? (obj) (:documentation "Returns T if OBJ is a FOL <set>."))
(defmethod <set>? (obj) nil)
(defmethod <set>? ((obj <set>)) t)

(defmethod print-object ((obj <set>) stream)
  (format stream "#{")
  (let ((items (pslot-value obj 'items))
        (first t))
    (fset:do-map (key val items)
      (declare (ignore val))
      (unless first (format stream " "))
      (setf first nil)
      (cond ((eq key t) (format stream "#t"))
            ((eq key nil) (format stream "#f"))
            ((keywordp key) (format stream "~S" key))
            ((symbolp key)  (format stream "'~S" key))
            (t (format stream "~S" key)))))
  (format stream "}"))


;;; ============================================================================
;;; Vector Class (<vector>)
;;; ============================================================================

(defclass <vector> (<ordered-collection>)
  ((items :initarg :items
          :initform (fset:empty-seq)
          :documentation "The underlying FSet sequence."))
  (:metaclass persistent-class)
  (:documentation "A persistent ordered vector implemented using FSet sequences."))

(defun make-vector (&rest elements)
  "Create a new <vector> from the given elements.
   Elements are stored as raw CL primitives."
  (make-instance '<vector>
                 :items (fset:convert 'fset:seq
                                      (mapcar #'fol.wrappers:fol-value elements))))

(defgeneric <vector>? (obj) (:documentation "Returns T if OBJ is a FOL <vector>."))
(defmethod <vector>? (obj) nil)
(defmethod <vector>? ((obj <vector>)) t)

(defmethod print-object ((obj <vector>) stream)
  (format stream "[")
  (let ((items (pslot-value obj 'items))
        (first t))
    (fset:do-seq (item items)
      (unless first (format stream " "))
      (setf first nil)
      (cond ((eq item t) (format stream "#t"))
            ((eq item nil) (format stream "#f"))
            ((keywordp item) (format stream "~S" item))
            ((symbolp item)  (format stream "'~S" item))
            (t (format stream "~S" item)))))
  (format stream "]"))


;;; ============================================================================
;;; Array Class (<array>)
;;; ============================================================================

(defclass <array> (<vector>)
  ((dimensions :initarg :dimensions
               :initform (make-vector)
               :documentation "A <vector> of positive integers defining the shape."))
  (:metaclass persistent-class)
  (:documentation "A multi-dimensional array stored as a flat vector."))

(defun make-array (dims &rest elements)
  "Create a new <array>.
   DIMS: A FOL <vector> of integers (e.g. [2 2]).
   ELEMENTS: The data to populate the array (flat sequence).
   Elements are stored as raw CL primitives."
  (make-instance '<array>
                 :dimensions dims
                 :items (fset:convert 'fset:seq
                                      (mapcar #'fol.wrappers:fol-value elements))))

(defgeneric <array>? (obj) (:documentation "Returns T if OBJ is a FOL <array>."))
(defmethod <array>? (obj) nil)
(defmethod <array>? ((obj <array>)) t)


;;; ============================================================================
;;; GENERIC GET (Shadows cl:get)
;;; ============================================================================

(defgeneric get (obj key &optional default)
  (:documentation "Retrieve element at KEY. Returns raw CL value.
   For arrays, KEY is a <vector> of indices.
   For dicts, KEY is any value.
   Returns DEFAULT if not found."))

(defmethod get ((dict <dict>) key &optional default)
  "Look up KEY in DICT and return the associated value, or DEFAULT if not found.
   KEY can be raw or wrapped; it's unwrapped for lookup."
  (multiple-value-bind (val found)
      (fset:lookup (pslot-value dict 'fol.collection::items)
                   (fol.wrappers:fol-value key))
    (if found val default)))

(defmethod get ((vec <vector>) (index integer) &optional default)
  "Get element at INDEX from vector. Returns raw value."
  (let ((seq (pslot-value vec 'items)))
    (if (and (>= index 0) (< index (fset:size seq)))
        (fset:lookup seq index)
        default)))

(defmethod get ((vec <vector>) (index fol.classes:<number>) &optional default)
  "Get element at INDEX from vector. INDEX can be wrapped."
  (get vec (fol.wrappers:fol-value index) default))

(defmethod get ((arr <array>) (indices <vector>) &optional default)
  "Get element from array at INDICES (a vector of integers)."
  (let* ((dim-seq (pslot-value (pslot-value arr 'dimensions) 'items))
         (idx-seq (pslot-value indices 'items))
         (dims (fset:convert 'list dim-seq))
         (idxs (fset:convert 'list idx-seq)))

    ;; Check Rank (Number of indices must match number of dimensions)
    (unless (= (length dims) (length idxs))
      (return-from get default))

    ;; Calculate Flat Index (Column Major Order)
    (let ((flat-index 0)
          (multiplier 1)
          (valid t))

      (loop for i in idxs
            for d in dims
            do (if (or (< i 0) (>= i d))
                   (setf valid nil)
                   (progn
                     (incf flat-index (* i multiplier))
                     (setf multiplier (* multiplier d)))))

      (if (not valid)
          default
          (let ((val (fset:lookup (pslot-value arr 'items) flat-index)))
            (or val default))))))


;;; ============================================================================
;;; GENERIC COLLECTION PROTOCOLS
;;; ============================================================================

;;; 1. SIZE
(defgeneric size (collection)
  (:documentation "Returns the number of elements in the collection."))

(defmethod size ((c <collection>))
  (fset:size (pslot-value c 'items)))

;;; 2. EMPTY?
(defgeneric empty? (collection)
  (:documentation "Returns T if the collection is empty, NIL otherwise."))

(defmethod empty? ((c <collection>))
  (if (fset:empty? (pslot-value c 'items))
      t
      nil))

;;; 3. CONTAINS?
(defgeneric contains? (collection item)
  (:documentation "Returns T if ITEM is in COLLECTION.
   ITEM can be raw or wrapped; it's unwrapped for comparison."))

(defmethod contains? ((c <unordered-collection>) item)
  (multiple-value-bind (val found)
      (fset:lookup (pslot-value c 'items) (fol.wrappers:fol-value item))
    (declare (ignore val))
    (if found t nil)))

(defmethod contains? ((v <vector>) item)
  (let* ((raw-item (fol.wrappers:fol-value item))
         (seq (pslot-value v 'items))
         (as-list (fset:convert 'list seq)))
    (if (cl:position raw-item as-list :test #'equal)
        t
        nil)))

;;; 4. ADD (Functional Insertion)
(defgeneric add (collection item &optional value)
  (:documentation "Returns a new collection with ITEM added.
   ITEM and VALUE are unwrapped before storage."))

(defmethod add ((d <dict>) key &optional value)
  (unless value (error "Adding to a <dict> requires a value."))
  (let ((new-map (fset:with (pslot-value d 'items)
                            (fol.wrappers:fol-value key)
                            (fol.wrappers:fol-value value))))
    (make-instance (class-of d) :items new-map)))

(defmethod add ((s <set>) item &optional value)
  (declare (ignore value))
  (let ((new-map (fset:with (pslot-value s 'items)
                            (fol.wrappers:fol-value item) t)))
    (make-instance (class-of s) :items new-map)))

(defmethod add ((b <bag>) item &optional value)
  (declare (ignore value))
  (let* ((raw-item (fol.wrappers:fol-value item))
         (map (pslot-value b 'items))
         (count (or (fset:lookup map raw-item) 0)))
    (make-instance (class-of b) :items (fset:with map raw-item (1+ count)))))

(defmethod add ((v <vector>) item &optional value)
  (declare (ignore value))
  (let ((new-seq (fset:with-last (pslot-value v 'items)
                                 (fol.wrappers:fol-value item))))
    (make-instance (class-of v) :items new-seq)))

(defmethod add ((a <array>) item &optional value)
  (declare (ignore item value))
  (error "Cannot add elements to fixed-dimension <array>."))

;;; 5. REMOVE (Functional Deletion)
(defgeneric remove (collection item)
  (:documentation "Returns a new collection with ITEM removed.
   ITEM is unwrapped before comparison."))

(defmethod remove ((d <dict>) key)
  (make-instance (class-of d)
                 :items (fset:less (pslot-value d 'items)
                                   (fol.wrappers:fol-value key))))

(defmethod remove ((s <set>) item)
  (make-instance (class-of s)
                 :items (fset:less (pslot-value s 'items)
                                   (fol.wrappers:fol-value item))))

(defmethod remove ((b <bag>) item)
  (let* ((raw-item (fol.wrappers:fol-value item))
         (map (pslot-value b 'items))
         (count (fset:lookup map raw-item)))
    (cond
      ((null count) b)
      ((<= count 1) (make-instance (class-of b) :items (fset:less map raw-item)))
      (t (make-instance (class-of b) :items (fset:with map raw-item (1- count)))))))

(defmethod remove ((v <vector>) item)
  (let* ((raw-item (fol.wrappers:fol-value item))
         (seq (pslot-value v 'items))
         (as-list (fset:convert 'list seq))
         (idx (cl:position raw-item as-list :test #'equal)))
    (if idx
        (make-instance (class-of v) :items (fset:less seq idx))
        v)))

;;; 6. ITERATOR PROTOCOL

(defclass <list-iterator> ()
  ((items :initarg :items :accessor iter-items))
  (:documentation "A mutable iterator wrapping a standard Lisp list."))

(defgeneric iterator (collection)
  (:documentation "Returns an iterator for the collection."))

(defmethod iterator ((c <collection>))
  (make-instance '<list-iterator>
                 :items (fset:convert 'list (pslot-value c 'items))))

(defgeneric next (iterator)
  (:documentation "Advances the iterator."))

(defmethod next ((iter <list-iterator>))
  (setf (iter-items iter) (cdr (iter-items iter)))
  iter)

(defgeneric current (iterator)
  (:documentation "Returns the current element/key of the iterator (raw value)."))

(defmethod current ((iter <list-iterator>))
  (car (iter-items iter)))

(defgeneric done? (iterator)
  (:documentation "Returns T if the iterator is exhausted."))

(defmethod done? ((iter <list-iterator>))
  (if (null (iter-items iter))
      t
      nil))


;;; ============================================================================
;;; Additional Collection Operations
;;; ============================================================================

(defgeneric nth-element (collection n)
  (:documentation "Get the Nth element from an ordered collection.
   Returns raw value. N can be raw or wrapped."))

(defmethod nth-element ((v <vector>) (n integer))
  (get v n nil))

(defmethod nth-element ((v <vector>) (n fol.classes:<number>))
  (get v (fol.wrappers:fol-value n) nil))

(defgeneric set-nth (collection n value)
  (:documentation "Returns a new collection with element at N replaced by VALUE.
   N and VALUE are unwrapped before use."))

(defmethod set-nth ((v <vector>) (n integer) value)
  (let* ((seq (pslot-value v 'items))
         (raw-value (fol.wrappers:fol-value value)))
    (if (and (>= n 0) (< n (fset:size seq)))
        (make-instance (class-of v)
                       :items (fset:with seq n raw-value))
        (error "Index ~A out of bounds for vector of size ~A" n (fset:size seq)))))

(defmethod set-nth ((v <vector>) (n fol.classes:<number>) value)
  (set-nth v (fol.wrappers:fol-value n) value))
