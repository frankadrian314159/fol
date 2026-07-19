;; CGO 2027 paper, Related Work "Novelty, and why an open world": tests
;; empirically whether Clojure's own JIT (here: GraalVM's Graal compiler,
;; the exact partial-escape-analysis system cited as stadler2014partial)
;; eliminates the identical loop-carried record-accumulator allocation that
;; this paper's ASR pass targets in FOL.
;;
;; Mirrors the paper's own running example (Figure 1 / Table 1 "Particle"):
;; a 2-field record threaded through loop/recur via a helper call, additive
;; per-field updates -- the same shape, same field count, same update style.
;; Uses `defrecord`, matching both reitit's real Methods builder and this
;; paper's own corpus classifier (which searches for defrecord/deftype
;; accumulators, not deftype specifically).
;;
;; Run from the repository root:
;;   clojure -M -e "(load-file \"benchmarks/clojure-comparison/point-bench.clj\")"

(set! *warn-on-reflection* true)
(set! *unchecked-math* :warn-on-boxed)

(defrecord Point [^double x ^double y])

(defn update-point ^Point [^Point p]
  (Point. (+ (.x p) 0.1) (+ (.y p) 0.2)))

(defn run-simulation ^double [^long n]
  (loop [p (Point. 0.0 0.0) i 0]
    (if (< i n)
      (recur (update-point p) (unchecked-inc i))
      (+ (.x p) (.y p)))))

;; --- Native-equivalent control: two unboxed primitive doubles, no record,
;;     no allocation at all -- the same "native ceiling" role Table 1's
;;     mutable defstruct plays for the FOL side. -----------------------------
(defn run-simulation-native ^double [^long n]
  (loop [x 0.0 y 0.0 i 0]
    (if (< i n)
      (recur (+ x 0.1) (+ y 0.2) (unchecked-inc i))
      (+ x y))))

(def iterations (long 5000000))
(def warmup-calls (long 200))
(def timed-calls (long 10))

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

(defn time-calls [f n label]
  ;; Warm-up: enough separate invocations to clear HotSpot/Graal's normal
  ;; tiered-compilation invocation thresholds (unlike FOL/SBCL, which needs
  ;; no warm-up at all -- this asymmetry is itself part of the comparison).
  (dotimes [_ warmup-calls] (f (quot iterations 50)))
  (dotimes [_ 5] (f iterations)) ;; extra warm-up at full size for OSR
  (System/gc)
  (let [times (atom [])
        allocs (atom [])]
    (dotimes [_ timed-calls]
      (System/gc)
      (let [b0 (allocated-bytes)
            t0 (System/nanoTime)
            r (f iterations)
            t1 (System/nanoTime)
            b1 (allocated-bytes)]
        (swap! times conj (/ (- t1 t0) 1e6))
        (swap! allocs conj (- b1 b0))
        (when (zero? (mod (count @times) timed-calls)) r)))
    (printf "%-10s : %8.2f +/- %6.2f ms   %,12d +/- %,10d B/call%n"
            label (mean @times) (stddev @times)
            (long (mean @allocs)) (long (stddev @allocs)))
    {:label label :time-ms (mean @times) :bytes (mean @allocs)}))

(println "=== FOL paper's Particle pattern, ported to Clojure, run under real JIT ===")
(println (str "Java: " (System/getProperty "java.vm.name") " "
              (System/getProperty "java.vm.version")))
(println (str "JVMCI/Graal enabled: "
              (.. (java.lang.management.ManagementFactory/getRuntimeMXBean)
                  getInputArguments)))
(println (format "%,d iterations/call, %d warm-up calls, %d timed calls, System/gc before each%n"
                  iterations warmup-calls timed-calls))

(let [rec (time-calls run-simulation iterations "record")
      nat (time-calls run-simulation-native iterations "native")
      correct? (< (Math/abs (- (run-simulation 1000) (run-simulation-native 1000))) 1e-9)]
  (println (format "%nRecord loop allocated %.1f B/call after JIT warm-up (0 = eliminated by escape analysis)."
                    (:bytes rec)))
  (println (format "Record vs native-equivalent: %.2fx time, correctness sanity check: %s"
                    (/ (:time-ms rec) (:time-ms nat))
                    (if correct? "OK" "FAILED"))))

(shutdown-agents)
