;; Test runner for FOL realistic benchmark (with caching)
(defun slurp (stream)
  "Read entire file contents as string"
  (let ((seq (make-string (file-length stream))))
    (read-sequence seq stream)
    seq))

(push #p"c:/Users/frank/Projects/FOL/fol/src/" asdf:*central-registry*)
(format t "~&Loading FOL compiler...~%")
(asdf:load-system :fol-compiler)
(asdf:load-system :fol-compiler/core)

(format t "~&Compiling FOL realistic benchmark...~%")
(let* ((fol-file #p"c:/Users/frank/Projects/FOL/fol/benchmarks/dispatch-realistic-bench.fol")
       (code (with-open-file (s fol-file) (slurp s)))
       (result (fol.repl:compile-fol-string code)))
  (format t "~&Compilation status: ~A~%" (fol.compiler:compilation-result-status result))
  (format t "~&Executing FOL realistic benchmark (with dispatch caching)...~%~%")
  (eval (fol.compiler:compilation-result-code result)))

(sb-ext:quit :unix-status 0)
