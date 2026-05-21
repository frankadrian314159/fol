;;; Simple test to verify ABCL installation
(format t "~&ABCL is working!~%")
(format t "Lisp Implementation: ~A~%" (lisp-implementation-type))
(format t "Lisp Version: ~A~%" (lisp-implementation-version))
(format t "Test calculation: 2 + 3 = ~D~%" (+ 2 3))
(quit)
