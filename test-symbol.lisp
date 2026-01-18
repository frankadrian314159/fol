(in-package fol.tests)
(in-readtable fol-syntax)

(in-suite fol-suite)

(test symbol-wrapping
  "Test wrapping and unwrapping of symbols"
  ;; Basic symbols
  (is (typep (wrap 'foo) '<symbol>))
  (is (eq 'foo (unwrap (wrap 'foo))))
  (is (eq 'bar (unwrap (wrap 'bar))))
  (is (eq 'my-var (unwrap (wrap 'my-var))))
  
  ;; Keywords
  (is (eq :test (unwrap (wrap :test))))
  (is (eq :another-key (unwrap (wrap :another-key))))
  
  ;; Gensyms
  (let ((g (gensym "TEST")))
    (is (eq g (unwrap (wrap g)))))
  
  ;; Already wrapped
  (let ((wrapped-sym (wrap 'test)))
    (is (eq wrapped-sym (wrap wrapped-sym)))))

(test symbol-with-module
  "Test symbol creation with module name"
  (let ((sym1 (wrap-symbol 'foo "mymodule"))
        (sym2 (wrap-symbol 'bar)))
    ;; Check that the symbol value is correct
    (is (eq 'foo (unwrap-symbol sym1)))
    (is (eq 'bar (unwrap-symbol sym2)))
    
    ;; Check module names
    (is (equal "mymodule" (symbol-module-name sym1)))
    (is (null (symbol-module-name sym2)))
    
    ;; Check that values are initially the unbound sentinel
    (is (eq fol.symbol:+symbol-unbound-sentinel+ (get-symbol-value sym1)))
    (is (eq fol.symbol:+symbol-unbound-sentinel+ (get-symbol-value sym2)))))

(test symbol-value-operations
  "Test setting and getting symbol values"
  (let ((sym1 (wrap-symbol 'x))
        (sym2 (wrap-symbol 'y "math" 42)))
    ;; Initial values
    (is (eq fol.symbol:+symbol-unbound-sentinel+ (get-symbol-value sym1)))
    (is (= 42 (get-symbol-value sym2)))
    
    ;; Set values - capture return value (new object)
    (setf sym1 (set-symbol-value sym1 100))
    (is (= 100 (get-symbol-value sym1)))
    
    ;; Set to different types
    (setf sym1 (set-symbol-value sym1 "hello"))
    (is (equal "hello" (get-symbol-value sym1)))
    
    (setf sym1 (set-symbol-value sym1 (wrap 'another-symbol)))
    (is (typep (get-symbol-value sym1) '<symbol>))
    
    ;; Set to nil - this is different from unbound!
    (setf sym1 (set-symbol-value sym1 nil))
    (is (null (get-symbol-value sym1)))
    (is (cl:not (eq fol.symbol:+symbol-unbound-sentinel+ (get-symbol-value sym1))))
    
    ;; Set back to unbound sentinel
    (setf sym1 (set-symbol-value sym1 fol.symbol:+symbol-unbound-sentinel+))
    (is (eq fol.symbol:+symbol-unbound-sentinel+ (get-symbol-value sym1)))))

(test symbol-bound-predicate
  "Test symbol-bound? predicate"
  (let ((sym1 (wrap-symbol 'unbound))
        (sym2 (wrap-symbol 'bound "module" 123)))
    ;; Unbound symbol (has sentinel value)
    (is (cl:not (unwrap (symbol-bound? sym1))))
    (is (eq fol.symbol:+symbol-unbound-sentinel+ (get-symbol-value sym1)))
    
    ;; Bound symbol
    (is (unwrap (symbol-bound? sym2)))
    
    ;; Bind the unbound symbol
    (setf sym1 (set-symbol-value sym1 'some-value))
    (is (unwrap (symbol-bound? sym1)))
    
    ;; Binding to nil is still bound (different from unbound!)
    (setf sym1 (set-symbol-value sym1 nil))
    (is (unwrap (symbol-bound? sym1)))
    (is (null (get-symbol-value sym1)))
    
    ;; Set back to sentinel to make it unbound
    (setf sym1 (set-symbol-value sym1 fol.symbol:+symbol-unbound-sentinel+))
    (is (cl:not (unwrap (symbol-bound? sym1))))))

(test symbol-sentinel-behavior
  "Test unbound sentinel behavior - nil vs unbound distinction"
  (let ((sym (wrap-symbol 'test)))
    ;; Starts unbound with sentinel value
    (is (eq fol.symbol:+symbol-unbound-sentinel+ (get-symbol-value sym)))
    (is (cl:not (unwrap (symbol-bound? sym))))
    
    ;; Bind to nil - this is a valid value!
    (setf sym (set-symbol-value sym nil))
    (is (null (get-symbol-value sym)))
    (is (unwrap (symbol-bound? sym)))  ; Bound to nil, not unbound!
    
    ;; Bind to false
    (setf sym (set-symbol-value sym (wrap-bool nil)))
    (is (unwrap (symbol-bound? sym)))
    
    ;; Bind to 0
    (setf sym (set-symbol-value sym 0))
    (is (= 0 (get-symbol-value sym)))
    (is (unwrap (symbol-bound? sym)))
    
    ;; Bind to empty string
    (setf sym (set-symbol-value sym ""))
    (is (equal "" (get-symbol-value sym)))
    (is (unwrap (symbol-bound? sym)))
    
    ;; Only the sentinel means unbound
    (setf sym (set-symbol-value sym fol.symbol:+symbol-unbound-sentinel+))
    (is (cl:not (unwrap (symbol-bound? sym))))))


(test symbol-name-operations
  "Test symbol name extraction"
  (let ((sym1 (wrap 'hello))
        (sym2 (wrap :keyword))
        (sym3 (wrap 'common-lisp:car)))
    ;; Get symbol names
    (is (equal "HELLO" (unwrap-string (symbol-name-str sym1))))
    (is (equal "KEYWORD" (unwrap-string (symbol-name-str sym2))))
    (is (equal "CAR" (unwrap-string (symbol-name-str sym3))))))

(test symbol-package-operations
  "Test symbol package extraction"
  (let ((sym1 (wrap 'common-lisp:car))
        (sym2 (wrap :test))
        (sym3 (wrap (gensym))))
    ;; Get package names
    (is (equal "COMMON-LISP" (unwrap-string (symbol-package-str sym1))))
    (is (equal "KEYWORD" (unwrap-string (symbol-package-str sym2))))
    ;; Uninterned symbols have no package
    (is (null (symbol-package-str sym3)))))

(test symbol-type-predicates
  "Test FOL type predicates for symbols"
  (let ((s (wrap 'test)))
    (is (unwrap (<symbol>? s)))
    (is (unwrap (not (<bool>? s))))
    (is (unwrap (not (<number>? s))))
    (is (unwrap (not (<char>? s))))))

(test symbol-printing
  "Test symbol printing"
  ;; Regular symbols without module
  (is (equal "FOO" (format nil "~A" (wrap 'foo))))
  (is (equal "BAR" (format nil "~A" (wrap 'bar))))
  
  ;; Keywords
  (is (equal ":TEST" (format nil "~A" (wrap :test))))
  
  ;; Symbols with module name
  (let ((sym (wrap-symbol 'baz "mymodule")))
    (is (equal "mymodule::BAZ" (format nil "~A" sym)))))

(test symbol-inheritance
  "Test that <symbol> inherits from <string>"
  (let ((sym (wrap 'test)))
    ;; <symbol> should be a subclass of <string>
    (is (typep sym '<symbol>))
    (is (typep sym '<string>))))

(test symbol-list-operations
  "Test operations on lists of symbols"
  (let ((syms (mapcar #'wrap '(foo bar baz))))
    (is (= 3 (length syms)))
    (is (every (lambda (s) (typep s '<symbol>)) syms))
    (is (equal '(foo bar baz)
               (mapcar #'unwrap syms)))))

(test symbol-equality
  "Test symbol equality through wrapping"
  (let ((sym1 (wrap 'test))
        (sym2 (wrap 'test))
        (sym3 (wrap 'other)))
    ;; The underlying symbols should be eq
    (is (eq (unwrap sym1) (unwrap sym2)))
    (is (cl:not (eq (unwrap sym1) (unwrap sym3))))))

(test symbol-module-binding-integration
  "Test symbols as module bindings with values"
  ;; Simulate a simple module environment
  (let ((bindings (list (wrap-symbol 'x "vars" 10)
                        (wrap-symbol 'y "vars" 20)
                        (wrap-symbol 'add "ops" #'+)
                        (wrap-symbol 'mult "ops" #'*))))
    ;; All symbols should be bound
    (is (every (lambda (sym) (unwrap (symbol-bound? sym))) bindings))
    
    ;; Check module names
    (is (equal "vars" (symbol-module-name (first bindings))))
    (is (equal "ops" (symbol-module-name (third bindings))))
    
    ;; Use the function values
    (let ((add-fn (get-symbol-value (third bindings)))
          (x-val (get-symbol-value (first bindings)))
          (y-val (get-symbol-value (second bindings))))
      (is (= 30 (funcall add-fn x-val y-val))))
    
    ;; Modify a value - returns a new object
    (let ((updated-x (set-symbol-value (first bindings) 100)))
      (is (= 100 (get-symbol-value updated-x))))))
;;; ============================================================================
;;; Keyword Tests
;;; ============================================================================

(test keyword-wrapping
  "Test that keywords are wrapped as <keyword> instances"
  ;; Keywords should be wrapped as <keyword>, not <symbol>
  (is (typep (wrap :test) '<keyword>))
  (is (typep (wrap :foo) '<keyword>))
  (is (typep (wrap :bar) '<keyword>))
  
  ;; But they're still symbols
  (is (typep (wrap :test) '<symbol>))
  
  ;; Non-keywords should not be <keyword>
  (is (not (typep (wrap 'foo) '<keyword>)))
  (is (not (typep (wrap 'bar) '<keyword>)))
  
  ;; Unwrapping keywords
  (is (eq :test (unwrap (wrap :test))))
  (is (eq :another-key (unwrap (wrap :another-key)))))

(test keyword-predicate
  "Test <keyword>? predicate"
  (let ((kw1 (wrap :test))
        (kw2 (wrap :another))
        (sym1 (wrap 'not-keyword))
        (sym2 (wrap 'foo)))
    ;; Keywords return true
    (is (unwrap (<keyword>? kw1)))
    (is (unwrap (<keyword>? kw2)))
    
    ;; Non-keywords return false
    (is (not (unwrap (<keyword>? sym1))))
    (is (not (unwrap (<keyword>? sym2))))
    
    ;; Non-symbols return false
    (is (not (unwrap (<keyword>? (wrap 42)))))
    (is (not (unwrap (<keyword>? (wrap "string")))))
    (is (not (unwrap (<keyword>? #t))))
    
    ;; Direct keyword wrapping
    (is (unwrap (<keyword>? (wrap-symbol :direct-keyword))))))

(test keyword-with-values
  "Test that keywords can have associated values like symbols"
  (let ((kw1 (wrap-symbol :config "settings" 100))
        (kw2 (wrap :status)))
    ;; Keywords can have values
    (is (= 100 (get-symbol-value kw1)))
    (is (equal "settings" (symbol-module-name kw1)))
    
    ;; Keywords start unbound if no value provided
    (is (eq fol.symbol:+symbol-unbound-sentinel+ (get-symbol-value kw2)))
    
    ;; Can set values on keywords
    (setf kw2 (set-symbol-value kw2 "active"))
    (is (equal "active" (get-symbol-value kw2)))
    (is (unwrap (symbol-bound? kw2)))
    
    ;; Keywords are still keywords after value changes
    (is (typep kw2 '<keyword>))
    (is (unwrap (<keyword>? kw2)))))

(test keyword-printing
  "Test that keywords print correctly"
  (let ((kw1 (wrap :test))
        (kw2 (wrap-symbol :config "settings")))
    ;; Keywords with no module print with colon (uppercase, as CL symbols do)
    (is (search ":TEST" (format nil "~A" kw1)))
    
    ;; Keywords with modules print with module name
    (is (search "settings::" (format nil "~A" kw2)))))

(test keyword-operations
  "Test that keyword operations work like symbol operations"
  (let ((kw (wrap :operation)))
    ;; Can get name as string
    (is (equal "OPERATION" (unwrap (symbol-name-str kw))))
    
    ;; Can get package (should be KEYWORD package)
    (let ((pkg-str (symbol-package-str kw)))
      (is (typep pkg-str '<string>))
      (is (equal "KEYWORD" (unwrap pkg-str))))
    
    ;; Symbol-bound? works on keywords
    (is (not (unwrap (symbol-bound? kw))))
    (setf kw (set-symbol-value kw 'value))
    (is (unwrap (symbol-bound? kw)))))

(test keyword-type-hierarchy
  "Test that <keyword> properly inherits from <symbol>"
  (let ((kw (wrap :test))
        (sym (wrap 'test)))
    ;; Keywords are symbols
    (is (typep kw '<symbol>))
    (is (unwrap (<symbol>? kw)))
    
    ;; But symbols are not keywords
    (is (not (typep sym '<keyword>)))
    (is (not (unwrap (<keyword>? sym))))
    
    ;; Both are strings (through inheritance)
    (is (typep kw '<string>))
    (is (typep sym '<string>))))

;;; ============================================================================
;;; Type Conversion with 'as' Tests
;;; ============================================================================

(test as-string-to-symbol
  "Test converting strings to symbols with as"
  ;; Basic conversion
  (is (typep (as '<symbol> "foo") '<symbol>))
  (is (eq 'FOO (unwrap (as '<symbol> "foo"))))
  
  ;; Case insensitivity - all should return the same symbol
  (is (eq (unwrap (as '<symbol> "foo"))
          (unwrap (as '<symbol> "FOO"))))
  (is (eq (unwrap (as '<symbol> "foo"))
          (unwrap (as '<symbol> "Foo"))))
  (is (eq (unwrap (as '<symbol> "TEST"))
          (unwrap (as '<symbol> "test"))))
  
  ;; Works with wrapped FOL strings too
  (is (eq 'BAR (unwrap (as '<symbol> (wrap "bar")))))
  (is (eq 'BAZ (unwrap (as '<symbol> (wrap "BAZ")))))
  
  ;; Same symbol object is returned for same name (identity test)
  (let ((sym1 (as '<symbol> "test"))
        (sym2 (as '<symbol> "TEST")))
    (is (eq (unwrap sym1) (unwrap sym2))))
  
  ;; Various symbol names
  (is (eq 'MY-VAR (unwrap (as '<symbol> "my-var"))))
  (is (eq 'ANOTHER-SYMBOL (unwrap (as '<symbol> "Another-Symbol")))))

(test as-string-to-keyword
  "Test converting strings to keywords with as"
  ;; Basic conversion
  (is (typep (as '<keyword> "foo") '<keyword>))
  (is (eq :FOO (unwrap (as '<keyword> "foo"))))
  
  ;; Case insensitivity
  (is (eq (unwrap (as '<keyword> "bar"))
          (unwrap (as '<keyword> "BAR"))))
  (is (eq (unwrap (as '<keyword> "bar"))
          (unwrap (as '<keyword> "Bar"))))
  (is (eq (unwrap (as '<keyword> "CONFIG"))
          (unwrap (as '<keyword> "config"))))
  
  ;; Works with wrapped FOL strings
  (is (eq :TEST (unwrap (as '<keyword> (wrap "test")))))
  (is (eq :STATUS (unwrap (as '<keyword> (wrap "STATUS")))))
  
  ;; Keywords are also symbols
  (is (typep (as '<keyword> "foo") '<symbol>))
  (is (unwrap (<symbol>? (as '<keyword> "test"))))
  
  ;; Same keyword object for same name
  (let ((kw1 (as '<keyword> "value"))
        (kw2 (as '<keyword> "VALUE")))
    (is (eq (unwrap kw1) (unwrap kw2)))))

(test as-symbol-to-string
  "Test converting symbols to strings with as"
  ;; Basic conversion
  (is (typep (as '<string> 'foo) '<string>))
  (is (equal "foo" (unwrap (as '<string> 'foo))))
  
  ;; Works with wrapped FOL symbols
  (is (equal "bar" (unwrap (as '<string> (wrap 'bar)))))
  
  ;; Default case is lowercase (per spec)
  (is (equal "test" (unwrap (as '<string> 'TEST))))
  (is (equal "myvar" (unwrap (as '<string> 'MYVAR))))
  (is (equal "another-symbol" (unwrap (as '<string> 'ANOTHER-SYMBOL))))
  
  ;; Mixed case symbols
  (is (equal "foo" (unwrap (as '<string> 'FOO))))
  
  ;; Symbols with hyphens
  (is (equal "my-variable" (unwrap (as '<string> 'MY-VARIABLE)))))

(test as-keyword-to-string
  "Test converting keywords to strings with as"
  ;; Basic conversion
  (is (typep (as '<string> :foo) '<string>))
  (is (equal "foo" (unwrap (as '<string> :foo))))
  (is (equal "bar" (unwrap (as '<string> :bar))))
  
  ;; Works with wrapped FOL keywords
  (is (equal "test" (unwrap (as '<string> (wrap :test)))))
  (is (equal "config" (unwrap (as '<string> (wrap :config)))))
  
  ;; Default case is lowercase (per spec)
  (is (equal "status" (unwrap (as '<string> :STATUS))))
  (is (equal "my-keyword" (unwrap (as '<string> :MY-KEYWORD)))))

(test as-round-trip-conversions
  "Test round-trip conversions with as"
  ;; Symbol -> String -> Symbol
  (is (eq 'FOO (unwrap (as '<symbol> (as '<string> 'FOO)))))
  (is (eq 'BAR (unwrap (as '<symbol> (as '<string> 'bar)))))
  (is (eq 'MY-VAR (unwrap (as '<symbol> (as '<string> 'MY-VAR)))))
  
  ;; Keyword -> String -> Keyword
  (is (eq :FOO (unwrap (as '<keyword> (as '<string> :FOO)))))
  (is (eq :BAR (unwrap (as '<keyword> (as '<string> :bar)))))
  (is (eq :CONFIG (unwrap (as '<keyword> (as '<string> :CONFIG)))))
  
  ;; String -> Symbol -> String (preserves name, converts to lowercase)
  (is (equal "test" (unwrap (as '<string> (as '<symbol> "TEST")))))
  (is (equal "foo" (unwrap (as '<string> (as '<symbol> "foo")))))
  
  ;; String -> Keyword -> String (preserves name, converts to lowercase)
  (is (equal "test" (unwrap (as '<string> (as '<keyword> "TEST")))))
  (is (equal "bar" (unwrap (as '<string> (as '<keyword> "bar"))))))

(test as-case-insensitive-behavior
  "Test that 'as' is case-insensitive when creating symbols/keywords"
  ;; String to symbol - different cases produce same symbol
  (let ((s1 (as '<symbol> "FooBar"))
        (s2 (as '<symbol> "foobar"))
        (s3 (as '<symbol> "FOOBAR"))
        (s4 (as '<symbol> "FoObAr")))
    (is (eq (unwrap s1) (unwrap s2)))
    (is (eq (unwrap s2) (unwrap s3)))
    (is (eq (unwrap s3) (unwrap s4))))
  
  ;; String to keyword - different cases produce same keyword
  (let ((k1 (as '<keyword> "FooBar"))
        (k2 (as '<keyword> "foobar"))
        (k3 (as '<keyword> "FOOBAR"))
        (k4 (as '<keyword> "FoObAr")))
    (is (eq (unwrap k1) (unwrap k2)))
    (is (eq (unwrap k2) (unwrap k3)))
    (is (eq (unwrap k3) (unwrap k4)))))

(test as-wrapped-and-unwrapped-values
  "Test that 'as' works with both wrapped and unwrapped values"
  ;; String inputs (both wrapped and unwrapped)
  (is (eq (unwrap (as '<symbol> "test"))
          (unwrap (as '<symbol> (wrap "test")))))
  (is (eq (unwrap (as '<keyword> "foo"))
          (unwrap (as '<keyword> (wrap "foo")))))
  
  ;; Symbol inputs (both wrapped and unwrapped)
  (is (equal (unwrap (as '<string> 'bar))
             (unwrap (as '<string> (wrap 'bar)))))
  
  ;; Keyword inputs (both wrapped and unwrapped)
  (is (equal (unwrap (as '<string> :test))
             (unwrap (as '<string> (wrap :test))))))

(test as-colon-detection
  "Test that 'as' detects : prefix and creates keywords automatically"
  ;; String starting with : to <symbol> should create keyword
  (is (typep (as '<symbol> ":foo") '<keyword>))
  (is (eq :FOO (unwrap (as '<symbol> ":foo"))))
  (is (eq :BAR (unwrap (as '<symbol> ":bar"))))
  (is (eq :TEST (unwrap (as '<symbol> ":test"))))
  
  ;; String without : to <symbol> should create regular symbol
  (is (typep (as '<symbol> "foo") '<symbol>))
  (is (not (typep (as '<symbol> "foo") '<keyword>)))
  (is (eq 'FOO (unwrap (as '<symbol> "foo"))))
  (is (eq 'BAR (unwrap (as '<symbol> "bar"))))
  
  ;; Works with wrapped strings too
  (is (typep (as '<symbol> (wrap ":config")) '<keyword>))
  (is (eq :CONFIG (unwrap (as '<symbol> (wrap ":config")))))
  (is (eq 'TEST (unwrap (as '<symbol> (wrap "test")))))
  
  ;; Case insensitive with colon
  (is (eq :FOO (unwrap (as '<symbol> ":foo"))))
  (is (eq :FOO (unwrap (as '<symbol> ":FOO"))))
  (is (eq :FOO (unwrap (as '<symbol> ":Foo"))))
  
  ;; Explicit <keyword> type - colon is optional
  (is (eq :FOO (unwrap (as '<keyword> ":foo"))))
  (is (eq :FOO (unwrap (as '<keyword> "foo"))))
  (is (eq (unwrap (as '<keyword> ":bar"))
          (unwrap (as '<keyword> "bar"))))
  
  ;; Empty string edge case
  (is (typep (as '<symbol> "") '<symbol>))
  (is (not (typep (as '<symbol> "") '<keyword>))))