(set! *warn-on-reflection* true)

(defrecord Point [x y])

(defn update-point [p]
  (Point. (+ (:x p) 0.1) (+ (:y p) 0.2)))

(defn run-simulation ^double [^long n]
  (loop [p (Point. 0.0 0.0) i 0]
    (if (< i n)
      (recur (update-point p) (unchecked-inc i))
      (+ (:x p) (:y p)))))

(def ^com.sun.management.ThreadMXBean thread-bean
  (cast com.sun.management.ThreadMXBean
        (java.lang.management.ManagementFactory/getThreadMXBean)))

(defn allocated-bytes ^long []
  (.getThreadAllocatedBytes thread-bean (.getId (Thread/currentThread))))

(def iterations (long 5000000))

(dotimes [_ 200] (run-simulation (quot iterations 50)))
(dotimes [_ 5] (run-simulation iterations))
(System/gc)
(dotimes [_ 5]
  (System/gc)
  (let [b0 (allocated-bytes)
        t0 (System/nanoTime)
        r (run-simulation iterations)
        t1 (System/nanoTime)
        b1 (allocated-bytes)]
    (printf "untyped-fields record: %.2f ms, %d B/call, result=%s%n"
            (/ (- t1 t0) 1e6) (- b1 b0) r)))
(shutdown-agents)
