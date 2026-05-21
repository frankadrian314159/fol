#!/usr/bin/env clojure
;;; Micro-benchmark: generic function dispatch (Clojure version)
;;; Basic dispatch performance test using defmulti

;; Generic dispatcher using Clojure's defmulti
(defmulti dispatch-clj-impl (fn [x]
                              (cond
                                (number? x) :long
                                (string? x) :string
                                (list? x) :list
                                (vector? x) :vector
                                (symbol? x) :symbol
                                :else :other)))

(defmethod dispatch-clj-impl :long [x] [:long x])
(defmethod dispatch-clj-impl :string [x] [:string (count x)])
(defmethod dispatch-clj-impl :list [x] [:list (count x)])
(defmethod dispatch-clj-impl :vector [x] [:vector (count x)])
(defmethod dispatch-clj-impl :symbol [x] [:symbol x])
(defmethod dispatch-clj-impl :default [x] [:other x])

;; Test data: 2,000,000 calls with 5-type repeating cycle (10x to get measurable time)
(def ^:dynamic *test-data*
  (vec (take 2000000
         (cycle [1 "test string" '(a b c d e) [1 2 3 4 5] 'symbol]))))

;; Benchmark function - use volatile to store result and prevent JIT optimization
(defn benchmark-dispatch [iterations]
  (loop [run 0 times []]
    (if (>= run iterations)
      times
      (let [result-box (volatile! 0)
            start-ns (System/nanoTime)]
        (dotimes [i (count *test-data*)]
          (let [r (dispatch-clj-impl (nth *test-data* i))]
            (when r
              (vswap! result-box inc))))
        (let [elapsed-ms (/ (- (System/nanoTime) start-ns) 1000000.0)
              result @result-box]
          (println (format "  Run %d: %,.1f seconds (result: %d)" (inc run) (/ elapsed-ms 1000.0) result))
          (recur (inc run) (conj times result)))))))

(defn run-all-benchmarks []
  (println "\n================================")
  (println "Clojure Generic Function Dispatch Micro-Benchmark")
  (println "================================")
  (println (format "Implementation: Clojure %s" (clojure-version)))
  (println "Test data: 200,000 calls over repeating 5-type cycle")
  (println "  Type cycle: number -> string -> list -> vector -> symbol\n")

  (println "Warming up JIT compiler (10,000 calls)...")
  (doseq [i (range 10000)]
    (dispatch-clj-impl (nth *test-data* (mod i (count *test-data*)))))
  (println "Warmup complete.\n")

  (println "Running dispatch benchmark (3 iterations):")
  (benchmark-dispatch 3)

  (println "\n================================")
  (println "Benchmark Complete")
  (println "================================"))

;; Run benchmarks
(run-all-benchmarks)
