;;; LSim Off-vs-On benchmark (PLDI 2027 paper, RQ6/RQ7 consolidation).
;;;
;;; RQ6's LSim wall-clock/allocation figures and RQ7's LSim world-guard
;;; comparison previously retained "original development-machine"
;;; (Ryzen 9 5900X) measurements, mixing machines with RQ2's Ryzen 5 7430U
;;; figures. This script re-measures the Off-vs-On comparison on the RQ2
;;; machine, for the 8bit-100 circuit (the paper's "LSim (8-bit)" label):
;;; compiles+loads the LSim engine (lsim-pq.fol) plus the 8bit-100 circuit
;;; definition, once with every optimization flag off, once with every flag
;;; on (redefining the same functions in place -- LSim's own package is
;;; fixed by its `(in-package "lsim")` declaration, so off/on run
;;; sequentially in one process rather than coexisting side by side, the
;;; way the microbenchmark harness's suffix-renamed variants do).
;;;
;;; Run from the repository root:
;;;   sbcl --noinform --non-interactive --load benchmarks/run-lsim-offon-bench.lisp

(require :asdf)
(let* ((here (or *load-pathname* *compile-file-pathname*))
       (root (make-pathname :directory (butlast (pathname-directory here))))
       (src  (merge-pathnames "src/" root)))
  (pushnew (truename src) asdf:*central-registry* :test #'equal)
  (handler-bind ((warning #'muffle-warning))
    (asdf:load-system :fol-compiler/core)))

(defpackage :fol.benchmarks.lsim-offon (:use :cl))
(in-package :fol.benchmarks.lsim-offon)

(defparameter *trials* 30)
(defparameter *warmup-iters* 3)

(defun load-fol-file* (path &key optimize transient-only)
  "Compile+eval every form in the FOL file at PATH, with every optimization
   flag bound to OPTIMIZE (mirrors run-transient-bench.lisp's COMPILE-FOL,
   applied to a whole file via cl:read/compile-form/eval instead of a
   single source string, since LSim spans multiple top-level forms across
   two files sharing one fixed package). TRANSIENT-ONLY isolates transient
   conversion from the other four flags, mirroring RQ2's ablation."
  (let ((fol.compiler.escape-analysis:*transient-loops* (or optimize transient-only))
        (fol.compiler.escape-analysis:*scalar-replacement* (and optimize (not transient-only)))
        (fol.compiler.escape-analysis:*numeric-specialization* (and optimize (not transient-only)))
        (fol.compiler.escape-analysis:*stack-closures* (and optimize (not transient-only)))
        (fol.compiler::*optimize-constructors* (and optimize (not transient-only)))
        (*readtable* fol.compiler.reader:*fol-readtable*)
        (*package* (find-package :fol.core)))
    (with-open-file (in path)
      (loop for f = (read in nil :eof) until (eq f :eof)
            do (eval (fol.compiler:compilation-result-code (fol.compiler:compile-form f)))))))

(defun gate-evals ()
  (funcall (find-symbol "DEREF" "FOL.COMPILER.MUTABLE")
           (symbol-value (find-symbol "*GATE-EVALS*" "LSIM"))))

(defun run-bench-fn () (fdefinition (find-symbol "RUN-BENCH" "LSIM")))

(defun bench-once ()
  (sb-ext:gc :full t)
  (let ((b0 (sb-ext:get-bytes-consed))
        (t0 (get-internal-real-time))
        (result (funcall (run-bench-fn))))
    (list (/ (- (get-internal-real-time) t0) (float internal-time-units-per-second))
          (- (sb-ext:get-bytes-consed) b0)
          result
          (gate-evals))))

(defun mean (xs) (/ (reduce #'+ xs) (float (length xs))))
(defun sd (xs)
  (let ((m (mean xs)) (n (length xs)))
    (if (< n 2) 0.0
        (sqrt (/ (reduce #'+ (mapcar (lambda (x) (expt (- x m) 2)) xs))
                 (float (1- n)))))))

(defun run-side (label optimize &key transient-only)
  (load-fol-file* "benchmarks/fol-code/lsim-pq.fol" :optimize optimize :transient-only transient-only)
  (load-fol-file* "benchmarks/fol-code/8bit-100.fol" :optimize optimize :transient-only transient-only)
  (dotimes (_ *warmup-iters*) (bench-once))
  (let* ((runs (loop repeat *trials* collect (bench-once)))
         (times (mapcar #'first runs))
         (bytes (mapcar #'second runs))
         (evals (fourth (first runs)))
         (result (third (first runs))))
    (format t "~&~A: ~,2F +/- ~,2F ms   ~,3F +/- ~,3F MB/call   gate-evals=~:D~%"
            label (* 1000 (mean times)) (* 1000 (sd times))
            (/ (mean bytes) 1048576.0) (/ (sd bytes) 1048576.0) evals)
    (list (mean times) (mean bytes) result evals)))

(format t "~&=== LSim Off-vs-On, 8bit-100 circuit (re-measured on RQ2 machine) ===~%")
(format t "SBCL ~A, dynamic space ~,0F MB, ~D trials (mean +/- sd), full GC before each~%~%"
        (lisp-implementation-version) (/ (sb-ext:dynamic-space-size) 1048576.0) *trials*)

(let ((off (run-side "Off" nil))
      (tc  (run-side "TC " nil :transient-only t))
      (on  (run-side "On " t)))
  (destructuring-bind (off-t off-b off-r off-e) off
    (destructuring-bind (tc-t tc-b tc-r tc-e) tc
      (destructuring-bind (on-t on-b on-r on-e) on
        (format t "~%TC-only speedup: ~,3Fx time   ~,3Fx alloc~%" (/ off-t tc-t) (/ off-b (max 1.0 tc-b)))
        (format t "All-5   speedup: ~,3Fx time   ~,3Fx alloc~%" (/ off-t on-t) (/ off-b (max 1.0 on-b)))
        (format t "gate-evals match: ~A (off=~:D tc=~:D on=~:D)~%" (and (= off-e tc-e) (= off-e on-e)) off-e tc-e on-e)
        (format t "results byte-identical: ~A (tc) ~A (on)~%" (equalp off-r tc-r) (equalp off-r on-r))))))

(format t "~&Done.~%")
