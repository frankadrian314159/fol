;;; Benchmark: Data structures for an array-dict
;;;
;;; An array-dict stores key-value pairs in a contiguous array structure.
;;; Best suited for small dictionaries where cache-friendly linear scan
;;; beats hash table overhead. The crossover point (where hashing wins)
;;; is the key finding.
;;;
;;; Candidates:
;;;   1. FSet seq of (key . value) pairs
;;;      Persistent, structural sharing. O(log n) append, O(n) key lookup.
;;;
;;;   2. CL simple-vector of (key . value) pairs (copy-on-write)
;;;      copy-seq on insert. O(1) indexed access, O(n) key lookup.
;;;
;;;   3. CL simple-vector alternating [k0 v0 k1 v1 ...] (copy-on-write)
;;;      No per-entry cons. O(1) indexed, O(n) key lookup. Stride-2 scan.
;;;
;;;   4. Sycamore hash-map (baseline — what <dict> already uses)
;;;      O(~1) lookup, O(~1) insert. The reference for when hashing wins.

(require :fset)
(require :sycamore)

;;; --- Data generators ---

(defun make-keyword-pairs (n)
  "Return a list of (keyword . integer) pairs."
  (loop for i below n
        collect (cons (intern (format nil "KEY-~4,'0D" i) :keyword) i)))

;;; --- Bench macro ---

(defmacro bench (label iterations &body body)
  `(let ((start (get-internal-real-time)))
     (loop repeat ,iterations do ,@body)
     (let* ((elapsed (/ (- (get-internal-real-time) start)
                        (float internal-time-units-per-second)))
            (ms (* elapsed 1000.0)))
       (format t "  ~42A ~8,2F ms~%" ,label ms))))

;;; =========================================================================
;;; Builders
;;; =========================================================================

(defun build-fset-seq (pairs)
  "Build an FSet seq of (key . value) pairs."
  (fset:convert 'fset:seq pairs))

(defun build-cl-vector-pairs (pairs)
  "Build a CL simple-vector of (key . value) conses."
  (coerce pairs 'simple-vector))

(defun build-cl-vector-flat (pairs)
  "Build a CL simple-vector [k0 v0 k1 v1 ...]."
  (let ((vec (make-array (* 2 (length pairs)))))
    (loop for (k . v) in pairs
          for i from 0 by 2
          do (setf (svref vec i) k
                   (svref vec (1+ i)) v))
    vec))

(defun build-sycamore-hm (pairs)
  "Build a Sycamore hash-map."
  (loop with hm = (sycamore:make-hash-map)
        for (k . v) in pairs
        do (setf hm (sycamore:hash-map-insert hm k v))
        finally (return hm)))

;;; =========================================================================
;;; Lookup helpers
;;; =========================================================================

(defun fset-seq-find (seq key)
  "Linear scan an FSet seq of pairs for KEY."
  (fset:do-seq (pair seq)
    (when (eql (car pair) key)
      (return-from fset-seq-find (cdr pair)))))

(defun cl-vec-pairs-find (vec key)
  "Linear scan a CL vector of (key . value) for KEY."
  (declare (simple-vector vec))
  (loop for i below (length vec)
        for pair = (svref vec i)
        when (eql (car pair) key)
          return (cdr pair)))

(defun cl-vec-flat-find (vec key)
  "Stride-2 scan a flat CL vector [k0 v0 k1 v1 ...] for KEY."
  (declare (simple-vector vec))
  (loop for i below (length vec) by 2
        when (eql (svref vec i) key)
          return (svref vec (1+ i))))

;;; =========================================================================
;;; Insert helpers (persistent: return new structure)
;;; =========================================================================

(defun fset-seq-insert (seq key val)
  "Insert/append (key . val) to FSet seq. No dedup for benchmark."
  (fset:with-last seq (cons key val)))

(defun cl-vec-pairs-insert (vec key val)
  "Copy-on-write insert into CL vector of pairs."
  (declare (simple-vector vec))
  (let* ((len (length vec))
         (new (make-array (1+ len))))
    (loop for i below len do (setf (svref new i) (svref vec i)))
    (setf (svref new len) (cons key val))
    new))

(defun cl-vec-flat-insert (vec key val)
  "Copy-on-write insert into flat CL vector."
  (declare (simple-vector vec))
  (let* ((len (length vec))
         (new (make-array (+ len 2))))
    (loop for i below len do (setf (svref new i) (svref vec i)))
    (setf (svref new len) key
          (svref new (1+ len)) val)
    new))

;;; =========================================================================
;;; Benchmarks
;;; =========================================================================

(defun run-benchmarks ()
  (let ((iters 1000))

    (format t "~%=== Array-Dict Benchmarks ===~%")
    (format t "Iterations: ~D~%~%" iters)

    (dolist (n '(5 10 20 50 100 200))

      (format t "~%====== ~D ENTRIES ======~%" n)
      (let ((pairs (make-keyword-pairs n)))

        ;; --- CREATE ---
        (format t "~%--- CREATE (~D pairs) ---~%" n)
        (bench "FSet seq of pairs" iters
          (build-fset-seq pairs))
        (bench "CL vector of pairs (copy)" iters
          (build-cl-vector-pairs pairs))
        (bench "CL flat vector [k v k v]" iters
          (build-cl-vector-flat pairs))
        (bench "Sycamore hash-map" iters
          (build-sycamore-hm pairs))

        ;; --- LOOKUP all keys ---
        (format t "~%--- LOOKUP all ~D keys ---~%" n)
        (let ((fseq (build-fset-seq pairs))
              (cvp  (build-cl-vector-pairs pairs))
              (cvf  (build-cl-vector-flat pairs))
              (shm  (build-sycamore-hm pairs))
              (keys (mapcar #'car pairs)))
          (bench "FSet seq (linear scan)" iters
            (dolist (k keys) (fset-seq-find fseq k)))
          (bench "CL vector of pairs (linear)" iters
            (dolist (k keys) (cl-vec-pairs-find cvp k)))
          (bench "CL flat vector (stride-2)" iters
            (dolist (k keys) (cl-vec-flat-find cvf k)))
          (bench "Sycamore hash-map" iters
            (dolist (k keys) (sycamore:hash-map-find shm k))))

        ;; --- LOOKUP single key (middle) ---
        (format t "~%--- LOOKUP single key (middle of ~D) ---~%" n)
        (let ((fseq (build-fset-seq pairs))
              (cvp  (build-cl-vector-pairs pairs))
              (cvf  (build-cl-vector-flat pairs))
              (shm  (build-sycamore-hm pairs))
              (mid-key (car (nth (floor n 2) pairs))))
          (bench "FSet seq (linear scan)" iters
            (fset-seq-find fseq mid-key))
          (bench "CL vector of pairs (linear)" iters
            (cl-vec-pairs-find cvp mid-key))
          (bench "CL flat vector (stride-2)" iters
            (cl-vec-flat-find cvf mid-key))
          (bench "Sycamore hash-map" iters
            (sycamore:hash-map-find shm mid-key)))

        ;; --- INSERT single entry ---
        (format t "~%--- INSERT single entry (into ~D) ---~%" n)
        (let ((fseq (build-fset-seq pairs))
              (cvp  (build-cl-vector-pairs pairs))
              (cvf  (build-cl-vector-flat pairs))
              (shm  (build-sycamore-hm pairs))
              (new-key (intern "NEW-KEY" :keyword)))
          (bench "FSet seq (with-last)" iters
            (fset-seq-insert fseq new-key 999))
          (bench "CL vector of pairs (copy+append)" iters
            (cl-vec-pairs-insert cvp new-key 999))
          (bench "CL flat vector (copy+append)" iters
            (cl-vec-flat-insert cvf new-key 999))
          (bench "Sycamore hash-map" iters
            (sycamore:hash-map-insert shm new-key 999)))

        ;; --- ITERATE ---
        (format t "~%--- ITERATE (~D entries) ---~%" n)
        (let ((fseq (build-fset-seq pairs))
              (cvp  (build-cl-vector-pairs pairs))
              (cvf  (build-cl-vector-flat pairs))
              (shm  (build-sycamore-hm pairs)))
          (bench "FSet seq (do-seq)" iters
            (fset:do-seq (pair fseq) (identity pair)))
          (bench "CL vector of pairs (loop)" iters
            (loop for pair across cvp do (identity pair)))
          (bench "CL flat vector (stride-2 loop)" iters
            (loop for i below (length cvf) by 2
                  do (svref cvf i) (svref cvf (1+ i))))
          (bench "Sycamore hash-map (fold)" iters
            (sycamore:fold-hash-map
             (lambda (acc k v) (declare (ignore acc k v))) nil shm)))))

    (format t "~%=== Done ===~%")))

(run-benchmarks)
