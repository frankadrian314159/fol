;;; =============================================================================
;;; Compliance Module - Trade validation in plain Common Lisp
;;; Equivalent to fol-code/compliance.fol
;;; =============================================================================

(defpackage :compliance
  (:use :cl)
  (:export #:trade
           #:make-trade
           #:trade-symbol
           #:trade-amount
           #:trade-price
           #:trade-side
           #:validate-trade))

(in-package :compliance)

(declaim (optimize (speed 3) (debug 0)))

;;; ---------------------------------------------------------------------------
;;; 1. Trade class
;;; ---------------------------------------------------------------------------

(defclass trade ()
  ((symbol :initarg :symbol :accessor trade-symbol)
   (amount :initarg :amount :accessor trade-amount)
   (price  :initarg :price  :accessor trade-price)
   (side   :initarg :side   :accessor trade-side)))

(defun make-trade (&key symbol amount price side)
  (make-instance 'trade :symbol symbol :amount amount
                        :price price :side side))

;;; ---------------------------------------------------------------------------
;;; 2. Business logic predicates
;;; ---------------------------------------------------------------------------

(defun trade-total-price (trade)
  (* (trade-price trade) (trade-amount trade)))

(defparameter *restricted-symbols* '(:AMZN :GOOG :META :MSFT))

(defun restricted-symbol-p (trade)
  (member (trade-symbol trade) *restricted-symbols*))

(defun high-value-p (trade)
  (> (trade-total-price trade) 1000000.00))

(defun buy-side-p (trade)
  (eq (trade-side trade) :buy))

(defun penny-stock-p (trade)
  (< (trade-price trade) 5.00))

(defun penny-stock-buy-p (trade)
  (and (buy-side-p trade) (penny-stock-p trade)))

;;; ---------------------------------------------------------------------------
;;; 3. Validation with manual dispatch
;;; ---------------------------------------------------------------------------

(defun validate-trade (trade)
  (cond
    ((restricted-symbol-p trade)
     (list :status :rejected
           :reason (format nil "Symbol ~A is on the restricted list"
                           (trade-symbol trade))))
    ((high-value-p trade)
     (list :status :manual-review
           :reason "Trade value exceeds $1M limit"))
    ((penny-stock-buy-p trade)
     (list :status :warning
           :reason "High risk penny stock purchase"))
    (t
     (list :status :approved
           :id (gensym "TRD")))))
