(in-package :fol.tests)

(def-suite wrappers-suite
  :description "Tests for FOL wrapper protocol (Option 4)"
  :in fol-suite)

(in-suite wrappers-suite)

;;; ============================================================================
;;; fol-value - Core Protocol
;;; ============================================================================

(test fol-value-raw-booleans
  "Test fol-value with raw booleans (pass-through)"
  (is (eq t (fol-value t)))
  (is (eq nil (fol-value nil))))

(test fol-value-raw-numbers
  "Test fol-value with raw numbers (pass-through)"
  ;; Fixnum
  (is (cl:= 42 (fol-value 42)))
  (is (cl:= -100 (fol-value -100)))
  (is (cl:= 0 (fol-value 0)))
  ;; Bignum
  (is (cl:= 10000000000000000000 (fol-value 10000000000000000000)))
  ;; Float
  (is (cl:= 3.14 (fol-value 3.14)))
  (is (cl:= 2.718d0 (fol-value 2.718d0)))
  ;; Ratio
  (is (cl:= 3/4 (fol-value 3/4)))
  ;; Complex
  (is (cl:= #C(1 2) (fol-value #C(1 2))))
  (is (cl:= #C(3.0 4.0) (fol-value #C(3.0 4.0)))))

(test fol-value-raw-characters
  "Test fol-value with raw characters (pass-through)"
  (is (char= #\a (fol-value #\a)))
  (is (char= #\Z (fol-value #\Z)))
  (is (char= #\Space (fol-value #\Space)))
  (is (char= #\Newline (fol-value #\Newline))))

(test fol-value-raw-strings
  "Test fol-value with raw strings (pass-through)"
  (is (string= "hello" (fol-value "hello")))
  (is (string= "" (fol-value "")))
  (is (string= "with spaces" (fol-value "with spaces"))))

(test fol-value-raw-symbols
  "Test fol-value with raw symbols (pass-through)"
  (is (eq 'foo (fol-value 'foo)))
  (is (eq :bar (fol-value :bar)))
  (is (eq 'cl:list (fol-value 'cl:list))))

(test fol-value-wrapped-booleans
  "Test fol-value with wrapped booleans (extraction)"
  (is (eq t (fol-value (wrap-bool t))))
  (is (eq nil (fol-value (wrap-bool nil)))))

(test fol-value-wrapped-numbers
  "Test fol-value with wrapped numbers (extraction)"
  (is (cl:= 42 (fol-value (wrap-number 42))))
  (is (cl:= 3.14 (fol-value (wrap-number 3.14))))
  (is (cl:= 3/4 (fol-value (wrap-number 3/4))))
  (is (cl:= #C(1 2) (fol-value (wrap-number #C(1 2))))))

(test fol-value-wrapped-characters
  "Test fol-value with wrapped characters (extraction)"
  (is (char= #\a (fol-value (wrap-char #\a))))
  (is (char= #\Z (fol-value (wrap-char #\Z))))
  (is (char= #\Space (fol-value (wrap-char #\Space)))))

(test fol-value-wrapped-strings
  "Test fol-value with wrapped strings (extraction)"
  (is (string= "hello" (fol-value (wrap-string "hello"))))
  (is (string= "" (fol-value (wrap-string ""))))
  (is (string= "test" (fol-value (wrap-string "test")))))

(test fol-value-wrapped-symbols
  "Test fol-value with wrapped symbols (extraction)"
  (is (eq 'foo (fol-value (wrap-symbol 'foo))))
  (is (eq :bar (fol-value (wrap-symbol :bar)))))

;;; ============================================================================
;;; fol-type-of - Type Reflection
;;; ============================================================================

(test fol-type-of-booleans
  "Test fol-type-of with booleans"
  ;; Raw booleans
  (is (eq '<bool> (fol-type-of t)))
  (is (eq '<bool> (fol-type-of nil)))
  ;; Wrapped booleans
  (is (eq '<bool> (fol-type-of (wrap-bool t))))
  (is (eq '<bool> (fol-type-of (wrap-bool nil)))))

(test fol-type-of-numbers
  "Test fol-type-of with various number types"
  ;; Raw fixnum
  (is (eq '<fixnum> (fol-type-of 42)))
  (is (eq '<fixnum> (fol-type-of -100)))
  ;; Raw bignum
  (is (eq '<bignum> (fol-type-of 10000000000000000000)))
  ;; Raw single-float
  (is (eq '<single-float> (fol-type-of 3.14)))
  ;; Raw double-float
  (is (eq '<double-float> (fol-type-of 3.14d0)))
  ;; Raw ratio
  (is (eq '<ratio> (fol-type-of 3/4)))
  ;; Raw complex
  (is (eq '<complex> (fol-type-of #C(1 2))))
  ;; Wrapped numbers
  (is (eq '<fixnum> (fol-type-of (wrap-number 42))))
  (is (eq '<single-float> (fol-type-of (wrap-number 3.14))))
  (is (eq '<ratio> (fol-type-of (wrap-number 3/4)))))

(test fol-type-of-characters
  "Test fol-type-of with characters"
  ;; Raw characters
  (is (eq '<char> (fol-type-of #\a)))
  (is (eq '<char> (fol-type-of #\Space)))
  ;; Wrapped characters
  (is (eq '<char> (fol-type-of (wrap-char #\a)))))

(test fol-type-of-strings
  "Test fol-type-of with strings"
  ;; Raw strings
  (is (eq '<string> (fol-type-of "hello")))
  (is (eq '<string> (fol-type-of "")))
  ;; Wrapped strings
  (is (eq '<string> (fol-type-of (wrap-string "hello")))))

(test fol-type-of-symbols
  "Test fol-type-of with symbols"
  ;; Raw symbols
  (is (eq '<symbol> (fol-type-of 'foo)))
  (is (eq '<keyword> (fol-type-of :bar)))
  ;; Wrapped symbols
  (is (eq '<symbol> (fol-type-of (wrap-symbol 'foo))))
  (is (eq '<keyword> (fol-type-of (wrap-symbol :bar)))))

;;; ============================================================================
;;; wrap Function - Type-dispatching Wrapper
;;; ============================================================================

(test wrap-booleans
  "Test wrap with booleans"
  ;; T and NIL are wrapped into <bool> instances
  (is (typep (wrap t) '<bool>))
  (is (typep (wrap nil) '<bool>))
  (is (eq t (fol-value (wrap t))))
  (is (eq nil (fol-value (wrap nil))))
  ;; Double wrapping returns same object
  (let ((wrapped-t (wrap t))
        (wrapped-nil (wrap nil)))
    (is (eq wrapped-t (wrap wrapped-t)))
    (is (eq wrapped-nil (wrap wrapped-nil)))))

(test wrap-numbers
  "Test wrap with numbers"
  ;; Wrapping produces the correct type
  (is (typep (wrap 42) '<fixnum>))
  (is (typep (wrap 10000000000000000000) '<bignum>))
  (is (typep (wrap 3.14) '<single-float>))
  (is (typep (wrap 3.14d0) '<double-float>))
  (is (typep (wrap 3/4) '<ratio>))
  (is (typep (wrap #C(1 2)) '<complex>))
  ;; Double wrapping returns same object
  (let ((wrapped (wrap 42)))
    (is (eq wrapped (wrap wrapped)))))

(test wrap-characters
  "Test wrap with characters"
  (is (typep (wrap #\a) '<char>))
  (is (typep (wrap #\Space) '<char>))
  ;; Double wrapping returns same object
  (let ((wrapped (wrap #\a)))
    (is (eq wrapped (wrap wrapped)))))

(test wrap-strings
  "Test wrap with strings"
  (is (typep (wrap "hello") '<string>))
  (is (typep (wrap "") '<string>))
  ;; Double wrapping returns same object
  (let ((wrapped (wrap "hello")))
    (is (eq wrapped (wrap wrapped)))))

(test wrap-symbols
  "Test wrap with symbols"
  (is (typep (wrap 'foo) '<symbol>))
  (is (typep (wrap :bar) '<keyword>))
  ;; Double wrapping returns same object
  (let ((wrapped (wrap 'foo)))
    (is (eq wrapped (wrap wrapped)))))

;;; ============================================================================
;;; unwrap Function - Value Extraction (Alias for fol-value)
;;; ============================================================================

(test unwrap-booleans
  "Test unwrap with booleans"
  (is (eq t (unwrap t)))
  (is (eq nil (unwrap nil)))
  (is (eq t (unwrap (wrap t))))
  (is (eq nil (unwrap (wrap nil)))))

(test unwrap-numbers
  "Test unwrap with numbers"
  (is (cl:= 42 (unwrap 42)))
  (is (cl:= 42 (unwrap (wrap 42))))
  (is (cl:= 3.14 (unwrap (wrap 3.14))))
  (is (cl:= 3/4 (unwrap (wrap 3/4)))))

(test unwrap-characters
  "Test unwrap with characters"
  (is (char= #\a (unwrap #\a)))
  (is (char= #\a (unwrap (wrap #\a)))))

(test unwrap-strings
  "Test unwrap with strings"
  (is (string= "hello" (unwrap "hello")))
  (is (string= "hello" (unwrap (wrap "hello")))))

(test unwrap-symbols
  "Test unwrap with symbols"
  (is (eq 'foo (unwrap 'foo)))
  (is (eq 'foo (unwrap (wrap 'foo))))
  (is (eq :bar (unwrap (wrap :bar)))))

;;; ============================================================================
;;; Specific Wrap Functions
;;; ============================================================================

(test wrap-bool-function
  "Test wrap-bool function"
  ;; Returns <bool> instances with appropriate values
  (is (typep (wrap-bool t) '<bool>))
  (is (typep (wrap-bool nil) '<bool>))
  (is (eq t (fol-value (wrap-bool t))))
  (is (eq nil (fol-value (wrap-bool nil))))
  ;; Any truthy value becomes T
  (is (eq t (fol-value (wrap-bool 1))))
  (is (eq t (fol-value (wrap-bool "truthy"))))
  (is (eq t (fol-value (wrap-bool 'symbol)))))

(test wrap-char-function
  "Test wrap-char function"
  (is (typep (wrap-char #\a) '<char>))
  (is (char= #\a (fol-value (wrap-char #\a))))
  ;; Error on non-character
  (signals error (wrap-char "not a char"))
  (signals error (wrap-char 65)))

(test wrap-string-function
  "Test wrap-string function"
  (is (typep (wrap-string "hello") '<string>))
  (is (string= "hello" (fol-value (wrap-string "hello"))))
  (is (string= "" (fol-value (wrap-string ""))))
  ;; Error on non-string
  (signals error (wrap-string #\a))
  (signals error (wrap-string 'symbol)))

(test wrap-symbol-function
  "Test wrap-symbol function"
  (is (typep (wrap-symbol 'foo) '<symbol>))
  (is (typep (wrap-symbol :bar) '<keyword>))
  (is (eq 'foo (fol-value (wrap-symbol 'foo))))
  (is (eq :bar (fol-value (wrap-symbol :bar))))
  ;; Error on non-symbol
  (signals error (wrap-symbol "not a symbol"))
  (signals error (wrap-symbol 42)))

(test wrap-number-function
  "Test wrap-number function"
  ;; Fixnum
  (is (typep (wrap-number 42) '<fixnum>))
  (is (cl:= 42 (fol-value (wrap-number 42))))
  ;; Bignum
  (is (typep (wrap-number 10000000000000000000) '<bignum>))
  ;; Single-float
  (is (typep (wrap-number 3.14) '<single-float>))
  ;; Double-float
  (is (typep (wrap-number 3.14d0) '<double-float>))
  ;; Ratio
  (is (typep (wrap-number 3/4) '<ratio>))
  ;; Complex
  (is (typep (wrap-number #C(1 2)) '<complex>))
  ;; Error on non-number
  (signals error (wrap-number "not a number"))
  (signals error (wrap-number 'symbol)))

;;; ============================================================================
;;; Specific Unwrap Functions
;;; ============================================================================

(test unwrap-bool-function
  "Test unwrap-bool function (alias for fol-value)"
  (is (eq t (unwrap-bool t)))
  (is (eq nil (unwrap-bool nil)))
  (is (eq t (unwrap-bool (wrap-bool t)))))

(test unwrap-char-function
  "Test unwrap-char function (alias for fol-value)"
  (is (char= #\a (unwrap-char #\a)))
  (is (char= #\a (unwrap-char (wrap-char #\a)))))

(test unwrap-string-function
  "Test unwrap-string function (alias for fol-value)"
  (is (string= "hello" (unwrap-string "hello")))
  (is (string= "hello" (unwrap-string (wrap-string "hello")))))

(test unwrap-symbol-function
  "Test unwrap-symbol function (alias for fol-value)"
  (is (eq 'foo (unwrap-symbol 'foo)))
  (is (eq 'foo (unwrap-symbol (wrap-symbol 'foo)))))

(test unwrap-number-function
  "Test unwrap-number function (alias for fol-value)"
  (is (cl:= 42 (unwrap-number 42)))
  (is (cl:= 42 (unwrap-number (wrap-number 42)))))

;;; ============================================================================
;;; Type Checking Utilities (fol-*p predicates)
;;; ============================================================================

(test fol-numberp-predicate
  "Test fol-numberp predicate"
  ;; Raw numbers
  (is (eq t (fol-numberp 42)))
  (is (eq t (fol-numberp 3.14)))
  (is (eq t (fol-numberp 3/4)))
  (is (eq t (fol-numberp #C(1 2))))
  ;; Wrapped numbers
  (is (eq t (fol-numberp (wrap 42))))
  (is (eq t (fol-numberp (wrap 3.14))))
  ;; Non-numbers
  (is (eq nil (fol-numberp "42")))
  (is (eq nil (fol-numberp #\0)))
  (is (eq nil (fol-numberp 'forty-two))))

(test fol-integerp-predicate
  "Test fol-integerp predicate"
  ;; Raw integers
  (is (eq t (fol-integerp 42)))
  (is (eq t (fol-integerp -100)))
  (is (eq t (fol-integerp 10000000000000000000)))
  ;; Wrapped integers
  (is (eq t (fol-integerp (wrap 42))))
  ;; Non-integers
  (is (eq nil (fol-integerp 3.14)))
  (is (eq nil (fol-integerp 3/4)))
  (is (eq nil (fol-integerp "42"))))

(test fol-realp-predicate
  "Test fol-realp predicate"
  ;; Raw reals
  (is (eq t (fol-realp 42)))
  (is (eq t (fol-realp 3.14)))
  (is (eq t (fol-realp 3/4)))
  ;; Wrapped reals
  (is (eq t (fol-realp (wrap 42))))
  (is (eq t (fol-realp (wrap 3.14))))
  ;; Non-reals (complex is not real)
  (is (eq nil (fol-realp #C(1 2))))
  (is (eq nil (fol-realp "42"))))

(test fol-stringp-predicate
  "Test fol-stringp predicate"
  ;; Raw strings
  (is (eq t (fol-stringp "hello")))
  (is (eq t (fol-stringp "")))
  ;; Wrapped strings
  (is (eq t (fol-stringp (wrap "hello"))))
  ;; Non-strings
  (is (eq nil (fol-stringp #\a)))
  (is (eq nil (fol-stringp 'symbol)))
  (is (eq nil (fol-stringp 42))))

(test fol-characterp-predicate
  "Test fol-characterp predicate"
  ;; Raw characters
  (is (eq t (fol-characterp #\a)))
  (is (eq t (fol-characterp #\Space)))
  ;; Wrapped characters
  (is (eq t (fol-characterp (wrap #\a))))
  ;; Non-characters
  (is (eq nil (fol-characterp "a")))
  (is (eq nil (fol-characterp 65)))
  (is (eq nil (fol-characterp 'a))))

(test fol-symbolp-predicate
  "Test fol-symbolp predicate"
  ;; Raw symbols
  (is (eq t (fol-symbolp 'foo)))
  (is (eq t (fol-symbolp :bar)))
  (is (eq t (fol-symbolp t)))
  (is (eq t (fol-symbolp nil)))
  ;; Wrapped symbols
  (is (eq t (fol-symbolp (wrap 'foo))))
  (is (eq t (fol-symbolp (wrap :bar))))
  ;; Non-symbols
  (is (eq nil (fol-symbolp "foo")))
  (is (eq nil (fol-symbolp 42))))

(test fol-booleanp-predicate
  "Test fol-booleanp predicate"
  ;; Raw booleans
  (is (eq t (fol-booleanp t)))
  (is (eq t (fol-booleanp nil)))
  ;; Wrapped booleans
  (is (eq t (fol-booleanp (wrap t))))
  (is (eq t (fol-booleanp (wrap nil))))
  ;; Non-booleans (other symbols are not booleans)
  (is (eq nil (fol-booleanp 'true)))
  (is (eq nil (fol-booleanp 1)))
  (is (eq nil (fol-booleanp "true"))))

;;; ============================================================================
;;; Round-trip Tests
;;; ============================================================================

(test wrap-unwrap-roundtrip
  "Test that wrap/unwrap is a round-trip for all types"
  ;; Booleans
  (is (eq t (unwrap (wrap t))))
  (is (eq nil (unwrap (wrap nil))))
  ;; Numbers
  (is (cl:= 42 (unwrap (wrap 42))))
  (is (cl:= 10000000000000000000
            (unwrap (wrap 10000000000000000000))))
  (is (cl:= 3.14 (unwrap (wrap 3.14))))
  (is (cl:= 3/4 (unwrap (wrap 3/4))))
  (is (cl:= #C(1 2) (unwrap (wrap #C(1 2)))))
  ;; Characters
  (is (char= #\a (unwrap (wrap #\a))))
  (is (char= #\Space (unwrap (wrap #\Space))))
  ;; Strings
  (is (string= "hello" (unwrap (wrap "hello"))))
  (is (string= "" (unwrap (wrap ""))))
  ;; Symbols
  (is (eq 'foo (unwrap (wrap 'foo))))
  (is (eq :bar (unwrap (wrap :bar)))))

(test mapcar-wrap-unwrap
  "Test wrap/unwrap with mapcar over a list of mixed types"
  (is (equal '(t nil 42 10000000000000000000 3/4 #C(1 2) #C(3.0 4.0))
             (mapcar #'unwrap
                     (mapcar #'wrap
                             '(t nil 42 10000000000000000000 3/4 #C(1 2) #C(3.0 4.0)))))))

;;; ============================================================================
;;; Edge Cases
;;; ============================================================================

(test wrap-already-wrapped
  "Test that wrapping an already wrapped object returns the same object"
  (let ((wrapped-num (wrap 42))
        (wrapped-char (wrap #\a))
        (wrapped-str (wrap "hello"))
        (wrapped-sym (wrap 'foo)))
    (is (eq wrapped-num (wrap wrapped-num)))
    (is (eq wrapped-char (wrap wrapped-char)))
    (is (eq wrapped-str (wrap wrapped-str)))
    (is (eq wrapped-sym (wrap wrapped-sym)))))

(test wrap-special-numbers
  "Test wrapping special numeric values"
  ;; Zero
  (is (typep (wrap 0) '<fixnum>))
  (is (cl:= 0 (unwrap (wrap 0))))
  ;; Negative fixnum
  (is (typep (wrap -42) '<fixnum>))
  (is (cl:= -42 (unwrap (wrap -42))))
  ;; Very large negative bignum
  (is (typep (wrap -10000000000000000000) '<bignum>)))

(test wrap-special-characters
  "Test wrapping special characters"
  (is (char= #\Null (unwrap (wrap #\Null))))
  (is (char= #\Tab (unwrap (wrap #\Tab))))
  (is (char= #\Newline (unwrap (wrap #\Newline))))
  (is (char= #\Return (unwrap (wrap #\Return)))))

(test wrap-unicode-strings
  "Test wrapping unicode strings"
  (is (string= "café" (unwrap (wrap "café"))))
  (is (string= "日本語" (unwrap (wrap "日本語")))))

(test wrap-error-on-invalid-input
  "Test that wrap signals error for unsupported types"
  (signals error (wrap (make-array 3)))
  (signals error (wrap (make-hash-table))))
