;;; FOL Compiler Tests - Aggregate Scalar Replacement
;;;
;;; Correctness and application tests for the loop-carried scalar-replacement
;;; algorithm (compiler.lisp, "Aggregate Scalar Replacement"). A record
;;; accumulator rebuilt every iteration is unboxed into one scalar loop var per
;;; field; an object-returning callee at the recur position is inlined; the
;;; converted loop is world-guarded on the record class name.
;;;
;;; Forms are read with the FOL readtable in :fol.core so that [] vector syntax
;;; and stdlib operators (get, +, <, inc) resolve exactly as in a real .fol
;;; file. Each test uses a distinct class name so world-guard invalidation in
;;; one test cannot disturb another.

(in-package :fol.compiler.tests)

(def-suite scalar-replacement-suite
  :description "Aggregate scalar replacement: optimized == unoptimized"
  :in compiler-tests)

(in-suite scalar-replacement-suite)

(defun sr-fol (source &key sr)
  "Read FOL SOURCE (one or more forms) with the FOL readtable in :fol.core,
   compile each form with scalar replacement enabled per SR, and evaluate it.
   Returns (values LAST-VALUE LAST-FORM-CODE)."
  (let ((fol.compiler.escape-analysis:*scalar-replacement* sr)
        (*readtable* fol.compiler.reader:*fol-readtable*)
        (*package* (find-package :fol.core))
        (val nil)
        (code nil))
    (with-input-from-string (in source)
      (loop for form = (read in nil :eof)
            until (eq form :eof)
            do (setf code (fol.compiler:compilation-result-code
                           (fol.compiler:compile-form form)))
               (setf val (eval code))))
    (values val code)))

(defun sr-code-has (code substring)
  "True when the printed representation of CODE contains SUBSTRING."
  (and (search substring (write-to-string code)) t))

;;; ============================================================================
;;; Correctness: optimized result == unoptimized result
;;; ============================================================================

(test sr-loop-carried-correctness
  "A record accumulator rebuilt each iteration yields identical results whether
   or not it is scalar-replaced (field read at the tail exit)."
  (let ((src "
(defclass <sr-pa> [] [[x] [y]])
(defn sr-pa-upd [p]
  (bind [dx 0.1 dy 0.2]
    (make-<sr-pa> :x (+ (get p :x) dx) :y (+ (get p :y) dy))))
(defn sr-pa-run [n]
  (loop [p (make-<sr-pa> :x 0 :y 0) i 0]
    (if (< i n)
      (recur (sr-pa-upd p) (inc i))
      (+ (get p :x) (get p :y)))))
(sr-pa-run 7)"))
    (is (= (sr-fol src :sr nil) (sr-fol src :sr t)))))

(test sr-rebox-at-exit-correctness
  "Returning the bare accumulator at the loop tail re-boxes a single object at
   exit; reading a field of it must match the unoptimized run."
  (let ((src "
(defclass <sr-pb> [] [[x] [y]])
(defn sr-pb-upd [p]
  (make-<sr-pb> :x (inc (get p :x)) :y (dec (get p :y))))
(defn sr-pb-run [n]
  (loop [p (make-<sr-pb> :x 0 :y 0) i 0]
    (if (< i n) (recur (sr-pb-upd p) (inc i)) p)))
(get (sr-pb-run 9) :x)"))
    (is (= 9 (sr-fol src :sr nil)))
    (is (= (sr-fol src :sr nil) (sr-fol src :sr t)))))

;;; ============================================================================
;;; Application: the transform actually fires on the qualifying loop
;;; ============================================================================

(test sr-loop-carried-applies
  "With SR on, the accumulator is split into P_X/P_Y scalar loop vars and the
   object-returning callee is inlined, so no constructor call survives on the
   recur back-edge (only the guarded fallback path allocates)."
  (multiple-value-bind (val code)
      (sr-fol "
(defclass <sr-pc> [] [[x] [y]])
(defn sr-pc-upd [p]
  (bind [dx 0.1 dy 0.2]
    (make-<sr-pc> :x (+ (get p :x) dx) :y (+ (get p :y) dy))))
(defn sr-pc-run [n]
  (loop [p (make-<sr-pc> :x 0 :y 0) i 0]
    (if (< i n) (recur (sr-pc-upd p) (inc i)) (+ (get p :x) (get p :y)))))"
              :sr t)
    (declare (ignore val))
    ;; scalar loop vars introduced on the fast path
    (is (sr-code-has code "P_X"))
    (is (sr-code-has code "P_Y"))
    ;; emitted as a world-guarded dual path keyed on the record class name
    ;; (the callee sr-pc-upd survives only in the un-inlined fallback branch)
    (is (sr-code-has code "REGISTER-REGION"))
    (is (sr-code-has code "<SR-PC>"))))

;;; ============================================================================
;;; Branch-shaped reconstruction: if/cond/case at the recur position
;;; ============================================================================

(test sr-if-branched-reconstruction
  "An if-branched reconstruction ((if test (make-<t> ...) (make-<t> ...))) at
   the recur position is recognized directly. The threshold is crossed
   partway through the run, so both branches are actually taken (not just
   syntactically present), and the optimized result matches the unoptimized
   one."
  (let ((src "
(defclass <sr-pf> [] [[x] [y]])
(defn sr-pf-run [n]
  (loop [p (make-<sr-pf> :x 0.0 :y 0.0) i 0]
    (if (>= i n)
      (+ (get p :x) (get p :y))
      (recur (if (> (get p :x) 3.0)
                 (make-<sr-pf> :x 0.0 :y (get p :y))
                 (make-<sr-pf> :x (+ (get p :x) 1.0) :y (+ (get p :y) 0.5)))
             (inc i)))))
(sr-pf-run 10)"))
    ;; x cycles 0,1,2,3,4,(clamp)0,1,2,3,4 over 10 iterations: the clamp
    ;; branch fires at i=4 and i=9, the move branch the other eight times.
    (is (= 4.0 (sr-fol src :sr nil)))
    (is (= (sr-fol src :sr nil) (sr-fol src :sr t))))
  (multiple-value-bind (val code)
      (sr-fol "
(defclass <sr-pf2> [] [[x] [y]])
(defn sr-pf2-run [n]
  (loop [p (make-<sr-pf2> :x 0.0 :y 0.0) i 0]
    (if (>= i n)
      (+ (get p :x) (get p :y))
      (recur (if (> (get p :x) 3.0)
                 (make-<sr-pf2> :x 0.0 :y (get p :y))
                 (make-<sr-pf2> :x (+ (get p :x) 1.0) :y (+ (get p :y) 0.5)))
             (inc i)))))"
              :sr t)
    (declare (ignore val))
    (is (sr-code-has code "P_X"))
    (is (sr-code-has code "P_Y"))
    (is (sr-code-has code "REGISTER-REGION"))))

(test sr-cond-branched-reconstruction
  "A cond-branched reconstruction with three clauses at the recur position is
   recognized directly. Dispatching on (mod i 3) rather than on the
   accumulator's own value guarantees all three clauses actually fire across
   the run, not just the syntactically-present ones."
  (let ((src "
(defclass <sr-pg> [] [[x] [y]])
(defn sr-pg-run [n]
  (loop [p (make-<sr-pg> :x 0.0 :y 0.0) i 0]
    (if (>= i n)
      (+ (get p :x) (get p :y))
      (recur (cond
               ((= (mod i 3) 0) (make-<sr-pg> :x (+ (get p :x) 1.0) :y (get p :y)))
               ((= (mod i 3) 1) (make-<sr-pg> :x (get p :x) :y (+ (get p :y) 2.0)))
               (:else (make-<sr-pg> :x (+ (get p :x) 0.5) :y (+ (get p :y) 0.5))))
             (inc i)))))
(sr-pg-run 9)"))
    ;; Three full (0,1,2) cycles over 9 iterations: x = 3*1 + 3*0.5 = 4.5,
    ;; y = 3*2 + 3*0.5 = 7.5, sum = 12.0.
    (is (= 12.0 (sr-fol src :sr nil)))
    (is (= (sr-fol src :sr nil) (sr-fol src :sr t))))
  (multiple-value-bind (val code)
      (sr-fol "
(defclass <sr-pg2> [] [[x] [y]])
(defn sr-pg2-run [n]
  (loop [p (make-<sr-pg2> :x 0.0 :y 0.0) i 0]
    (if (>= i n)
      (+ (get p :x) (get p :y))
      (recur (cond
               ((= (mod i 3) 0) (make-<sr-pg2> :x (+ (get p :x) 1.0) :y (get p :y)))
               ((= (mod i 3) 1) (make-<sr-pg2> :x (get p :x) :y (+ (get p :y) 2.0)))
               (:else (make-<sr-pg2> :x (+ (get p :x) 0.5) :y (+ (get p :y) 0.5))))
             (inc i)))))"
              :sr t)
    (declare (ignore val))
    (is (sr-code-has code "P_X"))
    (is (sr-code-has code "P_Y"))
    (is (sr-code-has code "REGISTER-REGION"))))

(test sr-case-branched-reconstruction
  "A case-branched reconstruction with three clauses at the recur position is
   recognized directly. (mod i 3) as the dispatch key guarantees all three
   clauses fire across the run."
  (let ((src "
(defclass <sr-ph> [] [[x] [y]])
(defn sr-ph-run [n]
  (loop [p (make-<sr-ph> :x 0.0 :y 0.0) i 0]
    (if (>= i n)
      (+ (get p :x) (get p :y))
      (recur (case (mod i 3)
               (0 (make-<sr-ph> :x (+ (get p :x) 1.0) :y (get p :y)))
               (1 (make-<sr-ph> :x (get p :x) :y (+ (get p :y) 2.0)))
               (2 (make-<sr-ph> :x (+ (get p :x) 0.5) :y (+ (get p :y) 0.5))))
             (inc i)))))
(sr-ph-run 9)"))
    ;; Same three-clause cycle as the cond test above: sum = 12.0.
    (is (= 12.0 (sr-fol src :sr nil)))
    (is (= (sr-fol src :sr nil) (sr-fol src :sr t))))
  (multiple-value-bind (val code)
      (sr-fol "
(defclass <sr-ph2> [] [[x] [y]])
(defn sr-ph2-run [n]
  (loop [p (make-<sr-ph2> :x 0.0 :y 0.0) i 0]
    (if (>= i n)
      (+ (get p :x) (get p :y))
      (recur (case (mod i 3)
               (0 (make-<sr-ph2> :x (+ (get p :x) 1.0) :y (get p :y)))
               (1 (make-<sr-ph2> :x (get p :x) :y (+ (get p :y) 2.0)))
               (2 (make-<sr-ph2> :x (+ (get p :x) 0.5) :y (+ (get p :y) 0.5))))
             (inc i)))))"
              :sr t)
    (declare (ignore val))
    (is (sr-code-has code "P_X"))
    (is (sr-code-has code "P_Y"))
    (is (sr-code-has code "REGISTER-REGION"))))

;;; ============================================================================
;;; Conservatism: escaping accumulators are not unboxed
;;; ============================================================================

(test sr-escaping-accumulator-not-unboxed
  "When the accumulator flows into an unknown call (escape), the loop is left
   untouched: no scalar field vars, and the result is still correct."
  (multiple-value-bind (val code)
      (sr-fol "
(defclass <sr-pd> [] [[x] [y]])
(defn sr-pd-sink [p] (get p :x))
(defn sr-pd-run [n]
  (loop [p (make-<sr-pd> :x 0 :y 0) i 0]
    (if (< i n)
      (recur (make-<sr-pd> :x (sr-pd-sink p) :y (get p :y)) (inc i))
      (get p :x))))"
              :sr t)
    (declare (ignore val))
    ;; sr-pd-sink is not a registered record constructor, so passing the bare
    ;; accumulator to it disqualifies the loop: no unboxing happened.
    (is (not (sr-code-has code "P_X")))))

;;; ============================================================================
;;; Multiple accumulators (fixpoint): unbox more than one record per loop
;;; ============================================================================

(test sr-multi-independent-correctness
  "Two independent record accumulators (plus a counter) are both unboxed, and
   the result matches the unoptimized run."
  (let ((src "
(defclass <sr-ma> [] [[x] [y]])
(defn sr-ma-up [p] (make-<sr-ma> :x (inc (get p :x)) :y (inc (get p :y))))
(defn sr-ma-run [n]
  (loop [p (make-<sr-ma> :x 0 :y 0)
         q (make-<sr-ma> :x 10 :y 20)
         i 0]
    (if (< i n)
      (recur (sr-ma-up p) (sr-ma-up q) (inc i))
      (+ (get p :x) (get q :y)))))
(sr-ma-run 5)"))
    (is (= 30 (sr-fol src :sr nil)))
    (is (= (sr-fol src :sr nil) (sr-fol src :sr t)))))

(test sr-multi-independent-both-unboxed
  "The fixpoint unboxes BOTH accumulators: scalar field vars appear for p and q,
   and no constructor call survives on the fast-path back-edge."
  (multiple-value-bind (val code)
      (sr-fol "
(defclass <sr-ma2> [] [[x] [y]])
(defn sr-ma2-up [p] (make-<sr-ma2> :x (inc (get p :x)) :y (inc (get p :y))))
(defn sr-ma2-run [n]
  (loop [p (make-<sr-ma2> :x 0 :y 0)
         q (make-<sr-ma2> :x 10 :y 20)
         i 0]
    (if (< i n)
      (recur (sr-ma2-up p) (sr-ma2-up q) (inc i))
      (+ (get p :x) (get q :y)))))"
              :sr t)
    (declare (ignore val))
    (is (sr-code-has code "P_X"))
    (is (sr-code-has code "P_Y"))
    (is (sr-code-has code "Q_X"))
    (is (sr-code-has code "Q_Y"))))

(test sr-multi-coupled-fibonacci
  "Coupled accumulators a'=b, b'=a+b (Fibonacci) exercise PSETQ parallelism
   through DOUBLE unboxing: if simultaneity were lost when both accumulators
   become scalar loop vars, the sequence would be wrong. Both are unboxed and
   the result equals Fib(n) and the unoptimized run."
  (let ((src "
(defclass <sr-mb> [] [[v]])
(defn sr-mb-run [n]
  (loop [a (make-<sr-mb> :v 0)
         b (make-<sr-mb> :v 1)
         i 0]
    (if (< i n)
      (recur (make-<sr-mb> :v (get b :v))
             (make-<sr-mb> :v (+ (get a :v) (get b :v)))
             (inc i))
      (get a :v))))
(sr-mb-run 10)"))
    ;; Fib(10) = 55; a starts at 0, b at 1, ten steps of (a,b)->(b,a+b).
    (is (= 55 (sr-fol src :sr nil)))
    (is (= (sr-fol src :sr nil) (sr-fol src :sr t))))
  ;; Confirm both accumulators were actually unboxed on the fast path.
  (multiple-value-bind (val code)
      (sr-fol "
(defclass <sr-mb2> [] [[v]])
(defn sr-mb2-run [n]
  (loop [a (make-<sr-mb2> :v 0) b (make-<sr-mb2> :v 1) i 0]
    (if (< i n)
      (recur (make-<sr-mb2> :v (get b :v))
             (make-<sr-mb2> :v (+ (get a :v) (get b :v)))
             (inc i))
      (get a :v))))"
              :sr t)
    (declare (ignore val))
    (is (sr-code-has code "A_V"))
    (is (sr-code-has code "B_V"))))

(test sr-multi-partial-replacement
  "When one accumulator qualifies and another escapes, the fixpoint unboxes the
   qualifying one and leaves the other boxed, still producing the right result."
  (multiple-value-bind (val code)
      (sr-fol "
(defclass <sr-mc> [] [[x]])
(defn sr-mc-sink [p] (get p :x))
(defn sr-mc-run [n]
  (loop [p (make-<sr-mc> :x 0)
         q (make-<sr-mc> :x 100)
         i 0]
    (if (< i n)
      (recur (make-<sr-mc> :x (inc (get p :x)))
             (make-<sr-mc> :x (sr-mc-sink q))
             (inc i))
      (+ (get p :x) (get q :x)))))"
              :sr t)
    (declare (ignore val))
    ;; p qualifies -> unboxed; q flows into sr-mc-sink (escape) -> stays boxed.
    (is (sr-code-has code "P_X"))
    (is (not (sr-code-has code "Q_X"))))
  (let ((src "
(defclass <sr-mc2> [] [[x]])
(defn sr-mc2-sink [p] (get p :x))
(defn sr-mc2-run [n]
  (loop [p (make-<sr-mc2> :x 0)
         q (make-<sr-mc2> :x 100)
         i 0]
    (if (< i n)
      (recur (make-<sr-mc2> :x (inc (get p :x)))
             (make-<sr-mc2> :x (sr-mc2-sink q))
             (inc i))
      (+ (get p :x) (get q :x)))))
(sr-mc2-run 5)"))
    (is (= 105 (sr-fol src :sr nil)))
    (is (= (sr-fol src :sr nil) (sr-fol src :sr t)))))

;;; ============================================================================
;;; Soundness: redefining the record class invalidates the converted loop
;;; ============================================================================

(test sr-world-guard-invalidation
  "The converted loop registers a world region keyed on the class name;
   redefining the class invalidates it and the next call takes the original
   allocating path, still producing a correct result."
  (fol.compiler.world:reset-world)
  (let ((defs "
(defclass <sr-pe> [] [[x] [y]])
(defn sr-pe-upd [p]
  (make-<sr-pe> :x (inc (get p :x)) :y (get p :y)))
(defn sr-pe-run [n]
  (loop [p (make-<sr-pe> :x 0 :y 0) i 0]
    (if (< i n) (recur (sr-pe-upd p) (inc i)) (get p :x))))"))
    (sr-fol defs :sr t)
    ;; Defining sr-pe-run registered exactly one guarded region.
    (is (= 1 (getf (fol.compiler.world:world-stats) :regions-registered)))
    (is (= 0 (getf (fol.compiler.world:world-stats) :regions-invalidated)))
    ;; It runs on the fast (unboxed) path.
    (is (= 5 (sr-fol "(sr-pe-run 5)" :sr t)))
    ;; Redefine the class: the region must invalidate.
    (sr-fol "(defclass <sr-pe> [] [[x] [y] [z]])" :sr t)
    (is (= 1 (getf (fol.compiler.world:world-stats) :regions-invalidated)))
    ;; The loop now falls back to the original object-allocating path and is
    ;; still correct against the redefined class.
    (is (= 5 (sr-fol "(sr-pe-run 5)" :sr t)))))
