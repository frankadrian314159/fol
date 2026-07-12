;;; FOL Compiler Tests - Transient Loop/Reduce Conversion (step 3)
;;;
;;; Correctness tests: code compiled with *transient-loops* enabled must
;;; produce results identical to unoptimized compilation, and non-qualifying
;;; code must be left alone.

(in-package :fol.compiler.tests)

(def-suite transient-conversion-suite
  :description "Transient conversion: optimized == unoptimized"
  :in compiler-tests)

(in-suite transient-conversion-suite)

(defun compile-eval-fol (form &key transient)
  "Compile FORM (optionally with transient conversion) and evaluate it."
  (let ((fol.compiler.escape-analysis:*transient-loops* transient))
    (let ((result (fol.compiler:compile-form form)))
      (eval (fol.compiler:compilation-result-code result)))))

(defun compile-eval-fol-source (src &key transient)
  "Compile+eval FOL SOURCE TEXT (as opposed to a raw AST-shaped form), with
   *package* bound to :fol.core so stdlib name resolution (§sec:nameres)
   works the way it does for real FOL programs and benchmarks."
  (let ((fol.compiler.escape-analysis:*transient-loops* transient)
        (*package* (find-package :fol.core)))
    (eval (fol.compiler:compilation-result-code (fol.compiler:compile-string src)))))

(defun conversion-counts ()
  (list fol.compiler.escape-analysis:*loops-converted*
        fol.compiler.escape-analysis:*params-converted*
        fol.compiler.escape-analysis:*reduces-converted*))

;;; ============================================================================
;;; Loop accumulator conversion
;;; ============================================================================

(test transient-loop-dict-correctness
  "Dict accumulator loop: converted result identical to unconverted"
  (let ((form '(loop (acc (dict) i 0)
                 (if (cl:< i 20)
                     (recur (fol.compiler.collection-functions:assoc acc i (cl:* i 3))
                            (cl:+ i 1))
                     acc))))
    (let ((before (conversion-counts))
          (plain (compile-eval-fol form))
          (opt (compile-eval-fol form :transient t)))
      (is (typep opt 'fol.compiler.collections:<dict>))
      (is (= (fol.compiler.collections:collection-size plain)
             (fol.compiler.collections:collection-size opt)))
      (is (loop for i below 20
                always (eql (fol.compiler.collection-functions:get plain i)
                            (fol.compiler.collection-functions:get opt i))))
      ;; Exactly one loop / one param converted by the optimized compile.
      (is (equal (list (+ (first before) 1) (+ (second before) 1) (third before))
                 (conversion-counts))))))

(test transient-loop-vector-with-tuple-exit
  "Vector accumulator exiting inside a tuple literal (lh-pop-batch shape)"
  (let ((form '(loop (acc (vector) i 0)
                 (if (cl:< i 10)
                     (recur (fol.compiler.collection-functions:conj acc (cl:* i i))
                            (cl:+ i 1))
                     (vector acc i)))))
    (let ((plain (compile-eval-fol form))
          (opt (compile-eval-fol form :transient t)))
      (let ((pv (fol.compiler.collection-functions:get plain 0))
            (ov (fol.compiler.collection-functions:get opt 0)))
        (is (typep ov 'fol.compiler.collections:<vector>))
        (is (= (fol.compiler.collections:collection-size pv)
               (fol.compiler.collections:collection-size ov)))
        (is (loop for i below 10
                  always (eql (fol.compiler.collection-functions:get pv i)
                              (fol.compiler.collection-functions:get ov i))))
        ;; The counter rides along unchanged.
        (is (eql (fol.compiler.collection-functions:get plain 1)
                 (fol.compiler.collection-functions:get opt 1)))))))

(test transient-loop-if-branched-update
  "Conditional update (if p (conj acc i) acc) in recur position"
  (let ((form '(loop (acc (vector) i 0)
                 (if (cl:< i 10)
                     (recur (if (cl:evenp i)
                                (fol.compiler.collection-functions:conj acc i)
                                acc)
                            (cl:+ i 1))
                     acc))))
    (let ((plain (compile-eval-fol form))
          (opt (compile-eval-fol form :transient t)))
      (is (= (fol.compiler.collections:collection-size plain)
             (fol.compiler.collections:collection-size opt)))
      (is (loop for i below (fol.compiler.collections:collection-size plain)
                always (eql (fol.compiler.collection-functions:get plain i)
                            (fol.compiler.collection-functions:get opt i)))))))

(test transient-loop-thread-first-update
  "-> chain update in recur position"
  (let ((form '(loop (acc (dict) i 0)
                 (if (cl:< i 8)
                     (recur (-> acc
                                (fol.compiler.collection-functions:assoc i i)
                                (fol.compiler.collection-functions:assoc (cl:+ i 100) i))
                            (cl:+ i 1))
                     acc))))
    (let ((plain (compile-eval-fol form))
          (opt (compile-eval-fol form :transient t)))
      (is (= (fol.compiler.collections:collection-size plain)
             (fol.compiler.collections:collection-size opt)))
      (is (loop for i below 8
                always (and (eql (fol.compiler.collection-functions:get plain i)
                                 (fol.compiler.collection-functions:get opt i))
                            (eql (fol.compiler.collection-functions:get plain (cl:+ i 100))
                                 (fol.compiler.collection-functions:get opt (cl:+ i 100)))))))))

;;; ============================================================================
;;; Non-conversion safety
;;; ============================================================================

(test transient-loop-with-reads-converts
  "Since step 3.5 a loop that READS its accumulator converts, and the reads
   dispatch correctly on the mid-session transient"
  (let ((form '(loop (acc (dict) i 0)
                 (if (cl:< i 8)
                     (recur (fol.compiler.collection-functions:assoc
                             acc i (cl:+ 1 (fol.compiler.collection-functions:get
                                            acc (cl:- i 1) 0)))
                            (cl:+ i 1))
                     acc)))
        (before fol.compiler.escape-analysis:*loops-converted*))
    (let ((plain (compile-eval-fol form))
          (opt (compile-eval-fol form :transient t)))
      (is (= (+ before 1) fol.compiler.escape-analysis:*loops-converted*))
      (is (= (fol.compiler.collections:collection-size plain)
             (fol.compiler.collections:collection-size opt)))
      (is (loop for i below 8
                always (eql (fol.compiler.collection-functions:get plain i)
                            (fol.compiler.collection-functions:get opt i)))))))

(test transient-gate-blocks-vector-assoc
  "Vector-init accumulator updated via assoc is blocked by the op gate
   (edit-tagged vector transients support conj! only)"
  (let ((form '(loop (acc (vector 0 0 0) i 0)
                 (if (cl:< i 3)
                     (recur (fol.compiler.collection-functions:assoc acc i (cl:* i 7))
                            (cl:+ i 1))
                     acc)))
        (before fol.compiler.escape-analysis:*loops-converted*))
    (let ((plain (compile-eval-fol form))
          (opt (compile-eval-fol form :transient t)))
      (is (= before fol.compiler.escape-analysis:*loops-converted*))
      (is (loop for i below 3
                always (eql (fol.compiler.collection-functions:get plain i)
                            (fol.compiler.collection-functions:get opt i)))))))

(test transient-set-write-only-converts
  "Set-init accumulator with a write-only conj chain converts (edit-tagged
   by default, PLDI 2027 weakness-6 fix: <set> is HAMT-backed exactly like
   <dict>, so it gets the same treatment, not a separate representation)."
  (let ((form '(loop (acc (set) i 0)
                 (if (cl:< i 6)
                     (recur (fol.compiler.collection-functions:conj acc i)
                            (cl:+ i 1))
                     acc)))
        (before fol.compiler.escape-analysis:*loops-converted*))
    (let ((plain (compile-eval-fol form))
          (opt (compile-eval-fol form :transient t)))
      (is (= (+ before 1) fol.compiler.escape-analysis:*loops-converted*))
      (is (= (fol.compiler.collections:collection-size plain)
             (fol.compiler.collections:collection-size opt))))))

(test transient-set-with-reads-converts
  "A set accumulator that is READ (via COUNT) now converts too, since sets
   are edit-tagged by default -- this used to be refused when sets were
   wrapper-only (no mid-session reads)."
  (let ((form '(loop (acc (set) i 0)
                 (if (cl:< i 6)
                     (recur (if (cl:evenp (fol.compiler.collection-functions:count acc))
                                (fol.compiler.collection-functions:conj acc i)
                                acc)
                            (cl:+ i 1))
                     acc)))
        (before fol.compiler.escape-analysis:*loops-converted*))
    (let ((plain (compile-eval-fol form))
          (opt (compile-eval-fol form :transient t)))
      (is (= (+ before 1) fol.compiler.escape-analysis:*loops-converted*))
      (is (= (fol.compiler.collections:collection-size plain)
             (fol.compiler.collections:collection-size opt))))))

(test transient-set-wrapper-ablation-forbids-reads
  "Under the RQ5 wrapper-transients ablation flag, a read-containing set
   loop is refused, matching wrapper's structural read limitation -- the
   op-gate check this flag exists to exercise. Write-only set loops still
   convert under the flag, using the legacy wrapper representation."
  (let ((fol.compiler.collections:*wrapper-transients* t))
    (let ((form '(loop (acc (set) i 0)
                   (if (cl:< i 6)
                       (recur (if (cl:evenp (fol.compiler.collection-functions:count acc))
                                  (fol.compiler.collection-functions:conj acc i)
                                  acc)
                              (cl:+ i 1))
                       acc)))
          (before fol.compiler.escape-analysis:*loops-converted*))
      (compile-eval-fol form :transient t)
      (is (= before fol.compiler.escape-analysis:*loops-converted*)))
    (let ((form '(loop (acc (set) i 0)
                   (if (cl:< i 6)
                       (recur (fol.compiler.collection-functions:conj acc i)
                              (cl:+ i 1))
                       acc)))
          (before fol.compiler.escape-analysis:*loops-converted*))
      (let ((plain (compile-eval-fol form))
            (opt (compile-eval-fol form :transient t)))
        (is (= (+ before 1) fol.compiler.escape-analysis:*loops-converted*))
        (is (= (fol.compiler.collections:collection-size plain)
               (fol.compiler.collections:collection-size opt)))))))

;;; ============================================================================
;;; Edit-tagged ownership soundness (step 3.5)
;;; ============================================================================

(test transient-source-preservation-dict
  "Mutating a transient never affects the persistent source, across generations"
  (let* ((p (fol.compiler.collection-functions:assoc
             (fol.compiler.collection-functions:dict) :a 1))
         (td (fol.compiler.collections:transient p)))
    (fol.compiler.collections:assoc! td :a 99)
    (fol.compiler.collections:assoc! td :b 2)
    (let ((p2 (fol.compiler.collections:persistent! td)))
      ;; source untouched
      (is (eql 1 (fol.compiler.collection-functions:get p :a)))
      (is (eql :absent (fol.compiler.collection-functions:get p :b :absent)))
      (is (= 1 (fol.compiler.collections:collection-size p)))
      ;; result correct
      (is (eql 99 (fol.compiler.collection-functions:get p2 :a)))
      (is (eql 2 (fol.compiler.collection-functions:get p2 :b)))
      ;; second generation: freezing really froze the edited nodes
      (let ((td2 (fol.compiler.collections:transient p2)))
        (fol.compiler.collections:assoc! td2 :a :mutated)
        (fol.compiler.collections:persistent! td2)
        (is (eql 99 (fol.compiler.collection-functions:get p2 :a)))))))

(test transient-source-preservation-vector
  "Vector transient conj! across tail boundaries preserves the source"
  (let* ((p (fol.compiler.collection-functions:vector 0 1 2))
         (tv (fol.compiler.collections:transient p)))
    (loop for i from 3 below 100
          do (fol.compiler.collections:conj! tv i))
    ;; mid-session reads
    (is (= 100 (fol.compiler.collection-functions:count tv)))
    (is (eql 50 (fol.compiler.collection-functions:get tv 50)))
    (let ((p2 (fol.compiler.collections:persistent! tv)))
      (is (= 3 (fol.compiler.collections:collection-size p)))
      (is (= 100 (fol.compiler.collections:collection-size p2)))
      (is (loop for i below 100
                always (eql i (fol.compiler.collection-functions:get p2 i)))))))

(test transient-source-preservation-set
  "Set transient conj!/disj! across tail boundaries preserves the source
   (PLDI 2027 weakness-6 fix: <set> is HAMT-backed like <dict>, so it gets
   the identical edit-tagged treatment and the same source-preservation
   guarantee, not the wrapper-only behavior an earlier draft described)."
  (let* ((p (fol.compiler.collection-functions:set 1 2 3))
         (ts (fol.compiler.collections:transient p)))
    (fol.compiler.collections:conj! ts 4)
    (fol.compiler.collections:conj! ts 5)
    (fol.compiler.collections:disj! ts 2)
    ;; mid-session reads
    (is (= 4 (fol.compiler.collection-functions:count ts)))
    (is (eql 4 (fol.compiler.collection-functions:get ts 4 :absent)))
    (is (eql :absent (fol.compiler.collection-functions:get ts 2 :absent)))
    (let ((p2 (fol.compiler.collections:persistent! ts)))
      ;; source untouched
      (is (eql 2 (fol.compiler.collection-functions:get p 2 :absent)))
      (is (eql :absent (fol.compiler.collection-functions:get p 4 :absent)))
      (is (= 3 (fol.compiler.collections:collection-size p)))
      ;; result correct
      (is (= 4 (fol.compiler.collections:collection-size p2)))
      (is (eql :absent (fol.compiler.collection-functions:get p2 2 :absent)))
      (is (eql 5 (fol.compiler.collection-functions:get p2 5 :absent)))
      ;; second generation: freezing really froze the edited nodes
      (let ((ts2 (fol.compiler.collections:transient p2)))
        (fol.compiler.collections:disj! ts2 4)
        (fol.compiler.collections:persistent! ts2)
        (is (eql 4 (fol.compiler.collection-functions:get p2 4 :absent)))))))

(test transient-loop-reset-not-converted
  "A recur that resets the accumulator to a fresh value is not converted"
  (let ((form '(loop (acc (dict) i 0)
                 (if (cl:< i 5)
                     (if (cl:= i 2)
                         (recur (dict) (cl:+ i 1))
                         (recur (fol.compiler.collection-functions:assoc acc i i)
                                (cl:+ i 1)))
                     acc)))
        (before fol.compiler.escape-analysis:*loops-converted*))
    (let ((plain (compile-eval-fol form))
          (opt (compile-eval-fol form :transient t)))
      (is (= before fol.compiler.escape-analysis:*loops-converted*))
      (is (= (fol.compiler.collections:collection-size plain)
             (fol.compiler.collections:collection-size opt))))))

(test transient-flag-off-no-conversion
  "With the flag off nothing is converted"
  (let ((before (conversion-counts)))
    (compile-eval-fol '(loop (acc (dict) i 0)
                         (if (cl:< i 3)
                             (recur (fol.compiler.collection-functions:assoc acc i i)
                                    (cl:+ i 1))
                             acc)))
    (is (equal before (conversion-counts)))))

;;; ============================================================================
;;; Tier-1 method-combination trust (A1's gap: a :before/:after/:around
;;; method on an assumed name, predating any region's registration, cannot
;;; be caught by NOTE-REDEFINITION -- there is no redefinition event for a
;;; not-yet-registered dependent to observe). TIER1-METHODS-TRUSTED-P
;;; (escape-analysis.lisp) closes it via MOP introspection at conversion
;;; time. Reproduces the exact scenario found during review: a pre-existing
;;; :around method's side effect was previously silently dropped by the
;;; bang-op fast path.
;;; ============================================================================

(test transient-loop-refuses-when-tier1-op-customized
  "A pre-existing :around method on ASSOC for <dict> blocks conversion, and
   the persistent (unconverted) path correctly still runs it."
  (let ((log nil))
    (defmethod fol.compiler.collection-functions:assoc :around
        ((d fol.compiler.collections:<dict>) key val &rest kvs)
      (declare (ignore kvs))
      (push (cons key val) log)
      (call-next-method))
    (unwind-protect
        (let ((form '(loop (acc (dict) i 0)
                       (if (cl:< i 5)
                           (recur (fol.compiler.collection-functions:assoc acc i i)
                                  (cl:+ i 1))
                           acc)))
              (before fol.compiler.escape-analysis:*loops-converted*))
          (let ((opt (compile-eval-fol form :transient t)))
            ;; Not converted: the counter must not move.
            (is (= before fol.compiler.escape-analysis:*loops-converted*))
            ;; The :around method's side effect ran exactly 5 times -- proof
            ;; the persistent (not bang) path executed, not merely that the
            ;; counter didn't move for some unrelated reason.
            (is (= 5 (length log)))
            (is (= 5 (fol.compiler.collections:collection-size opt)))))
      (remove-method #'fol.compiler.collection-functions:assoc
                      (find-method #'fol.compiler.collection-functions:assoc
                                   '(:around)
                                   (list (find-class 'fol.compiler.collections:<dict>) t t)
                                   nil)))))

(test transient-loop-unaffected-by-method-on-other-representation
  "A customized ASSOC method on <vector>'s representation must not block a
   <dict> accumulator's conversion -- the check is representation-specific,
   not a blanket refusal whenever ASSOC has any :around method anywhere."
  (defclass tc-unrelated-marker () ())
  (defmethod fol.compiler.collection-functions:assoc :around
      ((d tc-unrelated-marker) key val &rest kvs)
    (declare (ignore kvs))
    (call-next-method))
  (unwind-protect
      (let ((form '(loop (acc (dict) i 0)
                     (if (cl:< i 5)
                         (recur (fol.compiler.collection-functions:assoc acc i i)
                                (cl:+ i 1))
                         acc)))
            (before fol.compiler.escape-analysis:*loops-converted*))
        (compile-eval-fol form :transient t)
        (is (= (1+ before) fol.compiler.escape-analysis:*loops-converted*)))
    (remove-method #'fol.compiler.collection-functions:assoc
                    (find-method #'fol.compiler.collection-functions:assoc
                                 '(:around)
                                 (list (find-class 'tc-unrelated-marker) t t)
                                 nil))))

;;; ============================================================================
;;; RQ5 wrapper-transient ablation (fol.compiler.collections:*wrapper-transients*)
;;; ============================================================================

(test wrapper-ablation-write-only-still-converts
  "Under the RQ5 ablation flag, a write-only dict loop still converts, using
   the legacy wrapper representation instead of edit-tagged, and produces
   the same result as the persistent baseline."
  (let ((fol.compiler.collections:*wrapper-transients* t)
        (form '(loop (acc (dict) i 0)
                (if (cl:< i 20)
                    (recur (fol.compiler.collection-functions:assoc acc i i)
                           (cl:+ i 1))
                    acc))))
    (let ((before fol.compiler.escape-analysis:*loops-converted*)
          (opt (compile-eval-fol form :transient t)))
      (is (= (1+ before) fol.compiler.escape-analysis:*loops-converted*))
      (is (= 20 (fol.compiler.collections:collection-size opt)))
      (is (loop for i below 20
                always (eql i (fol.compiler.collection-functions:get opt i)))))))

(test wrapper-ablation-read-containing-not-converted
  "Under the RQ5 ablation flag, a read-containing dict loop is refused --
   wrapper transients (unlike edit-tagged) forbid mid-session reads."
  (let ((fol.compiler.collections:*wrapper-transients* t)
        (form '(loop (acc (dict) i 0)
                (if (cl:< i 5)
                    (recur (fol.compiler.collection-functions:assoc
                            acc i (fol.compiler.collection-functions:get acc i 0))
                           (cl:+ i 1))
                    acc)))
        (before fol.compiler.escape-analysis:*loops-converted*))
    (compile-eval-fol form :transient t)
    (is (= before fol.compiler.escape-analysis:*loops-converted*))))

(test wrapper-ablation-flag-off-uses-edit-tagged
  "With the ablation flag off (the default), the same read-containing loop
   converts normally via the edit-tagged representation."
  (let ((form '(loop (acc (dict) i 0)
                (if (cl:< i 5)
                    (recur (fol.compiler.collection-functions:assoc
                            acc i (fol.compiler.collection-functions:get acc i 0))
                           (cl:+ i 1))
                    acc)))
        (before fol.compiler.escape-analysis:*loops-converted*))
    (is (not fol.compiler.collections:*wrapper-transients*))
    (compile-eval-fol form :transient t)
    (is (= (1+ before) fol.compiler.escape-analysis:*loops-converted*))))

;;; ============================================================================
;;; Reduce accumulator conversion
;;; ============================================================================

(test transient-reduce-conj-correctness
  "(reduce (fn [acc x] (conj acc ...)) [] coll) converts and matches"
  (let ((form (fol-form
               '(fol.compiler.seq-functions:reduce
                 (fn #(acc x) (fol.compiler.collection-functions:conj
                               acc (cl:* x 2)))
                 (vector)
                 (vector 1 2 3 4 5)))))
    (let ((before fol.compiler.escape-analysis:*reduces-converted*)
          (plain (compile-eval-fol form))
          (opt (compile-eval-fol form :transient t)))
      (is (= (+ before 1) fol.compiler.escape-analysis:*reduces-converted*))
      (is (typep opt 'fol.compiler.collections:<vector>))
      (is (= (fol.compiler.collections:collection-size plain)
             (fol.compiler.collections:collection-size opt)))
      (is (loop for i below 5
                always (eql (fol.compiler.collection-functions:get plain i)
                            (fol.compiler.collection-functions:get opt i)))))))

(test transient-reduce-if-passthrough
  "Reduce lambda with conditional passthrough converts and matches"
  (let ((form (fol-form
               '(fol.compiler.seq-functions:reduce
                 (fn #(a x) (if (cl:< x 4)
                                (fol.compiler.collection-functions:conj a x)
                                a))
                 (vector)
                 (vector 1 2 3 4 5 6)))))
    (let ((plain (compile-eval-fol form))
          (opt (compile-eval-fol form :transient t)))
      (is (= (fol.compiler.collections:collection-size plain)
             (fol.compiler.collections:collection-size opt)))
      (is (loop for i below (fol.compiler.collections:collection-size plain)
                always (eql (fol.compiler.collection-functions:get plain i)
                            (fol.compiler.collection-functions:get opt i)))))))

(test transient-reduce-read-not-converted
  "A reduce lambda that reads its accumulator is left alone"
  (let ((form (fol-form
               '(fol.compiler.seq-functions:reduce
                 (fn #(acc x) (fol.compiler.collection-functions:assoc
                               acc x
                               (fol.compiler.collections:collection-size acc)))
                 (dict)
                 (vector :a :b :c))))
        (before fol.compiler.escape-analysis:*reduces-converted*))
    (let ((plain (compile-eval-fol form))
          (opt (compile-eval-fol form :transient t)))
      (is (= before fol.compiler.escape-analysis:*reduces-converted*))
      (is (= (fol.compiler.collections:collection-size plain)
             (fol.compiler.collections:collection-size opt))))))

(test transient-reduce-nonliteral-init-not-converted
  "Reduce whose init is not a collection literal is left alone"
  (let ((form (fol-form
               '(fol.compiler.seq-functions:reduce
                 (fn #(acc x) (fol.compiler.collection-functions:conj acc x))
                 someval
                 (vector 1 2))))
        (before fol.compiler.escape-analysis:*reduces-converted*))
    ;; Compile only (someval is unbound); conversion decision happens at emit.
    (let ((fol.compiler.escape-analysis:*transient-loops* t))
      (fol.compiler:compile-form form))
    (is (= before fol.compiler.escape-analysis:*reduces-converted*))))

;;; ============================================================================
;;; Reduce init-threading (step 5): (reduce (fn [a x] linear) <chain> coll)
;;; ============================================================================

(test init-threading-loop-recur-through-reduce
  "A loop accumulator threaded through a reduce in the recur position converts"
  (let ((form (fol-form
               '(loop (acc (vector) i 0)
                  (if (cl:< i 5)
                      (recur (fol.compiler.seq-functions:reduce
                              (fn #(a x) (fol.compiler.collection-functions:conj
                                          a (cl:+ x i)))
                              acc
                              (vector 1 2 3))
                             (cl:+ i 1))
                      acc))))
        (before fol.compiler.escape-analysis:*loops-converted*))
    (let ((plain (compile-eval-fol form))
          (opt (compile-eval-fol form :transient t)))
      (is (= (+ before 1) fol.compiler.escape-analysis:*loops-converted*))
      (is (= 15 (fol.compiler.collections:collection-size plain)))
      (is (= (fol.compiler.collections:collection-size plain)
             (fol.compiler.collections:collection-size opt)))
      (is (loop for i below 15
                always (eql (fol.compiler.collection-functions:get plain i)
                            (fol.compiler.collection-functions:get opt i)))))))

(test init-threading-nested-reduce
  "The LSim new-events shape: outer reduce whose lambda threads acc through
   an inner reduce converts as one transient region"
  (let ((form (fol-form
               '(fol.compiler.seq-functions:reduce
                 (fn #(acc c)
                     (fol.compiler.seq-functions:reduce
                      (fn #(a r) (if (cl:evenp r)
                                     (fol.compiler.collection-functions:conj a r)
                                     a))
                      acc
                      c))
                 (vector)
                 (vector (vector 1 2 3 4) (vector 5 6 7 8)))))
        (before fol.compiler.escape-analysis:*reduces-converted*))
    (let ((plain (compile-eval-fol form))
          (opt (compile-eval-fol form :transient t)))
      (is (= (+ before 1) fol.compiler.escape-analysis:*reduces-converted*))
      (is (= (fol.compiler.collections:collection-size plain)
             (fol.compiler.collections:collection-size opt)))
      (is (loop for i below (fol.compiler.collections:collection-size plain)
                always (eql (fol.compiler.collection-functions:get plain i)
                            (fol.compiler.collection-functions:get opt i)))))))

(test init-threading-capture-disqualifies
  "An inner lambda that references the OUTER accumulator (not shadowed by its
   params) blocks the conversion"
  (let ((form (fol-form
               '(loop (acc (vector) i 0)
                  (if (cl:< i 3)
                      (recur (fol.compiler.seq-functions:reduce
                              (fn #(a x) (fol.compiler.collection-functions:conj
                                          a (fol.compiler.collection-functions:count acc)))
                              acc
                              (vector 1 2))
                             (cl:+ i 1))
                      acc))))
        (before fol.compiler.escape-analysis:*loops-converted*))
    (let ((plain (compile-eval-fol form))
          (opt (compile-eval-fol form :transient t)))
      (is (= before fol.compiler.escape-analysis:*loops-converted*))
      (is (= (fol.compiler.collections:collection-size plain)
             (fol.compiler.collections:collection-size opt))))))

(test init-threading-op-gate-applies
  "A dict accumulator threaded through a conj-reduce is blocked by the op gate"
  (let ((form (fol-form
               '(loop (acc (dict) i 0)
                  (if (cl:< i 3)
                      (recur (fol.compiler.seq-functions:reduce
                              (fn #(a x) (fol.compiler.collection-functions:conj a x))
                              acc
                              (vector 1 2))
                             (cl:+ i 1))
                      acc))))
        (before fol.compiler.escape-analysis:*loops-converted*))
    (let ((fol.compiler.escape-analysis:*transient-loops* t))
      (fol.compiler:compile-form form))
    (is (= before fol.compiler.escape-analysis:*loops-converted*))))

;;; ============================================================================
;;; World machinery (step 4): guards, invalidation, live redefinition
;;; ============================================================================

(test world-register-and-invalidate-mechanics
  "Region cells invalidate on redefinition of assumed names only"
  (fol.compiler.world:reset-world)
  (let ((cell (fol.compiler.world:register-region '("ASSOC" "GET"))))
    (is (eq t (fol.compiler.world:region-valid-p cell)))
    ;; Unrelated redefinition: nothing happens.
    (fol.compiler.world:note-redefinition 'some-random-fn)
    (is (eq t (fol.compiler.world:region-valid-p cell)))
    ;; Redefinition of an assumed name: the region falls back.
    (fol.compiler.world:note-redefinition 'assoc)
    (is (null (fol.compiler.world:region-valid-p cell)))
    (let ((stats (fol.compiler.world:world-stats)))
      (is (= 1 (getf stats :regions-registered)))
      (is (= 1 (getf stats :regions-invalidated)))
      (is (= 2 (getf stats :redefinitions-noted)))
      (is (= 1 (getf stats :redefinitions-invalidating))))))

(test world-panic-switch
  "invalidate-all-regions flips every registered cell"
  (fol.compiler.world:reset-world)
  (let ((c1 (fol.compiler.world:register-region '("CONJ")))
        (c2 (fol.compiler.world:register-region '("ASSOC"))))
    (fol.compiler.world:invalidate-all-regions)
    (is (null (fol.compiler.world:region-valid-p c1)))
    (is (null (fol.compiler.world:region-valid-p c2)))))

(test world-guarded-loop-falls-back-correctly
  "A converted loop keeps producing correct results after its assumptions
   are invalidated (it silently takes the original path)"
  (fol.compiler.world:reset-world)
  (let* ((form '(loop (acc (dict) i 0)
                  (if (cl:< i 10)
                      (recur (fol.compiler.collection-functions:assoc acc i i)
                             (cl:+ i 1))
                      acc)))
         (fn (let ((fol.compiler.escape-analysis:*transient-loops* t))
               (compile nil `(lambda ()
                               ,(fol.compiler:compilation-result-code
                                 (fol.compiler:compile-form form))))))
         (before (funcall fn)))
    ;; Guard registered and valid: optimized path.
    (is (= 1 (getf (fol.compiler.world:world-stats) :regions-registered)))
    ;; Invalidate the assumption; the same compiled function must still work.
    (fol.compiler.world:note-redefinition 'assoc)
    (is (cl:plusp (getf (fol.compiler.world:world-stats) :regions-invalidated)))
    (let ((after (funcall fn)))
      (is (= (fol.compiler.collections:collection-size before)
             (fol.compiler.collections:collection-size after)))
      (is (loop for i below 10
                always (eql (fol.compiler.collection-functions:get before i)
                            (fol.compiler.collection-functions:get after i)))))))

(test world-defn-emits-redefinition-note
  "In optimizer mode, compiling+evaluating a defn notifies the world"
  (fol.compiler.world:reset-world)
  (fol.compiler.world:register-region '("MY-WORLD-TEST-FN"))
  (let ((code (let ((fol.compiler.escape-analysis:*transient-loops* t))
                (fol.compiler:compilation-result-code
                 (fol.compiler:compile-form
                  '(defn my-world-test-fn #(x) x))))))
    ;; The note fires at eval/load time, not compile time.
    (is (= 0 (getf (fol.compiler.world:world-stats) :redefinitions-noted)))
    (eval code)
    (is (= 1 (getf (fol.compiler.world:world-stats) :redefinitions-noted)))
    (is (= 1 (getf (fol.compiler.world:world-stats) :regions-invalidated)))))

(test world-defmethod-emits-redefinition-note
  "In optimizer mode, compiling+evaluating a defmethod notifies the world --
   mirrors world-defn-emits-redefinition-note above, but for 'a generic
   function gains a new method' (§sec:soundness), the invalidation trigger
   RQ8's existing evidence didn't exercise (Threats to Validity: 'no
   benchmark executes a defmethod against a name a converted region
   depends on'). Uses a fresh class/generic-function name, not ASSOC
   itself: ASSOC is shared by every other test in this suite, and unlike a
   dynamic-variable rebinding, a real CLOS method addition outlives the
   test's dynamic extent, so touching it here would leak into later tests."
  (fol.compiler.world:reset-world)
  (fol.compiler.world:register-region '("MY-WORLD-TEST-METHOD-FN"))
  (compile-eval-fol-source
   "(defclass <world-test-class> [] [[v :initform 0]])"
   :transient t)
  (let ((code (let ((fol.compiler.escape-analysis:*transient-loops* t)
                     (*package* (find-package :fol.core)))
                (fol.compiler:compilation-result-code
                 (fol.compiler:compile-string
                  "(defmethod my-world-test-method-fn [(x <world-test-class>) y] y)")))))
    ;; The note fires at eval/load time, not compile time.
    (is (= 0 (getf (fol.compiler.world:world-stats) :redefinitions-noted)))
    (let ((*package* (find-package :fol.core))) (eval code))
    (is (= 1 (getf (fol.compiler.world:world-stats) :redefinitions-noted)))
    (is (= 1 (getf (fol.compiler.world:world-stats) :regions-invalidated)))))

(test world-flag-off-defn-shape-unchanged
  "Outside optimizer mode, defn output has no world wrapper"
  (let ((code (fol.compiler:compilation-result-code
               (fol.compiler:compile-form '(defn my-plain-fn #(x) x)))))
    (is (not (eq 'cl:prog1 (first code))))))

;;; ============================================================================
;;; Dynamic-extent closure client (step 5)
;;; ============================================================================

(defun compile-eval-dx (form &key stack)
  (let ((fol.compiler.escape-analysis:*stack-closures* stack))
    (let ((result (fol.compiler:compile-form form)))
      (values (eval (fol.compiler:compilation-result-code result))
              (fol.compiler:compilation-result-code result)))))

(test dx-closure-correctness-and-emission
  "A closure passed to mapv is stack-allocated (guarded) with identical results"
  (let ((form (fol-form
               '(fol.compiler.seq-functions:mapv
                 (fn #(x) (cl:* x 3))
                 (vector 1 2 3 4)))))
    (multiple-value-bind (plain plain-code) (compile-eval-dx form)
      (multiple-value-bind (opt opt-code) (compile-eval-dx form :stack t)
        ;; flag off: no dynamic-extent anywhere
        (is (null (search "DYNAMIC-EXTENT" (write-to-string plain-code))))
        ;; flag on: dx binding + world guard emitted
        (is (not (null (search "DYNAMIC-EXTENT" (write-to-string opt-code)))))
        (is (not (null (search "REGISTER-REGION" (write-to-string opt-code)))))
        (is (= (fol.compiler.collections:collection-size plain)
               (fol.compiler.collections:collection-size opt)))
        (is (loop for i below 4
                  always (eql (fol.compiler.collection-functions:get plain i)
                              (fol.compiler.collection-functions:get opt i))))))))

(test dx-closure-capturing-loop-var
  "Stack-allocated closures capturing loop variables stay correct per iteration"
  (let ((form (fol-form
               '(loop (s 0 i 0)
                  (if (cl:< i 50)
                      (recur (cl:+ s (fol.compiler.seq-functions:reduce
                                      (fn #(a x) (cl:+ a (cl:* x i)))
                                      0
                                      (vector 1 2 3)))
                             (cl:+ i 1))
                      s)))))
    (let ((plain (compile-eval-dx form))
          (opt (compile-eval-dx form :stack t)))
      (is (eql plain opt)))))

(test dx-falls-back-after-redefinition
  "After the callee's name is redefined, the guarded dx call still works"
  (fol.compiler.world:reset-world)
  (let* ((form (fol-form
                '(fol.compiler.seq-functions:mapv (fn #(x) (cl:+ x 1))
                                                  (vector 10 20))))
         (fn (let ((fol.compiler.escape-analysis:*stack-closures* t))
               (compile nil `(lambda ()
                               ,(fol.compiler:compilation-result-code
                                 (fol.compiler:compile-form form))))))
         (before (funcall fn)))
    (fol.compiler.world:note-redefinition 'mapv)
    (let ((after (funcall fn)))
      (is (loop for i below 2
                always (eql (fol.compiler.collection-functions:get before i)
                            (fol.compiler.collection-functions:get after i)))))))

(test dx-and-transient-flags-compose
  "Both optimizers on: a converted reduce whose lambda is also stack-allocated"
  (let ((form (fol-form
               '(fol.compiler.seq-functions:reduce
                 (fn #(acc x) (fol.compiler.collection-functions:conj acc (cl:* x 2)))
                 (vector)
                 (vector 1 2 3)))))
    (let ((plain (compile-eval-dx form))
          (opt (let ((fol.compiler.escape-analysis:*transient-loops* t)
                     (fol.compiler.escape-analysis:*stack-closures* t))
                 (eval (fol.compiler:compilation-result-code
                        (fol.compiler:compile-form form))))))
      (is (= (fol.compiler.collections:collection-size plain)
             (fol.compiler.collections:collection-size opt)))
      (is (loop for i below 3
                always (eql (fol.compiler.collection-functions:get plain i)
                            (fol.compiler.collection-functions:get opt i)))))))

(test profitability-heuristic-emitted-correctly
  "The runtime size check is emitted only for accumulators that START from a
   non-empty collection (crossover thresholds: dict 16, vector 12). An
   accumulator grown from an EMPTY literal must NOT be guarded on initial
   size: count(empty)=0 can never exceed the threshold, which would make the
   fast path unreachable for the most common accumulation shape."
  (let* ((fol.compiler.escape-analysis:*transient-loops* t)
         (dict-form '(loop (acc (dict :a 1) i 0) (if (< i 10) (recur (assoc acc i i) (inc i)) acc)))
         (vec-form '(loop (acc (vector 1) i 0) (if (< i 10) (recur (conj acc i) (inc i)) acc)))
         (empty-dict-form '(loop (acc (dict) i 0) (if (< i 10) (recur (assoc acc i i) (inc i)) acc)))
         (empty-vec-form '(loop (acc (vector) i 0) (if (< i 10) (recur (conj acc i) (inc i)) acc)))
         (dict-code-str (write-to-string
                         (fol.compiler:compilation-result-code
                          (fol.compiler:compile-form dict-form))))
         (vec-code-str (write-to-string
                        (fol.compiler:compilation-result-code
                         (fol.compiler:compile-form vec-form))))
         (empty-dict-str (write-to-string
                          (fol.compiler:compilation-result-code
                           (fol.compiler:compile-form empty-dict-form))))
         (empty-vec-str (write-to-string
                         (fol.compiler:compilation-result-code
                          (fol.compiler:compile-form empty-vec-form)))))
    ;; The guard ANDs the world-validity cell with a size check on the
    ;; accumulator. (Package prefixes on CL:AND/CAR/LOAD-TIME-VALUE depend on
    ;; the printing package, so we check the package-stable fragments: the
    ;; assumed op region and the threshold+count comparison.)
    ;; Non-empty dict init: threshold = 16.
    (is (search "(FOL.COMPILER.WORLD:REGISTER-REGION '(\"ASSOC\"))"
                dict-code-str :test #'string-equal))
    (is (search "(< 16 (FOL.COMPILER.COLLECTION-FUNCTIONS:COUNT ACC))"
                dict-code-str :test #'string-equal))
    ;; Non-empty vector init: threshold = 12.
    (is (search "(FOL.COMPILER.WORLD:REGISTER-REGION '(\"CONJ\"))"
                vec-code-str :test #'string-equal))
    (is (search "(< 12 (FOL.COMPILER.COLLECTION-FUNCTIONS:COUNT ACC))"
                vec-code-str :test #'string-equal))
    ;; Empty inits: still converted (world-guarded transient fast path), but
    ;; with NO size check -- the fast path must be reachable.
    (is (search "TRANSIENT" empty-dict-str :test #'string-equal))
    (is (null (search "FOL.COMPILER.COLLECTION-FUNCTIONS:COUNT" empty-dict-str
                      :test #'string-equal)))
    (is (search "TRANSIENT" empty-vec-str :test #'string-equal))
    (is (null (search "FOL.COMPILER.COLLECTION-FUNCTIONS:COUNT" empty-vec-str
                      :test #'string-equal)))
    ;; Sets have no size threshold: a converted set loop emits no count check.
    (let* ((set-form '(loop (acc (set) i 0) (if (< i 10) (recur (conj acc i) (inc i)) acc)))
           (set-code-str (write-to-string (fol.compiler:compilation-result-code (fol.compiler:compile-form set-form)))))
      (is (null (search "FOL.COMPILER.COLLECTION-FUNCTIONS:COUNT" set-code-str))))))


;;; ============================================================================
;;; Helper inlining ("the DVI gap")
;;; ============================================================================

(test transient-loop-helper-inlining
  "The DVI shape: a loop's recur calls a user-defined helper that itself
   linearly threads its accumulator through a real update chain (assoc/get).
   Once the helper is compiled with *transient-loops* t (registering it as
   inlinable), the loop converts through it -- helper calls were previously
   an unconditional disqualifier."
  (let ((helper-form (fol-form '(defn tc-add-item #(cart price)
                                 (fol.compiler.collection-functions:assoc
                                  cart price
                                  (fol.compiler.arithmetic-functions:inc
                                   (fol.compiler.collection-functions:get cart price 0))))))
        (loop-form '(loop (acc (dict) i 0)
                      (if (< i 20)
                          (recur (tc-add-item acc i) (+ i 1))
                          acc))))
    ;; Plain (unoptimized) baseline for correctness comparison.
    (let ((fol.compiler.escape-analysis:*transient-loops* nil))
      (eval (fol.compiler:compilation-result-code (fol.compiler:compile-form helper-form))))
    (let ((plain (eval (fol.compiler:compilation-result-code (fol.compiler:compile-form loop-form)))))
      (let ((fol.compiler.escape-analysis:*transient-loops* t))
        ;; Registers tc-add-item as inlinable; must precede compiling the loop.
        (eval (fol.compiler:compilation-result-code (fol.compiler:compile-form helper-form)))
        (let* ((result (fol.compiler:compile-form loop-form))
               (code-str (write-to-string (fol.compiler:compilation-result-code result)))
               (opt (eval (fol.compiler:compilation-result-code result))))
          ;; The loop DOES convert -- proof the helper was inlined, not
          ;; conservatively rejected as an unknown call.
          (is (search "TRANSIENT" code-str :test #'string-equal))
          (is (typep opt 'fol.compiler.collections:<dict>))
          (is (= (fol.compiler.collections:collection-size plain)
                 (fol.compiler.collections:collection-size opt)))
          (is (loop for i below 20
                    always (eql (fol.compiler.collection-functions:get plain i)
                                (fol.compiler.collection-functions:get opt i))))
          ;; The world-guard depends on the helper's own name, not just
          ;; ASSOC: redefining tc-add-item must be able to invalidate this
          ;; region even though ASSOC itself was never touched.
          (is (search "TC-ADD-ITEM" code-str :test #'string-equal)))))))

(test transient-loop-helper-inlining-escaping-not-inlined
  "A helper that passes its accumulator parameter to a genuinely unknown
   function (no summary, not itself inlinable) is never registered: that
   use is an escape, not a sanctioned read or update-chain link, so the
   loop must NOT convert."
  (let ((helper-form (fol-form '(defn tc-add-item-escapes #(cart price)
                                 (fol.compiler.collection-functions:assoc
                                  cart price
                                  (tc-totally-unknown-fn cart)))))
        (loop-form '(loop (acc (dict) i 0)
                      (if (< i 20)
                          (recur (tc-add-item-escapes acc i) (+ i 1))
                          acc))))
    (let ((fol.compiler.escape-analysis:*transient-loops* t))
      (eval (fol.compiler:compilation-result-code (fol.compiler:compile-form helper-form)))
      (let* ((result (fol.compiler:compile-form loop-form))
             (code-str (write-to-string (fol.compiler:compilation-result-code result))))
        (is (null (search "TRANSIENT" code-str :test #'string-equal)))))))

;;; ============================================================================
;;; Tier-2-summarized constructor-call loop inits (§sec:formal's "constructor
;;; call summarized as returning an unaliased root" clause)
;;; ============================================================================

(test transient-loop-tier2-fresh-constructor-init
  "A loop initialized from a user-defined 0-ary constructor call, not a
   literal: TRANSIENT-ELIGIBLE-INIT-P previously required a literal
   ([..]/{..}/#{..}) init, so (loop [acc (tc-make-empty-cart) i 0] ...) was
   never eligible for conversion regardless of how clean its update chain
   was. Tier-2 inference gives TC-MAKE-EMPTY-CART a RETURNS-FRESH-P summary
   (it has no parameters, so no parameter effect can ever fail freshness)
   and a RETURNS-KIND of :DICT (its tail form is a direct DICT call), both
   of which TRANSIENT-ELIGIBLE-INIT-P/INIT-SUPPORTS-P now consult -- the
   loop converts.

   Both forms are COMPILED before either is EVALUATED, mirroring a real
   compile-file/load: the world-guard's NOTE-REDEFINITION (called by the
   emitted code for any defn, including its very first definition) clears
   the constructor's Tier-2 cache entry as soon as its code runs, since a
   redefinition and a first definition look identical to that mechanism.
   In a real file, every form compiles before any of them load, so this
   never matters; interleaving compile-form with an immediate EVAL (as
   other tests in this file do, harmlessly, since they don't depend on
   *INFERRED-SUMMARIES*) would clear the summary before the loop's
   compilation ever consulted it."
  (let ((ctor-form (fol-form '(defn tc-make-empty-cart #()
                                (fol.compiler.collection-functions:dict))))
        (loop-form '(loop (acc (tc-make-empty-cart) i 0)
                      (if (< i 20)
                          (recur (fol.compiler.collection-functions:assoc acc i i) (+ i 1))
                          acc))))
    (let ((fol.compiler.escape-analysis:*transient-loops* nil))
      (eval (fol.compiler:compilation-result-code (fol.compiler:compile-form ctor-form))))
    (let ((plain (eval (fol.compiler:compilation-result-code (fol.compiler:compile-form loop-form)))))
      (let* ((fol.compiler.escape-analysis:*transient-loops* t)
             ;; Compile BOTH forms (Tier-2 inference caches the constructor's
             ;; summary as a side effect of compiling it) before evaluating
             ;; either.
             (ctor-result (fol.compiler:compile-form ctor-form))
             (loop-result (fol.compiler:compile-form loop-form))
             (code-str (write-to-string (fol.compiler:compilation-result-code loop-result))))
        (eval (fol.compiler:compilation-result-code ctor-result))
        (let ((opt (eval (fol.compiler:compilation-result-code loop-result))))
          ;; The loop DOES convert -- proof the constructor's summary was
          ;; consulted, not conservatively rejected as an unknown init.
          (is (search "TRANSIENT" code-str :test #'string-equal))
          (is (typep opt 'fol.compiler.collections:<dict>))
          (is (= (fol.compiler.collections:collection-size plain)
                 (fol.compiler.collections:collection-size opt)))
          (is (loop for i below 20
                    always (eql (fol.compiler.collection-functions:get plain i)
                                (fol.compiler.collection-functions:get opt i))))
          ;; The world-guard depends on the constructor's own name: redefining
          ;; tc-make-empty-cart to return something aliased (or a different
          ;; kind) must be able to invalidate this region.
          (is (search "TC-MAKE-EMPTY-CART" code-str :test #'string-equal)))))))

(test transient-loop-fresh-constructor-summary-absent-not-converted
  "The SAME loop shape, but with the constructor's inferred summary absent
   when the loop is compiled: without Tier-2, TRANSIENT-ELIGIBLE-INIT-P sees
   a bare call node with no known freshness, so the init isn't eligible and
   the loop must NOT convert. Isolates Tier-2's causal contribution -- same
   source, only the summary's presence differs.

   Two independent ways the summary ends up absent, both exercised here: (1)
   EVALuating the constructor's compiled code (rather than just compiling
   it) runs NOTE-REDEFINITION, which clears any inferred summary for that
   name -- a first definition looks identical to a redefinition to that
   mechanism, so the natural compile+eval order used elsewhere in this file
   already clears it; (2) CLEAR-INFERRED-SUMMARY makes that outcome
   explicit and deterministic regardless of (1)."
  (let ((ctor-form (fol-form '(defn tc-make-empty-cart-2 #()
                                (fol.compiler.collection-functions:dict))))
        (loop-form '(loop (acc (tc-make-empty-cart-2) i 0)
                      (if (< i 20)
                          (recur (fol.compiler.collection-functions:assoc acc i i) (+ i 1))
                          acc))))
    (let ((fol.compiler.escape-analysis:*transient-loops* t))
      (eval (fol.compiler:compilation-result-code (fol.compiler:compile-form ctor-form)))
      (fol.compiler.summaries:clear-inferred-summary
       (find-symbol "TC-MAKE-EMPTY-CART-2" :fol.compiler.tests))
      (let* ((result (fol.compiler:compile-form loop-form))
             (code-str (write-to-string (fol.compiler:compilation-result-code result))))
        (is (null (search "TRANSIENT" code-str :test #'string-equal)))))))

(test transient-loop-fresh-constructor-unknown-kind-not-converted
  "A constructor proven RETURNS-FRESH-P but whose RETURNS-KIND is unknown
   (its tail form is a call to something other than a direct DICT/VECTOR/SET
   constructor -- here IDENTITY wrapping a dict) must NOT be treated as
   eligible: INIT-SUPPORTS-P has no way to pick the right op-gate, and
   guessing would be unsound, not merely imprecise. The loop must NOT
   convert, confirming the analysis declines rather than guesses.

   Both forms are compiled before either is evaluated (see
   TRANSIENT-LOOP-TIER2-FRESH-CONSTRUCTOR-INIT's docstring): otherwise
   evaluating the constructor would clear its summary via
   NOTE-REDEFINITION before the loop compiles, and this test would pass
   for the wrong reason -- no summary at all, rather than a summary with
   freshness proven but kind unknown."
  (let ((ctor-form (fol-form '(defn tc-make-mystery-cart #()
                                (fol.compiler.functional:identity
                                 (fol.compiler.collection-functions:dict)))))
        (loop-form '(loop (acc (tc-make-mystery-cart) i 0)
                      (if (< i 20)
                          (recur (fol.compiler.collection-functions:assoc acc i i) (+ i 1))
                          acc))))
    (let ((fol.compiler.escape-analysis:*transient-loops* t))
      (let* ((ctor-result (fol.compiler:compile-form ctor-form))
             (loop-result (fol.compiler:compile-form loop-form))
             (code-str (write-to-string (fol.compiler:compilation-result-code loop-result))))
        (eval (fol.compiler:compilation-result-code ctor-result))
        (is (null (search "TRANSIENT" code-str :test #'string-equal)))))))

;;; ============================================================================
;;; Independent accumulators, one via a nested reduce (chain-ops leak)
;;; ============================================================================

(test transient-loop-independent-accumulators-one-via-nested-reduce
  "Two independent accumulators in one loop -- a vector QUEUE grown through a
   nested reduce placed directly in the recur position, and a dict RANKS
   grown by a plain direct assoc -- must both convert.

   Regression test for a bug in REDUCE-CHAIN-KIND: classifying RANKS's uses
   walks over QUEUE's reduce as an unrelated node; validating that reduce's
   lambda (%LINEAR-REDUCE-LAMBDA's call to REDUCE-ACC-QUALIFIED-P) has the
   side effect of recording its spine op (CONJ) via %NOTE-CHAIN-OP, and
   this used to happen unconditionally -- before confirming the reduce's
   init actually roots at RANKS, the accumulator currently being classified.
   That leaked CONJ into RANKS's *CHAIN-OPS*, and INIT-SUPPORTS-P rejects a
   dict whose chain-ops include an op outside {ASSOC, DISSOC}, so RANKS
   never qualified even though its own chain (an ASSOC) was clean. Checking
   whether the reduce's init roots at the name being classified before
   validating the lambda (§sec:discussion's corrected DVI paragraph turns on
   this same kind of ordering) avoids the leak."
  (let ((src "(defn tc-indep-accs [] (loop [queue [0] ranks {} i 0]
                (if (< i (count queue))
                  (bind [node (get queue i)
                         kids (get {0 [1 2] 1 [] 2 []} node [])]
                    (recur (reduce (fn [acc k] (conj acc k)) queue kids)
                           (assoc ranks node i)
                           (inc i)))
                  ranks)))"))
    (let ((before (conversion-counts)))
      (compile-eval-fol-source src)
      (let* ((plain-result (funcall (fdefinition (find-symbol "TC-INDEP-ACCS" :fol.core))))
             (opt (progn (compile-eval-fol-source src :transient t)
                         (funcall (fdefinition (find-symbol "TC-INDEP-ACCS" :fol.core))))))
        (is (= (fol.compiler.collections:collection-size plain-result)
               (fol.compiler.collections:collection-size opt)))
        (is (loop for k below 3
                  always (eql (fol.compiler.collection-functions:get plain-result k)
                              (fol.compiler.collection-functions:get opt k))))
        ;; One loop, two params converted (queue AND ranks), not one.
        (is (equal (list (+ (first before) 1) (+ (second before) 2) (third before))
                   (conversion-counts)))))))

;;; ============================================================================
;;; Run the suite
;;; ============================================================================

(fiveam:run! 'transient-conversion-suite)
