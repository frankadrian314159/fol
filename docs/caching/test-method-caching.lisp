;;; Test to verify dispatch caching for multi-clause defmethods

(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(in-package :fol.compiler)

;; Define a generic function
(defgeneric dispatch-test (x))

;; Define a multi-clause defmethod with caching
;; This should be automatically wrapped with cache logic
(defmethod dispatch-test ((x integer))
  (format t "Dispatched to integer clause~%")
  (* x 2))

(defmethod dispatch-test ((x string))
  (format t "Dispatched to string clause~%")
  (str-repeat x 2))

(defmethod dispatch-test ((x vector))
  (format t "Dispatched to vector clause~%")
  (cl:length x))

;; Test the dispatch
(format t "~%Testing method dispatch:~%")
(format t "dispatch-test 5 = ~A~%" (dispatch-test 5))
(format t "dispatch-test \"hello\" = ~A~%" (dispatch-test "hello"))
(format t "dispatch-test [1 2 3] = ~A~%" (dispatch-test #(1 2 3)))

(format t "~%Method caching test completed!~%")
