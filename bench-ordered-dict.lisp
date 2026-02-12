;;; Benchmark: FSet vs Sycamore for ordered dictionaries
;;;
;;; An ordered dict preserves insertion order (like Python dict / Clojure array-map).
;;; Neither FSet nor Sycamore has a native insertion-ordered map, so we compare
;;; composite approaches:
;;;
;;;   1. FSet seq of (key . value) pairs — preserves order, O(n) lookup
;;;   2. FSet wb-map + FSet seq for order — O(log n) lookup, O(n) seq append
;;;   3. Sycamore hash-map + CL list for order — O(~1) lookup, O(n) list append
;;;   4. Sycamore hash-map + FSet seq for order — O(~1) lookup, O(n) seq append
;;;   5. CL alist (baseline) — O(n) lookup, O(1) cons-prepend
;;;
;;; Operations benchmarked:
;;;   CREATE   — build from N key-value pairs
;;;   LOOKUP   — find a specific key by value
;;;   INSERT   — add a single pair to an existing map (preserving order)
;;;   ITERATE  — walk all entries in insertion order

(require :fset)
(require :sycamore)

;;; --- Data generators ---

(defun make-keyword-pairs (n)
  "Return a list of (keyword . integer) pairs with unique keyword keys in random order."
  (let* ((keys (loop for i below n
                     collect (intern (format nil "KEY-~4,'0D" i) :keyword)))
         (vec (coerce keys 'vector)))
    ;; Shuffle
    (loop for i from (1- (length vec)) downto 1
          for j = (random (1+ i))
          do (rotatef (aref vec i) (aref vec j)))
    (loop for k across vec
          for i from 0
          collect (cons k i))))

(defun make-integer-pairs (n)
  "Return a list of (integer . integer) pairs with shuffled integer keys."
  (let ((vec (coerce (loop for i below n collect i) 'vector)))
    (loop for i from (1- (length vec)) downto 1
          for j = (random (1+ i))
          do (rotatef (aref vec i) (aref vec j)))
    (loop for k across vec collect (cons k (* k 10)))))

;;; --- Bench macro ---

(defmacro bench (label iterations &body body)
  `(let ((start (get-internal-real-time)))
     (loop repeat ,iterations do ,@body)
     (let* ((elapsed (/ (- (get-internal-real-time) start)
                        (float internal-time-units-per-second)))
            (ms (* elapsed 1000.0)))
       (format t "  ~40A ~8,2F ms~%" ,label ms))))

;;; ============================================================================
;;; Build helpers — construct each data structure from a list of pairs
;;; ============================================================================

;;; 1. FSet seq of pairs
(defun build-fset-seq (pairs)
  "Build an FSet seq of (key . value) conses preserving insertion order."
  (fset:convert 'fset:seq pairs))

;;; 2. FSet wb-map + FSet seq (dual structure)
(defun build-fset-dual (pairs)
  "Build (values fset-wb-map fset-seq-of-keys) preserving insertion order."
  (loop with wm = (fset:empty-map)
        with ks = (fset:empty-seq)
        for (k . v) in pairs
        do (setf wm (fset:with wm k v))
           (setf ks (fset:with-last ks k))
        finally (return (cons wm ks))))

;;; 3. Sycamore hash-map + CL list
(defun build-syc-hm-list (pairs)
  "Build (values sycamore-hash-map cl-key-list) preserving insertion order."
  (loop with hm = (sycamore:make-hash-map)
        with ks = nil
        for (k . v) in pairs
        do (setf hm (sycamore:hash-map-insert hm k v))
           (push k ks)
        finally (return (cons hm (nreverse ks)))))

;;; 4. Sycamore hash-map + FSet seq
(defun build-syc-hm-seq (pairs)
  "Build (values sycamore-hash-map fset-seq-of-keys) preserving insertion order."
  (loop with hm = (sycamore:make-hash-map)
        with ks = (fset:empty-seq)
        for (k . v) in pairs
        do (setf hm (sycamore:hash-map-insert hm k v))
           (setf ks (fset:with-last ks k))
        finally (return (cons hm ks))))

;;; 5. CL alist (baseline)
(defun build-alist (pairs)
  "Build a CL alist preserving insertion order."
  (copy-list pairs))

;;; ============================================================================
;;; Benchmarks
;;; ============================================================================

(defun run-benchmarks ()
  (let ((iters 1000)
        (small-n 20)
        (large-n 2000))

    (format t "~%=== Ordered Dict Benchmarks ===~%")
    (format t "Iterations: ~D~%~%" iters)

    ;; =====================================================================
    ;; KEYWORD KEYS
    ;; =====================================================================
    (format t "====== KEYWORD KEYS ======~%")

    ;; --- CREATE small ---
    (format t "~%--- CREATE ordered dict (~D keyword pairs) ---~%" small-n)
    (let ((pairs (make-keyword-pairs small-n)))
      (bench "1. FSet seq of pairs" iters
        (build-fset-seq pairs))
      (bench "2. FSet wb-map + FSet seq" iters
        (build-fset-dual pairs))
      (bench "3. Sycamore hash-map + CL list" iters
        (build-syc-hm-list pairs))
      (bench "4. Sycamore hash-map + FSet seq" iters
        (build-syc-hm-seq pairs))
      (bench "5. CL alist" iters
        (build-alist pairs)))

    ;; --- CREATE large ---
    (format t "~%--- CREATE ordered dict (~D keyword pairs) ---~%" large-n)
    (let ((pairs (make-keyword-pairs large-n)))
      (bench "1. FSet seq of pairs" iters
        (build-fset-seq pairs))
      (bench "2. FSet wb-map + FSet seq" iters
        (build-fset-dual pairs))
      (bench "3. Sycamore hash-map + CL list" iters
        (build-syc-hm-list pairs))
      (bench "4. Sycamore hash-map + FSet seq" iters
        (build-syc-hm-seq pairs))
      (bench "5. CL alist" iters
        (build-alist pairs)))

    ;; --- LOOKUP (in 20-entry map) ---
    (format t "~%--- LOOKUP key in ~D-entry ordered dict ---~%" small-n)
    (let* ((pairs (make-keyword-pairs small-n))
           (target-key (car (nth (floor small-n 2) pairs)))  ; middle key
           (fseq (build-fset-seq pairs))
           (fdual (build-fset-dual pairs))
           (shlist (build-syc-hm-list pairs))
           (shseq (build-syc-hm-seq pairs))
           (alist (build-alist pairs)))
      (bench "1. FSet seq (linear scan)" iters
        (fset:do-seq (pair fseq)
          (when (eq (car pair) target-key)
            (return (cdr pair)))))
      (bench "2. FSet wb-map (map lookup)" iters
        (fset:lookup (car fdual) target-key))
      (bench "3. Sycamore hash-map (hm lookup)" iters
        (sycamore:hash-map-find (car shlist) target-key))
      (bench "4. Sycamore hash-map (hm lookup)" iters
        (sycamore:hash-map-find (car shseq) target-key))
      (bench "5. CL alist (assoc)" iters
        (cdr (assoc target-key alist))))

    ;; --- LOOKUP (in 2000-entry map) ---
    (format t "~%--- LOOKUP key in ~D-entry ordered dict ---~%" large-n)
    (let* ((pairs (make-keyword-pairs large-n))
           (target-key (car (nth (floor large-n 2) pairs)))  ; middle key
           (fseq (build-fset-seq pairs))
           (fdual (build-fset-dual pairs))
           (shlist (build-syc-hm-list pairs))
           (shseq (build-syc-hm-seq pairs))
           (alist (build-alist pairs)))
      (bench "1. FSet seq (linear scan)" iters
        (fset:do-seq (pair fseq)
          (when (eq (car pair) target-key)
            (return (cdr pair)))))
      (bench "2. FSet wb-map (map lookup)" iters
        (fset:lookup (car fdual) target-key))
      (bench "3. Sycamore hash-map (hm lookup)" iters
        (sycamore:hash-map-find (car shlist) target-key))
      (bench "4. Sycamore hash-map (hm lookup)" iters
        (sycamore:hash-map-find (car shseq) target-key))
      (bench "5. CL alist (assoc)" iters
        (cdr (assoc target-key alist))))

    ;; --- INSERT single pair (into 20-entry map, append at end) ---
    (format t "~%--- INSERT single pair (into ~D-entry ordered dict) ---~%" small-n)
    (let* ((pairs (make-keyword-pairs small-n))
           (new-key (intern "ZZZZZ" :keyword))
           (new-val 9999)
           (fseq (build-fset-seq pairs))
           (fdual (build-fset-dual pairs))
           (shlist (build-syc-hm-list pairs))
           (shseq (build-syc-hm-seq pairs))
           (alist (build-alist pairs)))
      (bench "1. FSet seq (with-last)" iters
        (fset:with-last fseq (cons new-key new-val)))
      (bench "2. FSet dual (with + with-last)" iters
        (cons (fset:with (car fdual) new-key new-val)
              (fset:with-last (cdr fdual) new-key)))
      (bench "3. Syc hm + list (insert + append)" iters
        (cons (sycamore:hash-map-insert (car shlist) new-key new-val)
              (append (cdr shlist) (list new-key))))
      (bench "4. Syc hm + FSet seq (insert + with-last)" iters
        (cons (sycamore:hash-map-insert (car shseq) new-key new-val)
              (fset:with-last (cdr shseq) new-key)))
      (bench "5. CL alist (append)" iters
        (append alist (list (cons new-key new-val)))))

    ;; --- INSERT single pair (into 2000-entry map) ---
    (format t "~%--- INSERT single pair (into ~D-entry ordered dict) ---~%" large-n)
    (let* ((pairs (make-keyword-pairs large-n))
           (new-key (intern "ZZZZZ" :keyword))
           (new-val 9999)
           (fseq (build-fset-seq pairs))
           (fdual (build-fset-dual pairs))
           (shlist (build-syc-hm-list pairs))
           (shseq (build-syc-hm-seq pairs))
           (alist (build-alist pairs)))
      (bench "1. FSet seq (with-last)" iters
        (fset:with-last fseq (cons new-key new-val)))
      (bench "2. FSet dual (with + with-last)" iters
        (cons (fset:with (car fdual) new-key new-val)
              (fset:with-last (cdr fdual) new-key)))
      (bench "3. Syc hm + list (insert + append)" iters
        (cons (sycamore:hash-map-insert (car shlist) new-key new-val)
              (append (cdr shlist) (list new-key))))
      (bench "4. Syc hm + FSet seq (insert + with-last)" iters
        (cons (sycamore:hash-map-insert (car shseq) new-key new-val)
              (fset:with-last (cdr shseq) new-key)))
      (bench "5. CL alist (append)" iters
        (append alist (list (cons new-key new-val)))))

    ;; --- ITERATE (20-entry map in insertion order) ---
    (format t "~%--- ITERATE ~D-entry ordered dict ---~%" small-n)
    (let* ((pairs (make-keyword-pairs small-n))
           (fseq (build-fset-seq pairs))
           (fdual (build-fset-dual pairs))
           (shlist (build-syc-hm-list pairs))
           (shseq (build-syc-hm-seq pairs))
           (alist (build-alist pairs)))
      (bench "1. FSet seq (do-seq)" iters
        (fset:do-seq (pair fseq)
          (declare (ignore pair))))
      (bench "2. FSet dual (do-seq + lookup)" iters
        (fset:do-seq (k (cdr fdual))
          (fset:lookup (car fdual) k)))
      (bench "3. Syc hm + list (dolist + lookup)" iters
        (dolist (k (cdr shlist))
          (sycamore:hash-map-find (car shlist) k)))
      (bench "4. Syc hm + FSet seq (do-seq + lookup)" iters
        (fset:do-seq (k (cdr shseq))
          (sycamore:hash-map-find (car shseq) k)))
      (bench "5. CL alist (dolist)" iters
        (dolist (pair alist)
          (declare (ignore pair)))))

    ;; --- ITERATE (2000-entry map in insertion order) ---
    (format t "~%--- ITERATE ~D-entry ordered dict ---~%" large-n)
    (let* ((pairs (make-keyword-pairs large-n))
           (fseq (build-fset-seq pairs))
           (fdual (build-fset-dual pairs))
           (shlist (build-syc-hm-list pairs))
           (shseq (build-syc-hm-seq pairs))
           (alist (build-alist pairs)))
      (bench "1. FSet seq (do-seq)" iters
        (fset:do-seq (pair fseq)
          (declare (ignore pair))))
      (bench "2. FSet dual (do-seq + lookup)" iters
        (fset:do-seq (k (cdr fdual))
          (fset:lookup (car fdual) k)))
      (bench "3. Syc hm + list (dolist + lookup)" iters
        (dolist (k (cdr shlist))
          (sycamore:hash-map-find (car shlist) k)))
      (bench "4. Syc hm + FSet seq (do-seq + lookup)" iters
        (fset:do-seq (k (cdr shseq))
          (sycamore:hash-map-find (car shseq) k)))
      (bench "5. CL alist (dolist)" iters
        (dolist (pair alist)
          (declare (ignore pair)))))

    ;; =====================================================================
    ;; INTEGER KEYS
    ;; =====================================================================
    (format t "~%~%====== INTEGER KEYS ======~%")

    ;; --- CREATE small ---
    (format t "~%--- CREATE ordered dict (~D integer pairs) ---~%" small-n)
    (let ((pairs (make-integer-pairs small-n)))
      (bench "1. FSet seq of pairs" iters
        (build-fset-seq pairs))
      (bench "2. FSet wb-map + FSet seq" iters
        (build-fset-dual pairs))
      (bench "3. Sycamore hash-map + CL list" iters
        (build-syc-hm-list pairs))
      (bench "4. Sycamore hash-map + FSet seq" iters
        (build-syc-hm-seq pairs))
      (bench "5. CL alist" iters
        (build-alist pairs)))

    ;; --- CREATE large ---
    (format t "~%--- CREATE ordered dict (~D integer pairs) ---~%" large-n)
    (let ((pairs (make-integer-pairs large-n)))
      (bench "1. FSet seq of pairs" iters
        (build-fset-seq pairs))
      (bench "2. FSet wb-map + FSet seq" iters
        (build-fset-dual pairs))
      (bench "3. Sycamore hash-map + CL list" iters
        (build-syc-hm-list pairs))
      (bench "4. Sycamore hash-map + FSet seq" iters
        (build-syc-hm-seq pairs))
      (bench "5. CL alist" iters
        (build-alist pairs)))

    ;; --- LOOKUP (in 20-entry integer map) ---
    (format t "~%--- LOOKUP key in ~D-entry integer ordered dict ---~%" small-n)
    (let* ((pairs (make-integer-pairs small-n))
           (target-key (car (nth (floor small-n 2) pairs)))
           (fseq (build-fset-seq pairs))
           (fdual (build-fset-dual pairs))
           (shlist (build-syc-hm-list pairs))
           (shseq (build-syc-hm-seq pairs))
           (alist (build-alist pairs)))
      (bench "1. FSet seq (linear scan)" iters
        (fset:do-seq (pair fseq)
          (when (eql (car pair) target-key)
            (return (cdr pair)))))
      (bench "2. FSet wb-map (map lookup)" iters
        (fset:lookup (car fdual) target-key))
      (bench "3. Sycamore hash-map (hm lookup)" iters
        (sycamore:hash-map-find (car shlist) target-key))
      (bench "4. Sycamore hash-map (hm lookup)" iters
        (sycamore:hash-map-find (car shseq) target-key))
      (bench "5. CL alist (assoc)" iters
        (cdr (assoc target-key alist))))

    ;; --- LOOKUP (in 2000-entry integer map) ---
    (format t "~%--- LOOKUP key in ~D-entry integer ordered dict ---~%" large-n)
    (let* ((pairs (make-integer-pairs large-n))
           (target-key (car (nth (floor large-n 2) pairs)))
           (fseq (build-fset-seq pairs))
           (fdual (build-fset-dual pairs))
           (shlist (build-syc-hm-list pairs))
           (shseq (build-syc-hm-seq pairs))
           (alist (build-alist pairs)))
      (bench "1. FSet seq (linear scan)" iters
        (fset:do-seq (pair fseq)
          (when (eql (car pair) target-key)
            (return (cdr pair)))))
      (bench "2. FSet wb-map (map lookup)" iters
        (fset:lookup (car fdual) target-key))
      (bench "3. Sycamore hash-map (hm lookup)" iters
        (sycamore:hash-map-find (car shlist) target-key))
      (bench "4. Sycamore hash-map (hm lookup)" iters
        (sycamore:hash-map-find (car shseq) target-key))
      (bench "5. CL alist (assoc)" iters
        (cdr (assoc target-key alist))))

    ;; --- INSERT (into 20-entry integer map) ---
    (format t "~%--- INSERT single pair (into ~D-entry integer ordered dict) ---~%" small-n)
    (let* ((pairs (make-integer-pairs small-n))
           (new-key 999999)
           (new-val 42)
           (fseq (build-fset-seq pairs))
           (fdual (build-fset-dual pairs))
           (shlist (build-syc-hm-list pairs))
           (shseq (build-syc-hm-seq pairs))
           (alist (build-alist pairs)))
      (bench "1. FSet seq (with-last)" iters
        (fset:with-last fseq (cons new-key new-val)))
      (bench "2. FSet dual (with + with-last)" iters
        (cons (fset:with (car fdual) new-key new-val)
              (fset:with-last (cdr fdual) new-key)))
      (bench "3. Syc hm + list (insert + append)" iters
        (cons (sycamore:hash-map-insert (car shlist) new-key new-val)
              (append (cdr shlist) (list new-key))))
      (bench "4. Syc hm + FSet seq (insert + with-last)" iters
        (cons (sycamore:hash-map-insert (car shseq) new-key new-val)
              (fset:with-last (cdr shseq) new-key)))
      (bench "5. CL alist (append)" iters
        (append alist (list (cons new-key new-val)))))

    ;; --- INSERT (into 2000-entry integer map) ---
    (format t "~%--- INSERT single pair (into ~D-entry integer ordered dict) ---~%" large-n)
    (let* ((pairs (make-integer-pairs large-n))
           (new-key 999999)
           (new-val 42)
           (fseq (build-fset-seq pairs))
           (fdual (build-fset-dual pairs))
           (shlist (build-syc-hm-list pairs))
           (shseq (build-syc-hm-seq pairs))
           (alist (build-alist pairs)))
      (bench "1. FSet seq (with-last)" iters
        (fset:with-last fseq (cons new-key new-val)))
      (bench "2. FSet dual (with + with-last)" iters
        (cons (fset:with (car fdual) new-key new-val)
              (fset:with-last (cdr fdual) new-key)))
      (bench "3. Syc hm + list (insert + append)" iters
        (cons (sycamore:hash-map-insert (car shlist) new-key new-val)
              (append (cdr shlist) (list new-key))))
      (bench "4. Syc hm + FSet seq (insert + with-last)" iters
        (cons (sycamore:hash-map-insert (car shseq) new-key new-val)
              (fset:with-last (cdr shseq) new-key)))
      (bench "5. CL alist (append)" iters
        (append alist (list (cons new-key new-val)))))

    ;; --- ITERATE (20-entry integer map) ---
    (format t "~%--- ITERATE ~D-entry integer ordered dict ---~%" small-n)
    (let* ((pairs (make-integer-pairs small-n))
           (fseq (build-fset-seq pairs))
           (fdual (build-fset-dual pairs))
           (shlist (build-syc-hm-list pairs))
           (shseq (build-syc-hm-seq pairs))
           (alist (build-alist pairs)))
      (bench "1. FSet seq (do-seq)" iters
        (fset:do-seq (pair fseq)
          (declare (ignore pair))))
      (bench "2. FSet dual (do-seq + lookup)" iters
        (fset:do-seq (k (cdr fdual))
          (fset:lookup (car fdual) k)))
      (bench "3. Syc hm + list (dolist + lookup)" iters
        (dolist (k (cdr shlist))
          (sycamore:hash-map-find (car shlist) k)))
      (bench "4. Syc hm + FSet seq (do-seq + lookup)" iters
        (fset:do-seq (k (cdr shseq))
          (sycamore:hash-map-find (car shseq) k)))
      (bench "5. CL alist (dolist)" iters
        (dolist (pair alist)
          (declare (ignore pair)))))

    ;; --- ITERATE (2000-entry integer map) ---
    (format t "~%--- ITERATE ~D-entry integer ordered dict ---~%" large-n)
    (let* ((pairs (make-integer-pairs large-n))
           (fseq (build-fset-seq pairs))
           (fdual (build-fset-dual pairs))
           (shlist (build-syc-hm-list pairs))
           (shseq (build-syc-hm-seq pairs))
           (alist (build-alist pairs)))
      (bench "1. FSet seq (do-seq)" iters
        (fset:do-seq (pair fseq)
          (declare (ignore pair))))
      (bench "2. FSet dual (do-seq + lookup)" iters
        (fset:do-seq (k (cdr fdual))
          (fset:lookup (car fdual) k)))
      (bench "3. Syc hm + list (dolist + lookup)" iters
        (dolist (k (cdr shlist))
          (sycamore:hash-map-find (car shlist) k)))
      (bench "4. Syc hm + FSet seq (do-seq + lookup)" iters
        (fset:do-seq (k (cdr shseq))
          (sycamore:hash-map-find (car shseq) k)))
      (bench "5. CL alist (dolist)" iters
        (dolist (pair alist)
          (declare (ignore pair))))))

  (format t "~%=== Done ===~%"))

(run-benchmarks)
