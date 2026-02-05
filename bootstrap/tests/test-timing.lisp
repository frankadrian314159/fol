(in-package :fol.tests)

(def-suite timing-suite :in fol-suite)
(def-suite* :timing-tests :in timing-suite)

;;; ---------------------------------------------------------------------------
;;; Common Lisp Generic Function Timing Tests
;;; ---------------------------------------------------------------------------
;;;
;;; These tests measure CL CLOS generic function dispatch performance.
;;; This provides a baseline comparison for FOL's multi-pattern dispatch.

;; Define generic function and methods at compile/load time
(eval-when (:compile-toplevel :load-toplevel :execute)
  (defgeneric cl-timing-process (a &optional b c))

  (defmethod cl-timing-process (a &optional b c)
    (cond ((cl:and (null b) (null c)) 50)
          ((cl:and (numberp b) (null c) (cl:< b 10)) (cl:* 2 b))
          ((cl:and (numberp b) (stringp c)) c)
          (t :error))))


(test cl-generic-dispatch-timing
  "Time CL CLOS type-based generic function dispatch."
  (format t "~&~%--- CL Generic Function Timing (CLOS type dispatch) ---~%")
  (format t "100000 iterations with (number):~%")
  (time (dotimes (i 100000) (cl-timing-process 0)))
  (format t "100000 iterations with (number number):~%")
  (time (dotimes (i 100000) (cl-timing-process 0 5)))
  (format t "100000 iterations with (number number string):~%")
  (time (dotimes (i 100000) (cl-timing-process 0 100 "abc")))
  (format t "100000 iterations with fallback (t t t):~%")
  (time (dotimes (i 100000) (cl-timing-process "a" "b" 'symbol)))
  (pass))
