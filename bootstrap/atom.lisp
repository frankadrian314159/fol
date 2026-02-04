(in-package :fol.atom)

;;; ============================================================================
;;; FOL Atom - Mutable References
;;; ============================================================================
;;;
;;; Atoms provide a way to manage shared, synchronous, independent state
;;; in a multi-threaded environment. All operations are protected by a mutex.
;;; Based on Clojure's atom type and are not persistent because they are mutable.
;;; ============================================================================

(defclass <atom> ()
  ((value :initarg :value
          :accessor atom-value
          :documentation "The current value held by the atom.")
   (lock :initarg :lock
         :accessor atom-lock
         :documentation "Mutex for thread-safe operations."))
  (:documentation "A thread-safe mutable reference type that supports atomic updates."))

(defun <atom>? (obj)
  "Return T if OBJ is an atom."
  (typep obj '<atom>))

(defun atom (&optional (initial-value nil))
  "Create a new atom with INITIAL-VALUE."
  (make-instance '<atom>
                 :value (fol.wrappers:fol-value initial-value)
                 :lock (bordeaux-threads:make-lock "atom-lock")))

(defgeneric deref (ref)
  (:documentation "Dereference REF to get its current value. Works with atoms, delays, futures, etc."))

(defmethod deref ((atom-obj <atom>))
  "Dereference an atom to get its current value. Thread-safe."
  (handler-case
      (bordeaux-threads:with-lock-held ((atom-lock atom-obj))
        (atom-value atom-obj))
    (error (e)
      (format *error-output* "~&Error in deref: ~A~%" e)
      (error e))))

(defmethod deref ((delay-obj function))
  "Dereference a delay, forcing its evaluation and returning its value."
  (funcall delay-obj :force)
  (funcall delay-obj))

(defmethod deref (obj)
  "Default deref for non-reference types - just return the object."
  obj)

(defun reset! (atom-obj new-value)
  "Set the value of ATOM-OBJ to NEW-VALUE. Returns NEW-VALUE. Thread-safe."
  (unless (<atom>? atom-obj)
    (error "reset! requires an atom, got ~A" atom-obj))
  (handler-case
      (let ((wrapped-value (fol.wrappers:fol-value new-value)))
        (bordeaux-threads:with-lock-held ((atom-lock atom-obj))
          (setf (atom-value atom-obj) wrapped-value)
          wrapped-value))
    (error (e)
      (format *error-output* "~&Error in reset!: ~A~%" e)
      (error e))))

(defun swap! (atom-obj fn &rest args)
  "Atomically swaps the value of ATOM-OBJ to be (apply FN current-value ARGS).
   Returns the new value. Thread-safe."
  (unless (<atom>? atom-obj)
    (error "swap! requires an atom, got ~A" atom-obj))
  (handler-case
      (bordeaux-threads:with-lock-held ((atom-lock atom-obj))
        (let* ((current-value (atom-value atom-obj))
               (new-value (fol.eval:apply-function fn (cons current-value args))))
          (setf (atom-value atom-obj) new-value)
          new-value))
    (error (e)
      (format *error-output* "~&Error in swap!: ~A~%" e)
      (error e))))

;;; Printer
(defmethod print-object ((obj <atom>) stream)
  "Print an atom. Thread-safe - acquires lock to read value."
  (handler-case
      (let ((val (bordeaux-threads:with-lock-held ((atom-lock obj))
                   (atom-value obj))))
        (format stream "#<ATOM ~A>" val))
    (error (e)
      (format *error-output* "~&Error in print-object for atom: ~A~%" e)
      (format stream "#<ATOM <error printing value>>"))))
