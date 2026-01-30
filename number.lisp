(in-package fol.number)

;;; ============================================================================
;;; Number Operations - Option 4 (Tagged Representation)
;;; ============================================================================
;;;
;;; Type predicates and operations work on both raw CL numbers and wrapped
;;; FOL <number> objects. Results are returned as raw CL values.

;;; Number type predicates - work on both raw and wrapped values

(defgeneric <number>? (obj) (:documentation "Returns T if OBJ is a FOL <number> or raw number."))
(defmethod <number>? (obj) nil)
(defmethod <number>? ((obj <number>)) t)
(defmethod <number>? ((obj number)) t)

(defgeneric <complex>? (obj) (:documentation "Returns T if OBJ is a FOL <complex> or raw complex."))
(defmethod <complex>? (obj) nil)
(defmethod <complex>? ((obj <complex>)) t)
(defmethod <complex>? ((obj complex)) t)

(defgeneric <real>? (obj) (:documentation "Returns T if OBJ is a FOL <real> or raw real."))
(defmethod <real>? (obj) nil)
(defmethod <real>? ((obj <real>)) t)
(defmethod <real>? ((obj real)) t)

(defgeneric <float>? (obj) (:documentation "Returns T if OBJ is a FOL <float> or raw float."))
(defmethod <float>? (obj) nil)
(defmethod <float>? ((obj <float>)) t)
(defmethod <float>? ((obj float)) t)

(defgeneric <single-float>? (obj) (:documentation "Returns T if OBJ is a FOL <single-float> or raw single-float."))
(defmethod <single-float>? (obj) nil)
(defmethod <single-float>? ((obj <single-float>)) t)
(defmethod <single-float>? ((obj single-float)) t)

(defgeneric <double-float>? (obj) (:documentation "Returns T if OBJ is a FOL <double-float> or raw double-float."))
(defmethod <double-float>? (obj) nil)
(defmethod <double-float>? ((obj <double-float>)) t)
(defmethod <double-float>? ((obj double-float)) t)

(defgeneric <rational>? (obj) (:documentation "Returns T if OBJ is a FOL <rational> or raw rational."))
(defmethod <rational>? (obj) nil)
(defmethod <rational>? ((obj <rational>)) t)
(defmethod <rational>? ((obj rational)) t)

(defgeneric <integer>? (obj) (:documentation "Returns T if OBJ is a FOL <integer> or raw integer."))
(defmethod <integer>? (obj) nil)
(defmethod <integer>? ((obj <integer>)) t)
(defmethod <integer>? ((obj integer)) t)

(defgeneric <fixnum>? (obj) (:documentation "Returns T if OBJ is a FOL <fixnum> or raw fixnum."))
(defmethod <fixnum>? (obj) nil)
(defmethod <fixnum>? ((obj <fixnum>)) t)
(defmethod <fixnum>? ((obj fixnum)) t)

(defgeneric <bignum>? (obj) (:documentation "Returns T if OBJ is a FOL <bignum> or raw bignum."))
(defmethod <bignum>? (obj) nil)
(defmethod <bignum>? ((obj <bignum>)) t)
(defmethod <bignum>? ((obj bignum)) t)

(defgeneric <ratio>? (obj) (:documentation "Returns T if OBJ is a FOL <ratio> or raw ratio."))
(defmethod <ratio>? (obj) nil)
(defmethod <ratio>? ((obj <ratio>)) t)
(defmethod <ratio>? ((obj ratio)) t)


;;; Print Object
(defmethod print-object ((obj <number>) stream)
  (format stream "~A" (fol-value obj)))


;;; Numeric type functions - work on both raw and wrapped values

(defgeneric odd? (num)
  (:documentation "Returns T if NUM is an odd integer, NIL otherwise."))

(defmethod odd? ((num integer))
  (cl:oddp num))

(defmethod odd? ((num <integer>))
  (cl:oddp (fol-value num)))

(defmethod odd? ((num number))
  (error "ODD? requires an integer, got ~A of type ~A" num (type-of num)))

(defmethod odd? ((num <number>))
  (error "ODD? requires an integer, got ~A of type ~A" num (type-of num)))

(defmethod odd? (obj)
  (error "ODD? requires an integer, got ~A" obj))


(defgeneric even? (num)
  (:documentation "Returns T if NUM is an even integer, NIL otherwise."))

(defmethod even? ((num integer))
  (cl:evenp num))

(defmethod even? ((num <integer>))
  (cl:evenp (fol-value num)))

(defmethod even? ((num number))
  (error "EVEN? requires an integer, got ~A of type ~A" num (type-of num)))

(defmethod even? ((num <number>))
  (error "EVEN? requires an integer, got ~A of type ~A" num (type-of num)))

(defmethod even? (obj)
  (error "EVEN? requires an integer, got ~A" obj))


(defgeneric zero? (num)
  (:documentation "Returns T if NUM equals zero, NIL otherwise."))

(defmethod zero? ((num number))
  (cl:zerop num))

(defmethod zero? ((num <number>))
  (cl:zerop (fol-value num)))

(defmethod zero? (obj)
  (error "ZERO? requires a number, got ~A" obj))


(defgeneric positive? (num)
  (:documentation "Returns T if NUM is greater than zero, NIL otherwise."))

(defmethod positive? ((num real))
  (cl:plusp num))

(defmethod positive? ((num <real>))
  (cl:plusp (fol-value num)))

(defmethod positive? ((num number))
  (error "POSITIVE? requires a real number, got ~A of type ~A" num (type-of num)))

(defmethod positive? ((num <number>))
  (error "POSITIVE? requires a real number, got ~A of type ~A" num (type-of num)))

(defmethod positive? (obj)
  (error "POSITIVE? requires a real number, got ~A" obj))


(defgeneric negative? (num)
  (:documentation "Returns T if NUM is less than zero, NIL otherwise."))

(defmethod negative? ((num real))
  (cl:minusp num))

(defmethod negative? ((num <real>))
  (cl:minusp (fol-value num)))

(defmethod negative? ((num number))
  (error "NEGATIVE? requires a real number, got ~A of type ~A" num (type-of num)))

(defmethod negative? ((num <number>))
  (error "NEGATIVE? requires a real number, got ~A of type ~A" num (type-of num)))

(defmethod negative? (obj)
  (error "NEGATIVE? requires a real number, got ~A" obj))


(defgeneric integral? (num)
  (:documentation "Returns T if NUM has an integer value, NIL otherwise."))

(defmethod integral? ((num integer))
  t)

(defmethod integral? ((num <integer>))
  t)

(defmethod integral? ((num number))
  nil)

(defmethod integral? ((num <number>))
  nil)

(defmethod integral? (obj)
  (error "INTEGRAL? requires a number, got ~A" obj))


(defgeneric nat-int? (num)
  (:documentation "Returns T if NUM is a non-negative integer (>= 0), NIL otherwise."))

(defmethod nat-int? ((num integer))
  (cl:>= num 0))

(defmethod nat-int? ((num <integer>))
  (cl:>= (fol-value num) 0))

(defmethod nat-int? ((num number))
  nil)

(defmethod nat-int? ((num <number>))
  nil)

(defmethod nat-int? (obj)
  nil)


(defgeneric pos-int? (num)
  (:documentation "Returns T if NUM is a positive integer (> 0), NIL otherwise."))

(defmethod pos-int? ((num integer))
  (cl:> num 0))

(defmethod pos-int? ((num <integer>))
  (cl:> (fol-value num) 0))

(defmethod pos-int? ((num number))
  nil)

(defmethod pos-int? ((num <number>))
  nil)

(defmethod pos-int? (obj)
  nil)


(defgeneric NaN? (num)
  (:documentation "Returns T if NUM is a floating-point NaN (Not a Number), NIL otherwise."))

(defmethod NaN? ((num float))
  ;; NaN is the only value that is not equal to itself
  (/= num num))

(defmethod NaN? ((num <float>))
  (let ((val (fol-value num)))
    (/= val val)))

(defmethod NaN? ((num number))
  ;; Non-float numbers are never NaN
  nil)

(defmethod NaN? ((num <number>))
  ;; Non-float wrapped numbers are never NaN
  nil)

(defmethod NaN? (obj)
  (error "NaN? requires a number, got ~A" obj))


(defgeneric infinite? (num)
  (:documentation "Returns T if NUM is a floating-point infinity (positive or negative), NIL otherwise."))

(defmethod infinite? ((num float))
  ;; Infinity satisfies: non-zero and x = x/2 (only infinity has this property)
  (and (not (zerop num))
       (= num (/ num 2))))

(defmethod infinite? ((num <float>))
  (let ((val (fol-value num)))
    (and (not (zerop val))
         (= val (/ val 2)))))

(defmethod infinite? ((num number))
  ;; Non-float numbers are never infinite
  nil)

(defmethod infinite? ((num <number>))
  ;; Non-float wrapped numbers are never infinite
  nil)

(defmethod infinite? (obj)
  (error "INFINITE? requires a number, got ~A" obj))


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

(defmethod <complex> ((num <complex>))
  "Wrapped complex numbers are unwrapped and returned."
  (fol-value num))

(defmethod <complex> ((num <real>))
  "Convert a wrapped real number to complex with imaginary part 0.
   Uses 0.0 for imaginary part to ensure result is always a complex."
  (cl:complex (float (fol-value num)) 0.0))

(defmethod <complex> (obj)
  (error "<COMPLEX> requires a number, got ~A" obj))

(defgeneric <single-float> (num)
  (:documentation "Converts a real number to a single-float.
   If the number is already a single-float, returns it unchanged."))

(defmethod <single-float> ((num single-float))
  "Single-floats are returned unchanged."
  num)

(defmethod <single-float> ((num real))
  "Convert a real number to single-float."
  (coerce num 'single-float))

(defmethod <single-float> ((num <single-float>))
  "Wrapped single-floats are unwrapped and returned."
  (fol-value num))

(defmethod <single-float> ((num <real>))
  "Convert a wrapped real number to single-float."
  (coerce (fol-value num) 'single-float))

(defmethod <single-float> (obj)
  (error "<SINGLE-FLOAT> requires a real number, got ~A" obj))

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

(defmethod <double-float> ((num <double-float>))
  "Wrapped double-floats are unwrapped and returned."
  (fol-value num))

(defmethod <double-float> ((num <single-float>))
  "Convert a wrapped single-float to double-float."
  (coerce (fol-value num) 'double-float))

(defmethod <double-float> ((num <integer>))
  "Convert a wrapped integer to double-float with range checking."
  (let ((val (fol-value num)))
    (check-double-float-range val)
    (coerce val 'double-float)))

(defmethod <double-float> ((num <ratio>))
  "Convert a wrapped ratio to double-float with range checking."
  (let ((val (fol-value num)))
    (check-double-float-range val)
    (coerce val 'double-float)))

(defmethod <double-float> (obj)
  (error "<DOUBLE-FLOAT> requires a real number, got ~A" obj))


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
    (fol.eval:apply-function thunk nil)))


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

(defmethod int ((obj <char>))
  "Convert a wrapped character to its character code."
  (cl:char-code (fol-value obj)))

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

(defmethod int ((obj <integer>))
  "Wrapped integers are unwrapped and returned."
  (fol-value obj))

(defmethod int (obj)
  (error "INT requires a character, boolean, or integer, got ~A" obj))
