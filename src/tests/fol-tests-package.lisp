;;; FOL-Level Test System
;;;
;;; Standalone test system for end-to-end FOL-level tests.
;;; Tests are written in FOL syntax in src/tests/fol-code/.
;;; Each .fol file is read, compiled, and evaluated; any assertion
;;; failure or error is reported and causes the test to fail.

(defpackage :fol.compiler.fol-tests
  (:use :cl :fiveam)
  (:export :run-fol-tests :load-and-run-fol-test))
