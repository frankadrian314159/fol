;;; FOL Compiler - Merged Functions
;;;
;;; Contains polymorphic functions that dispatch to different implementations
;;; based on their argument types. Currently handles:
;;; - join: String join (separator coll) or relational natural join (xrel yrel)

(in-package :fol.compiler.merged-functions)

(defun %relational-join (xrel yrel &optional km)
  "Natural join of two relations (sets of dicts).
   Returns the set of all dicts formed by merging an element of XREL and
   an element of YREL that share the same values for their common keys.
   If KM is supplied, it maps keys in XREL to corresponding keys in YREL."
  (let ((xseq (fol.compiler.collections:collection-seq xrel))
        (yseq (fol.compiler.collections:collection-seq yrel)))
    (if km
        ;; Keyed join: KM maps xrel-key -> yrel-key
        (let ((km-seq (fol.compiler.collections:collection-seq
                       (fol.compiler.seq-functions:keys km)))
              (result (fol.compiler.collection-functions:set)))
          (dolist (x xseq result)
            (dolist (y yseq)
              (when (every (lambda (xk)
                             (let ((yk (fol.compiler.collection-functions:get km xk)))
                               (equal (fol.compiler.collection-functions:get x xk)
                                      (fol.compiler.collection-functions:get y yk))))
                        km-seq)
                    (setf result (fol.compiler.collection-functions:conj
                                  result
                                  (fol.compiler.collection-functions:merge x y)))))))
        ;; Natural join: find shared keys from first elements
        (if (or (null xseq) (null yseq))
            (fol.compiler.collection-functions:set)
            (let* ((x-keys (fol.compiler.collections:collection-seq
                            (fol.compiler.seq-functions:keys (cl:first xseq))))
                   (y-keys (fol.compiler.collections:collection-seq
                            (fol.compiler.seq-functions:keys (cl:first yseq))))
                   (shared (cl:intersection x-keys y-keys :test #'equal))
                   (result (fol.compiler.collection-functions:set)))
              (dolist (x xseq result)
                (dolist (y yseq)
                  (when (every (lambda (k)
                                 (equal (fol.compiler.collection-functions:get x k)
                                        (fol.compiler.collection-functions:get y k)))
                            shared)
                        (setf result (fol.compiler.collection-functions:conj
                                      result
                                      (fol.compiler.collection-functions:merge x y)))))))))))

(defun join (&rest args)
  "Polymorphic join function.
   - If args are (separator collection), performs string join.
   - If args are (xrel yrel &optional km), performs relational natural join."
  (let ((arg1 (first args))
        (arg2 (second args))
        (arg3 (third args))
        (nargs (length args)))
    (declare (ignore arg3))
    (cond
     ;; Case 1: String join (separator coll)
     ((and (= nargs 2)
           (or (stringp arg1) (characterp arg1)))
       (let ((separator (if (characterp arg1) (string arg1) arg1))
             (seq (if (listp arg2)
                      arg2
                      (fol.compiler.collections:collection-seq arg2))))
         (if (null seq)
             ""
             (apply #'fol.compiler.string-functions:str
               (cons (cl:first seq)
                     (mapcan (lambda (x) (cl:list separator x))
                         (cl:rest seq)))))))

     ;; Case 2: Relational join (xrel yrel &optional km)
     ((and (>= nargs 2)
           (<= nargs 3)
           (or (typep arg1 'fol.compiler.collections:<collection>) (listp arg1))
           (or (typep arg2 'fol.compiler.collections:<collection>) (listp arg2)))
       (apply #'%relational-join (cl:subseq args 0 nargs)))

     (t
       (error "Invalid arguments to join: ~S. Expected (str/char coll) or (coll coll [dict])." args)))))

(defun replace (&rest args)
  "Polymorphic replace function.
   - If args are (smap coll), where smap is a dict and coll is an ordered-collection,
     returns a new collection of the same type with keys in smap replaced by values.
   - If args are (s match replacement &key use-regex), performs string replacement.
     match can be a character or string. generic regex logic is applied if specified."
  (let ((nargs (length args)))
    (cond
     ;; Case 1: Collection replacement (smap coll)
     ((and (= nargs 2)
           (typep (first args) 'fol.compiler.collections:<dict>)
           (typep (second args) 'fol.compiler.collections:<ordered-collection>))
       (let* ((smap (first args))
              (coll (second args))
              (seq (fol.compiler.collections:collection-seq coll))
              (new-seq (mapcar (lambda (elem)
                                 (multiple-value-bind (replacement found)
                                     (fol.compiler.collections:get smap elem)
                                   (if found replacement elem)))
                           seq)))
         (apply #'fol.compiler.collections:make
           (class-name (class-of coll))
           new-seq)))

     ;; Case 2: String replacement (s match replacement &key use-regex)
     ((and (>= nargs 3)
           (stringp (first args))
           (or (stringp (second args)) (characterp (second args)))
           (stringp (third args)))
       (let ((s (first args))
             (match (second args))
             (replacement (third args))
             (use-regex (let ((k (member :use-regex (cdddr args))))
                          (and k (cadr k)))))
         (cond
          ((characterp match)
            ;; Character match
            (if use-regex
                (cl-ppcre:regex-replace-all (string match) s replacement)
                (with-output-to-string (out)
                  (loop for c across s
                        do (if (char= c match)
                               (write-string replacement out)
                               (write-char c out))))))
          ((stringp match)
            ;; String match
            (if use-regex
                ;; Regex replacement using CL-PPCRE
                (cl-ppcre:regex-replace-all match s replacement)
                ;; Literal string replacement
                (let ((result s)
                      (match-len (length match)))
                  (loop
                   (let ((pos (search match result)))
                     (if pos
                         (setf result (concatenate 'string
                                        (subseq result 0 pos)
                                        replacement
                                        (subseq result (+ pos match-len))))
                         (return result))))))))))

     (t
       (error "Invalid arguments to replace: ~S. Expected (dict ordered-coll) or (string match replacement &key use-regex)." args)))))

;;; ===========================================================================
;;; Reduced (Early Termination for Transducers)
;;; ===========================================================================

(defstruct reduced
  val)

(defun reduced (val)
  "Wraps VAL to signal early termination in a transduction."
  (make-reduced :val val))

(defun reduced? (x)
  "Returns true if X is a reduced value (early termination wrapper)."
  (typep x 'reduced))

(defun unreduced (x)
  "If X is reduced, unwraps it; otherwise returns X as-is."
  (if (reduced? x) (reduced-val x) x))

(defun ensure-reduced (x)
  "If X is already reduced, returns it; otherwise wraps it."
  (if (reduced? x) x (reduced x)))

;;; ===========================================================================
;;; Higher-Order Collection Functions
;;; ===========================================================================

;;; ---------------------------------------------------------------------------
;;; map - Apply function to each element of collection(s), or return transducer
;;; ---------------------------------------------------------------------------

(defun map (fn &rest args)
  "Apply FN to elements of collection(s). With no collection args, returns a transducer.
   (map f)              => transducer
   (map f coll)         => mapped collection
   (map f coll & colls) => zip-mapped collection

   Examples:
     (map inc [1 2 3])           => [2 3 4]
     (map + [1 2 3] [10 20 30])  => [11 22 33]
     (map inc)                   => transducer"
  (if (null args)
      ;; Transducer: (map f) => transducer
      (lambda (rf)
        (lambda (&optional (acc nil acc-p) (input nil input-p))
          (cond
           ((not acc-p) (funcall rf))
           ((not input-p) (funcall rf acc))
           (t (funcall rf acc (funcall fn input))))))
      ;; Sequence function: (map f coll ...) => collection
      (let ((coll (cl:first args))
            (colls (cl:rest args)))
        (if colls
            ;; Multiple collections - zip them
            (let* ((seqs (cl:cons (fol.compiler.collections:collection-seq coll)
                                  (cl:mapcar #'fol.compiler.collections:collection-seq colls)))
                   (results (cl:apply #'cl:mapcar fn seqs)))
              (cl:apply #'fol.compiler.collections:make (class-name (class-of coll)) results))
            ;; Single collection
            (let* ((seq (fol.compiler.collections:collection-seq coll))
                   (results (cl:mapcar fn seq)))
              (cl:apply #'fol.compiler.collections:make (class-name (class-of coll)) results))))))

;;; ---------------------------------------------------------------------------
;;; mapcat - map followed by concatenation
;;; ---------------------------------------------------------------------------

(defun mapcat (fn &rest args)
  "Apply FN to each element, then concatenate results. With no collection, returns transducer.

   Examples:
     (mapcat (fn [x] [x (* x 2)]) [1 2 3]) => [1 2 2 4 3 6]
     (mapcat (fn [x] [x (* x 2)]))          => transducer"
  (if (null args)
      ;; Transducer
      (lambda (rf)
        (lambda (&optional (acc nil acc-p) (input nil input-p))
          (cond
           ((not acc-p) (funcall rf))
           ((not input-p) (funcall rf acc))
           (t (let ((coll (funcall fn input)))
                (let ((iter (fol.compiler.collections:collection-seq coll))
                      (current-acc acc))
                  (cl:loop for item in iter
                  do (let ((res (funcall rf current-acc item)))
                       (if (reduced? res)
                           (return res)
                           (setf current-acc res)))
                  finally (return current-acc))))))))
      ;; Sequence function
      (let ((coll (cl:first args)))
        (let* ((seq (fol.compiler.collections:collection-seq coll))
               (mapped (cl:mapcar fn seq))
               (seqs (cl:mapcar #'fol.compiler.collections:collection-seq mapped))
               (flattened (cl:apply #'cl:append seqs)))
          (cl:apply #'fol.compiler.collections:make (class-name (class-of coll)) flattened)))))

;;; ---------------------------------------------------------------------------
;;; filter - Keep elements that satisfy predicate
;;; ---------------------------------------------------------------------------

(defun filter (pred &rest args)
  "Keep elements where (PRED element) is truthy. With no collection, returns transducer.

   Examples:
     (filter odd? [1 2 3 4 5])  => [1 3 5]
     (filter odd?)               => transducer"
  (if (null args)
      ;; Transducer
      (lambda (rf)
        (lambda (&optional (acc nil acc-p) (input nil input-p))
          (cond
           ((not acc-p) (funcall rf))
           ((not input-p) (funcall rf acc))
           (t (if (fol.compiler.primitives:truthy? (funcall pred input))
                  (funcall rf acc input)
                  acc)))))
      ;; Sequence function
      (let ((coll (cl:first args)))
        (let* ((seq (fol.compiler.collections:collection-seq coll))
               (filtered (cl:remove-if-not (lambda (x)
                                             (fol.compiler.primitives:truthy? (funcall pred x)))
                           seq)))
          (cl:apply #'fol.compiler.collections:make (class-name (class-of coll)) filtered)))))

;;; ---------------------------------------------------------------------------
;;; remove - Inverse of filter
;;; ---------------------------------------------------------------------------

(defun remove (pred &rest args)
  "Keep elements where (PRED element) is falsy. With no collection, returns transducer.

   Examples:
     (remove odd? [1 2 3 4 5])  => [2 4]
     (remove odd?)               => transducer"
  (if (null args)
      ;; Transducer: complement of filter
      (filter (cl:complement pred))
      ;; Sequence function
      (let ((coll (cl:first args)))
        (let* ((seq (fol.compiler.collections:collection-seq coll))
               (kept (cl:remove-if (lambda (x)
                                     (fol.compiler.primitives:truthy? (funcall pred x)))
                       seq)))
          (cl:apply #'fol.compiler.collections:make (class-name (class-of coll)) kept)))))

;;; ---------------------------------------------------------------------------
;;; keep - map but remove nil results
;;; ---------------------------------------------------------------------------

(defun keep (fn &rest args)
  "Apply FN and keep non-nil results. With no collection, returns transducer.

   Examples:
     (keep (fn [x] (if (odd? x) (* x 2) nil)) [1 2 3 4 5]) => [2 6 10]
     (keep (fn [x] (if (odd? x) (* x 2) nil)))               => transducer"
  (if (null args)
      ;; Transducer
      (lambda (rf)
        (lambda (&optional (acc nil acc-p) (input nil input-p))
          (cond
           ((not acc-p) (funcall rf))
           ((not input-p) (funcall rf acc))
           (t (let ((result (funcall fn input)))
                (if result
                    (funcall rf acc result)
                    acc))))))
      ;; Sequence function
      (let ((coll (cl:first args)))
        (let* ((seq (fol.compiler.collections:collection-seq coll))
               (results (cl:mapcar fn seq))
               (kept (cl:remove-if #'null results)))
          (cl:apply #'fol.compiler.collections:make (class-name (class-of coll)) kept)))))

;;; ---------------------------------------------------------------------------
;;; take - Take first n elements
;;; ---------------------------------------------------------------------------

(defun take (n &rest args)
  "Take first N elements from COLL. With no collection, returns transducer.

   Examples:
     (take 3 [1 2 3 4 5])  => [1 2 3]
     (take 3)               => transducer"
  (if (null args)
      ;; Transducer
      (lambda (rf)
        (let ((counter 0))
          (lambda (&optional (acc nil acc-p) (input nil input-p))
            (cond
             ((not acc-p) (funcall rf))
             ((not input-p) (funcall rf acc))
             (t (if (< counter n)
                    (let ((result (funcall rf acc input)))
                      (incf counter)
                      (if (>= counter n)
                          (ensure-reduced result)
                          result))
                    (ensure-reduced acc)))))))
      ;; Sequence function
      (let ((coll (cl:first args)))
        (if (typep coll 'fol.compiler.collections:<lazy-seq>)
            ;; Lazy-seq: iterate using realize-lazy-seq to avoid full realization
            (let ((result '())
                  (current coll)
                  (count 0))
              (cl:loop while (and (< count n) current
                                  (typep current 'fol.compiler.collections:<lazy-seq>))
              do (let* ((realized (fol.compiler.collections:realize-lazy-seq current))
                        (head (when (typep realized 'fol.compiler.collections:<list>)
                                    (fol.compiler.collections:list-first realized)))
                        (tail (when (typep realized 'fol.compiler.collections:<list>)
                                    (fol.compiler.collections:list-rest realized))))
                   (push head result)
                   (incf count)
                   (setf current tail)))
              (cl:apply #'fol.compiler.collections:make
                'fol.compiler.collections:<vector>
                (nreverse result)))
            ;; Eager collections: use collection-seq
            (let* ((seq (fol.compiler.collections:collection-seq coll))
                   (taken (cl:subseq seq 0 (cl:min n (length seq)))))
              (cl:apply #'fol.compiler.collections:make
                'fol.compiler.collections:<vector>
                taken))))))

;;; ---------------------------------------------------------------------------
;;; drop - Drop first n elements
;;; ---------------------------------------------------------------------------

(defun drop (n &rest args)
  "Drop first N elements from COLL. With no collection, returns transducer.

   Examples:
     (drop 2 [1 2 3 4 5])  => [3 4 5]
     (drop 2)               => transducer"
  (if (null args)
      ;; Transducer
      (lambda (rf)
        (let ((counter 0))
          (lambda (&optional (acc nil acc-p) (input nil input-p))
            (cond
             ((not acc-p) (funcall rf))
             ((not input-p) (funcall rf acc))
             (t (if (< counter n)
                    (progn (incf counter) acc)
                    (funcall rf acc input)))))))
      ;; Sequence function
      (let ((coll (cl:first args)))
        (let* ((seq (fol.compiler.collections:collection-seq coll))
               (dropped (cl:nthcdr n seq)))
          (cl:apply #'fol.compiler.collections:make (class-name (class-of coll)) dropped)))))

;;; ---------------------------------------------------------------------------
;;; take-while - Take elements while predicate is true
;;; ---------------------------------------------------------------------------

(defun take-while (pred &rest args)
  "Take elements while PRED is truthy. With no collection, returns transducer.

   Examples:
     (take-while (fn [x] (< x 5)) [1 2 3 4 5 6 1 2]) => [1 2 3 4]
     (take-while even?)                                 => transducer"
  (if (null args)
      ;; Transducer
      (lambda (rf)
        (lambda (&optional (acc nil acc-p) (input nil input-p))
          (cond
           ((not acc-p) (funcall rf))
           ((not input-p) (funcall rf acc))
           (t (if (fol.compiler.primitives:truthy? (funcall pred input))
                  (funcall rf acc input)
                  (ensure-reduced acc))))))
      ;; Sequence function
      (let ((coll (cl:first args)))
        (let ((seq (fol.compiler.collections:collection-seq coll))
              (result '()))
          (cl:loop for elem in seq
          while (fol.compiler.primitives:truthy? (funcall pred elem))
          do (push elem result))
          (cl:apply #'fol.compiler.collections:make (class-name (class-of coll)) (nreverse result))))))

;;; ---------------------------------------------------------------------------
;;; drop-while - Drop elements while predicate is true
;;; ---------------------------------------------------------------------------

(defun drop-while (pred &rest args)
  "Drop elements while PRED is truthy. With no collection, returns transducer.

   Examples:
     (drop-while (fn [x] (< x 5)) [1 2 3 4 5 6 1 2]) => [5 6 1 2]
     (drop-while even?)                                 => transducer"
  (if (null args)
      ;; Transducer
      (lambda (rf)
        (let ((dropping t))
          (lambda (&optional (acc nil acc-p) (input nil input-p))
            (cond
             ((not acc-p) (funcall rf))
             ((not input-p) (funcall rf acc))
             (t (if dropping
                    (if (fol.compiler.primitives:truthy? (funcall pred input))
                        acc
                        (progn
                         (setf dropping nil)
                         (funcall rf acc input)))
                    (funcall rf acc input)))))))
      ;; Sequence function
      (let ((coll (cl:first args)))
        (let ((seq (fol.compiler.collections:collection-seq coll)))
          (cl:loop for tail on seq
            when (cl:not (fol.compiler.primitives:truthy? (funcall pred (car tail))))
            return (cl:apply #'fol.compiler.collections:make (class-name (class-of coll)) tail)
          finally (return (fol.compiler.collections:make (class-name (class-of coll)))))))))

;;; ---------------------------------------------------------------------------
;;; keep-indexed - keep with index
;;; ---------------------------------------------------------------------------

(defun keep-indexed (fn &rest args)
  "Apply FN to (index, element) and keep non-nil results. With no collection, returns transducer.

   Examples:
     (keep-indexed (fn [i x] (if (odd? i) x nil)) [0 1 2 3 4]) => [1 3]
     (keep-indexed (fn [i x] (if (odd? i) x nil)))               => transducer"
  (if (null args)
      ;; Transducer
      (lambda (rf)
        (let ((idx -1))
          (lambda (&optional (acc nil acc-p) (input nil input-p))
            (cond
             ((not acc-p) (funcall rf))
             ((not input-p) (funcall rf acc))
             (t (incf idx)
                (let ((result (funcall fn idx input)))
                  (if result
                      (funcall rf acc result)
                      acc)))))))
      ;; Sequence function
      (let ((coll (cl:first args)))
        (let* ((s (fol.compiler.collections:collection-seq coll))
               (result (cl:loop for elem in s
                       for i from 0
                       for v = (funcall fn i elem)
                         when v collect v)))
          (cl:apply #'fol.compiler.collections:make
            'fol.compiler.collections:<vector>
            result)))))

;;; ---------------------------------------------------------------------------
;;; map-indexed - map with index passed as first arg
;;; ---------------------------------------------------------------------------

(defun map-indexed (fn &rest args)
  "Apply FN to (index, element). With no collection, returns transducer.

   Examples:
     (map-indexed (fn [i x] [i x]) [:a :b :c]) => [[0 :a] [1 :b] [2 :c]]
     (map-indexed (fn [i x] [i x]))              => transducer"
  (if (null args)
      ;; Transducer
      (lambda (rf)
        (let ((idx -1))
          (lambda (&optional (acc nil acc-p) (input nil input-p))
            (cond
             ((not acc-p) (funcall rf))
             ((not input-p) (funcall rf acc))
             (t (incf idx)
                (funcall rf acc (funcall fn idx input)))))))
      ;; Sequence function
      (let ((coll (cl:first args)))
        (let* ((seq (fol.compiler.collections:collection-seq coll))
               (result (cl:loop for elem in seq
                       for i from 0
                       collect (funcall fn i elem))))
          (cl:apply #'fol.compiler.collections:make
            'fol.compiler.collections:<vector> result)))))

;;; ---------------------------------------------------------------------------
;;; distinct - remove duplicates preserving first occurrence
;;; ---------------------------------------------------------------------------

(defun distinct (&rest args)
  "Remove duplicates preserving first occurrence. With no args, returns transducer.

   Examples:
     (distinct [1 2 1 3 2 4])  => [1 2 3 4]
     (distinct)                 => transducer"
  (if (null args)
      ;; Transducer
      (lambda (rf)
        (let ((seen (fol.compiler.collection-functions:set)))
          (lambda (&optional (acc nil acc-p) (input nil input-p))
            (cond
             ((not acc-p) (funcall rf))
             ((not input-p) (funcall rf acc))
             (t (if (fol.compiler.collection-functions:contains? seen input)
                    acc
                    (progn
                     (setf seen (fol.compiler.collection-functions:conj seen input))
                     (funcall rf acc input))))))))
      ;; Sequence function
      (let ((coll (cl:first args)))
        (let ((seen (make-hash-table :test 'equal))
              (result '()))
          (dolist (elem (fol.compiler.collections:collection-seq coll))
            (unless (gethash elem seen)
              (setf (gethash elem seen) t)
              (push elem result)))
          (cl:apply #'fol.compiler.collections:make
            'fol.compiler.collections:<vector> (nreverse result))))))

;;; ---------------------------------------------------------------------------
;;; dedupe - remove consecutive duplicates
;;; ---------------------------------------------------------------------------

(defun dedupe (&rest args)
  "Remove consecutive duplicates. With no args, returns transducer.

   Examples:
     (dedupe [1 1 2 1 1 3 3])  => [1 2 1 3]
     (dedupe)                    => transducer"
  (if (null args)
      ;; Transducer
      (lambda (rf)
        (let ((prior :none-yet))
          (lambda (&optional (acc nil acc-p) (input nil input-p))
            (cond
             ((not acc-p) (funcall rf))
             ((not input-p) (funcall rf acc))
             (t (if (equal prior input)
                    acc
                    (progn
                     (setf prior input)
                     (funcall rf acc input))))))))
      ;; Sequence function
      (let ((coll (cl:first args)))
        (let ((seq (fol.compiler.collections:collection-seq coll))
              (result '())
              (sentinel (cl:list :dedupe-sentinel)))
          (let ((prev sentinel))
            (dolist (elem seq)
              (unless (equal elem prev)
                (push elem result)
                (setf prev elem))))
          (cl:apply #'fol.compiler.collections:make
            'fol.compiler.collections:<vector> (nreverse result))))))

;;; ---------------------------------------------------------------------------
;;; partition-all - like partition but keeps partial final group
;;; ---------------------------------------------------------------------------

(defun partition-all (n &rest args)
  "Partition into groups of N. With no collection, returns transducer.

   Examples:
     (partition-all 3 [1 2 3 4 5])  => [[1 2 3] [4 5]]
     (partition-all 3)               => transducer"
  (if (null args)
      ;; Transducer
      (lambda (rf)
        (let ((buffer (cl:make-array n :adjustable t :fill-pointer 0)))
          (lambda (&optional (acc nil acc-p) (input nil input-p))
            (cond
             ((not acc-p) (funcall rf))
             ((not input-p)
               (if (> (length buffer) 0)
                   (let ((result (funcall rf acc (fol.compiler.collection-functions:vec buffer))))
                     (funcall rf result))
                   (funcall rf acc)))
             (t (vector-push-extend input buffer)
                (if (cl:= (length buffer) n)
                    (let ((res (fol.compiler.collection-functions:vec (copy-seq buffer))))
                      (setf (fill-pointer buffer) 0)
                      (funcall rf acc res))
                    acc))))))
      ;; Sequence function
      (let ((coll (cl:first args)))
        (let ((seq (fol.compiler.collections:collection-seq coll))
              (result '()))
          (cl:loop while seq
          do (let ((group (cl:subseq seq 0 (cl:min n (length seq)))))
               (push (cl:apply #'fol.compiler.collections:make
                       'fol.compiler.collections:<vector> group)
                     result)
               (setf seq (cl:nthcdr n seq))))
          (cl:apply #'fol.compiler.collections:make
            'fol.compiler.collections:<vector> (nreverse result))))))

;;; ---------------------------------------------------------------------------
;;; partition-by - partition by consecutive equal values of fn
;;; ---------------------------------------------------------------------------

(defun partition-by (fn &rest args)
  "Partition by consecutive equal (fn item) values. With no collection, returns transducer.

   Examples:
     (partition-by even? [1 1 2 2 3])  => [[1 1] [2 2] [3]]
     (partition-by even?)               => transducer"
  (if (null args)
      ;; Transducer
      (lambda (rf)
        (let ((buffer (cl:make-array 0 :adjustable t :fill-pointer 0))
              (prior :none-yet))
          (lambda (&optional (acc nil acc-p) (input nil input-p))
            (cond
             ((not acc-p) (funcall rf))
             ((not input-p)
               (if (> (length buffer) 0)
                   (let ((result (funcall rf acc (fol.compiler.collection-functions:vec buffer))))
                     (funcall rf result))
                   (funcall rf acc)))
             (t (let ((val (funcall fn input)))
                  (cond
                   ((eq prior :none-yet)
                     (setf prior val)
                     (vector-push-extend input buffer)
                     acc)
                   ((equal val prior)
                     (vector-push-extend input buffer)
                     acc)
                   (t
                     (let ((res (fol.compiler.collection-functions:vec (copy-seq buffer))))
                       (setf (fill-pointer buffer) 0)
                       (vector-push-extend input buffer)
                       (setf prior val)
                       (funcall rf acc res))))))))))
      ;; Sequence function
      (let ((coll (cl:first args)))
        (let ((seq (fol.compiler.collections:collection-seq coll))
              (result '())
              (current-group '())
              (sentinel (cl:list :partition-by-sentinel)))
          (let ((current-key sentinel))
            (dolist (elem seq)
              (let ((key (funcall fn elem)))
                (if (cl:or (eq current-key sentinel) (equal key current-key))
                    (push elem current-group)
                    (progn
                     (push (cl:apply #'fol.compiler.collections:make
                             'fol.compiler.collections:<vector>
                             (nreverse current-group))
                           result)
                     (setf current-group (cl:list elem))))
                (setf current-key key)))
            (when current-group
                  (push (cl:apply #'fol.compiler.collections:make
                          'fol.compiler.collections:<vector>
                          (nreverse current-group))
                        result)))
          (cl:apply #'fol.compiler.collections:make
            'fol.compiler.collections:<vector> (nreverse result))))))

;;; ---------------------------------------------------------------------------
;;; interpose - insert separator between elements
;;; ---------------------------------------------------------------------------

(defun interpose (sep &rest args)
  "Insert SEP between elements. With no collection, returns transducer.

   Examples:
     (interpose 0 [1 2 3])  => [1 0 2 0 3]
     (interpose 0)            => transducer"
  (if (null args)
      ;; Transducer
      (lambda (rf)
        (let ((started nil))
          (lambda (&optional (acc nil acc-p) (input nil input-p))
            (cond
             ((not acc-p) (funcall rf))
             ((not input-p) (funcall rf acc))
             (t (if started
                    (let ((result (funcall rf acc sep)))
                      (if (reduced? result)
                          result
                          (funcall rf result input)))
                    (progn
                     (setf started t)
                     (funcall rf acc input))))))))
      ;; Sequence function
      (let ((coll (cl:first args)))
        (let ((seq (fol.compiler.collections:collection-seq coll)))
          (if (null seq)
              (fol.compiler.collections:make 'fol.compiler.collections:<vector>)
              (let ((result (cl:list (cl:first seq))))
                (dolist (elem (cl:rest seq))
                  (push sep result)
                  (push elem result))
                (cl:apply #'fol.compiler.collections:make
                  'fol.compiler.collections:<vector>
                  (nreverse result))))))))

;;; ---------------------------------------------------------------------------
;;; take-nth - take every nth element
;;; ---------------------------------------------------------------------------

(defun take-nth (n &rest args)
  "Take every Nth element. With no collection, returns transducer.

   Examples:
     (take-nth 2 [1 2 3 4 5 6])  => [1 3 5]
     (take-nth 2)                  => transducer"
  (if (null args)
      ;; Transducer
      (lambda (rf)
        (let ((counter -1))
          (lambda (&optional (acc nil acc-p) (input nil input-p))
            (cond
             ((not acc-p) (funcall rf))
             ((not input-p) (funcall rf acc))
             (t (incf counter)
                (if (zerop (mod counter n))
                    (funcall rf acc input)
                    acc))))))
      ;; Sequence function
      (let ((coll (cl:first args)))
        (when (< n 1)
              (error "take-nth: n must be >= 1, got ~S" n))
        (let* ((seq (fol.compiler.collections:collection-seq coll))
               (result (cl:loop for elem in seq
                       for i from 0
                         when (zerop (mod i n)) collect elem)))
          (cl:apply #'fol.compiler.collections:make
            'fol.compiler.collections:<vector> result)))))
