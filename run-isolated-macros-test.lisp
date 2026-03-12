(require :asdf)
(let ((ql-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file ql-init) (load ql-init)))
(pushnew (truename "src/") asdf:*central-registry*)
(ql:quickload :fol-compiler :silent t)

(in-package :cl-user)

;; Ensure *out* is pointing to current *standard-output*
(setf (fol.compiler.streams::output-stream-stream fol.compiler.streams:*out*) *standard-output*)

(format t "Compiling and running macros_test.fol...~%")
(let ((fasl (fol.compiler:compile-file "src/tests/fol-code/macros_test.fol")))
  (load fasl))
(format t "Success!~%")
(sb-ext:exit)
