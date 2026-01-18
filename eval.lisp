(in-package fol.eval)

;;; ============================================================================
;;; FOL Evaluator - Clojure-style let and lambda
;;; ============================================================================

;;; Generic evaluation function
(defgeneric fol-eval (expr env)
  (:documentation "Evaluate an expression in the given environment.
                   Supports:
                   - Self-evaluating values (FOL wrapped types)
                   - Symbols (variable lookup)
                   - Lists (special forms and function application)"))

;;; ============================================================================
;;; Self-evaluating types (FOL wrapped types AND native CL types for convenience)
;;; ============================================================================

;; FOL wrapped types
(defmethod fol-eval ((expr fol.classes:<number>) env)
  "FOL numbers evaluate to themselves."
  (declare (ignore env))
  expr)

(defmethod fol-eval ((expr fol.classes:<string>) env)
  "FOL strings evaluate to themselves."
  (declare (ignore env))
  expr)

(defmethod fol-eval ((expr fol.classes:<bool>) env)
  "FOL boolean singletons evaluate to themselves."
  (declare (ignore env))
  expr)

(defmethod fol-eval ((expr fol.classes:<char>) env)
  "FOL characters evaluate to themselves."
  (declare (ignore env))
  expr)

(defmethod fol-eval ((expr fol.classes:<symbol>) env)
  "FOL symbols look up their variable value."
  (fol.env:lookup env (fol.classes:fol-value expr)))

;; Native CL types for convenience (auto-wrap to FOL)
(defmethod fol-eval ((expr number) env)
  "Native CL numbers evaluate to themselves."
  (declare (ignore env))
  expr)

(defmethod fol-eval ((expr string) env)
  "Native CL strings evaluate to themselves."
  (declare (ignore env))
  expr)

(defmethod fol-eval ((expr character) env)
  "Native CL characters evaluate to themselves."
  (declare (ignore env))
  expr)

(defmethod fol-eval ((expr null) env)
  "NIL evaluates to itself."
  (declare (ignore env))
  nil)

;;; ============================================================================
;;; Native CL Symbol evaluation (for special forms and variable lookup)
;;; ============================================================================

(defmethod fol-eval ((expr symbol) env)
  "CL Symbols are looked up in the environment (used for special forms)."
  (fol.env:lookup env expr))

;;; ============================================================================
;;; List evaluation (special forms and application)
;;; ============================================================================

(defmethod fol-eval ((expr cons) env)
  "Lists are either special forms or function applications."
  (let ((operator (car expr))
        (args (cdr expr)))
    (cond
      ;; Special form: (let [bindings] body)
      ((and (symbolp operator) (string= (symbol-name operator) "LET"))
       (eval-let args env))

      ;; Special form: (lambda [params] body)
      ((and (symbolp operator) (string= (symbol-name operator) "LAMBDA"))
       (eval-lambda args env))

      ;; Special form: (fn [params] body) - Clojure synonym for lambda
      ((and (symbolp operator) (string= (symbol-name operator) "FN"))
       (eval-lambda args env))

      ;; Special form: (quote expr)
      ((and (symbolp operator) (string= (symbol-name operator) "QUOTE"))
       (car args))

      ;; Special form: (if test then else)
      ((and (symbolp operator) (string= (symbol-name operator) "IF"))
       (eval-if args env))

      ;; Function application
      (t
       (eval-application operator args env)))))

;;; ============================================================================
;;; Special Form: let
;;; Clojure-style: (let [x 10 y 20] (+ x y))
;;; ============================================================================

(defun eval-let (args env)
  "Evaluate a let expression.
   Syntax: (let [var1 val1 var2 val2 ...] body)
   Creates a new environment with bindings and evaluates body."
  (unless (>= (length args) 2)
    (error "let requires at least 2 arguments: bindings and body"))

  (let ((bindings (car args))
        (body (cdr args)))

    ;; Check that bindings is a vector (list in our case)
    (unless (listp bindings)
      (error "let bindings must be a vector/list"))

    ;; Check that bindings has even number of elements
    (unless (evenp (length bindings))
      (error "let bindings must have even number of elements"))

    ;; Create new environment with bindings
    (let ((new-env env))
      ;; Evaluate each binding in sequence, extending environment
      (loop for (var val-expr) on bindings by #'cddr
            do (let ((val (fol-eval val-expr new-env)))
                 (setf new-env (fol.env:make-env new-env var val))))

      ;; Evaluate body forms in sequence, return last
      (let ((result nil))
        (dolist (form body result)
          (setf result (fol-eval form new-env)))))))

;;; ============================================================================
;;; Special Form: lambda/fn
;;; Clojure-style: (lambda [x y] (+ x y))
;;; ============================================================================

(defclass <closure> ()
  ((params :initarg :params :accessor closure-params)
   (body :initarg :body :accessor closure-body)
   (env :initarg :env :accessor closure-env))
  (:documentation "A closure created by lambda/fn"))

(defmethod print-object ((obj <closure>) stream)
  (format stream "#<closure ~A>" (closure-params obj)))

(defun eval-lambda (args env)
  "Evaluate a lambda expression.
   Syntax: (lambda [param1 param2 ...] body-form1 body-form2 ...)
   Returns a closure."
  (unless (>= (length args) 2)
    (error "lambda requires at least 2 arguments: parameters and body"))

  (let ((params (car args))
        (body (cdr args)))

    ;; Check that params is a list
    (unless (listp params)
      (error "lambda parameters must be a vector/list"))

    ;; Check that all params are symbols
    (dolist (param params)
      (unless (symbolp param)
        (error "lambda parameter must be a symbol: ~S" param)))

    ;; Create and return closure
    (make-instance '<closure>
                   :params params
                   :body body
                   :env env)))

;;; ============================================================================
;;; Special Form: if
;;; Syntax: (if test then-expr else-expr)
;;; ============================================================================

(defun eval-if (args env)
  "Evaluate an if expression."
  (unless (or (= (length args) 2) (= (length args) 3))
    (error "if requires 2 or 3 arguments: test, then, and optional else"))

  (let ((test (car args))
        (then-expr (cadr args))
        (else-expr (caddr args)))

    (let ((test-val (fol-eval test env)))
      ;; In FOL, nil and #f are falsy, everything else is truthy
      (if (or (null test-val)
              (eq test-val fol.singleton:*false-instance*))
          (if else-expr
              (fol-eval else-expr env)
              nil)
          (fol-eval then-expr env)))))

;;; ============================================================================
;;; Function Application
;;; ============================================================================

(defun eval-application (operator args env)
  "Apply a function to arguments."
  (let ((fn (fol-eval operator env))
        (arg-vals (mapcar (lambda (arg) (fol-eval arg env)) args)))
    (apply-function fn arg-vals)))

(defgeneric apply-function (fn args)
  (:documentation "Apply a function to evaluated arguments."))

(defmethod apply-function ((fn <closure>) args)
  "Apply a closure to arguments."
  (let ((params (closure-params fn))
        (body (closure-body fn))
        (env (closure-env fn)))

    ;; Check argument count
    (unless (= (length params) (length args))
      (error "Function expects ~D arguments but got ~D"
             (length params) (length args)))

    ;; Create new environment binding parameters to arguments
    (let ((new-env env))
      (loop for param in params
            for arg in args
            do (setf new-env (fol.env:make-env new-env param arg)))

      ;; Evaluate body forms in sequence, return last
      (let ((result nil))
        (dolist (form body result)
          (setf result (fol-eval form new-env)))))))

(defmethod apply-function ((fn function) args)
  "Apply a native Lisp function to arguments."
  (apply fn args))

;;; ============================================================================
;;; Primitive Operations
;;; ============================================================================
;;; We can bind primitive operations in the initial environment

(defun make-initial-env ()
  "Create an initial environment with FOL primitive operations.
   Binds operations using both CL and FOL package symbols for cross-package compatibility."
  (let ((env (fol.env:make-env nil)))
    ;; Bind FOL arithmetic operations using both CL and FOL.ARITHOP package symbols
    ;; This ensures they work from any package context
    (setf env (fol.env:make-env env (intern "+" :cl) (function fol.arithop:+)))
    (setf env (fol.env:make-env env (find-symbol "+" :fol.arithop) (function fol.arithop:+)))
    (setf env (fol.env:make-env env (intern "-" :cl) (function fol.arithop:-)))
    (setf env (fol.env:make-env env (find-symbol "-" :fol.arithop) (function fol.arithop:-)))
    (setf env (fol.env:make-env env (intern "*" :cl) (function fol.arithop:*)))
    (setf env (fol.env:make-env env (find-symbol "*" :fol.arithop) (function fol.arithop:*)))
    (setf env (fol.env:make-env env (intern "/" :cl) (function fol.arithop:/)))
    (setf env (fol.env:make-env env (find-symbol "/" :fol.arithop) (function fol.arithop:/)))

    ;; Bind FOL comparison operations
    (setf env (fol.env:make-env env (intern "=" :cl) (function fol.compareop:=)))
    (setf env (fol.env:make-env env (find-symbol "=" :fol.compareop) (function fol.compareop:=)))
    (setf env (fol.env:make-env env (intern "<" :cl) (function fol.compareop:<)))
    (setf env (fol.env:make-env env (find-symbol "<" :fol.compareop) (function fol.compareop:<)))
    (setf env (fol.env:make-env env (intern ">" :cl) (function fol.compareop:>)))
    (setf env (fol.env:make-env env (find-symbol ">" :fol.compareop) (function fol.compareop:>)))
    (setf env (fol.env:make-env env (intern "<=" :cl) (function fol.compareop:<=)))
    (setf env (fol.env:make-env env (find-symbol "<=" :fol.compareop) (function fol.compareop:<=)))
    (setf env (fol.env:make-env env (intern ">=" :cl) (function fol.compareop:>=)))
    (setf env (fol.env:make-env env (find-symbol ">=" :fol.compareop) (function fol.compareop:>=)))

    ;; Bind FOL logical operations
    (setf env (fol.env:make-env env (intern "NOT" :cl) (function fol.logop:not)))
    (setf env (fol.env:make-env env (find-symbol "NOT" :fol.logop) (function fol.logop:not)))
    (setf env (fol.env:make-env env (intern "AND" :cl) (function fol.logop:and)))
    (setf env (fol.env:make-env env (find-symbol "AND" :fol.logop) (function fol.logop:and)))
    (setf env (fol.env:make-env env (intern "OR" :cl) (function fol.logop:or)))
    (setf env (fol.env:make-env env (find-symbol "OR" :fol.logop) (function fol.logop:or)))

    ;; Bind FOL collection operations (both CL list operations and FOL constructors)
    (setf env (fol.env:make-env env (intern "LIST" :cl) (function cl:list)))
    (setf env (fol.env:make-env env (intern "CONS" :cl) (function cl:cons)))
    (setf env (fol.env:make-env env (intern "CAR" :cl) (function cl:car)))
    (setf env (fol.env:make-env env (intern "CDR" :cl) (function cl:cdr)))

    ;; Bind FOL collection constructors (for FOL syntax support)
    (setf env (fol.env:make-env env (find-symbol "MAKE-VECTOR" :fol.collection) (function fol.collection:make-vector)))
    (setf env (fol.env:make-env env (find-symbol "MAKE-DICT" :fol.collection) (function fol.collection:make-dict)))
    (setf env (fol.env:make-env env (find-symbol "MAKE-SET" :fol.collection) (function fol.collection:make-set)))
    (setf env (fol.env:make-env env (find-symbol "MAKE-BAG" :fol.collection) (function fol.collection:make-bag)))

    ;; Bind FOL boolean singletons (for #t and #f syntax support)
    (setf env (fol.env:make-env env (find-symbol "*TRUE-INSTANCE*" :fol.singleton) fol.singleton:*true-instance*))
    (setf env (fol.env:make-env env (find-symbol "*FALSE-INSTANCE*" :fol.singleton) fol.singleton:*false-instance*))

    ;; Bind predicates
    (setf env (fol.env:make-env env (intern "NULL?" :cl-user) (function cl:null)))
    (setf env (fol.env:make-env env (intern "EQ?" :cl-user) (function cl:eq)))
    (setf env (fol.env:make-env env (intern "EQUAL?" :cl-user) (function cl:equal)))

    env))

;;; ============================================================================
;;; Top-level eval convenience function
;;; ============================================================================

(defun fol-eval-toplevel (expr)
  "Evaluate an expression in the initial environment."
  (fol-eval expr (make-initial-env)))
