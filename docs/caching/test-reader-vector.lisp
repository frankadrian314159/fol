;;; Test what [x] produces when read

(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

;; Test 1: What does [x] produce?
(format t "~%Test 1: Reading [x] with FOL readtable~%")
(let* ((readtable (fol.compiler.reader:*fol-readtable*))
       (form (fol.compiler.reader:fol-read-from-string "[x]")))
  (format t "  Type: ~A~%" (type-of form))
  (format t "  Value: ~A~%" form)
  (format t "  fol-vector-p: ~A~%" (fol.compiler::fol-vector-p form))
  (when (cl:listp form)
    (format t "  List contents: ~A~%" form)))

;; Test 2: What does the quoted form contain?
(format t "~%Test 2: What does quoted form contain~%")
(let ((form '(defn test-simple [x]
              (cond
                ((integer? x) (* x 2))
                (t "default")))))
  (format t "  Form: ~S~%" form)
  (format t "  Third element type: ~A~%" (type-of (third form)))
  (format t "  Is it a vector? ~A~%" (vectorp (third form)))
  (format t "  Is it a FOL vector? ~A~%" (fol.compiler::fol-vector-p (third form))))

;; Test 3: Manually create the expected form
(format t "~%Test 3: Creating form with #(x)~%")
(let ((form `(defn test-simple #(x)
              (cond
                ((integer? x) (* x 2))
                (t "default")))))
  (format t "  Form created~%")
  (format t "  Third element: ~A~%" (third form))
  (format t "  Is it a vector? ~A~%" (vectorp (third form)))
  (let ((result (fol.compiler:compile-form form)))
    (format t "  Compilation result: ~A~%" (fol.compiler:compilation-result-p result))
    (format t "  Code: ~A~%" (fol.compiler:compilation-result-code result))
    (format t "  Errors: ~A~%" (fol.compiler:compilation-result-errors result))))

(quit)
