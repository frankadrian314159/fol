;;; tests/defpackage-test.lisp
(in-package :fol.core)

;;; A minimal FOL source using defpackage-like syntax for the compiler
(defpackage :my.test.pkg
  (:use :cl)
  (:export my-fn))

(defn my-fn []
  42)

;;; Test runner: compile the defpackage and defn forms and print the results
(let ((forms (list '(defpackage :my.test.pkg (:use :cl) (:export my-fn))
                   '(defn my-fn [] 42))))
  (dolist (f forms)
    (format t "~%-- FOL form: ~S~%" f)
    (let ((res (fol.compiler:compile-form f)))
      (if (slot-value res 'errors)
          (format t "Errors: ~S~%" (slot-value res 'errors))
          (format t "Emitted CL:~%~S~%" (slot-value res 'code))))))
