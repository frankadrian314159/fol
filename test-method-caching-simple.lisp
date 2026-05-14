;;; Simple test to verify dispatch caching infrastructure for defmethods

(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(in-package :fol.compiler)

;; Verify that the method caching infrastructure is loaded
(format t "~%Checking method caching infrastructure:~%")
(format t "  *method-cache-counter* = ~A~%" *method-cache-counter*)
(format t "  cacheable-method-p = ~A~%" (fboundp 'cacheable-method-p))
(format t "  make-cached-method = ~A~%" (fboundp 'make-cached-method))
(format t "  wrap-cond-with-cache = ~A~%" (fboundp 'wrap-cond-with-cache))

;; Test cacheable-method-p with a simple defmethod form
(let ((method-form '(cl:defmethod test-generic ((x integer))
                      (cl:declare (type integer x))
                      (cl:cond
                        ((cl:typep x 'cl:fixnum) 1)
                        ((cl:typep x 'cl:bignum) 2)
                        ((cl:typep x 'cl:ratio) 3)
                        ((cl:typep x 'cl:float) 4)
                        (t 5)))))
  (format t "~%Testing cacheable-method-p:~%")
  (format t "  method-form: ~A~%" (first method-form))
  (let ((result (cacheable-method-p method-form)))
    (format t "  cacheable-method-p result: ~A~%" result)
    (if result
        (format t "  ✓ Method form recognized as cacheable~%")
        (format t "  ✗ Method form not recognized as cacheable~%"))))

(format t "~%Method caching infrastructure test completed!~%")
