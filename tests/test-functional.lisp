(in-package :fol.integration-tests)

(def-suite functional-suite :in integration-suite)
(def-suite* :functional-tests :in functional-suite)

;;; ---------------------------------------------------------------------------
;;; Identity and Constantly
;;; ---------------------------------------------------------------------------

(test identity-function
  "Test identity function."
  (fol-is 42 "(identity 42)")
  (fol-is "hello" "(identity \"hello\")")
  (fol-is '(1 2 3) "(identity '(1 2 3))"))

(test constantly-function
  "Test constantly function."
  (fol-is 42 "((constantly 42))")
  (fol-is 42 "((constantly 42) 1 2 3)"))

;;; ---------------------------------------------------------------------------
;;; Complement
;;; ---------------------------------------------------------------------------

(test complement-function
  "Test complement function."
  (fol-is-true "((complement odd?) 4)")
  (fol-is-false "((complement odd?) 3)")
  (fol-is-true "((complement empty?) [1 2 3])")
  (fol-is-false "((complement empty?) [])"))

;;; ---------------------------------------------------------------------------
;;; Partial Application
;;; ---------------------------------------------------------------------------

(test partial-function
  "Test partial function."
  (fol-is 15 "((partial + 10) 5)")
  (fol-is 16 "((partial + 10) 1 2 3)")
  (fol-is 6 "((partial +) 1 2 3)"))

(test rpartial-function
  "Test rpartial function."
  (fol-is 5 "((rpartial - 10) 15)")
  (fol-is -7 "((rpartial - 10) 3)"))

;;; ---------------------------------------------------------------------------
;;; Composition
;;; ---------------------------------------------------------------------------

(test comp-function
  "Test comp function."
  (fol-is 12 "((comp (fn [x] (* x 2)) inc) 5)")
  (fol-is 3 "((comp inc inc inc) 0)")
  (fol-is 42 "((comp) 42)"))

;;; ---------------------------------------------------------------------------
;;; Conjoin and Disjoin
;;; ---------------------------------------------------------------------------

(test conjoin-function
  "Test conjoin function."
  (fol-is-true "((conjoin positive? even?) 4)")
  (fol-is-false "((conjoin positive? even?) 3)")
  (fol-is-false "((conjoin positive? even?) -4)"))

(test disjoin-function
  "Test disjoin function."
  (fol-is-true "((disjoin positive? zero?) 5)")
  (fol-is-true "((disjoin positive? zero?) 0)")
  (fol-is-false "((disjoin positive? zero?) -3)"))

;;; ---------------------------------------------------------------------------
;;; Juxt
;;; ---------------------------------------------------------------------------

(test juxt-function
  "Test juxt function."
  ;; juxt returns multiple values
  (fol-is 1 "(first ((juxt min max) 3 1 4 1 5 9 2 6))")
  (fol-is 9 "(second ((juxt min max) 3 1 4 1 5 9 2 6))"))

;;; ---------------------------------------------------------------------------
;;; Memoize
;;; ---------------------------------------------------------------------------

(test memoize-function
  "Test memoize function."
  ;; Just test that it returns the same results
  (fol-is 3 "((memoize +) 1 2)")
  (fol-is 3 "((memoize +) 1 2)"))

;;; ---------------------------------------------------------------------------
;;; Fnil
;;; ---------------------------------------------------------------------------

(test fnil-function
  "Test fnil function."
  (fol-is 10 "((fnil + 0) nil 10)")
  (fol-is 15 "((fnil + 0) 5 10)")
  (fol-is 0 "((fnil - 0 0) nil nil)"))

;;; ---------------------------------------------------------------------------
;;; Fn?
;;; ---------------------------------------------------------------------------

(test fn-predicate
  "Test fn? predicate."
  (fol-is-true "(fn? +)")
  (fol-is-true "(fn? (fn [x] x))")
  (fol-is-true "(fn? inc)")
  (fol-is-false "(fn? 42)")
  (fol-is-false "(fn? \"hello\")"))
