;;; FOL Compiler Tests - Persistent Object System
;;;
;;; Tests for the Sycamore hash-map backed persistent object system.

(in-package :fol.compiler.tests)

(in-suite persistence-tests)

;;; ---------------------------------------------------------------------------
;;; Test class definitions
;;; ---------------------------------------------------------------------------

(defclass <test-point> (fol.compiler.persistent:<persistent-object>)
  ((x :initarg :x)
   (y :initarg :y))
  (:metaclass fol.compiler.persistent:persistent-class))

(defclass <test-person> (fol.compiler.persistent:<persistent-object>)
  ((name :initarg :name)
   (age :initarg :age)
   (email :initarg :email))
  (:metaclass fol.compiler.persistent:persistent-class))

(defclass <test-defaults> (fol.compiler.persistent:<persistent-object>)
  ((value :initarg :value :initform 42)
   (label :initarg :label :initform "default"))
  (:metaclass fol.compiler.persistent:persistent-class))

;;; ---------------------------------------------------------------------------
;;; Class existence and metaclass
;;; ---------------------------------------------------------------------------

(test persistent-class-metaclass-exists
  "persistent-class metaclass is defined."
  (is (find-class 'fol.compiler.persistent:persistent-class)))

(test persistent-object-base-class-exists
  "<persistent-object> base class is defined."
  (is (find-class 'fol.compiler.persistent:<persistent-object>)))

(test persistent-object-uses-persistent-metaclass
  "<persistent-object> uses persistent-class metaclass."
  (is (eq (class-of (find-class 'fol.compiler.persistent:<persistent-object>))
          (find-class 'fol.compiler.persistent:persistent-class))))

;;; ---------------------------------------------------------------------------
;;; Construction
;;; ---------------------------------------------------------------------------

(test persistent-object-construction
  "Persistent objects can be created with make-instance."
  (let ((p (make-instance '<test-point> :x 1 :y 2)))
    (is (typep p '<test-point>))
    (is (typep p 'fol.compiler.persistent:<persistent-object>))))

(test persistent-object-slot-access
  "Slot values can be read with slot-value."
  (let ((p (make-instance '<test-point> :x 10 :y 20)))
    (is (eql 10 (slot-value p 'x)))
    (is (eql 20 (slot-value p 'y)))))

(test persistent-object-three-slots
  "Objects with three slots work."
  (let ((person (make-instance '<test-person> :name "Alice" :age 30 :email "alice@test.com")))
    (is (string= "Alice" (slot-value person 'name)))
    (is (eql 30 (slot-value person 'age)))
    (is (string= "alice@test.com" (slot-value person 'email)))))

;;; ---------------------------------------------------------------------------
;;; Initforms (defaults)
;;; ---------------------------------------------------------------------------

(test persistent-object-initform-defaults
  "Initforms provide default values."
  (let ((d (make-instance '<test-defaults>)))
    (is (eql 42 (slot-value d 'value)))
    (is (string= "default" (slot-value d 'label)))))

(test persistent-object-initform-override
  "Initargs override initform defaults."
  (let ((d (make-instance '<test-defaults> :value 99 :label "custom")))
    (is (eql 99 (slot-value d 'value)))
    (is (string= "custom" (slot-value d 'label)))))

(test persistent-object-partial-override
  "Some initargs override while others use defaults."
  (let ((d (make-instance '<test-defaults> :value 77)))
    (is (eql 77 (slot-value d 'value)))
    (is (string= "default" (slot-value d 'label)))))

;;; ---------------------------------------------------------------------------
;;; Immutability
;;; ---------------------------------------------------------------------------

(test persistent-object-immutable
  "Slot mutation after initialization signals an error."
  (let ((p (make-instance '<test-point> :x 1 :y 2)))
    (signals error
      (setf (slot-value p 'x) 99))))

(test persistent-object-slot-makunbound-error
  "slot-makunbound signals an error on persistent objects."
  (let ((p (make-instance '<test-point> :x 1 :y 2)))
    (signals error
      (slot-makunbound p 'x))))

;;; ---------------------------------------------------------------------------
;;; Slot-boundp
;;; ---------------------------------------------------------------------------

(test persistent-object-slot-boundp
  "slot-boundp returns T for initialized slots."
  (let ((p (make-instance '<test-point> :x 1 :y 2)))
    (is (eq t (slot-boundp p 'x)))
    (is (eq t (slot-boundp p 'y)))))

(test persistent-object-slot-boundp-default
  "slot-boundp returns T for slots with initforms."
  (let ((d (make-instance '<test-defaults>)))
    (is (eq t (slot-boundp d 'value)))
    (is (eq t (slot-boundp d 'label)))))

;;; ---------------------------------------------------------------------------
;;; Functional update - update-slot
;;; ---------------------------------------------------------------------------

(test persistent-update-slot
  "update-slot returns a new object with one slot changed."
  (let* ((p1 (make-instance '<test-point> :x 1 :y 2))
         (p2 (fol.compiler.persistent:update-slot p1 'x 10)))
    (is (eql 10 (slot-value p2 'x)))
    (is (eql 2 (slot-value p2 'y)))))

(test persistent-update-slot-original-unchanged
  "update-slot does not modify the original object."
  (let* ((p1 (make-instance '<test-point> :x 1 :y 2))
         (p2 (fol.compiler.persistent:update-slot p1 'x 10)))
    (declare (ignore p2))
    (is (eql 1 (slot-value p1 'x)))
    (is (eql 2 (slot-value p1 'y)))))

(test persistent-update-slot-same-type
  "update-slot returns an object of the same class."
  (let* ((p1 (make-instance '<test-point> :x 1 :y 2))
         (p2 (fol.compiler.persistent:update-slot p1 'x 10)))
    (is (eq (class-of p1) (class-of p2)))))

(test persistent-update-slot-chained
  "Multiple update-slot calls can be chained."
  (let* ((p1 (make-instance '<test-point> :x 1 :y 2))
         (p2 (fol.compiler.persistent:update-slot p1 'x 10))
         (p3 (fol.compiler.persistent:update-slot p2 'y 20)))
    (is (eql 10 (slot-value p3 'x)))
    (is (eql 20 (slot-value p3 'y)))
    ;; Originals unchanged
    (is (eql 1 (slot-value p1 'x)))
    (is (eql 2 (slot-value p1 'y)))))

;;; ---------------------------------------------------------------------------
;;; Functional update - update-slots
;;; ---------------------------------------------------------------------------

(test persistent-update-slots
  "update-slots updates multiple slots at once."
  (let* ((p1 (make-instance '<test-point> :x 1 :y 2))
         (p2 (fol.compiler.persistent:update-slots p1 'x 100 'y 200)))
    (is (eql 100 (slot-value p2 'x)))
    (is (eql 200 (slot-value p2 'y)))))

(test persistent-update-slots-original-unchanged
  "update-slots does not modify the original object."
  (let* ((p1 (make-instance '<test-point> :x 1 :y 2))
         (p2 (fol.compiler.persistent:update-slots p1 'x 100 'y 200)))
    (declare (ignore p2))
    (is (eql 1 (slot-value p1 'x)))
    (is (eql 2 (slot-value p1 'y)))))

(test persistent-update-slots-partial
  "update-slots with partial update preserves other slots."
  (let* ((person (make-instance '<test-person> :name "Alice" :age 30 :email "a@b.com"))
         (updated (fol.compiler.persistent:update-slots person 'age 31)))
    (is (string= "Alice" (slot-value updated 'name)))
    (is (eql 31 (slot-value updated 'age)))
    (is (string= "a@b.com" (slot-value updated 'email)))))

;;; ---------------------------------------------------------------------------
;;; Storage backing (Sycamore hash-map)
;;; ---------------------------------------------------------------------------

(test persistent-storage-is-sycamore-hash-map
  "Internal storage is a Sycamore hash-map."
  (let* ((p (make-instance '<test-point> :x 1 :y 2))
         (storage (fol.compiler.persistent::%persistent-storage p)))
    ;; Sycamore hash-map-find should work on the storage
    (multiple-value-bind (val found)
        (sycamore:hash-map-find storage :x)
      (is (eq t found))
      (is (eql 1 val)))))

(test persistent-storage-keyword-keys
  "Storage uses keyword symbols as keys."
  (let* ((p (make-instance '<test-point> :x 1 :y 2))
         (storage (fol.compiler.persistent::%persistent-storage p)))
    (multiple-value-bind (val-x found-x)
        (sycamore:hash-map-find storage :x)
      (is (eq t found-x))
      (is (eql 1 val-x)))
    (multiple-value-bind (val-y found-y)
        (sycamore:hash-map-find storage :y)
      (is (eq t found-y))
      (is (eql 2 val-y)))))

;;; ---------------------------------------------------------------------------
;;; Validate-superclass
;;; ---------------------------------------------------------------------------

(test persistent-validate-superclass-standard
  "persistent-class can have standard-class as superclass."
  (is (closer-mop:validate-superclass
       (find-class 'fol.compiler.persistent:persistent-class)
       (find-class 'standard-class))))

(test persistent-validate-superclass-persistent
  "persistent-class can have persistent-class as superclass."
  (is (closer-mop:validate-superclass
       (find-class 'fol.compiler.persistent:persistent-class)
       (find-class 'fol.compiler.persistent:persistent-class))))

(test standard-can-inherit-persistent
  "standard-class can have persistent-class as superclass."
  (is (closer-mop:validate-superclass
       (find-class 'standard-class)
       (find-class 'fol.compiler.persistent:persistent-class))))
