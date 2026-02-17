;;; FOL Compiler Tests - Compiler Entry Point Tests

(in-package :fol.compiler.tests)

(in-suite codegen-tests)

(test compile-form-returns-result
  "compile-form returns a compilation-result."
  (let ((result (fol.compiler:compile-form 42)))
    (is (fol.compiler:compilation-result-p result))))

(test compile-nil
  "nil compiles to nil."
  (let ((result (fol.compiler:compile-form nil)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eql nil (fol.compiler:compilation-result-code result)))))

(test compile-boolean
  "Booleans compile to themselves."
  (let ((result (fol.compiler:compile-form t)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eql t (fol.compiler:compilation-result-code result)))))

(test compile-number
  "Numbers compile to themselves."
  (let ((result (fol.compiler:compile-form 42)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eql 42 (fol.compiler:compilation-result-code result)))))

(test compile-string
  "Strings compile to themselves."
  (let ((result (fol.compiler:compile-form "hello")))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (equal "hello" (fol.compiler:compilation-result-code result)))))

(test compile-keyword
  "Keywords compile to themselves."
  (let ((result (fol.compiler:compile-form :foo)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eql :foo (fol.compiler:compilation-result-code result)))))

(test compile-character
  "Characters compile to themselves."
  (let ((result (fol.compiler:compile-form #\a)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eql #\a (fol.compiler:compilation-result-code result)))))

(test compile-symbol-ref
  "Symbols compile to themselves (CL will resolve the binding)."
  (let ((result (fol.compiler:compile-form 'x)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eql 'x (fol.compiler:compilation-result-code result)))))

(test compile-function-call
  "Function calls compile to CL function application."
  (let ((result (fol.compiler:compile-form '(+ 1 2))))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (equal '(+ 1 2) (fol.compiler:compilation-result-code result)))))

;;; ---------------------------------------------------------------------------
;;; Thread-first (->)
;;; ---------------------------------------------------------------------------

(test compile-thread-first-identity
  "(-> x) with no threading forms returns x."
  (let* ((result (fol.compiler:compile-form '(-> 5)))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eql 5 code))))

(test compile-thread-first-bare-symbol
  "(-> x f) compiles to (f x) with dynamic dispatch."
  (let* ((result (fol.compiler:compile-form '(-> 5 inc)))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    ;; Expect dynamic dispatch (IF checks fboundp)
    (is (eq 'if (first code)))
    ;; The direct call path should be the 'then' branch (3rd element): (inc 5)
    (is (equal '(inc 5) (third code)))))

(test compile-thread-first-call-form
  "(-> x (f a)) compiles to (f x a)."
  (let* ((result (fol.compiler:compile-form '(-> 5 (+ 3))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (equal '(+ 5 3) code))))

(test compile-thread-first-chained
  "(-> x (f a) (g b)) compiles to (g (f x a) b)."
  (let* ((result (fol.compiler:compile-form '(-> 5 (+ 3) (* 2))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (equal '(* (+ 5 3) 2) code))))

(test compile-thread-first-nested
  "Thread-first works with nested threading."
  (let* ((result (fol.compiler:compile-form '(-> 1 (+ 2) (+ 3) (+ 4))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (equal '(+ (+ (+ 1 2) 3) 4) code))))

(test compile-thread-first-with-variable
  "Thread-first works when initial value is a variable."
  (let* ((result (fol.compiler:compile-form '(-> x (+ 1))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (equal '(+ x 1) code))))

;;; ---------------------------------------------------------------------------
;;; def
;;; ---------------------------------------------------------------------------

(test compile-def-simple
  "(def x 42) compiles to (defvar x 42)."
  (let* ((result (fol.compiler:compile-form '(def x 42)))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'defvar (first code)))
    (is (eq 'x (second code)))
    (is (eql 42 (third code)))))

(test compile-def-expression
  "(def x (+ 1 2)) compiles to (defvar x (+ 1 2))."
  (let* ((result (fol.compiler:compile-form '(def x (+ 1 2))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'defvar (first code)))
    (is (equal '(+ 1 2) (third code)))))

(test compile-def-no-value
  "(def x) compiles to (defvar x)."
  (let* ((result (fol.compiler:compile-form '(def x)))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'defvar (first code)))
    (is (eq 'x (second code)))
    (is (null (cddr code)))))

;;; ---------------------------------------------------------------------------
;;; defn
;;; ---------------------------------------------------------------------------

(test compile-defn-single-clause
  "(defn add [a b] (+ a b)) compiles to (defun add (a b) (+ a b))."
  (let* ((result (fol.compiler:compile-form (fol-form '(defn add #(a b) (+ a b)))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    ;; Outer form is defun
    (is (eq 'defun (first code)))
    (is (eq 'add (second code)))
    ;; Params
    (is (equal '(a b) (third code)))
    ;; Body
    (is (equal '(+ a b) (fourth code)))))

(test compile-defn-multi-clause
  "Multi-clause defn compiles to defun with cond dispatch."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(defn process
                              (#((x <number>)) (* x 2))
                              (#(x) x)))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    ;; Outer form is defun
    (is (eq 'defun (first code)))
    (is (eq 'process (second code)))
    ;; Uniform arity (1) - should use fixed params (not &rest)
    (let ((params (third code)))
      (is (= 1 (length params)))
      (is (not (member '&rest params))))
    ;; Body should have cond for dispatch
    (is (find 'cond (flatten-form code)))))

(test compile-defn-with-type-specializer
  "defn with type specializer emits proper typep checks."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(defn stringify
                              (#((x <number>)) (format nil "~D" x))
                              (#((x <string>)) x)
                              (#(x) (format nil "~A" x))))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    ;; Outer form is defun
    (is (eq 'defun (first code)))
    (is (eq 'stringify (second code)))
    ;; Should have typep checks for dispatch
    (is (find 'typep (flatten-form code)))))

;;; ---------------------------------------------------------------------------
;;; loop/recur
;;; ---------------------------------------------------------------------------

(test compile-loop-simple
  "loop compiles with let bindings and tagbody structure."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(loop #(x 0 acc 0)
                              (if (> x 5) acc (recur (+ x 1) (+ acc x)))))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    ;; Should be a block form
    (is (eq 'block (first code)))))

(test compile-loop-has-tagbody
  "loop emits a tagbody for the loop mechanism."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(loop #(x 0) (if (> x 10) x (recur (+ x 1)))))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (find 'tagbody (flatten-form code)))))

(test compile-loop-has-block
  "loop emits a block with return-from for exit."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(loop #(x 0) (if (> x 10) x (recur (+ x 1)))))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (find 'block (flatten-form code)))
    (is (find 'return-from (flatten-form code)))))

(test compile-recur-emits-psetq-go
  "recur emits psetq for parallel update and go for jump."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(loop #(x 0 y 1) (if (> x 5) y (recur (+ x 1) (* y 2)))))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (find 'psetq (flatten-form code)))
    (is (find 'go (flatten-form code)))))

(test compile-loop-functional
  "Compiled loop evaluates correctly: sum 0..4 = 10."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(loop #(x 0 acc 0)
                              (if (> x 4) acc (recur (+ x 1) (+ acc x)))))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    ;; Eval the compiled code to verify correctness
    ;; sum of 0+1+2+3+4 = 10
    (is (= 10 (eval code)))))

;;; ---------------------------------------------------------------------------
;;; Vector literal compilation (via function call)
;;; ---------------------------------------------------------------------------

(test compile-vector-empty
  "Empty vector #() compiles to a call to the vector function."
  (let* ((result (fol.compiler:compile-form (fol-form #())))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'fol.compiler.collection-functions:vector (first code)))))

(test compile-vector-literals
  "#(1 2 3) compiles to (vector 1 2 3)."
  (let* ((result (fol.compiler:compile-form (fol-form #(1 2 3))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'fol.compiler.collection-functions:vector (first code)))
    (is (equal '(1 2 3) (rest code)))))

(test compile-vector-with-expressions
  "#(1 (+ 2 3)) compiles with nested call preserved."
  (let* ((result (fol.compiler:compile-form (fol-form #(1 (+ 2 3)))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'fol.compiler.collection-functions:vector (first code)))
    (is (eql 1 (second code)))
    (is (equal '(+ 2 3) (third code)))))

(test compile-vector-functional
  "Compiled #(1 2 3) evaluates to a FOL <vector> with 3 elements."
  (let* ((result (fol.compiler:compile-form (fol-form #(1 2 3))))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq t (fol.compiler.primitive-functions:<vector>? val)))
    (is (= 3 (fol.compiler.collections:collection-size val)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq val)))))

;;; ---------------------------------------------------------------------------
;;; Dict compilation (via function call)
;;; ---------------------------------------------------------------------------

(test compile-dict-special-form
  "(dict :a 1 :b 2) compiles via dict-node to a dict constructor call."
  (let* ((result (fol.compiler:compile-form '(fol.compiler.collection-functions:dict :a 1 :b 2)))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'fol.compiler.collection-functions:dict (first code)))))

(test compile-dict-functional
  "Compiled (dict :a 1 :b 2) evaluates to a FOL <dict>."
  (let* ((result (fol.compiler:compile-form '(fol.compiler.collection-functions:dict :a 1 :b 2)))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq t (fol.compiler.primitive-functions:<dict>? val)))
    (is (= 2 (fol.compiler.collections:collection-size val)))
    (is (= 1 (fol.compiler.collection-functions:get val :a)))
    (is (= 2 (fol.compiler.collection-functions:get val :b)))))

;;; ---------------------------------------------------------------------------
;;; Set compilation (via function call)
;;; ---------------------------------------------------------------------------

(test compile-set-special-form
  "(set 1 2 3) compiles via set-node to a set constructor call."
  (let* ((result (fol.compiler:compile-form '(fol.compiler.collection-functions:set 1 2 3)))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'fol.compiler.collection-functions:set (first code)))))

(test compile-set-functional
  "Compiled (set 1 2 3) evaluates to a FOL <set>."
  (let* ((result (fol.compiler:compile-form '(fol.compiler.collection-functions:set 1 2 3)))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq t (fol.compiler.primitive-functions:<set>? val)))
    (is (= 3 (fol.compiler.collections:collection-size val)))
    (is (eq 1 (fol.compiler.collection-functions:get val 1)))
    (is (eq 2 (fol.compiler.collection-functions:get val 2)))
    (is (eq 3 (fol.compiler.collection-functions:get val 3)))))

;;; ---------------------------------------------------------------------------
;;; Thread-last (->>)
;;; ---------------------------------------------------------------------------

(test compile-thread-last-identity
  "(->> x) with no threading forms returns x."
  (let* ((result (fol.compiler:compile-form '(->> 5)))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eql 5 code))))

(test compile-thread-last-bare-symbol
  "(->> x f) compiles to (f x) with dynamic dispatch."
  (let* ((result (fol.compiler:compile-form '(->> 5 inc)))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    ;; Expect dynamic dispatch (IF checks fboundp)
    (is (eq 'if (first code)))
    ;; The direct call path should be the 'then' branch (3rd element): (inc 5)
    (is (equal '(inc 5) (third code)))))

(test compile-thread-last-call-form
  "(->> x (f a)) compiles to (f a x) — threaded as last argument."
  (let* ((result (fol.compiler:compile-form '(->> 5 (+ 3))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    ;; Expect direct call for CL function +
    (is (equal '(+ 3 5) code))))

(test compile-thread-last-chained
  "(->> x (f a) (g b)) compiles to (g b (f a x))."
  (let* ((result (fol.compiler:compile-form '(->> 5 (+ 3) (* 2))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (equal '(* 2 (+ 3 5)) code))))

(test compile-thread-last-nested
  "Thread-last chains correctly through multiple forms."
  (let* ((result (fol.compiler:compile-form '(->> 1 (+ 2) (+ 3) (+ 4))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (equal '(+ 4 (+ 3 (+ 2 1))) code))))

(test compile-thread-last-with-variable
  "Thread-last works when initial value is a variable."
  (let* ((result (fol.compiler:compile-form '(->> x (+ 1))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (equal '(+ 1 x) code))))

(test compile-thread-last-differs-from-first
  "Thread-last and thread-first produce different argument positions."
  (let* ((first-result (fol.compiler:compile-form '(-> 5 (- 3))))
         (last-result (fol.compiler:compile-form '(->> 5 (- 3))))
         (first-code (fol.compiler:compilation-result-code first-result))
         (last-code (fol.compiler:compilation-result-code last-result)))
    ;; (-> 5 (- 3)) => (- 5 3)
    (is (equal '(- 5 3) first-code))
    ;; (->> 5 (- 3)) => (- 3 5)
    (is (equal '(- 3 5) last-code))))

;;; ---------------------------------------------------------------------------
;;; Vector node (AST-level compilation)
;;; ---------------------------------------------------------------------------

(test compile-vector-node-produces-vector-node
  "A vector literal from the reader produces a vector-node AST and compiles correctly."
  (let* ((vec (fol-form #(1 2 3)))
         (result (fol.compiler:compile-form vec))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'fol.compiler.collection-functions:vector (first code)))
    (is (equal '(1 2 3) (rest code)))))

;;; ---------------------------------------------------------------------------
;;; Dict node via reader syntax
;;; ---------------------------------------------------------------------------

(test compile-dict-from-reader
  "Dict from reader syntax {:a 1} compiles via dict-node."
  (let* ((d (let ((*readtable* fol.compiler.reader:*fol-readtable*))
              (read-from-string "{:a 1 :b 2}")))
         (result (fol.compiler:compile-form d))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'fol.compiler.collection-functions:dict (first code)))))

(test compile-dict-from-reader-functional
  "Dict from reader syntax evaluates to a <dict>."
  (let* ((d (let ((*readtable* fol.compiler.reader:*fol-readtable*))
              (read-from-string "{:a 1 :b 2}")))
         (result (fol.compiler:compile-form d))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq t (fol.compiler.primitive-functions:<dict>? val)))
    (is (= 2 (fol.compiler.collections:collection-size val)))))

;;; ---------------------------------------------------------------------------
;;; Set node via reader syntax
;;; ---------------------------------------------------------------------------

(test compile-set-from-reader
  "Set from reader syntax #{1 2 3} compiles via set-node."
  (let* ((s (let ((*readtable* fol.compiler.reader:*fol-readtable*))
              (read-from-string "#{1 2 3}")))
         (result (fol.compiler:compile-form s))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'fol.compiler.collection-functions:set (first code)))))

(test compile-set-from-reader-functional
  "Set from reader syntax evaluates to a FOL <set>."
  (let* ((s (let ((*readtable* fol.compiler.reader:*fol-readtable*))
              (read-from-string "#{1 2 3}")))
         (result (fol.compiler:compile-form s))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq t (fol.compiler.primitive-functions:<set>? val)))
    (is (= 3 (fol.compiler.collections:collection-size val)))))

;;; ---------------------------------------------------------------------------
;;; defmacro
;;; ---------------------------------------------------------------------------

(test compile-defmacro-simple
  "(defmacro unless [test & body] ...) compiles to CL defmacro with &body."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(defmacro unless #(test & body)
                               (list 'if (list 'not test) (cons 'progn body))))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'defmacro (first code)))
    (is (eq 'unless (second code)))
    ;; Lambda list should have test and &body body
    (let ((ll (third code)))
      (is (eq 'test (first ll)))
      (is (eq '&body (second ll)))
      (is (eq 'body (third ll))))))

(test compile-defmacro-with-destructuring
  "defmacro with vector destructuring in params."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(defmacro my-bind #(#(name value) & body)
                               (list 'let (list (list name value)) (cons 'progn body))))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'defmacro (first code)))
    (is (eq 'my-bind (second code)))
    ;; Lambda list should have nested destructuring
    (let ((ll (third code)))
      ;; First param is a destructured list (name value)
      (is (listp (first ll)))
      (is (equal '(name value) (first ll))))))

(test compile-defmacro-rejects-predicates
  "defmacro rejects predicate specializers with a compilation error."
  (let ((result (fol.compiler:compile-form
                 (fol-form '(defmacro bad #((x (= 0))) x)))))
    (is (not (null (fol.compiler:compilation-result-errors result))))))

;;; ---------------------------------------------------------------------------
;;; Wildcard _ parameter
;;; ---------------------------------------------------------------------------

(test compile-fn-with-wildcard
  "fn with _ parameter compiles with gensym replacement."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(fn #(x _ z) (+ x z)))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'lambda (first code)))
    ;; Lambda list should have 3 params, middle one is a gensym (not _)
    (let ((ll (second code)))
      (is (= 3 (length ll)))
      (is (eq 'x (first ll)))
      (is (not (eq '_ (second ll))))  ; replaced with gensym
      (is (eq 'z (third ll))))))

(test compile-fn-with-multiple-wildcards
  "fn with multiple _ parameters produces unique gensyms."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(fn #(_ _ x) x))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (let ((ll (second code)))
      (is (= 3 (length ll)))
      ;; Both wildcards should be gensyms and different from each other
      (is (not (eq (first ll) (second ll))))
      (is (eq 'x (third ll))))))

(test compile-fn-wildcard-functional
  "fn with _ accepts but ignores the argument."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(fn #(x _ z) (+ x z)))))
         (code (fol.compiler:compilation-result-code result))
         (fn (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    ;; Call with 3 args, middle one ignored
    (is (= 8 (funcall fn 3 999 5)))))

;;; ---------------------------------------------------------------------------
;;; handler-case
;;; ---------------------------------------------------------------------------

(test compile-handler-case-basic
  "(handler-case expr (type (var) body)) compiles to CL handler-case."
  (let* ((result (fol.compiler:compile-form
                  '(handler-case (do-something)
                     (cl:error (e) (print e)))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'handler-case (first code)))
    ;; Second element is the protected expression
    (is (listp (second code)))
    ;; Third element is a clause (type (var) body...)
    (let ((clause (third code)))
      (is (eq 'cl:error (first clause)))
      (is (equal '(e) (second clause))))))

(test compile-handler-case-multiple-clauses
  "handler-case with multiple clauses compiles correctly."
  (let* ((result (fol.compiler:compile-form
                  '(handler-case (do-something)
                     (cl:warning (w) (print w))
                     (cl:error (e) (print e)))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'handler-case (first code)))
    ;; Should have 2 clauses after the expr
    (is (= 4 (length code)))
    (is (eq 'cl:warning (first (third code))))
    (is (eq 'cl:error (first (fourth code))))))

(test compile-handler-case-no-var
  "handler-case clause with empty var list (type () body)."
  (let* ((result (fol.compiler:compile-form
                  '(handler-case (do-something)
                     (cl:error () :fallback))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (let ((clause (third code)))
      (is (eq 'cl:error (first clause)))
      (is (equal '() (second clause))))))

(test compile-handler-case-functional
  "handler-case catches an error at runtime."
  (let* ((result (fol.compiler:compile-form
                  '(handler-case (cl:error "boom")
                     (cl:error (e) (format nil "caught: ~A" e)))))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (stringp val))
    (is (search "caught:" val))))

;;; ---------------------------------------------------------------------------
;;; handler-bind
;;; ---------------------------------------------------------------------------

(test compile-handler-bind-basic
  "(handler-bind ((type handler)) body) compiles to CL handler-bind."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(handler-bind ((cl:error (fn #(e) (print e))))
                               (do-something)))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'handler-bind (first code)))
    ;; Second element is binding list
    (let ((bindings (second code)))
      (is (listp bindings))
      (is (= 1 (length bindings)))
      (is (eq 'cl:error (first (first bindings)))))))

(test compile-handler-bind-multiple
  "handler-bind with multiple bindings."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(handler-bind ((cl:warning (fn #(w) (muffle-warning)))
                                            (cl:error (fn #(e) (print e))))
                               (do-something)))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'handler-bind (first code)))
    (is (= 2 (length (second code))))))

(test compile-handler-bind-functional
  "handler-bind calls handler without unwinding."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(handler-bind ((cl:warning
                                             (fn #(w)
                                               (declare (ignore w))
                                               (muffle-warning))))
                               (cl:warn "test warning")
                               :done))))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq :done val))))

;;; ---------------------------------------------------------------------------
;;; restart-case
;;; ---------------------------------------------------------------------------

(test compile-restart-case-basic
  "(restart-case expr (name (params) body)) compiles to CL restart-case."
  (let* ((result (fol.compiler:compile-form
                  '(restart-case (do-something)
                     (use-value (v) v))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'restart-case (first code)))
    (let ((clause (third code)))
      (is (eq 'use-value (first clause)))
      (is (equal '(v) (second clause))))))

(test compile-restart-case-multiple
  "restart-case with multiple restart clauses."
  (let* ((result (fol.compiler:compile-form
                  '(restart-case (do-something)
                     (retry () (do-something))
                     (use-value (v) v))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'restart-case (first code)))
    (is (= 4 (length code)))
    (is (eq 'retry (first (third code))))
    (is (eq 'use-value (first (fourth code))))))

(test compile-restart-case-functional
  "restart-case + invoke-restart works at runtime."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(restart-case
                                 (handler-bind ((cl:error
                                                 (fn #(e)
                                                   (declare (ignore e))
                                                   (invoke-restart 'use-value 42))))
                                   (cl:error "boom"))
                               (use-value (v) v)))))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (= 42 val))))

;;; ---------------------------------------------------------------------------
;;; signal / error / warn
;;; ---------------------------------------------------------------------------

(test compile-signal-basic
  "(signal datum args) compiles to (signal ...)."
  (let* ((result (fol.compiler:compile-form
                  '(signal "something happened")))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'signal (first code)))
    (is (equal "something happened" (second code)))))

(test compile-error-basic
  "(error datum args) compiles to (cl:error ...)."
  (let* ((result (fol.compiler:compile-form
                  '(error "bad: ~A" 42)))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'cl:error (first code)))
    (is (equal "bad: ~A" (second code)))
    (is (eql 42 (third code)))))

(test compile-warn-basic
  "(warn datum args) compiles to (cl:warn ...)."
  (let* ((result (fol.compiler:compile-form
                  '(warn "caution: ~A" 99)))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'cl:warn (first code)))
    (is (equal "caution: ~A" (second code)))
    (is (eql 99 (third code)))))

(test compile-signal-functional
  "signal + handler-bind: signal is recoverable, returns nil if unhandled."
  (let* ((result (fol.compiler:compile-form
                  '(do (signal "test") :done)))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq :done val))))

;;; ---------------------------------------------------------------------------
;;; invoke-restart
;;; ---------------------------------------------------------------------------

(test compile-invoke-restart-basic
  "(invoke-restart name) compiles to (invoke-restart ...)."
  (let* ((result (fol.compiler:compile-form
                  '(invoke-restart 'continue)))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'invoke-restart (first code)))))

(test compile-invoke-restart-with-args
  "(invoke-restart name args) compiles with arguments."
  (let* ((result (fol.compiler:compile-form
                  '(invoke-restart 'use-value 42)))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'invoke-restart (first code)))
    (is (= 3 (length code)))))

;;; ---------------------------------------------------------------------------
;;; defdynamic
;;; ---------------------------------------------------------------------------

(test compile-defdynamic-simple
  "(defdynamic *x* 42) compiles to (defvar *x* 42)."
  (let* ((result (fol.compiler:compile-form '(defdynamic *x* 42)))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'defvar (first code)))
    (is (eq '*x* (second code)))
    (is (eql 42 (third code)))))

(test compile-defdynamic-expression
  "(defdynamic *x* (+ 1 2)) compiles to (defvar *x* (+ 1 2))."
  (let* ((result (fol.compiler:compile-form '(defdynamic *x* (+ 1 2))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'defvar (first code)))
    (is (equal '(+ 1 2) (third code)))))

(test compile-defdynamic-no-value
  "(defdynamic *x*) compiles to (defvar *x*)."
  (let* ((result (fol.compiler:compile-form '(defdynamic *x*)))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'defvar (first code)))
    (is (eq '*x* (second code)))
    (is (null (cddr code)))))

(test compile-defdynamic-same-as-def
  "defdynamic produces identical output to def."
  (let* ((def-result (fol.compiler:compile-form '(def *x* 42)))
         (defdynamic-result (fol.compiler:compile-form '(defdynamic *x* 42)))
         (def-code (fol.compiler:compilation-result-code def-result))
         (defdynamic-code (fol.compiler:compilation-result-code defdynamic-result)))
    (is (equal def-code defdynamic-code))))

;;; ---------------------------------------------------------------------------
;;; binding
;;; ---------------------------------------------------------------------------

(test compile-binding-single-var
  "(binding [*x* 10] *x*) compiles to (let ((*x* 10)) *x*)."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(binding #(*x* 10) *x*))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'let (first code)))
    ;; Binding list
    (let ((bindings (second code)))
      (is (= 1 (length bindings)))
      (is (eq '*x* (first (first bindings))))
      (is (eql 10 (second (first bindings)))))
    ;; Body
    (is (eq '*x* (third code)))))

(test compile-binding-multiple-vars
  "(binding [*x* 1 *y* 2] (+ *x* *y*)) compiles to let with two bindings."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(binding #(*x* 1 *y* 2) (+ *x* *y*)))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'let (first code)))
    (let ((bindings (second code)))
      (is (= 2 (length bindings)))
      (is (eq '*x* (first (first bindings))))
      (is (eq '*y* (first (second bindings)))))))

(test compile-binding-uses-let-not-let*
  "binding uses let (parallel) not let* (sequential)."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(binding #(*x* 1) *x*))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'let (first code)))
    (is (not (eq 'let* (first code))))))

(test compile-binding-functional
  "binding dynamically rebinds a special variable."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(do
                    (def *test-dynvar* :original)
                    (binding #(*test-dynvar* :rebound)
                      *test-dynvar*)))))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq :rebound val))))

(test compile-binding-restores-after
  "binding restores the original value after body completes."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(do
                    (def *test-dynvar2* :original)
                    (binding #(*test-dynvar2* :rebound)
                      *test-dynvar2*)
                    *test-dynvar2*))))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq :original val))))

(test compile-binding-with-body-expr
  "binding with expression value in body."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(binding #(*x* 10 *y* 20)
                    (+ *x* *y*)))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'let (first code)))
    ;; Body should be (+ *x* *y*)
    (is (equal '(+ *x* *y*) (third code)))))

;;; ===========================================================================
;;; Collection-as-function tests
;;; ===========================================================================

(test compile-collection-as-function-dict
  "A def'd dict can be called as a function to look up a key."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(do
                    (def *test-coll-dict* (dict :a 1 :b 2 :c 3))
                    (*test-coll-dict* :b)))))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (= 2 val))))

(test compile-collection-as-function-vector
  "A def'd vector can be called as a function to look up an index."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(do
                    (def *test-coll-vec* (vector 10 20 30))
                    (*test-coll-vec* 1)))))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (= 20 val))))

(test compile-collection-as-function-lexical
  "A lexically bound collection can be called as a function."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(bind (d (dict :x 99 :y 42))
                    (d :y)))))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (= 42 val))))

(test compile-collection-as-function-lexical-vector
  "A lexically bound vector can be called as a function."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(bind (v (vector 100 200 300))
                    (v 2)))))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (= 300 val))))

(test compile-collection-as-function-set
  "A def'd set can be called as a function to test membership."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(do
                    (def *test-coll-set* (set 10 20 30))
                    (*test-coll-set* 20)))))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (= 20 val))))

(test compile-collection-as-function-set-missing
  "A def'd set called with a missing element returns nil."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(do
                    (def *test-coll-set2* (set 10 20 30))
                    (*test-coll-set2* 99)))))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (null val))))

(test compile-collection-as-function-lexical-set
  "A lexically bound set can be called as a function."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(bind (s (set :a :b :c))
                    (s :b)))))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq :b val))))

;;; ---------------------------------------------------------------------------
;;; letfn
;;; ---------------------------------------------------------------------------

(test letfn-compiles-to-labels
  "letfn compiles to CL labels."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(letfn #((double #(x) (* x 2)))
                               (double 5)))))
         (code (fol.compiler:compilation-result-code result)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eq 'labels (first code)))))

(test letfn-single-fn-evaluates
  "A single letfn function executes correctly."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(letfn #((square #(x) (* x x)))
                               (square 7)))))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eql 49 val))))

(test letfn-multiple-fns
  "Multiple letfn functions are all defined and callable."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(letfn #((add1 #(x) (+ x 1))
                                      (mul2 #(x) (* x 2)))
                               (add1 (mul2 3))))))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eql 7 val))))

(test letfn-mutual-recursion
  "letfn supports mutually recursive functions."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(letfn #((is-even? #(n)
                                        (if (= n 0)
                                            t
                                            (is-odd? (- n 1))))
                                      (is-odd? #(n)
                                        (if (= n 0)
                                            nil
                                            (is-even? (- n 1)))))
                               (list (is-even? 4) (is-odd? 3))))))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (equal '(t t) val))))

(test letfn-body-sees-outer-scope
  "letfn body and functions can reference outer bindings."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(bind (n 10)
                    (letfn #((add-n #(x) (+ x n)))
                      (add-n 5))))))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eql 15 val))))

(test letfn-no-bindings
  "letfn with empty bindings vector just evaluates the body."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(letfn #() 42))))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eql 42 val))))

(test letfn-fn-calls-sibling
  "A letfn function can call another function defined in the same letfn."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(letfn #((double #(x) (* x 2))
                                      (quadruple #(x) (double (double x))))
                               (quadruple 3)))))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eql 12 val))))

(test letfn-with-rest-params
  "letfn supports rest parameters in fn-specs."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(letfn #((my-list #(& xs) xs))
                               (my-list 1 2 3)))))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (equal '(1 2 3) val))))

(test letfn-multiple-params
  "letfn fn-spec with multiple parameters receives all args correctly."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(letfn #((weighted #(x w) (* x w)))
                               (+ (weighted 3 10) (weighted 4 100))))))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eql 430 val))))

(test letfn-multi-arity
  "letfn supports multiple arity clauses in a single fn-spec."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(letfn #((greet (#(name) (list :hello name))
                                             (#(name greeting) (list greeting name))))
                               (list (greet :alice)
                                     (greet :bob :hi))))))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (equal '((:hello :alice) (:hi :bob)) val))))

(test letfn-multi-arity-cross-call
  "letfn multi-arity fn-spec: 1-arity clause calls 0-arity clause."
  (let* ((result (fol.compiler:compile-form
                  (fol-form '(letfn #((f (#() 0)
                                        (#(x) (+ x (f)))))
                               (f 42)))))
         (code (fol.compiler:compilation-result-code result))
         (val (eval code)))
    (is (null (fol.compiler:compilation-result-errors result)))
    (is (eql 42 val))))
