;;; run-idiomatic-bench.lisp
;;;
;;; Compares idiomatic persistent FOL algorithms against native CL equivalents.
;;; Unlike the adversarial benchmarks, these use algorithms suited to the
;;; persistent data structure model:
;;;
;;;   - Merge sort:  no per-element swaps; builds new vectors during merge.
;;;   - BFS (lazy): distances dict starts empty; one assoc per discovered node.
;;;
;;; Run:
;;;   sbcl --noinform --non-interactive \
;;;        --load benchmarks/run-idiomatic-bench.lisp

(require :asdf)
(pushnew #p"c:/Users/frank/Projects/FOL/fol/src/" asdf:*central-registry*)

(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file quicklisp-init)
      (load quicklisp-init)
      (format t "Quicklisp not found.~%")))

(dolist (dep '(:fset :sycamore :closer-mop :uuid :bordeaux-threads :usocket :cl-ppcre :fiveam))
  (if (find-package :ql)
      (uiop:symbol-call :ql :quickload dep)
      (asdf:load-system dep)))

(asdf:load-system :fol-compiler)

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; Timing helper (same as run-adversarial-transient-bench.lisp)
;;;; ─────────────────────────────────────────────────────────────────────────

(defmacro bench-time (label runs &body body)
  "Run BODY RUNS times, print mean wall-clock seconds and allocation, return mean seconds."
  (let ((g-total (gensym)) (g-start (gensym)) (g-r (gensym))
        (g-bytes (gensym)) (g-b0 (gensym)))
    `(let ((,g-total 0)
           (,g-bytes 0))
       (dotimes (,g-r ,runs)
         (sb-ext:gc :full t)
         (let ((,g-b0 (sb-ext:get-bytes-consed))
               (,g-start (get-internal-real-time)))
           (progn ,@body)
           (incf ,g-bytes (- (sb-ext:get-bytes-consed) ,g-b0))
           (incf ,g-total (- (get-internal-real-time) ,g-start))))
       (let ((mean-s  (/ ,g-total ,runs internal-time-units-per-second))
             (mean-mb (/ ,g-bytes ,runs 1e6)))
         (format t "  ~A~34Ttime ~7,3f s   cons ~8,2f MB~%" ,label mean-s mean-mb)
         (values mean-s mean-mb)))))

;;;; ═══════════════════════════════════════════════════════════════════════════
;;;; MERGE SORT
;;;; ═══════════════════════════════════════════════════════════════════════════

;;; ── CL (simple-vector, temporary arrays for each merge pass) ─────────────

(defun cl-merge! (src-a start-a end-a src-b start-b end-b dst start-dst)
  "Merge sorted regions of SRC-A and SRC-B into DST starting at START-DST."
  (declare (type simple-vector src-a src-b dst)
           (type fixnum start-a end-a start-b end-b start-dst)
           (optimize (speed 3) (safety 0)))
  (let ((i start-a) (j start-b) (k start-dst))
    (declare (type fixnum i j k))
    (loop while (and (< i end-a) (< j end-b)) do
      (if (<= (svref src-a i) (svref src-b j))
          (progn (setf (svref dst k) (svref src-a i)) (incf i))
          (progn (setf (svref dst k) (svref src-b j)) (incf j)))
      (incf k))
    (loop while (< i end-a) do
      (setf (svref dst k) (svref src-a i)) (incf i) (incf k))
    (loop while (< j end-b) do
      (setf (svref dst k) (svref src-b j)) (incf j) (incf k))))

(defun cl-msort-pass (src dst width n)
  "Bottom-up merge sort: one pass merging runs of WIDTH."
  (declare (type simple-vector src dst) (type fixnum width n)
           (optimize (speed 3) (safety 0)))
  (let ((lo 0))
    (declare (type fixnum lo))
    (loop while (< lo n) do
      (let* ((mid (min (+ lo width) n))
             (hi  (min (+ lo (* 2 width)) n)))
        (if (< mid n)
            (cl-merge! src lo mid src mid hi dst lo)
            (loop for i fixnum from lo below hi do
              (setf (svref dst i) (svref src i))))
        (incf lo (* 2 width))))))

(defun cl-msort (arr)
  "Bottom-up merge sort on a simple-vector; returns sorted result in place."
  (declare (type simple-vector arr) (optimize (speed 3)))
  (let* ((n (length arr))
         (tmp (make-array n)))
    (let ((src arr) (dst tmp))
      (let ((width 1))
        (loop while (< width n) do
          (cl-msort-pass src dst width n)
          (rotatef src dst)
          (setf width (* 2 width))))
      ;; If result is in tmp, copy back
      (when (eq src tmp)
        (replace arr tmp)))
    arr))

;;; ── FOL (idiomatic: merge two persistent vectors by conj, subvec for halves) ──

(defun fol-merge-vecs (a b)
  "Merge two sorted FOL persistent vectors into a new sorted vector."
  (let ((na (fol.compiler.collections:collection-size a))
        (nb (fol.compiler.collections:collection-size b))
        (acc (fol.compiler.collection-functions:vector)))
    (loop with ia fixnum = 0 and ib fixnum = 0
          while (or (< ia na) (< ib nb))
          do (cond
               ((>= ia na)
                (setf acc (fol.compiler.collection-functions:conj
                           acc (fol.compiler.collection-functions:get b ib)))
                (incf ib))
               ((>= ib nb)
                (setf acc (fol.compiler.collection-functions:conj
                           acc (fol.compiler.collection-functions:get a ia)))
                (incf ia))
               ((<= (fol.compiler.collection-functions:get a ia)
                    (fol.compiler.collection-functions:get b ib))
                (setf acc (fol.compiler.collection-functions:conj
                           acc (fol.compiler.collection-functions:get a ia)))
                (incf ia))
               (t
                (setf acc (fol.compiler.collection-functions:conj
                           acc (fol.compiler.collection-functions:get b ib)))
                (incf ib))))
    acc))

(defun fol-msort (v)
  "Idiomatic persistent merge sort: splits via subvec, merges via conj."
  (let ((n (fol.compiler.collections:collection-size v)))
    (if (<= n 1)
        v
        (let* ((mid (floor n 2))
               (left  (fol-msort (fol.compiler.collection-functions:subvec v 0 mid)))
               (right (fol-msort (fol.compiler.collection-functions:subvec v mid n))))
          (fol-merge-vecs left right)))))

;;; ── Transient helpers (mirrors run-adversarial-transient-bench.lisp) ─────

(defun transient-find-node (node shift hash key not-found)
  "Traverse a mixed persistent/transient HAMT tree to find KEY."
  (declare (type fixnum shift hash) (optimize (speed 3) (safety 0)))
  (cond
    ((null node) not-found)
    ((fol.compiler.collection-primitives::hamt-leaf-p node)
     (if (equal (fol.compiler.collection-primitives::hamt-leaf-key node) key)
         (fol.compiler.collection-primitives::hamt-leaf-value node)
         not-found))
    ((fol.compiler.collection-primitives::hamt-collision-p node)
     (let ((leaf (find key (fol.compiler.collection-primitives::hamt-collision-leaves node)
                       :key #'fol.compiler.collection-primitives::hamt-leaf-key
                       :test #'equal)))
       (if leaf (fol.compiler.collection-primitives::hamt-leaf-value leaf) not-found)))
    ((fol.compiler.collection-primitives::hamt-node-p node)
     (let* ((chunk (logand (ash hash (- shift)) 31))
            (bit   (ash 1 chunk))
            (bmap  (fol.compiler.collection-primitives::hamt-node-bitmap node)))
       (if (zerop (logand bmap bit))
           not-found
           (let* ((idx      (logcount (logand bmap (1- bit))))
                  (children (fol.compiler.collection-primitives::hamt-node-children node)))
             (transient-find-node (svref children idx) (+ shift 5) hash key not-found)))))
    ((fol.compiler.collection-primitives::hamt-transient-node-p node)
     (let* ((chunk (logand (ash hash (- shift)) 31))
            (bit   (ash 1 chunk))
            (bmap  (fol.compiler.collection-primitives::hamt-transient-node-bitmap node)))
       (if (zerop (logand bmap bit))
           not-found
           (let* ((idx      (logcount (logand bmap (1- bit))))
                  (children (fol.compiler.collection-primitives::hamt-transient-node-children node)))
             (transient-find-node (svref children idx) (+ shift 5) hash key not-found)))))
    (t not-found)))

(defun th-get (th key &optional (not-found nil))
  "Read KEY from a transient-hamt TH."
  (transient-find-node
    (fol.compiler.collection-primitives::transient-hamt-root th)
    0 (sxhash key) key not-found))

;;; ── Transient FOL (bottom-up merge sort on transient HAMT) ───────────────
;;;
;;; Uses a single transient HAMT with indices 0..n-1 (work area) and
;;; n..2n-1 (scratch buffer) to alternate src/dst between merge passes.

(defun transient-merge-pass! (th src-off dst-off width n)
  "One bottom-up merge pass: merge pairs of runs of WIDTH from src region to dst region."
  (declare (type fixnum src-off dst-off width n) (optimize (speed 3) (safety 0)))
  (let ((lo 0))
    (declare (type fixnum lo))
    (loop while (< lo n) do
      (let* ((mid (min (+ lo width) n))
             (hi  (min (+ lo (* 2 width)) n)))
        (if (< mid n)
            ;; merge th[src+lo..src+mid) and th[src+mid..src+hi) → th[dst+lo..)
            (let ((i (+ src-off lo)) (j (+ src-off mid)) (k (+ dst-off lo)))
              (declare (type fixnum i j k))
              (let ((iend (+ src-off mid)) (jend (+ src-off hi)))
                (declare (type fixnum iend jend))
                (loop while (and (< i iend) (< j jend)) do
                  (if (<= (the fixnum (th-get th i)) (the fixnum (th-get th j)))
                      (progn (fol.compiler.collection-primitives:hamt-assoc! th k (th-get th i)) (incf i))
                      (progn (fol.compiler.collection-primitives:hamt-assoc! th k (th-get th j)) (incf j)))
                  (incf k))
                (loop while (< i iend) do
                  (fol.compiler.collection-primitives:hamt-assoc! th k (th-get th i))
                  (incf i) (incf k))
                (loop while (< j jend) do
                  (fol.compiler.collection-primitives:hamt-assoc! th k (th-get th j))
                  (incf j) (incf k))))
            ;; odd tail run: copy straight across
            (loop for ii fixnum from lo below hi do
              (fol.compiler.collection-primitives:hamt-assoc!
               th (+ dst-off ii) (th-get th (+ src-off ii)))))
        (incf lo (* 2 width))))))

(defun transient-msort (v)
  "Bottom-up merge sort using a transient HAMT.
  Indices 0..n-1 are the work area; n..2n-1 are a scratch buffer.
  Returns a frozen persistent HAMT keyed by sort position."
  (let* ((n   (fol.compiler.collections:collection-size v))
         (th  (fol.compiler.collection-primitives:api-transient-hamt
               (fol.compiler.collection-primitives:%make-hamt))))
    ;; Load elements from the persistent FOL vector
    (dotimes (i n)
      (fol.compiler.collection-primitives:hamt-assoc!
       th i (fol.compiler.collection-functions:get v i)))
    ;; Bottom-up merge sort with alternating src/dst offsets
    (let ((src-off 0) (dst-off n) (width 1))
      (loop while (< width n) do
        (transient-merge-pass! th src-off dst-off width n)
        (rotatef src-off dst-off)
        (setf width (* 2 width)))
      ;; If result ended up in scratch area, copy back to 0..n-1
      (when (= src-off n)
        (dotimes (i n)
          (fol.compiler.collection-primitives:hamt-assoc!
           th i (th-get th (+ n i))))))
    (fol.compiler.collection-primitives:hamt-persistent! th)))

;;; ── Benchmark harness ────────────────────────────────────────────────────

(defun run-msort-bench (n runs)
  (format t "~%--- Merge Sort  N=~:D  (~A runs) ---~%" n runs)
  (let ((data (make-array n)))
    (dotimes (i n) (setf (svref data i) (random 100000)))

    (let* ((fol-input (let ((v (fol.compiler.collection-functions:vector)))
                        (dotimes (i n v)
                          (setf v (fol.compiler.collection-functions:conj
                                   v (svref data i))))))
           (cl-time
            (bench-time "CL merge sort (simple-vector)  " runs
              (cl-msort (copy-seq data))))
           (fol-time
            (bench-time "FOL merge sort (persistent)    " runs
              (fol-msort fol-input)))
           (trans-time
            (bench-time "FOL merge sort (transient)     " runs
              (transient-msort fol-input))))
      (format t "  Persistent/CL ratio: ~,1f x~%" (/ fol-time cl-time))
      (format t "  Transient/CL ratio:  ~,1f x~%" (/ trans-time cl-time))
      (format t "  Transient speedup vs Persistent: ~,1f x~%"
              (/ fol-time trans-time)))))

;;;; ═══════════════════════════════════════════════════════════════════════════
;;;; BFS (LAZY DISTANCE INITIALIZATION)
;;;; ═══════════════════════════════════════════════════════════════════════════
;;;
;;; Key difference from naive version:
;;;   - Distances dict starts empty; nodes are added only when first discovered.
;;;   - This eliminates the N up-front assoc calls to initialize all dists to -1.
;;;   - Presence in the dict serves as the "visited" test.
;;;   - One assoc per discovered node (same as naive), but zero wasted assocs.

;;; ── CL (hash-table, lazy init) ───────────────────────────────────────────
;;; Graph is pre-built by the caller; only traversal is timed.
;;; Uses an expandable vector as a FIFO to avoid the nconc/nil aliasing bug.

(defun cl-bfs-lazy (graph n)
  "BFS on graph[0..N-1] with lazy hash-table distance init.
  GRAPH is a simple-vector pre-built by the caller."
  (let ((dists (make-hash-table :size n :test #'eql))
        (q     (make-array 16 :adjustable t :fill-pointer 0))
        (qhead 0))
    (setf (gethash 0 dists) 0)
    (vector-push-extend 0 q)
    (loop while (< qhead (fill-pointer q)) do
      (let* ((u (aref q qhead))
             (d (gethash u dists)))
        (incf qhead)
        (dolist (v (svref graph u))
          (unless (gethash v dists)
            (setf (gethash v dists) (1+ d))
            (vector-push-extend v q)))))
    dists))

;;; ── FOL (persistent dict, lazy init) ────────────────────────────────────

(defun fol-make-graph-lazy (n)
  "Build graph as FOL dict: node -> FOL vector of successors."
  (let ((g (fol.compiler.collection-functions:dict)))
    (dotimes (i (1- n))
      (setf g (fol.compiler.collection-functions:assoc
               g i (fol.compiler.collection-functions:vector (1+ i)))))
    (setf g (fol.compiler.collection-functions:assoc
             g (1- n) (fol.compiler.collection-functions:vector)))
    g))

(defun fol-bfs-lazy (graph)
  "BFS with lazy persistent dict: one assoc per discovered node, no init pass.
  Uses an expandable vector FIFO to avoid the nconc/nil aliasing bug."
  (let ((dists (fol.compiler.collection-functions:assoc
                (fol.compiler.collection-functions:dict) 0 0))
        (q     (make-array 16 :adjustable t :fill-pointer 0))
        (qhead 0))
    (vector-push-extend 0 q)
    (loop while (< qhead (fill-pointer q)) do
      (let* ((u (aref q qhead))
             (d (fol.compiler.collection-functions:get dists u))
             (edges (fol.compiler.collection-functions:get graph u)))
        (incf qhead)
        (dolist (v (fol.compiler.collections:collection-seq edges))
          (unless (fol.compiler.collection-functions:get dists v nil)
            (setf dists (fol.compiler.collection-functions:assoc dists v (1+ d)))
            (vector-push-extend v q)))))
    dists))

;;; ── FOL (transient dict, lazy init) ──────────────────────────────────────

(defun fol-bfs-transient (graph)
  "BFS with lazy transient HAMT: hamt-assoc! per discovered node, no path-copy."
  (let* ((dists (fol.compiler.collection-primitives:api-transient-hamt
                 (fol.compiler.collection-primitives:%make-hamt)))
         (q     (make-array 16 :adjustable t :fill-pointer 0))
         (qhead 0))
    (fol.compiler.collection-primitives:hamt-assoc! dists 0 0)
    (vector-push-extend 0 q)
    (loop while (< qhead (fill-pointer q)) do
      (let* ((u (aref q qhead))
             (d (th-get dists u))
             (edges (fol.compiler.collection-functions:get graph u)))
        (incf qhead)
        (dolist (v (fol.compiler.collections:collection-seq edges))
          (unless (th-get dists v)
            (fol.compiler.collection-primitives:hamt-assoc! dists v (1+ d))
            (vector-push-extend v q)))))
    (fol.compiler.collection-primitives:hamt-persistent! dists)))

;;; ── Benchmark harness ────────────────────────────────────────────────────

(defun run-bfs-lazy-bench (n runs)
  (format t "~%--- BFS (lazy init)  N=~:D nodes  (~A runs) ---~%" n runs)
  ;; Pre-build both graphs outside timing; only traversal is measured.
  (let ((cl-graph (let ((g (make-array n)))
                    (dotimes (i (1- n)) (setf (svref g i) (list (1+ i))))
                    (setf (svref g (1- n)) nil)
                    g))
        (fol-graph (fol-make-graph-lazy n)))
    (let* ((cl-time
            (bench-time "CL BFS (hash-table, lazy)        " runs
              (cl-bfs-lazy cl-graph n)))
           (fol-time
            (bench-time "FOL BFS (persistent dict, lazy)  " runs
              (fol-bfs-lazy fol-graph)))
           (trans-time
            (bench-time "FOL BFS (transient dict, lazy)   " runs
              (fol-bfs-transient fol-graph))))
      (format t "  Persistent/CL ratio: ~,1f x~%" (/ fol-time cl-time))
      (format t "  Transient/CL ratio:  ~,1f x~%" (/ trans-time cl-time))
      (format t "  Transient speedup vs Persistent: ~,1f x~%"
              (/ fol-time trans-time)))))

;;;; ═══════════════════════════════════════════════════════════════════════════
;;;; Main
;;;; ═══════════════════════════════════════════════════════════════════════════

(format t "~%Idiomatic Algorithm Benchmarks: FOL vs CL~%")
(format t "~60,,,'-<~>~%")
(format t "Environment: ~A ~A~%" (lisp-implementation-type) (lisp-implementation-version))
(format t "(Algorithms designed for the persistent data structure model)~%")

(run-msort-bench 100000 3)
(run-bfs-lazy-bench 50000 3)

(format t "~%Done.~%")
(sb-ext:exit)
