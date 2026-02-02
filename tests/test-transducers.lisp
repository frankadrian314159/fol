(in-package :fol.integration-tests)

(def-suite transducers-suite :in integration-suite)
(def-suite* :transducers-tests :in transducers-suite)

;;; ---------------------------------------------------------------------------
;;; Basic Transducer Tests
;;; ---------------------------------------------------------------------------

(test transduce-with-map
  "Test transduce with map transducer."
  (fol-is 9 "(transduce (map inc) + 0 [1 2 3])")
  (fol-is 30 "(transduce (map (fn [x] (* x 2))) + 0 [1 2 3 4 5])"))

(test transduce-with-filter
  "Test transduce with filter transducer."
  (fol-is 12 "(transduce (filter even?) + 0 [1 2 3 4 5 6])")
  (fol-is 9 "(transduce (filter odd?) + 0 [1 2 3 4 5])"))

;;; ---------------------------------------------------------------------------
;;; Composed Transducers
;;; ---------------------------------------------------------------------------

(test comp-transducers-filter-map
  "Test composed transducers: filter then map."
  ;; Filter even, then increment: [2 4] -> [3 5] sum = 8
  (fol-is 8 "(transduce (comp (filter even?) (map inc)) + 0 [1 2 3 4 5])"))

(test comp-transducers-map-filter
  "Test composed transducers: map then filter."
  ;; Double all, then filter even: [2 4 6 8 10] -> [2 4 6 8 10] sum = 30
  (fol-is 30 "(transduce (comp (map (fn [x] (* x 2))) (filter even?)) + 0 [1 2 3 4 5])"))

;;; ---------------------------------------------------------------------------
;;; Sequence Function with Transducers
;;; ---------------------------------------------------------------------------

(test sequence-with-transducer
  "Test sequence with map transducer."
  (fol-is 2 "(first (sequence (map inc) [1 2 3]))")
  (fol-is 3 "(first (rest (sequence (map inc) [1 2 3])))"))

(test sequence-with-filter-transducer
  "Test sequence with filter transducer."
  (fol-is 2 "(first (sequence (filter even?) [1 2 3 4 5]))")
  (fol-is 4 "(first (rest (sequence (filter even?) [1 2 3 4 5]))))"))

(test sequence-with-composed
  "Test sequence with composed transducers."
  (fol-is 3 "(first (sequence (comp (filter even?) (map inc)) [1 2 3 4]))"))

;;; ---------------------------------------------------------------------------
;;; Into with Transducers
;;; ---------------------------------------------------------------------------

(test into-with-map-transducer
  "Test into with map transducer."
  (fol-is '(2 3 4) "(into [] (map inc) [1 2 3])")
  (fol-is 3 "(size (into [] (map inc) [1 2 3]))"))

(test into-with-filter-transducer
  "Test into with filter transducer."
  (fol-is '(2 4 6) "(into [] (filter even?) [1 2 3 4 5 6])")
  (fol-is 3 "(size (into [] (filter even?) [1 2 3 4 5 6]))"))

(test into-set-with-transducer
  "Test into set with transducer."
  (fol-is 3 "(size (into #{} (map inc) [1 2 3]))"))

;;; ---------------------------------------------------------------------------
;;; Remove Transducer
;;; ---------------------------------------------------------------------------

(test remove-transducer
  "Test remove transducer (opposite of filter)."
  (fol-is '(1 3 5) "(into [] (remove even?) [1 2 3 4 5])")
  (fol-is 3 "(size (into [] (remove even?) [1 2 3 4 5]))"))

(test remove-transducer-composed
  "Test remove transducer composed with others."
  ;; Remove even, map double
  (fol-is '(2 6 10) "(into [] (comp (remove even?) (map (fn [x] (* x 2)))) [1 2 3 4 5])"))

;;; ---------------------------------------------------------------------------
;;; Take-while and Drop-while Transducers
;;; ---------------------------------------------------------------------------

(test take-while-transducer
  "Test take-while transducer."
  (fol-is '(1 2 3) "(into [] (take-while (fn [x] (< x 4))) [1 2 3 4 5])"))

(test drop-while-transducer
  "Test drop-while transducer."
  (fol-is '(4 5 6) "(into [] (drop-while (fn [x] (< x 4))) [1 2 3 4 5 6])"))

(test take-while-drop-while-composed
  "Test take-while and drop-while composed."
  ;; Drop while < 3, take while < 6
  (fol-is '(3 4 5) "(into [] (comp (drop-while (fn [x] (< x 3))) (take-while (fn [x] (< x 6)))) [1 2 3 4 5 6 7])"))

;;; ---------------------------------------------------------------------------
;;; Take-nth Transducer
;;; ---------------------------------------------------------------------------

(test take-nth-transducer
  "Test take-nth transducer."
  (fol-is '(0 2 4 6 8) "(into [] (take-nth 2) [0 1 2 3 4 5 6 7 8 9])")
  (fol-is '(0 3 6 9) "(into [] (take-nth 3) [0 1 2 3 4 5 6 7 8 9])"))

;;; ---------------------------------------------------------------------------
;;; Distinct Transducer
;;; ---------------------------------------------------------------------------

(test distinct-transducer
  "Test distinct transducer."
  (fol-is '(1 2 3 4) "(into [] (distinct) [1 2 1 3 2 4 3 1])")
  (fol-is 4 "(size (into [] (distinct) [1 2 1 3 2 4 3 1]))"))

;;; ---------------------------------------------------------------------------
;;; Dedupe Transducer
;;; ---------------------------------------------------------------------------

(test dedupe-transducer
  "Test dedupe transducer (removes consecutive duplicates)."
  (fol-is '(1 2 3 1 2) "(into [] (dedupe) [1 1 2 2 2 3 1 1 2])")
  (fol-is 5 "(size (into [] (dedupe) [1 1 2 2 2 3 1 1 2]))"))

;;; ---------------------------------------------------------------------------
;;; Keep Transducer
;;; ---------------------------------------------------------------------------

(test keep-transducer
  "Test keep transducer (keeps non-nil results)."
  (fol-is '(1 3 5) "(into [] (keep (fn [x] (if (odd? x) x nil))) [1 2 3 4 5])"))

;;; ---------------------------------------------------------------------------
;;; Keep-indexed Transducer
;;; ---------------------------------------------------------------------------

(test keep-indexed-transducer
  "Test keep-indexed transducer."
  ;; Keep elements where index is odd
  (fol-is '(:b :d) "(into [] (keep-indexed (fn [i x] (if (odd? i) x nil))) [:a :b :c :d :e])"))

;;; ---------------------------------------------------------------------------
;;; Map-indexed Transducer
;;; ---------------------------------------------------------------------------

(test map-indexed-transducer
  "Test map-indexed transducer."
  (fol-is '(0 2 6) "(into [] (map-indexed (fn [i x] (* i x))) [1 2 3])"))

;;; ---------------------------------------------------------------------------
;;; Interpose Transducer
;;; ---------------------------------------------------------------------------

(test interpose-transducer
  "Test interpose transducer."
  (fol-is '(1 0 2 0 3) "(into [] (interpose 0) [1 2 3])")
  (fol-is 5 "(size (into [] (interpose :sep) [1 2 3]))"))

;;; ---------------------------------------------------------------------------
;;; Cat Transducer (Concatenates nested sequences)
;;; ---------------------------------------------------------------------------

(test cat-transducer
  "Test cat transducer."
  (fol-is '(1 2 3 4 5) "(into [] cat [[1 2] [3] [4 5]])")
  (fol-is 5 "(size (into [] cat [[1 2] [3] [4 5]]))"))

;;; ---------------------------------------------------------------------------
;;; Completing and Ensure-reduced
;;; ---------------------------------------------------------------------------

(test completing-basic
  "Test completing wraps a reducing function."
  (fol-is 6 "(transduce identity (completing +) 0 [1 2 3])"))

(test ensure-reduced-on-plain
  "Test ensure-reduced wraps plain value."
  (fol-is-true "(reduced? (ensure-reduced 42))"))

(test ensure-reduced-on-reduced
  "Test ensure-reduced keeps reduced as-is."
  (fol-is-true "(reduced? (ensure-reduced (reduced 42)))"))

(test unreduced-unwraps
  "Test unreduced unwraps reduced value."
  (fol-is 42 "(unreduced (reduced 42))")
  (fol-is 42 "(unreduced 42)"))

;;; ---------------------------------------------------------------------------
;;; Eduction
;;; ---------------------------------------------------------------------------

(test eduction-basic
  "Test eduction creates reusable transducer application."
  (fol-is 2 "(first (eduction (map inc) [1 2 3]))")
  (fol-is 3 "(size (into [] (eduction (map inc) [1 2 3])))"))

(test eduction-composed
  "Test eduction with composed transducers."
  (fol-is 3 "(first (eduction (comp (filter even?) (map inc)) [1 2 3 4]))"))

;;; ---------------------------------------------------------------------------
;;; Lazy Sequence Tests
;;; ---------------------------------------------------------------------------

(test lazy-seq-not-forced-until-accessed
  "Test lazy sequences are not forced until accessed."
  ;; The map creates a lazy-seq, which isn't forced until we take first
  (fol-is 2 "(first (map inc [1 2 3]))"))

(test lazy-seq-maintains-laziness
  "Test lazy sequences maintain laziness through operations."
  ;; Take from an infinite sequence
  (fol-is '(0 1 2 3 4) "(into [] (take 5 (range)))"))

(test lazy-cat-function
  "Test lazy-cat creates lazy concatenation."
  (fol-is 1 "(first (lazy-cat [1 2] [3 4]))")
  (fol-is '(1 2 3 4) "(into [] (lazy-cat [1 2] [3 4]))"))

(test iterate-is-lazy
  "Test iterate returns lazy sequence."
  (fol-is '(1 2 4 8 16) "(into [] (take 5 (iterate (fn [x] (* x 2)) 1)))"))

(test cycle-is-lazy
  "Test cycle returns lazy sequence."
  (fol-is '(1 2 3 1 2) "(into [] (take 5 (cycle [1 2 3])))"))

(test repeat-is-lazy
  "Test repeat without count is lazy."
  (fol-is '(:x :x :x :x :x) "(into [] (take 5 (repeat :x)))"))

(test repeatedly-is-lazy
  "Test repeatedly without count is lazy."
  (fol-is 5 "(size (into [] (take 5 (repeatedly (fn [] 42)))))"))

;;; ---------------------------------------------------------------------------
;;; Delay and Force
;;; ---------------------------------------------------------------------------

(test delay-creates-deferred
  "Test delay creates deferred computation."
  (fol-is 42 "(deref (delay 42))"))

(test delay-caches-result
  "Test delay caches its result."
  (fol-is 42 "(bind [d (delay (+ 20 22))] (deref d))"))

;;; ---------------------------------------------------------------------------
;;; Realized? Tests
;;; ---------------------------------------------------------------------------

(test realized?-on-lazy-seq
  "Test realized? on lazy sequences."
  ;; After forcing the first element, the lazy-seq should be realized
  (fol-is-true "(bind [s (map inc [1 2 3])]
                  (first s)
                  (realized? s))"))

;;; ---------------------------------------------------------------------------
;;; Reductions Function
;;; ---------------------------------------------------------------------------

(test reductions-without-init
  "Test reductions without initial value."
  (fol-is '(1 3 6 10 15) "(into [] (reductions + [1 2 3 4 5]))"))

(test reductions-with-init
  "Test reductions with initial value."
  (fol-is '(100 101 103 106) "(into [] (reductions + 100 [1 2 3]))"))

;;; ---------------------------------------------------------------------------
;;; Reduce with Reduced (Early Termination)
;;; ---------------------------------------------------------------------------

(test reduce-early-termination
  "Test reduce stops when reduced is returned."
  (fol-is 6 "(reduce (fn [acc x] (if (> acc 5) (reduced acc) (+ acc x))) 0 [1 2 3 4 5])"))

;;; ---------------------------------------------------------------------------
;;; Run! Function
;;; ---------------------------------------------------------------------------

(test run!-executes-side-effects
  "Test run! executes function for side effects."
  ;; run! returns nil but executes the function
  (fol-is nil "(run! identity [1 2 3])"))

;;; ---------------------------------------------------------------------------
;;; Doseq Macro
;;; ---------------------------------------------------------------------------

(test doseq-basic
  "Test doseq iterates for side effects."
  ;; doseq returns nil
  (fol-is nil "(doseq [x [1 2 3]] x)"))

;;; ---------------------------------------------------------------------------
;;; Dotimes Macro
;;; ---------------------------------------------------------------------------

(test dotimes-basic
  "Test dotimes iterates n times."
  ;; dotimes returns nil
  (fol-is nil "(dotimes [i 5] i)"))

;;; ---------------------------------------------------------------------------
;;; For Macro (List Comprehension)
;;; ---------------------------------------------------------------------------

(test for-basic
  "Test for list comprehension."
  (fol-is '(0 1 2 3 4) "(into [] (for [x (range 5)] x))"))

(test for-with-filter
  "Test for with :when filter."
  (fol-is '(0 2 4 6 8) "(into [] (for [x (range 10) :when (even? x)] x))"))

(test for-nested
  "Test for with nested bindings."
  (fol-is 9 "(size (into [] (for [x [1 2 3] y [:a :b :c]] [x y])))"))

;;; ---------------------------------------------------------------------------
;;; Pmap (Parallel Map)
;;; ---------------------------------------------------------------------------

(test pmap-basic
  "Test pmap computes in parallel."
  (fol-is '(2 3 4 5 6) "(into [] (pmap inc [1 2 3 4 5]))"))

(test pmap-preserves-order
  "Test pmap preserves order."
  (fol-is '(1 4 9 16 25) "(into [] (pmap (fn [x] (* x x)) [1 2 3 4 5]))"))

;;; ---------------------------------------------------------------------------
;;; Seque Function
;;; ---------------------------------------------------------------------------

(test seque-basic
  "Test seque pre-fetches lazy seq elements."
  (fol-is 1 "(first (seque (map inc [0 1 2])))"))

;;; ---------------------------------------------------------------------------
;;; Apply with Sequences
;;; ---------------------------------------------------------------------------

(test apply-with-vector
  "Test apply spreads vector as arguments."
  (fol-is 15 "(apply + [1 2 3 4 5])"))

(test apply-with-mixed
  "Test apply with leading args and sequence."
  (fol-is 21 "(apply + 1 2 3 [4 5 6])"))

;;; ---------------------------------------------------------------------------
;;; Mapv and Filterv (Eager Versions)
;;; ---------------------------------------------------------------------------

(test mapv-eager
  "Test mapv returns vector eagerly."
  (fol-is-true "(<vector>? (mapv inc [1 2 3]))")
  (fol-is '(2 3 4) "(mapv inc [1 2 3])"))

(test filterv-eager
  "Test filterv returns vector eagerly."
  (fol-is-true "(<vector>? (filterv even? [1 2 3 4 5]))")
  (fol-is '(2 4) "(filterv even? [1 2 3 4 5])"))

;;; ---------------------------------------------------------------------------
;;; Some and Every with Lazy Seqs
;;; ---------------------------------------------------------------------------

(test some-with-lazy
  "Test some works with lazy sequences."
  (fol-is-true "(some even? (range 1 100))")
  (fol-is 2 "(some (fn [x] (if (even? x) x nil)) (range 1 100))"))

(test every-with-lazy
  "Test every works with lazy sequences."
  (fol-is-true "(every positive? (range 1 10))")
  (fol-is-false "(every even? (range 1 10))"))

(test not-any-with-lazy
  "Test not-any works with lazy sequences."
  (fol-is-true "(not-any negative? (range 10))")
  (fol-is-false "(not-any even? (range 10))"))
