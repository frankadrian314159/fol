;;; =============================================================================
;;; Benchmark: FSet wb-map vs Sycamore tree-map for small key counts (<30)
;;;
;;; Tests creation, lookup, and functional update at key counts 2, 4, 8, 16, 30.
;;; Each operation: 100,000 iterations, best of 5 runs.
;;; =============================================================================

(defpackage :benchmark-hashmap
  (:use :cl))

(in-package :benchmark-hashmap)

(defparameter *iterations* 100000)
(defparameter *runs* 5)
(defparameter *key-counts* '(2 4 8 16 30))

;;; ---------------------------------------------------------------------------
;;; Key generation - simulate slot names
;;; ---------------------------------------------------------------------------

(defun make-keys (n)
  "Generate N string keys simulating slot names."
  (loop for i below n
        collect (format nil "SLOT-~D" i)))

;;; ---------------------------------------------------------------------------
;;; FSet benchmarks
;;; ---------------------------------------------------------------------------

(defun fset-create (keys)
  "Build an FSet map with all keys."
  (let ((m (fset:empty-map)))
    (dolist (k keys m)
      (setf m (fset:with m k 42)))))

(defun bench-fset-create (keys)
  "Benchmark FSet map creation."
  (let ((best most-positive-fixnum))
    (dotimes (run *runs* best)
      (let ((start (get-internal-real-time)))
        (dotimes (i *iterations*)
          (fset-create keys))
        (let ((elapsed (- (get-internal-real-time) start)))
          (when (< elapsed best)
            (setf best elapsed)))))))

(defun bench-fset-lookup (keys)
  "Benchmark FSet map lookup of all keys."
  (let ((m (fset-create keys))
        (best most-positive-fixnum))
    (dotimes (run *runs* best)
      (let ((start (get-internal-real-time)))
        (dotimes (i *iterations*)
          (dolist (k keys)
            (fset:lookup m k)))
        (let ((elapsed (- (get-internal-real-time) start)))
          (when (< elapsed best)
            (setf best elapsed)))))))

(defun bench-fset-update (keys)
  "Benchmark FSet functional update of one key."
  (let ((m (fset-create keys))
        (update-key (first keys))
        (best most-positive-fixnum))
    (dotimes (run *runs* best)
      (let ((start (get-internal-real-time)))
        (dotimes (i *iterations*)
          (fset:with m update-key 99))
        (let ((elapsed (- (get-internal-real-time) start)))
          (when (< elapsed best)
            (setf best elapsed)))))))

;;; ---------------------------------------------------------------------------
;;; Sycamore benchmarks
;;; ---------------------------------------------------------------------------

(defun string-compare (a b)
  "Compare two strings, returning -1, 0, or 1."
  (cond ((string< a b) -1)
        ((string> a b) 1)
        (t 0)))

(defun sycamore-create (keys)
  "Build a Sycamore tree-map with all keys."
  (let ((m (sycamore:make-tree-map #'string-compare)))
    (dolist (k keys m)
      (setf m (sycamore:tree-map-insert m k 42)))))

(defun bench-sycamore-create (keys)
  "Benchmark Sycamore tree-map creation."
  (let ((best most-positive-fixnum))
    (dotimes (run *runs* best)
      (let ((start (get-internal-real-time)))
        (dotimes (i *iterations*)
          (sycamore-create keys))
        (let ((elapsed (- (get-internal-real-time) start)))
          (when (< elapsed best)
            (setf best elapsed)))))))

(defun bench-sycamore-lookup (keys)
  "Benchmark Sycamore tree-map lookup of all keys."
  (let ((m (sycamore-create keys))
        (best most-positive-fixnum))
    (dotimes (run *runs* best)
      (let ((start (get-internal-real-time)))
        (dotimes (i *iterations*)
          (dolist (k keys)
            (sycamore:tree-map-find m k)))
        (let ((elapsed (- (get-internal-real-time) start)))
          (when (< elapsed best)
            (setf best elapsed)))))))

(defun bench-sycamore-update (keys)
  "Benchmark Sycamore functional update of one key."
  (let ((m (sycamore-create keys))
        (update-key (first keys))
        (best most-positive-fixnum))
    (dotimes (run *runs* best)
      (let ((start (get-internal-real-time)))
        (dotimes (i *iterations*)
          (sycamore:tree-map-insert m update-key 99))
        (let ((elapsed (- (get-internal-real-time) start)))
          (when (< elapsed best)
            (setf best elapsed)))))))

;;; ---------------------------------------------------------------------------
;;; Reporting
;;; ---------------------------------------------------------------------------

(defun ticks-to-us-per-iter (ticks)
  "Convert internal time ticks to microseconds per iteration."
  (* (/ ticks internal-time-units-per-second) (/ 1000000 *iterations*)))

(defun run-benchmarks ()
  (format t "~%===================================================~%")
  (format t "FSet vs Sycamore Benchmark (~D iterations, best of ~D)~%"
          *iterations* *runs*)
  (format t "===================================================~%~%")
  (format t "~20A ~8A ~12A ~12A ~12A ~12A ~12A ~12A~%"
          "Key Count" "" "FSet Create" "Syc Create" "FSet Lookup" "Syc Lookup" "FSet Update" "Syc Update")
  (format t "~20A ~8A ~12A ~12A ~12A ~12A ~12A ~12A~%"
          "---------" "" "-----------" "----------" "-----------" "----------" "-----------" "----------")
  (dolist (n *key-counts*)
    (let* ((keys (make-keys n))
           (fc (bench-fset-create keys))
           (sc (bench-sycamore-create keys))
           (fl (bench-fset-lookup keys))
           (sl (bench-sycamore-lookup keys))
           (fu (bench-fset-update keys))
           (su (bench-sycamore-update keys)))
      (format t "~20D ~8A ~10,2F us ~10,2F us ~10,2F us ~10,2F us ~10,2F us ~10,2F us~%"
              n ""
              (ticks-to-us-per-iter fc) (ticks-to-us-per-iter sc)
              (ticks-to-us-per-iter fl) (ticks-to-us-per-iter sl)
              (ticks-to-us-per-iter fu) (ticks-to-us-per-iter su))))

  (format t "~%--- Summary ---~%")
  (format t "Comparing ratios (FSet/Sycamore, <1.0 means FSet is faster):~%~%")
  (format t "~10A ~12A ~12A ~12A~%"
          "Keys" "Create" "Lookup" "Update")
  (format t "~10A ~12A ~12A ~12A~%"
          "----" "------" "------" "------")
  (dolist (n *key-counts*)
    (let* ((keys (make-keys n))
           (fc (bench-fset-create keys))
           (sc (bench-sycamore-create keys))
           (fl (bench-fset-lookup keys))
           (sl (bench-sycamore-lookup keys))
           (fu (bench-fset-update keys))
           (su (bench-sycamore-update keys)))
      (format t "~10D ~10,2Fx ~10,2Fx ~10,2Fx~%"
              n
              (/ (float fc) (float sc))
              (/ (float fl) (float sl))
              (/ (float fu) (float su)))))
  (format t "~%===================================================~%"))

(run-benchmarks)
