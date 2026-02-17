;;; FOL Compiler - Primitive Functions Tests
;;;
;;; Tests for primitive-functions.lisp

(in-package :fol.compiler.tests)
(in-suite primitive-functions-tests)

;;; ---------------------------------------------------------------------------
;;; Symbol Construction Tests
;;; ---------------------------------------------------------------------------

(test test-symbol
  "Test symbol creation from strings."
  (is (eq 'foo (fol.compiler.primitive-functions:symbol "foo")))
  (is (eq 'bar (fol.compiler.primitive-functions:symbol "bar")))
  (is (eq 'baz (fol.compiler.primitive-functions:symbol 'baz))))

(test test-keyword
  "Test keyword creation from strings."
  (is (eq :foo (fol.compiler.primitive-functions:keyword "foo")))
  (is (eq :bar (fol.compiler.primitive-functions:keyword "bar")))
  (is (eq :baz (fol.compiler.primitive-functions:keyword 'baz))))

(test test-find-keyword-from-string
  "Test find-keyword with string input."
  (is (eq :foo (fol.compiler.primitive-functions:find-keyword "foo")))
  (is (eq :bar (fol.compiler.primitive-functions:find-keyword "bar")))
  (is (eq :test (fol.compiler.primitive-functions:find-keyword "test"))))

(test test-find-keyword-from-symbol
  "Test find-keyword with symbol input."
  (is (eq :foo (fol.compiler.primitive-functions:find-keyword 'foo)))
  (is (eq :bar (fol.compiler.primitive-functions:find-keyword 'bar)))
  (is (eq :test (fol.compiler.primitive-functions:find-keyword 'test))))

(test test-find-keyword-from-keyword
  "Test find-keyword with keyword input (idempotent)."
  (is (eq :foo (fol.compiler.primitive-functions:find-keyword :foo)))
  (is (eq :bar (fol.compiler.primitive-functions:find-keyword :bar)))
  (is (eq :test (fol.compiler.primitive-functions:find-keyword :test))))

(test test-gensym-default
  "Test gensym with default prefix."
  (let ((sym1 (fol.compiler.primitive-functions:gensym))
        (sym2 (fol.compiler.primitive-functions:gensym)))
    (is (symbolp sym1))
    (is (symbolp sym2))
    (is (not (eq sym1 sym2)))  ; Each call returns unique symbol
    (is (null (symbol-package sym1)))  ; Uninterned
    (is (null (symbol-package sym2)))))

(test test-gensym-with-string-prefix
  "Test gensym with string prefix."
  (let ((sym1 (fol.compiler.primitive-functions:gensym "X"))
        (sym2 (fol.compiler.primitive-functions:gensym "Y")))
    (is (symbolp sym1))
    (is (symbolp sym2))
    (is (not (eq sym1 sym2)))
    (is (null (symbol-package sym1)))
    (is (null (symbol-package sym2)))
    ;; Check prefix is in symbol name
    (is (search "X" (symbol-name sym1)))
    (is (search "Y" (symbol-name sym2)))))

(test test-gensym-with-symbol-prefix
  "Test gensym with symbol prefix."
  (let ((sym (fol.compiler.primitive-functions:gensym 'temp)))
    (is (symbolp sym))
    (is (null (symbol-package sym)))
    (is (search "TEMP" (symbol-name sym)))))

(test test-gensym-uniqueness
  "Test that gensym generates unique symbols across multiple calls."
  (let ((syms (loop repeat 100
                    collect (fol.compiler.primitive-functions:gensym))))
    ;; All symbols should be distinct
    (is (= 100 (length (remove-duplicates syms))))))

;;; ---------------------------------------------------------------------------
;;; map-entry? Tests
;;; ---------------------------------------------------------------------------

(test map-entry?-cons-pair
  "map-entry? returns T for cons pairs (dict entries)."
  (is (eq t (fol.compiler.primitive-functions:map-entry? (cons :a 1))))
  (is (eq t (fol.compiler.primitive-functions:map-entry? (cons "name" 42))))
  (is (eq t (fol.compiler.primitive-functions:map-entry? (cons 1 2)))))

(test map-entry?-dict-seq-entries
  "map-entry? returns T for entries from dict collection-seq."
  (let* ((d (fol.compiler.collection-functions:dict :a 1 :b 2))
         (entries (fol.compiler.collections:collection-seq d)))
    (dolist (entry entries)
      (is (eq t (fol.compiler.primitive-functions:map-entry? entry))))))

(test map-entry?-vector-false
  "map-entry? returns NIL for vectors."
  (is (null (fol.compiler.primitive-functions:map-entry?
              (fol.compiler.collection-functions:vector 1 2)))))

(test map-entry?-number-false
  "map-entry? returns NIL for numbers."
  (is (null (fol.compiler.primitive-functions:map-entry? 42)))
  (is (null (fol.compiler.primitive-functions:map-entry? 3.14))))

(test map-entry?-string-false
  "map-entry? returns NIL for strings."
  (is (null (fol.compiler.primitive-functions:map-entry? "hello"))))

(test map-entry?-nil-false
  "map-entry? returns NIL for nil."
  (is (null (fol.compiler.primitive-functions:map-entry? nil))))

(test map-entry?-keyword-false
  "map-entry? returns NIL for keywords."
  (is (null (fol.compiler.primitive-functions:map-entry? :foo))))

(test map-entry?-cl-list-elements
  "map-entry? returns T for cons cells in CL lists (they are cons pairs)."
  (is (eq t (fol.compiler.primitive-functions:map-entry? '(1 2 3)))))

;;; ---------------------------------------------------------------------------
;;; Collection Category Predicate Tests
;;; ---------------------------------------------------------------------------

;;; --- sequential? ---

(test sequential?-vector
  "sequential? returns T for vectors."
  (is (eq t (fol.compiler.primitive-functions:sequential?
              (fol.compiler.collection-functions:vector 1 2 3)))))

(test sequential?-list
  "sequential? returns T for FOL lists."
  (is (eq t (fol.compiler.primitive-functions:sequential?
              (fol.compiler.collection-functions:list 1 2 3)))))

(test sequential?-deque
  "sequential? returns T for deques."
  (is (eq t (fol.compiler.primitive-functions:sequential?
              (fol.compiler.collection-functions:deque 1 2 3)))))

(test sequential?-lazy-seq
  "sequential? returns T for lazy sequences."
  (is (eq t (fol.compiler.primitive-functions:sequential?
              (fol.compiler.collection-functions:lazy-seq
                (lambda () (fol.compiler.collection-functions:vector 1)))))))

(test sequential?-dict-false
  "sequential? returns NIL for dicts."
  (is (null (fol.compiler.primitive-functions:sequential?
              (fol.compiler.collection-functions:dict :a 1)))))

(test sequential?-set-false
  "sequential? returns NIL for sets."
  (is (null (fol.compiler.primitive-functions:sequential?
              (fol.compiler.collection-functions:set 1 2 3)))))

(test sequential?-non-collection-false
  "sequential? returns NIL for non-collections."
  (is (null (fol.compiler.primitive-functions:sequential? 42)))
  (is (null (fol.compiler.primitive-functions:sequential? "hello")))
  (is (null (fol.compiler.primitive-functions:sequential? nil))))

;;; --- associative? ---

(test associative?-vector
  "associative? returns T for vectors."
  (is (eq t (fol.compiler.primitive-functions:associative?
              (fol.compiler.collection-functions:vector 1 2 3)))))

(test associative?-dict
  "associative? returns T for dicts."
  (is (eq t (fol.compiler.primitive-functions:associative?
              (fol.compiler.collection-functions:dict :a 1)))))

(test associative?-ordered-dict
  "associative? returns T for ordered-dicts."
  (is (eq t (fol.compiler.primitive-functions:associative?
              (fol.compiler.collection-functions:ordered-dict :a 1)))))

(test associative?-sorted-dict
  "associative? returns T for sorted-dicts."
  (is (eq t (fol.compiler.primitive-functions:associative?
              (fol.compiler.collection-functions:sorted-dict nil 1 :a)))))

(test associative?-set-false
  "associative? returns NIL for sets."
  (is (null (fol.compiler.primitive-functions:associative?
              (fol.compiler.collection-functions:set 1 2 3)))))

(test associative?-list-false
  "associative? returns NIL for FOL lists."
  (is (null (fol.compiler.primitive-functions:associative?
              (fol.compiler.collection-functions:list 1 2 3)))))

(test associative?-non-collection-false
  "associative? returns NIL for non-collections."
  (is (null (fol.compiler.primitive-functions:associative? 42)))
  (is (null (fol.compiler.primitive-functions:associative? nil))))

;;; --- sorted? ---

(test sorted?-sorted-dict
  "sorted? returns T for sorted-dicts."
  (is (eq t (fol.compiler.primitive-functions:sorted?
              (fol.compiler.collection-functions:sorted-dict nil 1 :a)))))

(test sorted?-int-dict
  "sorted? returns T for int-dicts (subtype of sorted-dict)."
  (is (eq t (fol.compiler.primitive-functions:sorted?
              (fol.compiler.collection-functions:int-dict 1 :a 2 :b)))))

(test sorted?-sorted-set
  "sorted? returns T for sorted-sets."
  (is (eq t (fol.compiler.primitive-functions:sorted?
              (fol.compiler.collection-functions:sorted-set nil 1 2 3)))))

(test sorted?-int-set
  "sorted? returns T for int-sets (subtype of sorted-set)."
  (is (eq t (fol.compiler.primitive-functions:sorted?
              (fol.compiler.collection-functions:int-set 1 2 3)))))

(test sorted?-dict-false
  "sorted? returns NIL for plain dicts."
  (is (null (fol.compiler.primitive-functions:sorted?
              (fol.compiler.collection-functions:dict :a 1)))))

(test sorted?-set-false
  "sorted? returns NIL for plain sets."
  (is (null (fol.compiler.primitive-functions:sorted?
              (fol.compiler.collection-functions:set 1 2 3)))))

(test sorted?-vector-false
  "sorted? returns NIL for vectors."
  (is (null (fol.compiler.primitive-functions:sorted?
              (fol.compiler.collection-functions:vector 1 2 3)))))

(test sorted?-non-collection-false
  "sorted? returns NIL for non-collections."
  (is (null (fol.compiler.primitive-functions:sorted? 42)))
  (is (null (fol.compiler.primitive-functions:sorted? nil))))

;;; --- counted? ---

(test counted?-vector
  "counted? returns T for vectors."
  (is (eq t (fol.compiler.primitive-functions:counted?
              (fol.compiler.collection-functions:vector 1 2 3)))))

(test counted?-dict
  "counted? returns T for dicts."
  (is (eq t (fol.compiler.primitive-functions:counted?
              (fol.compiler.collection-functions:dict :a 1)))))

(test counted?-set
  "counted? returns T for sets."
  (is (eq t (fol.compiler.primitive-functions:counted?
              (fol.compiler.collection-functions:set 1 2 3)))))

(test counted?-list
  "counted? returns T for FOL lists."
  (is (eq t (fol.compiler.primitive-functions:counted?
              (fol.compiler.collection-functions:list 1 2 3)))))

(test counted?-bag
  "counted? returns T for bags."
  (is (eq t (fol.compiler.primitive-functions:counted?
              (fol.compiler.collection-functions:bag 1 1 2)))))

(test counted?-non-collection-false
  "counted? returns NIL for non-collections."
  (is (null (fol.compiler.primitive-functions:counted? 42)))
  (is (null (fol.compiler.primitive-functions:counted? "hello")))
  (is (null (fol.compiler.primitive-functions:counted? nil))))

;;; --- reversible? ---

(test reversible?-vector
  "reversible? returns T for vectors."
  (is (eq t (fol.compiler.primitive-functions:reversible?
              (fol.compiler.collection-functions:vector 1 2 3)))))

(test reversible?-sorted-dict
  "reversible? returns T for sorted-dicts."
  (is (eq t (fol.compiler.primitive-functions:reversible?
              (fol.compiler.collection-functions:sorted-dict nil 1 :a)))))

(test reversible?-int-dict
  "reversible? returns T for int-dicts."
  (is (eq t (fol.compiler.primitive-functions:reversible?
              (fol.compiler.collection-functions:int-dict 1 :a 2 :b)))))

(test reversible?-sorted-set
  "reversible? returns T for sorted-sets."
  (is (eq t (fol.compiler.primitive-functions:reversible?
              (fol.compiler.collection-functions:sorted-set nil 1 2 3)))))

(test reversible?-int-set
  "reversible? returns T for int-sets."
  (is (eq t (fol.compiler.primitive-functions:reversible?
              (fol.compiler.collection-functions:int-set 1 2 3)))))

(test reversible?-dict-false
  "reversible? returns NIL for plain dicts."
  (is (null (fol.compiler.primitive-functions:reversible?
              (fol.compiler.collection-functions:dict :a 1)))))

(test reversible?-set-false
  "reversible? returns NIL for plain sets."
  (is (null (fol.compiler.primitive-functions:reversible?
              (fol.compiler.collection-functions:set 1 2 3)))))

(test reversible?-list-false
  "reversible? returns NIL for FOL lists."
  (is (null (fol.compiler.primitive-functions:reversible?
              (fol.compiler.collection-functions:list 1 2 3)))))

(test reversible?-non-collection-false
  "reversible? returns NIL for non-collections."
  (is (null (fol.compiler.primitive-functions:reversible? 42)))
  (is (null (fol.compiler.primitive-functions:reversible? nil))))
