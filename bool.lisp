(in-package fol.bool)




;; Boolean type predicates
(defgeneric <bool>? (obj) (:documentation "Returns T if OBJ is a FOL <bool>."))
(defmethod <bool>? (obj) (return-f))
(defmethod <bool>? ((obj <bool>)) (return-t))


(defmethod print-object ((obj <bool>) stream)
  (format stream (if (unwrap-bool obj) "#t" "#f")))
