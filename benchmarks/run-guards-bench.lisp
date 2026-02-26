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

(load "benchmarks/lisp-code/guards.lisp")
(load "benchmarks/transpiled-fol-code/guards.lisp")

(in-package :cl-user)

;; NOTE: the guards / guards-cl packages are created by the load forms above.
;; The IDE may report "package does not exist" on guards:: / guards-cl:: references
;; below because it reads the file before executing the loads; this is a false
;; positive identical to the one in run-lsim-gc-bench.lisp.

(defun run-benchmarks ()
  (let ((n 1000000))
    (format t "~%================================================================~%")
    (format t "  Guards Pattern Benchmark~%")
    (format t "  Invariant: balance >= 0 on every update~%")
    (format t "  CL:  guard coded manually in each update function~%")
    (format t "  FOL: single :around assoc method, fires automatically~%")
    (format t "  N = ~:D valid deposits~%" n)
    (format t "================================================================~%")

    ;; Warmup
    (format t "~%Warming up...~%")
    (guards-cl:run-bench 10000)
    (guards::run-bench 10000)
    (sb-ext:gc :full t)
    (format t "Done.~%")

    ;; CL benchmark
    (format t "~%--- Common Lisp (manual guard in each update function) ---~%")
    (sb-ext:gc :full t)
    (let ((s1 (get-internal-real-time))
          (b1 (sb-ext:get-bytes-consed)))
      (let ((result1 (guards-cl:run-bench n)))
        (let ((t1 (/ (- (get-internal-real-time) s1)
                     (float internal-time-units-per-second)))
              (m1 (- (sb-ext:get-bytes-consed) b1)))
          (format t "  Result:       ~D~%" result1)
          (format t "  Real Time:    ~,3F s~%" t1)
          (format t "  Bytes Consed: ~,2F MB~%" (/ m1 1048576.0))
          (format t "  Time/op:      ~,2F us~%" (* (/ t1 n) 1e6))

          ;; FOL benchmark
          (format t "~%--- FOL (automatic :around assoc guard) ---~%")
          (sb-ext:gc :full t)
          (let ((s2 (get-internal-real-time))
                (b2 (sb-ext:get-bytes-consed)))
            (let ((result2 (guards::run-bench n)))
              (let ((t2 (/ (- (get-internal-real-time) s2)
                           (float internal-time-units-per-second)))
                    (m2 (- (sb-ext:get-bytes-consed) b2)))
                (format t "  Result:       ~D~%" result2)
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
