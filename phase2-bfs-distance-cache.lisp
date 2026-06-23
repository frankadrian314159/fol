#!/usr/bin/env sbcl --script
;;; Phase 2, Item 1: BFS Distance Cache Optimization
;;;
;;; Compares BFS performance:
;;; 1. Baseline (no optimization)
;;; 2. Phase 1 (pragma enabled)
;;; 3. Phase 2a (distance cache - local mutable dict converted at end)
;;;
;;; The distance cache avoids repeated assoc/get dispatch overhead by using
;;; a local mutable structure during traversal.

(require :asdf)
(pushnew #p"c:/Users/frank/Projects/FOL/fol/src/" asdf:*central-registry*)

(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file quicklisp-init) (load quicklisp-init)))

(dolist (dep '(:fset :sycamore :closer-mop :uuid :bordeaux-threads :usocket :cl-ppcre :fiveam))
  (if (find-package :ql)
      (uiop:symbol-call :ql :quickload dep)
      (asdf:load-system dep)))

(asdf:load-system :fol-compiler)

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; CL Reference Implementation
;;;; ─────────────────────────────────────────────────────────────────────────

(defun cl-make-graph-lazy (n)
  "Create linear graph: 0→1→2→...→(n-1)"
  (let ((graph (make-array n)))
    (dotimes (i (1- n))
      (setf (svref graph i) (list (1+ i))))
    (setf (svref graph (1- n)) nil)
    graph))

(defun cl-bfs-lazy (graph n)
  "CL reference: hash-table for distances"
  (let ((dists (make-hash-table :size n :test #'eql)))
    (setf (gethash 0 dists) 0)
    (let ((q (list 0)))
      (loop while q do
        (let* ((u (pop q))
               (d (gethash u dists)))
          (dolist (v (svref graph u))
            (unless (gethash v dists)
              (setf (gethash v dists) (1+ d))
              (nconc q (list v)))))))
    dists))

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; FOL Implementations
;;;; ─────────────────────────────────────────────────────────────────────────

(format t "~%Compiling FOL BFS implementations...~%")

;; Helper to make FOL graph
(eval (fol.compiler:compilation-result-code
  (fol.compiler:compile-form
    (fol.compiler.reader:fol-read-from-string "
(defn fol-make-graph [n]
  (loop [i 0, g (dict)]
    (if (< i (- n 1))
      (recur (+ i 1) (assoc g i [i 1 (+ i 1)]))
      (assoc g (- n 1) []))))
"))))

;; Baseline: No optimization
(fol.compiler:disable-inline-methods)

(eval (fol.compiler:compilation-result-code
  (fol.compiler:compile-form
    (fol.compiler.reader:fol-read-from-string "
(defn bfs-baseline [graph n]
  (loop [q [0], dists (dict 0 0)]
    (if (empty? q)
      dists
      (bind [u (get q 0)
             rest-q (if (> (count q) 1) (subvec q 1) [])
             d (get dists u)
             neighbors (get graph u)]
        (loop [j 0, curr-q rest-q, curr-dists dists]
          (if (< j (count neighbors))
            (bind [v (get neighbors j)]
              (if (nil? (get curr-dists v nil))
                (recur (+ j 1)
                       (conj curr-q v)
                       (assoc curr-dists v (+ d 1)))
                (recur (+ j 1) curr-q curr-dists)))
            (recur (+ 1 (count rest-q))
                   curr-q
                   curr-dists)))))))
"))))

;; Phase 1: With pragma
(fol.compiler:enable-inline-methods t)

(eval (fol.compiler:compilation-result-code
  (fol.compiler:compile-form
    (fol.compiler.reader:fol-read-from-string "
(defn bfs-p1 [graph n]
  (loop [q [0], dists (dict 0 0)]
    (if (empty? q)
      dists
      (bind [u (get q 0)
             rest-q (if (> (count q) 1) (subvec q 1) [])
             d (get dists u)
             neighbors (get graph u)]
        (loop [j 0, curr-q rest-q, curr-dists dists]
          (if (< j (count neighbors))
            (bind [v (get neighbors j)]
              (if (nil? (get curr-dists v nil))
                (recur (+ j 1)
                       (conj curr-q v)
                       (assoc curr-dists v (+ d 1)))
                (recur (+ j 1) curr-q curr-dists)))
            (recur (+ 1 (count rest-q))
                   curr-q
                   curr-dists)))))))
"))))

(fol.compiler:disable-inline-methods)

;; Phase 2a: Distance cache optimization
;; Use local mutable vector as cache to reduce assoc overhead
(fol.compiler:enable-inline-methods t)

(eval (fol.compiler:compilation-result-code
  (fol.compiler:compile-form
    (fol.compiler.reader:fol-read-from-string "
(defn bfs-p2a [graph n]
  \"BFS with local distance vector cache.
   Allocate mutable array for distances, fill during traversal,
   convert to persistent dict at end.\"
  (bind [cache (make-array n :initial-element nil)]
    (loop [q [0], idx 0]
      (if (< idx (count q))
        (bind [u (get q idx)
               d (aget cache u)
               neighbors (get graph u)]
          (loop [j 0, curr-q q]
            (if (< j (count neighbors))
              (bind [v (get neighbors j)]
                (if (nil? (aget cache v))
                  (do (aset cache v (+ d 1))
                      (recur (+ j 1) (conj curr-q v)))
                  (recur (+ j 1) curr-q)))
              (recur (+ idx 1) curr-q))))
        (loop [i 0, result (dict)]
          (if (< i n)
            (bind [d (aget cache i)]
              (if (nil? d)
                (recur (+ i 1) result)
                (recur (+ i 1) (assoc result i d))))
            result))))))
"))))

(fol.compiler:disable-inline-methods)

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; Benchmarking
;;;; ─────────────────────────────────────────────────────────────────────────

(format t "~%~%")
(format t "════════════════════════════════════════════════════════════════════~%")
(format t "        PHASE 2, ITEM 1: BFS DISTANCE CACHE OPTIMIZATION~%")
(format t "════════════════════════════════════════════════════════════════════~%")

(let ((n 50000))
  (format t "~%=== BFS BENCHMARK (N=~:D nodes, linear graph) ===~%~%" n)

  ;; Create test graph
  (format t "Creating test graph...~%")
  (let ((cl-graph (cl-make-graph-lazy n))
        (fol-graph (fol-make-graph n)))

    ;; Warmup
    (format t "Warming up...~%")
    (cl-bfs-lazy cl-graph n)
    (bfs-baseline fol-graph n)
    (bfs-p1 fol-graph n)
    (bfs-p2a fol-graph n)

    ;; Benchmark results
    (format t "~%Benchmark Results (3 runs, average):~%")
    (format t "~%~{~A~%~}" '(
      "┌──────────────────────────────────┬──────────┬──────────────────┐"
      "│ Implementation                   │ Time(ms) │ vs Baseline      │"
      "├──────────────────────────────────┼──────────┼──────────────────┤"))

    ;; CL baseline
    (sb-ext:gc :full t)
    (let ((times (list)))
      (dotimes (i 3)
        (let ((start (get-internal-real-time)))
          (cl-bfs-lazy cl-graph n)
          (push (/ (- (get-internal-real-time) start) internal-time-units-per-second) times)))
      (let ((avg (/ (apply #'+ times) 3)))
        (format t "│ CL (reference)                   │ ~7,2F   │ baseline         │~%" (* avg 1000))))

    ;; Baseline (no optimization)
    (sb-ext:gc :full t)
    (let ((times (list)) (baseline-time nil))
      (dotimes (i 3)
        (let ((start (get-internal-real-time)))
          (bfs-baseline fol-graph n)
          (push (/ (- (get-internal-real-time) start) internal-time-units-per-second) times)))
      (let ((avg (/ (apply #'+ times) 3)))
        (setf baseline-time avg)
        (format t "│ FOL Baseline (no optimization)   │ ~7,2F   │ 1.0×             │~%" (* avg 1000))))

    ;; Phase 1 (pragma enabled)
    (sb-ext:gc :full t)
    (let ((times (list)) (p1-time nil))
      (dotimes (i 3)
        (let ((start (get-internal-real-time)))
          (bfs-p1 fol-graph n)
          (push (/ (- (get-internal-real-time) start) internal-time-units-per-second) times)))
      (let ((avg (/ (apply #'+ times) 3)))
        (setf p1-time avg)
        (format t "│ FOL Phase 1 (pragma)             │ ~7,2F   │ ~,2Fx          │~%"
                (* avg 1000) (/ baseline-time avg))))

    ;; Phase 2a (distance cache)
    (sb-ext:gc :full t)
    (let ((times (list)) (p2a-time nil))
      (dotimes (i 3)
        (let ((start (get-internal-real-time)))
          (bfs-p2a fol-graph n)
          (push (/ (- (get-internal-real-time) start) internal-time-units-per-second) times)))
      (let ((avg (/ (apply #'+ times) 3)))
        (setf p2a-time avg)
        (format t "│ FOL Phase 2a (distance cache)    │ ~7,2F   │ ~,2Fx          │~%"
                (* avg 1000) (/ baseline-time avg))))

    (format t "~%~{~A~%~}" '(
      "└──────────────────────────────────┴──────────┴──────────────────┘"))))

(format t "~%~%")
(format t "════════════════════════════════════════════════════════════════════~%")
(format t "                          OPTIMIZATION SUMMARY~%")
(format t "════════════════════════════════════════════════════════════════════~%")
(format t "~%Phase 1 (Pragma Inlining):~%")
(format t "  - Eliminates assoc dispatch overhead~%")
(format t "  - Expected: 5-10x speedup~%")
(format t "~%Phase 2a (Distance Cache):~%")
(format t "  - Uses mutable array for distances during traversal~%")
(format t "  - Converts to persistent dict at completion~%")
(format t "  - Reduces assoc/get dispatch calls significantly~%")
(format t "  - Expected: 2-3x speedup on top of Phase 1~%")
(format t "~%Combined Phase 1+2a:~%")
(format t "  - Expected: 5-10x × 2-3x = 10-30x total speedup~%")
(format t "~%")
(format t "════════════════════════════════════════════════════════════════════~%")

(sb-ext:exit)
