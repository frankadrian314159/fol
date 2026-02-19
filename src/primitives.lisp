;;; FOL Compiler - Primitive Type Classes
;;;
;;; Mirrors the class hierarchy from bootstrap/classes.lisp but with no slots.
;;; In compiled FOL, primitive values use their native CL representations
;;; directly (numbers are CL numbers, strings are CL strings, etc.).
;;; These classes exist as type descriptors for the compiler's type system,
;;; enabling defmethod dispatch and type predicates in compiled code.
;;;
;;; Hierarchy:
;;;   <standard-object>
;;;   ├── <bool>
;;;   ├── <char>
;;;   ├── <string>
;;;   │   ├── <re-pattern>
;;;   │   └── <symbol>
;;;   │       └── <keyword>
;;;   ├── <number>
;;;   │   ├── <complex>
;;;   │   └── <real>
;;;   │       ├── <float>
;;;   │       │   ├── <single-float>
;;;   │       │   └── <double-float>
;;;   │       └── <rational>
;;;   │           ├── <ratio>
;;;   │           └── <integer>
;;;   │               ├── <fixnum>
;;;   │               └── <bignum>
;;;   └── <uuid>

(in-package :fol.compiler.primitives)

;;; ---------------------------------------------------------------------------
;;; Boolean
;;; ---------------------------------------------------------------------------

(defclass <bool> (standard-object)
    ()
  (:documentation "Boolean type. Represented as CL generalized booleans."))

;;; ---------------------------------------------------------------------------
;;; Character
;;; ---------------------------------------------------------------------------

(defclass <char> (standard-object)
    ()
  (:documentation "Character type. Represented as CL characters."))

;;; ---------------------------------------------------------------------------
;;; String and derivatives
;;; ---------------------------------------------------------------------------

(defclass <string> (standard-object)
    ()
  (:documentation "String type. Represented as CL strings."))

(defclass <re-pattern> (<string>)
    ()
  (:documentation "Regular expression pattern. A string subtype."))

(defclass <symbol> (<string>)
    ()
  (:documentation "Symbol type. Represented as CL symbols."))

(defclass <keyword> (<symbol>)
    ()
  (:documentation "Keyword type. A symbol subtype for CL keywords."))

;;; ---------------------------------------------------------------------------
;;; Number hierarchy
;;; -------------------------------------------------------------------

(defclass <number> (standard-object)
    ()
  (:documentation "Base number type. Represented as CL numbers."))

(defclass <complex> (<number>)
    ()
  (:documentation "Complex number type."))

(defclass <real> (<number>)
    ()
  (:documentation "Real number type."))

(defclass <float> (<real>)
    ()
  (:documentation "Floating-point number type."))

(defclass <single-float> (<float>)
    ()
  (:documentation "Single-precision floating-point type."))

(defclass <double-float> (<float>)
    ()
  (:documentation "Double-precision floating-point type."))

(defclass <rational> (<real>)
    ()
  (:documentation "Rational number type."))

(defclass <ratio> (<rational>)
    ()
  (:documentation "Ratio type (exact fractions)."))

(defclass <integer> (<rational>)
    ()
  (:documentation "Integer type."))

(defclass <fixnum> (<integer>)
    ()
  (:documentation "Fixnum type (machine-word integers)."))

(defclass <bignum> (<integer>)
    ()
  (:documentation "Bignum type (arbitrary-precision integers)."))

;;; ---------------------------------------------------------------------------
;;; UUID
;;; ---------------------------------------------------------------------------

(defclass <uuid> (standard-object)
    ()
  (:documentation "UUID type."))

;;; ---------------------------------------------------------------------------
;;; Type-of mapping: CL type specifier -> FOL class
;;; ---------------------------------------------------------------------------

(defun fol-type-class (value)
  "Return the FOL primitive class corresponding to a CL value.
   Used by compiled code for type dispatch and predicates."
  (typecase value
    ((eql t) (find-class '<bool>))
    ((eql nil) (find-class '<bool>))
    (keyword (find-class '<keyword>))
    (symbol (find-class '<symbol>))
    (character (find-class '<char>))
    (string (find-class '<string>))
    ((complex *) (find-class '<complex>))
    (single-float (find-class '<single-float>))
    (double-float (find-class '<double-float>))
    (float (find-class '<float>))
    (ratio (find-class '<ratio>))
    (fixnum (find-class '<fixnum>))
    (bignum (find-class '<bignum>))
    ((integer *) (find-class '<integer>))
    ((rational *) (find-class '<rational>))
    ((real *) (find-class '<real>))
    (number (find-class '<number>))
    (<re-pattern> (find-class '<re-pattern>))
    (<uuid> (find-class '<uuid>))
    (t nil)))

;;; ---------------------------------------------------------------------------
;;; Type predicates for compiled code
;;; ---------------------------------------------------------------------------

(defun <bool>? (obj) (typep obj 'boolean))
(defun <char>? (obj) (characterp obj))
(defun <string>? (obj) (stringp obj))
(defun <keyword>? (obj) (keywordp obj))
(defun <symbol>? (obj) (symbolp obj))
(defun <complex>? (obj) (complexp obj))
(defun <float>? (obj) (floatp obj))
(defun <single-float>? (obj) (typep obj 'single-float))
(defun <double-float>? (obj) (typep obj 'double-float))
(defun <ratio>? (obj) (typep obj 'ratio))
(defun <fixnum>? (obj) (typep obj 'fixnum))
(defun <bignum>? (obj) (typep obj 'bignum))
(defun <integer>? (obj) (integerp obj))
(defun <rational>? (obj) (rationalp obj))
(defun <real>? (obj) (realp obj))
(defun <number>? (obj) (numberp obj))
(defun <re-pattern>? (obj) (typep obj (find-class '<re-pattern>)))
(defun <uuid>? (obj) (typep obj (find-class '<uuid>)))

;;; ---------------------------------------------------------------------------
;;; Utility predicates
;;; ---------------------------------------------------------------------------
(defun truthy? (obj) (not (null obj)))
(defun falsy? (obj) (null obj))

;;; ---------------------------------------------------------------------------
;;; Constructor generic
;;; ---------------------------------------------------------------------------

(defgeneric make (class &rest args)
  (:documentation "Create a new instance of CLASS from ARGS.
                   For primitive types, returns the value unchanged.
                   Collection subclasses specialize to build their backing store."))

;;; --- Primitive make methods (identity — CL values are their own representation) ---

(defmethod make ((class (eql '<bool>)) &rest args)
  (first args))

(defmethod make ((class (eql '<char>)) &rest args)
  (first args))

(defmethod make ((class (eql '<string>)) &rest args)
  (first args))

(defmethod make ((class (eql '<re-pattern>)) &rest args)
  (first args))

(defmethod make ((class (eql '<symbol>)) &rest args)
  (first args))

(defmethod make ((class (eql '<keyword>)) &rest args)
  (first args))

(defmethod make ((class (eql '<number>)) &rest args)
  (first args))

(defmethod make ((class (eql '<complex>)) &rest args)
  (first args))

(defmethod make ((class (eql '<real>)) &rest args)
  (first args))

(defmethod make ((class (eql '<float>)) &rest args)
  (first args))

(defmethod make ((class (eql '<single-float>)) &rest args)
  (first args))

(defmethod make ((class (eql '<double-float>)) &rest args)
  (first args))

(defmethod make ((class (eql '<rational>)) &rest args)
  (first args))

(defmethod make ((class (eql '<ratio>)) &rest args)
  (first args))

(defmethod make ((class (eql '<integer>)) &rest args)
  (first args))

(defmethod make ((class (eql '<fixnum>)) &rest args)
  (first args))

(defmethod make ((class (eql '<bignum>)) &rest args)
  (first args))

(defmethod make ((class (eql '<uuid>)) &rest args)
  (declare (ignore args))
  (uuid:make-v4-uuid))

;;; --- Fallback for user-defined classes ---
;;; When defclass creates a class, it can be found via find-class.
;;; This method handles cases where make is called with a symbol that
;;; refers to a user-defined class (e.g., from defclass in FOL).

(defmethod make (class &rest args)
  "Fallback: if CLASS is a symbol, look it up with find-class and instantiate."
  (if (symbolp class)
      (let ((found-class (find-class class nil)))
        (if found-class
            (apply #'make-instance found-class args)
            (error "Class ~S not found" class)))
      (error "Don't know how to make instance of ~S" class)))

;;; ---------------------------------------------------------------------------
;;; print-object methods
;;; ---------------------------------------------------------------------------

(defmethod print-object ((obj <re-pattern>) stream)
  (print-unreadable-object (obj stream :type t :identity t)))

(defmethod print-object ((obj <uuid>) stream)
  (print-unreadable-object (obj stream :type t :identity t)))