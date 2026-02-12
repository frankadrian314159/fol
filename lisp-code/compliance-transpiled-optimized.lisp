;;; =============================================================================
;;; Compliance Module - Transpiled from fol-code/compliance.fol (optimized)
;;;
;;; Same as compliance-transpiled.lisp but with the fixed-arity optimization:
;;; all multi-clause functions have uniform arity 1, so (&rest args) is
;;; replaced with a direct parameter, eliminating rest-argument consing,
;;; (length args) computation, and (nth 0 args) list traversal.
;;; =============================================================================

(defpackage :compliance-optimized
  (:use :cl)
  (:export #:<trade>
           #:validate-trade
           #:trade-symbol
           #:trade-amount
           #:trade-price
           #:trade-side
           #:make-trade))

(in-package :compliance-optimized)

(declaim (optimize (speed 3) (debug 0)))

;;; ---------------------------------------------------------------------------
;;; 1. Trade class (unchanged)
;;; ---------------------------------------------------------------------------

(defclass <trade> ()
  ((symbol :initarg :symbol :accessor trade-symbol)
   (amount :initarg :amount :accessor trade-amount)
   (price  :initarg :price  :accessor trade-price)
   (side   :initarg :side   :accessor trade-side)))

(defun make-trade (&key symbol amount price side)
  (make-instance '<trade> :symbol symbol :amount amount
                          :price price :side side))

;;; ---------------------------------------------------------------------------
;;; 2. Business logic functions (fixed-arity optimization applied)
;;; ---------------------------------------------------------------------------

(defun trade-total-price (trade)
  (* (trade-price trade) (trade-amount trade)))

;; restricted-symbol?: 2 clauses, both arity 1 → fixed param
(defun restricted-symbol? (a0)
  (cond
    ;; Clause 1: pred check - specificity 3
    ((let ((trade a0))
       (member (trade-symbol trade) '(:AMZN :GOOG :META :MSFT)))
     (let ((trade a0))
       (declare (ignore trade))
       t))
    ;; Clause 2: any - specificity 0
    (t
     (let ((trade a0))
       (declare (ignore trade))
       nil))))

;; high-value?: 2 clauses, both arity 1 → fixed param
(defun high-value? (a0)
  (cond
    ((let ((trade a0))
       (> (trade-total-price trade) 1000000.00d0))
     (let ((trade a0))
       (declare (ignore trade))
       t))
    (t
     (let ((trade a0))
       (declare (ignore trade))
       nil))))

;; is-buy-side-trade?: 2 clauses, both arity 1 → fixed param
(defun is-buy-side-trade? (a0)
  (cond
    ((let ((trade a0))
       (eq (trade-side trade) :buy))
     (let ((trade a0))
       (declare (ignore trade))
       t))
    (t
     (let ((trade a0))
       (declare (ignore trade))
       nil))))

;; is-penny-stock?: 2 clauses, both arity 1 → fixed param
(defun is-penny-stock? (a0)
  (cond
    ((let ((trade a0))
       (< (trade-price trade) 5.00d0))
     (let ((trade a0))
       (declare (ignore trade))
       t))
    (t
     (let ((trade a0))
       (declare (ignore trade))
       nil))))

;; penny-stock-buy?: single clause (unchanged)
(defun penny-stock-buy? (trade)
  (and (is-buy-side-trade? trade) (is-penny-stock? trade)))

;;; ---------------------------------------------------------------------------
;;; 3. Validation dispatch (fixed-arity optimization applied)
;;; ---------------------------------------------------------------------------

;; validate-trade: 4 clauses, all arity 1 → fixed param
(defun validate-trade (a0)
  (cond
    ;; Clause 1: pred (restricted-symbol?) - specificity 3
    ((let ((trd a0))
       (restricted-symbol? trd))
     (let ((trd a0))
       (list :status :rejected
             :reason (format nil "Symbol ~A is on the restricted list"
                             (trade-symbol trd)))))
    ;; Clause 2: pred (high-value?) - specificity 3
    ((let ((trd a0))
       (high-value? trd))
     (let ((trd a0))
       (declare (ignore trd))
       (list :status :manual-review
             :reason "Trade value exceeds $1M limit")))
    ;; Clause 3: pred (penny-stock-buy?) - specificity 3
    ((let ((trd a0))
       (penny-stock-buy? trd))
     (let ((trd a0))
       (list :status :warning
             :reason "High risk penny stock purchase"
             :trade trd)))
    ;; Clause 4: any - specificity 0 (catch-all)
    (t
     (let ((trd a0))
       (declare (ignore trd))
       (list :status :approved
             :id (gensym "TRD"))))))
