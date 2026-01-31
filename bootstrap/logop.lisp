(in-package fol.logop)

;;; ============================================================================
;;; Logical Operations - Option 4 (Tagged Representation)
;;; ============================================================================
;;;
;;; All operations work transparently on both raw CL values and wrapped
;;; FOL objects. Results are returned as raw CL values.
;;;
;;; - Booleans: logical operations (AND, OR, NOT, XOR)
;;; - Integers: bitwise operations (LOGAND, LOGIOR, LOGNOT, LOGXOR)
;;;
;;; IMPORTANT: AND and OR are macros that short-circuit evaluation.
;;; This means they behave like CL:AND and CL:OR for control flow.

;;; ============================================================================
;;; Primitive Dyadic Logical Operations (for non-short-circuit contexts)
;;; ============================================================================

(defgeneric %and (a b)
  (:documentation "Binary AND operation. Logical for booleans, bitwise for integers."))

(defgeneric %or (a b)
  (:documentation "Binary OR operation. Logical for booleans, bitwise for integers."))

(defgeneric %xor (a b)
  (:documentation "Binary XOR operation. Logical for booleans, bitwise for integers."))

;;; --- Raw Boolean Implementations ---

(defmethod %and ((a (eql t)) (b (eql t))) t)
(defmethod %and ((a (eql t)) (b (eql nil))) nil)
(defmethod %and ((a (eql nil)) (b (eql t))) nil)
(defmethod %and ((a (eql nil)) (b (eql nil))) nil)

(defmethod %or ((a (eql t)) (b (eql t))) t)
(defmethod %or ((a (eql t)) (b (eql nil))) t)
(defmethod %or ((a (eql nil)) (b (eql t))) t)
(defmethod %or ((a (eql nil)) (b (eql nil))) nil)

(defmethod %xor ((a (eql t)) (b (eql t))) nil)
(defmethod %xor ((a (eql t)) (b (eql nil))) t)
(defmethod %xor ((a (eql nil)) (b (eql t))) t)
(defmethod %xor ((a (eql nil)) (b (eql nil))) nil)

;;; --- Raw Integer Implementations (Bitwise) ---

(defmethod %and ((a integer) (b integer))
  (cl:logand a b))

(defmethod %or ((a integer) (b integer))
  (cl:logior a b))

(defmethod %xor ((a integer) (b integer))
  (cl:logxor a b))

;;; --- Wrapped Boolean Implementations ---

(defmethod %and ((a <bool>) (b <bool>))
  (cl:and (fol-value a) (fol-value b)))

(defmethod %or ((a <bool>) (b <bool>))
  (cl:or (fol-value a) (fol-value b)))

(defmethod %xor ((a <bool>) (b <bool>))
  (cl:not (cl:eq (fol-value a) (fol-value b))))

;;; --- Wrapped Integer Implementations ---

(defmethod %and ((a <integer>) (b <integer>))
  (cl:logand (fol-value a) (fol-value b)))

(defmethod %or ((a <integer>) (b <integer>))
  (cl:logior (fol-value a) (fol-value b)))

(defmethod %xor ((a <integer>) (b <integer>))
  (cl:logxor (fol-value a) (fol-value b)))

;;; --- Mixed: wrapped + raw for booleans ---

(defmethod %and ((a <bool>) (b (eql t))) (fol-value a))
(defmethod %and ((a <bool>) (b (eql nil))) nil)
(defmethod %and ((a (eql t)) (b <bool>)) (fol-value b))
(defmethod %and ((a (eql nil)) (b <bool>)) nil)

(defmethod %or ((a <bool>) (b (eql t))) t)
(defmethod %or ((a <bool>) (b (eql nil))) (fol-value a))
(defmethod %or ((a (eql t)) (b <bool>)) t)
(defmethod %or ((a (eql nil)) (b <bool>)) (fol-value b))

(defmethod %xor ((a <bool>) (b (eql t))) (cl:not (fol-value a)))
(defmethod %xor ((a <bool>) (b (eql nil))) (fol-value a))
(defmethod %xor ((a (eql t)) (b <bool>)) (cl:not (fol-value b)))
(defmethod %xor ((a (eql nil)) (b <bool>)) (fol-value b))

;;; --- Mixed: wrapped + raw for integers ---

(defmethod %and ((a <integer>) (b integer))
  (cl:logand (fol-value a) b))

(defmethod %and ((a integer) (b <integer>))
  (cl:logand a (fol-value b)))

(defmethod %or ((a <integer>) (b integer))
  (cl:logior (fol-value a) b))

(defmethod %or ((a integer) (b <integer>))
  (cl:logior a (fol-value b)))

(defmethod %xor ((a <integer>) (b integer))
  (cl:logxor (fol-value a) b))

(defmethod %xor ((a integer) (b <integer>))
  (cl:logxor a (fol-value b)))

;;; --- Fallback with type dispatch ---

(defmethod %and (a b)
  (let ((ua (fol-value a))
        (ub (fol-value b)))
    (cond
      ((cl:and (typep ua 'boolean) (typep ub 'boolean))
       (cl:and ua ub))
      ((cl:and (integerp ua) (integerp ub))
       (cl:logand ua ub))
      (t (error "Cannot AND ~A and ~A" a b)))))

(defmethod %or (a b)
  (let ((ua (fol-value a))
        (ub (fol-value b)))
    (cond
      ((cl:and (typep ua 'boolean) (typep ub 'boolean))
       (cl:or ua ub))
      ((cl:and (integerp ua) (integerp ub))
       (cl:logior ua ub))
      (t (error "Cannot OR ~A and ~A" a b)))))

(defmethod %xor (a b)
  (let ((ua (fol-value a))
        (ub (fol-value b)))
    (cond
      ((cl:and (typep ua 'boolean) (typep ub 'boolean))
       (cl:not (cl:eq ua ub)))
      ((cl:and (integerp ua) (integerp ub))
       (cl:logxor ua ub))
      (t (error "Cannot XOR ~A and ~A" a b)))))


;;; ============================================================================
;;; Unary NOT Operation
;;; ============================================================================

(defgeneric not (obj)
  (:documentation "Returns the logical negation of a boolean or bitwise NOT of an integer."))

;;; --- Raw values ---

(defmethod not ((obj (eql t))) nil)
(defmethod not ((obj (eql nil))) t)
(defmethod not ((obj integer)) (cl:lognot obj))

;;; --- Wrapped values ---

(defmethod not ((obj <bool>))
  (cl:not (fol-value obj)))

(defmethod not ((obj <integer>))
  (cl:lognot (fol-value obj)))

;;; --- Fallback ---

(defmethod not (obj)
  (let ((u (fol-value obj)))
    (cond
      ((typep u 'boolean) (cl:not u))
      ((integerp u) (cl:lognot u))
      (t (error "NOT requires a boolean or integer, got ~A" obj)))))


;;; ============================================================================
;;; Public Variadic Logical Operators
;;; ============================================================================
;;;
;;; NOTE: These are generic functions, not macros. They do NOT short-circuit.
;;; For booleans: logical AND/OR
;;; For integers: bitwise AND/OR (logand/logior)
;;;
;;; If you need short-circuit evaluation in Lisp code, use CL:AND and CL:OR.

(defgeneric and (&rest args)
  (:documentation "Variadic AND. Logical AND for booleans, bitwise AND for integers."))

(defmethod and (&rest args)
  (cond
    ;; No arguments: identity is true for logical
    ((null args) t)
    ;; One argument: return the value
    ((null (cdr args)) (fol-value (car args)))
    ;; Multiple arguments: determine type and fold
    (t
     (let ((first-unwrapped (fol-value (car args))))
       (cond
         ;; All booleans: logical AND
         ((typep first-unwrapped 'boolean)
          (every #'(lambda (x) (fol-value x)) args))
         ;; All integers: bitwise AND
         ((integerp first-unwrapped)
          (reduce #'cl:logand args :key #'fol-value))
         (t (error "AND requires all arguments to be the same type")))))))


(defgeneric or (&rest args)
  (:documentation "Variadic OR. Logical OR for booleans, bitwise OR for integers."))

(defmethod or (&rest args)
  (cond
    ;; No arguments: identity is false for logical
    ((null args) nil)
    ;; One argument: return the value
    ((null (cdr args)) (fol-value (car args)))
    ;; Multiple arguments: determine type and fold
    (t
     (let ((first-unwrapped (fol-value (car args))))
       (cond
         ;; All booleans: logical OR
         ((typep first-unwrapped 'boolean)
          (if (some #'(lambda (x) (fol-value x)) args) t nil))
         ;; All integers: bitwise OR
         ((integerp first-unwrapped)
          (reduce #'cl:logior args :key #'fol-value))
         (t (error "OR requires all arguments to be the same type")))))))


;;; ============================================================================
;;; Variadic XOR (no short-circuit semantics)
;;; ============================================================================

(defgeneric xor (&rest args)
  (:documentation "Variadic XOR. Logical XOR for booleans, bitwise XOR for integers."))

(defmethod xor (&rest args)
  (cond
    ;; No arguments: identity is false for logical, 0 for bitwise
    ((null args) nil)
    ;; One argument: return the value
    ((null (cdr args)) (fol-value (car args)))
    ;; Multiple arguments: determine type and fold
    (t
     (let ((first-unwrapped (fol-value (car args))))
       (cond
         ;; All booleans: logical XOR (odd number of trues)
         ((typep first-unwrapped 'boolean)
          (reduce (lambda (a b) (cl:not (eq a b)))
                  args
                  :key #'fol-value
                  :initial-value nil))
         ;; All integers: bitwise XOR
         ((integerp first-unwrapped)
          (reduce #'cl:logxor args :key #'fol-value))
         (t (error "XOR requires all arguments to be the same type")))))))


;;; ============================================================================
;;; Derived Logical Operators
;;; ============================================================================

(defgeneric implies (a b)
  (:documentation "Logical implication (If A then B). For booleans: (OR (NOT A) B). For integers: bitwise equivalent."))

;;; --- Raw values ---

(defmethod implies ((a (eql t)) (b (eql t))) t)
(defmethod implies ((a (eql t)) (b (eql nil))) nil)
(defmethod implies ((a (eql nil)) (b (eql t))) t)
(defmethod implies ((a (eql nil)) (b (eql nil))) t)

(defmethod implies ((a integer) (b integer))
  (cl:logior (cl:lognot a) b))

;;; --- Wrapped values ---

(defmethod implies ((a <bool>) (b <bool>))
  (cl:or (cl:not (fol-value a)) (fol-value b)))

(defmethod implies ((a <integer>) (b <integer>))
  (cl:logior (cl:lognot (fol-value a)) (fol-value b)))

;;; --- Mixed ---

(defmethod implies ((a <bool>) (b (eql t))) t)
(defmethod implies ((a <bool>) (b (eql nil))) (cl:not (fol-value a)))
(defmethod implies ((a (eql t)) (b <bool>)) (fol-value b))
(defmethod implies ((a (eql nil)) (b <bool>)) t)

(defmethod implies ((a <integer>) (b integer))
  (cl:logior (cl:lognot (fol-value a)) b))

(defmethod implies ((a integer) (b <integer>))
  (cl:logior (cl:lognot a) (fol-value b)))

;;; --- Fallback ---

(defmethod implies (a b)
  (let ((ua (fol-value a))
        (ub (fol-value b)))
    (cond
      ((cl:and (typep ua 'boolean) (typep ub 'boolean))
       (cl:or (cl:not ua) ub))
      ((cl:and (integerp ua) (integerp ub))
       (cl:logior (cl:lognot ua) ub))
      (t (error "IMPLIES requires matching types (both boolean or both integer), got ~A and ~A" a b)))))


;;; ============================================================================
;;; Additional Bitwise/Logical Operations
;;; ============================================================================

(defgeneric nand (&rest args)
  (:documentation "Variadic NAND. Returns NOT (AND args). Logical NAND for booleans, bitwise NAND for integers."))

(defmethod nand (&rest args)
  (cond
    ;; No arguments: NOT(AND()) = NOT(true) = false
    ((null args) nil)
    ;; One argument: NOT(arg)
    ((null (cdr args)) (not (car args)))
    ;; Multiple arguments: NOT(AND(args...))
    (t
     (let ((first-unwrapped (fol-value (car args))))
       (cond
         ;; All booleans: logical NAND
         ((typep first-unwrapped 'boolean)
          (cl:not (every #'(lambda (x) (fol-value x)) args)))
         ;; All integers: bitwise NAND
         ((integerp first-unwrapped)
          (cl:lognot (reduce #'cl:logand args :key #'fol-value)))
         (t (error "NAND requires all arguments to be the same type")))))))


(defgeneric nor (&rest args)
  (:documentation "Variadic NOR. Returns NOT (OR args). Logical NOR for booleans, bitwise NOR for integers."))

(defmethod nor (&rest args)
  (cond
    ;; No arguments: NOT(OR()) = NOT(false) = true
    ((null args) t)
    ;; One argument: NOT(arg)
    ((null (cdr args)) (not (car args)))
    ;; Multiple arguments: NOT(OR(args...))
    (t
     (let ((first-unwrapped (fol-value (car args))))
       (cond
         ;; All booleans: logical NOR
         ((typep first-unwrapped 'boolean)
          (cl:not (some #'(lambda (x) (fol-value x)) args)))
         ;; All integers: bitwise NOR
         ((integerp first-unwrapped)
          (cl:lognot (reduce #'cl:logior args :key #'fol-value)))
         (t (error "NOR requires all arguments to be the same type")))))))
