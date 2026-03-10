(require :asdf)
(let ((asd-path (merge-pathnames "src/fol-compiler.asd" (truename "."))))
  (unless (probe-file asd-path)
    (error "Could not find fol-compiler.asd at ~A" asd-path))
  (asdf:load-asd asd-path))

(handler-bind ((warning #'muffle-warning))
  (asdf:load-system :fol-compiler/core :verbose nil))

;; Ensure parallel libraries are loaded for plsim.fol
(load "src/lib/reducers.lisp")
(load "src/lib/parallel.lisp")

(cl:defparameter cl-user::*cl-time* 0.0)
(cl:defparameter cl-user::*cl-mem* 0.0)

;; Define load-fol-file in CL-USER
(defun cl-user::load-fol-file (path)
  (with-open-file (in path)
    (let ((cl:*readtable* fol.compiler.reader:*fol-readtable*))
      (loop for form = (cl:read in nil :eof)
            until (eq form :eof)
            do (let* ((compiled (fol.compiler:compile-form form))
                      (code (fol.compiler:compilation-result-code compiled)))
                 (cl:eval code))))))

(defstruct bench-result
  name
  mode
  time
  alloc-mb
  gc-time
  gc-percent
  gate-evals)

(defun run-experiment (name mode lisp-file fol-file package symbol)
  (format t "Running ~A (~A)...~%" name mode)
  (sb-ext:gc :full t)
  (let ((start-time (get-internal-run-time))
        (start-bytes (sb-ext:get-bytes-consed))
        (start-gc-time sb-ext:*gc-run-time*))

    (handler-case
        (let ((evals 0))
          (cond
           ((eq mode :cl)
             (load "benchmarks/lisp-code/lsim.lisp")
             (load lisp-file)
             (funcall (find-symbol symbol package))
             (setf evals (symbol-value (find-symbol "*GATE-EVALS*" "LSIM-CL"))))
           ((eq mode :fol-serial)
             (cl-user::load-fol-file "benchmarks/fol-code/lsim.fol")
             (cl-user::load-fol-file fol-file)
             (funcall (find-symbol symbol "LSIM"))
             (setf evals (fol.compiler.mutable:deref (symbol-value (find-symbol "*GATE-EVALS*" "LSIM")))))
           ((eq mode :fol-parallel)
             (cl-user::load-fol-file "benchmarks/fol-code/plsim.fol")
             (cl-user::load-fol-file fol-file)
             (funcall (find-symbol symbol "PLSIM"))
             (setf evals (fol.compiler.mutable:deref (symbol-value (find-symbol "*GATE-EVALS*" "PLSIM"))))))

          (let* ((end-time (get-internal-run-time))
                 (end-bytes (sb-ext:get-bytes-consed))
                 (end-gc-time sb-ext:*gc-run-time*)
                 (total-time (/ (- end-time start-time) (float internal-time-units-per-second)))
                 (total-alloc (/ (- end-bytes start-bytes) 1024.0 1024.0))
                 (gc-time-val (/ (- end-gc-time start-gc-time) (float internal-time-units-per-second)))
                 (gc-percent (* 100 (/ gc-time-val (max 0.001 total-time)))))
            (make-bench-result :name name :mode mode :time total-time :alloc-mb total-alloc
                               :gc-time gc-time-val :gc-percent gc-percent :gate-evals evals)))
      (error (e)
        (format t "  Error: ~A~%" e)
        nil))))

(defparameter *benchmarks*
              '(("8bit-100"
                 "benchmarks/lisp-code/8bit-100.lisp"
                 "benchmarks/fol-code/8bit-100.fol"
                 "benchmarks/fol-code/8bit-100-p.fol")
                ("32bit-300"
                 "benchmarks/lisp-code/32bit-300.lisp"
                 "benchmarks/fol-code/32bit-300.fol"
                 "benchmarks/fol-code/32bit-300-p.fol")
                ("8x32-9000"
                 "benchmarks/lisp-code/8x32-900.lisp"
                 "benchmarks/fol-code/8x32-900.fol"
                 "benchmarks/fol-code/8x32-900-p.fol")
                ("32x32-3000"
                 "benchmarks/lisp-code/32x32-3000.lisp"
                 "benchmarks/fol-code/32x32-3000.fol"
                 "benchmarks/fol-code/32x32-3000-p.fol")
                ("8x32x32-9000"
                 "benchmarks/lisp-code/8x32x32-9000.lisp"
                 "benchmarks/fol-code/8x32x32-9000.fol"
                 "benchmarks/fol-code/8x32x32-9000-p.fol")))

(let ((results '()))
  (dolist (b *benchmarks*)
    (destructuring-bind (name lisp fol fol-p) b
      ;; 1. CL
      (let ((res (run-experiment name :cl lisp nil "LSIM-CL" "RUN-BENCH")))
        (when res (push res results)))
      ;; 2. FOL Serial
      (let ((res (run-experiment name :fol-serial nil fol nil "RUN-BENCH")))
        (when res (push res results)))
      ;; 3. FOL Parallel
      (let ((res (run-experiment name :fol-parallel nil fol-p nil "RUN-BENCH")))
        (when res (push res results)))))

  ;; Output as Markdown Table
  (format t "~%| Benchmark | Mode | Time (s) | Allocation (MB) | GC Time (s) | GC % | Gate Evals |~%")
  (format t "| :--- | :--- | :---: | :---: | :---: | :---: | :---: |~%")
  (dolist (res (nreverse results))
    (format t "| ~A | ~A | ~,3F | ~,2F | ~,3F | ~,1F% | ~:D |~%"
      (bench-result-name res)
      (bench-result-mode res)
      (bench-result-time res)
      (bench-result-alloc-mb res)
      (bench-result-gc-time res)
      (bench-result-gc-percent res)
      (bench-result-gate-evals res))))

(sb-ext:exit :code 0)
