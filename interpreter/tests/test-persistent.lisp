(in-package fol.tests)

(in-suite fol-suite)

;;; ============================================================================
;;; Example Classes for Testing
;;; ============================================================================

(defclass test-person (<persistent-object>)
  ((name :initarg :name :initform "Anonymous")
   (age :initarg :age :initform 0)  ; Native value, wrap in tests
   (active :initarg :active :initform t))  ; Native boolean, wrap in tests
  (:metaclass persistent-class)
  (:documentation "Test person with FOL-wrapped persistent slots."))

(defclass test-point (<persistent-object>)
  ((x :initarg :x :initform 0)  ; Native value, wrap in tests
   (y :initarg :y :initform 0))  ; Native value, wrap in tests
  (:metaclass persistent-class)
  (:documentation "Test 2D point with FOL-wrapped coordinates."))

(defclass test-empty (<persistent-object>)
  ()
  (:metaclass persistent-class)
  (:documentation "Test class with no slots."))

(defclass test-many-slots (<persistent-object>)
  ((slot-a :initarg :slot-a :initform nil)
   (slot-b :initarg :slot-b :initform nil)
   (slot-c :initarg :slot-c :initform nil)
   (slot-d :initarg :slot-d :initform nil)
   (slot-e :initarg :slot-e :initform nil))
  (:metaclass persistent-class)
  (:documentation "Test class with many slots."))

(defclass test-no-initforms (<persistent-object>)
  ((required-slot :initarg :required-slot))
  (:metaclass persistent-class)
  (:documentation "Test class with slot that has no initform."))

;;; ============================================================================
;;; Basic Tests
;;; ============================================================================

(test persistent-basic-creation
  "Test basic persistent object creation and access"
  (let ((p (make-instance 'test-person
                         :name "Alice"
                         :age (wrap 30)
                         :active t)))
    ;; Check values are accessible
    (is (equal "Alice" (pslot-value p 'name)))
    (is (= 30 (unwrap (pslot-value p 'age))))
    (is (unwrap (pslot-value p 'active)))

    ;; Check using regular slot-value works too
    (is (equal "Alice" (slot-value p 'name)))
    (is (= 30 (unwrap (slot-value p 'age))))))

(test persistent-initforms
  "Test that initforms work correctly"
  (let ((p (make-instance 'test-person)))
    ;; Default values from initforms (native values, not wrapped)
    (is (equal "Anonymous" (pslot-value p 'name)))
    (is (= 0 (pslot-value p 'age)))  ; Native 0
    (is (eq t (pslot-value p 'active)))))  ; Native T

(test persistent-empty-class
  "Test persistent object with no slots"
  (let ((e (make-instance 'test-empty)))
    (is-true (<persistent-object>? e))))

(test persistent-many-slots
  "Test persistent object with many slots"
  (let ((m (make-instance 'test-many-slots
                          :slot-a 1 :slot-b 2 :slot-c 3 :slot-d 4 :slot-e 5)))
    (is (= 1 (pslot-value m 'slot-a)))
    (is (= 2 (pslot-value m 'slot-b)))
    (is (= 3 (pslot-value m 'slot-c)))
    (is (= 4 (pslot-value m 'slot-d)))
    (is (= 5 (pslot-value m 'slot-e)))))

(test persistent-partial-initargs
  "Test creation with partial initargs"
  (let ((p (make-instance 'test-person :name "Bob")))
    ;; Explicit initarg used
    (is (equal "Bob" (pslot-value p 'name)))
    ;; Initforms used for others
    (is (= 0 (pslot-value p 'age)))
    (is (eq t (pslot-value p 'active)))))

;;; ============================================================================
;;; Immutability Tests
;;; ============================================================================

(test persistent-immutability
  "Test that direct slot modification is prevented"
  (let ((p (make-instance 'test-person :name "Bob" :age (wrap 25))))
    ;; Trying to setf should error
    (signals error
      (setf (slot-value p 'name) "Changed"))

    ;; Original value unchanged
    (is (equal "Bob" (pslot-value p 'name)))))

(test persistent-immutability-all-slots
  "Test that all slots are protected from direct modification"
  (let ((p (make-instance 'test-person :name "Bob" :age 25 :active t)))
    (signals error (setf (slot-value p 'name) "Changed"))
    (signals error (setf (slot-value p 'age) 99))
    (signals error (setf (slot-value p 'active) nil))))

(test persistent-slot-makunbound-prevented
  "Test that slots cannot be made unbound"
  (let ((p (make-instance 'test-person :name "Bob")))
    (signals error
      (slot-makunbound p 'name))))

(test persistent-functional-update
  "Test that updates return new objects and originals are unchanged"
  (let* ((p1 (make-instance 'test-person :name "Bob" :age (wrap 25)))
         (p2 (set-pslot-value p1 'age (wrap 26))))

    ;; p1 unchanged
    (is (= 25 (unwrap (pslot-value p1 'age))))

    ;; p2 has new value
    (is (= 26 (unwrap (pslot-value p2 'age))))

    ;; p2 shares other values with p1
    (is (equal "Bob" (pslot-value p2 'name)))

    ;; They are different objects
    (is (cl:not (eq p1 p2)))))

;;; ============================================================================
;;; Multiple Updates
;;; ============================================================================

(test persistent-multiple-updates
  "Test setting multiple slots at once"
  (let* ((p1 (make-instance 'test-person :name "Alice" :age (wrap 30)))
         (p2 (set-pslot-values p1
                               'name "Bob"
                               'age (wrap 25)
                               'active nil)))

    ;; p1 unchanged
    (is (equal "Alice" (pslot-value p1 'name)))
    (is (= 30 (unwrap (pslot-value p1 'age))))
    (is (unwrap (pslot-value p1 'active)))

    ;; p2 has all new values
    (is (equal "Bob" (pslot-value p2 'name)))
    (is (= 25 (unwrap (pslot-value p2 'age))))
    (is (cl:not (unwrap (pslot-value p2 'active))))))

(test persistent-update-all-slots
  "Test updating all slots at once"
  (let* ((m1 (make-instance 'test-many-slots
                            :slot-a 1 :slot-b 2 :slot-c 3 :slot-d 4 :slot-e 5))
         (m2 (set-pslot-values m1
                               'slot-a 10
                               'slot-b 20
                               'slot-c 30
                               'slot-d 40
                               'slot-e 50)))
    ;; Original unchanged
    (is (= 1 (pslot-value m1 'slot-a)))
    (is (= 5 (pslot-value m1 'slot-e)))
    ;; New has updates
    (is (= 10 (pslot-value m2 'slot-a)))
    (is (= 50 (pslot-value m2 'slot-e)))))

;;; ============================================================================
;;; with-pslots Macro Tests
;;; ============================================================================

(test persistent-with-pslots
  "Test with-pslots macro"
  (let ((p (make-instance 'test-point :x (wrap 10) :y (wrap 20))))
    (with-pslots (x y) p
      (is (= 10 (unwrap x)))
      (is (= 20 (unwrap y)))
      ;; Can use them in expressions
      (is (= 30 (unwrap (+ x y)))))))

(test persistent-with-pslots-single
  "Test with-pslots with single slot"
  (let ((p (make-instance 'test-person :name "Alice")))
    (with-pslots (name) p
      (is (equal "Alice" name)))))

(test persistent-with-pslots-nested
  "Test nested with-pslots"
  (let ((p1 (make-instance 'test-point :x 1 :y 2))
        (p2 (make-instance 'test-point :x 10 :y 20)))
    (with-pslots (x y) p1
      (declare (ignore y))
      (with-pslots ((x2 x) (y2 y)) p2
        (declare (ignore y2))
        (is (= 1 x))
        (is (= 10 x2))
        (is (= 11 (cl:+ x x2)))))))

;;; ============================================================================
;;; Type Predicate Tests
;;; ============================================================================

(test persistent-type-predicate
  "Test the <persistent-object>? type predicate"
  (let ((p (make-instance 'test-person :name "Alice"))
        (regular (make-instance 'standard-object)))

    ;; Persistent object returns true
    (is (<persistent-object>? p))

    ;; Regular object returns false
    (is (cl:not (<persistent-object>? regular)))

    ;; Non-objects return false
    (is (cl:not (<persistent-object>? 42)))
    (is (cl:not (<persistent-object>? "string")))))

(test persistent-type-predicate-fol-values
  "Test type predicate with FOL value types"
  (is-true (<persistent-object>? (wrap t)))
  (is-true (<persistent-object>? (wrap #\a)))
  (is-true (<persistent-object>? (wrap 42)))
  (is-true (<persistent-object>? (wrap 'foo)))
  (is-true (<persistent-object>? (wrap "hello"))))

;;; ============================================================================
;;; FOL Integration Tests
;;; ============================================================================

(test persistent-fol-arithmetic
  "Test using FOL arithmetic operations with persistent objects"
  (let* ((p1 (make-instance 'test-point :x (wrap 5) :y (wrap 10)))
         (p2 (set-pslot-value p1 'x
                              (+ (pslot-value p1 'x)
                                 (wrap 5)))))

    ;; p1 unchanged
    (is (= 5 (unwrap (pslot-value p1 'x))))

    ;; p2 has updated x
    (is (= 10 (unwrap (pslot-value p2 'x))))))

(test persistent-fol-logic
  "Test using FOL logical operations with persistent objects"
  (let* ((p1 (make-instance 'test-person :active t))
         (p2 (set-pslot-value p1 'active
                              (not (pslot-value p1 'active)))))

    ;; p1 unchanged
    (is (unwrap (pslot-value p1 'active)))

    ;; p2 has toggled active
    (is (cl:not (unwrap (pslot-value p2 'active))))))

(test persistent-fol-comparisons
  "Test using FOL comparison operations"
  (let ((p1 (make-instance 'test-person :age (wrap 25)))
        (p2 (make-instance 'test-person :age (wrap 30))))

    (is (unwrap (< (pslot-value p1 'age)
                   (pslot-value p2 'age))))

    (is (unwrap (> (pslot-value p2 'age)
                   (pslot-value p1 'age))))))

;;; ============================================================================
;;; Chain of Updates Tests
;;; ============================================================================

(test persistent-update-chain
  "Test chaining functional updates"
  (let* ((p0 (make-instance 'test-person :name "Alice" :age (wrap 25)))
         (p1 (set-pslot-value p0 'age (wrap 26)))
         (p2 (set-pslot-value p1 'age (wrap 27)))
         (p3 (set-pslot-value p2 'name "Alicia")))

    ;; All previous versions unchanged
    (is (= 25 (unwrap (pslot-value p0 'age))))
    (is (= 26 (unwrap (pslot-value p1 'age))))
    (is (= 27 (unwrap (pslot-value p2 'age))))
    (is (equal "Alice" (pslot-value p2 'name)))

    ;; Latest version has all updates
    (is (= 27 (unwrap (pslot-value p3 'age))))
    (is (equal "Alicia" (pslot-value p3 'name)))))

(test persistent-divergent-updates
  "Test creating divergent update branches"
  (let* ((base (make-instance 'test-point :x 0 :y 0))
         (branch-a (set-pslot-value base 'x 10))
         (branch-b (set-pslot-value base 'y 20)))
    ;; Base unchanged
    (is (= 0 (pslot-value base 'x)))
    (is (= 0 (pslot-value base 'y)))
    ;; Branch A has x=10, y=0
    (is (= 10 (pslot-value branch-a 'x)))
    (is (= 0 (pslot-value branch-a 'y)))
    ;; Branch B has x=0, y=20
    (is (= 0 (pslot-value branch-b 'x)))
    (is (= 20 (pslot-value branch-b 'y)))))

;;; ============================================================================
;;; FOL Value Classes as Persistent
;;; ============================================================================

(test fol-values-are-persistent
  "Verify that FOL value classes are persistent objects"
  (let ((bool-val (wrap t))
        (char-val (wrap #\a))
        (num-val (wrap 42)))

    ;; All FOL values should be persistent objects
    (is (<persistent-object>? bool-val))
    (is (<persistent-object>? char-val))
    (is (<persistent-object>? num-val))))

(test fol-values-immutable
  "Test that FOL values are immutable"
  (let ((num (wrap 42)))
    ;; Cannot modify val slot
    (signals error
      (setf (slot-value num 'val) 100))

    ;; Value unchanged
    (is (= 42 (unwrap num)))))

(test fol-bool-persistent-works
  "Test that wrapped boolean FOL values work as persistent objects"
  (let ((true-val (wrap-bool t))
        (false-val (wrap-bool nil)))

    ;; Can access their slots
    (is (eq t (pslot-value true-val 'val)))
    (is (eq nil (pslot-value false-val 'val)))

    ;; They are persistent objects
    (is (<persistent-object>? true-val))
    (is (<persistent-object>? false-val))))

(test fol-char-persistent-works
  "Test that character FOL values work as persistent objects"
  (let ((char-a (wrap #\a)))

    ;; Can access val slot
    (is (char= #\a (pslot-value char-a 'val)))

    ;; Is persistent
    (is (<persistent-object>? char-a))

    ;; Cannot modify
    (signals error
      (setf (slot-value char-a 'val) #\b))))

(test fol-number-persistent-works
  "Test that number FOL values work as persistent objects"
  (let ((num (wrap 42)))

    ;; Can access val slot
    (is (= 42 (pslot-value num 'val)))

    ;; Is persistent
    (is (<persistent-object>? num))

    ;; Cannot modify
    (signals error
      (setf (slot-value num 'val) 100))))

;;; ============================================================================
;;; Slot Bound Tests
;;; ============================================================================

(test persistent-slot-boundp
  "Test slot-boundp on persistent objects"
  (let ((p (make-instance 'test-person :name "Alice")))
    ;; All slots should be bound due to initforms
    (is-true (slot-boundp p 'name))
    (is-true (slot-boundp p 'age))
    (is-true (slot-boundp p 'active))))

(test persistent-slot-boundp-no-initform
  "Test slot-boundp on slot without initform when value provided"
  (let ((obj (make-instance 'test-no-initforms :required-slot "value")))
    (is-true (slot-boundp obj 'required-slot))
    (is (equal "value" (slot-value obj 'required-slot)))))

;;; ============================================================================
;;; Complex Scenarios
;;; ============================================================================

(test persistent-storing-fol-values
  "Test storing FOL persistent values in other persistent objects"
  (let* ((p1 (make-instance 'test-person
                           :name "Alice"
                           :age (wrap 30)
                           :active t))
         ;; Create new person with updated age using arithmetic
         ;; Note: FOL arithmetic returns raw values, so wrap result to keep it persistent
         (p2 (set-pslot-value p1 'age
                              (wrap (+ (pslot-value p1 'age)
                                       (wrap 1))))))

    ;; Original unchanged
    (is (= 30 (unwrap (pslot-value p1 'age))))

    ;; New version updated
    (is (= 31 (unwrap (pslot-value p2 'age))))

    ;; Both age values are themselves persistent objects
    (is (<persistent-object>? (pslot-value p1 'age)))
    (is (<persistent-object>? (pslot-value p2 'age)))))

(test persistent-operations-with-fol-values
  "Test that FOL operations work with persistent value objects"
  (let ((x (wrap 10))
        (y (wrap 20)))

    ;; Arithmetic
    (is (= 30 (unwrap (+ x y))))

    ;; Comparison
    (is (unwrap (< x y)))
    (is (unwrap (> y x)))
    (is (unwrap (= x x)))

    ;; Values still immutable
    (signals error
      (setf (slot-value x 'val) 999))))

(test persistent-storing-various-types
  "Test storing various value types in persistent slots"
  (let ((p (make-instance 'test-person
                          :name '(a b c)      ; list
                          :age #(1 2 3)       ; vector
                          :active :keyword))) ; keyword
    (is (equal '(a b c) (pslot-value p 'name)))
    (is (equalp #(1 2 3) (pslot-value p 'age)))
    (is (eq :keyword (pslot-value p 'active)))))

(test persistent-storing-nil
  "Test storing nil as a slot value"
  (let ((p (make-instance 'test-person :name nil :age nil :active nil)))
    (is (eq nil (pslot-value p 'name)))
    (is (eq nil (pslot-value p 'age)))
    (is (eq nil (pslot-value p 'active)))))

(test persistent-updating-to-nil
  "Test updating a slot to nil"
  (let* ((p1 (make-instance 'test-person :name "Alice"))
         (p2 (set-pslot-value p1 'name nil)))
    (is (equal "Alice" (pslot-value p1 'name)))
    (is (eq nil (pslot-value p2 'name)))))

;;; ============================================================================
;;; Metaclass Tests
;;; ============================================================================

(test persistent-metaclass
  "Test that persistent objects have persistent-class metaclass"
  (let ((p (make-instance 'test-person)))
    (is (typep (class-of p) 'persistent-class))))

(test persistent-class-hierarchy
  "Test persistent class inheritance"
  (is (subtypep 'test-person '<persistent-object>))
  (is (subtypep 'test-point '<persistent-object>))
  (is (subtypep 'test-empty '<persistent-object>)))

(test persistent-dissoc
  "Test functional removal of slots"
  (let* ((p1 (make-instance 'test-person :name "Alice" :age 30))
         (p2 (dissoc p1 :name)))
    ;; Original unchanged
    (is (slot-boundp p1 'name))
    (is (equal "Alice" (slot-value p1 'name)))
    
    ;; p2 has slot unbound
    (is (cl:not (slot-boundp p2 'name)))
    (signals unbound-slot
      (slot-value p2 'name))
    
    ;; p2 still has other slots
    (is (= 30 (slot-value p2 'age)))))
