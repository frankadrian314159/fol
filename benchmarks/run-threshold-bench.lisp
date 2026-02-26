(require :asdf)
(pushnew #p"c:/Users/frank/Projects/FOL/fol/src/" asdf:*central-registry*)

(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file quicklisp-init)
      (load quicklisp-init)
      (format t "Quicklisp not found.~%")))

(dolist (dep '(:fset :sycamore :closer-mop :uuid :bordeaux-threads :usocket :cl-ppcre))
  (if (find-package :ql)
      (uiop:symbol-call :ql :quickload dep :silent t)
      (asdf:load-system dep)))

(asdf:load-system :fol-compiler)

(load "benchmarks/boilerplate/boilerplate.lisp")
(load "benchmarks/micro/threshold-bench.lisp")

(fol.benchmarks.threshold:run-threshold-benchmarks)
(sb-ext:exit :code 0)
