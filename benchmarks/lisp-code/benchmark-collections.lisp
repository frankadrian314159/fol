;;; =============================================================================
;;; Benchmark: FSet vs Sycamore for persistent collections
;;;
;;; Tests vector (seq), dict (map), and set operations at small (5) and
;;; large (2000) element counts.
;;; =============================================================================

(ql:quickload '(:fset :sycamore) :silent t)

(defpackage :benchmark-collections
  (:use :cl))

(in-package :benchmark-collections)

(defparameter *runs* 5)

;;; ---------------------------------------------------------------------------
;;; Timing harness
;;; ---------------------------------------------------------------------------

(defun run-timed (label iterations fn)
  "Run FN ITERATIONS times for *runs* rounds, report best in us/iter."
  (let ((best most-positive-fixnum))
    (dotimes (run *runs*)
      (let ((start (get-internal-real-time)))
        (dotimes (i iterations)
          (funcall fn))
        (let ((elapsed (- (get-internal-real-time) start)))
          (when (< elapsed best)
            (setf best elapsed)))))
    (let* ((elapsed-s (/ best internal-time-units-per-second))
           (per-call-us (* (/ elapsed-s iterations) 1000000)))
      (format t "  ~40A ~8,2F us/iter~%" label per-call-us)
      per-call-us)))

;;; ---------------------------------------------------------------------------
;;; Key generation
;;; ---------------------------------------------------------------------------

(defun make-integer-keys (n)
  (loop for i below n collect i))

(defun make-keyword-keys (n)
  (loop for i below n collect (intern (format nil "K~D" i) :keyword)))

;;; ---------------------------------------------------------------------------
;;; Sycamore comparators
;;; ---------------------------------------------------------------------------

(defun integer-compare (a b)
  (cond ((< a b) -1) ((> a b) 1) (t 0)))

(defun keyword-compare (a b)
  (let ((sa (symbol-name a)) (sb (symbol-name b)))
    (cond ((string< sa sb) -1) ((string> sa sb) 1) (t 0))))

;;; ===========================================================================
;;; VECTOR (FSet only)
;;; ===========================================================================

(defun bench-fset-seq (n iters)
  (let ((elements (make-integer-keys n)))
    (format t "~%--- FSet seq (n=~D, ~D iters) ---~%" n iters)
    (run-timed "create (convert from list)" iters
               (lambda () (fset:convert 'fset:seq elements)))
    (let ((seq (fset:convert 'fset:seq elements)))
      (run-timed "lookup (middle index)" iters
                 (lambda () (fset:lookup seq (floor n 2)))))
    (let ((seq (fset:convert 'fset:seq elements)))
      (run-timed "append (with-last)" iters
                 (lambda () (fset:with-last seq 999))))))

;;; ===========================================================================
;;; DICT (Map)
;;; ===========================================================================

(defun bench-fset-map (n iters)
  (let ((keys (make-keyword-keys n)))
    (format t "~%--- FSet wb-map (n=~D, ~D iters) ---~%" n iters)
    (run-timed "create" iters
               (lambda ()
                 (let ((m (fset:empty-map)))
                   (dolist (k keys) (setf m (fset:with m k 42))) m)))
    (let ((m (let ((m (fset:empty-map)))
               (dolist (k keys m) (setf m (fset:with m k 42))))))
      (run-timed "lookup (all keys)" iters
                 (lambda () (dolist (k keys) (fset:lookup m k)))))
    (let ((m (let ((m (fset:empty-map)))
               (dolist (k keys m) (setf m (fset:with m k 42))))))
      (run-timed "insert (new key)" iters
                 (lambda () (fset:with m :new-key 99))))))

(defun bench-sycamore-treemap (n iters)
  (let ((keys (make-keyword-keys n)))
    (format t "~%--- Sycamore tree-map (n=~D, ~D iters) ---~%" n iters)
    (run-timed "create" iters
               (lambda ()
                 (let ((m (sycamore:make-tree-map #'keyword-compare)))
                   (dolist (k keys) (setf m (sycamore:tree-map-insert m k 42))) m)))
    (let ((m (let ((m (sycamore:make-tree-map #'keyword-compare)))
               (dolist (k keys m) (setf m (sycamore:tree-map-insert m k 42))))))
      (run-timed "lookup (all keys)" iters
                 (lambda () (dolist (k keys) (sycamore:tree-map-find m k)))))
    (let ((m (let ((m (sycamore:make-tree-map #'keyword-compare)))
               (dolist (k keys m) (setf m (sycamore:tree-map-insert m k 42))))))
      (run-timed "insert (new key)" iters
                 (lambda () (sycamore:tree-map-insert m :new-key 99))))))

(defun bench-sycamore-hashmap (n iters)
  (let ((keys (make-keyword-keys n)))
    (format t "~%--- Sycamore hash-map (n=~D, ~D iters) ---~%" n iters)
    (run-timed "create" iters
               (lambda ()
                 (let ((m (sycamore:make-hash-map)))
                   (dolist (k keys) (setf m (sycamore:hash-map-insert m k 42))) m)))
    (let ((m (let ((m (sycamore:make-hash-map)))
               (dolist (k keys m) (setf m (sycamore:hash-map-insert m k 42))))))
      (run-timed "lookup (all keys)" iters
                 (lambda () (dolist (k keys) (sycamore:hash-map-find m k)))))
    (let ((m (let ((m (sycamore:make-hash-map)))
               (dolist (k keys m) (setf m (sycamore:hash-map-insert m k 42))))))
      (run-timed "insert (new key)" iters
                 (lambda () (sycamore:hash-map-insert m :new-key 99))))))

;;; ===========================================================================
;;; SET
;;; ===========================================================================

(defun bench-fset-set (n iters)
  (let ((elements (make-integer-keys n)))
    (format t "~%--- FSet wb-set (n=~D, ~D iters) ---~%" n iters)
    (run-timed "create" iters
               (lambda ()
                 (let ((s (fset:empty-set)))
                   (dolist (e elements) (setf s (fset:with s e))) s)))
    (let ((s (fset:convert 'fset:set elements)))
      (run-timed "membership (all elements)" iters
                 (lambda () (dolist (e elements) (fset:contains? s e)))))
    (let ((s (fset:convert 'fset:set elements)))
      (run-timed "insert (new element)" iters
                 (lambda () (fset:with s -1))))))

(defun bench-sycamore-treeset (n iters)
  (let ((elements (make-integer-keys n)))
    (format t "~%--- Sycamore tree-set (n=~D, ~D iters) ---~%" n iters)
    (run-timed "create" iters
               (lambda ()
                 (let ((s (sycamore:make-tree-set #'integer-compare)))
                   (dolist (e elements) (setf s (sycamore:tree-set-insert s e))) s)))
    (let ((s (let ((s (sycamore:make-tree-set #'integer-compare)))
               (dolist (e elements s) (setf s (sycamore:tree-set-insert s e))))))
      (run-timed "membership (all elements)" iters
                 (lambda () (dolist (e elements) (sycamore:tree-set-member-p s e)))))
    (let ((s (let ((s (sycamore:make-tree-set #'integer-compare)))
               (dolist (e elements s) (setf s (sycamore:tree-set-insert s e))))))
      (run-timed "insert (new element)" iters
                 (lambda () (sycamore:tree-set-insert s -1))))))

(defun bench-sycamore-hashset (n iters)
  (let ((elements (make-integer-keys n)))
    (format t "~%--- Sycamore hash-set (n=~D, ~D iters) ---~%" n iters)
    (run-timed "create" iters
               (lambda ()
                 (let ((s (sycamore:make-hash-set)))
                   (dolist (e elements) (setf s (sycamore:hash-set-insert s e))) s)))
    (let ((s (let ((s (sycamore:make-hash-set)))
               (dolist (e elements s) (setf s (sycamore:hash-set-insert s e))))))
      (run-timed "membership (all elements)" iters
                 (lambda () (dolist (e elements) (sycamore:hash-set-find s e)))))
    (let ((s (let ((s (sycamore:make-hash-set)))
               (dolist (e elements s) (setf s (sycamore:hash-set-insert s e))))))
      (run-timed "insert (new element)" iters
                 (lambda () (sycamore:hash-set-insert s -1))))))

;;; ===========================================================================
;;; Main
;;; ===========================================================================

(defun benchmark ()
  (format t "~%========================================~%")
  (format t "Collection Benchmarks (best of ~D runs)~%" *runs*)
  (format t "========================================~%")

  ;; --- Small (n=5), 100K iters ---
  (format t "~%=== SMALL (n=5), 100K iterations ===~%")

  (format t "~%-- Vector --")
  (bench-fset-seq 5 100000)

  (format t "~%-- Dict --")
  (bench-fset-map 5 100000)
  (bench-sycamore-treemap 5 100000)
  (bench-sycamore-hashmap 5 100000)

  (format t "~%-- Set --")
  (bench-fset-set 5 100000)
  (bench-sycamore-treeset 5 100000)
  (bench-sycamore-hashset 5 100000)

  ;; --- Large (n=2000), 1K iters (scaled down for feasibility) ---
  (format t "~%=== LARGE (n=2000), 1K iterations ===~%")

  (format t "~%-- Vector --")
  (bench-fset-seq 2000 1000)

  (format t "~%-- Dict --")
  (bench-fset-map 2000 1000)
  (bench-sycamore-treemap 2000 1000)
  (bench-sycamore-hashmap 2000 1000)

  (format t "~%-- Set --")
  (bench-fset-set 2000 1000)
  (bench-sycamore-treeset 2000 1000)
  (bench-sycamore-hashset 2000 1000)

  (format t "~%========================================~%")
  (format t "Done.~%"))

(benchmark)
