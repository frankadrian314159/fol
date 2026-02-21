(require :asdf)
(pushnew (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(defun transpile (src dst)
  (format t "Transpiling ~A to ~A...~%" src dst)
  (fol.compiler:compile-file src :output dst)
  (format t "Done.~%"))

(transpile "benchmarks/fol-code/lsim.fol" "benchmarks/transpiled-fol-code/lsim.lisp")
(transpile "benchmarks/fol-code/8bit-100.fol" "benchmarks/transpiled-fol-code/8bit-100.lisp")
(transpile "benchmarks/fol-code/32bit-300.fol" "benchmarks/transpiled-fol-code/32bit-300.lisp")
(transpile "benchmarks/fol-code/8x32-900.fol" "benchmarks/transpiled-fol-code/8x32-900.lisp")
(transpile "benchmarks/fol-code/compliance.fol" "benchmarks/transpiled-fol-code/compliance.lisp")

(sb-ext:exit :code 0)
