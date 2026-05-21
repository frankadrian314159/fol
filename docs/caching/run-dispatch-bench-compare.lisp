;; Dispatch caching benchmark comparison runner
;; Compiles and runs both FOL (with caching) and CL (without caching) versions
;; Provides side-by-side performance comparison

(defun slurp (stream)
  "Read entire file contents as string"
  (let ((seq (make-string (file-length stream))))
    (read-sequence seq stream)
    seq))

(push #p"c:/Users/frank/Projects/FOL/fol/src/" asdf:*central-registry*)

(format t "~&========================================~%")
(format t "  Dispatch Caching Performance Benchmark~%")
(format t "========================================~%~%")

(format t "Loading FOL compiler...~%")
(asdf:load-system :fol-compiler)
(asdf:load-system :fol-compiler/core)

;; ============================================================
;; MICRO-BENCHMARK: Tight loop with homogeneous types
;; ============================================================
(format t "~%========== MICRO-BENCHMARK ==========~%")
(format t "Test: 1M iterations of polymorphic dispatch on homogeneous types~%")
(format t "Expected: Cache hits on every call after first miss~%~%")

(format t "~%--- FOL Version (WITH caching) ---~%")
(let* ((fol-file #p"c:/Users/frank/Projects/FOL/fol/benchmarks/dispatch-micro-bench.fol")
       (code (with-open-file (s fol-file) (slurp s)))
       (result (fol.repl:compile-fol-string code)))
  (format t "Compiling...~%")
  (eval (fol.compiler:compilation-result-code result)))

(format t "~%--- CL Version (WITHOUT caching) ---~%")
(load "c:/Users/frank/Projects/FOL/fol/benchmarks/dispatch-micro-bench-cl.lisp")

;; ============================================================
;; REALISTIC BENCHMARK: Tree normalization
;; ============================================================
(format t "~%========== REALISTIC BENCHMARK ==========~%")
(format t "Test: 100 tree walks over depth-5 mixed-type tree~%")
(format t "Expected: Cache hits on normalization dispatch~%~%")

(format t "~%--- FOL Version (WITH caching) ---~%")
(let* ((fol-file #p"c:/Users/frank/Projects/FOL/fol/benchmarks/dispatch-realistic-bench.fol")
       (code (with-open-file (s fol-file) (slurp s)))
       (result (fol.repl:compile-fol-string code)))
  (format t "Compiling...~%")
  (eval (fol.compiler:compilation-result-code result)))

(format t "~%--- CL Version (WITHOUT caching) ---~%")
(load "c:/Users/frank/Projects/FOL/fol/benchmarks/dispatch-realistic-bench-cl.lisp")

(format t "~%========================================~%")
(format t "  Benchmark Complete~%")
(format t "========================================~%")
(format t "~%Note: FOL times include compilation overhead~%")
(format t "      Run each benchmark 2-3 times for consistent results~%~%")

(sb-ext:quit :unix-status 0)
