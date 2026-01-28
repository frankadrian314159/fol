(in-package fol.char)

;;; ============================================================================
;;; Character Operations - Option 4 (Tagged Representation)
;;; ============================================================================
;;;
;;; All operations work transparently on both raw CL characters and wrapped
;;; FOL <char> objects. Results are returned as raw CL values.

;;; Character type predicates
(defgeneric <char>? (obj) (:documentation "Returns T if OBJ is a FOL <char> or raw character."))
(defmethod <char>? (obj) nil)
(defmethod <char>? ((obj <char>)) t)
(defmethod <char>? ((obj character)) t)


;;; --- Print Object ---

(defmethod print-object ((obj <char>) stream)
  "Print a character in readable format."
  (let ((c (fol-value obj)))
    (cond
      ;; Special characters with readable names
      ((cl:char= c #\Space)    (format stream "#\\Space"))
      ((cl:char= c #\Newline)  (format stream "#\\Newline"))
      ((cl:char= c #\Tab)      (format stream "#\\Tab"))
      ((cl:char= c #\Return)   (format stream "#\\Return"))
      ((cl:char= c #\Page)     (format stream "#\\Page"))
      ((cl:char= c #\Rubout)   (format stream "#\\Rubout"))
      ((cl:char= c #\Backspace)(format stream "#\\Backspace"))
      ;; Regular characters
      (t (format stream "#\\~C" c)))))


;;; --- Character Case Conversion ---

(defgeneric char-upcase (char)
  (:documentation "Returns the uppercase version of CHAR."))

(defmethod char-upcase ((char character))
  (cl:char-upcase char))

(defmethod char-upcase ((char <char>))
  (cl:char-upcase (fol-value char)))


(defgeneric char-downcase (char)
  (:documentation "Returns the lowercase version of CHAR."))

(defmethod char-downcase ((char character))
  (cl:char-downcase char))

(defmethod char-downcase ((char <char>))
  (cl:char-downcase (fol-value char)))


;;; --- Character Predicates ---

(defgeneric alpha-char? (char)
  (:documentation "Returns T if CHAR is an alphabetic character."))

(defmethod alpha-char? ((char character))
  (if (cl:alpha-char-p char) t nil))

(defmethod alpha-char? ((char <char>))
  (if (cl:alpha-char-p (fol-value char)) t nil))


(defgeneric digit-char? (char)
  (:documentation "Returns T if CHAR is a digit character (0-9)."))

(defmethod digit-char? ((char character))
  (if (cl:digit-char-p char) t nil))

(defmethod digit-char? ((char <char>))
  (if (cl:digit-char-p (fol-value char)) t nil))


(defgeneric alphanumeric? (char)
  (:documentation "Returns T if CHAR is alphanumeric."))

(defmethod alphanumeric? ((char character))
  (if (cl:alphanumericp char) t nil))

(defmethod alphanumeric? ((char <char>))
  (if (cl:alphanumericp (fol-value char)) t nil))


(defgeneric upper-case? (char)
  (:documentation "Returns T if CHAR is uppercase."))

(defmethod upper-case? ((char character))
  (if (cl:upper-case-p char) t nil))

(defmethod upper-case? ((char <char>))
  (if (cl:upper-case-p (fol-value char)) t nil))


(defgeneric lower-case? (char)
  (:documentation "Returns T if CHAR is lowercase."))

(defmethod lower-case? ((char character))
  (if (cl:lower-case-p char) t nil))

(defmethod lower-case? ((char <char>))
  (if (cl:lower-case-p (fol-value char)) t nil))


(defgeneric whitespace? (char)
  (:documentation "Returns T if CHAR is a whitespace character."))

(defmethod whitespace? ((char character))
  (if (or (cl:char= char #\Space)
          (cl:char= char #\Tab)
          (cl:char= char #\Newline)
          (cl:char= char #\Return)
          (cl:char= char #\Linefeed)
          (cl:char= char #\Page))
      t nil))

(defmethod whitespace? ((char <char>))
  (whitespace? (fol-value char)))


;;; --- Character Name ---

(defun capitalize-name (name)
  "Capitalize a name: first letter uppercase, rest lowercase."
  (when name
    (concatenate 'string
                 (string (cl:char-upcase (char name 0)))
                 (string-downcase (subseq name 1)))))

(defgeneric char-name-string (char)
  (:documentation "Returns the name of the character as a capitalized string, or NIL if the character has no name.
For example: (char-name-string #\\Space) => \"Space\"
             (char-name-string #\\Newline) => \"Newline\"
             (char-name-string #\\a) => NIL"))

(defun named-char-p (char)
  "Returns T if CHAR should have a name returned by char-name-string.
   This follows Clojure's convention: special characters like space, newline,
   tab, return, page (formfeed), and backspace have names; regular printable
   characters (letters, digits, punctuation) do not."
  (or (not (cl:graphic-char-p char))  ; Non-graphic chars (control chars, etc.)
      (cl:char= char #\Space)))       ; Space is graphic but should have a name

(defmethod char-name-string ((char character))
  ;; Return names for special characters: non-graphic chars plus space
  ;; Regular printable characters (letters, digits, punctuation) return nil
  (if (named-char-p char)
      (capitalize-name (cl:char-name char))
      nil))

(defmethod char-name-string ((char <char>))
  (char-name-string (fol-value char)))
