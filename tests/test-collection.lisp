(in-package :fol.tests)

;;; ============================================================================
;;; Collection Tests - Comprehensive test suite for FOL collections
;;; ============================================================================

(def-suite* :fol.collection-tests)

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
