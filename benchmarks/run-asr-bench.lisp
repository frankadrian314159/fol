;;; Aggregate Scalar Replacement (ASR) benchmark driver
;;;
;;; Compiles each ASR benchmark twice -- once with scalar replacement OFF
;;; (baseline: one persistent record consed per iteration) and once with it ON
;;; -- and runs FIVE independent timed trials of each configuration. Reports,
;;; per benchmark: wall time (mean +/- sample stddev), paired speedup
;;; (mean +/- stddev), per-call and per-iteration allocation, GC collections
;;; per call, and time spent in GC per call, plus a check that the optimized
;;; result is bit-identical to the baseline. An environment header records the
;;; CPU, SBCL version, heap size, and GC nursery so the numbers are reproducible.
;;;
;;; Run from the repository root:
;;;   sbcl --noinform --non-interactive --load benchmarks/run-asr-bench.lisp

(require :asdf)

;; Locate the repo root relative to this file (benchmarks/ -> ../src) and load
;; the FOL compiler.
(let* ((here (or *load-pathname* *compile-file-pathname*))
       (root (make-pathname :directory (butlast (pathname-directory here))))
       (src  (merge-pathnames "src/" root)))
  (pushnew (truename src) asdf:*central-registry* :test #'equal)
  (handler-bind ((warning #'muffle-warning))
    (asdf:load-system :fol-compiler)))

(defpackage :fol.benchmarks.asr (:use :cl))
(in-package :fol.benchmarks.asr)

(defparameter *bench-dir*
  (merge-pathnames "fol-code/"
                   (make-pathname :directory (pathname-directory *load-pathname*))))
(defparameter *iterations* 5000000 "Loop iterations per call.")
(defparameter *trials*     5        "Independent timed trials per configuration.")

;;; --- GC accounting -------------------------------------------------------
(defvar *gc-count* 0 "Incremented by an after-GC hook while trials run.")
(defun bump-gc () (incf *gc-count*))
(defun install-gc-counter () (pushnew 'bump-gc sb-ext:*after-gc-hooks*))

;;; --- Compiling and running FOL benchmark files ---------------------------
(defun load-fol-file (path sr)
  "Compile and evaluate every form in FOL file PATH with scalar replacement
   per SR (NIL = baseline, T = optimized). Returns the last form's value."
  (let ((fol.compiler.escape-analysis:*scalar-replacement* sr)
        (*readtable* fol.compiler.reader:*fol-readtable*)
        (*package* (find-package :fol.core))
        (val nil))
    (with-open-file (in path :direction :input)
      (loop for form = (read in nil :eof)
            until (eq form :eof)
            do (setf val (eval (fol.compiler:compilation-result-code
                                (fol.compiler:compile-form form))))))
    val))

(defun run-fn (name)
  "The compiled FOL run-function object, by (hyphenated) name string."
  (fdefinition (find-symbol (string-upcase name) :fol.core)))

;;; --- Statistics ----------------------------------------------------------
(defun mean (xs) (/ (reduce #'+ xs) (float (length xs))))
(defun stddev (xs)
  "Sample (n-1) standard deviation."
  (let ((m (mean xs)) (n (length xs)))
    (if (< n 2) 0.0
        (sqrt (/ (reduce #'+ (mapcar (lambda (x) (expt (- x m) 2)) xs))
                 (float (1- n)))))))
(defun col (plists key) (mapcar (lambda (p) (getf p key)) plists))

;;; --- Measurement ---------------------------------------------------------
(defun measure-once (thunk)
  "One measured call: force a full GC, then time a single call while capturing
   bytes consed, GC completions, and GC run-time over the call."
  (sb-ext:gc :full t)
  (let* ((gc0  *gc-count*)
         (grt0 sb-ext:*gc-run-time*)
         (b0   (sb-ext:get-bytes-consed))
         (t0   (get-internal-real-time))
         (res  (funcall thunk))
         (t1   (get-internal-real-time))
         (b1   (sb-ext:get-bytes-consed))
         (grt1 sb-ext:*gc-run-time*)
         (gc1  *gc-count*))
    (list :secs    (/ (- t1 t0) (float internal-time-units-per-second))
          :bytes   (- b1 b0)
          :gc      (- gc1 gc0)
          :gc-secs (/ (- grt1 grt0) (float internal-time-units-per-second))
          :result  res)))

(defun trials (thunk n)
  "One warm-up call, then N measured calls; returns a list of per-call plists."
  (funcall thunk)
  (loop repeat n collect (measure-once thunk)))

(defun bench (label file run-name)
  (let ((path (merge-pathnames file *bench-dir*)))
    (load-fol-file path nil)
    (let ((base (trials (let ((f (run-fn run-name)))
                          (lambda () (funcall f *iterations*)))
                        *trials*)))
      (load-fol-file path t)
      (let ((asr (trials (let ((f (run-fn run-name)))
                           (lambda () (funcall f *iterations*)))
                         *trials*)))
        (report label base asr)
        (list :label label :base base :asr asr)))))

;;; --- Reporting -----------------------------------------------------------
(defun report (label base asr)
  (let* ((bt (col base :secs)) (at (col asr :secs))
         (speedups (mapcar #'/ bt at))
         (bbytes (mean (col base :bytes))) (abytes (mean (col asr :bytes)))
         (bgc  (mean (col base :gc)))      (agc  (mean (col asr :gc)))
         (bgcs (mean (col base :gc-secs))) (agcs (mean (col asr :gc-secs)))
         (bres (getf (first base) :result)) (ares (getf (first asr) :result))
         (ok   (and (every (lambda (r) (equalp r bres)) (col base :result))
                    (every (lambda (r) (equalp r ares)) (col asr :result))
                    (equalp bres ares))))
    (format t "~%~A~%" label)
    (format t "  ~:D iterations, ~D trials, result = ~A~%" *iterations* *trials* bres)
    (format t "  ~20A ~14A ~14A~%" "" "Baseline" "ASR on")
    (format t "  Wall time (ms)       ~6,1F +/-~5,1F  ~6,1F +/-~5,1F~%"
            (* 1000 (mean bt)) (* 1000 (stddev bt))
            (* 1000 (mean at)) (* 1000 (stddev at)))
    (format t "  Speedup (paired)     ~6,2Fx +/-~5,2F~%"
            (mean speedups) (stddev speedups))
    (format t "  Alloc (MB/call)      ~9,2F      ~9,2F~%"
            (/ bbytes 1048576.0) (/ abytes 1048576.0))
    (format t "  Alloc (B/iter)       ~9,1F      ~9,1F~%"
            (/ bbytes *iterations*) (/ abytes *iterations*))
    (format t "  GC collections/call  ~9,1F      ~9,1F~%" bgc agc)
    (format t "  GC time (ms/call)    ~9,1F      ~9,1F~%" (* 1000 bgcs) (* 1000 agcs))
    (format t "  Result identical?    ~A~%"
            (if ok "YES (bit-identical, all trials)" "NO -- MISMATCH"))))

(defun summary (results)
  (format t "~%================================================================~%")
  (format t "  SUMMARY (mean over ~D trials)~%" *trials*)
  (format t "================================================================~%")
  (format t "  ~26A ~10A ~10A ~9A ~10A~%"
          "Benchmark" "Base ms" "ASR ms" "Speedup" "Base MB")
  (format t "  ~26A ~10A ~10A ~9A ~10A~%"
          (make-string 26 :initial-element #\-) (make-string 10 :initial-element #\-)
          (make-string 10 :initial-element #\-) (make-string 9 :initial-element #\-)
          (make-string 10 :initial-element #\-))
  (dolist (r results)
    (let* ((base (getf r :base)) (asr (getf r :asr))
           (bt (col base :secs)) (at (col asr :secs)))
      (format t "  ~26A ~10,1F ~10,1F ~8,2Fx ~10,2F~%"
              (getf r :label)
              (* 1000 (mean bt)) (* 1000 (mean at))
              (mean (mapcar #'/ bt at))
              (/ (mean (col base :bytes)) 1048576.0)))))

(defun env-header ()
  (format t "~%================================================================~%")
  (format t "  Aggregate Scalar Replacement -- benchmark suite~%")
  (format t "================================================================~%")
  (format t "  SBCL           : ~A~%" (lisp-implementation-version))
  (format t "  Machine        : ~A / ~A~%"
          (machine-type) (or (ignore-errors (machine-version)) "?"))
  (format t "  Dynamic space  : ~,0F MB~%"
          (/ (sb-ext:dynamic-space-size) 1048576.0))
  (format t "  GC             : generational; nursery ~,1F MB (bytes-consed-between-gcs)~%"
          (/ (sb-ext:bytes-consed-between-gcs) 1048576.0))
  (format t "  Protocol       : ~D iters/call, 1 warm-up + ~D timed trials, full GC before each~%"
          *iterations* *trials*))

(defun main ()
  (install-gc-counter)
  (env-header)
  (let ((results
          (list (bench "C. Particle simulation  <particle>{x,y}"
                       "asr-particle.fol"   "run-particle")
                (bench "A. 2D rotation orbit    <rot>{re,im}"
                       "asr-rotation.fol"   "run-rotation")
                (bench "B. Ballistic integrator <state3>{x,y,vy}"
                       "asr-projectile.fol" "run-projectile"))))
    (summary results)
    (format t "~%Done.~%")))

(main)
