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
