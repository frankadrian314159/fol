;;; FOL Compiler - Transducers
;;;
;;; Transducer-only functions that are not also sequence functions.
;;; All unified functions (map, filter, take, etc.) now live in seq-functions.lisp
;;; and are re-exported from this package via the package definition.

(in-package :fol.compiler.transducers)

;;; ===========================================================================
;;; Transducer-Only Functions
;;; ===========================================================================

(defun replace (smap)
  "Returns a transducer that replaces keys in smap with their values."
  (map (lambda (x)
         (or (fol.compiler.collections:get smap x) x))))

(defun cat ()
  "Returns a transducer that flattens one level of nested collections."
  (lambda (rf)
    (lambda (&optional (acc nil acc-p) (input nil input-p))
      (cond
        ((not acc-p) (funcall rf))
        ((not input-p) (funcall rf acc))
        (t (let ((iter (fol.compiler.collections:collection-seq input))
                 (current-acc acc))
             (loop for item in iter
                   do (let ((res (funcall rf current-acc item)))
                        (if (reduced? res)
                            (return res)
                            (setf current-acc res)))
                   finally (return current-acc))))))))

(defun halt-when (pred &optional (retf nil))
  "Returns a transducer that ends reduction when pred returns true."
  (lambda (rf)
    (lambda (&optional (acc nil acc-p) (input nil input-p))
      (cond
        ((not acc-p) (funcall rf))
        ((not input-p) (funcall rf acc))
        (t (let ((should-halt (funcall pred input)))
             (if should-halt
                 (ensure-reduced (if retf (funcall retf should-halt input) input))
                 (funcall rf acc input))))))))

;;; ===========================================================================
;;; Eduction
;;; ===========================================================================

(defclass eduction (fol.compiler.collections:<collection>)
  ((xform :initarg :xform :reader eduction-xform)
   (coll :initarg :coll :reader eduction-coll)))

(defmethod fol.compiler.collections:collection-seq ((e eduction))
  (let ((v (transduce (eduction-xform e)
                      #'fol.compiler.collection-functions:conj
                      (fol.compiler.collection-functions:vector)
                      (eduction-coll e))))
    (fol.compiler.collections:collection-seq v)))

(defun eduction (xform coll)
  "Creates an eduction - a reducible/iterable application of xform to coll."
  (make-instance 'eduction :xform xform :coll coll))

(defmethod fol.compiler.collections:collection-size ((e eduction))
  (length (fol.compiler.collections:collection-seq e)))
