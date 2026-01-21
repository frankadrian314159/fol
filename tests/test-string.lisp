(in-package :fol.tests)

;;; ============================================================================
;;; String Tests - Comprehensive test suite for FOL string operations
;;; ============================================================================

(def-suite* :fol.string-tests)

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
