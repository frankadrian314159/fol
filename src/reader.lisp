;;; FOL Compiler - Reader
;;;
;;; Defines *fol-readtable*, a CL readtable extended with FOL reader macros.
;;; Copies the standard CL readtable and adds support for:
;;;
;;; Collection Literals:
;;;   [...]     - vector literal
;;;   {...}     - dict literal
;;;   #{...}    - set literal
;;;   #M{...}   - bag (multiset) literal
;;;   #Q[...]   - deque (double-ended queue) literal
;;;
;;; Other Literals:
;;;   #"..."    - regex pattern literal
;;;   #_        - ignore next form
;;;   @expr     - deref (expands to (deref expr))
;;;
;;; Character Literals (Clojure-style):
;;;   \a        - single character
;;;   \newline, \space, \tab, \return, \backspace, \formfeed - named characters
;;;   \n, \t, \r, \b, \f - shortcut escapes
;;;   \uNNNN    - Unicode character (4 hex digits)
;;;
;;; Numeric Literals (extended):
;;;   0xABCD    - hexadecimal (C-style)
;;;   0o777     - octal (C-style)
;;;   16rFF     - radix notation, base 2-36 (Dylan-style)
;;;   3/4       - ratios (CL standard)
;;;   3.14f0    - single-float (CL standard)
;;;   3.14d0    - double-float (CL standard)
;;;
;;; Usage:
;;;   (let ((*readtable* fol.compiler.reader:*fol-readtable*))
;;;     (read-from-string "[1 2 3]"))
;;;   => <vector> of 1, 2, 3

(in-package :fol.compiler.reader)

;;; ============================================================================
;;; FOL Readtable
;;; ============================================================================

(defvar *fol-readtable* (copy-readtable nil)
  "The FOL readtable, based on the standard CL readtable with FOL extensions.")

;;; ============================================================================
;;; Numeric Literal Support
;;; ============================================================================

(defun read-number-token (stream first-char)
  "Read a complete number token starting with FIRST-CHAR.
   Continues reading while we see characters that could be part of a number:
   digits, letters (for hex/radix), +/- (for exponents), /, ., e/E, f/F, d/D."
  (let ((chars (list first-char)))
    (loop
      (let ((c (peek-char nil stream nil nil t)))
        (if (and c (or (alphanumericp c)
                       (member c '(#\. #\/ #\+ #\- #\e #\E #\f #\F #\d #\D #\s #\S #\l #\L))))
            (push (read-char stream) chars)
            (return (coerce (nreverse chars) 'string)))))))

(defun parse-fol-number (token)
  "Parse a number token with extended FOL syntax:
   - 0xABCD / 0XABCD: hexadecimal (C-style)
   - 0o777 / 0O777: octal (C-style)
   - 16rFF / 16RFF: arbitrary radix 2-36 (Dylan-style)
   - 3/4: ratios (CL standard)
   - 3.14f0, 3.14d0: floats (CL standard)
   - Standard CL integers and floats"
  (cond
    ;; 0xABCD - hexadecimal
    ((and (>= (length token) 3)
          (char= (char token 0) #\0)
          (or (char= (char token 1) #\x)
              (char= (char token 1) #\X)))
     (parse-integer (subseq token 2) :radix 16))

    ;; 0o777 - octal
    ((and (>= (length token) 3)
          (char= (char token 0) #\0)
          (or (char= (char token 1) #\o)
              (char= (char token 1) #\O)))
     (parse-integer (subseq token 2) :radix 8))

    ;; 16rFF - arbitrary radix (Dylan-style)
    ;; Pattern: <digits>r<digits> or <digits>R<digits>
    ((position #\r token :test #'char-equal)
     (let ((pos (position #\r token :test #'char-equal)))
       (handler-case
           (let ((radix (parse-integer (subseq token 0 pos)))
                 (digits (subseq token (1+ pos))))
             (unless (<= 2 radix 36)
               (error "Radix must be between 2 and 36, got ~A" radix))
             (parse-integer digits :radix radix))
         (error ()
           ;; If parsing as radix fails, fall back to standard CL reading
           ;; (might be something like "error" which contains 'r')
           (let ((*readtable* (copy-readtable nil)))
             (read-from-string token))))))

    ;; Standard CL number (integers, ratios, floats)
    (t
     (let ((*readtable* (copy-readtable nil)))
       (read-from-string token)))))

(defun read-fol-number (stream char)
  "Read a number with extended FOL syntax support.
   Handles: 0xHEX, 0oOCT, NrDIGITS, and all standard CL numbers."
  (let ((token (read-number-token stream char)))
    (parse-fol-number token)))

;;; ============================================================================
;;; Reader Macro Functions
;;; ============================================================================

(defun read-fol-vector (stream char)
  "Read a FOL vector literal: [e1 e2 ...]"
  (declare (ignore char))
  (let ((elements (read-delimited-list #\] stream t)))
    (apply #'fol.compiler.collection-functions:vector elements)))

(defun read-fol-dict (stream char)
  "Read a FOL dict literal: {k1 v1 k2 v2 ...}"
  (declare (ignore char))
  (let ((pairs (read-delimited-list #\} stream t)))
    (unless (evenp (length pairs))
      (error "Dict literal must contain an even number of forms"))
    (apply #'fol.compiler.collection-functions:dict pairs)))

(defun read-fol-close-bracket (stream char)
  "Signal an error for unmatched ] or }."
  (declare (ignore stream))
  (error "Unmatched closing ~C" char))

;;; --- Dispatch macro functions (called via #) ---

(defun read-fol-set (stream sub-char arg)
  "Read a FOL set literal: #{e1 e2 ...}"
  (declare (ignore sub-char arg))
  (let ((elements (read-delimited-list #\} stream t)))
    (apply #'fol.compiler.collection-functions:set elements)))

(defun read-fol-bag (stream sub-char arg)
  "Read a FOL bag (multiset) literal: #M{e1 e2 ...}"
  (declare (ignore sub-char arg))
  (let ((next (read-char stream t nil t)))
    (unless (char= next #\{)
      (error "Expected { after #M, got ~C" next))
    (let ((elements (read-delimited-list #\} stream t)))
      (apply #'fol.compiler.collection-functions:bag elements))))

(defun read-fol-deque (stream sub-char arg)
  "Read a FOL deque literal: #Q[e1 e2 ...]"
  (declare (ignore sub-char arg))
  (let ((next (read-char stream t nil t)))
    (unless (char= next #\[)
      (error "Expected [ after #Q, got ~C" next))
    (let ((elements (read-delimited-list #\] stream t)))
      (apply #'fol.compiler.collection-functions:deque elements))))

(defun read-fol-regex (stream sub-char arg)
  "Read a FOL regex pattern: #\"pattern\"
   Returns the pattern as a string (re-pattern is a type descriptor)."
  (declare (ignore sub-char arg))
  (let ((result (make-array 0 :element-type 'character
                              :fill-pointer 0 :adjustable t)))
    (loop
      (let ((c (read-char stream t nil t)))
        (cond
          ((char= c #\")
           (return (copy-seq result)))
          ((char= c #\\)
           (let ((next (read-char stream t nil t)))
             (vector-push-extend
              (case next
                (#\n #\Newline)
                (#\t #\Tab)
                (#\r #\Return)
                (t next))
              result)))
          (t
           (vector-push-extend c result)))))))

(defun read-fol-ignore (stream sub-char arg)
  "Read and discard the next form: #_form"
  (declare (ignore sub-char arg))
  (read stream t nil t)
  (values))

(defun read-fol-deref (stream char)
  "Read a FOL deref: @expr => (fol.compiler.mutable:deref expr)"
  (declare (ignore char))
  (list 'fol.compiler.mutable:deref (read stream t nil t)))

(defun read-fol-character (stream char)
  "Read a Clojure-style character literal: \\a, \\newline, \\space, etc.
   Supported named characters: newline, space, tab, return, backspace, formfeed.
   Single characters: \\a, \\b, \\Z, etc.
   Unicode: \\uNNNN (4 hex digits)."
  (declare (ignore char))
  (let ((token (make-array 0 :element-type 'character
                             :fill-pointer 0 :adjustable t)))
    ;; Read characters until we hit whitespace, delimiter, or EOF
    (loop
      (let ((c (peek-char nil stream nil nil t)))
        (when (or (null c)
                  (member c '(#\Space #\Tab #\Newline #\Return #\( #\) #\[ #\] #\{ #\} #\" #\; #\,)))
          (return))
        (vector-push-extend (read-char stream) token)))
    ;; Parse the token
    (cond
      ;; Empty token - error
      ((zerop (length token))
       (error "Invalid character literal: backslash not followed by character"))
      ;; Single character shortcuts (C-style escapes)
      ((string= token "n") #\Newline)
      ((string= token "t") #\Tab)
      ((string= token "r") #\Return)
      ((string= token "b") #\Backspace)
      ((string= token "f") (code-char 12))  ; formfeed
      ;; Named characters (Clojure-style)
      ((string-equal token "newline") #\Newline)
      ((string-equal token "space") #\Space)
      ((string-equal token "tab") #\Tab)
      ((string-equal token "return") #\Return)
      ((string-equal token "backspace") #\Backspace)
      ((string-equal token "formfeed") (code-char 12))
      ;; Unicode: \uNNNN format (4 hex digits)
      ((and (> (length token) 1)
            (char= (char token 0) #\u)
            (= (length token) 5))
       (let ((hex-string (subseq token 1)))
         (handler-case
             (code-char (parse-integer hex-string :radix 16))
           (error ()
             (error "Invalid unicode character literal: \\~A" token)))))
      ;; Single character (after checking shortcuts)
      ((= 1 (length token))
       (char token 0))
      ;; Otherwise error
      (t
       (error "Unknown character literal: \\~A" token)))))

;;; ============================================================================
;;; Install Reader Macros
;;; ============================================================================

;;; [ and ] for vectors
(set-macro-character #\[ #'read-fol-vector nil *fol-readtable*)
(set-macro-character #\] #'read-fol-close-bracket nil *fol-readtable*)

;;; { and } for dicts
(set-macro-character #\{ #'read-fol-dict nil *fol-readtable*)
(set-macro-character #\} #'read-fol-close-bracket nil *fol-readtable*)

;;; #{ for sets
(set-dispatch-macro-character #\# #\{ #'read-fol-set *fol-readtable*)

;;; #M for bags (multisets)
(set-dispatch-macro-character #\# #\M #'read-fol-bag *fol-readtable*)

;;; #Q for deques
(set-dispatch-macro-character #\# #\Q #'read-fol-deque *fol-readtable*)

;;; #" for regex patterns
(set-dispatch-macro-character #\# #\" #'read-fol-regex *fol-readtable*)

;;; #_ for ignore-next-form
(set-dispatch-macro-character #\# #\_ #'read-fol-ignore *fol-readtable*)

;;; @ for deref
(set-macro-character #\@ #'read-fol-deref nil *fol-readtable*)

;;; \ for character literals (Clojure-style)
(set-macro-character #\\ #'read-fol-character nil *fol-readtable*)

;;; Digit characters (0-9) for extended numeric literals
;;; Install custom number reader for C-style hex/octal and Dylan-style radix
(loop for digit-char from (char-code #\0) to (char-code #\9)
      do (set-macro-character (code-char digit-char) #'read-fol-number nil *fol-readtable*))

;;; ============================================================================
;;; Reader Entry Points
;;; ============================================================================

(defun fol-read (&optional (stream *standard-input*) (eof-error-p t) eof-value recursive-p)
  "Read one FOL expression from STREAM using *fol-readtable*."
  (let ((*readtable* *fol-readtable*))
    (read stream eof-error-p eof-value recursive-p)))

(defun fol-read-from-string (string &optional (eof-error-p t) eof-value)
  "Read one FOL expression from STRING using *fol-readtable*.
   Returns two values: the expression and the position after reading."
  (let ((*readtable* *fol-readtable*))
    (read-from-string string eof-error-p eof-value)))
