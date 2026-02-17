;;; FOL Compiler - Persistent Object System
;;;
;;; Provides immutable objects with structural sharing via Sycamore hash-maps.
;;; All FOL user-level classes inherit from <persistent-object>, storing
;;; slot values in a Sycamore hash-map rather than standard CLOS slots.
;;;
;;; Sycamore hash-map was selected after benchmarking against FSet wb-map
;;; and Sycamore tree-map across 2, 5, 10, and 20 slot objects:
;;;   - Value access: 2-6x faster than FSet
;;;   - Construction: 2.4-3x faster than FSet
;;;   - Functional update: 1.4-2.4x faster than FSet
;;;
;;; Slot access is transparent through the MOP: standard slot-value and
;;; accessor functions work normally. Mutation is prevented after init;
;;; use update-slot/update-slots for functional updates.
;;;
;;; Keys are stored as keyword symbols for fast EQL-based lookup.

(in-package :fol.compiler.persistent)

;;; ============================================================================
;;; Metaclass
;;; ============================================================================

(defclass persistent-class (standard-class)
  ()
  (:documentation "Metaclass for persistent objects whose slots are stored in a Sycamore hash-map."))

(defmethod closer-mop:validate-superclass ((class persistent-class)
                                           (superclass standard-class))
  t)

(defmethod closer-mop:validate-superclass ((class persistent-class)
                                           (superclass persistent-class))
  t)

;;; Allow standard-class subclasses of persistent-class classes (for mutable classes like <lazy-seq>)
(defmethod closer-mop:validate-superclass ((class standard-class)
                                           (superclass persistent-class))
  t)

;;; ============================================================================
;;; Base Class
;;; ============================================================================

(defclass <persistent-object> (standard-object)
  ((%persistent-storage :accessor %persistent-storage
                        :documentation "Sycamore hash-map storing all slot values.")
   (%metadata :accessor %persistent-metadata
              :initarg :metadata :initform nil
              :documentation "Optional metadata dict associated with this object."))
  (:metaclass persistent-class)
  (:documentation "Base class for objects with persistent (immutable) slot storage."))

;;; ============================================================================
;;; Slot name to keyword conversion (cached)
;;; ============================================================================

(defvar *slot-key-cache* (make-hash-table :test 'eq)
  "Cache mapping slot-definition-name symbols to keyword symbols.")

(declaim (inline slot-key))
(defun slot-key (slot-name)
  "Convert a slot name symbol to a keyword for Sycamore hash-map lookup."
  (or (gethash slot-name *slot-key-cache*)
      (setf (gethash slot-name *slot-key-cache*)
            (intern (string slot-name) :keyword))))

;;; ============================================================================
;;; Initialization
;;; ============================================================================

(defvar *initializing-persistent-object* nil
  "Bound to T during persistent object initialization to allow slot writes.")

(defmethod initialize-instance :around ((object <persistent-object>) &rest initargs)
  "Allow slot writes during initialization."
  (declare (ignore initargs))
  (let ((*initializing-persistent-object* t))
    (call-next-method)))

(defmethod initialize-instance :after ((object <persistent-object>) &rest initargs)
  "Populate the Sycamore hash-map from initargs and initforms."
  (let ((storage (sycamore:make-hash-map))
        (class (class-of object)))
    (dolist (slot (closer-mop:class-slots class))
      (let* ((slot-name (closer-mop:slot-definition-name slot))
             (keyword (slot-key slot-name))
             (init-value (getf initargs keyword :not-found)))
        (unless (member slot-name '(%persistent-storage %metadata))
          (cond
            ((not (eq init-value :not-found))
             (setf storage (sycamore:hash-map-insert storage keyword init-value)))
            ((closer-mop:slot-definition-initfunction slot)
             (setf storage (sycamore:hash-map-insert
                            storage
                            keyword
                            (funcall (closer-mop:slot-definition-initfunction slot)))))))))
    (setf (%persistent-storage object) storage)))

;;; ============================================================================
;;; MOP Integration - Slot Access
;;; ============================================================================

(defmethod closer-mop:slot-value-using-class ((class persistent-class)
                                              object
                                              (slot closer-mop:standard-effective-slot-definition))
  "Read slot value from Sycamore hash-map."
  (let ((slot-name (closer-mop:slot-definition-name slot)))
    (if (member slot-name '(%persistent-storage %metadata))
        (call-next-method)
        (if (slot-boundp object '%persistent-storage)
            (let* ((storage (%persistent-storage object))
                   (key (slot-key slot-name)))
              (multiple-value-bind (value found)
                  (sycamore:hash-map-find storage key)
                (if found
                    value
                    (if (closer-mop:slot-definition-initfunction slot)
                        (funcall (closer-mop:slot-definition-initfunction slot))
                        (slot-unbound class object slot-name)))))
            (call-next-method)))))

(defmethod (setf closer-mop:slot-value-using-class) (new-value
                                                      (class persistent-class)
                                                      object
                                                      (slot closer-mop:standard-effective-slot-definition))
  "Prevent slot mutation after initialization."
  (let ((slot-name (closer-mop:slot-definition-name slot)))
    (cond
      ((member slot-name '(%persistent-storage %metadata))
       (call-next-method))
      (*initializing-persistent-object*
       (call-next-method))
      (t
       (error "Cannot set slot ~A on persistent object. Use UPDATE-SLOT." slot-name)))))

(defmethod closer-mop:slot-boundp-using-class ((class persistent-class)
                                               object
                                               (slot closer-mop:standard-effective-slot-definition))
  "Check if slot exists in Sycamore hash-map."
  (let ((slot-name (closer-mop:slot-definition-name slot)))
    (if (member slot-name '(%persistent-storage %metadata))
        (call-next-method)
        (if (slot-boundp object '%persistent-storage)
            (nth-value 1 (sycamore:hash-map-find (%persistent-storage object)
                                                  (slot-key slot-name)))
            (call-next-method)))))

(defmethod closer-mop:slot-makunbound-using-class ((class persistent-class)
                                                   object
                                                   (slot closer-mop:standard-effective-slot-definition))
  "Cannot unbind slots on persistent objects."
  (error "Cannot make slot ~A unbound on persistent object."
         (closer-mop:slot-definition-name slot)))

;;; ============================================================================
;;; Functional Update API
;;; ============================================================================

(defun update-slot (object slot-name new-value)
  "Return a new persistent object with SLOT-NAME updated to NEW-VALUE.
   Shares structure with OBJECT via Sycamore's persistent hash-map."
  (let* ((class (class-of object))
         (new-obj (allocate-instance class))
         (old-storage (%persistent-storage object))
         (new-storage (sycamore:hash-map-insert old-storage (slot-key slot-name) new-value)))
    (let ((*initializing-persistent-object* t))
      (setf (%persistent-storage new-obj) new-storage)
      (setf (%persistent-metadata new-obj) (%persistent-metadata object)))
    new-obj))

(defun update-slots (object &rest slot-name-value-pairs)
  "Return a new persistent object with multiple slots updated.
   Takes alternating slot-name value pairs.
   Example: (update-slots obj 'x 10 'y 20)"
  (let* ((class (class-of object))
         (new-obj (allocate-instance class))
         (storage (%persistent-storage object)))
    (loop for (slot-name value) on slot-name-value-pairs by #'cddr
          do (setf storage (sycamore:hash-map-insert storage (slot-key slot-name) value)))
    (let ((*initializing-persistent-object* t))
      (setf (%persistent-storage new-obj) storage)
      (setf (%persistent-metadata new-obj) (%persistent-metadata object)))
    new-obj))
