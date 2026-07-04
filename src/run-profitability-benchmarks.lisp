;;; FOL Compiler - Profitability Benchmarks Runner
;;;
;;; Runs benchmarks to determine the collection size at which transient
;;; conversion becomes more performant than standard persistent updates.

(load "src/test-load.lisp")

(defun run-benchmark (file-path size &key (transients t))
  "Compile and run a benchmark file for a given size."
  (let ((fol.compiler.escape-analysis:*transient-loops* transients)
        (fasl-path (fol.compiler:compile-file file-path)))
    (load fasl-path)
    (let* ((main-fn (find-symbol "MAIN" :fol.core))
           (start-time (get-internal-real-time))
           (result (funcall main-fn size))
           (end-time (get-internal-real-time))
           (elapsed-ms (/ (- end-time start-time)
                          (/ internal-time-units-per-second 1000.0))))
      (declare (ignore result))
      elapsed-ms)))

(defun find-crossover (name file-path sizes)
  "Find the smallest size where the optimized version is faster."
  (format t "~&--- Finding crossover for: ~A ---~%" name)
  (format t "~&| Size | Baseline (ms) | Optimized (ms) | Delta (ms) | Profitable? |~%")
  (format t   "|------|---------------|----------------|------------|-------------|~%")
  (let ((crossover-point nil))
    (dolist (size sizes)
      (let* ((baseline-ms (run-benchmark file-path size :transients nil))
             (optimized-ms (run-benchmark file-path size :transients t))
             (delta (- baseline-ms optimized-ms)))
        (format t "| ~4d | ~13,3f | ~14,3f | ~10,3f | ~11A |~%"
                size baseline-ms optimized-ms delta
                (if (> delta 0) "Yes" "No"))
        (when (and (null crossover-point) (> delta 0))
          (setf crossover-point size))))
    (if crossover-point
        (format t "~&Crossover point found at size: ~D~%" crossover-point)
        (format t "~&No crossover point found in the tested range.~%"))
    crossover-point))

(defun main ()
  (format t "~&======================================================")
  (format t "~&Running Profitability Heuristic Benchmarks")
  (format t "~&======================================================~%~%")

  (let ((sizes '(2 4 8 10 12 14 16 20 24 32 40))
        (dict-crossover nil)
        (vector-crossover nil))

    (setf dict-crossover
          (find-crossover "Dictionaries (assoc)"
                          "benchmarks/fol-code/profitability-dict-bench.fol"
                          sizes))
    (terpri)
    (setf vector-crossover
          (find-crossover "Vectors (conj)"
                          "benchmarks/fol-code/profitability-vector-bench.fol"
                          sizes))

    (format t "~&--- Summary ---~%")
    (format t "Dictionary crossover size: ~A~%" (or dict-crossover "N/A"))
    (format t "Vector crossover size:     ~A~%" (or vector-crossover "N/A"))
    (format t "~%These results will be used to set the thresholds in the compiler.~%"))

  (values))

(main)
(uiop:quit)