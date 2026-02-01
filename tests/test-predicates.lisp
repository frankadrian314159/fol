(in-package :fol.integration-tests)

(def-suite predicates-suite :in integration-suite)
(def-suite* :predicates-tests :in predicates-suite)

;;; ---------------------------------------------------------------------------
;;; Type Predicates
;;; ---------------------------------------------------------------------------

(test number-predicates
  "Test number type predicates."
  (fol-is-true "(<number>? 42)")
  (fol-is-true "(<number>? 3.14)")
  (fol-is-true "(<number>? 1/2)")
  (fol-is-false "(<number>? \"42\")")
  (fol-is-true "(<integer>? 42)")
  (fol-is-false "(<integer>? 3.14)")
  (fol-is-true "(<float>? 3.14)")
  (fol-is-false "(<float>? 42)")
  (fol-is-true "(<ratio>? 1/2)")
  (fol-is-false "(<ratio>? 0.5)"))

(test string-predicate
  "Test string predicate."
  (fol-is-true "(<string>? \"hello\")")
  (fol-is-true "(<string>? \"\")")
  (fol-is-false "(<string>? 42)")
  (fol-is-false "(<string>? :keyword)"))

(test char-predicate
  "Test character predicate."
  ;; Test that the predicate function exists and works for non-chars
  (fol-is-false "(<char>? \"a\")")
  (fol-is-false "(<char>? 65)")
  (fol-is-false "(<char>? nil)"))

(test bool-predicate
  "Test boolean predicate."
  (fol-is-true "(<bool>? t)")
  (fol-is-true "(<bool>? nil)")
  (fol-is-false "(<bool>? 0)")
  (fol-is-false "(<bool>? \"true\")"))

(test symbol-keyword-predicates
  "Test symbol and keyword predicates."
  (fol-is-true "(<keyword>? :foo)")
  (fol-is-true "(<keyword>? :bar-baz)")
  (fol-is-false "(<keyword>? 'foo)")
  (fol-is-true "(<symbol>? 'foo)")
  (fol-is-true "(<symbol>? :foo)"))  ; Keywords are symbols

;;; ---------------------------------------------------------------------------
;;; Collection Predicates
;;; ---------------------------------------------------------------------------

(test vector-predicate
  "Test vector predicate."
  (fol-is-true "(<vector>? [])")
  (fol-is-true "(<vector>? [1 2 3])")
  (fol-is-false "(<vector>? '(1 2 3))")
  (fol-is-false "(<vector>? {})"))

(test list-predicate
  "Test list predicate."
  (fol-is-true "(<list>? (list))")
  (fol-is-true "(<list>? (list 1 2 3))")
  (fol-is-false "(<list>? [])")
  (fol-is-false "(<list>? {})"))

(test dict-predicate
  "Test dict predicate."
  (fol-is-true "(<dict>? {})")
  (fol-is-true "(<dict>? {:a 1})")
  (fol-is-false "(<dict>? [])")
  (fol-is-false "(<dict>? #{})" ))

(test set-predicate
  "Test set predicate."
  (fol-is-true "(<set>? #{})")
  (fol-is-true "(<set>? #{1 2 3})")
  (fol-is-false "(<set>? [])")
  (fol-is-false "(<set>? {})"))

;;; ---------------------------------------------------------------------------
;;; General Predicates
;;; ---------------------------------------------------------------------------

(test nil-predicate
  "Test nil? predicate."
  (fol-is-true "(nil? nil)")
  (fol-is-false "(nil? 0)")
  (fol-is-false "(nil? \"\")"))

(test some-predicate
  "Test some? predicate."
  (fol-is-false "(some? nil)")
  (fol-is-true "(some? 0)")
  (fol-is-true "(some? \"\")"))

;; Note: FOL uses t/nil for booleans, not true/false
;; The true? and false? predicates test for exactly t and nil
(test true-false-predicates
  "Test t and nil as boolean values."
  (fol-is-true "(= t t)")
  (fol-is-true "(nil? nil)")
  (fol-is-false "(nil? t)")
  (fol-is-false "(nil? 0)"))
