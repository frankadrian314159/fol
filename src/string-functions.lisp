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

(defun str-join (separator coll)
  "Join collection elements with SEPARATOR string.
   Elements are converted to strings via str.

   Examples:
     (str-join \", \" '(1 2 3))        => \"1, 2, 3\"
     (str-join \" \" #(\"a\" \"b\" \"c\")) => \"a b c\""
  (let ((seq (coerce coll 'list)))
    (if (null seq)
        ""
        (apply #'str
               (cons (first seq)
                     (mapcan (lambda (x) (list separator x))
                             (rest seq)))))))

(defun str-split (s pattern)
  "Split string S by PATTERN (string or regex).
   Returns vector of substrings.

   Examples:
     (str-split \"a,b,c\" \",\")       => #(\"a\" \"b\" \"c\")
     (str-split \"a  b  c\" \"\\\\s+\")  => #(\"a\" \"b\" \"c\")"
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

(defun str-trim (s)
  "Remove whitespace from both ends of string S.

   Examples:
     (str-trim \"  hello  \")  => \"hello\"
     (str-trim \"\\n\\ttest\\n\")  => \"test\""
  (string-trim '(#\Space #\Tab #\Newline #\Return) s))

(defun str-trim-left (s)
  "Remove whitespace from left end of string S."
  (string-left-trim '(#\Space #\Tab #\Newline #\Return) s))

(defun str-trim-right (s)
  "Remove whitespace from right end of string S."
  (string-right-trim '(#\Space #\Tab #\Newline #\Return) s))

(defun str-upper-case (s)
  "Convert string S to uppercase.

   Examples:
     (str-upper-case \"hello\")  => \"HELLO\""
  (string-upcase s))

(defun str-lower-case (s)
  "Convert string S to lowercase.

   Examples:
     (str-lower-case \"HELLO\")  => \"hello\""
  (string-downcase s))

(defun str-capitalize (s)
  "Capitalize first character of string S.

   Examples:
     (str-capitalize \"hello world\")  => \"Hello world\""
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

(defun str-starts-with? (s prefix)
  "Check if string S starts with PREFIX.

   Examples:
     (str-starts-with? \"hello\" \"he\")   => T
     (str-starts-with? \"hello\" \"lo\")   => NIL"
  (and (>= (length s) (length prefix))
       (string= s prefix :end1 (length prefix))))

(defun str-ends-with? (s suffix)
  "Check if string S ends with SUFFIX.

   Examples:
     (str-ends-with? \"hello\" \"lo\")  => T
     (str-ends-with? \"hello\" \"he\")  => NIL"
  (and (>= (length s) (length suffix))
       (string= s suffix :start1 (- (length s) (length suffix)))))

(defun str-contains? (s substring)
  "Check if string S contains SUBSTRING.

   Examples:
     (str-contains? \"hello\" \"ell\")  => T
     (str-contains? \"hello\" \"xyz\")  => NIL"
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

(defun str-blank? (s)
  "Check if string S is nil, empty, or contains only whitespace.

   Examples:
     (str-blank? \"\")         => T
     (str-blank? \"  \\n\\t\")   => T
     (str-blank? \"hello\")    => NIL
     (str-blank? nil)        => T"
  (or (null s)
      (zerop (length s))
      (every (lambda (c) (member c '(#\Space #\Tab #\Newline #\Return)))
             s)))

(defun str-reverse (s)
  "Reverse string S.

   Examples:
     (str-reverse \"hello\")  => \"olleh\""
  (reverse s))
