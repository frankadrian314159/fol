(let ((ql-path (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file ql-path)
      (load ql-path)
      (error "Quicklisp not found at ~A" ql-path)))

(handler-bind ((warning #'muffle-warning) (style-warning #'muffle-warning))
  (handler-case
      (ql:quickload :fset :silent t)
    (error (e) (sb-ext:exit :code 1))))

;; ---------- QUICKSORT ----------

(defun cl-qsort (arr low high)
  (declare (type (simple-array fixnum (*)) arr)
           (type fixnum low high))
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

(defun run-cl-qsort (n)
  (let ((arr (make-array n :element-type 'fixnum)))
    (loop for i from 0 below n do (setf (aref arr i) (random 100000)))
    (time (cl-qsort arr 0 (1- n)))))

(defun fset-partition (v low high)
  (let ((pivot (fset:lookup v high))
        (j low)
        (i (1- low))
        (curr-v v))
    (loop while (< j high) do
            (if (<= (fset:lookup curr-v j) pivot)
                (let* ((next-i (1+ i))
                       (temp (fset:lookup curr-v next-i))
                       (v1 (fset:with curr-v next-i (fset:lookup curr-v j)))
                       (v2 (fset:with v1 j temp)))
                  (setf j (1+ j)
                    i next-i
                    curr-v v2))
                (setf j (1+ j))))
    (let* ((next-i (1+ i))
           (temp (fset:lookup curr-v next-i))
           (v1 (fset:with curr-v next-i (fset:lookup curr-v high)))
           (v2 (fset:with v1 high temp)))
      (values v2 next-i))))

(defun fset-qsort (v low high)
  (if (< low high)
      (multiple-value-bind (v-part p) (fset-partition v low high)
        (let ((v-left (fset-qsort v-part low (1- p))))
          (fset-qsort v-left (1+ p) high)))
      v))

(defun run-fset-qsort (n)
  (let ((arr (fset:empty-seq)))
    (loop for i from 0 below n do (setf arr (fset:with-last arr (random 100000))))
    (time (fset-qsort arr 0 (1- n)))))

;; ---------- GRAPH TRAVERSAL ----------

(defun build-cl-graph (nodes degree)
  (let ((graph (make-array nodes)))
    (loop for i from 0 below nodes do
            (let ((edges (make-array degree :element-type 'fixnum)))
              (loop for j from 0 below degree do
                      (setf (aref edges j) (random nodes)))
              (setf (aref graph i) edges)))
    graph))

(defun cl-bfs (graph start)
  (let* ((n (length graph))
         (dists (make-array n :element-type 'fixnum :initial-element -1))
         (q (make-array n :element-type 'fixnum))
         (head 0)
         (tail 0))
    (setf (aref dists start) 0)
    (setf (aref q tail) start)
    (incf tail)
    (loop while (< head tail) do
            (let ((u (aref q head)))
              (incf head)
              (let ((edges (aref graph u)))
                (loop for i from 0 below (length edges) do
                        (let ((v (aref edges i)))
                          (when (= (aref dists v) -1)
                                (setf (aref dists v) (1+ (aref dists u)))
                                (setf (aref q tail) v)
                                (incf tail)))))))
    dists))

(defun run-cl-bfs (nodes degree)
  (let ((graph (build-cl-graph nodes degree)))
    (time (cl-bfs graph 0))))

(defun fset-bfs (graph start n)
  (let* ((init-dists (fset:convert 'fset:seq (make-list n :initial-element -1)))
         (init-dists (fset:with init-dists start 0))
         (q (list start)))
    (labels ((bfs-step (q dists)
                       (if (null q)
                           dists
                           (let* ((u (car q))
                                  (edges (aref graph u))
                                  (new-q (cdr q))
                                  (new-dists dists)
                                  (curr-dist (fset:lookup dists u)))
                             (loop for i from 0 below (length edges) do
                                     (let ((v (aref edges i)))
                                       (when (= (fset:lookup new-dists v) -1)
                                             (setf new-dists (fset:with new-dists v (1+ curr-dist)))
                                             (setf new-q (append new-q (list v))))))
                             (bfs-step new-q new-dists)))))
      (bfs-step q init-dists))))

(defun run-fset-bfs (nodes degree)
  (let ((graph (build-cl-graph nodes degree)))
    (time (fset-bfs graph 0 nodes))))

(format t "~%--- QSort 100k ---~%")
(format t "CL:~%")
(run-cl-qsort 100000)
(format t "FOL:~%")
(run-fset-qsort 100000)

(format t "~%--- BFS 50k Nodes, Degree 10 ---~%")
(format t "CL:~%")
(run-cl-bfs 50000 10)
(format t "FOL:~%")
(run-fset-bfs 50000 10)

(format t "~%--- BFS 25k Nodes, Degree 10 ---~%")
(format t "CL:~%")
(run-cl-bfs 25000 10)
(format t "FOL:~%")
(run-fset-bfs 25000 10)


(sb-ext:exit :code 0)
