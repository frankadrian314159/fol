(require :asdf)
(pushnew #p"c:/Users/frank/Projects/FOL/fol/src/" asdf:*central-registry*)

(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file quicklisp-init)
      (load quicklisp-init)
      (format t "Quicklisp not found.~%")))

(dolist (dep '(:fset :sycamore :closer-mop :uuid :bordeaux-threads :usocket :cl-ppcre :flexi-streams :cl-json))
  (if (find-package :ql)
      (uiop:symbol-call :ql :quickload dep)
      (asdf:load-system dep)))

(asdf:load-system :fol-compiler)

(handler-bind ((error (lambda (c)
                        (format t "~%!!! ERROR: ~A~%" c)
                        (sb-debug:print-backtrace :count 20)
                        (sb-ext:exit :code 1))))
  (format t "~%Loading lsim.lisp...~%")
  (load "benchmarks/transpiled-fol-code/lsim.lisp")
  (format t "Loading 8bit-100.lisp...~%")
  (load "benchmarks/transpiled-fol-code/8bit-100.lisp")
  (format t "All loaded successfully.~%"))

(sb-ext:exit)
