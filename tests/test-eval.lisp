(in-package :fol.tests)

(def-suite eval-suite :in fol-suite)
(def-suite* :fol.eval-tests :in eval-suite)

;;; ---------------------------------------------------------------------------
;;; Self-Evaluating Forms
;;; ---------------------------------------------------------------------------

(test eval-numbers
  "Test that numbers are self-evaluating."
  (let ((env (make-env)))
    (is (cl:= 42 (fol-eval 42 env)))
    (is (cl:= -17 (fol-eval -17 env)))
    (is (cl:= 3.14 (fol-eval 3.14 env)))
    (is (cl:= 3/4 (fol-eval 3/4 env)))
    (is (cl:= #C(1 2) (fol-eval #C(1 2) env)))))

(test eval-strings
  "Test that strings are self-evaluating."
  (let ((env (make-env)))
    (is (string= "hello" (fol-eval "hello" env)))
    (is (string= "" (fol-eval "" env)))
    (is (string= "with spaces" (fol-eval "with spaces" env)))))

(test eval-characters
  "Test that characters are self-evaluating."
  (let ((env (make-env)))
    (is (char= #\a (fol-eval #\a env)))
    (is (char= #\Space (fol-eval #\Space env)))
    (is (char= #\Newline (fol-eval #\Newline env)))))

(test eval-keywords
  "Test that keywords are self-evaluating."
  (let ((env (make-env)))
    (is (eq :foo (fol-eval :foo env)))
    (is (eq :bar-baz (fol-eval :bar-baz env)))))

(test eval-booleans
  "Test that booleans are self-evaluating."
  (let ((env (make-env)))
    (is (eq t (fol-eval t env)))
    (is (eq nil (fol-eval nil env)))))

(test eval-wrapped-values
  "Test that wrapped FOL values are self-evaluating."
  (let ((env (make-env)))
    ;; Wrapped values return their raw values
    (is (eq t (fol-eval (wrap-bool t) env)))
    (is (eq nil (fol-eval (wrap-bool nil) env)))
    (is (cl:= 42 (fol-eval (wrap-number 42) env)))
    (is (char= #\a (fol-eval (wrap-char #\a) env)))
    (is (string= "hello" (fol-eval (wrap-string "hello") env)))))

;;; ---------------------------------------------------------------------------
;;; Symbol Lookup
;;; ---------------------------------------------------------------------------

(test eval-symbol-lookup
  "Test symbol lookup in environment."
  (let ((env (make-env nil 'x 10 'y 20)))
    (is (cl:= 10 (fol-eval 'x env)))
    (is (cl:= 20 (fol-eval 'y env)))))

(test eval-symbol-lookup-chained
  "Test symbol lookup in chained environments."
  (let* ((outer (make-env nil 'a 1 'b 2))
         (inner (make-env outer 'c 3)))
    ;; Can find variables in inner and outer
    (is (cl:= 3 (fol-eval 'c inner)))
    (is (cl:= 1 (fol-eval 'a inner)))
    (is (cl:= 2 (fol-eval 'b inner)))))

(test eval-symbol-shadowing
  "Test that inner bindings shadow outer bindings."
  (let* ((outer (make-env nil 'x 1))
         (inner (make-env outer 'x 100)))
    (is (cl:= 100 (fol-eval 'x inner)))
    (is (cl:= 1 (fol-eval 'x outer)))))

(test eval-unbound-variable-error
  "Test that unbound variables signal an error."
  (let ((env (make-env nil 'x 10)))
    (signals fol-unbound-variable
      (fol-eval 'undefined env))))

;;; ---------------------------------------------------------------------------
;;; QUOTE Special Form
;;; ---------------------------------------------------------------------------

(test eval-quote-symbol
  "Test quoting symbols."
  (let ((env (make-env)))
    (is (eq 'foo (fol-eval '(quote foo) env)))
    (is (eq 'bar (fol-eval '(quote bar) env)))))

(test eval-quote-list
  "Test quoting lists."
  (let ((env (make-env)))
    (is (equal '(1 2 3) (fol-eval '(quote (1 2 3)) env)))
    (is (equal '(a b c) (fol-eval '(quote (a b c)) env)))))

(test eval-quote-arity-error
  "Test that quote requires exactly one argument."
  (let ((env (make-env)))
    (signals fol-arity-error
      (fol-eval '(quote) env))
    (signals fol-arity-error
      (fol-eval '(quote a b) env))))

;;; ---------------------------------------------------------------------------
;;; IF Special Form
;;; ---------------------------------------------------------------------------

(test eval-if-true
  "Test if with truthy condition."
  (let ((env (make-env)))
    (is (cl:= 1 (fol-eval '(if t 1 2) env)))
    (is (eq 'yes (fol-eval '(if 42 (quote yes) (quote no)) env)))))

(test eval-if-false
  "Test if with falsy condition."
  (let ((env (make-env)))
    (is (cl:= 2 (fol-eval '(if nil 1 2) env)))
    (is (eq 'no (fol-eval '(if nil (quote yes) (quote no)) env)))))

(test eval-if-no-else
  "Test if without else clause."
  (let ((env (make-env)))
    (is (cl:= 1 (fol-eval '(if t 1) env)))
    (is (eq nil (fol-eval '(if nil 1) env)))))

(test eval-if-evaluates-condition
  "Test that if evaluates its condition."
  (let ((env (make-env nil 'flag t)))
    (is (cl:= 1 (fol-eval '(if flag 1 2) env)))))

;;; ---------------------------------------------------------------------------
;;; DO Special Form
;;; ---------------------------------------------------------------------------

(test eval-do-sequence
  "Test do evaluates forms in sequence."
  (let ((env (make-env)))
    (is (cl:= 3 (fol-eval '(do 1 2 3) env)))))

(test eval-do-empty
  "Test do with no forms returns nil."
  (let ((env (make-env)))
    (is (eq nil (fol-eval '(do) env)))))

(test eval-do-single
  "Test do with single form."
  (let ((env (make-env)))
    (is (cl:= 42 (fol-eval '(do 42) env)))))

;;; ---------------------------------------------------------------------------
;;; BIND Special Form
;;; ---------------------------------------------------------------------------

(test eval-bind-single-binding
  "Test bind with single binding."
  (let ((env (make-env)))
    (is (cl:= 10 (fol-eval '(bind (x 10) x) env)))))

(test eval-bind-multiple-bindings
  "Test bind with multiple bindings."
  (let ((env (make-standard-env)))
    (is (cl:= 30 (fol-eval '(bind (x 10 y 20) (+ x y)) env)))))

(test eval-bind-with-vector-bindings
  "Test bind with vector-style bindings."
  (let ((env (make-standard-env)))
    ;; Create a vector binding form
    (let ((vec-bindings (make-vector 'x 10 'y 20)))
      (is (cl:= 30 (fol-eval `(bind ,vec-bindings (+ x y)) env))))))

(test eval-bind-body-sequence
  "Test that bind body is a sequence."
  (let ((env (make-standard-env)))
    (is (cl:= 20 (fol-eval '(bind (x 10) x (+ x x)) env)))))

(test eval-bind-sequential
  "Test that bind binds sequentially (each binding visible to next)."
  (let ((env (make-standard-env)))
    ;; y should see x=10
    (is (cl:= 20 (fol-eval '(bind (x 10 y x) (+ x y)) env)))))

(test eval-bind-shadowing
  "Test that bind shadows outer bindings."
  (let ((env (make-env nil 'x 1)))
    (is (cl:= 100 (fol-eval '(bind (x 100) x) env)))
    ;; Outer x unchanged
    (is (cl:= 1 (fol-eval 'x env)))))

(test eval-bind-accumulating
  "Test bind with accumulating bindings."
  (let ((env (make-standard-env)))
    (is (cl:= 6 (fol-eval '(bind (a 1 b (+ a 1) c (+ a b)) (+ a b c)) env)))))

;;; ---------------------------------------------------------------------------
;;; FN Special Form
;;; ---------------------------------------------------------------------------

(test eval-fn-creates-function
  "Test that fn creates a function."
  (let ((env (make-env)))
    (let ((fn (fol-eval '(fn (x) x) env)))
      (is-true (<function>? fn)))))

(test eval-fn-application
  "Test applying fn-created functions."
  (let ((env (make-standard-env)))
    (is (cl:= 42 (fol-eval '((fn (x) x) 42) env)))
    (is (cl:= 30 (fol-eval '((fn (x y) (+ x y)) 10 20) env)))))

(test eval-fn-closure
  "Test that fn captures its environment."
  (let ((env (make-standard-env)))
    (let ((env2 (make-env env 'y 10)))
      (is (cl:= 15 (fol-eval '((fn (x) (+ x y)) 5) env2))))))

(test eval-fn-nested
  "Test nested fn applications."
  (let ((env (make-standard-env)))
    ;; Curried add: (fn (x) (fn (y) (+ x y)))
    (is (cl:= 30 (fol-eval '(((fn (x) (fn (y) (+ x y))) 10) 20) env)))))

(test eval-fn-with-name
  "Test named fn for recursion."
  (let ((env (make-standard-env)))
    ;; Named fn can call itself
    (is (cl:= 120 (fol-eval '((fn fact (n)
                               (if (<= n 1)
                                   1
                                   (* n (fact (- n 1)))))
                             5) env)))))

(test eval-fn-rest-params
  "Test fn with rest parameters."
  (let ((env (make-env)))
    ;; Function that takes rest args
    (let ((fn (fol-eval '(fn (x & rest) rest) env)))
      (is (equal '(2 3 4) (apply-function fn '(1 2 3 4)))))))

(test eval-fn-arity-error
  "Test that fn checks arity."
  (let ((env (make-standard-env)))
    (signals fol-arity-error
      (fol-eval '((fn (x y) (+ x y)) 1) env))))

;;; ---------------------------------------------------------------------------
;;; Function Application
;;; ---------------------------------------------------------------------------

(test eval-apply-cl-function
  "Test applying CL functions."
  (let ((env (make-env nil 'add #'cl:+)))
    (is (cl:= 6 (fol-eval '(add 1 2 3) env)))))

(test eval-apply-arithmetic
  "Test arithmetic operations."
  (let ((env (make-standard-env)))
    (is (cl:= 10 (fol-eval '(+ 1 2 3 4) env)))
    (is (cl:= 2 (fol-eval '(- 10 5 3) env)))
    (is (cl:= 24 (fol-eval '(* 2 3 4) env)))
    (is (cl:= 2 (fol-eval '(/ 8 2 2) env)))))

(test eval-apply-comparison
  "Test comparison operations."
  (let ((env (make-standard-env)))
    (is (eq t (fol-eval '(< 1 2 3) env)))
    (is (eq nil (fol-eval '(< 1 3 2) env)))
    (is (eq t (fol-eval '(= 1 1 1) env)))
    (is (eq t (fol-eval '(<= 1 1 2) env)))))

(test eval-apply-logical
  "Test logical operations."
  (let ((env (make-standard-env)))
    (is (eq t (fol-eval '(and t t t) env)))
    (is (eq nil (fol-eval '(and t nil t) env)))
    (is (eq t (fol-eval '(or nil nil t) env)))
    (is (eq nil (fol-eval '(not t) env)))))

(test eval-keyword-as-function
  "Test using keywords as functions for collection access."
  (let* ((dict (make-dict :name "Alice" :age 30))
         (env (make-env nil 'person dict)))
    (is (string= "Alice" (fol-eval '(:name person) env)))
    (is (cl:= 30 (fol-eval '(:age person) env)))))

;;; ---------------------------------------------------------------------------
;;; LOOP/RECUR Special Forms
;;; ---------------------------------------------------------------------------

(test eval-loop-simple
  "Test simple loop without recur."
  (let ((env (make-env)))
    (is (cl:= 10 (fol-eval '(loop (x 10) x) env)))))

(test eval-loop-with-recur
  "Test loop with recur for iteration."
  (let ((env (make-standard-env)))
    ;; Sum from 1 to 5: loop with accumulator
    (is (cl:= 15 (fol-eval '(loop (n 5 acc 0)
                            (if (<= n 0)
                                acc
                                (recur (- n 1) (+ acc n))))
                          env)))))

(test eval-loop-factorial
  "Test loop/recur for factorial."
  (let ((env (make-standard-env)))
    (is (cl:= 120 (fol-eval '(loop (n 5 result 1)
                             (if (<= n 1)
                                 result
                                 (recur (- n 1) (* result n))))
                           env)))))

;;; ---------------------------------------------------------------------------
;;; THROW/TRY Special Forms
;;; ---------------------------------------------------------------------------

(test eval-try-no-error
  "Test try when no error occurs."
  (let ((env (make-env)))
    (is (cl:= 42 (fol-eval '(try 42) env)))))

(test eval-try-catch
  "Test try/catch."
  (let ((env (make-env)))
    (is (string= "caught"
                 (fol-eval '(try
                             (throw "error")
                             (catch e "caught"))
                           env)))))

(test eval-try-catch-uses-error
  "Test that catch clause can use the error value."
  (let ((env (make-env)))
    (is (string= "oops"
                 (fol-eval '(try
                             (throw "oops")
                             (catch e e))
                           env)))))

(test eval-try-finally
  "Test try/finally."
  (let ((env (make-env nil 'result nil)))
    ;; finally should run even without error
    (is (cl:= 42 (fol-eval '(try 42 (finally "cleanup")) env)))))

;;; ---------------------------------------------------------------------------
;;; DEF and DEFN
;;; ---------------------------------------------------------------------------

(test eval-def-returns-value
  "Test that def returns the value."
  (let ((env (make-env)))
    (is (cl:= 42 (fol-eval '(def x 42) env)))))

(test eval-defn-creates-function
  "Test that defn creates and returns a function."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval '(defn add (x y) (+ x y)) env)))
      (is-true (<function>? result)))))

;;; ---------------------------------------------------------------------------
;;; Collections as Self-Evaluating
;;; ---------------------------------------------------------------------------

(test eval-collection-self-eval
  "Test that collections are self-evaluating."
  (let ((env (make-env))
        (vec (make-vector 1 2 3))
        (dict (make-dict :a 1)))
    (is (eq vec (fol-eval vec env)))
    (is (eq dict (fol-eval dict env)))))

;;; ---------------------------------------------------------------------------
;;; Complex Expressions
;;; ---------------------------------------------------------------------------

(test eval-nested-bind
  "Test nested bind expressions."
  (let ((env (make-standard-env)))
    (is (cl:= 60 (fol-eval '(bind (x 10)
                             (bind (y 20)
                               (bind (z 30)
                                 (+ x y z))))
                          env)))))

(test eval-fibonacci
  "Test evaluating fibonacci using recursion."
  (let ((env (make-standard-env)))
    ;; Using named fn for recursion
    (is (cl:= 55 (fol-eval '((fn fib (n)
                              (if (<= n 1)
                                  n
                                  (+ (fib (- n 1)) (fib (- n 2)))))
                            10)
                          env)))))

(test eval-higher-order
  "Test higher-order function usage."
  (let ((env (make-standard-env)))
    ;; twice: applies a function twice
    (is (cl:= 40 (fol-eval '(bind (twice (fn (f x) (f (f x)))
                                  inc (fn (n) (+ n 10)))
                             (twice inc 20))
                          env)))))

(test eval-compose
  "Test function composition."
  (let ((env (make-standard-env)))
    ;; compose: (compose f g) = (fn (x) (f (g x)))
    (is (cl:= 22 (fol-eval '(bind (compose (fn (f g) (fn (x) (f (g x))))
                                  double (fn (x) (* x 2))
                                  inc (fn (x) (+ x 1)))
                             ((compose double inc) 10))
                          env)))))

;;; ---------------------------------------------------------------------------
;;; Edge Cases
;;; ---------------------------------------------------------------------------

(test eval-empty-list-error
  "Test that empty list causes an error."
  (let ((env (make-env)))
    (signals error
      (fol-eval '() env))))

(test eval-nil-value-lookup
  "Test looking up a variable bound to nil."
  (let ((env (make-env nil 'x nil)))
    (is (eq nil (fol-eval 'x env)))))

(test eval-deeply-nested
  "Test deeply nested expressions."
  (let ((env (make-standard-env)))
    (is (cl:= 10 (fol-eval '(+ (+ (+ (+ 1 2) 3) 4) 0) env)))))
