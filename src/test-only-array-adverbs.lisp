;;; Test only array-functions and adverbs, skip test-persistence

(push (truename ".") asdf:*central-registry*)

(asdf:load-system :fol-compiler)

;;; Load only the test infrastructure and specific test files
(asdf:load-system :fiveam)

(in-package :fol.compiler.tests)

;;; Load test infrastructure
(load "tests/compiler-tests-package.lisp")

;;; Load only array-functions and adverbs tests
(load "tests/test-array-functions.lisp")
(load "tests/test-adverbs.lisp")

;;; Run tests
(fiveam:run! 'array-functions-suite)
(fiveam:run! 'adverbs-suite)

(format t "~%All tests completed!~%")
