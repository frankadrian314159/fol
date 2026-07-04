;;; FOL Compiler Tests - Escape Summaries (Tier-1 vocabulary)
;;;
;;; Tests for src/summaries.lisp: the effect lattice, summary operations,
;;; Tier-1 stdlib table lookup semantics, transient op mapping, and package
;;; locking. See docs/escape-analysis-design.md, step 1.

(in-package :fol.compiler.tests)

(def-suite escape-summaries-suite
  :description "Escape summary vocabulary: lattice, Tier-1 table, locks"
  :in compiler-tests)

(in-suite escape-summaries-suite)

;;; ============================================================================
;;; Effect lattice
;;; ============================================================================

(test effect-lattice-order
  "Effects are linearly ordered :none < :invoked < :shared-with-result < :retained"
  (is (eq t (fol.compiler.summaries:effect<= :none :invoked)))
  (is (eq t (fol.compiler.summaries:effect<= :invoked :shared-with-result)))
  (is (eq t (fol.compiler.summaries:effect<= :shared-with-result :retained)))
  (is (eq t (fol.compiler.summaries:effect<= :none :retained)))
  (is (not (fol.compiler.summaries:effect<= :retained :none)))
  (is (not (fol.compiler.summaries:effect<= :shared-with-result :invoked))))

(test effect-lattice-reflexive
  "effect<= is reflexive"
  (dolist (e fol.compiler.summaries:+effect-order+)
    (is (eq t (fol.compiler.summaries:effect<= e e)))))

(test effect-join-lub
  "effect-join returns the worse of two effects"
  (is (eq :retained (fol.compiler.summaries:effect-join :none :retained)))
  (is (eq :retained (fol.compiler.summaries:effect-join :retained :none)))
  (is (eq :shared-with-result
          (fol.compiler.summaries:effect-join :invoked :shared-with-result)))
  (is (eq :none (fol.compiler.summaries:effect-join :none :none))))

;;; ============================================================================
;;; effect-for-arg: positional, rest, and conservative default
;;; ============================================================================

(test effect-for-arg-positional
  "Declared positions use their declared effect"
  (let ((s (fol.compiler.summaries:make-escape-summary
            :name "T" :param-effects #(:none :retained))))
    (is (eq :none (fol.compiler.summaries:effect-for-arg s 0)))
    (is (eq :retained (fol.compiler.summaries:effect-for-arg s 1)))))

(test effect-for-arg-rest
  "Arguments beyond declared positions use the rest effect"
  (let ((s (fol.compiler.summaries:make-escape-summary
            :name "T" :param-effects #(:none) :rest-effect :shared-with-result)))
    (is (eq :shared-with-result (fol.compiler.summaries:effect-for-arg s 5)))))

(test effect-for-arg-conservative-default
  "With no rest effect, extra arguments conservatively escape"
  (let ((s (fol.compiler.summaries:make-escape-summary
            :name "T" :param-effects #(:none))))
    (is (eq :retained (fol.compiler.summaries:effect-for-arg s 1)))))

;;; ============================================================================
;;; summary<= (the monotonicity fast-path test)
;;; ============================================================================

(test summary<=-reflexive
  "A summary is compatible with itself"
  (let ((s (fol.compiler.summaries:lookup-summary
            'fol.compiler.collection-functions:assoc)))
    (is (eq t (fol.compiler.summaries:summary<= s s)))))

(test summary<=-strengthening-ok
  "A less-escaping redefinition is compatible (no invalidation needed)"
  (let ((old (fol.compiler.summaries:make-escape-summary
              :name "F" :param-effects #(:retained)))
        (new (fol.compiler.summaries:make-escape-summary
              :name "F" :param-effects #(:none))))
    (is (eq t (fol.compiler.summaries:summary<= new old)))
    (is (not (fol.compiler.summaries:summary<= old new)))))

(test summary<=-freshness-must-be-preserved
  "Consumers that assumed a fresh result are broken by a non-fresh redefinition"
  (let ((old (fol.compiler.summaries:make-escape-summary
              :name "F" :param-effects #(:none) :returns-fresh-p t))
        (new (fol.compiler.summaries:make-escape-summary
              :name "F" :param-effects #(:none) :returns-fresh-p nil)))
    (is (not (fol.compiler.summaries:summary<= new old)))
    ;; The reverse is fine: gaining freshness breaks nobody.
    (is (eq t (fol.compiler.summaries:summary<= old new)))))

(test summary<=-no-new-barrier
  "A redefinition that introduces a barrier is incompatible"
  (let ((old (fol.compiler.summaries:make-escape-summary
              :name "F" :param-effects #(:none)))
        (new (fol.compiler.summaries:make-escape-summary
              :name "F" :param-effects #(:none) :barrier-p t)))
    (is (not (fol.compiler.summaries:summary<= new old)))
    (is (eq t (fol.compiler.summaries:summary<= old new)))))

(test summary<=-rest-effect
  "Losing a rest effect (nil = :retained) is an escalation"
  (let ((old (fol.compiler.summaries:make-escape-summary
              :name "F" :param-effects #() :rest-effect :none))
        (new (fol.compiler.summaries:make-escape-summary
              :name "F" :param-effects #())))
    (is (not (fol.compiler.summaries:summary<= new old)))))

;;; ============================================================================
;;; summary-join (GF summaries from method summaries)
;;; ============================================================================

(test summary-join-pointwise-worst
  "Join takes the worse effect at each position"
  (let* ((s1 (fol.compiler.summaries:make-escape-summary
              :name "F" :param-effects #(:none :retained) :returns-fresh-p t))
         (s2 (fol.compiler.summaries:make-escape-summary
              :name "F" :param-effects #(:invoked :none) :returns-fresh-p t))
         (j (fol.compiler.summaries:summary-join s1 s2)))
    (is (eq :invoked (fol.compiler.summaries:effect-for-arg j 0)))
    (is (eq :retained (fol.compiler.summaries:effect-for-arg j 1)))
    (is (eq t (fol.compiler.summaries:escape-summary-returns-fresh-p j)))))

(test summary-join-fresh-and-barrier
  "Join is fresh only if both are; barrier if either is"
  (let* ((fresh (fol.compiler.summaries:make-escape-summary
                 :name "F" :param-effects #(:none) :returns-fresh-p t))
         (barrier (fol.compiler.summaries:make-escape-summary
                   :name "F" :param-effects #(:none) :barrier-p t))
         (j (fol.compiler.summaries:summary-join fresh barrier)))
    (is (not (fol.compiler.summaries:escape-summary-returns-fresh-p j)))
    (is (eq t (fol.compiler.summaries:escape-summary-barrier-p j)))))

;;; ============================================================================
;;; Tier-1 table lookup semantics
;;; ============================================================================

(test lookup-finds-stdlib-symbols
  "Stdlib symbols from implementation packages match Tier-1 entries"
  (let ((s (fol.compiler.summaries:lookup-summary
            'fol.compiler.collection-functions:assoc)))
    (is (not (null s)))
    (is (eq t (fol.compiler.summaries:escape-summary-returns-fresh-p s)))
    ;; assoc: collection root is read-only, key/value shared into result
    (is (eq :none (fol.compiler.summaries:effect-for-arg s 0)))
    (is (eq :shared-with-result (fol.compiler.summaries:effect-for-arg s 2)))))

(test lookup-finds-hof-summaries
  "HOF summaries mark the function parameter :invoked"
  (let ((s (fol.compiler.summaries:lookup-summary
            'fol.compiler.seq-functions:reduce)))
    (is (not (null s)))
    (is (eq :invoked (fol.compiler.summaries:effect-for-arg s 0)))
    ;; FOL reduce is (fn init coll) -- Clojure order; result may be init.
    (is (eq :shared-with-result (fol.compiler.summaries:effect-for-arg s 1)))
    (is (eq :none (fol.compiler.summaries:effect-for-arg s 2)))
    (is (not (fol.compiler.summaries:escape-summary-returns-fresh-p s)))))

(test lookup-name-resolution-mirrors-compiler
  "Foreign symbols match by name (FOL resolves stdlib calls by name at
   emit/load time), except keywords and locally-defined names"
  ;; Name fallback on: cl:assoc and package-local homonyms match.
  (is (not (null (fol.compiler.summaries:lookup-summary 'cl:assoc))))
  (is (not (null (fol.compiler.summaries:lookup-summary
                  (intern "ASSOC" :fol.compiler.tests)))))
  ;; Keywords never match (keyword accessors are handled separately).
  (is (null (fol.compiler.summaries:lookup-summary :assoc)))
  ;; Names defined by the current compilation unit are excluded.
  (let ((fol.compiler.summaries:*name-exclusions* '("ASSOC")))
    (is (null (fol.compiler.summaries:lookup-summary 'cl:assoc)))
    ;; ...but exact home-package symbols still match.
    (is (not (null (fol.compiler.summaries:lookup-summary
                    'fol.compiler.collection-functions:assoc)))))
  ;; With name resolution off, only home-package symbols match.
  (let ((fol.compiler.summaries:*resolve-by-name* nil))
    (is (null (fol.compiler.summaries:lookup-summary 'cl:assoc)))
    (is (not (null (fol.compiler.summaries:lookup-summary
                    'fol.compiler.collection-functions:assoc))))))

(test lookup-rejects-non-symbols
  "Non-symbols never match"
  (is (null (fol.compiler.summaries:lookup-summary "ASSOC")))
  (is (null (fol.compiler.summaries:lookup-summary 42))))

(test lookup-escape-hatches-are-conservative
  "apply/funcall route extra args to :retained"
  (let ((s (fol.compiler.summaries:lookup-summary
            'fol.compiler.functional:apply)))
    (is (not (null s)))
    (is (eq :invoked (fol.compiler.summaries:effect-for-arg s 0)))
    (is (eq :retained (fol.compiler.summaries:effect-for-arg s 1)))))

;;; ============================================================================
;;; Transient op mapping
;;; ============================================================================

(test transient-op-mapping
  "Persistent update ops map to their destructive counterparts"
  (is (equal "ASSOC!" (fol.compiler.summaries:transient-op-for
                       'fol.compiler.collection-functions:assoc)))
  (is (equal "CONJ!" (fol.compiler.summaries:transient-op-for
                      'fol.compiler.collection-functions:conj)))
  (is (eq t (fol.compiler.summaries:transient-safe-op-p
             'fol.compiler.collection-functions:assoc))))

(test transient-op-rejects-reads-and-keywords
  "Read ops and keywords have no transient counterpart; foreign homonyms
   resolve by name like the compiler does"
  (is (null (fol.compiler.summaries:transient-op-for
             'fol.compiler.collection-functions:get)))
  (is (null (fol.compiler.summaries:transient-op-for :assoc)))
  (is (equal "ASSOC!" (fol.compiler.summaries:transient-op-for 'cl:assoc)))
  (let ((fol.compiler.summaries:*name-exclusions* '("ASSOC")))
    (is (null (fol.compiler.summaries:transient-op-for 'cl:assoc))))
  (is (not (fol.compiler.summaries:transient-safe-op-p
            'fol.compiler.collection-functions:get))))

;;; ============================================================================
;;; Package locking (on a scratch package, to keep the suite hermetic)
;;; ============================================================================

(test package-lock-blocks-redefinition
  "Locking a package blocks fdefinition changes on its symbols"
  (let* ((pkg-name "FOL.TEST.SCRATCH-LOCK")
         (pkg (or (find-package pkg-name) (make-package pkg-name :use nil)))
         (sym (intern "VICTIM" pkg)))
    (unwind-protect
         (progn
           (setf (fdefinition sym) (lambda () :original))
           (fol.compiler.summaries:lock-summary-packages (list pkg-name))
           (signals cl:package-error
             (setf (fdefinition sym) (lambda () :overwritten)))
           ;; Original definition survives the blocked attempt.
           (is (eq :original (funcall (fdefinition sym)))))
      (fol.compiler.summaries:unlock-summary-packages (list pkg-name))
      (delete-package pkg))))

(test summary-locked-packages-exist
  "Every package named for locking actually exists"
  (dolist (name fol.compiler.summaries:*summary-locked-packages*)
    (is (not (null (find-package name))))))

;;; ============================================================================
;;; Run the suite
;;; ============================================================================

(fiveam:run! 'escape-summaries-suite)
