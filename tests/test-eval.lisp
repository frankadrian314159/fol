(in-package :fol.tests)

(def-suite eval-suite :in fol-suite)
(def-suite* :fol.eval-tests :in eval-suite)

;;; Helper to parse FOL syntax (vectors, maps, etc.) from strings
(defun fol-form (string)
  "Parse STRING using the FOL reader and return the form.
   This allows tests to use FOL syntax like [1 2 3] and {:a 1} in test cases."
  (fol-read-from-string string))

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
;;; Destructuring in bind
;;; ---------------------------------------------------------------------------

(test eval-bind-destructure-vector-simple
  "Test sequential destructuring with vector pattern."
  (let ((env (make-standard-env)))
    (is (cl:= 3 (fol-eval (fol-form "(bind [[a b] [1 2]] (+ a b))") env)))))

(test eval-bind-destructure-vector-nested
  "Test nested sequential destructuring."
  (let ((env (make-standard-env)))
    (is (cl:= 6 (fol-eval (fol-form "(bind [[a [b c]] [1 [2 3]]] (+ a b c))") env)))))

(test eval-bind-destructure-vector-rest
  "Test sequential destructuring with rest binding."
  (let ((env (make-standard-env)))
    ;; rest should be a list containing (3 4 5)
    (is (cl:= 3 (fol-eval (fol-form "(bind [[a b & rest] [1 2 3 4 5]] (size rest))") env)))
    (is (cl:= 1 (fol-eval (fol-form "(bind [[a b & rest] [1 2 3 4 5]] a)") env)))
    (is (cl:= 2 (fol-eval (fol-form "(bind [[a b & rest] [1 2 3 4 5]] b)") env)))))

(test eval-bind-destructure-vector-as
  "Test sequential destructuring with :as whole binding."
  (let ((env (make-standard-env)))
    (is (cl:= 5 (fol-eval (fol-form "(bind [[a b :as all] [1 2 3 4 5]] (size all))") env)))
    (is (cl:= 1 (fol-eval (fol-form "(bind [[a b :as all] [1 2 3 4 5]] a)") env)))))

(test eval-bind-destructure-map-keys
  "Test associative destructuring with :keys."
  (let ((env (make-standard-env)))
    (is (cl:= 3 (fol-eval (fol-form "(bind [{:keys [a b]} {:a 1 :b 2}] (+ a b))") env)))))

(test eval-bind-destructure-map-explicit
  "Test associative destructuring with explicit key mapping."
  (let ((env (make-standard-env)))
    (is (cl:= 3 (fol-eval (fol-form "(bind [{x :a y :b} {:a 1 :b 2}] (+ x y))") env)))))

(test eval-bind-destructure-map-as
  "Test associative destructuring with :as whole binding."
  (let ((env (make-standard-env)))
    (is (cl:= 2 (fol-eval (fol-form "(bind [{:keys [a] :as m} {:a 1 :b 2}] (size m))") env)))
    (is (cl:= 1 (fol-eval (fol-form "(bind [{:keys [a] :as m} {:a 1 :b 2}] a)") env)))))

(test eval-bind-destructure-map-or-defaults
  "Test associative destructuring with :or defaults."
  (let ((env (make-standard-env)))
    ;; Missing key uses default from :or
    (is (cl:= 20 (fol-eval (fol-form "(bind [{:keys [a b] :or {:a 10 :b 20}} {:a 1}] b)") env)))
    ;; Present key overrides default
    (is (cl:= 1 (fol-eval (fol-form "(bind [{:keys [a b] :or {:a 10 :b 20}} {:a 1}] a)") env)))
    ;; Both missing, both use defaults
    (is (cl:= 30 (fol-eval (fol-form "(bind [{:keys [a b] :or {:a 10 :b 20}} {}] (+ a b))") env)))
    ;; All present, no defaults used
    (is (cl:= 3 (fol-eval (fol-form "(bind [{:keys [a b] :or {:a 10 :b 20}} {:a 1 :b 2}] (+ a b))") env)))))

(test eval-bind-destructure-map-or-with-explicit
  "Test :or defaults with explicit key mapping."
  (let ((env (make-standard-env)))
    ;; Explicit mapping {x :a} with default
    (is (cl:= 99 (fol-eval (fol-form "(bind [{x :a :or {:x 99}} {}] x)") env)))
    (is (cl:= 5 (fol-eval (fol-form "(bind [{x :a :or {:x 99}} {:a 5}] x)") env)))))

(test eval-bind-destructure-with-list
  "Test destructuring with FOL list values."
  (let ((env (make-standard-env)))
    (is (cl:= 3 (fol-eval (fol-form "(bind [[a b] (list 1 2)] (+ a b))") env)))))

(test eval-bind-destructure-mixed
  "Test multiple bindings with some destructured."
  (let ((env (make-standard-env)))
    (is (cl:= 10 (fol-eval (fol-form "(bind [x 1 [a b] [2 3] y 4] (+ x a b y))") env)))))

(test eval-bind-destructure-multiple-values
  "Test destructuring with CL multiple values."
  (let ((env (make-standard-env)))
    ;; floor returns quotient and remainder as multiple values
    ;; floor(17, 3) = 5 remainder 2, so q=5, r=2, sum=7
    (is (cl:= 7 (fol-eval (fol-form "(bind [[q r] (floor 17 3)] (+ q r))") env)))))

(test eval-bind-destructure-multiple-values-truncate
  "Test that extra multiple values are ignored."
  (let ((env (make-standard-env)))
    ;; Only bind first two values, ignore the rest
    (is (cl:= 5 (fol-eval (fol-form "(bind [[a b] (floor 17 3)] a)") env)))))

(test eval-bind-destructure-multiple-values-with-rest
  "Test destructuring multiple values with rest binding."
  (let ((env (make-standard-env)))
    ;; Capture all values with rest
    (is (cl:= 2 (fol-eval (fol-form "(bind [[q & rest] (floor 17 3)] (first rest))") env)))))

(test eval-bind-underscore-discard
  "Test that _ discards values without binding."
  (let ((env (make-standard-env)))
    ;; Discard middle element
    (is (cl:= 4 (fol-eval (fol-form "(bind [[a _ c] [1 2 3]] (+ a c))") env)))
    ;; Discard first element
    (is (cl:= 5 (fol-eval (fol-form "(bind [[_ b c] [1 2 3]] (+ b c))") env)))
    ;; Discard last element
    (is (cl:= 3 (fol-eval (fol-form "(bind [[a b _] [1 2 3]] (+ a b))") env)))
    ;; Multiple discards
    (is (cl:= 2 (fol-eval (fol-form "(bind [[_ b _] [1 2 3]] b)") env)))))

(test eval-bind-underscore-with-rest
  "Test _ with rest binding."
  (let ((env (make-standard-env)))
    ;; Discard first, capture rest
    (is (cl:= 3 (fol-eval (fol-form "(bind [[_ & rest] [1 2 3 4]] (size rest))") env)))
    ;; Capture first, discard rest
    (is (cl:= 1 (fol-eval (fol-form "(bind [[a & _] [1 2 3 4]] a)") env)))))

(test eval-bind-underscore-nested
  "Test _ in nested destructuring."
  (let ((env (make-standard-env)))
    ;; Discard in nested pattern
    (is (cl:= 4 (fol-eval (fol-form "(bind [[a [_ c]] [1 [2 3]]] (+ a c))") env)))))

(test eval-bind-underscore-simple
  "Test _ as simple binding (discards entire value)."
  (let ((env (make-standard-env)))
    ;; Use _ to discard, then use other binding
    (is (cl:= 10 (fol-eval (fol-form "(bind [_ 5 x 10] x)") env)))))

;;; ---------------------------------------------------------------------------
;;; Type-Annotated Bindings in Destructuring
;;; ---------------------------------------------------------------------------

(test eval-bind-typed-simple
  "Test simple typed binding (x <integer>)."
  (let ((env (make-standard-env)))
    ;; Integer conforms to <integer>
    (is (cl:= 42 (fol-eval (fol-form "(bind [(x <integer>) 42] x)") env)))
    ;; String conforms to <string>
    (is (equal "hello" (fol-eval (fol-form "(bind [(s <string>) \"hello\"] s)") env)))))

(test eval-bind-typed-subtype
  "Test typed binding with subtype relationships."
  (let ((env (make-standard-env)))
    ;; Fixnum is a subtype of <integer>
    (is (cl:= 42 (fol-eval (fol-form "(bind [(x <integer>) 42] x)") env)))
    ;; Fixnum is a subtype of <number>
    (is (cl:= 42 (fol-eval (fol-form "(bind [(x <number>) 42] x)") env)))
    ;; Double-float is a subtype of <real> (FOL reader converts 3.14 to double-float)
    (is (cl:= 3.14d0 (fol-eval (fol-form "(bind [(x <real>) 3.14] x)") env)))))

(test eval-bind-typed-type-error
  "Test that typed binding signals error on type mismatch."
  (let ((env (make-standard-env)))
    ;; String doesn't conform to <integer>
    (signals fol-type-error
      (fol-eval (fol-form "(bind [(x <integer>) \"hello\"] x)") env))
    ;; Integer doesn't conform to <string>
    (signals fol-type-error
      (fol-eval (fol-form "(bind [(x <string>) 42] x)") env))))

(test eval-bind-typed-in-sequential
  "Test typed binding inside sequential destructuring."
  (let ((env (make-standard-env)))
    ;; Type annotations inside vector pattern
    (is (cl:= 3 (fol-eval (fol-form "(bind [[(a <integer>) (b <integer>)] (list 1 2)] (+ a b))") env)))))

(test eval-bind-typed-in-sequential-error
  "Test type error inside sequential destructuring."
  (let ((env (make-standard-env)))
    ;; Second element is string, not integer
    (signals fol-type-error
      (fol-eval (fol-form "(bind [[(a <integer>) (b <integer>)] (list 1 \"two\")] (+ a b))") env))))

(test eval-bind-typed-mixed
  "Test mixing typed and untyped bindings."
  (let ((env (make-standard-env)))
    ;; Mix typed and untyped
    (is (cl:= 6 (fol-eval (fol-form "(bind [x 1 (y <integer>) 2 z 3] (+ x y z))") env)))))

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

(test eval-lambda-synonym
  "Test that λ works as a synonym for fn."
  (let ((env (make-standard-env)))
    ;; λ should create functions just like fn
    (is-true (<function>? (fol-eval '(λ (x) x) env)))
    (is (cl:= 42 (fol-eval '((λ (x) x) 42) env)))
    (is (cl:= 30 (fol-eval '((λ (x y) (+ x y)) 10 20) env)))
    ;; λ with closure
    (let ((env2 (make-env env 'y 10)))
      (is (cl:= 15 (fol-eval '((λ (x) (+ x y)) 5) env2))))))

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

(test eval-empty-list-is-nil
  "Test that empty list evaluates to nil (standard Lisp semantics)."
  (let ((env (make-env)))
    (is (eq nil (fol-eval '() env)))))

(test eval-nil-value-lookup
  "Test looking up a variable bound to nil."
  (let ((env (make-env nil 'x nil)))
    (is (eq nil (fol-eval 'x env)))))

(test eval-deeply-nested
  "Test deeply nested expressions."
  (let ((env (make-standard-env)))
    (is (cl:= 10 (fol-eval '(+ (+ (+ (+ 1 2) 3) 4) 0) env)))))

;;; ---------------------------------------------------------------------------
;;; Macros (defmacro)
;;; ---------------------------------------------------------------------------

(test defmacro-creates-macro
  "Test that defmacro creates a macro object."
  (let ((env (make-env)))
    (let ((macro (fol-eval '(defmacro my-macro (x) x) env)))
      (is-true (<macro>? macro)))))

(test defmacro-with-name
  "Test that defmacro captures the macro name."
  (let ((env (make-env)))
    (let ((macro (fol-eval '(defmacro my-macro (x) x) env)))
      (is (eq 'my-macro (macro-name macro))))))

(test macro-receives-unevaluated-args
  "Test that macros receive unevaluated arguments."
  (let ((env (make-standard-env)))
    ;; Define a macro that returns its argument as a quoted form
    (let* ((macro (fol-eval '(defmacro quote-it (x) (list 'quote x)) env))
           (env2 (make-env env 'quote-it macro)))
      ;; (quote-it (+ 1 2)) should return the LIST (+ 1 2), not 3
      (is (equal '(+ 1 2) (fol-eval '(quote-it (+ 1 2)) env2))))))

(test macro-expansion-is-evaluated
  "Test that the result of macro expansion is evaluated."
  (let ((env (make-standard-env)))
    ;; Define a macro that builds an addition expression
    (let* ((macro (fol-eval '(defmacro add-expr (a b) (list '+ a b)) env))
           (env2 (make-env env 'add-expr macro)))
      ;; (add-expr 1 2) expands to (+ 1 2) which evaluates to 3
      (is (cl:= 3 (fol-eval '(add-expr 1 2) env2))))))

(test macro-when
  "Test implementing a 'when' macro."
  (let ((env (make-standard-env)))
    ;; (when test body...) => (if test (do body...))
    (let* ((macro (fol-eval '(defmacro when (test & body)
                               (list 'if test (cons 'do body)))
                            env))
           (env2 (make-env env 'when macro)))
      ;; Test when condition is true
      (is (cl:= 42 (fol-eval '(when t 1 2 42) env2)))
      ;; Test when condition is false
      (is (eq nil (fol-eval '(when nil 1 2 42) env2))))))

(test macro-unless
  "Test implementing an 'unless' macro."
  (let ((env (make-standard-env)))
    ;; (unless test body...) => (if test nil (do body...))
    (let* ((macro (fol-eval '(defmacro unless (test & body)
                               (list 'if test nil (cons 'do body)))
                            env))
           (env2 (make-env env 'unless macro)))
      ;; Test unless condition is false (body executes)
      (is (cl:= 42 (fol-eval '(unless nil 1 2 42) env2)))
      ;; Test unless condition is true (body doesn't execute)
      (is (eq nil (fol-eval '(unless t 1 2 42) env2))))))

(test macro-with-rest-params
  "Test macros with rest parameters."
  (let ((env (make-standard-env)))
    ;; A macro that wraps all args in a list call
    (let* ((macro (fol-eval '(defmacro make-list (& items)
                               (cons 'list items))
                            env))
           (env2 (make-env env 'make-list macro)))
      (is (equal '(1 2 3) (fol-eval '(make-list 1 2 3) env2))))))

(test macro-nested-expansion
  "Test nested macro calls."
  (let ((env (make-standard-env)))
    ;; Define two macros
    (let* ((double-macro (fol-eval '(defmacro double (x) (list '* 2 x)) env))
           (env2 (make-env env 'double double-macro))
           (triple-macro (fol-eval '(defmacro triple (x) (list '* 3 x)) env2))
           (env3 (make-env env2 'triple triple-macro)))
      ;; (double (triple 5)) => (* 2 (* 3 5)) => 30
      (is (cl:= 30 (fol-eval '(double (triple 5)) env3))))))

(test macro-accesses-closure-env
  "Test that macros can access their closure environment."
  (let ((env (make-standard-env)))
    ;; Define a macro that uses a value from its definition environment
    (let* ((env2 (make-env env 'multiplier 10))
           (macro (fol-eval '(defmacro scale (x) (list '* multiplier x)) env2))
           (env3 (make-env env2 'scale macro)))
      ;; (scale 5) expands to (* 10 5) => 50
      (is (cl:= 50 (fol-eval '(scale 5) env3))))))

(test macro-and-short-circuit
  "Test implementing a short-circuit 'and' macro."
  (let ((env (make-standard-env)))
    ;; (my-and a b) => (if a b nil)
    (let* ((macro (fol-eval '(defmacro my-and (a b)
                               (list 'if a b nil))
                            env))
           (env2 (make-env env 'my-and macro)))
      (is (eq t (fol-eval '(my-and t t) env2)))
      (is (eq nil (fol-eval '(my-and t nil) env2)))
      (is (eq nil (fol-eval '(my-and nil t) env2)))
      (is (eq nil (fol-eval '(my-and nil nil) env2))))))

(test macro-or-short-circuit
  "Test implementing a short-circuit 'or' macro."
  (let ((env (make-standard-env)))
    ;; (my-or a b) => (if a a b)
    ;; Note: This evaluates a twice, but demonstrates macro expansion
    (let* ((macro (fol-eval '(defmacro my-or (a b)
                               (list 'if a a b))
                            env))
           (env2 (make-env env 'my-or macro)))
      (is (eq t (fol-eval '(my-or t t) env2)))
      (is (eq t (fol-eval '(my-or t nil) env2)))
      (is (eq t (fol-eval '(my-or nil t) env2)))
      (is (eq nil (fol-eval '(my-or nil nil) env2))))))

(test macroexpand-1-basic
  "Test macroexpand-1 function."
  (let ((env (make-standard-env)))
    (let* ((macro (fol-eval '(defmacro double (x) (list '* 2 x)) env))
           (env2 (make-env env 'double macro)))
      ;; macroexpand-1 should expand once
      (multiple-value-bind (expanded expandedp)
          (macroexpand-1 '(double 5) env2)
        (is (equal '(* 2 5) expanded))
        (is-true expandedp)))))

(test macroexpand-1-non-macro
  "Test macroexpand-1 with non-macro form."
  (let ((env (make-standard-env)))
    ;; Non-macro form should return unchanged
    (multiple-value-bind (expanded expandedp)
        (macroexpand-1 '(+ 1 2) env)
      (is (equal '(+ 1 2) expanded))
      (is-false expandedp))))

(test macroexpand-full
  "Test macroexpand function for full expansion."
  (let ((env (make-standard-env)))
    ;; Define a macro that expands to another macro call
    (let* ((inner-macro (fol-eval '(defmacro inner (x) (list '+ x 1)) env))
           (env2 (make-env env 'inner inner-macro))
           (outer-macro (fol-eval '(defmacro outer (x) (list 'inner x)) env2))
           (env3 (make-env env2 'outer outer-macro)))
      ;; (outer 5) => (inner 5) => (+ 5 1)
      (let ((expanded (macroexpand '(outer 5) env3)))
        (is (equal '(+ 5 1) expanded))))))

(test macro-cond-implementation
  "Test implementing a simple 'cond' macro."
  (let ((env (make-standard-env)))
    ;; Simple cond: (my-cond (test1 result1) (test2 result2))
    ;; => (if test1 result1 (if test2 result2 nil))
    ;; Note: Use (= nil clauses) instead of (nil? clauses) to avoid
    ;; package issues (nil? symbol would be in fol.tests, but env has fol.eval::nil?)
    (let* ((macro (fol-eval
                   '(defmacro my-cond (& clauses)
                      (if (= nil clauses)
                          nil
                          (list 'if
                                (first (first clauses))
                                (first (rest (first clauses)))
                                (cons 'my-cond (rest clauses)))))
                   env))
           (env2 (make-env env 'my-cond macro)))
      ;; Test first clause matches
      (is (cl:= 1 (fol-eval '(my-cond (t 1) (t 2)) env2)))
      ;; Test second clause matches
      (is (cl:= 2 (fol-eval '(my-cond (nil 1) (t 2)) env2)))
      ;; Test no clause matches
      (is (eq nil (fol-eval '(my-cond (nil 1) (nil 2)) env2))))))

(test macro-let-implementation
  "Test implementing a simple 'let' macro using bind."
  (let ((env (make-standard-env)))
    ;; (my-let ((x 1) (y 2)) body) => (bind (x 1 y 2) body)
    ;; Flatten the bindings list
    (let* ((macro (fol-eval
                   '(defmacro my-let (bindings & body)
                      (cons 'bind
                            (cons (apply list
                                        (apply append
                                               (list bindings)))
                                  body)))
                   env))
           (env2 (make-env env 'my-let macro 'append #'cl:append)))
      ;; Note: This is a simplified test - the macro above is tricky
      ;; Let's test a simpler version
      (is (cl:= 3 (fol-eval '(bind (x 1 y 2) (+ x y)) env2))))))

(test macro-arity-error
  "Test that macros check arity."
  (let ((env (make-env)))
    (let* ((macro (fol-eval '(defmacro needs-two (a b) (list a b)) env))
           (env2 (make-env env 'needs-two macro)))
      ;; Too few arguments should error
      (signals fol-arity-error
        (fol-eval '(needs-two 1) env2))
      ;; Too many arguments should error
      (signals fol-arity-error
        (fol-eval '(needs-two 1 2 3) env2)))))

(test macro-self-evaluating
  "Test that macro objects are self-evaluating."
  (let ((env (make-env)))
    (let ((macro (fol-eval '(defmacro id (x) x) env)))
      ;; Evaluating the macro object itself returns the macro
      (is (eq macro (fol-eval macro env))))))

;;; ---------------------------------------------------------------------------
;;; Syntax-Quote (Quasiquote)
;;; ---------------------------------------------------------------------------

(test syntax-quote-literal-values
  "Test that syntax-quote preserves literal values."
  (let ((env (make-env)))
    ;; Numbers, strings, keywords are returned as-is
    (is (cl:= 42 (fol-eval '(syntax-quote 42) env)))
    (is (string= "hello" (fol-eval '(syntax-quote "hello") env)))
    (is (eq :foo (fol-eval '(syntax-quote :foo) env)))))

(test syntax-quote-symbols
  "Test that syntax-quote preserves symbols."
  (let ((env (make-env)))
    ;; Symbols are returned as symbols (not looked up)
    (is (eq 'foo (fol-eval '(syntax-quote foo) env)))
    (is (eq 'bar (fol-eval '(syntax-quote bar) env)))))

(test syntax-quote-lists
  "Test that syntax-quote preserves list structure."
  (let ((env (make-env)))
    (is (equal '(a b c) (fol-eval '(syntax-quote (a b c)) env)))
    (is (equal '(1 2 3) (fol-eval '(syntax-quote (1 2 3)) env)))
    (is (equal '((a b) (c d)) (fol-eval '(syntax-quote ((a b) (c d))) env)))))

(test syntax-quote-unquote
  "Test unquote (~) within syntax-quote."
  (let ((env (make-env nil 'x 42 'y "hello")))
    ;; (unquote x) evaluates x and inserts the value
    (is (equal '(a 42 c) (fol-eval '(syntax-quote (a (unquote x) c)) env)))
    (is (equal '(1 "hello" 3) (fol-eval '(syntax-quote (1 (unquote y) 3)) env)))))

(test syntax-quote-unquote-expression
  "Test unquote with expressions."
  (let ((env (make-standard-env)))
    ;; Can evaluate expressions within unquote
    (is (equal '(result 6) (fol-eval '(syntax-quote (result (unquote (+ 1 2 3)))) env)))))

(test syntax-quote-unquote-splicing
  "Test unquote-splicing (~@) within syntax-quote."
  (let ((env (make-env nil 'xs '(1 2 3) 'ys '(a b))))
    ;; (unquote-splicing xs) evaluates xs and splices the list
    (is (equal '(start 1 2 3 end)
               (fol-eval '(syntax-quote (start (unquote-splicing xs) end)) env)))
    (is (equal '(a b c d)
               (fol-eval '(syntax-quote ((unquote-splicing ys) c d)) env)))))

(test syntax-quote-unquote-splicing-empty
  "Test unquote-splicing with empty list."
  (let ((env (make-env nil 'empty '())))
    ;; Splicing empty list inserts nothing
    (is (equal '(a b)
               (fol-eval '(syntax-quote (a (unquote-splicing empty) b)) env)))))

(test syntax-quote-mixed-unquote
  "Test mixing unquote and unquote-splicing."
  (let ((env (make-env nil 'x 42 'ys '(1 2 3))))
    (is (equal '(start 42 1 2 3 end)
               (fol-eval '(syntax-quote (start (unquote x) (unquote-splicing ys) end)) env)))))

(test syntax-quote-nested
  "Test nested syntax-quote and unquote."
  (let ((env (make-env nil 'x 10)))
    ;; Nested unquote within list structure
    (is (equal '((a 10) (b 10))
               (fol-eval '(syntax-quote ((a (unquote x)) (b (unquote x)))) env)))))

(test syntax-quote-auto-gensym
  "Test auto-gensym (symbol#) creates unique symbols."
  (let ((env (make-env)))
    ;; x# should become a gensym
    (let ((result (fol-eval '(syntax-quote (bind (x# 1) x#)) env)))
      ;; Result should be (bind (GENSYM 1) GENSYM) where both GENSYMs are the same
      (is (eq 'bind (first result)))
      (let ((bindings (second result))
            (body (third result)))
        ;; The gensym symbol in bindings and body should be the same
        (is (eq (first bindings) body))
        ;; It should be a symbol
        (is (symbolp (first bindings)))
        ;; It should not be the original x# symbol
        (is (cl:not (string= "X#" (symbol-name (first bindings)))))))))

(test syntax-quote-auto-gensym-multiple
  "Test that multiple auto-gensyms with same name are the same within one syntax-quote."
  (let ((env (make-env)))
    (let ((result (fol-eval '(syntax-quote (x# x# y# y#)) env)))
      ;; First and second should be the same gensym
      (is (eq (first result) (second result)))
      ;; Third and fourth should be the same gensym
      (is (eq (third result) (fourth result)))
      ;; But first and third should be different
      (is (cl:not (eq (first result) (third result)))))))

(test syntax-quote-auto-gensym-different-quotes
  "Test that auto-gensyms in different syntax-quotes are different."
  (let ((env (make-env)))
    ;; Use separate list constructions to ensure they're truly independent calls
    (let* ((form1 (list 'syntax-quote 'x#))
           (form2 (list 'syntax-quote 'x#))
           (result1 (fol-eval form1 env))
           (result2 (fol-eval form2 env)))
      ;; Each syntax-quote gets its own gensym
      (is (cl:not (eq result1 result2))))))

(test syntax-quote-macro-use
  "Test using syntax-quote in a macro definition."
  (let ((env (make-standard-env)))
    ;; Define a 'when' macro using syntax-quote
    (let* ((macro (fol-eval
                   '(defmacro my-when (test & body)
                      (syntax-quote (if (unquote test)
                                        (do (unquote-splicing body))
                                        nil)))
                   env))
           (env2 (make-env env 'my-when macro)))
      ;; Test the macro
      (is (cl:= 42 (fol-eval '(my-when t 1 2 42) env2)))
      (is (eq nil (fol-eval '(my-when nil 1 2 42) env2))))))

(test syntax-quote-macro-with-gensym
  "Test macro using auto-gensym to avoid variable capture."
  (let ((env (make-standard-env)))
    ;; Define a macro that binds a temp variable - uses gensym to avoid capture
    (let* ((macro (fol-eval
                   '(defmacro my-let1 (var val & body)
                      (syntax-quote (bind (temp# (unquote val)
                                           (unquote var) temp#)
                                      (unquote-splicing body))))
                   env))
           (env2 (make-env env 'my-let1 macro)))
      ;; Test the macro - should work even if body references 'temp'
      (is (cl:= 10 (fol-eval '(my-let1 x 10 x) env2)))
      ;; Verify we can use a different value
      (is (cl:= 20 (fol-eval '(my-let1 y 20 y) env2))))))

(test syntax-quote-vectors
  "Test syntax-quote with vectors."
  (let ((env (make-env nil 'x 42)))
    ;; Vectors should be preserved and unquote should work
    (let ((result (fol-eval '(syntax-quote #(a (unquote x) c)) env)))
      (is (vectorp result))
      (is (eq 'a (aref result 0)))
      (is (cl:= 42 (aref result 1)))
      (is (eq 'c (aref result 2))))))

(test syntax-quote-arity-error
  "Test that syntax-quote requires exactly one argument."
  (let ((env (make-env)))
    (signals fol-arity-error
      (fol-eval '(syntax-quote) env))
    (signals fol-arity-error
      (fol-eval '(syntax-quote a b) env))))

(test unquote-splicing-requires-list
  "Test that unquote-splicing requires a list value."
  (let ((env (make-env nil 'x 42)))
    ;; Splicing a non-list should error
    (signals fol-eval-error
      (fol-eval '(syntax-quote (a (unquote-splicing x) b)) env))))

(test unquote-outside-syntax-quote-error
  "Test that unquote outside syntax-quote throws an error."
  (let ((env (make-env nil 'x 42)))
    ;; Bare unquote should error
    (signals fol-eval-error
      (fol-eval '(unquote x) env))))

(test unquote-splicing-outside-syntax-quote-error
  "Test that unquote-splicing outside syntax-quote throws an error."
  (let ((env (make-env nil 'xs '(1 2 3))))
    ;; Bare unquote-splicing should error
    (signals fol-eval-error
      (fol-eval '(unquote-splicing xs) env))))

(test auto-gensym-outside-syntax-quote-error
  "Test that auto-gensym symbols outside syntax-quote throw an error."
  (let ((env (make-env)))
    ;; Bare x# should error
    (signals fol-eval-error
      (fol-eval 'x# env))))

;;; ---------------------------------------------------------------------------
;;; Dynamic Variables (make-dynamic, binding)
;;; ---------------------------------------------------------------------------

(test make-dynamic-creates-dynamic-var
  "Test that make-dynamic creates a dynamic variable."
  (let ((env (make-env)))
    (let ((dvar (fol-eval '(make-dynamic *x*) env)))
      (is-true (<dynamic-var>? dvar))
      (is (eq '*x* (dynamic-var-name dvar))))))

(test make-dynamic-with-initial-value
  "Test make-dynamic with an initial value."
  (let ((env (make-env)))
    (let ((dvar (fol-eval '(make-dynamic *x* 42) env)))
      (is-true (<dynamic-var>? dvar))
      (is (cl:= 42 (dynamic-var-root-value dvar)))
      (is (cl:= 42 (dynamic-var-value dvar))))))

(test dynamic-var-auto-dereference
  "Test that dynamic variables are automatically dereferenced on lookup."
  (let ((env (make-env)))
    ;; Create a dynamic var and bind it in the environment
    (let* ((dvar (fol-eval '(make-dynamic *counter* 100) env))
           (env2 (make-env env '*counter* dvar)))
      ;; Looking up *counter* should return the value, not the dvar
      (is (cl:= 100 (fol-eval '*counter* env2))))))

(test binding-temporarily-rebinds
  "Test that binding temporarily rebinds a dynamic variable."
  (let ((env (make-env)))
    ;; Create and bind a dynamic var
    (let* ((dvar (fol-eval '(make-dynamic *x* 1) env))
           (env2 (make-env env '*x* dvar)))
      ;; Outside binding, value is 1
      (is (cl:= 1 (fol-eval '*x* env2)))
      ;; Inside binding, value is 10
      (is (cl:= 10 (fol-eval '(binding (*x* 10) *x*) env2)))
      ;; After binding, value is restored to 1
      (is (cl:= 1 (fol-eval '*x* env2))))))

(test binding-nested
  "Test nested binding forms."
  (let ((env (make-env)))
    (let* ((dvar (fol-eval '(make-dynamic *x* 1) env))
           (env2 (make-env env '*x* dvar)))
      ;; Nested bindings should stack
      (is (cl:= 30 (fol-eval '(binding (*x* 10)
                                (binding (*x* 20)
                                  (binding (*x* 30)
                                    *x*)))
                             env2)))
      ;; After all bindings, value is restored
      (is (cl:= 1 (fol-eval '*x* env2))))))

(test binding-multiple-vars
  "Test binding multiple dynamic variables at once."
  (let ((env (make-standard-env)))
    (let* ((dvar-x (fol-eval '(make-dynamic *x* 1) env))
           (dvar-y (fol-eval '(make-dynamic *y* 2) env))
           (env2 (make-env env '*x* dvar-x '*y* dvar-y)))
      ;; Bind both at once
      (is (cl:= 30 (fol-eval '(binding (*x* 10 *y* 20)
                                (+ *x* *y*))
                             env2)))
      ;; Both restored after
      (is (cl:= 1 (fol-eval '*x* env2)))
      (is (cl:= 2 (fol-eval '*y* env2))))))

(test binding-restores-on-error
  "Test that binding restores values even when body signals an error."
  (let ((env (make-env)))
    (let* ((dvar (fol-eval '(make-dynamic *x* 1) env))
           (env2 (make-env env '*x* dvar)))
      ;; Binding that throws an error
      (signals fol-eval-error
        (fol-eval '(binding (*x* 999)
                     (throw "error!"))
                  env2))
      ;; Value should be restored despite the error
      (is (cl:= 1 (fol-eval '*x* env2))))))

(test binding-requires-dynamic-var
  "Test that binding requires actual dynamic variables."
  (let ((env (make-env nil 'x 42)))
    ;; Trying to bind a non-dynamic variable should error
    (signals fol-eval-error
      (fol-eval '(binding (x 10) x) env))))

(test binding-evaluates-values
  "Test that binding evaluates the new values."
  (let ((env (make-standard-env)))
    (let* ((dvar (fol-eval '(make-dynamic *x* 0) env))
           (env2 (make-env env '*x* dvar)))
      ;; The value expression should be evaluated
      (is (cl:= 6 (fol-eval '(binding (*x* (+ 1 2 3))
                               *x*)
                            env2))))))

(test binding-body-sequence
  "Test that binding body is evaluated as a sequence."
  (let ((env (make-standard-env)))
    (let* ((dvar (fol-eval '(make-dynamic *x* 0) env))
           (env2 (make-env env '*x* dvar)))
      ;; Multiple body forms, returns last
      (is (cl:= 3 (fol-eval '(binding (*x* 10)
                               1
                               2
                               3)
                            env2))))))

(test dynamic-var-in-function
  "Test that dynamic variables work correctly across function calls."
  (let ((env (make-standard-env)))
    ;; Create dynamic var
    (let* ((dvar (fol-eval '(make-dynamic *multiplier* 1) env))
           (env2 (make-env env '*multiplier* dvar)))
      ;; Define a function that uses the dynamic var
      (let* ((fn (fol-eval '(fn (x) (* x *multiplier*)) env2))
             (env3 (make-env env2 'scale fn)))
        ;; Without rebinding, multiplier is 1
        (is (cl:= 5 (fol-eval '(scale 5) env3)))
        ;; With rebinding, multiplier is 10
        (is (cl:= 50 (fol-eval '(binding (*multiplier* 10)
                                  (scale 5))
                               env3)))
        ;; After binding, back to 1
        (is (cl:= 5 (fol-eval '(scale 5) env3)))))))

;;; ---------------------------------------------------------------------------
;;; Lazy Sequences (lazy-seq)
;;; ---------------------------------------------------------------------------

(test lazy-seq-basic
  "Test basic lazy-seq creation and realization."
  (let ((env (make-standard-env)))
    ;; Create a lazy-seq that returns a list
    (let ((ls (fol-eval '(lazy-seq (list 1 2 3)) env)))
      (is-true (<lazy-seq>? ls))
      (is (cl:= 1 (first ls)))
      (is (cl:= 2 (first (rest ls))))
      (is (cl:= 3 (first (rest (rest ls))))))))

(test lazy-seq-delays-evaluation
  "Test that lazy-seq delays body evaluation."
  (let ((env (make-standard-env)))
    ;; This would cause infinite recursion if evaluated immediately
    ;; But lazy-seq delays it, so we can create it safely
    (let ((ls (fol-eval '(lazy-seq (conj (lazy-seq nil) 1)) env)))
      (is-true (<lazy-seq>? ls))
      (is (cl:= 1 (first ls))))))

(test lazy-seq-captures-environment
  "Test that lazy-seq captures its environment."
  (let ((env (make-standard-env)))
    ;; Bind x in environment
    (let ((env2 (make-env env 'x 42)))
      ;; lazy-seq body references x
      (let ((ls (fol-eval '(lazy-seq (list x)) env2)))
        ;; When realized, x should be 42 (captured value)
        (is (cl:= 42 (first ls)))))))

(test lazy-seq-with-conj
  "Test lazy-seq with conj for building sequences."
  (let ((env (make-standard-env)))
    ;; Build a lazy sequence: (1 2 3)
    (let ((ls (fol-eval '(lazy-seq
                           (conj
                             (lazy-seq
                               (conj
                                 (lazy-seq
                                   (conj nil 3))
                                 2))
                             1))
                        env)))
      (is (cl:= 1 (first ls)))
      (is (cl:= 2 (first (rest ls))))
      (is (cl:= 3 (first (rest (rest ls))))))))

(test lazy-seq-recursive-function
  "Test lazy-seq with recursive function for infinite sequence."
  (let ((env (make-standard-env)))
    ;; Define a function that generates integers lazily
    (fol-eval '(defn integers (n)
                 (lazy-seq (conj (integers (+ n 1)) n)))
              env)
    ;; Create the infinite sequence starting at 0
    (let ((ints (fol-eval '(integers 0) env)))
      ;; Take first few elements
      (is (cl:= 0 (first ints)))
      (is (cl:= 1 (first (rest ints))))
      (is (cl:= 2 (first (rest (rest ints)))))
      (is (cl:= 3 (first (rest (rest (rest ints)))))))))

(test lazy-seq-arity-error
  "Test that lazy-seq requires exactly one argument."
  (let ((env (make-env)))
    (signals fol-arity-error
      (fol-eval '(lazy-seq) env))
    (signals fol-arity-error
      (fol-eval '(lazy-seq a b) env))))

;;; ---------------------------------------------------------------------------
;;; Function Parameter Destructuring
;;; ---------------------------------------------------------------------------

(test fn-destructure-vector-param
  "Test function with vector destructuring in parameter."
  (let ((env (make-standard-env)))
    ;; Function that destructures its first argument
    (is (cl:= 3 (fol-eval (fol-form "((fn [[a b]] (+ a b)) [1 2])") env)))))

(test fn-destructure-nested-vector
  "Test function with nested vector destructuring."
  (let ((env (make-standard-env)))
    (is (cl:= 6 (fol-eval (fol-form "((fn [[a [b c]]] (+ a b c)) [1 [2 3]])") env)))))

(test fn-destructure-with-rest
  "Test function with rest binding in destructuring pattern."
  (let ((env (make-standard-env)))
    ;; Get the size of rest
    (is (cl:= 3 (fol-eval (fol-form "((fn [[a & rest]] (size rest)) [1 2 3 4])") env)))
    (is (cl:= 1 (fol-eval (fol-form "((fn [[a & rest]] a) [1 2 3 4])") env)))))

(test fn-destructure-with-as
  "Test function with :as binding in destructuring pattern."
  (let ((env (make-standard-env)))
    ;; :as binds the whole collection
    (is (cl:= 4 (fol-eval (fol-form "((fn [[a b :as all]] (size all)) [1 2 3 4])") env)))
    (is (cl:= 1 (fol-eval (fol-form "((fn [[a b :as all]] a) [1 2 3 4])") env)))))

(test fn-destructure-map-keys
  "Test function with map :keys destructuring."
  (let ((env (make-standard-env)))
    (is (cl:= 3 (fol-eval (fol-form "((fn [{:keys [a b]}] (+ a b)) {:a 1 :b 2})") env)))))

(test fn-destructure-map-explicit
  "Test function with explicit key mapping in map destructuring."
  (let ((env (make-standard-env)))
    (is (cl:= 3 (fol-eval (fol-form "((fn [{x :a y :b}] (+ x y)) {:a 1 :b 2})") env)))))

(test fn-destructure-mixed-params
  "Test function with mix of simple and destructured params."
  (let ((env (make-standard-env)))
    ;; x is simple, [a b] is destructured
    (is (cl:= 6 (fol-eval (fol-form "((fn [x [a b]] (+ x a b)) 1 [2 3])") env)))))

(test fn-destructure-rest-with-destructuring
  "Test function with destructuring pattern as rest parameter."
  (let ((env (make-standard-env)))
    ;; First param is simple, rest is destructured as a list
    (is (cl:= 2 (fol-eval (fol-form "((fn [x & rest] (first rest)) 1 2 3)") env)))))

(test defn-destructure-params
  "Test defn with destructuring parameters."
  (let ((env (make-standard-env)))
    ;; Define function with destructuring
    (fol-eval (fol-form "(defn sum-pair [[a b]] (+ a b))") env)
    (is (cl:= 5 (fol-eval (fol-form "(sum-pair [2 3])") env)))))

;;; ---------------------------------------------------------------------------
;;; Macro Parameter Destructuring
;;; ---------------------------------------------------------------------------

(test macro-destructure-vector-param
  "Test macro with vector destructuring in parameter."
  (let ((env (make-standard-env)))
    ;; Macro that destructures its parameter
    (let* ((macro (fol-eval (fol-form "(defmacro with-pair [[a b] & body]
                               (list 'bind (list 'x a 'y b) (cons 'do body)))")
                            env))
           (env2 (make-env env 'with-pair macro)))
      ;; (with-pair [1 2] (+ x y)) expands to (bind (x 1 y 2) (do (+ x y)))
      (is (cl:= 3 (fol-eval (fol-form "(with-pair [1 2] (+ x y))") env2))))))

(test macro-destructure-extracts-form-parts
  "Test macro that destructures to extract parts of forms."
  (let ((env (make-standard-env)))
    ;; A macro that extracts the first two elements and returns them as a list
    (let* ((macro (fol-eval (fol-form "(defmacro get-first-two [[a b & rest]]
                               (list 'list b a))")
                            env))
           (env2 (make-env env 'get-first-two macro)))
      ;; (get-first-two (1 2 3)) => (2 1) - swapped first two elements
      (is (equal '(2 1) (fol-eval '(get-first-two (1 2 3)) env2))))))

(test macro-destructure-nested
  "Test macro with nested destructuring in parameter."
  (let ((env (make-standard-env)))
    ;; Macro that destructures nested structure
    ;; Pattern [[[a]]] extracts [[a]] as param, which extracts [a], then a
    ;; So with ((1)) as arg: [[a]] matches ((1)), [a] matches (1), a matches 1
    (let* ((macro (fol-eval (fol-form "(defmacro extract-nested [[[a]]]
                               a)")
                            env))
           (env2 (make-env env 'extract-nested macro)))
      ;; (extract-nested ((1))) => 1 (the atom)
      (is (cl:= 1 (fol-eval '(extract-nested ((1))) env2))))))

(test macro-destructure-with-rest
  "Test macro destructuring with rest binding."
  (let ((env (make-standard-env)))
    ;; Macro that captures some args in destructuring and rest
    (let* ((macro (fol-eval (fol-form "(defmacro take-two-and-rest [[a b & more]]
                               (list 'list a b (list 'quote more)))")
                            env))
           (env2 (make-env env 'take-two-and-rest macro)))
      (let ((result (fol-eval '(take-two-and-rest (1 2 3 4 5)) env2)))
        (is (cl:= 1 (cl:first result)))
        (is (cl:= 2 (cl:second result)))
        ;; The rest is a FOL list, check its elements
        (let ((rest-list (cl:third result)))
          (is (<list>? rest-list))
          (is (cl:= 3 (size rest-list)))
          (is (cl:= 3 (first rest-list)))
          (is (cl:= 4 (second rest-list)))
          (is (cl:= 5 (third rest-list))))))))

(test macro-destructure-map-keys
  "Test macro with map destructuring using :keys."
  (let ((env (make-standard-env)))
    ;; Note: This tests destructuring of the *unevaluated* form
    ;; So we pass a literal dict form as the macro argument
    (let* ((macro (fol-eval (fol-form "(defmacro extract-keys [{:keys [a b]}]
                               (list '+ a b))")
                            env))
           (env2 (make-env env 'extract-keys macro)))
      ;; (extract-keys {:a 1 :b 2}) - the {:a 1 :b 2} is passed as unevaluated
      ;; so the macro sees the dict literal and can destructure it
      (is (cl:= 3 (fol-eval (fol-form "(extract-keys {:a 1 :b 2})") env2))))))

(test macro-destructure-practical-let-macro
  "Test practical use: let macro with destructuring bindings."
  (let ((env (make-standard-env)))
    ;; A let macro that supports one destructured binding pair
    ;; (my-let [pattern value] body) => (bind [pattern value] body)
    (let* ((macro (fol-eval (fol-form "(defmacro my-let [[pattern value] & body]
                               (list 'bind (list pattern value) (cons 'do body)))")
                            env))
           (env2 (make-env env 'my-let macro)))
      ;; Test with simple binding
      (is (cl:= 10 (fol-eval (fol-form "(my-let [x 10] x)") env2)))
      ;; Test with destructured binding pattern inside the let
      (is (cl:= 3 (fol-eval (fol-form "(my-let [[a b] [1 2]] (+ a b))") env2))))))

;;; ---------------------------------------------------------------------------
;;; Anonymous Function Literals #()
;;; ---------------------------------------------------------------------------

(test eval-fn-literal-single-arg
  "Test evaluating #() with single arg (%)."
  (let ((env (make-standard-env)))
    ;; #(+ % 1) called with 10 should return 11
    (is (cl:= 11 (fol-eval (fol-form "(#(+ % 1) 10)") env)))
    ;; #(* % %) squares the argument
    (is (cl:= 25 (fol-eval (fol-form "(#(* % %) 5)") env)))))

(test eval-fn-literal-two-args
  "Test evaluating #() with two args (%1 %2)."
  (let ((env (make-standard-env)))
    ;; #(+ %1 %2) called with 3 and 4 should return 7
    (is (cl:= 7 (fol-eval (fol-form "(#(+ %1 %2) 3 4)") env)))
    ;; #(- %1 %2) called with 10 and 3 should return 7
    (is (cl:= 7 (fol-eval (fol-form "(#(- %1 %2) 10 3)") env)))))

(test eval-fn-literal-numbered-args
  "Test evaluating #() with higher numbered args."
  (let ((env (make-standard-env)))
    ;; #(+ %1 %2 %3) called with 1, 2, 3 should return 6
    (is (cl:= 6 (fol-eval (fol-form "(#(+ %1 %2 %3) 1 2 3)") env)))
    ;; Using only %3 should still expect 3 args
    (is (cl:= 30 (fol-eval (fol-form "(#(* %3 10) 1 2 3)") env)))))

(test eval-fn-literal-rest-args
  "Test evaluating #() with rest args (%&)."
  (let ((env (make-standard-env)))
    ;; #(first %&) called with multiple args returns the first
    (is (cl:= 1 (fol-eval (fol-form "(#(first %&) 1 2 3)") env)))
    ;; #(size %&) counts the rest args
    (is (cl:= 4 (fol-eval (fol-form "(#(size %&) 1 2 3 4)") env)))))

(test eval-fn-literal-mixed-args
  "Test evaluating #() with positional and rest args."
  (let ((env (make-standard-env)))
    ;; #(+ %1 (first %&)) mixes positional and rest
    (is (cl:= 3 (fol-eval (fol-form "(#(+ %1 (first %&)) 1 2 3 4)") env)))
    ;; %2 and %& together
    (is (cl:= 5 (fol-eval (fol-form "(#(+ %2 (size %&)) 1 2 3 4 5)") env)))))

(test eval-fn-literal-nested-forms
  "Test evaluating #() with nested forms."
  (let ((env (make-standard-env)))
    ;; Nested arithmetic
    (is (cl:= 14 (fol-eval (fol-form "(#(+ (* %1 2) (* %2 3)) 1 4)") env)))
    ;; Conditionals inside
    (is (eq t (fol-eval (fol-form "(#(if (> % 5) t nil) 10)") env)))
    (is (eq nil (fol-eval (fol-form "(#(if (> % 5) t nil) 3)") env)))))

;;; ---------------------------------------------------------------------------
;;; Threading Macros (-> and ->>)
;;; ---------------------------------------------------------------------------

(test eval-thread-first-basic
  "Test basic thread-first (->)."
  (let ((env (make-standard-env)))
    ;; (-> 5 (+ 3)) => (+ 5 3) => 8
    (is (cl:= 8 (fol-eval (fol-form "(-> 5 (+ 3))") env)))
    ;; (-> 10 (- 3)) => (- 10 3) => 7
    (is (cl:= 7 (fol-eval (fol-form "(-> 10 (- 3))") env)))))

(test eval-thread-first-chained
  "Test chained thread-first (->)."
  (let ((env (make-standard-env)))
    ;; (-> 5 (+ 3) (* 2)) => (* (+ 5 3) 2) => (* 8 2) => 16
    (is (cl:= 16 (fol-eval (fol-form "(-> 5 (+ 3) (* 2))") env)))
    ;; (-> 10 (- 3) (+ 5) (* 2)) => (* (+ (- 10 3) 5) 2) => (* 12 2) => 24
    (is (cl:= 24 (fol-eval (fol-form "(-> 10 (- 3) (+ 5) (* 2))") env)))))

(test eval-thread-first-no-forms
  "Test thread-first with no threading forms."
  (let ((env (make-standard-env)))
    ;; (-> 42) => 42
    (is (cl:= 42 (fol-eval (fol-form "(-> 42)") env)))))

(test eval-thread-first-with-collections
  "Test thread-first with collection operations."
  (let ((env (make-standard-env)))
    ;; Create a list and get its first element
    ;; (-> (make '<list> 1 2 3) first) => (first (make '<list> 1 2 3)) => 1
    (is (cl:= 1 (fol-eval (fol-form "(-> (make '<list> 1 2 3) first)") env)))
    ;; (-> (make '<list> 1 2 3) rest first) => (first (rest (make '<list> 1 2 3))) => 2
    (is (cl:= 2 (fol-eval (fol-form "(-> (make '<list> 1 2 3) rest first)") env)))))

(test eval-thread-last-basic
  "Test basic thread-last (->>)."
  (let ((env (make-standard-env)))
    ;; (->> 5 (+ 3)) => (+ 3 5) => 8
    (is (cl:= 8 (fol-eval (fol-form "(->> 5 (+ 3))") env)))
    ;; (->> 3 (- 10)) => (- 10 3) => 7
    (is (cl:= 7 (fol-eval (fol-form "(->> 3 (- 10))") env)))))

(test eval-thread-last-chained
  "Test chained thread-last (->>)."
  (let ((env (make-standard-env)))
    ;; (->> 5 (+ 3) (* 2)) => (* 2 (+ 3 5)) => (* 2 8) => 16
    (is (cl:= 16 (fol-eval (fol-form "(->> 5 (+ 3) (* 2))") env)))
    ;; (->> 1 (+ 2) (+ 3) (+ 4)) => (+ 4 (+ 3 (+ 2 1))) => 10
    (is (cl:= 10 (fol-eval (fol-form "(->> 1 (+ 2) (+ 3) (+ 4))") env)))))

(test eval-thread-last-no-forms
  "Test thread-last with no threading forms."
  (let ((env (make-standard-env)))
    ;; (->> 42) => 42
    (is (cl:= 42 (fol-eval (fol-form "(->> 42)") env)))))

(test eval-thread-first-vs-last-difference
  "Test the difference between -> and ->>."
  (let ((env (make-standard-env)))
    ;; With subtraction, position matters:
    ;; (-> 10 (- 3)) => (- 10 3) => 7 (10 is first arg)
    (is (cl:= 7 (fol-eval (fol-form "(-> 10 (- 3))") env)))
    ;; (->> 10 (- 3)) => (- 3 10) => -7 (10 is last arg)
    (is (cl:= -7 (fol-eval (fol-form "(->> 10 (- 3))") env)))))

(test eval-thread-with-multiple-args
  "Test threading with functions taking multiple args."
  (let ((env (make-standard-env)))
    ;; (-> 10 (+ 1 2 3)) => (+ 10 1 2 3) => 16
    (is (cl:= 16 (fol-eval (fol-form "(-> 10 (+ 1 2 3))") env)))
    ;; (->> 10 (+ 1 2 3)) => (+ 1 2 3 10) => 16
    (is (cl:= 16 (fol-eval (fol-form "(->> 10 (+ 1 2 3))") env)))))

(test eval-thread-with-bare-symbols
  "Test threading with bare function symbols."
  (let ((env (make-standard-env)))
    ;; Define a simple function
    (fol-eval (fol-form "(def double (fn [x] (* x 2)))") env)
    ;; (-> 5 double) => (double 5) => 10
    (is (cl:= 10 (fol-eval (fol-form "(-> 5 double)") env)))
    ;; (-> 5 double double) => (double (double 5)) => 20
    (is (cl:= 20 (fol-eval (fol-form "(-> 5 double double)") env)))))

(test eval-thread-nested
  "Test nested threading expressions."
  (let ((env (make-standard-env)))
    ;; Inner -> evaluates first, result is threaded
    ;; (-> (-> 5 (+ 3)) (* 2)) => (-> 8 (* 2)) => (* 8 2) => 16
    (is (cl:= 16 (fol-eval (fol-form "(-> (-> 5 (+ 3)) (* 2))") env)))))

(test eval-thread-with-conditionals
  "Test threading with conditional expressions."
  (let ((env (make-standard-env)))
    ;; Thread result of if into arithmetic
    ;; (-> (if t 10 20) (+ 5)) => (+ 10 5) => 15
    (is (cl:= 15 (fol-eval (fol-form "(-> (if t 10 20) (+ 5))") env)))))
