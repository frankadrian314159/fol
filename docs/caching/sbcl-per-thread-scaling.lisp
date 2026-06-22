;;;; SBCL Per-Thread Caching Scaling Experiment
;;;; Tests per-thread caching from 1 to 64 threads
;;;; Measures speedup at each thread count

(defpackage :fol.caching.scaling
  (:use :cl :sb-thread)
  (:export :run-scaling-experiment))

(in-package :fol.caching.scaling)

;;; Thread-local storage
(defvar *thread-id* nil)
(defvar *thread-local-caches* (make-hash-table :test 'eql))
(defvar *cache-lock* (make-mutex))

(defun get-thread-cache ()
  "Get or create thread-local cache for current thread."
  (let* ((thread-key *thread-id*)
         (cache (with-mutex (*cache-lock*)
                  (gethash thread-key *thread-local-caches*))))
    (unless cache
      (setq cache (make-hash-table :test 'equal))
      (with-mutex (*cache-lock*)
        (setf (gethash thread-key *thread-local-caches*) cache)))
    cache))

;;; Dispatch predicates
(defun dispatch-type-a (arg) (typep arg 'integer))
(defun dispatch-type-b (arg) (typep arg 'string))
(defun dispatch-type-c (arg) (typep arg 'symbol))
(defun dispatch-type-d (arg) (typep arg 'list))

;;; UNCACHED dispatch
(defun dispatch-uncached (arg type-key)
  "Uncached dispatch: always evaluates predicate."
  (case type-key
    (:a (dispatch-type-a arg))
    (:b (dispatch-type-b arg))
    (:c (dispatch-type-c arg))
    (:d (dispatch-type-d arg))
    (otherwise nil)))

;;; CACHED dispatch (thread-local)
(defun dispatch-cached (arg type-key)
  "Cached dispatch using thread-local cache."
  (let* ((cache (get-thread-cache))
         (key (cons arg type-key)))
    (multiple-value-bind (result found-p) (gethash key cache)
      (if found-p
          result
          (let ((result (dispatch-uncached arg type-key)))
            (setf (gethash key cache) result)
            result)))))

;;; Test data (4-cycle pattern for high hit rate)
(defvar *test-args* #(42 "hello" 'symbol (1 2 3)))
(defvar *test-types* #(:a :b :c :d))

;;; Benchmark infrastructure
(defun measure-dispatch (dispatch-fn num-iterations)
  "Measure dispatch performance over iterations, returning ns per call."
  (let ((start-time (get-internal-real-time)))
    (dotimes (i num-iterations)
      (let ((arg (aref *test-args* (mod i 4)))
            (type-key (aref *test-types* (mod i 4))))
        (funcall dispatch-fn arg type-key)))
    (let* ((end-time (get-internal-real-time))
           (elapsed (/ (float (- end-time start-time))
                      (float internal-time-units-per-second)))
           (ns-per-call (* 1000000000 (/ elapsed num-iterations))))
      ns-per-call)))

(defun worker-thread-benchmark (thread-id num-iterations cached-p result-vec)
  "Worker thread that runs dispatch benchmark."
  (let ((*thread-id* thread-id))
    (declare (special *thread-id*))
    (let* ((dispatch-fn (if cached-p #'dispatch-cached #'dispatch-uncached))
           (ns-per-call (measure-dispatch dispatch-fn num-iterations)))
      (setf (aref result-vec thread-id) ns-per-call))))

(defun run-thread-pool-benchmark (num-threads num-iterations-per-thread cached-p)
  "Run benchmark with multiple threads, return average ns per call."
  (let ((threads (make-array num-threads))
        (results (make-array num-threads :initial-element 0.0d0)))

    ;; Create and start threads
    (dotimes (i num-threads)
      (setf (aref threads i)
            (make-thread
             (lambda (tid)
               (worker-thread-benchmark tid num-iterations-per-thread cached-p results))
             :arguments (list i)
             :name (format nil "worker-~d" i))))

    ;; Wait for all threads to complete
    (dotimes (i num-threads)
      (join-thread (aref threads i)))

    ;; Calculate average time per call (across all threads)
    (/ (reduce #'+ results) num-threads)))

(defun run-scaling-experiment (&key (min-threads 1) (max-threads 32) (iterations-per-thread 500000))
  "Run complete scaling experiment from min-threads to max-threads."
  (format t "SBCL Per-Thread Caching Scaling Experiment~%")
  (format t "SBCL ~a~%" (lisp-implementation-version))
  (format t "System: ~a (~a)~%" (machine-type) (machine-version))
  (format t "Iterations per thread: ~:d~%~%" iterations-per-thread)

  (let ((results-uncached nil)
        (results-cached nil))

    ;; Run scaling experiment
    (loop for num-threads from min-threads to max-threads
          by (if (<= max-threads 8) 1 (max 1 (floor max-threads 8)))
      do
        (format t "Testing with ~d thread~:p...~%" num-threads)
        (force-output)

        ;; Clear caches
        (with-mutex (*cache-lock*)
          (clrhash *thread-local-caches*))
        (sleep 0.1)

        ;; Measure UNCACHED
        (let ((ns-uncached (run-thread-pool-benchmark num-threads iterations-per-thread nil)))
          (push (cons num-threads ns-uncached) results-uncached)
          (format t "  Uncached: ~,2f ns/call~%" ns-uncached)
          (force-output))

        ;; Measure CACHED
        (let ((ns-cached (run-thread-pool-benchmark num-threads iterations-per-thread t)))
          (push (cons num-threads ns-cached) results-cached)
          (let ((speedup (/ (cdr (car results-uncached)) ns-cached)))
            (format t "  Cached:   ~,2f ns/call (speedup: ~,2f×)~%~%" ns-cached speedup))
          (force-output)))

    ;; Print summary table
    (format t "~%~%=== SUMMARY TABLE ===~%")
    (format t "~20a ~18a ~18a ~15a~%"
            "Threads" "Uncached (ns)" "Cached (ns)" "Speedup")
    (format t "~20a ~18a ~18a ~15a~%"
            (make-string 20 :initial-element #\-)
            (make-string 18 :initial-element #\-)
            (make-string 18 :initial-element #\-)
            (make-string 15 :initial-element #\-))

    (loop for (threads . ns-uncached) in (reverse results-uncached)
      for (_ . ns-cached) in (reverse results-cached)
      do
        (let ((speedup (/ ns-uncached ns-cached)))
          (format t "~20d ~18,2f ~18,2f ~15,2f×~%"
                  threads ns-uncached ns-cached speedup)))

    ;; Analysis
    (format t "~%~%=== ANALYSIS ===~%")
    (let ((first-speedup (/ (cdr (car (last results-uncached)))
                            (cdr (car (last results-cached)))))
          (last-speedup (/ (cdr (car results-uncached))
                           (cdr (car results-cached)))))
      (format t "Single-thread speedup: ~,2f×~%" first-speedup)
      (format t "Max-thread speedup:    ~,2f×~%" last-speedup)
      (if (> first-speedup 0)
          (format t "Scaling efficiency:    ~,1f%~%" (* 100 (/ last-speedup first-speedup)))
          (format t "Scaling efficiency:    N/A (negative speedup)~%")))

    (format t "~%CONCLUSION: ~a~%"
            (if (> (cdr (car (last results-cached))) (cdr (car (last results-uncached))))
                "Per-thread caching provides consistent speedup across thread counts"
                "Per-thread caching shows slowdown or diminishing returns at scale"))))

;;; Entry point
(defun main ()
  (handler-case
      (run-scaling-experiment :min-threads 1 :max-threads 16 :iterations-per-thread 300000)
    (error (e)
      (format t "Error during benchmark: ~a~%" e))))

(main)
(sb-ext:exit)
