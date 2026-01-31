(in-package :fol.tests)

(def-suite transducer-suite :in fol-suite)
(def-suite* :fol.transducer-tests :in transducer-suite)

;;; ============================================================================
;;; Utility Predicate Tests
;;; ============================================================================

(test zero?-test
  "Test zero? predicate."
  (is-true (fol.number:zero? 0))
  (is-true (fol.number:zero? 0.0))
  (is-true (fol.number:zero? 0.0d0))
  (is-false (fol.number:zero? 1))
  (is-false (fol.number:zero? -1))
  (is-false (fol.number:zero? 0.1)))

(test simple-keyword?-test
  "Test simple-keyword? predicate using FOL eval."
  (let ((env (make-standard-env)))
    ;; Simple keywords should return true
    (is-true (fol-eval (fol-read-from-string "(simple-keyword? :foo)") env))
    (is-true (fol-eval (fol-read-from-string "(simple-keyword? :bar)") env))
    ;; Non-keywords should return false
    (is-false (fol-eval (fol-read-from-string "(simple-keyword? (quote foo))") env))
    (is-false (fol-eval (fol-read-from-string "(simple-keyword? \"foo\")") env))
    (is-false (fol-eval (fol-read-from-string "(simple-keyword? 42)") env))))

(test simple-symbol?-test
  "Test simple-symbol? predicate using FOL eval."
  (let ((env (make-standard-env)))
    ;; Simple symbols in CL-USER should return true
    (is-true (fol-eval (fol-read-from-string "(simple-symbol? (quote foo))") env))
    ;; Keywords should return false
    (is-false (fol-eval (fol-read-from-string "(simple-symbol? :foo)") env))
    ;; Non-symbols should return false
    (is-false (fol-eval (fol-read-from-string "(simple-symbol? \"foo\")") env))
    (is-false (fol-eval (fol-read-from-string "(simple-symbol? 42)") env))))

(test associative?-test
  "Test associative? predicate using FOL eval."
  (let ((env (make-standard-env)))
    ;; Dicts are associative
    (is-true (fol-eval (fol-read-from-string "(associative? {})") env))
    (is-true (fol-eval (fol-read-from-string "(associative? {:a 1 :b 2})") env))
    ;; Vectors are associative (by index)
    (is-true (fol-eval (fol-read-from-string "(associative? [])") env))
    (is-true (fol-eval (fol-read-from-string "(associative? [1 2 3])") env))
    ;; Lists are not associative
    (is-false (fol-eval (fol-read-from-string "(associative? (quote (1 2 3)))") env))
    ;; Sets are not associative
    (is-false (fol-eval (fol-read-from-string "(associative? #{1 2 3})") env))))

(test indexed?-test
  "Test indexed? predicate using FOL eval."
  (let ((env (make-standard-env)))
    ;; Vectors are indexed
    (is-true (fol-eval (fol-read-from-string "(indexed? [])") env))
    (is-true (fol-eval (fol-read-from-string "(indexed? [1 2 3])") env))
    ;; Lists are not indexed
    (is-false (fol-eval (fol-read-from-string "(indexed? (quote (1 2 3)))") env))
    ;; Dicts are not indexed
    (is-false (fol-eval (fol-read-from-string "(indexed? {:a 1})") env))))

(test seqable?-test
  "Test seqable? predicate using FOL eval."
  (let ((env (make-standard-env)))
    ;; Collections are seqable
    (is-true (fol-eval (fol-read-from-string "(seqable? [])") env))
    (is-true (fol-eval (fol-read-from-string "(seqable? [1 2 3])") env))
    (is-true (fol-eval (fol-read-from-string "(seqable? {})") env))
    (is-true (fol-eval (fol-read-from-string "(seqable? {:a 1})") env))
    (is-true (fol-eval (fol-read-from-string "(seqable? #{1 2 3})") env))
    ;; nil is seqable
    (is-true (fol-eval (fol-read-from-string "(seqable? nil)") env))
    ;; Numbers are not seqable
    (is-false (fol-eval (fol-read-from-string "(seqable? 42)") env))))

(test any?-test
  "Test any? predicate using FOL eval."
  (let ((env (make-standard-env)))
    ;; any? returns true for everything
    (is-true (fol-eval (fol-read-from-string "(any? nil)") env))
    (is-true (fol-eval (fol-read-from-string "(any? 42)") env))
    (is-true (fol-eval (fol-read-from-string "(any? \"hello\")") env))
    (is-true (fol-eval (fol-read-from-string "(any? [1 2 3])") env))
    (is-true (fol-eval (fol-read-from-string "(any? :keyword)") env))))

;;; ============================================================================
;;; Reduced Tests
;;; ============================================================================

(test reduced-creation
  "Test creating a reduced value."
  (let ((r (reduced 42)))
    (is-true (<reduced>? r))
    (is (= 42 (reduced-value r)))))

(test reduced-unreduced
  "Test unreduced on reduced and non-reduced values."
  (let ((r (reduced 42)))
    (is (= 42 (unreduced r)))
    (is (= 42 (unreduced 42)))))

(test reduced?-test
  "Test reduced? predicate."
  (is-true (<reduced>? (reduced 42)))
  (is-false (<reduced>? 42))
  (is-false (<reduced>? nil)))

;;; ============================================================================
;;; Transduce Tests
;;; ============================================================================

(test transduce-with-map
  "Test transduce with map transducer."
  (let ((env (make-standard-env)))
    ;; (transduce (map inc) + 0 [1 2 3]) should be 9 (2+3+4)
    (is (= 9 (fol-eval (fol-read-from-string "(transduce (map inc) + 0 [1 2 3])") env)))))

(test transduce-with-filter
  "Test transduce with filter transducer."
  (let ((env (make-standard-env)))
    ;; (transduce (filter even?) + 0 [1 2 3 4 5 6]) should be 12 (2+4+6)
    (is (= 12 (fol-eval (fol-read-from-string "(transduce (filter even?) + 0 [1 2 3 4 5 6])") env)))))

(test transduce-composed
  "Test transduce with composed transducers."
  (let ((env (make-standard-env)))
    ;; (transduce (comp (filter even?) (map inc)) + 0 [1 2 3 4])
    ;; filters to [2 4], maps to [3 5], sums to 8
    (is (= 8 (fol-eval (fol-read-from-string "(transduce (comp (filter even?) (map inc)) + 0 [1 2 3 4])") env)))))

;;; ============================================================================
;;; Completing Tests
;;; ============================================================================

(test completing-basic
  "Test completing function."
  (let ((env (make-standard-env)))
    ;; completing wraps a 2-arg function to add a 1-arg completion arity
    (is (= 6 (fol-eval (fol-read-from-string
                        "(bind [cf (completing +)]
                           (cf (cf (cf 0 1) 2) 3))")
                       env)))))

(test completing-with-custom-finalizer
  "Test completing with custom completion function."
  (let ((env (make-standard-env)))
    ;; completing with a finalizer that doubles the result
    ;; The 2-arg calls accumulate: (+ (+ (+ 0 1) 2) 3) = 6
    ;; The final 1-arg call triggers completion: (* 6 2) = 12
    (is (= 12 (fol-eval (fol-read-from-string
                         "(bind [cf (completing + (fn [x] (* x 2)))]
                            (cf (cf (cf (cf 0 1) 2) 3)))")
                        env)))))

;;; ============================================================================
;;; Ensure-reduced Tests
;;; ============================================================================

(test ensure-reduced-non-reduced
  "Test ensure-reduced on non-reduced value."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-read-from-string "(ensure-reduced 42)") env)))
      (is-true (<reduced>? result))
      (is (= 42 (reduced-value result))))))

(test ensure-reduced-already-reduced
  "Test ensure-reduced on already reduced value."
  (let ((env (make-standard-env)))
    (let ((result (fol-eval (fol-read-from-string "(ensure-reduced (reduced 42))") env)))
      (is-true (<reduced>? result))
      (is (= 42 (reduced-value result))))))

;;; ============================================================================
;;; Cat Transducer Tests
;;; ============================================================================

(test cat-transducer
  "Test cat transducer that concatenates collections."
  (let ((env (make-standard-env)))
    ;; (transduce cat conj [] [[1 2] [3 4] [5]]) should be [1 2 3 4 5]
    (let ((result (fol-eval (fol-read-from-string "(transduce cat conj [] [[1 2] [3 4] [5]])") env)))
      (is-true (<vector>? result))
      (is (= 5 (size result)))
      (is (= 1 (get result 0)))
      (is (= 5 (get result 4))))))

;;; ============================================================================
;;; Halt-when Transducer Tests
;;; ============================================================================

(test halt-when-transducer
  "Test halt-when transducer that stops early."
  (let ((env (make-standard-env)))
    ;; (transduce (halt-when (fn [x] (> x 3))) conj [] [1 2 3 4 5])
    ;; should stop when x > 3, so result is [1 2 3]
    (let ((result (fol-eval (fol-read-from-string
                             "(transduce (halt-when (fn [x] (> x 3))) conj [] [1 2 3 4 5])") env)))
      (is-true (<vector>? result))
      (is (= 3 (size result)))
      (is (= 1 (get result 0)))
      (is (= 3 (get result 2))))))

;;; ============================================================================
;;; Sequence Function Tests
;;; ============================================================================

(test sequence-with-map
  "Test sequence function with map transducer."
  (let ((env (make-standard-env)))
    ;; (sequence (map inc) [1 2 3]) should return (2 3 4)
    (let ((result (fol-eval (fol-read-from-string "(sequence (map inc) [1 2 3])") env)))
      (is-true (cl:or (<list>? result) (cl:listp result)))
      (is (= 2 (first result))))))

(test sequence-with-filter
  "Test sequence function with filter transducer."
  (let ((env (make-standard-env)))
    ;; (sequence (filter even?) [1 2 3 4 5 6]) should return (2 4 6)
    (let ((result (fol-eval (fol-read-from-string "(sequence (filter even?) [1 2 3 4 5 6])") env)))
      (is-true (cl:or (<list>? result) (cl:listp result)))
      (is (= 2 (first result))))))

;;; ============================================================================
;;; Intern Function Tests
;;; ============================================================================

(test intern-basic
  "Test intern function."
  (let ((env (make-standard-env)))
    ;; intern creates/finds a symbol in a namespace
    (let ((result (fol-eval (fol-read-from-string "(intern \"user\" \"my-symbol\")") env)))
      ;; intern returns a FOL <symbol> wrapper, not a CL symbol
      (is-true (fol.symbol:<symbol>? result)))))

;;; ============================================================================
;;; Reader Symbolic Value Tests
;;; ============================================================================

(test read-positive-infinity
  "Test reading ##Inf."
  (let ((result (fol-read-from-string "##Inf")))
    (is-true (cl:numberp result))
    (is-true (fol.number:infinite? result))
    (is-true (fol.number:positive? result))))

(test read-negative-infinity
  "Test reading ##-Inf."
  (let ((result (fol-read-from-string "##-Inf")))
    (is-true (cl:numberp result))
    (is-true (fol.number:infinite? result))
    (is-true (fol.number:negative? result))))

(test read-nan
  "Test reading ##NaN."
  (let ((result (fol-read-from-string "##NaN")))
    (is-true (cl:numberp result))
    (is-true (fol.number:NaN? result))))

(test symbolic-values-in-expression
  "Test using symbolic values in expressions."
  (let ((env (make-standard-env)))
    ;; Test that ##Inf can be used in expressions
    (let ((result (fol-eval (fol-read-from-string "(> ##Inf 1000000)") env)))
      (is-true result))
    ;; Test that ##-Inf can be used in expressions
    (let ((result (fol-eval (fol-read-from-string "(< ##-Inf -1000000)") env)))
      (is-true result))))
