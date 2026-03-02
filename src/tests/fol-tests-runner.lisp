;;; FOL-Level Test Runner
;;;
;;; Reads each .fol file listed below, compiles every top-level form
;;; through the FOL compiler, and evaluates the result.  Any assertion
;;; failure or unhandled error causes the enclosing FiveAM test to fail.

(in-package :fol.compiler.fol-tests)

(def-suite fol-tests
           :description "End-to-end tests written in FOL syntax.")

;;; -------------------------------------------------------------------------
;;; Core runner
;;; -------------------------------------------------------------------------

(defun load-and-run-fol-test (filename)
  "Compile and evaluate every form in FILENAME (relative to tests/fol-code/).
Returns T on success; prints error details and returns NIL on failure."
  (format t "Running FOL test: ~A... " filename)
  (let* ((path (asdf:system-relative-pathname
                 :fol-compiler
                 (format nil "tests/fol-code/~A" filename)))
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
         (dolist (r results)
           (format t "  ~A in ~S:~%    ~A~%" (first r) (second r) (third r)))
         nil)
        (progn
         (format t "PASSED~%")
         t))))

;;; -------------------------------------------------------------------------
;;; Test definitions
;;; -------------------------------------------------------------------------

(in-suite fol-tests)

(test arithmetic-functions
      "FOL-level tests for arithmetic-functions.lisp."
      (is (load-and-run-fol-test "arithmetic_test.fol")))

(test bitwise-functions
      "FOL-level tests for bitwise-operation-functions.lisp."
      (is (load-and-run-fol-test "bitwise_test.fol")))

(test collection-functions
      "FOL-level tests for collection-functions.lisp."
      (is (load-and-run-fol-test "collection_functions_test.fol")))

(test collections
      "FOL-level tests for collections.lisp."
      (is (load-and-run-fol-test "collections_test.fol")))

(test compareops
      "FOL-level tests for compareops.lisp."
      (is (load-and-run-fol-test "compareops_test.fol")))

(test compiler
      "FOL-level tests for compiler.lisp."
      (is (load-and-run-fol-test "compiler_test.fol")))

(test destructure
      "FOL-level tests for destructure.lisp."
      (is (load-and-run-fol-test "destructure_test.fol")))

(test functional
      "FOL-level tests for functional.lisp."
      (is (load-and-run-fol-test "functional_test.fol")))

(test logical-operations
      "FOL-level tests for logical-operation-functions.lisp."
      (is (load-and-run-fol-test "logical_operations_test.fol")))

(test macros
      "FOL-level tests for macros.lisp."
      (is (load-and-run-fol-test "macros_test.fol")))

(test merged-functions
      "FOL-level tests for merged-functions.lisp."
      (is (load-and-run-fol-test "merged_functions_test.fol")))

(test metadata
      "FOL-level tests for metadata.lisp."
      (is (load-and-run-fol-test "metadata_test.fol")))

(test misc-functions
      "FOL-level tests for misc-functions.lisp."
      (is (load-and-run-fol-test "misc_test.fol")))

(test mutable-functions
      "FOL-level tests for mutable-functions.lisp."
      (is (load-and-run-fol-test "mutable_test.fol")))

(test primitive-functions
      "FOL-level tests for primitive-functions.lisp."
      (is (load-and-run-fol-test "primitive_functions_test.fol")))

(test primitives
      "FOL-level tests for primitives.lisp."
      (is (load-and-run-fol-test "primitives_test.fol")))

(test reader
      "FOL-level tests for reader.lisp."
      (is (load-and-run-fol-test "reader_test.fol")))

;;; -------------------------------------------------------------------------
;;; Entry point
;;; -------------------------------------------------------------------------

(defun run-fol-tests ()
  "Run all FOL-level tests. Returns T if every test passes."
  (run! 'fol-tests))
