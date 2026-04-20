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

(asdf:load-system :fol-compiler/core)

(load "benchmarks/lisp-code/interpreter.lisp")

(defvar *fol-file*      "benchmarks/fol-code/interpreter.fol")
(defvar *fol-lisp-file* "benchmarks/transpiled-fol-code/interpreter.lisp")
(format t "Compiling FOL benchmark...~%")
(uiop:symbol-call :fol.compiler :compile-file *fol-file* :output *fol-lisp-file*)
(format t "Loading transpiled output...~%")
(load *fol-lisp-file*)
(format t "Loaded.~%")

(in-package :cl-user)

(defun run-benchmarks ()
  (let ((build-n    50)
        (build-depth 5)
        (iter-n    1000))

    (format t "~%================================================================~%")
    (format t "  Expression Interpreter — CLOS Adoption Cost Benchmark~%")
    (format t "~%  Purpose: measure the cost of porting a typical CLOS codebase~%")
    (format t "           to FOL (persistent objects + predicate dispatch).~%")
    (format t "~%  CL:  standard CLOS (defclass, defgeneric, defmethod)~%")
    (format t "       mutable hash-table environment, shadow-and-restore for let~%")
    (format t "  FOL: persistent objects (MOP metaclass)~%")
    (format t "       persistent dict environment, functional assoc for let~%")
    (format t "~%  Corpus: ~D depth-~D expression trees, covering all 7 node types~%"
            build-n build-depth)
    (format t "  3 generic functions per expression: eval-expr, pretty, free-vars~%")
    (format t "  N = ~:D iterations~%" iter-n)
    (format t "================================================================~%")

    ;; --- Build Phase ---------------------------------------------------------
    (format t "~%--- Build Phase (construct ~D expression trees, depth ~D) ---~%"
            build-n build-depth)

    (sb-ext:gc :full t)
    (let* ((s-cl  (get-internal-real-time))
           (b-cl  (sb-ext:get-bytes-consed))
           (dummy (uiop:symbol-call :interp-cl :build-corpus build-n build-depth))
           (t-cl  (/ (- (get-internal-real-time) s-cl)
                     (float internal-time-units-per-second)))
           (m-cl  (- (sb-ext:get-bytes-consed) b-cl)))
      (declare (ignore dummy))
      (format t "  CL  build: ~,2F ms / ~,2F MB~%"
              (* t-cl 1000.0) (/ m-cl 1048576.0))

      (sb-ext:gc :full t)
      (let* ((s-fol  (get-internal-real-time))
             (b-fol  (sb-ext:get-bytes-consed))
             (dummy2 (uiop:symbol-call :interp-fol :build-corpus build-n build-depth))
             (t-fol  (/ (- (get-internal-real-time) s-fol)
                        (float internal-time-units-per-second)))
             (m-fol  (- (sb-ext:get-bytes-consed) b-fol)))
        (declare (ignore dummy2))
        (format t "  FOL build: ~,2F ms / ~,2F MB~%"
                (* t-fol 1000.0) (/ m-fol 1048576.0))
        (format t "  Build ratio (FOL/CL): ~,1Fx time, ~,1Fx memory~%"
                (if (> t-cl 0) (/ t-fol t-cl) 0)
                (if (> m-cl 0) (/ (float m-fol) (float m-cl)) 0))))

    ;; --- Warmup --------------------------------------------------------------
    (format t "~%Warming up...~%")
    (uiop:symbol-call :interp-cl  :run-bench 1)
    (uiop:symbol-call :interp-fol :run-bench 1)
    (sb-ext:gc :full t)
    (format t "Done.~%")

    ;; --- Eval Phase ----------------------------------------------------------
    (format t "~%--- Eval Phase (~:D iters × ~D exprs × 3 generic functions) ---~%"
            iter-n build-n)

    (sb-ext:gc :full t)
    (let ((s1 (get-internal-real-time))
          (b1 (sb-ext:get-bytes-consed)))
      (uiop:symbol-call :interp-cl :run-bench iter-n)
      (let ((t1 (/ (- (get-internal-real-time) s1)
                   (float internal-time-units-per-second)))
            (m1 (- (sb-ext:get-bytes-consed) b1)))

        (format t "~%  CL  (CLOS generic dispatch + mutable hash-table env)~%")
        (format t "    Total time:   ~,3F s~%" t1)
        (format t "    Bytes consed: ~,2F MB~%" (/ m1 1048576.0))
        (format t "    Time/expr:    ~,2F µs~%"
                (* (/ t1 (* iter-n build-n)) 1e6))

        (sb-ext:gc :full t)
        (let ((s2 (get-internal-real-time))
              (b2 (sb-ext:get-bytes-consed)))
          (uiop:symbol-call :interp-fol :run-bench iter-n)
          (let ((t2 (/ (- (get-internal-real-time) s2)
                       (float internal-time-units-per-second)))
                (m2 (- (sb-ext:get-bytes-consed) b2)))

            (format t "~%  FOL (predicate dispatch + persistent dict env)~%")
            (format t "    Total time:   ~,3F s~%" t2)
            (format t "    Bytes consed: ~,2F MB~%" (/ m2 1048576.0))
            (format t "    Time/expr:    ~,2F µs~%"
                    (* (/ t2 (* iter-n build-n)) 1e6))

            (format t "~%--- Comparison (FOL / CL) ---~%")
            (format t "  Time ratio:   ~,2Fx~%"
                    (if (> t1 0) (/ t2 t1) 0))
            (format t "  Memory ratio: ~,2Fx~%"
                    (if (> m1 0) (/ (float m2) (float m1)) 0)))))))

  (format t "~%Done.~%"))

(handler-case
    (run-benchmarks)
  (error (e)
    (format t "~%FATAL ERROR: ~A~%" e)
    (sb-debug:print-backtrace :count 20)
    (sb-ext:exit :code 1)))

(sb-ext:exit :code 0)
