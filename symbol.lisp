(in-package fol.symbol)

;;; Symbol type predicates
(defgeneric <symbol>? (obj) (:documentation "Returns T if OBJ is a FOL <symbol>."))
(defmethod <symbol>? (obj) (return-f))
(defmethod <symbol>? ((obj <symbol>)) (return-t))

(defgeneric <keyword>? (obj) (:documentation "Returns T if OBJ is a FOL <keyword>."))
(defmethod <keyword>? (obj) (return-f))
(defmethod <keyword>? ((obj <keyword>)) (return-t))

;;; Type conversion with as
(defgeneric as (type value)
  (:documentation "Convert VALUE to TYPE. Type is specified as a class symbol like '<symbol>, '<keyword>, or '<string>."))

;; String -> Symbol (auto-detects keywords if string starts with :)
(defmethod as ((type (eql '<symbol>)) (value <string>))
  "Convert a FOL string to a FOL symbol or keyword. Case-insensitive.
   If the string starts with ':', creates a keyword, otherwise creates a symbol."
  (let ((str (unwrap-string value)))
    (if (and (> (length str) 0) (char= (char str 0) #\:))
        ;; String starts with : - create keyword
        (wrap-symbol (intern (string-upcase (subseq str 1)) :keyword))
        ;; Regular symbol
        (wrap-symbol (intern (string-upcase str))))))

(defmethod as ((type (eql '<symbol>)) (value string))
  "Convert a native string to a FOL symbol or keyword. Case-insensitive.
   If the string starts with ':', creates a keyword, otherwise creates a symbol."
  (if (and (> (length value) 0) (char= (char value 0) #\:))
      ;; String starts with : - create keyword
      (wrap-symbol (intern (string-upcase (subseq value 1)) :keyword))
      ;; Regular symbol
      (wrap-symbol (intern (string-upcase value)))))

;; String -> Keyword (explicit keyword creation)
(defmethod as ((type (eql '<keyword>)) (value <string>))
  "Convert a FOL string to a FOL keyword. Case-insensitive.
   The leading ':' is optional and will be stripped if present."
  (let ((str (unwrap-string value)))
    (if (and (> (length str) 0) (char= (char str 0) #\:))
        ;; Strip leading : if present
        (wrap-symbol (intern (string-upcase (subseq str 1)) :keyword))
        ;; No leading :, use string as-is
        (wrap-symbol (intern (string-upcase str) :keyword)))))

(defmethod as ((type (eql '<keyword>)) (value string))
  "Convert a native string to a FOL keyword. Case-insensitive.
   The leading ':' is optional and will be stripped if present."
  (if (and (> (length value) 0) (char= (char value 0) #\:))
      ;; Strip leading : if present
      (wrap-symbol (intern (string-upcase (subseq value 1)) :keyword))
      ;; No leading :, use string as-is
      (wrap-symbol (intern (string-upcase value) :keyword))))

;; Symbol -> String
(defmethod as ((type (eql '<string>)) (value <symbol>))
  "Convert a FOL symbol to a FOL string. Returns lowercase name."
  (wrap-string (string-downcase (symbol-name (unwrap-symbol value)))))

(defmethod as ((type (eql '<string>)) (value symbol))
  "Convert a native symbol to a FOL string. Returns lowercase name."
  (wrap-string (string-downcase (symbol-name value))))

;; Keyword -> String (explicit method for clarity, though <keyword> is a <symbol>)
(defmethod as ((type (eql '<string>)) (value <keyword>))
  "Convert a FOL keyword to a FOL string. Returns lowercase name."
  (wrap-string (string-downcase (symbol-name (unwrap-symbol value)))))

;;; Print Object
(defmethod print-object ((obj <symbol>) stream)
  (let ((sym (unwrap-symbol obj))
        (mod-name (symbol-module-name obj)))
    (cond
      (mod-name
       (format stream "~A::~A" mod-name (symbol-name sym)))
      ((keywordp sym)
       (format stream ":~A" (symbol-name sym)))
      (t
       (format stream "~A" sym)))))

;;; Symbol operations

(defgeneric symbol-name-str (symbol)
  (:documentation "Returns the name of the symbol as a FOL <string>."))
(defmethod symbol-name-str ((sym <symbol>))
  (wrap-string (symbol-name (unwrap-symbol sym))))

(defgeneric symbol-package-str (symbol)
  (:documentation "Returns the package name of the symbol as a FOL <string>, or NIL if uninterned."))
(defmethod symbol-package-str ((sym <symbol>))
  (let ((pkg (symbol-package (unwrap-symbol sym))))
    (if pkg
        (wrap-string (package-name pkg))
        nil)))

;;; Symbol value operations

(defgeneric get-symbol-value (symbol)
  (:documentation "Returns the value associated with the symbol."))
(defmethod get-symbol-value ((sym <symbol>))
  (symbol-val sym))

(defgeneric set-symbol-value (symbol new-value)
  (:documentation "Sets the value associated with the symbol and returns a new symbol with the updated value."))
(defmethod set-symbol-value ((sym <symbol>) new-value)
  (fol.persistent:set-pslot-value sym 'value new-value))

;;; The +symbol-unbound-sentinel+ constant is defined in package.lisp

(defgeneric symbol-bound? (symbol)
  (:documentation "Returns T if the symbol has a value bound to it (non-nil)."))
(defmethod symbol-bound? ((sym <symbol>))
  (wrap-bool (not (eq  +symbol-unbound-sentinel+ (symbol-val sym)))))