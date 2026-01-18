(in-package fol.char)





;; Character type predicates
(defgeneric <char>? (obj) (:documentation "Returns T if OBJ is a FOL <char>."))
(defmethod <char>? (obj) (return-f))
(defmethod <char>? ((obj <char>)) (return-t))





;;; --- Print Object ---

(defmethod print-object ((obj <char>) stream)
  "Print a character in readable format."
  (let ((c (unwrap-char obj)))
    (cond
      ;; Special characters with readable names
      ((cl:char= c #\Space)    (format stream "#\\Space"))
      ((cl:char= c #\Newline)  (format stream "#\\Newline"))
      ((cl:char= c #\Tab)      (format stream "#\\Tab"))
      ((cl:char= c #\Return)   (format stream "#\\Return"))
      ;((cl:char= c #\Linefeed) (format stream "#\\Linefeed"))
      ((cl:char= c #\Page)     (format stream "#\\Page"))
      ((cl:char= c #\Rubout)   (format stream "#\\Rubout"))
      ((cl:char= c #\Backspace)(format stream "#\\Backspace"))
      ;; Regular characters
      (t (format stream "#\\~C" c)))))





;;; --- Character Case Conversion ---

(defgeneric char-upcase (char)
  (:documentation "Returns the uppercase version of CHAR."))
(defmethod char-upcase ((char <char>))
  (wrap (cl:char-upcase (unwrap char))))

(defgeneric char-downcase (char)
  (:documentation "Returns the lowercase version of CHAR."))
(defmethod char-downcase ((char <char>))
  (wrap (cl:char-downcase (unwrap char))))


;;; --- Character Predicates ---

(defgeneric alpha-char? (char)
  (:documentation "Returns #t if CHAR is an alphabetic character."))
(defmethod alpha-char? ((char <char>))
  (wrap (cl:alpha-char-p (unwrap char))))

(defgeneric digit-char? (char)
  (:documentation "Returns #t if CHAR is a digit character (0-9)."))
(defmethod digit-char? ((char <char>))
  (wrap (cl:digit-char-p (unwrap char))))

(defgeneric alphanumeric? (char)
  (:documentation "Returns #t if CHAR is alphanumeric."))
(defmethod alphanumeric? ((char <char>))
  (wrap (cl:alphanumericp (unwrap char))))

(defgeneric upper-case? (char)
  (:documentation "Returns #t if CHAR is uppercase."))
(defmethod upper-case? ((char <char>))
  (wrap (cl:upper-case-p (unwrap char))))

(defgeneric lower-case? (char)
  (:documentation "Returns #t if CHAR is lowercase."))
(defmethod lower-case? ((char <char>))
  (wrap (cl:lower-case-p (unwrap char))))

(defgeneric whitespace? (char)
  (:documentation "Returns #t if CHAR is a whitespace character."))
(defmethod whitespace? ((char <char>))
  (let ((c (unwrap char)))
    (wrap (or (cl:char= c #\Space)
              (cl:char= c #\Tab)
              (cl:char= c #\Newline)
              (cl:char= c #\Return)
              (cl:char= c #\Linefeed)
              (cl:char= c #\Page)))))