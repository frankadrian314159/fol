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
   ;; Should signal an error due to incorrect type for :age.
