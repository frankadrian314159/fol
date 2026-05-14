#!/usr/bin/env scheme
;;; Micro-benchmark: generic function dispatch (Chez Scheme version)
;;; Basic dispatch performance test

;; Define displayln
(define (displayln x)
  (display x)
  (newline))

;; Simple dispatcher function
(define (dispatch-chez-impl x)
  (cond
    ((fixnum? x) (list 'fixnum x))
    ((string? x) (list 'string (string-length x)))
    ((list? x) (list 'list (length x)))
    ((vector? x) (list 'vector (vector-length x)))
    ((symbol? x) (list 'symbol x))
    (else (list 'other x))))

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
(define (benchmark-dispatch iterations)
  (let loop ((run 0) (times '()))
    (if (>= run iterations)
        times
        (let* ((start (cpu-time))
               (result 0))
          (do ((i 0 (+ i 1)))
              ((>= i (length *test-data*)))
            (set! result (+ result (if (dispatch-chez-impl (list-ref *test-data* i)) 1 0))))
          (let ((elapsed (* (- (cpu-time) start) 1000.0)))
            (displayln (format "  Run ~a: ~a seconds" (+ run 1) (/ elapsed 1000.0)))
            (loop (+ run 1) (cons result times)))))))

(define (run-all-benchmarks)
  (displayln "\n================================")
  (displayln "Chez Scheme Method Dispatch Micro-Benchmark")
  (displayln "================================")
  (displayln (format "Implementation: ~a" (scheme-version)))
  (displayln "Test data: 200,000 calls over repeating 5-type cycle")
  (displayln "  Type cycle: fixnum -> string -> list -> vector -> symbol\n")

  (displayln "Warming up JIT compiler (10,000 calls)...")
  (do ((i 0 (+ i 1)))
      ((>= i 10000))
    (dispatch-chez-impl (list-ref *test-data* (modulo i (length *test-data*)))))
  (displayln "Warmup complete.\n")

  (displayln "Running dispatch benchmark (3 iterations):")
  (benchmark-dispatch 3)

  (displayln "\n================================")
  (displayln "Benchmark Complete")
  (displayln "================================"))

;; Run benchmarks
(run-all-benchmarks)
