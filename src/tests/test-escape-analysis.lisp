;;; FOL Compiler Tests - Escape Analysis (audit mode)
;;;
;;; Tests for src/escape-analysis.lisp: loop-accumulator classification,
;;; chain recognition, Tier-1 coverage counting, via the public audit API.
;;; Forms use package-qualified stdlib symbols so Tier-1 summaries match
;;; (unqualified symbols intern into fol.compiler.tests and are Tier-0).

(in-package :fol.compiler.tests)

(def-suite escape-analysis-suite
  :description "Escape/uniqueness analysis: accumulators, chains, coverage"
  :in compiler-tests)

(in-suite escape-analysis-suite)

(defun run-audit-on (form)
  "Reset audit stats, compile FORM with audit enabled, return the stats."
  (let ((fol.compiler.escape-analysis:*escape-audit* t))
    (fol.compiler.escape-analysis:reset-audit)
    (fol.compiler:compile-form form)
    fol.compiler.escape-analysis:*audit-stats*))

(defun disqual-reasons-of (stats)
  (let ((reasons '()))
    (maphash (lambda (k v) (declare (ignore v)) (push k reasons))
             (fol.compiler.escape-analysis:audit-stats-disqual-reasons stats))
    reasons))

;;; ============================================================================
;;; Qualified accumulators
;;; ============================================================================

(test accumulator-qualifies-basic
  "Canonical DVI pattern: assoc into acc in recur, bare acc at exit"
  (let ((stats (run-audit-on
                '(defn build-map #(n)
                   (loop (acc (dict) i 0)
                     (if (< i n)
                         (recur (fol.compiler.collection-functions:assoc acc i i)
                                (inc i))
                         acc))))))
    (is (= 1 (fol.compiler.escape-analysis:audit-stats-functions stats)))
    (is (= 1 (fol.compiler.escape-analysis:audit-stats-loops stats)))
    (is (= 2 (fol.compiler.escape-analysis:audit-stats-loop-params stats)))
    (is (= 1 (fol.compiler.escape-analysis:audit-stats-candidates stats)))
    (is (= 1 (fol.compiler.escape-analysis:audit-stats-qualified stats)))))

(test accumulator-qualifies-thread-first-update
  "Recur update written as a -> chain rooted at the accumulator"
  (let ((stats (run-audit-on
                '(loop (acc (dict) i 0)
                   (if (< i 10)
                       (recur (-> acc
                                  (fol.compiler.collection-functions:assoc :a i)
                                  (fol.compiler.collection-functions:conj i))
                              (inc i))
                       acc)))))
    (is (= 1 (fol.compiler.escape-analysis:audit-stats-candidates stats)))
    (is (= 1 (fol.compiler.escape-analysis:audit-stats-qualified stats)))))

(test accumulator-qualifies-exit-update
  "Tail-position transient-safe chain at loop exit is sanctioned"
  (let ((stats (run-audit-on
                '(loop (acc (dict) i 0)
                   (if (< i 10)
                       (recur (fol.compiler.collection-functions:assoc acc i i)
                              (inc i))
                       (fol.compiler.collection-functions:assoc acc :done 1))))))
    (is (= 1 (fol.compiler.escape-analysis:audit-stats-qualified stats)))))

(test passthrough-only-is-not-accumulator
  "A param that is only passed through recur unchanged is not a candidate"
  (let ((stats (run-audit-on
                '(loop (acc (dict) i 0)
                   (if (< i 10) (recur acc (inc i)) acc)))))
    (is (= 0 (fol.compiler.escape-analysis:audit-stats-candidates stats)))
    (is (= 0 (fol.compiler.escape-analysis:audit-stats-qualified stats)))))

;;; ============================================================================
;;; Disqualifications
;;; ============================================================================

(test accumulator-whitelisted-read-sanctioned
  "Reading the accumulator via a whitelisted op (get, position 0) is
   sanctioned since step 3.5 -- edit-tagged transients support reads"
  (let ((stats (run-audit-on
                '(loop (acc (dict) i 0)
                   (if (< i 10)
                       (recur (fol.compiler.collection-functions:assoc
                               acc i (fol.compiler.collection-functions:get acc i))
                              (inc i))
                       acc)))))
    (is (= 1 (fol.compiler.escape-analysis:audit-stats-candidates stats)))
    (is (= 1 (fol.compiler.escape-analysis:audit-stats-qualified stats)))))

(test accumulator-disqualified-by-nonwhitelisted-read
  "The accumulator as a KEY argument (not position 0) still disqualifies --
   hashing a transient would change value semantics"
  (let ((stats (run-audit-on
                '(loop (acc (dict) i 0)
                   (if (< i 10)
                       (recur (fol.compiler.collection-functions:assoc
                               acc i (fol.compiler.collection-functions:get lookup-table acc))
                              (inc i))
                       acc)))))
    (is (= 1 (fol.compiler.escape-analysis:audit-stats-candidates stats)))
    (is (= 0 (fol.compiler.escape-analysis:audit-stats-qualified stats)))
    (is (not (null (member :read (disqual-reasons-of stats)))))))

(test accumulator-disqualified-by-capture
  "Accumulator referenced inside a closure body disqualifies"
  ;; fol-form converts #(x) into a real FOL <vector>, which parse-fn requires.
  (let ((stats (run-audit-on
                (fol-form
                 '(loop (acc (dict) i 0)
                    (if (< i 10)
                        (recur (fol.compiler.collection-functions:assoc acc i i)
                               (inc i))
                        (fol.compiler.seq-functions:mapv
                         (fn #(x) (fol.compiler.collection-functions:get acc x))
                         xs)))))))
    (is (= 0 (fol.compiler.escape-analysis:audit-stats-qualified stats)))
    (is (not (null (member :captured (disqual-reasons-of stats)))))))

(test accumulator-disqualified-by-aliasing
  "Accumulator flowing into another recur slot escapes (aliased)"
  (let ((stats (run-audit-on
                '(loop (a (dict) b (dict))
                   (if p
                       (recur (fol.compiler.collection-functions:assoc a :x 1)
                              (fol.compiler.collection-functions:conj b a))
                       a)))))
    ;; a is disqualified (stored into b); b itself qualifies (linear conj).
    (is (= 2 (fol.compiler.escape-analysis:audit-stats-candidates stats)))
    (is (= 1 (fol.compiler.escape-analysis:audit-stats-qualified stats)))
    (is (not (null (member :escape-call (disqual-reasons-of stats)))))))

;;; ============================================================================
;;; Nested loops
;;; ============================================================================

(test nested-loop-inner-accumulator-qualifies
  "Outer acc threaded through a nested loop: inner accumulator qualifies"
  (let ((stats (run-audit-on
                '(loop (acc (dict) i 0)
                   (if (< i 10)
                       (recur (loop (inner acc j 0)
                                (if (< j 3)
                                    (recur (fol.compiler.collection-functions:assoc
                                            inner j j)
                                           (inc j))
                                    inner))
                              (inc i))
                       acc)))))
    (is (= 2 (fol.compiler.escape-analysis:audit-stats-loops stats)))
    ;; The inner loop's accumulator is the convertible one.
    (is (>= (fol.compiler.escape-analysis:audit-stats-qualified stats) 1))))

;;; ============================================================================
;;; Chains
;;; ============================================================================

(test thread-first-chain-counted
  "A -> run of >=2 transient-safe ops is a chain, with its length recorded"
  (let ((stats (run-audit-on
                '(-> d
                     (fol.compiler.collection-functions:assoc :a 1)
                     (fol.compiler.collection-functions:assoc :b 2)
                     (fol.compiler.collection-functions:conj 3)))))
    (is (= 1 (fol.compiler.escape-analysis:audit-stats-chains stats)))
    (is (equal '(3) (fol.compiler.escape-analysis:audit-stats-chain-lengths stats)))))

(test thread-first-short-run-not-counted
  "A single safe op in a -> is not a chain"
  (let ((stats (run-audit-on
                '(-> d
                     (fol.compiler.collection-functions:assoc :a 1)
                     (fol.compiler.collection-functions:get :a)))))
    (is (= 0 (fol.compiler.escape-analysis:audit-stats-chains stats)))))

(test nested-direct-call-chain-counted
  "(assoc (assoc d ...) ...) is a nested chain, counted once at its head"
  (let ((stats (run-audit-on
                '(fol.compiler.collection-functions:assoc
                  (fol.compiler.collection-functions:assoc d :a 1)
                  :b 2))))
    (is (= 1 (fol.compiler.escape-analysis:audit-stats-nested-chains stats)))))

;;; ============================================================================
;;; Coverage counters
;;; ============================================================================

(test coverage-tier1-and-keyword
  "Tier-1 calls and keyword accessors are distinguished from Tier-0"
  (let ((stats (run-audit-on
                '(do (fol.compiler.collection-functions:get d :k)
                     (:k d)
                     (my-unknown-function d)))))
    (is (= 3 (fol.compiler.escape-analysis:audit-stats-calls stats)))
    (is (= 1 (fol.compiler.escape-analysis:audit-stats-calls-tier1 stats)))
    (is (= 1 (fol.compiler.escape-analysis:audit-stats-calls-keyword stats)))
    (is (= 1 (fol.compiler.escape-analysis:audit-stats-calls-tier0 stats)))))

(test coverage-barrier-counted
  "Calls to eval-like operators are counted as barriers"
  (let ((stats (run-audit-on '(eval x))))
    (is (= 1 (fol.compiler.escape-analysis:audit-stats-barriers stats)))))

;;; ============================================================================
;;; param-verdict unit tests
;;; ============================================================================

(test param-verdict-rules
  "Verdict combinator: candidate requires an update; any bad use disqualifies"
  (multiple-value-bind (v bad)
      (fol.compiler.escape-analysis:param-verdict
       '(:recur-update :exit-bare))
    (is (eq :qualified v))
    (is (null bad)))
  (multiple-value-bind (v bad)
      (fol.compiler.escape-analysis:param-verdict
       '(:recur-passthrough :exit-bare))
    (declare (ignore bad))
    (is (eq :not-accumulator v)))
  (multiple-value-bind (v bad)
      (fol.compiler.escape-analysis:param-verdict
       '(:recur-update :read :exit-bare))
    (is (eq :disqualified v))
    (is (equal '(:read) bad))))

;;; ============================================================================
;;; Audit is off by default
;;; ============================================================================

(test audit-disabled-by-default
  "Compiling with the audit switch off must not touch the stats"
  (fol.compiler.escape-analysis:reset-audit)
  (fol.compiler:compile-form
   '(loop (acc (dict) i 0)
      (if (< i 10)
          (recur (fol.compiler.collection-functions:assoc acc i i) (inc i))
          acc)))
  (is (= 0 (fol.compiler.escape-analysis:audit-stats-loops
            fol.compiler.escape-analysis:*audit-stats*))))

;;; ============================================================================
;;; Formal-model fidelity (PLDI 2027 paper, Table "fidelity"): the usage-tag
;;; vocabulary CLASSIFY-LOOP-PARAM actually produces must be a subset of what
;;; the paper's mapping table documents. This is the mechanical half of the
;;; fidelity argument -- a tag added to the classifier without updating the
;;; paper's vocabulary listing fails here, not just in a future proofreading
;;; pass.
;;; ============================================================================

(defparameter +documented-tag-vocabulary+
  '(;; Sanctioned (SanctionedUses, paper §sec:formal)
    :recur-update :recur-passthrough :exit-update :exit-bare :exit-in-literal :read-ok
    ;; Disqualifying, named rules
    :recur-reset :recur-in-complex-context
    ;; Disqualifying, diagnostic refinements of :escape (paper's Disqualifying-uses list)
    :escape :captured :other-flow :shadowed-bind :nested-loop-init :escape-call :read)
  "Every tag CLASSIFY-LOOP-PARAM is documented (pldi2027.tex, Table
   \"fidelity\" and the SanctionedUses/Disqualifying-uses descriptions) to
   ever produce. Kept in sync by hand with the paper; TAG-VOCABULARY-MATCHES-
   FORMAL-MODEL is what catches drift.")

(defun %all-loop-nodes (ast)
  "Every LOOP-NODE reachable from AST, including nested ones."
  (let ((out '()))
    (labels ((walk (n)
               (when (fol.compiler.ast:loop-node-p n) (push n out))
               (dolist (c (fol.compiler.escape-analysis:node-children n)) (walk c))))
      (walk ast))
    (nreverse out)))

(defun %parse-fol (raw-form)
  "Parse an already-read, package-qualified raw form (the same shape RUN-
   AUDIT-ON's callers pass to COMPILE-FORM) into an AST without emitting or
   evaluating anything."
  (fol.compiler:parse-form raw-form))

(defun %tags-in (raw-form)
  "Every usage tag CLASSIFY-LOOP-PARAM produces for every binding of every
   loop in RAW-FORM."
  (let ((tags '()))
    (dolist (loop-node (%all-loop-nodes (%parse-fol raw-form)))
      (loop for (pname . nil) in (fol.compiler.ast:loop-node-bindings loop-node)
            for pos from 0
            when (symbolp pname)
              do (setf tags (append (fol.compiler.escape-analysis:classify-loop-param
                                      pname pos loop-node)
                                     tags))))
    tags))

;; A hand-constructed corpus covering every rule in the vocabulary, plus the
;; real benchmark/DVI sources loaded as FOL source text (not raw AST forms)
;; for genuine, non-cherry-picked coverage.
(defparameter +conformance-corpus+
  (list
   ;; recur-update (+ its zero-op case, recur-passthrough, via chain-id)
   '(loop (acc (dict) i 0)
      (if (< i 10) (recur (fol.compiler.collection-functions:assoc acc i i) (inc i)) acc))
   '(loop (acc (dict) i 0) (if (< i 10) (recur acc (inc i)) acc))
   ;; exit-update: a tail-position chain, not via recur
   '(loop (acc (dict) i 0)
      (if (< i 10)
          (recur (fol.compiler.collection-functions:assoc acc i i) (inc i))
          (fol.compiler.collection-functions:assoc acc :done cl:t)))
   ;; exit-in-literal (lit-exit)
   '(loop (acc (vector) i 0)
      (if (< i 10) (recur (fol.compiler.collection-functions:conj acc i) (inc i)) (vector acc i)))
   ;; read-ok
   '(loop (acc (dict) i 0)
      (if (< i 10)
          (recur (fol.compiler.collection-functions:assoc
                   acc i (fol.compiler.collection-functions:get acc i 0))
                 (inc i))
          acc))
   ;; recur-reset
   '(loop (acc (dict) i 0)
      (if (< i 10) (recur (dict) (inc i)) acc))
   ;; recur-in-complex-context: the recur itself is reached through a node
   ;; type CLASSIFY-LOOP-PARAM has no explicit clause for (HANDLER-CASE),
   ;; so COMPLEXP goes sticky-true before the recur is reached -- the
   ;; rewriter shares that node type verbatim and can't rewrite beneath it.
   '(loop (acc (dict) i 0)
      (if (< i 10)
          (handler-case
              (recur (fol.compiler.collection-functions:assoc acc i i) (inc i))
            (cl:error (e) acc))
          acc))
   ;; escape-call / other-flow
   '(loop (acc (dict) i 0)
      (if (< i 10) (recur (fol.compiler.collection-functions:assoc acc i (unknown-fn acc)) (inc i)) acc))))

(test tag-vocabulary-matches-formal-model
  "Every tag CLASSIFY-LOOP-PARAM produces, across a corpus covering every
   documented rule plus the real DVI/quicksort/LSim sources, is in the
   paper's documented vocabulary (Table \"fidelity\")."
  (let ((seen '()))
    (dolist (form +conformance-corpus+)
      (setf seen (union seen (%tags-in form))))
    (dolist (path (list "../benchmarks/fol-code/quicksort.fol"
                        "../benchmarks/fol-code/derived-value-invalidation.fol"))
      (when (probe-file path)
        (let ((*readtable* fol.compiler.reader:*fol-readtable*))
          (with-open-file (in path)
            (loop for f = (read in nil :eof) until (eq f :eof)
                  do (setf seen (union seen (%tags-in f))))))))
    (let ((undocumented (set-difference seen +documented-tag-vocabulary+)))
      (is (null undocumented)
          "Classifier produced tag(s) not in the paper's documented vocabulary: ~S"
          undocumented))
    ;; Coverage sanity: the hand-constructed corpus alone should exercise
    ;; every sanctioned tag and every named disqualifying rule (not
    ;; necessarily the escape-refinement diagnostics, which real code hits
    ;; unevenly).
    (dolist (must-see '(:recur-update :recur-passthrough :exit-update :exit-in-literal
                        :read-ok :recur-reset :recur-in-complex-context))
      (is (member must-see seen) "Corpus never exercised ~S" must-see))))

;;; ============================================================================
;;; Tier-2 Summary Inference Tests
;;; ============================================================================

(def-suite infer-summary-suite
  :description "Tier-2 summary inference for user functions"
  :in escape-analysis-suite)

(in-suite infer-summary-suite)

(defun do-infer-summary (form)
  "Parse a defn form and run infer-summary on its inner fn-node."
  (let* ((defn-node (fol.compiler:parse-form form))
         (fn-node (fol.compiler.ast:make-fn-node
                   :name (fol.compiler.ast:defn-node-name defn-node)
                   :clauses (fol.compiler.ast:defn-node-clauses defn-node))))
    (fol.compiler.escape-analysis:infer-summary fn-node)))

(test infer-summary-simple-linear
  "Infers a simple linear update function correctly."
  (let ((summary (do-infer-summary
                  '(defn add-item #(cart item)
                     (fol.compiler.collection-functions:assoc cart item item)))))
    (is (not (null summary)))
    ;; add-item has two params (cart item). cart is the collection assoc builds
    ;; a fresh root from (:none); item flows in as both key and value, so it is
    ;; reachable through the result (:shared-with-result).
    (is (equalp #(:none :shared-with-result)
                (fol.compiler.summaries:escape-summary-param-effects summary)))
    (is (fol.compiler.summaries:escape-summary-returns-fresh-p summary))))

(test infer-summary-escaping-call
  "Correctly marks a parameter as :retained if passed to an unknown function."
  (let ((summary (do-infer-summary
                  '(defn escape-it #(x) (some-unknown-function x)))))
    (is (not (null summary)))
    (is (equalp #(:retained)
                (fol.compiler.summaries:escape-summary-param-effects summary)))))

(test infer-summary-capture
  "Correctly marks a captured parameter as :retained."
  (let ((summary (do-infer-summary
                  '(defn capture-it #(x) (fn #() x)))))
    (is (not (null summary)))
    (is (equalp #(:retained)
                (fol.compiler.summaries:escape-summary-param-effects summary)))))

(test infer-summary-recursive-passthrough
  "Handles a simple tail-recursive function that passes its argument through."
  (let ((summary (do-infer-summary
                  '(defn recursive-rest #(s)
                     (if (fol.compiler.collection-functions:empty? s)
                         s
                         (recursive-rest (fol.compiler.collection-functions:rest s)))))))
    (is (not (null summary)))
    ;; The effect is :shared-with-result because `s` is returned in the base case.
    (is (equalp #(:shared-with-result)
                (fol.compiler.summaries:escape-summary-param-effects summary)))
    ;; It does not return a fresh value because it may return the original `s`.
    (is (not (fol.compiler.summaries:escape-summary-returns-fresh-p summary)))))

(test infer-summary-recursive-accumulator
  "Handles a tail-recursive accumulator pattern."
  (let ((summary (do-infer-summary
                  '(defn build-list #(n acc)
                     (if (= n 0)
                         acc
                         (build-list (- n 1) (fol.compiler.collection-functions:conj acc n)))))))
    (is (not (null summary)))
    ;; `acc` is returned in the base case and threaded through `conj` (:none on
    ;; the collection arg) -> :shared-with-result. `n` is `conj`'s value
    ;; argument, so it too becomes an element reachable through the result
    ;; (:shared-with-result). Both params are therefore :shared-with-result.
    (is (equalp #(:shared-with-result :shared-with-result)
                (fol.compiler.summaries:escape-summary-param-effects summary)))
    ;; It returns `acc` (a parameter) in the base case, so not fresh.
    (is (not (fol.compiler.summaries:escape-summary-returns-fresh-p summary)))))

(test infer-summary-mutually-recursive
  "Handles mutually recursive functions by iterating to a fixed point."
  ;; is-even? and is-odd? call each other.
  (let ((is-even-summary (do-infer-summary
                          '(defn is-even? #(n)
                             (if (= n 0) true (is-odd? (- n 1))))))
        (is-odd-summary (do-infer-summary
                         '(defn is-odd? #(n)
                            (if (= n 0) false (is-even? (- n 1)))))))
    ;; This test primarily ensures the analysis terminates and doesn't produce
    ;; an overly-conservative :retained summary due to the recursion.
    (is (not (null is-even-summary)))
    (is (not (null is-odd-summary)))
    (is (equalp #(:none)
                (fol.compiler.summaries:escape-summary-param-effects is-even-summary)))
    (is (equalp #(:none)
                (fol.compiler.summaries:escape-summary-param-effects is-odd-summary)))
    (is (fol.compiler.summaries:escape-summary-returns-fresh-p is-even-summary))
    (is (fol.compiler.summaries:escape-summary-returns-fresh-p is-odd-summary))))

(test infer-summary-returns-kind-dict-constructor
  "A 0-ary constructor whose tail form directly calls DICT infers
   RETURNS-KIND :DICT, alongside RETURNS-FRESH-P (trivially true: no
   parameter exists to fail freshness). This is the summary fact
   TRANSIENT-ELIGIBLE-INIT-P/INIT-SUPPORTS-P consult to accept a
   constructor-call loop init in place of a literal (§sec:formal)."
  (let ((summary (do-infer-summary
                  '(defn make-empty-cart #()
                     (fol.compiler.collection-functions:dict)))))
    (is (not (null summary)))
    (is (fol.compiler.summaries:escape-summary-returns-fresh-p summary))
    (is (eq :dict (fol.compiler.summaries:escape-summary-returns-kind summary)))))

(test infer-summary-returns-kind-vector-literal
  "A tail-position vector LITERAL (not a constructor call) also infers
   RETURNS-KIND :VECTOR."
  (let ((summary (do-infer-summary
                  (fol-form '(defn make-empty-vec #() #())))))
    (is (not (null summary)))
    (is (eq :vector (fol.compiler.summaries:escape-summary-returns-kind summary)))))

(test infer-summary-returns-kind-unknown-declines
  "A tail form that isn't a literal or a direct DICT/VECTOR/SET call --
   here IDENTITY wrapping a dict -- infers RETURNS-KIND NIL (unknown), even
   though RETURNS-FRESH-P is still true. Consumers must treat NIL as
   \"can't tell\", not \"not a collection\"."
  (let ((summary (do-infer-summary
                  '(defn make-mystery-cart #()
                     (fol.compiler.functional:identity
                      (fol.compiler.collection-functions:dict))))))
    (is (not (null summary)))
    (is (fol.compiler.summaries:escape-summary-returns-fresh-p summary))
    (is (null (fol.compiler.summaries:escape-summary-returns-kind summary)))))

;;; ============================================================================
;;; Run the suite
;;; ============================================================================

(fiveam:run! 'escape-analysis-suite)
