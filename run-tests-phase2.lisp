;;; Test Phase 2 Dispatch Caching Implementation

(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler/tests)

;; Run the test suite
(fol.compiler.tests:run-compiler-tests)
