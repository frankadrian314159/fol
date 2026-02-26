;;; =============================================================================
;;; Guards Pattern - Plain Common Lisp equivalent of guards.fol
;;;
;;; Demonstrates the burden of manual guard placement: the invariant check
;;; must be repeated in every update function.  FOL's :around assoc enforces
;;; it centrally, making omission impossible.
;;; =============================================================================

(defpackage :guards-cl
  (:use :cl)
  (:export #:make-account #:account-owner #:account-balance
           #:deposit #:withdraw #:run-bench))

(in-package :guards-cl)

;;; Immutable account value: use a struct with a private constructor
;;; so the only way to build one is via make-account or the update functions.
(defstruct (account (:constructor %make-account) (:copier nil))
  (owner   ""  :type string  :read-only t)
  (balance 0   :type integer :read-only t))

(defun make-account (&key (owner "") (balance 0))
  (%make-account :owner owner :balance balance))

;;; ---------------------------------------------------------------------------
;;; Invariant check helper.
;;; In CL there is no cross-cutting hook; this function must be called manually
;;; inside EVERY update function.  Missing even one call silently breaks the
;;; invariant.  (contrast: FOL :around assoc makes omission structurally
;;; impossible.)
;;; ---------------------------------------------------------------------------
(declaim (inline %check-balance))
(defun %check-balance (acc new-balance)
  (when (< new-balance 0)
    (error "~A: balance cannot go negative" (account-owner acc))))

(defun deposit (acc amount)
  "Add AMOUNT to balance, returning a new immutable account.
   Manually checks the invariant -- the check must be present here AND
   in withdraw, transfer, and any future update function."
  (let ((new-balance (+ (account-balance acc) amount)))
    (%check-balance acc new-balance)
    (%make-account :owner (account-owner acc) :balance new-balance)))

(defun withdraw (acc amount)
  "Subtract AMOUNT from balance, returning a new immutable account.
   Guard is duplicated here -- another function to keep in sync."
  (let ((new-balance (- (account-balance acc) amount)))
    (%check-balance acc new-balance)
    (%make-account :owner (account-owner acc) :balance new-balance)))

(defun run-bench (iterations)
  "Run ITERATIONS valid deposits and return the final balance."
  (let ((acc (make-account :owner "Alice" :balance 0)))
    (dotimes (i iterations (account-balance acc))
      (setf acc (deposit acc 1)))))
