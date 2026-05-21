;;; Debug Phase 2 caching implementation

(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(format t "~%=== Debugging Phase 2 Dispatch Caching ===~%~%")

;;; Test what gets generated
(format t "Test: Compiling a simple defn...~%")
(let ((result (fol.compiler:compile-form
               '(defn test-simple [x]
                  (cond
                    ((integer? x) (* x 2))
                    ((string? x) (str x "!"))
                    ((vector? x) (count x))
                    (t "unknown"))))))
  (format t "  Result type: ~A~%" (type-of result))
  (format t "  Result: ~A~%" result)

  (when (fol.compiler:compilation-result-p result)
    (let ((code (fol.compiler:compilation-result-code result))
          (errors (fol.compiler:compilation-result-errors result))
          (warnings (fol.compiler:compilation-result-warnings result)))
      (format t "  Code: ~A~%" code)
      (format t "  Errors: ~A~%" errors)
      (format t "  Warnings: ~A~%" warnings))))

(format t "~%Test: Check if dispatch caching code is being generated...~%")
(let ((result (fol.compiler:compile-form '(defn multi [x]
  (cond
    ((integer? x) x)
    ((string? x) x)
    ((vector? x) x)
    ((float? x) x)
    (t x))))))
  (when (fol.compiler:compilation-result-p result)
    (let ((code (fol.compiler:compilation-result-code result)))
      (if (listp code)
          (format t "  Generated code is a list~%")
          (format t "  Generated code is not a list: ~A~%" (type-of code)))
      (if code
          (format t "  Code starts with: ~A...~%" (first code))
          (format t "  Code is NIL~%")))))

(quit)
