(in-package fol.tests)
(named-readtables:in-readtable fol.syntax:fol-syntax)

(in-suite fol-suite)

;;; ============================================================================
;;; Example Classes for Testing
;;; ============================================================================

(defclass test-person (fol.persistent:<persistent-object>)
  ((name :initarg :name :initform "Anonymous")
   (age :initarg :age :initform 0)  ; Native value, wrap in tests
   (active :initarg :active :initform t))  ; Native boolean, wrap in tests
  (:metaclass fol.persistent:persistent-class)
  (:documentation "Test person with FOL-wrapped persistent slots."))

(defclass test-point (fol.persistent:<persistent-object>)
  ((x :initarg :x :initform 0)  ; Native value, wrap in tests
   (y :initarg :y :initform 0))  ; Native value, wrap in tests
  (:metaclass fol.persistent:persistent-class)
  (:documentation "Test 2D point with FOL-wrapped coordinates."))

;;; ============================================================================
;;; Basic Tests
;;; ============================================================================

(test persistent-basic-creation
  "Test basic persistent object creation and access"
  (let ((p (make-instance 'test-person 
                         :name "Alice"
                         :age (wrap 30)
                         :active #t)))
    ;; Check values are accessible
    (is (equal "Alice" (fol.persistent:pslot-value p 'name)))
    (is (= 30 (unwrap (fol.persistent:pslot-value p 'age))))
    (is (unwrap (fol.persistent:pslot-value p 'active)))
    
    ;; Check using regular slot-value works too
    (is (equal "Alice" (slot-value p 'name)))
    (is (= 30 (unwrap (slot-value p 'age))))))

(test persistent-initforms
  "Test that initforms work correctly"
  (let ((p (make-instance 'test-person)))
    ;; Default values from initforms (native values, not wrapped)
    (is (equal "Anonymous" (fol.persistent:pslot-value p 'name)))
    (is (= 0 (fol.persistent:pslot-value p 'age)))  ; Native 0
    (is (eq t (fol.persistent:pslot-value p 'active)))))  ; Native T

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
    (is (equal "Bob" (fol.persistent:pslot-value p 'name)))))

(test persistent-functional-update
  "Test that updates return new objects and originals are unchanged"
  (let* ((p1 (make-instance 'test-person :name "Bob" :age (wrap 25)))
         (p2 (fol.persistent:set-pslot-value p1 'age (wrap 26))))
    
    ;; p1 unchanged
    (is (= 25 (unwrap (fol.persistent:pslot-value p1 'age))))
    
    ;; p2 has new value
    (is (= 26 (unwrap (fol.persistent:pslot-value p2 'age))))
    
    ;; p2 shares other values with p1
    (is (equal "Bob" (fol.persistent:pslot-value p2 'name)))
    
    ;; They are different objects
    (is (cl:not (eq p1 p2)))))

;;; ============================================================================
;;; Multiple Updates
;;; ============================================================================

(test persistent-multiple-updates
  "Test setting multiple slots at once"
  (let* ((p1 (make-instance 'test-person :name "Alice" :age (wrap 30)))
         (p2 (fol.persistent:set-pslot-values p1 
                                             'name "Bob"
                                             'age (wrap 25)
                                             'active #f)))
    
    ;; p1 unchanged
    (is (equal "Alice" (fol.persistent:pslot-value p1 'name)))
    (is (= 30 (unwrap (fol.persistent:pslot-value p1 'age))))
    (is (unwrap (fol.persistent:pslot-value p1 'active)))
    
    ;; p2 has all new values
    (is (equal "Bob" (fol.persistent:pslot-value p2 'name)))
    (is (= 25 (unwrap (fol.persistent:pslot-value p2 'age))))
    (is (cl:not (unwrap (fol.persistent:pslot-value p2 'active))))))

;;; ============================================================================
;;; with-pslots Macro Tests
;;; ============================================================================

(test persistent-with-pslots
  "Test with-pslots macro"
  (let ((p (make-instance 'test-point :x (wrap 10) :y (wrap 20))))
    (fol.persistent:with-pslots (x y) p
      (is (= 10 (unwrap x)))
      (is (= 20 (unwrap y)))
      ;; Can use them in expressions
      (is (= 30 (unwrap (+ x y)))))))

;;; ============================================================================
;;; Type Predicate Tests
;;; ============================================================================

(test persistent-type-predicate
  "Test the <persistent-object>? type predicate"
  (let ((p (make-instance 'test-person :name "Alice"))
        (regular (make-instance 'standard-object)))
    
    ;; Persistent object returns true
    (is (fol.persistent:<persistent-object>? p))
    
    ;; Regular object returns false
    (is (cl:not (fol.persistent:<persistent-object>? regular)))
    
    ;; Non-objects return false
    (is (cl:not (fol.persistent:<persistent-object>? 42)))
    (is (cl:not (fol.persistent:<persistent-object>? "string")))))

;;; ============================================================================
;;; FOL Integration Tests
;;; ============================================================================

(test persistent-fol-arithmetic
  "Test using FOL arithmetic operations with persistent objects"
  (let* ((p1 (make-instance 'test-point :x (wrap 5) :y (wrap 10)))
         (p2 (fol.persistent:set-pslot-value p1 'x 
                                            (+ (fol.persistent:pslot-value p1 'x) 
                                               (wrap 5)))))
    
    ;; p1 unchanged
    (is (= 5 (unwrap (fol.persistent:pslot-value p1 'x))))
    
    ;; p2 has updated x
    (is (= 10 (unwrap (fol.persistent:pslot-value p2 'x))))))

(test persistent-fol-logic
  "Test using FOL logical operations with persistent objects"
  (let* ((p1 (make-instance 'test-person :active #t))
         (p2 (fol.persistent:set-pslot-value p1 'active 
                                            (not (fol.persistent:pslot-value p1 'active)))))
    
    ;; p1 unchanged
    (is (unwrap (fol.persistent:pslot-value p1 'active)))
    
    ;; p2 has toggled active
    (is (cl:not (unwrap (fol.persistent:pslot-value p2 'active))))))

(test persistent-fol-comparisons
  "Test using FOL comparison operations"
  (let ((p1 (make-instance 'test-person :age (wrap 25)))
        (p2 (make-instance 'test-person :age (wrap 30))))
    
    (is (unwrap (< (fol.persistent:pslot-value p1 'age)
                   (fol.persistent:pslot-value p2 'age))))
    
    (is (unwrap (> (fol.persistent:pslot-value p2 'age)
                   (fol.persistent:pslot-value p1 'age))))))

;;; ============================================================================
;;; Chain of Updates Tests
;;; ============================================================================

(test persistent-update-chain
  "Test chaining functional updates"
  (let* ((p0 (make-instance 'test-person :name "Alice" :age (wrap 25)))
         (p1 (fol.persistent:set-pslot-value p0 'age (wrap 26)))
         (p2 (fol.persistent:set-pslot-value p1 'age (wrap 27)))
         (p3 (fol.persistent:set-pslot-value p2 'name "Alicia")))
    
    ;; All previous versions unchanged
    (is (= 25 (unwrap (fol.persistent:pslot-value p0 'age))))
    (is (= 26 (unwrap (fol.persistent:pslot-value p1 'age))))
    (is (= 27 (unwrap (fol.persistent:pslot-value p2 'age))))
    (is (equal "Alice" (fol.persistent:pslot-value p2 'name)))
    
    ;; Latest version has all updates
    (is (= 27 (unwrap (fol.persistent:pslot-value p3 'age))))
    (is (equal "Alicia" (fol.persistent:pslot-value p3 'name)))))

;;; ============================================================================
;;; FOL Value Classes as Persistent
;;; ============================================================================

(test fol-values-are-persistent
  "Verify that FOL value classes are persistent objects"
  (let ((bool-val (wrap t))
        (char-val (wrap #\a))
        (num-val (wrap 42)))
    
    ;; All FOL values should be persistent objects
    (is (fol.persistent:<persistent-object>? bool-val))
    (is (fol.persistent:<persistent-object>? char-val))
    (is (fol.persistent:<persistent-object>? num-val))))

(test fol-values-immutable
  "Test that FOL values are immutable"
  (let ((num (wrap 42)))
    ;; Cannot modify val slot
    (signals error
      (setf (slot-value num 'val) 100))
    
    ;; Value unchanged
    (is (= 42 (unwrap num)))))

(test fol-bool-persistent-works
  "Test that boolean FOL values work as persistent objects"
  (let ((true-val #t)
        (false-val #f))
    
    ;; Can access their slots
    (is (eq t (fol.persistent:pslot-value true-val 'val)))
    (is (eq nil (fol.persistent:pslot-value false-val 'val)))
    
    ;; They are persistent objects
    (is (fol.persistent:<persistent-object>? true-val))
    (is (fol.persistent:<persistent-object>? false-val))))

(test fol-char-persistent-works
  "Test that character FOL values work as persistent objects"
  (let ((char-a (wrap #\a)))
    
    ;; Can access val slot
    (is (= #\a (fol.persistent:pslot-value char-a 'val)))
    
    ;; Is persistent
    (is (fol.persistent:<persistent-object>? char-a))
    
    ;; Cannot modify
    (signals error
      (setf (slot-value char-a 'val) #\b))))

(test fol-number-persistent-works
  "Test that number FOL values work as persistent objects"
  (let ((num (wrap 42)))
    
    ;; Can access val slot
    (is (= 42 (fol.persistent:pslot-value num 'val)))
    
    ;; Is persistent
    (is (fol.persistent:<persistent-object>? num))
    
    ;; Cannot modify
    (signals error
      (setf (slot-value num 'val) 100))))

;;; ============================================================================
;;; Complex Scenarios
;;; ============================================================================

(test persistent-storing-fol-values
  "Test storing FOL persistent values in other persistent objects"
  (let* ((p1 (make-instance 'test-person 
                           :name "Alice"
                           :age (wrap 30)
                           :active #t))
         ;; Create new person with updated age using arithmetic
         (p2 (fol.persistent:set-pslot-value p1 'age 
                                            (+ (fol.persistent:pslot-value p1 'age)
                                               (wrap 1)))))
    
    ;; Original unchanged
    (is (= 30 (unwrap (fol.persistent:pslot-value p1 'age))))
    
    ;; New version updated
    (is (= 31 (unwrap (fol.persistent:pslot-value p2 'age))))
    
    ;; Both age values are themselves persistent objects
    (is (fol.persistent:<persistent-object>? (fol.persistent:pslot-value p1 'age)))
    (is (fol.persistent:<persistent-object>? (fol.persistent:pslot-value p2 'age)))))

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