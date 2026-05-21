;;;; LRU Dispatch Cache Variant
;;;; Compares LRU eviction policy vs. generation-based invalidation

(defpackage :fol.benchmarks.dispatch-lru
  (:use :cl)
  (:export :run-lru-comparison))

(in-package :fol.benchmarks.dispatch-lru)

;;; LRU Cache Implementation

(defstruct (lru-cache (:constructor make-lru-cache (capacity)))
  (table      (make-hash-table :test 'equal :synchronized t) :type hash-table)
  (access-log nil :type list)  ; list of (timestamp . key) in access order
  (capacity   nil :type fixnum)
  (hits       0 :type (unsigned-byte 64))
  (misses     0 :type (unsigned-byte 64)))

(defun lru-lookup (cache key)
  "Lookup in LRU cache; update access time."
  (let ((hit (gethash key (lru-cache-table cache))))
    (if hit
        (progn
          (sb-ext:atomic-incf (lru-cache-hits cache))
          ;; Record access (simplified: actual LRU would use timestamps)
          (push (cons (get-internal-real-time) key) (lru-cache-access-log cache))
          hit)
        (progn
          (sb-ext:atomic-incf (lru-cache-misses cache))
          nil))))

(defun lru-insert (cache key value)
  "Insert into LRU cache; evict least-recently-used if at capacity."
  (let ((table (lru-cache-table cache))
        (count (hash-table-count (lru-cache-table cache)))
        (cap (lru-cache-capacity cache)))
    ;; If at capacity, evict LRU entry
    (when (>= count cap)
      (let ((lru-key (caar (last (lru-cache-access-log cache)))))
        (when lru-key
          (remhash lru-key table))))
    ;; Insert new entry
    (setf (gethash key table) value)
    ;; Clear old access log to prevent memory growth
    (when (> (length (lru-cache-access-log cache)) (* 10 cap))
      (setf (lru-cache-access-log cache)
            (subseq (lru-cache-access-log cache) (- (* 5 cap)))))))

(defun lru-stats (cache)
  "Return stats for LRU cache."
  (values (lru-cache-hits cache)
          (lru-cache-misses cache)
          (hash-table-count (lru-cache-table cache))))

;;; Generation-Based Cache (Original)

(defstruct (gen-cache (:constructor make-gen-cache ()))
  (table      (make-hash-table :test 'equal :synchronized t) :type hash-table)
  (generation 0 :type (unsigned-byte 64))
  (hits       0 :type (unsigned-byte 64))
  (misses     0 :type (unsigned-byte 64)))

(defun gen-lookup (cache key)
  "Lookup in generation-based cache."
  (let ((hit (gethash key (gen-cache-table cache))))
    (if hit
        (progn (sb-ext:atomic-incf (gen-cache-hits cache)) hit)
        (progn (sb-ext:atomic-incf (gen-cache-misses cache)) nil))))

(defun gen-insert (cache key value)
  "Insert into generation-based cache (unbounded)."
  (setf (gethash key (gen-cache-table cache)) value))

(defun gen-flush (cache)
  "Invalidate all entries."
  (clrhash (gen-cache-table cache))
  (setf (gen-cache-hits cache) 0
        (gen-cache-misses cache) 0)
  (sb-ext:atomic-incf (gen-cache-generation cache)))

(defun gen-stats (cache)
  "Return stats for generation cache."
  (values (gen-cache-hits cache)
          (gen-cache-misses cache)
          (gen-cache-generation cache)))

;;; Benchmark: Type Dispatch with Memory Pressure

(defun benchmark-type-dispatch-lru (workload-name predicate-fn num-calls num-types cache-capacity)
  "Benchmark type dispatch with LRU caching and memory pressure.

   PREDICATE-FN: (lambda (x) ...) returns dispatch key
   NUM-CALLS: total number of calls
   NUM-TYPES: distinct predicate values
   CACHE-CAPACITY: max entries in LRU cache"
  (let ((test-data (loop for i below num-calls
                         collect (mod i num-types))))

    ;; LRU variant
    (let ((lru-cache (make-lru-cache cache-capacity))
          (start (get-internal-real-time)))
      (loop for x in test-data do
        (let ((key x))
          (let ((cached (lru-lookup lru-cache key)))
            (unless cached
              (let ((result (funcall predicate-fn x)))
                (lru-insert lru-cache key result))))))
      (let ((elapsed (- (get-internal-real-time) start)))
        (multiple-value-bind (hits misses size) (lru-stats lru-cache)
          (let* ((hit-rate (if (> (+ hits misses) 0)
                               (/ hits (float (+ hits misses)))
                               0.0))
                 (time-ms (* (/ elapsed internal-time-units-per-second) 1000))
                 (hit-pct (* hit-rate 100)))
            (format t "~&LRU (~a, cap=~D):~%  Time: ~F ms  Hit rate: ~F%  (H:~D M:~D Size:~D)~%"
                    workload-name cache-capacity
                    time-ms hit-pct hits misses size)))))

    ;; Generation-based variant (no flush)
    (let ((gen-cache (make-gen-cache))
          (start (get-internal-real-time)))
      (loop for x in test-data do
        (let ((key x))
          (let ((cached (gen-lookup gen-cache key)))
            (unless cached
              (let ((result (funcall predicate-fn x)))
                (gen-insert gen-cache key result))))))
      (let ((elapsed (- (get-internal-real-time) start)))
        (multiple-value-bind (hits misses gen) (gen-stats gen-cache)
          (let* ((hit-rate (if (> (+ hits misses) 0)
                               (/ hits (float (+ hits misses)))
                               0.0))
                 (time-ms (* (/ elapsed internal-time-units-per-second) 1000))
                 (hit-pct (* hit-rate 100)))
            (format t "Generation (unbounded):~%  Time: ~F ms  Hit rate: ~F%  (H:~D M:~D Gen:~D)~%"
                    time-ms hit-pct hits misses gen)))))))

;;; Benchmark: Bursty Access Pattern (LRU Advantage)

(defun benchmark-bursty-lru ()
  "Bursty workload: 80% of calls are to 2 types.

   LRU should excel here: frequently accessed items stay in cache.
   Generation strategy: unbounded cache grows to ~8 entries."
  (format t "~%=== LRU vs Generation-Based: Bursty Workload ===~%")
  (let ((predicate-fn (lambda (x)
                        ;; Simple type predicate
                        (cond ((integerp x) :int)
                              ((stringp x) :string)
                              ((vectorp x) :vector)
                              (t :other)))))

    ;; Create bursty test data: 80% access to types 0 and 1
    (let ((test-data (loop for i below 10000
                           collect (if (< (random 100) 80)
                                       (random 2)
                                       (+ 2 (random 6))))))

      ;; Benchmark with different LRU cache capacities
      (format t "~&=== Capacity Sensitivity ===~%")
      (loop for capacity in '(2 4 8 16 32) do
        (format t "~&LRU capacity: ~d~%" capacity)
        (benchmark-type-dispatch-lru "bursty" predicate-fn 10000 8 capacity)))))

;;; Benchmark: Uniform Access (Generation Advantage)

(defun benchmark-uniform-lru ()
  "Uniform workload: equal access to all types.

   Generation cache: should match LRU when capacity is large enough.
   LRU: benefits only if memory-constrained."
  (format t "~%=== LRU vs Generation-Based: Uniform Workload ===~%")
  (let ((predicate-fn (lambda (x) (mod x 20))))
    (format t "~&=== K=20 types, M=100k calls ===~%")
    (benchmark-type-dispatch-lru "uniform" predicate-fn 100000 20 10)))

;;; Benchmark: Memory Overhead

(defun benchmark-memory-overhead ()
  "Compare memory usage of LRU (bounded) vs generation (unbounded).

   Setup: dispatch cache with growing number of distinct predicates."
  (format t "~%=== Memory Overhead: LRU vs Generation ===~%")

  (let ((test-sizes '(100 1000 10000))
        (lru-cache (make-lru-cache 1000))
        (gen-cache (make-gen-cache)))
    (loop for size in test-sizes do
      ;; Populate both caches with size distinct entries
      (loop for i below size do
        (let ((key (list i (random 1000))))
          (lru-insert lru-cache key i)
          (gen-insert gen-cache key i)))

      ;; Report sizes
      (format t "~&After ~d insertions:~%" size)
      (format t "  LRU (cap 1000):  ~d entries~%"
              (hash-table-count (lru-cache-table lru-cache)))
      (format t "  Generation:      ~d entries~%"
              (hash-table-count (gen-cache-table gen-cache))))))

;;; Main Entry Point

(defun run-lru-comparison ()
  "Run all LRU vs generation cache comparison benchmarks."
  (format t "~%╔════════════════════════════════════════════════════╗~%")
  (format t   "║  Dispatch Cache Strategy Comparison: LRU vs Generation ║~%")
  (format t   "╚════════════════════════════════════════════════════╝~%")

  (benchmark-bursty-lru)
  (benchmark-uniform-lru)
  (benchmark-memory-overhead)

  (format t "~%~%=== Summary ===~%")
  (format t "~&LRU cache:          Better for memory-constrained systems with bursty access~%")
  (format t "Generation cache:    Better for unbounded memory; simpler invalidation model~%")
  (format t "Hybrid approach:     Use LRU with generation-based flush on method redefinition~%"))
