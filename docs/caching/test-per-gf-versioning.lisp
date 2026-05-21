;;;; Test Per-GF Versioning Functionality
;;;; Quick verification that per-GF version registry works correctly

(in-package :cl-user)

(defun test-per-gf-versioning ()
  "Test per-GF version registry and increment functions."
  (let ((fol.compiler.dispatch (find-package :fol.compiler.dispatch)))
    (unless fol.compiler.dispatch
      (error "fol.compiler.dispatch package not found. Load fol-compiler first."))

    ;; Test 1: get-gf-version returns 0 for unknown GFs
    (let ((get-gf-version (find-symbol "GET-GF-VERSION" fol.compiler.dispatch)))
      (assert (= (funcall get-gf-version 'my-gf-1) 0)
              () "GET-GF-VERSION should return 0 for unknown GF"))

    ;; Test 2: increment-gf-version! increments the version
    (let ((increment-gf-version! (find-symbol "INCREMENT-GF-VERSION!" fol.compiler.dispatch))
          (get-gf-version (find-symbol "GET-GF-VERSION" fol.compiler.dispatch)))
      (funcall increment-gf-version! 'my-gf-2)
      (assert (= (funcall get-gf-version 'my-gf-2) 1)
              () "increment-gf-version! should increment to 1"))

    ;; Test 3: Multiple increments work correctly
    (let ((increment-gf-version! (find-symbol "INCREMENT-GF-VERSION!" fol.compiler.dispatch))
          (get-gf-version (find-symbol "GET-GF-VERSION" fol.compiler.dispatch)))
      (funcall increment-gf-version! 'my-gf-3)
      (funcall increment-gf-version! 'my-gf-3)
      (funcall increment-gf-version! 'my-gf-3)
      (assert (= (funcall get-gf-version 'my-gf-3) 3)
              () "Multiple increments should work"))

    ;; Test 4: Different GFs have independent versions
    (let ((get-gf-version (find-symbol "GET-GF-VERSION" fol.compiler.dispatch)))
      (assert (= (funcall get-gf-version 'gf-a) 0) () "GF-A should be 0")
      (assert (= (funcall get-gf-version 'gf-b) 0) () "GF-B should be 0"))

    ;; Test 5: make-versioned-cache-key includes versions
    (let ((make-versioned-cache-key (find-symbol "MAKE-VERSIONED-CACHE-KEY" fol.compiler.dispatch)))
      (let ((key (funcall make-versioned-cache-key '(class-a class-b) '(gf-x gf-y))))
        (assert (consp key) () "Cache key should be a cons")
        (assert (consp (car key)) () "First element of key should be version list")))

    (format t "~&✓ All per-GF versioning tests passed!~%")))

(format t "~&Per-GF versioning basic tests complete.~&")
