(in-package fol.string)

;;; String type predicates
(defgeneric <string>? (obj) (:documentation "Returns T if OBJ is a FOL <string>."))
(defmethod <string>? (obj) (return-f))
(defmethod <string>? ((obj <string>)) (return-t))

;;; Print Object
(defmethod print-object ((obj <string>) stream)
  (format stream "~S" (unwrap-string obj)))