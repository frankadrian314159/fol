;;; RQ7 statistical-power check, current-compiler side (PLDI 2027 paper).
;;;
;;; The dict-loop Off-vs-v0.1.1 comparison in RQ7/Threats-to-Validity was
;;; originally run at n=5, "not powered to distinguish a small [difference]
;;; from noise." This script re-measures the CURRENT compiler's side of that
;;; comparison (all optimization flags off) at n=30, matching the small-N
;;; rows' protocol (Table~\ref{tab:microbenchmarks} caption) so the pair can
;;; actually resolve a small difference. Run the v0.1.1-side companion script
;;; (run-rq7-power-check-v011.lisp) against the v0.1.1 worktree separately --
;;; the two compilers can't load in the same image (v0.1.1 predates
;;; escape-analysis.lisp entirely, but more importantly running both from the
;;; same package definitions would collide).
;;;
;;; Run from the repository root:
;;;   sbcl --noinform --non-interactive --load benchmarks/run-rq7-power-check-current.lisp

(require :asdf)
(let* ((here (or *load-pathname* *compile-file-pathname*))
       (root (make-pathname :directory (butlast (pathname-directory here))))
       (src  (merge-pathnames "src/" root)))
  (pushnew (truename src) asdf:*central-registry* :test #'equal)
  (handler-bind ((warning #'muffle-warning))
    (asdf:load-system :fol-compiler)))

(defpackage :fol.benchmarks.rq7 (:use :cl))
(in-package :fol.benchmarks.rq7)

(defparameter *trials* 30
  "Matches the small-N rows' protocol (Table 1 caption): enough trials to
   resolve a difference well under the ~4% relative noise floor seen on
   this machine, rather than the n=5 used for the large workloads.")
(defparameter *warmup-iters* 3)

(defun mean (xs) (/ (reduce #'+ xs) (float (length xs))))
(defun sd (xs)
  (let ((m (mean xs)) (n (length xs)))
    (if (< n 2) 0.0
        (sqrt (/ (reduce #'+ (mapcar (lambda (x) (expt (- x m) 2)) xs))
                 (float (1- n)))))))

(defun trials (thunk)
  (dotimes (_ *warmup-iters*) (funcall thunk))
  (loop repeat *trials*
        collect (progn
                  (sb-ext:gc :full t)
                  (let ((t0 (get-internal-real-time)))
                    (funcall thunk)
                    (/ (- (get-internal-real-time) t0)
                       (float internal-time-units-per-second))))))

(defparameter +dict-loop-src+
  "(defn rq7-dict-loop [n] (loop [acc {} i 0] (if (< i n) (recur (assoc acc i i) (inc i)) acc)))")

(defun compile-fol-off (src)
  "Compile+eval SRC with every optimization flag off (the Off baseline)."
  (let ((fol.compiler.escape-analysis:*transient-loops* nil)
        (fol.compiler.escape-analysis:*scalar-replacement* nil)
        (fol.compiler.escape-analysis:*numeric-specialization* nil)
        (fol.compiler.escape-analysis:*stack-closures* nil)
        (fol.compiler::*optimize-constructors* nil)
        (*readtable* fol.compiler.reader:*fol-readtable*)
        (*package* (find-package :fol.core)))
    (with-input-from-string (in src)
      (loop for f = (read in nil :eof) until (eq f :eof)
            do (eval (fol.compiler:compilation-result-code (fol.compiler:compile-form f)))))))

(defun main ()
  (compile-fol-off +dict-loop-src+)
  (let* ((fn (fdefinition (find-symbol "RQ7-DICT-LOOP" :fol.core)))
         (n 200000)
         (times (trials (lambda () (funcall fn n)))))
    (format t "~&=== RQ7 power check: CURRENT compiler, Off, dict-loop 200k assocs ===~%")
    (format t "SBCL ~A, dynamic space ~,0F MB, ~D trials~%"
            (lisp-implementation-version) (/ (sb-ext:dynamic-space-size) 1048576.0) *trials*)
    (format t "mean: ~,4F ms   sd: ~,4F ms   n: ~D~%"
            (* 1000 (mean times)) (* 1000 (sd times)) (length times))
    (format t "raw (ms): ~{~,2F~^ ~}~%" (mapcar (lambda (x) (* 1000 x)) times))))

(main)
