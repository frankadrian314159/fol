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
  (form nil :read-only t) ; original FOL form (for error reporting)
  (position nil :read-only t) ; source position (line, column) if available
  (%type nil :read-only t)) ; type of AST node (e.g., 'literal, 'call, etc.)

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
  (operator nil :read-only t) ; AST node for the function position
  (args nil :read-only t)) ; list of AST nodes for arguments

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
  (body nil :read-only t)) ; list of AST nodes

(defstruct (bind-node (:include ast-node))
  "Local binding: (bind [pattern init ...] body ...)."
  (bindings nil :read-only t) ; list of (pattern . init-node) pairs
  (body nil :read-only t)) ; list of AST nodes

(defstruct (binding-node (:include ast-node))
  "Dynamic rebinding: (binding [*var* value ...] body ...).
   Rebinds special/dynamic variables for the duration of body.
   Uses CL let (parallel binding) on special vars."
  (bindings nil :read-only t) ; list of (name . init-node) pairs
  (body nil :read-only t)) ; list of AST nodes

(defstruct (letfn-node (:include ast-node))
  "Local function definitions: (letfn [(name [params] body...) ...] body...).
   Enables mutually recursive local functions; compiles to CL labels."
  (bindings nil :read-only t) ; list of (name params-vec body-nodes...) lists
  (body nil :read-only t)) ; list of AST nodes

(defstruct (fn-node (:include ast-node))
  "Anonymous function: (fn name [params] body) or multi-clause (fn name ([p1] b1) ([p2] b2))."
  (name nil :read-only t) ; optional name for self-reference
  (clauses nil :read-only t) ; list of (params . body) for multi-clause
  (docstring nil :read-only t)) ; optional docstring

(defstruct (def-node (:include ast-node))
  "Top-level definition: (def name value)."
  (name nil :read-only t)
  (value nil :read-only t)) ; AST node for the value

(defstruct (defdynamic-node (:include ast-node))
  "Dynamic variable definition: (defdynamic *name* value).
   Explicit-intent alias for def — both compile to defvar."
  (name nil :read-only t)
  (value nil :read-only t)) ; AST node for the value

(defstruct (defn-node (:include ast-node))
  "Named function definition: (defn name ([params] body) ...).
   Optionally includes a docstring as the first body element."
  (name nil :read-only t)
  (clauses nil :read-only t) ; list of (params . body) clause nodes
  (docstring nil :read-only t)) ; optional docstring

(defstruct (loop-node (:include ast-node))
  "Loop with recur: (loop [bindings] body)."
  (bindings nil :read-only t) ; list of (name . init-node) pairs
  (body nil :read-only t)) ; list of AST nodes

(defstruct (recur-node (:include ast-node))
  "Tail-position jump back to enclosing loop or fn: (recur args ...)."
  (args nil :read-only t)) ; list of AST nodes

;;; ---------------------------------------------------------------------------
;;; Collection Literals
;;; ---------------------------------------------------------------------------

(defstruct (vector-node (:include ast-node))
  "Vector literal: [a b c]."
  (elements nil :read-only t)) ; list of AST nodes

(defstruct (dict-node (:include ast-node))
  "Dict literal: {:key1 val1 :key2 val2}."
  (entries nil :read-only t)) ; list of (key-node . val-node) pairs

(defstruct (set-node (:include ast-node))
  "Set literal: #{a b c}."
  (elements nil :read-only t)) ; list of AST nodes

;;; ---------------------------------------------------------------------------
;;; Threading Macros
;;; ---------------------------------------------------------------------------

(defstruct (thread-first-node (:include ast-node))
  "Thread-first: (-> x form1 form2 ...)."
  (forms nil :read-only t)) ; list of AST nodes

(defstruct (thread-last-node (:include ast-node))
  "Thread-last: (->> x form1 form2 ...)."
  (forms nil :read-only t)) ; list of AST nodes

(defstruct (some-thread-first-node (:include ast-node))
  "Nil-safe thread-first: (some-> x form1 form2 ...)."
  (forms nil :read-only t)) ; list of AST nodes

(defstruct (some-thread-last-node (:include ast-node))
  "Nil-safe thread-last: (some->> x form1 form2 ...)."
  (forms nil :read-only t)) ; list of AST nodes

(defstruct (as-thread-node (:include ast-node))
  "Named threading: (as-> expr name form1 form2 ...)."
  (expr nil :read-only t) ; initial expression AST node
  (name nil :read-only t) ; binding symbol
  (forms nil :read-only t)) ; list of AST nodes

;;; ---------------------------------------------------------------------------
;;; Function Definition Variants
;;; ---------------------------------------------------------------------------

(defstruct (defn-private-node (:include ast-node))
  "Private function: (defn- name [params] body)."
  (name nil :read-only t)
  (clauses nil :read-only t) ; list of (params . body-nodes)
  (docstring nil :read-only t)) ; optional docstring

(defstruct (definline-node (:include ast-node))
  "Inline function: (definline name [params] body)."
  (name nil :read-only t)
  (clauses nil :read-only t) ; list of (params . body-nodes)
  (docstring nil :read-only t)) ; optional docstring

;;; ---------------------------------------------------------------------------
;;; Condition Handling
;;; ---------------------------------------------------------------------------

(defstruct (handler-case-node (:include ast-node))
  "Handle conditions with stack unwinding:
   (handler-case expr (condition-type (var) handler-body) ...)."
  (expr nil :read-only t) ; AST node for the protected expression
  (clauses nil :read-only t)) ; list of (type var . body-nodes)

(defstruct (handler-bind-node (:include ast-node))
  "Bind condition handlers without unwinding:
   (handler-bind [(condition-type handler-fn) ...] body ...)."
  (bindings nil :read-only t) ; list of (type . handler-node) pairs
  (body nil :read-only t)) ; list of AST nodes

(defstruct (restart-case-node (:include ast-node))
  "Establish restart points:
   (restart-case expr (restart-name (args) body) ...)."
  (expr nil :read-only t) ; AST node for the protected expression
  (clauses nil :read-only t)) ; list of (name params . body-nodes)

(defstruct (signal-node (:include ast-node))
  "Signal a condition (recoverable): (signal datum args ...)."
  (datum nil :read-only t) ; AST node for the condition designator
  (args nil :read-only t)) ; list of AST nodes for format args

(defstruct (error-node (:include ast-node))
  "Signal an error (enters debugger if unhandled): (error datum args ...)."
  (datum nil :read-only t) ; AST node for the condition designator
  (args nil :read-only t)) ; list of AST nodes for format args

(defstruct (warn-node (:include ast-node))
  "Signal a warning: (warn datum args ...)."
  (datum nil :read-only t) ; AST node for the condition designator
  (args nil :read-only t)) ; list of AST nodes for format args

(defstruct (invoke-restart-node (:include ast-node))
  "Invoke a named restart: (invoke-restart name args ...)."
  (name nil :read-only t) ; AST node for the restart name
  (args nil :read-only t)) ; list of AST nodes for restart args

;;; ---------------------------------------------------------------------------
;;; Object System
;;; ---------------------------------------------------------------------------

(defstruct (defclass-node (:include ast-node))
  "Class definition: (defclass <name> [supers] [slots] option*).
   Supported options: :abstract truthy  — class cannot be directly instantiated.
                      :sealed   truthy  — class cannot appear in an inheritance chain."
  (name nil :read-only t)
  (superclasses nil :read-only t)
  (slots nil :read-only t)
  (abstractp nil :read-only t) ; non-nil if :abstract option was truthy
  (sealedp nil :read-only t))  ; non-nil if :sealed option was truthy

(defstruct (defstruct-node (:include ast-node))
  "Struct definition: (defstruct <name> slot*).
   Each slot is either a symbol or a list (name :default val).
   Emits a defclass with <name>-<slot> accessors and a keyword constructor."
  (name nil :read-only t)
  (slots nil :read-only t))

(defstruct (defgeneric-node (:include ast-node))
  "Generic function definition: (defgeneric name [params] option*) or
   multi-pattern: (defgeneric name ([params1] [params2] ...) option*)."
  (name nil :read-only t)
  (lambda-lists nil :read-only t) ; list of param vectors (single or multi-pattern)
  (options nil :read-only t) ; generic function options
  (docstring nil :read-only t)) ; optional docstring

(defstruct (defmethod-node (:include ast-node))
  "Method definition: (defmethod name [params] body) or
   multi-clause: (defmethod name ([params1] body1) ([params2] body2) ...)."
  (name nil :read-only t)
  (qualifier nil :read-only t)
  (clauses nil :read-only t) ; list of (params . body-nodes), like fn-node
  (docstring nil :read-only t)) ; optional docstring

;;; ---------------------------------------------------------------------------
;;; Macros
;;; ---------------------------------------------------------------------------

(defstruct (defmacro-node (:include ast-node))
  "Macro definition: (defmacro name [params] body)."
  (name nil :read-only t)
  (params nil :read-only t)
  (body nil :read-only t)
  (docstring nil :read-only t)) ; optional docstring

;;; ---------------------------------------------------------------------------
;;; Additional Special Forms
;;; ---------------------------------------------------------------------------

(defstruct (cond-node (:include ast-node))
  "Multi-clause conditional: (cond (test1 body1) (test2 body2) ... (else body))."
  (clauses nil :read-only t)) ; list of (test-node . body-nodes)

(defstruct (cond-thread-first-node (:include ast-node))
  "Conditional threading first: (cond-> expr (test form) ...)."
  (expr nil :read-only t) ; initial expression
  (clauses nil :read-only t)) ; list of (test-node . form-node)

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
  (expr nil :read-only t) ; expression to dispatch on
  (clauses nil :read-only t)) ; list of (value-list . body-nodes)

(defstruct (env-node (:include ast-node))
  "Capture lexical environment: (env). Returns opaque environment object.")


(defstruct (in-package-node (:include ast-node))
  "Package definition: (in-package name [options...] body...)."
  (name nil :read-only t)
  (options nil :read-only t)
  (body nil :read-only t)) ; list of body forms

(defstruct (defpackage-node (:include ast-node))
  "Package definition: (defpackage name [options...] body...)."
  (name nil :read-only t)
  (options nil :read-only t)) ; list of package options (e.g., :use, :export)

(defstruct (swap-node (:include ast-node))
  "Atomic swap: (swap! atom fn & args). Special form to handle function references."
  (atom-expr nil :read-only t) ; expression that evaluates to atom
  (fn-expr nil :read-only t) ; function (bare symbol gets #')
  (args nil :read-only t)) ; additional arguments to fn

(defstruct (setf-node (:include ast-node))
  "Setf form: (setf place value place2 value2 ...).
   FOL does not permit mutation via setf; parsing captures the form for
   a descriptive compiler error at emit time."
  (pairs nil :read-only t)) ; list of (place-form . value-node) pairs

(defstruct (setq-node (:include ast-node))
  "Setq form: (setq var value var2 value2 ...).
   FOL does not permit mutation via setq; captured for a compiler error."
  (pairs nil :read-only t)) ; list of (var-symbol . value-form) pairs

(defstruct (cl-set-node (:include ast-node))
  "Set form: (set symbol value).
   FOL does not permit mutation via set; captured for a compiler error."
  (symbol-form nil :read-only t) ; the symbol argument (raw form)
  (value-form nil :read-only t)) ; the value argument (raw form)

(defstruct (psetq-node (:include ast-node))
  "Psetq form: (psetq var value ...) — parallel assignment.
   FOL does not permit mutation via psetq; captured for a compiler error."
  (pairs nil :read-only t)) ; list of (var-symbol . value-form) pairs

(defstruct (psetf-node (:include ast-node))
  "Psetf form: (psetf place value ...) — parallel generalized assignment.
   FOL does not permit mutation via psetf; captured for a compiler error."
  (pairs nil :read-only t)) ; list of (place-form . value-form) pairs

(defstruct (incf-node (:include ast-node))
  "Incf form: (incf place &optional delta).
   FOL does not permit mutation via incf; captured for a compiler error."
  (place nil :read-only t) ; raw place form
  (delta nil :read-only t)) ; raw delta form, or nil for the default of 1

(defstruct (decf-node (:include ast-node))
  "Decf form: (decf place &optional delta).
   FOL does not permit mutation via decf; captured for a compiler error."
  (place nil :read-only t) ; raw place form
  (delta nil :read-only t)) ; raw delta form, or nil for the default of 1

(defstruct (pushnew-node (:include ast-node))
  "Pushnew form: (pushnew item place &key test test-not key).
   FOL does not permit mutation via pushnew; captured for a compiler error."
  (item nil :read-only t)  ; raw item form
  (place nil :read-only t) ; raw place form
  (keys nil :read-only t)) ; raw keyword argument forms

(defstruct (rotatef-node (:include ast-node))
  "Rotatef form: (rotatef place ...) — rotates values among places.
   FOL does not permit mutation via rotatef; captured for a compiler error."
  (places nil :read-only t)) ; list of raw place forms

(defstruct (shiftf-node (:include ast-node))
  "Shiftf form: (shiftf place ... newval) — shifts values left among places.
   FOL does not permit mutation via shiftf; captured for a compiler error."
  (places nil :read-only t) ; raw place forms (all but the last argument)
  (newval nil :read-only t)) ; raw new-value form (last argument)

(defstruct (rplaca-node (:include ast-node))
  "Rplaca form: (rplaca cons new-car) — destructively replaces the car of a cons cell.
   FOL does not permit mutation via rplaca; captured for a compiler error."
  (cons-form nil :read-only t)    ; raw cons argument
  (new-car   nil :read-only t))   ; raw new-car argument

(defstruct (rplacd-node (:include ast-node))
  "Rplacd form: (rplacd cons new-cdr) — destructively replaces the cdr of a cons cell.
   FOL does not permit mutation via rplacd; captured for a compiler error."
  (cons-form nil :read-only t)    ; raw cons argument
  (new-cdr   nil :read-only t))   ; raw new-cdr argument

;;; ---------------------------------------------------------------------------
;;; AST Traversal Helpers
;;; ---------------------------------------------------------------------------

(defgeneric node-children (node)
  (:documentation "Return a list of all child AST nodes of NODE."))

(defgeneric remake-node-with-children (node new-children)
  (:documentation "Create a new node of the same type and with the same
  non-child properties as NODE, but with NEW-CHILDREN."))

;; Default method for nodes with no children
(defmethod node-children ((node ast-node))
  nil)

(defmethod remake-node-with-children ((node ast-node) new-children)
  (declare (ignore new-children))
  node)

;; --- Implementations for nodes with children ---

(defmethod node-children ((node call-node))
  (cons (call-node-operator node) (call-node-args node)))

(defmethod remake-node-with-children ((node call-node) new-children)
  (make-call-node
   :operator (first new-children)
   :args (rest new-children)
   :form (ast-node-form node)))

(defmethod node-children ((node if-node))
  (list* (if-node-test node) (if-node-then node) (if-node-else node)))

(defmethod remake-node-with-children ((node if-node) new-children)
  (make-if-node
   :test (first new-children)
   :then (second new-children)
   :else (cddr new-children)
   :form (ast-node-form node)))

(defmethod node-children ((node do-node))
  (do-node-body node))

(defmethod remake-node-with-children ((node do-node) new-children)
  (make-do-node :body new-children :form (ast-node-form node)))

(defmethod node-children ((node bind-node))
  (append (mapcar #'cdr (bind-node-bindings node))
          (bind-node-body node)))

(defmethod remake-node-with-children ((node bind-node) new-children)
  (let ((num-bindings (length (bind-node-bindings node))))
    (make-bind-node
     :bindings (loop for b in (bind-node-bindings node)
                     for new-init in (subseq new-children 0 num-bindings)
                     collect (cons (car b) new-init))
     :body (subseq new-children num-bindings)
     :form (ast-node-form node))))

(defmethod node-children ((node fn-node))
  (loop for clause in (fn-node-clauses node)
        append (cdr clause)))

(defmethod remake-node-with-children ((node fn-node) new-children)
  (let ((child-ptr new-children))
    (make-fn-node
     :name (fn-node-name node)
     :clauses (loop for clause in (fn-node-clauses node)
                    for body-len = (length (cdr clause))
                    collect (let ((new-body (subseq child-ptr 0 body-len)))
                              (setf child-ptr (nthcdr body-len child-ptr))
                              (cons (car clause) new-body)))
     :form (ast-node-form node))))

(defmethod node-children ((node defn-node))
  (loop for clause in (defn-node-clauses node)
        append (cdr clause)))

(defmethod remake-node-with-children ((node defn-node) new-children)
  (let ((child-ptr new-children))
    (make-defn-node
     :name (defn-node-name node)
     :docstring (defn-node-docstring node)
     :clauses (loop for clause in (defn-node-clauses node)
                    for body-len = (length (cdr clause))
                    collect (let ((new-body (subseq child-ptr 0 body-len)))
                              (setf child-ptr (nthcdr body-len child-ptr))
                              (cons (car clause) new-body)))
     :form (ast-node-form node))))

(defmethod node-children ((node loop-node))
  (append (mapcar #'cdr (loop-node-bindings node))
          (loop-node-body node)))

(defmethod remake-node-with-children ((node loop-node) new-children)
  (let ((num-bindings (length (loop-node-bindings node))))
    (make-loop-node
     :bindings (loop for b in (loop-node-bindings node)
                     for new-init in (subseq new-children 0 num-bindings)
                     collect (cons (car b) new-init))
     :body (subseq new-children num-bindings)
     :form (ast-node-form node))))

(defmethod node-children ((node recur-node))
  (recur-node-args node))

(defmethod remake-node-with-children ((node recur-node) new-children)
  (make-recur-node :args new-children :form (ast-node-form node)))

;; Add other node types here as needed...
