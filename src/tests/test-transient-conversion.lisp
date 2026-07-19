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

(defun compile-eval-fol-source-multi (src &key transient)
  "Like COMPILE-EVAL-FOL-SOURCE, but SRC may contain multiple top-level
   forms (e.g. a defclass, a defmethod, and one or more defns), which
   COMPILE-STRING (and hence COMPILE-EVAL-FOL-SOURCE) can't handle since it
   reads only one form. Returns the value of the LAST form evaluated."
  (let ((fol.compiler.escape-analysis:*transient-loops* transient)
        (*package* (find-package :fol.core))
        (*readtable* fol.compiler.reader:*fol-readtable*)
        (result nil))
    (with-input-from-string (in src)
      (loop for f = (read in nil :eof) until (eq f :eof)
            do (setf result (eval (fol.compiler:compilation-result-code
                                   (fol.compiler:compile-form f))))))
    result))

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
  ;; RESET-WORLD only clears world.lisp-level state (the redefinitions-noted
  ;; counter, region deps), not compiler.lisp's *GLOBAL-TYPE-INFO* class
  ;; registry -- this file's own trailing (fiveam:run! ...) call means this
  ;; test's suite can execute more than once in the same image (once at file
  ;; load, once via the aggregate RUN-COMPILER-TESTS), so without this the
  ;; second run would see <WORLD-TEST-CLASS> as already-registered and (now
  ;; correctly) count its DEFCLASS as a real redefinition.
  (remhash (intern "<WORLD-TEST-CLASS>" :fol.core) fol.compiler::*global-type-info*)
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
;;; Chain-through-bind: a named temporary hiding a chain (simple case of
;;; the Discussion section's "chain-through-bind extension" future work)
;;; ============================================================================

(test transient-loop-chain-through-single-binding-bind
  "(bind [new-acc (chain-expr acc ...)] (recur new-acc ...)): NAME's only
   appearance is inside the bind's init (an ordinary, non-tail call
   argument -- previously always :escape-call), and the recur references a
   *different* symbol the walk never ties back to NAME. With exactly one
   binding and the bind's sole body form the recur that consumes it
   exactly once, this is unambiguously safe to treat as if the chain
   expression had been written at the recur site directly -- the loop must
   now convert."
  (let ((helper-form (fol-form '(defn tc-cb-helper #(cart price)
                                 (fol.compiler.collection-functions:assoc
                                  cart price
                                  (fol.compiler.arithmetic-functions:inc
                                   (fol.compiler.collection-functions:get cart price 0))))))
        (loop-form '(loop (acc (dict) i 0)
                      (if (< i 20)
                          (bind (new-acc (tc-cb-helper acc i))
                            (recur new-acc (+ i 1)))
                          acc))))
    (let ((fol.compiler.escape-analysis:*transient-loops* nil))
      (eval (fol.compiler:compilation-result-code (fol.compiler:compile-form helper-form))))
    (let ((plain (eval (fol.compiler:compilation-result-code (fol.compiler:compile-form loop-form)))))
      (let ((fol.compiler.escape-analysis:*transient-loops* t))
        (eval (fol.compiler:compilation-result-code (fol.compiler:compile-form helper-form)))
        (let* ((result (fol.compiler:compile-form loop-form))
               (code-str (write-to-string (fol.compiler:compilation-result-code result)))
               (opt (eval (fol.compiler:compilation-result-code result))))
          (is (search "TRANSIENT" code-str :test #'string-equal))
          (is (typep opt 'fol.compiler.collections:<dict>))
          (is (= (fol.compiler.collections:collection-size plain)
                 (fol.compiler.collections:collection-size opt)))
          (is (loop for i below 20
                    always (eql (fol.compiler.collection-functions:get plain i)
                                (fol.compiler.collection-functions:get opt i)))))))))

(test transient-loop-chain-through-bind-multi-binding-unrelated-sibling-converts
  "The same shape but with a SECOND, wholly UNRELATED binding in the same
   bind (an intermediate local computed alongside the chain-producing one,
   never referencing the running alias at all) now converts.
   %VALIDATE-READ-TOLERANT-CHAIN (escape-analysis.lisp) does not fold the
   BIND away the way %FOLD-LET-CHAIN's strict, single/multi-binding-chain
   path does -- it rebuilds the BIND with every original binding kept in
   its original position and evaluation order, rewriting only the
   chain-extending one. Nothing is dropped or reordered, so the concern
   that disqualified this shape before (silently dropping the sibling
   binding's evaluation once the BIND was eliminated by folding) does not
   apply here. Correctness verified directly against the unconverted
   baseline, not just that conversion happened."
  (let ((helper-form (fol-form '(defn tc-cb-helper2 #(cart price)
                                 (fol.compiler.collection-functions:assoc cart price price))))
        (loop-form '(loop (acc (dict) i 0)
                      (if (< i 20)
                          (bind (new-acc (tc-cb-helper2 acc i)
                                 unused  i)
                            (recur new-acc (+ i 1)))
                          acc))))
    (let ((fol.compiler.escape-analysis:*transient-loops* nil))
      (eval (fol.compiler:compilation-result-code (fol.compiler:compile-form helper-form))))
    (let ((plain (eval (fol.compiler:compilation-result-code (fol.compiler:compile-form loop-form)))))
      (let ((fol.compiler.escape-analysis:*transient-loops* t))
        (eval (fol.compiler:compilation-result-code (fol.compiler:compile-form helper-form)))
        (let* ((result (fol.compiler:compile-form loop-form))
               (code-str (write-to-string (fol.compiler:compilation-result-code result)))
               (opt (eval (fol.compiler:compilation-result-code result))))
          (is (search "TRANSIENT" code-str :test #'string-equal))
          (is (= (fol.compiler.collections:collection-size plain)
                 (fol.compiler.collections:collection-size opt)))
          (is (loop for i below 20
                    always (eql (fol.compiler.collection-functions:get plain i)
                                (fol.compiler.collection-functions:get opt i)))))))))

(test transient-loop-chain-through-bind-var-used-twice-unaffected
  "The bind-bound variable used more than once (once as the recur
   argument, once elsewhere) must not be simplified either: substituting
   the chain expression in would duplicate it. Falls back to ordinary
   classification, which disqualifies via the second, non-chain use."
  (let ((helper-form (fol-form '(defn tc-cb-helper3 #(cart price)
                                 (fol.compiler.collection-functions:assoc cart price price))))
        (loop-form '(loop (acc (dict) i 0)
                      (if (< i 20)
                          (bind (new-acc (tc-cb-helper3 acc i))
                            (recur new-acc
                                   (fol.compiler.collection-functions:count new-acc)))
                          acc))))
    (let ((fol.compiler.escape-analysis:*transient-loops* t))
      (eval (fol.compiler:compilation-result-code (fol.compiler:compile-form helper-form)))
      (let* ((result (fol.compiler:compile-form loop-form))
             (code-str (write-to-string (fol.compiler:compilation-result-code result))))
        (is (null (search "TRANSIENT" code-str :test #'string-equal)))))))

(test transient-loop-chain-through-bind-multi-binding-chain-of-chains
  "A genuine chain-of-chains: (bind [c1 (chain1 acc x) c2 (chain2 c1 y)]
   (recur c2 ...)) -- EVERY binding extends the running alias (first NAME,
   then each binding's own var), so the whole bind folds into one
   expression rooted at NAME and converts, unlike the two-binding
   unaffected test above where the second binding does not extend the
   chain at all."
  (let ((loop-form '(loop (acc (dict) i 0)
                      (if (< i 20)
                          (bind (c1 (fol.compiler.collection-functions:assoc acc i i)
                                 c2 (fol.compiler.collection-functions:assoc c1 :extra i))
                            (recur c2 (+ i 1)))
                          acc))))
    (let ((plain (compile-eval-fol loop-form))
          (opt (compile-eval-fol loop-form :transient t)))
      (let* ((result (fol.compiler:compile-form loop-form))
             (code-str nil))
        (let ((fol.compiler.escape-analysis:*transient-loops* t))
          (setf result (fol.compiler:compile-form loop-form))
          (setf code-str (write-to-string (fol.compiler:compilation-result-code result))))
        (is (search "TRANSIENT" code-str :test #'string-equal))
        (is (typep opt 'fol.compiler.collections:<dict>))
        (is (= (fol.compiler.collections:collection-size plain)
               (fol.compiler.collections:collection-size opt)))
        (is (loop for i below 20
                  always (eql (fol.compiler.collection-functions:get plain i)
                              (fol.compiler.collection-functions:get opt i))))
        (is (eql (fol.compiler.collection-functions:get plain :extra)
                 (fol.compiler.collection-functions:get opt :extra)))))))

(test transient-loop-chain-through-bind-multi-binding-alias-used-twice-unaffected
  "An intermediate alias referenced more than once across the chain (once
   to extend it, once elsewhere) must not be folded: substituting it in
   would duplicate the first link's expression. Falls back to ordinary
   classification, which disqualifies since C1's second reference is a
   non-chain use the walk cannot connect back to NAME."
  (let ((loop-form '(loop (acc (dict) i 0)
                      (if (< i 20)
                          (bind (c1 (fol.compiler.collection-functions:assoc acc i i)
                                 c2 (fol.compiler.collection-functions:assoc c1 :extra
                                     (fol.compiler.collection-functions:count c1)))
                            (recur c2 (+ i 1)))
                          acc))))
    (let ((fol.compiler.escape-analysis:*transient-loops* t))
      (let* ((result (fol.compiler:compile-form loop-form))
             (code-str (write-to-string (fol.compiler:compilation-result-code result))))
        (is (null (search "TRANSIENT" code-str :test #'string-equal)))))))

(test transient-loop-chain-through-bind-multi-binding-intervening-read-converts
  "DVI's actual shape, in miniature: an intermediate binding that READS the
   running alias through a helper (not itself a chain extension) sitting
   between two chain-extending bindings. This is the fourth obstacle
   closed after Approach A: %VALIDATE-READ-TOLERANT-CHAIN (escape-
   analysis.lisp) classifies TC-CB-READER's binding as a safe read rather
   than a disqualifying use, via %SAFE-READ-OF-P/CALL-ARG-READ-P proving
   (through TC-CB-READER's Tier-2-inferred summary) that its CART
   parameter is only read (a keyword-accessor GET), never retained. The
   BIND is rewritten in place -- C1's and C2's bindings get their chain
   ops rewritten to the transient form, R's stays completely untouched --
   rather than folded away, so the read's relative evaluation order to the
   chain step it depends on is preserved exactly, unlike substitution,
   which the paper's Discussion previously argued could reorder it.

   Compiles the helper and the loop fully before evaluating either
   (mirroring TRANSIENT-LOOP-TIER2-FRESH-CONSTRUCTOR-INIT's documented
   pattern): interleaving compile with an immediate EVAL would trigger
   NOTE-REDEFINITION on TC-CB-READER's very first definition, clearing its
   just-cached Tier-2 summary before the loop's own compilation ever
   consults it."
  (let ((helper-form (fol-form '(defn tc-cb-reader #(cart)
                                 (fol.compiler.collection-functions:get cart 0))))
        (loop-form '(loop (acc (dict) i 0)
                      (if (< i 20)
                          (bind (c1 (fol.compiler.collection-functions:assoc acc i i)
                                 r  (tc-cb-reader c1)
                                 c2 (fol.compiler.collection-functions:assoc c1 :extra r))
                            (recur c2 (+ i 1)))
                          acc))))
    (let ((fol.compiler.escape-analysis:*transient-loops* nil))
      (eval (fol.compiler:compilation-result-code (fol.compiler:compile-form helper-form))))
    (let ((plain (eval (fol.compiler:compilation-result-code (fol.compiler:compile-form loop-form)))))
      (let ((fol.compiler.escape-analysis:*transient-loops* t))
        (let* ((helper-result (fol.compiler:compile-form helper-form))
               (loop-result (fol.compiler:compile-form loop-form))
               (code-str (write-to-string (fol.compiler:compilation-result-code loop-result))))
          (eval (fol.compiler:compilation-result-code helper-result))
          (let ((opt (eval (fol.compiler:compilation-result-code loop-result))))
            (is (search "TRANSIENT" code-str :test #'string-equal))
            (is (= (fol.compiler.collections:collection-size plain)
                   (fol.compiler.collections:collection-size opt)))
            (is (loop for i below 20
                      always (eql (fol.compiler.collection-functions:get plain i)
                                  (fol.compiler.collection-functions:get opt i))))
            (is (eql (fol.compiler.collection-functions:get plain :extra)
                     (fol.compiler.collection-functions:get opt :extra)))))))))

;;; ============================================================================
;;; CLOS-object (<persistent-object>) accumulators
;;; ============================================================================
;;; (make 'X), X a <persistent-object> subclass, as a loop init: closes the
;;; second of DVI's two remaining obstacles (§sec:discussion) -- a
;;; representation for arbitrary CLOS objects, using the existing but
;;; previously-unreached %TRANSIENT-OWNER/%TRANSIENT-BUFFER mechanism in
;;; persistence.lisp. ASSOC is the only spine op (no dissoc/conj/disj
;;; analogue for CLOS slots); reads go through the same GET method
;;; persistent-objects already have (transients.lisp adds no special
;;; read path for this representation, unlike dicts/vectors/sets, since
;;; plain SLOT-VALUE already sees in-place mutation once owned).

(test transient-loop-persistent-object-correctness
  "A loop accumulating into a plain <persistent-object> instance via ASSOC,
   with no method-combination hazard on MAKE or ASSOC for this class,
   converts, and produces results identical to the unconverted baseline."
  (let ((src "(defclass <tc-po-basket> []
                [[items :initarg :items :initform []]])
              (defn tc-po-add [b price]
                (fol.compiler.collection-functions:assoc
                 b :items
                 (fol.compiler.collection-functions:conj
                  (fol.compiler.collection-functions:get b :items) price)))
              (defn tc-po-run [n]
                (loop [i 0 b (make '<tc-po-basket>)]
                  (if (< i n)
                    (recur (inc i) (tc-po-add b i))
                    b)))"))
    (let ((before (conversion-counts)))
      (compile-eval-fol-source-multi src)
      (let* ((plain (funcall (fdefinition (find-symbol "TC-PO-RUN" :fol.core)) 20))
             (opt (progn (compile-eval-fol-source-multi src :transient t)
                         (funcall (fdefinition (find-symbol "TC-PO-RUN" :fol.core)) 20))))
        (is (equal (fol.compiler.collections:collection-seq
                    (fol.compiler.collection-functions:get plain :items))
                   (fol.compiler.collections:collection-seq
                    (fol.compiler.collection-functions:get opt :items))))
        ;; One loop, one param converted.
        (is (equal (list (+ (first before) 1) (+ (second before) 1) (third before))
                   (conversion-counts)))))))

(test transient-loop-persistent-object-around-now-converts
  "Approach A: a :around method on ASSOC -- DVI's own shape, guard-refined
   and all (the (slot (= :items)) guard alongside the (cart <class>) type
   specializer) -- no longer blocks conversion. ASSOC's own PRIMARY method
   for <persistent-object> (collection-functions.lisp) already calls
   UPDATE-SLOT, whose in-place fast path (persistence.lisp) already
   branches on %TRANSIENT-OWNER regardless of caller -- it's the general
   update primitive, not something built only for the transient bypass.
   INIT-SUPPORTS-P's second return value (escape-analysis.lisp) now signals
   this accumulator needs 'dispatch-through' mode, and the rewriter
   (*DISPATCH-THROUGH-NAMES*) routes its spine-op calls through the REAL
   ASSOC generic instead of the ASSOC! bypass, so the :around still fires.

   :_TOTAL's initform is a sentinel, never NIL on its own -- if the
   :around had been silently skipped (the old, pre-Approach-A hazard this
   test used to exist to catch, back when it asserted refusal), :_TOTAL
   would still read as the sentinel after conversion. It doesn't: this is
   direct proof real dispatch ran on the converted path, not just that
   conversion happened.

   Compiled as ordinary FOL source (defmethod assoc :around [...] ...),
   the same path DVI's own benchmark file goes through, now that two
   pre-existing compiler bugs this test used to work around are fixed:
   (1) COMPILE-DEFMETHOD-CLAUSES's fixed-arity path used to collapse EVERY
   parameter's CLOS specializer to T as soon as any one parameter in the
   clause needed a non-CLOS-representable guard check, which would have
   made TIER1-OP-CUSTOMIZED-P's MOP-based check see this method as
   applying to every representation rather than just this class; (2)
   registering a simple :around method used to corrupt later, unrelated
   call sites sharing the same generic function name with a malformed
   (locally (declare (optimize (inline 3))) ...) wrapper, which is what
   previously forced this test onto a raw CL DEFMETHOD instead of real FOL
   source. See COMPILE-DEFMETHOD-GUARD-PLUS-TYPE-KEEPS-CLOS-SPECIALIZER and
   COMPILE-DEFMETHOD-AROUND-REGISTRATION-DOES-NOT-CORRUPT-LATER-CALLS in
   test-oop.lisp for focused regression tests of each bug.

   Note: DVI's own benchmark file still does not convert even with this
   fix -- its actual accumulation loop threads the cart through a BIND
   chain (c1/t1/c2/reads) where t1 = (cart-total c1) READS c1 rather than
   extending it, which chain-through-bind's %FOLD-LET-CHAIN still declines
   (a separate, pre-existing scope boundary, not touched by this test)."
  (let ((class-src "(defclass <tc-po-cached> []
                       [[items  :initarg :items  :initform []]
                        [_total :initarg :_total :initform :tc-untouched]])
                     (defn tc-po-cached-add [g price]
                       (fol.compiler.collection-functions:assoc
                        g :items
                        (fol.compiler.collection-functions:conj
                         (fol.compiler.collection-functions:get g :items) price)))
                     (defn tc-po-cached-run [n]
                       (loop [i 0 g (make '<tc-po-cached>)]
                         (if (< i n)
                           (recur (inc i) (tc-po-cached-add g i))
                           g)))")
        (method-src "(defmethod fol.compiler.collection-functions:assoc :around
                       [(g <tc-po-cached>) (slot (= :items)) val]
                       (fol.compiler.collection-functions:assoc
                        (call-next-method) :_total nil))"))
    (compile-eval-fol-source-multi class-src)
    (let ((class (find-class (intern "<TC-PO-CACHED>" :fol.core))))
      (compile-eval-fol-source-multi method-src)
      (unwind-protect
          (let ((before (conversion-counts))
                (plain (funcall (fdefinition (find-symbol "TC-PO-CACHED-RUN" :fol.core)) 20)))
            (compile-eval-fol-source-multi class-src :transient t)
            (let ((opt (funcall (fdefinition (find-symbol "TC-PO-CACHED-RUN" :fol.core)) 20)))
              ;; Converted, not refused -- this is the behavior change.
              (is (equal (list (+ (first before) 1) (+ (second before) 1) (third before))
                         (conversion-counts)))
              ;; The :around fired on both paths: :_total moved off the
              ;; sentinel to nil, proof real dispatch ran on the converted
              ;; path too, not the bypass.
              (is (eq :tc-untouched (fol.compiler.collection-functions:get
                                     (fol.compiler.primitives:make (intern "<TC-PO-CACHED>" :fol.core))
                                     :_total)))
              (is (null (fol.compiler.collection-functions:get plain :_total)))
              (is (null (fol.compiler.collection-functions:get opt :_total)))
              (is (equal (fol.compiler.collections:collection-seq
                          (fol.compiler.collection-functions:get plain :items))
                         (fol.compiler.collections:collection-seq
                          (fol.compiler.collection-functions:get opt :items))))))
        (let ((m (find-method #'fol.compiler.collection-functions:assoc
                               '(:around) (list class t t) nil)))
          (when m (remove-method #'fol.compiler.collection-functions:assoc m)))))))

(test transient-loop-persistent-object-make-hazard-still-refused
  "Approach A's exception is narrow: it applies only to ASSOC. A :around
   method on MAKE for this class must still refuse conversion outright, the
   same as before -- INIT-SUPPORTS-P's persistent-object clause checks
   every non-ASSOC used op (MAKE included) via the ordinary, unexceptioned
   TIER1-OP-CUSTOMIZED-P, so a hijacked constructor can't silently hand
   back something other than a fresh instance regardless of what ASSOC
   itself allows.

   Writing this test surfaced a real, separate, pre-existing gap: MAKE's
   OWN dispatch parameter is always an EQL-specializer on the class-name
   symbol -- (defmethod make ((class (eql '<name>)) &rest args)) is how
   EVERY class's constructor method, including this test's hostile
   :around, selects a representation -- and %CLASS-APPLICABLE-P
   unconditionally skipped ALL EQL-specializers (a deliberate, documented
   choice for the general case: they usually match one object's identity,
   not a whole representation). That made TIER1-OP-CUSTOMIZED-P a silent
   no-op for MAKE specifically, contradicting this file's and the paper's
   existing claim that MAKE is checked. Fixed alongside this test by
   giving %CLASS-APPLICABLE-P an optional KIND parameter so it also
   recognizes an EQL-specializer whose object is exactly KIND's own
   class-name symbol -- a narrow, well-defined exception, not a general
   EQL-specializer handler."
  (let ((class-src "(defclass <tc-po-make-guarded> []
                       [[items :initarg :items :initform []]])
                     (defn tc-po-make-guarded-add [g price]
                       (fol.compiler.collection-functions:assoc
                        g :items
                        (fol.compiler.collection-functions:conj
                         (fol.compiler.collection-functions:get g :items) price)))
                     (defn tc-po-make-guarded-run [n]
                       (loop [i 0 g (make '<tc-po-make-guarded>)]
                         (if (< i n)
                           (recur (inc i) (tc-po-make-guarded-add g i))
                           g)))")
        (class-name nil))
    (compile-eval-fol-source-multi class-src)
    (setf class-name (intern "<TC-PO-MAKE-GUARDED>" :fol.core))
    (eval `(defmethod fol.compiler.primitives:make :around ((c (eql ',class-name)) &rest args)
             (apply #'call-next-method c args)))
    (unwind-protect
        (let ((before (conversion-counts)))
          (compile-eval-fol-source-multi class-src :transient t)
          (is (equal before (conversion-counts))))
      (let ((m (find-if (lambda (m)
                           (let ((s (first (sb-mop:method-specializers m))))
                             (and (typep s 'sb-mop:eql-specializer)
                                  (eql (sb-mop:eql-specializer-object s) class-name))))
                         (sb-mop:generic-function-methods #'fol.compiler.primitives:make))))
        (when m (remove-method #'fol.compiler.primitives:make m))))))

(test transient-loop-persistent-object-make-with-initargs-not-fresh
  "(make 'X val1 val2 ...) -- a constructor call passing initargs, not the
   bare 0-ary (make 'X) -- is deliberately outside %PERSISTENT-OBJECT-MAKE-
   CLASS's narrow recognition (it would need its own aliasing analysis of
   the initarg values), so the loop must not convert."
  (let ((src "(defclass <tc-po-seeded> []
                [[items :initarg :items :initform []]])
              (defn tc-po-seeded-add [b price]
                (fol.compiler.collection-functions:assoc
                 b :items
                 (fol.compiler.collection-functions:conj
                  (fol.compiler.collection-functions:get b :items) price)))
              (defn tc-po-seeded-run [n]
                (loop [i 0 b (make '<tc-po-seeded> :items [])]
                  (if (< i n)
                    (recur (inc i) (tc-po-seeded-add b i))
                    b)))"))
    (let ((before (conversion-counts)))
      (compile-eval-fol-source-multi src :transient t)
      (is (equal before (conversion-counts))))))

(test transient-loop-persistent-object-dispatch-through-with-read-tolerant-chain
  "DVI's actual full shape, combining both mechanisms it needs at once: a
   :around-customized persistent-object accumulator (Approach A's
   dispatch-through routing, §sec:discussion) threaded through a BIND chain
   with an intervening read (the fourth obstacle,
   %VALIDATE-READ-TOLERANT-CHAIN, tested in isolation above) -- add an
   item, read the (now-cleared) cached total through a helper, write the
   recomputed total back, exactly mirroring
   benchmarks/fol-code/derived-value-invalidation.fol's own RUN-BENCH.

   Neither mechanism alone is exercised by any other test: the persistent-
   object dispatch-through tests above use a plain RECUR chain (no BIND,
   no read), and the read-tolerant chain tests above use a plain <dict>
   (no :around, no dispatch-through). This is the first test where a
   chain-extending BIND binding's rewritten call must ALSO be checked
   against *DISPATCH-THROUGH-NAMES* using its OWN local alias (C1, not the
   loop's own qualified name) -- see TRY-READ-TOLERANT-CHAIN-RW's comment
   on why that lookup needs the locally-rebound extension.

   Compiles every form before evaluating any of it (mirroring DVI's own
   compile-file-free loading and TRANSIENT-LOOP-TIER2-FRESH-CONSTRUCTOR-
   INIT's documented reasoning): interleaving compile with an immediate
   EVAL, as COMPILE-EVAL-FOL-SOURCE-MULTI does, would trigger NOTE-
   REDEFINITION on the read helper's very first definition, clearing its
   just-cached Tier-2 summary before RUN's own compilation ever consults
   it -- exactly the failure mode discovered while first testing this
   against the real DVI benchmark file."
  (let* ((class-src "(defclass <tc-po-dvi> []
                        [[items  :initarg :items  :initform []]
                         [_total :initarg :_total :initform :tc-po-dvi-untouched]])")
         (method-src "(defmethod fol.compiler.collection-functions:assoc :around
                        [(g <tc-po-dvi>) (slot (= :items)) val]
                        (fol.compiler.collection-functions:assoc
                         (call-next-method) :_total nil))")
         (add-src "(defn tc-po-dvi-add [g price]
                     (fol.compiler.collection-functions:assoc
                      g :items
                      (fol.compiler.collection-functions:conj
                       (fol.compiler.collection-functions:get g :items) price)))")
         (total-src "(defn tc-po-dvi-total [g]
                       (if (nil? (fol.compiler.collection-functions:get g :_total))
                         (fol.compiler.seq-functions:reduce
                          fol.compiler.arithmetic-functions:+ 0
                          (fol.compiler.collection-functions:get g :items))
                         (fol.compiler.collection-functions:get g :_total)))")
         (run-src "(defn tc-po-dvi-run [n]
                     (loop [i 0 g (make '<tc-po-dvi>)]
                       (if (< i n)
                         (bind [c1 (tc-po-dvi-add g i)
                                t1 (tc-po-dvi-total c1)
                                c2 (fol.compiler.collection-functions:assoc c1 :_total t1)]
                           (recur (inc i) c2))
                         g)))")
         (class nil))
    (flet ((compile-all (transient)
             (let ((fol.compiler.escape-analysis:*transient-loops* transient)
                   (*package* (find-package :fol.core))
                   (*readtable* fol.compiler.reader:*fol-readtable*)
                   (deferred '()) (last-code-str nil))
               (dolist (src (list class-src method-src add-src total-src run-src))
                 (with-input-from-string (in src)
                   (loop for f = (read in nil :eof) until (eq f :eof)
                         do (let* ((result (fol.compiler:compile-form f))
                                   (code (fol.compiler:compilation-result-code result)))
                              (setf last-code-str (write-to-string code))
                              (if (and (consp f) (symbolp (car f))
                                       (string-equal (symbol-name (car f)) "DEFN"))
                                  (push code deferred)
                                  (eval code))))))
               (dolist (code (nreverse deferred)) (eval code))
               last-code-str)))
      (compile-all nil)
      (setf class (find-class (intern "<TC-PO-DVI>" :fol.core)))
      (let ((plain (funcall (fdefinition (find-symbol "TC-PO-DVI-RUN" :fol.core)) 20)))
        (unwind-protect
            (let ((before (conversion-counts))
                  (code-str (compile-all t)))
              (let ((opt (funcall (fdefinition (find-symbol "TC-PO-DVI-RUN" :fol.core)) 20)))
                (is (search "TRANSIENT" code-str :test #'string-equal))
                (is (equal (list (+ (first before) 1) (+ (second before) 1) (third before))
                           (conversion-counts)))
                ;; The :around fires on every :items write, clearing :_total
                ;; to nil; the NEXT binding (T1) then recomputes it and C2
                ;; writes the recomputed value back -- so the final
                ;; :_total is the last iteration's real total, not the
                ;; sentinel and not nil, on EITHER path. Equality between
                ;; the two paths (rather than a fixed value) is what proves
                ;; the :around fired identically on both, since a bypass
                ;; that skipped it would have left the sentinel in place.
                (is (not (eq :tc-po-dvi-untouched
                             (fol.compiler.collection-functions:get plain :_total))))
                (is (eql (fol.compiler.collection-functions:get plain :_total)
                         (fol.compiler.collection-functions:get opt :_total)))
                (is (equal (fol.compiler.collections:collection-seq
                            (fol.compiler.collection-functions:get plain :items))
                           (fol.compiler.collections:collection-seq
                            (fol.compiler.collection-functions:get opt :items))))))
          (let ((m (find-method #'fol.compiler.collection-functions:assoc
                                 '(:around) (list class t t) nil)))
            (when m (remove-method #'fol.compiler.collection-functions:assoc m))))))))

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

(test transient-loop-tier2-constructor-hijack-after-caching
  "A loop initialized via a Tier-2-summarized 0-ary HELPER whose tail
   position calls MAKE-<T> (not a direct (make 'X) at the loop's own init
   position -- %PERSISTENT-OBJECT-MAKE-CLASS alone would never see this,
   only %TIER2-CONSTRUCTOR-CLASS does) must still refuse conversion if MAKE
   gets hijacked for that class AFTER the helper's Tier-2 summary was
   already cached. *INFERRED-SUMMARIES* has no transitive invalidation
   (redefining MAKE doesn't touch the HELPER's own cached entry, only one
   literally named \"MAKE\"), so this is exactly the scenario FRESH-IF-
   CLASSES-TRUSTED exists for: freshness through a constructor call is
   never baked into a cached boolean, only ever re-verified live wherever
   it's consulted (TRANSIENT-ELIGIBLE-INIT-P).

   Sequence: define the class; compile (but deliberately never evaluate)
   the helper, caching its Tier-2 summary -- evaluating it would clear that
   very summary via NOTE-REDEFINITION, since a first definition looks
   identical to a redefinition to that mechanism (see TRANSIENT-LOOP-
   TIER2-FRESH-CONSTRUCTOR-INIT's docstring for the same gotcha; here it
   matters doubly, since the summary must survive across BOTH loop
   compilations, not just the first). Confirm a loop using the helper as
   init converts; THEN hijack MAKE for this class with a customizing
   :around method; confirm a freshly-compiled loop using the SAME
   (still-cached, untouched) helper summary does NOT convert -- proof the
   live re-check actually re-verifies trust, not a stale snapshot."
  (let* ((class-src "(defclass <tc-tier2-hijack> []
                        [[items :initarg :items :initform []]])")
         ;; CTOR-FORM and LOOP-FORM are read with *PACKAGE* bound to
         ;; :FOL.CORE (via the FOL readtable, for [] vector/<...> class-name
         ;; syntax) rather than quoted CL literals in this file's own
         ;; FOL.COMPILER.TESTS package: %TIER2-CONSTRUCTOR-CLASS interns the
         ;; MAKE-<T>-stripped class name into the OPERATOR symbol's OWN
         ;; package (mirroring INFER-TYPE-FROM-CONSTRUCTOR, compiler.lisp),
         ;; and LOOKUP-SUMMARY's *INFERRED-SUMMARIES* cache is EQ-keyed on
         ;; the DEFN's name symbol -- so the class (defined via
         ;; COMPILE-EVAL-FOL-SOURCE-MULTI, which reads into :FOL.CORE), the
         ;; ctor's own name, and the loop's call to it must all be the SAME
         ;; symbol objects, not merely same-named symbols in different
         ;; packages.
         (ctor-form (let ((*package* (find-package :fol.core))
                           (*readtable* fol.compiler.reader:*fol-readtable*))
                      (read-from-string "(defn tc-tier2-hijack-make [] (make-<tc-tier2-hijack>))")))
         (loop-form (let ((*package* (find-package :fol.core))
                           (*readtable* fol.compiler.reader:*fol-readtable*))
                      (read-from-string
                       "(loop [acc (tc-tier2-hijack-make) i 0]
                          (if (< i 20)
                            (recur (fol.compiler.collection-functions:assoc acc :items i) (+ i 1))
                            acc))")))
         (class-name nil))
    (compile-eval-fol-source-multi class-src)
    (setf class-name (intern "<TC-TIER2-HIJACK>" :fol.core))
    ;; Compile the ctor (caching its Tier-2 summary as a side effect) and
    ;; the first loop; deliberately never EVAL the ctor's code -- see the
    ;; docstring above.
    (let* ((fol.compiler.escape-analysis:*transient-loops* t))
      (fol.compiler:compile-form ctor-form)
      (let* ((loop-result-1 (fol.compiler:compile-form loop-form))
             (code-str-1 (write-to-string (fol.compiler:compilation-result-code loop-result-1))))
        (is (search "TRANSIENT" code-str-1 :test #'string-equal))))
    ;; Hijack MAKE for this class.
    (eval `(defmethod fol.compiler.primitives:make :around ((c (eql ',class-name)) &rest args)
             (apply #'call-next-method c args)))
    (unwind-protect
        ;; A freshly-compiled loop, using the SAME (untouched, still-cached)
        ;; helper summary, must NOT convert now.
        (let* ((fol.compiler.escape-analysis:*transient-loops* t)
               (loop-result-2 (fol.compiler:compile-form loop-form))
               (code-str-2 (write-to-string (fol.compiler:compilation-result-code loop-result-2))))
          (is (null (search "TRANSIENT" code-str-2 :test #'string-equal))))
      (let ((m (find-if (lambda (m)
                           (let ((s (first (sb-mop:method-specializers m))))
                             (and (typep s 'sb-mop:eql-specializer)
                                  (eql (sb-mop:eql-specializer-object s) class-name))))
                         (sb-mop:generic-function-methods #'fol.compiler.primitives:make))))
        (when m (remove-method #'fol.compiler.primitives:make m))))))

(defvar *tc-load-time-sentinel* 0
  "Incremented by a test-only :AROUND method hijacking ASSOC on <DICT>,
   used only by TRANSIENT-LOOP-LOAD-TIME-HIJACK-AFTER-COMPILE-CLOSES-GAP.")

(test transient-loop-load-time-hijack-after-compile-closes-gap
  "The gap a mathematician's-eye review of the paper's formal apparatus
   found: TRUSTED is checked once, at compile time, inside INIT-SUPPORTS-P
   -- but the world-guard's actual protection (REGISTER-REGION) only
   starts at load time, a strictly later, separate phase (every
   REGISTER-REGION call site is wrapped in CL:LOAD-TIME-VALUE). A hijack
   introduced in that window is invisible to both: the compile-time
   snapshot is already stale, and NOTE-REDEFINITION has nothing registered
   yet to invalidate (no redefinition event fires for a method that
   already existed by the time the region registers).
   %REGISTER-REGION-TRUSTED-FORM/%KIND-TRUSTED-P close this by
   re-verifying TRUSTED live, at load time, inside the very code
   REGISTER-REGION's CL:LOAD-TIME-VALUE wraps.

   Uses a DICT accumulator with ASSOC hijacked on <DICT> itself, not a
   user-defined persistent-object class with a hijacked MAKE: a dict
   literal init never calls a hijackable generic at all, so the hijack
   cannot fire during initialization -- only during the loop *body*'s
   ASSOC/ASSOC! calls -- and :DICT carries no ASSOC exemption the way
   persistent-object's Approach-A dispatch-through does, so this isolates
   the load-time re-check itself rather than interacting with that
   already-separately-tested mechanism.

   First confirms the positive case (no hijack -- fast path runs, sentinel
   stays silent), then the gap-closing case (hijack introduced strictly
   between compile and load -- slow path must run, sentinel must fire) on
   a second, freshly-compiled instance of the identical loop, proving this
   isn't a case where the fix simply always declines."
  (let ((loop-form '(loop (acc (fol.compiler.collection-functions:dict) i 0)
                      (if (< i 5)
                          (recur (fol.compiler.collection-functions:assoc acc i i) (+ i 1))
                          acc)))
        (fol.compiler.escape-analysis:*transient-loops* t))
    ;; Positive case: no hijack, compile immediately followed by eval.
    (setf *tc-load-time-sentinel* 0)
    (let ((result (fol.compiler:compile-form loop-form)))
      (eval (fol.compiler:compilation-result-code result))
      (is (= 0 *tc-load-time-sentinel*)))
    ;; Gap-closing case: hijack ASSOC on <DICT>, strictly after compiling a
    ;; FRESH instance of the same loop but before evaluating it.
    (setf *tc-load-time-sentinel* 0)
    (let ((result (fol.compiler:compile-form loop-form)))
      (eval '(defmethod fol.compiler.collection-functions:assoc :around
                 ((d fol.compiler.collections:<dict>) k v &rest kvs)
               (declare (ignore kvs))
               (incf *tc-load-time-sentinel*)
               (call-next-method)))
      (unwind-protect
          (progn
            (eval (fol.compiler:compilation-result-code result))
            (is (> *tc-load-time-sentinel* 0)))
        (let ((m (find-method #'fol.compiler.collection-functions:assoc '(:around)
                               (list (find-class 'fol.compiler.collections:<dict>) t t)
                               nil)))
          (when m (remove-method #'fol.compiler.collection-functions:assoc m)))))))

(test transient-reduce-load-time-hijack-after-compile-closes-gap
  "The REDUCE-conversion counterpart of TRANSIENT-LOOP-LOAD-TIME-HIJACK-
   AFTER-COMPILE-CLOSES-GAP: MAYBE-TRANSIENT-REDUCE (EMIT-CALL,
   compiler.lisp) is the other of the two call sites that ever computes a
   TRUSTED fact, and has its own, independent REGISTER-REGION/CL:LOAD-
   TIME-VALUE wrapping -- this exercises that wiring specifically, not
   just the LOOP path's."
  (let ((reduce-form (fol-form
                       '(fol.compiler.seq-functions:reduce
                         (fn #(acc x) (fol.compiler.collection-functions:assoc acc x x))
                         (fol.compiler.collection-functions:dict)
                         (fol.compiler.collection-functions:vector 0 1 2 3 4))))
        (fol.compiler.escape-analysis:*transient-loops* t))
    ;; Positive case: no hijack.
    (setf *tc-load-time-sentinel* 0)
    (let ((result (fol.compiler:compile-form reduce-form)))
      (eval (fol.compiler:compilation-result-code result))
      (is (= 0 *tc-load-time-sentinel*)))
    ;; Gap-closing case: hijack introduced strictly between compiling a
    ;; fresh instance of the same reduce and evaluating it.
    (setf *tc-load-time-sentinel* 0)
    (let ((result (fol.compiler:compile-form reduce-form)))
      (eval '(defmethod fol.compiler.collection-functions:assoc :around
                 ((d fol.compiler.collections:<dict>) k v &rest kvs)
               (declare (ignore kvs))
               (incf *tc-load-time-sentinel*)
               (call-next-method)))
      (unwind-protect
          (progn
            (eval (fol.compiler:compilation-result-code result))
            (is (> *tc-load-time-sentinel* 0)))
        (let ((m (find-method #'fol.compiler.collection-functions:assoc '(:around)
                               (list (find-class 'fol.compiler.collections:<dict>) t t)
                               nil)))
          (when m (remove-method #'fol.compiler.collection-functions:assoc m)))))))

(test kind-trusted-p-preserves-persistent-object-assoc-exemption
  "%KIND-TRUSTED-P (used by the load-time re-check above) must mirror
   %PERSISTENT-OBJECT-INIT-SUPPORTS-P's Approach-A exemption exactly: a
   customization on ASSOC alone does not make the representation
   untrusted (dispatch-through covers it), only a customization on MAKE or
   any other used op does. Neither of the two integration tests above
   exercises this branch (both use :DICT, which has no such exemption), so
   this checks it directly against a real class and a real :around method."
  (let ((class-src "(defclass <tc-kind-trusted-assoc-only> []
                       [[items :initarg :items :initform []]])")
        (class-name nil))
    (compile-eval-fol-source-multi class-src)
    (setf class-name (intern "<TC-KIND-TRUSTED-ASSOC-ONLY>" :fol.core))
    (let ((kind (cons :persistent-object class-name)))
      ;; No customization at all: trusted.
      (is (fol.compiler.escape-analysis:%kind-trusted-p kind '("MAKE" "ASSOC")))
      ;; Customize ASSOC only.
      (eval `(defmethod fol.compiler.collection-functions:assoc :around
                 ((o ,class-name) k v &rest kvs)
               (declare (ignore kvs))
               (call-next-method)))
      (unwind-protect
          (progn
            ;; ASSOC alone customized: still trusted (Approach A exemption).
            (is (fol.compiler.escape-analysis:%kind-trusted-p kind '("MAKE" "ASSOC")))
            ;; MAKE customized too (even if only checked, not called here):
            ;; untrusted, since MAKE gets no exemption.
            (eval `(defmethod fol.compiler.primitives:make :around
                       ((c (eql ',class-name)) &rest args)
                     (apply #'call-next-method c args)))
            (unwind-protect
                (is (not (fol.compiler.escape-analysis:%kind-trusted-p kind '("MAKE" "ASSOC"))))
              (let ((m (find-if (lambda (m)
                                   (let ((s (first (sb-mop:method-specializers m))))
                                     (and (typep s 'sb-mop:eql-specializer)
                                          (eql (sb-mop:eql-specializer-object s) class-name))))
                                 (sb-mop:generic-function-methods #'fol.compiler.primitives:make))))
                (when m (remove-method #'fol.compiler.primitives:make m)))))
        (let ((m (find-method #'fol.compiler.collection-functions:assoc '(:around)
                               (list (find-class class-name) t t)
                               nil)))
          (when m (remove-method #'fol.compiler.collection-functions:assoc m)))))))

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
;;; GET slot-lookup inline cache (persistence.lisp SLOT-NAME-FROM-KEYWORD)
;;; ============================================================================
;;; Profiling the DVI benchmark (§sec:discussion) found GET on a persistent
;;; object dominating time (~59% of a read-heavy run), most of it a hash
;;; lookup (SLOT-NAME-FROM-KEYWORD) mapping a literal keyword to a slot name
;;; on every call. A single-entry, per-class inline cache skips that lookup
;;; on a repeat (keyword, class) hit -- correctness, not just speed, is what
;;; these tests check: a stale entry must never survive a redefinition, and
;;; a cache miss on a different keyword must still return the right slot.

(test tc-slot-lookup-cache-hit-returns-correct-slot
  "A cache HIT (the same keyword looked up twice in a row on the same
   class) returns the same slot name a fresh, uncached lookup would."
  (let ((src "(defclass <tc-cache-basket> []
                [[items :initarg :items :initform []]
                 [_total :initarg :_total :initform :tc-cache-sentinel]])"))
    (compile-eval-fol-source-multi src)
    (let* ((class (find-class (intern "<TC-CACHE-BASKET>" :fol.core)))
           (obj (fol.compiler.primitives:make (intern "<TC-CACHE-BASKET>" :fol.core))))
      ;; First call populates the cache; second call must hit it and agree.
      (is (eq (fol.compiler.persistent::slot-name-from-keyword class :items)
              (fol.compiler.persistent::slot-name-from-keyword class :items)))
      (is (eq (intern "ITEMS" :fol.core)
              (fol.compiler.persistent::slot-name-from-keyword class :items)))
      ;; GET itself (the actual caller) must still read correctly, both
      ;; before and after the cache is warmed on that keyword.
      (is (eq :tc-cache-sentinel (fol.compiler.collection-functions:get obj :_total))))))

(test tc-slot-lookup-cache-miss-on-different-keyword-still-correct
  "Looking up a SECOND keyword after the cache is warmed on a first one is a
   cache miss (single-entry cache, not associative) but must still return
   the right slot, not the first keyword's cached answer."
  (let ((src "(defclass <tc-cache-two-slots> []
                [[items :initarg :items :initform []]
                 [_total :initarg :_total :initform nil]])"))
    (compile-eval-fol-source-multi src)
    (fol.compiler.primitives:make (intern "<TC-CACHE-TWO-SLOTS>" :fol.core)) ; force finalization
    (let ((class (find-class (intern "<TC-CACHE-TWO-SLOTS>" :fol.core))))
      (fol.compiler.persistent::slot-name-from-keyword class :items) ; warm on :items
      (is (eq (intern "_TOTAL" :fol.core)
              (fol.compiler.persistent::slot-name-from-keyword class :_total)))
      ;; Swap back: warmed on :_total now, :items must still resolve right.
      (is (eq (intern "ITEMS" :fol.core)
              (fol.compiler.persistent::slot-name-from-keyword class :items))))))

(test tc-slot-lookup-cache-invalidated-by-redefinition
  "A class redefinition that changes slot layout must not leave a stale
   cache entry from the OLD layout answering lookups against the NEW one:
   COMPUTE-SLOTS resets the cache unconditionally on every redefinition."
  (let ((src1 "(defclass <tc-cache-redef> []
                 [[old-slot :initarg :old-slot :initform nil]])")
        (src2 "(defclass <tc-cache-redef> []
                 [[new-slot :initarg :new-slot :initform nil]])"))
    (compile-eval-fol-source-multi src1)
    (fol.compiler.primitives:make (intern "<TC-CACHE-REDEF>" :fol.core)) ; force finalization
    (let ((class (find-class (intern "<TC-CACHE-REDEF>" :fol.core))))
      ;; Warm the cache on a keyword valid in the OLD layout.
      (is (eq (intern "OLD-SLOT" :fol.core)
              (fol.compiler.persistent::slot-name-from-keyword class :old-slot)))
      (compile-eval-fol-source-multi src2)
      (fol.compiler.primitives:make (intern "<TC-CACHE-REDEF>" :fol.core)) ; re-finalize
      ;; Same class object (REINITIALIZE-INSTANCE, not a fresh one); its
      ;; cache must have been reset, or this would still (wrongly) answer
      ;; OLD-SLOT for :old-slot instead of NIL, and fail to find NEW-SLOT.
      (is (null (fol.compiler.persistent::slot-name-from-keyword class :old-slot)))
      (is (eq (intern "NEW-SLOT" :fol.core)
              (fol.compiler.persistent::slot-name-from-keyword class :new-slot))))))

;;; ============================================================================
;;; Run the suite
;;; ============================================================================

(fiveam:run! 'transient-conversion-suite)
