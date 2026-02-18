;;; FOL Compiler - Relational Tests

(in-package :fol.compiler.tests)
(in-suite relational-tests)

(test union-test
  (let ((s1 (fol.compiler.collection-functions:set 1 2 3))
        (s2 (fol.compiler.collection-functions:set 3 4 5)))
    (is (fol.compiler.collection-functions:contains? (fol.compiler.collection-functions:union s1 s2) 1))
    (is (fol.compiler.collection-functions:contains? (fol.compiler.collection-functions:union s1 s2) 5))
    (is (= 5 (fol.compiler.collection-functions:size (fol.compiler.collection-functions:union s1 s2))))))

(test difference-test
  (let ((s1 (fol.compiler.collection-functions:set 1 2 3))
        (s2 (fol.compiler.collection-functions:set 3 4 5)))
    (let ((diff (fol.compiler.collection-functions:difference s1 s2)))
      (is (fol.compiler.collection-functions:contains? diff 1))
      (is (fol.compiler.collection-functions:contains? diff 2))
      (is (not (fol.compiler.collection-functions:contains? diff 3)))
      (is (= 2 (fol.compiler.collection-functions:size diff))))))

(test intersection-test
  (let ((s1 (fol.compiler.collection-functions:set 1 2 3))
        (s2 (fol.compiler.collection-functions:set 3 4 5)))
    (let ((inter (fol.compiler.collection-functions:intersection s1 s2)))
      (is (fol.compiler.collection-functions:contains? inter 3))
      (is (not (fol.compiler.collection-functions:contains? inter 1)))
      (is (= 1 (fol.compiler.collection-functions:size inter))))))

(test select-test
  (let ((s (fol.compiler.collection-functions:set 1 2 3 4)))
    (let ((res (fol.compiler.collection-functions:select #'evenp s)))
      (is (fol.compiler.collection-functions:contains? res 2))
      (is (fol.compiler.collection-functions:contains? res 4))
      (is (= 2 (fol.compiler.collection-functions:size res))))))

(test project-test
  (let ((data (fol.compiler.collection-functions:set
               (fol.compiler.collection-functions:dict :a 1 :b 2)
               (fol.compiler.collection-functions:dict :a 2 :c 3))))
    (let ((res (fol.compiler.relational:project data (fol.compiler.collection-functions:vector :a))))
      (is (= 2 (fol.compiler.collection-functions:size res)))
      (let ((l (fol.compiler.seq-functions:into (fol.compiler.collection-functions:list) res)))
        (is (some (lambda (d) (= 1 (fol.compiler.collection-functions:get d :a))) (fol.compiler.collections:collection-seq l)))
        (is (some (lambda (d) (= 2 (fol.compiler.collection-functions:get d :a))) (fol.compiler.collections:collection-seq l)))))))

(test rename-test
  (let ((data (fol.compiler.collection-functions:set
               (fol.compiler.collection-functions:dict :a 1 :b 2))))
    (let ((res (fol.compiler.relational:rename data (fol.compiler.collection-functions:dict :a :new-a))))
      (let ((item (fol.compiler.collection-functions:first res)))
        (is (= 1 (fol.compiler.collection-functions:get item :new-a)))
        (is (= 2 (fol.compiler.collection-functions:get item :b)))
        (is (not (fol.compiler.collection-functions:get item :a)))))))

(test index-test
  (let ((data (fol.compiler.collection-functions:set
               (fol.compiler.collection-functions:dict :id 1 :val "a")
               (fol.compiler.collection-functions:dict :id 2 :val "b")
               (fol.compiler.collection-functions:dict :id 1 :val "c"))))
    (let ((idx (fol.compiler.relational:index data (fol.compiler.collection-functions:vector :id))))
      (let ((group1 (fol.compiler.collection-functions:get idx (fol.compiler.collection-functions:dict :id 1))))
        (is (= 2 (fol.compiler.collection-functions:size group1)))))))

(test join-test
  (let ((r1 (fol.compiler.collection-functions:set
             (fol.compiler.collection-functions:dict :id 1 :val "a")
             (fol.compiler.collection-functions:dict :id 2 :val "b")))
        (r2 (fol.compiler.collection-functions:set
             (fol.compiler.collection-functions:dict :id 1 :extra "x")
             (fol.compiler.collection-functions:dict :id 3 :extra "y"))))
    (let ((j (fol.compiler.merged-functions:join r1 r2)))
      (is (= 1 (fol.compiler.collection-functions:size j)))
      (let ((item (fol.compiler.collection-functions:first j)))
        (is (= 1 (fol.compiler.collection-functions:get item :id)))
        (is (string= "a" (fol.compiler.collection-functions:get item :val)))
        (is (string= "x" (fol.compiler.collection-functions:get item :extra)))))))

;;; ---------------------------------------------------------------------------
;;; diff Tests
;;; ---------------------------------------------------------------------------

(test diff-equal-scalars
  "diff of equal scalars returns [nil nil value]."
  (let ((result (fol.compiler.relational:diff 1 1)))
    (is (null  (fol.compiler.collection-functions:nth result 0)))
    (is (null  (fol.compiler.collection-functions:nth result 1)))
    (is (eql 1 (fol.compiler.collection-functions:nth result 2)))))

(test diff-unequal-scalars
  "diff of unequal scalars returns [a b nil]."
  (let ((result (fol.compiler.relational:diff 1 2)))
    (is (eql 1 (fol.compiler.collection-functions:nth result 0)))
    (is (eql 2 (fol.compiler.collection-functions:nth result 1)))
    (is (null  (fol.compiler.collection-functions:nth result 2)))))

(test diff-equal-strings
  "diff of equal strings returns [nil nil value]."
  (let ((result (fol.compiler.relational:diff "hello" "hello")))
    (is (null        (fol.compiler.collection-functions:nth result 0)))
    (is (null        (fol.compiler.collection-functions:nth result 1)))
    (is (string= "hello" (fol.compiler.collection-functions:nth result 2)))))

(test diff-dicts-identical
  "diff of identical dicts returns [nil nil dict]."
  (let* ((d      (fol.compiler.collection-functions:dict :a 1 :b 2))
         (result (fol.compiler.relational:diff d d)))
    (is (null (fol.compiler.collection-functions:nth result 0)))
    (is (null (fol.compiler.collection-functions:nth result 1)))
    (is (not  (null (fol.compiler.collection-functions:nth result 2))))))

(test diff-dicts-one-different-value
  "diff of dicts with one differing value."
  (let* ((a      (fol.compiler.collection-functions:dict :a 1 :b 2))
         (b      (fol.compiler.collection-functions:dict :a 1 :b 3))
         (result (fol.compiler.relational:diff a b))
         (a-only (fol.compiler.collection-functions:nth result 0))
         (b-only (fol.compiler.collection-functions:nth result 1))
         (both   (fol.compiler.collection-functions:nth result 2)))
    (is (not (null a-only)))
    (is (eql 2 (fol.compiler.collection-functions:get a-only :b)))
    (is (not (null b-only)))
    (is (eql 3 (fol.compiler.collection-functions:get b-only :b)))
    (is (not (null both)))
    (is (eql 1 (fol.compiler.collection-functions:get both :a)))))

(test diff-dicts-disjoint-keys
  "diff of dicts with no shared keys."
  (let* ((a      (fol.compiler.collection-functions:dict :a 1))
         (b      (fol.compiler.collection-functions:dict :b 2))
         (result (fol.compiler.relational:diff a b))
         (a-only (fol.compiler.collection-functions:nth result 0))
         (b-only (fol.compiler.collection-functions:nth result 1))
         (both   (fol.compiler.collection-functions:nth result 2)))
    (is (not (null a-only)))
    (is (eql 1 (fol.compiler.collection-functions:get a-only :a)))
    (is (not (null b-only)))
    (is (eql 2 (fol.compiler.collection-functions:get b-only :b)))
    (is (null both))))

(test diff-sets
  "diff of two sets returns correctly categorised elements."
  (let* ((a      (fol.compiler.collection-functions:set 1 2 3))
         (b      (fol.compiler.collection-functions:set 1 2 4))
         (result (fol.compiler.relational:diff a b))
         (a-only (fol.compiler.collection-functions:nth result 0))
         (b-only (fol.compiler.collection-functions:nth result 1))
         (both   (fol.compiler.collection-functions:nth result 2)))
    (is (fol.compiler.collection-functions:contains? a-only 3))
    (is (not (fol.compiler.collection-functions:contains? a-only 1)))
    (is (fol.compiler.collection-functions:contains? b-only 4))
    (is (not (fol.compiler.collection-functions:contains? b-only 1)))
    (is (fol.compiler.collection-functions:contains? both 1))
    (is (fol.compiler.collection-functions:contains? both 2))
    (is (not (fol.compiler.collection-functions:contains? both 3)))))

(test diff-sets-identical
  "diff of identical sets returns [nil nil set]."
  (let* ((s      (fol.compiler.collection-functions:set 1 2 3))
         (result (fol.compiler.relational:diff s s)))
    (is (null (fol.compiler.collection-functions:nth result 0)))
    (is (null (fol.compiler.collection-functions:nth result 1)))
    (is (not  (null (fol.compiler.collection-functions:nth result 2))))))

(test diff-result-is-fol-vector
  "diff result is a FOL vector with three elements."
  (let ((result (fol.compiler.relational:diff 1 2)))
    (is (typep result 'fol.compiler.collections:<vector>))
    (is (= 3 (fol.compiler.collection-functions:size result)))))
