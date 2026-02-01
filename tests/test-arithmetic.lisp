(in-package :fol.integration-tests)

(def-suite arithmetic-suite :in integration-suite)
(def-suite* :arithmetic-tests :in arithmetic-suite)

;;; ---------------------------------------------------------------------------
;;; Basic Arithmetic
;;; ---------------------------------------------------------------------------

(test addition
  "Test + function."
  (fol-is 0 "(+)")
  (fol-is 5 "(+ 5)")
  (fol-is 3 "(+ 1 2)")
  (fol-is 10 "(+ 1 2 3 4)")
  (fol-is 4.0 "(+ 1.5 2.5)"))

(test subtraction
  "Test - function."
  (fol-is -5 "(- 5)")
  (fol-is 7 "(- 10 3)")
  (fol-is 5 "(- 10 3 2)")
  (fol-is 10.0 "(- 10.5 0.5)"))

(test multiplication
  "Test * function."
  (fol-is 1 "(*)")
  (fol-is 5 "(* 5)")
  (fol-is 6 "(* 2 3)")
  (fol-is 24 "(* 2 3 4)")
  (fol-is 3.0 "(* 1.5 2)"))

(test division
  "Test / function."
  (fol-is 1/4 "(/ 4)")
  (fol-is 5 "(/ 10 2)")
  (fol-is 5/2 "(/ 20 4 2)")
  (fol-is 2.5 "(/ 10.0 4)")
  (fol-is 1/3 "(/ 1 3)"))

;;; ---------------------------------------------------------------------------
;;; Math Functions
;;; ---------------------------------------------------------------------------

(test abs-function
  "Test abs function."
  (fol-is 5 "(abs -5)")
  (fol-is 5 "(abs 5)")
  (fol-is 3.14 "(abs -3.14)"))

(test sqrt-function
  "Test sqrt function."
  (fol-is 2.0 "(sqrt 4)")
  (fol-is 3.0 "(sqrt 9)"))

(test expt-function
  "Test expt function."
  (fol-is 8 "(expt 2 3)")
  (fol-is 1024 "(expt 2 10)")
  (fol-is 1/10 "(expt 10 -1)"))

(test mod-function
  "Test mod function."
  (fol-is 1 "(mod 10 3)")
  (fol-is 2 "(mod -10 3)")
  (fol-is -2 "(mod 10 -3)"))

(test rem-function
  "Test rem function."
  (fol-is 1 "(rem 10 3)")
  (fol-is -1 "(rem -10 3)")
  (fol-is 1 "(rem 10 -3)"))

;;; ---------------------------------------------------------------------------
;;; Increment / Decrement
;;; ---------------------------------------------------------------------------

(test inc-function
  "Test inc function."
  (fol-is 1 "(inc 0)")
  (fol-is 6 "(inc 5)")
  (fol-is 0 "(inc -1)")
  (fol-is 3.5 "(inc 2.5)"))

(test dec-function
  "Test dec function."
  (fol-is 4 "(dec 5)")
  (fol-is -1 "(dec 0)")
  (fol-is 0 "(dec 1)")
  (fol-is 2.5 "(dec 3.5)"))

;;; ---------------------------------------------------------------------------
;;; Rounding Functions
;;; ---------------------------------------------------------------------------

(test floor-function
  "Test floor function."
  (fol-is 3 "(floor 3.7)")
  (fol-is -4 "(floor -3.7)"))

(test ceiling-function
  "Test ceiling function."
  (fol-is 4 "(ceiling 3.2)")
  (fol-is -3 "(ceiling -3.7)"))

(test round-function
  "Test round function."
  (fol-is 3 "(round 3.4)")
  (fol-is 4 "(round 3.5)"))

(test truncate-function
  "Test truncate function."
  (fol-is 3 "(truncate 3.7)")
  (fol-is -3 "(truncate -3.7)"))

;;; ---------------------------------------------------------------------------
;;; Number Predicates
;;; ---------------------------------------------------------------------------

(test zero-predicate
  "Test zero? predicate."
  (fol-is-true "(zero? 0)")
  (fol-is-true "(zero? 0.0)")
  (fol-is-false "(zero? 1)")
  (fol-is-false "(zero? -1)"))

(test positive-predicate
  "Test positive? predicate."
  (fol-is-true "(positive? 5)")
  (fol-is-true "(positive? 0.1)")
  (fol-is-false "(positive? 0)")
  (fol-is-false "(positive? -5)"))

(test negative-predicate
  "Test negative? predicate."
  (fol-is-true "(negative? -5)")
  (fol-is-true "(negative? -0.1)")
  (fol-is-false "(negative? 0)")
  (fol-is-false "(negative? 5)"))

(test even-predicate
  "Test even? predicate."
  (fol-is-true "(even? 0)")
  (fol-is-true "(even? 2)")
  (fol-is-true "(even? -4)")
  (fol-is-false "(even? 1)")
  (fol-is-false "(even? -3)"))

(test odd-predicate
  "Test odd? predicate."
  (fol-is-true "(odd? 1)")
  (fol-is-true "(odd? -3)")
  (fol-is-false "(odd? 0)")
  (fol-is-false "(odd? 2)"))

(test nat-int-predicate
  "Test nat-int? predicate."
  (fol-is-true "(nat-int? 0)")
  (fol-is-true "(nat-int? 42)")
  (fol-is-false "(nat-int? -1)")
  (fol-is-false "(nat-int? 3.14)"))

(test pos-int-predicate
  "Test pos-int? predicate."
  (fol-is-true "(pos-int? 1)")
  (fol-is-true "(pos-int? 42)")
  (fol-is-false "(pos-int? 0)")
  (fol-is-false "(pos-int? -1)"))

;;; ---------------------------------------------------------------------------
;;; Type Conversion
;;; ---------------------------------------------------------------------------

(test rationalize-function
  "Test rationalize function."
  (fol-is 1/2 "(rationalize 1/2)")
  (fol-is 5 "(rationalize 5)")
  (fol-is 1/2 "(rationalize 0.5)"))
