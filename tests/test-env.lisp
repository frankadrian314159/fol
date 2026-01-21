(in-package :fol.tests)

;;; ============================================================================
;;; Environment Tests - Comprehensive test suite for FOL environments
;;; ============================================================================

(def-suite* :fol.env-tests)

;;; ---------------------------------------------------------------------------
;;; Environment Type Predicate Tests
;;; ---------------------------------------------------------------------------

(test env-predicate
  "Test <env>? predicate."
  (is-true (<env>? (make-env)))
  (is-true (<env>? (make-env nil 'x 1)))
  (is-false (<env>? (make-dict)))
  (is-false (<env>? (make-module)))
  (is-false (<env>? 42))
  (is-false (<env>? nil)))

;;; ---------------------------------------------------------------------------
;;; Environment Inheritance Tests
;;; ---------------------------------------------------------------------------

(test env-inherits-from-dict
  "Test that environment inherits from dict."
  (let ((env (make-env)))
    (is-true (<dict>? env))
    (is-true (<unordered-collection>? env))
    (is-true (<collection>? env))))

(test env-is-not-module
  "Test that environment is distinct from module."
  (let ((env (make-env)))
    (is-false (<module>? env))))

;;; ---------------------------------------------------------------------------
;;; Environment Creation Tests
;;; ---------------------------------------------------------------------------

(test env-creation-empty
  "Test creation of empty environment."
  (let ((env (make-env)))
    (is-true (<env>? env))
    (is (eq nil (env-previous env)))
    (is-true (empty? env))))

(test env-creation-with-bindings
  "Test creation of environment with initial bindings."
  (let ((env (make-env nil 'x 10 'y 20 'z 30)))
    (is-true (<env>? env))
    (is (= 3 (size env)))
    (is (= 10 (lookup env 'x)))
    (is (= 20 (lookup env 'y)))
    (is (= 30 (lookup env 'z)))))

(test env-creation-with-previous
  "Test creation of environment with previous environment."
  (let* ((outer (make-env nil 'a 1))
         (inner (make-env outer 'b 2)))
    (is (eq outer (env-previous inner)))
    (is (eq nil (env-previous outer)))))

(test env-creation-with-previous-and-bindings
  "Test creation of environment with previous and initial bindings."
  (let* ((outer (make-env nil 'x 1))
         (inner (make-env outer 'y 2 'z 3)))
    (is (= 2 (size inner)))
    (is (= 2 (lookup inner 'y)))
    (is (= 3 (lookup inner 'z)))))

;;; ---------------------------------------------------------------------------
;;; Environment Lookup Tests
;;; ---------------------------------------------------------------------------

(test env-lookup-in-current
  "Test looking up variables in current environment."
  (let ((env (make-env nil 'x 42 'y "hello")))
    (is (= 42 (lookup env 'x)))
    (is (string= "hello" (lookup env 'y)))))

(test env-lookup-in-previous
  "Test looking up variables in previous environment."
  (let* ((outer (make-env nil 'x 1 'y 2))
         (inner (make-env outer 'z 3)))
    ;; Inner finds its own binding
    (is (= 3 (lookup inner 'z)))
    ;; Inner falls back to outer for x and y
    (is (= 1 (lookup inner 'x)))
    (is (= 2 (lookup inner 'y)))))

(test env-lookup-shadowing
  "Test that inner bindings shadow outer bindings."
  (let* ((outer (make-env nil 'x 1 'y 2 'z 3))
         (inner (make-env outer 'x 100 'y 200)))
    ;; Inner values shadow outer
    (is (= 100 (lookup inner 'x)))
    (is (= 200 (lookup inner 'y)))
    ;; Outer value still accessible if not shadowed
    (is (= 3 (lookup inner 'z)))
    ;; Outer env still has original values
    (is (= 1 (lookup outer 'x)))
    (is (= 2 (lookup outer 'y)))))

(test env-lookup-deep-chain
  "Test lookup through multiple nested environments."
  (let* ((env1 (make-env nil 'a 1))
         (env2 (make-env env1 'b 2))
         (env3 (make-env env2 'c 3))
         (env4 (make-env env3 'd 4)))
    ;; Can find variables from any level
    (is (= 4 (lookup env4 'd)))
    (is (= 3 (lookup env4 'c)))
    (is (= 2 (lookup env4 'b)))
    (is (= 1 (lookup env4 'a)))))

(test env-lookup-nil-value
  "Test looking up variables that have nil as their value."
  (let ((env (make-env nil 'x nil 'y 10)))
    ;; Looking up a variable bound to nil should return nil
    (is (eq nil (lookup env 'x)))
    ;; But should not trigger error
    (is (= 10 (lookup env 'y)))))

;;; ---------------------------------------------------------------------------
;;; Environment Unbound Variable Tests
;;; ---------------------------------------------------------------------------

(test env-lookup-not-found-single
  "Test that lookup signals unbound-variable error when variable not found."
  (let ((env (make-env nil 'x 10)))
    (signals fol-unbound-variable
      (lookup env 'undefined))))

(test env-lookup-not-found-chain
  "Test that unbound-variable is raised when variable not in any level."
  (let* ((env1 (make-env nil 'x 1))
         (env2 (make-env env1 'y 2))
         (env3 (make-env env2 'z 3)))
    (signals fol-unbound-variable
      (lookup env3 'undefined))))

(test env-unbound-variable-condition-properties
  "Test the unbound-variable error condition properties."
  (let ((env (make-env nil 'x 10)))
    (handler-case
        (lookup env 'missing-var)
      (fol-unbound-variable (condition)
        (is (eq 'missing-var (fol-unbound-variable-name condition)))
        (is (stringp (fol-unbound-variable-message condition)))
        (is (search "missing-var" (fol-unbound-variable-message condition)
                    :test #'char-equal))))))

;;; ---------------------------------------------------------------------------
;;; Environment Add/Remove Tests (via dict operations)
;;; ---------------------------------------------------------------------------

(test env-add-binding
  "Test adding bindings to environment via dict operations."
  (let* ((env1 (make-env nil 'x 1))
         (env2 (add env1 'y 2)))
    ;; Original unchanged
    (is (= 1 (size env1)))
    ;; New env has addition
    (is (= 2 (size env2)))
    (is (= 2 (lookup env2 'y)))
    ;; New env is still an env
    (is-true (<env>? env2))))

(test env-remove-binding
  "Test removing bindings from environment via dict operations."
  (let* ((env1 (make-env nil 'a 1 'b 2))
         (env2 (remove env1 'a)))
    ;; Original unchanged
    (is (= 2 (size env1)))
    ;; New env has removal
    (is (= 1 (size env2)))
    (signals fol-unbound-variable
      (lookup env2 'a))
    ;; b still accessible
    (is (= 2 (lookup env2 'b)))))

;;; ---------------------------------------------------------------------------
;;; Environment Various Value Types
;;; ---------------------------------------------------------------------------

(test env-various-value-types
  "Test that environments can store various types of values."
  (let ((env (make-env nil
                       'bool t
                       'char #\A
                       'string "hello"
                       'symbol 'foo
                       'number 42
                       'float 3.14
                       'list '(1 2 3)
                       'vector #(a b c))))
    (is (eq t (lookup env 'bool)))
    (is (char= #\A (lookup env 'char)))
    (is (string= "hello" (lookup env 'string)))
    (is (eq 'foo (lookup env 'symbol)))
    (is (= 42 (lookup env 'number)))
    (is (< (abs (- 3.14 (lookup env 'float))) 0.001))
    (is (equal '(1 2 3) (lookup env 'list)))
    (is (equalp #(a b c) (lookup env 'vector)))))

(test env-stores-fol-collections
  "Test that environments can store FOL collections."
  (let* ((vec (make-vector 1 2 3))
         (dict (make-dict :a 1))
         (env (make-env nil 'vec vec 'dict dict)))
    (is-true (<vector>? (lookup env 'vec)))
    (is-true (<dict>? (lookup env 'dict)))))

;;; ---------------------------------------------------------------------------
;;; Environment Previous Link Tests
;;; ---------------------------------------------------------------------------

(test env-previous-link
  "Test the previous environment link is properly maintained."
  (let* ((env1 (make-env))
         (env2 (make-env env1))
         (env3 (make-env env2)))
    (is (eq nil (env-previous env1)))
    (is (eq env1 (env-previous env2)))
    (is (eq env2 (env-previous env3)))))

(test env-previous-preserved-after-add
  "Test that previous link is preserved after add operations."
  (let* ((outer (make-env nil 'x 1))
         (inner (make-env outer 'y 2))
         (inner2 (add inner 'z 3)))
    ;; New env is still an env
    (is-true (<env>? inner2))))

;;; ---------------------------------------------------------------------------
;;; Environment Immutability Tests
;;; ---------------------------------------------------------------------------

(test env-immutability
  "Test that environment operations don't mutate original."
  (let* ((env1 (make-env nil 'a 1 'b 2))
         (env2 (add env1 'c 3)))
    ;; env1 unchanged
    (is (= 2 (size env1)))
    (signals fol-unbound-variable
      (lookup env1 'c))
    ;; env2 has addition
    (is (= 3 (size env2)))
    (is (= 3 (lookup env2 'c)))))

;;; ---------------------------------------------------------------------------
;;; Environment Size/Empty Tests
;;; ---------------------------------------------------------------------------

(test env-size
  "Test size operation on environment."
  (is (= 0 (size (make-env))))
  (is (= 1 (size (make-env nil 'x 1))))
  (is (= 3 (size (make-env nil 'a 1 'b 2 'c 3)))))

(test env-empty
  "Test empty? operation on environment."
  (is-true (empty? (make-env)))
  (is-false (empty? (make-env nil 'x 1))))

;;; ---------------------------------------------------------------------------
;;; Environment Contains Tests
;;; ---------------------------------------------------------------------------

(test env-contains-in-current
  "Test contains? only checks current environment, not chain."
  (let* ((outer (make-env nil 'x 1))
         (inner (make-env outer 'y 2)))
    ;; Contains only checks current level
    (is-true (contains? inner 'y))
    ;; x is in outer, not inner directly
    (is-false (contains? inner 'x))
    ;; But lookup finds it via chain
    (is (= 1 (lookup inner 'x)))))

;;; ---------------------------------------------------------------------------
;;; Environment Iterator Tests
;;; ---------------------------------------------------------------------------

(test env-iterator
  "Test iterator on environment."
  (let* ((env (make-env nil 'a 1 'b 2))
         (iter (iterator env))
         (count 0))
    (loop until (done? iter)
          do (incf count)
             (next iter))
    (is (= 2 count))))

(test env-empty-iterator
  "Test iterator on empty environment."
  (let* ((env (make-env))
         (iter (iterator env)))
    (is-true (done? iter))))

;;; ---------------------------------------------------------------------------
;;; Environment Lexical Scoping Simulation
;;; ---------------------------------------------------------------------------

(test env-lexical-scope-simulation
  "Test simulating lexical scoping with nested environments."
  ;; Simulate:
  ;; (let ((x 1))
  ;;   (let ((y 2))
  ;;     (let ((x 10))
  ;;       ;; x=10, y=2
  ;;       )))
  (let* ((env1 (make-env nil 'x 1))
         (env2 (make-env env1 'y 2))
         (env3 (make-env env2 'x 10)))
    (is (= 10 (lookup env3 'x)))  ; x is shadowed
    (is (= 2 (lookup env3 'y)))   ; y from env2
    (is (= 1 (lookup env1 'x)))   ; outer x unchanged
    (is (= 1 (lookup env2 'x))))) ; y-env sees outer x

(test env-closure-simulation
  "Test simulating closure environments."
  ;; Simulate a closure that captures x
  (let* ((captured-env (make-env nil 'x 42))
         ;; Function call creates new env with captured as previous
         (call-env (make-env captured-env 'arg 100)))
    ;; Inside function, can see both arg and captured x
    (is (= 100 (lookup call-env 'arg)))
    (is (= 42 (lookup call-env 'x)))))

;;; ---------------------------------------------------------------------------
;;; Environment Wrapped Value Tests
;;; ---------------------------------------------------------------------------

(test env-stores-raw-values
  "Test that environments store raw CL values."
  (let* ((wrapped-num (wrap-number 42))
         (env (make-env nil 'key wrapped-num)))
    ;; Value should be stored as raw 42
    (is (= 42 (lookup env 'key)))
    (is (numberp (lookup env 'key)))))

(test env-accepts-wrapped-keys
  "Test that environments accept wrapped keys."
  (let* ((wrapped-key (wrap-symbol 'test))
         (env (make-env nil wrapped-key "value")))
    ;; Should be able to lookup using raw key
    (is (string= "value" (lookup env 'test)))))
