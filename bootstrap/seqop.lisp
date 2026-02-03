;;;; seq-ops.lisp - Sequence operations: assoc, assoc-in, sub
;;;;
;;;; These generic functions operate on vectors, dicts, lists, and strings.

(in-package :fol.seqop)

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
  "Return the rest of the list, or an empty list if at end."
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

(defmethod first ((v <vector>))
  "Return the first element of a vector, or NIL if empty."
  (if (cl:zerop (fset:size (pslot-value v 'fol.collection::items)))
      nil
      (fset:@ (pslot-value v 'fol.collection::items) 0)))

(defmethod rest ((v <vector>))
  "Return a new vector containing all but the first element."
  (let ((items (pslot-value v 'fol.collection::items)))
    (if (cl:<= (fset:size items) 1)
        (make-vector)
        (let ((result (fset:empty-seq)))
          (fset:do-seq (item items :index i)
            (when (cl:> i 0)
              (setf result (fset:with-last result item))))
          (make-instance '<vector> :items result)))))

(defmethod rest ((lst cons))
  "Return the rest of a CL list."
  (cdr lst))

(defmethod rest ((lst null))
  "Return nil for empty list."
  nil)

(defmethod first ((s <set>))
  "Return an arbitrary element from the set, or NIL if empty."
  (let ((items (pslot-value s 'fol.collection::items)))
    (if (fset:empty? items)
        nil
        (fset:arb items))))

(defmethod first ((s <ordered-set>))
  "Return the first element from the ordered set, or NIL if empty."
  (let ((s-seq (seq s)))
    (if (cl:or (null s-seq) (empty? s-seq))
        nil
        (first s-seq))))

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

;;; --- Stack-like operations (peek/pop/push) ---

(defgeneric peek (collection &optional indices)
  (:documentation "Returns an element from a collection without modifying it.
   For strings: returns the last character.
   For lists: returns the first element.
   For vectors: returns the last element.
   For arrays: INDICES is a <vector> of indices; returns the element at that position."))

(defmethod peek ((lst <list>) &optional indices)
  "Return the first element of the list, or NIL if empty."
  (declare (ignore indices))
  (if (zerop (list-size lst))
      nil
      (list-first lst)))

(defmethod peek ((lst null) &optional indices)
  "Return nil for empty/nil list."
  (declare (ignore indices))
  nil)

(defmethod peek ((v <vector>) &optional indices)
  "Return the last element of the vector, or NIL if empty."
  (declare (ignore indices))
  (let ((items (pslot-value v 'fol.collection::items)))
    (if (fset:empty? items)
        nil
        (fset:@ items (1- (fset:size items))))))

;;; Note: peek for <array> is defined later after the <array> class

(defgeneric pop (collection)
  (:documentation "Returns a new collection without one element.
   For lists: removes the first element (front of list).
   For vectors: removes the last element (end of vector).
   Returns nil if the collection is empty."))

(defmethod pop ((lst <list>))
  "Return a new list without the first item. Returns nil if empty."
  (if (zerop (list-size lst))
      nil
      (or (list-rest lst)
          (make-instance '<list> :first-elem nil :rest-list nil :list-size 0))))

(defmethod pop ((lst null))
  "Return nil for empty/nil list."
  nil)

(defgeneric push (item collection)
  (:documentation "Returns a new collection with ITEM added.
   For lists: adds to the front (like cons).
   For vectors: adds to the end (like conj)."))

(defmethod push (item (lst <list>))
  "Add ITEM to the front of the list."
  (conj lst item))

(defmethod push (item (lst null))
  "Create a new list with just ITEM."
  (make-list item))

;;; --- Deque-specific operations (front and end) ---

(defgeneric peek-front (collection)
  (:documentation "Returns the element at the front of a deque without modifying it.
   Returns NIL if the collection is empty."))

(defgeneric pop-front (collection)
  (:documentation "Returns a new deque without the front element.
   Returns an empty deque if the collection is empty."))

(defgeneric push-front (item collection)
  (:documentation "Returns a new deque with ITEM added at the front."))

(defgeneric peek-end (collection)
  (:documentation "Returns the element at the end of a deque without modifying it.
   Returns NIL if the collection is empty."))

(defgeneric pop-end (collection)
  (:documentation "Returns a new deque without the end element.
   Returns an empty deque if the collection is empty."))

(defgeneric push-end (item collection)
  (:documentation "Returns a new deque with ITEM added at the end."))

;;; --- Deque front operations ---

(defmethod peek-front ((dq <deque>))
  "Return the front element of the deque, or NIL if empty."
  (let ((items (pslot-value dq 'fol.collection::items)))
    (if (fset:empty? items)
        nil
        (fset:@ items 0))))

(defmethod pop-front ((dq <deque>))
  "Return a new deque without the front element."
  (let ((items (pslot-value dq 'fol.collection::items)))
    (if (fset:empty? items)
        (make-deque)
        (make-instance '<deque> :items (fset:subseq items 1)))))

(defmethod push-front (item (dq <deque>))
  "Add ITEM to the front of the deque."
  (let* ((items (pslot-value dq 'fol.collection::items))
         (raw-item (fol.wrappers:fol-value item))
         ;; Build a new sequence with item at front
         (new-items (fset:with-last (fset:empty-seq) raw-item)))
    (fset:do-seq (elem items)
      (setf new-items (fset:with-last new-items elem)))
    (make-instance '<deque> :items new-items)))

;;; --- Deque end operations ---

(defmethod peek-end ((dq <deque>))
  "Return the end element of the deque, or NIL if empty."
  (let ((items (pslot-value dq 'fol.collection::items)))
    (if (fset:empty? items)
        nil
        (fset:@ items (1- (fset:size items))))))

(defmethod pop-end ((dq <deque>))
  "Return a new deque without the end element."
  (let ((items (pslot-value dq 'fol.collection::items)))
    (if (fset:empty? items)
        (make-deque)
        (make-instance '<deque> :items (fset:less-last items)))))

(defmethod push-end (item (dq <deque>))
  "Add ITEM to the end of the deque."
  (make-instance '<deque>
                 :items (fset:with-last (pslot-value dq 'fol.collection::items)
                                        (fol.wrappers:fol-value item))))

;;; --- Standard operations for <deque> ---

(defmethod size ((dq <deque>))
  "Return the number of elements in the deque."
  (fset:size (pslot-value dq 'fol.collection::items)))

(defmethod empty? ((dq <deque>))
  "Return T if the deque is empty."
  (if (fset:empty? (pslot-value dq 'fol.collection::items)) t nil))

(defmethod contains? ((dq <deque>) item)
  "Return T if ITEM is in the deque."
  (let ((raw-item (fol.wrappers:fol-value item))
        (items (pslot-value dq 'fol.collection::items)))
    (fset:do-seq (elem items)
      (when (equal elem raw-item)
        (return-from contains? t)))
    nil))

(defmethod seq ((dq <deque>))
  "Return a seq over the deque's elements from front to back."
  (let ((items (pslot-value dq 'fol.collection::items)))
    (if (fset:empty? items)
        nil
        (apply #'make-list (fset:convert 'list items)))))

(defmethod first ((dq <deque>))
  "Return the first (front) element of the deque."
  (peek-front dq))

(defmethod rest ((dq <deque>))
  "Return a new deque without the first element."
  (pop-front dq))

(defmethod get ((dq <deque>) (index integer) &optional default)
  "Get element at INDEX from deque."
  (let ((items (pslot-value dq 'fol.collection::items)))
    (if (or (< index 0) (>= index (fset:size items)))
        default
        (fset:@ items index))))

(defmethod get ((dq <deque>) (index fol.classes:<number>) &optional default)
  "Get element at INDEX from deque. INDEX can be wrapped."
  (get dq (fol.wrappers:fol-value index) default))

(defmethod conj ((dq <deque>) item &rest more-items)
  "Add items to the end of the deque (like push-end)."
  (let ((result dq))
    (setf result (push-end item result))
    (dolist (it more-items)
      (setf result (push-end it result)))
    result))

(defmethod add ((dq <deque>) item &optional value)
  "Add ITEM to the end of the deque."
  (declare (ignore value))
  (push-end item dq))

(defmethod remove ((dq <deque>) item)
  "Return a new deque with the first occurrence of ITEM removed."
  (let ((raw-item (fol.wrappers:fol-value item))
        (items (pslot-value dq 'fol.collection::items))
        (found nil)
        (new-items (fset:empty-seq)))
    (fset:do-seq (elem items)
      (if (and (not found) (equal elem raw-item))
          (setf found t)
          (setf new-items (fset:with-last new-items elem))))
    (make-instance '<deque> :items new-items)))

;;; --- Standard peek/pop/push for <deque> (operate on back like vector) ---

(defmethod peek ((dq <deque>) &optional indices)
  "Return the last (end) element of the deque, or NIL if empty."
  (declare (ignore indices))
  (peek-end dq))

(defmethod pop ((dq <deque>))
  "Return a new deque without the last element."
  (pop-end dq))

(defmethod push (item (dq <deque>))
  "Add ITEM to the end of the deque."
  (push-end item dq))

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

(defgeneric nth (coll n)
  (:documentation "Return the Nth element (0-indexed) of COLL, or NIL if not present.
   Like Clojure's nth, this is 0-indexed. Arguments are (nth coll n)."))

(defmethod nth ((lst <list>) (n integer))
  "Get Nth element from a <list>."
  (get lst n nil))

(defmethod nth ((v <vector>) (n integer))
  "Get Nth element from a <vector>."
  (get v n nil))

(defmethod nth ((ls <lazy-seq>) (n integer))
  "Get Nth element from a <lazy-seq>."
  (let ((current ls))
    (dotimes (i n)
      (setf current (rest current))
      (when (null current)
        (return-from nth nil)))
    (first current)))

(defmethod nth ((lst cons) (n integer))
  "Get Nth element from a CL list."
  (cl:nth n lst))

(defmethod nth ((lst null) (n integer))
  "Nth of nil is nil."
  nil)

(defmethod nth (coll (n fol.classes:<number>))
  "Allow wrapped numbers as index."
  (nth coll (fol.wrappers:fol-value n)))

(defmethod nth-element ((lst <list>) (n integer))
  "Get the Nth element from the list."
  (get lst n nil))

(defmethod nth-element ((lst <list>) (n fol.classes:<number>))
  "Get the Nth element from the list. N can be wrapped."
  (get lst (fol.wrappers:fol-value n) nil))


;;; --- Sequence protocol for <lazy-seq> ---

(defmethod seq ((ls <lazy-seq>))
  "Return the lazy sequence as-is without forcing realization.
   Lazy sequences implement the seq protocol (first, rest) so they can be used
   directly as seqs. This preserves laziness."
  ;; Only check if the lazy-seq would be empty by peeking at realization
  ;; without fully forcing it
  (if (fol.collection:lazy-seq-realized-p ls)
      ;; If already realized, check the cached result
      (let ((cached (fol.collection::lazy-seq-cached ls)))
        (if cached ls nil))
      ;; Not realized yet - return the lazy-seq itself to preserve laziness
      ls))

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
                   (fol.collection::%dict-key key))
    (if found val default)))

(defmethod get ((dict <sorted-dict>) key &optional default)
  "Look up KEY in sorted-dict (uses SYCAMORE tree-map)."
  (multiple-value-bind (val found)
      (sycamore:tree-map-find (pslot-value dict 'fol.collection::items)
                              (fol.wrappers:fol-value key))
    (if found val default)))

(defmethod contains? ((dict <sorted-dict>) key)
  "Check if KEY is in sorted-dict (uses SYCAMORE tree-map)."
  (multiple-value-bind (val found)
      (sycamore:tree-map-find (pslot-value dict 'fol.collection::items)
                              (fol.wrappers:fol-value key))
    (declare (ignore val))
    (if found t nil)))

(defmethod get ((vec <vector>) (index integer) &optional default)
  "Get element at INDEX from vector. Returns raw value."
  (let ((seq (pslot-value vec 'fol.collection::items)))
    (if (and (>= index 0) (< index (fset:size seq)))
        (fset:lookup seq index)
        default)))

(defmethod get ((vec <vector>) (index fol.classes:<number>) &optional default)
  "Get element at INDEX from vector. INDEX can be wrapped."
  (get vec (fol.wrappers:fol-value index) default))

(defmethod get ((arr <array>) (indices <vector>) &optional default)
  "Get element from array at INDICES (a vector of integers)."
  (let* ((dim-seq (pslot-value (pslot-value arr 'fol.collection::dimensions) 'fol.collection::items))
         (idx-seq (pslot-value indices 'fol.collection::items))
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
          (let ((val (fset:lookup (pslot-value arr 'fol.collection::items) flat-index)))
            (or val default))))))

;;; --- GET for Sets ---
;;; For sets, get returns the key itself if present, default otherwise.
;;; This enables Clojure-style (set key) => key or nil semantics.

(defmethod get ((s <set>) key &optional default)
  "Get KEY from set: returns KEY if present, DEFAULT otherwise."
  (let ((raw-key (fol.wrappers:fol-value key)))
    (multiple-value-bind (val found)
        (fset:lookup (pslot-value s 'fol.collection::items) raw-key)
      (declare (ignore val))
      (if found raw-key default))))

(defmethod get ((s <sorted-set>) key &optional default)
  "Get KEY from sorted-set: returns KEY if present, DEFAULT otherwise."
  (let ((raw-key (fol.wrappers:fol-value key)))
    (if (fset:contains? (pslot-value s 'fol.collection::items) raw-key)
        raw-key
        default)))

(defmethod get ((s <ordered-set>) key &optional default)
  "Get KEY from ordered-set: returns KEY if present, DEFAULT otherwise."
  (let ((raw-key (fol.wrappers:fol-value key)))
    (multiple-value-bind (val found)
        (fset:lookup (pslot-value s 'fol.collection::items) raw-key)
      (declare (ignore val))
      (if found raw-key default))))

(defmethod get ((s <dense-int-set>) (key integer) &optional default)
  "Get KEY from dense-int-set: returns KEY if present, DEFAULT otherwise."
  (let* ((base (pslot-value s 'fol.collection::base))
         (bits (pslot-value s 'fol.collection::bits))
         (idx (- key base)))
    (if (and (>= idx 0)
             (< idx (length bits))
             (= 1 (aref bits idx)))
        key
        default)))

(defmethod get ((s <dense-int-set>) key &optional default)
  "Get KEY from dense-int-set with wrapped key."
  (let ((raw-key (fol.wrappers:fol-value key)))
    (if (integerp raw-key)
        (get s raw-key default)
        default)))

(defmethod get ((s <sorted-set-by>) key &optional default)
  "Get KEY from sorted-set-by: returns KEY if present, DEFAULT otherwise."
  (let ((raw-key (fol.wrappers:fol-value key))
        (elems (pslot-value s 'fol.collection::elements)))
    (if (member raw-key elems :test #'equal)
        raw-key
        default)))


;;; ============================================================================
;;; GENERIC COLLECTION PROTOCOLS
;;; ============================================================================

;;; 1. SIZE
(defgeneric size (collection)
  (:documentation "Returns the number of elements in the collection."))

(defmethod size ((c <collection>))
  (fset:size (pslot-value c 'fol.collection::items)))

(defmethod size ((d <sorted-dict>))
  "Return number of entries in sorted-dict (uses SYCAMORE tree-map)."
  (sycamore:tree-map-count (pslot-value d 'fol.collection::items)))

(defmethod size ((d <array-dict>))
  "Return number of entries in array-dict."
  (fset:size (pslot-value d 'fol.collection::order)))

(defmethod size ((d <ordered-dict>))
  "Return number of entries in ordered-dict."
  (fset:size (pslot-value d 'fol.collection::order)))

(defmethod size ((d <priority-dict>))
  "Return number of entries in priority-dict."
  (fset:size (pslot-value d 'fol.collection::items)))

(defmethod size ((s <sorted-set>))
  "Return number of elements in sorted-set."
  (fset:size (pslot-value s 'fol.collection::items)))

(defmethod size ((s <ordered-set>))
  "Return number of elements in ordered-set."
  (fset:size (pslot-value s 'fol.collection::items)))

(defmethod size ((s <dense-int-set>))
  "Return number of elements in dense-int-set (count of 1 bits)."
  (count 1 (pslot-value s 'fol.collection::bits)))

(defmethod size ((s <sorted-set-by>))
  "Return number of elements in sorted-set-by."
  (length (pslot-value s 'fol.collection::elements)))

;;; 2. EMPTY?
(defgeneric empty? (collection)
  (:documentation "Returns T if the collection is empty, NIL otherwise."))

(defmethod empty? ((c <collection>))
  (if (fset:empty? (pslot-value c 'fol.collection::items))
      t
      nil))

(defmethod empty? ((s <sorted-set>))
  "Check if sorted-set is empty."
  (if (fset:empty? (pslot-value s 'fol.collection::items))
      t
      nil))

(defmethod empty? ((s <ordered-set>))
  "Check if ordered-set is empty."
  (if (fset:empty? (pslot-value s 'fol.collection::items))
      t
      nil))

(defmethod empty? ((s <dense-int-set>))
  "Check if dense-int-set is empty (no 1 bits)."
  (if (zerop (count 1 (pslot-value s 'fol.collection::bits)))
      t
      nil))

(defmethod empty? ((s <sorted-set-by>))
  "Check if sorted-set-by is empty."
  (null (pslot-value s 'fol.collection::elements)))

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
              do (cl:push (current iter) result)
                 (next iter))
        (apply #'make-list (nreverse result)))))

(defmethod seq ((lst <list>))
  "For lists, return the list itself or NIL if empty."
  (if (zerop (list-size lst))
      nil
      lst))

(defmethod seq ((v <vector>))
  "For vectors, convert to a list."
  (let ((items (pslot-value v 'fol.collection::items)))
    (if (fset:empty? items)
        nil
        (apply #'make-list (fset:convert 'list items)))))

(defmethod seq ((d <dict>))
  "For dicts, return a list of (key . value) pairs."
  (let ((items (pslot-value d 'fol.collection::items)))
    (if (fset:empty? items)
        nil
        (let ((pairs nil))
          (fset:do-map (k v items)
            (cl:push (cons k v) pairs))
          (apply #'make-list (nreverse pairs))))))

(defmethod seq ((d <array-dict>))
  "For array-dicts, return a list of (key . value) pairs in insertion order."
  (let ((order (pslot-value d 'fol.collection::order))
        (items (pslot-value d 'fol.collection::items)))
    (if (fset:empty? order)
        nil
        (let ((pairs nil))
          (fset:do-seq (k order)
            (let ((v (fset:lookup items k)))
              (cl:push (cons k v) pairs)))
          (apply #'make-list (nreverse pairs))))))

(defmethod seq ((d <ordered-dict>))
  "For ordered-dicts, return a list of (key . value) pairs in insertion order."
  (let ((order (pslot-value d 'fol.collection::order))
        (items (pslot-value d 'fol.collection::items)))
    (if (fset:empty? order)
        nil
        (let ((pairs nil))
          (fset:do-seq (k order)
            (let ((v (fset:lookup items k)))
              (cl:push (cons k v) pairs)))
          (apply #'make-list (nreverse pairs))))))

(defmethod seq ((s <set>))
  "For sets, return a list of elements (keys only)."
  (let ((items (pslot-value s 'fol.collection::items)))
    (if (fset:empty? items)
        nil
        (let ((elems nil))
          (fset:do-map (k v items)
            (declare (ignore v))
            (cl:push k elems))
          (apply #'make-list (nreverse elems))))))

(defmethod seq ((s <sorted-set>))
  "For sorted-sets, return a list of elements in sorted order."
  (let ((items (pslot-value s 'fol.collection::items)))
    (if (fset:empty? items)
        nil
        (let ((elems nil))
          (fset:do-set (item items)
            (cl:push item elems))
          ;; Elements are pushed in sorted order, so reverse to get ascending
          (apply #'make-list (nreverse elems))))))

(defmethod seq ((s <ordered-set>))
  "For ordered-sets, return a list of elements in insertion order."
  (let ((order (pslot-value s 'fol.collection::order)))
    (if (fset:empty? order)
        nil
        (apply #'make-list (fset:convert 'list order)))))

(defmethod seq ((s <dense-int-set>))
  "For dense-int-sets, return a list of elements in ascending order."
  (let ((base (pslot-value s 'fol.collection::base))
        (bits (pslot-value s 'fol.collection::bits))
        (elems nil))
    (loop for i from (1- (length bits)) downto 0
          when (= 1 (aref bits i))
          do (cl:push (+ base i) elems))
    (if elems
        (apply #'make-list elems)
        nil)))

(defmethod seq ((s <sorted-set-by>))
  "For sorted-set-by, return a list of elements in sorted order."
  (let ((elems (pslot-value s 'fol.collection::elements)))
    (if elems
        (apply #'make-list elems)
        nil)))

(defmethod seq ((b <bag>))
  "For bags, return a list with elements repeated by their count."
  (let ((items (pslot-value b 'fol.collection::items)))
    (if (fset:empty? items)
        nil
        (let ((elems nil))
          (fset:do-map (elem count items)
            (dotimes (i count)
              (cl:push elem elems)))
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
      (fset:lookup (pslot-value c 'fol.collection::items) (fol.collection::%dict-key item))
    (declare (ignore val))
    (if found t nil)))

(defmethod contains? ((v <vector>) item)
  (let* ((raw-item (fol.wrappers:fol-value item))
         (seq (pslot-value v 'fol.collection::items))
         (as-list (fset:convert 'list seq)))
    (if (cl:position raw-item as-list :test #'equal)
        t
        nil)))

(defmethod contains? ((s <sorted-set>) item)
  "Check if ITEM is in sorted-set."
  (if (fset:contains? (pslot-value s 'fol.collection::items) (fol.wrappers:fol-value item))
      t
      nil))

(defmethod contains? ((s <ordered-set>) item)
  "Check if ITEM is in ordered-set."
  (multiple-value-bind (val found)
      (fset:lookup (pslot-value s 'fol.collection::items) (fol.wrappers:fol-value item))
    (declare (ignore val))
    (if found t nil)))

(defmethod contains? ((s <dense-int-set>) item)
  "Check if ITEM is in dense-int-set."
  (let* ((raw (fol.wrappers:fol-value item))
         (base (pslot-value s 'fol.collection::base))
         (bits (pslot-value s 'fol.collection::bits))
         (idx (- raw base)))
    (if (and (integerp raw)
             (>= idx 0)
             (< idx (length bits))
             (= 1 (aref bits idx)))
        t
        nil)))

(defmethod contains? ((s <sorted-set-by>) item)
  "Check if ITEM is in sorted-set-by."
  (let ((raw (fol.wrappers:fol-value item))
        (elems (pslot-value s 'fol.collection::elements)))
    (if (member raw elems :test #'equal)
        t
        nil)))

;;; 4. ADD (Functional Insertion)
(defgeneric add (collection item &optional value)
  (:documentation "Returns a new collection with ITEM added.
   ITEM and VALUE are unwrapped before storage."))

(defmethod add ((d <dict>) key &optional value)
  (unless value (error "Adding to a <dict> requires a value."))
  (let ((new-map (fset:with (pslot-value d 'fol.collection::items)
                            (fol.wrappers:fol-value key)
                            (fol.wrappers:fol-value value))))
    (make-instance (class-of d) :items new-map)))

(defmethod add ((d <sorted-dict>) key &optional value)
  "Add key-value pair to sorted-dict (uses SYCAMORE tree-map)."
  (unless value (error "Adding to a <sorted-dict> requires a value."))
  (let ((new-tree (sycamore:tree-map-insert (pslot-value d 'fol.collection::items)
                                             (fol.wrappers:fol-value key)
                                             (fol.wrappers:fol-value value))))
    (make-instance '<sorted-dict> :items new-tree)))

(defmethod add ((d <array-dict>) key &optional value)
  "Add key-value pair to array-dict (maintains insertion order)."
  (unless value (error "Adding to an <array-dict> requires a value."))
  (let* ((raw-key (fol.wrappers:fol-value key))
         (raw-val (fol.wrappers:fol-value value))
         (items (pslot-value d 'fol.collection::items))
         (order (pslot-value d 'fol.collection::order))
         (max-size (pslot-value d 'fol.collection::max-size)))
    (multiple-value-bind (old-val found) (fset:lookup items raw-key)
      (declare (ignore old-val))
      (let ((new-items (fset:with items raw-key raw-val))
            (new-order (if found
                           order
                           (progn
                             (when (>= (fset:size order) max-size)
                               (error "ARRAY-DICT size limit exceeded: cannot add more than ~D entries" max-size))
                             (fset:with-last order raw-key)))))
        (make-instance '<array-dict> :items new-items :order new-order :max-size max-size)))))

(defmethod add ((d <ordered-dict>) key &optional value)
  "Add key-value pair to ordered-dict (maintains insertion order)."
  (unless value (error "Adding to an <ordered-dict> requires a value."))
  (let* ((raw-key (fol.wrappers:fol-value key))
         (raw-val (fol.wrappers:fol-value value))
         (items (pslot-value d 'fol.collection::items))
         (order (pslot-value d 'fol.collection::order)))
    (multiple-value-bind (old-val found) (fset:lookup items raw-key)
      (declare (ignore old-val))
      (let ((new-items (fset:with items raw-key raw-val))
            (new-order (if found order (fset:with-last order raw-key))))
        (make-instance '<ordered-dict> :items new-items :order new-order)))))

(defmethod add ((d <priority-dict>) key &optional value)
  "Add key-value pair to priority-dict (maintains priority order)."
  (unless value (error "Adding to a <priority-dict> requires a value."))
  (let* ((raw-key (fol.wrappers:fol-value key))
         (raw-val (fol.wrappers:fol-value value))
         (items (pslot-value d 'fol.collection::items))
         (priorities (pslot-value d 'fol.collection::priorities)))
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
      (setf priorities (fset:with priorities raw-val item-set)))
    (make-instance '<priority-dict> :items items :priorities priorities)))

(defmethod add ((s <set>) item &optional value)
  (declare (ignore value))
  (let ((new-map (fset:with (pslot-value s 'fol.collection::items)
                            (fol.wrappers:fol-value item) t)))
    (make-instance (class-of s) :items new-map)))

(defmethod add ((s <sorted-set>) item &optional value)
  "Add ITEM to sorted-set, maintaining sorted order."
  (declare (ignore value))
  (let ((new-set (fset:with (pslot-value s 'fol.collection::items)
                            (fol.wrappers:fol-value item))))
    (make-instance (class-of s) :items new-set)))

(defmethod add ((s <ordered-set>) item &optional value)
  "Add ITEM to ordered-set, maintaining insertion order."
  (declare (ignore value))
  (let* ((raw (fol.wrappers:fol-value item))
         (items (pslot-value s 'fol.collection::items))
         (order (pslot-value s 'fol.collection::order)))
    (multiple-value-bind (val found) (fset:lookup items raw)
      (declare (ignore val))
      (if found
          ;; Already present, return same set
          s
          ;; Add to both items and order
          (make-instance (class-of s)
                         :items (fset:with items raw t)
                         :order (fset:with-last order raw))))))

(defmethod add ((s <dense-int-set>) item &optional value)
  "Add ITEM to dense-int-set."
  (declare (ignore value))
  (let* ((raw (fol.wrappers:fol-value item))
         (base (pslot-value s 'fol.collection::base))
         (bits (pslot-value s 'fol.collection::bits))
         (idx (- raw base)))
    (unless (integerp raw)
      (error "DENSE-INT-SET only accepts integers, got ~S" raw))
    (unless (and (>= idx 0) (< idx (length bits)))
      (error "Integer ~A is outside range [~A, ~A]" raw base (+ base (1- (length bits)))))
    ;; Create new bit vector with the bit set
    (let ((new-bits (copy-seq bits)))
      (setf (aref new-bits idx) 1)
      (make-instance (class-of s) :base base :bits new-bits))))

(defmethod add ((s <sorted-set-by>) item &optional value)
  "Add ITEM to sorted-set-by, maintaining sort order."
  (declare (ignore value))
  (let* ((raw (fol.wrappers:fol-value item))
         (elems (pslot-value s 'fol.collection::elements))
         (comparator (pslot-value s 'fol.collection::comparator)))
    ;; Check if already present
    (if (member raw elems :test #'equal)
        s  ; Return unchanged
        ;; Insert in sorted position
        (let ((new-elems
               (if (null elems)
                   (list raw)
                   (if (funcall comparator raw (car elems))
                       (cons raw elems)
                       (let ((result (list (car elems)))
                             (rest (cdr elems))
                             (inserted nil))
                         (loop while rest
                               do (if (and (not inserted)
                                           (funcall comparator raw (car rest)))
                                      (progn
                                        (setf result (nconc result (list raw)))
                                        (setf inserted t)))
                                  ;; Always add current element to result
                                  (setf result (nconc result (list (car rest))))
                                  (setf rest (cdr rest)))
                         (unless inserted
                           (setf result (nconc result (list raw))))
                         result)))))
          (make-instance '<sorted-set-by>
                         :comparator comparator
                         :elements new-elems
                         :items (fset:empty-set))))))

(defmethod add ((b <bag>) item &optional value)
  (declare (ignore value))
  (let* ((raw-item (fol.wrappers:fol-value item))
         (map (pslot-value b 'fol.collection::items))
         (count (or (fset:lookup map raw-item) 0)))
    (make-instance (class-of b) :items (fset:with map raw-item (1+ count)))))

(defmethod add ((v <vector>) item &optional value)
  (declare (ignore value))
  (let ((new-seq (fset:with-last (pslot-value v 'fol.collection::items)
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

(defmethod conj ((d <dict>) key &rest args)
  "Add a key-value pair to a dict: (conj dict key value).
   If key already exists, its value is updated to the new value."
  (unless (= 1 (length args))
    (error "CONJ on <dict> requires exactly one value argument: (conj dict key value)"))
  (add d key (cl:first args)))

(defmethod conj ((a <array>) item &rest more-items)
  "Arrays do not support conj."
  (declare (ignore item more-items))
  (error "Cannot conj to a fixed-dimension <array>. Use set-nth to modify elements."))

;;; Vector pop and push methods (defined here after vector is fully defined)

(defmethod pop ((v <vector>))
  "Return a new vector without the last element. Returns empty vector if empty."
  (let ((items (pslot-value v 'fol.collection::items)))
    (if (fset:empty? items)
        (make-vector)
        (make-instance '<vector> :items (fset:less-last items)))))

(defmethod push (item (v <vector>))
  "Add ITEM to the end of the vector."
  (conj v item))

;;; 6. REMOVE (Functional Deletion)
(defgeneric remove (collection item)
  (:documentation "Returns a new collection with ITEM removed.
   ITEM is unwrapped before comparison."))

(defmethod remove ((d <dict>) key)
  (make-instance (class-of d)
                 :items (fset:less (pslot-value d 'fol.collection::items)
                                   (fol.wrappers:fol-value key))))

(defmethod remove ((s <set>) item)
  (make-instance (class-of s)
                 :items (fset:less (pslot-value s 'fol.collection::items)
                                   (fol.wrappers:fol-value item))))

(defmethod remove ((s <sorted-set>) item)
  "Remove ITEM from sorted-set."
  (let ((raw (fol.wrappers:fol-value item)))
    (make-instance (class-of s)
                   :items (fset:less (pslot-value s 'fol.collection::items) raw))))

(defmethod remove ((s <ordered-set>) item)
  "Remove ITEM from ordered-set, maintaining insertion order of remaining elements."
  (let* ((raw (fol.wrappers:fol-value item))
         (items (pslot-value s 'fol.collection::items))
         (order (pslot-value s 'fol.collection::order)))
    (multiple-value-bind (val found) (fset:lookup items raw)
      (declare (ignore val))
      (if found
          ;; Remove from both items and order
          (let ((new-order (fset:empty-seq)))
            (fset:do-seq (elem order)
              (unless (equal elem raw)
                (setf new-order (fset:with-last new-order elem))))
            (make-instance (class-of s)
                           :items (fset:less items raw)
                           :order new-order))
          ;; Not present, return same set
          s))))

(defmethod remove ((s <dense-int-set>) item)
  "Remove ITEM from dense-int-set."
  (let* ((raw (fol.wrappers:fol-value item))
         (base (pslot-value s 'fol.collection::base))
         (bits (pslot-value s 'fol.collection::bits))
         (idx (- raw base)))
    (if (and (integerp raw)
             (>= idx 0)
             (< idx (length bits)))
        ;; Create new bit vector with the bit cleared
        (let ((new-bits (copy-seq bits)))
          (setf (aref new-bits idx) 0)
          (make-instance (class-of s) :base base :bits new-bits))
        ;; Not in range, return same set
        s)))

(defmethod remove ((s <sorted-set-by>) item)
  "Remove ITEM from sorted-set-by."
  (let* ((raw (fol.wrappers:fol-value item))
         (elems (pslot-value s 'fol.collection::elements))
         (comparator (pslot-value s 'fol.collection::comparator)))
    (let ((new-elems (cl:remove raw elems :test #'equal :count 1)))
      (if (equal new-elems elems)
          s  ; Not found, return unchanged
          (make-instance '<sorted-set-by>
                         :comparator comparator
                         :elements new-elems
                         :items (fset:empty-set))))))

(defmethod remove ((b <bag>) item)
  (let* ((raw-item (fol.wrappers:fol-value item))
         (map (pslot-value b 'fol.collection::items))
         (count (fset:lookup map raw-item)))
    (cond
      ((null count) b)
      ((<= count 1) (make-instance (class-of b) :items (fset:less map raw-item)))
      (t (make-instance (class-of b) :items (fset:with map raw-item (1- count)))))))

(defmethod remove ((v <vector>) item)
  (let* ((raw-item (fol.wrappers:fol-value item))
         (seq (pslot-value v 'fol.collection::items))
         (as-list (fset:convert 'list seq))
         (idx (cl:position raw-item as-list :test #'equal)))
    (if idx
        (make-instance (class-of v) :items (fset:less seq idx))
        v)))

;;; 7. DISJ (Clojure-style removal for unordered collections)

;; Internal generic for single-item removal (methods defined later with other set operations)
(defgeneric disj-one (collection key)
  (:documentation "Remove a single KEY from a collection. Internal implementation."))

;; Public function that accepts multiple keys
(defun disj (collection &rest keys)
  "Returns a new collection with KEYS removed.
   For sets: removes all specified keys.
   Accepts multiple keys: (disj #{1 2 3} 2 3) => #{1}"
  (cl:reduce #'disj-one keys :initial-value collection))

;; Base method for <set>
(defmethod disj-one ((s <set>) key)
  "Remove KEY from set."
  (remove s key))

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

(defmethod nth ((s string) (n integer))
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
;;; ASSOC - Associate a key with a value in a collection
;;; ============================================================================

(defgeneric assoc (coll key val)
  (:documentation "Returns a new collection with KEY mapped to VAL.
   For <dict>: associates key with value (like add).
   For <vector>: sets the element at index KEY to VAL.
   KEY must be a non-negative integer for vectors."))

(defmethod assoc ((coll <dict>) key val)
  "Associate KEY with VAL in the dict."
  (add coll key val))

(defmethod assoc ((coll <vector>) key val)
  "Set element at index KEY to VAL in the vector."
  (let ((idx (fol.wrappers:fol-value key)))
    (unless (and (integerp idx) (>= idx 0))
      (error "ASSOC: vector index must be a non-negative integer, got ~A" key))
    (let* ((items (pslot-value coll 'fol.collection::items))
           (len (fset:size items)))
      (unless (< idx len)
        (error "ASSOC: index ~A out of bounds for vector of size ~A" idx len))
      (make-instance '<vector>
                     :items (fset:with items idx (fol.wrappers:fol-value val))))))

;;; ============================================================================
;;; ASSOC-IN - Associate a value at a nested path in a collection
;;; ============================================================================

(defgeneric assoc-in (coll keys val)
  (:documentation "Associates VAL in a nested associative structure.
   KEYS is a sequence of keys identifying the path.
   Returns a new nested structure with the value at the path set to VAL.
   Creates intermediate dicts as needed when path doesn't exist."))

(defun %keys-to-list (keys)
  "Convert KEYS to a CL list for iteration."
  (typecase keys
    (null nil)
    (cons keys)
    (<list> (let ((result nil))
              (do ((lst keys (rest lst)))
                  ((empty? lst) (nreverse result))
                (cl:push (first lst) result))))
    (<vector> (let ((result nil)
                    (items (pslot-value keys 'fol.collection::items)))
                (fset:do-seq (item items)
                  (cl:push item result))
                (nreverse result)))
    (t (error "ASSOC-IN: keys must be a list or vector, got ~A" (type-of keys)))))

(defmethod assoc-in ((coll <dict>) keys val)
  "Associate VAL at the nested path KEYS in the dict."
  (let ((ks (%keys-to-list keys)))
    (if (null ks)
        coll
        (let ((k (car ks))
              (rest-ks (cdr ks)))
          (if (null rest-ks)
              ;; Last key - just assoc the value
              (assoc coll k val)
              ;; More keys - recurse into nested structure
              (let* ((raw-k (fol.wrappers:fol-value k))
                     (items (pslot-value coll 'fol.collection::items))
                     (next-val (fset:lookup items raw-k))
                     (next-coll (if next-val
                                    (if (typep next-val '<dict>)
                                        next-val
                                        (make-dict))
                                    (make-dict))))
                (assoc coll k (assoc-in next-coll rest-ks val))))))))

(defmethod assoc-in ((coll <vector>) keys val)
  "Associate VAL at the nested path KEYS starting with a vector."
  (let ((ks (%keys-to-list keys)))
    (if (null ks)
        coll
        (let ((k (car ks))
              (rest-ks (cdr ks)))
          (if (null rest-ks)
              ;; Last key - just assoc the value
              (assoc coll k val)
              ;; More keys - recurse into nested structure
              (let* ((idx (fol.wrappers:fol-value k))
                     (items (pslot-value coll 'fol.collection::items))
                     (next-val (when (and (integerp idx)
                                          (>= idx 0)
                                          (< idx (fset:size items)))
                                 (fset:lookup items idx)))
                     (next-coll (cond
                                  ((typep next-val '<dict>) next-val)
                                  ((typep next-val '<vector>) next-val)
                                  (t (make-dict)))))
                (assoc coll k (assoc-in next-coll rest-ks val))))))))

;;; ============================================================================
;;; SUB - Extract a subsequence from a collection
;;; ============================================================================

(defgeneric sub (coll start &optional end)
  (:documentation "Returns a subsequence of COLL from START to END (exclusive).
   If END is not provided, returns from START to the end.
   Supported for strings, vectors, and lists.
   Returns an object of the same type as the input."))

(defmethod sub ((s string) start &optional end)
  "Return a substring of S from START to END."
  (let ((s-start (fol.wrappers:fol-value start))
        (s-end (when end (fol.wrappers:fol-value end))))
    (if s-end
        (subseq s s-start s-end)
        (subseq s s-start))))

(defmethod sub ((s fol.classes:<string>) start &optional end)
  "Return a substring of wrapped string S from START to END."
  (let ((str (fol.wrappers:fol-value s))
        (s-start (fol.wrappers:fol-value start))
        (s-end (when end (fol.wrappers:fol-value end))))
    (if s-end
        (subseq str s-start s-end)
        (subseq str s-start))))

(defmethod sub ((coll <vector>) start &optional end)
  "Return a subvector of COLL from START to END."
  (let* ((s-start (fol.wrappers:fol-value start))
         (s-end (when end (fol.wrappers:fol-value end)))
         (items (pslot-value coll 'fol.collection::items))
         (len (fset:size items))
         (actual-end (or s-end len)))
    (unless (and (integerp s-start) (>= s-start 0))
      (error "SUB: start must be a non-negative integer, got ~A" start))
    (unless (and (integerp actual-end) (>= actual-end 0))
      (error "SUB: end must be a non-negative integer, got ~A" end))
    (when (> s-start actual-end)
      (error "SUB: start (~A) cannot be greater than end (~A)" s-start actual-end))
    (make-instance '<vector>
                   :items (fset:subseq items s-start actual-end))))

(defmethod sub ((coll <list>) start &optional end)
  "Return a sublist of COLL from START to END."
  (let* ((s-start (fol.wrappers:fol-value start))
         (s-end (when end (fol.wrappers:fol-value end)))
         (len (list-size coll))
         (actual-end (or s-end len)))
    (unless (and (integerp s-start) (>= s-start 0))
      (error "SUB: start must be a non-negative integer, got ~A" start))
    (unless (and (integerp actual-end) (>= actual-end 0))
      (error "SUB: end must be a non-negative integer, got ~A" end))
    (when (> s-start actual-end)
      (error "SUB: start (~A) cannot be greater than end (~A)" s-start actual-end))
    ;; Build the sublist by skipping start elements and taking (end - start) elements
    (let ((result nil)
          (current coll)
          (idx 0))
      ;; Skip to start
      (loop while (and (< idx s-start) (not (empty? current)))
            do (setf current (rest current))
               (incf idx))
      ;; Collect elements from start to end
      (loop while (and (< idx actual-end) (not (empty? current)))
            do (cl:push (first current) result)
               (setf current (rest current))
               (incf idx))
      (apply #'make-list (nreverse result)))))

;;; ============================================================================
;;; Reverse: Generic Reverse for Collections and Strings
;;; ============================================================================

(defgeneric reverse (coll)
  (:documentation "Return a new collection with elements in reverse order.
   Works on strings, vectors, lists, and CL sequences."))

;;; --- reverse for <vector> ---

(defmethod reverse ((v <vector>))
  "Return a new vector with elements in reverse order."
  (let* ((seq (pslot-value v 'fol.collection::items))
         (len (fset:size seq)))
    (make-instance '<vector>
                   :items (fset:convert 'fset:seq
                                        (loop for i from (1- len) downto 0
                                              collect (fset:@ seq i))))))

;;; --- reverse for <list> ---

(defmethod reverse ((lst <list>))
  "Return a new list with elements in reverse order."
  (labels ((rev-iter (current acc)
             (if (or (null current) (empty? current))
                 acc
                 (rev-iter (rest current)
                           (cl:cons (first current) acc)))))
    (let ((reversed (rev-iter lst nil)))
      (if reversed
          (apply #'make-list reversed)
          (make-list)))))

;;; --- reverse for CL list ---

(defmethod reverse ((lst list))
  "Return a reversed CL list."
  (cl:reverse lst))

;;; --- reverse for strings ---

(defmethod reverse ((s string))
  "Return a string with characters in reverse order."
  (cl:reverse s))

(defmethod reverse ((s fol.classes:<string>))
  "Return a string with characters in reverse order."
  ;; Check if it's a regex pattern - can't reverse those
  (if (typep s 'fol.classes:<re-pattern>)
      (error "REVERSE: Cannot reverse a regex pattern")
      (cl:reverse (fol.wrappers:fol-value s))))


;;; ============================================================================
;;; Index Operations: index-of and last-index-of
;;; ============================================================================
;;; Generic functions for finding the index of a value in ordered collections.

(defgeneric index-of (coll value &optional start)
  (:documentation "Return the index of VALUE in collection COLL, or NIL if not found.
   Searches from index START (default 0) to the end of the collection.
   For strings, VALUE can be a character, string, or regex pattern.
   For lists and vectors, VALUE is compared using EQL."))

;;; --- index-of for <vector> ---

(defmethod index-of ((v <vector>) value &optional (start 0))
  "Find VALUE in a FOL vector, starting from index START."
  (let* ((seq (pslot-value v 'fol.collection::items))
         (len (fset:size seq))
         (raw-value (fol.wrappers:fol-value value))
         (start-idx (fol.wrappers:fol-value start)))
    (loop for i from start-idx below len
          when (eql (fset:@ seq i) raw-value)
            return i
          finally (return nil))))

;;; --- index-of for <list> ---

(defmethod index-of ((lst <list>) value &optional (start 0))
  "Find VALUE in a FOL list, starting from index START."
  (let* ((raw-value (fol.wrappers:fol-value value))
         (start-idx (fol.wrappers:fol-value start)))
    ;; Skip to start position
    (loop for current = lst then (rest current)
          for idx from 0
          while (not (empty? current))
          when (and (>= idx start-idx)
                    (eql (first current) raw-value))
            return idx
          finally (return nil))))

;;; --- index-of for CL lists ---

(defmethod index-of ((lst list) value &optional (start 0))
  "Find VALUE in a CL list, starting from index START."
  (let* ((raw-value (fol.wrappers:fol-value value))
         (start-idx (fol.wrappers:fol-value start)))
    (loop for elem in (nthcdr start-idx lst)
          for idx from start-idx
          when (eql elem raw-value)
            return idx
          finally (return nil))))

;;; --- index-of for strings ---

(defmethod index-of ((s string) (value character) &optional (start 0))
  "Find character VALUE in string S, starting from index START."
  (let ((start-idx (fol.wrappers:fol-value start)))
    (cl:position value s :start start-idx)))

(defmethod index-of ((s string) (value fol.classes:<char>) &optional (start 0))
  "Find wrapped character VALUE in string S."
  (index-of s (fol.wrappers:fol-value value) start))

(defmethod index-of ((s string) (value string) &optional (start 0))
  "Find substring VALUE in string S, starting from index START."
  (let ((start-idx (fol.wrappers:fol-value start)))
    (cl:search value s :start2 start-idx)))

(defmethod index-of ((s string) (value fol.classes:<string>) &optional (start 0))
  "Find wrapped substring VALUE in string S."
  ;; Check if it's a <re-pattern> (subclass of <string>)
  (if (typep value 'fol.classes:<re-pattern>)
      ;; Use regex search
      (let ((start-idx (fol.wrappers:fol-value start)))
        (multiple-value-bind (match-start match-end)
            (cl-ppcre:scan (fol.wrappers:fol-value value) s :start start-idx)
          (declare (ignore match-end))
          match-start))
      ;; Plain string search
      (index-of s (fol.wrappers:fol-value value) start)))

(defmethod index-of ((s string) (value fol.classes:<re-pattern>) &optional (start 0))
  "Find regex pattern VALUE in string S, starting from index START."
  (let ((start-idx (fol.wrappers:fol-value start)))
    (multiple-value-bind (match-start match-end)
        (cl-ppcre:scan (fol.wrappers:fol-value value) s :start start-idx)
      (declare (ignore match-end))
      match-start)))

;;; --- index-of for wrapped strings ---

(defmethod index-of ((s fol.classes:<string>) value &optional (start 0))
  "Find VALUE in wrapped string S."
  ;; Check if it's a <re-pattern> (subclass of <string>)
  (if (typep s 'fol.classes:<re-pattern>)
      (error "INDEX-OF: Cannot search within a regex pattern")
      (index-of (fol.wrappers:fol-value s) value start)))


;;; ============================================================================
;;; last-index-of Generic Function
;;; ============================================================================

(defgeneric last-index-of (coll value &optional start)
  (:documentation "Return the index of the last occurrence of VALUE in collection COLL, or NIL if not found.
   Searches from the start of the collection to index START (if provided) or the end.
   For strings, VALUE can be a character or string.
   For lists and vectors, VALUE is compared using EQL."))

;;; --- last-index-of for <vector> ---

(defmethod last-index-of ((v <vector>) value &optional start)
  "Find last occurrence of VALUE in a FOL vector."
  (let* ((seq (pslot-value v 'fol.collection::items))
         (len (fset:size seq))
         (raw-value (fol.wrappers:fol-value value))
         (end-idx (if start
                      (cl:min (cl:1+ (fol.wrappers:fol-value start)) len)
                      len)))
    (loop for i from (1- end-idx) downto 0
          when (eql (fset:@ seq i) raw-value)
            return i
          finally (return nil))))

;;; --- last-index-of for <list> ---

(defmethod last-index-of ((lst <list>) value &optional start)
  "Find last occurrence of VALUE in a FOL list."
  (let* ((raw-value (fol.wrappers:fol-value value))
         (end-idx (if start
                      (cl:1+ (fol.wrappers:fol-value start))
                      (size lst)))
         (result nil))
    ;; Traverse and remember the last match
    (loop for current = lst then (rest current)
          for idx from 0 below end-idx
          while current
          when (eql (first current) raw-value)
            do (setf result idx)
          finally (return result))))

;;; --- last-index-of for CL lists ---

(defmethod last-index-of ((lst list) value &optional start)
  "Find last occurrence of VALUE in a CL list."
  (let* ((raw-value (fol.wrappers:fol-value value))
         (result nil))
    (if start
        (let ((end-idx (cl:1+ (fol.wrappers:fol-value start))))
          (loop for elem in lst
                for idx from 0 below end-idx
                when (eql elem raw-value)
                  do (setf result idx)
                finally (return result)))
        (loop for elem in lst
              for idx from 0
              when (eql elem raw-value)
                do (setf result idx)
              finally (return result)))))

;;; --- last-index-of for strings ---

(defmethod last-index-of ((s string) (value character) &optional start)
  "Find last occurrence of character VALUE in string S."
  (let ((end-idx (if start
                     (cl:min (cl:1+ (fol.wrappers:fol-value start)) (cl:length s))
                     (cl:length s))))
    (cl:position value s :end end-idx :from-end t)))

(defmethod last-index-of ((s string) (value fol.classes:<char>) &optional start)
  "Find last occurrence of wrapped character VALUE in string S."
  (last-index-of s (fol.wrappers:fol-value value) start))

(defmethod last-index-of ((s string) (value string) &optional start)
  "Find last occurrence of substring VALUE in string S."
  (let ((end-idx (if start
                     (cl:min (cl:1+ (fol.wrappers:fol-value start)) (cl:length s))
                     (cl:length s))))
    (cl:search value s :end2 end-idx :from-end t)))

(defmethod last-index-of ((s string) (value fol.classes:<string>) &optional start)
  "Find last occurrence of wrapped substring VALUE in string S."
  ;; For <re-pattern>, we don't support last-index-of
  (if (typep value 'fol.classes:<re-pattern>)
      (error "LAST-INDEX-OF: Regex patterns not supported for last-index-of")
      (last-index-of s (fol.wrappers:fol-value value) start)))

;;; --- last-index-of for wrapped strings ---

(defmethod last-index-of ((s fol.classes:<string>) value &optional start)
  "Find last occurrence of VALUE in wrapped string S."
  (if (typep s 'fol.classes:<re-pattern>)
      (error "LAST-INDEX-OF: Cannot search within a regex pattern")
      (last-index-of (fol.wrappers:fol-value s) value start)))

;;; ============================================================================
;;; RSEQ: Reversed Sequence View
;;; ============================================================================
;;; Returns a seq of the items in an ordered collection in reverse order.

(defgeneric rseq (coll)
  (:documentation "Return a lazy seq of the items in COLL in reverse order.
   Only works on ordered collections (vectors, lists, arrays).
   Returns NIL for empty collections."))

(defmethod rseq ((v <vector>))
  "Return a lazy seq of vector elements in reverse order."
  (if (empty? v)
      nil
      (let* ((items (pslot-value v 'fol.collection::items))
             (len (fset:size items)))
        (cl:labels ((lazy-rseq (idx)
                      (fol.collection:make-lazy-seq
                       (lambda ()
                         (if (cl:< idx 0)
                             nil
                             (cl:cons (fset:@ items idx) (lazy-rseq (cl:1- idx))))))))
          (lazy-rseq (cl:1- len))))))

(defmethod rseq ((lst <list>))
  "Return a lazy seq of list elements in reverse order."
  (if (empty? lst)
      nil
      ;; Collect elements then return lazy seq
      (let ((elems nil))
        (loop for current = lst then (list-rest current)
              while (and current (cl:> (list-size current) 0))
              do (cl:push (list-first current) elems))
        (cl:labels ((lazy-rseq (remaining)
                      (fol.collection:make-lazy-seq
                       (lambda ()
                         (if remaining
                             (cl:cons (car remaining) (lazy-rseq (cdr remaining)))
                             nil)))))
          (lazy-rseq elems)))))

(defmethod rseq ((arr <array>))
  "Return a lazy seq of array elements in reverse order (flattened)."
  (if (empty? arr)
      nil
      (let* ((items (pslot-value arr 'fol.collection::items))
             (len (fset:size items)))
        (cl:labels ((lazy-rseq (idx)
                      (fol.collection:make-lazy-seq
                       (lambda ()
                         (if (cl:< idx 0)
                             nil
                             (cl:cons (fset:@ items idx) (lazy-rseq (cl:1- idx))))))))
          (lazy-rseq (cl:1- len))))))

(defmethod rseq ((lst list))
  "Return a lazy seq of CL list elements in reverse order."
  (if (null lst)
      nil
      (let ((reversed (cl:reverse lst)))
        (cl:labels ((lazy-rseq (remaining)
                      (fol.collection:make-lazy-seq
                       (lambda ()
                         (if remaining
                             (cl:cons (car remaining) (lazy-rseq (cdr remaining)))
                             nil)))))
          (lazy-rseq reversed)))))

;;; ============================================================================
;;; UPDATE: Update a value by applying a function
;;; ============================================================================
;;; Updates the value at key k by applying function f to the current value.

(defgeneric update (coll k f &rest args)
  (:documentation "Return a new collection with the value at key K updated by
   applying function F to the current value and any additional ARGS.
   For dicts: (update m k f) => (assoc m k (f (get m k)))
   For vectors: (update v idx f) => (assoc v idx (f (get v idx)))
   If the key doesn't exist, F is called with NIL."))

(defmethod update ((d <dict>) k f &rest args)
  "Update the value at key K in dict D by applying F."
  (let* ((raw-key (fol.wrappers:fol-value k))
         (current-val (get d raw-key))
         (new-val (apply f current-val args)))
    (add d raw-key new-val)))

(defmethod update ((v <vector>) k f &rest args)
  "Update the value at index K in vector V by applying F."
  (let* ((idx (fol.wrappers:fol-value k))
         (current-val (get v idx))
         (new-val (apply f current-val args)))
    (assoc v idx new-val)))

;;; ============================================================================
;;; UPDATE-IN: Update a value in a nested structure
;;; ============================================================================
;;; Updates the value in a nested associative structure by applying a function.

(defgeneric update-in (coll ks f &rest args)
  (:documentation "Return a new nested structure with the value at path KS updated
   by applying function F to the current value and any additional ARGS.
   KS is a vector of keys specifying the path to the value.
   Creates intermediate dicts if they don't exist."))

(defmethod update-in ((d <dict>) (ks <vector>) f &rest args)
  "Update the value at path KS in dict D by applying F."
  (let ((keys-size (size ks)))
    (cond
      ((cl:= 0 keys-size)
       (error "UPDATE-IN: keys vector cannot be empty"))
      ((cl:= 1 keys-size)
       (apply #'update d (get ks 0) f args))
      (t
       (let* ((k (get ks 0))
              (raw-key (fol.wrappers:fol-value k))
              (rest-keys (sub ks 1))
              (nested (get d raw-key))
              (nested-or-empty (if nested nested (make-dict))))
         (add d raw-key (apply #'update-in nested-or-empty rest-keys f args)))))))

(defmethod update-in ((v <vector>) (ks <vector>) f &rest args)
  "Update the value at path KS in vector V by applying F."
  (let ((keys-size (size ks)))
    (cond
      ((cl:= 0 keys-size)
       (error "UPDATE-IN: keys vector cannot be empty"))
      ((cl:= 1 keys-size)
       (apply #'update v (get ks 0) f args))
      (t
       (let* ((idx (fol.wrappers:fol-value (get ks 0)))
              (rest-keys (sub ks 1))
              (nested (get v idx))
              (nested-or-empty (if nested nested (make-dict))))
         (assoc v idx (apply #'update-in nested-or-empty rest-keys f args)))))))

;;; ============================================================================
;;; REDUCE: Reduce over a collection
;;; ============================================================================
;;; Reduces a collection using a binary function.

(defgeneric reduce (f init coll)
  (:documentation "Reduce COLL using binary function F with initial value INIT.
   F is a function of 2 arguments: accumulator and element.
   INIT is the initial accumulator value.
   Supports early termination with reduced."))

(defmethod reduce (f init coll)
  "Default reduce implementation using seq/first/rest."
  (let ((s (seq coll))
        (acc init))
    (loop until (cl:or (null s) (empty? s)
                       (<reduced>? acc))
          do (setf acc (funcall f acc (first s)))
             (setf s (rest s)))
    (if (<reduced>? acc)
        (unreduced acc)
        acc)))

;;; ============================================================================
;;; REDUCE-KV: Reduce over key-value pairs
;;; ============================================================================
;;; Reduces an associative collection using a function that takes
;;; accumulator, key, and value.

(defgeneric reduce-kv (f init coll)
  (:documentation "Reduce over the key-value pairs of COLL.
   F is a function of 3 arguments: accumulator, key, and value.
   INIT is the initial accumulator value.
   For vectors, keys are indices (0, 1, 2, ...).
   For dicts, keys are the map keys.
   Supports early termination with reduced."))

(defmethod reduce-kv (f init (d <dict>))
  "Reduce over key-value pairs in dict D."
  (let ((items (pslot-value d 'fol.collection::items))
        (acc init))
    (fset:do-map (k v items)
      (when (<reduced>? acc)
        (return-from reduce-kv (unreduced acc)))
      (setf acc (funcall f acc k v)))
    (if (<reduced>? acc)
        (unreduced acc)
        acc)))

(defmethod reduce-kv (f init (v <vector>))
  "Reduce over index-value pairs in vector V."
  (let* ((items (pslot-value v 'fol.collection::items))
         (len (fset:size items))
         (acc init))
    (loop for idx from 0 below len
          do (when (<reduced>? acc)
               (return-from reduce-kv (unreduced acc)))
             (setf acc (funcall f acc idx (fset:@ items idx))))
    (if (<reduced>? acc)
        (unreduced acc)
        acc)))

;;; ============================================================================
;;; SET OPERATIONS: conj and disj for specialized set types
;;; ============================================================================

(defmethod conj ((s <sorted-set>) item &rest more-items)
  "Add items to a sorted-set."
  (let ((result (add s item)))
    (dolist (it more-items)
      (setf result (add result it)))
    result))

(defmethod conj ((s <ordered-set>) item &rest more-items)
  "Add items to an ordered-set, maintaining insertion order."
  (let ((result (add s item)))
    (dolist (it more-items)
      (setf result (add result it)))
    result))

(defmethod conj ((s <int-set>) item &rest more-items)
  "Add items to an int-set."
  (let ((result (add s item)))
    (dolist (it more-items)
      (setf result (add result it)))
    result))

(defmethod conj ((s <dense-int-set>) item &rest more-items)
  "Add items to a dense-int-set."
  (let ((result (add s item)))
    (dolist (it more-items)
      (setf result (add result it)))
    result))

(defmethod conj ((s <sorted-set-by>) item &rest more-items)
  "Add items to a sorted-set-by."
  (let ((result (add s item)))
    (dolist (it more-items)
      (setf result (add result it)))
    result))

(defmethod disj-one ((s <sorted-set>) item)
  "Remove ITEM from sorted-set."
  (remove s item))

(defmethod disj-one ((s <ordered-set>) item)
  "Remove ITEM from ordered-set."
  (remove s item))

(defmethod disj-one ((s <int-set>) item)
  "Remove ITEM from int-set."
  (remove s item))

(defmethod disj-one ((s <dense-int-set>) item)
  "Remove ITEM from dense-int-set."
  (remove s item))

(defmethod disj-one ((s <sorted-set-by>) item)
  "Remove ITEM from sorted-set-by."
  (remove s item))

;;; ============================================================================
;;; SET OPERATIONS: union, difference, intersect, select
;;; ============================================================================

(defgeneric set-union (set1 set2 &rest more-sets)
  (:documentation "Return a new set containing all elements from all input sets.
   The result type matches the type of the first set."))

(defmethod set-union ((s1 <set>) (s2 <set>) &rest more-sets)
  "Union of hash sets."
  (let ((result s1))
    ;; Add all elements from s2
    (let ((items2 (pslot-value s2 'fol.collection::items)))
      (fset:do-map (k v items2)
        (declare (ignore v))
        (setf result (add result k))))
    ;; Add all elements from more-sets
    (dolist (s more-sets)
      (let ((items (pslot-value s 'fol.collection::items)))
        (fset:do-map (k v items)
          (declare (ignore v))
          (setf result (add result k)))))
    result))

(defmethod set-union ((s1 <sorted-set>) (s2 <set>) &rest more-sets)
  "Union starting with sorted-set."
  (let ((result s1))
    (let ((s2-seq (seq s2)))
      (when s2-seq
        (let ((current s2-seq))
          (loop while (and current (not (empty? current)))
                do (setf result (add result (first current)))
                   (setf current (rest current))))))
    (dolist (s more-sets)
      (let ((s-seq (seq s)))
        (when s-seq
          (let ((current s-seq))
            (loop while current
                  do (setf result (add result (first current)))
                     (setf current (rest current)))))))
    result))

(defmethod set-union ((s1 <ordered-set>) (s2 <set>) &rest more-sets)
  "Union starting with ordered-set, preserving insertion order."
  (let ((result s1))
    (let ((s2-seq (seq s2)))
      (when s2-seq
        (let ((current s2-seq))
          (loop while (and current (not (empty? current)))
                do (setf result (add result (first current)))
                   (setf current (rest current))))))
    (dolist (s more-sets)
      (let ((s-seq (seq s)))
        (when s-seq
          (let ((current s-seq))
            (loop while current
                  do (setf result (add result (first current)))
                     (setf current (rest current)))))))
    result))

(defmethod set-union ((s1 <int-set>) (s2 <set>) &rest more-sets)
  "Union starting with int-set."
  (let ((result s1))
    (let ((s2-seq (seq s2)))
      (when s2-seq
        (let ((current s2-seq))
          (loop while (and current (not (empty? current)))
                do (setf result (add result (first current)))
                   (setf current (rest current))))))
    (dolist (s more-sets)
      (let ((s-seq (seq s)))
        (when s-seq
          (let ((current s-seq))
            (loop while current
                  do (setf result (add result (first current)))
                     (setf current (rest current)))))))
    result))

(defmethod set-union ((s1 <dense-int-set>) (s2 <dense-int-set>) &rest more-sets)
  "Union of dense-int-sets with same bounds."
  (let* ((base1 (pslot-value s1 'fol.collection::base))
         (bits1 (pslot-value s1 'fol.collection::bits))
         (base2 (pslot-value s2 'fol.collection::base))
         (bits2 (pslot-value s2 'fol.collection::bits)))
    (unless (and (= base1 base2) (= (length bits1) (length bits2)))
      (error "UNION: dense-int-sets must have same bounds"))
    (let ((new-bits (copy-seq bits1)))
      (dotimes (i (length bits1))
        (when (= 1 (aref bits2 i))
          (setf (aref new-bits i) 1)))
      (dolist (s more-sets)
        (let ((bits-s (pslot-value s 'fol.collection::bits)))
          (dotimes (i (length bits1))
            (when (= 1 (aref bits-s i))
              (setf (aref new-bits i) 1)))))
      (make-instance '<dense-int-set> :base base1 :bits new-bits))))

(defgeneric set-difference (set1 set2)
  (:documentation "Return a new set containing elements in set1 but not in set2."))

(defmethod set-difference ((s1 <set>) (s2 <set>))
  "Difference of hash sets."
  (let ((result s1))
    (let ((items2 (pslot-value s2 'fol.collection::items)))
      (fset:do-map (k v items2)
        (declare (ignore v))
        (setf result (remove result k))))
    result))

(defmethod set-difference ((s1 <sorted-set>) (s2 <set>))
  "Difference starting with sorted-set."
  (let ((result s1))
    (let ((s2-seq (seq s2)))
      (when s2-seq
        (let ((current s2-seq))
          (loop while (and current (not (empty? current)))
                do (setf result (remove result (first current)))
                   (setf current (rest current))))))
    result))

(defmethod set-difference ((s1 <ordered-set>) (s2 <set>))
  "Difference starting with ordered-set."
  (let ((result s1))
    (let ((s2-seq (seq s2)))
      (when s2-seq
        (let ((current s2-seq))
          (loop while (and current (not (empty? current)))
                do (setf result (remove result (first current)))
                   (setf current (rest current))))))
    result))

(defmethod set-difference ((s1 <int-set>) (s2 <set>))
  "Difference starting with int-set."
  (let ((result s1))
    (let ((s2-seq (seq s2)))
      (when s2-seq
        (let ((current s2-seq))
          (loop while (and current (not (empty? current)))
                do (setf result (remove result (first current)))
                   (setf current (rest current))))))
    result))

(defmethod set-difference ((s1 <dense-int-set>) (s2 <dense-int-set>))
  "Difference of dense-int-sets with same bounds."
  (let* ((base1 (pslot-value s1 'fol.collection::base))
         (bits1 (pslot-value s1 'fol.collection::bits))
         (base2 (pslot-value s2 'fol.collection::base))
         (bits2 (pslot-value s2 'fol.collection::bits)))
    (unless (and (= base1 base2) (= (length bits1) (length bits2)))
      (error "DIFFERENCE: dense-int-sets must have same bounds"))
    (let ((new-bits (copy-seq bits1)))
      (dotimes (i (length bits1))
        (when (= 1 (aref bits2 i))
          (setf (aref new-bits i) 0)))
      (make-instance '<dense-int-set> :base base1 :bits new-bits))))

(defgeneric set-intersection (set1 set2 &rest more-sets)
  (:documentation "Return a new set containing elements present in all input sets."))

(defmethod set-intersection ((s1 <set>) (s2 <set>) &rest more-sets)
  "Intersection of hash sets."
  (let ((result (make-set)))
    ;; Start with elements in s1 that are also in s2
    (let ((items1 (pslot-value s1 'fol.collection::items)))
      (fset:do-map (k v items1)
        (declare (ignore v))
        (when (contains? s2 k)
          (setf result (add result k)))))
    ;; For each additional set, keep only elements in that set
    (dolist (s more-sets)
      (let ((new-result (make-set)))
        (let ((items (pslot-value result 'fol.collection::items)))
          (fset:do-map (k v items)
            (declare (ignore v))
            (when (contains? s k)
              (setf new-result (add new-result k)))))
        (setf result new-result)))
    result))

(defmethod set-intersection ((s1 <sorted-set>) (s2 <set>) &rest more-sets)
  "Intersection starting with sorted-set."
  (let ((result (make-sorted-set)))
    (let ((s1-seq (seq s1)))
      (when s1-seq
        (let ((current s1-seq))
          (loop while (and current (not (empty? current)))
                do (when (contains? s2 (first current))
                     (setf result (add result (first current))))
                   (setf current (rest current))))))
    (dolist (s more-sets)
      (let ((new-result (make-sorted-set))
            (r-seq (seq result)))
        (when r-seq
          (let ((current r-seq))
            (loop while (and current (not (empty? current)))
                  do (when (contains? s (first current))
                       (setf new-result (add new-result (first current))))
                     (setf current (rest current)))))
        (setf result new-result)))
    result))

(defmethod set-intersection ((s1 <ordered-set>) (s2 <set>) &rest more-sets)
  "Intersection starting with ordered-set."
  (let ((result (make-ordered-set)))
    (let ((s1-seq (seq s1)))
      (when s1-seq
        (let ((current s1-seq))
          (loop while (and current (not (empty? current)))
                do (when (contains? s2 (first current))
                     (setf result (add result (first current))))
                   (setf current (rest current))))))
    (dolist (s more-sets)
      (let ((new-result (make-ordered-set))
            (r-seq (seq result)))
        (when r-seq
          (let ((current r-seq))
            (loop while (and current (not (empty? current)))
                  do (when (contains? s (first current))
                       (setf new-result (add new-result (first current))))
                     (setf current (rest current)))))
        (setf result new-result)))
    result))

(defmethod set-intersection ((s1 <int-set>) (s2 <set>) &rest more-sets)
  "Intersection starting with int-set."
  (let ((result (make-int-set)))
    (let ((s1-seq (seq s1)))
      (when s1-seq
        (let ((current s1-seq))
          (loop while (and current (not (empty? current)))
                do (when (contains? s2 (first current))
                     (setf result (add result (first current))))
                   (setf current (rest current))))))
    (dolist (s more-sets)
      (let ((new-result (make-int-set))
            (r-seq (seq result)))
        (when r-seq
          (let ((current r-seq))
            (loop while (and current (not (empty? current)))
                  do (when (contains? s (first current))
                       (setf new-result (add new-result (first current))))
                     (setf current (rest current)))))
        (setf result new-result)))
    result))

(defmethod set-intersection ((s1 <dense-int-set>) (s2 <dense-int-set>) &rest more-sets)
  "Intersection of dense-int-sets with same bounds."
  (let* ((base1 (pslot-value s1 'fol.collection::base))
         (bits1 (pslot-value s1 'fol.collection::bits))
         (base2 (pslot-value s2 'fol.collection::base))
         (bits2 (pslot-value s2 'fol.collection::bits)))
    (unless (and (= base1 base2) (= (length bits1) (length bits2)))
      (error "INTERSECTION: dense-int-sets must have same bounds"))
    (let ((new-bits (copy-seq bits1)))
      (dotimes (i (length bits1))
        (unless (= 1 (aref bits2 i))
          (setf (aref new-bits i) 0)))
      (dolist (s more-sets)
        (let ((bits-s (pslot-value s 'fol.collection::bits)))
          (dotimes (i (length bits1))
            (unless (= 1 (aref bits-s i))
              (setf (aref new-bits i) 0)))))
      (make-instance '<dense-int-set> :base base1 :bits new-bits))))

(defgeneric select (pred set)
  (:documentation "Return a new set containing only elements that satisfy PRED.
   Like Clojure's filter but returns a set of the same type."))

(defmethod select (pred (s <set>))
  "Filter elements of a hash set."
  (let ((result (make-set)))
    (let ((items (pslot-value s 'fol.collection::items)))
      (fset:do-map (k v items)
        (declare (ignore v))
        (when (funcall pred k)
          (setf result (add result k)))))
    result))

(defmethod select (pred (s <sorted-set>))
  "Filter elements of a sorted-set."
  (let ((result (make-sorted-set)))
    (let ((items (pslot-value s 'fol.collection::items)))
      (fset:do-set (item items)
        (when (funcall pred item)
          (setf result (add result item)))))
    result))

(defmethod select (pred (s <ordered-set>))
  "Filter elements of an ordered-set, preserving order of matching elements."
  (let ((result (make-ordered-set)))
    (let ((order (pslot-value s 'fol.collection::order)))
      (fset:do-seq (item order)
        (when (funcall pred item)
          (setf result (add result item)))))
    result))

(defmethod select (pred (s <int-set>))
  "Filter elements of an int-set."
  (let ((result (make-int-set)))
    (let ((items (pslot-value s 'fol.collection::items)))
      (fset:do-set (item items)
        (when (funcall pred item)
          (setf result (add result item)))))
    result))

(defmethod select (pred (s <dense-int-set>))
  "Filter elements of a dense-int-set."
  (let* ((base (pslot-value s 'fol.collection::base))
         (bits (pslot-value s 'fol.collection::bits))
         (new-bits (cl:make-array (length bits) :element-type 'bit :initial-element 0)))
    (dotimes (i (length bits))
      (when (and (= 1 (aref bits i))
                 (funcall pred (+ base i)))
        (setf (aref new-bits i) 1)))
    (make-instance '<dense-int-set> :base base :bits new-bits)))

;;; ============================================================================
;;; SET OPERATIONS: subset? and superset?
;;; ============================================================================

(defgeneric subset? (set1 set2)
  (:documentation "Return T if set1 is a subset of set2 (all elements of set1 are in set2)."))

(defmethod subset? ((s1 <set>) (s2 <set>))
  "Check if s1 is a subset of s2."
  (let ((items1 (pslot-value s1 'fol.collection::items)))
    (fset:do-map (k v items1)
      (declare (ignore v))
      (unless (contains? s2 k)
        (return-from subset? nil)))
    t))

(defmethod subset? ((s1 <sorted-set>) (s2 <set>))
  "Check if sorted-set s1 is a subset of s2."
  (let ((items1 (pslot-value s1 'fol.collection::items)))
    (fset:do-set (item items1)
      (unless (contains? s2 item)
        (return-from subset? nil)))
    t))

(defmethod subset? ((s1 <ordered-set>) (s2 <set>))
  "Check if ordered-set s1 is a subset of s2."
  (let ((items1 (pslot-value s1 'fol.collection::items)))
    (fset:do-map (k v items1)
      (declare (ignore v))
      (unless (contains? s2 k)
        (return-from subset? nil)))
    t))

(defmethod subset? ((s1 <int-set>) (s2 <set>))
  "Check if int-set s1 is a subset of s2."
  (let ((items1 (pslot-value s1 'fol.collection::items)))
    (fset:do-set (item items1)
      (unless (contains? s2 item)
        (return-from subset? nil)))
    t))

(defmethod subset? ((s1 <dense-int-set>) (s2 <set>))
  "Check if dense-int-set s1 is a subset of s2."
  (let ((base (pslot-value s1 'fol.collection::base))
        (bits (pslot-value s1 'fol.collection::bits)))
    (dotimes (i (length bits))
      (when (= 1 (aref bits i))
        (unless (contains? s2 (+ base i))
          (return-from subset? nil))))
    t))

(defmethod subset? ((s1 <dense-int-set>) (s2 <dense-int-set>))
  "Check if dense-int-set s1 is a subset of s2."
  (let* ((base1 (pslot-value s1 'fol.collection::base))
         (bits1 (pslot-value s1 'fol.collection::bits))
         (base2 (pslot-value s2 'fol.collection::base))
         (bits2 (pslot-value s2 'fol.collection::bits)))
    (if (and (= base1 base2) (= (length bits1) (length bits2)))
        ;; Same bounds: direct bit comparison
        (dotimes (i (length bits1) t)
          (when (and (= 1 (aref bits1 i))
                     (= 0 (aref bits2 i)))
            (return-from subset? nil)))
        ;; Different bounds: element-wise check
        (dotimes (i (length bits1) t)
          (when (= 1 (aref bits1 i))
            (unless (contains? s2 (+ base1 i))
              (return-from subset? nil)))))))

(defgeneric superset? (set1 set2)
  (:documentation "Return T if set1 is a superset of set2 (all elements of set2 are in set1)."))

(defmethod superset? ((s1 <set>) (s2 <set>))
  "Check if s1 is a superset of s2."
  (subset? s2 s1))

;;; ============================================================================
;;; ORDERED SET OPERATIONS: subs and rsubs
;;; ============================================================================
;;; subs and rsubs - Subsequence functions for ordered collections
;;; For vectors: (subs v start) or (subs v start end) - by index
;;; For sorted sets: (subs s start-val end-val) - elements >= start and < end

(defgeneric subs (coll start &optional end)
  (:documentation "Return a lazy seq of elements from an ordered collection.
   For vectors: (subs v start) or (subs v start end) - by index
   For sorted sets: (subs s start-val end-val) - elements >= start-val and < end-val"))

(defmethod subs ((v <vector>) start &optional end)
  "Return a lazy seq of elements from vector from start index to end (exclusive)."
  (let* ((items (pslot-value v 'fol.collection::items))
         (len (fset:size items))
         (actual-end (min (or end len) len)))
    (if (cl:>= start actual-end)
        nil
        (cl:labels ((lazy-subs (idx)
                      (fol.collection:make-lazy-seq
                       (lambda ()
                         (if (cl:>= idx actual-end)
                             nil
                             (cl:cons (fset:@ items idx) (lazy-subs (cl:1+ idx))))))))
          (lazy-subs start)))))

(defmethod subs ((s string) start &optional end)
  "Return a substring of S from START to END (exclusive).
   If END is not provided, returns from START to the end of the string."
  (if end
      (cl:subseq s start end)
      (cl:subseq s start)))

(defmethod subs ((s <sorted-set>) start &optional end)
  "Return a lazy seq of elements from sorted-set where element >= start and < end."
  (let ((items (pslot-value s 'fol.collection::items))
        (result nil))
    (fset:do-set (item items)
      (when (>= item start)
        (when (or (null end) (< item end))
          (cl:push item result))))
    (if result
        (setf result (nreverse result))
        (return-from subs nil))
    (cl:labels ((lazy-subs (remaining)
                  (fol.collection:make-lazy-seq
                   (lambda ()
                     (if remaining
                         (cl:cons (car remaining) (lazy-subs (cdr remaining)))
                         nil)))))
      (lazy-subs result))))

(defmethod subs ((s <int-set>) start &optional end)
  "Return a lazy seq of elements from int-set where element >= start and < end."
  (let ((items (pslot-value s 'fol.collection::items))
        (result nil))
    (fset:do-set (item items)
      (when (>= item start)
        (when (or (null end) (< item end))
          (cl:push item result))))
    (if result
        (setf result (nreverse result))
        (return-from subs nil))
    (cl:labels ((lazy-subs (remaining)
                  (fol.collection:make-lazy-seq
                   (lambda ()
                     (if remaining
                         (cl:cons (car remaining) (lazy-subs (cdr remaining)))
                         nil)))))
      (lazy-subs result))))

(defmethod subs ((s <dense-int-set>) start &optional end)
  "Return a lazy seq of elements from dense-int-set where element >= start and < end."
  (let ((base (pslot-value s 'fol.collection::base))
        (bits (pslot-value s 'fol.collection::bits))
        (result nil))
    (dotimes (i (length bits))
      (when (= 1 (aref bits i))
        (let ((val (+ base i)))
          (when (>= val start)
            (when (or (null end) (< val end))
              (cl:push val result))))))
    (if result
        (setf result (nreverse result))
        (return-from subs nil))
    (cl:labels ((lazy-subs (remaining)
                  (fol.collection:make-lazy-seq
                   (lambda ()
                     (if remaining
                         (cl:cons (car remaining) (lazy-subs (cdr remaining)))
                         nil)))))
      (lazy-subs result))))

(defgeneric rsubs (coll start &optional end)
  (:documentation "Return a lazy seq of elements from an ordered collection in reverse order.
   Like subs but results are reversed."))

(defmethod rsubs ((v <vector>) start &optional end)
  "Return a lazy seq of elements from vector in reverse order."
  (let* ((items (pslot-value v 'fol.collection::items))
         (len (fset:size items))
         (actual-end (min (or end len) len)))
    (if (cl:>= start actual-end)
        nil
        (cl:labels ((lazy-rsubs (idx)
                      (fol.collection:make-lazy-seq
                       (lambda ()
                         (if (cl:< idx start)
                             nil
                             (cl:cons (fset:@ items idx) (lazy-rsubs (cl:1- idx))))))))
          (lazy-rsubs (cl:1- actual-end))))))

(defmethod rsubs ((s <sorted-set>) start &optional end)
  "Return a lazy seq of elements from sorted-set in reverse order."
  (let ((items (pslot-value s 'fol.collection::items))
        (result nil))
    (fset:do-set (item items)
      (when (>= item start)
        (when (or (null end) (< item end))
          (cl:push item result))))
    (if (null result)
        nil
        ;; result is already reversed from push
        (cl:labels ((lazy-rsubs (remaining)
                      (fol.collection:make-lazy-seq
                       (lambda ()
                         (if remaining
                             (cl:cons (car remaining) (lazy-rsubs (cdr remaining)))
                             nil)))))
          (lazy-rsubs result)))))

(defmethod rsubs ((s <int-set>) start &optional end)
  "Return a lazy seq of elements from int-set in reverse order."
  (let ((items (pslot-value s 'fol.collection::items))
        (result nil))
    (fset:do-set (item items)
      (when (>= item start)
        (when (or (null end) (< item end))
          (cl:push item result))))
    (if (null result)
        nil
        (cl:labels ((lazy-rsubs (remaining)
                      (fol.collection:make-lazy-seq
                       (lambda ()
                         (if remaining
                             (cl:cons (car remaining) (lazy-rsubs (cdr remaining)))
                             nil)))))
          (lazy-rsubs result)))))

(defmethod rsubs ((s <dense-int-set>) start &optional end)
  "Return a lazy seq of elements from dense-int-set in reverse order."
  (let ((base (pslot-value s 'fol.collection::base))
        (bits (pslot-value s 'fol.collection::bits))
        (result nil))
    ;; Iterate in reverse to get descending order
    (loop for i from (1- (length bits)) downto 0
          when (= 1 (aref bits i))
          do (let ((val (+ base i)))
               (when (>= val start)
                 (when (or (null end) (< val end))
                   (cl:push val result)))))
    (if (null result)
        nil
        (progn
          (setf result (nreverse result))
          (cl:labels ((lazy-rsubs (remaining)
                        (fol.collection:make-lazy-seq
                         (lambda ()
                           (if remaining
                               (cl:cons (car remaining) (lazy-rsubs (cdr remaining)))
                               nil)))))
            (lazy-rsubs result))))))

;;; Add rseq for ordered sets
(defmethod rseq ((s <sorted-set>))
  "Return a seq of sorted-set elements in reverse order."
  (let ((items (pslot-value s 'fol.collection::items))
        (result nil))
    (fset:do-set (item items)
      (cl:push item result))
    (if result
        (apply #'make-list result)  ; reverse of sorted order
        nil)))

(defmethod rseq ((s <ordered-set>))
  "Return a seq of ordered-set elements in reverse insertion order."
  (let ((order (pslot-value s 'fol.collection::order))
        (elems nil))
    (fset:do-seq (item order)
      (cl:push item elems))
    (if elems
        (apply #'make-list elems)
        nil)))

(defmethod rseq ((s <dense-int-set>))
  "Return a seq of dense-int-set elements in descending order."
  (let ((base (pslot-value s 'fol.collection::base))
        (bits (pslot-value s 'fol.collection::bits))
        (result nil))
    (dotimes (i (length bits))
      (when (= 1 (aref bits i))
        (cl:push (+ base i) result)))
    (if result
        (apply #'make-list result)
        nil)))
;;; This file contains dict function additions for seqop.lisp
;;; To be appended to the end of seqop.lisp

;;; ============================================================================
;;; Dictionary Query Functions
;;; ============================================================================

(defgeneric get-in (coll keys &optional not-found)
  (:documentation "Returns the value in a nested associative structure.
   KEYS is a sequence of keys identifying the path.
   Returns NOT-FOUND if the path doesn't exist."))

(defmethod get-in ((coll <dict>) keys &optional (not-found nil))
  "Get value at nested path KEYS in dict."
  (let ((ks (%keys-to-list keys))
        (current coll))
    (dolist (k ks)
      (if (typep current '<dict>)
          (let ((raw-k (fol.collection::%dict-key k)))
            (multiple-value-bind (val found)
                (fset:lookup (pslot-value current 'fol.collection::items) raw-k)
              (if found
                  (setf current val)
                  (return-from get-in not-found))))
          (return-from get-in not-found)))
    current))

(defmethod get-in ((coll <vector>) keys &optional (not-found nil))
  "Get value at nested path KEYS starting with a vector."
  (let ((ks (%keys-to-list keys))
        (current coll))
    (dolist (k ks)
      (let ((idx (fol.wrappers:fol-value k)))
        (cond
          ((typep current '<vector>)
           (let ((items (pslot-value current 'fol.collection::items)))
             (if (and (integerp idx) (>= idx 0) (< idx (fset:size items)))
                 (setf current (fset:lookup items idx))
                 (return-from get-in not-found))))
          ((typep current '<dict>)
           (multiple-value-bind (val found)
               (fset:lookup (pslot-value current 'fol.collection::items) idx)
             (if found
                 (setf current val)
                 (return-from get-in not-found))))
          (t (return-from get-in not-found)))))
    current))

(defgeneric find (coll key)
  (:documentation "Returns the map entry for KEY, or NIL if key not present.
   For dicts, returns a cons pair (KEY . VALUE)."))

(defmethod find ((coll <dict>) key)
  "Find the map entry for KEY in dict, returns (KEY . VALUE) or NIL."
  (let ((raw-key (fol.collection::%dict-key key)))
    (multiple-value-bind (val found)
        (fset:lookup (pslot-value coll 'fol.collection::items) raw-key)
      (when found
        (cl:cons raw-key val)))))

(defgeneric keys (coll)
  (:documentation "Returns a lazy sequence of the keys in the associative collection."))

(defmethod keys ((coll <dict>))
  "Return a lazy sequence of all keys in the dict."
  (let ((items (pslot-value coll 'fol.collection::items)))
    (if (fset:empty? items)
        nil
        ;; Convert to list of keys for lazy iteration
        (let ((key-list nil))
          (fset:do-map (k v items)
            (declare (ignore v))
            (cl:push k key-list))
          (setf key-list (nreverse key-list))
          ;; Return a lazy-seq over the keys
          (cl:labels ((lazy-keys (remaining)
                        (fol.collection:make-lazy-seq
                         (lambda ()
                           (if remaining
                               (cl:cons (car remaining) (lazy-keys (cdr remaining)))
                               nil)))))
            (lazy-keys key-list))))))

(defmethod keys ((coll <array-dict>))
  "Return a lazy sequence of keys in insertion order for array-dict."
  (let ((order (pslot-value coll 'fol.collection::order)))
    (if (fset:empty? order)
        nil
        (let ((key-list (fset:convert 'list order)))
          (cl:labels ((lazy-keys (remaining)
                        (fol.collection:make-lazy-seq
                         (lambda ()
                           (if remaining
                               (cl:cons (car remaining) (lazy-keys (cdr remaining)))
                               nil)))))
            (lazy-keys key-list))))))

(defmethod keys ((coll <ordered-dict>))
  "Return a lazy sequence of keys in insertion order for ordered-dict."
  (let ((order (pslot-value coll 'fol.collection::order)))
    (if (fset:empty? order)
        nil
        (let ((key-list (fset:convert 'list order)))
          (cl:labels ((lazy-keys (remaining)
                        (fol.collection:make-lazy-seq
                         (lambda ()
                           (if remaining
                               (cl:cons (car remaining) (lazy-keys (cdr remaining)))
                               nil)))))
            (lazy-keys key-list))))))

(defmethod keys ((coll <sorted-dict>))
  "Return a lazy sequence of keys in sorted order for sorted-dict."
  (let ((items (pslot-value coll 'fol.collection::items)))
    (if (zerop (sycamore:tree-map-count items))
        nil
        (let ((key-list nil))
          (sycamore:do-tree-map ((k v) items)
            (declare (ignore v))
            (cl:push k key-list))
          (setf key-list (nreverse key-list))
          (cl:labels ((lazy-keys (remaining)
                        (fol.collection:make-lazy-seq
                         (lambda ()
                           (if remaining
                               (cl:cons (car remaining) (lazy-keys (cdr remaining)))
                               nil)))))
            (lazy-keys key-list))))))

(defmethod keys ((coll <priority-dict>))
  "Return a lazy sequence of keys in priority order for priority-dict."
  (let ((priorities (pslot-value coll 'fol.collection::priorities)))
    (if (fset:empty? priorities)
        nil
        (let ((key-list nil))
          (fset:do-map (priority item-set priorities)
            (declare (ignore priority))
            (fset:do-set (item item-set)
              (cl:push item key-list)))
          (setf key-list (nreverse key-list))
          (cl:labels ((lazy-keys (remaining)
                        (fol.collection:make-lazy-seq
                         (lambda ()
                           (if remaining
                               (cl:cons (car remaining) (lazy-keys (cdr remaining)))
                               nil)))))
            (lazy-keys key-list))))))

(defgeneric vals (coll)
  (:documentation "Returns a lazy sequence of the values in the associative collection."))

(defmethod vals ((coll <dict>))
  "Return a lazy sequence of all values in the dict."
  (let ((items (pslot-value coll 'fol.collection::items)))
    (if (fset:empty? items)
        nil
        (let ((val-list nil))
          (fset:do-map (k v items)
            (declare (ignore k))
            (cl:push v val-list))
          (setf val-list (nreverse val-list))
          (cl:labels ((lazy-vals (remaining)
                        (fol.collection:make-lazy-seq
                         (lambda ()
                           (if remaining
                               (cl:cons (car remaining) (lazy-vals (cdr remaining)))
                               nil)))))
            (lazy-vals val-list))))))

(defmethod vals ((coll <array-dict>))
  "Return a lazy sequence of values in key insertion order for array-dict."
  (let ((order (pslot-value coll 'fol.collection::order))
        (items (pslot-value coll 'fol.collection::items)))
    (if (fset:empty? order)
        nil
        (let ((val-list nil))
          (fset:do-seq (k order)
            (cl:push (fset:lookup items k) val-list))
          (setf val-list (nreverse val-list))
          (cl:labels ((lazy-vals (remaining)
                        (fol.collection:make-lazy-seq
                         (lambda ()
                           (if remaining
                               (cl:cons (car remaining) (lazy-vals (cdr remaining)))
                               nil)))))
            (lazy-vals val-list))))))

(defmethod vals ((coll <ordered-dict>))
  "Return a lazy sequence of values in key insertion order for ordered-dict."
  (let ((order (pslot-value coll 'fol.collection::order))
        (items (pslot-value coll 'fol.collection::items)))
    (if (fset:empty? order)
        nil
        (let ((val-list nil))
          (fset:do-seq (k order)
            (cl:push (fset:lookup items k) val-list))
          (setf val-list (nreverse val-list))
          (cl:labels ((lazy-vals (remaining)
                        (fol.collection:make-lazy-seq
                         (lambda ()
                           (if remaining
                               (cl:cons (car remaining) (lazy-vals (cdr remaining)))
                               nil)))))
            (lazy-vals val-list))))))

(defmethod vals ((coll <sorted-dict>))
  "Return a lazy sequence of values in sorted key order for sorted-dict."
  (let ((items (pslot-value coll 'fol.collection::items)))
    (if (zerop (sycamore:tree-map-count items))
        nil
        (let ((val-list nil))
          (sycamore:do-tree-map ((k v) items)
            (declare (ignore k))
            (cl:push v val-list))
          (setf val-list (nreverse val-list))
          (cl:labels ((lazy-vals (remaining)
                        (fol.collection:make-lazy-seq
                         (lambda ()
                           (if remaining
                               (cl:cons (car remaining) (lazy-vals (cdr remaining)))
                               nil)))))
            (lazy-vals val-list))))))

(defmethod vals ((coll <priority-dict>))
  "Return a lazy sequence of values (priorities) in priority order for priority-dict."
  (let ((items (pslot-value coll 'fol.collection::items))
        (priorities (pslot-value coll 'fol.collection::priorities)))
    (if (fset:empty? priorities)
        nil
        (let ((val-list nil))
          (fset:do-map (priority item-set priorities)
            (declare (ignore priority))
            (fset:do-set (item item-set)
              (cl:push (fset:lookup items item) val-list)))
          (setf val-list (nreverse val-list))
          (cl:labels ((lazy-vals (remaining)
                        (fol.collection:make-lazy-seq
                         (lambda ()
                           (if remaining
                               (cl:cons (car remaining) (lazy-vals (cdr remaining)))
                               nil)))))
            (lazy-vals val-list))))))

(defun key (map-entry)
  "Returns the key of a map entry (cons pair)."
  (if (consp map-entry)
      (car map-entry)
      (error "KEY expects a map entry (cons pair), got ~S" map-entry)))

(defun val (map-entry)
  "Returns the value of a map entry (cons pair)."
  (if (consp map-entry)
      (cdr map-entry)
      (error "VAL expects a map entry (cons pair), got ~S" map-entry)))


;;; ============================================================================
;;; Dictionary Modification Functions
;;; ============================================================================

(defgeneric dissoc (coll &rest keys)
  (:documentation "Returns a new dict with the given keys removed."))

(defmethod dissoc ((coll <dict>) &rest keys)
  "Remove keys from regular dict."
  (let ((items (pslot-value coll 'fol.collection::items)))
    (dolist (k keys)
      (setf items (fset:less items (fol.wrappers:fol-value k))))
    (make-instance (class-of coll) :items items)))

(defmethod dissoc ((coll <array-dict>) &rest keys)
  "Remove keys from array-dict, maintaining insertion order."
  (let ((items (pslot-value coll 'fol.collection::items))
        (order (pslot-value coll 'fol.collection::order))
        (max-size (pslot-value coll 'fol.collection::max-size))
        (keys-to-remove (mapcar #'fol.wrappers:fol-value keys)))
    (dolist (k keys-to-remove)
      (setf items (fset:less items k)))
    (let ((new-order (fset:empty-seq)))
      (fset:do-seq (k order)
        (unless (member k keys-to-remove :test #'equal)
          (setf new-order (fset:with-last new-order k))))
      (make-instance '<array-dict> :items items :order new-order :max-size max-size))))

(defmethod dissoc ((coll <ordered-dict>) &rest keys)
  "Remove keys from ordered-dict, maintaining insertion order."
  (let ((items (pslot-value coll 'fol.collection::items))
        (order (pslot-value coll 'fol.collection::order))
        (keys-to-remove (mapcar #'fol.wrappers:fol-value keys)))
    (dolist (k keys-to-remove)
      (setf items (fset:less items k)))
    (let ((new-order (fset:empty-seq)))
      (fset:do-seq (k order)
        (unless (member k keys-to-remove :test #'equal)
          (setf new-order (fset:with-last new-order k))))
      (make-instance '<ordered-dict> :items items :order new-order))))

(defmethod dissoc ((coll <sorted-dict>) &rest keys)
  "Remove keys from sorted-dict."
  (let ((tree (pslot-value coll 'fol.collection::items)))
    (dolist (k keys)
      (setf tree (sycamore:tree-map-remove tree (fol.wrappers:fol-value k))))
    (make-instance (class-of coll) :items tree)))

(defmethod dissoc ((coll <priority-dict>) &rest keys)
  "Remove keys from priority-dict."
  (let ((items (pslot-value coll 'fol.collection::items))
        (priorities (pslot-value coll 'fol.collection::priorities)))
    (dolist (k keys)
      (let ((raw-k (fol.wrappers:fol-value k)))
        (multiple-value-bind (priority found) (fset:lookup items raw-k)
          (when found
            (let ((item-set (fset:lookup priorities priority)))
              (when item-set
                (setf item-set (fset:less item-set raw-k))
                (if (fset:empty? item-set)
                    (setf priorities (fset:less priorities priority))
                    (setf priorities (fset:with priorities priority item-set)))))
            (setf items (fset:less items raw-k))))))
    (make-instance '<priority-dict> :items items :priorities priorities)))

(defgeneric merge (coll &rest colls)
  (:documentation "Returns a new dict containing all entries from the input dicts.
   If a key appears in more than one dict, the value from the rightmost dict is used."))

(defmethod merge ((coll <dict>) &rest colls)
  "Merge dicts, with rightmost values winning."
  (let ((items (pslot-value coll 'fol.collection::items)))
    (dolist (other colls)
      (when (typep other '<dict>)
        (fset:do-map (k v (pslot-value other 'fol.collection::items))
          (setf items (fset:with items k v)))))
    (make-instance (class-of coll) :items items)))

(defun merge-with (f &rest dicts)
  "Returns a new dict containing all entries from the input dicts.
   When a key appears in more than one dict, the values are combined using F."
  (when (null dicts)
    (return-from merge-with (make-dict)))
  (let ((result (fset:empty-map)))
    (dolist (dict dicts)
      (when (typep dict '<dict>)
        (fset:do-map (k v (pslot-value dict 'fol.collection::items))
          (multiple-value-bind (existing found) (fset:lookup result k)
            (if found
                (setf result (fset:with result k (funcall f existing v)))
                (setf result (fset:with result k v)))))))
    (make-instance '<dict> :items result)))


;;; ============================================================================
;;; Dictionary Transformation Functions
;;; ============================================================================

(defun select-keys (coll keys-seq)
  "Returns a new dict containing only the entries whose keys are in KEYS-SEQ."
  (let ((result (fset:empty-map))
        (items (pslot-value coll 'fol.collection::items)))
    (let ((s (seq keys-seq)))
      (loop while (and s (not (empty? s)))
            do (let ((k (fol.wrappers:fol-value (first s))))
                 (multiple-value-bind (v found) (fset:lookup items k)
                   (when found
                     (setf result (fset:with result k v))))
                 (setf s (rest s)))))
    (make-instance (class-of coll) :items result)))

(defun rename-keys (coll key-map)
  "Returns a new dict with keys renamed according to KEY-MAP.
   KEY-MAP is a dict mapping old keys to new keys."
  (let ((result (fset:empty-map))
        (items (pslot-value coll 'fol.collection::items))
        (key-map-items (pslot-value key-map 'fol.collection::items)))
    (fset:do-map (k v items)
      (multiple-value-bind (new-k found) (fset:lookup key-map-items k)
        (setf result (fset:with result (if found new-k k) v))))
    (make-instance (class-of coll) :items result)))

(defun map-invert (coll)
  "Returns a new dict with keys and values swapped."
  (let ((result (fset:empty-map))
        (items (pslot-value coll 'fol.collection::items)))
    (fset:do-map (k v items)
      (setf result (fset:with result v k)))
    (make-instance (class-of coll) :items result)))

(defun update-keys (coll f)
  "Returns a new dict with F applied to each key."
  (let ((result (fset:empty-map))
        (items (pslot-value coll 'fol.collection::items)))
    (fset:do-map (k v items)
      (setf result (fset:with result (funcall f k) v)))
    (make-instance (class-of coll) :items result)))

(defun update-vals (coll f)
  "Returns a new dict with F applied to each value."
  (let ((result (fset:empty-map))
        (items (pslot-value coll 'fol.collection::items)))
    (fset:do-map (k v items)
      (setf result (fset:with result k (funcall f v))))
    (make-instance (class-of coll) :items result)))


;;; ============================================================================
;;; Dictionary Construction Functions
;;; ============================================================================

(defun freqs (coll)
  "Returns a dict mapping each distinct element in COLL to the number of times it appears.
   Like Clojure's frequencies."
  (let ((result (fset:empty-map))
        (s (seq coll)))
    (loop while (and s (not (empty? s)))
          do (let ((item (fol.wrappers:fol-value (first s))))
               (multiple-value-bind (count found) (fset:lookup result item)
                 (setf result (fset:with result item (if found (1+ count) 1))))
               (setf s (rest s))))
    (make-instance '<dict> :items result)))

(defun group-by (f coll)
  "Returns a dict of the elements of COLL grouped by the result of F applied to each element."
  (let ((result (fset:empty-map))
        (s (seq coll)))
    (loop while (and s (not (empty? s)))
          do (let* ((item (first s))
                    (k (fol.wrappers:fol-value (funcall f item))))
               (multiple-value-bind (group found) (fset:lookup result k)
                 (setf result (fset:with result k
                                         (if found
                                             (conj group item)
                                             (make-list item)))))
               (setf s (rest s))))
    (make-instance '<dict> :items result)))

(defun index (coll f)
  "Returns a dict of the elements of COLL indexed by the result of F applied to each element.
   Unlike group-by, each key maps to a single value (the last element with that key)."
  (let ((result (fset:empty-map))
        (s (seq coll)))
    (loop while (and s (not (empty? s)))
          do (let* ((item (first s))
                    (k (fol.wrappers:fol-value (funcall f item))))
               (setf result (fset:with result k (fol.wrappers:fol-value item)))
               (setf s (rest s))))
    (make-instance '<dict> :items result)))

;;; ============================================================================
;;; Zipper - Functional Tree Navigation and Editing
;;; ============================================================================
;;; A zipper is a technique for navigating and editing immutable tree structures.
;;; It maintains a "focus" on a node and tracks the path back to the root,
;;; enabling efficient local updates in a purely functional way.
;;;
;;; The zipper implementation here follows Clojure's clojure.zip API.

(defclass <zipper> ()
  ((node :initarg :node
         :accessor zipper-node
         :documentation "The current node in focus.")
   (branch-fn :initarg :branch-fn
              :accessor zipper-branch-fn
              :documentation "A function that returns true if a node can have children.")
   (children-fn :initarg :children-fn
                :accessor zipper-children-fn
                :documentation "A function that returns the children of a branch node.")
   (make-node-fn :initarg :make-node-fn
                 :accessor zipper-make-node-fn
                 :documentation "A function that creates a node from an existing node and new children.")
   (path :initarg :path
         :initform nil
         :accessor zipper-path
         :documentation "A list of path segments from root to current location.")
   (lefts :initarg :lefts
          :initform nil
          :accessor zipper-lefts
          :documentation "Siblings to the left of current node.")
   (rights :initarg :rights
           :initform nil
           :accessor zipper-rights
           :documentation "Siblings to the right of current node.")
   (parent-nodes :initarg :parent-nodes
                 :initform nil
                 :accessor zipper-parent-nodes
                 :documentation "Stack of parent nodes for navigation.")
   (changed :initarg :changed
            :initform nil
            :accessor zipper-changed
            :documentation "True if the structure has been modified."))
  (:documentation "A zipper for functional navigation and editing of tree structures."))

(defgeneric <zipper>? (obj)
  (:documentation "Returns T if OBJ is a zipper."))

(defmethod <zipper>? (obj)
  nil)

(defmethod <zipper>? ((obj <zipper>))
  t)

(defmethod print-object ((z <zipper>) stream)
  (print-unreadable-object (z stream :type t)
    (format stream "~S" (zipper-node z))))

(defun zipper (branch-fn children-fn make-node-fn root)
  "Creates a new zipper structure.

   branch-fn is a fn that, given a node, returns true if it can have children.
   children-fn is a fn that, given a branch node, returns a seq of its children.
   make-node-fn is a fn that, given an existing node and a seq of children,
     returns a new branch node with the supplied children.
   root is the root node of the tree.

   Example:
     (zipper <vector>? seq (fn [node children] (apply vector children)) [1 [2 3] 4])"
  (make-instance '<zipper>
                 :node root
                 :branch-fn branch-fn
                 :children-fn children-fn
                 :make-node-fn make-node-fn))

(defun seq-zip (root)
  "Returns a zipper for nested sequences (lists/seqs).
   Branches are seqs, children are elements of the seq."
  (zipper (lambda (node)
            ;; Check FOL types first since they are CLOS objects (atoms in CL terms)
            (or (<list>? node)
                (<lazy-seq>? node)
                (and (not (atom node))
                     (or (listp node)
                         (consp node)))))
          (lambda (node)
            (seq node))
          (lambda (node children)
            (declare (ignore node))
            (apply #'make-list (if (listp children)
                                   children
                                   (let ((items nil)
                                         (s (seq children)))
                                     (loop while (and s (not (empty? s)))
                                           do (cl:push (first s) items)
                                              (setf s (rest s)))
                                     (nreverse items)))))
          root))

(defun vector-zip (root)
  "Returns a zipper for nested vectors.
   Branches are vectors, children are elements of the vector."
  (zipper (lambda (node)
            (<vector>? node))
          (lambda (node)
            (seq node))
          (lambda (node children)
            (declare (ignore node))
            (apply #'make-vector (if (listp children)
                                     children
                                     (let ((items nil)
                                           (s (seq children)))
                                       (loop while (and s (not (empty? s)))
                                             do (cl:push (first s) items)
                                                (setf s (rest s)))
                                       (nreverse items)))))
          root))

(defun node (loc)
  "Returns the node at loc."
  (zipper-node loc))

(defun branch? (loc)
  "Returns true if the node at loc is a branch."
  (funcall (zipper-branch-fn loc) (zipper-node loc)))

(defun children (loc)
  "Returns a seq of the children of the node at loc, which must be a branch."
  (if (branch? loc)
      (funcall (zipper-children-fn loc) (zipper-node loc))
      (error "Called children on a leaf node")))

(defun make-node (loc node children)
  "Returns a new branch node, given an existing node and new children."
  (funcall (zipper-make-node-fn loc) node children))

(defun path (loc)
  "Returns a seq of nodes leading to this loc."
  (zipper-path loc))

(defun lefts (loc)
  "Returns a seq of the left siblings of this loc."
  (zipper-lefts loc))

(defun rights (loc)
  "Returns a seq of the right siblings of this loc."
  (zipper-rights loc))

(defun down (loc)
  "Returns the loc of the leftmost child of the node at this loc,
   or nil if no children."
  (when (branch? loc)
    (let ((ch (funcall (zipper-children-fn loc) (zipper-node loc))))
      (when (and ch (not (empty? ch)))
        (let ((c (if (listp ch) ch
                     (let ((items nil)
                           (s (seq ch)))
                       (loop while (and s (not (empty? s)))
                             do (cl:push (first s) items)
                                (setf s (rest s)))
                       (nreverse items)))))
          (make-instance '<zipper>
                         :node (car c)
                         :branch-fn (zipper-branch-fn loc)
                         :children-fn (zipper-children-fn loc)
                         :make-node-fn (zipper-make-node-fn loc)
                         :path (cons (zipper-node loc) (zipper-path loc))
                         :lefts nil
                         :rights (cdr c)
                         :parent-nodes (cons loc (zipper-parent-nodes loc))
                         :changed (zipper-changed loc)))))))

(defun up (loc)
  "Returns the loc of the parent of the node at this loc, or nil if at the top."
  (let ((parent-nodes (zipper-parent-nodes loc)))
    (when parent-nodes
      (let* ((parent-loc (car parent-nodes))
             (new-node (if (zipper-changed loc)
                           (make-node parent-loc
                                      (zipper-node parent-loc)
                                      (append (cl:reverse (zipper-lefts loc))
                                              (cl:list (zipper-node loc))
                                              (zipper-rights loc)))
                           (zipper-node parent-loc))))
        (make-instance '<zipper>
                       :node new-node
                       :branch-fn (zipper-branch-fn loc)
                       :children-fn (zipper-children-fn loc)
                       :make-node-fn (zipper-make-node-fn loc)
                       :path (zipper-path parent-loc)
                       :lefts (zipper-lefts parent-loc)
                       :rights (zipper-rights parent-loc)
                       :parent-nodes (zipper-parent-nodes parent-loc)
                       :changed (or (zipper-changed loc) (zipper-changed parent-loc)))))))

(defun root (loc)
  "Returns the root node of the tree, reflecting any changes."
  (if (zipper-parent-nodes loc)
      (root (up loc))
      (zipper-node loc)))

(defun left (loc)
  "Returns the loc of the left sibling of the node at this loc, or nil."
  (let ((l (zipper-lefts loc)))
    (when l
      (make-instance '<zipper>
                     :node (car l)
                     :branch-fn (zipper-branch-fn loc)
                     :children-fn (zipper-children-fn loc)
                     :make-node-fn (zipper-make-node-fn loc)
                     :path (zipper-path loc)
                     :lefts (cdr l)
                     :rights (cons (zipper-node loc) (zipper-rights loc))
                     :parent-nodes (zipper-parent-nodes loc)
                     :changed (zipper-changed loc)))))

(defun right (loc)
  "Returns the loc of the right sibling of the node at this loc, or nil."
  (let ((r (zipper-rights loc)))
    (when r
      (make-instance '<zipper>
                     :node (car r)
                     :branch-fn (zipper-branch-fn loc)
                     :children-fn (zipper-children-fn loc)
                     :make-node-fn (zipper-make-node-fn loc)
                     :path (zipper-path loc)
                     :lefts (cons (zipper-node loc) (zipper-lefts loc))
                     :rights (cdr r)
                     :parent-nodes (zipper-parent-nodes loc)
                     :changed (zipper-changed loc)))))

(defun leftmost (loc)
  "Returns the loc of the leftmost sibling of the node at this loc,
   or self if already there."
  (if (null (zipper-lefts loc))
      loc
      (make-instance '<zipper>
                     :node (car (cl:last (zipper-lefts loc)))
                     :branch-fn (zipper-branch-fn loc)
                     :children-fn (zipper-children-fn loc)
                     :make-node-fn (zipper-make-node-fn loc)
                     :path (zipper-path loc)
                     :lefts nil
                     :rights (cl:append (cdr (cl:reverse (zipper-lefts loc)))
                                        (cl:list (zipper-node loc))
                                        (zipper-rights loc))
                     :parent-nodes (zipper-parent-nodes loc)
                     :changed (zipper-changed loc))))

(defun rightmost (loc)
  "Returns the loc of the rightmost sibling of the node at this loc,
   or self if already there."
  (if (null (zipper-rights loc))
      loc
      (make-instance '<zipper>
                     :node (car (cl:last (zipper-rights loc)))
                     :branch-fn (zipper-branch-fn loc)
                     :children-fn (zipper-children-fn loc)
                     :make-node-fn (zipper-make-node-fn loc)
                     :path (zipper-path loc)
                     :lefts (cl:append (cl:reverse (butlast (zipper-rights loc)))
                                       (cl:list (zipper-node loc))
                                       (zipper-lefts loc))
                     :rights nil
                     :parent-nodes (zipper-parent-nodes loc)
                     :changed (zipper-changed loc))))

(defun zip-replace (loc new-node)
  "Replaces the node at this loc, without moving."
  (make-instance '<zipper>
                 :node new-node
                 :branch-fn (zipper-branch-fn loc)
                 :children-fn (zipper-children-fn loc)
                 :make-node-fn (zipper-make-node-fn loc)
                 :path (zipper-path loc)
                 :lefts (zipper-lefts loc)
                 :rights (zipper-rights loc)
                 :parent-nodes (zipper-parent-nodes loc)
                 :changed t))

(defun edit (loc f &rest args)
  "Replaces the node at this loc with the value of (f node args)."
  (zip-replace loc (cl:apply f (zipper-node loc) args)))

(defun insert-child (loc item)
  "Inserts item as the leftmost child of the node at this loc,
   without moving."
  (zip-replace loc
               (make-node loc
                          (zipper-node loc)
                          (cons item (if (branch? loc)
                                         (let ((c (children loc)))
                                           (if (listp c) c
                                               (let ((items nil)
                                                     (s (seq c)))
                                                 (loop while (and s (not (empty? s)))
                                                       do (cl:push (first s) items)
                                                          (setf s (rest s)))
                                                 (nreverse items))))
                                         nil)))))

(defun append-child (loc item)
  "Inserts item as the rightmost child of the node at this loc,
   without moving."
  (zip-replace loc
               (make-node loc
                          (zipper-node loc)
                          (cl:append (if (branch? loc)
                                         (let ((c (children loc)))
                                           (if (listp c) c
                                               (let ((items nil)
                                                     (s (seq c)))
                                                 (loop while (and s (not (empty? s)))
                                                       do (cl:push (first s) items)
                                                          (setf s (rest s)))
                                                 (nreverse items))))
                                         nil)
                                     (cl:list item)))))

(defun insert-left (loc item)
  "Inserts item as the left sibling of the node at this loc,
   without moving."
  (if (null (zipper-parent-nodes loc))
      (error "Insert left at top")
      (make-instance '<zipper>
                     :node (zipper-node loc)
                     :branch-fn (zipper-branch-fn loc)
                     :children-fn (zipper-children-fn loc)
                     :make-node-fn (zipper-make-node-fn loc)
                     :path (zipper-path loc)
                     :lefts (cons item (zipper-lefts loc))
                     :rights (zipper-rights loc)
                     :parent-nodes (zipper-parent-nodes loc)
                     :changed t)))

(defun insert-right (loc item)
  "Inserts item as the right sibling of the node at this loc,
   without moving."
  (if (null (zipper-parent-nodes loc))
      (error "Insert right at top")
      (make-instance '<zipper>
                     :node (zipper-node loc)
                     :branch-fn (zipper-branch-fn loc)
                     :children-fn (zipper-children-fn loc)
                     :make-node-fn (zipper-make-node-fn loc)
                     :path (zipper-path loc)
                     :lefts (zipper-lefts loc)
                     :rights (cons item (zipper-rights loc))
                     :parent-nodes (zipper-parent-nodes loc)
                     :changed t)))

(defun zip-remove (loc)
  "Removes the node at loc, returning the loc that would have preceded it in a depth-first walk."
  (if (null (zipper-parent-nodes loc))
      (error "Remove at top")
      (if (zipper-lefts loc)
          ;; Move to left sibling and go to rightmost descendant
          (let ((new-loc (make-instance '<zipper>
                                        :node (car (zipper-lefts loc))
                                        :branch-fn (zipper-branch-fn loc)
                                        :children-fn (zipper-children-fn loc)
                                        :make-node-fn (zipper-make-node-fn loc)
                                        :path (zipper-path loc)
                                        :lefts (cdr (zipper-lefts loc))
                                        :rights (zipper-rights loc)
                                        :parent-nodes (zipper-parent-nodes loc)
                                        :changed t)))
            (labels ((rightmost-descendant (l)
                       (if (and (branch? l)
                                (let ((c (children l)))
                                  (and c (not (empty? c)))))
                           (rightmost-descendant (rightmost (down l)))
                           l)))
              (rightmost-descendant new-loc)))
          ;; No left sibling, go to parent
          (let ((parent-loc (car (zipper-parent-nodes loc))))
            (make-instance '<zipper>
                           :node (make-node parent-loc
                                            (zipper-node parent-loc)
                                            (zipper-rights loc))
                           :branch-fn (zipper-branch-fn loc)
                           :children-fn (zipper-children-fn loc)
                           :make-node-fn (zipper-make-node-fn loc)
                           :path (zipper-path parent-loc)
                           :lefts (zipper-lefts parent-loc)
                           :rights (zipper-rights parent-loc)
                           :parent-nodes (zipper-parent-nodes parent-loc)
                           :changed t)))))

(defun end? (loc)
  "Returns true if loc represents the end of a depth-first walk."
  (eq (zipper-node loc) :zip-end))

(defun zip-next (loc)
  "Moves to the next loc in the hierarchy, depth-first.
   When reaching the end, returns a distinguished loc detectable via end?."
  (if (end? loc)
      loc
      (cl:or (cl:and (branch? loc) (down loc))
             (right loc)
             (loop for p = (up loc) then (up p)
                   while p
                   do (when (right p)
                        (return (right p)))
                   finally (return (make-instance '<zipper>
                                                  :node :zip-end
                                                  :branch-fn (zipper-branch-fn loc)
                                                  :children-fn (zipper-children-fn loc)
                                                  :make-node-fn (zipper-make-node-fn loc)))))))

(defun prev (loc)
  "Moves to the previous loc in the hierarchy, depth-first.
   Returns nil if at the root."
  (if (zipper-lefts loc)
      ;; Go to left sibling and descend to rightmost leaf
      (let ((left-sib (left loc)))
        (labels ((rightmost-descendant (l)
                   (if (and (branch? l)
                            (let ((c (children l)))
                              (and c (not (empty? c)))))
                       (rightmost-descendant (rightmost (down l)))
                       l)))
          (rightmost-descendant left-sib)))
      ;; No left sibling, go to parent
      (up loc)))
