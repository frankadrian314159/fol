(in-package fol.tests)
(in-readtable fol-syntax)

(in-suite fol-suite)

(test string-wrapping
  "Test wrapping and unwrapping of strings"
  (let ((s (wrap "hello")))
    (is (typep s '<string>))
    (is (equal "hello" (unwrap s)))
    ;; Ensure identity of wrapped strings if reused (not guaranteed, but by value it works)
    (is (equal "world" (unwrap (wrap "world"))))))

(test string-unicode
  "Test strings with Unicode characters"
  (let ((s1 (wrap "Hello 🌍"))      ; Emoji
        (s2 (wrap "αβγ"))           ; Greek
        (s3 (wrap "こんにちは")))   ; Japanese (Hiragana)
    
    ;; Check Type
    (is (typep s1 '<string>))
    
    ;; Check Unwrapping
    (is (equal "Hello 🌍" (unwrap s1)))
    (is (equal "αβγ" (unwrap s2)))
    (is (equal "こんにちは" (unwrap s3)))
    
    ;; Check Equality
    (is (unwrap (= s1 (wrap "Hello 🌍"))))
    (is (unwrap (/= s1 s2)))
    
    ;; Check Printing (format ~A uses print-object -> ~S)
    ;; Note: Lisp printers generally handle unicode by outputting the characters directly.
    (is (equal "\"αβγ\"" (format nil "~A" s2)))))

(test string-predicates
  "Test string type predicates"
  (let ((s (wrap "test")))
    (is (unwrap (<string>? s)))
    (is (unwrap (not (<string>? (wrap 123)))))
    (is (unwrap (not (<string>? (wrap #\c)))))
    (is (unwrap (not (<string>? #t))))))

(test string-equality
  "Test string equality operations"
  (let ((s1 (wrap "foo"))
        (s2 (wrap "foo"))
        (s3 (wrap "bar")))
    ;; Equality
    (is (unwrap (= s1 s2)))
    (is (unwrap (= s1 (wrap "foo"))))
    
    ;; Inequality
    (is (unwrap (/= s1 s3)))
    (is (unwrap (not (= s1 s3))))
    
    ;; Mixed types
    (is (unwrap (not (= s1 (wrap 123)))))))

(test string-ordering
  "Test string comparison/ordering operations"
  (let ((a (wrap "apple"))
        (b (wrap "banana"))
        (a2 (wrap "apple")))
    
    ;; Less than
    (is (unwrap (< a b)))
    (is (unwrap (not (< b a))))
    (is (unwrap (not (< a a2))))
    
    ;; Greater than
    (is (unwrap (> b a)))
    (is (unwrap (not (> a b))))
    
    ;; Less than or equal
    (is (unwrap (<= a b)))
    (is (unwrap (<= a a2)))
    
    ;; Greater than or equal
    (is (unwrap (>= b a)))
    (is (unwrap (>= a a2)))))

(test string-printing
  "Test string printing"
  (let ((s (wrap "hello")))
    ;; print-object should use ~S, so it includes quotes
    (is (equal "\"hello\"" (format nil "~A" s)))))