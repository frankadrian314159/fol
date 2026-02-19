;;; =============================================================================
;;; Compliance Module - Transpiled from fol-code/compliance.fol
;;;
;;; Generated using the FOL compiler's emit patterns:
;;;   - defclass → CL defclass
;;;   - defn (single clause) → defun
;;;   - defn (multi-clause with predicates) → defun with cond dispatch
;;;   - defgeneric → CL defgeneric
;;;   - defmethod (multi-clause) → defun with cond dispatch
;;;   - Predicate patterns (-> accessor pred) → inline CL checks
;;;   - Dict literals {:k v} → plists
;;; =============================================================================

(defpackage :compliance-transpiled
  (:use :cl)
  (:export #:<trade>
           #:validate-trade
           #:trade-symbol
           #:trade-amount
           #:trade-price
           #:trade-side
           #:make-trade))

(in-package :compliance-transpiled)

(declaim (optimize (speed 3) (debug 0)))

;;; ---------------------------------------------------------------------------
;;; 1. Trade class
;;;    FOL: (defclass <trade> [<persistent-object>]
;;;           [[symbol :initarg :symbol :accessor trade-symbol] ...])
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
;;; 2. Business logic functions
;;;    FOL defn → CL defun
;;; ---------------------------------------------------------------------------

;; FOL: (defn trade-total-price [trade] (* (trade-price trade) (trade-amount trade)))
(defun trade-total-price (trade)
  (* (trade-price trade) (trade-amount trade)))

;; FOL: (defn restricted-symbol?
;;         ([(trade (-> (trade-symbol) (#{AMZN GOOG META MSFT})))] t)
;;         ([trade] nil))
;; Transpiled: multi-clause fn with predicate dispatch
;; Pattern (-> (trade-symbol) (#{AMZN GOOG META MSFT})) means:
;;   thread trade through trade-symbol, then check membership in set
(defun restricted-symbol? (&rest args)
  (cond
    ;; Clause 1: pred check - (-> (trade-symbol) (member-of-set))
    ((and (= (length args) 1)
          (let ((trade (nth 0 args)))
            (member (trade-symbol trade) '(:AMZN :GOOG :META :MSFT))))
     (let ((trade (nth 0 args)))
       (declare (ignore trade))
       t))
    ;; Clause 2: catch-all
    ((= (length args) 1)
     (let ((trade (nth 0 args)))
       (declare (ignore trade))
       nil))
    (t (error "No matching clause for restricted-symbol? with ~D arguments" (length args)))))

;; FOL: (defn high-value?
;;         ([(trade (-> (trade-total-price) (> 1000000.00)))] t)
;;         ([trade] nil))
(defun high-value? (&rest args)
  (cond
    ((and (= (length args) 1)
          (let ((trade (nth 0 args)))
            (> (trade-total-price trade) 1000000.00d0)))
     (let ((trade (nth 0 args)))
       (declare (ignore trade))
       t))
    ((= (length args) 1)
     (let ((trade (nth 0 args)))
       (declare (ignore trade))
       nil))
    (t (error "No matching clause for high-value? with ~D arguments" (length args)))))

;; FOL: (defn is-buy-side-trade?
;;         ([(trade (-> (trade-side) (= :buy)))] t)
;;         ([trade] nil))
(defun is-buy-side-trade? (&rest args)
  (cond
    ((and (= (length args) 1)
          (let ((trade (nth 0 args)))
            (eq (trade-side trade) :buy)))
     (let ((trade (nth 0 args)))
       (declare (ignore trade))
       t))
    ((= (length args) 1)
     (let ((trade (nth 0 args)))
       (declare (ignore trade))
       nil))
    (t (error "No matching clause for is-buy-side-trade? with ~D arguments" (length args)))))

;; FOL: (defn is-penny-stock?
;;         ([(trade (-> (trade-price) (< 5.00)))] t)
;;         ([trade] nil))
(defun is-penny-stock? (&rest args)
  (cond
    ((and (= (length args) 1)
          (let ((trade (nth 0 args)))
            (< (trade-price trade) 5.00d0)))
     (let ((trade (nth 0 args)))
       (declare (ignore trade))
       t))
    ((= (length args) 1)
     (let ((trade (nth 0 args)))
       (declare (ignore trade))
       nil))
    (t (error "No matching clause for is-penny-stock? with ~D arguments" (length args)))))

;; FOL: (defn penny-stock-buy? [trade]
;;         (and (is-buy-side-trade? trade) (is-penny-stock? trade)))
(defun penny-stock-buy? (trade)
  (and (is-buy-side-trade? trade) (is-penny-stock? trade)))

;;; ---------------------------------------------------------------------------
;;; 3. Generic function and method dispatch
;;;    FOL defgeneric + multi-clause defmethod → defun with cond dispatch
;;; ---------------------------------------------------------------------------

;; FOL: (defgeneric validate-trade [trade])
;; FOL: (defmethod validate-trade
;;         ([(trd (restricted-symbol?))] {:status :rejected ...})
;;         ([(trd (high-value?))] {:status :manual-review ...})
;;         ([(trd (penny-stock-buy?))] {:status :warning ...})
;;         ([trd] {:status :approved ...}))
;;
;; Multi-clause defmethod transpiles to defun with sorted cond dispatch.
;; Clauses sorted by specificity: pred > any.
(defun validate-trade (&rest args)
  (cond
    ;; Clause 1: pred (restricted-symbol?) - specificity 3
    ((and (= (length args) 1)
          (let ((trd (nth 0 args)))
            (restricted-symbol? trd)))
     (let ((trd (nth 0 args)))
       (list :status :rejected
             :reason (format nil "Symbol ~A is on the restricted list"
                             (trade-symbol trd)))))
    ;; Clause 2: pred (high-value?) - specificity 3
    ((and (= (length args) 1)
          (let ((trd (nth 0 args)))
            (high-value? trd)))
     (let ((trd (nth 0 args)))
       (declare (ignore trd))
       (list :status :manual-review
             :reason "Trade value exceeds $1M limit")))
    ;; Clause 3: pred (penny-stock-buy?) - specificity 3
    ((and (= (length args) 1)
          (let ((trd (nth 0 args)))
            (penny-stock-buy? trd)))
     (let ((trd (nth 0 args)))
       (list :status :warning
             :reason "High risk penny stock purchase"
             :trade trd)))
    ;; Clause 4: any - specificity 0 (catch-all)
    ((= (length args) 1)
     (let ((trd (nth 0 args)))
       (declare (ignore trd))
       (list :status :approved
             :id (gensym "TRD"))))
    (t (error "No matching method clause for validate-trade with ~D arguments" (length args)))))
