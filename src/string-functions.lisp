;;; String manipulation functions for FOL
;;; Provides Clojure-style string operations

(in-package :fol.compiler.string-functions)

(defun str (&rest args)
  "Concatenate arguments into a string (Clojure-style).
   - nil becomes empty string
   - strings are used as-is
   - other values are converted via prin1-to-string

   Examples:
     (str \"hello\" \" \" \"world\")  => \"hello world\"
     (str \"x=\" 42)                  => \"x=42\"
     (str nil \"foo\" nil)            => \"foo\"
     (str)                            => \"\""
  (apply #'concatenate 'string
    (mapcar (lambda (arg)
              (typecase arg
                (string arg)
                (character (string arg))
                (null "")
                (t (prin1-to-string arg))))
        args)))

(defun size (s)
  "Return the length of string S.
   Example: (size \"hello\") => 5"
  (length s))

(defun subs (s start &optional end)
  "Return substring of S from START to END (exclusive).
   If END is omitted, returns from START to end of string.
   Negative indices count from end.

   Examples:
     (subs \"hello\" 1 4)    => \"ell\"
     (subs \"hello\" 2)      => \"llo\"
     (subs \"hello\" -3)     => \"llo\""
  (let* ((len (length s))
         (actual-start (if (minusp start) (+ len start) start))
         (actual-end (if end
                         (if (minusp end) (+ len end) end)
                         len)))
    (subseq s actual-start actual-end)))

(defun split (s pattern)
  "Split string S by PATTERN (string or regex).
   Returns vector of substrings.

   Examples:
     (split \"a,b,c\" \",\")       => #(\"a\" \"b\" \"c\")
     (split \"a  b  c\" \"\\\\s+\")  => #(\"a\" \"b\" \"c\")"
  (if (stringp pattern)
      ;; Simple string split
      (let ((parts '())
            (start 0)
            (pattern-len (length pattern)))
        (loop
         (let ((pos (search pattern s :start2 start)))
           (if pos
               (progn
                (push (subseq s start pos) parts)
                (setf start (+ pos pattern-len)))
               (progn
                (push (subseq s start) parts)
                (return)))))
        (coerce (nreverse parts) 'vector))
      ;; Regex split (requires cl-ppcre)
      (coerce (cl-ppcre:split pattern s) 'vector)))

(defun trim (s)
  "Remove whitespace from both ends of string S.

   Examples:
     (trim \"  hello  \")  => \"hello\"
     (trim \"\\n\\ttest\\n\")  => \"test\""
  (string-trim '(#\Space #\Tab #\Newline #\Return) s))

(defun triml (s)
  "Remove whitespace from left end of string S.

   Examples:
     (triml \"  hello\")  => \"hello\""
  (string-left-trim '(#\Space #\Tab #\Newline #\Return) s))

(defun trimr (s)
  "Remove whitespace from right end of string S.

   Examples:
     (trimr \"hello  \")  => \"hello\""
  (string-right-trim '(#\Space #\Tab #\Newline #\Return) s))

(defun trim-newline (s)
  "Remove all trailing newline characters (\\n and \\r) from string S.

   Examples:
     (trim-newline \"hello\\n\")     => \"hello\"
     (trim-newline \"hello\\r\\n\")   => \"hello\"
     (trim-newline \"hello\\n\\n\")   => \"hello\""
  (string-right-trim '(#\Newline #\Return) s))

(defun upper-case (s)
  "Convert string S to uppercase.

   Examples:
     (upper-case \"hello\")  => \"HELLO\""
  (string-upcase s))

(defun lower-case (s)
  "Convert string S to lowercase.

   Examples:
     (lower-case \"HELLO\")  => \"hello\""
  (string-downcase s))

(defun capitalize (s)
  "Capitalize first character of string S.

   Examples:
     (capitalize \"hello world\")  => \"Hello world\""
  (if (zerop (length s))
      s
      (concatenate 'string
        (string-upcase (subseq s 0 1))
        (subseq s 1))))

(defun str-replace (s match replacement)
  "Replace all occurrences of MATCH with REPLACEMENT in string S.
   MATCH can be a string or regex pattern.

   Examples:
     (str-replace \"hello world\" \"world\" \"FOL\")  => \"hello FOL\"
     (str-replace \"a1b2c3\" \"\\\\d\" \"X\")          => \"aXbXcX\""
  (if (stringp match)
      ;; Simple string replacement
      (let ((result s)
            (match-len (length match))
            (repl-len (length replacement)))
        (loop
         (let ((pos (search match result)))
           (if pos
               (setf result (concatenate 'string
                              (subseq result 0 pos)
                              replacement
                              (subseq result (+ pos match-len))))
               (return result)))))
      ;; Regex replacement (requires cl-ppcre)
      (cl-ppcre:regex-replace-all match s replacement)))

(defun starts-with? (s prefix)
  "Check if string S starts with PREFIX.

   Examples:
     (starts-with? \"hello\" \"he\")   => T
     (starts-with? \"hello\" \"lo\")   => NIL"
  (and (>= (length s) (length prefix))
       (string= s prefix :end1 (length prefix))))

(defun ends-with? (s suffix)
  "Check if string S ends with SUFFIX.

   Examples:
     (ends-with? \"hello\" \"lo\")  => T
     (ends-with? \"hello\" \"he\")  => NIL"
  (and (>= (length s) (length suffix))
       (string= s suffix :start1 (- (length s) (length suffix)))))

(defun includes? (s substring)
  "Check if string S contains SUBSTRING (Clojure-style alias for contains).

   Examples:
     (includes? \"hello\" \"ell\")  => T
     (includes? \"hello\" \"xyz\")  => NIL"
  (not (null (search substring s))))

(defun str-index-of (s substring &optional from-index)
  "Find first index of SUBSTRING in S, starting from FROM-INDEX.
   Returns NIL if not found.

   Examples:
     (str-index-of \"hello\" \"l\")      => 2
     (str-index-of \"hello\" \"l\" 3)   => 3
     (str-index-of \"hello\" \"x\")     => NIL"
  (search substring s :start2 (or from-index 0)))

(defun str-last-index-of (s substring)
  "Find last index of SUBSTRING in S.
   Returns NIL if not found.

   Examples:
     (str-last-index-of \"hello\" \"l\")  => 3
     (str-last-index-of \"hello\" \"x\")  => NIL"
  (search substring s :from-end t))

(defun blank? (s)
  "Check if string S is nil, empty, or contains only whitespace.

   Examples:
     (blank? \"\")         => T
     (blank? \"  \\n\\t\")   => T
     (blank? \"hello\")    => NIL
     (blank? nil)        => T"
  (or (null s)
      (zerop (length s))
      (every (lambda (c) (member c '(#\Space #\Tab #\Newline #\Return)))
          s)))

(defun str-reverse (s)
  "Reverse string S.

   Examples:
     (str-reverse \"hello\")  => \"olleh\""
  (reverse s))

(defun format (destination control-string &rest args)
  "Format output using Common Lisp's format function.
   DESTINATION can be:
     - NIL: returns a string
     - T: outputs to *standard-output* and returns NIL
     - a stream: outputs to the stream and returns NIL
   CONTROL-STRING contains format directives (~A, ~D, ~%, etc.)

   Examples:
     (format nil \"x=~A\" 42)           => \"x=42\"
     (format nil \"~A + ~A = ~A\" 1 2 3) => \"1 + 2 = 3\"
     (format t \"Hello~%\")              => NIL (prints to stdout)"
  (apply #'cl:format destination control-string args))

(defun char (s index)
  "Returns the character at INDEX in string S (Clojure-style).
   Throws an error if index is out of bounds.

   Examples:
     (char \"hello\" 0)  => #\\h
     (char \"hello\" 4)  => #\\o"
  (unless (and (>= index 0) (< index (length s)))
    (error "String index out of bounds: ~A (string length: ~A)" index (length s)))
  (cl:char s index))

(defun char-name-string (c)
  "Returns the name of character C as a string, or NIL if unnamed.
   Named characters: newline, space, tab, return, backspace, formfeed.

   Examples:
     (char-name-string #\\Newline)    => \"newline\"
     (char-name-string #\\Space)      => \"space\"
     (char-name-string #\\a)          => NIL"
  (cond
   ((char= c #\Newline) "newline")
   ((char= c #\Space) "space")
   ((char= c #\Tab) "tab")
   ((char= c #\Return) "return")
   ((char= c #\Backspace) "backspace")
   ((char= c (code-char 12)) "formfeed")
   (t nil)))

(defun char-escape-string (c)
  "Returns the escape sequence for character C as a string.
   Returns the short form (\\n, \\t, etc.) for common characters,
   or the long form (\\newline, \\space, etc.) for others.

   Examples:
     (char-escape-string #\\Newline)   => \"\\\\n\"
     (char-escape-string #\\Tab)       => \"\\\\t\"
     (char-escape-string #\\Space)     => \"\\\\space\"
     (char-escape-string #\\a)         => \"\\\\a\""
  (cond
   ((char= c #\Newline) "\\n")
   ((char= c #\Tab) "\\t")
   ((char= c #\Return) "\\r")
   ((char= c #\Backspace) "\\b")
   ((char= c (code-char 12)) "\\f")
   ((char= c #\Space) "\\space")
   (t (format nil "\\~C" c))))

(defun compare (s1 s2)
  "Compare two strings lexicographically.
   Returns:
     - negative number if S1 < S2
     - 0 if S1 = S2
     - positive number if S1 > S2

   Examples:
     (compare \"abc\" \"abc\")   => 0
     (compare \"abc\" \"xyz\")   => negative
     (compare \"xyz\" \"abc\")   => positive"
  (cond ((string= s1 s2) 0)
        ((string< s1 s2) -1)
        (t 1)))

(defun escape (s char-escape-map)
  "Escape characters in string S using CHAR-ESCAPE-MAP.
   CHAR-ESCAPE-MAP is an association list of (char . replacement-string).

   Examples:
     (escape \"<foo>\" '((#\\< . \"&lt;\") (#\\> . \"&gt;\")))
       => \"&lt;foo&gt;\"
     (escape \"a'b\" '((#\\' . \"\\\\'\")))"
  (with-output-to-string (out)
    (loop for c across s
          do (let ((replacement (cdr (assoc c char-escape-map))))
               (if replacement
                   (write-string replacement out)
                   (write-char c out))))))

(defun split-lines (s)
  "Split string S on line breaks (\\n or \\r\\n).
   Returns a vector of lines (without the line breaks).

   Examples:
     (split-lines \"a\\nb\\nc\")        => #(\"a\" \"b\" \"c\")
     (split-lines \"a\\r\\nb\\r\\nc\")  => #(\"a\" \"b\" \"c\")
     (split-lines \"single line\")     => #(\"single line\")"
  (let ((lines '())
        (start 0)
        (len (length s))
        (i 0))
    (loop while (< i len)
          do (cond
              ;; Found \r\n
              ((and (char= (char s i) #\Return)
                    (< (1+ i) len)
                    (char= (char s (1+ i)) #\Newline))
                (push (subseq s start i) lines)
                (setf start (+ i 2))
                (setf i (+ i 2)))
              ;; Found \n
              ((char= (char s i) #\Newline)
                (push (subseq s start i) lines)
                (setf start (1+ i))
                (incf i))
              ;; Regular character
              (t
                (incf i))))
    ;; Add remaining part if any
    (when (<= start len)
          (push (subseq s start) lines))
    (coerce (nreverse lines) 'vector)))

;;; ============================================================================
;;; Parsing functions
;;; ============================================================================

(defun parse-boolean (bool-string)
  "Parse a boolean string and return T or NIL.
   Recognizes (case-insensitive): T, TRUE, NIL, FALSE, F.
   Returns T for T/TRUE, NIL for NIL/FALSE/F.

   Examples:
     (parse-boolean \"true\")  => T
     (parse-boolean \"T\")     => T
     (parse-boolean \"false\") => NIL
     (parse-boolean \"F\")     => NIL
     (parse-boolean \"nil\")   => NIL"
  (unless (stringp bool-string)
    (error "Expected a string for parse-boolean, got ~A" (type-of bool-string)))
  (let ((upper (string-upcase (string-trim '(#\Space #\Tab #\Newline #\Return) bool-string))))
    (cond ((member upper '("T" "TRUE") :test #'string=) t)
          ((member upper '("NIL" "FALSE" "F") :test #'string=) nil)
          (t (error "Invalid boolean string ~S. Expected T, TRUE, NIL, FALSE, or F" bool-string)))))

(defun parse-uuid (uuid-string)
  "Parse a UUID string and return a UUID object.
   UUID-STRING should be in standard UUID format (8-4-4-4-12 hex digits).

   Examples:
     (parse-uuid \"550e8400-e29b-41d4-a716-446655440000\") => #<UUID ...>
     (parse-uuid \"550E8400-E29B-41D4-A716-446655440000\") => #<UUID ...>"
  (unless (stringp uuid-string)
    (error "Expected a string for parse-uuid, got ~A" (type-of uuid-string)))
  (handler-case
      (uuid:make-uuid-from-string uuid-string)
    (error (e)
      (error "Invalid UUID string ~S: ~A" uuid-string e))))

;;; ============================================================================
;;; Generic Clojure-style string functions (with char/string/regex support)
;;; ============================================================================

(defgeneric replace-first (s match replacement &key use-regex)
  (:documentation "Replace first occurrence of MATCH with REPLACEMENT in string S.
                   MATCH can be a character or string.
                   If :use-regex T, MATCH is treated as a CL-PPCRE regex pattern."))

(defmethod replace-first ((s string) (match character) (replacement string) &key use-regex)
  "Replace first occurrence of character MATCH with REPLACEMENT."
  (declare (ignore use-regex))
  (let ((pos (position match s)))
    (if pos
        (concatenate 'string
          (subseq s 0 pos)
          replacement
          (subseq s (1+ pos)))
        s)))

(defmethod replace-first ((s string) (match string) (replacement string) &key use-regex)
  "Replace first occurrence of string MATCH with REPLACEMENT.
   If :use-regex T, MATCH is a regex pattern."
  (if use-regex
      ;; Regex replacement using CL-PPCRE
      (cl-ppcre:regex-replace match s replacement)
      ;; Literal string replacement
      (let ((pos (search match s)))
        (if pos
            (concatenate 'string
              (subseq s 0 pos)
              replacement
              (subseq s (+ pos (length match))))
            s))))

(defgeneric reverse (s)
  (:documentation "Reverse string S."))

(defmethod reverse ((s string))
  "Reverse a string."
  (cl:reverse s))

(defgeneric index-of (s match &key from-index use-regex)
  (:documentation "Find first index of MATCH in S, starting from FROM-INDEX.
                   MATCH can be a character or string.
                   If :use-regex T, MATCH is treated as a CL-PPCRE regex pattern.
                   Returns NIL if not found."))

(defmethod index-of ((s string) (match character) &key from-index use-regex)
  "Find first index of character MATCH in S."
  (declare (ignore use-regex))
  (position match s :start (or from-index 0)))

(defmethod index-of ((s string) (match string) &key from-index use-regex)
  "Find first index of string MATCH in S.
   If :use-regex T, MATCH is a regex pattern."
  (if use-regex
      ;; Regex search using CL-PPCRE
      (multiple-value-bind (match-start match-end)
          (cl-ppcre:scan match s :start (or from-index 0))
        (declare (ignore match-end))
        match-start)
      ;; Literal string search
      (search match s :start2 (or from-index 0))))

(defgeneric last-index-of (s match &key use-regex)
  (:documentation "Find last index of MATCH in S.
                   MATCH can be a character or string.
                   If :use-regex T, MATCH is treated as a CL-PPCRE regex pattern.
                   Returns NIL if not found."))

(defmethod last-index-of ((s string) (match character) &key use-regex)
  "Find last index of character MATCH in S."
  (declare (ignore use-regex))
  (position match s :from-end t))

(defmethod last-index-of ((s string) (match string) &key use-regex)
  "Find last index of string MATCH in S.
   If :use-regex T, MATCH is a regex pattern."
  (if use-regex
      ;; CL-PPCRE doesn't have built-in :from-end, so we find all matches
      (let ((last-pos nil))
        (cl-ppcre:do-matches (start end match s)
          (declare (ignore end))
          (setf last-pos start))
        last-pos)
      ;; Literal string search
      (search match s :from-end t)))

;;; ============================================================================
;;; Regular Expression Functions (Clojure-style)
;;; ============================================================================

(defun re-pattern (pattern-string)
  "Compile a regex pattern string into a CL-PPCRE scanner.
   The #\"pattern\" reader macro returns a string, which can be passed here
   to create a compiled scanner for better performance.

   Examples:
     (re-pattern \"\\\\d+\")       => compiled scanner
     (re-pattern #\"\\d+\")      => compiled scanner (using reader macro)"
  (unless (stringp pattern-string)
    (error "Expected a string for re-pattern, got ~A" (type-of pattern-string)))
  (cl-ppcre:create-scanner pattern-string))

(defun re-find (pattern string &optional (start 0))
  "Find the first match of PATTERN in STRING, starting at START position.
   PATTERN can be a string or compiled scanner.
   Returns the matched substring, or NIL if no match found.
   If the pattern has capture groups, returns a vector: [full-match group1 group2 ...]

   Examples:
     (re-find \"\\\\d+\" \"abc123def\")     => \"123\"
     (re-find \"(\\\\d+)\" \"abc123def\")   => #(\"123\" \"123\")
     (re-find \"xyz\" \"abc123def\")      => NIL"
  (multiple-value-bind (match-start match-end reg-starts reg-ends)
      (cl-ppcre:scan pattern string :start start)
    (when match-start
          (if (and reg-starts (plusp (length reg-starts)))
              ;; Has capture groups - return vector of [full-match group1 group2 ...]
              (let ((result (make-array (1+ (length reg-starts)))))
                (setf (aref result 0) (subseq string match-start match-end))
                (loop for i from 0 below (length reg-starts)
                      do (setf (aref result (1+ i))
                           (if (aref reg-starts i)
                               (subseq string (aref reg-starts i) (aref reg-ends i))
                               nil)))
                result)
              ;; No capture groups - return just the match
              (subseq string match-start match-end)))))

(defun re-seq (pattern string)
  "Return a vector of all matches of PATTERN in STRING.
   If the pattern has capture groups, each match is a vector: [full-match group1 group2 ...]
   If no capture groups, each match is just the matched string.

   Examples:
     (re-seq \"\\\\d+\" \"a1b22c333\")      => #(\"1\" \"22\" \"333\")
     (re-seq \"(\\\\d+)\" \"a1b22c333\")    => #(#(\"1\" \"1\") #(\"22\" \"22\") #(\"333\" \"333\"))"
  (let ((matches '())
        (start 0))
    (loop
     (multiple-value-bind (match-start match-end reg-starts reg-ends)
         (cl-ppcre:scan pattern string :start start)
       (unless match-start
         (return))
       (push
         (if (and reg-starts (plusp (length reg-starts)))
             ;; Has capture groups
             (let ((result (make-array (1+ (length reg-starts)))))
               (setf (aref result 0) (subseq string match-start match-end))
               (loop for i from 0 below (length reg-starts)
                     do (setf (aref result (1+ i))
                          (if (aref reg-starts i)
                              (subseq string (aref reg-starts i) (aref reg-ends i))
                              nil)))
               result)
             ;; No capture groups
             (subseq string match-start match-end))
         matches)
       (setf start match-end)
       ;; Prevent infinite loop on zero-length matches
       (when (= match-start match-end)
             (incf start))))
    (coerce (nreverse matches) 'vector)))

(defun re-matches (pattern string)
  "Check if the entire STRING matches PATTERN.
   Returns the matched string (or vector with groups) if it matches, NIL otherwise.
   Unlike re-find, this requires the pattern to match the entire string.

   Examples:
     (re-matches \"\\\\d+\" \"123\")        => \"123\"
     (re-matches \"\\\\d+\" \"abc123\")     => NIL (doesn't match entire string)
     (re-matches \"(\\\\d+)\" \"123\")      => #(\"123\" \"123\")"
  (multiple-value-bind (match-start match-end reg-starts reg-ends)
      (cl-ppcre:scan pattern string)
    ;; Must match entire string (start at 0, end at length)
    (when (and match-start
               (= match-start 0)
               (= match-end (length string)))
          (if (and reg-starts (plusp (length reg-starts)))
              ;; Has capture groups
              (let ((result (make-array (1+ (length reg-starts)))))
                (setf (aref result 0) (subseq string match-start match-end))
                (loop for i from 0 below (length reg-starts)
                      do (setf (aref result (1+ i))
                           (if (aref reg-starts i)
                               (subseq string (aref reg-starts i) (aref reg-ends i))
                               nil)))
                result)
              ;; No capture groups
              (subseq string match-start match-end)))))

(defun re-matcher (pattern string)
  "Create a compiled scanner for PATTERN.
   In Clojure, this returns a stateful Matcher object, but CL-PPCRE doesn't have
   stateful matchers. This function simply compiles the pattern for reuse.
   Use re-find, re-seq, or re-matches with the result.

   Examples:
     (let ((scanner (re-matcher \"\\\\d+\" \"unused\")))
       (re-find scanner \"abc123def\"))   => \"123\""
  (declare (ignore string))
  (if (stringp pattern)
      (cl-ppcre:create-scanner pattern)
      pattern))

(defun re-quote-replacement (replacement-string)
  "Quote special characters in REPLACEMENT-STRING so it can be used literally
   in regex replacement operations. Escapes backslashes and dollar signs which
   have special meaning in CL-PPCRE replacement strings.

   Examples:
     (re-quote-replacement \"$1.00\")     => \"\\\\$1.00\"
     (re-quote-replacement \"a\\\\b\")      => \"a\\\\\\\\b\"
     (re-quote-replacement \"normal\")    => \"normal\""
  (unless (stringp replacement-string)
    (error "Expected a string for re-quote-replacement, got ~A" (type-of replacement-string)))
  (with-output-to-string (out)
    (loop for c across replacement-string
          do (case c
               ((#\\ #\$)
                (write-char #\\ out)
                (write-char c out))
               (t
                (write-char c out))))))
