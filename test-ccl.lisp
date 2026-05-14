;;; Simple test to verify CCL installation
(format t "~&CCL is working!~%")
(format t "Version: ~A~%" (lisp-implementation-version))
(format t "Type: ~A~%" (lisp-implementation-type))
(format t "Test calculation: 2 + 3 = ~D~%" (+ 2 3))
(quit)
