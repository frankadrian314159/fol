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

;; Try to use statistical profiler if available
(handler-case
    (progn
      (require :sb-sprof)
      (format t "~%~%=== Statistical Profiler Report ===~%")
      (sb-sprof:reset)
      (sb-sprof:start-profiling :max-samples 10000 :mode :time)
      (diff::run-bench 50000)
      (sb-sprof:stop-profiling)
      (format t "~%Top hotspots (by sample count):~%")
      (sb-sprof:report :type :flat :max-samples 30))
  (error (e)
    (format t "~%Statistical profiler not available: ~A~%~%Falling back to heap allocation tracking...~%" e)
    (format t "Running benchmark again to measure heap usage...~%")
    (sb-ext:gc :full t)
    (let ((start-bytes (sb-ext:get-bytes-consed)))
      (diff::run-bench 50000)
      (let ((bytes-consed (- (sb-ext:get-bytes-consed) start-bytes)))
        (format t "Heap consed: ~,2F MB~%" (/ bytes-consed 1048576.0))))))

(format t "~%~%Done.~%")
(sb-ext:exit :code 0)
