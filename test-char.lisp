(in-package fol.tests)
(in-readtable fol-syntax)

(in-suite fol-suite)

(test char-wrapping
  "Test wrapping and unwrapping of characters"
  ;; ASCII characters
  (is (typep (wrap #\a) '<char>))
  (is (eq #\a (unwrap (wrap #\a))))
  (is (eq #\Z (unwrap (wrap #\Z))))
  (is (eq #\0 (unwrap (wrap #\0))))
  (is (eq #\9 (unwrap (wrap #\9))))
  
  ;; Special characters
  (is (eq #\Space (unwrap (wrap #\Space))))
  (is (eq #\Newline (unwrap (wrap #\Newline))))
  (is (eq #\Tab (unwrap (wrap #\Tab))))
  
  ;; Punctuation
  (is (eq #\! (unwrap (wrap #\!))))
  (is (eq #\? (unwrap (wrap #\?))))
  (is (eq #\. (unwrap (wrap #\.))))
  (is (eq #\, (unwrap (wrap #\,))))
  
  ;; Already wrapped
  (let ((wrapped-a (wrap #\a)))
    (is (eq wrapped-a (wrap wrapped-a)))))

(test char-unicode
  "Test Unicode character support"
  ;; Greek letters
  (is (eq #\α (unwrap (wrap #\α))))
  (is (eq #\β (unwrap (wrap #\β))))
  (is (eq #\Ω (unwrap (wrap #\Ω))))
  
  ;; Emoji (if supported by implementation)
  #+(or sbcl ccl)
  (progn
    (is (eq #\😀 (unwrap (wrap #\😀))))
    (is (eq #\🎉 (unwrap (wrap #\🎉)))))
  
  ;; Mathematical symbols
  (is (eq #\∀ (unwrap (wrap #\∀))))
  (is (eq #\∃ (unwrap (wrap #\∃))))
  (is (eq #\∈ (unwrap (wrap #\∈))))
  (is (eq #\∉ (unwrap (wrap #\∉))))
  
  ;; Currency symbols
  (is (eq #\€ (unwrap (wrap #\€))))
  (is (eq #\£ (unwrap (wrap #\£))))
  (is (eq #\¥ (unwrap (wrap #\¥))))
  
  ;; Arrows
  (is (eq #\→ (unwrap (wrap #\→))))
  (is (eq #\← (unwrap (wrap #\←))))
  (is (eq #\↔ (unwrap (wrap #\↔)))))


(test char-case-conversion
  "Test character case conversion"
  (let ((lower-a (wrap #\a))
        (upper-a (wrap #\A))
        (lower-z (wrap #\z))
        (upper-z (wrap #\Z)))
    ;; Upcase
    (is (eq #\A (unwrap (char-upcase lower-a))))
    (is (eq #\A (unwrap (char-upcase upper-a))))
    (is (eq #\Z (unwrap (char-upcase lower-z))))
    
    ;; Downcase
    (is (eq #\a (unwrap (char-downcase upper-a))))
    (is (eq #\a (unwrap (char-downcase lower-a))))
    (is (eq #\z (unwrap (char-downcase upper-z))))
    
    ;; Non-alphabetic characters unchanged
    (is (eq #\0 (unwrap (char-upcase (wrap #\0)))))
    (is (eq #\! (unwrap (char-downcase (wrap #\!)))))
    
    ;; Unicode case conversion
    (is (eq #\Α (unwrap (char-upcase (wrap #\α)))))
    (is (eq #\ω (unwrap (char-downcase (wrap #\Ω)))))))

(test char-predicates
  "Test character classification predicates"
  ;; Alphabetic
  (is (unwrap (alpha-char? (wrap #\a))))
  (is (unwrap (alpha-char? (wrap #\Z))))
  (is (unwrap (not (alpha-char? (wrap #\0)))))
  (is (unwrap (not (alpha-char? (wrap #\!)))))
  
  ;; Digit
  (is (unwrap (digit-char? (wrap #\0))))
  (is (unwrap (digit-char? (wrap #\9))))
  (is (unwrap (not (digit-char? (wrap #\a)))))
  (is (unwrap (not (digit-char? (wrap #\!)))))
  
  ;; Alphanumeric
  (is (unwrap (alphanumeric? (wrap #\a))))
  (is (unwrap (alphanumeric? (wrap #\Z))))
  (is (unwrap (alphanumeric? (wrap #\0))))
  (is (unwrap (alphanumeric? (wrap #\9))))
  (is (unwrap (not (alphanumeric? (wrap #\!)))))
  (is (unwrap (not (alphanumeric? (wrap #\Space)))))
  
  ;; Upper case
  (is (unwrap (upper-case? (wrap #\A))))
  (is (unwrap (upper-case? (wrap #\Z))))
  (is (unwrap (not (upper-case? (wrap #\a)))))
  (is (unwrap (not (upper-case? (wrap #\0)))))
  
  ;; Lower case
  (is (unwrap (lower-case? (wrap #\a))))
  (is (unwrap (lower-case? (wrap #\z))))
  (is (unwrap (not (lower-case? (wrap #\A)))))
  (is (unwrap (not (lower-case? (wrap #\0)))))
  
  ;; Whitespace
  (is (unwrap (whitespace? (wrap #\Space))))
  (is (unwrap (whitespace? (wrap #\Tab))))
  (is (unwrap (whitespace? (wrap #\Newline))))
  (is (unwrap (not (whitespace? (wrap #\a)))))
  (is (unwrap (not (whitespace? (wrap #\0))))))

(test char-type-predicates
  "Test FOL type predicates for characters"
  (let ((c (wrap #\x)))
    (is (unwrap (<char>? c)))
    (is (unwrap (not (<bool>? c))))
    (is (unwrap (not (<number>? c))))))

(test char-printing
  "Test character printing"
  ;; Regular characters
  (is (equal "#\\a" (format nil "~A" (wrap #\a))))
  (is (equal "#\\Z" (format nil "~A" (wrap #\Z))))
  (is (equal "#\\0" (format nil "~A" (wrap #\0))))
  
  ;; Special characters with names
  (is (equal "#\\Space" (format nil "~A" (wrap #\Space))))
  (is (equal "#\\Newline" (format nil "~A" (wrap #\Newline))))
  (is (equal "#\\Tab" (format nil "~A" (wrap #\Tab))))
  
  ;; Unicode
  (is (equal "#\\α" (format nil "~A" (wrap #\α))))
  (is (equal "#\\∀" (format nil "~A" (wrap #\∀)))))

(test char-list-operations
  "Test operations on lists of characters"
  (let ((chars (mapcar #'wrap '(#\h #\e #\l #\l #\o))))
    (is (= 5 (length chars)))
    (is (every (lambda (c) (typep c '<char>)) chars))
    (is (equal '(#\h #\e #\l #\l #\o)
               (mapcar #'unwrap chars)))))