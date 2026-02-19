;;; FOL Compiler Tests - Reader and Readtable Tests

(in-package :fol.compiler.tests)

(in-suite reader-tests)

;;; ---------------------------------------------------------------------------
;;; Readtable existence
;;; ---------------------------------------------------------------------------

(test fol-readtable-exists
  "*fol-readtable* is bound to a readtable."
  (is (readtablep fol.compiler.reader:*fol-readtable*)))

(test fol-readtable-is-not-standard
  "*fol-readtable* is distinct from the standard readtable."
  (is (not (eq fol.compiler.reader:*fol-readtable*
               (copy-readtable nil)))))

;;; ---------------------------------------------------------------------------
;;; Vector reader macro: [...]
;;; ---------------------------------------------------------------------------

(test read-vector-empty
  "[] reads as an empty <vector>."
  (let ((v (fol.compiler.reader:fol-read-from-string "[]")))
    (is (eq t (fol.compiler.collections:<vector>? v)))
    (is (= 0 (fol.compiler.collections:collection-size v)))))

(test read-vector-literals
  "[1 2 3] reads as a <vector> of 1, 2, 3."
  (let ((v (fol.compiler.reader:fol-read-from-string "[1 2 3]")))
    (is (eq t (fol.compiler.collections:<vector>? v)))
    (is (= 3 (fol.compiler.collections:collection-size v)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq v)))))

(test read-vector-with-keywords
  "[:a :b :c] reads keywords into a vector."
  (let ((v (fol.compiler.reader:fol-read-from-string "[:a :b :c]")))
    (is (eq t (fol.compiler.collections:<vector>? v)))
    (is (equal '(:a :b :c) (fol.compiler.collections:collection-seq v)))))

(test read-vector-nested
  "[[1 2] [3 4]] reads nested vectors."
  (let ((v (fol.compiler.reader:fol-read-from-string "[[1 2] [3 4]]")))
    (is (eq t (fol.compiler.collections:<vector>? v)))
    (is (= 2 (fol.compiler.collections:collection-size v)))
    (let ((inner (first (fol.compiler.collections:collection-seq v))))
      (is (eq t (fol.compiler.collections:<vector>? inner)))
      (is (equal '(1 2) (fol.compiler.collections:collection-seq inner))))))

;;; ---------------------------------------------------------------------------
;;; Dict reader macro: {...}
;;; ---------------------------------------------------------------------------

(test read-dict-empty
  "{} reads as an empty <dict>."
  (let ((d (fol.compiler.reader:fol-read-from-string "{}")))
    (is (eq t (fol.compiler.collections:<dict>? d)))
    (is (= 0 (fol.compiler.collections:collection-size d)))))

(test read-dict-simple
  "{:a 1 :b 2} reads as a <dict>."
  (let ((d (fol.compiler.reader:fol-read-from-string "{:a 1 :b 2}")))
    (is (eq t (fol.compiler.collections:<dict>? d)))
    (is (= 2 (fol.compiler.collections:collection-size d)))))

(test read-dict-odd-error
  "{:a 1 :b} signals an error for odd number of forms."
  (signals error
    (fol.compiler.reader:fol-read-from-string "{:a 1 :b}")))

;;; ---------------------------------------------------------------------------
;;; Set reader macro: #{...}
;;; ---------------------------------------------------------------------------

(test read-set-empty
  "#{} reads as an empty <set>."
  (let ((s (fol.compiler.reader:fol-read-from-string "#{}")))
    (is (eq t (fol.compiler.collections:<set>? s)))
    (is (= 0 (fol.compiler.collections:collection-size s)))))

(test read-set-simple
  "#{1 2 3} reads as a <set> of 1, 2, 3."
  (let ((s (fol.compiler.reader:fol-read-from-string "#{1 2 3}")))
    (is (eq t (fol.compiler.collections:<set>? s)))
    (is (= 3 (fol.compiler.collections:collection-size s)))))

;;; ---------------------------------------------------------------------------
;;; Bag reader macro: #M{...}
;;; ---------------------------------------------------------------------------

(test read-bag-empty
  "#M{} reads as an empty <bag>."
  (let ((b (fol.compiler.reader:fol-read-from-string "#M{}")))
    (is (eq t (fol.compiler.collections:<bag>? b)))
    (is (= 0 (fol.compiler.collections:collection-size b)))))

(test read-bag-with-duplicates
  "#M{1 1 2} reads as a bag with counts."
  (let ((b (fol.compiler.reader:fol-read-from-string "#M{1 1 2}")))
    (is (eq t (fol.compiler.collections:<bag>? b)))
    (is (= 3 (fol.compiler.collections:collection-size b)))))

;;; ---------------------------------------------------------------------------
;;; Deque reader macro: #Q[...]
;;; ---------------------------------------------------------------------------

(test read-deque-empty
  "#Q[] reads as an empty <deque>."
  (let ((d (fol.compiler.reader:fol-read-from-string "#Q[]")))
    (is (eq t (fol.compiler.collections:<deque>? d)))
    (is (= 0 (fol.compiler.collections:collection-size d)))))

(test read-deque-simple
  "#Q[1 2 3] reads as a <deque> of 1, 2, 3."
  (let ((d (fol.compiler.reader:fol-read-from-string "#Q[1 2 3]")))
    (is (eq t (fol.compiler.collections:<deque>? d)))
    (is (= 3 (fol.compiler.collections:collection-size d)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq d)))))

(test read-deque-with-keywords
  "#Q[:a :b :c] reads keywords into a deque."
  (let ((d (fol.compiler.reader:fol-read-from-string "#Q[:a :b :c]")))
    (is (eq t (fol.compiler.collections:<deque>? d)))
    (is (equal '(:a :b :c) (fol.compiler.collections:collection-seq d)))))

;;; ---------------------------------------------------------------------------
;;; Regex reader macro: #"..."
;;; ---------------------------------------------------------------------------

(test read-regex-simple
  "#\"foo\" reads as a string."
  (let ((r (fol.compiler.reader:fol-read-from-string "#\"foo\"")))
    (is (stringp r))
    (is (string= "foo" r))))

(test read-regex-with-escape
  "#\"a\\.b\" reads with escape preserved."
  (let ((r (fol.compiler.reader:fol-read-from-string "#\"a\\.b\"")))
    (is (stringp r))
    (is (string= "a.b" r))))

;;; ---------------------------------------------------------------------------
;;; Ignore reader macro: #_
;;; ---------------------------------------------------------------------------

(test read-ignore-form
  "#_42 99 reads 99 (42 is discarded)."
  (let ((result (fol.compiler.reader:fol-read-from-string "#_42 99")))
    (is (= 99 result))))

;;; ---------------------------------------------------------------------------
;;; Mixed / nested collection reading
;;; ---------------------------------------------------------------------------

(test read-dict-with-vector-value
  "{:a [1 2]} reads a dict containing a vector value."
  (let* ((d (fol.compiler.reader:fol-read-from-string "{:a [1 2]}"))
         (seq (fol.compiler.collections:collection-seq d)))
    (is (eq t (fol.compiler.collections:<dict>? d)))
    (is (= 1 (length seq)))
    (let ((val (cdar seq)))
      (is (eq t (fol.compiler.collections:<vector>? val))))))

;;; ---------------------------------------------------------------------------
;;; fol-read from stream
;;; ---------------------------------------------------------------------------

(test fol-read-from-stream
  "fol-read reads from a stream."
  (with-input-from-string (s "[1 2]")
    (let ((v (fol.compiler.reader:fol-read s)))
      (is (eq t (fol.compiler.collections:<vector>? v)))
      (is (equal '(1 2) (fol.compiler.collections:collection-seq v))))))

;;; ---------------------------------------------------------------------------
;;; Numeric literal support
;;; ---------------------------------------------------------------------------

(test read-hex-lowercase
  "0xabcd reads as hexadecimal 43981."
  (let ((n (fol.compiler.reader:fol-read-from-string "0xabcd")))
    (is (integerp n))
    (is (= n 43981))))

(test read-hex-uppercase
  "0XABCD reads as hexadecimal 43981."
  (let ((n (fol.compiler.reader:fol-read-from-string "0XABCD")))
    (is (integerp n))
    (is (= n 43981))))

(test read-hex-mixed-case
  "0xAbCd reads as hexadecimal."
  (let ((n (fol.compiler.reader:fol-read-from-string "0xAbCd")))
    (is (integerp n))
    (is (= n 43981))))

(test read-hex-zero
  "0x0 reads as 0."
  (let ((n (fol.compiler.reader:fol-read-from-string "0x0")))
    (is (integerp n))
    (is (= n 0))))

(test read-hex-large
  "0xdeadbeef reads as large hex number."
  (let ((n (fol.compiler.reader:fol-read-from-string "0xdeadbeef")))
    (is (integerp n))
    (is (= n 3735928559))))

(test read-octal-lowercase
  "0o777 reads as octal 511."
  (let ((n (fol.compiler.reader:fol-read-from-string "0o777")))
    (is (integerp n))
    (is (= n 511))))

(test read-octal-uppercase
  "0O777 reads as octal 511."
  (let ((n (fol.compiler.reader:fol-read-from-string "0O777")))
    (is (integerp n))
    (is (= n 511))))

(test read-octal-zero
  "0o0 reads as 0."
  (let ((n (fol.compiler.reader:fol-read-from-string "0o0")))
    (is (integerp n))
    (is (= n 0))))

(test read-radix-binary
  "2r1010 reads as binary 10."
  (let ((n (fol.compiler.reader:fol-read-from-string "2r1010")))
    (is (integerp n))
    (is (= n 10))))

(test read-radix-hex
  "16rFF reads as hexadecimal 255."
  (let ((n (fol.compiler.reader:fol-read-from-string "16rFF")))
    (is (integerp n))
    (is (= n 255))))

(test read-radix-base36
  "36rZZ reads as base-36 1295."
  (let ((n (fol.compiler.reader:fol-read-from-string "36rZZ")))
    (is (integerp n))
    (is (= n 1295))))

(test read-radix-uppercase-r
  "16RFF reads with uppercase R."
  (let ((n (fol.compiler.reader:fol-read-from-string "16RFF")))
    (is (integerp n))
    (is (= n 255))))

(test read-radix-base8
  "8r77 reads as octal via radix notation."
  (let ((n (fol.compiler.reader:fol-read-from-string "8r77")))
    (is (integerp n))
    (is (= n 63))))

(test read-ratio-simple
  "3/4 reads as ratio."
  (let ((n (fol.compiler.reader:fol-read-from-string "3/4")))
    (is (rationalp n))
    (is (= n 3/4))))

(test read-ratio-complex
  "22/7 reads as ratio (approximation of pi)."
  (let ((n (fol.compiler.reader:fol-read-from-string "22/7")))
    (is (rationalp n))
    (is (= n 22/7))))

(test read-single-float
  "3.14f0 reads as single-float."
  (let ((n (fol.compiler.reader:fol-read-from-string "3.14f0")))
    (is (typep n 'single-float))
    (is (< (abs (- n 3.14f0)) 0.01f0))))

(test read-double-float
  "3.14d0 reads as double-float."
  (let ((n (fol.compiler.reader:fol-read-from-string "3.14d0")))
    (is (typep n 'double-float))
    (is (< (abs (- n 3.14d0)) 0.01d0))))

(test read-standard-integer
  "Regular decimal integers still work."
  (let ((n (fol.compiler.reader:fol-read-from-string "42")))
    (is (integerp n))
    (is (= n 42))))

(test read-hex-in-vector
  "[0xFF 0x10] reads hex numbers in a vector."
  (let ((v (fol.compiler.reader:fol-read-from-string "[0xFF 0x10]")))
    (is (eq t (fol.compiler.collections:<vector>? v)))
    (let ((seq (fol.compiler.collections:collection-seq v)))
      (is (= (first seq) 255))
      (is (= (second seq) 16)))))

(test read-mixed-radix-in-dict
  "{:hex 0xFF :oct 0o77 :bin 2r1010} reads mixed radix in dict."
  (let ((d (fol.compiler.reader:fol-read-from-string "{:hex 0xFF :oct 0o77 :bin 2r1010}")))
    (is (eq t (fol.compiler.collections:<dict>? d)))
    (let ((hex-val (sycamore:hash-map-find (fol.compiler.collections:storage-items d) :hex))
          (oct-val (sycamore:hash-map-find (fol.compiler.collections:storage-items d) :oct))
          (bin-val (sycamore:hash-map-find (fol.compiler.collections:storage-items d) :bin)))
      (is (= hex-val 255))
      (is (= oct-val 63))
      (is (= bin-val 10)))))

;;; ---------------------------------------------------------------------------
;;; Character literal support
;;; ---------------------------------------------------------------------------

(test read-char-single
  "\\a reads as character #\\a."
  (let ((c (fol.compiler.reader:fol-read-from-string "\\a")))
    (is (characterp c))
    (is (char= c #\a))))

(test read-char-uppercase
  "\\Z reads as character #\\Z."
  (let ((c (fol.compiler.reader:fol-read-from-string "\\Z")))
    (is (characterp c))
    (is (char= c #\Z))))

(test read-char-digit
  "\\5 reads as character #\\5."
  (let ((c (fol.compiler.reader:fol-read-from-string "\\5")))
    (is (characterp c))
    (is (char= c #\5))))

(test read-char-newline-shortcut
  "\\n reads as #\\Newline."
  (let ((c (fol.compiler.reader:fol-read-from-string "\\n")))
    (is (characterp c))
    (is (char= c #\Newline))))

(test read-char-tab-shortcut
  "\\t reads as #\\Tab."
  (let ((c (fol.compiler.reader:fol-read-from-string "\\t")))
    (is (characterp c))
    (is (char= c #\Tab))))

(test read-char-return-shortcut
  "\\r reads as #\\Return."
  (let ((c (fol.compiler.reader:fol-read-from-string "\\r")))
    (is (characterp c))
    (is (char= c #\Return))))

(test read-char-backspace-shortcut
  "\\b reads as #\\Backspace."
  (let ((c (fol.compiler.reader:fol-read-from-string "\\b")))
    (is (characterp c))
    (is (char= c #\Backspace))))

(test read-char-formfeed-shortcut
  "\\f reads as formfeed character."
  (let ((c (fol.compiler.reader:fol-read-from-string "\\f")))
    (is (characterp c))
    (is (char= c (code-char 12)))))

(test read-char-newline-named
  "\\newline reads as #\\Newline."
  (let ((c (fol.compiler.reader:fol-read-from-string "\\newline")))
    (is (characterp c))
    (is (char= c #\Newline))))

(test read-char-space-named
  "\\space reads as #\\Space."
  (let ((c (fol.compiler.reader:fol-read-from-string "\\space")))
    (is (characterp c))
    (is (char= c #\Space))))

(test read-char-tab-named
  "\\tab reads as #\\Tab."
  (let ((c (fol.compiler.reader:fol-read-from-string "\\tab")))
    (is (characterp c))
    (is (char= c #\Tab))))

(test read-char-return-named
  "\\return reads as #\\Return."
  (let ((c (fol.compiler.reader:fol-read-from-string "\\return")))
    (is (characterp c))
    (is (char= c #\Return))))

(test read-char-backspace-named
  "\\backspace reads as #\\Backspace."
  (let ((c (fol.compiler.reader:fol-read-from-string "\\backspace")))
    (is (characterp c))
    (is (char= c #\Backspace))))

(test read-char-formfeed-named
  "\\formfeed reads as formfeed character."
  (let ((c (fol.compiler.reader:fol-read-from-string "\\formfeed")))
    (is (characterp c))
    (is (char= c (code-char 12)))))

(test read-char-unicode
  "\\u0041 reads as #\\A (Unicode)."
  (let ((c (fol.compiler.reader:fol-read-from-string "\\u0041")))
    (is (characterp c))
    (is (char= c #\A))))

(test read-char-unicode-lowercase
  "\\u0061 reads as #\\a (Unicode lowercase)."
  (let ((c (fol.compiler.reader:fol-read-from-string "\\u0061")))
    (is (characterp c))
    (is (char= c #\a))))

(test read-char-in-vector
  "[\\a \\x \\z] reads characters in vector."
  (let ((v (fol.compiler.reader:fol-read-from-string "[\\a \\x \\z]")))
    (is (eq t (fol.compiler.collections:<vector>? v)))
    (let ((seq (fol.compiler.collections:collection-seq v)))
      (is (char= (first seq) #\a))
      (is (char= (second seq) #\x))
      (is (char= (third seq) #\z)))))

;;; ---------------------------------------------------------------------------
;;; Anonymous function shorthand: #(...)
;;; ---------------------------------------------------------------------------

(test read-fn-shorthand-simple
  "#(f %1) reads as (fn [%1] (f %1))."
  (let ((result (fol.compiler.reader:fol-read-from-string "#(f %1)")))
    (is (consp result))
    (is (string= "FN" (symbol-name (car result))))
    (let ((params (second result))
          (body (third result)))
      (is (fol.compiler.collections:<vector>? params))
      (let ((p-list (fol.compiler.collections:collection-seq params)))
        (is (= 1 (length p-list)))
        (is (string= "%1" (symbol-name (first p-list)))))
      ;; body should be the list (+ %1 1) if input was #(+ % 1)
      ;; wait, for #(f %1) it is (f %1)
      (is (consp body))
      (is (equal 'f (car body)))
      (is (string= "%1" (symbol-name (second body)))))))

(test read-fn-shorthand-percent
  "#(+ % 1) reads as (fn [%1] (+ %1 1))."
  (let ((result (fol.compiler.reader:fol-read-from-string "#(+ % 1)")))
    (let ((params (second result))
          (body (third result)))
      (is (string= "%1" (symbol-name (first (fol.compiler.collections:collection-seq params)))))
      (is (consp body))
      (is (equal '+ (car body)))
      (is (string= "%1" (symbol-name (second body)))))))

(test read-fn-shorthand-multi-param
  "#(+ %1 %3) reads as (fn [%1 %2 %3] (+ %1 %3))."
  (let* ((result (fol.compiler.reader:fol-read-from-string "#(+ %1 %3)"))
         (params (fol.compiler.collections:collection-seq (second result))))
    (is (= 3 (length params)))
    (is (string= "%1" (symbol-name (first params))))
    (is (string= "%2" (symbol-name (second params))))
    (is (string= "%3" (symbol-name (third params))))))

(test read-fn-shorthand-rest
  "#(f %&) reads as (fn [& %&] (f %&))."
  (let* ((result (fol.compiler.reader:fol-read-from-string "#(f %&)"))
         (params (fol.compiler.collections:collection-seq (second result))))
    (is (= 2 (length params)))
    (is (string= "&" (symbol-name (first params))))
    (is (string= "%&" (symbol-name (second params))))))

(test read-fn-shorthand-mixed
  "#(+ %1 %&) reads as (fn [%1 & %&] (+ %1 %&))."
  (let* ((result (fol.compiler.reader:fol-read-from-string "#(+ %1 %&)"))
         (params (fol.compiler.collections:collection-seq (second result))))
    (is (= 3 (length params)))
    (is (string= "%1" (symbol-name (first params))))
    (is (string= "&" (symbol-name (second params))))
    (is (string= "%&" (symbol-name (third params))))))

(test read-fn-shorthand-nested-coll
  "#([%1 %2]) reads as (fn [%1 %2] ([%1 %2]))."
  (let* ((result (fol.compiler.reader:fol-read-from-string "#([%1 %2])"))
         (params (fol.compiler.collections:collection-seq (second result)))
         (body (third result)))
    (is (= 2 (length params)))
    (is (fol.compiler.collections:<vector>? body))
    (let ((v-seq (fol.compiler.collections:collection-seq body)))
      (is (string= "%1" (symbol-name (first v-seq))))
      (is (string= "%2" (symbol-name (second v-seq)))))))
