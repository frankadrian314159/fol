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

(load "benchmarks/lisp-code/diff.lisp")
(load "benchmarks/transpiled-fol-code/diff.lisp")

(in-package :cl-user)

;; NOTE: the diff / diff-cl packages are created by the load forms above.
;; The IDE may report "package does not exist" on diff:: / diff-cl:: references
;; below -- this is a false positive identical to the one in run-guards-bench.lisp.

(defun run-benchmarks ()
  (let ((n 500000))
    (format t "~%================================================================~%")
    (format t "  Structural Diff Pattern Benchmark~%")
    (format t "  Mechanism: :around assoc compares PRE and POST snapshots~%")
    (format t "  CL:  explicit before-snapshot + per-slot comparison in caller~%")
    (format t "  FOL: single :around assoc method on <diffable>, zero domain boilerplate~%")
    (format t "  N = ~:D iterations x 5 slot updates~%" n)
    (format t "================================================================~%")

    ;; Warmup
    (format t "~%Warming up...~%")
    (diff-cl:run-bench 10000)
    (diff::run-bench 10000)
    (sb-ext:gc :full t)
    (format t "Done.~%")

    ;; CL benchmark
    (format t "~%--- Common Lisp (explicit before-snapshot + per-slot comparison) ---~%")
    (sb-ext:gc :full t)
    (let ((s1 (get-internal-real-time))
          (b1 (sb-ext:get-bytes-consed)))
      (let ((result1 (diff-cl:run-bench n)))
        (let ((t1 (/ (- (get-internal-real-time) s1)
                     (float internal-time-units-per-second)))
              (m1 (- (sb-ext:get-bytes-consed) b1)))
          (format t "  Result:       ~D (expected ~D)~%" result1 (* 5 n))
          (format t "  Real Time:    ~,3F s~%" t1)
          (format t "  Bytes Consed: ~,2F MB~%" (/ m1 1048576.0))
          (format t "  Time/op:      ~,2F us~%" (* (/ t1 n) 1e6))

          ;; FOL benchmark
          (format t "~%--- FOL (:around assoc auto-detects changes via persistent snapshots) ---~%")
          (sb-ext:gc :full t)
          (let ((s2 (get-internal-real-time))
                (b2 (sb-ext:get-bytes-consed)))
            (let ((result2 (diff::run-bench n)))
              (let ((t2 (/ (- (get-internal-real-time) s2)
                           (float internal-time-units-per-second)))
                    (m2 (- (sb-ext:get-bytes-consed) b2)))
                (format t "  Result:       ~D (expected ~D)~%" result2 (* 5 n))
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
