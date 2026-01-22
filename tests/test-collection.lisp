(in-package :fol.tests)

;;; ============================================================================
;;; Collection Tests - Comprehensive test suite for FOL collections
;;; ============================================================================

(def-suite collection-suite :in fol-suite)
(def-suite* :fol.collection-tests :in collection-suite)

;;; ---------------------------------------------------------------------------
;;; Collection Base Class Tests
;;; ---------------------------------------------------------------------------

(test collection-predicate
  "Test <collection>? predicate."
  (is-true (<collection>? (make-dict)))
  (is-true (<collection>? (make-set)))
  (is-true (<collection>? (make-bag)))
  (is-true (<collection>? (make-vector)))
  (is-false (<collection>? 42))
  (is-false (<collection>? "string"))
  (is-false (<collection>? nil)))

(test collection-inheritance-hierarchy
  "Test collection class hierarchy."
  (let ((dict (make-dict))
        (set (make-set))
        (bag (make-bag))
        (vec (make-vector)))
    ;; All are collections
    (is-true (<collection>? dict))
    (is-true (<collection>? set))
    (is-true (<collection>? bag))
    (is-true (<collection>? vec))
    ;; Dict, set, bag are unordered
    (is-true (<unordered-collection>? dict))
    (is-true (<unordered-collection>? set))
    (is-true (<unordered-collection>? bag))
    (is-false (<unordered-collection>? vec))
    ;; Vector is ordered
    (is-true (<ordered-collection>? vec))
    (is-false (<ordered-collection>? dict))
    (is-false (<ordered-collection>? set))
    (is-false (<ordered-collection>? bag))))

;;; ---------------------------------------------------------------------------
;;; Dictionary Tests
;;; ---------------------------------------------------------------------------

(test dict-creation-empty
  "Test creation of empty dictionary."
  (let ((d (make-dict)))
    (is-true (<dict>? d))
    (is (= 0 (size d)))
    (is-true (empty? d))))

(test dict-creation-with-pairs
  "Test creation of dictionary with initial pairs."
  (let ((d (make-dict :a 1 :b 2 :c 3)))
    (is-true (<dict>? d))
    (is (= 3 (size d)))
    (is (= 1 (get d :a)))
    (is (= 2 (get d :b)))
    (is (= 3 (get d :c)))))

(test dict-get-default
  "Test dictionary get with default values."
  (let ((d (make-dict :x 10)))
    (is (= 10 (get d :x)))
    (is (eq nil (get d :missing)))
    (is (eq :not-found (get d :missing :not-found)))))

(test dict-get-with-wrapped-keys
  "Test dictionary get with wrapped keys."
  (let ((d (make-dict :a 1 42 "answer")))
    ;; Raw key
    (is (= 1 (get d :a)))
    ;; Wrapped key
    (is (string= "answer" (get d (wrap-number 42))))))

(test dict-add
  "Test dictionary add operation."
  (let* ((d1 (make-dict :a 1))
         (d2 (add d1 :b 2)))
    ;; Original unchanged
    (is (= 1 (size d1)))
    (is-false (contains? d1 :b))
    ;; New dict has addition
    (is (= 2 (size d2)))
    (is (= 2 (get d2 :b)))))

(test dict-add-requires-value
  "Test that dict add requires a value."
  (let ((d (make-dict)))
    (signals error (add d :key))))

(test dict-remove
  "Test dictionary remove operation."
  (let* ((d1 (make-dict :a 1 :b 2))
         (d2 (remove d1 :a)))
    ;; Original unchanged
    (is (= 2 (size d1)))
    ;; New dict has removal
    (is (= 1 (size d2)))
    (is-false (contains? d2 :a))
    (is-true (contains? d2 :b))))

(test dict-remove-nonexistent
  "Test removing nonexistent key from dictionary."
  (let* ((d1 (make-dict :a 1))
         (d2 (remove d1 :missing)))
    (is (= 1 (size d2)))))

(test dict-contains
  "Test dictionary contains? operation."
  (let ((d (make-dict :a 1 :b nil)))
    (is-true (contains? d :a))
    (is-true (contains? d :b))  ; nil value still means key exists
    (is-false (contains? d :c))))

(test dict-various-key-types
  "Test dictionary with various key types."
  (let ((d (make-dict
            :keyword 1
            'symbol 2
            "string" 3
            42 4
            #\c 5)))
    (is (= 1 (get d :keyword)))
    (is (= 2 (get d 'symbol)))
    (is (= 3 (get d "string")))
    (is (= 4 (get d 42)))
    (is (= 5 (get d #\c)))))

(test dict-various-value-types
  "Test dictionary with various value types."
  (let ((d (make-dict
            :num 42
            :str "hello"
            :bool t
            :nil nil
            :list '(1 2 3))))
    (is (= 42 (get d :num)))
    (is (string= "hello" (get d :str)))
    (is (eq t (get d :bool)))
    (is (eq nil (get d :nil)))
    (is (equal '(1 2 3) (get d :list)))))

;;; ---------------------------------------------------------------------------
;;; Set Tests
;;; ---------------------------------------------------------------------------

(test set-creation-empty
  "Test creation of empty set."
  (let ((s (make-set)))
    (is-true (<set>? s))
    (is (= 0 (size s)))
    (is-true (empty? s))))

(test set-creation-with-elements
  "Test creation of set with elements."
  (let ((s (make-set 1 2 3)))
    (is-true (<set>? s))
    (is (= 3 (size s)))
    (is-true (contains? s 1))
    (is-true (contains? s 2))
    (is-true (contains? s 3))))

(test set-deduplication
  "Test that sets deduplicate elements."
  (let ((s (make-set 1 2 1 3 2 1)))
    (is (= 3 (size s)))))

(test set-add
  "Test set add operation."
  (let* ((s1 (make-set 1 2))
         (s2 (add s1 3)))
    (is (= 2 (size s1)))
    (is (= 3 (size s2)))
    (is-true (contains? s2 3))))

(test set-add-duplicate
  "Test that adding duplicate to set is idempotent."
  (let* ((s1 (make-set 1 2))
         (s2 (add s1 1)))
    (is (= 2 (size s2)))))

(test set-remove
  "Test set remove operation."
  (let* ((s1 (make-set 1 2 3))
         (s2 (remove s1 2)))
    (is (= 3 (size s1)))
    (is (= 2 (size s2)))
    (is-false (contains? s2 2))))

(test set-is-dict
  "Test that set inherits from dict."
  (let ((s (make-set 1 2)))
    (is-true (<dict>? s))))

;;; ---------------------------------------------------------------------------
;;; Bag (Multiset) Tests
;;; ---------------------------------------------------------------------------

(test bag-creation-empty
  "Test creation of empty bag."
  (let ((b (make-bag)))
    (is-true (<bag>? b))
    (is (= 0 (size b)))
    (is-true (empty? b))))

(test bag-creation-with-elements
  "Test creation of bag with elements."
  (let ((b (make-bag :a :b :a :c :a)))
    (is-true (<bag>? b))
    ;; Size is number of unique keys
    (is (= 3 (size b)))))

(test bag-counts-elements
  "Test that bag counts element occurrences."
  (let ((b (make-bag :a :a :a :b :b :c)))
    ;; Get retrieves the count
    (is (= 3 (get b :a)))
    (is (= 2 (get b :b)))
    (is (= 1 (get b :c)))))

(test bag-add
  "Test bag add increments count."
  (let* ((b1 (make-bag :a :a))
         (b2 (add b1 :a)))
    (is (= 2 (get b1 :a)))
    (is (= 3 (get b2 :a)))))

(test bag-add-new-element
  "Test adding new element to bag."
  (let* ((b1 (make-bag :a))
         (b2 (add b1 :b)))
    (is (= 1 (get b2 :a)))
    (is (= 1 (get b2 :b)))))

(test bag-remove-decrements
  "Test bag remove decrements count."
  (let* ((b1 (make-bag :a :a :a))
         (b2 (remove b1 :a)))
    (is (= 3 (get b1 :a)))
    (is (= 2 (get b2 :a)))))

(test bag-remove-eliminates
  "Test bag remove eliminates element when count reaches zero."
  (let* ((b1 (make-bag :a))
         (b2 (remove b1 :a)))
    (is (= 1 (get b1 :a)))
    (is (eq nil (get b2 :a)))))

(test bag-remove-nonexistent
  "Test removing nonexistent element from bag."
  (let* ((b1 (make-bag :a))
         (b2 (remove b1 :missing)))
    (is (eq b1 b2))))  ; Returns same bag if element not found

(test bag-is-dict
  "Test that bag inherits from dict."
  (let ((b (make-bag 1 2)))
    (is-true (<dict>? b))))

;;; ---------------------------------------------------------------------------
;;; Vector Tests
;;; ---------------------------------------------------------------------------

(test vector-creation-empty
  "Test creation of empty vector."
  (let ((v (make-vector)))
    (is-true (<vector>? v))
    (is (= 0 (size v)))
    (is-true (empty? v))))

(test vector-creation-with-elements
  "Test creation of vector with elements."
  (let ((v (make-vector 1 2 3)))
    (is-true (<vector>? v))
    (is (= 3 (size v)))))

(test vector-get-by-index
  "Test vector get by index."
  (let ((v (make-vector :a :b :c)))
    (is (eq :a (get v 0)))
    (is (eq :b (get v 1)))
    (is (eq :c (get v 2)))))

(test vector-get-wrapped-index
  "Test vector get with wrapped index."
  (let ((v (make-vector :a :b :c)))
    (is (eq :b (get v (wrap-number 1))))))

(test vector-get-out-of-bounds
  "Test vector get with out of bounds index."
  (let ((v (make-vector 1 2 3)))
    (is (eq nil (get v 10)))
    (is (eq :default (get v 10 :default)))
    (is (eq nil (get v -1)))))

(test vector-add
  "Test vector add appends to end."
  (let* ((v1 (make-vector 1 2))
         (v2 (add v1 3)))
    (is (= 2 (size v1)))
    (is (= 3 (size v2)))
    (is (= 3 (get v2 2)))))

(test vector-remove
  "Test vector remove by value."
  (let* ((v1 (make-vector :a :b :c))
         (v2 (remove v1 :b)))
    (is (= 3 (size v1)))
    (is (= 2 (size v2)))
    (is (eq :a (get v2 0)))
    (is (eq :c (get v2 1)))))

(test vector-remove-nonexistent
  "Test removing nonexistent element from vector."
  (let* ((v1 (make-vector 1 2 3))
         (v2 (remove v1 99)))
    (is (= 3 (size v2)))))

(test vector-contains
  "Test vector contains? operation."
  (let ((v (make-vector 1 2 3)))
    (is-true (contains? v 1))
    (is-true (contains? v 2))
    (is-true (contains? v 3))
    (is-false (contains? v 4))))

(test vector-nth-element
  "Test vector nth-element operation."
  (let ((v (make-vector :a :b :c)))
    (is (eq :a (nth-element v 0)))
    (is (eq :b (nth-element v 1)))
    (is (eq :c (nth-element v 2)))
    (is (eq nil (nth-element v 10)))))

(test vector-set-nth
  "Test vector set-nth operation."
  (let* ((v1 (make-vector 1 2 3))
         (v2 (set-nth v1 1 :new)))
    (is (= 2 (get v1 1)))
    (is (eq :new (get v2 1)))))

(test vector-set-nth-out-of-bounds
  "Test vector set-nth with out of bounds index."
  (let ((v (make-vector 1 2 3)))
    (signals error (set-nth v 10 :value))))

(test vector-preserves-order
  "Test that vector preserves element order."
  (let ((v (make-vector 3 1 4 1 5 9)))
    (is (= 3 (get v 0)))
    (is (= 1 (get v 1)))
    (is (= 4 (get v 2)))
    (is (= 1 (get v 3)))
    (is (= 5 (get v 4)))
    (is (= 9 (get v 5)))))

;;; ---------------------------------------------------------------------------
;;; Array Tests
;;; ---------------------------------------------------------------------------

(test array-creation
  "Test creation of array."
  (let* ((dims (make-vector 2 3))
         (arr (make-array dims 1 2 3 4 5 6)))
    (is-true (<array>? arr))
    (is-true (<vector>? arr))))  ; Arrays inherit from vectors

(test array-get-2d
  "Test 2D array get with column-major order."
  ;; 2x2 array: [[A,C],[B,D]] in column-major
  ;; Flat: A B C D
  ;; [0,0]=A, [1,0]=B, [0,1]=C, [1,1]=D
  (let* ((dims (make-vector 2 2))
         (arr (make-array dims 'a 'b 'c 'd)))
    (is (eq 'a (get arr (make-vector 0 0))))
    (is (eq 'b (get arr (make-vector 1 0))))
    (is (eq 'c (get arr (make-vector 0 1))))
    (is (eq 'd (get arr (make-vector 1 1))))))

(test array-get-out-of-bounds
  "Test array get with out of bounds indices."
  (let* ((dims (make-vector 2 2))
         (arr (make-array dims 1 2 3 4)))
    (is (eq nil (get arr (make-vector 2 0))))
    (is (eq :default (get arr (make-vector 2 0) :default)))))

(test array-get-rank-mismatch
  "Test array get with wrong number of indices."
  (let* ((dims (make-vector 2 2))
         (arr (make-array dims 1 2 3 4)))
    (is (eq :mismatch (get arr (make-vector 0) :mismatch)))
    (is (eq :mismatch (get arr (make-vector 0 0 0) :mismatch)))))

(test array-add-error
  "Test that add is not allowed on arrays."
  (let* ((dims (make-vector 2 2))
         (arr (make-array dims 1 2 3 4)))
    (signals error (add arr 5))))

;;; ---------------------------------------------------------------------------
;;; Iterator Tests
;;; ---------------------------------------------------------------------------

(test iterator-vector
  "Test iterator on vector."
  (let* ((v (make-vector 10 20 30))
         (iter (iterator v)))
    (is-false (done? iter))
    (is (= 10 (current iter)))
    (next iter)
    (is (= 20 (current iter)))
    (next iter)
    (is (= 30 (current iter)))
    (next iter)
    (is-true (done? iter))))

(test iterator-dict
  "Test iterator on dictionary."
  (let* ((d (make-dict :a 1))
         (iter (iterator d)))
    (is-false (done? iter))
    ;; Dict iterator returns keys
    (is-true (consp (current iter)))
    (next iter)
    (is-true (done? iter))))

(test iterator-empty-collection
  "Test iterator on empty collection."
  (let* ((v (make-vector))
         (iter (iterator v)))
    (is-true (done? iter))))

(test iterator-collect-all
  "Test collecting all elements via iterator."
  (let* ((v (make-vector 1 2 3 4 5))
         (iter (iterator v))
         (collected '()))
    (loop until (done? iter)
          do (push (current iter) collected)
             (next iter))
    (is (equal '(5 4 3 2 1) collected))))

;;; ---------------------------------------------------------------------------
;;; Generic Operations Tests
;;; ---------------------------------------------------------------------------

(test size-all-collections
  "Test size operation on all collection types."
  (is (= 0 (size (make-dict))))
  (is (= 2 (size (make-dict :a 1 :b 2))))
  (is (= 0 (size (make-set))))
  (is (= 3 (size (make-set 1 2 3))))
  (is (= 0 (size (make-bag))))
  (is (= 2 (size (make-bag :a :a :b))))  ; 2 unique
  (is (= 0 (size (make-vector))))
  (is (= 4 (size (make-vector 1 2 3 4)))))

(test empty-all-collections
  "Test empty? operation on all collection types."
  (is-true (empty? (make-dict)))
  (is-false (empty? (make-dict :a 1)))
  (is-true (empty? (make-set)))
  (is-false (empty? (make-set 1)))
  (is-true (empty? (make-bag)))
  (is-false (empty? (make-bag :a)))
  (is-true (empty? (make-vector)))
  (is-false (empty? (make-vector 1))))

;;; ---------------------------------------------------------------------------
;;; Immutability Tests
;;; ---------------------------------------------------------------------------

(test dict-immutability
  "Test that dict operations don't mutate original."
  (let* ((d1 (make-dict :a 1))
         (d2 (add d1 :b 2))
         (d3 (remove d1 :a)))
    (is (= 1 (size d1)))
    (is (= 2 (size d2)))
    (is (= 0 (size d3)))))

(test vector-immutability
  "Test that vector operations don't mutate original."
  (let* ((v1 (make-vector 1 2 3))
         (v2 (add v1 4))
         (v3 (remove v1 2))
         (v4 (set-nth v1 0 99)))
    (is (= 3 (size v1)))
    (is (= 1 (get v1 0)))
    (is (= 4 (size v2)))
    (is (= 2 (size v3)))
    (is (= 99 (get v4 0)))))

;;; ---------------------------------------------------------------------------
;;; Wrapped Value Tests
;;; ---------------------------------------------------------------------------

(test collections-store-raw-values
  "Test that collections store raw CL values."
  (let* ((wrapped-num (wrap-number 42))
         (d (make-dict :key wrapped-num)))
    ;; Value should be stored as raw 42, not wrapped
    (is (= 42 (get d :key)))
    (is (numberp (get d :key)))))

(test collections-accept-wrapped-keys
  "Test that collections accept wrapped keys."
  (let* ((wrapped-key (wrap-symbol :test))
         (d (make-dict wrapped-key "value")))
    ;; Should be able to retrieve using raw key
    (is (string= "value" (get d :test)))))

;;; ---------------------------------------------------------------------------
;;; List Tests
;;; ---------------------------------------------------------------------------

(test list-predicate
  "Test <list>? predicate."
  (is-true (<list>? (make-list)))
  (is-true (<list>? (make-list 1 2 3)))
  (is-false (<list>? (make-vector)))
  (is-false (<list>? '(1 2 3)))  ; CL list is not FOL list
  (is-false (<list>? nil)))

(test list-creation-empty
  "Test creation of empty list."
  (let ((lst (make-list)))
    (is-true (<list>? lst))
    (is (= 0 (size lst)))
    (is-true (empty? lst))))

(test list-creation-with-elements
  "Test creation of list with elements."
  (let ((lst (make-list 1 2 3)))
    (is-true (<list>? lst))
    (is (= 3 (size lst)))
    (is (= 1 (first lst)))
    (is (= 2 (first (rest lst))))
    (is (= 3 (first (rest (rest lst)))))))

(test list-is-ordered-collection
  "Test that list is an ordered collection."
  (let ((lst (make-list 1 2 3)))
    (is-true (<ordered-collection>? lst))
    (is-true (<collection>? lst))
    (is-false (<unordered-collection>? lst))))

(test list-size-o1
  "Test that list size is O(1) - stored in slot."
  (let ((lst (make-list 1 2 3 4 5)))
    ;; Size is directly accessible from slot
    (is (= 5 (size lst)))
    (is (= 5 (list-size lst)))))

(test list-first-operation
  "Test first operation."
  (let ((lst (make-list :a :b :c)))
    (is (eq :a (first lst))))
  ;; First of empty list is nil
  (let ((empty (make-list)))
    (is (eq nil (first empty)))))

(test list-rest-operation
  "Test rest operation."
  (let ((lst (make-list 1 2 3)))
    (let ((rst (rest lst)))
      (is-true (<list>? rst))
      (is (= 2 (size rst)))
      (is (= 2 (first rst)))))
  ;; Rest of empty list is empty list
  (let ((empty (make-list)))
    (let ((rst (rest empty)))
      (is-true (<list>? rst))
      (is (= 0 (size rst))))))

(test list-cons-operation
  "Test conj operation."
  (let* ((lst (make-list 2 3))
         (new-lst (conj lst 1)))
    (is (= 3 (size new-lst)))
    (is (= 1 (first new-lst)))
    (is (= 2 (first (rest new-lst))))
    ;; Original unchanged
    (is (= 2 (size lst)))))

(test list-cons-to-empty
  "Test conj to empty list."
  (let* ((empty (make-list))
         (lst (conj empty :first)))
    (is (= 1 (size lst)))
    (is (eq :first (first lst)))))

(test list-add-is-cons
  "Test that add on list prepends (like cons)."
  (let* ((lst (make-list 2 3))
         (new-lst (add lst 1)))
    (is (= 3 (size new-lst)))
    (is (= 1 (first new-lst)))))

(test list-remove
  "Test list remove operation."
  (let* ((lst (make-list 1 2 3 2 4))
         (removed (remove lst 2)))
    ;; Removes first occurrence only
    (is (= 4 (size removed)))
    (is (= 1 (first removed)))
    (is (= 3 (first (rest removed))))
    ;; Original unchanged
    (is (= 5 (size lst)))))

(test list-remove-nonexistent
  "Test removing nonexistent element from list."
  (let* ((lst (make-list 1 2 3))
         (removed (remove lst 99)))
    (is (= 3 (size removed)))))

(test list-remove-from-empty
  "Test removing from empty list."
  (let* ((empty (make-list))
         (removed (remove empty 1)))
    (is (= 0 (size removed)))))

(test list-contains
  "Test list contains? operation."
  (let ((lst (make-list 1 2 3)))
    (is-true (contains? lst 1))
    (is-true (contains? lst 2))
    (is-true (contains? lst 3))
    (is-false (contains? lst 4))))

(test list-contains-empty
  "Test contains? on empty list."
  (let ((empty (make-list)))
    (is-false (contains? empty 1))))

(test list-get-by-index
  "Test list get by index."
  (let ((lst (make-list :a :b :c)))
    (is (eq :a (get lst 0)))
    (is (eq :b (get lst 1)))
    (is (eq :c (get lst 2)))))

(test list-get-out-of-bounds
  "Test list get with out of bounds index."
  (let ((lst (make-list 1 2 3)))
    (is (eq nil (get lst 10)))
    (is (eq :default (get lst 10 :default)))
    (is (eq nil (get lst -1)))))

(test list-nth-element
  "Test list nth-element operation."
  (let ((lst (make-list :a :b :c)))
    (is (eq :a (nth-element lst 0)))
    (is (eq :b (nth-element lst 1)))
    (is (eq :c (nth-element lst 2)))
    (is (eq nil (nth-element lst 10)))))

(test list-iterator
  "Test iterator on list."
  (let* ((lst (make-list 10 20 30))
         (iter (iterator lst)))
    (is-false (done? iter))
    (is (= 10 (current iter)))
    (next iter)
    (is (= 20 (current iter)))
    (next iter)
    (is (= 30 (current iter)))
    (next iter)
    (is-true (done? iter))))

(test list-iterator-empty
  "Test iterator on empty list."
  (let* ((empty (make-list))
         (iter (iterator empty)))
    (is-true (done? iter))))

(test list-iterator-collect-all
  "Test collecting all elements via list iterator."
  (let* ((lst (make-list 1 2 3 4 5))
         (iter (iterator lst))
         (collected '()))
    (loop until (done? iter)
          do (push (current iter) collected)
             (next iter))
    (is (equal '(5 4 3 2 1) collected))))

(test list-preserves-order
  "Test that list preserves element order."
  (let ((lst (make-list 3 1 4 1 5 9)))
    (is (= 3 (get lst 0)))
    (is (= 1 (get lst 1)))
    (is (= 4 (get lst 2)))
    (is (= 1 (get lst 3)))
    (is (= 5 (get lst 4)))
    (is (= 9 (get lst 5)))))

(test list-immutability
  "Test that list operations don't mutate original."
  (let* ((lst1 (make-list 1 2 3))
         (lst2 (conj lst1 0))
         (lst3 (rest lst1))
         (lst4 (add lst1 :new))
         (lst5 (remove lst1 2)))
    (is (= 3 (size lst1)))
    (is (= 1 (first lst1)))
    (is (= 4 (size lst2)))
    (is (= 2 (size lst3)))
    (is (= 4 (size lst4)))
    (is (= 2 (size lst5)))))

(test list-stores-raw-values
  "Test that list stores raw CL values."
  (let* ((wrapped-num (wrap-number 42))
         (lst (make-list wrapped-num)))
    ;; Value should be stored as raw 42, not wrapped
    (is (= 42 (first lst)))
    (is (numberp (first lst)))))

(test list-various-element-types
  "Test list with various element types."
  (let ((lst (make-list 42 "hello" :keyword 'symbol #\c)))
    (is (= 5 (size lst)))
    (is (= 42 (get lst 0)))
    (is (string= "hello" (get lst 1)))
    (is (eq :keyword (get lst 2)))
    (is (eq 'symbol (get lst 3)))
    (is (char= #\c (get lst 4)))))

(test list-nested-structure
  "Test list with nested lists."
  (let* ((inner (make-list 1 2))
         (outer (make-list inner 3)))
    (is (= 2 (size outer)))
    (is-true (<list>? (first outer)))
    (is (= 2 (size (first outer))))))

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
;;; Lazy Sequence Tests
;;; ---------------------------------------------------------------------------

(test lazy-seq-predicate
  "Test <lazy-seq>? predicate."
  (let ((ls (make-lazy-seq (lambda () (make-list 1 2 3)))))
    (is-true (<lazy-seq>? ls))
    (is-false (<lazy-seq>? (make-list 1 2 3)))
    (is-false (<lazy-seq>? nil))))

(test lazy-seq-not-realized-initially
  "Test that lazy-seq is not realized on creation."
  (let* ((called nil)
         (ls (make-lazy-seq (lambda () (setf called t) (make-list 1 2 3)))))
    (is-false (lazy-seq-realized-p ls))
    (is-false called)))

(test lazy-seq-realized-on-first
  "Test that lazy-seq is realized when first is called."
  (let* ((called nil)
         (ls (make-lazy-seq (lambda () (setf called t) (make-list 1 2 3)))))
    (is-false called)
    (is (= 1 (first ls)))
    (is-true called)
    (is-true (lazy-seq-realized-p ls))))

(test lazy-seq-realized-on-rest
  "Test that lazy-seq is realized when rest is called."
  (let* ((called nil)
         (ls (make-lazy-seq (lambda () (setf called t) (make-list 1 2 3)))))
    (is-false called)
    (let ((rst (rest ls)))
      (is-true called)
      (is-true (<list>? rst))
      (is (= 2 (first rst))))))

(test lazy-seq-realized-on-seq
  "Test that lazy-seq is realized when seq is called."
  (let* ((called nil)
         (ls (make-lazy-seq (lambda () (setf called t) (make-list 1 2 3)))))
    (is-false called)
    (let ((s (seq ls)))
      (is-true called)
      (is-true (<list>? s)))))

(test lazy-seq-cached-result
  "Test that lazy-seq caches the result after realization."
  (let* ((call-count 0)
         (ls (make-lazy-seq (lambda () (incf call-count) (make-list 1 2 3)))))
    ;; First access
    (first ls)
    (is (= 1 call-count))
    ;; Second access - should use cached result
    (first ls)
    (is (= 1 call-count))
    ;; Third access
    (rest ls)
    (is (= 1 call-count))))

(test lazy-seq-empty
  "Test lazy-seq that produces empty sequence."
  (let ((ls (make-lazy-seq (lambda () nil))))
    (is-true (empty? ls))
    (is (eq nil (seq ls)))
    (is (eq nil (first ls)))))

(test lazy-seq-nested
  "Test lazy-seq that returns another lazy-seq."
  (let* ((inner (make-lazy-seq (lambda () (make-list 1 2 3))))
         (outer (make-lazy-seq (lambda () inner))))
    ;; Outer returns inner lazy-seq, which should be automatically realized
    (is (= 1 (first outer)))
    (is (= 3 (size outer)))))

(test lazy-seq-cons
  "Test conj onto a lazy-seq."
  (let* ((ls (make-lazy-seq (lambda () (make-list 2 3))))
         (consed (conj ls 1)))
    ;; Consing onto lazy-seq returns a CL cons cell for efficiency
    ;; (the lazy-seq is only realized when its elements are accessed)
    (is-true (consp consed))
    ;; first returns the consed item
    (is (= 1 (first consed)))
    ;; rest returns the lazy-seq, and first on that realizes it
    (is-true (<lazy-seq>? (rest consed)))
    (is (= 2 (first (rest consed))))))

(test lazy-seq-size
  "Test size on lazy-seq (realizes entire sequence)."
  (let ((ls (make-lazy-seq (lambda () (make-list 1 2 3 4 5)))))
    (is (= 5 (size ls)))))

(test lazy-seq-contains
  "Test contains? on lazy-seq."
  (let ((ls (make-lazy-seq (lambda () (make-list 1 2 3)))))
    (is-true (contains? ls 2))
    (is-false (contains? ls 5))))

(test lazy-seq-iterator
  "Test iterator on lazy-seq."
  (let* ((ls (make-lazy-seq (lambda () (make-list 10 20 30))))
         (iter (iterator ls)))
    (is-false (done? iter))
    (is (= 10 (current iter)))
    (next iter)
    (is (= 20 (current iter)))
    (next iter)
    (is (= 30 (current iter)))
    (next iter)
    (is-true (done? iter))))

(test lazy-seq-print-unrealized
  "Test that unrealized lazy-seq prints specially."
  (let ((ls (make-lazy-seq (lambda () (make-list 1 2 3)))))
    (is (search "unrealized" (format nil "~A" ls)))))

(test lazy-seq-print-realized
  "Test that realized lazy-seq prints its contents."
  (let ((ls (make-lazy-seq (lambda () (make-list 1 2 3)))))
    ;; Realize it
    (first ls)
    ;; Should print like a list
    (let ((printed (format nil "~A" ls)))
      (is (search "1" printed))
      (is (search "2" printed))
      (is (search "3" printed)))))

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
         (result (conj d (cons :b 2))))
    (is (= 2 (size result)))
    (is (= 1 (get result :a)))
    (is (= 2 (get result :b)))))

(test conj-dict-multiple
  "Test conj with multiple pairs on dict."
  (let* ((d (make-dict))
         (result (conj d (cons :a 1) (cons :b 2) (cons :c 3))))
    (is (= 3 (size result)))
    (is (= 1 (get result :a)))
    (is (= 2 (get result :b)))
    (is (= 3 (get result :c)))))

(test conj-dict-update
  "Test conj updates existing key in dict."
  (let* ((d (make-dict :a 1))
         (result (conj d (cons :a 100))))
    (is (= 1 (size result)))
    (is (= 100 (get result :a)))))

(test conj-dict-requires-pair
  "Test conj on dict requires cons pair."
  (let ((d (make-dict)))
    (signals error
      (conj d :not-a-pair))))

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
