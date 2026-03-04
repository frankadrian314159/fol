(in-package :fol.fol-mop)

;;; ============================================================================
;;; FOL MOP - Metaobject Protocol with Vector Syntax
;;; ============================================================================
;;; This module provides FOL-style versions of CLOS definition forms that use
;;; vectors instead of lists for structural elements:
;;;   - defgeneric* : lambda-list in a vector
;;;   - defclass*   : superclasses and slots in vectors
;;;   - defmethod*  : specialized lambda-list in a vector

;;; ============================================================================
;;; Helper Functions
;;; ============================================================================

(defun vector-to-list (vec)
  "Convert a FOL <vector> to a CL list."
  (if (fol.collection:<vector>? vec)
      (let ((result nil))
        (fset:do-seq (item (slot-value vec 'fol.collection::items))
          (push item result))
        (nreverse result))
      vec))

(defun convert-slot-specifier (slot-spec)
  "Convert a FOL slot specifier to CL format.
   Handles both simple symbols and full slot specifications with vectors."
  (if (fol.collection:<vector>? slot-spec)
      (vector-to-list slot-spec)
      slot-spec))

(defun convert-specialized-param (param)
  "Convert a specialized parameter from FOL format to CL format.
   (var class-name) -> (var class-name)  ; list syntax for type specialization
   (var (eql form)) -> (var (eql form))
   var -> var
   Type specialization uses list syntax, not vector syntax."
  (cond
    ;; List - already in CL format (type specialization)
    ((and (listp param) (not (null param)))
     param)
    ;; Simple symbol
    ((symbolp param)
     param)
    ;; Anything else passes through
    (t param)))

;;; ============================================================================
;;; Generic Constructor: make
;;; ============================================================================
;;; A universal constructor function that creates instances of FOL classes.
;;; Dispatches to appropriate constructors based on the class type.

(defun make (class &rest values)
  "Create an instance of CLASS with the given VALUES.

   For collection types (can be empty):
     (make <vector>)           => []
     (make <vector> 1 2 3)     => [1 2 3]
     (make <list>)             => ()
     (make <set> 1 2 3)        => #{1 2 3}
     (make <dict> :a 1 :b 2)   => {:a 1 :b 2}

   For wrapper types (require exactly one value):
     (make <string> \"hello\")  => #<STRING \"hello\">
     (make <bool> t)           => #<BOOL T>

   CLASS can be a class name symbol or a class object.
   Non-collection classes require at least one initial value."
  (let* ((class-name (etypecase class
                       (symbol class)
                       (class (class-name class))))
         (name-string (symbol-name class-name)))
    ;; Compare by symbol name to handle symbols from different packages
    (cond
      ;; Collection types - dispatch to their specific constructors (can be empty)
      ((string= name-string "<VECTOR>")
       (apply #'fol.collection:make-vector values))
      ((string= name-string "<LIST>")
       (apply #'fol.collection:make-list values))
      ((string= name-string "<SET>")
       (apply #'fol.collection:make-set values))
      ((string= name-string "<BAG>")
       (apply #'fol.collection:make-bag values))
      ((string= name-string "<DICT>")
       (apply #'fol.collection:make-dict values))
      ((string= name-string "<ARRAY>")
       (apply #'fol.collection:make-array values))
      ((string= name-string "<LAZY-SEQ>")
       (if (= (length values) 1)
           (fol.collection:make-lazy-seq (cl:first values))
           (error "make <lazy-seq> requires exactly one thunk argument")))
      ;; Wrapper types - use :val initarg (require exactly one value)
      ((member name-string '("<STRING>" "<BOOL>" "<CHAR>" "<SYMBOL>" "<KEYWORD>")
               :test #'string=)
       (if (= (length values) 1)
           (make-instance class-name :val (cl:first values))
           (error "make ~A requires exactly one value" class-name)))
      ;; Number wrapper types (require exactly one value)
      ((member name-string '("<NUMBER>" "<COMPLEX>" "<REAL>" "<FLOAT>"
                             "<SINGLE-FLOAT>" "<DOUBLE-FLOAT>" "<RATIONAL>"
                             "<RATIO>" "<INTEGER>" "<FIXNUM>" "<BIGNUM>")
               :test #'string=)
       (if (= (length values) 1)
           (make-instance class-name :val (cl:first values))
           (error "make ~A requires exactly one value" class-name)))
      ;; Stream types - require specific initialization
      ((string= name-string "<STRING-INPUT-STREAM>")
       (if (= (length values) 1)
           (fol.stream:make-string-input-stream (cl:first values))
           (error "make <string-input-stream> requires exactly one string")))
      ((string= name-string "<STRING-OUTPUT-STREAM>")
       (fol.stream:make-string-output-stream))
      ((string= name-string "<FILE-INPUT-STREAM>")
       (if (= (length values) 1)
           (fol.stream:make-file-input-stream (cl:first values))
           (error "make <file-input-stream> requires exactly one file path")))
      ((string= name-string "<FILE-OUTPUT-STREAM>")
       (if (= (length values) 1)
           (fol.stream:make-file-output-stream (cl:first values))
           (error "make <file-output-stream> requires exactly one file path")))
      ;; Regex types
      ((string= name-string "<RE-PATTERN>")
       (if (= (length values) 1)
           (fol.string:wrap-re-pattern (cl:first values))
           (error "make <re-pattern> requires exactly one pattern string")))
      ((string= name-string "<RE-SCANNER>")
       (if (>= (length values) 1)
           (apply #'fol.string:make-re-scanner values)
           (error "make <re-scanner> requires at least one <re-pattern>")))
      ;; Default: require at least one value for non-collection types
      (t
       (when (null values)
         (error "make ~A requires at least one initial value" class-name))
       (if (and (= (length values) 1)
                (cl:not (keywordp (cl:first values))))
           ;; Single non-keyword value: try :val
           (make-instance class-name :val (cl:first values))
           ;; Multiple values or keyword args: pass as initargs
           (apply #'make-instance class-name values))))))

;;; ============================================================================
;;; defgeneric*
;;; ============================================================================
;;;
;;; Grammar:
;;;   defgeneric-form ::= (defgeneric function-name [gf-lambda-declaration | (gf-lambda-declaration+)] generic-option*)
;;;   gf-lambda-declaration ::= gf-destructuring-vector method-option* method-description?
;;;   generic-option ::= (:documentation <string>) | (:generic-function-class <class-name>)
;;;   method-option ::= (:argument-precedence-order <parameter-name>+) | (declare gf-declaration+) |
;;;                     (:method-combination <method-combination-type>) | (:method-class <class-name>)
;;;   method-description ::= (:method method-qualifier* method-destructuring-vector method-option* form*)

;;; ============================================================================
;;; Pattern Analysis
;;; ============================================================================
;;; Analyze destructuring patterns to determine what structure an argument expects.

(defun param-is-destructuring-p (param)
  "Check if PARAM is a destructuring pattern (a vector that doesn't start with a symbol).
   [a b] with symbol a is a type specialization: (a b) -> param a of type b
   [[a b]] with vector [a b] is destructuring: expects a sequence"
  (and (fol.collection:<vector>? param)
       (let ((first-elem (fol.seqop:first param)))
         ;; If first element is a vector, it's destructuring
         ;; If first element is a symbol and length is 2, it's type specialization
         (or (fol.collection:<vector>? first-elem)
             ;; Length > 2 means multiple elements to destructure
             (> (fol.seqop:size param) 2)
             ;; Length = 1 means just binding a name
             (and (= (fol.seqop:size param) 1)
                  (symbolp first-elem))))))

(defun pattern-expects-seq-p (param &key (defgeneric-context t))
  "Check if PARAM expects a sequential argument (destructuring pattern).
   Returns nil for simple params, the minimum required size for seq patterns.

   In defgeneric context (default), any vector is a destructuring pattern:
     [a b] means 'expects sequence of 2 elements'

   In defmethod context, (var type) is type specialization using list syntax:
     (a <integer>) means 'param a of type <integer>'
   Vectors in defmethod context are destructuring patterns."
  (cond
    ;; Simple symbol - matches any
    ((symbolp param) nil)
    ;; List in defmethod context - type or predicate specialization (not destructuring)
    ;; (var type) or (var (fn arg...))
    ((and (listp param)
          (not (null param))
          (not defgeneric-context)
          (symbolp (first param))
          (= (length param) 2)
          (or (symbolp (second param))           ; Type: (var <type>)
              (listp (second param))))           ; Predicate: (var (fn ...))
     nil)
    ;; Vector - check if it's destructuring
    ((and (fol.collection:<vector>? param)
          (> (fol.seqop:size param) 0))
     (let ((elems (vector-to-list param)))
       ;; Any vector is a destructuring pattern
       (length elems)))
    ;; Anything else
    (t nil)))

(defun compute-element-signature (elem)
  "Compute signature for a single element within a destructuring pattern.
   Used recursively for nested patterns. Returns a signature spec."
  (cond
    ;; Simple symbol - matches anything
    ((symbolp elem) (list :any))
    ;; Predicate specializer: (var (fn arg0 arg1 ...))
    ((and (listp elem)
          (not (null elem))
          (= (length elem) 2)
          (symbolp (first elem))
          (listp (second elem))
          (not (null (second elem))))
     (let ((pred-form (second elem)))
       ;; Keep arguments as-is (including quoted forms) - they will be
       ;; evaluated later by resolve-signature-predicates using FOL eval
       (list :pred (first pred-form) (rest pred-form))))
    ;; Type specialization: (var <type>)
    ((and (listp elem)
          (not (null elem))
          (= (length elem) 2)
          (symbolp (first elem))
          (symbolp (second elem)))
     (list :type (second elem)))
    ;; Dict pattern - map destructuring (treat as :any for signature matching)
    ((fol.collection:<dict>? elem)
     (list :any))
    ;; Nested vector - recursively process elements
    ((fol.collection:<vector>? elem)
     (let ((elements (vector-to-list elem)))
       ;; Filter out :as bindings (they don't affect pattern matching)
       (let ((filtered-elems (filter-as-bindings elements)))
         (list :seq (mapcar #'compute-element-signature filtered-elems)))))
    ;; Default: any (including CL lists for other destructuring forms)
    (t (list :any))))

(defun filter-as-bindings (elem-list)
  "Filter out :as and its following symbol from an element list.
   Also filters out & and rest parameters.
   Returns elements that participate in pattern matching."
  (let ((result nil))
    (loop for remaining on elem-list
          for elem = (car remaining)
          do (cond
               ;; :as keyword - skip it and the next element
               ((eq elem :as)
                (setf remaining (cdr remaining)) ; Skip the next element too
                (return))
               ;; & keyword - stop processing (rest params don't participate in matching)
               ((and (symbolp elem) (string= (symbol-name elem) "&"))
                (return))
               ;; Regular element - include it
               (t (push elem result))))
    (nreverse result)))

(defun compute-pattern-signature (lambda-list)
  "Compute a signature describing what each parameter expects.
   Returns a list of pattern specs for each parameter:
   - (:any) for simple parameters
   - (:seq element-sigs) for sequence destructuring with nested structure
   - (:type class-name) for type specialization (var class-name)
   - (:type-pred predicate-fn) for type predicate ((<type>? var))
   - (:pred fn args) for predicate specialization (var (fn args...))

   The new :seq format includes per-element signatures to support nested
   predicates like [x y (z (< 10))]."
  (mapcar (lambda (param)
            (cond
              ;; Predicate specializer: (var (fn arg0 arg1 ...))
              ;; Any list form is treated as a predicate application
              ((and (listp param)
                    (not (null param))
                    (= (length param) 2)
                    (symbolp (first param))
                    (listp (second param))
                    (not (null (second param))))
               (let ((pred-form (second param)))
                 ;; Predicate: (var (fn arg0 arg1 ...))
                 ;; Keep arguments as-is (including quoted forms) - they will be
                 ;; evaluated later by resolve-signature-predicates using FOL eval
                 (list :pred (first pred-form) (rest pred-form))))
              ;; Type specialization with predicate: ((<type>? var))
              ((and (listp param)
                    (not (null param))
                    (= (length param) 1)
                    (listp (first param))
                    (= (length (first param)) 2)
                    (symbolp (first (first param)))
                    (let ((pred-name (symbol-name (first (first param)))))
                      (and (> (length pred-name) 1)
                           (char= (char pred-name (1- (length pred-name))) #\?))))
               (list :type-pred (first (first param))))
              ;; Type specialization: (var <type>)
              ((and (listp param)
                    (not (null param))
                    (= (length param) 2)
                    (symbolp (first param))
                    (symbolp (second param)))
               (list :type (second param)))
              ;; Dict pattern - map destructuring (treat as :any for signature matching)
              ((fol.collection:<dict>? param)
               (list :any))
              ;; Sequence pattern - recursively compute element signatures
              ((fol.collection:<vector>? param)
               (let ((elements (vector-to-list param)))
                 ;; Filter out :as bindings (they don't affect pattern matching)
                 (let ((filtered-elems (filter-as-bindings elements)))
                   (list :seq (mapcar #'compute-element-signature filtered-elems)))))
              ;; Default: any
              (t (list :any))))
          lambda-list))

(defun pattern-specificity-level (sig)
  "Return numeric specificity level for a signature.
   Higher numbers are more specific.
   Order: Pred (3) > Type/Type-Pred (2) > Seq (1) > Any (0)

   For sequences, the base level is 1, but specificity also considers
   the element signatures for detailed comparison."
  (case (first sig)
    (:pred 3)  ; Predicate specializers (=, <, >, contains?, etc.)
    (:type 2)
    (:type-pred 2)  ; Same level as :type - both are type checks
    (:seq 1)
    (:any 0)
    (t 0)))

(defun pattern-more-specific-p (sig1 sig2)
  "Return T if SIG1 is more specific than SIG2.
   Specificity order: :pred (3) > :type/:type-pred (2) > :seq (1) > :any (0)"
  (loop for s1 in sig1
        for s2 in sig2
        for level1 = (pattern-specificity-level s1)
        for level2 = (pattern-specificity-level s2)
        do (cond
             ;; Different specificity levels
             ((> level1 level2)
              (return-from pattern-more-specific-p t))
             ((< level1 level2)
              (return-from pattern-more-specific-p nil))
             ;; Same level - check sub-specificity for sequences
             ((and (eq (first s1) :seq) (eq (first s2) :seq))
              ;; Compare element signatures
              (let ((elems1 (second s1))
                    (elems2 (second s2)))
                (cond
                  ;; More elements = more specific
                  ((> (length elems1) (length elems2))
                   (return-from pattern-more-specific-p t))
                  ((< (length elems1) (length elems2))
                   (return-from pattern-more-specific-p nil))
                  ;; Same number of elements - compare element by element
                  (t
                   (loop for e1 in elems1
                         for e2 in elems2
                         for el1 = (pattern-specificity-level e1)
                         for el2 = (pattern-specificity-level e2)
                         do (cond
                              ((> el1 el2)
                               (return-from pattern-more-specific-p t))
                              ((< el1 el2)
                               (return-from pattern-more-specific-p nil))
                              ;; If both are sequences, recurse
                              ((and (eq (first e1) :seq) (eq (first e2) :seq))
                               (let ((sub-result (pattern-more-specific-p
                                                   (list e1) (list e2))))
                                 (when sub-result
                                   (return-from pattern-more-specific-p t))))))))))))
  ;; Equal specificity
  nil)

(defun generate-pattern-check (signature arg-sym)
  "Generate code to check if ARG-SYM matches SIGNATURE.
   SIGNATURE is a single pattern spec like (:any) or (:seq [element-sigs])."
  (case (first signature)
    (:any t)
    (:seq
     ;; The second element is a list of element signatures, get its length for arity
     (let ((arity (length (second signature))))
       `(and (or (fol.collection:<vector>? ,arg-sym)
                 (fol.collection:<list>? ,arg-sym)
                 (listp ,arg-sym))
             (>= (if (listp ,arg-sym)
                     (length ,arg-sym)
                     (fol.seqop:size ,arg-sym))
                 ,arity))))
    (t t)))

(defun generate-args-pattern-check (signatures args-sym)
  "Generate code to check if ARGS-SYM matches all SIGNATURES."
  (let ((checks
          (loop for sig in signatures
                for i from 0
                for arg-access = `(cl:nth ,i ,args-sym)
                for check = (generate-pattern-check sig arg-access)
                unless (eq check t)
                  collect check)))
    (if (null checks)
        t
        (if (= (length checks) 1)
            (first checks)
            `(and ,@checks)))))

;;; ============================================================================
;;; Lambda Declaration Parsing
;;; ============================================================================

(defun gf-lambda-declaration-p (form)
  "Check if FORM is a gf-lambda-declaration (vector optionally followed by options)."
  (fol.collection:<vector>? form))

(defun multi-pattern-lambda-list-p (spec)
  "Check if SPEC is a list of gf-lambda-declarations (multi-pattern specification)."
  (and (listp spec)
       (not (null spec))
       (every #'gf-lambda-declaration-p spec)))

(defun parse-gf-lambda-declaration (decl)
  "Parse a gf-lambda-declaration.
   Returns (values destructuring-vector method-options method-description).
   For now, simplified: just returns the vector as the pattern."
  (if (fol.collection:<vector>? decl)
      (values decl nil nil)
      (error "Invalid gf-lambda-declaration: ~S" decl)))

(defun make-pattern-name (function-name pattern-index)
  "Create an internal name for a pattern-specific generic function."
  (intern (format nil "~A/P~A" function-name pattern-index)
          (symbol-package function-name)))

(defun generate-simple-lambda-list (arity)
  "Generate a simple lambda list with ARG0, ARG1, etc. for a generic function."
  (loop for i below arity
        collect (intern (format nil "ARG~A" i))))

(defun extract-simple-param-name (param)
  "Extract a simple parameter name from a potentially destructuring parameter.
   For symbol: returns the symbol
   For (var type): returns var (type specialization uses list syntax)
   For [a b c ...]: returns a gensym (destructuring pattern uses vector syntax)"
  (cond
    ((symbolp param) param)
    ;; List - type specialization (var type)
    ((and (listp param)
          (not (null param))
          (= (length param) 2)
          (symbolp (first param)))
     (first param))
    ;; Vector - destructuring pattern
    ((fol.collection:<vector>? param)
     (gensym "DESTRUCT-ARG"))
    (t (gensym "ARG"))))

(defmacro defgeneric* (function-name lambda-list-spec &rest options)
  "Define a generic function with FOL syntax.
   Lambda list can be:
   - A single vector: [arg1 arg2 ...] - defines single-pattern generic
   - A list of vectors: ([a] [a b] [[x y]]) - defines multi-pattern generic with dispatcher

   Syntax:
     (defgeneric* name [lambda-list] generic-option*)
     (defgeneric* name ([lambda-list-1] [lambda-list-2] ...) generic-option*)

   For multi-pattern, creates:
   - Internal generic functions named function-name/PN for each pattern N
   - A dispatcher function with the original name that routes by arity and pattern match
   - Patterns are checked most-specific first (destructuring patterns before :any)

   Examples:
     ;; Single pattern
     (defgeneric* distance [a b]
       (:documentation \"Calculate distance between two objects.\"))

     ;; Multi-arity (different argument counts)
     (defgeneric* foo ([x] [x y] [x y z])
       (:documentation \"Function with 1, 2, or 3 arguments.\"))

     ;; Multi-pattern with destructuring (same arity, different structure)
     (defgeneric* process-input ([x] [[a b]])
       (:documentation \"Process a single value or destructure a pair.\"))"
  (cond
    ;; Single pattern: a vector
    ((fol.collection:<vector>? lambda-list-spec)
     (let ((lambda-list (vector-to-list lambda-list-spec)))
       `(defgeneric ,function-name ,lambda-list
          ,@options)))
    ;; Multiple patterns: a list of vectors
    ((multi-pattern-lambda-list-p lambda-list-spec)
     (let* (;; Parse each pattern with its index
            (patterns (loop for vec in lambda-list-spec
                            for idx from 0
                            for ll = (vector-to-list vec)
                            collect (list :index idx
                                          :arity (length ll)
                                          :lambda-list ll
                                          :signature (compute-pattern-signature ll)
                                          :internal-name (make-pattern-name function-name idx))))
            ;; Sort patterns: first by arity, then by specificity (most specific first)
            (sorted-patterns
              (stable-sort (copy-list patterns)
                           (lambda (p1 p2)
                             (let ((a1 (getf p1 :arity))
                                   (a2 (getf p2 :arity)))
                               (cond
                                 ((< a1 a2) t)
                                 ((> a1 a2) nil)
                                 ;; Same arity: more specific pattern first
                                 (t (pattern-more-specific-p
                                     (getf p1 :signature)
                                     (getf p2 :signature))))))))
            ;; Generate generic function definitions with simple parameter names
            ;; (CLOS defgeneric doesn't support destructuring in lambda lists)
            (generic-defs
              (loop for p in patterns
                    for internal-name = (getf p :internal-name)
                    for arity = (getf p :arity)
                    for simple-ll = (generate-simple-lambda-list arity)
                    collect `(defgeneric ,internal-name ,simple-ll ,@options)))
            ;; Group patterns by arity for dispatcher
            (patterns-by-arity
              (let ((ht (make-hash-table)))
                (dolist (p sorted-patterns)
                  (push p (gethash (getf p :arity) ht)))
                (loop for arity being the hash-keys of ht
                      using (hash-value ps)
                      collect (cons arity (nreverse ps)))))
            ;; Generate dispatcher cases
            (dispatcher-cases
              (loop for (arity . arity-patterns) in (sort patterns-by-arity #'< :key #'car)
                    collect
                    (if (= (length arity-patterns) 1)
                        ;; Single pattern for this arity - direct dispatch
                        (let ((p (first arity-patterns)))
                          `(,arity (apply #',(getf p :internal-name) args)))
                        ;; Multiple patterns for same arity - pattern matching
                        (let ((cond-clauses
                                (loop for p in arity-patterns
                                      for sig = (getf p :signature)
                                      for check = (generate-args-pattern-check sig 'args)
                                      collect `(,check (apply #',(getf p :internal-name) args)))))
                          `(,arity (cond
                                     ,@cond-clauses
                                     (t (error "No matching pattern for ~A with args ~S"
                                               ',function-name args)))))))))
       `(progn
          ,@generic-defs
          (defun ,function-name (&rest args)
            (case (length args)
              ,@dispatcher-cases
              (t (error "No matching arity ~A for ~A (valid arities: ~{~A~^, ~})"
                        (length args) ',function-name
                        ',(sort (mapcar #'car patterns-by-arity) #'<)))))
          ;; Store pattern info for defmethod* to use
          (setf (get ',function-name 'multi-pattern-info)
                ',(mapcar (lambda (p)
                            (list :index (getf p :index)
                                  :arity (getf p :arity)
                                  :signature (getf p :signature)
                                  :internal-name (getf p :internal-name)))
                          patterns))
          ',function-name)))
    ;; Already a list (backwards compat for CL-style lambda lists)
    (t
     `(defgeneric ,function-name ,lambda-list-spec
        ,@options))))

;;; ============================================================================
;;; defclass*
;;; ============================================================================

(defmacro defclass* (class-name superclasses-vec slots-vec &rest class-options)
  "Define a class with FOL syntax.
   Superclasses and slots are specified as vectors.

   Syntax:
     (defclass* name [superclasses] [slots] class-option*)

   Slots can be:
     - Simple: symbol
     - Full: [slot-name :initarg :name :accessor accessor-name ...]

   Example:
     (defclass* <point> [<persistent-object>]
       [[x :initarg :x :accessor point-x :type real]
        [y :initarg :y :accessor point-y :type real]]
       (:documentation \"A 2D point.\"))"
  (let ((superclasses (if (fol.collection:<vector>? superclasses-vec)
                          (vector-to-list superclasses-vec)
                          superclasses-vec))
        (slots (if (fol.collection:<vector>? slots-vec)
                   (mapcar #'convert-slot-specifier (vector-to-list slots-vec))
                   slots-vec)))
    `(defclass ,class-name ,superclasses
       ,slots
       ,@class-options)))

;;; ============================================================================
;;; defmethod*
;;; ============================================================================

(defun method-signature-matches-pattern-p (method-sig pattern-sig)
  "Check if a method signature is compatible with a pattern signature.
   A method can be added to a pattern if:
   - Same number of parameters
   - Each method param is compatible with the pattern param

   Pattern :any accepts any method signature (most general)
   Method specializers (:type, :pred, :type-pred) can match :any patterns"
  (and (= (length method-sig) (length pattern-sig))
       (every (lambda (m-sig p-sig)
                (cond
                  ;; Pattern :any accepts any method signature
                  ((eq (first p-sig) :any) t)
                  ;; Both :any - match
                  ((and (eq (first m-sig) :any) (eq (first p-sig) :any)) t)
                  ;; Both :seq - method size must be <= pattern size (method is more general)
                  ((and (eq (first m-sig) :seq) (eq (first p-sig) :seq))
                   (<= (length (second m-sig)) (length (second p-sig))))
                  ;; Both same type of specialization - match
                  ((eq (first m-sig) (first p-sig)) t)
                  (t nil)))
              method-sig pattern-sig)))

(defun find-matching-pattern (function-name lambda-list)
  "Find the pattern that best matches LAMBDA-LIST for FUNCTION-NAME.
   Returns the internal generic name or nil if no match."
  (let ((pattern-info (get function-name 'multi-pattern-info)))
    (when pattern-info
      (let* ((arity (length lambda-list))
             (method-sig (compute-pattern-signature lambda-list))
             ;; Find patterns with matching arity
             (matching-arities (remove-if-not
                                (lambda (p) (= (getf p :arity) arity))
                                pattern-info))
             ;; Find best matching pattern
             (best-match
               (find-if (lambda (p)
                          (method-signature-matches-pattern-p
                           method-sig (getf p :signature)))
                        matching-arities)))
        (when best-match
          (getf best-match :internal-name))))))

(defun determine-method-target (function-name lambda-list)
  "Determine which generic function a method should be added to.
   For multi-pattern generics, returns the pattern-specific name (e.g., foo/P0).
   For single-pattern generics, returns the original name."
  (let ((pattern-match (find-matching-pattern function-name lambda-list)))
    (if pattern-match
        pattern-match
        function-name)))

(defun generate-destructuring-method (function-name qualifiers params body)
  "Generate a method definition with destructuring pattern support.
   PARAMS is a list that may contain FOL vectors (destructuring patterns).
   Returns a defmethod form that checks patterns and destructures arguments."
  (let* ((simple-params (loop for p in params
                             for i from 0
                             collect (if (fol.collection:<vector>? p)
                                       (intern (format nil "ARG~D" i))
                                       (convert-specialized-param p))))
         (target-name (determine-method-target function-name
                                              (mapcar #'convert-specialized-param params))))
    `(defmethod ,target-name ,@qualifiers ,simple-params
       ;; Check pattern and destructure
       (let ((args (list ,@simple-params)))
         (if (fol.eval::args-match-pattern-p args ',(compute-pattern-signature params))
             ;; Pattern matches - destructure and bind variables
             (fol.eval::destructure-and-execute
              ',params
              args
              (lambda ,(fol.eval::collect-pattern-vars params)
                ,@body))
             ;; Pattern doesn't match - try next method
             (call-next-method))))))

(defmacro defmethod* (function-name &rest args)
  "Define a method with FOL syntax.
   Specialized lambda list is specified as a vector.

   Syntax:
     (defmethod* name qualifier* [specialized-lambda-list] body*)

   Specialized parameters can be:
     - Simple: var
     - Specialized: (var class-name) or (var (eql form))
     - Destructuring: [a b] or [[a b] c] etc. with nested predicates

   For multi-arity generics (defined with a list of vectors), the method
   is automatically routed to the correct arity-specific generic function.

   Example:
     (defmethod* distance [(a <point>) (b <point>)]
       (sqrt (+ (expt (- (point-x b) (point-x a)) 2)
                (expt (- (point-y b) (point-y a)) 2))))

     (defmethod* process [[[x (y (< 10))]]]
       (list :matched x y))"
  ;; Parse qualifiers and lambda-list from args
  ;; Qualifiers are non-list, non-vector atoms before the lambda-list
  (let ((qualifiers nil)
        (lambda-list-vec nil)
        (body nil)
        (remaining args))
    ;; Collect qualifiers (atoms that aren't the lambda list vector)
    (loop while (and remaining
                     (not (fol.collection:<vector>? (car remaining)))
                     (not (listp (car remaining))))
          do (push (pop remaining) qualifiers))
    (setf qualifiers (nreverse qualifiers))
    ;; Next should be the lambda list
    (when remaining
      (setf lambda-list-vec (pop remaining))
      (setf body remaining))
    ;; Check if lambda list has destructuring patterns
    (let* ((params (if (fol.collection:<vector>? lambda-list-vec)
                       (vector-to-list lambda-list-vec)
                       lambda-list-vec))
           (has-destructuring (some #'fol.collection:<vector>? params)))
      (if has-destructuring
          ;; Generate method with destructuring support
          (generate-destructuring-method function-name qualifiers params body)
          ;; Standard method without destructuring
          (let* ((lambda-list (mapcar #'convert-specialized-param params))
                 (target-name (determine-method-target function-name lambda-list)))
            `(defmethod ,target-name ,@qualifiers ,lambda-list
               ,@body))))))

;;; ============================================================================
;;; Evaluation Support for FOL
;;; ============================================================================
;;; These functions are called by the FOL evaluator to process the special forms.

(defun eval-defgeneric* (name lambda-list-spec options)
  "Evaluate a defgeneric* form at runtime.
   Handles both single-pattern (vector) and multi-pattern (list of vectors)."
  (cond
    ;; Single pattern: a vector
    ((fol.collection:<vector>? lambda-list-spec)
     (let ((lambda-list (vector-to-list lambda-list-spec)))
       (eval `(defgeneric ,name ,lambda-list ,@options))))
    ;; Multiple patterns: a list of vectors
    ((multi-pattern-lambda-list-p lambda-list-spec)
     (let* (;; Parse each pattern with its index
            (patterns (loop for vec in lambda-list-spec
                            for idx from 0
                            for ll = (vector-to-list vec)
                            collect (list :index idx
                                          :arity (length ll)
                                          :lambda-list ll
                                          :signature (compute-pattern-signature ll)
                                          :internal-name (make-pattern-name name idx))))
            ;; Sort patterns: first by arity, then by specificity (most specific first)
            (sorted-patterns
              (stable-sort (copy-list patterns)
                           (lambda (p1 p2)
                             (let ((a1 (getf p1 :arity))
                                   (a2 (getf p2 :arity)))
                               (cond
                                 ((< a1 a2) t)
                                 ((> a1 a2) nil)
                                 (t (pattern-more-specific-p
                                     (getf p1 :signature)
                                     (getf p2 :signature)))))))))
       ;; Define each pattern-specific generic with simple parameter names
       ;; (CLOS defgeneric doesn't support destructuring in lambda lists)
       (loop for p in patterns
             for internal-name = (getf p :internal-name)
             for arity = (getf p :arity)
             for simple-ll = (generate-simple-lambda-list arity)
             do (eval `(defgeneric ,internal-name ,simple-ll ,@options)))
       ;; Group patterns by arity
       (let* ((patterns-by-arity
                (let ((ht (make-hash-table)))
                  (dolist (p sorted-patterns)
                    (push p (gethash (getf p :arity) ht)))
                  (loop for arity being the hash-keys of ht
                        using (hash-value ps)
                        collect (cons arity (nreverse ps)))))
              ;; Generate dispatcher cases
              (dispatcher-cases
                (loop for (arity . arity-patterns) in (sort patterns-by-arity #'< :key #'car)
                      collect
                      (if (= (length arity-patterns) 1)
                          (let ((p (first arity-patterns)))
                            `(,arity (apply #',(getf p :internal-name) args)))
                          (let ((cond-clauses
                                  (loop for p in arity-patterns
                                        for sig = (getf p :signature)
                                        for check = (generate-args-pattern-check sig 'args)
                                        collect `(,check (apply #',(getf p :internal-name) args)))))
                            `(,arity (cond
                                       ,@cond-clauses
                                       (t (error "No matching pattern for ~A with args ~S"
                                                 ',name args)))))))))
         (eval `(defun ,name (&rest args)
                  (case (length args)
                    ,@dispatcher-cases
                    (t (error "No matching arity ~A for ~A (valid arities: ~{~A~^, ~})"
                              (length args) ',name
                              ',(sort (mapcar #'car patterns-by-arity) #'<)))))))
       ;; Store pattern info
       (setf (get name 'multi-pattern-info)
             (mapcar (lambda (p)
                       (list :index (getf p :index)
                             :arity (getf p :arity)
                             :signature (getf p :signature)
                             :internal-name (getf p :internal-name)))
                     patterns))
       name))
    ;; Already a list (backwards compat)
    (t
     (eval `(defgeneric ,name ,lambda-list-spec ,@options)))))

(defun eval-defclass* (name superclasses-vec slots-vec class-options)
  "Evaluate a defclass* form at runtime."
  (let ((superclasses (if (fol.collection:<vector>? superclasses-vec)
                          (vector-to-list superclasses-vec)
                          superclasses-vec))
        (slots (if (fol.collection:<vector>? slots-vec)
                   (mapcar #'convert-slot-specifier (vector-to-list slots-vec))
                   slots-vec)))
    (eval `(defclass ,name ,superclasses ,slots ,@class-options))))

(defun eval-defmethod* (name qualifiers lambda-list-vec body)
  "Evaluate a defmethod* form at runtime.
   For multi-arity generics, routes to the correct arity-specific generic."
  (let* ((lambda-list (if (fol.collection:<vector>? lambda-list-vec)
                          (mapcar #'convert-specialized-param
                                  (vector-to-list lambda-list-vec))
                          lambda-list-vec))
         (target-name (determine-method-target name lambda-list)))
    (eval `(defmethod ,target-name ,@qualifiers ,lambda-list ,@body))))
