;;; Dict-mode ASR whole-program benchmark: reitit's route-Methods builder,
;;; without a defclass -- the CGO 2027 paper's "what if this had been
;;; written the way Clojure programmers actually write it" companion to
;;; run-asr-reitit-bench.lisp.
;;;
;;; reitit's real source declares Methods as a `defrecord`. But the corpus
;;; search that found reitit also converged on a broader empirical finding:
;;; real Clojure code overwhelmingly prefers a plain, schema-less map over
;;; a formal record for exactly this fixed-small-key-set-accumulator shape
;;; (see docs/cgo2027/cgo2027.tex's Discussion, "why so few hits"). A FOL
;;; programmer following that same idiom would write reitit's Methods
;;; builder against `{}`, not `defclass <methods> ...` -- and, before this
;;; benchmark's feature, would get none of ASR's allocation-elimination
;;; benefit for it, purely because they didn't commit to a record type.
;;;
;;; *DICT-SCALAR-REPLACEMENT* closes that gap for the intra-bind chain
;;; shape (src/compiler.lisp, %SR-INTRA-BIND-CHAIN dict-mode): the fixed
;;; key set is discovered from usage (every touch is a literal-keyword
;;; GET/ASSOC) instead of coming from a pre-registered defclass schema.
;;; This script is the identical benchmark to run-asr-reitit-bench.lisp --
;;; same 9-key chain, same MK-ENDPOINT stand-in, same correctness-then-
;;; timing harness -- with `{}` in place of `(make-<methods> ...)` and
;;; *DICT-SCALAR-REPLACEMENT* in place of *SCALAR-REPLACEMENT*.
;;;
;;; Run from the repository root:
;;;   sbcl --noinform --non-interactive --load benchmarks/run-asr-dict-reitit-bench.lisp

(require :asdf)
(let* ((here (or *load-pathname* *compile-file-pathname*))
       (root (make-pathname :directory (butlast (pathname-directory here))))
       (src  (merge-pathnames "src/" root)))
  (pushnew (truename src) asdf:*central-registry* :test #'equal)
  (handler-bind ((warning #'muffle-warning))
    (asdf:load-system :fol-compiler)))

(defpackage :fol.benchmarks.asr-dict-reitit (:use :cl))
(in-package :fol.benchmarks.asr-dict-reitit)

(defparameter *trials* 20)
(defparameter *warmup-iters* 50)

(defparameter +fol-src+
  ;; %F% is a gensym'd suffix so baseline/dict-ASR variants coexist as
  ;; distinct symbols. Identical chain shape to run-asr-reitit-bench.lisp's
  ;; +FOL-SRC+, minus the defclass: BASE seeds as {} instead of
  ;; (make-<methods> ...).
  "(defn mk-endpoint [path data method]
     (+ (count path) (count data)))

   (defn entry%F% [path data]
     (bind [base {}
            m1 (assoc base :get (mk-endpoint path data 'get))
            m2 (assoc m1 :head (mk-endpoint path data 'head))
            m3 (assoc m2 :post (mk-endpoint path data 'post))
            m4 (assoc m3 :put (mk-endpoint path data 'put))
            m5 (assoc m4 :delete (mk-endpoint path data 'delete))
            m6 (assoc m5 :connect (mk-endpoint path data 'connect))
            m7 (assoc m6 :options (mk-endpoint path data 'options))
            m8 (assoc m7 :trace (mk-endpoint path data 'trace))
            m9 (assoc m8 :patch (mk-endpoint path data 'patch))]
       m9))")

(defun replace-all (s from to)
  (with-output-to-string (out)
    (loop with flen = (length from) with i = 0
          for p = (search from s :start2 i)
          do (cond (p (write-string (subseq s i p) out)
                      (write-string to out)
                      (setf i (+ p flen)))
                   (t (write-string (subseq s i) out)
                      (return))))))

(defun compile-fol* (src dict-scalar-repl)
  (let ((fol.compiler.escape-analysis:*dict-scalar-replacement* dict-scalar-repl)
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
  "get-bytes-consed/timing deltas are unreliable at single-call granularity
   on this SBCL/platform (confirmed: a real, side-effect-confirmed 8000-byte
   allocation reads back as 0 bytes when measured via gc-then-single-call).
   Raised from an earlier 500 for consistency with run-asr-reitit-bench.lisp
   (see its own comment): re-measuring at this larger, confirmed-reliable
   batch size shifted the published 1.80x/2.01x numbers slightly.
   Measure a batch of calls per trial instead and divide.")

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
  (format t "~&=== reitit route-Methods builder (plain dict, no defclass): baseline vs. dict-ASR ===~%")
  (format t "SBCL ~A, ~D trials (mean +/- sd), full GC before each~%~%"
          (lisp-implementation-version) *trials*)
  (let ((bname "b1") (aname "a1"))
    (compile-fol* (replace-all +fol-src+ "%F%" bname) nil)
    (compile-fol* (replace-all +fol-src+ "%F%" aname) t)
    (let* ((fb (fdefinition (find-symbol (string-upcase (concatenate 'string "entry" bname)) :fol.core)))
           (fa (fdefinition (find-symbol (string-upcase (concatenate 'string "entry" aname)) :fol.core)))
           (get-fn (fdefinition (find-symbol "GET" :fol.core)))
           (path "/api/v1/resource")
           (data "somepayload")
           (rb (funcall fb path data))
           (ra (funcall fa path data))
           (mismatches 0))
      (dolist (k '(:get :head :post :put :delete :connect :options :trace :patch))
        (let ((vb (funcall get-fn rb k)) (va (funcall get-fn ra k)))
          (unless (equalp vb va)
            (incf mismatches)
            (format t "  MISMATCH on ~A: baseline=~A dict-asr=~A~%" k vb va))))
      (assert (zerop mismatches) () "dict-reitit port: baseline/dict-ASR results differ")
      (format t "Correctness: baseline and dict-ASR results bit-identical on all 9 fields.~%")
      (let* ((tb (trials (lambda () (funcall fb path data))))
             (ta (trials (lambda () (funcall fa path data))))
             (bt (mapcar #'car tb)) (at (mapcar #'car ta))
             (bc (mapcar #'cdr tb)) (ac (mapcar #'cdr ta))
             (bb (mean bc)) (ab (mean ac)))
        (format t "~&baseline : ~9,6F +/- ~8,6F ms   ~8,1F +/- ~6,1F B/call~%"
                (* 1000 (mean bt)) (* 1000 (sd bt)) bb (sd bc))
        (format t "dict-ASR : ~9,6F +/- ~8,6F ms   ~8,1F +/- ~6,1F B/call   ~5,3Fx time  ~5,3Fx alloc~%"
                (* 1000 (mean at)) (* 1000 (sd at)) ab (sd ac)
                (/ (mean bt) (mean at)) (/ bb (max 1.0 ab))))))
  (format t "~&Done.~%"))

(main)
