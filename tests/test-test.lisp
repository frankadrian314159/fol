(in-package :fol.integration-tests)

(def-suite test-suite :in integration-suite)
(def-suite* :test-tests :in test-suite)

(test destructuring-keys-test
  "Test destructuring with :keys."
  ;; Basic :keys without type annotations
  (fol-is "Alice is 30 years old"
    "(do (defn summarize-person
           ([{:keys [name age] :as person}]
            (str name \" is \" age \" years old\")))
         (summarize-person {:name \"Alice\" :age 30}))")

  ;; :keys with type annotations - additional keys should be ignored
  (fol-is "Bob is 25 years old"
    "(do (defn summarize-typed
           ([{:keys [(name <string>) (age <integer>)]}]
            (str name \" is \" age \" years old\")))
         (summarize-typed {:name \"Bob\" :age 25 :foo 'bar}))")

  ;; Missing keys should result in type error (nil doesn't match <integer>)
  (fol-signals
    fol.eval:fol-type-error
    "(do (defn summarize-missing
           ([{:keys [(name <string>) (age <integer>)]}]
            (str name \" is \" age \" years old\")))
         (summarize-missing {:name \"Charlie\" :foo 'bar}))")
         
  ;; Should signal an error due to incorrect type for :age (string instead of integer)
  (fol-signals
    fol.eval:fol-type-error
    "(do (defn summarize-wrong-type
            ([{:keys [(name <string>) (age <integer>)]}]
             (str name \" is \" age \" years old\")))
        (summarize-wrong-type {:name \"Charlie\" :age \"25\"}))"))

(test destructuring-keys-predicate-test
  "Test destructuring with :keys using predicate patterns."
  ;; Basic predicate pattern - value must be <= 10
  (fol-is 15
    "(bind [{:keys [(x (<= 10))]} {:x 5}]
       (+ x 10))")

  ;; Predicate pattern with type predicate like <number>?
  (fol-is 100
    "(bind [{:keys [(n (<number>?))]} {:n 50}]
       (* n 2))")

  ;; Combining type annotation and predicate pattern
  (fol-is "Value: 7, doubled: 14"
    "(bind [{:keys [(name <string>) (val (<= 10))]} {:name \"Value\" :val 7}]
       (str name \": \" val \", doubled: \" (* val 2)))")

  ;; Predicate with multiple args - (< x 100) means x < 100
  (fol-is 150
    "(bind [{:keys [(x (< 100))]} {:x 50}]
       (* x 3))")

  ;; Failed predicate should signal error
  (fol-signals
    fol.eval:fol-predicate-error
    "(bind [{:keys [(x (<= 10))]} {:x 15}]
       x)")

  ;; Failed type predicate should signal error
  (fol-signals
    fol.eval:fol-predicate-error
    "(bind [{:keys [(n (<number>?))]} {:n \"not-a-number\"}]
       n)"))
