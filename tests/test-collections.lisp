(in-package :fol.integration-tests)

(def-suite collections-suite :in integration-suite)
(def-suite* :collections-tests :in collections-suite)

;;; ---------------------------------------------------------------------------
;;; Vector Operations
;;; ---------------------------------------------------------------------------

(test vector-literals
  "Test vector literal syntax."
  (fol-is-true "(<vector>? [])")
  (fol-is-true "(<vector>? [1 2 3])")
  (fol-is 3 "(size [1 2 3])")
  (fol-is-true "(empty? [])"))

(test vector-access
  "Test vector element access."
  (fol-is 1 "(first [1 2 3])")
  (fol-is 2 "(second [1 2 3])")
  (fol-is 3 "(third [1 2 3])")
  (fol-is 2 "(nth [1 2 3] 1)")
  (fol-is 3 "(get [1 2 3] 2)"))

(test vector-conj
  "Test conj on vectors."
  (fol-is 4 "(size (conj [1 2 3] 4))")
  (fol-is 4 "(get (conj [1 2 3] 4) 3)"))

;;; ---------------------------------------------------------------------------
;;; List Operations
;;; ---------------------------------------------------------------------------

(test list-creation
  "Test list creation."
  (fol-is-true "(<list>? (list 1 2 3))")
  (fol-is 3 "(size (list 1 2 3))"))

(test list-cons
  "Test cons operation."
  (fol-is 1 "(first (cons 1 '(2 3)))")
  (fol-is 3 "(size (cons 1 '(2 3)))"))

(test list-access
  "Test list element access."
  (fol-is 1 "(first (list 1 2 3))")
  (fol-is 2 "(second (list 1 2 3))")
  (fol-is 2 "(size (rest (list 1 2 3)))"))

;;; ---------------------------------------------------------------------------
;;; Dict Operations
;;; ---------------------------------------------------------------------------

(test dict-literals
  "Test dict literal syntax."
  (fol-is-true "(<dict>? {})")
  (fol-is-true "(<dict>? {:a 1 :b 2})")
  (fol-is 2 "(size {:a 1 :b 2})")
  (fol-is-true "(empty? {})"))

(test dict-access
  "Test dict element access."
  (fol-is 1 "(get {:a 1 :b 2} :a)")
  (fol-is 2 "(get {:a 1 :b 2} :b)")
  (fol-is nil "(get {:a 1} :missing)")
  (fol-is :default "(get {:a 1} :missing :default)"))

(test dict-assoc
  "Test assoc on dicts."
  (fol-is 3 "(get (assoc {:a 1 :b 2} :c 3) :c)")
  (fol-is 10 "(get (assoc {:a 1} :a 10) :a)"))

(test dict-dissoc
  "Test dissoc on dicts."
  (fol-is 1 "(size (dissoc {:a 1 :b 2} :a))")
  (fol-is nil "(get (dissoc {:a 1 :b 2} :a) :a)"))

(test dict-keys-vals
  "Test keys and vals functions."
  (fol-is 2 "(size (into [] (keys {:a 1 :b 2})))")
  (fol-is 2 "(size (into [] (vals {:a 1 :b 2})))"))

;;; ---------------------------------------------------------------------------
;;; Set Operations
;;; ---------------------------------------------------------------------------

(test set-literals
  "Test set literal syntax."
  (fol-is-true "(<set>? #{})")
  (fol-is-true "(<set>? #{1 2 3})")
  (fol-is 3 "(size #{1 2 3})")
  (fol-is-true "(empty? #{})"))

(test set-contains
  "Test contains? on sets."
  (fol-is-true "(contains? #{1 2 3} 2)")
  (fol-is-false "(contains? #{1 2 3} 4)"))

(test set-conj-disj
  "Test conj and disj on sets."
  (fol-is 4 "(size (conj #{1 2 3} 4))")
  (fol-is 3 "(size (conj #{1 2 3} 2))")  ; No duplicate
  (fol-is 2 "(size (disj #{1 2 3} 2))"))

(test set-operations
  "Test set union, intersection, difference."
  (fol-is 4 "(size (union #{1 2} #{3 4}))")
  (fol-is 2 "(size (intersection #{1 2 3} #{2 3 4}))")
  (fol-is 1 "(size (difference #{1 2 3} #{2 3}))"))

;;; ---------------------------------------------------------------------------
;;; Collection Predicates
;;; ---------------------------------------------------------------------------

(test collection-predicates
  "Test collection type predicates."
  (fol-is-true "(<collection>? [1 2 3])")
  (fol-is-true "(<collection>? (list 1 2 3))")
  (fol-is-true "(<collection>? {:a 1})")
  (fol-is-true "(<collection>? #{1 2})")
  (fol-is-true "(<ordered-collection>? [1 2 3])")
  (fol-is-true "(<ordered-collection>? (list 1 2 3))")
  (fol-is-true "(<unordered-collection>? #{1 2})"))

;;; ---------------------------------------------------------------------------
;;; Common Operations
;;; ---------------------------------------------------------------------------

(test size-function
  "Test size function on various collections."
  (fol-is 0 "(size [])")
  (fol-is 3 "(size [1 2 3])")
  (fol-is 2 "(size {:a 1 :b 2})")
  (fol-is 3 "(size #{1 2 3})")
  (fol-is 5 "(size \"hello\")"))

(test empty-predicate
  "Test empty? predicate."
  (fol-is-true "(empty? [])")
  (fol-is-true "(empty? '())")
  (fol-is-true "(empty? {})")
  (fol-is-true "(empty? #{})")
  (fol-is-false "(empty? [1])")
  (fol-is-false "(empty? {:a 1})"))

(test seq-function
  "Test seq function."
  (fol-is nil "(seq [])")
  (fol-is nil "(seq '())")
  (fol-is-true "(seq [1 2 3])"))

;;; ---------------------------------------------------------------------------
;;; Nested Access
;;; ---------------------------------------------------------------------------

(test get-in-function
  "Test get-in for nested access."
  (fol-is 3 "(get-in {:a {:b {:c 3}}} [:a :b :c])")
  (fol-is nil "(get-in {:a 1} [:b :c])")
  (fol-is :default "(get-in {:a 1} [:b :c] :default)"))

(test assoc-in-function
  "Test assoc-in for nested update."
  (fol-is 10 "(get-in (assoc-in {:a {:b 1}} [:a :b] 10) [:a :b])"))
