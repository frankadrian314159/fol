(in-package fol.symbol)

;;; ============================================================================
;;; Symbol Operations - Option 4 (Tagged Representation)
;;; ============================================================================
;;;
;;; Type predicates and operations work on both raw CL symbols and wrapped
;;; FOL <symbol> objects. Results are returned as raw CL values where appropriate.

;;; ============================================================================
;;; Module Constants and Current Module Tracking
;;; ============================================================================

(defparameter +keyword-module+ "%keyword"
  "The name of the special module where all keywords are interned.")

(defparameter +default-module+ "fol-user"
  "The name of the default module for user symbols.")

(defvar *current-module* nil
  "The current module name (string) for symbol interning during reading.
   When NIL, defaults to +default-module+ (fol-user).")

;;; ============================================================================
;;; Symbol Interning
;;; ============================================================================

(defun parse-qualified-name (name)
  "Parse a potentially module-qualified name string.
   Returns two values: (module-name symbol-name)

   Examples:
     \"foo\"           -> (NIL \"foo\")
     \":bar\"          -> (\"%keyword\" \"bar\")
     \"mymod/baz\"     -> (\"mymod\" \"baz\")
     \"mymod::qux\"    -> (\"mymod\" \"qux\")

   The module separator can be / (Clojure-style) or :: (CL-style)."
  (let ((len (length name)))
    (cond
      ;; Empty string
      ((= len 0)
       (values nil ""))

      ;; Keyword - starts with :
      ((char= (char name 0) #\:)
       (values +keyword-module+ (subseq name 1)))

      ;; Check for / separator (Clojure-style)
      (t
       (let ((slash-pos (position #\/ name)))
         (if slash-pos
             (values (subseq name 0 slash-pos)
                     (subseq name (1+ slash-pos)))
             ;; Check for :: separator (CL-style)
             (let ((colon-pos (search "::" name)))
               (if colon-pos
                   (values (subseq name 0 colon-pos)
                           (subseq name (+ colon-pos 2)))
                   ;; No module qualifier
                   (values nil name)))))))))

(defun fol-intern (name &optional module-name)
  "Intern a string NAME as a FOL symbol in the appropriate module.

   Parameters:
   - NAME: A string representing the symbol name. May include module qualifier:
           - \":foo\" - keyword, interned in %keyword module
           - \"mod/foo\" - symbol foo in module mod (Clojure-style)
           - \"mod::foo\" - symbol foo in module mod (CL-style)
           - \"foo\" - symbol in MODULE-NAME or current/default module
   - MODULE-NAME: Optional module name (string) to use if NAME is unqualified.
                  If NIL, uses *current-module* or +default-module+.

   Returns:
   A FOL <symbol> or <keyword> instance with the appropriate module-name set.

   Module resolution order:
   1. If NAME starts with ':', use %keyword module
   2. If NAME contains module qualifier (/ or ::), use that module
   3. If MODULE-NAME is provided, use that
   4. If *current-module* is set, use that
   5. Otherwise use +default-module+ (fol-user)

   Examples:
     (fol-intern \":foo\")         -> <keyword> FOO in %keyword
     (fol-intern \"bar\")          -> <symbol> BAR in fol-user (default)
     (fol-intern \"bar\" \"mymod\") -> <symbol> BAR in mymod
     (fol-intern \"mod/baz\")      -> <symbol> BAZ in mod
     (fol-intern \"mod::qux\")     -> <symbol> QUX in mod"
  (multiple-value-bind (parsed-module symbol-name) (parse-qualified-name name)
    (let* ((final-module (or parsed-module
                             module-name
                             *current-module*
                             +default-module+))
           (is-keyword (string= final-module +keyword-module+))
           ;; Create the underlying CL symbol
           (cl-symbol (if is-keyword
                          (intern (string-upcase symbol-name) :keyword)
                          (make-symbol (string-upcase symbol-name))))
           ;; Create the FOL wrapper
           (fol-class (if is-keyword '<keyword> '<symbol>)))
      (make-instance fol-class
                     :val cl-symbol
                     :module-name final-module))))

;;; Symbol type predicates
(defgeneric <symbol>? (obj) (:documentation "Returns T if OBJ is a FOL <symbol> or raw symbol."))
(defmethod <symbol>? (obj) nil)
(defmethod <symbol>? ((obj <symbol>)) t)
(defmethod <symbol>? ((obj symbol)) t)

(defgeneric <keyword>? (obj) (:documentation "Returns T if OBJ is a FOL <keyword> or raw keyword."))
(defmethod <keyword>? (obj) nil)
(defmethod <keyword>? ((obj <keyword>)) t)
(defmethod <keyword>? ((obj symbol))
  (keywordp obj))

;;; Type conversion with as
(defgeneric as (type value)
  (:documentation "Convert VALUE to TYPE. Type is specified as a class symbol like '<symbol>, '<keyword>, or '<string>."))

;; String -> Symbol (auto-detects keywords if string starts with :)
(defmethod as ((type (eql '<symbol>)) (value <string>))
  "Convert a FOL string to a FOL symbol or keyword. Case-insensitive.
   If the string starts with ':', creates a keyword, otherwise creates a symbol."
  (let ((str (fol-value value)))
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
  (let ((str (fol-value value)))
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
  (wrap-string (string-downcase (symbol-name (fol-value value)))))

(defmethod as ((type (eql '<string>)) (value symbol))
  "Convert a native symbol to a FOL string. Returns lowercase name."
  (wrap-string (string-downcase (symbol-name value))))

;; Keyword -> String (explicit method for clarity, though <keyword> is a <symbol>)
(defmethod as ((type (eql '<string>)) (value <keyword>))
  "Convert a FOL keyword to a FOL string. Returns lowercase name."
  (wrap-string (string-downcase (symbol-name (fol-value value)))))

;;; Print Object
(defmethod print-object ((obj <symbol>) stream)
  (let ((sym (fol-value obj))
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
  (:documentation "Returns the name of the symbol as a string."))

(defmethod symbol-name-str ((sym symbol))
  (symbol-name sym))

(defmethod symbol-name-str ((sym <symbol>))
  (symbol-name (fol-value sym)))


(defgeneric symbol-package-str (symbol)
  (:documentation "Returns the package name of the symbol as a string, or NIL if uninterned."))

(defmethod symbol-package-str ((sym symbol))
  (let ((pkg (symbol-package sym)))
    (if pkg (package-name pkg) nil)))

(defmethod symbol-package-str ((sym <symbol>))
  (let ((pkg (symbol-package (fol-value sym))))
    (if pkg (package-name pkg) nil)))


;;; Symbol value operations (only for wrapped symbols which have the value slot)

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
  (:documentation "Returns T if the symbol has a value bound to it."))

(defmethod symbol-bound? ((sym <symbol>))
  (not (eq +symbol-unbound-sentinel+ (symbol-val sym))))
