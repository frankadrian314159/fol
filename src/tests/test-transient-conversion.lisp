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

(test transient-set-still-converts-via-wrapper
  "Set-init accumulator with conj chain converts on the legacy wrapper"
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
             (fol.compiler.collections:collection-size opt)))))
  ;; ...but a set accumulator that is READ does not convert (wrapper has no
  ;; read methods).
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
      (is (= before fol.compiler.escape-analysis:*loops-converted*))
      (is (= (fol.compiler.collections:collection-size plain)
             (fol.compiler.collections:collection-size opt))))))

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
  "Verifies the runtime size check is emitted for qualifying loops."
  (let* ((dict-form '(loop (acc (dict) i 0) (if (< i 10) (recur (assoc acc i i) (inc i)) acc)))
         (vec-form '(loop (acc (vector) i 0) (if (< i 10) (recur (conj acc i) (inc i)) acc)))
         (fol.compiler.escape-analysis:*transient-loops* t)
         (dict-code-str (write-to-string
                         (fol.compiler:compilation-result-code
                          (fol.compiler:compile-form dict-form))))
         (vec-code-str (write-to-string
                        (fol.compiler:compilation-result-code
                         (fol.compiler:compile-form vec-form)))))
    ;; The guard ANDs the world-validity cell with a size check on the
    ;; accumulator. (Package prefixes on CL:AND/CAR/LOAD-TIME-VALUE depend on
    ;; the printing package, so we check the package-stable fragments: the
    ;; assumed op region and the threshold+count comparison.)
    ;; Dict threshold = 16.
    (is (search "(FOL.COMPILER.WORLD:REGISTER-REGION '(\"ASSOC\"))"
                dict-code-str :test #'string-equal))
    (is (search "(< 16 (FOL.COMPILER.COLLECTION-FUNCTIONS:COUNT ACC))"
                dict-code-str :test #'string-equal))
    ;; Vector threshold = 12.
    (is (search "(FOL.COMPILER.WORLD:REGISTER-REGION '(\"CONJ\"))"
                vec-code-str :test #'string-equal))
    (is (search "(< 12 (FOL.COMPILER.COLLECTION-FUNCTIONS:COUNT ACC))"
                vec-code-str :test #'string-equal))
    ;; Sets have no size threshold: a converted set loop emits no count check.
    (let* ((fol.compiler.escape-analysis:*transient-loops* t)
           (set-form '(loop (acc (set) i 0) (if (< i 10) (recur (conj acc i) (inc i)) acc)))
           (set-code-str (write-to-string (fol.compiler:compilation-result-code (fol.compiler:compile-form set-form)))))
      (is (null (search "FOL.COMPILER.COLLECTION-FUNCTIONS:COUNT" set-code-str))))))


;;; ============================================================================
;;; Run the suite
;;; ============================================================================

(fiveam:run! 'transient-conversion-suite)
