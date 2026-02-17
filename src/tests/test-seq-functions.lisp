;;; FOL Compiler - Seq Functions Tests
;;;
;;; Tests for seq-functions.lisp: seq, sequence, keep-indexed, repeat, range,
;;; repeatedly, iterate, iteration, file-seq, line-seq, tree-seq,
;;; iterator-seq, enumeration-seq.

(in-package :fol.compiler.tests)
(in-suite seq-functions-tests)

;;; Aliases for brevity
(defun v (&rest items)
  (apply #'fol.compiler.collection-functions:vector items))

(defun nth* (coll i)
  (fol.compiler.collection-functions:nth coll i))

(defun size* (coll)
  (fol.compiler.collection-functions:size coll))

;;; ---------------------------------------------------------------------------
;;; seq
;;; ---------------------------------------------------------------------------

(test seq-nil
  "seq of nil returns nil."
  (is (null (fol.compiler.seq-functions:seq nil))))

(test seq-empty-vector
  "seq of empty vector returns nil."
  (is (null (fol.compiler.seq-functions:seq (v)))))

(test seq-non-empty-vector
  "seq of a non-empty vector returns a non-nil list."
  (let ((result (fol.compiler.seq-functions:seq (v 1 2 3))))
    (is (not (null result)))
    (is (= 3 (length result)))
    (is (eql 1 (first result)))))

(test seq-non-empty-set
  "seq of a non-empty set returns a non-nil list."
  (let ((result (fol.compiler.seq-functions:seq
                 (fol.compiler.collection-functions:set 1 2 3))))
    (is (not (null result)))
    (is (= 3 (length result)))))

;;; ---------------------------------------------------------------------------
;;; sequence
;;; ---------------------------------------------------------------------------

(test sequence-nil
  "sequence of nil returns an empty vector."
  (let ((result (fol.compiler.seq-functions:sequence nil)))
    (is (typep result 'fol.compiler.collections:<vector>))
    (is (= 0 (size* result)))))

(test sequence-vector
  "sequence of a vector returns a vector with same elements."
  (let ((result (fol.compiler.seq-functions:sequence (v 1 2 3))))
    (is (typep result 'fol.compiler.collections:<vector>))
    (is (= 3 (size* result)))))

(test sequence-set
  "sequence coerces a set to a vector."
  (let ((result (fol.compiler.seq-functions:sequence
                 (fol.compiler.collection-functions:set 1 2 3))))
    (is (typep result 'fol.compiler.collections:<vector>))
    (is (= 3 (size* result)))))

;;; ---------------------------------------------------------------------------
;;; keep-indexed
;;; ---------------------------------------------------------------------------

(test keep-indexed-basic
  "keep-indexed keeps non-nil results with index."
  (let ((result (fol.compiler.seq-functions:keep-indexed
                 (lambda (i x) (when (evenp i) x))
                 (v 10 20 30 40 50))))
    (is (= 3 (size* result)))
    (is (eql 10 (nth* result 0)))
    (is (eql 30 (nth* result 1)))
    (is (eql 50 (nth* result 2)))))

(test keep-indexed-all-nil
  "keep-indexed with always-nil fn returns empty vector."
  (let ((result (fol.compiler.seq-functions:keep-indexed
                 (lambda (i x) (declare (ignore i x)) nil)
                 (v 1 2 3))))
    (is (= 0 (size* result)))))

(test keep-indexed-passes-index
  "keep-indexed passes correct indices."
  (let* ((indices '())
         (result (fol.compiler.seq-functions:keep-indexed
                  (lambda (i x) (push i indices) x)
                  (v :a :b :c))))
    (declare (ignore result))
    (is (equal '(2 1 0) indices))))

;;; ---------------------------------------------------------------------------
;;; repeat
;;; ---------------------------------------------------------------------------

(test repeat-n-times
  "(repeat n x) returns a vector of x repeated n times."
  (let ((result (fol.compiler.seq-functions:repeat 3 :x)))
    (is (= 3 (size* result)))
    (is (eq :x (nth* result 0)))
    (is (eq :x (nth* result 1)))
    (is (eq :x (nth* result 2)))))

(test repeat-zero-times
  "(repeat 0 x) returns an empty vector."
  (let ((result (fol.compiler.seq-functions:repeat 0 :x)))
    (is (= 0 (size* result)))))

(test repeat-infinite-is-lazy-seq
  "(repeat x) returns a lazy-seq."
  (let ((result (fol.compiler.seq-functions:repeat :forever)))
    (is (typep result 'fol.compiler.collections:<lazy-seq>))))

(test repeat-infinite-take
  "take from an infinite (repeat x) yields n copies."
  (let* ((inf  (fol.compiler.seq-functions:repeat 42))
         (got  (fol.compiler.seq-functions:take 4 inf)))
    (is (= 4 (size* got)))
    (is (eql 42 (nth* got 0)))
    (is (eql 42 (nth* got 3)))))

;;; ---------------------------------------------------------------------------
;;; range
;;; ---------------------------------------------------------------------------

(test range-end-only
  "(range n) returns [0 1 ... n-1]."
  (let ((result (fol.compiler.seq-functions:range 5)))
    (is (= 5 (size* result)))
    (is (eql 0 (nth* result 0)))
    (is (eql 4 (nth* result 4)))))

(test range-start-end
  "(range start end) returns integers from start to end-1."
  (let ((result (fol.compiler.seq-functions:range 2 6)))
    (is (= 4 (size* result)))
    (is (eql 2 (nth* result 0)))
    (is (eql 5 (nth* result 3)))))

(test range-start-end-step
  "(range start end step) uses step."
  (let ((result (fol.compiler.seq-functions:range 0 10 2)))
    (is (= 5 (size* result)))
    (is (eql 0 (nth* result 0)))
    (is (eql 8 (nth* result 4)))))

(test range-empty
  "(range 0) returns empty vector."
  (let ((result (fol.compiler.seq-functions:range 0)))
    (is (= 0 (size* result)))))

(test range-descending
  "(range 5 0 -1) returns descending range."
  (let ((result (fol.compiler.seq-functions:range 5 0 -1)))
    (is (= 5 (size* result)))
    (is (eql 5 (nth* result 0)))
    (is (eql 1 (nth* result 4)))))

;;; ---------------------------------------------------------------------------
;;; repeatedly
;;; ---------------------------------------------------------------------------

(test repeatedly-n-calls
  "(repeatedly n fn) calls fn n times."
  (let* ((count 0)
         (result (fol.compiler.seq-functions:repeatedly
                  3 (lambda () (incf count) count))))
    (is (= 3 (size* result)))
    (is (= 3 count))
    (is (eql 1 (nth* result 0)))
    (is (eql 3 (nth* result 2)))))

(test repeatedly-zero-calls
  "(repeatedly 0 fn) returns empty vector."
  (let ((result (fol.compiler.seq-functions:repeatedly
                 0 (lambda () :never))))
    (is (= 0 (size* result)))))

(test repeatedly-infinite-is-lazy
  "(repeatedly fn) returns a lazy-seq."
  (let ((result (fol.compiler.seq-functions:repeatedly (lambda () 1))))
    (is (typep result 'fol.compiler.collections:<lazy-seq>))))

(test repeatedly-infinite-take
  "take from an infinite repeatedly yields n values."
  (let* ((n 0)
         (inf (fol.compiler.seq-functions:repeatedly (lambda () (incf n))))
         (got (fol.compiler.seq-functions:take 3 inf)))
    (is (= 3 (size* got)))))

;;; ---------------------------------------------------------------------------
;;; iterate
;;; ---------------------------------------------------------------------------

(test iterate-returns-lazy-seq
  "iterate returns a lazy-seq."
  (let ((result (fol.compiler.seq-functions:iterate #'1+ 0)))
    (is (typep result 'fol.compiler.collections:<lazy-seq>))))

(test iterate-take
  "(take n (iterate f x)) produces n values."
  (let* ((result (fol.compiler.seq-functions:take
                  5 (fol.compiler.seq-functions:iterate #'1+ 0))))
    (is (= 5 (size* result)))
    (is (eql 0 (nth* result 0)))
    (is (eql 4 (nth* result 4)))))

(test iterate-doubling
  "iterate with doubling function."
  (let* ((result (fol.compiler.seq-functions:take
                  4 (fol.compiler.seq-functions:iterate
                     (lambda (x) (* x 2)) 1))))
    (is (= 4 (size* result)))
    (is (eql 1  (nth* result 0)))
    (is (eql 2  (nth* result 1)))
    (is (eql 4  (nth* result 2)))
    (is (eql 8  (nth* result 3)))))

;;; ---------------------------------------------------------------------------
;;; iteration
;;; ---------------------------------------------------------------------------

(test iteration-basic
  "iteration steps through values until some? returns nil."
  (let ((result (fol.compiler.seq-functions:iteration
                 (lambda (k) (when (< k 5) (1+ k)))
                 :some? #'identity
                 :initk 0
                 :kf #'identity
                 :vf #'identity)))
    (is (= 5 (size* result)))
    (is (eql 1 (nth* result 0)))
    (is (eql 5 (nth* result 4)))))

(test iteration-empty
  "iteration stops immediately when some? fails on first step."
  (let ((result (fol.compiler.seq-functions:iteration
                 (lambda (k) (declare (ignore k)) nil)
                 :some? #'identity
                 :initk 0)))
    (is (= 0 (size* result)))))

;;; ---------------------------------------------------------------------------
;;; tree-seq
;;; ---------------------------------------------------------------------------

(test tree-seq-flat-list
  "tree-seq on a flat list visits each element."
  (let ((result (fol.compiler.seq-functions:tree-seq
                 #'listp #'identity '(1 2 3))))
    ;; root (1 2 3), then 1, 2, 3
    (is (= 4 (size* result)))))

(test tree-seq-nested
  "tree-seq on a nested structure visits nodes depth-first."
  (let ((result (fol.compiler.seq-functions:tree-seq
                 #'listp #'identity '(1 (2 3)))))
    ;; (1 (2 3)), 1, (2 3), 2, 3 => 5 nodes
    (is (= 5 (size* result)))))

(test tree-seq-leaf
  "tree-seq on a leaf (non-branch) returns just the root."
  (let ((result (fol.compiler.seq-functions:tree-seq
                 #'listp #'identity 42)))
    (is (= 1 (size* result)))
    (is (eql 42 (nth* result 0)))))

;;; ---------------------------------------------------------------------------
;;; iterator-seq
;;; ---------------------------------------------------------------------------

(test iterator-seq-basic
  "iterator-seq reads from a :has-next?/:next closure."
  (let* ((items (list 10 20 30))
         (iter  (lambda (msg)
                  (cond ((eq msg :has-next?) (not (null items)))
                        ((eq msg :next)      (pop items)))))
         (result (fol.compiler.seq-functions:iterator-seq iter)))
    (is (= 3 (size* result)))
    (is (eql 10 (nth* result 0)))
    (is (eql 30 (nth* result 2)))))

(test iterator-seq-empty
  "iterator-seq on an exhausted iterator returns empty vector."
  (let* ((iter   (lambda (msg) (declare (ignore msg)) nil))
         (result (fol.compiler.seq-functions:iterator-seq iter)))
    (is (= 0 (size* result)))))

;;; ---------------------------------------------------------------------------
;;; enumeration-seq
;;; ---------------------------------------------------------------------------

(test enumeration-seq-basic
  "enumeration-seq reads from a :has-more?/:next-element closure."
  (let* ((items (list :a :b :c))
         (enum  (lambda (msg)
                  (cond ((eq msg :has-more?)     (not (null items)))
                        ((eq msg :next-element)  (pop items)))))
         (result (fol.compiler.seq-functions:enumeration-seq enum)))
    (is (= 3 (size* result)))
    (is (eq :a (nth* result 0)))
    (is (eq :c (nth* result 2)))))

(test enumeration-seq-empty
  "enumeration-seq on an empty enumeration returns empty vector."
  (let* ((enum   (lambda (msg) (declare (ignore msg)) nil))
         (result (fol.compiler.seq-functions:enumeration-seq enum)))
    (is (= 0 (size* result)))))

;;; ---------------------------------------------------------------------------
;;; line-seq
;;; ---------------------------------------------------------------------------

(test line-seq-from-string-stream
  "line-seq reads all lines from a CL string stream."
  (let* ((s      (cl:make-string-input-stream
                  (cl:format nil "line1~%line2~%line3")))
         (result (fol.compiler.seq-functions:line-seq s)))
    (is (= 3 (size* result)))
    (is (string= "line1" (nth* result 0)))
    (is (string= "line3" (nth* result 2)))))

(test line-seq-empty-stream
  "line-seq on an empty stream returns empty vector."
  (let* ((s      (cl:make-string-input-stream ""))
         (result (fol.compiler.seq-functions:line-seq s)))
    (is (= 0 (size* result)))))

;;; ---------------------------------------------------------------------------
;;; sort
;;; ---------------------------------------------------------------------------

(test sort-ascending
  "(sort coll) sorts numbers ascending by default."
  (let ((result (fol.compiler.seq-functions:sort (v 3 1 4 1 5 9 2 6))))
    (is (= 8 (size* result)))
    (is (eql 1 (nth* result 0)))
    (is (eql 9 (nth* result 7)))))

(test sort-with-comparator
  "(sort coll comp) sorts with the given comparator."
  (let ((result (fol.compiler.seq-functions:sort (v 3 1 2) #'cl:>)))
    (is (= 3 (size* result)))
    (is (eql 3 (nth* result 0)))
    (is (eql 1 (nth* result 2)))))

(test sort-empty
  "(sort []) returns empty vector."
  (let ((result (fol.compiler.seq-functions:sort (v))))
    (is (= 0 (size* result)))))

;;; ---------------------------------------------------------------------------
;;; reverse
;;; ---------------------------------------------------------------------------

(test reverse-basic
  "(reverse coll) returns elements in reverse order."
  (let ((result (fol.compiler.seq-functions:reverse (v 1 2 3 4 5))))
    (is (= 5 (size* result)))
    (is (eql 5 (nth* result 0)))
    (is (eql 1 (nth* result 4)))))

(test reverse-empty
  "(reverse []) returns empty vector."
  (let ((result (fol.compiler.seq-functions:reverse (v))))
    (is (= 0 (size* result)))))

(test reverse-single
  "(reverse [x]) returns [x]."
  (let ((result (fol.compiler.seq-functions:reverse (v 42))))
    (is (= 1 (size* result)))
    (is (eql 42 (nth* result 0)))))

;;; ---------------------------------------------------------------------------
;;; map-indexed
;;; ---------------------------------------------------------------------------

(test map-indexed-basic
  "map-indexed passes correct indices."
  (let ((result (fol.compiler.seq-functions:map-indexed
                 (lambda (i x) (list i x))
                 (v :a :b :c))))
    (is (= 3 (size* result)))
    (is (equal '(0 :a) (nth* result 0)))
    (is (equal '(1 :b) (nth* result 1)))
    (is (equal '(2 :c) (nth* result 2)))))

(test map-indexed-empty
  "map-indexed on empty returns empty vector."
  (let ((result (fol.compiler.seq-functions:map-indexed
                 (lambda (i x) (declare (ignore i x)) :x)
                 (v))))
    (is (= 0 (size* result)))))

;;; ---------------------------------------------------------------------------
;;; distinct
;;; ---------------------------------------------------------------------------

(test distinct-removes-duplicates
  "distinct removes duplicate elements preserving first occurrence."
  (let ((result (fol.compiler.seq-functions:distinct (v 1 2 1 3 2 4))))
    (is (= 4 (size* result)))
    (is (eql 1 (nth* result 0)))
    (is (eql 2 (nth* result 1)))
    (is (eql 3 (nth* result 2)))
    (is (eql 4 (nth* result 3)))))

(test distinct-no-duplicates
  "distinct on already-distinct coll returns same elements."
  (let ((result (fol.compiler.seq-functions:distinct (v 1 2 3))))
    (is (= 3 (size* result)))))

(test distinct-empty
  "distinct on empty returns empty."
  (let ((result (fol.compiler.seq-functions:distinct (v))))
    (is (= 0 (size* result)))))

;;; ---------------------------------------------------------------------------
;;; dedupe
;;; ---------------------------------------------------------------------------

(test dedupe-removes-consecutive
  "dedupe removes consecutive duplicate elements."
  (let ((result (fol.compiler.seq-functions:dedupe (v 1 1 2 1 1 3 3))))
    (is (= 4 (size* result)))
    (is (eql 1 (nth* result 0)))
    (is (eql 2 (nth* result 1)))
    (is (eql 1 (nth* result 2)))
    (is (eql 3 (nth* result 3)))))

(test dedupe-no-consecutive
  "dedupe on coll without consecutive duplicates returns same elements."
  (let ((result (fol.compiler.seq-functions:dedupe (v 1 2 3))))
    (is (= 3 (size* result)))))

;;; ---------------------------------------------------------------------------
;;; flatten
;;; ---------------------------------------------------------------------------

(test flatten-nested
  "flatten recursively flattens nested vectors."
  (let ((result (fol.compiler.seq-functions:flatten
                 (v 1 (v 2 (v 3 4)) 5))))
    (is (= 5 (size* result)))
    (is (eql 1 (nth* result 0)))
    (is (eql 5 (nth* result 4)))))

(test flatten-already-flat
  "flatten on flat coll returns same elements."
  (let ((result (fol.compiler.seq-functions:flatten (v 1 2 3))))
    (is (= 3 (size* result)))))

(test flatten-empty
  "flatten on empty returns empty."
  (let ((result (fol.compiler.seq-functions:flatten (v))))
    (is (= 0 (size* result)))))

;;; ---------------------------------------------------------------------------
;;; group-by
;;; ---------------------------------------------------------------------------

(test group-by-even-odd
  "group-by groups by even?/odd? predicate."
  (let* ((result (fol.compiler.seq-functions:group-by
                  #'evenp (v 1 2 3 4 5)))
         (evens  (fol.compiler.collection-functions:get result t))
         (odds   (fol.compiler.collection-functions:get result nil)))
    (is (= 2 (size* evens)))
    (is (= 3 (size* odds)))))

(test group-by-identity
  "group-by with identity groups equal elements."
  (let* ((result (fol.compiler.seq-functions:group-by
                  #'identity (v :a :b :a)))
         (as     (fol.compiler.collection-functions:get result :a))
         (bs     (fol.compiler.collection-functions:get result :b)))
    (is (= 2 (size* as)))
    (is (= 1 (size* bs)))))

;;; ---------------------------------------------------------------------------
;;; partition-all
;;; ---------------------------------------------------------------------------

(test partition-all-exact
  "partition-all with exact multiple returns full groups."
  (let ((result (fol.compiler.seq-functions:partition-all 2 (v 1 2 3 4))))
    (is (= 2 (size* result)))
    (is (= 2 (size* (nth* result 0))))))

(test partition-all-partial-last
  "partition-all includes partial final group."
  (let ((result (fol.compiler.seq-functions:partition-all 3 (v 1 2 3 4 5))))
    (is (= 2 (size* result)))
    (is (= 3 (size* (nth* result 0))))
    (is (= 2 (size* (nth* result 1))))))

(test partition-all-empty
  "partition-all on empty returns empty."
  (let ((result (fol.compiler.seq-functions:partition-all 3 (v))))
    (is (= 0 (size* result)))))

;;; ---------------------------------------------------------------------------
;;; partition-by
;;; ---------------------------------------------------------------------------

(test partition-by-evenp
  "partition-by groups consecutive even/odd runs."
  (let ((result (fol.compiler.seq-functions:partition-by
                 #'evenp (v 1 1 2 2 3))))
    (is (= 3 (size* result)))
    (is (= 2 (size* (nth* result 0))))
    (is (= 2 (size* (nth* result 1))))
    (is (= 1 (size* (nth* result 2))))))

(test partition-by-no-consecutive
  "partition-by with no consecutive equal values creates singletons."
  (let ((result (fol.compiler.seq-functions:partition-by
                 #'identity (v 1 2 3))))
    (is (= 3 (size* result)))))

;;; ---------------------------------------------------------------------------
;;; split-at
;;; ---------------------------------------------------------------------------

(test split-at-basic
  "split-at returns two-element vector of [take drop]."
  (let* ((result (fol.compiler.seq-functions:split-at 3 (v 1 2 3 4 5)))
         (left   (nth* result 0))
         (right  (nth* result 1)))
    (is (= 2 (size* result)))
    (is (= 3 (size* left)))
    (is (= 2 (size* right)))
    (is (eql 1 (nth* left 0)))
    (is (eql 4 (nth* right 0)))))

(test split-at-zero
  "split-at 0 returns [[] coll]."
  (let* ((result (fol.compiler.seq-functions:split-at 0 (v 1 2 3)))
         (left   (nth* result 0))
         (right  (nth* result 1)))
    (is (= 0 (size* left)))
    (is (= 3 (size* right)))))

;;; ---------------------------------------------------------------------------
;;; split-with
;;; ---------------------------------------------------------------------------

(test split-with-basic
  "split-with splits at first non-matching element."
  (let* ((result (fol.compiler.seq-functions:split-with
                  #'evenp (v 2 4 1 2 3)))
         (left   (nth* result 0))
         (right  (nth* result 1)))
    (is (= 2 (size* left)))
    (is (= 3 (size* right)))
    (is (eql 2 (nth* left 0)))
    (is (eql 1 (nth* right 0)))))

;;; ---------------------------------------------------------------------------
;;; shuffle
;;; ---------------------------------------------------------------------------

(test shuffle-preserves-size
  "shuffle returns a vector with same number of elements."
  (let ((result (fol.compiler.seq-functions:shuffle (v 1 2 3 4 5))))
    (is (= 5 (size* result)))))

(test shuffle-preserves-elements
  "shuffle contains same elements (sorted to compare)."
  (let* ((original (v 1 2 3 4 5))
         (shuffled (fol.compiler.seq-functions:shuffle original))
         (sorted   (fol.compiler.seq-functions:sort shuffled)))
    (is (eql 1 (nth* sorted 0)))
    (is (eql 5 (nth* sorted 4)))))

;;; ---------------------------------------------------------------------------
;;; butlast
;;; ---------------------------------------------------------------------------

(test butlast-basic
  "butlast returns all but last element."
  (let ((result (fol.compiler.seq-functions:butlast (v 1 2 3 4))))
    (is (= 3 (size* result)))
    (is (eql 1 (nth* result 0)))
    (is (eql 3 (nth* result 2)))))

(test butlast-single
  "butlast of single-element returns empty."
  (let ((result (fol.compiler.seq-functions:butlast (v 42))))
    (is (= 0 (size* result)))))

;;; ---------------------------------------------------------------------------
;;; drop-last
;;; ---------------------------------------------------------------------------

(test drop-last-default
  "(drop-last coll) drops last element."
  (let ((result (fol.compiler.seq-functions:drop-last (v 1 2 3 4))))
    (is (= 3 (size* result)))
    (is (eql 3 (nth* result 2)))))

(test drop-last-n
  "(drop-last n coll) drops last n elements."
  (let ((result (fol.compiler.seq-functions:drop-last 2 (v 1 2 3 4))))
    (is (= 2 (size* result)))
    (is (eql 1 (nth* result 0)))
    (is (eql 2 (nth* result 1)))))

;;; ---------------------------------------------------------------------------
;;; take-last
;;; ---------------------------------------------------------------------------

(test take-last-basic
  "(take-last n coll) returns last n elements."
  (let ((result (fol.compiler.seq-functions:take-last 2 (v 1 2 3 4))))
    (is (= 2 (size* result)))
    (is (eql 3 (nth* result 0)))
    (is (eql 4 (nth* result 1)))))

(test take-last-more-than-size
  "(take-last n coll) where n > size returns full coll."
  (let ((result (fol.compiler.seq-functions:take-last 10 (v 1 2 3))))
    (is (= 3 (size* result)))))

;;; ---------------------------------------------------------------------------
;;; nthrest
;;; ---------------------------------------------------------------------------

(test nthrest-basic
  "(nthrest coll n) drops first n elements."
  (let ((result (fol.compiler.seq-functions:nthrest (v 1 2 3 4 5) 2)))
    (is (= 3 (size* result)))
    (is (eql 3 (nth* result 0)))))

(test nthrest-zero
  "(nthrest coll 0) returns same elements."
  (let ((result (fol.compiler.seq-functions:nthrest (v 1 2 3) 0)))
    (is (= 3 (size* result)))))

;;; ---------------------------------------------------------------------------
;;; third
;;; ---------------------------------------------------------------------------

(test third-basic
  "(third coll) returns the third element."
  (is (eql 3 (fol.compiler.seq-functions:third (v 1 2 3 4)))))

(test third-exactly-three
  "(third coll) with exactly three elements returns third."
  (is (eql 3 (fol.compiler.seq-functions:third (v 1 2 3)))))

(test third-too-short
  "(third coll) with fewer than 3 elements returns nil."
  (is (null (fol.compiler.seq-functions:third (v 1 2)))))

(test third-empty
  "(third []) returns nil."
  (is (null (fol.compiler.seq-functions:third (v)))))

;;; ---------------------------------------------------------------------------
;;; next / fnext / nnext
;;; ---------------------------------------------------------------------------

(test next-basic
  "(next coll) returns rest as a CL list or nil."
  (let ((result (fol.compiler.seq-functions:next (v 1 2 3))))
    (is (equal '(2 3) result))))

(test next-single
  "(next single-elem coll) returns nil."
  (let ((result (fol.compiler.seq-functions:next (v 1))))
    (is (null result))))

(test next-empty
  "(next []) returns nil."
  (let ((result (fol.compiler.seq-functions:next (v))))
    (is (null result))))

(test fnext-basic
  "(fnext coll) returns second element."
  (is (eql 2 (fol.compiler.seq-functions:fnext (v 1 2 3)))))

(test fnext-single
  "(fnext single-elem) returns nil."
  (is (null (fol.compiler.seq-functions:fnext (v 1)))))

(test nnext-basic
  "(nnext coll) returns rest of rest."
  (let ((result (fol.compiler.seq-functions:nnext (v 1 2 3 4))))
    (is (equal '(3 4) result))))

;;; ---------------------------------------------------------------------------
;;; cons
;;; ---------------------------------------------------------------------------

(test cons-prepend
  "(cons x coll) prepends x to coll."
  (let ((result (fol.compiler.seq-functions:cons 0 (v 1 2 3))))
    (is (listp result))
    (is (= 4 (length result)))
    (is (eql 0 (cl:first result)))))

(test cons-nil
  "(cons x nil) returns list of one element."
  (let ((result (fol.compiler.seq-functions:cons :a nil)))
    (is (equal '(:a) result))))

;;; ---------------------------------------------------------------------------
;;; cycle
;;; ---------------------------------------------------------------------------

(test cycle-basic
  "(take n (cycle coll)) cycles through coll."
  (let* ((cyc (fol.compiler.seq-functions:cycle (v 1 2 3)))
         (got (fol.compiler.seq-functions:take 7 cyc)))
    (is (= 7 (size* got)))
    (is (eql 1 (nth* got 0)))
    (is (eql 2 (nth* got 1)))
    (is (eql 3 (nth* got 2)))
    (is (eql 1 (nth* got 3)))
    (is (eql 2 (nth* got 4)))))

(test cycle-is-lazy-seq
  "(cycle coll) returns a lazy-seq."
  (let ((result (fol.compiler.seq-functions:cycle (v 1 2))))
    (is (typep result 'fol.compiler.collections:<lazy-seq>))))

;;; ---------------------------------------------------------------------------
;;; interleave
;;; ---------------------------------------------------------------------------

(test interleave-equal-length
  "interleave of equal-length colls produces alternating elements."
  (let ((result (fol.compiler.seq-functions:interleave
                 (v 1 2 3) (v :a :b :c))))
    (is (= 6 (size* result)))
    (is (eql 1   (nth* result 0)))
    (is (eq  :a  (nth* result 1)))
    (is (eql 2   (nth* result 2)))
    (is (eq  :b  (nth* result 3)))))

(test interleave-stops-at-shortest
  "interleave stops when the shortest coll is exhausted."
  (let ((result (fol.compiler.seq-functions:interleave
                 (v 1 2) (v :a :b :c))))
    (is (= 4 (size* result)))))

;;; ---------------------------------------------------------------------------
;;; interpose
;;; ---------------------------------------------------------------------------

(test interpose-basic
  "interpose inserts separator between elements."
  (let ((result (fol.compiler.seq-functions:interpose 0 (v 1 2 3))))
    (is (= 5 (size* result)))
    (is (eql 1 (nth* result 0)))
    (is (eql 0 (nth* result 1)))
    (is (eql 2 (nth* result 2)))
    (is (eql 0 (nth* result 3)))
    (is (eql 3 (nth* result 4)))))

(test interpose-single
  "interpose on single-element returns just that element."
  (let ((result (fol.compiler.seq-functions:interpose :sep (v 42))))
    (is (= 1 (size* result)))
    (is (eql 42 (nth* result 0)))))

(test interpose-empty
  "interpose on empty returns empty."
  (let ((result (fol.compiler.seq-functions:interpose :sep (v))))
    (is (= 0 (size* result)))))

;;; ---------------------------------------------------------------------------
;;; take-nth
;;; ---------------------------------------------------------------------------

(test take-nth-every-other
  "(take-nth 2 coll) takes every other element."
  (let ((result (fol.compiler.seq-functions:take-nth 2 (v 1 2 3 4 5 6))))
    (is (= 3 (size* result)))
    (is (eql 1 (nth* result 0)))
    (is (eql 3 (nth* result 1)))
    (is (eql 5 (nth* result 2)))))

(test take-nth-every-one
  "(take-nth 1 coll) returns all elements."
  (let ((result (fol.compiler.seq-functions:take-nth 1 (v 1 2 3))))
    (is (= 3 (size* result)))))

;;; ---------------------------------------------------------------------------
;;; random-sample
;;; ---------------------------------------------------------------------------

(test random-sample-all
  "(random-sample 1.0 coll) returns all elements."
  (let ((result (fol.compiler.seq-functions:random-sample 1.0 (v 1 2 3 4 5))))
    (is (= 5 (size* result)))))

(test random-sample-none
  "(random-sample 0.0 coll) returns empty vector."
  (let ((result (fol.compiler.seq-functions:random-sample 0.0 (v 1 2 3 4 5))))
    (is (= 0 (size* result)))))

(test random-sample-returns-vector
  "random-sample returns a FOL vector."
  (let ((result (fol.compiler.seq-functions:random-sample 0.5 (v 1 2 3 4 5 6))))
    (is (typep result 'fol.compiler.collections:<vector>))))

;;; ---------------------------------------------------------------------------
;;; seque
;;; ---------------------------------------------------------------------------

(test seque-basic
  "(seque coll) returns a vector with the same elements."
  (let ((result (fol.compiler.seq-functions:seque (v 1 2 3))))
    (is (typep result 'fol.compiler.collections:<vector>))
    (is (= 3 (size* result)))
    (is (eql 1 (nth* result 0)))))

(test seque-with-buffer-size
  "(seque n coll) ignores buffer size, returns same elements."
  (let ((result (fol.compiler.seq-functions:seque 16 (v 4 5 6))))
    (is (= 3 (size* result)))
    (is (eql 4 (nth* result 0)))))

;;; ---------------------------------------------------------------------------
;;; second
;;; ---------------------------------------------------------------------------

(test second-basic
  "(second coll) returns the second element."
  (is (eql 2 (fol.compiler.seq-functions:second (v 1 2 3)))))

(test second-too-short
  "(second coll) with fewer than 2 elements returns nil."
  (is (null (fol.compiler.seq-functions:second (v 1)))))

(test second-empty
  "(second []) returns nil."
  (is (null (fol.compiler.seq-functions:second (v)))))

;;; ---------------------------------------------------------------------------
;;; last
;;; ---------------------------------------------------------------------------

(test last-basic
  "(last coll) returns the last element."
  (is (eql 3 (fol.compiler.seq-functions:last (v 1 2 3)))))

(test last-single
  "(last [x]) returns x."
  (is (eql 42 (fol.compiler.seq-functions:last (v 42)))))

(test last-empty
  "(last []) returns nil."
  (is (null (fol.compiler.seq-functions:last (v)))))

;;; ---------------------------------------------------------------------------
;;; ffirst
;;; ---------------------------------------------------------------------------

(test ffirst-basic
  "(ffirst [[1 2] [3 4]]) returns 1."
  (is (eql 1 (fol.compiler.seq-functions:ffirst (v (v 1 2) (v 3 4))))))

(test ffirst-nil-when-empty-outer
  "(ffirst []) returns nil."
  (is (null (fol.compiler.seq-functions:ffirst (v)))))

;;; ---------------------------------------------------------------------------
;;; nfirst
;;; ---------------------------------------------------------------------------

(test nfirst-basic
  "(nfirst [[1 2 3] [4 5]]) returns (2 3)."
  (let ((result (fol.compiler.seq-functions:nfirst (v (v 1 2 3) (v 4 5)))))
    (is (equal '(2 3) result))))

(test nfirst-nil-when-empty-inner
  "(nfirst [[x] ...]) returns nil when first element has only one item."
  (let ((result (fol.compiler.seq-functions:nfirst (v (v 1) (v 2 3)))))
    (is (null result))))

;;; ---------------------------------------------------------------------------
;;; nthnext
;;; ---------------------------------------------------------------------------

(test nthnext-zero
  "(nthnext coll 0) returns the full seq."
  (let ((result (fol.compiler.seq-functions:nthnext (v 1 2 3) 0)))
    (is (equal '(1 2 3) result))))

(test nthnext-two
  "(nthnext coll 2) drops first two elements."
  (let ((result (fol.compiler.seq-functions:nthnext (v 1 2 3 4) 2)))
    (is (equal '(3 4) result))))

(test nthnext-past-end
  "(nthnext coll n) where n > size returns nil."
  (let ((result (fol.compiler.seq-functions:nthnext (v 1 2) 5)))
    (is (null result))))

;;; ---------------------------------------------------------------------------
;;; realized?
;;; ---------------------------------------------------------------------------

(test realized-eager-is-true
  "(realized? eager-coll) returns t."
  (is (eq t (fol.compiler.seq-functions:realized? (v 1 2 3)))))

(test realized-unrealized-lazy-seq
  "(realized? unrealized-lazy-seq) returns nil."
  (let ((ls (fol.compiler.seq-functions:repeat 0)))
    (is (null (fol.compiler.seq-functions:realized? ls)))))

(test realized-after-take
  "(realized? ls) returns t after the lazy-seq is forced."
  (let ((ls (fol.compiler.seq-functions:repeat 0)))
    (fol.compiler.seq-functions:take 1 ls)  ; forces realization
    (is (eq t (fol.compiler.seq-functions:realized? ls)))))

;;; ---------------------------------------------------------------------------
;;; dorun
;;; ---------------------------------------------------------------------------

(test dorun-returns-nil
  "(dorun coll) returns nil."
  (is (null (fol.compiler.seq-functions:dorun (v 1 2 3)))))

(test dorun-forces-lazy-seq
  "(dorun lazy-seq) forces realization."
  (let* ((count 0)
         (ls (fol.compiler.seq-functions:repeatedly 3 (lambda () (incf count)))))
    (fol.compiler.seq-functions:dorun ls)
    (is (= 3 count))))

;;; ---------------------------------------------------------------------------
;;; doall
;;; ---------------------------------------------------------------------------

(test doall-eager-returns-same
  "(doall eager-coll) returns the collection."
  (let* ((coll (v 1 2 3))
         (result (fol.compiler.seq-functions:doall coll)))
    (is (eq coll result))))

(test doall-lazy-returns-vector
  "(doall lazy-seq) returns a vector of all elements."
  (let* ((ls (fol.compiler.seq-functions:repeatedly 3 (lambda () 42)))
         (result (fol.compiler.seq-functions:doall ls)))
    (is (typep result 'fol.compiler.collections:<vector>))
    (is (= 3 (size* result)))
    (is (eql 42 (nth* result 0)))))

;;; ---------------------------------------------------------------------------
;;; run!
;;; ---------------------------------------------------------------------------

(test run!-applies-proc
  "(run! proc coll) applies proc to each element."
  (let ((collected '()))
    (fol.compiler.seq-functions:run! (lambda (x) (push x collected)) (v 1 2 3))
    (is (equal '(3 2 1) collected))))

(test run!-returns-nil
  "(run! proc coll) returns nil."
  (is (null (fol.compiler.seq-functions:run! #'identity (v 1 2 3)))))

;;; ---------------------------------------------------------------------------
;;; rand-nth
;;; ---------------------------------------------------------------------------

(test rand-nth-returns-element
  "(rand-nth coll) returns an element from coll."
  (let* ((coll (v 1 2 3 4 5))
         (elem (fol.compiler.seq-functions:rand-nth coll)))
    (is (member elem '(1 2 3 4 5)))))

(test rand-nth-nil-on-empty
  "(rand-nth []) returns nil."
  (is (null (fol.compiler.seq-functions:rand-nth (v)))))

;;; ---------------------------------------------------------------------------
;;; max-key
;;; ---------------------------------------------------------------------------

(test max-key-single
  "(max-key k x) returns x."
  (is (eql 42 (fol.compiler.seq-functions:max-key #'abs 42))))

(test max-key-two-args
  "(max-key abs -3 1) returns -3 (abs -3 = 3 > abs 1 = 1)."
  (is (eql -3 (fol.compiler.seq-functions:max-key #'abs -3 1))))

(test max-key-multiple
  "(max-key count ...) returns element with most items."
  (let ((result (fol.compiler.seq-functions:max-key
                 #'fol.compiler.collection-functions:size
                 (v 1 2) (v 1) (v 1 2 3))))
    (is (= 3 (size* result)))))

;;; ---------------------------------------------------------------------------
;;; min-key
;;; ---------------------------------------------------------------------------

(test min-key-single
  "(min-key k x) returns x."
  (is (eql 42 (fol.compiler.seq-functions:min-key #'abs 42))))

(test min-key-two-args
  "(min-key abs 1 -3) returns 1 (abs 1 = 1 < abs -3 = 3)."
  (is (eql 1 (fol.compiler.seq-functions:min-key #'abs 1 -3))))

(test min-key-multiple
  "(min-key count ...) returns element with fewest items."
  (let ((result (fol.compiler.seq-functions:min-key
                 #'fol.compiler.collection-functions:size
                 (v 1 2) (v 1) (v 1 2 3))))
    (is (= 1 (size* result)))))

;;; ---------------------------------------------------------------------------
;;; zipmap
;;; ---------------------------------------------------------------------------

(test zipmap-basic
  "(zipmap keys vals) returns a dict with keys mapped to vals."
  (let* ((result (fol.compiler.seq-functions:zipmap (v :a :b :c) (v 1 2 3)))
         (a (fol.compiler.collection-functions:get result :a))
         (b (fol.compiler.collection-functions:get result :b))
         (c (fol.compiler.collection-functions:get result :c)))
    (is (= 1 a))
    (is (= 2 b))
    (is (= 3 c))))

(test zipmap-stops-at-shorter-keys
  "(zipmap keys vals) stops at shorter sequence."
  (let ((result (fol.compiler.seq-functions:zipmap (v :a :b) (v 1 2 3))))
    (is (= 2 (fol.compiler.collection-functions:size result)))))

(test zipmap-empty
  "(zipmap [] []) returns empty dict."
  (let ((result (fol.compiler.seq-functions:zipmap (v) (v))))
    (is (= 0 (fol.compiler.collection-functions:size result)))))

;;; ---------------------------------------------------------------------------
;;; reductions
;;; ---------------------------------------------------------------------------

(test reductions-with-init
  "(reductions f init coll) includes init as first element."
  (let ((result (fol.compiler.seq-functions:reductions #'+ 0 (v 1 2 3))))
    (is (= 4 (size* result)))
    (is (eql 0 (nth* result 0)))
    (is (eql 1 (nth* result 1)))
    (is (eql 3 (nth* result 2)))
    (is (eql 6 (nth* result 3)))))

(test reductions-without-init
  "(reductions f coll) uses first element as init."
  (let ((result (fol.compiler.seq-functions:reductions #'+ (v 1 2 3 4))))
    (is (= 4 (size* result)))
    (is (eql 1 (nth* result 0)))
    (is (eql 3 (nth* result 1)))
    (is (eql 6 (nth* result 2)))
    (is (eql 10 (nth* result 3)))))

(test reductions-empty-coll
  "(reductions f []) returns empty vector."
  (let ((result (fol.compiler.seq-functions:reductions #'+ (v))))
    (is (= 0 (size* result)))))

(test reductions-single-with-init
  "(reductions f init [x]) returns [init (f init x)]."
  (let ((result (fol.compiler.seq-functions:reductions #'+ 10 (v 5))))
    (is (= 2 (size* result)))
    (is (eql 10 (nth* result 0)))
    (is (eql 15 (nth* result 1)))))
