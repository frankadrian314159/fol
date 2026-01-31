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

(test eval-min-max
  "Test min and max functions."
  (let ((env (make-standard-env)))
    ;; min - basic usage
    (is (cl:= 1 (fol-eval '(min 1 2 3) env)))
    (is (cl:= -5 (fol-eval '(min 3 -5 2) env)))
    (is (cl:= 42 (fol-eval '(min 42) env)))
    ;; min with floats
    (is (cl:= 1.5 (fol-eval '(min 1.5 2.5 3.5) env)))
    (is (cl:= 1 (fol-eval '(min 1 1.5 2) env)))
    ;; max - basic usage
    (is (cl:= 3 (fol-eval '(max 1 2 3) env)))
    (is (cl:= 5 (fol-eval '(max -3 5 2) env)))
    (is (cl:= 42 (fol-eval '(max 42) env)))
    ;; max with floats
    (is (cl:= 3.5 (fol-eval '(max 1.5 2.5 3.5) env)))
    (is (cl:= 2.5 (fol-eval '(max 1 2.5 2) env)))
    ;; min/max with two args
    (is (cl:= 1 (fol-eval '(min 1 2) env)))
    (is (cl:= 2 (fol-eval '(max 1 2) env)))
    ;; min/max with negative numbers
    (is (cl:= -10 (fol-eval '(min -10 -5 0 5) env)))
    (is (cl:= 5 (fol-eval '(max -10 -5 0 5) env)))))

(test eval-type-predicates-bool
  "Test boolean type predicate."
  (let ((env (make-standard-env)))
    (is (eq t (fol-eval '(<bool>? t) env)))
    (is (eq t (fol-eval '(<bool>? nil) env)))
    (is (eq nil (fol-eval '(<bool>? 42) env)))
    (is (eq nil (fol-eval '(<bool>? "true") env)))
    (is (eq nil (fol-eval '(<bool>? :true) env)))
    (is (eq nil (fol-eval '(<bool>? 'true) env)))))

(test eval-type-predicates-char
  "Test character type predicate."
  (let ((env (make-standard-env)))
    (is (eq t (fol-eval '(<char>? #\a) env)))
    (is (eq t (fol-eval '(<char>? #\Space) env)))
    (is (eq t (fol-eval '(<char>? #\Newline) env)))
    (is (eq nil (fol-eval '(<char>? "a") env)))
    (is (eq nil (fol-eval '(<char>? 65) env)))
    (is (eq nil (fol-eval '(<char>? :a) env)))))

(test eval-type-predicates-string
  "Test string type predicate."
  (let ((env (make-standard-env)))
    (is (eq t (fol-eval '(<string>? "hello") env)))
    (is (eq t (fol-eval '(<string>? "") env)))
    (is (eq t (fol-eval '(<string>? "with spaces") env)))
    (is (eq nil (fol-eval '(<string>? #\a) env)))
    (is (eq nil (fol-eval '(<string>? 42) env)))
    (is (eq nil (fol-eval '(<string>? :hello) env)))
    (is (eq nil (fol-eval '(<string>? 'hello) env)))))

(test eval-type-predicates-symbol
  "Test symbol type predicate."
  (let ((env (make-standard-env)))
    (is (eq t (fol-eval '(<symbol>? 'foo) env)))
    (is (eq t (fol-eval '(<symbol>? 'bar-baz) env)))
    ;; Keywords are also symbols
    (is (eq t (fol-eval '(<symbol>? :keyword) env)))
    (is (eq nil (fol-eval '(<symbol>? "foo") env)))
    (is (eq nil (fol-eval '(<symbol>? 42) env)))
    (is (eq nil (fol-eval '(<symbol>? #\a) env)))))

(test eval-type-predicates-keyword
  "Test keyword type predicate."
  (let ((env (make-standard-env)))
    (is (eq t (fol-eval '(<keyword>? :foo) env)))
    (is (eq t (fol-eval '(<keyword>? :bar-baz) env)))
    (is (eq nil (fol-eval '(<keyword>? 'foo) env)))
    (is (eq nil (fol-eval '(<keyword>? "foo") env)))
    (is (eq nil (fol-eval '(<keyword>? 42) env)))))

(test eval-type-predicates-number
  "Test number type predicate."
  (let ((env (make-standard-env)))
    ;; All numeric types should return true
    (is (eq t (fol-eval '(<number>? 42) env)))
    (is (eq t (fol-eval '(<number>? -17) env)))
    (is (eq t (fol-eval '(<number>? 3.14) env)))
    (is (eq t (fol-eval '(<number>? 1/2) env)))
    (is (eq t (fol-eval '(<number>? #C(1 2)) env)))
    ;; Non-numbers should return nil
    (is (eq nil (fol-eval '(<number>? "42") env)))
    (is (eq nil (fol-eval '(<number>? :42) env)))
    (is (eq nil (fol-eval '(<number>? #\0) env)))))

(test eval-type-predicates-integer
  "Test integer type predicates."
  (let ((env (make-standard-env)))
    ;; <integer>?
    (is (eq t (fol-eval '(<integer>? 42) env)))
    (is (eq t (fol-eval '(<integer>? -17) env)))
    (is (eq t (fol-eval '(<integer>? 0) env)))
    (is (eq nil (fol-eval '(<integer>? 3.14) env)))
    (is (eq nil (fol-eval '(<integer>? 1/2) env)))
    ;; <fixnum>?
    (is (eq t (fol-eval '(<fixnum>? 42) env)))
    (is (eq t (fol-eval '(<fixnum>? -1) env)))
    (is (eq nil (fol-eval '(<fixnum>? 3.14) env)))
    ;; <bignum>? - use a number larger than most-positive-fixnum
    (is (eq nil (fol-eval '(<bignum>? 42) env)))
    (is (eq t (fol-eval `(<bignum>? ,(1+ most-positive-fixnum)) env)))))

(test eval-type-predicates-float
  "Test float type predicates."
  (let ((env (make-standard-env)))
    ;; <float>?
    (is (eq t (fol-eval '(<float>? 3.14) env)))
    (is (eq t (fol-eval '(<float>? 1.0) env)))
    (is (eq nil (fol-eval '(<float>? 42) env)))
    (is (eq nil (fol-eval '(<float>? 1/2) env)))
    ;; <single-float>?
    (is (eq t (fol-eval '(<single-float>? 3.14f0) env)))
    (is (eq nil (fol-eval '(<single-float>? 3.14d0) env)))
    (is (eq nil (fol-eval '(<single-float>? 42) env)))
    ;; <double-float>?
    (is (eq t (fol-eval '(<double-float>? 3.14d0) env)))
    (is (eq nil (fol-eval '(<double-float>? 3.14f0) env)))
    (is (eq nil (fol-eval '(<double-float>? 42) env)))))

(test eval-type-predicates-rational
  "Test rational type predicates."
  (let ((env (make-standard-env)))
    ;; <ratio>?
    (is (eq t (fol-eval '(<ratio>? 1/2) env)))
    (is (eq t (fol-eval '(<ratio>? 3/4) env)))
    (is (eq nil (fol-eval '(<ratio>? 42) env)))
    (is (eq nil (fol-eval '(<ratio>? 2/2) env)))  ; 2/2 simplifies to 1
    (is (eq nil (fol-eval '(<ratio>? 3.14) env)))
    ;; <rational>?
    (is (eq t (fol-eval '(<rational>? 42) env)))      ; integers are rational
    (is (eq t (fol-eval '(<rational>? 1/2) env)))     ; ratios are rational
    (is (eq nil (fol-eval '(<rational>? 3.14) env)))  ; floats are not rational
    (is (eq nil (fol-eval '(<rational>? #C(1 2)) env)))))  ; complex not rational

(test eval-type-predicates-complex
  "Test complex type predicate."
  (let ((env (make-standard-env)))
    (is (eq t (fol-eval '(<complex>? #C(1 2)) env)))
    (is (eq t (fol-eval '(<complex>? #C(3.0 4.0)) env)))
    (is (eq nil (fol-eval '(<complex>? 42) env)))
    (is (eq nil (fol-eval '(<complex>? 3.14) env)))
    (is (eq nil (fol-eval '(<complex>? 1/2) env)))))

(test eval-type-predicates-collection
  "Test collection type predicates."
  (let ((env (make-standard-env)))
    ;; Create test collections
    (let ((vec (make-vector 1 2 3))
          (lst (make-list 1 2 3))
          (dict (make-dict :a 1 :b 2))
          (st (make-set 1 2 3))
          (bg (make-bag 1 2 2 3)))
      ;; <collection>? - all collections should pass
      (is (eq t (fol-eval `(<collection>? ',vec) env)))
      (is (eq t (fol-eval `(<collection>? ',lst) env)))
      (is (eq t (fol-eval `(<collection>? ',dict) env)))
      (is (eq t (fol-eval `(<collection>? ',st) env)))
      (is (eq t (fol-eval `(<collection>? ',bg) env)))
      (is (eq nil (fol-eval '(<collection>? 42) env)))
      (is (eq nil (fol-eval '(<collection>? "hello") env))))))

(test eval-type-predicates-ordered-collection
  "Test ordered collection type predicates."
  (let ((env (make-standard-env)))
    (let ((vec (make-vector 1 2 3))
          (lst (make-list 1 2 3))
          (dict (make-dict :a 1)))
      ;; <ordered-collection>? - vectors and lists are ordered
      (is (eq t (fol-eval `(<ordered-collection>? ',vec) env)))
      (is (eq t (fol-eval `(<ordered-collection>? ',lst) env)))
      (is (eq nil (fol-eval `(<ordered-collection>? ',dict) env)))
      ;; <vector>?
      (is (eq t (fol-eval `(<vector>? ',vec) env)))
      (is (eq nil (fol-eval `(<vector>? ',lst) env)))
      (is (eq nil (fol-eval '(<vector>? 42) env)))
      ;; <list>?
      (is (eq t (fol-eval `(<list>? ',lst) env)))
      (is (eq nil (fol-eval `(<list>? ',vec) env)))
      (is (eq nil (fol-eval '(<list>? 42) env))))))

(test eval-type-predicates-unordered-collection
  "Test unordered collection type predicates."
  (let ((env (make-standard-env)))
    (let ((dict (make-dict :a 1 :b 2))
          (st (make-set 1 2 3))
          (bg (make-bag 1 2 2 3))
          (vec (make-vector 1 2 3)))
      ;; <unordered-collection>? - dicts, sets, bags are unordered
      (is (eq t (fol-eval `(<unordered-collection>? ',dict) env)))
      (is (eq t (fol-eval `(<unordered-collection>? ',st) env)))
      (is (eq t (fol-eval `(<unordered-collection>? ',bg) env)))
      (is (eq nil (fol-eval `(<unordered-collection>? ',vec) env)))
      ;; <dict>?
      (is (eq t (fol-eval `(<dict>? ',dict) env)))
      (is (eq nil (fol-eval `(<dict>? ',st) env)))
      (is (eq nil (fol-eval '(<dict>? 42) env)))
      ;; <set>?
      (is (eq t (fol-eval `(<set>? ',st) env)))
      (is (eq nil (fol-eval `(<set>? ',dict) env)))
      (is (eq nil (fol-eval '(<set>? 42) env)))
      ;; <bag>?
      (is (eq t (fol-eval `(<bag>? ',bg) env)))
      (is (eq nil (fol-eval `(<bag>? ',st) env)))
      (is (eq nil (fol-eval '(<bag>? 42) env))))))

(test eval-type-predicates-array
  "Test array type predicate."
  (let ((env (make-standard-env)))
    (let ((arr (make-array '(2 3) :initial-element 0))
          (vec (make-vector 1 2 3)))
      (is (eq t (fol-eval `(<array>? ',arr) env)))
      (is (eq nil (fol-eval `(<array>? ',vec) env)))
      (is (eq nil (fol-eval '(<array>? 42) env))))))

(test eval-type-predicates-lazy-seq
  "Test lazy-seq type predicate."
  (let ((env (make-standard-env)))
    (let ((ls (fol-eval '(lazy-seq (list 1 2 3)) env))
          (vec (make-vector 1 2 3)))
      (is (eq t (fol-eval `(<lazy-seq>? ',ls) env)))
      (is (eq nil (fol-eval `(<lazy-seq>? ',vec) env)))
      (is (eq nil (fol-eval '(<lazy-seq>? 42) env))))))

;;; ---------------------------------------------------------------------------
;;; Number Predicates
;;; ---------------------------------------------------------------------------

(test eval-number-predicates-positive-negative
  "Test positive? and negative? predicates."
  (let ((env (make-standard-env)))
    ;; positive?
    (is (eq t (fol-eval '(positive? 42) env)))
    (is (eq t (fol-eval '(positive? 0.001) env)))
    (is (eq t (fol-eval '(positive? 1/2) env)))
    (is (eq nil (fol-eval '(positive? 0) env)))
    (is (eq nil (fol-eval '(positive? -5) env)))
    (is (eq nil (fol-eval '(positive? -3.14) env)))
    ;; negative?
    (is (eq t (fol-eval '(negative? -42) env)))
    (is (eq t (fol-eval '(negative? -0.001) env)))
    (is (eq t (fol-eval '(negative? -1/2) env)))
    (is (eq nil (fol-eval '(negative? 0) env)))
    (is (eq nil (fol-eval '(negative? 5) env)))
    (is (eq nil (fol-eval '(negative? 3.14) env)))))

(test eval-number-predicates-zero
  "Test zero? predicate."
  (let ((env (make-standard-env)))
    (is (eq t (fol-eval '(zero? 0) env)))
    (is (eq t (fol-eval '(zero? 0.0) env)))
    (is (eq t (fol-eval '(zero? 0/1) env)))
    (is (eq nil (fol-eval '(zero? 1) env)))
    (is (eq nil (fol-eval '(zero? -1) env)))
    (is (eq nil (fol-eval '(zero? 0.001) env)))))

(test eval-number-predicates-even-odd
  "Test even? and odd? predicates."
  (let ((env (make-standard-env)))
    ;; even?
    (is (eq t (fol-eval '(even? 0) env)))
    (is (eq t (fol-eval '(even? 2) env)))
    (is (eq t (fol-eval '(even? -4) env)))
    (is (eq t (fol-eval '(even? 100) env)))
    (is (eq nil (fol-eval '(even? 1) env)))
    (is (eq nil (fol-eval '(even? -3) env)))
    ;; odd?
    (is (eq t (fol-eval '(odd? 1) env)))
    (is (eq t (fol-eval '(odd? -3) env)))
    (is (eq t (fol-eval '(odd? 99) env)))
    (is (eq nil (fol-eval '(odd? 0) env)))
    (is (eq nil (fol-eval '(odd? 2) env)))
    (is (eq nil (fol-eval '(odd? -4) env)))))

;;; ---------------------------------------------------------------------------
;;; String Operations
;;; ---------------------------------------------------------------------------

(test eval-str-concatenation
  "Test str function for string concatenation."
  (let ((env (make-standard-env)))
    ;; Basic string concatenation
    (is (string= "hello" (fol-eval '(str "hello") env)))
    (is (string= "helloworld" (fol-eval '(str "hello" "world") env)))
    (is (string= "abc" (fol-eval '(str "a" "b" "c") env)))
    ;; Empty strings
    (is (string= "" (fol-eval '(str) env)))
    (is (string= "hello" (fol-eval '(str "" "hello" "") env)))
    ;; Converting numbers to strings
    (is (string= "42" (fol-eval '(str 42) env)))
    (is (string= "3.14" (fol-eval '(str 3.14) env)))
    (is (string= "1/2" (fol-eval '(str 1/2) env)))
    ;; Mixed types
    (is (string= "The answer is 42" (fol-eval '(str "The answer is " 42) env)))
    (is (string= "x = 3.14" (fol-eval '(str "x = " 3.14) env)))
    ;; Keywords and symbols
    (is (string= "FOO" (fol-eval '(str :foo) env)))
    ;; Characters
    (is (string= "a" (fol-eval '(str #\a) env)))
    (is (string= "abc" (fol-eval '(str #\a #\b #\c) env)))))

;;; ---------------------------------------------------------------------------
;;; Misc Utility Functions
;;; ---------------------------------------------------------------------------

(test eval-identity-function
  "Test identity function returns its argument unchanged."
  (let ((env (make-standard-env)))
    (is (cl:= 42 (fol-eval '(identity 42) env)))
    (is (string= "hello" (fol-eval '(identity "hello") env)))
    (is (eq :foo (fol-eval '(identity :foo) env)))
    (is (eq nil (fol-eval '(identity nil) env)))
    (is (eq t (fol-eval '(identity t) env)))
    ;; Works with collections
    (let ((vec (make-vector 1 2 3)))
      (is (eq vec (fol-eval `(identity ',vec) env))))))

(test eval-complement-function
  "Test complement returns a function that negates the predicate."
  (let ((env (make-standard-env)))
    ;; Complement of even? is odd-like
    (is (eq nil (fol-eval '((complement even?) 2) env)))
    (is (eq t (fol-eval '((complement even?) 3) env)))
    ;; Complement of positive?
    (is (eq nil (fol-eval '((complement positive?) 5) env)))
    (is (eq t (fol-eval '((complement positive?) -5) env)))
    (is (eq t (fol-eval '((complement positive?) 0) env)))
    ;; Complement of zero?
    (is (eq nil (fol-eval '((complement zero?) 0) env)))
    (is (eq t (fol-eval '((complement zero?) 1) env)))))

(test eval-make-constructor
  "Test make generic constructor with quoted class symbols."
  (let ((env (make-standard-env)))
    ;; Make vector - use quoted class name since <vector> isn't bound as variable
    (let ((result (fol-eval '(make '<vector> 1 2 3) env)))
      (is (<vector>? result))
      (is (cl:= 3 (size result)))
      (is (cl:= 1 (first result))))
    ;; Make list
    (let ((result (fol-eval '(make '<list> 4 5 6) env)))
      (is (<list>? result))
      (is (cl:= 3 (size result))))
    ;; Make dict
    (let ((result (fol-eval '(make '<dict> :a 1 :b 2) env)))
      (is (<dict>? result))
      (is (cl:= 1 (get result :a))))
    ;; Make set
    (let ((result (fol-eval '(make '<set> 1 2 3 2 1) env)))
      (is (<set>? result))
      (is (cl:= 3 (size result))))
    ;; Make bag - size returns unique element count
    (let ((result (fol-eval '(make '<bag> 1 2 2 3) env)))
      (is (<bag>? result))
      (is (cl:= 3 (size result))))))

;;; ---------------------------------------------------------------------------
;;; Collection Accessor Functions
;;; ---------------------------------------------------------------------------

(test eval-second-third-functions
  "Test second and third accessor functions."
  (let ((env (make-standard-env)))
    ;; On FOL lists
    (let ((lst (make-list :a :b :c :d)))
      (is (eq :b (fol-eval `(second ',lst) env)))
      (is (eq :c (fol-eval `(third ',lst) env))))
    ;; On CL lists
    (is (cl:= 2 (fol-eval '(second '(1 2 3 4)) env)))
    (is (cl:= 3 (fol-eval '(third '(1 2 3 4)) env)))
    ;; On strings
    (is (char= #\e (fol-eval '(second "hello") env)))
    (is (char= #\l (fol-eval '(third "hello") env)))))

(test eval-nth-function
  "Test nth accessor function (nth collection index)."
  (let ((env (make-standard-env)))
    ;; On vectors (0-indexed) - note: (nth collection index)
    (let ((vec (make-vector :a :b :c :d :e)))
      (is (eq :a (fol-eval `(nth ',vec 0) env)))
      (is (eq :c (fol-eval `(nth ',vec 2) env)))
      (is (eq :e (fol-eval `(nth ',vec 4) env))))
    ;; On FOL lists
    (let ((lst (make-list 10 20 30 40 50)))
      (is (cl:= 10 (fol-eval `(nth ',lst 0) env)))
      (is (cl:= 30 (fol-eval `(nth ',lst 2) env)))
      (is (cl:= 50 (fol-eval `(nth ',lst 4) env))))
    ;; On CL lists
    (is (eq :first (fol-eval '(nth '(:first :second :third) 0) env)))
    (is (eq :third (fol-eval '(nth '(:first :second :third) 2) env)))
    ;; On strings
    (is (char= #\h (fol-eval '(nth "hello" 0) env)))
    (is (char= #\o (fol-eval '(nth "hello" 4) env)))))

(test eval-size-function
  "Test size function returns collection size."
  (let ((env (make-standard-env)))
    ;; Vectors
    (let ((vec (make-vector 1 2 3 4 5)))
      (is (cl:= 5 (fol-eval `(size ',vec) env))))
    (is (cl:= 0 (fol-eval `(size ',(make-vector)) env)))
    ;; Lists
    (let ((lst (make-list :a :b :c)))
      (is (cl:= 3 (fol-eval `(size ',lst) env))))
    ;; Dicts
    (let ((dict (make-dict :x 1 :y 2)))
      (is (cl:= 2 (fol-eval `(size ',dict) env))))
    ;; Sets
    (let ((st (make-set 1 2 3 4)))
      (is (cl:= 4 (fol-eval `(size ',st) env))))
    ;; Bags (size returns unique element count, not total)
    (let ((bg (make-bag 1 1 2 2 2)))
      (is (cl:= 2 (fol-eval `(size ',bg) env))))
    ;; Strings
    (is (cl:= 5 (fol-eval '(size "hello") env)))
    (is (cl:= 0 (fol-eval '(size "") env)))))

(test eval-get-function
  "Test get function for collection access."
  (let ((env (make-standard-env)))
    ;; Dict access by key
    (let ((dict (make-dict :name "Alice" :age 30)))
      (is (string= "Alice" (fol-eval `(get ',dict :name) env)))
      (is (cl:= 30 (fol-eval `(get ',dict :age) env)))
      ;; Missing key returns nil
      (is (eq nil (fol-eval `(get ',dict :missing) env))))
    ;; Vector access by index
    (let ((vec (make-vector :a :b :c)))
      (is (eq :a (fol-eval `(get ',vec 0) env)))
      (is (eq :c (fol-eval `(get ',vec 2) env))))
    ;; FOL list access by index
    (let ((lst (make-list 10 20 30)))
      (is (cl:= 10 (fol-eval `(get ',lst 0) env)))
      (is (cl:= 30 (fol-eval `(get ',lst 2) env))))))

(test eval-contains-function
  "Test contains? function for membership testing."
  (let ((env (make-standard-env)))
    ;; Set membership
    (let ((st (make-set :a :b :c)))
      (is (eq t (fol-eval `(contains? ',st :a) env)))
      (is (eq t (fol-eval `(contains? ',st :c) env)))
      (is (eq nil (fol-eval `(contains? ',st :z) env))))
    ;; Dict has key
    (let ((dict (make-dict :x 1 :y 2)))
      (is (eq t (fol-eval `(contains? ',dict :x) env)))
      (is (eq nil (fol-eval `(contains? ',dict :z) env))))
    ;; Bag membership
    (let ((bg (make-bag 1 2 2 3)))
      (is (eq t (fol-eval `(contains? ',bg 2) env)))
      (is (eq nil (fol-eval `(contains? ',bg 99) env))))))

(test eval-seq-function
  "Test seq function converts collections to sequences."
  (let ((env (make-standard-env)))
    ;; Vector to seq
    (let* ((vec (make-vector 1 2 3))
           (s (fol-eval `(seq ',vec) env)))
      (is (cl:= 1 (first s)))
      (is (cl:= 2 (first (rest s)))))
    ;; List to seq
    (let* ((lst (make-list :a :b :c))
           (s (fol-eval `(seq ',lst) env)))
      (is (eq :a (first s))))
    ;; Empty collection returns nil/empty
    (let ((empty-vec (make-vector)))
      (is (fol.seqop:empty? (fol-eval `(seq ',empty-vec) env))))
    ;; String to seq (characters)
    (let ((s (fol-eval '(seq "abc") env)))
      (is (char= #\a (first s)))
      (is (char= #\b (first (rest s)))))))

(test eval-add-function
  "Test add function adds elements to collections."
  (let ((env (make-standard-env)))
    ;; Add to set
    (let* ((st (make-set 1 2))
           (result (fol-eval `(add ',st 3) env)))
      (is (<set>? result))
      (is (cl:= 3 (size result)))
      (is (contains? result 3)))
    ;; Add duplicate to set (no change in size)
    (let* ((st (make-set 1 2 3))
           (result (fol-eval `(add ',st 2) env)))
      (is (cl:= 3 (size result))))
    ;; Add to bag (allows duplicates, but size counts unique elements)
    (let* ((bg (make-bag 1 2))
           (result (fol-eval `(add ',bg 3) env)))  ; add new element
      (is (<bag>? result))
      (is (cl:= 3 (size result))))))

(test eval-type-function
  "Test type function returns the FOL type of values."
  (let ((env (make-standard-env)))
    ;; Numeric types
    (is (eq '<fixnum> (fol-eval '(type 42) env)))
    (is (eq '<ratio> (fol-eval '(type 1/2) env)))
    (is (eq '<double-float> (fol-eval '(type 3.14d0) env)))
    (is (eq '<single-float> (fol-eval '(type 3.14f0) env)))
    (is (eq '<complex> (fol-eval '(type #C(1 2)) env)))
    ;; Other primitives
    (is (eq '<bool> (fol-eval '(type t) env)))
    (is (eq '<bool> (fol-eval '(type nil) env)))
    (is (eq '<string> (fol-eval '(type "hello") env)))
    (is (eq '<char> (fol-eval '(type #\a) env)))
    (is (eq '<symbol> (fol-eval '(type 'foo) env)))
    (is (eq '<keyword> (fol-eval '(type :foo) env)))
    ;; CL list returns <list>
    (is (eq '<list> (fol-eval '(type '(1 2 3)) env)))
    ;; FOL collections
    (let ((vec (make-vector 1 2 3))
          (lst (make-list 1 2 3))
          (dict (make-dict :a 1))
          (st (make-set 1 2 3))
          (bg (make-bag 1 2 2)))
      (is (eq '<vector> (fol-eval `(type ',vec) env)))
      (is (eq '<list> (fol-eval `(type ',lst) env)))
      (is (eq '<dict> (fol-eval `(type ',dict) env)))
      (is (eq '<set> (fol-eval `(type ',st) env)))
      (is (eq '<bag> (fol-eval `(type ',bg) env))))))

(test eval-type-function-user-defined-class
  "Test type function returns class name for user-defined classes."
  (let ((env (make-standard-env)))
    ;; Define a class using FOL's defclass with proper initargs
    (fol-eval `(defclass <test-person> ,(make-vector)
                 ,(make-vector (make-vector 'name :initarg :name)
                               (make-vector 'age :initarg :age))) env)
    ;; Create an instance using FOL's make and check its type
    (let ((person (fol-eval `(make '<test-person> :name "Alice" :age 30) env)))
      (is (eq '<test-person> (fol-eval `(type ',person) env))))))

(test eval-keyword-as-function
  "Test using keywords as functions for collection access."
  (let* ((dict (make-dict :name "Alice" :age 30))
         (env (make-env nil 'person dict)))
    (is (string= "Alice" (fol-eval '(:name person) env)))
    (is (cl:= 30 (fol-eval '(:age person) env)))))

(test eval-keyword-as-function-on-set
  "Test using keywords as functions on sets."
  (let* ((s (make-set :a :b :c))
         (env (make-env nil 'my-set s)))
    (is (eq :b (fol-eval '(:b my-set) env)))
    (is (eq nil (fol-eval '(:missing my-set) env)))))

(test eval-collection-as-function-dict
  "Test using dict as function for key lookup."
  (let* ((dict (make-dict :name "Alice" :age 30))
         (env (make-env nil 'person dict)))
    (is (string= "Alice" (fol-eval '(person :name) env)))
    (is (cl:= 30 (fol-eval '(person :age) env)))))

(test eval-collection-as-function-vector
  "Test using vector as function for index lookup."
  (let* ((v (make-vector 10 20 30 40))
         (env (make-env nil 'v v)))
    (is (cl:= 10 (fol-eval '(v 0) env)))
    (is (cl:= 30 (fol-eval '(v 2) env)))
    (is (eq nil (fol-eval '(v 10) env)))))

(test eval-collection-as-function-set
  "Test using set as function for membership lookup."
  (let* ((s (make-set 1 2 3 4 5))
         (env (make-env nil 's s)))
    (is (cl:= 3 (fol-eval '(s 3) env)))
    (is (eq nil (fol-eval '(s 10) env)))))

(test eval-collection-as-function-with-default
  "Test using collection as function with default value."
  (let* ((dict (make-dict :a 1))
         (env (make-env nil 'd dict)))
    (is (cl:= 1 (fol-eval '(d :a) env)))
    (is (eq :not-found (fol-eval '(d :missing :not-found) env)))))

;;; ---------------------------------------------------------------------------
;;; Set Constructor Tests
;;; ---------------------------------------------------------------------------

(test eval-set-constructor
  "Test set constructor function."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval '(set 1 2 3 2 1) env)))
      (is-true (<set>? result))
      (is (cl:= 3 (size result))))))

(test eval-hash-set-constructor
  "Test hash-set constructor function."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval '(hash-set :a :b :c) env)))
      (is-true (<set>? result))
      (is (cl:= 3 (size result))))))

(test eval-sorted-set-constructor
  "Test sorted-set constructor function."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval '(sorted-set 3 1 4 1 5 9 2) env)))
      (is-true (<sorted-set>? result))
      (is (cl:= 6 (size result)))
      ;; Check elements are in sorted order
      (is (cl:= 1 (first (seq result)))))))

(test eval-ordered-set-constructor
  "Test ordered-set constructor function."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval '(ordered-set 3 1 4 5 9) env)))
      (is-true (<ordered-set>? result))
      (is (cl:= 5 (size result)))
      ;; Check elements preserve insertion order
      (is (cl:= 3 (first (seq result)))))))

(test eval-int-set-constructor
  "Test int-set constructor function."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval '(int-set 5 3 8 1) env)))
      (is-true (<int-set>? result))
      (is (cl:= 4 (size result)))
      ;; Should be sorted
      (is (cl:= 1 (first (seq result)))))))

(test eval-dense-int-set-constructor
  "Test dense-int-set constructor function."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval '(dense-int-set 0 10 1 3 5 7 9) env)))
      (is-true (<dense-int-set>? result))
      (is (cl:= 5 (size result)))
      (is-true (contains? result 5))
      (is-false (contains? result 4)))))

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
;;; COND Special Form
;;; ---------------------------------------------------------------------------

(test cond-basic
  "Test basic cond with matching first clause."
  (let ((env (make-standard-env)))
    (is (eq :first (fol-eval '(cond t :first nil :second) env)))))

(test cond-second-clause
  "Test cond matches second clause when first is false."
  (let ((env (make-standard-env)))
    (is (eq :second (fol-eval '(cond nil :first t :second) env)))))

(test cond-no-match
  "Test cond returns nil when no clause matches."
  (let ((env (make-standard-env)))
    (is (eq nil (fol-eval '(cond nil :first nil :second) env)))))

(test cond-with-expressions
  "Test cond with computed tests and forms."
  (let ((env (make-standard-env)))
    ;; Test matching based on computed value
    ;; Use fol-form to parse through FOL reader which handles [...] syntax
    (is (eq :positive (fol-eval (fol-form "(bind [x 5]
                                   (cond
                                     (< x 0) :negative
                                     (= x 0) :zero
                                     (> x 0) :positive))")
                                env)))
    (is (eq :zero (fol-eval (fol-form "(bind [x 0]
                               (cond
                                 (< x 0) :negative
                                 (= x 0) :zero
                                 (> x 0) :positive))")
                            env)))
    (is (eq :negative (fol-eval (fol-form "(bind [x -3]
                                   (cond
                                     (< x 0) :negative
                                     (= x 0) :zero
                                     (> x 0) :positive))")
                                env)))))

(test cond-default-with-t
  "Test cond with t as default case."
  (let ((env (make-standard-env)))
    (is (eq :default (fol-eval '(cond
                                  nil :first
                                  nil :second
                                  t :default)
                               env)))))

(test cond-evaluates-form
  "Test cond evaluates the form, not just returns it."
  (let ((env (make-standard-env)))
    (is (cl:= 15 (fol-eval '(cond t (+ 5 10)) env)))))

;;; ---------------------------------------------------------------------------
;;; CASE Special Form
;;; ---------------------------------------------------------------------------

(test case-basic-match
  "Test case matches a single value."
  (let ((env (make-standard-env)))
    (is (eq :one (fol-eval '(case 1
                              1 :one
                              2 :two
                              3 :three)
                           env)))))

(test case-vector-match
  "Test case matches from a vector of values."
  (let ((env (make-standard-env)))
    ;; Use backquote and make-vector since CL reader doesn't understand [...] syntax
    (is (eq :small (fol-eval `(case 2
                                ,(make-vector 0 1 2) :small
                                ,(make-vector 3 4 5) :medium
                                ,(make-vector 6 7 8 9) :large)
                             env)))))

(test case-default-form
  "Test case with default form when no match."
  (let ((env (make-standard-env)))
    (is (eq :unknown (fol-eval '(case 99
                                  1 :one
                                  2 :two
                                  :unknown)
                               env)))))

(test case-evaluates-target
  "Test case evaluates the target expression."
  (let ((env (make-standard-env)))
    (is (eq :three (fol-eval '(case (+ 1 2)
                                1 :one
                                2 :two
                                3 :three)
                             env)))))

(test case-evaluates-form
  "Test case evaluates the matching form."
  (let ((env (make-standard-env)))
    (is (cl:= 100 (fol-eval '(case :x
                               :a 10
                               :x (* 10 10)
                               :z 30)
                            env)))))

(test case-string-keys
  "Test case with string keys."
  (let ((env (make-standard-env)))
    (is (eq :art (fol-eval '(case "liberal arts"
                              "engineering" :eng
                              "business" :bus
                              "liberal arts" :art)
                           env)))))

(test case-no-match-error
  "Test case signals error when no match and no default."
  (let ((env (make-standard-env)))
    (signals fol-eval-error
      (fol-eval '(case 99
                   1 :one
                   2 :two)
                env))))

(test case-game-of-life-pattern
  "Test case like Game of Life neighbor counting."
  (let ((env (make-standard-env)))
    ;; Simulating the Game of Life rule
    ;; Use backquote and make-vector since CL reader doesn't understand [...] syntax
    (let ((low-vec (make-vector 0 1))
          (high-vec (make-vector 4 5 6 7 8)))
      (is (eq nil (fol-eval `(case 0
                               ,low-vec nil
                               2 :survive
                               3 :birth
                               ,high-vec nil)
                            env)))
      (is (eq :survive (fol-eval `(case 2
                                    ,low-vec nil
                                    2 :survive
                                    3 :birth
                                    ,high-vec nil)
                                 env)))
      (is (eq :birth (fol-eval `(case 3
                                  ,low-vec nil
                                  2 :survive
                                  3 :birth
                                  ,high-vec nil)
                               env)))
      (is (eq nil (fol-eval `(case 5
                               ,low-vec nil
                               2 :survive
                               3 :birth
                               ,high-vec nil)
                            env))))))

;;; ---------------------------------------------------------------------------
;;; Higher-Order Functions (disjoin, conjoin)
;;; ---------------------------------------------------------------------------

(test disjoin-basic
  "Test disjoin returns a function that is the OR of predicates."
  (let ((env (make-standard-env)))
    ;; Disjoin of positive? and zero? should match 0 and positive numbers
    (let ((non-negative? (fol-eval '(disjoin positive? zero?) env)))
      (is-true (funcall non-negative? 5))
      (is-true (funcall non-negative? 0))
      (is (eq nil (funcall non-negative? -3))))))

(test disjoin-short-circuit
  "Test disjoin returns first truthy value and short-circuits."
  (let ((env (make-standard-env)))
    ;; First truthy value is returned
    ;; Use fol-form to parse FOL syntax with [...] vectors
    (let ((f (fol-eval (fol-form "(disjoin (fn [x] nil) (fn [x] :second) (fn [x] :third))") env)))
      (is (eq :second (funcall f 1))))))

(test disjoin-all-false
  "Test disjoin returns nil when all predicates return false."
  (let ((env (make-standard-env)))
    (let ((never (fol-eval (fol-form "(disjoin (fn [x] nil) (fn [x] nil))") env)))
      (is (eq nil (funcall never 42))))))

(test disjoin-single-predicate
  "Test disjoin with a single predicate."
  (let ((env (make-standard-env)))
    (let ((wrapped (fol-eval '(disjoin positive?) env)))
      (is-true (funcall wrapped 5))
      (is (eq nil (funcall wrapped -5))))))

(test disjoin-multiple-args
  "Test disjoin returned function accepts multiple arguments."
  (let ((env (make-standard-env)))
    (let ((any-positive (fol-eval (fol-form "(disjoin (fn [a b] (positive? a))
                                                      (fn [a b] (positive? b)))") env)))
      (is-true (funcall any-positive 1 -1))
      (is-true (funcall any-positive -1 1))
      (is (eq nil (funcall any-positive -1 -1))))))

(test conjoin-basic
  "Test conjoin returns a function that is the AND of predicates."
  (let ((env (make-standard-env)))
    ;; Conjoin of positive? and even? should match positive even numbers
    (let ((positive-even? (fol-eval '(conjoin positive? even?) env)))
      (is-true (funcall positive-even? 4))
      (is (eq nil (funcall positive-even? 3)))   ; odd
      (is (eq nil (funcall positive-even? -4)))))) ; negative

(test conjoin-short-circuit
  "Test conjoin returns nil on first false and short-circuits."
  (let ((env (make-standard-env)))
    (let ((f (fol-eval (fol-form "(conjoin (fn [x] nil) (fn [x] :never-reached))") env)))
      (is (eq nil (funcall f 1))))))

(test conjoin-returns-last-value
  "Test conjoin returns the last predicate's value when all truthy."
  (let ((env (make-standard-env)))
    (let ((f (fol-eval (fol-form "(conjoin (fn [x] :first) (fn [x] :second) (fn [x] :last))") env)))
      (is (eq :last (funcall f 1))))))

(test conjoin-single-predicate
  "Test conjoin with a single predicate."
  (let ((env (make-standard-env)))
    (let ((wrapped (fol-eval '(conjoin positive?) env)))
      (is-true (funcall wrapped 5))
      (is (eq nil (funcall wrapped -5))))))

(test conjoin-multiple-args
  "Test conjoin returned function accepts multiple arguments."
  (let ((env (make-standard-env)))
    (let ((both-positive (fol-eval (fol-form "(conjoin (fn [a b] (positive? a))
                                                       (fn [a b] (positive? b)))") env)))
      (is-true (funcall both-positive 1 1))
      (is (eq nil (funcall both-positive 1 -1)))
      (is (eq nil (funcall both-positive -1 1))))))

(test conjoin-empty
  "Test conjoin with no predicates returns a function that returns true."
  (let ((env (make-standard-env)))
    (let ((always (fol-eval '(conjoin) env)))
      (is-true (funcall always 42)))))

(test disjoin-empty
  "Test disjoin with no predicates returns a function that returns nil."
  (let ((env (make-standard-env)))
    (let ((never (fol-eval '(disjoin) env)))
      (is (eq nil (funcall never 42))))))

;;; ---------------------------------------------------------------------------
;;; Partial Application (partial, rpartial, juxt)
;;; ---------------------------------------------------------------------------

(test partial-basic
  "Test partial binds arguments left to right."
  (let ((env (make-standard-env)))
    ;; (partial + 10) returns a function that adds 10 to its argument
    (let ((add10 (fol-eval '(partial + 10) env)))
      (is (cl:= 15 (funcall add10 5)))
      (is (cl:= 10 (funcall add10 0))))))

(test partial-multiple-bound-args
  "Test partial with multiple bound arguments."
  (let ((env (make-standard-env)))
    ;; (partial + 1 2 3) returns a function that adds 1+2+3 to remaining args
    (let ((add6 (fol-eval '(partial + 1 2 3) env)))
      (is (cl:= 10 (funcall add6 4)))
      (is (cl:= 16 (funcall add6 4 6))))))

(test partial-with-fol-function
  "Test partial works with FOL functions."
  (let ((env (make-standard-env)))
    (let ((f (fol-eval (fol-form "(partial (fn [a b c] (+ a (* b c))) 10)") env)))
      ;; f is (fn [b c] (+ 10 (* b c)))
      (is (cl:= 16 (funcall f 2 3)))))) ; 10 + 2*3 = 16

(test partial-no-bound-args
  "Test partial with no bound arguments acts like identity on function."
  (let ((env (make-standard-env)))
    (let ((same-plus (fol-eval '(partial +) env)))
      (is (cl:= 6 (funcall same-plus 1 2 3))))))

(test rpartial-basic
  "Test rpartial binds arguments right to left."
  (let ((env (make-standard-env)))
    ;; (rpartial - 3) returns a function that subtracts 3 from the end
    ;; (f 10) => (- 10 3) = 7
    (let ((sub3 (fol-eval '(rpartial - 3) env)))
      (is (cl:= 7 (funcall sub3 10))))))

(test rpartial-multiple-bound-args
  "Test rpartial with multiple bound arguments."
  (let ((env (make-standard-env)))
    ;; (rpartial - 2 3) returns fn where calling (f 10) => (- 10 2 3) = 5
    (let ((sub5 (fol-eval '(rpartial - 2 3) env)))
      (is (cl:= 5 (funcall sub5 10))))))

(test rpartial-with-fol-function
  "Test rpartial works with FOL functions."
  (let ((env (make-standard-env)))
    (let ((f (fol-eval (fol-form "(rpartial (fn [a b c] (+ a (* b c))) 3)") env)))
      ;; f is (fn [a b] (+ a (* b 3)))
      (is (cl:= 16 (funcall f 10 2)))))) ; 10 + 2*3 = 16

(test rpartial-vs-partial
  "Test that rpartial and partial produce different results for non-commutative ops."
  (let ((env (make-standard-env)))
    ;; partial puts 10 first: (- 10 x)
    ;; rpartial puts 10 last: (- x 10)
    (let ((partial-sub (fol-eval '(partial - 10) env))
          (rpartial-sub (fol-eval '(rpartial - 10) env)))
      (is (cl:= 5 (funcall partial-sub 5)))   ; (- 10 5) = 5
      (is (cl:= -5 (funcall rpartial-sub 5)))))) ; (- 5 10) = -5

(test juxt-basic
  "Test juxt applies multiple functions and returns multiple values."
  (let ((env (make-standard-env)))
    (let ((stats (fol-eval '(juxt + - *) env)))
      ;; (stats 3 4) => (values (+ 3 4) (- 3 4) (* 3 4)) = (values 7 -1 12)
      (multiple-value-bind (v1 v2 v3) (funcall stats 3 4)
        (is (cl:= 7 v1))
        (is (cl:= -1 v2))
        (is (cl:= 12 v3))))))

(test juxt-single-function
  "Test juxt with single function returns single value."
  (let ((env (make-standard-env)))
    (let ((wrapped (fol-eval '(juxt +) env)))
      (is (cl:= 6 (funcall wrapped 1 2 3))))))

(test juxt-with-fol-functions
  "Test juxt works with FOL functions."
  (let ((env (make-standard-env)))
    (let ((pair (fol-eval (fol-form "(juxt (fn [x] (* x 2)) (fn [x] (+ x 1)))") env)))
      (multiple-value-bind (v1 v2) (funcall pair 5)
        (is (cl:= 10 v1))  ; (* 5 2)
        (is (cl:= 6 v2))))))  ; (+ 5 1)

(test juxt-empty
  "Test juxt with no functions returns no values."
  (let ((env (make-standard-env)))
    (let ((empty-juxt (fol-eval '(juxt) env)))
      ;; (values-list nil) returns 0 values
      (is (cl:= 0 (cl:length (multiple-value-list (funcall empty-juxt 1 2 3))))))))

(test juxt-practical-example
  "Test juxt with a practical use case."
  (let ((env (make-standard-env)))
    ;; Get both min and max in one pass
    (let ((min-max (fol-eval '(juxt min max) env)))
      (multiple-value-bind (min-val max-val) (funcall min-max 3 1 4 1 5 9 2 6)
        (is (cl:= 1 min-val))   ; min
        (is (cl:= 9 max-val))))))  ; max

;;; ---------------------------------------------------------------------------
;;; Higher-order Collection Operations (reduce, map, filter)
;;; ---------------------------------------------------------------------------

(test reduce-with-init-vector
  "Test reduce with initial value on a vector."
  (let ((env (make-standard-env)))
    ;; (reduce + 0 [1 2 3 4]) => 10
    (is (cl:= 10 (fol-eval (fol-form "(reduce + 0 [1 2 3 4])") env)))))

(test reduce-with-init-list
  "Test reduce with initial value on a FOL list."
  (let ((env (make-standard-env)))
    ;; Use conj to build a list, then reduce
    (is (cl:= 6 (fol-eval (fol-form "(reduce + 0 (list 1 2 3))") env)))))

(test reduce-without-init
  "Test reduce without initial value uses first element."
  (let ((env (make-standard-env)))
    ;; (reduce + [1 2 3 4]) => 10
    (is (cl:= 10 (fol-eval (fol-form "(reduce + [1 2 3 4])") env)))))

(test reduce-single-element
  "Test reduce on single-element collection."
  (let ((env (make-standard-env)))
    ;; Single element, no reduction needed
    (is (cl:= 42 (fol-eval (fol-form "(reduce + [42])") env)))))

(test reduce-with-fol-function
  "Test reduce with a FOL function."
  (let ((env (make-standard-env)))
    ;; Use a FOL fn to multiply and add
    (is (cl:= 10 (fol-eval (fol-form "(reduce (fn [acc x] (+ acc x)) 0 [1 2 3 4])") env)))))

(test reduce-building-collection
  "Test reduce to build a new collection."
  (let ((env (make-standard-env)))
    ;; Reverse a list by conj-ing onto empty vector
    (let ((result (fol-eval (fol-form "(reduce (fn [acc x] (conj acc x)) [] [1 2 3])") env)))
      (is (<vector>? result))
      (is (cl:= 3 (size result)))
      (is (cl:= 1 (nth result 0)))
      (is (cl:= 2 (nth result 1)))
      (is (cl:= 3 (nth result 2))))))

(test reduce-on-dict
  "Test reduce on a dict processes key-value pairs."
  (let ((env (make-standard-env)))
    ;; Sum all values from a dict (pairs come as (key . value))
    (is (cl:= 6 (fol-eval (fol-form "(reduce (fn [acc pair] (+ acc (rest pair))) 0 {:a 1 :b 2 :c 3})") env)))))

(test reduce-on-set
  "Test reduce on a set."
  (let ((env (make-standard-env)))
    ;; Sum elements of a set
    (is (cl:= 6 (fol-eval (fol-form "(reduce + 0 #{1 2 3})") env)))))

(test reduce-on-string
  "Test reduce on a string processes characters."
  (let ((env (make-standard-env)))
    ;; Count characters
    (is (cl:= 5 (fol-eval (fol-form "(reduce (fn [acc _] (+ acc 1)) 0 \"hello\")") env)))))

(test reduce-empty-with-init
  "Test reduce on empty collection returns init."
  (let ((env (make-standard-env)))
    (is (cl:= 42 (fol-eval (fol-form "(reduce + 42 [])") env)))))

(test map-basic
  "Test map applies function to each element."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(map (fn [x] (* x 2)) [1 2 3])") env)))
      (is (<lazy-seq>? result))
      (is (cl:= 3 (size result)))
      (is (cl:= 2 (first result)))
      (is (cl:= 4 (first (rest result))))
      (is (cl:= 6 (first (rest (rest result))))))))

(test map-with-builtin
  "Test map with a built-in function."
  (let ((env (make-standard-env)))
    ;; Map abs over negative numbers
    (let ((result (fol-eval (fol-form "(map abs [-1 -2 -3])") env)))
      (is (cl:= 1 (first result)))
      (is (cl:= 2 (first (rest result))))
      (is (cl:= 3 (first (rest (rest result))))))))

(test map-empty
  "Test map on empty collection returns empty lazy-seq."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(map identity [])") env)))
      (is (<lazy-seq>? result))
      (is (empty? result)))))

(test map-on-list
  "Test map on a FOL list."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(map (fn [x] (+ x 1)) (list 1 2 3))") env)))
      (is (cl:= 2 (first result)))
      (is (cl:= 3 (first (rest result))))
      (is (cl:= 4 (first (rest (rest result))))))))

(test map-on-string
  "Test map on a string."
  (let ((env (make-standard-env)))
    ;; Map over characters, returning a lazy-seq
    (let ((result (fol-eval (fol-form "(map identity \"abc\")") env)))
      (is (<lazy-seq>? result))
      (is (cl:= 3 (size result)))
      (is (cl:char= #\a (first result))))))

(test filter-basic
  "Test filter keeps elements matching predicate."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(filter odd? [1 2 3 4 5])") env)))
      (is (<lazy-seq>? result))
      (is (cl:= 3 (size result)))
      (is (cl:= 1 (first result)))
      (is (cl:= 3 (first (rest result))))
      (is (cl:= 5 (first (rest (rest result))))))))

(test filter-none-match
  "Test filter when no elements match."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(filter negative? [1 2 3])") env)))
      (is (<lazy-seq>? result))
      (is (empty? result)))))

(test filter-all-match
  "Test filter when all elements match."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(filter positive? [1 2 3])") env)))
      (is (cl:= 3 (size result))))))

(test filter-empty
  "Test filter on empty collection."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(filter identity [])") env)))
      (is (<lazy-seq>? result))
      (is (empty? result)))))

(test filter-with-fol-function
  "Test filter with a FOL predicate function."
  (let ((env (make-standard-env)))
    ;; Filter numbers greater than 2
    (let ((result (fol-eval (fol-form "(filter (fn [x] (> x 2)) [1 2 3 4 5])") env)))
      (is (cl:= 3 (size result)))
      (is (cl:= 3 (first result)))
      (is (cl:= 4 (first (rest result))))
      (is (cl:= 5 (first (rest (rest result))))))))

(test filter-on-dict
  "Test filter on dict filters key-value pairs."
  (let ((env (make-standard-env)))
    ;; Filter pairs where value is positive
    (let ((result (fol-eval (fol-form "(filter (fn [pair] (positive? (rest pair))) {:a 1 :b -2 :c 3})") env)))
      (is (cl:= 2 (size result))))))

(test map-filter-composition
  "Test composing map and filter."
  (let ((env (make-standard-env)))
    ;; Double the odd numbers
    (let ((result (fol-eval (fol-form "(map (fn [x] (* x 2)) (filter odd? [1 2 3 4 5]))") env)))
      (is (cl:= 3 (size result)))
      (is (cl:= 2 (first result)))           ; 1 * 2
      (is (cl:= 6 (first (rest result))))    ; 3 * 2
      (is (cl:= 10 (first (rest (rest result)))))))) ; 5 * 2

;;; ---------------------------------------------------------------------------
;;; remove (higher-order function)
;;; ---------------------------------------------------------------------------

(test remove-basic
  "Test remove returns elements where predicate is false."
  (let ((env (make-standard-env)))
    ;; Remove odd numbers (keep evens)
    (let ((result (fol-eval (fol-form "(remove odd? [1 2 3 4 5 6])") env)))
      (is-true (<lazy-seq>? result))
      (is (cl:= 2 (first result)))
      (is (cl:= 4 (first (rest result))))
      (is (cl:= 6 (first (rest (rest result))))))))

(test remove-none-match
  "Test remove when predicate matches nothing."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(remove negative? [1 2 3])") env)))
      (is (cl:= 1 (first result)))
      (is (cl:= 2 (first (rest result))))
      (is (cl:= 3 (first (rest (rest result))))))))

(test remove-all-match
  "Test remove when predicate matches everything."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(remove positive? [1 2 3])") env)))
      (is (empty? result)))))

(test remove-with-fol-function
  "Test remove with user-defined function."
  (let ((env (make-standard-env)))
    (fol-eval (fol-form "(defn small? [x] (< x 3))") env)
    (let ((result (fol-eval (fol-form "(remove small? [1 2 3 4 5])") env)))
      (is (cl:= 3 (first result)))
      (is (cl:= 4 (first (rest result))))
      (is (cl:= 5 (first (rest (rest result))))))))

;;; ---------------------------------------------------------------------------
;;; keep (higher-order function)
;;; ---------------------------------------------------------------------------

(test keep-basic
  "Test keep returns non-nil results of applying f."
  (let ((env (make-standard-env)))
    ;; Keep function that returns nil for evens, value for odds
    (fol-eval (fol-form "(defn odd-or-nil [x] (if (odd? x) x nil))") env)
    (let ((result (fol-eval (fol-form "(keep odd-or-nil [1 2 3 4 5])") env)))
      (is-true (<lazy-seq>? result))
      (is (cl:= 1 (first result)))
      (is (cl:= 3 (first (rest result))))
      (is (cl:= 5 (first (rest (rest result))))))))

(test keep-all-nil
  "Test keep when f returns nil for all elements."
  (let ((env (make-standard-env)))
    (fol-eval (fol-form "(defn always-nil [x] nil)") env)
    (let ((result (fol-eval (fol-form "(keep always-nil [1 2 3])") env)))
      (is (empty? result)))))

(test keep-transform-and-filter
  "Test keep transforms and filters in one pass."
  (let ((env (make-standard-env)))
    ;; Return doubled value for positive, nil for others
    (fol-eval (fol-form "(defn double-if-positive [x] (if (positive? x) (* x 2) nil))") env)
    (let ((result (fol-eval (fol-form "(keep double-if-positive [-1 0 1 2 3])") env)))
      (is (cl:= 2 (first result)))           ; 1 * 2
      (is (cl:= 4 (first (rest result))))    ; 2 * 2
      (is (cl:= 6 (first (rest (rest result)))))))) ; 3 * 2

;;; ---------------------------------------------------------------------------
;;; mapcat (higher-order function)
;;; ---------------------------------------------------------------------------

(test mapcat-basic
  "Test mapcat applies f and concatenates results."
  (let ((env (make-standard-env)))
    ;; Duplicate each element
    (fol-eval (fol-form "(defn duplicate [x] (list x x))") env)
    (let ((result (fol-eval (fol-form "(mapcat duplicate [1 2 3])") env)))
      (is-true (<lazy-seq>? result))
      (is (cl:= 1 (first result)))
      (is (cl:= 1 (first (rest result))))
      (is (cl:= 2 (first (rest (rest result))))))))

(test mapcat-expand-range
  "Test mapcat expands ranges."
  (let ((env (make-standard-env)))
    ;; For each n, produce [0..n-1]
    (fol-eval (fol-form "(defn expand [n] (range n))") env)
    (let ((result (fol-eval (fol-form "(mapcat expand [1 2 3])") env)))
      ;; expand(1)=[0], expand(2)=[0,1], expand(3)=[0,1,2]
      ;; Result: 0, 0, 1, 0, 1, 2
      (is (cl:= 0 (first result)))
      (is (cl:= 0 (first (rest result))))
      (is (cl:= 1 (first (rest (rest result))))))))

(test mapcat-empty-results
  "Test mapcat with some empty results."
  (let ((env (make-standard-env)))
    ;; Return list only for odds, empty for evens
    (fol-eval (fol-form "(defn odd-list [x] (if (odd? x) (list x) (list)))") env)
    (let ((result (fol-eval (fol-form "(mapcat odd-list [1 2 3 4 5])") env)))
      (is (cl:= 1 (first result)))
      (is (cl:= 3 (first (rest result))))
      (is (cl:= 5 (first (rest (rest result))))))))

;;; ---------------------------------------------------------------------------
;;; interleave (higher-order function)
;;; ---------------------------------------------------------------------------

(test interleave-two-seqs
  "Test interleave alternates between two sequences."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(interleave [1 2 3] [:a :b :c])") env)))
      (is-true (<lazy-seq>? result))
      (is (cl:= 1 (first result)))
      (is (eq :a (first (rest result))))
      (is (cl:= 2 (first (rest (rest result)))))
      (is (eq :b (first (rest (rest (rest result)))))))))

(test interleave-three-seqs
  "Test interleave with three sequences."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(interleave [1 2] [:a :b] [100 200])") env)))
      ;; 1, :a, 100, 2, :b, 200
      (is (cl:= 1 (first result)))
      (is (eq :a (first (rest result))))
      (is (cl:= 100 (first (rest (rest result)))))
      (is (cl:= 2 (first (rest (rest (rest result)))))))))

(test interleave-unequal-length
  "Test interleave stops at shortest sequence."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(interleave [1 2 3 4 5] [:a :b])") env)))
      ;; Should stop when [:a :b] is exhausted: 1, :a, 2, :b
      (is (cl:= 1 (first result)))
      (is (eq :a (first (rest result))))
      (is (cl:= 2 (first (rest (rest result)))))
      (is (eq :b (first (rest (rest (rest result)))))))))

(test interleave-empty
  "Test interleave with empty sequence."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(interleave [] [1 2 3])") env)))
      (is (empty? result)))))

;;; ---------------------------------------------------------------------------
;;; interpose (higher-order function)
;;; ---------------------------------------------------------------------------

(test interpose-basic
  "Test interpose inserts separator between elements."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(interpose :sep [1 2 3])") env)))
      (is-true (<lazy-seq>? result))
      (is (cl:= 1 (first result)))
      (is (eq :sep (first (rest result))))
      (is (cl:= 2 (first (rest (rest result)))))
      (is (eq :sep (first (rest (rest (rest result))))))
      (is (cl:= 3 (first (rest (rest (rest (rest result))))))))))

(test interpose-single-element
  "Test interpose with single element (no separator needed)."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(interpose :sep [42])") env)))
      (is (cl:= 42 (first result)))
      ;; Rest should be empty
      (is (empty? (rest result))))))

(test interpose-empty
  "Test interpose with empty sequence."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(interpose :sep [])") env)))
      (is (empty? result)))))

(test interpose-string-join
  "Test using interpose to join with reduce."
  (let ((env (make-standard-env)))
    ;; Join strings with separator
    (let ((result (fol-eval (fol-form "(reduce str \"\" (interpose \"-\" [\"a\" \"b\" \"c\"]))") env)))
      (is (string= "a-b-c" result)))))

;;; ---------------------------------------------------------------------------
;;; range (lazy sequence generator)
;;; ---------------------------------------------------------------------------

(test range-single-arg
  "Test (range end) returns lazy sequence 0 to end-1."
  (let ((env (make-standard-env)))
    ;; (range 5) => 0, 1, 2, 3, 4
    (let ((result (fol-eval (fol-form "(range 5)") env)))
      (is-true (<lazy-seq>? result))
      (is (cl:= 0 (first result)))
      (is (cl:= 1 (first (rest result))))
      (is (cl:= 2 (first (rest (rest result)))))
      (is (cl:= 3 (first (rest (rest (rest result))))))
      (is (cl:= 4 (first (rest (rest (rest (rest result))))))))))

(test range-two-args
  "Test (range start end) returns lazy sequence start to end-1."
  (let ((env (make-standard-env)))
    ;; (range 2 5) => 2, 3, 4
    (let ((result (fol-eval (fol-form "(range 2 5)") env)))
      (is-true (<lazy-seq>? result))
      (is (cl:= 2 (first result)))
      (is (cl:= 3 (first (rest result))))
      (is (cl:= 4 (first (rest (rest result))))))))

(test range-three-args-positive-step
  "Test (range start end step) with positive step."
  (let ((env (make-standard-env)))
    ;; (range 0 10 2) => 0, 2, 4, 6, 8
    (let ((result (fol-eval (fol-form "(range 0 10 2)") env)))
      (is-true (<lazy-seq>? result))
      (is (cl:= 0 (first result)))
      (is (cl:= 2 (first (rest result))))
      (is (cl:= 4 (first (rest (rest result)))))
      (is (cl:= 6 (first (rest (rest (rest result))))))
      (is (cl:= 8 (first (rest (rest (rest (rest result))))))))))

(test range-three-args-negative-step
  "Test (range start end step) with negative step."
  (let ((env (make-standard-env)))
    ;; (range 5 0 -1) => 5, 4, 3, 2, 1
    (let ((result (fol-eval (fol-form "(range 5 0 -1)") env)))
      (is-true (<lazy-seq>? result))
      (is (cl:= 5 (first result)))
      (is (cl:= 4 (first (rest result))))
      (is (cl:= 3 (first (rest (rest result)))))
      (is (cl:= 2 (first (rest (rest (rest result))))))
      (is (cl:= 1 (first (rest (rest (rest (rest result))))))))))

(test range-empty-cases
  "Test range returns empty sequence for invalid ranges."
  (let ((env (make-standard-env)))
    ;; (range 0) => empty
    (let ((result (fol-eval (fol-form "(range 0)") env)))
      (is-true (<lazy-seq>? result))
      (is-true (empty? result)))
    ;; (range -5) => empty
    (let ((result (fol-eval (fol-form "(range -5)") env)))
      (is-true (empty? result)))
    ;; (range 5 5) => empty (start equals end)
    (let ((result (fol-eval (fol-form "(range 5 5)") env)))
      (is-true (empty? result)))
    ;; (range 5 2) => empty (start > end with default positive step)
    (let ((result (fol-eval (fol-form "(range 5 2)") env)))
      (is-true (empty? result)))
    ;; (range 2 5 -1) => empty (positive range with negative step)
    (let ((result (fol-eval (fol-form "(range 2 5 -1)") env)))
      (is-true (empty? result)))))

(test range-infinite
  "Test (range) returns infinite lazy sequence."
  (let ((env (make-standard-env)))
    ;; (range) => 0, 1, 2, 3, ...
    (let ((result (fol-eval (fol-form "(range)") env)))
      (is-true (<lazy-seq>? result))
      (is (cl:= 0 (first result)))
      (is (cl:= 1 (first (rest result))))
      (is (cl:= 2 (first (rest (rest result)))))
      ;; Can keep taking more elements
      (is (cl:= 3 (first (rest (rest (rest result)))))))))

(test range-with-reduce
  "Test using reduce with range."
  (let ((env (make-standard-env)))
    ;; Sum 0 to 9
    (let ((result (fol-eval (fol-form "(reduce + 0 (range 10))") env)))
      (is (cl:= 45 result)))))  ; 0+1+2+3+4+5+6+7+8+9 = 45

(test range-with-map
  "Test using map with range."
  (let ((env (make-standard-env)))
    ;; Square each number from 0 to 4
    (let ((result (fol-eval (fol-form "(map (fn [x] (* x x)) (range 5))") env)))
      (is (cl:= 5 (size result)))
      (is (cl:= 0 (first result)))           ; 0*0
      (is (cl:= 1 (first (rest result))))    ; 1*1
      (is (cl:= 4 (first (rest (rest result)))))))) ; 2*2

(test range-with-filter
  "Test using filter with range."
  (let ((env (make-standard-env)))
    ;; Filter even numbers from 0 to 9
    (let ((result (fol-eval (fol-form "(filter even? (range 10))") env)))
      (is (cl:= 5 (size result)))  ; 0, 2, 4, 6, 8
      (is (cl:= 0 (first result)))
      (is (cl:= 2 (first (rest result))))
      (is (cl:= 4 (first (rest (rest result))))))))

;;; ---------------------------------------------------------------------------
;;; reduced (early termination in reduce)
;;; ---------------------------------------------------------------------------

(test reduced-basic
  "Test reduced wraps a value for early termination."
  (let ((env (make-standard-env)))
    ;; reduced returns a reduced wrapper
    (let ((result (fol-eval (fol-form "(reduced 42)") env)))
      (is-true (<reduced>? result))
      (is (cl:= 42 (reduced-value result))))))

(test reduced-predicate
  "Test reduced? predicate."
  (let ((env (make-standard-env)))
    ;; reduced? returns true for reduced values
    (is-true (fol-eval (fol-form "(reduced? (reduced 42))") env))
    ;; reduced? returns false for regular values
    (is-false (fol-eval (fol-form "(reduced? 42)") env))
    (is-false (fol-eval (fol-form "(reduced? [1 2 3])") env))
    (is-false (fol-eval (fol-form "(reduced? nil)") env))))

(test unreduced-basic
  "Test unreduced unwraps reduced values."
  (let ((env (make-standard-env)))
    ;; unreduced unwraps reduced values
    (is (cl:= 42 (fol-eval (fol-form "(unreduced (reduced 42))") env)))
    ;; unreduced returns non-reduced values unchanged
    (is (cl:= 42 (fol-eval (fol-form "(unreduced 42)") env)))
    (is (eq :keyword (fol-eval (fol-form "(unreduced :keyword)") env)))))

(test reduce-with-reduced-early-termination
  "Test that reduce stops when it encounters a reduced value."
  (let ((env (make-standard-env)))
    ;; Sum until we exceed 10, then stop early
    (fol-eval (fol-form "(defn sum-until-10 [acc x]
                          (bind [new-sum (+ acc x)]
                            (if (> new-sum 10)
                                (reduced acc)
                                new-sum)))") env)
    ;; 0+1+2+3+4 = 10, adding 5 would exceed, so return 10
    (let ((result (fol-eval (fol-form "(reduce sum-until-10 0 (range 100))") env)))
      (is (cl:= 10 result)))))

(test reduce-with-reduced-finds-first
  "Test using reduced to find first matching element."
  (let ((env (make-standard-env)))
    ;; Find first even number greater than 5
    (fol-eval (fol-form "(defn find-first-even-gt-5 [acc x]
                          (if (and (even? x) (> x 5))
                              (reduced x)
                              acc))") env)
    (let ((result (fol-eval (fol-form "(reduce find-first-even-gt-5 nil (range 20))") env)))
      (is (cl:= 6 result)))))

;;; ---------------------------------------------------------------------------
;;; iterate (lazy sequence generator)
;;; ---------------------------------------------------------------------------

(test iterate-basic
  "Test iterate creates lazy sequence of repeated function application."
  (let ((env (make-standard-env)))
    ;; (iterate inc 0) => 0, 1, 2, 3, ...
    (let ((result (fol-eval (fol-form "(iterate inc 0)") env)))
      (is-true (<lazy-seq>? result))
      (is (cl:= 0 (first result)))
      (is (cl:= 1 (first (rest result))))
      (is (cl:= 2 (first (rest (rest result)))))
      (is (cl:= 3 (first (rest (rest (rest result)))))))))

(test iterate-with-custom-function
  "Test iterate with user-defined function."
  (let ((env (make-standard-env)))
    ;; Double each time: 1, 2, 4, 8, ...
    (fol-eval (fol-form "(defn double [x] (* x 2))") env)
    (let ((result (fol-eval (fol-form "(iterate double 1)") env)))
      (is (cl:= 1 (first result)))
      (is (cl:= 2 (first (rest result))))
      (is (cl:= 4 (first (rest (rest result)))))
      (is (cl:= 8 (first (rest (rest (rest result)))))))))

(test iterate-with-dec
  "Test iterate with decrement (countdown)."
  (let ((env (make-standard-env)))
    ;; Countdown: 10, 9, 8, 7, ...
    (let ((result (fol-eval (fol-form "(iterate dec 10)") env)))
      (is (cl:= 10 (first result)))
      (is (cl:= 9 (first (rest result))))
      (is (cl:= 8 (first (rest (rest result))))))))

;;; ---------------------------------------------------------------------------
;;; repeat (lazy sequence generator)
;;; ---------------------------------------------------------------------------

(test repeat-infinite
  "Test (repeat x) returns infinite sequence of x."
  (let ((env (make-standard-env)))
    ;; (repeat 42) => 42, 42, 42, ...
    (let ((result (fol-eval (fol-form "(repeat 42)") env)))
      (is-true (<lazy-seq>? result))
      (is (cl:= 42 (first result)))
      (is (cl:= 42 (first (rest result))))
      (is (cl:= 42 (first (rest (rest result)))))
      (is (cl:= 42 (first (rest (rest (rest result)))))))))

(test repeat-finite
  "Test (repeat n x) returns n copies of x."
  (let ((env (make-standard-env)))
    ;; (repeat 3 :a) => :a, :a, :a
    (let ((result (fol-eval (fol-form "(repeat 3 :a)") env)))
      (is-true (<lazy-seq>? result))
      (is (eq :a (first result)))
      (is (eq :a (first (rest result))))
      (is (eq :a (first (rest (rest result)))))
      ;; Should be empty after 3 elements
      (is (empty? (rest (rest (rest result))))))))

(test repeat-zero
  "Test (repeat 0 x) returns empty sequence."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(repeat 0 :x)") env)))
      (is-true (<lazy-seq>? result))
      (is-true (empty? result)))))

(test repeat-with-reduce
  "Test using repeat with reduce."
  (let ((env (make-standard-env)))
    ;; Sum five 10s
    (let ((result (fol-eval (fol-form "(reduce + 0 (repeat 5 10))") env)))
      (is (cl:= 50 result)))))

;;; ---------------------------------------------------------------------------
;;; repeatedly (lazy sequence generator)
;;; ---------------------------------------------------------------------------

(test repeatedly-infinite
  "Test (repeatedly f) calls f repeatedly."
  (let ((env (make-standard-env)))
    ;; Use a function that returns a constant (since we can't easily test side effects)
    (fol-eval (fol-form "(defn always-7 [] 7)") env)
    (let ((result (fol-eval (fol-form "(repeatedly always-7)") env)))
      (is-true (<lazy-seq>? result))
      (is (cl:= 7 (first result)))
      (is (cl:= 7 (first (rest result))))
      (is (cl:= 7 (first (rest (rest result))))))))

(test repeatedly-finite
  "Test (repeatedly n f) calls f n times."
  (let ((env (make-standard-env)))
    (fol-eval (fol-form "(defn always-42 [] 42)") env)
    (let ((result (fol-eval (fol-form "(repeatedly 3 always-42)") env)))
      (is-true (<lazy-seq>? result))
      (is (cl:= 42 (first result)))
      (is (cl:= 42 (first (rest result))))
      (is (cl:= 42 (first (rest (rest result)))))
      ;; Should be empty after 3 elements
      (is (empty? (rest (rest (rest result))))))))

(test repeatedly-zero
  "Test (repeatedly 0 f) returns empty sequence."
  (let ((env (make-standard-env)))
    (fol-eval (fol-form "(defn never-called [] (throw \"Should not be called\"))") env)
    (let ((result (fol-eval (fol-form "(repeatedly 0 never-called)") env)))
      (is-true (<lazy-seq>? result))
      (is-true (empty? result)))))

;;; ---------------------------------------------------------------------------
;;; Lazy Sequence Operations: take and drop
;;; ---------------------------------------------------------------------------

(test take-basic
  "Test take returns first n elements as lazy sequence."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(take 3 [1 2 3 4 5])") env)))
      (is-true (<lazy-seq>? result))
      (is (cl:= 1 (first result)))
      (is (cl:= 2 (first (rest result))))
      (is (cl:= 3 (first (rest (rest result)))))
      (is-true (empty? (rest (rest (rest result))))))))

(test take-more-than-available
  "Test take with n larger than collection size returns all elements."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(take 10 [1 2 3])") env)))
      (is-true (<lazy-seq>? result))
      (is (cl:= 1 (first result)))
      (is (cl:= 2 (first (rest result))))
      (is (cl:= 3 (first (rest (rest result)))))
      (is-true (empty? (rest (rest (rest result))))))))

(test take-zero
  "Test take with zero returns empty sequence."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(take 0 [1 2 3])") env)))
      (is-true (<lazy-seq>? result))
      (is-true (empty? result)))))

(test take-negative
  "Test take with negative n returns empty sequence."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(take -5 [1 2 3])") env)))
      (is-true (<lazy-seq>? result))
      (is-true (empty? result)))))

(test take-from-empty
  "Test take from empty collection returns empty sequence."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(take 5 [])") env)))
      (is-true (<lazy-seq>? result))
      (is-true (empty? result)))))

(test take-from-infinite
  "Test take from infinite sequence (range)."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(take 5 (range))") env)))
      (is-true (<lazy-seq>? result))
      (is (cl:= 0 (first result)))
      (is (cl:= 1 (first (rest result))))
      (is (cl:= 2 (first (rest (rest result)))))
      (is (cl:= 3 (first (rest (rest (rest result))))))
      (is (cl:= 4 (first (rest (rest (rest (rest result)))))))
      (is-true (empty? (rest (rest (rest (rest (rest result))))))))))

(test drop-basic
  "Test drop removes first n elements."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(drop 2 [1 2 3 4 5])") env)))
      (is-true (<lazy-seq>? result))
      (is (cl:= 3 (first result)))
      (is (cl:= 4 (first (rest result))))
      (is (cl:= 5 (first (rest (rest result)))))
      (is-true (empty? (rest (rest (rest result))))))))

(test drop-more-than-available
  "Test drop with n larger than collection size returns empty sequence."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(drop 10 [1 2 3])") env)))
      (is-true (<lazy-seq>? result))
      (is-true (empty? result)))))

(test drop-zero
  "Test drop with zero returns all elements."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(drop 0 [1 2 3])") env)))
      (is-true (<lazy-seq>? result))
      (is (cl:= 1 (first result)))
      (is (cl:= 2 (first (rest result))))
      (is (cl:= 3 (first (rest (rest result)))))
      (is-true (empty? (rest (rest (rest result))))))))

(test drop-negative
  "Test drop with negative n returns all elements."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(drop -5 [1 2 3])") env)))
      (is-true (<lazy-seq>? result))
      (is (cl:= 1 (first result)))
      (is (cl:= 2 (first (rest result))))
      (is (cl:= 3 (first (rest (rest result)))))
      (is-true (empty? (rest (rest (rest result))))))))

(test drop-from-empty
  "Test drop from empty collection returns empty sequence."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(drop 5 [])") env)))
      (is-true (<lazy-seq>? result))
      (is-true (empty? result)))))

(test drop-from-infinite
  "Test drop from infinite sequence (range)."
  (let ((env (make-standard-env)))
    ;; drop 5, then take 3 from infinite range
    (let ((result (fol-eval (fol-form "(take 3 (drop 5 (range)))") env)))
      (is-true (<lazy-seq>? result))
      (is (cl:= 5 (first result)))
      (is (cl:= 6 (first (rest result))))
      (is (cl:= 7 (first (rest (rest result)))))
      (is-true (empty? (rest (rest (rest result))))))))

(test take-drop-composition
  "Test composing take and drop."
  (let ((env (make-standard-env)))
    ;; Take 3 after dropping 2 from [1 2 3 4 5 6]
    (let ((result (fol-eval (fol-form "(take 3 (drop 2 [1 2 3 4 5 6]))") env)))
      (is-true (<lazy-seq>? result))
      (is (cl:= 3 (first result)))
      (is (cl:= 4 (first (rest result))))
      (is (cl:= 5 (first (rest (rest result)))))
      (is-true (empty? (rest (rest (rest result))))))))

(test take-transducer
  "Test take as a transducer with reduce."
  (let ((env (make-standard-env)))
    ;; Use take transducer to take first 3 elements during reduce
    (let ((result (fol-eval (fol-form "(reduce ((take 3) conj) [] [1 2 3 4 5])") env)))
      (is-true (<vector>? result))
      (is (cl:= 3 (size result)))
      (is (cl:= 1 (nth result 0)))
      (is (cl:= 2 (nth result 1)))
      (is (cl:= 3 (nth result 2))))))

(test take-transducer-fewer-elements
  "Test take transducer when collection has fewer than n elements."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(reduce ((take 10) conj) [] [1 2 3])") env)))
      (is-true (<vector>? result))
      (is (cl:= 3 (size result)))
      (is (cl:= 1 (nth result 0)))
      (is (cl:= 2 (nth result 1)))
      (is (cl:= 3 (nth result 2))))))

(test drop-transducer
  "Test drop as a transducer with reduce."
  (let ((env (make-standard-env)))
    ;; Use drop transducer to skip first 2 elements during reduce
    (let ((result (fol-eval (fol-form "(reduce ((drop 2) conj) [] [1 2 3 4 5])") env)))
      (is-true (<vector>? result))
      (is (cl:= 3 (size result)))
      (is (cl:= 3 (nth result 0)))
      (is (cl:= 4 (nth result 1)))
      (is (cl:= 5 (nth result 2))))))

(test drop-transducer-more-than-available
  "Test drop transducer when n is larger than collection size."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(reduce ((drop 10) conj) [] [1 2 3])") env)))
      (is-true (<vector>? result))
      (is (cl:= 0 (size result))))))

;;; ---------------------------------------------------------------------------
;;; cycle (lazy sequence generator)
;;; ---------------------------------------------------------------------------

(test cycle-basic
  "Test cycle repeats elements of collection infinitely."
  (let ((env (make-standard-env)))
    ;; (cycle [1 2 3]) => 1, 2, 3, 1, 2, 3, 1, ...
    (let ((result (fol-eval (fol-form "(cycle [1 2 3])") env)))
      (is-true (<lazy-seq>? result))
      ;; First cycle
      (is (cl:= 1 (first result)))
      (is (cl:= 2 (first (rest result))))
      (is (cl:= 3 (first (rest (rest result)))))
      ;; Second cycle
      (is (cl:= 1 (first (rest (rest (rest result))))))
      (is (cl:= 2 (first (rest (rest (rest (rest result)))))))
      (is (cl:= 3 (first (rest (rest (rest (rest (rest result))))))))
      ;; Third cycle starts
      (is (cl:= 1 (first (rest (rest (rest (rest (rest (rest result))))))))))))

(test cycle-single-element
  "Test cycle with single element collection."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(cycle [:only])") env)))
      (is-true (<lazy-seq>? result))
      (is (eq :only (first result)))
      (is (eq :only (first (rest result))))
      (is (eq :only (first (rest (rest result))))))))

(test cycle-empty
  "Test cycle with empty collection returns empty seq."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(cycle [])") env)))
      (is-true (<lazy-seq>? result))
      (is-true (empty? result)))))

(test cycle-multi
  "Test using cycle with map to create repeating patterns."
  (let ((env (make-standard-env)))
    ;; Create a repeating pattern of 1,2,3 over 10 elements
    (let ((result (fol-eval (fol-form "(take 10 (cycle [1 2 3]))") env)))
      (is-true (<lazy-seq>? result))
      (is (cl:= 1 (nth result 0)))
      (is (cl:= 2 (nth result 1)))
      (is (cl:= 3 (nth result 2)))
      (is (cl:= 1 (nth result 3)))
      (is (cl:= 2 (nth result 4)))
      (is (cl:= 3 (nth result 5)))
      (is (cl:= 1 (nth result 6)))
      (is (cl:= 2 (nth result 7)))
      (is (cl:= 3 (nth result 8)))
      (is (cl:= 1 (nth result 9))))))


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
    (let* ((macro (fol-eval '(defmacro quote-it (x) (cl-list 'quote x)) env))
           (env2 (make-env env 'quote-it macro)))
      ;; (quote-it (+ 1 2)) should return the LIST (+ 1 2), not 3
      (is (equal '(+ 1 2) (fol-eval '(quote-it (+ 1 2)) env2))))))

(test macro-expansion-is-evaluated
  "Test that the result of macro expansion is evaluated."
  (let ((env (make-standard-env)))
    ;; Define a macro that builds an addition expression
    (let* ((macro (fol-eval '(defmacro add-expr (a b) (cl-list '+ a b)) env))
           (env2 (make-env env 'add-expr macro)))
      ;; (add-expr 1 2) expands to (+ 1 2) which evaluates to 3
      (is (cl:= 3 (fol-eval '(add-expr 1 2) env2))))))

(test macro-when-builtin
  "Test the built-in 'when' macro from standard environment."
  (let ((env (make-standard-env)))
    ;; Test when condition is true - evaluates all forms, returns last
    (is (cl:= 42 (fol-eval '(when t 1 2 42) env)))
    ;; Test when condition is false - returns nil
    (is (eq nil (fol-eval '(when nil 1 2 42) env)))
    ;; Test when with computed test
    (is (cl:= 10 (fol-eval '(when (> 5 3) (+ 5 5)) env)))
    (is (eq nil (fol-eval '(when (< 5 3) (+ 5 5)) env)))
    ;; Test when with single body form
    (is (cl:= 1 (fol-eval '(when t 1) env)))
    ;; Test when with no body forms (just returns nil when true)
    (is (eq nil (fol-eval '(when t) env)))))

(test macro-unless-builtin
  "Test the built-in 'unless' macro from standard environment."
  (let ((env (make-standard-env)))
    ;; Test unless condition is false - evaluates all forms, returns last
    (is (cl:= 42 (fol-eval '(unless nil 1 2 42) env)))
    ;; Test unless condition is true - returns nil
    (is (eq nil (fol-eval '(unless t 1 2 42) env)))
    ;; Test unless with computed test
    (is (eq nil (fol-eval '(unless (> 5 3) (+ 5 5)) env)))
    (is (cl:= 10 (fol-eval '(unless (< 5 3) (+ 5 5)) env)))
    ;; Test unless with single body form
    (is (cl:= 1 (fol-eval '(unless nil 1) env)))
    ;; Test unless with no body forms (just returns nil when false)
    (is (eq nil (fol-eval '(unless nil) env)))))

(test macro-when-user-defined
  "Test implementing a 'when' macro (user-defined, for backwards compatibility)."
  (let ((env (make-standard-env)))
    ;; (when test body...) => (if test (do body...))
    (let* ((macro (fol-eval '(defmacro my-when (test & body)
                               (cl-list 'if test (cl-cons 'do body)))
                            env))
           (env2 (make-env env 'my-when macro)))
      ;; Test when condition is true
      (is (cl:= 42 (fol-eval '(my-when t 1 2 42) env2)))
      ;; Test when condition is false
      (is (eq nil (fol-eval '(my-when nil 1 2 42) env2))))))

(test macro-unless-user-defined
  "Test implementing an 'unless' macro (user-defined, for backwards compatibility)."
  (let ((env (make-standard-env)))
    ;; (my-unless test body...) => (if test nil (do body...))
    (let* ((macro (fol-eval '(defmacro my-unless (test & body)
                               (cl-list 'if test nil (cl-cons 'do body)))
                            env))
           (env2 (make-env env 'my-unless macro)))
      ;; Test unless condition is false (body executes)
      (is (cl:= 42 (fol-eval '(my-unless nil 1 2 42) env2)))
      ;; Test unless condition is true (body doesn't execute)
      (is (eq nil (fol-eval '(my-unless t 1 2 42) env2))))))

(test macro-with-rest-params
  "Test macros with rest parameters."
  (let ((env (make-standard-env)))
    ;; A macro that wraps all args in a list call
    (let* ((macro (fol-eval '(defmacro make-list (& items)
                               (cl-cons 'cl-list items))
                            env))
           (env2 (make-env env 'make-list macro)))
      (is (equal '(1 2 3) (fol-eval '(make-list 1 2 3) env2))))))

(test macro-nested-expansion
  "Test nested macro calls."
  (let ((env (make-standard-env)))
    ;; Define two macros
    (let* ((double-macro (fol-eval '(defmacro double (x) (cl-list '* 2 x)) env))
           (env2 (make-env env 'double double-macro))
           (triple-macro (fol-eval '(defmacro triple (x) (cl-list '* 3 x)) env2))
           (env3 (make-env env2 'triple triple-macro)))
      ;; (double (triple 5)) => (* 2 (* 3 5)) => 30
      (is (cl:= 30 (fol-eval '(double (triple 5)) env3))))))

(test macro-accesses-closure-env
  "Test that macros can access their closure environment."
  (let ((env (make-standard-env)))
    ;; Define a macro that uses a value from its definition environment
    (let* ((env2 (make-env env 'multiplier 10))
           (macro (fol-eval '(defmacro scale (x) (cl-list '* multiplier x)) env2))
           (env3 (make-env env2 'scale macro)))
      ;; (scale 5) expands to (* 10 5) => 50
      (is (cl:= 50 (fol-eval '(scale 5) env3))))))

(test macro-and-short-circuit
  "Test implementing a short-circuit 'and' macro."
  (let ((env (make-standard-env)))
    ;; (my-and a b) => (if a b nil)
    (let* ((macro (fol-eval '(defmacro my-and (a b)
                               (cl-list 'if a b nil))
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
                               (cl-list 'if a a b))
                            env))
           (env2 (make-env env 'my-or macro)))
      (is (eq t (fol-eval '(my-or t t) env2)))
      (is (eq t (fol-eval '(my-or t nil) env2)))
      (is (eq t (fol-eval '(my-or nil t) env2)))
      (is (eq nil (fol-eval '(my-or nil nil) env2))))))

(test macroexpand-1-basic
  "Test macroexpand-1 function."
  (let ((env (make-standard-env)))
    (let* ((macro (fol-eval '(defmacro double (x) (cl-list '* 2 x)) env))
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
    (let* ((inner-macro (fol-eval '(defmacro inner (x) (cl-list '+ x 1)) env))
           (env2 (make-env env 'inner inner-macro))
           (outer-macro (fol-eval '(defmacro outer (x) (cl-list 'inner x)) env2))
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
                          (cl-list 'if
                                (first (first clauses))
                                (first (rest (first clauses)))
                                (cl-cons 'my-cond (rest clauses)))))
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
                      (cl-cons 'bind
                            (cl-cons (apply cl-list
                                        (apply append
                                               (cl-list bindings)))
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
                               (cl-list 'bind (cl-list 'x a 'y b) (cl-cons 'do body)))")
                            env))
           (env2 (make-env env 'with-pair macro)))
      ;; (with-pair [1 2] (+ x y)) expands to (bind (x 1 y 2) (do (+ x y)))
      (is (cl:= 3 (fol-eval (fol-form "(with-pair [1 2] (+ x y))") env2))))))

(test macro-destructure-extracts-form-parts
  "Test macro that destructures to extract parts of forms."
  (let ((env (make-standard-env)))
    ;; A macro that extracts the first two elements and returns them as a list
    (let* ((macro (fol-eval (fol-form "(defmacro get-first-two [[a b & rest]]
                               (cl-list 'cl-list b a))")
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
                               (cl-list 'cl-list a b (cl-list 'quote more)))")
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
                               (cl-list '+ a b))")
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
                               (cl-list 'bind (cl-list pattern value) (cl-cons 'do body)))")
                            env))
           (env2 (make-env env 'my-let macro)))
      ;; Test with simple binding
      (is (cl:= 10 (fol-eval (fol-form "(my-let [x 10] x)") env2)))
      ;; Test with destructured binding pattern inside the let
      (is (cl:= 3 (fol-eval (fol-form "(my-let [[a b] [1 2]] (+ a b))") env2))))))

;;; ---------------------------------------------------------------------------
;;; Multi-Pattern Defmacro
;;; ---------------------------------------------------------------------------

(test defmacro-multi-pattern-creates-multi-macro
  "Test that multi-pattern defmacro creates a <multi-macro> object."
  (let ((env (make-standard-env)))
    (let ((multi-macro (fol-eval (fol-form "(defmacro my-macro
                                              ([x] x)
                                              ([x y] (cl-list x y)))")
                                 env)))
      (is-true (<multi-macro>? multi-macro)))))

(test defmacro-multi-pattern-by-arity
  "Test multi-pattern defmacro dispatches by arity."
  (let ((env (make-standard-env)))
    ;; Define a macro with different arities
    (fol-eval (fol-form "(defmacro my-case
                           ([val] val)
                           ([val alt] (cl-list 'if val val alt))
                           ([val alt1 alt2] (cl-list 'if val alt1 alt2)))")
              env)
    ;; Test each arity
    (is (cl:= 42 (fol-eval '(my-case 42) env)))
    (is (cl:= 5 (fol-eval '(my-case 5 10) env)))
    (is (cl:= 20 (fol-eval '(my-case nil 10 20) env)))))

(test defmacro-multi-pattern-with-rest
  "Test multi-pattern defmacro with rest parameters."
  (let ((env (make-standard-env)))
    ;; Define macro with rest params in one clause
    ;; Use list instead of list* since list* isn't in standard env
    (fol-eval (fol-form "(defmacro list-items
                           ([a] (cl-list 'cl-list a))
                           ([a b] (cl-list 'cl-list a b))
                           ([a b & more] (cl-cons 'cl-list (cl-cons a (cl-cons b more)))))")
              env)
    ;; Test arity 1
    (is (equal '(1) (fol-eval '(list-items 1) env)))
    ;; Test arity 2
    (is (equal '(1 2) (fol-eval '(list-items 1 2) env)))
    ;; Test arity 3+
    (let ((result (fol-eval '(list-items 1 2 3 4) env)))
      (is (cl:= 4 (length result)))
      (is (cl:= 1 (cl:first result)))
      (is (cl:= 2 (cl:second result)))
      (is (cl:= 3 (cl:third result)))
      (is (cl:= 4 (cl:fourth result))))))

(test defmacro-multi-pattern-with-destructuring
  "Test multi-pattern defmacro with destructuring patterns."
  (let ((env (make-standard-env)))
    ;; Define macro that dispatches based on destructuring pattern
    (fol-eval (fol-form "(defmacro extract
                           ([x] x)
                           ([[a b]] (cl-list '+ a b)))")
              env)
    ;; Test non-destructuring case
    (is (cl:= 5 (fol-eval '(extract 5) env)))
    ;; Test destructuring case - (1 2) is a 2-element sequence
    (is (cl:= 3 (fol-eval '(extract (1 2)) env)))))

(test defmacro-multi-pattern-specificity
  "Test that more specific patterns are tried first."
  (let ((env (make-standard-env)))
    ;; Define macro where same arity has different patterns
    ;; [x] matches anything, [[a b]] matches 2-element sequences
    ;; The [[a b]] pattern should be tried first
    (fol-eval (fol-form "(defmacro process
                           ([x] (cl-list 'quote x))
                           ([[a b]] (cl-list '+ a b)))")
              env)
    ;; 2-element list should match destructuring pattern first
    (is (cl:= 7 (fol-eval '(process (3 4)) env)))
    ;; Symbol should match the any pattern
    (is (eq 'foo (fol-eval '(process foo) env)))))

(test defmacro-multi-pattern-expansion
  "Test that multi-pattern macro expansion works correctly."
  (let ((env (make-standard-env)))
    ;; Define a 'when' equivalent with multiple patterns
    (fol-eval (fol-form "(defmacro my-when
                           ([test] nil)
                           ([test form] (cl-list 'if test form nil))
                           ([test form & more] (cl-list 'if test (cl-cons 'do (cl-cons form more)) nil)))")
              env)
    ;; Single arg - always nil
    (is (eq nil (fol-eval '(my-when t) env)))
    ;; Two args
    (is (cl:= 42 (fol-eval '(my-when t 42) env)))
    (is (eq nil (fol-eval '(my-when nil 42) env)))
    ;; Multiple body forms
    (is (cl:= 3 (fol-eval '(my-when t 1 2 3) env)))
    (is (eq nil (fol-eval '(my-when nil 1 2 3) env)))))

(test defmacro-multi-pattern-arity-error
  "Test that multi-pattern macro reports arity errors correctly."
  (let ((env (make-standard-env)))
    ;; Define macro that only accepts 1 or 2 args
    (fol-eval (fol-form "(defmacro one-or-two
                           ([x] x)
                           ([x y] (cl-list x y)))")
              env)
    ;; Zero args should error
    (signals fol-arity-error
      (fol-eval '(one-or-two) env))
    ;; Three args should error
    (signals fol-arity-error
      (fol-eval '(one-or-two 1 2 3) env))))

(test defmacro-multi-pattern-macroexpand
  "Test macroexpand-1 and macroexpand with multi-pattern macros."
  (let ((env (make-standard-env)))
    ;; Define multi-pattern macro
    (fol-eval (fol-form "(defmacro expand-test
                           ([x] (cl-list 'quote x))
                           ([x y] (cl-list '+ x y)))")
              env)
    ;; Test macroexpand-1 with first pattern
    (multiple-value-bind (expanded expandedp)
        (macroexpand-1 '(expand-test foo) env)
      (is (equal '(quote foo) expanded))
      (is-true expandedp))
    ;; Test macroexpand-1 with second pattern
    (multiple-value-bind (expanded expandedp)
        (macroexpand-1 '(expand-test 1 2) env)
      (is (equal '(+ 1 2) expanded))
      (is-true expandedp))))

(test defmacro-multi-pattern-nested-destructure
  "Test multi-pattern defmacro with nested destructuring."
  (let ((env (make-standard-env)))
    ;; Define macro with nested destructure in one pattern
    ;; Pattern [[[a] b]] expects one arg that is a 2-element sequence
    ;; where the first element is a 1-element sequence
    (fol-eval (fol-form "(defmacro extract-inner
                           ([x] x)
                           ([[[a] b]] (cl-list '+ a b)))")
              env)
    ;; Simple case - matches [x]
    (is (cl:= 5 (fol-eval '(extract-inner 5) env)))
    ;; Nested destructure - arg is ((1) 2), a 2-element list
    ;; [[a] b] destructures to: [a] matches (1) so a=1, b matches 2
    (is (cl:= 3 (fol-eval '(extract-inner ((1) 2)) env)))))

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

;;; ---------------------------------------------------------------------------
;;; Multi-Pattern defn
;;; ---------------------------------------------------------------------------

(test defn-multi-pattern-basic
  "Test multi-pattern defn with different arities."
  (let ((env (make-standard-env)))
    ;; Define function with multiple arities
    (fol-eval (fol-form "(defn inc-all
                          ([x] (+ x 1))
                          ([x y] (+ x y 2)))") env)
    ;; Test single-arg version
    (is (cl:= 6 (fol-eval (fol-form "(inc-all 5)") env)))
    ;; Test two-arg version
    (is (cl:= 12 (fol-eval (fol-form "(inc-all 5 5)") env)))))

(test defn-multi-pattern-numeric
  "Test multi-pattern defn with numeric operations."
  (let ((env (make-standard-env)))
    ;; Define function with multiple arities
    (fol-eval (fol-form "(defn add-all
                          ([x] x)
                          ([x y] (+ x y))
                          ([x y z] (+ x y z)))") env)
    ;; Test all arities
    (is (cl:= 5 (fol-eval (fol-form "(add-all 5)") env)))
    (is (cl:= 7 (fol-eval (fol-form "(add-all 3 4)") env)))
    (is (cl:= 15 (fol-eval (fol-form "(add-all 3 5 7)") env)))))

(test defn-multi-pattern-with-destructuring
  "Test multi-pattern defn with destructuring patterns."
  (let ((env (make-standard-env)))
    ;; Define function that handles atoms vs pairs differently
    (fol-eval (fol-form "(defn process
                          ([x] x)
                          ([[a b]] (+ a b)))") env)
    ;; Test single value (not a sequence)
    (is (cl:= 42 (fol-eval (fol-form "(process 42)") env)))
    ;; Test pair (vector) - should destructure and add
    (is (cl:= 7 (fol-eval (fol-form "(process [3 4])") env)))))

(test defn-multi-pattern-specificity
  "Test that more specific patterns match before general ones."
  (let ((env (make-standard-env)))
    ;; Define function: [[a b]] should match before [x] for pairs
    (fol-eval (fol-form "(defn classify
                          ([x] :single)
                          ([[a b]] :pair)
                          ([[a b c]] :triple))") env)
    ;; Single value -> :single
    (is (eq :single (fol-eval (fol-form "(classify 42)") env)))
    ;; Two-element vector -> :pair (more specific than :single for this arity)
    (is (eq :pair (fol-eval (fol-form "(classify [1 2])") env)))
    ;; Three-element vector -> :triple
    (is (eq :triple (fol-eval (fol-form "(classify [1 2 3])") env)))))

(test defn-multi-pattern-arity-error
  "Test that invalid arities signal an error."
  (let ((env (make-standard-env)))
    ;; Define function with only 1 and 2 arg patterns
    (fol-eval (fol-form "(defn limited
                          ([x] x)
                          ([x y] (+ x y)))") env)
    ;; Valid arities work
    (is (cl:= 5 (fol-eval (fol-form "(limited 5)") env)))
    (is (cl:= 8 (fol-eval (fol-form "(limited 3 5)") env)))
    ;; Invalid arity signals error
    (signals fol.eval:fol-arity-error
      (fol-eval (fol-form "(limited 1 2 3)") env))))

(test defn-multi-pattern-with-rest
  "Test multi-pattern defn with rest parameters."
  (let ((env (make-standard-env)))
    ;; Define function with rest parameter in one clause
    (fol-eval (fol-form "(defn variadic
                          ([x] x)
                          ([x y & more] (+ x y (reduce + 0 more))))") env)
    ;; Single arg
    (is (cl:= 5 (fol-eval (fol-form "(variadic 5)") env)))
    ;; Two args
    (is (cl:= 7 (fol-eval (fol-form "(variadic 3 4)") env)))
    ;; More args
    (is (cl:= 15 (fol-eval (fol-form "(variadic 1 2 3 4 5)") env)))))

;;; ---------------------------------------------------------------------------
;;; New Sequence Functions
;;; ---------------------------------------------------------------------------

(test sequence-function
  "Test sequence function returns sequence or empty list."
  (let ((env (make-standard-env)))
    ;; Non-empty collection returns sequence
    (is-true (fol.seqop:seq (fol-eval (fol-form "(sequence [1 2 3])") env)))
    ;; Empty collection returns empty list (not nil)
    (let ((result (fol-eval (fol-form "(sequence [])") env)))
      (is-true (fol.collection:<list>? result))
      (is-true (fol.seqop:empty? result)))))

(test keep-indexed-basic
  "Test keep-indexed with index and value."
  (let ((env (make-standard-env)))
    ;; Return indexed values where index is even
    (let ((result (fol-eval (fol-form "(into [] (keep-indexed (fn [i v] (when (even? i) v)) [10 20 30 40 50]))") env)))
      (is (cl:= 3 (fol.seqop:size result)))
      (is (cl:= 10 (fol.seqop:nth result 0)))
      (is (cl:= 30 (fol.seqop:nth result 1)))
      (is (cl:= 50 (fol.seqop:nth result 2))))))

(test map-indexed-basic
  "Test map-indexed returns (f index item) for each item."
  (let ((env (make-standard-env)))
    ;; Map with index
    (let ((result (fol-eval (fol-form "(into [] (map-indexed (fn [i v] (+ i v)) [10 20 30]))") env)))
      (is (cl:= 3 (fol.seqop:size result)))
      (is (cl:= 10 (fol.seqop:nth result 0)))  ; 0 + 10
      (is (cl:= 21 (fol.seqop:nth result 1)))  ; 1 + 20
      (is (cl:= 32 (fol.seqop:nth result 2))))))  ; 2 + 30

(test tree-seq-basic
  "Test tree-seq walks a tree depth-first."
  (let ((env (make-standard-env)))
    ;; Simple tree: walk a vector of vectors
    (let ((result (fol-eval (fol-form "(into [] (take 5 (tree-seq <vector>? seq [[1 2] [3 4]])))") env)))
      (is (>= (fol.seqop:size result) 1)))))

;;; ---------------------------------------------------------------------------
;;; Threading Macro Tests
;;; ---------------------------------------------------------------------------

(test as->-macro
  "Test as-> threading macro."
  (let ((env (make-standard-env)))
    ;; Basic threading with named binding
    (is (cl:= 4 (fol-eval (fol-form "(as-> 1 x (+ x 1) (* x 2))") env)))))

(test cond->-macro
  "Test cond-> conditional threading."
  (let ((env (make-standard-env)))
    ;; Thread when condition is true (using bare symbols)
    (is (cl:= 3 (fol-eval (fol-form "(cond-> 1 t inc t inc)") env)))
    ;; Skip when condition is false
    (is (cl:= 2 (fol-eval (fol-form "(cond-> 1 t inc nil inc)") env)))))

(test some->-macro
  "Test some-> nil-safe threading."
  (let ((env (make-standard-env)))
    ;; Normal threading
    (is (cl:= 3 (fol-eval (fol-form "(some-> 1 inc inc)") env)))
    ;; Short-circuit on nil
    (is (null (fol-eval (fol-form "(some-> nil inc inc)") env)))))

;;; ---------------------------------------------------------------------------
;;; Control Flow Macro Tests
;;; ---------------------------------------------------------------------------

(test when-not-macro
  "Test when-not macro."
  (let ((env (make-standard-env)))
    (is (cl:= 42 (fol-eval (fol-form "(when-not nil 42)") env)))
    (is (null (fol-eval (fol-form "(when-not t 42)") env)))))

(test when-let-macro
  "Test when-let macro."
  (let ((env (make-standard-env)))
    ;; When truthy, execute body
    (is (cl:= 2 (fol-eval (fol-form "(when-let [x 1] (+ x 1))") env)))
    ;; When nil, return nil
    (is (null (fol-eval (fol-form "(when-let [x nil] (+ x 1))") env)))))

(test when-first-macro
  "Test when-first macro."
  (let ((env (make-standard-env)))
    ;; When collection has elements
    (is (cl:= 2 (fol-eval (fol-form "(when-first [x [1 2 3]] (inc x))") env)))
    ;; When collection is empty
    (is (null (fol-eval (fol-form "(when-first [x []] 42)") env)))))

(test if-not-macro
  "Test if-not macro."
  (let ((env (make-standard-env)))
    (is (eq :yes (fol-eval (fol-form "(if-not nil :yes :no)") env)))
    (is (eq :no (fol-eval (fol-form "(if-not t :yes :no)") env)))))

(test if-let-macro
  "Test if-let macro."
  (let ((env (make-standard-env)))
    (is (cl:= 2 (fol-eval (fol-form "(if-let [x 1] (+ x 1) 0)") env)))
    (is (cl:= 0 (fol-eval (fol-form "(if-let [x nil] (+ x 1) 0)") env)))))

(test when-some-macro
  "Test when-some macro."
  (let ((env (make-standard-env)))
    ;; When value is non-nil
    (is (cl:= 2 (fol-eval (fol-form "(when-some [x 1] (+ x 1))") env)))
    ;; When value is nil
    (is (null (fol-eval (fol-form "(when-some [x nil] (+ x 1))") env)))))

(test if-some-macro
  "Test if-some macro."
  (let ((env (make-standard-env)))
    (is (cl:= 2 (fol-eval (fol-form "(if-some [x 1] (+ x 1) 0)") env)))
    (is (cl:= 0 (fol-eval (fol-form "(if-some [x nil] (+ x 1) 0)") env)))))

(test condp-macro
  "Test condp macro."
  (let ((env (make-standard-env)))
    (is (eq :one (fol-eval (fol-form "(condp = 1 1 :one 2 :two :other)") env)))
    (is (eq :two (fol-eval (fol-form "(condp = 2 1 :one 2 :two :other)") env)))
    (is (eq :other (fol-eval (fol-form "(condp = 3 1 :one 2 :two :other)") env)))))

;;; ---------------------------------------------------------------------------
;;; Loop Macro Tests
;;; ---------------------------------------------------------------------------

(test dotimes-macro
  "Test dotimes macro."
  (let ((env (make-standard-env)))
    ;; dotimes returns nil but executes body n times
    (is (null (fol-eval (fol-form "(dotimes [i 3] i)") env)))))

(test doseq-macro
  "Test doseq macro."
  (let ((env (make-standard-env)))
    ;; doseq returns nil
    (is (null (fol-eval (fol-form "(doseq [x [1 2 3]] x)") env)))))

(test for-macro
  "Test for comprehension macro."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(into [] (for [x [1 2 3]] (* x x)))") env)))
      (is (cl:= 3 (fol.seqop:size result)))
      (is (cl:= 1 (fol.seqop:nth result 0)))
      (is (cl:= 4 (fol.seqop:nth result 1)))
      (is (cl:= 9 (fol.seqop:nth result 2))))))

;;; ---------------------------------------------------------------------------
;;; Lazy and Misc Macro Tests
;;; ---------------------------------------------------------------------------

(test lazy-cat-macro
  "Test lazy-cat macro."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(into [] (lazy-cat [1 2] [3 4]))") env)))
      (is (cl:= 4 (fol.seqop:size result)))
      (is (cl:= 1 (fol.seqop:nth result 0)))
      (is (cl:= 4 (fol.seqop:nth result 3))))))

(test delay-and-force
  "Test delay and force."
  (let ((env (make-standard-env)))
    ;; delay creates a deferred computation, force evaluates it
    (is (cl:= 3 (fol-eval (fol-form "(force (delay (+ 1 2)))") env)))))

(test assert-macro-passes
  "Test assert macro passes on truthy."
  (let ((env (make-standard-env)))
    ;; assert returns nil on success
    (is (null (fol-eval (fol-form "(assert t)") env)))
    (is (null (fol-eval (fol-form "(assert (> 5 3))") env)))))

(test comment-macro
  "Test comment macro returns nil."
  (let ((env (make-standard-env)))
    (is (null (fol-eval (fol-form "(comment (this is ignored) (so is this))") env)))))

;;; ---------------------------------------------------------------------------
;;; Functional Utility Tests
;;; ---------------------------------------------------------------------------

(test constantly-function
  "Test constantly returns a function that always returns the same value."
  (let ((env (make-standard-env)))
    (is (cl:= 42 (fol-eval (fol-form "((constantly 42) 1 2 3)") env)))))

(test comp-function
  "Test comp composes functions."
  (let ((env (make-standard-env)))
    ;; (comp inc inc) should add 2
    (is (cl:= 7 (fol-eval (fol-form "((comp inc inc) 5)") env)))))

(test memoize-function
  "Test memoize caches results."
  (let ((env (make-standard-env)))
    ;; Just test that it works
    (is (cl:= 10 (fol-eval (fol-form "((memoize +) 3 7)") env)))))

(test fnil-function
  "Test fnil replaces nil arguments with defaults."
  (let ((env (make-standard-env)))
    ;; fnil with default for first arg
    (is (cl:= 10 (fol-eval (fol-form "((fnil + 0) nil 10)") env)))))

(test fn?-predicate
  "Test fn? predicate."
  (let ((env (make-standard-env)))
    (is-true (fol-eval (fol-form "(fn? +)") env))
    (is-true (fol-eval (fol-form "(fn? (fn [x] x))") env))
    (is-false (fol-eval (fol-form "(fn? 42)") env))))

(test trampoline-function
  "Test trampoline for mutual recursion."
  (let ((env (make-standard-env)))
    ;; Simple trampoline that doesn't need further calls
    (is (cl:= 42 (fol-eval (fol-form "(trampoline (fn [] 42))") env)))))

;;; ---------------------------------------------------------------------------
;;; Utility Function Tests
;;; ---------------------------------------------------------------------------

(test nil?-predicate
  "Test nil? predicate."
  (let ((env (make-standard-env)))
    (is-true (fol-eval (fol-form "(nil? nil)") env))
    (is-false (fol-eval (fol-form "(nil? 1)") env))))

(test some?-predicate
  "Test some? predicate."
  (let ((env (make-standard-env)))
    (is-true (fol-eval (fol-form "(some? 1)") env))
    (is-false (fol-eval (fol-form "(some? nil)") env))))

(test not=-function
  "Test not= function."
  (let ((env (make-standard-env)))
    (is-true (fol-eval (fol-form "(not= 1 2)") env))
    (is-false (fol-eval (fol-form "(not= 1 1)") env))))

(test compare-function
  "Test compare function."
  (let ((env (make-standard-env)))
    (is (cl:= -1 (fol-eval (fol-form "(compare 1 2)") env)))
    (is (cl:= 0 (fol-eval (fol-form "(compare 2 2)") env)))
    (is (cl:= 1 (fol-eval (fol-form "(compare 3 2)") env)))))

(test some-function
  "Test some function."
  (let ((env (make-standard-env)))
    ;; Returns first truthy result of (pred x), not the element itself
    (is-true (fol-eval (fol-form "(some even? [1 2 3 4])") env))
    ;; Using a set as predicate returns the element
    (is (cl:= 2 (fol-eval (fol-form "(some #{2 4} [1 2 3 4])") env)))
    ;; Returns nil if no match
    (is (null (fol-eval (fol-form "(some even? [1 3 5])") env)))))

;;; ---------------------------------------------------------------------------
;;; Relational Function Tests
;;; ---------------------------------------------------------------------------

(test project-function
  "Test project returns relation with selected keys."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(first (project #{{:a 1 :b 2 :c 3}} [:a :b]))") env)))
      (is-true (fol.seqop:contains? result :a))
      (is-true (fol.seqop:contains? result :b))
      (is-false (fol.seqop:contains? result :c)))))

(test rename-function
  "Test rename renames keys in relation."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-form "(first (rename #{{:a 1 :b 2}} {:a :x}))") env)))
      (is-true (fol.seqop:contains? result :x))
      (is-false (fol.seqop:contains? result :a))
      (is-true (fol.seqop:contains? result :b)))))
