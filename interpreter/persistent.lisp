(in-package fol.persistent)

;;; ============================================================================
;;; Persistent Object System using FSet
;;; ============================================================================

(defclass persistent-class (standard-class)
  ()
  (:documentation "Metaclass for persistent objects whose slots are stored in an FSet map."))

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
;;; Base Persistent Object Class
;;; ============================================================================

(defclass <persistent-object> (standard-object)
  ((%persistent-storage :accessor %persistent-storage
                        :documentation "The FSet map storing all slot values."))
  (:metaclass persistent-class)
  (:documentation "Base class for objects with persistent (immutable) slot storage."))

;;; ============================================================================
;;; Initialization
;;; ============================================================================

(defvar *initializing-persistent-object* nil
  "Bound to T during persistent object initialization to allow slot writes.")

(defmethod initialize-instance :around ((object <persistent-object>) &rest initargs)
  "Track that we're initializing to allow slot writes."
  (declare (ignore initargs))
  (let ((*initializing-persistent-object* t))
    (call-next-method)))

(defmethod initialize-instance :after ((object <persistent-object>) &rest initargs)
  "Initialize the persistent storage with provided initargs and initforms."
  (let ((storage (fset:empty-map))
        (class (class-of object)))
    (dolist (slot (closer-mop:class-slots class))
      (let* ((slot-name (closer-mop:slot-definition-name slot))
             (keyword (intern (string slot-name) :keyword))
             (init-value (getf initargs keyword :not-found)))
        (unless (eq slot-name '%persistent-storage)
          (cond
            ;; Value provided in initargs
            ((not (eq init-value :not-found))
             (setf storage (fset:with storage (string slot-name) init-value)))
            ;; Use initform if available
            ((closer-mop:slot-definition-initfunction slot)
             (setf storage (fset:with storage 
                                     (string slot-name)
                                     (funcall (closer-mop:slot-definition-initfunction slot)))))))))
    (setf (%persistent-storage object) storage)))

;;; ============================================================================
;;; MOP Integration - Slot Access
;;; ============================================================================

(defmethod closer-mop:slot-value-using-class ((class persistent-class) 
                                              object 
                                              (slot closer-mop:standard-effective-slot-definition))
  "Retrieve slot value from the persistent FSet map storage."
  (let ((slot-name (closer-mop:slot-definition-name slot)))
    (if (eq slot-name '%persistent-storage)
        ;; Direct access to storage slot
        (call-next-method)
        ;; Retrieve from FSet map - CHECK IF STORAGE EXISTS FIRST
        (if (slot-boundp object '%persistent-storage)
            ;; Storage exists, read from it
            (let* ((storage (%persistent-storage object))
                   (key (string slot-name)))
              (if (fset:domain-contains? storage key)
                  (fset:lookup storage key)
                  ;; Slot not in storage - try initform or signal unbound
                  (if (closer-mop:slot-definition-initfunction slot)
                      (funcall (closer-mop:slot-definition-initfunction slot))
                      (slot-unbound class object slot-name))))
            ;; Storage doesn't exist yet (during initialization)
            ;; Use call-next-method to get standard slot behavior
            (call-next-method)))))

(defmethod (setf closer-mop:slot-value-using-class) (new-value
                                                      (class persistent-class)
                                                      object
                                                      (slot closer-mop:standard-effective-slot-definition))
  "Prevent direct slot modification on persistent objects after initialization."
  (let ((slot-name (closer-mop:slot-definition-name slot)))
    (cond
      ;; Always allow setting the storage slot itself
      ((eq slot-name '%persistent-storage)
       (call-next-method))
      ;; Allow during initialization
      (*initializing-persistent-object*
       (call-next-method))
      ;; After initialization, prevent modification
      (t
       (error "Cannot directly set slot ~A on persistent object. Use SET-PSLOT-VALUE instead." 
              slot-name)))))

(defmethod closer-mop:slot-boundp-using-class ((class persistent-class)
                                               object
                                               (slot closer-mop:standard-effective-slot-definition))
  "Check if a slot is bound in the persistent storage."
  (let ((slot-name (closer-mop:slot-definition-name slot)))
    (if (eq slot-name '%persistent-storage)
        (call-next-method)
        ;; CHECK IF STORAGE EXISTS FIRST!
        (if (slot-boundp object '%persistent-storage)
            ;; Storage exists - check if slot is in it
            (fset:domain-contains? (%persistent-storage object) (string slot-name))
            ;; Storage doesn't exist yet - use standard behavior
            (call-next-method)))))

(defmethod closer-mop:slot-makunbound-using-class ((class persistent-class)
                                                   object
                                                   (slot closer-mop:standard-effective-slot-definition))
  "Cannot make slots unbound on persistent objects."
  (error "Cannot make slot ~A unbound on persistent object." 
         (closer-mop:slot-definition-name slot)))

;;; ============================================================================
;;; Functional Update API
;;; ============================================================================

(defun pslot-value (object slot-name)
  "Get the value of a slot in a persistent object."
  (slot-value object slot-name))

(defun set-pslot-value (object slot-name new-value)
  "Create a new persistent object with the specified slot updated.
   Returns a new object sharing structure with the original."
  (let* ((class (class-of object))
         (new-obj (allocate-instance class))
         (old-storage (%persistent-storage object))
         (new-storage (fset:with old-storage (string slot-name) new-value)))
    ;; Initialize the new object with updated storage
    (let ((*initializing-persistent-object* t))
      (setf (%persistent-storage new-obj) new-storage))
    new-obj))

(defun set-pslot-values (object &rest slot-name-value-pairs)
  "Create a new persistent object with multiple slots updated.
   Takes alternating slot-name value pairs.
   Example: (set-pslot-values obj 'x 10 'y 20)"
  (let* ((class (class-of object))
         (new-obj (allocate-instance class))
         (storage (%persistent-storage object)))
    ;; Update all slots in the storage
    (loop for (slot-name value) on slot-name-value-pairs by #'cddr
          do (setf storage (fset:with storage (string slot-name) value)))
    ;; Initialize the new object with updated storage
    (let ((*initializing-persistent-object* t))
      (setf (%persistent-storage new-obj) storage))
    new-obj))

;;; ============================================================================
;;; Convenience Macros
;;; ============================================================================

(defmacro with-pslots (slot-specs object &body body)
  "Bind slot names from a persistent object for convenient access.
   Similar to WITH-SLOTS but for persistent objects.
   SLOT-SPECS is a list where each element is either:
     - a symbol (binds to that slot name)
     - a list (var-name slot-name) to bind to a different variable name
   Example: (with-pslots (x y) point (list x y))
   Example: (with-pslots ((px x) (py y)) point (list px py))"
  (let ((obj-var (gensym "OBJ")))
    `(let ((,obj-var ,object))
       (let ,(loop for spec in slot-specs
                   collect (if (consp spec)
                               `(,(first spec) (pslot-value ,obj-var ',(second spec)))
                               `(,spec (pslot-value ,obj-var ',spec))))
         ,@body))))

;;; ============================================================================
;;; Type Predicate
;;; ============================================================================

(defun <persistent-object>? (obj)
  "Returns true if obj is a persistent object."
  (typep obj '<persistent-object>))