;;; FOL Compiler Tests - Replace Function
;;;
;;; Tests for the unified fol.compiler.merged-functions:replace

(in-package :fol.compiler.tests)

(def-suite replace-tests
           :description "Tests for the polymorphic replace function."
           :in compiler-tests)

(in-suite replace-tests)

;;; ---------------------------------------------------------------------------
;;; String Replacement Tests
;;; ---------------------------------------------------------------------------

(test replace-character
  "replace can replace a character with a string."
  (is (string= "hXllo"
               (fol.compiler.merged-functions:replace "hello" #\e "X"))))

(test replace-string-literal
  "replace can replace a literal string."
  (is (string= "hello FOL"
               (fol.compiler.merged-functions:replace "hello world" "world" "FOL"))))

(test replace-string-regex
  "replace can use regex patterns."
  (is (string= "aXbXcX"
               (fol.compiler.merged-functions:replace "a1b2c3" "\\d" "X" :use-regex t))))

(test replace-all-occurrences
  "replace replaces all occurrences."
  (is (string= "XXX"
               (fol.compiler.merged-functions:replace "aaa" #\a "X"))))

(test replace-character-regex
  "replace handles character match with :use-regex t by converting to string.
   '.' matches any character in regex."
  (is (string= "XXXXX"
               (fol.compiler.merged-functions:replace "a.b.c" #\. "X" :use-regex t))))

;;; ---------------------------------------------------------------------------
;;; Collection Replacement Tests
;;; ---------------------------------------------------------------------------

(test replace-vector-elements
  "replace replaces elements in a vector based on a dict map."
  (let* ((v (fol.compiler.collection-functions:vector 1 2 3 4 5))
         (repl-map (fol.compiler.collection-functions:dict 2 :two 4 :four))
         (result (fol.compiler.merged-functions:replace repl-map v)))
    (is (fol.compiler.primitive-functions:<vector>? result))
    (is (= 5 (fol.compiler.collection-functions:size result)))
    (is (equal :two (fol.compiler.collection-functions:nth result 1)))
    (is (equal :four (fol.compiler.collection-functions:nth result 3)))
    (is (= 1 (fol.compiler.collection-functions:nth result 0)))
    (is (= 3 (fol.compiler.collection-functions:nth result 2)))))

(test replace-list-elements
  "replace replaces elements in a list based on a dict map."
  (let* ((l (fol.compiler.collection-functions:list 1 2 3 4 5))
         (repl-map (fol.compiler.collection-functions:dict 1 :one 5 :five))
         (result (fol.compiler.merged-functions:replace repl-map l)))
    (is (fol.compiler.primitive-functions:<list>? result))
    (is (equal :one (fol.compiler.collection-functions:first result)))
    (is (equal :five (fol.compiler.collection-functions:nth result 4)))))

(test replace-deque-elements
  "replace replaces elements in a deque based on a dict map."
  (let* ((d (fol.compiler.collection-functions:deque 1 2 3))
         (repl-map (fol.compiler.collection-functions:dict 2 :two))
         (result (fol.compiler.merged-functions:replace repl-map d)))
    (is (fol.compiler.primitive-functions:<deque>? result))
    (is (equal :two (fol.compiler.collection-functions:nth result 1)))))

(test replace-preserves-type
  "replace preserves the specific collection type."
  (let* ((v (fol.compiler.collection-functions:vector 1))
         (l (fol.compiler.collection-functions:list 1))
         (m (fol.compiler.collection-functions:dict 1 :one)))
    (is (typep (fol.compiler.merged-functions:replace m v) 'fol.compiler.collections:<vector>))
    (is (typep (fol.compiler.merged-functions:replace m l) 'fol.compiler.collections:<list>))))

;;; ---------------------------------------------------------------------------
;;; Error Handling Tests
;;; ---------------------------------------------------------------------------

(test replace-invalid-args
  "replace errors on invalid arguments."
  (signals error
    (fol.compiler.merged-functions:replace "hello" "e")) ; Missing replacement
  (signals error
    (fol.compiler.merged-functions:replace (fol.compiler.collection-functions:dict) "not-a-collection")))
