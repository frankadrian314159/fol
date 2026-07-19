;;; FOL Compiler Tests - Reduce-over-literal-collection unrolling
;;;
;;; Correctness and application tests for *REDUCE-LITERAL-UNROLL*
;;; (compiler.lisp, REDUCE-LITERAL-DESUGAR-TOPLEVEL / %DESUGAR-REDUCE-LITERAL).
;;; A (reduce (fn [acc x] body) init coll) call where COLL is a literal
;;; vector/set -- inline, or referenced by a top-level DEF -- is unrolled at
;;; compile time into an ordinary straight-line BIND chain, so downstream
;;; passes (scalar replacement in particular) see it exactly as if the user
;;; had written the unrolled form by hand.
;;;
;;; Forms are read with the FOL readtable in :fol.core, matching
;;; test-scalar-replacement.lisp's convention. Each test uses a distinct
;;; def/defn name so registration/world-guard state in one test cannot
;;; disturb another.

(in-package :fol.compiler.tests)

(def-suite reduce-literal-unroll-suite
  :description "Reduce-over-literal-collection compile-time unrolling"
  :in compiler-tests)

(in-suite reduce-literal-unroll-suite)

(defun ru-fol (source &key (unroll t) sr)
  "Read FOL SOURCE (one or more forms) with the FOL readtable in :fol.core,
   compile each form with *REDUCE-LITERAL-UNROLL* per UNROLL and
   *SCALAR-REPLACEMENT* per SR, and evaluate it. Returns (values LAST-VALUE
   LAST-FORM-CODE)."
  (let ((fol.compiler.escape-analysis:*reduce-literal-unroll* unroll)
        (fol.compiler.escape-analysis:*scalar-replacement* sr)
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

(defun ru-code-has (code substring)
  "True when the printed representation of CODE contains SUBSTRING."
  (and (search substring (write-to-string code)) t))

;;; ============================================================================
;;; Correctness: unrolled result matches the ordinary (un-unrolled) reduce
;;; ============================================================================

(test reduce-literal-unroll-inline-vector-correctness
  "A reduce over a literal vector written inline at the call site unrolls
   and matches the un-unrolled result."
  (let ((src "
(defn ru-a-run []
  (reduce (fn [acc x] (+ acc x)) 0 [1 2 3 4 5]))
(ru-a-run)"))
    (is (= 15 (ru-fol src :unroll nil)))
    (is (= (ru-fol src :unroll nil) (ru-fol src :unroll t)))))

(test reduce-literal-unroll-def-set-correctness
  "A reduce over a literal SET referenced by name (the reitit shape: a
   top-level DEF used later as the reduce's coll argument) unrolls and
   matches the un-unrolled result."
  (let ((src "
(def ru-b-methods #{1 2 3 4})
(defn ru-b-run []
  (reduce (fn [acc x] (+ acc x)) 0 ru-b-methods))
(ru-b-run)"))
    (is (= 10 (ru-fol src :unroll nil)))
    (is (= (ru-fol src :unroll nil) (ru-fol src :unroll t)))))

(test reduce-literal-unroll-empty-collection-returns-init
  "A reduce over a literal empty vector returns init unchanged, whether or
   not unrolling is enabled."
  (let ((src "
(defn ru-f-run []
  (reduce (fn [acc x] (+ acc x)) 42 []))
(ru-f-run)"))
    (is (= 42 (ru-fol src :unroll nil)))
    (is (= 42 (ru-fol src :unroll t)))))

;;; ============================================================================
;;; Application: unrolling actually replaces the REDUCE call with a BIND chain
;;; ============================================================================

(test reduce-literal-unroll-applies
  "With the flag on, the reduce call over a literal vector no longer
   appears in the emitted code (it has been unrolled into a BIND chain)."
  (multiple-value-bind (val code)
      (ru-fol "
(defn ru-g-run []
  (reduce (fn [acc x] (+ acc x)) 0 [1 2 3 4 5]))"
              :unroll t)
    (declare (ignore val))
    (is (not (ru-code-has code "REDUCE")))))

(test reduce-literal-unroll-inert-when-flag-off
  "With the flag off, the reduce call is left completely alone: the
   emitted code still calls reduce, and the result is unaffected."
  (let ((defn-src "
(defn ru-h-run []
  (reduce (fn [acc x] (+ acc x)) 0 [1 2 3 4 5]))"))
    (multiple-value-bind (val code) (ru-fol defn-src :unroll nil)
      (declare (ignore val))
      (is (ru-code-has code "REDUCE")))
    (is (= 15 (ru-fol (concatenate 'string defn-src "
(ru-h-run)") :unroll nil)))))

;;; ============================================================================
;;; The motivating case: unrolling exposes a record accumulator to ASR
;;; ============================================================================

(test reduce-literal-unroll-exposes-record-accumulator-to-sr
  "The reitit shape: a record accumulator threaded through ASSOC once per
   element of a literal collection, via reduce rather than loop/recur.
   Reduce must be the function's own tail expression (v1's scope: tail
   position through bind/do peeling only, matching %SR-PEEL-CORE -- see
   reduce-literal-unroll-dynamic-collection-declines-safely's sibling
   scope-boundary tests below for the non-tail case). With unrolling (and
   scalar replacement) on, the result is correct and the reduce call
   itself no longer survives in the emitted code."
  (let ((src "
(defclass <ru-pt> [] [[x] [y]])
(def ru-c-deltas [1 2 3])
(defn ru-c-run []
  (reduce (fn [acc d] (assoc acc :x (+ (get acc :x) d)))
          (make-<ru-pt> :x 0 :y 0)
          ru-c-deltas))
(get (ru-c-run) :x)"))
    (is (= 6 (ru-fol src :unroll nil :sr nil)))
    (is (= 6 (ru-fol src :unroll t :sr nil)))
    (is (= 6 (ru-fol src :unroll t :sr t))))
  (multiple-value-bind (val code)
      (ru-fol "
(defclass <ru-pt2> [] [[x] [y]])
(def ru-c2-deltas [1 2 3])
(defn ru-c2-run []
  (reduce (fn [acc d] (assoc acc :x (+ (get acc :x) d)))
          (make-<ru-pt2> :x 0 :y 0)
          ru-c2-deltas))"
              :unroll t :sr t)
    (declare (ignore val))
    (is (not (ru-code-has code "REDUCE")))))

;;; ============================================================================
;;; Conservatism: shapes outside v1's scope are left untouched, not crashed
;;; ============================================================================

(test reduce-literal-unroll-dynamic-collection-declines-safely
  "A reduce over a non-literal (parameter-bound) collection is outside
   scope -- COLL isn't a literal or a registered DEF -- and must decline
   safely: the reduce call survives in the emitted code, and the result is
   still correct."
  (let ((defn-src "
(defn ru-d-run [xs]
  (reduce (fn [acc x] (+ acc x)) 0 xs))"))
    (multiple-value-bind (val code) (ru-fol defn-src :unroll t)
      (declare (ignore val))
      (is (ru-code-has code "REDUCE")))
    (is (= 6 (ru-fol (concatenate 'string defn-src "
(ru-d-run [1 2 3])") :unroll t)))))

(test reduce-literal-unroll-named-fn-declines-safely
  "A reduce whose step function is a named reference rather than an inline
   FN literal is outside scope and must decline safely."
  (let ((defn-src "
(def ru-e-nums [1 2 3])
(defn ru-e-run []
  (reduce + 0 ru-e-nums))"))
    (multiple-value-bind (val code) (ru-fol defn-src :unroll t)
      (declare (ignore val))
      (is (ru-code-has code "REDUCE")))
    (is (= 6 (ru-fol (concatenate 'string defn-src "
(ru-e-run)") :unroll t)))))
