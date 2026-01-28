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


;;; ============================================================================
;;; String Replace Operations Tests
;;; ============================================================================

;;; ---------------------------------------------------------------------------
;;; replace-first Tests
;;; ---------------------------------------------------------------------------

(test replace-first-string-basic
  "Test replace-first with string literal match."
  (is (string= "hello planet" (replace-first "hello world" "world" "planet")))
  (is (string= "goodbye world" (replace-first "hello world" "hello" "goodbye")))
  (is (string= "hXllo world" (replace-first "hello world" "e" "X"))))

(test replace-first-string-no-match
  "Test replace-first when match is not found."
  (is (string= "hello world" (replace-first "hello world" "xyz" "abc")))
  (is (string= "hello world" (replace-first "hello world" "World" "planet"))))

(test replace-first-string-multiple-occurrences
  "Test replace-first only replaces first occurrence."
  (is (string= "Xabab" (replace-first "aabab" "a" "X")))
  (is (string= "hello WORLD world" (replace-first "hello world world" "world" "WORLD"))))

(test replace-first-wrapped-string
  "Test replace-first with wrapped strings."
  (is (string= "hello planet" (replace-first (wrap-string "hello world") "world" "planet")))
  (is (string= "hello planet" (replace-first "hello world" (wrap-string "world") "planet")))
  (is (string= "hello planet" (replace-first "hello world" "world" (wrap-string "planet")))))

(test replace-first-regex-basic
  "Test replace-first with regex pattern."
  (let ((pat (wrap-re-pattern "\\d+")))
    (is (string= "abc###def" (replace-first "abc123def" pat "###")))
    (is (string= "hello NUMBERS" (replace-first "hello 123" pat "NUMBERS")))))

(test replace-first-regex-no-match
  "Test replace-first with regex that doesn't match."
  (let ((pat (wrap-re-pattern "\\d+")))
    (is (string= "hello world" (replace-first "hello world" pat "###")))))

(test replace-first-regex-with-backreference
  "Test replace-first with regex backreferences."
  ;; CL-PPCRE uses \\1, \\2 for backreferences, not $1, $2
  (let ((pat (wrap-re-pattern "(\\w+)@(\\w+)")))
    (is (string= "contact: USER=test" (replace-first "contact: test@example" pat "USER=\\1")))))

(test replace-first-with-function
  "Test replace-first with function replacement."
  (is (string= "hello WORLD" (replace-first "hello world" "world" (lambda (m) (string-upcase m)))))
  (let ((pat (wrap-re-pattern "\\d+")))
    (is (string= "abc[123]def" (replace-first "abc123def" pat (lambda (m groups)
                                                                 (declare (ignore groups))
                                                                 (concatenate 'string "[" m "]")))))))

(test replace-first-empty
  "Test replace-first with empty strings."
  (is (string= "" (replace-first "" "a" "b")))
  ;; Empty string pattern inserts at beginning (CL-PPCRE behavior)
  (is (string= "Xhello world" (replace-first "hello world" "" "X"))))

;;; ---------------------------------------------------------------------------
;;; replace Tests
;;; ---------------------------------------------------------------------------

(test replace-string-basic
  "Test replace with string literal match."
  (is (string= "hello planet" (replace "hello world" "world" "planet")))
  (is (string= "hellX wXrld" (replace "hello world" "o" "X"))))

(test replace-string-no-match
  "Test replace when match is not found."
  (is (string= "hello world" (replace "hello world" "xyz" "abc"))))

(test replace-string-all-occurrences
  "Test replace replaces all occurrences."
  (is (string= "XbXbXb" (replace "ababab" "a" "X")))
  (is (string= "hello WORLD WORLD" (replace "hello world world" "world" "WORLD"))))

(test replace-wrapped-string
  "Test replace with wrapped strings."
  (is (string= "hellX wXrld" (replace (wrap-string "hello world") "o" "X")))
  (is (string= "hellX wXrld" (replace "hello world" (wrap-string "o") "X")))
  (is (string= "hellX wXrld" (replace "hello world" "o" (wrap-string "X")))))

(test replace-regex-basic
  "Test replace with regex pattern."
  (let ((pat (wrap-re-pattern "\\d+")))
    (is (string= "abc###def###ghi" (replace "abc123def456ghi" pat "###")))))

(test replace-regex-with-backreference
  "Test replace with regex backreferences."
  ;; CL-PPCRE uses \\1, \\2 for backreferences, not $1, $2
  (let ((pat (wrap-re-pattern "(\\w+)=(\\d+)")))
    (is (string= "a:[1] b:[2]" (replace "a=1 b=2" pat "\\1:[\\2]")))))

(test replace-with-function
  "Test replace with function replacement."
  ;; Need to use regex pattern for word matching
  (let ((word-pat (wrap-re-pattern "\\w+")))
    (is (string= "HELLO WORLD" (replace "hello world" word-pat (lambda (m groups)
                                                                  (declare (ignore groups))
                                                                  (string-upcase m))))))
  (let ((pat (wrap-re-pattern "\\d+")))
    (is (string= "a[1]b[2]c[3]" (replace "a1b2c3" pat (lambda (m groups)
                                                        (declare (ignore groups))
                                                        (concatenate 'string "[" m "]")))))))

(test replace-empty
  "Test replace with empty strings."
  (is (string= "" (replace "" "a" "b")))
  (is (string= "hello world" (replace "hello world" "" "X"))))


;;; ============================================================================
;;; String Join, Split, and Misc Operations Tests
;;; ============================================================================

;;; ---------------------------------------------------------------------------
;;; join Tests
;;; ---------------------------------------------------------------------------

(test join-basic-list
  "Test join with a list of strings."
  (is (string= "a,b,c" (join "," '("a" "b" "c"))))
  (is (string= "hello world" (join " " '("hello" "world"))))
  (is (string= "1-2-3" (join "-" '("1" "2" "3")))))

(test join-empty-separator
  "Test join with empty separator."
  (is (string= "abc" (join "" '("a" "b" "c")))))

(test join-single-element
  "Test join with single element."
  (is (string= "hello" (join "," '("hello"))))
  (is (string= "test" (join " | " '("test")))))

(test join-empty-list
  "Test join with empty list."
  (is (string= "" (join "," '()))))

(test join-wrapped-separator
  "Test join with wrapped separator."
  (is (string= "a,b,c" (join (wrap-string ",") '("a" "b" "c")))))

(test join-vector
  "Test join with a FOL vector."
  (let ((v (fol.collection:make-vector "a" "b" "c")))
    (is (string= "a,b,c" (join "," v)))))

(test join-fol-list
  "Test join with a FOL list."
  (let ((lst (fol.collection:make-list "a" "b" "c")))
    (is (string= "a,b,c" (join "," lst)))))

(test join-mixed-types
  "Test join converts non-strings to strings."
  (is (string= "1,2,3" (join "," '(1 2 3))))
  (is (string= "a,1,b" (join "," '("a" 1 "b")))))

(test join-characters
  "Test join with characters."
  (is (string= "a-b-c" (join "-" '(#\a #\b #\c)))))

;;; ---------------------------------------------------------------------------
;;; escape Tests
;;; ---------------------------------------------------------------------------

(test escape-basic
  "Test escape with character map."
  (let ((cmap (fol.collection:make-dict #\< "&lt;" #\> "&gt;")))
    (is (string= "&lt;div&gt;hello&lt;/div&gt;" (escape "<div>hello</div>" cmap)))))

(test escape-no-replacements
  "Test escape when no characters match."
  (let ((cmap (fol.collection:make-dict #\< "&lt;" #\> "&gt;")))
    (is (string= "hello world" (escape "hello world" cmap)))))

(test escape-all-characters
  "Test escape when all characters match."
  (let ((cmap (fol.collection:make-dict #\a "X" #\b "Y")))
    (is (string= "XYX" (escape "aba" cmap)))))

(test escape-empty-string
  "Test escape with empty string."
  (let ((cmap (fol.collection:make-dict #\a "X")))
    (is (string= "" (escape "" cmap)))))

(test escape-wrapped-string
  "Test escape with wrapped string."
  (let ((cmap (fol.collection:make-dict #\< "&lt;" #\> "&gt;")))
    (is (string= "&lt;test&gt;" (escape (wrap-string "<test>") cmap)))))

(test escape-html-entities
  "Test escape for HTML entity escaping."
  (let ((cmap (fol.collection:make-dict #\& "&amp;" #\< "&lt;" #\> "&gt;" #\" "&quot;")))
    (is (string= "&lt;a href=&quot;test&quot;&gt;click &amp; go&lt;/a&gt;"
                 (escape "<a href=\"test\">click & go</a>" cmap)))))

;;; ---------------------------------------------------------------------------
;;; split Tests
;;; ---------------------------------------------------------------------------

(test split-basic
  "Test split with simple pattern."
  (let ((result (split "a,b,c" ",")))
    (is (typep result 'fol.collection:<vector>))
    (is (= 3 (fol.collection:size result)))
    (is (string= "a" (fol.collection:nth-element result 0)))
    (is (string= "b" (fol.collection:nth-element result 1)))
    (is (string= "c" (fol.collection:nth-element result 2)))))

(test split-regex
  "Test split with regex pattern."
  (let ((result (split "a1b2c3d" "\\d")))
    (is (= 4 (fol.collection:size result)))
    (is (string= "a" (fol.collection:nth-element result 0)))
    (is (string= "d" (fol.collection:nth-element result 3)))))

(test split-with-limit
  "Test split with limit argument."
  (let ((result (split "a,b,c,d" "," 2)))
    (is (= 2 (fol.collection:size result)))
    (is (string= "a" (fol.collection:nth-element result 0)))
    (is (string= "b,c,d" (fol.collection:nth-element result 1)))))

(test split-no-match
  "Test split when pattern doesn't match."
  (let ((result (split "hello world" ",")))
    (is (= 1 (fol.collection:size result)))
    (is (string= "hello world" (fol.collection:nth-element result 0)))))

(test split-empty-string
  "Test split with empty string."
  ;; CL-PPCRE returns empty list for empty string
  (let ((result (split "" ",")))
    (is (= 0 (fol.collection:size result)))))

(test split-wrapped
  "Test split with wrapped string."
  (let ((result (split (wrap-string "a,b,c") ",")))
    (is (= 3 (fol.collection:size result)))))

(test split-re-pattern
  "Test split with <re-pattern>."
  (let* ((pat (wrap-re-pattern "\\s+"))
         (result (split "hello   world  test" pat)))
    (is (= 3 (fol.collection:size result)))
    (is (string= "hello" (fol.collection:nth-element result 0)))
    (is (string= "world" (fol.collection:nth-element result 1)))
    (is (string= "test" (fol.collection:nth-element result 2)))))

;;; ---------------------------------------------------------------------------
;;; split-lines Tests
;;; ---------------------------------------------------------------------------

(test split-lines-basic
  "Test split-lines with LF."
  (let ((result (split-lines (format nil "line1~%line2~%line3"))))
    (is (typep result 'fol.collection:<vector>))
    (is (= 3 (fol.collection:size result)))
    (is (string= "line1" (fol.collection:nth-element result 0)))
    (is (string= "line2" (fol.collection:nth-element result 1)))
    (is (string= "line3" (fol.collection:nth-element result 2)))))

(test split-lines-crlf
  "Test split-lines with CRLF."
  (let ((result (split-lines (concatenate 'string "line1" (string #\Return) (string #\Newline)
                                          "line2" (string #\Return) (string #\Newline)
                                          "line3"))))
    (is (= 3 (fol.collection:size result)))
    (is (string= "line1" (fol.collection:nth-element result 0)))))

(test split-lines-single-line
  "Test split-lines with no newlines."
  (let ((result (split-lines "hello world")))
    (is (= 1 (fol.collection:size result)))
    (is (string= "hello world" (fol.collection:nth-element result 0)))))

(test split-lines-empty
  "Test split-lines with empty string."
  ;; CL-PPCRE returns empty list for empty string
  (let ((result (split-lines "")))
    (is (= 0 (fol.collection:size result)))))

(test split-lines-wrapped
  "Test split-lines with wrapped string."
  (let ((result (split-lines (wrap-string (format nil "a~%b~%c")))))
    (is (= 3 (fol.collection:size result)))))

;;; ---------------------------------------------------------------------------
;;; reverse Tests (for strings)
;;; ---------------------------------------------------------------------------

(test reverse-string-basic
  "Test reverse with basic strings."
  (is (string= "olleh" (reverse "hello")))
  (is (string= "dlrow olleh" (reverse "hello world")))
  (is (string= "321" (reverse "123"))))

(test reverse-string-empty
  "Test reverse with empty string."
  (is (string= "" (reverse ""))))

(test reverse-string-single-char
  "Test reverse with single character."
  (is (string= "a" (reverse "a"))))

(test reverse-string-wrapped
  "Test reverse with wrapped string."
  (is (string= "olleh" (reverse (wrap-string "hello")))))

(test reverse-string-palindrome
  "Test reverse with palindrome."
  (is (string= "racecar" (reverse "racecar")))
  (is (string= "level" (reverse "level"))))

(test reverse-string-unicode
  "Test reverse with unicode."
  (is (string= "界世好你" (reverse "你好世界"))))


;;; ============================================================================
;;; String Index Operations Tests
;;; ============================================================================

;;; ---------------------------------------------------------------------------
;;; index-of Tests (for strings)
;;; ---------------------------------------------------------------------------

(test index-of-string-basic
  "Test index-of with string search."
  (is (= 6 (index-of "hello world" "world")))
  (is (= 0 (index-of "hello world" "hello")))
  (is (= 4 (index-of "hello world" "o"))))

(test index-of-string-not-found
  "Test index-of when substring not found."
  (is (null (index-of "hello world" "xyz")))
  (is (null (index-of "hello world" "World"))))

(test index-of-string-character
  "Test index-of with character search."
  (is (= 4 (index-of "hello" #\o)))
  (is (= 0 (index-of "hello" #\h)))
  (is (null (index-of "hello" #\z))))

(test index-of-string-from-index
  "Test index-of with from-index."
  (is (= 7 (index-of "hello world" "o" 5)))
  (is (null (index-of "hello world" "hello" 1))))

(test index-of-string-wrapped
  "Test index-of with wrapped strings."
  (is (= 6 (index-of (wrap-string "hello world") "world")))
  (is (= 6 (index-of "hello world" (wrap-string "world")))))

(test index-of-string-empty
  "Test index-of with empty strings."
  (is (= 0 (index-of "hello" "")))
  (is (null (index-of "" "a"))))

;;; ---------------------------------------------------------------------------
;;; last-index-of Tests (for strings)
;;; ---------------------------------------------------------------------------

(test last-index-of-string-basic
  "Test last-index-of with string search."
  (is (= 6 (last-index-of "hello world" "world")))
  (is (= 7 (last-index-of "hello world" "o")))
  (is (= 10 (last-index-of "abracadabra" "a"))))

(test last-index-of-string-not-found
  "Test last-index-of when substring not found."
  (is (null (last-index-of "hello world" "xyz")))
  (is (null (last-index-of "hello world" "World"))))

(test last-index-of-string-character
  "Test last-index-of with character search."
  (is (= 4 (last-index-of "hello" #\o)))
  (is (= 3 (last-index-of "hello" #\l)))
  (is (null (last-index-of "hello" #\z))))

(test last-index-of-string-from-index
  "Test last-index-of with from-index (searches up to that index)."
  (is (= 4 (last-index-of "hello world" "o" 6)))
  (is (= 4 (last-index-of "hello world" "o" 4)))
  (is (null (last-index-of "hello world" "o" 3))))

(test last-index-of-string-wrapped
  "Test last-index-of with wrapped strings."
  (is (= 7 (last-index-of (wrap-string "hello world") "o")))
  (is (= 7 (last-index-of "hello world" (wrap-string "o")))))

(test last-index-of-string-empty
  "Test last-index-of with empty strings."
  (is (= 5 (last-index-of "hello" "")))
  (is (null (last-index-of "" "a"))))


;;; ---------------------------------------------------------------------------
;;; index-of Tests for Regex Patterns
;;; ---------------------------------------------------------------------------

(test index-of-string-regex
  "Test index-of with regex pattern."
  (let ((pat (wrap-re-pattern "\\d+")))
    (is (= 5 (index-of "hello123world" pat)))
    (is (= 0 (index-of "123abc" pat)))
    (is (null (index-of "hello world" pat)))))

(test index-of-string-regex-with-start
  "Test index-of with regex pattern and start index."
  (let ((pat (wrap-re-pattern "\\d+")))
    (is (= 5 (index-of "hello123world456" pat)))
    (is (= 13 (index-of "hello123world456" pat 8)))))


;;; ---------------------------------------------------------------------------
;;; parse-uuid Tests
;;; ---------------------------------------------------------------------------

(test parse-uuid-basic
  "Test parse-uuid with standard UUID format."
  (let ((result (parse-uuid "6ba7b810-9dad-11d1-80b4-00c04fd430c8")))
    (is-true (<uuid>? result))
    (is (typep result '<uuid>))))

(test parse-uuid-uppercase
  "Test parse-uuid with uppercase UUID."
  (let ((result (parse-uuid "6BA7B810-9DAD-11D1-80B4-00C04FD430C8")))
    (is-true (<uuid>? result))
    (is (typep result '<uuid>))))

(test parse-uuid-mixed-case
  "Test parse-uuid with mixed case UUID."
  (let ((result (parse-uuid "6Ba7B810-9dAd-11D1-80b4-00C04fD430c8")))
    (is-true (<uuid>? result))
    (is (typep result '<uuid>))))

(test parse-uuid-nil-uuid
  "Test parse-uuid with nil UUID (all zeros)."
  (let ((result (parse-uuid "00000000-0000-0000-0000-000000000000")))
    (is-true (<uuid>? result))
    (is (typep result '<uuid>))))

(test parse-uuid-invalid-format
  "Test parse-uuid with invalid format signals error."
  (signals error (parse-uuid "invalid")))

(test parse-uuid-invalid-type
  "Test parse-uuid with invalid input type signals error."
  (signals error (parse-uuid 123)))
