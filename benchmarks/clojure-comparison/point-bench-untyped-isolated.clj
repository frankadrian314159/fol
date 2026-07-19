;; Untyped-field Particle pattern, isolated in its own process (matching the
;; methodology of point-bench.clj and reitit-bench.clj, each a separate
;; `clojure -M -e` invocation) -- verifying the type-hint finding isn't an
;; artifact of running multiple record types in one JVM session.
;;
;; Run from the repository root:
;;   clojure -M -e "(load-file \"benchmarks/clojure-comparison/point-bench-untyped-isolated.clj\")"

(set! *warn-on-reflection* true)

(defrecord Point [x y])
(defn update-point [p]
  (Point. (+ (:x p) 0.1) (+ (:y p) 0.2)))
(defn run-simulation ^double [^long n]
  (loop [p (Point. 0.0 0.0) i 0]
    (if (< i n) (recur (update-point p) (unchecked-inc i)) (+ (:x p) (:y p)))))

(defn run-native ^double [^long n]
  (loop [x 0.0 y 0.0 i 0]
    (if (< i n) (recur (+ x 0.1) (+ y 0.2) (unchecked-inc i)) (+ x y))))

(def ^com.sun.management.ThreadMXBean thread-bean
  (cast com.sun.management.ThreadMXBean
        (java.lang.management.ManagementFactory/getThreadMXBean)))
(defn allocated-bytes ^long []
  (.getThreadAllocatedBytes thread-bean (.getId (Thread/currentThread))))

(def iterations (long 5000000))

(defn mean [xs] (/ (reduce + xs) (double (count xs))))
(defn stddev [xs]
  (let [m (mean xs) n (count xs)]
    (if (< n 2) 0.0
        (Math/sqrt (/ (reduce + (map #(let [d (- % m)] (* d d)) xs)) (double (dec n)))))))

(defn time-calls [f label]
  (dotimes [_ 200] (f (quot iterations 50)))
  (dotimes [_ 5] (f iterations))
  (System/gc)
  (let [times (atom []) allocs (atom [])]
    (dotimes [_ 10]
      (System/gc)
      (let [b0 (allocated-bytes) t0 (System/nanoTime)
            r (f iterations)
            t1 (System/nanoTime) b1 (allocated-bytes)]
        (swap! times conj (/ (- t1 t0) 1e6))
        (swap! allocs conj (- b1 b0))
        (when (zero? r) nil)))
    (printf "%-10s : %7.2f +/- %5.2f ms   %10d +/- %8d B/call%n"
            label (mean @times) (stddev @times) (long (mean @allocs)) (long (stddev @allocs)))
    {:label label :time-ms (mean @times) :bytes (mean @allocs)}))

(println "=== Particle pattern, UNTYPED defrecord fields, isolated process ===")
(println (str "Java: " (System/getProperty "java.vm.name") " " (System/getProperty "java.vm.version")))
(let [rec (time-calls run-simulation "record")
      nat (time-calls run-native "native")]
  (println (format "%nrecord/native time ratio: %.2fx" (/ (:time-ms rec) (:time-ms nat)))))

(shutdown-agents)
