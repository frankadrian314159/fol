;;; Minimal test of FOL collection creation

(in-package :cl-user)

;; Load FOL compiler
(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

;; Create a package for the FOL code
(defpackage :test-fol
  (:use :cl)
  (:shadowing-import-from :fol.compiler.collection-functions
                vector first rest conj size empty?)
  (:import-from :fol.compiler.collections
                <vector>)
  (:import-from :fol.compiler.string-functions
                str))

(in-package :test-fol)

(defun compile-and-eval-fol-expr (expr-str)
  "Compile and evaluate a single FOL expression."
  (let* ((*readtable* fol.compiler.reader:*fol-readtable*)
         (form (read-from-string expr-str))
         (result (fol.compiler:compile-form form)))
    (when (fol.compiler:compilation-result-errors result)
      (format t "~%COMPILATION ERRORS:~%")
      (dolist (err (fol.compiler:compilation-result-errors result))
        (format t "  ~A~%" err))
      (error "FOL compilation failed"))
    (let ((code (fol.compiler:compilation-result-code result)))
      (eval code))))

(format t "Testing simple FOL vector creation...~%")
(let ((v (compile-and-eval-fol-expr "[1 2 3]")))
  (format t "Vector created: ~A~%" v)
  (format t "Type: ~A~%" (type-of v))
  (format t "Size using collection-size: ~D~%"
          (fol.compiler.collections:collection-size v))
  (format t "Size using size function: ~D~%"
          (fol.compiler.collection-functions:size v)))

(format t "~%Testing vector with dicts...~%")
(let ((v (compile-and-eval-fol-expr "[{:a 1} {:b 2}]")))
  (format t "Vector created: ~A~%" v)
  (format t "Size: ~D~%" (fol.compiler.collection-functions:size v)))

(format t "~%Success!~%")
(sb-ext:quit)
