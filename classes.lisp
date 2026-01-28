(in-package fol.classes)

;;; ============================================================================
;;; FOL Value Classes
;;; ============================================================================
;;; Inherit directly from <persistent-object> to avoid circular dependency
;;; with fol.collection.

;;; --- Boolean Classes ---

(defclass <bool> (fol.persistent:<persistent-object>)
  ((val :initarg :val :accessor -fol-value :type boolean))
  (:metaclass fol.persistent:persistent-class)
  (:documentation "The base boolean class holding a native Lisp boolean."))


;;; --- Character Classes ---

(defclass <char> (fol.persistent:<persistent-object>)
  ((val :initarg :val :accessor -fol-value :type character))
  (:metaclass fol.persistent:persistent-class)
  (:documentation "The character class holding a native Lisp character."))

;;; --- String Class ---

(defclass <string> (fol.persistent:<persistent-object>)
  ((val :initarg :val :accessor -fol-value :type string))
  (:metaclass fol.persistent:persistent-class)
  (:documentation "The string class holding a native Lisp string."))

;;; --- Regular Expression Pattern Class ---

(defclass <re-pattern> (<string>)
  ()
  (:metaclass fol.persistent:persistent-class)
  (:documentation "A regular expression pattern. Inherits from <string> and holds the pattern string."))

;;; --- Regular Expression Scanner Class ---
;;; Note: Scanner class is NOT a persistent object because it holds a compiled
;;; scanner function which is inherently mutable/stateful.

(defclass <re-scanner> ()
  ((val :initarg :val :accessor -fol-value :type <re-pattern>
        :documentation "The <re-pattern> from which this scanner was created.")
   (scanner :initarg :scanner :accessor scanner-function :type function
            :documentation "The compiled scanner function from CL-PPCRE.")
   (register-names :initarg :register-names :accessor scanner-register-names
                   :documentation "A <vector> of register names for named groups."))
  (:documentation "A compiled regular expression scanner wrapping CL-PPCRE's scanner."))

;;; --- Symbol Class ---

(defclass <symbol> (<string>)
  ((val :initarg :val :accessor -fol-value :type symbol)
   (module-name :initarg :module-name :accessor symbol-module-name :initform nil :type (or null string))
   (value :initarg :value :accessor symbol-val :initform fol.symbol:+symbol-unbound-sentinel+ :type t))
  (:metaclass fol.persistent:persistent-class)
  (:documentation "The symbol class holding a native Lisp symbol, its module name, and an associated value."))

(defclass <keyword> (<symbol>)
  ()
  (:metaclass fol.persistent:persistent-class)
  (:documentation "The keyword class for Lisp keywords. Inherits all functionality from <symbol>."))

;;; --- Number Classes ---

(defclass <number> (fol.persistent:<persistent-object>) 
  ((val :initarg :val :accessor -fol-value :type number))
  (:metaclass fol.persistent:persistent-class)
  (:documentation "The base number class."))

(defclass <complex> (<number>) 
  nil 
  (:metaclass fol.persistent:persistent-class)
  (:documentation "The complex number class."))

(defclass <real> (<number>) 
  nil 
  (:metaclass fol.persistent:persistent-class)
  (:documentation "The real number class."))

(defclass <float> (<real>) 
  nil 
  (:metaclass fol.persistent:persistent-class)
  (:documentation "The float number class."))

(defclass <single-float> (<float>) 
  nil 
  (:metaclass fol.persistent:persistent-class)
  (:documentation "The single-float number class."))

(defclass <double-float> (<float>) 
  nil 
  (:metaclass fol.persistent:persistent-class)
  (:documentation "The double-float number class."))

(defclass <rational> (<real>) 
  nil 
  (:metaclass fol.persistent:persistent-class)
  (:documentation "The rational number class."))

(defclass <ratio> (<rational>) 
  nil 
  (:metaclass fol.persistent:persistent-class)
  (:documentation "The ratio number class."))

(defclass <integer> (<rational>) 
  nil 
  (:metaclass fol.persistent:persistent-class)
  (:documentation "The integer number class."))

(defclass <fixnum> (<integer>) 
  nil 
  (:metaclass fol.persistent:persistent-class)
  (:documentation "The fixnum number class."))

(defclass <bignum> (<integer>)
  nil
  (:metaclass fol.persistent:persistent-class)
  (:documentation "The bignum number class."))

;;; --- UUID Class ---

(defclass <uuid> (fol.persistent:<persistent-object>)
  ((val :initarg :val :accessor -fol-value :type uuid:uuid))
  (:metaclass fol.persistent:persistent-class)
  (:documentation "A UUID (Universally Unique Identifier) wrapping the uuid library's UUID object."))

;;; --- Stream Classes ---
;;; Note: Stream classes are NOT persistent objects because streams are inherently
;;; mutable and stateful. They use standard CLOS classes.

(defclass <stream> ()
  ((val :initarg :val :accessor -fol-value :type (or null stream)
        :documentation "The underlying CL stream, or NIL if not yet opened.")
   (open-p :initarg :open-p :accessor stream-open-p :initform nil :type boolean
           :documentation "Whether the stream is currently open."))
  (:documentation "The base stream class wrapping a native Lisp stream."))

(defclass <input-stream> (<stream>)
  ()
  (:documentation "Base class for input streams."))

(defclass <output-stream> (<stream>)
  ()
  (:documentation "Base class for output streams."))

(defclass <string-input-stream> (<input-stream>)
  ((source-string :initarg :source-string :accessor stream-source-string :type string
                  :documentation "The string to read from."))
  (:documentation "An input stream that reads from a string."))

(defclass <file-input-stream> (<input-stream>)
  ((file-path :initarg :file-path :accessor stream-file-path :type string
              :documentation "The path to the file to read from."))
  (:documentation "An input stream that reads from a file."))

(defclass <string-output-stream> (<output-stream>)
  ()
  (:documentation "An output stream that writes to a string."))

(defclass <file-output-stream> (<output-stream>)
  ((file-path :initarg :file-path :accessor stream-file-path :type string
              :documentation "The path to the file to write to."))
  (:documentation "An output stream that writes to a file."))

