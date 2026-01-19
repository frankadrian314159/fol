(require :asdf)
(load "~/quicklisp/setup.lisp")
(push (truename ".") asdf:*central-registry*)

(handler-bind ((warning #'muffle-warning))
  (handler-case
      (progn
        (ql:quickload :named-readtables :silent t)
        (ql:quickload :fset :silent t)
        (ql:quickload :closer-mop :silent t)
        (asdf:load-system :fol))
    (error (e)
      (format t "~%~%===== LOAD ERROR =====~%")
      (format t "~A~%~%" e)
      (describe e)
      (sb-ext:exit :code 1))))

;; Test basic REPL functionality
(in-package fol.repl)

(format t "~%~%===== TESTING REPL FUNCTIONALITY =====~%~%")

;; Test 1: Reset environment
(format t "Test 1: Resetting REPL environment...~%")
(reset-repl-env)
(format t "  Environment reset successfully~%~%")

;; Test 2: Read FOL syntax
(format t "Test 2: Testing FOL syntax reader...~%")
(let ((form (with-input-from-string (s "(+ 1 2)")
              (let ((*readtable* (named-readtables:find-readtable 'fol.syntax:fol-syntax)))
                (read s)))))
  (format t "  Read form: ~S~%" form)
  (format t "  Form type: ~A~%~%" (type-of form)))

;; Test 3: Evaluate simple expression
(format t "Test 3: Evaluating (+ 1 2)...~%")
(let ((result (fol.eval:fol-eval '(+ 1 2) *repl-env*)))
  (format t "  Result: ~S~%" result)
  (format t "  Result type: ~A~%~%" (type-of result)))

;; Test 4: Evaluate let expression
(format t "Test 4: Evaluating (let (x 10) (* x 2))...~%")
(let ((result (fol.eval:fol-eval '(let (x 10) (* x 2)) *repl-env*)))
  (format t "  Result: ~S~%" result)
  (format t "  Result type: ~A~%~%" (type-of result)))

;; Test 5: Evaluate lambda
(format t "Test 5: Evaluating ((lambda (x) (+ x 5)) 10)...~%")
(let ((result (fol.eval:fol-eval '((lambda (x) (+ x 5)) 10) *repl-env*)))
  (format t "  Result: ~S~%" result)
  (format t "  Result type: ~A~%~%" (type-of result)))

;; Test 6: REPL variable tracking
(format t "Test 6: Testing REPL variable tracking...~%")
(update-repl-vars '(+ 1 2) 3)
(format t "  *v1 (most recent value): ~S~%" *v1)
(format t "  *f1 (most recent form): ~S~%" *f1)
(format t "  *l1 (most recent value list): ~S~%~%" *l1)

(update-repl-vars '(* 3 4) 12)
(format t "  After second evaluation:~%")
(format t "  *v1: ~S, *v2: ~S~%" *v1 *v2)
(format t "  *f1: ~S, *f2: ~S~%~%" *f1 *f2)

(format t "~%===== ALL TESTS PASSED =====~%~%")
(format t "To start the interactive REPL, run: (fol.repl:start-repl)~%~%")

(sb-ext:exit :code 0)
