;;; FOL Compiler - Functional Operations Tests
;;;
;;; Tests for functional.lisp (regular functions) and
;;; functional special forms (defn-, definline, some->, some->>, as->).

(in-package :fol.compiler.tests)
(in-suite functional-tests)

;;; ===========================================================================
;;; Regular Functions (functional.lisp)
;;; ===========================================================================

;;; --- identity ---

(test identity-number
  "identity returns a number unchanged."
  (is (eql 42 (fol.compiler.functional:identity 42))))

(test identity-string
  "identity returns a string unchanged."
  (is (equal "hello" (fol.compiler.functional:identity "hello"))))

(test identity-nil
  "identity returns nil unchanged."
  (is (null (fol.compiler.functional:identity nil))))

(test identity-list
  "identity returns a list unchanged."
  (is (equal '(1 2 3) (fol.compiler.functional:identity '(1 2 3)))))

;;; --- constantly ---

(test constantly-returns-value
  "constantly returns a function that always returns the given value."
  (let ((f (fol.compiler.functional:constantly 42)))
    (is (eql 42 (funcall f)))
    (is (eql 42 (funcall f 1 2 3)))
    (is (eql 42 (funcall f :a :b)))))

(test constantly-nil
  "constantly with nil returns a function that always returns nil."
  (let ((f (fol.compiler.functional:constantly nil)))
    (is (null (funcall f)))
    (is (null (funcall f 1)))))

;;; --- comp ---

(test comp-no-args
  "comp with no args returns identity."
  (let ((f (fol.compiler.functional:comp)))
    (is (eql 42 (funcall f 42)))))

(test comp-single-fn
  "comp with one function returns that function."
  (let ((f (fol.compiler.functional:comp #'1+)))
    (is (eql 2 (funcall f 1)))))

(test comp-two-fns
  "comp with two functions composes right to left."
  (let ((f (fol.compiler.functional:comp #'1+ #'1+)))
    (is (eql 3 (funcall f 1)))))

(test comp-three-fns
  "comp with three functions composes right to left."
  (let ((f (fol.compiler.functional:comp #'car #'cdr #'cdr)))
    (is (eql 3 (funcall f '(1 2 3))))))

(test comp-rightmost-variadic
  "comp: rightmost function can accept multiple args."
  (let ((f (fol.compiler.functional:comp #'1+ #'+)))
    (is (eql 7 (funcall f 1 2 3)))))

;;; --- complement ---

(test complement-inverts
  "complement returns logical opposite of predicate."
  (let ((not-even (fol.compiler.functional:complement #'evenp)))
    (is (eq t (funcall not-even 3)))
    (is (null (funcall not-even 4)))))

(test complement-nil-result
  "complement of nil-returning function returns T."
  (let ((f (fol.compiler.functional:complement (lambda (x) (declare (ignore x)) nil))))
    (is (eq t (funcall f :anything)))))

;;; --- partial ---

(test partial-one-bound-arg
  "partial binds one argument."
  (let ((add10 (fol.compiler.functional:partial #'+ 10)))
    (is (eql 15 (funcall add10 5)))))

(test partial-two-bound-args
  "partial binds multiple arguments."
  (let ((add30 (fol.compiler.functional:partial #'+ 10 20)))
    (is (eql 35 (funcall add30 5)))))

(test partial-no-remaining-args
  "partial with all args bound can be called with no args."
  (let ((f (fol.compiler.functional:partial #'+ 1 2 3)))
    (is (eql 6 (funcall f)))))

;;; --- juxt ---

(test juxt-two-fns
  "juxt returns a list of results from each function."
  (let ((f (fol.compiler.functional:juxt #'1+ #'1-)))
    (is (equal '(6 4) (funcall f 5)))))

(test juxt-three-fns
  "juxt with three functions."
  (let ((f (fol.compiler.functional:juxt #'car #'cadr #'caddr)))
    (is (equal '(1 2 3) (funcall f '(1 2 3))))))

(test juxt-single-fn
  "juxt with single function returns single-element list."
  (let ((f (fol.compiler.functional:juxt #'1+)))
    (is (equal '(2) (funcall f 1)))))

;;; --- memoize ---

(test memoize-caches-result
  "memoize returns cached results for same arguments."
  (let* ((call-count 0)
         (f (fol.compiler.functional:memoize
             (lambda (x)
               (incf call-count)
               (* x x)))))
    (is (eql 25 (funcall f 5)))
    (is (eql 1 call-count))
    (is (eql 25 (funcall f 5)))
    (is (eql 1 call-count))  ; not called again
    (is (eql 9 (funcall f 3)))
    (is (eql 2 call-count))))

(test memoize-different-args
  "memoize caches per argument list."
  (let* ((f (fol.compiler.functional:memoize #'+)))
    (is (eql 3 (funcall f 1 2)))
    (is (eql 5 (funcall f 2 3)))))

;;; --- fnil ---

(test fnil-replaces-nil-args
  "fnil replaces nil arguments with defaults."
  (let ((f (fol.compiler.functional:fnil #'+ 0 0)))
    (is (eql 5 (funcall f nil 5)))
    (is (eql 3 (funcall f 3 nil)))
    (is (eql 0 (funcall f nil nil)))))

(test fnil-preserves-non-nil
  "fnil passes through non-nil arguments."
  (let ((f (fol.compiler.functional:fnil #'+ 100 100)))
    (is (eql 3 (funcall f 1 2)))))

;;; --- every-pred ---

(test every-pred-all-true
  "every-pred returns T when all predicates pass for all args."
  (let ((f (fol.compiler.functional:every-pred #'numberp #'plusp)))
    (is (eq t (funcall f 5)))))

(test every-pred-some-false
  "every-pred returns NIL when any predicate fails."
  (let ((f (fol.compiler.functional:every-pred #'numberp #'plusp)))
    (is (null (funcall f -1)))))

(test every-pred-multiple-args
  "every-pred checks all arguments against all predicates."
  (let ((f (fol.compiler.functional:every-pred #'numberp #'plusp)))
    (is (eq t (funcall f 5 3 1)))
    (is (null (funcall f 5 -1 1)))))

;;; --- some-fn ---

(test some-fn-first-truthy
  "some-fn returns first truthy result."
  (let ((f (fol.compiler.functional:some-fn #'evenp #'oddp)))
    (is (eq t (funcall f 3)))
    (is (eq t (funcall f 2)))))

(test some-fn-none-truthy
  "some-fn returns NIL when no function returns truthy."
  (let ((f (fol.compiler.functional:some-fn #'evenp)))
    (is (null (funcall f 3)))))

;;; --- apply ---

(test apply-basic
  "apply calls function with spread args."
  (is (eql 6 (fol.compiler.functional:apply #'+ '(1 2 3)))))

(test apply-mixed-args
  "apply with leading individual args and trailing list."
  (is (eql 10 (fol.compiler.functional:apply #'+ 1 2 '(3 4)))))

;;; --- trampoline ---

(test trampoline-non-function
  "trampoline returns non-function result immediately."
  (is (eql 6 (fol.compiler.functional:trampoline #'+ 1 2 3))))

(test trampoline-bouncing
  "trampoline repeatedly calls function results."
  (is (eql 42 (fol.compiler.functional:trampoline
               (lambda () (lambda () (lambda () 42)))))))

;;; ===========================================================================
;;; Special Forms
;;; ===========================================================================

;;; --- defn- ---

(test defn-private-compiles
  "defn- compiles to defun."
  (let* ((result (fol.compiler:compile-form (fol-form '(defn- helper #(x) (* x x)))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'defun (first code)))
    (is (eq 'helper (second code)))))

(test defn-private-executes
  "defn- produces a working defun."
  (let* ((result (fol.compiler:compile-form (fol-form '(defn- my-private-fn #(x) (+ x 1)))))
         (code (fol.compiler:compilation-result-code result)))
    (eval code)
    (is (eql 6 (funcall 'my-private-fn 5)))))

;;; --- definline ---

(test definline-compiles
  "definline compiles to progn with inline declaim and defun."
  (let* ((result (fol.compiler:compile-form (fol-form '(definline fast-add #(x y) (+ x y)))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'progn (first code)))
    ;; Second form should be (declaim (inline fast-add))
    (is (equal '(declaim (inline fast-add)) (second code)))
    ;; Third form should be defun
    (is (eq 'defun (first (third code))))))

(test definline-executes
  "definline produces a working inline function."
  (let* ((result (fol.compiler:compile-form (fol-form '(definline my-inline-fn #(x) (* x x)))))
         (code (fol.compiler:compilation-result-code result)))
    (eval code)
    (is (eql 25 (funcall 'my-inline-fn 5)))))

;;; --- some-> ---

(test some-thread-first-compiles
  "some-> compiles to nested let/when forms."
  (let* ((result (fol.compiler:compile-form '(some-> 1 identity)))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    ;; Should contain a LET
    (is (eq 'let (first code)))))

(test some-thread-first-non-nil
  "some-> threads value through when non-nil."
  (let* ((result (fol.compiler:compile-form '(some-> 5 1+ 1+)))
         (code (fol.compiler:compilation-result-code result)))
    (is (eql 7 (eval code)))))

(test some-thread-first-nil-short-circuit
  "some-> short-circuits on nil."
  (let* ((result (fol.compiler:compile-form
                  '(some-> 5 (progn nil) 1+)))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (eval code)))))

(test some-thread-first-initial-nil
  "some-> with nil initial value returns nil."
  (let* ((result (fol.compiler:compile-form '(some-> nil 1+)))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (eval code)))))

(test some-thread-first-single-form
  "some-> with no threading forms returns the expression."
  (let* ((result (fol.compiler:compile-form '(some-> 42)))
         (code (fol.compiler:compilation-result-code result)))
    (is (eql 42 (eval code)))))

;;; --- some->> ---

(test some-thread-last-compiles
  "some->> compiles to nested let/when forms."
  (let* ((result (fol.compiler:compile-form '(some->> 1 identity)))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'let (first code)))))

(test some-thread-last-non-nil
  "some->> threads value through as last arg when non-nil."
  (let* ((result (fol.compiler:compile-form '(some->> 5 1+ 1+)))
         (code (fol.compiler:compilation-result-code result)))
    (is (eql 7 (eval code)))))

(test some-thread-last-nil-short-circuit
  "some->> short-circuits on nil."
  (let* ((result (fol.compiler:compile-form
                  '(some->> 5 (cl:when nil) 1+)))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (eval code)))))

(test some-thread-last-initial-nil
  "some->> with nil initial value returns nil."
  (let* ((result (fol.compiler:compile-form '(some->> nil 1+)))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (eval code)))))

;;; --- as-> ---

(test as-thread-compiles
  "as-> compiles to nested let bindings."
  (let* ((result (fol.compiler:compile-form '(as-> 1 x (+ x 1))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'let (first code)))))

(test as-thread-basic
  "as-> binds expression to name and threads through forms."
  (let* ((result (fol.compiler:compile-form '(as-> 5 x (+ x 1) (* x 2))))
         (code (fol.compiler:compilation-result-code result)))
    (is (eql 12 (eval code)))))

(test as-thread-flexible-position
  "as-> allows name to appear in any position."
  (let* ((result (fol.compiler:compile-form '(as-> 5 x (- 10 x) (- x 1))))
         (code (fol.compiler:compilation-result-code result)))
    (is (eql 4 (eval code)))))

(test as-thread-single-value
  "as-> with no forms returns the expression."
  (let* ((result (fol.compiler:compile-form '(as-> 42 x)))
         (code (fol.compiler:compilation-result-code result)))
    (is (eql 42 (eval code)))))

(test as-thread-multiple-forms
  "as-> threads through multiple forms."
  (let* ((result (fol.compiler:compile-form
                  '(as-> 0 v (+ v 1) (+ v 2) (* v 3))))
         (code (fol.compiler:compilation-result-code result)))
    (is (eql 9 (eval code)))))
