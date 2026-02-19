(in-package :cl-user)

(let ((compile-script (merge-pathnames "compile-file.lisp" (or *compile-file-truename* *load-truename*))))
  (unless (probe-file compile-script)
    (setf compile-script #p"c:/Users/frank/Projects/FOL/fol/benchmarks/boilerplate/compile-file.lisp"))
  (load compile-script))

(compile-fol-file #p"c:/Users/frank/Projects/FOL/fol/benchmarks/fol-code/compliance.fol"
                  #p"c:/Users/frank/Projects/FOL/fol/benchmarks/transpiled-fol-code/compliance.lisp")
