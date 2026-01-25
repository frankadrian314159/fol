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
        (dolist (elem (reverse elements))
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

;;; --- List-specific operations ---

(defgeneric conj (collection item &rest more-items)
  (:documentation "Returns a new collection with ITEM(s) added in the natural position.
   Like Clojure's conj:
   - For lists: adds to the front (most efficient)
   - For vectors: adds to the end (most efficient)
   - For sets: adds the element
   - For bags: adds the element (increments count)
   - For dicts: ITEM should be a cons pair (key . value)
   - For lazy-seqs: adds to the front

   Multiple items can be added at once: (conj coll item1 item2 item3)
   Items are added left-to-right, so for lists the rightmost item ends up first."))

(defmethod conj ((lst <list>) item &rest more-items)
  "Add items to the front of a list."
  (let ((result (make-instance '<list>
                               :first-elem (fol.wrappers:fol-value item)
                               :rest-list lst
                               :list-size (1+ (list-size lst)))))
    (dolist (it more-items)
      (setf result (make-instance '<list>
                                  :first-elem (fol.wrappers:fol-value it)
                                  :rest-list result
                                  :list-size (1+ (list-size result)))))
    result))

(defgeneric first (list)
  (:documentation "Return the first element of LIST, or NIL if empty."))

(defmethod first ((lst <list>))
  "Return the first element of LST."
  (list-first lst))

(defgeneric rest (list)
  (:documentation "Return the rest of the list (all but first element).
   Returns an empty list if LIST has 0 or 1 elements."))

(defmethod rest ((lst <list>))
  "Return the rest of the list."
  (or (list-rest lst)
      (make-instance '<list> :first-elem nil :rest-list nil :list-size 0)))

;;; --- Methods for CL lists (cons cells) ---
;;; These enable lazy-seq to work with CL lists returned from thunks.

(defmethod first ((lst cons))
  "Return the first element of a CL list."
  (car lst))

(defmethod first ((lst null))
  "Return nil for empty list."
  nil)

(defmethod rest ((lst cons))
  "Return the rest of a CL list."
  (cdr lst))

(defmethod rest ((lst null))
  "Return nil for empty list."
  nil)

(defmethod conj ((lst cons) item &rest more-items)
  "Prepend items to a CL list, returning a CL list."
  (let ((result (cl:cons (fol.wrappers:fol-value item) lst)))
    (dolist (it more-items)
      (setf result (cl:cons (fol.wrappers:fol-value it) result)))
    result))

(defmethod conj ((lst null) item &rest more-items)
  "Add items to nil, creating a CL list."
  (let ((result (cl:cons (fol.wrappers:fol-value item) nil)))
    (dolist (it more-items)
      (setf result (cl:cons (fol.wrappers:fol-value it) result)))
    result))

;;; --- Generic protocol implementations for <list> ---

(defmethod size ((lst <list>))
  "Return the number of elements in the list. O(1) operation."
  (list-size lst))

(defmethod empty? ((lst <list>))
  "Return T if the list is empty."
  (if (zerop (list-size lst)) t nil))

(defmethod contains? ((lst <list>) item)
  "Return T if ITEM is in the list."
  (let ((raw-item (fol.wrappers:fol-value item))
        (current lst))
    (loop while (and current (> (list-size current) 0))
          do (when (equal (list-first current) raw-item)
               (return-from contains? t))
             (setf current (list-rest current)))
    nil))

(defmethod add ((lst <list>) item &optional value)
  "Add ITEM to the front of the list (like cons)."
  (declare (ignore value))
  (conj lst item))

(defmethod remove ((lst <list>) item)
  "Return a new list with the first occurrence of ITEM removed."
  (let ((raw-item (fol.wrappers:fol-value item)))
    (labels ((remove-first (current)
               (cond
                 ;; Empty list - nothing to remove
                 ((zerop (list-size current)) current)
                 ;; Found the item - skip it
                 ((equal (list-first current) raw-item)
                  (rest current))
                 ;; Not found yet - cons and continue
                 (t (conj (remove-first (rest current))
                          (list-first current))))))
      (remove-first lst))))

(defmethod get ((lst <list>) (index integer) &optional default)
  "Get element at INDEX from list. Returns raw value."
  (if (or (< index 0) (>= index (list-size lst)))
      default
      (let ((current lst))
        (dotimes (i index)
          (setf current (list-rest current)))
        (list-first current))))

(defmethod get ((lst <list>) (index fol.classes:<number>) &optional default)
  "Get element at INDEX from list. INDEX can be wrapped."
  (get lst (fol.wrappers:fol-value index) default))

(defmethod nth-element ((lst <list>) (n integer))
  "Get the Nth element from the list."
  (get lst n nil))

(defmethod nth-element ((lst <list>) (n fol.classes:<number>))
  "Get the Nth element from the list. N can be wrapped."
  (get lst (fol.wrappers:fol-value n) nil))

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

;;; --- Sequence protocol for <lazy-seq> ---

(defmethod seq ((ls <lazy-seq>))
  "Realize the lazy sequence and return seq of the result."
  (let ((realized (realize-lazy-seq ls)))
    (if realized
        (seq realized)
        nil)))

(defmethod first ((ls <lazy-seq>))
  "Get first element, realizing if needed."
  (let ((realized (realize-lazy-seq ls)))
    (if realized
        (first realized)
        nil)))

(defmethod rest ((ls <lazy-seq>))
  "Get rest of sequence, realizing if needed."
  (let ((realized (realize-lazy-seq ls)))
    (if realized
        (rest realized)
        (make-instance '<list> :first-elem nil :rest-list nil :list-size 0))))

(defmethod size ((ls <lazy-seq>))
  "Get size, realizing the entire sequence.
   WARNING: This will not terminate for infinite sequences!"
  (labels ((count-seq (seq acc)
             (let ((realized (if (<lazy-seq>? seq)
                                 (realize-lazy-seq seq)
                                 seq)))
               (cond
                 ((null realized) acc)
                 ((consp realized)
                  (count-seq (cl:cdr realized) (1+ acc)))
                 (t (cl:+ acc (size realized)))))))
    (count-seq ls 0)))

(defmethod empty? ((ls <lazy-seq>))
  "Check if empty, realizing if needed."
  (let ((realized (realize-lazy-seq ls)))
    (if (or (null realized) (empty? realized))
        t
        nil)))

(defmethod contains? ((ls <lazy-seq>) item)
  "Check if item is in the sequence, realizing as needed.
   WARNING: May not terminate for infinite sequences if item is not found!"
  (let ((realized (realize-lazy-seq ls)))
    (if realized
        (contains? realized item)
        nil)))

(defmethod conj ((ls <lazy-seq>) item &rest more-items)
  "Add items to the front of a lazy sequence.
   Returns a CL cons cell where first is the item and rest is the lazy-seq.
   The lazy-seq is only realized when first/rest is called on it."
  (let ((result (cl:cons (fol.wrappers:fol-value item) ls)))
    (dolist (it more-items)
      (setf result (cl:cons (fol.wrappers:fol-value it) result)))
    result))

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

(defgeneric nth (n coll)
  (:documentation "Return the Nth element (0-indexed) of COLL, or NIL if not present.
   Like Clojure's nth, this is 0-indexed."))

(defmethod nth ((n integer) (lst <list>))
  "Get Nth element from a <list>."
  (get lst n nil))

(defmethod nth ((n integer) (v <vector>))
  "Get Nth element from a <vector>."
  (get v n nil))

(defmethod nth ((n integer) (ls <lazy-seq>))
  "Get Nth element from a <lazy-seq>."
  (let ((current ls))
    (dotimes (i n)
      (setf current (rest current))
      (when (null current)
        (return-from nth nil)))
    (first current)))

(defmethod nth ((n integer) (lst cons))
  "Get Nth element from a CL list."
  (cl:nth n lst))

(defmethod nth ((n integer) (lst null))
  "Nth of nil is nil."
  nil)

(defmethod nth ((n fol.classes:<number>) coll)
  "Allow wrapped numbers as index."
  (nth (fol.wrappers:fol-value n) coll))


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

;;; --- Methods for CL lists (cons cells) ---

(defmethod size ((lst cons))
  "Return the length of a CL list."
  (cl:length lst))

(defmethod size ((lst null))
  "Return 0 for nil."
  0)

(defmethod empty? ((lst cons))
  "CL cons is never empty."
  nil)

(defmethod empty? ((lst null))
  "Nil is empty."
  t)

;;; 3. SEQ
(defgeneric seq (collection)
  (:documentation "Returns a <list> view of the collection, or NIL if empty.
   Like Clojure's seq, this is the fundamental way to get a sequential
   view of any collection. Returns NIL (not an empty list) for empty collections."))

(defmethod seq ((c <collection>))
  "Default implementation: convert to list via iterator."
  (if (empty? c)
      nil
      (let ((iter (iterator c))
            (result nil))
        (loop until (done? iter)
              do (push (current iter) result)
                 (next iter))
        (apply #'make-list (nreverse result)))))

(defmethod seq ((lst <list>))
  "For lists, return the list itself or NIL if empty."
  (if (zerop (list-size lst))
      nil
      lst))

(defmethod seq ((v <vector>))
  "For vectors, convert to a list."
  (let ((items (pslot-value v 'items)))
    (if (fset:empty? items)
        nil
        (apply #'make-list (fset:convert 'list items)))))

(defmethod seq ((d <dict>))
  "For dicts, return a list of (key . value) pairs."
  (let ((items (pslot-value d 'items)))
    (if (fset:empty? items)
        nil
        (let ((pairs nil))
          (fset:do-map (k v items)
            (push (cons k v) pairs))
          (apply #'make-list (nreverse pairs))))))

(defmethod seq ((s <set>))
  "For sets, return a list of elements (keys only)."
  (let ((items (pslot-value s 'items)))
    (if (fset:empty? items)
        nil
        (let ((elems nil))
          (fset:do-map (k v items)
            (declare (ignore v))
            (push k elems))
          (apply #'make-list (nreverse elems))))))

(defmethod seq ((b <bag>))
  "For bags, return a list with elements repeated by their count."
  (let ((items (pslot-value b 'items)))
    (if (fset:empty? items)
        nil
        (let ((elems nil))
          (fset:do-map (elem count items)
            (dotimes (i count)
              (push elem elems)))
          (apply #'make-list (nreverse elems))))))

;;; --- Methods for CL lists (cons cells) ---

(defmethod seq ((lst cons))
  "For CL lists, return the list itself."
  lst)

(defmethod seq ((lst null))
  "For nil, return nil."
  nil)

;;; 4. CONTAINS?
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

;;; 5. CONJ (Clojure-style addition for non-list collections)
;;; Note: conj for lists, CL cons, null, and lazy-seq is defined earlier in the file.

(defmethod conj ((v <vector>) item &rest more-items)
  "Add items to the end of a vector."
  (let ((result (add v item)))
    (dolist (it more-items)
      (setf result (add result it)))
    result))

(defmethod conj ((s <set>) item &rest more-items)
  "Add items to a set."
  (let ((result (add s item)))
    (dolist (it more-items)
      (setf result (add result it)))
    result))

(defmethod conj ((b <bag>) item &rest more-items)
  "Add items to a bag."
  (let ((result (add b item)))
    (dolist (it more-items)
      (setf result (add result it)))
    result))

(defmethod conj ((d <dict>) item &rest more-items)
  "Add key-value pairs to a dict. Each item should be a cons pair (key . value)."
  (unless (consp item)
    (error "conj on <dict> requires a cons pair (key . value), got ~A" item))
  (let ((result (add d (car item) (cdr item))))
    (dolist (it more-items)
      (unless (consp it)
        (error "conj on <dict> requires cons pairs (key . value), got ~A" it))
      (setf result (add result (car it) (cdr it))))
    result))

(defmethod conj ((a <array>) item &rest more-items)
  "Arrays do not support conj."
  (declare (ignore item more-items))
  (error "Cannot conj to a fixed-dimension <array>. Use set-nth to modify elements."))

;;; 6. REMOVE (Functional Deletion)
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


;;; ============================================================================
;;; String as Ordered Collection
;;; ============================================================================
;;; Strings can be treated as ordered collections of characters.

(defmethod size ((s string))
  "Return the length of a string."
  (cl:length s))

(defmethod empty? ((s string))
  "Return T if string is empty."
  (zerop (cl:length s)))

(defmethod get ((s string) (index integer) &optional default)
  "Get character at INDEX from string. Returns character or DEFAULT."
  (if (and (>= index 0) (< index (cl:length s)))
      (cl:char s index)
      default))

(defmethod get ((s string) (index fol.classes:<number>) &optional default)
  "Get character at INDEX from string. INDEX can be wrapped."
  (get s (fol.wrappers:fol-value index) default))

(defmethod first ((s string))
  "Return the first character of a string, or NIL if empty."
  (if (zerop (cl:length s))
      nil
      (cl:char s 0)))

(defmethod rest ((s string))
  "Return a string without the first character, or empty string if empty."
  (if (<= (cl:length s) 1)
      ""
      (cl:subseq s 1)))

(defmethod nth ((n integer) (s string))
  "Get Nth character from a string."
  (get s n nil))

(defmethod contains? ((s string) item)
  "Return T if character ITEM is in string S."
  (let ((char (fol.wrappers:fol-value item)))
    (if (characterp char)
        (if (cl:position char s)
            t
            nil)
        nil)))

(defmethod seq ((s string))
  "Return a <list> of characters from the string, or NIL if empty."
  (if (zerop (cl:length s))
      nil
      (apply #'make-list (coerce s 'list))))

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
