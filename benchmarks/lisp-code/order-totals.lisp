;;; =============================================================================
;;; Order Totals - Plain Common Lisp equivalent of order-totals.fol
;;;
;;; Fresh-construction, read-heavy companion to derived-value-invalidation.
;;; Native-struct baseline: one allocation per order, direct slot reads.
;;; =============================================================================

(defpackage :order-totals-cl
  (:use :cl)
  (:export #:build-order #:order-total #:sum-orders))

(in-package :order-totals-cl)

(defstruct (order (:constructor %make-order) (:copier nil))
  (subtotal 0 :read-only t)
  (tax 0 :read-only t)
  (shipping 0 :read-only t))

(defun build-order (i)
  (%make-order :subtotal (* i 3) :tax (* i 1) :shipping 5))

(defun order-total (o)
  (+ (order-subtotal o) (order-tax o) (order-shipping o)))

(defun sum-orders (n)
  (let ((total 0))
    (dotimes (i n total)
      (incf total (order-total (build-order i))))))
