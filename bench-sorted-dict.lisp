;;; Benchmark: FSet vs Sycamore for sorted dictionaries
;;;
;;; Sorted dictionaries maintain key-value pairs in key order.
;;; Candidates:
;;;   1. Sycamore tree-map (with custom comparator) — WB tree
;;;   2. FSet wb-map — weight-balanced tree, inherently sorted
;;;   3. Sycamore hash-map (HAMT, unsorted baseline for comparison)

(require :fset)
(require :sycamore)

;;; --- Comparator ---

(defun %general-cmp (a b)
  "General-purpose comparator for keyword symbols (by symbol-name string<)."
  (declare (optimize (speed 3) (safety 0)))
  (let ((sa (symbol-name a))
        (sb (symbol-name b)))
    (cond ((string< sa sb) -1)
          ((string> sa sb) 1)
          (t 0))))

(defun %int-cmp (a b)
  "Integer comparator."
  (declare (optimize (speed 3) (safety 0))
           (fixnum a b))
  (cond ((< a b) -1) ((> a b) 1) (t 0)))

;;; --- Data generators ---

(defun make-keyword-pairs (n)
  "Return a list of (keyword . integer) pairs with shuffled keyword keys."
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
       (format t "  ~30A ~8,2F ms~%" ,label ms))))

;;; --- Benchmarks ---

(defun run-benchmarks ()
  (let ((iters 1000)
        (small-n 20)
        (large-n 2000))

    (format t "~%=== Sorted Dict Benchmarks ===~%")
    (format t "Iterations: ~D~%~%" iters)

    ;; =====================================================================
    ;; KEYWORD KEYS
    ;; =====================================================================

    (format t "====== KEYWORD KEYS ======~%")

    ;; --- CREATE small (20 keyword pairs) ---
    (format t "~%--- CREATE sorted dict (~D keyword pairs) ---~%" small-n)
    (let ((pairs (make-keyword-pairs small-n)))
      (bench "Sycamore tree-map" iters
        (loop with tm = (sycamore:make-tree-map #'%general-cmp)
              for (k . v) in pairs
              do (setf tm (sycamore:tree-map-insert tm k v))))
      (bench "Sycamore hash-map (unsorted)" iters
        (loop with hm = (sycamore:make-hash-map)
              for (k . v) in pairs
              do (setf hm (sycamore:hash-map-insert hm k v))))
      (bench "FSet wb-map" iters
        (loop with wm = (fset:empty-map)
              for (k . v) in pairs
              do (setf wm (fset:with wm k v)))))

    ;; --- CREATE large (2000 keyword pairs) ---
    (format t "~%--- CREATE sorted dict (~D keyword pairs) ---~%" large-n)
    (let ((pairs (make-keyword-pairs large-n)))
      (bench "Sycamore tree-map" iters
        (loop with tm = (sycamore:make-tree-map #'%general-cmp)
              for (k . v) in pairs
              do (setf tm (sycamore:tree-map-insert tm k v))))
      (bench "Sycamore hash-map (unsorted)" iters
        (loop with hm = (sycamore:make-hash-map)
              for (k . v) in pairs
              do (setf hm (sycamore:hash-map-insert hm k v))))
      (bench "FSet wb-map" iters
        (loop with wm = (fset:empty-map)
              for (k . v) in pairs
              do (setf wm (fset:with wm k v)))))

    ;; --- LOOKUP small (20 keyword keys) ---
    (format t "~%--- LOOKUP (~D keyword keys, ~D lookups) ---~%" small-n small-n)
    (let* ((pairs (make-keyword-pairs small-n))
           (keys (mapcar #'car pairs))
           (tm (loop with tm = (sycamore:make-tree-map #'%general-cmp)
                     for (k . v) in pairs
                     do (setf tm (sycamore:tree-map-insert tm k v))
                     finally (return tm)))
           (hm (loop with hm = (sycamore:make-hash-map)
                     for (k . v) in pairs
                     do (setf hm (sycamore:hash-map-insert hm k v))
                     finally (return hm)))
           (wm (loop with wm = (fset:empty-map)
                     for (k . v) in pairs
                     do (setf wm (fset:with wm k v))
                     finally (return wm))))
      (bench "Sycamore tree-map" iters
        (dolist (k keys) (sycamore:tree-map-find tm k)))
      (bench "Sycamore hash-map (unsorted)" iters
        (dolist (k keys) (sycamore:hash-map-find hm k)))
      (bench "FSet wb-map" iters
        (dolist (k keys) (fset:lookup wm k))))

    ;; --- LOOKUP large (2000 keyword keys) ---
    (format t "~%--- LOOKUP (~D keyword keys, ~D lookups) ---~%" large-n large-n)
    (let* ((pairs (make-keyword-pairs large-n))
           (keys (mapcar #'car pairs))
           (tm (loop with tm = (sycamore:make-tree-map #'%general-cmp)
                     for (k . v) in pairs
                     do (setf tm (sycamore:tree-map-insert tm k v))
                     finally (return tm)))
           (hm (loop with hm = (sycamore:make-hash-map)
                     for (k . v) in pairs
                     do (setf hm (sycamore:hash-map-insert hm k v))
                     finally (return hm)))
           (wm (loop with wm = (fset:empty-map)
                     for (k . v) in pairs
                     do (setf wm (fset:with wm k v))
                     finally (return wm))))
      (bench "Sycamore tree-map" iters
        (dolist (k keys) (sycamore:tree-map-find tm k)))
      (bench "Sycamore hash-map (unsorted)" iters
        (dolist (k keys) (sycamore:hash-map-find hm k)))
      (bench "FSet wb-map" iters
        (dolist (k keys) (fset:lookup wm k))))

    ;; --- SORTED ITERATION (2000 keyword pairs) ---
    (format t "~%--- SORTED ITERATION (~D keyword pairs) ---~%" large-n)
    (let* ((pairs (make-keyword-pairs large-n))
           (tm (loop with tm = (sycamore:make-tree-map #'%general-cmp)
                     for (k . v) in pairs
                     do (setf tm (sycamore:tree-map-insert tm k v))
                     finally (return tm)))
           (wm (loop with wm = (fset:empty-map)
                     for (k . v) in pairs
                     do (setf wm (fset:with wm k v))
                     finally (return wm))))
      (bench "Sycamore tree-map (map)" iters
        (sycamore:map-tree-map :inorder nil (lambda (k v) (declare (ignore k v))) tm))
      (bench "FSet wb-map (do-map)" iters
        (fset:do-map (k v wm) (declare (ignore k v)))))

    ;; --- INSERT single pair (into 2000-entry map) ---
    (format t "~%--- INSERT single pair (into ~D-entry map) ---~%" large-n)
    (let* ((pairs (make-keyword-pairs large-n))
           (new-key (intern "ZZZZZ" :keyword))
           (tm (loop with tm = (sycamore:make-tree-map #'%general-cmp)
                     for (k . v) in pairs
                     do (setf tm (sycamore:tree-map-insert tm k v))
                     finally (return tm)))
           (hm (loop with hm = (sycamore:make-hash-map)
                     for (k . v) in pairs
                     do (setf hm (sycamore:hash-map-insert hm k v))
                     finally (return hm)))
           (wm (loop with wm = (fset:empty-map)
                     for (k . v) in pairs
                     do (setf wm (fset:with wm k v))
                     finally (return wm))))
      (bench "Sycamore tree-map" (* iters 100)
        (sycamore:tree-map-insert tm new-key 999))
      (bench "Sycamore hash-map (unsorted)" (* iters 100)
        (sycamore:hash-map-insert hm new-key 999))
      (bench "FSet wb-map" (* iters 100)
        (fset:with wm new-key 999)))

    ;; =====================================================================
    ;; INTEGER KEYS
    ;; =====================================================================

    (format t "~%====== INTEGER KEYS ======~%")

    ;; --- CREATE small (20 integer pairs) ---
    (format t "~%--- CREATE sorted dict (~D integer pairs) ---~%" small-n)
    (let ((pairs (make-integer-pairs small-n)))
      (bench "Sycamore tree-map" iters
        (loop with tm = (sycamore:make-tree-map #'%int-cmp)
              for (k . v) in pairs
              do (setf tm (sycamore:tree-map-insert tm k v))))
      (bench "Sycamore hash-map (unsorted)" iters
        (loop with hm = (sycamore:make-hash-map)
              for (k . v) in pairs
              do (setf hm (sycamore:hash-map-insert hm k v))))
      (bench "FSet wb-map" iters
        (loop with wm = (fset:empty-map)
              for (k . v) in pairs
              do (setf wm (fset:with wm k v)))))

    ;; --- CREATE large (2000 integer pairs) ---
    (format t "~%--- CREATE sorted dict (~D integer pairs) ---~%" large-n)
    (let ((pairs (make-integer-pairs large-n)))
      (bench "Sycamore tree-map" iters
        (loop with tm = (sycamore:make-tree-map #'%int-cmp)
              for (k . v) in pairs
              do (setf tm (sycamore:tree-map-insert tm k v))))
      (bench "Sycamore hash-map (unsorted)" iters
        (loop with hm = (sycamore:make-hash-map)
              for (k . v) in pairs
              do (setf hm (sycamore:hash-map-insert hm k v))))
      (bench "FSet wb-map" iters
        (loop with wm = (fset:empty-map)
              for (k . v) in pairs
              do (setf wm (fset:with wm k v)))))

    ;; --- LOOKUP large (2000 integer keys) ---
    (format t "~%--- LOOKUP (~D integer keys, ~D lookups) ---~%" large-n large-n)
    (let* ((pairs (make-integer-pairs large-n))
           (keys (mapcar #'car pairs))
           (tm (loop with tm = (sycamore:make-tree-map #'%int-cmp)
                     for (k . v) in pairs
                     do (setf tm (sycamore:tree-map-insert tm k v))
                     finally (return tm)))
           (hm (loop with hm = (sycamore:make-hash-map)
                     for (k . v) in pairs
                     do (setf hm (sycamore:hash-map-insert hm k v))
                     finally (return hm)))
           (wm (loop with wm = (fset:empty-map)
                     for (k . v) in pairs
                     do (setf wm (fset:with wm k v))
                     finally (return wm))))
      (bench "Sycamore tree-map" iters
        (dolist (k keys) (sycamore:tree-map-find tm k)))
      (bench "Sycamore hash-map (unsorted)" iters
        (dolist (k keys) (sycamore:hash-map-find hm k)))
      (bench "FSet wb-map" iters
        (dolist (k keys) (fset:lookup wm k))))

    ;; --- SORTED ITERATION (2000 integer pairs) ---
    (format t "~%--- SORTED ITERATION (~D integer pairs) ---~%" large-n)
    (let* ((pairs (make-integer-pairs large-n))
           (tm (loop with tm = (sycamore:make-tree-map #'%int-cmp)
                     for (k . v) in pairs
                     do (setf tm (sycamore:tree-map-insert tm k v))
                     finally (return tm)))
           (wm (loop with wm = (fset:empty-map)
                     for (k . v) in pairs
                     do (setf wm (fset:with wm k v))
                     finally (return wm))))
      (bench "Sycamore tree-map (map)" iters
        (sycamore:map-tree-map :inorder nil (lambda (k v) (declare (ignore k v))) tm))
      (bench "FSet wb-map (do-map)" iters
        (fset:do-map (k v wm) (declare (ignore k v)))))

    ;; --- INSERT single pair (into 2000-entry integer map) ---
    (format t "~%--- INSERT single pair (into ~D-entry map) ---~%" large-n)
    (let* ((pairs (make-integer-pairs large-n))
           (new-key 999999)
           (tm (loop with tm = (sycamore:make-tree-map #'%int-cmp)
                     for (k . v) in pairs
                     do (setf tm (sycamore:tree-map-insert tm k v))
                     finally (return tm)))
           (hm (loop with hm = (sycamore:make-hash-map)
                     for (k . v) in pairs
                     do (setf hm (sycamore:hash-map-insert hm k v))
                     finally (return hm)))
           (wm (loop with wm = (fset:empty-map)
                     for (k . v) in pairs
                     do (setf wm (fset:with wm k v))
                     finally (return wm))))
      (bench "Sycamore tree-map" (* iters 100)
        (sycamore:tree-map-insert tm new-key 999))
      (bench "Sycamore hash-map (unsorted)" (* iters 100)
        (sycamore:hash-map-insert hm new-key 999))
      (bench "FSet wb-map" (* iters 100)
        (fset:with wm new-key 999)))

    (format t "~%Done.~%")))

(run-benchmarks)
