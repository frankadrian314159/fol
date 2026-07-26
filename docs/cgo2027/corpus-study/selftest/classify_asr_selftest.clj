;; Self-test for asr-corpus.classify-asr against hand-authored shapes
;; mirroring the real gates' own test suite (src/tests/test-scalar-
;; replacement.lisp) as closely as a reader-level Clojure proxy allows.
;;
;; Run from corpus-study/: clojure -Sdeps '{:paths ["src" "selftest"]}' -X classify-asr-selftest/run

(ns classify-asr-selftest
  (:require [asr-corpus.classify-asr :as c]))

(defn check
  [label expected-verdict registry-forms loop-form]
  (let [registry (c/record-registry registry-forms)
        vs (c/loop-sites loop-form registry)
        v (first vs)]
    (if (= expected-verdict (:verdict v))
      (do (println (format "PASS: %s" label)) true)
      (do (println (format "FAIL: %s -- expected %s got %s" label expected-verdict (:verdict v)))
          (when (:uses v) (println "  uses:" (:uses v)))
          false))))

(def point-registry
  ['(defrecord Point [x y])])

(def cases
  [["direct constructor reconstruction, tail rebox"
    :qualified point-registry
    '(loop [p (->Point 0 0)]
       (if (< (:x p) 10)
         (recur (->Point (inc (:x p)) (:y p)))
         p))]

   ["assoc-based partial reconstruction"
    :qualified point-registry
    '(loop [p (->Point 0 0)]
       (if (< (:x p) 10)
         (recur (assoc p :x (inc (:x p))))
         p))]

   ["get-form field read (not just keyword-first)"
    :qualified point-registry
    '(loop [p (->Point 0 0)]
       (if (< (get p :x) 10)
         (recur (->Point (inc (get p :x)) (get p :y)))
         p))]

   ["dot-interop field read (deftype-style, e.g. fastmath's (.x rr))"
    :qualified point-registry
    '(loop [p (->Point 0 0)]
       (if (< (.x p) 10)
         (recur (->Point (inc (.x p)) (.y p)))
         p))]

   ["dot-interop CALL with an argument is not a field read (real method invocation, even under a same-as-field name)"
    :usage-disqualified point-registry
    '(loop [p (->Point 0 0)]
       (if (< (.x p) 10)
         (recur (->Point (.x p 42) (.y p)))
         p))]

   ["map->Name init with exactly the full field set"
    :qualified point-registry
    '(loop [p (map->Point {:x 0 :y 0})]
       (if (< (:x p) 10)
         (recur (assoc p :x (inc (:x p))))
         p))]

   ["if-branched reconstruction, both arms qualify"
    :qualified point-registry
    '(loop [p (->Point 0 0) i 0]
       (if (< i 10)
         (recur (if (even? i) (->Point (inc (:x p)) (:y p)) (assoc p :x (dec (:x p)))) (inc i))
         p))]

   ["cond-branched reconstruction"
    :qualified point-registry
    '(loop [p (->Point 0 0) i 0]
       (if (< i 10)
         (recur (cond (even? i) (->Point (inc (:x p)) (:y p)) :else (assoc p :x (dec (:x p)))) (inc i))
         p))]

   ["case-branched reconstruction"
    :qualified point-registry
    '(loop [p (->Point 0 0) i 0]
       (if (< i 10)
         (recur (case (mod i 3)
                  0 (->Point (inc (:x p)) (:y p))
                  1 (assoc p :x (dec (:x p)))
                  (assoc p :y (inc (:y p))))
                (inc i))
         p))]

   ["single-form let-wrapper peel before reconstruction"
    :qualified point-registry
    '(loop [p (->Point 0 0)]
       (if (< (:x p) 10)
         (recur (let [nx (inc (:x p))] (->Point nx (:y p))))
         p))]

   ["let-wrapper whose own body is NOT a reconstruction still disqualifies"
    :usage-disqualified point-registry
    '(loop [p (->Point 0 0)]
       (if (< (:x p) 10)
         (recur (let [nx (inc (:x p))] nx))
         p))]

   ["an unrelated fn literal elsewhere in the loop body -- not a capture, still qualifies"
    :qualified point-registry
    '(loop [p (->Point 0 0)]
       (let [unrelated (fn [q] (inc q))]
         (if (< (unrelated (:x p)) 10)
           (recur (->Point (inc (:x p)) (:y p)))
           p)))]

   ["a fn literal whose own param shadows the accumulator name is a separate scope, still qualifies"
    :qualified point-registry
    '(loop [p (->Point 0 0)]
       (let [ignore-me (fn [p] (inc p))]
         (if (< (:x p) 10)
           (recur (->Point (inc (:x p)) (:y p)))
           p)))]

   ["a fn literal that genuinely captures the accumulator as a free variable disqualifies"
    :usage-disqualified point-registry
    '(loop [p (->Point 0 0)]
       (let [thunk (fn [] p)]
         (if (< (:x p) 10)
           (recur (->Point (inc (:x p)) (:y p)))
           p)))]

   ["nested loop reading the outer accumulator's fields only"
    :qualified point-registry
    '(loop [p (->Point 0 0) i 0]
       (if (< i 10)
         (recur (->Point (+ (:x p) (loop [j 0 s 0] (if (< j 3) (recur (inc j) (+ s (:x p))) s))) (:y p))
                (inc i))
         p))]

   ["nested loop whose own binding shadows the accumulator name disqualifies safely"
    :usage-disqualified point-registry
    '(loop [p (->Point 0 0) i 0]
       (if (< i 10)
         (recur (->Point (+ (:x p) (loop [p 0] p)) (:y p)) (inc i))
         p))]

   ["bare accumulator escaping into an arbitrary call"
    :usage-disqualified point-registry
    '(loop [p (->Point 0 0)]
       (do (println p)
           (if (< (:x p) 10)
             (recur (->Point (inc (:x p)) (:y p)))
             p)))]

   ["helper-call reconstruction (no interprocedural inlining support)"
    :usage-disqualified point-registry
    '(loop [p (->Point 0 0)]
       (if (< (:x p) 10)
         (recur (bump p))
         p))]

   ["map->Name init missing a declared field -- field-mismatch"
    :field-mismatch point-registry
    '(loop [p (map->Point {:x 0})]
       p)]

   ["positional constructor with wrong arity -- field-mismatch"
    :field-mismatch point-registry
    '(loop [p (->Point 0)]
       p)]

   ["non-record init -- no-record-init"
    :no-record-init point-registry
    '(loop [p 0]
       (if (< p 10) (recur (inc p)) p))]])

(defn run [_]
  (let [results (mapv (fn [[label expected reg form]] (check label expected reg form)) cases)
        n (count results)
        passed (count (filter true? results))]
    (println (format "\n%d/%d passed" passed n))
    (System/exit (if (< passed n) 1 0))))
