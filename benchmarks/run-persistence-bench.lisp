(require :asdf)
(pushnew #p"c:/Users/frank/Projects/FOL/fol/src/" asdf:*central-registry*)

;; Load dependencies
(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file quicklisp-init)
      (load quicklisp-init)
      (format t "Quicklisp not found.~%")))

(dolist (dep '(:fset :sycamore :closer-mop :uuid :bordeaux-threads :usocket :cl-ppcre :fiveam))
  (if (find-package :ql)
      (uiop:symbol-call :ql :quickload dep)
      (asdf:load-system dep)))

;; Minimal system loading to avoid full compiler overhead if not needed,
;; but persistence-overhead.lisp uses fol.compiler.persistent.
(asdf:load-system :fol-compiler)

(load "benchmarks/boilerplate/boilerplate.lisp")
(load "benchmarks/micro/persistence-overhead.lisp")

(fol.benchmarks.persistence:run-persistence-benchmarks)
(sb-ext:exit :code 0)
