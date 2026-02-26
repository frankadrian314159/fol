;;; run-adversarial-transient-bench.lisp
;;;
;;; Compares three implementations of two adversarial workloads:
;;;   1. QuickSort on 100,000 elements
;;;   2. BFS on a 50,000-node linear graph
;;;
;;; Per implementation:
;;;   CL        -- native mutable CL (simple-vector / hash-table)
;;;   Persistent -- naive persistent FOL (assoc on every write)
;;;   Transient  -- FOL transient-builder protocol (assoc! inside window)
;;;
;;; Run:
;;;   sbcl --noinform --non-interactive \
;;;        --load benchmarks/run-adversarial-transient-bench.lisp

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
;;;; Transient-HAMT read helper
;;;; find-node only handles persistent hamt-node; transient-node needs own traversal
;;;; ─────────────────────────────────────────────────────────────────────────

(defun transient-find-node (node shift hash key not-found)
  "Traverse a mixed persistent/transient HAMT tree to find KEY."
  (declare (type fixnum shift hash) (optimize (speed 3) (safety 0)))
  (cond
    ((null node)
     not-found)
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
            (bit (ash 1 chunk))
            (bitmap (fol.compiler.collection-primitives::hamt-node-bitmap node)))
       (if (zerop (logand bitmap bit))
           not-found
           (let* ((idx (logcount (logand bitmap (1- bit))))
                  (children (fol.compiler.collection-primitives::hamt-node-children node)))
             (transient-find-node (svref children idx) (+ shift 5) hash key not-found)))))
    ((fol.compiler.collection-primitives::hamt-transient-node-p node)
     (let* ((chunk (logand (ash hash (- shift)) 31))
            (bit (ash 1 chunk))
            (bitmap (fol.compiler.collection-primitives::hamt-transient-node-bitmap node)))
       (if (zerop (logand bitmap bit))
           not-found
           (let* ((idx (logcount (logand bitmap (1- bit))))
                  (children (fol.compiler.collection-primitives::hamt-transient-node-children node)))
             (transient-find-node (svref children idx) (+ shift 5) hash key not-found)))))
    (t not-found)))

(defun th-get (th key &optional (not-found nil))
  "Read KEY from a transient-hamt TH."
  (transient-find-node
    (fol.compiler.collection-primitives::transient-hamt-root th)
    0 (sxhash key) key not-found))

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; Timing helper
;;;; ─────────────────────────────────────────────────────────────────────────

(defmacro bench-time (label runs &body body)
  "Run BODY RUNS times, print mean wall-clock seconds, return mean."
  (let ((g-total (gensym)) (g-start (gensym)) (g-r (gensym)) (g-bytes (gensym))
        (g-b0 (gensym)))
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
         (format t "  ~A~30Ttime ~6,3f s   cons ~7,2f MB~%" ,label mean-s mean-mb)
         mean-s))))

;;;; ═══════════════════════════════════════════════════════════════════════════
;;;; QUICKSORT
;;;; ═══════════════════════════════════════════════════════════════════════════

;;; ── CL (simple-vector, O(1) swap) ───────────────────────────────────────

(defun cl-partition (arr low high)
  (declare (type simple-vector arr) (type fixnum low high) (optimize (speed 3)))
  (let ((pivot (svref arr high))
        (i (1- low)))
    (declare (type fixnum i))
    (loop for j fixnum from low below high do
      (when (<= (svref arr j) pivot)
        (incf i)
        (rotatef (svref arr i) (svref arr j))))
    (incf i)
    (rotatef (svref arr i) (svref arr high))
    i))

(defun cl-qsort (arr low high)
  (declare (type simple-vector arr) (type fixnum low high) (optimize (speed 3)))
  (when (< low high)
    (let ((p (cl-partition arr low high)))
      (cl-qsort arr low (1- p))
      (cl-qsort arr (1+ p) high))))

;;; ── Persistent FOL (assoc on persistent vector at every swap) ────────────

(defun fol-partition (v low high)
  (let ((pivot (fol.compiler.collection-functions:get v high))
        (i (1- low))
        (curr v))
    (loop for j from low below high do
      (when (<= (fol.compiler.collection-functions:get curr j) pivot)
        (incf i)
        (let ((ti (fol.compiler.collection-functions:get curr i))
              (tj (fol.compiler.collection-functions:get curr j)))
          (setf curr (fol.compiler.collection-functions:assoc curr i tj))
          (setf curr (fol.compiler.collection-functions:assoc curr j ti)))))
    (incf i)
    (let ((ti (fol.compiler.collection-functions:get curr i))
          (th (fol.compiler.collection-functions:get curr high)))
      (setf curr (fol.compiler.collection-functions:assoc curr i th))
      (setf curr (fol.compiler.collection-functions:assoc curr high ti)))
    (values curr i)))

(defun fol-qsort (v low high)
  (if (< low high)
      (multiple-value-bind (v2 p) (fol-partition v low high)
        (let ((v3 (fol-qsort v2 low (1- p))))
          (fol-qsort v3 (1+ p) high)))
      v))

;;; ── Transient FOL (assoc! on transient-HAMT used as mutable array) ───────

(defun transient-partition (th low high)
  (let ((pivot (th-get th high))
        (i (1- low)))
    (loop for j from low below high do
      (when (<= (th-get th j) pivot)
        (incf i)
        (let ((ti (th-get th i))
              (tj (th-get th j)))
          (fol.compiler.collection-primitives:hamt-assoc! th i tj)
          (fol.compiler.collection-primitives:hamt-assoc! th j ti))))
    (incf i)
    (let ((ti (th-get th i))
          (th-val (th-get th high)))
      (fol.compiler.collection-primitives:hamt-assoc! th i th-val)
      (fol.compiler.collection-primitives:hamt-assoc! th high ti))
    i))

(defun transient-qsort (th low high)
  (when (< low high)
    (let ((p (transient-partition th low high)))
      (transient-qsort th low (1- p))
      (transient-qsort th (1+ p) high))))

;;; ── Benchmark harness ────────────────────────────────────────────────────

(defun run-qsort-bench (n runs)
  (format t "~%--- QuickSort  N=~:D  (~A runs) ---~%" n runs)
  (let ((data (make-array n)))
    (dotimes (i n) (setf (svref data i) (random 100000)))

    (let ((cl-time
           (bench-time "CL (simple-vector)" runs
             (let ((arr (copy-seq data)))
               (cl-qsort arr 0 (1- n))
               arr)))
          (fol-time
           (bench-time "Persistent FOL (assoc)" runs
             (let ((v (let ((acc (fol.compiler.collection-functions:vector)))
                        (dotimes (i n acc)
                          (setf acc (fol.compiler.collection-functions:conj
                                     acc (svref data i)))))))
               (fol-qsort v 0 (1- n)))))
          (trans-time
           (bench-time "Transient FOL (assoc!)" runs
             (let* ((empty (fol.compiler.collection-primitives:%make-hamt))
                    (th (fol.compiler.collection-primitives:api-transient-hamt empty)))
               (dotimes (i n)
                 (fol.compiler.collection-primitives:hamt-assoc! th i (svref data i)))
               (transient-qsort th 0 (1- n))
               (fol.compiler.collection-primitives:hamt-persistent! th)))))
      (format t "  Persistent/CL ratio:  ~,1f x~%" (/ fol-time cl-time))
      (format t "  Transient/CL ratio:   ~,1f x~%" (/ trans-time cl-time))
      (format t "  Transient speedup vs Persistent: ~,1f x~%"
              (/ fol-time trans-time)))))

;;;; ═══════════════════════════════════════════════════════════════════════════
;;;; BFS
;;;; ═══════════════════════════════════════════════════════════════════════════

;;; Build a linear graph: 0→1→2→...→(n-1).  All distances are integers.
;;; Start node 0, initial dist 0; all others -1.

;;; ── CL (hash-table for dists) ────────────────────────────────────────────

(defun run-cl-bfs (n)
  (let ((graph (make-array n))   ; graph[i] = list of successors
        (dists (make-hash-table :size n)))
    (dotimes (i (1- n)) (setf (svref graph i) (list (1+ i))))
    (setf (svref graph (1- n)) nil)
    (dotimes (i n) (setf (gethash i dists) -1))
    (setf (gethash 0 dists) 0)
    (let ((q (list 0)))
      (loop while q do
        (let* ((u (pop q))
               (d (gethash u dists)))
          (dolist (v (svref graph u))
            (when (= -1 (gethash v dists))
              (setf (gethash v dists) (1+ d))
              (nconc q (list v))))))
      dists)))

;;; ── Persistent FOL (assoc on persistent dict for dists) ─────────────────

(defun fol-make-graph (n)
  "Build graph as a FOL persistent dict: node -> FOL vector of successors."
  (let ((g (fol.compiler.collection-functions:dict)))
    (dotimes (i (1- n))
      (setf g (fol.compiler.collection-functions:assoc
               g i (fol.compiler.collection-functions:vector (1+ i)))))
    (setf g (fol.compiler.collection-functions:assoc
             g (1- n) (fol.compiler.collection-functions:vector)))
    g))

(defun fol-make-dists (n)
  "Build initial distances dict: all -1 except node 0 = 0."
  (let ((d (fol.compiler.collection-functions:dict)))
    (dotimes (i n)
      (setf d (fol.compiler.collection-functions:assoc d i -1)))
    (fol.compiler.collection-functions:assoc d 0 0)))

(defun fol-bfs (graph n)
  (let ((dists (fol-make-dists n))
        (q (list 0)))
    (loop while q do
      (let* ((u (pop q))
             (d (fol.compiler.collection-functions:get dists u))
             (edges (fol.compiler.collection-functions:get graph u)))
        (dolist (v (fol.compiler.collections:collection-seq edges))
          (when (= -1 (fol.compiler.collection-functions:get dists v))
            (setf dists (fol.compiler.collection-functions:assoc dists v (1+ d)))
            (nconc q (list v))))))
    dists))

;;; ── Transient FOL (transient-HAMT for dists) ─────────────────────────────

(defun trans-make-dists (n)
  "Build initial dists as a transient-HAMT directly."
  (let* ((empty (fol.compiler.collection-primitives:%make-hamt))
         (th (fol.compiler.collection-primitives:api-transient-hamt empty)))
    (dotimes (i n)
      (fol.compiler.collection-primitives:hamt-assoc! th i -1))
    (fol.compiler.collection-primitives:hamt-assoc! th 0 0)
    th))

(defun trans-bfs (graph n)
  "BFS with transient-HAMT for distances; graph is a CL array for speed."
  (let ((dists (trans-make-dists n))
        (q (list 0)))
    (loop while q do
      (let* ((u (pop q))
             (d (th-get dists u))
             (edges (svref graph u)))
        (dolist (v edges)
          (when (= -1 (th-get dists v))
            (fol.compiler.collection-primitives:hamt-assoc! dists v (1+ d))
            (nconc q (list v))))))
    (fol.compiler.collection-primitives:hamt-persistent! dists)))

;;; ── Benchmark harness ────────────────────────────────────────────────────

(defun run-bfs-bench (n runs)
  (format t "~%--- BFS  N=~:D nodes  (~A runs) ---~%" n runs)
  ;; Pre-build graph structures (not included in timing)
  (let ((cl-graph (make-array n))
        (fol-graph (fol-make-graph n)))
    (dotimes (i (1- n)) (setf (svref cl-graph i) (list (1+ i))))
    (setf (svref cl-graph (1- n)) nil)

    (let ((cl-time
           (bench-time "CL (hash-table dists)" runs
             (run-cl-bfs n)))
          (fol-time
           (bench-time "Persistent FOL (assoc dists)" runs
             (fol-bfs fol-graph n)))
          (trans-time
           (bench-time "Transient FOL (assoc! dists)" runs
             (trans-bfs cl-graph n))))
      (format t "  Persistent/CL ratio:  ~,1f x~%" (/ fol-time cl-time))
      (format t "  Transient/CL ratio:   ~,1f x~%" (/ trans-time cl-time))
      (format t "  Transient speedup vs Persistent: ~,1f x~%"
              (/ fol-time trans-time)))))

;;;; ═══════════════════════════════════════════════════════════════════════════
;;;; Main
;;;; ═══════════════════════════════════════════════════════════════════════════

(format t "~%Adversarial Workload Benchmarks: Persistent vs Transient FOL~%")
(format t "~60,,,'-<~>~%")
(format t "Environment: ~A ~A~%" (lisp-implementation-type) (lisp-implementation-version))

(run-qsort-bench 100000 3)
(run-bfs-bench   50000  3)

(format t "~%Done.~%")
(sb-ext:exit)
