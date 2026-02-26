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

(load "benchmarks/lisp-code/derived-value-invalidation.lisp")
(load "benchmarks/transpiled-fol-code/derived-value-invalidation.lisp")

(in-package :cl-user)

;; NOTE: the dvi-cl / derived-value-invalidation packages are created by the
;; load forms above.  IDE "package does not exist" warnings below are false
;; positives identical to those in run-lsim-gc-bench.lisp.

(defun run-benchmarks ()
  (let ((n-items 1000)
        (reads-per-item 1000))
    (format t "~%================================================================~%")
    (format t "  Derived-Value Invalidation Benchmark~%")
    (format t "  Pattern: cache :_total, clear on :items write~%")
    (format t "  CL:  invalidation coded manually in add-item~%")
    (format t "  FOL: :around assoc clears :_total automatically~%")
    (format t "  N = ~:D items, R = ~D reads/item (~:D total ops)~%"
            n-items reads-per-item (* n-items reads-per-item))
    (format t "================================================================~%")

    ;; Warmup
    (format t "~%Warming up...~%")
    (dvi-cl:run-bench 100 100)
    (derived-value-invalidation::run-bench 100 100)
    (sb-ext:gc :full t)
    (format t "Done.~%")

    ;; CL benchmark
    (format t "~%--- Common Lisp (manual cache invalidation in add-item) ---~%")
    (sb-ext:gc :full t)
    (let ((s1 (get-internal-real-time))
          (b1 (sb-ext:get-bytes-consed)))
      (let ((result1 (dvi-cl:run-bench n-items reads-per-item)))
        (let ((t1 (/ (- (get-internal-real-time) s1)
                     (float internal-time-units-per-second)))
              (m1 (- (sb-ext:get-bytes-consed) b1)))
          (format t "  Result:       ~D~%" result1)
          (format t "  Real Time:    ~,3F s~%" t1)
          (format t "  Bytes Consed: ~,2F MB~%" (/ m1 1048576.0))
          (format t "  Time/write:   ~,2F us~%"
                  (* (/ t1 n-items) 1e6))

          ;; FOL benchmark
          (format t "~%--- FOL (automatic :around assoc invalidation) ---~%")
          (sb-ext:gc :full t)
          (let ((s2 (get-internal-real-time))
                (b2 (sb-ext:get-bytes-consed)))
            (let ((result2 (derived-value-invalidation::run-bench
                            n-items reads-per-item)))
              (let ((t2 (/ (- (get-internal-real-time) s2)
                           (float internal-time-units-per-second)))
                    (m2 (- (sb-ext:get-bytes-consed) b2)))
                (format t "  Result:       ~D~%" result2)
                (format t "  Real Time:    ~,3F s~%" t2)
                (format t "  Bytes Consed: ~,2F MB~%" (/ m2 1048576.0))
                (format t "  Time/write:   ~,2F us~%"
                        (* (/ t2 n-items) 1e6))

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
