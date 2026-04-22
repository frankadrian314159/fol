;;; benchmarks/run-32x32x32-final.lisp
;;;
;;; Final benchmark for ELS 2026: 32x32x32-30000 configuration.
;;; 1. Runs FOL and CL 3 times each to report average wall time.
;;; 2. Performs a 2x2 ablation for this configuration.
;;;

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

(defun cl-user::mb (bytes)
  (cl:/ bytes 1024.0d0 1024.0d0))

(defun cl-user::bench-run (run-fn pkg-name)
  (sb-ext:gc :full t)
  (let ((t0  (cl-user::now-ms))
        (b0  (sb-ext:get-bytes-consed))
        (gc0 sb-ext:*gc-run-time*))
    (cl:funcall run-fn)
    (let* ((t1    (cl-user::now-ms))
           (b1    (sb-ext:get-bytes-consed))
           (gc1   sb-ext:*gc-run-time*)
           (wall  (cl:- t1 t0))
           (bytes (cl:- b1 b0))
           (gc-ms (cl:* 1000.0d0
                        (cl:/ (cl:- gc1 gc0)
                               (cl:float cl:internal-time-units-per-second 1.0d0))))
           (netms (cl:symbol-value (cl:find-symbol "*LAST-NETLIST-MS*" pkg-name)))
           (simms (cl:symbol-value (cl:find-symbol "*LAST-SIM-MS*"     pkg-name)))
           (evals (cl:symbol-value (cl:find-symbol "*GATE-EVALS*"      pkg-name))))
      (cl:list wall bytes gc-ms netms simms evals))))

(defun cl-user::bench-fol-run (run-fn)
  (sb-ext:gc :full t)
  (let ((t0  (cl-user::now-ms))
        (b0  (sb-ext:get-bytes-consed))
        (gc0 sb-ext:*gc-run-time*))
    (cl:funcall run-fn)
    (let* ((t1    (cl-user::now-ms))
           (b1    (sb-ext:get-bytes-consed))
           (gc1   sb-ext:*gc-run-time*)
           (wall  (cl:- t1 t0))
           (bytes (cl:- b1 b0))
           (gc-ms (cl:* 1000.0d0
                        (cl:/ (cl:- gc1 gc0)
                               (cl:float cl:internal-time-units-per-second 1.0d0))))
           (deref (cl:find-symbol "DEREF" "FOL.COMPILER.MUTABLE"))
           (netms (cl:funcall deref
                               (cl:symbol-value (cl:find-symbol "*LAST-NETLIST-MS*" "LSIM"))))
           (simms (cl:funcall deref
                               (cl:symbol-value (cl:find-symbol "*LAST-SIM-MS*" "LSIM"))))
           (evals (cl:funcall deref
                               (cl:symbol-value (cl:find-symbol "*GATE-EVALS*" "LSIM")))))
      (cl:list wall bytes gc-ms netms simms evals))))

(defun cl-user::avg-runs (runs)
  (let ((n (cl:length runs)))
    (cl:mapcar (cl:lambda (i)
                 (if (cl:= i 1)
                     (cl:reduce #'cl:+ runs :key (cl:lambda (r) (cl:nth i r)))
                     (cl:/ (cl:reduce #'cl:+ runs :key (cl:lambda (r) (cl:nth i r)))
                           (cl:float n))))
               '(0 1 2 3 4 5))))

;;; Engines
(format t "Loading engines...~%")
(load "benchmarks/lisp-code/lsim-pq.lisp")
(load "benchmarks/lisp-code/lsim-pq-hybrid-a.lisp")
(load "benchmarks/lisp-code/lsim-pq-hybrid-b.lisp")
(cl-user::load-fol-file "benchmarks/fol-code/lsim-pq.fol")

(format t "Loading 32x32x32-30000 circuit...~%")
(load "benchmarks/lisp-code/32x32x32-30000.lisp")
(cl-user::load-fol-file "benchmarks/fol-code/32x32x32-30000.fol")

(let* ((label "32x32x32-30000")
       (n-runs 3)
       (cl-fn   (cl:find-symbol "RUN-BENCH" "LSIM-CL"))
       (fol-fn  (cl:find-symbol "RUN-BENCH" "LSIM"))
       (cl-mod  (cl:intern "TOP32X32X32" :lsim-cl))
       (max-time 30000)
       (ha-fn   (cl:lambda () (lsim-hybrid-a:run-lsim cl-mod max-time)))
       (hb-fn   (cl:lambda () (lsim-hybrid-b:run-lsim cl-mod max-time))))

  (format t "Warming up...~%")
  (cl:funcall cl-fn)
  (cl:funcall ha-fn)
  (cl:funcall hb-fn)
  (cl:funcall fol-fn)

  (format t "~%Starting main runs (3 per engine)...~%")
  (let ((cl-results  '())
        (ha-results  '())
        (hb-results  '())
        (fol-results '()))
    (cl:dotimes (i n-runs)
      (format t "Run #~D...~%" (cl:1+ i))
      (cl:push (cl-user::bench-run      cl-fn "LSIM-CL")       cl-results)
      (cl:push (cl-user::bench-run      ha-fn "LSIM-HYBRID-A") ha-results)
      (cl:push (cl-user::bench-run      hb-fn "LSIM-HYBRID-B") hb-results)
      (cl:push (cl-user::bench-fol-run  fol-fn)              fol-results))

    (let ((ca  (cl-user::avg-runs cl-results))
          (haa (cl-user::avg-runs ha-results))
          (hba (cl-user::avg-runs hb-results))
          (fa  (cl-user::avg-runs fol-results)))

      (format t "~%Average Results for ~A (x~D):~%" label n-runs)
      (format t "--------------------------------------------------------------------------------~%")
      (format t "Engine     Wall(s)   Alloc(MB)  GC%      Net(s)    Sim(s)    evals~%")
      (format t "--------------------------------------------------------------------------------~%")
      (cl:labels ((pr (eng avg)
                    (let ((wall (cl:/ (cl:first avg) 1000.0d0))
                          (bytes (cl-user::mb (cl:second avg)))
                          (gc-pct (cl:* 100.0d0 (cl:/ (cl:third avg) (cl:first avg))))
                          (net (cl:/ (cl:fourth avg) 1000.0d0))
                          (sim (cl:/ (cl:fifth avg) 1000.0d0))
                          (evals (cl:round (cl:sixth avg))))
                      (cl:format cl:t "~-9A  ~8,2F  ~9,1F  ~5,1F%  ~8,2F  ~8,2F  ~12:D~%"
                                 eng wall bytes gc-pct net sim evals))))
        (pr "CL"       ca)
        (pr "Hybrid-A" haa)
        (pr "Hybrid-B" hba)
        (pr "FOL"      fa))
      (format t "--------------------------------------------------------------------------------~%"))))

(sb-ext:exit :code 0)
