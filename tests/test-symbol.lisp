(in-package :fol.tests)

;;; ============================================================================
;;; Symbol Tests - Comprehensive test suite for FOL symbol operations
;;; ============================================================================

(def-suite symbol-suite :in fol-suite)
(def-suite* :fol.symbol-tests :in symbol-suite)

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

;;; ---------------------------------------------------------------------------
;;; Symbol Interning Tests (fol-intern)
;;; ---------------------------------------------------------------------------

(test parse-qualified-name-simple
  "Test parsing simple unqualified names."
  (multiple-value-bind (mod sym) (parse-qualified-name "foo")
    (is (null mod))
    (is (string= "foo" sym))))

(test parse-qualified-name-keyword
  "Test parsing keyword names starting with colon."
  (multiple-value-bind (mod sym) (parse-qualified-name ":bar")
    (is (string= +keyword-module+ mod))
    (is (string= "bar" sym))))

(test parse-qualified-name-clojure-style
  "Test parsing Clojure-style module-qualified names (module/symbol)."
  (multiple-value-bind (mod sym) (parse-qualified-name "mymod/baz")
    (is (string= "mymod" mod))
    (is (string= "baz" sym))))

(test parse-qualified-name-cl-style
  "Test parsing CL-style module-qualified names (module::symbol)."
  (multiple-value-bind (mod sym) (parse-qualified-name "other::qux")
    (is (string= "other" mod))
    (is (string= "qux" sym))))

(test parse-qualified-name-empty
  "Test parsing empty string."
  (multiple-value-bind (mod sym) (parse-qualified-name "")
    (is (null mod))
    (is (string= "" sym))))

(test fol-intern-keyword
  "Test interning keywords (names starting with colon)."
  (let ((sym (fol-intern ":foo")))
    (is-true (<keyword>? sym))
    (is (eq :FOO (fol-value sym)))
    (is (string= +keyword-module+ (fol.classes:symbol-module-name sym)))))

(test fol-intern-simple-default-module
  "Test interning unqualified symbols uses default module."
  (let ((sym (fol-intern "bar")))
    (is-true (<symbol>? sym))
    (is-false (<keyword>? sym))
    (is (string= "BAR" (symbol-name (fol-value sym))))
    (is (string= +default-module+ (fol.classes:symbol-module-name sym)))))

(test fol-intern-with-explicit-module
  "Test interning with explicit module name."
  (let ((sym (fol-intern "baz" "mymodule")))
    (is-true (<symbol>? sym))
    (is (string= "BAZ" (symbol-name (fol-value sym))))
    (is (string= "mymodule" (fol.classes:symbol-module-name sym)))))

(test fol-intern-clojure-qualified
  "Test interning Clojure-style qualified names."
  (let ((sym (fol-intern "somemod/func")))
    (is-true (<symbol>? sym))
    (is (string= "FUNC" (symbol-name (fol-value sym))))
    (is (string= "somemod" (fol.classes:symbol-module-name sym)))))

(test fol-intern-cl-qualified
  "Test interning CL-style qualified names."
  (let ((sym (fol-intern "othermod::var")))
    (is-true (<symbol>? sym))
    (is (string= "VAR" (symbol-name (fol-value sym))))
    (is (string= "othermod" (fol.classes:symbol-module-name sym)))))

(test fol-intern-keyword-ignores-module
  "Test that keywords always go to %keyword module regardless of explicit module."
  (let ((sym (fol-intern ":keyword" "ignored-module")))
    (is-true (<keyword>? sym))
    (is (string= +keyword-module+ (fol.classes:symbol-module-name sym)))))

(test fol-intern-current-module
  "Test that *current-module* is used when set."
  (let ((*current-module* "current-test-module"))
    (let ((sym (fol-intern "myvar")))
      (is (string= "current-test-module" (fol.classes:symbol-module-name sym))))))

(test fol-intern-explicit-overrides-current
  "Test that explicit module overrides *current-module*."
  (let ((*current-module* "current-mod"))
    (let ((sym (fol-intern "myvar" "explicit-mod")))
      (is (string= "explicit-mod" (fol.classes:symbol-module-name sym))))))

(test fol-intern-qualified-overrides-all
  "Test that qualified names override both explicit and current module."
  (let ((*current-module* "current-mod"))
    (let ((sym (fol-intern "qualified/name" "explicit-mod")))
      (is (string= "qualified" (fol.classes:symbol-module-name sym))))))

(test fol-intern-case-insensitive
  "Test that symbol names are uppercased."
  (let ((lower (fol-intern "lowercase"))
        (upper (fol-intern "UPPERCASE"))
        (mixed (fol-intern "MixedCase")))
    (is (string= "LOWERCASE" (symbol-name (fol-value lower))))
    (is (string= "UPPERCASE" (symbol-name (fol-value upper))))
    (is (string= "MIXEDCASE" (symbol-name (fol-value mixed))))))

;;; ---------------------------------------------------------------------------
;;; Keyword Constructor Function Tests
;;; ---------------------------------------------------------------------------

(test keyword-from-string
  "Test creating keyword from string."
  (is (eq :foo (keyword "foo")))
  (is (eq :bar (keyword "bar")))
  (is (eq :hello-world (keyword "hello-world"))))

(test keyword-from-string-case-insensitive
  "Test that keyword is case-insensitive."
  (is (eq :foo (keyword "FOO")))
  (is (eq :foo (keyword "foo")))
  (is (eq :foo (keyword "Foo"))))

(test keyword-from-string-with-colon
  "Test that leading colon is stripped from string."
  (is (eq :bar (keyword ":bar")))
  (is (eq :baz (keyword ":baz"))))

(test keyword-from-wrapped-string
  "Test creating keyword from FOL <string>."
  (is (eq :test (keyword (wrap-string "test"))))
  (is (eq :xyz (keyword (wrap-string "xyz")))))

(test keyword-from-symbol
  "Test creating keyword from symbol."
  (is (eq :foo (keyword 'foo)))
  (is (eq :bar (keyword 'bar))))

(test keyword-from-keyword
  "Test that keyword returns keyword unchanged."
  (is (eq :foo (keyword :foo)))
  (is (eq :bar (keyword :bar))))

(test keyword-from-wrapped-symbol
  "Test creating keyword from wrapped FOL <symbol>."
  (is (eq :test (keyword (wrap-symbol 'test))))
  (is (eq :abc (keyword (wrap-symbol 'abc)))))

(test keyword-from-wrapped-keyword
  "Test creating keyword from wrapped FOL <keyword>."
  (is (eq :baz (keyword (wrap-symbol :baz)))))

;;; ---------------------------------------------------------------------------
;;; Find-Keyword Function Tests
;;; ---------------------------------------------------------------------------

(test find-keyword-existing
  "Test finding existing keywords."
  ;; :test should exist since we just used it
  (keyword "test-find-keyword-marker")  ; Create it first
  (is (eq :test-find-keyword-marker (find-keyword "test-find-keyword-marker")))
  (is (eq :test-find-keyword-marker (find-keyword "TEST-FIND-KEYWORD-MARKER")))
  (is (eq :test-find-keyword-marker (find-keyword ":test-find-keyword-marker"))))

(test find-keyword-not-found
  "Test that find-keyword returns nil for non-existent keywords."
  ;; Use a very unlikely name that shouldn't exist
  (is (null (find-keyword "this-keyword-should-definitely-not-exist-xyz123"))))

(test find-keyword-from-symbol
  "Test finding keyword from symbol."
  (keyword "find-keyword-symbol-test")  ; Create it first
  (is (eq :find-keyword-symbol-test (find-keyword 'find-keyword-symbol-test))))

(test find-keyword-from-keyword
  "Test that find-keyword returns keyword unchanged."
  (is (eq :foo (find-keyword :foo)))
  (is (eq :bar (find-keyword :bar))))

(test find-keyword-from-wrapped-string
  "Test finding keyword from FOL <string>."
  (keyword "find-keyword-wrapped-test")  ; Create it first
  (is (eq :find-keyword-wrapped-test (find-keyword (wrap-string "find-keyword-wrapped-test")))))

(test find-keyword-from-wrapped-symbol
  "Test finding keyword from wrapped FOL <symbol>."
  (keyword "find-keyword-wrapped-sym")  ; Create it first
  (is (eq :find-keyword-wrapped-sym (find-keyword (wrap-symbol 'find-keyword-wrapped-sym)))))

(test find-keyword-case-insensitive
  "Test that find-keyword is case-insensitive."
  (keyword "case-test-keyword")  ; Create it first
  (is (eq :case-test-keyword (find-keyword "case-test-keyword")))
  (is (eq :case-test-keyword (find-keyword "CASE-TEST-KEYWORD")))
  (is (eq :case-test-keyword (find-keyword "Case-Test-Keyword"))))

;;; ---------------------------------------------------------------------------
;;; Symbol Constructor Function Tests
;;; ---------------------------------------------------------------------------

(test symbol-from-string
  "Test creating symbol from string in default module."
  (let ((sym (symbol "test-sym")))
    (is-true (<symbol>? sym))
    (is (string= "TEST-SYM" (cl:symbol-name (fol-value sym))))
    (is (string= +default-module+ (fol.classes:symbol-module-name sym)))))

(test symbol-from-string-current-module
  "Test creating symbol uses *current-module*."
  (let ((*current-module* "my-test-module"))
    (let ((sym (symbol "my-var")))
      (is-true (<symbol>? sym))
      (is (string= "MY-VAR" (cl:symbol-name (fol-value sym))))
      (is (string= "my-test-module" (fol.classes:symbol-module-name sym))))))

(test symbol-with-module-arg
  "Test creating symbol in specific module."
  (let ((sym (symbol "custom-module" "my-symbol")))
    (is-true (<symbol>? sym))
    (is (string= "MY-SYMBOL" (cl:symbol-name (fol-value sym))))
    (is (string= "custom-module" (fol.classes:symbol-module-name sym)))))

(test symbol-from-wrapped-string
  "Test creating symbol from FOL <string>."
  (let ((sym (symbol (wrap-string "wrapped-name"))))
    (is-true (<symbol>? sym))
    (is (string= "WRAPPED-NAME" (cl:symbol-name (fol-value sym))))))

(test symbol-from-symbol-name
  "Test creating symbol from symbol name."
  (let ((sym (symbol 'source-sym)))
    (is-true (<symbol>? sym))
    (is (string= "SOURCE-SYM" (cl:symbol-name (fol-value sym))))))

(test symbol-with-module-from-symbol
  "Test creating symbol with module from symbol."
  (let ((sym (symbol 'mod-name 'sym-name)))
    (is-true (<symbol>? sym))
    (is (string= "SYM-NAME" (cl:symbol-name (fol-value sym))))
    (is (string= "MOD-NAME" (fol.classes:symbol-module-name sym)))))

(test symbol-case-insensitive
  "Test that symbol name is uppercased."
  (let ((lower (symbol "lowercase"))
        (upper (symbol "UPPERCASE"))
        (mixed (symbol "MixedCase")))
    (is (string= "LOWERCASE" (cl:symbol-name (fol-value lower))))
    (is (string= "UPPERCASE" (cl:symbol-name (fol-value upper))))
    (is (string= "MIXEDCASE" (cl:symbol-name (fol-value mixed))))))

;;; ============================================================================
;;; Gensym Tests
;;; ============================================================================

(test gensym-no-args
  "Test gensym with no arguments creates G__### in current module."
  (let ((sym (gensym)))
    (is-true (<symbol>? sym))
    (is-true (cl:search "G__" (cl:symbol-name (fol-value sym))))
    (is (string= +default-module+ (fol.classes:symbol-module-name sym)))))

(test gensym-unique-names
  "Test that successive gensyms produce unique names."
  (let ((sym1 (gensym))
        (sym2 (gensym)))
    (is (not (string= (cl:symbol-name (fol-value sym1))
                      (cl:symbol-name (fol-value sym2)))))))

(test gensym-with-prefix
  "Test gensym with prefix creates PREFIX__### in current module."
  (let ((sym (gensym "foo")))
    (is-true (<symbol>? sym))
    (is-true (cl:search "FOO__" (cl:symbol-name (fol-value sym))))
    (is (string= +default-module+ (fol.classes:symbol-module-name sym)))))

(test gensym-with-prefix-and-module
  "Test gensym with prefix and module creates MODULE__### in prefix's module."
  (let ((sym (gensym "my-module" "bar")))
    (is-true (<symbol>? sym))
    (is-true (cl:search "BAR__" (cl:symbol-name (fol-value sym))))
    (is (string= "my-module" (fol.classes:symbol-module-name sym)))))

(test gensym-nil-prefix-with-module
  "Test gensym with nil prefix and module creates MODULE__### with nil module-name."
  (let ((sym (gensym nil "baz")))
    (is-true (<symbol>? sym))
    (is-true (cl:search "BAZ__" (cl:symbol-name (fol-value sym))))
    (is (null (fol.classes:symbol-module-name sym)))))

(test gensym-with-current-module
  "Test gensym respects *current-module*."
  (let ((*current-module* "test-module"))
    (let ((sym (gensym)))
      (is (string= "test-module" (fol.classes:symbol-module-name sym))))))

(test gensym-with-symbol-prefix
  "Test gensym accepts symbol as prefix."
  (let ((sym (gensym 'myprefix)))
    (is-true (<symbol>? sym))
    (is-true (cl:search "MYPREFIX__" (cl:symbol-name (fol-value sym))))))
