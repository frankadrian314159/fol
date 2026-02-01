(in-package :fol.integration-tests)

(def-suite control-flow-suite :in integration-suite)
(def-suite* :control-flow-tests :in control-flow-suite)

;;; ---------------------------------------------------------------------------
;;; Conditionals
;;; ---------------------------------------------------------------------------

(test if-form
  "Test if special form."
  (fol-is :yes "(if t :yes :no)")
  (fol-is :no "(if nil :yes :no)")
  (fol-is :bigger "(if (> 5 3) :bigger)")
  (fol-is nil "(if (< 5 3) :smaller)"))

(test when-macro
  "Test when macro."
  (fol-is 42 "(when t 42)")
  (fol-is nil "(when nil 42)")
  (fol-is 3 "(when t 1 2 3)"))

(test unless-macro
  "Test unless macro."
  (fol-is 42 "(unless nil 42)")
  (fol-is nil "(unless t 42)")
  (fol-is 3 "(unless nil 1 2 3)"))

(test cond-form
  "Test cond special form."
  (fol-is :negative "(bind [x -5] (cond (< x 0) :negative (= x 0) :zero (> x 0) :positive))")
  (fol-is :zero "(bind [x 0] (cond (< x 0) :negative (= x 0) :zero (> x 0) :positive))")
  (fol-is :positive "(bind [x 5] (cond (< x 0) :negative (= x 0) :zero (> x 0) :positive))"))

(test case-form
  "Test case special form."
  (fol-is :one "(case 1 1 :one 2 :two :other)")
  (fol-is :two "(case 2 1 :one 2 :two :other)")
  (fol-is :other "(case 99 1 :one 2 :two :other)"))

(test if-let-macro
  "Test if-let macro."
  (fol-is 2 "(if-let [x 1] (+ x 1) :default)")
  (fol-is :default "(if-let [x nil] (+ x 1) :default)"))

(test when-let-macro
  "Test when-let macro."
  (fol-is 2 "(when-let [x 1] (+ x 1))")
  (fol-is nil "(when-let [x nil] (+ x 1))"))

(test if-not-macro
  "Test if-not macro."
  (fol-is :yes "(if-not nil :yes :no)")
  (fol-is :no "(if-not t :yes :no)"))

(test when-not-macro
  "Test when-not macro."
  (fol-is 42 "(when-not nil 42)")
  (fol-is nil "(when-not t 42)"))

;;; ---------------------------------------------------------------------------
;;; Binding Forms
;;; ---------------------------------------------------------------------------

(test bind-form
  "Test bind special form."
  (fol-is 3 "(bind [x 1 y 2] (+ x y))")
  (fol-is 2 "(bind [x 1 y (+ x 1)] y)"))

(test bind-destructuring
  "Test bind with destructuring."
  (fol-is 3 "(bind [[a b] [1 2]] (+ a b))")
  (fol-is 6 "(bind [[a [b c]] [1 [2 3]]] (+ a b c))"))

(test bind-rest-destructuring
  "Test bind with rest destructuring."
  (fol-is 3 "(bind [[a b & rest] [1 2 3 4 5]] (size rest))"))

(test bind-map-destructuring
  "Test bind with map destructuring."
  (fol-is 3 "(bind [{:keys [a b]} {:a 1 :b 2}] (+ a b))"))

;;; ---------------------------------------------------------------------------
;;; Functions
;;; ---------------------------------------------------------------------------

(test fn-form
  "Test fn special form."
  (fol-is 10 "((fn [x] (* x 2)) 5)")
  (fol-is 6 "((fn [x y] (+ x y)) 2 4)"))

(test fn-destructuring
  "Test fn with destructuring."
  (fol-is 7 "((fn [[a b]] (+ a b)) [3 4])")
  (fol-is 3 "((fn [x & more] (+ x (first more))) 1 2 3)"))

(test defn-form
  "Test defn macro."
  (fol-is 10 "(do (defn double [x] (* x 2)) (double 5))")
  ;; Use my-add to avoid conflict with fol.seqop:add
  (fol-is 6 "(do (defn my-add [a b] (+ a b)) (my-add 2 4))"))

;;; ---------------------------------------------------------------------------
;;; Loop/Recur
;;; ---------------------------------------------------------------------------

(test loop-recur
  "Test loop/recur."
  (fol-is 55 "(loop [i 1 sum 0] (if (> i 10) sum (recur (+ i 1) (+ sum i))))")
  (fol-is 120 "(loop [n 5 acc 1] (if (<= n 1) acc (recur (- n 1) (* acc n))))"))

;;; ---------------------------------------------------------------------------
;;; Threading Macros
;;; ---------------------------------------------------------------------------

(test thread-first
  "Test -> threading macro."
  (fol-is 16 "(-> 5 (+ 3) (* 2))")
  (fol-is 5 "(-> 10 (- 3) (- 2))"))

(test thread-last
  "Test ->> threading macro."
  (fol-is 16 "(->> 5 (+ 3) (* 2))")
  (fol-is 35 "(->> [1 2 3 4 5] (filter odd?) (map (fn [x] (* x x))) (reduce +))"))

(test some-thread
  "Test some-> threading macro."
  (fol-is 2 "(some-> {:a {:b 1}} :a :b inc)")
  (fol-is nil "(some-> {:a {:b 1}} :c :d)"))

(test cond-thread
  "Test cond-> threading macro."
  (fol-is 4 "(cond-> 1 t (+ 1) nil (+ 10) t (* 2))"))

;;; ---------------------------------------------------------------------------
;;; Iteration Macros
;;; ---------------------------------------------------------------------------

(test dotimes-macro
  "Test dotimes macro."
  (fol-is nil "(dotimes [i 3] i)"))

(test doseq-macro
  "Test doseq macro."
  (fol-is nil "(doseq [x [1 2 3]] x)"))

(test for-macro
  "Test for comprehension."
  (fol-is '(1 4 9) "(into [] (for [x [1 2 3]] (* x x)))"))

;;; ---------------------------------------------------------------------------
;;; Exception Handling
;;; ---------------------------------------------------------------------------

(test try-catch
  "Test try/catch."
  (fol-is :caught "(try (throw \"error\") (catch e :caught))")
  (fol-is 42 "(try 42 (catch e :error))"))

;;; ---------------------------------------------------------------------------
;;; Do Form
;;; ---------------------------------------------------------------------------

(test do-form
  "Test do special form."
  (fol-is 3 "(do 1 2 3)")
  (fol-is nil "(do)"))
