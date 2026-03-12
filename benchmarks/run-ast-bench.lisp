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

(load "benchmarks/lisp-code/ast-optimizer.lisp")

(defvar *fol-file* "benchmarks/fol-code/ast-optimizer.fol")
(defvar *fol-lisp-file* "benchmarks/transpiled-fol-code/ast-optimizer.lisp")
(format t "Compiling FOL benchmark...~%")
(uiop:symbol-call :fol.compiler :compile-file *fol-file* :output *fol-lisp-file*)
(format t "Loading transpiled output...~%")
(load *fol-lisp-file*)
(format t "Loaded.~%")

(in-package :cl-user)

(defun run-benchmarks ()
  (let ((n 10000))
    (format t "~%================================================================~%")
    (format t "  AST Optimizer Benchmark~%")
    (format t "  Mechanism: Recursive walk and rewrite across 25 nodes / 50 rules~%")
    (format t "  CL:  typecase + defstruct~%")
    (format t "  FOL: persistent objects + predicate dispatch~%")
    (format t "  N = ~:D iterations of tree walks~%" n)
    (format t "================================================================~%")

    ;; Warmup
    (format t "~%Warming up...~%")
    (ast-opt-cl::run-bench 1)
    (ast-opt::run-bench 1)
    (sb-ext:gc :full t)
    (format t "Done.~%")

    ;; CL benchmark
    (format t "~%--- Common Lisp (defstruct + typecase) ---~%")
    (sb-ext:gc :full t)
    (let ((s1 (get-internal-real-time))
          (b1 (sb-ext:get-bytes-consed)))
      (ast-opt-cl::run-bench n)
      (let ((t1 (/ (- (get-internal-real-time) s1)
                   (float internal-time-units-per-second)))
            (m1 (- (sb-ext:get-bytes-consed) b1)))
        (format t "  Real Time:    ~,3F s~%" t1)
        (format t "  Bytes Consed: ~,2F MB~%" (/ m1 1048576.0))
        (format t "  Time/op:      ~,2F ms~%" (* (/ t1 n) 1000.0))

        ;; FOL benchmark
        (format t "~%--- FOL (persistent <ast-node> + predicate dispatch) ---~%")
        (sb-ext:gc :full t)
        (let ((s2 (get-internal-real-time))
              (b2 (sb-ext:get-bytes-consed)))
          (ast-opt::run-bench n)
          (let ((t2 (/ (- (get-internal-real-time) s2)
                       (float internal-time-units-per-second)))
                (m2 (- (sb-ext:get-bytes-consed) b2)))
            (format t "  Real Time:    ~,3F s~%" t2)
            (format t "  Bytes Consed: ~,2F MB~%" (/ m2 1048576.0))
            (format t "  Time/op:      ~,2F ms~%" (* (/ t2 n) 1000.0))

            (format t "~%--- Comparison (FOL / CL) ---~%")
            (format t "  Time Ratio:   ~,2Fx~%"
              (if (> t1 0) (/ t2 t1) 0))
            (format t "  Memory Ratio: ~,2Fx~%"
              (if (> m1 0) (/ (float m2) (float m1)) 0)))))))

  (format t "~%Done.~%"))

(handler-case
    (run-benchmarks)
  (error (e)
    (format t "~%FATAL ERROR: ~A~%" e)
    (sb-debug:print-backtrace :count 20)
    (sb-ext:exit :code 1)))

(sb-ext:exit :code 0)
