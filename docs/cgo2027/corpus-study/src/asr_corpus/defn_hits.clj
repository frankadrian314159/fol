(ns asr-corpus.defn-hits
  "Detector for a shape ANALYZE.CLJ's LOOP/REDUCE-only classifier structurally
   cannot see: a record accumulator threaded through plain SELF-RECURSIVE
   function calls (Clojure recursion without loop/recur) rather than a
   loop's own recur target. `(defn f [acc ...] ... (f (assoc acc :k v) ...))`
   is the same accumulator-rebuild pattern, just via a tail self-call instead
   of a recur form; ANALYZE.CLJ's FIND-RECURS only ever looks for the symbol
   `recur`, so a defn threading a record this way is invisible to it, strong
   or weak tier alike -- a gap in the STUDY's classifier, not evidence the
   pattern doesn't exist under this shape.

   Checks every parameter position (not just the first) and every arity
   clause of a multi-arity defn -- the common Clojure idiom of a public
   1-arity entry point calling a private N-arity accumulator-carrying worker
   clause is exactly where this shape tends to live.

   Usage: clojure -M:defn-hits <corpus-dir> [project-name ...]"
  (:require [asr-corpus.analyze :as a]
            [clojure.java.io :as io]
            [clojure.pprint :as pp]))

(defn- strip-defn-preamble [forms]
  ;; forms: everything after the fn name in a (defn name ...) form.
  ;; Drops an optional docstring and/or attr-map before the params vector
  ;; (single-arity) or clause list (multi-arity).
  (let [forms (if (string? (first forms)) (rest forms) forms)
        forms (if (and (map? (first forms)) (or (vector? (second forms)) (seq? (second forms))))
                (rest forms) forms)]
    forms))

(defn- clause-hit [fname params body ctors names]
  (when (and (vector? params) (seq params) (seq body))
    (let [last-body (last body)
          tails (a/tail-exprs last-body)
          self-calls (filter (fn [t] (and (seq? t) (seq t) (= fname (first t)))) tails)]
      (when (seq self-calls)
        (let [n (count params)
              updates-by-pos
              (into {}
                (for [pos (range n)
                      :let [acc (nth params pos)
                            updates (set (for [sc self-calls
                                                :let [args (vec (rest sc))]
                                                :when (= (count args) n)]
                                           (a/classify-update (nth args pos) acc ctors names)))]
                      ;; :record-assoc alone is unreliable here: unlike a loop
                      ;; binding or reduce init (which ANALYZE.CLJ's INIT check
                      ;; verifies is a real record constructor), a defn
                      ;; PARAMETER has no init expression in this function at
                      ;; all -- its type comes from whatever the caller passes.
                      ;; `(assoc acc ...)` matches a plain map identically to a
                      ;; record; without a whole-program call-site check there
                      ;; is no way to tell them apart, so require the stronger
                      ;; :record-ctor signal (an explicit ->Name/map->Name/
                      ;; Name. call, which only exists for real DEFRECORD
                      ;; types) instead of trusting :record-assoc alone.
                      :when (contains? updates :record-ctor)]
                  [acc updates]))]
          (when (seq updates-by-pos)
            updates-by-pos))))))

(defn defn-self-recursion-hit [form ctors names]
  (when (and (seq? form) (seq form) (symbol? (first form))
             (#{"defn" "defn-"} (a/op-name form)))
    (let [rest1 (rest form)
          fname (first rest1)
          body0 (strip-defn-preamble (rest rest1))]
      (when (symbol? fname)
        (let [clauses (if (vector? (first body0))
                        [[(first body0) (rest body0)]]
                        (for [c body0 :when (and (seq? c) (vector? (first c)))]
                          [(first c) (rest c)]))
              hits (keep (fn [[params body]] (clause-hit fname params body ctors names)) clauses)]
          (when (seq hits)
            {:fname fname :hits (apply merge-with into hits)}))))))

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
                (when-let [hit (defn-self-recursion-hit f ctors names)]
                  (println (str "\n===== " nm "  ::  " path "  ::  " (:fname hit)
                                 "  " (:hits hit) " ====="))
                  (pp/pprint f))))))))
    (shutdown-agents)))
