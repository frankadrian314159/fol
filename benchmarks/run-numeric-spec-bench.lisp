;;; Numeric-specialization benchmark: measures *NUMERIC-SPECIALIZATION* applied
;;; on top of *SCALAR-REPLACEMENT*, under the exact same protocol as
;;; run-asr-bench.lisp / Table 1 in the CGO 2027 paper (5M iterations, one
;;; warm-up call, five timed trials, full GC before each, same machine).
;;;
;;; RQ3 of the paper asserts, without a measured figure, that numeric
;;; specialization narrows the ASR residual gap "most on the arithmetic-heavy
;;; loops (Lorenz, Mandelbrot) that gained least from allocation removal."
;;; This script tests that claim directly by running ASR-only vs.
;;; ASR+numeric-specialization on Lorenz and Mandelbrot (the two benchmarks
;;; named) plus Particle as a control (the least arithmetic-heavy benchmark
;;; in Table 1, which should gain the least from this second pass).
;;;
;;; Run from the repository root:
;;;   sbcl --noinform --non-interactive --load benchmarks/run-numeric-spec-bench.lisp

(require :asdf)
(let* ((here (or *load-pathname* *compile-file-pathname*))
       (root (make-pathname :directory (butlast (pathname-directory here))))
       (src  (merge-pathnames "src/" root)))
  (pushnew (truename src) asdf:*central-registry* :test #'equal)
  (handler-bind ((warning #'muffle-warning))
    (asdf:load-system :fol-compiler)))

(defpackage :fol.benchmarks.numspec (:use :cl))
(in-package :fol.benchmarks.numspec)

(defparameter *bench-dir*
  (merge-pathnames "fol-code/"
                   (make-pathname :directory (pathname-directory *load-pathname*))))
(defparameter *iterations* 5000000 "Loop iterations per call -- matches Table 1.")
(defparameter *trials*     20       "Independent timed trials per configuration -- matches Table 1.")

(defun load-fol-file (path sr ns)
  "Compile and evaluate every form in FOL file PATH with scalar replacement
   per SR and numeric specialization per NS (both booleans)."
  (let ((fol.compiler.escape-analysis:*scalar-replacement* sr)
        (fol.compiler.escape-analysis:*numeric-specialization* ns)
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
  (fdefinition (find-symbol (string-upcase name) :fol.core)))

(defun mean (xs) (/ (reduce #'+ xs) (float (length xs))))
(defun stddev (xs)
  (let ((m (mean xs)) (n (length xs)))
    (if (< n 2) 0.0
        (sqrt (/ (reduce #'+ (mapcar (lambda (x) (expt (- x m) 2)) xs))
                 (float (1- n)))))))

(defun measure-once (thunk)
  (sb-ext:gc :full t)
  (let* ((t0 (get-internal-real-time))
         (res (funcall thunk))
         (t1 (get-internal-real-time)))
    (list :secs (/ (- t1 t0) (float internal-time-units-per-second)) :result res)))

(defun trials (thunk n)
  (funcall thunk)
  (loop repeat n collect (measure-once thunk)))

(defun col (plists key) (mapcar (lambda (p) (getf p key)) plists))

(defun bench (label file run-name)
  (let ((path (merge-pathnames file *bench-dir*)))
    (load-fol-file path t nil)
    (let ((asr (trials (let ((f (run-fn run-name))) (lambda () (funcall f *iterations*))) *trials*)))
      (load-fol-file path t t)
      (let ((asr-ns (trials (let ((f (run-fn run-name))) (lambda () (funcall f *iterations*))) *trials*)))
        (let* ((at (col asr :secs)) (nt (col asr-ns :secs))
               (ares (getf (first asr) :result)) (nres (getf (first asr-ns) :result))
               (ok (and (every (lambda (r) (equalp r ares)) (col asr :result))
                        (every (lambda (r) (equalp r nres)) (col asr-ns :result))
                        (equalp ares nres))))
          (format t "~%~A~%" label)
          (format t "  ASR only        : ~7,1F +/- ~5,1F ms~%" (* 1000 (mean at)) (* 1000 (stddev at)))
          (format t "  ASR + numspec   : ~7,1F +/- ~5,1F ms   ~5,2Fx over ASR-only~%"
                  (* 1000 (mean nt)) (* 1000 (stddev nt)) (/ (mean at) (mean nt)))
          (format t "  Result identical (ASR+numspec == ASR-only)? ~A~%" (if ok "YES" "NO -- MISMATCH"))
          (list :label label :asr-ms (* 1000 (mean at)) :ns-ms (* 1000 (mean nt))
                :speedup (/ (mean at) (mean nt))))))))

(defun main ()
  (format t "~%================================================================~%")
  (format t "  Numeric specialization on top of ASR -- RQ3 residual-gap check~%")
  (format t "================================================================~%")
  (format t "  SBCL ~A, ~:D iters/call, 1 warm-up + ~D timed trials, full GC before each~%~%"
          (lisp-implementation-version) *iterations* *trials*)
  (let ((results
          (list (bench "Particle (control, least arithmetic-heavy in Table 1)"
                       "asr-particle.fol" "run-particle")
                (bench "Mandelbrot (named in RQ3's unmeasured claim)"
                       "asr-mandelbrot.fol" "run-mandelbrot")
                (bench "Lorenz (named in RQ3's unmeasured claim)"
                       "asr-lorenz.fol" "run-lorenz"))))
    (format t "~%================================================================~%")
    (format t "  SUMMARY~%")
    (format t "================================================================~%")
    (dolist (r results)
      (format t "  ~50A ASR ~8,1Fms -> ASR+NS ~8,1Fms  (~,2Fx)~%"
              (getf r :label) (getf r :asr-ms) (getf r :ns-ms) (getf r :speedup))))
  (format t "~%Done.~%"))

(main)
