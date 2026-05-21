;;; Micro-benchmark: homogeneous types (CCL version)
;;; All dispatches on fixnum only

(defun dispatch-homo-uncached (x)
  "6-clause dispatcher WITHOUT caching (homogeneous fixnum)"
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
(defvar %-homo-cache (make-dispatch-cache))
(defvar %-cache-hits 0)
(defvar %-cache-misses 0)

;; Cached dispatcher
(defun dispatch-homo-cached (x)
  "6-clause dispatcher WITH caching"
  (let* ((key (class-of x))
         (hit (cache-lookup %-homo-cache key)))
    (if hit
        (progn (incf %-cache-hits) (funcall hit x))
        (progn
          (incf %-cache-misses)
          (cond
            ((typep x 'fixnum)
             (cache-insert! %-homo-cache key #'%-clause-fixnum)
             (%-clause-fixnum x))
            ((stringp x)
             (cache-insert! %-homo-cache key #'%-clause-string)
             (%-clause-string x))
            ((listp x)
             (cache-insert! %-homo-cache key #'%-clause-list)
             (%-clause-list x))
            ((vectorp x)
             (cache-insert! %-homo-cache key #'%-clause-vector)
             (%-clause-vector x))
            ((symbolp x)
             (cache-insert! %-homo-cache key #'%-clause-symbol)
             (%-clause-symbol x))
            (t
             (cache-insert! %-homo-cache key #'%-clause-other)
             (%-clause-other x)))))))

;; Test data: 200,000 fixnum-only calls
(defvar *test-data*
  (let ((data nil))
    (dotimes (i 200000)
      (push (random 1000000) data))
    (reverse data)))

;; Benchmark functions
(defun benchmark-uncached (&optional (iterations 3))
  "Benchmark uncached dispatch"
  (let ((times nil))
    (dotimes (run iterations)
      (let ((result 0))
        (time
         (dotimes (i (length *test-data*))
           (incf result (if (dispatch-homo-uncached (nth i *test-data*)) 1 0))))
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
           (incf result (if (dispatch-homo-cached (nth i *test-data*)) 1 0))))
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
  (format t "~&=== CCL Homogeneous Dispatch Micro-Benchmark ===~%")
  (format t "Implementation: ~A ~A~%" (lisp-implementation-type) (lisp-implementation-version))
  (format t "Test data: 200,000 fixnum-only calls~%~%")

  (format t "Warming up...~%")
  (dotimes (i 10000)
    (dispatch-homo-uncached (nth (mod i (length *test-data*)) *test-data*)))
  (dotimes (i 10000)
    (setf %-cache-hits 0 %-cache-misses 0)
    (dispatch-homo-cached (nth (mod i (length *test-data*)) *test-data*)))

  (format t "~&=== Uncached COND Dispatch (3 iterations) ===~%")
  (benchmark-uncached 3)

  (format t "~&=== Cached Dispatch (3 iterations) ===~%")
  (benchmark-cached 3))

;; Run if invoked directly
(run-all-benchmarks)
(quit)
