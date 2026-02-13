;;; FOL Compiler - AST Node Definitions
;;;
;;; Defines the abstract syntax tree nodes produced by parsing FOL source.
;;; Each node type corresponds to a FOL syntactic construct. The compiler
;;; transforms these nodes into Common Lisp code.

(in-package :fol.compiler.ast)

;;; ---------------------------------------------------------------------------
;;; Base Node
;;; ---------------------------------------------------------------------------

(defstruct ast-node
  "Base structure for all AST nodes."
  (form nil :read-only t)       ; original FOL form (for error reporting)
  (position nil :read-only t))  ; source position (line, column) if available

;;; ---------------------------------------------------------------------------
;;; Literals
;;; ---------------------------------------------------------------------------

(defstruct (literal-node (:include ast-node))
  "A literal value: number, string, character, boolean, keyword, or nil."
  (value nil :read-only t))

(defstruct (quote-node (:include ast-node))
  "A quoted form: (quote x) or 'x."
  (value nil :read-only t))

;;; ---------------------------------------------------------------------------
;;; Symbol References
;;; ---------------------------------------------------------------------------

(defstruct (symbol-ref-node (:include ast-node))
  "A reference to a named binding (variable, function, etc.)."
  (name nil :read-only t))

;;; ---------------------------------------------------------------------------
;;; Function Call
;;; ---------------------------------------------------------------------------

(defstruct (call-node (:include ast-node))
  "A function application: (f arg1 arg2 ...)."
  (operator nil :read-only t)   ; AST node for the function position
  (args nil :read-only t))      ; list of AST nodes for arguments

;;; ---------------------------------------------------------------------------
;;; Special Forms
;;; ---------------------------------------------------------------------------

(defstruct (if-node (:include ast-node))
  "Conditional: (if test then else)."
  (test nil :read-only t)
  (then nil :read-only t)
  (else nil :read-only t))

(defstruct (do-node (:include ast-node))
  "Sequential evaluation: (do expr1 expr2 ...)."
  (body nil :read-only t))      ; list of AST nodes

(defstruct (bind-node (:include ast-node))
  "Local binding: (bind [pattern init ...] body ...)."
  (bindings nil :read-only t)   ; list of (pattern . init-node) pairs
  (body nil :read-only t))      ; list of AST nodes

(defstruct (binding-node (:include ast-node))
  "Dynamic rebinding: (binding [*var* value ...] body ...).
   Rebinds special/dynamic variables for the duration of body.
   Uses CL let (parallel binding) on special vars."
  (bindings nil :read-only t)   ; list of (name . init-node) pairs
  (body nil :read-only t))      ; list of AST nodes

(defstruct (fn-node (:include ast-node))
  "Anonymous function: (fn name [params] body) or multi-clause (fn name ([p1] b1) ([p2] b2))."
  (name nil :read-only t)       ; optional name for self-reference
  (clauses nil :read-only t))   ; list of (params . body) for multi-clause

(defstruct (def-node (:include ast-node))
  "Top-level definition: (def name value)."
  (name nil :read-only t)
  (value nil :read-only t))     ; AST node for the value

(defstruct (defdynamic-node (:include ast-node))
  "Dynamic variable definition: (defdynamic *name* value).
   Explicit-intent alias for def — both compile to defvar."
  (name nil :read-only t)
  (value nil :read-only t))     ; AST node for the value

(defstruct (defn-node (:include ast-node))
  "Named function definition: (defn name ([params] body) ...)."
  (name nil :read-only t)
  (clauses nil :read-only t))   ; list of (params . body) clause nodes

(defstruct (loop-node (:include ast-node))
  "Loop with recur: (loop [bindings] body)."
  (bindings nil :read-only t)   ; list of (name . init-node) pairs
  (body nil :read-only t))      ; list of AST nodes

(defstruct (recur-node (:include ast-node))
  "Tail-position jump back to enclosing loop or fn: (recur args ...)."
  (args nil :read-only t))      ; list of AST nodes

;;; ---------------------------------------------------------------------------
;;; Collection Literals
;;; ---------------------------------------------------------------------------

(defstruct (vector-node (:include ast-node))
  "Vector literal: [a b c]."
  (elements nil :read-only t))  ; list of AST nodes

(defstruct (dict-node (:include ast-node))
  "Dict literal: {:key1 val1 :key2 val2}."
  (entries nil :read-only t))   ; list of (key-node . val-node) pairs

(defstruct (set-node (:include ast-node))
  "Set literal: #{a b c}."
  (elements nil :read-only t))  ; list of AST nodes

;;; ---------------------------------------------------------------------------
;;; Threading Macros
;;; ---------------------------------------------------------------------------

(defstruct (thread-first-node (:include ast-node))
  "Thread-first: (-> x form1 form2 ...)."
  (forms nil :read-only t))     ; list of AST nodes

(defstruct (thread-last-node (:include ast-node))
  "Thread-last: (->> x form1 form2 ...)."
  (forms nil :read-only t))     ; list of AST nodes

;;; ---------------------------------------------------------------------------
;;; Condition Handling
;;; ---------------------------------------------------------------------------

(defstruct (handler-case-node (:include ast-node))
  "Handle conditions with stack unwinding:
   (handler-case expr (condition-type (var) handler-body) ...)."
  (expr nil :read-only t)       ; AST node for the protected expression
  (clauses nil :read-only t))   ; list of (type var . body-nodes)

(defstruct (handler-bind-node (:include ast-node))
  "Bind condition handlers without unwinding:
   (handler-bind [(condition-type handler-fn) ...] body ...)."
  (bindings nil :read-only t)   ; list of (type . handler-node) pairs
  (body nil :read-only t))      ; list of AST nodes

(defstruct (restart-case-node (:include ast-node))
  "Establish restart points:
   (restart-case expr (restart-name (args) body) ...)."
  (expr nil :read-only t)       ; AST node for the protected expression
  (clauses nil :read-only t))   ; list of (name params . body-nodes)

(defstruct (signal-node (:include ast-node))
  "Signal a condition (recoverable): (signal datum args ...)."
  (datum nil :read-only t)      ; AST node for the condition designator
  (args nil :read-only t))      ; list of AST nodes for format args

(defstruct (error-node (:include ast-node))
  "Signal an error (enters debugger if unhandled): (error datum args ...)."
  (datum nil :read-only t)      ; AST node for the condition designator
  (args nil :read-only t))      ; list of AST nodes for format args

(defstruct (warn-node (:include ast-node))
  "Signal a warning: (warn datum args ...)."
  (datum nil :read-only t)      ; AST node for the condition designator
  (args nil :read-only t))      ; list of AST nodes for format args

(defstruct (invoke-restart-node (:include ast-node))
  "Invoke a named restart: (invoke-restart name args ...)."
  (name nil :read-only t)       ; AST node for the restart name
  (args nil :read-only t))      ; list of AST nodes for restart args

;;; ---------------------------------------------------------------------------
;;; Object System
;;; ---------------------------------------------------------------------------

(defstruct (defclass-node (:include ast-node))
  "Class definition: (defclass <name> [supers] [slots])."
  (name nil :read-only t)
  (superclasses nil :read-only t)
  (slots nil :read-only t))

(defstruct (defgeneric-node (:include ast-node))
  "Generic function definition: (defgeneric name [params] option*) or
   multi-pattern: (defgeneric name ([params1] [params2] ...) option*)."
  (name nil :read-only t)
  (lambda-lists nil :read-only t)  ; list of param vectors (single or multi-pattern)
  (options nil :read-only t))      ; generic function options

(defstruct (defmethod-node (:include ast-node))
  "Method definition: (defmethod name [params] body) or
   multi-clause: (defmethod name ([params1] body1) ([params2] body2) ...)."
  (name nil :read-only t)
  (clauses nil :read-only t))     ; list of (params . body-nodes), like fn-node

;;; ---------------------------------------------------------------------------
;;; Macros
;;; ---------------------------------------------------------------------------

(defstruct (defmacro-node (:include ast-node))
  "Macro definition: (defmacro name [params] body)."
  (name nil :read-only t)
  (params nil :read-only t)
  (body nil :read-only t))

;;; ---------------------------------------------------------------------------
;;; Additional Special Forms
;;; ---------------------------------------------------------------------------

(defstruct (cond-node (:include ast-node))
  "Multi-clause conditional: (cond (test1 body1) (test2 body2) ... (else body))."
  (clauses nil :read-only t))  ; list of (test-node . body-nodes)

(defstruct (cond-thread-first-node (:include ast-node))
  "Conditional threading first: (cond-> expr (test form) ...)."
  (expr nil :read-only t)      ; initial expression
  (clauses nil :read-only t))  ; list of (test-node . form-node)

(defstruct (cond-thread-last-node (:include ast-node))
  "Conditional threading last: (cond->> expr (test form) ...)."
  (expr nil :read-only t)
  (clauses nil :read-only t))

(defstruct (syntax-quote-node (:include ast-node))
  "Syntax quote (backtick): `(a ~b ~@c). Template with unquote escapes."
  (template nil :read-only t)) ; template form with unquote markers

(defstruct (unquote-node (:include ast-node))
  "Unquote: ~expr. Escape inside syntax-quote."
  (expr nil :read-only t))

(defstruct (unquote-splicing-node (:include ast-node))
  "Unquote-splicing: ~@expr. Splice list inside syntax-quote."
  (expr nil :read-only t))

(defstruct (case-node (:include ast-node))
  "Value dispatch: (case expr (val1 body1) ... (default body))."
  (expr nil :read-only t)      ; expression to dispatch on
  (clauses nil :read-only t))  ; list of (value-list . body-nodes)

(defstruct (env-node (:include ast-node))
  "Capture lexical environment: (env). Returns opaque environment object."
  )

(defstruct (swap-node (:include ast-node))
  "Atomic swap: (swap! atom fn & args). Special form to handle function references."
  (atom-expr nil :read-only t)     ; expression that evaluates to atom
  (fn-expr nil :read-only t)       ; function (bare symbol gets #')
  (args nil :read-only t))         ; additional arguments to fn
