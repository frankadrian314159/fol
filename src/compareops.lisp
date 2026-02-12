(in-package :fol.compiler.compareops)

;;; ============================================================================
;;; Comparison Operations (Tagged Representation)
;;; ============================================================================
;;;
;;; All operations work transparently on raw CL values.
;;; Results are returned as raw CL booleans (T/NIL).
;;;
;;; Type ordering for cross-type comparisons:
;;;   boolean < character < string < number

;;; ============================================================================
;;; Generic Equality (%=)
;;; ============================================================================

(defgeneric %= (a b)
  (:documentation "Pairwise equality check. Works on raw CL values."))

;;; --- Raw CL primitives (most efficient path) ---

(defmethod %= ((a (eql t)) (b (eql t))) t)
(defmethod %= ((a (eql nil)) (b (eql nil))) t)
(defmethod %= ((a (eql t)) (b (eql nil))) nil)
(defmethod %= ((a (eql nil)) (b (eql t))) nil)

(defmethod %= ((a number) (b number))
  (cl:= a b))

(defmethod %= ((a character) (b character))
  (char= a b))

(defmethod %= ((a string) (b string))
  (string= a b))

(defmethod %= ((a symbol) (b symbol))
  (eq a b))

;;; --- Default: not equal ---

(defmethod %= (a b)
  (declare (ignore a b))
  nil)

;;; ============================================================================
;;; Generic Inequality (%/=)
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

;;; --- Boolean comparisons (NIL < T) ---

(defmethod %< ((a (eql nil)) (b (eql t))) t)
(defmethod %< ((a (eql t)) (b (eql nil))) nil)
(defmethod %< ((a (eql nil)) (b (eql nil))) nil)
(defmethod %< ((a (eql t)) (b (eql t))) nil)

(defmethod %> ((a (eql nil)) (b (eql t))) nil)
(defmethod %> ((a (eql t)) (b (eql nil))) t)
(defmethod %> ((a (eql nil)) (b (eql nil))) nil)
(defmethod %> ((a (eql t)) (b (eql t))) nil)

(defmethod %<= ((a (eql nil)) (b (eql t))) t)
(defmethod %<= ((a (eql t)) (b (eql nil))) nil)
(defmethod %<= ((a (eql nil)) (b (eql nil))) t)
(defmethod %<= ((a (eql t)) (b (eql t))) t)

(defmethod %>= ((a (eql nil)) (b (eql t))) nil)
(defmethod %>= ((a (eql t)) (b (eql nil))) t)
(defmethod %>= ((a (eql nil)) (b (eql nil))) t)
(defmethod %>= ((a (eql t)) (b (eql t))) t)

;;; --- Cross-type: boolean < character ---

(defmethod %< ((a (eql t)) (b character)) t)
(defmethod %< ((a (eql nil)) (b character)) t)
(defmethod %< ((a character) (b (eql t))) nil)
(defmethod %< ((a character) (b (eql nil))) nil)

(defmethod %> ((a (eql t)) (b character)) nil)
(defmethod %> ((a (eql nil)) (b character)) nil)
(defmethod %> ((a character) (b (eql t))) t)
(defmethod %> ((a character) (b (eql nil))) t)

(defmethod %<= ((a (eql t)) (b character)) t)
(defmethod %<= ((a (eql nil)) (b character)) t)
(defmethod %<= ((a character) (b (eql t))) nil)
(defmethod %<= ((a character) (b (eql nil))) nil)

(defmethod %>= ((a (eql t)) (b character)) nil)
(defmethod %>= ((a (eql nil)) (b character)) nil)
(defmethod %>= ((a character) (b (eql t))) t)
(defmethod %>= ((a character) (b (eql nil))) t)

;;; --- Cross-type: boolean < string ---

(defmethod %< ((a (eql t)) (b string)) t)
(defmethod %< ((a (eql nil)) (b string)) t)
(defmethod %< ((a string) (b (eql t))) nil)
(defmethod %< ((a string) (b (eql nil))) nil)

(defmethod %> ((a (eql t)) (b string)) nil)
(defmethod %> ((a (eql nil)) (b string)) nil)
(defmethod %> ((a string) (b (eql t))) t)
(defmethod %> ((a string) (b (eql nil))) t)

(defmethod %<= ((a (eql t)) (b string)) t)
(defmethod %<= ((a (eql nil)) (b string)) t)
(defmethod %<= ((a string) (b (eql t))) nil)
(defmethod %<= ((a string) (b (eql nil))) nil)

(defmethod %>= ((a (eql t)) (b string)) nil)
(defmethod %>= ((a (eql nil)) (b string)) nil)
(defmethod %>= ((a string) (b (eql t))) t)
(defmethod %>= ((a string) (b (eql nil))) t)

;;; --- Cross-type: boolean < number ---

(defmethod %< ((a (eql t)) (b number)) t)
(defmethod %< ((a (eql nil)) (b number)) t)
(defmethod %< ((a number) (b (eql t))) nil)
(defmethod %< ((a number) (b (eql nil))) nil)

(defmethod %> ((a (eql t)) (b number)) nil)
(defmethod %> ((a (eql nil)) (b number)) nil)
(defmethod %> ((a number) (b (eql t))) t)
(defmethod %> ((a number) (b (eql nil))) t)

(defmethod %<= ((a (eql t)) (b number)) t)
(defmethod %<= ((a (eql nil)) (b number)) t)
(defmethod %<= ((a number) (b (eql t))) nil)
(defmethod %<= ((a number) (b (eql nil))) nil)

(defmethod %>= ((a (eql t)) (b number)) nil)
(defmethod %>= ((a (eql nil)) (b number)) nil)
(defmethod %>= ((a number) (b (eql t))) t)
(defmethod %>= ((a number) (b (eql nil))) t)

;;; --- Character comparisons ---

(defmethod %< ((a character) (b character)) (if (char< a b) t nil))
(defmethod %<= ((a character) (b character)) (if (char<= a b) t nil))
(defmethod %> ((a character) (b character)) (if (char> a b) t nil))
(defmethod %>= ((a character) (b character)) (if (char>= a b) t nil))

;;; --- Cross-type: character < string ---

(defmethod %< ((a character) (b string)) t)
(defmethod %< ((a string) (b character)) nil)
(defmethod %<= ((a character) (b string)) t)
(defmethod %<= ((a string) (b character)) nil)
(defmethod %> ((a character) (b string)) nil)
(defmethod %> ((a string) (b character)) t)
(defmethod %>= ((a character) (b string)) nil)
(defmethod %>= ((a string) (b character)) t)

;;; --- Cross-type: character < number ---

(defmethod %< ((a character) (b number)) t)
(defmethod %< ((a number) (b character)) nil)
(defmethod %<= ((a character) (b number)) t)
(defmethod %<= ((a number) (b character)) nil)
(defmethod %> ((a character) (b number)) nil)
(defmethod %> ((a number) (b character)) t)
(defmethod %>= ((a character) (b number)) nil)
(defmethod %>= ((a number) (b character)) t)

;;; --- String comparisons ---

(defmethod %< ((a string) (b string)) (if (string< a b) t nil))
(defmethod %<= ((a string) (b string)) (if (string<= a b) t nil))
(defmethod %> ((a string) (b string)) (if (string> a b) t nil))
(defmethod %>= ((a string) (b string)) (if (string>= a b) t nil))

;;; --- Cross-type: string < number ---

(defmethod %< ((a string) (b number)) t)
(defmethod %< ((a number) (b string)) nil)
(defmethod %<= ((a string) (b number)) t)
(defmethod %<= ((a number) (b string)) nil)
(defmethod %> ((a string) (b number)) nil)
(defmethod %> ((a number) (b string)) t)
(defmethod %>= ((a string) (b number)) nil)
(defmethod %>= ((a number) (b string)) t)

;;; --- Number comparisons ---

(defmethod %< ((a number) (b number)) (cl:< a b))
(defmethod %<= ((a number) (b number)) (cl:<= a b))
(defmethod %> ((a number) (b number)) (cl:> a b))
(defmethod %>= ((a number) (b number)) (cl:>= a b))

;;; --- Fallback: error for unsupported types ---

(defmethod %< (a b)
  (error "Cannot compare ~A (~A) and ~A (~A) with <"
         a (type-of a) b (type-of b)))

(defmethod %> (a b)
  (error "Cannot compare ~A (~A) and ~A (~A) with >"
         a (type-of a) b (type-of b)))

(defmethod %<= (a b)
  (not (%> a b)))

(defmethod %>= (a b)
  (not (%< a b)))

;;; ============================================================================
;;; Public Variadic Operators
;;; ============================================================================
;;; These return raw CL booleans (T/NIL).

(defun = (&rest args)
  "Returns T if all arguments are equal."
  (or (null args)
      (null (cdr args))
      (loop for (a b) on args
            while b
            always (%= a b))))

(defun /= (&rest args)
  "Returns T if no two arguments are equal."
  (or (null args)
      (null (cdr args))
      (loop for (head . tail) on args
            always (loop for other in tail
                         never (%= head other)))))

(defun < (&rest args)
  "Returns T if arguments are strictly increasing."
  (or (null args)
      (null (cdr args))
      (loop for (a b) on args
            while b
            always (%< a b))))

(defun > (&rest args)
  "Returns T if arguments are strictly decreasing."
  (or (null args)
      (null (cdr args))
      (loop for (a b) on args
            while b
            always (%> a b))))

(defun <= (&rest args)
  "Returns T if arguments are non-decreasing."
  (or (null args)
      (null (cdr args))
      (loop for (a b) on args
            while b
            always (%<= a b))))

(defun >= (&rest args)
  "Returns T if arguments are non-increasing."
  (or (null args)
      (null (cdr args))
      (loop for (a b) on args
            while b
            always (%>= a b))))

;;; ============================================================================
;;; Min and Max
;;; ============================================================================

(defun min (first &rest args)
  "Returns the minimum of its arguments based on %<."
  (let ((result first))
    (dolist (item args result)
      (when (%< item result)
        (setf result item)))))

(defun max (first &rest args)
  "Returns the maximum of its arguments based on %>."
  (let ((result first))
    (dolist (item args result)
      (when (%> item result)
        (setf result item)))))
