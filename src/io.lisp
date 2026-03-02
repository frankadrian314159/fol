;;; FOL Compiler - I/O
;;;
;;; Clojure-style I/O functions.

(in-package :fol.compiler.io)

;;; ===========================================================================
;;; Core IO
;;; ===========================================================================

(defun coerce-to-stream (x &key (input t))
  "Internal helper to coerce argument to appropriate stream."
  (cond
   ((and input (fol.compiler.streams:<input-stream>? x)) x)
   ((and (not input) (fol.compiler.streams:<output-stream>? x)) x)
   ((streamp x)
     (if input
         (make-instance 'fol.compiler.streams:<file-input-stream> :stream x :file-object x)
         (make-instance 'fol.compiler.streams:<file-output-stream> :stream x :file-object x)))
   ((stringp x)
     (if input
         (make-instance 'fol.compiler.streams:<file-input-stream>
           :stream (open x :direction :input)
           :filename x
           :file-object (open x :direction :input)) ;; Warning: This opens a file but doesn't manage closing well if not used in with-open
         ;; For output, we default to string as filename
         (fol.compiler.streams:file-output-stream x)))
   (t (error "Cannot coerce ~S to stream." x))))

;;; Implementation Note:
;;; Many of these functions take an optional stream argument.
;;; In Clojure, they typically default to *out* or *in*.

;;; Printing

(defun pr (&rest args)
  "Prints object(s) to *out* in a way that can be read back by the reader.
   Returns nil."
  (let ((stream (fol.compiler.streams::output-stream-stream fol.compiler.streams:*out*)))
    (when args
          (cl:prin1 (first args) stream)
          (dolist (obj (rest args))
            (fol.compiler.streams:stream-write-char fol.compiler.streams:*out* #\Space)
            (cl:prin1 obj stream)))
    nil))

(defun prn (&rest args)
  "Same as pr, but follows with newline. Returns nil."
  (apply #'pr args)
  (newline))

(defun print (&rest args)
  "Prints object(s) to *out*. Returns nil."
  (let ((stream (fol.compiler.streams::output-stream-stream fol.compiler.streams:*out*)))
    (when args
          (cl:princ (first args) stream)
          (dolist (obj (rest args))
            (fol.compiler.streams:stream-write-char fol.compiler.streams:*out* #\Space)
            (cl:princ obj stream)))
    nil))

(defun println (&rest args)
  "Same as print, but follows with newline. Returns nil."
  (apply #'print args)
  (newline))

(defun printf (fmt &rest args)
  "Prints formatted output to *out*."
  (apply #'format t fmt args))

(defun newline ()
  "Prints a newline to *out*."
  (fol.compiler.streams:stream-write-char fol.compiler.streams:*out* #\Newline)
  nil)

(defun flush ()
  "Flushes the output stream."
  (fol.compiler.streams:stream-flush fol.compiler.streams:*out*)
  nil)

(defun print-table (rows)
  "Prints a collection of maps as a text table."
  (when (and rows (first rows))
        (let* ((keys-seq (fol.compiler.seq-functions:keys (first rows)))
               ;; Convert keys sequence to list for mapcar
               (keys (reverse (fol.compiler.seq-functions:reduce (lambda (acc x) (cons x acc)) nil keys-seq)))
               (col-data (mapcar (lambda (k)
                                   (let ((header (string k))
                                         (vals (mapcar (lambda (r) (cl:format nil "~A" (fol.compiler.collection-functions:get r k))) rows)))
                                     (list :key k
                                           :header header
                                           :width (reduce #'max (mapcar #'length vals) :initial-value (length header))
                                           :vals vals)))
                             keys))
               (stream (fol.compiler.streams::output-stream-stream fol.compiler.streams:*out*)))
          ;; Print header
          (cl:format stream "| ")
          (dolist (col col-data)
            (cl:format stream "~A~A | " (getf col :header)
              (make-string (- (getf col :width) (length (getf col :header))) :initial-element #\Space)))
          (cl:format stream "~%")

          ;; Print separator
          (cl:format stream "|-")
          (dolist (col col-data)
            (cl:format stream "~A-|-" (make-string (getf col :width) :initial-element #\-)))
          (cl:format stream "~%")

          ;; Print rows
          (dotimes (i (length rows))
            (cl:format stream "| ")
            (dolist (col col-data)
              (let ((val (nth i (getf col :vals))))
                (cl:format stream "~A~A | " val
                  (make-string (- (getf col :width) (length val)) :initial-element #\Space))))
            (cl:format stream "~%"))))
  nil)

(defun pprint (x)
  "Pretty prints object x to *out*."
  (cl:pprint x (fol.compiler.streams::output-stream-stream fol.compiler.streams:*out*)))

(defun format (stream format-string &rest args)
  "Wrapper around CL:FORMAT.
   Stream can be t (for *out*), nil (for string), or a stream object."
  (apply #'cl:format (if (eq stream t)
                         (fol.compiler.streams::output-stream-stream fol.compiler.streams:*out*)
                         stream)
    format-string args))


;;; String IO


(defun pr-str (&rest args)
  "pr to a string, returning it."
  (with-out-str (apply #'pr args)))

(defun prn-str (&rest args)
  "prn to a string, returning it."
  (with-out-str (apply #'prn args)))

(defun print-str (&rest args)
  "print to a string, returning it."
  (with-out-str (apply #'print args)))

(defun println-str (&rest args)
  "println to a string, returning it."
  (with-out-str (apply #'println args)))

;;; Reading

(defun read-line (&optional (stream fol.compiler.streams:*in*) (eof-error-p t) eof-value recursive-p)
  "Reads the next line from stream."
  (fol.compiler.streams:stream-read-line stream))

(defun read (&optional (stream fol.compiler.streams:*in*) (eof-error-p t) eof-value recursive-p)
  "Reads the next object from stream."
  (cl:read (fol.compiler.streams::input-stream-stream stream) eof-error-p eof-value recursive-p))

(defun line-seq (rdr)
  "Returns the lines of text from rdr as a lazy sequence of strings."
  (let ((line (read-line rdr nil nil)))
    (if line
        (fol.compiler.collection-functions:lazy-seq
          (lambda () (cons line (line-seq rdr))))
        nil)))


;;; File IO

(defun slurp (f &key encoding)
  "Reads the file named by f into a string and returns it."
  (with-open-file (stream f :direction :input :if-does-not-exist nil)
    (if stream
        (let ((seq (make-string (file-length stream))))
          (read-sequence seq stream)
          seq)
        nil)))

(defun spit (f content &key (append nil))
  "Opposite of slurp. Opens f, writes content, then closes f.
   Options passed to open (e.g. :append)."
  (with-open-file (stream f :direction :output
                          :if-exists (if append :append :supersede)
                          :if-does-not-exist :create)
    (write-sequence content stream))
  nil)


(defun close (x)
  "Closes the stream/resource x."
  (if (fol.compiler.streams:<input-stream>? x)
      (fol.compiler.streams:stream-close x)
      (if (fol.compiler.streams:<output-stream>? x)
          (fol.compiler.streams:stream-close x)
          (cl:close x))))

(defun file (path)
  "Returns a java.io.File (or logical equivalent) from string path."
  (pathname path))

(defun copy (input output)
  "Copies input to output."
  ;; Basic implementation
  (cond
   ((and (stringp input) (pathnamep output)) ;; String to File
                                            (spit output input))
   ((and (pathnamep input) (pathnamep output)) ;; File to File
                                              (uiop:copy-file input output))
   (t (error "Not implemented copy for these types"))))

(defun delete-file (f)
  "Delete file f. Returns true if successful."
  (cl:delete-file f)
  t)

(defun resource (name)
  "Returns the URL for the named resource on the classpath (not fully supported in CL)."
  ;; Placeholder: check current directory or source root
  (probe-file name))

(defun as-file (x)
  "Coerces x to a file."
  (pathname x))

(defun as-url (x)
  "Coerces x to a URL."
  (if (stringp x) x (namestring x)))

(defun as-relative-path (x)
  "Coerces x to a relative path."
  (namestring x))

;;; Tap system (simplified)
(defvar *taps* (atom (list)))

(defun tap> (x)
  "Sends x to any registered taps. Returns true if there are any taps, false otherwise."
  (let ((taps (fol.compiler.mutable:deref *taps*)))
    (dolist (f taps)
      (funcall f x))
    (not (null taps))))

(defun add-tap (f)
  "Adds f to the tap set."
  (fol.compiler.mutable:swap! *taps* (lambda (old) (cons f old)))
  nil)

(defun remove-tap (f)
  "Removes f from the tap set."
  (fol.compiler.mutable:swap! *taps* (lambda (old) (remove f old)))
  nil)
