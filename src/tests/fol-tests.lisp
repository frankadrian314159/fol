(in-package :fol.compiler.tests)

(in-suite fol-level-tests)

(defun load-and-run-fol-test (filename)
  (format t "Running FOL test: ~A... " filename)
  (let* ((path (asdf:system-relative-pathname :fol-compiler (format nil "tests/fol-code/~A" filename)))
         (results nil))
    (with-open-file (s path)
      (let ((*package* (find-package :fol.core)))
        (loop for form = (fol.compiler.reader:fol-read s nil :eof)
              while (not (eq form :eof))
              do (handler-case
                     (let* ((transpiled (fol.compiler:compile-form form))
                            (code (fol.compiler:compilation-result-code transpiled))
                            (errors (fol.compiler:compilation-result-errors transpiled)))
                       (if errors
                           (push (list :compilation-error form errors) results)
                           (handler-case
                               (eval code)
                             (error (e)
                               (push (list :runtime-error form e) results)))))
                   (error (e)
                     (push (list :reader-error form e) results))))))
    (if results
        (progn
          (format t "FAILED~%")
          (dolist (res results)
            (format t "  Error in form ~S:~%    ~A~%" (second res) (third res)))
          nil)
        (progn
          (format t "PASSED~%")
          t))))

(test run-fol-tests
  "Run all FOL-level tests."
  (let ((tests '("reader_syntax_test.fol" "special_forms_test.fol" "macros_test.fol" "functions_test.fol" "negative_test.fol" "arithmetic_test.fol" "bitwise_test.fol" "collection_functions_test.fol" "collections_test.fol" "compareops_test.fol" "compiler_test.fol" "destructure_test.fol" "functional_test.fol" "logical_operations_test.fol" "merged_functions_test.fol" "metadata_test.fol" "misc_test.fol" "mutable_test.fol" "primitive_functions_test.fol" "primitives_test.fol" "reader_test.fol" "relational_test.fol" "repl_test.fol")))
    (dolist (test tests)
      (is (load-and-run-fol-test test)))))
