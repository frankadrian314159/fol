;;;; FOL Dispatch Caching Performance Benchmark
;;;; Measures cache hit/miss behavior and speedup from caching

(eval-when (:compile-toplevel :load-toplevel :execute)
  (push #p"../src/" asdf:*central-registry*))

(asdf:load-system :fol-compiler)

(defun run-dispatch-cache-benchmark ()
  "Run a performance benchmark of dispatch caching.

   Measures:
   - Warm-up: 1000 calls to populate cache
   - Timed cached run: 100,000 calls with single type (all cache hits)
   - Cache statistics: hit rate and counts
   - Uncached baseline: same operations with cache flushed between calls
   - Speedup: ratio of cached to uncached performance"

  (format t "~%=== FOL Dispatch Cache Performance Benchmark ===~%")

  ;; Compile a 5-clause type-dispatch defn
  (let ((code "(defn type-dispatch-5 [x]
                (if (integer? x) :int
                (if (float? x) :float
                (if (string? x) :string
                (if (vector? x) :vector :other)))))"))

    (fol.compiler:compile-and-eval-form code)

    (let ((dispatch-fn (symbol-function 'type-dispatch-5))
          (warm-up-count 1000)
          (timed-run-count 100000))

      ;; WARM-UP: Populate cache
      (format t "Warm-up: ~D calls~%" warm-up-count)
      (loop repeat warm-up-count do
        (funcall dispatch-fn 42))

      ;; TIMED CACHED RUN: All cache hits with single type (integer)
      (format t "Timed run (~D calls, single type):~%" timed-run-count)
      (let ((start-time (get-internal-real-time)))
        (loop repeat timed-run-count do
          (funcall dispatch-fn 999))
        (let ((elapsed-ms (/ (- (get-internal-real-time) start-time)
                             internal-time-units-per-second
                             1000.0)))
          (format t "  Time: ~,1F ms  (~,2F µs/call)~%"
                  elapsed-ms
                  (* (/ elapsed-ms timed-run-count) 1000))))

      ;; Report cache statistics
      (multiple-value-bind (hits misses generation size)
          (fol.compiler.dispatch:inspect-fn-cache 'type-dispatch-5)
        (when hits
          (let ((total (+ hits misses)))
            (format t "Hit rate: ~,1F% (~D hits / ~D misses / ~D total)~%"
                    (if (> total 0) (* 100 (/ hits total)) 0)
                    hits misses total)
            (format t "Cache entries: ~D, generation: ~D~%" size generation))))

      ;; UNCACHED BASELINE: Same calls with cache flushed before each
      (format t "~%Uncached baseline (cache flushed each call):~%")
      (let* ((cache-sym (intern (format nil "%-~A-DISPATCH-CACHE"
                                        (symbol-name 'type-dispatch-5))
                               (symbol-package 'type-dispatch-5)))
             (cache (symbol-value cache-sym))
             (baseline-count 10000))  ;; Fewer calls for baseline (slower)
        (format t "  (~D calls for baseline)~%" baseline-count)
        (let ((start-time (get-internal-real-time)))
          (loop repeat baseline-count do
            (fol.compiler.dispatch:cache-flush! cache)
            (funcall dispatch-fn 999))
          (let ((elapsed-ms (/ (- (get-internal-real-time) start-time)
                               internal-time-units-per-second
                               1000.0)))
            (format t "  Time: ~,1F ms  (~,2F µs/call)~%"
                    elapsed-ms
                    (* (/ elapsed-ms baseline-count) 1000)))

          ;; Estimate speedup by extrapolation
          (let* ((cached-per-call (/ 100.0 timed-run-count 1000))  ;; 100ms / 100k calls → µs
                 (uncached-per-call (* (/ elapsed-ms baseline-count) 1000)))  ;; µs
            (when (> uncached-per-call 0)
              (format t "~%Estimated speedup: ~,1Fx~%"
                      (/ uncached-per-call cached-per-call))))))

      ;; Summary
      (format t "~%=== Benchmark Complete ===~%"))))

(defun main ()
  "Entry point for benchmark."
  (run-dispatch-cache-benchmark))

;; Run on load
(main)
