(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(defpackage :test-reduce (:use :cl))
(in-package :test-reduce)

;; Create a simple vector
(let ((v (fol.compiler.collection-functions:vector 1 2 3)))
  (format t "Vector: ~A~%" v)
  (format t "Type: ~A~%" (type-of v))
  (format t "Calling reduce...~%") (force-output)
  (let ((result (fol.compiler.seq-functions:reduce #'+ 0 v)))
    (format t "Result: ~A~%" result)))

(sb-ext:quit)
