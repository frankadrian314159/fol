(require :asdf)
(push (truename "c:/Users/frank/Projects/FOL/fol/src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(in-package :fol.core)

(defun run-debug ()
  (let ((form '(do (def acc (atom 0))
                   (fol.macros::dotimes (i 3) (swap! acc (fn [a] (+ a 1))))
                 @acc)))
    (let* ((transpiled (fol.compiler:compile-form form))
           (code (fol.compiler:compilation-result-code transpiled))
           (errors (fol.compiler:compilation-result-errors transpiled)))
      (if errors
          (format t "Errors: ~S~%" errors)
          (progn
           (format t "Generated code: ~S~%" code)
           (let ((res (eval code)))
             (format t "Result: ~S~%" res)))))))

(run-debug)
