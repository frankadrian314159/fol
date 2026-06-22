;;; Profile the Diff benchmark to find hotspots
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

(format t "~%=== Profiling Diff Benchmark ===~%")
(format t "Profiling FOL version (slower path)...~%~%")

;; Warmup
(format t "Warming up...~%")
(diff::run-bench 10000)
(sb-ext:gc :full t)

;; Profile the FOL version with basic time/statistics
(format t "Running FOL benchmark with time tracking (100K iterations)...~%")
(sb-ext:gc :full t)

(let ((start (get-internal-real-time))
      (start-bytes (sb-ext:get-bytes-consed)))
  (diff::run-bench 100000)
  (let* ((end (get-internal-real-time))
         (end-bytes (sb-ext:get-bytes-consed))
         (elapsed (/ (- end start) (float internal-time-units-per-second)))
         (bytes (- end-bytes start-bytes)))
    (format t "Completed in ~,3F seconds~%" elapsed)
    (format t "Bytes consed: ~,2F MB~%" (/ bytes 1048576.0))))

(sb-ext:exit :code 0)
