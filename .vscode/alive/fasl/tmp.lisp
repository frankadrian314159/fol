(in-package fol.tests)
(in-readtable fol-syntax)

(in-suite fol-suite)

;;; ============================================================================
;;; Addition Tests
;;; ============================================================================

(test addition-identity
  "Test addition identity and zero-argument case"
  ;; No arguments should return 0
  (is (= 0 (unwrap (+))))
  ;; Single argument should return itself
  (is (= 5 (unwrap (+ (wrap 5)))))
  (is (= 3.14 (unwrap (+ (wrap 3.14)))))
  (is (= 1/2 (unwrap (+ (wrap 1/2))))))

(test addition-two-args
  "Test binary addition with various type combinations"
  ;; Integer + Integer
  (is (= 5 (unwrap (+ (wrap 2) (wrap 3)))))
  (is (typep (+ (wrap 2) (wrap 3)) '<integer>))
  ;; Integer + Ratio
  (is (= 5/2 (unwrap (+ (wrap 2) (wrap 1/2)))))
  (is (typep (+ (wrap 2) (wrap 1/2)) '<ratio>))
  ;; Integer + Float
  (is (= 2.5 (unwrap (+ (wrap 2) (wrap 0.5)))))
  (is (typep (+ (wrap 2) (wrap 0.5)) '<single-float>))
  ;; Ratio + Ratio
  (is (= 3/4 (unwrap (+ (wrap 1/4) (wrap 1/2)))))
  (is (typep (+ (wrap 1/4) (wrap 1/2)) '<ratio>))
  ;; Float + Float
  (is (= 3.0 (unwrap (+ (wrap 1.5) (wrap 1.5)))))
  (is (typep (+ (wrap 1.5) (wrap 1.5)) '<single-float>))
  ;; Double + Double
  (is (= 2.0d0 (unwrap (+ (wrap 1.0d0) (wrap 1.0d0)))))
  (is (typep (+ (wrap 1.0d0) (wrap 1.0d0)) '<double-float>))
  ;; Complex + Complex
  (is (= #C(2 2) (unwrap (+ (wrap #C(1 1)) (wrap #C(1 1))))))
  (is (typep (+ (wrap #C(1 1)) (wrap #C(1 1))) '<complex>)))

(test addition-multi-args
  "Test addition with multiple arguments"
  ;; Three integers
  (is (= 6 (unwrap (+ (wrap 1) (wrap 2) (wrap 3)))))
  ;; Four integers
  (is (= 10 (unwrap (+ (wrap 1) (wrap 2) (wrap 3) (wrap 4)))))
  ;; Many integers
  (is (= 15 (unwrap (+ (wrap 1) (wrap 2) (wrap 3) (wrap 4) (wrap 5)))))
  ;; Mixed types - should promote to highest precision
  (is (= 3.5 (unwrap (+ (wrap 1) (wrap 2) (wrap 0.5)))))
  (is (typep (+ (wrap 1) (wrap 2) (wrap 0.5)) '<single-float>)))

(test addition-negative
  "Test addition with negative numbers"
  (is (= 0 (unwrap (+ (wrap 5) (wrap -5)))))
  (is (= -5 (unwrap (+ (wrap -2) (wrap -3)))))
  (is (= 1 (unwrap (+ (wrap -4) (wrap 5)))))
  (is (= -1 (unwrap (+ (wrap 4) (wrap -5))))))

(test addition-bignum
  "Test addition with bignums"
  (is (= 20000000000000000000 
         (unwrap (+ (wrap 10000000000000000000) (wrap 10000000000000000000)))))
  (is (typep (+ (wrap 10000000000000000000) (wrap 10000000000000000000)) '<bignum>)))

;;; ============================================================================
;;; Subtraction Tests
;;; ============================================================================

(test subtraction-unary
  "Test unary negation"
  (is (= -5 (unwrap (- (wrap 5)))))
  (is (= 5 (unwrap (- (wrap -5)))))
  (is (= -3.14 (unwrap (- (wrap 3.14)))))
  (is (= -1/2 (unwrap (- (wrap 1/2))))))

(test subtraction-two-args
  "Test binary subtraction"
  ;; Integer - Integer
  (is (= 1 (unwrap (- (wrap 3) (wrap 2)))))
  (is (= -1 (unwrap (- (wrap 2) (wrap 3)))))
  ;; Integer - Ratio
  (is (= 3/2 (unwrap (- (wrap 2) (wrap 1/2)))))
  ;; Float - Float
  (is (= 0.5 (unwrap (- (wrap 1.5) (wrap 1.0)))))
  ;; Complex - Complex
  (is (= #C(1 0) (unwrap (- (wrap #C(2 1)) (wrap #C(1 1)))))))

(test subtraction-multi-args
  "Test subtraction with multiple arguments"
  ;; 10 - 2 - 3 = 5
  (is (= 5 (unwrap (- (wrap 10) (wrap 2) (wrap 3)))))
  ;; 20 - 5 - 3 - 2 = 10
  (is (= 10 (unwrap (- (wrap 20) (wrap 5) (wrap 3) (wrap 2)))))
  ;; With floats: 10.0 - 2.5 - 1.5 = 6.0
  (is (= 6.0 (unwrap (- (wrap 10.0) (wrap 2.5) (wrap 1.5))))))

(test subtraction-zero
  "Test subtraction with zero"
  (is (= 5 (unwrap (- (wrap 5) (wrap 0)))))
  (is (= -5 (unwrap (- (wrap 0) (wrap 5))))))

(test subtraction-bignum
  "Test subtraction with bignums"
  (is (= 0 (unwrap (- (wrap 10000000000000000000) (wrap 10000000000000000000)))))
  (is (= 5000000000000000000 
         (unwrap (- (wrap 10000000000000000000) (wrap 5000000000000000000))))))

;;; ============================================================================
;;; Multiplication Tests
;;; ============================================================================

(test multiplication-identity
  "Test multiplication identity"
  ;; No arguments should return 1
  (is (= 1 (unwrap (*)))) 
  ;; Single argument should return itself
  (is (= 5 (unwrap (* (wrap 5)))))
  (is (= 3.14 (unwrap (* (wrap 3.14))))))

(test multiplication-two-args
  "Test binary multiplication"
  ;; Integer * Integer
  (is (= 6 (unwrap (* (wrap 2) (wrap 3)))))
  (is (typep (* (wrap 2) (wrap 3)) '<integer>))
  ;; Integer * Ratio
  (is (= 1 (unwrap (* (wrap 2) (wrap 1/2)))))
  (is (typep (* (wrap 2) (wrap 1/2)) '<integer>))
  ;; Ratio * Ratio
  (is (= 1/4 (unwrap (* (wrap 1/2) (wrap 1/2)))))
  (is (typep (* (wrap 1/2) (wrap 1/2)) '<ratio>))
  ;; Float * Float
  (is (= 2.25 (unwrap (* (wrap 1.5) (wrap 1.5)))))
  (is (typep (* (wrap 1.5) (wrap 1.5)) '<single-float>))
  ;; Complex * Complex
  (is (= #C(0 2) (unwrap (* (wrap #C(1 1)) (wrap #C(1 1)))))))

(test multiplication-multi-args
  "Test multiplication with multiple arguments"
  ;; 2 * 3 * 4 = 24
  (is (= 24 (unwrap (* (wrap 2) (wrap 3) (wrap 4)))))
  ;; 1 * 2 * 3 * 4 * 5 = 120
  (is (= 120 (unwrap (* (wrap 1) (wrap 2) (wrap 3) (wrap 4) (wrap 5))))))

(test multiplication-zero
  "Test multiplication by zero"
  (is (= 0 (unwrap (* (wrap 5) (wrap 0)))))
  (is (= 0 (unwrap (* (wrap 0) (wrap 5)))))
  (is (= 0.0 (unwrap (* (wrap 5.0) (wrap 0.0))))))

(test multiplication-negative
  "Test multiplication with negative numbers"
  (is (= -6 (unwrap (* (wrap 2) (wrap -3)))))
  (is (= 6 (unwrap (* (wrap -2) (wrap -3)))))
  (is (= -10 (unwrap (* (wrap -5) (wrap 2))))))

(test multiplication-bignum
  "Test multiplication with bignums"
  (is (= 100000000000000000000000000000000000000 
         (unwrap (* (wrap 10000000000000000000) (wrap 10000000000000000000)))))
  (is (typep (* (wrap 10000000000000000000) (wrap 10000000000000000000)) '<bignum>)))

;;; ============================================================================
;;; Division Tests
;;; ============================================================================

(test division-unary
  "Test reciprocal (unary division)"
  (is (= 1/2 (unwrap (/ (wrap 2)))))
  (is (= 1/4 (unwrap (/ (wrap 4)))))
  (is (= 0.5 (unwrap (/ (wrap 2.0)))))
  (is (typep (/ (wrap 2)) '<ratio>))
  (is (typep (/ (wrap 2.0)) '<single-float>)))

(test division-two-args
  "Test binary division"
  ;; Integer / Integer -> Ratio
  (is (= 3/2 (unwrap (/ (wrap 3) (wrap 2)))))
  (is (typep (/ (wrap 3) (wrap 2)) '<ratio>))
  ;; Integer / Integer (exact)
  (is (= 2 (unwrap (/ (wrap 4) (wrap 2)))))
  (is (typep (/ (wrap 4) (wrap 2)) '<integer>))
  ;; Ratio / Integer
  (is (= 1/4 (unwrap (/ (wrap 1/2) (wrap 2)))))
  ;; Float / Float
  (is (= 2.0 (unwrap (/ (wrap 4.0) (wrap 2.0)))))
  (is (typep (/ (wrap 4.0) (wrap 2.0)) '<single-float>))
  ;; Complex / Complex
  (is (= #C(1 0) (unwrap (/ (wrap #C(2 2)) (wrap #C(2 2)))))))

(test division-multi-args
  "Test division with multiple arguments"
  ;; 20 / 2 / 5 = 2
  (is (= 2 (unwrap (/ (wrap 20) (wrap 2) (wrap 5)))))
  ;; 100 / 2 / 5 / 2 = 5
  (is (= 5 (unwrap (/ (wrap 100) (wrap 2) (wrap 5) (wrap 2))))))

(test division-one
  "Test division by one"
  (is (= 5 (unwrap (/ (wrap 5) (wrap 1)))))
  (is (= 3.14 (unwrap (/ (wrap 3.14) (wrap 1.0))))))

(test division-bignum
  "Test division with bignums"
  (is (= 1 (unwrap (/ (wrap 10000000000000000000) (wrap 10000000000000000000)))))
  (is (= 2 (unwrap (/ (wrap 10000000000000000000) (wrap 5000000000000000000))))))

;;; ============================================================================
;;; Mixed Operation Tests
;;; ============================================================================

(test mixed-operations
  "Test combinations of operations"
  ;; (2 + 3) * 4 = 20
  (is (= 20 (unwrap (* (+ (wrap 2) (wrap 3)) (wrap 4)))))
  ;; (10 - 2) / 4 = 2
  (is (= 2 (unwrap (/ (- (wrap 10) (wrap 2)) (wrap 4)))))
  ;; 2 * 3 + 4 * 5 = 26
  (is (= 26 (unwrap (+ (* (wrap 2) (wrap 3)) (* (wrap 4) (wrap 5)))))))

(test type-promotion
  "Test type promotion in mixed operations"
  ;; Integer + Float -> Float
  (is (typep (+ (wrap 1) (wrap 1.0)) '<single-float>))
  ;; Integer + Ratio -> Ratio
  (is (typep (+ (wrap 1) (wrap 1/2)) '<ratio>))
  ;; Ratio + Float -> Float
  (is (typep (+ (wrap 1/2) (wrap 1.0)) '<single-float>))
  ;; Single-Float + Double-Float -> Double-Float
  (is (typep (+ (wrap 1.0f0) (wrap 1.0d0)) '<double-float>)))

  ;;; ============================================================================
;;; ABS (Absolute Value) Tests
;;; ============================================================================

(test abs-integer
  "Test absolute value on integers"
  (is (= 5 (unwrap (abs (wrap 5)))))
  (is (= 5 (unwrap (abs (wrap -5)))))
  (is (= 0 (unwrap (abs (wrap 0)))))
  (is (= 42 (unwrap (abs (wrap 42)))))
  (is (= 42 (unwrap (abs (wrap -42)))))
  (is (typep (abs (wrap 5)) '<integer>)))

(test abs-float
  "Test absolute value on floats"
  (is (= 3.14 (unwrap (abs (wrap 3.14)))))
  (is (= 3.14 (unwrap (abs (wrap -3.14)))))
  (is (= 0.0 (unwrap (abs (wrap 0.0)))))
  (is (typep (abs (wrap 3.14)) '<single-float>)))

(test abs-rational
  "Test absolute value on rationals"
  (is (= 1/2 (unwrap (abs (wrap 1/2)))))
  (is (= 1/2 (unwrap (abs (wrap -1/2)))))
  (is (= 3/4 (unwrap (abs (wrap -3/4)))))
  (is (typep (abs (wrap 1/2)) '<ratio>)))

(test abs-complex
  "Test absolute value (magnitude) on complex numbers"
  ;; |3+4i| = 5
  (is (= 5 (unwrap (abs (wrap #C(3 4))))))
  (is (= 5 (unwrap (abs (wrap #C(-3 -4))))))
  ;; |1+0i| = 1
  (is (= 1 (unwrap (abs (wrap #C(1 0))))))
  ;; |0+1i| = 1
  (is (= 1 (unwrap (abs (wrap #C(0 1)))))))

(test abs-bignum
  "Test absolute value on bignums"
  (is (= 10000000000000000000 
         (unwrap (abs (wrap 10000000000000000000)))))
  (is (= 10000000000000000000 
         (unwrap (abs (wrap -10000000000000000000))))))

;;; ============================================================================
;;; Trigonometric Function Tests
;;; ============================================================================

(test sin-basic
  "Test sine function"
  ;; sin(0) = 0
  (is (= 0 (unwrap (sin (wrap 0)))))
  ;; sin(π/2) ≈ 1
  (is (cl:< (cl:abs (cl:- 1.0 (unwrap (sin (wrap (/ pi 2)))))) 0.0001))
  ;; sin(π) ≈ 0
  (is (cl:< (cl:abs (unwrap (sin (wrap pi)))) 0.0001))
  ;; sin(-x) = -sin(x)
  (is (cl:< (cl:abs (cl:+ (unwrap (sin (wrap 1.0)))
                  (unwrap (sin (wrap -1.0))))) 0.0001)))

(test cos-basic
  "Test cosine function"
  ;; cos(0) = 1
  (is (= 1 (unwrap (cos (wrap 0)))))
  ;; cos(π/2) ≈ 0
  (is (cl:< (cl:abs (unwrap (cos (wrap (/ pi 2))))) 0.0001))
  ;; cos(π) ≈ -1
  (is (cl:< (cl:abs (cl:+ 1.0 (unwrap (cos (wrap pi))))) 0.0001))
  ;; cos(-x) = cos(x)
  (is (cl:< (cl:abs (cl:- (unwrap (cos (wrap 1.0)))
                  (unwrap (cos (wrap -1.0))))) 0.0001)))

(test tan-basic
  "Test tangent function"
  ;; tan(0) = 0
  (is (= 0 (unwrap (tan (wrap 0)))))
  ;; tan(π/4) ≈ 1
  (is (cl:< (cl:abs (cl:- 1.0 (unwrap (tan (wrap (/ pi 4)))))) 0.0001))
  ;; tan(-x) = -tan(x)
  (is (cl:< (cl:abs (cl:+ (unwrap (tan (wrap 1.0)))
                  (unwrap (tan (wrap -1.0))))) 0.0001)))

(test asin-basic
  "Test arcsine function"
  ;; asin(0) = 0
  (is (= 0 (unwrap (asin (wrap 0)))))
  ;; asin(1) ≈ π/2
  (is (cl:< (cl:abs (cl:- (cl:/ pi 2) (unwrap (asin (wrap 1))))) 0.0001))
  ;; asin(-1) ≈ -π/2
  (is (cl:< (cl:abs (cl:+ (cl:/ pi 2) (unwrap (asin (wrap -1))))) 0.0001))
  ;; asin(1/2) ≈ π/6
  (is (cl:< (cl:abs (cl:- (cl:/ pi 6) (unwrap (asin (wrap 0.5))))) 0.0001)))

(test acos-basic
  "Test arccosine function"
  ;; acos(1) = 0
  (is (cl:< (cl:abs (unwrap (acos (wrap 1)))) 0.0001))
  ;; acos(0) ≈ π/2
  (is (cl:< (cl:abs (cl:- (cl:/ pi 2) (unwrap (acos (wrap 0))))) 0.0001))
  ;; acos(-1) ≈ π
  (is (cl:< (cl:abs (cl:- pi (unwrap (acos (wrap -1))))) 0.0001)))

(test atan-basic
  "Test arctangent function (single argument)"
  ;; atan(0) = 0
  (is (= 0 (unwrap (atan (wrap 0)))))
  ;; atan(1) ≈ π/4
  (is (cl:< (cl:abs (cl:- (cl:/ pi 4) (unwrap (atan (wrap 1))))) 0.0001))
  ;; atan(-1) ≈ -π/4
  (is (cl:< (cl:abs (cl:+ (cl:/ pi 4) (unwrap (atan (wrap -1))))) 0.0001)))

(test atan2-basic
  "Test two-argument arctangent function"
  ;; atan2(0, 1) = 0 (positive x-axis)
  (is (cl:< (cl:abs (unwrap (atan2 (wrap 0) (wrap 1)))) 0.0001))
  ;; atan2(1, 1) ≈ π/4 (first quadrant)
  (is (cl:< (cl:abs (cl:- (cl:/ pi 4) (unwrap (atan2 (wrap 1) (wrap 1))))) 0.0001))
  ;; atan2(1, 0) ≈ π/2 (positive y-axis)
  (is (cl:< (cl:abs (cl:- (cl:/ pi 2) (unwrap (atan2 (wrap 1) (wrap 0))))) 0.0001))
  ;; atan2(1, -1) ≈ 3π/4 (second quadrant)
  (is (cl:< (cl:abs (cl:- (cl:* 3 (cl:/ pi 4)) (unwrap (atan2 (wrap 1) (wrap -1))))) 0.0001))
  ;; atan2(-1, -1) ≈ -3π/4 (third quadrant)
  (is (cl:< (cl:abs (cl:+ (cl:* 3 (cl:/ pi 4)) (unwrap (atan2 (wrap -1) (wrap -1))))) 0.0001)))

(test trig-identity
  "Test trigonometric identity: sin²(x) + cos²(x) = 1"
  (let ((x 0.7))
    (is (cl:< (cl:abs (cl:- 1.0 
                   (cl:+ (cl:* (unwrap (sin (wrap x))) (unwrap (sin (wrap x))))
                         (cl:* (unwrap (cos (wrap x))) (unwrap (cos (wrap x)))))))
           0.0001))))

;;; ============================================================================
;;; Hyperbolic Function Tests
;;; ============================================================================

(test sinh-basic
  "Test hyperbolic sine function"
  ;; sinh(0) = 0
  (is (= 0 (unwrap (sinh (wrap 0)))))
  ;; sinh(1) ≈ 1.1752
  (is (cl:< (cl:abs (cl:- 1.1752 (unwrap (sinh (wrap 1))))) 0.001))
  ;; sinh(-x) = -sinh(x)
  (is (cl:< (cl:abs (cl:+ (unwrap (sinh (wrap 1.0)))
                  (unwrap (sinh (wrap -1.0))))) 0.0001)))

(test cosh-basic
  "Test hyperbolic cosine function"
  ;; cosh(0) = 1
  (is (= 1 (unwrap (cosh (wrap 0)))))
  ;; cosh(1) ≈ 1.5431
  (is (cl:< (cl:abs (cl:- 1.5431 (unwrap (cosh (wrap 1))))) 0.001))
  ;; cosh(-x) = cosh(x)
  (is (cl:< (cl:abs (cl:- (unwrap (cosh (wrap 1.0)))
                  (unwrap (cosh (wrap -1.0))))) 0.0001)))

(test tanh-basic
  "Test hyperbolic tangent function"
  ;; tanh(0) = 0
  (is (= 0 (unwrap (tanh (wrap 0)))))
  ;; tanh(1) ≈ 0.7616
  (is (cl:< (cl:abs (cl:- 0.7616 (unwrap (tanh (wrap 1))))) 0.001))
  ;; tanh(-x) = -tanh(x)
  (is (cl:< (cl:abs (cl:+ (unwrap (tanh (wrap 1.0)))
                  (unwrap (tanh (wrap -1.0))))) 0.0001))
  ;; tanh approaches ±1 as x → ±∞
  (is (cl:< (cl:abs (cl:- 1.0 (unwrap (tanh (wrap 10))))) 0.001))
  (is (cl:< (cl:abs (cl:+ 1.0 (unwrap (tanh (wrap -10))))) 0.001)))

(test asinh-basic
  "Test inverse hyperbolic sine function"
  ;; asinh(0) = 0
  (is (= 0 (unwrap (asinh (wrap 0)))))
  ;; asinh(sinh(1)) ≈ 1
  (is (cl:< (cl:abs (cl:- 1.0 (unwrap (asinh (sinh (wrap 1)))))) 0.0001))
  ;; asinh(-x) = -asinh(x)
  (is (cl:< (cl:abs (cl:+ (unwrap (asinh (wrap 1.0)))
                  (unwrap (asinh (wrap -1.0))))) 0.0001)))

(test acosh-basic
  "Test inverse hyperbolic cosine function"
  ;; acosh(1) = 0
  (is (cl:< (cl:abs (unwrap (acosh (wrap 1)))) 0.0001))
  ;; acosh(cosh(1)) ≈ 1
  (is (cl:< (cl:abs (cl:- 1.0 (unwrap (acosh (cosh (wrap 1)))))) 0.0001))
  ;; acosh(2) ≈ 1.317
  (is (cl:< (cl:abs (cl:- 1.317 (unwrap (acosh (wrap 2))))) 0.01)))

(test atanh-basic
  "Test inverse hyperbolic tangent function"
  ;; atanh(0) = 0
  (is (= 0 (unwrap (atanh (wrap 0)))))
  ;; atanh(tanh(0.5)) ≈ 0.5
  (is (cl:< (cl:abs (cl:- 0.5 (unwrap (atanh (tanh (wrap 0.5)))))) 0.0001))
  ;; atanh(0.5) ≈ 0.5493
  (is (cl:< (cl:abs (cl:- 0.5493 (unwrap (atanh (wrap 0.5))))) 0.001)))

(test hyperbolic-identity
  "Test hyperbolic identity: cosh²(x) - sinh²(x) = 1"
  (let ((x 0.7))
    (is (cl:< (cl:abs (cl:- 1.0 
                   (cl:- (cl:* (unwrap (cosh (wrap x))) (unwrap (cosh (wrap x))))
                         (cl:* (unwrap (sinh (wrap x))) (unwrap (sinh (wrap x)))))))
           0.0001))))

;;; ============================================================================
;;; Exponential and Logarithmic Function Tests
;;; ============================================================================

(test exp-basic
  "Test exponential function"
  ;; exp(0) = 1
  (is (= 1 (unwrap (exp (wrap 0)))))
  ;; exp(1) ≈ e ≈ 2.71828
  (is (cl:< (cl:abs (cl:- 2.71828 (unwrap (exp (wrap 1))))) 0.0001))
  ;; exp(2) ≈ 7.389
  (is (cl:< (cl:abs (cl:- 7.389 (unwrap (exp (wrap 2))))) 0.01))
  ;; exp(ln(5)) ≈ 5
  (is (cl:< (cl:abs (cl:- 5.0 (unwrap (exp (log (wrap 5)))))) 0.0001)))

(test log-basic
  "Test natural logarithm function"
  ;; log(1) = 0
  (is (= 0 (unwrap (log (wrap 1)))))
  ;; log(e) ≈ 1
  (is (cl:< (cl:abs (cl:- 1.0 (unwrap (log (exp (wrap 1)))))) 0.0001))
  ;; log(10) ≈ 2.3026
  (is (cl:< (cl:abs (cl:- 2.3026 (unwrap (log (wrap 10))))) 0.001))
  ;; log(exp(3)) ≈ 3
  (is (cl:< (cl:abs (cl:- 3.0 (unwrap (log (exp (wrap 3)))))) 0.0001)))

(test log-exp-inverse
  "Test that log and exp are inverse functions"
  (is (cl:< (cl:abs (cl:- 5.0 (unwrap (exp (log (wrap 5)))))) 0.0001))
  (is (cl:< (cl:abs (cl:- 2.5 (unwrap (log (exp (wrap 2.5)))))) 0.0001)))

(test expt-basic
  "Test exponentiation function"
  ;; 2^3 = 8
  (is (= 8 (unwrap (expt (wrap 2) (wrap 3)))))
  ;; 3^2 = 9
  (is (= 9 (unwrap (expt (wrap 3) (wrap 2)))))
  ;; 10^0 = 1
  (is (= 1 (unwrap (expt (wrap 10) (wrap 0)))))
  ;; 5^1 = 5
  (is (= 5 (unwrap (expt (wrap 5) (wrap 1)))))
  ;; 2^-1 = 1/2
  (is (= 1/2 (unwrap (expt (wrap 2) (wrap -1)))))
  ;; 4^(1/2) = 2
  (is (= 2.0 (unwrap (expt (wrap 4) (wrap 0.5))))))

(test expt-float
  "Test exponentiation with floats"
  ;; 2.0^3 = 8.0
  (is (= 8.0 (unwrap (expt (wrap 2.0) (wrap 3)))))
  ;; 3^0.5 ≈ 1.732 (√3)
  (is (cl:< (cl:abs (cl:- 1.732 (unwrap (expt (wrap 3) (wrap 0.5))))) 0.01)))

(test expt-negative-base
  "Test exponentiation with negative bases"
  ;; (-2)^2 = 4
  (is (= 4 (unwrap (expt (wrap -2) (wrap 2)))))
  ;; (-2)^3 = -8
  (is (= -8 (unwrap (expt (wrap -2) (wrap 3)))))
  ;; (-1)^2 = 1
  (is (= 1 (unwrap (expt (wrap -1) (wrap 2))))))

(test sqrt-basic
  "Test square root function"
  ;; sqrt(0) = 0
  (is (= 0 (unwrap (sqrt (wrap 0)))))
  ;; sqrt(1) = 1
  (is (= 1 (unwrap (sqrt (wrap 1)))))
  ;; sqrt(4) = 2
  (is (= 2 (unwrap (sqrt (wrap 4)))))
  ;; sqrt(9) = 3
  (is (= 3 (unwrap (sqrt (wrap 9)))))
  ;; sqrt(2) ≈ 1.414
  (is (cl:< (cl:abs (cl:- 1.414 (unwrap (sqrt (wrap 2))))) 0.01))
  ;; sqrt(10) ≈ 3.162
  (is (cl:< (cl:abs (cl:- 3.162 (unwrap (sqrt (wrap 10))))) 0.01)))

(test sqrt-exact
  "Test square root with exact integer results"
  (is (= 2 (unwrap (sqrt (wrap 4)))))
  (is (= 3 (unwrap (sqrt (wrap 9)))))
  (is (= 10 (unwrap (sqrt (wrap 100)))))
  (is (typep (sqrt (wrap 4)) '<float>)))

(test sqrt-float
  "Test square root with float results"
  (is (cl:< (cl:abs (cl:- 1.414 (unwrap (sqrt (wrap 2))))) 0.01))
  (is (typep (sqrt (wrap 2)) '<float>)))

(test sqrt-rational
  "Test square root with rationals"
  ;; sqrt(1/4) = 1/2
  (is (= 1/2 (unwrap (sqrt (wrap 1/4)))))
  ;; sqrt(9/4) = 3/2
  (is (= 3/2 (unwrap (sqrt (wrap 9/4))))))

(test sqrt-complex
  "Test square root of negative numbers (returns complex)"
  ;; sqrt(-1) = i
  (let ((result (unwrap (sqrt (wrap -1)))))
    (is (typep result 'complex))
    (is (cl:< (cl:abs (realpart result)) 0.0001))
    (is (cl:< (cl:abs (cl:- 1.0 (cl:abs (imagpart result)))) 0.0001))))

;;; ============================================================================
;;; Type Preservation Tests
;;; ============================================================================

(test math-type-preservation
  "Test that mathematical functions preserve or promote types appropriately"
  ;; Integer operations
  (is (typep (abs (wrap 5)) '<integer>))
  (is (typep (expt (wrap 2) (wrap 3)) '<integer>))
  (is (typep (sqrt (wrap 4)) '<float>))
  
  ;; Float results
  (is (typep (sin (wrap 1)) '<float>))
  (is (typep (exp (wrap 1)) '<float>))
  (is (typep (sqrt (wrap 2)) '<float>))
  
  ;; Rational preservation
  (is (typep (abs (wrap 1/2)) '<ratio>))
  (is (typep (sqrt (wrap 1/4)) '<float>)))

;;; ============================================================================
;;; Edge Cases and Special Values
;;; ============================================================================

(test math-special-values
  "Test mathematical functions with special values"
  ;; Zero
  (is (= 0 (unwrap (sin (wrap 0)))))
  (is (= 1 (unwrap (cos (wrap 0)))))
  (is (= 1 (unwrap (exp (wrap 0)))))
  (is (= 0 (unwrap (log (wrap 1)))))
  (is (= 0 (unwrap (sqrt (wrap 0)))))
  
  ;; One
  (is (= 1 (unwrap (expt (wrap 10) (wrap 0)))))
  (is (= 1 (unwrap (sqrt (wrap 1)))))
  
  ;; Negative values
  (is (= 5 (unwrap (abs (wrap -5)))))
  (is (= -8 (unwrap (expt (wrap -2) (wrap 3))))))

;;; ============================================================================
;;; Error Handling Tests
;;; ============================================================================

(test math-error-handling
  "Test that mathematical functions error on non-numeric inputs"
  (signals error (abs (wrap #\a)))
  (signals error (sin (wrap "hello")))
  (signals error (exp *true-instance*))
  (signals error (sqrt (wrap #\x)))
  (signals error (expt (wrap 2) (wrap "3"))))

;;; ============================================================================
;;; Scheme-type Function Tests
;;; ============================================================================

(test rationalize-tests
  "Test simplest rational calculation according to R4RS"
  (is (= 1/3 (unwrap (rationalize (wrap 0.3) (wrap 1/10)))))
  (is (= 3/10 (unwrap (rationalize (wrap 0.3)))))
  (is (= 2 (unwrap (rationalize (wrap 2.1) (wrap 0.2))))))

(test rational-parts-tests
  "Test numerator and denominator"
  (is (= 2 (unwrap (numerator (wrap 2/3)))))
  (is (= 3 (unwrap (denominator (wrap 2/3)))))
  (is (= 5 (unwrap (numerator (wrap 5)))))
  (is (= 1 (unwrap (denominator (wrap 5))))))

(test complex-parts-tests
  "Test real-part, imag-part and angle (phase)"
  (is (= 3 (unwrap (real-part (wrap #C(3 4))))))
  (is (= 4 (unwrap (imag-part (wrap #C(3 4))))))
  (is (= 0 (unwrap (angle (wrap 1)))))
  ;; Check angle of i is pi/2
  (is (cl:< (cl:abs (cl:- (cl:/ pi 2) (unwrap (angle (wrap #C(0 1)))))) 0.0001)))


  (test gcd-tests
  "Test greatest common divisor functionality"
  (is (= 0 (unwrap (gcd))))
  (is (= 5 (unwrap (gcd (wrap 5)))))
  (is (= 5 (unwrap (gcd (wrap 10) (wrap 15)))))
  (is (= 2 (unwrap (gcd (wrap 12) (wrap 10) (wrap 6)))))
  (is (= 1 (unwrap (gcd (wrap 7) (wrap 11)))))
  (is (= 4 (unwrap (gcd (wrap -8) (wrap 12))))))

(test lcm-tests
  "Test least common multiple functionality"
  (is (= 1 (unwrap (lcm))))
  (is (= 5 (unwrap (lcm (wrap 5)))))
  (is (= 30 (unwrap (lcm (wrap 10) (wrap 15)))))
  (is (= 60 (unwrap (lcm (wrap 12) (wrap 10) (wrap 6)))))
  (is (= 0 (unwrap (lcm (wrap 7) (wrap 0)))))
  (is (= 24 (unwrap (lcm (wrap -8) (wrap 6))))))