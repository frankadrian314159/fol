(in-package :fol.exception)
    
(defclass <exception> (<persistent-object>)
  ((message :initarg :message
            :accessor exception-message
            :type string
            :documentation "The error message associated with the exception.")
   (data :initarg :data
         :accessor exception-data
         :documentation "Additional data related to the exception."))
  (:metaclass fol.persistent:persistent-class)
  (:documentation "Base class for exceptions in FOL."))

  (defclass <panic>
    (<exception>)
    ()
    (:metaclass persistent-class)
    (:documentation "Panic exception indicating a critical error in the system."))

(defclass <error>
  (<exception>)
  ()
  (:metaclass fol.persistent:persistent-class)
  (:documentation "General error exception class."))

(defclass <warning>
  (<exception>)
  ()
  (:metaclass fol.persistent:persistent-class)
  (:documentation "Warning exception class."))


(defun <exception>? (obj)
  "Return T if OBJ is an exception."
  (typep obj '<exception>)) 
  
(defun <panic>? (obj)
  "Return T if OBJ is a panic exception."
  (typep obj '<panic>))

(defun <error>? (obj)
  "Return T if OBJ is an error exception."
    (typep obj '<error>))

(defun <warning>? (obj)
  "Return T if OBJ is a warning exception."
    (typep obj '<warning>))