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
