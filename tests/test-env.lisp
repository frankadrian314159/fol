(in-package fol.tests)
(in-readtable fol-syntax)

(in-suite fol-suite)

;;; ============================================================================
;;; Environment Class Tests
;;; ============================================================================

(test env-inheritance
  "Test that <env> inherits from <dict>"
  (let ((env (make-env)))
    ;; Check class hierarchy
    (is (typep env '<env>))
    (is (typep env '<dict>))
    (is (typep env '<unordered-collection>))
    
    ;; Check predicates
    (is (unwrap (<env>? env)))
    (is (unwrap (<dict>? env)))))

(test env-creation-empty
  "Test creating an empty environment"
  (let ((env (make-env)))
    (is (not (null env)))
    (is (null (fol.env:env-previous env)))
    ;; Items should be an empty FSet map
    (is (fset:empty? (fol.persistent:pslot-value env 'fol.collection::items)))))

(test env-creation-with-bindings
  "Test creating an environment with initial bindings"
  (let ((env (make-env nil 'x 10 'y 20 'z 30)))
    (is (not (null env)))
    (is (null (fol.env:env-previous env)))

    ;; Check that items were stored
    (let ((items (fol.persistent:pslot-value env 'fol.collection::items)))
      (is (eql (fset:lookup items 'x) 10))
      (is (eql (fset:lookup items 'y) 20))
      (is (eql (fset:lookup items 'z) 30)))))

(test env-lookup-in-current
  "Test looking up a variable in the current environment"
  (let ((env (make-env nil 'x 42 'y "hello")))
    (is (eql (fol.env:lookup env 'x) 42))
    (is (equal (fol.env:lookup env 'y) "hello"))))

(test env-lookup-not-found-single-env
  "Test that lookup signals unbound-variable error when variable not found"
  (let ((env (make-env nil 'x 10)))
    (signals fol.env:fol-unbound-variable
      (fol.env:lookup env 'undefined))))

(test env-chain-lookup
  "Test looking up variables in a chained environment"
  (let* ((outer (make-env nil 'x 1 'y 2))
         (inner (make-env outer 'y 20 'z 30)))
    ;; Inner should find its own bindings
    (is (eql (fol.env:lookup inner 'y) 20))
    (is (eql (fol.env:lookup inner 'z) 30))
    
    ;; Inner should fall back to outer for x
    (is (eql (fol.env:lookup inner 'x) 1))))

(test env-chain-shadowing
  "Test that inner environment bindings shadow outer ones"
  (let* ((outer (make-env nil 'x 1 'y 2 'z 3))
         (inner (make-env outer 'x 100 'y 200)))
    ;; Inner values shadow outer
    (is (eql (fol.env:lookup inner 'x) 100))
    (is (eql (fol.env:lookup inner 'y) 200))
    
    ;; Outer value still accessible if not shadowed
    (is (eql (fol.env:lookup inner 'z) 3))))

(test env-deep-chain-lookup
  "Test lookup through multiple nested environments"
  (let* ((env1 (make-env nil 'a 1))
         (env2 (make-env env1 'b 2))
         (env3 (make-env env2 'c 3))
         (env4 (make-env env3 'd 4)))
    ;; Can find variables from any level
    (is (eql (fol.env:lookup env4 'd) 4))
    (is (eql (fol.env:lookup env4 'c) 3))
    (is (eql (fol.env:lookup env4 'b) 2))
    (is (eql (fol.env:lookup env4 'a) 1))))

(test env-unbound-in-deep-chain
  "Test that unbound-variable is raised when variable not in any level"
  (let* ((env1 (make-env nil 'x 1))
         (env2 (make-env env1 'y 2))
         (env3 (make-env env2 'z 3)))
    (signals fol.env:fol-unbound-variable
      (fol.env:lookup env3 'undefined))))

(test env-unbound-variable-condition
  "Test the unbound-variable error condition properties"
  (let ((env (make-env nil 'x 10)))
    (handler-case
        (fol.env:lookup env 'missing-var)
      (fol.env:fol-unbound-variable (condition)
        (is (eql (fol.env:fol-unbound-variable-name condition) 'missing-var))
        (is (stringp (fol.env:fol-unbound-variable-message condition)))))))

(test env-with-various-types
  "Test that environments can store various types of values"
  (let ((env (make-env nil
                       'bool #t
                       'char #\A
                       'string "hello"
                       'symbol 'foo
                       'number 42
                       'list '(1 2 3)
                       'vector #(a b c))))
    ;; Boolean singletons are special and remain as FOL objects
    (is (unwrap (eq (fol.env:lookup env 'bool) *true-instance*)))
    ;; Native Lisp values are stored as-is, not wrapped
    (is (characterp (fol.env:lookup env 'char)))
    (is (stringp (fol.env:lookup env 'string)))
    (is (symbolp (fol.env:lookup env 'symbol)))
    (is (numberp (fol.env:lookup env 'number)))
    (is (listp (fol.env:lookup env 'list)))
    (is (vectorp (fol.env:lookup env 'vector)))))

(test env-is-dict
  "Test that <env> behaves as a <dict> for storage"
  (let ((env (make-env nil 'x 10 'y 20)))
    ;; Should be able to access the underlying items
    (let ((items (fol.persistent:pslot-value env 'fol.collection::items)))
      (is (eql (fset:lookup items 'x) 10))
      (is (eql (fset:lookup items 'y) 20)))))

(test env-lookup-nil-value
  "Test looking up variables that have nil as their value"
  (let ((env (make-env nil 'x nil 'y 10)))
    ;; Looking up a variable bound to nil should return nil
    (is (null (fol.env:lookup env 'x)))
    ;; But it should not trigger the unbound-variable error
    (is (not (null (fol.env:lookup env 'y))))))

(test env-previous-link
  "Test the previous environment link is properly maintained"
  (let* ((outer (make-env))
         (inner (make-env outer)))
    (is (eq (fol.env:env-previous inner) outer))
    (is (null (fol.env:env-previous outer)))))
