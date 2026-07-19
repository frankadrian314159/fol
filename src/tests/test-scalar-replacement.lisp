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

(defun dict-sr-fol (source &key dict-sr)
  "Like SR-FOL, but for dict-mode intra-bind scalar replacement:
   *SCALAR-REPLACEMENT* stays off, *DICT-SCALAR-REPLACEMENT* is bound to
   DICT-SR. Returns (values LAST-VALUE LAST-FORM-CODE)."
  (let ((fol.compiler.escape-analysis:*scalar-replacement* nil)
        (fol.compiler.escape-analysis:*dict-scalar-replacement* dict-sr)
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

;;; ============================================================================
;;; Non-trivial accumulator argument to an inlinable callee: the accumulator
;;; may arrive at the callee's parameter position wrapped in a single ASSOC,
;;; not just as a bare alias. Every other argument must still be trivial, and
;;; shapes outside ASSOC (e.g. an IF-wrapped argument) still decline safely.
;;; ============================================================================

(test sr-inlinable-callee-assoc-arg-correctness
  "An inlinable callee invoked with (assoc acc :k v ...) as its accumulator
   argument is still recognized: the updated field (:x) and the untouched
   passthrough field (:y) both resolve correctly inside the callee, and the
   optimized result matches the unoptimized one."
  (let ((src "
(defclass <sr-pi> [] [[x] [y]])
(defn sr-pi-bump [q] (make-<sr-pi> :x (+ (get q :x) 1) :y (+ (get q :y) 1)))
(defn sr-pi-run [n]
  (loop [p (make-<sr-pi> :x 0 :y 0) i 0]
    (if (< i n)
      (recur (sr-pi-bump (assoc p :x (+ (get p :x) 10))) (inc i))
      (+ (get p :x) (get p :y)))))
(sr-pi-run 5)"))
    (is (= 60 (sr-fol src :sr nil)))
    (is (= (sr-fol src :sr nil) (sr-fol src :sr t)))))

(test sr-inlinable-callee-assoc-arg-applies
  "With SR on, the assoc-wrapped accumulator argument still unboxes: the
   loop's own P_X/P_Y field vars appear, a fresh Q_X binding carries the
   updated field into the inlined callee, and the fast path is world-guarded."
  (multiple-value-bind (val code)
      (sr-fol "
(defclass <sr-pi2> [] [[x] [y]])
(defn sr-pi2-bump [q] (make-<sr-pi2> :x (+ (get q :x) 1) :y (+ (get q :y) 1)))
(defn sr-pi2-run [n]
  (loop [p (make-<sr-pi2> :x 0 :y 0) i 0]
    (if (< i n)
      (recur (sr-pi2-bump (assoc p :x (+ (get p :x) 10))) (inc i))
      (+ (get p :x) (get p :y)))))"
              :sr t)
    (declare (ignore val))
    (is (sr-code-has code "P_X"))
    (is (sr-code-has code "P_Y"))
    ;; the non-trivial update value (+ (get p :x) 10) is pinned to a fresh,
    ;; single-evaluation scalar var named for the callee's own parameter.
    (is (sr-code-has code "Q_X"))
    (is (sr-code-has code "REGISTER-REGION"))
    (is (sr-code-has code "<SR-PI2>"))))

(test sr-inlinable-callee-nontrivial-other-arg-still-declines
  "Extension A relaxes only the accumulator argument's shape. A different,
   non-accumulator argument that is still a compound expression (not a bare
   symbol or literal) must continue to disqualify the loop."
  (multiple-value-bind (val code)
      (sr-fol "
(defclass <sr-pl> [] [[x] [y]])
(defn sr-pl-bump [q extra] (make-<sr-pl> :x (+ (get q :x) extra) :y (get q :y)))
(defn sr-pl-run [n]
  (loop [p (make-<sr-pl> :x 0 :y 0) i 0]
    (if (< i n) (recur (sr-pl-bump p (+ i 1)) (inc i)) (+ (get p :x) (get p :y)))))
(sr-pl-run 5)"
              :sr t)
    (is (= 15 val))
    (is (not (sr-code-has code "P_X")))))

(test sr-inlinable-callee-if-wrapped-arg-declines-safely
  "An accumulator argument wrapped in a shape other than a bare alias or a
   single ASSOC (here, an IF) is outside Extension A's scope and must still
   decline safely, not crash -- the result stays correct via fallback."
  (let ((src "
(defclass <sr-pj> [] [[x] [y]])
(defn sr-pj-bump [q] (make-<sr-pj> :x (+ (get q :x) 1) :y (+ (get q :y) 1)))
(defn sr-pj-run [n]
  (loop [p (make-<sr-pj> :x 0 :y 0) i 0]
    (if (< i n)
      (recur (sr-pj-bump (if (< i 2) p p)) (inc i))
      (+ (get p :x) (get p :y)))))
(sr-pj-run 5)"))
    (is (= (sr-fol src :sr nil) (sr-fol src :sr t)))
    (multiple-value-bind (val code) (sr-fol src :sr t)
      (declare (ignore val))
      (is (not (sr-code-has code "P_X"))))))

(test sr-inlinable-callee-two-alias-args-still-declines
  "A callee invoked with the SAME accumulator passed as two separate
   arguments is still the unsupported 'more than one record' shape and must
   decline, not misfire by picking one arbitrarily."
  (multiple-value-bind (val code)
      (sr-fol "
(defclass <sr-pk> [] [[x] [y]])
(defn sr-pk-mix [a b] (make-<sr-pk> :x (get a :x) :y (get b :y)))
(defn sr-pk-run [n]
  (loop [p (make-<sr-pk> :x 0 :y 0) i 0]
    (if (< i n) (recur (sr-pk-mix p p) (inc i)) (+ (get p :x) (get p :y)))))
(sr-pk-run 5)"
              :sr t)
    (is (= 0 val))
    (is (not (sr-code-has code "P_X")))))

;;; ============================================================================
;;; Extension B: an inlinable callee whose own body is IF/COND/CASE-branched
;;; (more than one constructor call reachable in its source), not just a
;;; single direct constructor call. Registration (%SR-REGISTER-DEFN) accepts
;;; the shape; EXPAND-ACC's existing, already-general branch reconstruction
;;; (used directly at the recur position since sr-if-branched-reconstruction)
;;; does the real work once the callee is actually inlined.
;;; ============================================================================

(test sr-inlinable-callee-if-branched-body-correctness
  "An inlinable helper whose body is (if test (make-<T> ...) (make-<T> ...))
   -- rather than a single direct constructor call -- is still recognized
   when called with the bare accumulator; the optimized result matches the
   unoptimized one across both branches actually firing."
  (let ((src "
(defclass <sr-pm> [] [[x] [y]])
(defn sr-pm-step [p]
  (if (> (get p :x) 3.0)
      (make-<sr-pm> :x 0.0 :y (get p :y))
      (make-<sr-pm> :x (+ (get p :x) 1.0) :y (+ (get p :y) 0.5))))
(defn sr-pm-run [n]
  (loop [p (make-<sr-pm> :x 0.0 :y 0.0) i 0]
    (if (< i n) (recur (sr-pm-step p) (inc i)) (+ (get p :x) (get p :y)))))
(sr-pm-run 10)"))
    ;; Same transition table as sr-if-branched-reconstruction, now reached
    ;; through an inlined callee instead of a recur-position if directly.
    (is (= 4.0 (sr-fol src :sr nil)))
    (is (= (sr-fol src :sr nil) (sr-fol src :sr t)))))

(test sr-inlinable-callee-if-branched-body-applies
  "With SR on, the if-branched callee body is actually inlined: the loop's
   own P_X/P_Y field vars appear and the fast path is world-guarded."
  (multiple-value-bind (val code)
      (sr-fol "
(defclass <sr-pm2> [] [[x] [y]])
(defn sr-pm2-step [p]
  (if (> (get p :x) 3.0)
      (make-<sr-pm2> :x 0.0 :y (get p :y))
      (make-<sr-pm2> :x (+ (get p :x) 1.0) :y (+ (get p :y) 0.5))))
(defn sr-pm2-run [n]
  (loop [p (make-<sr-pm2> :x 0.0 :y 0.0) i 0]
    (if (< i n) (recur (sr-pm2-step p) (inc i)) (+ (get p :x) (get p :y)))))"
              :sr t)
    (declare (ignore val))
    (is (sr-code-has code "P_X"))
    (is (sr-code-has code "P_Y"))
    (is (sr-code-has code "REGISTER-REGION"))
    (is (sr-code-has code "<SR-PM2>"))))

(test sr-inlinable-callee-cond-branched-body-correctness
  "A COND-branched callee body (three clauses, not two) is likewise
   recognized; the optimized result matches the unoptimized one."
  (let ((src "
(defclass <sr-pq> [] [[x] [y]])
(defn sr-pq-step [p]
  (cond
    ((> (get p :x) 6.0) (make-<sr-pq> :x 0.0 :y (get p :y)))
    ((> (get p :x) 3.0) (make-<sr-pq> :x (+ (get p :x) 2.0) :y (+ (get p :y) 1.0)))
    (:else (make-<sr-pq> :x (+ (get p :x) 1.0) :y (+ (get p :y) 0.5)))))
(defn sr-pq-run [n]
  (loop [p (make-<sr-pq> :x 0.0 :y 0.0) i 0]
    (if (< i n) (recur (sr-pq-step p) (inc i)) (+ (get p :x) (get p :y)))))
(sr-pq-run 10)"))
    (is (= 8.5 (sr-fol src :sr nil)))
    (is (= (sr-fol src :sr nil) (sr-fol src :sr t)))))

(test sr-inlinable-callee-branch-escape-declines-safely
  "One branch of the callee's body routes the bare accumulator through an
   unrelated function before reconstructing -- a real escape, not just an
   unrecognized literal. The whole loop must decline safely, not crash, and
   the result stays correct via fallback (checked against the unoptimized
   run, not a hand-derived constant)."
  (let ((src "
(defclass <sr-pn> [] [[x] [y]])
(defn sr-pn-sink [p] (get p :x))
(defn sr-pn-step [p]
  (if (> (get p :x) 3.0)
      (make-<sr-pn> :x (sr-pn-sink p) :y (get p :y))
      (make-<sr-pn> :x (+ (get p :x) 1.0) :y (+ (get p :y) 0.5))))
(defn sr-pn-run [n]
  (loop [p (make-<sr-pn> :x 0.0 :y 0.0) i 0]
    (if (< i n) (recur (sr-pn-step p) (inc i)) (+ (get p :x) (get p :y)))))
(sr-pn-run 10)"))
    (is (= (sr-fol src :sr nil) (sr-fol src :sr t))))
  (multiple-value-bind (val code)
      (sr-fol "
(defclass <sr-pn2> [] [[x] [y]])
(defn sr-pn2-sink [p] (get p :x))
(defn sr-pn2-step [p]
  (if (> (get p :x) 3.0)
      (make-<sr-pn2> :x (sr-pn2-sink p) :y (get p :y))
      (make-<sr-pn2> :x (+ (get p :x) 1.0) :y (+ (get p :y) 0.5))))
(defn sr-pn2-run [n]
  (loop [p (make-<sr-pn2> :x 0.0 :y 0.0) i 0]
    (if (< i n) (recur (sr-pn2-step p) (inc i)) (+ (get p :x) (get p :y)))))
(sr-pn2-run 10)"
              :sr t)
    (declare (ignore val))
    (is (not (sr-code-has code "P_X")))))

(test sr-inlinable-callee-non-record-branch-declines-safely
  "A callee body branch that is not a record at all (a bare literal) is
   registered on shape alone -- Extension B does not pre-validate branch
   content -- but must decline safely at actual inlining time, not crash."
  (multiple-value-bind (val code)
      (sr-fol "
(defclass <sr-po> [] [[x] [y]])
(defn sr-po-maybe [p]
  (if (> (get p :x) 100)
      42
      (make-<sr-po> :x (+ (get p :x) 1) :y (+ (get p :y) 1))))
(defn sr-po-run [n]
  (loop [p (make-<sr-po> :x 0 :y 0) i 0]
    (if (< i n) (recur (sr-po-maybe p) (inc i)) (+ (get p :x) (get p :y)))))
(sr-po-run 5)"
              :sr t)
    (is (= 10 val))
    (is (not (sr-code-has code "P_X")))))

;;; ============================================================================
;;; Nested-loop reads: a nested loop inside the body may READ the outer
;;; accumulator's fields (via GET); the outer accumulator itself may not
;;; escape into or through the nested loop (bare reference, shadowed
;;; binding name). Matches the shape found in fastmath's real corpus code
;;; (a DLA-style random walk carrying a Vec2 accumulator whose fields are
;;; read several let/if/case layers deep inside a nested search loop).
;;; ============================================================================

(test sr-nested-loop-read-correctness
  "A nested loop that only READS the outer accumulator's fields (never a
   bare reference) does not block unboxing; the optimized result matches
   the unoptimized one."
  (let ((src "
(defclass <sr-nr> [] [[x] [y]])
(defn sr-nr-run [n]
  (loop [p (make-<sr-nr> :x 0.0 :y 0.0) i 0]
    (if (< i n)
      (recur (make-<sr-nr>
               :x (loop [j 0 total 0.0]
                    (if (< j 3)
                      (recur (inc j) (+ total (get p :x) 1.0))
                      total))
               :y (+ (get p :y) 1.0))
             (inc i))
      (+ (get p :x) (get p :y)))))
(sr-nr-run 4)"))
    ;; p.x_{k+1} = 3*(p.x_k + 1), p.y_{k+1} = p.y_k + 1, from (0,0) over 4 steps.
    (is (= 124.0 (sr-fol src :sr nil)))
    (is (= (sr-fol src :sr nil) (sr-fol src :sr t)))))

(test sr-nested-loop-read-applies
  "With SR on, the outer accumulator is still unboxed into P_X/P_Y scalar
   loop vars even though a nested loop reads them; the fast path is
   world-guarded as usual."
  (multiple-value-bind (val code)
      (sr-fol "
(defclass <sr-nr2> [] [[x] [y]])
(defn sr-nr2-run [n]
  (loop [p (make-<sr-nr2> :x 0.0 :y 0.0) i 0]
    (if (< i n)
      (recur (make-<sr-nr2>
               :x (loop [j 0 total 0.0]
                    (if (< j 3)
                      (recur (inc j) (+ total (get p :x) 1.0))
                      total))
               :y (+ (get p :y) 1.0))
             (inc i))
      (+ (get p :x) (get p :y)))))"
              :sr t)
    (declare (ignore val))
    (is (sr-code-has code "P_X"))
    (is (sr-code-has code "P_Y"))
    (is (sr-code-has code "REGISTER-REGION"))
    (is (sr-code-has code "<SR-NR2>"))))

(test sr-nested-loop-shadowed-name-declines-safely
  "A nested loop whose own binding reuses the outer accumulator's name is
   ordinary, well-defined shadowing under normal evaluation, but the
   conservative guard declines to unbox rather than risk an ambiguous
   rewrite; the result is still correct via fallback."
  (let ((src "
(defclass <sr-nu> [] [[x] [y]])
(defn sr-nu-run [n]
  (loop [p (make-<sr-nu> :x 0.0 :y 0.0) i 0]
    (if (< i n)
      (recur (make-<sr-nu>
               :x (loop [p 0.0 j 0] (if (< j 1) (recur (inc p) (inc j)) p))
               :y (+ (get p :y) 1.0))
             (inc i))
      (+ (get p :x) (get p :y)))))
(sr-nu-run 3)"))
    (is (= 4.0 (sr-fol src :sr nil)))
    (is (= (sr-fol src :sr nil) (sr-fol src :sr t))))
  (multiple-value-bind (val code)
      (sr-fol "
(defclass <sr-nu2> [] [[x] [y]])
(defn sr-nu2-run [n]
  (loop [p (make-<sr-nu2> :x 0.0 :y 0.0) i 0]
    (if (< i n)
      (recur (make-<sr-nu2>
               :x (loop [p 0.0 j 0] (if (< j 1) (recur (inc p) (inc j)) p))
               :y (+ (get p :y) 1.0))
             (inc i))
      (+ (get p :x) (get p :y)))))"
              :sr t)
    (declare (ignore val))
    (is (not (sr-code-has code "P_X")))))

(test sr-nested-loop-bare-escape-at-nested-tail-declines-safely
  "A nested loop whose own tail position returns the bare outer accumulator
   (not a field read of it) must still decline, not misfire by reboxing at
   the wrong scope: the guard applies regardless of tail position once
   inside a nested loop."
  (multiple-value-bind (val code)
      (sr-fol "
(defclass <sr-nv> [] [[x] [y]])
(defn sr-nv-run [n]
  (loop [p (make-<sr-nv> :x 0.0 :y 0.0) i 0]
    (if (< i n)
      (recur (make-<sr-nv>
               :x (loop [j 0] (if (< j 1) (recur (inc j)) (get p :x)))
               :y (loop [j 0] (if (< j 1) (recur (inc j)) p)))
             (inc i))
      (get p :x))))"
              :sr t)
    (declare (ignore val))
    (is (not (sr-code-has code "P_X")))))

;;; ============================================================================
;;; Assoc-style updates hidden behind a user-defined macro. Matches the
;;; shape found in datascript's real corpus code (the pull-pattern parser
;;; rebuilds its record via ASSOC inside util/cond+, a project-local
;;; branching macro, not IF/COND/CASE directly).
;;;
;;; This turned out not to be an ASR gap at all: user DEFMACRO forms were
;;; never wired into FOL's own parser-level macro table (PARSE-COMPOUND's
;;; MACRO-P check only ever saw the fixed set of built-in macros macros.lisp
;;; registers, like COND-> and WHEN), so a user macro's call survived as an
;;; opaque, unrecognized call-node all the way to emission -- invisible not
;;; just to ASR but to every AST-level pass. A second, deeper issue sat
;;; behind that: even once registered, a macro expander built with FOL's
;;; own LIST/CONS produces a persistent <LIST> object (FOL's LIST shadows
;;; CL:LIST the same way every other collection constructor does), which
;;; PARSE-FORM's literal-collection cases didn't recognize either, so
;;; expansion still failed with "Cannot parse form." Both are now fixed in
;;; EMIT-DEFMACRO/PARSE-COMPOUND (%DELISTIFY), which is why these tests
;;; live here instead of duplicating a third, ASR-specific fix.
;;; ============================================================================

(test sr-macro-wrapped-assoc-simple-correctness
  "An ASSOC reconstruction wrapped in a trivial user macro (no branching)
   is still recognized once the macro is expanded; the optimized result
   matches the unoptimized one."
  (let ((src "
(defmacro sr-mw-id [x] x)
(defclass <sr-mw> [] [[x] [y]])
(defn sr-mw-run [n]
  (loop [p (make-<sr-mw> :x 0.0 :y 0.0) i 0]
    (if (< i n)
      (recur (sr-mw-id (assoc p :x (+ (get p :x) 1.0) :y (+ (get p :y) 0.5)))
             (inc i))
      (+ (get p :x) (get p :y)))))
(sr-mw-run 3)"))
    (is (= 4.5 (sr-fol src :sr nil)))
    (is (= (sr-fol src :sr nil) (sr-fol src :sr t)))))

(test sr-macro-wrapped-branching-assoc-correctness
  "The datascript shape: a record accumulator rebuilt by ASSOC inside a
   user-defined, project-local branching macro (a cond+ analogue) rather
   than IF/COND/CASE written directly. Once the macro is expanded during
   parsing, the underlying IF-tree is visible to the pass exactly as if
   the user had written it by hand; the optimized result matches the
   unoptimized one across all three branches actually firing."
  (let ((src "
(defmacro sr-mw2-cond+ [t1 b1 t2 b2 eb]
  (list 'if t1 b1 (list 'if t2 b2 eb)))
(defclass <sr-mw2> [] [[x] [y]])
(defn sr-mw2-run [n]
  (loop [p (make-<sr-mw2> :x 0.0 :y 0.0) i 0]
    (if (< i n)
      (recur (sr-mw2-cond+ (> (get p :x) 10.0)
                            (assoc p :x 0.0)
                            (> (get p :x) 5.0)
                            (assoc p :x (+ (get p :x) 2.0) :y (+ (get p :y) 1.0))
                            (assoc p :x (+ (get p :x) 1.0) :y (+ (get p :y) 0.5)))
             (inc i))
      (+ (get p :x) (get p :y)))))
(sr-mw2-run 8)"))
    ;; Hand-traced: else-branch fires while x<=5 (six steps), then the
    ;; middle branch fires twice more before i reaches 8. Final (10.0, 5.0).
    (is (= 15.0 (sr-fol src :sr nil)))
    (is (= (sr-fol src :sr nil) (sr-fol src :sr t)))))

(test sr-macro-wrapped-branching-assoc-applies
  "With SR on, the macro-hidden branching ASSOC reconstruction still
   unboxes the accumulator into P_X/P_Y scalar loop vars, world-guarded
   as usual."
  (multiple-value-bind (val code)
      (sr-fol "
(defmacro sr-mw3-cond+ [t1 b1 t2 b2 eb]
  (list 'if t1 b1 (list 'if t2 b2 eb)))
(defclass <sr-mw3> [] [[x] [y]])
(defn sr-mw3-run [n]
  (loop [p (make-<sr-mw3> :x 0.0 :y 0.0) i 0]
    (if (< i n)
      (recur (sr-mw3-cond+ (> (get p :x) 10.0)
                            (assoc p :x 0.0)
                            (> (get p :x) 5.0)
                            (assoc p :x (+ (get p :x) 2.0) :y (+ (get p :y) 1.0))
                            (assoc p :x (+ (get p :x) 1.0) :y (+ (get p :y) 0.5)))
             (inc i))
      (+ (get p :x) (get p :y)))))"
              :sr t)
    (declare (ignore val))
    (is (sr-code-has code "P_X"))
    (is (sr-code-has code "P_Y"))
    (is (sr-code-has code "REGISTER-REGION"))
    (is (sr-code-has code "<SR-MW3>"))
    ;; The macro call itself no longer survives -- it was expanded before
    ;; this pass ever ran, exactly like a hand-written IF would be.
    (is (not (sr-code-has code "SR-MW3-COND+")))))

;;; ============================================================================
;;; Intra-bind scalar replacement (a single object created and consumed
;;; entirely within one BIND scope, not a loop accumulator). No dedicated
;;; coverage existed for this pass before; added alongside the fix below.
;;; ============================================================================

(test sr-intra-bind-basic-correctness
  "A record created and read within a single BIND scope is unboxed; the
   result matches the unoptimized run (the pass's original, simplest shape)."
  (let ((src "
(defclass <sr-ia> [] [[x] [y]])
(defn sr-ia-run [n]
  (bind [p (make-<sr-ia> :x n :y (* n 2))]
    (+ (get p :x) (get p :y))))
(sr-ia-run 5)"))
    (is (= 15 (sr-fol src :sr nil)))
    (is (= (sr-fol src :sr nil) (sr-fol src :sr t)))))

(test sr-intra-bind-multi-step-chain-correctness
  "A multi-step ASSOC chain within one BIND scope (base -> m1 -> m2 -> m3,
   each ASSOC'ing one field) is fully threaded through and re-boxed at the
   tail; regression coverage for the chain-scoping fix (an earlier version
   of %SR-INTRA-BIND-CHAIN only ever inspected the trailing body for
   escapes, silently leaving a later binding's ASSOC on the already-unboxed
   accumulator unrewritten -- a miscompilation, not merely a missed
   optimization)."
  (let ((src "
(defclass <sr-ib> [] [[a] [b] [c]])
(defn sr-ib-run [x]
  (bind [base (make-<sr-ib> :a 0 :b 0 :c 0)
         m1 (assoc base :a (+ x 1))
         m2 (assoc m1 :b (+ x 2))
         m3 (assoc m2 :c (+ x 3))]
    (+ (get m3 :a) (+ (get m3 :b) (get m3 :c)))))
(sr-ib-run 10)"))
    (is (= 36 (sr-fol src :sr nil)))
    (is (= (sr-fol src :sr nil) (sr-fol src :sr t)))))

(test sr-intra-bind-nested-literal-declines-safely
  "A tracked alias read inside a VECTOR literal at tail position -- a node
   type REMAKE-NODE-WITH-CHILDREN has no reconstruction method for -- must
   decline (SR-on == SR-off) rather than emit code referencing a binding
   that scalar replacement already dropped. Regression test for the
   generic-recursion trap in %SR-INTRA-BIND-CHAIN's RW fallback: blindly
   calling REMAKE-NODE-WITH-CHILDREN on an unrecognized node type silently
   discarded rewritten children for VECTOR-NODE/DICT-NODE/SET-NODE (no
   reconstruction method exists for them), leaving a dangling reference to
   an already-dropped binding -- reproduced as an UNBOUND-VARIABLE error
   before the fix; must now simply not fire on this shape."
  (let ((src "
(defclass <sr-ic> [] [[a] [b]])
(defn sr-ic-run [x y]
  (bind [p (make-<sr-ic> :a x :b y)
         q (assoc p :a (+ x 1))]
    [(get q :a) (get q :b)]))
(sr-ic-run 10 20)"))
    (is (equal (fol.compiler.collections:collection-seq (sr-fol src :sr nil))
               (fol.compiler.collections:collection-seq (sr-fol src :sr t))))))

(test sr-intra-bind-world-guard-invalidation
  "The intra-bind fast path registers a world region keyed on the record
   class name, mirroring the loop path's guard; redefining the class
   invalidates it and the next call takes the original path, still correct."
  (fol.compiler.world:reset-world)
  (let ((defs "
(defclass <sr-id> [] [[x] [y]])
(defn sr-id-run [n]
  (bind [p (make-<sr-id> :x n :y (* n 2))
         q (assoc p :x (inc (get p :x)))]
    (get q :x)))"))
    (sr-fol defs :sr t)
    (is (= 1 (getf (fol.compiler.world:world-stats) :regions-registered)))
    (is (= 0 (getf (fol.compiler.world:world-stats) :regions-invalidated)))
    (is (= 6 (sr-fol "(sr-id-run 5)" :sr t)))
    (sr-fol "(defclass <sr-id> [] [[x] [y] [z]])" :sr t)
    (is (= 1 (getf (fol.compiler.world:world-stats) :regions-invalidated)))
    (is (= 6 (sr-fol "(sr-id-run 5)" :sr t)))))

;;; ============================================================================
;;; Dict-mode intra-bind scalar replacement (*DICT-SCALAR-REPLACEMENT*): the
;;; accumulator is a literal empty dict {} rather than a defclass record; its
;;; fixed key set is discovered from usage (every touch must be a literal-
;;; keyword GET/ASSOC) instead of a pre-registered *GLOBAL-TYPE-INFO* schema.
;;; v1 scope: intra-bind chains only, flat ASSOC-chain reconstruction only (no
;;; if/cond/case, no helper inlining, no dissoc/update/merge).
;;; ============================================================================

(defvar *dict-sr-hijack-sentinel* 0)

(defun dict-collection-alist (v)
  "Sorted (key . value) alist for a FOL dict, for order-independent equality
   (a HAMT's iteration order is not guaranteed stable across two separately-
   built instances with the same entries)."
  (sort (copy-list (fol.compiler.collections:collection-seq v))
        #'string< :key (lambda (kv) (symbol-name (car kv)))))

(test dict-sr-basic-correctness
  "A dict accumulator built via a straight-line ASSOC chain (3 keys) yields
   identical results whether or not it is dict-scalar-replaced."
  (let ((src "
(defn dict-sr-a-run [x y z]
  (bind [base {}
         m1 (assoc base :a x)
         m2 (assoc m1 :b y)
         m3 (assoc m2 :c z)]
    m3))
(dict-sr-a-run 1 2 3)"))
    (is (equal (dict-collection-alist (dict-sr-fol src :dict-sr nil))
               (dict-collection-alist (dict-sr-fol src :dict-sr t))))))

(test dict-sr-applies
  "With dict-SR on, the accumulator is split into BASE_A/BASE_B scalar
   bindings and the fast path is world-guarded. (The overall dual-path code
   still contains ASSOC -- the fallback branch is the original, unoptimized
   code verbatim; only the fast-path branch is checked for scalar vars.)"
  (multiple-value-bind (val code)
      (dict-sr-fol "
(defn dict-sr-b-run [x y]
  (bind [base {}
         m1 (assoc base :a x)
         m2 (assoc m1 :b y)]
    m2))"
                    :dict-sr t)
    (declare (ignore val))
    (is (sr-code-has code "BASE_A"))
    (is (sr-code-has code "BASE_B"))
    (is (sr-code-has code "REGISTER-REGION"))))

(test dict-sr-repeated-key-correctness
  "Re-ASSOC'ing the same key later in the chain overwrites correctly (the
   final scalar binding shadows the earlier one for that key)."
  (let ((src "
(defn dict-sr-c-run [x]
  (bind [base {}
         m1 (assoc base :a x)
         m2 (assoc m1 :a (+ x 1))]
    (get m2 :a)))
(dict-sr-c-run 10)"))
    (is (= 11 (dict-sr-fol src :dict-sr nil)))
    (is (= (dict-sr-fol src :dict-sr nil) (dict-sr-fol src :dict-sr t)))))

(test dict-sr-zero-assoc-declines
  "A dict accumulator with no ASSOC at all discovers no fields and declines
   (no benefit to scalarizing); still correct, and not world-guarded."
  (multiple-value-bind (val code)
      (dict-sr-fol "(defn dict-sr-d-run [x] (bind [p {}] p)) (dict-sr-d-run 1)"
                    :dict-sr t)
    (declare (ignore val))
    (is (not (sr-code-has code "REGISTER-REGION")))))

(test dict-sr-dynamic-key-declines-safely
  "A dynamic (non-literal-keyword) ASSOC key cannot be discovered statically;
   the chain must abort and fall back to the original, still-correct code."
  (let ((src "
(defn dict-sr-e-run [k v]
  (bind [p {}
         q (assoc p k v)]
    q))"))
    (is (equal (dict-collection-alist (dict-sr-fol (concatenate 'string src " (dict-sr-e-run :x 42)") :dict-sr nil))
               (dict-collection-alist (dict-sr-fol (concatenate 'string src " (dict-sr-e-run :x 42)") :dict-sr t))))))

(test dict-sr-non-assoc-op-declines-safely
  "DISSOC (or any op other than literal-keyword GET/ASSOC) on the tracked
   alias is outside v1's recognized shapes and must abort safely, not crash
   or miscompile."
  (let ((src "
(defn dict-sr-f-run [x]
  (bind [p {}
         q (assoc p :a x)
         r (dissoc q :a)]
    r))
(dict-sr-f-run 10)"))
    (is (equal (dict-collection-alist (dict-sr-fol src :dict-sr nil))
               (dict-collection-alist (dict-sr-fol src :dict-sr t))))))

(test dict-sr-independent-of-scalar-replacement-flag
  "*DICT-SCALAR-REPLACEMENT* fires with *SCALAR-REPLACEMENT* off (DICT-SR-FOL
   always binds it NIL): the two mechanisms are independently ablatable."
  (multiple-value-bind (val code)
      (dict-sr-fol "
(defn dict-sr-g-run [x] (bind [base {} m1 (assoc base :a x)] m1))"
                    :dict-sr t)
    (declare (ignore val))
    (is (sr-code-has code "REGISTER-REGION"))))

(test dict-sr-world-guard-invalidation
  "The dict fast path registers a world region keyed on the Tier-1 op names
   used (not a class name -- a dict has no class to redefine); redefining
   GET/ASSOC invalidates it via the ordinary NOTE-REDEFINITION path and the
   next call falls back, still correct."
  (fol.compiler.world:reset-world)
  (let ((defs "
(defn dict-sr-h-run [x]
  (bind [base {}
         m1 (assoc base :a x)]
    (get m1 :a)))"))
    (dict-sr-fol defs :dict-sr t)
    (is (= 1 (getf (fol.compiler.world:world-stats) :regions-registered)))
    (is (= 0 (getf (fol.compiler.world:world-stats) :regions-invalidated)))
    (is (= 5 (dict-sr-fol "(dict-sr-h-run 5)" :dict-sr t)))
    ;; Redefining ASSOC on <dict> -- through FOL's own compiler, not a raw
    ;; CL EVAL, so COMPILE-FORM's own DEFMETHOD-NODE redefinition tracking
    ;; is what's under test here (an out-of-band CL-level hijack is a
    ;; different threat, covered by DICT-SR-LOAD-TIME-HIJACK-AFTER-COMPILE-
    ;; CLOSES-GAP below, not by NOTE-REDEFINITION at all) -- must invalidate
    ;; the region via NOTE-REDEFINITION, same as any other Tier-1 op
    ;; redefinition. This exercises COMPILE-FORM's REDEF-NAME gate, which
    ;; used to fire only when *TRANSIENT-LOOPS* was also on -- a real gap
    ;; for a *DICT-SCALAR-REPLACEMENT*-only build, fixed alongside this test.
    (unwind-protect
        (progn
          (dict-sr-fol "(defmethod fol.compiler.collection-functions:assoc :around
                          [(d fol.compiler.collections:<dict>) k v]
                          (call-next-method))"
                       :dict-sr t)
          (is (= 1 (getf (fol.compiler.world:world-stats) :regions-invalidated)))
          (is (= 5 (dict-sr-fol "(dict-sr-h-run 5)" :dict-sr t))))
      (let ((m (find-method #'fol.compiler.collection-functions:assoc '(:around)
                             (list (find-class 'fol.compiler.collections:<dict>) t t)
                             nil)))
        (when m (remove-method #'fol.compiler.collection-functions:assoc m))))))

(test dict-sr-load-time-hijack-after-compile-closes-gap
  "The compile-to-load-time gap %REGISTER-REGION-TRUSTED-FORM/%KIND-TRUSTED-P
   close for the loop/reduce paths (see test-transient-conversion.lisp's
   TRANSIENT-LOOP-LOAD-TIME-HIJACK-AFTER-COMPILE-CLOSES-GAP) applies equally
   to this intra-bind dict path, now that it is wired through the same
   %REGISTER-REGION-TRUSTED-FORM helper: a hijack installed strictly between
   compiling a qualifying chain and evaluating it is invisible to a
   compile-time-only check, but %KIND-TRUSTED-P re-verifies live at load
   time. First the positive case (no hijack, sentinel stays silent), then
   the gap-closing case on a freshly-compiled instance of the identical
   chain (hijack strictly between compile and load; sentinel must fire).

   Uses a bare BIND expression, not a DEFN: evaluating an
   `(if guard (defun f () :fast) (defun f () :fallback))` form only
   *defines* F under whichever name the guard selected -- it never *calls*
   F, so a sentinel inside F's body can never fire regardless of which
   branch was chosen, no matter how the guard behaves. A bare BIND
   expression's dual-path IF runs immediately when EVAL'd (mirroring the
   loop-path test's own bare LOOP-form choice for the identical reason)."
  (let ((src "(bind [p {} q (assoc p :a 5)] q)"))
    ;; Positive case: no hijack.
    (setf *dict-sr-hijack-sentinel* 0)
    (let ((fol.compiler.escape-analysis:*dict-scalar-replacement* t)
          (*readtable* fol.compiler.reader:*fol-readtable*)
          (*package* (find-package :fol.core)))
      (let ((result (fol.compiler:compile-form (read-from-string src))))
        (eval (fol.compiler:compilation-result-code result))
        (is (= 0 *dict-sr-hijack-sentinel*))))
    ;; Gap-closing case: hijack ASSOC on <dict>, strictly after compiling a
    ;; FRESH instance of the same chain but before evaluating it.
    (setf *dict-sr-hijack-sentinel* 0)
    (let ((fol.compiler.escape-analysis:*dict-scalar-replacement* t)
          (*readtable* fol.compiler.reader:*fol-readtable*)
          (*package* (find-package :fol.core)))
      (let ((result (fol.compiler:compile-form (read-from-string src))))
        (eval '(defmethod fol.compiler.collection-functions:assoc :around
                   ((d fol.compiler.collections:<dict>) k v &rest kvs)
                 (declare (ignore kvs))
                 (incf *dict-sr-hijack-sentinel*)
                 (call-next-method)))
        (unwind-protect
            (progn
              (eval (fol.compiler:compilation-result-code result))
              (is (> *dict-sr-hijack-sentinel* 0)))
          (let ((m (find-method #'fol.compiler.collection-functions:assoc '(:around)
                                 (list (find-class 'fol.compiler.collections:<dict>) t t)
                                 nil)))
            (when m (remove-method #'fol.compiler.collection-functions:assoc m))))))))
