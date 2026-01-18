(in-package fol.tests)
(in-readtable fol-syntax)

(in-suite fol-suite)

(test wrapers 
      (is (eq *true-instance* (wrap t)))
      (is (eq *false-instance* (wrap nil)))
      (is (eq *true-instance* (wrap (wrap t))))
      (is (eq *false-instance* (wrap (wrap nil))))
      (is (eq t (unwrap *true-instance*)))
      (is (eq nil (unwrap *false-instance*)))
      (is (eq t (unwrap (unwrap t))))
      (is (eq nil (unwrap (unwrap nil))))
      (is (eq t (unwrap (unwrap *true-instance*))))
      (is (eq nil (unwrap (unwrap *false-instance*))))
      (is (equal '(t nil 42 10000000000000000000 3/4 #C(1 2) #C(3.0 4.0))
             (mapcar #'unwrap
                (mapcar #'wrap
                    '(t nil 42 10000000000000000000 3/4 #C(1 2) #C(3.0 4.0)))))))