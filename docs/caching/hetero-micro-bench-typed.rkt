#lang typed/racket

;;; Micro-benchmark: heterogeneous dispatch (Typed Racket version)
;;; Compiles to optimized code with static type information

;;; Type checking function
(: get-type (Any -> String))
(define (get-type x)
  (cond
    [(number? x) "number"]
    [(string? x) "string"]
    [(list? x) "list"]
    [(vector? x) "vector"]
    [else "other"]))

;;; Clause functions - use Any to avoid cast issues
(: clause-number (Any -> (Listof Any)))
(define (clause-number x) (list "number" x))

(: clause-string (Any -> (Listof Any)))
(define (clause-string x)
  (if (string? x)
      (list "string" (string-length x))
      (list "string" 0)))

(: clause-list (Any -> (Listof Any)))
(define (clause-list x)
  (if (list? x)
      (list "list" (length x))
      (list "list" 0)))

(: clause-vector (Any -> (Listof Any)))
(define (clause-vector x)
  (if (vector? x)
      (list "vector" (vector-length x))
      (list "vector" 0)))

(: clause-other (Any -> (Listof Any)))
(define (clause-other x) (list "other" x))

;;; Uncached dispatcher
(: dispatch-uncached (Any -> (Listof Any)))
(define (dispatch-uncached x)
  (let ([type (get-type x)])
    (cond
      [(equal? type "number") (clause-number x)]
      [(equal? type "string") (clause-string x)]
      [(equal? type "list") (clause-list x)]
      [(equal? type "vector") (clause-vector x)]
      [else (clause-other x)])))

;;; Simple cached dispatcher - direct function selection
(: dispatch-cached (Any -> (Listof Any)))
(define (dispatch-cached x)
  (let ([type (get-type x)])
    (let ([fn (cond
                [(equal? type "number") clause-number]
                [(equal? type "string") clause-string]
                [(equal? type "list") clause-list]
                [(equal? type "vector") clause-vector]
                [else clause-other])])
      (fn x))))

;;; Test data: 2,000,000 calls with 5-type repeating cycle
(define test-data : (Listof Any)
  (let ([cycle (list 1 "test string" (list 1 2 3 4 5) (vector 1 2 3 4 5))])
    (let loop ([i 0] [acc '()])
      (if (>= i 2000000)
          (reverse acc)
          (loop (+ i 1) (cons (list-ref cycle (modulo i (length cycle))) acc))))))

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
(displayln "Typed Racket Heterogeneous Dispatch Micro-Benchmark")
(displayln "================================")
(printf "Implementation: Racket ~a\n" (version))
(displayln "Test data: 2,000,000 calls over repeating 5-type cycle")
(displayln "  Type cycle: number -> string -> list -> vector -> symbol\n")

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
