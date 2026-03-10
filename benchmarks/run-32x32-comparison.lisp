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

(format cl:t "~%============================================~%")
(format cl:t "32x32-3000 Pipeline Benchmark Comparison~%")
(format cl:t "============================================~%~%")

;; --- CL Benchmark ---
(cl:load "benchmarks/lisp-code/lsim.lisp")
(cl:load "benchmarks/lisp-code/32x32-3000.lisp")

(format cl:t "--- Common Lisp (Mutable/Imperative) ---~%")
(sb-ext:gc :full cl:t)
(let ((start-time (cl:get-internal-run-time))
      (start-bytes (sb-ext:get-bytes-consed)))
  (lsim-cl:run-bench)
  (let ((end-time (cl:get-internal-run-time))
        (end-bytes (sb-ext:get-bytes-consed)))
    (let ((time (/ (- end-time start-time) (cl:float cl:internal-time-units-per-second)))
          (mem (/ (- end-bytes start-bytes) 1024.0 1024.0)))
      (format cl:t "Time:   ~,3F s~%" time)
      (format cl:t "Memory: ~,2F MB~%~%" mem)
      (cl:setf cl-user::*cl-time* time)
      (cl:setf cl-user::*cl-mem* mem))))

;; --- FOL Benchmark ---
(cl-user::load-fol-file "benchmarks/fol-code/lsim.fol")
(cl-user::load-fol-file "benchmarks/fol-code/32x32-3000.fol")

(format cl:t "~%--- FOL (Persistent/Functional) ---~%")
(sb-ext:gc :full cl:t)
(let ((start-time (cl:get-internal-run-time))
      (start-bytes (sb-ext:get-bytes-consed)))
  ;; Package name is upcased to "LSIM" by the FOL compiler
  (cl:funcall (cl:find-symbol "RUN-BENCH" "LSIM"))
  (let ((end-time (cl:get-internal-run-time))
        (end-bytes (sb-ext:get-bytes-consed)))
    (let ((time (/ (- end-time start-time) (cl:float cl:internal-time-units-per-second)))
          (mem (/ (- end-bytes start-bytes) 1024.0 1024.0)))
      (format cl:t "Time:   ~,3F s (Ratio: ~,2Fx)~%" time (/ time (cl:max 0.001 cl-user::*cl-time*)))
      (format cl:t "Memory: ~,2F MB (Ratio: ~,2Fx)~%~%" mem (/ mem (cl:max 0.001 cl-user::*cl-mem*))))))

(sb-ext:exit :code 0)
