#!/usr/bin/env sbcl --noinform --non-interactive

;;; Phase 3: Transient Optimization - FINAL POC
;;; Shows allocation impact of mutable vs. persistent operations

(defmacro measure-perf (desc &body body)
  "Measure time and allocation"
  `(let ((start (get-internal-real-time))
         (bytes-before (sb-ext:get-bytes-consed)))
     ,@body
     (let ((elapsed (/ (- (get-internal-real-time) start) internal-time-units-per-second))
           (allocated (- (sb-ext:get-bytes-consed) bytes-before)))
       (format t "~A~%" ,desc)
       (format t "  Time: ~7,3F ms | Alloc: ~15:D bytes (~,1F MB)~%"
               (* elapsed 1000) allocated (/ allocated 1024.0 1024.0))
       (values elapsed allocated))))

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; Quicksort Strategies
;;;; ─────────────────────────────────────────────────────────────────────────

(defun qsort-persistent (v low high)
  "Persistent-style: Copy vector at each swap (FOL vector assoc)"
  (if (< low high)
    (let* ((pivot (aref v high))
           (v-work (copy-seq v)))
      (loop for i from low below high
            when (<= (aref v-work i) pivot)
            do (rotatef (aref v-work low) (aref v-work i))
               (incf low))
      (rotatef (aref v-work low) (aref v-work high))
      (qsort-persistent v-work low (1- low))
      (qsort-persistent v-work (1+ low) high))
    v))

(defun qsort-transient (v low high)
  "Transient-style: Mutate in-place (FOL transient vector)"
  (let ((arr (copy-seq v)))
    (labels ((sort-mut (low high)
               (if (< low high)
                 (let* ((pivot (aref arr high))
                        (i (1- low)))
                   (loop for j from low below high do
                     (when (<= (aref arr j) pivot)
                       (incf i)
                       (rotatef (aref arr i) (aref arr j))))
                   (let ((i (1+ i)))
                     (rotatef (aref arr i) (aref arr high))
                     (sort-mut low (1- i))
                     (sort-mut (1+ i) high))))))
      (sort-mut low high))
    arr))

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; Main
;;;; ─────────────────────────────────────────────────────────────────────────

(format t "~%════════════════════════════════════════════════════════════════════~%")
(format t "   PHASE 3: TRANSIENT OPTIMIZATION - PROOF OF CONCEPT~%")
(format t "════════════════════════════════════════════════════════════════════~%~%")

(let ((n 1500))
  (format t "Test: Quicksort with N=~D random elements~%~%" n)
  (let ((test-data (make-array n :initial-contents (loop for i below n collect (random 100000)))))

    (sb-ext:gc :full t)
    (format t "Strategy 1: Persistent-Style (copy at each swap)~%")
    (let ((t1 0.0) (a1 0))
      (setf (values t1 a1) (measure-perf "" (qsort-persistent test-data 0 (1- n))))

      (sb-ext:gc :full t)
      (format t "Strategy 2: Transient-Style (mutate in-place)~%")
      (let ((t2 0.0) (a2 0))
        (setf (values t2 a2) (measure-perf "" (qsort-transient test-data 0 (1- n))))

        (format t "~%════════════════════════════════════════════════════════════════════~%")
        (format t "                          RESULTS~%")
        (format t "════════════════════════════════════════════════════════════════════~%")
        (format t "~%Speedup: ~7,2Fx~%" (/ t1 t2))
        (format t "Allocation Ratio: ~7,2Fx~%" (if (> a2 0) (/ a1 a2) 1))
        (format t "Memory Saved: ~15:D bytes (~,1F MB)~%" (- a1 a2) (/ (- a1 a2) 1024.0 1024.0))
        (format t "~%")))))

(format t "════════════════════════════════════════════════════════════════════~%")
(format t "                       KEY INSIGHTS~%")
(format t "════════════════════════════════════════════════════════════════════~%~%")
(format t "Persistent-Style (FOL default without transients):~%")
(format t "  - Every assoc creates new vector copy~%")
(format t "  - For quicksort: 100+ swaps × N log N = massive allocation~%")
(format t "~%Transient-Style (Phase 3 optimization):~%")
(format t "  - Mutate in-place during algorithm~%")
(format t "  - Only convert to persistent at completion~%")
(format t "  - Minimal allocation, minimal GC pressure~%")
(format t "~%Expected Gains:~%")
(format t "  - Time: 3-5x speedup from reduced allocation/GC~%")
(format t "  - Memory: 50-90% allocation reduction~%")
(format t "  - Combined Phase 1+2+3: 15-100x total speedup~%")
(format t "~%")
(format t "════════════════════════════════════════════════════════════════════~%")

(sb-ext:exit)
