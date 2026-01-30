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
    ;; Note: fol-set-macro-character returns a new readtable (persistent)
    (loop for (key fn) on char-fn-pairs by #'cddr
          do (unless (functionp fn)
               (error "Expected a function, got ~A" fn))
             (cond
               ;; Single character
               ((characterp key)
                (setf readtable (fol-set-macro-character readtable key fn)))

               ;; List of characters
               ((listp key)
                (dolist (char key)
                  (unless (characterp char)
                    (error "Expected a character in list, got ~A" char))
                  (setf readtable (fol-set-macro-character readtable char fn))))

               ;; Symbol referring to a character class
               ((symbolp key)
                (unless character-class-table-or-nil
                  (error "Cannot use symbol ~A without a character class table" key))
                (let ((char-class (fol.seqop:get character-class-table-or-nil key)))
                  (unless char-class
                    (error "Character class ~A not found in character class table" key))
                  (dolist (char char-class)
                    (setf readtable (fol-set-macro-character readtable char fn)))))

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
  ;; Since readtable is persistent, set-pslot-value returns a new object
  (let ((items (fol.persistent:pslot-value readtable 'fol.collection::items)))
    (setf items (fset:with items char function))
    (fol.persistent:set-pslot-value readtable 'fol.collection::items items)))

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

  (let ((function (fol.seqop:get readtable char)))
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
  ;; Note: set-pslot-value returns a new readtable (persistent)
  (let ((dispatch-table (readtable-dispatch-table readtable)))
    (unless dispatch-table
      (setf dispatch-table (fol.collection:make-dict)))

    ;; Get or create the sub-table for this dispatch character
    (let ((sub-table (fol.seqop:get dispatch-table disp-char)))
      (unless sub-table
        (setf sub-table (fol.collection:make-dict)))

      ;; Add the function to the sub-table
      (setf sub-table (fol.seqop:add sub-table sub-char function))

      ;; Update the dispatch table
      (setf dispatch-table (fol.seqop:add dispatch-table disp-char sub-table))
      (fol.persistent:set-pslot-value readtable 'dispatch-table dispatch-table))))

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
      (let ((sub-table (fol.seqop:get dispatch-table disp-char)))
        (when sub-table
          (fol.seqop:get sub-table sub-char))))))

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
;;; Atom Reading and Parsing
;;; ============================================================================

(defun read-atom (stream chr)
  "Read a complete atom (symbol or number) starting with CHR.
   Continues reading until a delimiter or whitespace."
  (let ((chars (make-array 32 :element-type 'character :fill-pointer 0 :adjustable t)))
    ;; Add the first character
    (vector-push-extend chr chars)
    ;; Keep reading constituent characters
    (loop for next-chr = (peek-char nil stream nil nil)
          while (and next-chr
                     (not (member next-chr '(#\Space #\Tab #\Newline #\Return
                                             #\( #\) #\[ #\] #\{ #\}
                                             #\; #\" #\' #\` #\, #\@))))
          do (vector-push-extend (read-char stream) chars))
    ;; Convert to symbol or number
    (let ((atom-string (coerce chars 'string)))
      (or (parse-number atom-string)
          (cond
            ;; Keyword (starts with :)
            ((char= (char atom-string 0) #\:)
             (intern (string-upcase (subseq atom-string 1)) :keyword))
            ;; & is interned in keyword package (for destructuring)
            ((string= atom-string "&")
             (intern "&" :keyword))
            ;; Regular symbol
            (t
             (intern (string-upcase atom-string))))))))

(defun accumulate-atom (stream chr)
  "Read a complete atom starting with CHR."
  (read-atom stream chr))

(defun terminate-atom (stream chr)
  "Terminating characters - not used directly in fol-read."
  (declare (ignore stream chr))
  nil)

(defun valid-digit-for-base-p (char base)
  "Return T if CHAR is a valid digit for the given BASE (2-36)."
  (let ((code (char-code (char-upcase char))))
    (cond
      ;; 0-9 for bases up to 10
      ((and (>= code (char-code #\0))
            (<= code (char-code #\9)))
       (< (- code (char-code #\0)) base))
      ;; A-Z for bases above 10
      ((and (>= code (char-code #\A))
            (<= code (char-code #\Z)))
       (< (+ 10 (- code (char-code #\A))) base))
      (t nil))))

(defun parse-radix-number (string radix start)
  "Parse a number in the given RADIX starting at position START in STRING.
   Returns the parsed integer or NIL if invalid."
  (when (< start (length string))
    (let ((negative (char= (char string start) #\-)))
      (when negative (incf start))
      (when (>= start (length string))
        (return-from parse-radix-number nil))
      ;; Check all remaining characters are valid digits
      (loop for i from start below (length string)
            for c = (char string i)
            unless (valid-digit-for-base-p c radix)
              do (return-from parse-radix-number nil))
      ;; Parse the number
      (let ((value (parse-integer string :start start :radix radix :junk-allowed nil)))
        (if negative (- value) value)))))

(defun parse-number (string)
  "Try to parse a string as a number. Returns NIL if not a valid number.
   Supports:
   - Standard decimal integers and floats
   - Hexadecimal: 0xff or 0xFF or 16rff
   - Octal: 017 (leading zero followed by octal digits) or 8r777
   - Binary: 2r1011
   - Arbitrary base: NrDIGITS where N is 2-36 (e.g., 36rCRAZY)"
  (when (zerop (length string))
    (return-from parse-number nil))

  (let ((first-char (char string 0))
        (len (length string)))

    ;; Check for 0x or 0X prefix (hexadecimal)
    (when (and (>= len 2)
               (char= first-char #\0)
               (member (char string 1) '(#\x #\X)))
      (return-from parse-number
        (handler-case
            (parse-radix-number string 16 2)
          (error () nil))))

    ;; Check for NrDIGITS format (arbitrary base)
    (let ((r-pos (position #\r string :test #'char-equal)))
      (when (and r-pos (> r-pos 0))
        (handler-case
            (let* ((base-str (subseq string 0 r-pos))
                   (base (parse-integer base-str :junk-allowed nil)))
              (when (and base (>= base 2) (<= base 36))
                (return-from parse-number
                  (parse-radix-number string base (1+ r-pos)))))
          (error () nil))))

    ;; Check for octal (leading 0 followed by only octal digits)
    ;; But not "0" alone, not "0.x" (floats), and not negative
    (when (and (>= len 2)
               (char= first-char #\0)
               (not (member (char string 1) '(#\. #\x #\X)))
               (every (lambda (c) (octal-digit-p c)) (subseq string 1)))
      (return-from parse-number
        (handler-case
            (parse-integer string :radix 8)
          (error () nil))))

    ;; Fall back to standard CL number parsing
    (handler-case
        (let ((*read-default-float-format* 'double-float)
              (*read-eval* nil))
          (let ((result (read-from-string string)))
            (if (numberp result) result nil)))
      (error () nil))))

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
    (apply #'fol.collection:make-vector elements)))

(defun read-map (stream chr)
  "Read a Clojure map starting with {"
  (declare (ignore chr))
  (let ((pairs (fol-read-delimited-list #\} stream *clojure-readtable*)))
    (unless (evenp (length pairs))
      (error "Map literal must contain an even number of forms"))
    (apply #'fol.collection:make-dict pairs)))

(defun octal-digit-p (char)
  "Return T if CHAR is an octal digit (0-7)."
  (and (characterp char)
       (member char '(#\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7))))

(defun hex-digit-p (char)
  "Return T if CHAR is a hexadecimal digit."
  (and (characterp char)
       (or (digit-char-p char)
           (member char '(#\a #\b #\c #\d #\e #\f #\A #\B #\C #\D #\E #\F)))))

(defun parse-octal-escape (stream first-digit)
  "Parse an octal escape sequence starting with FIRST-DIGIT.
   Reads up to 2 more octal digits for a max of 3 digits total."
  (let ((digits (list first-digit)))
    ;; Read up to 2 more octal digits
    (dotimes (i 2)
      (let ((next (peek-char nil stream nil nil)))
        (when (and next (octal-digit-p next))
          (push (read-char stream) digits))))
    ;; Convert octal string to character
    (let ((code (parse-integer (coerce (nreverse digits) 'string) :radix 8)))
      (code-char code))))

(defun parse-unicode-escape (stream)
  "Parse a Unicode escape sequence (\\uXXXX - exactly 4 hex digits)."
  (let ((digits nil))
    (dotimes (i 4)
      (let ((c (read-char stream t nil t)))
        (unless (hex-digit-p c)
          (error "Invalid Unicode escape: expected hex digit, got ~C" c))
        (push c digits)))
    (let ((code (parse-integer (coerce (nreverse digits) 'string) :radix 16)))
      (code-char code))))

(defun read-string (stream chr)
  "Read a Clojure string starting with \"
   Supports escape sequences:
   - \\b (backspace), \\f (form feed), \\n (newline), \\t (tab), \\r (return)
   - \\\\ (backslash), \\\" (double quote)
   - \\OOO (octal escape, 1-3 digits)
   - \\uXXXX (Unicode escape, exactly 4 hex digits)"
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
              (cond
                ;; Standard escape characters
                ((char= next #\b) #\Backspace)
                ((char= next #\f) #\Page)
                ((char= next #\n) #\Newline)
                ((char= next #\t) #\Tab)
                ((char= next #\r) #\Return)
                ((char= next #\\) #\\)
                ((char= next #\") #\")
                ;; Unicode escape \uXXXX (case-insensitive)
                ((or (char= next #\u) (char= next #\U))
                 (parse-unicode-escape stream))
                ;; Octal escape \OOO
                ((octal-digit-p next)
                 (parse-octal-escape stream next))
                ;; Unknown escape - just use the character as-is
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
    (apply #'fol.collection:make-set elements)))

(defun read-regex-dispatch (stream char arg)
  "Read a regex pattern starting with #\" and return a <re-pattern> object.
   The pattern uses CL-PPCRE syntax (Perl-compatible regular expressions)."
  (declare (ignore char arg))
  ;; Read the regex pattern as a string and wrap it as <re-pattern>
  (let ((pattern (read-string stream #\")))
    (fol.string:wrap-re-pattern pattern)))

(defun read-var-quote-dispatch (stream char arg)
  "Read a Clojure var quote starting with #'"
  (declare (ignore char arg))
  (list 'var (fol-read stream t nil *clojure-readtable*)))

(defun arg-placeholder-p (sym)
  "Return T if SYM is an argument placeholder (%, %1, %2, ..., %&).
   Returns :REST for %&, or the argument number (1 for % or %1, 2 for %2, etc.)."
  (when (symbolp sym)
    (let ((name (symbol-name sym)))
      (when (and (> (length name) 0)
                 (char= (char name 0) #\%))
        (cond
          ;; %& is rest args
          ((string= name "%&") :rest)
          ;; % alone means %1
          ((= (length name) 1) 1)
          ;; %N where N is a digit
          ((and (> (length name) 1)
                (every #'digit-char-p (subseq name 1)))
           (parse-integer (subseq name 1)))
          (t nil))))))

(defun find-arg-placeholders (form)
  "Walk FORM and return a list of (position . placeholder-type).
   placeholder-type is :rest for %& or a number for %1, %2, etc."
  (let ((found nil))
    (labels ((walk (x)
               (cond
                 ((symbolp x)
                  (let ((arg-type (arg-placeholder-p x)))
                    (when arg-type
                      (pushnew arg-type found))))
                 ((consp x)
                  (walk (car x))
                  (walk (cdr x)))
                 ;; Handle FOL vectors
                 ((fol.collection:<vector>? x)
                  (fset:do-seq (elem (slot-value x 'fol.collection::items))
                    (walk elem)))
                 ;; Handle FOL dicts
                 ((fol.collection:<dict>? x)
                  (fset:do-map (k v (slot-value x 'fol.collection::items))
                    (walk k)
                    (walk v)))
                 ;; Handle FOL lists
                 ((fol.collection:<list>? x)
                  (let ((current x))
                    (loop while (and current (> (fol.collection:list-size current) 0))
                          do (walk (fol.collection:list-first current))
                             (setf current (fol.collection:list-rest current))))))))
      (walk form)
      found)))

(defun replace-arg-placeholders (form arg-symbols rest-symbol)
  "Replace argument placeholders in FORM with actual symbols.
   ARG-SYMBOLS is a vector mapping position -> symbol.
   REST-SYMBOL is the symbol for %&, or NIL if not used."
  (labels ((replace-in (x)
             (cond
               ((symbolp x)
                (let ((arg-type (arg-placeholder-p x)))
                  (cond
                    ((eq arg-type :rest) (or rest-symbol x))
                    ((integerp arg-type) (aref arg-symbols (1- arg-type)))
                    (t x))))
               ((consp x)
                (cons (replace-in (car x))
                      (replace-in (cdr x))))
               ;; Handle FOL vectors
               ((fol.collection:<vector>? x)
                (let ((new-items nil))
                  (fset:do-seq (elem (slot-value x 'fol.collection::items))
                    (push (replace-in elem) new-items))
                  (apply #'fol.collection:make-vector (nreverse new-items))))
               ;; Handle FOL dicts
               ((fol.collection:<dict>? x)
                (let ((new-dict (fol.collection:make-dict)))
                  (fset:do-map (k v (slot-value x 'fol.collection::items))
                    (setf new-dict (fol.seqop:add new-dict
                                                       (replace-in k)
                                                       (replace-in v))))
                  new-dict))
               ;; Handle FOL lists
               ((fol.collection:<list>? x)
                (let ((items nil)
                      (current x))
                  (loop while (and current (> (fol.collection:list-size current) 0))
                        do (push (replace-in (fol.collection:list-first current)) items)
                           (setf current (fol.collection:list-rest current)))
                  (apply #'fol.collection:make-list (nreverse items))))
               (t x))))
    (replace-in form)))

(defun read-fn-dispatch (stream char arg)
  "Read a Clojure anonymous function literal #(...).
   Supports argument placeholders:
   - % or %1 -> first argument
   - %2, %3, ... -> second, third, etc. argument
   - %& -> rest arguments
   Example: #(+ %1 %2) => (fn [arg1 arg2] (+ arg1 arg2))"
  (declare (ignore char arg))
  (let* ((body-list (fol-read-delimited-list #\) stream *clojure-readtable*))
         ;; The body IS the list of items read - it's a function call form
         ;; e.g., #(+ % 1) => body = (+ % 1), which calls + with args
         (body body-list)
         (placeholders (find-arg-placeholders body))
         (has-rest (member :rest placeholders))
         (max-arg (let ((nums (remove-if-not #'integerp placeholders)))
                    (if nums (apply #'max nums) 0))))
    ;; If no placeholders found, treat as zero-arg function
    (if (and (= max-arg 0) (not has-rest))
        (list 'fn (fol.collection:make-vector) body)
        ;; Generate parameter symbols and build the function
        (let* ((arg-symbols (make-array max-arg))
               (rest-symbol (when has-rest (gensym "REST")))
               (params nil))
          ;; Create gensyms for each positional argument
          (dotimes (i max-arg)
            (setf (aref arg-symbols i) (gensym (format nil "ARG~D-" (1+ i)))))
          ;; Build parameter list
          (dotimes (i max-arg)
            (push (aref arg-symbols i) params))
          (setf params (nreverse params))
          ;; Add rest parameter if needed
          (when has-rest
            (setf params (append params (list '& rest-symbol))))
          ;; Replace placeholders in body and build fn form
          (let ((new-body (replace-arg-placeholders body arg-symbols rest-symbol)))
            (list 'fn (apply #'fol.collection:make-vector params) new-body))))))

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
      (apply #'fol.collection:make-bag elements))))

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
      ;; Note: fol-set-dispatch-macro-character returns a new readtable (persistent)

      ;; #{ - set literal
      (setf readtable (fol-set-dispatch-macro-character readtable #\# #\{ #'read-set-dispatch))

      ;; #M{ - multiset (bag) literal
      (setf readtable (fol-set-dispatch-macro-character readtable #\# #\M #'read-multiset-dispatch))

      ;; #" - regex literal
      (setf readtable (fol-set-dispatch-macro-character readtable #\# #\" #'read-regex-dispatch))

      ;; #' - var quote
      (setf readtable (fol-set-dispatch-macro-character readtable #\# #\' #'read-var-quote-dispatch))

      ;; #( - anonymous function
      (setf readtable (fol-set-dispatch-macro-character readtable #\# #\( #'read-fn-dispatch))

      ;; #_ - ignore next form
      (setf readtable (fol-set-dispatch-macro-character readtable #\# #\_ #'read-ignore-dispatch))

      ;; #? - reader conditional
      (setf readtable (fol-set-dispatch-macro-character readtable #\# #\? #'read-conditional-dispatch))

      ;; ## - symbolic value
      (setf readtable (fol-set-dispatch-macro-character readtable #\# #\# #'read-symbolic-value-dispatch))

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
               (let ((reader-fn (fol.seqop:get readtable chr)))
                 (cond
                   ;; Found a reader function for this character
                   (reader-fn
                    (read-char stream) ; Consume the character
                    (funcall reader-fn stream chr))

                   ;; No reader function - this is an error
                   (t
                    (error "No reader function found for character ~S" chr)))))))

    (read-expr)))

(defun fol-read-from-string (string &optional (eof-error-p t) eof-value
                                      (readtable *clojure-readtable*))
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

(defgeneric with-readtable (readtable source)
  (:documentation "Bind *fol-readtable* to READTABLE and use fol-read to read source.

   Parameters:
   - readtable: The readtable to use for reading
   - source: A string or input stream containing the form to read
   Returns:
   The read form

   Example:
     (with-readtable *fol-readtable* \"#{ 1 2 3 }\")"))

(defmethod with-readtable ((readtable <readtable>) (source <string>))
  "Read FORM using READTABLE by binding *fol-readtable*."
  (let ((*fol-readtable* readtable))
    (fol-read-from-string source)))

(let ((eof-symbol '***EOF***))
  (defmethod with-readtable ((readtable <readtable>) (stream <input-stream>))
    "Read all forms from STREAM using READTABLE until EOF."
    (let ((*fol-readtable* readtable)
          (eof-value eof-symbol))
      (loop for form = (fol-read stream nil eof-value)
            until (eq form eof-value)
            collect form))))