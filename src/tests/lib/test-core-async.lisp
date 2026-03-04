;;; FOL core.async Tests
;;;
;;; Tests for the CSP channel library in fol.lib.core-async.
;;; All tests are synchronous-safe: blocking operations use real threads
;;; with a timeout guard so the test suite can never hang indefinitely.

(in-package :fol.compiler.tests.lib)
(in-suite core-async-tests)

;;; ---------------------------------------------------------------------------
;;; Test helpers
;;; ---------------------------------------------------------------------------

(defmacro with-timeout ((ms) &body body)
  "Execute BODY in the current thread with a watchdog that signals an error
   if BODY takes longer than MS milliseconds.  Assertions in BODY run in the
   current thread, so FiveAM's test context is automatically available."
  (let ((done-var  (gensym "DONE-"))
        (lock-var  (gensym "LOCK-"))
        (main-var  (gensym "MAIN-")))
    `(let ((,done-var nil)
           (,lock-var (bordeaux-threads:make-lock "with-timeout-lock"))
           (,main-var (bordeaux-threads:current-thread)))
       ;; Watchdog fires if the main thread hasn't finished in time.
       (bordeaux-threads:make-thread
        (lambda ()
          (sleep (/ ,ms 1000.0))
          (bordeaux-threads:with-lock-held (,lock-var)
            (unless ,done-var
              (ignore-errors
               (bordeaux-threads:interrupt-thread
                ,main-var
                (lambda () (error "with-timeout: exceeded ~A ms" ,ms)))))))
        :name "test-timeout-watchdog")
       (unwind-protect
           (progn ,@body)
         (bordeaux-threads:with-lock-held (,lock-var)
           (setf ,done-var t))))))

;;; Short alias for package
(defun ca-chan (&rest args) (apply #'fol.lib.core-async:chan args))
(defun ca->!! (ch v) (fol.lib.core-async:>!! ch v))
(defun ca-<!! (ch) (fol.lib.core-async:<!! ch))

;;; ---------------------------------------------------------------------------
;;; Buffer construction
;;; ---------------------------------------------------------------------------

(test buffer-fixed-creation
  "buffer creates a fixed-buf of the given capacity."
  (let ((b (fol.lib.core-async:buffer 4)))
    (is (fol.lib.core-async::fixed-buf-p b))
    (is (= 4 (fol.lib.core-async::fixed-buf-capacity b)))))

(test buffer-dropping-creation
  "dropping-buffer creates a dropping-buf of the given capacity."
  (let ((b (fol.lib.core-async:dropping-buffer 4)))
    (is (fol.lib.core-async::dropping-buf-p b))
    (is (= 4 (fol.lib.core-async::dropping-buf-capacity b)))))

(test buffer-sliding-creation
  "sliding-buffer creates a sliding-buf of the given capacity."
  (let ((b (fol.lib.core-async:sliding-buffer 4)))
    (is (fol.lib.core-async::sliding-buf-p b))
    (is (= 4 (fol.lib.core-async::sliding-buf-capacity b)))))

;;; ---------------------------------------------------------------------------
;;; Channel construction
;;; ---------------------------------------------------------------------------

(test chan-unbuffered
  "chan with no arguments creates an unbuffered channel."
  (let ((ch (fol.lib.core-async:chan)))
    (is (fol.lib.core-async::channel-p ch))
    (is (null (fol.lib.core-async::%ch-buf ch)))))

(test chan-buffered-integer
  "chan with an integer creates a fixed-buffered channel."
  (let ((ch (fol.lib.core-async:chan 3)))
    (is (fol.lib.core-async::channel-p ch))
    (is (fol.lib.core-async::fixed-buf-p (fol.lib.core-async::%ch-buf ch)))
    (is (= 3 (fol.lib.core-async::fixed-buf-capacity
              (fol.lib.core-async::%ch-buf ch))))))

(test chan-buffered-fixed-buf
  "chan accepts a pre-made fixed-buf."
  (let* ((buf (fol.lib.core-async:buffer 5))
         (ch  (fol.lib.core-async:chan buf)))
    (is (eq buf (fol.lib.core-async::%ch-buf ch)))))

(test chan-buffered-dropping
  "chan accepts a dropping-buffer."
  (let* ((buf (fol.lib.core-async:dropping-buffer 2))
         (ch  (fol.lib.core-async:chan buf)))
    (is (fol.lib.core-async::dropping-buf-p (fol.lib.core-async::%ch-buf ch)))))

(test chan-buffered-sliding
  "chan accepts a sliding-buffer."
  (let* ((buf (fol.lib.core-async:sliding-buffer 2))
         (ch  (fol.lib.core-async:chan buf)))
    (is (fol.lib.core-async::sliding-buf-p (fol.lib.core-async::%ch-buf ch)))))

;;; ---------------------------------------------------------------------------
;;; close! and closed?
;;; ---------------------------------------------------------------------------

(test close-open-channel
  "A newly created channel is not closed."
  (let ((ch (fol.lib.core-async:chan 1)))
    (is (eq nil (fol.lib.core-async:closed? ch)))))

(test close-closes-channel
  "close! marks the channel as closed."
  (let ((ch (fol.lib.core-async:chan 1)))
    (fol.lib.core-async:close! ch)
    (is (eq t (fol.lib.core-async:closed? ch)))))

(test close-idempotent
  "Calling close! multiple times is safe."
  (let ((ch (fol.lib.core-async:chan 1)))
    (fol.lib.core-async:close! ch)
    (fol.lib.core-async:close! ch)
    (is (eq t (fol.lib.core-async:closed? ch)))))

(test close-returns-nil
  "close! returns nil."
  (let ((ch (fol.lib.core-async:chan 1)))
    (is (eq nil (fol.lib.core-async:close! ch)))))

;;; ---------------------------------------------------------------------------
;;; offer! and poll! — non-blocking operations
;;; ---------------------------------------------------------------------------

(test offer-succeeds-with-buffer-space
  "offer! returns t when the buffered channel has room."
  (let ((ch (fol.lib.core-async:chan 2)))
    (is (eq t (fol.lib.core-async:offer! ch :x)))))

(test offer-fails-when-buffer-full
  "offer! returns nil when a fixed-buffer is full and there are no takers."
  (let ((ch (fol.lib.core-async:chan 1)))
    (fol.lib.core-async:offer! ch :first)
    (is (eq nil (fol.lib.core-async:offer! ch :second)))))

(test offer-fails-on-closed-channel
  "offer! returns nil on a closed channel."
  (let ((ch (fol.lib.core-async:chan 2)))
    (fol.lib.core-async:close! ch)
    (is (eq nil (fol.lib.core-async:offer! ch :x)))))

(test poll-returns-value-and-true
  "poll! returns (values val t) when an item is available."
  (let ((ch (fol.lib.core-async:chan 1)))
    (fol.lib.core-async:offer! ch 42)
    (multiple-value-bind (val ok) (fol.lib.core-async:poll! ch)
      (is (= 42 val))
      (is (eq t ok)))))

(test poll-returns-nil-nil-when-empty
  "poll! returns (values nil nil) when the channel is empty."
  (let ((ch (fol.lib.core-async:chan 1)))
    (multiple-value-bind (val ok) (fol.lib.core-async:poll! ch)
      (is (eq nil val))
      (is (eq nil ok)))))

(test offer-poll-roundtrip
  "Values put via offer! can be retrieved via poll! in FIFO order."
  (let ((ch (fol.lib.core-async:chan 3)))
    (fol.lib.core-async:offer! ch 10)
    (fol.lib.core-async:offer! ch 20)
    (fol.lib.core-async:offer! ch 30)
    (is (= 10 (nth-value 0 (fol.lib.core-async:poll! ch))))
    (is (= 20 (nth-value 0 (fol.lib.core-async:poll! ch))))
    (is (= 30 (nth-value 0 (fol.lib.core-async:poll! ch))))))

;;; ---------------------------------------------------------------------------
;;; Dropping buffer semantics
;;; ---------------------------------------------------------------------------

(test dropping-buffer-drops-excess
  "A dropping buffer silently discards items when full."
  (let* ((buf (fol.lib.core-async:dropping-buffer 2))
         (ch  (fol.lib.core-async:chan buf)))
    (fol.lib.core-async:offer! ch :a)
    (fol.lib.core-async:offer! ch :b)
    (fol.lib.core-async:offer! ch :c) ; dropped
    (is (eq :a (nth-value 0 (fol.lib.core-async:poll! ch))))
    (is (eq :b (nth-value 0 (fol.lib.core-async:poll! ch))))
    (multiple-value-bind (val ok) (fol.lib.core-async:poll! ch)
      (is (eq nil val))
      (is (eq nil ok)))))

;;; ---------------------------------------------------------------------------
;;; Sliding buffer semantics
;;; ---------------------------------------------------------------------------

(test sliding-buffer-evicts-oldest
  "A sliding buffer evicts the oldest item when full."
  (let* ((buf (fol.lib.core-async:sliding-buffer 2))
         (ch  (fol.lib.core-async:chan buf)))
    (fol.lib.core-async:offer! ch :a)
    (fol.lib.core-async:offer! ch :b)
    (fol.lib.core-async:offer! ch :c) ; evicts :a
    (is (eq :b (nth-value 0 (fol.lib.core-async:poll! ch))))
    (is (eq :c (nth-value 0 (fol.lib.core-async:poll! ch))))))

;;; ---------------------------------------------------------------------------
;;; >!! and <!! — blocking put/take
;;; ---------------------------------------------------------------------------

(test blocking-put-take-buffered
  "A value put into a buffered channel can be taken back."
  (with-timeout (2000)
    (let ((ch (fol.lib.core-async:chan 1)))
      (fol.lib.core-async:>!! ch :hello)
      (is (eq :hello (fol.lib.core-async:<!! ch))))))

(test blocking-put-take-multiple
  "Multiple values are received in FIFO order."
  (with-timeout (2000)
    (let ((ch (fol.lib.core-async:chan 3)))
      (fol.lib.core-async:>!! ch 1)
      (fol.lib.core-async:>!! ch 2)
      (fol.lib.core-async:>!! ch 3)
      (is (= 1 (fol.lib.core-async:<!! ch)))
      (is (= 2 (fol.lib.core-async:<!! ch)))
      (is (= 3 (fol.lib.core-async:<!! ch))))))

(test blocking-take-on-closed-empty-channel
  "<!! on a closed empty channel returns nil."
  (with-timeout (2000)
    (let ((ch (fol.lib.core-async:chan 1)))
      (fol.lib.core-async:close! ch)
      (is (eq nil (fol.lib.core-async:<!! ch))))))

(test blocking-put-returns-nil-on-closed
  ">!! on a closed channel returns nil."
  (with-timeout (2000)
    (let ((ch (fol.lib.core-async:chan 1)))
      (fol.lib.core-async:close! ch)
      (is (eq nil (fol.lib.core-async:>!! ch :x))))))

(test blocking-put-take-across-threads
  "put in one thread, take in another — rendezvous via unbuffered channel."
  (with-timeout (3000)
    (let ((ch (fol.lib.core-async:chan)))
      (bordeaux-threads:make-thread
       (lambda () (fol.lib.core-async:>!! ch 99))
       :name "test-putter")
      (is (= 99 (fol.lib.core-async:<!! ch))))))

;;; ---------------------------------------------------------------------------
;;; go — lightweight blocks
;;; ---------------------------------------------------------------------------

(test go-returns-result-channel
  "go returns a channel that delivers the block's result."
  (with-timeout (3000)
    (let* ((result-ch (fol.lib.core-async:go (+ 1 2))))
      (is (= 3 (fol.lib.core-async:<!! result-ch))))))

(test go-result-channel-closed-after-delivery
  "The result channel from go is closed after delivering the value."
  (with-timeout (3000)
    (let ((result-ch (fol.lib.core-async:go :done)))
      (fol.lib.core-async:<!! result-ch)
      ;; Give the close a moment to propagate
      (sleep 0.05)
      (is (eq t (fol.lib.core-async:closed? result-ch))))))

(test go-communicates-via-channel
  "A go block can put values into a shared channel."
  (with-timeout (3000)
    (let ((ch (fol.lib.core-async:chan 1)))
      (fol.lib.core-async:go (fol.lib.core-async:>!! ch :from-go))
      (is (eq :from-go (fol.lib.core-async:<!! ch))))))

;;; ---------------------------------------------------------------------------
;;; timeout
;;; ---------------------------------------------------------------------------

(test timeout-channel-closes
  "A timeout channel closes after the specified delay."
  (with-timeout (3000)
    (let ((t-ch (fol.lib.core-async:timeout 50)))
      ;; Taking from the channel blocks until it closes, returning nil
      (is (eq nil (fol.lib.core-async:<!! t-ch))))))

(test timeout-channel-is-not-initially-closed
  "A fresh timeout channel is not yet closed."
  ;; Use a long timeout so we can observe the initial state
  (let ((t-ch (fol.lib.core-async:timeout 10000)))
    (is (eq nil (fol.lib.core-async:closed? t-ch)))
    ;; Clean up: close manually so the thread terminates
    (fol.lib.core-async:close! t-ch)))

;;; ---------------------------------------------------------------------------
;;; to-chan!! / onto-chan!!
;;; ---------------------------------------------------------------------------

(test to-chan-delivers-all-elements
  "to-chan!! returns a channel containing all elements of a list."
  (with-timeout (2000)
    (let* ((ch (fol.lib.core-async:to-chan!! '(10 20 30))))
      (is (= 10 (fol.lib.core-async:<!! ch)))
      (is (= 20 (fol.lib.core-async:<!! ch)))
      (is (= 30 (fol.lib.core-async:<!! ch)))
      ;; channel should be closed
      (is (eq nil (fol.lib.core-async:<!! ch))))))

(test onto-chan-fills-channel
  "onto-chan!! fills an existing channel with collection items."
  (with-timeout (2000)
    (let ((ch (fol.lib.core-async:chan 3)))
      (fol.lib.core-async:onto-chan!! ch '(:a :b :c))
      (is (eq :a (fol.lib.core-async:<!! ch)))
      (is (eq :b (fol.lib.core-async:<!! ch)))
      (is (eq :c (fol.lib.core-async:<!! ch))))))

(test onto-chan-closes-by-default
  "onto-chan!! closes the channel after putting all items."
  (with-timeout (2000)
    (let ((ch (fol.lib.core-async:chan 2)))
      (fol.lib.core-async:onto-chan!! ch '(1 2))
      (fol.lib.core-async:<!! ch)
      (fol.lib.core-async:<!! ch)
      (is (eq t (fol.lib.core-async:closed? ch))))))

(test onto-chan-no-close
  "onto-chan!! with close-p nil leaves the channel open."
  (with-timeout (2000)
    (let ((ch (fol.lib.core-async:chan 2)))
      (fol.lib.core-async:onto-chan!! ch '(1 2) nil)
      (fol.lib.core-async:<!! ch)
      (fol.lib.core-async:<!! ch)
      (is (eq nil (fol.lib.core-async:closed? ch)))
      ;; Clean up
      (fol.lib.core-async:close! ch))))

;;; ---------------------------------------------------------------------------
;;; pipe
;;; ---------------------------------------------------------------------------

(test pipe-transfers-values
  "pipe forwards all values from one channel to another."
  (with-timeout (3000)
    (let ((from (fol.lib.core-async:to-chan!! '(1 2 3)))
          (to   (fol.lib.core-async:chan 3)))
      (fol.lib.core-async:pipe from to)
      (is (= 1 (fol.lib.core-async:<!! to)))
      (is (= 2 (fol.lib.core-async:<!! to)))
      (is (= 3 (fol.lib.core-async:<!! to))))))

(test pipe-closes-destination
  "pipe closes the destination channel when source closes."
  (with-timeout (3000)
    (let ((from (fol.lib.core-async:to-chan!! '(1)))
          (to   (fol.lib.core-async:chan 1)))
      (fol.lib.core-async:pipe from to)
      (fol.lib.core-async:<!! to)
      ;; Drain nil (channel closed)
      (fol.lib.core-async:<!! to)
      (sleep 0.1) ; allow pipe go block to close to
      (is (eq t (fol.lib.core-async:closed? to))))))

;;; ---------------------------------------------------------------------------
;;; merge
;;; ---------------------------------------------------------------------------

(test merge-combines-channels
  "merge collects values from multiple channels into one."
  (with-timeout (3000)
    (let* ((c1  (fol.lib.core-async:to-chan!! '(1 2)))
           (c2  (fol.lib.core-async:to-chan!! '(3 4)))
           (out (fol.lib.core-async:merge (list c1 c2) 4))
           (results '()))
      ;; Collect 4 values
      (dotimes (_ 4)
        (let ((v (fol.lib.core-async:<!! out)))
          (when v (push v results))))
      (is (= 4 (length results)))
      (is (null (set-difference results '(1 2 3 4)))))))

(test merge-closes-output-when-all-closed
  "The merged output channel closes when all sources are exhausted."
  (with-timeout (3000)
    (let* ((c1  (fol.lib.core-async:to-chan!! '(:x)))
           (out (fol.lib.core-async:merge (list c1) 1)))
      (fol.lib.core-async:<!! out) ; :x
      (is (eq nil (fol.lib.core-async:<!! out))) ; nil → closed
      (sleep 0.05)
      (is (eq t (fol.lib.core-async:closed? out))))))

;;; ---------------------------------------------------------------------------
;;; Pub/sub
;;; ---------------------------------------------------------------------------

(test pub-sub-basic-routing
  "pub routes values to subscribers by topic."
  (with-timeout (3000)
    (let* ((src     (fol.lib.core-async:chan 4))
           (p       (fol.lib.core-async:pub src #'identity))
           (evens   (fol.lib.core-async:chan 4))
           (odds    (fol.lib.core-async:chan 4)))
      (fol.lib.core-async:sub p :even evens)
      (fol.lib.core-async:sub p :odd  odds)
      ;; Push tagged values
      (fol.lib.core-async:>!! src :even)
      (fol.lib.core-async:>!! src :odd)
      (fol.lib.core-async:>!! src :even)
      (sleep 0.1) ; let pub dispatch thread process
      (is (eq :even (nth-value 0 (fol.lib.core-async:poll! evens))))
      (is (eq :even (nth-value 0 (fol.lib.core-async:poll! evens))))
      (is (eq :odd  (nth-value 0 (fol.lib.core-async:poll! odds))))
      (fol.lib.core-async:close! src))))

(test pub-unsub-stops-delivery
  "unsub removes a subscriber; subsequent messages are not delivered."
  (with-timeout (3000)
    (let* ((src (fol.lib.core-async:chan 4))
           (p   (fol.lib.core-async:pub src #'identity))
           (sub-ch (fol.lib.core-async:chan 4)))
      (fol.lib.core-async:sub   p :topic sub-ch)
      (fol.lib.core-async:unsub p :topic sub-ch)
      (fol.lib.core-async:>!! src :topic)
      (sleep 0.1)
      (multiple-value-bind (val ok) (fol.lib.core-async:poll! sub-ch)
        (is (eq nil val))
        (is (eq nil ok)))
      (fol.lib.core-async:close! src))))

(test pub-unsub-all-clears-topic
  "unsub-all with a topic removes all subscribers for that topic."
  (with-timeout (3000)
    (let* ((src (fol.lib.core-async:chan 4))
           (p   (fol.lib.core-async:pub src #'identity))
           (s1  (fol.lib.core-async:chan 4))
           (s2  (fol.lib.core-async:chan 4)))
      (fol.lib.core-async:sub      p :t s1)
      (fol.lib.core-async:sub      p :t s2)
      (fol.lib.core-async:unsub-all p :t)
      (fol.lib.core-async:>!! src :t)
      (sleep 0.1)
      (multiple-value-bind (_ ok) (fol.lib.core-async:poll! s1)
        (is (eq nil ok)))
      (multiple-value-bind (_ ok) (fol.lib.core-async:poll! s2)
        (is (eq nil ok)))
      (fol.lib.core-async:close! src))))

;;; ---------------------------------------------------------------------------
;;; alts!!
;;; ---------------------------------------------------------------------------

(test alts-takes-from-ready-channel
  "alts!! returns the value and channel that was ready."
  (with-timeout (2000)
    (let ((c1 (fol.lib.core-async:chan 1))
          (c2 (fol.lib.core-async:chan 1)))
      (fol.lib.core-async:offer! c1 :from-c1)
      (multiple-value-bind (val ch)
          (fol.lib.core-async:alts!! (list c1 c2))
        (is (eq :from-c1 val))
        (is (eq c1 ch))))))

(test alts-default-when-none-ready
  "alts!! with :default returns the default value when no channel is ready."
  (let ((c1 (fol.lib.core-async:chan))
        (c2 (fol.lib.core-async:chan)))
    (multiple-value-bind (val ch)
        (fol.lib.core-async:alts!! (list c1 c2) :default :timed-out)
      (is (eq :timed-out val))
      (is (eq nil ch)))))

;;; ---------------------------------------------------------------------------
;;; Transducer support
;;; ---------------------------------------------------------------------------

(test chan-with-map-transducer
  "A channel with a map transducer transforms items on input."
  (with-timeout (2000)
    (let* ((xf (lambda (rf)
                 (lambda (result item)
                   (funcall rf result (* item 2)))))
           (ch (fol.lib.core-async:chan 4 xf)))
      (fol.lib.core-async:offer! ch 1)
      (fol.lib.core-async:offer! ch 2)
      (fol.lib.core-async:offer! ch 3)
      (is (= 2  (nth-value 0 (fol.lib.core-async:poll! ch))))
      (is (= 4  (nth-value 0 (fol.lib.core-async:poll! ch))))
      (is (= 6  (nth-value 0 (fol.lib.core-async:poll! ch)))))))

(test chan-with-filter-transducer
  "A channel with a filter transducer only admits passing items."
  (with-timeout (2000)
    (let* ((xf (lambda (rf)
                 (lambda (result item)
                   (if (evenp item)
                       (funcall rf result item)
                       result))))
           (ch (fol.lib.core-async:chan 4 xf)))
      (fol.lib.core-async:offer! ch 1) ; filtered out
      (fol.lib.core-async:offer! ch 2) ; admitted
      (fol.lib.core-async:offer! ch 3) ; filtered out
      (fol.lib.core-async:offer! ch 4) ; admitted
      (is (= 2 (nth-value 0 (fol.lib.core-async:poll! ch))))
      (is (= 4 (nth-value 0 (fol.lib.core-async:poll! ch))))
      (multiple-value-bind (_ ok) (fol.lib.core-async:poll! ch)
        (is (eq nil ok))))))
