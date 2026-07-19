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

(defvar +standard-fol-functions+
  '("+" "-" "*" "/" "<" ">" "<=" ">=" "=" "/=" "MIN" "MAX"
    "NOT" "AND" "OR" "IDENTITY" "CONSTANTLY" "COMPLEMENT" "APPLY"
    "REPLACE" "FIRST" "REST" "NTH" "PUSH" "POP" "FIND" "SUBSEQ"
    "UNION" "INTERSECTION" "SORT" "REVERSE" "LIST" "LIST*" "VECTOR"
    "MAP" "REDUCE" "REMOVE" "SOME" "EVERY" "THIRD" "SECOND" "LAST" "BUTLAST"
    "INTERN" "CHAR" "FORMAT" "COMPILE-FILE" "MACROEXPAND-1" "MACROEXPAND"
    "DEFMACRO" "DEFCLASS" "DEFGENERIC" "DEFMETHOD" "LOOP" "QUOTE" "IF" "DO"
    "COND" "CASE" "WHEN" "DOTIMES" "TIME" "ASSERT" "ASSOC" "DISSOC" "CONJ"
    "UPDATE" "COUNT" "MERGE" "GET" "PRINT" "PPRINT" "READ" "READ-LINE" "CLOSE" 
    "DELETE-FILE" "ATOM" "MAKE" "NIL?" "INC" "DEC"
    "RANGE" "REPEAT" "REPEATEDLY" "ITERATE" "ITERATION" "INTERLEAVE" "INTERPOSE"
    "CYCLE" "CONS" "CONCAT" "INTO" "FILTER" "FILTERV" "MAPV" "PMAP" "MAPCAT"
    "TAKE" "DROP" "TAKE-WHILE" "DROP-WHILE" "PARTITION" "PARTITION-BY" "GROUP-BY"
    "DISTINCT" "DEDUPE" "FLATTEN" "ZIPMAP" "REDUCTIONS" "REALIZED?" "DORUN" 
    "DOALL" "RUN!" "RAND-NTH" "VEC" "SEQ"
    "STR" "SUBS" "SPLIT" "JOIN" "TRIM" "UPPER-CASE" "LOWER-CASE" "CAPITALIZE"
    "CONTAINS?" "EMPTY?" "EVERY?" "DISTINCT?" "NOT-EVERY?" "NOT-ANY?"
    "PERSISTENT-CLASS" "<PERSISTENT-OBJECT>" "TRUTHY?" "PRINTLN"
    "DICT" "SET" "EXP" "SYMBOL" "KEYWORD")
  "List of standard FOL function names (strings).")

(defstruct compilation-result
  "Result of compiling a FOL form."
  (code nil) ; the generated Common Lisp form
  (warnings nil) ; list of warning strings
  (errors nil)) ; list of error strings

;;; ---------------------------------------------------------------------------
;;; Optimization Pragmas
;;; ---------------------------------------------------------------------------

(defvar *inline-methods-enabled* nil
  "Set of function names with inline-methods optimization enabled.
   When T, enables inlining for all functions. When a hash table or list,
   enables only for listed functions.")

(defvar *optimize-constructors* t
  "When T, emit specialized &key constructors for defclass. When NIL, emit slower &rest constructors.")

(defun enable-inline-methods (&optional (functions t))
  "Enable inline-methods optimization.
   FUNCTIONS can be:
   - T: enable for all functions
   - list of symbols: enable only for listed functions
   - hash table: enable for functions in hash table keys"
  (setf *inline-methods-enabled* functions))

(defun disable-inline-methods ()
  "Disable inline-methods optimization."
  (setf *inline-methods-enabled* nil))

(defun inline-methods-enabled-p (fn-name)
  "Check if inline-methods is enabled for FN-NAME."
  (or (eq *inline-methods-enabled* t)
      (and (listp *inline-methods-enabled*)
           (member fn-name *inline-methods-enabled*))
      (and (hash-table-p *inline-methods-enabled*)
           (gethash fn-name *inline-methods-enabled*))))

;;; ---------------------------------------------------------------------------
;;; Simple Method Detection (for inlining)
;;; ---------------------------------------------------------------------------

(defvar *simple-around-methods* (make-hash-table :test 'equal)
  "Registry of simple :around methods that could be inlined.
   Key: gf-name (generic function name)
   Value: list of (specializers . body-length) for each simple :around method
   Specializers is a list of (param-name . type-name) pairs for type-specialized params")

(defvar *around-method-specializers* (make-hash-table :test 'equal)
  "Maps (gf-name . specializer-signature) to method info for dispatch optimization.
   Specializer-signature is a dotted list of type names.")

(defun is-simple-method-p (body-nodes)
  "Check if method body is simple enough to potentially inline.
   Simple methods have:
   - Few forms (< 5 statements)
   - No complex control flow (no loop, flet, labels, etc.)
   - Mostly calls and simple expressions"
  (and (listp body-nodes)
       (< (length body-nodes) 5)))

(defun extract-type-specializers (param-list)
  "Extract type specializers from parameter list.
   Returns ((param-name . type-name) ...) for parameters with type specializers.
   Returns nil if no type specializers found."
  (loop for param in param-list
        when (listp param)
        collect param))

(defun registers-simple-around-method (gf-name qualifier clause)
  "Register a simple :around method for potential inlining.
   CLAUSE is (param-vec . body-nodes).
   Captures type specializers for dispatch optimization."
  (when (and (eq qualifier :around)
             (= (length clause) 2))
    (let* ((param-vec (car clause))
           (body-nodes (cdr clause))
           (param-list (fol-vector-to-list param-vec))
           (type-specs (extract-type-specializers param-list)))
      (when (is-simple-method-p body-nodes)
        ;; Register in main registry
        (let* ((key gf-name)
               (current (gethash key *simple-around-methods* nil)))
          (setf (gethash key *simple-around-methods*)
                (append current (list (cons type-specs (length body-nodes)))))
          ;; Also register by signature for faster lookup
          (when type-specs
            (let ((sig (cons gf-name (mapcar #'cdr type-specs))))
              (setf (gethash sig *around-method-specializers*) t))))))))

;;; ---------------------------------------------------------------------------
;;; :around Method Dispatch Optimization
;;; ---------------------------------------------------------------------------

(defvar *around-method-info* (make-hash-table :test 'equal)
  "Detailed information about simple :around methods for code generation.
   Key: (gf-name . specializer-signature)
   Value: (specializer-types . analysis-info)")

(defun has-simple-around-methods-p (gf-name)
  "Check if generic function has registered simple :around methods."
  (not (null (gethash gf-name *simple-around-methods*))))

(defun emit-optimized-generic-call (gf-name emitted-args)
  "Emit dispatch code for a call to GF-NAME, a generic function with at least
   one registered simple :around method (see HAS-SIMPLE-AROUND-METHODS-P).

   This used to branch on method shape and, for type-specialized methods,
   wrap the call in (locally (declare (optimize (inline 3))) ...) as a
   compiler 'hint'. INLINE is not a real CL optimize quality, so it never
   inlined anything -- and because registration is keyed only on GF-NAME
   (not on the specific class the :around method specializes on), any
   earlier compilation that defined a simple :around method on some
   GF-NAME, anywhere, in any file compiled into the same image, caused
   every later, unrelated call site sharing that name to be wrapped too.
   When such a call site's emitted form was later re-walked as source by
   another compiler pass, the unrecognized DECLARE inside LOCALLY was
   parsed as a call to a function named DECLARE and failed with \"no
   function named DECLARE\". Emitting a plain call unconditionally avoids
   both the meaningless hint and the cross-compilation-unit hazard."
  (let ((generic-sym (intern (symbol-name gf-name) :fol.core)))
    `(,generic-sym ,@emitted-args)))

;;; ---------------------------------------------------------------------------
;;; Around Method Specialization Code Generation
;;; ---------------------------------------------------------------------------

(defun generate-specialized-dispatch (gf-name class-name method-body)
  "Generate a specialized dispatch function for a :around method.

   Creates a wrapper function that:
   1. Checks if argument matches CLASS-NAME
   2. If yes: inlines the :around METHOD-BODY
   3. If no: delegates to the normal generic

   This enables call-site specialization without modifying defmethod."
  ;; Placeholder for future implementation
  ;; Would generate code like:
  ;; (defun gf-name-optimized-dispatch (obj &rest args)
  ;;   (if (typep obj 'class-name)
  ;;       ;; inlined :around logic here
  ;;       (original-gf-name obj &rest args)))
  nil)

;;; ---------------------------------------------------------------------------
;;; FOL Vector Helpers
;;; ---------------------------------------------------------------------------

(defun fol-vector-p (x)
  "Check if X is a FOL <vector> instance (from the reader's [...] syntax)."
  (typep x 'fol.compiler.collections:<vector>))

(defun param-vector-p (x)
  "Check if X is a valid parameter vector: either FOL <vector> or CL vector.
   Accepts both [...] (FOL syntax) and #(...) (CL syntax)."
  (or (fol-vector-p x) (cl:vectorp x)))

(defun sequence-p (x)
  "Check if X is a sequence (CL list or FOL <vector>)."
  (or (cl:listp x) (fol-vector-p x)))

(defun fol-vector-to-list (v)
  "Convert a FOL <vector> or CL list to a CL list of its elements."
  (if (cl:listp v)
      v
      (fol.compiler.collections:collection-seq v)))

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
    (cons (parse-compound form))
    (t (cond
        ;; FOL bag literal #M{a b c}
        ((typep form 'fol.compiler.collections:<bag>)
          (fol.compiler.ast:make-call-node
           :operator (fol.compiler.ast:make-symbol-ref-node :name 'fol.compiler.collection-functions:bag :form form)
           :args (mapcar #'parse-form (fol.compiler.collections:collection-seq form))
           :form form))
        ;; FOL deque literal #Q[a b c]
        ((typep form 'fol.compiler.collections:<deque>)
          (fol.compiler.ast:make-call-node
           :operator (fol.compiler.ast:make-symbol-ref-node :name 'fol.compiler.collection-functions:deque :form form)
           :args (mapcar #'parse-form (fol.compiler.collections:collection-seq form))
           :form form))
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

(defun %delistify (form)
  "Recursively convert FOL <LIST> collection objects back into ordinary CL
   conses. A macro's own expander body builds its expansion with FOL's
   LIST/CONS, which (like every other FOL collection constructor) produces
   a persistent <LIST> object, not a raw CL cons -- so MACROEXPAND-1's
   result needs this before PARSE-FORM can walk it as code, exactly as it
   walks a hand-written form. Raw macro arguments (T1, B1, ... below) are
   always already CL conses straight from the reader and pass through
   unchanged; only the expander's own <LIST>-typed wrapping, however
   deeply nested, needs converting."
  (cond
    ((typep form 'fol.compiler.collections:<list>)
     (mapcar #'%delistify (fol.compiler.collections:collection-seq form)))
    ((consp form) (cons (%delistify (car form)) (%delistify (cdr form))))
    (t form)))

(defun parse-compound (form)
  "Parse a compound form (list) into an AST node.
   Dispatches on the operator to handle macros, special forms, and function calls."
  (cond
   ;; Check for macros first and expand them
   ((and (symbolp (car form)) (macro-p (car form)))
     (let ((expanded (%delistify (macroexpand-1 form))))
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
                                  (param-vector-p (first (first forms))))))
      (cond
       ;; Single clause, no name: (fn [params] body ...)
       ((and (>= (length args) 1)
             (param-vector-p (first args)))
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
          ((param-vector-p (second args))
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
  "Parse a defmacro form: (defmacro name [params] body ...) or
   (defmacro name [params] \"doc\" body ...).
   Params support destructuring but not predicate specializers."
  (destructuring-bind (op name params &rest body) form
    (declare (ignore op))
    ;; Check if first element of body is a string (docstring)
    (let ((docstring (and (>= (length body) 1) (stringp (first body)) (first body)))
          (actual-body (if (and (>= (length body) 1) (stringp (first body)))
                           (rest body)
                           body)))
      (fol.compiler.ast:make-defmacro-node
       :name name
       :params params
       :body (mapcar #'parse-form actual-body)
       :docstring docstring
       :form form))))

(defun fol-option-truthy-p (val)
  "Return true if VAL is a truthy option value in FOL defclass option context.
   The value is a raw (unparsed) form: NIL, the symbol FALSE, and the symbol NIL
   are all falsy; everything else is truthy."
  (and (not (null val))
       (not (and (symbolp val) (string= (symbol-name val) "FALSE")))
       (not (and (symbolp val) (string= (symbol-name val) "NIL")))))

(defun parse-defclass (form)
  "Parse a defclass form: (defclass <name> [supers] [slots] option*).
   Superclasses and slots are specified as vectors.
   Slots can be simple symbols or vectors of [name :initarg ... :accessor ...].
   Options: :abstract truthy  — class cannot be directly instantiated.
            :sealed   truthy  — class cannot appear in an inheritance chain."
  (destructuring-bind (op name supers-vec slots-vec &rest options) form
    (declare (ignore op))
    (let ((supers (fol-vector-to-list supers-vec))
          (slots (mapcar (lambda (s)
                           (if (fol-vector-p s) (fol-vector-to-list s) s))
                     (fol-vector-to-list slots-vec)))
          (abstractp (fol-option-truthy-p (getf options :abstract)))
          (sealedp (fol-option-truthy-p (getf options :sealed))))
      (fol.compiler.ast:make-defclass-node
       :name name
       :superclasses supers
       :slots slots
       :abstractp abstractp
       :sealedp sealedp
       :form form))))

(defun parse-defstruct (form)
  "Parse (defstruct <name> slot*).
   Each slot is either a bare symbol or a vector [name :default val].
   Emits a persistent defclass with <name>-<slot> accessors and a keyword constructor."
  (destructuring-bind (op name &rest slot-specs) form
    (declare (ignore op))
    (let ((slots (mapcar (lambda (s)
                           (if (fol-vector-p s) (fol-vector-to-list s) s))
                     slot-specs)))
      (fol.compiler.ast:make-defstruct-node
       :name name
       :slots slots
       :form form))))

(defun parse-defgeneric (form)
  "Parse a defgeneric form:
   (defgeneric name [params] option*)                    - single pattern
   (defgeneric name [params] \"doc\" option*)            - with docstring
   (defgeneric name ([params1] [params2] ...) option*)   - multi-pattern"
  (destructuring-bind (op name lambda-spec &rest options) form
    (declare (ignore op))
    (let ((docstring (and (>= (length options) 1) (stringp (first options)) (first options)))
          (actual-options (if (and (>= (length options) 1) (stringp (first options)))
                              (rest options)
                              options)))
      (format t "DEBUG: parse-defgeneric lambda-spec type: ~A~%" (type-of lambda-spec))
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
         :options actual-options
         :docstring docstring
         :form form)))))

(defun parse-defmethod (form)
  "Parse a defmethod form:
   (defmethod name [params] body ...)               - single clause
   (defmethod name ([params1] body1) ([params2] body2) ...) - multi-clause
   Each clause is a list starting with a param vector."
  (destructuring-bind (op name &rest args) form
    (declare (ignore op))
    (let* ((qualifier (if (cl:keywordp (cl:first args)) (cl:first args) cl:nil))
           (real-args (if qualifier (cl:rest args) args)))
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
         ((and (>= (length real-args) 1)
               (fol-vector-p (first real-args)))
           (fol.compiler.ast:make-defmethod-node
            :name name
            :qualifier qualifier
            :clauses (list (cons (first real-args) (mapcar #'parse-form (rest real-args))))
            :form form))
         ;; Multi-clause: (defmethod name ([p1] b1 ...) ([p2] b2 ...) ...)
         ((multi-clause-p real-args)
           (fol.compiler.ast:make-defmethod-node
            :name name
            :qualifier qualifier
            :clauses (mapcar #'parse-clause real-args)
            :form form))
         (t (error "Invalid defmethod form: ~S" form)))))))

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

(defun parse-defun (form)
  "Parse a defun form: (defun name (params) body ...).
   Converts to a defn-node for consistency, handling list params."
  (destructuring-bind (op name params &rest body) form
    (declare (ignore op))
    (let ((param-vec (if (listp params)
                         (apply #'fol.compiler.collection-functions:vector params)
                         params)))
      (fol.compiler.ast:make-defn-node
       :name name
       :clauses (list (cons param-vec (mapcar #'parse-form body)))
       :form form))))

(defun parse-defn (form)
  "Parse a defn form into a defn-node.
   Supported syntaxes:
     (defn name [params] body ...)                                    - single clause
     (defn name ([p1] b1 ...) ([p2] b2 ...) ...)                    - multi-clause
     (defn ^long name [a b] ...)                                     - with type metadata

   Type metadata can be attached via reader ^TYPE syntax and is stored on the function
   name symbol plist for use by emit-defn to generate SBCL type declarations."
  (destructuring-bind (op name &rest args) form
    (declare (ignore op))

    ;; Extract metadata from the name if it's wrapped in with-meta by reader
    ;; (with-meta name-sym metadata-dict) -> extract and attach to symbol plist
    (when (and (listp name)
               (= (length name) 2)
               (symbolp (first name))
               (string= (symbol-name (first name)) "WITH-META"))
      (let ((actual-name (second name))
            (meta-expr (third name)))
        ;; Store the metadata expression on the symbol plist for later extraction
        ;; Note: meta-expr is a reader-generated (dict :type TypeName) form
        (when (symbolp actual-name)
          (setf (cl:symbol-plist actual-name)
                (cl:list* :defn-type-metadata meta-expr (cl:symbol-plist actual-name)))
          (setf name actual-name))))
    (labels ((parse-clause (clause)
                           (destructuring-bind (params &rest body) clause
                             (cons params (mapcar #'parse-form body))))
             (multi-clause-p (forms)
                             (and (>= (length forms) 1)
                                  (listp (first forms))
                                  (not (null (first forms)))
                                  (param-vector-p (first (first forms))))))
      (cond
       ;; Single clause: (defn name [params] body ...) or (defn name "doc" [params] body ...)
       ((and (>= (length args) 1)
             (param-vector-p (first args)))
         (fol.compiler.ast:make-defn-node
          :name name
          :clauses (list (cons (first args) (mapcar #'parse-form (rest args))))
          :form form))
       ;; Single clause with docstring: (defn name "doc" [params] body ...)
       ((and (>= (length args) 2)
             (stringp (first args))
             (param-vector-p (second args)))
         (fol.compiler.ast:make-defn-node
          :name name
          :clauses (list (cons (second args) (mapcar #'parse-form (cddr args))))
          :docstring (first args)
          :form form))
       ;; Multi-clause: (defn name ([p1] b1 ...) ([p2] b2 ...) ...)
       ((multi-clause-p args)
         (fol.compiler.ast:make-defn-node
          :name name
          :clauses (mapcar #'parse-clause args)
          :form form))
       ;; Multi-clause with docstring: (defn name "doc" ([p1] b1 ...) ([p2] b2 ...) ...)
       ((and (>= (length args) 2)
             (stringp (first args))
             (multi-clause-p (rest args)))
         (fol.compiler.ast:make-defn-node
          :name name
          :clauses (mapcar #'parse-clause (rest args))
          :docstring (first args)
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
                                  (param-vector-p (first (first forms))))))
      (cond
       ((and (>= (length args) 1)
             (fol-vector-p (first args)))
         (fol.compiler.ast:make-defn-private-node
          :name name
          :clauses (list (cons (first args) (mapcar #'parse-form (rest args))))
          :form form))
       ((and (>= (length args) 2)
             (stringp (first args))
             (fol-vector-p (second args)))
         (fol.compiler.ast:make-defn-private-node
          :name name
          :clauses (list (cons (second args) (mapcar #'parse-form (cddr args))))
          :docstring (first args)
          :form form))
       ((multi-clause-p args)
         (fol.compiler.ast:make-defn-private-node
          :name name
          :clauses (mapcar #'parse-clause args)
          :form form))
       ((and (>= (length args) 2)
             (stringp (first args))
             (multi-clause-p (rest args)))
         (fol.compiler.ast:make-defn-private-node
          :name name
          :clauses (mapcar #'parse-clause (rest args))
          :docstring (first args)
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
                                  (param-vector-p (first (first forms))))))
      (cond
       ((and (>= (length args) 1)
             (fol-vector-p (first args)))
         (fol.compiler.ast:make-definline-node
          :name name
          :clauses (list (cons (first args) (mapcar #'parse-form (rest args))))
          :form form))
       ((and (>= (length args) 2)
             (stringp (first args))
             (fol-vector-p (second args)))
         (fol.compiler.ast:make-definline-node
          :name name
          :clauses (list (cons (second args) (mapcar #'parse-form (cddr args))))
          :docstring (first args)
          :form form))
       ((multi-clause-p args)
         (fol.compiler.ast:make-definline-node
          :name name
          :clauses (mapcar #'parse-clause args)
          :form form))
       ((and (>= (length args) 2)
             (stringp (first args))
             (multi-clause-p (rest args)))
         (fol.compiler.ast:make-definline-node
          :name name
          :clauses (mapcar #'parse-clause (rest args))
          :docstring (first args)
          :form form))
       (t (error "Invalid definline form: ~S" form))))))

(defun parse-loop (form)
  "Parse a loop form: (loop [name init name init ...] body...).
   The first argument is a vector of alternating name/init pairs."
  (destructuring-bind (op bindings &rest body) form
    (declare (ignore op))
    (let* ((binding-list (cond
                          ((fol-vector-p bindings) (fol-vector-to-list bindings))
                          ((cl:listp bindings) bindings)
                          (t (error "loop: Expected a sequence for bindings, got ~S" bindings))))
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

(defun parse-setf (form)
  "Parse (setf place value ...) — Common Lisp setf syntax.
   FOL does not permit mutation via setf; the form is captured so that
   emit-setf can produce a descriptive compiler error."
  (destructuring-bind (op &rest place-value-pairs) form
    (declare (ignore op))
    (when (oddp (length place-value-pairs))
          (error "setf requires an even number of place/value arguments, got ~D"
            (length place-value-pairs)))
    (let ((pairs (loop for (place value) on place-value-pairs by #'cddr
                       collect (cons place (parse-form value)))))
      (fol.compiler.ast:make-setf-node
       :pairs pairs
       :form form))))

(defun parse-setq (form)
  "Parse (setq var value ...) — pairs of variable/value.
   FOL does not permit mutation via setq; the form is captured for a compiler error."
  (destructuring-bind (op &rest var-value-pairs) form
    (declare (ignore op))
    (when (oddp (length var-value-pairs))
          (error "setq requires an even number of var/value arguments, got ~D"
            (length var-value-pairs)))
    (let ((pairs (loop for (var value) on var-value-pairs by #'cddr
                       collect (cons var value))))
      (fol.compiler.ast:make-setq-node
       :pairs pairs
       :form form))))

(defun parse-cl-set (form)
  "Parse (set symbol value) — sets the value cell of a symbol.
   FOL does not permit mutation via set; the form is captured for a compiler error."
  (destructuring-bind (op symbol-arg value-arg) form
    (declare (ignore op))
    (fol.compiler.ast:make-cl-set-node
     :symbol-form symbol-arg
     :value-form value-arg
     :form form)))

(defun parse-psetq (form)
  "Parse (psetq var value ...) — parallel variable assignment.
   FOL does not permit mutation via psetq; the form is captured for a compiler error."
  (destructuring-bind (op &rest var-value-pairs) form
    (declare (ignore op))
    (when (oddp (length var-value-pairs))
          (error "psetq requires an even number of var/value arguments, got ~D"
            (length var-value-pairs)))
    (let ((pairs (loop for (var value) on var-value-pairs by #'cddr
                       collect (cons var value))))
      (fol.compiler.ast:make-psetq-node
       :pairs pairs
       :form form))))

(defun parse-psetf (form)
  "Parse (psetf place value ...) — parallel generalized assignment.
   FOL does not permit mutation via psetf; the form is captured for a compiler error."
  (destructuring-bind (op &rest place-value-pairs) form
    (declare (ignore op))
    (when (oddp (length place-value-pairs))
          (error "psetf requires an even number of place/value arguments, got ~D"
            (length place-value-pairs)))
    (let ((pairs (loop for (place value) on place-value-pairs by #'cddr
                       collect (cons place value))))
      (fol.compiler.ast:make-psetf-node
       :pairs pairs
       :form form))))

(defun parse-incf (form)
  "Parse (incf place &optional delta) — increment a place.
   FOL does not permit mutation via incf; the form is captured for a compiler error."
  (destructuring-bind (op place &optional delta) form
    (declare (ignore op))
    (fol.compiler.ast:make-incf-node
     :place place
     :delta delta
     :form form)))

(defun parse-decf (form)
  "Parse (decf place &optional delta) — decrement a place.
   FOL does not permit mutation via decf; the form is captured for a compiler error."
  (destructuring-bind (op place &optional delta) form
    (declare (ignore op))
    (fol.compiler.ast:make-decf-node
     :place place
     :delta delta
     :form form)))

(defun parse-pushnew (form)
  "Parse (pushnew item place &key test test-not key) — conditionally push onto a list.
   FOL does not permit mutation via pushnew; the form is captured for a compiler error."
  (destructuring-bind (op item place &rest keys) form
    (declare (ignore op))
    (fol.compiler.ast:make-pushnew-node
     :item item
     :place place
     :keys keys
     :form form)))

(defun parse-rotatef (form)
  "Parse (rotatef place ...) — rotate values among places.
   FOL does not permit mutation via rotatef; the form is captured for a compiler error."
  (destructuring-bind (op &rest places) form
    (declare (ignore op))
    (fol.compiler.ast:make-rotatef-node
     :places places
     :form form)))

(defun parse-shiftf (form)
  "Parse (shiftf place ... newval) — shift values left among places.
   FOL does not permit mutation via shiftf; the form is captured for a compiler error."
  (destructuring-bind (op &rest args) form
    (declare (ignore op))
    (when (< (length args) 2)
          (error "shiftf requires at least one place and a new value, got ~D argument(s)"
            (length args)))
    (fol.compiler.ast:make-shiftf-node
     :places (butlast args)
     :newval (car (last args))
     :form form)))

(defun parse-rplaca (form)
  "Parse (rplaca cons new-car) — destructively replaces the car of a cons cell.
   FOL does not permit mutation via rplaca; the form is captured for a compiler error."
  (destructuring-bind (op cons-form new-car) form
    (declare (ignore op))
    (fol.compiler.ast:make-rplaca-node
     :cons-form cons-form
     :new-car new-car
     :form form)))

(defun parse-rplacd (form)
  "Parse (rplacd cons new-cdr) — destructively replaces the cdr of a cons cell.
   FOL does not permit mutation via rplacd; the form is captured for a compiler error."
  (destructuring-bind (op cons-form new-cdr) form
    (declare (ignore op))
    (fol.compiler.ast:make-rplacd-node
     :cons-form cons-form
     :new-cdr new-cdr
     :form form)))

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

(defun parse-defpackage (form)
  "Parse (defpackage name option*).
   Options are collected as list elements beginning with keywords
   (e.g. (:use ...), (:export ...))."
  (destructuring-bind (op name &rest args) form
    (declare (ignore op))
    (let (options)
      (dolist (arg args)
        (when (and (consp arg)
                   (keywordp (car arg)))
              (push arg options)))
      (fol.compiler.ast:make-defpackage-node
       :name name
       :options (nreverse options)
       :form form))))

;;; --- Special form dispatch table ---

(let ((special-forms (make-hash-table :test 'equal)))
  (setf (gethash "IF" special-forms) #'parse-if)
  (setf (gethash "DO" special-forms) #'parse-do)
  (setf (gethash "BIND" special-forms) #'parse-bind)
  (setf (gethash "QUOTE" special-forms) #'parse-quote)
  (setf (gethash "FN" special-forms) #'parse-fn)
  (setf (gethash "Λ" special-forms) #'parse-fn) ; Λ/λ is an alias for fn
  ;; Threading forms with dynamic dispatch
  (setf (gethash "->" special-forms) #'parse-thread-first)
  (setf (gethash "->>" special-forms) #'parse-thread-last)
  (setf (gethash "VECTOR" special-forms) #'parse-vector)
  (setf (gethash "DICT" special-forms) #'parse-dict)
  (setf (gethash "SET" special-forms) #'parse-set)
  (setf (gethash "DEFMACRO" special-forms) #'parse-defmacro)
  (setf (gethash "DEFPACKAGE" special-forms) #'parse-defpackage)
  (setf (gethash "DEFCLASS" special-forms) #'parse-defclass)
  (setf (gethash "DEFSTRUCT" special-forms) #'parse-defstruct)
  (setf (gethash "DEFGENERIC" special-forms) #'parse-defgeneric)
  (setf (gethash "DEFMETHOD" special-forms) #'parse-defmethod)
  (setf (gethash "DEF" special-forms) #'parse-def)
  (setf (gethash "DEFN" special-forms) #'parse-defn)
  (setf (gethash "DEFUN" special-forms) #'parse-defun)
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
  (setf (gethash "SWAP!" special-forms) #'parse-swap!)
  (setf (gethash "COND" special-forms) #'parse-cond)
  ;; Now a macro: (setf (gethash "COND->" special-forms) #'parse-cond-thread-first)
  ;; Now a macro: (setf (gethash "COND->>" special-forms) #'parse-cond-thread-last)
  (setf (gethash "SYNTAX-QUOTE" special-forms) #'parse-syntax-quote)
  (setf (gethash "UNQUOTE" special-forms) #'parse-unquote)
  (setf (gethash "UNQUOTE-SPLICING" special-forms) #'parse-unquote-splicing)
  (setf (gethash "CASE" special-forms) #'parse-case)
  (setf (gethash "ENV" special-forms) #'parse-env)
  (setf (gethash "SETF" special-forms) #'parse-setf)
  (setf (gethash "SETQ" special-forms) #'parse-setq)
  ;; NOTE: "SET" is intentionally NOT re-registered here — (set ...) is the FOL
  ;; collection constructor, registered at line 1025 as parse-set.
  ;; Use (setq ...) or (setf ...) for CL-style mutation when needed.
  (setf (gethash "PSETQ" special-forms) #'parse-psetq)
  (setf (gethash "PSETF" special-forms) #'parse-psetf)
  (setf (gethash "INCF" special-forms) #'parse-incf)
  (setf (gethash "DECF" special-forms) #'parse-decf)
  (setf (gethash "PUSHNEW" special-forms) #'parse-pushnew)
  (setf (gethash "ROTATEF" special-forms) #'parse-rotatef)
  (setf (gethash "SHIFTF" special-forms) #'parse-shiftf)
  (setf (gethash "RPLACA" special-forms) #'parse-rplaca)
  (setf (gethash "RPLACD" special-forms) #'parse-rplacd)
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

(defvar *current-defn-name* nil
        "Name of the single-clause, simple-positional-params top-level function
   currently being emitted, or NIL (multi-clause functions, letfn bindings,
   and top-level non-defn forms leave this unbound). Paired with
   *CURRENT-DEFN-PARAM-INDEX*; together they let INFER-TYPE-FROM-EXPR
   (interprocedural-types.lisp) resolve a bare parameter reference inside
   the function body back to its interprocedurally-proven class, if any.
   Bound in EMIT-DEFN/EMIT-DEFN-PRIVATE/EMIT-DEFINLINE around their
   COMPILE-FN call.")

(defvar *current-defn-param-index* nil
        "Alist of (param-symbol . position-index) for *CURRENT-DEFN-NAME*'s
   positional parameters, or NIL. See *CURRENT-DEFN-NAME*.")

(defun %defn-context-param-index (clauses)
  "Alist of (param-symbol . index) when CLAUSES is a single clause with a
   flat, unspecialized positional parameter list (the same eligibility
   condition INFER-INTERPROCEDURAL-TYPES uses to track a function); NIL
   otherwise. Relies on %SR-PARAM-LIST/%SR-SYMBOL-LIST-P defined later in
   this file (forward reference to a plain function is fine in CL)."
  (when (= 1 (length clauses))
    (let ((params (%sr-param-list (car (first clauses)))))
      (when (%sr-symbol-list-p params)
        (loop for p in params for i from 0 collect (cons p i))))))

(defmacro %with-current-defn-context (name clauses &body body)
  "Bind *CURRENT-DEFN-NAME*/*CURRENT-DEFN-PARAM-INDEX* for BODY -- see
   *CURRENT-DEFN-NAME*. NAME and CLAUSES are each evaluated once."
  (let ((n (gensym "NAME")) (c (gensym "CLAUSES")))
    `(let* ((,n ,name) (,c ,clauses)
            (*current-defn-param-index* (%defn-context-param-index ,c))
            (*current-defn-name* (and *current-defn-param-index* ,n)))
       (declare (ignorable ,n))
       ,@body)))

(defvar *letfn-fns* nil
        "Set of function names bound in an enclosing letfn (CL labels) form.
   Calls to these names are emitted as direct function calls since labels
   puts them in the function slot, not the value slot.")

(defvar *extra-special-vars* nil
        "Set of symbols that should be declared SPECIAL in the current function scope.
   Used to silence warnings for dynamic variable usage and late-bound functions.")

(defvar *file-function-defs* nil
        "List of symbols defined as functions (defn/defgeneric) in the current compilation unit.
   Used by emit-symbol-ref to emit function-namespace references for Lisp-1 compatibility.
   Bound by compile-file; nil during individual compile-form calls.")

(defvar *sealed-classes* (make-hash-table :test 'equal)
        "Registry of sealed class names (upcased string → t).
   Populated by emit-defclass when a :sealed class is processed.
   Queried by emit-defclass to catch compile-time inheritance from sealed classes.")

;; Phase 2: Global type information registry
(defvar *global-type-info* (make-hash-table :test 'equal)
        "Compile-time registry mapping type-name → list of (keyword-key . slot-name) pairs.
   Built from defclass definitions. Used to optimize (get obj :key) when
   we can infer obj's type from constructor calls or type annotations.
   Example: (<op-add> → ((:left . left) (:right . right)))")

(defun infer-type-from-constructor (node)
  "Infer type from a constructor call node: either MAKE-<TYPE> literal-call
   syntax, or the (MAKE 'TYPE ...) EQL-specialized-generic call syntax.
   Returns the type name (symbol) if node is a constructor call, nil otherwise.
   Examples: (make-<op-add> :left ... :right ...) → <op-add>
             (make '<op-add> :left ... :right ...) → <op-add>"
  (when (and (fol.compiler.ast:call-node-p node)
             (fol.compiler.ast:symbol-ref-node-p (fol.compiler.ast:call-node-operator node)))
    (let* ((op-name (fol.compiler.ast:symbol-ref-node-name
                     (fol.compiler.ast:call-node-operator node)))
           (name-str (cl:symbol-name op-name))
           (args (fol.compiler.ast:call-node-args node)))
      (cond
        ;; Constructor name is make-<TYPE>, extract TYPE
        ((and (cl:>= (cl:length name-str) 5)
              (cl:string-equal (cl:subseq name-str 0 5) "MAKE-"))
         (let ((type-str (cl:subseq name-str 5)))
           (cl:intern type-str (cl:symbol-package op-name))))
        ;; (make 'TYPE ...) -- MAKE's own dispatch is EQL-specialized on the
        ;; class-name symbol, so a literal quoted symbol in operand position
        ;; is exactly as much a constructor call as MAKE-<TYPE> is.
        ((and (cl:string-equal name-str "MAKE")
              args
              (fol.compiler.ast:quote-node-p (first args))
              (cl:symbolp (fol.compiler.ast:quote-node-value (first args))))
         (fol.compiler.ast:quote-node-value (first args)))))))

(defun get-slot-name-for-type (type-name keyword-key)
  "Look up slot name for a given type and keyword key using global registry.
   Returns nil if type or key not found."
  (when (and type-name (keywordp keyword-key))
    (let ((slot-pairs (gethash type-name *global-type-info*)))
      (when slot-pairs
        (cl:assoc keyword-key slot-pairs :test #'eq)))))

(defun emit-literal (node)
  "Emit a literal value. Self-evaluating forms compile to themselves."
  (fol.compiler.ast:literal-node-value node))

(defun emit-symbol-ref (node)
  "Emit a symbol reference. Compiles to the CL symbol itself.
   Tracks non-lexical symbols for SPECIAL declarations.
   For symbols known to be function definitions (defn/defgeneric) in the
   current compilation unit, emits (cl:function name) for Lisp-1 compatibility."
  (let ((name (fol.compiler.ast:symbol-ref-node-name node)))
    (cond
     ;; Lexical variables: always in value namespace
     ((cl:member name *lexical-vars*)
       name)
     ;; Constants (T, NIL, keywords, etc.): self-evaluating
     ((cl:constantp name) name)
     ;; Known function def in current file: emit #'name for Lisp-1 compatibility
     ((cl:member name *file-function-defs* :test #'cl:string=)
       `(cl:function ,name))
     ;; Standard FOL functions (even if not currently loaded/fboundp)
     ((cl:member (cl:symbol-name name) +standard-fol-functions+ :test #'string-equal)
       `(cl:function ,name))
     ;; Globally defined function (from another module): emit #'name for Lisp-1 compatibility
     ((cl:fboundp name)
       `(cl:function ,name))
     ;; CL package symbols: use as-is
     ((cl:eq (cl:symbol-package name) (cl:find-package :cl))
       name)
     ;; Default: emit bare symbol (dynamic variable), track for SPECIAL declaration
     (t
       (pushnew name *extra-special-vars*)
       name))))

(defun %register-region-trusted-form (assumptions trust-checks)
  "Wrap FOL.COMPILER.WORLD:REGISTER-REGION with a live re-verification of
   TRUST-CHECKS -- a list of (KIND . USED-OPS) pairs, or NIL -- against
   FOL.COMPILER.ESCAPE-ANALYSIS:%KIND-TRUSTED-P. Returns the form to place
   inside the region's CL:LOAD-TIME-VALUE, so both the registration and the
   trust re-check happen at the same moment: load time.

   TRUSTED (the method-combination hazard check) was already run once, at
   compile time, to decide whether to attempt conversion at all -- but a
   :before/:after/:around method hijacking the representation, introduced
   after that compile-time check but before this form actually loads, is
   invisible to it: the snapshot is stale by the time load time arrives.
   It's also invisible to NOTE-REDEFINITION, since no redefinition event
   fires for a method that already existed. Re-running the same check here
   closes that gap: the compile-time check becomes an optimization (avoid
   emitting a dual path that would immediately register invalid), not the
   soundness gate -- this re-check is.

   No extra locking needed beyond REGISTER-REGION's own: the cell is
   already inserted into the world's dependency table by the time this
   runs, so a hijack racing with this exact moment is still caught by the
   ordinary NOTE-REDEFINITION path; this only needs to catch what predates
   registration entirely."
  (if trust-checks
      `(cl:let ((cell (fol.compiler.world:register-region ',assumptions)))
         (cl:when (cl:and (cl:car cell)
                          (cl:notevery
                           (cl:lambda (ko)
                             (fol.compiler.escape-analysis:%kind-trusted-p (cl:car ko) (cl:cdr ko)))
                           ',trust-checks))
           (cl:setf (cl:car cell) cl:nil))
         cell)
      `(fol.compiler.world:register-region ',assumptions)))

(defun emit-call (node)
  "Emit a function call node.
   Special cases:
   - (:keyword dict) => (get dict :keyword)  ; keyword as accessor
   - (lexical-var ...) => runtime dispatch: funcall if function, get if collection
   - (symbol ...) => normal call with runtime collection fallback"
  (multiple-value-bind (converted assumptions trust-checks)
      (fol.compiler.escape-analysis:maybe-transient-reduce node)
    (cond
      ((eq converted node) (emit-call-1 node))
      (fol.compiler.world:*sealed-world* (emit-node converted))
      (t `(cl:if (cl:car (cl:load-time-value
                          ,(%register-region-trusted-form assumptions trust-checks)
                          cl:t))
                 ,(emit-node converted)
                 ,(emit-call-1 node))))))

(defvar *dx-counter* 0)
(defvar *dx-suppress* nil
  "Bound while emitting the fallback branch of a dynamic-extent call, so the
   transform does not re-fire on the same node.")

(defun emit-dx-call (node)
  "Emit a call whose position-0 closure argument is stack-allocated, world-
   guarded against redefinition of the (non-retaining) callee:
   (if <cell> (let ((dx-fn (fn ...))) (declare (dynamic-extent dx-fn)) (op dx-fn ...))
              <original call>)"
  (let* ((args (fol.compiler.ast:call-node-args node))
         (op-name (symbol-name (fol.compiler.escape-analysis:operator-symbol node)))
         (tmp (intern (format nil "DX-FN-~D" (incf *dx-counter*))))
         ;; arg0 becomes a symbol ref, so dx-call-p cannot re-fire on this.
         (subst-node (fol.compiler.ast:make-call-node
                      :operator (fol.compiler.ast:call-node-operator node)
                      :args (cons (fol.compiler.ast:make-symbol-ref-node
                                   :name tmp :form tmp)
                                  (rest args))
                      :form (fol.compiler.ast:ast-node-form node)))
         (fn-code (emit-node (first args)))
         (opt `(cl:let ((,tmp ,fn-code))
                 (cl:declare (cl:dynamic-extent ,tmp))
                 ,(let ((*lexical-vars* (cons tmp *lexical-vars*)))
                    (emit-call-1 subst-node)))))
    (if fol.compiler.world:*sealed-world*
        opt
        `(cl:if (cl:car (cl:load-time-value
                         (fol.compiler.world:register-region '(,op-name))
                         cl:t))
                ,opt
                ,(let ((*dx-suppress* t)) (emit-call-1 node))))))

(defun emit-call-1 (node)
  "The original emit-call logic (see emit-call for the world-guard wrapper)."
  (when (and (not *dx-suppress*)
             (fol.compiler.escape-analysis:dx-call-p node))
    (return-from emit-call-1 (emit-dx-call node)))
  (let* ((operator (fol.compiler.ast:call-node-operator node))
         (args (fol.compiler.ast:call-node-args node)))
    (cond
     ;; Pattern: (:keyword dict) - keyword used as accessor function
     ;; This is unambiguous since keywords are never function names
     ;; Phase 2: Try to infer type and emit optimized slot-value if possible
     ((and (fol.compiler.ast:literal-node-p operator)
           (keywordp (fol.compiler.ast:literal-node-value operator))
           (= (length args) 1))
       (let ((keyword (fol.compiler.ast:literal-node-value operator))
             (dict-arg-node (first args))
             (dict-arg (emit-node (first args))))
         ;; Try to infer type: literal constructor call, or (interprocedurally)
         ;; a call/parameter whose class was proven from all its call sites.
         (let* ((inferred-type (infer-type-from-expr dict-arg-node))
                (slot-pair (when inferred-type
                             (get-slot-name-for-type inferred-type keyword)))
                (fallback `(fol.compiler.collection-functions:get ,dict-arg ,keyword)))
           (if slot-pair
               ;; World-guarded: the type proof may rest on other functions'
               ;; code (not just literal text right here), so guard the fast
               ;; path against INFERRED-TYPE being redefined at runtime.
               `(cl:if (cl:car (cl:load-time-value
                                (fol.compiler.world:register-region '(,(string inferred-type)))
                                cl:t))
                       (cl:slot-value ,dict-arg ',(cl:cdr slot-pair))
                       ,fallback)
               fallback))))

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
             ,@(when (cl:and emitted-args (cl:<= (cl:length emitted-args) 2))
                     `(((typep ,gop 'fol.compiler.collections:<dict>)
                        (fol.compiler.collection-functions:get ,gop ,@emitted-args))
                       ((typep ,gop 'fol.compiler.collections:<vector>)
                        (fol.compiler.collection-functions:nth ,gop ,@emitted-args))
                       ((typep ,gop 'fol.compiler.collections:<set>)
                        (fol.compiler.collection-functions:get ,gop ,@emitted-args))))
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
     ;; Special handling for assoc when inline-methods optimization is enabled
     ((fol.compiler.ast:symbol-ref-node-p operator)
       (let ((sym (fol.compiler.ast:symbol-ref-node-name operator))
             (emitted-args (mapcar #'emit-node args)))
         ;; Priority 0: constant-keyword `get` on a value of statically known
         ;; record type -> direct slot-value access, bypassing the generic
         ;; dict/vector dispatch entirely.
         (if (and (string= (symbol-name sym) "GET")
                  (= (length args) 2)
                  (fol.compiler.ast:literal-node-p (second args))
                  (keywordp (fol.compiler.ast:literal-node-value (second args))))
             (let* ((obj-node (first args))
                    (key (fol.compiler.ast:literal-node-value (second args)))
                    (inferred-type (infer-type-from-expr obj-node))
                    (slot-pair (when inferred-type
                                 (get-slot-name-for-type inferred-type key)))
                    (fallback `(fol.compiler.collection-functions:get ,@emitted-args)))
               (if slot-pair
                   ;; Optimization successful: emit direct slot-value,
                   ;; world-guarded since the proof may rest on other
                   ;; functions' code (see the (:keyword obj) branch above).
                   `(cl:if (cl:car (cl:load-time-value
                                    (fol.compiler.world:register-region '(,(string inferred-type)))
                                    cl:t))
                           (cl:slot-value ,(first emitted-args) ',(cdr slot-pair))
                           ,fallback)
                   fallback))
             ;; Priority 1: Check pragma-based inline-assoc! optimization
             (if (and (cl:string-equal (symbol-name sym) "ASSOC")
                      *inline-methods-enabled*
                      (cl:= (length emitted-args) 3))
                 ;; Use inline-assoc! for assoc calls when optimization is enabled
                 `(fol.compiler.collection-functions:inline-assoc! ,@emitted-args)
                 ;; Priority 2: Check for :around method optimization
                 (if (has-simple-around-methods-p sym)
                     ;; Use optimized dispatch for functions with simple :around methods
                     (emit-optimized-generic-call sym emitted-args)
                     ;; Normal emit-call path
                     (if (or (cl:member sym *file-function-defs* :test #'cl:string=)
                             (fboundp sym)
                             (cl:member (cl:symbol-name sym) +standard-fol-functions+ :test #'string-equal)
                             (eq (symbol-package sym) (find-package :cl)))
                         `(,sym ,@emitted-args)
                         (let ((gval (gensym "VAL")))
                           (pushnew sym *extra-special-vars*)
                           `(if (cl:fboundp ',sym)
                                (,sym ,@emitted-args)
                                (let ((,gval ,sym))
                                  (cl:cond
                                    ((cl:functionp ,gval) (cl:funcall ,gval ,@emitted-args))
                                    ,@(when (cl:and emitted-args (cl:<= (cl:length emitted-args) 2))
                                            `(((cl:typep ,gval 'fol.compiler.collections:<dict>)
                                               (fol.compiler.collection-functions:get ,gval ,@emitted-args))
                                              ((cl:typep ,gval 'fol.compiler.collections:<vector>)
                                               (fol.compiler.collection-functions:nth ,gval ,@emitted-args))
                                              ((cl:typep ,gval 'fol.compiler.collections:<set>)
                                               (fol.compiler.collection-functions:get ,gval ,@emitted-args))))
                                    (t (cl:error "~S is not a function or collection" ',sym))))))))))))

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
             (list* fn-name arg-expr extra-args)))))
        (*extra-special-vars* nil))
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
                    body-with-as))
               (body-with-special
                (if *extra-special-vars*
                    `((cl:declare (cl:special ,@(remove-duplicates *extra-special-vars*))) ,@body-with-ignore)
                    body-with-ignore)))
          `(cl:lambda ,lambda-list ,@body-with-special))))))

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
                collect `(,check
                           (cl:let ,bindings
                             ,@(let ((*lexical-vars* (append (mapcar #'car bindings) *lexical-vars*)))
                                 (mapcar #'emit-node body-nodes)))))))
    `(cl:lambda ,param-syms
       ,@(when *extra-special-vars*
               `((cl:declare (cl:special ,@(remove-duplicates *extra-special-vars*)))))
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
                collect `(,check
                           (cl:let ,bindings
                             ,@(let ((*lexical-vars* (append (mapcar #'car bindings) *lexical-vars*)))
                                 (mapcar #'emit-node body-nodes)))))))
    `(cl:lambda (&rest ,args-sym)
       ,@(when *extra-special-vars*
               `((cl:declare (cl:special ,@(remove-duplicates *extra-special-vars*)))))
       (cl:cond
         ,@cond-clauses
         (cl:t (cl:error "No matching fn clause for ~D arguments: ~S"
                 (cl:length ,args-sym) ,args-sym))))))

(defun emit-fn (node)
  "Emit a fn node as CL lambda.
   For named fns, wraps in labels for self-recursion.
   For unnamed multi-clause fns with fixed arity, applies dispatch caching."
  (let* ((name (fol.compiler.ast:fn-node-name node))
         (clauses (fol.compiler.ast:fn-node-clauses node))
         ;; AST-level analysis (robust, format-independent)
         (cache-mode (cacheable-clauses-p clauses))
         ;; Compile regardless (needed for emit)
         (lambda-form (compile-fn clauses))
         ;; Fallback: post-compile check catches edge cases
         (cache-mode (or cache-mode (cacheable-defn-p lambda-form))))
    (if name
        ;; Named fn: wrap in labels for self-reference
        (let ((params (second lambda-form))
              (body (cddr lambda-form)))
          `(cl:labels ((,name ,params ,@body))
             #',name))
        ;; Unnamed fn: apply caching if possible
        (if cache-mode
            (make-cached-fn lambda-form cache-mode)
            lambda-form))))

;;; ---------------------------------------------------------------------------
;;; Priority 3: Transient Accumulation - Detect and optimize update chains
;;; ---------------------------------------------------------------------------
;;; DISABLED PENDING IMPLEMENTATION FIXES
;;; The optimization structure is in place but needs careful pattern detection

(defun emit-thread-first (node)
  "Emit a thread-first node by expanding into nested function calls with dynamic dispatch.
   (-> x f)           => (if (fboundp 'f) (f x) (let ((val f)) ...))
   (-> x (f a))       => (f x a)
   (-> x (f a) (g b)) => (g (f x a) b)

   Priority 3: Detect accumulation chains and use transients for efficiency.
   (-> dict (assoc :a 1) (assoc :b 2)) => uses transient accumulation
   Each form threads the accumulated value as the first argument."
  (let* ((forms (fol.compiler.ast:thread-first-node-forms node))
         (initial (emit-node (first forms)))
         (threading-forms (rest forms)))
    (if (null threading-forms)
        initial
        ;; Standard thread-first (Priority 3 transient accumulation disabled pending fixes)
        (reduce (lambda (acc form-node)
                        (let ((emitted (emit-node form-node)))
                          (cond
                           ;; Bare symbol or (cl:function name): call with accumulated value, with dynamic dispatch
                           ((or (symbolp emitted)
                                (and (listp emitted) (eq (first emitted) 'cl:function)))
                             (let ((gval (gensym "VAL"))
                                   (sym (if (symbolp emitted) emitted (second emitted))))
                               (pushnew sym *extra-special-vars*)
                               `(if (cl:fboundp ',sym)
                                    (,sym ,acc)
                                    (let ((,gval ,sym))
                                      (cl:cond
                                        ((cl:functionp ,gval) (cl:funcall ,gval ,acc))
                                        ((cl:typep ,gval 'fol.compiler.collections:<dict>)
                                         (fol.compiler.collection-functions:get ,gval ,acc))
                                        ((cl:typep ,gval 'fol.compiler.collections:<vector>)
                                         (fol.compiler.collection-functions:nth ,gval ,acc))
                                        (t (cl:error "Value ~S is not callable or a collection" ,gval)))))))
                           ;; List form (f args...) not matching (cl:function ...): insert accumulated as first arg
                           ((listp emitted)
                             `(,(first emitted) ,acc ,@(rest emitted)))
                           ;; Anything else: treat as function call
                           (t `(funcall ,emitted ,acc)))))
                threading-forms
              :initial-value initial))))


(defun emit-thread-last (node)
  "Emit a thread-last node by expanding into nested function calls with dynamic dispatch.
   (->> x f)           => (if (fboundp 'f) (f x) (let ((val f)) ...))
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
                     ;; Bare symbol or (cl:function name): call with accumulated value, with dynamic dispatch
                     ((or (symbolp emitted)
                          (and (listp emitted) (eq (first emitted) 'cl:function)))
                       (let ((gval (gensym "VAL"))
                             (sym (if (symbolp emitted) emitted (second emitted))))
                         (pushnew sym *extra-special-vars*)
                         `(if (cl:fboundp ',sym)
                              (,sym ,acc)
                              (let ((,gval ,sym))
                                (cl:cond
                                  ((cl:functionp ,gval) (cl:funcall ,gval ,acc))
                                  ((cl:typep ,gval 'fol.compiler.collections:<dict>)
                                   (fol.compiler.collection-functions:get ,gval ,acc))
                                  ((cl:typep ,gval 'fol.compiler.collections:<vector>)
                                   (fol.compiler.collection-functions:nth ,gval ,acc))
                                  (t (cl:error "Value ~S is not callable or a collection" ,gval)))))))
                     ;; List form (f args...) not matching (cl:function ...): append accumulated as last arg
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
         (lambda-form (%with-current-defn-context name clauses
                        (compile-fn clauses))))
    (let ((params (second lambda-form))
          (body (cddr lambda-form)))
      `(cl:defun ,name ,params ,@body))))

(defun emit-definline (node)
  "Emit a definline node as (progn (declaim (inline name)) (defun name ...)).
   Declares the function inline before defining it."
  (let* ((name (fol.compiler.ast:definline-node-name node))
         (clauses (fol.compiler.ast:definline-node-clauses node))
         (lambda-form (%with-current-defn-context name clauses
                        (compile-fn clauses))))
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
   Uses emit-macro-lambda-list for FOL-to-CL lambda list conversion.
   Also emits metadata setting code if docstring is present.

   Also registers the macro with FOL's own parser-level macro table
   (REGISTER-MACRO, the same registry macros.lisp uses for built-ins like
   COND-> and WHEN) so that PARSE-COMPOUND's macro-first check picks it up
   for later forms too: without this, a user's own DEFMACRO produces a
   real CL macro, but one invisible to every FOL-AST-level pass (scalar
   replacement among them) until SBCL itself macroexpands the final
   emitted code, by which point those passes have already run and seen
   only an opaque, unrecognized call-node. EVAL-WHEN covers both the
   sequential parse-compile-eval-per-form model this compiler actually
   uses and a batch COMPILE-FILE-then-LOAD path, where a later top-level
   form in the same file is parsed (and needs the registration) during
   compilation, before the FASL is ever loaded."
  (let* ((name (fol.compiler.ast:defmacro-node-name node))
         (params (fol.compiler.ast:defmacro-node-params node))
         (body (fol.compiler.ast:defmacro-node-body node))
         (docstring (fol.compiler.ast:defmacro-node-docstring node))
         (param-list (fol-vector-to-list params))
         (cl-lambda-list (fol.compiler.destructure:emit-macro-lambda-list param-list))
         (emitted-body (mapcar #'emit-node body)))
    (let ((defmacro-form `(cl:defmacro ,name ,cl-lambda-list ,@emitted-body))
          (register-form `(cl:eval-when (:compile-toplevel :load-toplevel :execute)
                             (fol.compiler:register-macro ',name (cl:macro-function ',name))))
          (metadata-form (when docstring
                               `(fol.compiler.metadata:alter-meta! (quote ,name)
                                                                   (fn [m] (fol.compiler.collection-functions:merge m
                                                                                                                    (fol.compiler.collection-functions:dict
                                                                                                                     :doc ,docstring
                                                                                                                     :name (quote ,name))))))))
      `(cl:progn ,defmacro-form ,register-form ,@(when metadata-form (list metadata-form))))))

(defun emit-initform (value)
  "Convert a FOL initform value to a CL form that produces it.
   FOL collections from the reader need constructor calls since they
   cannot be printed readably in standard CL syntax."
  (cond
   ((typep value 'fol.compiler.collections:<vector>)
     (let ((elts (fol.compiler.collections:collection-seq value)))
       `(fol.compiler.collection-functions:vector ,@elts)))
   ((typep value 'fol.compiler.collections:<dict>)
     (let ((pairs nil))
       (dolist (entry (fol.compiler.collections:collection-seq value))
         (push (cdr entry) pairs)
         (push (car entry) pairs))
       `(fol.compiler.collection-functions:dict ,@pairs)))
   ((typep value 'fol.compiler.collections:<set>)
     (let ((elts (fol.compiler.collections:collection-seq value)))
       `(fol.compiler.collection-functions:set ,@elts)))
   (t value)))

(defun emit-slot-spec (slot-spec)
  "Process a slot-spec, converting FOL collection initforms to CL constructor forms."
  (let ((initform-pos (position :initform slot-spec)))
    (if (and initform-pos (< (1+ initform-pos) (length slot-spec)))
        (let* ((initform-val (nth (1+ initform-pos) slot-spec))
               (emitted (emit-initform initform-val)))
          (if (eq emitted initform-val)
              slot-spec
              (let ((result (copy-list slot-spec)))
                (setf (nth (1+ initform-pos) result) emitted)
                result)))
        slot-spec)))

(defun emit-defclass (node)
  "Emit a defclass node as CL defclass with persistent object support.
   All FOL classes inherit from <persistent-object> and use the persistent-class metaclass.
   Also emits a make-<name> convenience constructor.

   :abstract — emits an initialize-instance :before method that signals a runtime error
               when the class is instantiated directly (not via a subclass).
   :sealed   — registers the class in *sealed-classes* and signals a compile-time error
               if it appears as a superclass anywhere."
  (let* ((name (fol.compiler.ast:defclass-node-name node))
         (supers (fol.compiler.ast:defclass-node-superclasses node))
         (slots (fol.compiler.ast:defclass-node-slots node))
         (abstractp (fol.compiler.ast:defclass-node-abstractp node))
         (sealedp (fol.compiler.ast:defclass-node-sealedp node))
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
                  (append supers '(fol.compiler.persistent:<persistent-object>))))))
    ;; Compile-time sealed check: error if any superclass is sealed.
    (dolist (super supers)
      (when (and super (gethash (symbol-name super) *sealed-classes*))
            (cl:error "Compiler error: ~A inherits from sealed class ~A. ~
                   Sealed classes cannot appear in an inheritance chain."
              name super)))
    ;; Register this class as sealed so future subclasses are caught.
    (when sealedp
          (setf (gethash (symbol-name name) *sealed-classes*) t))
    (let* (;; Build constructor name: make-<classname>
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
           ;; Ensure each slot has an :initarg (defaulting to keyword name)
           (clean-slots
            (loop for slot in slots
                  for slot-spec = (if (listp slot) (copy-list slot) (list slot))
                  for sname = (car slot-spec)
                  for final-spec = (if (getf (cdr slot-spec) :initarg)
                                       slot-spec
                                       (append slot-spec (list :initarg (intern (string sname) :keyword))))
                  for processed = (emit-slot-spec
                                   (let ((result (copy-list final-spec)))
                                     (remf (cdr result) :accessor)
                                     result))
                  collect processed)))
      ;; World-guard integration: a redefinition of this class must
      ;; invalidate any function that assumed its old shape -- scalar
      ;; replacement (fields unboxed at compile time) or the interprocedural
      ;; GET-bypass (compiler.lisp EMIT-CALL-1, ~line 1550/1620, guarded via
      ;; REGISTER-REGION regardless of *SCALAR-REPLACEMENT*). Only fires when
      ;; NAME already has a *GLOBAL-TYPE-INFO* entry, i.e. this is a genuine
      ;; redefinition, not NAME's first DEFCLASS -- nothing could have
      ;; assumed a shape for a class that didn't exist yet, and callers of
      ;; WORLD-STATS (tests, diagnostics) treat :REDEFINITIONS-NOTED as
      ;; counting real redefinitions.
      (when (and (gethash name *global-type-info*)
                 (not fol.compiler.world:*sealed-world*))
        (fol.compiler.world:note-redefinition name))

      ;; Phase 2: Populate global type info registry for this type
      (let ((slot-pairs (loop for (slot-name initarg accessor storage-key) in slot-infos
                              collect (cons storage-key slot-name))))
        (setf (gethash name *global-type-info*) slot-pairs))
      `(cl:progn
         (cl:defclass ,name ,effective-supers
           ,clean-slots
           (:metaclass fol.compiler.persistent:persistent-class))
         ,@(loop for (sname initarg accessor storage-key) in slot-infos
                   when accessor
                 collect `(cl:defun ,accessor (object)
                            (cl:slot-value object ',sname)))
         ;; Abstract guard: prevent direct make-instance calls from CL code.
         ,@(when abstractp
                 `((cl:defmethod cl:initialize-instance :before ((obj ,name) &rest args)
                     (cl:declare (cl:ignore args))
                     (cl:when (cl:eq (cl:class-of obj) (cl:find-class ',name))
                       (cl:error "Cannot instantiate abstract class ~A" ',name)))))
         ;; Constructor — abstract classes always error; concrete classes use %make-persistent
         ;; fast path. The new implementation generates a &key constructor which is
         ;; much faster than the old &rest version that had to parse keywords at runtime.
         ,(if abstractp
              `(cl:defun ,constructor-name (&rest %ctor-args)
                 (cl:declare (cl:ignore %ctor-args))
                 (cl:error "Cannot instantiate abstract class ~A" ',name))
              (if *optimize-constructors*
                  ;; Optimized path: &key constructor with direct slot-filling.
                  ;; Slot names are known at compile time here, so this skips
                  ;; %make-persistent's keyword->slot-name lookup, but it must
                  ;; otherwise match %make-persistent exactly: direct
                  ;; (setf slot-value) on a native persistent slot is
                  ;; intercepted by a guard that requires either
                  ;; *initializing-persistent-object* bound, or checks
                  ;; %transient-owner -- unbound on a bare allocate-instance,
                  ;; so it must be explicitly initialized here rather than
                  ;; left to a slot initform (allocate-instance runs no
                  ;; initforms) -- and %schema-version is read by slot access
                  ;; / live-redefinition checks. Skipping either would error
                  ;; or silently corrupt objects from this path.
                  `(cl:defun ,constructor-name (&key ,@(loop for (sname initarg) in slot-infos
                                                             collect `(,sname nil)))
                     (cl:let ((%cls (cl:load-time-value (cl:find-class ',name))))
                       ;; Overflow (wide, >+native-slot-limit+ TOTAL slots including
                       ;; inherited ones -- not knowable from this defclass's own
                       ;; SLOT-INFOS alone) classes need the persistent-vector trie
                       ;; batch-built by the standard INITIALIZE-INSTANCE :AFTER
                       ;; method (persistence.lisp); the hand-rolled fast path below
                       ;; only fills native CLOS slots; a slot beyond the native
                       ;; limit routes through SLOT-MISSING's SETF clause, which
                       ;; needs %PERSISTENT-VECTOR to already be a real (even if
                       ;; empty) vector, not just NIL. Rather than duplicate that
                       ;; machinery here, wide classes fall back to MAKE-INSTANCE.
                       ;; PERSISTENT-CLASS-SLOT-COUNT is only populated by
                       ;; COMPUTE-SLOTS, which runs at class finalization -- not
                       ;; guaranteed yet on this constructor's very first call
                       ;; (FIND-CLASS alone doesn't finalize), so finalize first;
                       ;; ENSURE-FINALIZED is a cheap no-op once already finalized.
                       (closer-mop:ensure-finalized %cls)
                       (cl:if (cl:> (fol.compiler.persistent::persistent-class-slot-count %cls)
                                    fol.compiler.persistent::+native-slot-limit+)
                              (cl:make-instance %cls
                                ,@(loop for (sname initarg) in slot-infos
                                        append (list initarg sname)))
                              (cl:let ((obj (cl:allocate-instance %cls)))
                                (cl:let ((fol.compiler.persistent::*initializing-persistent-object* cl:t))
                                  ;; Must run BEFORE the slot-filling forms, not after:
                                  ;; direct (setf slot-value) on a native persistent
                                  ;; slot is intercepted by a guard that requires either
                                  ;; *initializing-persistent-object* bound, or checks
                                  ;; %transient-owner -- unbound on a bare
                                  ;; allocate-instance, so it must be explicitly
                                  ;; initialized here rather than left to a slot
                                  ;; initform (allocate-instance runs no initforms) --
                                  ;; and %schema-version is read by slot access /
                                  ;; live-redefinition checks. Skipping either would
                                  ;; error or silently corrupt objects from this path.
                                  (cl:setf (fol.compiler.persistent::%transient-owner obj) cl:nil)
                                  (cl:setf (fol.compiler.persistent::%schema-version obj)
                                           (fol.compiler.persistent::persistent-class-version-counter %cls))
                                  ,@(loop for (sname initarg) in slot-infos
                                          collect `(cl:setf (cl:slot-value obj ',sname) ,sname)))
                                obj))))
                  ;; Fallback path: original &rest constructor
                  `(cl:defun ,constructor-name (&rest %ctor-args)
                     (cl:apply #'fol.compiler.persistent::%make-persistent
                               (cl:load-time-value (cl:find-class ',name))
                               %ctor-args))))
         ',name))))

(defun emit-defstruct (node)
  "Emit a defstruct node as a persistent defclass with slot accessor methods and a make method.
   Slot syntax: bare symbol for no default, or (name :default val) for an initform.
   For each slot, emits a (defmethod get ((obj <name>) (key (eql :slot)) &optional default))
   so that (:slot obj) dispatch is type-specific.
   Constructor is (defmethod make ((class (eql '<name>)) &rest args)) forwarding to make-instance;
   initforms on the defclass handle default slot values."
  (let* ((name (fol.compiler.ast:defstruct-node-name node))
         (slots (fol.compiler.ast:defstruct-node-slots node))
         ;; Parse each slot into (slot-name storage-key default has-default)
         (slot-infos
          (loop for slot in slots
                for slot-spec = (if (listp slot) slot (list slot))
                for slot-name = (first slot-spec)
                for has-default = (member :default (rest slot-spec))
                for default = (when has-default (second has-default))
                for storage-key = (intern (string slot-name) :keyword)
                collect (list slot-name storage-key default has-default)))
         ;; CL defclass slot specs: (slot-name :initarg :slot-name [:initform default])
         (cl-slot-specs
          (loop for (sname storage-key default has-default) in slot-infos
                collect (if has-default
                            `(,sname :initarg ,storage-key
                               :initform ,(emit-initform default))
                            `(,sname :initarg ,storage-key)))))
    `(cl:progn
       (cl:defclass ,name (fol.compiler.persistent:<persistent-object>)
         ,cl-slot-specs
         (:metaclass fol.compiler.persistent:persistent-class))
       ;; Per-slot get methods: (:slot obj) dispatches here for type-specific access
       ,@(loop for (sname storage-key default has-default) in slot-infos
               collect `(cl:defmethod fol.compiler.collection-functions:get
                          ((obj ,name) (key (cl:eql ,storage-key)) &optional default)
                          (cl:declare (cl:ignore key default))
                          (cl:slot-value obj ',sname)))
       ;; Constructor via make generic: (make '<name> :slot val ...)
       (cl:defmethod fol.compiler.primitives:make ((class (cl:eql ',name)) &rest args)
         (cl:apply #'cl:make-instance ',name args))
       ',name)))

(defun emit-defgeneric (node)
  "Emit a defgeneric node as CL defgeneric.
   Single-pattern: (defgeneric name (params) options...)
   Multi-pattern: creates internal generics + dispatcher function.
   Also emits metadata setting code if docstring is present."
  (let ((name (fol.compiler.ast:defgeneric-node-name node))
        (lambda-lists (fol.compiler.ast:defgeneric-node-lambda-lists node))
        (options (fol.compiler.ast:defgeneric-node-options node))
        (docstring (fol.compiler.ast:defgeneric-node-docstring node)))
    ;; Track this function for Lisp-1 compatibility in compile-file
    (when *file-function-defs*
          (pushnew name *file-function-defs* :test #'string=))
    (let ((defgeneric-form
           (if (= (length lambda-lists) 1)
               ;; Single pattern
               (let ((params (fol.compiler.destructure:strip-specializers (first lambda-lists))))
                 `(cl:defgeneric ,name ,params ,@options))
               ;; Multi-pattern: create internal generics + dispatcher
               (emit-defgeneric-multi-pattern name lambda-lists options)))
          (metadata-form (when docstring
                               `(fol.compiler.metadata:alter-meta! (quote ,name)
                                                                   (fn [m] (fol.compiler.collection-functions:merge m
                                                                                                                    (fol.compiler.collection-functions:dict
                                                                                                                     :doc ,docstring
                                                                                                                     :arglists ,(list 'quote lambda-lists)
                                                                                                                     :name (quote ,name))))))))
      (if metadata-form
          `(cl:progn ,defgeneric-form ,metadata-form)
          defgeneric-form))))

;;; Defgeneric Multi-Pattern Caching Helpers

(defun cacheable-defgeneric-p (lambda-lists)
  "Dispatch caching disabled: benchmarks showed it slowed performance."
  (declare (ignore lambda-lists))
  nil)

(defun make-cached-defgeneric-dispatcher (name patterns-by-arity dispatcher-cases)
  "Wrap the dispatcher with cache logic using compound (arity . class-tuple) keys.
   Returns a modified dispatcher form that caches dispatch decisions."
  (let ((cache-name (intern (format nil "%-~A-GF-DISPATCH-CACHE" (symbol-name name))
                            (symbol-package name)))
        (key-sym (gensym "KEY"))
        (hit-sym (gensym "HIT"))
        (args-sym 'args))
    `(cl:progn
       ;; Create and register the cache
       (cl:defparameter ,cache-name (fol.compiler.dispatch:make-dispatch-cache))
       (fol.compiler.dispatch:register-gf-cache! ',name ,cache-name)
       ;; Modified dispatcher with cache lookup
       (cl:defun ,name (&rest ,args-sym)
         (cl:let* ((,key-sym (cl:cons (cl:length ,args-sym)
                                      (cl:mapcar #'cl:class-of ,args-sym)))
                   (,hit-sym (gethash ,key-sym (fol.compiler.dispatch:dispatch-cache-table ,cache-name))))
           (cl:if ,hit-sym
               ;; Cache hit: apply cached function directly
               (cl:apply ,hit-sym ,args-sym)
               ;; Cache miss: dispatch normally and cache result
               ,(wrap-dispatcher-with-cache dispatcher-cases cache-name key-sym args-sym)))))))

(defun wrap-dispatcher-with-cache (dispatcher-cases cache-name key-sym args-sym)
  "Wrap the original dispatcher case/cond to insert cache on each matched path.
   Returns modified dispatcher that caches the winning generic on miss."
  (let ((new-cases
         (loop for case-item in dispatcher-cases
               for arity = (first case-item)
               for body = (rest case-item)
               collect
               (if (= (length body) 1)
                   ;; Single form in body
                   (let* ((original-form (first body))
                          (wrapped (wrap-form-with-cache original-form cache-name key-sym args-sym)))
                     `(,arity ,wrapped))
                   ;; Multiple forms in body
                   (let* ((init-forms (butlast body))
                          (final-form (car (last body)))
                          (wrapped-final (wrap-form-with-cache final-form cache-name key-sym args-sym)))
                     `(,arity ,@init-forms ,wrapped-final))))))
    `(cl:case (cl:length ,args-sym)
       ,@new-cases)))

(defun wrap-form-with-cache (form cache-name key-sym args-sym)
  "Wrap a single form with cache insertion if it's an apply.
   Returns the wrapped or original form."
  (if (and (consp form)
           (eq (first form) 'apply)
           (consp (second form))
           (eq (first (second form)) 'cl:quote))
      ;; Form is (apply #'FUNCNAME args) - cache the function
      (let ((fn-name (second (second form))))
        `(cl:progn
           (setf (gethash ,key-sym (fol.compiler.dispatch:dispatch-cache-table ,cache-name)) #',fn-name)
           ,form))
      ;; Form is something else (maybe COND) - wrap if COND
      (if (and (consp form) (eq (first form) 'cond))
          (wrap-cond-for-generic-cache form cache-name key-sym args-sym)
          form)))

(defun wrap-cond-for-generic-cache (cond-form cache-name key-sym args-sym)
  "Wrap COND clauses to cache the winning internal generic on dispatch match."
  (let* ((clauses (rest cond-form))
         (fallback (car (last clauses)))
         (non-fallback (butlast clauses)))
    `(cl:cond
       ,@(loop for clause in non-fallback
               collect
               (let ((condition (first clause))
                     (body (rest clause)))
                 `(,condition
                   ;; Extract function from (apply #'FUNCNAME args) and cache it
                   ,(if (and (= (length body) 1)
                             (consp (first body))
                             (eq (first (first body)) 'apply)
                             (consp (second (first body)))
                             (eq (first (second (first body))) 'cl:quote))
                        (let ((fn-name (second (second (first body)))))
                          `(cl:progn
                             (setf (gethash ,key-sym (fol.compiler.dispatch:dispatch-cache-table ,cache-name)) #',fn-name)
                             ,(first body)))
                        (first body)))))
       ,fallback)))

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
    ;; Apply caching if enough distinct patterns
    (let ((base-dispatcher
           `(cl:progn
              ,@generic-defs
              (cl:defun ,name (&rest args)
                (cl:case (length args)
                  ,@dispatcher-cases
                  (t (error "No matching arity ~A for ~A"
                       (length args) ',name))))
              ',name)))
      (if (cacheable-defgeneric-p lambda-lists)
          ;; Wrap with caching
          `(cl:progn
             ,@generic-defs
             ,(make-cached-defgeneric-dispatcher name patterns-by-arity dispatcher-cases)
             ',name)
          ;; No caching
          base-dispatcher))))

(defvar *method-preferences* (make-hash-table :test 'eq))

(defun creates-cycle-p (gf-name sub pref)
  (let* ((prefs-for-gf (gethash gf-name *method-preferences*))
         (visited (make-hash-table :test 'eq)))
    (labels ((visit (node)
               (when (eq node sub)
                 (return-from creates-cycle-p t))
               (unless (gethash node visited)
                 (setf (gethash node visited) t)
                 (when prefs-for-gf
                   (dolist (parent (gethash node prefs-for-gf))
                     (visit parent))))))
      (when prefs-for-gf
        (dolist (parent (gethash pref prefs-for-gf))
          (visit parent)))
      nil)))

(defun prefer-method (gf-name pref-qualifier sub-qualifier)
  "Establish a preference between two method clauses for a generic function.
   Raises a program-error at load time if creating this preference creates a cycle."
  (when (creates-cycle-p gf-name sub-qualifier pref-qualifier)
    (error 'program-error :format-control "Circular preference: ~A prefers ~A over ~A, which creates a cycle." :format-arguments (list gf-name pref-qualifier sub-qualifier)))
  (let ((prefs-for-gf (or (gethash gf-name *method-preferences*)
                          (setf (gethash gf-name *method-preferences*) (make-hash-table :test 'eq)))))
    (pushnew pref-qualifier (gethash sub-qualifier prefs-for-gf))
    gf-name))

(defun compile-defmethod-clauses (name clauses &optional qualifier)
  "Compile defmethod clauses into a dispatched defmethod.
   Uses the same arity+specificity ordering as compile-fn-multi-clause.
   When all clauses share the same arity and none have rest params,
   emits a fixed-arity defmethod to avoid &rest consing overhead.
   Uses consistent parameter names across clauses when possible to avoid
   unnecessary gensyms and LET bindings (Bug #4 fix).
   QUALIFIER (:around/:before/:after) is forwarded to the emitted defmethod."
  (let* ((*extra-special-vars* nil)
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
               (all-signatures (mapcar (lambda (c) (getf c :signature)) sorted))
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
               ;; A position can carry a real CLOS specializer -- rather than
               ;; collapsing to an implicit T and enforcing the type via a
               ;; runtime COND check -- when every clause names the same bare
               ;; parameter there AND every clause's signature there is an
               ;; identical (:type ClassName). This keeps CLOS specializers
               ;; visible to MOP-based introspection (e.g. escape-analysis's
               ;; Trusted/tier1-op-customized-p hazard check) for the common
               ;; case of a type-specialized parameter that shares a clause
               ;; with an EQL/guard/predicate specializer on another
               ;; parameter, instead of every position silently becoming T
               ;; the moment any parameter in the clause needs a runtime
               ;; check. Positions where clauses disagree on type, or that
               ;; use a non-type pattern, are unaffected and still dispatch
               ;; via the COND below exactly as before.
               (clos-specializer-classes
                (loop for i below uniform-arity
                      for names-at-pos = (mapcar (lambda (stripped) (nth i stripped))
                                             all-stripped)
                      for sigs-at-pos = (mapcar (lambda (sig) (nth i sig)) all-signatures)
                      for shared-sym-p = (and (every #'symbolp names-at-pos)
                                               (every (lambda (n) (eq n (first names-at-pos)))
                                                   names-at-pos))
                      for uniform-type-p = (and (every (lambda (s) (eq (first s) :type)) sigs-at-pos)
                                                 (every (lambda (s)
                                                          (string= (symbol-name (second s))
                                                                   (symbol-name (second (first sigs-at-pos)))))
                                                     sigs-at-pos))
                      collect (and shared-sym-p uniform-type-p (second (first sigs-at-pos)))))
               (cond-clauses
                (loop for c in sorted
                      for signature = (getf c :signature)
                      for stripped = (getf c :stripped)
                      for body-nodes = (getf c :body-nodes)
                        ;; Positions already enforced by a CLOS specializer need
                        ;; no runtime check; treat them as :any for the COND.
                      for checked-signature = (loop for sig in signature
                                                    for cls in clos-specializer-classes
                                                    collect (if cls (list :any) sig))
                      for base-check = (fol.compiler.destructure:emit-fixed-arity-pattern-check
                                        checked-signature param-syms)
                        ;; Include inner dict predicate checks (e.g. nested :keys eql patterns)
                        ;; Priority 2: Extract type from signature for type-aware optimization
                      for inner-checks = (loop for param in stripped
                                               for sym in param-syms
                                               for sig in signature
                                               for param-type = (when (and (listp sig) (eq (first sig) :type))
                                                                  (second sig))
                                               append (fol.compiler.destructure:emit-stripped-param-inner-predicates
                                                       param sym param-type))
                      for check = (if inner-checks
                                      `(cl:and ,base-check ,@inner-checks)
                                      base-check)
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
                                       `((cl:let* ,bindings ,@emitted-body))
                                       emitted-body)))))
          (let* ((variadic-p (member (symbol-name name) '("ASSOC" "DISSOC" "CONJ" "MERGE" "LIST" "LIST*" "VECTOR" "DICT" "SET") :test #'string-equal))
                 (rest-sym (when variadic-p (cl:gensym "REST")))
                 (specialized-params
                  (loop for sym in param-syms
                        for cls in clos-specializer-classes
                        collect (if cls (list sym cls) sym)))
                 (final-lambda-list (if variadic-p (append specialized-params (list '&rest rest-sym)) specialized-params)))
            `(cl:defmethod ,name ,@(when qualifier (list qualifier)) ,final-lambda-list
               ,@(when variadic-p `((cl:declare (cl:ignore ,rest-sym))))
               ,@(when *extra-special-vars*
                       `((cl:declare (cl:special ,@(remove-duplicates *extra-special-vars*)))))
               (cl:cond
                 ,@cond-clauses
                 ,@(if (member qualifier '(:around :before :after))
                       `((t (cl:call-next-method)))
                       `((t (cl:error "No matching method clause for ~A with arguments: ~S"
                              ',name (cl:list ,@param-syms)))))))))
        ;; &rest path for mixed arities
        (let* ((args-sym (cl:gensym "ARGS"))
               (cond-clauses
                (loop for c in sorted
                      for arity = (getf c :arity)
                      for has-rest = (getf c :has-rest)
                      for signature = (getf c :signature)
                      for stripped = (getf c :stripped)
                      for rest-param = (getf c :rest-param)
                      for body-nodes = (getf c :body-nodes)
                      for base-check = (fol.compiler.destructure:emit-clause-pattern-check
                                        signature arity has-rest args-sym)
                      for inner-checks = (loop for param in stripped
                                               for i from 0
                                               for sig in signature
                                               for param-type = (when (and (listp sig) (eq (first sig) :type))
                                                                  (second sig))
                                               append (fol.compiler.destructure:emit-stripped-param-inner-predicates
                                                       param `(nth ,i ,args-sym) param-type))
                      for check = (if inner-checks
                                      `(cl:and ,base-check ,@inner-checks)
                                      base-check)
                      for bindings = (cl:append
                                       (fol.compiler.destructure:emit-param-bindings
                                        stripped args-sym)
                                       (fol.compiler.destructure:emit-rest-param-binding
                                        rest-param arity args-sym))
                      for emitted-body = (mapcar #'emit-node body-nodes)
                      collect `(,check
                                 (cl:let* ,bindings
                                   ,@emitted-body)))))
          `(cl:defmethod ,name ,@(when qualifier (list qualifier)) (&rest ,args-sym)
             ,@(when *extra-special-vars*
                     `((cl:declare (cl:special ,@(remove-duplicates *extra-special-vars*)))))
             (cl:cond
               ,@cond-clauses
               ,@(if (member qualifier '(:around :before :after))
                     `((t (cl:apply #'cl:call-next-method ,args-sym)))
                     `((t (cl:error "No matching method clause for ~A with ~D arguments: ~S"
                            ',name (cl:length ,args-sym) ,args-sym))))))))))

;;; Dispatch Cache Constant (needed by method caching helpers)

(defconstant +dispatch-cache-threshold+ 4)

;;; Method Caching Helpers

(defvar *method-cache-counter* 0
  "Monotonically increasing counter for unique defmethod cache variable naming.")

(defun cacheable-method-p (method-form)
  "Dispatch caching disabled: benchmarks showed it slowed performance."
  (declare (ignore method-form))
  nil)

(defun make-cached-method (name method-form)
  "Transform a defmethod form with COND body into a cached dispatcher.
   Extracts COND, wraps it with cache lookup/insert, returns modified defmethod."
  (let* ((rest (cddr method-form))
         (has-qualifier (keywordp (first rest)))
         (qualifier (when has-qualifier (first rest)))
         (rest (if has-qualifier (cdr rest) rest))
         (ll (first rest))
         (body (cdr rest))
         ;; Extract COND and preceding declarations
         (declares (loop while (and body (consp (first body))
                                    (eq (first (first body)) 'cl:declare))
                         collect (pop body)))
         (cond-form (first body))
         ;; Get parameter names (excluding &rest which we verified doesn't exist)
         (params (remove-if-not #'symbolp ll))
         ;; Cache naming
         (suffix (incf *method-cache-counter*))
         (pkg (or (symbol-package name) *package*))
         (cache-name (intern (format nil "%-~A-METHOD-CACHE-~D" (symbol-name name) suffix) pkg))
         ;; Build cache key expression
         (key-sym (gensym "KEY"))
         (hit-sym (gensym "HIT"))
         (key-expr `(cl:list ,@(mapcar (lambda (p) `(cl:class-of ,p)) params))))
    ;; Return modified method form with caching wrapper
    `(cl:progn
       ;; Create and register the cache
       (cl:defparameter ,cache-name (fol.compiler.dispatch:make-dispatch-cache))
       (fol.compiler.dispatch:register-gf-cache! ',name ,cache-name)
       ;; Modified defmethod with cache check before COND
       (cl:defmethod ,name ,@(when qualifier (list qualifier)) ,ll
         ,@declares
         (cl:let* ((,key-sym ,key-expr)
                   (,hit-sym (gethash ,key-sym (fol.compiler.dispatch:dispatch-cache-table ,cache-name))))
           (cl:if ,hit-sym
               ;; Cache hit: call cached function
               (cl:funcall ,hit-sym ,@params)
               ;; Cache miss: evaluate COND and cache winner
               ,(wrap-cond-with-cache cond-form cache-name key-sym params)))))))

(defun wrap-cond-with-cache (cond-form cache-name key-sym params)
  "Wrap a COND form to cache the winning clause's behavior.
   Returns a modified COND where each non-fallback clause inserts itself into cache."
  (let* ((clauses (rest cond-form))
         (fallback (car (last clauses)))
         (non-fallback (butlast clauses)))
    ;; Map each clause to wrap its body with cache insertion
    (let ((cached-clauses
           (loop for clause in non-fallback
                 collect
                 (let ((condition (first clause))
                       (body (rest clause)))
                   ;; Build wrapper: cache self, then execute
                   ;; Cache the entire clause body result by wrapping in a lambda
                   `(,condition
                     ;; Register winning clause as lambda in cache
                     (setf (gethash ,key-sym (fol.compiler.dispatch:dispatch-cache-table ,cache-name))
                           (lambda () (progn ,@body)))
                     ;; Execute the body
                     ,@body)))))
      ;; Return modified COND with cached clauses + fallback
      `(cl:cond
         ,@cached-clauses
         ,fallback))))

(defun emit-defmethod (node)
  "Emit a defmethod node as CL code.
   Single-clause with type specializers: CL defmethod.
   Multi-clause or predicate dispatch: defun with cond dispatcher.
   Also emits metadata setting code if docstring is present.
   Registers simple :around methods for potential optimization."
  (let ((name (fol.compiler.ast:defmethod-node-name node))
        (qualifier (fol.compiler.ast:defmethod-node-qualifier node))
        (clauses (fol.compiler.ast:defmethod-node-clauses node))
        (docstring (fol.compiler.ast:defmethod-node-docstring node)))
    ;; Register simple :around methods for optimization tracking
    (dolist (clause clauses)
      (registers-simple-around-method name qualifier clause))
    (let ((*extra-special-vars* nil))
      ;; Compute the defmethod form once
      (let ((method-form
             (if (= (length clauses) 1)
                 ;; Single clause - check if it has specializers
                 (let* ((clause (first clauses))
                        (param-vec (car clause))
                        (body-nodes (cdr clause))
                        (param-list (fol-vector-to-list param-vec))
                        (has-specializers (some (lambda (p)
                                                  (or (listp p)
                                                      (typep p 'fol.compiler.collections:<dict>)
                                                      (typep p 'fol.compiler.collections:<vector>)))
                                              param-list)))
                   (if (and has-specializers
                            ;; Only emit CLOS defmethod if all parameters are simple symbols 
                            ;; or (symbol type) specializers.
                            (every (lambda (p)
                                     (or (symbolp p)
                                         (and (listp p)
                                              (= (length p) 2)
                                              (symbolp (first p))
                                              (symbolp (second p)))))
                                param-list))
                       ;; All type specializers: emit proper CLOS defmethod with class specializers.
                       ;; Add &rest kvps for lambda-list congruence with generics like assoc.
                       (let* ((kvps-sym 'kvps)
                              (clos-lambda-list
                               (append
                                 (mapcar (lambda (p)
                                           (if (listp p)
                                               (list (first p) (second p))
                                               p))
                                     param-list)
                                 (list '&rest kvps-sym)))
                              (param-names
                               (mapcar (lambda (p)
                                         (if (listp p) (first p) p))
                                   param-list))
                              (emitted-body (let ((*lexical-vars* (append param-names *lexical-vars*)))
                                              (mapcar #'emit-node body-nodes)))
                              ;; Declare only the actual method params special.
                              ;; *extra-special-vars* may contain function-name symbols
                              ;; added by collection-as-function dispatch (e.g. NUMBER?)
                              ;; which must NOT appear in DECLARE SPECIAL.
                              (all-special (remove-duplicates
                                               (append param-names (list kvps-sym)))))
                         (if qualifier
                             `(defmethod ,name ,qualifier ,clos-lambda-list
                                (declare (special ,@all-special) (ignore ,kvps-sym))
                                ,@emitted-body)
                             `(defmethod ,name ,clos-lambda-list
                                (declare (special ,@all-special) (ignore ,kvps-sym))
                                ,@emitted-body)))
                       ;; Has predicate specializers or no specializers
                       (if has-specializers
                           (compile-defmethod-clauses name clauses qualifier)
                           ;; No specializers: emit simple CL defmethod, with optional caching
                           (let ((single-cache-mode (cacheable-clauses-p clauses)))
                             (multiple-value-bind (regular-params rest-param)
                                 (fol.compiler.destructure:parse-params param-list)
                               (let* ((variadic-p (member (symbol-name name) '("ASSOC" "DISSOC" "CONJ" "MERGE" "LIST" "LIST*" "VECTOR" "DICT" "SET") :test #'string-equal))
                                      (final-rest-param (or rest-param (when variadic-p (gensym "REST"))))
                                      (lambda-list (if final-rest-param
                                                       (append regular-params (list '&rest final-rest-param))
                                                       regular-params))
                                      (emitted-body (let ((*lexical-vars* (append regular-params
                                                                                  (when final-rest-param (list final-rest-param))
                                                                                  *lexical-vars*)))
                                                      (mapcar #'emit-node body-nodes)))
                                      (base-method-form
                                       (if qualifier
                                           `(defmethod ,name ,qualifier ,lambda-list
                                              ,@(when (and variadic-p (not rest-param)) `((declare (ignore ,final-rest-param))))
                                              ,@(when *extra-special-vars*
                                                      `((declare (special ,@(remove-duplicates *extra-special-vars*)))))
                                              ,@emitted-body)
                                           `(defmethod ,name ,lambda-list
                                              ,@(when (and variadic-p (not rest-param)) `((declare (ignore ,final-rest-param))))
                                              ,@(when *extra-special-vars*
                                                      `((declare (special ,@(remove-duplicates *extra-special-vars*)))))
                                              ,@emitted-body))))
                                 (if single-cache-mode
                                     (make-cached-method name base-method-form)
                                     base-method-form)))))))
                 ;; Multi-clause: emit dispatched defmethod, optionally cached
                 (let ((raw-form (compile-defmethod-clauses name clauses qualifier)))
                   (if (cacheable-method-p raw-form)
                       (make-cached-method name raw-form)
                       raw-form)))))
        ;; Wrap with metadata assignment if docstring is present
        (if docstring
            (let ((metadata-form
                   `(fol.compiler.metadata:alter-meta! (quote ,name)
                                                       (fn [m] (fol.compiler.collection-functions:merge m
                                                                                                        (fol.compiler.collection-functions:dict
                                                                                                         :doc ,docstring
                                                                                                         :name (quote ,name)))))))
              `(progn ,method-form ,metadata-form))
            method-form)))))

(defun emit-def (node)
  "Emit a def node as CL defvar."
  (let ((name (fol.compiler.ast:def-node-name node))
        (value (fol.compiler.ast:def-node-value node)))
    (pushnew name *extra-special-vars*)
    (if value
        `(cl:defvar ,name ,(emit-node value))
        `(cl:defvar ,name))))

(defun emit-defdynamic (node)
  "Emit a defdynamic node as CL defvar.
   Identical output to emit-def — defdynamic is an explicit-intent alias."
  (let ((name (fol.compiler.ast:defdynamic-node-name node))
        (value (fol.compiler.ast:defdynamic-node-value node)))
    (pushnew name *extra-special-vars*)
    (if value
        `(cl:defvar ,name ,(emit-node value))
        `(cl:defvar ,name))))

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

;;; ---------------------------------------------------------------------------
;;; Helper: Build metadata dictionary from function metadata
;;; ---------------------------------------------------------------------------

(defun build-function-metadata (name docstring clauses)
  "Build a metadata dictionary for a function.
   Returns a dict with :doc, :arglists, and :name keys (if available)."
  (let ((metadata-entries nil))
    ;; Add docstring if present
    (when docstring
          (push `:doc metadata-entries)
          (push docstring metadata-entries))
    ;; Add arglists from clauses (convert param vectors to lists)
    (let ((arglists (mapcar (lambda (clause)
                              (let ((params (car clause)))
                                (if (fol-vector-p params)
                                    (fol-vector-to-list params)
                                    params)))
                        clauses)))
      (push `:arglists metadata-entries)
      (push arglists metadata-entries))
    ;; Add function name
    (push `:name metadata-entries)
    (push name metadata-entries)
    ;; Build dict form: (fol.compiler.collection-functions:dict :key1 val1 :key2 val2 ...)
    `(fol.compiler.collection-functions:dict ,@(reverse metadata-entries))))

(defun emit-metadata-assignment (name docstring clauses)
  "Emit code to set metadata on a function symbol.
   Returns the metadata assignment form, or nil if no metadata."
  (when docstring
        (let ((metadata-dict (build-function-metadata name docstring clauses)))
          `(fol.compiler.metadata:alter-meta! (quote ,name)
                                              (lambda (m)
                                                (if m
                                                    (fol.compiler.collection-functions:merge m ,metadata-dict)
                                                    ,metadata-dict))))))

;;; Dispatch Caching Helpers

(defparameter *fol-type-predicates*
  '(integer? float? string? vector? dict? set? boolean? char? keyword? symbol?
    fn? map? list? seq? coll? nil? some? map-entry?))

(defun type-dispatch-cond-p (cond-form params)
  (let ((non-fallback (butlast (rest cond-form))))
    (and non-fallback
         (loop for clause in non-fallback
               for check = (first clause)
               always
               (or (and (consp check) (eq (first check) 'cl:typep) (member (second check) params))
                   (and (consp check) (= (length check) 2) (member (second check) params)
                        (let ((pred (first check)))
                          (or (member pred *fol-type-predicates*)
                              (member (symbol-name pred) (mapcar #'symbol-name *fol-type-predicates*) :test #'string=)))))))))

(defun predicate-dispatch-cond-p (cond-form)
  (and (consp cond-form) (eq (first cond-form) 'cl:cond)
       (>= (- (length (rest cond-form)) 1) +dispatch-cache-threshold+)))

(defun has-reference-type-value-predicates-p (cond-form params)
  "Return T if COND has value predicates on reference types (not eql-comparable).
   Detects patterns like (eq x obj) or (eql x symbol-ref) where obj/symbol-ref
   could be a reference type that multiple values share (same class).
   If detected, caching should be skipped to avoid cache conflicts."
  (let ((non-fallback (butlast (rest cond-form))))
    (loop for clause in non-fallback
          for check = (first clause)
          thereis
          ;; Pattern: (eq/eql param symbol-or-var) or similar value predicate
          (and (consp check)
               (member (first check) '(cl:eq cl:eql eq eql equal) :test #'eq)
               (= (length check) 3)
               ;; One arg is a parameter, one is potentially a reference
               (let ((arg1 (second check))
                     (arg2 (third check)))
                 (and (or (member arg1 params) (member arg2 params))
                      (or (and (member arg1 params) (symbolp arg2))
                          (and (member arg2 params) (symbolp arg1)))))))))

(defun value-key-expr (params)
  `(cl:list ,@(mapcar (lambda (p) `(fol.compiler.dispatch:pred-key ,p)) params)))

(defun cacheable-clauses-p (clauses)
  "Dispatch caching disabled: benchmarks showed it slowed performance."
  (declare (ignore clauses))
  nil)

(defun count-nested-ifs (form)
  "Count the total number of if-branches in a nested IF dispatch structure.
   Each (if ...) counts as 1, plus any nested IFs in the else branch."
  (when (and (consp form) (eq (first form) 'cl:if) (= (length form) 4))
    (let ((else-branch (fourth form)))
      (+ 1 (or (count-nested-ifs else-branch) 0)))))

(defun has-nested-dispatch-p (form)
  "Check if FORM is an IF/COND dispatch structure (possibly nested).
   Returns the total branching factor if it looks like a dispatch, nil otherwise."
  (when (consp form)
    (cond
      ;; COND dispatch: (cond (test body) ... )
      ((and (eq (first form) 'cl:cond) (>= (length form) 2))
       (- (length (rest form)) 1))  ; number of clauses (excluding fallback)
      ;; IF dispatch: (if test true-branch false-branch)
      ((and (eq (first form) 'cl:if) (= (length form) 4))
       (count-nested-ifs form))
      (t nil))))

(defun cacheable-defn-p (lambda-form)
  "Dispatch caching disabled: benchmarks showed it slowed performance."
  (declare (ignore lambda-form))
  nil)

(defun make-cached-defn (name lambda-form dispatch-mode)
  "Generate a cached defn with dispatch caching.

   Per-GF Versioning Integration (Future Enhancement):
   - Current: Uses global generation (may over-invalidate on unrelated method additions)
   - Future: Could include GF versions in cache key via (make-versioned-cache-key ...)
   - Requirement: CallSet analysis would need to identify which GFs this function calls
   - Implementation: Replace key-expr with version-aware key construction

   Current approach remains backward-compatible; per-GF versioning available via
   the MOP hooks in dispatch.lisp when *use-per-gf-versioning* is enabled."
  (let* ((params (second lambda-form)) (raw-body (cddr lambda-form))
         (first-body (first raw-body)) (has-declare (and (consp first-body) (eq (first first-body) 'cl:declare)))
         (declare-form (when has-declare first-body)) (cond-form (if has-declare (second raw-body) first-body))
         (all-clauses (rest cond-form)) (fallback (car (last all-clauses))) (clauses (butlast all-clauses))
         (n (length clauses)) (pkg (or (symbol-package name) *package*))
         (helper-names (loop for i below n collect (intern (format nil "%-~A-CLAUSE-~D" (symbol-name name) i) pkg)))
         (cache-name (intern (format nil "%-~A-DISPATCH-CACHE" (symbol-name name)) pkg))
         (key-sym (gensym "KEY")) (hit-sym (gensym "HIT"))
         (key-expr (ecase dispatch-mode
                     (:type `(cl:list ,@(mapcar (lambda (p) `(cl:class-of ,p)) params)))
                     (:value (value-key-expr params)))))
    `(cl:progn
       ,@(loop for clause in clauses for hname in helper-names
               collect `(cl:defun ,hname ,params ,@(when declare-form (list declare-form)) ,(second clause)))
       (cl:defparameter ,cache-name (fol.compiler.dispatch:make-dispatch-cache))
       (cl:defun ,name ,params ,@(when declare-form (list declare-form))
         (cl:let* ((,key-sym ,key-expr) (,hit-sym (gethash ,key-sym (fol.compiler.dispatch:dispatch-cache-table ,cache-name))))
           (cl:if ,hit-sym (cl:funcall ,hit-sym ,@params)
               (cl:cond ,@(loop for clause in clauses for hname in helper-names
                               collect `(,(first clause)
                                        (setf (gethash ,key-sym (fol.compiler.dispatch:dispatch-cache-table ,cache-name)) #',hname)
                                        (,hname ,@params)))
                        ,fallback)))))))

(defun make-cached-fn (lambda-form dispatch-mode)
  (let* ((params (second lambda-form)) (raw-body (cddr lambda-form))
         (first-body (first raw-body)) (has-declare (and (consp first-body) (eq (first first-body) 'cl:declare)))
         (declare-form (when has-declare first-body)) (cond-form (if has-declare (second raw-body) first-body))
         (all-clauses (rest cond-form)) (fallback (car (last all-clauses))) (clauses (butlast all-clauses))
         (cache-sym (gensym "FOL-FN-CACHE-")) (helper-syms (loop for i below (length clauses) collect (gensym (format nil "FOL-FN-CLAUSE-~D-" i))))
         (key-sym (gensym "KEY")) (hit-sym (gensym "HIT"))
         (key-expr (ecase dispatch-mode
                     (:type `(cl:list ,@(mapcar (lambda (p) `(cl:class-of ,p)) params)))
                     (:value (value-key-expr params)))))
    `(cl:progn
       ,@(loop for clause in clauses for hname in helper-syms
               collect `(cl:defun ,hname ,params ,@(when declare-form (list declare-form)) ,(second clause)))
       (cl:defvar ,cache-sym (fol.compiler.dispatch:make-dispatch-cache))
       (cl:lambda ,params ,@(when declare-form (list declare-form))
         (cl:let* ((,key-sym ,key-expr) (,hit-sym (gethash ,key-sym (fol.compiler.dispatch:dispatch-cache-table ,cache-sym))))
           (cl:if ,hit-sym (cl:funcall ,hit-sym ,@params)
               (cl:cond ,@(loop for clause in clauses for hname in helper-syms
                               collect `(,(first clause)
                                        (setf (gethash ,key-sym (fol.compiler.dispatch:dispatch-cache-table ,cache-sym)) #',hname)
                                        (,hname ,@params)))
                        ,fallback)))))))

(defun emit-defn (node)
  "Emit a defn node as (defun name ...).
   Puts the function in the function slot, not the value slot.
   For single-clause: (defun name (params) body...)
   For multi-clause: (defun name (&rest args) (cond ...)) with optional caching

   Also emits metadata setting code if docstring is present.
   Supports type annotations via reader ^TYPE syntax, generating SBCL (declare (ftype ...)) forms."
  (let* ((name (fol.compiler.ast:defn-node-name node))
         (clauses (fol.compiler.ast:defn-node-clauses node))
         (docstring (fol.compiler.ast:defn-node-docstring node))
         ;; Extract type metadata attached by reader ^TYPE syntax
         (type-metadata-form (cl:get name :defn-type-metadata))
         ;; AST-level analysis (robust, format-independent)
         (cache-mode (cacheable-clauses-p clauses))
         ;; Compile regardless (needed for emit). Bind the current-defn
         ;; context (see *CURRENT-DEFN-NAME*) so INFER-TYPE-FROM-EXPR can
         ;; resolve bare parameter references to interprocedurally-proven
         ;; types while this function's body is being emitted.
         (lambda-form (%with-current-defn-context name clauses
                        (compile-fn clauses)))
         ;; Fallback: post-compile check catches edge cases
         (cache-mode (or cache-mode (cacheable-defn-p lambda-form))))
    ;; Track this function for Lisp-1 compatibility in compile-file
    (when *file-function-defs*
          (pushnew name *file-function-defs* :test #'string=))

    ;; Extract type from metadata form if present
    ;; Metadata form is (dict :type TypeName) from the reader
    (let ((type-name (when (and type-metadata-form
                                (listp type-metadata-form)
                                (not (null (rest type-metadata-form))))
                       ;; type-metadata-form is (dict :type TypeName) where TypeName is the actual type
                       ;; We need to extract TypeName from this form
                       ;; The (dict :type TypeName) form evaluates to a dict, but we have the raw form
                       ;; TypeName is the last element in the plist after :type
                       (let ((plist-tail (rest type-metadata-form)))
                         (loop for (key val) on plist-tail by #'cddr
                               when (eq key :type)
                               return val)))))

      ;; lambda-form is (lambda params body...)
      ;; Check if dispatch caching applies
      (let* ((params (second lambda-form))
             ;; Generate type declaration if we have a type name
             (type-decl (when type-name
                          `((cl:declare (cl:ftype (cl:function ,@(loop for p in params collect t) ,type-name) ,name)))))
             (base-form (if cache-mode
                            (make-cached-defn name lambda-form cache-mode)
                            (let ((body (cddr lambda-form)))
                              (if type-decl
                                  `(cl:defun ,name ,params ,@type-decl ,@body)
                                  `(cl:defun ,name ,params ,@body)))))
             (metadata-form (emit-metadata-assignment name docstring clauses)))
        (if metadata-form
            `(cl:progn ,base-form ,metadata-form)
            base-form)))))

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

;;; ============================================================================
;;; Aggregate Scalar Replacement (loop-carried record accumulators)
;;; ============================================================================
;;;
;;; See docs/scalar-replacement-design.md. This is the "new" scalar replacement
;;; algorithm. Unlike the deleted intra-bind pass (which only unboxed an object
;;; that died in its own BIND -- the least profitable case), this transformation
;;; targets the allocation-bound pattern the design's own particle-simulation
;;; benchmark exercises: a loop accumulator of persistent record type rebuilt
;;; every iteration. It closes three gaps:
;;;
;;;   (1) return-value unboxing (interprocedural). An object-returning callee at
;;;       the recur position -- e.g. (recur (update-point p) ...) -- is inlined
;;;       (SR-TRANSFORM-TOPLEVEL registers qualifying single-clause callees in
;;;       *SR-INLINABLE-FNS*), so its tail make-<T> becomes the reconstruction
;;;       expression right at the back-edge.
;;;
;;;   (2) loop-carried unboxing. A loop accumulator P of record type <T> is
;;;       split into one scalar loop variable per field (P_X, P_Y, ...). Reads
;;;       (get p :x) become P_X; the reconstruction that feeds recur becomes the
;;;       per-field value expressions; a bare P in tail position is re-boxed with
;;;       a single make-<T> at loop exit. Net: zero per-iteration allocation.
;;;
;;;   (3) soundness under redefinition. The converted loop is emitted world-
;;;       guarded on the record's class name (EMIT-LOOP), and EMIT-DEFCLASS calls
;;;       NOTE-REDEFINITION, so redefining <T> falls the loop back to the
;;;       original object-allocating path on next entry.
;;;
;;; The rewrite is aligned-by-construction: a single walk both classifies and
;;; rewrites, and throws SR-FAIL on any accumulator use it does not recognize,
;;; so an un-handled shape yields the original loop unchanged (never wrong code).

(defvar *sr-inlinable-fns* (make-hash-table :test 'eq)
  "Maps a defn name (symbol) to (PARAMS . TAIL-EXPR-NODE): single-clause
   functions whose body is one expression that constructs and returns a fresh
   record (make-<T> ..., possibly under bind/do wrappers). Scalar replacement
   inlines these at a loop's recur position to expose the reconstruction.")

(defun %sr-canon-key (k)
  "Canonical keyword for a slot/initarg key (case-insensitive)."
  (intern (string-upcase (string k)) :keyword))

(defun %sr-param-list (params)
  "Coerce a clause parameter list (FOL <vector>, CL vector, or list) to a list."
  (cond ((and (vectorp params) (not (stringp params))) (coerce params 'list))
        ((typep params 'fol.compiler.collections:<vector>)
         (fol.compiler.collections:collection-seq params))
        ((listp params) params)
        (t nil)))

(defun %sr-symbol-list-p (params)
  (and (listp params) params (every #'symbolp params)))

(defun %sr-strip-docstring (body-nodes)
  "Drop a leading string-literal docstring from a clause body, if present."
  (if (and (cdr body-nodes)
           (fol.compiler.ast:literal-node-p (car body-nodes))
           (stringp (fol.compiler.ast:literal-node-value (car body-nodes))))
      (cdr body-nodes)
      body-nodes))

(defun %sr-peel-core (node)
  "Peel single-form bind/do wrappers off NODE, returning the innermost
   expression. Used to check whether a function body ultimately yields a
   constructor call."
  (cond
    ((and (fol.compiler.ast:bind-node-p node)
          (= 1 (length (fol.compiler.ast:bind-node-body node))))
     (%sr-peel-core (first (fol.compiler.ast:bind-node-body node))))
    ((and (fol.compiler.ast:do-node-p node)
          (fol.compiler.ast:do-node-body node))
     (%sr-peel-core (car (last (fol.compiler.ast:do-node-body node)))))
    (t node)))

(defun %sr-ctor-fields (call)
  "For a (make-<T> :k1 v1 :k2 v2 ...) call node, return an alist mapping each
   canonical keyword to its value NODE, or NIL if the args are not a clean
   sequence of keyword/value pairs."
  (let ((args (fol.compiler.ast:call-node-args call))
        (out '()))
    (loop for rest on args by #'cddr
          for k = (car rest)
          for v = (cadr rest)
          do (unless (and v
                          (fol.compiler.ast:literal-node-p k)
                          (keywordp (fol.compiler.ast:literal-node-value k)))
               (return-from %sr-ctor-fields nil))
             (push (cons (%sr-canon-key (fol.compiler.ast:literal-node-value k)) v) out))
    (nreverse out)))

(defun %sr-fields-match (fields ctor-fields)
  "True when the constructor supplies exactly the registry's field set."
  (and (= (length fields) (length ctor-fields))
       (every (lambda (f) (assoc (car f) ctor-fields)) fields)))

(defun %sr-register-defn (name clauses)
  "If NAME is a single-clause function whose body is one expression that peels
   to a record constructor -- directly, or via an IF/COND/CASE whose branches
   EXPAND-ACC's own (already-general) recursive dispatch can attempt to
   reconstruct -- record it as inlinable for scalar replacement. Branch
   validity beyond this shape check is decided only when a specific loop
   actually tries to inline the callee, not here: an unrecognized branch
   safely aborts just that reconstruction."
  (when (and name (= 1 (length clauses)))
    (let* ((clause (first clauses))
           (params (%sr-param-list (car clause)))
           (body (%sr-strip-docstring (cdr clause))))
      (when (and (%sr-symbol-list-p params)
                 (= 1 (length body))
                 (let ((core (%sr-peel-core (first body))))
                   (or (and (fol.compiler.ast:call-node-p core)
                            (infer-type-from-constructor core))
                       (fol.compiler.ast:if-node-p core)
                       (fol.compiler.ast:cond-node-p core)
                       (fol.compiler.ast:case-node-p core))))
        (setf (gethash name *sr-inlinable-fns*) (cons params (first body)))))))

;;; ----------------------------------------------------------------------
;;; Reduce-over-literal-collection unrolling (*REDUCE-LITERAL-UNROLL*)
;;; ----------------------------------------------------------------------
;;; REDUCE's own iteration is opaque to every downstream pass -- it lives
;;; inside COLLECTION-REDUCE's generic dispatch, not in code the compiler
;;; can see. When COLL is a literal vector/set (or a name bound to one by a
;;; top-level DEF), its element count and contents are known at compile
;;; time, so the whole call can be unrolled into an ordinary straight-line
;;; BIND chain instead: N sequential rebindings of the step function's own
;;; accumulator/element parameter names (BIND is sequential, like Clojure's
;;; let, so no renaming or substitution is needed -- each step just sees
;;; the previous one's bindings). That chain is then just ordinary code:
;;; scalar replacement, numeric specialization, or nothing at all can apply
;;; to it exactly as if the user had written the unrolled form by hand.

(defvar *def-literal-collections* (make-hash-table :test 'eq)
  "Maps a top-level DEF name (symbol) to its value AST node, when that value
   is a literal vector/set. Lets a REDUCE call elsewhere refer to the
   collection by name (as real code almost always does, e.g. (def
   http-methods #{...}) used later as (reduce f init http-methods)) and
   still be recognized as reducing over a known, literal collection.")

(defun %register-def-literal-collection (name value-node)
  (when (and name value-node
             (or (fol.compiler.ast:vector-node-p value-node)
                 (fol.compiler.ast:set-node-p value-node)))
    (setf (gethash name *def-literal-collections*) value-node)))

(defun %literal-collection-elements (n)
  "Element-node list when N is a literal vector/set, or a bare symbol
   registered (via a top-level DEF) as one; else NIL."
  (cond
    ((fol.compiler.ast:vector-node-p n) (fol.compiler.ast:vector-node-elements n))
    ((fol.compiler.ast:set-node-p n) (fol.compiler.ast:set-node-elements n))
    ((fol.compiler.ast:symbol-ref-node-p n)
     (let ((v (gethash (fol.compiler.ast:symbol-ref-node-name n) *def-literal-collections*)))
       (and v (%literal-collection-elements v))))
    (t nil)))

(defun %rename-safe-body-p (n)
  "True when N's subtree contains only node types %RENAME-REFS knows how to
   recurse through (call/if/do/cond/case/symbol-ref/literal/quote) -- a
   whitelist, not a blacklist, so an unfamiliar node type (a nested
   bind/fn/loop that could shadow or capture a renamed name, or anything
   else not accounted for) safely declines rather than being silently
   skipped over."
  (cond
    ((or (fol.compiler.ast:symbol-ref-node-p n) (fol.compiler.ast:literal-node-p n)
         (fol.compiler.ast:quote-node-p n))
     t)
    ((fol.compiler.ast:call-node-p n)
     (and (%rename-safe-body-p (fol.compiler.ast:call-node-operator n))
          (every #'%rename-safe-body-p (fol.compiler.ast:call-node-args n))))
    ((fol.compiler.ast:if-node-p n)
     (and (%rename-safe-body-p (fol.compiler.ast:if-node-test n))
          (%rename-safe-body-p (fol.compiler.ast:if-node-then n))
          (let ((e (fol.compiler.ast:if-node-else n)))
            (or (null e) (%rename-safe-body-p (first e))))))
    ((fol.compiler.ast:do-node-p n)
     (every #'%rename-safe-body-p (fol.compiler.ast:do-node-body n)))
    ((fol.compiler.ast:cond-node-p n)
     (every (lambda (c)
              (and (or (not (fol.compiler.ast:ast-node-p (car c))) (%rename-safe-body-p (car c)))
                   (every #'%rename-safe-body-p (cdr c))))
            (fol.compiler.ast:cond-node-clauses n)))
    ((fol.compiler.ast:case-node-p n)
     (and (%rename-safe-body-p (fol.compiler.ast:case-node-expr n))
          (every (lambda (c) (every #'%rename-safe-body-p (cdr c)))
                 (fol.compiler.ast:case-node-clauses n))))
    (t nil)))

(defun %rename-refs (n renames)
  "Return N with every bare SYMBOL-REF-NODE named by a key in RENAMES (an
   alist old-name -> new-name) replaced by a reference to the mapped name.
   Only ever called on a body already passed %RENAME-SAFE-BODY-P, so every
   node type below is exhaustive for what such a body can contain -- no
   shadowing or capture is possible."
  (cond
    ((and (fol.compiler.ast:symbol-ref-node-p n)
          (assoc (fol.compiler.ast:symbol-ref-node-name n) renames))
     (fol.compiler.ast:make-symbol-ref-node
      :name (cdr (assoc (fol.compiler.ast:symbol-ref-node-name n) renames))
      :form (fol.compiler.ast:ast-node-form n)))
    ((or (fol.compiler.ast:symbol-ref-node-p n) (fol.compiler.ast:literal-node-p n)
         (fol.compiler.ast:quote-node-p n))
     n)
    ((fol.compiler.ast:call-node-p n)
     (fol.compiler.ast:make-call-node
      :operator (%rename-refs (fol.compiler.ast:call-node-operator n) renames)
      :args (mapcar (lambda (a) (%rename-refs a renames)) (fol.compiler.ast:call-node-args n))
      :form (fol.compiler.ast:ast-node-form n)))
    ((fol.compiler.ast:if-node-p n)
     (fol.compiler.ast:make-if-node
      :test (%rename-refs (fol.compiler.ast:if-node-test n) renames)
      :then (%rename-refs (fol.compiler.ast:if-node-then n) renames)
      :else (let ((e (fol.compiler.ast:if-node-else n)))
              (and e (list (%rename-refs (first e) renames))))
      :form (fol.compiler.ast:ast-node-form n)))
    ((fol.compiler.ast:do-node-p n)
     (fol.compiler.ast:make-do-node
      :body (mapcar (lambda (b) (%rename-refs b renames)) (fol.compiler.ast:do-node-body n))
      :form (fol.compiler.ast:ast-node-form n)))
    ((fol.compiler.ast:cond-node-p n)
     (fol.compiler.ast:make-cond-node
      :clauses (mapcar (lambda (c)
                         (cons (if (fol.compiler.ast:ast-node-p (car c))
                                   (%rename-refs (car c) renames)
                                   (car c))
                               (mapcar (lambda (b) (%rename-refs b renames)) (cdr c))))
                       (fol.compiler.ast:cond-node-clauses n))
      :form (fol.compiler.ast:ast-node-form n)))
    ((fol.compiler.ast:case-node-p n)
     (fol.compiler.ast:make-case-node
      :expr (%rename-refs (fol.compiler.ast:case-node-expr n) renames)
      :clauses (mapcar (lambda (c) (cons (car c) (mapcar (lambda (b) (%rename-refs b renames)) (cdr c))))
                       (fol.compiler.ast:case-node-clauses n))
      :form (fol.compiler.ast:ast-node-form n)))
    (t n)))

(defun %reduce-literal-call-p (n)
  "When N is (reduce (fn [acc x] body) init coll) with a single-clause,
   two-param literal FN (mirrors escape-analysis.lisp's
   %LINEAR-REDUCE-LAMBDA shape check), a body %RENAME-SAFE-BODY-P accepts,
   and COLL resolving to a literal vector/set, return (values acc-sym
   elem-sym body-node init-node element-nodes); else NIL."
  (when (and (fol.compiler.ast:call-node-p n)
             (let ((op (fol.compiler.escape-analysis:operator-symbol n)))
               (and op (string= (symbol-name op) "REDUCE")))
             (= 3 (length (fol.compiler.ast:call-node-args n))))
    (let* ((args (fol.compiler.ast:call-node-args n))
           (f (first args))
           (init (second args))
           (coll (third args)))
      (when (and (fol.compiler.ast:fn-node-p f)
                 (= 1 (length (fol.compiler.ast:fn-node-clauses f))))
        (let* ((clause (first (fol.compiler.ast:fn-node-clauses f)))
               (params (%sr-param-list (car clause)))
               (body (%sr-strip-docstring (cdr clause))))
          (when (and (%sr-symbol-list-p params) (= 2 (length params))
                     (= 1 (length body))
                     (%rename-safe-body-p (first body)))
            (let ((elements (%literal-collection-elements coll)))
              (when elements
                (values (first params) (second params) (first body) init elements)))))))))

(defun %desugar-reduce-literal (n)
  "If N is a reduce-over-literal-collection call recognized by
   %REDUCE-LITERAL-CALL-P, return its unrolled BIND-chain equivalent; else
   N unchanged. Each unrolled step gets its own fresh GENSYM accumulator
   and element variable (never the step function's original parameter
   names, reused via shadowing): a shadowed-name chain reads correctly
   under ordinary evaluation, but was found to confuse the intra-bind
   scalar-replacement pass's per-name field tracking into silently
   computing a wrong value on the fast path (verified directly: the
   shadowed-name version produced 9 instead of 6 on a 3-element chain).
   Fresh names per step side-step that risk entirely."
  (multiple-value-bind (acc-sym elem-sym body init elements) (%reduce-literal-call-p n)
    (cond
      ((null acc-sym) n)
      ((null elements) init)
      (t (let* ((idx 0)
                ;; INTERN, not GENSYM: downstream (SR-INTRA-BIND-PASS's own
                ;; SCAN-BINDINGS, and ASR's own fresh-field-var minting) derive
                ;; further names via (INTERN ... (SYMBOL-PACKAGE this-name)),
                ;; which needs a real package -- an uninterned GENSYM symbol's
                ;; SYMBOL-PACKAGE is NIL and breaks that (confirmed directly:
                ;; INTERN of "ACC_X" into package NIL signals
                ;; PACKAGE-DOES-NOT-EXIST). A counter-suffixed interned name in
                ;; ACC-SYM's own package gives the same per-step uniqueness
                ;; without that hazard.
                (fresh (lambda (base)
                         (prog1 (intern (format nil "~A_~D" (symbol-name base) idx)
                                        (symbol-package base))
                           (incf idx))))
                (bindings nil)
                (cur-acc (funcall fresh acc-sym)))
           (push (cons cur-acc init) bindings)
           (dolist (e elements)
             (let ((elem-var (funcall fresh elem-sym))
                   (next-acc (funcall fresh acc-sym)))
               (push (cons elem-var e) bindings)
               (push (cons next-acc (%rename-refs body (list (cons acc-sym cur-acc)
                                                              (cons elem-sym elem-var))))
                     bindings)
               (setf cur-acc next-acc)))
           (fol.compiler.ast:make-bind-node
            :bindings (nreverse bindings)
            :body (list (fol.compiler.ast:make-symbol-ref-node :name cur-acc :form cur-acc))
            :form (fol.compiler.ast:ast-node-form n)))))))

(defun %reduce-desugar-peel (n)
  "Peel single-form BIND/DO wrappers -- exactly %SR-PEEL-CORE's scope, no
   IF/COND/CASE branch recognition in this v1 -- to find and desugar a
   qualifying reduce-over-literal-collection call in tail position. Returns
   N unchanged (recursively rebuilt around any inner rewrite) if none is
   found."
  (cond
    ((and (fol.compiler.ast:bind-node-p n) (= 1 (length (fol.compiler.ast:bind-node-body n))))
     (fol.compiler.ast:make-bind-node
      :bindings (fol.compiler.ast:bind-node-bindings n)
      :body (list (%reduce-desugar-peel (first (fol.compiler.ast:bind-node-body n))))
      :form (fol.compiler.ast:ast-node-form n)))
    ((and (fol.compiler.ast:do-node-p n) (fol.compiler.ast:do-node-body n))
     (let ((body (fol.compiler.ast:do-node-body n)))
       (fol.compiler.ast:make-do-node
        :body (append (butlast body) (list (%reduce-desugar-peel (car (last body)))))
        :form (fol.compiler.ast:ast-node-form n))))
    (t (%desugar-reduce-literal n))))

(defun %reduce-desugar-clauses (clauses)
  "Rewrite each clause's tail (last) body form via %REDUCE-DESUGAR-PEEL,
   leaving earlier body forms (and the parameter list) untouched."
  (mapcar (lambda (clause)
            (let ((body (cdr clause)))
              (if body
                  (cons (car clause)
                        (append (butlast body) (list (%reduce-desugar-peel (car (last body))))))
                  clause)))
          clauses))

(defun reduce-literal-desugar-toplevel (node)
  "COMPILE-FORM hook: registers a top-level DEF's literal-collection value
   (for later REDUCE call sites to resolve by name) and rewrites a
   qualifying REDUCE-over-literal-collection call found in tail position of
   a top-level defn/defn-private/definline body into its unrolled BIND
   chain. Runs before SR-INTRA-BIND-PASS so the unrolled chain is visible
   to scalar replacement like any other bind chain. Always returns a node
   (possibly NODE itself, unchanged)."
  (if (not fol.compiler.escape-analysis:*reduce-literal-unroll*)
      node
      (labels ((visit (n)
                 (cond
                   ((fol.compiler.ast:defn-node-p n)
                    (fol.compiler.ast:make-defn-node
                     :name (fol.compiler.ast:defn-node-name n)
                     :clauses (%reduce-desugar-clauses (fol.compiler.ast:defn-node-clauses n))
                     :form (fol.compiler.ast:ast-node-form n)))
                   ((fol.compiler.ast:defn-private-node-p n)
                    (fol.compiler.ast:make-defn-private-node
                     :name (fol.compiler.ast:defn-private-node-name n)
                     :clauses (%reduce-desugar-clauses (fol.compiler.ast:defn-private-node-clauses n))
                     :form (fol.compiler.ast:ast-node-form n)))
                   ((fol.compiler.ast:definline-node-p n)
                    (fol.compiler.ast:make-definline-node
                     :name (fol.compiler.ast:definline-node-name n)
                     :clauses (%reduce-desugar-clauses (fol.compiler.ast:definline-node-clauses n))
                     :form (fol.compiler.ast:ast-node-form n)))
                   ((fol.compiler.ast:def-node-p n)
                    (%register-def-literal-collection
                     (fol.compiler.ast:def-node-name n) (fol.compiler.ast:def-node-value n))
                    n)
                   ((fol.compiler.ast:do-node-p n)
                    (fol.compiler.ast:make-do-node
                     :body (mapcar #'visit (fol.compiler.ast:do-node-body n))
                     :form (fol.compiler.ast:ast-node-form n)))
                   (t n))))
        (visit node))))

(defun tr-transform-toplevel (node)
  "COMPILE-FORM hook (transient-conversion mode). Registers helpers that
   linearly thread an accumulator through a real update chain, so
   escape-analysis.lisp's CHAIN-KIND/REWRITE-LOOP-BODY can inline them at a
   loop's recur/reduce update position (closes the 'DVI gap' documented in
   the design notes: a helper call was previously an unconditional
   disqualifier). The registry and the inlining logic itself live in
   escape-analysis.lisp, next to CHAIN-KIND, which is what needs to consult
   them. Returns NODE unchanged."
  (when fol.compiler.escape-analysis:*transient-loops*
    (labels ((visit (n)
               (cond
                 ((fol.compiler.ast:defn-node-p n)
                  (fol.compiler.escape-analysis:maybe-register-inlinable-helper
                   (fol.compiler.ast:defn-node-name n)
                   (fol.compiler.ast:defn-node-clauses n)))
                 ((fol.compiler.ast:defn-private-node-p n)
                  (fol.compiler.escape-analysis:maybe-register-inlinable-helper
                   (fol.compiler.ast:defn-private-node-name n)
                   (fol.compiler.ast:defn-private-node-clauses n)))
                 ((fol.compiler.ast:definline-node-p n)
                  (fol.compiler.escape-analysis:maybe-register-inlinable-helper
                   (fol.compiler.ast:definline-node-name n)
                   (fol.compiler.ast:definline-node-clauses n)))
                 ((fol.compiler.ast:do-node-p n)
                  (mapc #'visit (fol.compiler.ast:do-node-body n))))))
      (visit node)))
  node)

(defun sr-transform-toplevel (node)
  "COMPILE-FORM hook (scalar-replacement mode). Registers inlinable record
   constructors found among the top-level definitions; the loop rewrite itself
   happens at emit time in MAYBE-SCALAR-REPLACE-LOOP. Returns NODE unchanged."
  (when fol.compiler.escape-analysis:*scalar-replacement*
    (labels ((visit (n)
               (cond
                 ((fol.compiler.ast:defn-node-p n)
                  (%sr-register-defn (fol.compiler.ast:defn-node-name n)
                                     (fol.compiler.ast:defn-node-clauses n)))
                 ((fol.compiler.ast:defn-private-node-p n)
                  (%sr-register-defn (fol.compiler.ast:defn-private-node-name n)
                                     (fol.compiler.ast:defn-private-node-clauses n)))
                 ((fol.compiler.ast:definline-node-p n)
                  (%sr-register-defn (fol.compiler.ast:definline-node-name n)
                                     (fol.compiler.ast:definline-node-clauses n)))
                 ((fol.compiler.ast:do-node-p n)
                  (mapc #'visit (fol.compiler.ast:do-node-body n))))))
      (visit node)))
  node)

(defun %sr-refs-alias-p (node aliases)
  "True when NODE's subtree references any accumulator-alias name in ALIASES."
  (labels ((scan (n)
             (cond
               ((fol.compiler.ast:symbol-ref-node-p n)
                (when (member (fol.compiler.ast:symbol-ref-node-name n) aliases)
                  (return-from %sr-refs-alias-p t)))
               (t (dolist (c (fol.compiler.escape-analysis:node-children n)) (scan c))))))
    (scan node)
    nil))

;;; ============================================================================
;;; Intra-bind Scalar Replacement (Original Proposal)
;;; ============================================================================

(defun %sr-intra-bind-chain (pname fields ctor-fields ctor-op rest-bindings body-nodes &optional dict-p)
  "Attempt to thread scalar replacement of PNAME's fields through
   REST-BINDINGS (the bindings after PNAME's own, in original order) and
   BODY-NODES (the enclosing bind's trailing body forms). PNAME's tracked
   field state starts as CTOR-FIELDS (the alist :K -> value-node the
   original constructor supplied) and is threaded forward through any
   chain of `(bname (assoc alias :key val))` bindings, where ALIAS is
   PNAME or an earlier such BNAME -- exactly the partial-reconstruction
   shape the loop-carried pass's Reconstruct handles (Figure 2), applied
   here to a straight-line bind chain instead of a recur argument. Any
   other appearance of a tracked alias -- passed to a function, stored in
   a literal, or a `(get alias :key)` whose key never entered the tracked
   state -- aborts the WHOLE attempt via THROW, matching the loop-carried
   pass's safe-by-abort discipline: the caller must see NIL and leave
   PNAME's original binding untouched, not a half-rewritten chain.
   (An earlier version of this function only ever inspected BODY-NODES for
   escapes and never looked at REST-BINDINGS at all, so a chain like
   `(bind [p (make-<t> ...) q (assoc p :k v)] q)` unboxed P's fields but
   left `(assoc p ...)` referring to the now-nonexistent P unrewritten --
   a real miscompilation, not merely a missed optimization.)
   On success, returns (values NEW-REST-BINDINGS NEW-BODY USED-OPS):
   NEW-REST-BINDINGS is REST-BINDINGS with every recognized chain-assoc
   binding dropped (record mode: it becomes pure compile-time bookkeeping
   -- its only meaning was the updated field state, now tracked directly)
   or kept, rewritten to a fresh scalar binding (dict mode: see below);
   every other binding is kept with its init rewritten. NEW-BODY resolves
   every alias/field reference, re-materializing the record via CTOR-OP
   (record mode) or as a dict literal (dict mode) if the chain's final
   alias is returned bare in tail position (mirroring the loop pass's
   tail re-box). USED-OPS is the list of Tier-1 operator name strings
   actually touched ("GET"/"ASSOC"), needed by dict mode's caller for the
   world-guard's live trust re-check (%KIND-TRUSTED-P); always NIL in
   record mode, which needs no such check (see SR-INTRA-BIND-PASS).

   DICT-P selects between two field-set sources. Record mode (DICT-P NIL,
   the original design): FIELDS is a closed, pre-registered set from
   *GLOBAL-TYPE-INFO*; CHAIN-ASSOC-TARGET only recognizes a KEY already in
   that set, and every recognized chain-assoc binding is dropped (the
   field's value is tracked directly, inlined at each read -- safe here
   because a record's initial field values are, in every case reachable
   from *GLOBAL-TYPE-INFO*-backed source, simple literals). Dict mode
   (DICT-P T, FIELDS/CTOR-FIELDS/CTOR-OP unused/NIL): there is no
   pre-registered set -- PNAME's `{}` init starts with zero fields, and
   CHAIN-ASSOC-TARGET accepts any literal-keyword key, discovering the
   field set from usage as the chain is walked. Because a dict field's
   value can be an arbitrary expression (a real corpus example calls a
   helper function per key, not a literal), inlining it at every
   subsequent read would silently re-evaluate it -- so dict mode instead
   mints a fresh scalar variable and KEEPS every chain-assoc binding
   (rewritten to bind that scalar), and tracks a reference to it rather
   than the raw value expression; a later read of the same key resolves
   to that already-evaluated result exactly once, never re-run."
  (let ((aliases (list (cons pname ctor-fields)))
        (used-ops nil))
    (labels
        ((current-fields (alias) (cdr (assoc alias aliases)))
         (alias-names () (mapcar #'car aliases))
         (note-op (op) (pushnew op used-ops :test #'string=))
         (rw (n)
           (cond
             ;; A bare reference to any tracked alias, anywhere other than
             ;; the recognized shapes below, is an escape -- abort.
             ((and (fol.compiler.ast:symbol-ref-node-p n)
                   (assoc (fol.compiler.ast:symbol-ref-node-name n) aliases))
              (throw 'sr-intra-bind-fail nil))
             ;; (get alias :field) -> the field's current tracked value.
             ((and (fol.compiler.ast:call-node-p n)
                   (let ((op (fol.compiler.escape-analysis:operator-symbol n))
                         (args (fol.compiler.ast:call-node-args n)))
                     (and op (string= (symbol-name op) "GET")
                          (= 2 (length args))
                          (fol.compiler.ast:symbol-ref-node-p (first args))
                          (assoc (fol.compiler.ast:symbol-ref-node-name (first args)) aliases)
                          (fol.compiler.ast:literal-node-p (second args))
                          (keywordp (fol.compiler.ast:literal-node-value (second args))))))
              (let* ((args (fol.compiler.ast:call-node-args n))
                     (alias (fol.compiler.ast:symbol-ref-node-name (first args)))
                     (key (%sr-canon-key (fol.compiler.ast:literal-node-value (second args))))
                     (hit (assoc key (current-fields alias))))
                (if hit (progn (note-op "GET") (rw (cdr hit))) (throw 'sr-intra-bind-fail nil))))
             ;; Any other node type: REMAKE-NODE-WITH-CHILDREN only has
             ;; reconstruction methods for a handful of node types (call,
             ;; if, do, bind, fn, defn, loop, recur); for everything else
             ;; (notably VECTOR-NODE/DICT-NODE/SET-NODE) it silently
             ;; returns the original node unchanged, discarding whatever
             ;; RW would have computed for its children -- blindly
             ;; rewrite-then-reconstruct here would then silently keep a
             ;; stale reference to a dropped alias binding. So: recurse and
             ;; reconstruct normally (matching prior behavior exactly, e.g.
             ;; a plain call like `(inc (get p :x))` whose OUTER operator
             ;; isn't GET/ASSOC still needs its child rewritten) only for
             ;; the node types REMAKE-NODE-WITH-CHILDREN actually knows how
             ;; to reconstruct; otherwise fall back to the loop-carried
             ;; pass's own discipline (%SR-REWRITE-BODY's RW, ~line 4066):
             ;; abort only if a tracked alias is actually reachable in this
             ;; subtree, else pass the node through unchanged. (Checking
             ;; applicability via FIND-METHOD/COMPUTE-APPLICABLE-METHODS
             ;; would be more maintainable than this fixed list, but these
             ;; AST nodes are DEFSTRUCTs -- structure-classes -- and SBCL's
             ;; FIND-METHOD errors on a structure-class specializer, so an
             ;; explicit list it is.)
             ((or (fol.compiler.ast:call-node-p n) (fol.compiler.ast:if-node-p n)
                  (fol.compiler.ast:do-node-p n) (fol.compiler.ast:bind-node-p n)
                  (fol.compiler.ast:fn-node-p n) (fol.compiler.ast:defn-node-p n)
                  (fol.compiler.ast:loop-node-p n) (fol.compiler.ast:recur-node-p n))
              (fol.compiler.ast:remake-node-with-children
               n (mapcar #'rw (fol.compiler.escape-analysis:node-children n))))
             ((fol.compiler.escape-analysis:node-children n)
              (if (%sr-refs-alias-p n (alias-names))
                  (throw 'sr-intra-bind-fail nil)
                  n))
             (t n)))
         (chain-assoc-target (init)
           ;; (assoc alias :key val) with ALIAS tracked and (record mode)
           ;; :key a known field, or (dict mode) any literal keyword ->
           ;; (values alias key val), else NIL.
           (when (fol.compiler.ast:call-node-p init)
             (let ((op (fol.compiler.escape-analysis:operator-symbol init))
                   (args (fol.compiler.ast:call-node-args init)))
               (when (and op (string= (symbol-name op) "ASSOC")
                          (= 3 (length args))
                          (fol.compiler.ast:symbol-ref-node-p (first args))
                          (assoc (fol.compiler.ast:symbol-ref-node-name (first args)) aliases)
                          (fol.compiler.ast:literal-node-p (second args))
                          (keywordp (fol.compiler.ast:literal-node-value (second args))))
                 (let ((key (%sr-canon-key (fol.compiler.ast:literal-node-value (second args)))))
                   (when (or dict-p (assoc key fields))
                     (values (fol.compiler.ast:symbol-ref-node-name (first args)) key (third args))))))))
         (process-bindings (bs)
           (if (null bs)
               nil
               (let* ((b (car bs)) (bname (car b)) (init (cdr b)))
                 (if (symbolp bname)
                     (multiple-value-bind (alias key val) (chain-assoc-target init)
                       (if alias
                           (progn
                             (note-op "ASSOC")
                             (if dict-p
                                 ;; Dict mode: always mint a fresh scalar and
                                 ;; KEEP the binding (never inline the raw
                                 ;; value expression) -- see docstring.
                                 (let* ((scalar-var (intern (format nil "~A_~A" (symbol-name pname) (symbol-name key))
                                                             (symbol-package pname)))
                                        (new-val (rw val))
                                        (ref (fol.compiler.ast:make-symbol-ref-node :name scalar-var :form scalar-var)))
                                   (push (cons bname (cons (cons key ref)
                                                            (remove key (current-fields alias) :key #'car)))
                                         aliases)
                                   (cons (cons scalar-var new-val) (process-bindings (cdr bs))))
                                 ;; Record mode: pure bookkeeping, drop the binding.
                                 (let ((new-val (rw val)))
                                   (push (cons bname (cons (cons key new-val)
                                                            (remove key (current-fields alias) :key #'car)))
                                         aliases)
                                   (process-bindings (cdr bs)))))
                           (cons (cons bname (rw init)) (process-bindings (cdr bs)))))
                     (if (%sr-refs-alias-p init (alias-names))
                         (throw 'sr-intra-bind-fail nil)
                         (cons (cons bname (rw init)) (process-bindings (cdr bs))))))))
         (rebox (alias form)
           (if dict-p
               (fol.compiler.ast:make-dict-node
                :entries (loop for (sk . vnode) in (current-fields alias)
                               collect (cons (fol.compiler.ast:make-literal-node :value sk :form sk) vnode))
                :form form)
               (fol.compiler.ast:make-call-node
                :operator ctor-op
                :args (loop for (sk . sname) in fields
                            append (list (fol.compiler.ast:make-literal-node :value sk :form sk)
                                         (cdr (assoc sk (current-fields alias)))))
                :form form))))
      (catch 'sr-intra-bind-fail
        (let* ((new-rest (process-bindings rest-bindings))
               (new-body
                 (loop for rem on body-nodes
                       for form = (car rem)
                       collect (if (and (null (cdr rem))
                                         (fol.compiler.ast:symbol-ref-node-p form)
                                         (assoc (fol.compiler.ast:symbol-ref-node-name form) aliases))
                                   (rebox (fol.compiler.ast:symbol-ref-node-name form)
                                          (fol.compiler.ast:ast-node-form form))
                                   (rw form)))))
          (values new-rest new-body used-ops))))))

(defun sr-intra-bind-pass (node)
  "AST-to-AST pass for intra-bind scalar replacement. Walks the AST, finds
   qualifying bind nodes, and rewrites them. Returns (values NEW-NODE
   ASSUMPTIONS TRUST-CHECKS): ASSUMPTIONS feeds REGISTER-REGION/
   NOTE-REDEFINITION (a record class name in record mode, or the Tier-1 op
   names actually used in dict mode -- a dict has no class to redefine, but
   its GET/ASSOC are ordinary redefinable generics); TRUST-CHECKS is a list
   of (KIND . USED-OPS) conses for %REGISTER-REGION-TRUSTED-FORM's live
   load-time re-check, non-empty only in dict mode (record-mode ASR never
   invokes a user-overridable generic on the accumulator -- direct
   slot-value/assoc-with-known-target only -- so there is no
   method-combination hazard to re-check, unlike dict GET/ASSOC, which
   are)."
  (if (not (or fol.compiler.escape-analysis:*scalar-replacement*
               fol.compiler.escape-analysis:*dict-scalar-replacement*))
      (return-from sr-intra-bind-pass node))

  (labels ((scan-bindings (bindings body-nodes)
             ;; Left to right: the first binding whose init is a matching
             ;; record constructor, or (dict mode) a literal empty dict {},
             ;; attempts %SR-INTRA-BIND-CHAIN over everything after it.
             ;; Success splices in that binding's scalar fields plus the
             ;; chain's result and stops -- a second, independent
             ;; accumulator later in the same BIND is left unoptimized
             ;; (rarer than a single chain, and still correct, just less
             ;; optimized -- the same trade-off MAYBE-SCALAR-REPLACE-LOOP's
             ;; fixpoint budget documents). Failure or a non-qualifying
             ;; init keeps that one binding and recurses on the rest, so a
             ;; LATER independent accumulator still gets a chance.
             (if (null bindings)
                 (values nil body-nodes nil nil)
                 (let* ((b (car bindings)) (pname (car b)) (init (cdr b))
                        (type (and (symbolp pname) (fol.compiler.ast:call-node-p init)
                                   (infer-type-from-constructor init)))
                        (fields (and type (gethash type *global-type-info*)))
                        (ctor-fields (and fields (%sr-ctor-fields init))))
                   (cond
                     ((and fields ctor-fields (%sr-fields-match fields ctor-fields)
                           fol.compiler.escape-analysis:*scalar-replacement*)
                      (multiple-value-bind (chain-rest chain-body)
                          (%sr-intra-bind-chain pname fields ctor-fields
                                                 (fol.compiler.ast:call-node-operator init)
                                                 (cdr bindings) body-nodes)
                        (if chain-body
                            (let* ((fvar (loop for (sk . sname) in fields
                                               collect (cons sk (intern (format nil "~A_~A" (symbol-name pname) (symbol-name sname)) (symbol-package pname)))))
                                   (scalar-bindings (loop for (sk . sname) in fields
                                                          collect (cons (cdr (assoc sk fvar)) (cdr (assoc sk ctor-fields))))))
                              (values (append scalar-bindings chain-rest) chain-body (list (string type)) nil))
                            (multiple-value-bind (rest-b rest-body rest-a rest-tc) (scan-bindings (cdr bindings) body-nodes)
                              (values (cons b rest-b) rest-body rest-a rest-tc)))))
                     ((and fol.compiler.escape-analysis:*dict-scalar-replacement*
                           (symbolp pname)
                           (fol.compiler.ast:dict-node-p init)
                           (null (fol.compiler.ast:dict-node-entries init)))
                      (multiple-value-bind (chain-rest chain-body used-ops)
                          (%sr-intra-bind-chain pname nil nil nil (cdr bindings) body-nodes t)
                        (if (and chain-body used-ops)
                            (values chain-rest chain-body used-ops (list (cons :dict used-ops)))
                            (multiple-value-bind (rest-b rest-body rest-a rest-tc) (scan-bindings (cdr bindings) body-nodes)
                              (values (cons b rest-b) rest-body rest-a rest-tc)))))
                     (t (multiple-value-bind (rest-b rest-body rest-a rest-tc) (scan-bindings (cdr bindings) body-nodes)
                          (values (cons b rest-b) rest-body rest-a rest-tc))))))))
    (labels ((visit (n)
               (cond
                 ((fol.compiler.ast:bind-node-p n)
                  (multiple-value-bind (new-bindings new-body assumptions trust-checks)
                      (scan-bindings (fol.compiler.ast:bind-node-bindings n)
                                     (fol.compiler.ast:bind-node-body n))
                    (if assumptions
                        (multiple-value-bind (new-body-visited body-assumptions body-tc)
                            (visit-list new-body)
                          (values (fol.compiler.ast:make-bind-node
                                   :bindings new-bindings
                                   :body new-body-visited
                                   :form (fol.compiler.ast:ast-node-form n))
                                  (append assumptions body-assumptions)
                                  (append trust-checks body-tc)))
                        (multiple-value-bind (rewritten-children child-assumptions child-tc)
                            (visit-children n)
                          (values (fol.compiler.ast:remake-node-with-children n rewritten-children)
                                  child-assumptions child-tc)))))

                 (t (multiple-value-bind (rewritten-children child-assumptions child-tc)
                        (visit-children n)
                      (values (fol.compiler.ast:remake-node-with-children n rewritten-children)
                              child-assumptions child-tc)))))
             (visit-list (ns)
               ;; VISIT each of NS, collecting the rewritten nodes plus
               ;; every assumption/trust-check any of them produced.
               (let ((all-assumptions nil) (all-tc nil))
                 (values (mapcar (lambda (c)
                                    (multiple-value-bind (rewritten a tc) (visit c)
                                      (setf all-assumptions (append a all-assumptions))
                                      (setf all-tc (append tc all-tc))
                                      rewritten))
                                  ns)
                         all-assumptions all-tc)))
             (visit-children (n)
               ;; A nested qualifying BIND (e.g. a `defn`'s body, or any
               ;; other non-bind ancestor) must still surface its
               ;; assumptions to the top-level caller (COMPILE-FORM),
               ;; which is what actually wraps the world-guard around the
               ;; whole form -- an earlier version of this function
               ;; discarded every child's assumptions via a plain MAPCAR,
               ;; so a converted loop nested one level below the top-level
               ;; form (the overwhelmingly common shape: a `defn` whose
               ;; body is a `bind`) got scalar-replaced with NO world-guard
               ;; at all, silently continuing to run the stale unboxed
               ;; fast path forever after a class redefinition that should
               ;; have invalidated it.
               (visit-list (fol.compiler.escape-analysis:node-children n))))
      (visit node))))

(defun %sr-replace-one (node)
  "Unbox the first qualifying record accumulator in loop NODE. Returns
   (values NEW-NODE ASSUMPTIONS) on success, or (values NIL NIL) if no loop
   parameter can be unboxed. Scans bindings in order; each attempt either
   succeeds (returning the rewritten loop) or leaves NODE untouched."
  (loop for (pname . init) in (fol.compiler.ast:loop-node-bindings node)
        for pos from 0
        do (when (and (symbolp pname)
                      (fol.compiler.ast:call-node-p init)
                      (infer-type-from-constructor init))
             (multiple-value-bind (result assumptions)
                 (%sr-try-accumulator node pname pos init)
               (when result
                 (return-from %sr-replace-one (values result assumptions))))))
  (values nil nil))

(defun maybe-scalar-replace-loop (node)
  "When *SCALAR-REPLACEMENT* is on, unbox every record accumulator of loop NODE
   whose uses all fit the recognized shapes (field read, reconstruction feeding
   recur, tail re-box), one scalar loop var per field. Returns (values
   REWRITTEN-LOOP ASSUMPTIONS), where ASSUMPTIONS is the list of record
   class-name strings the rewrite depends on (for the world guard), or
   (values NODE NIL) if nothing was unboxed.

   Multiple accumulators are handled by fixpoint: %SR-REPLACE-ONE unboxes one
   accumulator at a time, leaving the rest as ordinary boxed loop vars; because
   recur lowers to a parallel PSETQ, cross-references between accumulators
   resolve to the other's scalar vars as each is unboxed in turn, so coupled
   accumulators (p reads q, q reads p) stay correct. An accumulator that fails
   to qualify is simply left boxed (partial replacement)."
  (if (not fol.compiler.escape-analysis:*scalar-replacement*)
      (values node nil)
      (let ((current node)
            (all-assumptions '())
            (any nil)
            ;; Safety backstop against pathological nesting; each successful
            ;; pass unboxes one accumulator, and real loops carry a handful.
            ;; Stopping early only yields a less-optimized (still correct) loop.
            (budget 128))
        (loop
          (when (<= budget 0) (return))
          (decf budget)
          (multiple-value-bind (next assumptions) (%sr-replace-one current)
            (if next
                (setf current next
                      all-assumptions (union all-assumptions assumptions
                                             :test #'string=)
                      any t)
                (return))))
        (if any
            (values current all-assumptions)
            (values node nil)))))

(defun %sr-try-accumulator (loop-node pname pos init)
  "Attempt to unbox loop accumulator PNAME (at binding POS, initialized by the
   constructor call INIT). Returns (values NEW-LOOP-NODE ASSUMPTIONS) on
   success, or NIL if the accumulator's uses do not all fit the recognized
   shapes."
  (let* ((type (infer-type-from-constructor init))
         (fields (and type (gethash type *global-type-info*)))   ; ((:K . slot) ...)
         (ctor-fields (and fields (%sr-ctor-fields init))))
    (when (and fields ctor-fields (%sr-fields-match fields ctor-fields))
      (let* ((ctor-op (fol.compiler.ast:call-node-operator init))
             (fvar (loop for (sk . sname) in fields
                         collect (cons sk (intern (format nil "~A_~A"
                                                          (symbol-name pname)
                                                          (symbol-name sname))
                                                  (symbol-package pname)))))
             (assumptions (list (string type))))
        (catch 'sr-fail
          (let* ((new-body (%sr-rewrite-body (fol.compiler.ast:loop-node-body loop-node)
                                             pname pos fields fvar ctor-op))
                 (new-bindings
                   (loop for b in (fol.compiler.ast:loop-node-bindings loop-node)
                         for i from 0
                         append (if (= i pos)
                                    (loop for (sk . sname) in fields
                                          collect (cons (cdr (assoc sk fvar))
                                                        (cdr (assoc sk ctor-fields))))
                                    (list b)))))
            (return-from %sr-try-accumulator
              (values (fol.compiler.ast:make-loop-node
                       :bindings new-bindings
                       :body new-body
                       :form (fol.compiler.ast:ast-node-form loop-node))
                      assumptions))))
        nil))))

(defun %sr-rewrite-body (body-nodes pname pos fields fvar ctor-op)
  "Single-pass classify+rewrite of a loop body for accumulator PNAME. FIELDS is
   the registry field list ((:K . slot)...); FVAR maps :K -> scalar var symbol;
   CTOR-OP is the make-<T> operator node reused for re-boxing. Throws SR-FAIL on
   any accumulator use outside the recognized set."
  (labels
      ((fvar-for (sk) (cdr (assoc sk fvar)))
       (fail () (throw 'sr-fail nil))
       (aliasp (n aliases)
         (and (fol.compiler.ast:symbol-ref-node-p n)
              (member (fol.compiler.ast:symbol-ref-node-name n) aliases)))
       (field-node (alias sk overrides)
         ;; The current value-expression for field SK of ALIAS: an override
         ;; (an inlined callee's parameter bound to a reconstructed, non-
         ;; passthrough record -- see the inlinable-callee case below) if one
         ;; is in scope, else the shared scalar field variable.
         (let ((ov (cdr (assoc alias overrides))))
           (if ov
               (cdr (assoc sk ov))
               (fol.compiler.ast:make-symbol-ref-node
                :name (fvar-for sk) :form (fvar-for sk)))))
       (rebox (form)
         ;; Re-materialize the record from the current field vars.
         (fol.compiler.ast:make-call-node
          :operator ctor-op
          :args (loop for (sk . sname) in fields
                      append (list (fol.compiler.ast:make-literal-node :value sk :form sk)
                                   (fol.compiler.ast:make-symbol-ref-node
                                    :name (fvar-for sk) :form (fvar-for sk))))
          :form form))
       (get-of-alias (call aliases)
         ;; (get X :k) with X an alias -> canonical :k if it names a field.
         (let ((op (fol.compiler.escape-analysis:operator-symbol call))
               (args (fol.compiler.ast:call-node-args call)))
           (when (and op (string= (symbol-name op) "GET")
                      (= 2 (length args))
                      (aliasp (first args) aliases)
                      (fol.compiler.ast:literal-node-p (second args))
                      (keywordp (fol.compiler.ast:literal-node-value (second args))))
             (let ((k (%sr-canon-key (fol.compiler.ast:literal-node-value (second args)))))
               (if (assoc k fields) k (fail))))))
       (assoc-alias-p (a aliases)
         ;; True when A has shape (assoc X :k1 v1 ...) with X an alias and
         ;; every key a literal keyword naming a real field. Side-effect-free
         ;; (never FAILs) so it can be used to probe candidate arguments.
         (and (fol.compiler.ast:call-node-p a)
              (let ((op (fol.compiler.escape-analysis:operator-symbol a)))
                (and op (string= (symbol-name op) "ASSOC")))
              (aliasp (first (fol.compiler.ast:call-node-args a)) aliases)
              (let ((kvs (rest (fol.compiler.ast:call-node-args a))))
                (and (evenp (length kvs))
                     (loop for (k v) on kvs by #'cddr
                           always (and (fol.compiler.ast:literal-node-p k)
                                       (keywordp (fol.compiler.ast:literal-node-value k))
                                       (assoc (%sr-canon-key
                                               (fol.compiler.ast:literal-node-value k))
                                              fields)))))))
       (wrap-layers (inner layers)
         ;; LAYERS is a list of binding-lists, outermost first.
         (if (null layers)
             inner
             (fol.compiler.ast:make-bind-node
              :bindings (first layers)
              :body (list (wrap-layers inner (rest layers)))
              :form (fol.compiler.ast:ast-node-form inner))))
       (expand-acc (n aliases wrappers overrides)
         ;; Return (values FIELD-VALUE-NODES WRAPPER-LAYERS) for a recur-position
         ;; reconstruction of the accumulator, or throw.
         (cond
           ;; passthrough: the accumulator itself
           ((aliasp n aliases)
            (values (loop for (sk . sname) in fields
                          collect (field-node (fol.compiler.ast:symbol-ref-node-name n)
                                               sk overrides))
                    wrappers))
           ;; inlinable object-returning callee: (f ... acc ...) or
           ;; (f ... (assoc acc :k v ...) ...) -- the accumulator argument may
           ;; be a bare alias (pure pass-through) or a single-level assoc
           ;; reconstruction of one; every other argument must still be trivial.
           ((and (fol.compiler.ast:call-node-p n)
                 (let ((op (fol.compiler.escape-analysis:operator-symbol n)))
                   (and op (gethash op *sr-inlinable-fns*))))
            (let* ((op (fol.compiler.escape-analysis:operator-symbol n))
                   (entry (gethash op *sr-inlinable-fns*))
                   (params (car entry))
                   (fbody (cdr entry))
                   (cargs (fol.compiler.ast:call-node-args n))
                   (bare-idx (position-if (lambda (a) (aliasp a aliases)) cargs))
                   (assoc-idx (position-if (lambda (a) (assoc-alias-p a aliases)) cargs))
                   (acc-idx (or bare-idx assoc-idx)))
              (unless (and acc-idx
                           (= (length params) (length cargs))
                           (= 1 (+ (count-if (lambda (a) (aliasp a aliases)) cargs)
                                   (count-if (lambda (a) (assoc-alias-p a aliases)) cargs)))
                           (every (lambda (a) (or (fol.compiler.ast:symbol-ref-node-p a)
                                                  (fol.compiler.ast:literal-node-p a)
                                                  (assoc-alias-p a aliases)))
                                  cargs))
                (fail))
              (let* ((record-param (nth acc-idx params))
                     (acc-arg (nth acc-idx cargs))
                     (new-aliases (cons record-param aliases))
                     (param-layer (loop for p in params
                                        for a in cargs
                                        for i from 0
                                        unless (= i acc-idx)
                                        collect (cons p (rw a nil aliases overrides nil)))))
                ;; record-param must not collide with a scalar field var, or the
                ;; get-rewrite would be ambiguous. (Colliding with an existing
                ;; alias -- e.g. the callee's param is also named P -- is fine;
                ;; it denotes the same accumulator.)
                (when (rassoc record-param fvar) (fail))
                (multiple-value-bind (new-wrappers new-overrides)
                    (if bare-idx
                        ;; pure pass-through: no override needed, falls back
                        ;; to the shared field vars via field-node.
                        (values wrappers overrides)
                        ;; assoc-wrapped: reconstruct the inner fields and pin
                        ;; any non-trivial one to a fresh, single-evaluation
                        ;; scalar var so it can't be duplicated on reuse.
                        (multiple-value-bind (inner-fields inner-wrappers)
                            (expand-acc acc-arg aliases wrappers overrides)
                          (let (fresh-bindings)
                            (let ((field-ov
                                    (loop for (sk . sname) in fields
                                          for v in inner-fields
                                          collect
                                          (if (or (fol.compiler.ast:symbol-ref-node-p v)
                                                  (fol.compiler.ast:literal-node-p v))
                                              (cons sk v)
                                              (let ((fresh
                                                      (intern
                                                       (format nil "~A_~A"
                                                               (symbol-name record-param)
                                                               (symbol-name sname))
                                                       (symbol-package record-param))))
                                                (push (cons fresh v) fresh-bindings)
                                                (cons sk (fol.compiler.ast:make-symbol-ref-node
                                                          :name fresh :form fresh)))))))
                              (values (if fresh-bindings
                                          (append inner-wrappers
                                                  (list (nreverse fresh-bindings)))
                                          inner-wrappers)
                                      (cons (cons record-param field-ov) overrides))))))
                  (expand-acc fbody new-aliases
                              (if param-layer (append new-wrappers (list param-layer)) new-wrappers)
                              new-overrides)))))
           ;; explicit constructor: make-<T> with all fields
           ((and (fol.compiler.ast:call-node-p n)
                 (fol.compiler.escape-analysis:operator-symbol n)
                 (string= (symbol-name (fol.compiler.escape-analysis:operator-symbol n))
                          (symbol-name (fol.compiler.ast:symbol-ref-node-name ctor-op))))
            (let ((cf (%sr-ctor-fields n)))
              (unless (and cf (%sr-fields-match fields cf)) (fail))
              (values (loop for (sk . sname) in fields
                            collect (rw (cdr (assoc sk cf)) nil aliases overrides nil))
                      wrappers)))
           ;; partial reconstruction via assoc: (assoc X :k1 v1 :k2 v2 ...)
           ((and (fol.compiler.ast:call-node-p n)
                 (let ((op (fol.compiler.escape-analysis:operator-symbol n)))
                   (and op (string= (symbol-name op) "ASSOC")))
                 (aliasp (first (fol.compiler.ast:call-node-args n)) aliases))
            (let ((kvs (rest (fol.compiler.ast:call-node-args n)))
                  (base-alias (fol.compiler.ast:symbol-ref-node-name
                               (first (fol.compiler.ast:call-node-args n)))))
              (unless (evenp (length kvs)) (fail))
              (let ((updates
                      (loop for (k v) on kvs by #'cddr
                            collect (progn
                                      (unless (and (fol.compiler.ast:literal-node-p k)
                                                   (keywordp (fol.compiler.ast:literal-node-value k)))
                                        (fail))
                                      (let ((sk (%sr-canon-key (fol.compiler.ast:literal-node-value k))))
                                        (unless (assoc sk fields) (fail))
                                        (cons sk v))))))
                (values (loop for (sk . sname) in fields
                              collect (let ((upd (assoc sk updates)))
                                        (if upd
                                            (rw (cdr upd) nil aliases overrides nil)
                                            (field-node base-alias sk overrides))))
                        wrappers))))
           ;; single-form bind/do wrapper around the reconstruction
           ((and (fol.compiler.ast:bind-node-p n)
                 (= 1 (length (fol.compiler.ast:bind-node-body n))))
            (let ((layer (loop for b in (fol.compiler.ast:bind-node-bindings n)
                               do (when (or (not (symbolp (car b)))
                                            (rassoc (car b) fvar)
                                            (member (car b) aliases))
                                    (fail))
                               collect (cons (car b) (rw (cdr b) nil aliases overrides nil)))))
              (expand-acc (first (fol.compiler.ast:bind-node-body n))
                          aliases (append wrappers (list layer)) overrides)))
           ((and (fol.compiler.ast:do-node-p n)
                 (fol.compiler.ast:do-node-body n)
                 (= 1 (length (fol.compiler.ast:do-node-body n))))
            (expand-acc (car (fol.compiler.ast:do-node-body n)) aliases wrappers overrides))
           ;; --- conditional reconstruction ---
           ((fol.compiler.ast:if-node-p n)
            (let* ((test-node (fol.compiler.ast:if-node-test n))
                   (then-node (fol.compiler.ast:if-node-then n))
                   (else-node (if (fol.compiler.ast:if-node-else n)
                                  (first (fol.compiler.ast:if-node-else n))
                                  ;; An implicit else is a pass-through of the accumulator
                                  (fol.compiler.ast:make-symbol-ref-node :name pname :form pname)))
                   (rewritten-test (rw test-node nil aliases overrides nil)))
              (multiple-value-bind (then-scalars then-wrappers)
                  (expand-acc then-node aliases wrappers overrides)
                (multiple-value-bind (else-scalars else-wrappers)
                    (expand-acc else-node aliases wrappers overrides)
                  (when (or then-wrappers else-wrappers) (fail)) ; wrappers inside branches not yet supported
                  (values (loop for then-s in then-scalars
                                for else-s in else-scalars
                                collect (fol.compiler.ast:make-if-node
                                         :test rewritten-test
                                         :then then-s
                                         :else (list else-s)
                                         :form (fol.compiler.ast:ast-node-form n)))
                          wrappers)))))
           ((fol.compiler.ast:cond-node-p n)
            (let ((clause-scalars-transposed
                   (mapcar (lambda (clause)
                             (multiple-value-bind (scalars clause-wrappers)
                                 (expand-acc (first (cdr clause)) aliases wrappers overrides)
                               (when clause-wrappers (fail)) ; wrappers inside branches not yet supported
                               scalars))
                           (fol.compiler.ast:cond-node-clauses n))))
              (values (loop for i from 0 below (length fields)
                            collect (fol.compiler.ast:make-cond-node
                                     :clauses (mapcar (lambda (clause-list clause-nodes)
                                                        (cons (rw (car clause-nodes) nil aliases overrides nil)
                                                              (list (nth i clause-list))))
                                                      clause-scalars-transposed (fol.compiler.ast:cond-node-clauses n))
                                     :form (fol.compiler.ast:ast-node-form n)))
                      wrappers)))
           ((fol.compiler.ast:case-node-p n)
            (let ((clause-scalars-transposed
                   (mapcar (lambda (clause)
                             (multiple-value-bind (scalars clause-wrappers)
                                 (expand-acc (first (cdr clause)) aliases wrappers overrides)
                               (when clause-wrappers (fail)) ; wrappers inside branches not yet supported
                               scalars))
                           (fol.compiler.ast:case-node-clauses n))))
              (values (loop for i from 0 below (length fields)
                            collect (fol.compiler.ast:make-case-node
                                     :expr (rw (fol.compiler.ast:case-node-expr n) nil aliases overrides nil)
                                     ;; clause keys are literal match values, not
                                     ;; expressions -- unlike cond's tests, they
                                     ;; are carried through unrewritten.
                                     :clauses (mapcar (lambda (clause-list clause-nodes)
                                                        (cons (car clause-nodes) (list (nth i clause-list))))
                                                      clause-scalars-transposed (fol.compiler.ast:case-node-clauses n))
                                     :form (fol.compiler.ast:ast-node-form n)))
                      wrappers)))
           (t (fail))))
       (rw-list (ns tailp aliases overrides nested-p)
         (loop for rest on ns
               collect (rw (car rest) (and tailp (null (cdr rest))) aliases overrides nested-p)))
       (rw (n tailp aliases overrides nested-p)
         (cond
           ((null n) n)
           ;; --- accumulator reference: NESTED-P forces FAIL regardless of
           ;; tail position -- the accumulator escaping into or through a
           ;; nested loop is out of scope; only reading its fields (the
           ;; (get acc :k) case below) is supported there. ---
           ((and (fol.compiler.ast:symbol-ref-node-p n)
                 (member (fol.compiler.ast:symbol-ref-node-name n) aliases))
            (if (and tailp (not nested-p)) (rebox (fol.compiler.ast:ast-node-form n)) (fail)))
           ((fol.compiler.ast:symbol-ref-node-p n) n)
           ((fol.compiler.ast:literal-node-p n) n)
           ((fol.compiler.ast:quote-node-p n) n)
           ;; --- recur: expand the accumulator position, UNLESS this recur
           ;; targets a nested loop (NESTED-P), in which case it has nothing
           ;; to do with the outer accumulator and is rewritten like an
           ;; ordinary call. ---
           ((and (fol.compiler.ast:recur-node-p n) (not nested-p))
            (let ((wrappers nil))
              (let ((new-args
                      (loop for arg in (fol.compiler.ast:recur-node-args n)
                            for i from 0
                            append (if (= i pos)
                                       (multiple-value-bind (fnodes w)
                                           (expand-acc arg aliases nil overrides)
                                         (setf wrappers w)
                                         fnodes)
                                       (list (rw arg nil aliases overrides nested-p))))))
                (wrap-layers
                 (fol.compiler.ast:make-recur-node
                  :args new-args :form (fol.compiler.ast:ast-node-form n))
                 wrappers))))
           ((fol.compiler.ast:recur-node-p n)
            (fol.compiler.ast:make-recur-node
             :args (mapcar (lambda (a) (rw a nil aliases overrides nested-p))
                           (fol.compiler.ast:recur-node-args n))
             :form (fol.compiler.ast:ast-node-form n)))
           ;; --- a nested loop: read-only access to the outer accumulator's
           ;; fields is supported (via the (get acc :k) case, reached by
           ;; recursing with NESTED-P true); a bare accumulator reference
           ;; anywhere inside still FAILs via the case above. Binding inits
           ;; are evaluated in the outer scope, so they keep the current
           ;; NESTED-P unchanged. ---
           ((fol.compiler.ast:loop-node-p n)
            (dolist (b (fol.compiler.ast:loop-node-bindings n))
              (when (and (symbolp (car b)) (member (car b) aliases)) (fail)))
            (fol.compiler.ast:make-loop-node
             :bindings (mapcar (lambda (b) (cons (car b) (rw (cdr b) nil aliases overrides nested-p)))
                               (fol.compiler.ast:loop-node-bindings n))
             :body (rw-list (fol.compiler.ast:loop-node-body n) t aliases overrides t)
             :form (fol.compiler.ast:ast-node-form n)))
           ;; --- (get acc :k) field read ---
           ((and (fol.compiler.ast:call-node-p n) (get-of-alias n aliases))
            (let* ((sk (get-of-alias n aliases))
                   (alias-name (fol.compiler.ast:symbol-ref-node-name
                                (first (fol.compiler.ast:call-node-args n)))))
              (field-node alias-name sk overrides)))
           ;; --- general call: rewrite children (a bare alias arg fails) ---
           ((fol.compiler.ast:call-node-p n)
            (fol.compiler.ast:make-call-node
             :operator (rw (fol.compiler.ast:call-node-operator n) nil aliases overrides nested-p)
             :args (mapcar (lambda (a) (rw a nil aliases overrides nested-p))
                           (fol.compiler.ast:call-node-args n))
             :form (fol.compiler.ast:ast-node-form n)))
           ((fol.compiler.ast:if-node-p n)
            (fol.compiler.ast:make-if-node
             :test (rw (fol.compiler.ast:if-node-test n) nil aliases overrides nested-p)
             :then (rw (fol.compiler.ast:if-node-then n) tailp aliases overrides nested-p)
             :else (rw-list (fol.compiler.ast:if-node-else n) tailp aliases overrides nested-p)
             :form (fol.compiler.ast:ast-node-form n)))
           ((fol.compiler.ast:do-node-p n)
            (fol.compiler.ast:make-do-node
             :body (rw-list (fol.compiler.ast:do-node-body n) tailp aliases overrides nested-p)
             :form (fol.compiler.ast:ast-node-form n)))
           ((fol.compiler.ast:bind-node-p n)
            (dolist (b (fol.compiler.ast:bind-node-bindings n))
              (when (and (symbolp (car b)) (member (car b) aliases)) (fail)))
            (fol.compiler.ast:make-bind-node
             :bindings (mapcar (lambda (b) (cons (car b) (rw (cdr b) nil aliases overrides nested-p)))
                               (fol.compiler.ast:bind-node-bindings n))
             :body (rw-list (fol.compiler.ast:bind-node-body n) tailp aliases overrides nested-p)
             :form (fol.compiler.ast:ast-node-form n)))
           ((fol.compiler.ast:cond-node-p n)
            (fol.compiler.ast:make-cond-node
             :clauses (mapcar (lambda (c)
                                (cons (if (fol.compiler.ast:ast-node-p (car c))
                                          (rw (car c) nil aliases overrides nested-p)
                                          (car c))
                                      (rw-list (cdr c) tailp aliases overrides nested-p)))
                              (fol.compiler.ast:cond-node-clauses n))
             :form (fol.compiler.ast:ast-node-form n)))
           ((fol.compiler.ast:case-node-p n)
            (fol.compiler.ast:make-case-node
             :expr (rw (fol.compiler.ast:case-node-expr n) nil aliases overrides nested-p)
             :clauses (mapcar (lambda (c) (cons (car c) (rw-list (cdr c) tailp aliases overrides nested-p)))
                              (fol.compiler.ast:case-node-clauses n))
             :form (fol.compiler.ast:ast-node-form n)))
           ;; --- everything else: safe only if it never touches the accumulator ---
           (t (if (%sr-refs-alias-p n aliases) (fail) n)))))
    (rw-list body-nodes t (list pname) nil nil)))

(defun emit-loop (node)
  "Emit a loop node. Scalar replacement is tried first: when a record
   accumulator is unboxed, the converted loop is emitted behind a world-guard
   registered on the record class name(s), with the original allocating loop as
   the fallback. Otherwise the transient-conversion dual path applies: a
   qualifying accumulator is converted behind a validity-cell check registered
   against the conversion's summarized-name assumptions. If a profitability
   heuristic is available, it is ANDed with the validity check. *sealed-world*
   skips the guard for batch snapshots."
  (multiple-value-bind (sr-node sr-assumptions) (maybe-scalar-replace-loop node)
    (cond
      ;; --- 1. Scalar replacement applied ---
      ((not (eq sr-node node))
       (if fol.compiler.world:*sealed-world*
           (emit-loop-1 sr-node)
           (let ((validity-check `(cl:car (cl:load-time-value
                                           (fol.compiler.world:register-region ',sr-assumptions)
                                           cl:t))))
             `(cl:if ,validity-check ; world guard
                     ,(emit-loop-1 sr-node) ; fast path
                     ,(emit-loop-1 node))))) ; fallback
      ;; --- 2. Transient conversion ---
      (t
       (multiple-value-bind (converted assumptions profit-check profit-binding trust-checks)
           (fol.compiler.escape-analysis:maybe-transient-loop node)
         (cond
           ;; No conversion applicable
           ((eq converted node) (emit-loop-1 node))
           ;; Sealed world: emit only the fast path
           (fol.compiler.world:*sealed-world* (emit-loop-1 converted))
           ;; Open world: emit dual path with world guard and profitability check
           (t (let* ((validity-check `(cl:car (cl:load-time-value
                                               ,(%register-region-trusted-form assumptions trust-checks)
                                               cl:t)))
                     (dual `(cl:if ,(if profit-check
                                        `(cl:and ,validity-check ,profit-check)
                                        validity-check)
                                   ,(emit-loop-1 converted)
                                   ,(emit-loop-1 node))))
                ;; The profitability check references the accumulator, which is
                ;; bound only inside each loop; bind its initial value in an
                ;; outer LET so the guard can read it. Each loop still binds and
                ;; owns its own copy (this outer binding is shadowed within).
                (if profit-binding
                    `(cl:let ((,(car profit-binding) ,(emit-node (cdr profit-binding))))
                       ,dual)
                    dual)))))))))

;;; ============================================================================
;;; Numeric type inference + arithmetic specialization (flow inference, #1)
;;; ============================================================================
;;;
;;; Seeds loop-variable types from literal initializers, propagates through
;;; arithmetic to a fixpoint, then (a) rewrites generic operators on proven-
;;; number operands to CL operators, bypassing generic dispatch, and (b) emits
;;; CL type declarations for float/integer-typed loop variables so SBCL emits
;;; unboxed machine arithmetic. Opt-in via *numeric-specialization*; sound (an
;;; op is rewritten only when every operand is proven numeric -- FOL's scalar
;;; +,-,*,/,inc,dec,<,... are defined to equal the CL operators on numbers --
;;; and a variable is declared only when its inferred type is proven and stable).
;;;
;;; Type domain (CL type symbols): DOUBLE-FLOAT, SINGLE-FLOAT, INTEGER, NUMBER,
;;; or NIL = "not proven a number". Floats propagate soundly (float op float is
;;; that float); integers stay INTEGER under +,-,* (INT/INT is rational -> NUMBER).

(defparameter +cl-num-op+
  '(("+" . cl:+) ("-" . cl:-) ("*" . cl:*) ("/" . cl:/)
    ("<" . cl:<) (">" . cl:>) ("<=" . cl:<=) (">=" . cl:>=)
    ("=" . cl:=) ("/=" . cl:/=) ("INC" . cl:1+) ("DEC" . cl:1-))
  "FOL numeric-op name -> CL operator symbol to emit when all operands are numbers.")

(defparameter +num-value-ops+ '("+" "-" "*" "/" "INC" "DEC")
  "Ops whose result is itself a number (so they contribute to type inference).")

(defun %num-type-of-literal (v)
  (typecase v
    (double-float 'double-float)
    (single-float 'single-float)
    (integer      'integer)
    (number       'number)          ; ratio, complex: a number, no fine unboxed type
    (t            nil)))

(defun %num-contagion (a b)
  "Result type of +,-,* on operand types A and B."
  (cond ((or (null a) (null b))                         nil)
        ((or (eq a 'number) (eq b 'number))             'number)
        ((or (eq a 'double-float) (eq b 'double-float)) 'double-float)
        ((or (eq a 'single-float) (eq b 'single-float)) 'single-float)
        (t                                              'integer)))

(defun %num-div (a b)
  "Result type of / on A and B (integer/integer is rational, not integer)."
  (cond ((or (null a) (null b))                         nil)
        ((or (eq a 'number) (eq b 'number))             'number)
        ((or (eq a 'double-float) (eq b 'double-float)) 'double-float)
        ((or (eq a 'single-float) (eq b 'single-float)) 'single-float)
        (t                                              'number)))

(defun %num-lub (a b)
  "Least upper bound of a variable's possible types across init and recur paths."
  (cond ((eq a b)                a)
        ((or (null a) (null b))  nil)     ; ever-unknown => unknown
        (t                       'number)))  ; mixed fine types => just NUMBER

(defun %num-copy-env (env)
  (let ((h (make-hash-table :test 'eq)))
    (maphash (lambda (k v) (setf (gethash k h) v)) env) h))

(defun %num-infer (node env)
  "Infer the numeric type of NODE under type env ENV (symbol -> type). NIL if
   NODE is not a proven number."
  (cond
    ((null node) nil)
    ((fol.compiler.ast:literal-node-p node)
     (%num-type-of-literal (fol.compiler.ast:literal-node-value node)))
    ((fol.compiler.ast:symbol-ref-node-p node)
     (gethash (fol.compiler.ast:symbol-ref-node-name node) env))
    ((fol.compiler.ast:call-node-p node)
     (let ((op (fol.compiler.escape-analysis:operator-symbol node)))
       (when op
         (let ((nm (symbol-name op))
               (args (fol.compiler.ast:call-node-args node)))
           (cond
             ((or (string= nm "INC") (string= nm "DEC")) (%num-infer (first args) env))
             ((member nm +num-value-ops+ :test #'string=)
              (let ((ts (mapcar (lambda (a) (%num-infer a env)) args)))
                (cond ((null ts) (if (string= nm "/") nil 'integer))
                      ((string= nm "/") (reduce #'%num-div ts))
                      (t (reduce #'%num-contagion ts)))))
             (t nil))))))                 ; comparisons/other: not a number value
    ((fol.compiler.ast:bind-node-p node)
     (let ((env2 (%num-copy-env env)))
       (dolist (b (fol.compiler.ast:bind-node-bindings node))
         (when (symbolp (car b))
           (setf (gethash (car b) env2) (%num-infer (cdr b) env2))))
       (%num-infer (car (last (fol.compiler.ast:bind-node-body node))) env2)))
    ((fol.compiler.ast:do-node-p node)
     (%num-infer (car (last (fol.compiler.ast:do-node-body node))) env))
    (t nil)))

(defun %num-collect-recur-types (body env)
  "Walk BODY under scope ENV; at each recur (that targets this loop) infer each
   arg's type under the enclosing bind scope. Returns a hash position -> LUB type."
  (let ((acc (make-hash-table :test 'eql)))
    (labels ((w (n scope)
               (cond
                 ((null n) nil)
                 ((fol.compiler.ast:recur-node-p n)
                  (loop for arg in (fol.compiler.ast:recur-node-args n)
                        for k from 0
                        do (let ((ty (%num-infer arg scope)))
                             (multiple-value-bind (old present) (gethash k acc)
                               (setf (gethash k acc) (if present (%num-lub old ty) ty))))))
                 ((or (fol.compiler.ast:loop-node-p n) (fol.compiler.ast:fn-node-p n)) nil)
                 ((fol.compiler.ast:bind-node-p n)
                  (let ((scope2 (%num-copy-env scope)))
                    (dolist (b (fol.compiler.ast:bind-node-bindings n))
                      (when (symbolp (car b))
                        (setf (gethash (car b) scope2) (%num-infer (cdr b) scope2))))
                    (dolist (bf (fol.compiler.ast:bind-node-body n)) (w bf scope2))))
                 (t (dolist (c (fol.compiler.escape-analysis:node-children n)) (w c scope))))))
      (dolist (f body) (w f env)))
    acc))

(defun %num-infer-loop-env (loop-node)
  "Fixpoint numeric types for LOOP-NODE's loop variables (symbol -> type)."
  (let* ((bindings (fol.compiler.ast:loop-node-bindings loop-node))
         (names (mapcar #'car bindings))
         (inits (make-hash-table :test 'eq))
         (env (make-hash-table :test 'eq))
         (body (fol.compiler.ast:loop-node-body loop-node)))
    (loop for (name . init) in bindings do
      (let ((ty (%num-infer init env)))
        (setf (gethash name inits) ty (gethash name env) ty)))
    (dotimes (_ 16)
      (let ((acc (%num-collect-recur-types body env)) (changed nil))
        (loop for name in names for k from 0 do
          (let ((new (multiple-value-bind (rty present) (gethash k acc)
                       (if present (%num-lub (gethash name inits) rty)
                           (gethash name inits)))))
            (unless (eq new (gethash name env))
              (setf (gethash name env) new changed t))))
        (unless changed (return))))
    env))

(defun %num-specialize (node env)
  "Return NODE with generic numeric ops on proven-number operands rewritten to CL
   operators. Functional (AST nodes are immutable); does not descend into nested
   loops or fns."
  (labels ((sp (n) (%num-specialize n env))
           (form-of (n) (fol.compiler.ast:ast-node-form n)))
    (cond
      ((null node) nil)
      ((fol.compiler.ast:call-node-p node)
       (let* ((op (fol.compiler.escape-analysis:operator-symbol node))
              (nm (and op (symbol-name op)))
              (pair (and nm (assoc nm +cl-num-op+ :test #'string=)))
              (args (fol.compiler.ast:call-node-args node))
              (new-args (mapcar #'sp args)))
         (if (and pair args (every (lambda (a) (%num-infer a env)) args))
             (fol.compiler.ast:make-call-node
              :operator (fol.compiler.ast:make-symbol-ref-node :name (cdr pair) :form (cdr pair))
              :args new-args :form (form-of node))
             (fol.compiler.ast:make-call-node
              :operator (sp (fol.compiler.ast:call-node-operator node))
              :args new-args :form (form-of node)))))
      ((fol.compiler.ast:if-node-p node)
       (fol.compiler.ast:make-if-node
        :test (sp (fol.compiler.ast:if-node-test node))
        :then (sp (fol.compiler.ast:if-node-then node))
        :else (mapcar #'sp (fol.compiler.ast:if-node-else node))
        :form (form-of node)))
      ((fol.compiler.ast:do-node-p node)
       (fol.compiler.ast:make-do-node
        :body (mapcar #'sp (fol.compiler.ast:do-node-body node)) :form (form-of node)))
      ((fol.compiler.ast:bind-node-p node)
       (let ((env2 (%num-copy-env env)))
         (fol.compiler.ast:make-bind-node
          :bindings (loop for b in (fol.compiler.ast:bind-node-bindings node)
                          collect (let ((v (%num-specialize (cdr b) env2)))
                                    (when (symbolp (car b))
                                      (setf (gethash (car b) env2) (%num-infer (cdr b) env2)))
                                    (cons (car b) v)))
          :body (mapcar (lambda (bf) (%num-specialize bf env2))
                        (fol.compiler.ast:bind-node-body node))
          :form (form-of node))))
      ((fol.compiler.ast:recur-node-p node)
       (fol.compiler.ast:make-recur-node
        :args (mapcar #'sp (fol.compiler.ast:recur-node-args node)) :form (form-of node)))
      ((fol.compiler.ast:cond-node-p node)
       (fol.compiler.ast:make-cond-node
        :clauses (mapcar (lambda (c)
                           (cons (if (fol.compiler.ast:ast-node-p (car c)) (sp (car c)) (car c))
                                 (mapcar #'sp (cdr c))))
                         (fol.compiler.ast:cond-node-clauses node))
        :form (form-of node)))
      ;; nested loops/fns and any unhandled node type: leave unchanged
      (t node))))

(defun %num-loop-decls (loop-node env)
  "CL type declarations for loop variables with a proven float or integer type.
   When at least one float variable is present, also raise the local optimize
   policy so SBCL unboxes the arithmetic (EXPERIMENT: measuring safety 0 impact)."
  (let ((decls (loop for (name . nil) in (fol.compiler.ast:loop-node-bindings loop-node)
                     for ty = (gethash name env)
                     when (member ty '(double-float single-float integer))
                       collect `(cl:type ,ty ,name))))
    (when (some (lambda (d) (member (second d) '(double-float single-float))) decls)
      (push '(cl:optimize (cl:speed 3)) decls))
    decls))

(defun maybe-specialize-loop-nums (loop-node)
  "When *numeric-specialization* is on, return (values SPECIALIZED-LOOP DECLS):
   a copy of LOOP-NODE with scalar arithmetic rewritten to CL operators, plus
   type declarations for its numeric loop variables. Otherwise (values LOOP-NODE NIL)."
  (if (not fol.compiler.escape-analysis:*numeric-specialization*)
      (values loop-node nil)
      (let* ((env (%num-infer-loop-env loop-node))
             (new-body (mapcar (lambda (f) (%num-specialize f env))
                               (fol.compiler.ast:loop-node-body loop-node))))
        (values (fol.compiler.ast:make-loop-node
                 :bindings (fol.compiler.ast:loop-node-bindings loop-node)
                 :body new-body
                 :form (fol.compiler.ast:ast-node-form loop-node))
                (%num-loop-decls loop-node env)))))

(defun emit-loop-1 (node)
  "Emit a loop node using block/tagbody/go for optimized iteration.
   The block provides the exit mechanism (return-from).
   tagbody/go provides the loop mechanism.
   recur updates bindings with psetq then jumps back.
   NOTE: Uses interned symbols (not gensyms) so code can be serialized to files."
  (multiple-value-bind (node decls) (maybe-specialize-loop-nums node)
   (let* ((bindings (fol.compiler.ast:loop-node-bindings node))
         (body (fol.compiler.ast:loop-node-body node))
         (loop-id (incf *loop-counter*))
         (block-name (intern (format nil "LOOP-BLOCK-~D" loop-id)))
         (tag (intern (format nil "LOOP-~D" loop-id)))
         (result-sym (intern (format nil "RESULT-~D" loop-id)))
         (binding-names (mapcar #'car bindings))
         (*current-loop-context* (list block-name tag binding-names))
         ;; Track loop bindings as lexical vars
         (*lexical-vars* (append binding-names
                                 (list result-sym)
                                 *lexical-vars*)))
    `(cl:block ,block-name
       (cl:let ,(loop for (name . init-node) in bindings
                      collect `(,name ,(emit-node init-node)))
         ,@(when decls `((cl:declare ,@decls)))
         (cl:tagbody
           ,tag
           (cl:let ((,result-sym (cl:progn ,@(mapcar #'emit-node body))))
             (cl:return-from ,block-name ,result-sym))))))))

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
  (let ((name (cl:string-upcase (cl:string (fol.compiler.ast:in-package-node-name node))))
        (options (fol.compiler.ast:in-package-node-options node))
        (body (fol.compiler.ast:in-package-node-body node)))
    (let* ((use-opt (find :use options :key #'first))
           (other-opts (remove :use options :key #'first))
           (use-list (if use-opt
                         (mapcar (lambda (x) (cl:string-upcase (cl:string x)))
                             (rest use-opt))
                         nil))
           ;; Ensure :fol.core and :cl are present
           (new-use-list (cons :use
                               (remove-duplicates
                                   (append use-list '("FOL.CORE" "CL"))
                                 :test #'string-equal)))
           ;; Calculate conflicts
           (conflicts (remove-duplicates
                       (append
                        (loop for s being the external-symbols of (find-package :fol.core)
                              when (find-symbol (symbol-name s) :common-lisp)
                              collect (symbol-name s))
                        +standard-fol-functions+)
                       :test #'string-equal))
           (auto-shadow `(:shadowing-import-from :fol.core ,@conflicts))
           (final-options (append (list new-use-list auto-shadow) other-opts))
           (pkg-def `(cl:defpackage ,name ,@final-options))
           (pkg-switch `(cl:in-package ,name))
           (emitted-body (mapcar #'emit-node body)))
      (if body
          `(cl:progn
             ,pkg-def
             ,pkg-switch
             ,@emitted-body
             (cl:in-package :fol.core))
          `(cl:progn
             ,pkg-def
             ,pkg-switch)))))

(defun emit-defpackage (node)
  "Emit a defpackage form for a defpackage-node.
   Normalizes :use to include FOL.CORE and CL and auto-generates
   shadowing-imports for conflicts with CL symbols."
  (let ((name (cl:string-upcase (cl:string (fol.compiler.ast:defpackage-node-name node))))
        (options (fol.compiler.ast:defpackage-node-options node)))
    (let* ((use-opt (find :use options :key #'first))
           (other-opts (remove :use options :key #'first))
           (use-list (if use-opt
                         (mapcar (lambda (x) (cl:string-upcase (cl:string x)))
                             (rest use-opt))
                         nil))
           (new-use-list (cons :use
                               (remove-duplicates
                                   (append use-list '("FOL.CORE" "CL"))
                                 :test #'string-equal)))
           (conflicts (remove-duplicates
                       (append
                        (loop for s being the external-symbols of (find-package :fol.core)
                              when (find-symbol (symbol-name s) :common-lisp)
                              collect (symbol-name s))
                        +standard-fol-functions+)
                       :test #'string-equal))
           (auto-shadow `(:shadowing-import-from :fol.core ,@conflicts))
           (final-options (append (list new-use-list auto-shadow) other-opts))
           (pkg-def `(cl:defpackage ,name ,@final-options)))
      pkg-def)))

(defun emit-mutation-error (op-name suggestion node)
  "Signal a compiler error for a forbidden mutation form OP-NAME.
   SUGGESTION is appended to guide the user toward functional alternatives."
  (cl:error "Compiler error: '~A' is not allowed in FOL. ~
             FOL is a functional language; ~A ~
             Offending form: ~S"
    op-name suggestion (fol.compiler.ast:ast-node-form node)))

(defun emit-setf (node)
  "Signal a compiler error: setf is not permitted in FOL."
  (emit-mutation-error "setf"
                       "use persistent collection operations (assoc, update, etc.) instead."
                       node))

(defun emit-setq (node)
  "Signal a compiler error: setq is not permitted in FOL."
  (emit-mutation-error "setq"
                       "use bind for local bindings or def for top-level definitions instead."
                       node))

(defun emit-cl-set (node)
  "Signal a compiler error: set is not permitted in FOL."
  (emit-mutation-error "set"
                       "use bind for local bindings or def for top-level definitions instead."
                       node))

(defun emit-psetq (node)
  "Signal a compiler error: psetq is not permitted in FOL."
  (emit-mutation-error "psetq"
                       "use bind for local bindings or loop/recur for iteration instead."
                       node))

(defun emit-psetf (node)
  "Signal a compiler error: psetf is not permitted in FOL."
  (emit-mutation-error "psetf"
                       "use persistent collection operations (assoc, update, etc.) instead."
                       node))

(defun emit-incf (node)
  "Signal a compiler error: incf is not permitted in FOL."
  (emit-mutation-error "incf"
                       "use (+ x 1) or inc with bind/loop instead."
                       node))

(defun emit-decf (node)
  "Signal a compiler error: decf is not permitted in FOL."
  (emit-mutation-error "decf"
                       "use (- x 1) or dec with bind/loop instead."
                       node))

(defun emit-pushnew (node)
  "Signal a compiler error: pushnew is not permitted in FOL."
  (emit-mutation-error "pushnew"
                       "use conj with contains? to conditionally add to a persistent collection instead."
                       node))

(defun emit-rotatef (node)
  "Signal a compiler error: rotatef is not permitted in FOL."
  (emit-mutation-error "rotatef"
                       "use destructuring bind with explicit value swapping instead."
                       node))

(defun emit-shiftf (node)
  "Signal a compiler error: shiftf is not permitted in FOL."
  (emit-mutation-error "shiftf"
                       "use destructuring bind with explicit value threading instead."
                       node))

(defun emit-rplaca (node)
  "Signal a compiler error: rplaca is not permitted in FOL."
  (emit-mutation-error "rplaca"
                       "use cons or list* to construct a new pair with the desired car instead."
                       node))

(defun emit-rplacd (node)
  "Signal a compiler error: rplacd is not permitted in FOL."
  (emit-mutation-error "rplacd"
                       "use cons or list* to construct a new pair with the desired cdr instead."
                       node))

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
    (fol.compiler.ast:defstruct-node (emit-defstruct node))
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
    (fol.compiler.ast:setf-node (emit-setf node))
    (fol.compiler.ast:setq-node (emit-setq node))
    (fol.compiler.ast:cl-set-node (emit-cl-set node))
    (fol.compiler.ast:psetq-node (emit-psetq node))
    (fol.compiler.ast:psetf-node (emit-psetf node))
    (fol.compiler.ast:incf-node (emit-incf node))
    (fol.compiler.ast:decf-node (emit-decf node))
    (fol.compiler.ast:pushnew-node (emit-pushnew node))
    (fol.compiler.ast:rotatef-node (emit-rotatef node))
    (fol.compiler.ast:shiftf-node (emit-shiftf node))
    (fol.compiler.ast:rplaca-node (emit-rplaca node))
    (fol.compiler.ast:rplacd-node (emit-rplacd node))
    (fol.compiler.ast:in-package-node (emit-in-package node))
    (fol.compiler.ast:defpackage-node (emit-defpackage node))
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

(defun %maybe-infer-and-cache-summary (ast)
  "If AST is a function definition, infer its summary and cache it.
   This is the entry point for Tier-2 interprocedural analysis.
   Each definition node type has its own accessors (they include only
   ast-node, not defn-node, so there is no shared NAME/CLAUSES slot)."
  (when fol.compiler.escape-analysis:*transient-loops*
    (multiple-value-bind (name clauses)
        (typecase ast
          (fol.compiler.ast:defn-node
           (values (fol.compiler.ast:defn-node-name ast)
                   (fol.compiler.ast:defn-node-clauses ast)))
          (fol.compiler.ast:defn-private-node
           (values (fol.compiler.ast:defn-private-node-name ast)
                   (fol.compiler.ast:defn-private-node-clauses ast)))
          (fol.compiler.ast:definline-node
           (values (fol.compiler.ast:definline-node-name ast)
                   (fol.compiler.ast:definline-node-clauses ast)))
          (fol.compiler.ast:defmethod-node
           (values (fol.compiler.ast:defmethod-node-name ast)
                   (fol.compiler.ast:defmethod-node-clauses ast))))
      (when name
        (let* ((fn-ast (fol.compiler.ast:make-fn-node :clauses clauses :name name))
               (summary (fol.compiler.escape-analysis:infer-summary fn-ast)))
          (when summary
            (setf (gethash name fol.compiler.summaries:*inferred-summaries*)
                  summary)))))))

(defun compile-form (form)
  "Compile a single FOL form (already read) to a Common Lisp form.
   Returns a compilation-result."
  (handler-case
      ;; Tier-2: We need to infer summaries *before* emitting code that might
      ;; depend on them. We parse, then check if it's a function definition.
      ;; If so, we infer and cache its summary. Then we run scalar replacement.
      (let ((parsed-ast (reduce-literal-desugar-toplevel (parse-form form))))
        (multiple-value-bind (intra-bind-ast sr-assumptions sr-trust-checks)
            (sr-intra-bind-pass parsed-ast)
          (let ((ast (if fol.compiler.escape-analysis:*scalar-replacement*
                         (sr-transform-toplevel intra-bind-ast)
                         intra-bind-ast)))

            (%maybe-infer-and-cache-summary ast)
            (tr-transform-toplevel ast)
            ;; Escape-analysis audit mode: observe the parsed AST, never fail the
            ;; compile because of it. Names defined in this compilation unit are
            (when fol.compiler.escape-analysis:*escape-audit*
              (handler-case
                  (let ((fol.compiler.summaries:*name-exclusions*
                          (loop for x in *file-function-defs*
                                when (and x (symbolp x) (not (eq x t)))
                                  collect (symbol-name x)
                                when (stringp x)
                                  collect x)))
                    (fol.compiler.escape-analysis:audit-node ast))
                (error (e) (warn "escape-audit error on ~S: ~A"
                                 (if (consp form) (first form) form) e))))
            (let* ((fast-path-code (emit-node ast))
                   (redef-name
                     (when (and (or fol.compiler.escape-analysis:*transient-loops*
                                    fol.compiler.escape-analysis:*dict-scalar-replacement*)
                                (not fol.compiler.world:*sealed-world*))
                       (typecase ast
                         (fol.compiler.ast:defn-node
                          (fol.compiler.ast:defn-node-name ast))
                         (fol.compiler.ast:defn-private-node
                          (fol.compiler.ast:defn-private-node-name ast))
                         (fol.compiler.ast:definline-node
                          (fol.compiler.ast:definline-node-name ast))
                         (fol.compiler.ast:defmethod-node
                          (fol.compiler.ast:defmethod-node-name ast)))))
                   (final-code
                     (cond
                       ;; --- Intra-bind SR applied: emit dual path ---
                       ((and sr-assumptions (not fol.compiler.world:*sealed-world*))
                        (let ((validity-check `(cl:car (cl:load-time-value
                                                        ,(%register-region-trusted-form sr-assumptions sr-trust-checks)
                                                        cl:t)))
                              (fallback-code (emit-node parsed-ast)))
                          `(cl:if ,validity-check
                                  ,fast-path-code
                                  ,fallback-code)))
                       ;; --- No intra-bind SR: emit single path ---
                       (t fast-path-code))))
              (make-compilation-result
               :code (if (and redef-name (symbolp redef-name))
                         `(cl:progn
                            (fol.compiler.summaries:clear-inferred-summary ',redef-name)
                            (cl:prog1 ,final-code
                              (fol.compiler.world:note-redefinition ',redef-name)))
                         final-code))))))
    (error (e)
      (make-compilation-result
       :errors (list (format nil "~A" e))))))


(defun compile-string (source)
  "Read and compile a FOL source string.
   Returns a compilation-result."
  (let ((form (fol-read-from-string source)))
    (compile-form form)))

(cl:defun collect-fol-core-symbols (form)
  "Walk a form tree and collect all symbols interned in the FOL.CORE package.
   Used by compile-file to import these symbols into target packages so that
   prin1 outputs them without package qualification."
  (cl:let ((result cl:nil)
           (fol-core-pkg (cl:find-package :fol.core)))
    (cl:labels ((walk (x)
                      (cl:cond
                        ((cl:symbolp x)
                         (cl:when (cl:eq (cl:symbol-package x) fol-core-pkg)
                           (cl:pushnew x result)))
                        ((cl:consp x)
                         (walk (cl:car x))
                         (walk (cl:cdr x)))
                        ((cl:vectorp x)
                         (cl:loop for elem across x do (walk elem))))))
      (walk form))
    result))

(defun compile-file (path &key (output nil))
  "Read and compile a FOL source file.
   If OUTPUT is given, writes the generated CL code to that path.
   Otherwise writes to a temporary .lisp file and calls CL:COMPILE-FILE.
   Returns the pathname of the compiled file (fasl).

   Three passes over the file's forms:
     1. Read every form (exactly today's IN-PACKAGE bookkeeping, since a
        later form's reading can depend on an earlier IN-PACKAGE's package-
        creation/import side effects -- see the loop below) and PARSE-FORM
        it, without emitting anything yet. Collects (FORM AST PACKAGE),
        PACKAGE being the *PACKAGE* value in effect when FORM was read.
     2. INFER-INTERPROCEDURAL-TYPES over all the parsed ASTs from pass 1 --
        pure analysis, no I/O, no side effects. Needs every form's AST in
        hand up front, which is exactly what pass 1 produced.
     3. Emit: iterate the same collected forms in order, rebinding *PACKAGE*
        to each entry's stored snapshot, and call today's COMPILE-FORM +
        PRIN1 logic unchanged. COMPILE-FORM re-parses the form internally
        (a second PARSE-FORM call per form) -- deliberate: this keeps
        COMPILE-FORM's own internals (Tier-2 summary timing, scalar
        replacement, redefinition handling) completely untouched by this
        restructuring.
   Package creation/cleanup (CREATED-PACKAGES) spans both passes now,
   deleted only once emission has finished."
  (let* ((source-path (truename path))
         (lisp-path (make-pathname :type "lisp" :defaults (if output output source-path)))
         (created-packages nil)
         (collected nil)
         (*file-function-defs* (list t)))

    ;; --- Pass 1: read + package bookkeeping + parse (no emission) ---
    (with-open-file (in source-path :direction :input)
      (let ((*readtable* *fol-readtable*)
            (*package* (find-package :fol.core)))
        (loop for form = (fol-read in nil :eof)
              until (eq form :eof)
              do (progn
                  (when (cl:and (cl:consp form)
                          (cl:symbolp (cl:car form))
                          (cl:string-equal (cl:symbol-name (cl:car form)) "IN-PACKAGE"))
                        (cl:let ((raw-name (cl:second form)))
                          (cl:when (cl:or (cl:stringp raw-name) (cl:symbolp raw-name))
                            (cl:let ((pkg-name (cl:string-upcase (cl:string raw-name))))
                              (cl:let ((existing (cl:find-package pkg-name)))
                                (cl:unless existing
                                  (cl:push pkg-name created-packages))
                                (cl:let ((pkg (cl:or existing
                                                (cl:let ((new-pkg (cl:make-package pkg-name :use cl:nil)))
                                                  ;; Shadow-import FOL.CORE symbols that conflict with CL
                                                  (cl:let ((fol-core (cl:find-package :fol.core)))
                                                    (cl:loop for s being the external-symbols of fol-core
                                                      when (cl:find-symbol (cl:symbol-name s) :common-lisp)
                                                    do (cl:shadowing-import s new-pkg))
                                                    (cl:use-package (cl:list fol-core (cl:find-package :cl)) new-pkg))
                                                  new-pkg))))
                                  ;; Import all fol.core symbols from this form into the new package.
                                  ;; This ensures prin1 outputs them without package qualification,
                                  ;; so at load time they resolve correctly in the target package.
                                  (cl:let ((fol-syms (collect-fol-core-symbols form)))
                                    (cl:dolist (s fol-syms)
                                      (cl:multiple-value-bind (existing status)
                                        (cl:find-symbol (cl:symbol-name s) pkg)
                                        (cl:when (cl:or (cl:null status)
                                                   (cl:eq existing s))
                                          (cl:import s pkg)))))
                                  ;; Export symbols from :export clause so subsequent modules inherit them
                                  (cl:let ((export-opt (cl:find-if
                                                         (cl:lambda (x)
                                                           (cl:and (cl:consp x)
                                                             (cl:string-equal (cl:car x) :export)))
                                                         (cl:cddr form))))
                                    (cl:when export-opt
                                      (cl:dolist (s (cl:cdr export-opt))
                                        (cl:when (cl:symbolp s)
                                          (cl:let ((found (cl:find-symbol (cl:symbol-name s) pkg)))
                                            (cl:when found
                                              (cl:export found pkg)))))))
                                  (cl:setf cl:*package* pkg)))))))
                  (push (list form (parse-form form) cl:*package*) collected)))))
    (setf collected (nreverse collected))

    ;; --- Pass 2: whole-program interprocedural type inference ---
    (infer-interprocedural-types (mapcar #'second collected))

    ;; --- Pass 3: emission (COMPILE-FORM unchanged; re-parses internally) ---
    (with-open-file (out lisp-path :direction :output :if-exists :supersede)
      (let ((*print-circle* t))
        (format out "~&;;; Transpiled from ~A~%" (file-namestring source-path))
        (format out "(in-package :fol.core)~%")
        (dolist (entry collected)
          (destructuring-bind (form ast pkg) entry
            (declare (ignore ast))
            (let ((*package* pkg))
              (let ((result (compile-form form)))
                (if (compilation-result-errors result)
                    (error "Compilation error in ~A: ~A" path (compilation-result-errors result))
                    (let ((code (compilation-result-code result)))
                      (labels ((emit-flat (form)
                                          (if (and (consp form) (eq (car form) 'cl:progn))
                                              (mapc #'emit-flat (cdr form))
                                              (progn
                                               (terpri out)
                                               (prin1 form out)
                                               (terpri out)))))
                        (emit-flat code))))))))))

    ;; Delete packages created during transpilation to avoid name-conflicts
    ;; when cl:compile-file processes the defpackage in the generated output
    (cl:dolist (name (cl:reverse created-packages))
      (cl:let ((pkg (cl:find-package name)))
        (cl:when pkg (cl:delete-package pkg))))

    ;; Make sure to compile the generated Lisp file
    (cl:compile-file lisp-path)))A