;;; FOL Library - core.async
;;;
;;; Implements Clojure's core.async API for FOL.
;;; Provides CSP-style channels and go blocks built on bordeaux-threads.
;;;
;;; Key differences from Clojure's core.async:
;;;   - go blocks run as real OS threads (not green threads/coroutines).
;;;     The go macro is a thin wrapper around bordeaux-threads:make-thread.
;;;   - alts!!/alts! use short-sleep polling combined with per-channel
;;;     notification hints rather than a proper waitlist graph.
;;;   - All blocking operations (>!! <!!) are safe to call from any thread.
;;;   - >! and <! are identical to >!! and <!! in this implementation.
;;;   - Transducers are supported via a two-argument (step rf item) protocol.
;;;
;;; Threading model summary:
;;;   (chan)           → unbuffered rendezvous channel
;;;   (chan n)         → fixed buffer of size n
;;;   (chan (buffer n))          → same as (chan n)
;;;   (chan (dropping-buffer n)) → drops new items when full
;;;   (chan (sliding-buffer  n)) → drops oldest items when full
;;;   (chan n xf)      → buffered channel with transducer xf
;;;
;;;   (go body)        → start a thread; returns a result channel
;;;   (go-loop [...] body) → go + loop/recur pattern
;;;   (thread fn)      → start a thread with fn; returns a result channel
;;;   (>!! ch v)       → blocking put; returns true/false
;;;   (<!! ch)         → blocking take; returns value or nil on close
;;;   (close! ch)      → close the channel
;;;   (offer! ch v)    → non-blocking put; returns true or nil
;;;   (poll! ch)       → non-blocking take; returns [value true] or [nil false]
;;;   (alts!! ops)     → block until one channel in ops is ready
;;;   (timeout ms)     → channel that closes after ms milliseconds
;;;   (pipe from to)   → pipe all values from → to
;;;   (merge chs)      → merge multiple channels into one

(in-package :fol.lib.core-async)

;;; ---------------------------------------------------------------------------
;;; Utilities
;;; ---------------------------------------------------------------------------

(defmacro with-channel-lock ((ch) &body body)
  `(bordeaux-threads:with-lock-held ((%ch-lock ,ch))
     ,@body))

(defun %notify (cv)
  "Notify one waiter on condition variable CV."
  (bordeaux-threads:condition-notify cv))

(defun %broadcast (cv n)
  "Notify up to N waiters on CV (workaround for lack of condition-broadcast)."
  (dotimes (_ n)
    (bordeaux-threads:condition-notify cv)))

(defun %wait (cv lock)
  "Release LOCK and wait for a notification on CV, then re-acquire LOCK."
  (bordeaux-threads:condition-wait cv lock))

;;; ---------------------------------------------------------------------------
;;; Buffer types
;;; ---------------------------------------------------------------------------

(defstruct (fixed-buf (:constructor make-fixed-buf (capacity)))
  "Fixed-size buffer: puts block when the buffer is at capacity."
  (data (make-array 0 :adjustable t :fill-pointer 0) :type (array t *))
  (capacity 1 :type fixnum :read-only t))

(defstruct (dropping-buf (:constructor make-dropping-buf (capacity)))
  "Dropping buffer: new items are silently discarded when the buffer is full.
   Puts always succeed immediately."
  (data (make-array 0 :adjustable t :fill-pointer 0) :type (array t *))
  (capacity 1 :type fixnum :read-only t))

(defstruct (sliding-buf (:constructor make-sliding-buf (capacity)))
  "Sliding buffer: the oldest item is discarded when the buffer is full.
   Puts always succeed immediately."
  (data (make-array 0 :adjustable t :fill-pointer 0) :type (array t *))
  (capacity 1 :type fixnum :read-only t))

;;; Public constructor functions that match Clojure's names.
(defun buffer (n)
  "Create a fixed buffer of size N. Puts block when full."
  (make-fixed-buf n))

(defun dropping-buffer (n)
  "Create a dropping buffer of size N. Puts never block; excess items are dropped."
  (make-dropping-buf n))

(defun sliding-buffer (n)
  "Create a sliding buffer of size N. Puts never block; the oldest item is evicted."
  (make-sliding-buf n))

;;; ---------------------------------------------------------------------------
;;; Internal buffer operations
;;; ---------------------------------------------------------------------------

(defun %buf-data (buf)
  (etypecase buf
    (fixed-buf   (fixed-buf-data buf))
    (dropping-buf (dropping-buf-data buf))
    (sliding-buf  (sliding-buf-data buf))))

(defun %buf-capacity (buf)
  (etypecase buf
    (fixed-buf   (fixed-buf-capacity buf))
    (dropping-buf (dropping-buf-capacity buf))
    (sliding-buf  (sliding-buf-capacity buf))))

(defun %buf-count (buf)
  (length (%buf-data buf)))

(defun %buf-empty-p (buf)
  (= 0 (%buf-count buf)))

(defun %buf-full-p (buf)
  "Only fixed buffers can be full from the putter's perspective."
  (and (fixed-buf-p buf)
       (>= (%buf-count buf) (fixed-buf-capacity buf))))

(defun %arr-dequeue (arr)
  "Remove and return the element at index 0 of adjustable fill-pointer array ARR."
  (let ((val (aref arr 0))
        (n   (length arr)))
    (loop for i from 0 below (1- n)
          do (setf (aref arr i) (aref arr (1+ i))))
    (decf (fill-pointer arr))
    val))

(defun %buf-add! (buf item)
  "Add ITEM to BUF according to its overflow policy. Always returns t."
  (let ((data (%buf-data buf))
        (cap  (%buf-capacity buf)))
    (etypecase buf
      (fixed-buf
        (vector-push-extend item data))
      (dropping-buf
        (when (< (length data) cap)
          (vector-push-extend item data)))
      (sliding-buf
        (when (>= (length data) cap)
          (%arr-dequeue data))
        (vector-push-extend item data))))
  t)

(defun %buf-take! (buf)
  "Remove and return the oldest item from BUF. BUF must be non-empty."
  (%arr-dequeue (%buf-data buf)))

;;; ---------------------------------------------------------------------------
;;; Transducer protocol
;;;
;;; A transducer XF is a one-argument function: (xf rf) -> step-fn.
;;; The step-fn has signature (result input) -> result.
;;; For channels, result is the channel struct (ignored) and input is the value.
;;; The base reducing function adds the item to the channel's buffer.
;;; ---------------------------------------------------------------------------

(defun %make-chan-rf (ch)
  "Return the base reducing function for channel CH's buffer."
  (lambda (result item)
    (declare (ignore result))
    (when (%ch-buf ch)
      (%buf-add! (%ch-buf ch) item))
    ch))

(defun %apply-xf-or-add (ch item)
  "Add ITEM to CH's buffer, passing through the transducer if present."
  (if (%ch-xf ch)
      (funcall (%ch-xf ch) ch item)
      (when (%ch-buf ch)
        (%buf-add! (%ch-buf ch) item))))

;;; ---------------------------------------------------------------------------
;;; Channel struct
;;; ---------------------------------------------------------------------------

(defstruct (channel (:constructor %make-channel) (:conc-name %ch-))
  "A CSP channel with optional buffer and transducer.

   PENDING-PUTS  — list of (value . done-cell) for puts awaiting a taker.
                   done-cell is a cons (nil . nil); cdr is set to t when resolved.
   PENDING-TAKES — list of result-cell for takes awaiting a putter.
                   result-cell is a cons (nil . nil); car = value, cdr = t when resolved."
  buf           ; nil (unbuffered) or a fixed-buf/dropping-buf/sliding-buf
  xf            ; compiled transducer step function, or nil
  (lock         (bordeaux-threads:make-lock "channel-lock"))
  (not-empty    (bordeaux-threads:make-condition-variable :name "channel-not-empty"))
  (not-full     (bordeaux-threads:make-condition-variable :name "channel-not-full"))
  (closed       nil :type boolean)
  (pending-puts  '()) ; (value . done-cell) — waiting putters
  (pending-takes '()) ; result-cell          — waiting takers
  ;; notification counter: incremented on each state change so alts polling
  ;; can detect activity without re-acquiring all locks.
  (generation   0 :type fixnum))

(defun %ch-generation-bump (ch)
  (incf (%ch-generation ch)))

;;; ---------------------------------------------------------------------------
;;; Public channel constructor
;;; ---------------------------------------------------------------------------

(defun chan (&optional buf-or-n xf ex-handler)
  "Create a new channel.

   BUF-OR-N — nil        : unbuffered (rendezvous) channel [default]
              integer N  : fixed buffer of size N
              buffer     : any buffer object (fixed, dropping, or sliding)
   XF        — a transducer applied to items as they enter the buffer.
               Only valid with a buffered channel.
   EX-HANDLER — a function (err) → value called when XF throws an error.
               The returned value (if non-nil) is put into the buffer instead."
  (let* ((buf (etypecase buf-or-n
                (null nil)
                (integer (make-fixed-buf buf-or-n))
                (fixed-buf   buf-or-n)
                (dropping-buf buf-or-n)
                (sliding-buf  buf-or-n)))
         (ch (%make-channel :buf buf))
         (base-rf (%make-chan-rf ch)))
    (when xf
      (let ((step (funcall xf base-rf)))
        (if ex-handler
            (setf (%ch-xf ch)
                  (lambda (result item)
                    (handler-case (funcall step result item)
                      (error (e)
                        (let ((v (funcall ex-handler e)))
                          (when v (funcall base-rf result v)))))))
            (setf (%ch-xf ch) step))))
    ch))

;;; ---------------------------------------------------------------------------
;;; close!
;;; ---------------------------------------------------------------------------

(defun %close-holding-lock! (ch)
  "Close CH assuming the channel lock is already held by the caller."
  (unless (%ch-closed ch)
    (setf (%ch-closed ch) t)
    (%ch-generation-bump ch)
    (%broadcast (%ch-not-empty ch) (length (%ch-pending-takes ch)))
    (%broadcast (%ch-not-full ch) (length (%ch-pending-puts ch)))))

(defun close! (ch)
  "Close CH. Pending takers receive nil. Pending putters are discarded.
   Returns nil."
  (with-channel-lock (ch) (%close-holding-lock! ch))
  nil)

(defun closed? (ch)
  "Return t if CH is closed."
  (with-channel-lock (ch) (%ch-closed ch)))

;;; ---------------------------------------------------------------------------
;;; >!! — blocking put
;;; ---------------------------------------------------------------------------

(defun >!! (ch value)
  "Put VALUE into CH, blocking if necessary until a taker is ready or the buffer
   has space. Returns true if the value was accepted, nil if CH is closed.
   Safe to call from any thread."
  (let ((lock (%ch-lock ch)))
    (bordeaux-threads:with-lock-held (lock)
      (block put
        (when (%ch-closed ch)
          (return-from put nil))
        (if (%ch-buf ch)
            ;;; --- Buffered channel ---
            (progn
              ;; If there are pending takers and the buffer has items,
              ;; a taker should already have woken. Just add to buffer.
              ;; Block only for fixed-buf when full.
              (loop while (%buf-full-p (%ch-buf ch))
                    do (when (%ch-closed ch) (return-from put nil))
                       ;; Check for direct rendezvous: hand value to a pending taker
                       (when (%ch-pending-takes ch)
                         (let* ((rcell (pop (%ch-pending-takes ch)))
                                (val   value))
                           (setf (car rcell) val
                                 (cdr rcell) t)
                           (%ch-generation-bump ch)
                           (%notify (%ch-not-empty ch))
                           (return-from put t)))
                       (%wait (%ch-not-full ch) lock))
              (when (%ch-closed ch) (return-from put nil))
              ;; Check for a pending taker first (direct pass-through)
              (cond
                ((%ch-pending-takes ch)
                 (let ((rcell (pop (%ch-pending-takes ch))))
                   (setf (car rcell) value (cdr rcell) t)
                   (%ch-generation-bump ch)
                   (%notify (%ch-not-empty ch))))
                (t
                 (%apply-xf-or-add ch value)
                 (%ch-generation-bump ch)
                 (%notify (%ch-not-empty ch))))
              t)
            ;;; --- Unbuffered (rendezvous) channel ---
            (progn
              ;; Direct handoff to a waiting taker if available
              (when (%ch-pending-takes ch)
                (let ((rcell (pop (%ch-pending-takes ch))))
                  (setf (car rcell) value (cdr rcell) t)
                  (%ch-generation-bump ch)
                  (%notify (%ch-not-empty ch))
                  (return-from put t)))
              ;; No taker yet — register as a pending put and block
              (let ((done-cell (cons nil nil)))
                (setf (%ch-pending-puts ch)
                      (nconc (%ch-pending-puts ch) (list (cons value done-cell))))
                (loop until (or (cdr done-cell) (%ch-closed ch))
                      do (%wait (%ch-not-full ch) lock))
                (if (%ch-closed ch) nil t))))))))

(setf (fdefinition '>!) #'>!!)

;;; ---------------------------------------------------------------------------
;;; <!! — blocking take
;;; ---------------------------------------------------------------------------

(defun <!! (ch)
  "Take a value from CH, blocking until one is available or CH is closed.
   Returns the value, or nil if CH is closed and empty.
   Safe to call from any thread."
  (let ((lock (%ch-lock ch)))
    (bordeaux-threads:with-lock-held (lock)
      (block take
        (loop
          ;;; --- Try to get a value ---
          ;; 1. Drain from buffer first
          (when (and (%ch-buf ch) (not (%buf-empty-p (%ch-buf ch))))
            (let ((val (%buf-take! (%ch-buf ch))))
              ;; If there are pending puts waiting for space, admit one
              (when (%ch-pending-puts ch)
                (let* ((ppair    (pop (%ch-pending-puts ch)))
                       (pval     (car ppair))
                       (done-cel (cdr ppair)))
                  (%apply-xf-or-add ch pval)
                  (setf (cdr done-cel) t)
                  (%ch-generation-bump ch)
                  (%notify (%ch-not-full ch))))
              (%ch-generation-bump ch)
              (%notify (%ch-not-full ch))
              (return-from take val)))
          ;; 2. Direct handoff from a pending put (unbuffered or no-buffer path)
          (when (%ch-pending-puts ch)
            (let* ((ppair    (pop (%ch-pending-puts ch)))
                   (pval     (car ppair))
                   (done-cel (cdr ppair)))
              (setf (cdr done-cel) t)
              (%ch-generation-bump ch)
              (%notify (%ch-not-full ch))
              (return-from take pval)))
          ;; 3. Channel closed and empty
          (when (%ch-closed ch)
            (return-from take nil))
          ;; 4. Nothing available — register as a pending take and block
          (let ((rcell (cons nil nil)))
            (setf (%ch-pending-takes ch)
                  (nconc (%ch-pending-takes ch) (list rcell)))
            (%wait (%ch-not-empty ch) lock)
            ;; After waking, check if our cell was resolved
            (when (cdr rcell)
              (return-from take (car rcell)))))))))

(setf (fdefinition '<!) #'<!!)

;;; ---------------------------------------------------------------------------
;;; offer! — non-blocking put
;;; ---------------------------------------------------------------------------

(defun offer! (ch value)
  "Attempt to put VALUE into CH without blocking.
   Returns t if the value was accepted, nil otherwise."
  (with-channel-lock (ch)
    (when (%ch-closed ch) (return-from offer! nil))
    (cond
      ;; Pending taker waiting — direct handoff
      ((%ch-pending-takes ch)
       (let ((rcell (pop (%ch-pending-takes ch))))
         (setf (car rcell) value (cdr rcell) t)
         (%ch-generation-bump ch)
         (%notify (%ch-not-empty ch))
         t))
      ;; Buffered and has room
      ((and (%ch-buf ch) (not (%buf-full-p (%ch-buf ch))))
       (%apply-xf-or-add ch value)
       (%ch-generation-bump ch)
       (%notify (%ch-not-empty ch))
       t)
      ;; Dropping/sliding buffers never block, so always succeed here too
      ((and (%ch-buf ch) (not (fixed-buf-p (%ch-buf ch))))
       (%apply-xf-or-add ch value)
       (%ch-generation-bump ch)
       (%notify (%ch-not-empty ch))
       t)
      ;; Unbuffered with no taker, or fixed-buf full
      (t nil))))

;;; ---------------------------------------------------------------------------
;;; poll! — non-blocking take
;;; ---------------------------------------------------------------------------

(defun poll! (ch)
  "Attempt to take a value from CH without blocking.
   Returns (values value t) if a value was available, or (values nil nil) if not."
  (with-channel-lock (ch)
    (cond
      ;; Buffer has items
      ((and (%ch-buf ch) (not (%buf-empty-p (%ch-buf ch))))
       (let ((val (%buf-take! (%ch-buf ch))))
         (when (%ch-pending-puts ch)
           (let* ((ppair    (pop (%ch-pending-puts ch)))
                  (pval     (car ppair))
                  (done-cel (cdr ppair)))
             (%apply-xf-or-add ch pval)
             (setf (cdr done-cel) t)
             (%ch-generation-bump ch)
             (%notify (%ch-not-full ch))))
         (%ch-generation-bump ch)
         (values val t)))
      ;; Pending put on an unbuffered channel
      ((%ch-pending-puts ch)
       (let* ((ppair    (pop (%ch-pending-puts ch)))
              (pval     (car ppair))
              (done-cel (cdr ppair)))
         (setf (cdr done-cel) t)
         (%ch-generation-bump ch)
         (%notify (%ch-not-full ch))
         (values pval t)))
      ;; Nothing available
      (t (values nil nil)))))

;;; ---------------------------------------------------------------------------
;;; go, go-loop, thread
;;; ---------------------------------------------------------------------------

(defmacro go (&body body)
  "Execute BODY in a new OS thread. Returns a channel that delivers the result
   of the last form in BODY (or nil if BODY returns nil).
   The result channel is closed after the value is delivered.

   Unlike Clojure's go, FOL's go blocks are real threads, not green threads."
  (let ((result-ch (gensym "GO-CH-"))
        (result    (gensym "GO-RESULT-")))
    `(let ((,result-ch (chan 1)))
       (bordeaux-threads:make-thread
        (lambda ()
          (let ((,result (progn ,@body)))
            (>!! ,result-ch ,result)
            (close! ,result-ch)))
        :name "fol-go-block")
       ,result-ch)))

(defmacro go-loop (bindings &body body)
  "Start a go block containing a named loop.  BINDINGS are initial values for
   the loop variables.  Use (recur new-val ...) to jump back to the top.

   Implemented as (go (loop [...] body...)) using a labels-based loop."
  (let ((loop-name (gensym "LOOP-"))
        (vars  (loop for (v _) on bindings by #'cddr collect v))
        (inits (loop for (_ i) on bindings by #'cddr collect i)))
    `(go
       (labels ((,loop-name ,vars ,@body))
         (,loop-name ,@inits)))))

(defmacro recur (&rest new-vals)
  "Tail-recursive jump inside go-loop.  Must be in tail position of go-loop body."
  ;; This relies on the loop-name gensym from go-loop. For proper use, this
  ;; macro must be lexically inside a go-loop expansion.
  (error "recur used outside of go-loop"))

(defun thread-call (f)
  "Run (funcall F) in a new thread; return a channel that delivers its result."
  (let ((ch (chan 1)))
    (bordeaux-threads:make-thread
     (lambda ()
       (let ((result (funcall f)))
         (>!! ch result)
         (close! ch)))
     :name "fol-thread")
    ch))

(defmacro thread (&body body)
  "Run BODY in a new OS thread (not a go-block thread pool).
   Returns a channel that delivers the result."
  `(thread-call (lambda () ,@body)))

;;; ---------------------------------------------------------------------------
;;; alts!! / alts!
;;;
;;; Each op in OPS is either:
;;;   channel           → take operation on that channel
;;;   (channel value)   → put operation; value may be :close to close the channel
;;;
;;; Returns (values result channel) where:
;;;   result  = value taken, or true/nil for puts, or :default if :default given
;;;   channel = the channel that fired, or nil for :default
;;; ---------------------------------------------------------------------------

(defun %alts-try-once (ops priority)
  "Try all ops non-blockingly once. Return (values result ch) or nil."
  (let ((order (if priority ops (%shuffle (copy-list ops)))))
    (dolist (op order)
      (cond
        ;; Put op: (channel value)
        ((and (consp op) (not (null (cdr op))))
         (let ((ch (car op))
               (v  (cadr op)))
           (when (offer! ch v)
             (return-from %alts-try-once (values v ch)))))
        ;; Take op: bare channel
        (t
         (let ((ch (if (consp op) (car op) op)))
           (multiple-value-bind (val ok) (poll! ch)
             (when ok
               (return-from %alts-try-once (values val ch))))))))))

(defun %shuffle (lst)
  "Return a shallow copy of LST with elements in random order."
  (let ((vec (coerce lst 'vector)))
    (loop for i from (1- (length vec)) downto 1
          do (let* ((j  (random (1+ i)))
                    (tmp (aref vec i)))
               (setf (aref vec i) (aref vec j)
                     (aref vec j) tmp)))
    (coerce vec 'list)))

(defun alts!! (ops &key priority default)
  "Block until one operation in OPS is ready, then perform it.
   OPS is a list of channels (take) or (channel value) pairs (put).

   :priority t — try ops in order rather than random order.
   :default  v — if no op is immediately ready, return (values v nil) immediately.

   Returns (values result channel)."
  ;; Try non-blocking first
  (multiple-value-bind (result ch) (%alts-try-once ops priority)
    (when ch (return-from alts!! (values result ch))))
  ;; Default fallback
  (when default
    (return-from alts!! (values default nil)))
  ;; Polling loop with exponential backoff
  (loop for sleep-ms = 0 then (min (* sleep-ms 2) 8)
        do (when (> sleep-ms 0) (sleep (/ sleep-ms 1000.0d0)))
           (multiple-value-bind (result ch) (%alts-try-once ops priority)
             (when ch (return-from alts!! (values result ch))))))

(setf (fdefinition 'alts!) #'alts!!)

;;; ---------------------------------------------------------------------------
;;; timeout
;;; ---------------------------------------------------------------------------

(defun timeout (ms)
  "Return a channel that will close after MS milliseconds.
   Taking from a timeout channel blocks until it closes, then returns nil."
  (let ((ch (chan)))
    (bordeaux-threads:make-thread
     (lambda ()
       (sleep (/ ms 1000.0d0))
       (close! ch))
     :name "fol-timeout")
    ch))

;;; ---------------------------------------------------------------------------
;;; onto-chan!! / onto-chan
;;; ---------------------------------------------------------------------------

(defun onto-chan!! (ch coll &optional (close-p t))
  "Put each element of COLL into CH, blocking between puts.
   Closes CH when done if CLOSE-P is true (default).
   Returns CH."
  (dolist (item coll)
    (unless (>!! ch item)
      (return)))
  (when close-p (close! ch))
  ch)

(defun onto-chan (ch coll &optional (close-p t))
  "Asynchronously put each element of COLL into CH in a go block.
   Closes CH when done if CLOSE-P is true (default).
   Returns a channel that closes when all items have been put."
  (go (onto-chan!! ch coll close-p)))

;;; ---------------------------------------------------------------------------
;;; to-chan!! / to-chan
;;; ---------------------------------------------------------------------------

(defun to-chan!! (coll)
  "Return a channel loaded with all elements of COLL; channel is then closed.
   Blocks the calling thread while loading."
  (let ((ch (chan (length coll))))
    (onto-chan!! ch coll t)
    ch))

(defun to-chan (coll)
  "Return a channel that will receive all elements of COLL asynchronously.
   The channel is closed after the last element is delivered."
  (let ((ch (chan (length coll))))
    (onto-chan ch coll t)
    ch))

;;; ---------------------------------------------------------------------------
;;; pipe
;;; ---------------------------------------------------------------------------

(defun pipe (from to &optional (close-p t))
  "Take all values from FROM and put them into TO.
   Closes TO when FROM closes if CLOSE-P is true (default).
   Runs in a dedicated go block; returns TO."
  (go
    (loop
      (let ((val (<!! from)))
        (if (null val)
            (progn (when close-p (close! to)) (return))
            (unless (>!! to val) (return))))))
  to)

;;; ---------------------------------------------------------------------------
;;; pipeline
;;; ---------------------------------------------------------------------------

(defun pipeline (n to xf from &optional (close-p t) ex-handler)
  "Apply transducer XF to values from FROM and put results into TO,
   using up to N parallel go blocks.

   N         — degree of parallelism
   TO        — output channel
   XF        — transducer (e.g. (map f), (filter p))
   FROM      — input channel
   CLOSE-P   — close TO when FROM is exhausted (default t)
   EX-HANDLER — (err) → value called on transducer errors; non-nil value is put to TO

   Returns TO."
  (let* ((jobs (chan n))        ; input jobs channel
         (results (chan n)))    ; ordered output channel
    ;; Fan-out: one goroutine per worker
    (dotimes (_ n)
      (go
        (loop
          (let ((job (<!! jobs)))
            (when (null job) (return))
            (let* ((in-ch  (car job))
                   (out-ch (cdr job))
                   (val    (<!! in-ch)))
              (when val
                (let ((xf-ch (chan 1 xf ex-handler)))
                  (>!! xf-ch val)
                  (close! xf-ch)
                  (let ((res (poll! xf-ch)))
                    (>!! out-ch res))))
              (close! out-ch))))))
    ;; Sequencer: read results in submission order and put to TO
    (go
      (loop
        (let ((result-ch (<!! results)))
          (when (null result-ch) (return))
          (let ((val (<!! result-ch)))
            (when val (>!! to val)))))
      (when close-p (close! to)))
    ;; Dispatcher: read from FROM and dispatch to workers
    (go
      (loop
        (let ((val (<!! from)))
          (if (null val)
              (progn (close! jobs) (close! results) (return))
              (let ((in-ch  (chan 1))
                    (out-ch (chan 1)))
                (>!! in-ch val)
                (close! in-ch)
                (>!! jobs (cons in-ch out-ch))
                (>!! results out-ch))))))
    to))

(defun pipeline-async (n to af from &optional (close-p t))
  "Like pipeline but each item is processed by calling (AF value result-ch).
   AF should put its result(s) into result-ch and then close it.
   N parallel go blocks run AF concurrently.
   Returns TO."
  (let ((jobs    (chan n))
        (results (chan n)))
    (dotimes (_ n)
      (go
        (loop
          (let ((job (<!! jobs)))
            (when (null job) (return))
            (funcall af (car job) (cdr job))))))
    (go
      (loop
        (let ((result-ch (<!! results)))
          (when (null result-ch) (return))
          (loop
            (let ((val (<!! result-ch)))
              (when (null val) (return))
              (>!! to val)))))
      (when close-p (close! to)))
    (go
      (loop
        (let ((val (<!! from)))
          (if (null val)
              (progn (close! jobs) (close! results) (return))
              (let ((out-ch (chan 1)))
                (>!! jobs (cons val out-ch))
                (>!! results out-ch))))))
    to))

;;; ---------------------------------------------------------------------------
;;; merge
;;; ---------------------------------------------------------------------------

(defun merge (chs &optional (buf-or-n 0))
  "Merge a list of source channels CHS into a single output channel.
   All values from every source channel are put to the output channel.
   The output channel closes when all source channels are closed.
   BUF-OR-N controls the output channel's buffer size (default 0, unbuffered).
   Returns the output channel."
  (let ((out   (chan buf-or-n))
        (count (length chs)))
    (dolist (ch chs)
      (go
        (loop
          (let ((val (<!! ch)))
            (if (null val)
                (progn
                  (bordeaux-threads:with-lock-held ((%ch-lock out))
                    (decf count)
                    (when (= count 0) (%close-holding-lock! out)))
                  (return))
                (unless (>!! out val) (return)))))))
    out))

;;; ---------------------------------------------------------------------------
;;; Pub/Sub
;;; ---------------------------------------------------------------------------

(defstruct (publication (:constructor %make-pub) (:conc-name %pub-))
  "A publication multiplexes a source channel to topic-keyed subscriber channels."
  src-ch        ; the source channel
  topic-fn      ; (value) -> topic key
  (lock (bordeaux-threads:make-lock "pub-lock"))
  (subs (make-hash-table :test 'equal))) ; topic -> list of subscriber channels

(defun pub (ch topic-fn &optional buf-fn)
  "Create a publication from source channel CH.
   TOPIC-FN maps each value to a topic key (any object comparable with EQUAL).
   BUF-FN (optional) maps each topic key to a buffer size for subscriber channels.
   Returns a publication object."
  (declare (ignore buf-fn)) ; simplified: all sub channels use caller-supplied buffers
  (let ((p (%make-pub :src-ch ch :topic-fn topic-fn)))
    ;; Dispatch loop in a background thread
    (bordeaux-threads:make-thread
     (lambda ()
       (loop
         (let ((val (<!! ch)))
           (if (null val)
               ;; Source closed: close all subscriber channels
               (progn
                 (bordeaux-threads:with-lock-held ((%pub-lock p))
                   (maphash (lambda (_topic sub-chs)
                              (declare (ignore _topic))
                              (dolist (sub-ch sub-chs) (close! sub-ch)))
                            (%pub-subs p)))
                 (return))
               ;; Route to matching subscribers
               (let ((topic (funcall (%pub-topic-fn p) val)))
                 (bordeaux-threads:with-lock-held ((%pub-lock p))
                   (dolist (sub-ch (gethash topic (%pub-subs p) '()))
                     (>!! sub-ch val))))))))
     :name "fol-pub-dispatch")
    p))

(defun sub (p topic ch)
  "Subscribe channel CH to TOPIC on publication P.
   Values matching TOPIC from P's source are put into CH.
   Returns CH."
  (bordeaux-threads:with-lock-held ((%pub-lock p))
    (pushnew ch (gethash topic (%pub-subs p) '())))
  ch)

(defun unsub (p topic ch)
  "Unsubscribe CH from TOPIC on publication P. Returns nil."
  (bordeaux-threads:with-lock-held ((%pub-lock p))
    (setf (gethash topic (%pub-subs p))
          (remove ch (gethash topic (%pub-subs p) '()))))
  nil)

(defun unsub-all (p &optional topic)
  "Unsubscribe all channels from TOPIC on P, or from all topics if TOPIC is nil.
   Returns nil."
  (bordeaux-threads:with-lock-held ((%pub-lock p))
    (if topic
        (remhash topic (%pub-subs p))
        (clrhash (%pub-subs p))))
  nil)
