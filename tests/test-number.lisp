(in-package :fol.tests)

;;; ============================================================================
;;; Number Tests - Comprehensive test suite for FOL number operations
;;; ============================================================================

(def-suite* :fol.number-tests)

;;; ---------------------------------------------------------------------------
;;; Number Type Predicate Tests
;;; ---------------------------------------------------------------------------

(test number-predicate-raw
  "Test <number>? predicate with raw numbers."
  (is-true (<number>? 0))
  (is-true (<number>? 42))
  (is-true (<number>? -17))
  (is-true (<number>? 3.14))
  (is-true (<number>? 1/2))
  (is-true (<number>? #c(1 2))))

(test number-predicate-wrapped
  "Test <number>? predicate with wrapped numbers."
  (is-true (<number>? (wrap-number 42)))
  (is-true (<number>? (wrap-number 3.14)))
  (is-true (<number>? (wrap-number 1/2))))

(test number-predicate-non-numbers
  "Test <number>? predicate returns NIL for non-numbers."
  (is-false (<number>? "42"))
  (is-false (<number>? 'forty-two))
  (is-false (<number>? t))
  (is-false (<number>? nil))
  (is-false (<number>? #\0)))

;;; ---------------------------------------------------------------------------
;;; Integer Type Predicates
;;; ---------------------------------------------------------------------------

(test integer-predicate-raw
  "Test <integer>? predicate with raw integers."
  (is-true (<integer>? 0))
  (is-true (<integer>? 42))
  (is-true (<integer>? -17))
  (is-true (<integer>? most-positive-fixnum))
  (is-true (<integer>? most-negative-fixnum)))

(test integer-predicate-non-integers
  "Test <integer>? predicate returns NIL for non-integers."
  (is-false (<integer>? 3.14))
  (is-false (<integer>? 1/2))
  (is-false (<integer>? #c(1 2)))
  (is-false (<integer>? "42")))

(test fixnum-predicate
  "Test <fixnum>? predicate."
  (is-true (<fixnum>? 0))
  (is-true (<fixnum>? 42))
  (is-true (<fixnum>? most-positive-fixnum))
  (is-true (<fixnum>? most-negative-fixnum))
  (is-false (<fixnum>? 3.14))
  (is-false (<fixnum>? 1/2)))

(test bignum-predicate
  "Test <bignum>? predicate."
  (let ((big (1+ most-positive-fixnum)))
    (is-true (<bignum>? big))
    (is-true (<bignum>? (- big)))
    (is-false (<bignum>? 42))
    (is-false (<bignum>? 3.14))))

;;; ---------------------------------------------------------------------------
;;; Float Type Predicates
;;; ---------------------------------------------------------------------------

(test float-predicate
  "Test <float>? predicate."
  (is-true (<float>? 3.14))
  (is-true (<float>? 0.0))
  (is-true (<float>? -1.5))
  (is-true (<float>? 1.0d0))
  (is-false (<float>? 42))
  (is-false (<float>? 1/2)))

(test single-float-predicate
  "Test <single-float>? predicate."
  (is-true (<single-float>? 3.14))
  (is-true (<single-float>? 0.0))
  (is-false (<single-float>? 1.0d0))
  (is-false (<single-float>? 42)))

(test double-float-predicate
  "Test <double-float>? predicate."
  (is-true (<double-float>? 1.0d0))
  (is-true (<double-float>? 3.14159265358979d0))
  (is-false (<double-float>? 3.14))
  (is-false (<double-float>? 42)))

;;; ---------------------------------------------------------------------------
;;; Rational Type Predicates
;;; ---------------------------------------------------------------------------

(test rational-predicate
  "Test <rational>? predicate."
  (is-true (<rational>? 42))
  (is-true (<rational>? 1/2))
  (is-true (<rational>? -3/4))
  (is-false (<rational>? 3.14))
  (is-false (<rational>? #c(1 2))))

(test ratio-predicate
  "Test <ratio>? predicate."
  (is-true (<ratio>? 1/2))
  (is-true (<ratio>? -3/4))
  (is-true (<ratio>? 22/7))
  (is-false (<ratio>? 42))       ; integers are not ratios
  (is-false (<ratio>? 4/2))      ; reduces to integer
  (is-false (<ratio>? 3.14)))

;;; ---------------------------------------------------------------------------
;;; Real Type Predicate
;;; ---------------------------------------------------------------------------

(test real-predicate
  "Test <real>? predicate."
  (is-true (<real>? 42))
  (is-true (<real>? 3.14))
  (is-true (<real>? 1/2))
  (is-false (<real>? #c(1 2)))
  (is-false (<real>? #c(1.0 2.0))))

;;; ---------------------------------------------------------------------------
;;; Complex Type Predicate
;;; ---------------------------------------------------------------------------

(test complex-predicate
  "Test <complex>? predicate."
  (is-true (<complex>? #c(1 2)))
  (is-true (<complex>? #c(1.0 2.0)))
  (is-true (<complex>? #c(0 1)))
  (is-false (<complex>? 42))
  (is-false (<complex>? 3.14)))

;;; ---------------------------------------------------------------------------
;;; Number Wrapping/Unwrapping Tests
;;; ---------------------------------------------------------------------------

(test number-wrap-integer
  "Test wrapping of integers."
  (let ((wrapped (wrap-number 42)))
    (is (typep wrapped '<fixnum>))
    (is (= 42 (fol-value wrapped)))
    (is (= 42 (unwrap-number wrapped)))))

(test number-wrap-bignum
  "Test wrapping of bignums."
  (let* ((big (1+ most-positive-fixnum))
         (wrapped (wrap-number big)))
    (is (typep wrapped '<bignum>))
    (is (= big (fol-value wrapped)))))

(test number-wrap-single-float
  "Test wrapping of single floats."
  (let ((wrapped (wrap-number 3.14)))
    (is (typep wrapped '<single-float>))
    (is (= 3.14 (fol-value wrapped)))))

(test number-wrap-double-float
  "Test wrapping of double floats."
  (let ((wrapped (wrap-number 3.14d0)))
    (is (typep wrapped '<double-float>))
    (is (= 3.14d0 (fol-value wrapped)))))

(test number-wrap-ratio
  "Test wrapping of ratios."
  (let ((wrapped (wrap-number 1/2)))
    (is (typep wrapped '<ratio>))
    (is (= 1/2 (fol-value wrapped)))))

(test number-wrap-complex
  "Test wrapping of complex numbers."
  (let ((wrapped (wrap-number #c(1 2))))
    (is (typep wrapped '<complex>))
    (is (= #c(1 2) (fol-value wrapped)))))

(test number-fol-value-raw
  "Test fol-value on raw numbers (pass-through)."
  (is (= 42 (fol-value 42)))
  (is (= 3.14 (fol-value 3.14)))
  (is (= 1/2 (fol-value 1/2)))
  (is (= #c(1 2) (fol-value #c(1 2)))))

(test number-fol-type-of
  "Test fol-type-of for numbers."
  (is (eq '<fixnum> (fol-type-of 42)))
  (is (eq '<single-float> (fol-type-of 3.14)))
  (is (eq '<double-float> (fol-type-of 3.14d0)))
  (is (eq '<ratio> (fol-type-of 1/2)))
  (is (eq '<complex> (fol-type-of #c(1 2)))))

;;; ---------------------------------------------------------------------------
;;; Numeric Property Predicates
;;; ---------------------------------------------------------------------------

(test number-odd-raw
  "Test odd? predicate with raw integers."
  (is-true (odd? 1))
  (is-true (odd? 3))
  (is-true (odd? -1))
  (is-true (odd? -3))
  (is-false (odd? 0))
  (is-false (odd? 2))
  (is-false (odd? -2)))

(test number-odd-wrapped
  "Test odd? predicate with wrapped integers."
  (is-true (odd? (wrap-number 1)))
  (is-true (odd? (wrap-number -3)))
  (is-false (odd? (wrap-number 0)))
  (is-false (odd? (wrap-number 2))))

(test number-odd-error
  "Test odd? signals error for non-integers."
  (signals error (odd? 3.14))
  (signals error (odd? 1/2))
  (signals error (odd? "1")))

(test number-even-raw
  "Test even? predicate with raw integers."
  (is-true (even? 0))
  (is-true (even? 2))
  (is-true (even? -2))
  (is-true (even? 100))
  (is-false (even? 1))
  (is-false (even? -1)))

(test number-even-wrapped
  "Test even? predicate with wrapped integers."
  (is-true (even? (wrap-number 0)))
  (is-true (even? (wrap-number 2)))
  (is-false (even? (wrap-number 1))))

(test number-even-error
  "Test even? signals error for non-integers."
  (signals error (even? 3.14))
  (signals error (even? 1/2)))

(test number-zero-raw
  "Test zero? predicate with raw numbers."
  (is-true (zero? 0))
  (is-true (zero? 0.0))
  (is-true (zero? 0.0d0))
  (is-true (zero? #c(0 0)))
  (is-false (zero? 1))
  (is-false (zero? -1))
  (is-false (zero? 0.001)))

(test number-zero-wrapped
  "Test zero? predicate with wrapped numbers."
  (is-true (zero? (wrap-number 0)))
  (is-true (zero? (wrap-number 0.0)))
  (is-false (zero? (wrap-number 1))))

(test number-zero-error
  "Test zero? signals error for non-numbers."
  (signals error (zero? "0")))

(test number-positive-raw
  "Test positive? predicate with raw numbers."
  (is-true (positive? 1))
  (is-true (positive? 0.001))
  (is-true (positive? 1/1000))
  (is-false (positive? 0))
  (is-false (positive? -1))
  (is-false (positive? -0.001)))

(test number-positive-wrapped
  "Test positive? predicate with wrapped numbers."
  (is-true (positive? (wrap-number 1)))
  (is-true (positive? (wrap-number 0.5)))
  (is-false (positive? (wrap-number 0)))
  (is-false (positive? (wrap-number -1))))

(test number-positive-error
  "Test positive? signals error for complex numbers."
  (signals error (positive? #c(1 2))))

(test number-negative-raw
  "Test negative? predicate with raw numbers."
  (is-true (negative? -1))
  (is-true (negative? -0.001))
  (is-true (negative? -1/1000))
  (is-false (negative? 0))
  (is-false (negative? 1))
  (is-false (negative? 0.001)))

(test number-negative-wrapped
  "Test negative? predicate with wrapped numbers."
  (is-true (negative? (wrap-number -1)))
  (is-true (negative? (wrap-number -0.5)))
  (is-false (negative? (wrap-number 0)))
  (is-false (negative? (wrap-number 1))))

(test number-negative-error
  "Test negative? signals error for complex numbers."
  (signals error (negative? #c(-1 2))))

(test number-integral-raw
  "Test integral? predicate with raw numbers."
  (is-true (integral? 0))
  (is-true (integral? 42))
  (is-true (integral? -17))
  (is-false (integral? 3.14))
  (is-false (integral? 1/2))
  (is-false (integral? #c(1 2))))

(test number-integral-wrapped
  "Test integral? predicate with wrapped numbers."
  (is-true (integral? (wrap-number 42)))
  (is-false (integral? (wrap-number 3.14)))
  (is-false (integral? (wrap-number 1/2))))

;;; ---------------------------------------------------------------------------
;;; Arithmetic Operations with Mixed Types
;;; ---------------------------------------------------------------------------

(test number-arithmetic-mixed-add
  "Test addition with mixed raw and wrapped numbers."
  (let ((a (wrap-number 10))
        (b (wrap-number 20)))
    (is (= 30 (+ a b)))
    (is (= 30 (+ a 20)))
    (is (= 30 (+ 10 b)))
    (is (= 30 (+ 10 20)))))

(test number-arithmetic-mixed-subtract
  "Test subtraction with mixed raw and wrapped numbers."
  (let ((a (wrap-number 30))
        (b (wrap-number 10)))
    (is (= 20 (- a b)))
    (is (= 20 (- a 10)))
    (is (= 20 (- 30 b)))))

(test number-arithmetic-mixed-multiply
  "Test multiplication with mixed raw and wrapped numbers."
  (let ((a (wrap-number 5))
        (b (wrap-number 6)))
    (is (= 30 (* a b)))
    (is (= 30 (* a 6)))
    (is (= 30 (* 5 b)))))

(test number-arithmetic-mixed-divide
  "Test division with mixed raw and wrapped numbers."
  (let ((a (wrap-number 30))
        (b (wrap-number 5)))
    (is (= 6 (/ a b)))
    (is (= 6 (/ a 5)))
    (is (= 6 (/ 30 b)))))

;;; ---------------------------------------------------------------------------
;;; Comparison Operations with Mixed Types
;;; ---------------------------------------------------------------------------

(test number-comparison-equality
  "Test equality with mixed raw and wrapped numbers."
  (let ((a (wrap-number 42))
        (b (wrap-number 42)))
    (is-true (%= a b))
    (is-true (%= a 42))
    (is-true (%= 42 b))
    (is-true (%= 42 42))))

(test number-comparison-less-than
  "Test less-than with mixed raw and wrapped numbers."
  (let ((a (wrap-number 10))
        (b (wrap-number 20)))
    (is-true (%< a b))
    (is-true (%< a 20))
    (is-true (%< 10 b))
    (is-false (%< b a))))

(test number-comparison-greater-than
  "Test greater-than with mixed raw and wrapped numbers."
  (let ((a (wrap-number 20))
        (b (wrap-number 10)))
    (is-true (%> a b))
    (is-true (%> a 10))
    (is-true (%> 20 b))))

(test number-comparison-less-equal
  "Test less-equal with mixed raw and wrapped numbers."
  (let ((a (wrap-number 10))
        (b (wrap-number 10)))
    (is-true (%<= a b))
    (is-true (%<= a 10))
    (is-true (%<= a 20))))

(test number-comparison-greater-equal
  "Test greater-equal with mixed raw and wrapped numbers."
  (let ((a (wrap-number 20))
        (b (wrap-number 20)))
    (is-true (%>= a b))
    (is-true (%>= a 20))
    (is-true (%>= a 10))))

;;; ---------------------------------------------------------------------------
;;; Edge Cases and Special Values
;;; ---------------------------------------------------------------------------

(test number-zero-variations
  "Test operations with various zero representations."
  (is-true (%= 0 0.0))
  (is-true (%= 0 0.0d0))
  (is-true (zero? 0))
  (is-true (zero? 0.0))
  (is-true (zero? (wrap-number 0))))

(test number-negative-zero
  "Test negative zero handling."
  (is-true (%= 0.0 -0.0))
  (is-true (zero? -0.0)))

(test number-type-promotion
  "Test that arithmetic promotes types correctly."
  ;; integer + float -> float
  (let ((result (+ 1 0.5)))
    (is (floatp result)))
  ;; integer + ratio -> ratio or integer
  (let ((result (+ 1 1/2)))
    (is (rationalp result))))

(test number-large-values
  "Test operations with large values."
  (let ((big (wrap-number most-positive-fixnum)))
    (is-true (<integer>? big))
    (is-true (positive? big))
    (is-false (zero? big))))

(test number-small-fractions
  "Test operations with small fractions."
  (let ((small (wrap-number 1/1000000)))
    (is-true (<ratio>? small))
    (is-true (positive? small))
    (is-false (zero? small))
    (is (= 1/1000000 (fol-value small)))))

;;; ---------------------------------------------------------------------------
;;; Variadic Comparison Operations
;;; ---------------------------------------------------------------------------

(test number-variadic-equality
  "Test variadic equality with wrapped numbers."
  (let ((a (wrap-number 5))
        (b (wrap-number 5))
        (c (wrap-number 5)))
    (is-true (= a b c))
    (is-true (= 5 a 5 b))))

(test number-variadic-less-than
  "Test variadic less-than with wrapped numbers."
  (let ((a (wrap-number 1))
        (b (wrap-number 2))
        (c (wrap-number 3)))
    (is-true (< a b c))
    (is-true (< 0 a b c 4))))

(test number-variadic-greater-than
  "Test variadic greater-than with wrapped numbers."
  (let ((a (wrap-number 3))
        (b (wrap-number 2))
        (c (wrap-number 1)))
    (is-true (> a b c))
    (is-true (> 4 a b c 0))))

;;; ---------------------------------------------------------------------------
;;; Min/Max with Wrapped Numbers
;;; ---------------------------------------------------------------------------

(test number-min-max-wrapped
  "Test min/max with wrapped numbers."
  (let ((a (wrap-number 10))
        (b (wrap-number 20))
        (c (wrap-number 15)))
    (is (= 10 (min a b c)))
    (is (= 20 (max a b c)))
    (is (= 5 (min a 5)))
    (is (= 25 (max b 25)))))
