(in-package fol.number)



  

;; Number type predicates
(defgeneric <number>? (obj) (:documentation "Returns T if OBJ is a FOL <number>."))
(defmethod <number>? (obj) (return-f))
(defmethod <number>? ((obj <number>)) (return-t))

(defgeneric <complex>? (obj) (:documentation "Returns T if OBJ is a FOL <complex>."))
(defmethod <complex>? (obj) (return-f))
(defmethod <complex>? ((obj <complex>)) (return-t))

(defgeneric <real>? (obj) (:documentation "Returns T if OBJ is a FOL <real>."))
(defmethod <real>? (obj) (return-f))
(defmethod <real>? ((obj <real>)) (return-t))

(defgeneric <float>? (obj) (:documentation "Returns T if OBJ is a FOL <float>."))
(defmethod <float>? (obj) (return-f))
(defmethod <float>? ((obj <float>)) (return-t))

(defgeneric <single-float>? (obj) (:documentation "Returns T if OBJ is a FOL <single-float>."))
(defmethod <single-float>? (obj) (return-f))
(defmethod <single-float>? ((obj <single-float>)) (return-t))

(defgeneric <double-float>? (obj) (:documentation "Returns T if OBJ is a FOL <double-float>."))
(defmethod <double-float>? (obj) (return-f))
(defmethod <double-float>? ((obj <double-float>)) (return-t))

(defgeneric <rational>? (obj) (:documentation "Returns T if OBJ is a FOL <rational>."))
(defmethod <rational>? (obj) (return-f))
(defmethod <rational>? ((obj <rational>)) (return-t))

(defgeneric <integer>? (obj) (:documentation "Returns T if OBJ is a FOL <integer>."))
(defmethod <integer>? (obj) (return-f))
(defmethod <integer>? ((obj <integer>)) (return-t))

(defgeneric <fixnum>? (obj) (:documentation "Returns T if OBJ is a FOL <fixnum>."))
(defmethod <fixnum>? (obj) (return-f))
(defmethod <fixnum>? ((obj <fixnum>)) (return-t))

(defgeneric <bignum>? (obj) (:documentation "Returns T if OBJ is a FOL <bignum>."))
(defmethod <bignum>? (obj) (return-f))
(defmethod <bignum>? ((obj <bignum>)) (return-t))

(defgeneric <ratio>? (obj) (:documentation "Returns T if OBJ is a FOL <ratio>."))
(defmethod <ratio>? (obj) (return-f))
(defmethod <ratio>? ((obj <ratio>)) (return-t))





;; Base method for any <number>
;; This acts as a fallback using the built-in Lisp printer for the raw value
(defmethod print-object ((obj <number>) stream)
  (format stream "~A" (unwrap obj)))


;; Numeric type functions
(defgeneric odd? (num)
  (:documentation "Returns #t if NUM is an odd integer, #f otherwise."))

(defmethod odd? ((num <integer>))
  "Returns #t if NUM is odd, #f if even."
  (wrap (cl:oddp (unwrap-number num))))

(defmethod odd? ((num <number>))
  "Error for non-integer numbers."
  (error "ODD? requires an integer, got ~A of type ~A" 
         num (type-of num)))

(defmethod odd? (obj)
  "Error for non-numeric values."
  (error "ODD? requires a FOL integer, got ~A" obj))



(defgeneric even? (num)
  (:documentation "Returns #t if NUM is an even integer, #f otherwise."))

(defmethod even? ((num <integer>))
  "Returns #t if NUM is even, #f if odd."
  (wrap (cl:evenp (unwrap-number num))))

(defmethod even? ((num <number>))
  "Error for non-integer numbers."
  (error "EVEN? requires an integer, got ~A of type ~A" 
         num (type-of num)))

(defmethod even? (obj)
  "Error for non-numeric values."
  (error "EVEN? requires a FOL integer, got ~A" obj))



(defgeneric zero? (num)
  (:documentation "Returns #t if NUM equals zero, #f otherwise."))

(defmethod zero? ((num <number>))
  "Returns #t if NUM is zero, #f otherwise."
  (wrap (cl:zerop (unwrap-number num))))

(defmethod zero? (obj)
  "Error for non-numeric values."
  (error "ZERO? requires a FOL number, got ~A" obj))



(defgeneric positive? (num)
  (:documentation "Returns #t if NUM is greater than zero, #f otherwise."))

(defmethod positive? ((num <real>))
  "Returns #t if NUM is positive, #f otherwise."
  (wrap (cl:plusp (unwrap-number num))))

(defmethod positive? ((num <number>))
  "Error for non-real numbers (e.g., complex)."
  (error "POSITIVE? requires a real number, got ~A of type ~A" 
         num (type-of num)))

(defmethod positive? (obj)
  "Error for non-numeric values."
  (error "POSITIVE? requires a FOL real number, got ~A" obj))



(defgeneric negative? (num)
  (:documentation "Returns #t if NUM is less than zero, #f otherwise."))

(defmethod negative? ((num <real>))
  "Returns #t if NUM is negative, #f otherwise."
  (wrap (cl:minusp (unwrap-number num))))

(defmethod negative? ((num <number>))
  "Error for non-real numbers (e.g., complex)."
  (error "NEGATIVE? requires a real number, got ~A of type ~A" 
         num (type-of num)))

(defmethod negative? (obj)
  "Error for non-numeric values."
  (error "NEGATIVE? requires a FOL real number, got ~A" obj))

  

(defgeneric integral? (num)
  (:documentation "Returns #t if NUM has an integer value, #f otherwise."))

(defmethod integral? ((num <integer>))
  "Returns #t if NUM is mathematically an integer."
  (return-t))

(defmethod integral? ((num <number>))
  (return-f))

(defmethod integral? (obj)
  "Error for non-numeric values."
  (error "INTEGRAL? requires a FOL real number, got ~A" obj))