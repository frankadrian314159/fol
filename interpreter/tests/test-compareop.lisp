(in-package :fol.tests)

(def-suite compareop-suite
  :description "Tests for FOL comparison operations"
  :in fol-suite)

(in-suite compareop-suite)

;;; ============================================================================
;;; Binary Primitive Equality (%=)
;;; ============================================================================

(test binary-equality-numbers-raw
  "Test %= with raw numbers"
  ;; Integers
  (is (eq t (%= 5 5)))
  (is (eq nil (%= 5 6)))
  (is (eq t (%= 0 0)))
  (is (eq t (%= -5 -5)))
  ;; Floats
  (is (eq t (%= 3.14 3.14)))
  (is (eq nil (%= 3.14 3.15)))
  ;; Ratios
  (is (eq t (%= 1/2 1/2)))
  (is (eq t (%= 2/4 1/2)))
  (is (eq nil (%= 1/2 1/3)))
  ;; Mixed numeric types that are equal
  (is (eq t (%= 2 2.0)))
  (is (eq t (%= 1/2 0.5)))
  (is (eq t (%= 4/2 2))))

(test binary-equality-numbers-wrapped
  "Test %= with wrapped numbers"
  (let ((w5 (wrap 5))
        (w5b (wrap 5))
        (w6 (wrap 6)))
    (is (eq t (%= w5 w5b)))
    (is (eq nil (%= w5 w6)))
    ;; Mixed wrapped/raw
    (is (eq t (%= w5 5)))
    (is (eq t (%= 5 w5)))
    (is (eq nil (%= w5 6)))))

(test binary-equality-characters-raw
  "Test %= with raw characters"
  (is (eq t (%= #\a #\a)))
  (is (eq nil (%= #\a #\b)))
  (is (eq nil (%= #\a #\A)))  ; case sensitive
  (is (eq t (%= #\Space #\Space)))
  (is (eq t (%= #\Newline #\Newline))))

(test binary-equality-characters-wrapped
  "Test %= with wrapped characters"
  (let ((wa (wrap #\a))
        (wa2 (wrap #\a))
        (wb (wrap #\b)))
    (is (eq t (%= wa wa2)))
    (is (eq nil (%= wa wb)))
    ;; Mixed wrapped/raw
    (is (eq t (%= wa #\a)))
    (is (eq t (%= #\a wa)))))

(test binary-equality-strings-raw
  "Test %= with raw strings"
  (is (eq t (%= "hello" "hello")))
  (is (eq nil (%= "hello" "world")))
  (is (eq nil (%= "hello" "Hello")))  ; case sensitive
  (is (eq t (%= "" "")))
  (is (eq nil (%= "a" ""))))

(test binary-equality-strings-wrapped
  "Test %= with wrapped strings"
  (let ((ws1 (wrap "hello"))
        (ws2 (wrap "hello"))
        (ws3 (wrap "world")))
    (is (eq t (%= ws1 ws2)))
    (is (eq nil (%= ws1 ws3)))
    ;; Mixed wrapped/raw
    (is (eq t (%= ws1 "hello")))
    (is (eq t (%= "hello" ws1)))))

(test binary-equality-symbols-raw
  "Test %= with raw symbols"
  (is (eq t (%= 'foo 'foo)))
  (is (eq nil (%= 'foo 'bar)))
  (is (eq t (%= t t)))
  (is (eq t (%= nil nil)))
  (is (eq nil (%= t nil))))

(test binary-equality-symbols-wrapped
  "Test %= with wrapped symbols"
  (let ((ws1 (wrap 'foo))
        (ws2 (wrap 'foo))
        (ws3 (wrap 'bar)))
    (is (eq t (%= ws1 ws2)))
    (is (eq nil (%= ws1 ws3)))
    ;; Mixed wrapped/raw
    (is (eq t (%= ws1 'foo)))
    (is (eq t (%= 'foo ws1)))))

(test binary-equality-booleans
  "Test %= with booleans (wrapped)"
  (let ((wt (wrap t))
        (wt2 (wrap t))
        (wnil (wrap nil)))
    (is (eq t (%= wt wt2)))
    (is (eq t (%= wnil wnil)))
    (is (eq nil (%= wt wnil)))
    ;; Mixed wrapped/raw
    (is (eq t (%= wt t)))
    (is (eq t (%= t wt)))
    (is (eq t (%= wnil nil)))
    (is (eq nil (%= wt nil)))))

;;; ============================================================================
;;; Binary Primitive Inequality (%/=)
;;; ============================================================================

(test binary-inequality
  "Test %/= operation"
  (is (eq nil (%/= 5 5)))
  (is (eq t (%/= 5 6)))
  (is (eq nil (%/= #\a #\a)))
  (is (eq t (%/= #\a #\b)))
  (is (eq nil (%/= "hello" "hello")))
  (is (eq t (%/= "hello" "world"))))

;;; ============================================================================
;;; Binary Primitive Ordering (%<, %<=, %>, %>=)
;;; ============================================================================

(test binary-less-than-numbers-raw
  "Test %< with raw numbers"
  (is (eq t (%< 1 2)))
  (is (eq nil (%< 2 1)))
  (is (eq nil (%< 2 2)))
  (is (eq t (%< -5 0)))
  (is (eq t (%< 0 5)))
  (is (eq t (%< 1.5 2.5)))
  (is (eq t (%< 1/4 1/2))))

(test binary-less-than-numbers-wrapped
  "Test %< with wrapped numbers"
  (let ((w1 (wrap 1))
        (w2 (wrap 2)))
    (is (eq t (%< w1 w2)))
    (is (eq nil (%< w2 w1)))
    (is (eq t (%< w1 2)))
    (is (eq t (%< 1 w2)))))

(test binary-less-than-characters-raw
  "Test %< with raw characters"
  (is (eq t (%< #\a #\b)))
  (is (eq nil (%< #\b #\a)))
  (is (eq nil (%< #\a #\a)))
  (is (eq t (%< #\A #\a)))  ; uppercase < lowercase in ASCII
  (is (eq t (%< #\0 #\9))))

(test binary-less-than-characters-wrapped
  "Test %< with wrapped characters"
  (let ((wa (wrap #\a))
        (wb (wrap #\b)))
    (is (eq t (%< wa wb)))
    (is (eq nil (%< wb wa)))
    (is (eq t (%< wa #\b)))
    (is (eq t (%< #\a wb)))))

(test binary-less-than-strings-raw
  "Test %< with raw strings"
  (is (eq t (%< "apple" "banana")))
  (is (eq nil (%< "banana" "apple")))
  (is (eq nil (%< "apple" "apple")))
  (is (eq t (%< "" "a")))
  (is (eq t (%< "a" "aa")))
  (is (eq t (%< "Apple" "apple"))))  ; uppercase < lowercase

(test binary-less-than-strings-wrapped
  "Test %< with wrapped strings"
  (let ((ws1 (wrap "apple"))
        (ws2 (wrap "banana")))
    (is (eq t (%< ws1 ws2)))
    (is (eq nil (%< ws2 ws1)))
    (is (eq t (%< ws1 "banana")))
    (is (eq t (%< "apple" ws2)))))

(test binary-less-than-booleans
  "Test %< with booleans (NIL < T)"
  (let ((wt (wrap t))
        (wnil (wrap nil)))
    (is (eq t (%< wnil wt)))
    (is (eq nil (%< wt wnil)))
    (is (eq nil (%< wt wt)))
    (is (eq nil (%< wnil wnil)))))

(test binary-less-equal-numbers
  "Test %<= with numbers"
  (is (eq t (%<= 1 2)))
  (is (eq t (%<= 2 2)))
  (is (eq nil (%<= 3 2)))
  (is (eq t (%<= -5 -5)))
  (is (eq t (%<= 1.0 1.0))))

(test binary-less-equal-wrapped
  "Test %<= with wrapped values"
  (let ((w1 (wrap 1))
        (w2 (wrap 2)))
    (is (eq t (%<= w1 w2)))
    (is (eq t (%<= w1 w1)))
    (is (eq nil (%<= w2 w1)))))

(test binary-greater-than-numbers
  "Test %> with numbers"
  (is (eq t (%> 2 1)))
  (is (eq nil (%> 1 2)))
  (is (eq nil (%> 2 2)))
  (is (eq t (%> 5 -5)))
  (is (eq t (%> 2.5 1.5))))

(test binary-greater-than-wrapped
  "Test %> with wrapped values"
  (let ((w1 (wrap 1))
        (w2 (wrap 2)))
    (is (eq t (%> w2 w1)))
    (is (eq nil (%> w1 w2)))
    (is (eq t (%> w2 1)))
    (is (eq t (%> 2 w1)))))

(test binary-greater-equal-numbers
  "Test %>= with numbers"
  (is (eq t (%>= 2 1)))
  (is (eq t (%>= 2 2)))
  (is (eq nil (%>= 1 2)))
  (is (eq t (%>= 0 0))))

(test binary-greater-equal-wrapped
  "Test %>= with wrapped values"
  (let ((w1 (wrap 1))
        (w2 (wrap 2)))
    (is (eq t (%>= w2 w1)))
    (is (eq t (%>= w2 w2)))
    (is (eq nil (%>= w1 w2)))))

;;; ============================================================================
;;; Variadic Equality (=)
;;; ============================================================================

(test variadic-equality-zero-one-arg
  "Test = with zero or one argument"
  (is (eq t (=)))
  (is (eq t (= 5)))
  (is (eq t (= (wrap 5)))))

(test variadic-equality-two-args
  "Test = with two arguments"
  (is (eq t (= 5 5)))
  (is (eq nil (= 5 6)))
  (is (eq t (= #\a #\a)))
  (is (eq nil (= #\a #\b)))
  (is (eq t (= "hello" "hello")))
  (is (eq nil (= "hello" "world"))))

(test variadic-equality-multiple-args
  "Test = with multiple arguments"
  (is (eq t (= 1 1 1 1)))
  (is (eq nil (= 1 1 2 1)))
  (is (eq nil (= 1 2 1 1)))
  (is (eq t (= #\a #\a #\a)))
  (is (eq nil (= #\a #\a #\b)))
  (is (eq t (= "x" "x" "x" "x")))
  (is (eq nil (= "x" "x" "y"))))

(test variadic-equality-mixed
  "Test = with mixed wrapped/raw values"
  (is (eq t (= 5 (wrap 5) 5)))
  (is (eq t (= (wrap #\a) #\a (wrap #\a)))))

;;; ============================================================================
;;; Variadic Inequality (/=)
;;; ============================================================================

(test variadic-inequality-zero-one-arg
  "Test /= with zero or one argument"
  (is (eq t (/=)))
  (is (eq t (/= 5))))

(test variadic-inequality-two-args
  "Test /= with two arguments (all different)"
  (is (eq t (/= 1 2)))
  (is (eq nil (/= 1 1)))
  (is (eq t (/= #\a #\b)))
  (is (eq nil (/= #\a #\a))))

(test variadic-inequality-multiple-args
  "Test /= with multiple arguments (all pairwise different)"
  (is (eq t (/= 1 2 3 4)))
  (is (eq nil (/= 1 2 1)))  ; 1 appears twice
  (is (eq nil (/= 1 2 3 2)))  ; 2 appears twice
  (is (eq t (/= #\a #\b #\c)))
  (is (eq nil (/= #\a #\b #\a))))

;;; ============================================================================
;;; Variadic Ordering (<, <=, >, >=)
;;; ============================================================================

(test variadic-less-than-zero-one-arg
  "Test < with zero or one argument"
  (is (eq t (<)))
  (is (eq t (< 5))))

(test variadic-less-than-two-args
  "Test < with two arguments (strictly increasing)"
  (is (eq t (< 1 2)))
  (is (eq nil (< 2 1)))
  (is (eq nil (< 2 2))))

(test variadic-less-than-multiple-args
  "Test < with multiple arguments (strictly increasing chain)"
  (is (eq t (< 1 2 3 4 5)))
  (is (eq nil (< 1 2 2 3)))  ; not strictly increasing (2 = 2)
  (is (eq nil (< 1 3 2 4)))  ; not increasing (3 > 2)
  (is (eq t (< #\a #\b #\c)))
  (is (eq nil (< #\a #\c #\b))))

(test variadic-less-equal-zero-one-arg
  "Test <= with zero or one argument"
  (is (eq t (<=)))
  (is (eq t (<= 5))))

(test variadic-less-equal-two-args
  "Test <= with two arguments (non-decreasing)"
  (is (eq t (<= 1 2)))
  (is (eq t (<= 2 2)))
  (is (eq nil (<= 3 2))))

(test variadic-less-equal-multiple-args
  "Test <= with multiple arguments (non-decreasing chain)"
  (is (eq t (<= 1 2 2 3 4)))
  (is (eq t (<= 1 1 1 1)))
  (is (eq nil (<= 1 2 3 2)))  ; 3 > 2
  (is (eq t (<= #\a #\a #\b #\c)))
  (is (eq nil (<= #\a #\c #\b))))

(test variadic-greater-than-zero-one-arg
  "Test > with zero or one argument"
  (is (eq t (>)))
  (is (eq t (> 5))))

(test variadic-greater-than-two-args
  "Test > with two arguments (strictly decreasing)"
  (is (eq t (> 2 1)))
  (is (eq nil (> 1 2)))
  (is (eq nil (> 2 2))))

(test variadic-greater-than-multiple-args
  "Test > with multiple arguments (strictly decreasing chain)"
  (is (eq t (> 5 4 3 2 1)))
  (is (eq nil (> 5 4 4 3)))  ; not strictly decreasing
  (is (eq nil (> 5 3 4 2)))  ; not decreasing (3 < 4)
  (is (eq t (> #\c #\b #\a)))
  (is (eq nil (> #\c #\a #\b))))

(test variadic-greater-equal-zero-one-arg
  "Test >= with zero or one argument"
  (is (eq t (>=)))
  (is (eq t (>= 5))))

(test variadic-greater-equal-two-args
  "Test >= with two arguments (non-increasing)"
  (is (eq t (>= 2 1)))
  (is (eq t (>= 2 2)))
  (is (eq nil (>= 1 2))))

(test variadic-greater-equal-multiple-args
  "Test >= with multiple arguments (non-increasing chain)"
  (is (eq t (>= 5 4 4 3 2)))
  (is (eq t (>= 5 5 5 5)))
  (is (eq nil (>= 5 4 5 3)))  ; 4 < 5
  (is (eq t (>= #\c #\c #\b #\a)))
  (is (eq nil (>= #\c #\a #\b))))

;;; ============================================================================
;;; Min and Max Functions
;;; ============================================================================

(test min-single-arg
  "Test min with single argument"
  (is (cl:= 5 (min 5)))
  (is (cl:= -10 (min -10)))
  (is (eql #\a (min #\a)))
  (is (equal "hello" (min "hello"))))

(test min-two-args
  "Test min with two arguments"
  (is (cl:= 1 (min 1 2)))
  (is (cl:= 1 (min 2 1)))
  (is (cl:= -5 (min -5 5)))
  (is (eql #\a (min #\a #\b)))
  (is (eql #\a (min #\b #\a)))
  (is (equal "apple" (min "apple" "banana"))))

(test min-multiple-args
  "Test min with multiple arguments"
  (is (cl:= 1 (min 5 3 1 4 2)))
  (is (cl:= -10 (min 0 -5 -10 5 10)))
  (is (eql #\a (min #\c #\a #\b)))
  (is (equal "aaa" (min "bbb" "aaa" "ccc"))))

(test min-wrapped
  "Test min with wrapped values"
  (is (cl:= 1 (min (wrap 1) (wrap 2))))
  (is (cl:= 1 (min (wrap 2) 1)))
  (is (cl:= 1 (min 2 (wrap 1)))))

(test min-equal-values
  "Test min when values are equal"
  (is (cl:= 5 (min 5 5)))
  (is (cl:= 5 (min 5 5 5 5))))

(test max-single-arg
  "Test max with single argument"
  (is (cl:= 5 (max 5)))
  (is (cl:= -10 (max -10)))
  (is (eql #\z (max #\z)))
  (is (equal "world" (max "world"))))

(test max-two-args
  "Test max with two arguments"
  (is (cl:= 2 (max 1 2)))
  (is (cl:= 2 (max 2 1)))
  (is (cl:= 5 (max -5 5)))
  (is (eql #\b (max #\a #\b)))
  (is (eql #\b (max #\b #\a)))
  (is (equal "banana" (max "apple" "banana"))))

(test max-multiple-args
  "Test max with multiple arguments"
  (is (cl:= 5 (max 1 3 5 2 4)))
  (is (cl:= 10 (max 0 -5 -10 5 10)))
  (is (eql #\c (max #\a #\c #\b)))
  (is (equal "ccc" (max "bbb" "aaa" "ccc"))))

(test max-wrapped
  "Test max with wrapped values"
  (is (cl:= 2 (max (wrap 1) (wrap 2))))
  (is (cl:= 2 (max (wrap 1) 2)))
  (is (cl:= 2 (max 1 (wrap 2)))))

(test max-equal-values
  "Test max when values are equal"
  (is (cl:= 5 (max 5 5)))
  (is (cl:= 5 (max 5 5 5 5))))

(test min-max-booleans
  "Test min and max with booleans (NIL < T)"
  (is (eq nil (min nil t)))
  (is (eq nil (min t nil)))
  (is (eq t (max nil t)))
  (is (eq t (max t nil))))

;;; ============================================================================
;;; Edge Cases
;;; ============================================================================

(test comparison-with-zero
  "Test comparisons with zero"
  (is (eq t (%= 0 0)))
  (is (eq t (%= 0.0 0)))
  (is (eq t (%< -1 0)))
  (is (eq t (%< 0 1)))
  (is (eq t (%> 1 0)))
  (is (eq t (%> 0 -1)))
  (is (eq t (%<= 0 0)))
  (is (eq t (%>= 0 0))))

(test comparison-with-negative-numbers
  "Test comparisons with negative numbers"
  (is (eq t (%< -2 -1)))
  (is (eq t (%< -100 0)))
  (is (eq t (%> -1 -2)))
  (is (eq t (%<= -5 -5)))
  (is (eq t (%>= -5 -5))))

(test comparison-with-floats-precision
  "Test comparison with floating point precision"
  (is (eq t (%= 0.1 0.1)))
  (is (eq nil (%= 0.1 0.10000001)))
  ;; Be careful with float comparison
  (is (eq t (%< 0.1 0.2)))
  (is (eq t (%<= 1.0 1.0))))

(test comparison-empty-strings
  "Test comparison with empty strings"
  (is (eq t (%= "" "")))
  (is (eq t (%< "" "a")))
  (is (eq nil (%< "a" "")))
  (is (eq t (%<= "" "")))
  (is (eq t (%<= "" "a"))))

(test comparison-with-bignums
  "Test comparisons with very large numbers"
  (let ((big1 (cl:expt 10 100))
        (big2 (cl:expt 10 100))
        (big3 (cl:expt 10 101)))
    (is (eq t (%= big1 big2)))
    (is (eq t (%< big1 big3)))
    (is (eq t (%> big3 big1)))))

(test comparison-special-characters
  "Test comparison with special characters"
  (is (eq t (%= #\Space #\Space)))
  (is (eq t (%= #\Newline #\Newline)))
  (is (eq t (%= #\Tab #\Tab)))
  (is (eq t (%< #\Space #\!)))  ; space is before ! in ASCII
  (is (eq t (%< #\0 #\A)))      ; digits before uppercase letters
  (is (eq t (%< #\A #\a))))     ; uppercase before lowercase

(test comparison-unicode-strings
  "Test comparison with unicode strings"
  (is (eq t (%= "café" "café")))
  (is (eq nil (%= "cafe" "café")))
  (is (eq t (%= "日本語" "日本語")))
  (is (eq nil (%= "日本語" "中文"))))

;;; ============================================================================
;;; Cross-type comparisons
;;; ============================================================================

(test cross-type-numeric
  "Test cross-type numeric comparisons"
  ;; Integer vs Float
  (is (eq t (%= 2 2.0)))
  (is (eq t (%< 1 2.0)))
  (is (eq t (%> 3.0 2)))
  ;; Integer vs Ratio
  (is (eq t (%= 2 4/2)))
  (is (eq t (%< 1 3/2)))
  (is (eq t (%> 2 3/2)))
  ;; Float vs Ratio
  (is (eq t (%= 0.5 1/2)))
  (is (eq t (%< 0.25 1/2))))

;;; ============================================================================
;;; Error Cases
;;; ============================================================================

(test comparison-incompatible-types
  "Test that comparison of incompatible types behaves correctly"
  ;; These should not error but return nil for equality of different types
  (is (eq nil (%= 5 "5")))
  (is (eq nil (%= #\5 5)))
  (is (eq nil (%= 'five 5))))
