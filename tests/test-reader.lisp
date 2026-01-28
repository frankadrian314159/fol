(in-package :fol.tests)

;;; ============================================================================
;;; Reader Tests - Comprehensive test suite for FOL reader
;;; ============================================================================

(def-suite* :fol.reader-tests)

;;; ---------------------------------------------------------------------------
;;; Helper Functions
;;; ---------------------------------------------------------------------------

(defun fol-read-from-string-clj (string)
  "Read STRING using *clojure-readtable* explicitly."
  (fol-read-from-string string t nil *clojure-readtable*))

;;; ---------------------------------------------------------------------------
;;; Readtable Type Predicate Tests
;;; ---------------------------------------------------------------------------

(test readtable-predicate
  "Test <readtable>? predicate."
  (is-true (<readtable>? (make-readtable nil)))
  (is-true (<readtable>? *clojure-readtable*))
  (is-false (<readtable>? (make-dict)))
  (is-false (<readtable>? 42))
  (is-false (<readtable>? nil)))

;;; ---------------------------------------------------------------------------
;;; Readtable Creation Tests
;;; ---------------------------------------------------------------------------

(test readtable-creation-empty
  "Test creation of empty readtable."
  (let ((rt (make-readtable nil)))
    (is-true (<readtable>? rt))))

(test readtable-creation-with-functions
  "Test creation of readtable with reader functions."
  (let ((rt (make-readtable nil
              #\a (lambda (stream chr) (declare (ignore stream chr)) 'a-result)
              #\b (lambda (stream chr) (declare (ignore stream chr)) 'b-result))))
    (is-true (<readtable>? rt))
    (is (functionp (fol-get-macro-character rt #\a)))
    (is (functionp (fol-get-macro-character rt #\b)))))

(test readtable-creation-with-char-list
  "Test creation of readtable with character lists."
  (let* ((fn (lambda (stream chr) (declare (ignore stream chr)) 'result))
         (rt (make-readtable nil '(#\x #\y #\z) fn)))
    (is (functionp (fol-get-macro-character rt #\x)))
    (is (functionp (fol-get-macro-character rt #\y)))
    (is (functionp (fol-get-macro-character rt #\z)))))

;;; ---------------------------------------------------------------------------
;;; Character Class Table Tests
;;; ---------------------------------------------------------------------------

(test character-class-table-predicate
  "Test <character-class-table>? predicate."
  (let ((table (make-character-class-table
                :digits '(#\0 #\1 #\2))))
    (is-true (<character-class-table>? table))
    (is-false (<character-class-table>? (make-dict)))
    (is-false (<character-class-table>? nil))))

(test character-class-table-creation
  "Test character class table creation and lookup."
  (let ((table (make-character-class-table
                :digits '(#\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9)
                :letters '(#\a #\b #\c)
                :whitespace '(#\Space #\Tab #\Newline))))
    (is (= 10 (length (get table :digits))))
    (is (= 3 (length (get table :letters))))
    (is (= 3 (length (get table :whitespace))))))

(test character-class-table-errors
  "Test character class table validation errors."
  ;; Non-symbol key
  (signals error
    (make-character-class-table "not-symbol" '(#\a)))
  ;; Non-list value
  (signals error
    (make-character-class-table :key #\a))
  ;; Non-character in list
  (signals error
    (make-character-class-table :key '(#\a "b"))))

;;; ---------------------------------------------------------------------------
;;; Macro Character Tests
;;; ---------------------------------------------------------------------------

(test macro-character-set-get
  "Test setting and getting macro characters."
  (let ((rt (make-readtable nil))
        (test-fn (lambda (stream chr) (declare (ignore stream chr)) 'test-result)))
    (fol-set-macro-character rt #\@ test-fn)
    (multiple-value-bind (fn non-term-p)
        (fol-get-macro-character rt #\@)
      (is (eq fn test-fn))
      (is (null non-term-p)))))

(test macro-character-overwrite
  "Test that setting macro character overwrites previous."
  (let ((rt (make-readtable nil))
        (fn1 (lambda (stream chr) (declare (ignore stream chr)) 'first))
        (fn2 (lambda (stream chr) (declare (ignore stream chr)) 'second)))
    (fol-set-macro-character rt #\x fn1)
    (fol-set-macro-character rt #\x fn2)
    (is (eq fn2 (fol-get-macro-character rt #\x)))))

(test macro-character-errors
  "Test macro character validation errors."
  (let ((rt (make-readtable nil)))
    ;; Non-character
    (signals error
      (fol-set-macro-character rt "x" #'identity))
    ;; Non-function
    (signals error
      (fol-set-macro-character rt #\x "not-a-function"))))

;;; ---------------------------------------------------------------------------
;;; Dispatch Macro Character Tests
;;; ---------------------------------------------------------------------------

(test dispatch-macro-set-get
  "Test setting and getting dispatch macro characters."
  (let ((rt (make-readtable nil))
        (test-fn (lambda (stream chr arg) (declare (ignore stream chr arg)) 'dispatch-result)))
    (fol-set-dispatch-macro-character rt #\# #\{ test-fn)
    (let ((fn (fol-get-dispatch-macro-character rt #\# #\{)))
      (is (eq fn test-fn)))))

(test dispatch-macro-multiple-dispatches
  "Test multiple dispatch characters under same dispatch char."
  (let ((rt (make-readtable nil))
        (fn1 (lambda (s c a) (declare (ignore s c a)) 'set))
        (fn2 (lambda (s c a) (declare (ignore s c a)) 'bag)))
    (fol-set-dispatch-macro-character rt #\# #\{ fn1)
    (fol-set-dispatch-macro-character rt #\# #\M fn2)
    (is (eq fn1 (fol-get-dispatch-macro-character rt #\# #\{)))
    (is (eq fn2 (fol-get-dispatch-macro-character rt #\# #\M)))))

(test dispatch-macro-errors
  "Test dispatch macro validation errors."
  (let ((rt (make-readtable nil)))
    ;; Non-character dispatch char
    (signals error
      (fol-set-dispatch-macro-character rt "x" #\y #'identity))
    ;; Non-character sub-char
    (signals error
      (fol-set-dispatch-macro-character rt #\# "y" #'identity))
    ;; Non-function
    (signals error
      (fol-set-dispatch-macro-character rt #\# #\x "not-fn"))))

;;; ---------------------------------------------------------------------------
;;; Reader Symbol Tests
;;; ---------------------------------------------------------------------------

(test reader-symbol-simple
  "Test reading simple symbols."
  (is (eq 'foo (fol-read-from-string-clj "foo")))
  (is (eq 'bar (fol-read-from-string-clj "bar")))
  (is (eq 'baz (fol-read-from-string-clj "baz"))))

(test reader-symbol-case
  "Test that symbols are uppercased."
  (is (eq 'foo (fol-read-from-string-clj "FOO")))
  (is (eq 'bar (fol-read-from-string-clj "BaR")))
  (is (eq 'baz-qux (fol-read-from-string-clj "baz-qux"))))

(test reader-symbol-special-chars
  "Test symbols with special characters."
  (is (eq '+ (fol-read-from-string-clj "+")))
  (is (eq '- (fol-read-from-string-clj "-")))
  (is (eq '* (fol-read-from-string-clj "*")))
  (is (eq '/ (fol-read-from-string-clj "/")))
  (is (eq '< (fol-read-from-string-clj "<")))
  (is (eq '> (fol-read-from-string-clj ">")))
  (is (eq '= (fol-read-from-string-clj "="))))

(test reader-symbol-hyphenated
  "Test hyphenated symbols."
  (is (eq 'my-function (fol-read-from-string-clj "my-function")))
  (is (eq 'foo-bar-baz (fol-read-from-string-clj "foo-bar-baz"))))

(test reader-symbol-with-numbers
  "Test symbols containing numbers."
  (is (eq 'foo123 (fol-read-from-string-clj "foo123")))
  (is (eq 'x1y2z3 (fol-read-from-string-clj "x1y2z3"))))

;;; ---------------------------------------------------------------------------
;;; Reader Number Tests
;;; ---------------------------------------------------------------------------

(test reader-number-integer
  "Test reading integer numbers."
  (is (= 42 (fol-read-from-string-clj "42")))
  (is (= 0 (fol-read-from-string-clj "0")))
  (is (= -123 (fol-read-from-string-clj "-123")))
  (is (= 1000000 (fol-read-from-string-clj "1000000"))))

(test reader-number-float
  "Test reading floating point numbers."
  (is (= 3.14d0 (fol-read-from-string-clj "3.14")))
  (is (= -2.5d0 (fol-read-from-string-clj "-2.5")))
  (is (= 1.0d0 (fol-read-from-string-clj "1.0")))
  (is (= 0.001d0 (fol-read-from-string-clj "0.001"))))

(test reader-number-ratio
  "Test reading rational numbers."
  (is (= 1/2 (fol-read-from-string-clj "1/2")))
  (is (= 3/4 (fol-read-from-string-clj "3/4")))
  (is (= -2/3 (fol-read-from-string-clj "-2/3")))
  (is (= 22/7 (fol-read-from-string-clj "22/7"))))

(test reader-number-scientific
  "Test reading numbers in scientific notation."
  (is (= 1.0d10 (fol-read-from-string-clj "1e10")))
  (is (= 1.5d-3 (fol-read-from-string-clj "1.5e-3"))))

;;; ---------------------------------------------------------------------------
;;; Reader String Tests
;;; ---------------------------------------------------------------------------

(test reader-string-basic
  "Test reading basic strings."
  (is (string= "hello" (fol-read-from-string-clj "\"hello\"")))
  (is (string= "" (fol-read-from-string-clj "\"\"")))
  (is (string= "foo bar" (fol-read-from-string-clj "\"foo bar\""))))

(test reader-string-escapes
  "Test reading strings with escape sequences."
  (is (string= (format nil "hello~%world") (fol-read-from-string-clj "\"hello\\nworld\"")))
  (is (string= (format nil "tab~chere" #\Tab) (fol-read-from-string-clj "\"tab\\there\"")))
  (is (string= "quote\"test" (fol-read-from-string-clj "\"quote\\\"test\"")))
  (is (string= "back\\slash" (fol-read-from-string-clj "\"back\\\\slash\"")))
  (is (string= (format nil "carriage~creturn" #\Return) (fol-read-from-string-clj "\"carriage\\rreturn\""))))

(test reader-string-preserves-whitespace
  "Test that strings preserve internal whitespace."
  (is (string= "  spaces  " (fol-read-from-string-clj "\"  spaces  \"")))
  (is (string= "a b c" (fol-read-from-string-clj "\"a b c\""))))

;;; ---------------------------------------------------------------------------
;;; Reader List Tests
;;; ---------------------------------------------------------------------------

(test reader-list-empty
  "Test reading empty lists."
  (is (null (fol-read-from-string-clj "()"))))

(test reader-list-simple
  "Test reading simple lists."
  (is (equal '(a b c) (fol-read-from-string-clj "(a b c)")))
  (is (equal '(1 2 3) (fol-read-from-string-clj "(1 2 3)"))))

(test reader-list-nested
  "Test reading nested lists."
  (is (equal '((a b) (c d)) (fol-read-from-string-clj "((a b) (c d))")))
  (is (equal '(1 (2 3) 4) (fol-read-from-string-clj "(1 (2 3) 4)")))
  (is (equal '(((deep))) (fol-read-from-string-clj "(((deep)))"))))

(test reader-list-mixed
  "Test reading lists with mixed elements."
  (is (equal '(foo 42 "bar") (fol-read-from-string-clj "(foo 42 \"bar\")")))
  (is (equal '(1 two 3.0d0) (fol-read-from-string-clj "(1 two 3.0)"))))

(test reader-list-whitespace
  "Test that lists handle various whitespace."
  (is (equal '(a b c) (fol-read-from-string-clj "( a  b   c )")))
  (is (equal '(a b c) (fol-read-from-string-clj "(a
b
c)"))))

;;; ---------------------------------------------------------------------------
;;; Reader Vector Tests
;;; ---------------------------------------------------------------------------

(test reader-vector-empty
  "Test reading empty vectors."
  (let ((v (fol-read-from-string-clj "[]")))
    (is (vectorp v))
    (is (= 0 (length v)))))

(test reader-vector-simple
  "Test reading simple vectors."
  (let ((v (fol-read-from-string-clj "[1 2 3]")))
    (is (vectorp v))
    (is (= 3 (length v)))
    (is (= 1 (aref v 0)))
    (is (= 2 (aref v 1)))
    (is (= 3 (aref v 2)))))

(test reader-vector-mixed
  "Test reading vectors with mixed elements."
  (let ((v (fol-read-from-string-clj "[foo 42 \"bar\"]")))
    (is (vectorp v))
    (is (eq 'foo (aref v 0)))
    (is (= 42 (aref v 1)))
    (is (string= "bar" (aref v 2)))))

(test reader-vector-nested
  "Test reading nested vectors."
  (let ((v (fol-read-from-string-clj "[[1 2] [3 4]]")))
    (is (vectorp v))
    (is (= 2 (length v)))
    (is (vectorp (aref v 0)))
    (is (= 1 (aref (aref v 0) 0)))
    (is (= 4 (aref (aref v 1) 1)))))

;;; ---------------------------------------------------------------------------
;;; Reader Map Tests
;;; ---------------------------------------------------------------------------

(test reader-map-empty
  "Test reading empty maps."
  (let ((m (fol-read-from-string-clj "{}")))
    (is (hash-table-p m))
    (is (= 0 (hash-table-count m)))))

(test reader-map-simple
  "Test reading simple maps."
  (let ((m (fol-read-from-string-clj "{:a 1 :b 2}")))
    (is (hash-table-p m))
    (is (= 2 (hash-table-count m)))
    (is (= 1 (gethash :a m)))
    (is (= 2 (gethash :b m)))))

(test reader-map-string-keys
  "Test reading maps with string keys."
  (let ((m (fol-read-from-string-clj "{\"foo\" 1 \"bar\" 2}")))
    (is (hash-table-p m))
    (is (= 1 (gethash "foo" m)))
    (is (= 2 (gethash "bar" m)))))

(test reader-map-nested-values
  "Test reading maps with nested values."
  (let ((m (fol-read-from-string-clj "{:a [1 2] :b (3 4)}")))
    (is (hash-table-p m))
    (is (vectorp (gethash :a m)))
    (is (listp (gethash :b m)))))

(test reader-map-odd-elements-error
  "Test that maps with odd number of elements signal an error."
  (signals error
    (fol-read-from-string-clj "{:a 1 :b}")))

;;; ---------------------------------------------------------------------------
;;; Reader Set Tests
;;; ---------------------------------------------------------------------------

(test reader-set-empty
  "Test reading empty sets."
  (let ((s (fol-read-from-string-clj "#{}")))
    (is (consp s))
    (is (eq 'set (car s)))
    (is (hash-table-p (cdr s)))
    (is (= 0 (hash-table-count (cdr s))))))

(test reader-set-simple
  "Test reading simple sets."
  (let* ((s (fol-read-from-string-clj "#{1 2 3}"))
         (ht (cdr s)))
    (is (eq 'set (car s)))
    (is (= 3 (hash-table-count ht)))
    (is (eq t (gethash 1 ht)))
    (is (eq t (gethash 2 ht)))
    (is (eq t (gethash 3 ht)))))

(test reader-set-symbols
  "Test reading sets with symbols."
  (let* ((s (fol-read-from-string-clj "#{foo bar baz}"))
         (ht (cdr s)))
    (is (= 3 (hash-table-count ht)))
    (is (eq t (gethash 'foo ht)))
    (is (eq t (gethash 'bar ht)))
    (is (eq t (gethash 'baz ht)))))

(test reader-set-duplicates
  "Test that sets handle duplicates."
  (let* ((s (fol-read-from-string-clj "#{1 2 1 3 2}"))
         (ht (cdr s)))
    (is (eq 'set (car s)))
    ;; All values are T
    (is (eq t (gethash 1 ht)))
    (is (eq t (gethash 2 ht)))
    (is (eq t (gethash 3 ht)))))

;;; ---------------------------------------------------------------------------
;;; Reader Multiset (Bag) Tests
;;; ---------------------------------------------------------------------------

(test reader-multiset-empty
  "Test reading empty multisets."
  (let ((ms (fol-read-from-string-clj "#M{}")))
    (is (consp ms))
    (is (eq 'multiset (car ms)))
    (is (hash-table-p (cdr ms)))
    (is (= 0 (hash-table-count (cdr ms))))))

(test reader-multiset-simple
  "Test reading simple multisets."
  (let* ((ms (fol-read-from-string-clj "#M{1 2 3}"))
         (ht (cdr ms)))
    (is (eq 'multiset (car ms)))
    (is (= 3 (hash-table-count ht)))
    (is (= 1 (gethash 1 ht)))
    (is (= 1 (gethash 2 ht)))
    (is (= 1 (gethash 3 ht)))))

(test reader-multiset-with-duplicates
  "Test reading multisets with duplicate elements."
  (let* ((ms (fol-read-from-string-clj "#M{1 2 2 3 3 3}"))
         (ht (cdr ms)))
    (is (eq 'multiset (car ms)))
    (is (= 3 (hash-table-count ht)))
    (is (= 1 (gethash 1 ht)))
    (is (= 2 (gethash 2 ht)))
    (is (= 3 (gethash 3 ht)))))

(test reader-multiset-symbols
  "Test reading multisets with symbols."
  (let* ((ms (fol-read-from-string-clj "#M{foo bar foo baz foo}"))
         (ht (cdr ms)))
    (is (eq 'multiset (car ms)))
    (is (= 3 (hash-table-count ht)))
    (is (= 3 (gethash 'foo ht)))
    (is (= 1 (gethash 'bar ht)))
    (is (= 1 (gethash 'baz ht)))))

(test reader-multiset-strings
  "Test reading multisets with strings."
  (let* ((ms (fol-read-from-string-clj "#M{\"a\" \"b\" \"a\" \"c\" \"a\"}"))
         (ht (cdr ms)))
    (is (eq 'multiset (car ms)))
    (is (= 3 (gethash "a" ht)))
    (is (= 1 (gethash "b" ht)))
    (is (= 1 (gethash "c" ht)))))

(test reader-multiset-error-no-brace
  "Test that #M without { signals an error."
  (signals error
    (fol-read-from-string-clj "#M foo")))

;;; ---------------------------------------------------------------------------
;;; Reader Quote Tests
;;; ---------------------------------------------------------------------------

(test reader-quote-symbol
  "Test quoting symbols."
  (is (equal '(quote foo) (fol-read-from-string-clj "'foo"))))

(test reader-quote-list
  "Test quoting lists."
  (is (equal '(quote (1 2 3)) (fol-read-from-string-clj "'(1 2 3)"))))

(test reader-syntax-quote
  "Test syntax quoting."
  (is (equal '(syntax-quote foo) (fol-read-from-string-clj "`foo")))
  (is (equal '(syntax-quote (1 2 3)) (fol-read-from-string-clj "`(1 2 3)"))))

(test reader-unquote
  "Test unquoting."
  (is (equal '(unquote foo) (fol-read-from-string-clj "~foo")))
  (is (equal '(unquote (1 2 3)) (fol-read-from-string-clj "~(1 2 3)"))))

(test reader-unquote-splicing
  "Test unquote splicing."
  (is (equal '(unquote-splicing foo) (fol-read-from-string-clj "~@foo")))
  (is (equal '(unquote-splicing (1 2 3)) (fol-read-from-string-clj "~@(1 2 3)"))))

;;; ---------------------------------------------------------------------------
;;; Reader Deref Tests
;;; ---------------------------------------------------------------------------

(test reader-deref-symbol
  "Test dereferencing symbols."
  (is (equal '(deref foo) (fol-read-from-string-clj "@foo"))))

(test reader-deref-expression
  "Test dereferencing expressions."
  (is (equal '(deref (atom 42)) (fol-read-from-string-clj "@(atom 42)"))))

;;; ---------------------------------------------------------------------------
;;; Reader Metadata Tests
;;; ---------------------------------------------------------------------------

(test reader-metadata-keyword
  "Test metadata with keyword."
  (is (equal '(with-meta bar :foo) (fol-read-from-string-clj "^:foo bar"))))

(test reader-metadata-map
  "Test metadata with map."
  (let ((result (fol-read-from-string-clj "^{:type :int} x")))
    (is (eq 'with-meta (car result)))
    (is (eq 'x (cadr result)))))

;;; ---------------------------------------------------------------------------
;;; Reader Dispatch Macro Tests
;;; ---------------------------------------------------------------------------

(test reader-regex
  "Test reading regex literals."
  (is (equal '(regex "[a-z]+") (fol-read-from-string-clj "#\"[a-z]+\""))))

(test reader-var-quote
  "Test reading var quotes."
  (is (equal '(var foo) (fol-read-from-string-clj "#'foo")))
  (is (equal '(var my-ns/bar) (fol-read-from-string-clj "#'my-ns/bar"))))

(test reader-anonymous-function
  "Test reading anonymous function literals."
  (is (equal '(fn (+ % 1)) (fol-read-from-string-clj "#(+ % 1)")))
  (is (equal '(fn (* %1 %2)) (fol-read-from-string-clj "#(* %1 %2)"))))

(test reader-ignore
  "Test reading ignore forms."
  (let ((result (with-input-from-string (s "#_ foo bar")
                  (fol-read s t nil *clojure-readtable*))))
    (is (eq 'bar result))))

(test reader-reader-conditional
  "Test reading reader conditionals."
  (is (equal '(reader-conditional (:clj 1 :cljs 2))
             (fol-read-from-string-clj "#?(:clj 1 :cljs 2)"))))

(test reader-symbolic-value
  "Test reading symbolic values."
  (is (equal '(symbolic-value |Inf|) (fol-read-from-string-clj "##Inf")))
  (is (equal '(symbolic-value |NaN|) (fol-read-from-string-clj "##NaN"))))

;;; ---------------------------------------------------------------------------
;;; Reader Comment Tests
;;; ---------------------------------------------------------------------------

(test reader-comment-line
  "Test reading line comments."
  (let ((result (with-input-from-string (s "; this is a comment
foo")
                  (fol-read s t nil *clojure-readtable*))))
    (is (eq 'foo result))))

(test reader-comment-inline
  "Test reading inline comments."
  (let ((result (with-input-from-string (s "(1 ; comment
 2 3)")
                  (fol-read s t nil *clojure-readtable*))))
    (is (equal '(1 2 3) result))))

(test reader-comment-multiple
  "Test reading multiple line comments."
  (let ((result (with-input-from-string (s "; first
; second
; third
42")
                  (fol-read s t nil *clojure-readtable*))))
    (is (= 42 result))))

;;; ---------------------------------------------------------------------------
;;; Reader Complex Expression Tests
;;; ---------------------------------------------------------------------------

(test reader-complex-nested
  "Test reading complex nested expressions."
  (let ((expr (fol-read-from-string-clj
               "{:name \"test\" :data [1 2 #{3 4}] :flags #{:a :b}}")))
    (is (hash-table-p expr))
    (is (string= "test" (gethash :name expr)))
    (is (vectorp (gethash :data expr)))
    (let ((flags (gethash :flags expr)))
      (is (eq 'set (car flags))))))

(test reader-clojure-like-code
  "Test reading Clojure-like code."
  (let ((code (fol-read-from-string-clj "(defn add [x y] (+ x y))")))
    (is (eq 'defn (car code)))
    (is (eq 'add (cadr code)))
    (is (vectorp (caddr code)))))

(test reader-deeply-nested
  "Test reading deeply nested structures."
  (let ((result (fol-read-from-string-clj "((((((deep))))))")))
    (is (equal '((((((deep)))))) result))))

;;; ---------------------------------------------------------------------------
;;; Reader Whitespace Handling Tests
;;; ---------------------------------------------------------------------------

(test reader-whitespace-handling
  "Test that various whitespace is handled correctly."
  (is (equal '(a b c) (fol-read-from-string-clj "  (  a   b  c  )  ")))
  (is (equal '(a b c) (fol-read-from-string-clj "(a
b
c)"))))

(test reader-tab-handling
  "Test that tabs are handled as whitespace."
  (is (equal '(a b c) (fol-read-from-string-clj "(a	b	c)"))))

;;; ---------------------------------------------------------------------------
;;; Reader Multiple Forms Tests
;;; ---------------------------------------------------------------------------

(test reader-multiple-reads
  "Test reading multiple expressions from the same stream."
  (with-input-from-string (s "foo bar baz")
    (is (eq 'foo (fol-read s t nil *clojure-readtable*)))
    (is (eq 'bar (fol-read s t nil *clojure-readtable*)))
    (is (eq 'baz (fol-read s t nil *clojure-readtable*)))))

(test reader-multiple-forms-mixed
  "Test reading multiple forms of different types."
  (with-input-from-string (s "42 \"hello\" (a b)")
    (is (= 42 (fol-read s t nil *clojure-readtable*)))
    (is (string= "hello" (fol-read s t nil *clojure-readtable*)))
    (is (equal '(a b) (fol-read s t nil *clojure-readtable*)))))

;;; ---------------------------------------------------------------------------
;;; Reader EOF Handling Tests
;;; ---------------------------------------------------------------------------

(test reader-eof-with-default
  "Test EOF handling with default value."
  (with-input-from-string (s "")
    (is (eq :eof (fol-read s nil :eof *clojure-readtable*)))))

(test reader-eof-error
  "Test that EOF signals error when requested."
  (signals error
    (with-input-from-string (s "")
      (fol-read s t nil *clojure-readtable*))))

;;; ---------------------------------------------------------------------------
;;; Reader fol-read-from-string Tests
;;; ---------------------------------------------------------------------------

(test reader-from-string-returns-position
  "Test that fol-read-from-string returns position."
  (multiple-value-bind (result pos)
      (fol-read-from-string "foo bar" t nil *clojure-readtable*)
    (is (eq 'foo result))
    (is (= 3 pos))))

(test reader-from-string-position-after-whitespace
  "Test position after reading with whitespace."
  (multiple-value-bind (result pos)
      (fol-read-from-string "  42  rest" t nil *clojure-readtable*)
    (is (= 42 result))
    (is (= 4 pos))))

;;; ---------------------------------------------------------------------------
;;; Reader with-readtable Tests
;;; ---------------------------------------------------------------------------

(test reader-with-readtable
  "Test with-readtable function."
  (let ((result (with-readtable *clojure-readtable* "(a b c)")))
    (is (equal '(a b c) result))))

;;; ---------------------------------------------------------------------------
;;; Reader Edge Cases
;;; ---------------------------------------------------------------------------

(test reader-empty-string-in-list
  "Test reading list containing empty string."
  (is (equal '("" foo "") (fol-read-from-string-clj "(\"\" foo \"\")"))))

(test reader-keywords
  "Test reading keywords."
  (is (eq :foo (fol-read-from-string-clj ":foo")))
  (is (eq :bar-baz (fol-read-from-string-clj ":bar-baz"))))

(test reader-nil-in-structures
  "Test reading nil in various structures."
  (is (equal '(nil) (fol-read-from-string-clj "(nil)")))
  (let ((m (fol-read-from-string-clj "{:key nil}")))
    (is (eq nil (gethash :key m)))))

;;; ---------------------------------------------------------------------------
;;; Reader Anonymous Function #() Tests
;;; ---------------------------------------------------------------------------

(test reader-fn-literal-no-args
  "Test reading anonymous function with no arguments."
  (let ((form (fol-read-from-string-clj "#(+ 1 2)")))
    ;; Should produce (fn [] (+ 1 2))
    (is (eq 'fn (cl:first form)))
    (is (<vector>? (cl:second form)))
    (is (= 0 (size (cl:second form))))))

(test reader-fn-literal-single-arg
  "Test reading anonymous function with single arg (%)."
  (let ((form (fol-read-from-string-clj "#(+ % 1)")))
    ;; Should produce (fn [arg] (+ arg 1))
    (is (eq 'fn (cl:first form)))
    (is (<vector>? (cl:second form)))
    (is (= 1 (size (cl:second form))))))

(test reader-fn-literal-percent-one
  "Test reading anonymous function with %1."
  (let ((form (fol-read-from-string-clj "#(+ %1 10)")))
    ;; Should produce (fn [arg1] (+ arg1 10))
    (is (eq 'fn (cl:first form)))
    (is (<vector>? (cl:second form)))
    (is (= 1 (size (cl:second form))))))

(test reader-fn-literal-two-args
  "Test reading anonymous function with two args."
  (let ((form (fol-read-from-string-clj "#(+ %1 %2)")))
    ;; Should produce (fn [arg1 arg2] (+ arg1 arg2))
    (is (eq 'fn (cl:first form)))
    (is (<vector>? (cl:second form)))
    (is (= 2 (size (cl:second form))))))

(test reader-fn-literal-sparse-args
  "Test reading anonymous function with non-sequential args."
  (let ((form (fol-read-from-string-clj "#(+ %1 %3)")))
    ;; Should produce (fn [arg1 arg2 arg3] (+ arg1 arg3))
    ;; even though %2 is not used, it needs to be in params
    (is (eq 'fn (cl:first form)))
    (is (<vector>? (cl:second form)))
    (is (= 3 (size (cl:second form))))))

(test reader-fn-literal-rest-args
  "Test reading anonymous function with rest args."
  (let ((form (fol-read-from-string-clj "#(apply + %&)")))
    ;; Should produce (fn [& rest] (apply + rest))
    (is (eq 'fn (cl:first form)))
    (is (<vector>? (cl:second form)))
    ;; params vector should contain & and a rest symbol
    (is (>= (size (cl:second form)) 2))))

(test reader-fn-literal-mixed-args
  "Test reading anonymous function with positional and rest args."
  (let ((form (fol-read-from-string-clj "#(apply + %1 %&)")))
    ;; Should produce (fn [arg1 & rest] (apply + arg1 rest))
    (is (eq 'fn (cl:first form)))
    (is (<vector>? (cl:second form)))
    ;; Should have at least: arg1, &, rest
    (is (>= (size (cl:second form)) 3))))

;;; ---------------------------------------------------------------------------
;;; Reader String Extended Escape Tests
;;; ---------------------------------------------------------------------------

(test reader-string-escape-backspace
  "Test reading string with backspace escape."
  (is (char= #\Backspace (char (fol-read-from-string-clj "\"\\b\"") 0))))

(test reader-string-escape-formfeed
  "Test reading string with form feed escape."
  (is (char= #\Page (char (fol-read-from-string-clj "\"\\f\"") 0))))

(test reader-string-escape-all-standard
  "Test reading string with all standard escape sequences."
  (let ((s (fol-read-from-string-clj "\"\\b\\f\\n\\t\\r\\\\\\\"\"")))
    (is (= 7 (length s)))
    (is (char= #\Backspace (char s 0)))
    (is (char= #\Page (char s 1)))
    (is (char= #\Newline (char s 2)))
    (is (char= #\Tab (char s 3)))
    (is (char= #\Return (char s 4)))
    (is (char= #\\ (char s 5)))
    (is (char= #\" (char s 6)))))

(test reader-string-escape-octal
  "Test reading string with octal escape sequences."
  ;; \101 = 65 = 'A'
  (is (string= "A" (fol-read-from-string-clj "\"\\101\"")))
  ;; \141 = 97 = 'a'
  (is (string= "a" (fol-read-from-string-clj "\"\\141\"")))
  ;; \60 = 48 = '0'
  (is (string= "0" (fol-read-from-string-clj "\"\\60\"")))
  ;; \7 = 7 = BEL
  (is (char= (code-char 7) (char (fol-read-from-string-clj "\"\\7\"") 0))))

(test reader-string-escape-octal-partial
  "Test reading string with partial octal sequences."
  ;; \1 followed by non-octal should only consume the 1
  (is (string= (format nil "~CA" (code-char 1)) (fol-read-from-string-clj "\"\\1A\"")))
  ;; \77 = 63 = '?'
  (is (string= "?" (fol-read-from-string-clj "\"\\77\""))))

(test reader-string-escape-unicode
  "Test reading string with Unicode escape sequences."
  ;; \u0041 = 65 = 'A'
  (is (string= "A" (fol-read-from-string-clj "\"\\u0041\"")))
  ;; \u03BB = 955 = Greek lambda
  (is (char= (code-char 955) (char (fol-read-from-string-clj "\"\\u03BB\"") 0)))
  ;; \u0048\u0069 = "Hi"
  (is (string= "Hi" (fol-read-from-string-clj "\"\\u0048\\u0069\""))))

(test reader-string-escape-unicode-case-insensitive
  "Test that Unicode escapes are case-insensitive."
  (is (string= "A" (fol-read-from-string-clj "\"\\u0041\"")))
  (is (string= "A" (fol-read-from-string-clj "\"\\U0041\""))))

(test reader-string-escape-mixed
  "Test reading string with mixed escape types."
  ;; "A\tB" using unicode and standard escape
  (is (string= (format nil "A~CB" #\Tab)
               (fol-read-from-string-clj "\"\\u0041\\tB\""))))

;;; ---------------------------------------------------------------------------
;;; Reader Number Format Tests
;;; ---------------------------------------------------------------------------

(test reader-number-hex-0x
  "Test reading hexadecimal numbers with 0x prefix."
  (is (= 255 (fol-read-from-string-clj "0xff")))
  (is (= 255 (fol-read-from-string-clj "0xFF")))
  (is (= 255 (fol-read-from-string-clj "0XFF")))
  (is (= 16 (fol-read-from-string-clj "0x10")))
  (is (= 256 (fol-read-from-string-clj "0x100")))
  (is (= 65535 (fol-read-from-string-clj "0xFFFF"))))

(test reader-number-hex-radix
  "Test reading hexadecimal numbers with 16r prefix."
  (is (= 255 (fol-read-from-string-clj "16rff")))
  (is (= 255 (fol-read-from-string-clj "16rFF")))
  ;; 16rfeFe = 0xfefe = 15*4096 + 14*256 + 15*16 + 14 = 65278
  (is (= 65278 (fol-read-from-string-clj "16rfeFe")))
  (is (= 4095 (fol-read-from-string-clj "16rfff"))))

(test reader-number-octal-leading-zero
  "Test reading octal numbers with leading zero."
  (is (= 7 (fol-read-from-string-clj "07")))
  (is (= 15 (fol-read-from-string-clj "017")))
  (is (= 63 (fol-read-from-string-clj "077")))
  (is (= 511 (fol-read-from-string-clj "0777"))))

(test reader-number-octal-radix
  "Test reading octal numbers with 8r prefix."
  (is (= 4012 (fol-read-from-string-clj "8r7654")))
  (is (= 7 (fol-read-from-string-clj "8r7")))
  (is (= 63 (fol-read-from-string-clj "8r77"))))

(test reader-number-binary
  "Test reading binary numbers with 2r prefix."
  (is (= 11 (fol-read-from-string-clj "2r1011")))
  (is (= 0 (fol-read-from-string-clj "2r0")))
  (is (= 1 (fol-read-from-string-clj "2r1")))
  (is (= 255 (fol-read-from-string-clj "2r11111111")))
  (is (= 170 (fol-read-from-string-clj "2r10101010"))))

(test reader-number-base-36
  "Test reading base-36 numbers."
  ;; 36rZ = 35
  (is (= 35 (fol-read-from-string-clj "36rZ")))
  ;; 36r10 = 36
  (is (= 36 (fol-read-from-string-clj "36r10")))
  ;; Test CRAZY in base 36: C=12, R=27, A=10, Z=35, Y=34
  ;; = 12*36^4 + 27*36^3 + 10*36^2 + 35*36 + 34
  ;; = 12*1679616 + 27*46656 + 10*1296 + 35*36 + 34
  ;; = 20155392 + 1259712 + 12960 + 1260 + 34
  ;; = 21429358
  (is (= 21429358 (fol-read-from-string-clj "36rCRAZY"))))

(test reader-number-various-bases
  "Test reading numbers in various bases."
  ;; Base 3
  (is (= 8 (fol-read-from-string-clj "3r22")))  ; 2*3 + 2 = 8
  ;; Base 7
  (is (= 50 (fol-read-from-string-clj "7r101")))  ; 1*49 + 0*7 + 1 = 50
  ;; Base 12
  (is (= 23 (fol-read-from-string-clj "12r1B")))  ; 1*12 + 11 = 23
  ;; Base 20: J=19 in base 20, so 19*20 + 9 = 389
  (is (= 389 (fol-read-from-string-clj "20rJ9"))))

(test reader-number-zero-special-cases
  "Test that zero handling is correct."
  ;; Just "0" should be 0 (not octal)
  (is (= 0 (fol-read-from-string-clj "0")))
  ;; "00" should be octal 0
  (is (= 0 (fol-read-from-string-clj "00")))
  ;; 0x0 should be hex 0
  (is (= 0 (fol-read-from-string-clj "0x0"))))

(test reader-number-decimal-not-octal
  "Test that numbers starting with 0 but containing 8 or 9 are not read as octal."
  ;; 09 contains 9 which is not octal, should not parse as octal
  ;; This should fall back to decimal parsing or be read as symbol
  (let ((result (fol-read-from-string-clj "09")))
    ;; Since 09 has a non-octal digit after leading 0,
    ;; it should fall back to standard CL parsing (as 9 decimal)
    (is (= 9 result))))
