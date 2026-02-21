;;; =============================================================================
;;; Compliance Module - Trade validation in plain Common Lisp
;;; Equivalent to fol-code/compliance.fol
;;; =============================================================================

(defpackage :compliance-cl
  (:use :cl)
  (:export #:trade
           #:make-trade
           #:trade-symbol
           #:trade-amount
           #:trade-price
           #:trade-side
           #:validate-trade))

(in-package :compliance-cl)

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

;;; ---------------------------------------------------------------------------
;;; 4. Run validation
;;; ---------------------------------------------------------------------------

(defpackage :test-compliance-cl
  (:use :cl :compliance-cl))

(in-package :test-compliance-cl)

(defun compliance ()
  ;; Create test trades
  (defparameter t1 (make-trade :symbol :NU :amount 100 :price 18.00 :side :buy))
  (defparameter t2 (make-trade :symbol :GOOG :amount 50 :price 150.00 :side :sell))
  (defparameter t3 (make-trade :symbol :IBM  :amount 10000 :price 150.00 :side :buy))
  (defparameter t4 (make-trade :symbol :F :amount 1000 :price 12.00 :side :buy))

  ;; Run tests
  (format t "T1: ~A~&" (validate-trade t1))
  ;; => T1: (:status :approved :id TRD123)

  (format t "T2: ~A~&" (validate-trade t2))
  ;; => T2: (:status :rejected :reason "Symbol GOOG is on the restricted list")

  (format t "T3: ~A~&" (validate-trade t3))
  ;; => T3: (:status :manual-review :reason "Trade value exceeds $1M limit")

  (format t "T4: ~A~&" (validate-trade t4)))
  ;; => T4: (:status :warning :reason "High risk penny stock purchase")

(defun run-bench ()
  (let ((t1 (make-trade :symbol :NU :amount 100 :price 18.00 :side :buy))
        (t2 (make-trade :symbol :GOOG :amount 50 :price 150.00 :side :sell))
        (t3 (make-trade :symbol :IBM  :amount 10000 :price 150.00 :side :buy))
        (t4 (make-trade :symbol :F :amount 1000 :price 12.00 :side :buy)))
    (dotimes (i 1000)
      (validate-trade t1)
      (validate-trade t2)
      (validate-trade t3)
      (validate-trade t4))))
