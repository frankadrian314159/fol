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

(test set-inherits-from-dict
  "Test that set inherits from dict (using typep, not the type predicate)."
  (let ((s (make-set 1 2)))
    (is-true (typep s '<dict>))))

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

(test bag-inherits-from-dict
  "Test that bag inherits from dict (using typep, not the type predicate)."
  (let ((b (make-bag 1 2)))
    (is-true (typep b '<dict>))))

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
          do (cl:push (current iter) collected)
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
          do (cl:push (current iter) collected)
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

(test lazy-seq-preserves-laziness
  "Test that seq on lazy-seq preserves laziness (returns lazy-seq without realizing)."
  (let* ((called nil)
         (ls (make-lazy-seq (lambda () (setf called t) (make-list 1 2 3)))))
    (is-false called)
    (let ((s (seq ls)))
      ;; seq should NOT realize the lazy-seq - it returns the lazy-seq as-is
      (is-false called)
      (is-true (<lazy-seq>? s))
      ;; Only first/rest should trigger realization
      (first s)
      (is-true called))))

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
;;; sized? Tests
;;; ---------------------------------------------------------------------------

(test sized?-collections
  "Test sized? returns T for sized collections."
  (is-true (sized? (make-vector 1 2 3)))
  (is-true (sized? (make-vector)))
  (is-true (sized? (make-list 1 2 3)))
  (is-true (sized? (make-list)))
  (is-true (sized? (make-dict :a 1 :b 2)))
  (is-true (sized? (make-dict)))
  (is-true (sized? (make-set 1 2 3)))
  (is-true (sized? (make-set)))
  (is-true (sized? (make-bag 1 2 3)))
  (is-true (sized? (make-bag))))

(test sized?-unsized
  "Test sized? returns NIL for unsized types."
  (is-false (sized? (make-lazy-seq (lambda () nil))))
  (is-false (sized? 42))
  (is-false (sized? :foo)))

(test sized?-cl-types
  "Test sized? on CL native types."
  (is-true (sized? '(1 2 3)))
  (is-true (sized? nil))
  (is-true (sized? "hello")))

;;; ---------------------------------------------------------------------------
;;; bounded-size Tests
;;; ---------------------------------------------------------------------------

(test bounded-size-sized-collections
  "Test bounded-size returns exact size for sized collections."
  (is (= 3 (bounded-size 10 (make-vector 1 2 3))))
  (is (= 0 (bounded-size 10 (make-vector))))
  (is (= 3 (bounded-size 10 (make-list 1 2 3))))
  (is (= 2 (bounded-size 10 (make-dict :a 1 :b 2))))
  (is (= 3 (bounded-size 10 (make-set 1 2 3)))))

(test bounded-size-lazy-seq
  "Test bounded-size counts at most n elements for unsized collections."
  ;; Create a lazy seq of 5 elements
  (let ((ls (make-lazy-seq
             (lambda ()
               (cl:cons 1 (make-lazy-seq
                           (lambda ()
                             (cl:cons 2 (make-lazy-seq
                                         (lambda ()
                                           (cl:cons 3 (make-lazy-seq
                                                       (lambda ()
                                                         (cl:cons 4 (make-lazy-seq
                                                                     (lambda ()
                                                                       (cl:cons 5 (make-lazy-seq
                                                                                   (lambda () nil)))))))))))))))))))
    ;; Request more than available: returns actual count
    (is (= 5 (bounded-size 10 ls)))
    ;; Request fewer than available: returns the cap
    (is (= 3 (bounded-size 3 ls)))))

;;; ---------------------------------------------------------------------------
;;; into Tests
;;; ---------------------------------------------------------------------------

(test into-no-args
  "Test (into) returns an empty vector."
  (let ((result (into)))
    (is-true (<vector>? result))
    (is (= 0 (size result)))))

(test into-one-arg
  "Test (into to) returns to unchanged."
  (let ((v (make-vector 1 2 3)))
    (is (eq v (into v))))
  (let ((d (make-dict :a 1)))
    (is (eq d (into d)))))

(test into-vector-from-list
  "Test (into vec list) conjoins list elements into vector."
  (let* ((v (make-vector 1 2))
         (lst (make-list 3 4 5))
         (result (into v lst)))
    (is-true (<vector>? result))
    (is (= 5 (size result)))
    (is (= 1 (nth result 0)))
    (is (= 2 (nth result 1)))
    (is (= 3 (nth result 2)))
    (is (= 4 (nth result 3)))
    (is (= 5 (nth result 4)))))

(test into-list-from-vector
  "Test (into list vector) conjoins vector elements into list."
  (let* ((lst (make-list))
         (v (make-vector 1 2 3))
         (result (into lst v)))
    (is-true (<list>? result))
    (is (= 3 (size result)))))

(test into-set-from-vector
  "Test (into set vector) conjoins vector elements into set."
  (let* ((s (make-set 1 2))
         (v (make-vector 2 3 4))
         (result (into s v)))
    (is-true (<set>? result))
    (is-true (contains? result 1))
    (is-true (contains? result 2))
    (is-true (contains? result 3))
    (is-true (contains? result 4))))

(test into-empty-from
  "Test (into to empty-from) returns to unchanged."
  (let* ((v (make-vector 1 2 3))
         (result (into v (make-list))))
    (is-true (<vector>? result))
    (is (= 3 (size result)))))

(test into-with-transducer
  "Test (into to xform from) applies transducer."
  ;; Use a simple mapping transducer that doubles each element
  (let* ((double-xf (lambda (rf)
                      (lambda (result input)
                        (funcall rf result (cl:* input 2)))))
         (v (make-vector))
         (lst (make-list 1 2 3))
         (result (into v double-xf lst)))
    (is-true (<vector>? result))
    (is (= 3 (size result)))
    (is (= 2 (nth result 0)))
    (is (= 4 (nth result 1)))
    (is (= 6 (nth result 2)))))

(test into-with-filtering-transducer
  "Test (into to xform from) with a filtering transducer."
  ;; Transducer that only keeps even numbers
  (let* ((even-xf (lambda (rf)
                    (lambda (result input)
                      (if (cl:evenp input)
                          (funcall rf result input)
                          result))))
         (v (make-vector))
         (lst (make-list 1 2 3 4 5 6))
         (result (into v even-xf lst)))
    (is-true (<vector>? result))
    (is (= 3 (size result)))
    (is (= 2 (nth result 0)))
    (is (= 4 (nth result 1)))
    (is (= 6 (nth result 2)))))

;;; ---------------------------------------------------------------------------
;;; vector Tests
;;; ---------------------------------------------------------------------------

(test vector-no-args
  "Test (vector) returns an empty vector."
  (let ((v (vector)))
    (is-true (<vector>? v))
    (is (= 0 (size v)))))

(test vector-with-elements
  "Test (vector a b c) returns a vector with those elements."
  (let ((v (vector 1 2 3)))
    (is-true (<vector>? v))
    (is (= 3 (size v)))
    (is (= 1 (nth v 0)))
    (is (= 2 (nth v 1)))
    (is (= 3 (nth v 2)))))

(test vector-single-element
  "Test (vector x) returns a single-element vector."
  (let ((v (vector :foo)))
    (is-true (<vector>? v))
    (is (= 1 (size v)))
    (is (eq :foo (nth v 0)))))

;;; ---------------------------------------------------------------------------
;;; vec Tests
;;; ---------------------------------------------------------------------------

(test vec-from-list
  "Test (vec list) converts a list to a vector."
  (let ((v (vec (make-list 1 2 3))))
    (is-true (<vector>? v))
    (is (= 3 (size v)))
    (is (= 1 (nth v 0)))
    (is (= 2 (nth v 1)))
    (is (= 3 (nth v 2)))))

(test vec-from-vector
  "Test (vec vector) returns the elements as a new vector."
  (let ((v (vec (make-vector 4 5 6))))
    (is-true (<vector>? v))
    (is (= 3 (size v)))
    (is (= 4 (nth v 0)))))

(test vec-from-set
  "Test (vec set) converts a set to a vector."
  (let ((v (vec (make-set 1 2 3))))
    (is-true (<vector>? v))
    (is (= 3 (size v)))))

(test vec-empty
  "Test (vec empty-coll) returns an empty vector."
  (let ((v (vec (make-list))))
    (is-true (<vector>? v))
    (is (= 0 (size v)))))

;;; ---------------------------------------------------------------------------
;;; mapv Tests
;;; ---------------------------------------------------------------------------

(test mapv-basic
  "Test mapv applies function and returns a vector."
  (let ((v (mapv #'cl:1+ (make-list 1 2 3))))
    (is-true (<vector>? v))
    (is (= 3 (size v)))
    (is (= 2 (nth v 0)))
    (is (= 3 (nth v 1)))
    (is (= 4 (nth v 2)))))

(test mapv-from-vector
  "Test mapv works on vectors."
  (let ((v (mapv (lambda (x) (cl:* x 2)) (make-vector 1 2 3))))
    (is-true (<vector>? v))
    (is (= 3 (size v)))
    (is (= 2 (nth v 0)))
    (is (= 4 (nth v 1)))
    (is (= 6 (nth v 2)))))

(test mapv-empty
  "Test mapv on empty collection returns empty vector."
  (let ((v (mapv #'cl:1+ (make-list))))
    (is-true (<vector>? v))
    (is (= 0 (size v)))))

;;; ---------------------------------------------------------------------------
;;; filterv Tests
;;; ---------------------------------------------------------------------------

(test filterv-basic
  "Test filterv filters and returns a vector."
  (let ((v (filterv #'cl:evenp (make-list 1 2 3 4 5 6))))
    (is-true (<vector>? v))
    (is (= 3 (size v)))
    (is (= 2 (nth v 0)))
    (is (= 4 (nth v 1)))
    (is (= 6 (nth v 2)))))

(test filterv-from-vector
  "Test filterv works on vectors."
  (let ((v (filterv #'cl:oddp (make-vector 1 2 3 4 5))))
    (is-true (<vector>? v))
    (is (= 3 (size v)))
    (is (= 1 (nth v 0)))
    (is (= 3 (nth v 1)))
    (is (= 5 (nth v 2)))))

(test filterv-none-match
  "Test filterv when no elements match."
  (let ((v (filterv #'cl:evenp (make-list 1 3 5))))
    (is-true (<vector>? v))
    (is (= 0 (size v)))))

(test filterv-all-match
  "Test filterv when all elements match."
  (let ((v (filterv #'cl:evenp (make-list 2 4 6))))
    (is-true (<vector>? v))
    (is (= 3 (size v)))))

;;; ---------------------------------------------------------------------------
;;; Sorted Set Tests
;;; ---------------------------------------------------------------------------

(test sorted-set-predicate
  "Test <sorted-set>? predicate."
  (is-true (<sorted-set>? (make-sorted-set)))
  (is-true (<sorted-set>? (make-sorted-set 1 2 3)))
  (is-false (<sorted-set>? (make-set 1 2 3)))
  (is-false (<sorted-set>? nil)))

(test sorted-set-creation
  "Test creating sorted sets."
  (let ((s (make-sorted-set 3 1 4 1 5 9 2 6)))
    (is-true (<sorted-set>? s))
    ;; Duplicates should be removed
    (is (= 7 (size s)))))

(test sorted-set-contains
  "Test contains? on sorted set."
  (let ((s (make-sorted-set 1 3 5 7 9)))
    (is-true (contains? s 5))
    (is-false (contains? s 4))))

(test sorted-set-get
  "Test get on sorted set returns element if present."
  (let ((s (make-sorted-set :a :b :c)))
    (is (eq :b (get s :b)))
    (is (eq nil (get s :missing)))
    (is (eq :default (get s :missing :default)))))

(test sorted-set-add-remove
  "Test add and remove on sorted set."
  (let* ((s (make-sorted-set 1 3 5))
         (s2 (add s 4))
         (s3 (remove s2 3)))
    (is (= 4 (size s2)))
    (is-true (contains? s2 4))
    (is (= 3 (size s3)))
    (is-false (contains? s3 3))))

(test sorted-set-seq
  "Test seq on sorted set returns elements in sorted order."
  (let* ((s (make-sorted-set 3 1 4 1 5 9 2))
         (lst (seq s)))
    (is-true (<list>? lst))
    ;; Elements should be in sorted order
    (is (= 1 (first lst)))))

;;; ---------------------------------------------------------------------------
;;; Ordered Set Tests
;;; ---------------------------------------------------------------------------

(test ordered-set-predicate
  "Test <ordered-set>? predicate."
  (is-true (<ordered-set>? (make-ordered-set)))
  (is-true (<ordered-set>? (make-ordered-set 1 2 3)))
  (is-false (<ordered-set>? (make-set 1 2 3))))

(test ordered-set-creation
  "Test creating ordered sets maintains insertion order."
  (let ((s (make-ordered-set 3 1 4 1 5 9)))
    (is-true (<ordered-set>? s))
    ;; Duplicates removed (1 appears twice)
    (is (= 5 (size s)))))

(test ordered-set-seq-preserves-order
  "Test seq on ordered set preserves insertion order."
  (let* ((s (make-ordered-set 3 1 4 5 9))
         (lst (seq s)))
    (is-true (<list>? lst))
    ;; First element should be 3 (first inserted)
    (is (= 3 (first lst)))
    ;; Second should be 1
    (is (= 1 (first (rest lst))))))

(test ordered-set-contains
  "Test contains? on ordered set."
  (let ((s (make-ordered-set :a :b :c)))
    (is-true (contains? s :b))
    (is-false (contains? s :d))))

(test ordered-set-get
  "Test get on ordered set."
  (let ((s (make-ordered-set :x :y :z)))
    (is (eq :y (get s :y)))
    (is (eq nil (get s :missing)))
    (is (eq :default (get s :missing :default)))))

(test ordered-set-add-remove
  "Test add and remove on ordered set."
  (let* ((s (make-ordered-set 1 2 3))
         (s2 (add s 4))
         (s3 (remove s2 2)))
    (is (= 4 (size s2)))
    (is-true (contains? s2 4))
    (is (= 3 (size s3)))
    (is-false (contains? s3 2))
    ;; Order should be preserved for remaining elements
    (let ((lst (seq s3)))
      (is (= 1 (first lst)))
      (is (= 3 (first (rest lst)))))))

;;; ---------------------------------------------------------------------------
;;; Int Set Tests
;;; ---------------------------------------------------------------------------

(test int-set-predicate
  "Test <int-set>? predicate."
  (is-true (<int-set>? (make-int-set)))
  (is-true (<int-set>? (make-int-set 1 2 3)))
  (is-false (<int-set>? (make-sorted-set 1 2 3))))

(test int-set-rejects-non-integers
  "Test that int-set rejects non-integer elements."
  (signals error (make-int-set 1 2 "three")))

(test int-set-operations
  "Test int-set operations."
  (let* ((s (make-int-set 5 3 8 1 9))
         (lst (seq s)))
    (is (= 5 (size s)))
    (is-true (contains? s 8))
    (is-false (contains? s 6))
    ;; Should be sorted
    (is (= 1 (first lst)))))

;;; ---------------------------------------------------------------------------
;;; Dense Int Set Tests
;;; ---------------------------------------------------------------------------

(test dense-int-set-predicate
  "Test <dense-int-set>? predicate."
  (is-true (<dense-int-set>? (make-dense-int-set 0 10)))
  (is-false (<dense-int-set>? (make-int-set 1 2 3))))

(test dense-int-set-creation
  "Test creating dense int sets."
  (let ((s (make-dense-int-set 0 10 1 3 5 7 9)))
    (is-true (<dense-int-set>? s))
    (is (= 5 (size s)))))

(test dense-int-set-membership
  "Test dense-int-set membership operations."
  (let ((s (make-dense-int-set 0 10 1 3 5 7 9)))
    (is-true (contains? s 1))
    (is-true (contains? s 5))
    (is-false (contains? s 2))
    (is-false (contains? s 4))))

(test dense-int-set-get
  "Test get on dense-int-set."
  (let ((s (make-dense-int-set 0 10 2 4 6 8)))
    (is (= 4 (get s 4)))
    (is (eq nil (get s 5)))
    (is (eq :default (get s 5 :default)))))

(test dense-int-set-add-remove
  "Test add and remove on dense-int-set."
  (let* ((s (make-dense-int-set 0 10 1 2 3))
         (s2 (add s 5))
         (s3 (remove s2 2)))
    (is (= 4 (size s2)))
    (is-true (contains? s2 5))
    (is (= 3 (size s3)))
    (is-false (contains? s3 2))))

(test dense-int-set-out-of-range
  "Test dense-int-set rejects out-of-range integers."
  (signals error (make-dense-int-set 0 10 15)))

(test dense-int-set-seq
  "Test seq on dense-int-set returns elements in order."
  (let* ((s (make-dense-int-set 0 10 5 2 8 1))
         (lst (seq s)))
    (is-true (<list>? lst))
    (is (= 4 (size lst)))
    ;; Should be in ascending order
    (is (= 1 (first lst)))
    (is (= 2 (first (rest lst))))))

;;; ---------------------------------------------------------------------------
;;; Set Get Tests
;;; ---------------------------------------------------------------------------

(test set-get-basic
  "Test get on regular set returns element if present."
  (let ((s (make-set :a :b :c)))
    (is (eq :b (get s :b)))
    (is (eq nil (get s :missing)))
    (is (eq :default (get s :missing :default)))))

(test set-get-with-numbers
  "Test get on set with numbers."
  (let ((s (make-set 1 2 3 4 5)))
    (is (= 3 (get s 3)))
    (is (eq nil (get s 10)))))

;;; ---------------------------------------------------------------------------
;;; Deque Tests
;;; ---------------------------------------------------------------------------

(test deque-creation-empty
  "Test creation of empty deque."
  (let ((dq (make-deque)))
    (is-true (<deque>? dq))
    (is (= 0 (size dq)))
    (is-true (empty? dq))))

(test deque-creation-with-elements
  "Test creation of deque with elements."
  (let ((dq (make-deque 1 2 3)))
    (is-true (<deque>? dq))
    (is (= 3 (size dq)))
    (is (= 1 (peek-front dq)))
    (is (= 3 (peek-end dq)))))

(test deque-peek-front
  "Test peek-front returns front element without modification."
  (let ((dq (make-deque :a :b :c)))
    (is (eq :a (peek-front dq)))
    ;; Deque unchanged
    (is (= 3 (size dq)))
    ;; Empty deque returns nil
    (is (eq nil (peek-front (make-deque))))))

(test deque-peek-end
  "Test peek-end returns end element without modification."
  (let ((dq (make-deque :a :b :c)))
    (is (eq :c (peek-end dq)))
    ;; Deque unchanged
    (is (= 3 (size dq)))
    ;; Empty deque returns nil
    (is (eq nil (peek-end (make-deque))))))

(test deque-push-front
  "Test push-front adds element at front."
  (let* ((dq1 (make-deque :b :c))
         (dq2 (push-front :a dq1)))
    ;; Original unchanged
    (is (= 2 (size dq1)))
    (is (eq :b (peek-front dq1)))
    ;; New deque has element at front
    (is (= 3 (size dq2)))
    (is (eq :a (peek-front dq2)))
    (is (eq :c (peek-end dq2)))))

(test deque-push-end
  "Test push-end adds element at end."
  (let* ((dq1 (make-deque :a :b))
         (dq2 (push-end :c dq1)))
    ;; Original unchanged
    (is (= 2 (size dq1)))
    (is (eq :b (peek-end dq1)))
    ;; New deque has element at end
    (is (= 3 (size dq2)))
    (is (eq :a (peek-front dq2)))
    (is (eq :c (peek-end dq2)))))

(test deque-pop-front
  "Test pop-front removes front element."
  (let* ((dq1 (make-deque :a :b :c))
         (dq2 (pop-front dq1)))
    ;; Original unchanged
    (is (= 3 (size dq1)))
    ;; New deque without front
    (is (= 2 (size dq2)))
    (is (eq :b (peek-front dq2)))
    (is (eq :c (peek-end dq2)))))

(test deque-pop-end
  "Test pop-end removes end element."
  (let* ((dq1 (make-deque :a :b :c))
         (dq2 (pop-end dq1)))
    ;; Original unchanged
    (is (= 3 (size dq1)))
    ;; New deque without end
    (is (= 2 (size dq2)))
    (is (eq :a (peek-front dq2)))
    (is (eq :b (peek-end dq2)))))

(test deque-pop-empty
  "Test pop on empty deque returns empty deque."
  (let ((dq (make-deque)))
    (is-true (<deque>? (pop-front dq)))
    (is-true (empty? (pop-front dq)))
    (is-true (<deque>? (pop-end dq)))
    (is-true (empty? (pop-end dq)))))

(test deque-contains
  "Test contains? on deque."
  (let ((dq (make-deque 1 2 3)))
    (is-true (contains? dq 1))
    (is-true (contains? dq 2))
    (is-true (contains? dq 3))
    (is-false (contains? dq 4))))

(test deque-get-by-index
  "Test get by index on deque."
  (let ((dq (make-deque :a :b :c)))
    (is (eq :a (get dq 0)))
    (is (eq :b (get dq 1)))
    (is (eq :c (get dq 2)))
    (is (eq nil (get dq 10)))
    (is (eq :default (get dq 10 :default)))))

(test deque-seq
  "Test seq on deque returns list from front to back."
  (let* ((dq (make-deque 1 2 3))
         (lst (seq dq)))
    (is-true (<list>? lst))
    (is (= 3 (size lst)))
    (is (= 1 (first lst)))
    (is (= 2 (first (rest lst))))
    (is (= 3 (first (rest (rest lst)))))))

(test deque-conj
  "Test conj adds to end of deque."
  (let* ((dq1 (make-deque 1 2))
         (dq2 (conj dq1 3)))
    (is (= 2 (size dq1)))
    (is (= 3 (size dq2)))
    (is (= 3 (peek-end dq2)))))

(test deque-remove
  "Test remove on deque."
  (let* ((dq1 (make-deque 1 2 3 2 4))
         (dq2 (remove dq1 2)))
    ;; Should remove first occurrence
    (is (= 4 (size dq2)))
    (is (= 1 (get dq2 0)))
    (is (= 3 (get dq2 1)))
    (is (= 2 (get dq2 2)))
    (is (= 4 (get dq2 3)))))

(test deque-standard-peek-pop-push
  "Test standard peek/pop/push operate on end (like vector)."
  (let* ((dq1 (make-deque 1 2))
         (dq2 (push 3 dq1)))
    ;; push adds to end
    (is (= 3 (peek dq2)))
    ;; pop removes from end
    (let ((dq3 (pop dq2)))
      (is (= 2 (peek dq3))))))

(test deque-first-rest
  "Test first/rest work like peek-front/pop-front."
  (let ((dq (make-deque 1 2 3)))
    (is (= 1 (first dq)))
    (let ((dq2 (rest dq)))
      (is (= 2 (first dq2)))
      (is (= 2 (size dq2))))))

(test deque-ordered-collection
  "Test deque is an ordered collection."
  (let ((dq (make-deque 1 2 3)))
    (is-true (<ordered-collection>? dq))
    (is-false (<unordered-collection>? dq))))

(test deque-print
  "Test deque print representation."
  (let ((dq (make-deque 1 2 3)))
    (is (string= "#Q[1 2 3]" (princ-to-string dq)))))

