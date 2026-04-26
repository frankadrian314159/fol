;;; FOL Compiler Tests - defclass, defgeneric, defmethod, enhanced destructuring

(in-package :fol.compiler.tests)

(in-suite oop-tests)

;;; ---------------------------------------------------------------------------
;;; defclass
;;; ---------------------------------------------------------------------------

(test compile-defclass-simple
  "defclass compiles to progn with CL defclass, constructor, and quoted name."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(defclass <trade> #(<persistent-object>)
                               #(#(symbol :initarg :symbol :accessor trade-symbol)
                                 #(amount :initarg :amount :accessor trade-amount))))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    ;; Should be (progn (defclass ...) (defun make-...) '<trade>)
    (is (eq 'progn (first code)))
    (let ((defclass-form (second code)))
      (is (eq 'defclass (first defclass-form)))
      (is (eq '<trade> (second defclass-form)))
      ;; Superclasses should contain the persistent-object class
      (is (= 1 (length (third defclass-form))))
      (is (eq 'fol.compiler.persistent:<persistent-object>
              (first (third defclass-form))))
      ;; Slots should be a list of lists
      (is (= 2 (length (fourth defclass-form))))
      (is (eq 'symbol (first (first (fourth defclass-form)))))
      (is (eq 'amount (first (second (fourth defclass-form)))))
      ;; Should have metaclass
      (is (equal '(:metaclass fol.compiler.persistent:persistent-class)
                 (fifth defclass-form))))
    ;; Should contain accessor functions and a constructor
    ;; Find the constructor (defun make-<trade> ...)
    (let ((constructor (find-if (lambda (form)
                                  (and (listp form)
                                       (eq 'defun (first form))
                                       (string= "MAKE-<TRADE>"
                                                 (symbol-name (second form)))))
                                (rest code))))
      (is (not (null constructor)))
      (is (eq 'defun (first constructor))))
    ;; Should contain direct accessor functions
    (let ((accessors (remove-if-not
                       (lambda (form)
                         (and (listp form)
                              (eq 'defun (first form))
                              (member (symbol-name (second form))
                                      '("TRADE-SYMBOL" "TRADE-AMOUNT")
                                      :test #'string=)))
                       (rest code))))
      (is (= 2 (length accessors))))))

(test compile-defclass-empty-supers
  "defclass with empty supers defaults to <persistent-object>."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(defclass <point> #()
                               #(#(x :initarg :x)
                                 #(y :initarg :y))))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'progn (first code)))
    (let ((defclass-form (second code)))
      ;; Empty supers should default to (<persistent-object>)
      (is (= 1 (length (third defclass-form))))
      (is (eq 'fol.compiler.persistent:<persistent-object>
              (first (third defclass-form))))
      ;; Should have metaclass
      (is (equal '(:metaclass fol.compiler.persistent:persistent-class)
                 (fifth defclass-form)))
      ;; Should have 2 slots
      (is (= 2 (length (fourth defclass-form)))))))

;;; ---------------------------------------------------------------------------
;;; defclass - :abstract option
;;; ---------------------------------------------------------------------------

(test compile-defclass-abstract
  "defclass with :abstract true emits an initialize-instance :before guard."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(defclass <abstract-test-widget> #()
                               #() :abstract true))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    ;; Should emit a (defmethod initialize-instance :before ...) form
    (let ((guard (find-if (lambda (form)
                            (and (listp form)
                                 (eq 'defmethod (first form))
                                 (eq 'initialize-instance (second form))
                                 (eq :before (third form))))
                          (rest code))))
      (is (not (null guard)) "abstract guard method should be emitted")
      ;; Guard should reference class-of and find-class to detect direct instantiation
      (is (find 'class-of (flatten-form guard))
          "guard should call class-of to detect direct instantiation")
      (is (find 'find-class (flatten-form guard))
          "guard should call find-class to compare class identity"))))

(test compile-defclass-abstract-false
  "defclass with :abstract false does not emit an initialize-instance guard."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(defclass <concrete-test-widget> #() #() :abstract false))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    ;; Should NOT contain any initialize-instance :before method
    (let ((guard (find-if (lambda (form)
                            (and (listp form)
                                 (eq 'defmethod (first form))
                                 (eq 'initialize-instance (second form))))
                          (rest code))))
      (is (null guard) "no abstract guard should be emitted when :abstract is false"))))

(test compile-defclass-abstract-subclass-allowed
  "Subclass of an abstract class does not itself emit an abstract guard."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(defclass <concrete-sub-widget> #(<abstract-test-widget>)
                               #()))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (let ((guard (find-if (lambda (form)
                            (and (listp form)
                                 (eq 'defmethod (first form))
                                 (eq 'initialize-instance (second form))
                                 (eq :before (third form))))
                          (rest code))))
      (is (null guard) "concrete subclass should not have an abstract guard"))))

;;; ---------------------------------------------------------------------------
;;; defclass - :sealed option
;;; ---------------------------------------------------------------------------

(test compile-defclass-sealed-registers
  "defclass with :sealed true registers the class name in *sealed-classes*."
  ;; Remove any stale entry before testing
  (remhash "<TEST-SEALED-BASE>" fol.compiler::*sealed-classes*)
  (unwind-protect
      (progn
        (fol.compiler:compile-form
         (fol-form '(defclass <test-sealed-base> #() #() :sealed true)))
        (is (gethash "<TEST-SEALED-BASE>" fol.compiler::*sealed-classes*)
            "sealed class name should be registered in *sealed-classes*"))
    (remhash "<TEST-SEALED-BASE>" fol.compiler::*sealed-classes*)))

(test compile-defclass-unsealed-not-registered
  "defclass without :sealed does not register in *sealed-classes*."
  (remhash "<TEST-UNSEALED-BASE>" fol.compiler::*sealed-classes*)
  (fol.compiler:compile-form
   (fol-form '(defclass <test-unsealed-base> #() #())))
  (is (null (gethash "<TEST-UNSEALED-BASE>" fol.compiler::*sealed-classes*))
      "non-sealed class should not be in *sealed-classes*"))

(test compile-defclass-sealed-inheritance-error
  "Inheriting from a sealed class signals a compiler error at compile time."
  ;; Inject a sealed class name directly to avoid test-ordering dependencies
  (setf (gethash "<TEST-SEALED-INJECTED>" fol.compiler::*sealed-classes*) t)
  (unwind-protect
      (let ((errored-p nil))
        (handler-case
            (fol.compiler:compile-form
             (fol-form '(defclass <test-sealed-child> #(<test-sealed-injected>) #())))
          (error () (setf errored-p t)))
        (is (eq t errored-p) "inheriting from a sealed class should signal a compile-time error"))
    (remhash "<TEST-SEALED-INJECTED>" fol.compiler::*sealed-classes*)))

(test compile-defclass-sealed-no-own-guard
  "defclass with :sealed does not itself emit an abstract guard (sealed != abstract)."
  (remhash "<TEST-SEALED-ONLY>" fol.compiler::*sealed-classes*)
  (unwind-protect
      (let* ((result (fol.compiler:compile-form
                      (fol-form '(defclass <test-sealed-only> #() #() :sealed true))))
             (code (fol.compiler:compilation-result-code result)))
        (is (null (fol.compiler:compilation-result-errors result)))
        (let ((guard (find-if (lambda (form)
                                (and (listp form)
                                     (eq 'defmethod (first form))
                                     (eq 'initialize-instance (second form))
                                     (eq :before (third form))))
                              (rest code))))
          (is (null guard) "a sealed (but not abstract) class should not emit an instantiation guard")))
    (remhash "<TEST-SEALED-ONLY>" fol.compiler::*sealed-classes*)))

;;; ---------------------------------------------------------------------------
;;; defgeneric - single pattern
;;; ---------------------------------------------------------------------------

(test compile-defgeneric-simple
  "Single-pattern defgeneric compiles to CL defgeneric."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(defgeneric validate-trade #(trade)))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'defgeneric (first code)))
    (is (eq 'validate-trade (second code)))
    (is (equal '(trade) (third code)))))

(test compile-defgeneric-multi-param
  "defgeneric with multiple params."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(defgeneric distance #(a b)))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'defgeneric (first code)))
    (is (equal '(a b) (third code)))))

;;; ---------------------------------------------------------------------------
;;; defgeneric - multi-pattern
;;; ---------------------------------------------------------------------------

(test compile-defgeneric-multi-pattern
  "Multi-pattern defgeneric creates internal generics + dispatcher."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(defgeneric foo (#(x) #(x y))))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    ;; Should be a progn with generic defs and dispatcher
    (is (eq 'progn (first code)))
    ;; Should contain defgeneric forms for internal names
    (let ((generics (remove-if-not (lambda (f) (and (listp f) (eq 'defgeneric (first f))))
                                   (rest code))))
      (is (= 2 (length generics))))
    ;; Should contain a defun dispatcher
    (let ((defuns (remove-if-not (lambda (f) (and (listp f) (eq 'defun (first f))))
                                 (rest code))))
      (is (= 1 (length defuns)))
      (is (eq 'foo (second (first defuns)))))))

;;; ---------------------------------------------------------------------------
;;; defmethod - single clause
;;; ---------------------------------------------------------------------------

(test compile-defmethod-single-simple
  "Single-clause defmethod with simple params compiles to CL defmethod."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(defmethod validate-trade #(trade) trade))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'defmethod (first code)))
    (is (eq 'validate-trade (second code)))
    (is (equal '(trade) (third code)))))

(test compile-defmethod-single-specialized
  "Single-clause defmethod with type specializer compiles to dispatched defmethod."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(defmethod process #((x <number>)) x))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    ;; Specialized params should produce a defmethod with dispatch
    (is (eq 'defmethod (first code)))))

;;; ---------------------------------------------------------------------------
;;; defmethod - multi-clause
;;; ---------------------------------------------------------------------------

(test compile-defmethod-multi-clause
  "Multi-clause defmethod produces a defmethod with cond dispatch."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(defmethod validate
                              (#((x <number>)) x)
                              (#(x) x)))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'defmethod (first code)))
    (is (eq 'validate (second code)))
    ;; Same-arity clauses use fixed params (no &rest)
    (is (= 1 (length (third code))))
    (is (not (member '&rest (third code))))
    ;; Body should have cond
    (let ((body (cdddr code)))
      (is (find 'cond body :key #'car)))))

(test compile-defmethod-multi-clause-arity-ordering
  "Multi-clause defmethod orders by arity."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(defmethod foo
                              (#(a b) (+ a b))
                              (#(a) a)))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (let* ((body (cdddr code))
           (cond-form (find 'cond body :key #'car)))
      (is (not (null cond-form)))
      ;; First clause should check arity 1
      (is (find 1 (flatten-form (first (second cond-form)))))
      ;; Second clause should check arity 2
      (is (find 2 (flatten-form (first (third cond-form))))))))

(test compile-defmethod-multi-clause-specificity
  "Multi-clause defmethod orders by specificity within same arity."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(defmethod handler
                              (#(x) x)
                              (#((x <number>)) (* x 2))))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (let* ((body (cdddr code))
           (cond-form (find 'cond body :key #'car)))
      (is (not (null cond-form)))
      ;; First clause should have typep (more specific)
      (is (find 'typep (flatten-form (first (second cond-form)))))
      ;; Second clause should not have typep (less specific)
      (is (not (find 'typep (flatten-form (first (third cond-form)))))))))

;;; ---------------------------------------------------------------------------
;;; defmethod - fixed-arity optimization
;;; ---------------------------------------------------------------------------

(test compile-defmethod-uniform-arity-fixed-params
  "Uniform-arity multi-clause defmethod uses fixed params, not &rest."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(defmethod handler
                              (#(x) x)
                              (#((x <number>)) (* x 2))))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'defmethod (first code)))
    ;; Fixed params: exactly 1 param, no &rest
    (is (= 1 (length (third code))))
    (is (not (member '&rest (third code))))))

(test compile-defmethod-mixed-arity-uses-rest
  "Mixed-arity multi-clause defmethod still uses &rest."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(defmethod foo
                              (#(a b) (+ a b))
                              (#(a) a)))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'defmethod (first code)))
    ;; Mixed arities require &rest
    (is (member '&rest (third code)))))

;;; ---------------------------------------------------------------------------
;;; Enhanced destructuring - :key
;;; ---------------------------------------------------------------------------

(test parse-params-with-key
  "parse-params handles :key parameters."
  (multiple-value-bind (regular rest-param key-params defaults as-param)
      (fol.compiler.destructure:parse-params '(a b :key c d))
    (is (equal '(a b) regular))
    (is (null rest-param))
    (is (equal '(c d) key-params))
    (is (null defaults))
    (is (null as-param))))

(test parse-params-with-or
  "parse-params handles :or defaults."
  (multiple-value-bind (regular rest-param key-params defaults as-param)
      (fol.compiler.destructure:parse-params (list 'a 'b :or (fol-form #(10 20))))
    (is (equal '(a b) regular))
    (is (null rest-param))
    (is (null key-params))
    (is (typep defaults 'fol.compiler.collections:<vector>))
    (is (null as-param))))

(test parse-params-with-as
  "parse-params handles :as whole binding."
  (multiple-value-bind (regular rest-param key-params defaults as-param)
      (fol.compiler.destructure:parse-params '(a b :as all))
    (is (equal '(a b) regular))
    (is (null rest-param))
    (is (null key-params))
    (is (null defaults))
    (is (eq 'all as-param))))

(test parse-params-combined
  "parse-params handles &, :key, and :as together."
  (multiple-value-bind (regular rest-param key-params defaults as-param)
      (fol.compiler.destructure:parse-params '(a b & more :key verbose :as all))
    (is (equal '(a b) regular))
    (is (eq 'more rest-param))
    (is (equal '(verbose) key-params))
    (is (null defaults))
    (is (eq 'all as-param))))

;;; ---------------------------------------------------------------------------
;;; Enhanced destructuring - fn with :key
;;; ---------------------------------------------------------------------------

(test compile-fn-with-key
  "fn with :key params produces &key in lambda list."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(fn #(a b :key verbose) (list a b verbose)))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'lambda (first code)))
    (is (member '&key (second code)))
    (is (member 'verbose (second code)))))

(test compile-fn-with-key-and-or
  "fn with :key and :or produces &key with defaults."
  (let* ((result (fol.compiler:compile-form
                  (list 'fn (fol.compiler.collection-functions:vector 'a :key 'verbose :or (fol.compiler.collection-functions:vector nil)) '(list a verbose))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'lambda (first code)))
    (is (member '&key (second code)))))

;;; ---------------------------------------------------------------------------
;;; Multiple values assignment
;;; ---------------------------------------------------------------------------

(test compile-bind-simple
  "Simple bind works with vector bindings."
  (let* ((result (fol.compiler:compile-form
                  '(bind (x 1) x)))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    ;; Should contain a let binding
    (is (find 'let (flatten-form code)))))

(test compile-bind-vector-pattern
  "Bind with vector pattern emits destructuring."
  (let* ((result (fol.compiler:compile-form
                  (list 'bind (list (fol-form #(a b)) '(values 1 2)) '(+ a b))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    ;; Should contain multiple-value-list for MV capture
    (is (find 'multiple-value-list (flatten-form code)))))

;;; ---------------------------------------------------------------------------
;;; Utility (reuse from test-destructure.lisp)
;;; ---------------------------------------------------------------------------

;; flatten-form is already defined in test-destructure.lisp

;;; ---------------------------------------------------------------------------
;;; prefer-method tests
;;; ---------------------------------------------------------------------------

(test prefer-method-simple
  "prefer-method establishes preference and maintains DAG"
  (let ((gf-name 'test-gf))
    (remhash gf-name fol.compiler::*method-preferences*)
    (fol.compiler:prefer-method gf-name :a :b)
    (fol.compiler:prefer-method gf-name :b :c)
    (let ((prefs (gethash gf-name fol.compiler::*method-preferences*)))
      (is (not (null prefs)))
      (is (member :a (gethash :b prefs)))
      (is (member :b (gethash :c prefs)))
      (is (null (gethash :a prefs))))))

(test prefer-method-cycle-detection
  "prefer-method signals program-error on circular preference"
  (let ((gf-name 'test-gf-cycle))
    (remhash gf-name fol.compiler::*method-preferences*)
    (fol.compiler:prefer-method gf-name :a :b)
    (fol.compiler:prefer-method gf-name :b :c)
    (let ((errored-p nil))
      (handler-case
          (fol.compiler:prefer-method gf-name :c :a) ; C prefers A -> wait, args are (gf preferred subservient)
        (program-error () (setf errored-p t)))
      (is (eq t errored-p) "Cyclic preference should signal program-error"))))
