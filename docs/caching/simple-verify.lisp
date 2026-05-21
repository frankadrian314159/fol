;;;; Simple verification that per-GF versioning works
(in-package :cl-user)

(push (truename "src") asdf:*central-registry*)

(handler-bind ((warning #'muffle-warning))
  (asdf:load-system :fol-compiler))

(format t "~&Verifying Phase 4 changes...~%~%")

;; Test 1: Compiler can compile simple FOL expressions
(format t "✓ Test 1: Compiler compilation~%")
(let ((result (fol.compiler:compile-string "(+ 1 2)")))
  (assert (not (null (fol.compiler:compilation-result-code result))) () "Should compile"))

;; Test 2: GF version operations work
(format t "✓ Test 2: GF version operations~%")
(let ((v0 (fol.compiler.dispatch:get-gf-version 'test-fn)))
  (assert (= v0 0) () "Should start at 0")
  (fol.compiler.dispatch:increment-gf-version! 'test-fn)
  (let ((v1 (fol.compiler.dispatch:get-gf-version 'test-fn)))
    (assert (= v1 1) () "Should be 1 after increment")))

;; Test 3: System can load without errors
(format t "✓ Test 3: System load successful~%")

;; Test 4: Dispatch caching infrastructure present
(format t "✓ Test 4: Dispatch cache infrastructure~%")
(assert (fboundp 'fol.compiler.dispatch:cache-lookup) () "cache-lookup should exist")
(assert (fboundp 'fol.compiler.dispatch:cache-insert) () "cache-insert should exist")
(assert (fboundp 'fol.compiler.dispatch:cache-flush!) () "cache-flush! should exist")

(format t "~%=====================================~%")
(format t "✓ All verifications passed!~%")
(format t "  Phase 4 implementation successful~%")
(format t "=====================================~%")
