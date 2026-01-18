(in-package fol.module)

;;; ============================================================================
;;; Module Class
;;; ============================================================================

(defclass <module> (fol.collection:<dict>)
  ()
  (:metaclass fol.persistent:persistent-class)
  (:documentation "A module represents a namespace mapping symbols to values.
                   It inherits from <dict>, so it is a persistent collection."))

(defun make-module (&rest pairs)
  "Create a new <module>, optionally populated with initial bindings.
   Usage: (make-module 'key1 val1 'key2 val2 ...)"
  ;; Reuse the dict logic, but wrap it in our <module> class
  (let ((map (fset:empty-map)))
    (loop for (key val) on pairs by #'cddr
          do (setf map (fset:with map key val)))
    (make-instance '<module> :items map)))

(defgeneric <module>? (obj) (:documentation "Returns T if OBJ is a FOL <module>."))
(defmethod <module>? (obj) (fol.singleton:return-f))
(defmethod <module>? ((obj <module>)) (fol.singleton:return-t))

;;; Printer
;;; We might want modules to print differently than raw dicts (e.g. #<MODULE { ... }>)
(defmethod print-object ((obj <module>) stream)
  (format stream "#<MODULE ")
  ;; Call the <dict> printer to print the contents { ... }
  (call-next-method) 
  (format stream ">"))