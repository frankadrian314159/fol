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
(defmethod <symbol>? ((obj cl:symbol)) t)

(defgeneric <keyword>? (obj) (:documentation "Returns T if OBJ is a FOL <keyword> or raw keyword."))
(defmethod <keyword>? (obj) nil)
(defmethod <keyword>? ((obj <keyword>)) t)
(defmethod <keyword>? ((obj cl:symbol))
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

(defmethod as ((type (eql '<string>)) (value cl:symbol))
  "Convert a native symbol to a FOL string. Returns lowercase name."
  (wrap-string (string-downcase (symbol-name value))))

;; Keyword -> String (explicit method for clarity, though <keyword> is a <symbol>)
(defmethod as ((type (eql '<string>)) (value <keyword>))
  "Convert a FOL keyword to a FOL string. Returns lowercase name."
  (wrap-string (string-downcase (symbol-name (fol-value value)))))

;;; ============================================================================
;;; Keyword Constructor Function
;;; ============================================================================

(defgeneric keyword (name)
  (:documentation "Creates a keyword from NAME.
   NAME can be a string, symbol, or keyword.
   The leading ':' is stripped if present in strings.
   Returns a CL keyword symbol."))

(defmethod keyword ((name string))
  "Create a keyword from a string. Leading ':' is stripped if present."
  (let ((str (if (and (> (length name) 0) (char= (char name 0) #\:))
                 (subseq name 1)
                 name)))
    (intern (string-upcase str) :keyword)))

(defmethod keyword ((name <string>))
  "Create a keyword from a FOL string."
  (keyword (fol-value name)))

(defmethod keyword ((name cl:symbol))
  "Create a keyword from a symbol. If already a keyword, returns it unchanged."
  (if (keywordp name)
      name
      (intern (symbol-name name) :keyword)))

(defmethod keyword ((name <symbol>))
  "Create a keyword from a FOL symbol."
  (keyword (fol-value name)))

(defmethod keyword ((name <keyword>))
  "A keyword passed to keyword returns the underlying keyword."
  (fol-value name))

;;; ============================================================================
;;; Find-Keyword Function
;;; ============================================================================

(defgeneric find-keyword (name)
  (:documentation "Finds a keyword with NAME if it exists.
   NAME can be a string, symbol, or keyword.
   The leading ':' is stripped if present in strings.
   Returns the keyword if found, or NIL if not found."))

(defmethod find-keyword ((name string))
  "Find a keyword from a string. Leading ':' is stripped if present."
  (let ((str (if (and (> (length name) 0) (char= (char name 0) #\:))
                 (subseq name 1)
                 name)))
    (find-symbol (string-upcase str) :keyword)))

(defmethod find-keyword ((name <string>))
  "Find a keyword from a FOL string."
  (find-keyword (fol-value name)))

(defmethod find-keyword ((name cl:symbol))
  "Find a keyword from a symbol name. If already a keyword, returns it."
  (if (keywordp name)
      name
      (find-symbol (symbol-name name) :keyword)))

(defmethod find-keyword ((name <symbol>))
  "Find a keyword from a FOL symbol."
  (find-keyword (fol-value name)))

(defmethod find-keyword ((name <keyword>))
  "A keyword passed to find-keyword returns the underlying keyword."
  (fol-value name))

;;; ============================================================================
;;; Symbol Constructor Function
;;; ============================================================================

(defun %get-name-string (name func-name)
  "Extract the name string from NAME (string, <string>, symbol, or <symbol>)."
  (typecase name
    (string name)
    (<string> (fol-value name))
    (cl:keyword (cl:symbol-name name))
    (<keyword> (cl:symbol-name (fol-value name)))
    (cl:symbol (cl:symbol-name name))
    (<symbol> (cl:symbol-name (fol-value name)))
    (t (error "~A requires a string or symbol for name, got ~A" func-name (type-of name)))))

(defun symbol (name &optional module)
  "Creates a symbol from NAME and interns it in a module.

   If MODULE is not provided:
     Creates a symbol from NAME and interns it in the current module
     (or default module if *current-module* is nil).

   If MODULE is provided:
     NAME is the module name, MODULE is the symbol name.
     Creates a symbol from MODULE and interns it in the module named by NAME.

   Returns a FOL <symbol> with the module-name slot set appropriately."
  (let* ((actual-name (if module
                          (%get-name-string module "SYMBOL")
                          (%get-name-string name "SYMBOL")))
         (actual-module (if module
                            (%get-name-string name "SYMBOL")
                            (or *current-module* +default-module+)))
         ;; Create the underlying CL symbol
         (cl-symbol (make-symbol (string-upcase actual-name))))
    ;; Create the FOL <symbol> wrapper with module-name set
    (make-instance '<symbol>
                   :val cl-symbol
                   :module-name actual-module)))

;;; ============================================================================
;;; Gensym Function
;;; ============================================================================

(defvar *fol-gensym-counter* 0
  "Counter for generating unique gensym names.")

(defun gensym (&optional prefix module)
  "Creates a unique symbol with an auto-generated name.

   (gensym)
     Name is G__###. Interned in the current module.

   (gensym prefix)
     Name is PREFIX__###. Interned in the current module.

   (gensym prefix module)
     Name is MODULE__###. Interned in the module named by PREFIX.

   (gensym nil module)
     Name is MODULE__###. Not interned in any module (module-name is NIL)."
  (let ((count (incf *fol-gensym-counter*)))
    (cond
      ;; Case 1: No arguments - G__###, intern in current module
      ((and (null prefix) (null module))
       (let* ((name (format nil "G__~D" count))
              (actual-module (or *current-module* +default-module+))
              (cl-symbol (make-symbol (string-upcase name))))
         (make-instance '<symbol>
                        :val cl-symbol
                        :module-name actual-module)))

      ;; Case 4: prefix is nil, module present - MODULE__###, not interned
      ((and (null prefix) module)
       (let* ((mod-str (%get-name-string module "GENSYM"))
              (name (format nil "~A__~D" (string-upcase mod-str) count))
              (cl-symbol (make-symbol name)))
         (make-instance '<symbol>
                        :val cl-symbol
                        :module-name nil)))

      ;; Case 2: prefix present, no module - PREFIX__###, intern in current module
      ((and prefix (null module))
       (let* ((prefix-str (%get-name-string prefix "GENSYM"))
              (name (format nil "~A__~D" (string-upcase prefix-str) count))
              (actual-module (or *current-module* +default-module+))
              (cl-symbol (make-symbol name)))
         (make-instance '<symbol>
                        :val cl-symbol
                        :module-name actual-module)))

      ;; Case 3: both present - MODULE__###, intern in module named by prefix
      (t
       (let* ((mod-str (%get-name-string module "GENSYM"))
              (prefix-str (%get-name-string prefix "GENSYM"))
              (name (format nil "~A__~D" (string-upcase mod-str) count))
              (cl-symbol (make-symbol name)))
         (make-instance '<symbol>
                        :val cl-symbol
                        :module-name prefix-str))))))

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

(defmethod symbol-name-str ((sym cl:symbol))
  (symbol-name sym))

(defmethod symbol-name-str ((sym <symbol>))
  (symbol-name (fol-value sym)))


(defgeneric symbol-package-str (symbol)
  (:documentation "Returns the package name of the symbol as a string, or NIL if uninterned."))

(defmethod symbol-package-str ((sym cl:symbol))
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
