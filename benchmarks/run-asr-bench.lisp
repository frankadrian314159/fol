;;; Aggregate Scalar Replacement (ASR) benchmark driver
;;;
;;; Compiles each ASR benchmark twice -- once with scalar replacement OFF
;;; (baseline: one persistent record consed per iteration) and once with it
;;; ON -- runs both, and reports wall time, per-call allocation, speedup, and
;;; a check that the optimized result is bit-identical to the baseline.
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

(defun measure (thunk reps)
  "Warm up, force a full GC, then run THUNK REPS times. Returns
   (values seconds-per-call bytes-consed-per-call last-result)."
  (funcall thunk)                       ; warm up (compile/caches)
  (sb-ext:gc :full t)
  (let ((b0 (sb-ext:get-bytes-consed))
        (t0 (get-internal-real-time))
        (result nil))
    (dotimes (_ reps) (setf result (funcall thunk)))
    (let ((secs  (/ (- (get-internal-real-time) t0)
                    (float internal-time-units-per-second)))
          (bytes (- (sb-ext:get-bytes-consed) b0)))
      (values (/ secs reps) (/ bytes (float reps)) result))))

(defun bench (label file run-name iters reps)
  (let ((path (merge-pathnames file *bench-dir*)))
    ;; --- Baseline: scalar replacement OFF ---
    (load-fol-file path nil)
    (multiple-value-bind (bsecs bbytes bres)
        (measure (let ((f (run-fn run-name))) (lambda () (funcall f iters))) reps)
      ;; --- Optimized: scalar replacement ON (redefines the same functions) ---
      (load-fol-file path t)
      (multiple-value-bind (osecs obytes ores)
          (measure (let ((f (run-fn run-name))) (lambda () (funcall f iters))) reps)
        (report label iters bsecs bbytes bres osecs obytes ores)))))

(defun report (label iters bsecs bbytes bres osecs obytes ores)
  (format t "~%~A  (~:D iterations, result = ~A)~%" label iters bres)
  (format t "  ~24A ~14A ~14A ~10A~%" "" "Baseline" "ASR on" "Ratio")
  (format t "  ~24A ~14A ~14A ~10A~%"
          (make-string 24 :initial-element #\-)
          (make-string 14 :initial-element #\-)
          (make-string 14 :initial-element #\-)
          (make-string 10 :initial-element #\-))
  (format t "  ~24A ~11,1F ms ~11,1F ms ~8,2Fx~%"
          "Wall time / call" (* 1000 bsecs) (* 1000 osecs)
          (if (zerop osecs) 0.0 (/ bsecs osecs)))
  (format t "  ~24A ~11,2F MB ~11,2F MB ~8,4F~%"
          "Allocated / call"
          (/ bbytes 1048576.0) (/ obytes 1048576.0)
          (if (zerop bbytes) 0.0 (/ obytes bbytes)))
  (format t "  ~24A ~11,1F B  ~11,1F B~%"
          "Allocated / iteration"
          (/ bbytes iters) (/ obytes iters))
  (format t "  ~24A ~A~%"
          "Result identical?"
          (if (equalp bres ores) "YES (bit-identical)"
              (format nil "NO  (~A vs ~A)" bres ores))))

(defun main ()
  (format t "~%================================================================~%")
  (format t "  Aggregate Scalar Replacement -- benchmark suite~%")
  (format t "  SBCL ~A~%" (lisp-implementation-version))
  (format t "================================================================~%")
  (bench "C. Particle simulation  <particle>{x,y}"
         "asr-particle.fol"   "run-particle"   5000000 5)
  (bench "A. 2D rotation orbit   <rot>{re,im}"
         "asr-rotation.fol"   "run-rotation"   5000000 5)
  (bench "B. Ballistic integrator <state3>{x,y,vy}"
         "asr-projectile.fol" "run-projectile" 5000000 5)
  (format t "~%Done.~%"))

(main)
