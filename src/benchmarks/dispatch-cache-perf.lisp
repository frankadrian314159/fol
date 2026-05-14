;;;; FOL Dispatch Cache: Performance Benchmark

(eval-when (:compile-toplevel :load-toplevel :execute)
  (push #p"../src/" asdf:*central-registry*))

(asdf:load-system :fol-compiler)

(defun run-dispatch-cache-perf-benchmark ()
  "Run performance benchmark for dispatch caching."
  (format t "~%=== FOL Dispatch Cache Performance Benchmark ===~%~%")

  (format t "Benchmark: Single-type dispatch (all cache hits)~%")
  (format t "  Defines a 5-clause type-dispatch function~%~%")

  (let ((code "
(defn type-dispatch [x]
  (cond
    ((integer? x) (* x 2))
    ((float? x) (* x 2.0))
    ((string? x) (str x x))
    ((vector? x) (concat x x))
    ((keyword? x) x)
    (t nil)))"))

    (fol.compiler:compile-and-eval-form code)

    ;; Warm-up
    (loop repeat 1000 do (type-dispatch 42))

    ;; Timed run with cache
    (let ((calls 100000))
      (format t "  Timed run (with cache): ~D calls~%" calls)
      (let ((start (get-internal-real-time)))
        (loop repeat calls do (type-dispatch 42))
        (let ((elapsed (/ (- (get-internal-real-time) start)
                          internal-time-units-per-second 1000.0)))
          (format t "  Result: ~,1F ms (~,2F µs/call)~%" 
                  elapsed (/ elapsed calls 1000.0)))))

    ;; Cache stats
    (multiple-value-bind (hits misses)
        (fol.compiler.dispatch:inspect-fn-cache 'type-dispatch)
      (when hits
        (let ((total (+ hits misses)))
          (format t "  Cache: ~,1F% hit rate (~D hits / ~D misses)~%"
                  (* 100.0 (/ hits total)) hits misses)))))

  (format t "~%=== Benchmark Complete ===~%"))

(defun main () (run-dispatch-cache-perf-benchmark))

(main)
