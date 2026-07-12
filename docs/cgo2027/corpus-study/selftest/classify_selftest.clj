;; Self-test for asr-corpus.classify against cases mirroring the paper's own
;; worked examples: lh-pop-batch (should qualify), DVI-style helper-threading
;; (should NOT qualify -- the paper's own §7 says this is unconverted even by
;; the real FOL classifier), quicksort-swap (should NOT qualify: not fresh),
;; word-count-style read-heavy reduce (should qualify), and a plain vector
;; growth loop (should qualify).
;;
;; Run: clojure -M -e "(load-file \"src/asr_corpus/classify.clj\")" -e "(load-file \"selftest/classify_selftest.clj\")"
;; or, simpler, from corpus-study/: clojure -Sdeps '{:paths ["src" "selftest"]}' -M -m classify-selftest

(ns classify-selftest
  (:require [asr-corpus.classify :as c]))

(defn check [label expected-verdict form]
  (let [op (c/op-name* form)
        result (cond
                 (#{"loop" "loop*"} op) (first (c/loop-sites form))
                 (#{"reduce" "reduce-kv"} op) (first (c/reduce-sites form)))
        got (:verdict result)
        ok (= got expected-verdict)]
    (println (format "[%s] %-6s expected=%-20s got=%-20s %s"
                     (if ok "PASS" "FAIL") label expected-verdict got
                     (if ok "" (str "  uses=" (:uses result)))))
    ok))

(defn check-reason [label expected-reason form]
  (let [op (c/op-name* form)
        result (cond
                 (#{"loop" "loop*"} op) (first (c/loop-sites form))
                 (#{"reduce" "reduce-kv"} op) (first (c/reduce-sites form)))
        got (:reason result)
        ok (and (= :no-fresh-init (:verdict result)) (= got expected-reason))]
    (println (format "[%s] %-6s expected=:no-fresh-init/%-20s got=%s/%s"
                     (if ok "PASS" "FAIL") label expected-reason (:verdict result) got))
    ok))

(def cases
  [;; 1. lh-pop-batch shape: (loop [acc [] i 0] (if (< i n) (recur (conj acc v) (inc i)) [acc q]))
   ["lh-pop-batch (vector, conj, tuple exit)"
    :qualified
    '(loop [acc [] i 0]
       (if (< i n)
         (recur (conj acc v) (inc i))
         [acc q]))]

   ;; 2. dict accumulation, direct assoc, bare exit
   ["dict assoc loop, bare exit"
    :qualified
    '(loop [acc {} i 0]
       (if (< i n)
         (recur (assoc acc i i) (inc i))
         acc))]

   ;; 3. -> thread chain
   ["-> thread chain"
    :qualified
    '(loop [acc {}]
       (if (seq xs)
         (recur (-> acc (assoc :a 1) (dissoc :b)))
         acc))]

   ;; 4. if-branched chain
   ["if-branched chain"
    :qualified
    '(loop [acc {} xs xs]
       (if (seq xs)
         (recur (if (pred (first xs))
                  (assoc acc (first xs) 1)
                  (dissoc acc (first xs))))
         acc))]

   ;; 5. DVI-style helper threading: cart passed to add-item, a different
   ;;    local (c2) recurs. Per the paper's own §7 ("DVI does not convert"),
   ;;    this must NOT qualify even under full FOL rules (no helper inlining
   ;;    fires here since add-item isn't in chain position) -- so it must
   ;;    also not qualify under this restricted port.
   ["DVI-style helper-threading (paper's own unconverted case)"
    :usage-disqualified
    '(loop [cart {}]
       (if (seq xs)
         (let [total (add-item cart price)
               c2 (assoc cart :total total)]
           (recur c2))
         cart))]

   ;; 6. quicksort-swap style: accumulator is the caller's own argument, not
   ;;    a fresh literal -- must fail freshness (paper's RQ6 refusal case).
   ["quicksort-swap (not fresh -- caller's arg)"
    :no-fresh-init
    '(loop [acc input i 0]
       (if (< i n)
         (recur (assoc acc i (compute i)) (inc i))
         acc))]

   ;; 7. vector op-gate violation: assoc on a vector accumulator (only conj!
   ;;    is in the vector op-gate).
   ["vector + assoc (op-gate violation)"
    :op-gate-fail
    '(loop [acc [] i 0]
       (if (< i n)
         (recur (assoc acc i v) (inc i))
         acc))]

   ;; 8. captured in a closure -> disqualify
   ["closure capture"
    :usage-disqualified
    '(loop [acc {} xs xs]
       (if (seq xs)
         (do (run! (fn [_] (println acc)) xs)
             (recur (assoc acc (first xs) 1) (rest xs)))
         acc))]

   ;; 9. set: no reads allowed even though conj/disj gate would pass
   ["set with a read (op-gate: sets support no reads)"
    :op-gate-fail
    '(loop [acc #{} xs xs]
       (if (seq xs)
         (recur (conj acc (get acc (first xs) 0)) (rest xs))
         acc))]

   ;; 10. `vec`-initialized accumulator: FOL's own VEC summary has no
   ;;     :returns-fresh-p, so this must NOT count as a fresh init, unlike
   ;;     analyze.clj's cruder classify-init which would call this :coll.
   ["vec-initialized (FOL: VEC is not returns-fresh)"
    :no-fresh-init
    '(loop [acc (vec xs) i 0]
       (if (< i n)
         (recur (conj acc i) (inc i))
         acc))]

   ;; 11. read-heavy reduce (word-count shape): should qualify via :read-ok
   ["word-count-style reduce (read-heavy, dict)"
    :qualified
    '(reduce (fn [acc w] (assoc acc w (inc (get acc w 0)))) {} tokens)]

   ;; 12. reduce growing a vector with conj
   ["reduce/conj vector growth"
    :qualified
    '(reduce (fn [acc x] (conj acc (transform x))) [] coll)]])

;; Weakness-4-style cases: WHY a no-fresh-init verdict happened, not just
;; that it happened -- distinguishing structurally-aliased (unfixable) from
;; analysis-gap (potentially closeable) causes.
(def reason-cases
  [;; quicksort-swap's own shape: the threaded input vector, a bare param.
   ["quicksort-swap-style (bare param init)"
    :aliased-reference
    '(loop [acc input i 0]
       (if (< i n)
         (recur (assoc acc i (compute i)) (inc i))
         acc))]

   ;; vec-initialized: a real stdlib call, just not fresh-credited.
   ["vec-initialized (analysis gap, not aliasing)"
    :nonfresh-stdlib-call
    '(loop [acc (vec xs) i 0]
       (if (< i n)
         (recur (conj acc i) (inc i))
         acc))]

   ;; into-initialized: same category, common real-world idiom.
   ["into-initialized (analysis gap, not aliasing)"
    :nonfresh-stdlib-call
    '(loop [acc (into {} pairs) i 0]
       (if (< i n)
         (recur (assoc acc i i) (inc i))
         acc))]

   ;; project-local constructor call: Tier-2 territory, not aliasing.
   ["helper-constructor-initialized (Tier-2-closeable gap)"
    :helper-call
    '(loop [acc (make-thing) i 0]
       (if (< i n)
         (recur (assoc acc i i) (inc i))
         acc))]])

(let [results (mapv (fn [[label expected form]] (check label expected form)) cases)
      reason-results (mapv (fn [[label expected form]] (check-reason label expected form)) reason-cases)
      all (concat results reason-results)]
  (println (format "\n%d/%d passed" (count (filter true? all)) (count all)))
  (when-not (every? true? all) (System/exit 1)))
