(in-package fol.singleton)





;; Initialize the singletons with their native values
(defparameter *true-instance* (make-instance '<bool>  :val t))
(defparameter *false-instance* (make-instance '<bool> :val nil))


(defun return-t ()
  "Returns the FOL representation of true."
  *true-instance*)

(defun return-f ()
  "Returns the FOL representation of false."
  *false-instance*)
  