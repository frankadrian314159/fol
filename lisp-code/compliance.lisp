(defpackage :compliance-cl
  (:use :cl)
  (:export :trade :validate-trade :trade-symbol :trade-amount :trade-price :trade-side :run-compliance-tests))

(in-package :compliance-cl)

;; 1. Define the Trade class
(defclass trade (standard-object)
    ((symbol :initarg :symbol :accessor trade-symbol)
     (amount :initarg :amount :accessor trade-amount)
     (price :initarg :price :accessor trade-price)
     (side :initarg :side :accessor trade-side))
  (:documentation "Trade object represented in standard Common Lisp."))

(defun trade-total-price (trade)
  (* (trade-price trade) (trade-amount trade)))

;; 2. Business logic predicates
(defun restricted-symbol-p (trade)
  "Checks if the trade symbol is on the restricted list."
  ;; Same as compliance.fol: #{"AAPL" "MSFT" "TSLA"}
  (member (trade-symbol trade) '(AAPL MSFT TSLA)))

(defun high-value-p (trade)
  "Checks if the trade total value exceeds $1,000,000."
  (> (trade-total-price trade) 1000000))

(defun buy-side-p (trade)
  "Checks if the trade is a buy side trade."
  (eq (trade-side trade) :buy))

(defun penny-stock-p (trade)
  "Checks if the trade price is below $5.00."
  (< (trade-price trade) 5))

(defun penny-stock-buy-p (trade)
  "Checks if the trade is a buy-side penny stock purchase."
  (and (buy-side-p trade) (penny-stock-p trade)))

;; 3. Compliance validation logic
(defun validate-trade (trd)
  "Standard Common Lisp implementation of the compliance validation logic."
  (cond
   ((restricted-symbol-p trd)
     (list :status :rejected
           :reason (format nil "Symbol ~A is on the restricted list" (trade-symbol trd))))
   ((high-value-p trd)
     (list :status :manual-review
           :reason "Trade value exceeds $1M limit"))
   ((penny-stock-buy-p trd)
     (list :status :warning
           :reason "High risk penny stock purchase"
           :trade trd))
   (t
     (list :status :approved
           :id (gensym "TRD")))))

;; 4. Test function (equivalent to FOL's compliance function)
(defun run-compliance-tests ()
  (let ((t1 (make-instance 'trade :symbol 'NU :amount 100 :price 18.0 :side :buy))
        (t2 (make-instance 'trade :symbol 'GOOG :amount 50 :price 150.0 :side :sell))
        (t3 (make-instance 'trade :symbol 'IBM :amount 10000 :price 150.0 :side :buy))
        (t4 (make-instance 'trade :symbol 'F :amount 1000 :price 12.0 :side :buy)))

    (format t "T1: ~S~%" (validate-trade t1))
    (format t "T2: ~S~%" (validate-trade t2))
    (format t "T3: ~S~%" (validate-trade t3))
    (format t "T4: ~S~%" (validate-trade t4))))

;; Automatically run tests if this file is loaded directly as a script
(eval-when (:execute)
  (when (eq (find-package :cl-user) *package*)
    (run-compliance-tests)))
