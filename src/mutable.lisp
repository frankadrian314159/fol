;;; FOL Compiler - Mutable References (Atoms, Refs, Agents)
;;;
;;; Three Clojure-style reference types for managing mutable state:
;;;
;;; Atoms provide a way to manage shared, synchronous, independent state
;;; in a multi-threaded environment.  Based on Clojure's atom type.
;;;
;;; Unlike the bootstrap lock-based implementation (bootstrap/atom.lisp),
;;; this uses SBCL's native Compare-and-Swap (CAS) for synchronization:
;;;   - deref is a plain slot read (no lock acquisition)
;;;   - reset! is a plain slot write (atomic for single-word values)
;;;   - swap! uses a CAS retry loop (lock-free, no deadlock risk)
;;;   - compare-and-set! is a single CAS operation
;;;
;;; CAS is the better strategy for atoms because:
;;;   - Lock-free: no blocking, no deadlock even if swap! fn re-enters
;;;   - Lower read overhead (deref has zero synchronization cost)
;;;   - Clojure itself uses AtomicReference (CAS) for atoms
;;;   - Natural fit for compare-and-set! as a first-class operation

(in-package :fol.compiler.mutable)

;;; ---------------------------------------------------------------------------
;;; Atom class
;;; ---------------------------------------------------------------------------

(defclass <atom> (standard-object)
    ((value :initarg :value
            :initform nil
            :accessor atom-value
            :documentation "The current value held by the atom.")
     (validator :initarg :validator
                :initform nil
                :accessor atom-validator
                :documentation "Optional unary validator function.")
     (watches :initform nil
              :accessor atom-watches
              :documentation "Alist of (key . function) watchers."))
  (:documentation "A thread-safe mutable reference type using CAS for atomic updates.
                   Atoms are not persistent — they hold mutable state."))

;;; ---------------------------------------------------------------------------
;;; Type predicate
;;; ---------------------------------------------------------------------------

(defun <atom>? (obj)
  "Return T if OBJ is an atom, NIL otherwise."
  (typep obj '<atom>))

;;; ---------------------------------------------------------------------------
;;; Constructor
;;; ---------------------------------------------------------------------------

(defun atom (initial-value &key validator)
  "Create a new atom with INITIAL-VALUE.
   If VALIDATOR is provided, it must be a unary function returning true."
  (when (and validator (not (funcall validator initial-value)))
        (error "Validator rejected initial value ~S for atom." initial-value))
  (make-instance '<atom> :value initial-value :validator validator))

;;; ---------------------------------------------------------------------------
;;; Dereference
;;; ---------------------------------------------------------------------------

(defgeneric deref (ref)
  (:documentation "Dereference REF to get its current value.
                   For atoms, returns the current value (lock-free read).
                   For non-reference types, returns the object itself."))

(defmethod deref ((atom-obj <atom>))
  "Dereference an atom. Lock-free — just reads the slot."
  (atom-value atom-obj))

(defmethod deref (obj)
  "Default: non-reference types dereference to themselves."
  obj)

;;; ---------------------------------------------------------------------------
;;; Reset
;;; ---------------------------------------------------------------------------

(defun reset! (atom-obj new-value)
  "Set the value of ATOM-OBJ to NEW-VALUE regardless of current value.
   Returns NEW-VALUE."
  (let ((validator (atom-validator atom-obj)))
    (when (and validator (not (funcall validator new-value)))
          (error "Validator rejected value ~S for atom." new-value)))
  (let ((old-value (atom-value atom-obj)))
    (setf (atom-value atom-obj) new-value)
    (notify-watches atom-obj old-value new-value))
  new-value)

;;; ---------------------------------------------------------------------------
;;; Swap (CAS retry loop)
;;; ---------------------------------------------------------------------------

(defun swap! (atom-obj fn &rest args)
  "Atomically update ATOM-OBJ to (apply FN current-value ARGS).
   Returns the new value."
  (loop
   (let* ((old (atom-value atom-obj))
          (new (apply fn old args)))
     (let ((validator (atom-validator atom-obj)))
       (when (and validator (not (funcall validator new)))
             (error "Validator rejected value ~S for atom." new)))
     (when (eq old (sb-ext:cas (slot-value atom-obj 'value) old new))
           (notify-watches atom-obj old new)
           (return new)))))

;;; ---------------------------------------------------------------------------
;;; Compare-and-Set
;;; ---------------------------------------------------------------------------

(defun compare-and-set! (atom-obj old-value new-value)
  "Atomically set ATOM-OBJ to NEW-VALUE if and only if its current value
   is EQ to OLD-VALUE.  Returns T if the swap succeeded, NIL otherwise."
  (let ((validator (atom-validator atom-obj)))
    (when (and validator (not (funcall validator new-value)))
          (error "Validator rejected value ~S for atom." new-value)))
  (when (eq old-value (sb-ext:cas (slot-value atom-obj 'value) old-value new-value))
        (notify-watches atom-obj old-value new-value)
        t))

;;; ---------------------------------------------------------------------------
;;; Printer
;;; ---------------------------------------------------------------------------

(defmethod print-object ((obj <atom>) stream)
  "Print an atom as #<ATOM value>."
  (print-unreadable-object (obj stream :type nil)
    (format stream "ATOM ~S" (atom-value obj))))

(defun notify-watches (ref old new)
  "Internal helper to notify all watchers of a ref."
  (let ((watches (cond ((typep ref '<atom>) (atom-watches ref))
                       ((typep ref '<ref>) (ref-watches ref))
                       ((typep ref '<agent>) (agent-watches ref)))))
    (dolist (w watches)
      (funcall (cdr w) (car w) ref old new))))

;;; =========================================================================
;;; Refs — Coordinated Synchronous References (STM)
;;; =========================================================================
;;;
;;; Refs allow multiple mutable locations to be updated atomically within
;;; a dosync transaction.  Uses optimistic concurrency with snapshot isolation:
;;;   - Each ref has a version counter bumped on every commit
;;;   - Transactions record reads (ref + version) and writes (ref + new-value)
;;;   - At commit time, all read versions are validated against current versions
;;;   - On conflict, the transaction is automatically retried
;;;   - Locks are acquired in a globally consistent order (by object address)
;;;     to prevent deadlock during the commit phase

;;; ---------------------------------------------------------------------------
;;; STM infrastructure
;;; ---------------------------------------------------------------------------

(defvar *current-transaction* nil
        "The currently active STM transaction, or NIL if outside dosync.")

(defvar *max-stm-retries* 10000
        "Maximum number of STM retry attempts before signaling an error.")

(defstruct (transaction (:conc-name txn-))
  "An STM transaction. Tracks reads, writes, commutes, and ensures."
  (read-set (make-hash-table :test 'eq) :type hash-table)
  (write-set (make-hash-table :test 'eq) :type hash-table)
  (commute-set (make-hash-table :test 'eq) :type hash-table)
  (ensure-set (make-hash-table :test 'eq) :type hash-table))

;;; ---------------------------------------------------------------------------
;;; Ref class
;;; ---------------------------------------------------------------------------

(defclass <ref> (standard-object)
    ((value :initarg :value
            :initform nil
            :accessor ref-value
            :documentation "The current committed value.")
     (version :initform 0
              :accessor ref-version
              :type fixnum
              :documentation "Monotonically increasing version counter.")
     (lock :initform (bordeaux-threads:make-lock "ref-lock")
           :reader ref-lock
           :documentation "Per-ref lock for commit-phase coordination.")
     (validator :initarg :validator
                :initform nil
                :accessor ref-validator
                :documentation "Optional unary predicate called on new values before commit.")
     (watches :initform nil
              :accessor ref-watches
              :documentation "Alist of (key . function) watchers."))
  (:documentation "A coordinated, synchronous mutable reference governed by STM.
                   Modify within dosync via ref-set, alter, or commute."))

;;; ---------------------------------------------------------------------------
;;; Type predicate
;;; ---------------------------------------------------------------------------

(defun <ref>? (obj)
  "Return T if OBJ is a ref, NIL otherwise."
  (typep obj '<ref>))

;;; ---------------------------------------------------------------------------
;;; Constructor
;;; ---------------------------------------------------------------------------

(defun ref (initial-value &key validator)
  "Create a new ref with INITIAL-VALUE.
   If VALIDATOR is provided, it must be a unary function returning a
   generalized boolean.  The validator is called on initial-value
   immediately and on every future value before commit."
  (when (and validator (not (funcall validator initial-value)))
        (error "Validator rejected initial value ~S for ref." initial-value))
  (make-instance '<ref> :value initial-value :validator validator))

;;; ---------------------------------------------------------------------------
;;; Deref for refs
;;; ---------------------------------------------------------------------------

(defmethod deref ((r <ref>))
  "Read the current value of a ref.
   Inside dosync: returns the transaction-local value (write-set first,
   then committed value).  Records the read in the transaction's read-set.
   Outside dosync: returns the committed value directly."
  (let ((txn *current-transaction*))
    (if txn
        (multiple-value-bind (write-val write-found)
            (gethash r (txn-write-set txn))
          (if write-found
              write-val
              (progn
               (unless (gethash r (txn-read-set txn))
                 (setf (gethash r (txn-read-set txn)) (ref-version r)))
               (ref-value r))))
        (ref-value r))))

;;; ---------------------------------------------------------------------------
;;; Ref operations (require active transaction)
;;; ---------------------------------------------------------------------------

(defun ref-set (r new-value)
  "Set the value of ref R to NEW-VALUE within a dosync transaction.
   Signals an error if called outside dosync.  Returns NEW-VALUE."
  (unless *current-transaction*
    (error "ref-set called outside dosync."))
  (setf (gethash r (txn-write-set *current-transaction*)) new-value)
  new-value)

(defun alter (r fn &rest args)
  "Within dosync, apply (FN current-value ARGS...) and store result in R.
   Signals an error if called outside dosync.  Returns the new value."
  (unless *current-transaction*
    (error "alter called outside dosync."))
  (let* ((current (deref r))
         (new-val (apply fn current args)))
    (setf (gethash r (txn-write-set *current-transaction*)) new-val)
    new-val))

(defun commute (r fn &rest args)
  "Within dosync, record a commutative update to ref R.
   The function is re-applied at commit time to the most recent committed
   value, allowing concurrent commutes to succeed without conflict.
   Returns an in-transaction estimate (applying fn to current value now)."
  (unless *current-transaction*
    (error "commute called outside dosync."))
  (let ((txn *current-transaction*))
    (push (cons fn args) (gethash r (txn-commute-set txn) nil))
    (let ((current (deref r)))
      (apply fn current args))))

(defun ensure (r)
  "Within dosync, protect ref R from modification by other transactions
   during this transaction.  At commit time, validates that R's version
   has not changed.  Returns R's current value."
  (unless *current-transaction*
    (error "ensure called outside dosync."))
  (let ((txn *current-transaction*))
    (unless (gethash r (txn-ensure-set txn))
      (setf (gethash r (txn-ensure-set txn)) (ref-version r)))
    (deref r)))

;;; ---------------------------------------------------------------------------
;;; Commit protocol
;;; ---------------------------------------------------------------------------

(defun %collect-all-refs (txn)
  "Collect all unique refs involved in transaction TXN."
  (let ((refs (make-hash-table :test 'eq)))
    (maphash (lambda (r v) (declare (ignore v)) (setf (gethash r refs) t))
             (txn-read-set txn))
    (maphash (lambda (r v) (declare (ignore v)) (setf (gethash r refs) t))
             (txn-write-set txn))
    (maphash (lambda (r v) (declare (ignore v)) (setf (gethash r refs) t))
             (txn-commute-set txn))
    (maphash (lambda (r v) (declare (ignore v)) (setf (gethash r refs) t))
             (txn-ensure-set txn))
    (let ((ref-list nil))
      (maphash (lambda (r v) (declare (ignore v)) (push r ref-list)) refs)
      ref-list)))

(defun %ref-sort-key (r)
  "Return a stable sort key for ref R.  Uses the object's memory address
   to impose a total order for lock acquisition (deadlock prevention)."
  (sb-kernel:get-lisp-obj-address r))

(defun %try-commit (txn)
  "Attempt to commit TXN.  Returns T on success, NIL on conflict.
   Acquires locks in a globally consistent order to prevent deadlock."
  (let* ((all-refs (%collect-all-refs txn))
         (sorted-refs (sort all-refs #'< :key #'%ref-sort-key))
         (acquired-locks nil)
         (success nil))
    (unwind-protect
        (progn
         ;; Phase 1: Acquire all locks in sorted order
         (dolist (r sorted-refs)
           (bordeaux-threads:acquire-lock (ref-lock r))
           (push r acquired-locks))
         ;; Phase 2-5 inside a block for early exit on conflict
         (block commit
           ;; Phase 2: Validate read-set versions
           (maphash (lambda (r version-at-read)
                      (unless (= version-at-read (ref-version r))
                        (return-from commit)))
                    (txn-read-set txn))
           ;; Phase 3: Validate ensure-set versions
           (maphash (lambda (r version-at-ensure)
                      (unless (= version-at-ensure (ref-version r))
                        (return-from commit)))
                    (txn-ensure-set txn))
           ;; Phase 4: Apply commute functions to latest committed values
           (maphash
             (lambda (r fn-args-list)
               (let ((val (multiple-value-bind (wv found)
                              (gethash r (txn-write-set txn))
                            (if found wv (ref-value r)))))
                 (dolist (fn-args (reverse fn-args-list))
                   (setf val (apply (car fn-args) val (cdr fn-args))))
                 (setf (gethash r (txn-write-set txn)) val)))
             (txn-commute-set txn))
           ;; Phase 5: Validate all new values against validators
           (maphash (lambda (r new-val)
                      (let ((validator (ref-validator r)))
                        (when (and validator (not (funcall validator new-val)))
                              (error "Validator rejected value ~S for ref." new-val))))
                    (txn-write-set txn))
           ;; Phase 6: Write new values, bump versions
           (maphash (lambda (r new-val)
                      (let ((old-val (ref-value r)))
                        (setf (ref-value r) new-val)
                        (incf (ref-version r))
                        (notify-watches r old-val new-val)))
                    (txn-write-set txn))
           (setf success t)))
      ;; Always release locks (in reverse acquisition order)
      (dolist (r acquired-locks)
        (bordeaux-threads:release-lock (ref-lock r))))
    success))

;;; ---------------------------------------------------------------------------
;;; dosync macro
;;; ---------------------------------------------------------------------------

(defmacro dosync (&body body)
  "Execute BODY within an STM transaction.
   All ref-set, alter, commute, and ensure operations within BODY are
   committed atomically.  If a conflict is detected at commit time,
   the transaction is automatically retried from the beginning.
   Nested dosync flattens into the enclosing transaction.
   Returns the value of the last form in BODY."
  (let ((result (gensym "RESULT"))
        (retries (gensym "RETRIES")))
    `(if *current-transaction*
         ;; Nested dosync: run in the existing transaction
         (progn ,@body)
         ;; Top-level dosync: retry loop
         (loop for ,retries fixnum from 0
               do (when (> ,retries *max-stm-retries*)
                        (error "STM transaction exceeded ~D retries."
                          *max-stm-retries*))
                 (let* ((*current-transaction* (make-transaction))
                        (,result (progn ,@body)))
                   (when (%try-commit *current-transaction*)
                         (return ,result)))))))

;;; ---------------------------------------------------------------------------
;;; Ref printer
;;; ---------------------------------------------------------------------------

(defmethod print-object ((obj <ref>) stream)
  "Print a ref as #<REF value>."
  (print-unreadable-object (obj stream :type nil)
    (format stream "REF ~S" (ref-value obj))))

;;; =========================================================================
;;; Threads
;;; =========================================================================
;;;
;;; A wrapper around native threads, modeled on Java's Thread class.
;;; Provides run, start, suspend, resume, and halt capabilities.

;;; ---------------------------------------------------------------------------
;;; Thread class
;;; ---------------------------------------------------------------------------

(defclass <thread> ()
    ((fn
      :initarg :fn
      :accessor thread-fn
      :documentation "The function to execute.")
     (bindings
      :initarg :bindings
      :initform nil
      :accessor thread-bindings
      :documentation "A dictionary or alist of {symbol value} for thread-local dynamic bindings.")
     (name
      :initarg :name
      :initform (gensym "THREAD-")
      :accessor thread-name
      :documentation "The name of the thread.")
     (native-thread
      :initform nil
      :accessor thread-native
      :documentation "The underlying bordeaux-threads object.")
     (lock
      :initform (bordeaux-threads:make-lock "thread-lock")
      :accessor thread-lock)
     (resume-cv
      :initform (bordeaux-threads:make-condition-variable :name "thread-resume-cv")
      :accessor thread-resume-cv)
     (state
      :initform :new
      :accessor thread-state
      :documentation "Current state: :new, :running, :suspended, :terminated."))
  (:documentation "A wrapper around native threads, modeled on Java's Thread class."))

;;; ---------------------------------------------------------------------------
;;; Generic Functions
;;; ---------------------------------------------------------------------------

(defgeneric run (thread)
  (:documentation "Execute the thread's main logic."))

(defgeneric start (thread)
  (:documentation "Start the thread's execution."))

(defgeneric suspend (thread)
  (:documentation "Suspend the running thread."))

(defgeneric resume (thread)
  (:documentation "Resume a suspended thread."))

(defgeneric halt (thread)
  (:documentation "Forcefully stop the thread."))

(defgeneric thread-join (thread)
  (:documentation "Wait for the thread to die. Returns the thread's return value."))

;;; ---------------------------------------------------------------------------
;;; Method Implementations
;;; ---------------------------------------------------------------------------

(defmethod run ((t <thread>))
  (let ((user-fn (thread-fn t))
        (binds (thread-bindings t)))
    (let ((vars (mapcar #'car binds))
          (vals (mapcar #'cdr binds)))
      (progv vars vals
        (funcall user-fn)))))

(defmethod start ((t <thread>))
  (bordeaux-threads:with-lock-held ((thread-lock t))
    (unless (eq (thread-state t) :new)
      (error "Thread has already been started.")))

  (setf (thread-state t) :running)
  (setf (thread-native t)
    (bordeaux-threads:make-thread
      (lambda ()
        (unwind-protect
            (run t)
          (setf (thread-state t) :terminated)))
      :name (string (thread-name t)))))

(defmethod suspend ((t <thread>))
  (bordeaux-threads:with-lock-held ((thread-lock t))
    (when (eq (thread-state t) :running)
          (setf (thread-state t) :suspended)
          (bordeaux-threads:interrupt-thread
            (thread-native t)
            (lambda ()
              (bordeaux-threads:with-lock-held ((thread-lock t))
                (loop while (eq (thread-state t) :suspended)
                      do (bordeaux-threads:condition-wait (thread-resume-cv t) (thread-lock t)))))))))

(defmethod resume ((t <thread>))
  (bordeaux-threads:with-lock-held ((thread-lock t))
    (when (eq (thread-state t) :suspended)
          (setf (thread-state t) :running)
          (bordeaux-threads:condition-notify (thread-resume-cv t)))))

(defmethod halt ((t <thread>))
  (let ((native (thread-native t)))
    (when (and native (bordeaux-threads:thread-alive-p native))
          (setf (thread-state t) :terminated)
          (bordeaux-threads:destroy-thread native))))

(defmethod thread-join ((t <thread>))
  (let ((native (thread-native t)))
    (when native
          (bordeaux-threads:join-thread native))))

;;; =========================================================================
;;; Agents — Independent Asynchronous References
;;; =========================================================================
;;;
;;; Agents manage independent state that is updated asynchronously.
;;; Actions (functions) are dispatched to an agent and executed on a
;;; background thread, serialized per-agent.  The agent's value is updated
;;; to the return value of each action.
;;;
;;; Error handling: in :fail mode (default), an error stops the agent
;;; until restart-agent is called.  In :continue mode, errors are cached
;;; but the agent keeps processing subsequent actions.

;;; ---------------------------------------------------------------------------
;;; Agent class
;;; ---------------------------------------------------------------------------

(defclass <agent> (standard-object)
    ((value :initarg :value
            :initform nil
            :accessor agent-value
            :documentation "The current value held by the agent.")
     (lock :initform (bordeaux-threads:make-lock "agent-lock")
           :reader agent-lock
           :documentation "Lock protecting value, error state, and queue.")
     (queue :initform nil
            :accessor agent-queue
            :documentation "List of pending actions (each is a function of one arg).")
     (active-p :initform nil
               :accessor agent-active-p
               :type boolean
               :documentation "T when a worker thread is running for this agent.")
     (error-val :initform nil
                :accessor agent-error-val
                :documentation "Cached error from the last failed action, or NIL.")
     (error-handler :initarg :error-handler
                    :initform nil
                    :accessor agent-error-handler
                    :documentation "Function of (agent error) called when an action fails.")
     (error-mode :initarg :error-mode
                 :initform :fail
                 :accessor agent-error-mode
                 :documentation ":FAIL or :CONTINUE.")
     (idle-cv :initform (bordeaux-threads:make-condition-variable :name "agent-idle")
              :reader agent-idle-cv
              :documentation "Condition variable notified when the agent becomes idle.")
     (idle-p :initform t
             :accessor agent-idle-p
             :type boolean
             :documentation "T when the agent has no pending actions and no active worker.")
     (validator :initarg :validator
                :initform nil
                :accessor agent-validator
                :documentation "Optional validator function.")
     (watches :initform nil
              :accessor agent-watches
              :documentation "Alist of watchers."))
  (:documentation "An asynchronous mutable reference. Actions are dispatched
                   to a background thread and executed serially per-agent."))

;;; ---------------------------------------------------------------------------
;;; Type predicate
;;; ---------------------------------------------------------------------------

(defun <agent>? (obj)
  "Return T if OBJ is an agent, NIL otherwise."
  (typep obj '<agent>))

;;; ---------------------------------------------------------------------------
;;; Constructor
;;; ---------------------------------------------------------------------------

(defun agent (initial-value &key error-handler (error-mode :fail) validator)
  "Create a new agent with INITIAL-VALUE.
   :error-handler -- function of (agent error), called when an action fails.
   :error-mode    -- :FAIL (default) or :CONTINUE.
   :validator     -- function of value, validation check."
  (unless (member error-mode '(:fail :continue))
    (error "Invalid error-mode ~S. Must be :FAIL or :CONTINUE." error-mode))
  (when (and validator (not (funcall validator initial-value)))
        (error "Validator rejected initial value ~S for agent." initial-value))
  (make-instance '<agent>
    :value initial-value
    :error-handler error-handler
    :error-mode error-mode
    :validator validator))

;;; ---------------------------------------------------------------------------
;;; Deref for agents
;;; ---------------------------------------------------------------------------

(defmethod deref ((ag <agent>))
  "Read the current value of an agent.  Returns immediately.
   Does not coordinate with pending actions."
  (agent-value ag))

;;; ---------------------------------------------------------------------------
;;; Worker loop
;;; ---------------------------------------------------------------------------

(defun %agent-worker (ag)
  "Worker loop for agent AG.  Processes actions from the queue until
   the queue is empty or the agent enters an error state in :fail mode.
   Called on a dedicated thread."
  (loop
   (let ((action nil))
     ;; Dequeue next action under lock
     (bordeaux-threads:with-lock-held ((agent-lock ag))
       (cond
        ;; In :fail mode with a cached error — stop processing
        ((and (eq (agent-error-mode ag) :fail)
              (agent-error-val ag))
          (setf (agent-idle-p ag) t
            (agent-active-p ag) nil)
          (bordeaux-threads:condition-notify (agent-idle-cv ag))
          (return))
        ;; Queue empty — go idle and exit thread
        ((null (agent-queue ag))
          (setf (agent-idle-p ag) t
            (agent-active-p ag) nil)
          (bordeaux-threads:condition-notify (agent-idle-cv ag))
          (return))
        ;; Dequeue the next action
        (t
          (setf action (pop (agent-queue ag))))))
     ;; Execute action outside the lock
     (when action
           (handler-case
               (let ((new-val (funcall action (agent-value ag))))
                 (let ((validator (agent-validator ag)))
                   (when (and validator (not (funcall validator new-val)))
                         (error "Validator rejected value ~S for agent." new-val)))
                 (bordeaux-threads:with-lock-held ((agent-lock ag))
                   (let ((old-val (agent-value ag)))
                     (setf (agent-value ag) new-val)
                     (notify-watches ag old-val new-val))))
             (error (e)
               (bordeaux-threads:with-lock-held ((agent-lock ag))
                 (setf (agent-error-val ag) e)
                 (when (agent-error-handler ag)
                       (ignore-errors
                         (funcall (agent-error-handler ag) ag e))))))))))

(defun %ensure-agent-running (ag)
  "If the agent has no active worker thread, start one.
   Must be called with agent-lock held."
  (unless (agent-active-p ag)
    (setf (agent-idle-p ag) nil
      (agent-active-p ag) t)
    (let ((thread (make-instance '<thread>
                    :fn (lambda () (%agent-worker ag))
                    :name "fol-agent-worker")))
      (start thread)))

  ;;; ---------------------------------------------------------------------------
  ;;; Send / Send-off
  ;;; ---------------------------------------------------------------------------

  (defun send (ag fn &rest args)
    "Dispatch an action to agent AG.  The action is (FN current-value ARGS...).
   Returns the agent immediately.  The action will be executed asynchronously
   on a background thread.  Actions are serialized per-agent.
   Signals an error if the agent is in :fail mode with a cached error."
    (let ((action (if args
                      (lambda (val) (apply fn val args))
                      fn)))
      (bordeaux-threads:with-lock-held ((agent-lock ag))
        (when (and (eq (agent-error-mode ag) :fail)
                   (agent-error-val ag))
              (error "Agent is in error state: ~A. Use restart-agent to clear."
                (agent-error-val ag)))
        (setf (agent-queue ag)
          (nconc (agent-queue ag) (cl:list action)))
        (%ensure-agent-running ag)))
    ag)

  (defun send-off (ag fn &rest args)
    "Like SEND, but intended for potentially blocking I/O actions.
   In this implementation, send-off behaves identically to send
   (both use a dedicated thread per agent).  The API distinction is
   preserved for future pool-based optimization."
    (apply #'send ag fn args))

  ;;; ---------------------------------------------------------------------------
  ;;; Await
  ;;; ---------------------------------------------------------------------------

  (defun await (ag &key (timeout nil))
    "Block until all currently pending actions on agent AG have completed.
   If TIMEOUT is provided (in seconds), returns NIL on timeout, T on completion.
   If no timeout, blocks indefinitely and returns T."
    (bordeaux-threads:with-lock-held ((agent-lock ag))
      (loop until (agent-idle-p ag)
            do (if timeout
                   (progn
                    (bordeaux-threads:condition-wait
                      (agent-idle-cv ag) (agent-lock ag)
                      :timeout timeout)
                    (unless (agent-idle-p ag)
                      (return-from await nil)))
                   (bordeaux-threads:condition-wait
                     (agent-idle-cv ag) (agent-lock ag)))))
    t)

  ;;; ---------------------------------------------------------------------------
  ;;; Error management
  ;;; ---------------------------------------------------------------------------

  (defun agent-error (ag)
    "Return the cached error from the last failed action on AG, or NIL."
    (agent-error-val ag))

  (defun restart-agent (ag new-value &key clear-actions)
    "Clear the error state of AG and set its value to NEW-VALUE.
   If CLEAR-ACTIONS is true, also discard all pending actions.
   Returns AG."
    (bordeaux-threads:with-lock-held ((agent-lock ag))
      (setf (agent-error-val ag) nil
        (agent-value ag) new-value)
      (when clear-actions
            (setf (agent-queue ag) nil))
      (when (agent-queue ag)
            (%ensure-agent-running ag)))
    ag)

  (defun set-error-handler! (ag handler)
    "Set the error handler for agent AG.
   HANDLER is a function of (agent error).  Returns AG."
    (bordeaux-threads:with-lock-held ((agent-lock ag))
      (setf (agent-error-handler ag) handler))
    ag)

  (defun set-error-mode! (ag mode)
    "Set the error mode for agent AG.  MODE is :FAIL or :CONTINUE.
   Returns AG."
    (unless (member mode '(:fail :continue))
      (error "Invalid error-mode ~S. Must be :FAIL or :CONTINUE." mode))
    (bordeaux-threads:with-lock-held ((agent-lock ag))
      (setf (agent-error-mode ag) mode))
    ag)

  ;;; ---------------------------------------------------------------------------
  ;;; Agent printer
  ;;; ---------------------------------------------------------------------------

  (defmethod print-object ((obj <agent>) stream)
    "Print an agent as #<AGENT value> or #<AGENT value ERROR: ...>."
    (print-unreadable-object (obj stream :type nil)
      (let ((err (agent-error-val obj)))
        (if err
            (format stream "AGENT ~S" (agent-value obj))))))

  ;;; =========================================================================
  ;;; Thread Pool
  ;;; =========================================================================

  (defvar *thread-pool-size* 16
          "Number of worker threads in the global thread pool.")

  (defvar *work-queue* nil
          "Queue of work items to be processed by worker threads.")

  (defvar *work-queue-lock* (bordeaux-threads:make-lock "work-queue-lock")
          "Lock protecting the work queue.")

  (defvar *work-queue-condvar* (bordeaux-threads:make-condition-variable :name "work-queue-condvar")
          "Condition variable for signaling work availability.")

  (defvar *worker-threads* nil
          "Vector of worker threads (each is a <thread> instance).")

  (defvar *thread-pool-shutdown* nil
          "Flag indicating thread pool should shut down.")

  (defstruct work-item
    "A unit of work for the thread pool."
    (fn nil :type function)
    (args nil :type list)
    (result-box nil :type cons) ; cons cell to store result
    (done-lock nil)
    (done-condvar nil))

  (defun %worker-thread-loop ()
    "Main loop for worker threads. Pulls work from queue and executes it."
    (loop
     (let ((work nil))
       ;; Get work from queue
       (bordeaux-threads:with-lock-held (*work-queue-lock*)
         (loop while (and (null *work-queue*) (not *thread-pool-shutdown*))
               do (bordeaux-threads:condition-wait *work-queue-condvar* *work-queue-lock*))
         (when *thread-pool-shutdown*
               (return-from %worker-thread-loop))
         (when *work-queue*
               (setf work (pop *work-queue*))))

       ;; Execute work
       (when work
             (let ((result (handler-case
                               (apply (work-item-fn work) (work-item-args work))
                             (error (e)
                               (format *error-output* "~&Worker thread error: ~A~%" e)
                               :error))))
               ;; Store result and signal completion
               (setf (car (work-item-result-box work)) result)
               (bordeaux-threads:with-lock-held ((work-item-done-lock work))
                 (bordeaux-threads:condition-notify (work-item-done-condvar work))))))))

  (defun initialize-thread-pool ()
    "Initialize the global thread pool with worker threads."
    (unless *worker-threads*
      (setf *work-queue* nil)
      (setf *work-queue-lock* (bordeaux-threads:make-lock "work-queue-lock"))
      (setf *work-queue-condvar* (bordeaux-threads:make-condition-variable :name "work-queue-condvar"))
      (setf *thread-pool-shutdown* nil)
      (setf *worker-threads*
        (make-array *thread-pool-size*
          :initial-contents
          (loop for i from 0 below *thread-pool-size*
                collect (let ((thread (make-instance '<thread>
                                        :fn #'%worker-thread-loop
                                        :name (format nil "worker-~D" i))))
                          (start thread)
                          thread))))))

  (defun submit-work (fn args)
    "Submit work to the thread pool. Returns a work-item that can be waited on."
    (initialize-thread-pool) ; Ensure pool is initialized
    (let ((work (make-work-item
                 :fn fn
                 :args args
                 :result-box (cons nil nil)
                 :done-lock (bordeaux-threads:make-lock)
                 :done-condvar (bordeaux-threads:make-condition-variable))))
      (bordeaux-threads:with-lock-held (*work-queue-lock*)
        (setf *work-queue* (nconc *work-queue* (list work)))
        (bordeaux-threads:condition-notify *work-queue-condvar*))
      work))

  (defun wait-for-work (work-item)
    "Wait for a work item to complete and return its result."
    (bordeaux-threads:with-lock-held ((work-item-done-lock work-item))
      (loop while (null (car (work-item-result-box work-item)))
            do (bordeaux-threads:condition-wait (work-item-done-condvar work-item)
                                                (work-item-done-lock work-item))))
    (car (work-item-result-box work-item)))
