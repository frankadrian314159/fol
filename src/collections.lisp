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

(defmethod <collection>? ((obj <collection>))
  (declare (ignore obj))
  t)

(defmethod <collection>? (obj)
  (declare (ignore obj))
  nil)

;;; ============================================================================
;;; Collection Protocol
;;; ============================================================================

(defgeneric collection-size (collection)
  (:documentation "Return the number of elements in COLLECTION."))

(defmethod collection-size ((c <collection>))
  (declare (ignore c))
  0)

(defmethod collection-size ((c t))
  (if (listp c)
      (length c)
      0))

(defgeneric collection-empty-p (collection)
  (:documentation "Return T if COLLECTION has no elements."))

(defmethod collection-empty-p ((c <collection>))
  "Default: empty when size is zero."
  (zerop (collection-size c)))

(defmethod collection-empty-p ((c t))
  (if (listp c)
      (null c)
      t))

(defgeneric collection-conj (collection element)
  (:documentation "Return a new collection with ELEMENT added.
                   The position of the new element depends on the collection type."))

(defgeneric collection-assoc (coll key val))

(defgeneric collection-dissoc (coll key))

(defgeneric collection-ref (coll key &optional not-found))

(defgeneric collection-seq (collection)
  (:documentation "Return the elements of COLLECTION as a CL list.
                   For dicts, returns a list of (key . value) cons pairs."))

(defmethod collection-seq ((c t))
  (if (listp c)
      c
      nil))

(defgeneric collection-lazy-seq (collection)
  (:documentation "Return the elements of COLLECTION as a FOL lazy sequence.
                   For dicts, returns lazy-seq of (key . value) cons pairs.
                   For vectors/sets, returns lazy-seq of elements."))


;;; ============================================================================
;;; Comparator Interface
;;; ============================================================================

(defclass <comparator-mixin> (standard-object)
    ((cmp-fn :initarg :cmp-fn
             :initform #'(lambda (a b)
                           (cond ((< a b) -1)
                                 ((> a b) 1)
                                 (t 0)))
             :reader cmp-fn))
  (:documentation "Base comparator class for sorted collections.
                   The compare function returns -1, 0, or 1."))

(defclass <fast-fixnum-comparator-mixin> (<comparator-mixin>) ()
  (:default-initargs :cmp-fn #'(lambda (a b)
                                 (declare (optimize (speed 3) (safety 0))
                                          (type fixnum a)
                                          (type fixnum b))
                                 (if (< a b) 1 (if (< b a) -1 0)))))

(defclass <universal-comparator-mixin> (<comparator-mixin>) ()
  (:default-initargs :cmp-fn #'fol.compiler.compareops:%universal-comparator))

;;; ============================================================================
;;; Unordered Collection
;;; ============================================================================

(defclass <unordered-collection> (<collection>)
    ()
  (:documentation "Abstract base class for unordered collections (dicts, sets, bags).
                   Elements have no guaranteed iteration order."))

(defgeneric <unordered-collection>? (obj)
  (:documentation "Returns T if OBJ is a FOL <unordered-collection>."))

(defmethod <unordered-collection>? ((obj <unordered-collection>))
  (declare (ignore obj))
  t)

(defmethod <unordered-collection>? (obj)
  (declare (ignore obj))
  nil)

;;; ============================================================================
;;; Ordered Collection
;;; ============================================================================

(defclass <ordered-collection> (<collection>)
    ()
  (:documentation "Abstract base class for ordered collections (vectors, lists, deques).
                   Elements maintain a defined sequence order."))

(defgeneric <ordered-collection>? (obj)
  (:documentation "Returns T if OBJ is a FOL <ordered-collection>."))

(defmethod <ordered-collection>? ((obj <ordered-collection>))
  (declare (ignore obj))
  t)

(defmethod <ordered-collection>? (obj)
  (declare (ignore obj))
  nil)

;;; ============================================================================
;;; F64-vector
;;; ============================================================================

(defclass <f64-vector> (<ordered-collection> <vec-f64-storage-mixin>)
    ()
  (:documentation "A persistent ordered vector backed by an handcoded vec-t trie."))

(defgeneric <f64-vector>? (obj)
  (:documentation "Returns T if OBJ is a FOL <vector>."))

(defmethod <f64-vector>? ((obj <f64-vector>))
  (declare (ignore obj))
  t)

(defmethod <f64-vector>? (obj)
  (declare (ignore obj))
  nil)

(defmethod make ((class (eql '<f64-vector>)) &rest args)
  (if (and (= (length args) 2) (eq (first args) :initial-element))
      ;; Use our high-speed aliased constructor
      (make-instance '<f64-vector>
        :storage (%make-filled-vec-f64 (second args) (first args)))
      ;; Otherwise, fall back to standard element-by-element insertion
      (let ((v (make-instance '<f64-vector>)))
        (dolist (e args) (setf v (collection-conj v e)))
        v)))

;;; --- Protocol methods for <vector> ---

(defmethod collection-size ((v <f64-vector>))
  (fol.compiler.collection-primitives:size v))

(defun f64-pvec-leaf-for (pvec index)
  "Returns the internal 32-element simple-vector containing the INDEX."
  (declare (type %vec-f64 pvec)
           (type fixnum index)
           (optimize (speed 3) (safety 0)))
  (let ((count (%f64-count pvec)))
    (if (>= index (logand count (lognot 31))) ; Is it in the tail?
        (%f64-tail pvec)
        (let ((node (%f64-root pvec)))
          (loop for level-shift from (%f64-shift pvec) downto 5 by 5
                for child-idx = (logand (ash index (- level-shift)) 31)
                do (setf node (svref (the simple-vector node) child-idx)))
          node))))

(defun f64-pvec-iterator (pvec)
  "Returns a closure that yields elements of PVEC one by one, 
   fetching tree nodes only once every 32 elements."
  (let ((count (%f64-count pvec))
        (global-idx 0)
        (chunk-idx 32) ; Force an immediate fetch on the first call
        (current-chunk nil))
    (declare (type fixnum count global-idx chunk-idx))

    (lambda ()
      (if (>= global-idx count)
          :eof
          (progn
           (when (>= chunk-idx 32)
                 (setf current-chunk (f64-pvec-leaf-for pvec global-idx)
                   chunk-idx 0))
           (let ((val (aref (the (simple-array double-float (32)) current-chunk) chunk-idx)))
             (incf global-idx)
             (incf chunk-idx)
             val))))))

(defun f64-pvec->lazy-seq (pvec)
  (let ((iter (f64-pvec-iterator pvec)))
    (labels ((build-seq ()
                        (let ((val (funcall iter)))
                          (if (eq val :eof)
                              nil
                              (make-instance '<list> :first-elem val :rest-list (make-instance '<lazy-seq> :thunk #'build-seq))))))
      (build-seq))))

(defmethod collection-seq ((coll <f64-vector>))
  (let ((iter (f64-pvec-iterator coll)) (result nil))
    (loop for val = (funcall iter) until (eq val :eof) do (push val result))
    (nreverse result)))

(defmethod collection-lazy-seq ((coll <f64-vector>))
  (f64-pvec->lazy-seq coll))

(defmethod collection-ref ((coll <f64-vector>) key &optional not-found)
  (ref coll key not-found))

(defmethod collection-assoc ((coll <f64-vector>) key value)
  (fol.compiler.collection-primitives:assoc coll key value))

(defmethod collection-dissoc ((coll <f64-vector>) key)
  (error "Cannot dissoc element ~A from vector ~A." key coll))

(defmethod collection-conj ((coll <f64-vector>) val)
  (fol.compiler.collection-primitives:conj coll val))

;;; ============================================================================
;;; F32-vector
;;; ============================================================================

(defclass <f32-vector> (<ordered-collection> <vec-f32-storage-mixin>)
    ()
  (:documentation "A persistent ordered vector backed by an handcoded vec-t trie."))

(defgeneric <f32-vector>? (obj)
  (:documentation "Returns T if OBJ is a FOL <vector>."))

(defmethod <f32-vector>? ((obj <f32-vector>))
  (declare (ignore obj))
  t)

(defmethod <f32-vector>? (obj)
  (declare (ignore obj))
  nil)

(defmethod make ((class (eql '<f32-vector>)) &rest args)
  (if (and (= (length args) 2) (eq (first args) :initial-element))
      ;; Use our high-speed aliased constructor
      (make-instance '<f32-vector>
        :storage (%make-filled-vec-f32 (second args) (first args)))
      ;; Otherwise, fall back to standard element-by-element insertion
      (let ((v (make-instance '<f32-vector>)))
        (dolist (e args) (setf v (collection-conj v e)))
        v)))

;;; --- Protocol methods for <vector> ---

(defmethod collection-size ((v <f32-vector>))
  (fol.compiler.collection-primitives:size v))

(defun f32-pvec-leaf-for (pvec index)
  "Returns the internal 32-element simple-vector containing the INDEX."
  (declare (type %vec-f32 pvec)
           (type fixnum index)
           (optimize (speed 3) (safety 0)))
  (let ((count (%f32-count pvec)))
    (if (>= index (logand count (lognot 31))) ; Is it in the tail?
        (%f32-tail pvec)
        (let ((node (%f32-root pvec)))
          (loop for level-shift from (%f32-shift pvec) downto 5 by 5
                for child-idx = (logand (ash index (- level-shift)) 31)
                do (setf node (svref (the simple-vector node) child-idx)))
          node))))

(defun f32-pvec-iterator (pvec)
  "Returns a closure that yields elements of PVEC one by one, 
   fetching tree nodes only once every 32 elements."
  (let ((count (%f32-count pvec))
        (global-idx 0)
        (chunk-idx 32) ; Force an immediate fetch on the first call
        (current-chunk nil))
    (declare (type fixnum count global-idx chunk-idx))

    (lambda ()
      (if (>= global-idx count)
          :eof
          (progn
           (when (>= chunk-idx 32)
                 (setf current-chunk (f32-pvec-leaf-for pvec global-idx)
                   chunk-idx 0))
           (let ((val (aref (the (simple-array single-float (32)) current-chunk) chunk-idx)))
             (incf global-idx)
             (incf chunk-idx)
             val))))))

(defun f32-pvec->lazy-seq (pvec)
  (let ((iter (f32-pvec-iterator pvec)))
    (labels ((build-seq ()
                        (let ((val (funcall iter)))
                          (if (eq val :eof)
                              nil
                              (make-instance '<list> :first-elem val :rest-list (make-instance '<lazy-seq> :thunk #'build-seq))))))
      (build-seq))))

(defmethod collection-seq ((coll <f32-vector>))
  (let ((iter (f32-pvec-iterator coll)) (result nil))
    (loop for val = (funcall iter) until (eq val :eof) do (push val result))
    (nreverse result)))

(defmethod collection-lazy-seq ((coll <f32-vector>))
  (f32-pvec->lazy-seq coll))

(defmethod collection-ref ((coll <f32-vector>) key &optional not-found)
  (ref coll key not-found))

(defmethod collection-assoc ((coll <f32-vector>) key value)
  (fol.compiler.collection-primitives:assoc coll key value))

(defmethod collection-dissoc ((coll <f32-vector>) key)
  (error "Cannot dissoc element ~A from vector ~A." key coll))

(defmethod collection-conj ((coll <f32-vector>) val)
  (fol.compiler.collection-primitives:conj coll val))

;;; ============================================================================
;;; Vector
;;; ============================================================================

(defclass <vector> (<ordered-collection> <vec-t-storage-mixin>)
    ()
  (:documentation "A persistent ordered vector backed by an handcoded vec-t trie."))

(defgeneric <vector>? (obj)
  (:documentation "Returns T if OBJ is a FOL <vector>."))

(defmethod <vector>? ((obj <vector>))
  (declare (ignore obj))
  t)

(defmethod <vector>? (obj)
  (declare (ignore obj))
  nil)

(defmethod make ((class (eql '<vector>)) &rest args)
  (if (and (= (length args) 2) (eq (cl:first args) :initial-element))
      ;; Use our high-speed aliased constructor
      (make-instance class
        :storage (%make-filled-vec-t (cl:second args) (cl:first args)))
      ;; Otherwise, fall back to standard element-by-element insertion
      (let ((v (make-instance class)))
        (cl:dolist (e args) (cl:setf v (collection-conj v e)))
        v)))

;;; --- Protocol methods for <vector> ---

(defmethod collection-size ((v <vector>))
  (fol.compiler.collection-primitives:size v))

(defun pvec-leaf-for (pvec index)
  "Returns the internal 32-element simple-vector containing the INDEX.
   PVEC is a raw %vec-t struct."
  (declare (type %vec-t pvec)
           (type fixnum index)
           (optimize (speed 3) (safety 0)))
  (let ((count (%t-count pvec)))
    (if (>= index (logand count (lognot 31))) ; Is it in the tail?
        (%t-tail pvec)
        (let ((node (%t-root pvec)))
          (loop for level-shift from (%t-shift pvec) downto 5 by 5
                for child-idx = (logand (ash index (- level-shift)) 31)
                do (setf node (svref (the simple-vector node) child-idx)))
          node))))

(defun pvec-iterator (vec)
  "Returns a closure that yields elements of VEC (a <vector>) one by one,
   fetching tree nodes only once every 32 elements."
  (let* ((pvec (storage vec))
         (count (%t-count pvec))
         (global-idx 0)
         (chunk-idx 32) ; Force an immediate fetch on the first call
         (current-chunk nil))
    (declare (type fixnum count global-idx chunk-idx))

    (lambda ()
      (if (>= global-idx count)
          :eof
          (progn
           ;; Only traverse the tree when we exhaust the current 32-item chunk
           (when (= chunk-idx 32)
                 (setf current-chunk (pvec-leaf-for pvec global-idx))
                 (setf chunk-idx 0))

           ;; Fast-path: read directly from the cached leaf array
           (let ((val (svref (the simple-vector current-chunk) chunk-idx)))
             (incf global-idx)
             (incf chunk-idx)
             val))))))

(defmacro lazy-cons (val rest-form)
  "Create a lazy-seq that, when realized, produces a <list> node
   with VAL as the first element and REST-FORM (lazily evaluated)
   as the rest of the sequence."
  (let ((v (gensym "VAL")))
    `(let ((,v ,val))
       (make-instance '<lazy-seq>
         :thunk (lambda ()
                  (make-instance '<list>
                    :first-elem ,v
                    :rest-list ,rest-form
                    :list-size 1))))))

(defun pvec->lazy-seq (pvec)
  "Converts a persistent vector into a standard lazy sequence."
  (let ((iter (pvec-iterator pvec)))
    (labels ((build-seq ()
                        (let ((val (funcall iter)))
                          (if (eq val :eof)
                              nil ; Or your language's empty sequence marker
                              ;; Delay the evaluation of the rest of the sequence
                              (lazy-cons val (build-seq))))))
      (build-seq))))

(defmethod collection-seq ((coll <vector>))
  (let ((iter (fol.compiler.collection-primitives::%vec-t-iterator (storage coll)))
        (result nil))
    (loop for val = (funcall iter)
          until (eq val :eof)
          do (push val result))
    (nreverse result)))

(defmethod collection-lazy-seq ((coll <vector>))
  (pvec->lazy-seq coll))

(defmethod collection-ref ((coll <vector>) key &optional not-found)
  (ref coll key not-found))

(defmethod collection-assoc ((coll <vector>) key value)
  (fol.compiler.collection-primitives:assoc coll key value))

(defmethod collection-dissoc ((coll <vector>) key)
  (error "Cannot dissoc element ~A from vector ~A." key coll))

(defmethod collection-conj ((coll <vector>) val)
  (fol.compiler.collection-primitives:conj coll val))

;;; ============================================================================
;;; fix64-vector
;;; ============================================================================

(defclass <fix64-vector> (<ordered-collection> <vec-fix64-storage-mixin>)
    ()
  (:documentation "A persistent ordered vector backed by an handcoded vec-t trie."))

(defgeneric <fix64-vector>? (obj)
  (:documentation "Returns T if OBJ is a FOL <vector>."))

(defmethod <fix64-vector>? ((obj <fix64-vector>))
  (declare (ignore obj))
  t)

(defmethod <fix64-vector>? (obj)
  (declare (ignore obj))
  nil)

(defmethod make ((class (eql '<fix64-vector>)) &rest args)
  (if (and (= (length args) 2) (eq (first args) :initial-element))
      ;; Use our high-speed aliased constructor
      (make-instance '<fix64-vector>
        :storage (%make-filled-vec-fix64 (second args) (first args)))
      ;; Otherwise, fall back to standard element-by-element insertion
      (let ((v (make-instance '<fix64-vector>)))
        (dolist (e args) (setf v (collection-conj v e)))
        v)))

;;; --- Protocol methods for <vector> ---

(defmethod collection-size ((v <fix64-vector>))
  (fol.compiler.collection-primitives:size v))

(defun fix64-pvec-leaf-for (pvec index)
  "Returns the internal 32-element simple-vector containing the INDEX."
  (declare (type %vec-fix64 pvec)
           (type fixnum index)
           (optimize (speed 3) (safety 0)))
  (let ((count (%fix64-count pvec)))
    (if (>= index (logand count (lognot 31))) ; Is it in the tail?
        (%fix64-tail pvec)
        (let ((node (%fix64-root pvec)))
          (loop for level-shift from (%fix64-shift pvec) downto 5 by 5
                for child-idx = (logand (ash index (- level-shift)) 31)
                do (setf node (svref (the simple-vector node) child-idx)))
          node))))

(defun fix64-pvec-iterator (pvec)
  "Returns a closure that yields elements of PVEC one by one, 
   fetching tree nodes only once every 32 elements."
  (let ((count (%fix64-count pvec))
        (global-idx 0)
        (chunk-idx 32) ; Force an immediate fetch on the first call
        (current-chunk nil))
    (declare (type fixnum count global-idx chunk-idx))

    (lambda ()
      (if (>= global-idx count)
          :eof
          (progn
           (when (>= chunk-idx 32)
                 (setf current-chunk (fix64-pvec-leaf-for pvec global-idx)
                   chunk-idx 0))
           (let ((val (aref (the (simple-array fixnum (32)) current-chunk) chunk-idx)))
             (incf global-idx)
             (incf chunk-idx)
             val))))))

(defun fix64-pvec->lazy-seq (pvec)
  (let ((iter (fix64-pvec-iterator pvec)))
    (labels ((build-seq ()
                        (let ((val (funcall iter)))
                          (if (eq val :eof)
                              nil
                              (make-instance '<list> :first-elem val :rest-list (make-instance '<lazy-seq> :thunk #'build-seq))))))
      (build-seq))))

(defmethod collection-seq ((coll <fix64-vector>))
  (let ((iter (fix64-pvec-iterator coll)) (result nil))
    (loop for val = (funcall iter) until (eq val :eof) do (push val result))
    (nreverse result)))

(defmethod collection-lazy-seq ((coll <fix64-vector>))
  (fix64-pvec->lazy-seq coll))

(defmethod collection-ref ((coll <fix64-vector>) key &optional not-found)
  (ref coll key not-found))

(defmethod collection-assoc ((coll <fix64-vector>) key value)
  (fol.compiler.collection-primitives:assoc coll key value))

(defmethod collection-dissoc ((coll <fix64-vector>) key)
  (error "Cannot dissoc element ~A from vector ~A." key coll))

(defmethod collection-conj ((coll <fix64-vector>) val)
  (fol.compiler.collection-primitives:conj coll val))

;;; ============================================================================
;;; F64-array (subclass of f64-vector)
;;; ============================================================================

(defclass <f64-array> (<f64-vector>)
    ((dimension :initarg :dimension
                :initform '(1)
                :reader array-dimension
                :documentation "List of dimension sizes, as in CL array-dimensions."))
  (:default-initargs :items (cl:make-array 0))
  (:documentation "A persistent array.
                   Subclass of <vector> with O(1) indexed access and
                   a dimension slot tracking shape."))

(defgeneric <f64-array>? (obj)
  (:documentation "Returns T if OBJ is a FOL <array>."))

(defmethod <f64-array>? (obj)
  (declare (ignore obj))
  nil)

(defmethod <f64-array>? ((obj <f64-array>))
  (declare (ignore obj))
  t)

(defmethod initialize-instance :after ((a <f64-array>) &key)
  "Validate that all dimension entries are non-negative integers."
  (dolist (d (array-dimension a))
    (unless (and (integerp d) (>= d 0))
      (error "Array dimension ~A is not a non-negative integer" d))))

(defmethod make ((class (eql '<f64-array>)) &rest args)
  (let* ((has-dims (eq (cl:first args) :dimensions))
         (dimensions (if has-dims (cl:second args) (cl:first args)))
         (elements (if has-dims (cl:cddr args) (cl:rest args)))

         ;; Normalize dimensions to a list to calculate expected capacity
         (dims-list (if (listp dimensions) dimensions (coerce dimensions 'cl:list)))
         (expected-size (reduce #'* dims-list :initial-value 1)))

    (cond
     ;; FAST PATH 1: Single repeating initial element (O(log N) memory aliasing)
     ((eq (cl:first elements) :initial-element)
       (make-instance '<array>
         :dimension dimensions
         :storage (fol.compiler.collection-primitives::%make-filled-vec-f64
                   expected-size
                   (cl:second elements))))

     ;; FAST PATH 2: A sequence of distinct initial elements (O(N) bottom-up builder)
     (elements
       ;; Optional: You can add an error check here to ensure (length elements) == expected-size
       (make-instance '<array>
         :dimension dimensions
         :storage (fol.compiler.collection-primitives::%build-vec-f64-from-list elements)))

     ;; FAST PATH 3: Empty array (fallback)
     (t
       (make-instance '<array>
         :dimension dimensions
         :storage fol.compiler.collection-primitives::%empty-vec-f64)))))

;;; --- Protocol methods for <array> (override <vector> FSet-based methods) ---

(defmethod collection-size ((a <f64-array>))
  (fol.compiler.collection-primitives:size a))

(defmethod collection-seq ((coll <f64-array>))
  (let ((iter (f64-pvec-iterator coll)) (result nil))
    (loop for val = (funcall iter) until (eq val :eof) do (push val result))
    (nreverse result)))

(defmethod collection-lazy-seq ((coll <f64-array>))
  (f64-pvec->lazy-seq coll))

(defmethod collection-ref ((coll <f64-array>) key &optional not-found)
  (let ((idx (%column-major-idx (array-dimensions coll) key)))
    (ref coll idx not-found)))

(defmethod collection-assoc ((coll <f64-array>) key value)
  (let ((idx (%column-major-idx (array-dimensions coll) key)))
    (fol.compiler.collection-primitives:assoc coll idx value)))

(defmethod collection-dissoc ((coll <f64-array>) key)
  (error "Cannot dissoc element ~A from array ~A." key coll))

(defmethod collection-conj ((coll <f64-array>) val)
  (fol.compiler.collection-primitives:conj coll val))

;;; ============================================================================
;;; f32-array (subclass of f32-vector)
;;; ============================================================================

(defclass <f32-array> (<f32-vector>)
    ((dimension :initarg :dimension
                :initform '(1)
                :reader array-dimension
                :documentation "List of dimension sizes, as in CL array-dimensions."))
  (:default-initargs :items (cl:make-array 0))
  (:documentation "A persistent array.
                   Subclass of <vector> with O(1) indexed access and
                   a dimension slot tracking shape."))

(defgeneric <f32-array>? (obj)
  (:documentation "Returns T if OBJ is a FOL <array>."))

(defmethod <f32-array>? (obj)
  (declare (ignore obj))
  nil)

(defmethod <f32-array>? ((obj <f32-array>))
  (declare (ignore obj))
  t)

(defmethod initialize-instance :after ((a <f32-array>) &key)
  "Validate that all dimension entries are non-negative integers."
  (dolist (d (array-dimension a))
    (unless (and (integerp d) (>= d 0))
      (error "Array dimension ~A is not a non-negative integer" d))))

(defmethod make ((class (eql '<f32-array>)) &rest args)
  (let* ((has-dims (eq (cl:first args) :dimensions))
         (dimensions (if has-dims (cl:second args) (cl:first args)))
         (elements (if has-dims (cl:cddr args) (cl:rest args)))

         ;; Normalize dimensions to a list to calculate expected capacity
         (dims-list (if (listp dimensions) dimensions (coerce dimensions 'cl:list)))
         (expected-size (reduce #'* dims-list :initial-value 1)))

    (cond
     ;; FAST PATH 1: Single repeating initial element (O(log N) memory aliasing)
     ((eq (cl:first elements) :initial-element)
       (make-instance '<array>
         :dimension dimensions
         :storage (fol.compiler.collection-primitives::%make-filled-vec-f32
                   expected-size
                   (cl:second elements))))

     ;; FAST PATH 2: A sequence of distinct initial elements (O(N) bottom-up builder)
     (elements
       ;; Optional: You can add an error check here to ensure (length elements) == expected-size
       (make-instance '<array>
         :dimension dimensions
         :storage (fol.compiler.collection-primitives::%build-vec-f32-from-list elements)))

     ;; FAST PATH 3: Empty array (fallback)
     (t
       (make-instance '<array>
         :dimension dimensions
         :storage fol.compiler.collection-primitives::%empty-vec-f32)))))

;;; --- Protocol methods for <array> (override <vector> FSet-based methods) ---

(defmethod collection-size ((a <f32-array>))
  (fol.compiler.collection-primitives:size a))

(defmethod collection-seq ((coll <f32-array>))
  (let ((iter (f32-pvec-iterator coll)) (result nil))
    (loop for val = (funcall iter) until (eq val :eof) do (push val result))
    (nreverse result)))

(defmethod collection-lazy-seq ((coll <f32-array>))
  (f32-pvec->lazy-seq coll))

(defmethod collection-ref ((coll <f32-array>) key &optional not-found)
  (let ((idx (%column-major-idx (array-dimensions coll) key)))
    (ref coll idx not-found)))

(defmethod collection-assoc ((coll <f32-array>) key value)
  (let ((idx (%column-major-idx (array-dimensions coll) key)))
    (fol.compiler.collection-primitives:assoc coll idx value)))

(defmethod collection-dissoc ((coll <f32-array>) key)
  (error "Cannot dissoc element ~A from array ~A." key coll))

(defmethod collection-conj ((coll <f32-array>) val)
  (fol.compiler.collection-primitives:conj coll val))

;;; ============================================================================
;;; Array (subclass of Vector)
;;; ============================================================================

(defclass <array> (<vector>)
    ((dimension :initarg :dimension
                :initform '(1)
                :reader array-dimension
                :documentation "List of dimension sizes, as in CL array-dimensions."))
  (:default-initargs :items (cl:make-array 0))
  (:documentation "A persistent array .
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

(defmethod make ((class (eql '<array>)) &rest args)
  (let* ((has-dims (eq (cl:first args) :dimensions))
         (dimensions (if has-dims (cl:second args) (cl:first args)))
         (elements (if has-dims (cl:cddr args) (cl:rest args)))

         ;; Normalize dimensions to a list to calculate expected capacity
         (dims-list (if (listp dimensions) dimensions (coerce dimensions 'cl:list)))
         (expected-size (reduce #'* dims-list :initial-value 1)))

    (cond
     ;; FAST PATH 1: Single repeating initial element (O(log N) memory aliasing)
     ((eq (cl:first elements) :initial-element)
       (make-instance '<array>
         :dimension dimensions
         :storage (fol.compiler.collection-primitives::%make-filled-vec-t
                   expected-size
                   (cl:second elements))))

     ;; FAST PATH 2: A sequence of distinct initial elements (O(N) bottom-up builder)
     (elements
       ;; Optional: You can add an error check here to ensure (length elements) == expected-size
       (make-instance '<array>
         :dimension dimensions
         :storage (fol.compiler.collection-primitives::%build-vec-t-from-list elements)))

     ;; FAST PATH 3: Empty array (fallback)
     (t
       (make-instance '<array>
         :dimension dimensions
         :storage fol.compiler.collection-primitives::%empty-vec-t)))))

;;; --- Protocol methods for <array> (override <vector> FSet-based methods) ---

(defmethod collection-size ((a <array>))
  (fol.compiler.collection-primitives:size a))

(defmethod collection-seq ((coll <array>))
  (let ((iter (fol.compiler.collection-primitives::%vec-t-iterator (storage coll)))
        (result nil))
    (loop for val = (funcall iter) until (eq val :eof) do (push val result))
    (nreverse result)))

(defmethod collection-lazy-seq ((coll <array>))
  (pvec->lazy-seq coll))

(defmethod collection-ref ((coll <array>) key &optional not-found)
  (let ((idx (%column-major-idx (array-dimensions coll) key)))
    (ref coll idx not-found)))

(defmethod collection-assoc ((coll <array>) key value)
  (let ((idx (%column-major-idx (array-dimensions coll) key)))
    (fol.compiler.collection-primitives:assoc coll idx value)))

(defmethod collection-dissoc ((coll <array>) key)
  (error "Cannot dissoc element ~A from array ~A." key coll))

(defmethod collection-conj ((coll <array>) val)
  (fol.compiler.collection-primitives:conj coll val))

;;; ============================================================================
;;; Fix64-array (subclass of fix64-vector)
;;; ============================================================================

(defclass <fix64-array> (<fix64-vector>)
    ((dimension :initarg :dimension
                :initform '(1)
                :reader array-dimension
                :documentation "List of dimension sizes, as in CL array-dimensions."))
  (:default-initargs :items (cl:make-array 0))
  (:documentation "A persistent array.
                   Subclass of <vector> with O(1) indexed access and
                   a dimension slot tracking shape."))

(defgeneric <fix64-array>? (obj)
  (:documentation "Returns T if OBJ is a FOL <array>."))

(defmethod <fix64-array>? (obj)
  (declare (ignore obj))
  nil)

(defmethod <fix64-array>? ((obj <fix64-array>))
  (declare (ignore obj))
  t)

(defmethod initialize-instance :after ((a <fix64-array>) &key)
  "Validate that all dimension entries are non-negative integers."
  (dolist (d (array-dimension a))
    (unless (and (integerp d) (>= d 0))
      (error "Array dimension ~A is not a non-negative integer" d))))

(defmethod make ((class (eql '<fix64-array>)) &rest args)
  (let* ((has-dims (eq (cl:first args) :dimensions))
         (dimensions (if has-dims (cl:second args) (cl:first args)))
         (elements (if has-dims (cl:cddr args) (cl:rest args)))

         ;; Normalize dimensions to a list to calculate expected capacity
         (dims-list (if (listp dimensions) dimensions (coerce dimensions 'cl:list)))
         (expected-size (reduce #'* dims-list :initial-value 1)))

    (cond
     ;; FAST PATH 1: Single repeating initial element (O(log N) memory aliasing)
     ((eq (cl:first elements) :initial-element)
       (make-instance '<array>
         :dimension dimensions
         :storage (fol.compiler.collection-primitives::%make-filled-vec-fix64
                   expected-size
                   (cl:second elements))))

     ;; FAST PATH 2: A sequence of distinct initial elements (O(N) bottom-up builder)
     (elements
       ;; Optional: You can add an error check here to ensure (length elements) == expected-size
       (make-instance '<array>
         :dimension dimensions
         :storage (fol.compiler.collection-primitives::%build-vec-fix64-from-list elements)))

     ;; FAST PATH 3: Empty array (fallback)
     (t
       (make-instance '<array>
         :dimension dimensions
         :storage fol.compiler.collection-primitives::%empty-vec-fix64)))))

;;; --- Protocol methods for <array> (override <vector> FSet-based methods) ---

(defmethod collection-size ((a <fix64-array>))
  (fol.compiler.collection-primitives:size a))

(defmethod collection-seq ((coll <fix64-array>))
  (let ((iter (fix64-pvec-iterator coll)) (result nil))
    (loop for val = (funcall iter) until (eq val :eof) do (push val result))
    (nreverse result)))

(defmethod collection-lazy-seq ((coll <fix64-array>))
  (fix64-pvec->lazy-seq coll))

(defmethod collection-ref ((coll <fix64-array>) key &optional not-found)
  (let ((idx (%column-major-idx (array-dimensions coll) key)))
    (ref coll idx not-found)))

(defmethod collection-assoc ((coll <fix64-array>) key value)
  (let ((idx (%column-major-idx (array-dimensions coll) key)))
    (fol.compiler.collection-primitives:assoc coll idx value)))

(defmethod collection-dissoc ((coll <fix64-array>) key)
  (error "Cannot dissoc element ~A from array ~A." key coll))

(defmethod collection-conj ((coll <fix64-array>) val)
  (fol.compiler.collection-primitives:conj coll val))

;;; ============================================================================
;;; Dict
;;; ============================================================================

(defclass <dict> (<unordered-collection> <dict-mixin> <collection-storage>)
    ()
  (:default-initargs :dict-storage (%make-hamt))
  (:documentation "A persistent unordered dictionary backed by a hand-coded hamt."))

(defgeneric <dict>? (obj)
  (:documentation "Returns T if OBJ is a FOL <dict>."))

(defmethod <dict>? ((obj <dict>))
  (declare (ignore obj))
  t)

(defmethod <dict>? (obj)
  (declare (ignore obj))
  nil)

(defmethod make ((class (eql '<dict>)) &rest args)
  (make-instance class
    :dict-storage (hamt-bulk-load args)))

(defmethod make ((class (eql '<array-dict>)) &rest args)
  "Create a new <array-dict> from alternating key-value ARGS.
   Keys are stored in the order provided; duplicate keys keep the last value
   and retain the position of the first occurrence.
   (make '<array-dict>)             => empty array dict
   (make '<array-dict> :a 1 :b 2)  => array dict with :a->1, :b->2"

  (make-instance '<array-dict>
    :dict-storage (hamt-bulk-load args)))

;;; --- Protocol methods for <dict> ---

(defmethod collection-size ((d <dict>))
  (fol.compiler.collection-primitives:size d))

(defmethod collection-empty-p ((d <dict>))
  (fol.compiler.collection-primitives:empty? d))

(defmethod collection-conj ((d <dict>) entry)
  "Add a key-val pair (cons cell) to the dict."
  (kv-conj d (car entry) (cdr entry)))

(defmethod collection-seq ((d <dict>))
  (let ((iter (fol.compiler.collection-primitives::hamt-iterator (dict-storage d)))
        (result nil))
    (loop for pair = (funcall iter)
          until (eq pair :eof)
          do (push pair result))
    (nreverse result)))

(defmethod collection-lazy-seq ((d <dict>))
  (seq d))

(defmethod collection-assoc ((d <dict>) key val)
  (fol.compiler.collection-primitives:assoc d key val))

(defmethod collection-dissoc ((d <dict>) key)
  (dissoc d key))

(defmethod collection-ref ((d <dict-mixin>) key &optional not-found)
  (ref d key not-found))

;;; ---------------------------------------------------------------------
;;; Helper
;;; ---------------------------------------------------------------------

(defun %vec-t-contains-p (v target &key (test #'eql))
  "Quickly scans a persistent vector for TARGET by checking 32-element chunks natively."
  (declare (type %vec-t v) (optimize (speed 3) (safety 0)))
  (let ((count (%t-count v)))
    (when (zerop count)
          (return-from %vec-t-contains-p nil))

    (labels ((search-node (node level)
                          (declare (type simple-vector node) (type fixnum level))
                          (if (zerop level)
                              ;; Base case: We hit a 32-element leaf. 
                              ;; Use native Lisp SIMD/optimized array search!
                              (when (find target (the simple-vector node) :test test)
                                    (return-from %vec-t-contains-p t))

                              ;; Recursive case: Internal routing node. Traverse children.
                              (loop for child across node
                                      when child do (search-node child (- level +bit-shift+))))))

      ;; 1. Scan the main tree (if it has elements)
      (when (> count 32)
            (search-node (%t-root v) (%t-shift v)))

      ;; 2. Scan the variable-length tail
      (let* ((tail (%t-tail v))
             (tail-len (logand count +bit-mask+))
             (actual-tail-len (if (and (zerop tail-len) (> count 0)) 32 tail-len)))
        (if (find target tail :end actual-tail-len :test test)
            t
            nil)))))

;;; ============================================================================
;;; Ordered Dict
;;; ============================================================================

(defclass <ordered-dict> (<dict> <ordered-collection> <vec-t-storage-mixin>) ()
  (:documentation "A persistent insertion-ordered dictionary.
                   Inherits the hash-map from <dict> for O(~1) lookup.
                   Maintains an seq of keys in insertion order."))

(defgeneric <ordered-dict>? (obj)
  (:documentation "Returns T if OBJ is a FOL <ordered-dict>."))

(defmethod <ordered-dict>? ((obj <ordered-dict>))
  (declare (ignore obj))
  t)

(defmethod <ordered-dict>? (obj)
  (declare (ignore obj))
  nil)

(defmethod make ((class (eql '<ordered-dict>)) &rest args)
  "Create a new <ordered-dict> from alternating key-value ARGS.
   Keys are stored in the order provided; duplicate keys keep the last value
   and retain the position of the first occurrence."

  ;; 1. Extract unique keys in insertion order using native Lisp
  (let ((seen (make-hash-table :test 'equal)) ; Use 'equal to match your HAMT hash rules
                                             (unique-keys nil))
    (loop for (k v) on args by #'cddr
          do (unless (gethash k seen)
               (setf (gethash k seen) t)
               (push k unique-keys)))

    ;; `push` builds the list backwards, so we reverse it destructively
    (setf unique-keys (nreverse unique-keys))

    ;; 2. Instatiate the object by calling our high-speed bulk loaders
    (make-instance '<ordered-dict>
      ;; Load the HAMT dictionary (transiently applies all args, overwriting duplicates)
      :dict-storage (fol.compiler.collection-primitives::hamt-bulk-load args)

      ;; Load the Vector (builds the trie bottom-up in strict O(N) time)
      :storage (fol.compiler.collection-primitives::%build-vec-t-from-list unique-keys))))

;;; --- Protocol methods for <ordered-dict> ---

(defmethod collection-size ((d <ordered-dict>))
  (fol.compiler.collection-primitives:size d))

(defmethod collection-empty-p ((d <ordered-dict>))
  (fol.compiler.collection-primitives:empty? d))

(defmethod collection-conj ((d <ordered-dict>) entry)
  "Add a key value pair (cons cell), preserving insertion order.
   If the key already exists, its value is updated in place."
  (kv-conj d (car entry) (cdr entry)))

(defmethod collection-seq ((d <ordered-dict>))
  "Return entries as (key . value) pairs in insertion order."
  (let ((h (dict-storage d))
        (key-iter (fol.compiler.collection-primitives::%vec-t-iterator (storage d)))
        (result nil))
    (loop for k = (funcall key-iter)
          until (eq k :eof)
          do (multiple-value-bind (val foundp)
                 (fol.compiler.collection-primitives::hamt-get h k)
               (when foundp
                     (push (cons k val) result))))
    (nreverse result)))

(defmethod collection-lazy-seq ((d <ordered-dict>))
  (seq d))

(defmethod collection-assoc ((d <ordered-dict>) key val)
  (fol.compiler.collection-primitives:assoc d key val))

(defmethod collection-dissoc ((d <ordered-dict>) key)
  (dissoc d key))

(defmethod collection-ref ((d <ordered-dict>) key &optional not-found)
  (ref d key not-found))

;;; ============================================================================
;;; Array Dict
;;; ============================================================================

(defclass <array-dict> (<ordered-dict>) ()
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

;;; ============================================================================
;;; Sorted Dict
;;; ============================================================================

(defclass <sorted-dict> (<unordered-collection> <ordered-collection> <sorted-dict-mixin> <universal-comparator-mixin> <collection-storage>)
    ()
  (:documentation "A persistent sorted dictionary backed by a hand-coded HAMT.
                   Inherits storage and insertion order from <dict>, and comparison from <comparator-mixin>.
                   Keys are maintained in the order defined by the comparator
                   function, which must return a negative fixnum, zero, or
                   positive fixnum for less-than, equal, and greater-than
                   respectively."))

(defgeneric <sorted-dict>? (obj)
  (:documentation "Returns T if OBJ is a FOL <sorted-dict>."))

(defmethod <sorted-dict>? ((obj <sorted-dict>))
  (declare (ignore obj))
  t)

(defmethod <sorted-dict>? (obj)
  (declare (ignore obj))
  nil)

;;; --- Protocol methods for <sorted-dict> ---

(defmethod collection-size ((d <sorted-dict>))
  (fol.compiler.collection-primitives:size d))

(defmethod collection-conj ((d <sorted-dict>) entry)
  "Add a key/value pair (cons cell) to the sorted dict in comparator order."
  (kv-conj d (car entry) (cdr entry)))

(defmethod collection-seq ((d <sorted-dict>))
  "Return entries as an alist of (key . value) pairs in comparator order."
  (let ((bd (fol.compiler.collection-primitives::storage-items d))
        (result nil))
    (let ((iter (fol.compiler.collection-primitives::btree-iterator
                 (fol.compiler.collection-primitives::btree-dict-root bd))))
      (loop
       (multiple-value-bind (key val) (funcall iter)
         (when (eq key :eof) (return))
         (push (cons key val) result))))
    (nreverse result)))

(defmethod collection-lazy-seq ((d <sorted-dict>))
  (seq d))

(defmethod collection-assoc ((d <sorted-dict>) key value)
  (fol.compiler.collection-primitives:assoc d key value))

(defmethod collection-dissoc ((d <sorted-dict>) key)
  (dissoc d key))

(defmethod collection-ref ((d <sorted-dict>) key &optional not-found)
  (ref d key not-found))

;;; ============================================================================
;;; Int Dict
;;; ============================================================================

(defclass <int-dict> (<unordered-collection> <ordered-collection> <sorted-dict-mixin> <fast-fixnum-comparator-mixin> <collection-storage>)
    ()
  (:documentation "A persistent sorted dictionary specialized for integer keys.
                   Backed by a hand-coded B-Tree."))

(defgeneric <int-dict>? (obj)
  (:documentation "Returns T if OBJ is a FOL <int-dict>."))

(defmethod <int-dict>? (obj)
  (declare (ignore obj))
  nil)

(defmethod <int-dict>? ((obj <int-dict>))
  (declare (ignore obj))
  t)

(defmethod make ((class (eql '<int-dict>)) &rest args)
  "Create a new <int-dict> from alternating integer-key value ARGS."
  (let* ((pairs args))
    (make-instance '<int-dict>
      :dict-storage (fol.compiler.collection-primitives::btree-bulk-load pairs #'%int-compare))))

;;; --- Protocol methods for <int-dict> ---

(defmethod collection-size ((d <int-dict>))
  (fol.compiler.collection-primitives:size d))

(defmethod collection-empty-p ((d <int-dict>))
  (fol.compiler.collection-primitives:empty? d))


(defgeneric comparator-compare (obj))
(defmethod comparator-compare ((obj <comparator-mixin>)) (cmp-fn obj))

(defun ordered-dict-key-order (d) (storage d))
(defun array-dict-key-order (d) (storage d))

(defmethod collection-conj ((d <int-dict>) entry)
  "Add a key/value pair (cons cell) to the sorted dict in comparator order."
  (kv-conj d (car entry) (cdr entry)))

(defmethod collection-seq ((d <int-dict>))
  "Return entries as an alist of (key . value) pairs in integer order."
  (let ((bd (fol.compiler.collection-primitives::storage-items d))
        (result nil))
    (let ((iter (fol.compiler.collection-primitives::btree-iterator
                 (fol.compiler.collection-primitives::btree-dict-root bd))))
      (loop
       (multiple-value-bind (key val) (funcall iter)
         (when (eq key :eof) (return))
         (push (cons key val) result))))
    (nreverse result)))

(defmethod collection-lazy-seq ((d <int-dict>))
  (seq d))

(defmethod collection-assoc ((d <int-dict>) key value)
  (fol.compiler.collection-primitives:assoc d key value))

(defmethod collection-dissoc ((d <int-dict>) key)
  (dissoc d key))

(defmethod collection-ref ((d <int-dict>) key &optional not-found)
  (ref d key not-found))


;;; ============================================================================
;;; Priority Dict
;;; ============================================================================

(defclass <priority-dict> (<dict-mixin> <sorted-dict-mixin> <universal-comparator-mixin>) ()
  (:documentation "A persistent priority dictionary backed by a hand-coded HAMT
                   and a hand-coded 32-way B-Tree.
                   Inherits the hash-map from <dict-mixin> for O(~1) key→priority lookup.
                   Maintains a B-Tree from <sorted-dict-mixin> with composite keys
                   for O(log n) priority ordering, insert, update, and pop-min."))

(defgeneric <priority-dict>? (obj)
  (:documentation "Returns T if OBJ is a FOL <priority-dict>."))

(defmethod <priority-dict>? ((obj <priority-dict>))
  (declare (ignore obj))
  t)

(defmethod <priority-dict>? (obj)
  (declare (ignore obj))
  nil)

(defmethod make ((class (eql '<priority-dict>)) &rest args)
  "Creates a new <priority-dict> from a flat sequence of alternating key-priority pairs.
   Optionally accepts a comparator function as the very first argument."

  ;; 1. Extract the optional comparator
  (let* ((cmp-fn (if (and args (functionp (first args)))
                     (pop args)
                     #'fol.compiler.compareops:%universal-comparator))
         (node-cmp (lambda (x y) (%priority-node-compare x y cmp-fn)))
         (seen (make-hash-table :test 'equal))
         (btree-args nil))

    ;; 2. Deduplicate for the B+ Tree (Keeping the LAST seen priority for each key)
    ;; By reversing the list, we encounter the 'last' elements first.
    ;; A sequence of (k v k v) reversed becomes (v k v k).
    (let ((rev-args (reverse args)))
      (loop for (priority key) on rev-args by #'cddr
            do (unless (gethash key seen)
                 (setf (gethash key seen) t)

                 ;; Build the B+ Tree args sequence. 
                 ;; Since we are pushing onto a list, we push the value ('t'), then the key.
                 (push t btree-args)
                 (push (cons priority key) btree-args))))

    ;; 3. Instantiate using the massive O(N) bulk loaders
    (make-instance '<priority-dict>
      ;; Load the HAMT (transient mutations instantly resolve duplicates)
      :dict-storage (fol.compiler.collection-primitives::hamt-bulk-load args)

      ;; Load the B+ Tree (bottom-up strict O(N) chunking)
      :sorted-dict-storage (fol.compiler.collection-primitives::btree-bulk-load btree-args node-cmp)

      :cmp-fn cmp-fn)))

(defun %priority-node-compare (a b cmp)
  "Compares two (priority . key) pairs. Sorts by priority first, then breaks ties using the key."
  (let ((c (funcall cmp (car a) (car b))))
    (if (zerop c)
        (fol.compiler.compareops:%universal-comparator (cdr a) (cdr b))
        c)))


;;; --- Protocol methods for <priority-dict> ---

(defmethod collection-size ((d <priority-dict>))
  (fol.compiler.collection-primitives::hamt-count (dict-storage d)))

(defmethod collection-ref ((d <priority-dict>) key &optional not-found)
  (fol.compiler.collection-primitives::hamt-get (dict-storage d) key not-found))

(defmethod collection-assoc ((d <priority-dict>) key priority)
  (let* ((hamt (dict-storage d))
         (btree (sorted-dict-storage d))
         (cmp (cmp-fn d))
         (node-cmp (lambda (x y) (%priority-node-compare x y cmp))))

    (multiple-value-bind (old-priority found-p)
        (fol.compiler.collection-primitives::hamt-get hamt key)

      (let ((new-btree btree))
        ;; 1. Remove the old (priority . key) from the B+ Tree if it exists
        (when found-p
              (multiple-value-bind (cleaned-root old-val removed-p)
                  (fol.compiler.collection-primitives::btree-dissoc-node
                   (fol.compiler.collection-primitives::btree-dict-root btree)
                   (cons old-priority key)
                   node-cmp)
                (declare (ignore old-val removed-p))
                (setf new-btree (fol.compiler.collection-primitives::%make-btree-dict
                                 :count (1- (fol.compiler.collection-primitives::btree-dict-count btree))
                                 :root cleaned-root))))

        ;; 2. Insert the new (priority . key) into the B+ Tree
        (multiple-value-bind (inserted-root split-key split-right old-val inserted-p)
            (fol.compiler.collection-primitives::btree-assoc-node
             (fol.compiler.collection-primitives::btree-dict-root new-btree)
             (cons priority key) t
             node-cmp)
          (declare (ignore old-val inserted-p))

          (let ((final-root (if split-key
                                (fol.compiler.collection-primitives::%make-btree-node
                                 (vector split-key) (vector inserted-root split-right))
                                inserted-root)))

            ;; 3. Return the updated persistent Priority Dict
            (make-instance '<priority-dict>
              :dict-storage (fol.compiler.collection-primitives::hamt-assoc hamt key priority)
              :sorted-dict-storage (fol.compiler.collection-primitives::%make-btree-dict
                                    :count (1+ (fol.compiler.collection-primitives::btree-dict-count new-btree))
                                    :root final-root)
              :cmp-fn cmp)))))))

(defmethod collection-dissoc ((d <priority-dict>) key)
  (let* ((hamt (dict-storage d))
         (btree (sorted-dict-storage d))
         (cmp (cmp-fn d))
         (node-cmp (lambda (x y) (%priority-node-compare x y cmp))))

    (multiple-value-bind (old-priority found-p)
        (fol.compiler.collection-primitives::hamt-get hamt key)

      (if (not found-p)
          d ; Key doesn't exist, return identically

          ;; Remove from B+ Tree and HAMT
          (multiple-value-bind (cleaned-root old-val removed-p)
              (fol.compiler.collection-primitives::btree-dissoc-node
               (fol.compiler.collection-primitives::btree-dict-root btree)
               (cons old-priority key)
               node-cmp)
            (declare (ignore old-val removed-p))

            (make-instance '<priority-dict>
              :dict-storage (fol.compiler.collection-primitives::hamt-dissoc hamt key)
              :sorted-dict-storage (fol.compiler.collection-primitives::%make-btree-dict
                                    :count (1- (fol.compiler.collection-primitives::btree-dict-count btree))
                                    :root cleaned-root)
              :cmp-fn cmp))))))

(defmethod collection-conj ((d <priority-dict>) element)
  ;; Allows passing a cons cell or a 2-element list/vector
  (let ((key (if (consp element) (car element) (collection-ref element 0)))
        (priority (if (consp element) (cdr element) (collection-ref element 1))))
    (collection-assoc d key priority)))

(defmethod collection-seq ((d <priority-dict>))
  "Return entries as (key . priority) pairs in priority order."
  (let ((btree (sorted-dict-storage d))
        (result nil))
    (let ((iter (fol.compiler.collection-primitives::btree-iterator
                 (fol.compiler.collection-primitives::btree-dict-root btree))))
      (loop
       (multiple-value-bind (p-k-cons dummy-val) (funcall iter)
         (declare (ignore dummy-val))
         (when (eq p-k-cons :eof) (return))
         (push (cons (cdr p-k-cons) (car p-k-cons)) result))))
    (nreverse result)))

(defmethod collection-lazy-seq ((d <priority-dict>))
  (seq d))

;;; ============================================================================
;;; Set
;;; ============================================================================

(defclass <set> (<unordered-collection> <dict-mixin> <collection-storage>)
    ()
  (:default-initargs :dict-storage (%make-hamt))
  (:documentation "A persistent unordered set backed by a HAMT."))

(defgeneric <set>? (obj)
  (:documentation "Returns T if OBJ is a FOL <set>."))

(defmethod <set>? ((obj <set>))
  (declare (ignore obj))
  t)

(defmethod <set>? (obj)
  (declare (ignore obj))
  nil)

(defmethod make ((class (eql '<set>)) &rest elements)
  (let ((s (make-instance class)))
    (dolist (e elements s)
      (setf s (fol.compiler.collection-primitives:assoc s e t)))))

;;; --- Protocol methods for <set> ---

(defmethod collection-assoc ((s <set>) key val)
  (declare (ignore val))
  (fol.compiler.collection-primitives:assoc s key t))

(defmethod collection-conj ((s <set>) element)
  "Add ELEMENT to the set."
  (fol.compiler.collection-primitives:assoc s element t))

(defmethod collection-seq ((s <set>))
  "Return elements of the set as a CL list."
  (let ((iter (fol.compiler.collection-primitives::hamt-iterator (dict-storage s)))
        (result nil))
    (loop for pair = (funcall iter)
          until (eq pair :eof)
          do (push (car pair) result))
    (nreverse result)))

(defmethod collection-size ((s <set>))
  (fol.compiler.collection-primitives:size s))

(defmethod collection-empty-p ((s <set>))
  (fol.compiler.collection-primitives:empty? s))

(defmethod collection-lazy-seq ((s <set>))
  "Return elements of the set as a lazy-seq (keys only)."
  (let ((iter (fol.compiler.collection-primitives::hamt-iterator (dict-storage s))))
    (labels ((build-seq ()
                        (let ((pair (funcall iter)))
                          (if (eq pair :eof)
                              nil
                              (lazy-cons (car pair) (build-seq))))))
      (build-seq))))

(defmethod collection-ref ((s <set>) key &optional not-found)
  (ref s key not-found))

;;; ============================================================================
;;; Ordered Set
;;; ============================================================================

(defclass <ordered-set> (<ordered-dict>)
    ()
  (:default-initargs :dict-storage (%make-hamt))
  (:documentation "A persistent ordered set that maintains insertion order.
                   Backed by a hand-coded HAMT (for O(1) membership) and
                   a hand-coded vector (for ordered iteration)."))

(defgeneric <ordered-set>? (obj)
  (:documentation "Returns T if OBJ is a FOL <ordered-set>."))

(defmethod <ordered-set>? ((obj <ordered-set>))
  (declare (ignore obj))
  t)

(defmethod <ordered-set>? (obj)
  (declare (ignore obj))
  nil)

;;; --- Protocol methods for <ordered-set> ---

;;; ============================================================================
;;; Sorted Set
;;; ============================================================================

(defclass <sorted-set> (<set> <ordered-collection> <sorted-dict-mixin> <universal-comparator-mixin> <collection-storage>)
    ()
  (:documentation "A persistent sorted set backed by a hand-coded HAMT.
                   Elements are maintained in the order defined by the comparator
                   function (inherited from <comparator>), which must return a
                   negative fixnum, zero, or positive fixnum for less-than,
                   equal, and greater-than respectively.
                   The comparator is stored in the compare slot and also used
                   to construct the Sycamore tree-set in storage-items."))

(defgeneric <sorted-set>? (obj)
  (:documentation "Returns T if OBJ is a FOL <sorted-set>."))

(defmethod <sorted-set>? ((obj <sorted-set>))
  (declare (ignore obj))
  t)

(defmethod <sorted-set>? (obj)
  (declare (ignore obj))
  nil)

(defmethod make ((class (eql '<sorted-set>)) &rest args)
  "Create a new <sorted-set>.
   First argument is a comparator function (or NIL for default numeric order).
   Remaining arguments are elements."
  (let* ((cmp (first args))
         (elements (rest args))
         (s (make-instance '<sorted-set> :cmp-fn (or cmp #'fol.compiler.compareops:%universal-comparator))))
    (dolist (e elements s)
      (setf s (collection-conj s e)))))

;;; ============================================================================
;;; Int Set
;;; ============================================================================

(defclass <int-set> (<set> <ordered-collection> <sorted-dict-mixin> <fast-fixnum-comparator-mixin> <collection-storage>)
    ()
  (:documentation "A persistent sorted set backed by a hand-coded HAMT.
                   Elements are maintained in the order defined by the comparator
                   function, which must return a
                   negative fixnum, zero, or positive fixnum for less-than,
                   equal, and greater-than respectively.
                   The comparator is stored in the compare slot and also used
                   to construct the Sycamore tree-set in storage-items."))

(defgeneric <int-set>? (obj)
  (:documentation "Returns T if OBJ is a FOL <int-set>."))

(defmethod <int-set>? ((obj <int-set>))
  (declare (ignore obj))
  t)

(defmethod <int-set>? (obj)
  (declare (ignore obj))
  nil)

;;; ============================================================================
;;; Dense Int Set
;;; ============================================================================

(defclass <dense-int-set> (<int-set>)
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


;;; ============================================================================
;;; Bag (Multiset)
;;; ============================================================================

(defclass <bag> (<unordered-collection> <dict-mixin> <collection-storage>) ()
  (:documentation "A persistent multiset (bag) backed by a hand-coded HAMT.
                   Keys are elements, values are occurrence counts."))

(defgeneric <bag>? (obj)
  (:documentation "Returns T if OBJ is a FOL <bag>."))

(defmethod <bag>? ((obj <bag>))
  (declare (ignore obj))
  t)

(defmethod <bag>? (obj)
  (declare (ignore obj))
  nil)

;;; --- Protocol methods for <bag> ---

(defmethod collection-seq ((b <bag>))
  "Return (element . count) pairs as a CL list."
  (let ((iter (fol.compiler.collection-primitives::hamt-iterator (dict-storage b)))
        (result nil))
    (loop for pair = (funcall iter)
          until (eq pair :eof)
          do (push pair result))
    (nreverse result)))

(defmethod collection-lazy-seq ((b <bag>))
  (seq b))

(defmethod collection-size ((b <bag>))
  "Total number of elements including multiplicities."
  (let ((total 0))
    (dolist (pair (collection-seq b) total)
      (incf total (cdr pair)))))

(defmethod collection-assoc ((b <bag>) key val)
  "Directly set the count of KEY to VAL."
  (fol.compiler.collection-primitives:assoc b key val))

(defmethod collection-conj ((b <bag>) element)
  "Add one occurrence of ELEMENT to the bag. (Clojure-style: element is the key)"
  (multiple-value-bind (v found) (ref b element)
    (fol.compiler.collection-primitives:assoc b element (if found (1+ v) 1))))

(defmethod collection-dissoc ((b <bag>) element)
  "Remove one occurrence of ELEMENT from the bag."
  (multiple-value-bind (v found) (ref b element)
    (cond ((not found) b)
          ((= v 1) (dissoc b element))
          (t (fol.compiler.collection-primitives:assoc b element (1- v))))))


;;; ============================================================================
;;; Deque
;;; ============================================================================

(defclass <deque> (<ordered-collection>)
    ((front :initarg :front :reader deque-front)
     (rear :initarg :rear :reader deque-rear))
  (:documentation "A purely functional Banker's Deque backed by two persistent vectors."))

(defgeneric <deque>? (obj))
(defmethod <deque>? (obj) (declare (ignore obj)) nil)
(defmethod <deque>? ((obj <deque>)) t)

(defmethod make ((class (eql '<deque>)) &rest args)
  (let* ((len (length args))
         (mid (ash len -1))
         ;; The front vector stores items backwards (index 0 is the center of the deque)
         (front-args (nreverse (subseq args 0 mid)))
         (rear-args (subseq args mid)))
    (make-instance '<deque>
      :front (make-instance '<vector>
               :storage (fol.compiler.collection-primitives::%build-vec-t-from-list front-args))
      :rear (make-instance '<vector>
              :storage (fol.compiler.collection-primitives::%build-vec-t-from-list rear-args)))))

(defmethod collection-size ((d <deque>))
  (+ (collection-size (deque-front d))
     (collection-size (deque-rear d))))

(defmethod collection-ref ((d <deque>) index &optional not-found)
  (let ((f-size (collection-size (deque-front d)))
        (r-size (collection-size (deque-rear d))))
    (if (or (< index 0) (>= index (+ f-size r-size)))
        (values not-found nil)
        (if (< index f-size)
            ;; Index falls in front vector (which is reversed in memory)
            (collection-ref (deque-front d) (- f-size 1 index) not-found)
            ;; Index falls in rear vector
            (collection-ref (deque-rear d) (- index f-size) not-found)))))

(defmethod collection-conj ((d <deque>) element)
  "Appends an element to the REAR of the deque."
  (make-instance '<deque>
    :front (deque-front d)
    :rear (collection-conj (deque-rear d) element)))

(defmethod conj-front ((d <deque>) element)
  "Appends an element to the FRONT of the deque."
  (make-instance '<deque>
    :front (collection-conj (deque-front d) element)
    :rear (deque-rear d)))

(defun %rebalance-deque (d)
  "Splits the elements evenly between front and rear to restore amortized O(1) bounds."
  (let* ((f-size (collection-size (deque-front d)))
         (r-size (collection-size (deque-rear d)))
         (total (+ f-size r-size)))

    (if (or (and (> f-size 0) (> r-size 0)) (< total 2))
        d ; Already balanced or too small to split
        (let ((lst nil))
          ;; Extract rear backwards, then front forwards to construct logical order
          (loop for i from (1- r-size) downto 0
                do (push (collection-ref (deque-rear d) i) lst))
          (loop for i from 0 below f-size
                do (push (collection-ref (deque-front d) i) lst))

          (let* ((mid (ash total -1))
                 (new-front-lst (nreverse (subseq lst 0 mid)))
                 (new-rear-lst (subseq lst mid)))
            (make-instance '<deque>
              :front (make-instance '<vector> :storage (fol.compiler.collection-primitives::%build-vec-t-from-list new-front-lst))
              :rear (make-instance '<vector> :storage (fol.compiler.collection-primitives::%build-vec-t-from-list new-rear-lst))))))))

(defmethod collection-pop-front ((d <deque>))
  (let* ((d-bal (if (zerop (collection-size (deque-front d))) (%rebalance-deque d) d))
         (front (deque-front d-bal))
         (rear (deque-rear d-bal)))
    (cond
     ((> (collection-size front) 0)
       (make-instance '<deque>
         :front (make-instance '<vector> :storage (fol.compiler.collection-primitives::%vec-t-pop (storage front)))
         :rear rear))
     ((> (collection-size rear) 0) ; Deque only had 1 item total
                                  (make '<deque>))
     (t d))))

(defmethod collection-pop ((d <deque>))
  "Pops from the REAR of the deque."
  (let* ((d-bal (if (zerop (collection-size (deque-rear d))) (%rebalance-deque d) d))
         (front (deque-front d-bal))
         (rear (deque-rear d-bal)))
    (cond
     ((> (collection-size rear) 0)
       (make-instance '<deque>
         :front front
         :rear (make-instance '<vector> :storage (fol.compiler.collection-primitives::%vec-t-pop (storage rear)))))
     ((> (collection-size front) 0) ; Deque only had 1 item total
                                   (make '<deque>))
     (t d))))

(defmethod collection-seq ((d <deque>))
  (let* ((front (deque-front d))
         (rear (deque-rear d))
         (f-idx (1- (collection-size front)))
         (r-idx 0)
         (result nil))
    ;; Front elements in reverse order (stack)
    (loop while (>= f-idx 0)
          do (push (collection-ref front f-idx) result)
            (decf f-idx))
    ;; Rear elements in order (queue)
    (loop while (< r-idx (collection-size rear))
          do (push (collection-ref rear r-idx) result)
            (incf r-idx))
    (nreverse result)))

(defmethod collection-lazy-seq ((d <deque>))
  (let* ((front (deque-front d))
         (rear (deque-rear d))
         (total (collection-size d))
         (f-idx (1- (collection-size front)))
         (r-idx 0))
    (labels ((generator ()
                        (cond
                         ((>= f-idx 0)
                           (let ((val (collection-ref front f-idx)))
                             (decf f-idx) val))
                         ((< r-idx (collection-size rear))
                           (let ((val (collection-ref rear r-idx)))
                             (incf r-idx) val))
                         (t :eof))))
      (labels ((build-lazy-chain (remaining)
                                 (if (<= remaining 0) nil
                                     (make-instance '<lazy-seq>
                                       :thunk (lambda ()
                                                (let ((val (generator)))
                                                  (if (eq val :eof) nil
                                                      (make-instance '<list>
                                                        :first-elem val
                                                        :rest-list (build-lazy-chain (1- remaining))
                                                        :list-size 1))))))))
        (build-lazy-chain total)))))

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
  (let ((result nil)
        (current l))
    (loop
     (when (null current) (return))
     (typecase current
       (<list>
        (when (zerop (list-size current)) (return))
        (push (list-first current) result)
        (setf current (list-rest current)))
       (<lazy-seq>
        (let ((realized (realize-lazy-seq current)))
          (if realized
              (setf current realized)
              (return))))
       (t (return))))
    (nreverse result)))

(defmethod collection-lazy-seq ((l <list>))
  "Return the <list> itself as a lazy sequence (it already is one)."
  l)

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

(defmethod collection-lazy-seq ((ls <lazy-seq>))
  "Return the lazy-seq itself."
  ls)

;;; ============================================================================
;;; print-object methods
;;; ============================================================================

(defun %write-fol-element (item stream)
  "Write a single FOL element to STREAM, respecting *print-escape*."
  (write item :stream stream))

(defmethod print-object ((obj <vector>) stream)
  (write-char #\[ stream)
  (let ((sz (fol.compiler.collection-primitives:size obj)))
    (dotimes (i sz)
      (unless (zerop i) (write-char #\Space stream))
      (%write-fol-element (ref obj i) stream)))
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
  (write-string "#M[" stream)
  (let ((first-p t))
    (dolist (pair (collection-seq obj))
      (dotimes (i (cdr pair))
        (if first-p
            (setf first-p nil)
            (write-char #\Space stream))
        (%write-fol-element (car pair) stream))))
  (write-char #\] stream))

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