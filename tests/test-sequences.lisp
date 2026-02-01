(in-package :fol.integration-tests)

(def-suite sequences-suite :in integration-suite)
(def-suite* :sequences-tests :in sequences-suite)

;;; ---------------------------------------------------------------------------
;;; Map, Filter, Reduce
;;; ---------------------------------------------------------------------------

(test map-function
  "Test map function."
  (fol-is 2 "(first (map inc [1 2 3]))")
  (fol-is 3 "(second (map inc [1 2 3]))")
  (fol-is 4 "(third (map inc [1 2 3]))"))

(test filter-function
  "Test filter function."
  (fol-is '(2 4) "(into [] (filter even? [1 2 3 4 5]))")
  (fol-is '(1 3 5) "(into [] (filter odd? [1 2 3 4 5]))"))

(test remove-function
  "Test remove function."
  (fol-is '(1 3 5) "(into [] (remove even? [1 2 3 4 5]))")
  (fol-is '(2 4) "(into [] (remove odd? [1 2 3 4 5]))"))

(test reduce-function
  "Test reduce function."
  (fol-is 15 "(reduce + [1 2 3 4 5])")
  (fol-is 25 "(reduce + 10 [1 2 3 4 5])")
  (fol-is 120 "(reduce * [1 2 3 4 5])")
  (fol-is 0 "(reduce + 0 [])"))

(test keep-function
  "Test keep function."
  (fol-is '(1 3 5) "(into [] (keep (fn [x] (if (odd? x) x nil)) [1 2 3 4 5]))"))

(test mapcat-function
  "Test mapcat function."
  (fol-is '(1 1 2 2 3 3) "(into [] (mapcat (fn [x] (vector x x)) [1 2 3]))"))

;;; ---------------------------------------------------------------------------
;;; Sequence Access
;;; ---------------------------------------------------------------------------

(test first-rest-functions
  "Test first and rest functions."
  (fol-is 1 "(first [1 2 3])")
  (fol-is '(2 3) "(into [] (rest [1 2 3]))")
  (fol-is nil "(first [])")
  (fol-is nil "(first nil)"))

(test second-third-functions
  "Test second and third functions."
  (fol-is 2 "(second [1 2 3])")
  (fol-is 3 "(third [1 2 3])")
  (fol-is nil "(second [1])")
  (fol-is nil "(third [1 2])"))

(test nth-function
  "Test nth function."
  (fol-is 1 "(nth [1 2 3] 0)")
  (fol-is 2 "(nth [1 2 3] 1)")
  (fol-is 3 "(nth [1 2 3] 2)")
  ;; nth returns nil for out of bounds
  (fol-is nil "(nth [1 2 3] 10)"))

(test last-function
  "Test last function."
  (fol-is 3 "(last [1 2 3])")
  (fol-is 1 "(last [1])")
  (fol-is nil "(last [])"))

;;; ---------------------------------------------------------------------------
;;; Take and Drop
;;; ---------------------------------------------------------------------------

(test take-function
  "Test take function."
  (fol-is '(1 2 3) "(into [] (take 3 [1 2 3 4 5]))")
  (fol-is '(1 2) "(into [] (take 2 [1 2 3]))")
  (fol-is '(1 2 3) "(into [] (take 5 [1 2 3]))"))

(test drop-function
  "Test drop function."
  (fol-is '(4 5) "(into [] (drop 3 [1 2 3 4 5]))")
  (fol-is '(3) "(into [] (drop 2 [1 2 3]))")
  (fol-is nil "(into [] (drop 5 [1 2 3]))"))

(test take-while-function
  "Test take-while function."
  (fol-is '(1 2 3) "(into [] (take-while (fn [x] (< x 4)) [1 2 3 4 5]))"))

(test drop-while-function
  "Test drop-while function."
  (fol-is '(4 5) "(into [] (drop-while (fn [x] (< x 4)) [1 2 3 4 5]))"))

;;; ---------------------------------------------------------------------------
;;; Sequence Generators
;;; ---------------------------------------------------------------------------

(test range-function
  "Test range function."
  (fol-is '(0 1 2 3 4) "(into [] (take 5 (range)))")
  (fol-is '(0 1 2 3 4) "(into [] (range 5))")
  (fol-is '(1 2 3 4) "(into [] (range 1 5))")
  (fol-is '(0 2 4 6 8) "(into [] (range 0 10 2))"))

(test repeat-function
  "Test repeat function."
  (fol-is '(:x :x :x) "(into [] (repeat 3 :x))")
  (fol-is '(:x :x :x :x :x) "(into [] (take 5 (repeat :x)))"))

(test repeatedly-function
  "Test repeatedly function."
  (fol-is 3 "(size (into [] (repeatedly 3 (fn [] 42))))"))

(test iterate-function
  "Test iterate function."
  (fol-is '(1 2 4 8 16) "(into [] (take 5 (iterate (fn [x] (* x 2)) 1)))"))

(test cycle-function
  "Test cycle function."
  (fol-is '(1 2 3 1 2 3 1) "(into [] (take 7 (cycle [1 2 3])))"))

;;; ---------------------------------------------------------------------------
;;; Interleave and Interpose
;;; ---------------------------------------------------------------------------

(test interleave-function
  "Test interleave function."
  (fol-is '(:a 1 :b 2 :c 3) "(into [] (interleave [:a :b :c] [1 2 3]))"))

(test interpose-function
  "Test interpose function."
  (fol-is '(1 0 2 0 3) "(into [] (interpose 0 [1 2 3]))")
  (fol-is "a,b,c" "(reduce str \"\" (interpose \",\" [\"a\" \"b\" \"c\"]))"))

;;; ---------------------------------------------------------------------------
;;; Concatenation
;;; ---------------------------------------------------------------------------

(test concat-function
  "Test concat function."
  (fol-is '(1 2 3 4 5 6) "(into [] (concat [1 2 3] [4 5 6]))")
  (fol-is '(1 2 3 4 5) "(into [] (concat [1 2] [3] [4 5]))"))

;;; ---------------------------------------------------------------------------
;;; Sorting and Reversing
;;; ---------------------------------------------------------------------------

(test reverse-function
  "Test reverse function."
  (fol-is '(3 2 1) "(into [] (reverse [1 2 3]))")
  (fol-is nil "(into [] (reverse []))"))

(test sort-function
  "Test sort function."
  (fol-is '(1 1 2 3 4 5 6 9) "(into [] (sort [3 1 4 1 5 9 2 6]))")
  (fol-is '(5 4 3 2 1) "(into [] (sort > [3 1 4 5 2]))"))

;;; ---------------------------------------------------------------------------
;;; Grouping and Partitioning
;;; ---------------------------------------------------------------------------

(test group-by-function
  "Test group-by function."
  ;; Group by odd? creates a dict with keys for true/false groups
  (fol-is 2 "(size (group-by odd? [1 2 3 4 5]))"))

(test partition-function
  "Test partition function."
  (fol-is 2 "(size (into [] (partition 2 [1 2 3 4])))"))

(test partition-all-function
  "Test partition-all function."
  (fol-is 3 "(size (into [] (partition-all 2 [1 2 3 4 5])))"))

;;; ---------------------------------------------------------------------------
;;; Distinct and Dedupe
;;; ---------------------------------------------------------------------------

(test distinct-function
  "Test distinct function."
  (fol-is '(1 2 3) "(into [] (distinct [1 2 1 3 2 1]))")
  (fol-is 3 "(size (into [] (distinct [1 1 2 2 3 3])))"))

(test dedupe-function
  "Test dedupe function."
  (fol-is '(1 2 1 2) "(into [] (dedupe [1 1 2 2 1 1 2 2]))")
  (fol-is '(1 2 3) "(into [] (dedupe [1 1 1 2 2 3]))"))

;;; ---------------------------------------------------------------------------
;;; Some and Every
;;; ---------------------------------------------------------------------------

(test some-function
  "Test some function."
  (fol-is-true "(some even? [1 2 3])")
  (fol-is-false "(some even? [1 3 5])"))

;; Note: FOL uses every (not every?) and not-any (not not-any?)
(test every-function
  "Test every function."
  (fol-is-true "(every even? [2 4 6])")
  (fol-is-false "(every even? [2 3 4])"))

(test not-any-function
  "Test not-any function."
  (fol-is-true "(not-any even? [1 3 5])")
  (fol-is-false "(not-any even? [1 2 3])"))

;;; ---------------------------------------------------------------------------
;;; Into and Vec
;;; ---------------------------------------------------------------------------

(test into-function
  "Test into function."
  (fol-is-true "(<vector>? (into [] (list 1 2 3)))")
  (fol-is-true "(<list>? (into (list) [1 2 3]))")
  (fol-is 3 "(size (into [] (list 1 2 3)))"))

(test vec-function
  "Test vec function."
  (fol-is-true "(<vector>? (vec (list 1 2 3)))")
  (fol-is 3 "(size (vec (list 1 2 3)))"))
