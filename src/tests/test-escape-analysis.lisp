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
;;; Run the suite
;;; ============================================================================

(fiveam:run! 'escape-analysis-suite)
