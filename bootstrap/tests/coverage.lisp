;;; FOL Test Coverage Utilities
;;; Using SBCL's sb-cover for code coverage analysis

(in-package :fol.tests)

#+sbcl
(eval-when (:compile-toplevel :load-toplevel :execute)
  (require :sb-cover))

;;; ============================================================================
;;; Coverage Configuration
;;; ============================================================================

(defvar *coverage-enabled* nil
  "When T, coverage data is collected during test runs.")

(defvar *coverage-output-dir* nil
  "Directory for HTML coverage reports.")

(defun enable-coverage ()
  "Enable coverage collection. Must be called before loading code to be analyzed."
  #+sbcl
  (progn
    (declaim (optimize sb-cover:store-coverage-data))
    (setf *coverage-enabled* t)
    (format t "~&Coverage collection enabled.~%"))
  #-sbcl
  (warn "Coverage collection is only supported on SBCL."))

(defun disable-coverage ()
  "Disable coverage collection."
  #+sbcl
  (progn
    (declaim (optimize (sb-cover:store-coverage-data 0)))
    (setf *coverage-enabled* nil)
    (format t "~&Coverage collection disabled.~%"))
  #-sbcl
  nil)

(defun reset-coverage ()
  "Reset all coverage data."
  #+sbcl
  (when *coverage-enabled*
    (sb-cover:reset-coverage)
    (format t "~&Coverage data reset.~%"))
  #-sbcl
  nil)

;;; ============================================================================
;;; Coverage Reporting
;;; ============================================================================

(defun generate-coverage-report (&optional (output-dir "coverage-report/"))
  "Generate an HTML coverage report in OUTPUT-DIR."
  #+sbcl
  (when *coverage-enabled*
    (setf *coverage-output-dir* (pathname output-dir))
    (ensure-directories-exist *coverage-output-dir*)
    (sb-cover:report *coverage-output-dir*)
    (format t "~&Coverage report generated in ~A~%" *coverage-output-dir*))
  #-sbcl
  (warn "Coverage reporting is only supported on SBCL."))

(defun coverage-summary ()
  "Print a summary of coverage statistics."
  #+sbcl
  (when *coverage-enabled*
    (format t "~&~%========================================~%")
    (format t "           COVERAGE SUMMARY~%")
    (format t "========================================~%~%")
    (format t "Coverage data collected. Use (generate-coverage-report) to create HTML report.~%")
    (format t "========================================~%~%"))
  #-sbcl
  (warn "Coverage summary is only supported on SBCL."))

;;; ============================================================================
;;; Coverage-enabled Test Runners
;;; ============================================================================

(defun run-fol-tests-with-coverage (&optional (report-dir "coverage-report/"))
  "Run all FOL tests with coverage collection and generate a report."
  #+sbcl
  (progn
    (enable-coverage)
    (reset-coverage)
    ;; Force recompilation to enable coverage
    (asdf:load-system :bootstrap :force t)
    ;; Run tests
    (let ((results (run! 'fol-suite)))
      ;; Print coverage summary
      (coverage-summary)
      ;; Generate HTML report
      (generate-coverage-report report-dir)
      results))
  #-sbcl
  (progn
    (warn "Coverage collection is only supported on SBCL. Running tests without coverage.")
    (run! 'fol-suite)))

(defun run-integration-tests-with-coverage (&optional (report-dir "coverage-report/"))
  "Run integration tests with coverage collection."
  #+sbcl
  (progn
    (enable-coverage)
    (reset-coverage)
    ;; Force recompilation
    (asdf:load-system :fol-integration-tests :force t)
    ;; Run tests
    (let ((results (funcall (find-symbol "RUN-INTEGRATION-TESTS" "FOL.INTEGRATION-TESTS"))))
      (coverage-summary)
      (generate-coverage-report report-dir)
      results))
  #-sbcl
  (progn
    (warn "Coverage collection is only supported on SBCL.")
    (funcall (find-symbol "RUN-INTEGRATION-TESTS" "FOL.INTEGRATION-TESTS"))))
