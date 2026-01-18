(in-package fol.compareop)

;;; ============================================================================
;;; Generic Equality (%=)
;;; ============================================================================

(defgeneric %= (a b)
  (:documentation "Pairwise equality check. Unwraps FOL instances or compares natives."))

(defmethod %= ((a <bool>) (b <bool>))
  (eq (unwrap a) (unwrap b)))

(defmethod %= ((a <char>) (b <char>))
  (cl:char= (unwrap a) (unwrap b)))

(defmethod %= ((a <string>) (b <string>))
  (string= (unwrap a) (unwrap b)))

(defmethod %= ((a <number>) (b <number>))
  (cl:= (unwrap a) (unwrap b)))
  
(defmethod %= ((a t) (b t))
  (equal a b))

(defmethod %= ((a <bool>) (b t))
  (equal (unwrap a) b))

(defmethod %= ((a t) (b <bool>))
  (equal a (unwrap b)))
  
(defmethod %= ((a <char>) (b t))
  (equal (unwrap a) b))

(defmethod %= ((a t) (b <char>))
  (equal a (unwrap b)))

(defmethod %= ((a <string>) (b t))
  (equal (unwrap a) b))

(defmethod %= ((a t) (b <string>))
  (equal a (unwrap b)))

(defmethod %= ((a <number>) (b t))
  (equal (unwrap a) b))

(defmethod %= ((a t) (b <number>))
  (equal a (unwrap b)))

(defmethod %= ((a t) (b <number>))
  (equal a (unwrap b)))

(defmethod %= ((a <persistent-object>) (b t))
  (equal (unwrap a) b))

(defmethod %= ((a t) (b <persistent-object>))
  (equal a (unwrap b)))

(defmethod %= ((a <persistent-object>) (b <persistent-object>))
  (equal (%persistent-storage a) (%persistent-storage b)))

(defmethod %= ((a t) (b t))
  (equal a b))


;;; ============================================================================
;;; Generic Inequality Helper (%/=)
;;; ============================================================================

(defmethod %/= (a b)
  (not (%= a b)))

;;; ============================================================================
;;; Generic Ordering (%<, %<=, %>, %>=)
;;; ============================================================================

(defgeneric %< (a b) (:documentation "Binary less-than."))
(defgeneric %<= (a b) (:documentation "Binary less-than-or-equal."))
(defgeneric %> (a b) (:documentation "Binary greater-than."))
(defgeneric %>= (a b) (:documentation "Binary greater-than-or-equal."))

;;; --- Number Implementations ---

(defmethod %< ((a <number>) (b <number>)) (cl:< (unwrap a) (unwrap b)))
(defmethod %<= ((a <number>) (b <number>)) (cl:<= (unwrap a) (unwrap b)))
(defmethod %> ((a <number>) (b <number>)) (cl:> (unwrap a) (unwrap b)))
(defmethod %>= ((a <number>) (b <number>)) (cl:>= (unwrap a) (unwrap b)))

;;; --- Character Implementations ---

(defmethod %< ((a <char>) (b <char>)) (cl:char< (unwrap a) (unwrap b)))
(defmethod %<= ((a <char>) (b <char>)) (cl:char<= (unwrap a) (unwrap b)))
(defmethod %> ((a <char>) (b <char>)) (cl:char> (unwrap a) (unwrap b)))
(defmethod %>= ((a <char>) (b <char>)) (cl:char>= (unwrap a) (unwrap b)))

;;; --- String Implementations ---
(defmethod %< ((a <string>) (b <string>)) (string< (unwrap a) (unwrap b)))
(defmethod %<= ((a <string>) (b <string>)) (string<= (unwrap a) (unwrap b)))
(defmethod %> ((a <string>) (b <string>)) (string> (unwrap a) (unwrap b)))
(defmethod %>= ((a <string>) (b <string>)) (string>= (unwrap a) (unwrap b)))

;;; --- Boolean Implementations (NIL < T) ---

(defmethod %< ((a <bool>) (b <bool>)) 
  ;; True if A is False and B is True
  (and (not (unwrap a)) (unwrap b)))

(defmethod %<= ((a <bool>) (b <bool>))
  ;; True if A is False OR B is True (Implication)
  (or (not (unwrap a)) (unwrap b)))

(defmethod %> ((a <bool>) (b <bool>))
  ;; True if A is True and B is False
  (and (unwrap a) (not (unwrap b))))

(defmethod %>= ((a <bool>) (b <bool>))
  ;; True if A is True OR B is False
  (or (unwrap a) (not (unwrap b))))

;;; --- Mixed / Native Implementations ---
;;; To support mixed comparisons (e.g. (< (wrap 1) 2)), we define methods for (T T)
;;; and dispatch based on run-time types for safety.

(defmethod %< ((a t) (b t))
  (let ((ua (unwrap a))
        (ub (unwrap b)))
    (cond
      ((and (numberp ua) (numberp ub)) (cl:< ua ub))
      ((and (characterp ua) (characterp ub)) (cl:char< ua ub))
      ((and (stringp ua) (stringp ub)) (string< ua ub))
      ((and (typep ua 'boolean) (typep ub 'boolean)) (and (not ua) ub))
      (t (error "Cannot compare ~A and ~A" a b)))))

(defmethod %<= ((a t) (b t))
  (let ((ua (unwrap a))
        (ub (unwrap b)))
    (cond
      ((and (numberp ua) (numberp ub)) (cl:<= ua ub))
      ((and (characterp ua) (characterp ub)) (cl:char<= ua ub))
      ((and (stringp ua) (stringp ub)) (string<= ua ub))
      ((and (typep ua 'boolean) (typep ub 'boolean)) (or (not ua) ub))
      (t (error "Cannot compare ~A and ~A" a b)))))

(defmethod %> ((a t) (b t))
  (let ((ua (unwrap a))
        (ub (unwrap b)))
    (cond
      ((and (numberp ua) (numberp ub)) (cl:> ua ub))
      ((and (characterp ua) (characterp ub)) (cl:char> ua ub))
      ((and (stringp ua) (stringp ub)) (string> ua ub))
      ((and (typep ua 'boolean) (typep ub 'boolean)) (and ua (not ub)))
      (t (error "Cannot compare ~A and ~A" a b)))))

(defmethod %>= ((a t) (b t))
  (let ((ua (unwrap a))
        (ub (unwrap b)))
    (cond
      ((and (numberp ua) (numberp ub)) (cl:>= ua ub))
      ((and (characterp ua) (characterp ub)) (cl:char>= ua ub))
      ((and (stringp ua) (stringp ub)) (string>= ua ub))
      ((and (typep ua 'boolean) (typep ub 'boolean)) (or ua (not ub)))
      (t (error "Cannot compare ~A and ~A" a b)))))


;;; ============================================================================
;;; Public Variadic Operators
;;; ============================================================================

(defgeneric = (&rest args)
  (:documentation "Returns T if all arguments are equal."))

(defmethod = (&rest args)
  (let ((result 
         (cond
           ((null args) t)
           ((null (cdr args)) t)
           (t (loop for (a b) on args
                    while b
                    always (%= a b))))))
    (wrap result)))

(defgeneric /= (&rest args)
  (:documentation "Returns #t if no two arguments are equal."))

(defmethod /= (&rest args)
  (let ((result 
         (cond
           ((null args) t)
           ((null (cdr args)) t)
           (t (loop for (head . tail) on args
                    always (loop for other in tail
                                 never (%= head other)))))))
    (wrap result)))

(defgeneric < (&rest args)
  (:documentation "Strictly increasing."))
(defmethod < (&rest args)
  (let ((result
         (cond
           ((null args) t)
           ((null (cdr args)) t)
           (t (loop for (a b) on args
                    while b
                    always (%< a b))))))
    (wrap result)))

(defgeneric > (&rest args)
  (:documentation "Strictly decreasing."))
(defmethod > (&rest args)
  (let ((result
         (cond
           ((null args) t)
           ((null (cdr args)) t)
           (t (loop for (a b) on args
                    while b
                    always (%> a b))))))
    (wrap result)))

(defgeneric <= (&rest args)
  (:documentation "Non-decreasing."))
(defmethod <= (&rest args)
  (let ((result
         (cond
           ((null args) t)
           ((null (cdr args)) t)
           (t (loop for (a b) on args
                    while b
                    always (%<= a b))))))
    (wrap result)))

(defgeneric >= (&rest args)
  (:documentation "Non-increasing."))
(defmethod >= (&rest args)
  (let ((result
         (cond
           ((null args) t)
           ((null (cdr args)) t)
           (t (loop for (a b) on args
                    while b
                    always (%>= a b))))))
    (wrap result)))


;;; ============================================================================
;;; Min and Max
;;; ============================================================================
(defgeneric min (a &rest args) (:documentation "Minimum."))

(defmethod min (a &rest args)
  "Returns the minimum of its arguments based on the %< primitive."
  (let ((min-val a))
    (dolist (item args)
      (when (%< item min-val)
        (setf min-val item)))
    min-val))

(defgeneric max (a &rest args) (:documentation "Maximum."))

(defmethod max (a &rest args)
  "Returns the maximum of its arguments based on the %< primitive."
  (let ((max-val a))
    (dolist (item args)
      (when (%< max-val item)
        (setf max-val item)))
    max-val))
