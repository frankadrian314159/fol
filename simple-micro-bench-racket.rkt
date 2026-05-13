#lang racket

;;; Micro-benchmark: homogeneous types (Racket Scheme version)
;;; All dispatches on fixnum only

;; Cache structure
(define +cache-size+ 8)

(define-struct dispatch-cache
  (entries next))

(define (create-dispatch-cache)
  (make-dispatch-cache (make-vector +cache-size+ #f) 0))

(define (cache-lookup cache key)
  (let loop ([i 0])
    (if (>= i +cache-size+)
        #f
        (let ([entry (vector-ref (dispatch-cache-entries cache) i)])
          (if (and entry (eq? (car entry) key))
              (cdr entry)
              (loop (+ i 1)))))))

(define (cache-insert! cache key fn)
  (let* ([entries (dispatch-cache-entries cache)]
         [pos (dispatch-cache-next cache)])
    (vector-set! entries pos (cons key fn))
    (set-dispatch-cache-next! cache (modulo (+ pos 1) +cache-size+))))

;; Clause functions
(define (%-clause-fixnum x) (list 'fixnum x))
(define (%-clause-string x) (list 'string (string-length x)))
(define (%-clause-list x) (list 'list (length x)))
(define (%-clause-vector x) (list 'vector (vector-length x)))
(define (%-clause-symbol x) (list 'symbol x))
(define (%-clause-other x) (list 'other x))

;; Cache variable
(define %-homo-cache (create-dispatch-cache))
(define %-cache-hits 0)
(define %-cache-misses 0)

;; Uncached dispatcher
(define (dispatch-homo-uncached x)
  "6-clause dispatcher WITHOUT caching (homogeneous fixnum)"
  (cond
    [(fixnum? x) (list 'fixnum x)]
    [(string? x) (list 'string (string-length x))]
    [(list? x) (list 'list (length x))]
    [(vector? x) (list 'vector (vector-length x))]
    [(symbol? x) (list 'symbol x)]
    [else (list 'other x)]))

;; Cached dispatcher
(define (dispatch-homo-cached x)
  "6-clause dispatcher WITH caching"
  (let* ([key (object-name x)]
         [hit (cache-lookup %-homo-cache key)])
    (if hit
        (begin
          (set! %-cache-hits (+ %-cache-hits 1))
          (hit x))
        (begin
          (set! %-cache-misses (+ %-cache-misses 1))
          (cond
            [(fixnum? x)
             (cache-insert! %-homo-cache key %-clause-fixnum)
             (%-clause-fixnum x)]
            [(string? x)
             (cache-insert! %-homo-cache key %-clause-string)
             (%-clause-string x)]
            [(list? x)
             (cache-insert! %-homo-cache key %-clause-list)
             (%-clause-list x)]
            [(vector? x)
             (cache-insert! %-homo-cache key %-clause-vector)
             (%-clause-vector x)]
            [(symbol? x)
             (cache-insert! %-homo-cache key %-clause-symbol)
             (%-clause-symbol x)]
            [else
             (cache-insert! %-homo-cache key %-clause-other)
             (%-clause-other x)])))))

;; Test data: 200,000 fixnum-only calls
(define *test-data*
  (let loop ([i 0] [acc '()])
    (if (>= i 200000)
        (reverse acc)
        (loop (+ i 1) (cons (random 1000000) acc)))))

;; Benchmark function
(define (benchmark-uncached [iterations 3])
  "Benchmark uncached dispatch"
  (let loop ([run 0] [times '()])
    (if (>= run iterations)
        times
        (let* ([start (current-process-milliseconds)]
               [result 0])
          (dotimes i (length *test-data*)
            (set! result (+ result (if (dispatch-homo-uncached (list-ref *test-data* i)) 1 0))))
          (let ([elapsed (- (current-process-milliseconds) start)])
            (printf "  Run ~D: ~A seconds\n" (+ run 1) (/ elapsed 1000.0))
            (loop (+ run 1) (cons result times)))))))

(define (benchmark-cached [iterations 3])
  "Benchmark cached dispatch"
  (let loop ([run 0] [times '()])
    (if (>= run iterations)
        times
        (let* ([start (current-process-milliseconds)]
               [result 0])
          (set! %-cache-hits 0)
          (set! %-cache-misses 0)
          (dotimes i (length *test-data*)
            (set! result (+ result (if (dispatch-homo-cached (list-ref *test-data* i)) 1 0))))
          (let ([elapsed (- (current-process-milliseconds) start)])
            (printf "  Run ~D: ~A seconds\n" (+ run 1) (/ elapsed 1000.0))
            (loop (+ run 1) (cons result times)))))))

(define (run-all-benchmarks)
  "Run all benchmarks"
  (printf "~&================================~%")
  (printf "Racket Homogeneous Dispatch Caching Micro-Benchmark~%")
  (printf "================================~%")
  (printf "Implementation: ~A~%" (version))
  (printf "Test data: 200,000 fixnum-only calls~%~%")

  (printf "Warming up JIT compiler (10,000 calls)...~%")
  (let loop ([i 0])
    (when (< i 10000)
      (dispatch-homo-uncached (list-ref *test-data* (modulo i (length *test-data*))))
      (loop (+ i 1))))
  (let loop ([i 0])
    (when (< i 10000)
      (set! %-cache-hits 0)
      (set! %-cache-misses 0)
      (dispatch-homo-cached (list-ref *test-data* (modulo i (length *test-data*))))
      (loop (+ i 1))))
  (printf "Warmup complete.~%~%")

  (printf "=== Uncached COND Dispatch (3 iterations) ===~%")
  (benchmark-uncached 3)

  (printf "~%=== Cached Dispatch (3 iterations) ===~%")
  (benchmark-cached 3)

  (printf "~&Cached Dispatch Stats:~%")
  (printf "  Cache hits: ~D~%" %-cache-hits)
  (printf "  Cache misses: ~D~%" %-cache-misses)
  (printf "  Hit rate: ~,4F%~%" (* 100.0 (/ %-cache-hits (+ %-cache-hits %-cache-misses))))

  (printf "~&================================~%")
  (printf "Benchmark Complete~%")
  (printf "================================~%"))

;; Helper macro
(define-syntax dotimes
  (syntax-rules ()
    [(dotimes (var count) body ...)
     (let loop ([var 0])
       (when (< var count)
         body ...
         (loop (+ var 1))))]))

;; Run benchmarks
(run-all-benchmarks)
