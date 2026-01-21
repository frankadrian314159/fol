(in-package fol.tests)

(in-suite fol-suite)

;;; ============================================================================
;;; MOP Tests
;;; ============================================================================
;;; Tests for the FOL Metaobject Protocol

;;; Define some test classes for MOP testing
(defclass <test-base> (<persistent-object>)
  ((base-slot :initarg :base-slot :accessor base-slot :initform nil))
  (:metaclass persistent-class)
  (:documentation "Base test class for MOP testing."))

(defclass <test-derived> (<test-base>)
  ((derived-slot :initarg :derived-slot :accessor derived-slot :initform 0 :type integer)
   (another-slot :initarg :another-slot :reader another-slot :initform "default"))
  (:metaclass persistent-class)
  (:documentation "Derived test class for MOP testing."))

(defclass <test-multi-inherit> (<symbol> <test-derived>)
  ((multi-slot :initarg :multi-slot :accessor multi-slot))
  (:metaclass persistent-class)
  (:documentation "Test class with multiple inheritance."))

(defclass <test-no-slots> (<persistent-object>)
  ()
  (:metaclass persistent-class)
  (:documentation "Test class with no direct slots."))

(defclass <test-class-slot> (<persistent-object>)
  ((instance-slot :initarg :instance-slot :allocation :instance :initform nil)
   (class-slot :initarg :class-slot :allocation :class :initform :shared))
  (:metaclass persistent-class)
  (:documentation "Test class with class-allocated slot."))

;; Ensure all test classes are finalized before tests run
;; Use eval-when to ensure this happens at load time
(eval-when (:load-toplevel :execute)
  (ensure-finalized '<test-base>)
  (ensure-finalized '<test-derived>)
  (ensure-finalized '<test-multi-inherit>)
  (ensure-finalized '<test-no-slots>)
  (ensure-finalized '<test-class-slot>))

;;; ============================================================================
;;; Class Introspection Tests
;;; ============================================================================

(test mop-class-name
  "Test class-name* function"
  ;; Test with class object
  (is (eq '<test-base> (class-name* (find-class '<test-base>))))
  (is (eq '<test-derived> (class-name* (find-class '<test-derived>))))

  ;; Test with symbol
  (is (eq '<test-base> (class-name* '<test-base>)))
  (is (eq '<symbol> (class-name* '<symbol>))))

(test mop-class-name-standard-class
  "Test class-name* with standard classes"
  (is (eq 'standard-object (class-name* (find-class 'standard-object)))))

(test mop-class-superclasses
  "Test class-direct-superclasses* function"
  ;; <test-base> has <persistent-object> as direct superclass
  (let ((supers (class-direct-superclasses* '<test-base>)))
    (is (= 1 (length supers)))
    (is (eq '<persistent-object>
            (class-name* (first supers)))))

  ;; <test-derived> has <test-base> as direct superclass
  (let ((supers (class-direct-superclasses* '<test-derived>)))
    (is (= 1 (length supers)))
    (is (eq '<test-base> (class-name* (first supers)))))

  ;; <test-multi-inherit> has two direct superclasses
  (let ((supers (class-direct-superclasses* '<test-multi-inherit>)))
    (is (= 2 (length supers)))
    (is (member '<test-derived> (mapcar #'class-name* supers)))
    (is (member '<symbol> (mapcar #'class-name* supers)))))

(test mop-class-subclasses
  "Test class-direct-subclasses* function"
  ;; <test-base> should have <test-derived> as a direct subclass
  (let ((subs (class-direct-subclasses* '<test-base>)))
    (is (member (find-class '<test-derived>) subs))))

(test mop-class-precedence-list
  "Test class-precedence-list* function"
  ;; Get precedence list for <test-derived>
  (let ((cpl (class-precedence-list* '<test-derived>)))
    ;; Should include itself, <test-base>, <persistent-object>, etc.
    (is (member '<test-derived> (mapcar #'class-name* cpl)))
    (is (member '<test-base> (mapcar #'class-name* cpl)))
    (is (member '<persistent-object> (mapcar #'class-name* cpl)))
    ;; <test-derived> should come before <test-base>
    (is (< (position '<test-derived> (mapcar #'class-name* cpl))
           (position '<test-base> (mapcar #'class-name* cpl))))))

(test mop-class-precedence-list-multi-inherit
  "Test class-precedence-list* with multiple inheritance"
  (let ((cpl (class-precedence-list* '<test-multi-inherit>)))
    ;; Should include all classes in the hierarchy
    (is (member '<test-multi-inherit> (mapcar #'class-name* cpl)))
    (is (member '<test-derived> (mapcar #'class-name* cpl)))
    (is (member '<test-base> (mapcar #'class-name* cpl)))
    (is (member '<symbol> (mapcar #'class-name* cpl)))))

(test mop-class-slots
  "Test class-direct-slots* and class-slots* functions"
  ;; Direct slots of <test-base>
  (let ((direct-slots (class-direct-slots* '<test-base>)))
    (is (= 1 (length direct-slots)))
    (is (eq 'base-slot (slot-definition-name* (first direct-slots)))))

  ;; Direct slots of <test-derived>
  (let ((direct-slots (class-direct-slots* '<test-derived>)))
    (is (= 2 (length direct-slots)))
    (let ((names (mapcar #'slot-definition-name* direct-slots)))
      (is (member 'derived-slot names))
      (is (member 'another-slot names))))

  ;; All slots of <test-derived> (includes inherited)
  (let ((all-slots (class-slots* '<test-derived>)))
    (let ((names (mapcar #'slot-definition-name* all-slots)))
      (is (member 'base-slot names))      ; inherited
      (is (member 'derived-slot names))   ; direct
      (is (member 'another-slot names))))) ; direct

(test mop-class-no-direct-slots
  "Test class with no direct slots"
  (let ((direct-slots (class-direct-slots* '<test-no-slots>)))
    (is (= 0 (length direct-slots))))
  ;; But should still have inherited slots
  (let ((all-slots (class-slots* '<test-no-slots>)))
    ;; Should have at least %persistent-storage from <persistent-object>
    (is (>= (length all-slots) 1))))

(test mop-finalized
  "Test finalized-p and ensure-finalized functions"
  ;; Classes should be finalized after being used
  (is (finalized-p '<test-base>))
  (is (finalized-p '<test-derived>))

  ;; ensure-finalized should return the class
  (is (eq (find-class '<test-base>)
          (ensure-finalized '<test-base>))))

;;; ============================================================================
;;; Slot Definition Introspection Tests
;;; ============================================================================

(test mop-slot-definition-properties
  "Test slot definition property accessors"
  (let* ((slot-def (find-slot-definition '<test-derived> 'derived-slot))
         ;; Get direct slot for readers/writers
         (direct-slot (find 'derived-slot (class-direct-slots* '<test-derived>)
                           :key #'slot-definition-name*)))
    ;; Name
    (is (eq 'derived-slot (slot-definition-name* slot-def)))

    ;; Type
    (is (eq 'integer (slot-definition-type* slot-def)))

    ;; Initargs
    (is (member :derived-slot (slot-definition-initargs* slot-def)))

    ;; Initform
    (is (equal 0 (slot-definition-initform* slot-def)))

    ;; Initfunction (should be non-nil)
    (is (functionp (slot-definition-initfunction* slot-def)))

    ;; Allocation (should be :instance)
    (is (eq :instance (slot-definition-allocation* slot-def)))

    ;; Readers/Writers (from direct slot)
    (is (member 'derived-slot (slot-definition-readers* direct-slot)))
    (is (member '(setf derived-slot) (slot-definition-writers* direct-slot)
                :test #'equal))))

(test mop-slot-definition-readers-writers
  "Test slot definition readers and writers"
  ;; another-slot has only a reader, no writer
  ;; Use direct slot definition to get readers/writers
  (let ((slot-def (find 'another-slot (class-direct-slots* '<test-derived>)
                        :key #'slot-definition-name*)))
    (is (member 'another-slot (slot-definition-readers* slot-def)))
    (is (null (slot-definition-writers* slot-def)))))

(test mop-slot-definition-allocation
  "Test slot definition allocation types"
  (let ((instance-slot (find-slot-definition '<test-class-slot> 'instance-slot))
        (class-slot (find-slot-definition '<test-class-slot> 'class-slot)))
    (is (eq :instance (slot-definition-allocation* instance-slot)))
    (is (eq :class (slot-definition-allocation* class-slot)))))

;;; ============================================================================
;;; Instance Introspection Tests
;;; ============================================================================

(test mop-instance-class
  "Test instance-class function"
  (let ((obj (make-instance '<test-base> :base-slot 42)))
    (is (eq (find-class '<test-base>) (instance-class obj)))))

(test mop-instance-slots
  "Test instance-slots function"
  (let* ((obj (make-instance '<test-derived>))
         (slots (instance-slots obj))
         (names (mapcar #'slot-definition-name* slots)))
    (is (member 'base-slot names))
    (is (member 'derived-slot names))
    (is (member 'another-slot names))))

(test mop-slot-names
  "Test slot-names function"
  ;; With class
  (let ((names (slot-names '<test-derived>)))
    (is (member 'base-slot names))
    (is (member 'derived-slot names))
    (is (member 'another-slot names)))

  ;; With class symbol
  (let ((names (slot-names '<test-base>)))
    (is (member 'base-slot names)))

  ;; With instance
  (let* ((obj (make-instance '<test-derived>))
         (names (slot-names obj)))
    (is (member 'base-slot names))
    (is (member 'derived-slot names))))

(test mop-slot-exists
  "Test slot-exists-p* function"
  ;; With class
  (is (slot-exists-p* '<test-derived> 'derived-slot))
  (is (slot-exists-p* '<test-derived> 'base-slot))
  (is (cl:not (slot-exists-p* '<test-derived> 'nonexistent-slot)))

  ;; With instance
  (let ((obj (make-instance '<test-derived>)))
    (is (slot-exists-p* obj 'derived-slot))
    (is (slot-exists-p* obj 'base-slot))
    (is (cl:not (slot-exists-p* obj 'nonexistent-slot)))))

(test mop-slot-boundp-value
  "Test slot-boundp* and slot-value* functions"
  (let ((obj (make-instance '<test-derived> :derived-slot 123)))
    ;; Bound slot
    (is (slot-boundp* obj 'derived-slot))
    (is (= 123 (slot-value* obj 'derived-slot)))

    ;; Slot with initform
    (is (slot-boundp* obj 'another-slot))
    (is (equal "default" (slot-value* obj 'another-slot)))))

;;; ============================================================================
;;; Utility Function Tests
;;; ============================================================================

(test mop-all-persistent-classes
  "Test all-persistent-classes function"
  (let ((all-classes (all-persistent-classes)))
    ;; Should include our test classes
    (is (member (find-class '<test-base>) all-classes))
    (is (member (find-class '<test-derived>) all-classes))
    (is (member (find-class '<symbol>) all-classes))
    ;; All should be persistent-classes
    (is (every #'persistent-class-p all-classes))))

(test mop-subclasses
  "Test subclasses* function"
  ;; Direct subclasses of <test-base>
  (let ((direct (subclasses* '<test-base> :direct-only t)))
    (is (member (find-class '<test-derived>) direct)))

  ;; All subclasses of <test-base>
  (let ((all (subclasses* '<test-base>)))
    (is (member (find-class '<test-derived>) all))
    (is (member (find-class '<test-multi-inherit>) all))))

(test mop-superclasses
  "Test superclasses* function"
  ;; Direct superclasses of <test-derived>
  (let ((direct (superclasses* '<test-derived> :direct-only t)))
    (is (= 1 (length direct)))
    (is (eq (find-class '<test-base>) (first direct))))

  ;; All superclasses of <test-derived>
  (let ((all (superclasses* '<test-derived>)))
    (is (member (find-class '<test-base>) all))
    (is (member (find-class '<persistent-object>) all))))

(test mop-find-slot-definition
  "Test find-slot-definition function"
  ;; Find existing slot
  (let ((slot-def (find-slot-definition '<test-derived> 'derived-slot)))
    (is (cl:not (null slot-def)))
    (is (eq 'derived-slot (slot-definition-name* slot-def))))

  ;; Find inherited slot
  (let ((slot-def (find-slot-definition '<test-derived> 'base-slot)))
    (is (cl:not (null slot-def)))
    (is (eq 'base-slot (slot-definition-name* slot-def))))

  ;; Non-existent slot
  (is (null (find-slot-definition '<test-derived> 'nonexistent))))

(test mop-slot-properties
  "Test slot-properties function"
  (let ((props (slot-properties '<test-derived> 'derived-slot)))
    (is (eq 'derived-slot (getf props :name)))
    (is (eq 'integer (getf props :type)))
    (is (eq :instance (getf props :allocation)))
    (is (member :derived-slot (getf props :initargs)))
    (is (equal 0 (getf props :initform)))
    (is (member 'derived-slot (getf props :readers)))
    (is (member '(setf derived-slot) (getf props :writers) :test #'equal))))

(test mop-slot-properties-not-found
  "Test slot-properties returns nil for non-existent slot"
  (is (null (slot-properties '<test-derived> 'nonexistent-slot))))

(test mop-class-info
  "Test class-info function"
  (let ((info (class-info '<test-derived>)))
    (is (eq '<test-derived> (getf info :name)))
    (is (member '<test-base> (getf info :direct-superclasses)))
    (is (member '<test-base> (getf info :precedence-list)))
    (is (member 'derived-slot (getf info :direct-slots)))
    (is (member 'base-slot (getf info :all-slots)))
    (is (getf info :finalized))))

(test mop-class-info-complete
  "Test that class-info returns all expected keys"
  (let ((info (class-info '<test-base>)))
    (is (cl:not (null (getf info :name))))
    (is (listp (getf info :direct-superclasses)))
    (is (listp (getf info :direct-subclasses)))
    (is (listp (getf info :precedence-list)))
    (is (listp (getf info :direct-slots)))
    (is (listp (getf info :all-slots)))
    (is (cl:not (null (getf info :finalized))))))

(test mop-persistent-class-p
  "Test persistent-class-p predicate"
  ;; With class objects
  (is (persistent-class-p (find-class '<test-base>)))
  (is (persistent-class-p (find-class '<symbol>)))
  (is (persistent-class-p (find-class '<persistent-object>)))

  ;; With symbols
  (is (persistent-class-p '<test-base>))
  (is (persistent-class-p '<symbol>))

  ;; Non-persistent classes
  (is (cl:not (persistent-class-p 'standard-object))))

(test mop-persistent-class-p-nil
  "Test persistent-class-p with nil and invalid symbols"
  (is (cl:not (persistent-class-p nil)))
  (is (cl:not (persistent-class-p 'nonexistent-class-symbol-12345))))

(test mop-persistent-object-p
  "Test persistent-object-p predicate"
  ;; Persistent objects
  (is (persistent-object-p (make-instance '<test-base>)))
  (is (persistent-object-p (make-instance '<test-derived>)))
  (is (persistent-object-p (wrap 'foo)))
  (is (persistent-object-p (wrap t)))  ; wrapped bool is persistent

  ;; Non-persistent objects (raw CL values are NOT persistent)
  (is (cl:not (persistent-object-p t)))      ; raw boolean
  (is (cl:not (persistent-object-p 42)))     ; raw number
  (is (cl:not (persistent-object-p "string"))) ; raw string
  (is (cl:not (persistent-object-p 'symbol)))  ; raw symbol
  )

(test mop-persistent-object-p-various-types
  "Test persistent-object-p with various types"
  ;; FOL wrapped values
  (is (persistent-object-p (wrap t)))
  (is (persistent-object-p (wrap #\a)))
  (is (persistent-object-p (wrap 42)))
  (is (persistent-object-p (wrap 3.14)))
  (is (persistent-object-p (wrap "hello")))
  (is (persistent-object-p (wrap 'symbol)))
  ;; Raw CL values are not persistent objects
  (is (cl:not (persistent-object-p #\a)))
  (is (cl:not (persistent-object-p 3.14)))
  (is (cl:not (persistent-object-p '(1 2 3)))))

(test mop-describe-functions
  "Test describe-class and describe-slot functions"
  ;; These mainly test that they don't error
  ;; Actual output would go to a stream
  (is (eq (find-class '<test-base>)
          (describe-class '<test-base> nil)))

  (is (cl:not (null (describe-slot '<test-derived> 'derived-slot nil)))))

(test mop-describe-class-output
  "Test describe-class produces output"
  (let ((output (with-output-to-string (s)
                  (describe-class '<test-base> s))))
    (is (> (length output) 0))
    (is (search "<TEST-BASE>" output))))

(test mop-describe-slot-output
  "Test describe-slot produces output"
  (let ((output (with-output-to-string (s)
                  (describe-slot '<test-derived> 'derived-slot s))))
    (is (> (length output) 0))
    (is (search "DERIVED-SLOT" output))))

(test mop-describe-slot-not-found
  "Test describe-slot with non-existent slot"
  (let ((result (describe-slot '<test-derived> 'nonexistent nil)))
    (is (null result))))

;;; ============================================================================
;;; FOL Value Class MOP Tests
;;; ============================================================================

(test mop-fol-value-classes
  "Test MOP introspection on FOL value classes"
  ;; <bool> is a persistent class
  (is (persistent-class-p '<bool>))
  (is (persistent-class-p '<char>))
  (is (persistent-class-p '<number>))
  (is (persistent-class-p '<string>))
  (is (persistent-class-p '<symbol>)))

(test mop-fol-number-hierarchy
  "Test MOP introspection on FOL number class hierarchy"
  (let ((cpl (class-precedence-list* '<integer>)))
    (is (member '<integer> (mapcar #'class-name* cpl)))
    (is (member '<rational> (mapcar #'class-name* cpl)))
    (is (member '<real> (mapcar #'class-name* cpl)))
    (is (member '<number> (mapcar #'class-name* cpl)))
    (is (member '<persistent-object> (mapcar #'class-name* cpl)))))

(test mop-fol-value-slot
  "Test MOP introspection on FOL value class slots"
  ;; <number> has a 'val' slot
  (is (slot-exists-p* '<number> 'val))
  (let ((slot-def (find-slot-definition '<number> 'val)))
    (is (cl:not (null slot-def)))
    (is (eq 'val (slot-definition-name* slot-def)))))

;;; ============================================================================
;;; Edge Cases and Error Handling
;;; ============================================================================

(test mop-class-operations-with-symbol
  "Test that all class operations work with symbols"
  ;; All these should work with symbol instead of class object
  (is (eq '<test-base> (class-name* '<test-base>)))
  (is (listp (class-direct-superclasses* '<test-base>)))
  (is (listp (class-direct-subclasses* '<test-base>)))
  (is (listp (class-precedence-list* '<test-base>)))
  (is (listp (class-direct-slots* '<test-base>)))
  (is (listp (class-slots* '<test-base>)))
  (is (finalized-p '<test-base>))
  (is (eq (find-class '<test-base>) (ensure-finalized '<test-base>))))

(test mop-slot-operations-with-instance
  "Test slot operations work with both class and instance"
  (let ((obj (make-instance '<test-derived> :derived-slot 42)))
    ;; slot-names works with instance
    (is (member 'derived-slot (slot-names obj)))
    ;; slot-exists-p* works with instance
    (is (slot-exists-p* obj 'derived-slot))
    ;; slot-properties works with instance
    (is (cl:not (null (slot-properties obj 'derived-slot))))))
