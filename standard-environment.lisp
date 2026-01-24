(in-package fol.eval)

;;; ============================================================================
;;; Standard Macros
;;; ============================================================================

(defun make-when-macro ()
  "Create the 'when' macro.
   (when test form0 form1 ... formN) expands to (if test (do form0 form1 ... formN) nil)"
  (make-macro
   '(test)                    ; params: just test
   '((syntax-quote            ; body: expand to (if test (do ~@body) nil)
      (if (unquote test)
          (do (unquote-splicing body))
          nil)))
   nil                        ; env
   :rest-param 'body          ; rest param captures all body forms
   :name 'when))

(defun make-unless-macro ()
  "Create the 'unless' macro.
   (unless test form0 form1 ... formN) expands to (if test nil (do form0 form1 ... formN))"
  (make-macro
   '(test)                    ; params: just test
   '((syntax-quote            ; body: expand to (if test nil (do ~@body))
      (if (unquote test)
          nil
          (do (unquote-splicing body)))))
   nil                        ; env
   :rest-param 'body          ; rest param captures all body forms
   :name 'unless))

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
            'ln #'ln
            'mod #'cl:mod
            'rem #'cl:rem
            'abs #'abs
            'sin #'sin
            'cos #'cos
            'tan #'tan
            'sqrt #'sqrt
            'expt #'expt
            'exp #'exp
            'ln #'ln
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
            '<bool>? #'(lambda (x) (typep x 'boolean))
            '<char>? #'cl:characterp
            '<number>? #'cl:numberp
            '<integer>? #'cl:integerp
            '<fixnum>? #'(lambda (x) (typep x 'fixnum))
            '<bignum>? #'(lambda (x) (typep x 'bignum))
            '<float>? #'cl:floatp
            '<single-float>? #'(lambda (x) (typep x 'single-float))
            '<double-float>? #'(lambda (x) (typep x 'double-float))
            '<ratio>? #'(lambda (x) (typep x 'ratio))
            '<rational>? #'cl:rationalp
            '<complex>? #'cl:complexp
            '<string>? #'cl:stringp
            '<symbol>? #'cl:symbolp
            '<keyword>? #'cl:keywordp
            ;; Collection type predicates
            '<collection>? #'fol.collection:<collection>?
            '<ordered-collection>? #'fol.collection:<ordered-collection>?
            '<unordered-collection>? #'fol.collection:<unordered-collection>?
            '<vector>? #'fol.collection:<vector>?
            '<list>? #'fol.collection:<list>?
            '<dict>? #'fol.collection:<dict>?
            '<set>? #'fol.collection:<set>?
            '<bag>? #'fol.collection:<bag>?
            '<array>? #'fol.collection:<array>?
            '<lazy-seq>? #'fol.collection:<lazy-seq>?
            ;; Number predicates
            'positive? #'fol.number:positive?
            'negative? #'fol.number:negative?
            'zero? #'fol.number:zero?
            'even? #'fol.number:even?
            'odd? #'fol.number:odd?
            ;; CL list operations (for compatibility)
            'list #'cl:list
            'cons #'cl:cons
            'append #'cl:append
            'reverse #'cl:reverse
            ;; String operations
            'str #'(lambda (&rest args)
                     (apply #'concatenate 'string
                            (mapcar #'princ-to-string args)))
            ;; Misc
            'identity #'cl:identity
            'complement #'cl:complement
            'disjoin #'(lambda (&rest predicates)
                         "Returns a function that is the disjunction (OR) of the predicates.
                          The returned function applies predicates in order until one returns
                          a truthy value (short-circuit). Returns that value, or nil if none."
                         (lambda (&rest args)
                           (loop for pred in predicates
                                 for result = (apply-function pred args)
                                 when result return result
                                 finally (return nil))))
            'conjoin #'(lambda (&rest predicates)
                         "Returns a function that is the conjunction (AND) of the predicates.
                          The returned function applies predicates in order. If any returns nil,
                          immediately returns nil (short-circuit). Otherwise returns the last result."
                         (lambda (&rest args)
                           (if (null predicates)
                               t  ; empty conjunction is true
                               (loop for pred in predicates
                                     for result = (apply-function pred args)
                                     unless result return nil
                                     finally (return result)))))
            'partial #'(lambda (f &rest bound-args)
                         "Returns a function that calls f with bound-args prepended to any additional args.
                          (partial f a b) returns a function that, when called with (x y), calls (f a b x y)."
                         (lambda (&rest more-args)
                           (apply-function f (append bound-args more-args))))
            'rpartial #'(lambda (f &rest bound-args)
                          "Returns a function that calls f with bound-args appended to any additional args.
                           (rpartial f a b) returns a function that, when called with (x y), calls (f x y a b)."
                          (lambda (&rest more-args)
                            (apply-function f (append more-args bound-args))))
            'juxt #'(lambda (&rest fns)
                      "Returns a function that applies each fn to its args and returns the results as multiple values.
                       (juxt f g h) returns a function that, when called with args, returns (values (f args) (g args) (h args))."
                      (lambda (&rest args)
                        (values-list
                         (loop for fn in fns
                               collect (apply-function fn args)))))
            'print #'cl:print
            'type #'fol.wrappers:fol-type-of
            ;; Generic constructor
            'make #'make
            ;; Bitwise operations
            'bitnot #'fol.bitop:bitnot
            'bitand #'fol.bitop:bitand
            'bitor #'fol.bitop:bitor
            'bitxor #'fol.bitop:bitxor
            'bit-nand #'fol.bitop:bit-nand
            'bit-nor #'fol.bitop:bit-nor
            'bit-andc1 #'fol.bitop:bit-andc1
            'bit-andc2 #'fol.bitop:bit-andc2
            'bit-orc1 #'fol.bitop:bit-orc1
            'bit-orc2 #'fol.bitop:bit-orc2
            'bit-test #'fol.bitop:bit-test
            'bit-set #'fol.bitop:bit-set
            'bit-clear #'fol.bitop:bit-clear
            'bit-count #'fol.bitop:bit-count
            ;; FOL collection operations
            'conj #'fol.collection:conj
            'first #'fol.collection:first
            'rest #'fol.collection:rest
            'second #'fol.collection:second
            'third #'fol.collection:third
            'nth #'fol.collection:nth
            'size #'fol.collection:size
            'empty? #'fol.collection:empty?
            'get #'fol.collection:get
            'contains? #'fol.collection:contains?
            'seq #'fol.collection:seq
            'add #'fol.collection:add
            'remove #'fol.collection:remove
            ;; Higher-order collection operations
            'reduce #'(lambda (f &rest args)
                        "Reduce a collection using function f.
                         (reduce f coll) - uses first element as initial value
                         (reduce f init coll) - uses init as initial value
                         f is called as (f accumulator element) for each element."
                        (cond
                          ;; (reduce f coll) - no initial value
                          ((= (cl:length args) 1)
                           (let* ((coll (cl:first args))
                                  (s (fol.collection:seq coll)))
                             (if (null s)
                                 (apply-function f nil)  ; call f with no args for empty coll
                                 (let ((acc (fol.collection:first s))
                                       (s (fol.collection:rest s)))
                                   (loop until (fol.collection:empty? s)
                                         do (setf acc (apply-function f (cl:list acc (fol.collection:first s))))
                                            (setf s (fol.collection:rest s)))
                                   acc))))
                          ;; (reduce f init coll) - with initial value
                          ((= (cl:length args) 2)
                           (let* ((init (cl:first args))
                                  (coll (cl:second args))
                                  (s (fol.collection:seq coll))
                                  (acc init))
                             (loop until (or (null s) (fol.collection:empty? s))
                                   do (setf acc (apply-function f (cl:list acc (fol.collection:first s))))
                                      (setf s (fol.collection:rest s)))
                             acc))
                          (t (error "reduce requires 2 or 3 arguments"))))
            'map #'(lambda (f coll)
                     "Apply f to each element of coll, returning a list of results.
                      Implemented using reduce."
                     (let ((s (fol.collection:seq coll)))
                       (if (null s)
                           (fol.collection:make-list)  ; empty list
                           ;; Reduce to build result in reverse, then reverse
                           (let ((result
                                   (cl:labels ((reduce-fn (acc elem)
                                                 (cl:cons (apply-function f (cl:list elem)) acc)))
                                     (let ((acc nil)
                                           (current s))
                                       (loop until (or (null current) (fol.collection:empty? current))
                                             do (setf acc (reduce-fn acc (fol.collection:first current)))
                                                (setf current (fol.collection:rest current)))
                                       acc))))
                             (apply #'fol.collection:make-list (cl:nreverse result))))))
            'filter #'(lambda (pred coll)
                        "Return a list of elements from coll for which pred returns truthy.
                         Implemented using reduce."
                        (let ((s (fol.collection:seq coll)))
                          (if (null s)
                              (fol.collection:make-list)  ; empty list
                              ;; Reduce to build result in reverse, then reverse
                              (let ((result
                                      (cl:labels ((reduce-fn (acc elem)
                                                    (if (apply-function pred (cl:list elem))
                                                        (cl:cons elem acc)
                                                        acc)))
                                        (let ((acc nil)
                                              (current s))
                                          (loop until (or (null current) (fol.collection:empty? current))
                                                do (setf acc (reduce-fn acc (fol.collection:first current)))
                                                   (setf current (fol.collection:rest current)))
                                          acc))))
                                (apply #'fol.collection:make-list (cl:nreverse result))))))
            ;; Standard macros
            'when (make-when-macro)
            'unless (make-unless-macro)))
