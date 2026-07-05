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

;;; ============================================================================
;;; Run the suite
;;; ============================================================================

(fiveam:run! 'escape-analysis-suite)
