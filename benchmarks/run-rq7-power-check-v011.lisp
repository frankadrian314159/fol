;;; RQ7 statistical-power check, v0.1.1 side (PLDI 2027 paper).
;;;
;;; Companion to run-rq7-power-check-current.lisp. This file lives in the
;;; main repo for reproducibility, but must be RUN from a checkout/worktree
;;; of the v0.1.1 tag (e.g. `git worktree add ../fol-v011 v0.1.1`), since it
;;; measures the pre-work compiler, not the current one:
;;;   cp benchmarks/run-rq7-power-check-v011.lisp ../fol-v011/benchmarks/
;;;   cd ../fol-v011 && sbcl --noinform --non-interactive \
;;;     --load benchmarks/run-rq7-power-check-v011.lisp
;;;
;;; Measures the same dict-loop workload against the pre-work compiler at
;;; n=30, so the Off-vs-v0.1.1 comparison in RQ7 is actually powered to
;;; resolve a small difference (the original n=5 comparison was not).

(require :asdf)
(let* ((here (or *load-pathname* *compile-file-pathname*))
       (root (make-pathname :directory (butlast (pathname-directory here))))
       (src  (merge-pathnames "src/" root)))
  (pushnew (truename src) asdf:*central-registry* :test #'equal)
  (handler-bind ((warning #'muffle-warning))
    (asdf:load-system :fol-compiler)))

(defpackage :fol.benchmarks.rq7 (:use :cl))
(in-package :fol.benchmarks.rq7)

(defparameter *trials* 30)
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

(defun compile-fol (src)
  (let ((*readtable* fol.compiler.reader:*fol-readtable*)
        (*package* (find-package :fol.core)))
    (with-input-from-string (in src)
      (loop for f = (read in nil :eof) until (eq f :eof)
            do (eval (fol.compiler:compilation-result-code (fol.compiler:compile-form f)))))))

(defun main ()
  (compile-fol +dict-loop-src+)
  (let* ((fn (fdefinition (find-symbol "RQ7-DICT-LOOP" :fol.core)))
         (n 200000)
         (times (trials (lambda () (funcall fn n)))))
    (format t "~&=== RQ7 power check: v0.1.1 compiler, dict-loop 200k assocs ===~%")
    (format t "SBCL ~A, dynamic space ~,0F MB, ~D trials~%"
            (lisp-implementation-version) (/ (sb-ext:dynamic-space-size) 1048576.0) *trials*)
    (format t "mean: ~,4F ms   sd: ~,4F ms   n: ~D~%"
            (* 1000 (mean times)) (* 1000 (sd times)) (length times))
    (format t "raw (ms): ~{~,2F~^ ~}~%" (mapcar (lambda (x) (* 1000 x)) times))))

(main)
