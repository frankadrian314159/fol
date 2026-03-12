(require :asdf)
(let ((ql-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file ql-init) (load ql-init)))
(pushnew (truename "src/") asdf:*central-registry*)
(ql:quickload :fol-compiler :silent t)

(in-package :cl-user)

(defun run-fol-file (path)
  (format t "Compiling ~A...~%" path)
  (let ((fasl (fol.compiler:compile-file path)))
    (format t "Loading ~A...~%" fasl)
    ;; Ensure *out* is pointing to current *standard-output*
    (setf (fol.compiler.streams::output-stream-stream fol.compiler.streams:*out*) *standard-output*)
    (load fasl)
    (format t "Done loading.~%")))

(handler-case
    (run-fol-file "repro-macros.fol")
  (error (e)
    (format t "Caught ERROR: ~A~%" e)
    (sb-ext:exit :code 1)))

(sb-ext:exit)
