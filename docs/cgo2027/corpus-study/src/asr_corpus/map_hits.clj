(ns asr-corpus.map-hits
  "Detector for the hypothesis behind the record-accumulator pattern's
   rarity: Clojure programmers building a FIXED-SCHEMA accumulator tend to
   reach for a plain map (init = {} or {:k v ...}, updated via literal
   assoc with the SAME small set of keys every time) rather than commit to
   a DEFRECORD -- a map is more flexible (extensible, no separate type
   declaration) even when the actual key set never varies. If true, this
   is a much larger pool of *would-be* ASR candidates than DEFRECORD-based
   ones: the same allocation cost, avoided the same idiomatic way FOL
   programmers avoid it (by not using a fixed-field type at all), just
   without ASR's option of scalarizing the fields, because FOL's ASR (like
   this classifier) targets DEFCLASS records specifically.

   A site counts as a FIXED-SCHEMA MAP hit when: init classifies as :map,
   and every recur/reduce-fn tail update is `(assoc acc k1 v1 k2 v2 ...)`
   with all keys LITERAL keywords (not `merge`/`update-in`/computed keys),
   using the *same* key set across all update sites for that binding
   (mirroring DEFRECORD's fixed field set) -- the closest map-only analogue
   to what ASR's Reconstruct already handles for records.

   Usage: clojure -M:map-hits <corpus-dir> [project-name ...]"
  (:require [asr-corpus.analyze :as a]
            [clojure.java.io :as io]
            [clojure.pprint :as pp]
            [clojure.set :as set]))

(defn assoc-literal-keys [expr]
  "If EXPR is (assoc acc k1 v1 k2 v2 ...) with all k_i literal keywords,
   return the set of keys; else nil. Does not check the target is ACC --
   caller does that via classify-update already having matched :record-assoc-
   shaped update; this just extracts which keys."
  (when (and (seq? expr) (seq expr) (symbol? (first expr))
             (= "assoc" (a/op-name expr)))
    (let [kvs (rest (rest expr))]
      (when (even? (count kvs))
        (let [keys (take-nth 2 kvs)]
          (when (every? keyword? keys)
            (set keys)))))))

(defn map-fixed-schema-hit? [bindings-or-fn]
  "BINDINGS-OR-FN: {:init init-form :updates [update-form ...]}. True when
   init is {} or a literal keyword-keyed map, and every update is a literal
   assoc on a consistent (non-empty, size >= 2) key set."
  (let [{:keys [init updates]} bindings-or-fn]
    (when (or (map? init) (and (seq? init) (empty? init)))
      (let [key-sets (keep assoc-literal-keys updates)]
        (when (seq key-sets)
          (apply set/union key-sets))))))

(defn analyze-loop-for-maps [form]
  (let [binds (second form)]
    (when (and (vector? binds) (even? (count binds)))
      (let [pairs (partition 2 binds)
            recurs (a/find-recurs (drop 2 form))]
        (for [[k [nm init]] (map-indexed vector pairs)
              :let [updates (for [rr recurs :when (> (count rr) k)] (nth rr k))
                    ks (map-fixed-schema-hit? {:init init :updates updates})]
              :when ks]
          {:name nm :keys ks})))))

(defn analyze-reduce-for-maps [form]
  (let [args (rest form)]
    (when (and (= 3 (count args)) (#{"fn" "fn*"} (a/op-name (first args))))
      (let [f (first args) init (second args)
            after (rest f)
            after (if (symbol? (first after)) (rest after) after)
            params (first after)
            acc (when (vector? params) (first params))]
        (when acc
          (let [updates (a/tail-exprs (last (rest after)))
                ks (map-fixed-schema-hit? {:init init :updates updates})]
            (when ks [{:name acc :keys ks}])))))))

(defn -main [& [corpus-dir & which]]
  (let [corpus  (or corpus-dir "corpus")
        targets (when (seq which) (set which))
        projects (->> (.listFiles (io/file corpus))
                      (filter #(.isDirectory ^java.io.File %))
                      (sort-by #(.getName ^java.io.File %)))
        total (atom 0)]
    (binding [*print-length* 200 *print-level* 20]
      (doseq [d projects
              :let [nm (.getName ^java.io.File d)]
              :when (or (nil? targets) (contains? targets nm))]
        (let [files  (a/clj-files (.getPath d))
              parsed (mapv (fn [p] (assoc (a/read-forms p) :path p)) files)]
          (doseq [{:keys [path forms]} parsed, top forms]
            (a/walk-sites top
              (fn [f]
                (let [op (a/op-name f)
                      hits (cond
                             (#{"loop" "loop*"} op) (analyze-loop-for-maps f)
                             (#{"reduce" "reduce-kv"} op) (analyze-reduce-for-maps f)
                             :else nil)]
                  (doseq [h hits]
                    (swap! total inc)
                    (println (str "\n===== " nm "  ::  " path "  ::  " (:name h)
                                   "  keys=" (:keys h) " ====="))
                    (pp/pprint f))))))))
      (println (str "\nTotal fixed-schema map-accumulator sites: " @total)))
    (shutdown-agents)))
