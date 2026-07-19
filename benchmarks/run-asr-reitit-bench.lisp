;;; ASR whole-program benchmark: reitit's route-Methods builder (CGO 2027
;;; paper, Discussion -- "One real whole-program result").
;;;
;;; reitit (github.com/metosin/reitit, a widely used Clojure HTTP router)
;;; builds a 9-field Methods record by threading it through
;;; `(cond-> acc any? (assoc method (->endpoint ...)))` once per HTTP verb
;;; (reitit-ring/src/reitit/ring.cljc, reitit-http/src/reitit/http.cljc).
;;; Recognizing the always-true `any?` test, this is an unconditional
;;; assoc -- the same shape as this project's own Assoc microbenchmark
;;; (run-asr-bench.lisp / asr-assoc.fol), just as a straight-line 9-step
;;; bind chain instead of a loop. It was found by docs/cgo2027/corpus-
;;; study's weak_hits.clj/wide_hits.clj classifiers (the "helper-mediated"
;;; tier the paper's main corpus study reports but does not itself port),
;;; not hand-picked.
;;;
;;; Porting it faithfully surfaced no ASR limitation: three separate,
;;; pre-existing bugs in FOL's persistent-object machinery (src/
;;; persistence.lisp, src/compiler.lisp, src/collection-primitives.lisp),
;;; unrelated to this pass and never exercised because no prior benchmark
;;; used a record past six effective fields, blocked construction and
;;; update of any 7-or-more-field record outright:
;;;   1. COMPUTE-SLOTS (persistence.lisp) miscounted %TRANSIENT-OWNER and
;;;      %TRANSIENT-BUFFER as user-declared fields, silently consuming 2
;;;      of the 8-slot native budget.
;;;   2. Both fast-construction paths (%MAKE-PERSISTENT and the
;;;      *OPTIMIZE-CONSTRUCTORS* inline codegen) never built the overflow
;;;      persistent-vector for genuinely wide classes, and read
;;;      PERSISTENT-CLASS-SLOT-COUNT before the class was guaranteed
;;;      finalized.
;;;   3. The modern edit-tagged <TRANSIENT-VECTOR> representation had no
;;;      ASSOC! (index-set) method, nor did its underlying
;;;      TRANSIENT-%VEC-T struct implement one at all -- only CONJ!
;;;      (append) existed.
;;; All three are fixed; the full compiler test suite (3,505 checks) passes
;;; unchanged. This script benchmarks the result: baseline vs. ASR-only on
;;; the actual translated reitit chain (see FOL-SRC below), verifying
;;; correctness field-by-field before timing.
;;;
;;; Run from the repository root:
;;;   sbcl --noinform --non-interactive --load benchmarks/run-asr-reitit-bench.lisp

(require :asdf)
(let* ((here (or *load-pathname* *compile-file-pathname*))
       (root (make-pathname :directory (butlast (pathname-directory here))))
       (src  (merge-pathnames "src/" root)))
  (pushnew (truename src) asdf:*central-registry* :test #'equal)
  (handler-bind ((warning #'muffle-warning))
    (asdf:load-system :fol-compiler)))

(defpackage :fol.benchmarks.asr-reitit (:use :cl))
(in-package :fol.benchmarks.asr-reitit)

(defparameter *trials* 20)
(defparameter *warmup-iters* 50)

(defparameter +fol-src+
  ;; %F% is a gensym'd suffix so baseline/ASR-only variants coexist as
  ;; distinct symbols. MK-ENDPOINT stands in for reitit's ->endpoint
  ;; closure (which calls into middleware/coercion compilation this
  ;; benchmark has no reason to port); only its argument shape (path,
  ;; data, method) and non-triviality matter here, not its real behavior.
  "(defclass <methods> [] [[get] [head] [post] [put] [delete] [connect] [options] [trace] [patch]])

   (defn mk-endpoint [path data method]
     (+ (count path) (count data)))

   (defn entry%F% [path data]
     (bind [base (make-<methods> :get 0 :head 0 :post 0 :put 0 :delete 0
                                  :connect 0 :options 0 :trace 0 :patch 0)
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
  "get-bytes-consed/timing deltas are unreliable at single-call granularity
   on this SBCL/platform (confirmed: a real, side-effect-confirmed 8000-byte
   allocation reads back as 0 bytes when measured via gc-then-single-call).
   Measure a batch of calls per trial instead and divide. Raised from an
   earlier 500 after building the sibling nested-loop/macro-assoc
   benchmarks (run-asr-nested-loop-bench.lisp, run-asr-macro-assoc-bench.
   lisp) surfaced the same issue more severely there (500 read a genuine
   ~159 B/call allocation as a flat, wrong 0.0): re-measuring reitit at
   the same larger, confirmed-reliable batch size shifted its own
   published numbers slightly (3.56x/4.75x at 500 -> ~3.2x/~4.5x at
   20000), so 500 was already a real, if smaller, undercount here too.")

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
  (format t "~&=== reitit route-Methods builder: baseline vs. ASR-only ===~%")
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
            (format t "  MISMATCH on ~A: baseline=~A asr=~A~%" k vb va))))
      (assert (zerop mismatches) () "reitit port: baseline/ASR-only results differ")
      (format t "Correctness: baseline and ASR-only results bit-identical on all 9 fields.~%")
      (let* ((tb (trials (lambda () (funcall fb path data))))
             (ta (trials (lambda () (funcall fa path data))))
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
