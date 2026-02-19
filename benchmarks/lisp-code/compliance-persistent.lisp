;;; =============================================================================
;;; Compliance Module - Persistent Objects version
;;; Same logic as compliance.lisp but using persistent object storage via FSet.
;;; Uses direct accessor functions that bypass MOP for fast reads.
;;; =============================================================================

;; Load the compiler's persistent system
(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(defpackage :compliance-persistent
  (:use :cl)
  (:export #:<trade>
           #:validate-trade
           #:trade-symbol
           #:trade-amount
           #:trade-price
           #:trade-side
           #:make-trade))

(in-package :compliance-persistent)

(declaim (optimize (speed 3) (debug 0)))

;;; ---------------------------------------------------------------------------
;;; 1. Trade class - persistent with direct accessors
;;; ---------------------------------------------------------------------------

(defclass <trade> (fol.compiler.persistent:<persistent-object>)
  ((symbol :initarg :symbol)
   (amount :initarg :amount)
   (price  :initarg :price)
   (side   :initarg :side))
  (:metaclass fol.compiler.persistent:persistent-class))

;; Direct accessor functions - bypass MOP, read directly from FSet map
(defun trade-symbol (obj)
  (fset:lookup (fol.compiler.persistent::%persistent-storage obj) :symbol))

(defun trade-amount (obj)
  (fset:lookup (fol.compiler.persistent::%persistent-storage obj) :amount))

(defun trade-price (obj)
  (fset:lookup (fol.compiler.persistent::%persistent-storage obj) :price))

(defun trade-side (obj)
  (fset:lookup (fol.compiler.persistent::%persistent-storage obj) :side))

(defun make-trade (&key symbol amount price side)
  (make-instance '<trade> :symbol symbol :amount amount
                          :price price :side side))

;;; ---------------------------------------------------------------------------
;;; 2. Business logic predicates (identical to compliance.lisp)
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
;;; 3. Validation with manual dispatch (identical to compliance.lisp)
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
