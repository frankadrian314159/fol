(in-package fol.bool)

;;; ============================================================================
;;; Boolean Operations - Option 4 (Tagged Representation)
;;; ============================================================================
;;;
;;; Type predicates work on both raw CL booleans and wrapped FOL <bool> objects.

;;; Boolean type predicates
(defgeneric <bool>? (obj) (:documentation "Returns T if OBJ is a FOL <bool> or a raw boolean."))
(defmethod <bool>? (obj) nil)
(defmethod <bool>? ((obj <bool>)) t)
(defmethod <bool>? ((obj (eql t))) t)
(defmethod <bool>? ((obj (eql nil))) t)

;;; Print Object
(defmethod print-object ((obj <bool>) stream)
  (if (fol-value obj)
      (format stream "t")
      (format stream "nil")))
