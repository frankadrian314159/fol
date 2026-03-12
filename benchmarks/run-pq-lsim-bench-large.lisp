;;; run-pq-lsim-bench-large.lisp
;;;
;;; Large-circuit portion of the PQ-LSim benchmark.
;;; Run with 56 GB heap:
;;;   sbcl --dynamic-space-size 57344 --noinform --non-interactive \
;;;        --load benchmarks/run-pq-lsim-bench-large.lisp
;;;
;;; Covers:
;;;   8x32x32-9000   3 runs averaged
;;;   32x32x32-30000 1 run

(require :asdf)
(pushnew (truename "src/") asdf:*central-registry*)
(asdf:load-asd (merge-pathnames "src/fol-compiler.asd" (truename ".")))

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

(defun cl-user::now-ms ()
  (* 1000.0d0
     (/ (cl:get-internal-real-time)
        (cl:float cl:internal-time-units-per-second 1.0d0))))

(defun cl-user::bench-fol-run (run-fn)
  (sb-ext:gc :full t)
  (let ((t0   (cl-user::now-ms))
        (b0   (sb-ext:get-bytes-consed))
        (gc0  sb-ext:*gc-run-time*))
    (cl:funcall run-fn)
    (let* ((t1    (cl-user::now-ms))
           (b1    (sb-ext:get-bytes-consed))
           (gc1   sb-ext:*gc-run-time*)
           (wall  (cl:- t1 t0))
           (bytes (cl:- b1 b0))
           (gc-ms (cl:* 1000.0d0 (cl:/ (cl:- gc1 gc0)
                                        (cl:float cl:internal-time-units-per-second 1.0d0))))
           (netms (cl:funcall (cl:find-symbol "DEREF" "FOL.COMPILER.MUTABLE")
                              (cl:symbol-value (cl:find-symbol "*LAST-NETLIST-MS*" "LSIM"))))
           (simms (cl:funcall (cl:find-symbol "DEREF" "FOL.COMPILER.MUTABLE")
                              (cl:symbol-value (cl:find-symbol "*LAST-SIM-MS*" "LSIM"))))
           (evals (cl:funcall (cl:find-symbol "DEREF" "FOL.COMPILER.MUTABLE")
                              (cl:symbol-value (cl:find-symbol "*GATE-EVALS*" "LSIM")))))
      (cl:list wall bytes gc-ms netms simms evals))))

(defun cl-user::bench-cl-run (run-fn)
  (sb-ext:gc :full t)
  (let ((t0   (cl-user::now-ms))
        (b0   (sb-ext:get-bytes-consed))
        (gc0  sb-ext:*gc-run-time*))
    (cl:funcall run-fn)
    (let* ((t1    (cl-user::now-ms))
           (b1    (sb-ext:get-bytes-consed))
           (gc1   sb-ext:*gc-run-time*)
           (wall  (cl:- t1 t0))
           (bytes (cl:- b1 b0))
           (gc-ms (cl:* 1000.0d0 (cl:/ (cl:- gc1 gc0)
                                        (cl:float cl:internal-time-units-per-second 1.0d0))))
           (netms (cl:symbol-value (cl:find-symbol "*LAST-NETLIST-MS*" "LSIM-CL")))
           (simms (cl:symbol-value (cl:find-symbol "*LAST-SIM-MS*"    "LSIM-CL")))
           (evals (cl:symbol-value (cl:find-symbol "*GATE-EVALS*"     "LSIM-CL"))))
      (cl:list wall bytes gc-ms netms simms evals))))

(defun cl-user::mb (bytes) (cl:/ bytes 1024.0d0 1024.0d0))

(defun cl-user::print-run (label engine wall-ms bytes gc-ms net-ms sim-ms evals)
  (cl:declare (cl:ignore bytes))
  (let ((gc-pct (if (cl:> wall-ms 0) (cl:* 100.0d0 (cl:/ gc-ms wall-ms)) 0.0d0)))
    (cl:format cl:t "~12A  ~8A  ~12,1F  ~5,1F%  ~10,1F  ~10,1F  ~14:D~%"
               label engine wall-ms gc-pct net-ms sim-ms evals)
    (cl:force-output)))

(defun cl-user::avg-runs (runs)
  (let ((n (cl:length runs)))
    (cl:mapcar (cl:lambda (i)
                 (if (cl:= i 1)
                     (cl:reduce #'cl:+ runs :key (cl:lambda (r) (cl:nth i r)))
                     (cl:/ (cl:reduce #'cl:+ runs :key (cl:lambda (r) (cl:nth i r)))
                           (cl:float n))))
               '(0 1 2 3 4 5))))

(defun cl-user::run-circuit (label cl-path fol-path n-runs)
  (cl:format cl:t "~%=== ~A (x~D) ===~%" label n-runs)
  (cl:load cl-path)
  (cl-user::load-fol-file fol-path)
  (in-package :cl-user)
  (let ((cl-fn  (cl:find-symbol "RUN-BENCH" "LSIM-CL"))
        (fol-fn (cl:find-symbol "RUN-BENCH" "LSIM")))
    ;; Warmup (1 run each)
    (cl:format cl:t "  Warming up...~%") (cl:force-output)
    (cl:funcall cl-fn)
    (cl:funcall fol-fn)
    (sb-ext:gc :full t)
    (cl:format cl:t "  Warmup done. Running ~D timed run~:P...~%" n-runs) (cl:force-output)
    (let ((cl-results  '())
          (fol-results '()))
      (cl:dotimes (i n-runs)
        (cl:format cl:t "  Run ~D/~D CL-PQ...~%" (cl:1+ i) n-runs) (cl:force-output)
        (let ((cr (cl-user::bench-cl-run  (cl:lambda () (cl:funcall cl-fn)))))
          (cl:push cr cl-results)
          (cl-user::print-run (cl:format cl:nil "~A #~D" label (cl:1+ i)) "CL-PQ"
                              (cl:first cr) (cl:second cr) (cl:third cr)
                              (cl:fourth cr) (cl:fifth cr) (cl:sixth cr)))
        (cl:format cl:t "  Run ~D/~D FOL-PQ...~%" (cl:1+ i) n-runs) (cl:force-output)
        (let ((fr (cl-user::bench-fol-run (cl:lambda () (cl:funcall fol-fn)))))
          (cl:push fr fol-results)
          (cl-user::print-run (cl:format cl:nil "~A #~D" label (cl:1+ i)) "FOL-PQ"
                              (cl:first fr) (cl:second fr) (cl:third fr)
                              (cl:fourth fr) (cl:fifth fr) (cl:sixth fr))))
      (cl:list (cl:nreverse cl-results) (cl:nreverse fol-results)))))

;;; Load engines
(load "benchmarks/lisp-code/lsim-pq.lisp")
(cl-user::load-fol-file "benchmarks/fol-code/lsim-pq.fol")
(in-package :cl-user)

;;; Main
(handler-case
    (progn
      (format t "~%FOL PQ-LSim Benchmark — Large Circuits (56 GB heap)~%")
      (format t "Engine CL-PQ : mutable destructive leftist heap (pure CL)~%")
      (format t "Engine FOL-PQ: persistent leftist heap (FOL persistent collections)~%")

      ;; 8x32x32-9000 — 3 averaged runs
      (destructuring-bind (cl-rs fol-rs)
          (cl-user::run-circuit "8x32x32-9000"
                                "benchmarks/lisp-code/8x32x32-9000.lisp"
                                "benchmarks/fol-code/8x32x32-9000.fol"
                                3)
        (let ((ca (cl-user::avg-runs cl-rs))
              (fa (cl-user::avg-runs fol-rs)))
          (format t "  AVG CL-PQ : wall=~,1Fms alloc=~,1FMB gc=~,1Fms net=~,1Fms sim=~,1Fms evals=~:D~%"
                  (first ca) (cl-user::mb (second ca)) (third ca) (fourth ca) (fifth ca) (round (sixth ca)))
          (format t "  AVG FOL-PQ: wall=~,1Fms alloc=~,1FMB gc=~,1Fms net=~,1Fms sim=~,1Fms evals=~:D~%"
                  (first fa) (cl-user::mb (second fa)) (third fa) (fourth fa) (fifth fa) (round (sixth fa)))))

      ;; 32x32x32-30000 — 1 run
      (destructuring-bind (cl-rs fol-rs)
          (cl-user::run-circuit "32x32x32-30000"
                                "benchmarks/lisp-code/32x32x32-30000.lisp"
                                "benchmarks/fol-code/32x32x32-30000.fol"
                                1)
        (let ((ca (first cl-rs))
              (fa (first fol-rs)))
          (format t "  CL-PQ : wall=~,1Fms alloc=~,1FMB gc=~,1Fms net=~,1Fms sim=~,1Fms evals=~:D~%"
                  (first ca) (cl-user::mb (second ca)) (third ca) (fourth ca) (fifth ca) (round (sixth ca)))
          (format t "  FOL-PQ: wall=~,1Fms alloc=~,1FMB gc=~,1Fms net=~,1Fms sim=~,1Fms evals=~:D~%"
                  (first fa) (cl-user::mb (second fa)) (third fa) (fourth fa) (fifth fa) (round (sixth fa)))))

      (format t "~%Benchmark complete.~%"))

  (error (e)
    (format t "~%FATAL ERROR: ~A~%" e)
    (sb-debug:print-backtrace :count 20)
    (sb-ext:exit :code 1)))

(sb-ext:exit :code 0)
