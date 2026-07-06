(ns fixture.sample)

(defrecord Point [x y])
(defrecord Stats [n mean])

;; (a) record accumulator rebuilt via constructor  -> should be record/strong/ctor
(defn run-a [n]
  (loop [p (->Point 0 0) i 0]
    (if (< i n)
      (recur (->Point (inc (:x p)) (:y p)) (inc i))
      p)))

;; (a) record accumulator rebuilt via assoc/update -> record/strong/assoc
(defn run-a2 [n]
  (loop [p (->Point 0 0) i 0]
    (if (< i n)
      (recur (update p :x inc) (inc i))
      p)))

;; (a) via helper (reduce, record init, helper rebuild) -> record/possible
(defn step [p] (->Point (inc (:x p)) (:y p)))
(defn run-a3 [coll]
  (reduce (fn [acc x] (step acc)) (->Point 0 0) coll))

;; (b) map accumulator rebuilt
(defn run-b [coll]
  (reduce (fn [acc x] (assoc acc x 1)) {} coll))

;; (c) collection accumulator grown
(defn run-c [n]
  (loop [v [] i 0]
    (if (< i n) (recur (conj v i) (inc i)) v)))

;; (d) primitive-scalar loop
(defn run-d [n]
  (loop [zr 0.0 zi 0.0 i 0]
    (if (< i n) (recur (+ zr 1.0) (* zi 2.0) (inc i)) (+ zr zi))))
