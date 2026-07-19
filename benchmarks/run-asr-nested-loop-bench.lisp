;;; ASR whole-program benchmark: fastmath's nested-loop Vec2 read (CGO 2027
;;; paper, Discussion -- corpus study, second of the two "learnable shapes").
;;;
;;; fastmath (github.com/generateme/fastmath, a widely used Clojure numeric
;;; library) has a DLA-style random-walk aggregation whose outer loop
;;; carries a Vec2 accumulator `rr`; nested inside its body is a second
;;; loop that reads `rr`'s fields (`.x`, `.y`) several `let`/`if`/`case`
;;; layers deep to compute a scalar, which then feeds the outer loop's own
;;; reconstruction. ASR previously aborted the whole outer reconstruction
;;; the instant it saw the accumulator referenced anywhere inside a nested
;;; loop, without checking whether that reference was a harmless field
;;; read or a real escape.
;;;
;;; This benchmark is a faithful-shape, deterministic port: real field
;;; count and nesting depth (a two-field accumulator, three layers of
;;; bind/if inside the nested loop reading both fields), stubbed random
;;; walk and mutable-array logic (unnecessary to exercise the shape and
;;; would make correctness verification non-deterministic) -- the same
;;; "faithful shape, stubbed payload" approach run-asr-reitit-bench.lisp
;;; already uses for reitit's ->endpoint.
;;;
;;; Run from the repository root:
;;;   sbcl --noinform --non-interactive --load benchmarks/run-asr-nested-loop-bench.lisp

(require :asdf)
(let* ((here (or *load-pathname* *compile-file-pathname*))
       (root (make-pathname :directory (butlast (pathname-directory here))))
       (src  (merge-pathnames "src/" root)))
  (pushnew (truename src) asdf:*central-registry* :test #'equal)
  (handler-bind ((warning #'muffle-warning))
    (asdf:load-system :fol-compiler)))

(defpackage :fol.benchmarks.asr-nested-loop (:use :cl))
(in-package :fol.benchmarks.asr-nested-loop)

(defparameter *trials* 20)
(defparameter *warmup-iters* 50)

(defparameter +fol-src+
  ;; %F% is a gensym'd suffix so baseline/ASR-only variants coexist as
  ;; distinct symbols. The inner loop's bind/if/bind/if chain mirrors the
  ;; real code's nesting depth (idx/sum intermediate lets, then a field
  ;; read at the innermost branch); STEPS controls its iteration count,
  ;; giving a real per-outer-step workload instead of a single read.
  "(defclass <vec2%F%> [] [[x] [y]])

   (defn dla-run%F% [n steps]
     (loop [i 0 rr (make-<vec2%F%> :x 3.0 :y 9.0)]
       (if (< i n)
         (recur (inc i)
                (make-<vec2%F%>
                 :x (+ (get rr :x)
                       (loop [nci 0.0 j 0]
                         (if (< j steps)
                           (recur (bind [idx (+ nci 1.0)]
                                    (if (> idx 0.0)
                                      (bind [sum (* idx 2.0)]
                                        (if (> sum 0.0)
                                          (+ (get rr :x) (get rr :y))
                                          (get rr :x)))
                                      -1.0))
                                  (inc j))
                           nci)))
                 :y (get rr :y)))
         (make-<vec2%F%> :x (get rr :x) :y (get rr :y)))))")

(defun replace-all (s from to)
  (with-output-to-string (out)
    (loop with flen = (length from) with i = 0
          for p = (search from s :start2 i)
          do (cond (p (write-string (subseq s i p) out)
                      (write-string to out)
                      (setf i (+ p flen)))
                   (t (write-string (subseq s i) out)
                      (return))))))

(defun compile-fol* (src scalar-repl)
  (let ((fol.compiler.escape-analysis:*scalar-replacement* scalar-repl)
        (*readtable* fol.compiler.reader:*fol-readtable*)
        (*package* (find-package :fol.core)))
    (with-input-from-string (in src)
      (loop for f = (read in nil :eof) until (eq f :eof)
            do (let ((code (fol.compiler:compilation-result-code (fol.compiler:compile-form f))))
                 (eval code))))))

(defun mean (xs) (/ (reduce #'+ xs) (float (length xs))))
(defun sd (xs)
  (let ((m (mean xs)) (n (length xs)))
    (if (< n 2) 0.0
        (sqrt (/ (reduce #'+ (mapcar (lambda (x) (expt (- x m) 2)) xs))
                 (float (1- n)))))))

(defparameter *batch-size* 20000
  "get-bytes-consed/timing deltas are unreliable at single-call granularity;
   measure a batch of calls per trial instead and divide (see
   run-asr-reitit-bench.lisp for the confirmed 0-byte-readback issue). This
   benchmark's ASR-only record is small (2 fields), and a smaller batch
   size (200, matching the other ASR benchmarks) was confirmed empirically
   to still read back as a suspicious flat 0.0 B/call -- a quantization
   artifact, not a real zero-allocation result: raising the batch 100x
   makes the true per-call allocation (~150 B, matching a small residual
   exit re-box) measurable.")

(defun trials (thunk)
  (dotimes (_ *warmup-iters*) (funcall thunk))
  (loop repeat *trials*
        collect (progn
                  (sb-ext:gc :full t)
                  (let ((b0 (sb-ext:get-bytes-consed))
                        (t0 (get-internal-real-time)))
                    (dotimes (_ *batch-size*) (funcall thunk))
                    (cons (/ (/ (- (get-internal-real-time) t0)
                                (float internal-time-units-per-second))
                             *batch-size*)
                          (/ (- (sb-ext:get-bytes-consed) b0) *batch-size*))))))

(defun main ()
  (format t "~&=== fastmath-shaped nested-loop Vec2 read: baseline vs. ASR-only ===~%")
  (format t "SBCL ~A, ~D trials (mean +/- sd), full GC before each~%~%"
          (lisp-implementation-version) *trials*)
  (let ((bname "b1") (aname "a1") (n 60) (steps 8))
    (compile-fol* (replace-all +fol-src+ "%F%" bname) nil)
    (compile-fol* (replace-all +fol-src+ "%F%" aname) t)
    (let* ((fb (fdefinition (find-symbol (string-upcase (concatenate 'string "dla-run" bname)) :fol.core)))
           (fa (fdefinition (find-symbol (string-upcase (concatenate 'string "dla-run" aname)) :fol.core)))
           (get-fn (fdefinition (find-symbol "GET" :fol.core)))
           (rb (funcall fb n steps))
           (ra (funcall fa n steps))
           (mismatches 0))
      (dolist (k '(:x :y))
        (let ((vb (funcall get-fn rb k)) (va (funcall get-fn ra k)))
          (unless (equalp vb va)
            (incf mismatches)
            (format t "  MISMATCH on ~A: baseline=~A asr=~A~%" k vb va))))
      (assert (zerop mismatches) () "nested-loop port: baseline/ASR-only results differ")
      (format t "Correctness: baseline and ASR-only results bit-identical on both fields.~%")
      (let* ((tb (trials (lambda () (funcall fb n steps))))
             (ta (trials (lambda () (funcall fa n steps))))
             (bt (mapcar #'car tb)) (at (mapcar #'car ta))
             (bc (mapcar #'cdr tb)) (ac (mapcar #'cdr ta))
             (bb (mean bc)) (ab (mean ac)))
        (format t "~&baseline : ~9,6F +/- ~8,6F ms   ~8,1F +/- ~6,1F B/call~%"
                (* 1000 (mean bt)) (* 1000 (sd bt)) bb (sd bc))
        (format t "ASR-only : ~9,6F +/- ~8,6F ms   ~8,1F +/- ~6,1F B/call   ~5,3Fx time  ~5,3Fx alloc~%"
                (* 1000 (mean at)) (* 1000 (sd at)) ab (sd ac)
                (/ (mean bt) (mean at)) (/ bb (max 1.0 ab))))))
  (format t "~&Done.~%"))

(main)
