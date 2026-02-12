;;; FOL Compiler Tests - Mutable References (Atoms, Refs, Agents)

(in-package :fol.compiler.tests)

(in-suite mutable-tests)

;;; ---------------------------------------------------------------------------
;;; Atom creation and predicate
;;; ---------------------------------------------------------------------------

(test atom-class-exists
  "<atom> class is defined."
  (is (find-class 'fol.compiler.mutable:<atom>)))

(test atom-predicate-true
  "<atom>? returns T for atoms."
  (let ((a (fol.compiler.mutable:atom 42)))
    (is (eq t (fol.compiler.mutable:<atom>? a)))))

(test atom-predicate-non-atom
  "<atom>? returns NIL for non-atoms."
  (is (null (fol.compiler.mutable:<atom>? 42)))
  (is (null (fol.compiler.mutable:<atom>? "hello")))
  (is (null (fol.compiler.mutable:<atom>? nil))))

(test atom-default-value-nil
  "atom with no argument defaults to NIL."
  (let ((a (fol.compiler.mutable:atom)))
    (is (null (fol.compiler.mutable:deref a)))))

(test atom-with-initial-value
  "atom with an argument stores that value."
  (let ((a (fol.compiler.mutable:atom 42)))
    (is (eql 42 (fol.compiler.mutable:deref a)))))

;;; ---------------------------------------------------------------------------
;;; Deref
;;; ---------------------------------------------------------------------------

(test deref-returns-value
  "deref returns the current value of an atom."
  (let ((a (fol.compiler.mutable:atom :hello)))
    (is (eq :hello (fol.compiler.mutable:deref a)))))

(test deref-default-returns-obj
  "deref on a non-reference returns the object itself."
  (is (eql 42 (fol.compiler.mutable:deref 42)))
  (is (eq :x (fol.compiler.mutable:deref :x)))
  (is (equal "hi" (fol.compiler.mutable:deref "hi"))))

;;; ---------------------------------------------------------------------------
;;; Reset!
;;; ---------------------------------------------------------------------------

(test reset!-changes-value
  "reset! changes the atom's value."
  (let ((a (fol.compiler.mutable:atom 1)))
    (fol.compiler.mutable:reset! a 2)
    (is (eql 2 (fol.compiler.mutable:deref a)))))

(test reset!-returns-new-value
  "reset! returns the new value."
  (let ((a (fol.compiler.mutable:atom 1)))
    (is (eql 99 (fol.compiler.mutable:reset! a 99)))))

;;; ---------------------------------------------------------------------------
;;; Swap!
;;; ---------------------------------------------------------------------------

(test swap!-applies-fn
  "swap! applies fn to the current value."
  (let ((a (fol.compiler.mutable:atom 10)))
    (fol.compiler.mutable:swap! a #'1+)
    (is (eql 11 (fol.compiler.mutable:deref a)))))

(test swap!-with-extra-args
  "swap! passes extra args to fn."
  (let ((a (fol.compiler.mutable:atom 10)))
    (fol.compiler.mutable:swap! a #'+ 5)
    (is (eql 15 (fol.compiler.mutable:deref a)))))

(test swap!-returns-new-value
  "swap! returns the new value."
  (let ((a (fol.compiler.mutable:atom 10)))
    (is (eql 20 (fol.compiler.mutable:swap! a #'* 2)))))

(test swap!-multiple-updates
  "swap! correctly chains multiple updates."
  (let ((a (fol.compiler.mutable:atom 0)))
    (dotimes (i 100)
      (fol.compiler.mutable:swap! a #'1+))
    (is (eql 100 (fol.compiler.mutable:deref a)))))

;;; ---------------------------------------------------------------------------
;;; Compare-and-set!
;;; ---------------------------------------------------------------------------

(test compare-and-set!-success
  "compare-and-set! succeeds when old matches current value."
  (let ((a (fol.compiler.mutable:atom :old)))
    (is (eq t (fol.compiler.mutable:compare-and-set! a :old :new)))
    (is (eq :new (fol.compiler.mutable:deref a)))))

(test compare-and-set!-failure
  "compare-and-set! fails when old does not match."
  (let ((a (fol.compiler.mutable:atom :current)))
    (is (null (fol.compiler.mutable:compare-and-set! a :wrong :new)))
    (is (eq :current (fol.compiler.mutable:deref a)))))

;;; ---------------------------------------------------------------------------
;;; Print
;;; ---------------------------------------------------------------------------

(test atom-print-object
  "Atoms print as #<ATOM value>."
  (let* ((a (fol.compiler.mutable:atom 42))
         (str (format nil "~A" a)))
    (is (search "ATOM" str))
    (is (search "42" str))))

;;; =========================================================================
;;; Ref (STM) tests
;;; =========================================================================

;;; ---------------------------------------------------------------------------
;;; Ref creation and predicate
;;; ---------------------------------------------------------------------------

(test ref-class-exists
  "<ref> class is defined."
  (is (find-class 'fol.compiler.mutable:<ref>)))

(test ref-predicate-true
  "<ref>? returns T for refs."
  (let ((r (fol.compiler.mutable:ref 42)))
    (is (eq t (fol.compiler.mutable:<ref>? r)))))

(test ref-predicate-non-ref
  "<ref>? returns NIL for non-refs."
  (is (null (fol.compiler.mutable:<ref>? 42)))
  (is (null (fol.compiler.mutable:<ref>? "hello")))
  (is (null (fol.compiler.mutable:<ref>? (fol.compiler.mutable:atom 1)))))

(test ref-initial-value
  "ref stores its initial value."
  (let ((r (fol.compiler.mutable:ref 42)))
    (is (eql 42 (fol.compiler.mutable:deref r)))))

(test ref-deref-outside-dosync
  "deref on a ref works outside dosync."
  (let ((r (fol.compiler.mutable:ref :hello)))
    (is (eq :hello (fol.compiler.mutable:deref r)))))

;;; ---------------------------------------------------------------------------
;;; Ref operations within dosync
;;; ---------------------------------------------------------------------------

(test ref-set-within-dosync
  "ref-set changes the ref's value within dosync."
  (let ((r (fol.compiler.mutable:ref 1)))
    (fol.compiler.mutable:dosync
      (fol.compiler.mutable:ref-set r 99))
    (is (eql 99 (fol.compiler.mutable:deref r)))))

(test ref-set-outside-dosync-errors
  "ref-set signals an error outside dosync."
  (let ((r (fol.compiler.mutable:ref 1)))
    (signals error
      (fol.compiler.mutable:ref-set r 99))))

(test alter-within-dosync
  "alter applies fn to the ref's value within dosync."
  (let ((r (fol.compiler.mutable:ref 10)))
    (fol.compiler.mutable:dosync
      (fol.compiler.mutable:alter r #'1+))
    (is (eql 11 (fol.compiler.mutable:deref r)))))

(test alter-with-args
  "alter passes extra args to fn."
  (let ((r (fol.compiler.mutable:ref 10)))
    (fol.compiler.mutable:dosync
      (fol.compiler.mutable:alter r #'+ 5 3))
    (is (eql 18 (fol.compiler.mutable:deref r)))))

(test alter-outside-dosync-errors
  "alter signals an error outside dosync."
  (let ((r (fol.compiler.mutable:ref 10)))
    (signals error
      (fol.compiler.mutable:alter r #'1+))))

(test commute-within-dosync
  "commute updates the ref's value within dosync."
  (let ((r (fol.compiler.mutable:ref 10)))
    (fol.compiler.mutable:dosync
      (fol.compiler.mutable:commute r #'+ 5))
    (is (eql 15 (fol.compiler.mutable:deref r)))))

(test commute-outside-dosync-errors
  "commute signals an error outside dosync."
  (let ((r (fol.compiler.mutable:ref 10)))
    (signals error
      (fol.compiler.mutable:commute r #'1+))))

(test ensure-within-dosync
  "ensure returns the ref's current value within dosync."
  (let ((r (fol.compiler.mutable:ref :x)))
    (is (eq :x (fol.compiler.mutable:dosync
                 (fol.compiler.mutable:ensure r))))))

(test ensure-outside-dosync-errors
  "ensure signals an error outside dosync."
  (let ((r (fol.compiler.mutable:ref 1)))
    (signals error
      (fol.compiler.mutable:ensure r))))

;;; ---------------------------------------------------------------------------
;;; dosync semantics
;;; ---------------------------------------------------------------------------

(test dosync-returns-last-value
  "dosync returns the value of its last form."
  (let ((r (fol.compiler.mutable:ref 0)))
    (is (eql 42
             (fol.compiler.mutable:dosync
               (fol.compiler.mutable:ref-set r 1)
               42)))))

(test dosync-nested-flattens
  "Nested dosync runs in the enclosing transaction."
  (let ((r (fol.compiler.mutable:ref 0)))
    (fol.compiler.mutable:dosync
      (fol.compiler.mutable:ref-set r 1)
      (fol.compiler.mutable:dosync
        (fol.compiler.mutable:ref-set r 2)))
    (is (eql 2 (fol.compiler.mutable:deref r)))))

(test dosync-multiple-refs
  "dosync atomically updates multiple refs."
  (let ((r1 (fol.compiler.mutable:ref 0))
        (r2 (fol.compiler.mutable:ref 0)))
    (fol.compiler.mutable:dosync
      (fol.compiler.mutable:ref-set r1 10)
      (fol.compiler.mutable:ref-set r2 20))
    (is (eql 10 (fol.compiler.mutable:deref r1)))
    (is (eql 20 (fol.compiler.mutable:deref r2)))))

(test dosync-reads-own-writes
  "Within dosync, deref sees writes made earlier in the same transaction."
  (let ((r (fol.compiler.mutable:ref 0)))
    (fol.compiler.mutable:dosync
      (fol.compiler.mutable:ref-set r 42)
      (is (eql 42 (fol.compiler.mutable:deref r))))))

(test dosync-alter-chains
  "Multiple alters within dosync chain correctly."
  (let ((r (fol.compiler.mutable:ref 0)))
    (fol.compiler.mutable:dosync
      (fol.compiler.mutable:alter r #'+ 10)
      (fol.compiler.mutable:alter r #'* 3))
    (is (eql 30 (fol.compiler.mutable:deref r)))))

;;; ---------------------------------------------------------------------------
;;; Validators
;;; ---------------------------------------------------------------------------

(test ref-validator-on-creation
  "Validator rejects invalid initial value."
  (signals error
    (fol.compiler.mutable:ref 43 :validator #'evenp)))

(test ref-validator-accepts
  "Validator accepts valid ref-set."
  (let ((r (fol.compiler.mutable:ref 42 :validator #'evenp)))
    (fol.compiler.mutable:dosync
      (fol.compiler.mutable:ref-set r 44))
    (is (eql 44 (fol.compiler.mutable:deref r)))))

(test ref-validator-rejects
  "Validator rejects invalid ref-set at commit time."
  (let ((r (fol.compiler.mutable:ref 42 :validator #'evenp)))
    (signals error
      (fol.compiler.mutable:dosync
        (fol.compiler.mutable:ref-set r 43)))))

;;; ---------------------------------------------------------------------------
;;; Ref printer
;;; ---------------------------------------------------------------------------

(test ref-print-object
  "Refs print as #<REF value>."
  (let* ((r (fol.compiler.mutable:ref 42))
         (str (format nil "~A" r)))
    (is (search "REF" str))
    (is (search "42" str))))

;;; ---------------------------------------------------------------------------
;;; Multi-threaded STM tests
;;; ---------------------------------------------------------------------------

(test ref-concurrent-increments
  "Multiple threads incrementing a ref via dosync converge to correct total."
  (let ((r (fol.compiler.mutable:ref 0))
        (n-threads 10)
        (n-increments 100))
    (let ((threads
            (loop for i below n-threads
                  collect (bordeaux-threads:make-thread
                           (lambda ()
                             (dotimes (j n-increments)
                               (fol.compiler.mutable:dosync
                                 (fol.compiler.mutable:alter r #'1+))))))))
      (dolist (th threads)
        (bordeaux-threads:join-thread th))
      (is (= (* n-threads n-increments)
              (fol.compiler.mutable:deref r))))))

(test ref-concurrent-transfer
  "Concurrent transfers between two refs preserve the total sum."
  (let ((r1 (fol.compiler.mutable:ref 1000))
        (r2 (fol.compiler.mutable:ref 1000))
        (n-threads 8)
        (n-transfers 50))
    (let ((threads
            (loop for i below n-threads
                  collect (bordeaux-threads:make-thread
                           (lambda ()
                             (dotimes (j n-transfers)
                               (fol.compiler.mutable:dosync
                                 (let ((v1 (fol.compiler.mutable:deref r1)))
                                   (when (> v1 0)
                                     (fol.compiler.mutable:alter r1 #'1-)
                                     (fol.compiler.mutable:alter r2 #'1+))))))))))
      (dolist (th threads)
        (bordeaux-threads:join-thread th))
      ;; The total across both refs must always be 2000
      (is (= 2000 (+ (fol.compiler.mutable:deref r1)
                      (fol.compiler.mutable:deref r2)))))))

(test ref-commute-concurrent
  "Concurrent commutes converge to correct total."
  (let ((r (fol.compiler.mutable:ref 0))
        (n-threads 10)
        (n-increments 100))
    (let ((threads
            (loop for i below n-threads
                  collect (bordeaux-threads:make-thread
                           (lambda ()
                             (dotimes (j n-increments)
                               (fol.compiler.mutable:dosync
                                 (fol.compiler.mutable:commute r #'1+))))))))
      (dolist (th threads)
        (bordeaux-threads:join-thread th))
      (is (= (* n-threads n-increments)
              (fol.compiler.mutable:deref r))))))

;;; =========================================================================
;;; Agent tests
;;; =========================================================================

;;; ---------------------------------------------------------------------------
;;; Agent creation and predicate
;;; ---------------------------------------------------------------------------

(test agent-class-exists
  "<agent> class is defined."
  (is (find-class 'fol.compiler.mutable:<agent>)))

(test agent-predicate-true
  "<agent>? returns T for agents."
  (let ((a (fol.compiler.mutable:agent 0)))
    (is (eq t (fol.compiler.mutable:<agent>? a)))))

(test agent-predicate-non-agent
  "<agent>? returns NIL for non-agents."
  (is (null (fol.compiler.mutable:<agent>? 42)))
  (is (null (fol.compiler.mutable:<agent>? (fol.compiler.mutable:atom 1))))
  (is (null (fol.compiler.mutable:<agent>? (fol.compiler.mutable:ref 1)))))

(test agent-initial-value
  "agent stores its initial value."
  (let ((a (fol.compiler.mutable:agent 42)))
    (is (eql 42 (fol.compiler.mutable:deref a)))))

;;; ---------------------------------------------------------------------------
;;; Send and deref
;;; ---------------------------------------------------------------------------

(test agent-send-updates
  "send dispatches an action that updates the agent's value."
  (let ((a (fol.compiler.mutable:agent 0)))
    (fol.compiler.mutable:send a #'1+)
    (fol.compiler.mutable:await a)
    (is (eql 1 (fol.compiler.mutable:deref a)))))

(test agent-send-with-args
  "send passes extra args to the action function."
  (let ((a (fol.compiler.mutable:agent 0)))
    (fol.compiler.mutable:send a #'+ 10)
    (fol.compiler.mutable:await a)
    (is (eql 10 (fol.compiler.mutable:deref a)))))

(test agent-send-multiple
  "Multiple sends chain correctly."
  (let ((a (fol.compiler.mutable:agent 0)))
    (dotimes (i 100)
      (fol.compiler.mutable:send a #'1+))
    (fol.compiler.mutable:await a)
    (is (eql 100 (fol.compiler.mutable:deref a)))))

(test agent-send-off-works
  "send-off dispatches an action just like send."
  (let ((a (fol.compiler.mutable:agent 0)))
    (fol.compiler.mutable:send-off a #'+ 5)
    (fol.compiler.mutable:await a)
    (is (eql 5 (fol.compiler.mutable:deref a)))))

(test agent-send-serialized
  "Actions are executed in dispatch order."
  (let ((a (fol.compiler.mutable:agent 0)))
    ;; First add 10, then multiply by 3 => 30
    (fol.compiler.mutable:send a #'+ 10)
    (fol.compiler.mutable:send a #'* 3)
    (fol.compiler.mutable:await a)
    (is (eql 30 (fol.compiler.mutable:deref a)))))

;;; ---------------------------------------------------------------------------
;;; Await
;;; ---------------------------------------------------------------------------

(test agent-await-returns-t
  "await returns T when the agent is idle."
  (let ((a (fol.compiler.mutable:agent 0)))
    (is (eq t (fol.compiler.mutable:await a)))))

;;; ---------------------------------------------------------------------------
;;; Error handling - :fail mode
;;; ---------------------------------------------------------------------------

(test agent-error-fail-mode
  "In :fail mode, an error stops the agent and caches the error."
  (let ((a (fol.compiler.mutable:agent 0)))
    (fol.compiler.mutable:send a (lambda (v)
                                   (declare (ignore v))
                                   (error "boom")))
    (sleep 0.1)  ; Give worker time to process
    (is (not (null (fol.compiler.mutable:agent-error a))))
    ;; Further sends should error
    (signals error
      (fol.compiler.mutable:send a #'1+))))

(test agent-error-continue-mode
  "In :continue mode, the agent keeps processing after an error."
  (let ((a (fol.compiler.mutable:agent 0 :error-mode :continue)))
    (fol.compiler.mutable:send a #'1+)
    (fol.compiler.mutable:send a (lambda (v)
                                   (declare (ignore v))
                                   (error "boom")))
    (fol.compiler.mutable:send a #'1+)
    (fol.compiler.mutable:await a)
    ;; Value should be 2: 0 -> 1 (1+), error (stays 1), 1 -> 2 (1+)
    (is (eql 2 (fol.compiler.mutable:deref a)))))

(test agent-restart-clears-error
  "restart-agent clears the error and allows new actions."
  (let ((a (fol.compiler.mutable:agent 0)))
    (fol.compiler.mutable:send a (lambda (v)
                                   (declare (ignore v))
                                   (error "boom")))
    (sleep 0.1)
    (is (not (null (fol.compiler.mutable:agent-error a))))
    (fol.compiler.mutable:restart-agent a 10)
    (is (null (fol.compiler.mutable:agent-error a)))
    (is (eql 10 (fol.compiler.mutable:deref a)))
    ;; Can send again
    (fol.compiler.mutable:send a #'1+)
    (fol.compiler.mutable:await a)
    (is (eql 11 (fol.compiler.mutable:deref a)))))

(test agent-error-handler-called
  "Custom error handler receives agent and error."
  (let* ((handler-called nil)
         (a (fol.compiler.mutable:agent 0
              :error-handler (lambda (ag err)
                               (declare (ignore ag))
                               (setf handler-called (type-of err))))))
    (fol.compiler.mutable:send a (lambda (v)
                                   (declare (ignore v))
                                   (error "boom")))
    (sleep 0.1)
    (is (not (null handler-called)))))

;;; ---------------------------------------------------------------------------
;;; Error management functions
;;; ---------------------------------------------------------------------------

(test agent-set-error-handler!
  "set-error-handler! changes the handler."
  (let* ((a (fol.compiler.mutable:agent 0))
         (result (fol.compiler.mutable:set-error-handler!
                  a (lambda (ag err) (declare (ignore ag err))))))
    (is (eq a result))))

(test agent-set-error-mode!
  "set-error-mode! changes the mode."
  (let* ((a (fol.compiler.mutable:agent 0))
         (result (fol.compiler.mutable:set-error-mode! a :continue)))
    (is (eq a result)))
  ;; Invalid mode signals error
  (signals error
    (fol.compiler.mutable:set-error-mode! (fol.compiler.mutable:agent 0) :invalid)))

;;; ---------------------------------------------------------------------------
;;; Agent printer
;;; ---------------------------------------------------------------------------

(test agent-print-object
  "Agents print as #<AGENT value>."
  (let* ((a (fol.compiler.mutable:agent 42))
         (str (format nil "~A" a)))
    (is (search "AGENT" str))
    (is (search "42" str))))
