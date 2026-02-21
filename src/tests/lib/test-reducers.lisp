(in-package :fol.compiler.tests.lib)

(def-suite reducers-tests
  :description "Tests for the reducers library"
  :in lib-tests)

(in-suite reducers-tests)

(test test-preduce
  (is (= 10 (fol.lib.reducers:preduce #'+ 0 '(1 2 3 4))))
  (is (= 0 (fol.lib.reducers:preduce #'+ 0 '()))))

(test test-fold
  ;; Using identity factories as Clojure reducers do
  (let ((add-fn (lambda (&optional (x nil x-p) (y nil y-p))
                  (cond ((and (not x-p) (not y-p)) 0)
                        ((and x-p (not y-p)) x)
                        (t (+ x y))))))
    ;; Small collection (serial path)
    (is (= 5050 (fol.lib.reducers:fold add-fn add-fn (loop for i from 1 to 100 collect i) 200)))
    ;; Large collection (parallel path)
    (is (= 5050 (fol.lib.reducers:fold add-fn add-fn (loop for i from 1 to 100 collect i) 10)))))
