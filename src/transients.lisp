(in-package :fol.compiler.collections)

;;; ===========================================================================
;;; Transient Protocol
;;; ===========================================================================

(defgeneric transient (collection)
  (:documentation "Returns a transient (mutable) version of the collection."))

(defmethod transient ((obj t))
  "Default: everything else is already its own transient."
  obj)

(defgeneric persistent! (transient-collection)
  (:documentation "Freezes a transient collection and returns it as a persistent one."))

(defmethod persistent! ((obj t))
  "Default: everything else is already persistent."
  obj)

(defgeneric conj! (transient-collection val)
  (:documentation "Adds an element to a transient collection in-place."))

(defmethod conj! ((obj t) val)
  (error "conj! not supported for type ~A" (type-of obj)))

(defgeneric pop! (transient-collection)
  (:documentation "Removes the last element from a transient collection in-place."))

(defmethod pop! ((obj t))
  (error "pop! not supported for type ~A" (type-of obj)))

(defgeneric assoc! (transient-collection key val)
  (:documentation "Sets a key/value pair in a transient collection in-place."))

(defmethod assoc! ((obj t) key val)
  (error "assoc! not supported for type ~A" (type-of obj)))

(defgeneric dissoc! (transient-collection key)
  (:documentation "Removes a key from a transient collection in-place."))

(defmethod dissoc! ((obj t) key)
  (error "dissoc! not supported for type ~A" (type-of obj)))

(defgeneric disj! (transient-collection val)
  (:documentation "Removes an element from a transient set in-place."))

(defmethod disj! ((obj t) val)
  (error "disj! not supported for type ~A" (type-of obj)))

;;; --- Vector Transients ---

(defmethod transient ((v <vector>))
  (fol.compiler.collection-primitives:transient-%vec-t (fol.compiler.collection-primitives:storage v)))

(defmethod conj! ((tv fol.compiler.collection-primitives::transient-%vec-t) val)
  (fol.compiler.collection-primitives::transient-%vec-t-conj! tv val))

(defmethod persistent! ((tv fol.compiler.collection-primitives::transient-%vec-t))
  (make-instance '<vector>
    :storage (fol.compiler.collection-primitives::transient-%vec-t-persistent! tv)))

;;; --- Dict Transients ---

(defmethod transient ((d <dict>))
  (fol.compiler.collection-primitives:api-transient-hamt (fol.compiler.collection-primitives:dict-storage d)))

(defmethod conj! ((th fol.compiler.collection-primitives::transient-hamt) value)
  (fol.compiler.collection-primitives:hamt-assoc! th value value))

(defmethod assoc! ((th fol.compiler.collection-primitives::transient-hamt) key value)
  (fol.compiler.collection-primitives:hamt-assoc! th key value))

(defmethod dissoc! ((th fol.compiler.collection-primitives::transient-hamt) key)
  (fol.compiler.collection-primitives:hamt-dissoc! th key))

(defmethod disj! ((th fol.compiler.collection-primitives::transient-hamt) val)
  (fol.compiler.collection-primitives:hamt-dissoc! th val))

(defmethod persistent! ((th fol.compiler.collection-primitives::transient-hamt))
  (make-instance '<dict>
    :dict-storage (fol.compiler.collection-primitives:hamt-persistent! th)))

(in-package :fol.compiler.persistent)

;;; ===========================================================================
;;; Persistent Object Transient Support
;;; ===========================================================================

(defmethod transient ((object <persistent-object>))
  "Return a transient (mutable) version of the object.
   For FOL objects, this returns a shallow copy with the transient bit set."
  (let* ((class (class-of object))
         (new-obj (allocate-instance class)))
    (let ((*initializing-persistent-object* t))
      ;; Shallow copy all slots
      (dolist (slot (closer-mop:class-slots class))
        (let ((sname (closer-mop:slot-definition-name slot)))
          (when (slot-boundp object sname)
                (setf (slot-value new-obj sname) (slot-value object sname)))))
      ;; Mark as transient
      (setf (%transient-p new-obj) t)
      ;; If wide, prepare the mutable buffer
      (when (> (persistent-class-slot-count class) +native-slot-limit+)
            (let* ((overflow-indices (persistent-class-overflow-indices class))
                   (size (hash-table-count overflow-indices))
                   (buffer (make-array size :initial-element :unbound))
                   (pvec (%persistent-vector object)))
              (when pvec
                    (loop for i from 0 below (fol.compiler.collections:collection-size pvec)
                          do (setf (aref buffer i) (fol.compiler.collections:collection-ref pvec i))))
              (setf (%transient-buffer new-obj) buffer))))
    new-obj))

(defmethod persistent! ((object <persistent-object>))
  "Freeze a transient object, making it immutable. Returns the object."
  (unless (%transient-p object)
    (error "Object is not transient."))
  (let* ((class (class-of object))
         (is-wide (> (persistent-class-slot-count class) +native-slot-limit+)))
    ;; If wide, freeze the buffer
    (when is-wide
          (let ((buffer (%transient-buffer object)))
            (when buffer
                  (let ((*initializing-persistent-object* t))
                    (setf (%persistent-vector object)
                      (make-instance 'fol.compiler.collections:<vector>
                        :storage (fol.compiler.collection-primitives::%build-vec-t-from-list
                                  (coerce buffer 'list))))
                    (setf (%transient-buffer object) nil)))))
    ;; Unset transient bit
    (setf (%transient-p object) nil)
    object))

(defmethod fol.compiler.collections:assoc! ((object <persistent-object>) key value)
  "Update a slot in a transient persistent object in-place."
  (unless (%transient-p object)
    (error "Cannot use assoc! on a non-transient object."))
  (update-slot object key value)
  object)
