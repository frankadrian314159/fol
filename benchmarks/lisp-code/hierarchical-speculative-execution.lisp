;;; =============================================================================
;;; Hierarchical Speculative Execution - Plain CL equivalent of
;;; hierarchical-speculative-execution.fol
;;;
;;; Demonstrates that FOL's :around method combination across a persistent-
;;; object class hierarchy provides automatic, composable speculative execution
;;; that CL cannot replicate without flattening all validation levels into a
;;; single function.
;;;
;;; In FOL: three classes each contribute one :around assoc method.  Methods
;;; compose via call-next-method; any level can veto by returning the old
;;; persistent snapshot rather than the new one.
;;;
;;; In CL: all three validation levels must be coded explicitly in one
;;; update function.  Adding a new subclass requires modifying that function.
;;; =============================================================================

(defpackage :hse-cl
  (:use :cl)
  (:export #:make-regulated-account #:deposit #:run-bench))

(in-package :hse-cl)

;;; Immutable regulated-account struct -- models the same three-level hierarchy
;;; as the FOL class chain <validated> -> <bounded-account> -> <regulated-account>.
(defstruct (regulated-account (:constructor %make-ra) (:copier nil))
  (owner   ""   :type string  :read-only t)
  (balance 0    :type integer :read-only t)
  (limit   1000 :type integer :read-only t)
  (tx-cap  100  :type integer :read-only t))

(defun make-regulated-account (&key (owner "") (balance 0) (limit 1000) (tx-cap 100))
  (%make-ra :owner owner :balance balance :limit limit :tx-cap tx-cap))

;;; ---------------------------------------------------------------------------
;;; In CL, composing multi-level validation with automatic rollback cannot
;;; be expressed as method combinations because mutable objects have no
;;; persistent "old snapshot" to return on failure.
;;;
;;; Instead, all three constraint levels must be coded inline in a single
;;; function:
;;;   Level 1 (non-negative)    -- corresponds to <validated>:around assoc
;;;   Level 3 (tx-delta cap)    -- corresponds to <regulated-account>:around assoc
;;;   Level 2 (balance ceiling) -- corresponds to <bounded-account>:around assoc
;;;
;;; Note: the order must be chosen manually here.  In FOL the order is
;;; determined automatically by the class hierarchy (most-specific first).
;;; ---------------------------------------------------------------------------
(defun %try-update-balance (acc new-balance)
  "Attempt to update the balance, applying all three constraint levels.
   Returns the old account on any failure, or a new account on success.
   All levels are coded here; none can be overridden via subclassing."
  (let ((delta (- new-balance (regulated-account-balance acc))))
    (cond
      ;; Level 1: non-negative check (corresponds to <validated>)
      ((< new-balance 0)
       acc)
      ;; Level 3: per-transaction cap (corresponds to <regulated-account>)
      ((> delta (regulated-account-tx-cap acc))
       acc)
      ;; Level 2: account balance ceiling (corresponds to <bounded-account>)
      ((> new-balance (regulated-account-limit acc))
       acc)
      ;; All levels passed -- return a new immutable struct
      (t
       (%make-ra :owner   (regulated-account-owner   acc)
                 :balance new-balance
                 :limit   (regulated-account-limit   acc)
                 :tx-cap  (regulated-account-tx-cap  acc))))))

(defun deposit (acc amount)
  (%try-update-balance acc (+ (regulated-account-balance acc) amount)))

(defun run-bench (iterations)
  "Run ITERATIONS valid deposits of 1 unit each.
   Returns the final balance (= ITERATIONS if all deposits accepted)."
  (let ((acc (make-regulated-account :owner "Alice" :balance 0
                                     :limit 2000000 :tx-cap 1000000)))
    (dotimes (i iterations (regulated-account-balance acc))
      (setf acc (deposit acc 1)))))
