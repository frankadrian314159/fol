;;; =============================================================================
;;; Derived-Value Invalidation - Plain Common Lisp equivalent
;;; of derived-value-invalidation.fol
;;;
;;; Demonstrates the manual burden: every function that modifies :items must
;;; explicitly set :_total to nil.  FOL's :around assoc does this automatically.
;;; =============================================================================

(defpackage :dvi-cl
  (:use :cl)
  (:export #:make-cart #:cart-items #:cart-total
           #:add-item #:sum-reads #:run-bench))

(in-package :dvi-cl)

;;; Immutable cart: struct with a private constructor.
(defstruct (cart (:constructor %make-cart) (:copier nil))
  (items  nil :read-only t)   ; CL list of integer prices
  (_total nil :read-only t))  ; NIL = invalid, integer = cached sum

(defun make-cart ()
  (%make-cart :items nil :_total nil))

;;; ---------------------------------------------------------------------------
;;; Manual cache invalidation.
;;; The nil assignment for :_total must appear in EVERY function that changes
;;; :items.  (contrast: FOL :around assoc handles this automatically.)
;;; ---------------------------------------------------------------------------
(defun add-item (cart price)
  "Prepend PRICE to cart items, explicitly clearing the cached total."
  (%make-cart :items (cons price (cart-items cart))
              :_total nil))        ; <-- must not forget this

;;; Lazy total accessor: return cached value or recompute.
(defun cart-total (cart)
  (or (cart-_total cart)
      (reduce #'+ (cart-items cart) :initial-value 0)))

;;; Inner benchmark loop: N-READS reads from a cart with a warm cache.
(defun sum-reads (cart n-reads)
  (let ((s 0))
    (dotimes (j n-reads s)
      (incf s (cart-total cart)))))

;;; Outer benchmark: N-ITEMS rounds of (add-item + reads-per-item reads).
;;; Mirrors the FOL run-bench exactly:
;;;   1. add-item  -> manual cache invalidation
;;;   2. cart-total -> recompute (cache miss)
;;;   3. store total back  -> enable caching
;;;   4. sum-reads -> all cache hits
(defun run-bench (n-items reads-per-item)
  (let ((cart (make-cart))
        (total 0))
    (dotimes (i n-items total)
      (setf cart (add-item cart i))
      ;; Recompute and store back (same logic as FOL)
      (let ((t1 (cart-total cart)))
        (setf cart (%make-cart :items (cart-items cart) :_total t1))
        (incf total (sum-reads cart reads-per-item))))))
