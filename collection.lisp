(in-package fol.collection)

;;; ============================================================================
;;; Collection Base Class
;;; ============================================================================

(defclass <collection> (<persistent-object>)
  ()
  (:metaclass persistent-class)
  (:documentation "Abstract base class for all persistent collections.
                   Inherits storage capabilities from <persistent-object>."))
  
(defgeneric <collection>? (obj) (:documentation "Returns T if OBJ is a FOL <collection>."))
(defmethod <collection>? (obj) (return-f))
(defmethod <collection>? ((obj <collection>)) (return-t))


;;; ============================================================================
;;; Unordered Collection Class (<unordered-collection>)
;;; ============================================================================

(defclass <unordered-collection> (<collection>)
  ()
  (:metaclass persistent-class)
  (:documentation "Abstract base class for all persistent unordered collections (sets, bags, maps)."))

(defgeneric <unordered-collection>? (obj) (:documentation "Returns T if OBJ is a FOL <unordered-collection>."))
(defmethod <unordered-collection>? (obj) (return-f))
(defmethod <unordered-collection>? ((obj <unordered-collection>)) (return-t))


;;; ============================================================================
;;; Ordered Collection Class (<ordered-collection>)
;;; ============================================================================

(defclass <ordered-collection> (<collection>)
  ()
  (:metaclass persistent-class)
  (:documentation "Abstract base class for all persistent ordered collections (sequences)."))

(defgeneric <ordered-collection>? (obj) (:documentation "Returns T if OBJ is a FOL <ordered-collection>."))
(defmethod <ordered-collection>? (obj) (return-f))
(defmethod <ordered-collection>? ((obj <ordered-collection>)) (return-t))


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
  "Create a new <dict> populated with the given key-value pairs."
  (let ((map (fset:empty-map)))
    (loop for (key val) on pairs by #'cddr
          do (setf map (fset:with map key val)))
    (make-instance '<dict> :items map)))

(defgeneric <dict>? (obj) (:documentation "Returns T if OBJ is a FOL <dict>."))
(defmethod <dict>? (obj) (return-f))
(defmethod <dict>? ((obj <dict>)) (return-t))

(defmethod print-object ((obj <dict>) stream)
  (format stream "{")
  (let ((items (pslot-value obj 'items))
        (first t))
    (fset:do-map (key val items)
      (unless first (format stream " "))
      (setf first nil)
      (flet ((safe-print (item)
               (cond ((eq item fol.singleton:*true-instance*) (format stream "#t"))
                     ((eq item fol.singleton:*false-instance*) (format stream "#f"))
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
  "Create a new <bag> from the given elements."
  (let ((map (fset:empty-map)))
    (dolist (item elements)
      (let ((count (fset:lookup map item)))
        (setf map (fset:with map item (if count (1+ count) 1)))))
    (make-instance '<bag> :items map)))

(defgeneric <bag>? (obj) (:documentation "Returns T if OBJ is a FOL <bag>."))
(defmethod <bag>? (obj) (return-f))
(defmethod <bag>? ((obj <bag>)) (return-t))

(defmethod print-object ((obj <bag>) stream)
  (format stream "#M{")
  (let ((items (pslot-value obj 'items))
        (first t))
    (fset:do-map (elem count items)
      (dotimes (i count)
        (unless first (format stream " "))
        (setf first nil)
        (cond ((eq elem fol.singleton:*true-instance*) (format stream "#t"))
              ((eq elem fol.singleton:*false-instance*) (format stream "#f"))
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
  "Create a new <set> from the given elements. Stores elements as keys with T values."
  (let ((map (fset:empty-map)))
    (dolist (item elements)
      (setf map (fset:with map item t)))
    (make-instance '<set> :items map)))

(defgeneric <set>? (obj) (:documentation "Returns T if OBJ is a FOL <set>."))
(defmethod <set>? (obj) (return-f))
(defmethod <set>? ((obj <set>)) (return-t))

(defmethod print-object ((obj <set>) stream)
  (format stream "#{")
  (let ((items (pslot-value obj 'items))
        (first t))
    (fset:do-map (key val items)
      (declare (ignore val)) 
      (unless first (format stream " "))
      (setf first nil)
      (cond ((eq key fol.singleton:*true-instance*) (format stream "#t"))
            ((eq key fol.singleton:*false-instance*) (format stream "#f"))
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
  "Create a new <vector> from the given elements."
  (make-instance '<vector> :items (fset:convert 'fset:seq elements)))

(defgeneric <vector>? (obj) (:documentation "Returns T if OBJ is a FOL <vector>."))
(defmethod <vector>? (obj) (return-f))
(defmethod <vector>? ((obj <vector>)) (return-t))

(defmethod print-object ((obj <vector>) stream)
  (format stream "[")
  (let ((items (pslot-value obj 'items))
        (first t))
    (fset:do-seq (item items)
      (unless first (format stream " "))
      (setf first nil)
      (cond ((eq item fol.singleton:*true-instance*) (format stream "#t"))
            ((eq item fol.singleton:*false-instance*) (format stream "#f"))
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
   ELEMENTS: The data to populate the array (flat sequence)."
  (make-instance '<array> 
                 :dimensions dims 
                 :items (fset:convert 'fset:seq elements)))

(defgeneric <array>? (obj) (:documentation "Returns T if OBJ is a FOL <array>."))
(defmethod <array>? (obj) (return-f))
(defmethod <array>? ((obj <array>)) (return-t))

;;; GENERIC GET (Shadows cl:get)
(defgeneric get (obj indices &optional default)
  (:documentation "Retrieve element at INDICES (a <vector>). Returns DEFAULT if out of bounds."))

(defmethod get ((arr <array>) (indices <vector>) &optional default)
  (let* ((dim-seq (pslot-value (pslot-value arr 'dimensions) 'items))
         (idx-seq (pslot-value indices 'items))
         (dims (fset:convert 'list dim-seq))
         (idxs (fset:convert 'list idx-seq)))
    
    ;; Check Rank (Number of indices must match number of dimensions)
    (unless (= (length dims) (length idxs))
      (return-from get default))
    
    ;; Calculate Flat Index (Column Major Order)
    ;;    Formula: i1 + d1 * (i2 + d2 * (i3 + ...))
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
          ;; 3. Retrieve from storage (inherited 'items' slot from <vector>)
          (let ((val (fset:lookup (pslot-value arr 'items) flat-index)))
            ;; fset:lookup returns nil if index is missing in sparse seq
            (or val default))))))





;;; ============================================================================
;;; GENERIC COLLECTION PROTOCOLS
;;; ============================================================================

;;; 1. SIZE
(defgeneric size (collection)
  (:documentation "Returns the number of elements in the collection."))

(defmethod size ((c <collection>) )
  (fset:size (pslot-value c 'items)))

;;; 2. EMPTY?
(defgeneric empty? (collection)
  (:documentation "Returns #t if the collection is empty, #f otherwise."))

(defmethod empty? ((c <collection>))
  (if (fset:empty? (pslot-value c 'items))
      (return-t)
      (return-f)))

;;; 3. CONTAINS?
(defgeneric contains? (collection item)
  (:documentation "Returns #t if ITEM is in COLLECTION."))

(defmethod contains? ((c <unordered-collection>) item)
  ;; For sets/bags/dicts, simple lookup.
  (multiple-value-bind (val found) (fset:lookup (pslot-value c 'items) item)
    (declare (ignore val))
    (if found (return-t) (return-f))))

(defmethod contains? ((v <vector>) item)
  ;; Convert FSet sequence to list and use CL:POSITION
  ;; FSet doesn't provide a position function for sequences
  (let* ((seq (pslot-value v 'items))
         (as-list (fset:convert 'list seq)))
    (if (cl:position item as-list :test #'equal)
        (return-t)
        (return-f))))

;;; 4. ADD (Functional Insertion)
(defgeneric add (collection item &optional value)
  (:documentation "Returns a new collection with ITEM added."))

(defmethod add ((d <dict>) key &optional value)
  (unless value (error "Adding to a <dict> requires a value."))
  (let ((new-map (fset:with (pslot-value d 'items) key value)))
    (make-instance (class-of d) :items new-map)))

(defmethod add ((s <set>) item &optional value)
  (declare (ignore value))
  (let ((new-map (fset:with (pslot-value s 'items) item t)))
    (make-instance (class-of s) :items new-map)))

(defmethod add ((b <bag>) item &optional value)
  (declare (ignore value))
  (let* ((map (pslot-value b 'items))
         (count (or (fset:lookup map item) 0)))
    (make-instance (class-of b) :items (fset:with map item (1+ count)))))

(defmethod add ((v <vector>) item &optional value)
  (declare (ignore value))
  (let ((new-seq (fset:with-last (pslot-value v 'items) item)))
    (make-instance (class-of v) :items new-seq)))

(defmethod add ((a <array>) item &optional value)
  (declare (ignore item value))
  (error "Cannot add elements to fixed-dimension <array>."))

;;; 5. REMOVE (Functional Deletion)
(defgeneric remove (collection item)
  (:documentation "Returns a new collection with ITEM removed."))

(defmethod remove ((d <dict>) key)
  (make-instance (class-of d) :items (fset:less (pslot-value d 'items) key)))

(defmethod remove ((s <set>) item)
  (make-instance (class-of s) :items (fset:less (pslot-value s 'items) item)))

(defmethod remove ((b <bag>) item)
  (let* ((map (pslot-value b 'items))
         (count (fset:lookup map item)))
    (cond
      ((null count) b)
      ((<= count 1) (make-instance (class-of b) :items (fset:less map item)))
      (t (make-instance (class-of b) :items (fset:with map item (1- count)))))))

(defmethod remove ((v <vector>) item)
  (let* ((seq (pslot-value v 'items))
         (as-list (fset:convert 'list seq))
         (idx (cl:position item as-list :test #'equal)))
    (if idx
        (make-instance (class-of v) :items (fset:less seq idx))
        v)))

;;; 6. ITERATOR PROTOCOL
;;; We implement this using a simple List Iterator helper class
;;; because FSet's internal iterator API is not strictly standardized/exported.

(defclass <list-iterator> ()
  ((items :initarg :items :accessor iter-items))
  (:documentation "A mutable iterator wrapping a standard Lisp list."))

(defgeneric iterator (collection)
  (:documentation "Returns an iterator for the collection."))

(defmethod iterator ((c <collection>))
  ;; Convert FSet collection to a standard list
  ;; - Maps become alists: ((k . v) ...)
  ;; - Sets/Seqs become lists: (e1 e2 ...)
  (make-instance '<list-iterator> 
                 :items (fset:convert 'list (pslot-value c 'items))))

(defgeneric next (iterator)
  (:documentation "Advances the iterator."))

(defmethod next ((iter <list-iterator>))
  (setf (iter-items iter) (cdr (iter-items iter)))
  iter)

(defgeneric current (iterator)
  (:documentation "Returns the current element/key of the iterator."))

(defmethod current ((iter <list-iterator>))
  (car (iter-items iter)))

(defgeneric done? (iterator)
  (:documentation "Returns #t if the iterator is exhausted."))

(defmethod done? ((iter <list-iterator>))
  (if (null (iter-items iter))
      (return-t)
      (return-f)))