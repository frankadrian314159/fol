;;; FOL Library - Parallel Collections
;;;
;;; Parallel versions of collection operations that have no parallel counterpart
;;; in the base library. Mirrors the Scala parallel-collections API.
;;;
;;; All functions dispatch element-level work to the global thread pool via
;;; fol.compiler.mutable:submit-work / wait-for-work. The calling thread
;;; waits for all work items to finish before assembling the result.
;;;
;;; Ordering guarantee: element ordering relative to the input is preserved
;;; in all functions.
;;;
;;; Thread pool sizing: controlled by fol.compiler.mutable:*thread-pool-size*
;;; (default 16). For collections smaller than the pool size every element gets
;;; its own worker; for larger collections work is queued naturally.

(in-package :fol.lib.parallel)

;;; ---------------------------------------------------------------------------
;;; pfilter — parallel filter
;;; ---------------------------------------------------------------------------

(defun pfilter (pred coll)
  "Parallel version of filter. Tests each element with PRED on the thread pool.
   Returns a collection of the same type as COLL containing only elements for
   which PRED returns a truthy value. Element ordering is preserved.

   Examples:
     (pfilter odd?  [1 2 3 4 5])   => [1 3 5]
     (pfilter even? #{1 2 3 4})    => #{2 4}  ; set order may vary"
  (let* ((seq (fol.compiler.collections:collection-seq coll))
         ;; Submit one predicate test per element.
         ;; Each work-item is (elem . future) so we can reconstruct order.
         (futures (cl:mapcar (lambda (elem)
                               (cons elem
                                     (fol.compiler.mutable:submit-work pred (list elem))))
                   seq))
         ;; Collect results; keep elements whose predicate returned truthy.
         (passing (cl:remove-if-not
                   (lambda (pair)
                     (fol.compiler.primitives:truthy?
                      (fol.compiler.mutable:wait-for-work (cdr pair))))
                   futures)))
    (cl:apply #'fol.compiler.collections:make
              (cl:class-name (cl:class-of coll))
              (cl:mapcar #'car passing))))

;;; ---------------------------------------------------------------------------
;;; pgroup-by — parallel group-by
;;; ---------------------------------------------------------------------------

(defun pgroup-by (fn coll)
  "Parallel version of group-by. Applies FN to every element on the thread pool
   to compute its group key, then assembles the result dict serially.
   Returns a dict of {key [elements]} where key = (fn element).
   Element ordering within each group matches the input ordering.

   Examples:
     (pgroup-by even? [1 2 3 4 5])         => {nil [1 3 5]  t [2 4]}
     (pgroup-by #'cl:floor [1.1 1.9 2.3])  => {1 [1.1 1.9]  2 [2.3]}"
  (let* ((seq (fol.compiler.collections:collection-seq coll))
         ;; Compute the group key for each element in parallel.
         (futures (cl:mapcar (lambda (elem)
                               (cons elem
                                     (fol.compiler.mutable:submit-work fn (list elem))))
                   seq))
         ;; Collect (key . elem) pairs in original order.
         (keyed (cl:mapcar (lambda (pair)
                             (cons (fol.compiler.mutable:wait-for-work (cdr pair))
                                   (car pair)))
                 futures))
         ;; Group into a CL hash-table (serial — dict merging requires coordination).
         (buckets (make-hash-table :test 'equal)))
    (dolist (pair keyed)
      (push (cdr pair) (gethash (car pair) buckets nil)))
    ;; Build the FOL dict from the buckets; reverse each bucket to restore order.
    (let ((d (fol.compiler.collections:make 'fol.compiler.collections:<dict>)))
      (maphash (lambda (k vs)
                 (setf d (fol.compiler.collection-functions:assoc
                          d k
                          (cl:apply #'fol.compiler.collections:make
                                    'fol.compiler.collections:<vector>
                                    (nreverse vs)))))
               buckets)
      d)))

;;; ---------------------------------------------------------------------------
;;; ppartition — parallel partition by predicate
;;;
;;; NOTE: This is Scala's partition(pred) — split into (passing, failing) —
;;;       not FOL's partition-by-size. For grouping by N, use fol's partition.
;;; ---------------------------------------------------------------------------

(defun ppartition (pred coll)
  "Parallel partition by predicate. Tests each element with PRED on the thread
   pool, then splits the collection into two groups.

   Returns a two-element vector [matching non-matching] where each group is
   the same collection type as COLL. Element ordering within each group is
   preserved.

   Examples:
     (ppartition odd?  [1 2 3 4 5])   => [[1 3 5] [2 4]]
     (ppartition pos?  [-1 2 -3 4])   => [[2 4] [-1 -3]]"
  (let* ((seq (fol.compiler.collections:collection-seq coll))
         ;; Test predicate for every element in parallel.
         (futures (cl:mapcar (lambda (elem)
                               (cons elem
                                     (fol.compiler.mutable:submit-work pred (list elem))))
                   seq))
         ;; Collect (elem . truthy?) in original order.
         (results (cl:mapcar (lambda (pair)
                               (cons (car pair)
                                     (fol.compiler.primitives:truthy?
                                      (fol.compiler.mutable:wait-for-work (cdr pair)))))
                  futures))
         (passing (cl:mapcar #'car (cl:remove-if-not #'cdr results)))
         (failing (cl:mapcar #'car (cl:remove-if     #'cdr results)))
         (cls (cl:class-name (cl:class-of coll))))
    (fol.compiler.collections:make
     'fol.compiler.collections:<vector>
     (cl:apply #'fol.compiler.collections:make cls passing)
     (cl:apply #'fol.compiler.collections:make cls failing))))

;;; ---------------------------------------------------------------------------
;;; pzip — parallel zip of two collections
;;; ---------------------------------------------------------------------------

(defun pzip (coll1 coll2)
  "Pair corresponding elements from COLL1 and COLL2, building each pair on the
   thread pool. Stops at the shorter collection.
   Returns a vector of two-element vectors [a b].

   Note: element pairing is intrinsically cheap; the parallelism here is most
   useful when the caller will subsequently apply expensive transformations to
   each pair using pmap.

   Examples:
     (pzip [1 2 3] [:a :b :c])   => [[1 :a] [2 :b] [3 :c]]
     (pzip [1 2]   [10 20 30])   => [[1 10] [2 20]]"
  (let* ((seq1 (fol.compiler.collections:collection-seq coll1))
         (seq2 (fol.compiler.collections:collection-seq coll2))
         (pairs (cl:mapcar #'list seq1 seq2))
         (futures (cl:mapcar
                   (lambda (pair)
                     (fol.compiler.mutable:submit-work
                      (lambda (a b)
                        (fol.compiler.collections:make
                         'fol.compiler.collections:<vector> a b))
                      pair))
                   pairs))
         (results (cl:mapcar #'fol.compiler.mutable:wait-for-work futures)))
    (cl:apply #'fol.compiler.collections:make
              'fol.compiler.collections:<vector> results)))

;;; ---------------------------------------------------------------------------
;;; pzip-with-index — parallel zip with positional index
;;; ---------------------------------------------------------------------------

(defun pzip-with-index (coll)
  "Pair each element of COLL with its zero-based positional index on the thread
   pool. Returns a vector of two-element vectors [element index].

   Examples:
     (pzip-with-index [:a :b :c])      => [[:a 0] [:b 1] [:c 2]]
     (pzip-with-index [100 200 300])   => [[100 0] [200 1] [300 2]]"
  (let* ((seq (fol.compiler.collections:collection-seq coll))
         (indexed (cl:loop for elem in seq for i from 0 collect (list elem i)))
         (futures (cl:mapcar
                   (lambda (pair)
                     (fol.compiler.mutable:submit-work
                      (lambda (elem idx)
                        (fol.compiler.collections:make
                         'fol.compiler.collections:<vector> elem idx))
                      pair))
                   indexed))
         (results (cl:mapcar #'fol.compiler.mutable:wait-for-work futures)))
    (cl:apply #'fol.compiler.collections:make
              'fol.compiler.collections:<vector> results)))

;;; ---------------------------------------------------------------------------
;;; pforeach — parallel for-each (side effects)
;;; ---------------------------------------------------------------------------

(defun pforeach (fn coll)
  "Apply FN to every element of COLL in parallel for side effects.
   All elements are dispatched to the thread pool simultaneously; this function
   blocks until every invocation has completed. Returns nil.

   The order in which FN is called across elements is unspecified. If the
   side effects must be ordered, use the serial run! instead.

   Examples:
     (pforeach println [1 2 3])   ; prints 1, 2, 3 in some order, returns nil"
  (let* ((seq (fol.compiler.collections:collection-seq coll))
         (futures (cl:mapcar (lambda (elem)
                               (fol.compiler.mutable:submit-work fn (list elem)))
                   seq)))
    (dolist (f futures) (fol.compiler.mutable:wait-for-work f))
    nil))

;;; ---------------------------------------------------------------------------
;;; pfind — parallel find (first matching element by input order)
;;; ---------------------------------------------------------------------------

(defun pfind (pred coll)
  "Test every element of COLL with PRED in parallel. Return the first element
   (in input order) for which PRED returns a truthy value, or nil if none match.

   All predicate tests are submitted to the thread pool at once; the result is
   the positionally-earliest match, not the one whose test finishes first.

   Examples:
     (pfind even? [1 3 4 6])   => 4
     (pfind even? [1 3 5])     => nil"
  (let* ((seq (fol.compiler.collections:collection-seq coll))
         (futures (cl:mapcar (lambda (elem)
                               (cons elem
                                     (fol.compiler.mutable:submit-work pred (list elem))))
                   seq)))
    (dolist (pair futures)
      (when (fol.compiler.primitives:truthy?
             (fol.compiler.mutable:wait-for-work (cdr pair)))
        (return (car pair))))))

;;; ---------------------------------------------------------------------------
;;; pexists — parallel existential test (any element satisfies pred?)
;;; ---------------------------------------------------------------------------

(defun pexists (pred coll)
  "Return t if PRED returns a truthy value for at least one element of COLL,
   nil otherwise. All predicate tests run on the thread pool in parallel.

   Analogous to Scala's .par.exists(pred) and Clojure's (some pred coll)
   coerced to a boolean.

   Examples:
     (pexists even? [1 3 4 6])   => t
     (pexists even? [1 3 5])     => nil"
  (let* ((seq (fol.compiler.collections:collection-seq coll))
         (futures (cl:mapcar (lambda (elem)
                               (fol.compiler.mutable:submit-work pred (list elem)))
                   seq)))
    (if (cl:some (lambda (f)
                   (fol.compiler.primitives:truthy?
                    (fol.compiler.mutable:wait-for-work f)))
                 futures)
        t
        nil)))

;;; ---------------------------------------------------------------------------
;;; pforall — parallel universal test (all elements satisfy pred?)
;;; ---------------------------------------------------------------------------

(defun pforall (pred coll)
  "Return t if PRED returns a truthy value for every element of COLL,
   nil otherwise. All predicate tests run on the thread pool in parallel.

   Analogous to Scala's .par.forall(pred) and Clojure's (every? pred coll).

   Examples:
     (pforall even? [2 4 6])   => t
     (pforall even? [2 3 6])   => nil"
  (let* ((seq (fol.compiler.collections:collection-seq coll))
         (futures (cl:mapcar (lambda (elem)
                               (fol.compiler.mutable:submit-work pred (list elem)))
                   seq)))
    (if (cl:every (lambda (f)
                    (fol.compiler.primitives:truthy?
                     (fol.compiler.mutable:wait-for-work f)))
                  futures)
        t
        nil)))

;;; ---------------------------------------------------------------------------
;;; pcount — parallel count of elements satisfying a predicate
;;; ---------------------------------------------------------------------------

(defun pcount (pred coll)
  "Count the elements of COLL for which PRED returns a truthy value.
   All predicate tests run on the thread pool in parallel.

   Analogous to Scala's .par.count(pred).

   Examples:
     (pcount even? [1 2 3 4 5])   => 2
     (pcount odd?  [1 2 3 4 5])   => 3
     (pcount pos?  [-1 -2 3])     => 1"
  (let* ((seq (fol.compiler.collections:collection-seq coll))
         (futures (cl:mapcar (lambda (elem)
                               (fol.compiler.mutable:submit-work pred (list elem)))
                   seq)))
    (cl:count-if (lambda (f)
                   (fol.compiler.primitives:truthy?
                    (fol.compiler.mutable:wait-for-work f)))
                 futures)))
