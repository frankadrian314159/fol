;;; FOL Compiler Tests - Transducers
;;;
;;; Tests for the Transducers implementation.

(in-package :fol.compiler.tests)

(in-suite transducers-tests)

;;; Helper to run a transducer and collect results into a vector
(defun run-transducer (xform coll)
  (fol.compiler.transducers:transduce xform
                                      #'fol.compiler.collection-functions:conj
                                      (fol.compiler.collection-functions:vector)
                                      coll))

(test transducer-map
  (let ((data (fol.compiler.collection-functions:vector 1 2 3)))
    (is (fol.compiler.primitive-functions:=? 
          (run-transducer (fol.compiler.transducers:map #'1+) data)
          (fol.compiler.collection-functions:vector 2 3 4)))))

(test transducer-filter
  (let ((data (fol.compiler.collection-functions:vector 1 2 3 4)))
    (is (fol.compiler.primitive-functions:=? 
          (run-transducer (fol.compiler.transducers:filter #'evenp) data)
          (fol.compiler.collection-functions:vector 2 4)))))

(test transducer-take
  (let ((data (fol.compiler.collection-functions:vector 1 2 3 4 5)))
    (is (fol.compiler.primitive-functions:=? 
          (run-transducer (fol.compiler.transducers:take 3) data)
          (fol.compiler.collection-functions:vector 1 2 3)))))

(test transducer-mapcat
  (let ((data (fol.compiler.collection-functions:vector 1 2 3)))
    (is (fol.compiler.primitive-functions:=? 
          (run-transducer (fol.compiler.transducers:mapcat (lambda (x)
                                                                  (fol.compiler.collection-functions:vector x (1+ x))))
                          data)
          (fol.compiler.collection-functions:vector 1 2 2 3 3 4)))))

(test transducer-compose
  (let ((data (fol.compiler.collection-functions:vector 1 2 3 4 5 6))
        (xform (fol.compiler.functional:comp
                (fol.compiler.transducers:filter #'evenp)
                (fol.compiler.transducers:map #'1+))))
    ;; filter even: 2 4 6
    ;; map 1+: 3 5 7
    (is (fol.compiler.primitive-functions:=? 
          (run-transducer xform data)
          (fol.compiler.collection-functions:vector 3 5 7)))))

(test transducer-halt-when
  (let ((data (fol.compiler.collection-functions:vector 1 2 3 4 5)))
    ;; The transducer returns the halted value (3) because halt-when with no retf returns the input.
    ;; run-transducer uses conj, but transduce returns the accumulator.
    ;; Wait, if transduce returns the reduced value, run-transducer (which calls transduce) returns that value.
    (is (= 3 (run-transducer (fol.compiler.transducers:halt-when (lambda (x) (= x 3)))
                             data)))))

(test transducer-halt-when-behavior
  (let ((data (fol.compiler.collection-functions:vector 1 2 3 4)))
    ;; Should return 3 (the value that caused halt)
    (is (= 3 (run-transducer (fol.compiler.transducers:halt-when (lambda (x) (= x 3))) data)))))

(test transducer-take-while
  (let ((data (fol.compiler.collection-functions:vector 1 2 3 4 5)))
    ;; take-while (< x 3): 1, 2. stops at 3.
    (is (fol.compiler.primitive-functions:=? 
          (run-transducer (fol.compiler.transducers:take-while (lambda (x) (< x 3))) data)
          (fol.compiler.collection-functions:vector 1 2)))))

(test transducer-drop
  (let ((data (fol.compiler.collection-functions:vector 1 2 3 4 5)))
    (is (fol.compiler.primitive-functions:=? 
          (run-transducer (fol.compiler.transducers:drop 2) data)
          (fol.compiler.collection-functions:vector 3 4 5)))))

(test transducer-drop-while
  (let ((data (fol.compiler.collection-functions:vector 1 2 3 4 5)))
    (is (fol.compiler.primitive-functions:=? 
          (run-transducer (fol.compiler.transducers:drop-while (lambda (x) (< x 3))) data)
          (fol.compiler.collection-functions:vector 3 4 5)))))

(test transducer-replace
  (let ((data (fol.compiler.collection-functions:vector 1 2 3))
        (repl-map (fol.compiler.collection-functions:dict 1 10 3 30)))
    (is (fol.compiler.primitive-functions:=? 
          (run-transducer (fol.compiler.transducers:replace repl-map) data)
          (fol.compiler.collection-functions:vector 10 2 30)))))

(test transducer-keep
  (let ((data (fol.compiler.collection-functions:vector 1 2 3 4)))
    (is (fol.compiler.primitive-functions:=? 
          (run-transducer (fol.compiler.transducers:keep (lambda (x) (and (evenp x) (* x 10)))) data)
          (fol.compiler.collection-functions:vector 20 40)))))

(test transducer-distinct
  (let ((data (fol.compiler.collection-functions:vector 1 2 1 3 2 4)))
    (is (fol.compiler.primitive-functions:=? 
          (run-transducer (fol.compiler.transducers:distinct) data)
          (fol.compiler.collection-functions:vector 1 2 3 4)))))

(test transducer-interpose
  (let ((data (fol.compiler.collection-functions:vector 1 2 3)))
    (is (fol.compiler.primitive-functions:=? 
          (run-transducer (fol.compiler.transducers:interpose 0) data)
          (fol.compiler.collection-functions:vector 1 0 2 0 3)))))

(test transducer-dedupe
  (let ((data (fol.compiler.collection-functions:vector 1 1 2 2 3 1 1)))
    (is (fol.compiler.primitive-functions:=? 
          (run-transducer (fol.compiler.transducers:dedupe) data)
          (fol.compiler.collection-functions:vector 1 2 3 1)))))

(test transducer-partition-all
  (let ((data (fol.compiler.collection-functions:vector 1 2 3 4 5)))
    (is (fol.compiler.primitive-functions:=? 
          (run-transducer (fol.compiler.transducers:partition-all 2) data)
          (fol.compiler.collection-functions:vector
           (fol.compiler.collection-functions:vector 1 2)
           (fol.compiler.collection-functions:vector 3 4)
           (fol.compiler.collection-functions:vector 5))))))

(test transducer-partition-by
  (let ((data (fol.compiler.collection-functions:vector 1 1 2 2 3 1)))
    (is (fol.compiler.primitive-functions:=? 
          (run-transducer (fol.compiler.transducers:partition-by #'identity) data)
          (fol.compiler.collection-functions:vector
           (fol.compiler.collection-functions:vector 1 1)
           (fol.compiler.collection-functions:vector 2 2)
           (fol.compiler.collection-functions:vector 3)
           (fol.compiler.collection-functions:vector 1))))))

(test transducer-remove
  (let ((data (fol.compiler.collection-functions:vector 1 2 3 4)))
    (is (fol.compiler.primitive-functions:=? 
          (run-transducer (fol.compiler.transducers:remove #'evenp) data)
          (fol.compiler.collection-functions:vector 1 3)))))

(test transducer-take-nth
  (let ((data (fol.compiler.collection-functions:vector 1 2 3 4 5)))
    (is (fol.compiler.primitive-functions:=? 
          (run-transducer (fol.compiler.transducers:take-nth 2) data)
          (fol.compiler.collection-functions:vector 1 3 5)))))

(test transducer-cat
  (let ((data (fol.compiler.collection-functions:vector 
               (fol.compiler.collection-functions:vector 1 2)
               (fol.compiler.collection-functions:vector 3)
               (fol.compiler.collection-functions:vector)
               (fol.compiler.collection-functions:vector 4 5))))
    (is (fol.compiler.primitive-functions:=? 
          (run-transducer (fol.compiler.transducers:cat) data)
          (fol.compiler.collection-functions:vector 1 2 3 4 5)))))

(test transducer-map-indexed
  (let ((data (fol.compiler.collection-functions:vector :a :b :c)))
    (is (fol.compiler.primitive-functions:=? 
          (run-transducer (fol.compiler.transducers:map-indexed (lambda (i x) (fol.compiler.collection-functions:vector i x))) data)
          (fol.compiler.collection-functions:vector 
           (fol.compiler.collection-functions:vector 0 :a)
           (fol.compiler.collection-functions:vector 1 :b)
           (fol.compiler.collection-functions:vector 2 :c))))))

(test transducer-keep-indexed
  (let ((data (fol.compiler.collection-functions:vector :a :b :c :d)))
    (is (fol.compiler.primitive-functions:=? 
          (run-transducer (fol.compiler.transducers:keep-indexed (lambda (i x) (if (evenp i) x nil))) data)
          (fol.compiler.collection-functions:vector :a :c)))))

(test transducer-into
  (let ((data (fol.compiler.collection-functions:vector 1 2 3)))
    (is (fol.compiler.primitive-functions:=? 
          (fol.compiler.transducers:into (fol.compiler.collection-functions:vector) (fol.compiler.transducers:map #'1+) data)
          (fol.compiler.collection-functions:vector 2 3 4)))))

(test transducer-sequence
  (let ((data (fol.compiler.collection-functions:vector 1 2 3)))
    (let ((seq (fol.compiler.transducers:sequence (fol.compiler.transducers:map #'1+) data)))
      (is (fol.compiler.primitive-functions:<lazy-seq>? seq))
      (is (equal (fol.compiler.collections:collection-seq seq) '(2 3 4))))))

(test transducer-eduction
  (let ((data (fol.compiler.collection-functions:vector 1 2 3)))
    (let ((ed (fol.compiler.transducers:eduction (fol.compiler.transducers:map #'1+) data)))
      (is (= (fol.compiler.collections:collection-size ed) 3))
      (is (equal (fol.compiler.collections:collection-seq ed) '(2 3 4))))))
