;;; Test defgeneric multi-pattern caching infrastructure

(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(in-package :fol.compiler)

;; Verify that the defgeneric caching infrastructure is loaded
(format t "~%Checking defgeneric caching infrastructure:~%")
(format t "  cacheable-defgeneric-p = ~A~%" (fboundp 'cacheable-defgeneric-p))
(format t "  make-cached-defgeneric-dispatcher = ~A~%" (fboundp 'make-cached-defgeneric-dispatcher))
(format t "  wrap-dispatcher-with-cache = ~A~%" (fboundp 'wrap-dispatcher-with-cache))
(format t "  wrap-form-with-cache = ~A~%" (fboundp 'wrap-form-with-cache))
(format t "  wrap-cond-for-generic-cache = ~A~%" (fboundp 'wrap-cond-for-generic-cache))

;; Test cacheable-defgeneric-p with various lambda-lists
(format t "~%Testing cacheable-defgeneric-p:~%")
(format t "  Empty list: ~A~%" (cacheable-defgeneric-p nil))
(format t "  3 patterns: ~A~%" (cacheable-defgeneric-p '((a) (a b) (a b c))))
(format t "  4 patterns: ~A~%" (cacheable-defgeneric-p '((a) (a b) (a b c) (a b c d))))
(format t "  5 patterns: ~A~%" (cacheable-defgeneric-p '((a) (a b) (a b c) (a b c d) (a b c d e))))

(format t "~%Defgeneric caching infrastructure test completed!~%")
