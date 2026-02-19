(require :asdf)
(push (truename "src/") asdf:*central-registry*)
(handler-case
    (asdf:load-system :fol-compiler)
  (error (c)
    (format t "ASDF Error: ~A~%" c)
    (sb-ext:quit)))

(format t "Compiling...~%")
(handler-case
    (fol.compiler:compile-file "benchmarks/fol-code/compliance.fol" :output "transpiled-fol-code/compliance_new.lisp")
  (error (c)
    (format t "Compile Error: ~A~%" c)
    (sb-debug:print-backtrace)
    (sb-ext:quit)))
(format t "Success.~%")
(sb-ext:quit)
