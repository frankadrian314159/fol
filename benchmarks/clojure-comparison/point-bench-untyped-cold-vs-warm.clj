;; Directly tests the paper's claim that the untyped-fields, warmed-up
;; allocation (48 B/iteration) is "indistinguishable from a cold run" --
;; i.e. that Graal's tiered compilation never kicks in any optimization
;; that changes the allocation footprint for this shape. Measures the
;; very first call (zero warm-up, whatever mix of interpreter/OSR/tier-1
;; compilation the JVM uses for it) against the same warmed-up steady
;; state as point-bench-untyped-isolated.clj, in one process each so
;; neither measurement contaminates the other.
;;
;; Run from the repository root:
;;   clojure -M -e "(load-file \"benchmarks/clojure-comparison/point-bench-untyped-cold-vs-warm.clj\")"

(set! *warn-on-reflection* true)

(defrecord Point [x y])
(defn update-point [p]
  (Point. (+ (:x p) 0.1) (+ (:y p) 0.2)))
(defn run-simulation ^double [^long n]
  (loop [p (Point. 0.0 0.0) i 0]
    (if (< i n) (recur (update-point p) (unchecked-inc i)) (+ (:x p) (:y p)))))

(def ^com.sun.management.ThreadMXBean thread-bean
  (cast com.sun.management.ThreadMXBean
        (java.lang.management.ManagementFactory/getThreadMXBean)))
(defn allocated-bytes ^long []
  (.getThreadAllocatedBytes thread-bean (.getId (Thread/currentThread))))

(def iterations (long 5000000))

;; COLD: absolutely the first call in this process, no warm-up at all.
(System/gc)
(let [b0 (allocated-bytes)
      t0 (System/nanoTime)
      r (run-simulation iterations)
      t1 (System/nanoTime)
      b1 (allocated-bytes)]
  (printf "cold (first call, zero warm-up): %.2f ms, %d B/call (%.1f B/iter), result=%s%n"
          (/ (- t1 t0) 1e6) (- b1 b0) (/ (double (- b1 b0)) iterations) r))

(shutdown-agents)
