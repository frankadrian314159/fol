(in-package fol.arithop)

;;; ============================================================================
;;; Arithmetic Operations - Option 4 (Tagged Representation)
;;; ============================================================================
;;;
;;; All operations work transparently on both raw CL numbers and wrapped
;;; FOL <number> objects. Results are returned as raw CL numbers.
;;; Wrap only when you need persistence or metadata.

;;; ============================================================================
;;; Primitive Dyadic Arithmetic Operations
;;; ============================================================================

(defgeneric %+ (a b)
  (:documentation "Binary addition. Works on raw or wrapped numbers."))

(defgeneric %- (a b)
  (:documentation "Binary subtraction. Works on raw or wrapped numbers."))

(defgeneric %* (a b)
  (:documentation "Binary multiplication. Works on raw or wrapped numbers."))

(defgeneric %/ (a b)
  (:documentation "Binary division. Works on raw or wrapped numbers."))

;;; --- Direct implementations for raw numbers (most efficient path) ---

(defmethod %+ ((a number) (b number))
  (cl:+ a b))

(defmethod %- ((a number) (b number))
  (cl:- a b))

(defmethod %* ((a number) (b number))
  (cl:* a b))

(defmethod %/ ((a number) (b number))
  (cl:/ a b))

;;; --- Wrapped FOL numbers ---

(defmethod %+ ((a <number>) (b <number>))
  (cl:+ (fol-value a) (fol-value b)))

(defmethod %- ((a <number>) (b <number>))
  (cl:- (fol-value a) (fol-value b)))

(defmethod %* ((a <number>) (b <number>))
  (cl:* (fol-value a) (fol-value b)))

(defmethod %/ ((a <number>) (b <number>))
  (cl:/ (fol-value a) (fol-value b)))

;;; --- Mixed: wrapped + raw ---

(defmethod %+ ((a <number>) (b number))
  (cl:+ (fol-value a) b))

(defmethod %+ ((a number) (b <number>))
  (cl:+ a (fol-value b)))

(defmethod %- ((a <number>) (b number))
  (cl:- (fol-value a) b))

(defmethod %- ((a number) (b <number>))
  (cl:- a (fol-value b)))

(defmethod %* ((a <number>) (b number))
  (cl:* (fol-value a) b))

(defmethod %* ((a number) (b <number>))
  (cl:* a (fol-value b)))

(defmethod %/ ((a <number>) (b number))
  (cl:/ (fol-value a) b))

(defmethod %/ ((a number) (b <number>))
  (cl:/ a (fol-value b)))

;;; --- Fallback with error for non-numbers ---

(defmethod %+ (a b)
  (error "Cannot add ~A and ~A" a b))

(defmethod %- (a b)
  (error "Cannot subtract ~A and ~A" a b))

(defmethod %* (a b)
  (error "Cannot multiply ~A and ~A" a b))

(defmethod %/ (a b)
  (error "Cannot divide ~A and ~A" a b))


;;; ============================================================================
;;; Public Variadic Arithmetic Operators
;;; ============================================================================
;;; These return raw CL numbers for efficiency.

(defgeneric + (&rest args)
  (:documentation "Adds any number of values. Returns raw CL number."))

(defmethod + (&rest args)
  (cond
    ((null args) 0)
    ((null (cdr args)) (fol-value (car args)))
    (t (reduce #'%+ args))))

(defgeneric - (first-num &rest rest-nums)
  (:documentation "Subtracts values (negation if one arg). Returns raw CL number."))

(defmethod - (first-num &rest rest-nums)
  (if rest-nums
      (reduce #'%- rest-nums :initial-value (fol-value first-num))
      (cl:- (fol-value first-num))))

(defgeneric * (&rest args)
  (:documentation "Multiplies any number of values. Returns raw CL number."))

(defmethod * (&rest args)
  (cond
    ((null args) 1)
    ((null (cdr args)) (fol-value (car args)))
    (t (reduce #'%* args))))

(defgeneric / (first-num &rest rest-nums)
  (:documentation "Divides values (reciprocal if one arg). Returns raw CL number."))

(defmethod / (first-num &rest rest-nums)
  (if rest-nums
      (reduce #'%/ rest-nums :initial-value (fol-value first-num))
      (cl:/ (fol-value first-num))))


;;; ============================================================================
;;; Basic Mathematical Functions
;;; ============================================================================

(defgeneric abs (num)
  (:documentation "Returns the absolute value of NUM."))

(defmethod abs ((num number))
  (cl:abs num))

(defmethod abs ((num <number>))
  (cl:abs (fol-value num)))

(defmethod abs (obj)
  (error "ABS requires a number, got ~A" obj))


;;; ============================================================================
;;; Trigonometric Functions
;;; ============================================================================

(defgeneric sin (num)
  (:documentation "Returns the sine of NUM (in radians)."))

(defmethod sin ((num number))
  (cl:sin num))

(defmethod sin ((num <number>))
  (cl:sin (fol-value num)))

(defmethod sin (obj)
  (error "SIN requires a number, got ~A" obj))


(defgeneric cos (num)
  (:documentation "Returns the cosine of NUM (in radians)."))

(defmethod cos ((num number))
  (cl:cos num))

(defmethod cos ((num <number>))
  (cl:cos (fol-value num)))

(defmethod cos (obj)
  (error "COS requires a number, got ~A" obj))


(defgeneric tan (num)
  (:documentation "Returns the tangent of NUM (in radians)."))

(defmethod tan ((num number))
  (cl:tan num))

(defmethod tan ((num <number>))
  (cl:tan (fol-value num)))

(defmethod tan (obj)
  (error "TAN requires a number, got ~A" obj))


(defgeneric asin (num)
  (:documentation "Returns the arcsine of NUM."))

(defmethod asin ((num number))
  (cl:asin num))

(defmethod asin ((num <number>))
  (cl:asin (fol-value num)))

(defmethod asin (obj)
  (error "ASIN requires a number, got ~A" obj))


(defgeneric acos (num)
  (:documentation "Returns the arccosine of NUM."))

(defmethod acos ((num number))
  (cl:acos num))

(defmethod acos ((num <number>))
  (cl:acos (fol-value num)))

(defmethod acos (obj)
  (error "ACOS requires a number, got ~A" obj))


(defgeneric atan (num)
  (:documentation "Returns the arctangent of NUM."))

(defmethod atan ((num number))
  (cl:atan num))

(defmethod atan ((num <number>))
  (cl:atan (fol-value num)))

(defmethod atan (obj)
  (error "ATAN requires a number, got ~A" obj))


(defgeneric atan2 (y x)
  (:documentation "Returns the arctangent of Y/X, using signs to determine quadrant."))

(defmethod atan2 ((y number) (x number))
  (cl:atan y x))

(defmethod atan2 ((y <number>) (x <number>))
  (cl:atan (fol-value y) (fol-value x)))

(defmethod atan2 ((y <number>) (x number))
  (cl:atan (fol-value y) x))

(defmethod atan2 ((y number) (x <number>))
  (cl:atan y (fol-value x)))

(defmethod atan2 (y x)
  (error "ATAN2 requires numbers, got ~A and ~A" y x))


;;; ============================================================================
;;; Hyperbolic Functions
;;; ============================================================================

(defgeneric sinh (num)
  (:documentation "Returns the hyperbolic sine of NUM."))

(defmethod sinh ((num number))
  (cl:sinh num))

(defmethod sinh ((num <number>))
  (cl:sinh (fol-value num)))

(defmethod sinh (obj)
  (error "SINH requires a number, got ~A" obj))


(defgeneric cosh (num)
  (:documentation "Returns the hyperbolic cosine of NUM."))

(defmethod cosh ((num number))
  (cl:cosh num))

(defmethod cosh ((num <number>))
  (cl:cosh (fol-value num)))

(defmethod cosh (obj)
  (error "COSH requires a number, got ~A" obj))


(defgeneric tanh (num)
  (:documentation "Returns the hyperbolic tangent of NUM."))

(defmethod tanh ((num number))
  (cl:tanh num))

(defmethod tanh ((num <number>))
  (cl:tanh (fol-value num)))

(defmethod tanh (obj)
  (error "TANH requires a number, got ~A" obj))


(defgeneric asinh (num)
  (:documentation "Returns the hyperbolic arcsine of NUM."))

(defmethod asinh ((num number))
  (cl:asinh num))

(defmethod asinh ((num <number>))
  (cl:asinh (fol-value num)))

(defmethod asinh (obj)
  (error "ASINH requires a number, got ~A" obj))


(defgeneric acosh (num)
  (:documentation "Returns the hyperbolic arccosine of NUM."))

(defmethod acosh ((num number))
  (cl:acosh num))

(defmethod acosh ((num <number>))
  (cl:acosh (fol-value num)))

(defmethod acosh (obj)
  (error "ACOSH requires a number, got ~A" obj))


(defgeneric atanh (num)
  (:documentation "Returns the hyperbolic arctangent of NUM."))

(defmethod atanh ((num number))
  (cl:atanh num))

(defmethod atanh ((num <number>))
  (cl:atanh (fol-value num)))

(defmethod atanh (obj)
  (error "ATANH requires a number, got ~A" obj))


;;; ============================================================================
;;; Exponential and Logarithmic Functions
;;; ============================================================================

(defgeneric exp (num)
  (:documentation "Returns e raised to the power NUM."))

(defmethod exp ((num number))
  (cl:exp num))

(defmethod exp ((num <number>))
  (cl:exp (fol-value num)))

(defmethod exp (obj)
  (error "EXP requires a number, got ~A" obj))


(defgeneric log (num)
  (:documentation "Returns the natural logarithm of NUM."))

(defmethod log ((num number))
  (cl:log num))

(defmethod log ((num <number>))
  (cl:log (fol-value num)))

(defmethod log (obj)
  (error "LOG requires a number, got ~A" obj))


(defgeneric expt (base power)
  (:documentation "Returns BASE raised to the POWER."))

(defmethod expt ((base number) (power number))
  (cl:expt base power))

(defmethod expt ((base <number>) (power <number>))
  (cl:expt (fol-value base) (fol-value power)))

(defmethod expt ((base <number>) (power number))
  (cl:expt (fol-value base) power))

(defmethod expt ((base number) (power <number>))
  (cl:expt base (fol-value power)))

(defmethod expt (base power)
  (error "EXPT requires numbers, got ~A and ~A" base power))


(defgeneric sqrt (num)
  (:documentation "Returns the square root of NUM."))

(defmethod sqrt ((num number))
  (cl:sqrt num))

(defmethod sqrt ((num <number>))
  (cl:sqrt (fol-value num)))

(defmethod sqrt (obj)
  (error "SQRT requires a number, got ~A" obj))


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

(defmethod rationalize ((num number) &optional tolerance)
  (if tolerance
      (scheme-rationalize num (fol-value tolerance))
      (cl:rationalize num)))

(defmethod rationalize ((num <number>) &optional tolerance)
  (let ((val (fol-value num)))
    (if tolerance
        (scheme-rationalize val (fol-value tolerance))
        (cl:rationalize val))))

(defgeneric numerator (number)
  (:documentation "Returns the numerator of a rational number."))

(defmethod numerator ((num rational))
  (cl:numerator num))

(defmethod numerator ((num <number>))
  (cl:numerator (fol-value num)))

(defgeneric denominator (number)
  (:documentation "Returns the denominator of a rational number."))

(defmethod denominator ((num rational))
  (cl:denominator num))

(defmethod denominator ((num <number>))
  (cl:denominator (fol-value num)))

(defgeneric real-part (number)
  (:documentation "Returns the real part of a complex number."))

(defmethod real-part ((num number))
  (cl:realpart num))

(defmethod real-part ((num <number>))
  (cl:realpart (fol-value num)))

(defgeneric imag-part (number)
  (:documentation "Returns the imaginary part of a complex number."))

(defmethod imag-part ((num number))
  (cl:imagpart num))

(defmethod imag-part ((num <number>))
  (cl:imagpart (fol-value num)))

(defgeneric angle (number)
  (:documentation "Returns the angle (phase) of a complex number."))

(defmethod angle ((num number))
  (cl:phase num))

(defmethod angle ((num <number>))
  (cl:phase (fol-value num)))


;;; ============================================================================
;;; GCD and LCM
;;; ============================================================================

(defgeneric %gcd (a b)
  (:documentation "Binary greatest common divisor."))

(defmethod %gcd ((a integer) (b integer))
  (cl:gcd a b))

(defmethod %gcd ((a <integer>) (b <integer>))
  (cl:gcd (fol-value a) (fol-value b)))

(defmethod %gcd ((a <integer>) (b integer))
  (cl:gcd (fol-value a) b))

(defmethod %gcd ((a integer) (b <integer>))
  (cl:gcd a (fol-value b)))

(defmethod %gcd (a b)
  (let ((ua (fol-value a))
        (ub (fol-value b)))
    (if (and (integerp ua) (integerp ub))
        (cl:gcd ua ub)
        (error "GCD requires integers, got ~A and ~A" a b))))

(defgeneric %lcm (a b)
  (:documentation "Binary least common multiple."))

(defmethod %lcm ((a integer) (b integer))
  (cl:lcm a b))

(defmethod %lcm ((a <integer>) (b <integer>))
  (cl:lcm (fol-value a) (fol-value b)))

(defmethod %lcm ((a <integer>) (b integer))
  (cl:lcm (fol-value a) b))

(defmethod %lcm ((a integer) (b <integer>))
  (cl:lcm a (fol-value b)))

(defmethod %lcm (a b)
  (let ((ua (fol-value a))
        (ub (fol-value b)))
    (if (and (integerp ua) (integerp ub))
        (cl:lcm ua ub)
        (error "LCM requires integers, got ~A and ~A" a b))))

;; Variadic Public Functions
(defun gcd (&rest args)
  "Returns the greatest common divisor of zero or more integers."
  (cond ((null args) 0)
        ((null (cdr args)) (cl:abs (fol-value (car args))))
        (t (reduce #'%gcd args))))

(defun lcm (&rest args)
  "Returns the least common multiple of zero or more integers."
  (cond ((null args) 1)
        ((null (cdr args)) (cl:abs (fol-value (car args))))
        (t (reduce #'%lcm args))))
