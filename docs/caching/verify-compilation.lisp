;;;; Verify FOL compiler still works after dispatch caching changes
(in-package :cl-user)

(push (truename "src") asdf:*central-registry*)

(handler-bind ((warning #'muffle-warning))
  (asdf:load-system :fol-compiler))

;; Test 1: Simple FOL compilation
(format t "~&Test 1: Simple FOL compilation...~%")
(let* ((fol-code "(+ 1 2)")
       (result (fol.compiler:compile-string fol-code))
       (code (fol.compiler:compilation-result-code result)))
  (format t "  Compiled successfully~%")
  (format t "  Code: ~A~%" code)
  (let ((val (eval code)))
    (format t "  Evaluated to: ~A~%" val)
    (assert (= val 3) () "Should evaluate to 3")))

;; Test 2: Function definition with if/cond
(format t "~&Test 2: Function definition with conditionals...~%")
(let* ((fol-code "
(defn double [x]
  (if (number? x)
    (* x 2)
    x))
")
       (result (fol.compiler:compile-string fol-code))
       (code (fol.compiler:compilation-result-code result)))
  (format t "  Compiled successfully~%")
  (eval code)
  (let* ((double-fn (find-symbol "DOUBLE" (find-package :fol.core)))
         (result (funcall double-fn 21)))
    (format t "  (double 21) = ~A~%" result)
    (assert (= result 42) () "Should double the number")))

;; Test 3: Verify per-GF version registry exists
(format t "~&Test 3: Per-GF versioning registry...~%")
(let ((registry (fol.compiler.dispatch:*gf-version-registry*)))
  (format t "  Registry exists: ~A~%" (not (null registry)))
  (assert registry () "Registry should exist"))

;; Test 4: Get and increment GF version
(format t "~&Test 4: GF version operations...~%")
(let ((v1 (fol.compiler.dispatch:get-gf-version 'test-gf)))
  (format t "  Initial version of test-gf: ~A~%" v1)
  (assert (= v1 0) () "Should start at 0")

  (fol.compiler.dispatch:increment-gf-version! 'test-gf)
  (let ((v2 (fol.compiler.dispatch:get-gf-version 'test-gf)))
    (format t "  After increment: ~A~%" v2)
    (assert (= v2 1) () "Should be 1 after increment")))

(format t "~%✓ All verification tests passed!~%")
