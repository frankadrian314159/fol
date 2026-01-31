(in-package :fol.tests)

;;; ============================================================================
;;; Dictionary Subclass Tests
;;; ============================================================================

(def-suite dict-suite :in fol-suite)
(def-suite* dict-tests :in dict-suite)

;;; ---------------------------------------------------------------------------
;;; Helper Functions
;;; ---------------------------------------------------------------------------

(defun seq-to-cl-list (fol-seq)
  "Convert a FOL sequence (list, vector, lazy-seq, etc.) to a CL list for test assertions."
  (let ((result nil))
    (cond
      ((null fol-seq) nil)
      ((<lazy-seq>? fol-seq)
       ;; Lazy sequences - iterate using first/rest
       (let ((current fol-seq))
         (cl:loop while (cl:and current (cl:not (empty? current))) do
           (cl:push (first current) result)
           (setf current (rest current)))))
      ((<list>? fol-seq)
       ;; FOL lists are linked lists with first and rest
       (let ((current fol-seq))
         (cl:loop while (cl:and current (cl:not (zerop (list-size current)))) do
           (cl:push (list-first current) result)
           (setf current (list-rest current)))))
      ((<vector>? fol-seq)
       ;; FOL vectors wrap FSET sequences
       (fset:do-seq (item (fol.wrappers:fol-value fol-seq))
         (cl:push item result)))
      (t
       ;; Try generic FSET iteration
       (fset:do-seq (item (fol.wrappers:fol-value fol-seq))
         (cl:push item result))))
    (cl:nreverse result)))

;;; ---------------------------------------------------------------------------
;;; Array Dict Tests
;;; ---------------------------------------------------------------------------

(test array-dict-creation
  "Test creation of array-dict."
  (let ((d (array-dict :a 1 :b 2 :c 3)))
    (is-true (<array-dict>? d))
    (is-true (<dict>? d))
    (is-true (<ordered-collection>? d))
    (is (= 3 (size d)))
    (is (= 1 (get d :a)))
    (is (= 2 (get d :b)))
    (is (= 3 (get d :c)))))

(test array-dict-preserves-insertion-order
  "Test that array-dict maintains insertion order."
  (let ((d (array-dict :z 3 :a 1 :m 2)))
    (is (equal '(:z :a :m) (cl:mapcar #'cl:car (seq-to-cl-list (seq d)))))))

(test array-dict-size-limit
  "Test that array-dict enforces size limit."
  (signals error
    (apply #'array-dict (loop for i from 1 to 1001 append (list i i)))))

(test array-dict-custom-limit
  "Test array-dict with custom size limit."
  (let ((d (array-dict-with-limit 5 :a 1 :b 2 :c 3)))
    (is (= 3 (size d)))
    (signals error
      (array-dict-with-limit 2 :a 1 :b 2 :c 3))))

;;; ---------------------------------------------------------------------------
;;; Sorted Dict Tests
;;; ---------------------------------------------------------------------------

(test sorted-dict-creation
  "Test creation of sorted-dict."
  (let ((d (sorted-dict :c 3 :a 1 :b 2)))
    (is-true (<sorted-dict>? d))
    (is-true (<dict>? d))
    (is-true (<ordered-collection>? d))
    (is (= 3 (size d)))))

(test sorted-dict-maintains-sort-order
  "Test that sorted-dict maintains keys in sorted order."
  (let ((d (sorted-dict :z 26 :a 1 :m 13 :b 2)))
    (let ((ks (keys d)))
      (is (equal '(:a :b :m :z) (cl:mapcar #'fol.wrappers:fol-value (seq-to-cl-list (seq ks))))))))

(test sorted-dict-by-custom-comparator
  "Test sorted-dict-by with custom comparator."
  ;; Use a comparator that sorts keywords in reverse alphabetical order
  (let* ((comparator (lambda (a b)
                       (let ((a-str (cl:symbol-name a))
                             (b-str (cl:symbol-name b)))
                         (cond ((cl:string> a-str b-str) -1)
                               ((cl:string< a-str b-str) 1)
                               (t 0)))))
         (d (sorted-dict-by comparator :a 1 :b 2 :c 3)))
    (is-true (<sorted-dict>? d))
    (let ((ks (keys d)))
      (is (equal '(:c :b :a) (cl:mapcar #'fol.wrappers:fol-value (seq-to-cl-list (seq ks))))))))

;;; ---------------------------------------------------------------------------
;;; Ordered Dict Tests
;;; ---------------------------------------------------------------------------

(test ordered-dict-creation
  "Test creation of ordered-dict."
  (let ((d (ordered-dict :a 1 :b 2 :c 3)))
    (is-true (<ordered-dict>? d))
    (is-true (<dict>? d))
    (is-true (<ordered-collection>? d))
    (is (= 3 (size d)))))

(test ordered-dict-preserves-insertion-order
  "Test that ordered-dict maintains insertion order."
  (let ((d (ordered-dict :z 3 :a 1 :m 2)))
    (is (equal '(:z :a :m) (cl:mapcar #'cl:car (seq-to-cl-list (seq d)))))))

(test ordered-dict-no-size-limit
  "Test that ordered-dict has no size limit."
  (let ((d (apply #'ordered-dict (loop for i from 1 to 2000 append (list i i)))))
    (is (= 2000 (size d)))))

;;; ---------------------------------------------------------------------------
;;; Priority Dict Tests
;;; ---------------------------------------------------------------------------

(test priority-dict-creation
  "Test creation of priority-dict."
  (let ((d (priority-dict :a 3 :b 1 :c 2)))
    (is-true (<priority-dict>? d))
    (is-true (<dict>? d))
    (is-true (<ordered-collection>? d))
    (is (= 3 (size d)))))

(test priority-dict-sorted-by-values
  "Test that priority-dict sorts by values (priorities)."
  (let ((d (priority-dict :low 10 :high 100 :mid 50)))
    (let ((ks (keys d)))
      ;; Keys should be in order of their values (priorities)
      (is (equal '(:low :mid :high) (cl:mapcar #'fol.wrappers:fol-value (seq-to-cl-list (seq ks))))))))

;;; ---------------------------------------------------------------------------
;;; Int Dict Tests
;;; ---------------------------------------------------------------------------

(test int-dict-creation
  "Test creation of int-dict with integer keys."
  (let ((d (int-dict 3 "c" 1 "a" 2 "b")))
    (is-true (<int-dict>? d))
    (is-true (<sorted-dict>? d))
    (is (= 3 (size d)))))

(test int-dict-sorted-by-keys
  "Test that int-dict maintains keys in sorted order."
  (let ((d (int-dict 42 "x" 7 "y" 100 "z" 3 "w")))
    (let ((ks (keys d)))
      (is (equal '(3 7 42 100) (cl:mapcar #'fol.wrappers:fol-value (seq-to-cl-list (seq ks))))))))

(test int-dict-rejects-non-integer-keys
  "Test that int-dict rejects non-integer keys."
  (signals error (int-dict :a 1))
  (signals error (int-dict "key" 1))
  (signals error (int-dict 1 "ok" 2.5 "bad")))

;;; ---------------------------------------------------------------------------
;;; Dict Query Function Tests
;;; ---------------------------------------------------------------------------

(test get-in-nested-dicts
  "Test get-in with nested dictionaries."
  (let ((d (make-dict :a (make-dict :b (make-dict :c 42)))))
    (is (= 42 (get-in d (make-list :a :b :c))))
    (is (eq nil (get-in d (make-list :a :b :x))))
    (is (eq :not-found (get-in d (make-list :a :x :c) :not-found)))))

(test get-in-mixed-collections
  "Test get-in with mixed dict/vector nesting."
  (let ((d (make-dict :x (make-vector 10 20 30))))
    (is (= 20 (get-in d (make-list :x 1))))))

(test find-returns-entry
  "Test find returns key-value pair."
  (let ((d (make-dict :a 1 :b 2)))
    (let ((entry (find d :a)))
      (is (consp entry))
      (is (eq :a (car entry)))
      (is (= 1 (cdr entry))))
    (is (eq nil (find d :missing)))))

(test keys-returns-all-keys
  "Test keys returns all dictionary keys (as lazy-seq)."
  (let ((d (make-dict :a 1 :b 2 :c 3)))
    ;; keys now returns a lazy-seq, convert to set for testing
    (let ((ks (into (make-set) (keys d))))
      (is (= 3 (size ks)))
      (is-true (contains? ks :a))
      (is-true (contains? ks :b))
      (is-true (contains? ks :c)))))

(test vals-returns-all-values
  "Test vals returns all dictionary values (as lazy-seq)."
  (let ((d (make-dict :a 1 :b 2 :c 3)))
    ;; vals now returns a lazy-seq, convert to set for testing
    (let ((vs (into (make-set) (vals d))))
      (is (= 3 (size vs)))
      (is-true (contains? vs 1))
      (is-true (contains? vs 2))
      (is-true (contains? vs 3)))))

(test key-and-val-extract-from-entry
  "Test key and val extract from map entry."
  (let ((entry (cl:cons :foo 42)))
    (is (eq :foo (key entry)))
    (is (= 42 (val entry)))))

;;; ---------------------------------------------------------------------------
;;; Dict Modification Function Tests
;;; ---------------------------------------------------------------------------

(test dissoc-removes-keys
  "Test dissoc removes keys from dict."
  (let* ((d (make-dict :a 1 :b 2 :c 3 :d 4))
         (d2 (dissoc d :b :d)))
    (is (= 2 (size d2)))
    (is (= 1 (get d2 :a)))
    (is (= 3 (get d2 :c)))
    (is (eq nil (get d2 :b)))
    (is (eq nil (get d2 :d)))))

(test dissoc-preserves-order-in-ordered-dict
  "Test dissoc maintains insertion order in ordered-dict."
  (let* ((d (ordered-dict :a 1 :b 2 :c 3 :d 4))
         (d2 (dissoc d :b)))
    (is (equal '(:a :c :d) (cl:mapcar #'cl:car (seq-to-cl-list (seq d2)))))))

(test merge-combines-dicts
  "Test merge combines multiple dicts."
  (let* ((d1 (make-dict :a 1 :b 2))
         (d2 (make-dict :b 20 :c 3))
         (d3 (merge d1 d2)))
    (is (= 3 (size d3)))
    (is (= 1 (get d3 :a)))
    (is (= 20 (get d3 :b)))  ; d2's value wins
    (is (= 3 (get d3 :c)))))

(test merge-with-combines-values
  "Test merge-with combines values with function."
  (let* ((d1 (make-dict :a 1 :b 2))
         (d2 (make-dict :b 3 :c 4))
         (d3 (merge-with #'cl:+ d1 d2)))
    (is (= 1 (get d3 :a)))
    (is (= 5 (get d3 :b)))  ; 2 + 3
    (is (= 4 (get d3 :c)))))

;;; ---------------------------------------------------------------------------
;;; Dict Transformation Function Tests
;;; ---------------------------------------------------------------------------

(test select-keys-filters-dict
  "Test select-keys keeps only specified keys."
  (let* ((d (make-dict :a 1 :b 2 :c 3 :d 4))
         (d2 (select-keys d (make-list :a :c :e))))
    (is (= 2 (size d2)))
    (is (= 1 (get d2 :a)))
    (is (= 3 (get d2 :c)))
    (is (eq nil (get d2 :b)))))

(test rename-keys-renames-keys
  "Test rename-keys renames dict keys."
  (let* ((d (make-dict :a 1 :b 2))
         (key-map (make-dict :a :x :b :y))
         (d2 (rename-keys d key-map)))
    (is (= 2 (size d2)))
    (is (= 1 (get d2 :x)))
    (is (= 2 (get d2 :y)))
    (is (eq nil (get d2 :a)))))

(test map-invert-swaps-keys-and-values
  "Test map-invert swaps keys and values."
  (let* ((d (make-dict :a 1 :b 2 :c 3))
         (d2 (map-invert d)))
    (is (= 3 (size d2)))
    (is (eq :a (get d2 1)))
    (is (eq :b (get d2 2)))
    (is (eq :c (get d2 3)))))

(test update-keys-transforms-keys
  "Test update-keys applies function to all keys."
  (let* ((d (make-dict 1 "a" 2 "b" 3 "c"))
         (d2 (update-keys d #'(lambda (k) (cl:* k 10)))))
    (is (= 3 (size d2)))
    (is (string= "a" (get d2 10)))
    (is (string= "b" (get d2 20)))
    (is (string= "c" (get d2 30)))))

(test update-vals-transforms-values
  "Test update-vals applies function to all values."
  (let* ((d (make-dict :a 1 :b 2 :c 3))
         (d2 (update-vals d #'(lambda (v) (cl:* v 10)))))
    (is (= 3 (size d2)))
    (is (= 10 (get d2 :a)))
    (is (= 20 (get d2 :b)))
    (is (= 30 (get d2 :c)))))

;;; ---------------------------------------------------------------------------
;;; Dict Construction Function Tests
;;; ---------------------------------------------------------------------------

(test freqs-counts-occurrences
  "Test freqs counts element occurrences."
  (let ((d (freqs (make-vector 1 2 3 1 2 1))))
    (is-true (<dict>? d))
    (is (= 3 (get d 1)))
    (is (= 2 (get d 2)))
    (is (= 1 (get d 3)))))

(test group-by-groups-by-function
  "Test group-by groups elements by function result."
  (let ((d (group-by #'cl:evenp (make-vector 1 2 3 4 5 6))))
    (is-true (<dict>? d))
    (let ((evens (get d t))
          (odds (get d nil)))
      (is (= 3 (size evens)))
      (is (= 3 (size odds)))
      (is-true (contains? evens 2))
      (is-true (contains? evens 4))
      (is-true (contains? evens 6))
      (is-true (contains? odds 1))
      (is-true (contains? odds 3))
      (is-true (contains? odds 5)))))

(test index-indexes-by-function
  "Test index creates dict indexed by function result."
  (let ((d (index (make-list :a :b :c :d) #'fol.wrappers:fol-value)))
    (is-true (<dict>? d))
    (is (= 4 (size d)))
    (is (eq :a (get d :a)))
    (is (eq :b (get d :b)))
    (is (eq :c (get d :c)))
    (is (eq :d (get d :d)))))

;;; ---------------------------------------------------------------------------
;;; Integration Tests
;;; ---------------------------------------------------------------------------

(test dict-types-work-with-existing-functions
  "Test that new dict types work with existing collection functions."
  (let ((ad (array-dict :a 1 :b 2))
        (sd (sorted-dict :a 1 :b 2))
        (od (ordered-dict :a 1 :b 2))
        (id (int-dict 1 "a" 2 "b")))
    ;; Test assoc
    (is (= 3 (get (assoc ad :c 3) :c)))
    (is (= 3 (get (assoc sd :c 3) :c)))
    (is (= 3 (get (assoc od :c 3) :c)))
    (is (string= "c" (get (assoc id 3 "c") 3)))
    ;; Test contains?
    (is-true (contains? ad :a))
    (is-true (contains? sd :a))
    (is-true (contains? od :a))
    (is-true (contains? id 1))
    ;; Test size
    (is (= 2 (size ad)))
    (is (= 2 (size sd)))
    (is (= 2 (size od)))
    (is (= 2 (size id)))))
