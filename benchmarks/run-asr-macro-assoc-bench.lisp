;;; ASR whole-program benchmark: datascript's macro-hidden ASSOC update
;;; (CGO 2027 paper, Discussion -- corpus study, the third "strong" match).
;;;
;;; datascript (github.com/tonsky/datascript)'s pull-pattern parser rebuilds
;;; its PullPattern record via ASSOC inside `util/cond+`, a project-local
;;; branching macro, not IF/COND/CASE written directly. A reader-level (or
;;; FOL AST-level) walk that only recognizes the built-in branching forms
;;; never sees the ASSOC calls at all -- and, as it turned out while
;;; building this benchmark, FOL's own compiler had two real, pre-existing
;;; bugs in how a *user-defined* DEFMACRO is treated versus the fixed set
;;; of built-in macros (COND->, WHEN, ...) that were already transparent:
;;; EMIT-DEFMACRO never registered the macro with FOL's own parser-level
;;; macro table at all, and even once registered, a macro body that builds
;;; its expansion with FOL's own LIST/CONS produces a persistent <LIST>
;;; object (not a raw CL cons), which PARSE-FORM had no case for. Both are
;;; now fixed (src/compiler.lisp: EMIT-DEFMACRO, PARSE-COMPOUND,
;;; %DELISTIFY); this benchmark exercises the result.
;;;
;;; This is a faithful-shape, deterministic port: a project-local
;;; branching macro (three clauses, matching cond+'s shape) wrapping an
;;; unconditional/conditional ASSOC reconstruction of a 2-field record,
;;; stubbed pattern-parsing payload (unnecessary to exercise the shape and
;;; would require porting datascript's whole pull-pattern DSL) -- the same
;;; "faithful shape, stubbed payload" approach run-asr-reitit-bench.lisp
;;; already uses for reitit's ->endpoint.
;;;
;;; Run from the repository root:
;;;   sbcl --noinform --non-interactive --load benchmarks/run-asr-macro-assoc-bench.lisp

(require :asdf)
(let* ((here (or *load-pathname* *compile-file-pathname*))
       (root (make-pathname :directory (butlast (pathname-directory here))))
       (src  (merge-pathnames "src/" root)))
  (pushnew (truename src) asdf:*central-registry* :test #'equal)
  (handler-bind ((warning #'muffle-warning))
    (asdf:load-system :fol-compiler)))

(defpackage :fol.benchmarks.asr-macro-assoc (:use :cl))
(in-package :fol.benchmarks.asr-macro-assoc)

(defparameter *trials* 20)
(defparameter *warmup-iters* 50)

(defparameter +fol-src+
  ;; %F% is a gensym'd suffix so baseline/ASR-only variants coexist as
  ;; distinct symbols. COND-PLUS mirrors cond+'s shape: an ordered list of
  ;; test/body clauses ending in a default, expanded (once EMIT-DEFMACRO
  ;; registers it and %DELISTIFY normalizes its <LIST>-built expansion) to
  ;; a plain IF-tree ASR's existing branch recognition already handles.
  "(defmacro cond-plus%F% [t1 b1 t2 b2 eb]
     (list 'if t1 b1 (list 'if t2 b2 eb)))

   (defclass <pull%F%> [] [[attrs] [wildcard]])

   (defn parse-run%F% [n]
     (loop [i 0 result (make-<pull%F%> :attrs 0.0 :wildcard 0.0)]
       (if (< i n)
         (recur (inc i)
                (cond-plus%F% (> (get result :attrs) 100.0)
                              (assoc result :wildcard (+ (get result :wildcard) 1.0))
                              (> (get result :attrs) 50.0)
                              (assoc result :attrs (+ (get result :attrs) 2.0)
                                            :wildcard (+ (get result :wildcard) 1.0))
                              (assoc result :attrs (+ (get result :attrs) 1.0)
                                            :wildcard (get result :wildcard))))
         result)))")

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
   benchmark's ASR-only record is small (2 fields); 500 (matching the
   reitit benchmark's 9-field record) was confirmed empirically to still
   under-read the true per-call allocation at this size -- raising the
   batch 40x makes the true, stable per-call figure (~159 B, matching a
   small residual exit re-box) measurable.")

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
  (format t "~&=== datascript-shaped macro-hidden ASSOC update: baseline vs. ASR-only ===~%")
  (format t "SBCL ~A, ~D trials (mean +/- sd), full GC before each~%~%"
          (lisp-implementation-version) *trials*)
  (let ((bname "b1") (aname "a1") (n 40))
    (compile-fol* (replace-all +fol-src+ "%F%" bname) nil)
    (compile-fol* (replace-all +fol-src+ "%F%" aname) t)
    (let* ((fb (fdefinition (find-symbol (string-upcase (concatenate 'string "parse-run" bname)) :fol.core)))
           (fa (fdefinition (find-symbol (string-upcase (concatenate 'string "parse-run" aname)) :fol.core)))
           (get-fn (fdefinition (find-symbol "GET" :fol.core)))
           (rb (funcall fb n))
           (ra (funcall fa n))
           (mismatches 0))
      (dolist (k '(:attrs :wildcard))
        (let ((vb (funcall get-fn rb k)) (va (funcall get-fn ra k)))
          (unless (equalp vb va)
            (incf mismatches)
            (format t "  MISMATCH on ~A: baseline=~A asr=~A~%" k vb va))))
      (assert (zerop mismatches) () "macro-hidden-assoc port: baseline/ASR-only results differ")
      (format t "Correctness: baseline and ASR-only results bit-identical on both fields.~%")
      (let* ((tb (trials (lambda () (funcall fb n))))
             (ta (trials (lambda () (funcall fa n))))
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
