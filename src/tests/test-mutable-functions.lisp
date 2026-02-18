;;; FOL Compiler - Mutable Functions Tests (Part 2)

(in-package :fol.compiler.tests)

(in-suite mutable-functions-tests)

;;; Validators

(test atom-validator-test
  (let ((a (fol.compiler.mutable:atom 0 :validator #'evenp)))
    (is (eql 0 (fol.compiler.mutable:deref a)))
    (fol.compiler.mutable:reset! a 2)
    (is (eql 2 (fol.compiler.mutable:deref a)))
    (signals error (fol.compiler.mutable:reset! a 3))
    (is (eql 2 (fol.compiler.mutable:deref a)))))

(test ref-validator-dynamic-test
  (let ((r (fol.compiler.mutable:ref 0)))
    (fol.compiler.mutable-functions:set-validator! r #'evenp)
    (fol.compiler.mutable:dosync
      (fol.compiler.mutable:ref-set r 2))
    (signals error
      (fol.compiler.mutable:dosync
        (fol.compiler.mutable:ref-set r 3)))))

;;; Watchers

(test atom-watch-test
  (let ((a (fol.compiler.mutable:atom 0))
        (notifications nil))
    (fol.compiler.mutable-functions:add-watch a :key 
      (lambda (k r old new)
        (declare (ignore k r))
        (push (list old new) notifications)))
    (fol.compiler.mutable:reset! a 1)
    (is (equal notifications '((0 1))))
    (fol.compiler.mutable:swap! a #'1+)
    (is (equal notifications '((1 2) (0 1))))
    (fol.compiler.mutable-functions:remove-watch a :key)
    (fol.compiler.mutable:reset! a 3)
    (is (equal notifications '((1 2) (0 1))))))

;;; STM Extensions

(test io!-test
  (signals error
    (fol.compiler.mutable:dosync
      (fol.compiler.mutable-functions:io!
        (print "Should fail"))))
  (is (eq t (fol.compiler.mutable-functions:io! t))))

(test sync-macro-test
  (let ((r (fol.compiler.mutable:ref 0)))
    (fol.compiler.mutable-functions:sync nil
      (fol.compiler.mutable:ref-set r 1))
    (is (eql 1 (fol.compiler.mutable:deref r)))))

;;; Agent Extensions

(test await-for-test
  (let ((a (fol.compiler.mutable:agent 0)))
    (fol.compiler.mutable:send a (lambda (x) (sleep 0.1) (1+ x)))
    ;; Wait sufficient time
    (is (eq t (fol.compiler.mutable-functions:await-for 2000 a)))
    (is (eql 1 (fol.compiler.mutable:deref a)))))

(test executor-stubs
  (is (null (fol.compiler.mutable-functions:set-agent-send-executor! nil)))
  (is (null (fol.compiler.mutable-functions:shutdown-agents))))
