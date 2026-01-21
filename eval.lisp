(in-package fol.eval)

;;; ============================================================================
;;; FOL Evaluator
;;; ============================================================================
;;; A Lisp evaluator that takes a form and an environment and evaluates
;;; the form in the context of the environment.
;;;
;;; Supports:
;;; - Self-evaluating forms: numbers, strings, characters, keywords, booleans
;;; - Symbol lookup via environment
;;; - Special forms: quote, if, do, let, let*, fn, def, set!, loop/recur, throw/try
;;; - Function application (both built-in and user-defined)
;;; - Collection literals: vectors, dicts, sets
;;;
;;; All results are returned as raw CL values where applicable.
;;; ============================================================================

;;; ============================================================================
;;; Error Conditions
;;; ============================================================================

(define-condition fol-eval-error (error)
  ((message :initarg :message :accessor fol-eval-error-message)
   (form :initarg :form :accessor fol-eval-error-form :initform nil))
  (:report (lambda (condition stream)
             (format stream "Evaluation error: ~A" (fol-eval-error-message condition)))))

(define-condition fol-arity-error (fol-eval-error)
  ((expected :initarg :expected :accessor fol-arity-error-expected)
   (got :initarg :got :accessor fol-arity-error-got))
  (:report (lambda (condition stream)
             (format stream "Arity error: expected ~A arguments, got ~A"
                     (fol-arity-error-expected condition)
                     (fol-arity-error-got condition)))))

;;; ============================================================================
;;; FOL Function Representation
;;; ============================================================================

(defclass <function> (fol.persistent:<persistent-object>)
  ((params :initarg :params :accessor function-params :type list)
   (body :initarg :body :accessor function-body :type list)
   (env :initarg :env :accessor function-env)
   (rest-param :initarg :rest-param :accessor function-rest-param :initform nil)
   (name :initarg :name :accessor function-name :initform nil))
  (:metaclass fol.persistent:persistent-class)
  (:documentation "A user-defined FOL function with captured lexical environment."))

(defun <function>? (obj)
  "Returns T if OBJ is a FOL function."
  (typep obj '<function>))

(defun make-function (params body env &key rest-param name)
  "Create a new FOL function with the given parameters, body, and closure environment."
  (make-instance '<function>
                 :params params
                 :body body
                 :env env
                 :rest-param rest-param
                 :name name))

;;; ============================================================================
;;; Recur Exception (for loop/recur)
;;; ============================================================================

(define-condition recur-signal ()
  ((args :initarg :args :accessor recur-args))
  (:documentation "Signal used to implement recur within loop."))

;;; ============================================================================
;;; Main Evaluation Function
;;; ============================================================================

(defgeneric fol-eval (form env)
  (:documentation "Evaluate FORM in the context of environment ENV.
                   Returns the result of evaluation."))

;;; --- Self-Evaluating Forms ---

(defmethod fol-eval ((form (eql t)) env)
  "T is self-evaluating."
  (declare (ignore env))
  t)

(defmethod fol-eval ((form (eql nil)) env)
  "NIL is self-evaluating."
  (declare (ignore env))
  nil)

(defmethod fol-eval ((form number) env)
  "Numbers are self-evaluating."
  (declare (ignore env))
  form)

(defmethod fol-eval ((form string) env)
  "Strings are self-evaluating."
  (declare (ignore env))
  form)

(defmethod fol-eval ((form character) env)
  "Characters are self-evaluating."
  (declare (ignore env))
  form)

;;; --- Wrapped FOL Values are Self-Evaluating ---

(defmethod fol-eval ((form <bool>) env)
  "Wrapped booleans are self-evaluating, return raw value."
  (declare (ignore env))
  (fol-value form))

(defmethod fol-eval ((form <number>) env)
  "Wrapped numbers are self-evaluating, return raw value."
  (declare (ignore env))
  (fol-value form))

(defmethod fol-eval ((form <char>) env)
  "Wrapped characters are self-evaluating, return raw value."
  (declare (ignore env))
  (fol-value form))

(defmethod fol-eval ((form <string>) env)
  "Wrapped strings are self-evaluating, return raw value."
  (declare (ignore env))
  (fol-value form))

(defmethod fol-eval ((form <keyword>) env)
  "Wrapped keywords are self-evaluating, return raw value."
  (declare (ignore env))
  (fol-value form))

;;; --- FOL Collections are Self-Evaluating ---

(defmethod fol-eval ((form <collection>) env)
  "Collections are self-evaluating."
  (declare (ignore env))
  form)

;;; --- FOL Functions are Self-Evaluating ---

(defmethod fol-eval ((form <function>) env)
  "FOL functions are self-evaluating."
  (declare (ignore env))
  form)

;;; --- CL Functions are Self-Evaluating ---

(defmethod fol-eval ((form function) env)
  "CL functions are self-evaluating."
  (declare (ignore env))
  form)

;;; --- Symbol Lookup ---

(defmethod fol-eval ((form symbol) env)
  "Symbols are looked up in the environment. Keywords are self-evaluating."
  (if (keywordp form)
      form
      (lookup env form)))

;;; --- Wrapped Symbol Lookup ---

(defmethod fol-eval ((form <symbol>) env)
  "Wrapped symbols are looked up using their raw symbol value."
  (lookup env (fol-value form)))

;;; --- List Forms (Special Forms and Function Application) ---

(defmethod fol-eval ((form cons) env)
  "Evaluate a list form. Dispatch on the operator."
  (let ((op (car form))
        (args (cdr form)))
    (cond
      ;; Special forms - compare by symbol name for package independence
      ((special-form-p op 'quote)  (eval-quote args env))
      ((special-form-p op 'if)     (eval-if args env))
      ((special-form-p op 'do)     (eval-do args env))
      ((special-form-p op 'bind)   (eval-bind args env))
      ((special-form-p op 'fn)     (eval-fn args env))
      ((special-form-p op 'def)    (eval-def args env))
      ((special-form-p op 'loop)   (eval-loop args env))
      ((special-form-p op 'recur)  (eval-recur args env))
      ((special-form-p op 'throw)  (eval-throw args env))
      ((special-form-p op 'try)    (eval-try args env))
      ((special-form-p op 'defn)   (eval-defn args env))
      (t (eval-application op args env)))))

;;; ============================================================================
;;; Special Form Evaluators
;;; ============================================================================

;;; --- QUOTE ---

(defun eval-quote (args env)
  "Evaluate (quote form). Returns the form unevaluated."
  (declare (ignore env))
  (unless (= (length args) 1)
    (error 'fol-arity-error :expected 1 :got (length args)
           :form (cons 'quote args)))
  (car args))

;;; --- IF ---

(defun eval-if (args env)
  "Evaluate (if test then else?).
   If test is truthy, evaluate then; otherwise evaluate else (or nil if omitted)."
  (let ((len (length args)))
    (unless (<= 2 len 3)
      (error 'fol-arity-error :expected "2 or 3" :got len
             :form (cons 'if args)))
    (let ((test (first args))
          (then-form (second args))
          (else-form (third args)))
      (if (fol-eval test env)
          (fol-eval then-form env)
          (fol-eval else-form env)))))

;;; --- DO ---

(defun eval-do (args env)
  "Evaluate (do form*). Evaluates each form in sequence, returns the last result.
   Returns NIL if no forms."
  (let ((result nil))
    (dolist (form args)
      (setf result (fol-eval form env)))
    result))

;;; --- LET ---

(defun eval-bind (args env)
  "Evaluate (bind [bindings] body*).
   Bindings are pairs: [var1 val1 var2 val2 ...].
   Each binding is visible to subsequent bindings (sequential)."
  (unless (>= (length args) 1)
    (error 'fol-eval-error :message "bind requires at least bindings"
           :form (cons 'bind args)))
  (let ((bindings (first args))
        (body (rest args)))
    ;; Handle both list and vector bindings
    (let ((binding-list (if (<vector>? bindings)
                            (vector-to-list bindings)
                            bindings)))
      ;; Bind sequentially, each binding visible to the next
      (let ((current-env env))
        (loop for (var val-form) on binding-list by #'cddr
              do (let ((val (fol-eval val-form current-env)))
                   (setf current-env (make-env current-env
                                               (extract-symbol var) val))))
        ;; Evaluate body in final environment
        (let ((result nil))
          (dolist (form body)
            (setf result (fol-eval form current-env)))
          result)))))

;;; --- FN ---

(defun eval-fn (args env)
  "Evaluate (fn [params] body*) or (fn name [params] body*).
   Creates a function with the given parameters and body, capturing the current environment."
  (unless (>= (length args) 1)
    (error 'fol-eval-error :message "fn requires at least parameters"
           :form (cons 'fn args)))
  (let (name params body)
    ;; Check if first arg is a name (symbol, not vector/list)
    (if (cl:and (symbolp (first args))
             (cl:not (null (first args)))
             (>= (length args) 2))
        (progn
          (setf name (first args))
          (setf params (second args))
          (setf body (cddr args)))
        (progn
          (setf params (first args))
          (setf body (cdr args))))
    ;; Parse parameter list
    (let ((param-list (if (<vector>? params)
                          (vector-to-list params)
                          params)))
      (multiple-value-bind (regular-params rest-param)
          (parse-params param-list)
        (make-function regular-params body env
                       :rest-param rest-param
                       :name name)))))

;;; --- DEF ---

(defun eval-def (args env)
  "Evaluate (def name value). Evaluates the value and returns it.
   Note: With immutable environments, actual binding must be handled
   by a REPL or module system that captures the returned value."
  (unless (= (length args) 2)
    (error 'fol-arity-error :expected 2 :got (length args)
           :form (cons 'def args)))
  ;; Validate that the first arg is a valid symbol name
  (extract-symbol (first args))
  ;; Evaluate and return the value
  (fol-eval (second args) env))

;;; --- DEFN ---

(defun eval-defn (args env)
  "Evaluate (defn name [params] body*). Sugar for (def name (fn name [params] body*))."
  (unless (>= (length args) 2)
    (error 'fol-eval-error :message "defn requires name, params, and body"
           :form (cons 'defn args)))
  (let* ((name (first args))
         (params (second args))
         (body (cddr args))
         (fn-form `(fn ,name ,params ,@body)))
    (fol-eval `(def ,name ,fn-form) env)))

;;; --- LOOP/RECUR ---

(defun eval-loop (args env)
  "Evaluate (loop [bindings] body*).
   Establishes a recursion point. RECUR jumps back to this point with new values."
  (unless (>= (length args) 1)
    (error 'fol-eval-error :message "loop requires at least bindings"
           :form (cons 'loop args)))
  (let ((bindings (first args))
        (body (rest args)))
    (let ((binding-list (if (<vector>? bindings)
                            (vector-to-list bindings)
                            bindings)))
      ;; Extract parameter names and initial values
      (let ((params nil)
            (values nil))
        (loop for (var val-form) on binding-list by #'cddr
              do (push (extract-symbol var) params)
                 (push (fol-eval val-form env) values))
        (setf params (nreverse params))
        (setf values (nreverse values))
        ;; Loop until no recur
        (loop
          (let ((loop-env (apply #'make-env env
                                 (loop for p in params
                                       for v in values
                                       collect p
                                       collect v))))
            (handler-case
                (let ((result nil))
                  (dolist (form body)
                    (setf result (fol-eval form loop-env)))
                  (return result))
              (recur-signal (c)
                ;; Update values and continue loop
                (setf values (recur-args c))))))))))

(defun eval-recur (args env)
  "Evaluate (recur arg*). Signals a recur to the enclosing loop with new values."
  (let ((values (mapcar (lambda (arg) (fol-eval arg env)) args)))
    (signal 'recur-signal :args values)))

;;; --- THROW/TRY ---

(defun eval-throw (args env)
  "Evaluate (throw value). Throws a value that can be caught by try."
  (unless (= (length args) 1)
    (error 'fol-arity-error :expected 1 :got (length args)
           :form (cons 'throw args)))
  (error 'fol-eval-error
         :message (fol-eval (first args) env)
         :form (cons 'throw args)))

(defun eval-try (args env)
  "Evaluate (try body* (catch var body*) (finally body*)?).
   Catches exceptions and optionally runs finally code."
  (let ((body nil)
        (catch-clause nil)
        (finally-clause nil))
    ;; Parse clauses - use string comparison for package independence
    (dolist (form args)
      (cond
        ((cl:and (consp form) (symbolp (car form))
              (string= (symbol-name (car form)) "CATCH"))
         (setf catch-clause form))
        ((cl:and (consp form) (symbolp (car form))
              (string= (symbol-name (car form)) "FINALLY"))
         (setf finally-clause form))
        (t (push form body))))
    (setf body (nreverse body))
    ;; Execute with handler
    (let ((result nil))
      (unwind-protect
           (handler-case
               (dolist (form body)
                 (setf result (fol-eval form env)))
             (fol-eval-error (e)
               (if catch-clause
                   (let* ((var (extract-symbol (second catch-clause)))
                          (catch-body (cddr catch-clause))
                          (catch-env (make-env env var (fol-eval-error-message e))))
                     (dolist (form catch-body)
                       (setf result (fol-eval form catch-env))))
                   (error e)))
             (error (e)
               (if catch-clause
                   (let* ((var (extract-symbol (second catch-clause)))
                          (catch-body (cddr catch-clause))
                          (catch-env (make-env env var (format nil "~A" e))))
                     (dolist (form catch-body)
                       (setf result (fol-eval form catch-env))))
                   (error e))))
        ;; Finally clause
        (when finally-clause
          (dolist (form (cdr finally-clause))
            (fol-eval form env))))
      result)))

;;; ============================================================================
;;; Function Application
;;; ============================================================================

(defun eval-application (op args env)
  "Evaluate a function application (op arg*)."
  (let ((fn (fol-eval op env))
        (evaluated-args (mapcar (lambda (arg) (fol-eval arg env)) args)))
    (apply-function fn evaluated-args)))

(defgeneric apply-function (fn args)
  (:documentation "Apply function FN to ARGS."))

(defmethod apply-function ((fn function) args)
  "Apply a CL function to args."
  (apply fn args))

(defmethod apply-function ((fn <function>) args)
  "Apply a FOL function to args."
  (let* ((params (function-params fn))
         (rest-param (function-rest-param fn))
         (body (function-body fn))
         (closure-env (function-env fn))
         (name (function-name fn))
         (num-params (length params))
         (num-args (length args)))
    ;; Check arity
    (if rest-param
        (unless (>= num-args num-params)
          (error 'fol-arity-error
                 :expected (format nil "at least ~A" num-params)
                 :got num-args))
        (unless (= num-args num-params)
          (error 'fol-arity-error :expected num-params :got num-args)))
    ;; Create environment with parameter bindings
    (let ((fn-env closure-env))
      ;; Bind regular parameters
      (loop for param in params
            for arg in args
            do (setf fn-env (make-env fn-env param arg)))
      ;; Bind rest parameter if present
      (when rest-param
        (setf fn-env (make-env fn-env rest-param (nthcdr num-params args))))
      ;; Bind function name for recursion if present
      (when name
        (setf fn-env (make-env fn-env name fn)))
      ;; Evaluate body
      (let ((result nil))
        (dolist (form body)
          (setf result (fol-eval form fn-env)))
        result))))

;;; Symbols (including keywords) as functions (for collection access, Clojure style)
(defmethod apply-function ((fn symbol) args)
  "Symbols and keywords can be used as functions to access collections."
  (unless (= (length args) 1)
    (error 'fol-arity-error :expected 1 :got (length args)))
  (let ((coll (first args)))
    (if (<dict>? coll)
        (get coll fn)
        (error 'fol-eval-error
               :message (format nil "Cannot use symbol ~S as function on ~S" fn coll)))))

;;; ============================================================================
;;; Helper Functions
;;; ============================================================================

(defun special-form-p (op name)
  "Check if OP matches the special form NAME, comparing by symbol name.
   This allows forms from any package to be recognized as special forms."
  (cl:and (symbolp op)
       (string= (symbol-name op) (symbol-name name))))

(defun extract-symbol (form)
  "Extract a raw symbol from FORM (handles wrapped symbols)."
  (cond
    ((symbolp form) form)
    ((<symbol>? form) (fol-value form))
    (t (error 'fol-eval-error
              :message (format nil "Expected symbol, got ~S" form)
              :form form))))

(defun vector-to-list (vec)
  "Convert a FOL vector to a CL list."
  (let ((result nil)
        (iter (iterator vec)))
    (loop until (done? iter)
          do (push (current iter) result)
             (next iter))
    (nreverse result)))

(defun parse-params (param-list)
  "Parse a parameter list, returning (values regular-params rest-param).
   Handles & for rest parameters."
  (let ((regular nil)
        (rest-param nil)
        (saw-ampersand nil))
    (dolist (p param-list)
      (let ((sym (extract-symbol p)))
        (cond
          ;; Compare by name for package independence
          ((string= (symbol-name sym) "&")
           (setf saw-ampersand t))
          (saw-ampersand
           (setf rest-param sym)
           (setf saw-ampersand nil))
          (t
           (push sym regular)))))
    (values (nreverse regular) rest-param)))

;;; ============================================================================
;;; Standard Environment
;;; ============================================================================

(defun make-standard-env ()
  "Create an environment with standard FOL bindings for arithmetic,
   comparison, and logical operations."
  (make-env nil
            ;; Arithmetic
            '+ #'+
            '- #'-
            '* #'*
            '/ #'/
            'abs #'abs
            'sin #'sin
            'cos #'cos
            'tan #'tan
            'sqrt #'sqrt
            'expt #'expt
            'exp #'exp
            'log #'log
            'mod #'cl:mod
            'rem #'cl:rem
            'floor #'cl:floor
            'ceiling #'cl:ceiling
            'truncate #'cl:truncate
            'round #'cl:round
            ;; Comparison
            '= #'=
            '/= #'/=
            '< #'<
            '> #'>
            '<= #'<=
            '>= #'>=
            'min #'min
            'max #'max
            ;; Logical
            'not #'not
            'and #'and
            'or #'or
            ;; Type predicates
            'nil? #'cl:null
            'number? #'cl:numberp
            'string? #'cl:stringp
            'symbol? #'cl:symbolp
            'list? #'cl:listp
            'cons? #'cl:consp
            ;; List operations
            'cons #'cl:cons
            'car #'cl:car
            'cdr #'cl:cdr
            'first #'cl:first
            'rest #'cl:rest
            'list #'cl:list
            'length #'cl:length
            'nth #'cl:nth
            'append #'cl:append
            'reverse #'cl:reverse
            ;; String operations
            'str #'(lambda (&rest args)
                     (apply #'concatenate 'string
                            (mapcar #'princ-to-string args)))
            ;; Misc
            'identity #'cl:identity
            'print #'cl:print
            'princ #'cl:princ))
