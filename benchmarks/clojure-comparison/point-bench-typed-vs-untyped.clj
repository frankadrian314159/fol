;; Consolidated version of point-bench.clj + point-bench-untyped-fields.clj:
;; isolates whether primitive type hints on defrecord fields (not just loop
;; shape) are load-bearing for Graal's escape analysis fully eliminating the
;; allocation. Same protocol (warm-up calls, then timed calls, ThreadMXBean
;; allocation tracking) for typed-field, untyped-field, and native variants
;; of the identical Particle loop shape.
;;
;; Run from the repository root:
;;   clojure -M -e "(load-file \"benchmarks/clojure-comparison/point-bench-typed-vs-untyped.clj\")"

(set! *warn-on-reflection* true)

(defrecord PointTyped [^double x ^double y])
(defn update-point-typed ^PointTyped [^PointTyped p]
  (PointTyped. (+ (.x p) 0.1) (+ (.y p) 0.2)))
(defn run-typed ^double [^long n]
  (loop [p (PointTyped. 0.0 0.0) i 0]
    (if (< i n) (recur (update-point-typed p) (unchecked-inc i)) (+ (.x p) (.y p)))))

(defrecord PointUntyped [x y])
(defn update-point-untyped [p]
  (PointUntyped. (+ (:x p) 0.1) (+ (:y p) 0.2)))
(defn run-untyped ^double [^long n]
  (loop [p (PointUntyped. 0.0 0.0) i 0]
    (if (< i n) (recur (update-point-untyped p) (unchecked-inc i)) (+ (:x p) (:y p)))))

(defn run-native ^double [^long n]
  (loop [x 0.0 y 0.0 i 0]
    (if (< i n) (recur (+ x 0.1) (+ y 0.2) (unchecked-inc i)) (+ x y))))

(def ^com.sun.management.ThreadMXBean thread-bean
  (cast com.sun.management.ThreadMXBean
        (java.lang.management.ManagementFactory/getThreadMXBean)))
(defn allocated-bytes ^long []
  (.getThreadAllocatedBytes thread-bean (.getId (Thread/currentThread))))

(def iterations (long 5000000))
(def warmup-calls (long 200))
(def timed-calls (long 10))

(defn mean [xs] (/ (reduce + xs) (double (count xs))))
(defn stddev [xs]
  (let [m (mean xs) n (count xs)]
    (if (< n 2) 0.0
        (Math/sqrt (/ (reduce + (map #(let [d (- % m)] (* d d)) xs)) (double (dec n)))))))

(defn time-calls [f label]
  (dotimes [_ warmup-calls] (f (quot iterations 50)))
  (dotimes [_ 5] (f iterations))
  (System/gc)
  (let [times (atom []) allocs (atom [])]
    (dotimes [_ timed-calls]
      (System/gc)
      (let [b0 (allocated-bytes) t0 (System/nanoTime)
            r (f iterations)
            t1 (System/nanoTime) b1 (allocated-bytes)]
        (swap! times conj (/ (- t1 t0) 1e6))
        (swap! allocs conj (- b1 b0))
        (when (zero? r) nil)))
    (printf "%-16s : %7.2f +/- %5.2f ms   %6d +/- %4d B/call%n"
            label (mean @times) (stddev @times) (long (mean @allocs)) (long (stddev @allocs)))
    {:label label :time-ms (mean @times) :bytes (mean @allocs)}))

(println "=== Particle pattern: typed vs. untyped defrecord fields vs. native ===")
(println (str "Java: " (System/getProperty "java.vm.name") " " (System/getProperty "java.vm.version")))
(printf "%,d iterations/call, %d warm-up calls, %d timed calls, System/gc before each%n%n"
        iterations warmup-calls timed-calls)

(let [typed (time-calls run-typed "typed fields")
      untyped (time-calls run-untyped "untyped fields")
      native (time-calls run-native "native")]
  (println (format "%ntyped/native   time ratio: %.2fx" (/ (:time-ms typed) (:time-ms native))))
  (println (format "untyped/native time ratio: %.2fx" (/ (:time-ms untyped) (:time-ms native)))))

(shutdown-agents)
