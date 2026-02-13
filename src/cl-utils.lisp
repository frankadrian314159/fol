;;; FOL Compiler - Common Lisp Utility Functions
;;;
;;; Runtime functions for creating CL data structures from FOL literals.
;;; Used when transpiling FOL collection literals to CL equivalents.

(in-package :fol.compiler.cl-utils)

(defun make-cl-vector (&rest elements)
  "Create a Common Lisp vector from ELEMENTS.
   Returns a simple CL vector #(e1 e2 ...)."
  (coerce elements 'vector))

(defun make-cl-dict (&rest key-value-pairs)
  "Create a Common Lisp hash-table from alternating KEY-VALUE-PAIRS.
   Uses EQL test for compatibility with keyword and symbol keys.

   Example:
     (make-cl-dict :a 1 :b 2) => #<HASH-TABLE :A 1 :B 2>"
  (unless (evenp (length key-value-pairs))
    (error "make-cl-dict requires an even number of arguments (key-value pairs), got ~A"
           (length key-value-pairs)))
  (let ((ht (make-hash-table :test 'eql)))
    (loop for (key value) on key-value-pairs by #'cddr
          do (setf (gethash key ht) value))
    ht))

(defun make-cl-set (&rest elements)
  "Create a Common Lisp hash-table representing a set from ELEMENTS.
   All values are T (indicating presence). Uses EQL test.

   Example:
     (make-cl-set 1 2 3) => #<HASH-TABLE 1 T, 2 T, 3 T>"
  (let ((ht (make-hash-table :test 'eql)))
    (dolist (elem elements)
      (setf (gethash elem ht) t))
    ht))
