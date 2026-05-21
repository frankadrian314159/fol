;;; Compile and run FOL method dispatch benchmark

(push #p"C:/Users/frank/Projects/FOL/fol/src/" asdf:*central-registry*)

;; Load FOL compiler
(asdf:load-system :fol-compiler)

;; Compile the FOL benchmark
(format t "~&Compiling and running FOL method dispatch benchmark...~%")

(let ((fol-source (with-open-file (f "method-dispatch-bench.fol")
                    (uiop:slurp-stream-string f))))
  (format t "~&Running benchmark:~%~%")
  (fol.repl:run-fol-string fol-source))
