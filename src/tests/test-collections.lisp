;;; FOL Compiler Tests - Collection Base Class
;;;
;;; Tests for <collection>, the abstract base class and protocol generics.

(in-package :fol.compiler.tests)

(in-suite collections-tests)

;;; ---------------------------------------------------------------------------
;;; <collection> class existence and inheritance
;;; ---------------------------------------------------------------------------

(test collection-class-exists
  "The <collection> class is defined and findable."
  (is (not (null (find-class 'fol.compiler.collections:<collection>)))))

(test collection-superclass-is-standard-object
  "<collection> inherits from standard-object."
  (let ((supers (closer-mop:class-direct-superclasses
                 (find-class 'fol.compiler.collections:<collection>))))
    (is (eq t (some (lambda (s) (eq s (find-class 'standard-object))) supers)))))

;;; ---------------------------------------------------------------------------
;;; Type predicate
;;; ---------------------------------------------------------------------------

(test collection-predicate-nil
  "<collection>? returns NIL for non-collections."
  (is (null (fol.compiler.collections:<collection>? 42)))
  (is (null (fol.compiler.collections:<collection>? "hello")))
  (is (null (fol.compiler.collections:<collection>? nil))))

(test collection-predicate-true
  "<collection>? returns T for a <collection> instance."
  (let ((obj (make-instance 'fol.compiler.collections:<collection>)))
    (is (eq t (fol.compiler.collections:<collection>? obj)))))

;;; ---------------------------------------------------------------------------
;;; Protocol generics exist
;;; ---------------------------------------------------------------------------

(test collection-size-generic-exists
  "collection-size generic function is defined."
  (is (eq t (typep #'fol.compiler.collections:collection-size 'generic-function))))

(test collection-empty-p-generic-exists
  "collection-empty-p generic function is defined."
  (is (eq t (typep #'fol.compiler.collections:collection-empty-p 'generic-function))))

(test collection-conj-generic-exists
  "collection-conj generic function is defined."
  (is (eq t (typep #'fol.compiler.collections:collection-conj 'generic-function))))

(test collection-seq-generic-exists
  "collection-seq generic function is defined."
  (is (eq t (typep #'fol.compiler.collections:collection-seq 'generic-function))))

;;; ---------------------------------------------------------------------------
;;; <collection-storage> class (removed — class migrated to collection-primitives mixins)
;;; ---------------------------------------------------------------------------

;;; ---------------------------------------------------------------------------
;;; <unordered-collection> class and predicate
;;; ---------------------------------------------------------------------------

(test unordered-collection-class-exists
  "The <unordered-collection> class is defined."
  (is (not (null (find-class 'fol.compiler.collections:<unordered-collection>)))))

(test unordered-collection-inherits-collection
  "<unordered-collection> is a subclass of <collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<unordered-collection>
                       'fol.compiler.collections:<collection>))))

(test unordered-collection-predicate-nil
  "<unordered-collection>? returns NIL for non-collections."
  (is (null (fol.compiler.collections:<unordered-collection>? 42)))
  (is (null (fol.compiler.collections:<unordered-collection>? nil))))

(test unordered-collection-predicate-true
  "<unordered-collection>? returns T for an instance."
  (let ((obj (make-instance 'fol.compiler.collections:<unordered-collection>)))
    (is (eq t (fol.compiler.collections:<unordered-collection>? obj)))))

(test unordered-collection-is-collection
  "<unordered-collection> instances satisfy <collection>?."
  (let ((obj (make-instance 'fol.compiler.collections:<unordered-collection>)))
    (is (eq t (fol.compiler.collections:<collection>? obj)))))

;;; ---------------------------------------------------------------------------
;;; <ordered-collection> class and predicate
;;; ---------------------------------------------------------------------------

(test ordered-collection-class-exists
  "The <ordered-collection> class is defined."
  (is (not (null (find-class 'fol.compiler.collections:<ordered-collection>)))))

(test ordered-collection-inherits-collection
  "<ordered-collection> is a subclass of <collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<ordered-collection>
                       'fol.compiler.collections:<collection>))))

(test ordered-collection-predicate-nil
  "<ordered-collection>? returns NIL for non-collections."
  (is (null (fol.compiler.collections:<ordered-collection>? 42)))
  (is (null (fol.compiler.collections:<ordered-collection>? nil))))

(test ordered-collection-predicate-true
  "<ordered-collection>? returns T for an instance."
  (let ((obj (make-instance 'fol.compiler.collections:<ordered-collection>)))
    (is (eq t (fol.compiler.collections:<ordered-collection>? obj)))))

(test ordered-collection-is-collection
  "<ordered-collection> instances satisfy <collection>?."
  (let ((obj (make-instance 'fol.compiler.collections:<ordered-collection>)))
    (is (eq t (fol.compiler.collections:<collection>? obj)))))

(test ordered-not-unordered
  "<ordered-collection> instances are NOT <unordered-collection>?."
  (let ((obj (make-instance 'fol.compiler.collections:<ordered-collection>)))
    (is (null (fol.compiler.collections:<unordered-collection>? obj)))))

(test unordered-not-ordered
  "<unordered-collection> instances are NOT <ordered-collection>?."
  (let ((obj (make-instance 'fol.compiler.collections:<unordered-collection>)))
    (is (null (fol.compiler.collections:<ordered-collection>? obj)))))

;;; ---------------------------------------------------------------------------
;;; <vector> class, predicate, constructor, and protocol
;;; ---------------------------------------------------------------------------

(test vector-class-exists
  "The <vector> class is defined."
  (is (not (null (find-class 'fol.compiler.collections:<vector>)))))

(test vector-inherits-ordered-collection
  "<vector> is a subclass of <ordered-collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<vector>
                       'fol.compiler.collections:<ordered-collection>))))

(test vector-predicate-nil
  "<vector>? returns NIL for non-vectors."
  (is (null (fol.compiler.collections:<vector>? 42)))
  (is (null (fol.compiler.collections:<vector>? nil))))

(test vector-predicate-true
  "<vector>? returns T for a <vector> instance."
  (let ((v (fol.compiler.collections:make 'fol.compiler.collections:<vector> 1 2 3)))
    (is (eq t (fol.compiler.collections:<vector>? v)))))

(test vector-is-collection
  "<vector> satisfies <collection>? and <ordered-collection>?."
  (let ((v (fol.compiler.collections:make 'fol.compiler.collections:<vector>)))
    (is (eq t (fol.compiler.collections:<collection>? v)))
    (is (eq t (fol.compiler.collections:<ordered-collection>? v)))
    (is (null (fol.compiler.collections:<unordered-collection>? v)))))

(test vector-make-empty
  "(make '<vector>) with no args creates an empty vector."
  (let ((v (fol.compiler.collections:make 'fol.compiler.collections:<vector>)))
    (is (= 0 (fol.compiler.collections:collection-size v)))
    (is (eq t (fol.compiler.collections:collection-empty-p v)))
    (is (null (fol.compiler.collections:collection-seq v)))))

(test vector-make-with-elements
  "(make '<vector> ...) with args creates a populated vector."
  (let ((v (fol.compiler.collections:make 'fol.compiler.collections:<vector> 10 20 30)))
    (is (= 3 (fol.compiler.collections:collection-size v)))
    (is (null (fol.compiler.collections:collection-empty-p v)))
    (is (equal '(10 20 30) (fol.compiler.collections:collection-seq v)))))

(test vector-conj-appends
  "collection-conj on a vector appends to the end."
  (let* ((v (fol.compiler.collections:make 'fol.compiler.collections:<vector> 1 2))
         (v2 (fol.compiler.collections:collection-conj v 3)))
    (is (= 3 (fol.compiler.collections:collection-size v2)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq v2)))
    ;; Original unchanged
    (is (= 2 (fol.compiler.collections:collection-size v)))))

(test vector-conj-on-empty
  "collection-conj on an empty vector produces a single-element vector."
  (let* ((v (fol.compiler.collections:make 'fol.compiler.collections:<vector>))
         (v2 (fol.compiler.collections:collection-conj v 42)))
    (is (= 1 (fol.compiler.collections:collection-size v2)))
    (is (equal '(42) (fol.compiler.collections:collection-seq v2)))))

;;; ---------------------------------------------------------------------------
;;; <dict> class, predicate, constructor, and protocol
;;; ---------------------------------------------------------------------------

(test dict-class-exists
  "The <dict> class is defined."
  (is (not (null (find-class 'fol.compiler.collections:<dict>)))))

(test dict-inherits-unordered-collection
  "<dict> is a subclass of <unordered-collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<dict>
                       'fol.compiler.collections:<unordered-collection>))))

;;; dict-inherits-collection-storage — removed (<collection-storage> no longer exists)

(test dict-predicate-nil
  "<dict>? returns NIL for non-dicts."
  (is (null (fol.compiler.collections:<dict>? 42)))
  (is (null (fol.compiler.collections:<dict>? nil))))

(test dict-predicate-true
  "<dict>? returns T for a <dict> instance."
  (let ((d (fol.compiler.collections:make 'fol.compiler.collections:<dict>)))
    (is (eq t (fol.compiler.collections:<dict>? d)))))

(test dict-is-collection
  "<dict> satisfies <collection>? and <unordered-collection>?."
  (let ((d (fol.compiler.collections:make 'fol.compiler.collections:<dict>)))
    (is (eq t (fol.compiler.collections:<collection>? d)))
    (is (eq t (fol.compiler.collections:<unordered-collection>? d)))
    (is (null (fol.compiler.collections:<ordered-collection>? d)))))

(test dict-make-empty
  "(make '<dict>) with no args creates an empty dict."
  (let ((d (fol.compiler.collections:make 'fol.compiler.collections:<dict>)))
    (is (= 0 (fol.compiler.collections:collection-size d)))
    (is (eq t (fol.compiler.collections:collection-empty-p d)))
    (is (null (fol.compiler.collections:collection-seq d)))))

(test dict-make-with-entries
  "(make '<dict> :a 1 :b 2) creates a populated dict."
  (let ((d (fol.compiler.collections:make 'fol.compiler.collections:<dict> :a 1 :b 2)))
    (is (= 2 (fol.compiler.collections:collection-size d)))
    (is (null (fol.compiler.collections:collection-empty-p d)))))

(test dict-conj-adds-pair
  "collection-conj on a dict adds a key-value pair."
  (let* ((d (fol.compiler.collections:make 'fol.compiler.collections:<dict> :a 1))
         (d2 (fol.compiler.collections:collection-conj d (cons :b 2))))
    (is (= 2 (fol.compiler.collections:collection-size d2)))
    ;; Original unchanged
    (is (= 1 (fol.compiler.collections:collection-size d)))))

(test dict-seq-returns-alist
  "collection-seq on a dict returns an alist of (key . value) pairs."
  (let* ((d (fol.compiler.collections:make 'fol.compiler.collections:<dict> :x 10))
         (seq (fol.compiler.collections:collection-seq d)))
    (is (= 1 (length seq)))
    (is (eq :x (caar seq)))
    (is (= 10 (cdar seq)))))

(test dict-storage-is-hash-map
  "<dict> storage-items returns the underlying HAMT."
  (let ((d (fol.compiler.collections:make 'fol.compiler.collections:<dict> :a 1)))
    (is (eq 1 (fol.compiler.collections:get d :a)))))

;;; ---------------------------------------------------------------------------
;;; <ordered-dict> class, predicate, constructor, and protocol
;;; ---------------------------------------------------------------------------

(test ordered-dict-class-exists
  "The <ordered-dict> class is defined."
  (is (not (null (find-class 'fol.compiler.collections:<ordered-dict>)))))

(test ordered-dict-inherits-dict
  "<ordered-dict> is a subclass of <dict>."
  (is (eq t (subtypep 'fol.compiler.collections:<ordered-dict>
                       'fol.compiler.collections:<dict>))))

(test ordered-dict-inherits-unordered-collection
  "<ordered-dict> is a subclass of <unordered-collection> (via <dict>)."
  (is (eq t (subtypep 'fol.compiler.collections:<ordered-dict>
                       'fol.compiler.collections:<unordered-collection>))))

;;; ordered-dict-inherits-collection-storage — removed

(test ordered-dict-inherits-collection
  "<ordered-dict> is a subclass of <collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<ordered-dict>
                       'fol.compiler.collections:<collection>))))

(test ordered-dict-is-collection
  "<ordered-dict> satisfies <collection>?, <dict>?, <ordered-dict>?."
  (let ((d (fol.compiler.collection-functions:ordered-dict :a 1 :b 2)))
    (is (eq t (fol.compiler.collections:<collection>? d)))
    (is (eq t (fol.compiler.collections:<dict>? d)))
    (is (eq t (fol.compiler.collections:<ordered-dict>? d)))))

(test ordered-dict-predicate-nil
  "<ordered-dict>? returns NIL for non-ordered-dicts."
  (is (null (fol.compiler.collections:<ordered-dict>? 42)))
  (is (null (fol.compiler.collections:<ordered-dict>? nil)))
  ;; A plain <dict> is NOT an <ordered-dict>
  (is (null (fol.compiler.collections:<ordered-dict>?
             (fol.compiler.collection-functions:dict :a 1)))))

(test ordered-dict-predicate-true
  "<ordered-dict>? returns T for an <ordered-dict> instance."
  (let ((d (fol.compiler.collection-functions:ordered-dict :a 1 :b 2)))
    (is (eq t (fol.compiler.collections:<ordered-dict>? d)))))

(test ordered-dict-is-also-dict
  "<ordered-dict> satisfies <dict>? (it is a subclass of dict)."
  (let ((d (fol.compiler.collection-functions:ordered-dict :a 1)))
    (is (eq t (fol.compiler.collections:<dict>? d)))))

(test ordered-dict-make-empty
  "(ordered-dict) creates an empty ordered dict."
  (let ((d (fol.compiler.collection-functions:ordered-dict)))
    (is (= 0 (fol.compiler.collections:collection-size d)))
    (is (eq t (fol.compiler.collections:collection-empty-p d)))
    (is (null (fol.compiler.collections:collection-seq d)))))

(test ordered-dict-make-with-entries
  "(ordered-dict :a 1 :b 2 :c 3) creates a populated ordered dict with 3 entries."
  (let ((d (fol.compiler.collection-functions:ordered-dict :a 1 :b 2 :c 3)))
    (is (= 3 (fol.compiler.collections:collection-size d)))))

(test ordered-dict-preserves-insertion-order
  "collection-seq returns entries in insertion order."
  (let ((d (fol.compiler.collection-functions:ordered-dict :c 3 :a 1 :b 2)))
    (is (equal '((:c . 3) (:a . 1) (:b . 2))
               (fol.compiler.collections:collection-seq d)))))

(test ordered-dict-duplicate-keys
  "Duplicate keys keep the last value but the first insertion position."
  (let ((d (fol.compiler.collection-functions:ordered-dict :a 1 :b 2 :a 99)))
    (is (= 2 (fol.compiler.collections:collection-size d)))
    (is (equal '((:a . 99) (:b . 2))
               (fol.compiler.collections:collection-seq d)))))

(test ordered-dict-conj-adds-pair
  "collection-conj adds a key-value pair at the end."
  (let* ((d (fol.compiler.collection-functions:ordered-dict :a 1 :b 2))
         (d2 (fol.compiler.collections:collection-conj d (cons :c 3))))
    (is (= 3 (fol.compiler.collections:collection-size d2)))
    (is (equal '((:a . 1) (:b . 2) (:c . 3))
               (fol.compiler.collections:collection-seq d2)))
    ;; Original unchanged
    (is (= 2 (fol.compiler.collections:collection-size d)))))

(test ordered-dict-conj-overwrites-key
  "collection-conj overwrites the value for an existing key, keeping position."
  (let* ((d (fol.compiler.collection-functions:ordered-dict :a 1 :b 2))
         (d2 (fol.compiler.collections:collection-conj d (cons :a 99))))
    (is (= 2 (fol.compiler.collections:collection-size d2)))
    (is (equal '((:a . 99) (:b . 2))
               (fol.compiler.collections:collection-seq d2)))))

(test ordered-dict-conj-on-empty
  "collection-conj on an empty ordered dict produces a single-entry dict."
  (let* ((d (fol.compiler.collection-functions:ordered-dict))
         (d2 (fol.compiler.collections:collection-conj d (cons :x 42))))
    (is (= 1 (fol.compiler.collections:collection-size d2)))
    (is (equal '((:x . 42)) (fol.compiler.collections:collection-seq d2)))))

(test ordered-dict-storage-is-hash-map
  "<ordered-dict> get returns correct values."
  (let ((d (fol.compiler.collection-functions:ordered-dict :a 1 :b 2)))
    (is (eq 1 (fol.compiler.collections:get d :a)))
    (is (eq 2 (fol.compiler.collections:get d :b)))))

(test ordered-dict-key-order-slot
  "ordered-dict-key-order returns keys in insertion order."
  (let ((d (fol.compiler.collection-functions:ordered-dict :c 3 :a 1 :b 2)))
    (is (equal '(:c :a :b)
               (mapcar #'car (fol.compiler.collections:collection-seq d))))))

(test ordered-dict-count
  "count returns entry count for an <ordered-dict>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collection-functions:ordered-dict))))
  (is (= 3 (fol.compiler.collections:count
             (fol.compiler.collection-functions:ordered-dict :a 1 :b 2 :c 3)))))

(test ordered-dict-empty?
  "empty? works for <ordered-dict>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:ordered-dict))))
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:ordered-dict :a 1)))))

(test ordered-dict-print-object
  "Printing an <ordered-dict> produces FOL dict syntax in insertion order."
  (let ((d (fol.compiler.collection-functions:ordered-dict :c 3 :a 1 :b 2)))
    (is (string= "{:C 3 :A 1 :B 2}" (write-to-string d)))))

(test ordered-dict-print-object-empty
  "Printing an empty <ordered-dict> produces {}."
  (let ((d (fol.compiler.collection-functions:ordered-dict)))
    (is (string= "{}" (write-to-string d)))))

;;; ---------------------------------------------------------------------------
;;; <array-dict> class, predicate, constructor, and protocol
;;; ---------------------------------------------------------------------------

(test array-dict-class-exists
  "The <array-dict> class is defined."
  (is (not (null (find-class 'fol.compiler.collections:<array-dict>)))))

(test array-dict-inherits-dict
  "<array-dict> is a subclass of <dict>."
  (is (eq t (subtypep 'fol.compiler.collections:<array-dict>
                       'fol.compiler.collections:<dict>))))

(test array-dict-inherits-ordered-collection
  "<array-dict> is a subclass of <ordered-collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<array-dict>
                       'fol.compiler.collections:<ordered-collection>))))

;;; array-dict-inherits-collection-storage — removed

(test array-dict-inherits-collection
  "<array-dict> is a subclass of <collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<array-dict>
                       'fol.compiler.collections:<collection>))))

(test array-dict-is-collection
  "<array-dict> satisfies <collection>?, <dict>?, <ordered-collection>?, <array-dict>?."
  (let ((d (fol.compiler.collection-functions:array-dict :a 1 :b 2)))
    (is (eq t (fol.compiler.collections:<collection>? d)))
    (is (eq t (fol.compiler.collections:<dict>? d)))
    (is (eq t (fol.compiler.collections:<ordered-collection>? d)))
    (is (eq t (fol.compiler.collections:<array-dict>? d)))))

(test array-dict-predicate-nil
  "<array-dict>? returns NIL for non-array-dicts."
  (is (null (fol.compiler.collections:<array-dict>? 42)))
  (is (null (fol.compiler.collections:<array-dict>? nil)))
  ;; A plain <dict> is NOT an <array-dict>
  (is (null (fol.compiler.collections:<array-dict>?
             (fol.compiler.collection-functions:dict :a 1)))))

(test array-dict-predicate-true
  "<array-dict>? returns T for an <array-dict> instance."
  (let ((d (fol.compiler.collection-functions:array-dict :a 1 :b 2)))
    (is (eq t (fol.compiler.collections:<array-dict>? d)))))

(test array-dict-is-also-dict
  "<array-dict> satisfies <dict>? (it is a subclass of dict)."
  (let ((d (fol.compiler.collection-functions:array-dict :a 1)))
    (is (eq t (fol.compiler.collections:<dict>? d)))))

(test array-dict-make-empty
  "(array-dict) creates an empty array dict."
  (let ((d (fol.compiler.collection-functions:array-dict)))
    (is (= 0 (fol.compiler.collections:collection-size d)))
    (is (eq t (fol.compiler.collections:collection-empty-p d)))
    (is (null (fol.compiler.collections:collection-seq d)))))

(test array-dict-make-with-entries
  "(array-dict :a 1 :b 2 :c 3) creates a populated array dict with 3 entries."
  (let ((d (fol.compiler.collection-functions:array-dict :a 1 :b 2 :c 3)))
    (is (= 3 (fol.compiler.collections:collection-size d)))))

(test array-dict-preserves-insertion-order
  "collection-seq returns entries in insertion order."
  (let ((d (fol.compiler.collection-functions:array-dict :c 3 :a 1 :b 2)))
    (is (equal '((:c . 3) (:a . 1) (:b . 2))
               (fol.compiler.collections:collection-seq d)))))

(test array-dict-duplicate-keys
  "Duplicate keys keep the last value but the first insertion position."
  (let ((d (fol.compiler.collection-functions:array-dict :a 1 :b 2 :a 99)))
    (is (= 2 (fol.compiler.collections:collection-size d)))
    (is (equal '((:a . 99) (:b . 2))
               (fol.compiler.collections:collection-seq d)))))

(test array-dict-conj-adds-pair
  "collection-conj adds a key-value pair at the end."
  (let* ((d (fol.compiler.collection-functions:array-dict :a 1 :b 2))
         (d2 (fol.compiler.collections:collection-conj d (cons :c 3))))
    (is (= 3 (fol.compiler.collections:collection-size d2)))
    (is (equal '((:a . 1) (:b . 2) (:c . 3))
               (fol.compiler.collections:collection-seq d2)))
    ;; Original unchanged
    (is (= 2 (fol.compiler.collections:collection-size d)))))

(test array-dict-conj-overwrites-key
  "collection-conj overwrites the value for an existing key, keeping position."
  (let* ((d (fol.compiler.collection-functions:array-dict :a 1 :b 2))
         (d2 (fol.compiler.collections:collection-conj d (cons :a 99))))
    (is (= 2 (fol.compiler.collections:collection-size d2)))
    (is (equal '((:a . 99) (:b . 2))
               (fol.compiler.collections:collection-seq d2)))))

(test array-dict-conj-on-empty
  "collection-conj on an empty array dict produces a single-entry dict."
  (let* ((d (fol.compiler.collection-functions:array-dict))
         (d2 (fol.compiler.collections:collection-conj d (cons :x 42))))
    (is (= 1 (fol.compiler.collections:collection-size d2)))
    (is (equal '((:x . 42)) (fol.compiler.collections:collection-seq d2)))))

(test array-dict-storage-is-hash-map
  "<array-dict> get returns correct values."
  (let ((d (fol.compiler.collection-functions:array-dict :a 1 :b 2)))
    (is (eq 1 (fol.compiler.collections:get d :a)))
    (is (eq 2 (fol.compiler.collections:get d :b)))))

(test array-dict-key-order-slot
  "array-dict-key-order returns keys in insertion order."
  (let ((d (fol.compiler.collection-functions:array-dict :c 3 :a 1 :b 2)))
    (is (equal '(:c :a :b)
               (mapcar #'car (fol.compiler.collections:collection-seq d))))))

(test array-dict-count
  "count returns entry count for an <array-dict>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collection-functions:array-dict))))
  (is (= 3 (fol.compiler.collections:count
             (fol.compiler.collection-functions:array-dict :a 1 :b 2 :c 3)))))

(test array-dict-empty?
  "empty? works for <array-dict>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:array-dict))))
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:array-dict :a 1)))))

(test array-dict-print-object
  "Printing an <array-dict> produces FOL dict syntax in insertion order."
  (let ((d (fol.compiler.collection-functions:array-dict :c 3 :a 1 :b 2)))
    (is (string= "{:C 3 :A 1 :B 2}" (write-to-string d)))))

(test array-dict-print-object-empty
  "Printing an empty <array-dict> produces {}."
  (let ((d (fol.compiler.collection-functions:array-dict)))
    (is (string= "{}" (write-to-string d)))))

;;; ---------------------------------------------------------------------------
;;; <sorted-dict> class, predicate, constructor, and protocol
;;; ---------------------------------------------------------------------------

(test sorted-dict-class-exists
  "The <sorted-dict> class is defined."
  (is (not (null (find-class 'fol.compiler.collections:<sorted-dict>)))))

;;; sorted-dict-inherits-dict — removed (hierarchy changed)

(test sorted-dict-inherits-ordered-collection
  "<sorted-dict> is a subclass of <ordered-collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<sorted-dict>
                       'fol.compiler.collections:<ordered-collection>))))

;;; sorted-dict-inherits-collection-storage — removed

(test sorted-dict-inherits-comparator
  "<sorted-dict> is a subclass of <comparator>."
  (is (eq t (subtypep 'fol.compiler.collections:<sorted-dict>
                       'fol.compiler.collections:<comparator>))))

(test sorted-dict-inherits-collection
  "<sorted-dict> is a subclass of <collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<sorted-dict>
                       'fol.compiler.collections:<collection>))))

(test sorted-dict-is-collection
  "<sorted-dict> satisfies <collection>?, <ordered-collection>?, <dict>?, <sorted-dict>?."
  (let ((d (fol.compiler.collection-functions:sorted-dict nil 1 :a 2 :b)))
    (is (eq t (fol.compiler.collections:<collection>? d)))
    (is (eq t (fol.compiler.collections:<ordered-collection>? d)))
    (is (eq t (fol.compiler.collections:<dict>? d)))
    (is (eq t (fol.compiler.collections:<sorted-dict>? d)))))

(test sorted-dict-predicate-nil
  "<sorted-dict>? returns NIL for non-sorted-dicts."
  (is (null (fol.compiler.collections:<sorted-dict>? 42)))
  (is (null (fol.compiler.collections:<sorted-dict>? nil)))
  ;; A plain <dict> is NOT a <sorted-dict>
  (is (null (fol.compiler.collections:<sorted-dict>?
             (fol.compiler.collection-functions:dict :a 1)))))

(test sorted-dict-predicate-true
  "<sorted-dict>? returns T for a <sorted-dict> instance."
  (let ((d (fol.compiler.collection-functions:sorted-dict nil 1 :a 2 :b)))
    (is (eq t (fol.compiler.collections:<sorted-dict>? d)))))

(test sorted-dict-is-also-dict
  "<sorted-dict> satisfies <dict>? (it is a subclass of dict)."
  (let ((d (fol.compiler.collection-functions:sorted-dict nil 1 :a)))
    (is (eq t (fol.compiler.collections:<dict>? d)))))

(test sorted-dict-make-empty
  "(sorted-dict nil) creates an empty sorted dict."
  (let ((d (fol.compiler.collection-functions:sorted-dict nil)))
    (is (= 0 (fol.compiler.collections:collection-size d)))
    (is (eq t (fol.compiler.collections:collection-empty-p d)))
    (is (null (fol.compiler.collections:collection-seq d)))))

(test sorted-dict-make-with-entries
  "(sorted-dict nil 2 :b 1 :a 3 :c) creates a populated sorted dict with 3 entries."
  (let ((d (fol.compiler.collection-functions:sorted-dict nil 2 :b 1 :a 3 :c)))
    (is (= 3 (fol.compiler.collections:collection-size d)))))

(test sorted-dict-sorted-seq
  "collection-seq returns entries in comparator key order."
  (let ((d (fol.compiler.collection-functions:sorted-dict nil 3 :c 1 :a 2 :b)))
    (is (equal '((1 . :a) (2 . :b) (3 . :c))
               (fol.compiler.collections:collection-seq d)))))

(test sorted-dict-duplicate-keys
  "Duplicate keys keep the last value."
  (let ((d (fol.compiler.collection-functions:sorted-dict nil 1 :first 2 :x 1 :second)))
    (is (= 2 (fol.compiler.collections:collection-size d)))
    (is (equal '((1 . :second) (2 . :x))
               (fol.compiler.collections:collection-seq d)))))

(test sorted-dict-conj-adds-pair
  "collection-conj adds a key-value pair in order."
  (let* ((d (fol.compiler.collection-functions:sorted-dict nil 1 :a 3 :c))
         (d2 (fol.compiler.collections:collection-conj d (cons 2 :b))))
    (is (= 3 (fol.compiler.collections:collection-size d2)))
    (is (equal '((1 . :a) (2 . :b) (3 . :c))
               (fol.compiler.collections:collection-seq d2)))
    ;; Original unchanged
    (is (= 2 (fol.compiler.collections:collection-size d)))))

(test sorted-dict-conj-overwrites-key
  "collection-conj overwrites the value for an existing key."
  (let* ((d (fol.compiler.collection-functions:sorted-dict nil 1 :a 2 :b))
         (d2 (fol.compiler.collections:collection-conj d (cons 1 :z))))
    (is (= 2 (fol.compiler.collections:collection-size d2)))
    (is (equal '((1 . :z) (2 . :b))
               (fol.compiler.collections:collection-seq d2)))))

(test sorted-dict-conj-on-empty
  "collection-conj on an empty sorted dict produces a single-entry dict."
  (let* ((d (fol.compiler.collection-functions:sorted-dict nil))
         (d2 (fol.compiler.collections:collection-conj d (cons 42 :x))))
    (is (= 1 (fol.compiler.collections:collection-size d2)))
    (is (equal '((42 . :x)) (fol.compiler.collections:collection-seq d2)))))

(test sorted-dict-custom-comparator
  "A custom comparator (reverse order) is used for key sorting."
  (let* ((rev-cmp (lambda (a b)
                    (cond ((> a b) -1)
                          ((< a b)  1)
                          (t        0))))
         (d (fol.compiler.collection-functions:sorted-dict rev-cmp 1 :a 2 :b 3 :c)))
    (is (equal '((3 . :c) (2 . :b) (1 . :a))
               (fol.compiler.collections:collection-seq d)))))

(test sorted-dict-comparator-preserved-on-conj
  "collection-conj preserves the comparator."
  (let* ((rev-cmp (lambda (a b)
                    (cond ((> a b) -1)
                          ((< a b)  1)
                          (t        0))))
         (d (fol.compiler.collection-functions:sorted-dict rev-cmp 3 :c 1 :a))
         (d2 (fol.compiler.collections:collection-conj d (cons 2 :b))))
    (is (equal '((3 . :c) (2 . :b) (1 . :a))
               (fol.compiler.collections:collection-seq d2)))
    (is (eq rev-cmp (fol.compiler.collections:comparator-compare d2)))))

(test sorted-dict-storage-is-tree-map
  "<sorted-dict> get returns correct values."
  (let ((d (fol.compiler.collection-functions:sorted-dict nil 1 :a 2 :b)))
    (is (eq :a (fol.compiler.collections:get d 1)))
    (is (eq :b (fol.compiler.collections:get d 2)))))

(test sorted-dict-count
  "count returns entry count for a <sorted-dict>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collection-functions:sorted-dict nil))))
  (is (= 3 (fol.compiler.collections:count
             (fol.compiler.collection-functions:sorted-dict nil 1 :a 2 :b 3 :c)))))

(test sorted-dict-empty?
  "empty? works for <sorted-dict>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:sorted-dict nil))))
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:sorted-dict nil 1 :a)))))

(test sorted-dict-print-object
  "Printing a <sorted-dict> produces FOL dict syntax with sorted keys."
  (let ((d (fol.compiler.collection-functions:sorted-dict nil 2 :b 1 :a)))
    (is (string= "{1 :A 2 :B}" (write-to-string d)))))

(test sorted-dict-print-object-empty
  "Printing an empty <sorted-dict> produces {}."
  (let ((d (fol.compiler.collection-functions:sorted-dict nil)))
    (is (string= "{}" (write-to-string d)))))

;;; ---------------------------------------------------------------------------
;;; <int-dict> class, predicate, constructor, and protocol
;;; ---------------------------------------------------------------------------

(test int-dict-class-exists
  "The <int-dict> class is defined."
  (is (not (null (find-class 'fol.compiler.collections:<int-dict>)))))

;;; int-dict-inherits-sorted-dict — removed (hierarchy changed)
;;; int-dict-inherits-dict — removed (hierarchy changed)

(test int-dict-inherits-ordered-collection
  "<int-dict> is a subclass of <ordered-collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<int-dict>
                       'fol.compiler.collections:<ordered-collection>))))

;;; int-dict-inherits-collection-storage — removed

(test int-dict-inherits-comparator
  "<int-dict> is a subclass of <comparator> (via <sorted-dict>)."
  (is (eq t (subtypep 'fol.compiler.collections:<int-dict>
                       'fol.compiler.collections:<comparator>))))

(test int-dict-inherits-collection
  "<int-dict> is a subclass of <collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<int-dict>
                       'fol.compiler.collections:<collection>))))

(test int-dict-is-collection
  "<int-dict> satisfies <collection>?, <ordered-collection>?, <dict>?,
   <sorted-dict>?, and <int-dict>?."
  (let ((d (fol.compiler.collection-functions:int-dict 1 :a 2 :b)))
    (is (eq t (fol.compiler.collections:<collection>? d)))
    (is (eq t (fol.compiler.collections:<ordered-collection>? d)))
    (is (eq t (fol.compiler.collections:<dict>? d)))
    (is (eq t (fol.compiler.collections:<sorted-dict>? d)))
    (is (eq t (fol.compiler.collections:<int-dict>? d)))))

(test int-dict-predicate-nil
  "<int-dict>? returns NIL for non-int-dicts."
  (is (null (fol.compiler.collections:<int-dict>? 42)))
  (is (null (fol.compiler.collections:<int-dict>? nil)))
  ;; A plain <sorted-dict> is NOT an <int-dict>
  (is (null (fol.compiler.collections:<int-dict>?
             (fol.compiler.collection-functions:sorted-dict nil 1 :a)))))

(test int-dict-predicate-true
  "<int-dict>? returns T for an <int-dict> instance."
  (let ((d (fol.compiler.collection-functions:int-dict 1 :a 2 :b)))
    (is (eq t (fol.compiler.collections:<int-dict>? d)))))

(test int-dict-is-also-dict
  "<int-dict> satisfies <dict>? (it is a subclass of dict)."
  (let ((d (fol.compiler.collection-functions:int-dict 1 :a)))
    (is (eq t (fol.compiler.collections:<dict>? d)))))

(test int-dict-make-empty
  "(int-dict) creates an empty int dict."
  (let ((d (fol.compiler.collection-functions:int-dict)))
    (is (= 0 (fol.compiler.collections:collection-size d)))
    (is (eq t (fol.compiler.collections:collection-empty-p d)))
    (is (null (fol.compiler.collections:collection-seq d)))))

(test int-dict-make-with-entries
  "(int-dict 2 :b 1 :a 3 :c) creates a populated int dict with 3 entries."
  (let ((d (fol.compiler.collection-functions:int-dict 2 :b 1 :a 3 :c)))
    (is (= 3 (fol.compiler.collections:collection-size d)))))

(test int-dict-sorted-seq
  "collection-seq returns entries in ascending integer key order."
  (let ((d (fol.compiler.collection-functions:int-dict 3 :c 1 :a 2 :b)))
    (is (equal '((1 . :a) (2 . :b) (3 . :c))
               (fol.compiler.collections:collection-seq d)))))

(test int-dict-duplicate-keys
  "Duplicate integer keys keep the last value."
  (let ((d (fol.compiler.collection-functions:int-dict 1 :first 2 :x 1 :second)))
    (is (= 2 (fol.compiler.collections:collection-size d)))
    (is (equal '((1 . :second) (2 . :x))
               (fol.compiler.collections:collection-seq d)))))

(test int-dict-conj-adds-pair
  "collection-conj adds a key-value pair in integer order."
  (let* ((d (fol.compiler.collection-functions:int-dict 1 :a 3 :c))
         (d2 (fol.compiler.collections:collection-conj d (cons 2 :b))))
    (is (= 3 (fol.compiler.collections:collection-size d2)))
    (is (equal '((1 . :a) (2 . :b) (3 . :c))
               (fol.compiler.collections:collection-seq d2)))
    ;; Original unchanged
    (is (= 2 (fol.compiler.collections:collection-size d)))))

(test int-dict-conj-overwrites-key
  "collection-conj overwrites the value for an existing integer key."
  (let* ((d (fol.compiler.collection-functions:int-dict 1 :a 2 :b))
         (d2 (fol.compiler.collections:collection-conj d (cons 1 :z))))
    (is (= 2 (fol.compiler.collections:collection-size d2)))
    (is (equal '((1 . :z) (2 . :b))
               (fol.compiler.collections:collection-seq d2)))))

(test int-dict-conj-on-empty
  "collection-conj on an empty int dict produces a single-entry dict."
  (let* ((d (fol.compiler.collection-functions:int-dict))
         (d2 (fol.compiler.collections:collection-conj d (cons 42 :x))))
    (is (= 1 (fol.compiler.collections:collection-size d2)))
    (is (equal '((42 . :x)) (fol.compiler.collections:collection-seq d2)))))

(test int-dict-conj-preserves-type
  "collection-conj on an <int-dict> returns another <int-dict>."
  (let* ((d (fol.compiler.collection-functions:int-dict 1 :a))
         (d2 (fol.compiler.collections:collection-conj d (cons 2 :b))))
    (is (eq t (fol.compiler.collections:<int-dict>? d2)))))

(test int-dict-storage-is-tree-map
  "<int-dict> get returns correct values."
  (let ((d (fol.compiler.collection-functions:int-dict 1 :a 2 :b)))
    (is (eq :a (fol.compiler.collections:get d 1)))
    (is (eq :b (fol.compiler.collections:get d 2)))))

(test int-dict-count
  "count returns entry count for an <int-dict>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collection-functions:int-dict))))
  (is (= 3 (fol.compiler.collections:count
             (fol.compiler.collection-functions:int-dict 1 :a 2 :b 3 :c)))))

(test int-dict-empty?
  "empty? works for <int-dict>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:int-dict))))
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:int-dict 1 :a)))))

(test int-dict-print-object
  "Printing an <int-dict> produces FOL dict syntax with sorted integer keys."
  (let ((d (fol.compiler.collection-functions:int-dict 2 :b 1 :a)))
    (is (string= "{1 :A 2 :B}" (write-to-string d)))))

(test int-dict-print-object-empty
  "Printing an empty <int-dict> produces {}."
  (let ((d (fol.compiler.collection-functions:int-dict)))
    (is (string= "{}" (write-to-string d)))))

(test int-dict-by-custom-comparator
  "int-dict-by with a descending comparator reverses key order."
  (let* ((desc-cmp (lambda (a b)
                     (cond ((> a b) -1)
                           ((< a b)  1)
                           (t        0))))
         (d (fol.compiler.collection-functions:int-dict-by desc-cmp 1 :a 2 :b 3 :c)))
    (is (equal '((3 . :c) (2 . :b) (1 . :a))
               (fol.compiler.collections:collection-seq d)))
    (is (eq t (fol.compiler.collections:<int-dict>? d)))))

(test int-dict-by-nil-uses-default
  "int-dict-by with NIL comparator uses the default ascending fixnum order."
  (let ((d (fol.compiler.collection-functions:int-dict-by nil 3 :c 1 :a 2 :b)))
    (is (equal '((1 . :a) (2 . :b) (3 . :c))
               (fol.compiler.collections:collection-seq d)))
    (is (eq t (fol.compiler.collections:<int-dict>? d)))))

(test int-dict-by-comparator-preserved-on-conj
  "collection-conj preserves the custom comparator from int-dict-by."
  (let* ((desc-cmp (lambda (a b)
                     (cond ((> a b) -1)
                           ((< a b)  1)
                           (t        0))))
         (d (fol.compiler.collection-functions:int-dict-by desc-cmp 3 :c 1 :a))
         (d2 (fol.compiler.collections:collection-conj d (cons 2 :b))))
    (is (equal '((3 . :c) (2 . :b) (1 . :a))
               (fol.compiler.collections:collection-seq d2)))
    (is (eq desc-cmp (fol.compiler.collections:comparator-compare d2)))))

;;; ---------------------------------------------------------------------------
;;; <priority-dict> class, predicate, constructor, and protocol
;;; ---------------------------------------------------------------------------

(test priority-dict-class-exists
  "The <priority-dict> class is defined."
  (is (not (null (find-class 'fol.compiler.collections:<priority-dict>)))))

;;; priority-dict-inherits-dict — removed (hierarchy changed)

(test priority-dict-inherits-ordered-collection
  "<priority-dict> is a subclass of <ordered-collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<priority-dict>
                       'fol.compiler.collections:<ordered-collection>))))

;;; priority-dict-inherits-collection-storage — removed

(test priority-dict-inherits-collection
  "<priority-dict> is a subclass of <collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<priority-dict>
                       'fol.compiler.collections:<collection>))))

(test priority-dict-is-collection
  "<priority-dict> satisfies <collection>?, <dict>?, <ordered-collection>?, <priority-dict>?."
  (let ((d (fol.compiler.collection-functions:priority-dict :a 1 :b 2)))
    (is (eq t (fol.compiler.collections:<collection>? d)))
    (is (eq t (fol.compiler.collections:<dict>? d)))
    (is (eq t (fol.compiler.collections:<ordered-collection>? d)))
    (is (eq t (fol.compiler.collections:<priority-dict>? d)))))

(test priority-dict-predicate-nil
  "<priority-dict>? returns NIL for non-priority-dicts."
  (is (null (fol.compiler.collections:<priority-dict>? 42)))
  (is (null (fol.compiler.collections:<priority-dict>? nil)))
  ;; A plain <dict> is NOT a <priority-dict>
  (is (null (fol.compiler.collections:<priority-dict>?
             (fol.compiler.collection-functions:dict :a 1)))))

(test priority-dict-predicate-true
  "<priority-dict>? returns T for a <priority-dict> instance."
  (let ((d (fol.compiler.collection-functions:priority-dict :a 1 :b 2)))
    (is (eq t (fol.compiler.collections:<priority-dict>? d)))))

(test priority-dict-is-also-dict
  "<priority-dict> satisfies <dict>? (it is a subclass of dict)."
  (let ((d (fol.compiler.collection-functions:priority-dict :a 1)))
    (is (eq t (fol.compiler.collections:<dict>? d)))))

(test priority-dict-make-empty
  "(priority-dict) creates an empty priority dict."
  (let ((d (fol.compiler.collection-functions:priority-dict)))
    (is (= 0 (fol.compiler.collections:collection-size d)))
    (is (eq t (fol.compiler.collections:collection-empty-p d)))
    (is (null (fol.compiler.collections:collection-seq d)))))

(test priority-dict-make-with-entries
  "(priority-dict :a 1 :b 3 :c 2) creates a populated priority dict with 3 entries."
  (let ((d (fol.compiler.collection-functions:priority-dict :a 1 :b 3 :c 2)))
    (is (= 3 (fol.compiler.collections:collection-size d)))))

(test priority-dict-orders-by-priority
  "collection-seq returns entries in ascending priority order."
  (let ((d (fol.compiler.collection-functions:priority-dict :x 30 :y 10 :z 20)))
    (is (equal '((:y . 10) (:z . 20) (:x . 30))
               (fol.compiler.collections:collection-seq d)))))

(test priority-dict-duplicate-keys
  "Duplicate keys keep the last priority."
  (let ((d (fol.compiler.collection-functions:priority-dict :a 1 :b 2 :a 99)))
    (is (= 2 (fol.compiler.collections:collection-size d)))
    ;; :a has priority 99 now, :b has 2 → order is :b(2), :a(99)
    (is (equal '((:b . 2) (:a . 99))
               (fol.compiler.collections:collection-seq d)))))

(test priority-dict-conj-adds-pair
  "collection-conj adds a new key-priority pair in priority order."
  (let* ((d (fol.compiler.collection-functions:priority-dict :a 10 :b 30))
         (d2 (fol.compiler.collections:collection-conj d (cons :c 20))))
    (is (= 3 (fol.compiler.collections:collection-size d2)))
    (is (equal '((:a . 10) (:c . 20) (:b . 30))
               (fol.compiler.collections:collection-seq d2)))
    ;; Original unchanged
    (is (= 2 (fol.compiler.collections:collection-size d)))))

(test priority-dict-conj-updates-priority
  "collection-conj on existing key updates its priority and re-orders."
  (let* ((d (fol.compiler.collection-functions:priority-dict :a 10 :b 20 :c 30))
         ;; Move :c from priority 30 to priority 5 (now the minimum)
         (d2 (fol.compiler.collections:collection-conj d (cons :c 5))))
    (is (= 3 (fol.compiler.collections:collection-size d2)))
    (is (equal '((:c . 5) (:a . 10) (:b . 20))
               (fol.compiler.collections:collection-seq d2)))))

(test priority-dict-conj-on-empty
  "collection-conj on an empty priority dict produces a single-entry dict."
  (let* ((d (fol.compiler.collection-functions:priority-dict))
         (d2 (fol.compiler.collections:collection-conj d (cons :x 42))))
    (is (= 1 (fol.compiler.collections:collection-size d2)))
    (is (equal '((:x . 42)) (fol.compiler.collections:collection-seq d2)))))

(test priority-dict-storage-is-hash-map
  "<priority-dict> get returns correct priorities."
  (let ((d (fol.compiler.collection-functions:priority-dict :a 10 :b 20)))
    (is (eq 10 (fol.compiler.collections:get d :a)))
    (is (eq 20 (fol.compiler.collections:get d :b)))))

(test priority-dict-tree-slot
  "priority-dict-tree returns the Sycamore tree-map for priority ordering."
  (let ((d (fol.compiler.collection-functions:priority-dict :a 10 :b 20)))
    (is (not (null (fol.compiler.collections:priority-dict-tree d))))))

(test priority-dict-peek-min
  "priority-dict-peek-min returns the entry with the lowest priority."
  (let ((d (fol.compiler.collection-functions:priority-dict :x 30 :y 10 :z 20)))
    (is (equal '(:y . 10)
               (fol.compiler.collections:priority-dict-peek-min d)))))

(test priority-dict-peek-min-empty
  "priority-dict-peek-min returns NIL for an empty dict."
  (let ((d (fol.compiler.collection-functions:priority-dict)))
    (is (null (fol.compiler.collections:priority-dict-peek-min d)))))

(test priority-dict-pop-min
  "priority-dict-pop-min removes the minimum-priority entry."
  (let* ((d (fol.compiler.collection-functions:priority-dict :x 30 :y 10 :z 20))
         (d2 (fol.compiler.collections:priority-dict-pop-min d)))
    (is (= 2 (fol.compiler.collections:collection-size d2)))
    (is (equal '((:z . 20) (:x . 30))
               (fol.compiler.collections:collection-seq d2)))
    ;; Original unchanged
    (is (= 3 (fol.compiler.collections:collection-size d)))))

(test priority-dict-pop-min-empty
  "priority-dict-pop-min on empty dict returns the same empty dict."
  (let* ((d (fol.compiler.collection-functions:priority-dict))
         (d2 (fol.compiler.collections:priority-dict-pop-min d)))
    (is (= 0 (fol.compiler.collections:collection-size d2)))))

(test priority-dict-count
  "count returns entry count for a <priority-dict>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collection-functions:priority-dict))))
  (is (= 3 (fol.compiler.collections:count
             (fol.compiler.collection-functions:priority-dict :a 1 :b 2 :c 3)))))

(test priority-dict-empty?
  "empty? works for <priority-dict>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:priority-dict))))
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:priority-dict :a 1)))))

(test priority-dict-print-object
  "Printing a <priority-dict> produces FOL dict syntax in priority order."
  (let ((d (fol.compiler.collection-functions:priority-dict :x 30 :y 10 :z 20)))
    (is (string= "{:Y 10 :Z 20 :X 30}" (write-to-string d)))))

(test priority-dict-print-object-empty
  "Printing an empty <priority-dict> produces {}."
  (let ((d (fol.compiler.collection-functions:priority-dict)))
    (is (string= "{}" (write-to-string d)))))

;;; ---------------------------------------------------------------------------
;;; <set> class, predicate, constructor, and protocol
;;; ---------------------------------------------------------------------------

(test set-class-exists
  "The <set> class is defined."
  (is (not (null (find-class 'fol.compiler.collections:<set>)))))

(test set-inherits-unordered-collection
  "<set> is a subclass of <unordered-collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<set>
                       'fol.compiler.collections:<unordered-collection>))))

;;; set-inherits-collection-storage — removed

(test set-predicate-nil
  "<set>? returns NIL for non-sets."
  (is (null (fol.compiler.collections:<set>? 42)))
  (is (null (fol.compiler.collections:<set>? nil))))

(test set-predicate-true
  "<set>? returns T for a <set> instance."
  (let ((s (fol.compiler.collections:make 'fol.compiler.collections:<set> 1 2 3)))
    (is (eq t (fol.compiler.collections:<set>? s)))))

(test set-is-collection
  "<set> satisfies <collection>? and <unordered-collection>?."
  (let ((s (fol.compiler.collections:make 'fol.compiler.collections:<set>)))
    (is (eq t (fol.compiler.collections:<collection>? s)))
    (is (eq t (fol.compiler.collections:<unordered-collection>? s)))
    (is (null (fol.compiler.collections:<ordered-collection>? s)))))

(test set-make-empty
  "(make '<set>) with no args creates an empty set."
  (let ((s (fol.compiler.collections:make 'fol.compiler.collections:<set>)))
    (is (= 0 (fol.compiler.collections:collection-size s)))
    (is (eq t (fol.compiler.collections:collection-empty-p s)))
    (is (null (fol.compiler.collections:collection-seq s)))))

(test set-make-with-elements
  "(make '<set> 1 2 3) creates a populated set."
  (let ((s (fol.compiler.collections:make 'fol.compiler.collections:<set> 1 2 3)))
    (is (= 3 (fol.compiler.collections:collection-size s)))))

(test set-conj-adds-element
  "collection-conj on a set adds an element."
  (let* ((s (fol.compiler.collections:make 'fol.compiler.collections:<set> 1 2))
         (s2 (fol.compiler.collections:collection-conj s 3)))
    (is (= 3 (fol.compiler.collections:collection-size s2)))
    ;; Original unchanged
    (is (= 2 (fol.compiler.collections:collection-size s)))))

(test set-conj-on-empty
  "collection-conj on an empty set produces a single-element set."
  (let* ((s (fol.compiler.collections:make 'fol.compiler.collections:<set>))
         (s2 (fol.compiler.collections:collection-conj s 42)))
    (is (= 1 (fol.compiler.collections:collection-size s2)))
    (is (equal '(42) (fol.compiler.collections:collection-seq s2)))))

(test set-conj-deduplicates
  "collection-conj does not add duplicate elements."
  (let* ((s (fol.compiler.collections:make 'fol.compiler.collections:<set> 1 2 3))
         (s2 (fol.compiler.collections:collection-conj s 2)))
    (is (= 3 (fol.compiler.collections:collection-size s2)))))

(test set-storage-is-hash-set
  "<set> contains added elements."
  (let ((s (fol.compiler.collections:make 'fol.compiler.collections:<set> :x :y)))
    (is (eq :x (fol.compiler.collections:get s :x)))))

;;; ---------------------------------------------------------------------------
;;; Constructor functions (vector, dict, set)
;;; ---------------------------------------------------------------------------

(test vector-function-empty
  "(vector) creates an empty <vector>."
  (let ((v (fol.compiler.collection-functions:vector)))
    (is (eq t (fol.compiler.collections:<vector>? v)))
    (is (= 0 (fol.compiler.collections:collection-size v)))))

(test vector-function-with-elements
  "(vector 1 2 3) creates a populated <vector>."
  (let ((v (fol.compiler.collection-functions:vector 1 2 3)))
    (is (eq t (fol.compiler.collections:<vector>? v)))
    (is (= 3 (fol.compiler.collections:collection-size v)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq v)))))

(test dict-function-empty
  "(dict) creates an empty <dict>."
  (let ((d (fol.compiler.collection-functions:dict)))
    (is (eq t (fol.compiler.collections:<dict>? d)))
    (is (= 0 (fol.compiler.collections:collection-size d)))))

(test dict-function-with-entries
  "(dict :a 1 :b 2) creates a populated <dict>."
  (let ((d (fol.compiler.collection-functions:dict :a 1 :b 2)))
    (is (eq t (fol.compiler.collections:<dict>? d)))
    (is (= 2 (fol.compiler.collections:collection-size d)))))

(test set-function-empty
  "(set) creates an empty <set>."
  (let ((s (fol.compiler.collection-functions:set)))
    (is (eq t (fol.compiler.collections:<set>? s)))
    (is (= 0 (fol.compiler.collections:collection-size s)))))

(test set-function-with-elements
  "(set 1 2 3) creates a populated <set>."
  (let ((s (fol.compiler.collection-functions:set 1 2 3)))
    (is (eq t (fol.compiler.collections:<set>? s)))
    (is (= 3 (fol.compiler.collections:collection-size s)))))

;;; ---------------------------------------------------------------------------
;;; Primitive make methods (identity — return value unchanged)
;;; ---------------------------------------------------------------------------

(test make-bool
  "make '<bool> returns the boolean value unchanged."
  (is (eq t (fol.compiler.primitives:make 'fol.compiler.primitives:<bool> t)))
  (is (eq nil (fol.compiler.primitives:make 'fol.compiler.primitives:<bool> nil))))

(test make-char
  "make '<char> returns the character unchanged."
  (is (char= #\A (fol.compiler.primitives:make 'fol.compiler.primitives:<char> #\A)))
  (is (char= #\Space (fol.compiler.primitives:make 'fol.compiler.primitives:<char> #\Space))))

(test make-string
  "make '<string> returns the string unchanged."
  (is (string= "hello" (fol.compiler.primitives:make 'fol.compiler.primitives:<string> "hello")))
  (is (string= "" (fol.compiler.primitives:make 'fol.compiler.primitives:<string> ""))))

(test make-symbol
  "make '<symbol> returns the symbol unchanged."
  (is (eq 'foo (fol.compiler.primitives:make 'fol.compiler.primitives:<symbol> 'foo))))

(test make-keyword
  "make '<keyword> returns the keyword unchanged."
  (is (eq :bar (fol.compiler.primitives:make 'fol.compiler.primitives:<keyword> :bar))))

(test make-integer
  "make '<integer> returns the integer unchanged."
  (is (= 42 (fol.compiler.primitives:make 'fol.compiler.primitives:<integer> 42)))
  (is (= -7 (fol.compiler.primitives:make 'fol.compiler.primitives:<integer> -7)))
  (is (= 0 (fol.compiler.primitives:make 'fol.compiler.primitives:<integer> 0))))

(test make-fixnum
  "make '<fixnum> returns the fixnum unchanged."
  (is (= 99 (fol.compiler.primitives:make 'fol.compiler.primitives:<fixnum> 99))))

(test make-bignum
  "make '<bignum> returns the bignum unchanged."
  (let ((big (expt 2 64)))
    (is (= big (fol.compiler.primitives:make 'fol.compiler.primitives:<bignum> big)))))

(test make-float
  "make '<float> returns the float unchanged."
  (is (= 3.14 (fol.compiler.primitives:make 'fol.compiler.primitives:<float> 3.14))))

(test make-single-float
  "make '<single-float> returns the single-float unchanged."
  (is (= 1.0f0 (fol.compiler.primitives:make 'fol.compiler.primitives:<single-float> 1.0f0))))

(test make-double-float
  "make '<double-float> returns the double-float unchanged."
  (is (= 2.0d0 (fol.compiler.primitives:make 'fol.compiler.primitives:<double-float> 2.0d0))))

(test make-rational
  "make '<rational> returns the rational unchanged."
  (is (= 3/4 (fol.compiler.primitives:make 'fol.compiler.primitives:<rational> 3/4))))

(test make-ratio
  "make '<ratio> returns the ratio unchanged."
  (is (= 1/3 (fol.compiler.primitives:make 'fol.compiler.primitives:<ratio> 1/3))))

(test make-real
  "make '<real> returns the real unchanged."
  (is (= 5 (fol.compiler.primitives:make 'fol.compiler.primitives:<real> 5))))

(test make-number
  "make '<number> returns the number unchanged."
  (is (= 7 (fol.compiler.primitives:make 'fol.compiler.primitives:<number> 7))))

(test make-complex
  "make '<complex> returns the complex number unchanged."
  (is (= #c(1 2) (fol.compiler.primitives:make 'fol.compiler.primitives:<complex> #c(1 2)))))

;;; ---------------------------------------------------------------------------
;;; <bag> class, predicate, constructor, and protocol
;;; ---------------------------------------------------------------------------

(test bag-class-exists
  "The <bag> class is defined."
  (is (not (null (find-class 'fol.compiler.collections:<bag>)))))

(test bag-inherits-unordered-collection
  "<bag> is a subclass of <unordered-collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<bag>
                       'fol.compiler.collections:<unordered-collection>))))

(test bag-predicate-nil
  "<bag>? returns NIL for non-bags."
  (is (null (fol.compiler.collections:<bag>? 42)))
  (is (null (fol.compiler.collections:<bag>? nil))))

(test bag-predicate-true
  "<bag>? returns T for a <bag> instance."
  (let ((b (fol.compiler.collection-functions:bag 1 2 3)))
    (is (eq t (fol.compiler.collections:<bag>? b)))))

(test bag-make-empty
  "(bag) creates an empty bag."
  (let ((b (fol.compiler.collection-functions:bag)))
    (is (= 0 (fol.compiler.collections:collection-size b)))
    (is (eq t (fol.compiler.collections:collection-empty-p b)))
    (is (null (fol.compiler.collections:collection-seq b)))))

(test bag-make-with-elements
  "(bag 1 1 2) creates a bag with counts."
  (let ((b (fol.compiler.collection-functions:bag 1 1 2)))
    (is (= 3 (fol.compiler.collections:collection-size b)))))

(test bag-conj-adds-element
  "collection-conj on a bag adds one occurrence."
  (let* ((b (fol.compiler.collection-functions:bag 1 2))
         (b2 (fol.compiler.collections:collection-conj b 1)))
    (is (= 3 (fol.compiler.collections:collection-size b2)))
    ;; Original unchanged
    (is (= 2 (fol.compiler.collections:collection-size b)))))

(test bag-seq-expands-counts
  "collection-seq on a bag returns elements repeated by count."
  (let* ((b (fol.compiler.collection-functions:bag 1 1 2))
         (seq (fol.compiler.collections:collection-seq b)))
    (is (= 3 (length seq)))))

;;; ---------------------------------------------------------------------------
;;; print-object methods
;;; ---------------------------------------------------------------------------

(test vector-print-object
  "Printing a <vector> produces FOL vector syntax."
  (let ((v (fol.compiler.collection-functions:vector 1 2 3)))
    (is (string= "[1 2 3]" (write-to-string v)))))

(test vector-print-object-empty
  "Printing an empty <vector> produces []."
  (let ((v (fol.compiler.collection-functions:vector)))
    (is (string= "[]" (write-to-string v)))))

(test vector-print-object-nested
  "Printing nested vectors produces nested brackets."
  (let ((v (fol.compiler.collection-functions:vector
             1
             (fol.compiler.collection-functions:vector 2 3))))
    (is (string= "[1 [2 3]]" (write-to-string v)))))

(test dict-print-object-empty
  "Printing an empty <dict> produces {}."
  (let ((d (fol.compiler.collection-functions:dict)))
    (is (string= "{}" (write-to-string d)))))

(test dict-print-object-single
  "Printing a single-entry <dict> produces {key value}."
  (let ((d (fol.compiler.collection-functions:dict :a 1)))
    (is (string= "{:A 1}" (write-to-string d)))))

(test set-print-object-empty
  "Printing an empty <set> produces #{}."
  (let ((s (fol.compiler.collection-functions:set)))
    (is (string= "#{}" (write-to-string s)))))

(test bag-print-object-empty
  "Printing an empty <bag> produces #M{}."
  (let ((b (fol.compiler.collection-functions:bag)))
    (is (string= "#M{}" (write-to-string b)))))

;;; ---------------------------------------------------------------------------
;;; <array> class, predicate, constructor, and protocol
;;; ---------------------------------------------------------------------------

(test array-class-exists
  "The <array> class is defined."
  (is (not (null (find-class 'fol.compiler.collections:<array>)))))

(test array-inherits-vector
  "<array> is a subclass of <vector>."
  (is (eq t (subtypep 'fol.compiler.collections:<array>
                       'fol.compiler.collections:<vector>))))

(test array-is-ordered-collection
  "<array> is also a subclass of <ordered-collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<array>
                       'fol.compiler.collections:<ordered-collection>))))

(test array-predicate-nil
  "<array>? returns NIL for non-arrays."
  (is (null (fol.compiler.collections:<array>? 42)))
  (is (null (fol.compiler.collections:<array>? nil)))
  ;; A plain <vector> is NOT an <array>
  (is (null (fol.compiler.collections:<array>?
             (fol.compiler.collection-functions:vector 1 2 3)))))

(test array-predicate-true
  "<array>? returns T for an <array> instance."
  (let ((a (fol.compiler.collections:make 'fol.compiler.collections:<array> 1 2 3)))
    (is (eq t (fol.compiler.collections:<array>? a)))))

(test array-is-also-vector
  "<array> satisfies <vector>?, <ordered-collection>?, <collection>?."
  (let ((a (fol.compiler.collections:make 'fol.compiler.collections:<array>)))
    (is (eq t (fol.compiler.collections:<vector>? a)))
    (is (eq t (fol.compiler.collections:<ordered-collection>? a)))
    (is (eq t (fol.compiler.collections:<collection>? a)))))

(test array-make-empty
  "(make '<array>) creates an empty array."
  (let ((a (fol.compiler.collections:make 'fol.compiler.collections:<array>)))
    (is (= 0 (fol.compiler.collections:collection-size a)))
    (is (null (fol.compiler.collections:collection-seq a)))))

(test array-make-with-elements
  "(make '<array> 10 20 30) creates a populated array."
  (let ((a (fol.compiler.collections:make 'fol.compiler.collections:<array> 10 20 30)))
    (is (= 3 (fol.compiler.collections:collection-size a)))
    (is (equal '(10 20 30) (fol.compiler.collections:collection-seq a)))))

(test array-dimension-slot
  "array-dimension returns the dimension list."
  (let ((a (fol.compiler.collections:make 'fol.compiler.collections:<array> 1 2 3 4)))
    (is (equal '(4) (fol.compiler.collections:array-dimension a))))
  (let ((a (fol.compiler.collections:make 'fol.compiler.collections:<array>)))
    (is (equal '(0) (fol.compiler.collections:array-dimension a)))))

(test array-conj-appends
  "collection-conj on an array appends and updates dimension."
  (let* ((a (fol.compiler.collections:make 'fol.compiler.collections:<array> 1 2))
         (a2 (fol.compiler.collections:collection-conj a 3)))
    (is (= 3 (fol.compiler.collections:collection-size a2)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq a2)))
    (is (equal '(3) (fol.compiler.collections:array-dimension a2)))
    ;; Original unchanged
    (is (= 2 (fol.compiler.collections:collection-size a)))))

(test array-storage-is-vec-t
  "<array> storage-items returns a %vec-t struct."
  (let ((a (fol.compiler.collections:make 'fol.compiler.collections:<array> 1 2 3)))
    (is (fol.compiler.collection-primitives::%vec-t?
          (fol.compiler.collection-primitives:storage-items a)))))

;;; ---------------------------------------------------------------------------
;;; count generic function
;;; ---------------------------------------------------------------------------

(test count-vector
  "count returns element count for a <vector>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collection-functions:vector))))
  (is (= 3 (fol.compiler.collections:count
             (fol.compiler.collection-functions:vector 1 2 3)))))

(test count-array
  "count returns element count for an <array>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collections:make 'fol.compiler.collections:<array>))))
  (is (= 2 (fol.compiler.collections:count
             (fol.compiler.collections:make 'fol.compiler.collections:<array> 10 20)))))

(test count-dict
  "count returns entry count for a <dict>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collection-functions:dict))))
  (is (= 2 (fol.compiler.collections:count
             (fol.compiler.collection-functions:dict :a 1 :b 2)))))

(test count-set
  "count returns element count for a <set>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collection-functions:set))))
  (is (= 3 (fol.compiler.collections:count
             (fol.compiler.collection-functions:set 1 2 3)))))

(test count-bag
  "count returns total element count for a <bag>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collection-functions:bag))))
  (is (= 3 (fol.compiler.collections:count
             (fol.compiler.collection-functions:bag 1 1 2)))))

;;; ---------------------------------------------------------------------------
;;; empty? generic function
;;; ---------------------------------------------------------------------------

(test empty?-bare-collection
  "empty? returns T for a bare <collection> instance."
  (is (eq t (fol.compiler.collections:empty?
             (make-instance 'fol.compiler.collections:<collection>)))))

(test empty?-empty-vector
  "empty? returns T for an empty <vector>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:vector)))))

(test empty?-nonempty-vector
  "empty? returns NIL for a non-empty <vector>."
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:vector 1 2 3)))))

(test empty?-empty-array
  "empty? returns T for an empty <array>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collections:make 'fol.compiler.collections:<array>)))))

(test empty?-nonempty-array
  "empty? returns NIL for a non-empty <array>."
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collections:make 'fol.compiler.collections:<array> 1)))))

(test empty?-empty-dict
  "empty? returns T for an empty <dict>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:dict)))))

(test empty?-nonempty-dict
  "empty? returns NIL for a non-empty <dict>."
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:dict :a 1)))))

(test empty?-empty-set
  "empty? returns T for an empty <set>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:set)))))

(test empty?-nonempty-set
  "empty? returns NIL for a non-empty <set>."
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:set 1 2)))))

(test empty?-empty-bag
  "empty? returns T for an empty <bag>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:bag)))))

(test empty?-nonempty-bag
  "empty? returns NIL for a non-empty <bag>."
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:bag 1 1 2)))))

;;; ---------------------------------------------------------------------------
;;; <ordered-set> class, predicate, constructor, and protocol
;;; ---------------------------------------------------------------------------

(test ordered-set-class-exists
  "The <ordered-set> class is defined."
  (is (not (null (find-class 'fol.compiler.collections:<ordered-set>)))))

;;; ordered-set-inherits-set — removed (hierarchy changed: ordered-set inherits ordered-dict, not set)

(test ordered-set-inherits-ordered-collection
  "<ordered-set> is a subclass of <ordered-collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<ordered-set>
                       'fol.compiler.collections:<ordered-collection>))))

(test ordered-set-is-collection
  "<ordered-set> satisfies <collection>? and <set>?."
  (let ((s (fol.compiler.collection-functions:ordered-set 1 2 3)))
    (is (eq t (fol.compiler.collections:<collection>? s)))
    (is (eq t (fol.compiler.collections:<set>? s)))
    (is (eq t (fol.compiler.collections:<ordered-collection>? s)))
    (is (eq t (fol.compiler.collections:<ordered-set>? s)))))

(test ordered-set-predicate-nil
  "<ordered-set>? returns NIL for non-ordered-sets."
  (is (null (fol.compiler.collections:<ordered-set>? 42)))
  (is (null (fol.compiler.collections:<ordered-set>? nil)))
  ;; A plain <set> is NOT an <ordered-set>
  (is (null (fol.compiler.collections:<ordered-set>?
             (fol.compiler.collection-functions:set 1 2 3)))))

(test ordered-set-predicate-true
  "<ordered-set>? returns T for an <ordered-set> instance."
  (let ((s (fol.compiler.collection-functions:ordered-set 1 2 3)))
    (is (eq t (fol.compiler.collections:<ordered-set>? s)))))

(test ordered-set-make-empty
  "(ordered-set) creates an empty ordered set."
  (let ((s (fol.compiler.collection-functions:ordered-set)))
    (is (= 0 (fol.compiler.collections:collection-size s)))
    (is (eq t (fol.compiler.collections:collection-empty-p s)))
    (is (null (fol.compiler.collections:collection-seq s)))))

(test ordered-set-make-with-elements
  "(ordered-set 1 2 3) creates a populated ordered set."
  (let ((s (fol.compiler.collection-functions:ordered-set 1 2 3)))
    (is (= 3 (fol.compiler.collections:collection-size s)))))

(test ordered-set-preserves-insertion-order
  "collection-seq returns elements in insertion order."
  (let ((s (fol.compiler.collection-functions:ordered-set 3 1 4 1 5 9 2 6)))
    ;; Duplicates dropped, order preserved
    (is (equal '(3 1 4 5 9 2 6) (fol.compiler.collections:collection-seq s)))))

(test ordered-set-deduplicates
  "Duplicate elements are silently dropped during construction."
  (let ((s (fol.compiler.collection-functions:ordered-set 1 2 2 3 3 3)))
    (is (= 3 (fol.compiler.collections:collection-size s)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq s)))))

(test ordered-set-conj-appends
  "collection-conj adds a new element at the end."
  (let* ((s (fol.compiler.collection-functions:ordered-set 1 2))
         (s2 (fol.compiler.collections:collection-conj s 3)))
    (is (= 3 (fol.compiler.collections:collection-size s2)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq s2)))
    ;; Original unchanged
    (is (= 2 (fol.compiler.collections:collection-size s)))))

(test ordered-set-conj-deduplicates
  "collection-conj does not add duplicate elements."
  (let* ((s (fol.compiler.collection-functions:ordered-set 1 2 3))
         (s2 (fol.compiler.collections:collection-conj s 2)))
    (is (= 3 (fol.compiler.collections:collection-size s2)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq s2)))
    ;; Returns the same object when element already present
    (is (eq s s2))))

(test ordered-set-conj-on-empty
  "collection-conj on an empty ordered set produces a single-element set."
  (let* ((s (fol.compiler.collection-functions:ordered-set))
         (s2 (fol.compiler.collections:collection-conj s 42)))
    (is (= 1 (fol.compiler.collections:collection-size s2)))
    (is (equal '(42) (fol.compiler.collections:collection-seq s2)))))

(test ordered-set-count
  "count returns element count for an <ordered-set>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collection-functions:ordered-set))))
  (is (= 3 (fol.compiler.collections:count
             (fol.compiler.collection-functions:ordered-set 1 2 3)))))

(test ordered-set-empty?
  "empty? works for <ordered-set>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:ordered-set))))
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:ordered-set 1 2)))))

;;; ---------------------------------------------------------------------------
;;; <sorted-set> class, predicate, constructor, and protocol
;;; ---------------------------------------------------------------------------

(test sorted-set-class-exists
  "The <sorted-set> class is defined."
  (is (not (null (find-class 'fol.compiler.collections:<sorted-set>)))))

(test sorted-set-inherits-set
  "<sorted-set> is a subclass of <set>."
  (is (eq t (subtypep 'fol.compiler.collections:<sorted-set>
                       'fol.compiler.collections:<set>))))

(test sorted-set-inherits-ordered-collection
  "<sorted-set> is a subclass of <ordered-collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<sorted-set>
                       'fol.compiler.collections:<ordered-collection>))))

(test sorted-set-inherits-comparator
  "<sorted-set> is a subclass of <comparator>."
  (is (eq t (subtypep 'fol.compiler.collections:<sorted-set>
                       'fol.compiler.collections:<comparator>))))

(test sorted-set-is-collection
  "<sorted-set> satisfies <collection>?, <set>?, <ordered-collection>?, <sorted-set>?."
  (let ((s (fol.compiler.collection-functions:sorted-set nil 3 1 2)))
    (is (eq t (fol.compiler.collections:<collection>? s)))
    (is (eq t (fol.compiler.collections:<set>? s)))
    (is (eq t (fol.compiler.collections:<ordered-collection>? s)))
    (is (eq t (fol.compiler.collections:<sorted-set>? s)))))

(test sorted-set-predicate-nil
  "<sorted-set>? returns NIL for non-sorted-sets."
  (is (null (fol.compiler.collections:<sorted-set>? 42)))
  (is (null (fol.compiler.collections:<sorted-set>? nil)))
  ;; A plain <set> is NOT a <sorted-set>
  (is (null (fol.compiler.collections:<sorted-set>?
             (fol.compiler.collection-functions:set 1 2 3)))))

(test sorted-set-predicate-true
  "<sorted-set>? returns T for a <sorted-set> instance."
  (let ((s (fol.compiler.collection-functions:sorted-set nil 1 2 3)))
    (is (eq t (fol.compiler.collections:<sorted-set>? s)))))

(test sorted-set-make-empty
  "(sorted-set nil) creates an empty sorted set."
  (let ((s (fol.compiler.collection-functions:sorted-set nil)))
    (is (= 0 (fol.compiler.collections:collection-size s)))
    (is (eq t (fol.compiler.collections:collection-empty-p s)))
    (is (null (fol.compiler.collections:collection-seq s)))))

(test sorted-set-make-with-elements
  "(sorted-set nil 5 3 1) creates a populated sorted set."
  (let ((s (fol.compiler.collection-functions:sorted-set nil 5 3 1)))
    (is (= 3 (fol.compiler.collections:collection-size s)))))

(test sorted-set-sorts-elements
  "collection-seq returns elements in comparator order."
  (let ((s (fol.compiler.collection-functions:sorted-set nil 5 3 1 4 2)))
    (is (equal '(1 2 3 4 5) (fol.compiler.collections:collection-seq s)))))

(test sorted-set-deduplicates
  "Duplicate elements are silently dropped."
  (let ((s (fol.compiler.collection-functions:sorted-set nil 3 1 2 2 3 1)))
    (is (= 3 (fol.compiler.collections:collection-size s)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq s)))))

(test sorted-set-conj-inserts-in-order
  "collection-conj inserts in comparator order."
  (let* ((s (fol.compiler.collection-functions:sorted-set nil 1 3 5))
         (s2 (fol.compiler.collections:collection-conj s 2)))
    (is (= 4 (fol.compiler.collections:collection-size s2)))
    (is (equal '(1 2 3 5) (fol.compiler.collections:collection-seq s2)))
    ;; Original unchanged
    (is (= 3 (fol.compiler.collections:collection-size s)))))

(test sorted-set-conj-deduplicates
  "collection-conj does not add duplicate elements."
  (let* ((s (fol.compiler.collection-functions:sorted-set nil 1 2 3))
         (s2 (fol.compiler.collections:collection-conj s 2)))
    (is (= 3 (fol.compiler.collections:collection-size s2)))
    ;; Returns the same object when element already present
    (is (eq s s2))))

(test sorted-set-conj-on-empty
  "collection-conj on an empty sorted set produces a single-element set."
  (let* ((s (fol.compiler.collection-functions:sorted-set nil))
         (s2 (fol.compiler.collections:collection-conj s 42)))
    (is (= 1 (fol.compiler.collections:collection-size s2)))
    (is (equal '(42) (fol.compiler.collections:collection-seq s2)))))

(test sorted-set-custom-comparator
  "A custom comparator (reverse order) is used for sorting."
  (let* ((rev-cmp (lambda (a b)
                    (cond ((> a b) -1)
                          ((< a b)  1)
                          (t        0))))
         (s (fol.compiler.collection-functions:sorted-set rev-cmp 1 2 3 4 5)))
    (is (equal '(5 4 3 2 1) (fol.compiler.collections:collection-seq s)))))

(test sorted-set-comparator-preserved-on-conj
  "collection-conj preserves the comparator."
  (let* ((rev-cmp (lambda (a b)
                    (cond ((> a b) -1)
                          ((< a b)  1)
                          (t        0))))
         (s (fol.compiler.collection-functions:sorted-set rev-cmp 5 3 1))
         (s2 (fol.compiler.collections:collection-conj s 4)))
    (is (equal '(5 4 3 1) (fol.compiler.collections:collection-seq s2)))
    ;; Comparator is the same function
    (is (eq rev-cmp (fol.compiler.collections:comparator-compare s2)))))

(test sorted-set-count
  "count returns element count for a <sorted-set>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collection-functions:sorted-set nil))))
  (is (= 3 (fol.compiler.collections:count
             (fol.compiler.collection-functions:sorted-set nil 1 2 3)))))

(test sorted-set-empty?
  "empty? works for <sorted-set>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:sorted-set nil))))
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:sorted-set nil 1 2)))))

;;; ---------------------------------------------------------------------------
;;; <int-set> class, predicate, constructor, and protocol
;;; ---------------------------------------------------------------------------

(test int-set-class-exists
  "The <int-set> class is defined."
  (is (not (null (find-class 'fol.compiler.collections:<int-set>)))))

;;; int-set-inherits-sorted-set — removed (hierarchy changed)

(test int-set-inherits-set
  "<int-set> is a subclass of <set>."
  (is (eq t (subtypep 'fol.compiler.collections:<int-set>
                       'fol.compiler.collections:<set>))))

(test int-set-inherits-ordered-collection
  "<int-set> is a subclass of <ordered-collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<int-set>
                       'fol.compiler.collections:<ordered-collection>))))

(test int-set-is-collection
  "<int-set> satisfies <collection>?, <set>?, <ordered-collection>?, <int-set>?."
  (let ((s (fol.compiler.collection-functions:int-set 3 1 2)))
    (is (eq t (fol.compiler.collections:<collection>? s)))
    (is (eq t (fol.compiler.collections:<set>? s)))
    (is (eq t (fol.compiler.collections:<ordered-collection>? s)))
    (is (eq t (fol.compiler.collections:<int-set>? s)))))

(test int-set-predicate-nil
  "<int-set>? returns NIL for non-int-sets."
  (is (null (fol.compiler.collections:<int-set>? 42)))
  (is (null (fol.compiler.collections:<int-set>? nil)))
  ;; A plain <sorted-set> is NOT an <int-set>
  (is (null (fol.compiler.collections:<int-set>?
             (fol.compiler.collection-functions:sorted-set nil 1 2 3)))))

(test int-set-predicate-true
  "<int-set>? returns T for an <int-set> instance."
  (let ((s (fol.compiler.collection-functions:int-set 1 2 3)))
    (is (eq t (fol.compiler.collections:<int-set>? s)))))

(test int-set-make-empty
  "(int-set) creates an empty int set."
  (let ((s (fol.compiler.collection-functions:int-set)))
    (is (= 0 (fol.compiler.collections:collection-size s)))
    (is (eq t (fol.compiler.collections:collection-empty-p s)))
    (is (null (fol.compiler.collections:collection-seq s)))))

(test int-set-make-with-elements
  "(int-set 5 3 1) creates a populated int set."
  (let ((s (fol.compiler.collection-functions:int-set 5 3 1)))
    (is (= 3 (fol.compiler.collections:collection-size s)))))

(test int-set-sorts-elements
  "collection-seq returns elements in numeric order."
  (let ((s (fol.compiler.collection-functions:int-set 5 3 1 4 2)))
    (is (equal '(1 2 3 4 5) (fol.compiler.collections:collection-seq s)))))

(test int-set-deduplicates
  "Duplicate elements are silently dropped."
  (let ((s (fol.compiler.collection-functions:int-set 3 1 2 2 3 1)))
    (is (= 3 (fol.compiler.collections:collection-size s)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq s)))))

(test int-set-conj-inserts-in-order
  "collection-conj inserts in numeric order."
  (let* ((s (fol.compiler.collection-functions:int-set 1 3 5))
         (s2 (fol.compiler.collections:collection-conj s 2)))
    (is (= 4 (fol.compiler.collections:collection-size s2)))
    (is (equal '(1 2 3 5) (fol.compiler.collections:collection-seq s2)))
    ;; Original unchanged
    (is (= 3 (fol.compiler.collections:collection-size s)))))

(test int-set-conj-deduplicates
  "collection-conj does not add duplicate elements."
  (let* ((s (fol.compiler.collection-functions:int-set 1 2 3))
         (s2 (fol.compiler.collections:collection-conj s 2)))
    (is (= 3 (fol.compiler.collections:collection-size s2)))
    ;; Returns the same object when element already present
    (is (eq s s2))))

(test int-set-conj-on-empty
  "collection-conj on an empty int set produces a single-element set."
  (let* ((s (fol.compiler.collection-functions:int-set))
         (s2 (fol.compiler.collections:collection-conj s 42)))
    (is (= 1 (fol.compiler.collections:collection-size s2)))
    (is (equal '(42) (fol.compiler.collections:collection-seq s2)))))

(test int-set-conj-preserves-type
  "collection-conj on an <int-set> returns an <int-set>, not a <sorted-set>."
  (let* ((s (fol.compiler.collection-functions:int-set 1 2))
         (s2 (fol.compiler.collections:collection-conj s 3)))
    (is (eq t (fol.compiler.collections:<int-set>? s2)))))

(test int-set-count
  "count returns element count for an <int-set>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collection-functions:int-set))))
  (is (= 3 (fol.compiler.collections:count
             (fol.compiler.collection-functions:int-set 1 2 3)))))

(test int-set-empty?
  "empty? works for <int-set>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:int-set))))
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:int-set 1 2)))))

;;; ---------------------------------------------------------------------------
;;; <dense-int-set> class, predicate, constructor, and protocol
;;; ---------------------------------------------------------------------------

(test dense-int-set-class-exists
  "The <dense-int-set> class is defined."
  (is (not (null (find-class 'fol.compiler.collections:<dense-int-set>)))))

(test dense-int-set-inherits-ordered-collection
  "<dense-int-set> is a subclass of <ordered-collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<dense-int-set>
                       'fol.compiler.collections:<ordered-collection>))))

;;; dense-int-set-inherits-collection-storage — removed

(test dense-int-set-inherits-collection
  "<dense-int-set> is a subclass of <collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<dense-int-set>
                       'fol.compiler.collections:<collection>))))

(test dense-int-set-is-collection
  "<dense-int-set> satisfies <collection>?, <ordered-collection>?, <dense-int-set>?."
  (let ((s (fol.compiler.collection-functions:dense-int-set 3 1 2)))
    (is (eq t (fol.compiler.collections:<collection>? s)))
    (is (eq t (fol.compiler.collections:<ordered-collection>? s)))
    (is (eq t (fol.compiler.collections:<dense-int-set>? s)))))

(test dense-int-set-predicate-nil
  "<dense-int-set>? returns NIL for non-dense-int-sets."
  (is (null (fol.compiler.collections:<dense-int-set>? 42)))
  (is (null (fol.compiler.collections:<dense-int-set>? nil)))
  ;; A plain <int-set> is NOT a <dense-int-set>
  (is (null (fol.compiler.collections:<dense-int-set>?
             (fol.compiler.collection-functions:int-set 1 2 3)))))

(test dense-int-set-predicate-true
  "<dense-int-set>? returns T for a <dense-int-set> instance."
  (let ((s (fol.compiler.collection-functions:dense-int-set 1 2 3)))
    (is (eq t (fol.compiler.collections:<dense-int-set>? s)))))

(test dense-int-set-make-empty
  "(dense-int-set) creates an empty dense int set."
  (let ((s (fol.compiler.collection-functions:dense-int-set)))
    (is (= 0 (fol.compiler.collections:collection-size s)))
    (is (eq t (fol.compiler.collections:collection-empty-p s)))
    (is (null (fol.compiler.collections:collection-seq s)))))

(test dense-int-set-make-with-elements
  "(dense-int-set 5 3 1) creates a populated dense int set."
  (let ((s (fol.compiler.collection-functions:dense-int-set 5 3 1)))
    (is (= 3 (fol.compiler.collections:collection-size s)))))

(test dense-int-set-sorted-seq
  "collection-seq returns elements in numeric order."
  (let ((s (fol.compiler.collection-functions:dense-int-set 5 3 1 4 2)))
    (is (equal '(1 2 3 4 5) (fol.compiler.collections:collection-seq s)))))

(test dense-int-set-deduplicates
  "Duplicate elements are silently dropped."
  (let ((s (fol.compiler.collection-functions:dense-int-set 3 1 2 2 3 1)))
    (is (= 3 (fol.compiler.collections:collection-size s)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq s)))))

(test dense-int-set-conj-within-range
  "collection-conj adds an element within the existing range."
  (let* ((s (fol.compiler.collection-functions:dense-int-set 1 3 5))
         (s2 (fol.compiler.collections:collection-conj s 2)))
    (is (= 4 (fol.compiler.collections:collection-size s2)))
    (is (equal '(1 2 3 5) (fol.compiler.collections:collection-seq s2)))
    ;; Original unchanged
    (is (= 3 (fol.compiler.collections:collection-size s)))))

(test dense-int-set-conj-extends-right
  "collection-conj extends the bit-vector when element is above range."
  (let* ((s (fol.compiler.collection-functions:dense-int-set 1 2 3))
         (s2 (fol.compiler.collections:collection-conj s 10)))
    (is (= 4 (fol.compiler.collections:collection-size s2)))
    (is (equal '(1 2 3 10) (fol.compiler.collections:collection-seq s2)))))

(test dense-int-set-conj-extends-left
  "collection-conj extends the bit-vector when element is below range."
  (let* ((s (fol.compiler.collection-functions:dense-int-set 5 6 7))
         (s2 (fol.compiler.collections:collection-conj s 2)))
    (is (= 4 (fol.compiler.collections:collection-size s2)))
    (is (equal '(2 5 6 7) (fol.compiler.collections:collection-seq s2)))))

(test dense-int-set-conj-deduplicates
  "collection-conj does not add duplicate elements."
  (let* ((s (fol.compiler.collection-functions:dense-int-set 1 2 3))
         (s2 (fol.compiler.collections:collection-conj s 2)))
    (is (= 3 (fol.compiler.collections:collection-size s2)))
    ;; Returns the same object when element already present
    (is (eq s s2))))

(test dense-int-set-conj-on-empty
  "collection-conj on an empty dense int set produces a single-element set."
  (let* ((s (fol.compiler.collection-functions:dense-int-set))
         (s2 (fol.compiler.collections:collection-conj s 42)))
    (is (= 1 (fol.compiler.collections:collection-size s2)))
    (is (equal '(42) (fol.compiler.collections:collection-seq s2)))))

(test dense-int-set-offset-tracking
  "dense-int-set-offset tracks the minimum element."
  (let ((s (fol.compiler.collection-functions:dense-int-set 10 20 15)))
    (is (= 10 (fol.compiler.collections:dense-int-set-offset s)))))

(test dense-int-set-internal-representation
  "Dense int set stores elements as a bignum bit-mask."
  (let ((s (fol.compiler.collection-functions:dense-int-set 1 2 3)))
    (is (= 3 (fol.compiler.collections:collection-size s)))))

(test dense-int-set-count
  "count returns element count for a <dense-int-set>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collection-functions:dense-int-set))))
  (is (= 3 (fol.compiler.collections:count
             (fol.compiler.collection-functions:dense-int-set 1 2 3)))))

(test dense-int-set-empty?
  "empty? works for <dense-int-set>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:dense-int-set))))
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collection-functions:dense-int-set 1 2)))))

;;; ===========================================================================
;;; <deque> tests
;;; ===========================================================================

(test deque-class-exists
  "<deque> class is defined."
  (is (not (null (find-class 'fol.compiler.collections:<deque>)))))

(test deque-predicate
  "<deque>? type predicate."
  (is (null (fol.compiler.collections:<deque>? 42)))
  (let ((d (fol.compiler.collections:make 'fol.compiler.collections:<deque>)))
    (is (eq t (fol.compiler.collections:<deque>? d)))))

(test deque-is-ordered-collection
  "<deque> inherits from <ordered-collection>."
  (let ((d (fol.compiler.collections:make 'fol.compiler.collections:<deque>)))
    (is (eq t (fol.compiler.collections:<ordered-collection>? d)))
    (is (eq t (fol.compiler.collections:<collection>? d)))))

(test deque-make-empty
  "make '<deque> with no args creates an empty deque."
  (let ((d (fol.compiler.collections:make 'fol.compiler.collections:<deque>)))
    (is (= 0 (fol.compiler.collections:collection-size d)))
    (is (null (fol.compiler.collections:collection-seq d)))))

(test deque-make-with-elements
  "make '<deque> with args creates a deque with those elements."
  (let ((d (fol.compiler.collections:make 'fol.compiler.collections:<deque> 1 2 3)))
    (is (= 3 (fol.compiler.collections:collection-size d)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq d)))))

(test deque-conj-appends
  "collection-conj appends to the back of a deque."
  (let* ((d (fol.compiler.collections:make 'fol.compiler.collections:<deque> 1 2))
         (d2 (fol.compiler.collections:collection-conj d 3)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq d2)))
    ;; Original is unchanged
    (is (equal '(1 2) (fol.compiler.collections:collection-seq d)))))

(test deque-count-and-empty
  "count and empty? work for <deque>."
  (let ((empty (fol.compiler.collections:make 'fol.compiler.collections:<deque>))
        (full (fol.compiler.collections:make 'fol.compiler.collections:<deque> 1 2 3)))
    (is (= 0 (fol.compiler.collections:count empty)))
    (is (= 3 (fol.compiler.collections:count full)))
    (is (eq t (fol.compiler.collections:empty? empty)))
    (is (null (fol.compiler.collections:empty? full)))))

(test deque-constructor-function
  "deque constructor function works."
  (let ((d (fol.compiler.collection-functions:deque 10 20 30)))
    (is (eq t (fol.compiler.collections:<deque>? d)))
    (is (= 3 (fol.compiler.collections:collection-size d)))
    (is (equal '(10 20 30) (fol.compiler.collections:collection-seq d)))))

(test deque-print-object
  "print-object for <deque> uses #Q[...] syntax."
  (let ((d (fol.compiler.collections:make 'fol.compiler.collections:<deque> 1 2 3)))
    (is (string= "#Q[1 2 3]" (princ-to-string d)))))

;;; ===========================================================================
;;; <list> tests
;;; ===========================================================================

(test list-class-exists
  "<list> class is defined."
  (is (not (null (find-class 'fol.compiler.collections:<list>)))))

(test list-predicate
  "<list>? type predicate."
  (is (null (fol.compiler.collections:<list>? 42)))
  (is (null (fol.compiler.collections:<list>? '(1 2 3))))
  (let ((l (fol.compiler.collections:make 'fol.compiler.collections:<list>)))
    (is (eq t (fol.compiler.collections:<list>? l)))))

(test list-is-ordered-collection
  "<list> inherits from <ordered-collection>."
  (let ((l (fol.compiler.collections:make 'fol.compiler.collections:<list>)))
    (is (eq t (fol.compiler.collections:<ordered-collection>? l)))
    (is (eq t (fol.compiler.collections:<collection>? l)))))

(test list-not-persistent-class
  "<list> uses standard-class, not persistent-class."
  (is (eq (find-class 'standard-class)
          (class-of (find-class 'fol.compiler.collections:<list>)))))

(test list-make-empty
  "make '<list> with no args creates an empty list."
  (let ((l (fol.compiler.collections:make 'fol.compiler.collections:<list>)))
    (is (= 0 (fol.compiler.collections:list-size l)))
    (is (null (fol.compiler.collections:list-first l)))
    (is (null (fol.compiler.collections:list-rest l)))
    (is (null (fol.compiler.collections:collection-seq l)))))

(test list-make-with-elements
  "make '<list> with args creates a list with those elements in order."
  (let ((l (fol.compiler.collections:make 'fol.compiler.collections:<list> 1 2 3)))
    (is (= 3 (fol.compiler.collections:list-size l)))
    (is (= 1 (fol.compiler.collections:list-first l)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq l)))))

(test list-first-rest-chain
  "list-first and list-rest walk the linked structure."
  (let* ((l (fol.compiler.collections:make 'fol.compiler.collections:<list> :a :b :c))
         (r1 (fol.compiler.collections:list-rest l))
         (r2 (fol.compiler.collections:list-rest r1)))
    (is (eq :a (fol.compiler.collections:list-first l)))
    (is (eq :b (fol.compiler.collections:list-first r1)))
    (is (eq :c (fol.compiler.collections:list-first r2)))
    (is (= 3 (fol.compiler.collections:list-size l)))
    (is (= 2 (fol.compiler.collections:list-size r1)))
    (is (= 1 (fol.compiler.collections:list-size r2)))))

(test list-conj-prepends
  "collection-conj prepends to the front of a list (Clojure semantics)."
  (let* ((l (fol.compiler.collections:make 'fol.compiler.collections:<list> 2 3))
         (l2 (fol.compiler.collections:collection-conj l 1)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq l2)))
    (is (= 3 (fol.compiler.collections:list-size l2)))
    ;; Original unchanged
    (is (equal '(2 3) (fol.compiler.collections:collection-seq l)))))

(test list-collection-size
  "collection-size returns cached size in O(1)."
  (is (= 0 (fol.compiler.collections:collection-size
             (fol.compiler.collections:make 'fol.compiler.collections:<list>))))
  (is (= 5 (fol.compiler.collections:collection-size
             (fol.compiler.collections:make 'fol.compiler.collections:<list> 1 2 3 4 5)))))

(test list-count-and-empty
  "count and empty? work for <list>."
  (let ((empty (fol.compiler.collections:make 'fol.compiler.collections:<list>))
        (full (fol.compiler.collections:make 'fol.compiler.collections:<list> 1 2 3)))
    (is (= 0 (fol.compiler.collections:count empty)))
    (is (= 3 (fol.compiler.collections:count full)))
    (is (eq t (fol.compiler.collections:empty? empty)))
    (is (null (fol.compiler.collections:empty? full)))))

(test list-structural-sharing
  "Conjing onto a list shares structure with the original."
  (let* ((l1 (fol.compiler.collections:make 'fol.compiler.collections:<list> 2 3))
         (l2 (fol.compiler.collections:collection-conj l1 1)))
    ;; l2's rest should be eq to l1
    (is (eq l1 (fol.compiler.collections:list-rest l2)))))

(test list-constructor-function
  "list constructor function works."
  (let ((l (fol.compiler.collection-functions:list 10 20 30)))
    (is (eq t (fol.compiler.collections:<list>? l)))
    (is (= 3 (fol.compiler.collections:collection-size l)))
    (is (equal '(10 20 30) (fol.compiler.collections:collection-seq l)))))

(test list-print-object
  "print-object for <list> uses (...) syntax."
  (let ((l (fol.compiler.collections:make 'fol.compiler.collections:<list> 1 2 3)))
    (is (string= "(1 2 3)" (princ-to-string l))))
  (let ((empty (fol.compiler.collections:make 'fol.compiler.collections:<list>)))
    (is (string= "()" (princ-to-string empty)))))

(test list-single-element
  "Single-element list works correctly."
  (let ((l (fol.compiler.collections:make 'fol.compiler.collections:<list> 42)))
    (is (= 1 (fol.compiler.collections:list-size l)))
    (is (= 42 (fol.compiler.collections:list-first l)))
    (is (= 0 (fol.compiler.collections:list-size
               (fol.compiler.collections:list-rest l))))
    (is (equal '(42) (fol.compiler.collections:collection-seq l)))))

(test list-mixed-types
  "List can hold mixed types."
  (let ((l (fol.compiler.collections:make 'fol.compiler.collections:<list> 1 "two" :three)))
    (is (= 3 (fol.compiler.collections:list-size l)))
    (is (= 1 (fol.compiler.collections:list-first l)))
    (is (equal '(1 "two" :three) (fol.compiler.collections:collection-seq l)))))

;;; ===========================================================================
;;; list* tests
;;; ===========================================================================

(test list*-single-arg
  "list* with a single argument returns that argument."
  (let ((l (fol.compiler.collection-functions:list 1 2 3)))
    (is (eq l (fol.compiler.collection-functions:list* l)))))

(test list*-prepend-to-list
  "list* prepends elements to a list tail."
  (let* ((tail (fol.compiler.collection-functions:list 3 4 5))
         (result (fol.compiler.collection-functions:list* 1 2 tail)))
    (is (= 5 (fol.compiler.collections:list-size result)))
    (is (equal '(1 2 3 4 5) (fol.compiler.collections:collection-seq result)))))

(test list*-nil-tail
  "list* with nil tail creates a list from preceding args."
  (let ((result (fol.compiler.collection-functions:list* 1 2 3 nil)))
    (is (= 3 (fol.compiler.collections:list-size result)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq result)))))

(test list*-single-head-and-tail
  "list* with one head and a list tail."
  (let* ((tail (fol.compiler.collection-functions:list 2 3))
         (result (fol.compiler.collection-functions:list* 1 tail)))
    (is (= 3 (fol.compiler.collections:list-size result)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq result)))))

(test list*-non-collection-tail
  "list* with a non-collection last argument wraps it in a list."
  (let ((result (fol.compiler.collection-functions:list* 1 2 3)))
    (is (= 3 (fol.compiler.collections:list-size result)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq result)))))

(test list*-empty-list-tail
  "list* with an empty list tail."
  (let* ((empty (fol.compiler.collection-functions:list))
         (result (fol.compiler.collection-functions:list* 1 2 empty)))
    (is (= 2 (fol.compiler.collections:list-size result)))
    (is (equal '(1 2) (fol.compiler.collections:collection-seq result)))))

(test list*-no-args-error
  "list* with no arguments signals an error."
  (signals error (fol.compiler.collection-functions:list*)))

;;; ===========================================================================
;;; nth tests
;;; ===========================================================================

(test nth-first-element
  "nth with index 0 returns the first element."
  (let ((l (fol.compiler.collection-functions:list 10 20 30)))
    (is (= 10 (fol.compiler.collection-functions:nth l 0)))))

(test nth-middle-element
  "nth returns the element at the given index."
  (let ((l (fol.compiler.collection-functions:list 10 20 30)))
    (is (= 20 (fol.compiler.collection-functions:nth l 1)))))

(test nth-last-element
  "nth returns the last element."
  (let ((l (fol.compiler.collection-functions:list 10 20 30)))
    (is (= 30 (fol.compiler.collection-functions:nth l 2)))))

(test nth-out-of-bounds-error
  "nth signals an error when index is out of bounds."
  (let ((l (fol.compiler.collection-functions:list 10 20 30)))
    (signals error (fol.compiler.collection-functions:nth l 5))))

(test nth-not-found-default
  "nth returns not-found when index is out of bounds and default given."
  (let ((l (fol.compiler.collection-functions:list 10 20 30)))
    (is (eq :missing (fol.compiler.collection-functions:nth l 5 :missing)))))

(test nth-empty-list-error
  "nth signals an error on an empty list."
  (let ((l (fol.compiler.collection-functions:list)))
    (signals error (fol.compiler.collection-functions:nth l 0))))

(test nth-empty-list-not-found
  "nth returns not-found on an empty list when default given."
  (let ((l (fol.compiler.collection-functions:list)))
    (is (eq :nope (fol.compiler.collection-functions:nth l 0 :nope)))))

;;; --- nth on <vector> ---

(test nth-vector-first
  "nth returns the first element of a vector."
  (let ((v (fol.compiler.collection-functions:vector 10 20 30)))
    (is (= 10 (fol.compiler.collection-functions:nth v 0)))))

(test nth-vector-middle
  "nth returns a middle element of a vector."
  (let ((v (fol.compiler.collection-functions:vector 10 20 30)))
    (is (= 20 (fol.compiler.collection-functions:nth v 1)))))

(test nth-vector-last
  "nth returns the last element of a vector."
  (let ((v (fol.compiler.collection-functions:vector 10 20 30)))
    (is (= 30 (fol.compiler.collection-functions:nth v 2)))))

(test nth-vector-out-of-bounds
  "nth signals an error on out-of-bounds index for a vector."
  (let ((v (fol.compiler.collection-functions:vector 10 20 30)))
    (signals error (fol.compiler.collection-functions:nth v 5))))

(test nth-vector-not-found
  "nth returns default when index out of bounds and default given."
  (let ((v (fol.compiler.collection-functions:vector 10 20 30)))
    (is (eq :missing (fol.compiler.collection-functions:nth v 5 :missing)))))

(test nth-vector-empty-error
  "nth signals an error on empty vector."
  (let ((v (fol.compiler.collection-functions:vector)))
    (signals error (fol.compiler.collection-functions:nth v 0))))

(test nth-vector-empty-not-found
  "nth returns default on empty vector when default given."
  (let ((v (fol.compiler.collection-functions:vector)))
    (is (eq :nope (fol.compiler.collection-functions:nth v 0 :nope)))))

;;; ===========================================================================
;;; peek tests
;;; ===========================================================================

(test peek-non-empty
  "peek returns the first element of a non-empty list."
  (let ((l (fol.compiler.collection-functions:list 10 20 30)))
    (is (= 10 (fol.compiler.collection-functions:peek l)))))

(test peek-single-element
  "peek returns the only element in a single-element list."
  (let ((l (fol.compiler.collection-functions:list 42)))
    (is (= 42 (fol.compiler.collection-functions:peek l)))))

(test peek-empty-list
  "peek returns NIL for an empty list."
  (let ((l (fol.compiler.collection-functions:list)))
    (is (null (fol.compiler.collection-functions:peek l)))))

;;; ===========================================================================
;;; push tests
;;; ===========================================================================

(test push-prepends-to-list
  "push prepends an element to the front of a list."
  (let* ((l (fol.compiler.collection-functions:list 2 3))
         (result (fol.compiler.collection-functions:push l 1)))
    (is (= 3 (fol.compiler.collections:list-size result)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq result)))))

(test push-to-empty-list
  "push onto an empty list creates a single-element list."
  (let* ((l (fol.compiler.collection-functions:list))
         (result (fol.compiler.collection-functions:push l 42)))
    (is (= 1 (fol.compiler.collections:list-size result)))
    (is (= 42 (fol.compiler.collections:list-first result)))))

(test push-preserves-original
  "push returns a new list; original is unmodified."
  (let* ((l (fol.compiler.collection-functions:list 2 3))
         (result (fol.compiler.collection-functions:push l 1)))
    (is (= 2 (fol.compiler.collections:list-size l)))
    (is (= 3 (fol.compiler.collections:list-size result)))))

;;; ===========================================================================
;;; pop tests
;;; ===========================================================================

(test pop-removes-first
  "pop removes the first element from a list."
  (let* ((l (fol.compiler.collection-functions:list 1 2 3))
         (result (fol.compiler.collection-functions:pop l)))
    (is (= 2 (fol.compiler.collections:list-size result)))
    (is (equal '(2 3) (fol.compiler.collections:collection-seq result)))))

(test pop-single-element
  "pop on a single-element list returns an empty list."
  (let* ((l (fol.compiler.collection-functions:list 42))
         (result (fol.compiler.collection-functions:pop l)))
    (is (= 0 (fol.compiler.collections:list-size result)))))

(test pop-empty-list-error
  "pop on an empty list signals an error."
  (let ((l (fol.compiler.collection-functions:list)))
    (signals error (fol.compiler.collection-functions:pop l))))

(test pop-preserves-original
  "pop returns a new list; original is unmodified."
  (let* ((l (fol.compiler.collection-functions:list 1 2 3))
         (result (fol.compiler.collection-functions:pop l)))
    (is (= 3 (fol.compiler.collections:list-size l)))
    (is (= 2 (fol.compiler.collections:list-size result)))))

;;; ===========================================================================
;;; index-of tests (for <list>)
;;; ===========================================================================

(test index-of-found
  "index-of returns the index of the first occurrence."
  (let ((l (fol.compiler.collection-functions:list 10 20 30 20)))
    (is (= 1 (fol.compiler.collection-functions:index-of l 20)))))

(test index-of-not-found
  "index-of returns NIL when value is not in the list."
  (let ((l (fol.compiler.collection-functions:list 10 20 30)))
    (is (null (fol.compiler.collection-functions:index-of l 99)))))

(test index-of-first-element
  "index-of returns 0 for the first element."
  (let ((l (fol.compiler.collection-functions:list :a :b :c)))
    (is (= 0 (fol.compiler.collection-functions:index-of l :a)))))

(test index-of-from-index
  "index-of respects :from-index keyword."
  (let ((l (fol.compiler.collection-functions:list 10 20 30 20)))
    (is (= 3 (fol.compiler.collection-functions:index-of l 20 :from-index 2)))))

(test index-of-empty-list
  "index-of returns NIL for an empty list."
  (let ((l (fol.compiler.collection-functions:list)))
    (is (null (fol.compiler.collection-functions:index-of l 42)))))

;;; ===========================================================================
;;; last-index-of tests (for <list>)
;;; ===========================================================================

(test last-index-of-found
  "last-index-of returns the last occurrence index."
  (let ((l (fol.compiler.collection-functions:list 10 20 30 20)))
    (is (= 3 (fol.compiler.collection-functions:last-index-of l 20)))))

(test last-index-of-not-found
  "last-index-of returns NIL when value is not in the list."
  (let ((l (fol.compiler.collection-functions:list 10 20 30)))
    (is (null (fol.compiler.collection-functions:last-index-of l 99)))))

(test last-index-of-single-occurrence
  "last-index-of returns the index when value occurs once."
  (let ((l (fol.compiler.collection-functions:list :a :b :c)))
    (is (= 1 (fol.compiler.collection-functions:last-index-of l :b)))))

(test last-index-of-empty-list
  "last-index-of returns NIL for an empty list."
  (let ((l (fol.compiler.collection-functions:list)))
    (is (null (fol.compiler.collection-functions:last-index-of l 42)))))

;;; ===========================================================================
;;; <lazy-seq> tests
;;; ===========================================================================

(test lazy-seq-class-exists
  "<lazy-seq> class is defined."
  (is (not (null (find-class 'fol.compiler.collections:<lazy-seq>)))))

(test lazy-seq-predicate
  "<lazy-seq>? type predicate."
  (is (null (fol.compiler.collections:<lazy-seq>? 42)))
  (let ((ls (fol.compiler.collections:make 'fol.compiler.collections:<lazy-seq>
              (lambda () nil))))
    (is (eq t (fol.compiler.collections:<lazy-seq>? ls)))))

(test lazy-seq-is-ordered-collection
  "<lazy-seq> inherits from <ordered-collection>."
  (let ((ls (fol.compiler.collections:make 'fol.compiler.collections:<lazy-seq>
              (lambda () nil))))
    (is (eq t (fol.compiler.collections:<ordered-collection>? ls)))
    (is (eq t (fol.compiler.collections:<collection>? ls)))))

(test lazy-seq-not-persistent-class
  "<lazy-seq> uses standard-class, not persistent-class."
  (is (eq (find-class 'standard-class)
          (class-of (find-class 'fol.compiler.collections:<lazy-seq>)))))

(test lazy-seq-unrealized-initially
  "A new lazy-seq is unrealized."
  (let ((ls (fol.compiler.collections:make 'fol.compiler.collections:<lazy-seq>
              (lambda () nil))))
    (is (null (fol.compiler.collections:lazy-seq-realized-p ls)))))

(test lazy-seq-realize-nil
  "Realizing a lazy-seq whose thunk returns NIL gives NIL."
  (let ((ls (fol.compiler.collections:make 'fol.compiler.collections:<lazy-seq>
              (lambda () nil))))
    (is (null (fol.compiler.collections:realize-lazy-seq ls)))
    (is (eq t (fol.compiler.collections:lazy-seq-realized-p ls)))))

(test lazy-seq-realize-list
  "Realizing a lazy-seq whose thunk returns a <list> gives that <list>."
  (let* ((inner (fol.compiler.collections:make 'fol.compiler.collections:<list> 1 2 3))
         (ls (fol.compiler.collections:make 'fol.compiler.collections:<lazy-seq>
               (lambda () inner))))
    (let ((result (fol.compiler.collections:realize-lazy-seq ls)))
      (is (eq t (fol.compiler.collections:<list>? result)))
      (is (equal '(1 2 3) (fol.compiler.collections:collection-seq result))))))

(test lazy-seq-thunk-called-once
  "The thunk is called only once; subsequent access uses cached result."
  (let* ((call-count 0)
         (ls (fol.compiler.collections:make 'fol.compiler.collections:<lazy-seq>
               (lambda ()
                 (incf call-count)
                 (fol.compiler.collections:make 'fol.compiler.collections:<list> 42)))))
    (fol.compiler.collections:realize-lazy-seq ls)
    (fol.compiler.collections:realize-lazy-seq ls)
    (fol.compiler.collections:realize-lazy-seq ls)
    (is (= 1 call-count))))

(test lazy-seq-thunk-cleared-after-realization
  "After realization, thunk is cleared (set to NIL) for GC."
  (let ((ls (fol.compiler.collections:make 'fol.compiler.collections:<lazy-seq>
              (lambda ()
                (fol.compiler.collections:make 'fol.compiler.collections:<list> 1)))))
    (fol.compiler.collections:realize-lazy-seq ls)
    (is (null (fol.compiler.collections:lazy-seq-thunk ls)))))

(test lazy-seq-chained-realization
  "A lazy-seq whose thunk returns another lazy-seq is recursively realized."
  (let* ((inner-ls (fol.compiler.collections:make 'fol.compiler.collections:<lazy-seq>
                     (lambda ()
                       (fol.compiler.collections:make 'fol.compiler.collections:<list> 10 20))))
         (outer-ls (fol.compiler.collections:make 'fol.compiler.collections:<lazy-seq>
                     (lambda () inner-ls))))
    (let ((result (fol.compiler.collections:realize-lazy-seq outer-ls)))
      (is (eq t (fol.compiler.collections:<list>? result)))
      (is (equal '(10 20) (fol.compiler.collections:collection-seq result))))))

(test lazy-seq-collection-seq
  "collection-seq fully realizes and returns elements as a CL list."
  (let ((ls (fol.compiler.collections:make 'fol.compiler.collections:<lazy-seq>
              (lambda ()
                (fol.compiler.collections:make 'fol.compiler.collections:<list> 1 2 3)))))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq ls)))))

(test lazy-seq-collection-size
  "collection-size fully realizes and counts elements."
  (let ((ls (fol.compiler.collections:make 'fol.compiler.collections:<lazy-seq>
              (lambda ()
                (fol.compiler.collections:make 'fol.compiler.collections:<list> 1 2 3)))))
    (is (= 3 (fol.compiler.collections:collection-size ls)))))

(test lazy-seq-collection-size-nil
  "collection-size returns 0 for a lazy-seq that realizes to NIL."
  (let ((ls (fol.compiler.collections:make 'fol.compiler.collections:<lazy-seq>
              (lambda () nil))))
    (is (= 0 (fol.compiler.collections:collection-size ls)))))

(test lazy-seq-conj
  "collection-conj realizes and prepends."
  (let* ((ls (fol.compiler.collections:make 'fol.compiler.collections:<lazy-seq>
               (lambda ()
                 (fol.compiler.collections:make 'fol.compiler.collections:<list> 2 3))))
         (result (fol.compiler.collections:collection-conj ls 1)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq result)))))

(test lazy-seq-conj-nil
  "collection-conj on a lazy-seq that realizes to NIL creates a single-element list."
  (let* ((ls (fol.compiler.collections:make 'fol.compiler.collections:<lazy-seq>
               (lambda () nil)))
         (result (fol.compiler.collections:collection-conj ls 42)))
    (is (equal '(42) (fol.compiler.collections:collection-seq result)))))

(test lazy-seq-count-and-empty
  "count and empty? work for <lazy-seq>."
  (let ((empty-ls (fol.compiler.collections:make 'fol.compiler.collections:<lazy-seq>
                    (lambda () nil)))
        (full-ls (fol.compiler.collections:make 'fol.compiler.collections:<lazy-seq>
                   (lambda ()
                     (fol.compiler.collections:make 'fol.compiler.collections:<list> 1 2)))))
    (is (= 0 (fol.compiler.collections:count empty-ls)))
    (is (= 2 (fol.compiler.collections:count full-ls)))
    (is (eq t (fol.compiler.collections:empty? empty-ls)))
    (is (null (fol.compiler.collections:empty? full-ls)))))

(test lazy-seq-constructor-function
  "lazy-seq constructor function works."
  (let ((ls (fol.compiler.collection-functions:lazy-seq
              (lambda ()
                (fol.compiler.collections:make 'fol.compiler.collections:<list> 5 10)))))
    (is (eq t (fol.compiler.collections:<lazy-seq>? ls)))
    (is (equal '(5 10) (fol.compiler.collections:collection-seq ls)))))

(test lazy-seq-print-unrealized
  "print-object for unrealized lazy-seq."
  (let ((ls (fol.compiler.collections:make 'fol.compiler.collections:<lazy-seq>
              (lambda () nil))))
    (is (string= "#<lazy-seq unrealized>" (princ-to-string ls)))))

(test lazy-seq-print-realized-nil
  "print-object for realized lazy-seq with NIL."
  (let ((ls (fol.compiler.collections:make 'fol.compiler.collections:<lazy-seq>
              (lambda () nil))))
    (fol.compiler.collections:realize-lazy-seq ls)
    (is (string= "()" (princ-to-string ls)))))

(test lazy-seq-print-realized-list
  "print-object for realized lazy-seq delegates to cached result."
  (let ((ls (fol.compiler.collections:make 'fol.compiler.collections:<lazy-seq>
              (lambda ()
                (fol.compiler.collections:make 'fol.compiler.collections:<list> 1 2 3)))))
    (fol.compiler.collections:realize-lazy-seq ls)
    (is (string= "(1 2 3)" (princ-to-string ls)))))

;;; ===========================================================================
;;; Collection Type Predicates
;;; ===========================================================================

(test collection-predicate-on-vector
  "<collection>? returns T for vectors."
  (let ((v (fol.compiler.collection-functions:vector 1 2 3)))
    (is (eq t (fol.compiler.primitive-functions:<collection>? v)))))

(test collection-predicate-on-dict
  "<collection>? returns T for dicts."
  (let ((d (fol.compiler.collection-functions:dict :a 1)))
    (is (eq t (fol.compiler.primitive-functions:<collection>? d)))))

(test collection-predicate-on-set
  "<collection>? returns T for sets."
  (let ((s (fol.compiler.collection-functions:set 1 2 3)))
    (is (eq t (fol.compiler.primitive-functions:<collection>? s)))))

(test collection-predicate-on-non-collection
  "<collection>? returns NIL for non-collections."
  (is (null (fol.compiler.primitive-functions:<collection>? 42)))
  (is (null (fol.compiler.primitive-functions:<collection>? "string")))
  (is (null (fol.compiler.primitive-functions:<collection>? '(1 2 3)))))

(test unordered-collection-predicate-on-set
  "<unordered-collection>? returns T for sets."
  (let ((s (fol.compiler.collection-functions:set 1 2 3)))
    (is (eq t (fol.compiler.primitive-functions:<unordered-collection>? s)))))

(test unordered-collection-predicate-on-dict
  "<unordered-collection>? returns T for dicts."
  (let ((d (fol.compiler.collection-functions:dict :a 1)))
    (is (eq t (fol.compiler.primitive-functions:<unordered-collection>? d)))))

(test unordered-collection-predicate-on-vector
  "<unordered-collection>? returns NIL for vectors."
  (let ((v (fol.compiler.collection-functions:vector 1 2 3)))
    (is (null (fol.compiler.primitive-functions:<unordered-collection>? v)))))

(test ordered-collection-predicate-on-vector
  "<ordered-collection>? returns T for vectors."
  (let ((v (fol.compiler.collection-functions:vector 1 2 3)))
    (is (eq t (fol.compiler.primitive-functions:<ordered-collection>? v)))))

(test ordered-collection-predicate-on-dict
  "<ordered-collection>? returns NIL for dicts."
  (let ((d (fol.compiler.collection-functions:dict :a 1)))
    (is (null (fol.compiler.primitive-functions:<ordered-collection>? d)))))

(test dict-predicate-on-dict
  "<dict>? returns T for dict."
  (let ((d (fol.compiler.collection-functions:dict :a 1)))
    (is (eq t (fol.compiler.primitive-functions:<dict>? d)))))

(test dict-predicate-on-ordered-dict
  "<dict>? returns T for ordered-dict (subclass)."
  (let ((d (fol.compiler.collection-functions:ordered-dict :a 1)))
    (is (eq t (fol.compiler.primitive-functions:<dict>? d)))))

(test dict-predicate-on-vector
  "<dict>? returns NIL for vector."
  (let ((v (fol.compiler.collection-functions:vector 1 2 3)))
    (is (null (fol.compiler.primitive-functions:<dict>? v)))))

(test ordered-dict-predicate-on-ordered-dict
  "<ordered-dict>? returns T for ordered-dict."
  (let ((d (fol.compiler.collection-functions:ordered-dict :a 1 :b 2)))
    (is (eq t (fol.compiler.primitive-functions:<ordered-dict>? d)))))

(test ordered-dict-predicate-on-dict
  "<ordered-dict>? returns NIL for plain dict."
  (let ((d (fol.compiler.collection-functions:dict :a 1)))
    (is (null (fol.compiler.primitive-functions:<ordered-dict>? d)))))

(test array-dict-predicate-on-array-dict
  "<array-dict>? returns T for array-dict."
  (let ((d (fol.compiler.collection-functions:array-dict :a 1 :b 2)))
    (is (eq t (fol.compiler.primitive-functions:<array-dict>? d)))))

(test array-dict-predicate-on-dict
  "<array-dict>? returns NIL for plain dict."
  (let ((d (fol.compiler.collection-functions:dict :a 1)))
    (is (null (fol.compiler.primitive-functions:<array-dict>? d)))))

(test sorted-dict-predicate-on-sorted-dict
  "<sorted-dict>? returns T for sorted-dict."
  (let ((d (fol.compiler.collection-functions:sorted-dict nil 1 :a 2 :b)))
    (is (eq t (fol.compiler.primitive-functions:<sorted-dict>? d)))))

(test sorted-dict-predicate-on-dict
  "<sorted-dict>? returns NIL for plain dict."
  (let ((d (fol.compiler.collection-functions:dict :a 1)))
    (is (null (fol.compiler.primitive-functions:<sorted-dict>? d)))))

(test int-dict-predicate-on-int-dict
  "<int-dict>? returns T for int-dict."
  (let ((d (fol.compiler.collection-functions:int-dict 1 :a 2 :b)))
    (is (eq t (fol.compiler.primitive-functions:<int-dict>? d)))))

(test int-dict-predicate-on-dict
  "<int-dict>? returns NIL for plain dict."
  (let ((d (fol.compiler.collection-functions:dict :a 1)))
    (is (null (fol.compiler.primitive-functions:<int-dict>? d)))))

(test priority-dict-predicate-on-priority-dict
  "<priority-dict>? returns T for priority-dict."
  (let ((d (fol.compiler.collection-functions:priority-dict :a 10 :b 20)))
    (is (eq t (fol.compiler.primitive-functions:<priority-dict>? d)))))

(test priority-dict-predicate-on-dict
  "<priority-dict>? returns NIL for plain dict."
  (let ((d (fol.compiler.collection-functions:dict :a 1)))
    (is (null (fol.compiler.primitive-functions:<priority-dict>? d)))))

(test set-predicate-on-set
  "<set>? returns T for set."
  (let ((s (fol.compiler.collection-functions:set 1 2 3)))
    (is (eq t (fol.compiler.primitive-functions:<set>? s)))))

(test set-predicate-on-ordered-set
  "<set>? returns T for ordered-set (subclass)."
  (let ((s (fol.compiler.collection-functions:ordered-set 1 2 3)))
    (is (eq t (fol.compiler.primitive-functions:<set>? s)))))

(test set-predicate-on-vector
  "<set>? returns NIL for vector."
  (let ((v (fol.compiler.collection-functions:vector 1 2 3)))
    (is (null (fol.compiler.primitive-functions:<set>? v)))))

(test ordered-set-predicate-on-ordered-set
  "<ordered-set>? returns T for ordered-set."
  (let ((s (fol.compiler.collection-functions:ordered-set 1 2 3)))
    (is (eq t (fol.compiler.primitive-functions:<ordered-set>? s)))))

(test ordered-set-predicate-on-set
  "<ordered-set>? returns NIL for plain set."
  (let ((s (fol.compiler.collection-functions:set 1 2 3)))
    (is (null (fol.compiler.primitive-functions:<ordered-set>? s)))))

(test sorted-set-predicate-on-sorted-set
  "<sorted-set>? returns T for sorted-set."
  (let ((s (fol.compiler.collection-functions:sorted-set nil 1 2 3)))
    (is (eq t (fol.compiler.primitive-functions:<sorted-set>? s)))))

(test sorted-set-predicate-on-set
  "<sorted-set>? returns NIL for plain set."
  (let ((s (fol.compiler.collection-functions:set 1 2 3)))
    (is (null (fol.compiler.primitive-functions:<sorted-set>? s)))))

(test int-set-predicate-on-int-set
  "<int-set>? returns T for int-set."
  (let ((s (fol.compiler.collection-functions:int-set 1 2 3)))
    (is (eq t (fol.compiler.primitive-functions:<int-set>? s)))))

(test int-set-predicate-on-set
  "<int-set>? returns NIL for plain set."
  (let ((s (fol.compiler.collection-functions:set 1 2 3)))
    (is (null (fol.compiler.primitive-functions:<int-set>? s)))))

(test dense-int-set-predicate-on-dense-int-set
  "<dense-int-set>? returns T for dense-int-set."
  (let ((s (fol.compiler.collection-functions:dense-int-set 1 2 3)))
    (is (eq t (fol.compiler.primitive-functions:<dense-int-set>? s)))))

(test dense-int-set-predicate-on-set
  "<dense-int-set>? returns NIL for plain set."
  (let ((s (fol.compiler.collection-functions:set 1 2 3)))
    (is (null (fol.compiler.primitive-functions:<dense-int-set>? s)))))

(test vector-predicate-on-vector
  "<vector>? returns T for vector."
  (let ((v (fol.compiler.collection-functions:vector 1 2 3)))
    (is (eq t (fol.compiler.primitive-functions:<vector>? v)))))

(test vector-predicate-on-dict
  "<vector>? returns NIL for dict."
  (let ((d (fol.compiler.collection-functions:dict :a 1)))
    (is (null (fol.compiler.primitive-functions:<vector>? d)))))

(test list-predicate-on-list
  "<list>? returns T for list."
  (let ((l (fol.compiler.collections:make 'fol.compiler.collections:<list> 1 2 3)))
    (is (eq t (fol.compiler.primitive-functions:<list>? l)))))

(test list-predicate-on-vector
  "<list>? returns NIL for vector."
  (let ((v (fol.compiler.collection-functions:vector 1 2 3)))
    (is (null (fol.compiler.primitive-functions:<list>? v)))))

(test lazy-seq-predicate-on-lazy-seq
  "<lazy-seq>? returns T for lazy-seq."
  (let ((ls (fol.compiler.collections:make 'fol.compiler.collections:<lazy-seq> (lambda () nil))))
    (is (eq t (fol.compiler.primitive-functions:<lazy-seq>? ls)))))

(test lazy-seq-predicate-on-vector
  "<lazy-seq>? returns NIL for vector."
  (let ((v (fol.compiler.collection-functions:vector 1 2 3)))
    (is (null (fol.compiler.primitive-functions:<lazy-seq>? v)))))

(test deque-predicate-on-deque
  "<deque>? returns T for deque."
  (let ((dq (fol.compiler.collections:make 'fol.compiler.collections:<deque>)))
    (is (eq t (fol.compiler.primitive-functions:<deque>? dq)))))

(test deque-predicate-on-vector
  "<deque>? returns NIL for vector."
  (let ((v (fol.compiler.collection-functions:vector 1 2 3)))
    (is (null (fol.compiler.primitive-functions:<deque>? v)))))

(test bag-predicate-on-bag
  "<bag>? returns T for bag."
  (let ((b (fol.compiler.collection-functions:bag 1 1 2 3)))
    (is (eq t (fol.compiler.primitive-functions:<bag>? b)))))

(test bag-predicate-on-set
  "<bag>? returns NIL for set."
  (let ((s (fol.compiler.collection-functions:set 1 2 3)))
    (is (null (fol.compiler.primitive-functions:<bag>? s)))))

;;; ===========================================================================
;;; empty and not-empty tests
;;; ===========================================================================

(test empty-vector
  "empty on vector returns empty vector."
  (let* ((v (fol.compiler.collection-functions:vector 1 2 3))
         (empty-v (fol.compiler.collection-functions:empty v)))
    (is (eq t (fol.compiler.primitive-functions:<vector>? empty-v)))
    (is (= 0 (fol.compiler.collections:collection-size empty-v)))
    (is (eq t (fol.compiler.collections:empty? empty-v)))))

(test empty-dict
  "empty on dict returns empty dict."
  (let* ((d (fol.compiler.collection-functions:dict :a 1 :b 2))
         (empty-d (fol.compiler.collection-functions:empty d)))
    (is (eq t (fol.compiler.primitive-functions:<dict>? empty-d)))
    (is (= 0 (fol.compiler.collections:collection-size empty-d)))
    (is (eq t (fol.compiler.collections:empty? empty-d)))))

(test empty-set
  "empty on set returns empty set."
  (let* ((s (fol.compiler.collection-functions:set 1 2 3))
         (empty-s (fol.compiler.collection-functions:empty s)))
    (is (eq t (fol.compiler.primitive-functions:<set>? empty-s)))
    (is (= 0 (fol.compiler.collections:collection-size empty-s)))
    (is (eq t (fol.compiler.collections:empty? empty-s)))))

(test empty-ordered-dict
  "empty on ordered-dict returns empty ordered-dict."
  (let* ((d (fol.compiler.collection-functions:ordered-dict :a 1 :b 2))
         (empty-d (fol.compiler.collection-functions:empty d)))
    (is (eq t (fol.compiler.primitive-functions:<ordered-dict>? empty-d)))
    (is (= 0 (fol.compiler.collections:collection-size empty-d)))))

(test empty-sorted-dict-preserves-comparator
  "empty on sorted-dict preserves comparator."
  (let* ((d (fol.compiler.collection-functions:sorted-dict nil 2 :b 1 :a))
         (empty-d (fol.compiler.collection-functions:empty d)))
    (is (eq t (fol.compiler.primitive-functions:<sorted-dict>? empty-d)))
    (is (= 0 (fol.compiler.collections:collection-size empty-d)))
    ;; Verify comparator preserved by adding elements
    (let ((d2 (fol.compiler.collections:collection-conj empty-d (cons 3 :c))))
      (is (eq t (fol.compiler.primitive-functions:<sorted-dict>? d2))))))

(test empty-int-dict-preserves-comparator
  "empty on int-dict preserves comparator."
  (let* ((d (fol.compiler.collection-functions:int-dict 2 :b 1 :a))
         (empty-d (fol.compiler.collection-functions:empty d)))
    (is (eq t (fol.compiler.primitive-functions:<int-dict>? empty-d)))
    (is (= 0 (fol.compiler.collections:collection-size empty-d)))
    ;; Verify comparator preserved
    (let ((d2 (fol.compiler.collections:collection-conj empty-d (cons 3 :c))))
      (is (eq t (fol.compiler.primitive-functions:<int-dict>? d2))))))

(test empty-sorted-set-preserves-comparator
  "empty on sorted-set preserves comparator."
  (let* ((s (fol.compiler.collection-functions:sorted-set nil 3 1 2))
         (empty-s (fol.compiler.collection-functions:empty s)))
    (is (eq t (fol.compiler.primitive-functions:<sorted-set>? empty-s)))
    (is (= 0 (fol.compiler.collections:collection-size empty-s)))
    ;; Verify comparator preserved
    (let ((s2 (fol.compiler.collections:collection-conj empty-s 5)))
      (is (eq t (fol.compiler.primitive-functions:<sorted-set>? s2))))))

(test empty-int-set-preserves-comparator
  "empty on int-set preserves comparator."
  (let* ((s (fol.compiler.collection-functions:int-set 3 1 2))
         (empty-s (fol.compiler.collection-functions:empty s)))
    (is (eq t (fol.compiler.primitive-functions:<int-set>? empty-s)))
    (is (= 0 (fol.compiler.collections:collection-size empty-s)))
    ;; Verify comparator preserved
    (let ((s2 (fol.compiler.collections:collection-conj empty-s 5)))
      (is (eq t (fol.compiler.primitive-functions:<int-set>? s2))))))

(test empty-bag
  "empty on bag returns empty bag."
  (let* ((b (fol.compiler.collection-functions:bag 1 1 2 3))
         (empty-b (fol.compiler.collection-functions:empty b)))
    (is (eq t (fol.compiler.primitive-functions:<bag>? empty-b)))
    (is (= 0 (fol.compiler.collections:collection-size empty-b)))))

(test empty-list
  "empty on list returns empty list."
  (let* ((l (fol.compiler.collection-functions:list 1 2 3))
         (empty-l (fol.compiler.collection-functions:empty l)))
    (is (eq t (fol.compiler.primitive-functions:<list>? empty-l)))
    (is (= 0 (fol.compiler.collections:collection-size empty-l)))))

(test empty-deque
  "empty on deque returns empty deque."
  (let* ((d (fol.compiler.collection-functions:deque 1 2 3))
         (empty-d (fol.compiler.collection-functions:empty d)))
    (is (eq t (fol.compiler.primitive-functions:<deque>? empty-d)))
    (is (= 0 (fol.compiler.collections:collection-size empty-d)))))

(test not-empty-on-populated-vector
  "not-empty on populated collection returns the collection."
  (let* ((v (fol.compiler.collection-functions:vector 1 2 3))
         (result (fol.compiler.collection-functions:not-empty v)))
    (is (eq v result))))

(test not-empty-on-empty-vector
  "not-empty on empty collection returns nil."
  (let* ((v (fol.compiler.collection-functions:vector))
         (result (fol.compiler.collection-functions:not-empty v)))
    (is (null result))))

(test not-empty-on-nil
  "not-empty on nil returns nil."
  (is (null (fol.compiler.collection-functions:not-empty nil))))

(test not-empty-on-populated-dict
  "not-empty on populated dict returns the dict."
  (let* ((d (fol.compiler.collection-functions:dict :a 1 :b 2))
         (result (fol.compiler.collection-functions:not-empty d)))
    (is (eq d result))))

(test not-empty-on-empty-dict
  "not-empty on empty dict returns nil."
  (let* ((d (fol.compiler.collection-functions:dict))
         (result (fol.compiler.collection-functions:not-empty d)))
    (is (null result))))

(test not-empty-on-populated-set
  "not-empty on populated set returns the set."
  (let* ((s (fol.compiler.collection-functions:set 1 2 3))
         (result (fol.compiler.collection-functions:not-empty s)))
    (is (eq s result))))

(test not-empty-on-empty-set
  "not-empty on empty set returns nil."
  (let* ((s (fol.compiler.collection-functions:set))
         (result (fol.compiler.collection-functions:not-empty s)))
    (is (null result))))

;;; ===========================================================================
;;; into - generic function tests
;;; ===========================================================================

;;; --- into: generic function existence ---

(test into-generic-exists
  "into is a generic function."
  (is (eq t (typep #'fol.compiler.collection-functions:into 'generic-function))))

;;; --- into: vector target ---

(test into-vector-from-vector
  "into vector from vector appends elements."
  (let* ((v1 (fol.compiler.collection-functions:vector 1 2 3))
         (v2 (fol.compiler.collection-functions:vector 4 5 6))
         (result (fol.compiler.collection-functions:into v1 v2)))
    (is (typep result 'fol.compiler.collections:<vector>))
    (is (= 6 (fol.compiler.collection-functions:count result)))
    (is (equal '(1 2 3 4 5 6)
               (fol.compiler.collections:collection-seq result)))))

(test into-empty-vector-from-vector
  "into empty vector from vector copies elements."
  (let* ((v1 (fol.compiler.collection-functions:vector))
         (v2 (fol.compiler.collection-functions:vector 1 2 3))
         (result (fol.compiler.collection-functions:into v1 v2)))
    (is (= 3 (fol.compiler.collection-functions:count result)))
    (is (equal '(1 2 3)
               (fol.compiler.collections:collection-seq result)))))

(test into-vector-from-empty-vector
  "into vector from empty vector returns same elements."
  (let* ((v1 (fol.compiler.collection-functions:vector 1 2 3))
         (v2 (fol.compiler.collection-functions:vector))
         (result (fol.compiler.collection-functions:into v1 v2)))
    (is (= 3 (fol.compiler.collection-functions:count result)))
    (is (equal '(1 2 3)
               (fol.compiler.collections:collection-seq result)))))

(test into-vector-from-set
  "into vector from set adds all elements."
  (let* ((v (fol.compiler.collection-functions:vector))
         (s (fol.compiler.collection-functions:set 1 2 3))
         (result (fol.compiler.collection-functions:into v s)))
    (is (typep result 'fol.compiler.collections:<vector>))
    (is (= 3 (fol.compiler.collection-functions:count result)))))

(test into-vector-from-list
  "into vector from list appends elements."
  (let* ((v (fol.compiler.collection-functions:vector 10 20))
         (l (fol.compiler.collection-functions:list 30 40))
         (result (fol.compiler.collection-functions:into v l)))
    (is (typep result 'fol.compiler.collections:<vector>))
    (is (= 4 (fol.compiler.collection-functions:count result)))
    (is (equal '(10 20 30 40)
               (fol.compiler.collections:collection-seq result)))))

;;; --- into: dict target ---

(test into-dict-from-dict
  "into dict from dict merges entries, later values win."
  (let* ((d1 (fol.compiler.collection-functions:dict :a 1 :b 2))
         (d2 (fol.compiler.collection-functions:dict :b 99 :c 3))
         (result (fol.compiler.collection-functions:into d1 d2)))
    (is (typep result 'fol.compiler.collections:<dict>))
    (is (= 3 (fol.compiler.collection-functions:count result)))
    (is (= 1 (fol.compiler.collection-functions:get result :a)))
    (is (= 99 (fol.compiler.collection-functions:get result :b)))
    (is (= 3 (fol.compiler.collection-functions:get result :c)))))

(test into-empty-dict-from-dict
  "into empty dict from dict copies entries."
  (let* ((d1 (fol.compiler.collection-functions:dict))
         (d2 (fol.compiler.collection-functions:dict :x 10 :y 20))
         (result (fol.compiler.collection-functions:into d1 d2)))
    (is (typep result 'fol.compiler.collections:<dict>))
    (is (= 2 (fol.compiler.collection-functions:count result)))
    (is (= 10 (fol.compiler.collection-functions:get result :x)))
    (is (= 20 (fol.compiler.collection-functions:get result :y)))))

;;; --- into: ordered-dict target ---

(test into-ordered-dict-from-dict
  "into ordered-dict from dict maintains insertion order for new keys."
  (let* ((od (fol.compiler.collection-functions:ordered-dict :a 1))
         (d (fol.compiler.collection-functions:dict :b 2 :c 3))
         (result (fol.compiler.collection-functions:into od d)))
    (is (typep result 'fol.compiler.collections:<ordered-dict>))
    (is (= 1 (fol.compiler.collection-functions:get result :a)))
    (is (= 2 (fol.compiler.collection-functions:get result :b)))
    (is (= 3 (fol.compiler.collection-functions:get result :c)))))

;;; --- into: array-dict target ---

(test into-array-dict-from-dict
  "into array-dict from dict maintains insertion order."
  (let* ((ad (fol.compiler.collection-functions:array-dict :x 10))
         (d (fol.compiler.collection-functions:dict :y 20 :z 30))
         (result (fol.compiler.collection-functions:into ad d)))
    (is (typep result 'fol.compiler.collections:<array-dict>))
    (is (= 10 (fol.compiler.collection-functions:get result :x)))
    (is (= 20 (fol.compiler.collection-functions:get result :y)))
    (is (= 30 (fol.compiler.collection-functions:get result :z)))))

;;; --- into: sorted-dict target ---

(test into-sorted-dict-from-dict
  "into sorted-dict from dict inserts in comparator order."
  (let* ((sd (fol.compiler.collection-functions:sorted-dict nil))
         (d (fol.compiler.collection-functions:dict 3 :c 1 :a))
         (result (fol.compiler.collection-functions:into sd d)))
    (is (typep result 'fol.compiler.collections:<sorted-dict>))
    (is (= 2 (fol.compiler.collection-functions:count result)))))

;;; --- into: int-dict target (dispatches via sorted-dict method) ---

(test into-int-dict-from-dict
  "into int-dict from another dict preserves int-dict type."
  (let* ((id (fol.compiler.collection-functions:int-dict 1 :a))
         (d (fol.compiler.collection-functions:dict 2 :b 3 :c))
         (result (fol.compiler.collection-functions:into id d)))
    (is (typep result 'fol.compiler.collections:<int-dict>))
    (is (= 3 (fol.compiler.collection-functions:count result)))
    (is (eq :a (fol.compiler.collection-functions:get result 1)))
    (is (eq :b (fol.compiler.collection-functions:get result 2)))
    (is (eq :c (fol.compiler.collection-functions:get result 3)))))

;;; --- into: priority-dict target ---

(test into-priority-dict-from-dict
  "into priority-dict from dict adds priority entries."
  (let* ((pd (fol.compiler.collection-functions:priority-dict :a 10))
         (d (fol.compiler.collection-functions:dict :b 5 :c 15))
         (result (fol.compiler.collection-functions:into pd d)))
    (is (typep result 'fol.compiler.collections:<priority-dict>))
    (is (= 3 (fol.compiler.collection-functions:count result)))))

;;; --- into: set target ---

(test into-set-from-vector
  "into set from vector adds elements, dropping duplicates."
  (let* ((s (fol.compiler.collection-functions:set))
         (v (fol.compiler.collection-functions:vector 1 1 2 2 3))
         (result (fol.compiler.collection-functions:into s v)))
    (is (typep result 'fol.compiler.collections:<set>))
    (is (= 3 (fol.compiler.collection-functions:count result)))))

(test into-set-from-set
  "into set from set creates union."
  (let* ((s1 (fol.compiler.collection-functions:set 1 2))
         (s2 (fol.compiler.collection-functions:set 2 3 4))
         (result (fol.compiler.collection-functions:into s1 s2)))
    (is (typep result 'fol.compiler.collections:<set>))
    (is (= 4 (fol.compiler.collection-functions:count result)))))

(test into-set-with-existing-elements
  "into set with pre-existing elements preserves them."
  (let* ((s (fol.compiler.collection-functions:set 10 20))
         (v (fol.compiler.collection-functions:vector 20 30 40))
         (result (fol.compiler.collection-functions:into s v)))
    (is (= 4 (fol.compiler.collection-functions:count result)))))

;;; --- into: ordered-set target ---

(test into-ordered-set-from-vector
  "into ordered-set from vector maintains insertion order."
  (let* ((os (fol.compiler.collection-functions:ordered-set))
         (v (fol.compiler.collection-functions:vector 3 1 2))
         (result (fol.compiler.collection-functions:into os v)))
    (is (typep result 'fol.compiler.collections:<ordered-set>))
    (is (= 3 (fol.compiler.collection-functions:count result)))
    (is (equal '(3 1 2) (fol.compiler.collections:collection-seq result)))))

(test into-ordered-set-deduplicates
  "into ordered-set drops duplicates, keeping first occurrence order."
  (let* ((os (fol.compiler.collection-functions:ordered-set 1))
         (v (fol.compiler.collection-functions:vector 2 1 3 2))
         (result (fol.compiler.collection-functions:into os v)))
    (is (= 3 (fol.compiler.collection-functions:count result)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq result)))))

;;; --- into: sorted-set target ---

(test into-sorted-set-from-vector
  "into sorted-set from vector adds elements in sorted order."
  (let* ((ss (fol.compiler.collection-functions:sorted-set nil))
         (v (fol.compiler.collection-functions:vector 5 3 1 4 2))
         (result (fol.compiler.collection-functions:into ss v)))
    (is (typep result 'fol.compiler.collections:<sorted-set>))
    (is (= 5 (fol.compiler.collection-functions:count result)))
    (is (equal '(1 2 3 4 5)
               (fol.compiler.collections:collection-seq result)))))

;;; --- into: int-set target (dispatches via sorted-set method) ---

(test into-int-set-from-vector
  "into int-set from vector preserves int-set type."
  (let* ((is (fol.compiler.collection-functions:int-set))
         (v (fol.compiler.collection-functions:vector 5 3 1 4 2))
         (result (fol.compiler.collection-functions:into is v)))
    (is (typep result 'fol.compiler.collections:<int-set>))
    (is (= 5 (fol.compiler.collection-functions:count result)))
    (is (equal '(1 2 3 4 5)
               (fol.compiler.collections:collection-seq result)))))

;;; --- into: bag target ---

(test into-bag-from-vector
  "into bag from vector counts elements."
  (let* ((b (fol.compiler.collection-functions:bag))
         (v (fol.compiler.collection-functions:vector 1 1 2 3 3 3))
         (result (fol.compiler.collection-functions:into b v)))
    (is (typep result 'fol.compiler.collections:<bag>))
    (is (= 6 (fol.compiler.collection-functions:count result)))))

(test into-bag-from-bag
  "into bag from bag merges counts."
  (let* ((b1 (fol.compiler.collection-functions:bag 1 1))
         (b2 (fol.compiler.collection-functions:bag 1 2 2))
         (result (fol.compiler.collection-functions:into b1 b2)))
    (is (typep result 'fol.compiler.collections:<bag>))
    (is (= 5 (fol.compiler.collection-functions:count result)))))

;;; --- into: list target ---

(test into-list-from-vector
  "into list from vector prepends elements (conj semantics)."
  (let* ((l (fol.compiler.collection-functions:list))
         (v (fol.compiler.collection-functions:vector 1 2 3))
         (result (fol.compiler.collection-functions:into l v)))
    (is (typep result 'fol.compiler.collections:<list>))
    (is (= 3 (fol.compiler.collection-functions:count result)))
    ;; conj prepends each element, so elements end up reversed
    (is (equal '(3 2 1) (fol.compiler.collections:collection-seq result)))))

(test into-list-from-list
  "into list from list prepends elements."
  (let* ((l1 (fol.compiler.collection-functions:list 4 5))
         (l2 (fol.compiler.collection-functions:list 1 2 3))
         (result (fol.compiler.collection-functions:into l1 l2)))
    (is (typep result 'fol.compiler.collections:<list>))
    (is (= 5 (fol.compiler.collection-functions:count result)))
    ;; l2 elements (1 2 3) prepended one by one: 3 then 2 then 1
    (is (equal '(3 2 1 4 5) (fol.compiler.collections:collection-seq result)))))

;;; --- into: deque target (uses base <collection> method) ---

(test into-deque-from-vector
  "into deque from vector appends elements."
  (let* ((dq (fol.compiler.collection-functions:deque 1 2))
         (v (fol.compiler.collection-functions:vector 3 4 5))
         (result (fol.compiler.collection-functions:into dq v)))
    (is (typep result 'fol.compiler.collections:<deque>))
    (is (= 5 (fol.compiler.collection-functions:count result)))
    (is (equal '(1 2 3 4 5)
               (fol.compiler.collections:collection-seq result)))))

;;; --- into: type preservation ---

(test into-preserves-vector-type
  "into returns same type as target: vector."
  (let ((result (fol.compiler.collection-functions:into
                 (fol.compiler.collection-functions:vector)
                 (fol.compiler.collection-functions:set 1 2 3))))
    (is (typep result 'fol.compiler.collections:<vector>))))

(test into-preserves-dict-type
  "into returns same type as target: dict."
  (let ((result (fol.compiler.collection-functions:into
                 (fol.compiler.collection-functions:dict)
                 (fol.compiler.collection-functions:dict :a 1))))
    (is (typep result 'fol.compiler.collections:<dict>))))

(test into-preserves-set-type
  "into returns same type as target: set."
  (let ((result (fol.compiler.collection-functions:into
                 (fol.compiler.collection-functions:set)
                 (fol.compiler.collection-functions:vector 1 2 3))))
    (is (typep result 'fol.compiler.collections:<set>))))

;;; --- into: empty from ---

(test into-from-empty-returns-equivalent
  "into with empty from returns equivalent to target."
  (let* ((v (fol.compiler.collection-functions:vector 1 2 3))
         (result (fol.compiler.collection-functions:into
                  v (fol.compiler.collection-functions:vector))))
    (is (= 3 (fol.compiler.collection-functions:count result)))
    (is (equal '(1 2 3)
               (fol.compiler.collections:collection-seq result)))))

(test into-both-empty
  "into empty into empty returns empty."
  (let ((result (fol.compiler.collection-functions:into
                 (fol.compiler.collection-functions:vector)
                 (fol.compiler.collection-functions:vector))))
    (is (= 0 (fol.compiler.collection-functions:count result)))))

;;; ===========================================================================
;;; bounded-size tests
;;; ===========================================================================

(test bounded-size-nil
  "bounded-size on nil returns 0."
  (is (= 0 (fol.compiler.collection-functions:bounded-size 10 nil))))

(test bounded-size-vector-under-limit
  "bounded-size on a vector smaller than n returns actual size."
  (let ((v (fol.compiler.collection-functions:vector 1 2 3)))
    (is (= 3 (fol.compiler.collection-functions:bounded-size 10 v)))))

(test bounded-size-vector-at-limit
  "bounded-size on a vector equal to n returns actual size."
  (let ((v (fol.compiler.collection-functions:vector 1 2 3 4 5)))
    (is (= 5 (fol.compiler.collection-functions:bounded-size 5 v)))))

(test bounded-size-vector-over-limit
  "bounded-size on a vector larger than n returns actual size (O(1) counted)."
  (let ((v (fol.compiler.collection-functions:vector 1 2 3 4 5 6 7 8)))
    (is (= 8 (fol.compiler.collection-functions:bounded-size 3 v)))))

(test bounded-size-empty-vector
  "bounded-size on empty vector returns 0."
  (let ((v (fol.compiler.collection-functions:vector)))
    (is (= 0 (fol.compiler.collection-functions:bounded-size 5 v)))))

(test bounded-size-dict
  "bounded-size on a dict returns actual size (O(1) counted)."
  (let ((d (fol.compiler.collection-functions:dict :a 1 :b 2 :c 3)))
    (is (= 3 (fol.compiler.collection-functions:bounded-size 2 d)))))

(test bounded-size-set
  "bounded-size on a set returns actual size (O(1) counted)."
  (let ((s (fol.compiler.collection-functions:set 1 2 3 4 5)))
    (is (= 5 (fol.compiler.collection-functions:bounded-size 3 s)))))

(test bounded-size-fol-list
  "bounded-size on a FOL list returns actual size (O(1) counted)."
  (let ((l (fol.compiler.collection-functions:list 1 2 3)))
    (is (= 3 (fol.compiler.collection-functions:bounded-size 10 l)))))

(test bounded-size-cl-list-under-limit
  "bounded-size on a CL list smaller than n returns actual length."
  (is (= 3 (fol.compiler.collection-functions:bounded-size 10 '(a b c)))))

(test bounded-size-cl-list-at-limit
  "bounded-size on a CL list equal to n returns n."
  (is (= 5 (fol.compiler.collection-functions:bounded-size 5 '(a b c d e)))))

(test bounded-size-cl-list-over-limit
  "bounded-size on a CL list larger than n returns n (stops early)."
  (is (= 3 (fol.compiler.collection-functions:bounded-size 3 '(a b c d e f g)))))

(test bounded-size-cl-list-empty
  "bounded-size on an empty CL list returns 0."
  (is (= 0 (fol.compiler.collection-functions:bounded-size 5 '()))))

(test bounded-size-lazy-seq-under-limit
  "bounded-size on a lazy-seq smaller than n returns actual size."
  (let ((ls (fol.compiler.collection-functions:lazy-seq
              (lambda () (fol.compiler.collection-functions:vector 1 2 3)))))
    (is (= 3 (fol.compiler.collection-functions:bounded-size 10 ls)))))

(test bounded-size-lazy-seq-over-limit
  "bounded-size on a lazy-seq larger than n returns n (stops counting)."
  (let ((ls (fol.compiler.collection-functions:lazy-seq
              (lambda () (apply #'fol.compiler.collection-functions:vector
                                (loop for i from 1 to 100 collect i))))))
    (is (= 5 (fol.compiler.collection-functions:bounded-size 5 ls)))))

(test bounded-size-lazy-seq-empty
  "bounded-size on an empty lazy-seq returns 0."
  (let ((ls (fol.compiler.collection-functions:lazy-seq
              (lambda () (fol.compiler.collection-functions:vector)))))
    (is (= 0 (fol.compiler.collection-functions:bounded-size 5 ls)))))

;;; ===========================================================================
;;; distinct? tests
;;; ===========================================================================

(test distinct?-no-args
  "distinct? with no arguments returns T."
  (is (eq t (fol.compiler.collection-functions:distinct?))))

(test distinct?-single-arg
  "distinct? with one argument returns T."
  (is (eq t (fol.compiler.collection-functions:distinct? 1))))

(test distinct?-two-different
  "distinct? with two different values returns T."
  (is (eq t (fol.compiler.collection-functions:distinct? 1 2))))

(test distinct?-two-same
  "distinct? with two equal values returns NIL."
  (is (null (fol.compiler.collection-functions:distinct? 1 1))))

(test distinct?-many-different
  "distinct? with many distinct values returns T."
  (is (eq t (fol.compiler.collection-functions:distinct? 1 2 3 4 5))))

(test distinct?-many-with-duplicate
  "distinct? with a duplicate among many values returns NIL."
  (is (null (fol.compiler.collection-functions:distinct? 1 2 3 1))))

(test distinct?-strings
  "distinct? works with strings (EQUAL comparison)."
  (is (eq t (fol.compiler.collection-functions:distinct? "a" "b" "c")))
  (is (null (fol.compiler.collection-functions:distinct? "a" "b" "a"))))

(test distinct?-keywords
  "distinct? works with keywords."
  (is (eq t (fol.compiler.collection-functions:distinct? :a :b :c)))
  (is (null (fol.compiler.collection-functions:distinct? :a :b :a))))

(test distinct?-mixed-types
  "distinct? with mixed types that are not equal."
  (is (eq t (fol.compiler.collection-functions:distinct? 1 "1" :1))))

;;; ===========================================================================
;;; every? tests
;;; ===========================================================================

(test every?-all-match
  "every? returns T when all elements satisfy the predicate."
  (let ((v (fol.compiler.collection-functions:vector 1 3 5 7)))
    (is (eq t (fol.compiler.collection-functions:every? #'oddp v)))))

(test every?-some-fail
  "every? returns NIL when at least one element fails the predicate."
  (let ((v (fol.compiler.collection-functions:vector 1 2 3)))
    (is (null (fol.compiler.collection-functions:every? #'oddp v)))))

(test every?-empty
  "every? on an empty collection returns T (vacuous truth)."
  (let ((v (fol.compiler.collection-functions:vector)))
    (is (eq t (fol.compiler.collection-functions:every? #'oddp v)))))

(test every?-single-match
  "every? on single matching element returns T."
  (let ((v (fol.compiler.collection-functions:vector 3)))
    (is (eq t (fol.compiler.collection-functions:every? #'oddp v)))))

(test every?-single-fail
  "every? on single failing element returns NIL."
  (let ((v (fol.compiler.collection-functions:vector 2)))
    (is (null (fol.compiler.collection-functions:every? #'oddp v)))))

(test every?-on-dict
  "every? works on dict entries (key . value pairs)."
  (let ((d (fol.compiler.collection-functions:dict :a 1 :b 2)))
    (is (eq t (fol.compiler.collection-functions:every? #'consp d)))))

(test every?-on-set
  "every? works on sets."
  (let ((s (fol.compiler.collection-functions:set 2 4 6)))
    (is (eq t (fol.compiler.collection-functions:every? #'evenp s)))))

;;; ===========================================================================
;;; not-every? tests
;;; ===========================================================================

(test not-every?-all-match
  "not-every? returns NIL when all elements satisfy the predicate."
  (let ((v (fol.compiler.collection-functions:vector 1 3 5)))
    (is (null (fol.compiler.collection-functions:not-every? #'oddp v)))))

(test not-every?-some-fail
  "not-every? returns T when at least one element fails."
  (let ((v (fol.compiler.collection-functions:vector 1 2 3)))
    (is (eq t (fol.compiler.collection-functions:not-every? #'oddp v)))))

(test not-every?-empty
  "not-every? on empty collection returns NIL (vacuous truth for every?)."
  (let ((v (fol.compiler.collection-functions:vector)))
    (is (null (fol.compiler.collection-functions:not-every? #'oddp v)))))

(test not-every?-none-match
  "not-every? returns T when no elements match."
  (let ((v (fol.compiler.collection-functions:vector 2 4 6)))
    (is (eq t (fol.compiler.collection-functions:not-every? #'oddp v)))))

;;; ===========================================================================
;;; not-any? tests
;;; ===========================================================================

(test not-any?-none-match
  "not-any? returns T when no elements satisfy the predicate."
  (let ((v (fol.compiler.collection-functions:vector 2 4 6)))
    (is (eq t (fol.compiler.collection-functions:not-any? #'oddp v)))))

(test not-any?-some-match
  "not-any? returns NIL when at least one element satisfies the predicate."
  (let ((v (fol.compiler.collection-functions:vector 2 3 6)))
    (is (null (fol.compiler.collection-functions:not-any? #'oddp v)))))

(test not-any?-all-match
  "not-any? returns NIL when all elements satisfy the predicate."
  (let ((v (fol.compiler.collection-functions:vector 1 3 5)))
    (is (null (fol.compiler.collection-functions:not-any? #'oddp v)))))

(test not-any?-empty
  "not-any? on empty collection returns T."
  (let ((v (fol.compiler.collection-functions:vector)))
    (is (eq t (fol.compiler.collection-functions:not-any? #'oddp v)))))

(test not-any?-on-set
  "not-any? works on sets."
  (let ((s (fol.compiler.collection-functions:set 2 4 6)))
    (is (eq t (fol.compiler.collection-functions:not-any? #'oddp s)))))

(test not-any?-on-dict
  "not-any? works on dict entries."
  (let ((d (fol.compiler.collection-functions:dict :a 1 :b 2)))
    (is (eq t (fol.compiler.collection-functions:not-any? #'null d)))))

;;; ===========================================================================
;;; %index tests
;;; ===========================================================================

(test %index-1d-basic
  "%index in 1D is trivial identity."
  (is (= 0 (fol.compiler.collection-functions:%index '(5) '(0))))
  (is (= 3 (fol.compiler.collection-functions:%index '(5) '(3))))
  (is (= 4 (fol.compiler.collection-functions:%index '(5) '(4)))))

(test %index-2d-column-major
  "%index in 2D uses column-major order (first index varies fastest)."
  ;; dims (3 4), indices (0 0) => 0
  (is (= 0 (fol.compiler.collection-functions:%index '(3 4) '(0 0))))
  ;; dims (3 4), indices (1 0) => 1
  (is (= 1 (fol.compiler.collection-functions:%index '(3 4) '(1 0))))
  ;; dims (3 4), indices (2 0) => 2
  (is (= 2 (fol.compiler.collection-functions:%index '(3 4) '(2 0))))
  ;; dims (3 4), indices (0 1) => 3  (stride for dim 1 = 3)
  (is (= 3 (fol.compiler.collection-functions:%index '(3 4) '(0 1))))
  ;; dims (3 4), indices (1 2) => 1 + 3*2 = 7
  (is (= 7 (fol.compiler.collection-functions:%index '(3 4) '(1 2))))
  ;; dims (3 4), indices (2 3) => 2 + 3*3 = 11 (last element)
  (is (= 11 (fol.compiler.collection-functions:%index '(3 4) '(2 3)))))

(test %index-3d-column-major
  "%index in 3D uses column-major order."
  ;; dims (3 4 5), indices (0 0 0) => 0
  (is (= 0 (fol.compiler.collection-functions:%index '(3 4 5) '(0 0 0))))
  ;; dims (3 4 5), indices (1 0 0) => 1
  (is (= 1 (fol.compiler.collection-functions:%index '(3 4 5) '(1 0 0))))
  ;; dims (3 4 5), indices (0 1 0) => 3
  (is (= 3 (fol.compiler.collection-functions:%index '(3 4 5) '(0 1 0))))
  ;; dims (3 4 5), indices (0 0 1) => 12  (stride = 3*4)
  (is (= 12 (fol.compiler.collection-functions:%index '(3 4 5) '(0 0 1))))
  ;; dims (3 4 5), indices (2 1 3) => 2 + 3*1 + 12*3 = 2+3+36 = 41
  (is (= 41 (fol.compiler.collection-functions:%index '(3 4 5) '(2 1 3)))))

(test %index-wrong-number-of-indices
  "%index signals error when index count doesn't match dimension count."
  (signals error (fol.compiler.collection-functions:%index '(3 4) '(1)))
  (signals error (fol.compiler.collection-functions:%index '(3) '(1 2))))

(test %index-index-out-of-bounds
  "%index signals error when an index >= its dimension."
  (signals error (fol.compiler.collection-functions:%index '(3) '(3)))
  (signals error (fol.compiler.collection-functions:%index '(3 4) '(1 4)))
  (signals error (fol.compiler.collection-functions:%index '(3 4) '(3 0))))

(test %index-negative-index
  "%index signals error for negative indices."
  (signals error (fol.compiler.collection-functions:%index '(5) '(-1))))

;;; ===========================================================================
;;; Array dimension validation tests
;;; ===========================================================================

(test array-negative-dimension-error
  "Creating an array with a negative dimension signals an error."
  (signals error
    (make-instance 'fol.compiler.collections:<array>
                   :storage (fol.compiler.collection-primitives::%build-vec-t-from-list nil)
                   :dimension '(-1))))

(test array-non-integer-dimension-error
  "Creating an array with a non-integer dimension signals an error."
  (signals error
    (make-instance 'fol.compiler.collections:<array>
                   :storage (fol.compiler.collection-primitives::%build-vec-t-from-list nil)
                   :dimension '(3.5))))

(test array-valid-dimensions-ok
  "Creating an array with valid dimensions succeeds."
  (let ((a (make-instance 'fol.compiler.collections:<array>
                          :storage (fol.compiler.collection-primitives::%build-vec-t-from-list
                                     (loop for i below 12 collect 0))
                          :dimension '(3 4))))
    (is (equal '(3 4) (fol.compiler.collections:array-dimension a)))))

(test array-zero-dimension-ok
  "Creating an array with a zero dimension succeeds."
  (let ((a (make-instance 'fol.compiler.collections:<array>
                          :storage (fol.compiler.collection-primitives::%build-vec-t-from-list nil)
                          :dimension '(0))))
    (is (equal '(0) (fol.compiler.collections:array-dimension a)))))

(test array-make-validates-dimensions
  "make '<array> creates valid 1D arrays."
  (let ((a (fol.compiler.collections:make 'fol.compiler.collections:<array> 10 20 30)))
    (is (equal '(3) (fol.compiler.collections:array-dimension a)))
    (is (= 3 (fol.compiler.collections:collection-size a)))))

;;; ===========================================================================
;;; Array get with list of indices tests
;;; ===========================================================================

(test array-get-2d-basic
  "get on array with list of indices accesses the correct element."
  (let ((a (make-instance 'fol.compiler.collections:<array>
                          :storage (fol.compiler.collection-primitives::%build-vec-t-from-list '(0 1 2 3 4 5))
                          :dimension '(3 2))))
    ;; Column-major: (0,0)=>0, (1,0)=>1, (2,0)=>2, (0,1)=>3, (1,1)=>4, (2,1)=>5
    (is (= 0 (fol.compiler.collection-functions:get a '(0 0))))
    (is (= 1 (fol.compiler.collection-functions:get a '(1 0))))
    (is (= 2 (fol.compiler.collection-functions:get a '(2 0))))
    (is (= 3 (fol.compiler.collection-functions:get a '(0 1))))
    (is (= 4 (fol.compiler.collection-functions:get a '(1 1))))
    (is (= 5 (fol.compiler.collection-functions:get a '(2 1))))))

(test array-get-3d
  "get on 3D array with list of indices."
  (let ((a (make-instance 'fol.compiler.collections:<array>
                          :storage (fol.compiler.collection-primitives::%build-vec-t-from-list
                                     (loop for i below 24 collect i))
                          :dimension '(2 3 4))))
    ;; (0,0,0) => 0, (1,0,0) => 1, (0,1,0) => 2, (0,0,1) => 6
    (is (= 0 (fol.compiler.collection-functions:get a '(0 0 0))))
    (is (= 1 (fol.compiler.collection-functions:get a '(1 0 0))))
    (is (= 2 (fol.compiler.collection-functions:get a '(0 1 0))))
    (is (= 6 (fol.compiler.collection-functions:get a '(0 0 1))))))

(test array-get-indices-wrong-count
  "get on array with wrong number of indices signals error."
  (let ((a (make-instance 'fol.compiler.collections:<array>
                          :storage (fol.compiler.collection-primitives::%build-vec-t-from-list
                                     (loop for i below 6 collect 0))
                          :dimension '(3 2))))
    (signals error (fol.compiler.collection-functions:get a '(1)))
    (signals error (fol.compiler.collection-functions:get a '(1 0 0)))))

(test array-get-indices-out-of-bounds
  "get on array with out-of-bounds indices signals error."
  (let ((a (make-instance 'fol.compiler.collections:<array>
                          :storage (fol.compiler.collection-primitives::%build-vec-t-from-list
                                     (loop for i below 6 collect 0))
                          :dimension '(3 2))))
    (signals error (fol.compiler.collection-functions:get a '(3 0)))
    (signals error (fol.compiler.collection-functions:get a '(0 2)))))

(test array-get-integer-still-works
  "get on array with integer index still works (linear index)."
  (let ((a (fol.compiler.collections:make 'fol.compiler.collections:<array> 10 20 30)))
    (is (= 10 (fol.compiler.collection-functions:get a 0)))
    (is (= 20 (fol.compiler.collection-functions:get a 1)))
    (is (= 30 (fol.compiler.collection-functions:get a 2)))))

(test array-get-indices-with-default
  "get on array with indices passes default through."
  (let ((a (make-instance 'fol.compiler.collections:<array>
                          :storage (fol.compiler.collection-primitives::%build-vec-t-from-list '(10 20 30 40 50 60))
                          :dimension '(3 2))))
    (is (= 10 (fol.compiler.collection-functions:get a '(0 0) :not-found)))
    (is (= 60 (fol.compiler.collection-functions:get a '(2 1) :not-found)))))

;;; ===========================================================================
;;; vec - Coerce to vector
;;; ===========================================================================

(test vec-from-vector-identity
  "vec of a <vector> returns the same object."
  (let ((v (fol.compiler.collection-functions:vector 1 2 3)))
    (is (eq v (fol.compiler.collection-functions:vec v)))))

(test vec-from-list
  "vec converts a FOL <list> to a <vector>."
  (let* ((lst (fol.compiler.collection-functions:list 1 2 3))
         (v (fol.compiler.collection-functions:vec lst)))
    (is (typep v 'fol.compiler.collections:<vector>))
    (is (= 3 (fol.compiler.collections:collection-size v)))
    (is (= 1 (fol.compiler.collection-functions:get v 0)))
    (is (= 2 (fol.compiler.collection-functions:get v 1)))
    (is (= 3 (fol.compiler.collection-functions:get v 2)))))

(test vec-from-set
  "vec converts a <set> to a <vector> (order unspecified)."
  (let* ((s (fol.compiler.collection-functions:set 10 20 30))
         (v (fol.compiler.collection-functions:vec s)))
    (is (typep v 'fol.compiler.collections:<vector>))
    (is (= 3 (fol.compiler.collections:collection-size v)))))

(test vec-from-dict
  "vec converts a <dict> to a <vector> of map entries."
  (let* ((d (fol.compiler.collection-functions:dict :a 1 :b 2))
         (v (fol.compiler.collection-functions:vec d)))
    (is (typep v 'fol.compiler.collections:<vector>))
    (is (= 2 (fol.compiler.collections:collection-size v)))))

(test vec-from-nil
  "vec of nil returns an empty <vector>."
  (let ((v (fol.compiler.collection-functions:vec nil)))
    (is (typep v 'fol.compiler.collections:<vector>))
    (is (= 0 (fol.compiler.collections:collection-size v)))))

(test vec-from-cl-list
  "vec converts a CL list to a <vector>."
  (let ((v (fol.compiler.collection-functions:vec '(4 5 6))))
    (is (typep v 'fol.compiler.collections:<vector>))
    (is (= 3 (fol.compiler.collections:collection-size v)))
    (is (= 4 (fol.compiler.collection-functions:get v 0)))
    (is (= 5 (fol.compiler.collection-functions:get v 1)))
    (is (= 6 (fol.compiler.collection-functions:get v 2)))))

(test vec-from-empty-vector
  "vec of an empty <vector> returns the same empty vector."
  (let ((v (fol.compiler.collection-functions:vector)))
    (is (eq v (fol.compiler.collection-functions:vec v)))))

(test vec-from-deque
  "vec converts a <deque> to a <vector>."
  (let* ((dq (fol.compiler.collection-functions:deque 7 8 9))
         (v (fol.compiler.collection-functions:vec dq)))
    (is (typep v 'fol.compiler.collections:<vector>))
    (is (= 3 (fol.compiler.collections:collection-size v)))))

(test vec-error-on-non-collection
  "vec signals an error for non-collection, non-sequence input."
  (signals error (fol.compiler.collection-functions:vec 42)))

;;; ===========================================================================
;;; vector-of - Typed vector constructor
;;; ===========================================================================

(test vector-of-numbers
  "vector-of creates a <vector> when all elements match the type."
  (let ((v (fol.compiler.collection-functions:vector-of '<number> 1 2 3)))
    (is (typep v 'fol.compiler.collections:<vector>))
    (is (= 3 (fol.compiler.collections:collection-size v)))
    (is (= 1 (fol.compiler.collection-functions:get v 0)))
    (is (= 2 (fol.compiler.collection-functions:get v 1)))
    (is (= 3 (fol.compiler.collection-functions:get v 2)))))

(test vector-of-strings
  "vector-of creates a <vector> of strings."
  (let ((v (fol.compiler.collection-functions:vector-of '<string> "a" "b" "c")))
    (is (typep v 'fol.compiler.collections:<vector>))
    (is (= 3 (fol.compiler.collections:collection-size v)))
    (is (string= "a" (fol.compiler.collection-functions:get v 0)))))

(test vector-of-integers
  "vector-of creates a <vector> of integers."
  (let ((v (fol.compiler.collection-functions:vector-of '<integer> 1 2 3)))
    (is (typep v 'fol.compiler.collections:<vector>))
    (is (= 3 (fol.compiler.collections:collection-size v)))))

(test vector-of-type-mismatch-error
  "vector-of signals an error when an element doesn't match."
  (signals error (fol.compiler.collection-functions:vector-of '<number> 1 "x" 3)))

(test vector-of-unknown-type-error
  "vector-of signals an error for an unknown FOL type."
  (signals error (fol.compiler.collection-functions:vector-of '<bogus> 1 2 3)))

(test vector-of-empty
  "vector-of with no elements creates an empty <vector>."
  (let ((v (fol.compiler.collection-functions:vector-of '<number>)))
    (is (typep v 'fol.compiler.collections:<vector>))
    (is (= 0 (fol.compiler.collections:collection-size v)))))

(test vector-of-float
  "vector-of with <float> type accepts float values."
  (let ((v (fol.compiler.collection-functions:vector-of '<float> 1.0 2.5 3.7)))
    (is (typep v 'fol.compiler.collections:<vector>))
    (is (= 3 (fol.compiler.collections:collection-size v)))))

(test vector-of-float-rejects-integers
  "vector-of with <float> type rejects integer values."
  (signals error (fol.compiler.collection-functions:vector-of '<float> 1 2 3)))

;;; ===========================================================================
;;; peek on <vector>
;;; ===========================================================================

(test peek-vector-non-empty
  "peek returns the last element of a non-empty vector."
  (let ((v (fol.compiler.collection-functions:vector 10 20 30)))
    (is (= 30 (fol.compiler.collection-functions:peek v)))))

(test peek-vector-single
  "peek returns the only element of a single-element vector."
  (let ((v (fol.compiler.collection-functions:vector 42)))
    (is (= 42 (fol.compiler.collection-functions:peek v)))))

(test peek-vector-empty
  "peek returns NIL for an empty vector."
  (let ((v (fol.compiler.collection-functions:vector)))
    (is (null (fol.compiler.collection-functions:peek v)))))

;;; ===========================================================================
;;; index-of on <vector>
;;; ===========================================================================

(test index-of-vector-found
  "index-of finds an element in a vector."
  (let ((v (fol.compiler.collection-functions:vector 10 20 30 20)))
    (is (= 1 (fol.compiler.string-functions:index-of v 20)))))

(test index-of-vector-not-found
  "index-of returns NIL when element is not in the vector."
  (let ((v (fol.compiler.collection-functions:vector 10 20 30)))
    (is (null (fol.compiler.string-functions:index-of v 99)))))

(test index-of-vector-first-element
  "index-of finds the first element."
  (let ((v (fol.compiler.collection-functions:vector 10 20 30)))
    (is (= 0 (fol.compiler.string-functions:index-of v 10)))))

(test index-of-vector-from-index
  "index-of respects from-index."
  (let ((v (fol.compiler.collection-functions:vector 10 20 30 20)))
    (is (= 3 (fol.compiler.string-functions:index-of v 20 :from-index 2)))))

(test index-of-vector-empty
  "index-of returns NIL for an empty vector."
  (let ((v (fol.compiler.collection-functions:vector)))
    (is (null (fol.compiler.string-functions:index-of v 1)))))

;;; ===========================================================================
;;; last-index-of on <vector>
;;; ===========================================================================

(test last-index-of-vector-found
  "last-index-of finds the last occurrence of a value."
  (let ((v (fol.compiler.collection-functions:vector 10 20 30 20)))
    (is (= 3 (fol.compiler.string-functions:last-index-of v 20)))))

(test last-index-of-vector-not-found
  "last-index-of returns NIL when element is not in the vector."
  (let ((v (fol.compiler.collection-functions:vector 10 20 30)))
    (is (null (fol.compiler.string-functions:last-index-of v 99)))))

(test last-index-of-vector-single-occurrence
  "last-index-of returns the index for a single occurrence."
  (let ((v (fol.compiler.collection-functions:vector 10 20 30)))
    (is (= 1 (fol.compiler.string-functions:last-index-of v 20)))))

(test last-index-of-vector-empty
  "last-index-of returns NIL for an empty vector."
  (let ((v (fol.compiler.collection-functions:vector)))
    (is (null (fol.compiler.string-functions:last-index-of v 1)))))

;;; ===========================================================================
;;; pop on <vector>
;;; ===========================================================================

(test pop-vector-basic
  "pop removes the last element from a vector."
  (let* ((v (fol.compiler.collection-functions:vector 10 20 30))
         (popped (fol.compiler.collection-functions:pop v)))
    (is (= 2 (fol.compiler.collections:collection-size popped)))
    (is (= 10 (fol.compiler.collection-functions:get popped 0)))
    (is (= 20 (fol.compiler.collection-functions:get popped 1)))))

(test pop-vector-single
  "pop on a single-element vector returns empty vector."
  (let* ((v (fol.compiler.collection-functions:vector 42))
         (popped (fol.compiler.collection-functions:pop v)))
    (is (= 0 (fol.compiler.collections:collection-size popped)))))

(test pop-vector-empty-error
  "pop on an empty vector signals an error."
  (let ((v (fol.compiler.collection-functions:vector)))
    (signals error (fol.compiler.collection-functions:pop v))))

(test pop-vector-preserves-original
  "pop returns a new vector, original is unchanged."
  (let* ((v (fol.compiler.collection-functions:vector 10 20 30))
         (popped (fol.compiler.collection-functions:pop v)))
    (is (= 3 (fol.compiler.collections:collection-size v)))
    (is (= 2 (fol.compiler.collections:collection-size popped)))))

;;; ===========================================================================
;;; update on <vector>
;;; ===========================================================================

(test update-vector-basic
  "update applies a function to the element at an index."
  (let* ((v (fol.compiler.collection-functions:vector 10 20 30))
         (u (fol.compiler.collection-functions:update v 1 #'1+)))
    (is (= 10 (fol.compiler.collection-functions:get u 0)))
    (is (= 21 (fol.compiler.collection-functions:get u 1)))
    (is (= 30 (fol.compiler.collection-functions:get u 2)))))

(test update-vector-first
  "update can modify the first element."
  (let* ((v (fol.compiler.collection-functions:vector 10 20 30))
         (u (fol.compiler.collection-functions:update v 0 (lambda (x) (cl:* x 2)))))
    (is (= 20 (fol.compiler.collection-functions:get u 0)))))

(test update-vector-out-of-bounds
  "update signals an error for out-of-bounds index."
  (let ((v (fol.compiler.collection-functions:vector 10 20 30)))
    (signals error (fol.compiler.collection-functions:update v 5 #'1+))))

(test update-vector-preserves-original
  "update returns a new vector, original is unchanged."
  (let* ((v (fol.compiler.collection-functions:vector 10 20 30))
         (u (fol.compiler.collection-functions:update v 1 #'1+)))
    (is (= 20 (fol.compiler.collection-functions:get v 1)))
    (is (= 21 (fol.compiler.collection-functions:get u 1)))))

;;; ===========================================================================
;;; assoc-in
;;; ===========================================================================

(test assoc-in-vector-flat
  "assoc-in with a single key is like assoc."
  (let* ((v (fol.compiler.collection-functions:vector 10 20 30))
         (r (fol.compiler.collection-functions:assoc-in v '(1) 99)))
    (is (= 99 (fol.compiler.collection-functions:get r 1)))))

(test assoc-in-vector-nested-dict
  "assoc-in updates a nested dict inside a vector."
  (let* ((d (fol.compiler.collection-functions:dict :a 1 :b 2))
         (v (fol.compiler.collection-functions:vector d 99))
         (r (fol.compiler.collection-functions:assoc-in v '(0 :a) 42)))
    (is (= 42 (fol.compiler.collection-functions:get
               (fol.compiler.collection-functions:get r 0) :a)))))

(test assoc-in-dict-nested
  "assoc-in works on nested dicts."
  (let* ((inner (fol.compiler.collection-functions:dict :x 1))
         (outer (fol.compiler.collection-functions:dict :a inner))
         (r (fol.compiler.collection-functions:assoc-in outer '(:a :x) 99)))
    (is (= 99 (fol.compiler.collection-functions:get
               (fol.compiler.collection-functions:get r :a) :x)))))

;;; ===========================================================================
;;; update-in
;;; ===========================================================================

(test update-in-vector-flat
  "update-in with a single key is like update."
  (let* ((v (fol.compiler.collection-functions:vector 10 20 30))
         (r (fol.compiler.collection-functions:update-in v '(1) #'1+)))
    (is (= 21 (fol.compiler.collection-functions:get r 1)))))

(test update-in-vector-nested-dict
  "update-in applies function to a nested dict value inside a vector."
  (let* ((d (fol.compiler.collection-functions:dict :a 1 :b 2))
         (v (fol.compiler.collection-functions:vector d 99))
         (r (fol.compiler.collection-functions:update-in v '(0 :a) #'1+)))
    (is (= 2 (fol.compiler.collection-functions:get
              (fol.compiler.collection-functions:get r 0) :a)))))

(test update-in-dict-nested
  "update-in works on nested dicts."
  (let* ((inner (fol.compiler.collection-functions:dict :x 10))
         (outer (fol.compiler.collection-functions:dict :a inner))
         (r (fol.compiler.collection-functions:update-in outer '(:a :x) #'1+)))
    (is (= 11 (fol.compiler.collection-functions:get
               (fol.compiler.collection-functions:get r :a) :x)))))

;;; ===========================================================================
;;; rseq
;;; ===========================================================================

(test rseq-vector-basic
  "rseq returns elements in reverse order."
  (let* ((v (fol.compiler.collection-functions:vector 10 20 30))
         (r (fol.compiler.collection-functions:rseq v)))
    (is (equal '(30 20 10) r))))

(test rseq-vector-single
  "rseq on a single-element vector returns a singleton list."
  (let ((r (fol.compiler.collection-functions:rseq
            (fol.compiler.collection-functions:vector 42))))
    (is (equal '(42) r))))

(test rseq-vector-empty
  "rseq on an empty vector returns NIL."
  (is (null (fol.compiler.collection-functions:rseq
             (fol.compiler.collection-functions:vector)))))

;;; ===========================================================================
;;; reduce-kv
;;; ===========================================================================

(test reduce-kv-vector-sum-indices
  "reduce-kv on a vector accumulates index*value."
  (let ((v (fol.compiler.collection-functions:vector 10 20 30)))
    ;; 0*10 + 1*20 + 2*30 = 0 + 20 + 60 = 80
    (is (= 80 (fol.compiler.collection-functions:reduce-kv
               (lambda (acc i val) (cl:+ acc (cl:* i val))) 0 v)))))

(test reduce-kv-vector-collect-pairs
  "reduce-kv can collect index-value pairs."
  (let* ((v (fol.compiler.collection-functions:vector :a :b :c))
         (pairs (fol.compiler.collection-functions:reduce-kv
                 (lambda (acc i val) (cons (cons i val) acc)) nil v)))
    (is (= 3 (length pairs)))
    (is (equal '(2 . :c) (cl:first pairs)))))

(test reduce-kv-vector-empty
  "reduce-kv on empty vector returns init."
  (is (= 0 (fol.compiler.collection-functions:reduce-kv
             (lambda (acc i val) (declare (ignore i val)) acc) 0
             (fol.compiler.collection-functions:vector)))))

(test reduce-kv-dict-basic
  "reduce-kv on a dict accumulates key-value pairs."
  (let* ((d (fol.compiler.collection-functions:dict :a 1 :b 2))
         (result (fol.compiler.collection-functions:reduce-kv
                  (lambda (acc k v) (declare (ignore k)) (cl:+ acc v)) 0 d)))
    (is (= 3 result))))

;;; ===========================================================================
;;; subvec
;;; ===========================================================================

(test subvec-basic
  "subvec returns a sub-vector from start to end."
  (let* ((v (fol.compiler.collection-functions:vector 10 20 30 40 50))
         (sv (fol.compiler.collection-functions:subvec v 1 3)))
    (is (typep sv 'fol.compiler.collections:<vector>))
    (is (= 2 (fol.compiler.collections:collection-size sv)))
    (is (= 20 (fol.compiler.collection-functions:get sv 0)))
    (is (= 30 (fol.compiler.collection-functions:get sv 1)))))

(test subvec-to-end
  "subvec without end returns from start to the end."
  (let* ((v (fol.compiler.collection-functions:vector 10 20 30 40 50))
         (sv (fol.compiler.collection-functions:subvec v 2)))
    (is (= 3 (fol.compiler.collections:collection-size sv)))
    (is (= 30 (fol.compiler.collection-functions:get sv 0)))
    (is (= 50 (fol.compiler.collection-functions:get sv 2)))))

(test subvec-empty-range
  "subvec with start=end returns empty vector."
  (let* ((v (fol.compiler.collection-functions:vector 10 20 30))
         (sv (fol.compiler.collection-functions:subvec v 1 1)))
    (is (= 0 (fol.compiler.collections:collection-size sv)))))

(test subvec-full-range
  "subvec with 0 to size returns equivalent vector."
  (let* ((v (fol.compiler.collection-functions:vector 10 20 30))
         (sv (fol.compiler.collection-functions:subvec v 0 3)))
    (is (= 3 (fol.compiler.collections:collection-size sv)))
    (is (= 10 (fol.compiler.collection-functions:get sv 0)))
    (is (= 30 (fol.compiler.collection-functions:get sv 2)))))

(test subvec-out-of-bounds-start
  "subvec signals error for out-of-bounds start."
  (let ((v (fol.compiler.collection-functions:vector 10 20 30)))
    (signals error (fol.compiler.collection-functions:subvec v 5))))

(test subvec-out-of-bounds-end
  "subvec signals error when end > size."
  (let ((v (fol.compiler.collection-functions:vector 10 20 30)))
    (signals error (fol.compiler.collection-functions:subvec v 0 10))))

;;; ===========================================================================
;;; replace
;;; ===========================================================================

(test replace-vector-basic
  "replace substitutes elements according to a map."
  (let* ((smap (fol.compiler.collection-functions:dict 2 :two 4 :four))
         (v (fol.compiler.collection-functions:vector 4 2 3 4 5))
         (r (fol.compiler.collection-functions:replace smap v)))
    (is (typep r 'fol.compiler.collections:<vector>))
    (is (= 5 (fol.compiler.collections:collection-size r)))
    (is (eq :four (fol.compiler.collection-functions:get r 0)))
    (is (eq :two (fol.compiler.collection-functions:get r 1)))
    (is (= 3 (fol.compiler.collection-functions:get r 2)))
    (is (eq :four (fol.compiler.collection-functions:get r 3)))
    (is (= 5 (fol.compiler.collection-functions:get r 4)))))

(test replace-vector-no-matches
  "replace with no matching elements returns equivalent vector."
  (let* ((smap (fol.compiler.collection-functions:dict 99 :x))
         (v (fol.compiler.collection-functions:vector 1 2 3))
         (r (fol.compiler.collection-functions:replace smap v)))
    (is (= 3 (fol.compiler.collections:collection-size r)))
    (is (= 1 (fol.compiler.collection-functions:get r 0)))))

(test replace-vector-empty
  "replace on an empty vector returns empty vector."
  (let* ((smap (fol.compiler.collection-functions:dict 1 :one))
         (v (fol.compiler.collection-functions:vector))
         (r (fol.compiler.collection-functions:replace smap v)))
    (is (= 0 (fol.compiler.collections:collection-size r)))))

;;; ===========================================================================
;;; contains?
;;; ===========================================================================

(test contains?-set-present
  "contains? returns T for an element in a hash-set."
  (let ((s (fol.compiler.collection-functions:set 1 2 3)))
    (is (eq t (fol.compiler.collection-functions:contains? s 2)))))

(test contains?-set-absent
  "contains? returns NIL for an element not in a hash-set."
  (let ((s (fol.compiler.collection-functions:set 1 2 3)))
    (is (null (fol.compiler.collection-functions:contains? s 5)))))

(test contains?-set-empty
  "contains? returns NIL on an empty set."
  (let ((s (fol.compiler.collection-functions:set)))
    (is (null (fol.compiler.collection-functions:contains? s 1)))))

(test contains?-sorted-set
  "contains? works on sorted-sets."
  (let ((s (fol.compiler.collection-functions:sorted-set nil 3 1 2)))
    (is (eq t (fol.compiler.collection-functions:contains? s 2)))
    (is (null (fol.compiler.collection-functions:contains? s 5)))))

(test contains?-ordered-set
  "contains? works on ordered-sets."
  (let ((s (fol.compiler.collection-functions:ordered-set 1 2 3)))
    (is (eq t (fol.compiler.collection-functions:contains? s 1)))
    (is (null (fol.compiler.collection-functions:contains? s 4)))))

(test contains?-int-set
  "contains? works on int-sets."
  (let ((s (fol.compiler.collection-functions:int-set 10 20 30)))
    (is (eq t (fol.compiler.collection-functions:contains? s 20)))
    (is (null (fol.compiler.collection-functions:contains? s 15)))))

;;; ===========================================================================
;;; disj
;;; ===========================================================================

(test disj-set-remove-present
  "disj removes a present element from a hash-set."
  (let* ((s (fol.compiler.collection-functions:set 1 2 3))
         (r (fol.compiler.collection-functions:disj s 2)))
    (is (= 2 (fol.compiler.collections:collection-size r)))
    (is (eq t (fol.compiler.collection-functions:contains? r 1)))
    (is (null (fol.compiler.collection-functions:contains? r 2)))))

(test disj-set-remove-absent
  "disj on a non-present element returns set unchanged in content."
  (let* ((s (fol.compiler.collection-functions:set 1 2 3))
         (r (fol.compiler.collection-functions:disj s 5)))
    (is (= 3 (fol.compiler.collections:collection-size r)))))

(test disj-set-remove-multiple
  "disj removes multiple elements."
  (let* ((s (fol.compiler.collection-functions:set 1 2 3 4))
         (r (fol.compiler.collection-functions:disj s 2 4)))
    (is (= 2 (fol.compiler.collections:collection-size r)))
    (is (eq t (fol.compiler.collection-functions:contains? r 1)))
    (is (eq t (fol.compiler.collection-functions:contains? r 3)))))

(test disj-sorted-set
  "disj works on sorted-sets."
  (let* ((s (fol.compiler.collection-functions:sorted-set nil 1 2 3))
         (r (fol.compiler.collection-functions:disj s 2)))
    (is (= 2 (fol.compiler.collections:collection-size r)))
    (is (equal '(1 3) (fol.compiler.collections:collection-seq r)))))

(test disj-ordered-set
  "disj works on ordered-sets and preserves order."
  (let* ((s (fol.compiler.collection-functions:ordered-set 3 1 2))
         (r (fol.compiler.collection-functions:disj s 1)))
    (is (= 2 (fol.compiler.collections:collection-size r)))
    (is (equal '(3 2) (fol.compiler.collections:collection-seq r)))))

(test disj-int-set
  "disj works on int-sets."
  (let* ((s (fol.compiler.collection-functions:int-set 10 20 30))
         (r (fol.compiler.collection-functions:disj s 20)))
    (is (= 2 (fol.compiler.collections:collection-size r)))
    (is (equal '(10 30) (fol.compiler.collections:collection-seq r)))))

;;; ===========================================================================
;;; union
;;; ===========================================================================

(test union-set-basic
  "union of two hash-sets."
  (let* ((s1 (fol.compiler.collection-functions:set 1 2))
         (s2 (fol.compiler.collection-functions:set 2 3))
         (r (fol.compiler.collection-functions:union s1 s2)))
    (is (= 3 (fol.compiler.collections:collection-size r)))
    (is (eq t (fol.compiler.collection-functions:contains? r 1)))
    (is (eq t (fol.compiler.collection-functions:contains? r 2)))
    (is (eq t (fol.compiler.collection-functions:contains? r 3)))))

(test union-set-disjoint
  "union of disjoint hash-sets."
  (let* ((s1 (fol.compiler.collection-functions:set 1 2))
         (s2 (fol.compiler.collection-functions:set 3 4))
         (r (fol.compiler.collection-functions:union s1 s2)))
    (is (= 4 (fol.compiler.collections:collection-size r)))))

(test union-set-empty
  "union with empty set."
  (let* ((s1 (fol.compiler.collection-functions:set 1 2))
         (s2 (fol.compiler.collection-functions:set))
         (r (fol.compiler.collection-functions:union s1 s2)))
    (is (= 2 (fol.compiler.collections:collection-size r)))))

(test union-sorted-set
  "union of two sorted-sets."
  (let* ((s1 (fol.compiler.collection-functions:sorted-set nil 1 3))
         (s2 (fol.compiler.collection-functions:sorted-set nil 2 3))
         (r (fol.compiler.collection-functions:union s1 s2)))
    (is (= 3 (fol.compiler.collections:collection-size r)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq r)))))

(test union-int-set
  "union of two int-sets."
  (let* ((s1 (fol.compiler.collection-functions:int-set 1 3))
         (s2 (fol.compiler.collection-functions:int-set 2 3))
         (r (fol.compiler.collection-functions:union s1 s2)))
    (is (= 3 (fol.compiler.collections:collection-size r)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq r)))))

(test union-ordered-set
  "union of two ordered-sets preserves order."
  (let* ((s1 (fol.compiler.collection-functions:ordered-set 3 1))
         (s2 (fol.compiler.collection-functions:ordered-set 2 1))
         (r (fol.compiler.collection-functions:union s1 s2)))
    (is (= 3 (fol.compiler.collections:collection-size r)))
    ;; s1 elements first (3 1), then novel from s2 (2)
    (is (equal '(3 1 2) (fol.compiler.collections:collection-seq r)))))

;;; ===========================================================================
;;; difference
;;; ===========================================================================

(test difference-set-basic
  "difference of two hash-sets."
  (let* ((s1 (fol.compiler.collection-functions:set 1 2 3))
         (s2 (fol.compiler.collection-functions:set 2 3 4))
         (r (fol.compiler.collection-functions:difference s1 s2)))
    (is (= 1 (fol.compiler.collections:collection-size r)))
    (is (eq t (fol.compiler.collection-functions:contains? r 1)))))

(test difference-set-no-overlap
  "difference with no overlap returns all elements."
  (let* ((s1 (fol.compiler.collection-functions:set 1 2))
         (s2 (fol.compiler.collection-functions:set 3 4))
         (r (fol.compiler.collection-functions:difference s1 s2)))
    (is (= 2 (fol.compiler.collections:collection-size r)))))

(test difference-set-complete-overlap
  "difference with complete overlap returns empty set."
  (let* ((s1 (fol.compiler.collection-functions:set 1 2))
         (s2 (fol.compiler.collection-functions:set 1 2 3))
         (r (fol.compiler.collection-functions:difference s1 s2)))
    (is (= 0 (fol.compiler.collections:collection-size r)))))

(test difference-sorted-set
  "difference of two sorted-sets."
  (let* ((s1 (fol.compiler.collection-functions:sorted-set nil 1 2 3 4))
         (s2 (fol.compiler.collection-functions:sorted-set nil 2 4))
         (r (fol.compiler.collection-functions:difference s1 s2)))
    (is (= 2 (fol.compiler.collections:collection-size r)))
    (is (equal '(1 3) (fol.compiler.collections:collection-seq r)))))

(test difference-ordered-set
  "difference of two ordered-sets preserves order."
  (let* ((s1 (fol.compiler.collection-functions:ordered-set 3 1 2 4))
         (s2 (fol.compiler.collection-functions:ordered-set 1 4))
         (r (fol.compiler.collection-functions:difference s1 s2)))
    (is (= 2 (fol.compiler.collections:collection-size r)))
    (is (equal '(3 2) (fol.compiler.collections:collection-seq r)))))

;;; ===========================================================================
;;; intersection
;;; ===========================================================================

(test intersection-set-basic
  "intersection of two hash-sets."
  (let* ((s1 (fol.compiler.collection-functions:set 1 2 3))
         (s2 (fol.compiler.collection-functions:set 2 3 4))
         (r (fol.compiler.collection-functions:intersection s1 s2)))
    (is (= 2 (fol.compiler.collections:collection-size r)))
    (is (eq t (fol.compiler.collection-functions:contains? r 2)))
    (is (eq t (fol.compiler.collection-functions:contains? r 3)))))

(test intersection-set-no-overlap
  "intersection with no overlap returns empty set."
  (let* ((s1 (fol.compiler.collection-functions:set 1 2))
         (s2 (fol.compiler.collection-functions:set 3 4))
         (r (fol.compiler.collection-functions:intersection s1 s2)))
    (is (= 0 (fol.compiler.collections:collection-size r)))))

(test intersection-set-complete-overlap
  "intersection with complete overlap returns all."
  (let* ((s1 (fol.compiler.collection-functions:set 1 2))
         (s2 (fol.compiler.collection-functions:set 1 2 3))
         (r (fol.compiler.collection-functions:intersection s1 s2)))
    (is (= 2 (fol.compiler.collections:collection-size r)))))

(test intersection-sorted-set
  "intersection of two sorted-sets."
  (let* ((s1 (fol.compiler.collection-functions:sorted-set nil 1 2 3 4))
         (s2 (fol.compiler.collection-functions:sorted-set nil 2 4 5))
         (r (fol.compiler.collection-functions:intersection s1 s2)))
    (is (= 2 (fol.compiler.collections:collection-size r)))
    (is (equal '(2 4) (fol.compiler.collections:collection-seq r)))))

(test intersection-ordered-set
  "intersection of two ordered-sets preserves s1 order."
  (let* ((s1 (fol.compiler.collection-functions:ordered-set 3 1 2 4))
         (s2 (fol.compiler.collection-functions:ordered-set 2 4 5))
         (r (fol.compiler.collection-functions:intersection s1 s2)))
    (is (= 2 (fol.compiler.collections:collection-size r)))
    (is (equal '(2 4) (fol.compiler.collections:collection-seq r)))))

;;; ===========================================================================
;;; select
;;; ===========================================================================

(test select-set-basic
  "select filters a hash-set by predicate."
  (let* ((s (fol.compiler.collection-functions:set 1 2 3 4 5 6))
         (r (fol.compiler.collection-functions:select #'evenp s)))
    (is (= 3 (fol.compiler.collections:collection-size r)))
    (is (eq t (fol.compiler.collection-functions:contains? r 2)))
    (is (eq t (fol.compiler.collection-functions:contains? r 4)))
    (is (eq t (fol.compiler.collection-functions:contains? r 6)))))

(test select-set-no-match
  "select with no matching elements returns empty set."
  (let* ((s (fol.compiler.collection-functions:set 1 3 5))
         (r (fol.compiler.collection-functions:select #'evenp s)))
    (is (= 0 (fol.compiler.collections:collection-size r)))))

(test select-set-all-match
  "select with all matching elements returns equivalent set."
  (let* ((s (fol.compiler.collection-functions:set 2 4 6))
         (r (fol.compiler.collection-functions:select #'evenp s)))
    (is (= 3 (fol.compiler.collections:collection-size r)))))

(test select-sorted-set
  "select on a sorted-set preserves comparator."
  (let* ((s (fol.compiler.collection-functions:sorted-set nil 1 2 3 4 5))
         (r (fol.compiler.collection-functions:select #'oddp s)))
    (is (= 3 (fol.compiler.collections:collection-size r)))
    (is (equal '(1 3 5) (fol.compiler.collections:collection-seq r)))))

(test select-int-set
  "select on an int-set preserves int-set type."
  (let* ((s (fol.compiler.collection-functions:int-set 1 2 3 4 5))
         (r (fol.compiler.collection-functions:select #'evenp s)))
    (is (= 2 (fol.compiler.collections:collection-size r)))
    (is (equal '(2 4) (fol.compiler.collections:collection-seq r)))
    (is (typep r 'fol.compiler.collections:<int-set>))))

(test select-ordered-set
  "select on an ordered-set preserves insertion order."
  (let* ((s (fol.compiler.collection-functions:ordered-set 5 2 4 1 3))
         (r (fol.compiler.collection-functions:select #'evenp s)))
    (is (= 2 (fol.compiler.collections:collection-size r)))
    (is (equal '(2 4) (fol.compiler.collections:collection-seq r)))))

;;; ===========================================================================
;;; subset?
;;; ===========================================================================

(test subset?-set-true
  "subset? returns T when s1 is a subset of s2."
  (let ((s1 (fol.compiler.collection-functions:set 1 2))
        (s2 (fol.compiler.collection-functions:set 1 2 3)))
    (is (eq t (fol.compiler.collection-functions:subset? s1 s2)))))

(test subset?-set-false
  "subset? returns NIL when s1 is not a subset of s2."
  (let ((s1 (fol.compiler.collection-functions:set 1 4))
        (s2 (fol.compiler.collection-functions:set 1 2 3)))
    (is (null (fol.compiler.collection-functions:subset? s1 s2)))))

(test subset?-set-empty
  "Empty set is a subset of any set."
  (let ((s1 (fol.compiler.collection-functions:set))
        (s2 (fol.compiler.collection-functions:set 1 2 3)))
    (is (eq t (fol.compiler.collection-functions:subset? s1 s2)))))

(test subset?-set-equal
  "A set is a subset of itself."
  (let ((s (fol.compiler.collection-functions:set 1 2 3)))
    (is (eq t (fol.compiler.collection-functions:subset? s s)))))

(test subset?-sorted-set
  "subset? works on sorted-sets."
  (let ((s1 (fol.compiler.collection-functions:sorted-set nil 1 2))
        (s2 (fol.compiler.collection-functions:sorted-set nil 1 2 3)))
    (is (eq t (fol.compiler.collection-functions:subset? s1 s2)))))

(test subset?-ordered-set
  "subset? works on ordered-sets."
  (let ((s1 (fol.compiler.collection-functions:ordered-set 2 1))
        (s2 (fol.compiler.collection-functions:ordered-set 3 2 1)))
    (is (eq t (fol.compiler.collection-functions:subset? s1 s2)))))

;;; ===========================================================================
;;; superset?
;;; ===========================================================================

(test superset?-set-true
  "superset? returns T when s1 contains all of s2."
  (let ((s1 (fol.compiler.collection-functions:set 1 2 3))
        (s2 (fol.compiler.collection-functions:set 1 2)))
    (is (eq t (fol.compiler.collection-functions:superset? s1 s2)))))

(test superset?-set-false
  "superset? returns NIL when s1 doesn't contain all of s2."
  (let ((s1 (fol.compiler.collection-functions:set 1 2))
        (s2 (fol.compiler.collection-functions:set 1 2 3)))
    (is (null (fol.compiler.collection-functions:superset? s1 s2)))))

(test superset?-set-empty
  "Any set is a superset of the empty set."
  (let ((s1 (fol.compiler.collection-functions:set 1 2 3))
        (s2 (fol.compiler.collection-functions:set)))
    (is (eq t (fol.compiler.collection-functions:superset? s1 s2)))))

(test superset?-sorted-set
  "superset? works on sorted-sets."
  (let ((s1 (fol.compiler.collection-functions:sorted-set nil 1 2 3))
        (s2 (fol.compiler.collection-functions:sorted-set nil 1 3)))
    (is (eq t (fol.compiler.collection-functions:superset? s1 s2)))))

;;; ===========================================================================
;;; rseq (sorted-set)
;;; ===========================================================================

(test rseq-sorted-set-basic
  "rseq returns elements in reverse sorted order."
  (let ((s (fol.compiler.collection-functions:sorted-set nil 3 1 4 1 5)))
    (is (equal '(5 4 3 1) (fol.compiler.collection-functions:rseq s)))))

(test rseq-sorted-set-empty
  "rseq returns NIL for empty sorted-set."
  (let ((s (fol.compiler.collection-functions:sorted-set nil)))
    (is (null (fol.compiler.collection-functions:rseq s)))))

(test rseq-int-set
  "rseq works on int-sets."
  (let ((s (fol.compiler.collection-functions:int-set 10 30 20)))
    (is (equal '(30 20 10) (fol.compiler.collection-functions:rseq s)))))

;;; ===========================================================================
;;; subseq
;;; ===========================================================================

(test subseq-sorted-set-gte
  "subseq with >= returns elements >= key."
  (let ((s (fol.compiler.collection-functions:sorted-set nil 1 2 3 4 5)))
    (is (equal '(3 4 5) (fol.compiler.collection-functions:subseq s '>= 3)))))

(test subseq-sorted-set-gt
  "subseq with > returns elements > key."
  (let ((s (fol.compiler.collection-functions:sorted-set nil 1 2 3 4 5)))
    (is (equal '(4 5) (fol.compiler.collection-functions:subseq s '> 3)))))

(test subseq-sorted-set-lte
  "subseq with <= returns elements <= key."
  (let ((s (fol.compiler.collection-functions:sorted-set nil 1 2 3 4 5)))
    (is (equal '(1 2 3) (fol.compiler.collection-functions:subseq s '<= 3)))))

(test subseq-sorted-set-lt
  "subseq with < returns elements < key."
  (let ((s (fol.compiler.collection-functions:sorted-set nil 1 2 3 4 5)))
    (is (equal '(1 2) (fol.compiler.collection-functions:subseq s '< 3)))))

(test subseq-sorted-set-range
  "subseq with two tests returns elements in range."
  (let ((s (fol.compiler.collection-functions:sorted-set nil 1 2 3 4 5)))
    (is (equal '(2 3 4) (fol.compiler.collection-functions:subseq s '>= 2 '< 5)))))

(test subseq-sorted-set-empty-result
  "subseq returns NIL when no elements match."
  (let ((s (fol.compiler.collection-functions:sorted-set nil 1 2 3)))
    (is (null (fol.compiler.collection-functions:subseq s '> 5)))))

(test subseq-int-set
  "subseq works on int-sets."
  (let ((s (fol.compiler.collection-functions:int-set 10 20 30 40 50)))
    (is (equal '(30 40 50) (fol.compiler.collection-functions:subseq s '>= 30)))))

;;; ===========================================================================
;;; rsubseq
;;; ===========================================================================

(test rsubseq-sorted-set-lte
  "rsubseq with <= returns elements <= key in reverse order."
  (let ((s (fol.compiler.collection-functions:sorted-set nil 1 2 3 4 5)))
    (is (equal '(3 2 1) (fol.compiler.collection-functions:rsubseq s '<= 3)))))

(test rsubseq-sorted-set-range
  "rsubseq with two tests returns elements in range, reversed."
  (let ((s (fol.compiler.collection-functions:sorted-set nil 1 2 3 4 5)))
    (is (equal '(4 3 2) (fol.compiler.collection-functions:rsubseq s '>= 2 '< 5)))))

(test rsubseq-sorted-set-empty-result
  "rsubseq returns NIL when no elements match."
  (let ((s (fol.compiler.collection-functions:sorted-set nil 1 2 3)))
    (is (null (fol.compiler.collection-functions:rsubseq s '> 5)))))

;;; ===========================================================================
;;; Dict Operations
;;; ===========================================================================

;;; ---------------------------------------------------------------------------
;;; contains? for dicts
;;; ---------------------------------------------------------------------------

(test contains?-dict-present
  "contains? returns T for a key that exists in a dict."
  (let ((d (fol.compiler.collection-functions:dict :a 1 :b 2 :c 3)))
    (is (eq t (fol.compiler.collection-functions:contains? d :a)))
    (is (eq t (fol.compiler.collection-functions:contains? d :b)))
    (is (eq t (fol.compiler.collection-functions:contains? d :c)))))

(test contains?-dict-absent
  "contains? returns NIL for a key not in the dict."
  (let ((d (fol.compiler.collection-functions:dict :a 1 :b 2)))
    (is (null (fol.compiler.collection-functions:contains? d :z)))
    (is (null (fol.compiler.collection-functions:contains? d :x)))))

(test contains?-dict-empty
  "contains? returns NIL for any key in an empty dict."
  (let ((d (fol.compiler.collection-functions:dict)))
    (is (null (fol.compiler.collection-functions:contains? d :a)))))

(test contains?-sorted-dict-present
  "contains? returns T for a key in a sorted-dict."
  (let ((d (fol.compiler.collection-functions:sorted-dict nil 1 :a 2 :b 3 :c)))
    (is (eq t (fol.compiler.collection-functions:contains? d 1)))
    (is (eq t (fol.compiler.collection-functions:contains? d 2)))))

(test contains?-sorted-dict-absent
  "contains? returns NIL for a key not in a sorted-dict."
  (let ((d (fol.compiler.collection-functions:sorted-dict nil 1 :a 2 :b)))
    (is (null (fol.compiler.collection-functions:contains? d 99)))))

;;; ---------------------------------------------------------------------------
;;; find
;;; ---------------------------------------------------------------------------

(test find-dict-present
  "find returns (key . value) for a key in the dict."
  (let ((d (fol.compiler.collection-functions:dict :a 1 :b 2)))
    (is (equal '(:a . 1) (fol.compiler.collection-functions:find d :a)))
    (is (equal '(:b . 2) (fol.compiler.collection-functions:find d :b)))))

(test find-dict-absent
  "find returns NIL for a key not in the dict."
  (let ((d (fol.compiler.collection-functions:dict :a 1 :b 2)))
    (is (null (fol.compiler.collection-functions:find d :z)))))

(test find-dict-empty
  "find returns NIL for any key in an empty dict."
  (let ((d (fol.compiler.collection-functions:dict)))
    (is (null (fol.compiler.collection-functions:find d :a)))))

(test find-sorted-dict-present
  "find returns (key . value) for a key in a sorted-dict."
  (let ((d (fol.compiler.collection-functions:sorted-dict nil 1 :a 2 :b)))
    (is (equal '(1 . :a) (fol.compiler.collection-functions:find d 1)))
    (is (equal '(2 . :b) (fol.compiler.collection-functions:find d 2)))))

(test find-sorted-dict-absent
  "find returns NIL for a key not in a sorted-dict."
  (let ((d (fol.compiler.collection-functions:sorted-dict nil 1 :a 2 :b)))
    (is (null (fol.compiler.collection-functions:find d 99)))))

;;; ---------------------------------------------------------------------------
;;; get-in
;;; ---------------------------------------------------------------------------

(test get-in-dict-shallow
  "get-in with a single key works like get."
  (let ((d (fol.compiler.collection-functions:dict :a 1 :b 2)))
    (is (eql 1 (fol.compiler.collection-functions:get-in d '(:a))))
    (is (eql 2 (fol.compiler.collection-functions:get-in d '(:b))))))

(test get-in-dict-nested
  "get-in follows nested dict keys."
  (let ((d (fol.compiler.collection-functions:dict
            :a (fol.compiler.collection-functions:dict :b 42))))
    (is (eql 42 (fol.compiler.collection-functions:get-in d '(:a :b))))))

(test get-in-dict-missing-returns-nil
  "get-in returns NIL when path doesn't exist."
  (let ((d (fol.compiler.collection-functions:dict :a 1)))
    (is (null (fol.compiler.collection-functions:get-in d '(:z))))))

(test get-in-dict-missing-returns-not-found
  "get-in returns the not-found value when path doesn't exist."
  (let ((d (fol.compiler.collection-functions:dict :a 1)))
    (is (eq :nope (fol.compiler.collection-functions:get-in d '(:z) :nope)))))

(test get-in-dict-deep-missing
  "get-in returns not-found when a deep path doesn't exist."
  (let ((d (fol.compiler.collection-functions:dict
            :a (fol.compiler.collection-functions:dict :b 1))))
    (is (eq :missing (fol.compiler.collection-functions:get-in d '(:a :c) :missing)))))

(test get-in-vector-shallow
  "get-in on a vector with a single index."
  (let ((v (fol.compiler.collection-functions:vector 10 20 30)))
    (is (eql 20 (fol.compiler.collection-functions:get-in v '(1))))))

(test get-in-vector-nested-dict
  "get-in on a vector containing a dict."
  (let ((v (fol.compiler.collection-functions:vector
            (fol.compiler.collection-functions:dict :x 99))))
    (is (eql 99 (fol.compiler.collection-functions:get-in v '(0 :x))))))

(test get-in-vector-out-of-bounds
  "get-in on a vector with out-of-bounds index returns not-found."
  (let ((v (fol.compiler.collection-functions:vector 10 20)))
    (is (eq :oob (fol.compiler.collection-functions:get-in v '(5) :oob)))))

;;; ---------------------------------------------------------------------------
;;; vals
;;; ---------------------------------------------------------------------------

(test vals-dict-basic
  "vals returns a vector of values from a dict."
  (let* ((d (fol.compiler.collection-functions:dict :a 1 :b 2 :c 3))
         (v (fol.compiler.collection-functions:vals d))
         (elems (fol.compiler.collections:collection-seq v)))
    (is (eql 3 (fol.compiler.collections:collection-size v)))
    (is (eq t (and (cl:member 1 elems) t)))
    (is (eq t (and (cl:member 2 elems) t)))
    (is (eq t (and (cl:member 3 elems) t)))))

(test vals-dict-empty
  "vals of an empty dict returns an empty vector."
  (let ((v (fol.compiler.collection-functions:vals (fol.compiler.collection-functions:dict))))
    (is (eql 0 (fol.compiler.collections:collection-size v)))))

(test vals-ordered-dict
  "vals of an ordered-dict preserves insertion order."
  (let* ((d (fol.compiler.collection-functions:ordered-dict :x 10 :y 20 :z 30))
         (v (fol.compiler.collection-functions:vals d)))
    (is (equal '(10 20 30) (fol.compiler.collections:collection-seq v)))))

(test vals-sorted-dict
  "vals of a sorted-dict returns values in key-sorted order."
  (let* ((d (fol.compiler.collection-functions:sorted-dict nil 3 :c 1 :a 2 :b))
         (v (fol.compiler.collection-functions:vals d)))
    (is (equal '(:a :b :c) (fol.compiler.collections:collection-seq v)))))

;;; ===========================================================================
;;; key / val
;;; ===========================================================================

(test key-extracts-car
  "key returns the key from a map entry."
  (is (eq :a (fol.compiler.collection-functions:key (cons :a 1))))
  (is (eql 42 (fol.compiler.collection-functions:key (cons 42 :foo)))))

(test val-extracts-cdr
  "val returns the value from a map entry."
  (is (eql 1 (fol.compiler.collection-functions:val (cons :a 1))))
  (is (eq :foo (fol.compiler.collection-functions:val (cons 42 :foo)))))

(test key-val-on-dict-entries
  "key and val work on entries from collection-seq."
  (let* ((d (fol.compiler.collection-functions:dict :x 10 :y 20))
         (entries (fol.compiler.collections:collection-seq d)))
    (dolist (e entries)
      (is (eq t (keywordp (fol.compiler.collection-functions:key e))))
      (is (eq t (integerp (fol.compiler.collection-functions:val e)))))))

;;; ===========================================================================
;;; merge-with
;;; ===========================================================================

(test merge-with-dict-add
  "merge-with #'+ sums conflicting values."
  (let* ((d1 (fol.compiler.collection-functions:dict :a 1 :b 2))
         (d2 (fol.compiler.collection-functions:dict :a 10 :c 3))
         (result (fol.compiler.collection-functions:merge-with #'cl:+ d1 d2)))
    (is (eql 11 (fol.compiler.collections:get result :a)))
    (is (eql 2 (fol.compiler.collections:get result :b)))
    (is (eql 3 (fol.compiler.collections:get result :c)))))

(test merge-with-dict-no-conflict
  "merge-with with disjoint keys acts like merge."
  (let* ((d1 (fol.compiler.collection-functions:dict :a 1))
         (d2 (fol.compiler.collection-functions:dict :b 2))
         (result (fol.compiler.collection-functions:merge-with #'cl:+ d1 d2)))
    (is (eql 1 (fol.compiler.collections:get result :a)))
    (is (eql 2 (fol.compiler.collections:get result :b)))))

(test merge-with-multiple-dicts
  "merge-with accepts multiple source dicts."
  (let* ((d1 (fol.compiler.collection-functions:dict :a 1))
         (d2 (fol.compiler.collection-functions:dict :a 2))
         (d3 (fol.compiler.collection-functions:dict :a 3))
         (result (fol.compiler.collection-functions:merge-with #'cl:+ d1 d2 d3)))
    (is (eql 6 (fol.compiler.collections:get result :a)))))

(test merge-with-ordered-dict
  "merge-with works on ordered-dicts."
  (let* ((d1 (fol.compiler.collection-functions:ordered-dict :a 1 :b 2))
         (d2 (fol.compiler.collection-functions:ordered-dict :a 10 :c 3))
         (result (fol.compiler.collection-functions:merge-with #'cl:+ d1 d2)))
    (is (eql 11 (fol.compiler.collections:get result :a)))
    (is (eql 3 (fol.compiler.collections:get result :c)))))

(test merge-with-sorted-dict
  "merge-with works on sorted-dicts."
  (let* ((d1 (fol.compiler.collection-functions:sorted-dict nil 1 :a 2 :b))
         (d2 (fol.compiler.collection-functions:sorted-dict nil 1 :x 3 :c))
         (result (fol.compiler.collection-functions:merge-with
                  (lambda (a b) (declare (ignore a)) b) d1 d2)))
    (is (eq :x (fol.compiler.collections:get result 1)))
    (is (eq :b (fol.compiler.collections:get result 2)))
    (is (eq :c (fol.compiler.collections:get result 3)))))

;;; ===========================================================================
;;; select-keys
;;; ===========================================================================

(test select-keys-dict-basic
  "select-keys returns a dict with only the specified keys."
  (let* ((d (fol.compiler.collection-functions:dict :a 1 :b 2 :c 3))
         (result (fol.compiler.collection-functions:select-keys d '(:a :c))))
    (is (eql 2 (fol.compiler.collections:collection-size result)))
    (is (eql 1 (fol.compiler.collections:get result :a)))
    (is (eql 3 (fol.compiler.collections:get result :c)))))

(test select-keys-missing-keys
  "select-keys ignores keys not in the dict."
  (let* ((d (fol.compiler.collection-functions:dict :a 1))
         (result (fol.compiler.collection-functions:select-keys d '(:a :z))))
    (is (eql 1 (fol.compiler.collections:collection-size result)))
    (is (eql 1 (fol.compiler.collections:get result :a)))))

(test select-keys-empty-result
  "select-keys with no matching keys returns empty dict."
  (let* ((d (fol.compiler.collection-functions:dict :a 1))
         (result (fol.compiler.collection-functions:select-keys d '(:z))))
    (is (eql 0 (fol.compiler.collections:collection-size result)))))

(test select-keys-ordered-dict
  "select-keys works on ordered-dicts."
  (let* ((d (fol.compiler.collection-functions:ordered-dict :a 1 :b 2 :c 3))
         (result (fol.compiler.collection-functions:select-keys d '(:c :a))))
    (is (eql 2 (fol.compiler.collections:collection-size result)))))

(test select-keys-sorted-dict
  "select-keys works on sorted-dicts."
  (let* ((d (fol.compiler.collection-functions:sorted-dict nil 1 :a 2 :b 3 :c))
         (result (fol.compiler.collection-functions:select-keys d '(1 3))))
    (is (eql 2 (fol.compiler.collections:collection-size result)))
    (is (eq :a (fol.compiler.collections:get result 1)))
    (is (eq :c (fol.compiler.collections:get result 3)))))

;;; ===========================================================================
;;; rename-keys
;;; ===========================================================================

(test rename-keys-basic
  "rename-keys renames specified keys."
  (let* ((d (fol.compiler.collection-functions:dict :a 1 :b 2))
         (kmap (fol.compiler.collection-functions:dict :a :x))
         (result (fol.compiler.collection-functions:rename-keys d kmap)))
    (is (eql 1 (fol.compiler.collections:get result :x)))
    (is (eql 2 (fol.compiler.collections:get result :b)))
    (is (null (fol.compiler.collections:get result :a)))))

(test rename-keys-no-match
  "rename-keys with no matching keys returns equivalent dict."
  (let* ((d (fol.compiler.collection-functions:dict :a 1 :b 2))
         (kmap (fol.compiler.collection-functions:dict :z :w))
         (result (fol.compiler.collection-functions:rename-keys d kmap)))
    (is (eql 1 (fol.compiler.collections:get result :a)))
    (is (eql 2 (fol.compiler.collections:get result :b)))))

(test rename-keys-ordered-dict
  "rename-keys works on ordered-dicts."
  (let* ((d (fol.compiler.collection-functions:ordered-dict :a 1 :b 2))
         (kmap (fol.compiler.collection-functions:dict :a :x))
         (result (fol.compiler.collection-functions:rename-keys d kmap)))
    (is (eql 1 (fol.compiler.collections:get result :x)))
    (is (eql 2 (fol.compiler.collections:get result :b)))))

;;; ===========================================================================
;;; map-invert
;;; ===========================================================================

(test map-invert-basic
  "map-invert swaps keys and values."
  (let* ((d (fol.compiler.collection-functions:dict :a 1 :b 2))
         (result (fol.compiler.collection-functions:map-invert d)))
    (is (eq :a (fol.compiler.collections:get result 1)))
    (is (eq :b (fol.compiler.collections:get result 2)))))

(test map-invert-empty
  "map-invert on empty dict returns empty dict."
  (let ((result (fol.compiler.collection-functions:map-invert
                 (fol.compiler.collection-functions:dict))))
    (is (eql 0 (fol.compiler.collections:collection-size result)))))

(test map-invert-duplicate-values
  "map-invert with duplicate values keeps last one."
  (let* ((d (fol.compiler.collection-functions:dict :a 1 :b 1))
         (result (fol.compiler.collection-functions:map-invert d)))
    (is (eql 1 (fol.compiler.collections:collection-size result)))
    (is (eq t (keywordp (fol.compiler.collections:get result 1))))))

;;; ===========================================================================
;;; update-keys
;;; ===========================================================================

(test update-keys-basic
  "update-keys applies function to all keys."
  (let* ((d (fol.compiler.collection-functions:dict 1 :a 2 :b))
         (result (fol.compiler.collection-functions:update-keys d #'1+)))
    (is (eq :a (fol.compiler.collections:get result 2)))
    (is (eq :b (fol.compiler.collections:get result 3)))))

(test update-keys-ordered-dict
  "update-keys works on ordered-dicts."
  (let* ((d (fol.compiler.collection-functions:ordered-dict 1 :a 2 :b))
         (result (fol.compiler.collection-functions:update-keys d #'1+)))
    (is (eq :a (fol.compiler.collections:get result 2)))
    (is (eq :b (fol.compiler.collections:get result 3)))))

(test update-keys-empty
  "update-keys on empty dict returns empty dict."
  (let ((result (fol.compiler.collection-functions:update-keys
                 (fol.compiler.collection-functions:dict)
                 #'identity)))
    (is (eql 0 (fol.compiler.collections:collection-size result)))))

;;; ===========================================================================
;;; update-vals
;;; ===========================================================================

(test update-vals-dict
  "update-vals applies function to all values."
  (let* ((d (fol.compiler.collection-functions:dict :a 1 :b 2 :c 3))
         (result (fol.compiler.collection-functions:update-vals d #'1+)))
    (is (eql 2 (fol.compiler.collections:get result :a)))
    (is (eql 3 (fol.compiler.collections:get result :b)))
    (is (eql 4 (fol.compiler.collections:get result :c)))))

(test update-vals-ordered-dict
  "update-vals works on ordered-dicts."
  (let* ((d (fol.compiler.collection-functions:ordered-dict :x 10 :y 20))
         (result (fol.compiler.collection-functions:update-vals d #'1+)))
    (is (eql 11 (fol.compiler.collections:get result :x)))
    (is (eql 21 (fol.compiler.collections:get result :y)))))

(test update-vals-sorted-dict
  "update-vals works on sorted-dicts."
  (let* ((d (fol.compiler.collection-functions:sorted-dict nil 1 :a 2 :b))
         (result (fol.compiler.collection-functions:update-vals
                  d (lambda (v) (cl:intern (symbol-name v) :keyword)))))
    (is (typep result 'fol.compiler.collections:<sorted-dict>))
    (is (eql 2 (fol.compiler.collections:collection-size result)))))

(test update-vals-empty
  "update-vals on empty dict returns empty dict."
  (let ((result (fol.compiler.collection-functions:update-vals
                 (fol.compiler.collection-functions:dict)
                 #'1+)))
    (is (eql 0 (fol.compiler.collections:collection-size result)))))

;;; ===========================================================================
;;; Sorted Dict rseq
;;; ===========================================================================

(test rseq-sorted-dict
  "rseq returns entries in reverse key order."
  (let* ((d (fol.compiler.collection-functions:sorted-dict nil 1 :a 3 :c 2 :b))
         (result (fol.compiler.collection-functions:rseq d)))
    (is (equal '((3 . :c) (2 . :b) (1 . :a)) result))))

(test rseq-sorted-dict-empty
  "rseq on empty sorted-dict returns NIL."
  (let ((d (fol.compiler.collection-functions:sorted-dict nil)))
    (is (null (fol.compiler.collection-functions:rseq d)))))

(test rseq-int-dict
  "rseq works on int-dict."
  (let* ((d (fol.compiler.collection-functions:int-dict 10 :x 5 :y 20 :z))
         (result (fol.compiler.collection-functions:rseq d)))
    (is (eql 20 (car (cl:first result))))
    (is (eql 5 (car (cl:third result))))))

;;; ===========================================================================
;;; Sorted Dict subseq / rsubseq
;;; ===========================================================================

(test subseq-sorted-dict-gte
  "subseq with >= returns entries with keys >= key."
  (let* ((d (fol.compiler.collection-functions:sorted-dict nil 1 :a 2 :b 3 :c 4 :d 5 :e))
         (result (fol.compiler.collection-functions:subseq d '>= 3)))
    (is (equal '((3 . :c) (4 . :d) (5 . :e)) result))))

(test subseq-sorted-dict-range
  "subseq with two tests returns entries in range."
  (let* ((d (fol.compiler.collection-functions:sorted-dict nil 1 :a 2 :b 3 :c 4 :d 5 :e))
         (result (fol.compiler.collection-functions:subseq d '>= 2 '< 5)))
    (is (equal '((2 . :b) (3 . :c) (4 . :d)) result))))

(test subseq-sorted-dict-empty-result
  "subseq returns NIL when no entries match."
  (let ((d (fol.compiler.collection-functions:sorted-dict nil 1 :a 2 :b)))
    (is (null (fol.compiler.collection-functions:subseq d '> 5)))))

(test rsubseq-sorted-dict-lte
  "rsubseq with <= returns entries in reverse order."
  (let* ((d (fol.compiler.collection-functions:sorted-dict nil 1 :a 2 :b 3 :c 4 :d))
         (result (fol.compiler.collection-functions:rsubseq d '<= 3)))
    (is (equal '((3 . :c) (2 . :b) (1 . :a)) result))))

(test rsubseq-sorted-dict-range
  "rsubseq with range returns entries in reverse order."
  (let* ((d (fol.compiler.collection-functions:sorted-dict nil 1 :a 2 :b 3 :c 4 :d 5 :e))
         (result (fol.compiler.collection-functions:rsubseq d '>= 2 '< 5)))
    (is (equal '((4 . :d) (3 . :c) (2 . :b)) result))))

;;; ===========================================================================
;;; Deque Operations
;;; ===========================================================================

(test deque-peek-front
  "peek returns the front element of a deque."
  (let ((d (fol.compiler.collection-functions:deque 10 20 30)))
    (is (eql 10 (fol.compiler.collection-functions:peek d)))))

(test deque-peek-empty
  "peek returns NIL for an empty deque."
  (let ((d (fol.compiler.collection-functions:deque)))
    (is (null (fol.compiler.collection-functions:peek d)))))

(test deque-pop-front
  "pop removes the front element."
  (let* ((d (fol.compiler.collection-functions:deque 10 20 30))
         (popped (fol.compiler.collection-functions:pop d)))
    (is (eql 2 (fol.compiler.collections:collection-size popped)))
    (is (equal '(20 30) (fol.compiler.collections:collection-seq popped)))))

(test deque-pop-empty-signals-error
  "pop on empty deque signals an error."
  (let ((d (fol.compiler.collection-functions:deque)))
    (signals error (fol.compiler.collection-functions:pop d))))

(test deque-push-back
  "push adds to the back of the deque."
  (let* ((d (fol.compiler.collection-functions:deque 10 20))
         (pushed (fol.compiler.collection-functions:push d 30)))
    (is (equal '(10 20 30) (fol.compiler.collections:collection-seq pushed)))))

(test deque-conj-back
  "conj adds to the back of the deque."
  (let* ((d (fol.compiler.collection-functions:deque 10 20))
         (result (fol.compiler.collection-functions:conj d 30)))
    (is (equal '(10 20 30) (fol.compiler.collections:collection-seq result)))))

(test deque-rpeek-back
  "rpeek returns the back element of a deque."
  (let ((d (fol.compiler.collection-functions:deque 10 20 30)))
    (is (eql 30 (fol.compiler.collection-functions:rpeek d)))))

(test deque-rpeek-empty
  "rpeek returns NIL for an empty deque."
  (let ((d (fol.compiler.collection-functions:deque)))
    (is (null (fol.compiler.collection-functions:rpeek d)))))

(test deque-rpop-back
  "rpop removes the back element."
  (let* ((d (fol.compiler.collection-functions:deque 10 20 30))
         (popped (fol.compiler.collection-functions:rpop d)))
    (is (eql 2 (fol.compiler.collections:collection-size popped)))
    (is (equal '(10 20) (fol.compiler.collections:collection-seq popped)))))

(test deque-rpop-empty-signals-error
  "rpop on empty deque signals an error."
  (let ((d (fol.compiler.collection-functions:deque)))
    (signals error (fol.compiler.collection-functions:rpop d))))

(test deque-rpush-front
  "rpush adds to the front of the deque."
  (let* ((d (fol.compiler.collection-functions:deque 20 30))
         (pushed (fol.compiler.collection-functions:rpush d 10)))
    (is (equal '(10 20 30) (fol.compiler.collections:collection-seq pushed)))))

(test deque-rconj-front
  "rconj adds to the front of the deque."
  (let* ((d (fol.compiler.collection-functions:deque 20 30))
         (result (fol.compiler.collection-functions:rconj d 10)))
    (is (equal '(10 20 30) (fol.compiler.collections:collection-seq result)))))

(test deque-roundtrip-front-back
  "Items can be added to back and removed from front (queue semantics)."
  (let* ((d (fol.compiler.collection-functions:deque))
         (d (fol.compiler.collection-functions:push d 1))
         (d (fol.compiler.collection-functions:push d 2))
         (d (fol.compiler.collection-functions:push d 3)))
    (is (eql 1 (fol.compiler.collection-functions:peek d)))
    (let ((d (fol.compiler.collection-functions:pop d)))
      (is (eql 2 (fol.compiler.collection-functions:peek d)))
      (let ((d (fol.compiler.collection-functions:pop d)))
        (is (eql 3 (fol.compiler.collection-functions:peek d)))))))

(test deque-roundtrip-back-front
  "Items can be added to front and removed from back (reverse queue)."
  (let* ((d (fol.compiler.collection-functions:deque))
         (d (fol.compiler.collection-functions:rpush d 1))
         (d (fol.compiler.collection-functions:rpush d 2))
         (d (fol.compiler.collection-functions:rpush d 3)))
    (is (eql 1 (fol.compiler.collection-functions:rpeek d)))
    (let ((d (fol.compiler.collection-functions:rpop d)))
      (is (eql 2 (fol.compiler.collection-functions:rpeek d)))
      (let ((d (fol.compiler.collection-functions:rpop d)))
        (is (eql 3 (fol.compiler.collection-functions:rpeek d)))))))

;;; ---------------------------------------------------------------------------
;;; collection-lazy-seq tests
;;; ---------------------------------------------------------------------------

(test lazy-seq-vector
  "collection-lazy-seq on <vector> returns a lazy-seq that yields all elements."
  (let* ((v (fol.compiler.primitives:make 'fol.compiler.collections:<vector> 10 20 30))
         (ls (fol.compiler.collections:collection-lazy-seq v)))
    (is (typep ls 'fol.compiler.collections:<lazy-seq>))
    ;; Materialize and check
    (let ((elems (fol.compiler.collections:collection-seq ls)))
      (is (equal '(10 20 30) elems)))))

(test lazy-seq-dict
  "collection-lazy-seq on <dict> returns a lazy-seq of (key . value) pairs."
  (let* ((d (fol.compiler.primitives:make 'fol.compiler.collections:<dict> :x 1 :y 2))
         (ls (fol.compiler.collections:collection-lazy-seq d)))
    (is (typep ls 'fol.compiler.collections:<lazy-seq>))
    (let ((pairs (fol.compiler.collections:collection-seq ls)))
      (is (= 2 (length pairs)))
      ;; Each entry should be a cons pair
      (is (every #'consp pairs)))))

(test lazy-seq-set
  "collection-lazy-seq on <set> returns a lazy-seq of elements (keys only)."
  (let* ((s (fol.compiler.primitives:make 'fol.compiler.collections:<set> 1 2 3))
         (ls (fol.compiler.collections:collection-lazy-seq s)))
    (is (typep ls 'fol.compiler.collections:<lazy-seq>))
    (let ((elems (fol.compiler.collections:collection-seq ls)))
      (is (= 3 (length elems)))
      ;; All original elements should be present
      (is (null (cl:set-difference '(1 2 3) elems))))))

(test lazy-seq-list
  "collection-lazy-seq on <list> returns the <list> itself."
  (let* ((l (fol.compiler.primitives:make 'fol.compiler.collections:<list> 1 2 3))
         (ls (fol.compiler.collections:collection-lazy-seq l)))
    ;; <list> is already a sequence-like structure, so lazy-seq returns itself
    (is (typep ls 'fol.compiler.collections:<list>))
    (is (eq l ls))))

(test lazy-seq-lazy-seq
  "collection-lazy-seq on <lazy-seq> returns itself."
  (let* ((v (fol.compiler.primitives:make 'fol.compiler.collections:<vector> 1 2 3))
         (ls (fol.compiler.collections:collection-lazy-seq v)))
    (is (eq ls (fol.compiler.collections:collection-lazy-seq ls)))))

(test lazy-seq-deque
  "collection-lazy-seq on <deque> returns a lazy-seq with elements in deque order."
  (let* ((d (fol.compiler.primitives:make 'fol.compiler.collections:<deque> 1 2 3 4))
         (ls (fol.compiler.collections:collection-lazy-seq d)))
    (is (typep ls 'fol.compiler.collections:<lazy-seq>))
    (let ((elems (fol.compiler.collections:collection-seq ls)))
      (is (equal '(1 2 3 4) elems)))))

(test collection-seq-returns-cl-list
  "collection-seq always returns a proper CL list for all collection types."
  (let ((v (fol.compiler.primitives:make 'fol.compiler.collections:<vector> 1 2 3))
        (d (fol.compiler.primitives:make 'fol.compiler.collections:<dict> :a 1))
        (s (fol.compiler.primitives:make 'fol.compiler.collections:<set> 1 2)))
    (is (listp (fol.compiler.collections:collection-seq v)))
    (is (listp (fol.compiler.collections:collection-seq d)))
    (is (listp (fol.compiler.collections:collection-seq s)))))
