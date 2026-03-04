(in-package fol.stream)

;;; ============================================================================
;;; FOL Stream Operations
;;; ============================================================================
;;; This module provides stream classes and operations for I/O in FOL.
;;; Streams wrap CL streams and provide a functional interface.

;;; ============================================================================
;;; Type Predicates
;;; ============================================================================

(defun <stream>? (obj)
  "Return T if OBJ is a FOL stream."
  (typep obj 'fol.classes:<stream>))

(defun <input-stream>? (obj)
  "Return T if OBJ is a FOL input stream."
  (typep obj 'fol.classes:<input-stream>))

(defun <output-stream>? (obj)
  "Return T if OBJ is a FOL output stream."
  (typep obj 'fol.classes:<output-stream>))

(defun <string-input-stream>? (obj)
  "Return T if OBJ is a FOL string input stream."
  (typep obj 'fol.classes:<string-input-stream>))

(defun <file-input-stream>? (obj)
  "Return T if OBJ is a FOL file input stream."
  (typep obj 'fol.classes:<file-input-stream>))

(defun <string-output-stream>? (obj)
  "Return T if OBJ is a FOL string output stream."
  (typep obj 'fol.classes:<string-output-stream>))

(defun <file-output-stream>? (obj)
  "Return T if OBJ is a FOL file output stream."
  (typep obj 'fol.classes:<file-output-stream>))

;;; ============================================================================
;;; Constructors
;;; ============================================================================

(defun make-string-input-stream (string)
  "Create a new string input stream that will read from STRING.
   The stream is created in a closed state; call OPEN to start reading."
  (make-instance 'fol.classes:<string-input-stream>
                 :val nil
                 :open-p nil
                 :source-string string))

(defun make-file-input-stream (file-path)
  "Create a new file input stream that will read from FILE-PATH.
   The stream is created in a closed state; call OPEN to start reading."
  (make-instance 'fol.classes:<file-input-stream>
                 :val nil
                 :open-p nil
                 :file-path file-path))

(defun make-string-output-stream ()
  "Create a new string output stream.
   The stream is created in a closed state; call OPEN to start writing."
  (make-instance 'fol.classes:<string-output-stream>
                 :val nil
                 :open-p nil))

(defun make-file-output-stream (file-path)
  "Create a new file output stream that will write to FILE-PATH.
   The stream is created in a closed state; call OPEN to start writing."
  (make-instance 'fol.classes:<file-output-stream>
                 :val nil
                 :open-p nil
                 :file-path file-path))

;;; ============================================================================
;;; Stream State Predicates
;;; ============================================================================

(defun stream-open? (stream)
  "Return T if STREAM is currently open."
  (fol.classes:stream-open-p stream))

(defun stream-closed? (stream)
  "Return T if STREAM is currently closed."
  (not (fol.classes:stream-open-p stream)))

;;; ============================================================================
;;; Open and Close Operations
;;; ============================================================================

(defgeneric open (stream)
  (:documentation "Open STREAM for reading or writing.
   Returns the stream with its underlying CL stream initialized.
   Signals an error if the stream is already open."))

(defmethod open ((stream fol.classes:<string-input-stream>))
  "Open a string input stream for reading."
  (when (stream-open? stream)
    (error "Stream is already open"))
  (let ((cl-stream (cl:make-string-input-stream
                    (fol.classes:stream-source-string stream))))
    (setf (fol.classes:-fol-value stream) cl-stream)
    (setf (fol.classes:stream-open-p stream) t))
  stream)

(defmethod open ((stream fol.classes:<file-input-stream>))
  "Open a file input stream for reading."
  (when (stream-open? stream)
    (error "Stream is already open"))
  (let ((cl-stream (cl:open (fol.classes:stream-file-path stream)
                            :direction :input
                            :if-does-not-exist :error)))
    (setf (fol.classes:-fol-value stream) cl-stream)
    (setf (fol.classes:stream-open-p stream) t))
  stream)

(defmethod open ((stream fol.classes:<string-output-stream>))
  "Open a string output stream for writing."
  (when (stream-open? stream)
    (error "Stream is already open"))
  (let ((cl-stream (cl:make-string-output-stream)))
    (setf (fol.classes:-fol-value stream) cl-stream)
    (setf (fol.classes:stream-open-p stream) t))
  stream)

(defmethod open ((stream fol.classes:<file-output-stream>))
  "Open a file output stream for writing."
  (when (stream-open? stream)
    (error "Stream is already open"))
  (let ((cl-stream (cl:open (fol.classes:stream-file-path stream)
                            :direction :output
                            :if-exists :supersede
                            :if-does-not-exist :create)))
    (setf (fol.classes:-fol-value stream) cl-stream)
    (setf (fol.classes:stream-open-p stream) t))
  stream)

(defgeneric close (stream)
  (:documentation "Close STREAM.
   Returns the stream with its underlying CL stream closed.
   Does nothing if the stream is already closed."))

(defmethod close ((stream fol.classes:<stream>))
  "Close any FOL stream."
  (when (stream-open? stream)
    (let ((cl-stream (fol.classes:-fol-value stream)))
      (when cl-stream
        (cl:close cl-stream)))
    (setf (fol.classes:stream-open-p stream) nil))
  stream)

;;; ============================================================================
;;; String Output Stream Operations
;;; ============================================================================

(defun get-output-stream-string (stream)
  "Get the string accumulated in STREAM.
   STREAM must be a string output stream and must be open.
   Returns the accumulated string without closing the stream."
  (unless (<string-output-stream>? stream)
    (error "Expected a string output stream, got ~A" (type-of stream)))
  (unless (stream-open? stream)
    (error "Stream must be open to get its string"))
  (cl:get-output-stream-string (fol.classes:-fol-value stream)))

;;; ============================================================================
;;; Basic Read/Write Operations
;;; ============================================================================

(defun read-char* (stream &optional (eof-error-p t) eof-value)
  "Read a character from STREAM.
   If EOF-ERROR-P is true (default), signals error on EOF.
   Otherwise returns EOF-VALUE on EOF."
  (unless (<input-stream>? stream)
    (error "Expected an input stream, got ~A" (type-of stream)))
  (unless (stream-open? stream)
    (error "Stream is not open for reading"))
  (cl:read-char (fol.classes:-fol-value stream) eof-error-p eof-value))

(defun write-char* (char stream)
  "Write CHAR to STREAM. Returns CHAR."
  (unless (<output-stream>? stream)
    (error "Expected an output stream, got ~A" (type-of stream)))
  (unless (stream-open? stream)
    (error "Stream is not open for writing"))
  (cl:write-char char (fol.classes:-fol-value stream)))

(defun write-string* (string stream &key (start 0) end)
  "Write STRING to STREAM. Returns STRING."
  (unless (<output-stream>? stream)
    (error "Expected an output stream, got ~A" (type-of stream)))
  (unless (stream-open? stream)
    (error "Stream is not open for writing"))
  (cl:write-string string (fol.classes:-fol-value stream) :start start :end end))

(defun read-line* (stream &optional (eof-error-p t) eof-value)
  "Read a line from STREAM.
   Returns two values: the line (without newline) and a flag indicating EOF.
   If EOF-ERROR-P is true (default), signals error on EOF.
   Otherwise returns EOF-VALUE on EOF."
  (unless (<input-stream>? stream)
    (error "Expected an input stream, got ~A" (type-of stream)))
  (unless (stream-open? stream)
    (error "Stream is not open for reading"))
  (cl:read-line (fol.classes:-fol-value stream) eof-error-p eof-value))

;;; ============================================================================
;;; with-open-stream Macro
;;; ============================================================================

(defmacro with-open-stream ((var stream) &body body)
  "Execute BODY with VAR bound to an opened version of STREAM.
   The stream is opened before BODY executes and closed afterward,
   even if BODY signals an error.

   Example:
     (with-open-stream (s (make-string-input-stream \"hello\"))
       (read-line* s))

   This is equivalent to:
     (let ((s (open stream)))
       (try
         body...
         (finally (close s))))"
  (let ((stream-sym (gensym "STREAM")))
    `(let* ((,stream-sym ,stream)
            (,var (open ,stream-sym)))
       (unwind-protect
           (progn ,@body)
         (close ,var)))))
