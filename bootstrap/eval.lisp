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

(define-condition fol-type-error (fol-eval-error)
  ((expected-type :initarg :expected-type :accessor fol-type-error-expected)
   (actual-type :initarg :actual-type :accessor fol-type-error-actual)
   (variable :initarg :variable :accessor fol-type-error-variable :initform nil))
  (:report (lambda (condition stream)
             (if (fol-type-error-variable condition)
                 (format stream "Type error: variable ~A expected type ~A, got ~A"
                         (fol-type-error-variable condition)
                         (fol-type-error-expected condition)
                         (fol-type-error-actual condition))
                 (format stream "Type error: expected type ~A, got ~A"
                         (fol-type-error-expected condition)
                         (fol-type-error-actual condition))))))

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
;;; FOL Macro Representation
;;; ============================================================================

(defclass <macro> (fol.persistent:<persistent-object>)
  ((params :initarg :params :accessor macro-params :type list)
   (body :initarg :body :accessor macro-body :type list)
   (env :initarg :env :accessor macro-env)
   (rest-param :initarg :rest-param :accessor macro-rest-param :initform nil)
   (name :initarg :name :accessor macro-name :initform nil))
  (:metaclass fol.persistent:persistent-class)
  (:documentation "A user-defined FOL macro. Receives unevaluated arguments,
                   returns a form that is then evaluated."))

(defun <macro>? (obj)
  "Returns T if OBJ is a FOL macro."
  (typep obj '<macro>))

(defun make-macro (params body env &key rest-param name)
  "Create a new FOL macro with the given parameters, body, and closure environment."
  (make-instance '<macro>
                 :params params
                 :body body
                 :env env
                 :rest-param rest-param
                 :name name))

;;; ============================================================================
;;; FOL Multi-Pattern Macro Representation
;;; ============================================================================
;;; Multi-pattern macros support multiple dispatch clauses with different arities
;;; and destructuring patterns, similar to multi-pattern defn.

(defclass <multi-macro> ()
  ((dispatcher :initarg :dispatcher :accessor multi-macro-dispatcher
               :type function
               :documentation "A CL function that takes unevaluated args and returns expanded form.")
   (name :initarg :name :accessor multi-macro-name :initform nil
         :documentation "The name of this multi-macro.")
   (valid-arities :initarg :valid-arities :accessor multi-macro-valid-arities
                  :initform nil :type list
                  :documentation "List of valid arities for error messages."))
  (:documentation "A multi-pattern FOL macro with multiple dispatch clauses."))

(defun <multi-macro>? (obj)
  "Returns T if OBJ is a multi-pattern FOL macro."
  (typep obj '<multi-macro>))

(defun make-multi-macro (dispatcher &key name valid-arities)
  "Create a new multi-pattern macro with the given dispatcher function."
  (make-instance '<multi-macro>
                 :dispatcher dispatcher
                 :name name
                 :valid-arities valid-arities))

(defun expand-multi-macro (multi-macro args)
  "Expand a multi-pattern macro by dispatching to the appropriate clause.
   ARGS are unevaluated (raw forms from the call site)."
  (funcall (multi-macro-dispatcher multi-macro) args))

;;; ============================================================================
;;; FOL Dynamic Variable Representation
;;; ============================================================================
;;; Dynamic variables provide dynamically-scoped bindings that can be temporarily
;;; rebound using the `binding` form. The value stack allows nested bindings.

(defclass <dynamic-var> ()
  ((name :initarg :name :accessor dynamic-var-name :type symbol
         :documentation "The name of this dynamic variable.")
   (root-value :initarg :root-value :accessor dynamic-var-root-value
               :documentation "The root (default) value of this dynamic variable.")
   (value-stack :initform nil :accessor dynamic-var-value-stack :type list
                :documentation "Stack of bound values. When non-empty, the car is the current value."))
  (:documentation "A dynamic variable with a value stack for nested bindings.
                   When the stack is empty, root-value is used.
                   The `binding` form pushes values onto the stack."))

(defun <dynamic-var>? (obj)
  "Returns T if OBJ is a FOL dynamic variable."
  (typep obj '<dynamic-var>))

(defun make-dynamic-var (name &optional (root-value nil))
  "Create a new dynamic variable with the given name and optional root value."
  (make-instance '<dynamic-var>
                 :name name
                 :root-value root-value))

(defmethod fol-value ((dvar <dynamic-var>))
  "Dynamic variables are NOT unwrapped - return the object itself.
   This ensures they can be stored in environments and auto-dereferenced on lookup."
  dvar)

(defun dynamic-var-value (dvar)
  "Get the current value of a dynamic variable.
   Returns the top of the value stack if non-empty, otherwise the root value."
  (let ((stack (dynamic-var-value-stack dvar)))
    (if stack
        (car stack)
        (dynamic-var-root-value dvar))))

(defun dynamic-var-push (dvar value)
  "Push a new value onto the dynamic variable's value stack."
  (cl:push value (dynamic-var-value-stack dvar)))

(defun dynamic-var-pop (dvar)
  "Pop a value from the dynamic variable's value stack.
   Returns the popped value."
  (cl:pop (dynamic-var-value-stack dvar)))

;;; ============================================================================
;;; Recur Exception (for loop/recur)
;;; ============================================================================

(define-condition recur-signal ()
  ((args :initarg :args :accessor recur-args))
  (:documentation "Signal used to implement recur within loop."))

;;; ============================================================================
;;; Forward Declarations for Syntax-Quote Helpers
;;; ============================================================================
;;; These need to be defined before fol-eval methods that use them.

(defun auto-gensym-symbol-p (form)
  "Check if FORM is an auto-gensym symbol (ends with #)."
  (cl:and (symbolp form)
          (cl:not (keywordp form))
          (let ((name (symbol-name form)))
            (cl:and (> (length name) 1)
                    (char= (char name (1- (length name))) #\#)))))

(defun unquote-form-p (form)
  "Check if FORM is an unquote form: (unquote x)"
  (cl:and (consp form)
          (symbolp (car form))
          (string= (symbol-name (car form)) "UNQUOTE")))

(defun unquote-splicing-form-p (form)
  "Check if FORM is an unquote-splicing form: (unquote-splicing x)"
  (cl:and (consp form)
          (symbolp (car form))
          (string= (symbol-name (car form)) "UNQUOTE-SPLICING")))

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

;;; --- FOL Macros are Self-Evaluating ---

(defmethod fol-eval ((form <macro>) env)
  "FOL macros are self-evaluating."
  (declare (ignore env))
  form)

;;; --- FOL Dynamic Variables return their current value ---

(defmethod fol-eval ((form <dynamic-var>) env)
  "Dynamic variables evaluate to their current value."
  (declare (ignore env))
  (dynamic-var-value form))

;;; --- CL Functions are Self-Evaluating ---

(defmethod fol-eval ((form function) env)
  "CL functions are self-evaluating."
  (declare (ignore env))
  form)

;;; --- Symbol Lookup ---

(defmethod fol-eval ((form symbol) env)
  "Symbols are looked up in the environment. Keywords are self-evaluating.
   Auto-gensym symbols (ending with #) are an error outside syntax-quote.
   If the looked-up value is a <dynamic-var>, it is automatically dereferenced."
  (cond
    ((keywordp form) form)
    ((auto-gensym-symbol-p form)
     (error 'fol-eval-error
            :message (format nil "Auto-gensym symbol ~A is only valid inside syntax-quote" form)
            :form form))
    (t (let ((value (handler-case (lookup env form)
                      (fol-unbound-variable ()
                        ;; Not in local env, check global CL binding
                        (if (boundp form)
                            (symbol-value form)
                            ;; Neither local nor global - signal unbound error
                            (error 'fol-unbound-variable
                                   :name form
                                   :message (format nil "Variable ~A is unbound" form)))))))
         ;; Auto-dereference dynamic variables
         (if (<dynamic-var>? value)
             (dynamic-var-value value)
             value)))))

;;; --- Wrapped Symbol Lookup ---

(defmethod fol-eval ((form <symbol>) env)
  "Wrapped symbols are looked up using their raw symbol value.
   If the looked-up value is a <dynamic-var>, it is automatically dereferenced."
  (let* ((sym (fol-value form))
         (value (handler-case (lookup env sym)
                  (fol-unbound-variable ()
                    ;; Not in local env, check global CL binding
                    (if (boundp sym)
                        (symbol-value sym)
                        ;; Neither local nor global - signal unbound error
                        (error 'fol-unbound-variable
                               :name sym
                               :message (format nil "Variable ~A is unbound" sym)))))))
    ;; Auto-dereference dynamic variables
    (if (<dynamic-var>? value)
        (dynamic-var-value value)
        value)))

;;; --- List Forms (Special Forms and Function Application) ---

;;; Dispatch table for special forms - maps symbol name (string) to handler symbol.
;;; Each handler is a symbol naming a function that takes (args env).
(defparameter *special-form-dispatch*
  (let ((table (make-hash-table :test 'equal)))
    ;; Core special forms
    (setf (gethash "QUOTE" table) 'eval-quote)
    (setf (gethash "IF" table) 'eval-if)
    (setf (gethash "DO" table) 'eval-do)
    (setf (gethash "BIND" table) 'eval-bind)
    (setf (gethash "FN" table) 'eval-fn)
    (setf (gethash "Λ" table) 'eval-fn)  ; λ is a synonym for fn
    (setf (gethash "DEF" table) 'eval-def)
    (setf (gethash "LOOP" table) 'eval-loop)
    (setf (gethash "RECUR" table) 'eval-recur)
    (setf (gethash "THROW" table) 'eval-throw)
    (setf (gethash "TRY" table) 'eval-try)
    (setf (gethash "DEFN" table) 'eval-defn)
    (setf (gethash "DEFMACRO" table) 'eval-defmacro)
    (setf (gethash "DEFINLINE" table) 'eval-definline)
    (setf (gethash "SYNTAX-QUOTE" table) 'eval-syntax-quote)
    (setf (gethash "MAKE-DYNAMIC" table) 'eval-make-dynamic)
    (setf (gethash "BINDING" table) 'eval-binding)
    (setf (gethash "LAZY-SEQ" table) 'eval-lazy-seq)
    ;; Conditional forms
    (setf (gethash "COND" table) 'eval-cond)
    (setf (gethash "CASE" table) 'eval-case)
    ;; Threading macros
    (setf (gethash "->" table) 'eval-thread-first)
    (setf (gethash "->>" table) 'eval-thread-last)
    (setf (gethash "COND->" table) 'eval-cond-thread-first)
    (setf (gethash "COND->>" table) 'eval-cond-thread-last)
    ;; FOL MOP forms
    (setf (gethash "DEFGENERIC" table) 'eval-defgeneric*)
    (setf (gethash "DEFCLASS" table) 'eval-defclass*)
    (setf (gethash "DEFMETHOD" table) 'eval-defmethod*)
    ;; Module operations
    (setf (gethash "USE-MODULE" table) 'eval-use-module)
    (setf (gethash "MODULE" table) 'eval-module)
    ;; Environment access
    (setf (gethash "ENV" table) 'eval-env)
    ;; Unquote forms are errors outside syntax-quote
    (setf (gethash "UNQUOTE" table) 'eval-unquote-error)
    (setf (gethash "UNQUOTE-SPLICING" table) 'eval-unquote-splicing-error)
    table)
  "Hash table mapping special form names (uppercase strings) to handler symbols.")

(defun eval-use-module (args env)
  "Import all exported symbols from a module into the current environment.
   (use-module module-name)"
  (let* ((name-form (cl:first args))
         (name (fol-eval name-form env)))
    (fol.module:use-module name env)
    nil))

(defun eval-module (args env)
  "Create a new module and add it to the environment chain.
   (module) - creates an anonymous module (not registered)
   (module name) - creates a named module and registers it
   Returns the new module with the current environment as its parent."
  (let* ((name-form (cl:first args))
         (name (when name-form (fol-eval name-form env)))
         (module (make-instance 'fol.module:<module>
                                :name name
                                :items (fset:empty-map)
                                :previous env)))
    ;; Register named modules
    (when name
      (fol.module:register-module name module))
    module))

(defun eval-unquote-error (args env)
  "Signal error for unquote outside syntax-quote."
  (declare (ignore env))
  (error 'fol-eval-error
         :message "unquote (~) is only valid inside syntax-quote"
         :form (cl:cons 'unquote args)))

(defun eval-unquote-splicing-error (args env)
  "Signal error for unquote-splicing outside syntax-quote."
  (declare (ignore env))
  (error 'fol-eval-error
         :message "unquote-splicing (~@) is only valid inside syntax-quote"
         :form (cl:cons 'unquote-splicing args)))

(defmethod fol-eval ((form cons) env)
  "Evaluate a list form. Dispatch on the operator."
  (let* ((op (car form))
         (args (cdr form))
         (handler (cl:and (symbolp op)
                          (gethash (symbol-name op) *special-form-dispatch*))))
    (if handler
        (funcall handler args env)
        (eval-application op args env))))

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

;;; --- ENV ---

(defun eval-env (args env)
  "Evaluate (env). Returns the current environment."
  (unless (= (length args) 0)
    (error 'fol-arity-error :expected 0 :got (length args)
           :form (cons 'env args)))
  env)

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

;;; --- COND ---

(defun eval-cond (args env)
  "Evaluate (cond test1 form1 test2 form2 ...).
   Evaluates test/form pairs sequentially. When a test is truthy,
   evaluates and returns the corresponding form.
   Returns NIL if no test is truthy.

   Example:
     (cond
       (= x 0) \"zero\"
       (> x 0) \"positive\"
       t \"negative\")"
  (unless (evenp (length args))
    (error 'fol-eval-error
           :message "cond requires an even number of arguments (test/form pairs)"
           :form (cons 'cond args)))
  ;; Process pairs
  (loop for (test form) on args by #'cddr
        when (fol-eval test env)
        return (fol-eval form env)
        finally (return nil)))

;;; --- CASE ---

(defun eval-case (args env)
  "Evaluate (case target-form target1 form1 target2 form2 ... [default-form]).
   Evaluates target-form to get a value, then matches against targets.
   Each target can be an atom or a vector of atoms.
   If matched, evaluates and returns the corresponding form.
   If no match and default-form present, evaluates default-form.
   If no match and no default-form, signals an error.

   Example:
     (case x
       [0 1] nil
       2 (state x)
       3 t
       [4 5 6 7 8] nil)

     (case major
       \"engineering\" (values 60000 :engineering)
       \"business\" (values 90000 :management)
       (values 20000 :production))"
  (when (< (length args) 1)
    (error 'fol-eval-error
           :message "case requires at least a target form"
           :form (cons 'case args)))
  (let* ((target-form (first args))
         (clauses (rest args))
         (target-value (fol-eval target-form env)))
    ;; Determine if we have an odd number of remaining args (default form present)
    (let* ((has-default (oddp (length clauses)))
           (default-form (when has-default (car (last clauses))))
           (case-pairs (if has-default (butlast clauses) clauses))
           (seen-targets (make-hash-table :test 'equal)))
      ;; Check for even number of case pairs
      (unless (evenp (length case-pairs))
        (error 'fol-eval-error
               :message "case requires target/form pairs"
               :form (cons 'case args)))
      ;; Build dispatch table and check for duplicates
      (loop for (target form) on case-pairs by #'cddr
            do (let ((targets (if (<vector>? target)
                                  ;; Vector of targets
                                  (loop for i from 0 below (size target)
                                        collect (fol.wrappers:fol-value (nth target i)))
                                  ;; Single target
                                  (list (fol.wrappers:fol-value target)))))
                 (dolist (tgt targets)
                   (when (gethash tgt seen-targets)
                     (error 'fol-eval-error
                            :message (format nil "Duplicate target in case: ~S" tgt)
                            :form (cons 'case args)))
                   (setf (gethash tgt seen-targets) form))))
      ;; Look up target value
      (multiple-value-bind (matching-form found)
          (gethash (fol.wrappers:fol-value target-value) seen-targets)
        (cond
          (found (fol-eval matching-form env))
          (has-default (fol-eval default-form env))
          (t (error 'fol-eval-error
                    :message (format nil "No matching case for ~S" target-value)
                    :form (cons 'case args))))))))

;;; --- DO ---

(defun eval-do (args env)
  "Evaluate (do form*). Evaluates each form in sequence, returns the last result.
   Returns NIL if no forms."
  (let ((result nil))
    (dolist (form args)
      (setf result (fol-eval form env)))
    result))

;;; --- DESTRUCTURING ---

;;; Type annotation support for destructuring patterns.
;;; A type-annotated binding has the form (symbol type), e.g., (x <integer>)
;;; Types are symbols like <integer>, <string>, <number>, etc.

(defun fol-type-symbol-p (sym)
  "Return T if SYM looks like a FOL type symbol (starts with < and ends with >)."
  (cl:and (symbolp sym)
       (let ((name (symbol-name sym)))
         (cl:and (> (length name) 2)
              (char= (char name 0) #\<)
              (char= (char name (1- (length name))) #\>)))))

(defun typed-binding-p (pattern)
  "Return T if PATTERN is a typed binding of the form (symbol type).
   A typed binding is a CL list with exactly 2 elements where:
   - First element is a symbol (variable name)
   - Second element is a type symbol (like <integer>, <string>, etc.)"
  (cl:and (cl:listp pattern)
       (= (length pattern) 2)
       (let ((var (cl:first pattern))
             (type-spec (cl:second pattern)))
         (cl:and (or (symbolp var) (<symbol>? var))
              (or (fol-type-symbol-p type-spec)
                  (cl:and (<symbol>? type-spec)
                       (fol-type-symbol-p (fol-value type-spec))))))))

(defun get-fol-type-class (type-sym)
  "Return the CL class corresponding to a FOL type symbol, or NIL if not found."
  (cl:find-class type-sym nil))

(defun type-conforms-p (value expected-type)
  "Return T if VALUE conforms to EXPECTED-TYPE.
   Uses the FOL class hierarchy to check subtypes."
  (let ((type-class (get-fol-type-class expected-type)))
    (if type-class
        ;; Check using CLOS type hierarchy
        (or
         ;; Check if value is an instance of the expected type class
         (typep value type-class)
         ;; For raw CL values, check against their FOL type and hierarchy
         (let ((actual-type (fol.wrappers:fol-type-of value)))
           (if (eq actual-type expected-type)
               t  ; Exact match
               ;; Check if actual-type's class is a subtype of expected-type
               (let ((actual-class (get-fol-type-class actual-type)))
                 (cl:and actual-class type-class
                      (subtypep actual-class type-class))))))
        ;; No class found for expected-type - try symbol comparison
        (eq (fol.wrappers:fol-type-of value) expected-type))))

(defun bind-with-type-check (var-name type-spec value)
  "Create a binding for VAR-NAME to VALUE, checking that VALUE conforms to TYPE-SPEC.
   Returns a list containing a single (var-name . value) cons.
   Signals fol-type-error if VALUE doesn't conform to TYPE-SPEC."
  (unless (type-conforms-p value type-spec)
    (error 'fol-type-error
           :expected-type type-spec
           :actual-type (fol.wrappers:fol-type-of value)
           :variable var-name
           :message (format nil "Type mismatch in binding ~A" var-name)
           :form (list var-name type-spec)))
  (list (cons var-name value)))

(defun underscore-symbol-p (sym)
  "Return T if SYM is the underscore placeholder symbol (named \"_\").
   The underscore is used in destructuring to discard values without binding."
  (cl:and (symbolp sym)
       (string= (symbol-name sym) "_")))

(defun destructure-pattern (pattern value)
  "Destructure VALUE according to PATTERN, returning an alist of (symbol . value) pairs.
   Supports:
   - Simple symbol: binds the whole value
   - Underscore _: discards the value (no binding created)
   - Typed binding (symbol type): binds with type check, e.g., (x <integer>)
   - Vector [a b c]: sequential destructuring for lists/vectors
   - Vector with &: [a b & rest] captures remaining elements
   - Vector with :as: [a b :as whole] also binds the whole collection
   - Map {:keys [a b]}: binds a and b from map keys :a and :b
   - Map {a :key}: binds a to the value at :key
   - Map with :as: {a :key :as whole} also binds the whole map
   - Nested patterns: [[a b] c] for nested destructuring"
  (cond
    ;; Underscore placeholder - discard value, no binding
    ((underscore-symbol-p pattern)
     nil)

    ;; Simple symbol - bind the whole value
    ((symbolp pattern)
     (if (null pattern)
         nil  ; nil pattern binds nothing
         (list (cons pattern value))))

    ;; FOL <symbol> wrapper - check for underscore first
    ((<symbol>? pattern)
     (if (underscore-symbol-p (fol-value pattern))
         nil  ; underscore discards value
         (list (cons (fol-value pattern) value))))

    ;; Typed binding: (symbol type) - check type before binding
    ((typed-binding-p pattern)
     (let* ((var-sym (cl:first pattern))
            (type-spec (cl:second pattern))
            ;; Extract raw symbols from any wrappers
            (var-name (if (<symbol>? var-sym) (fol-value var-sym) var-sym))
            (type-name (if (<symbol>? type-spec) (fol-value type-spec) type-spec)))
       (bind-with-type-check var-name type-name value)))

    ;; Vector pattern - sequential destructuring
    ((<vector>? pattern)
     (destructure-sequential (vector-to-list pattern) value))

    ;; CL list pattern - sequential destructuring (for quoted patterns)
    ((cl:listp pattern)
     (destructure-sequential pattern value))

    ;; Dict pattern - associative destructuring
    ((<dict>? pattern)
     (destructure-associative pattern value))

    (t (error 'fol-eval-error
              :message (format nil "Invalid destructuring pattern: ~S" pattern)
              :form pattern))))

(defun destructure-sequential (pattern-list value)
  "Destructure VALUE as a sequence according to PATTERN-LIST.
   Handles & for rest binding and :as for whole binding."
  (let ((bindings nil)
        (seq-value (cond
                     ((<vector>? value) (vector-to-list value))
                     ((<list>? value) (fol-list-to-cl-list value))
                     ((cl:listp value) value)
                     (t (error 'fol-eval-error
                               :message (format nil "Cannot destructure non-sequential value: ~S" value)
                               :form value))))
        (current-idx 0)
        (rest-mode nil)
        (as-binding nil))
    ;; Process pattern elements
    (loop for remaining on pattern-list
          for pat = (car remaining)
          do (cond
               ;; :as keyword - next element is the whole-binding symbol
               ((eq pat :as)
                (let ((as-sym (cadr remaining)))
                  (when as-sym
                    (setf as-binding (cons (extract-symbol as-sym) value))))
                (return))

               ;; & keyword - switch to rest mode (compare by name for cross-package support)
               ((cl:and (symbolp pat) (string= (symbol-name pat) "&"))
                (setf rest-mode t))

               ;; In rest mode - bind remaining elements
               (rest-mode
                (let ((rest-val (nthcdr current-idx seq-value)))
                  ;; Always convert to FOL list (like Clojure's rest which returns a seq)
                  (setf rest-val (apply #'make-list rest-val))
                  (setf bindings (append bindings (destructure-pattern pat rest-val))))
                (setf rest-mode nil))

               ;; Normal element - destructure at current index
               (t
                (let ((elem-val (cl:nth current-idx seq-value)))
                  (setf bindings (append bindings (destructure-pattern pat elem-val))))
                (incf current-idx))))
    ;; Add :as binding if present
    (when as-binding
      (cl:push as-binding bindings))
    bindings))

(defun destructure-associative (pattern value)
  "Destructure VALUE as a map according to dict PATTERN.
   Handles :keys, :strs, :syms shortcuts, :as for whole binding, and :or for defaults.
   Example: {:keys [a b] :or {a 10 b 20}} - if a is missing, uses 10 as default."
  (let ((bindings nil)
        (as-binding nil)
        ;; Extract :or defaults map
        (defaults (get pattern :or nil)))
    ;; Helper to get value with fallback to defaults
    (flet ((get-with-default (key sym)
             "Get KEY from value, falling back to SYM in defaults map."
             (let ((val (get value key nil)))
               (if (cl:and (null val) defaults)
                   ;; Try to find default using the symbol name as keyword
                   (let ((default-key (intern (symbol-name sym) :keyword)))
                     (get defaults default-key val))
                   val))))
      ;; Check for :keys shortcut in the pattern
      (let ((keys-val (get pattern :keys nil)))
        (when keys-val
          ;; :keys [a b c] -> bind a to :a, b to :b, etc.
          (let ((key-list (cond
                            ((<vector>? keys-val) (vector-to-list keys-val))
                            ((cl:listp keys-val) keys-val)
                            (t (list keys-val)))))
            (dolist (k key-list)
              (let* ((sym (extract-symbol k))
                     (keyword (intern (symbol-name sym) :keyword))
                     (val (get-with-default keyword sym)))
                (cl:push (cons sym val) bindings))))))

      ;; Check for :strs shortcut (string keys)
      (let ((strs-val (get pattern :strs nil)))
        (when strs-val
          (let ((str-list (cond
                            ((<vector>? strs-val) (vector-to-list strs-val))
                            ((cl:listp strs-val) strs-val)
                            (t (list strs-val)))))
            (dolist (s str-list)
              (let* ((sym (extract-symbol s))
                     (str-key (symbol-name sym))
                     (val (get-with-default str-key sym)))
                (cl:push (cons sym val) bindings))))))

      ;; Check for :syms shortcut (symbol keys)
      (let ((syms-val (get pattern :syms nil)))
        (when syms-val
          (let ((sym-list (cond
                            ((<vector>? syms-val) (vector-to-list syms-val))
                            ((cl:listp syms-val) syms-val)
                            (t (list syms-val)))))
            (dolist (s sym-list)
              (let* ((sym (extract-symbol s))
                     (val (get-with-default sym sym)))
                (cl:push (cons sym val) bindings))))))

      ;; Check for :as whole binding
      (let ((as-val (get pattern :as nil)))
        (when as-val
          (setf as-binding (cons (extract-symbol as-val) value))))

      ;; Process explicit key->binding pairs in the pattern
      ;; Pattern: {local-var :map-key} means bind local-var to value at :map-key
      (let ((items (slot-value pattern 'fol.collection::items)))
        (fset:do-map (k v items)
          ;; Skip special keys
          (unless (member k '(:keys :strs :syms :as :or))
            ;; k is the local variable name, v is the key to look up in value
            (let* ((local-sym (extract-symbol k))
                   (lookup-key v)
                   (val (get-with-default lookup-key local-sym)))
              ;; Support nested destructuring
              (if (or (<vector>? local-sym) (<dict>? local-sym) (cl:listp local-sym))
                  (setf bindings (append bindings (destructure-pattern k val)))
                  (cl:push (cons local-sym val) bindings))))))

      ;; Add :as binding if present
      (when as-binding
        (cl:push as-binding bindings))

      (nreverse bindings))))

(defun fol-list-to-cl-list (fol-list)
  "Convert a FOL <list> to a CL list."
  (let ((result nil)
        (current fol-list))
    (loop while (cl:and current (cl:> (list-size current) 0))
          do (cl:push (list-first current) result)
             (setf current (list-rest current)))
    (nreverse result)))

;;; --- LET ---

(defun sequential-pattern-p (pattern)
  "Return T if PATTERN is a sequential destructuring pattern (vector or list)."
  (or (<vector>? pattern)
      (cl:and (cl:listp pattern) (not (null pattern)))))

(defun capture-value-for-destructuring (val-form env pattern)
  "Evaluate VAL-FORM and return a value suitable for destructuring against PATTERN.
   For sequential patterns, captures multiple return values if the expression
   returns more than one value. For single-value returns of sequences, returns
   the sequence directly for element-by-element destructuring."
  (if (sequential-pattern-p pattern)
      (let ((mv-result (multiple-value-list (fol-eval val-form env))))
        ;; If multiple values returned, use the list of values for destructuring
        ;; If single value that's already a sequence, use it directly
        (if (> (length mv-result) 1)
            mv-result  ; Multiple values: destructure the values themselves
            (car mv-result)))  ; Single value: unwrap and destructure it
      ;; Non-sequential pattern: just get the primary value
      (fol-eval val-form env)))

(defun eval-bind (args env)
  "Evaluate (bind [bindings] body*).
   Bindings are pairs: [pattern1 val1 pattern2 val2 ...].
   Supports destructuring patterns (vectors, maps) like Clojure:
   - Simple: [x 1] binds x to 1
   - Sequential: [[a b] [1 2]] binds a to 1, b to 2
   - Rest: [[a & rest] [1 2 3]] binds a to 1, rest to (2 3)
   - As: [[a :as all] [1 2]] binds a to 1, all to [1 2]
   - Map: [{:keys [a b]} {:a 1 :b 2}] binds a to 1, b to 2
   - Multiple values: [[a b c] (values 1 2 3)] binds a=1, b=2, c=3
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
        (loop for (pattern val-form) on binding-list by #'cddr
              do (let ((val (capture-value-for-destructuring val-form current-env pattern)))
                   ;; Use destructuring to get all bindings from pattern
                   (let ((destructured (destructure-pattern pattern val)))
                     (dolist (binding destructured)
                       (setf current-env (make-env current-env
                                                   (car binding) (cdr binding)))))))
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
   Sets the global symbol value using defparameter."
  (unless (= (length args) 2)
    (error 'fol-arity-error :expected 2 :got (length args)
           :form (cons 'def args)))
  (let ((name (extract-symbol (first args)))
        (value (fol-eval (second args) env)))
    (cl:eval `(cl:defparameter ,name ',value))
    value))

;;; --- DEFN ---

(defun multi-pattern-defn-p (args)
  "Check if ARGS represents a multi-pattern defn form.
   Multi-pattern syntax: (defn name ([params1] body1*) ([params2] body2*) ...)
   Each clause is a list whose first element is a vector."
  (cl:and (>= (length args) 2)
          (listp (second args))
          (cl:not (null (second args)))
          (<vector>? (first (second args)))))

(defun parse-defn-clause (clause)
  "Parse a defn clause ([params] body*) into (params . body)."
  (if (cl:and (listp clause)
              (cl:not (null clause))
              (<vector>? (first clause)))
      (cons (first clause) (rest clause))
      (error 'fol-eval-error
             :message "Invalid defn clause: expected ([params] body*)"
             :form clause)))

(defun multi-pattern-defmacro-p (args)
  "Check if ARGS represents a multi-pattern defmacro form.
   Multi-pattern syntax: (defmacro name ([params1] body1*) ([params2] body2*) ...)
   Each clause is a list whose first element is a vector."
  (cl:and (>= (length args) 2)
          (listp (second args))
          (cl:not (null (second args)))
          (<vector>? (first (second args)))))

(defun parse-defmacro-clause (clause)
  "Parse a defmacro clause ([params] body*) into (params . body)."
  (if (cl:and (listp clause)
              (cl:not (null clause))
              (<vector>? (first clause)))
      (cons (first clause) (rest clause))
      (error 'fol-eval-error
             :message "Invalid defmacro clause: expected ([params] body*)"
             :form clause)))

(defun args-match-pattern-p (args signature)
  "Check if ARGS match the given pattern SIGNATURE at runtime.
   SIGNATURE is a list of (:any) or (:seq min-size) specs."
  (loop for arg in args
        for sig in signature
        always (case (first sig)
                 (:any t)
                 (:seq (cl:and (cl:or (<vector>? arg)
                                      (<list>? arg)
                                      (listp arg))
                               (>= (if (listp arg)
                                       (length arg)
                                       (fol.seqop:size arg))
                                   (second sig))))
                 (t t))))

(defun macro-args-match-pattern-p (args signature)
  "Check if unevaluated macro ARGS match the given pattern SIGNATURE.
   SIGNATURE is a list of (:any) or (:seq min-size) specs.
   Unlike args-match-pattern-p, this works on raw forms (not evaluated values)."
  (loop for arg in args
        for sig in signature
        always (case (first sig)
                 (:any t)
                 ;; For macros, check if the form is a sequence type
                 ;; Forms that can be destructured: lists, vectors
                 (:seq (cl:and (cl:or (<vector>? arg)  ; FOL vector
                                      (<list>? arg)    ; FOL list
                                      (listp arg))     ; CL list form
                               (>= (cond ((listp arg) (length arg))
                                         ((<vector>? arg) (fol.seqop:size arg))
                                         ((<list>? arg) (fol.seqop:size arg))
                                         (t 0))
                                   (second sig))))
                 (t t))))

(defun eval-defn (args env)
  "Evaluate defn in single-pattern or multi-pattern form.

   Single-pattern:
     (defn name [params] body*)
     Sugar for (def name (fn name [params] body*))

   Multi-pattern:
     (defn name
       ([params1] body1*)
       ([params2] body2*)
       ...)
     Creates a dispatcher function that routes by arity and pattern match."
  (unless (>= (length args) 2)
    (error 'fol-eval-error :message "defn requires name, params/clauses, and body"
           :form (cons 'defn args)))
  (let ((name (first args)))
    (if (multi-pattern-defn-p args)
        ;; Multi-pattern defn
        (let* ((clauses (rest args))
               ;; Parse each clause
               (parsed-clauses
                 (loop for clause in clauses
                       for idx from 0
                       for parsed = (parse-defn-clause clause)
                       for params = (car parsed)
                       for body = (cdr parsed)
                       for param-list = (vector-to-list params)
                       ;; Parse to separate regular params from rest param
                       for (regular-params rest-param) = (multiple-value-list
                                                          (parse-params param-list))
                       for arity = (length regular-params)
                       for has-rest = (cl:not (null rest-param))
                       for signature = (compute-pattern-signature regular-params)
                       for internal-name = (make-pattern-name name idx)
                       collect (list :index idx
                                     :arity arity
                                     :has-rest has-rest
                                     :params params
                                     :body body
                                     :signature signature
                                     :internal-name internal-name)))
               ;; Sort by arity, then by specificity (most specific first)
               (sorted-clauses
                 (stable-sort (copy-list parsed-clauses)
                              (lambda (c1 c2)
                                (let ((a1 (getf c1 :arity))
                                      (a2 (getf c2 :arity)))
                                  (cond
                                    ((< a1 a2) t)
                                    ((> a1 a2) nil)
                                    ;; Same arity: more specific pattern first
                                    (t (pattern-more-specific-p
                                        (getf c1 :signature)
                                        (getf c2 :signature))))))))
               ;; Create internal functions
               (internal-fns
                 (loop for c in parsed-clauses
                       for internal-name = (getf c :internal-name)
                       for params = (getf c :params)
                       for body = (getf c :body)
                       for fn = (fol-eval `(fn ,internal-name ,params ,@body) env)
                       collect (cons internal-name fn)))
               ;; Collect valid arities for error messages
               (valid-arities
                 (remove-duplicates
                  (loop for c in parsed-clauses
                        collect (if (getf c :has-rest)
                                    (format nil "~A+" (getf c :arity))
                                    (getf c :arity))))))
          ;; Create dispatcher as a CL closure (apply-function supports CL functions)
          (let ((dispatcher
                  (lambda (&rest call-args)
                    (let ((call-arity (length call-args)))
                      ;; Try clauses in sorted order (by arity, then specificity)
                      (loop for c in sorted-clauses
                            for min-arity = (getf c :arity)
                            for has-rest = (getf c :has-rest)
                            for sig = (getf c :signature)
                            for internal-name = (getf c :internal-name)
                            ;; Check if arity matches (exact or >= for rest params)
                            when (if has-rest
                                     (>= call-arity min-arity)
                                     (= call-arity min-arity))
                              ;; Check pattern signature on non-rest args
                              when (args-match-pattern-p
                                    (subseq call-args 0 (min (length sig) call-arity))
                                    sig)
                                return (let ((internal-fn (cdr (cl:assoc internal-name internal-fns))))
                                         (apply-function internal-fn call-args))
                            finally (error 'fol-arity-error
                                           :expected valid-arities
                                           :got call-arity))))))
            ;; Bind the dispatcher to the name
            (let ((sym-name (extract-symbol name)))
              (cl:eval `(cl:defparameter ,sym-name ',dispatcher))
              dispatcher)))
        ;; Single-pattern defn
        (let* ((params (second args))
               (body (cddr args))
               (fn-form `(fn ,name ,params ,@body)))
          (fol-eval `(def ,name ,fn-form) env)))))

;;; --- DEFMACRO ---

(defun eval-defmacro (args env)
  "Evaluate defmacro in single-pattern or multi-pattern form.

   Single-pattern:
     (defmacro name [params] body*)
     Creates a macro that receives unevaluated arguments and returns a form to evaluate.

   Multi-pattern:
     (defmacro name
       ([params1] body1*)
       ([params2] body2*)
       ...)
     Creates a dispatcher macro that routes by arity and pattern match."
  (unless (>= (length args) 2)
    (error 'fol-eval-error :message "defmacro requires name, params/clauses, and body"
           :form (cons 'defmacro args)))
  (let ((name (first args)))
    (if (multi-pattern-defmacro-p args)
        ;; Multi-pattern defmacro
        (let* ((sym-name (extract-symbol name))
               (clauses (rest args))
               ;; Parse each clause
               (parsed-clauses
                 (loop for clause in clauses
                       for idx from 0
                       for parsed = (parse-defmacro-clause clause)
                       for params = (car parsed)
                       for body = (cdr parsed)
                       for param-list = (vector-to-list params)
                       ;; Parse to separate regular params from rest param
                       for (regular-params rest-param) = (multiple-value-list
                                                          (parse-params param-list))
                       for arity = (length regular-params)
                       for has-rest = (cl:not (null rest-param))
                       for signature = (compute-pattern-signature regular-params)
                       for internal-name = (make-pattern-name sym-name idx)
                       collect (list :index idx
                                     :arity arity
                                     :has-rest has-rest
                                     :regular-params regular-params
                                     :rest-param rest-param
                                     :body body
                                     :signature signature
                                     :internal-name internal-name)))
               ;; Sort by arity, then by specificity (most specific first)
               (sorted-clauses
                 (stable-sort (copy-list parsed-clauses)
                              (lambda (c1 c2)
                                (let ((a1 (getf c1 :arity))
                                      (a2 (getf c2 :arity)))
                                  (cond
                                    ((< a1 a2) t)
                                    ((> a1 a2) nil)
                                    ;; Same arity: more specific pattern first
                                    (t (pattern-more-specific-p
                                        (getf c1 :signature)
                                        (getf c2 :signature))))))))
               ;; Create internal macros for each pattern
               (internal-macros
                 (loop for c in parsed-clauses
                       for internal-name = (getf c :internal-name)
                       for regular-params = (getf c :regular-params)
                       for rest-param = (getf c :rest-param)
                       for body = (getf c :body)
                       for macro-obj = (make-macro regular-params body env
                                                   :rest-param rest-param
                                                   :name internal-name)
                       collect (cons internal-name macro-obj)))
               ;; Collect valid arities for error messages
               (valid-arities
                 (remove-duplicates
                  (loop for c in parsed-clauses
                        collect (if (getf c :has-rest)
                                    (format nil "~A+" (getf c :arity))
                                    (getf c :arity))))))
          ;; Create dispatcher as a CL closure that expands the right internal macro
          (let ((dispatcher
                  (lambda (call-args)
                    (let ((call-arity (length call-args)))
                      ;; Try clauses in sorted order (by arity, then specificity)
                      (loop for c in sorted-clauses
                            for min-arity = (getf c :arity)
                            for has-rest = (getf c :has-rest)
                            for sig = (getf c :signature)
                            for internal-name = (getf c :internal-name)
                            ;; Check if arity matches (exact or >= for rest params)
                            when (if has-rest
                                     (>= call-arity min-arity)
                                     (= call-arity min-arity))
                              ;; Check pattern signature on non-rest args
                              ;; For macros, we check unevaluated forms
                              when (macro-args-match-pattern-p
                                    (subseq call-args 0 (min (length sig) call-arity))
                                    sig)
                                return (let ((internal-macro (cdr (cl:assoc internal-name internal-macros))))
                                         (expand-macro internal-macro call-args))
                            finally (error 'fol-arity-error
                                           :expected valid-arities
                                           :got call-arity))))))
            ;; Create multi-macro and bind it
            (let ((multi-macro (make-multi-macro dispatcher
                                                 :name sym-name
                                                 :valid-arities valid-arities)))
              (cl:eval `(cl:defparameter ,sym-name ',multi-macro))
              multi-macro)))
        ;; Single-pattern defmacro
        (let* ((sym-name (extract-symbol name))
               (params (second args))
               (body (cddr args))
               (param-list (if (<vector>? params)
                               (vector-to-list params)
                               params)))
          (multiple-value-bind (regular-params rest-param)
              (parse-params param-list)
            ;; Create the macro object and bind it
            (let ((macro-obj (make-macro regular-params body env
                                         :rest-param rest-param
                                         :name sym-name)))
              (cl:eval `(cl:defparameter ,sym-name ',macro-obj))
              macro-obj))))))

;;; --- DEFINLINE ---

(defun eval-definline (args env)
  "Evaluate (definline name [params] body).
   Defines an inline function that expands at macro-expansion time.
   Unlike Common Lisp's definline, this supports variadic and destructuring arguments.

   The inline function is implemented as a macro that wraps the body in a bind
   form with the parameters bound to the (unevaluated) arguments. This allows
   inlining while preserving proper evaluation order.

   Example:
     (definline square [x] (* x x))
     (square 5)  ; expands to (bind [x 5] (* x x))

   With destructuring:
     (definline add-coords [[x1 y1] [x2 y2]]
       [(+ x1 x2) (+ y1 y2)])

   With variadic args:
     (definline sum-all [& nums]
       (reduce + 0 nums))"
  (unless (>= (length args) 3)
    (error 'fol-eval-error :message "definline requires name, params, and body"
           :form (cons 'definline args)))
  (let* ((name (first args))
         (sym-name (extract-symbol name))
         (params (second args))
         (body (cddr args))
         (param-list (if (<vector>? params)
                         (vector-to-list params)
                         params)))
    (multiple-value-bind (regular-params rest-param)
        (parse-params param-list)
      ;; Create a macro that expands to (bind [params args] body)
      ;; The macro receives unevaluated arguments and constructs the bind form
      (let ((inline-macro (make-macro
                           regular-params
                           (list (make-inline-expansion-body params body))
                           env
                           :rest-param rest-param
                           :name sym-name)))
        ;; Bind the macro to the name
        (cl:eval `(cl:defparameter ,sym-name ',inline-macro))
        inline-macro))))

(defun make-inline-expansion-body (params body)
  "Create the macro body that generates (bind [params args] body).
   PARAMS is the original parameter vector/list.
   BODY is the list of body forms.
   Returns a form that, when evaluated in the macro, produces the bind form."
  ;; We need to generate code that builds:
  ;; (bind [p1 arg1 p2 arg2 ...] body...)
  ;; where p1, p2 are the original param patterns and arg1, arg2 are the macro args
  (let* ((param-list (if (<vector>? params)
                         (vector-to-list params)
                         params))
         ;; Extract just the parameter names/patterns (not &)
         (binding-params (cl:remove-if
                          (lambda (p)
                            (cl:and (symbolp p)
                                    (string= (symbol-name p) "&")))
                          param-list)))
    ;; Build the syntax-quote form that generates the bind
    `(syntax-quote
      (bind ,(apply #'make-vector
                    (loop for p in binding-params
                          collect p
                          collect (list 'unquote p)))
        ,@(loop for form in body
                collect (list 'unquote (list 'quote form)))))))

;;; --- SYNTAX-QUOTE (Quasiquote with unquote, unquote-splicing, auto-gensym) ---

(defun eval-syntax-quote (args env)
  "Evaluate (syntax-quote form).
   Expands a syntax-quoted form with support for:
   - (unquote x) or ~x: evaluate x and insert
   - (unquote-splicing x) or ~@x: evaluate x and splice into list
   - symbol# (auto-gensym): generate unique symbol

   Example:
     (syntax-quote (a (unquote b) c)) with b=42 => (a 42 c)
     (syntax-quote (a (unquote-splicing xs) b)) with xs='(1 2) => (a 1 2 b)
     (syntax-quote (bind (x# 1) x#)) => (bind (G123 1) G123)"
  (unless (= (length args) 1)
    (error 'fol-arity-error :expected 1 :got (length args)
           :form (cons 'syntax-quote args)))
  (let ((gensym-table (make-hash-table :test 'equal)))
    (expand-syntax-quote (first args) env gensym-table)))

(defun expand-syntax-quote (form env gensym-table)
  "Recursively expand a syntax-quoted form.
   GENSYM-TABLE maps auto-gensym symbols (ending in #) to their generated symbols."
  (cond
    ;; Handle unquote: (unquote x) => evaluate x
    ((unquote-form-p form)
     (fol-eval (second form) env))

    ;; Handle unquote-splicing at top level - error, must be inside list
    ((unquote-splicing-form-p form)
     (error 'fol-eval-error
            :message "unquote-splicing (~@) not valid outside of a list"
            :form form))

    ;; Handle lists (may contain unquote-splicing)
    ((consp form)
     (expand-syntax-quote-list form env gensym-table))

    ;; Handle auto-gensym symbols (ending with #) - must check before symbolp
    ((auto-gensym-symbol-p form)
     (get-or-create-gensym form gensym-table))

    ;; Handle regular symbols - return as-is (quoted)
    ((symbolp form)
     form)

    ;; Strings are self-evaluating (and are technically vectors, so check before vectorp)
    ((stringp form)
     form)

    ;; Handle CL vectors (from reader syntax like #(a b c)) - but not strings
    ((cl:and (vectorp form) (cl:not (<vector>? form)))
     (let ((expanded (expand-syntax-quote-list (coerce form 'list) env gensym-table)))
       (coerce expanded 'cl:vector)))

    ;; Handle FOL vectors
    ((<vector>? form)
     (let ((expanded (expand-syntax-quote-list (vector-to-list form) env gensym-table)))
       (apply #'make-vector expanded)))

    ;; Self-evaluating forms (numbers, strings, characters, keywords)
    (t form)))

(defun expand-syntax-quote-list (forms env gensym-table)
  "Expand a list within syntax-quote, handling unquote-splicing."
  (let ((result nil))
    (dolist (form forms)
      (cond
        ;; unquote-splicing: evaluate and splice
        ((unquote-splicing-form-p form)
         (let ((spliced (fol-eval (second form) env)))
           (unless (listp spliced)
             (error 'fol-eval-error
                    :message (format nil "unquote-splicing requires a list, got ~S" spliced)
                    :form form))
           (dolist (item spliced)
             (cl:push item result))))

        ;; Regular form: expand recursively
        (t
         (cl:push (expand-syntax-quote form env gensym-table) result))))
    (nreverse result)))

(defun get-or-create-gensym (symbol gensym-table)
  "Get or create a gensym for an auto-gensym symbol.
   The same auto-gensym symbol# within a syntax-quote maps to the same generated symbol."
  (let ((name (symbol-name symbol)))
    (cl:or (gethash name gensym-table)
           (let* ((base-name (subseq name 0 (1- (length name))))
                  (new-sym (cl:gensym (concatenate 'string base-name "__"))))
             (setf (gethash name gensym-table) new-sym)
             new-sym))))

;;; --- DYNAMIC VARIABLES (make-dynamic, binding) ---

(defun eval-make-dynamic (args env)
  "Evaluate (make-dynamic name value?).
   Creates and returns a new dynamic variable with the given name and optional initial value.
   The name is NOT evaluated - it is treated as a literal symbol (like def).
   The dynamic variable can be bound in an environment and will be auto-dereferenced on lookup.
   Use `binding` to temporarily rebind the value.

   Example:
     (def *counter* (make-dynamic *counter* 0))
     (binding (*counter* 10) *counter*)  ; => 10"
  (let ((len (length args)))
    (unless (<= 1 len 2)
      (error 'fol-arity-error :expected "1 or 2" :got len
             :form (cons 'make-dynamic args)))
    ;; Name is NOT evaluated - treated as a literal symbol (like def)
    (let ((name (extract-symbol (first args)))
          (init-value (if (= len 2)
                          (fol-eval (second args) env)
                          nil)))
      (make-dynamic-var name init-value))))

(defun eval-binding (args env)
  "Evaluate (binding [bindings] body*).
   Temporarily rebinds dynamic variables for the duration of body evaluation.
   Bindings are pairs: [dvar1 val1 dvar2 val2 ...].
   Each dvar must evaluate to a <dynamic-var>.
   Values are pushed onto the dynamic var's stack and popped after body executes.
   Uses unwind-protect to ensure values are popped even if body signals an error.

   Example:
     (def *x* (make-dynamic '*x* 1))
     (binding (*x* 10)
       *x*)  ; => 10
     *x*    ; => 1 (restored)"
  (unless (>= (length args) 1)
    (error 'fol-eval-error :message "binding requires at least bindings"
           :form (cons 'binding args)))
  (let ((bindings-form (first args))
        (body (rest args)))
    ;; Handle both list and vector bindings
    (let ((binding-list (if (<vector>? bindings-form)
                            (vector-to-list bindings-form)
                            bindings-form)))
      ;; Collect dynamic vars and their new values
      (let ((dvars nil)
            (new-values nil))
        ;; First, evaluate all the dynamic var references and values
        (loop for (dvar-form val-form) on binding-list by #'cddr
              do (let ((dvar (cond
                               ((<dynamic-var>? dvar-form) dvar-form)
                               ((cl:and (typep dvar-form 'standard-object)
                                        (let ((n (class-name (class-of dvar-form))))
                                          (cl:and n (string= (symbol-name n) "<DYNAMIC-VAR>"))))
                                dvar-form)
                               ((symbolp dvar-form) 
                                (let ((val (handler-case (lookup env dvar-form)
                                             (fol-unbound-variable () :unbound))))
                                  (cond
                                    ((eq val :unbound)
                                     (if (boundp dvar-form) (symbol-value dvar-form) dvar-form))
                                    ((cl:and (eq val dvar-form) (boundp dvar-form))
                                     (symbol-value dvar-form))
                                    (t val))))
                               ((<symbol>? dvar-form) 
                                (let* ((sym (fol-value dvar-form))
                                       (val (handler-case (lookup env sym)
                                              (fol-unbound-variable () :unbound))))
                                  (cond
                                    ((eq val :unbound)
                                     (if (boundp sym) (symbol-value sym) sym))
                                    ((cl:and (eq val sym) (boundp sym))
                                     (symbol-value sym))
                                    (t val))))
                               (t (fol-eval dvar-form env))))
                       (val (fol-eval val-form env)))
                   (unless (<dynamic-var>? dvar)
                     (when (cl:and (symbolp dvar) (cl:not (boundp dvar)))
                       (error 'fol-eval-error :message (format nil "Variable ~A is unbound" dvar) :form dvar-form))
                     (error 'fol-eval-error
                            :message (format nil "binding requires dynamic variables, got ~S" dvar)
                            :form dvar-form))
                   (cl:push dvar dvars)
                   (cl:push val new-values)))
        (setf dvars (nreverse dvars))
        (setf new-values (nreverse new-values))
        ;; Push all values onto their respective stacks
        (mapc #'dynamic-var-push dvars new-values)
        ;; Evaluate body with unwind-protect to ensure cleanup
        (unwind-protect
             (let ((result nil))
               (dolist (form body)
                 (setf result (fol-eval form env)))
               result)
          ;; Cleanup: pop all values from their stacks
          (mapc #'dynamic-var-pop dvars))))))

;;; --- LAZY-SEQ ---

(defun eval-lazy-seq (args env)
  "Evaluate (lazy-seq body).
   Creates a lazy sequence that delays evaluation of body until realized.
   The body should return a seq (typically via conj) or nil.

   Example:
     ;; Infinite sequence of integers starting from n
     (defn integers (n)
       (lazy-seq (conj (integers (+ n 1)) n)))

     ;; First 5 integers starting from 0
     (take 5 (integers 0))  ; => (0 1 2 3 4)"
  (unless (= 1 (length args))
    (error 'fol-arity-error :expected 1 :got (length args)
           :form (cons 'lazy-seq args)))
  (let ((body (first args)))
    ;; Capture the environment for the closure
    ;; The body is evaluated lazily when the sequence is realized
    (make-lazy-seq (lambda () (fol-eval body env)))))

;;; --- THREADING MACROS (-> and ->>) ---

(defun apply-threaded (x form thread-position env)
  "Apply FORM to X in a threaded context.
   THREAD-POSITION is :first for -> or :last for ->>.
   If FORM is a bare symbol, call it as a function with X as the only arg.
   If FORM is a list (fn arg*), evaluate fn and args, then call with X inserted."
  (cond
    ;; If form is a bare symbol/keyword, evaluate it and apply to x
    ((or (symbolp form) (keywordp form))
     (let ((fn (fol-eval form env)))
       (apply-function fn (list x))))
    ;; If form is a wrapped FOL symbol
    ((<symbol>? form)
     (let ((fn (fol-eval form env)))
       (apply-function fn (list x))))
    ;; If form is a list (fn arg1 arg2 ...), evaluate fn and args, insert x
    ((cl:listp form)
     (let* ((fn-form (car form))
            (arg-forms (cdr form))
            (fn (fol-eval fn-form env))
            (evaluated-args (mapcar (lambda (arg) (fol-eval arg env)) arg-forms)))
       (if (eq thread-position :first)
           ;; Thread-first: x is the first argument
           (apply-function fn (cons x evaluated-args))
           ;; Thread-last: x is the last argument
           (apply-function fn (append evaluated-args (list x))))))
    ;; For FOL vectors, treat them like lists
    ((<vector>? form)
     (let* ((form-list (vector-to-list form))
            (fn-form (car form-list))
            (arg-forms (cdr form-list))
            (fn (fol-eval fn-form env))
            (evaluated-args (mapcar (lambda (arg) (fol-eval arg env)) arg-forms)))
       (if (eq thread-position :first)
           (apply-function fn (cons x evaluated-args))
           (apply-function fn (append evaluated-args (list x))))))
    ;; Otherwise, evaluate form as a function and apply to x
    (t
     (let ((fn (fol-eval form env)))
       (apply-function fn (list x))))))

(defun eval-thread-first (args env)
  "Evaluate (-> x form*).
   Threads x through each form as the first argument.

   Example:
     (-> 5 (+ 3) (* 2))
     ; expands to (* (+ 5 3) 2)
     ; evaluates to 16

   For bare symbols:
     (-> x f g)
     ; expands to (g (f x))"
  (unless (>= (length args) 1)
    (error 'fol-arity-error :expected "at least 1" :got (length args)
           :form (cons '-> args)))
  (let ((x (fol-eval (first args) env))
        (forms (rest args)))
    (if (null forms)
        x  ; No forms, just return x
        (dolist (form forms x)
          (setf x (apply-threaded x form :first env))))))

(defun eval-thread-last (args env)
  "Evaluate (->> x form*).
   Threads x through each form as the last argument.

   Example:
     (->> 5 (+ 3) (* 2))
     ; expands to (* 2 (+ 3 5))
     ; evaluates to 16

   For bare symbols:
     (->> x f g)
     ; expands to (g (f x))"
  (unless (>= (length args) 1)
    (error 'fol-arity-error :expected "at least 1" :got (length args)
           :form (cons '->> args)))
  (let ((x (fol-eval (first args) env))
        (forms (rest args)))
    (if (null forms)
        x  ; No forms, just return x
        (dolist (form forms x)
          (setf x (apply-threaded x form :last env))))))

(defun eval-cond-thread-first (args env)
  "Evaluate (cond-> x test1 form1 test2 form2 ...).
   Threads x through forms where corresponding test is true (thread-first).

   Example:
     (cond-> 1 true (+ 1) false (+ 10) true (* 2))
     ; evaluates (+ 1 1) => 2, skips (+ 10), evaluates (* 2 2) => 4
     ; returns 4"
  (unless (>= (length args) 1)
    (error 'fol-arity-error :expected "at least 1" :got (length args)
           :form (cons 'cond-> args)))
  (let ((x (fol-eval (first args) env))
        (clauses (rest args)))
    ;; Process pairs of (test form)
    (loop while (>= (length clauses) 2)
          for test = (fol-eval (first clauses) env)
          for form = (second clauses)
          do (when test
               (setf x (apply-threaded x form :first env)))
             (setf clauses (cddr clauses)))
    x))

(defun eval-cond-thread-last (args env)
  "Evaluate (cond->> x test1 form1 test2 form2 ...).
   Threads x through forms where corresponding test is true (thread-last).

   Example:
     (cond->> [1 2 3] true (map inc) false (map dec))
     ; evaluates to [2 3 4]"
  (unless (>= (length args) 1)
    (error 'fol-arity-error :expected "at least 1" :got (length args)
           :form (cons 'cond->> args)))
  (let ((x (fol-eval (first args) env))
        (clauses (rest args)))
    ;; Process pairs of (test form)
    (loop while (>= (length clauses) 2)
          for test = (fol-eval (first clauses) env)
          for form = (second clauses)
          do (when test
               (setf x (apply-threaded x form :last env)))
             (setf clauses (cddr clauses)))
    x))

;;; --- FOL MOP FORMS ---

(defun eval-defgeneric* (args env)
  "Evaluate (defgeneric* name [lambda-list] option*) or
   (defgeneric* name ([lambda-list-1] [lambda-list-2] ...) option*).
   Defines a generic function with FOL syntax where lambda list is a vector
   or a list of vectors for multi-arity."
  (unless (>= (length args) 2)
    (error 'fol-eval-error :message "defgeneric* requires name and lambda-list"
           :form (cons 'defgeneric* args)))
  (let* ((name (first args))
         (lambda-list-spec (second args))
         (options (cddr args))
         ;; Handle both single vector and list of vectors
         (lambda-list-vec
           (cond
             ;; Single vector: evaluate it
             ((fol.collection:<vector>? lambda-list-spec)
              (fol-eval lambda-list-spec env))
             ;; Multi-arity: list of vectors - evaluate each vector
             ((and (listp lambda-list-spec)
                   (not (null lambda-list-spec))
                   (every #'fol.collection:<vector>? lambda-list-spec))
              (mapcar (lambda (v) (fol-eval v env)) lambda-list-spec))
             ;; Otherwise evaluate (handles CL-style list lambda lists)
             (t (fol-eval lambda-list-spec env)))))
    (fol.fol-mop:eval-defgeneric* name lambda-list-vec options)))

(defun eval-defclass* (args env)
  "Evaluate (defclass* name [superclasses] [slots] class-option*).
   Defines a class with FOL syntax where superclasses and slots are vectors."
  (unless (>= (length args) 3)
    (error 'fol-eval-error :message "defclass* requires name, superclasses, and slots"
           :form (cons 'defclass* args)))
  (let ((name (first args))
        (superclasses-vec (fol-eval (second args) env))
        (slots-vec (fol-eval (third args) env))
        (class-options (cdddr args)))
    (fol.fol-mop:eval-defclass* name superclasses-vec slots-vec class-options)))

(defun eval-defmethod* (args env)
  "Evaluate (defmethod* name qualifier* [specialized-lambda-list] body*).
   Defines a method with FOL syntax where the specialized lambda list is a vector."
  (unless (>= (length args) 2)
    (error 'fol-eval-error :message "defmethod* requires name and lambda-list"
           :form (cons 'defmethod* args)))
  (let ((name (first args))
        (remaining (rest args))
        (qualifiers nil)
        (lambda-list-vec nil)
        (body nil))
    ;; Collect qualifiers (atoms that aren't the lambda list vector)
    ;; Use cl:and since fol.logop:and is shadowed in this package
    (loop while (cl:and remaining
                        (cl:not (<vector>? (car remaining)))
                        (cl:not (listp (car remaining))))
          do (cl:push (cl:pop remaining) qualifiers))
    (setf qualifiers (nreverse qualifiers))
    ;; Next should be the lambda list
    (when remaining
      (setf lambda-list-vec (fol-eval (cl:pop remaining) env))
      (setf body remaining))
    (fol.fol-mop:eval-defmethod* name qualifiers lambda-list-vec body)))

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
              do (cl:push (extract-symbol var) params)
                 (cl:push (fol-eval val-form env) values))
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
        (t (cl:push form body))))
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
  "Evaluate a function or macro application (op arg*).
   For functions: evaluate args, then apply.
   For macros: pass unevaluated args, expand, then evaluate result.
   For multi-macros: dispatch to the appropriate pattern, expand, then evaluate."
  (let ((fn (fol-eval op env)))
    (cond
      ((<macro>? fn)
       ;; Single-pattern macro: expand with unevaluated args, then evaluate result
       (let ((expanded (expand-macro fn args)))
         (fol-eval expanded env)))
      ((<multi-macro>? fn)
       ;; Multi-pattern macro: dispatch and expand, then evaluate result
       (let ((expanded (expand-multi-macro fn args)))
         (fol-eval expanded env)))
      (t
       ;; Function: evaluate args first
       (let ((evaluated-args (mapcar (lambda (arg) (fol-eval arg env)) args)))
         (apply-function fn evaluated-args))))))

(defgeneric apply-function (fn args)
  (:documentation "Apply function FN to ARGS."))

(defmethod apply-function ((fn function) args)
  "Apply a CL function to args."
  (apply fn args))

(defmethod apply-function ((fn <function>) args)
  "Apply a FOL function to args.
   Supports destructuring in parameter patterns."
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
      ;; Bind regular parameters (with destructuring support)
      (loop for param in params
            for arg in args
            do (setf fn-env (bind-param-with-destructuring param arg fn-env)))
      ;; Bind rest parameter if present (with destructuring support)
      (when rest-param
        (setf fn-env (bind-param-with-destructuring rest-param (nthcdr num-params args) fn-env)))
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
  "Symbols and keywords can be used as functions to access collections.
   Works on dicts and sets: (:key coll) => (get coll :key)"
  (unless (= (length args) 1)
    (error 'fol-arity-error :expected 1 :got (length args)))
  (let ((coll (first args)))
    (cond
      ((<dict>? coll) (get coll fn))
      ((<set>? coll) (get coll fn))
      (t (error 'fol-eval-error
                :message (format nil "Cannot use symbol ~S as function on ~S" fn coll))))))

;;; Collections as functions (for element access, Clojure style)
(defmethod apply-function ((coll <collection>) args)
  "Collections can be used as functions to access their elements.
   (coll key) => (get coll key)
   (coll key default) => (get coll key default)"
  (let ((num-args (length args)))
    (cond
      ((= num-args 1)
       (get coll (first args)))
      ((= num-args 2)
       (get coll (first args) (second args)))
      (t (error 'fol-arity-error :expected "1 or 2" :got num-args)))))

;;; ============================================================================
;;; Macro Expansion
;;; ============================================================================

(defun expand-macro (macro args)
  "Expand a macro with the given unevaluated arguments.
   Returns the expanded form (not yet evaluated).
   Supports destructuring in parameter patterns."
  (let* ((params (macro-params macro))
         (rest-param (macro-rest-param macro))
         (body (macro-body macro))
         (closure-env (macro-env macro))
         (name (macro-name macro))
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
    ;; Create environment with parameter bindings (args are NOT evaluated)
    (let ((macro-env closure-env))
      ;; Bind regular parameters to unevaluated args (with destructuring support)
      (loop for param in params
            for arg in args
            do (setf macro-env (bind-param-with-destructuring param arg macro-env)))
      ;; Bind rest parameter if present (with destructuring support)
      (when rest-param
        (setf macro-env (bind-param-with-destructuring rest-param (nthcdr num-params args) macro-env)))
      ;; Bind macro name for recursive macros if present
      (when name
        (setf macro-env (make-env macro-env name macro)))
      ;; Evaluate body to produce expanded form
      (let ((result nil))
        (dolist (form body)
          (setf result (fol-eval form macro-env)))
        result))))

(defun macroexpand-1 (form env)
  "If FORM is a macro call, expand it once and return (values expanded-form t).
   Otherwise return (values form nil).
   Handles both single-pattern macros and multi-pattern macros.
   Checks both FOL environment and CL globals (for multi-pattern macros)."
  (if (cl:and (consp form) (symbolp (car form)))
      (let* ((op-sym (car form))
             (op-value (handler-case (lookup env op-sym)
                         (fol-unbound-variable ()
                           ;; Not in FOL env, check CL globals
                           (if (boundp op-sym)
                               (symbol-value op-sym)
                               nil)))))
        (cond
          ((<macro>? op-value)
           (values (expand-macro op-value (cdr form)) t))
          ((<multi-macro>? op-value)
           (values (expand-multi-macro op-value (cdr form)) t))
          (t
           (values form nil))))
      (values form nil)))

(defun macroexpand (form env)
  "Repeatedly expand FORM until it is no longer a macro call.
   Returns the fully expanded form."
  (loop
    (multiple-value-bind (expanded expandedp) (macroexpand-1 form env)
      (if expandedp
          (setf form expanded)
          (return form)))))

;;; ============================================================================
;;; Helper Functions
;;; ============================================================================

(defun special-form-p (op name)
  "Check if OP matches the special form NAME, comparing by symbol name.
   This allows forms from any package to be recognized as special forms."
  (cl:and (symbolp op)
       (string-equal (symbol-name op) (symbol-name name))))

(defun extract-symbol (form)
  "Extract a raw symbol from FORM (handles wrapped symbols)."
  (cond
    ((symbolp form) form)
    ((<symbol>? form) (fol-value form))
    (t (error 'fol-eval-error
              :message (format nil "Expected symbol, got ~S" form)
              :form form))))

;; vector-to-list is imported from fol.fol-mop and handles both vectors and non-vectors

(defun parse-params (param-list)
  "Parse a parameter list, returning (values regular-params rest-param).
   Handles & for rest parameters.
   Parameters can be symbols or destructuring patterns (vectors, maps)."
  (let ((regular nil)
        (rest-param nil)
        (saw-ampersand nil))
    (dolist (p param-list)
      (cond
        ;; Check for & symbol
        ((cl:and (symbolp p) (string= (symbol-name p) "&"))
         (setf saw-ampersand t))
        ((cl:and (<symbol>? p) (string= (symbol-name (fol-value p)) "&"))
         (setf saw-ampersand t))
        ;; After &, capture rest param (can also be a destructuring pattern)
        (saw-ampersand
         (setf rest-param p)
         (setf saw-ampersand nil))
        ;; Regular param - can be symbol or destructuring pattern
        (t
         (cl:push p regular))))
    (values (nreverse regular) rest-param)))

(defun bind-param-with-destructuring (param value env)
  "Bind PARAM to VALUE in ENV, supporting destructuring.
   PARAM can be a symbol or a destructuring pattern (vector, map).
   Returns the new environment with all bindings."
  (cond
    ;; Simple symbol - just bind directly
    ((symbolp param)
     (make-env env param value))
    ;; Wrapped symbol - extract and bind
    ((<symbol>? param)
     (make-env env (fol-value param) value))
    ;; Destructuring pattern - use destructure-pattern
    ((or (<vector>? param) (<dict>? param) (cl:listp param))
     (let ((bindings (destructure-pattern param value)))
       (dolist (binding bindings)
         (setf env (make-env env (car binding) (cdr binding))))
       env))
    (t
     (error 'fol-eval-error
            :message (format nil "Invalid parameter: ~S" param)
            :form param))))
