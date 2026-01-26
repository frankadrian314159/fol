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

(defgeneric <double-float> (num)
  (:documentation "Converts a real number to a double-float.
   If the number is already a double-float, returns it unchanged."))

(defmethod <double-float> ((num double-float))
  "Double-floats are returned unchanged."
  num)

(defmethod <double-float> ((num real))
  "Convert a real number to double-float."
  (coerce num 'double-float))

(defmethod <double-float> ((num <double-float>))
  "Wrapped double-floats are unwrapped and returned."
  (fol-value num))

(defmethod <double-float> ((num <real>))
  "Convert a wrapped real number to double-float."
  (coerce (fol-value num) 'double-float))

(defmethod <double-float> (obj)
  (error "<DOUBLE-FLOAT> requires a real number, got ~A" obj))
