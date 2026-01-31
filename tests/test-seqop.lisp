(in-package :fol.tests)

;;; ============================================================================
;;; Sequence Operation Tests - Tests for functions in seqop.lisp
;;; ============================================================================

(def-suite seqop-suite :in fol-suite)
(def-suite* :fol.seqop-tests :in seqop-suite)

;;; ---------------------------------------------------------------------------
;;; Seq Tests
;;; ---------------------------------------------------------------------------

(test seq-empty-collections
  "Test that seq returns NIL for empty collections."
  (is (eq nil (seq (make-list))))
  (is (eq nil (seq (make-vector))))
  (is (eq nil (seq (make-dict))))
  (is (eq nil (seq (make-set))))
  (is (eq nil (seq (make-bag)))))

(test seq-list
  "Test seq on list returns the list itself."
  (let ((lst (make-list 1 2 3)))
    ;; seq on non-empty list returns the list itself
    (is (eq lst (seq lst)))
    (is-true (<list>? (seq lst)))
    (is (= 3 (size (seq lst))))))

(test seq-vector
  "Test seq on vector returns a list."
  (let* ((v (make-vector 1 2 3))
         (s (seq v)))
    (is-true (<list>? s))
    (is (= 3 (size s)))
    (is (= 1 (first s)))
    (is (= 2 (first (rest s))))
    (is (= 3 (first (rest (rest s)))))))

(test seq-dict
  "Test seq on dict returns a list of pairs."
  (let* ((d (make-dict :a 1 :b 2))
         (s (seq d)))
    (is-true (<list>? s))
    (is (= 2 (size s)))
    ;; Each element should be a cons pair
    (is-true (consp (first s)))
    (is-true (consp (first (rest s))))))

(test seq-set
  "Test seq on set returns a list of elements."
  (let* ((st (make-set 1 2 3))
         (s (seq st)))
    (is-true (<list>? s))
    (is (= 3 (size s)))
    ;; All elements should be in the seq
    (is-true (contains? s 1))
    (is-true (contains? s 2))
    (is-true (contains? s 3))))

(test seq-bag
  "Test seq on bag returns elements repeated by count."
  (let* ((b (make-bag :a :a :a :b :b))
         (s (seq b)))
    (is-true (<list>? s))
    ;; 3 :a's and 2 :b's = 5 total
    (is (= 5 (size s)))))

(test seq-preserves-vector-order
  "Test that seq preserves vector element order."
  (let* ((v (make-vector 10 20 30 40))
         (s (seq v)))
    (is (= 10 (get s 0)))
    (is (= 20 (get s 1)))
    (is (= 30 (get s 2)))
    (is (= 40 (get s 3)))))

(test seq-idempotent-on-list
  "Test that seq on a list is idempotent."
  (let* ((lst (make-list 1 2 3))
         (s1 (seq lst))
         (s2 (seq s1)))
    ;; seq of seq of list is the same list
    (is (eq lst s1))
    (is (eq s1 s2))))

;;; ---------------------------------------------------------------------------
;;; Conj Tests (Clojure-style addition)
;;; ---------------------------------------------------------------------------

(test conj-list-single
  "Test conj adds to front of list."
  (let* ((lst (make-list 2 3))
         (result (conj lst 1)))
    (is (= 3 (size result)))
    (is (= 1 (first result)))
    (is (= 2 (first (rest result))))))

(test conj-list-multiple
  "Test conj with multiple items on list."
  (let* ((lst (make-list 4 5))
         (result (conj lst 1 2 3)))
    ;; Items are added left-to-right, so 3 ends up first
    (is (= 5 (size result)))
    (is (= 3 (first result)))
    (is (= 2 (first (rest result))))
    (is (= 1 (first (rest (rest result)))))))

(test conj-list-empty
  "Test conj to empty list."
  (let* ((empty (make-list))
         (result (conj empty :first)))
    (is (= 1 (size result)))
    (is (eq :first (first result)))))

(test conj-vector-single
  "Test conj adds to end of vector."
  (let* ((v (make-vector 1 2))
         (result (conj v 3)))
    (is (= 3 (size result)))
    (is (= 1 (get result 0)))
    (is (= 2 (get result 1)))
    (is (= 3 (get result 2)))))

(test conj-vector-multiple
  "Test conj with multiple items on vector."
  (let* ((v (make-vector 1))
         (result (conj v 2 3 4)))
    (is (= 4 (size result)))
    (is (= 1 (get result 0)))
    (is (= 2 (get result 1)))
    (is (= 3 (get result 2)))
    (is (= 4 (get result 3)))))

(test conj-set-single
  "Test conj adds element to set."
  (let* ((s (make-set 1 2))
         (result (conj s 3)))
    (is (= 3 (size result)))
    (is-true (contains? result 1))
    (is-true (contains? result 2))
    (is-true (contains? result 3))))

(test conj-set-duplicate
  "Test conj with duplicate element on set."
  (let* ((s (make-set 1 2))
         (result (conj s 2)))
    ;; Set should still have 2 elements
    (is (= 2 (size result)))))

(test conj-set-multiple
  "Test conj with multiple items on set."
  (let* ((s (make-set 1))
         (result (conj s 2 3 4)))
    (is (= 4 (size result)))
    (is-true (contains? result 1))
    (is-true (contains? result 2))
    (is-true (contains? result 3))
    (is-true (contains? result 4))))

(test conj-bag-single
  "Test conj adds element to bag."
  (let* ((b (make-bag :a :a))
         (result (conj b :a)))
    ;; Bag size is unique elements, but seq gives total count
    (is (= 1 (size result)))  ; 1 unique element
    (is (= 3 (size (seq result))))))  ; 3 total occurrences

(test conj-bag-multiple
  "Test conj with multiple items on bag."
  (let* ((b (make-bag :x))
         (result (conj b :x :y :y)))
    ;; 2 unique elements (:x and :y)
    (is (= 2 (size result)))
    ;; 2 :x's and 2 :y's = 4 total in seq
    (is (= 4 (size (seq result))))))

(test conj-dict-single
  "Test conj adds key-value pair to dict."
  (let* ((d (make-dict :a 1))
         (result (conj d :b 2)))
    (is (= 2 (size result)))
    (is (= 1 (get result :a)))
    (is (= 2 (get result :b)))))

(test conj-dict-multiple
  "Test conj with multiple pairs on dict (chained calls)."
  (let* ((d (make-dict))
         (result (conj (conj (conj d :a 1) :b 2) :c 3)))
    (is (= 3 (size result)))
    (is (= 1 (get result :a)))
    (is (= 2 (get result :b)))
    (is (= 3 (get result :c)))))

(test conj-dict-update
  "Test conj updates existing key in dict."
  (let* ((d (make-dict :a 1))
         (result (conj d :a 100)))
    (is (= 1 (size result)))
    (is (= 100 (get result :a)))))

(test conj-dict-requires-key-value
  "Test conj on dict requires exactly key and value."
  (let ((d (make-dict)))
    ;; Too few args (just key, no value)
    (signals error
      (conj d :key-only))))

(test conj-array-error
  "Test conj on array signals error."
  (let ((a (make-array (make-vector 2 2) 1 2 3 4)))
    (signals error
      (conj a 5))))

(test conj-lazy-seq
  "Test conj adds to front of lazy-seq."
  (let* ((ls (make-lazy-seq (lambda () (make-list 2 3))))
         (result (conj ls 1)))
    (is (= 1 (first result)))
    (is (= 2 (first (rest result))))))

(test conj-lazy-seq-multiple
  "Test conj with multiple items on lazy-seq."
  (let* ((ls (make-lazy-seq (lambda () (make-list 4))))
         (result (conj ls 1 2 3)))
    ;; Items added left-to-right, so 3 is first
    (is (= 3 (first result)))
    (is (= 2 (first (rest result))))
    (is (= 1 (first (rest (rest result)))))
    (is (= 4 (first (rest (rest (rest result))))))))

(test conj-immutability
  "Test conj does not mutate original collection."
  (let* ((lst (make-list 1 2))
         (vec (make-vector 1 2))
         (st (make-set 1 2))
         (lst2 (conj lst 0))
         (vec2 (conj vec 3))
         (st2 (conj st 3)))
    ;; Originals unchanged
    (is (= 2 (size lst)))
    (is (= 2 (size vec)))
    (is (= 2 (size st)))
    ;; New collections have added elements
    (is (= 3 (size lst2)))
    (is (= 3 (size vec2)))
    (is (= 3 (size st2)))))

;;; ---------------------------------------------------------------------------
;;; Pop Tests
;;; ---------------------------------------------------------------------------

(test pop-list-basic
  "Test pop removes first element from list."
  (let* ((lst (make-list 1 2 3))
         (popped (pop lst)))
    (is (= 2 (size popped)))
    (is (= 2 (first popped)))
    (is (= 3 (second popped)))))

(test pop-list-single
  "Test pop on single-element list returns empty list."
  (let* ((lst (make-list 1))
         (popped (pop lst)))
    (is (<list>? popped))
    (is (= 0 (size popped)))))

(test pop-list-empty
  "Test pop on empty list returns nil."
  (let ((lst (make-list)))
    (is (eq nil (pop lst)))))

(test pop-list-nil
  "Test pop on nil returns nil."
  (is (eq nil (pop nil))))

(test pop-vector-basic
  "Test pop removes last element from vector."
  (let* ((vec (make-vector 1 2 3))
         (popped (pop vec)))
    (is (= 2 (size popped)))
    (is (= 1 (first popped)))
    (is (= 2 (second popped)))))

(test pop-vector-single
  "Test pop on single-element vector returns empty vector."
  (let* ((vec (make-vector 1))
         (popped (pop vec)))
    (is (<vector>? popped))
    (is (= 0 (size popped)))))

(test pop-vector-empty
  "Test pop on empty vector returns empty vector."
  (let* ((vec (make-vector))
         (popped (pop vec)))
    (is (<vector>? popped))
    (is (= 0 (size popped)))))

(test pop-immutability
  "Test pop does not mutate original collection."
  (let* ((lst (make-list 1 2 3))
         (vec (make-vector 1 2 3))
         (lst2 (pop lst))
         (vec2 (pop vec)))
    ;; Originals unchanged
    (is (= 3 (size lst)))
    (is (= 3 (size vec)))
    ;; Popped collections have one less element
    (is (= 2 (size lst2)))
    (is (= 2 (size vec2)))))

;;; ---------------------------------------------------------------------------
;;; Push Tests
;;; ---------------------------------------------------------------------------

(test push-list-basic
  "Test push adds element to front of list."
  (let* ((lst (make-list 2 3))
         (pushed (push 1 lst)))
    (is (= 3 (size pushed)))
    (is (= 1 (first pushed)))
    (is (= 2 (second pushed)))
    (is (= 3 (third pushed)))))

(test push-list-empty
  "Test push on empty list creates single-element list."
  (let* ((lst (make-list))
         (pushed (push 1 lst)))
    (is (= 1 (size pushed)))
    (is (= 1 (first pushed)))))

(test push-list-nil
  "Test push on nil creates single-element list."
  (let ((pushed (push 1 nil)))
    (is (<list>? pushed))
    (is (= 1 (size pushed)))
    (is (= 1 (first pushed)))))

(test push-vector-basic
  "Test push adds element to end of vector."
  (let* ((vec (make-vector 1 2))
         (pushed (push 3 vec)))
    (is (= 3 (size pushed)))
    (is (= 1 (first pushed)))
    (is (= 2 (second pushed)))
    (is (= 3 (third pushed)))))

(test push-vector-empty
  "Test push on empty vector creates single-element vector."
  (let* ((vec (make-vector))
         (pushed (push 1 vec)))
    (is (= 1 (size pushed)))
    (is (= 1 (first pushed)))))

(test push-immutability
  "Test push does not mutate original collection."
  (let* ((lst (make-list 2 3))
         (vec (make-vector 1 2))
         (lst2 (push 1 lst))
         (vec2 (push 3 vec)))
    ;; Originals unchanged
    (is (= 2 (size lst)))
    (is (= 2 (size vec)))
    ;; Pushed collections have one more element
    (is (= 3 (size lst2)))
    (is (= 3 (size vec2)))))

;;; ---------------------------------------------------------------------------
;;; Reverse Tests (for vectors)
;;; ---------------------------------------------------------------------------

(test reverse-vector-basic
  "Test reverse with FOL vectors."
  (let ((v (make-vector 1 2 3 4 5)))
    (let ((r (reverse v)))
      (is (= 5 (nth-element r 0)))
      (is (= 4 (nth-element r 1)))
      (is (= 3 (nth-element r 2)))
      (is (= 2 (nth-element r 3)))
      (is (= 1 (nth-element r 4))))))

(test reverse-vector-empty
  "Test reverse with empty vector."
  (let ((v (make-vector)))
    (is (= 0 (size (reverse v))))))

(test reverse-vector-single
  "Test reverse with single-element vector."
  (let ((v (make-vector 42)))
    (let ((r (reverse v)))
      (is (= 1 (size r)))
      (is (= 42 (nth-element r 0))))))

;;; ---------------------------------------------------------------------------
;;; Reverse Tests (for lists)
;;; ---------------------------------------------------------------------------

(test reverse-list-basic
  "Test reverse with FOL lists."
  (let ((lst (make-list 1 2 3 4 5)))
    (let ((r (reverse lst)))
      (is (= 5 (first r)))
      (is (= 4 (first (rest r))))
      (is (= 1 (first (rest (rest (rest (rest r))))))))))

(test reverse-list-empty
  "Test reverse with empty list."
  (let ((lst (make-list)))
    (is (empty? (reverse lst)))))

(test reverse-list-single
  "Test reverse with single-element list."
  (let ((lst (make-list 42)))
    (let ((r (reverse lst)))
      (is (= 1 (size r)))
      (is (= 42 (first r))))))

(test reverse-cl-list
  "Test reverse with CL lists."
  (is (equal '(3 2 1) (reverse '(1 2 3))))
  (is (equal '(c b a) (reverse '(a b c)))))

;;; ---------------------------------------------------------------------------
;;; index-of Tests for Vectors
;;; ---------------------------------------------------------------------------

(test index-of-vector-basic
  "Test index-of with FOL vectors."
  (let ((v (make-vector 1 2 3 4 5)))
    (is (= 0 (index-of v 1)))
    (is (= 2 (index-of v 3)))
    (is (= 4 (index-of v 5)))
    (is (null (index-of v 6)))))

(test index-of-vector-with-start
  "Test index-of with start index on vectors."
  (let ((v (make-vector 1 2 3 2 1)))
    (is (= 1 (index-of v 2)))
    (is (= 3 (index-of v 2 2)))
    (is (= 4 (index-of v 1 2)))
    (is (null (index-of v 1 5)))))

(test index-of-vector-symbols
  "Test index-of with symbol values in vectors."
  (let ((v (make-vector 'a 'b 'c 'd)))
    (is (= 0 (index-of v 'a)))
    (is (= 2 (index-of v 'c)))
    (is (null (index-of v 'e)))))

;;; ---------------------------------------------------------------------------
;;; index-of Tests for Lists
;;; ---------------------------------------------------------------------------

(test index-of-list-basic
  "Test index-of with FOL lists."
  (let ((lst (make-list 1 2 3 4 5)))
    (is (= 0 (index-of lst 1)))
    (is (= 2 (index-of lst 3)))
    (is (= 4 (index-of lst 5)))
    (is (null (index-of lst 6)))))

(test index-of-list-with-start
  "Test index-of with start index on lists."
  (let ((lst (make-list 1 2 3 2 1)))
    (is (= 1 (index-of lst 2)))
    (is (= 3 (index-of lst 2 2)))
    (is (= 4 (index-of lst 1 2)))
    (is (null (index-of lst 1 5)))))

(test index-of-cl-list
  "Test index-of with CL lists."
  (is (= 1 (index-of '(a b c) 'b)))
  (is (= 0 (index-of '(1 2 3) 1)))
  (is (null (index-of '(1 2 3) 4))))

;;; ---------------------------------------------------------------------------
;;; last-index-of Tests for Vectors
;;; ---------------------------------------------------------------------------

(test last-index-of-vector-basic
  "Test last-index-of with FOL vectors."
  (let ((v (make-vector 1 2 3 2 1)))
    (is (= 4 (last-index-of v 1)))
    (is (= 3 (last-index-of v 2)))
    (is (= 2 (last-index-of v 3)))
    (is (null (last-index-of v 5)))))

(test last-index-of-vector-with-start
  "Test last-index-of with start index on vectors."
  (let ((v (make-vector 1 2 3 2 1)))
    (is (= 1 (last-index-of v 2 2)))
    (is (= 0 (last-index-of v 1 2)))
    (is (null (last-index-of v 3 1)))))

;;; ---------------------------------------------------------------------------
;;; last-index-of Tests for Lists
;;; ---------------------------------------------------------------------------

(test last-index-of-list-basic
  "Test last-index-of with FOL lists."
  (let ((lst (make-list 1 2 3 2 1)))
    (is (= 4 (last-index-of lst 1)))
    (is (= 3 (last-index-of lst 2)))
    (is (= 2 (last-index-of lst 3)))
    (is (null (last-index-of lst 5)))))

(test last-index-of-list-with-start
  "Test last-index-of with start index on lists."
  (let ((lst (make-list 1 2 3 2 1)))
    (is (= 1 (last-index-of lst 2 2)))
    (is (= 0 (last-index-of lst 1 2)))
    (is (null (last-index-of lst 3 1)))))

(test last-index-of-cl-list
  "Test last-index-of with CL lists."
  (is (= 2 (last-index-of '(a b a) 'a)))
  (is (= 2 (last-index-of '(1 2 1) 1)))
  (is (null (last-index-of '(1 2 3) 4))))

;;; ---------------------------------------------------------------------------
;;; assoc Tests
;;; ---------------------------------------------------------------------------

(test assoc-dict-new-key
  "Test assoc adds a new key to a dict."
  (let* ((d (make-dict :a 1 :b 2))
         (result (assoc d :c 3)))
    (is-true (<dict>? result))
    (is (= 3 (get result :c)))
    (is (= 1 (get d :a)))  ; original unchanged
    (is (null (get d :c)))))  ; original doesn't have :c

(test assoc-dict-existing-key
  "Test assoc updates an existing key in a dict."
  (let* ((d (make-dict :a 1 :b 2))
         (result (assoc d :a 100)))
    (is-true (<dict>? result))
    (is (= 100 (get result :a)))
    (is (= 1 (get d :a)))))  ; original unchanged

(test assoc-vector
  "Test assoc updates an element in a vector."
  (let* ((v (make-vector 10 20 30))
         (result (assoc v 1 99)))
    (is-true (<vector>? result))
    (is (= 10 (nth result 0)))
    (is (= 99 (nth result 1)))
    (is (= 30 (nth result 2)))
    (is (= 20 (nth v 1)))))  ; original unchanged

;;; ---------------------------------------------------------------------------
;;; assoc-in Tests
;;; ---------------------------------------------------------------------------

(test assoc-in-single-key
  "Test assoc-in with a single key."
  (let* ((d (make-dict :a 1))
         (result (assoc-in d (make-vector :b) 2)))
    (is-true (<dict>? result))
    (is (= 2 (get result :b)))))

(test assoc-in-nested-dict
  "Test assoc-in with nested dicts."
  (let* ((d (make-dict :a (make-dict :b 1)))
         (result (assoc-in d (make-vector :a :b) 99)))
    (is-true (<dict>? result))
    (is (= 99 (get (get result :a) :b)))))

(test assoc-in-creates-intermediate
  "Test assoc-in creates intermediate dicts."
  (let* ((d (make-dict))
         (result (assoc-in d (make-vector :a :b :c) 42)))
    (is-true (<dict>? result))
    (is (= 42 (get (get (get result :a) :b) :c)))))

(test assoc-in-vector-root
  "Test assoc-in with vector as root."
  (let* ((v (make-vector (make-dict :a 1) (make-dict :b 2)))
         (result (assoc-in v (make-vector 0 :a) 100)))
    (is-true (<vector>? result))
    (is (= 100 (get (nth result 0) :a)))))

;;; ---------------------------------------------------------------------------
;;; sub Tests
;;; ---------------------------------------------------------------------------

(test sub-string-basic
  "Test sub on a string with start and end."
  (is (string= "ell" (sub "hello" 1 4))))

(test sub-string-no-end
  "Test sub on a string with only start."
  (is (string= "lo" (sub "hello" 3))))

(test sub-string-full
  "Test sub on a string from 0 to length."
  (is (string= "hello" (sub "hello" 0 5))))

(test sub-vector-basic
  "Test sub on a vector with start and end."
  (let ((v (sub (make-vector 1 2 3 4 5) 1 4)))
    (is-true (<vector>? v))
    (is (= 3 (size v)))
    (is (= 2 (nth v 0)))
    (is (= 3 (nth v 1)))
    (is (= 4 (nth v 2)))))

(test sub-vector-no-end
  "Test sub on a vector with only start."
  (let ((v (sub (make-vector 1 2 3 4 5) 2)))
    (is-true (<vector>? v))
    (is (= 3 (size v)))
    (is (= 3 (nth v 0)))
    (is (= 4 (nth v 1)))
    (is (= 5 (nth v 2)))))

(test sub-list-basic
  "Test sub on a list with start and end."
  (let ((lst (sub (make-list 1 2 3 4 5) 1 4)))
    (is-true (<list>? lst))
    (is (= 3 (size lst)))
    (is (= 2 (first lst)))))

(test sub-list-no-end
  "Test sub on a list with only start."
  (let ((lst (sub (make-list 1 2 3 4 5) 3)))
    (is-true (<list>? lst))
    (is (= 2 (size lst)))
    (is (= 4 (first lst)))))

;;; ---------------------------------------------------------------------------
;;; rseq Tests
;;; ---------------------------------------------------------------------------

(test rseq-vector-basic
  "Test rseq on a vector returns elements in reverse order (as lazy-seq)."
  (let ((v (make-vector 1 2 3 4 5)))
    (let ((rs (rseq v)))
      ;; rseq now returns a lazy-seq
      (is-true (<lazy-seq>? rs))
      (is (= 5 (first rs)))
      (is (= 4 (first (rest rs))))
      (is (= 1 (first (rest (rest (rest (rest rs))))))))))

(test rseq-vector-empty
  "Test rseq on empty vector returns NIL."
  (let ((v (make-vector)))
    (is (null (rseq v)))))

(test rseq-list-basic
  "Test rseq on a list returns elements in reverse order (as lazy-seq)."
  (let ((lst (make-list 1 2 3)))
    (let ((rs (rseq lst)))
      ;; rseq now returns a lazy-seq
      (is-true (<lazy-seq>? rs))
      (is (= 3 (first rs)))
      (is (= 2 (first (rest rs))))
      (is (= 1 (first (rest (rest rs))))))))

(test rseq-list-empty
  "Test rseq on empty list returns NIL."
  (let ((lst (make-list)))
    (is (null (rseq lst)))))

(test rseq-cl-list
  "Test rseq on CL list returns elements in reverse order."
  (let ((rs (rseq '(1 2 3))))
    (is-true (<lazy-seq>? rs))
    (is (= 3 (first rs)))
    (is (= 2 (first (rest rs))))
    (is (= 1 (first (rest (rest rs))))))
  (is (null (rseq nil))))

;;; ---------------------------------------------------------------------------
;;; update Tests
;;; ---------------------------------------------------------------------------

(test update-dict-basic
  "Test update applies function to value in dict."
  (let* ((d (make-dict :a 1 :b 2))
         (result (update d :a #'cl:1+)))
    (is-true (<dict>? result))
    (is (= 2 (get result :a)))
    (is (= 1 (get d :a)))))  ; original unchanged

(test update-dict-with-args
  "Test update with additional arguments."
  (let* ((d (make-dict :a 10))
         (result (update d :a #'cl:+ 5)))
    (is (= 15 (get result :a)))))

(test update-dict-missing-key
  "Test update on missing key passes NIL to function."
  (let* ((d (make-dict :a 1))
         (result (update d :b (lambda (x) (if x (cl:1+ x) 100)))))
    (is (= 100 (get result :b)))))

(test update-vector-basic
  "Test update applies function to value in vector."
  (let* ((v (make-vector 10 20 30))
         (result (update v 1 #'cl:1+)))
    (is-true (<vector>? result))
    (is (= 21 (nth result 1)))
    (is (= 20 (nth v 1)))))  ; original unchanged

(test update-vector-with-args
  "Test update on vector with additional arguments."
  (let* ((v (make-vector 10 20 30))
         (result (update v 0 #'cl:* 2)))
    (is (= 20 (nth result 0)))))

;;; ---------------------------------------------------------------------------
;;; update-in Tests
;;; ---------------------------------------------------------------------------

(test update-in-single-key
  "Test update-in with a single key."
  (let* ((d (make-dict :a 1))
         (result (update-in d (make-vector :a) #'cl:1+)))
    (is-true (<dict>? result))
    (is (= 2 (get result :a)))))

(test update-in-nested-dict
  "Test update-in with nested dicts."
  (let* ((d (make-dict :a (make-dict :b 10)))
         (result (update-in d (make-vector :a :b) #'cl:1+)))
    (is-true (<dict>? result))
    (is (= 11 (get (get result :a) :b)))))

(test update-in-creates-intermediate
  "Test update-in creates intermediate dicts."
  (let* ((d (make-dict))
         (result (update-in d (make-vector :a :b) (lambda (x) (if x x 42)))))
    (is-true (<dict>? result))
    (is (= 42 (get (get result :a) :b)))))

(test update-in-with-args
  "Test update-in with additional arguments."
  (let* ((d (make-dict :a (make-dict :b 10)))
         (result (update-in d (make-vector :a :b) #'cl:+ 5)))
    (is (= 15 (get (get result :a) :b)))))

(test update-in-vector-root
  "Test update-in with vector as root."
  (let* ((v (make-vector (make-dict :a 1) (make-dict :b 2)))
         (result (update-in v (make-vector 0 :a) #'cl:1+)))
    (is-true (<vector>? result))
    (is (= 2 (get (nth result 0) :a)))))

;;; ---------------------------------------------------------------------------
;;; reduce-kv Tests
;;; ---------------------------------------------------------------------------

(test reduce-kv-dict-basic
  "Test reduce-kv on a dict."
  (let* ((d (make-dict :a 1 :b 2 :c 3))
         ;; Sum of all values
         (result (reduce-kv (lambda (acc k v)
                              (declare (ignore k))
                              (cl:+ acc v))
                            0 d)))
    (is (= 6 result))))

(test reduce-kv-dict-with-keys
  "Test reduce-kv uses keys."
  (let* ((d (make-dict :a 1 :b 2))
         ;; Collect keys into a list
         (result (reduce-kv (lambda (acc k v)
                              (declare (ignore v))
                              (cl:cons k acc))
                            nil d)))
    (is (= 2 (cl:length result)))
    (is-true (cl:member :a result))
    (is-true (cl:member :b result))))

(test reduce-kv-vector-basic
  "Test reduce-kv on a vector uses indices as keys."
  (let* ((v (make-vector 10 20 30))
         ;; Sum of index * value
         (result (reduce-kv (lambda (acc idx val)
                              (cl:+ acc (cl:* idx val)))
                            0 v)))
    ;; 0*10 + 1*20 + 2*30 = 0 + 20 + 60 = 80
    (is (= 80 result))))

(test reduce-kv-empty-dict
  "Test reduce-kv on empty dict returns init."
  (let ((result (reduce-kv (lambda (acc k v)
                             (declare (ignore k v))
                             (cl:1+ acc))
                           42 (make-dict))))
    (is (= 42 result))))

(test reduce-kv-empty-vector
  "Test reduce-kv on empty vector returns init."
  (let ((result (reduce-kv (lambda (acc k v)
                             (declare (ignore k v))
                             (cl:1+ acc))
                           42 (make-vector))))
    (is (= 42 result))))

(test reduce-kv-early-termination
  "Test reduce-kv with early termination via reduced."
  (let* ((v (make-vector 1 2 3 4 5))
         ;; Stop when we reach index 2
         (result (reduce-kv (lambda (acc idx val)
                              (if (cl:= idx 2)
                                  (reduced acc)
                                  (cl:+ acc val)))
                            0 v)))
    ;; 1 + 2 = 3 (stopped at idx 2)
    (is (= 3 result))))

;;; ---------------------------------------------------------------------------
;;; Set Operation Tests: union, difference, intersection
;;; ---------------------------------------------------------------------------

(test union-basic-sets
  "Test union of basic hash sets."
  (let* ((s1 (make-set 1 2 3))
         (s2 (make-set 3 4 5))
         (result (set-union s1 s2)))
    (is-true (<set>? result))
    (is (= 5 (size result)))
    (is-true (contains? result 1))
    (is-true (contains? result 3))
    (is-true (contains? result 5))))

(test union-multiple-sets
  "Test union of multiple sets."
  (let* ((s1 (make-set 1 2))
         (s2 (make-set 3 4))
         (s3 (make-set 5 6))
         (result (set-union s1 s2 s3)))
    (is (= 6 (size result)))))

(test union-sorted-sets
  "Test union preserves sorted-set type."
  (let* ((s1 (make-sorted-set 3 1 5))
         (s2 (make-set 2 4))
         (result (set-union s1 s2)))
    (is-true (<sorted-set>? result))
    (is (= 5 (size result)))
    ;; Check order
    (let ((lst (seq result)))
      (is (= 1 (first lst))))))

(test union-ordered-sets
  "Test union preserves ordered-set type and order."
  (let* ((s1 (make-ordered-set 3 1 5))
         (s2 (make-set 2 4))
         (result (set-union s1 s2)))
    (is-true (<ordered-set>? result))
    ;; First element should still be 3 (first inserted)
    (is (= 3 (first (seq result))))))

(test difference-basic-sets
  "Test difference of basic hash sets."
  (let* ((s1 (make-set 1 2 3 4))
         (s2 (make-set 2 4))
         (result (set-difference s1 s2)))
    (is-true (<set>? result))
    (is (= 2 (size result)))
    (is-true (contains? result 1))
    (is-true (contains? result 3))
    (is-false (contains? result 2))))

(test difference-sorted-set
  "Test difference preserves sorted-set type."
  (let* ((s1 (make-sorted-set 1 2 3 4 5))
         (s2 (make-set 2 4))
         (result (set-difference s1 s2)))
    (is-true (<sorted-set>? result))
    (is (= 3 (size result)))))

(test difference-no-overlap
  "Test difference when sets don't overlap."
  (let* ((s1 (make-set 1 2))
         (s2 (make-set 3 4))
         (result (set-difference s1 s2)))
    (is (= 2 (size result)))))

(test intersection-basic-sets
  "Test intersection of basic hash sets."
  (let* ((s1 (make-set 1 2 3 4))
         (s2 (make-set 2 3 5))
         (result (set-intersection s1 s2)))
    (is-true (<set>? result))
    (is (= 2 (size result)))
    (is-true (contains? result 2))
    (is-true (contains? result 3))
    (is-false (contains? result 1))))

(test intersection-multiple-sets
  "Test intersection of multiple sets."
  (let* ((s1 (make-set 1 2 3 4 5))
         (s2 (make-set 2 3 4))
         (s3 (make-set 3 4 5))
         (result (set-intersection s1 s2 s3)))
    (is (= 2 (size result)))
    (is-true (contains? result 3))
    (is-true (contains? result 4))))

(test intersection-sorted-set
  "Test intersection preserves sorted-set type."
  (let* ((s1 (make-sorted-set 1 2 3 4 5))
         (s2 (make-set 2 4 6))
         (result (set-intersection s1 s2)))
    (is-true (<sorted-set>? result))
    (is (= 2 (size result)))))

(test intersection-empty-result
  "Test intersection with no common elements."
  (let* ((s1 (make-set 1 2))
         (s2 (make-set 3 4))
         (result (set-intersection s1 s2)))
    (is (= 0 (size result)))))

;;; ---------------------------------------------------------------------------
;;; Select Tests
;;; ---------------------------------------------------------------------------

(test select-basic-set
  "Test select on basic hash set."
  (let* ((s (make-set 1 2 3 4 5 6))
         (result (select #'cl:evenp s)))
    (is-true (<set>? result))
    (is (= 3 (size result)))
    (is-true (contains? result 2))
    (is-true (contains? result 4))
    (is-false (contains? result 1))))

(test select-sorted-set
  "Test select on sorted set preserves type."
  (let* ((s (make-sorted-set 1 2 3 4 5))
         (result (select #'cl:oddp s)))
    (is-true (<sorted-set>? result))
    (is (= 3 (size result)))))

(test select-ordered-set
  "Test select on ordered set preserves type and order."
  (let* ((s (make-ordered-set 5 2 4 1 3))
         (result (select #'cl:oddp s)))
    (is-true (<ordered-set>? result))
    (is (= 3 (size result)))
    ;; Order should be preserved: 5, 1, 3
    (is (= 5 (first (seq result))))))

(test select-none-match
  "Test select when no elements match."
  (let* ((s (make-set 1 3 5))
         (result (select #'cl:evenp s)))
    (is (= 0 (size result)))))

;;; ---------------------------------------------------------------------------
;;; Subset? and Superset? Tests
;;; ---------------------------------------------------------------------------

(test subset?-true
  "Test subset? returns true for proper subset."
  (let ((s1 (make-set 1 2))
        (s2 (make-set 1 2 3 4)))
    (is-true (subset? s1 s2))))

(test subset?-false
  "Test subset? returns false when not subset."
  (let ((s1 (make-set 1 2 5))
        (s2 (make-set 1 2 3 4)))
    (is-false (subset? s1 s2))))

(test subset?-equal-sets
  "Test subset? returns true for equal sets."
  (let ((s1 (make-set 1 2 3))
        (s2 (make-set 1 2 3)))
    (is-true (subset? s1 s2))))

(test subset?-empty-set
  "Test empty set is subset of any set."
  (let ((s1 (make-set))
        (s2 (make-set 1 2 3)))
    (is-true (subset? s1 s2))))

(test superset?-true
  "Test superset? returns true when contains all elements."
  (let ((s1 (make-set 1 2 3 4))
        (s2 (make-set 1 2)))
    (is-true (superset? s1 s2))))

(test superset?-false
  "Test superset? returns false when missing elements."
  (let ((s1 (make-set 1 2 3))
        (s2 (make-set 1 2 5)))
    (is-false (superset? s1 s2))))

(test superset?-empty-set
  "Test any set is superset of empty set."
  (let ((s1 (make-set 1 2 3))
        (s2 (make-set)))
    (is-true (superset? s1 s2))))

;;; ---------------------------------------------------------------------------
;;; subs and rsubs Tests
;;; ---------------------------------------------------------------------------

(test subs-vector-with-end
  "Test subs on vector with start and end (returns lazy-seq)."
  (let* ((v (make-vector 0 1 2 3 4 5))
         (result (subs v 2 5)))
    ;; subs now returns a lazy-seq
    (is-true (<lazy-seq>? result))
    ;; Convert to vector to test size
    (let ((as-vec (into (make-vector) result)))
      (is (= 3 (size as-vec))))
    (is (= 2 (first result)))
    (is (= 4 (first (rest (rest result)))))))

(test subs-vector-no-end
  "Test subs on vector with only start."
  (let* ((v (make-vector 0 1 2 3 4))
         (result (subs v 3)))
    ;; subs now returns a lazy-seq
    (is-true (<lazy-seq>? result))
    (let ((as-vec (into (make-vector) result)))
      (is (= 2 (size as-vec))))
    (is (= 3 (first result)))))

(test subs-sorted-set
  "Test subs on sorted set returns elements in range (as lazy-seq)."
  (let* ((s (make-sorted-set 1 3 5 7 9))
         (result (subs s 3 8)))
    ;; subs now returns a lazy-seq
    (is-true (<lazy-seq>? result))
    ;; Should include 3, 5, 7 (>= 3 and < 8)
    (let ((as-vec (into (make-vector) result)))
      (is (= 3 (size as-vec))))
    (is (= 3 (first result)))))

(test rsubs-vector
  "Test rsubs on vector returns elements in reverse (as lazy-seq)."
  (let* ((v (make-vector 0 1 2 3 4))
         (result (rsubs v 1 4)))
    ;; rsubs now returns a lazy-seq
    (is-true (<lazy-seq>? result))
    (let ((as-vec (into (make-vector) result)))
      (is (= 3 (size as-vec))))
    (is (= 3 (first result)))
    (is (= 1 (first (rest (rest result)))))))

(test rsubs-sorted-set
  "Test rsubs on sorted set returns elements in reverse order (as lazy-seq)."
  (let* ((s (make-sorted-set 1 3 5 7 9))
         (result (rsubs s 3 8)))
    ;; rsubs now returns a lazy-seq
    (is-true (<lazy-seq>? result))
    ;; Should include 7, 5, 3 (>= 3 and < 8, reversed)
    (let ((as-vec (into (make-vector) result)))
      (is (= 3 (size as-vec))))
    (is (= 7 (first result)))))

;;; ---------------------------------------------------------------------------
;;; sorted-set-by Tests
;;; ---------------------------------------------------------------------------

(test sorted-set-by-descending
  "Test sorted-set-by with descending order."
  (let ((s (sorted-set-by #'cl:> 3 1 4 1 5 9 2)))
    (is-true (<sorted-set-by>? s))
    (is (= 6 (size s)))
    ;; First element should be 9 (largest)
    (let ((lst (seq s)))
      (is (= 9 (first lst))))))

(test sorted-set-by-contains
  "Test contains? on sorted-set-by."
  (let ((s (sorted-set-by #'cl:> 1 2 3)))
    (is-true (contains? s 2))
    (is-false (contains? s 5))))

(test sorted-set-by-add-remove
  "Test add and remove on sorted-set-by."
  (let* ((s (sorted-set-by #'cl:> 3 1 5))
         (s2 (add s 4))
         (s3 (remove s2 3)))
    (is (= 4 (size s2)))
    (is-true (contains? s2 4))
    (is (= 3 (size s3)))
    (is-false (contains? s3 3))))

;;; ---------------------------------------------------------------------------
;;; disj Tests for New Set Types
;;; ---------------------------------------------------------------------------

(test disj-sorted-set
  "Test disj on sorted-set."
  (let* ((s (make-sorted-set 1 2 3 4 5))
         (result (disj s 2 4)))
    (is-true (<sorted-set>? result))
    (is (= 3 (size result)))
    (is-false (contains? result 2))
    (is-false (contains? result 4))))

(test disj-ordered-set
  "Test disj on ordered-set."
  (let* ((s (make-ordered-set 5 3 1 4 2))
         (result (disj s 3 4)))
    (is-true (<ordered-set>? result))
    (is (= 3 (size result)))
    ;; Order should still be 5, 1, 2
    (is (= 5 (first (seq result))))))

(test disj-int-set
  "Test disj on int-set."
  (let* ((s (make-int-set 1 2 3 4 5))
         (result (disj s 2)))
    (is-true (<int-set>? result))
    (is (= 4 (size result)))
    (is-false (contains? result 2))))

;;; ---------------------------------------------------------------------------
;;; conj Tests for New Set Types
;;; ---------------------------------------------------------------------------

(test conj-sorted-set
  "Test conj on sorted-set."
  (let* ((s (make-sorted-set 1 3 5))
         (result (conj s 2 4)))
    (is-true (<sorted-set>? result))
    (is (= 5 (size result)))
    ;; Check sorted order
    (let ((lst (seq result)))
      (is (= 1 (first lst)))
      (is (= 2 (first (rest lst)))))))

(test conj-ordered-set
  "Test conj on ordered-set preserves insertion order."
  (let* ((s (make-ordered-set 3 1))
         (result (conj s 5 2)))
    (is-true (<ordered-set>? result))
    (is (= 4 (size result)))
    ;; Order: 3, 1, 5, 2
    (let ((lst (seq result)))
      (is (= 3 (first lst)))
      (is (= 2 (first (rest (rest (rest lst)))))))))

(test conj-int-set
  "Test conj on int-set."
  (let* ((s (make-int-set 1 3))
         (result (conj s 2)))
    (is-true (<int-set>? result))
    (is (= 3 (size result)))))

;;; ===========================================================================
;;; New Clojure Sequence Function Tests
;;; ===========================================================================

;;; Helper to parse FOL syntax from strings (if not already defined)
(defun fol-form (string)
  "Parse STRING using the FOL reader and return the form.
   This allows tests to use FOL syntax like [1 2 3] and {:a 1} in test cases."
  (fol-read-from-string string))

;;; ---------------------------------------------------------------------------
;;; distinct Tests
;;; ---------------------------------------------------------------------------

(test distinct-basic
  "Test distinct removes duplicates from sequence."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (distinct [1 2 1 3 2 4 3 5]))") env)))
    (is (= 5 (size result)))
    (is (= 1 (nth result 0)))
    (is (= 2 (nth result 1)))
    (is (= 3 (nth result 2)))
    (is (= 4 (nth result 3)))
    (is (= 5 (nth result 4)))))

(test distinct-preserves-order
  "Test distinct preserves first occurrence order."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (distinct [3 1 4 1 5 9 2 6 5]))") env)))
    (is (= 3 (first (seq result))))))

(test distinct-empty
  "Test distinct on empty sequence."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (distinct []))") env)))
    (is (= 0 (size result)))))

;;; ---------------------------------------------------------------------------
;;; take-nth Tests
;;; ---------------------------------------------------------------------------

(test take-nth-basic
  "Test take-nth takes every nth element."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (take-nth 2 [0 1 2 3 4 5 6 7 8 9]))") env)))
    (is (= 5 (size result)))
    (is (= 0 (nth result 0)))
    (is (= 2 (nth result 1)))
    (is (= 4 (nth result 2)))
    (is (= 6 (nth result 3)))
    (is (= 8 (nth result 4)))))

(test take-nth-every-third
  "Test take-nth with step 3."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (take-nth 3 (range 12)))") env)))
    (is (= 4 (size result)))
    (is (= 0 (nth result 0)))
    (is (= 3 (nth result 1)))
    (is (= 6 (nth result 2)))
    (is (= 9 (nth result 3)))))

;;; ---------------------------------------------------------------------------
;;; dedupe Tests
;;; ---------------------------------------------------------------------------

(test dedupe-basic
  "Test dedupe removes consecutive duplicates."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (dedupe [1 1 2 2 2 3 3 1 1]))") env)))
    (is (= 4 (size result)))
    (is (= 1 (nth result 0)))
    (is (= 2 (nth result 1)))
    (is (= 3 (nth result 2)))
    (is (= 1 (nth result 3)))))

(test dedupe-no-consecutive
  "Test dedupe with no consecutive duplicates."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (dedupe [1 2 3 4 5]))") env)))
    (is (= 5 (size result)))))

;;; ---------------------------------------------------------------------------
;;; concat Tests
;;; ---------------------------------------------------------------------------

(test concat-two-seqs
  "Test concat joins two sequences."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (concat [1 2] [3 4]))") env)))
    (is (= 4 (size result)))
    (is (= 1 (nth result 0)))
    (is (= 4 (nth result 3)))))

(test concat-multiple-seqs
  "Test concat joins multiple sequences."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (concat [1] [2] [3] [4 5]))") env)))
    (is (= 5 (size result)))))

(test concat-empty-seqs
  "Test concat with some empty sequences."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (concat [] [1 2] [] [3]))") env)))
    (is (= 3 (size result)))))

;;; ---------------------------------------------------------------------------
;;; nthrest Tests
;;; ---------------------------------------------------------------------------

(test nthrest-basic
  "Test nthrest returns nth rest of sequence."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(first (nthrest [1 2 3 4 5] 2))") env)))
    (is (= 3 result))))

(test nthrest-zero
  "Test nthrest with n=0 returns original."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(first (nthrest [1 2 3] 0))") env)))
    (is (= 1 result))))

;;; ---------------------------------------------------------------------------
;;; next Tests
;;; ---------------------------------------------------------------------------

(test next-basic
  "Test next returns seq of items after first."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(first (next [1 2 3]))") env)))
    (is (= 2 result))))

(test next-single-element
  "Test next on single element returns nil."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(next [1])") env)))
    (is (null result))))

(test next-empty
  "Test next on empty sequence returns nil."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(next [])") env)))
    (is (null result))))

;;; ---------------------------------------------------------------------------
;;; fnext Tests
;;; ---------------------------------------------------------------------------

(test fnext-basic
  "Test fnext returns (first (next x))."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(fnext [1 2 3])") env)))
    (is (= 2 result))))

(test fnext-single
  "Test fnext on single element returns nil."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(fnext [1])") env)))
    (is (null result))))

;;; ---------------------------------------------------------------------------
;;; nnext Tests
;;; ---------------------------------------------------------------------------

(test nnext-basic
  "Test nnext returns (next (next x))."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(first (nnext [1 2 3 4]))") env)))
    (is (= 3 result))))

(test nnext-two-elements
  "Test nnext on two elements returns nil."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(nnext [1 2])") env)))
    (is (null result))))

;;; ---------------------------------------------------------------------------
;;; drop-while Tests
;;; ---------------------------------------------------------------------------

(test drop-while-basic
  "Test drop-while drops elements while predicate is true."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (drop-while (fn [x] (< x 5)) [1 2 3 4 5 6 7]))") env)))
    (is (= 3 (size result)))
    (is (= 5 (nth result 0)))
    (is (= 6 (nth result 1)))
    (is (= 7 (nth result 2)))))

(test drop-while-all-match
  "Test drop-while when all elements match."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (drop-while (fn [x] (< x 10)) [1 2 3]))") env)))
    (is (= 0 (size result)))))

(test drop-while-none-match
  "Test drop-while when no elements match."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (drop-while (fn [x] (> x 10)) [1 2 3]))") env)))
    (is (= 3 (size result)))))

;;; ---------------------------------------------------------------------------
;;; take-while Tests
;;; ---------------------------------------------------------------------------

(test take-while-basic
  "Test take-while takes elements while predicate is true."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (take-while (fn [x] (< x 5)) [1 2 3 4 5 6 7]))") env)))
    (is (= 4 (size result)))
    (is (= 1 (nth result 0)))
    (is (= 4 (nth result 3)))))

(test take-while-all-match
  "Test take-while when all elements match."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (take-while (fn [x] (< x 10)) [1 2 3]))") env)))
    (is (= 3 (size result)))))

(test take-while-none-match
  "Test take-while when no elements match."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (take-while (fn [x] (> x 10)) [1 2 3]))") env)))
    (is (= 0 (size result)))))

;;; ---------------------------------------------------------------------------
;;; take-last Tests
;;; ---------------------------------------------------------------------------

(test take-last-basic
  "Test take-last returns last n items."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (take-last 3 [1 2 3 4 5]))") env)))
    (is (= 3 (size result)))
    (is (= 3 (nth result 0)))
    (is (= 5 (nth result 2)))))

(test take-last-more-than-size
  "Test take-last with n > collection size."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (take-last 10 [1 2 3]))") env)))
    (is (= 3 (size result)))))

;;; ---------------------------------------------------------------------------
;;; drop-last Tests
;;; ---------------------------------------------------------------------------

(test drop-last-basic
  "Test drop-last removes last n items."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (drop-last 2 [1 2 3 4 5]))") env)))
    (is (= 3 (size result)))
    (is (= 1 (nth result 0)))
    (is (= 3 (nth result 2)))))

(test drop-last-default
  "Test drop-last with default n=1."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (drop-last [1 2 3 4 5]))") env)))
    (is (= 4 (size result)))))

;;; ---------------------------------------------------------------------------
;;; butlast Tests
;;; ---------------------------------------------------------------------------

(test butlast-basic
  "Test butlast returns all but last item."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (butlast [1 2 3 4 5]))") env)))
    (is (= 4 (size result)))
    (is (= 4 (nth result 3)))))

(test butlast-single
  "Test butlast on single element."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(butlast [1])") env)))
    (is (null result))))

;;; ---------------------------------------------------------------------------
;;; flatten Tests
;;; ---------------------------------------------------------------------------

(test flatten-nested-vectors
  "Test flatten flattens nested vectors."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (flatten [[1 2] [3 [4 5]]]))") env)))
    (is (= 5 (size result)))
    (is (= 1 (nth result 0)))
    (is (= 5 (nth result 4)))))

(test flatten-shallow
  "Test flatten on already flat sequence."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (flatten [1 2 3]))") env)))
    (is (= 3 (size result)))))

;;; ---------------------------------------------------------------------------
;;; partition Tests
;;; ---------------------------------------------------------------------------

(test partition-basic
  "Test partition divides sequence into groups."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (partition 3 (range 9)))") env)))
    (is (= 3 (size result)))
    (is (= 3 (size (nth result 0))))
    (is (= 0 (first (seq (nth result 0)))))))

(test partition-with-step
  "Test partition with custom step."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (partition 2 1 (range 5)))") env)))
    (is (= 4 (size result)))))

(test partition-incomplete-dropped
  "Test partition drops incomplete final group."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (partition 3 (range 10)))") env)))
    (is (= 3 (size result)))))

;;; ---------------------------------------------------------------------------
;;; partition-all Tests
;;; ---------------------------------------------------------------------------

(test partition-all-basic
  "Test partition-all includes incomplete final group."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (partition-all 3 (range 10)))") env)))
    (is (= 4 (size result)))
    (is (= 1 (size (nth result 3))))))

;;; ---------------------------------------------------------------------------
;;; partition-by Tests
;;; ---------------------------------------------------------------------------

(test partition-by-basic
  "Test partition-by splits on predicate change."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (partition-by even? [1 1 2 2 3 3 4]))") env)))
    (is (= 4 (size result)))))

;;; ---------------------------------------------------------------------------
;;; split-at Tests
;;; ---------------------------------------------------------------------------

(test split-at-basic
  "Test split-at splits sequence at index."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(split-at 3 [1 2 3 4 5])") env)))
    (is (= 2 (size result)))
    (is (= 3 (size (seq (nth result 0)))))
    (is (= 2 (size (seq (nth result 1)))))))

;;; ---------------------------------------------------------------------------
;;; split-with Tests
;;; ---------------------------------------------------------------------------

(test split-with-basic
  "Test split-with splits on predicate."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(split-with (fn [x] (< x 3)) [1 2 3 4 5])") env)))
    (is (= 2 (size result)))
    (is (= 2 (size (seq (nth result 0)))))
    (is (= 3 (size (seq (nth result 1)))))))

;;; ---------------------------------------------------------------------------
;;; shuffle Tests
;;; ---------------------------------------------------------------------------

(test shuffle-preserves-elements
  "Test shuffle preserves all elements."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(shuffle [1 2 3 4 5])") env)))
    (is (= 5 (size result)))
    (is-true (contains? result 1))
    (is-true (contains? result 5))))

;;; ---------------------------------------------------------------------------
;;; sort Tests
;;; ---------------------------------------------------------------------------

(test sort-basic
  "Test sort orders elements."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (sort [3 1 4 1 5 9 2 6]))") env)))
    (is (= 1 (nth result 0)))
    (is (= 1 (nth result 1)))
    (is (= 9 (nth result 7)))))

(test sort-with-comparator
  "Test sort with custom comparator."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (sort (fn [a b] (- b a)) [3 1 4 1 5]))") env)))
    (is (= 5 (nth result 0)))
    (is (= 1 (nth result 4)))))

;;; ---------------------------------------------------------------------------
;;; sort-by Tests
;;; ---------------------------------------------------------------------------

(test sort-by-basic
  "Test sort-by with key function."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (sort-by (fn [x] (- x)) [3 1 4 1 5]))") env)))
    ;; Sorted by negative, so descending
    (is (= 5 (nth result 0)))
    (is (= 1 (nth result 4)))))

;;; ---------------------------------------------------------------------------
;;; last Tests
;;; ---------------------------------------------------------------------------

(test last-basic
  "Test last returns last element."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(last [1 2 3 4 5])") env)))
    (is (= 5 result))))

(test last-single
  "Test last on single element."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(last [42])") env)))
    (is (= 42 result))))

(test last-empty
  "Test last on empty sequence."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(last [])") env)))
    (is (null result))))

;;; ---------------------------------------------------------------------------
;;; ffirst Tests
;;; ---------------------------------------------------------------------------

(test ffirst-basic
  "Test ffirst returns (first (first x))."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(ffirst [[1 2] [3 4]])") env)))
    (is (= 1 result))))

;;; ---------------------------------------------------------------------------
;;; nthnext Tests
;;; ---------------------------------------------------------------------------

(test nthnext-basic
  "Test nthnext returns nth next."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(first (nthnext [1 2 3 4 5] 2))") env)))
    (is (= 3 result))))

(test nthnext-zero
  "Test nthnext with n=0."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(first (nthnext [1 2 3] 0))") env)))
    (is (= 1 result))))

;;; ---------------------------------------------------------------------------
;;; max-key and min-key Tests
;;; ---------------------------------------------------------------------------

(test max-key-basic
  "Test max-key returns element with max key value."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(max-key (fn [x] (* x x)) -5 3 4)") env)))
    (is (= -5 result))))

(test min-key-basic
  "Test min-key returns element with min key value."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(min-key (fn [x] (* x x)) -5 3 4)") env)))
    (is (= 3 result))))

;;; ---------------------------------------------------------------------------
;;; zipmap Tests
;;; ---------------------------------------------------------------------------

(test zipmap-basic
  "Test zipmap creates map from keys and vals."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(zipmap [:a :b :c] [1 2 3])") env)))
    (is-true (<dict>? result))
    (is (= 1 (get result :a)))
    (is (= 2 (get result :b)))
    (is (= 3 (get result :c)))))

(test zipmap-unequal-lengths
  "Test zipmap stops at shorter sequence."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(zipmap [:a :b] [1 2 3 4])") env)))
    (is (= 2 (size result)))))

;;; ---------------------------------------------------------------------------
;;; reductions Tests
;;; ---------------------------------------------------------------------------

(test reductions-basic
  "Test reductions returns intermediate values."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (reductions + [1 2 3 4 5]))") env)))
    (is (= 5 (size result)))
    (is (= 1 (nth result 0)))
    (is (= 3 (nth result 1)))
    (is (= 6 (nth result 2)))
    (is (= 10 (nth result 3)))
    (is (= 15 (nth result 4)))))

(test reductions-with-init
  "Test reductions with initial value."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (reductions + 10 [1 2 3]))") env)))
    (is (= 4 (size result)))
    (is (= 10 (nth result 0)))
    (is (= 11 (nth result 1)))
    (is (= 13 (nth result 2)))
    (is (= 16 (nth result 3)))))

;;; ---------------------------------------------------------------------------
;;; apply Tests
;;; ---------------------------------------------------------------------------

(test apply-basic
  "Test apply calls function with seq as args."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(apply + [1 2 3])") env)))
    (is (= 6 result))))

(test apply-with-leading-args
  "Test apply with leading arguments."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(apply + 1 2 [3 4])") env)))
    (is (= 10 result))))

;;; ---------------------------------------------------------------------------
;;; doall Tests
;;; ---------------------------------------------------------------------------

(test doall-realizes-lazy-seq
  "Test doall realizes lazy sequence."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(doall (map inc [1 2 3]))") env)))
    (is-true (<lazy-seq>? result))
    (is (= 2 (first result)))))

;;; ---------------------------------------------------------------------------
;;; dorun Tests
;;; ---------------------------------------------------------------------------

(test dorun-returns-nil
  "Test dorun returns nil."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(dorun (map inc [1 2 3]))") env)))
    (is (null result))))

;;; ---------------------------------------------------------------------------
;;; realized? Tests
;;; ---------------------------------------------------------------------------

(test realized?-unrealized
  "Test realized? on unrealized lazy-seq."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(bind (ls (map inc [1 2 3]))
                              (realized? ls))") env)))
    ;; The lazy seq is created but not yet forced
    (is-false result)))

(test realized?-after-force
  "Test realized? after forcing lazy-seq."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(bind (ls (map inc [1 2 3]))
                              (first ls)
                              (realized? ls))") env)))
    (is-true result)))

;;; ---------------------------------------------------------------------------
;;; pmap Tests
;;; ---------------------------------------------------------------------------

(test pmap-basic
  "Test pmap maps function in parallel."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (pmap inc [1 2 3 4 5]))") env)))
    (is (= 5 (size result)))
    (is (= 2 (nth result 0)))
    (is (= 6 (nth result 4)))))

(test pmap-preserves-order
  "Test pmap preserves element order."
  (let* ((env (make-standard-env))
         (result (fol-eval (fol-form "(into [] (pmap (fn [x] (* x x)) [1 2 3]))") env)))
    (is (= 1 (nth result 0)))
    (is (= 4 (nth result 1)))
    (is (= 9 (nth result 2)))))
