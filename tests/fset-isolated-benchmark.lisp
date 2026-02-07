;;; =============================================================================
;;; Isolated FSet Benchmarks - Direct CL comparison without interpreter overhead
;;; Purpose: Separate persistence overhead from FOL interpreter overhead
;;; =============================================================================

(in-package :cl-user)

;;; ============================================================
;;; Setup
;;; ============================================================

(defun ensure-gc ()
  "Force garbage collection for accurate memory measurements."
  #+sbcl (sb-ext:gc :full t)
  #-sbcl nil)

;;; ============================================================
;;; 1. Map Operation Benchmarks
;;; ============================================================

(defun benchmark-cl-map (n num-runs)
  "Benchmark CL's map over a simple-vector of N elements.
   Operation: i + sqrt(i) + log(i+1)"
  (let ((arr (coerce (loop for i from 1 to n collect i) 'simple-vector))
        (times nil))
    (dotimes (run num-runs)
      (let ((start (get-internal-real-time)))
        (map 'simple-vector
             (lambda (i) (+ i (sqrt i) (log (1+ i))))
             arr)
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

(defun benchmark-fset-map (n num-runs)
  "Benchmark FSet's image over a seq of N elements.
   Operation: i + sqrt(i) + log(i+1)"
  (let ((seq (fset:convert 'fset:seq (loop for i from 1 to n collect i)))
        (times nil))
    (dotimes (run num-runs)
      (let ((start (get-internal-real-time)))
        (fset:image (lambda (i) (+ i (sqrt i) (log (1+ i)))) seq)
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

;;; ============================================================
;;; 2. Update/Modification Benchmarks
;;; ============================================================

(defun benchmark-cl-vector-updates (n num-updates num-runs)
  "Benchmark N random updates on a mutable CL vector."
  (let ((times nil))
    (dotimes (run num-runs)
      (let ((arr (make-array n :initial-element 0))
            (start (get-internal-real-time)))
        (dotimes (i num-updates)
          (setf (aref arr (random n)) i))
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

(defun benchmark-fset-seq-updates (n num-updates num-runs)
  "Benchmark N persistent updates on an FSet seq."
  (let ((times nil))
    (dotimes (run num-runs)
      (let ((seq (fset:convert 'fset:seq (make-list n :initial-element 0)))
            (start (get-internal-real-time)))
        (dotimes (i num-updates)
          (setf seq (fset:with seq (random n) i)))
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

;;; ============================================================
;;; 3. Dict/Map Benchmarks
;;; ============================================================

(defun benchmark-cl-hash-lookup (n num-lookups num-runs)
  "Benchmark hash-table lookups."
  (let ((ht (make-hash-table :size n))
        (times nil))
    (dotimes (i n)
      (setf (gethash i ht) i))
    (dotimes (run num-runs)
      (let ((start (get-internal-real-time)))
        (dotimes (i num-lookups)
          (gethash (random n) ht))
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

(defun benchmark-fset-map-lookup (n num-lookups num-runs)
  "Benchmark FSet map lookups."
  (let ((m (fset:empty-map))
        (times nil))
    (dotimes (i n)
      (setf m (fset:with m i i)))
    (dotimes (run num-runs)
      (let ((start (get-internal-real-time)))
        (dotimes (i num-lookups)
          (fset:@ m (random n)))
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

(defun benchmark-cl-hash-insert (n num-runs)
  "Benchmark N hash-table insertions."
  (let ((times nil))
    (dotimes (run num-runs)
      (let ((ht (make-hash-table :size n))
            (start (get-internal-real-time)))
        (dotimes (i n)
          (setf (gethash i ht) i))
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

(defun benchmark-fset-map-insert (n num-runs)
  "Benchmark N FSet map insertions (persistent)."
  (let ((times nil))
    (dotimes (run num-runs)
      (let ((m (fset:empty-map))
            (start (get-internal-real-time)))
        (dotimes (i n)
          (setf m (fset:with m i i)))
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

;;; ============================================================
;;; 4. Reduce/Fold Benchmarks
;;; ============================================================

(defun benchmark-cl-reduce (n num-runs)
  "Benchmark CL reduce over a vector."
  (let ((arr (coerce (loop for i from 1 to n collect i) 'simple-vector))
        (times nil))
    (dotimes (run num-runs)
      (let ((start (get-internal-real-time)))
        (reduce #'+ arr)
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

(defun benchmark-fset-reduce (n num-runs)
  "Benchmark FSet reduce over a seq."
  (let ((seq (fset:convert 'fset:seq (loop for i from 1 to n collect i)))
        (times nil))
    (dotimes (run num-runs)
      (let ((start (get-internal-real-time)))
        (fset:reduce #'+ seq)
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

;;; ============================================================
;;; Run All Benchmarks
;;; ============================================================

(defun run-isolated-fset-benchmarks ()
  "Run isolated FSet benchmarks to separate persistence from interpreter overhead."
  (format t "~%================================================================~%")
  (format t "Isolated FSet Benchmarks - Direct CL vs FSet (No Interpreter)~%")
  (format t "================================================================~%")

  (let ((sizes '(1000 10000 100000))
        (num-runs 5))

    (format t "~%Warming up...~%")
    (ensure-gc)
    (benchmark-cl-map 100 1)
    (benchmark-fset-map 100 1)

    ;; Map benchmarks
    (format t "~%--- MAP OPERATION (i + sqrt(i) + log(i+1)) ---~%")
    (format t "~10A ~15A ~15A ~10A~%" "N" "CL map (s)" "FSet map (s)" "Ratio")
    (format t "~10A ~15A ~15A ~10A~%" "---" "----------" "-----------" "-----")
    (dolist (n sizes)
      (ensure-gc)
      (let* ((cl-time (benchmark-cl-map n num-runs))
             (fset-time (benchmark-fset-map n num-runs))
             (ratio (if (> cl-time 0) (/ fset-time cl-time) 0)))
        (format t "~10D ~15,6F ~15,6F ~10,2Fx~%" n cl-time fset-time ratio)))

    ;; Update benchmarks
    (format t "~%--- RANDOM UPDATES (1000 updates) ---~%")
    (format t "~10A ~15A ~15A ~10A~%" "N" "CL vec (s)" "FSet seq (s)" "Ratio")
    (format t "~10A ~15A ~15A ~10A~%" "---" "----------" "-----------" "-----")
    (dolist (n sizes)
      (ensure-gc)
      (let* ((cl-time (benchmark-cl-vector-updates n 1000 num-runs))
             (fset-time (benchmark-fset-seq-updates n 1000 num-runs))
             (ratio (if (> cl-time 0) (/ fset-time cl-time) 0)))
        (format t "~10D ~15,6F ~15,6F ~10,2Fx~%" n cl-time fset-time ratio)))

    ;; Lookup benchmarks
    (format t "~%--- MAP LOOKUP (10000 lookups) ---~%")
    (format t "~10A ~15A ~15A ~10A~%" "N" "CL hash (s)" "FSet map (s)" "Ratio")
    (format t "~10A ~15A ~15A ~10A~%" "---" "-----------" "-----------" "-----")
    (dolist (n sizes)
      (ensure-gc)
      (let* ((cl-time (benchmark-cl-hash-lookup n 10000 num-runs))
             (fset-time (benchmark-fset-map-lookup n 10000 num-runs))
             (ratio (if (> cl-time 0) (/ fset-time cl-time) 0)))
        (format t "~10D ~15,6F ~15,6F ~10,2Fx~%" n cl-time fset-time ratio)))

    ;; Insert benchmarks
    (format t "~%--- MAP INSERT (N insertions) ---~%")
    (format t "~10A ~15A ~15A ~10A~%" "N" "CL hash (s)" "FSet map (s)" "Ratio")
    (format t "~10A ~15A ~15A ~10A~%" "---" "-----------" "-----------" "-----")
    (dolist (n sizes)
      (ensure-gc)
      (let* ((cl-time (benchmark-cl-hash-insert n num-runs))
             (fset-time (benchmark-fset-map-insert n num-runs))
             (ratio (if (> cl-time 0) (/ fset-time cl-time) 0)))
        (format t "~10D ~15,6F ~15,6F ~10,2Fx~%" n cl-time fset-time ratio)))

    ;; Reduce benchmarks
    (format t "~%--- REDUCE (+) ---~%")
    (format t "~10A ~15A ~15A ~10A~%" "N" "CL reduce (s)" "FSet reduce (s)" "Ratio")
    (format t "~10A ~15A ~15A ~10A~%" "---" "-------------" "---------------" "-----")
    (dolist (n sizes)
      (ensure-gc)
      (let* ((cl-time (benchmark-cl-reduce n num-runs))
             (fset-time (benchmark-fset-reduce n num-runs))
             (ratio (if (> cl-time 0) (/ fset-time cl-time) 0)))
        (format t "~10D ~15,6F ~15,6F ~10,2Fx~%" n cl-time fset-time ratio))))

  (format t "~%================================================================~%")
  (format t "Summary: These ratios reflect PURE persistence overhead~%")
  (format t "         (no FOL interpreter overhead included)~%")
  (format t "================================================================~%"))

;;; Run if loaded directly
;; (run-isolated-fset-benchmarks)
