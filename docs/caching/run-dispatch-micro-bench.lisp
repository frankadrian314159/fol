;; Test runner for FOL micro-benchmark (with caching)
(defun slurp (stream)
  "Read entire file contents as string"
  (let ((seq (make-string (file-length stream))))
    (read-sequence seq stream)
    seq))

(push #p"c:/Users/frank/Projects/FOL/fol/src/" asdf:*central-registry*)
(format t "~&Loading FOL compiler...~%")
(asdf:load-system :fol-compiler)
(asdf:load-system :fol-compiler/core)

(format t "~&Compiling FOL micro-benchmark...~%")
(let* ((fol-file #p"c:/Users/frank/Projects/FOL/fol/benchmarks/dispatch-micro-bench.fol")
       (code (with-open-file (s fol-file) (slurp s)))
       (result (fol.repl:compile-fol-string code)))
  (if (fol.compiler:compilation-result-errors result)
      (format t "~&Compilation FAILED: ~A~%" (fol.compiler:compilation-result-errors result))
      (format t "~&Compilation OK~%"))
  (format t "~&Executing FOL micro-benchmark (with dispatch caching)...~%~%")
  (eval (fol.compiler:compilation-result-code result)))

(sb-ext:quit :unix-status 0)
