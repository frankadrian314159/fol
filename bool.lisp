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

(defun parse-bool (bool-string)
  "Parses a boolean string and returns a FOL <bool> instance.
   BOOL-STRING should be t, nil, or () (case-insensitive).
   Example: (parse-bool \"t\") => <bool> true
            (parse-bool \"NIL\") => <bool> false
            (parse-bool \"()\") => <bool> false"
  (let ((str (typecase bool-string
               (string bool-string)
               (<string> (fol-value bool-string))
               (t (error "Expected a string for parse-bool, got ~A" (type-of bool-string))))))
    (let ((form (let ((*read-eval* nil))  ; Safety: disable #. reader macro
                  (read-from-string str))))
      (cond
        ((eq form t) (wrap-bool t))
        ((eq form nil) (wrap-bool nil))
        (t (error "Expected t, nil, or () for boolean, got ~S" form))))))
