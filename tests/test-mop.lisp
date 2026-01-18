(in-package fol.tests)
(in-readtable fol-syntax)

(in-suite fol-suite)

;;; ============================================================================
;;; MOP Tests
;;; ============================================================================
;;; Tests for the FOL Metaobject Protocol

;;; Define some test classes for MOP testing
(defclass <test-base> (fol.persistent:<persistent-object>)
  ((base-slot :initarg :base-slot :accessor base-slot :initform nil))
  (:metaclass fol.persistent:persistent-class)
  (:documentation "Base test class for MOP testing."))

(defclass <test-derived> (<test-base>)
  ((derived-slot :initarg :derived-slot :accessor derived-slot :initform 0 :type integer)
   (another-slot :initarg :another-slot :reader another-slot :initform "default"))
  (:metaclass fol.persistent:persistent-class)
  (:documentation "Derived test class for MOP testing."))

(defclass <test-multi-inherit> (<test-derived> <symbol>)
  ((multi-slot :initarg :multi-slot :accessor multi-slot))
  (:metaclass fol.persistent:persistent-class)
  (:documentation "Test class with multiple inheritance."))

;; Ensure all test classes are finalized before tests run
;; Use eval-when to ensure this happens at load time
(eval-when (:load-toplevel :execute)
  (fol.mop:ensure-finalized '<test-base>)
  (fol.mop:ensure-finalized '<test-derived>)
  (fol.mop:ensure-finalized '<test-multi-inherit>))

;;; ============================================================================
;;; Class Introspection Tests
;;; ============================================================================

(test mop-class-name
  "Test class-name* function"
  ;; Test with class object
  (is (eq '<test-base> (fol.mop:class-name* (find-class '<test-base>))))
  (is (eq '<test-derived> (fol.mop:class-name* (find-class '<test-derived>))))
  
  ;; Test with symbol
  (is (eq '<test-base> (fol.mop:class-name* '<test-base>)))
  (is (eq '<symbol> (fol.mop:class-name* '<symbol>))))

(test mop-class-superclasses
  "Test class-direct-superclasses* function"
  ;; <test-base> has <persistent-object> as direct superclass
  (let ((supers (fol.mop:class-direct-superclasses* '<test-base>)))
    (is (= 1 (length supers)))
    (is (eq 'fol.persistent:<persistent-object> 
            (fol.mop:class-name* (first supers)))))
  
  ;; <test-derived> has <test-base> as direct superclass
  (let ((supers (fol.mop:class-direct-superclasses* '<test-derived>)))
    (is (= 1 (length supers)))
    (is (eq '<test-base> (fol.mop:class-name* (first supers)))))
  
  ;; <test-multi-inherit> has two direct superclasses
  (let ((supers (fol.mop:class-direct-superclasses* '<test-multi-inherit>)))
    (is (= 2 (length supers)))
    (is (member '<test-derived> (mapcar #'fol.mop:class-name* supers)))
    (is (member '<symbol> (mapcar #'fol.mop:class-name* supers)))))

(test mop-class-precedence-list
  "Test class-precedence-list* function"
  ;; Get precedence list for <test-derived>
  (let ((cpl (fol.mop:class-precedence-list* '<test-derived>)))
    ;; Should include itself, <test-base>, <persistent-object>, etc.
    (is (member '<test-derived> (mapcar #'fol.mop:class-name* cpl)))
    (is (member '<test-base> (mapcar #'fol.mop:class-name* cpl)))
    (is (member 'fol.persistent:<persistent-object> (mapcar #'fol.mop:class-name* cpl)))
    ;; <test-derived> should come before <test-base>
    (is (< (position '<test-derived> (mapcar #'fol.mop:class-name* cpl))
           (position '<test-base> (mapcar #'fol.mop:class-name* cpl))))))

(test mop-class-slots
  "Test class-direct-slots* and class-slots* functions"
  ;; Direct slots of <test-base>
  (let ((direct-slots (fol.mop:class-direct-slots* '<test-base>)))
    (is (= 1 (length direct-slots)))
    (is (eq 'base-slot (fol.mop:slot-definition-name* (first direct-slots)))))
  
  ;; Direct slots of <test-derived>
  (let ((direct-slots (fol.mop:class-direct-slots* '<test-derived>)))
    (is (= 2 (length direct-slots)))
    (let ((names (mapcar #'fol.mop:slot-definition-name* direct-slots)))
      (is (member 'derived-slot names))
      (is (member 'another-slot names))))
  
  ;; All slots of <test-derived> (includes inherited)
  (let ((all-slots (fol.mop:class-slots* '<test-derived>)))
    (let ((names (mapcar #'fol.mop:slot-definition-name* all-slots)))
      (is (member 'base-slot names))      ; inherited
      (is (member 'derived-slot names))   ; direct
      (is (member 'another-slot names))))) ; direct

(test mop-finalized
  "Test finalized-p and ensure-finalized functions"
  ;; Classes should be finalized after being used
  (is (fol.mop:finalized-p '<test-base>))
  (is (fol.mop:finalized-p '<test-derived>))
  
  ;; ensure-finalized should return the class
  (is (eq (find-class '<test-base>)
          (fol.mop:ensure-finalized '<test-base>))))

;;; ============================================================================
;;; Slot Definition Introspection Tests
;;; ============================================================================

(test mop-slot-definition-properties
  "Test slot definition property accessors"
  (let* ((slot-def (fol.mop:find-slot-definition '<test-derived> 'derived-slot))
         ;; Get direct slot for readers/writers
         (direct-slot (find 'derived-slot (fol.mop:class-direct-slots* '<test-derived>)
                           :key #'fol.mop:slot-definition-name*)))
    ;; Name
    (is (eq 'derived-slot (fol.mop:slot-definition-name* slot-def)))
    
    ;; Type
    (is (eq 'integer (fol.mop:slot-definition-type* slot-def)))
    
    ;; Initargs
    (is (member :derived-slot (fol.mop:slot-definition-initargs* slot-def)))
    
    ;; Initform
    (is (equal 0 (fol.mop:slot-definition-initform* slot-def)))
    
    ;; Initfunction (should be non-nil)
    (is (functionp (fol.mop:slot-definition-initfunction* slot-def)))
    
    ;; Allocation (should be :instance)
    (is (eq :instance (fol.mop:slot-definition-allocation* slot-def)))
    
    ;; Readers/Writers (from direct slot)
    (is (member 'derived-slot (fol.mop:slot-definition-readers* direct-slot)))
    (is (member '(setf derived-slot) (fol.mop:slot-definition-writers* direct-slot)
                :test #'equal))))

(test mop-slot-definition-readers-writers
  "Test slot definition readers and writers"
  ;; another-slot has only a reader, no writer
  ;; Use direct slot definition to get readers/writers
  (let ((slot-def (find 'another-slot (fol.mop:class-direct-slots* '<test-derived>)
                        :key #'fol.mop:slot-definition-name*)))
    (is (member 'another-slot (fol.mop:slot-definition-readers* slot-def)))
    (is (null (fol.mop:slot-definition-writers* slot-def)))))

;;; ============================================================================
;;; Instance Introspection Tests
;;; ============================================================================

(test mop-instance-class
  "Test instance-class function"
  (let ((obj (make-instance '<test-base> :base-slot 42)))
    (is (eq (find-class '<test-base>) (fol.mop:instance-class obj)))))

(test mop-instance-slots
  "Test instance-slots function"
  (let* ((obj (make-instance '<test-derived>))
         (slots (fol.mop:instance-slots obj))
         (names (mapcar #'fol.mop:slot-definition-name* slots)))
    (is (member 'base-slot names))
    (is (member 'derived-slot names))
    (is (member 'another-slot names))))

(test mop-slot-names
  "Test slot-names function"
  ;; With class
  (let ((names (fol.mop:slot-names '<test-derived>)))
    (is (member 'base-slot names))
    (is (member 'derived-slot names))
    (is (member 'another-slot names)))
  
  ;; With class symbol
  (let ((names (fol.mop:slot-names '<test-base>)))
    (is (member 'base-slot names)))
  
  ;; With instance
  (let* ((obj (make-instance '<test-derived>))
         (names (fol.mop:slot-names obj)))
    (is (member 'base-slot names))
    (is (member 'derived-slot names))))

(test mop-slot-exists
  "Test slot-exists-p* function"
  ;; With class
  (is (fol.mop:slot-exists-p* '<test-derived> 'derived-slot))
  (is (fol.mop:slot-exists-p* '<test-derived> 'base-slot))
  (is (not (fol.mop:slot-exists-p* '<test-derived> 'nonexistent-slot)))
  
  ;; With instance
  (let ((obj (make-instance '<test-derived>)))
    (is (fol.mop:slot-exists-p* obj 'derived-slot))
    (is (fol.mop:slot-exists-p* obj 'base-slot))
    (is (not (fol.mop:slot-exists-p* obj 'nonexistent-slot)))))

(test mop-slot-boundp-value
  "Test slot-boundp* and slot-value* functions"
  (let ((obj (make-instance '<test-derived> :derived-slot 123)))
    ;; Bound slot
    (is (fol.mop:slot-boundp* obj 'derived-slot))
    (is (= 123 (fol.mop:slot-value* obj 'derived-slot)))
    
    ;; Slot with initform
    (is (fol.mop:slot-boundp* obj 'another-slot))
    (is (equal "default" (fol.mop:slot-value* obj 'another-slot)))))

;;; ============================================================================
;;; Utility Function Tests
;;; ============================================================================

(test mop-all-persistent-classes
  "Test all-persistent-classes function"
  (let ((all-classes (fol.mop:all-persistent-classes)))
    ;; Should include our test classes
    (is (member (find-class '<test-base>) all-classes))
    (is (member (find-class '<test-derived>) all-classes))
    (is (member (find-class '<symbol>) all-classes))
    ;; All should be persistent-classes
    (is (every #'fol.mop:persistent-class-p all-classes))))

(test mop-subclasses
  "Test subclasses* function"
  ;; Direct subclasses of <test-base>
  (let ((direct (fol.mop:subclasses* '<test-base> :direct-only t)))
    (is (member (find-class '<test-derived>) direct)))
  
  ;; All subclasses of <test-base>
  (let ((all (fol.mop:subclasses* '<test-base>)))
    (is (member (find-class '<test-derived>) all))
    (is (member (find-class '<test-multi-inherit>) all))))

(test mop-superclasses
  "Test superclasses* function"
  ;; Direct superclasses of <test-derived>
  (let ((direct (fol.mop:superclasses* '<test-derived> :direct-only t)))
    (is (= 1 (length direct)))
    (is (eq (find-class '<test-base>) (first direct))))
  
  ;; All superclasses of <test-derived>
  (let ((all (fol.mop:superclasses* '<test-derived>)))
    (is (member (find-class '<test-base>) all))
    (is (member (find-class 'fol.persistent:<persistent-object>) all))))

(test mop-find-slot-definition
  "Test find-slot-definition function"
  ;; Find existing slot
  (let ((slot-def (fol.mop:find-slot-definition '<test-derived> 'derived-slot)))
    (is (not (null slot-def)))
    (is (eq 'derived-slot (fol.mop:slot-definition-name* slot-def))))
  
  ;; Find inherited slot
  (let ((slot-def (fol.mop:find-slot-definition '<test-derived> 'base-slot)))
    (is (not (null slot-def)))
    (is (eq 'base-slot (fol.mop:slot-definition-name* slot-def))))
  
  ;; Non-existent slot
  (is (null (fol.mop:find-slot-definition '<test-derived> 'nonexistent))))

(test mop-slot-properties
  "Test slot-properties function"
  (let ((props (fol.mop:slot-properties '<test-derived> 'derived-slot)))
    (is (eq 'derived-slot (getf props :name)))
    (is (eq 'integer (getf props :type)))
    (is (eq :instance (getf props :allocation)))
    (is (member :derived-slot (getf props :initargs)))
    (is (equal 0 (getf props :initform)))
    (is (member 'derived-slot (getf props :readers)))
    (is (member '(setf derived-slot) (getf props :writers) :test #'equal))))

(test mop-class-info
  "Test class-info function"
  (let ((info (fol.mop:class-info '<test-derived>)))
    (is (eq '<test-derived> (getf info :name)))
    (is (member '<test-base> (getf info :direct-superclasses)))
    (is (member '<test-base> (getf info :precedence-list)))
    (is (member 'derived-slot (getf info :direct-slots)))
    (is (member 'base-slot (getf info :all-slots)))
    (is (getf info :finalized))))

(test mop-persistent-class-p
  "Test persistent-class-p predicate"
  ;; With class objects
  (is (fol.mop:persistent-class-p (find-class '<test-base>)))
  (is (fol.mop:persistent-class-p (find-class '<symbol>)))
  (is (fol.mop:persistent-class-p (find-class 'fol.persistent:<persistent-object>)))
  
  ;; With symbols
  (is (fol.mop:persistent-class-p '<test-base>))
  (is (fol.mop:persistent-class-p '<symbol>))
  
  ;; Non-persistent classes
  (is (not (fol.mop:persistent-class-p 'standard-object))))

(test mop-persistent-object-p
  "Test persistent-object-p predicate"
  ;; Persistent objects
  (is (fol.mop:persistent-object-p (make-instance '<test-base>)))
  (is (fol.mop:persistent-object-p (make-instance '<test-derived>)))
  (is (fol.mop:persistent-object-p (wrap 'foo)))
  (is (fol.mop:persistent-object-p #t))
  
  ;; Non-persistent objects
  (is (not (fol.mop:persistent-object-p 42)))
  (is (not (fol.mop:persistent-object-p "string")))
  (is (not (fol.mop:persistent-object-p 'symbol))))

(test mop-describe-functions
  "Test describe-class and describe-slot functions"
  ;; These mainly test that they don't error
  ;; Actual output would go to a stream
  (is (eq (find-class '<test-base>)
          (fol.mop:describe-class '<test-base> nil)))
  
  (is (not (null (fol.mop:describe-slot '<test-derived> 'derived-slot nil)))))