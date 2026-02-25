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

(defparameter *iterations* 1)

(format t "~%============================================~%")
(format t "32x32-3000 Pipeline Benchmark~%")
(format t "  32 cascaded 32-bit registers (~~4096 NAND gates)~%")
(format t "  3000 time steps, ~A iterations~%" *iterations*)
(format t "============================================~%")

;; Load circuit definitions
(format t "~%Loading CL circuit definition...~%")
(load "benchmarks/lisp-code/32x32-3000.lisp")

(format t "Loading FOL circuit definition...~%")
(load "benchmarks/transpiled-fol-code/32x32-3000.lisp")

(format t "Loading PLSim circuit definition...~%")
(load "benchmarks/transpiled-fol-code/32x32-3000-p.lisp")

(format t "~%Running benchmarks...~%~%")

(handler-case
    (progn
     ;; CL Run
     (let ((cl-time 0))
       (dotimes (i *iterations*)
         (let ((start (get-internal-run-time)))
           (lsim-cl::run-bench)
           (incf cl-time (- (get-internal-run-time) start))))
       (let ((avg (/ (/ (float cl-time) *iterations*) internal-time-units-per-second)))
         (format t "  CL Average:    ~,3F s~%" avg)

         ;; FOL Run
         (let ((fol-time 0))
           (dotimes (i *iterations*)
             (let ((start (get-internal-run-time)))
               (lsim::run-bench)
               (incf fol-time (- (get-internal-run-time) start))))
           (let ((fol-avg (/ (/ (float fol-time) *iterations*) internal-time-units-per-second)))
             (format t "  FOL Average:   ~,3F s (Ratio: ~,2Fx)~%" fol-avg (/ fol-avg avg))

             ;; PLSIM Run
             (let ((pfol-time 0))
               (dotimes (i *iterations*)
                 (let ((start (get-internal-run-time)))
                   (plsim::run-bench)
                   (incf pfol-time (- (get-internal-run-time) start))))
               (let ((pfol-avg (/ (/ (float pfol-time) *iterations*) internal-time-units-per-second)))
                 (format t "  PLSim Average: ~,3F s (Ratio: ~,2Fx, Speedup: ~,2Fx)~%"
                   pfol-avg (/ pfol-avg avg) (/ fol-avg pfol-avg))
                 (format t "~%============================================~%")
                 (format t "Summary: CL=~,3Fs  FOL=~,3Fs (~,2Fx)  PLSim=~,3Fs (~,2Fx)~%"
                   avg fol-avg (/ fol-avg avg) pfol-avg (/ pfol-avg avg)))))))))
  (error (e)
    (format t "~%FATAL ERROR: ~A~%" e)
    (sb-debug:print-backtrace :count 20)
    (sb-ext:exit :code 1)))

(sb-ext:exit :code 0)
