(in-package fol.module)

;;; ============================================================================
;;; Module Class
;;; ============================================================================

;;; Global Registry
(defvar +module-registry+ (make-hash-table :test 'equal)
  "Global registry mapping module names (strings) to <module> instances.")

(defun find-module (name)
  (gethash (string name) +module-registry+))

(defun register-module (name module)
  (setf (gethash (string name) +module-registry+) module))

(defclass <module> (fol.env:<env>)
  ((name :initarg :name
         :reader module-name
         :type (or null string symbol))
   (exports :initarg :exports
            :initform (fset:empty-set)
            :accessor module-exports
            :documentation "Set of exported symbols.")
   (imports :initarg :imports
            :initform (fset:empty-map)
            :accessor module-imports
            :documentation "Dict of imported symbols from other modules."))
  (:metaclass fol.persistent:persistent-class)
  (:documentation "A module represents a namespace mapping symbols to values.
                   It inherits from <env> to serve as an evaluation context.
                   Lookup checks imports first, then local bindings, then the env chain."))

(defun make-module (name &rest pairs)
  "Create a new <module> optionally populated with initial bindings.
   Usage: (make-module 'my-mod 'key1 val1 'key2 val2 ...)"
  (unless name (error "Module must have a name"))
  (let ((map (fset:empty-map)))
    (loop for (key val) on pairs by #'cddr
          do (setf map (fset:with map
                                  (fol.env:normalize-env-key key)
                                  (fol.wrappers:fol-value val))))
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
(defmethod print-object ((obj <module>) stream)
  (format stream "#<MODULE ~A>" (module-name obj)))

;;; Module-specific lookup: imports -> local items -> env chain
(defmethod fol.env:lookup ((mod <module>) variable-name)
  "Look up a variable in a module. Search order:
   1. Module's imports dict
   2. Module's local items (own bindings)
   3. Environment chain (previous)"
  (let ((key (fol.env:normalize-env-key variable-name))
        (imports (fol.persistent:pslot-value mod 'imports))
        (items (fol.persistent:pslot-value mod 'fol.collection::items)))
    ;; Check imports first
    (multiple-value-bind (value found) (fset:lookup imports key)
      (when (and found (not (eq value fol.symbol:+symbol-unbound-sentinel+)))
        (return-from fol.env:lookup value)))
    ;; Check local items
    (multiple-value-bind (value found) (fset:lookup items key)
      (cond
        ((and found (not (eq value fol.symbol:+symbol-unbound-sentinel+)))
         value)
        (t
         ;; Check environment chain
         (let ((previous (fol.env:env-previous mod)))
           (if previous
               (fol.env:lookup previous variable-name)
               (error 'fol.env:fol-unbound-variable
                      :name variable-name
                      :message (format nil "Unbound variable: ~S" variable-name)))))))))

(defun find-module-in-chain (env)
  "Trace up the environment chain to find the first <module>.
   Returns the module or nil if none found."
  (loop for e = env then (fol.env:env-previous e)
        while e
        when (<module>? e) return e))

(defun use-module (name target-env)
  "Import all exported symbols and their values from module NAME into the
   nearest enclosing module in the environment chain. Symbols are added to
   the module's imports dict, not the current environment's bindings.
   NAME can be a string or symbol naming the module."
  (let ((source-module (find-module name)))
    (unless source-module
      (error "Module ~A not found" name))
    (let ((target-module (find-module-in-chain target-env)))
      (unless target-module
        (error "No module found in environment chain"))
      (let ((exports (fol.persistent:pslot-value source-module 'exports))
            (src-items (fol.persistent:pslot-value source-module 'fol.collection::items))
            (current-imports (fol.persistent:pslot-value target-module 'imports)))
        ;; Add exported bindings to the target module's imports dict
        (fset:do-set (sym exports)
          (let* ((key (fol.env:normalize-env-key sym))
                 (val (fset:lookup src-items key)))
            (when val
              (setf current-imports (fset:with current-imports key val)))))
        (fol.persistent:set-pslot-value target-module 'imports current-imports)))
    target-env))

;;; ============================================================================
;;; Standard Modules
;;; ============================================================================

(defun ensure-standard-modules ()
  "Ensure the standard modules exist in the registry.
   Creates %keyword (for all keywords) and fol-user (default user module)."
  (unless (find-module "%keyword")
    (make-module "%keyword"))
  (unless (find-module "fol-user")
    (make-module "fol-user")))

;; Initialize standard modules when this file is loaded
(ensure-standard-modules)
