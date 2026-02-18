;;; FOL Compiler - Relational Functions
;;;
;;; Implementation of Clojure-style relational algebra functions.
;;; These functions operate on sets of maps.

(in-package :fol.compiler.relational)

;;; Basic Set Operations


(defun project (xset keys)
  "Returns a set of the maps in xset with only the specified keys.
   Equivalent to SQL SELECT keys FROM xset."
  (let ((ks (if (listp keys) keys (collection-seq (if (typep keys '<collection>) keys (vec keys)))))) ; Ensure keys is a list for select-keys
    (into (empty xset)
          (map (lambda (m)
                 (select-keys m ks)) ; Assuming select-keys available
               xset))))

(defun rename (xset kmap)
  "Returns a set of the maps in xset with keys renamed according to kmap."
  (into (empty xset)
        (map (lambda (m)
               (rename-keys m kmap)) ; Assuming rename-keys available
             xset)))

(defun universal-compare (a b)
  "Compare two arbitrary values. Returns -1 (<), 0 (=), 1 (>)."
  (cond
   ((eql a b) 0)
   ((null a) -1)
   ((null b) 1)
   ((and (numberp a) (numberp b))
     (cond ((< a b) -1) ((> a b) 1) (t 0)))
   ((and (stringp a) (stringp b))
     (cond ((string< a b) -1) ((string> a b) 1) (t 0)))
   ((and (symbolp a) (symbolp b))
     (let ((sa (symbol-name a)) (sb (symbol-name b)))
       (cond ((string< sa sb) -1) ((string> sa sb) 1) (t 0))))
   ((and (typep a 'fol.compiler.collections:<dict>) (typep b 'fol.compiler.collections:<dict>))
     ;; Compare dicts by sorted keys then values
     (let* ((ka (sort (fol.compiler.collections:collection-seq (keys a)) #'universal-compare))
            (kb (sort (fol.compiler.collections:collection-seq (keys b)) #'universal-compare))
            (c (universal-compare ka kb)))
       (if (zerop c)
           (loop for k in ka
                 for va = (get a k)
                 for vb = (get b k)
                 for cv = (universal-compare va vb)
                   unless (zerop cv) return cv
                 finally (return 0))
           c)))
   ((and (or (listp a) (typep a 'fol.compiler.collections:<collection>))
         (or (listp b) (typep b 'fol.compiler.collections:<collection>)))
     ;; Compare sequences
     (let ((sa (if (listp a) a (fol.compiler.collections:collection-seq a)))
           (sb (if (listp b) b (fol.compiler.collections:collection-seq b))))
       (loop for xa in sa
             for xb in sb
             for c = (universal-compare xa xb)
               unless (zerop c) return c
             finally (return (cond ((< (length sa) (length sb)) -1)
                                   ((> (length sa) (length sb)) 1)
                                   (t 0))))))
   (t 0))) ; Fallback

(defun index (xset keys)
  "Returns a map of the elements of xset indexed by the result of applying generic select behavior.
   Wait, Clojure index groups by 'keys' which is a vector of keys usually?
   (index xrel [:a :b]) -> returns map of key-val to set of matching rows?
   Clojure docs: index [xrel ks] Returns a map of the distinct values of ks in the xrel mapped to a set of the elements of xrel with that value."
  (let* ((ks-list (if (listp keys) keys (collection-seq (if (typep keys '<collection>) keys (vec keys)))))
         (key-fn (lambda (m) (select-keys m ks-list))))
    (reduce (lambda (acc m)
              (let ((k (funcall key-fn m)))
                (assoc acc k (conj (get acc k (empty xset)) m))))
            (make '<sorted-dict> #'universal-compare) ; Use sorted-dict with value comparison
            xset)))

(defun diff (a b)
  "Recursively diff two data structures A and B.
   Returns a three-element vector [a-only b-only both] where:
   - a-only: data only in A (nil if empty)
   - b-only: data only in B (nil if empty)
   - both:   data present in both (nil if empty)

   For maps: recursively diffs corresponding values for shared keys.
   For sets: uses set operations (difference, intersection).
   For other values: [A B nil] if unequal, [nil nil A] if equal.

   Examples:
     (diff {:a 1 :b 2} {:a 1 :b 3}) => [{:b 2} {:b 3} {:a 1}]
     (diff #{1 2 3} #{1 2 4})       => [#{3} #{4} #{1 2}]
     (diff 1 1)                     => [nil nil 1]
     (diff 1 2)                     => [1 2 nil]"
  (cond
   ;; Both are dicts/maps: recursively diff by key
   ((and (typep a 'fol.compiler.collections:<dict>)
         (typep b 'fol.compiler.collections:<dict>))
     (let ((a-only (empty a))
           (b-only (empty b))
           (both-map (empty a)))
       ;; Keys present in a
       (dolist (k (collection-seq (keys a)))
         (if (contains? b k)
             (let* ((inner (diff (get a k) (get b k)))
                    (ia (fol.compiler.collection-functions:nth inner 0))
                    (ib (fol.compiler.collection-functions:nth inner 1))
                    (iboth (fol.compiler.collection-functions:nth inner 2)))
               (when ia (setf a-only (assoc a-only k ia)))
               (when ib (setf b-only (assoc b-only k ib)))
               (when iboth (setf both-map (assoc both-map k iboth))))
             (setf a-only (assoc a-only k (get a k)))))
       ;; Keys present only in b
       (dolist (k (collection-seq (keys b)))
         (unless (contains? a k)
           (setf b-only (assoc b-only k (get b k)))))
       (fol.compiler.collection-functions:vector
        (and (not (empty? a-only)) a-only)
        (and (not (empty? b-only)) b-only)
        (and (not (empty? both-map)) both-map))))
   ;; Both are sets: use set operations
   ((and (typep a 'fol.compiler.collections:<set>)
         (typep b 'fol.compiler.collections:<set>))
     (let ((a-only (difference a b))
           (b-only (difference b a))
           (both-set (intersection a b)))
       (fol.compiler.collection-functions:vector
        (and (not (empty? a-only)) a-only)
        (and (not (empty? b-only)) b-only)
        (and (not (empty? both-set)) both-set))))
   ;; Scalars or other values
   (t
     (if (equal a b)
         (fol.compiler.collection-functions:vector nil nil a)
         (fol.compiler.collection-functions:vector a b nil)))))
