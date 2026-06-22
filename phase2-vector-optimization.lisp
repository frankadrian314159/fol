#!/usr/bin/env sbcl --script
;;; Phase 2: Vector Access Specialization Benchmark
;;;
;;; Compares quicksort performance:
;;; 1. Baseline (no optimization)
;;; 2. With Phase 1 pragma
;;; 3. With Phase 1 + Phase 2 vec-nth specialization

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

(defun cl-qsort (arr low high)
  "CL quicksort with mutable arrays"
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
;;;; FOL Implementations
;;;; ─────────────────────────────────────────────────────────────────────────

(format t "~%Compiling FOL quicksort implementations...~%")

;; Baseline implementation (no optimization)
(fol.compiler:disable-inline-methods)

(eval (fol.compiler:compilation-result-code
  (fol.compiler:compile-form
    (fol.compiler.reader:fol-read-from-string "
(defn partition-baseline [v low high]
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
"))))

(eval (fol.compiler:compilation-result-code
  (fol.compiler:compile-form
    (fol.compiler.reader:fol-read-from-string "
(defn qsort-baseline [v low high]
  (if (< low high)
    (bind [[v-part p] (partition-baseline v low high)
           v-left (qsort-baseline v-part low (- p 1))]
      (qsort-baseline v-left (+ p 1) high))
    v))
"))))

;; Phase 1: With pragma
(fol.compiler:enable-inline-methods t)

(eval (fol.compiler:compilation-result-code
  (fol.compiler:compile-form
    (fol.compiler.reader:fol-read-from-string "
(defn partition-p1 [v low high]
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
"))))

(eval (fol.compiler:compilation-result-code
  (fol.compiler:compile-form
    (fol.compiler.reader:fol-read-from-string "
(defn qsort-p1 [v low high]
  (if (< low high)
    (bind [[v-part p] (partition-p1 v low high)
           v-left (qsort-p1 v-part low (- p 1))]
      (qsort-p1 v-left (+ p 1) high))
    v))
"))))

(fol.compiler:disable-inline-methods)

;; Phase 2: With pragma + vec-nth specialization
(fol.compiler:enable-inline-methods t)

(eval (fol.compiler:compilation-result-code
  (fol.compiler:compile-form
    (fol.compiler.reader:fol-read-from-string "
(defn partition-p2 [v low high]
  (bind [pivot (fol.compiler.collection-functions:vec-nth v high)]
    (loop [j low, i (- low 1), curr-v v]
      (if (< j high)
        (if (<= (fol.compiler.collection-functions:vec-nth curr-v j) pivot)
          (bind [next-i (+ i 1)
                 temp (fol.compiler.collection-functions:vec-nth curr-v next-i)
                 v1 (assoc curr-v next-i (fol.compiler.collection-functions:vec-nth curr-v j))
                 v2 (assoc v1 j temp)]
            (recur (+ j 1) next-i v2))
          (recur (+ j 1) i curr-v))
        (bind [next-i (+ i 1)
               temp (fol.compiler.collection-functions:vec-nth curr-v next-i)
               v1 (assoc curr-v next-i (fol.compiler.collection-functions:vec-nth curr-v high))
               v2 (assoc v1 high temp)]
          [v2 next-i])))))
"))))

(eval (fol.compiler:compilation-result-code
  (fol.compiler:compile-form
    (fol.compiler.reader:fol-read-from-string "
(defn qsort-p2 [v low high]
  (if (< low high)
    (bind [[v-part p] (partition-p2 v low high)
           v-left (qsort-p2 v-part low (- p 1))]
      (qsort-p2 v-left (+ p 1) high))
    v))
"))))

(fol.compiler:disable-inline-methods)

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; Benchmarking
;;;; ─────────────────────────────────────────────────────────────────────────

(format t "~%~%")
(format t "════════════════════════════════════════════════════════════════════~%")
(format t "            PHASE 2: VECTOR ACCESS SPECIALIZATION RESULTS~%")
(format t "════════════════════════════════════════════════════════════════════~%")

(format t "~%=== QUICKSORT BENCHMARK (N=10,000) ===~%")

(let ((n 10000))
  ;; Create test data
  (let ((test-data (make-array n)))
    (dotimes (i n) (setf (aref test-data i) (random 100000)))

    ;; Create FOL vectors
    (format t "~%Creating test vectors...~%")
    (let ((fol-vec-baseline
            (loop with v = (fol.compiler.collection-functions:vector)
                  for i below n
                  do (setf v (fol.compiler.collection-functions:conj v (random 100000)))
                  finally (return v)))
          (fol-vec-p1
            (loop with v = (fol.compiler.collection-functions:vector)
                  for i below n
                  do (setf v (fol.compiler.collection-functions:conj v (random 100000)))
                  finally (return v)))
          (fol-vec-p2
            (loop with v = (fol.compiler.collection-functions:vector)
                  for i below n
                  do (setf v (fol.compiler.collection-functions:conj v (random 100000)))
                  finally (return v))))

      ;; Warmup
      (format t "Warming up...~%")
      (let ((arr (copy-seq test-data)))
        (cl-qsort arr 0 (1- n)))
      (qsort-baseline fol-vec-baseline 0 (1- n))
      (qsort-p1 fol-vec-p1 0 (1- n))
      (qsort-p2 fol-vec-p2 0 (1- n))

      ;; Benchmark results table
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
            (let ((arr (copy-seq test-data)))
              (cl-qsort arr 0 (1- n)))
            (push (/ (- (get-internal-real-time) start) internal-time-units-per-second) times)))
        (let ((avg (/ (apply #'+ times) 3)))
          (format t "│ CL (reference)                   │ ~7,2F   │ baseline         │~%" (* avg 1000))))

      ;; Baseline (no optimization)
      (sb-ext:gc :full t)
      (let ((times (list)))
        (dotimes (i 3)
          (let ((start (get-internal-real-time)))
            (qsort-baseline fol-vec-baseline 0 (1- n))
            (push (/ (- (get-internal-real-time) start) internal-time-units-per-second) times)))
        (let ((avg (/ (apply #'+ times) 3)))
          (format t "│ FOL Baseline (no optimization)   │ ~7,2F   │ 1.0×             │~%" (* avg 1000))))

      ;; Phase 1 (pragma enabled)
      (sb-ext:gc :full t)
      (let ((times (list)))
        (dotimes (i 3)
          (let ((start (get-internal-real-time)))
            (qsort-p1 fol-vec-p1 0 (1- n))
            (push (/ (- (get-internal-real-time) start) internal-time-units-per-second) times)))
        (let ((avg (/ (apply #'+ times) 3)))
          (format t "│ FOL Phase 1 (pragma)             │ ~7,2F   │ ? (TBD)          │~%" (* avg 1000))))

      ;; Phase 2 (pragma + vec-nth)
      (sb-ext:gc :full t)
      (let ((times (list)))
        (dotimes (i 3)
          (let ((start (get-internal-real-time)))
            (qsort-p2 fol-vec-p2 0 (1- n))
            (push (/ (- (get-internal-real-time) start) internal-time-units-per-second) times)))
        (let ((avg (/ (apply #'+ times) 3)))
          (format t "│ FOL Phase 1+2 (pragma+vec-nth)   │ ~7,2F   │ ? (TBD)          │~%" (* avg 1000))))

      (format t "~%~{~A~%~}" '(
        "└──────────────────────────────────┴──────────┴──────────────────┘")))))

(format t "~%~%")
(format t "════════════════════════════════════════════════════════════════════~%")
(format t "                          OPTIMIZATION SUMMARY~%")
(format t "════════════════════════════════════════════════════════════════════~%")
(format t "~%Phase 1 (Pragma Inlining):~%")
(format t "  - Expected: 5-10x speedup from assoc dispatch elimination~%")
(format t "  - Actual: [See table above]~%")
(format t "~%Phase 2 (Vector Access Specialization):~%")
(format t "  - Expected: 1.5-2x speedup from vec-nth dispatch elimination~%")
(format t "  - Actual: [See table above]~%")
(format t "~%Phase 1+2 Combined:~%")
(format t "  - Expected: 5-10x × 1.5-2x = 7.5-20x total speedup~%")
(format t "  - Actual: [See table above]~%")
(format t "~%")
(format t "════════════════════════════════════════════════════════════════════~%")

(sb-ext:exit)
