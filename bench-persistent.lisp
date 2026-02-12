;;; Benchmark: FSet wb-map vs Sycamore hash-map for persistent object slot storage
;;;
;;; Tests value access (lookup) performance with keyword symbol keys
;;; for objects with 2, 5, 10, and 20 slots.

(ql:quickload '("fset" "sycamore") :silent t)

(defpackage :bench-persistent
  (:use :cl))

(in-package :bench-persistent)

;;; ============================================================================
;;; Build maps with N keyword-symbol keys
;;; ============================================================================

(defun make-slot-keywords (n)
  "Generate N keyword symbols like :SLOT-1, :SLOT-2, ..."
  (loop for i from 1 to n
        collect (intern (format nil "SLOT-~D" i) :keyword)))

(defun build-fset-map (keys)
  "Build an FSet wb-map from KEYS, each mapped to its index."
  (let ((m (fset:empty-map)))
    (loop for k in keys
          for i from 0
          do (setf m (fset:with m k i)))
    m))

(defun build-sycamore-hash-map (keys)
  "Build a Sycamore hash-map from KEYS, each mapped to its index."
  (let ((m (sycamore:make-hash-map)))
    (loop for k in keys
          for i from 0
          do (setf m (sycamore:hash-map-insert m k i)))
    m))

(defun build-sycamore-tree-map (keys)
  "Build a Sycamore tree-map from KEYS (using string compare), each mapped to its index."
  (let ((m (sycamore:make-tree-map #'(lambda (a b)
                                        (let ((sa (symbol-name a))
                                              (sb (symbol-name b)))
                                          (cond ((string< sa sb) -1)
                                                ((string= sa sb) 0)
                                                (t 1)))))))
    (loop for k in keys
          for i from 0
          do (setf m (sycamore:tree-map-insert m k i)))
    m))

;;; ============================================================================
;;; Benchmark: value access (lookup)
;;; ============================================================================

(defun bench-fset-lookup (map keys iterations)
  "Time ITERATIONS lookups of each key in FSet MAP."
  (let ((start (get-internal-real-time)))
    (dotimes (_ iterations)
      (dolist (k keys)
        (fset:lookup map k)))
    (let ((end (get-internal-real-time)))
      (/ (- end start) (float internal-time-units-per-second)))))

(defun bench-sycamore-hash-lookup (map keys iterations)
  "Time ITERATIONS lookups of each key in Sycamore hash-map MAP."
  (let ((start (get-internal-real-time)))
    (dotimes (_ iterations)
      (dolist (k keys)
        (sycamore:hash-map-find map k)))
    (let ((end (get-internal-real-time)))
      (/ (- end start) (float internal-time-units-per-second)))))

(defun bench-sycamore-tree-lookup (map keys iterations)
  "Time ITERATIONS lookups of each key in Sycamore tree-map MAP."
  (let ((start (get-internal-real-time)))
    (dotimes (_ iterations)
      (dolist (k keys)
        (sycamore:tree-map-find map k)))
    (let ((end (get-internal-real-time)))
      (/ (- end start) (float internal-time-units-per-second)))))

;;; ============================================================================
;;; Benchmark: construction (creating a new map from scratch)
;;; ============================================================================

(defun bench-fset-construct (keys iterations)
  "Time ITERATIONS constructions of an FSet map with KEYS."
  (let ((start (get-internal-real-time)))
    (dotimes (_ iterations)
      (let ((m (fset:empty-map)))
        (loop for k in keys
              for i from 0
              do (setf m (fset:with m k i)))))
    (let ((end (get-internal-real-time)))
      (/ (- end start) (float internal-time-units-per-second)))))

(defun bench-sycamore-hash-construct (keys iterations)
  "Time ITERATIONS constructions of a Sycamore hash-map with KEYS."
  (let ((start (get-internal-real-time)))
    (dotimes (_ iterations)
      (let ((m (sycamore:make-hash-map)))
        (loop for k in keys
              for i from 0
              do (setf m (sycamore:hash-map-insert m k i)))))
    (let ((end (get-internal-real-time)))
      (/ (- end start) (float internal-time-units-per-second)))))

(defun bench-sycamore-tree-construct (keys iterations)
  "Time ITERATIONS constructions of a Sycamore tree-map with KEYS."
  (let ((start (get-internal-real-time)))
    (dotimes (_ iterations)
      (let ((m (sycamore:make-tree-map #'(lambda (a b)
                                            (let ((sa (symbol-name a))
                                                  (sb (symbol-name b)))
                                              (cond ((string< sa sb) -1)
                                                    ((string= sa sb) 0)
                                                    (t 1)))))))
        (loop for k in keys
              for i from 0
              do (setf m (sycamore:tree-map-insert m k i)))))
    (let ((end (get-internal-real-time)))
      (/ (- end start) (float internal-time-units-per-second)))))

;;; ============================================================================
;;; Benchmark: functional update (with one slot changed)
;;; ============================================================================

(defun bench-fset-update (map target-key iterations)
  "Time ITERATIONS updates of TARGET-KEY in FSet MAP."
  (let ((start (get-internal-real-time)))
    (dotimes (i iterations)
      (fset:with map target-key i))
    (let ((end (get-internal-real-time)))
      (/ (- end start) (float internal-time-units-per-second)))))

(defun bench-sycamore-hash-update (map target-key iterations)
  "Time ITERATIONS updates of TARGET-KEY in Sycamore hash-map MAP."
  (let ((start (get-internal-real-time)))
    (dotimes (i iterations)
      (sycamore:hash-map-insert map target-key i))
    (let ((end (get-internal-real-time)))
      (/ (- end start) (float internal-time-units-per-second)))))

(defun bench-sycamore-tree-update (map target-key iterations)
  "Time ITERATIONS updates of TARGET-KEY in Sycamore tree-map MAP."
  (let ((start (get-internal-real-time)))
    (dotimes (i iterations)
      (sycamore:tree-map-insert map target-key i))
    (let ((end (get-internal-real-time)))
      (/ (- end start) (float internal-time-units-per-second)))))

;;; ============================================================================
;;; Run all benchmarks
;;; ============================================================================

(defun run-benchmarks ()
  (let ((slot-counts '(2 5 10 20))
        (iterations 100000))
    (format t "~%=== Persistent Object Storage Benchmark ===~%")
    (format t "Iterations: ~:D per slot count~%~%" iterations)

    ;; Warmup
    (let ((keys (make-slot-keywords 20)))
      (let ((fm (build-fset-map keys))
            (sm (build-sycamore-hash-map keys))
            (tm (build-sycamore-tree-map keys)))
        (dotimes (_ 1000)
          (dolist (k keys)
            (fset:lookup fm k)
            (sycamore:hash-map-find sm k)
            (sycamore:tree-map-find tm k)))))

    (format t "~%--- VALUE ACCESS (LOOKUP) ---~%")
    (format t "~30A ~12A ~12A ~12A ~12A ~12A~%"
            "Slots" "FSet" "Syc-Hash" "Syc-Tree" "Hash/FSet" "Tree/FSet")
    (format t "~30A ~12A ~12A ~12A ~12A ~12A~%"
            "-----" "----" "--------" "--------" "---------" "---------")
    (dolist (n slot-counts)
      (let* ((keys (make-slot-keywords n))
             (fm (build-fset-map keys))
             (sm (build-sycamore-hash-map keys))
             (tm (build-sycamore-tree-map keys))
             (ft (bench-fset-lookup fm keys iterations))
             (st (bench-sycamore-hash-lookup sm keys iterations))
             (tt (bench-sycamore-tree-lookup tm keys iterations)))
        (format t "~30D ~12,4F ~12,4F ~12,4F ~12,2F ~12,2F~%"
                n ft st tt (/ st ft) (/ tt ft))))

    (format t "~%--- CONSTRUCTION ---~%")
    (format t "~30A ~12A ~12A ~12A ~12A ~12A~%"
            "Slots" "FSet" "Syc-Hash" "Syc-Tree" "Hash/FSet" "Tree/FSet")
    (format t "~30A ~12A ~12A ~12A ~12A ~12A~%"
            "-----" "----" "--------" "--------" "---------" "---------")
    (dolist (n slot-counts)
      (let* ((keys (make-slot-keywords n))
             (ft (bench-fset-construct keys iterations))
             (st (bench-sycamore-hash-construct keys iterations))
             (tt (bench-sycamore-tree-construct keys iterations)))
        (format t "~30D ~12,4F ~12,4F ~12,4F ~12,2F ~12,2F~%"
                n ft st tt (/ st ft) (/ tt ft))))

    (format t "~%--- FUNCTIONAL UPDATE (single slot) ---~%")
    (format t "~30A ~12A ~12A ~12A ~12A ~12A~%"
            "Slots" "FSet" "Syc-Hash" "Syc-Tree" "Hash/FSet" "Tree/FSet")
    (format t "~30A ~12A ~12A ~12A ~12A ~12A~%"
            "-----" "----" "--------" "--------" "---------" "---------")
    (dolist (n slot-counts)
      (let* ((keys (make-slot-keywords n))
             (target (first keys))
             (fm (build-fset-map keys))
             (sm (build-sycamore-hash-map keys))
             (tm (build-sycamore-tree-map keys))
             (ft (bench-fset-update fm target iterations))
             (st (bench-sycamore-hash-update sm target iterations))
             (tt (bench-sycamore-tree-update tm target iterations)))
        (format t "~30D ~12,4F ~12,4F ~12,4F ~12,2F ~12,2F~%"
                n ft st tt (/ st ft) (/ tt ft))))

    (format t "~%Ratio < 1.0 = faster than FSet, > 1.0 = slower than FSet~%")))

(run-benchmarks)
