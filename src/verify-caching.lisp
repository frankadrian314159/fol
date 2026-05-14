(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

;; Test that we can compile a simple multi-clause function
(let* ((code "(defn dispatch-test ([x integer?] (+ x 1)) ([x float?] (* x 2.0)))")
       (parsed (fol.compiler:compile-fol-string code)))
  (format t "~%Compilation successful!~%")
  (format t "Generated code contains cache: ~A~%"
          (if (search "DISPATCH-CACHE" (fol.compiler:compilation-result-code parsed))
              "YES" "NO")))