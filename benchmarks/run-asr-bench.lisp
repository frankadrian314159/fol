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

;;; --- Native mutable-defstruct baselines (the performance ceiling) ---------
;;; The idiomatic imperative equivalent of each benchmark: a mutable defstruct
;;; updated in place (setf slot) each iteration. Single-float slots match FOL's
;;; float type so results are directly comparable. This is the "native mutable
;;; struct" the paper's motivation contrasts against; it allocates one struct
;;; total and shows what the loop costs with no persistence and no allocation.
(defstruct (npt  (:conc-name npt-))
  (x  0.0 :type single-float) (y  0.0 :type single-float))
(defstruct (nrot (:conc-name nrot-))
  (re 0.0 :type single-float) (im 0.0 :type single-float))
(defstruct (nst3 (:conc-name nst3-))
  (x  0.0 :type single-float) (y  0.0 :type single-float) (vy 0.0 :type single-float))

(defun native-particle (n)
  (declare (fixnum n) (optimize (speed 3) (safety 0)))
  (let ((p (make-npt :x 0.0 :y 0.0)))
    (dotimes (i n)
      (setf (npt-x p) (+ (npt-x p) 0.1)
            (npt-y p) (+ (npt-y p) 0.2)))
    (+ (npt-x p) (npt-y p))))

(defun native-rotation (n)
  (declare (fixnum n) (optimize (speed 3) (safety 0)))
  (let ((z (make-nrot :re 1.0 :im 0.0)))
    (dotimes (i n)
      (let ((re (nrot-re z)) (im (nrot-im z)))
        (setf (nrot-re z) (- (* re 0.9950041652780258) (* im 0.09983341664682815))
              (nrot-im z) (+ (* re 0.09983341664682815) (* im 0.9950041652780258)))))
    (+ (nrot-re z) (nrot-im z))))

(defun native-projectile (n)
  (declare (fixnum n) (optimize (speed 3) (safety 0)))
  (let ((s (make-nst3 :x 0.0 :y 0.0 :vy 20.0)))
    (dotimes (i n)
      (let ((nvy (- (nst3-vy s) 0.098)))
        (setf (nst3-x s)  (+ (nst3-x s) 1.0)
              (nst3-y s)  (+ (nst3-y s) nvy)
              (nst3-vy s) nvy)))
    (+ (nst3-x s) (+ (nst3-y s) (nst3-vy s)))))

;; Multi-accumulator: two mutable structs updated together, all old values read
;; before any is written (matching the parallel recur semantics of the FOL loop).
(defstruct (nv2 (:conc-name nv2-))
  (x 0.0 :type single-float) (y 0.0 :type single-float))

(defun native-twobody (n)
  (declare (fixnum n) (optimize (speed 3) (safety 0)))
  (let ((a (make-nv2 :x 0.0 :y 0.0))
        (b (make-nv2 :x 1.0 :y 1.0)))
    (dotimes (i n)
      (let ((ax (nv2-x a)) (ay (nv2-y a)) (bx (nv2-x b)) (by (nv2-y b)))
        (setf (nv2-x a) (+ ax (* 0.01 (- bx ax)))
              (nv2-y a) (+ ay (* 0.01 (- by ay)))
              (nv2-x b) (+ bx (* 0.01 (- ax bx)))
              (nv2-y b) (+ by (* 0.01 (- ay by))))))
    (+ (nv2-x a) (nv2-y a))))

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

(defun bench (label file run-name native-fn)
  (let ((path (merge-pathnames file *bench-dir*)))
    (load-fol-file path nil)
    (let ((base (trials (let ((f (run-fn run-name)))
                          (lambda () (funcall f *iterations*)))
                        *trials*)))
      (load-fol-file path t)
      (let ((asr (trials (let ((f (run-fn run-name)))
                           (lambda () (funcall f *iterations*)))
                         *trials*))
            (nat (trials (lambda () (funcall native-fn *iterations*)) *trials*)))
        (report label base asr nat)
        (list :label label :base base :asr asr :native nat)))))

;;; --- Reporting -----------------------------------------------------------
(defun report (label base asr nat)
  (let* ((bt (col base :secs)) (at (col asr :secs)) (nt (col nat :secs))
         (asr-sp (mapcar #'/ bt at)) (nat-sp (mapcar #'/ bt nt))
         (bbytes (mean (col base :bytes))) (abytes (mean (col asr :bytes)))
         (nbytes (mean (col nat :bytes)))
         (bgc  (mean (col base :gc)))      (agc  (mean (col asr :gc)))
         (bgcs (mean (col base :gc-secs))) (agcs (mean (col asr :gc-secs)))
         (bres (getf (first base) :result)) (ares (getf (first asr) :result))
         (nres (getf (first nat) :result))
         (ok   (and (every (lambda (r) (equalp r bres)) (col base :result))
                    (every (lambda (r) (equalp r ares)) (col asr :result))
                    (equalp bres ares))))
    (format t "~%~A~%" label)
    (format t "  ~:D iterations, ~D trials~%" *iterations* *trials*)
    (format t "  ~19A ~17A ~14A ~14A~%"
            "" "Baseline (persist)" "ASR" "Native struct")
    (format t "  Wall time (ms)      ~7,1F +/-~5,1F  ~5,1F +/-~4,1F  ~5,1F +/-~4,1F~%"
            (* 1000 (mean bt)) (* 1000 (stddev bt))
            (* 1000 (mean at)) (* 1000 (stddev at))
            (* 1000 (mean nt)) (* 1000 (stddev nt)))
    (format t "  Speedup vs baseline ~10A       ~5,2Fx        ~5,2Fx~%"
            "1.00x" (mean asr-sp) (mean nat-sp))
    (format t "  Alloc (B/iter)      ~10,1F       ~7,1F       ~7,1F~%"
            (/ bbytes *iterations*) (/ abytes *iterations*) (/ nbytes *iterations*))
    (format t "  GC (count / ms per call): baseline ~,1F / ~,1F ; ASR ~,1F / ~,1F~%"
            bgc (* 1000 bgcs) agc (* 1000 agcs))
    (format t "  ASR reaches ~,0F%% of native speed (ASR ~,2Fx native wall time)~%"
            (* 100 (/ (mean nt) (mean at))) (/ (mean at) (mean nt)))
    (format t "  Result identical (ASR==baseline)? ~A ; native = ~A~%"
            (if ok "YES" "NO -- MISMATCH") nres)))

(defun summary (results)
  (format t "~%================================================================~%")
  (format t "  SUMMARY (mean over ~D trials)~%" *trials*)
  (format t "================================================================~%")
  (format t "  ~26A ~9A ~8A ~9A ~8A ~9A ~8A~%"
          "Benchmark" "Base ms" "ASR ms" "Nat ms" "ASR x" "Native x" "ASR/Nat")
  (format t "  ~26A ~9A ~8A ~9A ~8A ~9A ~8A~%"
          (make-string 26 :initial-element #\-) (make-string 9 :initial-element #\-)
          (make-string 8 :initial-element #\-) (make-string 9 :initial-element #\-)
          (make-string 8 :initial-element #\-) (make-string 9 :initial-element #\-)
          (make-string 8 :initial-element #\-))
  (dolist (r results)
    (let* ((base (getf r :base)) (asr (getf r :asr)) (nat (getf r :native))
           (bt (col base :secs)) (at (col asr :secs)) (nt (col nat :secs)))
      (format t "  ~26A ~9,1F ~8,1F ~9,1F ~7,2Fx ~8,2Fx ~7,2Fx~%"
              (getf r :label)
              (* 1000 (mean bt)) (* 1000 (mean at)) (* 1000 (mean nt))
              (mean (mapcar #'/ bt at)) (mean (mapcar #'/ bt nt))
              (/ (mean at) (mean nt))))))

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
                       "asr-particle.fol"   "run-particle"   #'native-particle)
                (bench "A. 2D rotation orbit    <rot>{re,im}"
                       "asr-rotation.fol"   "run-rotation"   #'native-rotation)
                (bench "B. Ballistic integrator <state3>{x,y,vy}"
                       "asr-projectile.fol" "run-projectile" #'native-projectile)
                (bench "D. Two-body relaxation  2x<vec2>{x,y}"
                       "asr-twobody.fol"    "run-twobody"    #'native-twobody))))
    (summary results)
    (format t "~%Done.~%")))

(main)
