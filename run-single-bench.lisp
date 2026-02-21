(require :asdf)
(pushnew (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(load "benchmarks/transpiled-fol-code/lsim.lisp")
(load "benchmarks/transpiled-fol-code/plsim.lisp")
(load "benchmarks/lisp-code/lsim.lisp")

(load "benchmarks/lisp-code/8x32-900.lisp")
(load "benchmarks/transpiled-fol-code/8x32-900.lisp")
(load "benchmarks/transpiled-fol-code/8x32-900-p.lisp")

(defun run-once (name cl-fn fol-fn pfol-fn)
  (format t "Benchmark: ~A~%" name)
  (let ((start (get-internal-run-time)))
    (funcall cl-fn)
    (format t "  CL:    ~F s~%" (/ (/ (float (- (get-internal-run-time) start)) 1) internal-time-units-per-second)))
  (let ((start (get-internal-run-time)))
    (funcall fol-fn)
    (format t "  FOL:   ~F s~%" (/ (/ (float (- (get-internal-run-time) start)) 1) internal-time-units-per-second)))
  (let ((start (get-internal-run-time)))
    (funcall pfol-fn)
    (format t "  PLSim: ~F s~%" (/ (/ (float (- (get-internal-run-time) start)) 1) internal-time-units-per-second))))

(run-once "8x32-900" 
          (lambda () (lsim-cl::run-bench))
          (lambda () (lsim::run-bench))
          (lambda () (plsim::run-bench)))

(sb-ext:exit)
