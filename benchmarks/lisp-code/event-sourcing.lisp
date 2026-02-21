;;; =============================================================================
;;; Event Sourcing - Immutable aggregate updates with event logging
;;; Equivalent to fol-code/event-sourcing.fol
;;; =============================================================================

(defpackage :event-sourcing-cl
  (:use :cl)
  (:export #:account
           #:deposit
           #:withdraw
           #:apply-command
           #:replay-to
           #:run-bench
           #:account-balance
           #:account-events))

(in-package :event-sourcing-cl)

;; 1. Define the Account aggregate
(defclass account ()
  ((balance :initarg :balance :initform 0 :accessor account-balance)
   (events  :initarg :events  :initform nil :accessor account-events)))

(defun copy-account (acc)
  "Manual copy of the account object."
  (make-instance 'account
                 :balance (account-balance acc)
                 :events (account-events acc)))

;; 2. Command structures
(defstruct deposit amount)
(defstruct withdraw amount)

;; 3. Generic update function
(defgeneric apply-command (agg cmd))

;; 4. Declarative Event Sourcing via :around method
;;    Intercepts commands to log them.
(defmethod apply-command :around (agg cmd)
  (let* ((result (call-next-method))
         (new-agg (copy-account result))
         (event (list :command cmd :timestamp (get-internal-run-time))))
    ;; Use push (O(1)) instead of append (O(N)) to be fair to CL performance.
    ;; The event log will be in reverse order, which is a common CL pattern.
    (push event (account-events new-agg))
    new-agg))

;; 5. Command Implementation Methods
(defmethod apply-command ((agg account) (cmd deposit))
  (let ((new-acc (copy-account agg)))
    (incf (account-balance new-acc) (deposit-amount cmd))
    new-acc))

(defmethod apply-command ((agg account) (cmd withdraw))
  (let ((new-acc (copy-account agg)))
    (decf (account-balance new-acc) (withdraw-amount cmd))
    new-acc))

;; 6. Replay Functionality
(defun replay-to (aggregate events)
  (reduce #'apply-command events :initial-value aggregate))

;; 7. Benchmark Function
(defun run-bench (iterations)
  (let ((acc (make-instance 'account))
        (cmds (loop for i from 0 below iterations
                    collect (if (zerop (mod i 2))
                                (make-deposit :amount 10)
                                (make-withdraw :amount 10)))))
    (replay-to acc cmds)))
