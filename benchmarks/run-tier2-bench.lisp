;;; Tier-2 constructor-init benchmark driver (PLDI 2027 paper, RQ3).
;;;
;;; Demonstrates that Tier-2 inference has a real, measured effect on
;;; conversion outcomes: a loop initialized from a user-defined 0-ary
;;; constructor call -- not a collection literal -- is only eligible for
;;; transient conversion once TRANSIENT-ELIGIBLE-INIT-P/INIT-SUPPORTS-P can
;;; consult a RETURNS-FRESH-P/RETURNS-KIND summary for that constructor.
;;; Tier-1 has no entry for a user-defined function, so this summary can only
;;; come from Tier-2's inference.
;;;
;;; Three variants of the SAME source are compiled and timed:
;;;   baseline  -- every optimization flag off (the persistent baseline).
;;;   converted -- all flags on; the constructor is compiled (Tier-2 infers
;;;                its summary) BEFORE the loop, so the loop's init is
;;;                eligible and the loop converts.
;;;   ablated   -- all flags on, but the constructor's inferred summary is
;;;                cleared (simulating "Tier-2 unavailable") before the loop
;;;                compiles; same source, same flags, only Tier-2's summary
;;;                differs -- isolates its causal contribution.
;;;
;;; Both forms are compiled before either is evaluated, matching real
;;; compile-file/load semantics: NOTE-REDEFINITION (run by the emitted code
;;; for any defn, including its first definition) clears a function's Tier-2
;;; cache entry as soon as its code runs, since a first definition and a
;;; genuine redefinition look identical to that mechanism. In a real file,
;;; every form compiles before any of them load, so this never matters; a
;;; naive compile-then-immediately-eval loop (as the simpler workloads in
;;; run-transient-bench.lisp use, harmlessly, since they don't depend on
;;; *INFERRED-SUMMARIES*) would clear the summary before the loop's
;;; compilation ever consulted it.
;;;
;;; Run from the repository root:
;;;   sbcl --noinform --non-interactive --load benchmarks/run-tier2-bench.lisp

(require :asdf)
(let* ((here (or *load-pathname* *compile-file-pathname*))
       (root (make-pathname :directory (butlast (pathname-directory here))))
       (src  (merge-pathnames "src/" root)))
  (pushnew (truename src) asdf:*central-registry* :test #'equal)
  (handler-bind ((warning #'muffle-warning))
    (asdf:load-system :fol-compiler)))

(defpackage :fol.benchmarks.tier2 (:use :cl))
(in-package :fol.benchmarks.tier2)

(defparameter *trials* 5)
(defparameter *warmup-iters* 3)
(defparameter *cooldown-seconds* 2)

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

(defun fol-fn (name) (fdefinition (find-symbol (string-upcase name) :fol.core)))

(defun result-key (v)
  (if (numberp v) v (fol.compiler.collection-functions:count v)))

;;; --- Workload source: a loop initialized from a user constructor call,
;;; not a literal -- TRANSIENT-ELIGIBLE-INIT-P's other case (§sec:formal).
(defparameter +ctor-template+
  "(defn tb-tier2-ctor~A [] (fol.compiler.collection-functions:dict))")
(defparameter +loop-template+
  "(defn tb-tier2~A [n] (loop [acc (tb-tier2-ctor~A) i 0] (if (< i n) (recur (assoc acc i i) (inc i)) acc)))")

(defun native-dict (n)
  (declare (fixnum n) (optimize (speed 3)))
  (let ((h (make-hash-table :size (* 2 n))))
    (dotimes (i n) (setf (gethash i h) i))
    h))

(defun %compile* (src &key transient)
  "Compile+eval every form in SRC with *TRANSIENT-LOOPS* bound to TRANSIENT.
   Returns the printed concatenation of every form's emitted code, so
   callers can check whether the pipeline converted the loop."
  (let ((fol.compiler.escape-analysis:*transient-loops* transient)
        (*readtable* fol.compiler.reader:*fol-readtable*)
        (*package* (find-package :fol.core))
        (all (make-string-output-stream)))
    (with-input-from-string (in src)
      (loop for f = (read in nil :eof) until (eq f :eof)
            do (let ((code (fol.compiler:compilation-result-code (fol.compiler:compile-form f))))
                 (eval code)
                 (write-string (write-to-string code) all))))
    (get-output-stream-string all)))

(defun %compile-ctor-then-loop (ctor-src loop-src &key transient clear-ctor-summary)
  "Compile CTOR-SRC then LOOP-SRC (both, before evaluating either), so a
   Tier-2 summary inferred for the constructor is still cached when the
   loop's init eligibility is checked. Optionally clears the constructor's
   inferred summary between compiling and evaluating (the ablation).
   Returns (values LOOP-CODE-STRING) after evaluating both forms in order."
  (let ((fol.compiler.escape-analysis:*transient-loops* transient)
        (*readtable* fol.compiler.reader:*fol-readtable*)
        (*package* (find-package :fol.core)))
    (let* ((ctor-form (with-input-from-string (in ctor-src) (read in)))
           (loop-form (with-input-from-string (in loop-src) (read in)))
           (ctor-result (fol.compiler:compile-form ctor-form))
           (ctor-name (fol.compiler.ast:defn-node-name (fol.compiler:parse-form ctor-form))))
      (when clear-ctor-summary
        (fol.compiler.summaries:clear-inferred-summary ctor-name))
      (let* ((loop-result (fol.compiler:compile-form loop-form))
             (loop-code-str (write-to-string (fol.compiler:compilation-result-code loop-result))))
        (eval (fol.compiler:compilation-result-code ctor-result))
        (eval (fol.compiler:compilation-result-code loop-result))
        loop-code-str))))

(defun converted-p (code-str) (and (search "TRANSIENT" code-str) t))

(defun run-workload (label n)
  (let* ((base-suffix (string (gensym "B")))
         (opt-suffix  (string (gensym "O")))
         (abl-suffix  (string (gensym "A"))))
    ;; Baseline: all flags off. No summaries matter; compiled+evaluated
    ;; form-by-form is fine here.
    (%compile* (format nil "~A~%~A"
                        (format nil +ctor-template+ base-suffix)
                        (format nil +loop-template+ base-suffix base-suffix))
               :transient nil)
    ;; Converted: Tier-2 present when the loop compiles.
    (let ((opt-code-str (%compile-ctor-then-loop
                         (format nil +ctor-template+ opt-suffix)
                         (format nil +loop-template+ opt-suffix opt-suffix)
                         :transient t :clear-ctor-summary nil)))
      (assert (converted-p opt-code-str) () "~A: converted variant did not convert" label))
    ;; Ablated: same flags, but the constructor's inferred summary is
    ;; cleared before the loop compiles -- Tier-2 "unavailable".
    (let ((abl-code-str (%compile-ctor-then-loop
                         (format nil +ctor-template+ abl-suffix)
                         (format nil +loop-template+ abl-suffix abl-suffix)
                         :transient t :clear-ctor-summary t)))
      (assert (not (converted-p abl-code-str)) () "~A: ablated variant converted anyway" label))
    (let* ((fb (fol-fn (concatenate 'string "TB-TIER2" base-suffix)))
           (fo (fol-fn (concatenate 'string "TB-TIER2" opt-suffix)))
           (fa (fol-fn (concatenate 'string "TB-TIER2" abl-suffix)))
           (rb (funcall fb n)) (ro (funcall fo n)) (ra (funcall fa n)))
      (assert (equalp (result-key rb) (result-key ro)) () "~A: results differ (converted)" label)
      (assert (equalp (result-key rb) (result-key ra)) () "~A: results differ (ablated)" label)
      (let* ((tb (trials (lambda () (funcall fb n))))
             (to (trials (lambda () (funcall fo n))))
             (ta (trials (lambda () (funcall fa n))))
             (tn (trials (lambda () (native-dict n))))
             (bt (mapcar #'car tb)) (ot (mapcar #'car to)) (at (mapcar #'car ta))
             (bb (mean (mapcar #'cdr tb))) (ob (mean (mapcar #'cdr to))) (ab (mean (mapcar #'cdr ta))))
        (format t "~&~A (n=~:D, result=~A)~%" label n (result-key rb))
        (format t "  baseline (Off)        : ~7,1F +/- ~5,1F ms   ~8,1F MB/call~%"
                (* 1000 (mean bt)) (* 1000 (sd bt)) (/ bb 1048576.0))
        (format t "  converted (Tier-2 on) : ~7,1F +/- ~5,1F ms   ~8,1F MB/call   ~5,2Fx time  ~5,2Fx alloc~%"
                (* 1000 (mean ot)) (* 1000 (sd ot)) (/ ob 1048576.0)
                (/ (mean bt) (mean ot)) (/ bb (max 1.0 ob)))
        (format t "  ablated (Tier-2 off)  : ~7,1F +/- ~5,1F ms   ~8,1F MB/call   ~5,2Fx time  (matches baseline)~%"
                (* 1000 (mean at)) (* 1000 (sd at)) (/ ab 1048576.0)
                (/ (mean bt) (mean at)))
        (let ((nt (mapcar #'car tn)))
          (format t "  mutable CL            : ~7,1F +/- ~5,1F ms   (converted = ~,2Fx CL time)~%"
                  (* 1000 (mean nt)) (* 1000 (sd nt))
                  (/ (mean ot) (mean nt))))
        (cooldown)))))

(defun main ()
  (format t "~&=== Tier-2 constructor-init benchmark (RQ3) ===~%")
  (format t "SBCL ~A, dynamic space ~,0F MB, ~D trials (mean +/- sd), full GC before each~%"
          (lisp-implementation-version) (/ (sb-ext:dynamic-space-size) 1048576.0) *trials*)
  (run-workload "dict loop, ctor-init, 200k assocs" 200000)
  (format t "~&Done.~%"))

(main)
