;;; FOL Compiler - Streams
;;;
;;; Stream class hierarchy wrapping Common Lisp streams with a FOL-friendly
;;; interface.  All stream classes use standard-object (mutable, not persistent).
;;;
;;; Base classes:
;;;   <input-stream>   — wraps a CL input stream
;;;   <output-stream>  — wraps a CL output stream
;;;   <string-base>    — mixin holding a string
;;;   <file-base>      — mixin holding filename + file object
;;;   <socket-base>    — mixin holding URL + socket
;;;
;;; Concrete classes (multiple inheritance):
;;;   <string-input-stream>   = <input-stream>  + <string-base>
;;;   <string-output-stream>  = <output-stream> + <string-base>
;;;   <file-input-stream>     = <input-stream>  + <file-base>
;;;   <file-output-stream>    = <output-stream> + <file-base>
;;;   <socket-input-stream>   = <input-stream>  + <socket-base>
;;;   <socket-output-stream>  = <output-stream> + <socket-base>

(in-package :fol.compiler.streams)

;;; =========================================================================
;;; Base Classes
;;; =========================================================================

(defclass <input-stream> (standard-object)
  ((stream :initarg :stream
           :initform nil
           :accessor input-stream-stream
           :documentation "The underlying CL input stream."))
  (:documentation "Base class for FOL input streams wrapping a CL input stream."))

(defclass <output-stream> (standard-object)
  ((stream :initarg :stream
           :initform nil
           :accessor output-stream-stream
           :documentation "The underlying CL output stream."))
  (:documentation "Base class for FOL output streams wrapping a CL output stream."))

;;; =========================================================================
;;; Mixin Classes
;;; =========================================================================

(defclass <string-base> ()
  ((string :initarg :string
           :initform ""
           :accessor string-base-string
           :documentation "The string from which a stream reads or to which it writes."))
  (:documentation "Mixin for string-backed streams."))

(defclass <file-base> ()
  ((filename :initarg :filename
             :initform nil
             :accessor file-base-filename
             :documentation "The pathname or filename string.")
   (file-object :initarg :file-object
                :initform nil
                :accessor file-base-file-object
                :documentation "The underlying CL file stream object."))
  (:documentation "Mixin for file-backed streams."))

(defclass <socket-base> ()
  ((url :initarg :url
        :initform nil
        :accessor socket-base-url
        :documentation "The URL or hostname for the socket connection.")
   (socket :initarg :socket
           :initform nil
           :accessor socket-base-socket
           :documentation "The underlying usocket socket object."))
  (:documentation "Mixin for socket-backed streams."))

;;; =========================================================================
;;; Concrete Classes
;;; =========================================================================

(defclass <string-input-stream> (<input-stream> <string-base>)
  ()
  (:documentation "An input stream that reads from a string."))

(defclass <string-output-stream> (<output-stream> <string-base>)
  ()
  (:documentation "An output stream that writes to a string."))

(defclass <file-input-stream> (<input-stream> <file-base>)
  ()
  (:documentation "An input stream that reads from a file."))

(defclass <file-output-stream> (<output-stream> <file-base>)
  ()
  (:documentation "An output stream that writes to a file."))

(defclass <socket-input-stream> (<input-stream> <socket-base>)
  ()
  (:documentation "An input stream that reads from a socket."))

(defclass <socket-output-stream> (<output-stream> <socket-base>)
  ()
  (:documentation "An output stream that writes to a socket."))

;;; =========================================================================
;;; Type Predicates
;;; =========================================================================

(defun <input-stream>? (obj)
  "Return T if OBJ is an input stream."
  (typep obj '<input-stream>))

(defun <output-stream>? (obj)
  "Return T if OBJ is an output stream."
  (typep obj '<output-stream>))

(defun <string-input-stream>? (obj)
  "Return T if OBJ is a string input stream."
  (typep obj '<string-input-stream>))

(defun <string-output-stream>? (obj)
  "Return T if OBJ is a string output stream."
  (typep obj '<string-output-stream>))

(defun <file-input-stream>? (obj)
  "Return T if OBJ is a file input stream."
  (typep obj '<file-input-stream>))

(defun <file-output-stream>? (obj)
  "Return T if OBJ is a file output stream."
  (typep obj '<file-output-stream>))

(defun <socket-input-stream>? (obj)
  "Return T if OBJ is a socket input stream."
  (typep obj '<socket-input-stream>))

(defun <socket-output-stream>? (obj)
  "Return T if OBJ is a socket output stream."
  (typep obj '<socket-output-stream>))

;;; =========================================================================
;;; Constructor Functions
;;; =========================================================================

(defun string-input-stream (string)
  "Create a new string input stream that reads from STRING."
  (make-instance '<string-input-stream>
                 :stream (make-string-input-stream string)
                 :string string))

(defun string-output-stream ()
  "Create a new string output stream.
   Use get-output-string to retrieve the accumulated string."
  (let ((cl-stream (make-string-output-stream)))
    (make-instance '<string-output-stream>
                   :stream cl-stream
                   :string "")))

(defun file-input-stream (filename)
  "Create a new file input stream that reads from FILENAME."
  (let ((cl-stream (open filename :direction :input)))
    (make-instance '<file-input-stream>
                   :stream cl-stream
                   :filename (namestring filename)
                   :file-object cl-stream)))

(defun file-output-stream (filename &key (if-exists :supersede))
  "Create a new file output stream that writes to FILENAME.
   :if-exists controls behavior when file already exists (default :supersede)."
  (let ((cl-stream (open filename :direction :output :if-exists if-exists)))
    (make-instance '<file-output-stream>
                   :stream cl-stream
                   :filename (namestring filename)
                   :file-object cl-stream)))

(defun socket-input-stream (host port)
  "Create a new socket input stream connected to HOST:PORT."
  (let* ((sock (usocket:socket-connect host port))
         (cl-stream (usocket:socket-stream sock)))
    (make-instance '<socket-input-stream>
                   :stream cl-stream
                   :url (format nil "~A:~A" host port)
                   :socket sock)))

(defun socket-output-stream (host port)
  "Create a new socket output stream connected to HOST:PORT."
  (let* ((sock (usocket:socket-connect host port))
         (cl-stream (usocket:socket-stream sock)))
    (make-instance '<socket-output-stream>
                   :stream cl-stream
                   :url (format nil "~A:~A" host port)
                   :socket sock)))

;;; =========================================================================
;;; Protocol — Generic Functions
;;; =========================================================================

(defgeneric stream-read-char (s)
  (:documentation "Read a single character from input stream S.
   Returns the character, or NIL at end of stream."))

(defgeneric stream-read-line (s)
  (:documentation "Read a line from input stream S.
   Returns the line as a string (without the newline).
   Second value is T if end-of-file was reached."))

(defgeneric stream-write-char (s ch)
  (:documentation "Write character CH to output stream S. Returns CH."))

(defgeneric stream-write-string (s str)
  (:documentation "Write string STR to output stream S. Returns STR."))

(defgeneric stream-write-line (s str)
  (:documentation "Write string STR followed by a newline to output stream S. Returns STR."))

(defgeneric stream-close (s)
  (:documentation "Close stream S. Returns T."))

(defgeneric stream-flush (s)
  (:documentation "Flush any buffered output on stream S. Returns T."))

(defgeneric get-output-string (s)
  (:documentation "Return the accumulated string from a string output stream."))

;;; =========================================================================
;;; Protocol — Input Methods
;;; =========================================================================

(defmethod stream-read-char ((s <input-stream>))
  "Read a character from the underlying CL input stream."
  (read-char (input-stream-stream s) nil nil))

(defmethod stream-read-line ((s <input-stream>))
  "Read a line from the underlying CL input stream."
  (read-line (input-stream-stream s) nil nil))

;;; =========================================================================
;;; Protocol — Output Methods
;;; =========================================================================

(defmethod stream-write-char ((s <output-stream>) ch)
  "Write a character to the underlying CL output stream."
  (write-char ch (output-stream-stream s))
  ch)

(defmethod stream-write-string ((s <output-stream>) str)
  "Write a string to the underlying CL output stream."
  (write-string str (output-stream-stream s))
  str)

(defmethod stream-write-line ((s <output-stream>) str)
  "Write a string followed by a newline to the underlying CL output stream."
  (write-line str (output-stream-stream s))
  str)

(defmethod stream-flush ((s <output-stream>))
  "Flush buffered output."
  (force-output (output-stream-stream s))
  t)

;;; =========================================================================
;;; Protocol — Close Methods
;;; =========================================================================

(defmethod stream-close ((s <input-stream>))
  "Close the underlying CL input stream."
  (close (input-stream-stream s))
  t)

(defmethod stream-close ((s <output-stream>))
  "Close the underlying CL output stream."
  (close (output-stream-stream s))
  t)

(defmethod stream-close ((s <socket-input-stream>))
  "Close the socket input stream and its underlying socket."
  (close (input-stream-stream s))
  (usocket:socket-close (socket-base-socket s))
  t)

(defmethod stream-close ((s <socket-output-stream>))
  "Close the socket output stream and its underlying socket."
  (close (output-stream-stream s))
  (usocket:socket-close (socket-base-socket s))
  t)

;;; =========================================================================
;;; Protocol — String Output Stream
;;; =========================================================================

(defmethod get-output-string ((s <string-output-stream>))
  "Return the accumulated string from a string output stream."
  (cl:get-output-stream-string (output-stream-stream s)))

;;; =========================================================================
;;; Printer Methods
;;; =========================================================================

(defmethod print-object ((obj <string-input-stream>) stream)
  (print-unreadable-object (obj stream :type nil)
    (format stream "STRING-INPUT-STREAM")))

(defmethod print-object ((obj <string-output-stream>) stream)
  (print-unreadable-object (obj stream :type nil)
    (format stream "STRING-OUTPUT-STREAM")))

(defmethod print-object ((obj <file-input-stream>) stream)
  (print-unreadable-object (obj stream :type nil)
    (format stream "FILE-INPUT-STREAM ~S" (file-base-filename obj))))

(defmethod print-object ((obj <file-output-stream>) stream)
  (print-unreadable-object (obj stream :type nil)
    (format stream "FILE-OUTPUT-STREAM ~S" (file-base-filename obj))))

(defmethod print-object ((obj <socket-input-stream>) stream)
  (print-unreadable-object (obj stream :type nil)
    (format stream "SOCKET-INPUT-STREAM ~A" (socket-base-url obj))))

(defmethod print-object ((obj <socket-output-stream>) stream)
  (print-unreadable-object (obj stream :type nil)
    (format stream "SOCKET-OUTPUT-STREAM ~A" (socket-base-url obj))))

;;; =========================================================================
;;; Global Dynamic Variables
;;; =========================================================================

(defvar *in*
  (make-instance '<file-input-stream>
                 :stream *standard-input*
                 :filename "stdin"
                 :file-object *standard-input*)
  "The default input stream, bound to standard input.")

(defvar *out*
  (make-instance '<file-output-stream>
                 :stream *standard-output*
                 :filename "stdout"
                 :file-object *standard-output*)
  "The default output stream, bound to standard output.")

(defvar *err*
  (make-instance '<file-output-stream>
                 :stream *error-output*
                 :filename "stderr"
                 :file-object *error-output*)
  "The default error stream, bound to standard error.")
