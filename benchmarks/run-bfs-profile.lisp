;;; run-bfs-profile.lisp
;;;
;;; Two complementary analyses of the lazy-init BFS result:
;;;
;;;  1. SCALING ANALYSIS: run at N = 5K, 10K, 25K, 50K, 100K, 200K, 400K.
;;;     If the cache-pressure hypothesis is correct, CL's ns/node should
;;;     grow faster than FOL's as the hash-table working set grows.
;;;
;;;  2. STATISTICAL PROFILING (sb-sprof, :mode :cpu): one run each of the
;;;     CL and FOL implementations at N = 50,000 to show where CPU time
;;;     is actually spent.
;;;
;;; Run:
;;;   sbcl --noinform --non-interactive \
;;;        --load benchmarks/run-bfs-profile.lisp

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
(require :sb-sprof)

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; Timing helper
;;;; ─────────────────────────────────────────────────────────────────────────

(defmacro timed-run (&body body)
  "Execute BODY, return (values seconds bytes-consed)."
  (let ((t0 (gensym)) (b0 (gensym)))
    `(progn
       (sb-ext:gc :full t)
       (let ((,t0 (get-internal-real-time))
             (,b0 (sb-ext:get-bytes-consed)))
         ,@body
         (values (/ (- (get-internal-real-time) ,t0)
                    internal-time-units-per-second)
                 (- (sb-ext:get-bytes-consed) ,b0))))))

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; Implementations (from run-idiomatic-bench.lisp)
;;;; ─────────────────────────────────────────────────────────────────────────

(defun cl-bfs-lazy (n)
  (let ((graph (make-array n))
        (dists (make-hash-table :size n :test #'eql)))
    (dotimes (i (1- n)) (setf (svref graph i) (list (1+ i))))
    (setf (svref graph (1- n)) nil)
    (setf (gethash 0 dists) 0)
    (let ((q (list 0)))
      (loop while q do
        (let* ((u (pop q))
               (d (gethash u dists)))
          (dolist (v (svref graph u))
            (unless (gethash v dists)
              (setf (gethash v dists) (1+ d))
              (nconc q (list v))))))
      dists)))

(defun fol-make-graph-lazy (n)
  (let ((g (fol.compiler.collection-functions:dict)))
    (dotimes (i (1- n))
      (setf g (fol.compiler.collection-functions:assoc
               g i (fol.compiler.collection-functions:vector (1+ i)))))
    (setf g (fol.compiler.collection-functions:assoc
             g (1- n) (fol.compiler.collection-functions:vector)))
    g))

(defun fol-bfs-lazy (graph)
  (let ((dists (fol.compiler.collection-functions:assoc
                (fol.compiler.collection-functions:dict) 0 0))
        (q (list 0)))
    (loop while q do
      (let* ((u (pop q))
             (d (fol.compiler.collection-functions:get dists u))
             (edges (fol.compiler.collection-functions:get graph u)))
        (dolist (v (fol.compiler.collections:collection-seq edges))
          (unless (fol.compiler.collection-functions:get dists v nil)
            (setf dists (fol.compiler.collection-functions:assoc dists v (1+ d)))
            (nconc q (list v))))))
    dists))

;;;; ═══════════════════════════════════════════════════════════════════════════
;;;; 1. SCALING ANALYSIS
;;;; ═══════════════════════════════════════════════════════════════════════════

(defun run-scaling-analysis ()
  (format t "~%=== Scaling Analysis: ns/node vs. N ===~%")
  (format t "~%  ~8A  ~12A  ~12A  ~10A  ~10A  ~8A~%"
          "N" "CL (ms)" "FOL (ms)" "CL ns/node" "FOL ns/node" "FOL/CL")
  (format t "  ~A~%" (make-string 72 :initial-element #\-))
  (dolist (n '(5000 10000 25000 50000 100000 200000 400000))
    (let ((fol-graph (fol-make-graph-lazy n)))
      ;; warm up
      (cl-bfs-lazy n)
      (fol-bfs-lazy fol-graph)
      ;; measure (3 runs each, take mean)
      (let ((cl-total 0.0d0) (fol-total 0.0d0))
        (dotimes (_ 3)
          (multiple-value-bind (s ignore) (timed-run (cl-bfs-lazy n))
            (declare (ignore ignore))
            (incf cl-total s))
          (multiple-value-bind (s ignore) (timed-run (fol-bfs-lazy fol-graph))
            (declare (ignore ignore))
            (incf fol-total s)))
        (let* ((cl-s  (/ cl-total 3.0d0))
               (fol-s (/ fol-total 3.0d0))
               (cl-ns  (* cl-s 1d9 (/ 1.0d0 n)))
               (fol-ns (* fol-s 1d9 (/ 1.0d0 n)))
               (ratio  (/ fol-s cl-s)))
          (format t "  ~8:D  ~12,3F  ~12,3F  ~10,2F  ~10,2F  ~8,3F~%"
                  n (* cl-s 1000) (* fol-s 1000) cl-ns fol-ns ratio))))))

;;;; ═══════════════════════════════════════════════════════════════════════════
;;;; 2. STATISTICAL PROFILING (sb-sprof)
;;;; ═══════════════════════════════════════════════════════════════════════════

(defun run-profiling (n)
  (format t "~%=== Statistical CPU Profiling at N=~:D ===~%" n)

  ;; -- CL profile --
  (format t "~%--- CL (hash-table) ---~%")
  (let ((fol-graph (fol-make-graph-lazy n)))
    (sb-ext:gc :full t)
    (sb-sprof:with-profiling (:mode :cpu :sample-interval 0.001
                              :report :flat :loop nil
                              :reset t)
      (dotimes (_ 20) (cl-bfs-lazy n)))

    ;; -- FOL profile --
    (format t "~%--- FOL (persistent HAMT) ---~%")
    (sb-ext:gc :full t)
    (sb-sprof:with-profiling (:mode :cpu :sample-interval 0.001
                              :report :flat :loop nil
                              :reset t)
      (dotimes (_ 20) (fol-bfs-lazy fol-graph))))

  ;; -- Allocation profile (CL) --
  (format t "~%--- Allocation profile: CL (hash-table) ---~%")
  (sb-ext:gc :full t)
  (sb-sprof:with-profiling (:mode :alloc :alloc-interval 1
                            :report :flat :loop nil
                            :reset t)
    (dotimes (_ 5) (cl-bfs-lazy n)))

  ;; -- Allocation profile (FOL) --
  (let ((fol-graph (fol-make-graph-lazy n)))
    (format t "~%--- Allocation profile: FOL (persistent HAMT) ---~%")
    (sb-ext:gc :full t)
    (sb-sprof:with-profiling (:mode :alloc :alloc-interval 1
                              :report :flat :loop nil
                              :reset t)
      (dotimes (_ 5) (fol-bfs-lazy fol-graph)))))

;;;; ═══════════════════════════════════════════════════════════════════════════
;;;; Main
;;;; ═══════════════════════════════════════════════════════════════════════════

(format t "~%BFS Lazy-Init: Cache-Pressure Analysis~%")
(format t "~60,,,'-<~>~%")
(format t "Environment: ~A ~A~%" (lisp-implementation-type) (lisp-implementation-version))

(run-scaling-analysis)
(run-profiling 50000)

(format t "~%Done.~%")
(sb-ext:exit)
