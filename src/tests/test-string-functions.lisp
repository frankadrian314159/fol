;;; FOL Compiler Tests - String Functions

(in-package :fol.compiler.tests)

(in-suite string-tests)

;;; ---------------------------------------------------------------------------
;;; format function
;;; ---------------------------------------------------------------------------

(test format-nil-destination
  "format with NIL destination returns a string."
  (is (string= "hello world"
               (fol.compiler.string-functions:format nil "hello world"))))

(test format-with-args
  "format can interpolate arguments."
  (is (string= "x=42"
               (fol.compiler.string-functions:format nil "x=~A" 42))))

(test format-multiple-args
  "format can handle multiple arguments."
  (is (string= "1 + 2 = 3"
               (fol.compiler.string-functions:format nil "~A + ~A = ~A" 1 2 3))))

(test format-integer-directive
  "format ~D directive formats integers."
  (is (string= "The answer is 42"
               (fol.compiler.string-functions:format nil "The answer is ~D" 42))))

(test format-newline
  "format ~% inserts newline."
  (is (string= (concatenate 'string "line1" (string #\Newline) "line2")
               (fol.compiler.string-functions:format nil "line1~%line2"))))

;;; ---------------------------------------------------------------------------
;;; size function
;;; ---------------------------------------------------------------------------

(test size-empty-string
  "size of empty string is 0."
  (is (= 0 (fol.compiler.string-functions:size ""))))

(test size-single-char
  "size of single character string is 1."
  (is (= 1 (fol.compiler.string-functions:size "x"))))

(test size-normal-string
  "size returns the length of a string."
  (is (= 5 (fol.compiler.string-functions:size "hello"))))

(test size-with-spaces
  "size counts spaces."
  (is (= 11 (fol.compiler.string-functions:size "hello world"))))

(test size-unicode
  "size counts characters (not bytes)."
  (is (= 3 (fol.compiler.string-functions:size "a§c"))))

;;; ---------------------------------------------------------------------------
;;; compare function
;;; ---------------------------------------------------------------------------

(test compare-equal-strings
  "compare returns 0 for equal strings."
  (is (= 0 (fol.compiler.string-functions:compare "abc" "abc"))))

(test compare-less-than
  "compare returns negative for s1 < s2."
  (is (< (fol.compiler.string-functions:compare "abc" "xyz") 0)))

(test compare-greater-than
  "compare returns positive for s1 > s2."
  (is (> (fol.compiler.string-functions:compare "xyz" "abc") 0)))

(test compare-empty-strings
  "compare handles empty strings."
  (is (= 0 (fol.compiler.string-functions:compare "" ""))))

(test compare-empty-vs-nonempty
  "compare: empty string is less than non-empty."
  (is (< (fol.compiler.string-functions:compare "" "a") 0)))

(test compare-prefix
  "compare: prefix is less than longer string."
  (is (< (fol.compiler.string-functions:compare "abc" "abcd") 0)))

(test compare-case-sensitive
  "compare is case-sensitive."
  (is (not (= 0 (fol.compiler.string-functions:compare "abc" "ABC")))))

;;; ---------------------------------------------------------------------------
;;; escape function
;;; ---------------------------------------------------------------------------

(test escape-html-chars
  "escape can escape HTML special characters."
  (is (string= "&lt;foo&gt;"
               (fol.compiler.string-functions:escape
                "<foo>"
                '((#\< . "&lt;") (#\> . "&gt;"))))))

(test escape-quotes
  "escape can escape quote characters."
  (is (string= "a\\'b"
               (fol.compiler.string-functions:escape
                "a'b"
                '((#\' . "\\'"))))))

(test escape-multiple-chars
  "escape handles multiple different characters."
  (is (string= "&lt;a&amp;b&gt;"
               (fol.compiler.string-functions:escape
                "<a&b>"
                '((#\< . "&lt;") (#\> . "&gt;") (#\& . "&amp;"))))))

(test escape-no-matching-chars
  "escape returns original string when no chars match."
  (is (string= "hello"
               (fol.compiler.string-functions:escape
                "hello"
                '((#\< . "&lt;") (#\> . "&gt;"))))))

(test escape-empty-string
  "escape handles empty string."
  (is (string= ""
               (fol.compiler.string-functions:escape
                ""
                '((#\< . "&lt;"))))))

(test escape-empty-map
  "escape with empty map returns original string."
  (is (string= "hello"
               (fol.compiler.string-functions:escape "hello" '()))))

;;; ---------------------------------------------------------------------------
;;; split-lines function
;;; ---------------------------------------------------------------------------

(test split-lines-newline
  "split-lines splits on \\n."
  (let ((result (fol.compiler.string-functions:split-lines (format nil "a~Cb~Cc" #\Newline #\Newline))))
    (is (vectorp result))
    (is (= 3 (length result)))
    (is (string= "a" (aref result 0)))
    (is (string= "b" (aref result 1)))
    (is (string= "c" (aref result 2)))))

(test split-lines-crlf
  "split-lines splits on \\r\\n."
  (let ((result (fol.compiler.string-functions:split-lines (format nil "a~C~Cb~C~Cc" #\Return #\Newline #\Return #\Newline))))
    (is (vectorp result))
    (is (= 3 (length result)))
    (is (string= "a" (aref result 0)))
    (is (string= "b" (aref result 1)))
    (is (string= "c" (aref result 2)))))

(test split-lines-mixed
  "split-lines handles mixed line endings."
  (let ((result (fol.compiler.string-functions:split-lines (format nil "a~Cb~C~Cc" #\Newline #\Return #\Newline))))
    (is (vectorp result))
    (is (= 3 (length result)))
    (is (string= "a" (aref result 0)))
    (is (string= "b" (aref result 1)))
    (is (string= "c" (aref result 2)))))

(test split-lines-single-line
  "split-lines returns single element for string without line breaks."
  (let ((result (fol.compiler.string-functions:split-lines "single line")))
    (is (vectorp result))
    (is (= 1 (length result)))
    (is (string= "single line" (aref result 0)))))

(test split-lines-empty-string
  "split-lines handles empty string."
  (let ((result (fol.compiler.string-functions:split-lines "")))
    (is (vectorp result))
    (is (= 1 (length result)))
    (is (string= "" (aref result 0)))))

(test split-lines-empty-lines
  "split-lines preserves empty lines."
  (let ((result (fol.compiler.string-functions:split-lines (format nil "a~C~Cb" #\Newline #\Newline))))
    (is (vectorp result))
    (is (= 3 (length result)))
    (is (string= "a" (aref result 0)))
    (is (string= "" (aref result 1)))
    (is (string= "b" (aref result 2)))))

(test split-lines-trailing-newline
  "split-lines handles trailing newline."
  (let ((result (fol.compiler.string-functions:split-lines (format nil "a~Cb~C" #\Newline #\Newline))))
    (is (vectorp result))
    (is (= 3 (length result)))
    (is (string= "a" (aref result 0)))
    (is (string= "b" (aref result 1)))
    (is (string= "" (aref result 2)))))

;;; ---------------------------------------------------------------------------
;;; Generic replace function
;;; ---------------------------------------------------------------------------

(test replace-character
  "replace can replace a character with a string."
  (is (string= "hXllo"
               (fol.compiler.string-functions:replace "hello" #\e "X"))))

(test replace-string-literal
  "replace can replace a literal string."
  (is (string= "hello FOL"
               (fol.compiler.string-functions:replace "hello world" "world" "FOL"))))

(test replace-string-regex
  "replace can use regex patterns."
  (is (string= "aXbXcX"
               (fol.compiler.string-functions:replace "a1b2c3" "\\d" "X" :use-regex t))))

(test replace-all-occurrences
  "replace replaces all occurrences."
  (is (string= "XXX"
               (fol.compiler.string-functions:replace "aaa" #\a "X"))))

;;; ---------------------------------------------------------------------------
;;; Generic replace-first function
;;; ---------------------------------------------------------------------------

(test replace-first-character
  "replace-first replaces only first occurrence of character."
  (is (string= "Xello"
               (fol.compiler.string-functions:replace-first "hello" #\h "X"))))

(test replace-first-string-literal
  "replace-first replaces only first occurrence of string."
  (is (string= "hello FOL world"
               (fol.compiler.string-functions:replace-first "hello world world" "world" "FOL"))))

(test replace-first-string-regex
  "replace-first can use regex patterns."
  (is (string= "aXb2c3"
               (fol.compiler.string-functions:replace-first "a1b2c3" "\\d" "X" :use-regex t))))

;;; ---------------------------------------------------------------------------
;;; Generic reverse function
;;; ---------------------------------------------------------------------------

(test reverse-string
  "reverse reverses a string."
  (is (string= "olleh"
               (fol.compiler.string-functions:reverse "hello"))))

(test reverse-empty-string
  "reverse handles empty string."
  (is (string= ""
               (fol.compiler.string-functions:reverse ""))))

;;; ---------------------------------------------------------------------------
;;; Generic index-of function
;;; ---------------------------------------------------------------------------

(test index-of-character
  "index-of finds first occurrence of character."
  (is (= 2 (fol.compiler.string-functions:index-of "hello" #\l))))

(test index-of-character-not-found
  "index-of returns nil when character not found."
  (is (null (fol.compiler.string-functions:index-of "hello" #\x))))

(test index-of-string-literal
  "index-of finds first occurrence of string."
  (is (= 6 (fol.compiler.string-functions:index-of "hello world" "world"))))

(test index-of-with-start
  "index-of can start from a given index."
  (is (= 3 (fol.compiler.string-functions:index-of "hello" #\l :from-index 3))))

(test index-of-string-regex
  "index-of can use regex patterns."
  (is (= 1 (fol.compiler.string-functions:index-of "a1b2c3" "\\d" :use-regex t))))

;;; ---------------------------------------------------------------------------
;;; Generic last-index-of function
;;; ---------------------------------------------------------------------------

(test last-index-of-character
  "last-index-of finds last occurrence of character."
  (is (= 3 (fol.compiler.string-functions:last-index-of "hello" #\l))))

(test last-index-of-character-not-found
  "last-index-of returns nil when character not found."
  (is (null (fol.compiler.string-functions:last-index-of "hello" #\x))))

(test last-index-of-string-literal
  "last-index-of finds last occurrence of string."
  (is (= 12 (fol.compiler.string-functions:last-index-of "hello world world" "world"))))

(test last-index-of-string-regex
  "last-index-of can use regex patterns."
  (is (= 5 (fol.compiler.string-functions:last-index-of "a1b2c3" "\\d" :use-regex t))))

;;; ---------------------------------------------------------------------------
;;; parse-boolean function
;;; ---------------------------------------------------------------------------

(test parse-boolean-true-lowercase
  "parse-boolean recognizes 'true' (case-insensitive)."
  (is (eq t (fol.compiler.string-functions:parse-boolean "true"))))

(test parse-boolean-true-uppercase
  "parse-boolean recognizes 'TRUE'."
  (is (eq t (fol.compiler.string-functions:parse-boolean "TRUE"))))

(test parse-boolean-true-mixed-case
  "parse-boolean recognizes 'TrUe'."
  (is (eq t (fol.compiler.string-functions:parse-boolean "TrUe"))))

(test parse-boolean-t
  "parse-boolean recognizes 'T'."
  (is (eq t (fol.compiler.string-functions:parse-boolean "T"))))

(test parse-boolean-t-lowercase
  "parse-boolean recognizes 't'."
  (is (eq t (fol.compiler.string-functions:parse-boolean "t"))))

(test parse-boolean-false-lowercase
  "parse-boolean recognizes 'false' and returns NIL."
  (is (eq nil (fol.compiler.string-functions:parse-boolean "false"))))

(test parse-boolean-false-uppercase
  "parse-boolean recognizes 'FALSE' and returns NIL."
  (is (eq nil (fol.compiler.string-functions:parse-boolean "FALSE"))))

(test parse-boolean-nil-lowercase
  "parse-boolean recognizes 'nil' and returns NIL."
  (is (eq nil (fol.compiler.string-functions:parse-boolean "nil"))))

(test parse-boolean-nil-uppercase
  "parse-boolean recognizes 'NIL' and returns NIL."
  (is (eq nil (fol.compiler.string-functions:parse-boolean "NIL"))))

(test parse-boolean-f
  "parse-boolean recognizes 'F' and returns NIL."
  (is (eq nil (fol.compiler.string-functions:parse-boolean "F"))))

(test parse-boolean-f-lowercase
  "parse-boolean recognizes 'f' and returns NIL."
  (is (eq nil (fol.compiler.string-functions:parse-boolean "f"))))

(test parse-boolean-with-whitespace
  "parse-boolean trims whitespace."
  (is (eq t (fol.compiler.string-functions:parse-boolean "  true  "))))

(test parse-boolean-invalid-string
  "parse-boolean errors on invalid boolean string."
  (signals error
    (fol.compiler.string-functions:parse-boolean "yes")))

;;; ---------------------------------------------------------------------------
;;; parse-uuid function
;;; ---------------------------------------------------------------------------

(test parse-uuid-valid-lowercase
  "parse-uuid parses a valid UUID (lowercase)."
  (let ((uuid (fol.compiler.string-functions:parse-uuid "550e8400-e29b-41d4-a716-446655440000")))
    (is (typep uuid 'uuid:uuid))))

(test parse-uuid-valid-uppercase
  "parse-uuid parses a valid UUID (uppercase)."
  (let ((uuid (fol.compiler.string-functions:parse-uuid "550E8400-E29B-41D4-A716-446655440000")))
    (is (typep uuid 'uuid:uuid))))

(test parse-uuid-valid-mixed-case
  "parse-uuid parses a valid UUID (mixed case)."
  (let ((uuid (fol.compiler.string-functions:parse-uuid "550e8400-E29B-41d4-A716-446655440000")))
    (is (typep uuid 'uuid:uuid))))

(test parse-uuid-invalid-format
  "parse-uuid errors on invalid UUID format."
  (signals error
    (fol.compiler.string-functions:parse-uuid "invalid-uuid")))

(test parse-uuid-wrong-length
  "parse-uuid errors on wrong-length UUID string."
  (signals error
    (fol.compiler.string-functions:parse-uuid "550e8400-e29b-41d4-a716")))

;;; ---------------------------------------------------------------------------
;;; parse-int and parse-long functions (from arithmetic-functions)
;;; ---------------------------------------------------------------------------

(test parse-int-positive
  "parse-int parses positive integer."
  (is (= 42 (fol.compiler.arithmetic-functions:parse-int "42"))))

(test parse-int-negative
  "parse-int parses negative integer."
  (is (= -17 (fol.compiler.arithmetic-functions:parse-int "-17"))))

(test parse-int-zero
  "parse-int parses zero."
  (is (= 0 (fol.compiler.arithmetic-functions:parse-int "0"))))

(test parse-int-large
  "parse-int parses large integer."
  (is (= 9223372036854775807 (fol.compiler.arithmetic-functions:parse-int "9223372036854775807"))))

(test parse-int-invalid-float
  "parse-int errors on float string."
  (signals error
    (fol.compiler.arithmetic-functions:parse-int "3.14")))

(test parse-int-invalid-string
  "parse-int errors on non-numeric string."
  (signals error
    (fol.compiler.arithmetic-functions:parse-int "abc")))

(test parse-long-positive
  "parse-long parses positive integer (alias for parse-int)."
  (is (= 42 (fol.compiler.arithmetic-functions:parse-long "42"))))

(test parse-long-large
  "parse-long parses very large integer."
  (is (= 9223372036854775807 (fol.compiler.arithmetic-functions:parse-long "9223372036854775807"))))

;;; ---------------------------------------------------------------------------
;;; parse-double function (from arithmetic-functions)
;;; ---------------------------------------------------------------------------

(test parse-double-float
  "parse-double parses floating-point string."
  (is (typep (fol.compiler.arithmetic-functions:parse-double "3.14") 'double-float))
  (is (< (abs (- (fol.compiler.arithmetic-functions:parse-double "3.14") 3.14d0)) 0.001d0)))

(test parse-double-integer
  "parse-double converts integer string to double-float."
  (is (typep (fol.compiler.arithmetic-functions:parse-double "42") 'double-float))
  (is (= 42.0d0 (fol.compiler.arithmetic-functions:parse-double "42"))))

(test parse-double-negative
  "parse-double parses negative float."
  (is (< (abs (- (fol.compiler.arithmetic-functions:parse-double "-1.5") -1.5d0)) 0.001d0)))

(test parse-double-scientific
  "parse-double parses scientific notation."
  (is (typep (fol.compiler.arithmetic-functions:parse-double "1.5e10") 'double-float)))

(test parse-double-invalid-string
  "parse-double errors on non-numeric string."
  (signals error
    (fol.compiler.arithmetic-functions:parse-double "abc")))

;;; ---------------------------------------------------------------------------
;;; Regular expression functions (Clojure-style)
;;; ---------------------------------------------------------------------------

(test re-pattern-creates-scanner
  "re-pattern compiles a pattern string to a scanner."
  (let ((scanner (fol.compiler.string-functions:re-pattern "\\d+")))
    (is (not (null scanner)))
    (is (not (stringp scanner)))))

(test re-find-simple-match
  "re-find finds first match without groups."
  (is (string= "123" (fol.compiler.string-functions:re-find "\\d+" "abc123def"))))

(test re-find-no-match
  "re-find returns nil when no match found."
  (is (null (fol.compiler.string-functions:re-find "xyz" "abc123def"))))

(test re-find-with-groups
  "re-find returns vector with full match and groups."
  (let ((result (fol.compiler.string-functions:re-find "(\\d+)" "abc123def")))
    (is (vectorp result))
    (is (= 2 (length result)))
    (is (string= "123" (aref result 0)))
    (is (string= "123" (aref result 1)))))

(test re-find-multiple-groups
  "re-find returns all capture groups."
  (let ((result (fol.compiler.string-functions:re-find "(\\d+)([a-z]+)" "123abc")))
    (is (vectorp result))
    (is (= 3 (length result)))
    (is (string= "123abc" (aref result 0)))
    (is (string= "123" (aref result 1)))
    (is (string= "abc" (aref result 2)))))

(test re-find-with-start-position
  "re-find can start from a given position."
  (is (string= "456" (fol.compiler.string-functions:re-find "\\d+" "abc123def456" 9))))

(test re-seq-simple-matches
  "re-seq returns all matches without groups."
  (let ((result (fol.compiler.string-functions:re-seq "\\d+" "a1b22c333")))
    (is (vectorp result))
    (is (= 3 (length result)))
    (is (string= "1" (aref result 0)))
    (is (string= "22" (aref result 1)))
    (is (string= "333" (aref result 2)))))

(test re-seq-no-matches
  "re-seq returns empty vector when no matches."
  (let ((result (fol.compiler.string-functions:re-seq "\\d+" "abc")))
    (is (vectorp result))
    (is (= 0 (length result)))))

(test re-seq-with-groups
  "re-seq returns vector of vectors when pattern has groups."
  (let ((result (fol.compiler.string-functions:re-seq "(\\d+)" "a1b22c333")))
    (is (vectorp result))
    (is (= 3 (length result)))
    (is (vectorp (aref result 0)))
    (is (string= "1" (aref (aref result 0) 0)))
    (is (string= "1" (aref (aref result 0) 1)))
    (is (string= "22" (aref (aref result 1) 0)))))

(test re-matches-entire-string
  "re-matches requires pattern to match entire string."
  (is (string= "123" (fol.compiler.string-functions:re-matches "\\d+" "123")))
  (is (null (fol.compiler.string-functions:re-matches "\\d+" "abc123")))
  (is (null (fol.compiler.string-functions:re-matches "\\d+" "123abc"))))

(test re-matches-with-groups
  "re-matches returns vector with groups when entire string matches."
  (let ((result (fol.compiler.string-functions:re-matches "(\\d+)" "123")))
    (is (vectorp result))
    (is (= 2 (length result)))
    (is (string= "123" (aref result 0)))
    (is (string= "123" (aref result 1)))))

(test re-matches-partial-no-match
  "re-matches returns nil for partial matches."
  (is (null (fol.compiler.string-functions:re-matches "\\d+" "abc123def"))))

(test re-matcher-compiles-pattern
  "re-matcher creates a compiled scanner."
  (let ((scanner (fol.compiler.string-functions:re-matcher "\\d+" "ignored")))
    (is (not (null scanner)))
    (is (not (stringp scanner)))))

(test re-matcher-can-be-reused
  "re-matcher result can be used with re-find."
  (let ((scanner (fol.compiler.string-functions:re-matcher "\\d+" "ignored")))
    (is (string= "123" (fol.compiler.string-functions:re-find scanner "abc123def")))
    (is (string= "456" (fol.compiler.string-functions:re-find scanner "xyz456")))))

(test re-quote-replacement-escapes-dollar
  "re-quote-replacement escapes dollar signs."
  (is (string= "\\$1.00" (fol.compiler.string-functions:re-quote-replacement "$1.00"))))

(test re-quote-replacement-escapes-backslash
  "re-quote-replacement escapes backslashes."
  (is (string= "a\\\\b" (fol.compiler.string-functions:re-quote-replacement "a\\b"))))

(test re-quote-replacement-escapes-both
  "re-quote-replacement escapes both dollar and backslash."
  (is (string= "\\$\\\\\\$" (fol.compiler.string-functions:re-quote-replacement "$\\$"))))

(test re-quote-replacement-normal-string
  "re-quote-replacement leaves normal strings unchanged."
  (is (string= "hello world" (fol.compiler.string-functions:re-quote-replacement "hello world"))))

(test re-quote-replacement-empty-string
  "re-quote-replacement handles empty string."
  (is (string= "" (fol.compiler.string-functions:re-quote-replacement ""))))

;;; ---------------------------------------------------------------------------
;;; Clojure-style trimming functions
;;; ---------------------------------------------------------------------------

(test trim-both-sides
  "trim removes whitespace from both ends."
  (is (string= "hello" (fol.compiler.string-functions:trim "  hello  "))))

(test trim-newlines-and-tabs
  "trim removes newlines and tabs."
  (is (string= "test" (fol.compiler.string-functions:trim (format nil "~C~Ctest~C~C" #\Newline #\Tab #\Newline #\Tab)))))

(test trim-no-whitespace
  "trim leaves strings without whitespace unchanged."
  (is (string= "hello" (fol.compiler.string-functions:trim "hello"))))

(test trim-empty-string
  "trim handles empty string."
  (is (string= "" (fol.compiler.string-functions:trim ""))))

(test triml-left-whitespace
  "triml removes whitespace from left end only."
  (is (string= "hello  " (fol.compiler.string-functions:triml "  hello  "))))

(test triml-no-left-whitespace
  "triml leaves strings without left whitespace unchanged."
  (is (string= "hello  " (fol.compiler.string-functions:triml "hello  "))))

(test trimr-right-whitespace
  "trimr removes whitespace from right end only."
  (is (string= "  hello" (fol.compiler.string-functions:trimr "  hello  "))))

(test trimr-no-right-whitespace
  "trimr leaves strings without right whitespace unchanged."
  (is (string= "  hello" (fol.compiler.string-functions:trimr "  hello"))))

(test trim-newline-single
  "trim-newline removes single trailing newline."
  (is (string= "hello" (fol.compiler.string-functions:trim-newline (format nil "hello~C" #\Newline)))))

(test trim-newline-crlf
  "trim-newline removes CRLF line ending."
  (is (string= "hello" (fol.compiler.string-functions:trim-newline (format nil "hello~C~C" #\Return #\Newline)))))

(test trim-newline-multiple
  "trim-newline removes multiple trailing newlines."
  (is (string= "hello" (fol.compiler.string-functions:trim-newline (format nil "hello~C~C" #\Newline #\Newline)))))

(test trim-newline-preserves-leading
  "trim-newline preserves leading newlines."
  (is (string= (format nil "~Chello" #\Newline)
               (fol.compiler.string-functions:trim-newline (format nil "~Chello~C" #\Newline #\Newline)))))

(test trim-newline-no-newlines
  "trim-newline leaves strings without newlines unchanged."
  (is (string= "hello" (fol.compiler.string-functions:trim-newline "hello"))))

;;; ---------------------------------------------------------------------------
;;; Clojure-style case conversion functions
;;; ---------------------------------------------------------------------------

(test upper-case-lowercase-string
  "upper-case converts lowercase to uppercase."
  (is (string= "HELLO" (fol.compiler.string-functions:upper-case "hello"))))

(test upper-case-mixed-case
  "upper-case converts mixed case to uppercase."
  (is (string= "HELLO WORLD" (fol.compiler.string-functions:upper-case "Hello World"))))

(test upper-case-already-upper
  "upper-case leaves uppercase strings unchanged."
  (is (string= "HELLO" (fol.compiler.string-functions:upper-case "HELLO"))))

(test upper-case-empty
  "upper-case handles empty string."
  (is (string= "" (fol.compiler.string-functions:upper-case ""))))

(test lower-case-uppercase-string
  "lower-case converts uppercase to lowercase."
  (is (string= "hello" (fol.compiler.string-functions:lower-case "HELLO"))))

(test lower-case-mixed-case
  "lower-case converts mixed case to lowercase."
  (is (string= "hello world" (fol.compiler.string-functions:lower-case "Hello World"))))

(test lower-case-already-lower
  "lower-case leaves lowercase strings unchanged."
  (is (string= "hello" (fol.compiler.string-functions:lower-case "hello"))))

(test lower-case-empty
  "lower-case handles empty string."
  (is (string= "" (fol.compiler.string-functions:lower-case ""))))

(test capitalize-lowercase-string
  "capitalize capitalizes first character of lowercase string."
  (is (string= "Hello world" (fol.compiler.string-functions:capitalize "hello world"))))

(test capitalize-uppercase-string
  "capitalize first character, rest unchanged."
  (is (string= "HELLO WORLD" (fol.compiler.string-functions:capitalize "hELLO WORLD"))))

(test capitalize-already-capitalized
  "capitalize leaves already capitalized strings unchanged."
  (is (string= "Hello" (fol.compiler.string-functions:capitalize "Hello"))))

(test capitalize-empty
  "capitalize handles empty string."
  (is (string= "" (fol.compiler.string-functions:capitalize ""))))

(test capitalize-single-char
  "capitalize handles single character."
  (is (string= "H" (fol.compiler.string-functions:capitalize "h"))))

;;; ---------------------------------------------------------------------------
;;; Clojure-style predicate functions
;;; ---------------------------------------------------------------------------

(test blank-empty-string
  "blank? returns true for empty string."
  (is (eq t (fol.compiler.string-functions:blank? ""))))

(test blank-nil
  "blank? returns true for nil."
  (is (eq t (fol.compiler.string-functions:blank? nil))))

(test blank-whitespace-only
  "blank? returns true for whitespace-only string."
  (is (eq t (fol.compiler.string-functions:blank? "   ")))
  (is (eq t (fol.compiler.string-functions:blank? (format nil "~C~C" #\Tab #\Newline)))))

(test blank-non-blank-string
  "blank? returns false for non-blank string."
  (is (null (fol.compiler.string-functions:blank? "hello")))
  (is (null (fol.compiler.string-functions:blank? "  hello  "))))

(test starts-with-matching-prefix
  "starts-with? returns true for matching prefix."
  (is (eq t (fol.compiler.string-functions:starts-with? "hello world" "hello"))))

(test starts-with-exact-match
  "starts-with? returns true when prefix equals string."
  (is (eq t (fol.compiler.string-functions:starts-with? "hello" "hello"))))

(test starts-with-non-matching
  "starts-with? returns false for non-matching prefix."
  (is (null (fol.compiler.string-functions:starts-with? "hello world" "world"))))

(test starts-with-prefix-too-long
  "starts-with? returns false when prefix is longer than string."
  (is (null (fol.compiler.string-functions:starts-with? "hi" "hello"))))

(test starts-with-empty-prefix
  "starts-with? returns true for empty prefix."
  (is (eq t (fol.compiler.string-functions:starts-with? "hello" ""))))

(test ends-with-matching-suffix
  "ends-with? returns true for matching suffix."
  (is (eq t (fol.compiler.string-functions:ends-with? "hello world" "world"))))

(test ends-with-exact-match
  "ends-with? returns true when suffix equals string."
  (is (eq t (fol.compiler.string-functions:ends-with? "hello" "hello"))))

(test ends-with-non-matching
  "ends-with? returns false for non-matching suffix."
  (is (null (fol.compiler.string-functions:ends-with? "hello world" "hello"))))

(test ends-with-suffix-too-long
  "ends-with? returns false when suffix is longer than string."
  (is (null (fol.compiler.string-functions:ends-with? "hi" "hello"))))

(test ends-with-empty-suffix
  "ends-with? returns true for empty suffix."
  (is (eq t (fol.compiler.string-functions:ends-with? "hello" ""))))

(test includes-matching-substring
  "includes? returns true for matching substring."
  (is (eq t (fol.compiler.string-functions:includes? "hello world" "llo wor"))))

(test includes-at-start
  "includes? returns true for substring at start."
  (is (eq t (fol.compiler.string-functions:includes? "hello world" "hello"))))

(test includes-at-end
  "includes? returns true for substring at end."
  (is (eq t (fol.compiler.string-functions:includes? "hello world" "world"))))

(test includes-non-matching
  "includes? returns false for non-matching substring."
  (is (null (fol.compiler.string-functions:includes? "hello world" "xyz"))))

(test includes-empty-substring
  "includes? returns true for empty substring."
  (is (eq t (fol.compiler.string-functions:includes? "hello" ""))))

;;; ---------------------------------------------------------------------------
;;; Character functions (Clojure-style)
;;; ---------------------------------------------------------------------------

(test char-first-index
  "char returns character at index 0."
  (is (char= #\h (fol.compiler.string-functions:char "hello" 0))))

(test char-middle-index
  "char returns character at middle index."
  (is (char= #\l (fol.compiler.string-functions:char "hello" 2))))

(test char-last-index
  "char returns character at last index."
  (is (char= #\o (fol.compiler.string-functions:char "hello" 4))))

(test char-out-of-bounds
  "char errors on out-of-bounds index."
  (signals error
    (fol.compiler.string-functions:char "hello" 5)))

(test char-negative-index
  "char errors on negative index."
  (signals error
    (fol.compiler.string-functions:char "hello" -1)))

(test char-name-string-newline
  "char-name-string returns \"newline\" for newline character."
  (is (string= "newline" (fol.compiler.string-functions:char-name-string #\Newline))))

(test char-name-string-space
  "char-name-string returns \"space\" for space character."
  (is (string= "space" (fol.compiler.string-functions:char-name-string #\Space))))

(test char-name-string-tab
  "char-name-string returns \"tab\" for tab character."
  (is (string= "tab" (fol.compiler.string-functions:char-name-string #\Tab))))

(test char-name-string-return
  "char-name-string returns \"return\" for return character."
  (is (string= "return" (fol.compiler.string-functions:char-name-string #\Return))))

(test char-name-string-backspace
  "char-name-string returns \"backspace\" for backspace character."
  (is (string= "backspace" (fol.compiler.string-functions:char-name-string #\Backspace))))

(test char-name-string-formfeed
  "char-name-string returns \"formfeed\" for formfeed character."
  (is (string= "formfeed" (fol.compiler.string-functions:char-name-string (code-char 12)))))

(test char-name-string-regular-char
  "char-name-string returns nil for regular characters."
  (is (null (fol.compiler.string-functions:char-name-string #\a))))

(test char-escape-string-newline
  "char-escape-string returns \"\\\\n\" for newline."
  (is (string= "\\n" (fol.compiler.string-functions:char-escape-string #\Newline))))

(test char-escape-string-tab
  "char-escape-string returns \"\\\\t\" for tab."
  (is (string= "\\t" (fol.compiler.string-functions:char-escape-string #\Tab))))

(test char-escape-string-return
  "char-escape-string returns \"\\\\r\" for return."
  (is (string= "\\r" (fol.compiler.string-functions:char-escape-string #\Return))))

(test char-escape-string-backspace
  "char-escape-string returns \"\\\\b\" for backspace."
  (is (string= "\\b" (fol.compiler.string-functions:char-escape-string #\Backspace))))

(test char-escape-string-formfeed
  "char-escape-string returns \"\\\\f\" for formfeed."
  (is (string= "\\f" (fol.compiler.string-functions:char-escape-string (code-char 12)))))

(test char-escape-string-space
  "char-escape-string returns \"\\\\space\" for space."
  (is (string= "\\space" (fol.compiler.string-functions:char-escape-string #\Space))))

(test char-escape-string-regular-char
  "char-escape-string returns \"\\\\c\" for regular character."
  (is (string= "\\a" (fol.compiler.string-functions:char-escape-string #\a))))
