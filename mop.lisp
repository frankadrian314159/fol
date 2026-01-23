(in-package fol.mop)

;;; ============================================================================
;;; FOL Metaobject Protocol
;;; ============================================================================
;;; A metaobject protocol for FOL's persistent-class system, providing
;;; introspection and reflection capabilities similar to CLOS MOP.
;;;
;;; This is built on top of Closer-MOP but provides a FOL-specific interface
;;; that works with persistent-class as the foundational metaclass.
;;; ============================================================================

;;; ============================================================================
;;; Class Introspection
;;; ============================================================================

(defgeneric class-name* (class)
  (:documentation "Return the name of the class."))

(defmethod class-name* ((class persistent-class))
  (class-name class))

(defmethod class-name* ((class class))
  "Catch-all method for any class object (handles standard-class, etc.)."
  (class-name class))

(defmethod class-name* ((class symbol))
  (class-name (find-class class)))

(defgeneric class-direct-superclasses* (class)
  (:documentation "Return the list of direct superclasses of CLASS."))

(defmethod class-direct-superclasses* ((class persistent-class))
  (closer-mop:class-direct-superclasses class))

(defmethod class-direct-superclasses* ((class symbol))
  (closer-mop:class-direct-superclasses (find-class class)))

(defgeneric class-direct-subclasses* (class)
  (:documentation "Return the list of direct subclasses of CLASS."))

(defmethod class-direct-subclasses* ((class persistent-class))
  (closer-mop:class-direct-subclasses class))

(defmethod class-direct-subclasses* ((class symbol))
  (closer-mop:class-direct-subclasses (find-class class)))

(defgeneric class-precedence-list* (class)
  (:documentation "Return the class precedence list for CLASS."))

(defmethod class-precedence-list* ((class persistent-class))
  (ensure-finalized class)
  (closer-mop:class-precedence-list class))

(defmethod class-precedence-list* ((class symbol))
  (class-precedence-list* (find-class class)))

(defgeneric class-direct-slots* (class)
  (:documentation "Return the list of direct slot definitions for CLASS."))

(defmethod class-direct-slots* ((class persistent-class))
  (ensure-finalized class)
  (closer-mop:class-direct-slots class))

(defmethod class-direct-slots* ((class standard-class))
  "Fallback for standard CL classes."
  (closer-mop:class-direct-slots class))

(defmethod class-direct-slots* ((class class))
  "General fallback for any class type (including implementation-specific classes)."
  (closer-mop:class-direct-slots class))

(defmethod class-direct-slots* ((class symbol))
  (class-direct-slots* (find-class class)))

(defgeneric class-slots* (class)
  (:documentation "Return the list of all effective slot definitions for CLASS (including inherited)."))

(defmethod class-slots* ((class persistent-class))
  (ensure-finalized class)
  (closer-mop:class-slots class))

(defmethod class-slots* ((class standard-class))
  "Fallback for standard CL classes."
  (closer-mop:class-slots class))

(defmethod class-slots* ((class class))
  "General fallback for any class type (including implementation-specific classes)."
  (closer-mop:class-slots class))

(defmethod class-slots* ((class symbol))
  (class-slots* (find-class class)))

(defgeneric finalized-p (class)
  (:documentation "Return T if CLASS has been finalized, NIL otherwise."))

(defmethod finalized-p ((class persistent-class))
  (closer-mop:class-finalized-p class))

(defmethod finalized-p ((class symbol))
  (closer-mop:class-finalized-p (find-class class)))

(defgeneric ensure-finalized (class)
  (:documentation "Ensure CLASS is finalized. Returns CLASS."))

(defmethod ensure-finalized ((class persistent-class))
  (unless (closer-mop:class-finalized-p class)
    (closer-mop:finalize-inheritance class))
  class)

(defmethod ensure-finalized ((class symbol))
  (ensure-finalized (find-class class)))

;;; ============================================================================
;;; Slot Definition Introspection
;;; ============================================================================

(defgeneric slot-definition-name* (slot)
  (:documentation "Return the name of SLOT."))

(defmethod slot-definition-name* (slot)
  (closer-mop:slot-definition-name slot))

(defgeneric slot-definition-type* (slot)
  (:documentation "Return the type constraint of SLOT."))

(defmethod slot-definition-type* (slot)
  (closer-mop:slot-definition-type slot))

(defgeneric slot-definition-initargs* (slot)
  (:documentation "Return the list of initialization keywords for SLOT."))

(defmethod slot-definition-initargs* (slot)
  (closer-mop:slot-definition-initargs slot))

(defgeneric slot-definition-initform* (slot)
  (:documentation "Return the initform expression for SLOT."))

(defmethod slot-definition-initform* (slot)
  (closer-mop:slot-definition-initform slot))

(defgeneric slot-definition-initfunction* (slot)
  (:documentation "Return the initfunction (compiled initform) for SLOT, or NIL if none."))

(defmethod slot-definition-initfunction* (slot)
  (closer-mop:slot-definition-initfunction slot))

(defgeneric slot-definition-allocation* (slot)
  (:documentation "Return the allocation type of SLOT (:INSTANCE or :CLASS)."))

(defmethod slot-definition-allocation* (slot)
  (closer-mop:slot-definition-allocation slot))

(defgeneric slot-definition-readers* (slot)
  (:documentation "Return the list of reader generic functions for SLOT."))

(defmethod slot-definition-readers* (slot)
  ;; For direct slot definitions, get the readers
  (handler-case
      (closer-mop:slot-definition-readers slot)
    (error () nil)))  ; Return NIL if readers not available (e.g., effective slots)

(defgeneric slot-definition-writers* (slot)
  (:documentation "Return the list of writer generic functions for SLOT."))

(defmethod slot-definition-writers* (slot)
  ;; For direct slot definitions, get the writers
  (handler-case
      (closer-mop:slot-definition-writers slot)
    (error () nil)))  ; Return NIL if writers not available (e.g., effective slots)

;;; ============================================================================
;;; Instance Introspection
;;; ============================================================================

(defgeneric instance-class (instance)
  (:documentation "Return the class of INSTANCE."))

(defmethod instance-class (instance)
  (class-of instance))

(defgeneric instance-slots (instance)
  (:documentation "Return the list of slot definitions for INSTANCE's class."))

(defmethod instance-slots (instance)
  (class-slots* (class-of instance)))

(defgeneric slot-names (class-or-instance)
  (:documentation "Return a list of slot names for CLASS-OR-INSTANCE."))

(defmethod slot-names ((class persistent-class))
  (mapcar #'closer-mop:slot-definition-name (class-slots* class)))

(defmethod slot-names ((class symbol))
  (slot-names (find-class class)))

(defmethod slot-names (instance)
  (slot-names (class-of instance)))

(defgeneric slot-exists-p* (class-or-instance slot-name)
  (:documentation "Return T if SLOT-NAME exists in CLASS-OR-INSTANCE, NIL otherwise."))

(defmethod slot-exists-p* ((class persistent-class) slot-name)
  (not (null (find slot-name (class-slots* class)
                   :key #'closer-mop:slot-definition-name))))

(defmethod slot-exists-p* ((class symbol) slot-name)
  (slot-exists-p* (find-class class) slot-name))

(defmethod slot-exists-p* (instance slot-name)
  (slot-exists-p* (class-of instance) slot-name))

(defgeneric slot-boundp* (instance slot-name)
  (:documentation "Return T if SLOT-NAME is bound in INSTANCE, NIL otherwise."))

(defmethod slot-boundp* (instance slot-name)
  (slot-boundp instance slot-name))

(defgeneric slot-value* (instance slot-name)
  (:documentation "Return the value of SLOT-NAME in INSTANCE."))

(defmethod slot-value* (instance slot-name)
  (slot-value instance slot-name))

;;; ============================================================================
;;; Utility Functions
;;; ============================================================================

(defun all-persistent-classes ()
  "Return a list of all classes with persistent-class as their metaclass."
  (let ((result nil))
    (do-all-symbols (sym)
      (when (and (find-class sym nil)
                 (typep (find-class sym) 'persistent-class))
        (pushnew (find-class sym) result)))
    result))

(defun subclasses* (class &key (direct-only nil))
  "Return all subclasses of CLASS. If DIRECT-ONLY is T, return only direct subclasses."
  (let ((class-obj (if (symbolp class) (find-class class) class)))
    (if direct-only
        (class-direct-subclasses* class-obj)
        (labels ((collect-subclasses (cls)
                   (let ((direct (class-direct-subclasses* cls)))
                     (append direct
                             (mapcan #'collect-subclasses direct)))))
          (remove-duplicates (collect-subclasses class-obj))))))

(defun superclasses* (class &key (direct-only nil))
  "Return all superclasses of CLASS. If DIRECT-ONLY is T, return only direct superclasses."
  (let ((class-obj (if (symbolp class) (find-class class) class)))
    (if direct-only
        (class-direct-superclasses* class-obj)
        (rest (class-precedence-list* class-obj)))))

(defun find-slot-definition (class slot-name)
  "Find and return the slot definition for SLOT-NAME in CLASS, or NIL if not found."
  (let ((class-obj (if (symbolp class) (find-class class) class)))
    (find slot-name (class-slots* class-obj)
          :key #'closer-mop:slot-definition-name)))

(defun slot-properties (class-or-instance slot-name)
  "Return a property list describing SLOT-NAME in CLASS-OR-INSTANCE."
  (let* ((class (if (symbolp class-or-instance)
                    (find-class class-or-instance)
                    (if (typep class-or-instance 'persistent-class)
                        class-or-instance
                        (class-of class-or-instance))))
         (slot-def (find-slot-definition class slot-name))
         ;; Find direct slot definition for readers/writers by searching precedence list
         (direct-slot (some (lambda (c)
                              (find slot-name (class-direct-slots* c)
                                    :key #'closer-mop:slot-definition-name))
                            (class-precedence-list* class))))
    (when slot-def
      (list :name (slot-definition-name* slot-def)
            :type (slot-definition-type* slot-def)
            :allocation (slot-definition-allocation* slot-def)
            :initargs (slot-definition-initargs* slot-def)
            :initform (slot-definition-initform* slot-def)
            ;; Get readers/writers from direct slot if available
            :readers (when direct-slot (slot-definition-readers* direct-slot))
            :writers (when direct-slot (slot-definition-writers* direct-slot))))))

(defun class-info (class)
  "Return a property list with detailed information about CLASS."
  (let ((class-obj (if (symbolp class) (find-class class) class)))
    (list :name (class-name* class-obj)
          :direct-superclasses (mapcar #'class-name* (class-direct-superclasses* class-obj))
          :direct-subclasses (mapcar #'class-name* (class-direct-subclasses* class-obj))
          :precedence-list (mapcar #'class-name* (class-precedence-list* class-obj))
          :direct-slots (mapcar #'slot-definition-name* (class-direct-slots* class-obj))
          :all-slots (mapcar #'slot-definition-name* (class-slots* class-obj))
          :finalized (finalized-p class-obj))))

(defun describe-class (class &optional (stream *standard-output*))
  "Print a human-readable description of CLASS to STREAM."
  (let* ((class-obj (if (symbolp class) (find-class class) class))
         (info (class-info class-obj)))
    (format stream "~&Class: ~A~%" (getf info :name))
    (format stream "  Metaclass: ~A~%" (class-name (class-of class-obj)))
    (format stream "  Direct superclasses: ~{~A~^, ~}~%" (getf info :direct-superclasses))
    (format stream "  Precedence list: ~{~A~^, ~}~%" (getf info :precedence-list))
    (format stream "  Direct subclasses: ~{~A~^, ~}~%" (getf info :direct-subclasses))
    (format stream "  Direct slots: ~{~A~^, ~}~%" (getf info :direct-slots))
    (format stream "  All slots: ~{~A~^, ~}~%" (getf info :all-slots))
    (format stream "  Finalized: ~A~%" (getf info :finalized))
    class-obj))

(defun describe-slot (class-or-instance slot-name &optional (stream *standard-output*))
  "Print a human-readable description of SLOT-NAME to STREAM."
  (let ((props (slot-properties class-or-instance slot-name)))
    (if props
        (progn
          (format stream "~&Slot: ~A~%" (getf props :name))
          (format stream "  Type: ~A~%" (getf props :type))
          (format stream "  Allocation: ~A~%" (getf props :allocation))
          (format stream "  Initargs: ~{~A~^, ~}~%" (getf props :initargs))
          (format stream "  Initform: ~S~%" (getf props :initform))
          (format stream "  Readers: ~{~A~^, ~}~%" (getf props :readers))
          (format stream "  Writers: ~{~A~^, ~}~%" (getf props :writers)))
        (format stream "~&Slot ~A not found~%" slot-name))
    props))

(defun persistent-class-p (class-or-symbol)
  "Return T if CLASS-OR-SYMBOL is or names a persistent-class, NIL otherwise."
  (let ((class (if (symbolp class-or-symbol)
                   (find-class class-or-symbol nil)
                   class-or-symbol)))
    (and class (typep class 'persistent-class))))

(defun persistent-object-p (object)
  "Return T if OBJECT is an instance of a persistent-class, NIL otherwise."
  (and (typep object '<persistent-object>)
       (persistent-class-p (class-of object))))

;;; ============================================================================
;;; Constructor Generation Protocol
;;; ============================================================================
;;; This section provides a protocol for generating constructor functions
;;; following the pattern make-X where X is the class name without angle brackets.
;;; For example: <string> -> make-string, <vector> -> make-vector

(defun class-name-string (class)
  "Return the name of CLASS as a string."
  (let ((class-obj (if (symbolp class) (find-class class) class)))
    (symbol-name (class-name* class-obj))))

(defun bare-class-name (class)
  "Return the class name without angle brackets.
   E.g., '<string>' becomes 'string', '<persistent-object>' becomes 'persistent-object'."
  (let ((name (class-name-string class)))
    (if (and (> (length name) 2)
             (char= (char name 0) #\<)
             (char= (char name (1- (length name))) #\>))
        (subseq name 1 (1- (length name)))
        name)))

(defun constructor-name (class &optional (prefix "MAKE-"))
  "Return the constructor function name for CLASS.
   E.g., '<string>' becomes 'MAKE-STRING'."
  (let* ((bare-name (bare-class-name class))
         (class-obj (if (symbolp class) (find-class class) class))
         (class-sym (class-name* class-obj))
         (pkg (symbol-package class-sym)))
    (intern (concatenate 'string prefix (string-upcase bare-name)) pkg)))

(defun class-initargs (class)
  "Return a list of all initarg keywords for CLASS."
  (let ((class-obj (if (symbolp class) (find-class class) class)))
    (ensure-finalized class-obj)
    (remove-duplicates
     (mapcan (lambda (slot)
               (copy-list (slot-definition-initargs* slot)))
             (class-slots* class-obj)))))

(defun required-initargs (class)
  "Return a list of initargs for slots that have no initform (required args)."
  (let ((class-obj (if (symbolp class) (find-class class) class)))
    (ensure-finalized class-obj)
    (remove-duplicates
     (mapcan (lambda (slot)
               (when (null (slot-definition-initfunction* slot))
                 (copy-list (slot-definition-initargs* slot))))
             (class-slots* class-obj)))))

(defun optional-initargs (class)
  "Return a list of initargs for slots that have an initform (optional args)."
  (let ((class-obj (if (symbolp class) (find-class class) class)))
    (ensure-finalized class-obj)
    (remove-duplicates
     (mapcan (lambda (slot)
               (when (slot-definition-initfunction* slot)
                 (copy-list (slot-definition-initargs* slot))))
             (class-slots* class-obj)))))

(defgeneric make-instance* (class &rest initargs)
  (:documentation "Generic constructor for FOL classes.
   This serves as the base protocol for constructing instances."))

(defmethod make-instance* ((class symbol) &rest initargs)
  "Create an instance of the class named by SYMBOL."
  (apply #'make-instance class initargs))

(defmethod make-instance* ((class class) &rest initargs)
  "Create an instance of CLASS."
  (apply #'make-instance class initargs))

(defmacro define-constructor (class-name &key
                                           (constructor-name nil)
                                           (package nil)
                                           (documentation nil))
  "Define a constructor function for CLASS-NAME following the make-X pattern.

   CLASS-NAME - The class name symbol (e.g., '<string>)
   CONSTRUCTOR-NAME - Override the default make-X name
   PACKAGE - Package to intern the constructor in (default: class's package)
   DOCUMENTATION - Optional docstring for the constructor

   Example:
     (define-constructor <string>)
     ; Creates: (defun make-string (&rest initargs) ...)"
  (let* ((class-obj (find-class class-name))
         (ctor-name (or constructor-name
                        (constructor-name class-obj)))
         (target-pkg (or package
                         (symbol-package (class-name* class-obj))))
         (ctor-sym (if (symbolp ctor-name)
                       ctor-name
                       (intern ctor-name target-pkg)))
         (doc (or documentation
                  (format nil "Create an instance of ~A." class-name))))
    `(progn
       (defun ,ctor-sym (&rest initargs)
         ,doc
         (apply #'make-instance ',class-name initargs))
       ',ctor-sym)))

(defmacro define-constructors (&rest class-names)
  "Define constructor functions for multiple classes.

   Example:
     (define-constructors <string> <bool> <char>)
     ; Creates make-string, make-bool, make-char"
  `(progn
     ,@(mapcar (lambda (class-name)
                 `(define-constructor ,class-name))
               class-names)
     (list ,@(mapcar (lambda (class-name)
                       `',(constructor-name (find-class class-name)))
                     class-names))))

(defun generate-constructor-form (class)
  "Return the source form that would define a constructor for CLASS.
   Useful for metaprogramming and code generation."
  (let* ((class-obj (if (symbolp class) (find-class class) class))
         (class-name (class-name* class-obj))
         (ctor-name (constructor-name class-obj)))
    `(defun ,ctor-name (&rest initargs)
       ,(format nil "Create an instance of ~A." class-name)
       (apply #'make-instance ',class-name initargs))))

(defun list-constructible-classes (&optional (filter-fn #'identity))
  "Return a list of all persistent classes that could have constructors generated.
   FILTER-FN can be used to filter the results."
  (remove-if-not filter-fn (all-persistent-classes)))

(defun describe-constructor (class &optional (stream *standard-output*))
  "Print information about the constructor that would be generated for CLASS."
  (let* ((class-obj (if (symbolp class) (find-class class) class))
         (class-name (class-name* class-obj))
         (ctor-name (constructor-name class-obj))
         (required (required-initargs class-obj))
         (optional (optional-initargs class-obj)))
    (format stream "~&Constructor for ~A:~%" class-name)
    (format stream "  Function name: ~A~%" ctor-name)
    (format stream "  Required initargs: ~{~A~^, ~}~%" required)
    (format stream "  Optional initargs: ~{~A~^, ~}~%" optional)
    (format stream "  All initargs: ~{~A~^, ~}~%" (class-initargs class-obj))
    (values ctor-name required optional)))