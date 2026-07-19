;; Same question as point-bench.clj, but for the paper's actual real-world
;; validated pattern: reitit's route-Methods builder (9-field record, 9
;; sequential `assoc` calls, straight-line -- not a hot loop). Mirrors
;; benchmarks/run-asr-reitit-bench.lisp's FOL port exactly, so the two are
;; directly comparable.
;;
;; Run from the repository root:
;;   clojure -M -e "(load-file \"benchmarks/clojure-comparison/reitit-bench.clj\")"

(set! *warn-on-reflection* true)

(defrecord Methods [get head post put delete connect options trace patch])

(defn mk-endpoint ^long [^String path ^String data method]
  (+ (count path) (count data)))

(defn entry [^String path ^String data]
  (let [base (->Methods 0 0 0 0 0 0 0 0 0)
        m1 (assoc base :get     (mk-endpoint path data :get))
        m2 (assoc m1   :head    (mk-endpoint path data :head))
        m3 (assoc m2   :post    (mk-endpoint path data :post))
        m4 (assoc m3   :put     (mk-endpoint path data :put))
        m5 (assoc m4   :delete  (mk-endpoint path data :delete))
        m6 (assoc m5   :connect (mk-endpoint path data :connect))
        m7 (assoc m6   :options (mk-endpoint path data :options))
        m8 (assoc m7   :trace   (mk-endpoint path data :trace))
        m9 (assoc m8   :patch   (mk-endpoint path data :patch))]
    m9))

(def ^com.sun.management.ThreadMXBean thread-bean
  (cast com.sun.management.ThreadMXBean
        (java.lang.management.ManagementFactory/getThreadMXBean)))

(defn allocated-bytes ^long []
  (.getThreadAllocatedBytes thread-bean (.getId (Thread/currentThread))))

(defn mean [xs] (/ (reduce + xs) (double (count xs))))
(defn stddev [xs]
  (let [m (mean xs) n (count xs)]
    (if (< n 2) 0.0
        (Math/sqrt (/ (reduce + (map #(let [d (- % m)] (* d d)) xs))
                       (double (dec n)))))))

(def path "/api/v1/resource")
(def data "somepayload")
(def warmup-calls (long 200000))  ;; reitit's is a single small call, so warm up on CALL COUNT
(def batch-size (long 5000))      ;; like the FOL side, batch to get above measurement granularity
(def timed-batches (long 20))

;; Warm-up: many separate invocations to get the JIT to compile ENTRY itself
;; (a straight-line method, not a loop -- needs invocation-count-based
;; compilation, not OSR).
(dotimes [_ warmup-calls] (entry path data))

(System/gc)
(let [times (atom []) allocs (atom [])]
  (dotimes [_ timed-batches]
    (System/gc)
    (let [b0 (allocated-bytes)
          t0 (System/nanoTime)]
      (dotimes [_ batch-size] (entry path data))
      (let [t1 (System/nanoTime)
            b1 (allocated-bytes)]
        (swap! times conj (/ (/ (- t1 t0) 1e6) batch-size))
        (swap! allocs conj (/ (double (- b1 b0)) batch-size)))))
  (println "=== reitit route-Methods builder pattern, ported to Clojure, run under real JIT ===")
  (println (str "Java: " (System/getProperty "java.vm.name") " " (System/getProperty "java.vm.version")))
  (printf "%,d warm-up calls, %d timed batches of %,d calls each, System/gc before each batch%n%n"
          warmup-calls timed-batches batch-size)
  (printf "entry : %8.5f +/- %7.5f ms/call   %10.1f +/- %8.1f B/call%n"
          (mean @times) (stddev @times) (mean @allocs) (stddev @allocs))
  (println (format "%nAllocated %.1f B/call after JIT warm-up (baseline persistent-map construction for 9 fields would be roughly 200-400B+; near-zero means escape analysis eliminated it, a large positive number means it did not)."
                    (mean @allocs))))

(shutdown-agents)
