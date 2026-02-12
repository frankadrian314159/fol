;;; Benchmark: Data structures for a priority-dict
;;;
;;; A priority-dict maps keys to priorities and maintains entries ordered by
;;; priority value. Core operations:
;;;   - CREATE:   build from N (key, priority) pairs
;;;   - LOOKUP:   get priority for a key          — must be O(~1) or O(log n)
;;;   - INSERT:   add a new key with priority     — must maintain ordering
;;;   - UPDATE:   change priority of existing key — must re-sort
;;;   - PEEK-MIN: get entry with lowest priority  — should be O(1) or O(log n)
;;;   - POP-MIN:  remove min-priority entry       — should be O(log n)
;;;   - ITERATE:  walk entries in priority order
;;;
;;; Candidates:
;;;   1. Sycamore hash-map + Sycamore tree-map
;;;      hash-map: key → priority (O(~1) lookup)
;;;      tree-map: (priority . key) → key (O(log n) ordering)
;;;      Composite comparator sorts by priority first, then key for stability.
;;;
;;;   2. FSet wb-map + FSet wb-map
;;;      forward-map: key → priority
;;;      reverse-map: priority → key (via FSet's inherent ordering)
;;;      Issue: FSet wb-map keys must be comparable; multiple keys per priority
;;;      need careful handling (FSet supports (priority . key) compound keys).
;;;
;;;   3. Sycamore hash-map + CL sorted alist
;;;      hash-map: key → priority (O(~1) lookup)
;;;      sorted-alist: ((priority . key) ...) maintained in order
;;;      Insert is O(n) to find insertion point, but cache-friendly.
;;;
;;;   4. Sycamore hash-map + Sycamore tree-map (tree-map only, no hash-map)
;;;      Single tree-map with (priority . key) composite keys.
;;;      Lookup by key requires full scan — O(n). Not viable for large dicts.
;;;      Included as baseline to show why dual structure is needed.

(require :fset)
(require :sycamore)

;;; --- Comparators ---

(defun %priority-key-cmp (a b)
  "Compare (priority . key) pairs: by priority first, then key name for stability."
  (declare (optimize (speed 3) (safety 0)))
  (let ((pa (car a)) (pb (car b)))
    (cond ((< pa pb) -1)
          ((> pa pb) 1)
          ;; Same priority: break tie by key name
          (t (let ((sa (symbol-name (cdr a)))
                   (sb (symbol-name (cdr b))))
               (cond ((string< sa sb) -1)
                     ((string> sa sb) 1)
                     (t 0)))))))

(defun %int-cmp (a b)
  "Integer comparator."
  (declare (optimize (speed 3) (safety 0))
           (fixnum a b))
  (cond ((< a b) -1) ((> a b) 1) (t 0)))

(defun %tree-map-min (tm)
  "Return the minimum (key . value) entry of a Sycamore tree-map.
   Uses do-tree-map which iterates in order; return-from on first entry."
  (block found
    (sycamore:do-tree-map ((k v) tm)
      (return-from found (cons k v)))))

;;; --- Data generators ---

(defun make-priority-pairs (n)
  "Return a list of (keyword . integer-priority) pairs with shuffled keys.
   Priorities are random integers in [0, 10*n)."
  (let* ((keys (loop for i below n
                     collect (intern (format nil "KEY-~4,'0D" i) :keyword)))
         (vec (coerce keys 'vector)))
    ;; Shuffle
    (loop for i from (1- (length vec)) downto 1
          for j = (random (1+ i))
          do (rotatef (aref vec i) (aref vec j)))
    (loop for k across vec
          collect (cons k (random (* 10 n))))))

;;; --- Bench macro ---

(defmacro bench (label iterations &body body)
  `(let ((start (get-internal-real-time)))
     (loop repeat ,iterations do ,@body)
     (let* ((elapsed (/ (- (get-internal-real-time) start)
                        (float internal-time-units-per-second)))
            (ms (* elapsed 1000.0)))
       (format t "  ~42A ~8,2F ms~%" ,label ms))))

;;; =========================================================================
;;; Helper: Build structures from pairs
;;; =========================================================================

(defun build-sycamore-dual (pairs)
  "Build (values hash-map tree-map) from ((key . priority) ...) pairs."
  (loop with hm = (sycamore:make-hash-map)
        with tm = (sycamore:make-tree-map #'%priority-key-cmp)
        for (k . p) in pairs
        do (setf hm (sycamore:hash-map-insert hm k p))
           (setf tm (sycamore:tree-map-insert tm (cons p k) k))
        finally (return (values hm tm))))

(defun build-fset-dual (pairs)
  "Build (values forward-map reverse-map) from ((key . priority) ...) pairs.
   forward-map: key → priority
   reverse-map: (priority . key) → key  [FSet compares conses lexicographically]"
  (loop with fm = (fset:empty-map)
        with rm = (fset:empty-map)
        for (k . p) in pairs
        do (setf fm (fset:with fm k p))
           (setf rm (fset:with rm (cons p k) k))
        finally (return (values fm rm))))

(defun build-sycamore-sorted-alist (pairs)
  "Build (values hash-map sorted-alist) from ((key . priority) ...) pairs.
   sorted-alist is sorted by (priority . key) ascending."
  (loop with hm = (sycamore:make-hash-map)
        for (k . p) in pairs
        do (setf hm (sycamore:hash-map-insert hm k p))
        finally (return (values hm (sort (mapcar (lambda (pair)
                                                   (cons (cdr pair) (car pair)))
                                                 pairs)
                                         (lambda (a b)
                                           (or (< (car a) (car b))
                                               (and (= (car a) (car b))
                                                    (string< (symbol-name (cdr a))
                                                             (symbol-name (cdr b)))))))))))

;;; =========================================================================
;;; Benchmarks
;;; =========================================================================

(defun run-benchmarks ()
  (let ((iters 1000)
        (small-n 20)
        (large-n 2000))

    (format t "~%=== Priority-Dict Benchmarks ===~%")
    (format t "Iterations: ~D~%~%" iters)

    ;; =====================================================================
    ;; CREATE
    ;; =====================================================================

    (format t "--- CREATE (~D pairs) ---~%" small-n)
    (let ((pairs (make-priority-pairs small-n)))
      (bench "Sycamore hash-map + tree-map" iters
        (build-sycamore-dual pairs))
      (bench "FSet wb-map + wb-map" iters
        (build-fset-dual pairs))
      (bench "Sycamore hash-map + sorted alist" iters
        (build-sycamore-sorted-alist pairs)))

    (format t "~%--- CREATE (~D pairs) ---~%" large-n)
    (let ((pairs (make-priority-pairs large-n)))
      (bench "Sycamore hash-map + tree-map" iters
        (build-sycamore-dual pairs))
      (bench "FSet wb-map + wb-map" iters
        (build-fset-dual pairs))
      (bench "Sycamore hash-map + sorted alist" iters
        (build-sycamore-sorted-alist pairs)))

    ;; =====================================================================
    ;; LOOKUP by key
    ;; =====================================================================

    (format t "~%--- LOOKUP by key (~D entries, ~D lookups) ---~%" small-n small-n)
    (let ((pairs (make-priority-pairs small-n)))
      (multiple-value-bind (shm stm) (build-sycamore-dual pairs)
        (declare (ignore stm))
        (let ((keys (mapcar #'car pairs)))
          (bench "Sycamore hash-map" iters
            (dolist (k keys) (sycamore:hash-map-find shm k)))))
      (multiple-value-bind (fm rm) (build-fset-dual pairs)
        (declare (ignore rm))
        (let ((keys (mapcar #'car pairs)))
          (bench "FSet wb-map" iters
            (dolist (k keys) (fset:lookup fm k)))))
      (multiple-value-bind (shm sal) (build-sycamore-sorted-alist pairs)
        (declare (ignore sal))
        (let ((keys (mapcar #'car pairs)))
          (bench "Sycamore hash-map (alist approach)" iters
            (dolist (k keys) (sycamore:hash-map-find shm k))))))

    (format t "~%--- LOOKUP by key (~D entries, ~D lookups) ---~%" large-n large-n)
    (let ((pairs (make-priority-pairs large-n)))
      (multiple-value-bind (shm stm) (build-sycamore-dual pairs)
        (declare (ignore stm))
        (let ((keys (mapcar #'car pairs)))
          (bench "Sycamore hash-map" iters
            (dolist (k keys) (sycamore:hash-map-find shm k)))))
      (multiple-value-bind (fm rm) (build-fset-dual pairs)
        (declare (ignore rm))
        (let ((keys (mapcar #'car pairs)))
          (bench "FSet wb-map" iters
            (dolist (k keys) (fset:lookup fm k)))))
      (multiple-value-bind (shm sal) (build-sycamore-sorted-alist pairs)
        (declare (ignore sal))
        (let ((keys (mapcar #'car pairs)))
          (bench "Sycamore hash-map (alist approach)" iters
            (dolist (k keys) (sycamore:hash-map-find shm k))))))

    ;; =====================================================================
    ;; INSERT new entry (into existing structure)
    ;; =====================================================================

    (format t "~%--- INSERT new entry (into ~D-entry structure) ---~%" small-n)
    (let* ((pairs (make-priority-pairs small-n))
           (new-key (intern "NEW-KEY" :keyword))
           (new-pri 42))
      (multiple-value-bind (shm stm) (build-sycamore-dual pairs)
        (bench "Sycamore hash-map + tree-map" iters
          (sycamore:hash-map-insert shm new-key new-pri)
          (sycamore:tree-map-insert stm (cons new-pri new-key) new-key)))
      (multiple-value-bind (fm rm) (build-fset-dual pairs)
        (bench "FSet wb-map + wb-map" iters
          (fset:with fm new-key new-pri)
          (fset:with rm (cons new-pri new-key) new-key)))
      (multiple-value-bind (shm sal) (build-sycamore-sorted-alist pairs)
        (bench "Sycamore hash-map + sorted alist" iters
          (sycamore:hash-map-insert shm new-key new-pri)
          (merge 'list (list (cons new-pri new-key)) (copy-list sal)
                 (lambda (a b)
                   (or (< (car a) (car b))
                       (and (= (car a) (car b))
                            (string< (symbol-name (cdr a))
                                     (symbol-name (cdr b))))))))))

    (format t "~%--- INSERT new entry (into ~D-entry structure) ---~%" large-n)
    (let* ((pairs (make-priority-pairs large-n))
           (new-key (intern "NEW-KEY" :keyword))
           (new-pri 42))
      (multiple-value-bind (shm stm) (build-sycamore-dual pairs)
        (bench "Sycamore hash-map + tree-map" iters
          (sycamore:hash-map-insert shm new-key new-pri)
          (sycamore:tree-map-insert stm (cons new-pri new-key) new-key)))
      (multiple-value-bind (fm rm) (build-fset-dual pairs)
        (bench "FSet wb-map + wb-map" iters
          (fset:with fm new-key new-pri)
          (fset:with rm (cons new-pri new-key) new-key)))
      (multiple-value-bind (shm sal) (build-sycamore-sorted-alist pairs)
        (bench "Sycamore hash-map + sorted alist" iters
          (sycamore:hash-map-insert shm new-key new-pri)
          (merge 'list (list (cons new-pri new-key)) (copy-list sal)
                 (lambda (a b)
                   (or (< (car a) (car b))
                       (and (= (car a) (car b))
                            (string< (symbol-name (cdr a))
                                     (symbol-name (cdr b))))))))))

    ;; =====================================================================
    ;; UPDATE priority of existing key
    ;; =====================================================================

    (format t "~%--- UPDATE priority of existing key (~D entries) ---~%" small-n)
    (let* ((pairs (make-priority-pairs small-n))
           (target-key (car (nth (floor small-n 2) pairs)))
           (old-pri (cdr (nth (floor small-n 2) pairs)))
           (new-pri (+ old-pri 100)))
      (multiple-value-bind (shm stm) (build-sycamore-dual pairs)
        (bench "Sycamore hash-map + tree-map" iters
          ;; Remove old entry from tree-map, insert new
          (let ((tm2 (sycamore:tree-map-remove stm (cons old-pri target-key))))
            (sycamore:tree-map-insert tm2 (cons new-pri target-key) target-key))
          (sycamore:hash-map-insert shm target-key new-pri)))
      (multiple-value-bind (fm rm) (build-fset-dual pairs)
        (bench "FSet wb-map + wb-map" iters
          (let ((rm2 (fset:less rm (cons old-pri target-key))))
            (fset:with rm2 (cons new-pri target-key) target-key))
          (fset:with fm target-key new-pri)))
      (multiple-value-bind (shm sal) (build-sycamore-sorted-alist pairs)
        (bench "Sycamore hash-map + sorted alist" iters
          (sycamore:hash-map-insert shm target-key new-pri)
          (let ((cleaned (remove (cons old-pri target-key) sal :test #'equal)))
            (merge 'list (list (cons new-pri target-key)) cleaned
                   (lambda (a b) (< (car a) (car b))))))))

    (format t "~%--- UPDATE priority of existing key (~D entries) ---~%" large-n)
    (let* ((pairs (make-priority-pairs large-n))
           (target-key (car (nth (floor large-n 2) pairs)))
           (old-pri (cdr (nth (floor large-n 2) pairs)))
           (new-pri (+ old-pri 100)))
      (multiple-value-bind (shm stm) (build-sycamore-dual pairs)
        (bench "Sycamore hash-map + tree-map" iters
          (let ((tm2 (sycamore:tree-map-remove stm (cons old-pri target-key))))
            (sycamore:tree-map-insert tm2 (cons new-pri target-key) target-key))
          (sycamore:hash-map-insert shm target-key new-pri)))
      (multiple-value-bind (fm rm) (build-fset-dual pairs)
        (bench "FSet wb-map + wb-map" iters
          (let ((rm2 (fset:less rm (cons old-pri target-key))))
            (fset:with rm2 (cons new-pri target-key) target-key))
          (fset:with fm target-key new-pri)))
      (multiple-value-bind (shm sal) (build-sycamore-sorted-alist pairs)
        (bench "Sycamore hash-map + sorted alist" iters
          (sycamore:hash-map-insert shm target-key new-pri)
          (let ((cleaned (remove (cons old-pri target-key) sal :test #'equal)))
            (merge 'list (list (cons new-pri target-key)) cleaned
                   (lambda (a b) (< (car a) (car b))))))))

    ;; =====================================================================
    ;; PEEK-MIN (get minimum priority entry without removing)
    ;; =====================================================================

    (format t "~%--- PEEK-MIN (~D entries) ---~%" small-n)
    (let ((pairs (make-priority-pairs small-n)))
      (multiple-value-bind (shm stm) (build-sycamore-dual pairs)
        (declare (ignore shm))
        (bench "Sycamore tree-map (do-tree-map min)" iters
          (%tree-map-min stm)))
      (multiple-value-bind (fm rm) (build-fset-dual pairs)
        (declare (ignore fm))
        (bench "FSet wb-map (least)" iters
          (fset:least rm)))
      (multiple-value-bind (shm sal) (build-sycamore-sorted-alist pairs)
        (declare (ignore shm))
        (bench "Sorted alist (car)" iters
          (car sal))))

    (format t "~%--- PEEK-MIN (~D entries) ---~%" large-n)
    (let ((pairs (make-priority-pairs large-n)))
      (multiple-value-bind (shm stm) (build-sycamore-dual pairs)
        (declare (ignore shm))
        (bench "Sycamore tree-map (do-tree-map min)" iters
          (%tree-map-min stm)))
      (multiple-value-bind (fm rm) (build-fset-dual pairs)
        (declare (ignore fm))
        (bench "FSet wb-map (least)" iters
          (fset:least rm)))
      (multiple-value-bind (shm sal) (build-sycamore-sorted-alist pairs)
        (declare (ignore shm))
        (bench "Sorted alist (car)" iters
          (car sal))))

    ;; =====================================================================
    ;; POP-MIN (remove minimum priority entry)
    ;; =====================================================================

    (format t "~%--- POP-MIN (~D entries) ---~%" small-n)
    (let ((pairs (make-priority-pairs small-n)))
      (multiple-value-bind (shm stm) (build-sycamore-dual pairs)
        (bench "Sycamore hash-map + tree-map" iters
          (let ((min-entry (%tree-map-min stm)))
            ;; min-entry = ((priority . key) . key)
            (sycamore:tree-map-remove stm (car min-entry))
            (sycamore:hash-map-remove shm (cdr min-entry)))))
      (multiple-value-bind (fm rm) (build-fset-dual pairs)
        (bench "FSet wb-map + wb-map" iters
          (let ((min-key (fset:least rm)))
            (fset:less rm min-key)
            (fset:less fm (cdr min-key)))))
      (multiple-value-bind (shm sal) (build-sycamore-sorted-alist pairs)
        (bench "Sycamore hash-map + sorted alist" iters
          (let ((min-entry (car sal)))
            (cdr sal)  ; pop front
            (sycamore:hash-map-remove shm (cdr min-entry))))))

    (format t "~%--- POP-MIN (~D entries) ---~%" large-n)
    (let ((pairs (make-priority-pairs large-n)))
      (multiple-value-bind (shm stm) (build-sycamore-dual pairs)
        (bench "Sycamore hash-map + tree-map" iters
          (let ((min-entry (%tree-map-min stm)))
            ;; min-entry = ((priority . key) . key)
            (sycamore:tree-map-remove stm (car min-entry))
            (sycamore:hash-map-remove shm (cdr min-entry)))))
      (multiple-value-bind (fm rm) (build-fset-dual pairs)
        (bench "FSet wb-map + wb-map" iters
          (let ((min-key (fset:least rm)))
            (fset:less rm min-key)
            (fset:less fm (cdr min-key)))))
      (multiple-value-bind (shm sal) (build-sycamore-sorted-alist pairs)
        (bench "Sycamore hash-map + sorted alist" iters
          (let ((min-entry (car sal)))
            (cdr sal)
            (sycamore:hash-map-remove shm (cdr min-entry))))))

    ;; =====================================================================
    ;; ITERATE in priority order
    ;; =====================================================================

    (format t "~%--- ITERATE in priority order (~D entries) ---~%" small-n)
    (let ((pairs (make-priority-pairs small-n)))
      (multiple-value-bind (shm stm) (build-sycamore-dual pairs)
        (declare (ignore shm))
        (bench "Sycamore tree-map (map-tree-map)" iters
          (sycamore:map-tree-map :inorder nil
            (lambda (k v) (declare (ignore k v))) stm)))
      (multiple-value-bind (fm rm) (build-fset-dual pairs)
        (declare (ignore fm))
        (bench "FSet wb-map (do-map)" iters
          (fset:do-map (k v rm) (declare (ignore k v)))))
      (multiple-value-bind (shm sal) (build-sycamore-sorted-alist pairs)
        (declare (ignore shm))
        (bench "Sorted alist (dolist)" iters
          (dolist (pair sal) (declare (ignore pair))))))

    (format t "~%--- ITERATE in priority order (~D entries) ---~%" large-n)
    (let ((pairs (make-priority-pairs large-n)))
      (multiple-value-bind (shm stm) (build-sycamore-dual pairs)
        (declare (ignore shm))
        (bench "Sycamore tree-map (map-tree-map)" iters
          (sycamore:map-tree-map :inorder nil
            (lambda (k v) (declare (ignore k v))) stm)))
      (multiple-value-bind (fm rm) (build-fset-dual pairs)
        (declare (ignore fm))
        (bench "FSet wb-map (do-map)" iters
          (fset:do-map (k v rm) (declare (ignore k v)))))
      (multiple-value-bind (shm sal) (build-sycamore-sorted-alist pairs)
        (declare (ignore shm))
        (bench "Sorted alist (dolist)" iters
          (dolist (pair sal) (declare (ignore pair))))))

    (format t "~%=== Done ===~%")))

(run-benchmarks)
