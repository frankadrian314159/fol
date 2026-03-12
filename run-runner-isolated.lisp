(require :asdf)
(let ((ql-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file ql-init) (load ql-init)))
(pushnew (truename "src/") asdf:*central-registry*)
(ql:quickload :fol-compiler :silent t)

(in-package :cl-user)

;; Ensure *out* is pointing to current *standard-output*
(setf (fol.compiler.streams::output-stream-stream fol.compiler.streams:*out*) *standard-output*)

(format t "Running fol-tests:macros via runner...~%")
(if (fol.compiler.fol-tests:load-and-run-fol-test "macros_test.fol")
    (format t "Runner succeeded.~%")
    (progn
     (format t "Runner failed.~%")
     (sb-ext:exit :code 1)))

(sb-ext:exit)
