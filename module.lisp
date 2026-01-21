(in-package fol.module)

;;; ============================================================================
;;; Module Class
;;; ============================================================================

(defclass <module> (fol.collection:<dict>)
  ()
;;; Global Registry
(defvar *modules* (make-hash-table :test 'equal)
  "Global registry mapping module names (strings) to <module> instances.")

(defun find-module (name)
  (gethash (string name) *modules*))

(defun register-module (name module)
  (setf (gethash (string name) *modules*) module))

(defclass <module> (fol.env:<env>)
  ((name :initarg :name
         :reader module-name
         :type (or null string symbol))
   (exports :initarg :exports
            :initform (fset:empty-set)
            :accessor module-exports
            :documentation "Set of exported symbols."))
  (:metaclass fol.persistent:persistent-class)
  (:documentation "A module represents a namespace mapping symbols to values.
                   It inherits from <dict>, so it is a persistent collection."))
                   It inherits from <env> to serve as an evaluation context."))

(defun make-module (&rest pairs)
(defun make-module (name &rest pairs)
  "Create a new <module>, optionally populated with initial bindings.
   Usage: (make-module 'key1 val1 'key2 val2 ...)"
  ;; Reuse the dict logic, but wrap it in our <module> class
   Usage: (make-module 'my-mod 'key1 val1 'key2 val2 ...)"
  (let ((map (fset:empty-map)))
    (loop for (key val) on pairs by #'cddr
          do (setf map (fset:with map 
                                  (fol.wrappers:fol-value key) 
                                  (fol.wrappers:fol-value val))))
    (make-instance '<module> :items map)))
    (let ((m (make-instance '<module> 
                            :name name 
                            :items map
                            :previous nil)))
      (register-module name m)
      m)))

(defgeneric <module>? (obj) (:documentation "Returns T if OBJ is a FOL <module>."))
(defmethod <module>? (obj) nil)
(defmethod <module>? ((obj <module>)) t)

;;; ============================================================================
;;; Import / Export
;;; ============================================================================

(defgeneric module-export (module symbol)
  (:documentation "Add a symbol to the module's export list."))

(defmethod module-export ((mod <module>) symbol)
  (let ((current-exports (fol.persistent:pslot-value mod 'exports)))
    (fol.persistent:set-pslot-value mod 'exports (fset:with current-exports symbol))))

(defgeneric module-import (target-env source-module)
  (:documentation "Import all exported symbols from SOURCE-MODULE into TARGET-ENV."))

(defmethod module-import ((target-env fol.env:<env>) (source-module <module>))
  (let ((exports (fol.persistent:pslot-value source-module 'exports))
        (src-items (fol.persistent:pslot-value source-module 'fol.collection::items))
        (target-items (fol.persistent:pslot-value target-env 'fol.collection::items)))
    (fset:do-set (sym exports)
      (let ((val (fset:lookup src-items (fol.wrappers:fol-value sym))))
        (setf target-items (fset:with target-items (fol.wrappers:fol-value sym) val))))
    (fol.persistent:set-pslot-value target-env 'fol.collection::items target-items)))

;;; Printer
;;; We might want modules to print differently than raw dicts (e.g. #<MODULE { ... }>)
(defmethod print-object ((obj <module>) stream)
  (format stream "#<MODULE ")
  ;; Call the <dict> printer to print the contents { ... }
  (call-next-method) 
  (format stream ">"))
  (format stream "#<MODULE ~A>" (module-name obj)))