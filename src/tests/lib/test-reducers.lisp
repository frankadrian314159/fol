(in-package :fol.compiler.tests.lib)

(def-suite reducers-tests
  :description "Tests for the reducers library"
  :in lib-tests)

(in-suite reducers-tests)

(test test-preduce
  (is (= 10 (fol.lib.reducers:preduce #'+ 0 '(1 2 3 4))))
  (is (= 0 (fol.lib.reducers:preduce #'+ 0 '()))))

(test test-fold
  ;; Using identity factories as Clojure reducers do
  (let ((add-fn (lambda (&optional (x nil x-p) (y nil y-p))
                  (cond ((and (not x-p) (not y-p)) 0)
                        ((and x-p (not y-p)) x)
                        (t (+ x y))))))
    ;; Small collection (serial path)
    (is (= 5050 (fol.lib.reducers:fold add-fn add-fn (loop for i from 1 to 100 collect i) 200)))
    ;; Large collection (parallel path)
    (is (= 5050 (fol.lib.reducers:fold add-fn add-fn (loop for i from 1 to 100 collect i) 10)))))

;;; ---------------------------------------------------------------------------
;;; aggregate tests
;;; ---------------------------------------------------------------------------

(test aggregate-serial-sum
  "aggregate on a small collection takes the serial path and produces correct sum."
  (let ((result (fol.lib.reducers:aggregate
                 0
                 #'+
                 #'+
                 '(1 2 3 4 5)
                 1000))) ; chunk size > collection size => serial
    (is (= 15 result))))

(test aggregate-parallel-sum
  "aggregate on a large collection uses parallel chunks and still sums correctly."
  (let ((result (fol.lib.reducers:aggregate
                 0
                 #'+
                 #'+
                 (loop for i from 1 to 1000 collect i)
                 50)))
    (is (= 500500 result))))

(test aggregate-type-changing
  "aggregate can produce an accumulator of a different type than the elements."
  ;; Collect integers into a list of strings (seq-op changes type).
  (let* ((result (fol.lib.reducers:aggregate
                  (lambda () '())
                  (lambda (acc x) (cons (write-to-string x) acc))
                  (lambda (a b) (append a b))
                  '(1 2 3)
                  1000)) ; serial path for deterministic order
         (sorted (sort result #'string<)))
    (is (equal '("1" "2" "3") sorted))))

(test aggregate-zero-function
  "When zero is a function it is called fresh for each chunk, not shared."
  ;; Each chunk starts with its own fresh list accumulator.
  (let ((result (fol.lib.reducers:aggregate
                 (lambda () '())
                 (lambda (acc x) (cons x acc))
                 (lambda (a b) (append a b))
                 '(1 2 3 4 5 6)
                 2))) ; 3 chunks of 2 → 3 fresh accumulators
    (is (= 6 (length result)))
    (is (null (set-difference result '(1 2 3 4 5 6))))))

(test aggregate-empty-collection
  "aggregate on an empty collection returns zero directly."
  (is (= 0 (fol.lib.reducers:aggregate 0 #'+ #'+ '())))
  (is (equal '() (fol.lib.reducers:aggregate '() #'cons #'append '()))))

(test aggregate-frequency-map
  "aggregate builds a frequency map in a single parallel pass."
  (let* ((data '(:a :b :a :c :b :a))
         (result (fol.lib.reducers:aggregate
                  (lambda () (make-hash-table))
                  (lambda (m k)
                    (setf (gethash k m) (1+ (gethash k m 0)))
                    m)
                  (lambda (a b)
                    (maphash (lambda (k v)
                               (setf (gethash k a) (+ v (gethash k a 0))))
                             b)
                    a)
                  data
                  1000))) ; serial path so one hash-table is safe to mutate
    (is (= 3 (gethash :a result 0)))
    (is (= 2 (gethash :b result 0)))
    (is (= 1 (gethash :c result 0)))))
