(ns asr-corpus.weak-hits
  "Print the source of WEAK record-accumulator hits (init is a record
   constructor, rebuilt via a HELPER call rather than a literal
   constructor/assoc at the recur site) -- the complement of hits.clj's
   strong-only output. These are exactly the sites record-acc? counts but
   strong-acc? does not (analyze.clj).

   Usage: clojure -M:weak-hits <corpus-dir> [project-name ...]"
  (:require [asr-corpus.analyze :as a]
            [clojure.java.io :as io]
            [clojure.pprint :as pp]))

(defn weak-loop-hit? [f ctors names]
  (and (#{"loop" "loop*"} (a/op-name f))
       (when-let [bs (a/analyze-loop f ctors names)]
         (and (some a/record-acc? bs) (not (some a/strong-acc? bs))))))

(defn weak-reduce-hit? [f ctors names]
  (and (#{"reduce" "reduce-kv" "reductions"} (a/op-name f))
       (when-let [b (a/analyze-reduce f ctors names)]
         (and (a/record-acc? b) (not (a/strong-acc? b))))))

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
                (when (or (weak-loop-hit? f ctors names)
                          (weak-reduce-hit? f ctors names))
                  (println (str "\n===== " nm "  ::  " path " ====="))
                  (pp/pprint f))))))))
    (shutdown-agents)))
