;;; Simple dispatch test

(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)
(asdf:load-system :fol-compiler/core)

(format t "~%Compiling simple FOL dispatch...~%")

(let ((code "
(defn test-dispatch [x]
  (< x 0) (- x)
  (= x 0) 0
  (< x 1000) (inc x)
  (< x 10000) (+ x 1)
  (< x 100000) (+ x 2)
  (+ x 3))

(format t \"Result 1: ~A~%\" (test-dispatch -5))
(format t \"Result 2: ~A~%\" (test-dispatch 0))
(format t \"Result 3: ~A~%\" (test-dispatch 500))
(format t \"Result 4: ~A~%\" (test-dispatch 5000))
(format t \"Result 5: ~A~%\" (test-dispatch 50000))
(format t \"Result 6: ~A~%\" (test-dispatch 500000))
"))
  (let ((result (fol.repl:compile-fol-string code)))
    (if (fol.compiler:compilation-result-errors result)
        (format t "~&Compilation FAILED: ~A~%" (fol.compiler:compilation-result-errors result))
        (progn
          (format t "~&Compilation OK, executing...~%")
          (eval (fol.compiler:compilation-result-code result))))))

(format t "~%Test completed!~%")
