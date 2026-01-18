(in-package fol.tests)
(in-readtable fol-syntax)

(in-suite fol-suite)

(test boolean-logic
  (is (eq *true-instance* (not *false-instance*)))
  (is (eq *false-instance* (not *true-instance*)))
  (is (eq *true-instance* (and #t #t)))
  (is (eq *false-instance* (and #t #f)))
  (is (eq *true-instance* (implies #f #t))))