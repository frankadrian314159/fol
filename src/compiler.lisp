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

(defun emit-literal (node)
  "Emit a literal value. Self-evaluating forms compile to themselves."
  (fol.compiler.ast:literal-node-value node))

(defun emit-symbol-ref (node)
  "Emit a symbol reference. Compiles to the CL symbol itself.
   Tracks non-lexical symbols for SPECIAL declarations.
   For symbols known to be function definitions (defn/defgeneric) in the
   current compilation unit, emits (cl:function name) for Lisp-1 compatibility."
  (let ((name (fol.compiler.ast:symbol-ref-node-name node)))
    (format t "DEBUG: emit-symbol-ref ~S (pkg: ~A)~%" name (when (symbolp name) (symbol-package name)))
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
     ((fol.compiler.ast:symbol-ref-node-p operator)
       (let ((sym (fol.compiler.ast:symbol-ref-node-name operator))
             (emitted-args (mapcar #'emit-node args)))
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
                        (t (cl:error "~S is not a function or collection" ',sym)))))))))

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

(defun emit-thread-first (node)
  "Emit a thread-first node by expanding into nested function calls with dynamic dispatch.
   (-> x f)           => (if (fboundp 'f) (f x) (let ((val f)) ...))
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
   Uses emit-macro-lambda-list for FOL-to-CL lambda list conversion.
   Also emits metadata setting code if docstring is present."
  (let* ((name (fol.compiler.ast:defmacro-node-name node))
         (params (fol.compiler.ast:defmacro-node-params node))
         (body (fol.compiler.ast:defmacro-node-body node))
         (docstring (fol.compiler.ast:defmacro-node-docstring node))
         (param-list (fol-vector-to-list params))
         (cl-lambda-list (fol.compiler.destructure:emit-macro-lambda-list param-list))
         (emitted-body (mapcar #'emit-node body)))
    (let ((defmacro-form `(cl:defmacro ,name ,cl-lambda-list ,@emitted-body))
          (metadata-form (when docstring
                               `(fol.compiler.metadata:alter-meta! (quote ,name)
                                                                   (fn [m] (fol.compiler.collection-functions:merge m
                                                                                                                    (fol.compiler.collection-functions:dict
                                                                                                                     :doc ,docstring
                                                                                                                     :name (quote ,name))))))))
      (if metadata-form
          `(cl:progn ,defmacro-form ,metadata-form)
          defmacro-form))))

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
      `(cl:progn
         (cl:defclass ,name ,effective-supers
           ,clean-slots
           (:metaclass fol.compiler.persistent:persistent-class))
         ,@(loop for (sname initarg accessor storage-key) in slot-infos
                   when accessor
                 collect `(cl:defun ,accessor (object)
                            (fol.compiler.collection-functions:get object ,storage-key)))
         ;; Abstract guard: prevent direct make-instance calls from CL code.
         ,@(when abstractp
                 `((cl:defmethod cl:initialize-instance :before ((obj ,name) &rest args)
                     (cl:declare (cl:ignore args))
                     (cl:when (cl:eq (cl:class-of obj) (cl:find-class ',name))
                       (cl:error "Cannot instantiate abstract class ~A" ',name)))))
         ;; Constructor — abstract classes always error; concrete classes use %make-persistent
         ;; fast path (bypasses initialize-instance MOP overhead ~550ns/call on SBCL).
         ;; load-time-value caches the class object, avoiding find-class on each call.
         ,(if abstractp
              `(cl:defun ,constructor-name (&rest %ctor-args)
                 (cl:declare (cl:ignore %ctor-args))
                 (cl:error "Cannot instantiate abstract class ~A" ',name))
              `(cl:defun ,constructor-name (&rest %ctor-args)
                 (cl:apply #'fol.compiler.persistent::%make-persistent
                           (cl:load-time-value (cl:find-class ',name))
                           %ctor-args)))
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
                      for base-check = (fol.compiler.destructure:emit-fixed-arity-pattern-check
                                        signature param-syms)
                        ;; Include inner dict predicate checks (e.g. nested :keys eql patterns)
                      for inner-checks = (loop for param in stripped
                                               for sym in param-syms
                                               append (fol.compiler.destructure:emit-stripped-param-inner-predicates
                                                       param sym))
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
                 (final-lambda-list (if variadic-p (append param-syms (list '&rest rest-sym)) param-syms)))
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
                                               append (fol.compiler.destructure:emit-stripped-param-inner-predicates
                                                       param `(nth ,i ,args-sym)))
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
   Also emits metadata setting code if docstring is present."
  (let ((name (fol.compiler.ast:defmethod-node-name node))
        (qualifier (fol.compiler.ast:defmethod-node-qualifier node))
        (clauses (fol.compiler.ast:defmethod-node-clauses node))
        (docstring (fol.compiler.ast:defmethod-node-docstring node)))
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
   Also emits metadata setting code if docstring is present."
  (let* ((name (fol.compiler.ast:defn-node-name node))
         (clauses (fol.compiler.ast:defn-node-clauses node))
         (docstring (fol.compiler.ast:defn-node-docstring node))
         ;; AST-level analysis (robust, format-independent)
         (cache-mode (cacheable-clauses-p clauses))
         ;; Compile regardless (needed for emit)
         (lambda-form (compile-fn clauses))
         ;; Fallback: post-compile check catches edge cases
         (cache-mode (or cache-mode (cacheable-defn-p lambda-form))))
    ;; Track this function for Lisp-1 compatibility in compile-file
    (when *file-function-defs*
          (pushnew name *file-function-defs* :test #'string=))
    ;; lambda-form is (lambda params body...)
    ;; Check if dispatch caching applies
    (let* ((base-form (if cache-mode
                          (make-cached-defn name lambda-form cache-mode)
                          (let ((params (second lambda-form))
                                (body (cddr lambda-form)))
                            `(cl:defun ,name ,params ,@body))))
           (metadata-form (emit-metadata-assignment name docstring clauses)))
      (if metadata-form
          `(cl:progn ,base-form ,metadata-form)
          base-form))))

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
   Returns the pathname of the compiled file (fasl)."
  (let* ((source-path (truename path))
         (lisp-path (make-pathname :type "lisp" :defaults (if output output source-path)))
         (created-packages nil))

    (with-open-file (in source-path :direction :input)
      (with-open-file (out lisp-path :direction :output :if-exists :supersede)
        ;; Bind readtable and package for reading
        (let ((*readtable* *fol-readtable*)
              (*package* (find-package :fol.core))
              (*print-circle* t)
              (*file-function-defs* (list t)))
          ;; Emit package declaration so cl:compile-file uses correct package
          (format out "~&;;; Transpiled from ~A~%" (file-namestring source-path))
          (format out "(in-package :fol.core)~%")

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
    (cl:compile-file lisp-path)))