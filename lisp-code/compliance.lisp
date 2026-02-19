(defpackage :compliance-cl
  (:use :cl)
  (:export #:trade #:validate-trade #:compliance-test))

(in-package :compliance-cl)

(defclass trade (standard-object)
  ((symbol :initarg :symbol :accessor trade-symbol)
   (amount :initarg :amount :accessor trade-amount)
   (price  :initarg :price  :accessor trade-price)
   (side   :initarg :side   :accessor trade-side)))

(defun trade-total-price (trade)
  (* (trade-price trade) (trade-amount trade)))

(defun restricted-symbol-p (trade)
  (member (trade-symbol trade) '(AMZN GOOG META MSFT)))

(defun high-value-p (trade)
  (> (trade-total-price trade) 1000000.0))

(defun is-buy-side-trade-p (trade)
  (eq (trade-side trade) :buy))

(defun is-penny-stock-p (trade)
  (< (trade-price trade) 5.0))

(defun penny-stock-buy-p (trade)
  (and (is-buy-side-trade-p trade) (is-penny-stock-p trade)))

(defun validate-trade (trd)
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

(defun compliance-test ()
  (let ((t1 (make-instance 'trade :symbol 'NU :amount 100 :price 18.0 :side :buy))
        (t2 (make-instance 'trade :symbol 'GOOG :amount 50 :price 150.0 :side :sell))
        (t3 (make-instance 'trade :symbol 'IBM :amount 10000 :price 150.0 :side :buy))
        (t4 (make-instance 'trade :symbol 'F :amount 1000 :price 12.0 :side :buy)))
    (validate-trade t1)
    (validate-trade t2)
    (validate-trade t3)
    (validate-trade t4)
    nil))

(defpackage :fol.benchmarks
  (:use :cl)
  (:import-from :compliance-cl #:compliance-test))

(in-package :fol.benchmarks)

(defun run-compliance-cl ()
  (compliance-cl:compliance-test))
