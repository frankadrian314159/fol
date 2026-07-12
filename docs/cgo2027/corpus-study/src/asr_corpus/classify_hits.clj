(ns asr-corpus.classify-hits
  "Print the source of sites classify.clj scores :qualified, with file/project
   provenance, so a real one can be hand-picked and ported to FOL as an
   external, unmodified-provenance benchmark (PLDI 2027 paper, item 3:
   addressing the 'co-designed benchmarks' concern).

   Usage: clojure -M -m asr-corpus.classify-hits <corpus-dir> [project-name ...]"
  (:require [asr-corpus.classify :as c]
            [clojure.java.io :as io]
            [clojure.pprint :as pp]))

(defn -main [& [corpus-dir & which]]
  (let [corpus (or corpus-dir "corpus")
        targets (when (seq which) (set which))
        projects (->> (.listFiles (io/file corpus))
                      (filter #(.isDirectory ^java.io.File %))
                      (sort-by #(.getName ^java.io.File %)))]
    (binding [*print-length* 400 *print-level* 30]
      (doseq [d projects
              :let [nm (.getName ^java.io.File d)]
              :when (or (nil? targets) (contains? targets nm))]
        (let [files (c/clj-files (.getPath d))
              parsed (mapv (fn [p] (assoc (c/read-forms p) :path p)) files)]
          (doseq [{:keys [path forms]} parsed, top forms]
            (c/walk-sites top
              (fn [f]
                (let [op (c/op-name* f)]
                  (cond
                    (#{"loop" "loop*"} op)
                    (when (some #(= :qualified (:verdict %)) (c/loop-sites f))
                      (println (str "\n===== " nm "  ::  " path " ====="))
                      (pp/pprint f))
                    (#{"reduce" "reduce-kv" "reductions"} op)
                    (when (some #(= :qualified (:verdict %)) (c/reduce-sites f))
                      (println (str "\n===== " nm "  ::  " path " ====="))
                      (pp/pprint f))))))))))
    (shutdown-agents)))
