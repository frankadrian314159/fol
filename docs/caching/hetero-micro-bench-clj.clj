#!/usr/bin/env clojure
;;; Micro-benchmark: heterogeneous dispatch (Clojure version)
;;; Compares dispatch caching across Lisp/Scheme implementations

;; Cache structure using atom (idiomatic Clojure mutable state)
(def +cache-size+ 8)

(defn create-dispatch-cache []
  (atom {:entries (make-array Object +cache-size+)
         :next-idx 0
         :hits 0
         :misses 0}))

(defn cache-lookup [cache key]
  (let [{:keys [entries]} @cache]
    (loop [i 0]
      (if (>= i +cache-size+)
        nil
        (let [entry (aget entries i)]
          (if (and entry (= (first entry) key))
            (second entry)
            (recur (inc i))))))))

(defn cache-insert! [cache key f]
  (swap! cache
         (fn [{:keys [entries next-idx] :as state}]
           (aset entries next-idx [key f])
           (assoc state :next-idx (mod (inc next-idx) +cache-size+)))))

;; Clause functions
(defn %-clause-long [x] [:long x])
(defn %-clause-string [x] [:string (count x)])
(defn %-clause-list [x] [:list (count x)])
(defn %-clause-vector [x] [:vector (count x)])
(defn %-clause-symbol [x] [:symbol x])
(defn %-clause-other [x] [:other x])

;; Cache variable
(def %-hetero-cache (create-dispatch-cache))

;; Uncached dispatcher
(defn dispatch-hetero-uncached [x]
  (cond
    (number? x) [:long x]
    (string? x) [:string (count x)]
    (list? x) [:list (count x)]
    (vector? x) [:vector (count x)]
    (symbol? x) [:symbol x]
    :else [:other x]))

;; Cached dispatcher
(defn dispatch-hetero-cached [x]
  (let [key (cond
              (number? x) :long
              (string? x) :string
              (list? x) :list
              (vector? x) :vector
              (symbol? x) :symbol
              :else :other)
        hit (cache-lookup %-hetero-cache key)]
    (if hit
      (do
        (swap! %-hetero-cache update :hits inc)
        (hit x))
      (do
        (swap! %-hetero-cache update :misses inc)
        (cond
          (number? x)
          (do
            (cache-insert! %-hetero-cache key %-clause-long)
            (%-clause-long x))
          (string? x)
          (do
            (cache-insert! %-hetero-cache key %-clause-string)
            (%-clause-string x))
          (list? x)
          (do
            (cache-insert! %-hetero-cache key %-clause-list)
            (%-clause-list x))
          (vector? x)
          (do
            (cache-insert! %-hetero-cache key %-clause-vector)
            (%-clause-vector x))
          (symbol? x)
          (do
            (cache-insert! %-hetero-cache key %-clause-symbol)
            (%-clause-symbol x))
          :else
          (do
            (cache-insert! %-hetero-cache key %-clause-other)
            (%-clause-other x)))))))

;; Test data: 2,000,000 calls with 5-type repeating cycle (10x to get measurable time)
(def ^:dynamic *test-data*
  (vec (take 2000000
         (cycle [1 "test string" '(a b c d e) [1 2 3 4 5] 'symbol]))))

;; Benchmark functions - with explicit side effects to prevent JIT optimization
(defn benchmark-uncached [iterations]
  (loop [run 0 times []]
    (if (>= run iterations)
      times
      (let [result-box (volatile! 0)
            start-ns (System/nanoTime)]
        (dotimes [i (count *test-data*)]
          (let [r (dispatch-hetero-uncached (nth *test-data* i))]
            (when r
              (vswap! result-box inc))))
        (let [elapsed-ms (/ (- (System/nanoTime) start-ns) 1000000.0)]
          (println (format "  Run %d: %,.1f seconds (result: %d)" (inc run) (/ elapsed-ms 1000.0) @result-box))
          (recur (inc run) (conj times elapsed-ms)))))))

(defn benchmark-cached [iterations]
  (loop [run 0 times []]
    (if (>= run iterations)
      times
      (do
        (reset! %-hetero-cache (assoc @%-hetero-cache :hits 0 :misses 0))
        (let [result-box (volatile! 0)
              start-ns (System/nanoTime)]
          (dotimes [i (count *test-data*)]
            (let [r (dispatch-hetero-cached (nth *test-data* i))]
              (when r
                (vswap! result-box inc))))
          (let [elapsed-ms (/ (- (System/nanoTime) start-ns) 1000000.0)]
            (println (format "  Run %d: %,.1f seconds (result: %d)" (inc run) (/ elapsed-ms 1000.0) @result-box))
            (recur (inc run) (conj times elapsed-ms))))))))

(defn run-all-benchmarks []
  (println "\n================================")
  (println "Clojure Heterogeneous Dispatch Caching Micro-Benchmark")
  (println "================================")
  (println (format "Implementation: Clojure %s" (clojure-version)))
  (println "Test data: 2,000,000 calls over repeating 5-type cycle (10× iterations)")
  (println "  Type cycle: number -> string -> list -> vector -> symbol\n")

  (println "Warming up JIT compiler (10,000 calls)...")
  (doseq [i (range 10000)]
    (dispatch-hetero-uncached (nth *test-data* (mod i (count *test-data*)))))
  (doseq [i (range 10000)]
    (reset! %-hetero-cache (assoc @%-hetero-cache :hits 0 :misses 0))
    (dispatch-hetero-cached (nth *test-data* (mod i (count *test-data*)))))
  (println "Warmup complete.\n")

  (println "=== Uncached COND Dispatch (3 iterations) ===")
  (benchmark-uncached 3)

  (println "\n=== Cached Dispatch (3 iterations) ===")
  (benchmark-cached 3)

  (println "\nCached Dispatch Stats:")
  (let [{:keys [hits misses]} @%-hetero-cache
        total (+ hits misses)]
    (println (format "  Cache hits: %d" hits))
    (println (format "  Cache misses: %d" misses))
    (println (format "  Hit rate: %,.4f%%" (if (> total 0) (* 100.0 (/ hits total)) 0))))

  (println "\n================================")
  (println "Benchmark Complete")
  (println "================================"))

;; Run benchmarks
(run-all-benchmarks)
