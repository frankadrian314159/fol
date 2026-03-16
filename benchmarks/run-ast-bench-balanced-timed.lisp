;;; Instrumented AST balanced-tree benchmark.
;;; Captures: (1) build time, (2) optimizer wall time, (3) allocation per phase,
;;; (4) GC real-time percentage, for both CL and FOL variants.
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
(load "benchmarks/lisp-code/ast-optimizer-balanced.lisp")

(defvar *fol-file*      "benchmarks/fol-code/ast-optimizer-balanced.fol")
(defvar *fol-lisp-file* "benchmarks/transpiled-fol-code/ast-optimizer-balanced.lisp")
(format t "Compiling FOL benchmark...~%")
(uiop:symbol-call :fol.compiler :compile-file *fol-file* :output *fol-lisp-file*)
(format t "Loading transpiled output...~%")
(load *fol-lisp-file*)
(format t "Loaded.~%")

(in-package :cl-user)

;;; GC-cycle counter via after-gc hook.
(defvar *gc-count* 0)
(push (lambda () (incf *gc-count*)) sb-ext:*after-gc-hooks*)

;;; Helper: returns (values wall-seconds bytes-consed gc-cycles)
(defmacro timed (&body body)
  (let ((g-t0 (gensym)) (g-b0 (gensym)) (g-gc0 (gensym)))
    `(let ((,g-t0  (get-internal-real-time))
           (,g-b0  (sb-ext:get-bytes-consed))
           (,g-gc0 *gc-count*))
       ,@body
       (values (/ (- (get-internal-real-time) ,g-t0)
                  (float internal-time-units-per-second))
               (- (sb-ext:get-bytes-consed) ,g-b0)
               (- *gc-count* ,g-gc0)))))

(defun run-benchmarks ()
  (let ((n 100))
    (format t "~%================================================================~%")
    (format t "  AST Optimizer Benchmark -- Balanced 9,999-node Tree~%")
    (format t "  Tree: near-perfect binary, depth 13, all 23 op types, 3 leaf types~%")
    (format t "  CL:  typecase + defstruct~%")
    (format t "  FOL: persistent objects + predicate dispatch~%")
    (format t "  N = ~:D optimizer passes after one-time tree build~%" n)
    (format t "  Total node visits per run: ~:D~%" (* n 9999))
    (format t "================================================================~%")

    ;;------------------------------------------------------------------
    ;; CL variant
    ;;------------------------------------------------------------------
    (format t "~%--- Common Lisp (defstruct + typecase) ---~%")

    ;; Build
    (sb-ext:gc :full t)
    (multiple-value-bind (bt bm bgc)
        (timed (setf (symbol-value '*cl-tree*)
                     (ast-opt-cl-balanced::build-balanced 9999 1)))
      (format t "  Build time:   ~,3F ms~%" (* bt 1000))
      (format t "  Build alloc:  ~,2F MB~%" (/ bm 1048576.0))
      (format t "  Build GC:     ~D cycle(s)~%" bgc)

      ;; Warmup optimizer
      (ast-opt-cl-balanced::walk (symbol-value '*cl-tree*))
      (sb-ext:gc :full t)

      ;; Optimizer passes
      (multiple-value-bind (ot om ogc)
          (timed (dotimes (i n)
                   (ast-opt-cl-balanced::walk (symbol-value '*cl-tree*))))
        (format t "  Optim time:   ~,3F s  (~,3F ms/pass)~%" ot (* (/ ot n) 1000))
        (format t "  Optim alloc:  ~,2F MB  (~,3F MB/pass)~%" (/ om 1048576.0) (/ om 1048576.0 n))
        (format t "  Optim GC:     ~D cycle(s)~%" ogc)

        ;;------------------------------------------------------------------
        ;; FOL variant
        ;;------------------------------------------------------------------
        (format t "~%--- FOL (persistent <ast-node> + predicate dispatch) ---~%")

        ;; Build
        (sb-ext:gc :full t)
        (multiple-value-bind (fbt fbm fbgc)
            (timed (setf (symbol-value '*fol-tree*)
                         (uiop:symbol-call :ast-opt-balanced :build-balanced 9999 1)))
          (format t "  Build time:   ~,3F ms~%" (* fbt 1000))
          (format t "  Build alloc:  ~,2F MB~%" (/ fbm 1048576.0))
          (format t "  Build GC:     ~D cycle(s)~%" fbgc)

          ;; Warmup optimizer
          (uiop:symbol-call :ast-opt-balanced :walk (symbol-value '*fol-tree*))
          (sb-ext:gc :full t)

          ;; Optimizer passes
          (multiple-value-bind (fot fom fogc)
              (timed (dotimes (i n)
                       (uiop:symbol-call :ast-opt-balanced :walk (symbol-value '*fol-tree*))))
            (format t "  Optim time:   ~,3F s  (~,3F ms/pass)~%" fot (* (/ fot n) 1000))
            (format t "  Optim alloc:  ~,2F MB  (~,3F MB/pass)~%" (/ fom 1048576.0) (/ fom 1048576.0 n))
            (format t "  Optim GC:     ~D cycle(s)~%" fogc)

            ;;------------------------------------------------------------------
            ;; Summary
            ;;------------------------------------------------------------------
            (format t "~%--- Summary ---~%")
            (format t "  Build  time ratio  (FOL/CL): ~,1Fx~%"
                    (if (> bt 0) (/ fbt bt) 0.0))
            (format t "  Build  mem  ratio  (FOL/CL): ~,1Fx~%"
                    (if (> bm 0) (/ (float fbm) (float bm)) 0.0))
            (format t "  Optim  time ratio  (FOL/CL): ~,1Fx~%"
                    (if (> ot 0) (/ fot ot) 0.0))
            (format t "  Optim  mem  ratio  (FOL/CL): ~,1Fx~%"
                    (if (> om 0) (/ (float fom) (float om)) 0.0))
            (format t "  Nodes / optim pass: 9,999~%")
            (format t "  CL  ns/node:  ~,1F~%" (* 1e9 (/ ot (* n 9999))))
            (format t "  FOL ns/node:  ~,1F~%" (* 1e9 (/ fot (* n 9999)))))))))

  (format t "~%Done.~%"))

(defvar *cl-tree*  nil)
(defvar *fol-tree* nil)

(handler-case
    (run-benchmarks)
  (error (e)
    (format t "~%FATAL ERROR: ~A~%" e)
    (sb-debug:print-backtrace :count 20)
    (sb-ext:exit :code 1)))

(sb-ext:exit :code 0)
