(in-package fol.reader)

;;; Forward declarations for readtable variables which are defined later in this file
;;; but referenced by reader functions defined earlier.
(defvar *clojure-readtable*)
(defvar *fol-readtable*)

;;; ============================================================================
;;; Readtable Class
;;; ============================================================================

(defclass <readtable> (fol.collection:<dict>)
  ((dispatch-table :initarg :dispatch-table
                   :initform nil
                   :accessor readtable-dispatch-table
                   :documentation "A nested dict mapping dispatch characters to sub-character functions.
                                   Structure: {disp-char -> {sub-char -> function}}
                                   Each function takes (stream char arg) as parameters."))
  (:metaclass fol.persistent:persistent-class)
  (:documentation "A readtable that maps characters to reader functions.
                   Each function takes the character as a parameter.
                   Also supports dispatch macro characters (like #\\# in Common Lisp)."))

(defun make-readtable (character-class-table-or-nil &rest char-fn-pairs)
  "Create a new <readtable> from consecutive pairs of characters/character-lists and functions.

   The first argument must be either a <character-class-table> or NIL.
   If a <character-class-table> is provided, character class symbols can be used as keys.

   Each function should accept a character as its parameter.

   Keys in char-fn-pairs can be:
   - A character: the function is mapped to that character
   - A list of characters: the function is mapped to all characters in the list
   - A symbol (if character-class-table provided): the function is mapped to all characters
     in that character class

   Examples:
     (make-readtable nil
                     #\\( #'read-list
                     #\\[ #'read-vector)

     (make-readtable nil
                     (#\\a #\\b #\\c) #'read-letter
                     #\\( #'read-list)

     (make-readtable char-class-table
                     'digit #'read-number
                     'whitespace #'skip-whitespace
                     #\\( #'read-list)"
  (unless (or (null character-class-table-or-nil)
              (<character-class-table>? character-class-table-or-nil))
    (error "First argument must be a <character-class-table> or NIL, got ~A"
           character-class-table-or-nil))

  ;; Create an empty readtable
  (let ((readtable (make-instance '<readtable> :items (fset:empty-map))))

    ;; Process char-fn-pairs using set-macro-character
    (loop for (key fn) on char-fn-pairs by #'cddr
          do (unless (functionp fn)
               (error "Expected a function, got ~A" fn))
             (cond
               ;; Single character
               ((characterp key)
                (fol-set-macro-character readtable key fn))

               ;; List of characters
               ((listp key)
                (dolist (char key)
                  (unless (characterp char)
                    (error "Expected a character in list, got ~A" char))
                  (fol-set-macro-character readtable char fn)))

               ;; Symbol referring to a character class
               ((symbolp key)
                (unless character-class-table-or-nil
                  (error "Cannot use symbol ~A without a character class table" key))
                (let ((char-class (fol.collection:get character-class-table-or-nil key)))
                  (unless char-class
                    (error "Character class ~A not found in character class table" key))
                  (dolist (char char-class)
                    (fol-set-macro-character readtable char fn))))

               ;; Invalid type
               (t
                (error "Expected a character, list of characters, or symbol, got ~A" key))))

    readtable))

(defgeneric <readtable>? (obj)
  (:documentation "Returns T if OBJ is a FOL <readtable>."))

(defmethod <readtable>? (obj)
  nil)

(defmethod <readtable>? ((obj <readtable>))
  t)

;;; ============================================================================
;;; Macro Characters
;;; ============================================================================

(defgeneric fol-set-macro-character (readtable char function &optional non-terminating-p)
  (:documentation "Set a macro character function in the readtable.

   Similar to Common Lisp's SET-MACRO-CHARACTER but takes a readtable as first argument.

   Parameters:
   - readtable: The <readtable> to modify
   - char: The character to set as a macro character
   - function: A function taking two arguments (stream char)
   - non-terminating-p: Optional, currently ignored (for CL compatibility)

   The function will be called with:
   - stream: The input stream
   - char: The character that was read

   Example:
     (fol-set-macro-character my-readtable #\\( #'read-list)"))

(defmethod fol-set-macro-character ((readtable <readtable>)
                                    char
                                    function
                                    &optional non-terminating-p)
  (declare (ignore non-terminating-p))

  (unless (characterp char)
    (error "Macro character must be a character, got ~A" char))

  (unless (functionp function)
    (error "Function must be a function, got ~A" function))

  ;; Add the function to the readtable (which is a dict)
  (let ((items (fol.persistent:pslot-value readtable 'fol.collection::items)))
    (setf items (fset:with items char function))
    (fol.persistent:set-pslot-value readtable 'fol.collection::items items))

  readtable)

(defgeneric fol-get-macro-character (readtable char)
  (:documentation "Get the macro character function from the readtable.

   Similar to Common Lisp's GET-MACRO-CHARACTER but takes a readtable as first argument.

   Parameters:
   - readtable: The <readtable> to query
   - char: The character to look up

   Returns:
   Two values:
   1. The function associated with this character, or NIL if none exists
   2. Non-terminating-p flag (always NIL in this implementation)"))

(defmethod fol-get-macro-character ((readtable <readtable>) char)
  (unless (characterp char)
    (error "Macro character must be a character, got ~A" char))

  (let ((function (fol.collection:get readtable char)))
    (values function nil)))

;;; ============================================================================
;;; Dispatch Macro Characters
;;; ============================================================================

(defgeneric fol-set-dispatch-macro-character (readtable disp-char sub-char function &optional non-terminating-p)
  (:documentation "Set a dispatch macro character function in the readtable.

   Similar to Common Lisp's SET-DISPATCH-MACRO-CHARACTER but takes a readtable as first argument.

   Parameters:
   - readtable: The <readtable> to modify
   - disp-char: The dispatch character (e.g., #\\#)
   - sub-char: The sub-character that follows the dispatch character (e.g., #\\{)
   - function: A function taking three arguments (stream char arg)
   - non-terminating-p: Optional, currently ignored (for CL compatibility)

   The function will be called with:
   - stream: The input stream
   - char: The sub-character that was read
   - arg: An optional numeric argument (or NIL)

   Example:
     (fol-set-dispatch-macro-character my-readtable #\\# #\\{ #'read-set)
     ;; Now #{ will call read-set"))

(defmethod fol-set-dispatch-macro-character ((readtable <readtable>)
                                             disp-char
                                             sub-char
                                             function
                                             &optional non-terminating-p)
  (declare (ignore non-terminating-p))

  (unless (characterp disp-char)
    (error "Dispatch character must be a character, got ~A" disp-char))

  (unless (characterp sub-char)
    (error "Sub-character must be a character, got ~A" sub-char))

  (unless (functionp function)
    (error "Function must be a function, got ~A" function))

  ;; Get or create the dispatch table
  (let ((dispatch-table (readtable-dispatch-table readtable)))
    (unless dispatch-table
      (setf dispatch-table (fol.collection:make-dict))
      (fol.persistent:set-pslot-value readtable 'dispatch-table dispatch-table))

    ;; Get or create the sub-table for this dispatch character
    (let ((sub-table (fol.collection:get dispatch-table disp-char)))
      (unless sub-table
        (setf sub-table (fol.collection:make-dict)))

      ;; Add the function to the sub-table
      (setf sub-table (fol.collection:add sub-table sub-char function))

      ;; Update the dispatch table
      (setf dispatch-table (fol.collection:add dispatch-table disp-char sub-table))
      (fol.persistent:set-pslot-value readtable 'dispatch-table dispatch-table)))

  readtable)

(defgeneric fol-get-dispatch-macro-character (readtable disp-char sub-char)
  (:documentation "Get the dispatch macro character function from the readtable.

   Similar to Common Lisp's GET-DISPATCH-MACRO-CHARACTER but takes a readtable as first argument.

   Parameters:
   - readtable: The <readtable> to query
   - disp-char: The dispatch character (e.g., #\\#)
   - sub-char: The sub-character (e.g., #\\{)

   Returns:
   The function associated with this dispatch macro, or NIL if none exists."))

(defmethod fol-get-dispatch-macro-character ((readtable <readtable>) disp-char sub-char)
  (let ((dispatch-table (readtable-dispatch-table readtable)))
    (when dispatch-table
      (let ((sub-table (fol.collection:get dispatch-table disp-char)))
        (when sub-table
          (fol.collection:get sub-table sub-char))))))

;;; ============================================================================
;;; Character Class Table
;;; ============================================================================

(defclass <character-class-table> (fol.collection:<dict>)
  ()
  (:metaclass fol.persistent:persistent-class)
  (:documentation "A table that maps character class names (symbols) to lists of characters."))

(defun make-character-class-table (&rest symbol-charlist-pairs)
  "Create a new <character-class-table> from consecutive pairs of symbols and character lists.

   Each pair consists of:
   - A symbol representing the name of the character class
   - A list of characters belonging to that class

   Example:
     (make-character-class-table 'whitespace '(#\\Space #\\Tab #\\Newline)
                                 'digit '(#\\0 #\\1 #\\2 #\\3 #\\4 #\\5 #\\6 #\\7 #\\8 #\\9))"
  (let ((map (fset:empty-map)))
    (loop for (symbol charlist) on symbol-charlist-pairs by #'cddr
          do (unless (symbolp symbol)
               (error "Expected a symbol for character class name, got ~A" symbol))
             (unless (listp charlist)
               (error "Expected a list of characters, got ~A" charlist))
             (dolist (char charlist)
               (unless (characterp char)
                 (error "Expected a character in character list, got ~A" char)))
             (setf map (fset:with map symbol charlist)))
    (make-instance '<character-class-table> :items map)))

(defgeneric <character-class-table>? (obj)
  (:documentation "Returns T if OBJ is a FOL <character-class-table>."))

(defmethod <character-class-table>? (obj)
  nil)

(defmethod <character-class-table>? ((obj <character-class-table>))
  t)

;;; ============================================================================
;;; Atom Accumulation and Parsing
;;; ============================================================================
(defparameter *atom-accumulator*
  (make-array 0 :element-type 'character
              :fill-pointer 0
              :adjustable t)
  "Shared accumulator for building atoms during reading")

(defun accumulate-atom (stream chr)
  "Accumulate a character into the current atom being read"
  (declare (ignore stream))
  (vector-push-extend chr *atom-accumulator*)
  (values))

(defun terminate-atom (stream chr)
  "Terminate the current atom and return it as a symbol or number"
  (declare (ignore stream chr))
  (when (> (fill-pointer *atom-accumulator*) 0)
    (let* ((atom-string (copy-seq *atom-accumulator*))
           (result (or (parse-number atom-string)
                       (intern (string-upcase atom-string)))))
      (setf (fill-pointer *atom-accumulator*) 0)
      result)))

(defun parse-number (string)
  "Try to parse a string as a number. Returns NIL if not a valid number."
  (handler-case
      (let ((*read-default-float-format* 'double-float))
        (read-from-string string))
    (error () nil)))

;; Reader functions for Clojure special forms

(defun fol-read-delimited-list (closing-char stream readtable)
  "Read a list of forms until CLOSING-CHAR is encountered"
  (let ((result '()))
    (loop
      (let ((chr (peek-char t stream t nil t)))
        (when (char= chr closing-char)
          (read-char stream)  ; Consume closing char
          (return (nreverse result)))
        (push (fol-read stream t nil readtable) result)))))

(defun read-list (stream chr)
  "Read a Clojure list starting with ("
  (declare (ignore chr))
  (fol-read-delimited-list #\) stream *clojure-readtable*))

(defun read-vector (stream chr)
  "Read a Clojure vector starting with ["
  (declare (ignore chr))
  (let ((elements (fol-read-delimited-list #\] stream *clojure-readtable*)))
    (make-array (length elements) :initial-contents elements)))

(defun read-map (stream chr)
  "Read a Clojure map starting with {"
  (declare (ignore chr))
  (let ((pairs (fol-read-delimited-list #\} stream *clojure-readtable*)))
    (unless (evenp (length pairs))
      (error "Map literal must contain an even number of forms"))
    (let ((hash-table (make-hash-table :test 'equal)))
      (loop for (key value) on pairs by #'cddr
            do (setf (gethash key hash-table) value))
      hash-table)))

(defun read-string (stream chr)
  "Read a Clojure string starting with \""
  (declare (ignore chr))
  (let ((result (make-array 0 :element-type 'character
                              :fill-pointer 0
                              :adjustable t)))
    (loop
      (let ((c (read-char stream t nil t)))
        (cond
          ;; End of string
          ((char= c #\")
           (return (copy-seq result)))

          ;; Escape sequences
          ((char= c #\\)
           (let ((next (read-char stream t nil t)))
             (vector-push-extend
              (case next
                (#\n #\Newline)
                (#\t #\Tab)
                (#\r #\Return)
                (#\\ #\\)
                (#\" #\")
                (t next))
              result)))

          ;; Regular character
          (t
           (vector-push-extend c result)))))))

(defun read-comment (stream chr)
  "Read a Clojure comment starting with ; - consume until end of line"
  (declare (ignore chr))
  (loop for c = (read-char stream nil nil t)
        until (or (null c) (char= c #\Newline)))
  (values))

(defun read-deref (stream chr)
  "Read a Clojure deref starting with @"
  (declare (ignore chr))
  (list 'deref (fol-read stream t nil *clojure-readtable*)))

(defun read-quote (stream chr)
  "Read a Clojure quote starting with '"
  (declare (ignore chr))
  (list 'quote (fol-read stream t nil *clojure-readtable*)))

(defun read-syntax-quote (stream chr)
  "Read a Clojure syntax-quote starting with `"
  (declare (ignore chr))
  (list 'syntax-quote (fol-read stream t nil *clojure-readtable*)))

(defun read-unquote (stream chr)
  "Read a Clojure unquote starting with ~"
  (declare (ignore chr))
  ;; Check for unquote-splicing (~@)
  (if (char= (peek-char nil stream nil nil t) #\@)
      (progn
        (read-char stream)
        (list 'unquote-splicing (fol-read stream t nil *clojure-readtable*)))
      (list 'unquote (fol-read stream t nil *clojure-readtable*))))

(defun read-metadata (stream chr)
  "Read a Clojure metadata starting with ^"
  (declare (ignore chr))
  (let ((metadata (fol-read stream t nil *clojure-readtable*))
        (form (fol-read stream t nil *clojure-readtable*)))
    (list 'with-meta form metadata)))

;; Dispatch macro functions (take stream, char, arg)

(defun read-set-dispatch (stream char arg)
  "Read a Clojure set starting with #{"
  (declare (ignore char arg))
  (let ((elements (fol-read-delimited-list #\} stream *clojure-readtable*)))
    ;; Convert list to a hash table representing a set (keys with value T)
    (let ((set (make-hash-table :test 'equal)))
      (dolist (elem elements)
        (setf (gethash elem set) t))
      (cons 'set set))))

(defun read-regex-dispatch (stream char arg)
  "Read a Clojure regex starting with #\""
  (declare (ignore char arg))
  ;; Read the regex pattern as a string
  (let ((pattern (read-string stream #\")))
    (list 'regex pattern)))

(defun read-var-quote-dispatch (stream char arg)
  "Read a Clojure var quote starting with #'"
  (declare (ignore char arg))
  (list 'var (fol-read stream t nil *clojure-readtable*)))

(defun read-fn-dispatch (stream char arg)
  "Read a Clojure anonymous function starting with #("
  (declare (ignore char arg))
  (let ((body (fol-read-delimited-list #\) stream *clojure-readtable*)))
    (list 'fn body)))

(defun read-ignore-dispatch (stream char arg)
  "Read a Clojure ignore form starting with #_ - read and discard next form"
  (declare (ignore char arg))
  (fol-read stream t nil *clojure-readtable*)
  (values))

(defun read-conditional-dispatch (stream char arg)
  "Read a Clojure reader conditional starting with #?"
  (declare (ignore char arg))
  (let ((conditional-form (fol-read stream t nil *clojure-readtable*)))
    (list 'reader-conditional conditional-form)))

(defun read-symbolic-value-dispatch (stream char arg)
  "Read a Clojure symbolic value starting with ##"
  (declare (ignore char arg))
  (let ((symbol (fol-read stream t nil *clojure-readtable*)))
    (list 'symbolic-value symbol)))

(defun read-multiset-dispatch (stream char arg)
  "Read a multiset (bag) starting with #M{"
  (declare (ignore char arg))
  ;; Verify the next character is {
  (let ((next-char (peek-char nil stream t nil t)))
    (unless (char= next-char #\{)
      (error "Expected '{' after #M, got ~C" next-char))
    (read-char stream)  ; Consume the {
    (let ((elements (fol-read-delimited-list #\} stream *clojure-readtable*)))
      ;; Convert list to a hash table representing a multiset (element -> count)
      (let ((bag (make-hash-table :test 'equal)))
        (dolist (elem elements)
          (incf (gethash elem bag 0)))
        (cons 'multiset bag)))))

(defun read-dispatch-general (stream chr)
  "General dispatch function for # character - delegates to specific dispatch handlers"
  (declare (ignore chr))
  ;; Read the next character to determine which dispatch function to use
  (let ((sub-char (peek-char nil stream t nil t)))
    ;; Check if it's a digit (for argument)
    (let ((arg nil))
      (when (digit-char-p sub-char)
        (setf arg (parse-integer
                   (with-output-to-string (s)
                     (loop while (digit-char-p (peek-char nil stream nil nil t))
                           do (write-char (read-char stream) s))))))

      ;; Now read the actual sub-character
      (let ((actual-sub-char (read-char stream t nil t)))
        ;; Look up the dispatch function
        (let ((dispatch-fn (fol-get-dispatch-macro-character *clojure-readtable* #\# actual-sub-char)))
          (if dispatch-fn
              (funcall dispatch-fn stream actual-sub-char arg)
              (error "No dispatch function for #~C" actual-sub-char)))))))

(defparameter *clojure-readtable*
    (let* ((clojure-char-classes
                (make-character-class-table
                    :whitespace '(#\Space #\Tab #\Newline #\Linefeed
                                  #\Return #\Page)
                    :digit '(#\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9)
                    :alphabetic
                        '(#\a #\b #\c #\d #\e #\f #\g #\h #\i #\j
                          #\k #\l #\m #\n #\o #\p #\q #\r #\s #\t
                          #\u #\v #\w #\x #\y #\z
                          #\A #\B #\C #\D #\E #\F #\G #\H #\I #\J
                          #\K #\L #\M #\N #\O #\P #\Q #\R #\S #\T
                          #\U #\V #\W #\X #\Y #\Z)
                    :symbol-constituent
                        '(#\- #\+ #\* #\/ #\< #\> #\? #\! #\$ #\%
                          #\& #\_ #\= #\.)
                    :namespace-separator '(#\: #\/)))
           (readtable
                (make-readtable clojure-char-classes
                    ;; Whitespace - terminates atoms
                    :whitespace #'terminate-atom

                    ;; Symbol constituents - accumulate into atoms
                    :alphabetic #'accumulate-atom
                    :digit #'accumulate-atom
                    :symbol-constituent #'accumulate-atom
                    :namespace-separator #'accumulate-atom

                    ;; Delimiters and special forms
                    #\( #'read-list          ; List
                    #\) #'terminate-atom     ; End list
                    #\[ #'read-vector        ; Vector
                    #\] #'terminate-atom     ; End vector
                    #\{ #'read-map           ; Map
                    #\} #'terminate-atom     ; End map

                    ;; Reader macros
                    #\" #'read-string        ; String literal
                    #\; #'read-comment       ; Comment
                    #\@ #'read-deref         ; Deref
                    #\' #'read-quote         ; Quote
                    #\` #'read-syntax-quote  ; Syntax quote
                    #\~ #'read-unquote       ; Unquote
                    #\^ #'read-metadata      ; Metadata
                    #\# #'read-dispatch-general ; Dispatch character
                    #\\ #'accumulate-atom))) ; Character literal (backslash)

      ;; Set up dispatch macro characters for #
      ;; The #\# character is now mapped to read-dispatch-general
      ;; which will look up the appropriate sub-character handler

      ;; #{ - set literal
      (fol-set-dispatch-macro-character readtable #\# #\{ #'read-set-dispatch)

      ;; #M{ - multiset (bag) literal
      (fol-set-dispatch-macro-character readtable #\# #\M #'read-multiset-dispatch)

      ;; #" - regex literal
      (fol-set-dispatch-macro-character readtable #\# #\" #'read-regex-dispatch)

      ;; #' - var quote
      (fol-set-dispatch-macro-character readtable #\# #\' #'read-var-quote-dispatch)

      ;; #( - anonymous function
      (fol-set-dispatch-macro-character readtable #\# #\( #'read-fn-dispatch)

      ;; #_ - ignore next form
      (fol-set-dispatch-macro-character readtable #\# #\_ #'read-ignore-dispatch)

      ;; #? - reader conditional
      (fol-set-dispatch-macro-character readtable #\# #\? #'read-conditional-dispatch)

      ;; ## - symbolic value
      (fol-set-dispatch-macro-character readtable #\# #\# #'read-symbolic-value-dispatch)

      readtable)
  "The standard Clojure readtable with full support for:
   - Lists: ( )
   - Vectors: [ ]
   - Maps: { }
   - Sets: #{ }
   - Multisets: #M{ }
   - Strings: \"...\"
   - Comments: ; ...
   - Deref: @
   - Quote: '
   - Syntax quote: `
   - Unquote: ~
   - Metadata: ^
   - Character literals: \\
   - Regex: #\"...\"
   - Var quote: #'
   - Anonymous functions: #(...)
   - Ignore: #_
   - Reader conditionals: #?
   - Symbolic values: ##")

(defparameter *fol-readtable* *clojure-readtable*
  "The current readtable used by fol-read and fol-read-from-string.")

;;; ============================================================================
;;; Reader Function
;;; ============================================================================

(defun fol-read (stream &optional (eof-error-p t) eof-value (readtable *fol-readtable*))
  "Read one Clojure expression from STREAM using the specified readtable.

   Parameters:
   - stream: Input stream to read from
   - eof-error-p: If true, signal error on EOF; if false, return eof-value
   - eof-value: Value to return on EOF when eof-error-p is false
   - readtable: The readtable to use (defaults to *clojure-readtable*)

   Returns:
   The read expression (atom or compound object like list, vector, map, etc.)

   Examples:
     (fol-read (make-string-input-stream \"foo\"))      => FOO (symbol)
     (fol-read (make-string-input-stream \"(a b c)\"))  => (A B C) (list)
     (fol-read (make-string-input-stream \"[1 2 3]\"))  => [1 2 3] (vector)"

  (labels ((read-expr ()
             "Read one complete expression from the stream"
             (let ((chr (peek-char t stream eof-error-p nil)))
               ;; Check for EOF
               (unless chr
                 (return-from fol-read eof-value))

               ;; Look up the character in the readtable
               (let ((reader-fn (fol.collection:get readtable chr)))
                 (cond
                   ;; Found a reader function for this character
                   (reader-fn
                    (read-char stream) ; Consume the character
                    (funcall reader-fn chr))

                   ;; No reader function - this is an error
                   (t
                    (error "No reader function found for character ~S" chr)))))))

    (read-expr)))

(defun fol-read-from-string (string &optional (eof-error-p t) eof-value
                                      (readtable *fol-readtable*))
  "Read one Clojure expression from STRING using the specified readtable.

   Parameters:
   - string: Input string to read from
   - eof-error-p: If true, signal error on EOF; if false, return eof-value
   - eof-value: Value to return on EOF when eof-error-p is false
   - readtable: The readtable to use (defaults to *clojure-readtable*)

   Returns:
   Two values:
   1. The read expression (atom or compound object)
   2. The position in the string after reading

   Examples:
     (fol-read-from-string \"foo\")      => FOO, 3
     (fol-read-from-string \"(a b c)\")  => (A B C), 7
     (fol-read-from-string \"[1 2 3]\")  => [1 2 3], 7"

  (with-input-from-string (stream string)
    (let ((result (fol-read stream eof-error-p eof-value readtable)))
      (values result (file-position stream)))))

(defgeneric with-readtable (readtable form)
  (:documentation "Bind *fol-readtable* to READTABLE and use fol-read to read FORM.

   Parameters:
   - readtable: The readtable to use for reading
   - form: A string containing the form to read

   Returns:
   The read form

   Example:
     (with-readtable *fol-readtable* \"#{ 1 2 3 }\")"))

(defmethod with-readtable ((readtable <readtable>) (form string))
  "Read FORM using READTABLE by binding *fol-readtable*."
  (let ((*fol-readtable* readtable))
    (fol-read-from-string form)))