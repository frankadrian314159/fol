;;; benchmarks/run-pq-lsim-bench-ablation.lisp
;;;
;;; 2×2 Ablation: isolating persistent-heap vs persistent-state overhead in LSim
;;;
;;;   CL      : mutable CL heap   + mutable CL hash-tables   (baseline)
;;;   Hybrid-A: mutable CL heap   + FOL persistent HAMT maps (swap state only)
;;;   Hybrid-B: FOL persistent heap + mutable CL hash-tables  (swap heap only)
;;;   FOL     : FOL persistent heap + FOL persistent HAMT maps (full FOL)
;;;
;;; All four engines run the same circuits and event sequences.
;;; Hybrid-A and Hybrid-B read the netlist/events/monitors from the LSIM-CL
;;; package globals set when the CL circuit file is loaded.
;;;
;;; Circuits and run counts:
;;;   32bit-300      20 runs, individual output
;;;   8x32-900       20 runs, individual output
;;;   32x32-3000      3 runs averaged
;;;   8x32x32-9000    3 runs averaged
;;;
;;; Run from the fol/ project root:
;;;   sbcl --noinform --non-interactive --load benchmarks/run-pq-lsim-bench-ablation.lisp

(require :asdf)
(pushnew (truename "src/") asdf:*central-registry*)
(asdf:load-asd (merge-pathnames "src/fol-compiler.asd" (truename ".")))

;;; Load the full FOL compiler + fol-core runtime.
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system :fol-compiler/core :verbose nil))

;;; ---------------------------------------------------------------------------
;;; FOL file loader
;;; ---------------------------------------------------------------------------

(defun cl-user::load-fol-file (path)
  (with-open-file (in path)
    (let ((cl:*readtable* fol.compiler.reader:*fol-readtable*))
      (loop for form = (cl:read in nil :eof)
            until (eq form :eof)
            do (let* ((compiled (fol.compiler:compile-form form))
                      (code (fol.compiler:compilation-result-code compiled)))
                 (cl:eval code))))))

;;; ---------------------------------------------------------------------------
;;; Timing helpers
;;; ---------------------------------------------------------------------------

(defun cl-user::now-ms ()
  (* 1000.0d0
     (/ (cl:get-internal-real-time)
        (cl:float cl:internal-time-units-per-second 1.0d0))))

(defun cl-user::mb (bytes)
  (cl:/ bytes 1024.0d0 1024.0d0))

;;; Run FN once; return (wall-ms bytes-consed gc-ms netlist-ms sim-ms gate-evals).
;;; PKG-NAME is a string; timing vars are plain CL variables in that package.
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

;;; FOL timing vars are wrapped in atoms; use deref.
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

;;; Average a list of run results. Returns (avg-wall sum-bytes avg-gc avg-net avg-sim avg-evals).
(defun cl-user::avg-runs (runs)
  (let ((n (cl:length runs)))
    (cl:mapcar (cl:lambda (i)
                 (if (cl:= i 1)  ; bytes: sum, not average
                     (cl:reduce #'cl:+ runs :key (cl:lambda (r) (cl:nth i r)))
                     (cl:/ (cl:reduce #'cl:+ runs :key (cl:lambda (r) (cl:nth i r)))
                           (cl:float n))))
               '(0 1 2 3 4 5))))

;;; ---------------------------------------------------------------------------
;;; Output formatting
;;; ---------------------------------------------------------------------------

(defun cl-user::print-ablation-header ()
  (cl:format cl:t "~%~80A~%" (cl:make-string 80 :initial-element #\-))
  (cl:format cl:t "~14A  ~9A  ~8A  ~6A  ~8A  ~8A  ~12A~%"
             "Circuit" "Engine" "Wall(ms)" "GC%" "Net(ms)" "Sim(ms)" "GateEvals")
  (cl:format cl:t "~80A~%" (cl:make-string 80 :initial-element #\-)))

(defun cl-user::print-ablation-run (label engine wall-ms bytes gc-ms net-ms sim-ms evals)
  (cl:declare (cl:ignore bytes))
  (let ((gc-pct (if (cl:> wall-ms 0) (cl:* 100.0d0 (cl:/ gc-ms wall-ms)) 0.0d0)))
    (cl:format cl:t "~14A  ~9A  ~8,1F  ~5,1F%  ~8,1F  ~8,1F  ~12:D~%"
               label engine wall-ms gc-pct net-ms sim-ms evals)
    (cl:force-output)))

(defun cl-user::print-ablation-avg (label engine avg)
  (cl:format cl:t "  AVG ~A ~A: wall=~,1Fms alloc=~,1FMB gc=~,1Fms net=~,1Fms sim=~,1Fms evals=~:D~%"
             label engine
             (cl:first avg) (cl-user::mb (cl:second avg)) (cl:third avg)
             (cl:fourth avg) (cl:fifth avg) (cl:round (cl:sixth avg)))
  (cl:force-output))

;;; ---------------------------------------------------------------------------
;;; Load engines
;;; ---------------------------------------------------------------------------

;;; CL engine — mutable heap + mutable hash-tables
(load "benchmarks/lisp-code/lsim-pq.lisp")

;;; Hybrid-A engine — mutable heap + persistent HAMT maps
(load "benchmarks/lisp-code/lsim-pq-hybrid-a.lisp")

;;; Hybrid-B engine — persistent heap + mutable hash-tables
(load "benchmarks/lisp-code/lsim-pq-hybrid-b.lisp")

;;; FOL engine — persistent heap + persistent HAMT maps
(cl-user::load-fol-file "benchmarks/fol-code/lsim-pq.fol")

(in-package :cl-user)

;;; ---------------------------------------------------------------------------
;;; Per-circuit runner: loads circuit, warms up, runs all 4 engines N times.
;;; CL-MODULE-STR is the uppercase string name of the top CL module (e.g. "TOP32").
;;; MAX-TIME is the simulation end time used by the CL run-bench.
;;; Returns (cl-results ha-results hb-results fol-results).
;;; ---------------------------------------------------------------------------

(defun cl-user::run-ablation-circuit (label cl-path fol-path n-runs cl-module-str max-time)
  (cl:format cl:t "~%=== ~A (x~D) ===~%" label n-runs)
  ;; Load circuit definitions into LSIM-CL and LSIM packages.
  (cl:load cl-path)
  (cl-user::load-fol-file fol-path)
  (in-package :cl-user)
  (let* ((cl-fn   (cl:find-symbol "RUN-BENCH" "LSIM-CL"))
         (fol-fn  (cl:find-symbol "RUN-BENCH" "LSIM"))
         (cl-mod  (cl:intern cl-module-str :lsim-cl))
         (ha-fn   (cl:lambda () (lsim-hybrid-a:run-lsim cl-mod max-time)))
         (hb-fn   (cl:lambda () (lsim-hybrid-b:run-lsim cl-mod max-time))))
    ;; Warmup: one run of each engine to JIT-compile and warm caches.
    (cl:funcall cl-fn)
    (cl:funcall ha-fn)
    (cl:funcall hb-fn)
    (cl:funcall fol-fn)
    (sb-ext:gc :full t)
    (let ((cl-results  '())
          (ha-results  '())
          (hb-results  '())
          (fol-results '()))
      (cl:dotimes (i n-runs)
        (let ((cr  (cl-user::bench-run     (cl:lambda () (cl:funcall cl-fn))  "LSIM-CL"))
              (har (cl-user::bench-run     (cl:lambda () (cl:funcall ha-fn))  "LSIM-HYBRID-A"))
              (hbr (cl-user::bench-run     (cl:lambda () (cl:funcall hb-fn))  "LSIM-HYBRID-B"))
              (fr  (cl-user::bench-fol-run (cl:lambda () (cl:funcall fol-fn)))))
          (cl:push cr  cl-results)
          (cl:push har ha-results)
          (cl:push hbr hb-results)
          (cl:push fr  fol-results)
          (when (cl:> n-runs 1)
            (let ((run-label (cl:format cl:nil "~A #~D" label (cl:1+ i))))
              (cl-user::print-ablation-run run-label "CL"      (cl:first cr)  (cl:second cr)  (cl:third cr)  (cl:fourth cr)  (cl:fifth cr)  (cl:sixth cr))
              (cl-user::print-ablation-run run-label "Hybrid-A" (cl:first har) (cl:second har) (cl:third har) (cl:fourth har) (cl:fifth har) (cl:sixth har))
              (cl-user::print-ablation-run run-label "Hybrid-B" (cl:first hbr) (cl:second hbr) (cl:third hbr) (cl:fourth hbr) (cl:fifth hbr) (cl:sixth hbr))
              (cl-user::print-ablation-run run-label "FOL"     (cl:first fr)  (cl:second fr)  (cl:third fr)  (cl:fourth fr)  (cl:fifth fr)  (cl:sixth fr))))))
      (when (cl:= n-runs 1)
        (let ((cr  (cl:first cl-results))
              (har (cl:first ha-results))
              (hbr (cl:first hb-results))
              (fr  (cl:first fol-results)))
          (cl-user::print-ablation-run label "CL"       (cl:first cr)  (cl:second cr)  (cl:third cr)  (cl:fourth cr)  (cl:fifth cr)  (cl:sixth cr))
          (cl-user::print-ablation-run label "Hybrid-A" (cl:first har) (cl:second har) (cl:third har) (cl:fourth har) (cl:fifth har) (cl:sixth har))
          (cl-user::print-ablation-run label "Hybrid-B" (cl:first hbr) (cl:second hbr) (cl:third hbr) (cl:fourth hbr) (cl:fifth hbr) (cl:sixth hbr))
          (cl-user::print-ablation-run label "FOL"      (cl:first fr)  (cl:second fr)  (cl:third fr)  (cl:fourth fr)  (cl:fifth fr)  (cl:sixth fr))))
      (cl:list (cl:nreverse cl-results)
               (cl:nreverse ha-results)
               (cl:nreverse hb-results)
               (cl:nreverse fol-results)))))

;;; ---------------------------------------------------------------------------
;;; Main benchmark
;;; ---------------------------------------------------------------------------

(handler-case
    (progn
      (format t "~%FOL LSim Ablation Benchmark~%")
      (format t "~%Engines:~%")
      (format t "  CL       : mutable CL heap   + mutable CL hash-tables   (baseline)~%")
      (format t "  Hybrid-A : mutable CL heap   + FOL persistent HAMT maps~%")
      (format t "  Hybrid-B : FOL persistent heap + mutable CL hash-tables~%")
      (format t "  FOL      : FOL persistent heap + FOL persistent HAMT maps~%")
      (format t "~%Interpretation:~%")
      (format t "  Hybrid-A ≈ FOL  =>  persistent state maps drive overhead~%")
      (format t "  Hybrid-B ≈ FOL  =>  persistent event heap drives overhead~%")
      (format t "  Both ≈ CL       =>  overhead is in FOL dispatch layers~%")
      (cl-user::print-ablation-header)

      ;; 32bit-300 — 20 individual runs
      (cl-user::run-ablation-circuit "32bit-300"
                                     "benchmarks/lisp-code/32bit-300.lisp"
                                     "benchmarks/fol-code/32bit-300.fol"
                                     20 "TOP32" 300)

      ;; 8x32-900 — 20 individual runs
      (cl-user::run-ablation-circuit "8x32-900"
                                     "benchmarks/lisp-code/8x32-900.lisp"
                                     "benchmarks/fol-code/8x32-900.fol"
                                     20 "TOP8X32" 900)

      ;; 32x32-3000 — 3 averaged runs
      (destructuring-bind (cl-rs ha-rs hb-rs fol-rs)
          (cl-user::run-ablation-circuit "32x32-3000"
                                         "benchmarks/lisp-code/32x32-3000.lisp"
                                         "benchmarks/fol-code/32x32-3000.fol"
                                         3 "TOP32X32" 3000)
        (let ((ca  (cl-user::avg-runs cl-rs))
              (haa (cl-user::avg-runs ha-rs))
              (hba (cl-user::avg-runs hb-rs))
              (fa  (cl-user::avg-runs fol-rs)))
          (cl-user::print-ablation-avg "32x32-3000" "CL"       ca)
          (cl-user::print-ablation-avg "32x32-3000" "Hybrid-A" haa)
          (cl-user::print-ablation-avg "32x32-3000" "Hybrid-B" hba)
          (cl-user::print-ablation-avg "32x32-3000" "FOL"      fa)))

      ;; 8x32x32-9000 — 3 averaged runs
      (destructuring-bind (cl-rs ha-rs hb-rs fol-rs)
          (cl-user::run-ablation-circuit "8x32x32-9000"
                                         "benchmarks/lisp-code/8x32x32-9000.lisp"
                                         "benchmarks/fol-code/8x32x32-9000.fol"
                                         3 "TOP8X32X32" 9000)
        (let ((ca  (cl-user::avg-runs cl-rs))
              (haa (cl-user::avg-runs ha-rs))
              (hba (cl-user::avg-runs hb-rs))
              (fa  (cl-user::avg-runs fol-rs)))
          (cl-user::print-ablation-avg "8x32x32-9000" "CL"       ca)
          (cl-user::print-ablation-avg "8x32x32-9000" "Hybrid-A" haa)
          (cl-user::print-ablation-avg "8x32x32-9000" "Hybrid-B" hba)
          (cl-user::print-ablation-avg "8x32x32-9000" "FOL"      fa)))

      (format t "~%~80A~%" (make-string 80 :initial-element #\=))
      (format t "Ablation benchmark complete.~%"))

  (error (e)
    (format t "~%FATAL ERROR: ~A~%" e)
    (sb-debug:print-backtrace :count 20)
    (sb-ext:exit :code 1)))

(sb-ext:exit :code 0)
