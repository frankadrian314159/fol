;;; Transient-conversion benchmark driver (PLDI 2027 paper, RQ2).
;;;
;;; For each accumulation workload, compiles the same FOL source twice --
;;; *transient-loops* off (baseline) and on (converted) -- verifies the
;;; converted code actually contains the transient rewrite and produces results
;;; equal to the baseline, then runs five timed trials of each (one warm-up,
;;; full GC before each) reporting mean +/- sample stddev wall time and
;;; per-call allocation. Idiomatic hand-written mutable Common Lisp versions of
;;; the three large workloads provide a native ceiling.
;;;
;;; Run from the repository root:
;;;   sbcl --noinform --non-interactive --load benchmarks/run-transient-bench.lisp

(require :asdf)
(let* ((here (or *load-pathname* *compile-file-pathname*))
       (root (make-pathname :directory (butlast (pathname-directory here))))
       (src  (merge-pathnames "src/" root)))
  (pushnew (truename src) asdf:*central-registry* :test #'equal)
  (handler-bind ((warning #'muffle-warning))
    (asdf:load-system :fol-compiler)))

(defpackage :fol.benchmarks.transients (:use :cl))
(in-package :fol.benchmarks.transients)

(defparameter *trials* 5)

(defun compile-fol (src transients-on)
  "Compile+eval every form in FOL SRC with *transient-loops* per flag.
   Returns (values LAST-CODE ALL-CODE-STRING); the second value is the printed
   concatenation of every form's emitted code, so callers can detect a
   conversion that lands in any form (e.g. a helper), not just the last."
  (let ((fol.compiler.escape-analysis:*transient-loops* transients-on)
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
  "Non-regex substring replace of FROM by TO throughout S."
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
  "One warm-up + *trials* timed calls; list of (secs . bytes)."
  (funcall thunk)
  (loop repeat *trials*
        collect (progn
                  (sb-ext:gc :full t)
                  (let ((b0 (sb-ext:get-bytes-consed))
                        (t0 (get-internal-real-time)))
                    (funcall thunk)
                    (cons (/ (- (get-internal-real-time) t0)
                             (float internal-time-units-per-second))
                          (- (sb-ext:get-bytes-consed) b0))))))

;;; --- FOL workload sources (~A = function name suffix) ---------------------
(defparameter +workloads+
  ;; label            n        source template                        native
  `(("dict 200k assoc" 200000
     "(defn tb-dict~A [n] (loop [acc {} i 0] (if (< i n) (recur (assoc acc i i) (inc i)) acc)))"
     native-dict)
    ("vector 1M conj"  1000000
     "(defn tb-vec~A [n] (loop [acc [] i 0] (if (< i n) (recur (conj acc i) (inc i)) acc)))"
     native-vec)
    ("reduce 500k conj" 500000
     "(defn tb-red~A [n] (reduce (fn [a x] (conj a x)) [] (loop [v [] i 0] (if (< i n) (recur (conj v i) (inc i)) v))))"
     native-red)
    ("small-N (3 assoc/boundary)" 40000
     "(defn tb-sn~A [m] (loop [tot 0 i 0] (if (< i m) (recur (+ tot (count (loop [acc {} j 0] (if (< j 3) (recur (assoc acc j j) (inc j)) acc)))) (inc i)) tot)))"
     nil)
    ("small-N with reads" 40000
     "(defn tb-snr~A [m] (loop [tot 0 i 0] (if (< i m) (recur (+ tot (count (loop [acc {} j 0] (if (< j 3) (recur (assoc acc j (get acc j)) (inc j)) acc)))) (inc i)) tot)))"
     nil)))

;;; --- Native mutable CL ceilings -------------------------------------------
(defun native-dict (n)
  (declare (fixnum n) (optimize (speed 3)))
  (let ((h (make-hash-table :size (* 2 n))))
    (dotimes (i n) (setf (gethash i h) i))
    h))
(defun native-vec (n)
  (declare (fixnum n) (optimize (speed 3)))
  (let ((v (make-array 0 :adjustable t :fill-pointer t)))
    (dotimes (i n) (vector-push-extend i v))
    v))
(defun native-red (n)
  (declare (fixnum n) (optimize (speed 3)))
  ;; build input then fold it into a fresh vector, mirroring the FOL reduce
  (let ((in (make-array n)))
    (dotimes (i n) (setf (aref in i) i))
    (let ((out (make-array 0 :adjustable t :fill-pointer t)))
      (loop for x across in do (vector-push-extend x out))
      out)))

(defun result-key (v)
  "Comparable summary of a workload result (count for collections, value for numbers)."
  (if (numberp v) v (fol.compiler.collection-functions:count v)))

(defun run-workload (label n template native)
  (let* ((base-name (format nil "~A" (gensym "B")))
         (opt-name  (format nil "~A" (gensym "O"))))
    (compile-fol (format nil template (string-downcase base-name)) nil)
    (multiple-value-bind (opt-code all) (compile-fol (format nil template (string-downcase opt-name)) t)
      (declare (ignore opt-code))
      (assert (converted-p all) () "workload ~A did not convert" label))
    (let* ((prefix (subseq template (length "(defn ") (position #\~ template)))
           (fb (fol-fn (concatenate 'string prefix (string base-name))))
           (fo (fol-fn (concatenate 'string prefix (string opt-name))))
           (rb (funcall fb n)) (ro (funcall fo n)))
      (assert (equalp (result-key rb) (result-key ro)) ()
              "workload ~A results differ" label)
      (let* ((tb (trials (lambda () (funcall fb n))))
             (to (trials (lambda () (funcall fo n))))
             (tn (when native (trials (lambda () (funcall native n)))))
             (bt (mapcar #'car tb)) (ot (mapcar #'car to))
             (bb (mean (mapcar #'cdr tb))) (ob (mean (mapcar #'cdr to))))
        (format t "~&~A (n=~:D, result=~A)~%" label n (result-key rb))
        (format t "  baseline : ~7,1F +/- ~5,1F ms   ~8,1F MB/call~%"
                (* 1000 (mean bt)) (* 1000 (sd bt)) (/ bb 1048576.0))
        (format t "  converted: ~7,1F +/- ~5,1F ms   ~8,1F MB/call   ~5,2Fx time  ~5,2Fx alloc~%"
                (* 1000 (mean ot)) (* 1000 (sd ot)) (/ ob 1048576.0)
                (/ (mean bt) (mean ot)) (/ bb (max 1.0 ob)))
        (when tn
          (let ((nt (mapcar #'car tn)))
            (format t "  mutable CL: ~6,1F +/- ~5,1F ms   (converted = ~,2Fx CL time)~%"
                    (* 1000 (mean nt)) (* 1000 (sd nt))
                    (/ (mean ot) (mean nt)))))))))

;;; --- Whole-program workloads ----------------------------------------------
;;; Each entry drives a complete algorithm, not an isolated loop, so the
;;; end-to-end speedup includes the unconverted work (reads, concatenation,
;;; recursion) that dilutes the microbenchmark ratios. Input is built once,
;;; outside timing. In each template the token %F% is the (gensym'd) entry
;;; function name; self-references and helpers carry it too so the off/on
;;; versions coexist. Boundary entries (expect-convert = NIL) are compiled but
;;; not run: they demonstrate that the analysis refuses an inconvertible style
;;; of the same algorithm.

(defparameter +quicksort-conj+
  ;; Partition by building two FRESH accumulator vectors (less/more) in one
  ;; two-accumulator loop with an exit-in-literal [less more]; converts.
  "(defn entry%F% [v]
     (if (< (count v) 2)
         v
         (bind [pivot (get v 0)
                n (count v)
                parts (loop [i 1 less [] more []]
                        (if (< i n)
                          (if (< (get v i) pivot)
                            (recur (inc i) (conj less (get v i)) more)
                            (recur (inc i) less (conj more (get v i))))
                          [less more]))]
           (concat (conj (entry%F% (get parts 0)) pivot)
                   (entry%F% (get parts 1))))))")

(defparameter +quicksort-swap+
  ;; The in-place-swap style: the accumulator curr-v is the threaded INPUT
  ;; vector (freshness fails) and is updated with assoc (not in the vector
  ;; op-gate). The analysis refuses it -- the boundary twin of the above.
  "(defn part%F% [v low high]
     (bind [pivot (get v high)]
       (loop [j low, i (- low 1), curr-v v]
         (if (< j high)
           (if (<= (get curr-v j) pivot)
             (bind [ni (+ i 1) tmp (get curr-v ni)
                    v1 (assoc curr-v ni (get curr-v j)) v2 (assoc v1 j tmp)]
               (recur (+ j 1) ni v2))
             (recur (+ j 1) i curr-v))
           (bind [ni (+ i 1) tmp (get curr-v ni)
                  v1 (assoc curr-v ni (get curr-v high)) v2 (assoc v1 high tmp)]
             [v2 ni])))))
   (defn entry%F% [v low high]
     (if (< low high)
       (bind [[vp p] (part%F% v low high) vl (entry%F% vp low (- p 1))]
         (entry%F% vl (+ p 1) high))
       v))")

(defparameter +word-count+
  ;; Frequency count: a dict accumulator threaded through a reduce, both READ
  ;; (get) and updated (assoc) each step -- the read-heavy fold edit-tagged
  ;; transients were built for.
  "(defn entry%F% [words]
     (reduce (fn [acc w] (assoc acc w (inc (get acc w 0)))) {} words))")

(defparameter +mk-vec+
  ;; deterministic pseudo-random input vector of N integers mod M
  "(defn mk-input [n m]
     (loop [v [] i 0 s 12345]
       (if (< i n)
         (recur (conj v (mod s m)) (inc i)
                (mod (+ (* s 1103515245) 12345) 2147483648))
         v)))")

(defun native-quicksort (v)
  "Sort a copy of the FOL input vector with CL SORT (native ceiling)."
  (let* ((n (fol.compiler.collection-functions:count v))
         (a (make-array n)))
    (dotimes (i n) (setf (aref a i) (fol.compiler.collection-functions:get v i)))
    (sort a #'<)))

(defun native-word-count (v)
  "Frequency count into a hash table (native ceiling)."
  (let ((h (make-hash-table))
        (n (fol.compiler.collection-functions:count v)))
    (dotimes (i n)
      (let ((w (fol.compiler.collection-functions:get v i)))
        (setf (gethash w h) (1+ (gethash w h 0)))))
    h))

(defun build-input (n m)
  (compile-fol +mk-vec+ nil)
  (funcall (fol-fn "mk-input") n m))

(defun run-program (label input template expect native)
  "Compile TEMPLATE off and on, verify conversion matches EXPECT, and (when it
   converts) verify equal results and time off/on/native."
  (let ((bname (string-downcase (symbol-name (gensym "PB"))))
        (oname (string-downcase (symbol-name (gensym "PO")))))
    (compile-fol (replace-all template "%F%" bname) nil)
    (multiple-value-bind (code all) (compile-fol (replace-all template "%F%" oname) t)
      (declare (ignore code))
      (let ((did (converted-p all)))
        (assert (eq did expect) ()
                "~A: converted=~A but expected ~A" label did expect)
        (unless expect
          (format t "~&~A~%  correctly NOT converted (boundary: freshness + op-gate)~%" label)
          (return-from run-program))
        (let* ((fb (fol-fn (concatenate 'string "entry" bname)))
               (fo (fol-fn (concatenate 'string "entry" oname)))
               (rb (funcall fb input)) (ro (funcall fo input)))
          (assert (equalp (result-key rb) (result-key ro)) ()
                  "~A: results differ off vs on" label)
          (let* ((tb (trials (lambda () (funcall fb input))))
                 (to (trials (lambda () (funcall fo input))))
                 (tn (when native (trials (lambda () (funcall native input)))))
                 (bt (mapcar #'car tb)) (ot (mapcar #'car to))
                 (bb (mean (mapcar #'cdr tb))) (ob (mean (mapcar #'cdr to))))
            (format t "~&~A (result=~A)~%" label (result-key rb))
            (format t "  baseline : ~7,1F +/- ~5,1F ms   ~8,1F MB/call~%"
                    (* 1000 (mean bt)) (* 1000 (sd bt)) (/ bb 1048576.0))
            (format t "  converted: ~7,1F +/- ~5,1F ms   ~8,1F MB/call   ~5,2Fx time  ~5,2Fx alloc~%"
                    (* 1000 (mean ot)) (* 1000 (sd ot)) (/ ob 1048576.0)
                    (/ (mean bt) (mean ot)) (/ bb (max 1.0 ob)))
            (when tn
              (let ((nt (mapcar #'car tn)))
                (format t "  native CL: ~6,1F +/- ~5,1F ms   (converted = ~,2Fx CL time)~%"
                        (* 1000 (mean nt)) (* 1000 (sd nt))
                        (/ (mean ot) (mean nt)))))))))))

(defun main ()
  (format t "~&=== Transient conversion benchmarks ===~%")
  (format t "SBCL ~A, dynamic space ~,0F MB, ~D trials (mean +/- sd), full GC before each~%"
          (lisp-implementation-version) (/ (sb-ext:dynamic-space-size) 1048576.0) *trials*)
  (format t "~%-- Microbenchmarks (isolated accumulation loops) --~%")
  (dolist (w +workloads+)
    (destructuring-bind (label n template native) w
      (run-workload label n template (and native (symbol-function native)))))
  (format t "~%-- Whole-program benchmarks --~%")
  (let ((qinput (build-input 50000 100000))
        (winput (build-input 200000 997)))
    (run-program "quicksort (conj-partition, 50k)" qinput +quicksort-conj+ t #'native-quicksort)
    (run-program "quicksort (in-place-swap, 50k)"  qinput +quicksort-swap+ nil nil)
    (run-program "word-count (200k tokens, 997 keys)" winput +word-count+ t #'native-word-count))
  (format t "~&Done.~%"))

(main)
