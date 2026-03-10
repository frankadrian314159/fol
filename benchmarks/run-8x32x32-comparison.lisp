(require :asdf)
(let ((asd-path (merge-pathnames "src/fol-compiler.asd" (truename "."))))
  (unless (probe-file asd-path)
    (error "Could not find fol-compiler.asd at ~A" asd-path))
  (asdf:load-asd asd-path))

(handler-bind ((warning #'muffle-warning))
  (asdf:load-system :fol-compiler/core :verbose nil))

(cl:defparameter cl-user::*cl-time* 0.0)
(cl:defparameter cl-user::*cl-mem* 0.0)

;; Define load-fol-file in CL-USER
(defun cl-user::load-fol-file (path)
  (format cl:t "Compiling and loading ~A...~%" path)
  (with-open-file (in path)
    (let ((cl:*readtable* fol.compiler.reader:*fol-readtable*))
      (loop for form = (cl:read in nil :eof)
            until (eq form :eof)
            do (let* ((compiled (fol.compiler:compile-form form))
                      (code (fol.compiler:compilation-result-code compiled)))
                 (cl:eval code))))))

(defun report-gc-pressure (label total-time start-bytes start-gc-time)
  (let* ((end-bytes (sb-ext:get-bytes-consed))
         (end-gc-time sb-ext:*gc-run-time*)
         (total-alloc (/ (- end-bytes start-bytes) 1024.0 1024.0))
         (gc-time (/ (- end-gc-time start-gc-time) (cl:float cl:internal-time-units-per-second)))
         (alloc-rate (/ total-alloc total-time))
         (gc-percent (* 100 (/ gc-time total-time))))
    (format cl:t "~A GC Pressure Figures:~%" label)
    (format cl:t "  Total Allocation: {~,2F MB}~%" total-alloc)
    (format cl:t "  Allocation Rate:  {~,2F MB/s}~%" alloc-rate)
    (format cl:t "  Time spent in GC: {~,3F s} (~,1F% of total time)~%" gc-time gc-percent)
    (list total-alloc total-time)))

(format cl:t "~%============================================~%")
(format cl:t "8x32x32-9000 GC Pressure Benchmark~%")
(format cl:t "============================================~%~%")

;; --- CL Benchmark ---
(format cl:t "Loading CL simulation...~%")
(cl:load "benchmarks/lisp-code/lsim.lisp")
(cl:load "benchmarks/lisp-code/8x32x32-9000.lisp")

(format cl:t "--- Common Lisp (Mutable/Imperative) ---~%")
(sb-ext:gc :full cl:t)
(handler-case
    (let ((start-time (cl:get-internal-run-time))
          (start-bytes (sb-ext:get-bytes-consed))
          (start-gc-time sb-ext:*gc-run-time*))
      (lsim-cl:run-bench)
      (let* ((end-time (cl:get-internal-run-time))
             (total-time (/ (- end-time start-time) (cl:float cl:internal-time-units-per-second))))
        (destructuring-bind (mem time) (report-gc-pressure "Common Lisp" total-time start-bytes start-gc-time)
          (cl:setf cl-user::*cl-time* time)
          (cl:setf cl-user::*cl-mem* mem)
          (format cl:t "  Wall Time:        ~,3F s~%~%" total-time))))
  (error (e)
    (format cl:t "Error during CL benchmark: ~A~%" e)
    (sb-ext:exit :code 1)))

;; --- FOL Benchmark ---
(format cl:t "Loading FOL simulation...~%")
(cl-user::load-fol-file "benchmarks/fol-code/lsim.fol")
(cl-user::load-fol-file "benchmarks/fol-code/8x32x32-9000.fol")

(format cl:t "~%--- FOL (Persistent/Functional) ---~%")
(sb-ext:gc :full cl:t)
(handler-case
    (let ((start-time (cl:get-internal-run-time))
          (start-bytes (sb-ext:get-bytes-consed))
          (start-gc-time sb-ext:*gc-run-time*))
      ;; Package name is upcased to "LSIM" by the FOL compiler
      (cl:funcall (cl:find-symbol "RUN-BENCH" "LSIM"))
      (let* ((end-time (cl:get-internal-run-time))
             (total-time (/ (- end-time start-time) (cl:float cl:internal-time-units-per-second))))
        (report-gc-pressure "FOL" total-time start-bytes start-gc-time)
        (format cl:t "  Wall Time:        ~,3F s (Ratio: ~,2Fx)~%~%" total-time (/ total-time (cl:max 0.001 cl-user::*cl-time*)))))
  (error (e)
    (format cl:t "Error during FOL benchmark: ~A~%" e)
    (sb-ext:exit :code 1)))

(sb-ext:exit :code 0)
