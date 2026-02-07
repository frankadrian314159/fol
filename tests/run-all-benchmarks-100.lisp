;;; Run all benchmarks with 100 repetitions for paper data
(in-package :cl-user)

(defun ensure-gc ()
  "Force garbage collection for accurate measurements."
  #+sbcl (sb-ext:gc :full t)
  #-sbcl nil)

;;; ============================================================
;;; 1. Isolated FSet Benchmarks (from fset-isolated-benchmark.lisp)
;;; ============================================================

(defun benchmark-cl-map-100 (n)
  "Benchmark CL's map over a simple-vector of N elements, 100 runs."
  (let ((arr (coerce (loop for i from 1 to n collect i) 'simple-vector))
        (times nil))
    (dotimes (run 100)
      (let ((start (get-internal-real-time)))
        (map 'simple-vector
             (lambda (i) (+ i (sqrt i) (log (1+ i))))
             arr)
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

(defun benchmark-fset-map-100 (n)
  "Benchmark FSet's image over a seq of N elements, 100 runs."
  (let ((seq (fset:convert 'fset:seq (loop for i from 1 to n collect i)))
        (times nil))
    (dotimes (run 100)
      (let ((start (get-internal-real-time)))
        (fset:image (lambda (i) (+ i (sqrt i) (log (1+ i)))) seq)
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

(defun benchmark-cl-vector-updates-100 (n num-updates)
  "Benchmark random updates on mutable CL vector, 100 runs."
  (let ((times nil))
    (dotimes (run 100)
      (let ((arr (make-array n :initial-element 0))
            (start (get-internal-real-time)))
        (dotimes (i num-updates)
          (setf (aref arr (random n)) i))
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

(defun benchmark-fset-seq-updates-100 (n num-updates)
  "Benchmark persistent updates on FSet seq, 100 runs."
  (let ((times nil))
    (dotimes (run 100)
      (let ((seq (fset:convert 'fset:seq (make-list n :initial-element 0)))
            (start (get-internal-real-time)))
        (dotimes (i num-updates)
          (setf seq (fset:with seq (random n) i)))
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

(defun benchmark-cl-hash-lookup-100 (n num-lookups)
  "Benchmark hash-table lookups, 100 runs."
  (let ((ht (make-hash-table :size n))
        (times nil))
    (dotimes (i n)
      (setf (gethash i ht) i))
    (dotimes (run 100)
      (let ((start (get-internal-real-time)))
        (dotimes (i num-lookups)
          (gethash (random n) ht))
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

(defun benchmark-fset-map-lookup-100 (n num-lookups)
  "Benchmark FSet map lookups, 100 runs."
  (let ((m (fset:empty-map))
        (times nil))
    (dotimes (i n)
      (setf m (fset:with m i i)))
    (dotimes (run 100)
      (let ((start (get-internal-real-time)))
        (dotimes (i num-lookups)
          (fset:@ m (random n)))
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

(defun benchmark-cl-hash-insert-100 (n)
  "Benchmark N hash-table insertions, 100 runs."
  (let ((times nil))
    (dotimes (run 100)
      (let ((ht (make-hash-table :size n))
            (start (get-internal-real-time)))
        (dotimes (i n)
          (setf (gethash i ht) i))
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

(defun benchmark-fset-map-insert-100 (n)
  "Benchmark N FSet map insertions, 100 runs."
  (let ((times nil))
    (dotimes (run 100)
      (let ((m (fset:empty-map))
            (start (get-internal-real-time)))
        (dotimes (i n)
          (setf m (fset:with m i i)))
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

(defun benchmark-cl-reduce-100 (n)
  "Benchmark CL reduce over a vector, 100 runs."
  (let ((arr (coerce (loop for i from 1 to n collect i) 'simple-vector))
        (times nil))
    (dotimes (run 100)
      (let ((start (get-internal-real-time)))
        (reduce #'+ arr)
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

(defun benchmark-fset-reduce-100 (n)
  "Benchmark FSet reduce over a seq, 100 runs."
  (let ((seq (fset:convert 'fset:seq (loop for i from 1 to n collect i)))
        (times nil))
    (dotimes (run 100)
      (let ((start (get-internal-real-time)))
        (fset:reduce #'+ seq)
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

;;; ============================================================
;;; 2. Concurrent Benchmarks (from concurrent-benchmark.lisp)
;;; ============================================================

(defparameter *num-threads* 16)
(defparameter *iterations* 10000)
(defparameter *vec-size* 100)

(defstruct atomic-ref
  (value nil)
  (lock (bt:make-lock "atomic-lock")))

(defun atomic-swap! (ref update-fn)
  (bt:with-lock-held ((atomic-ref-lock ref))
    (setf (atomic-ref-value ref)
          (funcall update-fn (atomic-ref-value ref)))))

(defun benchmark-cl-locked ()
  (let ((vec (make-array *vec-size* :initial-element 0))
        (lock (bt:make-lock "vec-lock"))
        (threads nil))
    (let ((start-time (get-internal-real-time)))
      (dotimes (thread-id *num-threads*)
        (push (bt:make-thread
               (lambda ()
                 (dotimes (i *iterations*)
                   (bt:with-lock-held (lock)
                     (setf (aref vec (mod i *vec-size*)) i))))
               :name (format nil "cl-thread-~D" thread-id))
              threads))
      (dolist (thread threads)
        (bt:join-thread thread))
      (/ (- (get-internal-real-time) start-time)
         (float internal-time-units-per-second)))))

(defun benchmark-fset-atomic ()
  (let ((atom (make-atomic-ref
               :value (fset:convert 'fset:seq
                        (loop for i below *vec-size* collect 0))))
        (threads nil))
    (let ((start-time (get-internal-real-time)))
      (dotimes (thread-id *num-threads*)
        (push (bt:make-thread
               (lambda ()
                 (dotimes (i *iterations*)
                   (atomic-swap! atom
                     (lambda (v)
                       (fset:with v (mod i *vec-size*) i)))))
               :name (format nil "fset-thread-~D" thread-id))
              threads))
      (dolist (thread threads)
        (bt:join-thread thread))
      (/ (- (get-internal-real-time) start-time)
         (float internal-time-units-per-second)))))

(defun benchmark-fset-lockfree ()
  (let ((threads nil)
        (results (make-array *num-threads*)))
    (let ((start-time (get-internal-real-time)))
      (dotimes (thread-id *num-threads*)
        (let ((tid thread-id))
          (push (bt:make-thread
                 (lambda ()
                   (let ((v (fset:convert 'fset:seq
                              (loop for i below *vec-size* collect 0))))
                     (dotimes (i *iterations*)
                       (setf v (fset:with v (mod i *vec-size*) i)))
                     (setf (aref results tid) v)))
                 :name (format nil "fset-free-~D" thread-id))
                threads)))
      (dolist (thread threads)
        (bt:join-thread thread))
      (/ (- (get-internal-real-time) start-time)
         (float internal-time-units-per-second)))))

(defun run-concurrent-100 ()
  "Run concurrent benchmarks 100 times each."
  (format t "~%Running concurrent benchmarks (100 runs each)...~%")
  (let ((cl-times nil)
        (fset-atomic-times nil)
        (fset-free-times nil))
    (dotimes (run 100)
      (when (zerop (mod run 10))
        (format t "  Run ~D/100...~%" run))
      (push (benchmark-cl-locked) cl-times)
      (push (benchmark-fset-atomic) fset-atomic-times)
      (push (benchmark-fset-lockfree) fset-free-times))
    (values (/ (reduce #'+ cl-times) (length cl-times))
            (/ (reduce #'+ fset-atomic-times) (length fset-atomic-times))
            (/ (reduce #'+ fset-free-times) (length fset-free-times)))))

;;; ============================================================
;;; Main runner
;;; ============================================================

(defun run-all-benchmarks-100 ()
  (format t "~%================================================================~%")
  (format t "All Benchmarks - 100 Repetitions Each~%")
  (format t "================================================================~%")

  ;; Warmup
  (format t "~%Warming up...~%")
  (ensure-gc)
  (benchmark-cl-map-100 100)
  (benchmark-fset-map-100 100)

  ;; Isolated FSet benchmarks
  (format t "~%================================================================~%")
  (format t "ISOLATED FSET BENCHMARKS~%")
  (format t "================================================================~%")

  (format t "~%--- MAP OPERATION (i + sqrt(i) + log(i+1)) ---~%")
  (format t "~10A ~15A ~15A ~10A~%" "N" "CL map (s)" "FSet map (s)" "Ratio")
  (dolist (n '(10000 100000))
    (ensure-gc)
    (let* ((cl-time (benchmark-cl-map-100 n))
           (fset-time (benchmark-fset-map-100 n))
           (ratio (if (> cl-time 0) (/ fset-time cl-time) 0)))
      (format t "~10D ~15,6F ~15,6F ~10,2Fx~%" n cl-time fset-time ratio)))

  (format t "~%--- RANDOM UPDATES (1000 updates) ---~%")
  (format t "~10A ~15A ~15A ~10A~%" "N" "CL vec (s)" "FSet seq (s)" "Ratio")
  (dolist (n '(10000 100000))
    (ensure-gc)
    (let* ((cl-time (benchmark-cl-vector-updates-100 n 1000))
           (fset-time (benchmark-fset-seq-updates-100 n 1000))
           (ratio (if (> cl-time 0) (/ fset-time cl-time) 0)))
      (format t "~10D ~15,6F ~15,6F ~10,2Fx~%" n cl-time fset-time ratio)))

  (format t "~%--- MAP LOOKUP (10000 lookups) ---~%")
  (format t "~10A ~15A ~15A ~10A~%" "N" "CL hash (s)" "FSet map (s)" "Ratio")
  (dolist (n '(10000 100000))
    (ensure-gc)
    (let* ((cl-time (benchmark-cl-hash-lookup-100 n 10000))
           (fset-time (benchmark-fset-map-lookup-100 n 10000))
           (ratio (if (> cl-time 0) (/ fset-time cl-time) 0)))
      (format t "~10D ~15,6F ~15,6F ~10,2Fx~%" n cl-time fset-time ratio)))

  (format t "~%--- MAP INSERT (N insertions) ---~%")
  (format t "~10A ~15A ~15A ~10A~%" "N" "CL hash (s)" "FSet map (s)" "Ratio")
  (dolist (n '(10000 100000))
    (ensure-gc)
    (let* ((cl-time (benchmark-cl-hash-insert-100 n))
           (fset-time (benchmark-fset-map-insert-100 n))
           (ratio (if (> cl-time 0) (/ fset-time cl-time) 0)))
      (format t "~10D ~15,6F ~15,6F ~10,2Fx~%" n cl-time fset-time ratio)))

  (format t "~%--- REDUCE (+) ---~%")
  (format t "~10A ~15A ~15A ~10A~%" "N" "CL reduce (s)" "FSet reduce (s)" "Ratio")
  (dolist (n '(10000 100000))
    (ensure-gc)
    (let* ((cl-time (benchmark-cl-reduce-100 n))
           (fset-time (benchmark-fset-reduce-100 n))
           (ratio (if (> cl-time 0) (/ fset-time cl-time) 0)))
      (format t "~10D ~15,6F ~15,6F ~10,2Fx~%" n cl-time fset-time ratio)))

  ;; Concurrent benchmarks
  (format t "~%================================================================~%")
  (format t "CONCURRENT BENCHMARKS (~D threads × ~D iterations)~%"
          *num-threads* *iterations*)
  (format t "================================================================~%")

  (multiple-value-bind (cl-avg fset-atomic-avg fset-free-avg)
      (run-concurrent-100)
    (format t "~%Results (average of 100 runs):~%")
    (format t "CL (locked mutable):      ~,4F seconds~%" cl-avg)
    (format t "FSet (atomic persistent): ~,4F seconds (~,2Fx vs CL)~%"
            fset-atomic-avg (/ fset-atomic-avg cl-avg))
    (format t "FSet (lock-free copies):  ~,4F seconds (~,2Fx vs CL)~%"
            fset-free-avg (/ fset-free-avg cl-avg)))

  (format t "~%================================================================~%")
  (format t "Done!~%")
  (format t "================================================================~%"))

;; Run if loaded
(run-all-benchmarks-100)
