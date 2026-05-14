;;;; =============================================================================
;;;; Clojure Synthetic Benchmarks (Table 3 Comparison)
;;;; Equivalent to FOL dispatch caching paper Section 7.1 validation benchmarks
;;;; =============================================================================
;;;;
;;;; These benchmarks implement the same workload patterns as the FOL version,
;;;; using Clojure multimethods (predicate-based dispatch, no caching).
;;;; Results directly compare Clojure's runtime dispatch vs FOL's cached dispatch.
;;;;
;;;; Workloads:
;;;; 1. Type-only:     K=5 types, predicate=(type x)
;;;; 2. AST visitor:   K=8 types, predicate=(ast-type node)
;;;; 3. Numeric:       K=5 ranges, predicate=(numeric-category x)
;;;; 4. Bursty:        K=8 types, bursty access pattern (80% hits on 20% of types)
;;;; 5. Single-type:   K=1 type, predicate=(single-type? x)

(ns clojure-synthetic-benchmarks
  (:require [clojure.core :as core]))

;; =============================================================================
;; Workload 1: Type-only (K=5)
;; =============================================================================

(defmulti process-type-only (fn [x] (type x)))

(defmethod process-type-only java.lang.Long [x]
  (+ x 1))

(defmethod process-type-only java.lang.Double [x]
  (* x 2.0))

(defmethod process-type-only java.lang.String [x]
  (str x "!"))

(defmethod process-type-only clojure.lang.PersistentVector [x]
  (conj x 0))

(defmethod process-type-only clojure.lang.PersistentHashMap [x]
  (assoc x :key "value"))

(defmethod process-type-only :default [x]
  x)

(defn benchmark-type-only []
  (let [objects [42 3.14 "hello" [1 2 3] {:a 1}]
        iterations 1000]
    (let [start (System/currentTimeMillis)
          _ (dotimes [i iterations]
              (let [idx (mod i (count objects))]
                (process-type-only (nth objects idx))))
          elapsed (- (System/currentTimeMillis) start)]
      {:workload "Type-only"
       :K 5
       :M iterations
       :elapsed-ms (max 1.0 elapsed)
       :ops-per-ms (if (zero? elapsed) 0.0 (/ iterations (max 1.0 elapsed)))})))

;; =============================================================================
;; Workload 2: AST visitor (K=8)
;; =============================================================================
;; Simulate AST node types

(defrecord LiteralNode [value])
(defrecord SymbolNode [name])
(defrecord CallNode [fn args])
(defrecord IfNode [test then else])
(defrecord DoNode [forms])
(defrecord BindNode [bindings body])
(defrecord FnNode [clauses])
(defrecord DefnNode [name clauses])

(defmulti visit-ast (fn [node] (type node)))

(defmethod visit-ast LiteralNode [node]
  (:value node))

(defmethod visit-ast SymbolNode [node]
  (symbol (:name node)))

(defmethod visit-ast CallNode [node]
  (list (:fn node) (:args node)))

(defmethod visit-ast IfNode [node]
  `(if ~(:test node) ~(:then node) ~(:else node)))

(defmethod visit-ast DoNode [node]
  `(do ~@(:forms node)))

(defmethod visit-ast BindNode [node]
  `(let ~(:bindings node) ~(:body node)))

(defmethod visit-ast FnNode [node]
  `(fn ~@(:clauses node)))

(defmethod visit-ast DefnNode [node]
  `(defn ~(:name node) ~@(:clauses node)))

(defmethod visit-ast :default [node]
  node)

(defn benchmark-ast-visitor []
  (let [ast-nodes [(LiteralNode. 42)
                   (SymbolNode. "x")
                   (CallNode. 'foo '[1 2 3])
                   (IfNode. (SymbolNode. "x") (LiteralNode. 1) (LiteralNode. 0))
                   (DoNode. [(LiteralNode. 1) (LiteralNode. 2)])
                   (BindNode. '[x 1] (SymbolNode. "x"))
                   (FnNode. '[])
                   (DefnNode. "foo" '[])]
        iterations 1000]
    (let [start (System/currentTimeMillis)
          _ (dotimes [i iterations]
              (let [idx (mod i (count ast-nodes))]
                (visit-ast (nth ast-nodes idx))))
          elapsed (- (System/currentTimeMillis) start)]
      {:workload "AST visitor"
       :K 8
       :M iterations
       :elapsed-ms elapsed
       :ops-per-ms (/ iterations elapsed)})))

;; =============================================================================
;; Workload 3: Numeric (K=5)
;; =============================================================================

(defmulti numeric-category (fn [x]
                             (cond
                               (< x 0) :negative
                               (= x 0) :zero
                               (< x 100) :small
                               (< x 1000) :medium
                               :else :large)))

(defmethod numeric-category :negative [x]
  (- x))

(defmethod numeric-category :zero [x]
  0)

(defmethod numeric-category :small [x]
  (+ x 10))

(defmethod numeric-category :medium [x]
  (+ x 100))

(defmethod numeric-category :large [x]
  (+ x 1000))

(defn benchmark-numeric []
  (let [values [-50 0 50 500 5000]
        iterations 1000]
    (let [start (System/currentTimeMillis)
          _ (dotimes [i iterations]
              (let [idx (mod i (count values))]
                (numeric-category (nth values idx))))
          elapsed (- (System/currentTimeMillis) start)]
      {:workload "Numeric"
       :K 5
       :M iterations
       :elapsed-ms elapsed
       :ops-per-ms (/ iterations elapsed)})))

;; =============================================================================
;; Workload 4: Bursty (K=8, 80% hits on 20% of types)
;; =============================================================================
;; Simulate bursty access: most calls go to 1-2 types out of 8

(defmulti process-bursty (fn [x] (type x)))

(defmethod process-bursty java.lang.Long [x] (+ x 1))
(defmethod process-bursty java.lang.Double [x] (* x 2.0))
(defmethod process-bursty java.lang.String [x] (str x "!"))
(defmethod process-bursty clojure.lang.PersistentVector [x] (conj x 0))
(defmethod process-bursty clojure.lang.PersistentHashMap [x] (assoc x :k "v"))
(defmethod process-bursty clojure.lang.PersistentList [x] (cons 0 x))
(defmethod process-bursty clojure.lang.PersistentHashSet [x] (conj x 0))
(defmethod process-bursty clojure.lang.Keyword [x] (str x))
(defmethod process-bursty :default [x] x)

(defn benchmark-bursty []
  (let [; 80% hits: mostly Long and Double
        bursty-objects (vec (concat
                              (repeat 400 42)           ; 400 Long (40%)
                              (repeat 400 3.14)         ; 400 Double (40%)
                              (repeat 50 "hello")       ; 50 String (5%)
                              (repeat 50 [1 2 3])       ; 50 Vector (5%)
                              (repeat 25 {:a 1})        ; 25 Map (2.5%)
                              (repeat 25 '(1 2 3))      ; 25 List (2.5%)
                              (repeat 25 #{1 2 3})      ; 25 Set (2.5%)
                              (repeat 25 :keyword)))    ; 25 Keyword (2.5%)
        iterations 1000]
    (let [start (System/currentTimeMillis)
          _ (dotimes [i iterations]
              (let [idx (rand-int (count bursty-objects))]
                (process-bursty (nth bursty-objects idx))))
          elapsed (- (System/currentTimeMillis) start)]
      {:workload "Bursty"
       :K 8
       :M iterations
       :elapsed-ms elapsed
       :ops-per-ms (/ iterations elapsed)})))

;; =============================================================================
;; Workload 5: Single-type (K=1)
;; =============================================================================

(defmulti process-single-type (fn [x] (type x)))

(defmethod process-single-type java.lang.Long [x]
  (+ x 1))

(defmethod process-single-type :default [x]
  x)

(defn benchmark-single-type []
  (let [objects (vec (repeat 10000 42))  ; K=1: only Long (larger dataset)
        iterations 10000]
    (let [start (System/currentTimeMillis)
          _ (dotimes [i iterations]
              (process-single-type (nth objects i)))
          elapsed (- (System/currentTimeMillis) start)]
      {:workload "Single-type"
       :K 1
       :M iterations
       :elapsed-ms (max 1.0 elapsed)  ; Avoid divide by zero
       :ops-per-ms (if (zero? elapsed) 0.0 (/ iterations (max 1.0 elapsed)))})))

;; =============================================================================
;; Main: Run all benchmarks
;; =============================================================================

(defn run-all-benchmarks []
  (println "=============================================================================")
  (println "Clojure Synthetic Benchmarks (Table 3 Comparison)")
  (println "Using predicate-based dispatch via multimethods (no caching)")
  (println "=============================================================================")
  (println)

  (let [results [(benchmark-type-only)
                 (benchmark-ast-visitor)
                 (benchmark-numeric)
                 (benchmark-bursty)
                 (benchmark-single-type)]]

    (println "Results (Clojure, no caching):")
    (println)
    (println "Workload        | K | M    | Time (ms) | Ops/ms")
    (println "---------------------+---+------+-----------+----------")
    (doseq [result results]
      (printf "%-15s | %d | %4d | %9.1f | %8.2f\n"
              (:workload result)
              (:K result)
              (:M result)
              (double (:elapsed-ms result))
              (double (:ops-per-ms result))))
    (println)
    (println "Note: Clojure uses predicate-based dispatch (multimethods)")
    (println "      No caching is applied; all predicates recomputed at every call")
    (println)

    results))

;; Run benchmarks if executed as a script
(when (= (str *ns*) "user")
  (run-all-benchmarks))
