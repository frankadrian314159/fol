#!/usr/bin/env sbcl --script

(require :asdf)
(pushnew #p"c:/Users/frank/Projects/FOL/fol/src/" asdf:*central-registry*)

(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file quicklisp-init)
      (load quicklisp-init)
      (format t "Quicklisp not found.~%")))

(dolist (dep '(:fset :sycamore :closer-mop :uuid :bordeaux-threads :usocket :cl-ppcre :fiveam))
  (if (find-package :ql)
      (uiop:symbol-call :ql :quickload dep)
      (asdf:load-system dep)))

(format t "~%Loading FOL compiler...~%")
(asdf:load-system :fol-compiler)

(format t "~%Loading FOL tests...~%")
(asdf:load-system :fol-compiler/tests)

(format t "~%Running tests...~%")
(fol.compiler.tests:run-compiler-tests)

(sb-ext:exit :code 0)
