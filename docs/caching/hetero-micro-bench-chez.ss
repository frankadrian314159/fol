#!/usr/bin/env scheme
;;; Micro-benchmark: heterogeneous types (Chez Scheme version)
;;; Compares dispatch caching across Lisp/Scheme implementations

;; Define displayln
(define (displayln x)
  (display x)
  (newline))

;; Cache structure
(define +cache-size+ 8)

(define-record-type dispatch-cache
  (fields (mutable entries) (mutable next) (mutable hits) (mutable misses)))

(define (create-dispatch-cache)
  (make-dispatch-cache (make-vector +cache-size+ #f) 0 0 0))

(define (cache-lookup cache key)
  (let loop ((i 0))
    (if (>= i +cache-size+)
        #f
        (let ((entry (vector-ref (dispatch-cache-entries cache) i)))
          (if (and entry (eq? (car entry) key))
              (cdr entry)
              (loop (+ i 1)))))))

(define (cache-insert! cache key fn)
  (let* ((entries (dispatch-cache-entries cache))
         (pos (dispatch-cache-next cache)))
    (vector-set! entries pos (cons key fn))
    (dispatch-cache-next-set! cache (modulo (+ pos 1) +cache-size+))))

;; Clause functions
(define (%-clause-fixnum x) (list 'fixnum x))
(define (%-clause-string x) (list 'string (string-length x)))
(define (%-clause-list x) (list 'list (length x)))
(define (%-clause-vector x) (list 'vector (vector-length x)))
(define (%-clause-symbol x) (list 'symbol x))
(define (%-clause-other x) (list 'other x))

;; Cache variable
(define %-hetero-cache (create-dispatch-cache))

;; Uncached dispatcher
(define (dispatch-hetero-uncached x)
  (cond
    ((fixnum? x) (list 'fixnum x))
    ((string? x) (list 'string (string-length x)))
    ((list? x) (list 'list (length x)))
    ((vector? x) (list 'vector (vector-length x)))
    ((symbol? x) (list 'symbol x))
    (else (list 'other x))))

;; Cached dispatcher
(define (dispatch-hetero-cached x)
  (let* ((key (cond
                ((fixnum? x) 'fixnum)
                ((string? x) 'string)
                ((list? x) 'list)
                ((vector? x) 'vector)
                ((symbol? x) 'symbol)
                (else 'other)))
         (hit (cache-lookup %-hetero-cache key)))
    (if hit
        (begin
          (dispatch-cache-hits-set! %-hetero-cache
            (+ (dispatch-cache-hits %-hetero-cache) 1))
          (hit x))
        (begin
          (dispatch-cache-misses-set! %-hetero-cache
            (+ (dispatch-cache-misses %-hetero-cache) 1))
          (cond
            ((fixnum? x)
             (cache-insert! %-hetero-cache key %-clause-fixnum)
             (%-clause-fixnum x))
            ((string? x)
             (cache-insert! %-hetero-cache key %-clause-string)
             (%-clause-string x))
            ((list? x)
             (cache-insert! %-hetero-cache key %-clause-list)
             (%-clause-list x))
            ((vector? x)
             (cache-insert! %-hetero-cache key %-clause-vector)
             (%-clause-vector x))
            ((symbol? x)
             (cache-insert! %-hetero-cache key %-clause-symbol)
             (%-clause-symbol x))
            (else
             (cache-insert! %-hetero-cache key %-clause-other)
             (%-clause-other x)))))))

;; Test data: 200,000 calls with 5-type repeating cycle
(define *test-data*
  (let loop ((i 0) (acc '()))
    (if (>= i 200000)
        (reverse acc)
        (loop (+ i 1)
              (cons (case (modulo i 5)
                      ((0) (random 1000000))
                      ((1) "test string")
                      ((2) '(a b c d e))
                      ((3) (vector 1 2 3 4 5))
                      ((4) 'symbol))
                    acc)))))

;; Benchmark function
(define (benchmark-uncached iterations)
  (let loop ((run 0) (times '()))
    (if (>= run iterations)
        times
        (let* ((start (cpu-time))
               (result 0))
          (do ((i 0 (+ i 1)))
              ((>= i (length *test-data*)))
            (set! result (+ result (if (dispatch-hetero-uncached (list-ref *test-data* i)) 1 0))))
          (let ((elapsed (* (- (cpu-time) start) 1000.0)))
            (displayln (format "  Run ~a: ~a seconds" (+ run 1) (/ elapsed 1000.0)))
            (loop (+ run 1) (cons result times)))))))

(define (benchmark-cached iterations)
  (let loop ((run 0) (times '()))
    (if (>= run iterations)
        times
        (let* ((start (cpu-time))
               (result 0))
          (dispatch-cache-hits-set! %-hetero-cache 0)
          (dispatch-cache-misses-set! %-hetero-cache 0)
          (do ((i 0 (+ i 1)))
              ((>= i (length *test-data*)))
            (set! result (+ result (if (dispatch-hetero-cached (list-ref *test-data* i)) 1 0))))
          (let ((elapsed (* (- (cpu-time) start) 1000.0)))
            (displayln (format "  Run ~a: ~a seconds" (+ run 1) (/ elapsed 1000.0)))
            (loop (+ run 1) (cons result times)))))))

(define (run-all-benchmarks)
  (displayln "\n================================")
  (displayln "Chez Scheme Heterogeneous Dispatch Caching Micro-Benchmark")
  (displayln "================================")
  (displayln (format "Implementation: ~a" (scheme-version)))
  (displayln "Test data: 200,000 calls over repeating 5-type cycle")
  (displayln "  Type cycle: fixnum -> string -> list -> vector -> symbol\n")

  (displayln "Warming up JIT compiler (10,000 calls)...")
  (do ((i 0 (+ i 1)))
      ((>= i 10000))
    (dispatch-hetero-uncached (list-ref *test-data* (modulo i (length *test-data*)))))
  (do ((i 0 (+ i 1)))
      ((>= i 10000))
    (dispatch-cache-hits-set! %-hetero-cache 0)
    (dispatch-cache-misses-set! %-hetero-cache 0)
    (dispatch-hetero-cached (list-ref *test-data* (modulo i (length *test-data*)))))
  (displayln "Warmup complete.\n")

  (displayln "=== Uncached COND Dispatch (3 iterations) ===")
  (benchmark-uncached 3)

  (displayln "\n=== Cached Dispatch (3 iterations) ===")
  (benchmark-cached 3)

  (displayln "\nCached Dispatch Stats:")
  (displayln (format "  Cache hits: ~a" (dispatch-cache-hits %-hetero-cache)))
  (displayln (format "  Cache misses: ~a" (dispatch-cache-misses %-hetero-cache)))
  (let ((total (+ (dispatch-cache-hits %-hetero-cache) (dispatch-cache-misses %-hetero-cache))))
    (displayln (format "  Hit rate: ~a"
      (if (> total 0)
          (number->string (* 100.0 (/ (dispatch-cache-hits %-hetero-cache) total)))
          "N/A"))))

  (displayln "\n================================")
  (displayln "Benchmark Complete")
  (displayln "================================"))

;; Run benchmarks
(run-all-benchmarks)
