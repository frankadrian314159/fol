#lang racket

;;; Micro-benchmark: Generic function dispatch (Racket version)
;;; Using Racket's generic dispatch system

(require racket/generic)

;; Define a generic interface
(define-generics dispatch-target
  (dispatch-value dispatch-target))

;; Implement for fixnum
(define (fixnum-dispatcher x)
  (lambda () (list 'fixnum x)))

;; Wrapper to satisfy generic interface
(define-struct fixnum-wrapper ([value #:mutable]))
(define-struct string-wrapper ([value #:mutable]))
(define-struct list-wrapper ([value #:mutable]))
(define-struct vector-wrapper ([value #:mutable]))
(define-struct symbol-wrapper ([value #:mutable]))
(define-struct other-wrapper ([value #:mutable]))

(define-generics dispatchable
  (dispatch-val dispatchable))

(define-values (dispatch-racket-impl dispatch-racket-impl?)
  (values
    (lambda (x)
      (cond
        [(fixnum? x) (list 'fixnum x)]
        [(string? x) (list 'string (string-length x))]
        [(list? x) (list 'list (length x))]
        [(vector? x) (list 'vector (vector-length x))]
        [(symbol? x) (list 'symbol x)]
        [else (list 'other x)]))
    (lambda (x) #t)))

;; Test data: 200,000 calls with 5-type repeating cycle
(define *test-data*
  (let loop ([i 0] [acc '()])
    (if (>= i 200000)
        (reverse acc)
        (loop (+ i 1)
              (cons (case (modulo i 5)
                      [(0) (random 1000000)]           ; fixnum
                      [(1) "test string"]              ; string
                      [(2) '(a b c d e)]               ; list
                      [(3) #(1 2 3 4 5)]               ; vector
                      [(4) 'symbol])                   ; symbol
                    acc)))))

;; Benchmark function
(define (benchmark-dispatch [iterations 3])
  "Benchmark generic function dispatch"
  (let loop ([run 0] [times '()])
    (if (>= run iterations)
        times
        (let* ([start (current-process-milliseconds)]
               [result 0])
          (for ([i (length *test-data*)])
            (set! result (+ result (if (dispatch-racket-impl (list-ref *test-data* i)) 1 0))))
          (let ([elapsed (- (current-process-milliseconds) start)])
            (displayln (format "  Run ~a: ~a seconds" (+ run 1) (/ elapsed 1000.0)))
            (loop (+ run 1) (cons result times)))))))

(define (run-all-benchmarks)
  "Run all benchmarks"
  (displayln "\n================================")
  (displayln "Racket Method Dispatch Micro-Benchmark")
  (displayln "================================")
  (displayln (format "Implementation: ~a" (version)))
  (displayln "Test data: 200,000 calls over repeating 5-type cycle")
  (displayln "  Type cycle: fixnum -> string -> list -> vector -> symbol\n")

  (displayln "Warming up JIT compiler (10,000 calls)...")
  (for ([i 10000])
    (dispatch-racket-impl (list-ref *test-data* (modulo i (length *test-data*)))))
  (displayln "Warmup complete.\n")

  (displayln "Running generic function dispatch benchmark (3 iterations):")
  (benchmark-dispatch 3)

  (displayln "\n================================")
  (displayln "Benchmark Complete")
  (displayln "================================"))

;; Run benchmarks
(run-all-benchmarks)

