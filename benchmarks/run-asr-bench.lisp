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

;; Conditional reconstruction: clamp x to 0 past a boundary, otherwise move.
(defstruct (nclp (:conc-name nclp-))
  (x 0.0 :type single-float) (y 0.0 :type single-float))
(defun native-clamp (n)
  (declare (fixnum n) (optimize (speed 3) (safety 0)))
  (let ((p (make-nclp :x 0.0 :y 0.0)))
    (dotimes (i n)
      (if (> (nclp-x p) 100.0)
          (setf (nclp-x p) 0.0)
          (setf (nclp-x p) (+ (nclp-x p) 1.0)
                (nclp-y p) (+ (nclp-y p) 0.5))))
    (+ (nclp-x p) (nclp-y p))))

;; Partial reconstruction via assoc: only vx changes each iteration.
(defstruct (nasc (:conc-name nasc-))
  (x 0.0 :type single-float) (y 0.0 :type single-float)
  (vx 0.0 :type single-float) (vy 0.0 :type single-float))
(defun native-assoc (n)
  (declare (fixnum n) (optimize (speed 3) (safety 0)))
  (let ((p (make-nasc :x 0.0 :y 0.0 :vx 0.0 :vy 0.0)))
    (dotimes (i n)
      (setf (nasc-vx p) (+ (nasc-vx p) 0.1)))
    (+ (nasc-x p) (+ (nasc-y p) (+ (nasc-vx p) (nasc-vy p))))))

;; Mandelbrot orbit z <- z^2 + c (c = rabbit).
(defstruct (ncplx (:conc-name ncplx-))
  (re 0.0 :type single-float) (im 0.0 :type single-float))
(defun native-mandelbrot (n)
  (declare (fixnum n) (optimize (speed 3) (safety 0)))
  (let ((z (make-ncplx :re 0.0 :im 0.0)))
    (dotimes (i n)
      (let ((zr (ncplx-re z)) (zi (ncplx-im z)))
        (setf (ncplx-re z) (+ (- (* zr zr) (* zi zi)) -0.123)
              (ncplx-im z) (+ (* 2.0 (* zr zi)) 0.745))))
    (+ (ncplx-re z) (ncplx-im z))))

;; Biquad IIR filter (Direct Form I), constant input.
(defstruct (nbq (:conc-name nbq-))
  (x1 0.0 :type single-float) (x2 0.0 :type single-float)
  (y1 0.0 :type single-float) (y2 0.0 :type single-float))
(defun native-biquad (n)
  (declare (fixnum n) (optimize (speed 3) (safety 0)))
  (let ((st (make-nbq)))
    (dotimes (i n)
      (let* ((x1 (nbq-x1 st)) (x2 (nbq-x2 st))
             (y1 (nbq-y1 st)) (y2 (nbq-y2 st))
             (xin 1.0)
             (y (- (+ (+ (+ (* 0.1 xin) (* 0.2 x1)) (* 0.1 x2)) (* 0.9 y1))
                   (* 0.2 y2))))
        (setf (nbq-x1 st) xin (nbq-x2 st) x1 (nbq-y1 st) y (nbq-y2 st) y1)))
    (nbq-y1 st)))

;; Streaming co-moments (online covariance), constant streams.
(defstruct (ncm (:conc-name ncm-))
  (n 0.0 :type single-float) (mx 0.0 :type single-float)
  (my 0.0 :type single-float) (cxy 0.0 :type single-float))
(defun native-comoments (n)
  (declare (fixnum n) (optimize (speed 3) (safety 0)))
  (let ((st (make-ncm)))
    (dotimes (i n)
      (let* ((cn (ncm-n st)) (mx (ncm-mx st)) (my (ncm-my st)) (cxy (ncm-cxy st))
             (n1 (+ cn 1.0))
             (dx (- 1.0 mx)) (mx1 (+ mx (/ dx n1)))
             (dy (- 2.0 my)) (my1 (+ my (/ dy n1)))
             (dy2 (- 2.0 my1)))
        (setf (ncm-n st) n1 (ncm-mx st) mx1 (ncm-my st) my1
              (ncm-cxy st) (+ cxy (* dx dy2)))))
    (ncm-cxy st)))

;; Minimal single-field counter (the simplest possible loop-carried case).
(defstruct (nctr (:conc-name nctr-))
  (n 0.0 :type single-float))
(defun native-counter (n)
  (declare (fixnum n) (optimize (speed 3) (safety 0)))
  (let ((c (make-nctr :n 0.0)))
    (dotimes (i n)
      (setf (nctr-n c) (+ (nctr-n c) 1.0)))
    (nctr-n c)))

;; Lorenz attractor, semi-explicit Euler.
(defstruct (nl3 (:conc-name nl3-))
  (x 0.0 :type single-float) (y 0.0 :type single-float) (z 0.0 :type single-float))
(defun native-lorenz (n)
  (declare (fixnum n) (optimize (speed 3) (safety 0)))
  (let ((p (make-nl3 :x 1.0 :y 1.0 :z 1.0)))
    (dotimes (i n)
      (let* ((x (nl3-x p)) (y (nl3-y p)) (z (nl3-z p))
             (dx (* 10.0 (- y x)))
             (dy (- (* x (- 28.0 z)) y))
             (dz (- (* x y) (* 2.6666667 z))))
        (setf (nl3-x p) (+ x (* dx 0.01))
              (nl3-y p) (+ y (* dy 0.01))
              (nl3-z p) (+ z (* dz 0.01)))))
    (+ (+ (nl3-x p) (nl3-y p)) (nl3-z p))))

;; 1D constant-velocity Kalman filter (two mutable structs, all reads first).
(defstruct (nks (:conc-name nks-))
  (x 0.0 :type single-float) (v 0.0 :type single-float))
(defstruct (nkc (:conc-name nkc-))
  (p00 1.0 :type single-float) (p01 0.0 :type single-float) (p11 1.0 :type single-float))
(defun native-kalman (n)
  (declare (fixnum n) (optimize (speed 3) (safety 0)))
  (let ((s (make-nks)) (c (make-nkc)))
    (dotimes (i n)
      (let* ((x (nks-x s)) (v (nks-v s))
             (p00 (nkc-p00 c)) (p01 (nkc-p01 c)) (p11 (nkc-p11 c))
             (xp (+ x v))
             (pp00 (+ (+ p00 (* 2.0 p01)) (+ p11 0.001)))
             (pp01 (+ p01 p11))
             (pp11 (+ p11 0.001))
             (y (- 10.0 xp))
             (sden (+ pp00 0.1))
             (k0 (/ pp00 sden))
             (k1 (/ pp01 sden)))
        (setf (nks-x s) (+ xp (* k0 y))
              (nks-v s) (+ v (* k1 y))
              (nkc-p00 c) (* (- 1.0 k0) pp00)
              (nkc-p01 c) (* (- 1.0 k0) pp01)
              (nkc-p11 c) (- pp11 (* k1 pp01)))))
    (nks-x s)))

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
                       "asr-twobody.fol"    "run-twobody"    #'native-twobody)
                (bench "K. Clamp (conditional)  <point>{x,y}"
                       "asr-clamp.fol"      "run-clamp"      #'native-clamp)
                (bench "L. Assoc (partial)      <particle>{x,y,vx,vy}"
                       "asr-assoc.fol"      "run-assoc"      #'native-assoc)
                (bench "E. Mandelbrot orbit     <cplx>{re,im}"
                       "asr-mandelbrot.fol"  "run-mandelbrot"  #'native-mandelbrot)
                (bench "F. Kalman filter        2x<kstate>/<kcov>"
                       "asr-kalman.fol"      "run-kalman"      #'native-kalman)
                (bench "G. Biquad IIR filter    <biquad>{x1,x2,y1,y2}"
                       "asr-biquad.fol"      "run-biquad"      #'native-biquad)
                (bench "H. Streaming co-moments <comoments>{n,mx,my,cxy}"
                       "asr-comoments.fol"   "run-co-moments"  #'native-comoments)
                (bench "I. Lorenz attractor     <lvec3>{x,y,z}"
                       "asr-lorenz.fol"      "run-lorenz"      #'native-lorenz)
                (bench "J. Counter (minimal)    <ctr>{n}"
                       "asr-counter.fol"     "run-counter"     #'native-counter))))
    (summary results)
    (format t "~%Done.~%")))

(main)
