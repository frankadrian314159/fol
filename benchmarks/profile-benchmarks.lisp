;;; Profiling script for FOL benchmarks
;;; Usage: sbcl --noinform --non-interactive --load profile-benchmarks.lisp

(require :sb-profile)

(defpackage :fol-profiler
  (:use :cl :sb-profile))

(in-package :fol-profiler)

(format t "~%=== FOL Benchmark Profiling ===~%~%")

;; Helper to run a benchmark with profiling
(defun run-benchmark-with-profile (name file-path &key (reset t))
  (format t "~%--- Running: ~A ---~%" name)
  (when reset
    (sb-profile:reset))

  ;; Load and run the benchmark
  (with-open-file (s file-path)
    (let ((code (read s)))
      (eval code)))

  ;; Print profiling results
  (format t "~%Profiling results for ~A:~%" name)
  (sb-profile:report :max-samples 50)
  (format t "~%"))

;; Profile the key benchmarks
(format t "Starting profiling run...~%")

;; Try to profile diff benchmark
(handler-case
    (run-benchmark-with-profile "Diff Benchmark" "run-diff-bench.lisp")
  (error (e)
    (format t "Diff benchmark error: ~A~%" e)))

;; Try to profile guards benchmark
(handler-case
    (run-benchmark-with-profile "Guards Benchmark" "run-guards-bench.lisp")
  (error (e)
    (format t "Guards benchmark error: ~A~%" e)))

;; Try to profile derived-value-invalidation benchmark
(handler-case
    (run-benchmark-with-profile "Derived Value Invalidation" "run-derived-value-invalidation-bench.lisp")
  (error (e)
    (format t "Derived value invalidation benchmark error: ~A~%" e)))

(format t "~%=== Profiling Complete ===~%")
(quit)
