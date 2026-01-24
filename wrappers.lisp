(in-package fol.wrappers)

;;; ============================================================================
;;; FOL Value Protocol - Option 4 (Tagged Representation)
;;; ============================================================================
;;;
;;; This module provides a unified protocol for working with both raw CL
;;; primitives and wrapped FOL objects transparently. Operations can accept
;;; either form and the generic function dispatch handles the difference.
;;;
;;; Key functions:
;;;   fol-value  - Extract the raw CL value from any FOL-compatible object
;;;   fol-type-of - Get the FOL type name for any value (raw or wrapped)
;;;   wrap       - Convert a raw primitive to a wrapped FOL object (when needed)
;;;   unwrap     - Alias for fol-value (backward compatibility)

;;; ============================================================================
;;; Core Protocol: fol-value
;;; ============================================================================
;;; Extracts the underlying CL primitive from any value.
;;; For raw primitives, returns the value unchanged.
;;; For wrapped FOL objects, extracts the slot value.

(defgeneric fol-value (obj)
  (:documentation "Extract the raw Common Lisp value from OBJ.
   For raw primitives, returns OBJ unchanged.
   For FOL wrapper objects, returns the wrapped value."))

;;; --- Pass-through for raw CL primitives ---
(defmethod fol-value ((obj number)) obj)
(defmethod fol-value ((obj character)) obj)
(defmethod fol-value ((obj string)) obj)
(defmethod fol-value ((obj symbol)) obj)
(defmethod fol-value ((obj (eql t))) t)
(defmethod fol-value ((obj (eql nil))) nil)
(defmethod fol-value ((obj function)) obj)
(defmethod fol-value ((obj cons)) obj)
;; Pass-through for persistent objects that are not wrappers (e.g. collections)
(defmethod fol-value ((obj fol.persistent:<persistent-object>)) obj)

;;; --- Extraction for wrapped FOL objects ---
(defmethod fol-value ((obj <bool>)) (slot-value obj 'val))
(defmethod fol-value ((obj <char>)) (slot-value obj 'val))
(defmethod fol-value ((obj <string>)) (slot-value obj 'val))
(defmethod fol-value ((obj <symbol>)) (slot-value obj 'val))
(defmethod fol-value ((obj <number>)) (slot-value obj 'val))

;;; ============================================================================
;;; Core Protocol: fol-type-of
;;; ============================================================================
;;; Returns the FOL type name (as a symbol) for any value.
;;; This allows type reflection without requiring wrapping.

(defgeneric fol-type-of (obj)
  (:documentation "Return the FOL type name for OBJ as a symbol.
   Works on both raw CL primitives and wrapped FOL objects."))

;;; --- Raw CL primitives -> FOL types ---
(defmethod fol-type-of ((obj (eql t))) '<bool>)
(defmethod fol-type-of ((obj (eql nil))) '<bool>)
(defmethod fol-type-of ((obj integer)) 
  (if (typep obj 'fixnum) '<fixnum> '<bignum>))
(defmethod fol-type-of ((obj rational)) '<ratio>)
(defmethod fol-type-of ((obj float))
  (typecase obj
    (single-float '<single-float>)
    (double-float '<double-float>)
    ;(t '<float>) ; Not needed - the two classes in the first two conditions
                  ; exhausts the members of type '<float>.
    ))
(defmethod fol-type-of ((obj complex)) '<complex>)
(defmethod fol-type-of ((obj character)) '<char>)
(defmethod fol-type-of ((obj string)) '<string>)
(defmethod fol-type-of ((obj symbol))
  (if (keywordp obj) '<keyword> '<symbol>))
(defmethod fol-type-of ((obj cons)) 'fol.collection::<list>)

;;; --- Wrapped FOL objects -> FOL types (from class name) ---
(defmethod fol-type-of ((obj <bool>)) '<bool>)
(defmethod fol-type-of ((obj <char>)) '<char>)
(defmethod fol-type-of ((obj <string>)) '<string>)
(defmethod fol-type-of ((obj <keyword>)) '<keyword>)
(defmethod fol-type-of ((obj <symbol>)) '<symbol>)
(defmethod fol-type-of ((obj <fixnum>)) '<fixnum>)
(defmethod fol-type-of ((obj <bignum>)) '<bignum>)
(defmethod fol-type-of ((obj <ratio>)) '<ratio>)
(defmethod fol-type-of ((obj <single-float>)) '<single-float>)
(defmethod fol-type-of ((obj <double-float>)) '<double-float>)
(defmethod fol-type-of ((obj <complex>)) '<complex>)
(defmethod fol-type-of ((obj <float>)) '<float>)
(defmethod fol-type-of ((obj <rational>)) '<rational>)
(defmethod fol-type-of ((obj <real>)) '<real>)
(defmethod fol-type-of ((obj <integer>)) '<integer>)
(defmethod fol-type-of ((obj <number>)) '<number>)

;;; NOTE: fol-type-of methods for FOL collection types (<vector>, <list>, etc.)
;;; are defined in collection.lisp to avoid circular dependency.

;;; --- Default for standard-object: return class name ---
(defmethod fol-type-of ((obj standard-object))
  "Default: return the class name for any standard-object."
  (class-name (class-of obj)))

;;; ============================================================================
;;; Wrapping Functions (for when you need a FOL object)
;;; ============================================================================
;;; Use these only when you need to attach metadata, persist, or need
;;; a first-class FOL object. For most operations, raw primitives work fine.

(defmethod make-load-form ((obj <bool>) &optional environment)
  (declare (ignore environment))
  `(make-instance '<bool> :val ,(slot-value obj 'val)))

(defun wrap-bool (obj)
  "Wraps a native Lisp boolean into a FOL <bool> instance."
  (make-instance '<bool> :val (if obj t nil)))

(defun wrap-char (obj)
  "Wraps a native Lisp character into a FOL <char> instance."
  (if (characterp obj)
      (make-instance '<char> :val obj)
      (error "Expected a native character, got ~A" obj)))

(defun wrap-string (obj)
  "Wraps a native Lisp string into a FOL <string> instance."
  (if (stringp obj)
      (make-instance '<string> :val obj)
      (error "Expected a native string, got ~A" obj)))

(defun wrap-symbol (obj &optional module-name (value nil value-supplied-p))
  "Wraps a native Lisp symbol into a FOL <symbol> or <keyword> instance.
   Keywords are wrapped as <keyword>, other symbols as <symbol>.
   Optionally accepts a module-name (string) and value to associate with the symbol."
  (if (symbolp obj)
      (let ((class-name (if (keywordp obj) '<keyword> '<symbol>)))
        (if value-supplied-p
            (make-instance class-name :val obj :module-name module-name :value value)
            (make-instance class-name :val obj :module-name module-name)))
      (error "Expected a native symbol, got ~A" obj)))

(defun wrap-number (obj)
  "Wraps a native Lisp number into the appropriate FOL number class."
  (cond
    ((typep obj 'fixnum) (make-instance '<fixnum> :val obj))
    ((typep obj 'bignum) (make-instance '<bignum> :val obj))
    ((typep obj 'single-float) (make-instance '<single-float> :val obj))
    ((typep obj 'double-float) (make-instance '<double-float> :val obj))
    ((typep obj 'ratio) (make-instance '<ratio> :val obj))
    ((typep obj 'complex) (make-instance '<complex> :val obj))
    (t (error "Invalid native number type: ~A" obj))))

(defun wrap (obj)
  "Wrap a raw CL primitive into a FOL object if not already wrapped.
   Use this when you need a FOL object specifically (for persistence, metadata, etc.)
   For most operations, raw primitives work fine without wrapping."
  (cond
    ;; Already wrapped - return as-is
    ((typep obj '<bool>) obj)
    ((typep obj '<char>) obj)
    ((typep obj '<string>) obj)
    ((typep obj '<symbol>) obj)
    ((typep obj '<number>) obj)
    ;; Raw primitives - wrap them
    ((typep obj 'boolean) (wrap-bool obj))
    ((characterp obj) (wrap-char obj))
    ((stringp obj) (wrap-string obj))
    ((symbolp obj) (wrap-symbol obj))
    ((numberp obj) (wrap-number obj))
    (t (error "Object ~A cannot be wrapped." obj))))

;;; ============================================================================
;;; Unwrapping Functions (backward compatibility + convenience)
;;; ============================================================================

(defun unwrap-bool (obj)
  "Extracts the raw boolean value from a FOL <bool> instance or raw boolean."
  (fol-value obj))

(defun unwrap-char (obj)
  "Extracts the raw character value from a FOL <char> instance or raw char."
  (fol-value obj))

(defun unwrap-string (obj)
  "Extracts the raw string value from a FOL <string> instance or raw string."
  (fol-value obj))

(defun unwrap-symbol (obj)
  "Extracts the raw symbol value from a FOL <symbol> instance or raw symbol."
  (fol-value obj))

(defun unwrap-number (obj)
  "Extracts the raw numeric value from a FOL <number> instance or raw number."
  (fol-value obj))

(defun unwrap (obj)
  "Extract the raw CL value from OBJ. Alias for fol-value.
   Works on both raw primitives (returns unchanged) and wrapped FOL objects."
  (fol-value obj))

;;; ============================================================================
;;; Type Checking Utilities
;;; ============================================================================

(defgeneric fol-numberp (obj)
  (:documentation "Returns T if OBJ is a number (raw or wrapped)."))
(defmethod fol-numberp ((obj number)) t)
(defmethod fol-numberp ((obj <number>)) t)
(defmethod fol-numberp (obj) nil)

(defgeneric fol-integerp (obj)
  (:documentation "Returns T if OBJ is an integer (raw or wrapped)."))
(defmethod fol-integerp ((obj integer)) t)
(defmethod fol-integerp ((obj <integer>)) t)
(defmethod fol-integerp (obj) nil)

(defgeneric fol-realp (obj)
  (:documentation "Returns T if OBJ is a real number (raw or wrapped)."))
(defmethod fol-realp ((obj real)) t)
(defmethod fol-realp ((obj <real>)) t)
(defmethod fol-realp (obj) nil)

(defgeneric fol-stringp (obj)
  (:documentation "Returns T if OBJ is a string (raw or wrapped)."))
(defmethod fol-stringp ((obj string)) t)
(defmethod fol-stringp ((obj <string>)) t)
(defmethod fol-stringp (obj) nil)

(defgeneric fol-characterp (obj)
  (:documentation "Returns T if OBJ is a character (raw or wrapped)."))
(defmethod fol-characterp ((obj character)) t)
(defmethod fol-characterp ((obj <char>)) t)
(defmethod fol-characterp (obj) nil)

(defgeneric fol-symbolp (obj)
  (:documentation "Returns T if OBJ is a symbol (raw or wrapped)."))
(defmethod fol-symbolp ((obj symbol)) t)
(defmethod fol-symbolp ((obj <symbol>)) t)
(defmethod fol-symbolp (obj) nil)

(defgeneric fol-booleanp (obj)
  (:documentation "Returns T if OBJ is a boolean (raw or wrapped)."))
(defmethod fol-booleanp ((obj (eql t))) t)
(defmethod fol-booleanp ((obj (eql nil))) t)
(defmethod fol-booleanp ((obj <bool>)) t)
(defmethod fol-booleanp (obj) nil)
