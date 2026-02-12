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
;;; <collection-storage> class
;;; ---------------------------------------------------------------------------

(test collection-storage-class-exists
  "The <collection-storage> class is defined and findable."
  (is (not (null (find-class 'fol.compiler.collections:<collection-storage>)))))

(test collection-storage-superclass-is-standard-object
  "<collection-storage> inherits from standard-object."
  (let ((supers (closer-mop:class-direct-superclasses
                 (find-class 'fol.compiler.collections:<collection-storage>))))
    (is (eq t (some (lambda (s) (eq s (find-class 'standard-object))) supers)))))

(test collection-storage-items-defaults-to-nil
  "<collection-storage> items slot defaults to NIL."
  (let ((obj (make-instance 'fol.compiler.collections:<collection-storage>)))
    (is (null (fol.compiler.collections:storage-items obj)))))

(test collection-storage-items-initarg
  "<collection-storage> items slot accepts :items initarg."
  (let ((obj (make-instance 'fol.compiler.collections:<collection-storage> :items :something)))
    (is (eq :something (fol.compiler.collections:storage-items obj)))))

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

(test dict-inherits-collection-storage
  "<dict> is a subclass of <collection-storage>."
  (is (eq t (subtypep 'fol.compiler.collections:<dict>
                       'fol.compiler.collections:<collection-storage>))))

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
  "<dict> storage-items returns a Sycamore hash-map."
  (let ((d (fol.compiler.collections:make 'fol.compiler.collections:<dict> :a 1)))
    (is (eq 1 (sycamore:hash-map-find (fol.compiler.collections:storage-items d) :a)))))

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

(test ordered-dict-inherits-collection-storage
  "<ordered-dict> is a subclass of <collection-storage> (via <dict>)."
  (is (eq t (subtypep 'fol.compiler.collections:<ordered-dict>
                       'fol.compiler.collections:<collection-storage>))))

(test ordered-dict-inherits-collection
  "<ordered-dict> is a subclass of <collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<ordered-dict>
                       'fol.compiler.collections:<collection>))))

(test ordered-dict-is-collection
  "<ordered-dict> satisfies <collection>?, <dict>?, <ordered-dict>?."
  (let ((d (fol.compiler.collections:ordered-dict :a 1 :b 2)))
    (is (eq t (fol.compiler.collections:<collection>? d)))
    (is (eq t (fol.compiler.collections:<dict>? d)))
    (is (eq t (fol.compiler.collections:<ordered-dict>? d)))))

(test ordered-dict-predicate-nil
  "<ordered-dict>? returns NIL for non-ordered-dicts."
  (is (null (fol.compiler.collections:<ordered-dict>? 42)))
  (is (null (fol.compiler.collections:<ordered-dict>? nil)))
  ;; A plain <dict> is NOT an <ordered-dict>
  (is (null (fol.compiler.collections:<ordered-dict>?
             (fol.compiler.collections:dict :a 1)))))

(test ordered-dict-predicate-true
  "<ordered-dict>? returns T for an <ordered-dict> instance."
  (let ((d (fol.compiler.collections:ordered-dict :a 1 :b 2)))
    (is (eq t (fol.compiler.collections:<ordered-dict>? d)))))

(test ordered-dict-is-also-dict
  "<ordered-dict> satisfies <dict>? (it is a subclass of dict)."
  (let ((d (fol.compiler.collections:ordered-dict :a 1)))
    (is (eq t (fol.compiler.collections:<dict>? d)))))

(test ordered-dict-make-empty
  "(ordered-dict) creates an empty ordered dict."
  (let ((d (fol.compiler.collections:ordered-dict)))
    (is (= 0 (fol.compiler.collections:collection-size d)))
    (is (eq t (fol.compiler.collections:collection-empty-p d)))
    (is (null (fol.compiler.collections:collection-seq d)))))

(test ordered-dict-make-with-entries
  "(ordered-dict :a 1 :b 2 :c 3) creates a populated ordered dict with 3 entries."
  (let ((d (fol.compiler.collections:ordered-dict :a 1 :b 2 :c 3)))
    (is (= 3 (fol.compiler.collections:collection-size d)))))

(test ordered-dict-preserves-insertion-order
  "collection-seq returns entries in insertion order."
  (let ((d (fol.compiler.collections:ordered-dict :c 3 :a 1 :b 2)))
    (is (equal '((:c . 3) (:a . 1) (:b . 2))
               (fol.compiler.collections:collection-seq d)))))

(test ordered-dict-duplicate-keys
  "Duplicate keys keep the last value but the first insertion position."
  (let ((d (fol.compiler.collections:ordered-dict :a 1 :b 2 :a 99)))
    (is (= 2 (fol.compiler.collections:collection-size d)))
    (is (equal '((:a . 99) (:b . 2))
               (fol.compiler.collections:collection-seq d)))))

(test ordered-dict-conj-adds-pair
  "collection-conj adds a key-value pair at the end."
  (let* ((d (fol.compiler.collections:ordered-dict :a 1 :b 2))
         (d2 (fol.compiler.collections:collection-conj d (cons :c 3))))
    (is (= 3 (fol.compiler.collections:collection-size d2)))
    (is (equal '((:a . 1) (:b . 2) (:c . 3))
               (fol.compiler.collections:collection-seq d2)))
    ;; Original unchanged
    (is (= 2 (fol.compiler.collections:collection-size d)))))

(test ordered-dict-conj-overwrites-key
  "collection-conj overwrites the value for an existing key, keeping position."
  (let* ((d (fol.compiler.collections:ordered-dict :a 1 :b 2))
         (d2 (fol.compiler.collections:collection-conj d (cons :a 99))))
    (is (= 2 (fol.compiler.collections:collection-size d2)))
    (is (equal '((:a . 99) (:b . 2))
               (fol.compiler.collections:collection-seq d2)))))

(test ordered-dict-conj-on-empty
  "collection-conj on an empty ordered dict produces a single-entry dict."
  (let* ((d (fol.compiler.collections:ordered-dict))
         (d2 (fol.compiler.collections:collection-conj d (cons :x 42))))
    (is (= 1 (fol.compiler.collections:collection-size d2)))
    (is (equal '((:x . 42)) (fol.compiler.collections:collection-seq d2)))))

(test ordered-dict-storage-is-hash-map
  "<ordered-dict> storage-items returns a Sycamore hash-map with correct values."
  (let ((d (fol.compiler.collections:ordered-dict :a 1 :b 2)))
    (is (eq 1 (sycamore:hash-map-find
                (fol.compiler.collections:storage-items d) :a)))
    (is (eq 2 (sycamore:hash-map-find
                (fol.compiler.collections:storage-items d) :b)))))

(test ordered-dict-key-order-slot
  "ordered-dict-key-order returns an FSet seq of keys in insertion order."
  (let ((d (fol.compiler.collections:ordered-dict :c 3 :a 1 :b 2)))
    (is (equal '(:c :a :b)
               (fset:convert 'cl:list
                 (fol.compiler.collections:ordered-dict-key-order d))))))

(test ordered-dict-count
  "count returns entry count for an <ordered-dict>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collections:ordered-dict))))
  (is (= 3 (fol.compiler.collections:count
             (fol.compiler.collections:ordered-dict :a 1 :b 2 :c 3)))))

(test ordered-dict-empty?
  "empty? works for <ordered-dict>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collections:ordered-dict))))
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collections:ordered-dict :a 1)))))

(test ordered-dict-print-object
  "Printing an <ordered-dict> produces FOL dict syntax in insertion order."
  (let ((d (fol.compiler.collections:ordered-dict :c 3 :a 1 :b 2)))
    (is (string= "{:C 3 :A 1 :B 2}" (write-to-string d)))))

(test ordered-dict-print-object-empty
  "Printing an empty <ordered-dict> produces {}."
  (let ((d (fol.compiler.collections:ordered-dict)))
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

(test array-dict-inherits-collection-storage
  "<array-dict> is a subclass of <collection-storage> (via <dict>)."
  (is (eq t (subtypep 'fol.compiler.collections:<array-dict>
                       'fol.compiler.collections:<collection-storage>))))

(test array-dict-inherits-collection
  "<array-dict> is a subclass of <collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<array-dict>
                       'fol.compiler.collections:<collection>))))

(test array-dict-is-collection
  "<array-dict> satisfies <collection>?, <dict>?, <ordered-collection>?, <array-dict>?."
  (let ((d (fol.compiler.collections:array-dict :a 1 :b 2)))
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
             (fol.compiler.collections:dict :a 1)))))

(test array-dict-predicate-true
  "<array-dict>? returns T for an <array-dict> instance."
  (let ((d (fol.compiler.collections:array-dict :a 1 :b 2)))
    (is (eq t (fol.compiler.collections:<array-dict>? d)))))

(test array-dict-is-also-dict
  "<array-dict> satisfies <dict>? (it is a subclass of dict)."
  (let ((d (fol.compiler.collections:array-dict :a 1)))
    (is (eq t (fol.compiler.collections:<dict>? d)))))

(test array-dict-make-empty
  "(array-dict) creates an empty array dict."
  (let ((d (fol.compiler.collections:array-dict)))
    (is (= 0 (fol.compiler.collections:collection-size d)))
    (is (eq t (fol.compiler.collections:collection-empty-p d)))
    (is (null (fol.compiler.collections:collection-seq d)))))

(test array-dict-make-with-entries
  "(array-dict :a 1 :b 2 :c 3) creates a populated array dict with 3 entries."
  (let ((d (fol.compiler.collections:array-dict :a 1 :b 2 :c 3)))
    (is (= 3 (fol.compiler.collections:collection-size d)))))

(test array-dict-preserves-insertion-order
  "collection-seq returns entries in insertion order."
  (let ((d (fol.compiler.collections:array-dict :c 3 :a 1 :b 2)))
    (is (equal '((:c . 3) (:a . 1) (:b . 2))
               (fol.compiler.collections:collection-seq d)))))

(test array-dict-duplicate-keys
  "Duplicate keys keep the last value but the first insertion position."
  (let ((d (fol.compiler.collections:array-dict :a 1 :b 2 :a 99)))
    (is (= 2 (fol.compiler.collections:collection-size d)))
    (is (equal '((:a . 99) (:b . 2))
               (fol.compiler.collections:collection-seq d)))))

(test array-dict-conj-adds-pair
  "collection-conj adds a key-value pair at the end."
  (let* ((d (fol.compiler.collections:array-dict :a 1 :b 2))
         (d2 (fol.compiler.collections:collection-conj d (cons :c 3))))
    (is (= 3 (fol.compiler.collections:collection-size d2)))
    (is (equal '((:a . 1) (:b . 2) (:c . 3))
               (fol.compiler.collections:collection-seq d2)))
    ;; Original unchanged
    (is (= 2 (fol.compiler.collections:collection-size d)))))

(test array-dict-conj-overwrites-key
  "collection-conj overwrites the value for an existing key, keeping position."
  (let* ((d (fol.compiler.collections:array-dict :a 1 :b 2))
         (d2 (fol.compiler.collections:collection-conj d (cons :a 99))))
    (is (= 2 (fol.compiler.collections:collection-size d2)))
    (is (equal '((:a . 99) (:b . 2))
               (fol.compiler.collections:collection-seq d2)))))

(test array-dict-conj-on-empty
  "collection-conj on an empty array dict produces a single-entry dict."
  (let* ((d (fol.compiler.collections:array-dict))
         (d2 (fol.compiler.collections:collection-conj d (cons :x 42))))
    (is (= 1 (fol.compiler.collections:collection-size d2)))
    (is (equal '((:x . 42)) (fol.compiler.collections:collection-seq d2)))))

(test array-dict-storage-is-hash-map
  "<array-dict> storage-items returns a Sycamore hash-map with correct values."
  (let ((d (fol.compiler.collections:array-dict :a 1 :b 2)))
    (is (eq 1 (sycamore:hash-map-find
                (fol.compiler.collections:storage-items d) :a)))
    (is (eq 2 (sycamore:hash-map-find
                (fol.compiler.collections:storage-items d) :b)))))

(test array-dict-key-order-slot
  "array-dict-key-order returns an FSet seq of keys in insertion order."
  (let ((d (fol.compiler.collections:array-dict :c 3 :a 1 :b 2)))
    (is (equal '(:c :a :b)
               (fset:convert 'cl:list
                 (fol.compiler.collections:array-dict-key-order d))))))

(test array-dict-count
  "count returns entry count for an <array-dict>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collections:array-dict))))
  (is (= 3 (fol.compiler.collections:count
             (fol.compiler.collections:array-dict :a 1 :b 2 :c 3)))))

(test array-dict-empty?
  "empty? works for <array-dict>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collections:array-dict))))
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collections:array-dict :a 1)))))

(test array-dict-print-object
  "Printing an <array-dict> produces FOL dict syntax in insertion order."
  (let ((d (fol.compiler.collections:array-dict :c 3 :a 1 :b 2)))
    (is (string= "{:C 3 :A 1 :B 2}" (write-to-string d)))))

(test array-dict-print-object-empty
  "Printing an empty <array-dict> produces {}."
  (let ((d (fol.compiler.collections:array-dict)))
    (is (string= "{}" (write-to-string d)))))

;;; ---------------------------------------------------------------------------
;;; <sorted-dict> class, predicate, constructor, and protocol
;;; ---------------------------------------------------------------------------

(test sorted-dict-class-exists
  "The <sorted-dict> class is defined."
  (is (not (null (find-class 'fol.compiler.collections:<sorted-dict>)))))

(test sorted-dict-inherits-dict
  "<sorted-dict> is a subclass of <dict>."
  (is (eq t (subtypep 'fol.compiler.collections:<sorted-dict>
                       'fol.compiler.collections:<dict>))))

(test sorted-dict-inherits-ordered-collection
  "<sorted-dict> is a subclass of <ordered-collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<sorted-dict>
                       'fol.compiler.collections:<ordered-collection>))))

(test sorted-dict-inherits-collection-storage
  "<sorted-dict> is a subclass of <collection-storage> (via <dict>)."
  (is (eq t (subtypep 'fol.compiler.collections:<sorted-dict>
                       'fol.compiler.collections:<collection-storage>))))

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
  (let ((d (fol.compiler.collections:sorted-dict nil 1 :a 2 :b)))
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
             (fol.compiler.collections:dict :a 1)))))

(test sorted-dict-predicate-true
  "<sorted-dict>? returns T for a <sorted-dict> instance."
  (let ((d (fol.compiler.collections:sorted-dict nil 1 :a 2 :b)))
    (is (eq t (fol.compiler.collections:<sorted-dict>? d)))))

(test sorted-dict-is-also-dict
  "<sorted-dict> satisfies <dict>? (it is a subclass of dict)."
  (let ((d (fol.compiler.collections:sorted-dict nil 1 :a)))
    (is (eq t (fol.compiler.collections:<dict>? d)))))

(test sorted-dict-make-empty
  "(sorted-dict nil) creates an empty sorted dict."
  (let ((d (fol.compiler.collections:sorted-dict nil)))
    (is (= 0 (fol.compiler.collections:collection-size d)))
    (is (eq t (fol.compiler.collections:collection-empty-p d)))
    (is (null (fol.compiler.collections:collection-seq d)))))

(test sorted-dict-make-with-entries
  "(sorted-dict nil 2 :b 1 :a 3 :c) creates a populated sorted dict with 3 entries."
  (let ((d (fol.compiler.collections:sorted-dict nil 2 :b 1 :a 3 :c)))
    (is (= 3 (fol.compiler.collections:collection-size d)))))

(test sorted-dict-sorted-seq
  "collection-seq returns entries in comparator key order."
  (let ((d (fol.compiler.collections:sorted-dict nil 3 :c 1 :a 2 :b)))
    (is (equal '((1 . :a) (2 . :b) (3 . :c))
               (fol.compiler.collections:collection-seq d)))))

(test sorted-dict-duplicate-keys
  "Duplicate keys keep the last value."
  (let ((d (fol.compiler.collections:sorted-dict nil 1 :first 2 :x 1 :second)))
    (is (= 2 (fol.compiler.collections:collection-size d)))
    (is (equal '((1 . :second) (2 . :x))
               (fol.compiler.collections:collection-seq d)))))

(test sorted-dict-conj-adds-pair
  "collection-conj adds a key-value pair in order."
  (let* ((d (fol.compiler.collections:sorted-dict nil 1 :a 3 :c))
         (d2 (fol.compiler.collections:collection-conj d (cons 2 :b))))
    (is (= 3 (fol.compiler.collections:collection-size d2)))
    (is (equal '((1 . :a) (2 . :b) (3 . :c))
               (fol.compiler.collections:collection-seq d2)))
    ;; Original unchanged
    (is (= 2 (fol.compiler.collections:collection-size d)))))

(test sorted-dict-conj-overwrites-key
  "collection-conj overwrites the value for an existing key."
  (let* ((d (fol.compiler.collections:sorted-dict nil 1 :a 2 :b))
         (d2 (fol.compiler.collections:collection-conj d (cons 1 :z))))
    (is (= 2 (fol.compiler.collections:collection-size d2)))
    (is (equal '((1 . :z) (2 . :b))
               (fol.compiler.collections:collection-seq d2)))))

(test sorted-dict-conj-on-empty
  "collection-conj on an empty sorted dict produces a single-entry dict."
  (let* ((d (fol.compiler.collections:sorted-dict nil))
         (d2 (fol.compiler.collections:collection-conj d (cons 42 :x))))
    (is (= 1 (fol.compiler.collections:collection-size d2)))
    (is (equal '((42 . :x)) (fol.compiler.collections:collection-seq d2)))))

(test sorted-dict-custom-comparator
  "A custom comparator (reverse order) is used for key sorting."
  (let* ((rev-cmp (lambda (a b)
                    (cond ((> a b) -1)
                          ((< a b)  1)
                          (t        0))))
         (d (fol.compiler.collections:sorted-dict rev-cmp 1 :a 2 :b 3 :c)))
    (is (equal '((3 . :c) (2 . :b) (1 . :a))
               (fol.compiler.collections:collection-seq d)))))

(test sorted-dict-comparator-preserved-on-conj
  "collection-conj preserves the comparator."
  (let* ((rev-cmp (lambda (a b)
                    (cond ((> a b) -1)
                          ((< a b)  1)
                          (t        0))))
         (d (fol.compiler.collections:sorted-dict rev-cmp 3 :c 1 :a))
         (d2 (fol.compiler.collections:collection-conj d (cons 2 :b))))
    (is (equal '((3 . :c) (2 . :b) (1 . :a))
               (fol.compiler.collections:collection-seq d2)))
    (is (eq rev-cmp (fol.compiler.collections:comparator-compare d2)))))

(test sorted-dict-storage-is-tree-map
  "<sorted-dict> storage-items returns a Sycamore tree-map with correct values."
  (let ((d (fol.compiler.collections:sorted-dict nil 1 :a 2 :b)))
    (is (eq :a (sycamore:tree-map-find
                (fol.compiler.collections:storage-items d) 1)))
    (is (eq :b (sycamore:tree-map-find
                (fol.compiler.collections:storage-items d) 2)))))

(test sorted-dict-count
  "count returns entry count for a <sorted-dict>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collections:sorted-dict nil))))
  (is (= 3 (fol.compiler.collections:count
             (fol.compiler.collections:sorted-dict nil 1 :a 2 :b 3 :c)))))

(test sorted-dict-empty?
  "empty? works for <sorted-dict>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collections:sorted-dict nil))))
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collections:sorted-dict nil 1 :a)))))

(test sorted-dict-print-object
  "Printing a <sorted-dict> produces FOL dict syntax with sorted keys."
  (let ((d (fol.compiler.collections:sorted-dict nil 2 :b 1 :a)))
    (is (string= "{1 :A 2 :B}" (write-to-string d)))))

(test sorted-dict-print-object-empty
  "Printing an empty <sorted-dict> produces {}."
  (let ((d (fol.compiler.collections:sorted-dict nil)))
    (is (string= "{}" (write-to-string d)))))

;;; ---------------------------------------------------------------------------
;;; <int-dict> class, predicate, constructor, and protocol
;;; ---------------------------------------------------------------------------

(test int-dict-class-exists
  "The <int-dict> class is defined."
  (is (not (null (find-class 'fol.compiler.collections:<int-dict>)))))

(test int-dict-inherits-sorted-dict
  "<int-dict> is a subclass of <sorted-dict>."
  (is (eq t (subtypep 'fol.compiler.collections:<int-dict>
                       'fol.compiler.collections:<sorted-dict>))))

(test int-dict-inherits-dict
  "<int-dict> is a subclass of <dict>."
  (is (eq t (subtypep 'fol.compiler.collections:<int-dict>
                       'fol.compiler.collections:<dict>))))

(test int-dict-inherits-ordered-collection
  "<int-dict> is a subclass of <ordered-collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<int-dict>
                       'fol.compiler.collections:<ordered-collection>))))

(test int-dict-inherits-collection-storage
  "<int-dict> is a subclass of <collection-storage> (via <dict>)."
  (is (eq t (subtypep 'fol.compiler.collections:<int-dict>
                       'fol.compiler.collections:<collection-storage>))))

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
  (let ((d (fol.compiler.collections:int-dict 1 :a 2 :b)))
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
             (fol.compiler.collections:sorted-dict nil 1 :a)))))

(test int-dict-predicate-true
  "<int-dict>? returns T for an <int-dict> instance."
  (let ((d (fol.compiler.collections:int-dict 1 :a 2 :b)))
    (is (eq t (fol.compiler.collections:<int-dict>? d)))))

(test int-dict-is-also-dict
  "<int-dict> satisfies <dict>? (it is a subclass of dict)."
  (let ((d (fol.compiler.collections:int-dict 1 :a)))
    (is (eq t (fol.compiler.collections:<dict>? d)))))

(test int-dict-make-empty
  "(int-dict) creates an empty int dict."
  (let ((d (fol.compiler.collections:int-dict)))
    (is (= 0 (fol.compiler.collections:collection-size d)))
    (is (eq t (fol.compiler.collections:collection-empty-p d)))
    (is (null (fol.compiler.collections:collection-seq d)))))

(test int-dict-make-with-entries
  "(int-dict 2 :b 1 :a 3 :c) creates a populated int dict with 3 entries."
  (let ((d (fol.compiler.collections:int-dict 2 :b 1 :a 3 :c)))
    (is (= 3 (fol.compiler.collections:collection-size d)))))

(test int-dict-sorted-seq
  "collection-seq returns entries in ascending integer key order."
  (let ((d (fol.compiler.collections:int-dict 3 :c 1 :a 2 :b)))
    (is (equal '((1 . :a) (2 . :b) (3 . :c))
               (fol.compiler.collections:collection-seq d)))))

(test int-dict-duplicate-keys
  "Duplicate integer keys keep the last value."
  (let ((d (fol.compiler.collections:int-dict 1 :first 2 :x 1 :second)))
    (is (= 2 (fol.compiler.collections:collection-size d)))
    (is (equal '((1 . :second) (2 . :x))
               (fol.compiler.collections:collection-seq d)))))

(test int-dict-conj-adds-pair
  "collection-conj adds a key-value pair in integer order."
  (let* ((d (fol.compiler.collections:int-dict 1 :a 3 :c))
         (d2 (fol.compiler.collections:collection-conj d (cons 2 :b))))
    (is (= 3 (fol.compiler.collections:collection-size d2)))
    (is (equal '((1 . :a) (2 . :b) (3 . :c))
               (fol.compiler.collections:collection-seq d2)))
    ;; Original unchanged
    (is (= 2 (fol.compiler.collections:collection-size d)))))

(test int-dict-conj-overwrites-key
  "collection-conj overwrites the value for an existing integer key."
  (let* ((d (fol.compiler.collections:int-dict 1 :a 2 :b))
         (d2 (fol.compiler.collections:collection-conj d (cons 1 :z))))
    (is (= 2 (fol.compiler.collections:collection-size d2)))
    (is (equal '((1 . :z) (2 . :b))
               (fol.compiler.collections:collection-seq d2)))))

(test int-dict-conj-on-empty
  "collection-conj on an empty int dict produces a single-entry dict."
  (let* ((d (fol.compiler.collections:int-dict))
         (d2 (fol.compiler.collections:collection-conj d (cons 42 :x))))
    (is (= 1 (fol.compiler.collections:collection-size d2)))
    (is (equal '((42 . :x)) (fol.compiler.collections:collection-seq d2)))))

(test int-dict-conj-preserves-type
  "collection-conj on an <int-dict> returns another <int-dict>."
  (let* ((d (fol.compiler.collections:int-dict 1 :a))
         (d2 (fol.compiler.collections:collection-conj d (cons 2 :b))))
    (is (eq t (fol.compiler.collections:<int-dict>? d2)))))

(test int-dict-storage-is-tree-map
  "<int-dict> storage-items returns a Sycamore tree-map with correct values."
  (let ((d (fol.compiler.collections:int-dict 1 :a 2 :b)))
    (is (eq :a (sycamore:tree-map-find
                (fol.compiler.collections:storage-items d) 1)))
    (is (eq :b (sycamore:tree-map-find
                (fol.compiler.collections:storage-items d) 2)))))

(test int-dict-count
  "count returns entry count for an <int-dict>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collections:int-dict))))
  (is (= 3 (fol.compiler.collections:count
             (fol.compiler.collections:int-dict 1 :a 2 :b 3 :c)))))

(test int-dict-empty?
  "empty? works for <int-dict>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collections:int-dict))))
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collections:int-dict 1 :a)))))

(test int-dict-print-object
  "Printing an <int-dict> produces FOL dict syntax with sorted integer keys."
  (let ((d (fol.compiler.collections:int-dict 2 :b 1 :a)))
    (is (string= "{1 :A 2 :B}" (write-to-string d)))))

(test int-dict-print-object-empty
  "Printing an empty <int-dict> produces {}."
  (let ((d (fol.compiler.collections:int-dict)))
    (is (string= "{}" (write-to-string d)))))

(test int-dict-by-custom-comparator
  "int-dict-by with a descending comparator reverses key order."
  (let* ((desc-cmp (lambda (a b)
                     (cond ((> a b) -1)
                           ((< a b)  1)
                           (t        0))))
         (d (fol.compiler.collections:int-dict-by desc-cmp 1 :a 2 :b 3 :c)))
    (is (equal '((3 . :c) (2 . :b) (1 . :a))
               (fol.compiler.collections:collection-seq d)))
    (is (eq t (fol.compiler.collections:<int-dict>? d)))))

(test int-dict-by-nil-uses-default
  "int-dict-by with NIL comparator uses the default ascending fixnum order."
  (let ((d (fol.compiler.collections:int-dict-by nil 3 :c 1 :a 2 :b)))
    (is (equal '((1 . :a) (2 . :b) (3 . :c))
               (fol.compiler.collections:collection-seq d)))
    (is (eq t (fol.compiler.collections:<int-dict>? d)))))

(test int-dict-by-comparator-preserved-on-conj
  "collection-conj preserves the custom comparator from int-dict-by."
  (let* ((desc-cmp (lambda (a b)
                     (cond ((> a b) -1)
                           ((< a b)  1)
                           (t        0))))
         (d (fol.compiler.collections:int-dict-by desc-cmp 3 :c 1 :a))
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

(test priority-dict-inherits-dict
  "<priority-dict> is a subclass of <dict>."
  (is (eq t (subtypep 'fol.compiler.collections:<priority-dict>
                       'fol.compiler.collections:<dict>))))

(test priority-dict-inherits-ordered-collection
  "<priority-dict> is a subclass of <ordered-collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<priority-dict>
                       'fol.compiler.collections:<ordered-collection>))))

(test priority-dict-inherits-collection-storage
  "<priority-dict> is a subclass of <collection-storage> (via <dict>)."
  (is (eq t (subtypep 'fol.compiler.collections:<priority-dict>
                       'fol.compiler.collections:<collection-storage>))))

(test priority-dict-inherits-collection
  "<priority-dict> is a subclass of <collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<priority-dict>
                       'fol.compiler.collections:<collection>))))

(test priority-dict-is-collection
  "<priority-dict> satisfies <collection>?, <dict>?, <ordered-collection>?, <priority-dict>?."
  (let ((d (fol.compiler.collections:priority-dict :a 1 :b 2)))
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
             (fol.compiler.collections:dict :a 1)))))

(test priority-dict-predicate-true
  "<priority-dict>? returns T for a <priority-dict> instance."
  (let ((d (fol.compiler.collections:priority-dict :a 1 :b 2)))
    (is (eq t (fol.compiler.collections:<priority-dict>? d)))))

(test priority-dict-is-also-dict
  "<priority-dict> satisfies <dict>? (it is a subclass of dict)."
  (let ((d (fol.compiler.collections:priority-dict :a 1)))
    (is (eq t (fol.compiler.collections:<dict>? d)))))

(test priority-dict-make-empty
  "(priority-dict) creates an empty priority dict."
  (let ((d (fol.compiler.collections:priority-dict)))
    (is (= 0 (fol.compiler.collections:collection-size d)))
    (is (eq t (fol.compiler.collections:collection-empty-p d)))
    (is (null (fol.compiler.collections:collection-seq d)))))

(test priority-dict-make-with-entries
  "(priority-dict :a 1 :b 3 :c 2) creates a populated priority dict with 3 entries."
  (let ((d (fol.compiler.collections:priority-dict :a 1 :b 3 :c 2)))
    (is (= 3 (fol.compiler.collections:collection-size d)))))

(test priority-dict-orders-by-priority
  "collection-seq returns entries in ascending priority order."
  (let ((d (fol.compiler.collections:priority-dict :x 30 :y 10 :z 20)))
    (is (equal '((:y . 10) (:z . 20) (:x . 30))
               (fol.compiler.collections:collection-seq d)))))

(test priority-dict-duplicate-keys
  "Duplicate keys keep the last priority."
  (let ((d (fol.compiler.collections:priority-dict :a 1 :b 2 :a 99)))
    (is (= 2 (fol.compiler.collections:collection-size d)))
    ;; :a has priority 99 now, :b has 2 → order is :b(2), :a(99)
    (is (equal '((:b . 2) (:a . 99))
               (fol.compiler.collections:collection-seq d)))))

(test priority-dict-conj-adds-pair
  "collection-conj adds a new key-priority pair in priority order."
  (let* ((d (fol.compiler.collections:priority-dict :a 10 :b 30))
         (d2 (fol.compiler.collections:collection-conj d (cons :c 20))))
    (is (= 3 (fol.compiler.collections:collection-size d2)))
    (is (equal '((:a . 10) (:c . 20) (:b . 30))
               (fol.compiler.collections:collection-seq d2)))
    ;; Original unchanged
    (is (= 2 (fol.compiler.collections:collection-size d)))))

(test priority-dict-conj-updates-priority
  "collection-conj on existing key updates its priority and re-orders."
  (let* ((d (fol.compiler.collections:priority-dict :a 10 :b 20 :c 30))
         ;; Move :c from priority 30 to priority 5 (now the minimum)
         (d2 (fol.compiler.collections:collection-conj d (cons :c 5))))
    (is (= 3 (fol.compiler.collections:collection-size d2)))
    (is (equal '((:c . 5) (:a . 10) (:b . 20))
               (fol.compiler.collections:collection-seq d2)))))

(test priority-dict-conj-on-empty
  "collection-conj on an empty priority dict produces a single-entry dict."
  (let* ((d (fol.compiler.collections:priority-dict))
         (d2 (fol.compiler.collections:collection-conj d (cons :x 42))))
    (is (= 1 (fol.compiler.collections:collection-size d2)))
    (is (equal '((:x . 42)) (fol.compiler.collections:collection-seq d2)))))

(test priority-dict-storage-is-hash-map
  "<priority-dict> storage-items returns a Sycamore hash-map with key→priority."
  (let ((d (fol.compiler.collections:priority-dict :a 10 :b 20)))
    (is (eq 10 (sycamore:hash-map-find
                 (fol.compiler.collections:storage-items d) :a)))
    (is (eq 20 (sycamore:hash-map-find
                 (fol.compiler.collections:storage-items d) :b)))))

(test priority-dict-tree-slot
  "priority-dict-tree returns the Sycamore tree-map for priority ordering."
  (let ((d (fol.compiler.collections:priority-dict :a 10 :b 20)))
    (is (not (null (fol.compiler.collections:priority-dict-tree d))))))

(test priority-dict-peek-min
  "priority-dict-peek-min returns the entry with the lowest priority."
  (let ((d (fol.compiler.collections:priority-dict :x 30 :y 10 :z 20)))
    (is (equal '(:y . 10)
               (fol.compiler.collections:priority-dict-peek-min d)))))

(test priority-dict-peek-min-empty
  "priority-dict-peek-min returns NIL for an empty dict."
  (let ((d (fol.compiler.collections:priority-dict)))
    (is (null (fol.compiler.collections:priority-dict-peek-min d)))))

(test priority-dict-pop-min
  "priority-dict-pop-min removes the minimum-priority entry."
  (let* ((d (fol.compiler.collections:priority-dict :x 30 :y 10 :z 20))
         (d2 (fol.compiler.collections:priority-dict-pop-min d)))
    (is (= 2 (fol.compiler.collections:collection-size d2)))
    (is (equal '((:z . 20) (:x . 30))
               (fol.compiler.collections:collection-seq d2)))
    ;; Original unchanged
    (is (= 3 (fol.compiler.collections:collection-size d)))))

(test priority-dict-pop-min-empty
  "priority-dict-pop-min on empty dict returns the same empty dict."
  (let* ((d (fol.compiler.collections:priority-dict))
         (d2 (fol.compiler.collections:priority-dict-pop-min d)))
    (is (= 0 (fol.compiler.collections:collection-size d2)))))

(test priority-dict-count
  "count returns entry count for a <priority-dict>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collections:priority-dict))))
  (is (= 3 (fol.compiler.collections:count
             (fol.compiler.collections:priority-dict :a 1 :b 2 :c 3)))))

(test priority-dict-empty?
  "empty? works for <priority-dict>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collections:priority-dict))))
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collections:priority-dict :a 1)))))

(test priority-dict-print-object
  "Printing a <priority-dict> produces FOL dict syntax in priority order."
  (let ((d (fol.compiler.collections:priority-dict :x 30 :y 10 :z 20)))
    (is (string= "{:Y 10 :Z 20 :X 30}" (write-to-string d)))))

(test priority-dict-print-object-empty
  "Printing an empty <priority-dict> produces {}."
  (let ((d (fol.compiler.collections:priority-dict)))
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

(test set-inherits-collection-storage
  "<set> is a subclass of <collection-storage>."
  (is (eq t (subtypep 'fol.compiler.collections:<set>
                       'fol.compiler.collections:<collection-storage>))))

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
  "<set> storage-items returns a Sycamore hash-set."
  (let ((s (fol.compiler.collections:make 'fol.compiler.collections:<set> :x :y)))
    (is (eq :x (sycamore:hash-set-find (fol.compiler.collections:storage-items s) :x)))))

;;; ---------------------------------------------------------------------------
;;; Constructor functions (vector, dict, set)
;;; ---------------------------------------------------------------------------

(test vector-function-empty
  "(vector) creates an empty <vector>."
  (let ((v (fol.compiler.collections:vector)))
    (is (eq t (fol.compiler.collections:<vector>? v)))
    (is (= 0 (fol.compiler.collections:collection-size v)))))

(test vector-function-with-elements
  "(vector 1 2 3) creates a populated <vector>."
  (let ((v (fol.compiler.collections:vector 1 2 3)))
    (is (eq t (fol.compiler.collections:<vector>? v)))
    (is (= 3 (fol.compiler.collections:collection-size v)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq v)))))

(test dict-function-empty
  "(dict) creates an empty <dict>."
  (let ((d (fol.compiler.collections:dict)))
    (is (eq t (fol.compiler.collections:<dict>? d)))
    (is (= 0 (fol.compiler.collections:collection-size d)))))

(test dict-function-with-entries
  "(dict :a 1 :b 2) creates a populated <dict>."
  (let ((d (fol.compiler.collections:dict :a 1 :b 2)))
    (is (eq t (fol.compiler.collections:<dict>? d)))
    (is (= 2 (fol.compiler.collections:collection-size d)))))

(test set-function-empty
  "(set) creates an empty <set>."
  (let ((s (fol.compiler.collections:set)))
    (is (eq t (fol.compiler.collections:<set>? s)))
    (is (= 0 (fol.compiler.collections:collection-size s)))))

(test set-function-with-elements
  "(set 1 2 3) creates a populated <set>."
  (let ((s (fol.compiler.collections:set 1 2 3)))
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
  (let ((b (fol.compiler.collections:bag 1 2 3)))
    (is (eq t (fol.compiler.collections:<bag>? b)))))

(test bag-make-empty
  "(bag) creates an empty bag."
  (let ((b (fol.compiler.collections:bag)))
    (is (= 0 (fol.compiler.collections:collection-size b)))
    (is (eq t (fol.compiler.collections:collection-empty-p b)))
    (is (null (fol.compiler.collections:collection-seq b)))))

(test bag-make-with-elements
  "(bag 1 1 2) creates a bag with counts."
  (let ((b (fol.compiler.collections:bag 1 1 2)))
    (is (= 3 (fol.compiler.collections:collection-size b)))))

(test bag-conj-adds-element
  "collection-conj on a bag adds one occurrence."
  (let* ((b (fol.compiler.collections:bag 1 2))
         (b2 (fol.compiler.collections:collection-conj b 1)))
    (is (= 3 (fol.compiler.collections:collection-size b2)))
    ;; Original unchanged
    (is (= 2 (fol.compiler.collections:collection-size b)))))

(test bag-seq-expands-counts
  "collection-seq on a bag returns elements repeated by count."
  (let* ((b (fol.compiler.collections:bag 1 1 2))
         (seq (fol.compiler.collections:collection-seq b)))
    (is (= 3 (length seq)))))

;;; ---------------------------------------------------------------------------
;;; print-object methods
;;; ---------------------------------------------------------------------------

(test vector-print-object
  "Printing a <vector> produces FOL vector syntax."
  (let ((v (fol.compiler.collections:vector 1 2 3)))
    (is (string= "[1 2 3]" (write-to-string v)))))

(test vector-print-object-empty
  "Printing an empty <vector> produces []."
  (let ((v (fol.compiler.collections:vector)))
    (is (string= "[]" (write-to-string v)))))

(test vector-print-object-nested
  "Printing nested vectors produces nested brackets."
  (let ((v (fol.compiler.collections:vector
             1
             (fol.compiler.collections:vector 2 3))))
    (is (string= "[1 [2 3]]" (write-to-string v)))))

(test dict-print-object-empty
  "Printing an empty <dict> produces {}."
  (let ((d (fol.compiler.collections:dict)))
    (is (string= "{}" (write-to-string d)))))

(test dict-print-object-single
  "Printing a single-entry <dict> produces {key value}."
  (let ((d (fol.compiler.collections:dict :a 1)))
    (is (string= "{:A 1}" (write-to-string d)))))

(test set-print-object-empty
  "Printing an empty <set> produces #{}."
  (let ((s (fol.compiler.collections:set)))
    (is (string= "#{}" (write-to-string s)))))

(test bag-print-object-empty
  "Printing an empty <bag> produces #M{}."
  (let ((b (fol.compiler.collections:bag)))
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
             (fol.compiler.collections:vector 1 2 3)))))

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

(test array-storage-is-cl-array
  "<array> storage-items returns a CL simple-vector."
  (let ((a (fol.compiler.collections:make 'fol.compiler.collections:<array> 1 2 3)))
    (is (arrayp (fol.compiler.collections:storage-items a)))))

;;; ---------------------------------------------------------------------------
;;; count generic function
;;; ---------------------------------------------------------------------------

(test count-vector
  "count returns element count for a <vector>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collections:vector))))
  (is (= 3 (fol.compiler.collections:count
             (fol.compiler.collections:vector 1 2 3)))))

(test count-array
  "count returns element count for an <array>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collections:make 'fol.compiler.collections:<array>))))
  (is (= 2 (fol.compiler.collections:count
             (fol.compiler.collections:make 'fol.compiler.collections:<array> 10 20)))))

(test count-dict
  "count returns entry count for a <dict>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collections:dict))))
  (is (= 2 (fol.compiler.collections:count
             (fol.compiler.collections:dict :a 1 :b 2)))))

(test count-set
  "count returns element count for a <set>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collections:set))))
  (is (= 3 (fol.compiler.collections:count
             (fol.compiler.collections:set 1 2 3)))))

(test count-bag
  "count returns total element count for a <bag>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collections:bag))))
  (is (= 3 (fol.compiler.collections:count
             (fol.compiler.collections:bag 1 1 2)))))

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
             (fol.compiler.collections:vector)))))

(test empty?-nonempty-vector
  "empty? returns NIL for a non-empty <vector>."
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collections:vector 1 2 3)))))

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
             (fol.compiler.collections:dict)))))

(test empty?-nonempty-dict
  "empty? returns NIL for a non-empty <dict>."
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collections:dict :a 1)))))

(test empty?-empty-set
  "empty? returns T for an empty <set>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collections:set)))))

(test empty?-nonempty-set
  "empty? returns NIL for a non-empty <set>."
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collections:set 1 2)))))

(test empty?-empty-bag
  "empty? returns T for an empty <bag>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collections:bag)))))

(test empty?-nonempty-bag
  "empty? returns NIL for a non-empty <bag>."
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collections:bag 1 1 2)))))

;;; ---------------------------------------------------------------------------
;;; <ordered-set> class, predicate, constructor, and protocol
;;; ---------------------------------------------------------------------------

(test ordered-set-class-exists
  "The <ordered-set> class is defined."
  (is (not (null (find-class 'fol.compiler.collections:<ordered-set>)))))

(test ordered-set-inherits-set
  "<ordered-set> is a subclass of <set>."
  (is (eq t (subtypep 'fol.compiler.collections:<ordered-set>
                       'fol.compiler.collections:<set>))))

(test ordered-set-inherits-ordered-collection
  "<ordered-set> is a subclass of <ordered-collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<ordered-set>
                       'fol.compiler.collections:<ordered-collection>))))

(test ordered-set-is-collection
  "<ordered-set> satisfies <collection>? and <set>?."
  (let ((s (fol.compiler.collections:ordered-set 1 2 3)))
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
             (fol.compiler.collections:set 1 2 3)))))

(test ordered-set-predicate-true
  "<ordered-set>? returns T for an <ordered-set> instance."
  (let ((s (fol.compiler.collections:ordered-set 1 2 3)))
    (is (eq t (fol.compiler.collections:<ordered-set>? s)))))

(test ordered-set-make-empty
  "(ordered-set) creates an empty ordered set."
  (let ((s (fol.compiler.collections:ordered-set)))
    (is (= 0 (fol.compiler.collections:collection-size s)))
    (is (eq t (fol.compiler.collections:collection-empty-p s)))
    (is (null (fol.compiler.collections:collection-seq s)))))

(test ordered-set-make-with-elements
  "(ordered-set 1 2 3) creates a populated ordered set."
  (let ((s (fol.compiler.collections:ordered-set 1 2 3)))
    (is (= 3 (fol.compiler.collections:collection-size s)))))

(test ordered-set-preserves-insertion-order
  "collection-seq returns elements in insertion order."
  (let ((s (fol.compiler.collections:ordered-set 3 1 4 1 5 9 2 6)))
    ;; Duplicates dropped, order preserved
    (is (equal '(3 1 4 5 9 2 6) (fol.compiler.collections:collection-seq s)))))

(test ordered-set-deduplicates
  "Duplicate elements are silently dropped during construction."
  (let ((s (fol.compiler.collections:ordered-set 1 2 2 3 3 3)))
    (is (= 3 (fol.compiler.collections:collection-size s)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq s)))))

(test ordered-set-conj-appends
  "collection-conj adds a new element at the end."
  (let* ((s (fol.compiler.collections:ordered-set 1 2))
         (s2 (fol.compiler.collections:collection-conj s 3)))
    (is (= 3 (fol.compiler.collections:collection-size s2)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq s2)))
    ;; Original unchanged
    (is (= 2 (fol.compiler.collections:collection-size s)))))

(test ordered-set-conj-deduplicates
  "collection-conj does not add duplicate elements."
  (let* ((s (fol.compiler.collections:ordered-set 1 2 3))
         (s2 (fol.compiler.collections:collection-conj s 2)))
    (is (= 3 (fol.compiler.collections:collection-size s2)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq s2)))
    ;; Returns the same object when element already present
    (is (eq s s2))))

(test ordered-set-conj-on-empty
  "collection-conj on an empty ordered set produces a single-element set."
  (let* ((s (fol.compiler.collections:ordered-set))
         (s2 (fol.compiler.collections:collection-conj s 42)))
    (is (= 1 (fol.compiler.collections:collection-size s2)))
    (is (equal '(42) (fol.compiler.collections:collection-seq s2)))))

(test ordered-set-count
  "count returns element count for an <ordered-set>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collections:ordered-set))))
  (is (= 3 (fol.compiler.collections:count
             (fol.compiler.collections:ordered-set 1 2 3)))))

(test ordered-set-empty?
  "empty? works for <ordered-set>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collections:ordered-set))))
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collections:ordered-set 1 2)))))

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
  (let ((s (fol.compiler.collections:sorted-set nil 3 1 2)))
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
             (fol.compiler.collections:set 1 2 3)))))

(test sorted-set-predicate-true
  "<sorted-set>? returns T for a <sorted-set> instance."
  (let ((s (fol.compiler.collections:sorted-set nil 1 2 3)))
    (is (eq t (fol.compiler.collections:<sorted-set>? s)))))

(test sorted-set-make-empty
  "(sorted-set nil) creates an empty sorted set."
  (let ((s (fol.compiler.collections:sorted-set nil)))
    (is (= 0 (fol.compiler.collections:collection-size s)))
    (is (eq t (fol.compiler.collections:collection-empty-p s)))
    (is (null (fol.compiler.collections:collection-seq s)))))

(test sorted-set-make-with-elements
  "(sorted-set nil 5 3 1) creates a populated sorted set."
  (let ((s (fol.compiler.collections:sorted-set nil 5 3 1)))
    (is (= 3 (fol.compiler.collections:collection-size s)))))

(test sorted-set-sorts-elements
  "collection-seq returns elements in comparator order."
  (let ((s (fol.compiler.collections:sorted-set nil 5 3 1 4 2)))
    (is (equal '(1 2 3 4 5) (fol.compiler.collections:collection-seq s)))))

(test sorted-set-deduplicates
  "Duplicate elements are silently dropped."
  (let ((s (fol.compiler.collections:sorted-set nil 3 1 2 2 3 1)))
    (is (= 3 (fol.compiler.collections:collection-size s)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq s)))))

(test sorted-set-conj-inserts-in-order
  "collection-conj inserts in comparator order."
  (let* ((s (fol.compiler.collections:sorted-set nil 1 3 5))
         (s2 (fol.compiler.collections:collection-conj s 2)))
    (is (= 4 (fol.compiler.collections:collection-size s2)))
    (is (equal '(1 2 3 5) (fol.compiler.collections:collection-seq s2)))
    ;; Original unchanged
    (is (= 3 (fol.compiler.collections:collection-size s)))))

(test sorted-set-conj-deduplicates
  "collection-conj does not add duplicate elements."
  (let* ((s (fol.compiler.collections:sorted-set nil 1 2 3))
         (s2 (fol.compiler.collections:collection-conj s 2)))
    (is (= 3 (fol.compiler.collections:collection-size s2)))
    ;; Returns the same object when element already present
    (is (eq s s2))))

(test sorted-set-conj-on-empty
  "collection-conj on an empty sorted set produces a single-element set."
  (let* ((s (fol.compiler.collections:sorted-set nil))
         (s2 (fol.compiler.collections:collection-conj s 42)))
    (is (= 1 (fol.compiler.collections:collection-size s2)))
    (is (equal '(42) (fol.compiler.collections:collection-seq s2)))))

(test sorted-set-custom-comparator
  "A custom comparator (reverse order) is used for sorting."
  (let* ((rev-cmp (lambda (a b)
                    (cond ((> a b) -1)
                          ((< a b)  1)
                          (t        0))))
         (s (fol.compiler.collections:sorted-set rev-cmp 1 2 3 4 5)))
    (is (equal '(5 4 3 2 1) (fol.compiler.collections:collection-seq s)))))

(test sorted-set-comparator-preserved-on-conj
  "collection-conj preserves the comparator."
  (let* ((rev-cmp (lambda (a b)
                    (cond ((> a b) -1)
                          ((< a b)  1)
                          (t        0))))
         (s (fol.compiler.collections:sorted-set rev-cmp 5 3 1))
         (s2 (fol.compiler.collections:collection-conj s 4)))
    (is (equal '(5 4 3 1) (fol.compiler.collections:collection-seq s2)))
    ;; Comparator is the same function
    (is (eq rev-cmp (fol.compiler.collections:comparator-compare s2)))))

(test sorted-set-count
  "count returns element count for a <sorted-set>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collections:sorted-set nil))))
  (is (= 3 (fol.compiler.collections:count
             (fol.compiler.collections:sorted-set nil 1 2 3)))))

(test sorted-set-empty?
  "empty? works for <sorted-set>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collections:sorted-set nil))))
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collections:sorted-set nil 1 2)))))

;;; ---------------------------------------------------------------------------
;;; <int-set> class, predicate, constructor, and protocol
;;; ---------------------------------------------------------------------------

(test int-set-class-exists
  "The <int-set> class is defined."
  (is (not (null (find-class 'fol.compiler.collections:<int-set>)))))

(test int-set-inherits-sorted-set
  "<int-set> is a subclass of <sorted-set>."
  (is (eq t (subtypep 'fol.compiler.collections:<int-set>
                       'fol.compiler.collections:<sorted-set>))))

(test int-set-inherits-set
  "<int-set> is a subclass of <set>."
  (is (eq t (subtypep 'fol.compiler.collections:<int-set>
                       'fol.compiler.collections:<set>))))

(test int-set-inherits-ordered-collection
  "<int-set> is a subclass of <ordered-collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<int-set>
                       'fol.compiler.collections:<ordered-collection>))))

(test int-set-is-collection
  "<int-set> satisfies <collection>?, <set>?, <ordered-collection>?, <sorted-set>?, <int-set>?."
  (let ((s (fol.compiler.collections:int-set 3 1 2)))
    (is (eq t (fol.compiler.collections:<collection>? s)))
    (is (eq t (fol.compiler.collections:<set>? s)))
    (is (eq t (fol.compiler.collections:<ordered-collection>? s)))
    (is (eq t (fol.compiler.collections:<sorted-set>? s)))
    (is (eq t (fol.compiler.collections:<int-set>? s)))))

(test int-set-predicate-nil
  "<int-set>? returns NIL for non-int-sets."
  (is (null (fol.compiler.collections:<int-set>? 42)))
  (is (null (fol.compiler.collections:<int-set>? nil)))
  ;; A plain <sorted-set> is NOT an <int-set>
  (is (null (fol.compiler.collections:<int-set>?
             (fol.compiler.collections:sorted-set nil 1 2 3)))))

(test int-set-predicate-true
  "<int-set>? returns T for an <int-set> instance."
  (let ((s (fol.compiler.collections:int-set 1 2 3)))
    (is (eq t (fol.compiler.collections:<int-set>? s)))))

(test int-set-make-empty
  "(int-set) creates an empty int set."
  (let ((s (fol.compiler.collections:int-set)))
    (is (= 0 (fol.compiler.collections:collection-size s)))
    (is (eq t (fol.compiler.collections:collection-empty-p s)))
    (is (null (fol.compiler.collections:collection-seq s)))))

(test int-set-make-with-elements
  "(int-set 5 3 1) creates a populated int set."
  (let ((s (fol.compiler.collections:int-set 5 3 1)))
    (is (= 3 (fol.compiler.collections:collection-size s)))))

(test int-set-sorts-elements
  "collection-seq returns elements in numeric order."
  (let ((s (fol.compiler.collections:int-set 5 3 1 4 2)))
    (is (equal '(1 2 3 4 5) (fol.compiler.collections:collection-seq s)))))

(test int-set-deduplicates
  "Duplicate elements are silently dropped."
  (let ((s (fol.compiler.collections:int-set 3 1 2 2 3 1)))
    (is (= 3 (fol.compiler.collections:collection-size s)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq s)))))

(test int-set-conj-inserts-in-order
  "collection-conj inserts in numeric order."
  (let* ((s (fol.compiler.collections:int-set 1 3 5))
         (s2 (fol.compiler.collections:collection-conj s 2)))
    (is (= 4 (fol.compiler.collections:collection-size s2)))
    (is (equal '(1 2 3 5) (fol.compiler.collections:collection-seq s2)))
    ;; Original unchanged
    (is (= 3 (fol.compiler.collections:collection-size s)))))

(test int-set-conj-deduplicates
  "collection-conj does not add duplicate elements."
  (let* ((s (fol.compiler.collections:int-set 1 2 3))
         (s2 (fol.compiler.collections:collection-conj s 2)))
    (is (= 3 (fol.compiler.collections:collection-size s2)))
    ;; Returns the same object when element already present
    (is (eq s s2))))

(test int-set-conj-on-empty
  "collection-conj on an empty int set produces a single-element set."
  (let* ((s (fol.compiler.collections:int-set))
         (s2 (fol.compiler.collections:collection-conj s 42)))
    (is (= 1 (fol.compiler.collections:collection-size s2)))
    (is (equal '(42) (fol.compiler.collections:collection-seq s2)))))

(test int-set-conj-preserves-type
  "collection-conj on an <int-set> returns an <int-set>, not a <sorted-set>."
  (let* ((s (fol.compiler.collections:int-set 1 2))
         (s2 (fol.compiler.collections:collection-conj s 3)))
    (is (eq t (fol.compiler.collections:<int-set>? s2)))))

(test int-set-count
  "count returns element count for an <int-set>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collections:int-set))))
  (is (= 3 (fol.compiler.collections:count
             (fol.compiler.collections:int-set 1 2 3)))))

(test int-set-empty?
  "empty? works for <int-set>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collections:int-set))))
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collections:int-set 1 2)))))

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

(test dense-int-set-inherits-collection-storage
  "<dense-int-set> is a subclass of <collection-storage>."
  (is (eq t (subtypep 'fol.compiler.collections:<dense-int-set>
                       'fol.compiler.collections:<collection-storage>))))

(test dense-int-set-inherits-collection
  "<dense-int-set> is a subclass of <collection>."
  (is (eq t (subtypep 'fol.compiler.collections:<dense-int-set>
                       'fol.compiler.collections:<collection>))))

(test dense-int-set-is-collection
  "<dense-int-set> satisfies <collection>?, <ordered-collection>?, <dense-int-set>?."
  (let ((s (fol.compiler.collections:dense-int-set 3 1 2)))
    (is (eq t (fol.compiler.collections:<collection>? s)))
    (is (eq t (fol.compiler.collections:<ordered-collection>? s)))
    (is (eq t (fol.compiler.collections:<dense-int-set>? s)))))

(test dense-int-set-predicate-nil
  "<dense-int-set>? returns NIL for non-dense-int-sets."
  (is (null (fol.compiler.collections:<dense-int-set>? 42)))
  (is (null (fol.compiler.collections:<dense-int-set>? nil)))
  ;; A plain <int-set> is NOT a <dense-int-set>
  (is (null (fol.compiler.collections:<dense-int-set>?
             (fol.compiler.collections:int-set 1 2 3)))))

(test dense-int-set-predicate-true
  "<dense-int-set>? returns T for a <dense-int-set> instance."
  (let ((s (fol.compiler.collections:dense-int-set 1 2 3)))
    (is (eq t (fol.compiler.collections:<dense-int-set>? s)))))

(test dense-int-set-make-empty
  "(dense-int-set) creates an empty dense int set."
  (let ((s (fol.compiler.collections:dense-int-set)))
    (is (= 0 (fol.compiler.collections:collection-size s)))
    (is (eq t (fol.compiler.collections:collection-empty-p s)))
    (is (null (fol.compiler.collections:collection-seq s)))))

(test dense-int-set-make-with-elements
  "(dense-int-set 5 3 1) creates a populated dense int set."
  (let ((s (fol.compiler.collections:dense-int-set 5 3 1)))
    (is (= 3 (fol.compiler.collections:collection-size s)))))

(test dense-int-set-sorted-seq
  "collection-seq returns elements in numeric order."
  (let ((s (fol.compiler.collections:dense-int-set 5 3 1 4 2)))
    (is (equal '(1 2 3 4 5) (fol.compiler.collections:collection-seq s)))))

(test dense-int-set-deduplicates
  "Duplicate elements are silently dropped."
  (let ((s (fol.compiler.collections:dense-int-set 3 1 2 2 3 1)))
    (is (= 3 (fol.compiler.collections:collection-size s)))
    (is (equal '(1 2 3) (fol.compiler.collections:collection-seq s)))))

(test dense-int-set-conj-within-range
  "collection-conj adds an element within the existing range."
  (let* ((s (fol.compiler.collections:dense-int-set 1 3 5))
         (s2 (fol.compiler.collections:collection-conj s 2)))
    (is (= 4 (fol.compiler.collections:collection-size s2)))
    (is (equal '(1 2 3 5) (fol.compiler.collections:collection-seq s2)))
    ;; Original unchanged
    (is (= 3 (fol.compiler.collections:collection-size s)))))

(test dense-int-set-conj-extends-right
  "collection-conj extends the bit-vector when element is above range."
  (let* ((s (fol.compiler.collections:dense-int-set 1 2 3))
         (s2 (fol.compiler.collections:collection-conj s 10)))
    (is (= 4 (fol.compiler.collections:collection-size s2)))
    (is (equal '(1 2 3 10) (fol.compiler.collections:collection-seq s2)))))

(test dense-int-set-conj-extends-left
  "collection-conj extends the bit-vector when element is below range."
  (let* ((s (fol.compiler.collections:dense-int-set 5 6 7))
         (s2 (fol.compiler.collections:collection-conj s 2)))
    (is (= 4 (fol.compiler.collections:collection-size s2)))
    (is (equal '(2 5 6 7) (fol.compiler.collections:collection-seq s2)))))

(test dense-int-set-conj-deduplicates
  "collection-conj does not add duplicate elements."
  (let* ((s (fol.compiler.collections:dense-int-set 1 2 3))
         (s2 (fol.compiler.collections:collection-conj s 2)))
    (is (= 3 (fol.compiler.collections:collection-size s2)))
    ;; Returns the same object when element already present
    (is (eq s s2))))

(test dense-int-set-conj-on-empty
  "collection-conj on an empty dense int set produces a single-element set."
  (let* ((s (fol.compiler.collections:dense-int-set))
         (s2 (fol.compiler.collections:collection-conj s 42)))
    (is (= 1 (fol.compiler.collections:collection-size s2)))
    (is (equal '(42) (fol.compiler.collections:collection-seq s2)))))

(test dense-int-set-offset-tracking
  "dense-int-set-offset tracks the minimum element."
  (let ((s (fol.compiler.collections:dense-int-set 10 20 15)))
    (is (= 10 (fol.compiler.collections:dense-int-set-offset s)))))

(test dense-int-set-storage-is-bit-vector
  "storage-items returns a CL bit-vector."
  (let ((s (fol.compiler.collections:dense-int-set 1 2 3)))
    (is (typep (fol.compiler.collections:storage-items s) 'bit-vector))))

(test dense-int-set-count
  "count returns element count for a <dense-int-set>."
  (is (= 0 (fol.compiler.collections:count
             (fol.compiler.collections:dense-int-set))))
  (is (= 3 (fol.compiler.collections:count
             (fol.compiler.collections:dense-int-set 1 2 3)))))

(test dense-int-set-empty?
  "empty? works for <dense-int-set>."
  (is (eq t (fol.compiler.collections:empty?
             (fol.compiler.collections:dense-int-set))))
  (is (null (fol.compiler.collections:empty?
             (fol.compiler.collections:dense-int-set 1 2)))))

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
