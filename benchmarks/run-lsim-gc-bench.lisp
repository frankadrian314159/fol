(require :asdf)
(pushnew (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)
(asdf:load-system :fol-compiler/tests/lib)

;; Load simulation engines
(load "benchmarks/transpiled-fol-code/lsim.lisp")  ; FOL lsim engine
(load "benchmarks/lisp-code/lsim.lisp")             ; CL  lsim engine

;; Load GC pressure measurement infrastructure
(load "benchmarks/micro/lsim-gc-pressure.lisp")

;; NOTE: lsim-cl / lsim packages are created by the load forms above.
;; The IDE may report "package does not exist" on the lsim-cl:: / lsim::
;; references below because it reads the file before executing the loads;
;; this is a false positive identical to the one seen in run-32x32-bench.lisp.

(handler-case
    (progn
      (fol.benchmarks.lsim-gc:print-benchmark-header)

      ;; ----------------------------------------------------------
      ;; Warmup: load the smallest circuit and run once each to
      ;; trigger JIT compilation before timed measurements.
      ;; ----------------------------------------------------------
      (format t "~%Warming up...~%")
      (load "benchmarks/lisp-code/8bit-100.lisp")
      (load "benchmarks/transpiled-fol-code/8bit-100.lisp")
      (lsim-cl::run-bench)
      (lsim::run-bench)
      (sb-ext:gc :full t)
      (format t "Done.~%")

      ;; ----------------------------------------------------------
      ;; Per-circuit measurement.
      ;; Each circuit file redefines lsim-cl::run-bench / lsim::run-bench.
      ;; We load then immediately measure so the lambdas capture the
      ;; correct circuit at call time.
      ;; ----------------------------------------------------------
      (let ((results '()))

        ;; --- 8bit-100 ---
        (format t "~%--- 8bit-100 ---~%")
        (load "benchmarks/lisp-code/8bit-100.lisp")
        (load "benchmarks/transpiled-fol-code/8bit-100.lisp")
        (let ((r (fol.benchmarks.lsim-gc:measure-circuit
                  "8bit-100" 100
                  (lambda () (lsim-cl::run-bench))
                  (lambda () (lsim::run-bench))
                  10)))
          (fol.benchmarks.lsim-gc:print-circuit-report r)
          (push r results))

        ;; --- 32bit-300 ---
        (format t "~%--- 32bit-300 ---~%")
        (load "benchmarks/lisp-code/32bit-300.lisp")
        (load "benchmarks/transpiled-fol-code/32bit-300.lisp")
        (let ((r (fol.benchmarks.lsim-gc:measure-circuit
                  "32bit-300" 300
                  (lambda () (lsim-cl::run-bench))
                  (lambda () (lsim::run-bench))
                  10)))
          (fol.benchmarks.lsim-gc:print-circuit-report r)
          (push r results))

        ;; --- 8x32-900 ---
        (format t "~%--- 8x32-900 ---~%")
        (load "benchmarks/lisp-code/8x32-900.lisp")
        (load "benchmarks/transpiled-fol-code/8x32-900.lisp")
        (let ((r (fol.benchmarks.lsim-gc:measure-circuit
                  "8x32-900" 900
                  (lambda () (lsim-cl::run-bench))
                  (lambda () (lsim::run-bench))
                  5)))
          (fol.benchmarks.lsim-gc:print-circuit-report r)
          (push r results))

        ;; --- 32x32-3000 ---
        (format t "~%--- 32x32-3000 ---~%")
        (load "benchmarks/lisp-code/32x32-3000.lisp")
        (load "benchmarks/transpiled-fol-code/32x32-3000.lisp")
        (let ((r (fol.benchmarks.lsim-gc:measure-circuit
                  "32x32-3000" 3000
                  (lambda () (lsim-cl::run-bench))
                  (lambda () (lsim::run-bench))
                  3)))
          (fol.benchmarks.lsim-gc:print-circuit-report r)
          (push r results))

        (fol.benchmarks.lsim-gc:print-summary-table (nreverse results)))

      (format t "~%Done.~%"))

  (error (e)
    (format t "~%FATAL ERROR: ~A~%" e)
    (sb-debug:print-backtrace :count 20)
    (sb-ext:exit :code 1)))

(sb-ext:exit :code 0)
