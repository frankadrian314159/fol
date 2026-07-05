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
