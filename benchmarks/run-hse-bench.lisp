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

(load "benchmarks/lisp-code/hierarchical-speculative-execution.lisp")
(load "benchmarks/transpiled-fol-code/hierarchical-speculative-execution.lisp")

(in-package :cl-user)

;; NOTE: the hse / hse-cl packages are created by the load forms above.
;; The IDE may report "package does not exist" on hse:: / hse-cl:: references
;; below -- this is a false positive identical to the one in run-guards-bench.lisp.

(defun run-benchmarks ()
  (let ((n 1000000))
    (format t "~%================================================================~%")
    (format t "  Hierarchical Speculative Execution Benchmark~%")
    (format t "  Constraints: non-negative (L1), balance cap (L2), tx cap (L3)~%")
    (format t "  CL:  all three validation levels coded flat in one function~%")
    (format t "  FOL: each class contributes one :around assoc method,~%")
    (format t "       composed automatically via call-next-method~%")
    (format t "  N = ~:D valid deposits of 1 unit each~%" n)
    (format t "================================================================~%")

    ;; Warmup
    (format t "~%Warming up...~%")
    (hse-cl:run-bench 10000)
    (hse::run-bench 10000)
    (sb-ext:gc :full t)
    (format t "Done.~%")

    ;; CL benchmark
    (format t "~%--- Common Lisp (all constraints in one flat function) ---~%")
    (sb-ext:gc :full t)
    (let ((s1 (get-internal-real-time))
          (b1 (sb-ext:get-bytes-consed)))
      (let ((result1 (hse-cl:run-bench n)))
        (let ((t1 (/ (- (get-internal-real-time) s1)
                     (float internal-time-units-per-second)))
              (m1 (- (sb-ext:get-bytes-consed) b1)))
          (format t "  Result:       ~D (expected ~D)~%" result1 n)
          (format t "  Real Time:    ~,3F s~%" t1)
          (format t "  Bytes Consed: ~,2F MB~%" (/ m1 1048576.0))
          (format t "  Time/op:      ~,2F us~%" (* (/ t1 n) 1e6))

          ;; FOL benchmark
          (format t "~%--- FOL (three :around methods composed via call-next-method) ---~%")
          (sb-ext:gc :full t)
          (let ((s2 (get-internal-real-time))
                (b2 (sb-ext:get-bytes-consed)))
            (let ((result2 (hse::run-bench n)))
              (let ((t2 (/ (- (get-internal-real-time) s2)
                           (float internal-time-units-per-second)))
                    (m2 (- (sb-ext:get-bytes-consed) b2)))
                (format t "  Result:       ~D (expected ~D)~%" result2 n)
                (format t "  Real Time:    ~,3F s~%" t2)
                (format t "  Bytes Consed: ~,2F MB~%" (/ m2 1048576.0))
                (format t "  Time/op:      ~,2F us~%" (* (/ t2 n) 1e6))

                (format t "~%--- Comparison (FOL / CL) ---~%")
                (format t "  Time Ratio:   ~,2Fx~%"
                        (if (> t1 0) (/ t2 t1) 0))
                (format t "  Memory Ratio: ~,2Fx~%"
                        (if (> m1 0) (/ (float m2) (float m1)) 0))
                (if (= result1 result2)
                    (format t "  Correctness:  PASS (both return ~D)~%" result1)
                    (format t "  Correctness:  FAIL (CL=~D, FOL=~D)~%"
                            result1 result2)))))))))

  (format t "~%Done.~%"))

(handler-case
    (run-benchmarks)
  (error (e)
    (format t "~%FATAL ERROR: ~A~%" e)
    (sb-debug:print-backtrace :count 20)
    (sb-ext:exit :code 1)))

(sb-ext:exit :code 0)
