;;; LSim GC Pressure Benchmarks
;;;
;;; Measures GC pressure (bytes consed, GC invocations, live-heap delta,
;;; allocation rate) for all four LSim circuits across CL and FOL variants.
;;;
;;; For each circuit the following are reported per single simulation run:
;;;   - Wall time (s)
;;;   - Bytes consed (MB)          – total allocations, drives GC frequency
;;;   - Bytes per time-step (KB)   – normalised allocation intensity
;;;   - GC invocations             – how many minor/major GCs occurred
;;;   - MB/s alloc rate            – allocation throughput
;;;   - Live-heap delta (KB)       – heap retained after full GC
;;;
;;; Circuits and their sizes:
;;;   8bit-100   :  100 time steps,   ~128 NAND gates
;;;   32bit-300  :  300 time steps,   ~512 NAND gates
;;;   8x32-900   :  900 time steps, ~1024 NAND gates
;;;   32x32-3000 : 3000 time steps, ~4096 NAND gates
;;;
;;; Assumes the following packages are already defined and all four circuit
;;; run-bench functions are loaded before calling run-gc-pressure-benchmarks:
;;;   lsim-cl  (CL mutable)
;;;   lsim     (FOL persistent, serial)

(defpackage :fol.benchmarks.lsim-gc
  (:use :cl)
  (:export :run-gc-pressure-benchmarks
           :measure-circuit
           :print-circuit-report
           :print-summary-table
           :print-benchmark-header))

(in-package :fol.benchmarks.lsim-gc)

;;;; ============================================================
;;;; GC measurement infrastructure
;;;; ============================================================

(defvar *gc-invocations* 0
  "Counter incremented by the after-GC hook during measurement windows.")

(defun current-heap-bytes ()
  "Bytes currently in use in the dynamic heap (SBCL-specific)."
  (sb-kernel:dynamic-usage))

(defmacro measure-gc-pressure (thunk-form n-iters &key (warmup 1))
  "Run THUNK-FORM N-ITERS times (after WARMUP warm-up calls).
   Returns a plist:
     :bytes-consed   – total bytes allocated across all iters
     :bytes-per-iter – bytes-consed / n-iters
     :gc-count       – GC completions across all iters
     :gc-per-iter    – gc-count / n-iters
     :wall-seconds   – total wall time across all iters
     :secs-per-iter  – wall-seconds / n-iters
     :heap-delta     – live-heap difference (post-fullgc – pre-fullgc), bytes"
  (let ((fn (gensym "FN"))
        (saved-hooks (gensym "HOOKS"))
        (hook (gensym "HOOK"))
        (gc-count (gensym "GCC"))
        (pre-bytes (gensym "PREB"))
        (pre-heap (gensym "PREH"))
        (pre-time (gensym "PRET"))
        (post-bytes (gensym "POSTB"))
        (post-heap (gensym "POSTH"))
        (post-time (gensym "POSTT")))
    `(let ((,fn (lambda () ,thunk-form)))
       ;; Warm up
       (dotimes (_ ,warmup) (funcall ,fn))
       ;; Force full GC to start clean
       (sb-ext:gc :full t)
       (let* ((,gc-count 0)
              (,hook (lambda () (incf ,gc-count)))
              (,saved-hooks sb-ext:*after-gc-hooks*)
              (,pre-bytes (sb-ext:get-bytes-consed))
              (,pre-heap  (current-heap-bytes))
              (,pre-time  (get-internal-real-time)))
         (push ,hook sb-ext:*after-gc-hooks*)
         (unwind-protect
             (dotimes (_ ,n-iters) (funcall ,fn))
           ;; Always restore hooks
           (setf sb-ext:*after-gc-hooks* ,saved-hooks))
         (let ((,post-bytes (sb-ext:get-bytes-consed))
               (,post-time  (get-internal-real-time)))
           (sb-ext:gc :full t)
           (let* ((,post-heap    (current-heap-bytes))
                  (total-bytes   (- ,post-bytes ,pre-bytes))
                  (total-secs    (/ (- ,post-time ,pre-time)
                                    (float internal-time-units-per-second))))
             (list :bytes-consed   total-bytes
                   :bytes-per-iter (/ total-bytes ,n-iters)
                   :gc-count       ,gc-count
                   :gc-per-iter    (/ ,gc-count (float ,n-iters))
                   :wall-seconds   total-secs
                   :secs-per-iter  (/ total-secs ,n-iters)
                   :heap-delta     (- ,post-heap ,pre-heap))))))))

;;;; ============================================================
;;;; Formatting helpers
;;;; ============================================================

(defun fmt-bytes (b)
  "Format byte count as MB (3 decimal places)."
  (format nil "~,3F MB" (/ b (* 1024.0 1024.0))))

(defun fmt-kb (b)
  "Format byte count as KB (1 decimal place)."
  (format nil "~,1F KB" (/ b 1024.0)))

(defun fmt-rate (bytes secs)
  "Format MB/s allocation rate."
  (if (zerop secs)
      "N/A"
      (format nil "~,1F MB/s" (/ (/ bytes (* 1024.0 1024.0)) secs))))

(defun fmt-time (s)
  "Format seconds with 3 decimal places."
  (format nil "~,3F s" s))

(defun ratio-str (fol-val cl-val label)
  "Format FOL/CL ratio with 'x' suffix."
  (declare (ignore label))
  (if (zerop cl-val)
      "N/A"
      (format nil "~,2Fx" (/ (float fol-val) (float cl-val)))))

;;;; ============================================================
;;;; Single-circuit measurement
;;;; ============================================================

(defun measure-circuit (name steps cl-fn fol-fn n-iters)
  "Measure GC pressure for one circuit. Returns a result plist."
  (format t "  Measuring CL ...~%")
  (let ((cl-stats (measure-gc-pressure (funcall cl-fn) n-iters :warmup 1)))
    (format t "  Measuring FOL ...~%")
    (let ((fol-stats (measure-gc-pressure (funcall fol-fn) n-iters :warmup 1)))
      (list :name name :steps steps :n-iters n-iters
            :cl cl-stats :fol fol-stats))))

;;;; ============================================================
;;;; Report printer
;;;; ============================================================

(defun print-circuit-report (result)
  (let* ((name     (getf result :name))
         (steps    (getf result :steps))
         (n-iters  (getf result :n-iters))
         (cl       (getf result :cl))
         (fol      (getf result :fol))
         (cl-bpi   (getf cl  :bytes-per-iter))
         (fol-bpi  (getf fol :bytes-per-iter))
         (cl-gpi   (getf cl  :gc-per-iter))
         (fol-gpi  (getf fol :gc-per-iter))
         (cl-spi   (getf cl  :secs-per-iter))
         (fol-spi  (getf fol :secs-per-iter))
         (cl-hd    (getf cl  :heap-delta))
         (fol-hd   (getf fol :heap-delta)))
    (format t "~%  ~A  (~D steps, ~D iter~:P)~%" name steps n-iters)
    (format t "  ~42A ~14A ~14A ~8A~%"
            "" "CL (mutable)" "FOL (persist.)" "Ratio")
    (format t "  ~42A ~14A ~14A ~8A~%"
            (make-string 42 :initial-element #\-)
            (make-string 14 :initial-element #\-)
            (make-string 14 :initial-element #\-)
            (make-string 8  :initial-element #\-))
    (flet ((row (label cl-v fol-v ratio)
             (format t "  ~42A ~14A ~14A ~8A~%"
                     label cl-v fol-v ratio)))
      (row "Wall time / run"
           (fmt-time cl-spi) (fmt-time fol-spi)
           (ratio-str fol-spi cl-spi ""))
      (row "Bytes consed / run"
           (fmt-bytes cl-bpi) (fmt-bytes fol-bpi)
           (ratio-str fol-bpi cl-bpi ""))
      (row "Bytes consed / time-step"
           (fmt-kb (/ cl-bpi steps)) (fmt-kb (/ fol-bpi steps))
           (ratio-str (/ fol-bpi steps) (/ cl-bpi steps) ""))
      (row "Allocation rate"
           (fmt-rate cl-bpi cl-spi) (fmt-rate fol-bpi fol-spi) "")
      (row "GC invocations / run"
           (format nil "~,2F" (float cl-gpi))
           (format nil "~,2F" (float fol-gpi))
           (ratio-str fol-gpi (max 0.001 cl-gpi) ""))
      (row "Live-heap delta after full GC"
           (fmt-kb cl-hd) (fmt-kb fol-hd) ""))))

(defun print-summary-table (results)
  (format t "~%~%================================================================~%")
  (format t "  SUMMARY: Bytes consed per run  (FOL / CL ratio)~%")
  (format t "================================================================~%")
  (format t "  ~15A ~12A ~12A ~8A ~12A ~12A ~8A~%"
          "Circuit" "CL (MB)" "FOL (MB)" "B ratio"
          "CL GC/run" "FOL GC/run" "G ratio")
  (format t "  ~15A ~12A ~12A ~8A ~12A ~12A ~8A~%"
          (make-string 15 :initial-element #\-)
          (make-string 12 :initial-element #\-)
          (make-string 12 :initial-element #\-)
          (make-string 8  :initial-element #\-)
          (make-string 12 :initial-element #\-)
          (make-string 12 :initial-element #\-)
          (make-string 8  :initial-element #\-))
  (dolist (r results)
    (let* ((cl    (getf r :cl))
           (fol   (getf r :fol))
           (cl-b  (getf cl  :bytes-per-iter))
           (fol-b (getf fol :bytes-per-iter))
           (cl-g  (getf cl  :gc-per-iter))
           (fol-g (getf fol :gc-per-iter)))
      (format t "  ~15A ~12,3F ~12,3F ~8,2Fx ~12,2F ~12,2F ~8,2Fx~%"
              (getf r :name)
              (/ cl-b  (* 1024.0 1024.0))
              (/ fol-b (* 1024.0 1024.0))
              (/ (float fol-b) (max 1.0 (float cl-b)))
              (float cl-g)
              (float fol-g)
              (/ (float fol-g) (max 0.001 (float cl-g)))))))

;;;; ============================================================
;;;; Main entry point
;;;; ============================================================

(defun print-benchmark-header ()
  (format t "~%~%================================================================~%")
  (format t "  LSim GC Pressure Benchmarks~%")
  (format t "  CL (mutable) vs FOL (persistent objects)~%")
  (format t "  SBCL ~A~%" (lisp-implementation-version))
  (format t "================================================================~%"))

(defparameter *circuit-iters*
  '(("8bit-100"   100  10)   ; name, steps, iters
    ("32bit-300"  300  10)
    ("8x32-900"   900   5)
    ("32x32-3000" 3000  3))
  "Per-circuit: (name time-steps measurement-iterations).")

(defun run-gc-pressure-benchmarks ()
  (format t "~%~%================================================================~%")
  (format t "  LSim GC Pressure Benchmarks~%")
  (format t "  CL (mutable) vs FOL (persistent objects)~%")
  (format t "  SBCL ~A~%"
          (lisp-implementation-version))
  (format t "================================================================~%")

  ;; Warm up SBCL's compiler/runtime before measurements
  (format t "~%Warming up...~%")
  (lsim-cl::run-bench)
  (lsim::run-bench)
  (sb-ext:gc :full t)
  (format t "Done.~%")

  (let ((results '()))

    (dolist (spec *circuit-iters*)
      (destructuring-bind (name steps n-iters) spec
        (format t "~%--- ~A ---~%" name)
        (let ((r (measure-circuit name steps
                                  (lambda () (lsim-cl::run-bench))
                                  (lambda () (lsim::run-bench))
                                  n-iters)))
          (print-circuit-report r)
          (push r results))))

    (print-summary-table (nreverse results))
    (format t "~%Done.~%")))
