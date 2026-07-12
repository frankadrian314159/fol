;;; RQ5 ablation benchmark: wrapper vs edit-tagged transients (PLDI 2027 paper).
;;;
;;; The paper's RQ5 previously retained "original development-machine"
;;; (Ryzen 9 5900X) measurements, mixing machines with RQ2's Ryzen 5 7430U
;;; figures (Threats to Validity). This script re-measures RQ5 on the RQ2
;;; machine, using RQ2's own workload templates, so the whole evaluation
;;; consolidates onto one machine/session.
;;;
;;; No prior committed script existed for this comparison (RQ5's original
;;; numbers came from a one-off run never checked into this repo), so this
;;; is a fresh implementation of the comparison the paper describes:
;;; "compared edit-tagged to a wrapper-based implementation (simulated by
;;; disabling reads)". Concretely: fol.compiler.collections:*wrapper-transients*
;;; (transients.lisp) makes TRANSIENT on <dict>/<vector> construct the
;;; legacy, O(n)-boundary, read-forbidding wrapper representation that
;;; already exists in the runtime (previously dead code, only ever reached
;;; for sets) instead of the O(1)/O(32) edit-tagged one -- same classifier,
;;; same rewriter, same source, only the representation TRANSIENT hands
;;; back differs. This is a REAL representation swap, not a simulated
;;; timing model.
;;;
;;; Run from the repository root:
;;;   sbcl --noinform --non-interactive --load benchmarks/run-rq5-ablation-bench.lisp

(require :asdf)
(let* ((here (or *load-pathname* *compile-file-pathname*))
       (root (make-pathname :directory (butlast (pathname-directory here))))
       (src  (merge-pathnames "src/" root)))
  (pushnew (truename src) asdf:*central-registry* :test #'equal)
  (handler-bind ((warning #'muffle-warning))
    (asdf:load-system :fol-compiler)))

(defpackage :fol.benchmarks.rq5-ablation (:use :cl))
(in-package :fol.benchmarks.rq5-ablation)

(defparameter *trials* 30
  "30 throughout, not just the near-1x rows: this script's whole point is a
   relative (wrapper vs edit-tagged) comparison, which deserves the same
   power as the small-N rows it's directly analogous to.")
(defparameter *warmup-iters* 3)
(defparameter *cooldown-seconds* 2)
(defparameter *preflight-seconds* 3)

(defun compile-fol* (src &key transient wrapper)
  (let ((fol.compiler.escape-analysis:*transient-loops* transient)
        (fol.compiler.collections:*wrapper-transients* wrapper)
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
                    (cons (/ (- (get-internal-real-time) t0) (float internal-time-units-per-second))
                          (- (sb-ext:get-bytes-consed) b0))))))

(defun cooldown () (sleep *cooldown-seconds*))
(defun preflight-warmup ()
  (let ((deadline (+ (get-internal-real-time) (* *preflight-seconds* internal-time-units-per-second)))
        (acc 0))
    (loop while (< (get-internal-real-time) deadline)
          do (dotimes (i 100000) (setf acc (logxor acc i))))
    acc))

(defun result-key (v) (if (numberp v) v (fol.compiler.collection-functions:count v)))

;;; Exactly RQ2's own templates (run-transient-bench.lisp +WORKLOADS+), so
;;; the "edit-tagged" column here is directly comparable to Table
;;; \ref{tab:microbenchmarks}'s On/TC columns run under the same protocol.
(defparameter +workloads+
  `(("dict 200k assoc"           200000
     "(defn ab-dict~A [n] (loop [acc {} i 0] (if (< i n) (recur (assoc acc i i) (inc i)) acc)))")
    ("vector 1M conj"            1000000
     "(defn ab-vec~A [n] (loop [acc [] i 0] (if (< i n) (recur (conj acc i) (inc i)) acc)))")
    ("small-N (3 assoc/boundary)" 40000
     "(defn ab-sn~A [m] (loop [tot 0 i 0] (if (< i m) (recur (+ tot (count (loop [acc {} j 0] (if (< j 3) (recur (assoc acc j j) (inc j)) acc)))) (inc i)) tot)))")
    ("small-N with reads"        40000
     "(defn ab-snr~A [m] (loop [tot 0 i 0] (if (< i m) (recur (+ tot (count (loop [acc {} j 0] (if (< j 3) (recur (assoc acc j (get acc j)) (inc j)) acc)))) (inc i)) tot)))")
    ;; Sets (PLDI 2027 weakness-6 fix: <set> is HAMT-backed exactly like
    ;; <dict>, so it now gets edit-tagged treatment too, not wrapper-only --
    ;; these two rows are RQ5's set-specific evidence for that claim.
    ("set 200k conj"             200000
     "(defn ab-set~A [n] (loop [acc #{} i 0] (if (< i n) (recur (conj acc i) (inc i)) acc)))")
    ("set small-N with reads"    40000
     "(defn ab-setr~A [m] (loop [tot 0 i 0] (if (< i m) (recur (+ tot (count (loop [acc #{} j 0] (if (< j 3) (recur (if (get acc j nil) acc (conj acc j)) (inc j)) acc)))) (inc i)) tot)))")))

(defun run-ablation-workload (label n template)
  (let* ((base-name (format nil "~A" (gensym "AB")))
         (edit-name (format nil "~A" (gensym "AE")))
         (wrap-name (format nil "~A" (gensym "AW"))))
    ;; baseline: everything off
    (compile-fol* (format nil template (string-downcase base-name)) :transient nil :wrapper nil)
    ;; edit-tagged: transient on, wrapper off (the paper's normal design)
    (multiple-value-bind (c1 edit-all) (compile-fol* (format nil template (string-downcase edit-name))
                                                       :transient t :wrapper nil)
      (declare (ignore c1))
      ;; wrapper ablation: transient on, wrapper representation on
      (multiple-value-bind (c2 wrap-all) (compile-fol* (format nil template (string-downcase wrap-name))
                                                         :transient t :wrapper t)
        (declare (ignore c2))
        (let* ((prefix (subseq template (length "(defn ") (position #\~ template)))
               (fb (fol-fn (concatenate 'string prefix (string base-name))))
               (fe (fol-fn (concatenate 'string prefix (string edit-name))))
               (fw (fol-fn (concatenate 'string prefix (string wrap-name))))
               (edit-converted (converted-p edit-all))
               (wrap-converted (converted-p wrap-all))
               (rb (funcall fb n)))
          (unless edit-converted (error "~A: edit-tagged variant did not convert" label))
          (let* ((tb (trials (lambda () (funcall fb n))))
                 (te (trials (lambda () (funcall fe n))))
                 (tw (when wrap-converted (trials (lambda () (funcall fw n)))))
                 (bt (mapcar #'car tb)) (et (mapcar #'car te)) (wt (and tw (mapcar #'car tw)))
                 (bb (mean (mapcar #'cdr tb))) (eb (mean (mapcar #'cdr te))) (wb (and tw (mean (mapcar #'cdr tw))))
                 (bm (mean bt)) (em (mean et)) (wm (and wt (mean wt))))
            (assert (equalp (result-key rb) (result-key (funcall fe n))) ()
                    "~A: edit-tagged result differs from baseline" label)
            (when wrap-converted
              (assert (equalp (result-key rb) (result-key (funcall fw n))) ()
                      "~A: wrapper result differs from baseline" label))
            (format t "~&~A (n=~:D)~%" label n)
            (format t "  baseline      : ~8,2F +/- ~5,2F ms   ~9,1F B/call~%" (* 1000 bm) (* 1000 (sd bt)) bb)
            (format t "  edit-tagged   : ~8,2F +/- ~5,2F ms   ~9,1F B/call   ~5,2Fx time  ~5,2Fx alloc~%"
                    (* 1000 em) (* 1000 (sd et)) eb (/ bm em) (/ bb (max 1.0 eb)))
            (if wrap-converted
                (format t "  wrapper       : ~8,2F +/- ~5,2F ms   ~9,1F B/call   ~5,2Fx time  ~5,2Fx alloc~%"
                        (* 1000 wm) (* 1000 (sd wt)) wb (/ bm wm) (/ bb (max 1.0 wb)))
                (format t "  wrapper       : REFUSED (read present, wrapper forbids reads) -> 1.00x (baseline)~%"))
            (cooldown)))))))

(defun main ()
  (format t "~&=== RQ5 ablation: wrapper vs edit-tagged transients (re-measured on RQ2 machine) ===~%")
  (format t "SBCL ~A, dynamic space ~,0F MB, ~D trials (mean +/- sd), full GC before each~%~%"
          (lisp-implementation-version) (/ (sb-ext:dynamic-space-size) 1048576.0) *trials*)
  (preflight-warmup)
  (dolist (w +workloads+)
    (destructuring-bind (label n template) w
      (run-ablation-workload label n template)))
  (format t "~&Done.~%"))

(main)
