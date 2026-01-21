(in-package :fol.tests)

(def-suite char-suite
  :description "Tests for FOL character operations"
  :in fol-suite)

(in-suite char-suite)

;;; ============================================================================
;;; Character Type Predicate (<char>?)
;;; ============================================================================

(test char-predicate-raw
  "Test <char>? with raw characters"
  (is (eq t (<char>? #\a)))
  (is (eq t (<char>? #\A)))
  (is (eq t (<char>? #\0)))
  (is (eq t (<char>? #\Space)))
  (is (eq t (<char>? #\Newline)))
  (is (eq t (<char>? #\Tab))))

(test char-predicate-wrapped
  "Test <char>? with wrapped characters"
  (is (eq t (<char>? (wrap #\a))))
  (is (eq t (<char>? (wrap #\Z))))
  (is (eq t (<char>? (wrap #\Space)))))

(test char-predicate-non-chars
  "Test <char>? returns nil for non-characters"
  (is (eq nil (<char>? "a")))
  (is (eq nil (<char>? 65)))
  (is (eq nil (<char>? 'a)))
  (is (eq nil (<char>? nil)))
  (is (eq nil (<char>? t))))

;;; ============================================================================
;;; Character Case Conversion
;;; ============================================================================

(test char-upcase-raw
  "Test char-upcase with raw characters"
  ;; Lowercase to uppercase
  (is (char= #\A (char-upcase #\a)))
  (is (char= #\Z (char-upcase #\z)))
  (is (char= #\M (char-upcase #\m)))
  ;; Already uppercase - unchanged
  (is (char= #\A (char-upcase #\A)))
  (is (char= #\Z (char-upcase #\Z)))
  ;; Non-alphabetic - unchanged
  (is (char= #\0 (char-upcase #\0)))
  (is (char= #\9 (char-upcase #\9)))
  (is (char= #\Space (char-upcase #\Space)))
  (is (char= #\! (char-upcase #\!))))

(test char-upcase-wrapped
  "Test char-upcase with wrapped characters"
  (is (char= #\A (char-upcase (wrap #\a))))
  (is (char= #\Z (char-upcase (wrap #\z))))
  (is (char= #\0 (char-upcase (wrap #\0)))))

(test char-downcase-raw
  "Test char-downcase with raw characters"
  ;; Uppercase to lowercase
  (is (char= #\a (char-downcase #\A)))
  (is (char= #\z (char-downcase #\Z)))
  (is (char= #\m (char-downcase #\M)))
  ;; Already lowercase - unchanged
  (is (char= #\a (char-downcase #\a)))
  (is (char= #\z (char-downcase #\z)))
  ;; Non-alphabetic - unchanged
  (is (char= #\0 (char-downcase #\0)))
  (is (char= #\9 (char-downcase #\9)))
  (is (char= #\Space (char-downcase #\Space)))
  (is (char= #\! (char-downcase #\!))))

(test char-downcase-wrapped
  "Test char-downcase with wrapped characters"
  (is (char= #\a (char-downcase (wrap #\A))))
  (is (char= #\z (char-downcase (wrap #\Z))))
  (is (char= #\0 (char-downcase (wrap #\0)))))

(test char-case-roundtrip
  "Test upcase/downcase roundtrip"
  (is (char= #\a (char-downcase (char-upcase #\a))))
  (is (char= #\A (char-upcase (char-downcase #\A))))
  ;; Non-alphabetic stays same
  (is (char= #\5 (char-downcase (char-upcase #\5)))))

;;; ============================================================================
;;; Alphabetic Character Predicate
;;; ============================================================================

(test alpha-char-lowercase
  "Test alpha-char? with lowercase letters"
  (is (eq t (alpha-char? #\a)))
  (is (eq t (alpha-char? #\m)))
  (is (eq t (alpha-char? #\z))))

(test alpha-char-uppercase
  "Test alpha-char? with uppercase letters"
  (is (eq t (alpha-char? #\A)))
  (is (eq t (alpha-char? #\M)))
  (is (eq t (alpha-char? #\Z))))

(test alpha-char-non-alpha
  "Test alpha-char? with non-alphabetic characters"
  (is (eq nil (alpha-char? #\0)))
  (is (eq nil (alpha-char? #\9)))
  (is (eq nil (alpha-char? #\Space)))
  (is (eq nil (alpha-char? #\!)))
  (is (eq nil (alpha-char? #\@)))
  (is (eq nil (alpha-char? #\Newline))))

(test alpha-char-wrapped
  "Test alpha-char? with wrapped characters"
  (is (eq t (alpha-char? (wrap #\a))))
  (is (eq t (alpha-char? (wrap #\Z))))
  (is (eq nil (alpha-char? (wrap #\5)))))

;;; ============================================================================
;;; Digit Character Predicate
;;; ============================================================================

(test digit-char-digits
  "Test digit-char? with digit characters"
  (is (eq t (digit-char? #\0)))
  (is (eq t (digit-char? #\1)))
  (is (eq t (digit-char? #\5)))
  (is (eq t (digit-char? #\9))))

(test digit-char-non-digits
  "Test digit-char? with non-digit characters"
  (is (eq nil (digit-char? #\a)))
  (is (eq nil (digit-char? #\A)))
  (is (eq nil (digit-char? #\Space)))
  (is (eq nil (digit-char? #\!)))
  (is (eq nil (digit-char? #\Newline))))

(test digit-char-wrapped
  "Test digit-char? with wrapped characters"
  (is (eq t (digit-char? (wrap #\0))))
  (is (eq t (digit-char? (wrap #\9))))
  (is (eq nil (digit-char? (wrap #\a)))))

;;; ============================================================================
;;; Alphanumeric Character Predicate
;;; ============================================================================

(test alphanumeric-letters
  "Test alphanumeric? with letters"
  (is (eq t (alphanumeric? #\a)))
  (is (eq t (alphanumeric? #\Z)))
  (is (eq t (alphanumeric? #\m)))
  (is (eq t (alphanumeric? #\M))))

(test alphanumeric-digits
  "Test alphanumeric? with digits"
  (is (eq t (alphanumeric? #\0)))
  (is (eq t (alphanumeric? #\5)))
  (is (eq t (alphanumeric? #\9))))

(test alphanumeric-non-alphanumeric
  "Test alphanumeric? with non-alphanumeric characters"
  (is (eq nil (alphanumeric? #\Space)))
  (is (eq nil (alphanumeric? #\!)))
  (is (eq nil (alphanumeric? #\@)))
  (is (eq nil (alphanumeric? #\-)))
  (is (eq nil (alphanumeric? #\_)))
  (is (eq nil (alphanumeric? #\Newline))))

(test alphanumeric-wrapped
  "Test alphanumeric? with wrapped characters"
  (is (eq t (alphanumeric? (wrap #\a))))
  (is (eq t (alphanumeric? (wrap #\5))))
  (is (eq nil (alphanumeric? (wrap #\!)))))

;;; ============================================================================
;;; Upper Case Predicate
;;; ============================================================================

(test upper-case-uppercase
  "Test upper-case? with uppercase letters"
  (is (eq t (upper-case? #\A)))
  (is (eq t (upper-case? #\M)))
  (is (eq t (upper-case? #\Z))))

(test upper-case-lowercase
  "Test upper-case? with lowercase letters"
  (is (eq nil (upper-case? #\a)))
  (is (eq nil (upper-case? #\m)))
  (is (eq nil (upper-case? #\z))))

(test upper-case-non-alpha
  "Test upper-case? with non-alphabetic characters"
  (is (eq nil (upper-case? #\0)))
  (is (eq nil (upper-case? #\Space)))
  (is (eq nil (upper-case? #\!))))

(test upper-case-wrapped
  "Test upper-case? with wrapped characters"
  (is (eq t (upper-case? (wrap #\A))))
  (is (eq nil (upper-case? (wrap #\a))))
  (is (eq nil (upper-case? (wrap #\5)))))

;;; ============================================================================
;;; Lower Case Predicate
;;; ============================================================================

(test lower-case-lowercase
  "Test lower-case? with lowercase letters"
  (is (eq t (lower-case? #\a)))
  (is (eq t (lower-case? #\m)))
  (is (eq t (lower-case? #\z))))

(test lower-case-uppercase
  "Test lower-case? with uppercase letters"
  (is (eq nil (lower-case? #\A)))
  (is (eq nil (lower-case? #\M)))
  (is (eq nil (lower-case? #\Z))))

(test lower-case-non-alpha
  "Test lower-case? with non-alphabetic characters"
  (is (eq nil (lower-case? #\0)))
  (is (eq nil (lower-case? #\Space)))
  (is (eq nil (lower-case? #\!))))

(test lower-case-wrapped
  "Test lower-case? with wrapped characters"
  (is (eq t (lower-case? (wrap #\a))))
  (is (eq nil (lower-case? (wrap #\A))))
  (is (eq nil (lower-case? (wrap #\5)))))

;;; ============================================================================
;;; Whitespace Predicate
;;; ============================================================================

(test whitespace-standard
  "Test whitespace? with standard whitespace characters"
  (is (eq t (whitespace? #\Space)))
  (is (eq t (whitespace? #\Tab)))
  (is (eq t (whitespace? #\Newline)))
  (is (eq t (whitespace? #\Return)))
  (is (eq t (whitespace? #\Linefeed)))
  (is (eq t (whitespace? #\Page))))

(test whitespace-non-whitespace
  "Test whitespace? with non-whitespace characters"
  (is (eq nil (whitespace? #\a)))
  (is (eq nil (whitespace? #\A)))
  (is (eq nil (whitespace? #\0)))
  (is (eq nil (whitespace? #\!)))
  (is (eq nil (whitespace? #\_))))

(test whitespace-wrapped
  "Test whitespace? with wrapped characters"
  (is (eq t (whitespace? (wrap #\Space))))
  (is (eq t (whitespace? (wrap #\Tab))))
  (is (eq t (whitespace? (wrap #\Newline))))
  (is (eq nil (whitespace? (wrap #\a)))))

;;; ============================================================================
;;; Edge Cases - Special Characters
;;; ============================================================================

(test special-characters-predicates
  "Test predicates with special characters"
  ;; Backspace
  (is (eq nil (alpha-char? #\Backspace)))
  (is (eq nil (digit-char? #\Backspace)))
  (is (eq nil (alphanumeric? #\Backspace)))
  ;; Null character
  (is (eq nil (alpha-char? #\Null)))
  (is (eq nil (whitespace? #\Null)))
  ;; Escape
  (is (eq nil (alpha-char? #\Escape)))
  ;; Rubout/Delete
  (is (eq nil (alpha-char? #\Rubout))))

(test special-characters-case
  "Test case conversion with special characters"
  ;; Case conversion on non-alphabetic should return unchanged
  (is (char= #\Backspace (char-upcase #\Backspace)))
  (is (char= #\Backspace (char-downcase #\Backspace)))
  (is (char= #\Null (char-upcase #\Null)))
  (is (char= #\Null (char-downcase #\Null))))

;;; ============================================================================
;;; Edge Cases - Boundary Characters
;;; ============================================================================

(test boundary-characters
  "Test with boundary characters (edge of ranges)"
  ;; First and last lowercase
  (is (eq t (lower-case? #\a)))
  (is (eq t (lower-case? #\z)))
  ;; First and last uppercase
  (is (eq t (upper-case? #\A)))
  (is (eq t (upper-case? #\Z)))
  ;; First and last digit
  (is (eq t (digit-char? #\0)))
  (is (eq t (digit-char? #\9)))
  ;; Characters just outside alphabetic range
  (is (eq nil (alpha-char? #\@)))  ; before A
  (is (eq nil (alpha-char? #\[)))  ; after Z
  (is (eq nil (alpha-char? #\`)))  ; before a
  (is (eq nil (alpha-char? #\{)))  ; after z
  ;; Characters just outside digit range
  (is (eq nil (digit-char? #\/)))  ; before 0
  (is (eq nil (digit-char? #\:)))) ; after 9

;;; ============================================================================
;;; Combination Tests
;;; ============================================================================

(test predicate-combinations
  "Test logical combinations of predicates"
  ;; A letter is alpha AND alphanumeric
  (is (eq (alpha-char? #\a) (alphanumeric? #\a)))
  ;; A digit is NOT alpha but IS alphanumeric
  (is (eq nil (alpha-char? #\5)))
  (is (eq t (alphanumeric? #\5)))
  ;; Uppercase implies alpha
  (is (eq t (alpha-char? #\A)))
  (is (eq t (upper-case? #\A)))
  ;; Lowercase implies alpha
  (is (eq t (alpha-char? #\z)))
  (is (eq t (lower-case? #\z))))

(test upcase-downcase-consistency
  "Test that upcase/downcase are consistent"
  ;; For all uppercase letters, downcase produces lowercase
  (loop for c from (char-code #\A) to (char-code #\Z)
        for ch = (code-char c)
        do (is (lower-case? (char-downcase ch))))
  ;; For all lowercase letters, upcase produces uppercase
  (loop for c from (char-code #\a) to (char-code #\z)
        for ch = (code-char c)
        do (is (upper-case? (char-upcase ch)))))

;;; ============================================================================
;;; Wrapped Character Comparison (using compareop)
;;; ============================================================================

(test char-comparison-equality
  "Test character equality comparison"
  (let ((wa (wrap #\a))
        (wa2 (wrap #\a))
        (wb (wrap #\b)))
    (is (eq t (%= wa wa2)))
    (is (eq nil (%= wa wb)))
    (is (eq t (%= wa #\a)))
    (is (eq t (%= #\a wa)))))

(test char-comparison-ordering
  "Test character ordering comparison"
  (let ((wa (wrap #\a))
        (wb (wrap #\b)))
    (is (eq t (%< wa wb)))
    (is (eq nil (%< wb wa)))
    (is (eq t (%<= wa wa)))
    (is (eq t (%<= wa wb)))
    (is (eq t (%> wb wa)))
    (is (eq nil (%> wa wb)))
    (is (eq t (%>= wb wb)))
    (is (eq t (%>= wb wa)))))

;;; ============================================================================
;;; Print Representation
;;; ============================================================================

(test char-print-regular
  "Test print representation of regular characters"
  (let ((wa (wrap #\a)))
    ;; Just verify it doesn't error
    (is (stringp (format nil "~A" wa)))))

(test char-print-special
  "Test print representation of special characters"
  (let ((space (wrap #\Space))
        (newline (wrap #\Newline))
        (tab (wrap #\Tab)))
    ;; Just verify they don't error
    (is (stringp (format nil "~A" space)))
    (is (stringp (format nil "~A" newline)))
    (is (stringp (format nil "~A" tab)))))
