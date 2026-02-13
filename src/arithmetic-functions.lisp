;;; ============================================================================
;;; Arithmetic Operations - Option 4 (Tagged Representation)
;;; ============================================================================
;;;
;;; All operations work transparently on both raw CL numbers and wrapped
;;; FOL <number> objects. Results are returned as raw CL numbers.
;;; Wrap only when you need persistence or metadata.

(in-package :fol.compiler.arithmetic-functions)

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


(defgeneric ln (num)
  (:documentation "Returns the natural logarithm of NUM."))

(defmethod ln ((num number))
  (cl:log num))

(defmethod ln ((num <number>))
  (cl:log (fol-value num)))

(defmethod ln (obj)
  (error "LN requires a number, got ~A" obj))


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

;;; Numeric type functions - work on both raw and wrapped values

(defgeneric odd? (num)
  (:documentation "Returns T if NUM is an odd integer, NIL otherwise."))

(defmethod odd? ((num integer))
  (cl:oddp num))

(defmethod odd? ((num number))
  (error "ODD? requires an integer, got ~A of type ~A" num (type-of num)))

(defmethod odd? (obj)
  (error "ODD? requires an integer, got ~A of type ~A" obj (type-of obj)))


(defgeneric even? (num)
  (:documentation "Returns T if NUM is an even integer, NIL otherwise."))

(defmethod even? ((num integer))
  (cl:evenp num))

(defmethod even? ((num number))
  (error "EVEN? requires an integer, got ~A of type ~A" num (type-of num)))

(defmethod even? (obj)
  (error "EVEN? requires an integer, got ~A of type ~A" obj (type-of obj)))


(defgeneric zero? (num)
  (:documentation "Returns T if NUM equals zero, NIL otherwise."))

(defmethod zero? ((num number))
  (cl:zerop num))

(defmethod zero? ((num <number>))
  (cl:zerop (fol-value num)))

(defmethod zero? (obj)
  (error "ZERO? requires a number, got ~A of type ~A" obj (type-of obj)))


(defgeneric positive? (num)
  (:documentation "Returns T if NUM is greater than zero, NIL otherwise."))

(defmethod positive? ((num real))
  (cl:plusp num))

(defmethod positive? ((num number))
  (error "POSITIVE? requires a real number, got ~A of type ~A" num (type-of num)))

(defmethod positive? (obj)
  (error "POSITIVE? requires a real number, got ~A of type ~A" obj (type-of obj))


(defgeneric negative? (num)
  (:documentation "Returns T if NUM is less than zero, NIL otherwise."))

(defmethod negative? ((num real))
  (cl:minusp num))

(defmethod negative? ((num number))
  (error "NEGATIVE? requires a real number, got ~A of type ~A" num (type-of num)))

(defmethod negative? (obj)
  (error "NEGATIVE? requires a real number, got ~A of type ~A" obj (type-of obj)))



(defgeneric integral? (num)
  (:documentation "Returns T if NUM has an integer value, NIL otherwise."))

(defmethod integral? ((num integer))
  t)

(defmethod integral? ((num number))
  nil)

  nil)

(defmethod integral? (obj)
  (error "INTEGRAL? requires a number, got ~A of type ~A" obj (type-of obj)))


(defgeneric nat-int? (num)
  (:documentation "Returns T if NUM is a non-negative integer (>= 0), NIL otherwise."))

(defmethod nat-int? ((num integer))
  (cl:>= num 0))

(defmethod nat-int? ((num number))
  nil)

(defmethod nat-int? (obj)
  nil)


(defgeneric pos-int? (num)
  (:documentation "Returns T if NUM is a positive integer (> 0), NIL otherwise."))

(defmethod pos-int? ((num integer))
  (cl:> num 0))

(defmethod pos-int? ((num number))
  nil)

(defmethod pos-int? (obj)
  nil)


(defgeneric NaN? (num)
  (:documentation "Returns T if NUM is a floating-point NaN (Not a Number), NIL otherwise."))

(defmethod NaN? ((num float))
  ;; Use SBCL's built-in float-nan-p to avoid triggering floating-point exceptions
  #+sbcl (sb-ext:float-nan-p num)
  ;; Fallback for other implementations: NaN is the only value not equal to itself
  #-sbcl (/= num num))

(defmethod NaN? ((num <float>))
  (let ((val (fol-value num)))
    #+sbcl (sb-ext:float-nan-p val)
    #-sbcl (/= val val)))

(defmethod NaN? ((num number))
  ;; Non-float numbers are never NaN
  nil)

(defmethod NaN? ((num <number>))
  ;; Non-float wrapped numbers are never NaN
  nil)

(defmethod NaN? (obj)
  (error "NaN? requires a number, got ~A of type ~A" obj (type-of obj)))


(defgeneric infinite? (num)
  (:documentation "Returns T if NUM is a floating-point infinity (positive or negative), NIL otherwise."))

(defmethod infinite? ((num float))
  ;; Infinity satisfies: non-zero and x = x/2 (only infinity has this property)
  (and (not (zerop num))
       (= num (/ num 2))))

(defmethod infinite? ((num number))
  ;; Non-float numbers are never infinite
  nil)


(defmethod infinite? (obj)
  (error "INFINITE? requires a number, got ~A of type ~A" obj (type-of obj)))


;;; Type conversion functions

(defgeneric <complex> (num)
  (:documentation "Converts a number to a complex number with imaginary part 0.
   If the number is already complex, returns it unchanged."))

(defmethod <complex> ((num complex))
  "Complex numbers are returned unchanged."
  num)

(defmethod <complex> ((num real))
  "Convert a real number to complex with imaginary part 0.
   Uses 0.0 for imaginary part to ensure result is always a complex."
  (cl:complex (float num) 0.0))

(defmethod <complex> (obj)
  (error "<COMPLEX> requires a number, got ~A of type ~A" obj (type-of obj)))

(defgeneric <single-float> (num)
  (:documentation "Converts a real number to a single-float.
   If the number is already a single-float, returns it unchanged."))

(defmethod <single-float> ((num single-float))
  "Single-floats are returned unchanged."
  num)

(defmethod <single-float> ((num real))
  "Convert a real number to single-float."
  (coerce num 'single-float))

(defmethod <single-float> (obj)
  (error "<SINGLE-FLOAT> requires a real number, got ~A of type ~A" obj (type-of obj)))

(defun check-double-float-range (num)
  "Check if NUM is within the range representable by double-float.
   Signals an error if out of range."
  (let ((abs-num (cl:abs num)))
    (when (and (cl:> abs-num 0)
               (or (cl:> abs-num most-positive-double-float)
                   (cl:< abs-num least-positive-normalized-double-float)))
      ;; Allow denormalized numbers and exact zero, but error on overflow
      (when (cl:> abs-num most-positive-double-float)
        (error "<DOUBLE-FLOAT> value ~A is out of range for double-float" num)))))

(defgeneric <double-float> (num)
  (:documentation "Converts a real number to a double-float.
   If the number is already a double-float, returns it unchanged.
   Signals an error if the number is out of range for double-float."))

(defmethod <double-float> ((num double-float))
  "Double-floats are returned unchanged."
  num)

(defmethod <double-float> ((num single-float))
  "Convert a single-float to double-float."
  (coerce num 'double-float))

(defmethod <double-float> ((num integer))
  "Convert an integer to double-float with range checking."
  (check-double-float-range num)
  (coerce num 'double-float))

(defmethod <double-float> ((num ratio))
  "Convert a ratio to double-float with range checking."
  (check-double-float-range num)
  (coerce num 'double-float))

(defmethod <double-float> (obj)
  (error "<DOUBLE-FLOAT> requires a real number, got ~A of type ~A" obj (type-of obj)))


;;; Random number generation

(defun rand (&optional n)
  "Returns a random number.
With no argument, returns a random double-float in [0.0, 1.0).
With a positive integer argument N, returns a random integer in [0, N)."
  (cond
    ((null n) (random 1.0d0))
    ((and (integerp n) (cl:plusp n)) (random n))
    ((and (typep n '<integer>) (cl:plusp (fol-value n))) (random (fol-value n)))
    (t (error "RAND requires no argument or a positive integer, got ~A" n))))

(defun make-seeded-random-state (seed)
  "Create a random state seeded with SEED (a non-negative integer)."
  (unless (and (integerp seed) (cl:>= seed 0))
    (error "MAKE-SEEDED-RANDOM-STATE requires a non-negative integer seed, got ~A" seed))
  #+sbcl (sb-ext:seed-random-state seed)
  #-sbcl (progn
           ;; For non-SBCL implementations, we use a workaround:
           ;; Create a state and use it to "warm up" with the seed
           (let ((state (make-random-state t)))
             ;; Consume seed number of random values to get different sequences
             (dotimes (i (mod seed 1000))
               (random 1.0 state))
             state)))

(defun call-with-seed (seed thunk)
  "Call THUNK with *random-state* bound to a state seeded from SEED.
This is the underlying implementation for the with-seed macro."
  (let ((*random-state* (make-seeded-random-state seed)))
    (funcall thunk)))


;;; Parsing functions

(defun parse-int (int-string)
  "Parses an integer string and returns a FOL <integer> instance.
   INT-STRING should contain a valid integer representation.
   Example: (parse-int \"42\") => 42
            (parse-int \"-17\") => -17
            (parse-int \"3.14\") => ERROR"
  (let ((str (typecase int-string
               (string int-string)
               (<string> (fol-value int-string))
               (t (error "Expected a string for parse-int, got ~A" (type-of int-string))))))
    (let ((form (let ((*read-eval* nil))  ; Safety: disable #. reader macro
                  (read-from-string str))))
      (if (integerp form)
          (wrap-number form)
          (error "Expected an integer, got ~S" form)))))

(defun parse-double (double-string)
  "Parses a floating-point string and returns a FOL <double-float> instance.
   DOUBLE-STRING should contain a valid floating-point representation.
   Integers are automatically converted to double-float.
   Example: (parse-double \"3.14\") => 3.14d0
            (parse-double \"42\") => 42.0d0
            (parse-double \"-1.5e10\") => -1.5d10"
  (let ((str (typecase double-string
               (string double-string)
               (<string> (fol-value double-string))
               (t (error "Expected a string for parse-double, got ~A" (type-of double-string))))))
    (let ((form (let ((*read-eval* nil))  ; Safety: disable #. reader macro
                  (read-from-string str))))
      (if (realp form)
          (wrap-number (coerce form 'double-float))
          (error "Expected a real number, got ~S" form)))))


;;; Integer conversion function

(defgeneric int (obj)
  (:documentation "Converts an object to an integer.
   - Characters are converted to their character code.
   - Booleans are converted to 1 (true) or 0 (false/nil).
   - Integers are returned unchanged."))

(defmethod int ((obj character))
  "Convert a character to its character code."
  (cl:char-code obj))

(defmethod int ((obj (eql t)))
  "Convert true to 1."
  1)

(defmethod int ((obj (eql nil)))
  "Convert nil/false to 0."
  0)

(defmethod int ((obj <bool>))
  "Convert a wrapped boolean to 1 or 0."
  (if (fol-value obj) 1 0))

(defmethod int ((obj integer))
  "Integers are returned unchanged."
  obj)

(defmethod int (obj)
  (error "INT requires a character, boolean, or integer, got ~A of type ~A" obj (type-of obj)))
