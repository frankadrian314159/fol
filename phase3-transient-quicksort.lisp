#!/usr/bin/env sbcl --script
;;; Phase 3: Transient Vector Optimization for Quicksort
;;;
;;; Compares quicksort performance:
;;; 1. Baseline (no optimization)
;;; 2. Phase 1 (pragma enabled for inlining)
;;; 3. Phase 1+2 (pragma + vec-nth specialization)
;;; 4. Phase 1+2+3 (pragma + vec-nth + transient vectors)
;;;
;;; Key insight: Use transient vectors during sort (fast mutation),
;;; convert to persistent at completion (required for return value).

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
;;;; FOL Implementations (compiled)
;;;; ─────────────────────────────────────────────────────────────────────────

(format t "~%Compiling FOL quicksort implementations...~%")

;; Baseline: No optimization
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

(defn qsort-p1 [v low high]
  (if (< low high)
    (bind [[v-part p] (partition-p1 v low high)
           v-left (qsort-p1 v-part low (- p 1))]
      (qsort-p1 v-left (+ p 1) high))
    v))
"))))

(fol.compiler:disable-inline-methods)

;; Phase 2: With pragma + vec-nth
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

(defn qsort-p2 [v low high]
  (if (< low high)
    (bind [[v-part p] (partition-p2 v low high)
           v-left (qsort-p2 v-part low (- p 1))]
      (qsort-p2 v-left (+ p 1) high))
    v))
"))))

(fol.compiler:disable-inline-methods)

;; Phase 3: With pragma + vec-nth + transient vectors
;; Strategy: Convert to transient at start, use transient ops during sort,
;; convert back to persistent at completion
(fol.compiler:enable-inline-methods t)

(eval (fol.compiler:compilation-result-code
  (fol.compiler:compile-form
    (fol.compiler.reader:fol-read-from-string "
(defn partition-p3-transient [tv low high]
  \"Partition using transient vector operations (mutation)\"
  (bind [pivot (fol.compiler.collection-functions:vec-nth tv high)]
    (loop [j low, i (- low 1), curr-tv tv]
      (if (< j high)
        (if (<= (fol.compiler.collection-functions:vec-nth curr-tv j) pivot)
          (bind [next-i (+ i 1)
                 temp (fol.compiler.collection-functions:vec-nth curr-tv next-i)]
            ;; Transient assoc! for mutation
            (do (fol.compiler.collection-functions:assoc! curr-tv next-i
                  (fol.compiler.collection-functions:vec-nth curr-tv j))
                (fol.compiler.collection-functions:assoc! curr-tv j temp)
                (recur (+ j 1) next-i curr-tv)))
          (recur (+ j 1) i curr-tv))
        (bind [next-i (+ i 1)
               temp (fol.compiler.collection-functions:vec-nth curr-tv next-i)]
          (do (fol.compiler.collection-functions:assoc! curr-tv next-i
                (fol.compiler.collection-functions:vec-nth curr-tv high))
              (fol.compiler.collection-functions:assoc! curr-tv high temp)
              [curr-tv next-i]))))))

(defn qsort-p3-helper [tv low high]
  \"Quicksort using transient vector (mutable operations)\"
  (if (< low high)
    (bind [[tv-part p] (partition-p3-transient tv low high)]
      (do (qsort-p3-helper tv-part low (- p 1))
          (qsort-p3-helper tv-part (+ p 1) high)
          tv-part))
    tv))

(defn qsort-p3 [v low high]
  \"Quicksort with transient optimization:
   1. Convert to transient at start
   2. Sort with mutable operations
   3. Convert back to persistent at completion\"
  (bind [tv (fol.compiler.collection-functions:transient v)
         tv-sorted (qsort-p3-helper tv low high)]
    (fol.compiler.collection-functions:persistent! tv-sorted)))
"))))

(fol.compiler:disable-inline-methods)

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; Benchmarking
;;;; ─────────────────────────────────────────────────────────────────────────

(format t "~%~%")
(format t "════════════════════════════════════════════════════════════════════~%")
(format t "        PHASE 3: TRANSIENT VECTOR OPTIMIZATION RESULTS~%")
(format t "════════════════════════════════════════════════════════════════════~%")

(format t "~%=== QUICKSORT BENCHMARK (N=10,000) ===~%")

(let ((n 10000))
  ;; Create test data
  (let ((test-data (make-array n)))
    (dotimes (i n) (setf (aref test-data i) (random 100000)))

    ;; Create FOL vectors (same data for each)
    (format t "~%Creating test vectors...~%")
    (let ((fol-vec-baseline
            (loop with v = (fol.compiler.collection-functions:vector)
                  for i below n
                  do (setf v (fol.compiler.collection-functions:conj v (aref test-data i)))
                  finally (return v)))
          (fol-vec-p1
            (loop with v = (fol.compiler.collection-functions:vector)
                  for i below n
                  do (setf v (fol.compiler.collection-functions:conj v (aref test-data i)))
                  finally (return v)))
          (fol-vec-p2
            (loop with v = (fol.compiler.collection-functions:vector)
                  for i below n
                  do (setf v (fol.compiler.collection-functions:conj v (aref test-data i)))
                  finally (return v)))
          (fol-vec-p3
            (loop with v = (fol.compiler.collection-functions:vector)
                  for i below n
                  do (setf v (fol.compiler.collection-functions:conj v (aref test-data i)))
                  finally (return v))))

      ;; Warmup
      (format t "Warming up...~%")
      (let ((arr (copy-seq test-data)))
        (cl-qsort arr 0 (1- n)))
      (qsort-baseline fol-vec-baseline 0 (1- n))
      (qsort-p1 fol-vec-p1 0 (1- n))
      (qsort-p2 fol-vec-p2 0 (1- n))
      (qsort-p3 fol-vec-p3 0 (1- n))

      ;; Benchmark results table
      (format t "~%Benchmark Results (3 runs, average):~%")
      (format t "~%~{~A~%~}" '(
        "┌──────────────────────────────────┬──────────┬──────────────────┐"
        "│ Implementation                   │ Time(ms) │ vs Baseline      │"
        "├──────────────────────────────────┼──────────┼──────────────────┤"))

      ;; CL baseline
      (sb-ext:gc :full t)
      (let ((times (list)) (cl-time nil))
        (dotimes (i 3)
          (let ((start (get-internal-real-time)))
            (let ((arr (copy-seq test-data)))
              (cl-qsort arr 0 (1- n)))
            (push (/ (- (get-internal-real-time) start) internal-time-units-per-second) times)))
        (let ((avg (/ (apply #'+ times) 3)))
          (setf cl-time avg)
          (format t "│ CL (reference)                   │ ~7,2F   │ baseline         │~%" (* avg 1000))))

      ;; Baseline (no optimization)
      (sb-ext:gc :full t)
      (let ((times (list)) (baseline-time nil))
        (dotimes (i 3)
          (let ((start (get-internal-real-time)))
            (qsort-baseline fol-vec-baseline 0 (1- n))
            (push (/ (- (get-internal-real-time) start) internal-time-units-per-second) times)))
        (let ((avg (/ (apply #'+ times) 3)))
          (setf baseline-time avg)
          (format t "│ FOL Baseline (no optimization)   │ ~7,2F   │ 1.0×             │~%" (* avg 1000))))

      ;; Phase 1 (pragma enabled)
      (sb-ext:gc :full t)
      (let ((times (list)) (p1-time nil))
        (dotimes (i 3)
          (let ((start (get-internal-real-time)))
            (qsort-p1 fol-vec-p1 0 (1- n))
            (push (/ (- (get-internal-real-time) start) internal-time-units-per-second) times)))
        (let ((avg (/ (apply #'+ times) 3)))
          (setf p1-time avg)
          (format t "│ FOL Phase 1 (pragma)             │ ~7,2F   │ ~,2Fx          │~%"
                  (* avg 1000) (/ baseline-time avg))))

      ;; Phase 2 (pragma + vec-nth)
      (sb-ext:gc :full t)
      (let ((times (list)) (p2-time nil))
        (dotimes (i 3)
          (let ((start (get-internal-real-time)))
            (qsort-p2 fol-vec-p2 0 (1- n))
            (push (/ (- (get-internal-real-time) start) internal-time-units-per-second) times)))
        (let ((avg (/ (apply #'+ times) 3)))
          (setf p2-time avg)
          (format t "│ FOL Phase 1+2 (pragma+vec-nth)   │ ~7,2F   │ ~,2Fx          │~%"
                  (* avg 1000) (/ baseline-time avg))))

      ;; Phase 3 (pragma + vec-nth + transient)
      (sb-ext:gc :full t)
      (let ((times (list)) (p3-time nil))
        (dotimes (i 3)
          (let ((start (get-internal-real-time)))
            (qsort-p3 fol-vec-p3 0 (1- n))
            (push (/ (- (get-internal-real-time) start) internal-time-units-per-second) times)))
        (let ((avg (/ (apply #'+ times) 3)))
          (setf p3-time avg)
          (format t "│ FOL Phase 1+2+3 (transient)      │ ~7,2F   │ ~,2Fx          │~%"
                  (* avg 1000) (/ baseline-time avg))))

      (format t "~%~{~A~%~}" '(
        "└──────────────────────────────────┴──────────┴──────────────────┘")))))

(format t "~%~%")
(format t "════════════════════════════════════════════════════════════════════~%")
(format t "                          OPTIMIZATION SUMMARY~%")
(format t "════════════════════════════════════════════════════════════════════~%")
(format t "~%Phase 1 (Pragma Inlining):~%")
(format t "  - Expected: 5-10x speedup from assoc dispatch elimination~%")
(format t "~%Phase 2 (Vector Access Specialization):~%")
(format t "  - Expected: 1.5-2x speedup from vec-nth dispatch elimination~%")
(format t "~%Phase 3 (Transient Vectors):~%")
(format t "  - Expected: 3-5x speedup from allocation pressure reduction~%")
(format t "  - Mechanism: Use mutable transient during sort, convert at completion~%")
(format t "~%Phase 1+2+3 Combined:~%")
(format t "  - Expected: 5-10x × 1.5-2x × 3-5x = 15-100x total speedup~%")
(format t "  - Target: Near or at CL performance parity~%")
(format t "~%")
(format t "════════════════════════════════════════════════════════════════════~%")

(sb-ext:exit)
