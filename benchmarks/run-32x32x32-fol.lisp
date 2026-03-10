(require :asdf)
(let ((asd-path (merge-pathnames "src/fol-compiler.asd" (truename "."))))
  (unless (probe-file asd-path)
    (error "Could not find fol-compiler.asd at ~A" asd-path))
  (asdf:load-asd asd-path))

(handler-bind ((warning #'muffle-warning))
  (asdf:load-system :fol-compiler/core :verbose nil))

(defun cl-user::load-fol-file (path)
  (with-open-file (in path)
    (let ((cl:*readtable* fol.compiler.reader:*fol-readtable*))
      (loop for form = (cl:read in nil :eof)
            until (eq form :eof)
            do (let* ((compiled (fol.compiler:compile-form form))
                      (code (fol.compiler:compilation-result-code compiled)))
                 (cl:eval code))))))

(format t "~%Running 32x32x32-30000 (FOL-SERIAL)...~%")

(cl-user::load-fol-file "benchmarks/fol-code/lsim.fol")
(cl-user::load-fol-file "benchmarks/fol-code/32x32x32-30000.fol")

(sb-ext:gc :full t)

(let* ((start-time  (get-internal-run-time))
       (start-bytes (sb-ext:get-bytes-consed))
       (start-gc    sb-ext:*gc-run-time*))

  (funcall (find-symbol "RUN-BENCH" "LSIM"))

  (let* ((end-time  (get-internal-run-time))
         (end-bytes (sb-ext:get-bytes-consed))
         (end-gc    sb-ext:*gc-run-time*)
         (total-time  (/ (- end-time  start-time)  (float internal-time-units-per-second)))
         (total-alloc (/ (- end-bytes start-bytes) 1024.0 1024.0))
         (gc-time     (/ (- end-gc    start-gc)    (float internal-time-units-per-second)))
         (gc-pct      (* 100 (/ gc-time (max 0.001 total-time))))
         (evals       (fol.compiler.mutable:deref
                        (symbol-value (find-symbol "*GATE-EVALS*" "LSIM")))))
    (format t "~%Results:~%")
    (format t "  Time (s):        ~,3F~%" total-time)
    (format t "  Alloc (MB):      ~,2F~%" total-alloc)
    (format t "  GC Time (s):     ~,3F~%" gc-time)
    (format t "  GC %%:            ~,1F~%" gc-pct)
    (format t "  Gate Evals:      ~:D~%" evals)
    (format t "~%| 32x32x32-30000 | FOL-SERIAL | ~,3F | ~,2F | ~,3F | ~,1F% | ~:D |~%"
            total-time total-alloc gc-time gc-pct evals)))

(sb-ext:exit :code 0)
