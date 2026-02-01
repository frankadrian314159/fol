(in-package :fol.integration-tests)

(def-suite comparison-suite :in integration-suite)
(def-suite* :comparison-tests :in comparison-suite)

;;; ---------------------------------------------------------------------------
;;; Equality
;;; ---------------------------------------------------------------------------

(test equality-operator
  "Test = operator."
  (fol-is-true "(= 1 1)")
  (fol-is-true "(= 1 1 1 1)")
  (fol-is-false "(= 1 2)")
  (fol-is-true "(= \"hello\" \"hello\")")
  (fol-is-true "(= :foo :foo)"))

(test inequality-operator
  "Test /= operator."
  (fol-is-true "(/= 1 2)")
  (fol-is-false "(/= 1 1)")
  (fol-is-true "(/= 1 2 3)"))

;;; ---------------------------------------------------------------------------
;;; Ordering
;;; ---------------------------------------------------------------------------

(test less-than-operator
  "Test < operator."
  (fol-is-true "(< 1 2)")
  (fol-is-true "(< 1 2 3 4)")
  (fol-is-false "(< 2 1)")
  (fol-is-false "(< 1 1)"))

(test greater-than-operator
  "Test > operator."
  (fol-is-true "(> 2 1)")
  (fol-is-true "(> 4 3 2 1)")
  (fol-is-false "(> 1 2)")
  (fol-is-false "(> 1 1)"))

(test less-than-or-equal-operator
  "Test <= operator."
  (fol-is-true "(<= 1 2)")
  (fol-is-true "(<= 1 1)")
  (fol-is-true "(<= 1 2 2 3)")
  (fol-is-false "(<= 2 1)"))

(test greater-than-or-equal-operator
  "Test >= operator."
  (fol-is-true "(>= 2 1)")
  (fol-is-true "(>= 1 1)")
  (fol-is-true "(>= 3 2 2 1)")
  (fol-is-false "(>= 1 2)"))

;;; ---------------------------------------------------------------------------
;;; Min and Max
;;; ---------------------------------------------------------------------------

(test min-function
  "Test min function."
  (fol-is 1 "(min 3 1 4 1 5 9)")
  (fol-is 5 "(min 5)")
  (fol-is -10 "(min 0 -10 5)"))

(test max-function
  "Test max function."
  (fol-is 9 "(max 3 1 4 1 5 9)")
  (fol-is 5 "(max 5)")
  (fol-is 5 "(max 0 -10 5)"))

;;; ---------------------------------------------------------------------------
;;; Logical/Bitwise Operators
;;; ---------------------------------------------------------------------------
;;;
;;; FOL's not/and/or from fol.logop are context-sensitive:
;;; - For booleans: logical operations with short-circuit behavior
;;; - For integers: bitwise operations
;;; Note: Mixing booleans and integers in the same expression is an error.

(test not-operator
  "Test not function (bitwise for integers, logical for booleans)."
  ;; Boolean NOT
  (fol-is-true "(not nil)")
  (fol-is nil "(not t)")
  ;; Bitwise NOT for integers
  (fol-is -2 "(not 1)")
  (fol-is -1 "(not 0)"))

(test and-operator
  "Test and function (bitwise for integers, logical for booleans)."
  ;; Bitwise AND for integers
  (fol-is 0 "(and 1 2 3)")  ; 1 & 2 & 3 = 0
  (fol-is 2 "(and 3 2)")    ; 3 & 2 = 2
  ;; Logical AND for booleans
  (fol-is nil "(and nil t)")  ; short-circuits on nil
  (fol-is-true "(and t t)"))  ; returns last truthy

(test or-operator
  "Test or function (bitwise for integers, logical for booleans)."
  ;; Bitwise OR for integers
  (fol-is 3 "(or 1 2 3)")   ; 1 | 2 | 3 = 3
  (fol-is 3 "(or 1 2)")     ; 1 | 2 = 3
  ;; Logical OR for booleans
  (fol-is-true "(or nil t)")  ; returns truthy value
  (fol-is nil "(or nil nil)"))

;;; ---------------------------------------------------------------------------
;;; Dedicated Bitwise Operators (using fol.bitop functions)
;;; ---------------------------------------------------------------------------

(test bitnot-operator
  "Test bitnot function (bitwise NOT)."
  (fol-is -2 "(bitnot 1)")
  (fol-is -1 "(bitnot 0)"))

(test bitand-operator
  "Test bitand function (bitwise AND)."
  (fol-is 0 "(bitand 1 2 3)")  ; 1 & 2 & 3 = 0
  (fol-is 2 "(bitand 3 2)")  ; 3 & 2 = 2
  (fol-is 1 "(bitand 5 3)"))  ; 5 & 3 = 1

(test bitor-operator
  "Test bitor function (bitwise OR)."
  (fol-is 3 "(bitor 1 2)")  ; 1 | 2 = 3
  (fol-is 7 "(bitor 1 2 4)")  ; 1 | 2 | 4 = 7
  (fol-is 3 "(bitor 1 3)"))  ; 1 | 3 = 3
