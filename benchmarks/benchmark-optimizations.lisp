;;; Benchmark all three optimization techniques across diff, guards, and DVI
(require :asdf)

(pushnew #p"c:/Users/frank/Projects/FOL/fol/src/" asdf:*central-registry*)

(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file quicklisp-init)
      (load quicklisp-init)
      (format t "Quicklisp not found.~%")))

(dolist (dep '(:fset :sycamore :closer-mop :uuid :bordeaux-threads :usocket :cl-ppcre :fiveam))
  (if (find-package :ql)
      (uiop:symbol-call :ql :quickload dep)
      (asdf:load-system dep)))

(asdf:load-system :fol-compiler)

(in-package :cl-user)

(format t "~%========================================================================~%")
(format t "           FOL Performance Optimization Benchmark Suite~%")
(format t "========================================================================~%")

;;; Helper function to run benchmark and measure time/memory
(defun run-and-measure (name fn)
  (sb-ext:gc :full t)
  (let ((start (get-internal-real-time))
        (start-bytes (sb-ext:get-bytes-consed)))
    (funcall fn)
    (let* ((end (get-internal-real-time))
           (end-bytes (sb-ext:get-bytes-consed))
           (elapsed (/ (- end start) (float internal-time-units-per-second)))
           (bytes (- end-bytes start-bytes)))
      (format t "  ~A: ~,3F seconds, ~,2F MB~%" name elapsed (/ bytes 1048576.0))
      (list name elapsed bytes))))

;;; =========================================================================
;;; DIFF BENCHMARK
;;; =========================================================================

(format t "~%~%=== DIFF BENCHMARK (100K iterations) ===~%")
(load "c:/Users/frank/Projects/FOL/fol/benchmarks/lisp-code/diff.lisp")
(load "c:/Users/frank/Projects/FOL/fol/benchmarks/transpiled-fol-code/diff.lisp")

;; Warmup
(format t "Warming up...~%")
(diff-cl:run-bench 10000)
(diff::run-bench 10000)

;; Baseline (no optimization)
(format t "~%Baseline (CL reference):~%")
(run-and-measure "CL" (lambda () (diff-cl:run-bench 100000)))

(format t "~%Baseline (FOL - with :around dispatch):~%")
(run-and-measure "FOL" (lambda () (diff::run-bench 100000)))

;; Optimized with pragma
(format t "~%Optimized (FOL with pragma enabled):~%")
(fol.compiler::enable-inline-methods t)
(run-and-measure "FOL+pragma" (lambda () (diff::run-bench 100000)))
(fol.compiler::disable-inline-methods)

;;; =========================================================================
;;; GUARDS BENCHMARK
;;; =========================================================================

(format t "~%~%=== GUARDS BENCHMARK (10K iterations) ===~%")
(load "c:/Users/frank/Projects/FOL/fol/benchmarks/lisp-code/guards.lisp")
(load "c:/Users/frank/Projects/FOL/fol/benchmarks/transpiled-fol-code/guards.lisp")

;; Warmup
(format t "Warming up...~%")
(guards-cl:run-bench 1000)
(guards::run-bench 1000)

;; Baseline (CL reference)
(format t "~%Baseline (CL reference):~%")
(run-and-measure "CL" (lambda () (guards-cl:run-bench 10000)))

;; Baseline (FOL default)
(format t "~%Baseline (FOL - with :around dispatch):~%")
(run-and-measure "FOL" (lambda () (guards::run-bench 10000)))

;; Optimized with pragma
(format t "~%Optimized (FOL with pragma enabled):~%")
(fol.compiler::enable-inline-methods t)
(run-and-measure "FOL+pragma" (lambda () (guards::run-bench 10000)))
(fol.compiler::disable-inline-methods)

;;; =========================================================================
;;; DERIVED VALUE INVALIDATION BENCHMARK
;;; =========================================================================

(format t "~%~%=== DERIVED VALUE INVALIDATION BENCHMARK (1000 items, 10 reads) ===~%")
(load "c:/Users/frank/Projects/FOL/fol/benchmarks/lisp-code/derived-value-invalidation.lisp")
(load "c:/Users/frank/Projects/FOL/fol/benchmarks/transpiled-fol-code/derived-value-invalidation.lisp")

;; Warmup
(format t "Warming up...~%")
(dvi-cl:run-bench 100 10)
(derived-value-invalidation::run-bench 100 10)

;; Baseline (CL reference)
(format t "~%Baseline (CL reference):~%")
(run-and-measure "CL" (lambda () (dvi-cl:run-bench 1000 10)))

;; Baseline (FOL default)
(format t "~%Baseline (FOL - with :around dispatch):~%")
(run-and-measure "FOL" (lambda () (derived-value-invalidation::run-bench 1000 10)))

;; Optimized with pragma
(format t "~%Optimized (FOL with pragma enabled):~%")
(fol.compiler::enable-inline-methods t)
(run-and-measure "FOL+pragma" (lambda () (derived-value-invalidation::run-bench 1000 10)))
(fol.compiler::disable-inline-methods)

;;; =========================================================================
;;; SUMMARY
;;; =========================================================================

(format t "~%~%========================================================================~%")
(format t "                          SUMMARY~%")
(format t "========================================================================~%")
(format t "~%All measurements complete. Compare results above to calculate speedups.~%~%")
(format t "Expected optimizations:~%")
(format t "  - Diff: 5-10× speedup from pragma (114× baseline → 11-23×)~%")
(format t "  - Guards: 2-3× speedup from pragma (20× baseline → 7-10×)~%")
(format t "  - DVI: 1.5-2× speedup from pragma (15× baseline → 8-10×)~%~%")

(sb-ext:exit :code 0)
