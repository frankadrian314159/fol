(ns asr-corpus.fetch
  "Clone the corpus repos and record a lock file of exact SHAs analyzed.

   Usage: clojure -M:fetch [manifest.edn] [corpus-dir]"
  (:require [clojure.edn :as edn]
            [clojure.java.io :as io]
            [clojure.java.shell :as sh]
            [clojure.string :as str]
            [clojure.pprint :as pp]))

(defn- git [& args]
  (let [{:keys [exit out err]} (apply sh/sh "git" args)]
    (when-not (zero? exit)
      (binding [*out* *err*] (println "  git" (str/join " " args) "->" (str/trim (str err)))))
    {:exit exit :out (str/trim (str out))}))

(defn -main [& [manifest-path corpus-dir]]
  (let [manifest (edn/read-string (slurp (or manifest-path "manifest.edn")))
        corpus   (or corpus-dir "corpus")
        repos    (:repos manifest)]
    (.mkdirs (io/file corpus))
    (let [locked
          (doall
           (for [{:keys [name url sha domain]} repos]
             (let [dir (str corpus "/" name)]
               (if (.exists (io/file dir ".git"))
                 (println "have" name)
                 (do (println "clone" name)
                     ;; blobless partial clone: full history/trees, no file blobs
                     ;; until checkout -- fast and enough for source analysis.
                     (git "clone" "--filter=blob:none" "--quiet" url dir)))
               (when sha (git "-C" dir "checkout" "--quiet" sha))
               (let [head (:out (git "-C" dir "rev-parse" "HEAD"))]
                 {:name name :domain domain :url url :sha head}))))]
      (spit "manifest.lock.edn"
            (with-out-str
              (pp/pprint {:fetched (str (java.time.Instant/now))
                          :repos   (vec locked)})))
      (println "\nWrote manifest.lock.edn (" (count locked) "repos)."))
    (shutdown-agents)))
