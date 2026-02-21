(require :asdf)
(pushnew (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)
(asdf:load-system :fol-compiler/tests/lib)

;; Load LSim (Serial FOL)
(load "benchmarks/transpiled-fol-code/lsim.lisp")
;; Load PLSim (Parallel FOL)
(load "benchmarks/transpiled-fol-code/plsim.lisp")
;; Load CL version
(load "benchmarks/lisp-code/lsim.lisp")

(defparameter *iterations* 3)

(defun run-benchmark (name cl-fn fol-fn pfol-fn)
  (format t "----------------------------------------------------~%")
  (format t "Benchmark: ~A~%" name)
  
  ;; CL Run
  (let ((cl-time 0))
    (dotimes (i *iterations*)
      (let ((start (get-internal-run-time)))
        (funcall cl-fn)
        (incf cl-time (- (get-internal-run-time) start))))
    (let ((avg (/ (/ (float cl-time) *iterations*) internal-time-units-per-second)))
      (format t "  CL Average:   ~F s~%" avg)
      
      ;; FOL Run
      (let ((fol-time 0))
        (dotimes (i *iterations*)
          (let ((start (get-internal-run-time)))
            (funcall fol-fn)
            (incf fol-time (- (get-internal-run-time) start))))
        (let ((fol-avg (/ (/ (float fol-time) *iterations*) internal-time-units-per-second)))
          (format t "  FOL Average:  ~F s (Ratio CL: ~F)~%" fol-avg (/ fol-avg avg))
          
          ;; PLSIM Run
          (let ((pfol-time 0))
            (dotimes (i *iterations*)
              (let ((start (get-internal-run-time)))
                (funcall pfol-fn)
                (incf pfol-time (- (get-internal-run-time) start))))
            (let ((pfol-avg (/ (/ (float pfol-time) *iterations*) internal-time-units-per-second)))
              (format t "  PLSim Average: ~F s (Ratio CL: ~F, Speedup: ~F)~%" 
                      pfol-avg (/ pfol-avg avg) (/ fol-avg pfol-avg))
              (list avg fol-avg pfol-avg))))))))

;; Load circuit files for each implementation
(format t "Loading circuit definitions...~%")

(defparameter results '())

(handler-case
    (progn
      ;; 8-bit Register
      (load "benchmarks/lisp-code/8bit-100.lisp")
      (load "benchmarks/transpiled-fol-code/8bit-100.lisp")
      (load "benchmarks/transpiled-fol-code/8bit-100-p.lisp")
      (push (run-benchmark "8bit-100" 
                           (lambda () (lsim-cl::run-bench))
                           (lambda () (lsim::run-bench))
                           (lambda () (plsim::run-bench)))
            results)

      ;; 32-bit Register
      (load "benchmarks/lisp-code/32bit-300.lisp")
      (load "benchmarks/transpiled-fol-code/32bit-300.lisp")
      (load "benchmarks/transpiled-fol-code/32bit-300-p.lisp")
      (push (run-benchmark "32bit-300" 
                           (lambda () (lsim-cl::run-bench))
                           (lambda () (lsim::run-bench))
                           (lambda () (plsim::run-bench)))
            results)

      ;; 8x32 Pipeline
      (load "benchmarks/lisp-code/8x32-900.lisp")
      (load "benchmarks/transpiled-fol-code/8x32-900.lisp")
      (load "benchmarks/transpiled-fol-code/8x32-900-p.lisp")
      (push (run-benchmark "8x32-900" 
                           (lambda () (lsim-cl::run-bench))
                           (lambda () (lsim::run-bench))
                           (lambda () (plsim::run-bench)))
            results)

      (format t "----------------------------------------------------~%")
      (format t "Summary Finished.~%"))
  (error (e)
    (format t "FATAL ERROR during benchmark: ~A~%" e)
    (sb-debug:print-backtrace)
    (sb-ext:exit :code 1)))

(sb-ext:exit :code 0)
