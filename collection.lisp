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

(defgeneric <dict>? (obj) (:documentation "Returns T if OBJ is exactly a FOL <dict> (not subclasses like <set> or <bag>)."))
(defmethod <dict>? (obj) nil)
(defmethod <dict>? ((obj <dict>))
  ;; Check for exact class match, not subclasses
  (eq (class-of obj) (find-class '<dict>)))

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
(defmethod fol.wrappers:fol-type-of ((obj <list>)) '<list>)
(defmethod fol.wrappers:fol-type-of ((obj <dict>)) '<dict>)
(defmethod fol.wrappers:fol-type-of ((obj <set>)) '<set>)
(defmethod fol.wrappers:fol-type-of ((obj <bag>)) '<bag>)
(defmethod fol.wrappers:fol-type-of ((obj <array>)) '<array>)
(defmethod fol.wrappers:fol-type-of ((obj <lazy-seq>)) '<lazy-seq>)
