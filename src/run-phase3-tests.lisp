(push (truename ".") asdf:*central-registry*)

(asdf:load-system :fol-compiler)
(asdf:load-system :fiveam)

(in-package :fol.compiler.tests)

;;; Load test infrastructure
(load "tests/compiler-tests-package.lisp")

;;; Load phase 3 tests
(load "tests/test-advanced-array-operations.lisp")

;;; Run tests
(fiveam:run! 'advanced-array-operations-suite)

(format t "~%All Phase 3 tests completed!~%")
