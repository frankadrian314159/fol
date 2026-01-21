(in-package fol.compareop)

;;; ============================================================================
;;; Comparison Operations - Option 4 (Tagged Representation)
;;; ============================================================================
;;;
;;; All operations work transparently on both raw CL values and wrapped
;;; FOL objects. Results are returned as raw CL booleans (T/NIL).

;;; ============================================================================
;;; Generic Equality (%=)
;;; ============================================================================

(defgeneric %= (a b)
  (:documentation "Pairwise equality check. Works on raw or wrapped values."))

;;; --- Raw CL primitives (most efficient path) ---

(defmethod %= ((a number) (b number))
  (cl:= a b))

(defmethod %= ((a character) (b character))
  (cl:char= a b))

(defmethod %= ((a string) (b string))
  (string= a b))

(defmethod %= ((a symbol) (b symbol))
  (eq a b))

;;; --- Wrapped FOL objects ---

(defmethod %= ((a <bool>) (b <bool>))
  (eq (fol-value a) (fol-value b)))

(defmethod %= ((a <char>) (b <char>))
  (cl:char= (fol-value a) (fol-value b)))

(defmethod %= ((a <string>) (b <string>))
  (string= (fol-value a) (fol-value b)))

(defmethod %= ((a <number>) (b <number>))
  (cl:= (fol-value a) (fol-value b)))

(defmethod %= ((a <symbol>) (b <symbol>))
  (eq (fol-value a) (fol-value b)))

;;; --- Mixed: wrapped + raw ---

(defmethod %= ((a <bool>) (b symbol))
  (eq (fol-value a) b))

(defmethod %= ((a symbol) (b <bool>))
  (eq a (fol-value b)))

(defmethod %= ((a <char>) (b character))
  (cl:char= (fol-value a) b))

(defmethod %= ((a character) (b <char>))
  (cl:char= a (fol-value b)))

(defmethod %= ((a <string>) (b string))
  (string= (fol-value a) b))

(defmethod %= ((a string) (b <string>))
  (string= a (fol-value b)))

(defmethod %= ((a <number>) (b number))
  (cl:= (fol-value a) b))

(defmethod %= ((a number) (b <number>))
  (cl:= a (fol-value b)))

(defmethod %= ((a <symbol>) (b symbol))
  (eq (fol-value a) b))

(defmethod %= ((a symbol) (b <symbol>))
  (eq a (fol-value b)))

;;; --- Persistent objects ---

(defmethod %= ((a <persistent-object>) (b <persistent-object>))
  (equal (%persistent-storage a) (%persistent-storage b)))

;;; --- Fallback using equal ---

(defmethod %= (a b)
  (equal (fol-value a) (fol-value b)))


;;; ============================================================================
;;; Generic Inequality Helper (%/=)
;;; ============================================================================

(defgeneric %/= (a b)
  (:documentation "Pairwise inequality check."))

(defmethod %/= (a b)
  (not (%= a b)))


;;; ============================================================================
;;; Generic Ordering (%<, %<=, %>, %>=)
;;; ============================================================================

(defgeneric %< (a b) (:documentation "Binary less-than."))
(defgeneric %<= (a b) (:documentation "Binary less-than-or-equal."))
(defgeneric %> (a b) (:documentation "Binary greater-than."))
(defgeneric %>= (a b) (:documentation "Binary greater-than-or-equal."))

;;; --- Raw Number Implementations ---

(defmethod %< ((a number) (b number)) (cl:< a b))
(defmethod %<= ((a number) (b number)) (cl:<= a b))
(defmethod %> ((a number) (b number)) (cl:> a b))
(defmethod %>= ((a number) (b number)) (cl:>= a b))

;;; --- Raw Character Implementations ---

(defmethod %< ((a character) (b character)) (cl:char< a b))
(defmethod %<= ((a character) (b character)) (cl:char<= a b))
(defmethod %> ((a character) (b character)) (cl:char> a b))
(defmethod %>= ((a character) (b character)) (cl:char>= a b))

;;; --- Raw String Implementations ---

(defmethod %< ((a string) (b string)) (if (string< a b) t nil))
(defmethod %<= ((a string) (b string)) (if (string<= a b) t nil))
(defmethod %> ((a string) (b string)) (if (string> a b) t nil))
(defmethod %>= ((a string) (b string)) (if (string>= a b) t nil))

;;; --- Wrapped Number Implementations ---

(defmethod %< ((a <number>) (b <number>)) (cl:< (fol-value a) (fol-value b)))
(defmethod %<= ((a <number>) (b <number>)) (cl:<= (fol-value a) (fol-value b)))
(defmethod %> ((a <number>) (b <number>)) (cl:> (fol-value a) (fol-value b)))
(defmethod %>= ((a <number>) (b <number>)) (cl:>= (fol-value a) (fol-value b)))

;;; --- Wrapped Character Implementations ---

(defmethod %< ((a <char>) (b <char>)) (cl:char< (fol-value a) (fol-value b)))
(defmethod %<= ((a <char>) (b <char>)) (cl:char<= (fol-value a) (fol-value b)))
(defmethod %> ((a <char>) (b <char>)) (cl:char> (fol-value a) (fol-value b)))
(defmethod %>= ((a <char>) (b <char>)) (cl:char>= (fol-value a) (fol-value b)))

;;; --- Wrapped String Implementations ---

(defmethod %< ((a <string>) (b <string>)) (if (string< (fol-value a) (fol-value b)) t nil))
(defmethod %<= ((a <string>) (b <string>)) (if (string<= (fol-value a) (fol-value b)) t nil))
(defmethod %> ((a <string>) (b <string>)) (if (string> (fol-value a) (fol-value b)) t nil))
(defmethod %>= ((a <string>) (b <string>)) (if (string>= (fol-value a) (fol-value b)) t nil))

;;; --- Boolean Implementations (NIL < T) ---

(defmethod %< ((a <bool>) (b <bool>))
  (and (not (fol-value a)) (fol-value b)))

(defmethod %<= ((a <bool>) (b <bool>))
  (or (not (fol-value a)) (fol-value b)))

(defmethod %> ((a <bool>) (b <bool>))
  (and (fol-value a) (not (fol-value b))))

(defmethod %>= ((a <bool>) (b <bool>))
  (or (fol-value a) (not (fol-value b))))

;;; --- Mixed: wrapped + raw for numbers ---

(defmethod %< ((a <number>) (b number)) (cl:< (fol-value a) b))
(defmethod %< ((a number) (b <number>)) (cl:< a (fol-value b)))
(defmethod %<= ((a <number>) (b number)) (cl:<= (fol-value a) b))
(defmethod %<= ((a number) (b <number>)) (cl:<= a (fol-value b)))
(defmethod %> ((a <number>) (b number)) (cl:> (fol-value a) b))
(defmethod %> ((a number) (b <number>)) (cl:> a (fol-value b)))
(defmethod %>= ((a <number>) (b number)) (cl:>= (fol-value a) b))
(defmethod %>= ((a number) (b <number>)) (cl:>= a (fol-value b)))

;;; --- Mixed: wrapped + raw for characters ---

(defmethod %< ((a <char>) (b character)) (cl:char< (fol-value a) b))
(defmethod %< ((a character) (b <char>)) (cl:char< a (fol-value b)))
(defmethod %<= ((a <char>) (b character)) (cl:char<= (fol-value a) b))
(defmethod %<= ((a character) (b <char>)) (cl:char<= a (fol-value b)))
(defmethod %> ((a <char>) (b character)) (cl:char> (fol-value a) b))
(defmethod %> ((a character) (b <char>)) (cl:char> a (fol-value b)))
(defmethod %>= ((a <char>) (b character)) (cl:char>= (fol-value a) b))
(defmethod %>= ((a character) (b <char>)) (cl:char>= a (fol-value b)))

;;; --- Mixed: wrapped + raw for strings ---

(defmethod %< ((a <string>) (b string)) (if (string< (fol-value a) b) t nil))
(defmethod %< ((a string) (b <string>)) (if (string< a (fol-value b)) t nil))
(defmethod %<= ((a <string>) (b string)) (if (string<= (fol-value a) b) t nil))
(defmethod %<= ((a string) (b <string>)) (if (string<= a (fol-value b)) t nil))
(defmethod %> ((a <string>) (b string)) (if (string> (fol-value a) b) t nil))
(defmethod %> ((a string) (b <string>)) (if (string> a (fol-value b)) t nil))
(defmethod %>= ((a <string>) (b string)) (if (string>= (fol-value a) b) t nil))
(defmethod %>= ((a string) (b <string>)) (if (string>= a (fol-value b)) t nil))

;;; --- Fallback with type dispatch ---

(defmethod %< (a b)
  (let ((ua (fol-value a))
        (ub (fol-value b)))
    (cond
      ((and (numberp ua) (numberp ub)) (cl:< ua ub))
      ((and (characterp ua) (characterp ub)) (cl:char< ua ub))
      ((and (stringp ua) (stringp ub)) (if (string< ua ub) t nil))
      ((and (typep ua 'boolean) (typep ub 'boolean)) (and (not ua) ub))
      (t (error "Cannot compare ~A and ~A" a b)))))

(defmethod %<= (a b)
  (let ((ua (fol-value a))
        (ub (fol-value b)))
    (cond
      ((and (numberp ua) (numberp ub)) (cl:<= ua ub))
      ((and (characterp ua) (characterp ub)) (cl:char<= ua ub))
      ((and (stringp ua) (stringp ub)) (if (string<= ua ub) t nil))
      ((and (typep ua 'boolean) (typep ub 'boolean)) (or (not ua) ub))
      (t (error "Cannot compare ~A and ~A" a b)))))

(defmethod %> (a b)
  (let ((ua (fol-value a))
        (ub (fol-value b)))
    (cond
      ((and (numberp ua) (numberp ub)) (cl:> ua ub))
      ((and (characterp ua) (characterp ub)) (cl:char> ua ub))
      ((and (stringp ua) (stringp ub)) (if (string> ua ub) t nil))
      ((and (typep ua 'boolean) (typep ub 'boolean)) (and ua (not ub)))
      (t (error "Cannot compare ~A and ~A" a b)))))

(defmethod %>= (a b)
  (let ((ua (fol-value a))
        (ub (fol-value b)))
    (cond
      ((and (numberp ua) (numberp ub)) (cl:>= ua ub))
      ((and (characterp ua) (characterp ub)) (cl:char>= ua ub))
      ((and (stringp ua) (stringp ub)) (if (string>= ua ub) t nil))
      ((and (typep ua 'boolean) (typep ub 'boolean)) (or ua (not ub)))
      (t (error "Cannot compare ~A and ~A" a b)))))


;;; ============================================================================
;;; Public Variadic Operators
;;; ============================================================================
;;; These return raw CL booleans (T/NIL).

(defgeneric = (&rest args)
  (:documentation "Returns T if all arguments are equal."))

(defmethod = (&rest args)
  (cond
    ((null args) t)
    ((null (cdr args)) t)
    (t (loop for (a b) on args
             while b
             always (%= a b)))))

(defgeneric /= (&rest args)
  (:documentation "Returns T if no two arguments are equal."))

(defmethod /= (&rest args)
  (cond
    ((null args) t)
    ((null (cdr args)) t)
    (t (loop for (head . tail) on args
             always (loop for other in tail
                          never (%= head other))))))

(defgeneric < (&rest args)
  (:documentation "Strictly increasing."))

(defmethod < (&rest args)
  (cond
    ((null args) t)
    ((null (cdr args)) t)
    (t (loop for (a b) on args
             while b
             always (%< a b)))))

(defgeneric > (&rest args)
  (:documentation "Strictly decreasing."))

(defmethod > (&rest args)
  (cond
    ((null args) t)
    ((null (cdr args)) t)
    (t (loop for (a b) on args
             while b
             always (%> a b)))))

(defgeneric <= (&rest args)
  (:documentation "Non-decreasing."))

(defmethod <= (&rest args)
  (cond
    ((null args) t)
    ((null (cdr args)) t)
    (t (loop for (a b) on args
             while b
             always (%<= a b)))))

(defgeneric >= (&rest args)
  (:documentation "Non-increasing."))

(defmethod >= (&rest args)
  (cond
    ((null args) t)
    ((null (cdr args)) t)
    (t (loop for (a b) on args
             while b
             always (%>= a b)))))


;;; ============================================================================
;;; Min and Max
;;; ============================================================================

(defgeneric min (a &rest args) (:documentation "Minimum."))

(defmethod min (a &rest args)
  "Returns the minimum of its arguments based on the %< primitive.
   Returns a raw CL value (unwrapped)."
  (let ((min-val (fol-value a)))
    (dolist (item args)
      (let ((item-val (fol-value item)))
        (when (%< item-val min-val)
          (setf min-val item-val))))
    min-val))

(defgeneric max (a &rest args) (:documentation "Maximum."))

(defmethod max (a &rest args)
  "Returns the maximum of its arguments based on the %< primitive.
   Returns a raw CL value (unwrapped)."
  (let ((max-val (fol-value a)))
    (dolist (item args)
      (let ((item-val (fol-value item)))
        (when (%< max-val item-val)
          (setf max-val item-val))))
    max-val))
