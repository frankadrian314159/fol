;;; FOL Parallel Collections Tests
;;;
;;; Tests for all functions in fol.lib.parallel.
;;; Each test submits real work to the thread pool so ordering of results
;;; is verified against input order, not wall-clock completion order.

(in-package :fol.compiler.tests.lib)
(in-suite parallel-tests)

;;; ---------------------------------------------------------------------------
;;; Helpers
;;; ---------------------------------------------------------------------------

;;; Aliases for verbose qualified names.
(defun par (sym) (intern (symbol-name sym) :fol.lib.parallel))
(defun mk-vec (&rest elems)
  (apply #'fol.compiler.collections:make 'fol.compiler.collections:<vector> elems))
(defun mk-set (&rest elems)
  (apply #'fol.compiler.collections:make 'fol.compiler.collections:<set> elems))
(defun vec->list (v)
  (fol.compiler.collections:collection-seq v))
(defun vec-ref (v i)
  (fol.compiler.collection-functions:get v i))
(defun vec-size (v)
  (fol.compiler.collections:collection-size v))

;;; Simple predicates that the thread pool can call safely.
(defun even-p (x) (evenp x))
(defun odd-p  (x) (oddp  x))
(defun pos-p  (x) (> x 0))

;;; ---------------------------------------------------------------------------
;;; pfilter
;;; ---------------------------------------------------------------------------

(test pfilter-basic
  "pfilter returns elements satisfying the predicate in original order."
  (let* ((v      (mk-vec 1 2 3 4 5 6))
         (result (fol.lib.parallel:pfilter #'even-p v)))
    (is (equal '(2 4 6) (vec->list result)))))

(test pfilter-none-match
  "pfilter returns an empty collection when no elements match."
  (let* ((v      (mk-vec 1 3 5))
         (result (fol.lib.parallel:pfilter #'even-p v)))
    (is (= 0 (vec-size result)))))

(test pfilter-all-match
  "pfilter returns all elements when all match."
  (let* ((v      (mk-vec 2 4 6))
         (result (fol.lib.parallel:pfilter #'even-p v)))
    (is (equal '(2 4 6) (vec->list result)))))

(test pfilter-preserves-type
  "pfilter returns a collection of the same type as the input."
  (let* ((s      (mk-set 1 2 3 4 5))
         (result (fol.lib.parallel:pfilter #'even-p s)))
    (is (typep result 'fol.compiler.collections:<set>))))

(test pfilter-large
  "pfilter is correct on a large input (exercises thread pool scheduling)."
  (let* ((data   (loop for i from 1 to 200 collect i))
         (v      (apply #'mk-vec data))
         (result (fol.lib.parallel:pfilter #'even-p v))
         (lst    (vec->list result)))
    (is (= 100 (length lst)))
    (is (every #'evenp lst))))

;;; ---------------------------------------------------------------------------
;;; pgroup-by
;;; ---------------------------------------------------------------------------

(test pgroup-by-basic
  "pgroup-by groups elements by key function."
  (let* ((v      (mk-vec 1 2 3 4 5))
         (result (fol.lib.parallel:pgroup-by #'even-p v)))
    (is (typep result 'fol.compiler.collections:<dict>))
    (let ((evens (vec->list (fol.compiler.collection-functions:get result t)))
          (odds  (vec->list (fol.compiler.collection-functions:get result nil))))
      (is (null (set-difference evens '(2 4))))
      (is (null (set-difference odds  '(1 3 5)))))))

(test pgroup-by-single-group
  "pgroup-by with constant key produces one group containing all elements."
  (let* ((v      (mk-vec :a :b :c))
         (result (fol.lib.parallel:pgroup-by (lambda (x) (declare (ignore x)) :all) v))
         (group  (fol.compiler.collection-functions:get result :all)))
    (is (= 3 (vec-size group)))))

(test pgroup-by-each-unique
  "pgroup-by with identity key produces one group per element."
  (let* ((v      (mk-vec 10 20 30))
         (result (fol.lib.parallel:pgroup-by #'identity v)))
    (is (= 1 (vec-size (fol.compiler.collection-functions:get result 10))))
    (is (= 1 (vec-size (fol.compiler.collection-functions:get result 20))))
    (is (= 1 (vec-size (fol.compiler.collection-functions:get result 30))))))

;;; ---------------------------------------------------------------------------
;;; ppartition
;;; ---------------------------------------------------------------------------

(test ppartition-basic
  "ppartition splits a collection into passing and failing groups."
  (let* ((v      (mk-vec 1 2 3 4 5))
         (result (fol.lib.parallel:ppartition #'even-p v))
         (pass   (vec->list (vec-ref result 0)))
         (fail   (vec->list (vec-ref result 1))))
    (is (null (set-difference pass '(2 4))))
    (is (null (set-difference fail '(1 3 5))))))

(test ppartition-returns-two-element-vector
  "ppartition always returns a two-element vector."
  (let ((result (fol.lib.parallel:ppartition #'even-p (mk-vec 1 2 3))))
    (is (= 2 (vec-size result)))))

(test ppartition-all-pass
  "ppartition with all-matching pred returns empty fail group."
  (let* ((result (fol.lib.parallel:ppartition #'even-p (mk-vec 2 4 6)))
         (fail   (vec-ref result 1)))
    (is (= 0 (vec-size fail)))))

(test ppartition-none-pass
  "ppartition with no-matching pred returns empty pass group."
  (let* ((result (fol.lib.parallel:ppartition #'even-p (mk-vec 1 3 5)))
         (pass   (vec-ref result 0)))
    (is (= 0 (vec-size pass)))))

(test ppartition-preserves-group-type
  "ppartition sub-collections are the same type as the input."
  (let* ((v      (mk-vec 1 2 3))
         (result (fol.lib.parallel:ppartition #'odd-p v)))
    (is (typep (vec-ref result 0) 'fol.compiler.collections:<vector>))
    (is (typep (vec-ref result 1) 'fol.compiler.collections:<vector>))))

;;; ---------------------------------------------------------------------------
;;; pzip
;;; ---------------------------------------------------------------------------

(test pzip-basic
  "pzip pairs corresponding elements from two collections."
  (let* ((a      (mk-vec 1 2 3))
         (b      (mk-vec :x :y :z))
         (result (fol.lib.parallel:pzip a b)))
    (is (= 3 (vec-size result)))
    (is (= 1   (vec-ref (vec-ref result 0) 0)))
    (is (eq :x (vec-ref (vec-ref result 0) 1)))
    (is (= 2   (vec-ref (vec-ref result 1) 0)))
    (is (eq :y (vec-ref (vec-ref result 1) 1)))))

(test pzip-stops-at-shorter
  "pzip stops at the shorter of the two collections."
  (let* ((result (fol.lib.parallel:pzip (mk-vec 1 2) (mk-vec :a :b :c))))
    (is (= 2 (vec-size result)))))

(test pzip-empty
  "pzip of empty collections returns empty vector."
  (let ((result (fol.lib.parallel:pzip (mk-vec) (mk-vec))))
    (is (= 0 (vec-size result)))))

(test pzip-pairs-are-two-element-vectors
  "Each element produced by pzip is a two-element vector."
  (let* ((result (fol.lib.parallel:pzip (mk-vec 10 20) (mk-vec 100 200))))
    (dotimes (i (vec-size result))
      (is (= 2 (vec-size (vec-ref result i)))))))

;;; ---------------------------------------------------------------------------
;;; pzip-with-index
;;; ---------------------------------------------------------------------------

(test pzip-with-index-basic
  "pzip-with-index pairs each element with its zero-based index."
  (let* ((v      (mk-vec :a :b :c))
         (result (fol.lib.parallel:pzip-with-index v)))
    (is (= 3 (vec-size result)))
    (is (eq :a (vec-ref (vec-ref result 0) 0)))
    (is (=  0  (vec-ref (vec-ref result 0) 1)))
    (is (eq :b (vec-ref (vec-ref result 1) 0)))
    (is (=  1  (vec-ref (vec-ref result 1) 1)))
    (is (eq :c (vec-ref (vec-ref result 2) 0)))
    (is (=  2  (vec-ref (vec-ref result 2) 1)))))

(test pzip-with-index-preserves-order
  "pzip-with-index assigns indices matching input position."
  (let* ((data   (loop for i from 10 to 19 collect i))
         (v      (apply #'mk-vec data))
         (result (fol.lib.parallel:pzip-with-index v)))
    (dotimes (i 10)
      (is (= (+ 10 i) (vec-ref (vec-ref result i) 0)))
      (is (= i        (vec-ref (vec-ref result i) 1))))))

;;; ---------------------------------------------------------------------------
;;; pforeach
;;; ---------------------------------------------------------------------------

(test pforeach-returns-nil
  "pforeach always returns nil."
  (is (eq nil (fol.lib.parallel:pforeach #'identity (mk-vec 1 2 3)))))

(test pforeach-calls-fn-for-every-element
  "pforeach invokes the function for every element."
  (let ((counter (make-array 1 :initial-element 0)))
    (fol.lib.parallel:pforeach
     (lambda (x)
       (declare (ignore x))
       ;; Atomic increment via bordeaux-threads lock
       (bordeaux-threads:with-lock-held
           ((load-time-value (bordeaux-threads:make-lock "counter")))
         (incf (aref counter 0))))
     (mk-vec 1 2 3 4 5))
    (is (= 5 (aref counter 0)))))

(test pforeach-empty-collection
  "pforeach on an empty collection returns nil without error."
  (is (eq nil (fol.lib.parallel:pforeach #'error (mk-vec)))))

;;; ---------------------------------------------------------------------------
;;; pfind
;;; ---------------------------------------------------------------------------

(test pfind-returns-first-match-by-position
  "pfind returns the first element in input order that satisfies pred."
  (let ((result (fol.lib.parallel:pfind #'even-p (mk-vec 1 3 4 6))))
    (is (= 4 result))))

(test pfind-returns-nil-when-no-match
  "pfind returns nil when no element satisfies the predicate."
  (is (eq nil (fol.lib.parallel:pfind #'even-p (mk-vec 1 3 5)))))

(test pfind-returns-first-not-later-match
  "pfind returns the positionally-earliest match even if a later one finishes sooner."
  ;; Elements 2 and 4 are both even; 2 comes first.
  (let ((result (fol.lib.parallel:pfind #'even-p (mk-vec 1 2 4 6))))
    (is (= 2 result))))

(test pfind-single-element-match
  "pfind works on a single-element collection that matches."
  (is (= 42 (fol.lib.parallel:pfind #'even-p (mk-vec 42)))))

(test pfind-single-element-no-match
  "pfind returns nil on a single-element collection that does not match."
  (is (eq nil (fol.lib.parallel:pfind #'even-p (mk-vec 1)))))

;;; ---------------------------------------------------------------------------
;;; pexists
;;; ---------------------------------------------------------------------------

(test pexists-true-when-any-match
  "pexists returns t when at least one element satisfies the predicate."
  (is (eq t (fol.lib.parallel:pexists #'even-p (mk-vec 1 3 4 5)))))

(test pexists-false-when-none-match
  "pexists returns nil when no element satisfies the predicate."
  (is (eq nil (fol.lib.parallel:pexists #'even-p (mk-vec 1 3 5)))))

(test pexists-empty-collection
  "pexists returns nil for an empty collection."
  (is (eq nil (fol.lib.parallel:pexists #'even-p (mk-vec)))))

(test pexists-all-match
  "pexists returns t when every element matches."
  (is (eq t (fol.lib.parallel:pexists #'even-p (mk-vec 2 4 6)))))

(test pexists-returns-boolean
  "pexists always returns t or nil, never another truthy value."
  (let ((r (fol.lib.parallel:pexists #'even-p (mk-vec 1 2 3))))
    (is (or (eq r t) (eq r nil)))))

;;; ---------------------------------------------------------------------------
;;; pforall
;;; ---------------------------------------------------------------------------

(test pforall-true-when-all-match
  "pforall returns t when every element satisfies the predicate."
  (is (eq t (fol.lib.parallel:pforall #'even-p (mk-vec 2 4 6)))))

(test pforall-false-when-any-fail
  "pforall returns nil when at least one element fails the predicate."
  (is (eq nil (fol.lib.parallel:pforall #'even-p (mk-vec 2 3 6)))))

(test pforall-empty-collection
  "pforall returns t vacuously for an empty collection."
  (is (eq t (fol.lib.parallel:pforall #'even-p (mk-vec)))))

(test pforall-single-element-true
  "pforall returns t for a single matching element."
  (is (eq t (fol.lib.parallel:pforall #'even-p (mk-vec 4)))))

(test pforall-single-element-false
  "pforall returns nil for a single non-matching element."
  (is (eq nil (fol.lib.parallel:pforall #'even-p (mk-vec 3)))))

(test pforall-returns-boolean
  "pforall always returns t or nil."
  (let ((r (fol.lib.parallel:pforall #'even-p (mk-vec 2 4))))
    (is (or (eq r t) (eq r nil)))))

;;; ---------------------------------------------------------------------------
;;; psize
;;; ---------------------------------------------------------------------------

(test psize-basic
  "psize returns the number of elements satisfying the predicate."
  (is (= 3 (fol.lib.parallel:psize #'even-p (mk-vec 1 2 3 4 5 6)))))

(test psize-none-match
  "psize returns 0 when no element satisfies the predicate."
  (is (= 0 (fol.lib.parallel:psize #'even-p (mk-vec 1 3 5)))))

(test psize-all-match
  "psize returns the collection size when all elements satisfy the predicate."
  (let ((v (mk-vec 2 4 6 8)))
    (is (= 4 (fol.lib.parallel:psize #'even-p v)))))

(test psize-empty-collection
  "psize returns 0 for an empty collection."
  (is (= 0 (fol.lib.parallel:psize #'even-p (mk-vec)))))

(test psize-large
  "psize is correct on a large collection."
  (let* ((data (loop for i from 1 to 500 collect i))
         (v    (apply #'mk-vec data)))
    (is (= 250 (fol.lib.parallel:psize #'even-p v)))))
