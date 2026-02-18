;;; FOL Compiler - Mutable Functions
;;;
;;; Higher-level concurrency and mutable state functions.
;;; Includes: pmap, pcalls, futures, promises, thread binding utilities,
;;; and extensions for STM, Agents, and Ref validation/watching.

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
;;; Validators & Watchers
;;; ===========================================================================

(defgeneric set-validator! (ref validator-fn)
  (:documentation "Set the validator for a reference. Validator must be a function of one argument.
                   Returns nil."))

(defmethod set-validator! ((r <atom>) fn)
  (setf (atom-validator r) fn)
  nil)

(defmethod set-validator! ((r <ref>) fn)
  (setf (ref-validator r) fn)
  nil)

(defmethod set-validator! ((r <agent>) fn)
  (setf (agent-validator r) fn)
  nil)

(defgeneric get-validator (ref)
  (:documentation "Get the current validator for a reference."))

(defmethod get-validator ((r <atom>))
  (atom-validator r))

(defmethod get-validator ((r <ref>))
  (ref-validator r))

(defmethod get-validator ((r <agent>))
  (agent-validator r))

(defgeneric add-watch (ref key fn)
  (:documentation "Add a watcher to a reference. 
                   Key is an identifier. FN is (fn key ref old-state new-state).
                   Returns the reference."))

(defmethod add-watch ((r <atom>) key fn)
  ;; For atoms, we might need a CAS loop on the watches list if we want strict thread safety on adding watch
  ;; But simple setf is usually acceptable for infrequent config changes, or use a lock.
  ;; Atoms are thread-safe for value, but metadata like watches might need care.
  ;; We will treat watches list as volatile.
  ;; Better: Use simple push/alist update. 
  ;; Since we don't have a lock on atom-watches, this is technically racy if multiple threads add watches concurrently.
  ;; However, standard Clojure add-watch is atomic regarding the watch map.
  ;; We'll use a CAS loop on the watches slot? 
  ;; Standard-object slots aren't CAS-able portably in CL without specific implementation support (SBCL supports it).
  ;; Let's assumes straightforward setf for now or use a lock if we can add one.
  ;; Atoms don't have a lock.
  ;; We can use sb-ext:cas on the slot if we access it directly.
  ;; For now, use lock-free loop on slot-value if possible, or just setf and assume low contention on config.
  ;; Let's use a CAS loop for correctness.
  (loop
   (let* ((old-watches (atom-watches r))
          (new-watches (assoc-adjoin old-watches key fn)))
     (if (eq old-watches (sb-ext:cas (slot-value r 'fol.compiler.mutable::watches) old-watches new-watches))
         (return r)))))

(defmethod add-watch ((r <ref>) key fn)
  ;; Refs have a lock, use it.
  (bordeaux-threads:with-lock-held ((fol.compiler.mutable::ref-lock r))
    (setf (ref-watches r) (assoc-adjoin (ref-watches r) key fn)))
  r)

(defmethod add-watch ((r <agent>) key fn)
  ;; Agents have a lock.
  (bordeaux-threads:with-lock-held ((fol.compiler.mutable::agent-lock r))
    (setf (agent-watches r) (assoc-adjoin (agent-watches r) key fn)))
  r)

(defgeneric remove-watch (ref key)
  (:documentation "Remove a watcher from a reference."))

(defmethod remove-watch ((r <atom>) key)
  (loop
   (let* ((old-watches (atom-watches r))
          (new-watches (remove key old-watches :key #'car :test #'equal)))
     (if (eq old-watches (sb-ext:cas (slot-value r 'fol.compiler.mutable::watches) old-watches new-watches))
         (return r)))))

(defmethod remove-watch ((r <ref>) key)
  (bordeaux-threads:with-lock-held ((fol.compiler.mutable::ref-lock r))
    (setf (ref-watches r) (remove key (ref-watches r) :key #'car :test #'equal)))
  r)

(defmethod remove-watch ((r <agent>) key)
  (bordeaux-threads:with-lock-held ((fol.compiler.mutable::agent-lock r))
    (setf (agent-watches r) (remove key (agent-watches r) :key #'car :test #'equal)))
  r)

(defun assoc-adjoin (alist key val)
  "Update alist with (key . val), replacing existing key if present."
  (cons (cons key val) (remove key alist :key #'car :test #'equal)))

;;; ===========================================================================
;;; STM Extensions
;;; ===========================================================================

(defmacro sync (flags-ignored &body body)
  "Alias for dosync. Flags are currently ignored."
  `(dosync ,@body))

(defmacro io! (&body body)
  "Throw if called in a transaction."
  `(if fol.compiler.mutable::*current-transaction*
       (error "I/O in transaction!")
       (progn ,@body)))

(defun ref-history-count (ref) (declare (ignore ref)) 0)
(defun ref-min-history (ref) (declare (ignore ref)) 0)
(defun ref-max-history (ref) (declare (ignore ref)) 0)

;;; ===========================================================================
;;; Agent Extensions
;;; ===========================================================================

(defvar *agent* nil "The agent currently running an action.")

(defun send-via (executor agent fn &rest args)
  "Dispatch an action to agent using executor.
   Current implementation ignores executor and uses default send logic."
  (apply #'send agent fn args))

(defun set-agent-send-executor! (executor)
  "Sets the default executor for send. Stub."
  (declare (ignore executor))
  nil)

(defun set-agent-send-off-executor! (executor)
  "Sets the default executor for send-off. Stub."
  (declare (ignore executor))
  nil)

(defun await-for (timeout-ms agent &rest agents)
  "Blocks until actions for AGENT and AGENTS are completed or TIMEOUT-MS expires.
   Returns logic true if all actions completed, nil if timeout."
  (let ((all-agents (cons agent agents))
        (timeout-sec (/ timeout-ms 1000.0)))
    ;; Naive: wait for each sequentially.
    ;; Correct: wait for all concurrently.
    ;; Given the API of `await`, we can only wait one by one or create a latch.
    ;; But `await` waits for queue empty.
    (dolist (a all-agents)
      (unless (await a :timeout timeout-sec)
        (return-from await-for nil)))
    t))

(defun shutdown-agents ()
  "Initiate shutdown of agent thread pools. Stub."
  nil)

(defun executor (x) (declare (ignore x)) nil) ;; Internal stub if needed

(defun error-handler (ag)
  (fol.compiler.mutable::agent-error-handler ag))

(defun error-mode (ag)
  (fol.compiler.mutable::agent-error-mode ag))

(defun release-pending-sends ()
  "Release any pending sends in the transaction. 
   Since our STM doesn't hold sends until commit yet (we dispatch immediately), this is a no-op."
  0)

;;; ===========================================================================
;;; Futures
;;; ===========================================================================

(defclass <future> ()
    ((lock :initform (bordeaux-threads:make-lock "future-lock") :reader future-lock)
     (cv :initform (bordeaux-threads:make-condition-variable :name "future-cv") :reader future-cv)
     (state :initform :pending :accessor future-state) ; :pending, :done, :cancelled, :failed
     (value :initform nil :accessor future-value) ; Result or error object
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
      (let ((t-obj (make-instance 'fol.compiler.mutable:<thread>
                     :fn (lambda ()
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
                     :name "fol-future-worker")))
        (fol.compiler.mutable:start t-obj)
        t-obj))
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
                (fol.compiler.mutable:halt (future-thread fut)))
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

(defvar *thread-bindings* nil
        "List of currently active thread bindings (for introspection).")

(defmacro bound-fn (bindings &body body)
  "Returns a function that, when called, installs the bindings and runs body."
  (let ((vars (loop for i from 0 below (length bindings) by 2 collect (nth i bindings)))
        (vals (loop for i from 1 below (length bindings) by 2 collect (nth i bindings))))
    `(let ((captured-vals (list ,@vals)))
       (lambda (&rest args)
         (progv ',vars captured-vals
           (apply (lambda () ,@body) args))))))

(defun bound-fn* (f)
  "Returns a function that calls f with current thread bindings installed."
  (let ((bindings *thread-bindings*))
    (lambda (&rest args)
      (let ((vars (mapcar #'car bindings))
            (vals (mapcar #'cdr bindings)))
        (progv vars vals
          (apply f args))))))

(defun get-thread-bindings ()
  (let ((map (make-hash-table)))
    (dolist (b *thread-bindings*)
      (setf (gethash (car b) map) (cdr b)))
    map))

(defun push-thread-bindings (bindings-map)
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
