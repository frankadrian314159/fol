(in-package :fol.tests)

;;; ============================================================================
;;; Module Tests - Comprehensive test suite for FOL modules
;;; ============================================================================

(def-suite* :fol.module-tests)

;;; ---------------------------------------------------------------------------
;;; Module Type Predicate Tests
;;; ---------------------------------------------------------------------------

(test module-predicate
  "Test <module>? predicate."
  (is-true (<module>? (make-module)))
  (is-true (<module>? (make-module 'x 1)))
  (is-false (<module>? (make-dict)))
  (is-false (<module>? 42))
  (is-false (<module>? "string"))
  (is-false (<module>? nil)))

;;; ---------------------------------------------------------------------------
;;; Module Inheritance Tests
;;; ---------------------------------------------------------------------------

(test module-inherits-from-dict
  "Test that module inherits from dict."
  (let ((m (make-module)))
    (is-true (<dict>? m))
    (is-true (<unordered-collection>? m))
    (is-true (<collection>? m))))

(test module-is-not-other-collections
  "Test that module is not confused with other collection types."
  (let ((m (make-module)))
    (is-false (<set>? m))
    (is-false (<bag>? m))
    (is-false (<vector>? m))
    (is-false (<ordered-collection>? m))))

;;; ---------------------------------------------------------------------------
;;; Module Creation Tests
;;; ---------------------------------------------------------------------------

(test module-creation-empty
  "Test creation of empty module."
  (let ((m (make-module)))
    (is-true (<module>? m))
    (is (= 0 (size m)))
    (is-true (empty? m))))

(test module-creation-with-bindings
  "Test creation of module with initial bindings."
  (let ((m (make-module 'x 10 'y 20 'z 30)))
    (is-true (<module>? m))
    (is (= 3 (size m)))
    (is (= 10 (get m 'x)))
    (is (= 20 (get m 'y)))
    (is (= 30 (get m 'z)))))

(test module-creation-with-keywords
  "Test creation of module with keyword bindings."
  (let ((m (make-module :foo 1 :bar 2)))
    (is (= 2 (size m)))
    (is (= 1 (get m :foo)))
    (is (= 2 (get m :bar)))))

(test module-creation-mixed-keys
  "Test creation of module with mixed key types."
  (let ((m (make-module
            'sym 1
            :key 2
            "str" 3)))
    (is (= 3 (size m)))
    (is (= 1 (get m 'sym)))
    (is (= 2 (get m :key)))
    (is (= 3 (get m "str")))))

;;; ---------------------------------------------------------------------------
;;; Module Get/Contains Tests
;;; ---------------------------------------------------------------------------

(test module-get-existing
  "Test getting existing bindings from module."
  (let ((m (make-module 'a 100 'b 200)))
    (is (= 100 (get m 'a)))
    (is (= 200 (get m 'b)))))

(test module-get-missing
  "Test getting missing bindings from module."
  (let ((m (make-module 'x 1)))
    (is (eq nil (get m 'missing)))
    (is (eq :not-found (get m 'missing :not-found)))))

(test module-contains
  "Test contains? on module."
  (let ((m (make-module 'present 1 'also-present nil)))
    (is-true (contains? m 'present))
    (is-true (contains? m 'also-present))  ; nil value still means key exists
    (is-false (contains? m 'absent))))

;;; ---------------------------------------------------------------------------
;;; Module Add/Remove Tests
;;; ---------------------------------------------------------------------------

(test module-add-binding
  "Test adding bindings to module."
  (let* ((m1 (make-module 'x 1))
         (m2 (add m1 'y 2)))
    ;; Original unchanged
    (is (= 1 (size m1)))
    (is-false (contains? m1 'y))
    ;; New module has addition
    (is (= 2 (size m2)))
    (is (= 2 (get m2 'y)))
    ;; New module is still a module
    (is-true (<module>? m2))))

(test module-add-overwrites
  "Test that adding existing key overwrites value."
  (let* ((m1 (make-module 'x 1))
         (m2 (add m1 'x 100)))
    (is (= 1 (get m1 'x)))
    (is (= 100 (get m2 'x)))))

(test module-remove-binding
  "Test removing bindings from module."
  (let* ((m1 (make-module 'a 1 'b 2))
         (m2 (remove m1 'a)))
    ;; Original unchanged
    (is (= 2 (size m1)))
    ;; New module has removal
    (is (= 1 (size m2)))
    (is-false (contains? m2 'a))
    (is-true (contains? m2 'b))
    ;; New module is still a module
    (is-true (<module>? m2))))

(test module-remove-nonexistent
  "Test removing nonexistent binding from module."
  (let* ((m1 (make-module 'x 1))
         (m2 (remove m1 'nonexistent)))
    (is (= 1 (size m2)))
    (is-true (<module>? m2))))

;;; ---------------------------------------------------------------------------
;;; Module Immutability Tests
;;; ---------------------------------------------------------------------------

(test module-immutability
  "Test that module operations don't mutate original."
  (let* ((m1 (make-module 'a 1 'b 2))
         (m2 (add m1 'c 3))
         (m3 (remove m1 'a)))
    ;; m1 unchanged
    (is (= 2 (size m1)))
    (is-true (contains? m1 'a))
    (is-false (contains? m1 'c))
    ;; m2 has addition
    (is (= 3 (size m2)))
    ;; m3 has removal
    (is (= 1 (size m3)))))

;;; ---------------------------------------------------------------------------
;;; Module with Various Value Types
;;; ---------------------------------------------------------------------------

(test module-various-value-types
  "Test module with various value types."
  (let ((m (make-module
            'num 42
            'str "hello"
            'bool t
            'nil-val nil
            'list '(1 2 3)
            'vec (make-vector 1 2 3))))
    (is (= 42 (get m 'num)))
    (is (string= "hello" (get m 'str)))
    (is (eq t (get m 'bool)))
    (is (eq nil (get m 'nil-val)))
    (is (equal '(1 2 3) (get m 'list)))
    (is-true (<vector>? (get m 'vec)))))

(test module-stores-functions
  "Test that modules can store functions."
  (let ((m (make-module 'add #'+)))
    (is (functionp (get m 'add)))
    (is (= 3 (funcall (get m 'add) 1 2)))))

;;; ---------------------------------------------------------------------------
;;; Module Iterator Tests
;;; ---------------------------------------------------------------------------

(test module-iterator
  "Test iterator on module."
  (let* ((m (make-module 'a 1 'b 2))
         (iter (iterator m))
         (keys '()))
    (loop until (done? iter)
          do (push (car (current iter)) keys)
             (next iter))
    (is (= 2 (length keys)))))

(test module-empty-iterator
  "Test iterator on empty module."
  (let* ((m (make-module))
         (iter (iterator m)))
    (is-true (done? iter))))

;;; ---------------------------------------------------------------------------
;;; Module Size/Empty Tests
;;; ---------------------------------------------------------------------------

(test module-size
  "Test size operation on module."
  (is (= 0 (size (make-module))))
  (is (= 1 (size (make-module 'x 1))))
  (is (= 3 (size (make-module 'a 1 'b 2 'c 3)))))

(test module-empty
  "Test empty? operation on module."
  (is-true (empty? (make-module)))
  (is-false (empty? (make-module 'x 1))))

;;; ---------------------------------------------------------------------------
;;; Module as Namespace Tests
;;; ---------------------------------------------------------------------------

(test module-as-namespace
  "Test using module as a namespace for bindings."
  (let ((math-module (make-module
                      'pi 3.14159
                      'e 2.71828
                      'phi 1.61803)))
    (is (< (abs (- 3.14159 (get math-module 'pi))) 0.00001))
    (is (< (abs (- 2.71828 (get math-module 'e))) 0.00001))
    (is (< (abs (- 1.61803 (get math-module 'phi))) 0.00001))))

(test module-nested-modules
  "Test modules containing other modules."
  (let* ((inner (make-module 'x 1))
         (outer (make-module 'inner inner)))
    (is-true (<module>? (get outer 'inner)))
    (is (= 1 (get (get outer 'inner) 'x)))))

;;; ---------------------------------------------------------------------------
;;; Module Wrapped Value Tests
;;; ---------------------------------------------------------------------------

(test module-stores-raw-values
  "Test that modules store raw CL values."
  (let* ((wrapped-num (wrap-number 42))
         (m (make-module 'key wrapped-num)))
    ;; Value should be stored as raw 42
    (is (= 42 (get m 'key)))
    (is (numberp (get m 'key)))))

(test module-accepts-wrapped-keys
  "Test that modules accept wrapped keys."
  (let* ((wrapped-key (wrap-symbol 'test))
         (m (make-module wrapped-key "value")))
    ;; Should be able to retrieve using raw key
    (is (string= "value" (get m 'test)))))
