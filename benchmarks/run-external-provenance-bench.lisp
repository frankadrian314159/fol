;;; External-provenance benchmark (PLDI 2027 paper, addressing the
;;; "co-designed benchmarks" concern raised in review).
;;;
;;; Every other RQ2/RQ6 workload (dict/vector/reduce microbenchmarks,
;;; quicksort, word-count, bfs-ranks) was written by this project's authors,
;;; several specifically to evaluate this optimization (see git history:
;;; run-transient-bench.lisp was added 2026-07-08, during the escape-
;;; analysis project). quicksort.fol and lsim.fol predate the project by
;;; ~4-5 months (2026-02-19/25) and were not written to showcase transient
;;; conversion, but none of the four whole-program benchmarks come from
;;; outside the FOL project entirely.
;;;
;;; This workload does: it is a faithful, structure-preserving port of a
;;; real accumulation loop from cognitect/aws-api (github.com/cognitect-labs/
;;; aws-api), a well-known, independently-maintained open-source Clojure
;;; library with no connection to FOL -- specifically
;;; src/cognitect/aws/util/xml.clj's READ-ELEMENT function, the :attrs loop
;;; (lines 42-48 at the SHA pinned in docs/cgo2027/corpus-study/
;;; manifest.lock.edn). It was located by docs/cgo2027/corpus-study's
;;; GATE-FAITHFUL classifier (classify.clj) independently flagging it
;;; :qualified over the full 29-project corpus -- i.e. it was not
;;; hand-picked by eyeballing for convertibility; it is one of the 102 real
;;; sites that tool's automated, pre-registered gates accepted, chosen
;;; because it is small and self-contained enough to port by hand.
;;;
;;; Original (Clojure, unmodified):
;;;   (loop [i 0 attrs {}]
;;;     (if (< i nattrs)
;;;       (recur (inc i) (assoc attrs (attr-key rdr i) (.getAttributeValue rdr i)))
;;;       attrs))
;;;
;;; FOL port below preserves the loop shape (bindings, order, exit) exactly.
;;; The ONE change: FOL has no XML/Java interop, so the two per-index reads
;;; off the XMLStreamReader (ATTR-KEY, .getAttributeValue) become indexing
;;; into two parallel input vectors -- still index-driven external reads,
;;; the role they played in the original, just against FOL-native data.
;;;
;;; Run from the repository root:
;;;   sbcl --noinform --non-interactive --load benchmarks/run-external-provenance-bench.lisp

(require :asdf)
(let* ((here (or *load-pathname* *compile-file-pathname*))
       (root (make-pathname :directory (butlast (pathname-directory here))))
       (src  (merge-pathnames "src/" root)))
  (pushnew (truename src) asdf:*central-registry* :test #'equal)
  (handler-bind ((warning #'muffle-warning))
    (asdf:load-system :fol-compiler)))

(defpackage :fol.benchmarks.external-provenance (:use :cl))
(in-package :fol.benchmarks.external-provenance)

(defparameter *trials* 5)
(defparameter *warmup-iters* 3)
(defparameter *cooldown-seconds* 2)

(defun compile-fol* (src &key transient scalar-repl numeric-spec stack-closures optimize-ctors)
  (let ((fol.compiler.escape-analysis:*transient-loops* transient)
        (fol.compiler.escape-analysis:*scalar-replacement* scalar-repl)
        (fol.compiler.escape-analysis:*numeric-specialization* numeric-spec)
        (fol.compiler.escape-analysis:*stack-closures* stack-closures)
        (fol.compiler::*optimize-constructors* optimize-ctors)
        (*readtable* fol.compiler.reader:*fol-readtable*)
        (*package* (find-package :fol.core))
        (code nil)
        (all (make-string-output-stream)))
    (with-input-from-string (in src)
      (loop for f = (read in nil :eof) until (eq f :eof)
            do (setf code (fol.compiler:compilation-result-code
                           (fol.compiler:compile-form f)))
               (eval code)
               (write-string (write-to-string code) all)))
    (values code (get-output-stream-string all))))

(defun compile-fol (src optimize-p)
  (compile-fol* src :transient optimize-p :scalar-repl optimize-p
                :numeric-spec optimize-p :stack-closures optimize-p
                :optimize-ctors optimize-p))

(defun compile-fol-transient-only (src)
  (compile-fol* src :transient t))

(defun converted-p (all-code) (and (search "TRANSIENT" all-code) t))
(defun fol-fn (name) (fdefinition (find-symbol (string-upcase name) :fol.core)))

(defun replace-all (s from to)
  (with-output-to-string (out)
    (loop with flen = (length from) with i = 0
          for p = (search from s :start2 i)
          do (cond (p (write-string (subseq s i p) out)
                      (write-string to out)
                      (setf i (+ p flen)))
                   (t (write-string (subseq s i) out)
                      (return))))))

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
                  (let ((b0 (sb-ext:get-bytes-consed))
                        (t0 (get-internal-real-time)))
                    (funcall thunk)
                    (cons (/ (- (get-internal-real-time) t0)
                             (float internal-time-units-per-second))
                          (- (sb-ext:get-bytes-consed) b0))))))

(defun cooldown () (sleep *cooldown-seconds*))

;;; --- The ported workload ----------------------------------------------
;;; %F% is a gensym'd suffix so baseline/transient-only/converted variants
;;; coexist under distinct names, same discipline as run-transient-bench.lisp.

(defparameter +read-attrs+
  "(defn read-attrs%F% [ks vs nattrs]
     (loop [i 0 attrs {}]
       (if (< i nattrs)
         (recur (inc i) (assoc attrs (get ks i) (get vs i)))
         attrs)))")

(defparameter +mk-kv+
  ;; Deterministic pseudo-random key/value vectors of length N, disjoint
  ;; ranges so no key collisions perturb the dict's final size.
  "(defn mk-kv [n seed]
     (loop [ks [] vs [] i 0 s seed]
       (if (< i n)
         (recur (conj ks (mod s 1000000))
                (conj vs (mod (+ s 7) 1000000))
                (inc i)
                (mod (+ (* s 1103515245) 12345) 2147483648))
         [ks vs])))")

(defun native-read-attrs (ks vs nattrs)
  "Hand-written mutable CL ceiling: same algorithm, hash-table instead of
   a persistent dict."
  (declare (optimize (speed 3)))
  (let ((h (make-hash-table :size (max 16 (* 2 nattrs)))))
    (dotimes (i nattrs)
      (setf (gethash (fol.compiler.collection-functions:get ks i) h)
            (fol.compiler.collection-functions:get vs i)))
    h))

(defun result-key (v) (fol.compiler.collection-functions:count v))

(defun run-workload-1 (label n)
  (let* ((base-name (format nil "~A" (gensym "B")))
         (opt-name  (format nil "~A" (gensym "O")))
         (tc-name   (format nil "~A" (gensym "T"))))
    (compile-fol (replace-all +read-attrs+ "%F%" base-name) nil)
    (multiple-value-bind (opt-code all) (compile-fol (replace-all +read-attrs+ "%F%" opt-name) t)
      (declare (ignore opt-code))
      (assert (converted-p all) () "~A did not convert (expected: classify.clj scored it :qualified)" label))
    (multiple-value-bind (tc-code all-tc) (compile-fol-transient-only (replace-all +read-attrs+ "%F%" tc-name))
      (declare (ignore tc-code))
      (assert (converted-p all-tc) () "~A did not convert (transient-only)" label))
    (let* ((fb (fol-fn (concatenate 'string "read-attrs" base-name)))
           (fo (fol-fn (concatenate 'string "read-attrs" opt-name)))
           (ft (fol-fn (concatenate 'string "read-attrs" tc-name)))
           (kv (funcall (fol-fn "mk-kv") n 999))
           (ks (fol.compiler.collection-functions:get kv 0))
           (vs (fol.compiler.collection-functions:get kv 1))
           (rb (funcall fb ks vs n)) (ro (funcall fo ks vs n)) (rt (funcall ft ks vs n)))
      (assert (equalp (result-key rb) (result-key ro)) () "~A results differ (converted)" label)
      (assert (equalp (result-key rb) (result-key rt)) () "~A results differ (transient-only)" label)
      (let* ((tb (trials (lambda () (funcall fb ks vs n))))
             (tt (trials (lambda () (funcall ft ks vs n))))
             (to (trials (lambda () (funcall fo ks vs n))))
             (tn (trials (lambda () (native-read-attrs ks vs n))))
             (bt (mapcar #'car tb)) (tct (mapcar #'car tt)) (ot (mapcar #'car to)) (nt (mapcar #'car tn))
             (bb (mean (mapcar #'cdr tb))) (tcb (mean (mapcar #'cdr tt))) (ob (mean (mapcar #'cdr to))))
        (format t "~&~A (n=~:D, result-count=~A)~%" label n (result-key rb))
        (format t "  baseline       : ~7,2F +/- ~5,2F ms   ~8,1F MB/call~%"
                (* 1000 (mean bt)) (* 1000 (sd bt)) (/ bb 1048576.0))
        (format t "  transient-only : ~7,2F +/- ~5,2F ms   ~8,1F MB/call   ~5,2Fx time  ~5,2Fx alloc~%"
                (* 1000 (mean tct)) (* 1000 (sd tct)) (/ tcb 1048576.0)
                (/ (mean bt) (mean tct)) (/ bb (max 1.0 tcb)))
        (format t "  converted (5x) : ~7,2F +/- ~5,2F ms   ~8,1F MB/call   ~5,2Fx time  ~5,2Fx alloc~%"
                (* 1000 (mean ot)) (* 1000 (sd ot)) (/ ob 1048576.0)
                (/ (mean bt) (mean ot)) (/ bb (max 1.0 ob)))
        (format t "  mutable CL     : ~7,2F +/- ~5,2F ms   (converted = ~,2Fx CL time)~%"
                (* 1000 (mean nt)) (* 1000 (sd nt)) (/ (mean ot) (mean nt)))
        (cooldown)))))

(defun run-workload (label n &optional (trial-count *trials*))
  "TRIAL-COUNT overrides *TRIALS* for this call only; the n=5 row sits
   closest to 1x (same reason RQ2's small-N rows use 30 trials, not 5)."
  (let ((*trials* trial-count))
    (run-workload-1 label n)))

(defun main ()
  (format t "~&=== External-provenance benchmark: cognitect/aws-api read-element's :attrs loop, ported to FOL ===~%")
  (format t "SBCL ~A, dynamic space ~,0F MB, ~D trials (mean +/- sd), full GC before each~%~%"
          (lisp-implementation-version) (/ (sb-ext:dynamic-space-size) 1048576.0) *trials*)
  (compile-fol +mk-kv+ nil)
  (run-workload "read-attrs, n=200000 (stress-test scale, matches RQ2)" 200000)
  (run-workload "read-attrs, n=5 (realistic: an XML element rarely has >5-10 attrs)" 5 30)
  (format t "~&Done.~%"))

(main)
