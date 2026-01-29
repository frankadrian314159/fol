(in-package fol.env)

;;; ============================================================================
;;; Environment Key Normalization
;;; ============================================================================
;;; We use symbol names (strings) as keys to ensure symbols with the same name
;;; in different packages are treated as the same variable.

(defun normalize-env-key (key)
  "Normalize a key for environment lookup.
   For symbols, returns the symbol name string (uppercased).
   For other types, returns the fol-value of the key."
  (let ((raw (fol.wrappers:fol-value key)))
    (if (symbolp raw)
        (symbol-name raw)
        raw)))

;;; ============================================================================
;;; Environment Class
;;; ============================================================================

(defclass <env> (fol.collection:<dict>)
  ((previous :initarg :previous
             :initform nil
             :accessor env-previous
             :type (or null <env>)
             :documentation "Link to the previous (enclosing) environment."))
  (:metaclass fol.persistent:persistent-class)
  (:documentation "An environment for variable bindings that chains to a previous environment.
                   Inherits from <dict> for persistent key-value storage."))

(defun make-env (&optional previous &rest pairs)
  "Create a new <env>, optionally with a previous environment and initial bindings.
   Usage: (make-env nil 'var1 val1 'var2 val2 ...)
          (make-env parent-env 'var1 val1 ...)"
  (let ((map (fset:empty-map)))
    (loop for (key val) on pairs by #'cddr
          do (setf map (fset:with map
                                  (normalize-env-key key)
                                  (fol.wrappers:fol-value val))))
    (make-instance '<env> :items map :previous previous)))

(defgeneric <env>? (obj)
  (:documentation "Returns T if OBJ is a FOL <env>."))
(defmethod <env>? (obj) nil)
(defmethod <env>? ((obj <env>)) t)

;;; ============================================================================
;;; Environment Lookup
;;; ============================================================================

(defgeneric lookup (env variable-name)
  (:documentation "Look up a variable in the environment chain.
                   Searches the current environment and all previous (enclosing) environments.
                   Signals an unbound-variable error if not found."))

(defmethod lookup ((env <env>) variable-name)
  "Look up a variable by name, traversing the environment chain.
   If the variable is not found in this environment or any previous environments,
   signal an unbound-variable error."
  (let ((items (fol.persistent:pslot-value env 'fol.collection::items)))
    ;; Try to find in current environment using multiple-value-bind
    ;; to distinguish between "key not found" and "key bound to nil"
    (multiple-value-bind (value found) (fset:lookup items (normalize-env-key variable-name))
      (cond
        ;; Found in current environment and not the sentinel value
        ((and found (not (eq value fol.symbol:+symbol-unbound-sentinel+)))
         value)
        ;; Found but it's the sentinel (treat as unbound)
        ((and found (eq value fol.symbol:+symbol-unbound-sentinel+))
         (let ((previous (env-previous env)))
           (if previous
               (lookup previous variable-name)
               (error 'fol-unbound-variable
                      :name variable-name
                      :message (format nil "Unbound variable: ~S" variable-name)))))
        ;; Not found in current environment, check previous
        (t
         (let ((previous (env-previous env)))
           (if previous
               (lookup previous variable-name)
               ;; No previous environment and variable not found
               (error 'fol-unbound-variable
                      :name variable-name
                      :message (format nil "Unbound variable: ~S" variable-name)))))))))

(define-condition fol-unbound-variable (error)
  ((name :initarg :name :accessor fol-unbound-variable-name)
   (message :initarg :message :accessor fol-unbound-variable-message))
  (:report (lambda (condition stream)
             (format stream "~A" (fol-unbound-variable-message condition)))))
