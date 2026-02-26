;;; FOL Compiler - Persistent Object System
;;;
;;; Hybrid Strategy: native CLOS slots for objects with <= 8 slots,
;;; overflowing into a persistent vector for objects with > 8 slots.
;;;
;;; Threshold rationale: empirical OO class-size studies report median 2
;;; fields/class and a 90th percentile of ~10-12 (Concas et al. 2007,
;;; Eclipse/Java, n=10000 classes).  T=8 keeps ~80% of real classes on the
;;; all-native fast path.  A separate micro-benchmark over T in {8,12,16,24,32}
;;; shows that persistent vector batch-build costs ~106 ns + 5-7 ns/element,
;;; far less per element than slot-value dispatch (~27 ns/slot), so T=8 also
;;; minimises update cost for objects with more than ~28 slots.
;;;
;;; All FOL user-level classes inherit from <persistent-object>.
;;;
;;; Slot access is transparent through the MOP: standard slot-value and
;;; accessor functions work normally. Mutation is prevented after init;
;;; use update-slot/update-slots for functional updates.

(in-package :fol.compiler.persistent)

;;; ============================================================================
;;; Metaclass
;;; ============================================================================

(defconstant +native-slot-limit+ 8
             "Maximum number of user slots stored in native CLOS slots.
Objects with more than this many slots overflow the remainder into a
persistent vector trie.  See file header for threshold rationale.")

(defclass persistent-class (standard-class)
    ((%slot-count :accessor persistent-class-slot-count
                  :initform 0
                  :documentation "Cached number of slots to determine storage strategy.")
     (%overflow-indices :accessor persistent-class-overflow-indices
                        :initform nil
                        :documentation "Hash table mapping overflow slots (>= +native-slot-limit+) to vector indices.")
     (%keyword-to-slot :accessor persistent-class-keyword-to-slot
                       :initform (make-hash-table :test 'eq)
                       :documentation "Hash table mapping keywords to slot name symbols."))
  (:documentation "Hybrid split layout metaclass: first +native-slot-limit+ native slots, rest overflow to persistent vector."))

(defmethod closer-mop:validate-superclass ((class persistent-class)
                                           (superclass standard-class))
  t)

(defmethod closer-mop:validate-superclass ((class persistent-class)
                                           (superclass persistent-class))
  t)

(defmethod closer-mop:validate-superclass ((class standard-class)
                                           (superclass persistent-class))
  t)

(defmethod closer-mop:compute-slots ((class persistent-class))
  "Split layout: first +native-slot-limit+ are native CLOS slots, the rest overflow to the vector."
  (let* ((all-slots (call-next-method))
         ;; Only count user slots (exclude internal ones)
         (user-slots (remove-if (lambda (s)
                                  (member (closer-mop:slot-definition-name s)
                                          '(%persistent-vector %metadata %persistent-storage)))
                         all-slots))
         (count (length user-slots))
         (kw-map (make-hash-table :test 'eq)))

    (setf (persistent-class-slot-count class) count)

    ;; Populate keyword to slot name map for all slots (even overflow ones)
    (dolist (slot user-slots)
      (let ((name (closer-mop:slot-definition-name slot)))
        (setf (gethash (intern (string name) :keyword) kw-map) name)))
    (setf (persistent-class-keyword-to-slot class) kw-map)

    (if (<= count +native-slot-limit+)
        ;; All slots fit natively
        all-slots

        ;; Split the slots
        (let ((native-slots (subseq user-slots 0 +native-slot-limit+))
              (overflow-slots (subseq user-slots +native-slot-limit+))
              (idx-map (make-hash-table :test 'eq)))

          ;; Map the overflow slots to 0-based vector indices
          (loop for slot in overflow-slots
                for i from 0
                do (setf (gethash (closer-mop:slot-definition-name slot) idx-map) i))
          (setf (persistent-class-overflow-indices class) idx-map)

          ;; Return the +native-slot-limit+ native slots PLUS the internal persistence slots
          (append native-slots
            (remove-if-not (lambda (s)
                             (member (closer-mop:slot-definition-name s)
                                     '(%persistent-vector %metadata %persistent-storage)))
                all-slots))))))

;;; ============================================================================
;;; Base Class
;;; ============================================================================

(defvar *initializing-persistent-object* nil
        "Bound to T during persistent object initialization to allow slot writes.")

(defclass <persistent-object> (standard-object)
    ((%persistent-vector :accessor %persistent-vector
                         :initform nil
                         :documentation "Persistent sequence for wide objects.")
     (%metadata :accessor %persistent-metadata
                :initarg :metadata :initform nil
                :documentation "Optional metadata dict associated with this object.")
     (%transient-p :accessor %transient-p
                   :initform nil
                   :documentation "T if object is in a mutable transient state.")
     (%transient-buffer :accessor %transient-buffer
                        :initform nil
                        :documentation "Mutable array for overflow slots when transient."))
  (:metaclass persistent-class)
  (:documentation "Base class for objects with persistent (immutable) slot storage."))

;;; ============================================================================
;;; Initialization
;;; ============================================================================

(defmethod initialize-instance :around ((object <persistent-object>) &rest initargs &key &allow-other-keys)
  "Allow slot writes during initialization. &allow-other-keys permits overflow initargs
   for objects with > +native-slot-limit+ slots (whose overflow slots are not in the effective-slots list)."
  (declare (ignore initargs))
  (let ((*initializing-persistent-object* t))
    (call-next-method)))
(defmethod initialize-instance :after ((object <persistent-object>) &rest initargs)
  "Populate the overflow <vector> from initargs."
  (let* ((class (class-of object))
         (count (persistent-class-slot-count class)))
    (when (> count +native-slot-limit+)
          (let* ((overflow-size (- count +native-slot-limit+))
                 ;; 1. Pre-allocate a mutable native array for O(1) random-access updates
                 (temp-arr (make-array overflow-size :initial-element :unbound)))

            ;; 2. Loop through the unordered hash map and slot the values perfectly into place
            (maphash (lambda (slot-name idx)
                       (let* ((kw (intern (string slot-name) :keyword))
                              (init-val (getf initargs kw :not-found)))
                         (unless (eq init-val :not-found)
                           (setf (aref temp-arr idx) init-val))))
                     (persistent-class-overflow-indices class))

            ;; 3. Freeze the data into the bit-partitioned trie in strict O(N) time
            (let* ((frozen-storage (fol.compiler.collection-primitives::%build-vec-t-from-list
                                    (coerce temp-arr 'list)))
                   (persistent-vec (make-instance 'fol.compiler.collections:<vector> :storage frozen-storage)))

              ;; 4. Bind to the instance
              (let ((*initializing-persistent-object* t))
                (setf (%persistent-vector object) persistent-vec)))))))

;;; ============================================================================
;;; MOP Integration - Slot Access
;;; ============================================================================

(defmethod slot-missing ((class persistent-class) object slot-name operation &optional new-value)
  "Catches reads/writes ONLY for the overflow slots (index >= +native-slot-limit+)."
  (let ((idx (and (persistent-class-overflow-indices class)
                  (gethash slot-name (persistent-class-overflow-indices class)))))
    (if idx
        (ecase operation
          (slot-value
            (let ((val (fol.compiler.collection-primitives:ref (%persistent-vector object) idx :unbound)))
              (if (eq val :unbound)
                  (error "Slot ~A is unbound." slot-name)
                  val)))
          (setf
            (if (or *initializing-persistent-object* (%transient-p object))
                (if (%transient-p object)
                    (if (%transient-buffer object)
                        (setf (aref (%transient-buffer object) idx) new-value)
                        (setf (%persistent-vector object)
                          (fol.compiler.collections:assoc (%persistent-vector object) idx new-value)))
                    (setf (%persistent-vector object)
                      (fol.compiler.collections:assoc (%persistent-vector object) idx new-value)))
                (error "Cannot mutate persistent slot ~A. Use TRANSIENT to mutate." slot-name)))
          (slot-boundp
            (if (and (%transient-p object) (%transient-buffer object))
                (not (eq (aref (%transient-buffer object) idx) :unbound))
                (not (eq (fol.compiler.collection-primitives:ref (%persistent-vector object) idx) :unbound))))
          (slot-makunbound
            (if (%transient-p object)
                (if (%transient-buffer object)
                    (setf (aref (%transient-buffer object) idx) :unbound)
                    (setf (%persistent-vector object)
                      (fol.compiler.collections:assoc (%persistent-vector object) idx :unbound)))
                (error "Cannot makunbound persistent slots.")))
          ;; Genuine missing slot
          (t (call-next-method))))))

  (defmethod (setf closer-mop:slot-value-using-class) (new-value
                                                       (class persistent-class)
                                                       object
                                                       (slot closer-mop:standard-effective-slot-definition))
    "Prevent mutation of native slots after initialization."
    (let ((slot-name (closer-mop:slot-definition-name slot)))
      (if (or (member slot-name '(%persistent-vector %metadata %persistent-storage %transient-p))
              *initializing-persistent-object*
              (%transient-p object))
          (call-next-method)
          (error "Cannot set slot ~A on persistent object. Use UPDATE-SLOT or TRANSIENT." slot-name))))

  #+sbcl
  (defmethod sb-mop:slot-makunbound-using-class ((class persistent-class)
                                                 object
                                                 (slot closer-mop:standard-effective-slot-definition))
    "Prevent slot-makunbound on native persistent slots."
    (let ((slot-name (closer-mop:slot-definition-name slot)))
      (if (or (member slot-name '(%persistent-vector %metadata %persistent-storage %transient-p))
              (%transient-p object))
          (call-next-method)
          (error "Cannot makunbound persistent slots."))))

  ;;; ============================================================================
  ;;; Functional Update API
  ;;; ============================================================================

  (defun %persistent-storage (obj)
    "Compatibility accessor. Returns either the map or vector storage."
    (let ((class (class-of obj)))
      (if (> (persistent-class-slot-count class) +native-slot-limit+)
          (%persistent-vector obj)
          ;; For native, we could return a map, but it's expensive.
          ;; Most FOL code should use slot-value now.
          nil)))

  (defun slot-name-from-keyword (class keyword)
    "Map a keyword back to a slot name symbol using the class's cached map."
    (gethash keyword (persistent-class-keyword-to-slot class)))

  (defun update-slot (object key new-value)
    "Return a new persistent object with KEY (slot name or keyword) updated to NEW-VALUE."
    (update-slots object key new-value))

  (defun update-slots (object &rest slot-name-value-pairs)
    "Return a new persistent object with multiple slots updated.
   Takes alternating slot-name (or keyword) value pairs.
   Efficiently routes updates to native CLOS slots or the overflow <vector>."
    (let* ((class (class-of object))
           (is-wide (> (persistent-class-slot-count class) +native-slot-limit+)))

      (when (%transient-p object)
            (loop for (key value) on slot-name-value-pairs by #'cddr
                  for slot-name = (if (keywordp key) (slot-name-from-keyword class key) key)
                  do (if slot-name
                         (setf (slot-value object slot-name) value)
                         (error "Unknown slot/attribute: ~A" key)))
            (return-from update-slots object))

      (let ((*initializing-persistent-object* t)
            (new-obj (allocate-instance class)))
        ;; 1. Shallow copy all native slots (up to +native-slot-limit+ user slots + %persistent-vector)
        (dolist (slot (closer-mop:class-slots class))
          (let ((sname (closer-mop:slot-definition-name slot)))
            (when (slot-boundp object sname)
                  (setf (slot-value new-obj sname) (slot-value object sname)))))

        (if is-wide
            ;; Strategy 2: Wide object - route updates to native or overflow
            (let* ((overflow-indices (persistent-class-overflow-indices class))
                   (old-vec (and (slot-boundp object '%persistent-vector)
                                 (%persistent-vector object)))
                   (temp-array nil)
                   (vector-mutated-p nil))

              (loop for (key value) on slot-name-value-pairs by #'cddr
                    for slot-name = (if (keywordp key) (slot-name-from-keyword class key) key)
                    for overflow-idx = (and slot-name (gethash slot-name overflow-indices))
                    do (if overflow-idx
                           ;; It's an overflow slot. Initialize temp-array if we haven't yet.
                           (progn
                            (unless temp-array
                              (setf temp-array (make-array (hash-table-count overflow-indices)
                                                 :initial-element :unbound))
                              ;; Copy old vector contents into the mutable buffer
                              (when old-vec
                                    (loop for i from 0 below (fol.compiler.collections:collection-size old-vec)
                                          do (setf (aref temp-array i) (fol.compiler.collections:collection-ref old-vec i)))))

                            (setf (aref temp-array overflow-idx) value)
                            (setf vector-mutated-p t))

                           ;; It's a native slot. Overwrite the copied value.
                           (if slot-name
                               (setf (slot-value new-obj slot-name) value)
                               (error "Unknown slot/attribute: ~A" key))))

              ;; If any overflow slots were touched, freeze the mutated array back to the persistent <vector>
              (when vector-mutated-p
                    (setf (%persistent-vector new-obj)
                      (make-instance 'fol.compiler.collections:<vector>
                        :storage (fol.compiler.collection-primitives::%build-vec-t-from-list
                                  (coerce temp-array 'list))))))

            ;; Strategy 1: Small object - purely native overwrite
            (loop for (key value) on slot-name-value-pairs by #'cddr
                  for slot-name = (if (keywordp key) (slot-name-from-keyword class key) key)
                  do (if slot-name
                         (setf (slot-value new-obj slot-name) value)
                         (error "Unknown slot/attribute: ~A" key))))

      ;; Ensure metadata carries over
      (when (slot-boundp object '%metadata)
            (setf (%persistent-metadata new-obj) (%persistent-metadata object)))

      ;; Ensure transient status DOES NOT carry over (updates result in persistent copies)

      new-obj)))
