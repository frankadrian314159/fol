(in-package fol.tests)

(in-suite fol-suite)

(in-readtable fol-syntax)

(test reader-syntax
  "Test that #t and #f reader macros work"

  (is (eq #t *true-instance*))
  (is (eq #f *false-instance*))
  
  ;; Test unwrapping them gives native booleans
  (is (eq (unwrap #t) t))
  (is (eq (unwrap #f) nil)))