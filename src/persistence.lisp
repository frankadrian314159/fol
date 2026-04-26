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

(defclass persistent-direct-slot-definition (closer-mop:standard-direct-slot-definition)
    ((alias :initarg :alias :initform nil :accessor slot-definition-alias)))

(defclass persistent-effective-slot-definition (closer-mop:standard-effective-slot-definition)
    ((alias :initarg :alias :initform nil :accessor slot-definition-alias)))

;;; ============================================================================
;;; Schema Version Chain
;;; ============================================================================

;;; Each class-version snapshot records the alias-map and overflow layout that
;;; were in effect FOR a given version, captured just before the transition to
;;; the next version.  The chain is singly-linked, newest first.
(defstruct (class-version (:constructor make-class-version (version-id alias-map overflow-indices prev)))
  (version-id 0 :type fixnum :read-only t)
  (alias-map nil :read-only t)
  (overflow-indices nil :read-only t)
  (prev nil :read-only t))

(defclass persistent-class (standard-class)
    ((%slot-count :accessor persistent-class-slot-count
                  :initform 0
                  :documentation "Cached number of slots to determine storage strategy.")
     (%overflow-indices :accessor persistent-class-overflow-indices
                        :initform nil
                        :documentation "Hash table mapping overflow slots (>= +native-slot-limit+) to vector indices.")
     (%keyword-to-slot :accessor persistent-class-keyword-to-slot
                       :initform (make-hash-table :test 'eq)
                       :documentation "Hash table mapping keywords to slot name symbols.")
     (%slot-aliases :accessor persistent-class-slot-aliases
                    :initform (make-hash-table :test 'eq)
                    :documentation "Maps slot name symbols to their old-name aliases.")
     (%version-counter :accessor persistent-class-version-counter
                       :initform 0
                       :documentation "Monotonically increasing version counter; incremented on each defclass redefinition.")
     (%version-chain :accessor persistent-class-version-chain
                     :initform nil
                     :documentation "Singly-linked list of class-version snapshots, newest first."))
  (:documentation "Hybrid split layout metaclass with slot aliasing support and schema-version chain."))

(defmethod closer-mop:direct-slot-definition-class ((class persistent-class) &rest initargs)
  (declare (ignore initargs))
  (find-class 'persistent-direct-slot-definition))

(defmethod closer-mop:effective-slot-definition-class ((class persistent-class) &rest initargs)
  (declare (ignore initargs))
  (find-class 'persistent-effective-slot-definition))

(defmethod closer-mop:compute-effective-slot-definition ((class persistent-class) name direct-slots)
  (let ((effective-slot (call-next-method)))
    (setf (slot-definition-alias effective-slot)
      (some #'slot-definition-alias direct-slots))
    effective-slot))

(defmethod closer-mop:validate-superclass ((class persistent-class)
                                           (superclass standard-class))
  t)

(defmethod closer-mop:validate-superclass ((class persistent-class)
                                           (superclass persistent-class))
  t)

(defmethod closer-mop:validate-superclass ((class standard-class)
                                           (superclass persistent-class))
  t)

;;; Snapshot the current schema state just before each redefinition.
;;; This preserves the single-hop alias-map and overflow-indices that describe
;;; the transition FROM this version to the next, enabling multi-hop chain replay.
(defmethod reinitialize-instance :before ((class persistent-class) &rest initargs)
  (declare (ignore initargs))
  (when (closer-mop:class-finalized-p class)
        (let ((snapshot (make-class-version
                         (persistent-class-version-counter class)
                         (persistent-class-slot-aliases class)
                         (persistent-class-overflow-indices class)
                         (persistent-class-version-chain class))))
          (setf (persistent-class-version-chain class) snapshot)
          (incf (persistent-class-version-counter class)))))

(defmethod closer-mop:compute-slots ((class persistent-class))
  "Split layout: first +native-slot-limit+ are native CLOS slots, the rest overflow to the vector."
  (let* ((all-slots (call-next-method))
         ;; Only count user slots (exclude internal ones)
         (user-slots (remove-if (lambda (s)
                                  (member (closer-mop:slot-definition-name s)
                                          '(%persistent-vector %metadata %persistent-storage
                                                               %schema-version)))
                         all-slots))
         (count (length user-slots))
         (kw-map (make-hash-table :test 'eq)))

    (setf (persistent-class-slot-count class) count)

    ;; Populate keyword to slot name map and alias map
    (let ((alias-map (make-hash-table :test 'eq)))
      (dolist (slot user-slots)
        (let ((name (closer-mop:slot-definition-name slot))
              (alias (slot-definition-alias slot)))
          (setf (gethash (intern (string name) :keyword) kw-map) name)
          (when alias
                (setf (gethash name alias-map) alias)
                ;; Also map the alias keyword to this slot if not already mapped
                (let ((alias-kw (intern (string alias) :keyword)))
                  (unless (gethash alias-kw kw-map)
                    (setf (gethash alias-kw kw-map) name))))))
      (setf (persistent-class-slot-aliases class) alias-map))
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
                                     '(%persistent-vector %metadata %persistent-storage
                                                          %schema-version)))
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
     (%transient-owner :accessor %transient-owner
                       :initform nil
                       :documentation "Thread that owns this transient object, or NIL if persistent.")
     (%transient-buffer :accessor %transient-buffer
                        :initform nil
                        :documentation "Mutable array for overflow slots when transient.")
     (%schema-version :accessor %schema-version
                      :initform 0
                      :documentation "Version counter at the time this instance was created or last migrated.
Used to locate the correct starting point in the class version chain during multi-hop schema migration."))
  (:metaclass persistent-class)
  (:documentation "Base class for objects with persistent (immutable) slot storage."))

;;; ============================================================================
;;; Initialization
;;; ============================================================================

(defmethod initialize-instance :around ((object <persistent-object>) &rest initargs &key &allow-other-keys)
  "Allow slot writes during initialization and handle slot aliasing in initargs."
  (let* ((class (class-of object))
         (aliases (persistent-class-slot-aliases class)))
    (if (zerop (hash-table-count aliases))
        ;; Fast path: no aliases — skip copy-list/maphash/apply
        (let ((*initializing-persistent-object* t))
          (call-next-method))
        ;; Slow path: resolve alias initargs before passing to next method
        (let ((new-initargs (copy-list initargs)))
          (maphash (lambda (sname alias)
                     (let* ((kw (intern (string sname) :keyword))
                            (alias-name (if (symbolp alias) (string alias) alias))
                            (alias-kw (intern (string alias-name) :keyword)))
                       (when (and (eq (getf new-initargs kw :not-found) :not-found)
                                  (not (eq (getf new-initargs alias-kw :not-found) :not-found)))
                             (setf (getf new-initargs kw) (getf new-initargs alias-kw)))))
                   aliases)
          (let ((*initializing-persistent-object* t))
            (apply #'call-next-method object new-initargs))))))

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
                              (alias (gethash slot-name (persistent-class-slot-aliases class)))
                              (alias-kw (and alias (intern (string alias) :keyword)))
                              (init-val (getf initargs kw :not-found)))
                         ;; If not found under the primary name, check the alias
                         (when (and (eq init-val :not-found) alias-kw)
                               (setf init-val (getf initargs alias-kw :not-found)))
                         (unless (eq init-val :not-found)
                           (setf (aref temp-arr idx) init-val))))
                     (persistent-class-overflow-indices class))

            ;; 3. Freeze the data into the bit-partitioned trie in strict O(N) time
            (let* ((frozen-storage (fol.compiler.collection-primitives::%build-vec-t-from-vector temp-arr))
                   (persistent-vec (make-instance 'fol.compiler.collections:<vector> :storage frozen-storage)))

              ;; 4. Bind to the instance
              (let ((*initializing-persistent-object* t))
                (setf (%persistent-vector object) persistent-vec)))))
    ;; Record the schema version at birth so multi-hop migration can locate
    ;; the correct starting point in the class version chain.
    (let ((*initializing-persistent-object* t))
      (setf (%schema-version object) (persistent-class-version-counter (class-of object))))))

;;; When a class is redefined, SBCL's default update-instance-for-redefined-class
;;; migrates only slots that are native in BOTH the old and the new schema.  Slots
;;; that were native in the old schema but are absent (removed) or have moved into
;;; the overflow zone in the new schema are "discarded"; their values arrive in
;;; property-list keyed by the OLD slot name.
;;;
;;; Single-hop case: a :alias annotation on the new schema names the old slot —
;;; we look up the old name directly in property-list.
;;;
;;; Multi-hop case: an instance may have been born at version N and never touched
;;; while the class was redefined at version N+1, N+2, …, M.  SBCL performs a
;;; single migration from the N layout to the current M layout; the chain of
;;; intermediate renames is invisible in the property-list (which only contains
;;; the N-era slot names).  We recover the full rename chain by composing the
;;; single-hop alias maps stored in the version snapshots, producing a transitive
;;; map from current slot names back to the birth-version slot names.
(defmethod cl:update-instance-for-redefined-class
  :after ((instance <persistent-object>)
          added-slots discarded-slots property-list
          &rest initargs)
  "Multi-hop alias recovery: replay the version chain to find birth-version slot names,
   then recover values from property-list and populate native/overflow targets."
  (declare (ignore initargs added-slots discarded-slots))
  (let* ((class (class-of instance))
         (overflow-indices (persistent-class-overflow-indices class))
         (birth-version (%schema-version instance))
         (*initializing-persistent-object* t))

    ;; -----------------------------------------------------------------------
    ;; Build composed alias map: current-slot-name -> birth-version-slot-name
    ;; by walking the version chain from newest snapshot back to birth-version.
    ;; -----------------------------------------------------------------------
    (let ((composed (make-hash-table :test 'eq)))

      ;; Seed from the current defclass alias-map (single-hop: current → previous)
      (maphash (lambda (sname alias)
                 (setf (gethash sname composed) alias))
               (persistent-class-slot-aliases class))

      ;; Extend through each intermediate snapshot that is NEWER than birth-version.
      ;; Each snapshot records the alias-map that was active IN that version, i.e.
      ;; the renames that moved from (version-id - 1) → version-id.
      (loop for snap = (persistent-class-version-chain class) then (class-version-prev snap)
            while (and snap (> (class-version-version-id snap) birth-version))
            do (let ((snap-aliases (class-version-alias-map snap)))
                 (maphash (lambda (sname intermediate)
                            ;; If 'intermediate' was itself a rename of something older,
                            ;; chase the chain one more step.
                            (let ((deeper (gethash intermediate snap-aliases)))
                              (when deeper
                                    (setf (gethash sname composed) deeper))))
                          composed)))

      ;; -----------------------------------------------------------------------
      ;; Use the composed map to recover values from property-list.
      ;; -----------------------------------------------------------------------
      (when (and property-list (> (hash-table-count composed) 0))
            (let (native-assignments overflow-assignments)

              (maphash
                (lambda (sname orig-name)
                  (let ((old-val (getf property-list orig-name :not-found)))
                    (unless (eq old-val :not-found)
                      (if (and overflow-indices (gethash sname overflow-indices))
                          (push (cons sname old-val) overflow-assignments)
                          ;; Native: only assign if still unbound (initform may have run)
                          (unless (slot-boundp instance sname)
                            (push (cons sname old-val) native-assignments))))))
                composed)

              ;; Apply native recoveries
              (dolist (pair native-assignments)
                (setf (slot-value instance (car pair)) (cdr pair)))

              ;; Apply overflow recoveries, rebuilding the persistent vector
              (when overflow-assignments
                    (let* ((size (hash-table-count overflow-indices))
                           (temp-arr (make-array size :initial-element :unbound)))
                      ;; Preserve existing overflow values (may be nil for a schema-1 instance)
                      (when (%persistent-vector instance)
                            (maphash (lambda (sname idx)
                                       (declare (ignore sname))
                                       (let ((val (fol.compiler.collection-primitives:ref
                                                   (%persistent-vector instance) idx :not-found)))
                                         (unless (eq val :not-found)
                                           (setf (aref temp-arr idx) val))))
                                     overflow-indices))
                      ;; Overlay alias-recovered values
                      (dolist (pair overflow-assignments)
                        (setf (aref temp-arr (gethash (car pair) overflow-indices)) (cdr pair)))
                      ;; Freeze into the trie
                      (setf (%persistent-vector instance)
                        (make-instance 'fol.compiler.collections:<vector>
                          :storage (fol.compiler.collection-primitives::%build-vec-t-from-vector temp-arr))))))))

    ;; Stamp the migrated instance with the current version so any further
    ;; redefinitions start from the correct point in the chain.
    (setf (%schema-version instance) (persistent-class-version-counter class))))

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
            (if (null (%persistent-vector object))
                (error "Slot ~A is unbound." slot-name)
                (let ((val (fol.compiler.collection-primitives:ref (%persistent-vector object) idx :unbound)))
                  (if (eq val :unbound)
                      (error "Slot ~A is unbound." slot-name)
                      val))))
          (setf
            (if (or *initializing-persistent-object* (eq (%transient-owner object) (bt:current-thread)))
                (if (%transient-owner object)
                    (if (%transient-buffer object)
                        (setf (aref (%transient-buffer object) idx) new-value)
                        (setf (%persistent-vector object)
                          (fol.compiler.collections:assoc (%persistent-vector object) idx new-value)))
                    (setf (%persistent-vector object)
                      (fol.compiler.collections:assoc (%persistent-vector object) idx new-value)))
                (error "Cannot mutate persistent slot ~A. Use TRANSIENT to mutate." slot-name)))
          (slot-boundp
            (cond
             ((and (%transient-p object) (%transient-buffer object))
               (not (eq (aref (%transient-buffer object) idx) :unbound)))
             ((null (%persistent-vector object))
               nil)
             (t
               (not (eq (fol.compiler.collection-primitives:ref (%persistent-vector object) idx) :unbound)))))
          (slot-makunbound
            (if (eq (%transient-owner object) (bt:current-thread))
                (if (%transient-buffer object)
                    (setf (aref (%transient-buffer object) idx) :unbound)
                    (setf (%persistent-vector object)
                      (fol.compiler.collections:assoc (%persistent-vector object) idx :unbound)))
                (error "Cannot makunbound persistent slots.")))
          ;; Genuine missing slot
          (t (call-next-method))))))

(defun %transient-p (object)
  "Return T if the object is transient (has a thread owner)."
  (not (null (%transient-owner object))))

(defmethod (setf closer-mop:slot-value-using-class) (new-value
                                                     (class persistent-class)
                                                     object
                                                     (slot closer-mop:standard-effective-slot-definition))
  "Prevent mutation of native slots after initialization."
  (let ((slot-name (closer-mop:slot-definition-name slot)))
    (if (or (member slot-name '(%persistent-vector %metadata %persistent-storage %transient-owner %transient-buffer %schema-version))
            *initializing-persistent-object*
            (eq (%transient-owner object) (bt:current-thread)))
        (call-next-method)
        (if (%transient-owner object)
            (error "Cannot mutate transient object from different thread.")
            (error "Cannot set slot ~A on persistent object. Use UPDATE-SLOT or TRANSIENT." slot-name)))))

#+sbcl
(defmethod sb-mop:slot-makunbound-using-class ((class persistent-class)
                                               object
                                               (slot closer-mop:standard-effective-slot-definition))
  "Prevent slot-makunbound on native persistent slots."
  (let ((slot-name (closer-mop:slot-definition-name slot)))
    (if (or (member slot-name '(%persistent-vector %metadata %persistent-storage %transient-owner %transient-buffer %schema-version))
            (eq (%transient-owner object) (bt:current-thread)))
        (call-next-method)
        (error "Cannot makunbound persistent slots."))))

;;; ============================================================================
;;; Fast Construction (bypass initialize-instance MOP overhead)
;;; ============================================================================

(defun %make-persistent (class &rest initargs)
  "Construct a persistent instance bypassing initialize-instance.
   Avoids the MOP slot-iteration overhead of standard initialize-instance
   (~550 ns/call on SBCL) for the common case of no-alias non-overflow classes.
   CLASS must be a persistent-class instance (use load-time-value (find-class ...) at call site)."
  (let ((obj (allocate-instance class)))
    (let ((*initializing-persistent-object* t))
      (loop for (key val) on initargs by #'cddr
            for slot-name = (slot-name-from-keyword class key)
            when slot-name
              do (setf (slot-value obj slot-name) val))
      (setf (%schema-version obj) (persistent-class-version-counter class)))
    obj))

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

    (when (eq (%transient-owner object) (bt:current-thread))
          (loop for (key value) on slot-name-value-pairs by #'cddr
                for slot-name = (if (keywordp key) (slot-name-from-keyword class key) key)
                do (if slot-name
                       (setf (slot-value object slot-name) value)
                       (error "Unknown slot/attribute: ~A" key)))
          (return-from update-slots object))

    (let ((*initializing-persistent-object* t)
          (new-obj (allocate-instance class)))
      (setf (%transient-owner new-obj) nil)
      (setf (%transient-buffer new-obj) nil)
      (setf (%schema-version new-obj) (persistent-class-version-counter class))
      (dolist (slot (closer-mop:class-slots class))
        (let* ((sname (closer-mop:slot-definition-name slot))
               (alias (gethash sname (persistent-class-slot-aliases class))))
          (unless (member sname '(%persistent-vector %metadata %persistent-storage %transient-owner %transient-buffer %schema-version))
            (cond ((slot-boundp object sname)
                    (setf (slot-value new-obj sname) (slot-value object sname)))
                  ((and alias (slot-boundp object alias))
                    (setf (slot-value new-obj sname) (slot-value object alias)))))))

      (if is-wide
          (let* ((overflow-indices (persistent-class-overflow-indices class))
                 (any-overflow (some (lambda (k) (gethash (if (keywordp k) (slot-name-from-keyword class k) k) overflow-indices))
                                     (loop for (key val) on slot-name-value-pairs by #'cddr collect key)))
                 (vector-mutated-p nil))
            (if any-overflow
                (let ((tv (when (%persistent-vector object)
                            (fol.compiler.collections:transient (%persistent-vector object)))))
                  (unless tv
                    (let ((size (hash-table-count overflow-indices)))
                      (setf tv (fol.compiler.collections::%make-transient-vector 
                                (make-array size :initial-element :unbound :adjustable t :fill-pointer t)))))
                  (loop for (key value) on slot-name-value-pairs by #'cddr
                        for slot-name = (if (keywordp key) (slot-name-from-keyword class key) key)
                        for overflow-idx = (and slot-name (gethash slot-name overflow-indices))
                        do (if overflow-idx
                               (progn
                                 (fol.compiler.collections:assoc! tv overflow-idx value)
                                 (setf vector-mutated-p t))
                               (if slot-name
                                   (setf (slot-value new-obj slot-name) value)
                                   (error "Unknown slot/attribute: ~A" key))))
                  (setf (%persistent-vector new-obj)
                    (if vector-mutated-p
                        (fol.compiler.collections:persistent! tv)
                        (%persistent-vector object))))
                ;; Native-only update: just copy the existing vector
                (progn
                  (setf (%persistent-vector new-obj) (%persistent-vector object))
                  (loop for (key value) on slot-name-value-pairs by #'cddr
                        for slot-name = (if (keywordp key) (slot-name-from-keyword class key) key)
                        do (if slot-name
                               (setf (slot-value new-obj slot-name) value)
                               (error "Unknown slot/attribute: ~A" key))))))
          (loop for (key value) on slot-name-value-pairs by #'cddr
                for slot-name = (if (keywordp key) (slot-name-from-keyword class key) key)
                do (if slot-name
                       (setf (slot-value new-obj slot-name) value)
                       (error "Unknown slot/attribute: ~A" key))))

      (when (slot-boundp object '%metadata)
            (setf (%persistent-metadata new-obj) (%persistent-metadata object)))

      new-obj)))

(defun dissoc-slots (object &rest keys)
  "Return a new persistent object with the specified slots removed (unbound).
   Works for both native and overflow slots."
  (let* ((class (class-of object))
         (is-wide (> (persistent-class-slot-count class) +native-slot-limit+))
         (keys-to-remove (loop for k in keys
                               collect (if (keywordp k)
                                           (slot-name-from-keyword class k)
                                           k))))
    (let ((*initializing-persistent-object* t)
          (new-obj (allocate-instance class)))
      (setf (%transient-owner new-obj) nil)
      (setf (%transient-buffer new-obj) nil)
      (setf (%schema-version new-obj) (persistent-class-version-counter class))
      (dolist (slot (closer-mop:class-slots class))
        (let* ((sname (closer-mop:slot-definition-name slot))
               (alias (gethash sname (persistent-class-slot-aliases class))))
          (unless (member sname '(%persistent-vector %metadata %persistent-storage %transient-owner %transient-buffer %schema-version))
            (unless (or (member sname keys-to-remove)
                        (and alias (member alias keys-to-remove)))
              (cond ((slot-boundp object sname)
                      (setf (slot-value new-obj sname) (slot-value object sname)))
                    ((and alias (slot-boundp object alias))
                      (setf (slot-value new-obj sname) (slot-value object alias))))))))

      (if (and is-wide (%persistent-vector object))
          (let* ((overflow-indices (persistent-class-overflow-indices class))
                 (any-overflow (some (lambda (k) (gethash k overflow-indices)) keys-to-remove)))
            (if any-overflow
                (let ((tv (fol.compiler.collections:transient (%persistent-vector object)))
                      (vector-mutated-p nil))
                  (maphash (lambda (sname idx)
                             (let ((alias (gethash sname (persistent-class-slot-aliases class))))
                               (when (or (member sname keys-to-remove)
                                         (and alias (member alias keys-to-remove)))
                                 (fol.compiler.collections:assoc! tv idx :unbound)
                                 (setf vector-mutated-p t))))
                           overflow-indices)
                  (setf (%persistent-vector new-obj)
                    (if vector-mutated-p
                        (fol.compiler.collections:persistent! tv)
                        (%persistent-vector object))))
                ;; Native-only dissoc: just copy the existing vector
                (setf (%persistent-vector new-obj) (%persistent-vector object)))))

      (when (slot-boundp object '%metadata)
            (setf (%persistent-metadata new-obj) (%persistent-metadata object)))

      new-obj)))
