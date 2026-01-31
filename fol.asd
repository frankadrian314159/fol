;;; FOL - Functional Object Lisp
;;;
;;; This is the main system definition that loads the FOL implementation.
;;; By default, it loads the bootstrap implementation written in Common Lisp.
;;;
;;; The bootstrap implementation is located in the bootstrap/ subdirectory.
;;; To load FOL, first register this directory with ASDF, then load the system:
;;;
;;;   (push #p"/path/to/fol/" asdf:*central-registry*)
;;;   (asdf:load-system :fol)
;;;
;;; To run tests:
;;;
;;;   (asdf:test-system :fol)

;; First, we need to ensure the bootstrap directory is in the source registry
;; so ASDF can find the bootstrap.asd file.
(eval-when (:compile-toplevel :load-toplevel :execute)
  (let* ((this-file (or *compile-file-pathname* *load-pathname*))
         (bootstrap-dir (when this-file
                          (merge-pathnames "bootstrap/"
                                           (make-pathname :directory (pathname-directory this-file))))))
    (when (and bootstrap-dir (probe-file (merge-pathnames "bootstrap.asd" bootstrap-dir)))
      (pushnew bootstrap-dir asdf:*central-registry* :test #'equal))))

(defsystem "fol"
  :description "Functional Object Lisp - A persistent object-oriented programming language."
  :version "0.1.0"
  :author "Frank Adrian"
  :license "MIT"
  :depends-on ("bootstrap")
  :in-order-to ((test-op (test-op "fol/tests"))))

(defsystem "fol/tests"
  :depends-on ("fol" "bootstrap/tests")
  :perform (test-op (o s) (symbol-call :fol.tests :run-fol-tests)))
