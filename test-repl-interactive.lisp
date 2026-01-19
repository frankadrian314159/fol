(require :asdf)
(load "~/quicklisp/setup.lisp")
(push (truename ".") asdf:*central-registry*)

;; Load FOL quietly
(let ((*standard-output* (make-broadcast-stream))
      (*error-output* (make-broadcast-stream)))
  (handler-bind ((warning #'muffle-warning))
    (ql:quickload :fol :silent t)))

;; Simulate interactive REPL session with predefined inputs
(in-package fol.repl)

(format t "~%Testing REPL functionality...~%~%")

;; Initialize REPL
(reset-repl-env)

;; Test 1: Simple arithmetic
(format t "Test 1: Evaluating (+ 1 2)~%")
(let ((form '(+ 1 2)))
  (let ((result (repl-eval form)))
    (update-repl-vars form result)
    (format t "Result: ~S~%" result)
    (format t "History - *v1: ~S, *f1: ~S~%~%" *v1 *f1)))

;; Test 2: Let expression
(format t "Test 2: Evaluating (let (x 10) (* x 2))~%")
(let ((form '(let (x 10) (* x 2))))
  (let ((result (repl-eval form)))
    (update-repl-vars form result)
    (format t "Result: ~S~%" result)
    (format t "History - *v1: ~S, *v2: ~S~%" *v1 *v2)
    (format t "         *f1: ~S, *f2: ~S~%~%" *f1 *f2)))

;; Test 3: Lambda and application
(format t "Test 3: Evaluating ((lambda (x) (+ x 5)) 10)~%")
(let ((form '((lambda (x) (+ x 5)) 10)))
  (let ((result (repl-eval form)))
    (update-repl-vars form result)
    (format t "Result: ~S~%~%" result)))

;; Test 4: FOL syntax (using readtable)
(format t "Test 4: Testing FOL syntax reader with vector [1 2 3]~%")
(let ((form (with-input-from-string (s "[1 2 3]")
              (let ((*readtable* (named-readtables:find-readtable 'fol.syntax:fol-syntax)))
                (read s)))))
  (format t "Read form: ~S~%" form)
  (format t "Form evaluates to: ~S~%~%" (repl-eval form)))

;; Test 5: Boolean literals
(format t "Test 5: Testing FOL boolean literals~%")
(let ((true-form (with-input-from-string (s "#t")
                   (let ((*readtable* (named-readtables:find-readtable 'fol.syntax:fol-syntax)))
                     (read s))))
      (false-form (with-input-from-string (s "#f")
                    (let ((*readtable* (named-readtables:find-readtable 'fol.syntax:fol-syntax)))
                      (read s)))))
  (format t "Read #t as: ~S~%" true-form)
  (format t "Read #f as: ~S~%" false-form)
  (format t "#t evaluates to: ~S~%" (repl-eval true-form))
  (format t "#f evaluates to: ~S~%~%" (repl-eval false-form)))

;; Test 6: Nested expressions
(format t "Test 6: Evaluating nested expression (let (f (lambda (x) (* x x))) (f 7))~%")
(let ((form '(let (f (lambda (x) (* x x))) (f 7))))
  (let ((result (repl-eval form)))
    (format t "Result: ~S~%~%" result)))

;; Test 7: REPL variable history
(format t "Test 7: Checking REPL variable history~%")
(format t "*v1 (most recent): ~S~%" *v1)
(format t "*v2: ~S~%" *v2)
(format t "*v3: ~S~%" *v3)
(format t "*f1 (most recent): ~S~%" *f1)
(format t "*f2: ~S~%" *f2)
(format t "*f3: ~S~%~%" *f3)

(format t "~%===================================~%")
(format t "All REPL tests completed successfully!~%")
(format t "===================================~%~%")

(format t "To start the interactive REPL, run:~%")
(format t "  sbcl --load start-repl.lisp~%")
(format t "Or from within SBCL:~%")
(format t "  (ql:quickload :fol)~%")
(format t "  (fol.repl:start-repl)~%~%")

(sb-ext:exit :code 0)
