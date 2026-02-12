;;; Benchmark: FSet vs Sycamore for dense integer sets
;;;
;;; Dense integer sets contain contiguous or near-contiguous ranges of integers.
;;; Candidates:
;;;   1. Sycamore tree-set (with fixnum comparator)
;;;   2. Sycamore hash-set (EQL-based HAMT)
;;;   3. FSet wb-set (weight-balanced tree)
;;;   4. CL bit-vector (native, as baseline reference)

(require :fset)
(require :sycamore)

(defun %int-cmp (a b)
  (declare (optimize (speed 3) (safety 0))
           (fixnum a b))
  (cond ((< a b) -1) ((> a b) 1) (t 0)))

(defun make-dense-range (n &optional (start 0))
  "Return a list of N consecutive integers starting at START."
  (loop for i from start below (+ start n) collect i))

(defun make-dense-shuffled (n &optional (start 0))
  "Return a shuffled list of N consecutive integers starting at START."
  (let ((vec (coerce (make-dense-range n start) 'vector)))
    (loop for i from (1- (length vec)) downto 1
          for j = (random (1+ i))
          do (rotatef (aref vec i) (aref vec j)))
    (coerce vec 'list)))

(defmacro bench (label iterations &body body)
  `(let ((start (get-internal-real-time)))
     (loop repeat ,iterations do ,@body)
     (let* ((elapsed (/ (- (get-internal-real-time) start)
                        (float internal-time-units-per-second)))
            (ms (* elapsed 1000.0)))
       (format t "  ~30A ~8,2F ms~%" ,label ms))))

(defun run-benchmarks ()
  (let ((iters 1000)
        (small-n 100)
        (large-n 10000))

    (format t "~%=== Dense Int Set Benchmarks ===~%")
    (format t "Iterations: ~D~%~%" iters)

    ;; --- CREATE small dense set (100 elements) ---
    (format t "--- CREATE dense set (~D elements) ---~%" small-n)
    (let ((elems (make-dense-shuffled small-n)))
      (bench "Sycamore tree-set" iters
        (loop with ts = (sycamore:make-tree-set #'%int-cmp)
              for e in elems
              do (setf ts (sycamore:tree-set-insert ts e))))
      (bench "Sycamore hash-set" iters
        (loop with hs = (sycamore:make-hash-set)
              for e in elems
              do (setf hs (sycamore:hash-set-insert hs e))))
      (bench "FSet wb-set" iters
        (loop with ws = (fset:empty-set)
              for e in elems
              do (setf ws (fset:with ws e))))
      (bench "CL bit-vector (baseline)" iters
        (let ((bv (make-array small-n :element-type 'bit :initial-element 0)))
          (dolist (e elems) (setf (sbit bv e) 1)))))

    ;; --- CREATE large dense set (10000 elements) ---
    (format t "~%--- CREATE dense set (~D elements) ---~%" large-n)
    (let ((elems (make-dense-shuffled large-n)))
      (bench "Sycamore tree-set" iters
        (loop with ts = (sycamore:make-tree-set #'%int-cmp)
              for e in elems
              do (setf ts (sycamore:tree-set-insert ts e))))
      (bench "Sycamore hash-set" iters
        (loop with hs = (sycamore:make-hash-set)
              for e in elems
              do (setf hs (sycamore:hash-set-insert hs e))))
      (bench "FSet wb-set" iters
        (loop with ws = (fset:empty-set)
              for e in elems
              do (setf ws (fset:with ws e))))
      (bench "CL bit-vector (baseline)" iters
        (let ((bv (make-array large-n :element-type 'bit :initial-element 0)))
          (dolist (e elems) (setf (sbit bv e) 1)))))

    ;; --- MEMBERSHIP on small dense set ---
    (format t "~%--- MEMBERSHIP on dense set (~D elements, ~D lookups) ---~%" small-n small-n)
    (let* ((elems (make-dense-shuffled small-n))
           (ts (loop with ts = (sycamore:make-tree-set #'%int-cmp)
                     for e in elems do (setf ts (sycamore:tree-set-insert ts e))
                     finally (return ts)))
           (hs (loop with hs = (sycamore:make-hash-set)
                     for e in elems do (setf hs (sycamore:hash-set-insert hs e))
                     finally (return hs)))
           (ws (loop with ws = (fset:empty-set)
                     for e in elems do (setf ws (fset:with ws e))
                     finally (return ws)))
           (bv (let ((bv (make-array small-n :element-type 'bit :initial-element 0)))
                 (dolist (e elems) (setf (sbit bv e) 1)) bv)))
      (bench "Sycamore tree-set" iters
        (dolist (e elems) (sycamore:tree-set-member-p ts e)))
      (bench "Sycamore hash-set" iters
        (dolist (e elems) (sycamore:hash-set-find hs e)))
      (bench "FSet wb-set" iters
        (dolist (e elems) (fset:contains? ws e)))
      (bench "CL bit-vector (baseline)" iters
        (dolist (e elems) (= 1 (sbit bv e)))))

    ;; --- MEMBERSHIP on large dense set ---
    (format t "~%--- MEMBERSHIP on dense set (~D elements, ~D lookups) ---~%" large-n large-n)
    (let* ((elems (make-dense-shuffled large-n))
           (ts (loop with ts = (sycamore:make-tree-set #'%int-cmp)
                     for e in elems do (setf ts (sycamore:tree-set-insert ts e))
                     finally (return ts)))
           (hs (loop with hs = (sycamore:make-hash-set)
                     for e in elems do (setf hs (sycamore:hash-set-insert hs e))
                     finally (return hs)))
           (ws (loop with ws = (fset:empty-set)
                     for e in elems do (setf ws (fset:with ws e))
                     finally (return ws)))
           (bv (let ((bv (make-array large-n :element-type 'bit :initial-element 0)))
                 (dolist (e elems) (setf (sbit bv e) 1)) bv)))
      (bench "Sycamore tree-set" iters
        (dolist (e elems) (sycamore:tree-set-member-p ts e)))
      (bench "Sycamore hash-set" iters
        (dolist (e elems) (sycamore:hash-set-find hs e)))
      (bench "FSet wb-set" iters
        (dolist (e elems) (fset:contains? ws e)))
      (bench "CL bit-vector (baseline)" iters
        (dolist (e elems) (= 1 (sbit bv e)))))

    ;; --- SORTED ITERATION on large dense set ---
    (format t "~%--- SORTED ITERATION (~D elements) ---~%" large-n)
    (let* ((elems (make-dense-shuffled large-n))
           (ts (loop with ts = (sycamore:make-tree-set #'%int-cmp)
                     for e in elems do (setf ts (sycamore:tree-set-insert ts e))
                     finally (return ts)))
           (hs (loop with hs = (sycamore:make-hash-set)
                     for e in elems do (setf hs (sycamore:hash-set-insert hs e))
                     finally (return hs)))
           (ws (loop with ws = (fset:empty-set)
                     for e in elems do (setf ws (fset:with ws e))
                     finally (return ws)))
           (bv (let ((bv (make-array large-n :element-type 'bit :initial-element 0)))
                 (dolist (e elems) (setf (sbit bv e) 1)) bv)))
      (bench "Sycamore tree-set (map)" iters
        (sycamore:map-tree-set nil (lambda (x) (declare (ignore x))) ts))
      ;; hash-set has no sorted iteration - skip
      (bench "FSet wb-set (do-set)" iters
        (fset:do-set (x ws) (declare (ignore x))))
      (bench "CL bit-vector (scan)" iters
        (loop for i below large-n when (= 1 (sbit bv i)) do (identity i))))

    ;; --- INSERT single element (into existing large set) ---
    (format t "~%--- INSERT single element (into ~D-element set) ---~%" large-n)
    (let* ((elems (make-dense-range large-n))
           (new-elem (+ large-n 1))
           (ts (loop with ts = (sycamore:make-tree-set #'%int-cmp)
                     for e in elems do (setf ts (sycamore:tree-set-insert ts e))
                     finally (return ts)))
           (hs (loop with hs = (sycamore:make-hash-set)
                     for e in elems do (setf hs (sycamore:hash-set-insert hs e))
                     finally (return hs)))
           (ws (loop with ws = (fset:empty-set)
                     for e in elems do (setf ws (fset:with ws e))
                     finally (return ws))))
      (bench "Sycamore tree-set" (* iters 100)
        (sycamore:tree-set-insert ts new-elem))
      (bench "Sycamore hash-set" (* iters 100)
        (sycamore:hash-set-insert hs new-elem))
      (bench "FSet wb-set" (* iters 100)
        (fset:with ws new-elem)))

    (format t "~%Done.~%")))

(run-benchmarks)
