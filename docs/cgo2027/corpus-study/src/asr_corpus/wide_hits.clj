(ns asr-corpus.wide-hits
  "Broadened record-accumulator detector: like analyze.clj/hits.clj, but sees
   through single-step threading macros (->, cond-> with one clause, some->)
   around a record ctor/assoc call, which the original classify-update treats
   as an opaque :helper (or :other) because it only pattern-matches a bare
   call form, not a threading macro's implicit first-arg insertion. This is
   exactly the gap that caused reitit's http.cljc/ring.cljc site (see
   weak_hits.clj output) to classify as :helper instead of :record-assoc even
   though (cond-> acc any? (assoc method v)) is, once any? is recognized as an
   always-truthy test, unconditionally (assoc acc method v).

   Usage: clojure -M:wide-hits <corpus-dir> [project-name ...]"
  (:require [asr-corpus.analyze :as a]
            [clojure.java.io :as io]
            [clojure.pprint :as pp]))

(def ^:private assoc-ops #{"assoc" "assoc-in" "update" "update-in" "merge" "merge-with" "dissoc"})

(defn unwrap-thread
  "If EXPR is a single-step (-> x form) / (->> x form) / (some-> x form) or a
   single-clause (cond-> x test form), return the form with x spliced in as
   its implicit first (for ->/cond->/some->) or last (for ->>) argument, i.e.
   what the macro would expand to. Otherwise return EXPR unchanged."
  [expr]
  (if (and (seq? expr) (seq expr) (symbol? (first expr)))
    (let [op (name (first expr))]
      (cond
        (and (#{"cond->" "some->"} op) (= 4 (count expr)))
        (let [[_ x _test form] expr]
          (if (seq? form) (list* (first form) x (rest form)) form))
        (and (= "->" op) (= 3 (count expr)))
        (let [[_ x form] expr]
          (if (seq? form) (list* (first form) x (rest form)) form))
        (and (= "->>" op) (= 3 (count expr)))
        (let [[_ x form] expr]
          (if (seq? form) (concat form [x]) form))
        :else expr))
    expr))

(defn classify-update-wide [expr acc ctors names]
  (let [expr (unwrap-thread expr)]
    (cond
      (= expr acc)                                              :passthrough
      (a/record-ctor? expr ctors names)                        :record-ctor
      (and (contains? assoc-ops (a/op-name expr)) (= (second expr) acc)) :record-assoc
      (and (seq? expr) (symbol? (first expr))
           (some #(= % acc) (rest expr)))                      :helper
      :else                                                    :other)))

(defn analyze-reduce-wide [form ctors names]
  (let [args (rest form)]
    (when (and (= 3 (count args)) (#{"fn" "fn*"} (a/op-name (first args))))
      (let [f      (first args)
            init   (second args)
            after  (rest f)
            after  (if (symbol? (first after)) (rest after) after)
            params (first after)
            acc    (when (vector? params) (first params))]
        (when acc
          (let [ik  (a/classify-init init ctors names)
                uks (map #(classify-update-wide % acc ctors names)
                         (a/tail-exprs (last (rest after))))
                uk  (condp #(some %2 %1) (set uks)
                      #{:record-ctor}  :record-ctor
                      #{:record-assoc} :record-assoc
                      #{:helper}       :helper
                      :none)]
            {:init ik :update uk}))))))

(defn wide-strong? [b] (and (= :record (:init b)) (#{:record-ctor :record-assoc} (:update b))))

(defn wide-reduce-hit? [f ctors names]
  (and (#{"reduce" "reduce-kv" "reductions"} (a/op-name f))
       (when-let [b (analyze-reduce-wide f ctors names)] (wide-strong? b))))

;; loop analysis, same widening applied to classify-update calls inside recur args
(defn analyze-loop-wide [form ctors names]
  (let [binds (second form)]
    (when (and (vector? binds) (even? (count binds)))
      (let [pairs  (partition 2 binds)
            syms   (mapv first pairs)
            inits  (mapv second pairs)
            recurs (a/find-recurs (drop 2 form))]
        (vec
         (for [k (range (count syms))
               :let [nm  (nth syms k)
                     ik  (a/classify-init (nth inits k) ctors names)
                     uks (for [rr recurs :when (> (count rr) k)]
                           (classify-update-wide (nth rr k) nm ctors names))
                     uk  (condp #(some %2 %1) (set uks)
                           #{:record-ctor}  :record-ctor
                           #{:record-assoc} :record-assoc
                           #{:helper}       :helper
                           #{:passthrough}  :passthrough
                           :none)]]
           {:init ik :update uk}))))))

(defn wide-loop-hit? [f ctors names]
  (and (#{"loop" "loop*"} (a/op-name f))
       (when-let [bs (analyze-loop-wide f ctors names)] (some wide-strong? bs))))

(defn -main [& [corpus-dir & which]]
  (let [corpus  (or corpus-dir "corpus")
        targets (when (seq which) (set which))
        projects (->> (.listFiles (io/file corpus))
                      (filter #(.isDirectory ^java.io.File %))
                      (sort-by #(.getName ^java.io.File %)))]
    (binding [*print-length* 400 *print-level* 30]
      (doseq [d projects
              :let [nm (.getName ^java.io.File d)]
              :when (or (nil? targets) (contains? targets nm))]
        (let [files  (a/clj-files (.getPath d))
              parsed (mapv (fn [p] (assoc (a/read-forms p) :path p)) files)
              {:keys [ctors names]} (a/record-defs (mapcat :forms parsed))]
          (doseq [{:keys [path forms]} parsed, top forms]
            (a/walk-sites top
              (fn [f]
                (when (or (wide-loop-hit? f ctors names)
                          (wide-reduce-hit? f ctors names))
                  (println (str "\n===== " nm "  ::  " path " ====="))
                  (pp/pprint f))))))))
    (shutdown-agents)))
