;;;; seq-ops.lisp - Sequence operations: assoc, assoc-in, sub
;;;;
;;;; These generic functions operate on vectors, dicts, lists, and strings.

(in-package :fol.collection)

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

(defmethod first ((v <vector>))
  "Return the first element of a vector, or NIL if empty."
  (if (cl:zerop (fset:size (pslot-value v 'items)))
      nil
      (fset:@ (pslot-value v 'items) 0)))

(defmethod rest ((v <vector>))
  "Return a new vector containing all but the first element."
  (let ((items (pslot-value v 'items)))
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
  (let ((items (pslot-value v 'items)))
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


;;; ============================================================================
;;; GENERIC COLLECTION PROTOCOLS
;;; ============================================================================

;;; 1. SIZE
(defgeneric size (collection)
  (:documentation "Returns the number of elements in the collection."))

(defmethod size ((c <collection>))
  (fset:size (pslot-value c 'items)))

(defmethod size ((s <sorted-set>))
  "Return number of elements in sorted-set."
  (fset:size (pslot-value s 'items)))

(defmethod size ((s <ordered-set>))
  "Return number of elements in ordered-set."
  (fset:size (pslot-value s 'fol.collection::items)))

(defmethod size ((s <dense-int-set>))
  "Return number of elements in dense-int-set (count of 1 bits)."
  (count 1 (pslot-value s 'fol.collection::bits)))

;;; 2. EMPTY?
(defgeneric empty? (collection)
  (:documentation "Returns T if the collection is empty, NIL otherwise."))

(defmethod empty? ((c <collection>))
  (if (fset:empty? (pslot-value c 'items))
      t
      nil))

(defmethod empty? ((s <sorted-set>))
  "Check if sorted-set is empty."
  (if (fset:empty? (pslot-value s 'items))
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
            (cl:push (cons k v) pairs))
          (apply #'make-list (nreverse pairs))))))

(defmethod seq ((s <set>))
  "For sets, return a list of elements (keys only)."
  (let ((items (pslot-value s 'items)))
    (if (fset:empty? items)
        nil
        (let ((elems nil))
          (fset:do-map (k v items)
            (declare (ignore v))
            (cl:push k elems))
          (apply #'make-list (nreverse elems))))))

(defmethod seq ((s <sorted-set>))
  "For sorted-sets, return a list of elements in sorted order."
  (let ((items (pslot-value s 'items)))
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

(defmethod seq ((b <bag>))
  "For bags, return a list with elements repeated by their count."
  (let ((items (pslot-value b 'items)))
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

(defmethod contains? ((s <sorted-set>) item)
  "Check if ITEM is in sorted-set."
  (if (fset:contains? (pslot-value s 'items) (fol.wrappers:fol-value item))
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

(defmethod add ((s <sorted-set>) item &optional value)
  "Add ITEM to sorted-set, maintaining sorted order."
  (declare (ignore value))
  (let ((new-set (fset:with (pslot-value s 'items)
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
  (let ((items (pslot-value v 'items)))
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
                 :items (fset:less (pslot-value d 'items)
                                   (fol.wrappers:fol-value key))))

(defmethod remove ((s <set>) item)
  (make-instance (class-of s)
                 :items (fset:less (pslot-value s 'items)
                                   (fol.wrappers:fol-value item))))

(defmethod remove ((s <sorted-set>) item)
  "Remove ITEM from sorted-set."
  (let ((raw (fol.wrappers:fol-value item)))
    (make-instance (class-of s)
                   :items (fset:less (pslot-value s 'items) raw))))

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

;;; 7. DISJ (Clojure-style removal for unordered collections)

(defgeneric disj (collection item)
  (:documentation "Returns a new collection with ITEM removed.
   For dicts: removes the key and its value.
   For sets: removes the item.
   For bags: decrements the count of item; removes if count becomes 0."))

(defmethod disj ((d <dict>) key)
  "Return a copy of the dict with KEY and its value removed."
  (remove d key))

(defmethod disj ((s <set>) item)
  "Return a copy of the set with ITEM removed."
  (remove s item))

(defmethod disj ((b <bag>) item)
  "Decrement count of ITEM; remove if count becomes 0."
  (remove b item))

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
    (let* ((items (pslot-value coll 'items))
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
                    (items (pslot-value keys 'items)))
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
                     (items (pslot-value coll 'items))
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
                     (items (pslot-value coll 'items))
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
         (items (pslot-value coll 'items))
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
  (let* ((seq (pslot-value v 'items))
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
  (let* ((seq (pslot-value v 'items))
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
  (let* ((seq (pslot-value v 'items))
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
  (:documentation "Return a seq of the items in COLL in reverse order.
   Only works on ordered collections (vectors, lists, arrays).
   Returns NIL for empty collections."))

(defmethod rseq ((v <vector>))
  "Return a seq of vector elements in reverse order."
  (if (empty? v)
      nil
      (let* ((items (pslot-value v 'items))
             (len (fset:size items)))
        (labels ((build-list (idx acc)
                   (if (cl:>= idx len)
                       acc
                       (build-list (cl:1+ idx) (cl:cons (fset:@ items idx) acc)))))
          (apply #'make-list (build-list 0 nil))))))

(defmethod rseq ((lst <list>))
  "Return a seq of list elements in reverse order."
  (if (empty? lst)
      nil
      (reverse lst)))

(defmethod rseq ((arr <array>))
  "Return a seq of array elements in reverse order (flattened)."
  (if (empty? arr)
      nil
      (let* ((items (pslot-value arr 'items))
             (len (fset:size items)))
        (labels ((build-list (idx acc)
                   (if (cl:>= idx len)
                       acc
                       (build-list (cl:1+ idx) (cl:cons (fset:@ items idx) acc)))))
          (apply #'make-list (build-list 0 nil))))))

(defmethod rseq ((lst list))
  "Return a seq of CL list elements in reverse order."
  (if (null lst)
      nil
      (cl:reverse lst)))

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
  (let ((items (pslot-value d 'items))
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
  (let* ((items (pslot-value v 'items))
         (len (fset:size items))
         (acc init))
    (loop for idx from 0 below len
          do (when (<reduced>? acc)
               (return-from reduce-kv (unreduced acc)))
             (setf acc (funcall f acc idx (fset:@ items idx))))
    (if (<reduced>? acc)
        (unreduced acc)
        acc)))
