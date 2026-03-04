(in-package :fol.tests)

;;; ============================================================================
;;; FOL Walk Tests
;;; ============================================================================
;;;
;;; Tests for tree traversal and transformation functions in fol.walk module.

(def-suite walk-tests
  :description "Tests for FOL walk functions"
  :in fol-suite)

(in-suite walk-tests)

;;; ---------------------------------------------------------------------------
;;; Basic Walk Function Tests
;;; ---------------------------------------------------------------------------

(test walk-list-basic
  "Test basic walk on a vector (using [] syntax)."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (def data [1 2 3])
                 (walk (fn [x] (* x 2))
                       identity
                       data))"))
    (let ((result (test-fol code)))
      (is (fol.collection:<vector>? result))
      (is (= 2 (fol.seqop:first result)))
      (is (= 4 (fol.collection:second result)))
      (is (= 6 (fol.seqop:nth result 2))))))

(test walk-vector-basic
  "Test basic walk on a vector."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (def data (make '<vector> 1 2 3))
                 (walk (fn [x] (* x 2))
                       identity
                       data))"))
    (let ((result (test-fol code)))
      (is (fol.collection:<vector>? result))
      (is (= 2 (fol.seqop:first result)))
      (is (= 4 (fol.collection:second result))))))

(test walk-nested-structure
  "Test walk on nested structures."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (def data [1 [2 3] 4])
                 (walk identity
                       (fn [x]
                         (if (<vector>? x)
                             (apply make '<vector> x)
                             x))
                       data))"))
    (let ((result (test-fol code)))
      (is (fol.collection:<vector>? result)))))

(test walk-dict-basic
  "Test walk on a dictionary."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (def data (make '<dict> :a 1 :b 2))
                 (walk (fn [entry]
                         (make '<vector> (first entry)
                                     (* (second entry) 10)))
                       identity
                       data))"))
    (let ((result (test-fol code)))
      (is (fol.collection:<dict>? result))
      (is (= 10 (fol.seqop:get result :a)))
      (is (= 20 (fol.seqop:get result :b))))))

(test walk-set-basic
  "Test walk on a set."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (def data (make '<set> 1 2 3))
                 (walk (fn [x] (* x 2))
                       identity
                       data))"))
    (let ((result (test-fol code)))
      (is (fol.collection:<set>? result))
      (is (= 3 (fol.seqop:size result))))))

(test walk-non-collection
  "Test walk on non-collection values."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (walk identity (fn [x] (* x 2)) 5))"))
    (is (= 10 (test-fol code)))))

;;; ---------------------------------------------------------------------------
;;; Prewalk Tests
;;; ---------------------------------------------------------------------------

(test prewalk-numbers
  "Test prewalk incrementing numbers."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (def data [1 [2 3] 4])
                 (prewalk (fn [x]
                           (if (number? x)
                               (+ x 1)
                               x))
                         data))"))
    (let ((result (test-fol code)))
      (is (= 2 (fol.seqop:first result)))
      (is (= 5 (fol.seqop:nth result 2))))))

(test prewalk-replace-basic
  "Test prewalk-replace with simple replacements."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (def data [:a :b [:c :d]])
                 (def replacements (make '<dict> :a 1 :b 2 :c 3 :d 4))
                 (prewalk-replace replacements data))"))
    (let ((result (test-fol code)))
      (is (= 1 (fol.seqop:first result)))
      (is (= 2 (fol.collection:second result)))
      (let ((nested (fol.seqop:nth result 2)))
        (is (= 3 (fol.seqop:first nested)))
        (is (= 4 (fol.collection:second nested)))))))

(test prewalk-replace-nested
  "Test prewalk-replace on nested structures."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (def data [[1 2] [3 4]])
                 (def replacements (make '<dict> [1 2] :replaced))
                 (prewalk-replace replacements data))"))
    (let ((result (test-fol code)))
      ;; The outer list [1 2] should be replaced before we walk into it
      (is (= :replaced (fol.seqop:first result))))))

(test prewalk-order
  "Test that prewalk processes in pre-order (parent before children)."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (def visited (atom []))
                 (prewalk (fn [x]
                           (swap! visited (fn [v] (conj v x)))
                           x)
                         [:a [:b :c]])
                 @visited)"))
    (let ((result (test-fol code)))
      ;; First element should be the outer vector [:a [:b :c]]
      (is (fol.collection:<vector>? (fol.seqop:first result)))
      ;; :a should come before the nested vector [:b :c]
      (let ((second-elem (fol.collection:second result)))
        (is (eq :a second-elem))))))

;;; ---------------------------------------------------------------------------
;;; Postwalk Tests
;;; ---------------------------------------------------------------------------

(test postwalk-numbers
  "Test postwalk incrementing numbers."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (def data [1 [2 3] 4])
                 (postwalk (fn [x]
                            (if (number? x)
                                (+ x 1)
                                x))
                          data))"))
    (let ((result (test-fol code)))
      (is (= 2 (fol.seqop:first result)))
      (is (= 5 (fol.seqop:nth result 2))))))

(test postwalk-replace-basic
  "Test postwalk-replace with simple replacements."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (def data [:a :b [:c :d]])
                 (def replacements (make '<dict> :a 1 :b 2 :c 3 :d 4))
                 (postwalk-replace replacements data))"))
    (let ((result (test-fol code)))
      (is (= 1 (fol.seqop:first result)))
      (is (= 2 (fol.collection:second result)))
      (let ((nested (fol.seqop:nth result 2)))
        (is (= 3 (fol.seqop:first nested)))
        (is (= 4 (fol.collection:second nested)))))))

(test postwalk-replace-nested
  "Test postwalk-replace on nested structures."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (def data [[1 2] [3 4]])
                 (def replacements (make '<dict> [1 2] :first [3 4] :second))
                 (postwalk-replace replacements data))"))
    (let ((result (test-fol code)))
      ;; In post-order, children are processed first, then parents
      (is (= :first (fol.seqop:first result)))
      (is (= :second (fol.collection:second result))))))

(test postwalk-order
  "Test that postwalk processes in post-order (children before parent)."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (def visited (atom []))
                 (postwalk (fn [x]
                            (swap! visited (fn [v] (conj v x)))
                            x)
                          [:a [:b :c]])
                 @visited)"))
    (let ((result (test-fol code)))
      ;; First element should be :a (leaf), not the outer list
      (is (eq :a (fol.seqop:first result))))))

(test postwalk-transform-structure
  "Test postwalk transforming collection types."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (def data [1 [2 3] 4])
                 (postwalk (fn [x]
                            (if (<vector>? x)
                                (apply make '<vector> x)
                                x))
                          data))"))
    (let ((result (test-fol code)))
      (is (fol.collection:<vector>? result))
      (let ((nested (fol.collection:second result)))
        (is (fol.collection:<vector>? nested))))))

;;; ---------------------------------------------------------------------------
;;; Prewalk vs Postwalk Difference Tests
;;; ---------------------------------------------------------------------------

(test prewalk-vs-postwalk-replacement
  "Test difference between prewalk and postwalk for replacements."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (def data [1 2])
                 (def replacements (make '<dict> [1 2] [3 4] 1 99))
                 (def pre-result (prewalk-replace replacements data))
                 (def post-result (postwalk-replace replacements data))
                 (make '<dict> :pre pre-result :post post-result))"))
    (let ((result (test-fol code)))
      (let ((pre (fol.seqop:get result :pre))
            (post (fol.seqop:get result :post)))
        ;; Prewalk: [1 2] is replaced before walking into it -> [3 4]
        ;; Postwalk: 1 is replaced with 99 first, then [99 2] has no replacement
        (is (= 3 (fol.seqop:first pre)))
        (is (= 4 (fol.collection:second pre)))
        (is (= 99 (fol.seqop:first post)))
        (is (= 2 (fol.collection:second post)))))))

;;; ---------------------------------------------------------------------------
;;; Complex Structure Tests
;;; ---------------------------------------------------------------------------

(test walk-complex-nested-dict
  "Test walk on complex nested dictionary."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (def data (make '<dict>
                             :user (make '<dict> :name \"Alice\" :age 30)
                             :scores [10 20 30]))
                 (postwalk (fn [x]
                            (if (number? x)
                                (* x 2)
                                x))
                          data))"))
    (let ((result (test-fol code)))
      (let ((user (fol.seqop:get result :user)))
        (is (= 60 (fol.seqop:get user :age))))
      (let ((scores (fol.seqop:get result :scores)))
        (is (= 20 (fol.seqop:first scores)))
        (is (= 40 (fol.collection:second scores)))
        (is (= 60 (fol.seqop:nth scores 2)))))))

(test walk-mixed-collections
  "Test walk on mixed collection types."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (def vec-inner (make '<vector> 1 2))
                 (def dict-inner (make '<dict> :a 3 :b 4))
                 (def set-inner (make '<set> 5 6))
                 (def data (make '<vector> vec-inner dict-inner set-inner))
                 (postwalk (fn [x]
                            (if (number? x)
                                (+ x 10)
                                x))
                          data))"))
    (let ((result (test-fol code)))
      (let ((vec (fol.seqop:first result)))
        (is (fol.collection:<vector>? vec))
        (is (= 11 (fol.seqop:first vec))))
      (let ((dict (fol.collection:second result)))
        (is (fol.collection:<dict>? dict))
        (is (= 13 (fol.seqop:get dict :a))))
      (let ((set (fol.seqop:nth result 2)))
        (is (fol.collection:<set>? set))))))

(test walk-deeply-nested
  "Test walk on deeply nested structures."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (def data [[[1 2] [3 4]] [[5 6] [7 8]]])
                 (postwalk (fn [x]
                            (if (number? x)
                                (if (even? x) (* x 2) x)
                                x))
                          data))"))
    (let ((result (test-fol code)))
      ;; Navigate to deeply nested structure
      (let* ((outer-first (fol.seqop:first result))
             (inner-first (fol.seqop:first outer-first))
             (val1 (fol.seqop:first inner-first))
             (val2 (fol.collection:second inner-first)))
        (is (= 1 val1))  ;; 1 is odd, unchanged
        (is (= 4 val2))))))  ;; 2 is even, doubled to 4

;;; ---------------------------------------------------------------------------
;;; Edge Cases
;;; ---------------------------------------------------------------------------

(test walk-empty-list
  "Test walk on empty vector (using [] syntax)."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (prewalk identity []))"))
    (let ((result (test-fol code)))
      (is (fol.collection:<vector>? result))
      (is (= 0 (fol.seqop:size result))))))

(test walk-empty-vector
  "Test walk on empty vector."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (postwalk identity (make '<vector>)))"))
    (let ((result (test-fol code)))
      (is (fol.collection:<vector>? result))
      (is (= 0 (fol.seqop:size result))))))

(test walk-empty-dict
  "Test walk on empty dictionary."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (walk identity identity (make '<dict>)))"))
    (let ((result (test-fol code)))
      (is (fol.collection:<dict>? result))
      (is (= 0 (fol.seqop:size result))))))

(test walk-single-element
  "Test walk on single element list."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (prewalk (fn [x] (if (number? x) (* x 2) x)) [42]))"))
    (let ((result (test-fol code)))
      (is (= 84 (fol.seqop:first result))))))

(test walk-nil-values
  "Test walk with nil values."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (prewalk identity [1 nil 3]))"))
    (let ((result (test-fol code)))
      (is (= 1 (fol.seqop:first result)))
      (is (eq nil (fol.collection:second result)))
      (is (= 3 (fol.seqop:nth result 2))))))

;;; ---------------------------------------------------------------------------
;;; Functional Composition Tests
;;; ---------------------------------------------------------------------------

(test walk-with-multiple-transformations
  "Test walk with multiple transformation passes."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (def data [1 2 3])
                 (def step1 (prewalk (fn [x] (if (number? x) (* x 2) x)) data))
                 (def step2 (postwalk (fn [x] (if (number? x) (+ x 10) x)) step1))
                 step2)"))
    (let ((result (test-fol code)))
      ;; First multiply by 2: [2 4 6]
      ;; Then add 10: [12 14 16]
      (is (= 12 (fol.seqop:first result)))
      (is (= 14 (fol.collection:second result)))
      (is (= 16 (fol.seqop:nth result 2))))))

(test walk-preserves-structure-type
  "Test that walk preserves collection types."
  (let ((code "(do
                 (import 'fol.walk :all)
                 (def vec-data (make '<vector> 1 2 3))
                 (def vec-data2 [1 2 3])
                 (def dict-data (make '<dict> :a 1 :b 2))
                 (def set-data (make '<set> 1 2 3))
                 (make '<dict>
                   :vec (postwalk identity vec-data)
                   :vec2 (postwalk identity vec-data2)
                   :dict (postwalk identity dict-data)
                   :set (postwalk identity set-data)))"))
    (let ((result (test-fol code)))
      (is (fol.collection:<vector>? (fol.seqop:get result :vec)))
      (is (fol.collection:<vector>? (fol.seqop:get result :vec2)))
      (is (fol.collection:<dict>? (fol.seqop:get result :dict)))
      (is (fol.collection:<set>? (fol.seqop:get result :set))))))
