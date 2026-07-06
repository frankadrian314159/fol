(ns asr-corpus.analyze
  "Reader-level detector for the ASR pattern (record accumulator rebuilt in a
   loop/reduce) over a corpus of Clojure projects. See README.md for methodology
   and caveats. Usage: clojure -M:analyze <corpus-dir> [manifest.edn] [out.edn]"
  (:require [clojure.tools.reader :as r]
            [clojure.tools.reader.reader-types :as rt]
            [clojure.java.io :as io]
            [clojure.edn :as edn]
            [clojure.string :as str]
            [clojure.pprint :as pp]))

;;; ------------------------------------------------------------------ reading

(defn read-forms
  "Read all top-level forms from a Clojure source file as data. Returns
   {:forms [...] :read-error bool}. Reader conditionals resolved for :clj;
   unknown tagged literals collapsed to their value; #= disabled."
  [path]
  (let [rdr  (rt/indexing-push-back-reader (slurp path))
        opts {:eof ::eof :read-cond :allow :features #{:clj}}]
    (binding [r/*default-data-reader-fn* (fn [_tag v] v)
              r/*read-eval* false
              r/*suppress-read* true]
      (loop [acc []]
        (let [form (try (r/read opts rdr) (catch Throwable _ ::error))]
          (cond
            (identical? form ::eof)   {:forms acc :read-error false}
            (identical? form ::error) {:forms acc :read-error true}
            :else                     (recur (conj acc form))))))))

;;; ------------------------------------------------------------- tree helpers

(defn children [form]
  (cond
    (map? form)  (mapcat identity (seq form))   ; keys and vals
    (coll? form) (seq form)
    :else        nil))

(defn op-name
  "Unqualified name of a call form's operator symbol, or nil."
  [form]
  (when (and (seq? form) (seq form) (symbol? (first form)))
    (name (first form))))

(defn walk-sites
  "Pre-order walk of FORM calling (visit node) on every non-quoted subform."
  [form visit]
  (when-not (= "quote" (op-name form))
    (visit form)
    (doseq [c (children form)] (walk-sites c visit))))

;;; ------------------------------------------------------- record definitions

(defn record-defs
  "Scan FORMS for defrecord/deftype and return {:names #{str} :ctors #{str}}."
  [forms]
  (let [names (volatile! #{})]
    (doseq [top forms]
      (walk-sites top
        (fn [f]
          (when (and (#{"defrecord" "deftype"} (op-name f)) (symbol? (second f)))
            (vswap! names conj (name (second f)))))))
    (let [ns @names]
      {:names ns
       :ctors (into #{} (mapcat (fn [n] [(str "->" n) (str "map->" n) (str n ".")]) ns))})))

;;; ------------------------------------------------------------ classification

(def ^:private map-ctor-ops  #{"hash-map" "array-map" "sorted-map" "sorted-map-by" "zipmap"})
(def ^:private coll-ctor-ops #{"vector" "vec" "list" "list*" "hash-set" "sorted-set"
                               "sorted-set-by" "set" "transient" "range" "repeat" "cons"})
(def ^:private assoc-ops     #{"assoc" "assoc-in" "update" "update-in" "merge" "merge-with" "dissoc"})

(defn record-ctor? [form ctors names]
  (and (seq? form) (seq form) (symbol? (first form))
       (let [op (name (first form))]
         (or (contains? ctors op)
             (and (= op "new") (symbol? (second form))
                  (contains? names (name (second form))))))))

(defn classify-init [init ctors names]
  (cond
    (record-ctor? init ctors names)                    :record
    (map? init)                                        :map
    (contains? map-ctor-ops (op-name init))            :map
    (and (= "into" (op-name init)) (map? (second init))) :map
    (vector? init)                                     :coll
    (set? init)                                        :coll
    (and (seq? init) (empty? init))                    :coll
    (contains? coll-ctor-ops (op-name init))           :coll
    (and (= "into" (op-name init)))                    :coll
    (number? init)                                     :primitive
    :else                                              :other))

(defn classify-update
  "How is accumulator ACC produced by EXPR (a recur arg / reduce-fn tail)?"
  [expr acc ctors names]
  (cond
    (= expr acc)                                              :passthrough
    (record-ctor? expr ctors names)                          :record-ctor
    (and (contains? assoc-ops (op-name expr)) (= (second expr) acc)) :record-assoc
    (and (seq? expr) (symbol? (first expr))
         (some #(= % acc) (rest expr)))                      :helper
    :else                                                    :other))

;;; ------------------------------------------------------------- loop analysis

(defn find-recurs
  "Recur arg-lists that target THIS loop: walk BODY but do not descend into
   nested loop*/fn*/quote (which establish their own recur target)."
  [body]
  (let [out (volatile! [])]
    (letfn [(w [f]
              (cond
                (and (seq? f) (seq f) (symbol? (first f)))
                (let [op (name (first f))]
                  (cond
                    (= op "recur")                              (vswap! out conj (vec (rest f)))
                    (#{"loop" "loop*" "fn" "fn*" "quote"} op)   nil
                    :else                                       (doseq [x f] (w x))))
                (coll? f) (doseq [x (children f)] (w x))
                :else nil))]
      (doseq [f body] (w f)))
    @out))

(defn analyze-loop
  "Return a vector of {:init kw :update kw} per loop binding, or nil."
  [form ctors names]
  (let [binds (second form)]
    (when (and (vector? binds) (even? (count binds)))
      (let [pairs  (partition 2 binds)
            syms   (mapv first pairs)
            inits  (mapv second pairs)
            recurs (find-recurs (drop 2 form))]
        (vec
         (for [k (range (count syms))
               :let [nm  (nth syms k)
                     ik  (classify-init (nth inits k) ctors names)
                     uks (for [rr recurs :when (> (count rr) k)]
                           (classify-update (nth rr k) nm ctors names))
                     uk  (condp #(some %2 %1) (set uks)
                           #{:record-ctor}  :record-ctor
                           #{:record-assoc} :record-assoc
                           #{:helper}       :helper
                           #{:passthrough}  :passthrough
                           :none)]]
           {:init ik :update uk}))))))

;;; ----------------------------------------------------------- reduce analysis

(defn tail-exprs
  "Flat seq of tail-position expressions of a function body form."
  [f]
  (if-not (and (seq? f) (seq f) (symbol? (first f)))
    [f]
    (let [op (name (first f))]
      (cond
        (#{"if" "if-not" "if-let" "if-some"} op)
        (vec (mapcat tail-exprs (remove nil? [(nth f 2 nil) (nth f 3 nil)])))
        (#{"when" "when-not" "when-let" "when-some" "do" "let" "let*"
           "letfn" "letfn*" "binding" "loop"} op)
        (tail-exprs (last f))
        (= "cond" op)
        (vec (mapcat tail-exprs (map second (partition 2 (rest f)))))
        :else [f]))))

(defn analyze-reduce
  "Classify a (reduce f init coll) with an fn-literal F and explicit INIT.
   Returns {:init kw :update kw} or nil (unclassifiable: named fn / 2-arg)."
  [form ctors names]
  (let [args (rest form)]
    (when (and (= 3 (count args)) (#{"fn" "fn*"} (op-name (first args))))
      (let [f      (first args)
            init   (second args)
            after  (rest f)
            after  (if (symbol? (first after)) (rest after) after) ; drop fn name
            params (first after)
            acc    (when (vector? params) (first params))]
        (when acc
          (let [ik  (classify-init init ctors names)
                uks (map #(classify-update % acc ctors names)
                         (tail-exprs (last (rest after))))
                uk  (condp #(some %2 %1) (set uks)
                      #{:record-ctor}  :record-ctor
                      #{:record-assoc} :record-assoc
                      #{:helper}       :helper
                      :none)]
            {:init ik :update uk}))))))

;;; --------------------------------------------------------------- predicates

(defn record-acc?   [b] (and (= :record (:init b)) (#{:record-ctor :record-assoc :helper} (:update b))))
(defn strong-acc?   [b] (and (= :record (:init b)) (#{:record-ctor :record-assoc} (:update b))))

(defn site-tags [bindings]
  {:record        (boolean (some record-acc? bindings))
   :record-strong (boolean (some strong-acc? bindings))
   :ctor          (boolean (some #(and (= :record (:init %)) (= :record-ctor  (:update %))) bindings))
   :assoc         (boolean (some #(and (= :record (:init %)) (= :record-assoc (:update %))) bindings))
   :map           (boolean (some #(= :map  (:init %)) bindings))
   :coll          (boolean (some #(= :coll (:init %)) bindings))
   :primitive     (boolean (and (not (some record-acc? bindings))
                                (not (some #(#{:map :coll} (:init %)) bindings))
                                (some #(= :primitive (:init %)) bindings)))})

;;; ------------------------------------------------------------- aggregation

(defn clj-files [dir]
  (->> (file-seq (io/file dir))
       (filter #(.isFile ^java.io.File %))
       (map #(.getPath ^java.io.File %))
       (filter #(re-find #"\.clj[cs]?$" %))
       (remove #(re-find #"(?:^|[/\\])(?:target|\.git|node_modules|\.cpcache|out|resources)[/\\]"
                         %))))

(defn tally [sites]
  (reduce (fn [m t]
            (-> m
                (update :sites inc)
                (cond-> (:record t)        (update :record inc))
                (cond-> (:record-strong t) (update :record-strong inc))
                (cond-> (:ctor t)          (update :ctor inc))
                (cond-> (:assoc t)         (update :assoc inc))
                (cond-> (:map t)           (update :map inc))
                (cond-> (:coll t)          (update :coll inc))
                (cond-> (:primitive t)     (update :primitive inc))))
          {:sites 0 :record 0 :record-strong 0 :ctor 0 :assoc 0 :map 0 :coll 0 :primitive 0}
          sites))

(defn analyze-project [project domain dir]
  (let [files  (clj-files dir)
        parsed (mapv read-forms files)
        forms  (mapcat :forms parsed)
        {:keys [ctors names]} (record-defs forms)
        loops  (volatile! [])
        reds   (volatile! [])]
    (doseq [{fs :forms} parsed, top fs]
      (walk-sites top
        (fn [f]
          (let [op (op-name f)]
            (cond
              (#{"loop" "loop*"} op)
              (when-let [bs (analyze-loop f ctors names)] (vswap! loops conj bs))
              (#{"reduce" "reduce-kv" "reductions"} op)
              (when-let [b (analyze-reduce f ctors names)] (vswap! reds conj [b])))))))
    {:project     project
     :domain      domain
     :files       (count files)
     :read-errors (count (filter :read-error parsed))
     :records     (count names)
     :loop        (tally (map site-tags @loops))
     :reduce      (tally (map site-tags @reds))}))

(defn add-tallies [a b]
  (merge-with + a b))

(defn combine [stats key-path]
  (reduce add-tallies
          {:sites 0 :record 0 :record-strong 0 :ctor 0 :assoc 0 :map 0 :coll 0 :primitive 0}
          (map #(get-in % key-path) stats)))

(defn pct [num den] (if (pos? den) (format "%.2f%%" (* 100.0 (/ (double num) den))) "n/a"))

(defn print-summary [stats]
  (let [loop-tot   (combine stats [:loop])
        red-tot    (combine stats [:reduce])
        sites      (+ (:sites loop-tot) (:sites red-tot))
        rec        (+ (:record loop-tot) (:record red-tot))
        rec-strong (+ (:record-strong loop-tot) (:record-strong red-tot))
        prim       (+ (:primitive loop-tot) (:primitive red-tot))
        mapc       (+ (:map loop-tot) (:map red-tot))
        collc      (+ (:coll loop-tot) (:coll red-tot))
        ctor       (+ (:ctor loop-tot) (:ctor red-tot))
        assc       (+ (:assoc loop-tot) (:assoc red-tot))]
    (println "\n================ ASR pattern corpus study ================")
    (println (format "Projects: %d   Files: %d   Read errors: %d   Records defined: %d"
                     (count stats)
                     (reduce + (map :files stats))
                     (reduce + (map :read-errors stats))
                     (reduce + (map :records stats))))
    (println (format "Loop sites: %d   Reduce sites (classified): %d   Total: %d"
                     (:sites loop-tot) (:sites red-tot) sites))
    (println "\n(a) record accumulator rebuilt : " rec  (str "(" (pct rec sites) " of sites)"))
    (println "      of which strong (ctor/assoc): " rec-strong)
    (println "      rebuild via constructor      : " ctor)
    (println "      rebuild via assoc/update     : " assc)
    (println "(b) map accumulator rebuilt     : " mapc (str "(" (pct mapc sites) ")"))
    (println "(c) collection accumulator grown: " collc (str "(" (pct collc sites) ")"))
    (println "(d) primitive-scalar loop       : " prim (str "(" (pct prim sites) ")"))
    (println (format "\nSuppression signal (d):(a) = %.1f : 1"
                     (if (pos? rec) (/ (double prim) rec) 0.0)))
    (println "\n--- by domain (record sites / total sites) ---")
    (doseq [[dom ss] (sort-by key (group-by :domain stats))]
      (let [lt (combine ss [:loop]) rt (combine ss [:reduce])
            s  (+ (:sites lt) (:sites rt)) r (+ (:record lt) (:record rt))]
        (println (format "  %-16s %5d / %-6d  %s" (str dom) r s (pct r s)))))
    (println "==========================================================\n")))

(defn -main [& [corpus-dir manifest-path out-path]]
  (let [corpus   (or corpus-dir "corpus")
        manifest (edn/read-string (slurp (or manifest-path "manifest.edn")))
        dom-of   (into {} (map (juxt :name :domain) (:repos manifest)))
        projects (->> (.listFiles (io/file corpus))
                      (filter #(.isDirectory ^java.io.File %))
                      (sort-by #(.getName ^java.io.File %)))
        stats    (vec
                  (for [d projects
                        :let [nm (.getName ^java.io.File d)]]
                    (do (binding [*out* *err*] (println "analyzing" nm))
                        (analyze-project nm (get dom-of nm :unknown) (.getPath d)))))]
    (spit (or out-path "results.edn")
          (with-out-str (pp/pprint {:generated (str (java.time.Instant/now))
                                    :projects  stats})))
    (print-summary stats)
    (println "Wrote" (or out-path "results.edn"))
    (shutdown-agents)))
