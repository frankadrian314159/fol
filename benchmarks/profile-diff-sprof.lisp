;;; Profile the Diff benchmark using SBCL's statistical profiler
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

(load "c:/Users/frank/Projects/FOL/fol/benchmarks/lisp-code/diff.lisp")
(load "c:/Users/frank/Projects/FOL/fol/benchmarks/transpiled-fol-code/diff.lisp")

(in-package :cl-user)

(format t "~%=== Profiling Diff Benchmark with Statistical Profiler ===~%")
(format t "Note: This uses SBCL's statistical profiler (sb-sprof)~%~%")

;; Warmup
(format t "Warming up...~%")
(diff::run-bench 10000)
(sb-ext:gc :full t)

;; Use SBCL's built-in time macro to measure
(format t "~%Running FOL benchmark (100K iterations) with timing...~%~%")
(time (diff::run-bench 100000))

;; Measure CL version for comparison
(format t "~%~%--- Common Lisp Baseline (for comparison) ---~%")
(sb-ext:gc :full t)
(let ((start (get-internal-real-time))
      (start-bytes (sb-ext:get-bytes-consed)))
  (diff-cl:run-bench 100000)
  (let* ((end (get-internal-real-time))
         (end-bytes (sb-ext:get-bytes-consed))
         (elapsed (/ (- end start) (float internal-time-units-per-second)))
         (bytes (- end-bytes start-bytes)))
    (format t "Completed in ~,3F seconds~%" elapsed)
    (format t "Bytes consed: ~,2F MB~%" (/ bytes 1048576.0))))

(format t "~%~%Done.~%")
(sb-ext:exit :code 0)
