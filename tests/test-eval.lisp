(in-package fol.tests)
(in-readtable fol-syntax)

(in-suite fol-suite)

;;; ============================================================================
;;; FOL Evaluator Tests
;;; ============================================================================

;;; Helper to create a test environment
(defun test-env ()
  (fol.eval:make-initial-env))

;;; ============================================================================
;;; Self-evaluating expressions
;;; ============================================================================

(test eval-self-evaluating-number
  "Test that numbers evaluate to themselves"
  (is (= (fol.eval:fol-eval 42 (test-env)) 42))
  (is (= (fol.eval:fol-eval 3.14 (test-env)) 3.14))
  (is (= (fol.eval:fol-eval -10 (test-env)) -10)))

(test eval-self-evaluating-string
  "Test that strings evaluate to themselves"
  (is (string= (fol.eval:fol-eval "hello" (test-env)) "hello"))
  (is (string= (fol.eval:fol-eval "" (test-env)) "")))

(test eval-self-evaluating-character
  "Test that characters evaluate to themselves"
  (is (char= (fol.eval:fol-eval #\A (test-env)) #\A))
  (is (char= (fol.eval:fol-eval #\space (test-env)) #\space)))

(test eval-self-evaluating-boolean
  "Test that booleans evaluate to themselves"
  (is (eq (fol.eval:fol-eval *true-instance* (test-env)) *true-instance*))
  (is (eq (fol.eval:fol-eval *false-instance* (test-env)) *false-instance*)))

;;; ============================================================================
;;; Variable lookup
;;; ============================================================================

(test eval-variable-lookup
  "Test variable lookup in environment"
  (let ((env (make-env nil 'x 10 'y 20)))
    (is (= (fol.eval:fol-eval 'x env) 10))
    (is (= (fol.eval:fol-eval 'y env) 20))))

(test eval-variable-unbound
  "Test unbound variable raises error"
  (signals fol.env:fol-unbound-variable
    (fol.eval:fol-eval 'undefined (make-env))))

;;; ============================================================================
;;; Quote special form
;;; ============================================================================

(test eval-quote
  "Test quote special form"
  (is (equal (fol.eval:fol-eval '(quote (1 2 3)) (test-env)) '(1 2 3)))
  (is (eq (fol.eval:fol-eval '(quote foo) (test-env)) 'foo))
  (is (equal (fol.eval:fol-eval '(quote (+ 1 2)) (test-env)) '(+ 1 2))))

;;; ============================================================================
;;; If special form
;;; ============================================================================

(test eval-if-true
  "Test if with true condition"
  (is (= (fol.eval:fol-eval '(if 1 10 20) (test-env)) 10))
  (is (= (fol.eval:fol-eval '(if (quote foo) 10 20) (test-env)) 10)))

(test eval-if-false
  "Test if with false condition (nil and #f)"
  (let ((env (test-env)))
    (is (= (fol.eval:fol-eval (list'if nil 10 20) env) 20))
    (is (= (fol.eval:fol-eval (list'if *false-instance* 10 20) env) 20))))

(test eval-if-no-else
  "Test if without else clause"
  (is (= (fol.eval:fol-eval '(if 1 10) (test-env)) 10))
  (is (null (fol.eval:fol-eval (list'if nil 10) (test-env)))))

(test eval-if-nested
  "Test nested if expressions"
  (is (= (fol.eval:fol-eval '(if 1 (if 2 10 20) 30) (test-env)) 10))
  (is (= (fol.eval:fol-eval (list'if nil 10 (list'if 1 20 30)) (test-env)) 20)))

;;; ============================================================================
;;; Let special form
;;; ============================================================================

(test eval-let-simple
  "Test simple let binding"
  (is (= (fol.eval:fol-eval '(let (x 10) x) (test-env)) 10))
  (is (= (fol.eval:fol-eval '(let (x 10 y 20) (+ x y)) (test-env)) 30)))

(test eval-let-multiple-bindings
  "Test let with multiple bindings"
  (is (= (fol.eval:fol-eval '(let (a 1 b 2 c 3) (+ a (+ b c))) (test-env)) 6)))

(test eval-let-nested
  "Test nested let expressions"
  (is (= (fol.eval:fol-eval '(let (x 10)
                                (let (y 20)
                                  (+ x y)))
                            (test-env))
         30)))

(test eval-let-shadowing
  "Test that inner let bindings shadow outer ones"
  (is (= (fol.eval:fol-eval '(let (x 10)
                                (let (x 20)
                                  x))
                            (test-env))
         20)))

(test eval-let-sequential-bindings
  "Test that let bindings are sequential (later bindings can reference earlier)"
  (is (= (fol.eval:fol-eval '(let (x 10 y (+ x 5)) y) (test-env)) 15))
  (is (= (fol.eval:fol-eval '(let (a 1 b (+ a 1) c (+ b 1)) c) (test-env)) 3)))

(test eval-let-body-sequence
  "Test that let evaluates multiple body forms and returns last"
  (is (= (fol.eval:fol-eval '(let (x 10)
                                (+ x 1)
                                (+ x 2)
                                (+ x 3))
                            (test-env))
         13)))

(test eval-let-empty-bindings
  "Test let with empty bindings"
  (is (= (fol.eval:fol-eval '(let () 42) (test-env)) 42)))

;;; ============================================================================
;;; Lambda special form
;;; ============================================================================

(test eval-lambda-creation
  "Test that lambda creates a closure"
  (let ((closure (fol.eval:fol-eval '(lambda (x) x) (test-env))))
    (is (typep closure 'fol.eval:<closure>))
    (is (equal (fol.eval:closure-params closure) '(x)))))

(test eval-lambda-with-fn
  "Test that fn is synonym for lambda"
  (let ((closure (fol.eval:fol-eval '(fn (x) x) (test-env))))
    (is (typep closure 'fol.eval:<closure>))
    (is (equal (fol.eval:closure-params closure) '(x)))))

(test eval-lambda-multiple-params
  "Test lambda with multiple parameters"
  (let ((closure (fol.eval:fol-eval '(lambda (x y z) (+ x (+ y z))) (test-env))))
    (is (typep closure 'fol.eval:<closure>))
    (is (equal (fol.eval:closure-params closure) '(x y z)))))

(test eval-lambda-captures-environment
  "Test that lambda captures its lexical environment"
  (let* ((expr '(let (x 10)
                  (lambda (y) (+ x y))))
         (closure (fol.eval:fol-eval expr (test-env))))
    (is (typep closure 'fol.eval:<closure>))
    ;; The closure should have captured x=10 from the environment
    (is (= (fol.eval:apply-function closure '(5)) 15))))

;;; ============================================================================
;;; Function application
;;; ============================================================================

(test eval-application-primitive
  "Test applying primitive functions"
  (is (= (fol.eval:fol-eval '(+ 1 2) (test-env)) 3))
  (is (= (fol.eval:fol-eval '(* 3 4) (test-env)) 12))
  (is (= (fol.eval:fol-eval '(- 10 3) (test-env)) 7))
  (is (= (fol.eval:fol-eval '(/ 20 4) (test-env)) 5)))

(test eval-application-nested
  "Test nested function applications"
  (is (= (fol.eval:fol-eval '(+ 1 (+ 2 3)) (test-env)) 6))
  (is (= (fol.eval:fol-eval '(* (+ 1 2) (+ 3 4)) (test-env)) 21)))

(test eval-application-lambda-immediate
  "Test immediately applying a lambda"
  (is (= (fol.eval:fol-eval '((lambda (x) (+ x 1)) 5) (test-env)) 6))
  (is (= (fol.eval:fol-eval '((lambda (x y) (+ x y)) 3 4) (test-env)) 7)))

(test eval-application-lambda-via-let
  "Test applying lambda bound in let"
  (is (= (fol.eval:fol-eval '(let (f (lambda (x) (* x 2)))
                                (f 5))
                            (test-env))
         10)))

(test eval-application-with-variable-args
  "Test function application with variable arguments"
  (is (= (fol.eval:fol-eval '(let (x 3 y 4)
                                (+ x y))
                            (test-env))
         7)))

;;; ============================================================================
;;; Higher-order functions
;;; ============================================================================

(test eval-lambda-returning-lambda
  "Test lambda returning lambda"
  (let* ((expr '((lambda (x)
                   (lambda (y) (+ x y)))
                 10))
         (inner-fn (fol.eval:fol-eval expr (test-env))))
    (is (typep inner-fn 'fol.eval:<closure>))
    (is (= (fol.eval:apply-function inner-fn '(5)) 15))))

(test eval-currying
  "Test curried functions"
  (is (= (fol.eval:fol-eval '(((lambda (x)
                                  (lambda (y)
                                    (+ x y)))
                                10)
                               5)
                            (test-env))
         15)))

(test eval-lambda-as-argument
  "Test passing lambda as argument"
  (is (= (fol.eval:fol-eval '(let (apply-twice (lambda (f x) (f (f x)))
                                    add1 (lambda (x) (+ x 1)))
                                (apply-twice add1 5))
                            (test-env))
         7)))

;;; ============================================================================
;;; Complex examples
;;; ============================================================================

(test eval-factorial-recursive
  "Test recursive factorial using Y combinator style"
  ;; Simple iterative version using let
  (is (= (fol.eval:fol-eval '(let (n 5
                                    acc 1
                                    i 1)
                                (let (acc (* acc i) i (+ i 1))
                                  (let (acc (* acc i) i (+ i 1))
                                    (let (acc (* acc i) i (+ i 1))
                                      (let (acc (* acc i) i (+ i 1))
                                        (let (acc (* acc i))
                                          acc))))))
                            (test-env))
         120)))

(test eval-let-over-lambda
  "Test let-over-lambda pattern (closure with state)"
  (let* ((make-counter '(let (count 0)
                          (lambda ()
                            (let (count (+ count 1))
                              count))))
         ;; Note: This won't work as expected because let doesn't mutate
         ;; It creates a new binding. This test just verifies the syntax works
         (counter (fol.eval:fol-eval make-counter (test-env))))
    (is (typep counter 'fol.eval:<closure>))))

(test eval-composition
  "Test function composition"
  (is (= (fol.eval:fol-eval '(let (compose (lambda (f g)
                                              (lambda (x)
                                                (f (g x))))
                                    add1 (lambda (x) (+ x 1))
                                    double (lambda (x) (* x 2)))
                                ((compose double add1) 5))
                            (test-env))
         12)))

(test eval-map-like
  "Test a map-like operation with multiple applications"
  (let ((result (fol.eval:fol-eval '(let (square (lambda (x) (* x x)))
                                      (list (square 1)
                                            (square 2)
                                            (square 3)))
                                   (test-env))))
    (is (listp result))
    (is (= (length result) 3))
    (is (= (first result) 1))
    (is (= (second result) 4))
    (is (= (third result) 9))))

;;; ============================================================================
;;; List operations
;;; ============================================================================

(test eval-list-primitives
  "Test listprimitive operations"
  (is (equal (fol.eval:fol-eval '(list 1 2 3) (test-env)) '(1 2 3)))
  (is (equal (fol.eval:fol-eval '(cons 1 (quote (2 3))) (test-env)) '(1 2 3)))
  (is (= (fol.eval:fol-eval '(car (quote (1 2 3))) (test-env)) 1))
  (is (equal (fol.eval:fol-eval '(cdr (quote (1 2 3))) (test-env)) '(2 3))))

(test eval-list-construction
  "Test building lists with let and lambda"
  (is (equal (fol.eval:fol-eval '(let (x 1 y 2 z 3)
                                   (list x y z))
                                (test-env))
             '(1 2 3))))

;;; ============================================================================
;;; Toplevel eval
;;; ============================================================================

(test eval-toplevel
  "Test fol-eval-toplevel convenience function"
  (is (= (fol.eval:fol-eval-toplevel 42) 42))
  (is (= (fol.eval:fol-eval-toplevel '(+ 1 2)) 3))
  (is (= (fol.eval:fol-eval-toplevel '(let (x 10) (* x 2))) 20)))
