;;; FOL Walk Tests
;;;
;;; Tests for tree traversal and transformation functions in fol.walk.

(in-package :fol.compiler.tests.lib)
(in-suite walk-tests)

;;; ---------------------------------------------------------------------------
;;; Helper aliases
;;; ---------------------------------------------------------------------------

(defun make-vec (&rest elems)
  (apply #'fol.compiler.collections:make 'fol.compiler.collections:<vector> elems))

(defun make-dict (&rest args)
  (apply #'fol.compiler.collections:make 'fol.compiler.collections:<dict> args))

(defun make-fol-set (&rest elems)
  (apply #'fol.compiler.collections:make 'fol.compiler.collections:<set> elems))

(defun vec-ref (v idx)
  (fol.compiler.collection-functions:get v idx))

(defun dict-ref (d key)
  (fol.compiler.collection-functions:get d key))

(defun vec-size (v)
  (fol.compiler.collections:collection-size v))

;;; ---------------------------------------------------------------------------
;;; Basic Walk Function Tests
;;; ---------------------------------------------------------------------------

(test walk-vector-basic
      "Walk applies inner to each element of a vector."
      (let* ((data (make-vec 1 2 3))
             (result (fol.walk:walk #'1+ #'identity data)))
        (is (typep result 'fol.compiler.collections:<vector>))
        (is (eql 2 (vec-ref result 0)))
        (is (eql 3 (vec-ref result 1)))
        (is (eql 4 (vec-ref result 2)))))

(test walk-vector-outer
      "Walk applies outer to the rebuilt collection."
      (let* ((data (make-vec 10 20 30))
             (outer-called nil)
             (result (fol.walk:walk #'identity
                                    (lambda (x)
                                      (setf outer-called t)
                                      x)
                                    data)))
        (is (eq t outer-called))
        (is (typep result 'fol.compiler.collections:<vector>))
        (is (eql 10 (vec-ref result 0)))))

(test walk-dict-basic
      "Walk on dict wraps entries as 2-element vectors."
      (let* ((data (make-dict :a 1 :b 2))
             (result (fol.walk:walk
                      (lambda (entry)
                        ;; entry is a 2-element vector [key value]
                        (let ((k (vec-ref entry 0))
                              (v (vec-ref entry 1)))
                          (make-vec k (* v 10))))
                      #'identity
                      data)))
        (is (typep result 'fol.compiler.collections:<dict>))
        (is (eql 10 (dict-ref result :a)))
        (is (eql 20 (dict-ref result :b)))))

(test walk-set-basic
      "Walk on set applies inner to each element."
      (let* ((data (make-fol-set 1 2 3))
             (result (fol.walk:walk #'1+ #'identity data)))
        (is (typep result 'fol.compiler.collections:<set>))
        (is (eql 3 (fol.compiler.collections:collection-size result)))))

(test walk-non-collection
      "Walk on a non-collection value applies outer directly."
      (is (eql 10 (fol.walk:walk #'identity (lambda (x) (* x 2)) 5)))
      (is (eq :hello (fol.walk:walk #'identity #'identity :hello)))
      (is (equal "test" (fol.walk:walk #'identity #'identity "test"))))

;;; ---------------------------------------------------------------------------
;;; Prewalk Tests
;;; ---------------------------------------------------------------------------

(test prewalk-increment-numbers
      "Prewalk increments all numbers in a nested vector."
      (let* ((data (make-vec 1 (make-vec 2 3) 4))
             (result (fol.walk:prewalk
                      (lambda (x) (if (numberp x) (1+ x) x))
                      data)))
        (is (eql 2 (vec-ref result 0)))
        (let ((nested (vec-ref result 1)))
          (is (eql 3 (vec-ref nested 0)))
          (is (eql 4 (vec-ref nested 1))))
        (is (eql 5 (vec-ref result 2)))))

(test prewalk-order
      "Prewalk visits parent before children (pre-order)."
      (let* ((visited nil)
             (data (make-vec :a (make-vec :b :c))))
        (fol.walk:prewalk
         (lambda (x)
           (push x visited)
           x)
         data)
        (setf visited (nreverse visited))
        ;; First visited should be the outer vector [:a [:b :c]]
        (is (typep (cl:first visited) 'fol.compiler.collections:<vector>))
        ;; :a comes second (before the nested vector)
        (is (eq :a (cl:second visited)))))

(test prewalk-replace-basic
      "Prewalk-replace substitutes keys from a dict."
      (let* ((data (make-vec :a :b (make-vec :c :d)))
             (smap (make-dict :a 1 :b 2 :c 3 :d 4))
             (result (fol.walk:prewalk-replace smap data)))
        (is (eql 1 (vec-ref result 0)))
        (is (eql 2 (vec-ref result 1)))
        (let ((nested (vec-ref result 2)))
          (is (eql 3 (vec-ref nested 0)))
          (is (eql 4 (vec-ref nested 1))))))

(test prewalk-replace-nested
      "Prewalk-replace replaces parent before walking children."
      (let* ((inner (make-vec 1 2))
             (data (make-vec inner (make-vec 3 4)))
             (smap (make-dict inner :replaced)))
        (let ((result (fol.walk:prewalk-replace smap data)))
          ;; The vector [1 2] should be replaced with :replaced before we recurse
          (is (eq :replaced (vec-ref result 0))))))

;;; ---------------------------------------------------------------------------
;;; Postwalk Tests
;;; ---------------------------------------------------------------------------

(test postwalk-increment-numbers
      "Postwalk increments all numbers in a nested vector."
      (let* ((data (make-vec 1 (make-vec 2 3) 4))
             (result (fol.walk:postwalk
                      (lambda (x) (if (numberp x) (1+ x) x))
                      data)))
        (is (eql 2 (vec-ref result 0)))
        (let ((nested (vec-ref result 1)))
          (is (eql 3 (vec-ref nested 0)))
          (is (eql 4 (vec-ref nested 1))))
        (is (eql 5 (vec-ref result 2)))))

(test postwalk-order
      "Postwalk visits children before parent (post-order)."
      (let* ((visited nil)
             (data (make-vec :a (make-vec :b :c))))
        (fol.walk:postwalk
         (lambda (x)
           (push x visited)
           x)
         data)
        (setf visited (nreverse visited))
        ;; First visited should be :a (leaf)
        (is (eq :a (cl:first visited)))
        ;; :b comes next
        (is (eq :b (cl:second visited)))))

(test postwalk-replace-basic
      "Postwalk-replace substitutes keys from a dict."
      (let* ((data (make-vec :a :b (make-vec :c :d)))
             (smap (make-dict :a 1 :b 2 :c 3 :d 4))
             (result (fol.walk:postwalk-replace smap data)))
        (is (eql 1 (vec-ref result 0)))
        (is (eql 2 (vec-ref result 1)))
        (let ((nested (vec-ref result 2)))
          (is (eql 3 (vec-ref nested 0)))
          (is (eql 4 (vec-ref nested 1))))))

(test postwalk-replace-nested
      "Postwalk-replace replaces leaf values before parent sees them."
      (let* ((data (make-vec :x (make-vec :y :z)))
             ;; Replace leaf keywords with numbers
             (smap (make-dict :x 10 :y 20 :z 30)))
        (let ((result (fol.walk:postwalk-replace smap data)))
          ;; :x replaced with 10
          (is (eql 10 (vec-ref result 0)))
          ;; nested :y and :z replaced with 20 and 30
          (let ((nested (vec-ref result 1)))
            (is (eql 20 (vec-ref nested 0)))
            (is (eql 30 (vec-ref nested 1)))))))

;;; ---------------------------------------------------------------------------
;;; Prewalk vs Postwalk Difference
;;; ---------------------------------------------------------------------------

(test prewalk-vs-postwalk-replacement
      "Prewalk and postwalk produce different results for overlapping replacements."
      (let* ((data (make-vec 1 2))
             (smap (make-dict data (make-vec 3 4) 1 99)))
        (let ((pre-result (fol.walk:prewalk-replace smap data))
              (post-result (fol.walk:postwalk-replace smap data)))
          ;; Prewalk: [1 2] is replaced with [3 4] before walking children
          (is (eql 3 (vec-ref pre-result 0)))
          (is (eql 4 (vec-ref pre-result 1)))
          ;; Postwalk: 1 is replaced with 99 first, then [99 2] has no match
          (is (eql 99 (vec-ref post-result 0)))
          (is (eql 2 (vec-ref post-result 1))))))

;;; ---------------------------------------------------------------------------
;;; Complex Structure Tests
;;; ---------------------------------------------------------------------------

(test walk-nested-dict
      "Postwalk doubles all numbers in a nested dict."
      (let* ((user-dict (make-dict :name "Alice" :age 30))
             (scores (make-vec 10 20 30))
             (data (make-dict :user user-dict :scores scores))
             (result (fol.walk:postwalk
                      (lambda (x) (if (numberp x) (* x 2) x))
                      data)))
        (is (eql 60 (dict-ref (dict-ref result :user) :age)))
        (let ((new-scores (dict-ref result :scores)))
          (is (eql 20 (vec-ref new-scores 0)))
          (is (eql 40 (vec-ref new-scores 1)))
          (is (eql 60 (vec-ref new-scores 2))))))

(test walk-mixed-collections
      "Postwalk adds 10 to numbers across mixed collection types."
      (let* ((v (make-vec 1 2))
             (d (make-dict :a 3 :b 4))
             (s (make-fol-set 5 6))
             (data (make-vec v d s))
             (result (fol.walk:postwalk
                      (lambda (x) (if (numberp x) (+ x 10) x))
                      data)))
        ;; Vector element
        (let ((rv (vec-ref result 0)))
          (is (typep rv 'fol.compiler.collections:<vector>))
          (is (eql 11 (vec-ref rv 0))))
        ;; Dict element
        (let ((rd (vec-ref result 1)))
          (is (typep rd 'fol.compiler.collections:<dict>))
          (is (eql 13 (dict-ref rd :a))))
        ;; Set element
        (let ((rs (vec-ref result 2)))
          (is (typep rs 'fol.compiler.collections:<set>)))))

(test walk-deeply-nested
      "Walk handles deeply nested structures."
      (let* ((data (make-vec
                    (make-vec (make-vec 1 2) (make-vec 3 4))
                    (make-vec (make-vec 5 6) (make-vec 7 8))))
             (result (fol.walk:postwalk
                      (lambda (x)
                        (if (and (numberp x) (evenp x))
                            (* x 2)
                            x))
                      data)))
        (let* ((outer-first (vec-ref result 0))
               (inner-first (vec-ref outer-first 0)))
          (is (eql 1 (vec-ref inner-first 0))) ; odd, unchanged
          (is (eql 4 (vec-ref inner-first 1)))))) ; even, doubled

;;; ---------------------------------------------------------------------------
;;; Edge Cases
;;; ---------------------------------------------------------------------------

(test walk-empty-vector
      "Walk on empty vector returns empty vector."
      (let ((result (fol.walk:prewalk #'identity (make-vec))))
        (is (typep result 'fol.compiler.collections:<vector>))
        (is (eql 0 (vec-size result)))))

(test walk-empty-dict
      "Walk on empty dict returns empty dict."
      (let ((result (fol.walk:walk #'identity #'identity (make-dict))))
        (is (typep result 'fol.compiler.collections:<dict>))
        (is (eql 0 (fol.compiler.collections:collection-size result)))))

(test walk-empty-set
      "Walk on empty set returns empty set."
      (let ((result (fol.walk:postwalk #'identity (make-fol-set))))
        (is (typep result 'fol.compiler.collections:<set>))
        (is (eql 0 (fol.compiler.collections:collection-size result)))))

(test walk-single-element
      "Walk on single-element vector."
      (let ((result (fol.walk:prewalk
                     (lambda (x) (if (numberp x) (* x 2) x))
                     (make-vec 42))))
        (is (eql 84 (vec-ref result 0)))))

(test walk-nil-values
      "Walk handles nil values in vectors."
      (let ((result (fol.walk:prewalk #'identity (make-vec 1 nil 3))))
        (is (eql 1 (vec-ref result 0)))
        (is (null (vec-ref result 1)))
        (is (eql 3 (vec-ref result 2)))))

;;; ---------------------------------------------------------------------------
;;; Functional Composition Tests
;;; ---------------------------------------------------------------------------

(test walk-multiple-transformations
      "Multiple walk passes compose correctly."
      (let* ((data (make-vec 1 2 3))
             (step1 (fol.walk:prewalk
                     (lambda (x) (if (numberp x) (* x 2) x))
                     data))
             (step2 (fol.walk:postwalk
                     (lambda (x) (if (numberp x) (+ x 10) x))
                     step1)))
        ;; First multiply by 2: [2 4 6], then add 10: [12 14 16]
        (is (eql 12 (vec-ref step2 0)))
        (is (eql 14 (vec-ref step2 1)))
        (is (eql 16 (vec-ref step2 2)))))

(test walk-preserves-structure-type
      "Walk preserves the collection type of each structure."
      (let* ((vec (make-vec 1 2 3))
             (dict (make-dict :a 1 :b 2))
             (fset (make-fol-set 1 2 3)))
        (is (typep (fol.walk:postwalk #'identity vec) 'fol.compiler.collections:<vector>))
        (is (typep (fol.walk:postwalk #'identity dict) 'fol.compiler.collections:<dict>))
        (is (typep (fol.walk:postwalk #'identity fset) 'fol.compiler.collections:<set>))))

;;; ---------------------------------------------------------------------------
;;; Demo Tests
;;; ---------------------------------------------------------------------------

(test prewalk-demo-returns-unchanged
      "Prewalk-demo returns the form unchanged (just prints)."
      (let* ((data (make-vec 1 2 3))
             (result (with-output-to-string (*standard-output*)
                       (fol.walk:prewalk-demo data))))
        (is (stringp result))
        ;; Output should contain some printed representation
        (is (> (length result) 0))))

(test postwalk-demo-returns-unchanged
      "Postwalk-demo returns the form unchanged (just prints)."
      (let* ((data (make-vec 1 2 3))
             (result (with-output-to-string (*standard-output*)
                       (fol.walk:postwalk-demo data))))
        (is (stringp result))
        (is (> (length result) 0))))
