(in-package :fol.tests)

(def-suite arithop-suite
  :description "Tests for FOL arithmetic operations"
  :in fol-suite)

(in-suite arithop-suite)

;;; ============================================================================
;;; Binary Primitive Operations (%+, %-, %*, %/)
;;; ============================================================================

(test binary-addition-raw
  "Test %+ with raw CL numbers"
  ;; Integers
  (is (cl:= 5 (%+ 2 3)))
  (is (cl:= 0 (%+ 0 0)))
  (is (cl:= -1 (%+ 2 -3)))
  (is (cl:= 0 (%+ -5 5)))
  ;; Floats
  (is (cl:= 5.5 (%+ 2.5 3.0)))
  (is (cl:< (cl:abs (cl:- (%+ 0.1 0.2) 0.3)) 0.0001))
  ;; Ratios
  (is (cl:= 1 (%+ 1/2 1/2)))
  (is (cl:= 5/6 (%+ 1/2 1/3)))
  ;; Mixed numeric types
  (is (cl:= 3.5 (%+ 1 2.5)))
  (is (cl:= 5/2 (%+ 2 1/2)))
  ;; Large numbers
  (is (cl:= 20000000000 (%+ 10000000000 10000000000))))

(test binary-addition-wrapped
  "Test %+ with wrapped FOL numbers"
  (let ((w2 (wrap 2))
        (w3 (wrap 3)))
    (is (cl:= 5 (%+ w2 w3)))
    (is (cl:= 5 (%+ w2 3)))
    (is (cl:= 5 (%+ 2 w3)))))

(test binary-subtraction-raw
  "Test %- with raw CL numbers"
  (is (cl:= -1 (%- 2 3)))
  (is (cl:= 0 (%- 5 5)))
  (is (cl:= 5 (%- 2 -3)))
  (is (cl:= -10 (%- -5 5)))
  (is (cl:= 1.5 (%- 4.0 2.5)))
  (is (cl:= 1/6 (%- 1/2 1/3))))

(test binary-subtraction-wrapped
  "Test %- with wrapped FOL numbers"
  (let ((w5 (wrap 5))
        (w3 (wrap 3)))
    (is (cl:= 2 (%- w5 w3)))
    (is (cl:= 2 (%- w5 3)))
    (is (cl:= 2 (%- 5 w3)))))

(test binary-multiplication-raw
  "Test %* with raw CL numbers"
  (is (cl:= 6 (%* 2 3)))
  (is (cl:= 0 (%* 0 100)))
  (is (cl:= -6 (%* 2 -3)))
  (is (cl:= 6 (%* -2 -3)))
  (is (cl:= 6.0 (%* 2.0 3.0)))
  (is (cl:= 1/6 (%* 1/2 1/3))))

(test binary-multiplication-wrapped
  "Test %* with wrapped FOL numbers"
  (let ((w2 (wrap 2))
        (w3 (wrap 3)))
    (is (cl:= 6 (%* w2 w3)))
    (is (cl:= 6 (%* w2 3)))
    (is (cl:= 6 (%* 2 w3)))))

(test binary-division-raw
  "Test %/ with raw CL numbers"
  (is (cl:= 2 (%/ 6 3)))
  (is (cl:= 2/3 (%/ 2 3)))
  (is (cl:= -2 (%/ 6 -3)))
  (is (cl:= 2.0 (%/ 6.0 3.0)))
  (is (cl:= 3/2 (%/ 1/2 1/3))))

(test binary-division-wrapped
  "Test %/ with wrapped FOL numbers"
  (let ((w6 (wrap 6))
        (w3 (wrap 3)))
    (is (cl:= 2 (%/ w6 w3)))
    (is (cl:= 2 (%/ w6 3)))
    (is (cl:= 2 (%/ 6 w3)))))

(test binary-division-by-zero
  "Test %/ division by zero signals error"
  (signals error (%/ 1 0)))

;;; ============================================================================
;;; Variadic Arithmetic Operations (+, -, *, /)
;;; ============================================================================

(test variadic-addition
  "Test + with varying number of arguments"
  ;; Zero arguments - identity
  (is (cl:= 0 (+)))
  ;; One argument - returns value
  (is (cl:= 5 (+ 5)))
  (is (cl:= 5 (+ (wrap 5))))
  ;; Two arguments
  (is (cl:= 7 (+ 3 4)))
  ;; Multiple arguments
  (is (cl:= 15 (+ 1 2 3 4 5)))
  (is (cl:= 10.5 (+ 1 2.5 3 4)))
  ;; Mixed raw and wrapped
  (is (cl:= 10 (+ 1 (wrap 2) 3 (wrap 4)))))

(test variadic-subtraction
  "Test - with varying number of arguments"
  ;; One argument - negation
  (is (cl:= -5 (- 5)))
  (is (cl:= 5 (- -5)))
  (is (cl:= -5 (- (wrap 5))))
  ;; Two arguments
  (is (cl:= 1 (- 5 4)))
  ;; Multiple arguments - left-to-right reduction
  (is (cl:= -5 (- 10 5 5 5)))
  (is (cl:= 0 (- 10 5 3 2))))

(test variadic-multiplication
  "Test * with varying number of arguments"
  ;; Zero arguments - identity
  (is (cl:= 1 (*)))
  ;; One argument - returns value
  (is (cl:= 5 (* 5)))
  ;; Two arguments
  (is (cl:= 12 (* 3 4)))
  ;; Multiple arguments
  (is (cl:= 120 (* 1 2 3 4 5)))
  ;; With zero
  (is (cl:= 0 (* 1 2 0 4 5))))

(test variadic-division
  "Test / with varying number of arguments"
  ;; One argument - reciprocal
  (is (cl:= 1/2 (/ 2)))
  (is (cl:= 0.5 (/ 2.0)))
  ;; Two arguments
  (is (cl:= 3 (/ 12 4)))
  ;; Multiple arguments - left-to-right reduction
  (is (cl:= 2 (/ 24 3 4)))
  (is (cl:= 1 (/ 24 4 3 2))))

;;; ============================================================================
;;; abs Function
;;; ============================================================================

(test abs-integers
  "Test abs with integers"
  (is (cl:= 5 (abs 5)))
  (is (cl:= 5 (abs -5)))
  (is (cl:= 0 (abs 0)))
  (is (cl:= 42 (abs -42)))
  (is (cl:= 5 (abs (wrap -5)))))

(test abs-floats
  "Test abs with floats"
  (is (cl:= 5.5 (abs 5.5)))
  (is (cl:= 5.5 (abs -5.5)))
  (is (cl:= 0.0 (abs 0.0)))
  (is (cl:= 3.14 (abs -3.14))))

(test abs-ratios
  "Test abs with ratios"
  (is (cl:= 1/2 (abs 1/2)))
  (is (cl:= 1/2 (abs -1/2)))
  (is (cl:= 3/4 (abs -3/4))))

(test abs-complex
  "Test abs (magnitude) with complex numbers"
  ;; |3+4i| = 5
  (is (cl:= 5 (abs #C(3 4))))
  (is (cl:= 5 (abs #C(-3 -4))))
  ;; |1+0i| = 1
  (is (cl:= 1 (abs #C(1 0))))
  ;; |0+1i| = 1
  (is (cl:= 1 (abs #C(0 1)))))

(test abs-bignum
  "Test abs with bignums"
  (is (cl:= 10000000000000000000 (abs 10000000000000000000)))
  (is (cl:= 10000000000000000000 (abs -10000000000000000000))))

;;; ============================================================================
;;; Trigonometric Functions
;;; ============================================================================

(test sin-function
  "Test sin function"
  ;; sin(0) = 0
  (is (cl:< (cl:abs (sin 0)) 0.0001))
  ;; sin(π/2) ≈ 1
  (is (cl:< (cl:abs (cl:- (sin (cl:/ cl:pi 2)) 1)) 0.0001))
  ;; sin(π) ≈ 0
  (is (cl:< (cl:abs (sin cl:pi)) 0.0001))
  ;; sin(-x) = -sin(x) (odd function)
  (is (cl:< (cl:abs (cl:+ (sin 1.0) (sin -1.0))) 0.0001))
  ;; Wrapped value
  (is (cl:< (cl:abs (sin (wrap 0))) 0.0001)))

(test cos-function
  "Test cos function"
  ;; cos(0) = 1
  (is (cl:< (cl:abs (cl:- (cos 0) 1)) 0.0001))
  ;; cos(π/2) ≈ 0
  (is (cl:< (cl:abs (cos (cl:/ cl:pi 2))) 0.0001))
  ;; cos(π) ≈ -1
  (is (cl:< (cl:abs (cl:- (cos cl:pi) -1)) 0.0001))
  ;; cos(-x) = cos(x) (even function)
  (is (cl:< (cl:abs (cl:- (cos 1.0) (cos -1.0))) 0.0001))
  ;; Wrapped value
  (is (cl:< (cl:abs (cl:- (cos (wrap 0)) 1)) 0.0001)))

(test tan-function
  "Test tan function"
  ;; tan(0) = 0
  (is (cl:< (cl:abs (tan 0)) 0.0001))
  ;; tan(π/4) ≈ 1
  (is (cl:< (cl:abs (cl:- (tan (cl:/ cl:pi 4)) 1)) 0.0001))
  ;; tan(-x) = -tan(x) (odd function)
  (is (cl:< (cl:abs (cl:+ (tan 1.0) (tan -1.0))) 0.0001))
  ;; Wrapped value
  (is (cl:< (cl:abs (tan (wrap 0))) 0.0001)))

(test asin-function
  "Test asin function"
  ;; asin(0) = 0
  (is (cl:< (cl:abs (asin 0)) 0.0001))
  ;; asin(1) ≈ π/2
  (is (cl:< (cl:abs (cl:- (asin 1) (cl:/ cl:pi 2))) 0.0001))
  ;; asin(-1) ≈ -π/2
  (is (cl:< (cl:abs (cl:- (asin -1) (cl:/ cl:pi -2))) 0.0001))
  ;; asin(0.5) ≈ π/6
  (is (cl:< (cl:abs (cl:- (asin 0.5) (cl:/ cl:pi 6))) 0.0001)))

(test acos-function
  "Test acos function"
  ;; acos(1) = 0
  (is (cl:< (cl:abs (acos 1)) 0.0001))
  ;; acos(0) ≈ π/2
  (is (cl:< (cl:abs (cl:- (acos 0) (cl:/ cl:pi 2))) 0.0001))
  ;; acos(-1) ≈ π
  (is (cl:< (cl:abs (cl:- (acos -1) cl:pi)) 0.0001)))

(test atan-function
  "Test atan function (single argument)"
  ;; atan(0) = 0
  (is (cl:< (cl:abs (atan 0)) 0.0001))
  ;; atan(1) ≈ π/4
  (is (cl:< (cl:abs (cl:- (atan 1) (cl:/ cl:pi 4))) 0.0001))
  ;; atan(-1) ≈ -π/4
  (is (cl:< (cl:abs (cl:- (atan -1) (cl:/ cl:pi -4))) 0.0001)))

(test atan2-function
  "Test atan2 function (two-argument arctangent)"
  ;; atan2(0, 1) = 0 (positive x-axis)
  (is (cl:< (cl:abs (atan2 0 1)) 0.0001))
  ;; atan2(1, 1) ≈ π/4 (first quadrant)
  (is (cl:< (cl:abs (cl:- (atan2 1 1) (cl:/ cl:pi 4))) 0.0001))
  ;; atan2(1, 0) ≈ π/2 (positive y-axis)
  (is (cl:< (cl:abs (cl:- (atan2 1 0) (cl:/ cl:pi 2))) 0.0001))
  ;; atan2(1, -1) ≈ 3π/4 (second quadrant)
  (is (cl:< (cl:abs (cl:- (atan2 1 -1) (cl:* 3 (cl:/ cl:pi 4)))) 0.0001))
  ;; atan2(-1, -1) ≈ -3π/4 (third quadrant)
  (is (cl:< (cl:abs (cl:- (atan2 -1 -1) (cl:* -3 (cl:/ cl:pi 4)))) 0.0001))
  ;; Mixed wrapped/raw
  (is (cl:< (cl:abs (cl:- (atan2 (wrap 1) 1) (cl:/ cl:pi 4))) 0.0001))
  (is (cl:< (cl:abs (cl:- (atan2 1 (wrap 1)) (cl:/ cl:pi 4))) 0.0001)))

(test trig-identity
  "Test trigonometric identity: sin²(x) + cos²(x) = 1"
  (let ((x 0.7))
    (is (cl:< (cl:abs (cl:- 1.0
                           (cl:+ (cl:* (sin x) (sin x))
                                 (cl:* (cos x) (cos x)))))
              0.0001))))

;;; ============================================================================
;;; Hyperbolic Functions
;;; ============================================================================

(test sinh-function
  "Test sinh function"
  ;; sinh(0) = 0
  (is (cl:< (cl:abs (sinh 0)) 0.0001))
  ;; sinh(1) ≈ 1.1752
  (is (cl:< (cl:abs (cl:- (sinh 1) 1.1752)) 0.001))
  ;; sinh(-x) = -sinh(x) (odd function)
  (is (cl:< (cl:abs (cl:+ (sinh 1.0) (sinh -1.0))) 0.0001)))

(test cosh-function
  "Test cosh function"
  ;; cosh(0) = 1
  (is (cl:< (cl:abs (cl:- (cosh 0) 1)) 0.0001))
  ;; cosh(1) ≈ 1.5431
  (is (cl:< (cl:abs (cl:- (cosh 1) 1.5431)) 0.001))
  ;; cosh(-x) = cosh(x) (even function)
  (is (cl:< (cl:abs (cl:- (cosh 1.0) (cosh -1.0))) 0.0001)))

(test tanh-function
  "Test tanh function"
  ;; tanh(0) = 0
  (is (cl:< (cl:abs (tanh 0)) 0.0001))
  ;; tanh(1) ≈ 0.7616
  (is (cl:< (cl:abs (cl:- (tanh 1) 0.7616)) 0.001))
  ;; tanh(-x) = -tanh(x) (odd function)
  (is (cl:< (cl:abs (cl:+ (tanh 1.0) (tanh -1.0))) 0.0001))
  ;; tanh approaches ±1 as x → ±∞
  (is (cl:< (cl:abs (cl:- (tanh 10) 1.0)) 0.001))
  (is (cl:< (cl:abs (cl:+ (tanh -10) 1.0)) 0.001)))

(test asinh-function
  "Test asinh function"
  ;; asinh(0) = 0
  (is (cl:< (cl:abs (asinh 0)) 0.0001))
  ;; asinh(sinh(1)) ≈ 1
  (is (cl:< (cl:abs (cl:- (asinh (sinh 1)) 1.0)) 0.0001))
  ;; asinh(-x) = -asinh(x) (odd function)
  (is (cl:< (cl:abs (cl:+ (asinh 1.0) (asinh -1.0))) 0.0001)))

(test acosh-function
  "Test acosh function"
  ;; acosh(1) = 0
  (is (cl:< (cl:abs (acosh 1)) 0.0001))
  ;; acosh(cosh(1)) ≈ 1
  (is (cl:< (cl:abs (cl:- (acosh (cosh 1)) 1.0)) 0.0001))
  ;; acosh(2) ≈ 1.317
  (is (cl:< (cl:abs (cl:- (acosh 2) 1.317)) 0.01)))

(test atanh-function
  "Test atanh function"
  ;; atanh(0) = 0
  (is (cl:< (cl:abs (atanh 0)) 0.0001))
  ;; atanh(tanh(0.5)) ≈ 0.5
  (is (cl:< (cl:abs (cl:- (atanh (tanh 0.5)) 0.5)) 0.0001))
  ;; atanh(0.5) ≈ 0.5493
  (is (cl:< (cl:abs (cl:- (atanh 0.5) 0.5493)) 0.001)))

(test hyperbolic-identity
  "Test hyperbolic identity: cosh²(x) - sinh²(x) = 1"
  (let ((x 0.7))
    (is (cl:< (cl:abs (cl:- 1.0
                           (cl:- (cl:* (cosh x) (cosh x))
                                 (cl:* (sinh x) (sinh x)))))
              0.0001))))

;;; ============================================================================
;;; Exponential and Logarithmic Functions
;;; ============================================================================

(test exp-function
  "Test exp function"
  ;; exp(0) = 1
  (is (cl:< (cl:abs (cl:- (exp 0) 1)) 0.0001))
  ;; exp(1) ≈ e ≈ 2.71828
  (is (cl:< (cl:abs (cl:- (exp 1) 2.71828)) 0.0001))
  ;; exp(2) ≈ e² ≈ 7.389
  (is (cl:< (cl:abs (cl:- (exp 2) 7.389)) 0.001))
  ;; exp(ln(5)) ≈ 5
  (is (cl:< (cl:abs (cl:- (exp (ln 5)) 5.0)) 0.0001))
  ;; Wrapped value
  (is (cl:< (cl:abs (cl:- (exp (wrap 0)) 1)) 0.0001)))

(test ln-function
  "Test ln function (natural logarithm)"
  ;; ln(1) = 0
  (is (cl:< (cl:abs (ln 1)) 0.0001))
  ;; ln(e) ≈ 1, where e ≈ 2.71828
  (is (cl:< (cl:abs (cl:- (ln 2.71828) 1.0)) 0.0001))
  ;; ln(10) ≈ 2.3026
  (is (cl:< (cl:abs (cl:- (ln 10) 2.3026)) 0.001))
  ;; ln(exp(3)) ≈ 3
  (is (cl:< (cl:abs (cl:- (ln (exp 3)) 3.0)) 0.0001))
  ;; Wrapped value
  (is (cl:< (cl:abs (ln (wrap 1))) 0.0001)))

(test ln-exp-inverse
  "Test that ln and exp are inverse functions"
  (is (cl:< (cl:abs (cl:- (exp (ln 5)) 5.0)) 0.0001))
  (is (cl:< (cl:abs (cl:- (ln (exp 2.5)) 2.5)) 0.0001)))

(test expt-integers
  "Test expt with integer arguments"
  ;; 2^3 = 8
  (is (cl:= 8 (expt 2 3)))
  ;; 3^2 = 9
  (is (cl:= 9 (expt 3 2)))
  ;; 10^0 = 1
  (is (cl:= 1 (expt 10 0)))
  ;; 5^1 = 5
  (is (cl:= 5 (expt 5 1)))
  ;; 2^-1 = 1/2
  (is (cl:= 1/2 (expt 2 -1)))
  ;; 2^10 = 1024
  (is (cl:= 1024 (expt 2 10))))

(test expt-floats
  "Test expt with float arguments"
  ;; 4^0.5 = 2 (square root)
  (is (cl:< (cl:abs (cl:- (expt 4 0.5) 2.0)) 0.0001))
  ;; 8^(1/3) ≈ 2 (cube root)
  (is (cl:< (cl:abs (cl:- (expt 8 (cl:/ 1 3)) 2.0)) 0.0001))
  ;; 2.0^3 = 8.0
  (is (cl:= 8.0 (expt 2.0 3)))
  ;; 3^0.5 ≈ 1.732 (√3)
  (is (cl:< (cl:abs (cl:- (expt 3 0.5) 1.732)) 0.01)))

(test expt-negative-base
  "Test expt with negative bases"
  ;; (-2)^2 = 4
  (is (cl:= 4 (expt -2 2)))
  ;; (-2)^3 = -8
  (is (cl:= -8 (expt -2 3)))
  ;; (-1)^2 = 1
  (is (cl:= 1 (expt -1 2)))
  ;; (-1)^100 = 1
  (is (cl:= 1 (expt -1 100)))
  ;; (-1)^101 = -1
  (is (cl:= -1 (expt -1 101))))

(test expt-wrapped
  "Test expt with wrapped values"
  (is (cl:= 8 (expt (wrap 2) 3)))
  (is (cl:= 8 (expt 2 (wrap 3))))
  (is (cl:= 8 (expt (wrap 2) (wrap 3)))))

(test sqrt-integers
  "Test sqrt with perfect squares"
  (is (cl:= 0 (sqrt 0)))
  (is (cl:= 1 (sqrt 1)))
  (is (cl:= 2 (sqrt 4)))
  (is (cl:= 3 (sqrt 9)))
  (is (cl:= 10 (sqrt 100))))

(test sqrt-non-perfect-squares
  "Test sqrt with non-perfect squares"
  (is (cl:< (cl:abs (cl:- (sqrt 2) 1.41421356)) 0.0001))
  (is (cl:< (cl:abs (cl:- (sqrt 3) 1.73205081)) 0.0001))
  (is (cl:< (cl:abs (cl:- (sqrt 10) 3.16227766)) 0.0001)))

(test sqrt-ratios
  "Test sqrt with rational numbers"
  ;; sqrt(1/4) = 1/2
  (is (cl:= 0.5 (sqrt 1/4)))
  ;; sqrt(9/4) = 3/2
  (is (cl:= 1.5 (sqrt 9/4))))

(test sqrt-negative
  "Test sqrt of negative numbers returns complex"
  (let ((result (sqrt -1)))
    (is (complexp result))
    (is (cl:< (cl:abs (cl:realpart result)) 0.0001))
    (is (cl:< (cl:abs (cl:- (cl:abs (cl:imagpart result)) 1.0)) 0.0001)))
  (let ((result (sqrt -4)))
    (is (complexp result))
    (is (cl:< (cl:abs (cl:realpart result)) 0.0001))
    (is (cl:< (cl:abs (cl:- (cl:abs (cl:imagpart result)) 2.0)) 0.0001))))

(test sqrt-wrapped
  "Test sqrt with wrapped values"
  (is (cl:= 2 (sqrt (wrap 4))))
  (is (cl:= 3 (sqrt (wrap 9)))))

;;; ============================================================================
;;; Rational and Complex Number Functions
;;; ============================================================================

(test rationalize-without-tolerance
  "Test rationalize without tolerance"
  (is (cl:= 1/2 (rationalize 1/2)))
  (is (cl:= 5 (rationalize 5)))
  (is (rationalp (rationalize 0.5))))

(test rationalize-with-tolerance
  "Test rationalize with tolerance (Scheme-style)"
  (is (cl:= 1/3 (rationalize 0.3333333 0.0001)))
  (is (cl:= 1/3 (rationalize 0.3 0.1)))
  (is (cl:= 2 (rationalize 2.1 0.2))))

(test rationalize-wrapped
  "Test rationalize with wrapped values"
  (is (cl:= 1/3 (rationalize (wrap 0.3333333) 0.0001)))
  (is (cl:= 1/3 (rationalize 0.3333333 (wrap 0.0001)))))

(test numerator-function
  "Test numerator function"
  (is (cl:= 1 (numerator 1/2)))
  (is (cl:= 3 (numerator 3/4)))
  (is (cl:= 5 (numerator 5)))
  (is (cl:= -1 (numerator -1/2)))
  (is (cl:= 7 (numerator 7/11)))
  ;; Wrapped value
  (is (cl:= 1 (numerator (wrap 1/2)))))

(test denominator-function
  "Test denominator function"
  (is (cl:= 2 (denominator 1/2)))
  (is (cl:= 4 (denominator 3/4)))
  (is (cl:= 1 (denominator 5)))
  (is (cl:= 2 (denominator -1/2)))
  (is (cl:= 11 (denominator 7/11)))
  ;; Wrapped value
  (is (cl:= 2 (denominator (wrap 1/2)))))

(test real-part-function
  "Test real-part function"
  (is (cl:= 3 (real-part 3)))
  (is (cl:= 3.5 (real-part 3.5)))
  (is (cl:= 3 (real-part #C(3 4))))
  (is (cl:= 0 (real-part #C(0 5))))
  (is (cl:= -2 (real-part #C(-2 3))))
  ;; Wrapped value
  (is (cl:= 3 (real-part (wrap #C(3 4))))))

(test imag-part-function
  "Test imag-part function"
  (is (cl:= 0 (imag-part 3)))
  (is (cl:= 0 (imag-part 3.5)))
  (is (cl:= 4 (imag-part #C(3 4))))
  (is (cl:= 5 (imag-part #C(0 5))))
  (is (cl:= -3 (imag-part #C(2 -3))))
  ;; Wrapped value
  (is (cl:= 4 (imag-part (wrap #C(3 4))))))

(test angle-function
  "Test angle function (phase of complex number)"
  ;; Positive real: angle = 0
  (is (cl:< (cl:abs (angle 1)) 0.0001))
  (is (cl:< (cl:abs (angle 5)) 0.0001))
  ;; Negative real: angle = π
  (is (cl:< (cl:abs (cl:- (angle -1) cl:pi)) 0.0001))
  ;; Positive imaginary: angle = π/2
  (is (cl:< (cl:abs (cl:- (angle #C(0 1)) (cl:/ cl:pi 2))) 0.0001))
  ;; First quadrant: angle = π/4
  (is (cl:< (cl:abs (cl:- (angle #C(1 1)) (cl:/ cl:pi 4))) 0.0001))
  ;; Negative imaginary: angle = -π/2
  (is (cl:< (cl:abs (cl:- (angle #C(0 -1)) (cl:/ cl:pi -2))) 0.0001)))

;;; ============================================================================
;;; GCD and LCM Functions
;;; ============================================================================

(test gcd-zero-args
  "Test gcd with zero arguments"
  (is (cl:= 0 (gcd))))

(test gcd-one-arg
  "Test gcd with one argument"
  (is (cl:= 5 (gcd 5)))
  (is (cl:= 5 (gcd -5)))
  (is (cl:= 0 (gcd 0))))

(test gcd-two-args
  "Test gcd with two arguments"
  (is (cl:= 6 (gcd 12 18)))
  (is (cl:= 1 (gcd 7 11)))
  (is (cl:= 5 (gcd 0 5)))
  (is (cl:= 5 (gcd 5 0)))
  (is (cl:= 4 (gcd 8 12)))
  (is (cl:= 6 (gcd -12 18)))
  (is (cl:= 6 (gcd 12 -18)))
  (is (cl:= 6 (gcd -12 -18))))

(test gcd-multiple-args
  "Test gcd with multiple arguments"
  (is (cl:= 2 (gcd 12 18 8)))
  (is (cl:= 1 (gcd 12 18 7)))
  (is (cl:= 3 (gcd 12 18 9)))
  (is (cl:= 6 (gcd 12 18 24 30))))

(test gcd-wrapped
  "Test gcd with wrapped values"
  (is (cl:= 6 (gcd (wrap 12) 18)))
  (is (cl:= 6 (gcd 12 (wrap 18))))
  (is (cl:= 6 (gcd (wrap 12) (wrap 18)))))

(test lcm-zero-args
  "Test lcm with zero arguments"
  (is (cl:= 1 (lcm))))

(test lcm-one-arg
  "Test lcm with one argument"
  (is (cl:= 5 (lcm 5)))
  (is (cl:= 5 (lcm -5)))
  (is (cl:= 0 (lcm 0))))

(test lcm-two-args
  "Test lcm with two arguments"
  (is (cl:= 36 (lcm 12 18)))
  (is (cl:= 77 (lcm 7 11)))
  (is (cl:= 0 (lcm 0 5)))
  (is (cl:= 0 (lcm 5 0)))
  (is (cl:= 24 (lcm 8 12)))
  (is (cl:= 36 (lcm -12 18)))
  (is (cl:= 36 (lcm 12 -18))))

(test lcm-multiple-args
  "Test lcm with multiple arguments"
  (is (cl:= 72 (lcm 12 18 8)))
  (is (cl:= 252 (lcm 12 18 7)))
  (is (cl:= 36 (lcm 12 18 9))))

(test lcm-wrapped
  "Test lcm with wrapped values"
  (is (cl:= 36 (lcm (wrap 12) 18)))
  (is (cl:= 36 (lcm 12 (wrap 18)))))

(test binary-gcd-lcm
  "Test binary %gcd and %lcm operations"
  (is (cl:= 6 (%gcd 12 18)))
  (is (cl:= 36 (%lcm 12 18)))
  (is (cl:= 6 (%gcd (wrap 12) (wrap 18))))
  (is (cl:= 36 (%lcm (wrap 12) (wrap 18)))))

;;; ============================================================================
;;; Bit Shift and Rotate Functions
;;; ============================================================================

(test bit-shift-left
  "Test bit-shift with positive count (shift left)"
  (is (cl:= 4 (bit-shift 1 2)))      ; 1 << 2 = 4
  (is (cl:= 16 (bit-shift 1 4)))     ; 1 << 4 = 16
  (is (cl:= 8 (bit-shift 2 2)))      ; 2 << 2 = 8
  (is (cl:= 0 (bit-shift 0 5)))      ; 0 << 5 = 0
  (is (cl:= 256 (bit-shift 1 8))))   ; 1 << 8 = 256

(test bit-shift-right
  "Test bit-shift with negative count (shift right)"
  (is (cl:= 2 (bit-shift 8 -2)))     ; 8 >> 2 = 2
  (is (cl:= 1 (bit-shift 16 -4)))    ; 16 >> 4 = 1
  (is (cl:= 0 (bit-shift 1 -1)))     ; 1 >> 1 = 0
  (is (cl:= 4 (bit-shift 16 -2)))    ; 16 >> 2 = 4
  (is (cl:= 0 (bit-shift 7 -3))))    ; 7 >> 3 = 0

(test bit-shift-negative-integers
  "Test bit-shift with negative integers (arithmetic shift)"
  (is (cl:= -4 (bit-shift -1 2)))    ; -1 << 2 = -4
  (is (cl:= -1 (bit-shift -4 -2)))   ; -4 >> 2 = -1 (arithmetic shift preserves sign)
  (is (cl:= -2 (bit-shift -8 -2))))  ; -8 >> 2 = -2

(test bit-shift-zero-count
  "Test bit-shift with zero count"
  (is (cl:= 42 (bit-shift 42 0)))
  (is (cl:= -17 (bit-shift -17 0)))
  (is (cl:= 0 (bit-shift 0 0))))

(test bit-shift-wrapped
  "Test bit-shift with wrapped integers"
  (is (cl:= 8 (bit-shift (wrap-number 2) 2)))
  (is (cl:= 8 (bit-shift 2 (wrap-number 2))))
  (is (cl:= 8 (bit-shift (wrap-number 2) (wrap-number 2)))))

(test bit-rotate-left
  "Test bit-rotate with positive count (rotate left)"
  ;; 8-bit rotation: 0b00000001 rotated left by 1 = 0b00000010
  (is (cl:= #b00000010 (bit-rotate #b00000001 1 8)))
  ;; 8-bit rotation: 0b00000001 rotated left by 4 = 0b00010000
  (is (cl:= #b00010000 (bit-rotate #b00000001 4 8)))
  ;; 8-bit rotation: 0b10000000 rotated left by 1 = 0b00000001 (wraps around)
  (is (cl:= #b00000001 (bit-rotate #b10000000 1 8)))
  ;; 8-bit rotation: 0b11000001 rotated left by 2 = 0b00000111
  (is (cl:= #b00000111 (bit-rotate #b11000001 2 8))))

(test bit-rotate-right
  "Test bit-rotate with negative count (rotate right)"
  ;; 8-bit rotation: 0b00000001 rotated right by 1 = 0b10000000
  (is (cl:= #b10000000 (bit-rotate #b00000001 -1 8)))
  ;; 8-bit rotation: 0b00010000 rotated right by 4 = 0b00000001
  (is (cl:= #b00000001 (bit-rotate #b00010000 -4 8)))
  ;; 8-bit rotation: 0b00000010 rotated right by 1 = 0b00000001
  (is (cl:= #b00000001 (bit-rotate #b00000010 -1 8))))

(test bit-rotate-full-rotation
  "Test bit-rotate with full rotation (count = width)"
  ;; Rotating by width should return the same value
  (is (cl:= #b10101010 (bit-rotate #b10101010 8 8)))
  (is (cl:= #b10101010 (bit-rotate #b10101010 -8 8)))
  ;; Rotating by multiples of width should also return the same value
  (is (cl:= #b10101010 (bit-rotate #b10101010 16 8)))
  (is (cl:= #b10101010 (bit-rotate #b10101010 24 8))))

(test bit-rotate-zero-count
  "Test bit-rotate with zero count"
  (is (cl:= #b11110000 (bit-rotate #b11110000 0 8)))
  (is (cl:= #b10101010 (bit-rotate #b10101010 0 8))))

(test bit-rotate-different-widths
  "Test bit-rotate with different bit widths"
  ;; 4-bit rotation
  (is (cl:= #b1000 (bit-rotate #b0001 3 4)))
  (is (cl:= #b0001 (bit-rotate #b1000 1 4)))
  ;; 16-bit rotation
  (is (cl:= #x8001 (bit-rotate #xC000 1 16)))
  ;; 32-bit rotation
  (is (cl:= #x80000001 (bit-rotate #xC0000000 1 32))))

(test bit-rotate-wrapped
  "Test bit-rotate with wrapped integers"
  (is (cl:= #b00000010 (bit-rotate (wrap-number #b00000001) 1 8)))
  (is (cl:= #b00000010 (bit-rotate #b00000001 (wrap-number 1) 8)))
  (is (cl:= #b00000010 (bit-rotate #b00000001 1 (wrap-number 8))))
  (is (cl:= #b00000010 (bit-rotate (wrap-number #b00000001) (wrap-number 1) (wrap-number 8)))))

;;; ============================================================================
;;; Error Cases
;;; ============================================================================

(test arithmetic-type-errors
  "Test that arithmetic operations signal errors for non-numbers"
  (signals error (%+ "a" "b"))
  (signals error (%- "a" "b"))
  (signals error (%* "a" "b"))
  (signals error (%/ "a" "b"))
  (signals error (abs "not a number"))
  (signals error (sin "not a number"))
  (signals error (sqrt "not a number"))
  (signals error (expt "a" "b")))

;;; ============================================================================
;;; Edge Cases and Special Values
;;; ============================================================================

(test very-large-numbers
  "Test arithmetic with very large numbers (bignums)"
  (let ((big1 (cl:expt 10 100))
        (big2 (cl:expt 10 100)))
    (is (cl:= (cl:* 2 big1) (%+ big1 big2)))
    (is (cl:= 0 (%- big1 big2)))
    (is (cl:= (cl:expt 10 200) (%* big1 big2)))
    (is (cl:= 1 (%/ big1 big2)))))

(test very-small-ratios
  "Test arithmetic with very small ratios"
  (let ((small1 (cl:/ 1 (cl:expt 10 100)))
        (small2 (cl:/ 1 (cl:expt 10 100))))
    (is (cl:= (cl:/ 2 (cl:expt 10 100)) (%+ small1 small2)))
    (is (cl:= 0 (%- small1 small2)))
    (is (cl:= 1 (%/ small1 small2)))))

(test mixed-operations
  "Test combinations of operations"
  ;; (2 + 3) * 4 = 20
  (is (cl:= 20 (* (+ 2 3) 4)))
  ;; (10 - 2) / 4 = 2
  (is (cl:= 2 (/ (- 10 2) 4)))
  ;; 2 * 3 + 4 * 5 = 26
  (is (cl:= 26 (+ (* 2 3) (* 4 5)))))

(test complex-arithmetic
  "Test arithmetic with complex numbers"
  ;; Addition
  (is (cl:= #C(4 6) (%+ #C(1 2) #C(3 4))))
  ;; Subtraction
  (is (cl:= #C(-2 -2) (%- #C(1 2) #C(3 4))))
  ;; Multiplication: (1+2i)(3+4i) = 3 + 4i + 6i + 8i² = 3 + 10i - 8 = -5 + 10i
  (is (cl:= #C(-5 10) (%* #C(1 2) #C(3 4))))
  ;; Division
  (is (cl:= #C(1 0) (%/ #C(2 2) #C(2 2)))))
