;;; Micro-benchmark: heterogeneous types (CCL version)
;;; Compares SBCL dispatch caching results against CCL

(defun dispatch-hetero-uncached (x)
  "6-clause dispatcher WITHOUT caching"
  (cond
    ((typep x 'fixnum) (list :fixnum x))
    ((stringp x) (list :string (length x)))
    ((listp x) (list :list (length x)))
    ((vectorp x) (list :vector (length x)))
    ((symbolp x) (list :symbol x))
    (t (list :other x))))

;; Cache structure
(defconstant +cache-size+ 8)

(defstruct dispatch-cache
  (entries (make-array +cache-size+ :initial-element nil) :type simple-vector)
  (next 0 :type fixnum))

(defun cache-lookup (cache key)
  (loop for entry across (dispatch-cache-entries cache)
        when (and entry (eq (car entry) key))
        return (cdr entry)))

(defun cache-insert! (cache key fn)
  (let* ((entries (dispatch-cache-entries cache))
         (pos (dispatch-cache-next cache)))
    (setf (aref entries pos) (cons key fn)
          (dispatch-cache-next cache) (mod (1+ pos) +cache-size+))))

;; Clause functions
(defun %-clause-fixnum (x) (list :fixnum x))
(defun %-clause-string (x) (list :string (length x)))
(defun %-clause-list (x) (list :list (length x)))
(defun %-clause-vector (x) (list :vector (length x)))
(defun %-clause-symbol (x) (list :symbol x))
(defun %-clause-other (x) (list :other x))

;; Cache variable
(defvar %-hetero-cache (make-dispatch-cache))
(defvar %-cache-hits 0)
(defvar %-cache-misses 0)

;; Cached dispatcher
(defun dispatch-hetero-cached (x)
  "6-clause dispatcher WITH caching"
  (let* ((key (class-of x))
         (hit (cache-lookup %-hetero-cache key)))
    (if hit
        (progn (incf %-cache-hits) (funcall hit x))
        (progn
          (incf %-cache-misses)
          (cond
            ((typep x 'fixnum)
             (cache-insert! %-hetero-cache key #'%-clause-fixnum)
             (%-clause-fixnum x))
            ((stringp x)
             (cache-insert! %-hetero-cache key #'%-clause-string)
             (%-clause-string x))
            ((listp x)
             (cache-insert! %-hetero-cache key #'%-clause-list)
             (%-clause-list x))
            ((vectorp x)
             (cache-insert! %-hetero-cache key #'%-clause-vector)
             (%-clause-vector x))
            ((symbolp x)
             (cache-insert! %-hetero-cache key #'%-clause-symbol)
             (%-clause-symbol x))
            (t
             (cache-insert! %-hetero-cache key #'%-clause-other)
             (%-clause-other x)))))))

;; Test data: 200,000 calls with 5-type repeating cycle
(defvar *test-data*
  (let ((data nil))
    (dotimes (i 200000)
      (push (case (mod i 5)
              (0 (random 1000000))           ; fixnum
              (1 "test string")              ; string
              (2 '(a b c d e))               ; list
              (3 #(1 2 3 4 5))               ; vector
              (4 'symbol))                   ; symbol
            data))
    (reverse data)))

;; Benchmark functions
(defun benchmark-uncached (&optional (iterations 3))
  "Benchmark uncached dispatch"
  (let ((times nil))
    (dotimes (run iterations)
      (let ((result 0))
        (time
         (dotimes (i (length *test-data*))
           (incf result (if (dispatch-hetero-uncached (nth i *test-data*)) 1 0))))
        (push result times)))
    (format t "~&Uncached Dispatch Results:~%")
    (format t "  Runs: ~D~%" iterations)
    (format t "  Total calls per run: ~D~%" (length *test-data*))
    times))

(defun benchmark-cached (&optional (iterations 3))
  "Benchmark cached dispatch"
  (let ((times nil))
    (dotimes (run iterations)
      (setf %-cache-hits 0 %-cache-misses 0)
      (let ((result 0))
        (time
         (dotimes (i (length *test-data*))
           (incf result (if (dispatch-hetero-cached (nth i *test-data*)) 1 0))))
        (push result times)))
    (format t "~&Cached Dispatch Results:~%")
    (format t "  Runs: ~D~%" iterations)
    (format t "  Total calls per run: ~D~%" (length *test-data*))
    (format t "  Cache hits: ~D~%" %-cache-hits)
    (format t "  Cache misses: ~D~%" %-cache-misses)
    (format t "  Hit rate: ~,4F%~%" (* 100.0 (/ %-cache-hits (+ %-cache-hits %-cache-misses))))
    times))

(defun run-all-benchmarks ()
  "Run all benchmarks"
  (format t "~&=== CCL Dispatch Caching Micro-Benchmark ===~%")
  (format t "Implementation: ~A ~A~%" (lisp-implementation-type) (lisp-implementation-version))
  (format t "Test data: 200,000 calls over repeating 5-type cycle~%")
  (format t "  Type cycle: fixnum -> string -> list -> vector -> symbol~%~%")

  (format t "Warming up...~%")
  (dotimes (i 10000)
    (dispatch-hetero-uncached (nth (mod i (length *test-data*)) *test-data*)))
  (dotimes (i 10000)
    (setf %-cache-hits 0 %-cache-misses 0)
    (dispatch-hetero-cached (nth (mod i (length *test-data*)) *test-data*)))

  (format t "~&=== Uncached COND Dispatch (3 iterations) ===~%")
  (benchmark-uncached 3)

  (format t "~&=== Cached Dispatch (3 iterations) ===~%")
  (benchmark-cached 3))

;; Run if invoked directly
(run-all-benchmarks)
;(quit)
;;; Optimized Benchmark using ELT instead of NTH for performance
(defun benchmark-optimized-uncached (&optional (iterations 3))
  "Benchmark uncached dispatch using a vector for faster access"
  (let* ((data-vec (coerce *test-data* 'vector))
         (len (length data-vec)))
    (format t "~&=== Optimized Uncached (Vector Access) ===~%")
    (dotimes (run iterations)
      (time
       (dotimes (i len)
         (dispatch-hetero-uncached (aref data-vec i)))))))

(defun benchmark-optimized-cached (&optional (iterations 3))
  "Benchmark cached dispatch using a vector for faster access"
  (let* ((data-vec (coerce *test-data* 'vector))
         (len (length data-vec)))
    (format t "~&=== Optimized Cached (Vector Access) ===~%")
    (dotimes (run iterations)
      (setf %-cache-hits 0 %-cache-misses 0)
      (time
       (dotimes (i len)
         (dispatch-hetero-cached (aref data-vec i)))))))

(run-all-benchmarks)
(benchmark-optimized-uncached 3)
(benchmark-optimized-cached 3)