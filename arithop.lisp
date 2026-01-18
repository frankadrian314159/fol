(in-package fol.arithop)

;;; ============================================================================
;;; Primitive Dyadic Arithmetic Operations
;;; ============================================================================

(defgeneric %+ (a b)
  (:documentation "Binary addition. Returns unwrapped result."))

(defgeneric %- (a b)
  (:documentation "Binary subtraction. Returns unwrapped result."))

(defgeneric %* (a b)
  (:documentation "Binary multiplication. Returns unwrapped result."))

(defgeneric %/ (a b)
  (:documentation "Binary division. Returns unwrapped result."))

;;; --- Number × Number Implementations ---

(defmethod %+ ((a <number>) (b <number>))
  (cl:+ (unwrap-number a) (unwrap-number b)))

(defmethod %- ((a <number>) (b <number>))
  (cl:- (unwrap-number a) (unwrap-number b)))

(defmethod %* ((a <number>) (b <number>))
  (cl:* (unwrap-number a) (unwrap-number b)))

(defmethod %/ ((a <number>) (b <number>))
  (cl:/ (unwrap-number a) (unwrap-number b)))

;;; --- Mixed / Native Implementations ---
;;; Support mixed operations like (%+ (wrap 1) 2)

(defmethod %+ ((a t) (b t))
  (let ((ua (unwrap a))
        (ub (unwrap b)))
    (if (and (numberp ua) (numberp ub))
        (cl:+ ua ub)
        (error "Cannot add ~A and ~A" a b))))

(defmethod %- ((a t) (b t))
  (let ((ua (unwrap a))
        (ub (unwrap b)))
    (if (and (numberp ua) (numberp ub))
        (cl:- ua ub)
        (error "Cannot subtract ~A and ~A" a b))))

(defmethod %* ((a t) (b t))
  (let ((ua (unwrap a))
        (ub (unwrap b)))
    (if (and (numberp ua) (numberp ub))
        (cl:* ua ub)
        (error "Cannot multiply ~A and ~A" a b))))

(defmethod %/ ((a t) (b t))
  (let ((ua (unwrap a))
        (ub (unwrap b)))
    (if (and (numberp ua) (numberp ub))
        (cl:/ ua ub)
        (error "Cannot divide ~A and ~A" a b))))


;;; ============================================================================
;;; Public Variadic Arithmetic Operators
;;; ============================================================================

(defgeneric + (&rest args)
  (:documentation "Adds any number of FOL <number> instances."))

(defmethod + (&rest args)
  (let ((result
         (cond
           ;; No arguments: identity is 0
           ((null args) 0)
           ;; One argument: return it unwrapped
           ((null (cdr args)) (unwrap (car args)))
           ;; Multiple arguments: fold left using %+
           (t (reduce #'%+ args)))))
    (wrap result)))

(defgeneric - (first-num &rest rest-nums)
  (:documentation "Subtracts FOL <number> instances (negation if one arg)."))

(defmethod - (first-num &rest rest-nums)
  (let ((result
         (if rest-nums
             ;; Multiple arguments: subtract rest from first
             (reduce #'%- rest-nums :initial-value (unwrap first-num))
             ;; One argument: negate
             (cl:- (unwrap first-num)))))
    (wrap result)))

(defgeneric * (&rest args)
  (:documentation "Multiplies any number of FOL <number> instances."))

(defmethod * (&rest args)
  (let ((result
         (cond
           ;; No arguments: identity is 1
           ((null args) 1)
           ;; One argument: return it unwrapped
           ((null (cdr args)) (unwrap (car args)))
           ;; Multiple arguments: fold left using %*
           (t (reduce #'%* args)))))
    (wrap result)))

(defgeneric / (first-num &rest rest-nums)
  (:documentation "Divides FOL <number> instances (reciprocal if one arg)."))

(defmethod / (first-num &rest rest-nums)
  (let ((result
         (if rest-nums
             ;; Multiple arguments: divide first by rest
             (reduce #'%/ rest-nums :initial-value (unwrap first-num))
             ;; One argument: reciprocal
             (cl:/ (unwrap first-num)))))
    (wrap result)))

;;; ============================================================================
;;; Basic Mathematical Functions
;;; ============================================================================

(defgeneric abs (num)
  (:documentation "Returns the absolute value of NUM."))

(defmethod abs ((num <number>))
  "Absolute value of a number."
  (wrap (cl:abs (unwrap-number num))))

(defmethod abs (obj)
  "Error for non-numeric values."
  (error "ABS requires a FOL number, got ~A" obj))


;;; ============================================================================
;;; Trigonometric Functions
;;; ============================================================================

(defgeneric sin (num)
  (:documentation "Returns the sine of NUM (in radians)."))

(defmethod sin ((num <number>))
  "Sine function."
  (wrap (cl:sin (unwrap-number num))))

(defmethod sin (obj)
  (error "SIN requires a FOL number, got ~A" obj))


(defgeneric cos (num)
  (:documentation "Returns the cosine of NUM (in radians)."))

(defmethod cos ((num <number>))
  "Cosine function."
  (wrap (cl:cos (unwrap-number num))))

(defmethod cos (obj)
  (error "COS requires a FOL number, got ~A" obj))


(defgeneric tan (num)
  (:documentation "Returns the tangent of NUM (in radians)."))

(defmethod tan ((num <number>))
  "Tangent function."
  (wrap (cl:tan (unwrap-number num))))

(defmethod tan (obj)
  (error "TAN requires a FOL number, got ~A" obj))


(defgeneric asin (num)
  (:documentation "Returns the arcsine of NUM."))

(defmethod asin ((num <number>))
  "Arcsine function."
  (wrap (cl:asin (unwrap num))))

(defmethod asin (obj)
  (error "ASIN requires a FOL number, got ~A" obj))


(defgeneric acos (num)
  (:documentation "Returns the arccosine of NUM."))

(defmethod acos ((num <number>))
  "Arccosine function."
  (wrap (cl:acos (unwrap num))))

(defmethod acos (obj)
  (error "ACOS requires a FOL number, got ~A" obj))


(defgeneric atan (num)
  (:documentation "Returns the arctangent of NUM."))

(defmethod atan ((num <number>))
  "Arctangent function (one argument)."
  (wrap (cl:atan (unwrap num))))

(defmethod atan (obj)
  (error "ATAN requires a FOL number, got ~A" obj))


(defgeneric atan2 (y x)
  (:documentation "Returns the arctangent of Y/X, using signs to determine quadrant."))

(defmethod atan2 ((y <number>) (x <number>))
  "Two-argument arctangent function."
  (wrap (cl:atan (unwrap-number y) (unwrap-number x))))

(defmethod atan2 (y x)
  (error "ATAN2 requires FOL numbers, got ~A and ~A" y x))


;;; ============================================================================
;;; Hyperbolic Functions
;;; ============================================================================

(defgeneric sinh (num)
  (:documentation "Returns the hyperbolic sine of NUM."))

(defmethod sinh ((num <number>))
  "Hyperbolic sine function."
  (wrap (cl:sinh (unwrap-number num))))

(defmethod sinh (obj)
  (error "SINH requires a FOL number, got ~A" obj))


(defgeneric cosh (num)
  (:documentation "Returns the hyperbolic cosine of NUM."))

(defmethod cosh ((num <number>))
  "Hyperbolic cosine function."
  (wrap (cl:cosh (unwrap-number num))))

(defmethod cosh (obj)
  (error "COSH requires a FOL number, got ~A" obj))


(defgeneric tanh (num)
  (:documentation "Returns the hyperbolic tangent of NUM."))

(defmethod tanh ((num <number>))
  "Hyperbolic tangent function."
  (wrap (cl:tanh (unwrap-number num))))

(defmethod tanh (obj)
  (error "TANH requires a FOL number, got ~A" obj))


(defgeneric asinh (num)
  (:documentation "Returns the hyperbolic arcsine of NUM."))

(defmethod asinh ((num <number>))
  "Hyperbolic arcsine function."
  (wrap (cl:asinh (unwrap-number num))))

(defmethod asinh (obj)
  (error "ASINH requires a FOL number, got ~A" obj))


(defgeneric acosh (num)
  (:documentation "Returns the hyperbolic arccosine of NUM."))

(defmethod acosh ((num <number>))
  "Hyperbolic arccosine function."
  (wrap (cl:acosh (unwrap-number num))))

(defmethod acosh (obj)
  (error "ACOSH requires a FOL number, got ~A" obj))


(defgeneric atanh (num)
  (:documentation "Returns the hyperbolic arctangent of NUM."))

(defmethod atanh ((num <number>))
  "Hyperbolic arctangent function."
  (wrap (cl:atanh (unwrap-number num))))

(defmethod atanh (obj)
  (error "ATANH requires a FOL number, got ~A" obj))


;;; ============================================================================
;;; Exponential and Logarithmic Functions
;;; ============================================================================

(defgeneric exp (num)
  (:documentation "Returns e raised to the power NUM."))

(defmethod exp ((num <number>))
  "Exponential function (e^NUM)."
  (wrap (cl:exp (unwrap-number num))))

(defmethod exp (obj)
  (error "EXP requires a FOL number, got ~A" obj))


(defgeneric log (num)
  (:documentation "Returns the natural logarithm of NUM."))

(defmethod log ((num <number>))
  "Natural logarithm function."
  (wrap (cl:log (unwrap-number num))))

(defmethod log (obj)
  (error "LOG requires a FOL number, got ~A" obj))


(defgeneric expt (base power)
  (:documentation "Returns BASE raised to the POWER."))

(defmethod expt ((base <number>) (power <number>))
  "Exponentiation function."
  (wrap (cl:expt (unwrap-number base) (unwrap-number power))))

(defmethod expt (base power)
  (error "EXPT requires FOL numbers, got ~A and ~A" base power))


(defgeneric sqrt (num)
  (:documentation "Returns the square root of NUM."))

(defmethod sqrt ((num <number>))
  "Square root function."
  (wrap (cl:sqrt (unwrap-number num))))

(defmethod sqrt (obj)
  (error "SQRT requires a FOL number, got ~A" obj))


;;; ============================================================================
;;; Scheme-style Rationalize and Rational/Complex parts
;;; ============================================================================

(defun scheme-rationalize (x e)
  "Implementation of Scheme's simplest-rational-in-interval algorithm."
  (let ((e (cl:abs e)))
    (labels ((simplest (x y)
               (let ((fx (cl:floor x))
                     (fy (cl:floor y)))
                 (cond ((>= fx x) fx)
                       ((= fx fy) (cl:+ fx (cl:/ 1 (simplest (cl:/ 1 (cl:- y fy)) (cl:/ 1 (cl:- x fx))))))
                       (t (cl:1+ fx))))))
      (let ((lower (cl:- x e))
            (upper (cl:+ x e)))
        (cond ((cl:< x 0) (cl:- (scheme-rationalize (cl:- x) e)))
              ((cl:<= lower 0 upper) 0)
              ((cl:>= upper (cl:floor upper) lower) (cl:floor upper))
              (t (simplest lower upper)))))))

(defgeneric rationalize (number &optional tolerance)
  (:documentation "Returns the simplest rational number differing from NUMBER by at most TOLERANCE."))

(defmethod rationalize ((num <number>) &optional tolerance)
  (let ((val (unwrap num)))
    (wrap (if tolerance
              (scheme-rationalize val (unwrap tolerance))
              (cl:rationalize val)))))

(defmethod rationalize ((num number) &optional tolerance)
  (wrap (if tolerance
            (scheme-rationalize num (unwrap tolerance))
            (cl:rationalize num))))

(defgeneric numerator (number)
  (:documentation "Returns the numerator of a rational number."))

(defmethod numerator ((num <number>)) (wrap (cl:numerator (unwrap num))))

(defgeneric denominator (number)
  (:documentation "Returns the denominator of a rational number."))

(defmethod denominator ((num <number>)) (wrap (cl:denominator (unwrap num))))

(defgeneric real-part (number)
  (:documentation "Returns the real part of a complex number."))

(defmethod real-part ((num <number>)) (wrap (cl:realpart (unwrap num))))

(defgeneric imag-part (number)
  (:documentation "Returns the imaginary part of a complex number."))

(defmethod imag-part ((num <number>)) (wrap (cl:imagpart (unwrap num))))

(defgeneric angle (number)
  (:documentation "Returns the angle (phase) of a complex number."))

(defmethod angle ((num <number>)) (wrap (cl:phase (unwrap num))))

;;; ============================================================================
;;; GCD and LCM
;;; ============================================================================

(defgeneric %gcd (a b)
  (:documentation "Binary greatest common divisor."))

(defmethod %gcd ((a <integer>) (b <integer>))
  (wrap (cl:gcd (unwrap a) (unwrap b))))

(defmethod %gcd ((a t) (b t))
  (let ((ua (unwrap a))
        (ub (unwrap b)))
    (if (and (integerp ua) (integerp ub))
        (wrap (cl:gcd ua ub))
        (error "GCD requires integers, got ~A and ~A" a b))))

(defgeneric %lcm (a b)
  (:documentation "Binary least common multiple."))

(defmethod %lcm ((a <integer>) (b <integer>))
  (wrap (cl:lcm (unwrap a) (unwrap b))))

(defmethod %lcm ((a t) (b t))
  (let ((ua (unwrap a))
        (ub (unwrap b)))
    (if (and (integerp ua) (integerp ub))
        (wrap (cl:lcm ua ub))
        (error "LCM requires integers, got ~A and ~A" a b))))

;; Variadic Public Functions
(defun gcd (&rest args)
  "Returns the greatest common divisor of zero or more integers."
  (cond ((null args) (wrap 0))
        ((null (cdr args)) (wrap (cl:abs (unwrap (car args)))))
        (t (reduce #'%gcd args))))

(defun lcm (&rest args)
  "Returns the least common multiple of zero or more integers."
  (cond ((null args) (wrap 1))
        ((null (cdr args)) (wrap (cl:abs (unwrap (car args)))))
        (t (reduce #'%lcm args))))