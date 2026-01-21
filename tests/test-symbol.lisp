(in-package :fol.tests)

;;; ============================================================================
;;; Symbol Tests - Comprehensive test suite for FOL symbol operations
;;; ============================================================================

(def-suite* :fol.symbol-tests)

;;; ---------------------------------------------------------------------------
;;; Symbol Type Predicate Tests
;;; ---------------------------------------------------------------------------

(test symbol-predicate-raw
  "Test <symbol>? predicate with raw symbols."
  (is-true (<symbol>? 'foo))
  (is-true (<symbol>? 'bar))
  (is-true (<symbol>? 'my-symbol))
  (is-true (<symbol>? :keyword))  ; keywords are symbols
  (is-true (<symbol>? t))          ; t is a symbol
  (is-true (<symbol>? nil)))       ; nil is a symbol

(test symbol-predicate-wrapped
  "Test <symbol>? predicate with wrapped symbols."
  (is-true (<symbol>? (wrap-symbol 'foo)))
  (is-true (<symbol>? (wrap-symbol 'bar)))
  (is-true (<symbol>? (wrap-symbol :keyword))))

(test symbol-predicate-non-symbols
  "Test <symbol>? predicate returns NIL for non-symbols."
  (is-false (<symbol>? "foo"))
  (is-false (<symbol>? 123))
  (is-false (<symbol>? 3.14))
  (is-false (<symbol>? #\a))
  (is-false (<symbol>? '(a b c))))

;;; ---------------------------------------------------------------------------
;;; Keyword Type Predicate Tests
;;; ---------------------------------------------------------------------------

(test keyword-predicate-raw
  "Test <keyword>? predicate with raw keywords."
  (is-true (<keyword>? :foo))
  (is-true (<keyword>? :bar))
  (is-true (<keyword>? :my-keyword)))

(test keyword-predicate-wrapped
  "Test <keyword>? predicate with wrapped keywords."
  (is-true (<keyword>? (wrap-symbol :foo)))
  (is-true (<keyword>? (wrap-symbol :bar))))

(test keyword-predicate-non-keywords
  "Test <keyword>? predicate returns NIL for non-keywords."
  (is-false (<keyword>? 'foo))
  (is-false (<keyword>? (wrap-symbol 'foo)))
  (is-false (<keyword>? "foo"))
  (is-false (<keyword>? 123))
  (is-false (<keyword>? t))
  (is-false (<keyword>? nil)))

;;; ---------------------------------------------------------------------------
;;; Symbol Wrapping/Unwrapping Tests
;;; ---------------------------------------------------------------------------

(test symbol-wrap-basic
  "Test wrapping of basic symbols."
  (let ((wrapped (wrap-symbol 'foo)))
    (is (typep wrapped '<symbol>))
    (is (eq 'foo (fol-value wrapped)))
    (is (eq 'foo (unwrap-symbol wrapped)))))

(test symbol-wrap-keyword
  "Test wrapping of keywords."
  (let ((wrapped (wrap-symbol :bar)))
    (is (typep wrapped '<keyword>))
    (is (eq :bar (fol-value wrapped)))
    (is (eq :bar (unwrap-symbol wrapped)))))

(test symbol-wrap-roundtrip
  "Test that wrap/unwrap is identity for symbols."
  (is (eq 'test (unwrap-symbol (wrap-symbol 'test))))
  (is (eq :key (unwrap-symbol (wrap-symbol :key))))
  (is (eq 'my-sym (unwrap-symbol (wrap-symbol 'my-sym)))))

(test symbol-fol-value-raw
  "Test fol-value on raw symbols (pass-through)."
  (is (eq 'foo (fol-value 'foo)))
  (is (eq :bar (fol-value :bar)))
  (is (eq t (fol-value t)))
  (is (eq nil (fol-value nil))))

(test symbol-fol-type-of
  "Test fol-type-of for symbols."
  (is (eq '<symbol> (fol-type-of 'foo)))
  (is (eq '<keyword> (fol-type-of :bar)))
  (is (eq '<symbol> (fol-type-of (wrap-symbol 'test))))
  (is (eq '<keyword> (fol-type-of (wrap-symbol :key)))))

;;; ---------------------------------------------------------------------------
;;; Symbol Equality Tests
;;; ---------------------------------------------------------------------------

(test symbol-equality-raw-raw
  "Test equality between raw symbols."
  (is-true (%= 'foo 'foo))
  (is-true (%= :bar :bar))
  (is-false (%= 'foo 'bar))
  (is-false (%= 'foo :foo))  ; symbol vs keyword
  (is-false (%= :foo :bar)))

(test symbol-equality-wrapped-wrapped
  "Test equality between wrapped symbols."
  (let ((s1 (wrap-symbol 'foo))
        (s2 (wrap-symbol 'foo))
        (s3 (wrap-symbol 'bar)))
    (is-true (%= s1 s2))
    (is-false (%= s1 s3))))

(test symbol-equality-mixed
  "Test equality between raw and wrapped symbols."
  (let ((wrapped (wrap-symbol 'foo)))
    (is-true (%= wrapped 'foo))
    (is-true (%= 'foo wrapped))
    (is-false (%= wrapped 'bar))
    (is-false (%= 'bar wrapped))))

(test keyword-equality
  "Test equality for keywords."
  (let ((k1 (wrap-symbol :test))
        (k2 (wrap-symbol :test))
        (k3 (wrap-symbol :other)))
    (is-true (%= k1 k2))
    (is-true (%= k1 :test))
    (is-false (%= k1 k3))))

(test symbol-inequality
  "Test inequality for symbols."
  (is-true (%/= 'foo 'bar))
  (is-true (%/= :foo :bar))
  (is-true (%/= 'foo :foo))
  (is-false (%/= 'foo 'foo))
  (let ((s1 (wrap-symbol 'a))
        (s2 (wrap-symbol 'b)))
    (is-true (%/= s1 s2))
    (is-false (%/= s1 'a))))

;;; ---------------------------------------------------------------------------
;;; Symbol Name Operations
;;; ---------------------------------------------------------------------------

(test symbol-name-str-raw
  "Test symbol-name-str with raw symbols."
  (is (string= "FOO" (symbol-name-str 'foo)))
  (is (string= "BAR" (symbol-name-str :bar)))
  (is (string= "MY-SYMBOL" (symbol-name-str 'my-symbol))))

(test symbol-name-str-wrapped
  "Test symbol-name-str with wrapped symbols."
  (is (string= "FOO" (symbol-name-str (wrap-symbol 'foo))))
  (is (string= "BAR" (symbol-name-str (wrap-symbol :bar)))))

;;; ---------------------------------------------------------------------------
;;; Symbol Package Operations
;;; ---------------------------------------------------------------------------

(test symbol-package-str-raw
  "Test symbol-package-str with raw symbols."
  (is (stringp (symbol-package-str 'foo)))
  (is (string= "KEYWORD" (symbol-package-str :bar))))

(test symbol-package-str-wrapped
  "Test symbol-package-str with wrapped symbols."
  (is (stringp (symbol-package-str (wrap-symbol 'foo))))
  (is (string= "KEYWORD" (symbol-package-str (wrap-symbol :bar)))))

;;; ---------------------------------------------------------------------------
;;; Type Conversion Tests (as function)
;;; ---------------------------------------------------------------------------

(test symbol-as-string-to-symbol
  "Test converting string to symbol using as."
  (let ((result (as '<symbol> "foo")))
    (is (typep result '<symbol>))
    (is (eq 'foo (fol-value result)))))

(test symbol-as-string-to-symbol-wrapped
  "Test converting wrapped string to symbol using as."
  (let* ((str (wrap-string "test"))
         (result (as '<symbol> str)))
    (is (typep result '<symbol>))
    (is (eq 'test (fol-value result)))))

(test symbol-as-string-to-keyword-auto
  "Test auto-detection of keyword from string starting with colon."
  (let ((result (as '<symbol> ":foo")))
    (is (typep result '<keyword>))
    (is (eq :foo (fol-value result)))))

(test symbol-as-string-to-keyword-explicit
  "Test explicit keyword creation using as."
  (let ((result (as '<keyword> "foo")))
    (is (typep result '<keyword>))
    (is (eq :foo (fol-value result)))))

(test symbol-as-keyword-with-colon
  "Test keyword creation strips leading colon."
  (let ((result (as '<keyword> ":bar")))
    (is (eq :bar (fol-value result)))))

(test symbol-as-symbol-to-string
  "Test converting symbol to string using as."
  (let ((result (as '<string> (wrap-symbol 'foo))))
    (is (typep result '<string>))
    (is (string= "foo" (fol-value result)))))

(test symbol-as-raw-symbol-to-string
  "Test converting raw symbol to string using as."
  (let ((result (as '<string> 'bar)))
    (is (typep result '<string>))
    (is (string= "bar" (fol-value result)))))

(test symbol-as-keyword-to-string
  "Test converting keyword to string using as."
  (let ((result (as '<string> (wrap-symbol :baz))))
    (is (typep result '<string>))
    (is (string= "baz" (fol-value result)))))

(test symbol-as-case-insensitive
  "Test that string to symbol conversion is case-insensitive."
  (let ((upper (as '<symbol> "FOO"))
        (lower (as '<symbol> "foo"))
        (mixed (as '<symbol> "FoO")))
    (is (eq (fol-value upper) (fol-value lower)))
    (is (eq (fol-value lower) (fol-value mixed)))))

;;; ---------------------------------------------------------------------------
;;; Symbol Value Operations (persistent storage)
;;; ---------------------------------------------------------------------------

(test symbol-value-unbound
  "Test that new wrapped symbols are unbound."
  (let ((sym (wrap-symbol 'unbound-test)))
    (is-false (symbol-bound? sym))))

(test symbol-value-set-and-get
  "Test setting and getting symbol value."
  (let* ((sym (wrap-symbol 'value-test))
         (sym2 (set-symbol-value sym 42)))
    (is-true (symbol-bound? sym2))
    (is (= 42 (get-symbol-value sym2)))))

(test symbol-value-immutability
  "Test that set-symbol-value returns a new symbol, leaving original unchanged."
  (let* ((sym1 (wrap-symbol 'immutable-test))
         (sym2 (set-symbol-value sym1 100)))
    ;; Original should still be unbound
    (is-false (symbol-bound? sym1))
    ;; New symbol should be bound
    (is-true (symbol-bound? sym2))
    (is (= 100 (get-symbol-value sym2)))))

(test symbol-value-various-types
  "Test symbol values can hold various types."
  (let ((sym (wrap-symbol 'various-values)))
    ;; Number
    (let ((sym-num (set-symbol-value sym 42)))
      (is (= 42 (get-symbol-value sym-num))))
    ;; String
    (let ((sym-str (set-symbol-value sym "hello")))
      (is (string= "hello" (get-symbol-value sym-str))))
    ;; List
    (let ((sym-list (set-symbol-value sym '(1 2 3))))
      (is (equal '(1 2 3) (get-symbol-value sym-list))))
    ;; Symbol
    (let ((sym-sym (set-symbol-value sym 'other)))
      (is (eq 'other (get-symbol-value sym-sym))))))

(test symbol-value-update
  "Test updating a symbol's value."
  (let* ((sym1 (wrap-symbol 'update-test))
         (sym2 (set-symbol-value sym1 10))
         (sym3 (set-symbol-value sym2 20)))
    (is (= 10 (get-symbol-value sym2)))
    (is (= 20 (get-symbol-value sym3)))))

;;; ---------------------------------------------------------------------------
;;; Edge Cases and Special Symbols
;;; ---------------------------------------------------------------------------

(test symbol-special-names
  "Test symbols with special names."
  (let ((plus (wrap-symbol '+))
        (minus (wrap-symbol '-))
        (star (wrap-symbol '*)))
    (is (eq '+ (fol-value plus)))
    (is (eq '- (fol-value minus)))
    (is (eq '* (fol-value star)))))

(test symbol-hyphenated-names
  "Test symbols with hyphenated names."
  (let ((sym (wrap-symbol 'my-long-symbol-name)))
    (is (eq 'my-long-symbol-name (fol-value sym)))
    (is (string= "MY-LONG-SYMBOL-NAME" (symbol-name-str sym)))))

(test symbol-with-numbers
  "Test symbols containing numbers."
  (let ((sym (wrap-symbol 'test123)))
    (is (eq 'test123 (fol-value sym))))
  (let ((sym (wrap-symbol '123test)))
    (is (eq '|123TEST| (fol-value sym)))))

(test keyword-special-names
  "Test keywords with special characters."
  (let ((k1 (wrap-symbol :test-keyword))
        (k2 (wrap-symbol :another_keyword)))
    (is (eq :test-keyword (fol-value k1)))
    (is (eq :another_keyword (fol-value k2)))))

;;; ---------------------------------------------------------------------------
;;; Variadic Symbol Comparisons
;;; ---------------------------------------------------------------------------

(test symbol-variadic-equality
  "Test variadic equality with symbols."
  (is-true (= 'a 'a 'a))
  (is-false (= 'a 'a 'b))
  (let ((s1 (wrap-symbol 'test))
        (s2 (wrap-symbol 'test)))
    (is-true (= s1 'test s2))))

(test keyword-variadic-equality
  "Test variadic equality with keywords."
  (is-true (= :x :x :x))
  (is-false (= :x :x :y))
  (let ((k1 (wrap-symbol :key))
        (k2 (wrap-symbol :key)))
    (is-true (= k1 :key k2))))

;;; ---------------------------------------------------------------------------
;;; Symbol/Keyword Distinction Tests
;;; ---------------------------------------------------------------------------

(test symbol-keyword-distinction
  "Test that symbols and keywords are properly distinguished."
  (let ((sym (wrap-symbol 'foo))
        (kw (wrap-symbol :foo)))
    ;; Different types
    (is (typep sym '<symbol>))
    (is (typep kw '<keyword>))
    ;; Keyword is also a symbol
    (is-true (<symbol>? kw))
    ;; Symbol is not a keyword
    (is-false (<keyword>? sym))
    ;; Not equal to each other
    (is-false (%= sym kw))))

(test nil-and-t-handling
  "Test that NIL and T are handled as symbols."
  (is-true (<symbol>? nil))
  (is-true (<symbol>? t))
  (is-false (<keyword>? nil))
  (is-false (<keyword>? t)))
