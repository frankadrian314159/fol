;;; FOL Compiler - Mutable Functions Tests

(in-package :fol.compiler.tests)

(in-suite mutable-functions-tests)

;;; Atom Extensions

(test swap-vals-test
  (let ((a (fol.compiler.mutable-functions:atom 10)))
    (let ((result (fol.compiler.mutable-functions:swap-vals! a #'+ 5)))
      (is (equal result '(10 15)))
      (is (= 15 (fol.compiler.mutable-functions:deref a))))))

(test reset-vals-test
  (let ((a (fol.compiler.mutable-functions:atom 10)))
    (let ((result (fol.compiler.mutable-functions:reset-vals! a 20)))
      (is (equal result '(10 20)))
      (is (= 20 (fol.compiler.mutable-functions:deref a))))))

;;; Futures

(test future-basic-test
  (let ((f (fol.compiler.mutable-functions:future (+ 1 2))))
    (is (fol.compiler.mutable-functions:future? f))
    (is (= 3 (fol.compiler.mutable-functions:deref f)))))

(test future-async-test
  (let ((f (fol.compiler.mutable-functions:future (sleep 0.1) :done)))
    ;; Should not be done immediately (conceptually, though sleep might be fast)
    ;; Actually checking if it eventually complete.
    (is (eq :done (fol.compiler.mutable-functions:deref f)))))

(test future-error-test
  (let ((f (fol.compiler.mutable-functions:future (error "Failure"))))
    (signals error (fol.compiler.mutable-functions:deref f))))

(test future-cancel-test
  (let ((f (fol.compiler.mutable-functions:future (sleep 2) :done)))
    (is (fol.compiler.mutable-functions:future-cancel f))
    (is (fol.compiler.mutable-functions:future-cancelled? f))
    (signals error (fol.compiler.mutable-functions:deref f))))

;;; Promises

(test promise-basic-test
  (let ((p (fol.compiler.mutable-functions:promise)))
    (fol.compiler.mutable-functions:deliver p :delivered)
    (is (eq :delivered (fol.compiler.mutable-functions:deref p)))))

(test promise-async-test
  (let ((p (fol.compiler.mutable-functions:promise)))
    (fol.compiler.mutable-functions:future
      (sleep 0.1)
      (fol.compiler.mutable-functions:deliver p :async-result))
    (is (eq :async-result (fol.compiler.mutable-functions:deref p)))))

(test promise-deliver-once-test
  (let ((p (fol.compiler.mutable-functions:promise)))
    (fol.compiler.mutable-functions:deliver p 1)
    (fol.compiler.mutable-functions:deliver p 2)
    (is (= 1 (fol.compiler.mutable-functions:deref p)))))

;;; Parallel Processing

(test pvalues-test
  (let ((result (fol.compiler.mutable-functions:pvalues (+ 1 1) (+ 2 2))))
    (is (equal result '(2 4)))))

(test pmap-test
  ;; Use small list to avoid heavy threading overhead in test
  (let ((result (fol.compiler.mutable-functions:pmap #'1+ '(1 2 3))))
    (is (equal result '(2 3 4)))))

;;; Thread Bindings (Placeholder check)

(test thread-bindings-placeholder
  ;; Just verify bound-fn macro expands and compiles
  (let ((f (fol.compiler.mutable-functions:bound-fn () 42)))
    (is (= 42 (funcall f)))))
