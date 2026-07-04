;;; FOL Compiler - Recursive Benchmarks Runner
;;;
;;; Runs the new recursive micro-benchmarks to measure the performance
;;; improvement from the Tier-2 fixed-point summary inference.

(load "src/test-load.lisp")

(defun run-benchmark (file-path &key (transients t))
  "Compile and run a benchmark file, returning the elapsed time in seconds."
  (let ((fol.compiler.escape-analysis:*transient-loops* transients)
        (fasl-path (fol.compiler:compile-file file-path)))
    (load fasl-path)
    (let* ((start-time (get-internal-real-time))
           (result (funcall (find-symbol "MAIN" :fol.core)))
           (end-time (get-internal-real-time))
           (elapsed-ms (/ (- end-time start-time)
                          (/ internal-time-units-per-second 1000.0))))
      (declare (ignore result))
      elapsed-ms)))

(defun run-and-compare (name file-path)
  "Run a benchmark with and without transient optimizations and print results."
  (format t "~&--- Running benchmark: ~A ---~%" name)
  (let* ((baseline-ms (run-benchmark file-path :transients nil))
         (optimized-ms (run-benchmark file-path :transients t))
         (speedup (if (> optimized-ms 0) (/ baseline-ms optimized-ms) 0.0)))
    (format t "Baseline:  ~,2f ms~%" baseline-ms)
    (format t "Optimized: ~,2f ms~%" optimized-ms)
    (format t "Speedup:   ~,2fx~%" speedup)
    (values baseline-ms optimized-ms speedup)))

(defun main ()
  (format t "~&==================================================")
  (format t "~&Running Recursive Function Performance Benchmarks")
  (format t "~&==================================================~%~%")

  (let ((results '()))
    (push (multiple-value-list
           (run-and-compare "Recursive Accumulator"
                            "benchmarks/fol-code/recursive-accumulator-bench.fol"))
          results)
    (terpri)
    (push (multiple-value-list
           (run-and-compare "Mutual Recursion"
                            "benchmarks/fol-code/mutual-recursion-bench.fol"))
          results)

    (setf results (nreverse results))

    (format t "~&--- Summary ---~%")
    (format t "~&| Benchmark             | Baseline (ms) | Optimized (ms) | Speedup |~%")
    (format t   "|-----------------------|---------------|----------------|---------|~%")
    (loop for (base opt speed) in results
          for name in '("Recursive Accumulator" "Mutual Recursion")
          do (format t "| ~21A | ~13,2f | ~14,2f | ~6,2fx |~%"
                     name base opt speed))))

(main)
(uiop:quit)