(in-package fol.string)

;;; ============================================================================
;;; String Operations - Option 4 (Tagged Representation)
;;; ============================================================================
;;;
;;; Type predicates work on both raw CL strings and wrapped FOL <string> objects.

;;; String type predicates
(defgeneric <string>? (obj) (:documentation "Returns T if OBJ is a FOL <string> or raw string."))
(defmethod <string>? (obj) nil)
(defmethod <string>? ((obj <string>)) t)
(defmethod <string>? ((obj string)) t)

;;; Print Object
(defmethod print-object ((obj <string>) stream)
  (format stream "~S" (fol-value obj)))
