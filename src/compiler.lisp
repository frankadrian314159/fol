;;; FOL Compiler - Top-Level Entry Point
;;;
;;; Compiles FOL source forms to Common Lisp code. The generated CL code
;;; can then be compiled by SBCL to native machine code.
;;;
;;; The compilation pipeline:
;;;   FOL source -> Reader -> S-expressions -> AST -> CL code -> SBCL native
;;;
;;; Currently handles:
;;;   1. Literals (numbers, strings, booleans, keywords, characters)
;;;   2. Symbol references (variable lookup)
;;;   3. Function calls
;;;   4. Special forms: if, do, bind

(in-package :fol.compiler)

;;; ---------------------------------------------------------------------------
;;; Compilation Result
;;; ---------------------------------------------------------------------------

(defstruct compilation-result
  "Result of compiling a FOL form."
  (code nil) ; the generated Common Lisp form
  (warnings nil) ; list of warning strings
  (errors nil)) ; list of error strings

;;; ---------------------------------------------------------------------------
;;; FOL Vector Helpers
;;; ---------------------------------------------------------------------------

(defun fol-vector-p (x)
  "Check if X is a FOL <vector> instance (from the reader's [...] syntax)."
  (typep x 'fol.compiler.collections:<vector>))

(defun fol-vector-to-list (v)
  "Convert a FOL <vector> to a CL list of its elements."
  (fol.compiler.collections:collection-seq v))

;;; ---------------------------------------------------------------------------
;;; Phase 1: Parse (reader s-expressions -> AST)
;;; ---------------------------------------------------------------------------

(defun parse-form (form)
  "Parse a reader-produced s-expression into an AST node."
  (typecase form
    (null (fol.compiler.ast:make-literal-node :value nil :form form))
    (boolean (fol.compiler.ast:make-literal-node :value form :form form))
    (keyword (fol.compiler.ast:make-literal-node :value form :form form))
    (number (fol.compiler.ast:make-literal-node :value form :form form))
    (string (fol.compiler.ast:make-literal-node :value form :form form))
    (character (fol.compiler.ast:make-literal-node :value form :form form))
    (symbol (fol.compiler.ast:make-symbol-ref-node :name form :form form))
    (cons
      (when (symbolp (car form))
            (format t "~&Parse-compound: Op=~S Name=~S Special=~A~%"
              (car form)
              (symbol-name (car form))
              (special-form-p (car form))))
      (parse-compound form))
    (t (cond
        ;; FOL vector literal [a b c]
        ((fol-vector-p form)
          (fol.compiler.ast:make-vector-node
            :elements (mapcar #'parse-form (fol-vector-to-list form))
            :form form))
        ;; FOL dict literal {:key val ...}
        ((typep form 'fol.compiler.collections:<dict>)
          (let ((pairs (fol.compiler.collections:collection-seq form)))
            (fol.compiler.ast:make-dict-node
              :entries (mapcar (lambda (pair)
                                 (cons (parse-form (car pair))
                                       (parse-form (cdr pair))))
                           pairs)
              :form form)))
        ;; FOL set literal #{a b c}
        ((typep form 'fol.compiler.collections:<set>)
          (fol.compiler.ast:make-set-node
            :elements (mapcar #'parse-form (fol.compiler.collections:collection-seq form))
            :form form))
        (t (error "Cannot parse form: ~S" form))))))

(defun parse-compound (form)
  "Parse a compound form (list) into an AST node.
   Dispatches on the operator to handle macros, special forms, and function calls."
  (cond
   ;; Check for macros first and expand them
   ((and (symbolp (car form)) (macro-p (car form)))
     (let ((expanded (macroexpand-1 form)))
       (parse-form expanded)))
   ;; Then check for special forms
   ((special-form-p (car form))
     (parse-special-form form))
   ;; Otherwise it's a function call
   (t
     (parse-function-call form))))

(defun parse-function-call (form)
  "Parse a function call: (f arg1 arg2 ...)."
  (destructuring-bind (op &rest args) form
    (fol.compiler.ast:make-call-node
      :operator (parse-form op)
      :args (mapcar #'parse-form args)
      :form form)))

(defun parse-if (form)
  "Parse an if form: (if test then else)."
  (destructuring-bind (op test then &rest else-forms) form
    (declare (ignore op))
    (fol.compiler.ast:make-if-node
      :test (parse-form test)
      :then (parse-form then)
      :else (when else-forms (mapcar #'parse-form else-forms))
      :form form)))

(defun parse-do (form)
  "Parse a do form: (do expr1 expr2 ...)."
  (destructuring-bind (op &rest body) form
    (declare (ignore op))
    (fol.compiler.ast:make-do-node
      :body (mapcar #'parse-form body)
      :form form)))

(defun parse-bind (form)
  "Parse a bind form: (bind [pattern init ...] body ...).
   The first argument is a vector (or list) of alternating pattern/init pairs.
   Patterns can be simple symbols or vectors for destructuring.
   Destructuring patterns support multiple values:
     (bind [#(a b c) (values 1 2 3)] body)"
  (destructuring-bind (op bindings &rest body) form
    (declare (ignore op))
    (let ((parsed-bindings '())
          (binding-list (cond
                         ((fol-vector-p bindings) (fol-vector-to-list bindings))
                         ((consp bindings) bindings)
                         (t nil))))
      (loop for (pattern init) on binding-list by #'cddr
            do (push (cons pattern (parse-form init)) parsed-bindings))
      (fol.compiler.ast:make-bind-node
        :bindings (nreverse parsed-bindings)
        :body (mapcar #'parse-form body)
        :form form))))

(defun parse-quote (form)
  "Parse a quote form: (quote x) or 'x."
  (destructuring-bind (op &rest args) form
    (declare (ignore op))
    (if (= (length args) 1)
        (fol.compiler.ast:make-quote-node :value (car args) :form form)
        (error "Invalid quote form: ~S" form))))

(defun parse-fn (form)
  "Parse a fn form into an fn-node.
   Supported syntaxes:
     (fn [params] body ...)                          - single clause, no name
     (fn name [params] body ...)                     - single clause, named
     (fn ([p1] b1 ...) ([p2] b2 ...) ...)            - multi-clause, no name
     (fn name ([p1] b1 ...) ([p2] b2 ...) ...)       - multi-clause, named"
  (destructuring-bind (op &rest args) form
    (declare (ignore op))
    (labels ((parse-clause (clause)
                           "Parse a single clause (list starting with a param vector) into (params . body-nodes)."
                           (destructuring-bind (params &rest body) clause
                             (cons params (mapcar #'parse-form body))))
             (multi-clause-p (forms)
                             "Check if FORMS looks like multi-clause: each is a list whose car is a vector."
                             (and (>= (length forms) 1)
                                  (listp (first forms))
                                  (not (null (first forms)))
                                  (fol-vector-p (first (first forms))))))
      (cond
       ;; Single clause, no name: (fn [params] body ...)
       ((and (>= (length args) 1)
             (fol-vector-p (first args)))
         (fol.compiler.ast:make-fn-node
           :name nil
           :clauses (list (cons (first args) (mapcar #'parse-form (rest args))))
           :form form))
       ;; Named forms: first arg is a symbol
       ((and (>= (length args) 2)
             (symbolp (first args))
             (not (null (first args))))
         (cond
          ;; Single clause, named: (fn name [params] body ...)
          ((fol-vector-p (second args))
            (fol.compiler.ast:make-fn-node
              :name (first args)
              :clauses (list (cons (second args) (mapcar #'parse-form (cddr args))))
              :form form))
          ;; Multi-clause, named: (fn name ([p1] b1 ...) ([p2] b2 ...) ...)
          ((multi-clause-p (rest args))
            (fol.compiler.ast:make-fn-node
              :name (first args)
              :clauses (mapcar #'parse-clause (rest args))
              :form form))
          (t (error "Invalid fn form: ~S" form))))
       ;; Multi-clause, no name: (fn ([p1] b1 ...) ([p2] b2 ...) ...)
       ((multi-clause-p args)
         (fol.compiler.ast:make-fn-node
           :name nil
           :clauses (mapcar #'parse-clause args)
           :form form))
       (t (error "Invalid fn form: ~S" form))))))

(defun parse-thread-first (form)
  "Parse a thread-first form: (-> x form1 form2 ...).
   Threads x through each form as the first argument.
   All forms (including the initial value) are parsed and stored."
  (destructuring-bind (op &rest args) form
    (declare (ignore op))
    (unless (>= (length args) 1)
      (error "-> requires at least one argument: ~S" form))
    (fol.compiler.ast:make-thread-first-node
      :forms (mapcar #'parse-form args)
      :form form)))

(defun parse-thread-last (form)
  "Parse a thread-last form: (->> x form1 form2 ...).
   Threads x through each form as the last argument.
   All forms (including the initial value) are parsed and stored."
  (destructuring-bind (op &rest args) form
    (declare (ignore op))
    (unless (>= (length args) 1)
      (error "->> requires at least one argument: ~S" form))
    (fol.compiler.ast:make-thread-last-node
      :forms (mapcar #'parse-form args)
      :form form)))

(defun parse-some-thread-first (form)
  "Parse a nil-safe thread-first form: (some-> x form1 form2 ...).
   Short-circuits on nil at each step."
  (destructuring-bind (op &rest args) form
    (declare (ignore op))
    (unless (>= (length args) 1)
      (error "some-> requires at least one argument: ~S" form))
    (fol.compiler.ast:make-some-thread-first-node
      :forms (mapcar #'parse-form args)
      :form form)))

(defun parse-some-thread-last (form)
  "Parse a nil-safe thread-last form: (some->> x form1 form2 ...).
   Short-circuits on nil at each step."
  (destructuring-bind (op &rest args) form
    (declare (ignore op))
    (unless (>= (length args) 1)
      (error "some->> requires at least one argument: ~S" form))
    (fol.compiler.ast:make-some-thread-last-node
      :forms (mapcar #'parse-form args)
      :form form)))

(defun parse-as-thread (form)
  "Parse a named threading form: (as-> expr name form1 form2 ...).
   Binds expr to name, then threads through each form."
  (destructuring-bind (op expr name &rest forms) form
    (declare (ignore op))
    (unless (symbolp name)
      (error "as-> binding name must be a symbol: ~S" form))
    (fol.compiler.ast:make-as-thread-node
      :expr (parse-form expr)
      :name name
      :forms (mapcar #'parse-form forms)
      :form form)))

(defun parse-vector (form)
  "Parse a vector form: (vector elem1 elem2 ...)."
  (destructuring-bind (op &rest args) form
    (declare (ignore op))
    (fol.compiler.ast:make-vector-node
      :elements (mapcar #'parse-form args)
      :form form)))

(defun parse-dict (form)
  "Parse a dict form: (dict key1 val1 key2 val2 ...).
   Keys and values alternate; must be an even number of arguments."
  (destructuring-bind (op &rest args) form
    (declare (ignore op))
    (unless (evenp (length args))
      (error "Dict form must have an even number of arguments: ~S" form))
    (fol.compiler.ast:make-dict-node
      :entries (loop for (k v) on args by #'cddr
                     collect (cons (parse-form k) (parse-form v)))
      :form form)))

(defun parse-set (form)
  "Parse a set form: (set elem1 elem2 ...)."
  (destructuring-bind (op &rest args) form
    (declare (ignore op))
    (fol.compiler.ast:make-set-node
      :elements (mapcar #'parse-form args)
      :form form)))

(defun parse-defmacro (form)
  "Parse a defmacro form: (defmacro name [params] body ...).
   Params support destructuring but not predicate specializers."
  (destructuring-bind (op name params &rest body) form
    (declare (ignore op))
    (fol.compiler.ast:make-defmacro-node
      :name name
      :params params
      :body (mapcar #'parse-form body)
      :form form)))

(defun parse-defclass (form)
  "Parse a defclass form: (defclass <name> [supers] [slots] option*).
   Superclasses and slots are specified as vectors.
   Slots can be simple symbols or vectors of [name :initarg ... :accessor ...]."
  (destructuring-bind (op name supers-vec slots-vec &rest options) form
    (declare (ignore op options))
    (let ((supers (fol-vector-to-list supers-vec))
          (slots (mapcar (lambda (s)
                           (if (fol-vector-p s) (fol-vector-to-list s) s))
                     (fol-vector-to-list slots-vec))))
      (fol.compiler.ast:make-defclass-node
        :name name
        :superclasses supers
        :slots slots
        :form form))))

(defun parse-defgeneric (form)
  "Parse a defgeneric form:
   (defgeneric name [params] option*)               - single pattern
   (defgeneric name ([params1] [params2] ...) option*) - multi-pattern"
  (destructuring-bind (op name lambda-spec &rest options) form
    (declare (ignore op))
    (let ((lambda-lists
           (cond
            ;; Single pattern: a vector
            ((fol-vector-p lambda-spec)
              (list (fol-vector-to-list lambda-spec)))
            ;; Multi-pattern: list of vectors
            ((and (listp lambda-spec)
                  (not (null lambda-spec))
                  (every #'fol-vector-p lambda-spec))
              (mapcar #'fol-vector-to-list lambda-spec))
            (t (error "Invalid defgeneric lambda-list: ~S" lambda-spec)))))
      (fol.compiler.ast:make-defgeneric-node
        :name name
        :lambda-lists lambda-lists
        :options options
        :form form))))

(defun parse-defmethod (form)
  "Parse a defmethod form:
   (defmethod name [params] body ...)               - single clause
   (defmethod name ([params1] body1) ([params2] body2) ...) - multi-clause
   Each clause is a list starting with a param vector."
  (destructuring-bind (op name &rest args) form
    (declare (ignore op))
    (labels ((parse-clause (clause)
                           "Parse a single clause (list starting with a param vector) into (params . body-nodes)."
                           (destructuring-bind (params &rest body) clause
                             (cons params (mapcar #'parse-form body))))
             (multi-clause-p (forms)
                             "Check if FORMS looks like multi-clause: each is a list whose car is a vector."
                             (and (>= (length forms) 1)
                                  (listp (first forms))
                                  (not (null (first forms)))
                                  (fol-vector-p (first (first forms))))))
      (cond
       ;; Single clause: (defmethod name [params] body ...)
       ((and (>= (length args) 1)
             (fol-vector-p (first args)))
         (fol.compiler.ast:make-defmethod-node
           :name name
           :clauses (list (cons (first args) (mapcar #'parse-form (rest args))))
           :form form))
       ;; Multi-clause: (defmethod name ([p1] b1 ...) ([p2] b2 ...) ...)
       ((multi-clause-p args)
         (fol.compiler.ast:make-defmethod-node
           :name name
           :clauses (mapcar #'parse-clause args)
           :form form))
       (t (error "Invalid defmethod form: ~S" form))))))

(defun parse-def (form)
  "Parse a def form: (def name value) or (def name).
   Compiles to a top-level variable definition."
  (destructuring-bind (op name &optional (value nil value-p)) form
    (declare (ignore op))
    (fol.compiler.ast:make-def-node
      :name name
      :value (when value-p (parse-form value))
      :form form)))

(defun parse-defdynamic (form)
  "Parse a defdynamic form: (defdynamic *name* value) or (defdynamic *name*).
   Explicit-intent alias for def — both compile to defvar."
  (destructuring-bind (op name &optional (value nil value-p)) form
    (declare (ignore op))
    (fol.compiler.ast:make-defdynamic-node
      :name name
      :value (when value-p (parse-form value))
      :form form)))

(defun parse-binding (form)
  "Parse a binding form: (binding [*var1* val1 *var2* val2 ...] body ...).
   Dynamically rebinds special variables for the duration of body."
  (destructuring-bind (op bindings &rest body) form
    (declare (ignore op))
    (let ((binding-list (cond
                         ((fol-vector-p bindings) (fol-vector-to-list bindings))
                         ((consp bindings) bindings)
                         (t nil))))
      (fol.compiler.ast:make-binding-node
        :bindings (loop for (name init) on binding-list by #'cddr
                        collect (cons name (parse-form init)))
        :body (mapcar #'parse-form body)
        :form form))))

(defun parse-letfn (form)
  "Parse a letfn form: (letfn [(name [params] body...) ...] body...).
   The bindings vector contains fn-specs in one of two formats:
     Single-arity:  (name [params] body...)
     Multi-arity:   (name ([params1] body1...) ([params2] body2...))
   Each binding is stored as (name . clauses) where each clause is
   (params-vec . body-nodes), matching the format expected by compile-fn."
  (destructuring-bind (op bindings-vec &rest body) form
    (declare (ignore op))
    (unless (fol-vector-p bindings-vec)
      (error "letfn bindings must be a vector: ~S" form))
    (let ((fn-specs (fol-vector-to-list bindings-vec)))
      (fol.compiler.ast:make-letfn-node
        :bindings (mapcar (lambda (spec)
                            (unless (and (listp spec) (>= (length spec) 2))
                              (error "letfn fn-spec must be (name [params] body...): ~S" spec))
                            (destructuring-bind (name &rest args) spec
                              (unless (symbolp name)
                                (error "letfn fn name must be a symbol: ~S" name))
                              (let ((clauses
                                     (cond
                                      ;; Single-arity: (name [params] body...)
                                      ((fol-vector-p (first args))
                                        (list (cons (first args)
                                                    (mapcar #'parse-form (rest args)))))
                                      ;; Multi-arity: (name ([p1] b1...) ([p2] b2...))
                                      ((and (>= (length args) 1)
                                            (listp (first args))
                                            (not (null (first args)))
                                            (fol-vector-p (first (first args))))
                                        (mapcar (lambda (clause)
                                                  (destructuring-bind (params &rest body-forms) clause
                                                    (cons params (mapcar #'parse-form body-forms))))
                                            args))
                                      (t (error "Invalid letfn fn-spec: ~S" spec)))))
                                (cons name clauses))))
                      fn-specs)
        :body (mapcar #'parse-form body)
        :form form))))

(defun parse-defn (form)
  "Parse a defn form into a defn-node.
   Supported syntaxes:
     (defn name [params] body ...)                 - single clause
     (defn name ([p1] b1 ...) ([p2] b2 ...) ...)   - multi-clause"
  (destructuring-bind (op name &rest args) form
    (declare (ignore op))
    (labels ((parse-clause (clause)
                           (destructuring-bind (params &rest body) clause
                             (cons params (mapcar #'parse-form body))))
             (multi-clause-p (forms)
                             (and (>= (length forms) 1)
                                  (listp (first forms))
                                  (not (null (first forms)))
                                  (fol-vector-p (first (first forms))))))
      (cond
       ;; Single clause: (defn name [params] body ...)
       ((and (>= (length args) 1)
             (fol-vector-p (first args)))
         (fol.compiler.ast:make-defn-node
           :name name
           :clauses (list (cons (first args) (mapcar #'parse-form (rest args))))
           :form form))
       ;; Multi-clause: (defn name ([p1] b1 ...) ([p2] b2 ...) ...)
       ((multi-clause-p args)
         (fol.compiler.ast:make-defn-node
           :name name
           :clauses (mapcar #'parse-clause args)
           :form form))
       (t (error "Invalid defn form: ~S" form))))))

(defun parse-defn-private (form)
  "Parse a defn- form: private function definition.
   Same syntax as defn but emits a non-exported defun."
  (destructuring-bind (op name &rest args) form
    (declare (ignore op))
    (labels ((parse-clause (clause)
                           (destructuring-bind (params &rest body) clause
                             (cons params (mapcar #'parse-form body))))
             (multi-clause-p (forms)
                             (and (>= (length forms) 1)
                                  (listp (first forms))
                                  (not (null (first forms)))
                                  (fol-vector-p (first (first forms))))))
      (cond
       ((and (>= (length args) 1)
             (fol-vector-p (first args)))
         (fol.compiler.ast:make-defn-private-node
           :name name
           :clauses (list (cons (first args) (mapcar #'parse-form (rest args))))
           :form form))
       ((multi-clause-p args)
         (fol.compiler.ast:make-defn-private-node
           :name name
           :clauses (mapcar #'parse-clause args)
           :form form))
       (t (error "Invalid defn- form: ~S" form))))))

(defun parse-definline (form)
  "Parse a definline form: inline function definition.
   Same syntax as defn but emits (declaim (inline name)) + defun."
  (destructuring-bind (op name &rest args) form
    (declare (ignore op))
    (labels ((parse-clause (clause)
                           (destructuring-bind (params &rest body) clause
                             (cons params (mapcar #'parse-form body))))
             (multi-clause-p (forms)
                             (and (>= (length forms) 1)
                                  (listp (first forms))
                                  (not (null (first forms)))
                                  (fol-vector-p (first (first forms))))))
      (cond
       ((and (>= (length args) 1)
             (fol-vector-p (first args)))
         (fol.compiler.ast:make-definline-node
           :name name
           :clauses (list (cons (first args) (mapcar #'parse-form (rest args))))
           :form form))
       ((multi-clause-p args)
         (fol.compiler.ast:make-definline-node
           :name name
           :clauses (mapcar #'parse-clause args)
           :form form))
       (t (error "Invalid definline form: ~S" form))))))

(defun parse-loop (form)
  "Parse a loop form: (loop [name init name init ...] body...).
   The first argument is a vector of alternating name/init pairs."
  (destructuring-bind (op bindings-vec &rest body) form
    (declare (ignore op))
    (let* ((binding-list (fol-vector-to-list bindings-vec))
           (parsed-bindings
            (loop for (name init) on binding-list by #'cddr
                  collect (cons name (parse-form init)))))
      (fol.compiler.ast:make-loop-node
        :bindings parsed-bindings
        :body (mapcar #'parse-form body)
        :form form))))

(defun parse-recur (form)
  "Parse a recur form: (recur expr1 expr2 ...).
   Returns a recur-node with the argument expressions."
  (destructuring-bind (op &rest args) form
    (declare (ignore op))
    (fol.compiler.ast:make-recur-node
      :args (mapcar #'parse-form args)
      :form form)))

;;; --- Condition handling parsers ---

(defun parse-handler-case (form)
  "Parse a handler-case form:
   (handler-case expr (type (var) body ...) ...).
   Each clause binds a condition variable and has a body."
  (destructuring-bind (op expr &rest clauses) form
    (declare (ignore op))
    (fol.compiler.ast:make-handler-case-node
      :expr (parse-form expr)
      :clauses (mapcar (lambda (clause)
                         (destructuring-bind (type var-list &rest body) clause
                           (let ((var (if (and (listp var-list) (car var-list))
                                          (car var-list)
                                          nil)))
                             (cons type (cons var (mapcar #'parse-form body))))))
                   clauses)
      :form form)))

(defun parse-handler-bind (form)
  "Parse a handler-bind form:
   (handler-bind ((type handler-fn) ...) body ...).
   Each binding pairs a condition type with a handler function."
  (destructuring-bind (op bindings &rest body) form
    (declare (ignore op))
    (fol.compiler.ast:make-handler-bind-node
      :bindings (mapcar (lambda (binding)
                          (destructuring-bind (type handler) binding
                            (cons type (parse-form handler))))
                    bindings)
      :body (mapcar #'parse-form body)
      :form form)))

(defun parse-restart-case (form)
  "Parse a restart-case form:
   (restart-case expr (restart-name (params ...) body ...) ...).
   Each clause names a restart with parameters and a body."
  (destructuring-bind (op expr &rest clauses) form
    (declare (ignore op))
    (fol.compiler.ast:make-restart-case-node
      :expr (parse-form expr)
      :clauses (mapcar (lambda (clause)
                         (destructuring-bind (name params &rest body) clause
                           (cons name (cons params (mapcar #'parse-form body)))))
                   clauses)
      :form form)))

(defun parse-signal (form)
  "Parse a signal form: (signal datum args ...).
   Signals a recoverable condition."
  (destructuring-bind (op datum &rest args) form
    (declare (ignore op))
    (fol.compiler.ast:make-signal-node
      :datum (parse-form datum)
      :args (mapcar #'parse-form args)
      :form form)))

(defun parse-error-form (form)
  "Parse an error form: (error datum args ...).
   Signals a non-recoverable error."
  (destructuring-bind (op datum &rest args) form
    (declare (ignore op))
    (fol.compiler.ast:make-error-node
      :datum (parse-form datum)
      :args (mapcar #'parse-form args)
      :form form)))

(defun parse-warn (form)
  "Parse a warn form: (warn datum args ...).
   Signals a warning condition."
  (destructuring-bind (op datum &rest args) form
    (declare (ignore op))
    (fol.compiler.ast:make-warn-node
      :datum (parse-form datum)
      :args (mapcar #'parse-form args)
      :form form)))

(defun parse-invoke-restart (form)
  "Parse an invoke-restart form: (invoke-restart name args ...).
   Invokes a named restart with optional arguments."
  (destructuring-bind (op name &rest args) form
    (declare (ignore op))
    (fol.compiler.ast:make-invoke-restart-node
      :name (parse-form name)
      :args (mapcar #'parse-form args)
      :form form)))

(defun parse-swap! (form)
  "Parse (swap! atom fn & args). Special handling for function references."
  (destructuring-bind (op atom-form fn-form &rest args) form
    (declare (ignore op))
    (fol.compiler.ast:make-swap-node
      :atom-expr (parse-form atom-form)
      :fn-expr (parse-form fn-form)
      :args (mapcar #'parse-form args)
      :form form)))

(defun parse-cond (form)
  "Parse (cond (test1 expr1 ...) (test2 expr2 ...) ...)."
  (destructuring-bind (op &rest clauses) form
    (declare (ignore op))
    (fol.compiler.ast:make-cond-node
      :clauses (mapcar (lambda (clause)
                         (cons (parse-form (car clause))
                               (mapcar #'parse-form (cdr clause))))
                   clauses)
      :form form)))

(defun parse-cond-thread-first (form)
  "Parse (cond-> expr (test form) ...)."
  (destructuring-bind (op expr &rest clauses) form
    (declare (ignore op))
    (fol.compiler.ast:make-cond-thread-first-node
      :expr (parse-form expr)
      :clauses (mapcar (lambda (clause)
                         (cons (parse-form (car clause))
                               (parse-form (second clause))))
                   clauses)
      :form form)))

(defun parse-cond-thread-last (form)
  "Parse (cond->> expr (test form) ...)."
  (destructuring-bind (op expr &rest clauses) form
    (declare (ignore op))
    (fol.compiler.ast:make-cond-thread-last-node
      :expr (parse-form expr)
      :clauses (mapcar (lambda (clause)
                         (cons (parse-form (car clause))
                               (parse-form (second clause))))
                   clauses)
      :form form)))

(defun parse-syntax-quote (form)
  "Parse (syntax-quote template). Handles nested unquote/unquote-splicing."
  (destructuring-bind (op template) form
    (declare (ignore op))
    (fol.compiler.ast:make-syntax-quote-node
      :template (parse-syntax-quote-template template)
      :form form)))

(defun parse-syntax-quote-template (template)
  "Recursively parse template, detecting unquote/unquote-splicing."
  (cond
   ((and (consp template) (eq (car template) 'unquote))
     (fol.compiler.ast:make-unquote-node
       :expr (parse-form (second template))
       :form template))
   ((and (consp template) (eq (car template) 'unquote-splicing))
     (fol.compiler.ast:make-unquote-splicing-node
       :expr (parse-form (second template))
       :form template))
   ((consp template)
     (cons (parse-syntax-quote-template (car template))
           (parse-syntax-quote-template (cdr template))))
   (t template)))

(defun parse-unquote (form)
  "Parse (unquote expr)."
  (destructuring-bind (op expr) form
    (declare (ignore op))
    (fol.compiler.ast:make-unquote-node :expr (parse-form expr) :form form)))

(defun parse-unquote-splicing (form)
  "Parse (unquote-splicing expr)."
  (destructuring-bind (op expr) form
    (declare (ignore op))
    (fol.compiler.ast:make-unquote-splicing-node :expr (parse-form expr) :form form)))

(defun parse-case (form)
  "Parse (case expr (val1 body1) ((val2 val3) body2) ...)."
  (destructuring-bind (op expr &rest clauses) form
    (declare (ignore op))
    (fol.compiler.ast:make-case-node
      :expr (parse-form expr)
      :clauses (mapcar (lambda (clause)
                         (let ((values (car clause))
                               (body (cdr clause)))
                           (cons (if (listp values) values (list values))
                                 (mapcar #'parse-form body))))
                   clauses)
      :form form)))

(defun parse-env (form)
  "Parse (env). No arguments."
  (fol.compiler.ast:make-env-node :form form))

(defun parse-in-package (form)
  "Parse (in-package name options... body...)."
  (destructuring-bind (op name &rest args) form
    (declare (ignore op))
    (let (options body)
      (dolist (arg args)
        (if (and (consp arg)
                 (or (keywordp (car arg))
                     (member (car arg) '(:use :export :shadow :import-from :nicknames :documentation :size) :test #'string-equal)))
            (push arg options)
            (push (parse-form arg) body)))
      (fol.compiler.ast:make-in-package-node
       :name name
       :options (nreverse options)
       :body (nreverse body)
       :form form))))

;;; --- Special form dispatch table ---

(let ((special-forms (make-hash-table :test 'equal)))
  (setf (gethash "IF" special-forms) #'parse-if)
  (setf (gethash "DO" special-forms) #'parse-do)
  (setf (gethash "BIND" special-forms) #'parse-bind)
  (setf (gethash "QUOTE" special-forms) #'parse-quote)
  (setf (gethash "FN" special-forms) #'parse-fn)
  (setf (gethash "Λ" special-forms) #'parse-fn) ; Λ/λ is an alias for fn
  ;; Threading macros now handled in macros.lisp
  ;; (setf (gethash "->" special-forms) #'parse-thread-first)
  ;; (setf (gethash "->>" special-forms) #'parse-thread-last)
  (setf (gethash "VECTOR" special-forms) #'parse-vector)
  (setf (gethash "DICT" special-forms) #'parse-dict)
  (setf (gethash "SET" special-forms) #'parse-set)
  (setf (gethash "DEFMACRO" special-forms) #'parse-defmacro)
  (setf (gethash "DEFCLASS" special-forms) #'parse-defclass)
  (setf (gethash "DEFGENERIC" special-forms) #'parse-defgeneric)
  (setf (gethash "DEFMETHOD" special-forms) #'parse-defmethod)
  (setf (gethash "DEF" special-forms) #'parse-def)
  (setf (gethash "DEFN" special-forms) #'parse-defn)
  (setf (gethash "LOOP" special-forms) #'parse-loop)
  (setf (gethash "RECUR" special-forms) #'parse-recur)
  (setf (gethash "HANDLER-CASE" special-forms) #'parse-handler-case)
  (setf (gethash "HANDLER-BIND" special-forms) #'parse-handler-bind)
  (setf (gethash "RESTART-CASE" special-forms) #'parse-restart-case)
  (setf (gethash "SIGNAL" special-forms) #'parse-signal)
  (setf (gethash "ERROR" special-forms) #'parse-error-form)
  (setf (gethash "WARN" special-forms) #'parse-warn)
  (setf (gethash "INVOKE-RESTART" special-forms) #'parse-invoke-restart)
  (setf (gethash "DEFDYNAMIC" special-forms) #'parse-defdynamic)
  (setf (gethash "BINDING" special-forms) #'parse-binding)
  ;; Now in mutable-functions: (setf (gethash "SWAP!" special-forms) #'parse-swap!)
  (setf (gethash "COND" special-forms) #'parse-cond)
  ;; Now a macro: (setf (gethash "COND->" special-forms) #'parse-cond-thread-first)
  ;; Now a macro: (setf (gethash "COND->>" special-forms) #'parse-cond-thread-last)
  (setf (gethash "SYNTAX-QUOTE" special-forms) #'parse-syntax-quote)
  (setf (gethash "UNQUOTE" special-forms) #'parse-unquote)
  (setf (gethash "UNQUOTE-SPLICING" special-forms) #'parse-unquote-splicing)
  (setf (gethash "CASE" special-forms) #'parse-case)
  (setf (gethash "ENV" special-forms) #'parse-env)
  (setf (gethash "IN-PACKAGE" special-forms) #'parse-in-package)
  ;; Functional special forms
  (setf (gethash "DEFN-" special-forms) #'parse-defn-private)
  (setf (gethash "DEFINLINE" special-forms) #'parse-definline)
  (setf (gethash "LETFN" special-forms) #'parse-letfn)
  ;; Now macros: (setf (gethash "SOME->" special-forms) #'parse-some-thread-first)
  ;; Now macros: (setf (gethash "SOME->>" special-forms) #'parse-some-thread-last)
  ;; Now a macro: (setf (gethash "AS->" special-forms) #'parse-as-thread)
  (defun special-form-p (op)
    "Check if OP is a special form operator.
     Compares by symbol name to work across packages."
    (and (symbolp op)
         (nth-value 1 (gethash (symbol-name op) special-forms))))

  (defun parse-special-form (form)
    "Parse a special form based on its operator."
    (let ((parser (gethash (symbol-name (car form)) special-forms)))
      (if parser
          (funcall parser form)
          (error "Unknown special form: ~S" (car form))))))

;;; ---------------------------------------------------------------------------
;;; Macro System
;;; ---------------------------------------------------------------------------

(let ((macros (make-hash-table :test 'equal)))
  (defun register-macro (name expander)
    "Register a macro with NAME and its EXPANDER function.
     The expander function takes a form and returns the expanded form.
     NAME can be a symbol or string; strings are used for cross-package compatibility."
    (let ((key (if (symbolp name) (symbol-name name) name)))
      (setf (gethash key macros) expander)))

  (defun unregister-macro (name)
    "Remove a macro registration."
    (let ((key (if (symbolp name) (symbol-name name) name)))
      (remhash key macros)))

  (defun macro-p (symbol)
    "Check if SYMBOL is a registered macro."
    (and (symbolp symbol)
         (nth-value 1 (gethash (symbol-name symbol) macros))))

  (defun get-macro-expander (symbol)
    "Get the expander function for a macro, or NIL if not a macro."
    (when (symbolp symbol)
          (gethash (symbol-name symbol) macros))))

(defun macroexpand-1 (form)
  "Expand FORM one level if it's a macro call. Returns two values:
   the expanded form and T if expansion occurred, or the original form and NIL."
  (if (and (consp form)
           (symbolp (car form))
           (macro-p (car form)))
      (let ((expander (get-macro-expander (car form))))
        (values (funcall expander form nil) t))
      (values form nil)))

(defun macroexpand (form)
  "Recursively expand FORM until it's no longer a macro call.
   Returns two values: the fully expanded form and T if any expansion occurred."
  (multiple-value-bind (expanded expanded-p) (macroexpand-1 form)
    (if expanded-p
        (multiple-value-bind (final any-expansion) (macroexpand expanded)
          (values final t))
        (values form nil))))

(defun macroexpand-all (form)
  "Recursively expand all macros in FORM, including nested subforms."
  (multiple-value-bind (expanded expanded-p) (macroexpand-1 form)
    (if expanded-p
        ;; After top-level expansion, recursively expand the result
        (macroexpand-all expanded)
        ;; Not a macro call, but recursively process subforms
        (typecase form
          (cons
            (cons (macroexpand-all (car form))
                  (macroexpand-all (cdr form))))
          (t form)))))

;;; ---------------------------------------------------------------------------
;;; Phase 2: Emit (AST -> Common Lisp forms)
;;; ---------------------------------------------------------------------------

;;; Lexical variable tracking for Lisp-2 funcall detection
(defvar *lexical-vars* nil
        "Set of lexically bound variable names. Used to detect when a function call
   needs funcall (Lisp-2 semantics). Bound dynamically during code emission.")

(defvar *letfn-fns* nil
        "Set of function names bound in an enclosing letfn (CL labels) form.
   Calls to these names are emitted as direct function calls since labels
   puts them in the function slot, not the value slot.")

(defun emit-literal (node)
  "Emit a literal value. Self-evaluating forms compile to themselves."
  (fol.compiler.ast:literal-node-value node))

(defun emit-symbol-ref (node)
  "Emit a symbol reference. Compiles to the CL symbol itself."
  (fol.compiler.ast:symbol-ref-node-name node))

(defun emit-call (node)
  "Emit a function call node.
   Special cases:
   - (:keyword dict) => (get dict :keyword)  ; keyword as accessor
   - (lexical-var ...) => runtime dispatch: funcall if function, get if collection
   - (symbol ...) => normal call with runtime collection fallback"
  (let ((operator (fol.compiler.ast:call-node-operator node))
        (args (fol.compiler.ast:call-node-args node)))
    (cond
     ;; Pattern: (:keyword dict) - keyword used as accessor function
     ;; This is unambiguous since keywords are never function names
     ((and (fol.compiler.ast:literal-node-p operator)
           (keywordp (fol.compiler.ast:literal-node-value operator))
           (= (length args) 1))
       (let ((keyword (fol.compiler.ast:literal-node-value operator))
             (dict-arg (emit-node (first args))))
         `(fol.compiler.collection-functions:get ,dict-arg ,keyword)))

     ;; Pattern: (letfn-fn ...) - function bound by an enclosing letfn (labels)
     ;; These are in the function slot, so emit a direct function call.
     ((and (fol.compiler.ast:symbol-ref-node-p operator)
           (member (fol.compiler.ast:symbol-ref-node-name operator) *letfn-fns*))
       `(,(fol.compiler.ast:symbol-ref-node-name operator) ,@(mapcar #'emit-node args)))

     ;; Pattern: (lexical-var ...) - variable holding a function or collection
     ;; Runtime dispatch: funcall if function, get/nth if dict/vector/set
     ((and (fol.compiler.ast:symbol-ref-node-p operator)
           (member (fol.compiler.ast:symbol-ref-node-name operator) *lexical-vars*))
       (let ((emitted-args (mapcar #'emit-node args))
             (gop (gensym "OP")))
         `(let ((,gop ,(emit-node operator)))
            (cond
             ((functionp ,gop) (funcall ,gop ,@emitted-args))
             ((typep ,gop 'fol.compiler.collections:<dict>)
               (fol.compiler.collection-functions:get ,gop ,@emitted-args))
             ((typep ,gop 'fol.compiler.collections:<vector>)
               (fol.compiler.collection-functions:nth ,gop ,@emitted-args))
             ((typep ,gop 'fol.compiler.collections:<set>)
               (fol.compiler.collection-functions:get ,gop ,@emitted-args))
             (t (error "Value ~S is not callable or a collection" ,gop))))))

     ;; Normal function call - operator is a lambda, nested call, or literal
     ;; Collection literals as operators -> use accessor
     ((fol.compiler.ast:set-node-p operator)
       `(fol.compiler.collection-functions:get ,(emit-node operator) ,@(mapcar #'emit-node args)))
     ((fol.compiler.ast:dict-node-p operator)
       `(fol.compiler.collection-functions:get ,(emit-node operator) ,@(mapcar #'emit-node args)))
     ((fol.compiler.ast:vector-node-p operator)
       `(fol.compiler.collection-functions:nth ,(emit-node operator) ,@(mapcar #'emit-node args)))

     ;; Function-like operators -> use funcall
     ((or (fol.compiler.ast:fn-node-p operator)
          (fol.compiler.ast:call-node-p operator)
          (fol.compiler.ast:literal-node-p operator))
       `(funcall ,(emit-node operator) ,@(mapcar #'emit-node args)))

     ;; Symbol-ref call with runtime collection fallback
     ;; If symbol is fboundp or a CL package symbol, emit direct call;
     ;; otherwise emit runtime check: try as function, then as dict/vector/set
     ((fol.compiler.ast:symbol-ref-node-p operator)
       (let ((sym (fol.compiler.ast:symbol-ref-node-name operator))
             (emitted-args (mapcar #'emit-node args)))
         (if (or (fboundp sym)
                 (eq (symbol-package sym) (find-package :cl)))
             `(,sym ,@emitted-args)
             (let ((gval (gensym "VAL")))
               `(if (fboundp ',sym)
                    (,sym ,@emitted-args)
                    (let ((,gval ,sym))
                      (cond
                       ((typep ,gval 'fol.compiler.collections:<dict>)
                         (fol.compiler.collection-functions:get ,gval ,@emitted-args))
                       ((typep ,gval 'fol.compiler.collections:<vector>)
                         (fol.compiler.collection-functions:nth ,gval ,@emitted-args))
                       ((typep ,gval 'fol.compiler.collections:<set>)
                         (fol.compiler.collection-functions:get ,gval ,@emitted-args))
                       (t (error "~S is not a function or collection" ',sym)))))))))

     ;; Invalid function call - operator is not callable
     (t
       (error "Illegal function call form: operator ~S is not callable"
         (fol.compiler.ast:ast-node-form operator))))))

(defun emit-if (node)
  "Emit an if node. Wraps the test in truthy? for FOL semantics.
   The else branch may be a list of nodes (implicit progn)."
  (let ((test (fol.compiler.ast:if-node-test node))
        (then (fol.compiler.ast:if-node-then node))
        (else (fol.compiler.ast:if-node-else node)))
    (if (and else (listp else) (> (length else) 1))
        `(if (fol.compiler.primitives:truthy? ,(emit-node test))
             ,(emit-node then)
             (progn ,@(mapcar #'emit-node else)))
        `(if (fol.compiler.primitives:truthy? ,(emit-node test))
             ,(emit-node then)
             ,(when else
                    (if (listp else)
                        (emit-node (first else))
                        (emit-node else)))))))

(defun emit-do (node)
  "Emit a do node as CL progn."
  (let ((body (fol.compiler.ast:do-node-body node)))
    `(progn ,@(mapcar #'emit-node body))))

(defun emit-bind (node)
  "Emit a bind node as CL let* with destructuring support.
   Simple patterns use let* binding.
   Vector patterns use destructuring with multiple-value capture:
     [#(a b) (values 1 2)] -> capture multiple values into a, b."
  (let ((bindings (fol.compiler.ast:bind-node-bindings node))
        (body (fol.compiler.ast:bind-node-body node)))
    ;; Pass body AST nodes, not emitted forms, so they're emitted with correct *lexical-vars*
    (emit-bind-chain bindings body)))

(defun emit-bind-chain (bindings body-nodes)
  "Emit nested let/destructuring forms for bind bindings.
   Each binding is sequential (visible to subsequent bindings).
   Tracks bound variables in *lexical-vars* for Lisp-2 funcall detection.
   Body-nodes are AST nodes that will be emitted after all bindings are processed."
  (if (null bindings)
      ;; Emit body with all bindings in scope
      (let ((body-forms (mapcar #'emit-node body-nodes)))
        (if (= (length body-forms) 1)
            (first body-forms)
            `(cl:progn ,@body-forms)))
      (destructuring-bind (pattern . init-node) (first bindings)
        (let ((init-code (emit-node init-node)))
          (if (fol-vector-p pattern)
              ;; Destructuring pattern - capture multiple values
              (let* ((mv-sym (gensym "MV"))
                     (val-sym (gensym "VAL"))
                     (param-bindings
                      (fol.compiler.destructure:emit-single-param-binding pattern val-sym))
                     ;; Extract all bound symbols from param-bindings
                     (bound-syms (mapcar #'car param-bindings))
                     ;; Add to *lexical-vars* for nested scope
                     (*lexical-vars* (append bound-syms *lexical-vars*))
                     (rest-code (emit-bind-chain (rest bindings) body-nodes)))
                `(cl:let* ((,mv-sym (cl:multiple-value-list ,init-code))
                           (,val-sym (if (cl:> (cl:length ,mv-sym) 1) ,mv-sym (cl:car ,mv-sym)))
                           ,@param-bindings)
                   ,rest-code))
              ;; Simple symbol binding
              (let* ((*lexical-vars* (cons pattern *lexical-vars*))
                     (rest-code (emit-bind-chain (rest bindings) body-nodes)))
                `(cl:let ((,pattern ,init-code))
                   ,rest-code)))))))

(defun emit-quote (node)
  "Emit a quote node."
  (let ((value (fol.compiler.ast:quote-node-value node)))
    `(cl:quote ,value)))

(defun compile-fn (clauses)
  "Compile fn clauses into a sorted, dispatched CL lambda form.
   Clauses are sorted by arity (ascending), then by pattern specificity
   (most specific first within the same arity).

   Single-clause fns with simple params emit a direct lambda.
   Multi-clause or specialized fns emit a dispatcher lambda with &rest args
   and a cond that tests arity and pattern matches inline."
  (let ((fol.compiler.destructure:*emit-predicate-hook*
         (lambda (fn-name extra-args arg-expr)
           (emit-node
             (parse-form
               (list* fn-name arg-expr extra-args))))))
    (if (= (length clauses) 1)
        (compile-fn-single-clause (first clauses))
        (compile-fn-multi-clause clauses))))

(defun compile-fn-single-clause (clause)
  "Compile a single fn clause into a CL lambda form.
   Handles &rest, :key, :or (defaults), :as (whole binding), and _ wildcards.
   Returns (lambda (params...) body...)."
  (destructuring-bind (param-vec . body-nodes) clause
    (let ((param-list (fol-vector-to-list param-vec)))
      (multiple-value-bind (regular-params rest-param key-params defaults as-param)
          (fol.compiler.destructure:parse-params param-list)
        (let* ((stripped (fol.compiler.destructure:strip-specializers regular-params))
               ;; Replace _ wildcards in regular params with gensyms
               (wildcard-result (multiple-value-list
                                  (fol.compiler.destructure:replace-wildcards stripped)))
               (clean-stripped (first wildcard-result))
               (wildcards-regular (second wildcard-result))
               ;; Handle _ in rest param
               (clean-rest (if (and rest-param
                                    (fol.compiler.destructure:wildcard-param-p rest-param))
                               (gensym "UNUSED")
                               rest-param))
               (all-wildcards (append wildcards-regular
                                (when (and rest-param
                                           (fol.compiler.destructure:wildcard-param-p rest-param))
                                      (list clean-rest))))
               (stripped-keys (when key-params
                                    (fol.compiler.destructure:strip-specializers key-params)))
               (key-with-defaults
                (when stripped-keys
                      (if (and defaults (fol-vector-p defaults))
                          ;; Pair key params with defaults from :or vector
                          (let ((default-list (fol-vector-to-list defaults)))
                            (loop for k in stripped-keys
                                  for i from 0
                                  for default = (if (< i (length default-list))
                                                    (nth i default-list)
                                                    nil)
                                  collect (if default
                                              (list k default)
                                              k)))
                          stripped-keys)))
               (lambda-list (append clean-stripped
                              (when clean-rest
                                    (list '&rest clean-rest))
                              (when key-with-defaults
                                    (cons '&key key-with-defaults))))
               ;; Track all params as lexical vars for Lisp-2 funcall detection
               (*lexical-vars* (append clean-stripped
                                 (when clean-rest (list clean-rest))
                                 (when stripped-keys stripped-keys)
                                 (when as-param (list as-param))
                                 *lexical-vars*))
               (emitted-body (mapcar #'emit-node body-nodes))
               (body-with-as (if as-param
                                 ;; Wrap body in let binding the whole arg list
                                 `((cl:let ((,as-param (cl:list ,@clean-stripped
                                                         ,@(when clean-rest
                                                                 (cl:list clean-rest)))))
                                     ,@emitted-body))
                                 emitted-body))
               (body-with-ignore
                (if all-wildcards
                    `((cl:declare (cl:ignorable ,@all-wildcards)) ,@body-with-as)
                    body-with-as)))
          `(cl:lambda ,lambda-list ,@body-with-ignore))))))

(defun compile-fn-multi-clause (clauses)
  "Compile multiple fn clauses into a dispatcher lambda.
   Sorts clauses by arity then specificity and emits a cond form.
   When all clauses share the same arity and none have rest params,
   emits a fixed-arity lambda to avoid &rest consing overhead."
  (let* (;; Analyze each clause
         (analyzed
          (loop for clause in clauses
                for (param-vec . body-nodes) = clause
                for param-list = (fol-vector-to-list param-vec)
                for (regular-params rest-param) = (multiple-value-list
                                                    (fol.compiler.destructure:parse-params param-list))
                for arity = (length regular-params)
                for has-rest = (not (null rest-param))
                for signature = (fol.compiler.destructure:compute-pattern-signature regular-params)
                for stripped = (fol.compiler.destructure:strip-specializers regular-params)
                collect (list :arity arity
                              :has-rest has-rest
                              :signature signature
                              :stripped stripped
                              :rest-param rest-param
                              :body-nodes body-nodes)))
         ;; Sort: arity ascending, then specificity descending
         (sorted
          (stable-sort (copy-list analyzed)
              (lambda (c1 c2)
                (let ((a1 (getf c1 :arity))
                      (a2 (getf c2 :arity)))
                  (cond
                   ((< a1 a2) t)
                   ((> a1 a2) nil)
                   (t (fol.compiler.destructure:pattern-more-specific-p
                        (getf c1 :signature)
                        (getf c2 :signature))))))))
         ;; Detect uniform-arity: all same arity, no rest params
         (arities (mapcar (lambda (c) (getf c :arity)) analyzed))
         (has-any-rest (some (lambda (c) (getf c :has-rest)) analyzed))
         (uniform-arity (and (not has-any-rest)
                             (apply #'= arities)
                             (first arities))))
    (if uniform-arity
        (compile-fn-fixed-arity sorted uniform-arity)
        (compile-fn-rest-args sorted))))

(defun compile-fn-fixed-arity (sorted-clauses arity)
  "Emit a fixed-arity lambda for uniform-arity multi-clause fn.
   Uses direct parameter symbols instead of &rest + nth."
  (let* ((param-syms (loop for i below arity
                           collect (intern (format nil "A~D" i))))
         ;; Track param-syms as lexical vars for all clauses
         (*lexical-vars* (append param-syms *lexical-vars*))
         (cond-clauses
          (loop for c in sorted-clauses
                for signature = (getf c :signature)
                for stripped = (getf c :stripped)
                for body-nodes = (getf c :body-nodes)
                for check = (fol.compiler.destructure:emit-fixed-arity-pattern-check
                              signature param-syms)
                for bindings = (fol.compiler.destructure:emit-fixed-arity-param-bindings
                                 stripped param-syms)
                  ;; Track bound vars from destructuring
                for bound-vars = (mapcar #'car bindings)
                for *lexical-vars* = (append bound-vars *lexical-vars*)
                for emitted-body = (mapcar #'emit-node body-nodes)
                collect `(,check
                           (cl:let ,bindings
                             ,@emitted-body)))))
    `(cl:lambda ,param-syms
       (cl:cond
         ,@cond-clauses
         (cl:t (cl:error "No matching fn clause for arguments: ~S"
                 (cl:list ,@param-syms)))))))

(defun compile-fn-rest-args (sorted-clauses)
  "Emit a &rest lambda for mixed-arity multi-clause fn."
  (let* ((args-sym (intern "ARGS"))
         ;; Track args-sym as lexical var
         (*lexical-vars* (cons args-sym *lexical-vars*))
         (cond-clauses
          (loop for c in sorted-clauses
                for arity = (getf c :arity)
                for has-rest = (getf c :has-rest)
                for signature = (getf c :signature)
                for stripped = (getf c :stripped)
                for rest-param = (getf c :rest-param)
                for body-nodes = (getf c :body-nodes)
                for check = (fol.compiler.destructure:emit-clause-pattern-check
                              signature arity has-rest args-sym)
                for bindings = (append
                                 (fol.compiler.destructure:emit-param-bindings
                                   stripped args-sym)
                                 (fol.compiler.destructure:emit-rest-param-binding
                                   rest-param arity args-sym))
                  ;; Track bound vars from destructuring
                for bound-vars = (mapcar #'car bindings)
                for *lexical-vars* = (append bound-vars *lexical-vars*)
                for emitted-body = (mapcar #'emit-node body-nodes)
                collect `(,check
                           (cl:let ,bindings
                             ,@emitted-body)))))
    `(cl:lambda (&rest ,args-sym)
       (cl:cond
         ,@cond-clauses
         (cl:t (cl:error "No matching fn clause for ~D arguments: ~S"
                 (cl:length ,args-sym) ,args-sym))))))

(defun emit-fn (node)
  "Emit a fn node as CL lambda.
   For named fns, wraps in labels for self-recursion."
  (let* ((name (fol.compiler.ast:fn-node-name node))
         (clauses (fol.compiler.ast:fn-node-clauses node))
         (lambda-form (compile-fn clauses)))
    (if name
        ;; Named fn: wrap in labels for self-reference
        (let ((params (second lambda-form))
              (body (cddr lambda-form)))
          `(cl:labels ((,name ,params ,@body))
             #',name))
        lambda-form)))

(defun emit-thread-first (node)
  "Emit a thread-first node by expanding into nested function calls.
   (-> x f)           => (f x)
   (-> x (f a))       => (f x a)
   (-> x (f a) (g b)) => (g (f x a) b)
   Each form threads the accumulated value as the first argument."
  (let* ((forms (fol.compiler.ast:thread-first-node-forms node))
         (initial (emit-node (first forms)))
         (threading-forms (rest forms)))
    (if (null threading-forms)
        initial
        (reduce (lambda (acc form-node)
                  (let ((emitted (emit-node form-node)))
                    (cond
                     ;; Bare symbol: call it with accumulated value
                     ((symbolp emitted)
                       `(,emitted ,acc))
                     ;; List form (f args...): insert accumulated as first arg
                     ((listp emitted)
                       `(,(first emitted) ,acc ,@(rest emitted)))
                     ;; Anything else: treat as function call
                     (t `(funcall ,emitted ,acc)))))
            threading-forms
          :initial-value initial))))

(defun emit-thread-last (node)
  "Emit a thread-last node by expanding into nested function calls.
   (->> x f)           => (f x)
   (->> x (f a))       => (f a x)
   (->> x (f a) (g b)) => (g b (f a x))
   Each form threads the accumulated value as the last argument."
  (let* ((forms (fol.compiler.ast:thread-last-node-forms node))
         (initial (emit-node (first forms)))
         (threading-forms (rest forms)))
    (if (null threading-forms)
        initial
        (reduce (lambda (acc form-node)
                  (let ((emitted (emit-node form-node)))
                    (cond
                     ;; Bare symbol: call it with accumulated value
                     ((symbolp emitted)
                       `(,emitted ,acc))
                     ;; List form (f args...): append accumulated as last arg
                     ((listp emitted)
                       `(,(first emitted) ,@(rest emitted) ,acc))
                     ;; Anything else: treat as function call
                     (t `(funcall ,emitted ,acc)))))
            threading-forms
          :initial-value initial))))

(defun emit-some-thread-first (node)
  "Emit nil-safe thread-first: (some-> x f1 f2 ...)
   Threads value as first arg, short-circuiting on nil.
   Expands to nested (let ((g expr)) (when g (let ((g (f g))) ...)))."
  (let* ((forms (fol.compiler.ast:some-thread-first-node-forms node))
         (initial (emit-node (first forms)))
         (threading-forms (rest forms)))
    (if (null threading-forms)
        initial
        (let ((g (gensym "G")))
          (reduce (lambda (inner form-node)
                    (let ((emitted (emit-node form-node)))
                      (let ((call (cond
                                   ((symbolp emitted)
                                     `(,emitted ,g))
                                   ((listp emitted)
                                     `(,(first emitted) ,g ,@(rest emitted)))
                                   (t `(funcall ,emitted ,g)))))
                        `(let ((,g ,inner))
                           (when ,g ,call)))))
              threading-forms
            :initial-value initial
            :from-end nil)))))

(defun emit-some-thread-last (node)
  "Emit nil-safe thread-last: (some->> x f1 f2 ...)
   Threads value as last arg, short-circuiting on nil.
   Expands to nested (let ((g expr)) (when g (let ((g (f ... g))) ...)))."
  (let* ((forms (fol.compiler.ast:some-thread-last-node-forms node))
         (initial (emit-node (first forms)))
         (threading-forms (rest forms)))
    (if (null threading-forms)
        initial
        (let ((g (gensym "G")))
          (reduce (lambda (inner form-node)
                    (let ((emitted (emit-node form-node)))
                      (let ((call (cond
                                   ((symbolp emitted)
                                     `(,emitted ,g))
                                   ((listp emitted)
                                     `(,(first emitted) ,@(rest emitted) ,g))
                                   (t `(funcall ,emitted ,g)))))
                        `(let ((,g ,inner))
                           (when ,g ,call)))))
              threading-forms
            :initial-value initial
            :from-end nil)))))

(defun emit-as-thread (node)
  "Emit named threading: (as-> expr name form1 form2 ...)
   Binds expr to name, then rebinds name to each form's result.
   Expands to nested let bindings."
  (let* ((expr (emit-node (fol.compiler.ast:as-thread-node-expr node)))
         (name (fol.compiler.ast:as-thread-node-name node))
         (forms (fol.compiler.ast:as-thread-node-forms node))
         (*lexical-vars* (cons name *lexical-vars*)))
    (if (null forms)
        expr
        (reduce (lambda (inner form-node)
                  `(let ((,name ,inner))
                     ,(emit-node form-node)))
            forms
          :initial-value expr
          :from-end nil))))

(defun emit-defn-private (node)
  "Emit a defn- node as (defun name ...).
   Same as defn; privacy is by convention only."
  (let* ((name (fol.compiler.ast:defn-private-node-name node))
         (clauses (fol.compiler.ast:defn-private-node-clauses node))
         (lambda-form (compile-fn clauses)))
    (let ((params (second lambda-form))
          (body (cddr lambda-form)))
      `(cl:defun ,name ,params ,@body))))

(defun emit-definline (node)
  "Emit a definline node as (progn (declaim (inline name)) (defun name ...)).
   Declares the function inline before defining it."
  (let* ((name (fol.compiler.ast:definline-node-name node))
         (clauses (fol.compiler.ast:definline-node-clauses node))
         (lambda-form (compile-fn clauses)))
    (let ((params (second lambda-form))
          (body (cddr lambda-form)))
      `(cl:progn
         (cl:declaim (inline ,name))
         (cl:defun ,name ,params ,@body)))))

(defun emit-vector (node)
  "Emit a vector-node as a call to vector.
   Creates a FOL <vector>."
  (let ((elements (fol.compiler.ast:vector-node-elements node)))
    `(fol.compiler.collection-functions:vector ,@(mapcar #'emit-node elements))))

(defun emit-dict (node)
  "Emit a dict-node as a call to dict.
   Creates a FOL <dict>."
  (let ((entries (fol.compiler.ast:dict-node-entries node)))
    `(fol.compiler.collection-functions:dict
       ,@(loop for (k . v) in entries
                 append (list (emit-node k) (emit-node v))))))

(defun emit-set (node)
  "Emit a set-node as a call to set.
   Creates a FOL <set>."
  (let ((elements (fol.compiler.ast:set-node-elements node)))
    `(fol.compiler.collection-functions:set ,@(mapcar #'emit-node elements))))

(defun emit-defmacro (node)
  "Emit a defmacro node as CL defmacro with destructured parameter list.
   Uses emit-macro-lambda-list for FOL-to-CL lambda list conversion."
  (let* ((name (fol.compiler.ast:defmacro-node-name node))
         (params (fol.compiler.ast:defmacro-node-params node))
         (body (fol.compiler.ast:defmacro-node-body node))
         (param-list (fol-vector-to-list params))
         (cl-lambda-list (fol.compiler.destructure:emit-macro-lambda-list param-list))
         (emitted-body (mapcar #'emit-node body)))
    `(cl:defmacro ,name ,cl-lambda-list ,@emitted-body)))

(defun emit-defclass (node)
  "Emit a defclass node as CL defclass with persistent object support.
   All FOL classes inherit from <persistent-object> and use the persistent-class metaclass.
   Also emits a make-<name> convenience constructor."
  (let* ((name (fol.compiler.ast:defclass-node-name node))
         (supers (fol.compiler.ast:defclass-node-superclasses node))
         (slots (fol.compiler.ast:defclass-node-slots node))
         ;; Ensure <persistent-object> is in superclass list
         (has-persistent (some (lambda (s)
                                 (string= (symbol-name s) "<PERSISTENT-OBJECT>"))
                             supers))
         (effective-supers
          (if (or (null supers)
                  (equal supers '(nil)))
              '(fol.compiler.persistent:<persistent-object>)
              (if has-persistent
                  (mapcar (lambda (s)
                            (if (string= (symbol-name s) "<PERSISTENT-OBJECT>")
                                'fol.compiler.persistent:<persistent-object>
                                s))
                      supers)
                  (append supers '(fol.compiler.persistent:<persistent-object>)))))
         ;; Build constructor name: make-<classname>
         (constructor-name (intern (format nil "MAKE-~A" name)
                                   (symbol-package name)))
         ;; Extract slot info for the constructor and accessors
         (slot-infos
          (loop for slot in slots
                for slot-spec = (if (listp slot) slot (list slot))
                for slot-name = (first slot-spec)
                for initarg = (or (getf (rest slot-spec) :initarg)
                                  (intern (string slot-name) :keyword))
                for accessor = (getf (rest slot-spec) :accessor)
                  ;; Storage key is always the keyword version of the slot name
                for storage-key = (intern (string slot-name) :keyword)
                collect (list slot-name initarg accessor storage-key)))
         ;; Strip :accessor from slot specs for defclass (we generate our own)
         (clean-slots
          (loop for slot in slots
                for slot-spec = (if (listp slot) slot (list slot))
                for accessor = (getf (rest slot-spec) :accessor)
                collect (if accessor
                            ;; Remove :accessor pair from slot spec
                            (let ((result (copy-list slot-spec)))
                              (remf (cdr result) :accessor)
                              result)
                            slot-spec))))
    `(cl:progn
       (cl:defclass ,name ,effective-supers
         ,clean-slots
         (:metaclass fol.compiler.persistent:persistent-class))
       ;; Direct accessor functions (bypass MOP for fast reads)
       ,@(loop for (sname initarg accessor storage-key) in slot-infos
                 when accessor
               collect `(cl:defun ,accessor (object)
                          (sycamore:hash-map-find
                            (fol.compiler.persistent::%persistent-storage object)
                            ,storage-key)))
       ;; Constructor
       (cl:defun ,constructor-name (&key ,@(mapcar #'first slot-infos))
         (cl:make-instance ',name
           ,@(loop for (sname kw) in slot-infos
                     append (list kw sname))))
       ',name)))

(defun emit-defgeneric (node)
  "Emit a defgeneric node as CL defgeneric.
   Single-pattern: (defgeneric name (params) options...)
   Multi-pattern: creates internal generics + dispatcher function."
  (let ((name (fol.compiler.ast:defgeneric-node-name node))
        (lambda-lists (fol.compiler.ast:defgeneric-node-lambda-lists node))
        (options (fol.compiler.ast:defgeneric-node-options node)))
    (if (= (length lambda-lists) 1)
        ;; Single pattern
        (let ((params (fol.compiler.destructure:strip-specializers (first lambda-lists))))
          `(cl:defgeneric ,name ,params ,@options))
        ;; Multi-pattern: create internal generics + dispatcher
        (emit-defgeneric-multi-pattern name lambda-lists options))))

(defun emit-defgeneric-multi-pattern (name lambda-lists options)
  "Emit CL code for a multi-pattern defgeneric.
   Creates internal generic functions for each pattern and a dispatcher
   that routes by arity and pattern matching."
  (let* ((patterns
          (loop for ll in lambda-lists
                for idx from 0
                for arity = (length ll)
                for signature = (fol.compiler.destructure:compute-pattern-signature ll)
                for internal-name = (intern (format nil "~A/P~A" name idx)
                                            (symbol-package name))
                collect (list :index idx
                              :arity arity
                              :lambda-list ll
                              :signature signature
                              :internal-name internal-name)))
         ;; Sort: arity ascending, then specificity descending
         (sorted-patterns
          (stable-sort (copy-list patterns)
              (lambda (p1 p2)
                (let ((a1 (getf p1 :arity))
                      (a2 (getf p2 :arity)))
                  (cond
                   ((< a1 a2) t)
                   ((> a1 a2) nil)
                   (t (fol.compiler.destructure:pattern-more-specific-p
                        (getf p1 :signature)
                        (getf p2 :signature))))))))
         ;; Generate simple lambda lists for each internal generic
         (generic-defs
          (loop for p in patterns
                for internal-name = (getf p :internal-name)
                for arity = (getf p :arity)
                for simple-ll = (loop for i below arity
                                      collect (intern (format nil "ARG~A" i)))
                collect `(cl:defgeneric ,internal-name ,simple-ll ,@options)))
         ;; Group patterns by arity
         (patterns-by-arity
          (let ((ht (make-hash-table)))
            (dolist (p sorted-patterns)
              (push p (gethash (getf p :arity) ht)))
            (loop for arity being the hash-keys of ht
                  using (hash-value ps)
                  collect (cons arity (nreverse ps)))))
         ;; Generate dispatcher cases
         (dispatcher-cases
          (loop for (arity . arity-patterns) in
                  (sort (copy-list patterns-by-arity) #'< :key #'car)
                collect
                  (if (= (length arity-patterns) 1)
                      (let ((p (first arity-patterns)))
                        `(,arity (apply #',(getf p :internal-name) args)))
                      (let ((cond-clauses
                             (loop for p in arity-patterns
                                   for sig = (getf p :signature)
                                   for args-sym = 'args
                                   for check = (fol.compiler.destructure:emit-clause-pattern-check
                                                 sig arity nil args-sym)
                                   collect `(,check
                                              (apply #',(getf p :internal-name) args)))))
                        `(,arity (cond
                                  ,@cond-clauses
                                  (t (error "No matching pattern for ~A with args ~S"
                                       ',name args)))))))))
    `(cl:progn
       ,@generic-defs
       (cl:defun ,name (&rest args)
         (cl:case (length args)
           ,@dispatcher-cases
           (t (error "No matching arity ~A for ~A"
                (length args) ',name))))
       ',name)))

(defun compile-defmethod-clauses (name clauses)
  "Compile defmethod clauses into a dispatched defun.
   Uses the same arity+specificity ordering as compile-fn-multi-clause.
   When all clauses share the same arity and none have rest params,
   emits a fixed-arity defun to avoid &rest consing overhead.
   Uses consistent parameter names across clauses when possible to avoid
   unnecessary gensyms and LET bindings (Bug #4 fix)."
  (let* ((analyzed
          (loop for clause in clauses
                for (param-vec . body-nodes) = clause
                for param-list = (fol-vector-to-list param-vec)
                for (regular-params rest-param) = (multiple-value-list
                                                    (fol.compiler.destructure:parse-params param-list))
                for arity = (length regular-params)
                for has-rest = (not (null rest-param))
                for signature = (fol.compiler.destructure:compute-pattern-signature regular-params)
                for stripped = (fol.compiler.destructure:strip-specializers regular-params)
                collect (list :arity arity
                              :has-rest has-rest
                              :signature signature
                              :stripped stripped
                              :rest-param rest-param
                              :body-nodes body-nodes)))
         (sorted
          (stable-sort (copy-list analyzed)
              (lambda (c1 c2)
                (let ((a1 (getf c1 :arity))
                      (a2 (getf c2 :arity)))
                  (cond
                   ((< a1 a2) t)
                   ((> a1 a2) nil)
                   (t (fol.compiler.destructure:pattern-more-specific-p
                        (getf c1 :signature)
                        (getf c2 :signature))))))))
         ;; Detect uniform-arity: all same arity, no rest params
         (arities (mapcar (lambda (c) (getf c :arity)) analyzed))
         (has-any-rest (some (lambda (c) (getf c :has-rest)) analyzed))
         (uniform-arity (and (not has-any-rest)
                             (apply #'= arities)
                             (first arities))))
    (if uniform-arity
        ;; Fixed-arity path with smart parameter naming (Bug #4 fix)
        (let* (;; For each parameter position, check if all clauses use same name
               (all-stripped (mapcar (lambda (c) (getf c :stripped)) sorted))
               (param-syms
                (loop for i below uniform-arity
                      for names-at-pos = (mapcar (lambda (stripped) (nth i stripped))
                                             all-stripped)
                        ;; Check if all are simple symbols and all equal
                      for all-simple = (every #'symbolp names-at-pos)
                      for all-same = (and all-simple
                                          (every (lambda (n) (eq n (first names-at-pos)))
                                              names-at-pos))
                      collect (if all-same
                                  (first names-at-pos) ; Use the shared name
                                  (intern (format nil "A~D" i))))) ; Use intern
               (cond-clauses
                (loop for c in sorted
                      for signature = (getf c :signature)
                      for stripped = (getf c :stripped)
                      for body-nodes = (getf c :body-nodes)
                      for check = (fol.compiler.destructure:emit-fixed-arity-pattern-check
                                    signature param-syms)
                        ;; Only emit bindings for params that differ from function params
                      for bindings = (loop for param in stripped
                                           for sym in param-syms
                                             ;; Only bind if param name differs from function param
                                             when (not (eq param sym))
                                             append (fol.compiler.destructure:emit-single-param-binding
                                                      param sym))
                      for emitted-body = (mapcar #'emit-node body-nodes)
                      collect `(,check
                                 ,@(if bindings
                                       `((let ,bindings ,@emitted-body))
                                       emitted-body)))))
          `(cl:defun ,name ,param-syms
             (cl:cond
               ,@cond-clauses
               (t (error "No matching method clause for ~A with arguments: ~S"
                    ',name (list ,@param-syms))))))
        ;; &rest path for mixed arities
        (let* ((args-sym (gensym "ARGS"))
               (cond-clauses
                (loop for c in sorted
                      for arity = (getf c :arity)
                      for has-rest = (getf c :has-rest)
                      for signature = (getf c :signature)
                      for stripped = (getf c :stripped)
                      for rest-param = (getf c :rest-param)
                      for body-nodes = (getf c :body-nodes)
                      for check = (fol.compiler.destructure:emit-clause-pattern-check
                                    signature arity has-rest args-sym)
                      for bindings = (append
                                       (fol.compiler.destructure:emit-param-bindings
                                         stripped args-sym)
                                       (fol.compiler.destructure:emit-rest-param-binding
                                         rest-param arity args-sym))
                      for emitted-body = (mapcar #'emit-node body-nodes)
                      collect `(,check
                                 (let ,bindings
                                   ,@emitted-body)))))
          `(defun ,name (&rest ,args-sym)
             (cond
              ,@cond-clauses
              (t (error "No matching method clause for ~A with ~D arguments: ~S"
                   ',name (length ,args-sym) ,args-sym))))))))

(defun emit-defmethod (node)
  "Emit a defmethod node as CL code.
   Single-clause with type specializers: CL defmethod.
   Multi-clause or predicate dispatch: defun with cond dispatcher."
  (let ((name (fol.compiler.ast:defmethod-node-name node))
        (clauses (fol.compiler.ast:defmethod-node-clauses node)))
    (if (= (length clauses) 1)
        ;; Single clause - check if it has specializers
        (let* ((clause (first clauses))
               (param-vec (car clause))
               (body-nodes (cdr clause))
               (param-list (fol-vector-to-list param-vec))
               (has-specializers (some (lambda (p) (listp p)) param-list)))
          (if has-specializers
              ;; Has type/pred specializers - emit dispatched defun
              (compile-defmethod-clauses name clauses)
              ;; Simple params - emit CL defmethod
              (multiple-value-bind (regular-params rest-param)
                  (fol.compiler.destructure:parse-params param-list)
                (let* ((lambda-list (if rest-param
                                        (append regular-params (list '&rest rest-param))
                                        regular-params))
                       (emitted-body (mapcar #'emit-node body-nodes)))
                  `(defmethod ,name ,lambda-list
                     ,@emitted-body)))))
        ;; Multi-clause: emit dispatched defun
        (compile-defmethod-clauses name clauses))))

(defun emit-def (node)
  "Emit a def node as CL defvar."
  (let ((name (fol.compiler.ast:def-node-name node))
        (value (fol.compiler.ast:def-node-value node)))
    (if value
        `(defvar ,name ,(emit-node value))
        `(defvar ,name))))

(defun emit-defdynamic (node)
  "Emit a defdynamic node as CL defvar.
   Identical output to emit-def — defdynamic is an explicit-intent alias."
  (let ((name (fol.compiler.ast:defdynamic-node-name node))
        (value (fol.compiler.ast:defdynamic-node-value node)))
    (if value
        `(defvar ,name ,(emit-node value))
        `(defvar ,name))))

(defun emit-binding (node)
  "Emit a binding node as CL let with dynamic rebinding.
   Uses let (not let*) so bindings are parallel — matches Clojure binding semantics.
   CL's let on special/dynamic variables does dynamic binding."
  (let* ((bindings (fol.compiler.ast:binding-node-bindings node))
         (body (fol.compiler.ast:binding-node-body node))
         ;; Track bound vars for funcall detection (even though they're dynamic)
         (*lexical-vars* (append (mapcar #'car bindings) *lexical-vars*)))
    `(let ,(loop for (name . init-node) in bindings
                 collect `(,name ,(emit-node init-node)))
       ,@(mapcar #'emit-node body))))

(defun emit-swap! (node)
  "Emit a swap! node. Adds #' if fn-expr is a bare symbol reference."
  (let ((atom-expr (emit-node (fol.compiler.ast:swap-node-atom-expr node)))
        (fn-expr-node (fol.compiler.ast:swap-node-fn-expr node))
        (args (mapcar #'emit-node (fol.compiler.ast:swap-node-args node))))
    ;; Check if fn-expr is a symbol-ref-node (bare symbol)
    (let ((fn-expr (if (fol.compiler.ast:symbol-ref-node-p fn-expr-node)
                       ;; It's a bare symbol - emit as function reference
                       `(function ,(fol.compiler.ast:symbol-ref-node-name fn-expr-node))
                       ;; It's an expression - emit as-is
                       (emit-node fn-expr-node))))
      `(fol.compiler.mutable:swap! ,atom-expr ,fn-expr ,@args))))

(defun emit-defn (node)
  "Emit a defn node as (defun name ...).
   Puts the function in the function slot, not the value slot.
   For single-clause: (defun name (params) body...)
   For multi-clause: (defun name (&rest args) (cond ...))"
  (let* ((name (fol.compiler.ast:defn-node-name node))
         (clauses (fol.compiler.ast:defn-node-clauses node))
         (lambda-form (compile-fn clauses)))
    ;; lambda-form is (lambda params body...)
    ;; Extract params and body to create defun
    (let ((params (second lambda-form))
          (body (cddr lambda-form)))
      `(cl:defun ,name ,params ,@body))))

(defun emit-letfn (node)
  "Emit a letfn node as CL labels.
   Each binding is (name . clauses) where clauses match compile-fn's input format.
   Single-arity and multi-arity fn-specs are both supported via compile-fn.
   Names are tracked in *letfn-fns* so call sites emit direct function calls
   rather than value-slot dispatch (which would fail for labels bindings)."
  (let* ((bindings (fol.compiler.ast:letfn-node-bindings node))
         (body (fol.compiler.ast:letfn-node-body node))
         (fn-names (mapcar #'car bindings))
         (*letfn-fns* (append fn-names *letfn-fns*)))
    `(cl:labels ,(mapcar (lambda (binding)
                           (destructuring-bind (name . clauses) binding
                             (let ((lambda-form (compile-fn clauses)))
                               `(,name ,(second lambda-form) ,@(cl:cddr lambda-form)))))
                     bindings)
       ,@(cl:mapcar #'emit-node body))))

;;; ---------------------------------------------------------------------------
;;; Loop/Recur Emission
;;; ---------------------------------------------------------------------------

(defvar *current-loop-context* nil
        "List of (block-name tag binding-names) for the innermost loop, or nil.")

(defvar *loop-counter* 0
        "Counter for generating unique loop block/tag names.")

(defun emit-loop (node)
  "Emit a loop node using block/tagbody/go for optimized iteration.
   The block provides the exit mechanism (return-from).
   tagbody/go provides the loop mechanism.
   recur updates bindings with psetq then jumps back.
   NOTE: Uses interned symbols (not gensyms) so code can be serialized to files."
  (let* ((bindings (fol.compiler.ast:loop-node-bindings node))
         (body (fol.compiler.ast:loop-node-body node))
         (loop-id (incf *loop-counter*))
         (block-name (intern (format nil "LOOP-BLOCK-~D" loop-id)))
         (tag (intern (format nil "LOOP-~D" loop-id)))
         (result-sym (intern (format nil "RESULT-~D" loop-id)))
         (binding-names (mapcar #'car bindings))
         (*current-loop-context* (list block-name tag binding-names))
         ;; Track loop bindings as lexical vars
         (*lexical-vars* (append binding-names (list result-sym) *lexical-vars*)))
    `(cl:block ,block-name
       (cl:let ,(loop for (name . init-node) in bindings
                      collect `(,name ,(emit-node init-node)))
         (cl:tagbody
           ,tag
           (cl:let ((,result-sym (cl:progn ,@(mapcar #'emit-node body))))
             (cl:return-from ,block-name ,result-sym)))))))

(defun emit-recur (node)
  "Emit a recur node as psetq + go.
   Uses psetq to update all loop bindings simultaneously (Clojure semantics),
   then jumps back to the loop tag."
  (unless *current-loop-context*
    (error "recur outside of loop"))
  (destructuring-bind (block-name tag binding-names) *current-loop-context*
    (declare (ignore block-name))
    (let* ((args (fol.compiler.ast:recur-node-args node))
           (emitted-args (mapcar #'emit-node args)))
      (unless (= (length args) (length binding-names))
        (error "recur arity mismatch: expected ~D args, got ~D"
          (length binding-names) (length args)))
      `(cl:progn
         (cl:psetq ,@(mapcan #'list binding-names emitted-args))
         (cl:go ,tag)))))

;;; --- Condition handling emitters ---

(defun emit-handler-case (node)
  "Emit a handler-case node as CL handler-case.
   (handler-case expr (type (var) body ...) ...)"
  (let ((expr (emit-node (fol.compiler.ast:handler-case-node-expr node)))
        (clauses (fol.compiler.ast:handler-case-node-clauses node)))
    `(handler-case ,expr
       ,@(mapcar (lambda (clause)
                   (let ((type (first clause))
                         (var (second clause))
                         (body-nodes (cddr clause)))
                     (if var
                         ;; Track var as lexical for handler body
                         (let ((*lexical-vars* (cons var *lexical-vars*)))
                           `(,type (,var) ,@(mapcar #'emit-node body-nodes)))
                         `(,type () ,@(mapcar #'emit-node body-nodes)))))
             clauses))))

(defun emit-handler-bind (node)
  "Emit a handler-bind node as CL handler-bind.
   (handler-bind ((type handler-fn) ...) body ...)"
  (let ((bindings (fol.compiler.ast:handler-bind-node-bindings node))
        (body (fol.compiler.ast:handler-bind-node-body node)))
    `(handler-bind ,(mapcar (lambda (binding)
                              (list (car binding) (emit-node (cdr binding))))
                        bindings)
       ,@(mapcar #'emit-node body))))

(defun emit-restart-case (node)
  "Emit a restart-case node as CL restart-case.
   (restart-case expr (name (params) body ...) ...)"
  (let ((expr (emit-node (fol.compiler.ast:restart-case-node-expr node)))
        (clauses (fol.compiler.ast:restart-case-node-clauses node)))
    `(restart-case ,expr
       ,@(mapcar (lambda (clause)
                   (let* ((name (first clause))
                          (params (second clause))
                          (body-nodes (cddr clause))
                          ;; Track params as lexical vars for restart body
                          (*lexical-vars* (append (if (listp params) params (list params))
                                            *lexical-vars*)))
                     `(,name ,params ,@(mapcar #'emit-node body-nodes))))
             clauses))))

(defun emit-signal (node)
  "Emit a signal node as CL signal."
  (let ((datum (emit-node (fol.compiler.ast:signal-node-datum node)))
        (args (mapcar #'emit-node (fol.compiler.ast:signal-node-args node))))
    `(signal ,datum ,@args)))

(defun emit-error (node)
  "Emit an error node as CL cl:error."
  (let ((datum (emit-node (fol.compiler.ast:error-node-datum node)))
        (args (mapcar #'emit-node (fol.compiler.ast:error-node-args node))))
    `(cl:error ,datum ,@args)))

(defun emit-warn (node)
  "Emit a warn node as CL cl:warn."
  (let ((datum (emit-node (fol.compiler.ast:warn-node-datum node)))
        (args (mapcar #'emit-node (fol.compiler.ast:warn-node-args node))))
    `(cl:warn ,datum ,@args)))

(defun emit-invoke-restart (node)
  "Emit an invoke-restart node as CL invoke-restart."
  (let ((name (emit-node (fol.compiler.ast:invoke-restart-node-name node)))
        (args (mapcar #'emit-node (fol.compiler.ast:invoke-restart-node-args node))))
    `(invoke-restart ,name ,@args)))

(defun emit-cond (node)
  "Emit a cond node as CL cond."
  (let ((clauses (fol.compiler.ast:cond-node-clauses node)))
    `(cl:cond
       ,@(mapcar (lambda (clause)
                   (let ((test (car clause))
                         (body (cdr clause)))
                     `((fol.compiler.primitives:truthy? ,(emit-node test))
                       ,@(mapcar #'emit-node body))))
             clauses))))

(defun emit-cond-thread-first (node)
  "Emit cond-> as nested if with -> threading."
  (let ((expr (emit-node (fol.compiler.ast:cond-thread-first-node-expr node)))
        (clauses (fol.compiler.ast:cond-thread-first-node-clauses node)))
    (emit-cond-thread-helper expr clauses t)))

(defun emit-cond-thread-last (node)
  "Emit cond->> as nested if with ->> threading."
  (let ((expr (emit-node (fol.compiler.ast:cond-thread-last-node-expr node)))
        (clauses (fol.compiler.ast:cond-thread-last-node-clauses node)))
    (emit-cond-thread-helper expr clauses nil)))

(defun emit-cond-thread-helper (expr clauses thread-first-p)
  "Helper for conditional threading emission."
  (if (null clauses)
      expr
      (let* ((clause (car clauses))
             (test (emit-node (car clause)))
             (form (emit-node (cdr clause)))
             (threaded (if thread-first-p
                           ;; Thread as first arg: (form expr ...)
                           (if (consp form)
                               `(,(car form) ,expr ,@(cdr form))
                               `(,form ,expr))
                           ;; Thread as last arg: (form ... expr)
                           (if (consp form)
                               `(,@form ,expr)
                               `(,form ,expr))))
             (rest-code (emit-cond-thread-helper threaded (cdr clauses) thread-first-p)))
        `(if (fol.compiler.primitives:truthy? ,test)
             ,rest-code
             ,expr))))

(defun emit-syntax-quote (node)
  "Emit syntax-quote as nested quasiquote with unquote support."
  (let ((template (fol.compiler.ast:syntax-quote-node-template node)))
    `(quote ,(emit-syntax-quote-template template))))

(defun emit-syntax-quote-template (template)
  "Recursively emit template, handling unquote nodes."
  (typecase template
    (fol.compiler.ast:unquote-node
     (emit-node (fol.compiler.ast:unquote-node-expr template)))
    (fol.compiler.ast:unquote-splicing-node
     `(,@(emit-node (fol.compiler.ast:unquote-splicing-node-expr template))))
    (cons
      (cons (emit-syntax-quote-template (car template))
            (emit-syntax-quote-template (cdr template))))
    (t template)))

(defun emit-case (node)
  "Emit a case node as CL case."
  (let ((expr (emit-node (fol.compiler.ast:case-node-expr node)))
        (clauses (fol.compiler.ast:case-node-clauses node)))
    `(cl:case ,expr
       ,@(mapcar (lambda (clause)
                   (let ((values (car clause))
                         (body (cdr clause)))
                     `(,values ,@(mapcar #'emit-node body))))
             clauses))))

(defun emit-env (node)
  "Emit env as nil (no CL equivalent for lexical environment capture)."
  (declare (ignore node))
  nil)

(defun emit-in-package (node)
  "Emit in-package node as CL defpackage option.
   Ensures fol.core is used and CL is used with conflict resolution."
  (let ((name (fol.compiler.ast:in-package-node-name node))
        (options (fol.compiler.ast:in-package-node-options node))
        (body (fol.compiler.ast:in-package-node-body node)))
    (let* ((use-opt (find :use options :key #'first))
           (other-opts (remove :use options :key #'first))
           (use-list (if use-opt (rest use-opt) nil))
           ;; Ensure :fol.core and :cl are present
           (new-use-list (cons :use
                               (remove-duplicates
                                   (append use-list '(:fol.core :cl))
                                 :test #'string-equal)))
           ;; Calculate conflicts between FOL.CORE and CL to auto-shadow
           (conflicts (loop for s being the external-symbols of (find-package :fol.core)
                              when (find-symbol (symbol-name s) :common-lisp)
                            collect (symbol-name s)))
           (auto-shadow `(:shadowing-import-from :fol.core ,@conflicts))
           (final-options (append (list new-use-list auto-shadow) other-opts))
           (pkg-def `(cl:defpackage ,name ,@final-options))
           (pkg-switch `(cl:in-package ,name))
           (emitted-body (mapcar #'emit-node body)))
      `(cl:progn
         ,pkg-def
         ,pkg-switch
         ,@emitted-body
         (cl:in-package :fol.core)))))

(defun emit-node (node)
  "Emit a Common Lisp form from an AST node."
  (etypecase node
    (fol.compiler.ast:literal-node (emit-literal node))
    (fol.compiler.ast:symbol-ref-node (emit-symbol-ref node))
    (fol.compiler.ast:call-node (emit-call node))
    (fol.compiler.ast:if-node (emit-if node))
    (fol.compiler.ast:do-node (emit-do node))
    (fol.compiler.ast:bind-node (emit-bind node))
    (fol.compiler.ast:quote-node (emit-quote node))
    (fol.compiler.ast:fn-node (emit-fn node))
    (fol.compiler.ast:thread-first-node (emit-thread-first node))
    (fol.compiler.ast:thread-last-node (emit-thread-last node))
    (fol.compiler.ast:vector-node (emit-vector node))
    (fol.compiler.ast:dict-node (emit-dict node))
    (fol.compiler.ast:set-node (emit-set node))
    (fol.compiler.ast:defmacro-node (emit-defmacro node))
    (fol.compiler.ast:defclass-node (emit-defclass node))
    (fol.compiler.ast:defgeneric-node (emit-defgeneric node))
    (fol.compiler.ast:defmethod-node (emit-defmethod node))
    (fol.compiler.ast:def-node (emit-def node))
    (fol.compiler.ast:defdynamic-node (emit-defdynamic node))
    (fol.compiler.ast:binding-node (emit-binding node))
    (fol.compiler.ast:swap-node (emit-swap! node))
    (fol.compiler.ast:defn-node (emit-defn node))
    (fol.compiler.ast:loop-node (emit-loop node))
    (fol.compiler.ast:recur-node (emit-recur node))
    (fol.compiler.ast:handler-case-node (emit-handler-case node))
    (fol.compiler.ast:handler-bind-node (emit-handler-bind node))
    (fol.compiler.ast:restart-case-node (emit-restart-case node))
    (fol.compiler.ast:signal-node (emit-signal node))
    (fol.compiler.ast:error-node (emit-error node))
    (fol.compiler.ast:warn-node (emit-warn node))
    (fol.compiler.ast:invoke-restart-node (emit-invoke-restart node))
    (fol.compiler.ast:cond-node (emit-cond node))
    (fol.compiler.ast:cond-thread-first-node (emit-cond-thread-first node))
    (fol.compiler.ast:cond-thread-last-node (emit-cond-thread-last node))
    (fol.compiler.ast:syntax-quote-node (emit-syntax-quote node))
    (fol.compiler.ast:unquote-node (error "unquote outside syntax-quote"))
    (fol.compiler.ast:unquote-splicing-node (error "unquote-splicing outside syntax-quote"))
    (fol.compiler.ast:case-node (emit-case node))
    (fol.compiler.ast:env-node (emit-env node))
    (fol.compiler.ast:in-package-node (emit-in-package node))
    ;; Functional special forms
    (fol.compiler.ast:defn-private-node (emit-defn-private node))
    (fol.compiler.ast:definline-node (emit-definline node))
    (fol.compiler.ast:some-thread-first-node (emit-some-thread-first node))
    (fol.compiler.ast:some-thread-last-node (emit-some-thread-last node))
    (fol.compiler.ast:as-thread-node (emit-as-thread node))
    ;; Local function definitions
    (fol.compiler.ast:letfn-node (emit-letfn node))))

;;; ---------------------------------------------------------------------------
;;; Main Entry Points
;;; ---------------------------------------------------------------------------

(defun compile-form (form)
  "Compile a single FOL form (already read) to a Common Lisp form.
   Returns a compilation-result."
  (handler-case
      (let* ((ast (parse-form form))
             (code (emit-node ast)))
        (make-compilation-result :code code))
    (error (e)
      (make-compilation-result
        :errors (list (format nil "~A" e))))))


(defun compile-string (source)
  "Read and compile a FOL source string.
   Returns a compilation-result."
  (let ((form (fol-read-from-string source)))
    (compile-form form)))

(defun compile-file (path &key (output nil))
  "Read and compile a FOL source file.
   If OUTPUT is given, writes the generated CL code to that path.
   Otherwise writes to a temporary .lisp file and calls CL:COMPILE-FILE.
   Returns the pathname of the compiled file (fasl)."
  (let* ((source-path (truename path))
         (lisp-path (make-pathname :type "lisp" :defaults (if output output source-path)))
         (fasl-path (make-pathname :type "fasl" :defaults lisp-path)))

    (with-open-file (in source-path :direction :input)
      (with-open-file (out lisp-path :direction :output :if-exists :supersede)
        ;; Bind readtable and package for reading
        (let ((*readtable* *fol-readtable*)
              (*package* (find-package :fol.core))) ;; Or current package? usually fol.core
          ;; Emit package declaration so cl:compile-file uses correct package
          (format out "~&(in-package :fol.core)~%")

          (loop for form = (fol-read in nil :eof)
                until (eq form :eof)
                do (let ((result (compile-form form)))
                     (if (compilation-result-errors result)
                         (error "Compilation error: ~A" (compilation-result-errors result))
                         (print (compilation-result-code result) out)))))))

    ;; Make sure to compile the generated Lisp file
    (cl:compile-file lisp-path)))