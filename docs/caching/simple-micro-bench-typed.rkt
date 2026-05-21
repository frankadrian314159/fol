#lang typed/racket

;;; Micro-benchmark: homogeneous dispatch (Typed Racket version)
;;; All dispatches on numbers (integers) only

;;; Clause functions
(: clause-long (Any -> (Listof Any)))
(define (clause-long x) (list "long" x))

;;; Uncached dispatcher (COND-style)
(: dispatch-uncached (Any -> (Listof Any)))
(define (dispatch-uncached x)
  (if (number? x)
      (clause-long x)
      (list "other" x)))

;;; "Cached" dispatcher - direct function selection
(: dispatch-cached (Any -> (Listof Any)))
(define (dispatch-cached x)
  (let ([fn (if (number? x) clause-long (lambda (x) (list "other" x)))])
    (fn x)))

;;; Test data: 2,000,000 random numbers
(define test-data : (Listof Any)
  (let loop ([i 0] [acc '()])
    (if (>= i 2000000)
        (reverse acc)
        (loop (+ i 1) (cons (random 1000000) acc)))))

;;; Benchmark functions
(: benchmark-uncached (Integer -> Void))
(define (benchmark-uncached iterations)
  (displayln "=== Uncached COND Dispatch (3 iterations) ===")
  (let loop ([run 0])
    (when (< run iterations)
      (let* ([start-ns (current-inexact-milliseconds)]
             [_ (for ([item test-data])
                  (dispatch-uncached item))]
             [elapsed-ms (- (current-inexact-milliseconds) start-ns)]
             [elapsed-sec (/ elapsed-ms 1000)])
        (printf "  Run ~a: ~a seconds\n" (+ run 1) elapsed-sec))
      (loop (+ run 1)))))

(: benchmark-cached (Integer -> Void))
(define (benchmark-cached iterations)
  (displayln "\n=== Cached Dispatch (3 iterations) ===")
  (let loop ([run 0])
    (when (< run iterations)
      (let* ([start-ns (current-inexact-milliseconds)]
             [_ (for ([item test-data])
                  (dispatch-cached item))]
             [elapsed-ms (- (current-inexact-milliseconds) start-ns)]
             [elapsed-sec (/ elapsed-ms 1000)])
        (printf "  Run ~a: ~a seconds\n" (+ run 1) elapsed-sec))
      (loop (+ run 1)))))

;;; Main
(displayln "================================")
(displayln "Typed Racket Homogeneous Dispatch Micro-Benchmark")
(displayln "================================")
(printf "Implementation: Racket ~a\n" (version))
(displayln "Test data: 2,000,000 number-only calls\n")

(displayln "Warming up JIT compiler (10,000 calls)...")
(let loop ([i 0])
  (when (< i 10000)
    (dispatch-uncached (list-ref test-data (modulo i (length test-data))))
    (dispatch-cached (list-ref test-data (modulo i (length test-data))))
    (loop (+ i 1))))
(displayln "Warmup complete.\n")

(benchmark-uncached 3)
(benchmark-cached 3)

(displayln "\n================================")
(displayln "Benchmark Complete")
(displayln "================================")
