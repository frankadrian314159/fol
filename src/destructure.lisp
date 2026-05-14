;;; FOL Compiler - Destructuring and Pattern Matching
;;;
;;; Compile-time analysis of fn parameter vectors: pattern signature
;;; computation, specificity comparison, and CL code emission for
;;; runtime dispatch.  Mirrors the bootstrap's pattern matching
;;; (fol-mop.lisp and eval.lisp) but targets CL vector params and
;;; emits inline CL code with no bootstrap runtime dependency.

(in-package :fol.compiler.destructure)

;;; ---------------------------------------------------------------------------
;;; Wildcard parameter support
;;; ---------------------------------------------------------------------------

(defun wildcard-param-p (sym)
  "Return T if SYM is the wildcard parameter _, meaning 'skip this value'.
   Compares by symbol name for cross-package safety."
  (and (symbolp sym)
       (string= (symbol-name sym) "_")))

(defun replace-wildcards (params)
  "Replace each _ in PARAMS with a unique gensym.
   Returns two values: the cleaned param list and a list of the gensyms introduced."
  (let ((gensyms nil))
    (values
      (mapcar (lambda (p)
                (if (wildcard-param-p p)
                    (let ((g (gensym "UNUSED")))
                      (push g gensyms)
                      g)
                    p))
          params)
      (nreverse gensyms))))

;;; ---------------------------------------------------------------------------
;;; Parameter parsing
;;; ---------------------------------------------------------------------------

(defun parse-params (param-list)
  "Split PARAM-LIST on &, :key, :or, and :as markers into components.
   Returns (values regular-params rest-param key-params defaults as-param).
     &      - rest parameter (collects remaining args)
     :key   - keyword parameters (like CL &key)
     :or    - default values vector for optional/key params
     :as    - whole-binding parameter (binds the entire argument list)"
  (let ((regular nil)
        (rest-param nil)
        (key-params nil)
        (defaults nil)
        (as-param nil)
        (mode :regular)) ; :regular, :rest, :key, :or, :as
    (dolist (p param-list)
      (cond
       ;; Mode-switching keywords
       ((and (symbolp p) (string= (symbol-name p) "&"))
         (setf mode :rest))
       ((eq p :key)
         (setf mode :key))
       ((eq p :or)
         (setf mode :or))
       ((eq p :as)
         (setf mode :as))
       ;; Collect based on current mode
       ((eq mode :rest)
         (setf rest-param p)
         (setf mode :regular))
       ((eq mode :key)
         (push p key-params))
       ((eq mode :or)
         (setf defaults p)
         (setf mode :regular))
       ((eq mode :as)
         (setf as-param p)
         (setf mode :regular))
       (t (push p regular))))
    (values (nreverse regular) rest-param (nreverse key-params) defaults as-param)))

(defun strip-specializers (param-list)
  "Strip type and predicate specializers, returning bare variable names.
   (n (= 0))   -> n
   (x <number>) -> x
   n            -> n
   #(a b)       -> #(a b)  ; destructuring patterns preserved"
  (mapcar (lambda (param)
            (cond
             ;; Predicate specializer: (pattern (fn args...))
             ((and (listp param)
                   (not (null param))
                   (= (length param) 2)
                   (listp (second param)))
               (first param))
             ;; Type specializer: (pattern <type>)
             ((and (listp param)
                   (not (null param))
                   (= (length param) 2)
                   (symbolp (second param)))
               (first param))
             (t param)))
      param-list))

;;; ---------------------------------------------------------------------------
;;; Pattern signature computation  (compile-time)
;;; ---------------------------------------------------------------------------

(defun filter-as-bindings (elem-list)
  "Remove :as and its following symbol, and & and everything after it,
   from ELEM-LIST.  Returns (values filtered-elements has-rest-p)."
  (let ((result nil)
        (has-rest nil))
    (loop for remaining on elem-list
          for elem = (car remaining)
          do (cond
              ((eq elem :as)
                (return))
              ((and (symbolp elem) (string= (symbol-name elem) "&"))
                (setf has-rest t)
                (return))
              (t (push elem result))))
    (values (nreverse result) has-rest)))

(defun compute-element-signature (elem)
  "Compute signature for a single element within a destructuring pattern.
   Returns a signature spec:
     symbol             -> (:any)
     (var (fn args...)) -> (:pred fn args) OR (:type-pred fn args)
     (var <type>)       -> (:type <type>)
     #(elems...)        -> (:seq (element-sigs...) has-rest)
     otherwise          -> (:any)"
  (cond
   ((symbolp elem) (list :any))
   ;; Predicate specializer: (pattern (fn arg0 arg1 ...))
   ((and (listp elem)
         (not (null elem))
         (= (length elem) 2)
         (listp (second elem))
         (not (null (second elem))))
     (let* ((pred-form (second elem))
            (fn (first pred-form)))
       (if (type-predicate-p fn)
           (list :type-pred fn (rest pred-form))
           (list :pred fn (rest pred-form)))))
   ;; Type specializer: (pattern <type>)
   ((and (listp elem)
         (not (null elem))
         (= (length elem) 2)
         (symbolp (second elem)))
     (list :type (second elem)))
   ;; Nested FOL vector -> sequence destructuring
   ((typep elem 'fol.compiler.collections:<vector>)
     (let ((elements (fol.compiler.collections:collection-seq elem)))
       (multiple-value-bind (filtered has-rest) (filter-as-bindings elements)
         (list :seq (mapcar #'compute-element-signature filtered) has-rest))))
   ;; Nested FOL dict -> map destructuring
   ((typep elem 'fol.compiler.collections:<dict>)
     (list :any)) ; For now, treat map patterns as :any for dispatch purposes
   (t (list :any))))

(defun compute-pattern-signature (param-list)
  "Compute a signature describing what each parameter expects.
   PARAM-LIST is the list of regular parameters (after parse-params).
   Returns a list of pattern specs:
     (:any)             - simple parameter, matches anything
     (:seq elem-sigs has-rest) - sequence destructuring
     (:type class-name) - type specializer
     (:type-pred fn args) - recognized type predicate
     (:pred fn args)    - arbitrary predicate specializer"
  (mapcar (lambda (param)
            (cond
             ;; Predicate specializer: (pattern (fn arg0 arg1 ...))
             ((and (listp param)
                   (not (null param))
                   (= (length param) 2)
                   (listp (second param))
                   (not (null (second param))))
               (let* ((pred-form (second param))
                      (fn (first pred-form)))
                 (if (type-predicate-p fn)
                     (list :type-pred fn (rest pred-form))
                     (list :pred fn (rest pred-form)))))
             ;; Type specializer: (pattern <type>)
             ((and (listp param)
                   (not (null param))
                   (= (length param) 2)
                   (symbolp (second param)))
               (list :type (second param)))
             ;; Sequence pattern (FOL vector)
             ((typep param 'fol.compiler.collections:<vector>)
               (let ((elements (fol.compiler.collections:collection-seq param)))
                 (multiple-value-bind (filtered has-rest) (filter-as-bindings elements)
                   (list :seq (mapcar #'compute-element-signature filtered) has-rest))))
             ;; Map pattern (FOL dict)
             ((typep param 'fol.compiler.collections:<dict>)
               (list :any))
             ;; Default: any
             (t (list :any))))
      param-list))

;;; ---------------------------------------------------------------------------
;;; Specificity comparison  (compile-time)
;;; ---------------------------------------------------------------------------

(defun is-type-predicate-form-p (form)
  "Check if FORM is a type predicate like (<integer>) or (integer?).
   Returns T if it's a single-element list with a type predicate, or a type-predicate call."
  (cond
    ((and (listp form) (= (length form) 1) (symbolp (first form)))
     (type-predicate-p (first form)))
    ((and (listp form) (symbolp (first form)))
     (type-predicate-p (first form)))
    (t nil)))

(defun detect-composite-level (pred-form)
  "Detect if a predicate form is a conjunction of type check + other predicate.
   Returns:
     - 2.5 if the form is (and <type-pred> <other-pred>) or equivalent
     - nil otherwise

   Example: (and (<integer>) (prime?)) -> 2.5 (between type:2 and pred:3)"
  (when (and (listp pred-form)
             (symbolp (first pred-form))
             (string= (symbol-name (first pred-form)) "AND")
             (>= (length pred-form) 3)) ; (and pred1 pred2 ...)
    (let ((conjuncts (rest pred-form))
          (has-type-pred nil)
          (has-other-pred nil))
      (dolist (conj conjuncts)
        (cond
          ((is-type-predicate-form-p conj)
           (setf has-type-pred t))
          ((and (listp conj) (symbolp (first conj)))
           (setf has-other-pred t))))
      (when (and has-type-pred has-other-pred)
        2.5)))) ; Composite level: between type (2) and pure pred (3)

(defun pattern-specificity-level (sig)
  "Return numeric specificity level for a single signature spec.
   Higher numbers are more specific.
   Levels (in ascending specificity):
     0: wildcard (:any)
     1: sequence destructuring (:seq)
     2: bare types (:type, :type-pred)
     3: type-annotated predicates (composite: :and with type + predicate)
     4: pure predicates (:pred without type annotation)

   Type-annotated conjunctions like (and (<integer>) (prime?)) are Level 3,
   making them more specific than bare types (2) but less specific than
   pure predicates (4) that lack the type constraint. This resolves the
   semantic issue where both (prime?) and (and (<integer>) (prime?))
   would otherwise receive the same level."
  (case (first sig)
    (:pred
     ;; Check if this predicate is a type-annotated conjunction
     (let ((fn (second sig))
           (args (rest (rest sig))))
       ;; Reconstruct the predicate form for composite-level detection
       (if (and (string= (symbol-name fn) "AND") args)
           (let ((composite (detect-composite-level (cons fn args))))
             ;; Composite (type + predicate) is Level 3
             ;; Pure predicate is Level 4
             (if composite 3 4))
           4))) ; Pure predicate: Level 4
    (:type 2)
    (:type-pred 2)
    (:seq 1)
    (:any 0)
    (t 0)))


(defun pattern-more-specific-p (sig1 sig2)
  "Return T if signature SIG1 is more specific than SIG2.
   Implements lexicographical ordering: compares elements by level (including
   composite levels like 2.5 for type-annotated conjunctions), then handles
   nested sequence length and variadicness."
  (loop for s1 in sig1
        for s2 in sig2
        for level1 = (pattern-specificity-level s1)
        for level2 = (pattern-specificity-level s2)
        do (cond
            ;; Use numeric comparison for all levels (integers and composites)
            ((> level1 level2)
              (return-from pattern-more-specific-p t))
            ((< level1 level2)
              (return-from pattern-more-specific-p nil))
            ;; Same level - recurse for sequences
            ((and (eq (first s1) :seq) (eq (first s2) :seq))
              (let ((elems1 (second s1))
                    (elems2 (second s2))
                    (rest1 (third s1))
                    (rest2 (third s2)))
                (cond
                 ;; Recurse on common prefix
                 ((pattern-more-specific-p elems1 elems2)
                   (return-from pattern-more-specific-p t))
                 ((pattern-more-specific-p elems2 elems1)
                   (return-from pattern-more-specific-p nil))
                 ;; Common prefix is tied - longer sequence wins
                 ((> (length elems1) (length elems2))
                   (return-from pattern-more-specific-p t))
                 ((< (length elems1) (length elems2))
                   (return-from pattern-more-specific-p nil))
                 ;; Length is tied - fixed wins over variadic
                 ((and (not rest1) rest2)
                   (return-from pattern-more-specific-p t))
                 ((and rest1 (not rest2))
                   (return-from pattern-more-specific-p nil)))))))
  ;; Prefix is tied - longer top-level list wins (for sequences)
  (> (length sig1) (length sig2)))

;;; ---------------------------------------------------------------------------
;;; FOL type name -> CL type specifier mapping
;;; ---------------------------------------------------------------------------

(defvar *fol-type-to-cl-type*
        (let ((ht (make-hash-table :test 'equal)))
          (loop for (fol-name cl-type) in
                  '(("<NUMBER>" number)
                    ("<COMPLEX>" complex)
                    ("<REAL>" real)
                    ("<FLOAT>" float)
                    ("<SINGLE-FLOAT>" single-float)
                    ("<DOUBLE-FLOAT>" double-float)
                    ("<RATIONAL>" rational)
                    ("<RATIO>" ratio)
                    ("<INTEGER>" integer)
                    ("<FIXNUM>" fixnum)
                    ("<BIGNUM>" bignum)
                    ("<STRING>" string)
                    ("<CHAR>" character)
                    ("<BOOL>" boolean)
                    ("<SYMBOL>" symbol)
                    ("<KEYWORD>" keyword))
                do (setf (gethash fol-name ht) cl-type))
          ht)
        "Map from FOL type name strings to CL type specifiers.")

(defun type-predicate-p (sym)
  "Check if SYM is a recognized type predicate (e.g., <number>?)."
  (let ((name (symbol-name sym)))
    (and (> (length name) 2)
         (char= (char name 0) #\<)
         (char= (char name (1- (length name))) #\?)
         (let ((type-name (subseq name 0 (1- (length name)))))
           (gethash type-name *fol-type-to-cl-type*)))))

(defun fol-type-to-cl-type (fol-type-sym)
  "Convert a FOL type symbol like <number> to a CL type specifier.
   Returns NIL if not a recognized FOL primitive type."
  (gethash (symbol-name fol-type-sym) *fol-type-to-cl-type*))

;;; ---------------------------------------------------------------------------
;;; CL code emission for runtime pattern checks
;;; ---------------------------------------------------------------------------

(defvar *emit-predicate-hook* nil
        "Hook for custom emitting of predicate checks.
   Called with (fn-name extra-args arg-expr).")

(defun emit-element-pattern-check (sig arg-expr)
  "Emit a CL form that checks whether ARG-EXPR matches a single
   element signature SIG at runtime.  Returns a CL form or T."
  (case (first sig)
    (:any t)
    (:type
     (let ((cl-type (fol-type-to-cl-type (second sig))))
       (if cl-type
           `(typep ,arg-expr ',cl-type)
           ;; Unknown type - fall back to class check
           `(typep ,arg-expr ',(second sig)))))
    (:pred
     (let ((fn-name (second sig))
           (extra-args (third sig)))
       (if *emit-predicate-hook*
           (funcall *emit-predicate-hook* fn-name extra-args arg-expr)
           (if extra-args
               `(,fn-name ,arg-expr ,@extra-args)
               `(,fn-name ,arg-expr)))))
    (:type-pred
     (let ((fn-name (second sig))
           (extra-args (third sig)))
       ;; Recognized type predicates are always emitted as direct calls
       ;; unless a hook is present (which is rare outside bootstrap).
       (if extra-args
           `(,fn-name ,arg-expr ,@extra-args)
           `(,fn-name ,arg-expr))))
    (:seq
     (let* ((elem-sigs (second sig))
            (has-rest (third sig))
            (n (length elem-sigs))
            (temp (gensym "SEQ")))
       `(let ((,temp ,arg-expr))
          (and (typep ,temp 'sequence)
               ,(if has-rest
                    `(>= (cl:length ,temp) ,n)
                    `(= (cl:length ,temp) ,n))
               ,@(loop for es in elem-sigs
                       for i from 0
                       for check = (emit-element-pattern-check es `(elt ,temp ,i))
                         unless (eq check t)
                       collect check)))))
    (t t)))

(defun emit-clause-pattern-check (signature arity has-rest args-sym)
  "Emit a CL form that checks whether ARGS-SYM matches a clause with
   the given SIGNATURE, ARITY, and HAS-REST flag.  Returns a CL form."
  (let ((arity-check (if has-rest
                         `(>= (length ,args-sym) ,arity)
                         `(= (length ,args-sym) ,arity)))
        (pattern-checks
         (loop for sig in signature
               for i from 0
               for check = (emit-element-pattern-check sig `(nth ,i ,args-sym))
                 unless (eq check t)
               collect check)))
    (if pattern-checks
        `(and ,arity-check ,@pattern-checks)
        arity-check)))

;;; ---------------------------------------------------------------------------
;;; CL code emission for parameter bindings
;;; ---------------------------------------------------------------------------

(defun emit-param-bindings (stripped-params args-sym &optional (start-index 0))
  "Emit a list of CL let-binding forms that bind each stripped parameter
   to the corresponding element of ARGS-SYM.
   Handles simple symbols and vector destructuring patterns."
  (loop for param in stripped-params
        for i from start-index
          append (emit-single-param-binding param `(nth ,i ,args-sym))))

(defun emit-single-param-binding (param access-expr)
  "Emit let-binding forms for a single parameter bound to ACCESS-EXPR.
   For symbols, returns a single binding.  For _, returns nil (skip).
   For vectors, emits nested destructuring bindings."
  (cond
   ;; Wildcard: skip this binding entirely
   ((wildcard-param-p param) nil)
   ((symbolp param)
     (list (list param access-expr)))
   ((typep param 'fol.compiler.collections:<vector>)
     (let* ((elems (fol.compiler.collections:collection-seq param))
            (temp (gensym "DESTR"))
            (bindings (list (list temp access-expr))))
       ;; Process each element, skipping :as and & markers
       (let ((saw-ampersand nil)
             (saw-as nil))
         (loop for elem in elems
               for idx from 0
               do (cond
                   (saw-as
                     ;; :as binding - bind to the whole value (skip if _)
                     (unless (wildcard-param-p elem)
                       (push (list elem temp) bindings))
                     (setf saw-as nil))
                   ((eq elem :as)
                     (setf saw-as t))
                   ((and (symbolp elem) (string= (symbol-name elem) "&"))
                     (setf saw-ampersand t))
                   (saw-ampersand
                     ;; Rest param in destructuring (skip if _)
                     (unless (wildcard-param-p elem)
                       (push (list elem `(nthcdr ,idx ,temp)) bindings))
                     (setf saw-ampersand nil))
                   (t
                     ;; Regular element - may itself be a destructuring pattern
                     (let ((sub-bindings
                            (emit-single-param-binding elem `(elt ,temp ,idx))))
                       (setf bindings (append bindings sub-bindings)))))))
       bindings))
   ((typep param 'fol.compiler.collections:<dict>)
     (let* ((pairs (fol.compiler.collections:collection-seq param))
            (temp (gensym "DESTR"))
            (bindings (list (list temp access-expr))))
       ;; Use forward append (not push+nreverse) so that sub-bindings
       ;; referencing temp appear after temp is bound in the let* chain.
       (dolist (pair pairs)
         (let ((k (car pair)) (v (cdr pair)))
           (cond
            ((eq k :keys)
              ;; v is a vector of symbols or (field binding) pairs.
              ;; Simple symbol: bind (get temp :sym) to sym.
              ;; Pair (field sym): bind (get temp :field) to sym.
              ;; Pair (field (eql val)): predicate-only, no binding.
              ;; Pair (field (dict-pat type)): nested destructure on field value.
              (let ((syms (if (typep v 'fol.compiler.collections:<collection>)
                              (fol.compiler.collections:collection-seq v)
                              v)))
                (dolist (s syms)
                  (cond
                    ;; Simple symbol: bind (get temp :sym) to sym
                    ((symbolp s)
                     (let ((key (intern (symbol-name s) :keyword)))
                       (setf bindings
                             (append bindings
                                     (list (list s `(fol.compiler.collection-functions:get ,temp ,key)))))))
                    ;; Pair (field-name binding-pattern)
                    ((and (listp s) (= (length s) 2))
                     (let* ((field (first s))
                            (binding (second s))
                            (key (intern (symbol-name field) :keyword))
                            (field-access `(fol.compiler.collection-functions:get ,temp ,key)))
                       (cond
                         ;; (field sym) → bind field to sym
                         ((symbolp binding)
                          (setf bindings (append bindings (list (list binding field-access)))))
                         ;; (field (eql val)) → predicate check only, no binding
                         ((and (listp binding) (>= (length binding) 1)
                               (symbolp (first binding))
                               (string= (symbol-name (first binding)) "EQL"))
                          nil)
                         ;; (field (dict-pattern <type>)) → nested destructure on field
                         ((and (listp binding) (= (length binding) 2)
                               (symbolp (second binding))
                               (typep (first binding) 'fol.compiler.collections:<dict>))
                          (let ((sub-bindings (emit-single-param-binding (first binding) field-access)))
                            (setf bindings (append bindings sub-bindings))))
                         ;; (field dict-pattern) → nested destructure on field
                         ((typep binding 'fol.compiler.collections:<dict>)
                          (let ((sub-bindings (emit-single-param-binding binding field-access)))
                            (setf bindings (append bindings sub-bindings)))))))
                    ;; Fallback: skip
                    (t nil)))))
            ((eq k :as)
              (unless (wildcard-param-p v)
                (setf bindings (append bindings (list (list v temp)))))))))
       bindings))
   (t (list (list (gensym "IGNORED") access-expr)))))

(defun emit-rest-param-binding (rest-param arity args-sym)
  "Emit a let-binding for the rest parameter, collecting args from ARITY onward.
   Returns NIL if rest-param is _ (wildcard)."
  (when (and rest-param (not (wildcard-param-p rest-param)))
        (list (list rest-param `(nthcdr ,arity ,args-sym)))))

(defun emit-dict-inner-predicates (dict-param access-expr)
  "Emit additional runtime predicate checks from a {:keys [...]} dict pattern.
   Returns a list of CL check forms to be ANDed with the dispatch check.
   Handles pairs in :keys vectors:
   - (field (eql val))            → (eql (get obj :field) val)
   - (field (nested-dict <type>)) → (typep (get obj :field) '<type>) + recursive
   Simple symbols produce no checks (bindings only)."
  (let ((pairs (fol.compiler.collections:collection-seq dict-param))
        (checks nil))
    (dolist (pair pairs)
      (let ((k (car pair)) (v (cdr pair)))
        (when (eq k :keys)
          (let ((syms (if (typep v 'fol.compiler.collections:<collection>)
                          (fol.compiler.collections:collection-seq v)
                          v)))
            (dolist (s syms)
              (when (and (listp s) (= (length s) 2))
                (let* ((field (first s))
                       (binding (second s))
                       (key (intern (symbol-name field) :keyword))
                       (field-access `(fol.compiler.collection-functions:get ,access-expr ,key)))
                  (cond
                    ;; (field (eql val)) → eql check
                    ((and (listp binding) (>= (length binding) 1)
                          (symbolp (first binding))
                          (string= (symbol-name (first binding)) "EQL"))
                     (push `(eql ,field-access ,(second binding)) checks))
                    ;; (field (dict-pattern <type>)) → typep + nested checks
                    ((and (listp binding) (= (length binding) 2)
                          (symbolp (second binding))
                          (typep (first binding) 'fol.compiler.collections:<dict>))
                     (let* ((type-sym (second binding))
                            (inner-dict (first binding))
                            (inner-checks (emit-dict-inner-predicates inner-dict field-access)))
                       (push `(typep ,field-access ',type-sym) checks)
                       (dolist (ic inner-checks) (push ic checks))))
                    ;; Other forms: no extra check
                    (t nil)))))))))
    (nreverse checks)))

(defun emit-stripped-param-inner-predicates (stripped-param access-expr)
  "Emit inner predicate checks for a stripped parameter (type specializer removed).
   For dict params with nested predicates, returns check forms.
   For other params, returns nil."
  (when (typep stripped-param 'fol.compiler.collections:<dict>)
    (emit-dict-inner-predicates stripped-param access-expr)))

;;; ---------------------------------------------------------------------------
;;; Fixed-arity emission (optimization for uniform-arity multi-clause)
;;; ---------------------------------------------------------------------------

(defun emit-fixed-arity-pattern-check (signature param-syms)
  "Emit a CL form that checks whether PARAM-SYMS match SIGNATURE.
   Unlike emit-clause-pattern-check, no arity check is needed because
   the lambda's fixed parameter list enforces arity.
   PARAM-SYMS is a list of symbols corresponding to the lambda parameters."
  (let ((pattern-checks
         (loop for sig in signature
               for sym in param-syms
               for check = (emit-element-pattern-check sig sym)
                 unless (eq check t)
               collect check)))
    (cond
     ((null pattern-checks) t)
     ((= (length pattern-checks) 1) (first pattern-checks))
     (t `(and ,@pattern-checks)))))

(defun emit-fixed-arity-param-bindings (stripped-params param-syms)
  "Emit let-binding forms that bind each stripped parameter to its
   corresponding fixed param symbol.  Like emit-param-bindings but
   uses direct symbol references instead of (nth N args-sym)."
  (loop for param in stripped-params
        for sym in param-syms
          append (emit-single-param-binding param sym)))

;;; ---------------------------------------------------------------------------
;;; Macro parameter destructuring (no predicate specializers)
;;; ---------------------------------------------------------------------------

(defun convert-macro-param (param)
  "Convert a single FOL macro parameter to CL defmacro lambda list form.
   Handles: simple symbols, _ wildcards, nested vector destructuring.
   Signals an error for type or predicate specializers."
  (cond
   ;; Wildcard -> gensym
   ((wildcard-param-p param) (gensym "UNUSED"))
   ;; Simple symbol
   ((symbolp param) param)
   ;; Nested vector destructuring -> recurse
   ((typep param 'fol.compiler.collections:<vector>)
     (emit-macro-lambda-list (fol.compiler.collections:collection-seq param)))
   ;; List form -> specializer (not allowed in macros)
   ((and (listp param) (not (null param)))
     (error "Specializers not supported in macro parameter lists: ~S" param))
   (t param)))

(defun emit-macro-lambda-list (param-list)
  "Convert a FOL macro parameter list to a CL defmacro lambda list.
   Supports: simple params, & (rest/body), :key, :as (&whole),
   nested vector destructuring, and _ wildcards.
   Does NOT support type or predicate specializers.
   Uses &body instead of &rest for the main-level rest parameter."
  (multiple-value-bind (regular rest-param key-params defaults as-param)
      (parse-params param-list)
    (declare (ignore defaults))
    (let ((cl-params (mapcar #'convert-macro-param regular)))
      (append
        ;; &whole comes first in CL defmacro lambda lists
        (when as-param
              (if (wildcard-param-p as-param)
                  (list '&whole (gensym "UNUSED"))
                  (list '&whole as-param)))
        ;; Regular params
        cl-params
        ;; &body for rest (better indentation in CL macros)
        (when rest-param
              (if (wildcard-param-p rest-param)
                  (list '&body (gensym "UNUSED"))
                  (list '&body rest-param)))
        ;; &key params
        (when key-params
              (cons '&key (mapcar #'convert-macro-param key-params)))))))
