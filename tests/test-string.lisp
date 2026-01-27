(in-package :fol.tests)

;;; ============================================================================
;;; String Tests - Comprehensive test suite for FOL string operations
;;; ============================================================================

(def-suite string-suite :in fol-suite)
(def-suite* :fol.string-tests :in string-suite)

;;; ---------------------------------------------------------------------------
;;; String Type Predicate Tests
;;; ---------------------------------------------------------------------------

(test string-predicate-raw
  "Test <string>? predicate with raw strings."
  (is-true (<string>? "hello"))
  (is-true (<string>? ""))
  (is-true (<string>? "Hello World"))
  (is-true (<string>? "123"))
  (is-true (<string>? " ")))

(test string-predicate-wrapped
  "Test <string>? predicate with wrapped strings."
  (is-true (<string>? (wrap-string "hello")))
  (is-true (<string>? (wrap-string "")))
  (is-true (<string>? (wrap-string "test"))))

(test string-predicate-non-strings
  "Test <string>? predicate returns NIL for non-strings."
  (is-false (<string>? 'hello))
  (is-false (<string>? :hello))
  (is-false (<string>? 123))
  (is-false (<string>? #\h))
  (is-false (<string>? t))
  (is-false (<string>? nil))
  (is-false (<string>? '(h e l l o))))

;;; ---------------------------------------------------------------------------
;;; String Wrapping/Unwrapping Tests
;;; ---------------------------------------------------------------------------

(test string-wrap-basic
  "Test wrapping of basic strings."
  (let ((wrapped (wrap-string "hello")))
    (is (typep wrapped '<string>))
    (is (string= "hello" (fol-value wrapped)))
    (is (string= "hello" (unwrap-string wrapped)))))

(test string-wrap-empty
  "Test wrapping of empty string."
  (let ((wrapped (wrap-string "")))
    (is (typep wrapped '<string>))
    (is (string= "" (fol-value wrapped)))
    (is (string= "" (unwrap-string wrapped)))))

(test string-wrap-whitespace
  "Test wrapping of whitespace strings."
  (let ((wrapped (wrap-string "   ")))
    (is (typep wrapped '<string>))
    (is (string= "   " (fol-value wrapped)))))

(test string-wrap-special-chars
  "Test wrapping of strings with special characters."
  (let ((wrapped (wrap-string "hello\nworld")))
    (is (string= "hello\nworld" (fol-value wrapped))))
  (let ((wrapped (wrap-string "tab\there")))
    (is (string= "tab\there" (fol-value wrapped)))))

(test string-wrap-roundtrip
  "Test that wrap/unwrap is identity for strings."
  (is (string= "test" (unwrap-string (wrap-string "test"))))
  (is (string= "" (unwrap-string (wrap-string ""))))
  (is (string= "hello world" (unwrap-string (wrap-string "hello world")))))

(test string-fol-value-raw
  "Test fol-value on raw strings (pass-through)."
  (is (string= "hello" (fol-value "hello")))
  (is (string= "" (fol-value "")))
  (is (string= "test" (fol-value "test"))))

(test string-fol-type-of
  "Test fol-type-of for strings."
  (is (eq '<string> (fol-type-of "hello")))
  (is (eq '<string> (fol-type-of "")))
  (is (eq '<string> (fol-type-of (wrap-string "test")))))

;;; ---------------------------------------------------------------------------
;;; String Equality Tests
;;; ---------------------------------------------------------------------------

(test string-equality-raw-raw
  "Test equality between raw strings."
  (is-true (%= "hello" "hello"))
  (is-true (%= "" ""))
  (is-false (%= "hello" "HELLO"))
  (is-false (%= "hello" "world"))
  (is-false (%= "hello" "hello ")))

(test string-equality-wrapped-wrapped
  "Test equality between wrapped strings."
  (let ((s1 (wrap-string "hello"))
        (s2 (wrap-string "hello"))
        (s3 (wrap-string "world")))
    (is-true (%= s1 s2))
    (is-false (%= s1 s3))))

(test string-equality-mixed
  "Test equality between raw and wrapped strings."
  (let ((wrapped (wrap-string "hello")))
    (is-true (%= wrapped "hello"))
    (is-true (%= "hello" wrapped))
    (is-false (%= wrapped "world"))
    (is-false (%= "world" wrapped))))

(test string-inequality
  "Test inequality for strings."
  (is-true (%/= "hello" "world"))
  (is-true (%/= "hello" "HELLO"))
  (is-false (%/= "hello" "hello"))
  (let ((s1 (wrap-string "abc"))
        (s2 (wrap-string "def")))
    (is-true (%/= s1 s2))
    (is-false (%/= s1 "abc"))))

;;; ---------------------------------------------------------------------------
;;; String Ordering Tests
;;; ---------------------------------------------------------------------------

(test string-less-than-raw
  "Test less-than comparison with raw strings."
  (is-true (%< "abc" "def"))
  (is-true (%< "aaa" "aab"))
  (is-true (%< "a" "aa"))
  (is-true (%< "" "a"))
  (is-false (%< "def" "abc"))
  (is-false (%< "abc" "abc")))

(test string-less-than-wrapped
  "Test less-than comparison with wrapped strings."
  (let ((s1 (wrap-string "abc"))
        (s2 (wrap-string "def")))
    (is-true (%< s1 s2))
    (is-false (%< s2 s1))))

(test string-less-than-mixed
  "Test less-than comparison with mixed raw and wrapped strings."
  (let ((wrapped (wrap-string "abc")))
    (is-true (%< wrapped "def"))
    (is-true (%< "aaa" wrapped))
    (is-false (%< "xyz" wrapped))))

(test string-greater-than-raw
  "Test greater-than comparison with raw strings."
  (is-true (%> "def" "abc"))
  (is-true (%> "aab" "aaa"))
  (is-true (%> "aa" "a"))
  (is-true (%> "a" ""))
  (is-false (%> "abc" "def"))
  (is-false (%> "abc" "abc")))

(test string-greater-than-wrapped
  "Test greater-than comparison with wrapped strings."
  (let ((s1 (wrap-string "xyz"))
        (s2 (wrap-string "abc")))
    (is-true (%> s1 s2))
    (is-false (%> s2 s1))))

(test string-less-equal-raw
  "Test less-or-equal comparison with raw strings."
  (is-true (%<= "abc" "def"))
  (is-true (%<= "abc" "abc"))
  (is-false (%<= "def" "abc")))

(test string-less-equal-wrapped
  "Test less-or-equal comparison with wrapped strings."
  (let ((s1 (wrap-string "abc"))
        (s2 (wrap-string "abc")))
    (is-true (%<= s1 s2))
    (is-true (%<= s1 "def"))))

(test string-greater-equal-raw
  "Test greater-or-equal comparison with raw strings."
  (is-true (%>= "def" "abc"))
  (is-true (%>= "abc" "abc"))
  (is-false (%>= "abc" "def")))

(test string-greater-equal-wrapped
  "Test greater-or-equal comparison with wrapped strings."
  (let ((s1 (wrap-string "xyz"))
        (s2 (wrap-string "xyz")))
    (is-true (%>= s1 s2))
    (is-true (%>= s1 "abc"))))

;;; ---------------------------------------------------------------------------
;;; Variadic String Comparisons
;;; ---------------------------------------------------------------------------

(test string-variadic-equality
  "Test variadic equality with strings."
  (is-true (= "a" "a" "a"))
  (is-false (= "a" "a" "b"))
  (let ((s1 (wrap-string "test"))
        (s2 (wrap-string "test")))
    (is-true (= s1 "test" s2))))

(test string-variadic-less-than
  "Test variadic less-than with strings."
  (is-true (< "a" "b" "c"))
  (is-true (< "aa" "ab" "ac"))
  (is-false (< "a" "c" "b"))
  (let ((s1 (wrap-string "a"))
        (s2 (wrap-string "c")))
    (is-true (< s1 "b" s2))))

(test string-variadic-greater-than
  "Test variadic greater-than with strings."
  (is-true (> "c" "b" "a"))
  (is-false (> "c" "a" "b"))
  (let ((s1 (wrap-string "z"))
        (s2 (wrap-string "a")))
    (is-true (> s1 "m" s2))))

;;; ---------------------------------------------------------------------------
;;; String Edge Cases
;;; ---------------------------------------------------------------------------

(test string-empty-comparisons
  "Test comparisons involving empty strings."
  (is-true (%= "" ""))
  (is-true (%< "" "a"))
  (is-true (%> "a" ""))
  (is-true (%<= "" ""))
  (is-true (%>= "" ""))
  (let ((empty (wrap-string "")))
    (is-true (%= empty ""))
    (is-true (%< empty "anything"))))

(test string-single-char-comparisons
  "Test comparisons with single character strings."
  (is-true (%< "a" "b"))
  (is-true (%< "A" "a"))  ; uppercase before lowercase in ASCII
  (is-true (%< "9" "a"))  ; digits before letters in ASCII
  (is-true (%< " " "!"))  ; space before exclamation in ASCII)
  )

(test string-length-comparisons
  "Test that shorter strings come before longer prefixes."
  (is-true (%< "a" "aa"))
  (is-true (%< "ab" "abc"))
  (is-true (%< "" "x"))
  (is-false (%< "abc" "ab")))

(test string-case-sensitive
  "Test that string comparisons are case-sensitive."
  (is-false (%= "Hello" "hello"))
  (is-false (%= "ABC" "abc"))
  (is-true (%/= "Test" "test")))

(test string-unicode-basic
  "Test strings with extended ASCII characters."
  (let ((s1 (wrap-string "cafe"))
        (s2 (wrap-string "cafe")))
    (is-true (%= s1 s2))
    (is (string= "cafe" (fol-value s1)))))

(test string-whitespace-significant
  "Test that whitespace is significant in comparisons."
  (is-false (%= "hello" "hello "))
  (is-false (%= " hello" "hello"))
  (is-false (%= "hello world" "helloworld"))
  (is-true (%< "hello" "hello "))  ; shorter comes first
  (let ((with-space (wrap-string "a b"))
        (without-space (wrap-string "ab")))
    (is-false (%= with-space without-space))))

(test string-min-max
  "Test min/max with strings."
  (is (string= "a" (min "a" "b" "c")))
  (is (string= "c" (max "a" "b" "c")))
  (is (string= "" (min "" "a" "z")))
  (is (string= "z" (max "" "a" "z")))
  (let ((s1 (wrap-string "apple"))
        (s2 (wrap-string "banana"))
        (s3 (wrap-string "cherry")))
    (is (string= "apple" (min s1 s2 s3)))
    (is (string= "cherry" (max s1 s2 s3)))))

;;; ---------------------------------------------------------------------------
;;; String Preservation Tests
;;; ---------------------------------------------------------------------------

(test string-content-preserved
  "Test that string content is exactly preserved through wrap/unwrap."
  (let* ((original "Hello, World! 123 @#$%")
         (wrapped (wrap-string original))
         (unwrapped (unwrap-string wrapped)))
    (is (string= original unwrapped))
    (is (= (length original) (length unwrapped)))))

(test string-newlines-preserved
  "Test that newlines and other control characters are preserved."
  (let* ((original "line1
line2
line3")
         (wrapped (wrap-string original)))
    (is (string= original (fol-value wrapped)))))

(test string-tabs-preserved
  "Test that tabs are preserved."
  (let* ((original "col1	col2	col3")
         (wrapped (wrap-string original)))
    (is (string= original (fol-value wrapped)))))

;;; ============================================================================
;;; Substring Operations
;;; ============================================================================

;;; ---------------------------------------------------------------------------
;;; substr Tests
;;; ---------------------------------------------------------------------------

(test substr-basic
  "Test substr with start only."
  (is (string= "world" (substr "hello world" 6)))
  (is (string= "hello world" (substr "hello world" 0)))
  (is (string= "" (substr "hello" 5))))

(test substr-with-end
  "Test substr with start and end."
  (is (string= "ell" (substr "hello" 1 4)))
  (is (string= "hello" (substr "hello world" 0 5)))
  (is (string= "" (substr "hello" 2 2))))

(test substr-wrapped-string
  "Test substr with wrapped <string>."
  (let ((s (wrap-string "hello world")))
    (is (string= "world" (substr s 6)))
    (is (string= "ell" (substr s 1 4)))))

(test substr-wrapped-indices
  "Test substr with wrapped integer indices."
  (is (string= "ell" (substr "hello" (wrap-number 1) (wrap-number 4))))
  (is (string= "world" (substr "hello world" (wrap-number 6)))))

(test substr-full-string
  "Test substr returning full string."
  (is (string= "hello" (substr "hello" 0)))
  (is (string= "hello" (substr "hello" 0 5))))

(test substr-empty-result
  "Test substr returning empty string."
  (is (string= "" (substr "hello" 5)))
  (is (string= "" (substr "hello" 3 3))))

(test substr-single-char
  "Test substr returning single character."
  (is (string= "e" (substr "hello" 1 2)))
  (is (string= "o" (substr "hello" 4 5))))

(test substr-error-start-negative
  "Test substr signals error for negative start."
  (signals error (substr "hello" -1)))

(test substr-error-start-out-of-bounds
  "Test substr signals error for start beyond string length."
  (signals error (substr "hello" 6)))

(test substr-error-end-before-start
  "Test substr signals error for end before start."
  (signals error (substr "hello" 3 2)))

(test substr-error-end-out-of-bounds
  "Test substr signals error for end beyond string length."
  (signals error (substr "hello" 0 10)))

(test substr-error-non-string
  "Test substr signals error for non-string input."
  (signals error (substr 123 0)))

(test substr-error-non-integer-start
  "Test substr signals error for non-integer start index."
  (signals error (substr "hello" "1")))

(test substr-error-non-integer-end
  "Test substr signals error for non-integer end index."
  (signals error (substr "hello" 0 "5")))

(test substr-unicode
  "Test substr with unicode characters."
  (is (string= "世界" (substr "你好世界" 2)))
  (is (string= "好世" (substr "你好世界" 1 3))))

;;; ---------------------------------------------------------------------------
;;; blank? Tests
;;; ---------------------------------------------------------------------------

(test blank-nil
  "Test blank? returns true for nil."
  (is-true (blank? nil)))

(test blank-empty-string
  "Test blank? returns true for empty string."
  (is-true (blank? ""))
  (is-true (blank? (wrap-string ""))))

(test blank-whitespace-only
  "Test blank? returns true for whitespace-only strings."
  (is-true (blank? " "))
  (is-true (blank? "   "))
  (is-true (blank? "	"))  ; tab
  (is-true (blank? (format nil "~%")))  ; newline
  (is-true (blank? (format nil " ~% 	"))))  ; mixed whitespace

(test blank-non-blank
  "Test blank? returns false for non-blank strings."
  (is-false (blank? "hello"))
  (is-false (blank? " hello "))
  (is-false (blank? "a"))
  (is-false (blank? (wrap-string "test"))))

;;; ---------------------------------------------------------------------------
;;; trim Tests
;;; ---------------------------------------------------------------------------

(test trim-basic
  "Test trim removes whitespace from both ends."
  (is (string= "hello" (trim "  hello  ")))
  (is (string= "hello" (trim "hello")))
  (is (string= "hello world" (trim "  hello world  "))))

(test trim-various-whitespace
  "Test trim removes various whitespace characters."
  (is (string= "test" (trim (format nil "~%test~%"))))
  (is (string= "test" (trim (format nil "	test	"))))
  (is (string= "test" (trim (format nil " ~%	test ~%	")))))

(test trim-empty
  "Test trim with empty string."
  (is (string= "" (trim "")))
  (is (string= "" (trim "   "))))

(test trim-wrapped
  "Test trim with wrapped string."
  (is (string= "hello" (trim (wrap-string "  hello  ")))))

;;; ---------------------------------------------------------------------------
;;; triml Tests
;;; ---------------------------------------------------------------------------

(test triml-basic
  "Test triml removes whitespace from left only."
  (is (string= "hello  " (triml "  hello  ")))
  (is (string= "hello" (triml "hello")))
  (is (string= "hello " (triml "  hello "))))

(test triml-empty
  "Test triml with empty or whitespace-only string."
  (is (string= "" (triml "")))
  (is (string= "" (triml "   "))))

(test triml-wrapped
  "Test triml with wrapped string."
  (is (string= "hello  " (triml (wrap-string "  hello  ")))))

;;; ---------------------------------------------------------------------------
;;; trimr Tests
;;; ---------------------------------------------------------------------------

(test trimr-basic
  "Test trimr removes whitespace from right only."
  (is (string= "  hello" (trimr "  hello  ")))
  (is (string= "hello" (trimr "hello")))
  (is (string= " hello" (trimr " hello  "))))

(test trimr-empty
  "Test trimr with empty or whitespace-only string."
  (is (string= "" (trimr "")))
  (is (string= "" (trimr "   "))))

(test trimr-wrapped
  "Test trimr with wrapped string."
  (is (string= "  hello" (trimr (wrap-string "  hello  ")))))

;;; ---------------------------------------------------------------------------
;;; trim-newline Tests
;;; ---------------------------------------------------------------------------

(test trim-newline-basic
  "Test trim-newline removes trailing newlines only."
  (is (string= "hello" (trim-newline (format nil "hello~%"))))
  (is (string= "hello" (trim-newline (format nil "hello~%~%"))))
  (is (string= "hello" (trim-newline "hello"))))

(test trim-newline-preserves-leading
  "Test trim-newline preserves leading newlines."
  (is (string= (format nil "~%hello") (trim-newline (format nil "~%hello~%")))))

(test trim-newline-preserves-spaces
  "Test trim-newline does not remove trailing spaces."
  (is (string= "hello  " (trim-newline "hello  "))))

(test trim-newline-wrapped
  "Test trim-newline with wrapped string."
  (is (string= "hello" (trim-newline (wrap-string (format nil "hello~%"))))))

;;; ---------------------------------------------------------------------------
;;; capitalize Tests
;;; ---------------------------------------------------------------------------

(test capitalize-basic
  "Test capitalize uppercases first char, lowercases rest."
  (is (string= "Hello" (capitalize "hello")))
  (is (string= "Hello" (capitalize "HELLO")))
  (is (string= "Hello" (capitalize "hELLO")))
  (is (string= "Hello world" (capitalize "HELLO WORLD"))))

(test capitalize-empty
  "Test capitalize with empty string."
  (is (string= "" (capitalize ""))))

(test capitalize-single-char
  "Test capitalize with single character."
  (is (string= "A" (capitalize "a")))
  (is (string= "A" (capitalize "A"))))

(test capitalize-wrapped
  "Test capitalize with wrapped string."
  (is (string= "Hello" (capitalize (wrap-string "hello")))))

(test capitalize-unicode
  "Test capitalize with unicode."
  (is (string= "Über" (capitalize "ÜBER"))))

;;; ---------------------------------------------------------------------------
;;; starts-with? Tests
;;; ---------------------------------------------------------------------------

(test starts-with-basic
  "Test starts-with? with matching prefix."
  (is-true (starts-with? "hello world" "hello"))
  (is-true (starts-with? "hello" "hello"))
  (is-true (starts-with? "hello" "h"))
  (is-true (starts-with? "hello" "")))

(test starts-with-no-match
  "Test starts-with? with non-matching prefix."
  (is-false (starts-with? "hello world" "world"))
  (is-false (starts-with? "hello" "Hello"))
  (is-false (starts-with? "hello" "hello world")))

(test starts-with-empty
  "Test starts-with? with empty string."
  (is-true (starts-with? "" ""))
  (is-false (starts-with? "" "a")))

(test starts-with-wrapped
  "Test starts-with? with wrapped strings."
  (is-true (starts-with? (wrap-string "hello world") "hello"))
  (is-true (starts-with? "hello world" (wrap-string "hello")))
  (is-true (starts-with? (wrap-string "hello") (wrap-string "hel"))))

;;; ---------------------------------------------------------------------------
;;; ends-with? Tests
;;; ---------------------------------------------------------------------------

(test ends-with-basic
  "Test ends-with? with matching suffix."
  (is-true (ends-with? "hello world" "world"))
  (is-true (ends-with? "hello" "hello"))
  (is-true (ends-with? "hello" "o"))
  (is-true (ends-with? "hello" "")))

(test ends-with-no-match
  "Test ends-with? with non-matching suffix."
  (is-false (ends-with? "hello world" "hello"))
  (is-false (ends-with? "hello" "Hello"))
  (is-false (ends-with? "hello" "hello world")))

(test ends-with-empty
  "Test ends-with? with empty string."
  (is-true (ends-with? "" ""))
  (is-false (ends-with? "" "a")))

(test ends-with-wrapped
  "Test ends-with? with wrapped strings."
  (is-true (ends-with? (wrap-string "hello world") "world"))
  (is-true (ends-with? "hello world" (wrap-string "world")))
  (is-true (ends-with? (wrap-string "hello") (wrap-string "llo"))))

;;; ---------------------------------------------------------------------------
;;; includes? Tests
;;; ---------------------------------------------------------------------------

(test includes-basic
  "Test includes? finds substring."
  (is-true (includes? "hello world" "world"))
  (is-true (includes? "hello world" "hello"))
  (is-true (includes? "hello world" "lo wo"))
  (is-true (includes? "hello" "hello"))
  (is-true (includes? "hello" "")))

(test includes-no-match
  "Test includes? with substring not found."
  (is-false (includes? "hello world" "foo"))
  (is-false (includes? "hello" "Hello"))
  (is-false (includes? "hello" "hello world")))

(test includes-empty
  "Test includes? with empty string."
  (is-true (includes? "" ""))
  (is-false (includes? "" "a")))

(test includes-wrapped
  "Test includes? with wrapped strings."
  (is-true (includes? (wrap-string "hello world") "lo wo"))
  (is-true (includes? "hello world" (wrap-string "lo wo")))
  (is-true (includes? (wrap-string "hello") (wrap-string "ell"))))

;;; ============================================================================
;;; Regular Expression Pattern Tests
;;; ============================================================================

;;; ---------------------------------------------------------------------------
;;; RE-Pattern Type Predicate Tests
;;; ---------------------------------------------------------------------------

(test re-pattern-predicate-basic
  "Test <re-pattern>? predicate with regex patterns."
  (let ((pat (wrap-re-pattern "\\d+")))
    (is-true (<re-pattern>? pat))
    (is-true (<string>? pat))))  ; Also a string

(test re-pattern-predicate-non-patterns
  "Test <re-pattern>? predicate returns NIL for non-patterns."
  (is-false (<re-pattern>? "hello"))  ; raw string is not a pattern
  (is-false (<re-pattern>? (wrap-string "hello")))  ; wrapped string is not a pattern
  (is-false (<re-pattern>? 123))
  (is-false (<re-pattern>? nil)))

(test re-pattern-wrapping
  "Test wrap-re-pattern creates valid patterns."
  (let ((pat (wrap-re-pattern "[a-z]+")))
    (is (typep pat '<re-pattern>))
    (is (string= "[a-z]+" (fol-value pat)))))

(test re-pattern-empty
  "Test wrapping empty pattern string."
  (let ((pat (wrap-re-pattern "")))
    (is (typep pat '<re-pattern>))
    (is (string= "" (fol-value pat)))))

(test re-pattern-print
  "Test that <re-pattern> prints with #\"...\" syntax."
  (let* ((pat (wrap-re-pattern "\\d+"))
         (printed (with-output-to-string (s)
                    (print-object pat s))))
    (is (string= "#\"\\d+\"" printed))))

;;; ---------------------------------------------------------------------------
;;; RE-Scanner Tests
;;; ---------------------------------------------------------------------------

(test re-scanner-predicate
  "Test <re-scanner>? predicate."
  (let* ((pat (wrap-re-pattern "\\d+"))
         (scanner (make-re-scanner pat)))
    (is-true (<re-scanner>? scanner))
    (is-false (<re-scanner>? pat))
    (is-false (<re-scanner>? "hello"))))

(test re-scanner-basic-creation
  "Test basic scanner creation."
  (let* ((pat (wrap-re-pattern "[a-z]+"))
         (scanner (make-re-scanner pat)))
    (is (typep scanner '<re-scanner>))
    (is (eq pat (fol-value scanner)))
    (is (functionp (scanner-function scanner)))
    (is (typep (scanner-register-names scanner) 'fol.collection:<vector>))))

(test re-scanner-with-case-insensitive
  "Test scanner with case-insensitive option."
  (let* ((pat (wrap-re-pattern "[a-z]+"))
         (scanner (make-re-scanner pat :case-insensitive t)))
    (is (typep scanner '<re-scanner>))))

(test re-scanner-with-multi-line
  "Test scanner with multi-line option."
  (let* ((pat (wrap-re-pattern "^test$"))
         (scanner (make-re-scanner pat :multi-line t)))
    (is (typep scanner '<re-scanner>))))

(test re-scanner-with-extended
  "Test scanner with extended option."
  (let* ((pat (wrap-re-pattern "\\d+  # match digits"))
         (scanner (make-re-scanner pat :extended t)))
    (is (typep scanner '<re-scanner>))))

(test re-scanner-all-options
  "Test scanner with all options."
  (let* ((pat (wrap-re-pattern "[a-z]+"))
         (scanner (make-re-scanner pat
                    :case-insensitive t
                    :multi-line t
                    :extended t)))
    (is (typep scanner '<re-scanner>))))

(test re-scanner-named-groups
  "Test scanner with named groups populates register-names."
  (let* ((pat (wrap-re-pattern "(?<name>\\w+)\\s+(?<age>\\d+)"))
         (scanner (make-re-scanner pat)))
    (is (typep (scanner-register-names scanner) 'fol.collection:<vector>))
    ;; The register names should contain the named groups
    (let ((names (scanner-register-names scanner)))
      (is (= 2 (fol.collection:size names)))
      (is (string= "name" (fol.collection:nth-element names 0)))
      (is (string= "age" (fol.collection:nth-element names 1))))))

(test re-scanner-unnamed-groups
  "Test scanner with unnamed groups - names are generated during matching."
  (let* ((pat (wrap-re-pattern "(\\w+)\\s+(\\d+)"))
         (scanner (make-re-scanner pat)))
    ;; CL-PPCRE returns empty list for unnamed groups
    ;; The $1, $2, etc. names are generated dynamically during matching
    (let ((names (scanner-register-names scanner)))
      (is (= 0 (fol.collection:size names))))))

(test re-scanner-make-function
  "Test creating scanner via make function."
  (let* ((pat (wrap-re-pattern "\\d+"))
         (scanner (fol.fol-mop:make '<re-scanner> pat)))
    (is (typep scanner '<re-scanner>))
    (is (eq pat (fol-value scanner)))))

(test re-scanner-make-with-options
  "Test creating scanner via make function with options."
  (let* ((pat (wrap-re-pattern "test"))
         (scanner (fol.fol-mop:make '<re-scanner> pat :case-insensitive t)))
    (is (typep scanner '<re-scanner>))))

;;; ============================================================================
;;; Regular Expression Matching Tests (re-find, re-seq)
;;; ============================================================================

;;; ---------------------------------------------------------------------------
;;; re-find Tests
;;; ---------------------------------------------------------------------------

(test re-find-basic-match
  "Test re-find with a simple pattern that matches."
  (multiple-value-bind (match groups) (re-find "\\d+" "abc123def")
    (is (string= "123" match))
    (is (typep groups 'fol.collection:<dict>))
    (is (string= "123" (fol.collection:get groups "$0")))))

(test re-find-no-match
  "Test re-find when pattern doesn't match."
  (multiple-value-bind (match groups) (re-find "\\d+" "abcdef")
    (is (null match))
    (is (null groups))))

(test re-find-with-groups
  "Test re-find with capturing groups."
  (multiple-value-bind (match groups) (re-find "(\\w+)@(\\w+)" "email: test@example.com")
    (is (string= "test@example" match))
    (is (string= "test@example" (fol.collection:get groups "$0")))
    (is (string= "test" (fol.collection:get groups "$1")))
    (is (string= "example" (fol.collection:get groups "$2")))))

(test re-find-with-named-groups
  "Test re-find with named capturing groups."
  (multiple-value-bind (match groups) (re-find "(?<user>\\w+)@(?<domain>\\w+)" "test@example.com")
    (is (string= "test@example" match))
    (is (string= "test@example" (fol.collection:get groups "$0")))
    (is (string= "test" (fol.collection:get groups "user")))
    (is (string= "example" (fol.collection:get groups "domain")))))

(test re-find-with-re-pattern
  "Test re-find with a <re-pattern> argument."
  (let ((pat (wrap-re-pattern "[a-z]+")))
    (multiple-value-bind (match groups) (re-find pat "123abc456")
      (is (string= "abc" match))
      (is (string= "abc" (fol.collection:get groups "$0"))))))

(test re-find-with-re-scanner
  "Test re-find with a <re-scanner> argument."
  (let* ((pat (wrap-re-pattern "[A-Z]+"))
         (scanner (make-re-scanner pat :case-insensitive t)))
    (multiple-value-bind (match groups) (re-find scanner "123abc456")
      (is (string= "abc" match))
      (is (string= "abc" (fol.collection:get groups "$0"))))))

(test re-find-with-wrapped-target
  "Test re-find with a wrapped <string> target."
  (let ((target (wrap-string "hello123world")))
    (multiple-value-bind (match groups) (re-find "\\d+" target)
      (is (string= "123" match))
      (is (string= "123" (fol.collection:get groups "$0"))))))

(test re-find-empty-target
  "Test re-find with empty target string."
  (multiple-value-bind (match groups) (re-find "\\d+" "")
    (is (null match))
    (is (null groups))))

(test re-find-at-start
  "Test re-find matching at start of string."
  (multiple-value-bind (match groups) (re-find "^\\d+" "123abc")
    (is (string= "123" match))))

(test re-find-at-end
  "Test re-find matching at end of string."
  (multiple-value-bind (match groups) (re-find "\\d+$" "abc123")
    (is (string= "123" match))))

;;; ---------------------------------------------------------------------------
;;; re-seq Tests
;;; ---------------------------------------------------------------------------

(test re-seq-basic
  "Test re-seq returns lazy sequence of all matches."
  (let ((seq (re-seq "\\d+" "a1b2c3d4")))
    (is (typep seq 'fol.collection:<lazy-seq>))
    ;; Check size (realizes entire sequence)
    (is (= 4 (fol.collection:size seq)))
    ;; Check first match
    (let ((first-match (first seq)))
      (is (typep first-match 'fol.collection:<vector>))
      (is (string= "1" (fol.collection:nth-element first-match 0)))
      (is (string= "1" (fol.collection:get (fol.collection:nth-element first-match 1) "$0"))))))

(test re-seq-no-matches
  "Test re-seq with no matches returns empty sequence."
  (let ((seq (re-seq "\\d+" "abcdef")))
    (is (typep seq 'fol.collection:<lazy-seq>))
    (is (fol.collection:empty? seq))))

(test re-seq-with-groups
  "Test re-seq with capturing groups."
  (let ((seq (re-seq "(\\w+)=(\\d+)" "a=1 b=2 c=3")))
    (is (= 3 (fol.collection:size seq)))
    ;; Check first match
    (let* ((first-match (first seq))
           (groups (fol.collection:nth-element first-match 1)))
      (is (string= "a=1" (fol.collection:nth-element first-match 0)))
      (is (string= "a" (fol.collection:get groups "$1")))
      (is (string= "1" (fol.collection:get groups "$2"))))))

(test re-seq-laziness
  "Test that re-seq is actually lazy."
  (let ((seq (re-seq "." "abcd")))
    ;; The sequence exists but hasn't been realized
    (is (typep seq 'fol.collection:<lazy-seq>))
    (is-false (fol.collection:lazy-seq-realized-p seq))
    ;; Accessing first realizes only that part
    (is (string= "a" (fol.collection:nth-element (first seq) 0)))
    ;; Now check full size
    (is (= 4 (fol.collection:size seq)))))

(test re-seq-with-re-pattern
  "Test re-seq with a <re-pattern> argument."
  (let* ((pat (wrap-re-pattern "[a-z]+"))
         (seq (re-seq pat "1abc2def3ghi")))
    (is (= 3 (fol.collection:size seq)))
    (is (string= "abc" (fol.collection:nth-element (first seq) 0)))
    (let ((second-match (first (rest seq))))
      (is (string= "def" (fol.collection:nth-element second-match 0))))
    (let ((third-match (first (rest (rest seq)))))
      (is (string= "ghi" (fol.collection:nth-element third-match 0))))))

(test re-seq-with-re-scanner
  "Test re-seq with a <re-scanner> argument."
  (let* ((pat (wrap-re-pattern "[A-Z]+"))
         (scanner (make-re-scanner pat :case-insensitive t))
         (seq (re-seq scanner "1abc2DEF3ghi")))
    (is (= 3 (fol.collection:size seq)))
    (is (string= "abc" (fol.collection:nth-element (first seq) 0)))
    (is (string= "DEF" (fol.collection:nth-element (first (rest seq)) 0)))
    (is (string= "ghi" (fol.collection:nth-element (first (rest (rest seq))) 0)))))

(test re-seq-empty-matches
  "Test re-seq handles empty matches by advancing."
  ;; Pattern that can match empty string at word boundaries
  (let ((seq (re-seq "\\d*" "a1b")))
    ;; Should find matches: "" at pos 0, "1" at pos 1, "" at pos 2
    (is (cl:>= (fol.collection:size seq) 1))))

(test re-seq-overlapping-positions
  "Test re-seq finds non-overlapping matches."
  (let ((seq (re-seq "aa" "aaaa")))
    ;; Should find "aa" at positions 0 and 2, not overlapping
    (is (= 2 (fol.collection:size seq)))
    (is (string= "aa" (fol.collection:nth-element (first seq) 0)))
    (is (string= "aa" (fol.collection:nth-element (first (rest seq)) 0)))))
