;;; Simple test of defn parsing issue

(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(format t "~%=== Debugging defn Parser Issue ===~%~%")

;; Test 1: Using standard CL vector syntax #(...)
(format t "Test 1: Defn with #(x) vector syntax~%")
(let ((form `(defn test-with-cl-vector #(x)
              (cond
                ((integer? x) (* x 2))
                (t "default")))))
  (format t "  Creating form with: ~S~%" form)
  (let ((result (fol.compiler:compile-form form)))
    (format t "  Errors: ~A~%" (fol.compiler:compilation-result-errors result))
    (if (fol.compiler:compilation-result-code result)
        (format t "  SUCCESS: Code generated~%")
        (format t "  FAIL: No code generated~%"))))

;; Test 2: Try with a list instead of vector
(format t "~%Test 2: Defn with (x) list syntax (should fail gracefully)~%")
(let ((form `(defn test-with-list (x)
              (cond
                ((integer? x) (* x 2))
                (t "default")))))
  (format t "  Creating form with: ~S~%" form)
  (let ((result (fol.compiler:compile-form form)))
    (format t "  Errors: ~A~%" (fol.compiler:compilation-result-errors result))))

;; Test 3: Multi-clause syntax (should work)
(format t "~%Test 3: Defn with multi-clause syntax~%")
(let ((form `(defn test-multi-clause
              (#(x)
               (cond
                 ((integer? x) (* x 2))
                 (t "default")))
              (#(x y)
               (+ x y)))))
  (format t "  Creating form with multi-clause syntax~%")
  (let ((result (fol.compiler:compile-form form)))
    (format t "  Errors: ~A~%" (fol.compiler:compilation-result-errors result))
    (if (fol.compiler:compilation-result-code result)
        (format t "  SUCCESS: Code generated~%")
        (format t "  FAIL: No code generated~%"))))

(quit)
