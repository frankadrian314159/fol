;;; FOL Compiler Tests - Destructuring, Pattern Signatures, and Fn Compilation

(in-package :fol.compiler.tests)

(in-suite destructure-tests)

;;; ---------------------------------------------------------------------------
;;; parse-params
;;; ---------------------------------------------------------------------------

(test parse-params-simple
  "parse-params splits a simple param list."
  (multiple-value-bind (regular rest-param)
      (fol.compiler.destructure:parse-params '(a b c))
    (is (equal '(a b c) regular))
    (is (null rest-param))))

(test parse-params-with-rest
  "parse-params handles & rest parameter."
  (multiple-value-bind (regular rest-param)
      (fol.compiler.destructure:parse-params '(a b & more))
    (is (equal '(a b) regular))
    (is (eq 'more rest-param))))

(test parse-params-empty
  "parse-params handles empty list."
  (multiple-value-bind (regular rest-param)
      (fol.compiler.destructure:parse-params '())
    (is (null regular))
    (is (null rest-param))))

;;; ---------------------------------------------------------------------------
;;; strip-specializers
;;; ---------------------------------------------------------------------------

(test strip-specializers-simple
  "strip-specializers passes through simple symbols."
  (is (equal '(a b c)
             (fol.compiler.destructure:strip-specializers '(a b c)))))

(test strip-specializers-type
  "strip-specializers strips type annotations."
  (is (equal '(x y)
             (fol.compiler.destructure:strip-specializers '((x <number>) (y <string>))))))

(test strip-specializers-pred
  "strip-specializers strips predicate annotations."
  (is (equal '(x y)
             (fol.compiler.destructure:strip-specializers '((x (= 0)) (y (< 10)))))))

(test strip-specializers-mixed
  "strip-specializers handles a mix of simple, type, and predicate params."
  (is (equal '(a x y)
             (fol.compiler.destructure:strip-specializers '(a (x <number>) (y (= 0)))))))

;;; ---------------------------------------------------------------------------
;;; compute-pattern-signature
;;; ---------------------------------------------------------------------------

(test signature-simple-params
  "Simple params produce all (:any) signatures."
  (is (equal '((:any) (:any))
             (fol.compiler.destructure:compute-pattern-signature '(a b)))))

(test signature-type-specializer
  "Type specializer produces (:type <type>) signature."
  (let ((sig (fol.compiler.destructure:compute-pattern-signature '((x <number>)))))
    (is (equal '((:type <number>)) sig))))

(test signature-pred-specializer
  "Predicate specializer produces (:pred fn args) signature."
  (let ((sig (fol.compiler.destructure:compute-pattern-signature '((x (= 0))))))
    (is (eq :pred (first (first sig))))
    (is (eq '= (second (first sig))))
    (is (equal '(0) (third (first sig))))))

(test signature-vector-destructuring
  "Vector param produces (:seq ...) signature."
  (let ((sig (fol.compiler.destructure:compute-pattern-signature
              (list (fol-form #(a b))))))
    (is (eq :seq (first (first sig))))
    (is (= 2 (length (second (first sig)))))))

;;; ---------------------------------------------------------------------------
;;; pattern-specificity-level
;;; ---------------------------------------------------------------------------

(test specificity-levels
  "Specificity levels follow: pred (3) > type (2) > seq (1) > any (0)."
  (is (= 0 (fol.compiler.destructure:pattern-specificity-level '(:any))))
  (is (= 1 (fol.compiler.destructure:pattern-specificity-level '(:seq ()))))
  (is (= 2 (fol.compiler.destructure:pattern-specificity-level '(:type <number>))))
  (is (= 3 (fol.compiler.destructure:pattern-specificity-level '(:pred = (0))))))

;;; ---------------------------------------------------------------------------
;;; pattern-more-specific-p
;;; ---------------------------------------------------------------------------

(test more-specific-pred-over-type
  "Predicate is more specific than type."
  (is (fol.compiler.destructure:pattern-more-specific-p
       '((:pred = (0)))
       '((:type <number>)))))

(test more-specific-type-over-any
  "Type is more specific than any."
  (is (fol.compiler.destructure:pattern-more-specific-p
       '((:type <number>))
       '((:any)))))

(test more-specific-seq-over-any
  "Sequence is more specific than any."
  (is (fol.compiler.destructure:pattern-more-specific-p
       '((:seq ((:any) (:any))))
       '((:any)))))

(test not-more-specific-when-equal
  "Equal specificity returns NIL."
  (is (not (fol.compiler.destructure:pattern-more-specific-p
            '((:any))
            '((:any))))))

(test more-specific-longer-seq
  "Longer sequence is more specific than shorter."
  (is (fol.compiler.destructure:pattern-more-specific-p
       '((:seq ((:any) (:any) (:any))))
       '((:seq ((:any) (:any)))))))

;;; ---------------------------------------------------------------------------
;;; compile-fn: single clause
;;; ---------------------------------------------------------------------------

(test compile-fn-single-simple
  "Single-clause fn with simple params produces a direct lambda."
  (let* ((result (fol.compiler:compile-form (fol-form '(fn #(a b) (+ a b)))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'lambda (first code)))
    (is (equal '(a b) (second code)))))

(test compile-fn-single-with-rest
  "Single-clause fn with rest param produces &rest in lambda list."
  (let* ((result (fol.compiler:compile-form (fol-form '(fn #(a & more) a))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'lambda (first code)))
    (is (member '&rest (second code)))))

;;; ---------------------------------------------------------------------------
;;; compile-fn: multi-clause
;;; ---------------------------------------------------------------------------

(test compile-fn-multi-clause-produces-dispatcher
  "Multi-clause fn produces a lambda with &rest and cond."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(fn (#(a) a) (#(a b) (+ a b))))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'lambda (first code)))
    ;; Should have &rest in lambda list
    (is (eq '&rest (first (second code))))))

(test compile-fn-multi-clause-arity-ordering
  "Multi-clause fn orders clauses by arity (lower first)."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(fn (#(a b c) (+ a b c)) (#(a) a)))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    ;; Find the cond form
    (let* ((body (cddr code))
           (cond-form (find 'cond body :key #'car)))
      (is (not (null cond-form)))
      ;; First cond clause should check arity 1, second arity 3
      (let ((clause-1 (second cond-form))
            (clause-2 (third cond-form)))
        ;; First clause should have arity check for 1
        (is (find 1 (flatten-form (first clause-1))))
        ;; Second clause should have arity check for 3
        (is (find 3 (flatten-form (first clause-2))))))))

(test compile-fn-multi-clause-specificity-ordering
  "Same-arity clauses are ordered by specificity (pred > type > any)."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(fn (#(x) x)
                                (#((x <number>)) x)
                                (#((x (= 0))) x)))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    ;; Find the cond form
    (let* ((body (cddr code))
           (cond-form (find 'cond body :key #'car)))
      (is (not (null cond-form)))
      ;; All three are arity 1, so ordering is by specificity:
      ;; 1st: pred (= 0), 2nd: type <number>, 3rd: any
      (let ((clause-1-check (first (second cond-form)))
            (clause-2-check (first (third cond-form)))
            (clause-3-check (first (fourth cond-form))))
        ;; First clause should have the = predicate check
        (is (find '= (flatten-form clause-1-check)))
        ;; Second clause should have a typep check
        (is (find 'typep (flatten-form clause-2-check)))
        ;; Third clause should be just arity check (no typep, no literal 0)
        (is (not (find 'typep (flatten-form clause-3-check))))
        (is (not (find 0 (flatten-form clause-3-check))))))))

(test compile-fn-named
  "Named fn wraps in labels for self-recursion."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(fn factorial #(n) (if (= n 0) 1 (* n (factorial (- n 1))))))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'labels (first code)))))

(test compile-fn-multi-clause-named
  "Named multi-clause fn wraps dispatcher in labels."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(fn my-fn (#(a) a) (#(a b) (+ a b))))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'labels (first code)))))

;;; ---------------------------------------------------------------------------
;;; Type check emission
;;; ---------------------------------------------------------------------------

(test emit-type-check-number
  "Type specializer <number> emits (typep arg 'number)."
  (let ((check (fol.compiler.destructure:emit-element-pattern-check
                '(:type <number>) 'arg)))
    (is (equal '(typep arg 'number) check))))

(test emit-type-check-string
  "Type specializer <string> emits (typep arg 'string)."
  (let ((check (fol.compiler.destructure:emit-element-pattern-check
                '(:type <string>) 'arg)))
    (is (equal '(typep arg 'string) check))))

(test emit-pred-check
  "Predicate specializer (= 0) emits (= arg 0)."
  (let ((check (fol.compiler.destructure:emit-element-pattern-check
                '(:pred = (0)) 'arg)))
    (is (equal '(= arg 0) check))))

(test emit-any-check
  "Any signature emits T."
  (is (eq t (fol.compiler.destructure:emit-element-pattern-check
             '(:any) 'arg))))

;;; ---------------------------------------------------------------------------
;;; Fixed-arity emission helpers
;;; ---------------------------------------------------------------------------

(test emit-fixed-arity-pattern-check-all-any
  "All :any signatures produce T (no check needed)."
  (is (eq t (fol.compiler.destructure:emit-fixed-arity-pattern-check
             '((:any) (:any)) '(a0 a1)))))

(test emit-fixed-arity-pattern-check-with-type
  "Type signature emits typep using the param symbol directly."
  (let ((check (fol.compiler.destructure:emit-fixed-arity-pattern-check
                '((:type <number>)) '(a0))))
    (is (equal '(typep a0 'number) check))))

(test emit-fixed-arity-param-bindings-simple
  "Binds stripped params from corresponding param symbols."
  (let ((bindings (fol.compiler.destructure:emit-fixed-arity-param-bindings
                   '(x y) '(a0 a1))))
    (is (= 2 (length bindings)))
    (is (eq 'x (first (first bindings))))
    (is (eq 'a0 (second (first bindings))))
    (is (eq 'y (first (second bindings))))
    (is (eq 'a1 (second (second bindings))))))

;;; ---------------------------------------------------------------------------
;;; Fixed-arity optimization in fn compilation
;;; ---------------------------------------------------------------------------

(test compile-fn-uniform-arity-fixed-params
  "Uniform-arity multi-clause fn uses fixed params, not &rest."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(fn (#(x) x)
                                (#((x <number>)) (* x 2))))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'lambda (first code)))
    ;; Fixed params: exactly 1 param, no &rest
    (is (= 1 (length (second code))))
    (is (not (member '&rest (second code))))
    ;; Should still have cond dispatch
    (let ((body (cddr code)))
      (is (find 'cond body :key #'car)))))

(test compile-fn-mixed-arity-uses-rest
  "Mixed-arity multi-clause fn still uses &rest."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(fn (#(a) a) (#(a b) (+ a b))))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'lambda (first code)))
    ;; Mixed arities require &rest
    (is (eq '&rest (first (second code))))))

;;; ---------------------------------------------------------------------------
;;; Wildcard _ parameter support
;;; ---------------------------------------------------------------------------

(test wildcard-param-p-recognizes-underscore
  "wildcard-param-p returns T for the symbol _."
  (is (eq t (fol.compiler.destructure:wildcard-param-p '_))))

(test wildcard-param-p-rejects-others
  "wildcard-param-p returns NIL for non-underscore symbols."
  (is (null (fol.compiler.destructure:wildcard-param-p 'x)))
  (is (null (fol.compiler.destructure:wildcard-param-p '_foo))))

(test replace-wildcards-basic
  "replace-wildcards replaces _ with gensyms."
  (multiple-value-bind (cleaned gensyms)
      (fol.compiler.destructure:replace-wildcards '(a _ c))
    (is (eq 'a (first cleaned)))
    (is (not (eq '_ (second cleaned))))
    (is (eq 'c (third cleaned)))
    (is (= 1 (length gensyms)))
    ;; The gensym in the list should match the one returned
    (is (eq (second cleaned) (first gensyms)))))

(test replace-wildcards-multiple
  "replace-wildcards produces unique gensyms for multiple _."
  (multiple-value-bind (cleaned gensyms)
      (fol.compiler.destructure:replace-wildcards '(_ _ x))
    (is (= 2 (length gensyms)))
    (is (not (eq (first cleaned) (second cleaned))))
    (is (eq 'x (third cleaned)))))

(test replace-wildcards-no-wildcards
  "replace-wildcards returns original params when no _ present."
  (multiple-value-bind (cleaned gensyms)
      (fol.compiler.destructure:replace-wildcards '(a b c))
    (is (equal '(a b c) cleaned))
    (is (null gensyms))))

(test emit-single-param-binding-skips-wildcard
  "emit-single-param-binding returns NIL for _ parameter."
  (is (null (fol.compiler.destructure:emit-single-param-binding '_ 'some-expr))))

(test emit-single-param-binding-vector-with-wildcard
  "emit-single-param-binding handles _ inside vector destructuring."
  (let* ((vec (fol-form #(a _ c)))
         (bindings (fol.compiler.destructure:emit-single-param-binding vec 'my-val)))
    ;; Should have bindings for temp, a, and c but NOT for _
    (is (>= (length bindings) 2))
    ;; No binding should have _ as its variable name
    (is (notany (lambda (b) (and (symbolp (first b))
                                 (string= (symbol-name (first b)) "_")))
                bindings))))

;;; ---------------------------------------------------------------------------
;;; Macro lambda list emission
;;; ---------------------------------------------------------------------------

(test emit-macro-lambda-list-simple
  "Simple macro params convert correctly."
  (let ((ll (fol.compiler.destructure:emit-macro-lambda-list '(test expr))))
    (is (equal '(test expr) ll))))

(test emit-macro-lambda-list-with-rest
  "Macro params with & convert to &body."
  (let ((ll (fol.compiler.destructure:emit-macro-lambda-list '(test & body))))
    (is (eq 'test (first ll)))
    (is (eq '&body (second ll)))
    (is (eq 'body (third ll)))))

(test emit-macro-lambda-list-with-destructuring
  "Nested vector destructuring in macro params."
  (let* ((nested-vec (fol-form #(a b)))
         (ll (fol.compiler.destructure:emit-macro-lambda-list (list nested-vec 'c))))
    ;; First param should be a list (a b), second should be c
    (is (equal '(a b) (first ll)))
    (is (eq 'c (second ll)))))

(test emit-macro-lambda-list-with-wildcard
  "_ in macro params becomes a gensym."
  (let ((ll (fol.compiler.destructure:emit-macro-lambda-list '(_ x))))
    (is (not (eq '_ (first ll))))
    (is (eq 'x (second ll)))))

(test emit-macro-lambda-list-rejects-specializer
  "Specializers in macro params signal an error."
  (signals error
    (fol.compiler.destructure:emit-macro-lambda-list '((x <number>) y))))

;;; ---------------------------------------------------------------------------
;;; Utility
;;; ---------------------------------------------------------------------------

(defun flatten-form (form)
  "Flatten a nested form into a flat list of atoms for search."
  (cond
    ((null form) nil)
    ((atom form) (list form))
    (t (append (flatten-form (car form))
               (flatten-form (cdr form))))))
