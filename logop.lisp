(in-package fol.logop)

;;; ============================================================================
;;; Primitive Dyadic Logical Operations
;;; ============================================================================

(defgeneric %and (a b)
  (:documentation "Binary AND operation."))

(defgeneric %or (a b)
  (:documentation "Binary OR operation."))

(defgeneric %xor (a b)
  (:documentation "Binary XOR operation."))

;;; --- Boolean Implementations ---

(defmethod %and ((a <bool>) (b <bool>))
  "Logical AND for booleans."
  (cl:and (unwrap-bool a) (unwrap-bool b)))

(defmethod %or ((a <bool>) (b <bool>))
  "Logical OR for booleans."
  (cl:or (unwrap-bool a) (unwrap-bool b)))

(defmethod %xor ((a <bool>) (b <bool>))
  "Logical XOR for booleans."
  (cl:not (cl:eq (unwrap-bool a) (unwrap-bool b))))

;;; --- Integer Implementations (Bitwise) ---

(defmethod %and ((a <integer>) (b <integer>))
  "Bitwise AND for integers."
  (cl:logand (unwrap-number a) (unwrap-number b)))

(defmethod %or ((a <integer>) (b <integer>))
  "Bitwise OR for integers."
  (cl:logior (unwrap-number a) (unwrap-number b)))

(defmethod %xor ((a <integer>) (b <integer>))
  "Bitwise XOR for integers."
  (cl:logxor (unwrap-number a) (unwrap-number b)))

;;; --- Mixed / Native Implementations ---

(defmethod %and ((a t) (b t))
  (let ((ua (unwrap a))
        (ub (unwrap b)))
    (cond
      ((and (typep ua 'boolean) (typep ub 'boolean))
       (cl:and ua ub))
      ((and (integerp ua) (integerp ub))
       (cl:logand ua ub))
      (t (error "Cannot AND ~A and ~A" a b)))))

(defmethod %or ((a t) (b t))
  (let ((ua (unwrap a))
        (ub (unwrap b)))
    (cond
      ((and (typep ua 'boolean) (typep ub 'boolean))
       (cl:or ua ub))
      ((and (integerp ua) (integerp ub))
       (cl:logior ua ub))
      (t (error "Cannot OR ~A and ~A" a b)))))

(defmethod %xor ((a t) (b t))
  (let ((ua (unwrap a))
        (ub (unwrap b)))
    (cond
      ((and (typep ua 'boolean) (typep ub 'boolean))
       (cl:not (cl:eq ua ub)))
      ((and (integerp ua) (integerp ub))
       (cl:logxor ua ub))
      (t (error "Cannot XOR ~A and ~A" a b)))))


;;; ============================================================================
;;; Unary NOT Operation
;;; ============================================================================

(defgeneric not (obj)
  (:documentation "Returns the logical negation of a boolean or bitwise NOT of an integer."))

(defmethod not ((obj <bool>))
  "Logical NOT for booleans."
  (wrap (cl:not (unwrap-bool obj))))

(defmethod not ((obj <integer>))
  "Bitwise NOT for integers (one's complement)."
  (wrap (cl:lognot (unwrap-number obj))))

(defmethod not (obj)
  (let ((u (unwrap obj)))
    (cond
      ((typep u 'boolean) (wrap (cl:not u)))
      ((integerp u) (wrap (cl:lognot u)))
      (t (error "NOT requires a boolean or integer, got ~A" obj)))))


;;; ============================================================================
;;; Public Variadic Logical Operators
;;; ============================================================================

(defgeneric and (&rest args)
  (:documentation "Variadic AND. Logical AND for booleans, bitwise AND for integers."))

(defmethod and (&rest args)
  (cond
    ;; No arguments: identity is true for logical, -1 for bitwise
    ((null args) (wrap t))
    ;; One argument: return it
    ((null (cdr args)) (car args))
    ;; Multiple arguments: determine type and fold
    (t
     (let ((first-unwrapped (unwrap (car args))))
       (cond
         ;; All booleans: logical AND
         ((typep first-unwrapped 'boolean)
          (wrap (every #'(lambda (x) (unwrap-bool x)) args)))
         ;; All integers: bitwise AND - reduce on unwrapped values
         ((integerp first-unwrapped)
          (wrap (reduce #'cl:logand args :key #'unwrap-number)))
         (t (error "AND requires all arguments to be the same type")))))))


(defgeneric or (&rest args)
  (:documentation "Variadic OR. Logical OR for booleans, bitwise OR for integers."))

(defmethod or (&rest args)
  (cond
    ;; No arguments: identity is false for logical, 0 for bitwise
    ((null args) (wrap nil))
    ;; One argument: return it
    ((null (cdr args)) (car args))
    ;; Multiple arguments: determine type and fold
    (t
     (let ((first-unwrapped (unwrap (car args))))
       (cond
         ;; All booleans: logical OR
         ((typep first-unwrapped 'boolean)
          (wrap (some #'(lambda (x) (unwrap-bool x)) args)))
         ;; All integers: bitwise OR - reduce on unwrapped values
         ((integerp first-unwrapped)
          (wrap (reduce #'cl:logior args :key #'unwrap-number)))
         (t (error "OR requires all arguments to be the same type")))))))


(defgeneric xor (&rest args)
  (:documentation "Variadic XOR. Logical XOR for booleans, bitwise XOR for integers."))

(defmethod xor (&rest args)
  (cond
    ;; No arguments: identity is false for logical, 0 for bitwise
    ((null args) (wrap nil))
    ;; One argument: return it
    ((null (cdr args)) (car args))
    ;; Multiple arguments: determine type and fold
    (t
     (let ((first-unwrapped (unwrap (car args))))
       (cond
         ;; All booleans: logical XOR (odd number of trues)
         ((typep first-unwrapped 'boolean)
          (wrap (reduce (lambda (a b) (cl:not (eq a b)))
                        args
                        :key #'unwrap-bool
                        :initial-value nil)))
         ;; All integers: bitwise XOR - reduce on unwrapped values
         ((integerp first-unwrapped)
          (wrap (reduce #'cl:logxor args :key #'unwrap-number)))
         (t (error "XOR requires all arguments to be the same type")))))))


;;; ============================================================================
;;; Derived Logical Operators
;;; ============================================================================

(defgeneric implies (a b)
  (:documentation "Logical implication (If A then B). For booleans: (OR (NOT A) B). For integers: bitwise equivalent."))

(defmethod implies ((a <bool>) (b <bool>))
  "Logical implication for booleans."
  (wrap (cl:or (cl:not (unwrap-bool a)) 
               (unwrap-bool b))))

(defmethod implies ((a <integer>) (b <integer>))
  "Bitwise implication for integers: (~A) | B"
  (wrap (cl:logior (cl:lognot (unwrap-number a))
                   (unwrap-number b))))

(defmethod implies (a b)
  (let ((ua (unwrap a))
        (ub (unwrap b)))
    (cond
      ((and (typep ua 'boolean) (typep ub 'boolean))
       (wrap (cl:or (cl:not ua) ub)))
      ((and (integerp ua) (integerp ub))
       (wrap (cl:logior (cl:lognot ua) ub)))
      (t (error "IMPLIES requires matching types (both boolean or both integer), got ~A and ~A" a b)))))




;;; ============================================================================
;;; Additional Bitwise/Logical Operations
;;; ============================================================================

(defgeneric nand (&rest args)
  (:documentation "Variadic NAND. Returns NOT (AND args). Logical NAND for booleans, bitwise NAND for integers."))

(defmethod nand (&rest args)
  (cond
    ;; No arguments: NOT(AND()) = NOT(true) = false
    ((null args) (wrap nil))
    ;; One argument: NOT(arg)
    ((null (cdr args)) (not (car args)))
    ;; Multiple arguments: NOT(AND(args...))
    (t
     (let ((first-unwrapped (unwrap (car args))))
       (cond
         ;; All booleans: logical NAND
         ((typep first-unwrapped 'boolean)
          (wrap (cl:not (every #'(lambda (x) (unwrap-bool x)) args))))
         ;; All integers: bitwise NAND - reduce on unwrapped values
         ((integerp first-unwrapped)
          (wrap (cl:lognot (reduce #'cl:logand args :key #'unwrap-number))))
         (t (error "NAND requires all arguments to be the same type")))))))


(defgeneric nor (&rest args)
  (:documentation "Variadic NOR. Returns NOT (OR args). Logical NOR for booleans, bitwise NOR for integers."))

(defmethod nor (&rest args)
  (cond
    ;; No arguments: NOT(OR()) = NOT(false) = true
    ((null args) (wrap t))
    ;; One argument: NOT(arg)
    ((null (cdr args)) (not (car args)))
    ;; Multiple arguments: NOT(OR(args...))
    (t
     (let ((first-unwrapped (unwrap (car args))))
       (cond
         ;; All booleans: logical NOR
         ((typep first-unwrapped 'boolean)
          (wrap (cl:not (some #'(lambda (x) (unwrap-bool x)) args))))
         ;; All integers: bitwise NOR - reduce on unwrapped values
         ((integerp first-unwrapped)
          (wrap (cl:lognot (reduce #'cl:logior args :key #'unwrap-number))))
         (t (error "NOR requires all arguments to be the same type")))))))