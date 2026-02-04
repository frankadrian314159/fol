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
(defun %dict-key (key)
  "Unwrap a key for dict storage. Collections are unwrapped to their storage."
  (let ((unwrapped (fol.wrappers:fol-value key)))
    (if (typep unwrapped '<persistent-object>)
        (fol.persistent:%persistent-storage unwrapped)
        unwrapped)))

(defun make-dict (&rest pairs)
  "Create a new <dict> populated with the given key-value pairs.
   Values are stored as raw CL primitives (unwrapped)."
  (let ((map (fset:empty-map)))
    (loop for (key val) on pairs by #'cddr
          do (setf map (fset:with map
                                  (%dict-key key)
                                  (fol.wrappers:fol-value val))))
    (make-instance '<dict> :items map)))

(defgeneric <dict>? (obj) (:documentation "Returns T if OBJ is a FOL <dict> or dict subclass (but not <set> or <bag>)."))
(defmethod <dict>? (obj) nil)
(defmethod <dict>? ((obj <dict>))
  ;; Return true for <dict> and dict subclasses
  ;; Specific methods for <set> and <bag> return nil
  t)

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

;; <bag> is not a <dict> for type predicate purposes
(defmethod <dict>? ((obj <bag>)) nil)

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

;; <set> is not a <dict> for type predicate purposes
(defmethod <dict>? ((obj <set>)) nil)

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
;;; Sorted Set Class (<sorted-set>)
;;; ============================================================================
;;; A persistent sorted set maintaining elements in natural sorted order.
;;; Uses FSet's weight-balanced set (wb-set) for O(log n) operations.

(defclass <sorted-set> (<set> <ordered-collection>)
  ((items :initarg :items
          :initform (fset:empty-set)
          :documentation "An FSet wb-set for sorted storage."))
  (:metaclass persistent-class)
  (:documentation "A persistent sorted set maintaining elements in natural sorted order."))

(defun make-sorted-set (&rest elements)
  "Create a new <sorted-set> from the given elements.
   Elements are stored in sorted order."
  (let ((set (fset:empty-set)))
    (dolist (item elements)
      (setf set (fset:with set (fol.wrappers:fol-value item))))
    (make-instance '<sorted-set> :items set)))

(defgeneric <sorted-set>? (obj) (:documentation "Returns T if OBJ is a FOL <sorted-set>."))
(defmethod <sorted-set>? (obj) nil)
(defmethod <sorted-set>? ((obj <sorted-set>)) t)

(defmethod print-object ((obj <sorted-set>) stream)
  "Print sorted set as #S{elem1 elem2 ...} in sorted order."
  (format stream "#S{")
  (let ((first t))
    (fset:do-set (item (pslot-value obj 'items))
      (unless first (format stream " "))
      (setf first nil)
      (cond ((eq item t) (format stream "#t"))
            ((eq item nil) (format stream "#f"))
            ((keywordp item) (format stream "~S" item))
            ((symbolp item)  (format stream "'~S" item))
            (t (format stream "~S" item)))))
  (format stream "}"))


;;; ============================================================================
;;; Ordered Set Class (<ordered-set>)
;;; ============================================================================
;;; A persistent set maintaining insertion order.
;;; Uses dual structure: map for O(1) membership, seq for insertion order.

(defclass <ordered-set> (<set> <ordered-collection>)
  ((items :initarg :items
          :initform (fset:empty-map)
          :documentation "FSet map for O(1) membership testing.")
   (order :initarg :order
          :initform (fset:empty-seq)
          :documentation "FSet seq maintaining insertion order."))
  (:metaclass persistent-class)
  (:documentation "A persistent set maintaining insertion order."))

(defun make-ordered-set (&rest elements)
  "Create a new <ordered-set> from the given elements.
   Elements are maintained in insertion order, duplicates ignored."
  (let ((map (fset:empty-map))
        (seq (fset:empty-seq)))
    (dolist (item elements)
      (let ((raw (fol.wrappers:fol-value item)))
        (multiple-value-bind (val found) (fset:lookup map raw)
          (declare (ignore val))
          (unless found
            (setf map (fset:with map raw t))
            (setf seq (fset:with-last seq raw))))))
    (make-instance '<ordered-set> :items map :order seq)))

(defgeneric <ordered-set>? (obj) (:documentation "Returns T if OBJ is a FOL <ordered-set>."))
(defmethod <ordered-set>? (obj) nil)
(defmethod <ordered-set>? ((obj <ordered-set>)) t)

(defmethod print-object ((obj <ordered-set>) stream)
  "Print ordered set as #O{elem1 elem2 ...} in insertion order."
  (format stream "#O{")
  (let ((first t))
    (fset:do-seq (item (pslot-value obj 'order))
      (unless first (format stream " "))
      (setf first nil)
      (cond ((eq item t) (format stream "#t"))
            ((eq item nil) (format stream "#f"))
            ((keywordp item) (format stream "~S" item))
            ((symbolp item)  (format stream "'~S" item))
            (t (format stream "~S" item)))))
  (format stream "}"))


;;; ============================================================================
;;; Integer Set Class (<int-set>)
;;; ============================================================================
;;; A persistent sorted set optimized for integers.

(defclass <int-set> (<sorted-set>)
  ()
  (:metaclass persistent-class)
  (:documentation "A persistent sorted set optimized for integers."))

(defun make-int-set (&rest elements)
  "Create a new <int-set> from the given integer elements.
   Signals an error if any element is not an integer."
  (let ((set (fset:empty-set)))
    (dolist (item elements)
      (let ((raw (fol.wrappers:fol-value item)))
        (unless (integerp raw)
          (error "INT-SET only accepts integers, got ~S" raw))
        (setf set (fset:with set raw))))
    (make-instance '<int-set> :items set)))

(defgeneric <int-set>? (obj) (:documentation "Returns T if OBJ is a FOL <int-set>."))
(defmethod <int-set>? (obj) nil)
(defmethod <int-set>? ((obj <int-set>)) t)

;; <int-set> inherits print-object from <sorted-set>


;;; ============================================================================
;;; Sorted Set By Class (<sorted-set-by>)
;;; ============================================================================
;;; A persistent sorted set with a custom comparator function.
;;; Elements are maintained in order determined by the comparator.

(defclass <sorted-set-by> (<sorted-set>)
  ((comparator :initarg :comparator
               :initform #'cl:<
               :documentation "Comparator function for ordering elements.")
   (elements :initarg :elements
             :initform nil
             :documentation "Sorted list of elements."))
  (:metaclass persistent-class)
  (:documentation "A persistent sorted set with a custom comparator."))

(defun sorted-set-by (comparator &rest elements)
  "Create a new <sorted-set-by> with the given COMPARATOR.
   COMPARATOR should be a function of two arguments that returns true
   if the first argument should come before the second.
   Elements are stored in sorted order according to the comparator."
  (let ((sorted-elems nil)
        (seen (make-hash-table :test 'equal)))
    ;; Add elements one by one, maintaining sort order and removing duplicates
    (dolist (item elements)
      (let ((raw (fol.wrappers:fol-value item)))
        (unless (gethash raw seen)
          (setf (gethash raw seen) t)
          ;; Insert in sorted position
          (if (null sorted-elems)
              (setf sorted-elems (list raw))
              (if (funcall comparator raw (car sorted-elems))
                  (setf sorted-elems (cons raw sorted-elems))
                  (let ((prev sorted-elems))
                    (loop while (and (cdr prev)
                                     (not (funcall comparator raw (cadr prev))))
                          do (setf prev (cdr prev)))
                    (setf (cdr prev) (cons raw (cdr prev)))))))))
    (make-instance '<sorted-set-by>
                   :comparator comparator
                   :elements sorted-elems
                   ;; Use empty fset for compatibility with parent class
                   :items (fset:empty-set))))

(defgeneric <sorted-set-by>? (obj) (:documentation "Returns T if OBJ is a FOL <sorted-set-by>."))
(defmethod <sorted-set-by>? (obj) nil)
(defmethod <sorted-set-by>? ((obj <sorted-set-by>)) t)

(defmethod print-object ((obj <sorted-set-by>) stream)
  "Print sorted-set-by as #S<cmp>{elem1 elem2 ...}."
  (format stream "#S<cmp>{")
  (let ((first t))
    (dolist (item (pslot-value obj 'elements))
      (unless first (format stream " "))
      (setf first nil)
      (cond ((eq item t) (format stream "#t"))
            ((eq item nil) (format stream "#f"))
            ((keywordp item) (format stream "~S" item))
            ((symbolp item)  (format stream "'~S" item))
            (t (format stream "~S" item)))))
  (format stream "}"))


;;; ============================================================================
;;; Dense Integer Set Class (<dense-int-set>)
;;; ============================================================================
;;; A persistent set optimized for dense integer ranges using bit vectors.
;;; Efficient when integers are clustered within a known range.

(defclass <dense-int-set> (<ordered-collection>)
  ((base :initarg :base
         :initform 0
         :documentation "The base (minimum) integer of the range.")
   (bits :initarg :bits
         :initform (cl:make-array 0 :element-type 'bit)
         :documentation "Bit vector representing membership."))
  (:metaclass persistent-class)
  (:documentation "A persistent set optimized for dense integer ranges using bit vectors."))

(defun make-dense-int-set (min-val max-val &rest elements)
  "Create a new <dense-int-set> spanning [min-val, max-val].
   Elements must be integers within the specified range."
  (unless (and (integerp min-val) (integerp max-val))
    (error "DENSE-INT-SET requires integer bounds, got ~S and ~S" min-val max-val))
  (unless (<= min-val max-val)
    (error "DENSE-INT-SET min (~A) must be <= max (~A)" min-val max-val))
  (let* ((range-size (1+ (- max-val min-val)))
         (bits (cl:make-array range-size :element-type 'bit :initial-element 0)))
    (dolist (item elements)
      (let ((raw (fol.wrappers:fol-value item)))
        (unless (integerp raw)
          (error "DENSE-INT-SET only accepts integers, got ~S" raw))
        (unless (<= min-val raw max-val)
          (error "Integer ~A is outside range [~A, ~A]" raw min-val max-val))
        (setf (aref bits (- raw min-val)) 1)))
    (make-instance '<dense-int-set> :base min-val :bits bits)))

(defgeneric <dense-int-set>? (obj) (:documentation "Returns T if OBJ is a FOL <dense-int-set>."))
(defmethod <dense-int-set>? (obj) nil)
(defmethod <dense-int-set>? ((obj <dense-int-set>)) t)

(defmethod print-object ((obj <dense-int-set>) stream)
  "Print dense-int-set as #D{elem1 elem2 ...} in ascending order."
  (format stream "#D{")
  (let ((base (pslot-value obj 'base))
        (bits (pslot-value obj 'bits))
        (first t))
    (loop for i from 0 below (length bits)
          when (= 1 (aref bits i))
          do (unless first (format stream " "))
             (setf first nil)
             (format stream "~D" (+ base i))))
  (format stream "}"))


;;; ============================================================================
;;; Array Dictionary Class (<array-dict>)
;;; ============================================================================
;;; A persistent dictionary maintaining insertion order with a size limit.
;;; Uses dual structure: map for O(1) lookup, seq for insertion order.
;;; Limited to 1000 entries.

(defclass <array-dict> (<dict> <ordered-collection>)
  ((items :initarg :items
          :initform (fset:empty-map)
          :documentation "FSet map for O(1) lookup.")
   (order :initarg :order
          :initform (fset:empty-seq)
          :documentation "FSet seq maintaining insertion order.")
   (max-size :initarg :max-size
             :initform 1000
             :documentation "Maximum number of entries allowed."))
  (:metaclass persistent-class)
  (:documentation "A persistent dictionary maintaining insertion order, with configurable size limit."))

(defun %make-array-dict-internal (max-size pairs)
  "Internal helper to create array-dict with specified max-size."
  (let ((map (fset:empty-map))
        (seq (fset:empty-seq)))
    (loop for (key val) on pairs by #'cddr
          do (let ((raw-key (fol.wrappers:fol-value key))
                   (raw-val (fol.wrappers:fol-value val)))
               (multiple-value-bind (old-val found) (fset:lookup map raw-key)
                 (declare (ignore old-val))
                 (unless found
                   (when (>= (fset:size seq) max-size)
                     (error "ARRAY-DICT size limit exceeded: cannot add more than ~D entries" max-size))
                   (setf seq (fset:with-last seq raw-key)))
                 (setf map (fset:with map raw-key raw-val)))))
    (make-instance '<array-dict> :items map :order seq :max-size max-size)))

(defun make-array-dict (&rest pairs)
  "Create a new <array-dict> from key-value pairs.
   Maintains insertion order. Limited to 1000 entries by default.
   Signals an error if size limit is exceeded.

   For custom max-size, use array-dict-with-limit."
  (%make-array-dict-internal 1000 pairs))

(defun array-dict (&rest pairs)
  "Create a new <array-dict> from key-value pairs with default max-size of 1000.
   Alias for make-array-dict."
  (apply #'make-array-dict pairs))

(defun array-dict-with-limit (max-size &rest pairs)
  "Create a new <array-dict> from key-value pairs with custom MAX-SIZE limit.

   Usage: (array-dict-with-limit 500 key1 val1 key2 val2 ...)"
  (%make-array-dict-internal max-size pairs))

(defgeneric <array-dict>? (obj) (:documentation "Returns T if OBJ is a FOL <array-dict>."))
(defmethod <array-dict>? (obj) nil)
(defmethod <array-dict>? ((obj <array-dict>)) t)

(defmethod print-object ((obj <array-dict>) stream)
  "Print array-dict as {|k1 v1 k2 v2|} in insertion order."
  (format stream "{|")
  (let ((first t))
    (fset:do-seq (key (pslot-value obj 'order))
      (unless first (format stream " "))
      (setf first nil)
      (let ((val (fset:lookup (pslot-value obj 'items) key)))
        (flet ((safe-print (item)
                 (cond ((eq item t) (format stream "#t"))
                       ((eq item nil) (format stream "#f"))
                       ((keywordp item) (format stream "~S" item))
                       ((symbolp item)  (format stream "'~S" item))
                       (t (format stream "~S" item)))))
          (safe-print key)
          (format stream " ")
          (safe-print val)))))
  (format stream "|}"))


;;; ============================================================================
;;; Helper: Generic Comparator for Sorted Collections
;;; ============================================================================

(defun generic-compare (a b)
  "Generic three-way comparison function for SYCAMORE tree-map.
   Returns -1 if a < b, 0 if a = b, 1 if a > b.
   Numbers are compared numerically, symbols and keywords by name,
   strings lexicographically, and other types by their printed representation."
  (cond
    ;; Both numbers - use numeric comparison
    ((and (realp a) (realp b))
     (cond ((cl:< a b) -1)
           ((cl:> a b) 1)
           (t 0)))
    ;; Both symbols/keywords - compare by name
    ((and (or (symbolp a) (keywordp a))
          (or (symbolp b) (keywordp b)))
     (let ((name-a (symbol-name a))
           (name-b (symbol-name b)))
       (cond ((cl:string< name-a name-b) -1)
             ((cl:string> name-a name-b) 1)
             (t 0))))
    ;; Both strings - lexicographic comparison
    ((and (stringp a) (stringp b))
     (cond ((cl:string< a b) -1)
           ((cl:string> a b) 1)
           (t 0)))
    ;; Mixed types - compare by type name first, then by printed representation
    (t
     (let* ((type-a (type-of a))
            (type-b (type-of b))
            (type-name-a (symbol-name type-a))
            (type-name-b (symbol-name type-b)))
       (cond ((cl:string< type-name-a type-name-b) -1)
             ((cl:string> type-name-a type-name-b) 1)
             (t (let ((str-a (princ-to-string a))
                      (str-b (princ-to-string b)))
                  (cond ((cl:string< str-a str-b) -1)
                        ((cl:string> str-a str-b) 1)
                        (t 0)))))))))

;;; ============================================================================
;;; Sorted Dictionary Class (<sorted-dict>)
;;; ============================================================================
;;; A persistent dictionary maintaining keys in sorted order.
;;; Uses SYCAMORE tree-map for O(log n) operations and better performance.

(defclass <sorted-dict> (<dict> <ordered-collection>)
  ((items :initarg :items
          :initform (sycamore:make-tree-map #'generic-compare)
          :documentation "SYCAMORE tree-map for sorted storage."))
  (:metaclass persistent-class)
  (:documentation "A persistent dictionary maintaining keys in sorted order."))

(defun make-sorted-dict (&rest pairs)
  "Create a new <sorted-dict> from key-value pairs.
   Keys are maintained in sorted order using the default comparator."
  (let ((tree (sycamore:make-tree-map #'generic-compare)))
    (loop for (key val) on pairs by #'cddr
          do (setf tree (sycamore:tree-map-insert tree
                                                   (fol.wrappers:fol-value key)
                                                   (fol.wrappers:fol-value val))))
    (make-instance '<sorted-dict> :items tree)))

(defun sorted-dict (&rest pairs)
  "Create a new <sorted-dict> from key-value pairs.
   Alias for make-sorted-dict."
  (apply #'make-sorted-dict pairs))

(defun sorted-dict-by (comparator &rest pairs)
  "Create a new <sorted-dict> with a custom COMPARATOR function.
   COMPARATOR should be a function of two arguments that returns true
   if the first argument should come before the second."
  (let ((tree (sycamore:make-tree-map comparator)))
    (loop for (key val) on pairs by #'cddr
          do (setf tree (sycamore:tree-map-insert tree
                                                   (fol.wrappers:fol-value key)
                                                   (fol.wrappers:fol-value val))))
    (make-instance '<sorted-dict> :items tree)))

(defgeneric <sorted-dict>? (obj) (:documentation "Returns T if OBJ is a FOL <sorted-dict>."))
(defmethod <sorted-dict>? (obj) nil)
(defmethod <sorted-dict>? ((obj <sorted-dict>)) t)

(defmethod print-object ((obj <sorted-dict>) stream)
  "Print sorted-dict as {<k1 v1 k2 v2>} in sorted key order."
  (format stream "{<")
  (let ((first t))
    (sycamore:do-tree-map ((key val) (pslot-value obj 'items))
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
  (format stream ">}"))


;;; ============================================================================
;;; Ordered Dictionary Class (<ordered-dict>)
;;; ============================================================================
;;; A persistent dictionary maintaining insertion order without size limit.
;;; Uses dual structure: map for O(1) lookup, seq for insertion order.

(defclass <ordered-dict> (<dict> <ordered-collection>)
  ((items :initarg :items
          :initform (fset:empty-map)
          :documentation "FSet map for O(1) lookup.")
   (order :initarg :order
          :initform (fset:empty-seq)
          :documentation "FSet seq maintaining insertion order."))
  (:metaclass persistent-class)
  (:documentation "A persistent dictionary maintaining insertion order without size limit."))

(defun make-ordered-dict (&rest pairs)
  "Create a new <ordered-dict> from key-value pairs.
   Maintains insertion order with no size limit."
  (let ((map (fset:empty-map))
        (seq (fset:empty-seq)))
    (loop for (key val) on pairs by #'cddr
          do (let ((raw-key (fol.wrappers:fol-value key))
                   (raw-val (fol.wrappers:fol-value val)))
               (multiple-value-bind (old-val found) (fset:lookup map raw-key)
                 (declare (ignore old-val))
                 (unless found
                   (setf seq (fset:with-last seq raw-key)))
                 (setf map (fset:with map raw-key raw-val)))))
    (make-instance '<ordered-dict> :items map :order seq)))

(defun ordered-dict (&rest pairs)
  "Create a new <ordered-dict> from key-value pairs.
   Alias for make-ordered-dict."
  (apply #'make-ordered-dict pairs))

(defgeneric <ordered-dict>? (obj) (:documentation "Returns T if OBJ is a FOL <ordered-dict>."))
(defmethod <ordered-dict>? (obj) nil)
(defmethod <ordered-dict>? ((obj <ordered-dict>)) t)

(defmethod print-object ((obj <ordered-dict>) stream)
  "Print ordered-dict as {#k1 v1 k2 v2#} in insertion order."
  (format stream "{#")
  (let ((first t))
    (fset:do-seq (key (pslot-value obj 'order))
      (unless first (format stream " "))
      (setf first nil)
      (let ((val (fset:lookup (pslot-value obj 'items) key)))
        (flet ((safe-print (item)
                 (cond ((eq item t) (format stream "#t"))
                       ((eq item nil) (format stream "#f"))
                       ((keywordp item) (format stream "~S" item))
                       ((symbolp item)  (format stream "'~S" item))
                       (t (format stream "~S" item)))))
          (safe-print key)
          (format stream " ")
          (safe-print val)))))
  (format stream "#}"))


;;; ============================================================================
;;; Priority Dictionary Class (<priority-dict>)
;;; ============================================================================
;;; A persistent dictionary maintaining entries sorted by their values (priorities).
;;; Useful as a priority queue where keys are items and values are priorities.

(defclass <priority-dict> (<dict> <ordered-collection>)
  ((items :initarg :items
          :initform (fset:empty-map)
          :documentation "Map from items (keys) to their priorities (values).")
   (priorities :initarg :priorities
               :initform (fset:empty-map)
               :documentation "Map from priorities to sets of items with that priority."))
  (:metaclass persistent-class)
  (:documentation "A persistent dictionary sorted by values (priorities), not keys."))

(defun make-priority-dict (&rest pairs)
  "Create a new <priority-dict> from key-value pairs.
   Items are sorted by their values (priorities) in ascending order."
  (let ((items (fset:empty-map))
        (priorities (fset:empty-map)))
    (loop for (key val) on pairs by #'cddr
          do (let ((raw-key (fol.wrappers:fol-value key))
                   (raw-val (fol.wrappers:fol-value val)))
               ;; Remove old priority if key exists
               (multiple-value-bind (old-priority found) (fset:lookup items raw-key)
                 (when found
                   (let ((item-set (fset:lookup priorities old-priority)))
                     (when item-set
                       (setf item-set (fset:less item-set raw-key))
                       (if (fset:empty? item-set)
                           (setf priorities (fset:less priorities old-priority))
                           (setf priorities (fset:with priorities old-priority item-set)))))))
               ;; Add new priority
               (setf items (fset:with items raw-key raw-val))
               (let ((item-set (or (fset:lookup priorities raw-val) (fset:empty-set))))
                 (setf item-set (fset:with item-set raw-key))
                 (setf priorities (fset:with priorities raw-val item-set)))))
    (make-instance '<priority-dict> :items items :priorities priorities)))

(defun priority-dict (&rest pairs)
  "Create a new <priority-dict> from key-value pairs.
   Alias for make-priority-dict."
  (apply #'make-priority-dict pairs))

(defgeneric <priority-dict>? (obj) (:documentation "Returns T if OBJ is a FOL <priority-dict>."))
(defmethod <priority-dict>? (obj) nil)
(defmethod <priority-dict>? ((obj <priority-dict>)) t)

(defmethod print-object ((obj <priority-dict>) stream)
  "Print priority-dict as {^k1 v1 k2 v2^} in priority (value) order."
  (format stream "{^")
  (let ((first t)
        (priorities (pslot-value obj 'priorities)))
    (fset:do-map (priority item-set priorities)
      (fset:do-set (key item-set)
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
          (safe-print priority)))))
  (format stream "^}"))


;;; ============================================================================
;;; Integer Dictionary Class (<int-dict>)
;;; ============================================================================
;;; A persistent dictionary optimized for integer keys, maintaining sorted order.

(defclass <int-dict> (<sorted-dict>)
  ()
  (:metaclass persistent-class)
  (:documentation "A persistent dictionary optimized for integer keys, sorted by key value."))

(defun make-int-dict (&rest pairs)
  "Create a new <int-dict> from key-value pairs.
   Keys must be integers. Maintains sorted order by key."
  (let ((tree (sycamore:make-tree-map #'(lambda (a b)
                                           (cond ((cl:< a b) -1)
                                                 ((cl:> a b) 1)
                                                 (t 0))))))
    (loop for (key val) on pairs by #'cddr
          do (let ((raw-key (fol.wrappers:fol-value key)))
               (unless (integerp raw-key)
                 (error "INT-DICT requires integer keys, got ~S" raw-key))
               (setf tree (sycamore:tree-map-insert tree
                                                    raw-key
                                                    (fol.wrappers:fol-value val)))))
    (make-instance '<int-dict> :items tree)))

(defun int-dict (&rest pairs)
  "Create a new <int-dict> from key-value pairs.
   Alias for make-int-dict."
  (apply #'make-int-dict pairs))

(defgeneric <int-dict>? (obj) (:documentation "Returns T if OBJ is a FOL <int-dict>."))
(defmethod <int-dict>? (obj) nil)
(defmethod <int-dict>? ((obj <int-dict>)) t)

;; <int-dict> inherits print-object from <sorted-dict> but uses standard format
(defmethod print-object ((obj <int-dict>) stream)
  "Print int-dict as {k1 v1 k2 v2} in sorted key order."
  (format stream "{")
  (let ((first t))
    (sycamore:do-tree-map ((key val) (pslot-value obj 'items))
      (unless first (format stream " "))
      (setf first nil)
      (format stream "~D ~S" key val)))
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
;;; Deque Class (<deque>)
;;; ============================================================================
;;; A persistent double-ended queue (deque) that supports efficient operations
;;; at both the front and back. Uses FSet sequences internally.
;;; All operations are O(log n) due to FSet's finger tree implementation.

(defclass <deque> (<ordered-collection>)
  ((items :initarg :items
          :initform (fset:empty-seq)
          :documentation "The underlying FSet sequence."))
  (:metaclass persistent-class)
  (:documentation "A persistent double-ended queue implemented using FSet sequences.
                   Supports O(log n) operations at both ends."))

(defun make-deque (&rest elements)
  "Create a new <deque> from the given elements.
   Elements are stored as raw CL primitives.
   The first element becomes the front of the deque."
  (make-instance '<deque>
                 :items (fset:convert 'fset:seq
                                      (mapcar #'fol.wrappers:fol-value elements))))

(defgeneric <deque>? (obj) (:documentation "Returns T if OBJ is a FOL <deque>."))
(defmethod <deque>? (obj) nil)
(defmethod <deque>? ((obj <deque>)) t)

(defmethod print-object ((obj <deque>) stream)
  "Print deque as #Q[elem1 elem2 ...] with front at left."
  (format stream "#Q[")
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
;;; List Class (<list>)
;;; ============================================================================
;;; A persistent singly-linked list following Clojure's list semantics.
;;; Structure: each list node has first (head element), rest (tail list), and size.
;;; This enables O(1) size/count operations and supports lazy sequences.
;;;
;;; The empty list is represented by a list with first=nil, rest=nil, size=0.
;;; Non-empty lists have first=element, rest=<list>, size=length.

(defclass <list> (<ordered-collection>)
  ((first-elem :initarg :first-elem
               :initform nil
               :accessor list-first
               :documentation "The first element of this list, or NIL if empty.")
   (rest-list :initarg :rest-list
              :initform nil
              :accessor list-rest
              :documentation "The rest of this list (another <list>), or NIL if empty.")
   (list-size :initarg :list-size
              :initform 0
              :accessor list-size
              :type integer
              :documentation "The number of elements in this list. O(1) access."))
  (:metaclass persistent-class)
  (:documentation "A persistent singly-linked list with O(1) size access.
                   Each node contains first (head), rest (tail), and size.
                   Supports efficient cons (prepend), first, and rest operations.
                   The structure enables lazy sequence implementations."))

(defun make-list (&rest elements)
  "Create a new <list> from the given elements.
   Elements are stored as raw CL primitives in the order given."
  (if (null elements)
      ;; Empty list
      (make-instance '<list> :first-elem nil :rest-list nil :list-size 0)
      ;; Build list from right to left
      (let ((result (make-instance '<list> :first-elem nil :rest-list nil :list-size 0)))
        (dolist (elem (cl:reverse elements))
          (setf result (make-instance '<list>
                                      :first-elem (fol.wrappers:fol-value elem)
                                      :rest-list result
                                      :list-size (1+ (list-size result)))))
        result)))

(defgeneric <list>? (obj) (:documentation "Returns T if OBJ is a FOL <list>."))
(defmethod <list>? (obj) nil)
(defmethod <list>? ((obj <list>)) t)

(defmethod print-object ((obj <list>) stream)
  (format stream "(")
  (let ((current obj)
        (first-printed nil))
    (loop while (and current (> (list-size current) 0))
          do (unless first-printed
               (setf first-printed t))
             (when (> (list-size current) 0)
               (unless (eq current obj) (format stream " "))
               (let ((item (list-first current)))
                 (cond ((eq item t) (format stream "#t"))
                       ((eq item nil) (format stream "#f"))
                       ((keywordp item) (format stream "~S" item))
                       ((symbolp item) (format stream "'~S" item))
                       (t (format stream "~S" item)))))
             (setf current (list-rest current))))
  (format stream ")"))



(defclass <list-node-iterator> ()
  ((current :initarg :current :accessor iter-current))
  (:documentation "An iterator for <list> that traverses the linked structure."))

(defmethod iterator ((lst <list>))
  "Return an iterator for the list."
  (make-instance '<list-node-iterator> :current lst))

(defmethod next ((iter <list-node-iterator>))
  "Advance the iterator to the next element."
  (let ((current (iter-current iter)))
    (when (and current (> (list-size current) 0))
      (setf (iter-current iter) (list-rest current))))
  iter)

(defmethod current ((iter <list-node-iterator>))
  "Return the current element."
  (let ((current (iter-current iter)))
    (when (and current (> (list-size current) 0))
      (list-first current))))

(defmethod done? ((iter <list-node-iterator>))
  "Return T if the iterator is exhausted."
  (let ((current (iter-current iter)))
    (if (or (null current) (zerop (list-size current)))
        t
        nil)))


;;; ============================================================================
;;; Lazy Sequence Class (<lazy-seq>)
;;; ============================================================================
;;; A lazy sequence that delays computation until realized, like Clojure's lazy-seq.
;;; The thunk is a zero-argument function that when called produces:
;;;   - nil (empty sequence)
;;;   - a <list> (the sequence)
;;;   - another <lazy-seq> (chained lazy computation)
;;;
;;; Once realized, the result is cached. This enables infinite sequences
;;; and efficient memory usage for large transformations.

(defclass <lazy-seq> ()
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
  (:documentation "A lazy sequence that delays computation until needed.
                   Implements the sequence protocol (first, rest, seq).
                   Once realized, the result is cached for subsequent access."))

(defun make-lazy-seq (thunk)
  "Create a new lazy sequence from a thunk (zero-argument function).
   The thunk should return a seq (list), nil, or another lazy-seq."
  (make-instance '<lazy-seq> :thunk thunk))

(defgeneric <lazy-seq>? (obj) (:documentation "Returns T if OBJ is a FOL <lazy-seq>."))
(defmethod <lazy-seq>? (obj) nil)
(defmethod <lazy-seq>? ((obj <lazy-seq>)) t)

;; Pass-through for fol-value - lazy sequences are their own FOL value
(defmethod fol.wrappers:fol-value ((obj <lazy-seq>)) obj)

(defun realize-lazy-seq (ls)
  "Force realization of a lazy sequence. Returns the underlying sequence or nil.
   If the thunk returns another lazy-seq, recursively realizes it."
  (unless (lazy-seq-realized-p ls)
    (let ((result (funcall (lazy-seq-thunk ls))))
      ;; Recursively realize if result is also a lazy-seq
      (setf (lazy-seq-cached ls)
            (loop while (<lazy-seq>? result)
                  do (setf result (realize-lazy-seq result))
                  finally (return result)))
      (setf (lazy-seq-realized-p ls) t)
      ;; Clear the thunk to allow GC
      (setf (lazy-seq-thunk ls) nil)))
  (lazy-seq-cached ls))

(defmethod print-object ((obj <lazy-seq>) stream)
  (if (lazy-seq-realized-p obj)
      (let ((cached (lazy-seq-cached obj)))
        (if cached
            (print-object cached stream)
            (format stream "()")))
      (format stream "#<lazy-seq unrealized>")))

;;; --- Iterator for <lazy-seq> ---

(defclass <lazy-seq-iterator> ()
  ((current :initarg :current :accessor iter-current-lazy)
   (done :initform nil :accessor iter-done-lazy))
  (:documentation "An iterator for lazy sequences."))

(defmethod iterator ((ls <lazy-seq>))
  "Return an iterator for the lazy sequence."
  (make-instance '<lazy-seq-iterator> :current ls))

(defmethod next ((iter <lazy-seq-iterator>))
  "Advance the iterator to the next element."
  (unless (iter-done-lazy iter)
    (let* ((current (iter-current-lazy iter))
           (realized (if (<lazy-seq>? current)
                         (realize-lazy-seq current)
                         current)))
      (if (or (null realized) (empty? realized))
          (setf (iter-done-lazy iter) t)
          (setf (iter-current-lazy iter) (rest realized)))))
  iter)

(defmethod current ((iter <lazy-seq-iterator>))
  "Return the current element."
  (unless (iter-done-lazy iter)
    (let* ((current (iter-current-lazy iter))
           (realized (if (<lazy-seq>? current)
                         (realize-lazy-seq current)
                         current)))
      (when (and realized (not (empty? realized)))
        (first realized)))))

(defmethod done? ((iter <lazy-seq-iterator>))
  "Return T if the iterator is exhausted."
  (if (iter-done-lazy iter)
      t
      (let* ((current (iter-current-lazy iter))
             (realized (if (<lazy-seq>? current)
                           (realize-lazy-seq current)
                           current)))
        (if (or (null realized) (empty? realized))
            (progn (setf (iter-done-lazy iter) t) t)
            nil))))


;;; ============================================================================
;;; Reduced: Early Termination for Reduce
;;; ============================================================================
;;; A wrapper type that signals early termination in reduce operations.
;;; When reduce encounters a reduced value, it unwraps and returns immediately.

(defclass <reduced> ()
  ((value :initarg :value
          :initform nil
          :accessor reduced-value
          :documentation "The wrapped value to return from reduce."))
  (:documentation "Wrapper indicating early termination in reduce operations."))

(defun reduced (value)
  "Wrap VALUE to signal early termination in reduce.
   When reduce encounters a reduced value, it stops iteration and returns
   the unwrapped value immediately."
  (make-instance '<reduced> :value value))

(defgeneric <reduced>? (obj)
  (:documentation "Returns T if OBJ is a reduced wrapper."))

(defmethod <reduced>? (obj)
  "Default: not reduced."
  nil)

(defmethod <reduced>? ((obj <reduced>))
  "Reduced values return T."
  t)

(defun unreduced (value)
  "Unwrap a reduced value, or return VALUE unchanged if not reduced."
  (if (<reduced>? value)
      (reduced-value value)
      value))

(defmethod print-object ((obj <reduced>) stream)
  (format stream "#<reduced ~S>" (reduced-value obj)))

;;; ============================================================================
;;; Sequence Accessors: second, third, nth
;;; ============================================================================
;;; These work on any seqable (lists, vectors, lazy-seqs, CL lists).

(defgeneric second (coll)
  (:documentation "Return the second element of COLL, or NIL if not present."))

(defmethod second ((coll t))
  "Default implementation: (first (rest coll))"
  (first (rest coll)))

(defgeneric third (coll)
  (:documentation "Return the third element of COLL, or NIL if not present."))

(defmethod third ((coll t))
  "Default implementation: (first (rest (rest coll)))"
  (first (rest (rest coll))))

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

;;; peek for <array> (defined here after <array> class)
(defmethod peek ((a <array>) &optional indices)
  "Return the element at INDICES (a <vector> of integers)."
  (unless indices
    (error "PEEK on <array> requires indices"))
  (get a indices nil))



;;; 8. ITERATOR PROTOCOL

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

;;; ============================================================================
;;; SIZED? - Check if a collection has a known size
;;; ============================================================================

(defgeneric sized? (collection)
  (:documentation "Returns T if COLLECTION has a known finite size, NIL otherwise.
   Vectors, lists, dicts, sets, bags, and arrays are sized.
   Lazy sequences and other types are not."))

(defmethod sized? (obj)
  "Default: not sized."
  (declare (ignore obj))
  nil)

(defmethod sized? ((c <vector>)) t)
(defmethod sized? ((c <deque>)) t)
(defmethod sized? ((c <list>)) t)
(defmethod sized? ((c <dict>)) t)
(defmethod sized? ((c <set>)) t)
(defmethod sized? ((c <bag>)) t)
(defmethod sized? ((c <array>)) t)
(defmethod sized? ((c <lazy-seq>)) nil)
(defmethod sized? ((lst cons)) t)
(defmethod sized? ((lst null)) t)
(defmethod sized? ((s string)) t)

;;; ============================================================================
;;; BOUNDED-SIZE - Get size with a limit for unsized collections
;;; ============================================================================

(defun bounded-size (n coll)
  "If COLL is sized?, returns its size.
   Otherwise, counts at most the first N elements of COLL."
  (if (sized? coll)
      (size coll)
      (let ((s (seq coll))
            (count 0))
        (loop while (and s
                        (not (empty? s))
                        (cl:< count n))
              do (cl:incf count)
                 (setf s (rest s)))
        count)))

;;; ============================================================================
;;; INTO - Conjoin elements from one collection into another
;;; ============================================================================

(defun into (&optional (to nil to-supplied-p) (xform-or-from nil xform-or-from-supplied-p)
                       (from nil from-supplied-p))
  "Returns a new collection consisting of TO with all of the items of FROM conjoined.
   A transducer may be supplied.

   (into)              - returns []
   (into to)           - returns to
   (into to from)      - conjoins all items of FROM into TO
   (into to xform from) - applies transducer XFORM while conjoining FROM into TO"
  (cond
    ;; (into) => []
    ((not to-supplied-p)
     (make-vector))

    ;; (into to) => to
    ((not xform-or-from-supplied-p)
     to)

    ;; (into to from) or (into to xform from)?
    ((not from-supplied-p)
     ;; Two args: (into to from) — no transducer
     (let ((from xform-or-from)
           (result to))
       (let ((s (seq from))
             (dict-target (and (typep result '<dict>)
                               (not (typep result '<set>))
                               (not (typep result '<bag>)))))
         (loop while (and s (not (empty? s)))
               do (if dict-target
                      ;; For dicts, elements from seq come as cons pairs (key . value)
                      (let ((pair (first s)))
                        (setf result (add result (car pair) (cdr pair))))
                      (setf result (conj result (first s))))
                  (setf s (rest s))))
       result))

    ;; (into to xform from) — with transducer
    (t
     (let* ((xform xform-or-from)
            ;; Build the reducing function: conj (or add for dicts)
            (dict-target (and (typep to '<dict>)
                              (not (typep to '<set>))
                              (not (typep to '<bag>))))
            (rf (if dict-target
                    #'(lambda (acc elem)
                        (if (consp elem)
                            (add acc (car elem) (cdr elem))
                            (error "INTO <dict> with transducer: each element must be a cons pair (key . value), got ~A" elem)))
                    #'(lambda (acc elem)
                        (conj acc elem))))
            ;; Apply the transducer to get the transformed reducing function
            (xrf (funcall xform rf))
            ;; Reduce over from using the transformed reducing function
            (s (seq from))
            (acc to))
       (loop while (and s
                        (not (empty? s))
                        (not (<reduced>? acc)))
             do (setf acc (funcall xrf acc (first s)))
                (setf s (rest s)))
       (unreduced acc)))))

;;; ============================================================================
;;; VECTOR, VEC, MAPV, FILTERV - Eager vector operations
;;; ============================================================================

(defun vector (&rest elements)
  "Creates a new vector containing the supplied elements.
   (vector)       - returns []
   (vector a b c) - returns [a b c]"
  (apply #'make-vector elements))

(defun vec (coll)
  "Coerces COLL to a vector.
   Equivalent to (into [] coll)."
  (into (make-vector) coll))

(defun mapv (f coll)
  "Returns a vector of applying F to each element of COLL.
   Eager (non-lazy) version of map."
  (let ((result (make-vector))
        (s (seq coll)))
    (loop while (and s (not (empty? s)))
          do (setf result (conj result (funcall f (first s))))
             (setf s (rest s)))
    result))

(defun filterv (pred coll)
  "Returns a vector of the items in COLL for which (PRED item) returns true.
   Eager (non-lazy) version of filter."
  (let ((result (make-vector))
        (s (seq coll)))
    (loop while (and s (not (empty? s)))
          do (let ((item (first s)))
               (when (funcall pred item)
                 (setf result (conj result item))))
             (setf s (rest s)))
    result))

;;; ============================================================================
;;; FOL Type Reflection for Collections
;;; ============================================================================
;;; These methods must be defined here (after collection classes exist)
;;; to avoid circular dependency with wrappers.lisp.

(defmethod fol.wrappers:fol-type-of ((obj <vector>)) '<vector>)
(defmethod fol.wrappers:fol-type-of ((obj <deque>)) '<deque>)
(defmethod fol.wrappers:fol-type-of ((obj <list>)) '<list>)
(defmethod fol.wrappers:fol-type-of ((obj <dict>)) '<dict>)
(defmethod fol.wrappers:fol-type-of ((obj <set>)) '<set>)
(defmethod fol.wrappers:fol-type-of ((obj <sorted-set>)) '<sorted-set>)
(defmethod fol.wrappers:fol-type-of ((obj <ordered-set>)) '<ordered-set>)
(defmethod fol.wrappers:fol-type-of ((obj <int-set>)) '<int-set>)
(defmethod fol.wrappers:fol-type-of ((obj <dense-int-set>)) '<dense-int-set>)
(defmethod fol.wrappers:fol-type-of ((obj <sorted-set-by>)) '<sorted-set-by>)
(defmethod fol.wrappers:fol-type-of ((obj <bag>)) '<bag>)
(defmethod fol.wrappers:fol-type-of ((obj <array-dict>)) '<array-dict>)
(defmethod fol.wrappers:fol-type-of ((obj <sorted-dict>)) '<sorted-dict>)
(defmethod fol.wrappers:fol-type-of ((obj <ordered-dict>)) '<ordered-dict>)
(defmethod fol.wrappers:fol-type-of ((obj <priority-dict>)) '<priority-dict>)
(defmethod fol.wrappers:fol-type-of ((obj <int-dict>)) '<int-dict>)
(defmethod fol.wrappers:fol-type-of ((obj <array>)) '<array>)
(defmethod fol.wrappers:fol-type-of ((obj <lazy-seq>)) '<lazy-seq>)
