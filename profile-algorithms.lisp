#!/usr/bin/env sbcl --script
;;; Comprehensive profiling of BFS and Quicksort algorithms
;;; Run: sbcl --noinform --script profile-algorithms.lisp

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

(format t "~%Loading FOL system...~%")
(asdf:load-system :fol-compiler)
(require :sb-sprof)

;; Get access to compile function
(use-package :fol.compiler)

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
;;;; CL Implementations
;;;; ─────────────────────────────────────────────────────────────────────────

(defun cl-bfs-lazy (n)
  "CL BFS with lazy distance initialization"
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
              (nconc q (list v)))))))
    dists))

(defun cl-qsort (arr low high)
  "CL quicksort with mutable array"
  (when (< low high)
    (let ((pivot (aref arr high))
          (i (1- low)))
      (loop for j from low below high do
        (when (<= (aref arr j) pivot)
          (incf i)
          (rotatef (aref arr i) (aref arr j))))
      (incf i)
      (rotatef (aref arr i) (aref arr high))
      (cl-qsort arr low (1- i))
      (cl-qsort arr (1+ i) high)))
  arr)

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; FOL Implementations (compiled from FOL source)
;;;; ─────────────────────────────────────────────────────────────────────────

(format t "~%Compiling FOL implementations...~%")

;; Compile FOL functions individually using compile-form
(defun fol-compile-and-eval (fol-code-string)
  "Compile FOL code string to CL and evaluate it"
  (let* ((form (fol.compiler.reader:fol-read-from-string fol-code-string))
         (compiled (fol.compiler:compile-form form))
         (errors (fol.compiler:compilation-result-errors compiled)))
    (when errors
      (error "Compilation error: ~{~A~^~%~}" errors))
    (eval (fol.compiler:compilation-result-code compiled))))

;; Define BFS functions
(fol-compile-and-eval "
(defn make-graph [n]
  (bind [g (dict)]
    (loop [i 0, g-acc g]
      (if (< i (- n 1))
        (recur (+ i 1) (assoc g-acc i [(+ i 1)]))
        (assoc g-acc (- n 1) [])))))
")

(fol-compile-and-eval "
(defn fol-bfs-lazy [graph]
  (bind [dists (assoc (dict) 0 0)]
    (loop [q (list 0), dists-acc dists]
      (if (empty? q)
        dists-acc
        (bind [u (first q)
               d (get dists-acc u)
               edges (get graph u)
               [q-new dists-new]
                 (loop [edges-i 0, q-acc (rest q), d-acc dists-acc]
                   (if (< edges-i (count edges))
                     (bind [v (get edges edges-i)]
                       (if (nil? (get d-acc v nil))
                         (recur (+ edges-i 1)
                                (conj q-acc v)
                                (assoc d-acc v (+ d 1)))
                         (recur (+ edges-i 1) q-acc d-acc)))
                     [q-acc d-acc]))]
          (recur q-new dists-new))))))
")

;; Define Quicksort functions
(fol-compile-and-eval "
(defn partition [v low high]
  (bind [pivot (get v high)]
    (loop [j low, i (- low 1), curr-v v]
      (if (< j high)
        (if (<= (get curr-v j) pivot)
          (bind [next-i (+ i 1)
                 temp (get curr-v next-i)
                 v1 (assoc curr-v next-i (get curr-v j))
                 v2 (assoc v1 j temp)]
            (recur (+ j 1) next-i v2))
          (recur (+ j 1) i curr-v))
        (bind [next-i (+ i 1)
               temp (get curr-v next-i)
               v1 (assoc curr-v next-i (get curr-v high))
               v2 (assoc v1 high temp)]
          [v2 next-i])))))
")

(fol-compile-and-eval "
(defn qsort [v low high]
  (if (< low high)
    (bind [[v-part p] (partition v low high)
           v-left (qsort v-part low (- p 1))]
      (qsort v-left (+ p 1) high))
    v))
")

(format t "~%Compiled FOL implementations.~%~%")

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; BFS Profiling
;;;; ─────────────────────────────────────────────────────────────────────────

(format t "~%====================================================================~%")
(format t "                    BFS PROFILING (N=50,000)~%")
(format t "====================================================================~%")

(let ((n 50000))
  ;; Warmup
  (format t "~%Warming up...~%")
  (cl-bfs-lazy n)
  (let ((fol-graph (fol-user::make-graph n)))
    (fol-user::fol-bfs-lazy fol-graph))

  ;; Timing comparison
  (format t "~%--- Timing (3 runs, mean) ---~%")
  (let ((cl-total 0.0) (fol-total 0.0))
    (dotimes (i 3)
      (format t "Run ~D: " (1+ i))
      (multiple-value-bind (cl-s cl-bytes) (timed-run (cl-bfs-lazy n))
        (format t "CL ~,3F s (~,1F MB) | " cl-s (/ cl-bytes 1e6))
        (incf cl-total cl-s)
        (let ((fol-graph (fol-user::make-graph n)))
          (multiple-value-bind (fol-s fol-bytes)
              (timed-run (fol-user::fol-bfs-lazy fol-graph))
            (format t "FOL ~,3F s (~,1F MB)~%" fol-s (/ fol-bytes 1e6))
            (incf fol-total fol-s)))))
    (let ((cl-mean (/ cl-total 3.0))
          (fol-mean (/ fol-total 3.0)))
      (format t "~%Mean: CL ~,3F s | FOL ~,3F s | Ratio ~,2Fx~%"
              cl-mean fol-mean (/ fol-mean cl-mean))))

  ;; CPU Profiling
  (format t "~%--- CPU Profile: CL (hash-table, 10 runs) ---~%")
  (sb-ext:gc :full t)
  (sb-sprof:with-profiling (:mode :cpu :sample-interval 0.001
                            :report :flat :loop nil :reset t)
    (dotimes (i 10) (cl-bfs-lazy n)))

  (format t "~%--- CPU Profile: FOL (persistent dict, 10 runs) ---~%")
  (let ((fol-graph (fol-user::make-graph n)))
    (sb-ext:gc :full t)
    (sb-sprof:with-profiling (:mode :cpu :sample-interval 0.001
                              :report :flat :loop nil :reset t)
      (dotimes (i 10) (fol-user::fol-bfs-lazy fol-graph))))

  ;; Allocation Profiling
  (format t "~%--- Allocation Profile: CL (hash-table, 5 runs) ---~%")
  (sb-ext:gc :full t)
  (sb-sprof:with-profiling (:mode :alloc :alloc-interval 1
                            :report :flat :loop nil :reset t)
    (dotimes (i 5) (cl-bfs-lazy n)))

  (format t "~%--- Allocation Profile: FOL (persistent dict, 5 runs) ---~%")
  (let ((fol-graph (fol-user::make-graph n)))
    (sb-ext:gc :full t)
    (sb-sprof:with-profiling (:mode :alloc :alloc-interval 1
                              :report :flat :loop nil :reset t)
      (dotimes (i 5) (fol-user::fol-bfs-lazy fol-graph)))))

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; Quicksort Profiling
;;;; ─────────────────────────────────────────────────────────────────────────

(format t "~%====================================================================~%")
(format t "                  QUICKSORT PROFILING (N=10,000)~%")
(format t "====================================================================~%")

(let ((n 10000))
  ;; Prepare test data (same for both)
  (let ((test-data (make-array n)))
    (dotimes (i n) (setf (aref test-data i) (random 100000)))

    ;; Create FOL vector using conj
    (let ((fol-vec (loop with v = (funcall (find-symbol "VECTOR"))
                         for i below n
                         do (setf v (funcall (find-symbol "CONJ") v (random 100000)))
                         finally (return v))))

      ;; Warmup
      (format t "~%Warming up...~%")
      (let ((arr-copy (copy-seq test-data)))
        (cl-qsort arr-copy 0 (1- n)))
      (funcall (find-symbol "QSORT") fol-vec 0 (1- n))

      ;; Timing comparison
      (format t "~%--- Timing (3 runs, mean) ---~%")
      (let ((cl-total 0.0) (fol-total 0.0))
        (dotimes (i 3)
          (format t "Run ~D: " (1+ i))
          (multiple-value-bind (cl-s cl-bytes)
              (timed-run
               (let ((arr-copy (copy-seq test-data)))
                 (cl-qsort arr-copy 0 (1- n))))
            (format t "CL ~,3F s (~,1F MB) | " cl-s (/ cl-bytes 1e6))
            (incf cl-total cl-s)
            (multiple-value-bind (fol-s fol-bytes)
                (timed-run (fol-user::qsort fol-vec 0 (1- n)))
              (format t "FOL ~,3F s (~,1F MB)~%" fol-s (/ fol-bytes 1e6))
              (incf fol-total fol-s))))
        (let ((cl-mean (/ cl-total 3.0))
              (fol-mean (/ fol-total 3.0)))
          (format t "~%Mean: CL ~,3F s | FOL ~,3F s | Ratio ~,2Fx~%"
                  cl-mean fol-mean (/ fol-mean cl-mean))))

      ;; CPU Profiling
      (format t "~%--- CPU Profile: CL (mutable array, 10 runs) ---~%")
      (sb-ext:gc :full t)
      (sb-sprof:with-profiling (:mode :cpu :sample-interval 0.001
                                :report :flat :loop nil :reset t)
        (dotimes (i 10)
          (let ((arr-copy (copy-seq test-data)))
            (cl-qsort arr-copy 0 (1- n)))))

      (format t "~%--- CPU Profile: FOL (persistent vector, 10 runs) ---~%")
      (sb-ext:gc :full t)
      (sb-sprof:with-profiling (:mode :cpu :sample-interval 0.001
                                :report :flat :loop nil :reset t)
        (dotimes (i 10)
          (fol-user::qsort fol-vec 0 (1- n))))

      ;; Allocation Profiling
      (format t "~%--- Allocation Profile: CL (mutable array, 5 runs) ---~%")
      (sb-ext:gc :full t)
      (sb-sprof:with-profiling (:mode :alloc :alloc-interval 1
                                :report :flat :loop nil :reset t)
        (dotimes (i 5)
          (let ((arr-copy (copy-seq test-data)))
            (cl-qsort arr-copy 0 (1- n)))))

      (format t "~%--- Allocation Profile: FOL (persistent vector, 5 runs) ---~%")
      (sb-ext:gc :full t)
      (sb-sprof:with-profiling (:mode :alloc :alloc-interval 1
                                :report :flat :loop nil :reset t)
        (dotimes (i 5)
          (fol-user::qsort fol-vec 0 (1- n)))))))

(format t "~%====================================================================~%")
(format t "Profiling complete.~%")
(sb-ext:exit)
