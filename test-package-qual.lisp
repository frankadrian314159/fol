(defpackage :test-pkg
  (:use :cl)
  (:shadow reduce))

(in-package :test-pkg)

(defun reduce (fn init list)
  (format t "Custom reduce called!~%")
  (error "This shouldn't happen!"))

;; Try calling cl:reduce
(format t "Calling cl:reduce...~%")
(let ((result (cl:reduce #'+ '(1 2 3) :initial-value 0)))
  (format t "Result: ~A~%" result))

(sb-ext:quit)
