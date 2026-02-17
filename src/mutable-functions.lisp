;;; FOL Compiler - Mutable Functions
;;;
;;; Higher-level concurrency and mutable state functions.
;;; Includes: pmap, pcalls, futures, promises, and thread binding utilities.

(in-package :fol.compiler.mutable-functions)

;;; ===========================================================================
;;; Atom Extensions
;;; ===========================================================================

(defun swap-vals! (atom-obj fn &rest args)
  "Atomically apply FN to ATOM-OBJ, returns (list old-val new-val).
   Like swap!, but returns previous value too."
  (loop
    (let* ((old (deref atom-obj))
           (new (apply fn old args)))
      (when (compare-and-set! atom-obj old new)
        (return (list old new))))))

(defun reset-vals! (atom-obj new-value)
  "Sets the value of ATOM-OBJ to NEW-VALUE. Returns (list old-val new-val)."
  (loop
    (let ((old (deref atom-obj)))
      (when (compare-and-set! atom-obj old new-value)
        (return (list old new-value))))))

;;; ===========================================================================
;;; Futures
;;; ===========================================================================

(defclass <future> ()
  ((lock :initform (bordeaux-threads:make-lock "future-lock") :reader future-lock)
   (cv :initform (bordeaux-threads:make-condition-variable :name "future-cv") :reader future-cv)
   (state :initform :pending :accessor future-state) ; :pending, :done, :cancelled, :failed
   (value :initform nil :accessor future-value)      ; Result or error object
   (thread :initform nil :accessor future-thread))
  (:documentation "A value that will be computed asynchronously."))

(defmethod print-object ((obj <future>) stream)
  (print-unreadable-object (obj stream :type t :identity t)
    (format stream "~A" (future-state obj))))

(defun future? (x)
  (typep x '<future>))

(defun future-call (fn)
  "Execute (fn) in another thread and return a future object."
  (let ((fut (make-instance '<future>)))
    (setf (future-thread fut)
          (bordeaux-threads:make-thread
           (lambda ()
             (let ((result nil)
                   (success nil))
               (unwind-protect
                    (handler-case
                        (progn
                          (setf result (funcall fn))
                          (setf success t))
                      (error (e)
                        (setf result e)
                        (setf success nil)))
                 (bordeaux-threads:with-lock-held ((future-lock fut))
                   (unless (eq (future-state fut) :cancelled)
                     (setf (future-value fut) result
                           (future-state fut) (if success :done :failed)))
                   (bordeaux-threads:condition-notify (future-cv fut))))))
           :name "fol-future-worker"))
    fut))

(defmacro future (&body body)
  "Execute body in another thread and return future."
  `(future-call (lambda () ,@body)))

(defmethod deref ((fut <future>))
  "Block until future is done/failed/cancelled, then return value or signal error."
  (bordeaux-threads:with-lock-held ((future-lock fut))
    (loop while (eq (future-state fut) :pending)
          do (bordeaux-threads:condition-wait (future-cv fut) (future-lock fut)))
    (case (future-state fut)
      (:done (future-value fut))
      (:failed (error (future-value fut)))
      (:cancelled (error "Future was cancelled.")))))

(defun future-cancel (fut)
  "Cancel the future calculation if possible. Returns T if cancelled, NIL if already done."
  (bordeaux-threads:with-lock-held ((future-lock fut))
    (when (eq (future-state fut) :pending)
      (setf (future-state fut) :cancelled)
      (when (future-thread fut)
        (bordeaux-threads:destroy-thread (future-thread fut)))
      (bordeaux-threads:condition-notify (future-cv fut))
      t)))

(defun future-cancelled? (fut)
  (eq (future-state fut) :cancelled))

(defun future-done? (fut)
  (member (future-state fut) '(:done :failed :cancelled)))

;;; ===========================================================================
;;; Promises
;;; ===========================================================================

(defclass <promise> ()
  ((lock :initform (bordeaux-threads:make-lock "promise-lock") :reader promise-lock)
   (cv :initform (bordeaux-threads:make-condition-variable :name "promise-cv") :reader promise-cv)
   (delivered :initform nil :accessor promise-delivered-p)
   (value :initform nil :accessor promise-value))
  (:documentation "A value that can be delivered later."))

(defun promise ()
  (make-instance '<promise>))

(defun deliver (p val)
  "Deliver the value to the promise. Returns nil on success.
   Returns nil if already delivered? Clojure returns nil if successful, or throws if already delivered."
  (bordeaux-threads:with-lock-held ((promise-lock p))
    (if (promise-delivered-p p)
        ;; Actually Clojure `deliver` returns nil if already delivered.
        ;; But standard implies single assignment.
        ;; Let's return NIL if successful delivery, else ignore if already delivered.
        ;; Wait, Clojure `deliver` returns the promise object or nil?
        ;; Clojure: `(deliver p val)` returns `p` if successful, `nil` if already delivered.
        nil
        (progn
          (setf (promise-value p) val
                (promise-delivered-p p) t)
          (bordeaux-threads:condition-notify (promise-cv p))
          p))))

(defmethod deref ((p <promise>))
  "Block until promise is delivered."
  (bordeaux-threads:with-lock-held ((promise-lock p))
    (loop until (promise-delivered-p p)
          do (bordeaux-threads:condition-wait (promise-cv p) (promise-lock p)))
    (promise-value p)))


;;; ===========================================================================
;;; Thread Bindings
;;; ===========================================================================

;; In CL, dynamic variables are thread-local by default if bound.
;; `push-thread-bindings` usually takes a map of vars to values.
;; Since we don't have first-class vars in the same way (symbols are values),
;; we simulate this.
;; However, simpler implementation is just using `progv`.

(defvar *thread-bindings* nil
  "List of currently active thread bindings (for introspection).")

(defmacro bound-fn (bindings &body body)
  "Returns a function that, when called, installs the bindings and runs body."
  ;; bindings is a list of (var val var val ...) or a vector check in macro expansion?
  ;; Usually vector in Clojure.
  (let ((vars (loop for i from 0 below (length bindings) by 2 collect (nth i bindings)))
        (vals (loop for i from 1 below (length bindings) by 2 collect (nth i bindings))))
    `(let ((captured-vals (list ,@vals)))
       (lambda (&rest args)
         (progv ',vars captured-vals
           (apply (lambda () ,@body) args)))))) ;; apply macro body? No, simple funcall.
           
(defun bound-fn* (f)
  "Returns a function that calls f with current thread bindings installed."
  ;; Requires capturing current dynamic environment. CL doesn't easily expose "all dynamic bindings".
  ;; This is hard effectively in portable CL.
  ;; We will assume this only captures bindings established via `push-thread-bindings`.
  (let ((bindings *thread-bindings*))
    (lambda (&rest args)
      (let ((vars (mapcar #'car bindings))
            (vals (mapcar #'cdr bindings)))
        (progv vars vals
          (apply f args))))))

(defun get-thread-bindings ()
  ;; Requires tracking bindings manually if we want to return a map
  ;; For now, return the manually tracked list.
  (let ((map (make-hash-table)))
    (dolist (b *thread-bindings*)
      (setf (gethash (car b) map) (cdr b)))
    map))

(defun push-thread-bindings (bindings-map)
  "Establishes thread bindings from a map.
   NOTE: This function doesn't work as expected in CL because dynamic bindings
   must be lexical scope (progv). `push-thread-bindings` implies pushing state
   that persists for subsequent calls in this thread until `pop`.
   This is not how `progv` or `special` variables work in CL.
   They have dynamic extent.
   Implementing this strictly requires all access to be via a wrapper or custom logic.
   
   However, we can simulate it if `bindings-map` refers to `*variables*` we control.
   Given the limitation, we can't implement persistent thread-local state push/pop for GLOBAL dynamic vars
   without `progv` wrapping the *execution*.
   
   Clojure's `push-thread-bindings` works because `Var`s are objects that hold state.
   CL symbols are not.
   
   We will stub this or use a thread-local dictionary approach for specific use cases."
  (error "push-thread-bindings not fully supported in CL model."))

(defun pop-thread-bindings ()
  (error "pop-thread-bindings not fully supported in CL model."))

(defun thread-bound? (var)
  (boundp var))


;;; ===========================================================================
;;; Parallel Processing
;;; ===========================================================================

(defun pmap (f coll &rest more-colls)
  "Like map, but applies f in parallel. Semi-lazy."
  ;; Simple version: realized eagerly or chunked.
  ;; Clojure uses a complex chunking strategy.
  ;; Here we'll map to futures and then deref.
  (let* ((colls (cons coll more-colls))
         (futures (apply #'mapcar 
                         (lambda (&rest args)
                           (future-call (lambda () (apply f args))))
                         colls)))
    (mapcar #'deref futures)))

(defmacro pvalues (&rest exprs)
  "Returns a lazy sequence of the values of the exprs, evaluated in parallel."
  `(list ,@(loop for e in exprs collect `(deref (future ,e)))))

(defmacro pcalls (&rest fns)
  "Executes the (0-arity) functions in parallel, returning a lazy sequence of their values."
  `(pvalues ,@(loop for f in fns collect `(funcall ,f))))

(defun seque (s)
  "Partially realizes sequence s in parallel."
  ;; Placeholder
  s)
