;;;; SBCL Expensive Predicates Dispatch Caching Benchmark
;;;; Tests dispatch with expensive regex/pattern matching predicates

(defpackage :expensive-predicates-bench
  (:use :cl)
  (:export :run-benchmark))

(in-package :expensive-predicates-bench)

;;; Global cache: 8-slot round-robin LRU
(defstruct dispatch-cache
  (entries (make-array 8 :initial-element (make-hash-table :test 'equal)) :type (vector hash-table))
  (next 0 :type fixnum)
  (hits 0 :type fixnum)
  (misses 0 :type fixnum))

(defun cache-lookup (cache key)
  (loop for i below 8
        when (gethash key (aref (dispatch-cache-entries cache) i))
        do (incf (dispatch-cache-hits cache))
           (return (gethash key (aref (dispatch-cache-entries cache) i)))
        finally (incf (dispatch-cache-misses cache))
                (return nil)))

(defun cache-insert (cache key fn)
  (clrhash (aref (dispatch-cache-entries cache) (dispatch-cache-next cache)))
  (setf (gethash key (aref (dispatch-cache-entries cache) (dispatch-cache-next cache))) fn)
  (setf (dispatch-cache-next cache) (mod (1+ (dispatch-cache-next cache)) 8)))

(defun cache-reset (cache)
  (setf (dispatch-cache-hits cache) 0)
  (setf (dispatch-cache-misses cache) 0)
  (setf (dispatch-cache-next cache) 0)
  (loop for i below 8 do (clrhash (aref (dispatch-cache-entries cache) i))))

;;; Expensive predicates using CL regex (cl-ppcre)
(defun predicate-is-email (x)
  "Check if X is a valid email address (expensive regex, ~2-3 µs)"
  (and (stringp x)
       (ppcre:scan "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$" x)))

(defun predicate-is-json (x)
  "Check if X looks like JSON (expensive regex, ~1-2 µs)"
  (and (stringp x)
       (ppcre:scan "^[\\s]*[\\{\\[].*[\\}\\]][\\s]*$" x)))

(defun predicate-is-ip (x)
  "Check if X is an IP address (expensive regex, ~2-3 µs)"
  (and (stringp x)
       (ppcre:scan "^(\\d{1,3}\\.){3}\\d{1,3}$" x)))

(defun predicate-is-url (x)
  "Check if X is a URL (expensive regex, ~2-3 µs)"
  (and (stringp x)
       (ppcre:scan "^https?://[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}(/[a-zA-Z0-9._~:/?#\\[\\]@!$&'()*+,;=-]*)?$" x)))

(defun predicate-is-alphanum (x)
  "Check if X is alphanumeric only (expensive regex, ~1-2 µs)"
  (and (stringp x)
       (ppcre:scan "^[a-zA-Z0-9]+$" x)))

;;; Clause functions
(defun clause-email (x) (list "email" x))
(defun clause-json (x) (list "json" x))
(defun clause-ip (x) (list "ipaddress" x))
(defun clause-url (x) (list "url" x))
(defun clause-alphanum (x) (list "alphanumeric" x))
(defun clause-unknown (x) (list "unknown" x))

;;; Uncached dispatch: test all predicates (5-15 µs per call)
(defun dispatch-uncached (x)
  (cond
    ((predicate-is-email x) (clause-email x))
    ((predicate-is-json x) (clause-json x))
    ((predicate-is-ip x) (clause-ip x))
    ((predicate-is-url x) (clause-url x))
    ((predicate-is-alphanum x) (clause-alphanum x))
    (t (clause-unknown x))))

;;; Cached dispatch
(defun dispatch-cached (x cache)
  (let* ((key (if (stringp x)
                  (if (> (length x) 20)
                      (subseq x 0 20)
                      x)
                  "unknown"))
         (cached (cache-lookup cache key)))
    (if cached
        (funcall cached x)
        (let (fn)
          (setf fn (cond
                     ((predicate-is-email x) #'clause-email)
                     ((predicate-is-json x) #'clause-json)
                     ((predicate-is-ip x) #'clause-ip)
                     ((predicate-is-url x) #'clause-url)
                     ((predicate-is-alphanum x) #'clause-alphanum)
                     (t #'clause-unknown)))
          (cache-insert cache key fn)
          (funcall fn x)))))

(defun run-benchmark ()
  (let ((num-calls 100000)
        (patterns '("user@example.com"
                    "{\"key\": \"value\"}"
                    "192.168.1.1"
                    "https://example.com/path?query=value"
                    "abc123def456")))

    (format t "================================~%")
    (format t "SBCL Expensive Predicates Dispatch Caching Micro-Benchmark~%")
    (format t "================================~%")
    (format t "Test data: ~D calls with expensive predicates (1-3 microseconds per predicate)~%" num-calls)
    (format t "  Predicates: email, JSON, IP address, URL, alphanumeric~%")
    (format t "  Dispatch cost (uncached): 5-15 microseconds per call~%")
    (format t "  Cache benefit potential: 2-10 microseconds savings when predicate matches early~%~%")

    ;; Create test data
    (let ((test-data (make-array num-calls)))
      (loop for i below num-calls
            do (setf (aref test-data i) (nth (mod i 5) patterns)))

      ;; Warmup
      (format t "Warming up compiler (10,000 calls)...~%")
      (loop for i below 10000
            do (dispatch-uncached (aref test-data (mod i num-calls))))

      (let ((cache (make-dispatch-cache)))
        (loop for i below 10000
              do (dispatch-cached (aref test-data (mod i num-calls)) cache)))

      (format t "Warmup complete.~%~%")

      ;; Uncached benchmark
      (format t "=== Uncached Expensive Dispatch (3 iterations) ===~%")
      (let ((uncached-times (make-array 3)))
        (loop for run below 3
              do (let ((start (get-internal-real-time)))
                   (loop for item across test-data
                         do (dispatch-uncached item))
                   (let* ((elapsed (- (get-internal-real-time) start))
                          (seconds (/ elapsed 1000.0))
                          (us-per-call (/ (* elapsed 1000.0) num-calls)))
                     (setf (aref uncached-times run) seconds)
                     (format t "  Run ~D: ~5,4F seconds (~5,2F us/call)~%" (1+ run) seconds us-per-call))))

        ;; Cached benchmark
        (format t "~%=== Cached Expensive Dispatch (3 iterations) ===~%")
        (let ((cached-times (make-array 3))
              (cache (make-dispatch-cache)))
          (loop for run below 3
                do (cache-reset cache)
                   (let ((start (get-internal-real-time)))
                     (loop for item across test-data
                           do (dispatch-cached item cache))
                     (let* ((elapsed (- (get-internal-real-time) start))
                            (seconds (/ elapsed 1000.0))
                            (us-per-call (/ (* elapsed 1000.0) num-calls)))
                       (setf (aref cached-times run) seconds)
                       (format t "  Run ~D: ~5,4F seconds (~5,2F us/call)~%" (1+ run) seconds us-per-call))))

          ;; Cache stats
          (format t "~%Cached Dispatch Stats:~%")
          (format t "  Cache hits: ~D~%" (dispatch-cache-hits cache))
          (format t "  Cache misses: ~D~%" (dispatch-cache-misses cache))
          (let ((total (+ (dispatch-cache-hits cache) (dispatch-cache-misses cache))))
            (when (> total 0)
              (format t "  Hit rate: ~5,4F%%~%"
                      (* 100.0 (/ (dispatch-cache-hits cache) total)))))

          ;; Summary
          (let* ((avg-uncached (/ (loop for time across uncached-times sum time) 3.0))
                 (avg-cached (/ (loop for time across cached-times sum time) 3.0))
                 (us-uncached (/ (* avg-uncached 1000.0) num-calls))
                 (us-cached (/ (* avg-cached 1000.0) num-calls))
                 (ratio (/ avg-cached avg-uncached)))

            (format t "~%================================~%")
            (format t "Average uncached: ~5,2F us/call~%" us-uncached)
            (format t "Average cached: ~5,2F us/call~%" us-cached)
            (format t "Speedup ratio: ~5,2F×~%" ratio)

            (if (< ratio 1.0)
                (format t "SPEEDUP: ~D%% faster with caching~%" (round (* 100 (- 1.0 ratio))))
                (format t "SLOWDOWN: ~D%% slower with caching~%" (round (* 100 (- ratio 1.0)))))

            (format t "~%Break-even analysis:~%")
            (format t "  Predicate cost: 5 to 15 microseconds (expensive)~%")
            (format t "  Cache overhead: 0.1 to 0.5 microseconds (negligible at this scale)~%")
            (format t "  Theoretical: Should see speedup if predicates are expensive enough~%")
            (format t "  Actual: ~5,2F%% ~A~%"
                    (if (< ratio 1.0)
                        (* 100 (- 1.0 ratio))
                        (* 100 (- ratio 1.0)))
                    (if (< ratio 1.0) "SPEEDUP" "SLOWDOWN"))

            (format t "================================~%")))))))
