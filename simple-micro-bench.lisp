;;; Simple micro-benchmark: cached vs uncached dispatch

;; Uncached dispatcher
(defun dispatch-sum-uncached (x)
  "6-clause dispatcher WITHOUT caching"
  (cond
    ((< x 0) (- x))
    ((= x 0) 0)
    ((< x 1000) (1+ x))
    ((< x 10000) (+ x 1))
    ((< x 100000) (+ x 2))
    (t (+ x 3))))

;; Cache structure
(defconstant +cache-size+ 8)

(defstruct dispatch-cache
  (entries (make-array +cache-size+ :initial-element nil) :type simple-vector)
  (next 0 :type fixnum))

(defun cache-lookup (cache key)
  "Linear search for type signature in cache"
  (loop for entry across (dispatch-cache-entries cache)
        when (and entry (equal (car entry) key))
        return (cdr entry)))

(defun cache-insert! (cache key fn)
  "Insert into ring-buffer cache"
  (let* ((entries (dispatch-cache-entries cache))
         (pos (dispatch-cache-next cache)))
    (setf (aref entries pos) (cons key fn)
          (dispatch-cache-next cache) (mod (1+ pos) +cache-size+))))

;; Clause functions for cached version
(defun %-clause-0 (x) (- x))
(defun %-clause-1 (x) 0)
(defun %-clause-2 (x) (1+ x))
(defun %-clause-3 (x) (+ x 1))
(defun %-clause-4 (x) (+ x 2))
(defun %-clause-5 (x) (+ x 3))

;; Cache variable
(defvar %-cache (make-dispatch-cache))

;; Cached dispatcher
(defun dispatch-sum-cached (x)
  "6-clause dispatcher WITH caching"
  (let* ((key (list (type-of x)))
         (hit (cache-lookup %-cache key)))
    (if hit
        (funcall hit x)
        (cond
          ((< x 0)
           (cache-insert! %-cache key #'%-clause-0)
           (%-clause-0 x))
          ((= x 0)
           (cache-insert! %-cache key #'%-clause-1)
           (%-clause-1 x))
          ((< x 1000)
           (cache-insert! %-cache key #'%-clause-2)
           (%-clause-2 x))
          ((< x 10000)
           (cache-insert! %-cache key #'%-clause-3)
           (%-clause-3 x))
          ((< x 100000)
           (cache-insert! %-cache key #'%-clause-4)
           (%-clause-4 x))
          (t
           (cache-insert! %-cache key #'%-clause-5)
           (%-clause-5 x))))))

;; Benchmarks
(defun bench-uncached (n)
  (let ((start (get-internal-real-time)))
    (loop for i from 0 below n
          sum (dispatch-sum-uncached i) into result
          finally (return (values result (/ (- (get-internal-real-time) start) 1000.0))))))

(defun bench-cached (n)
  (setf (dispatch-cache-entries %-cache) (make-array +cache-size+ :initial-element nil))
  (setf (dispatch-cache-next %-cache) 0)
  (let ((start (get-internal-real-time)))
    (loop for i from 0 below n
          sum (dispatch-sum-cached i) into result
          finally (return (values result (/ (- (get-internal-real-time) start) 1000.0))))))

;; Run benchmarks
(format t "~&Micro-benchmark: Polymorphic Dispatch Caching~%")
(format t "===============================================~%~%")

(let ((n 1000000))
  (format t "Running with ~D iterations...~%~%" n)

  (multiple-value-bind (result-u time-u) (bench-uncached n)
    (format t "UNCACHED (pure COND):~%")
    (format t "  Result: ~D~%" result-u)
    (format t "  Time: ~,1F ms~%" time-u)
    (format t "  Per-call: ~,6F µs~%~%" (/ time-u n)))

  (multiple-value-bind (result-c time-c) (bench-cached n)
    (format t "CACHED (with 8-slot ring buffer):~%")
    (format t "  Result: ~D~%" result-c)
    (format t "  Time: ~,1F ms~%" time-c)
    (format t "  Per-call: ~,6F µs~%~%" (/ time-c n)))

  (multiple-value-bind (result-u time-u) (bench-uncached n)
    (multiple-value-bind (result-c time-c) (bench-cached n)
      (let ((speedup (/ time-u time-c)))
        (format t "SPEEDUP: ~,2Fx faster with caching~%" speedup)))))

(format t "~%Benchmark complete.~%")
(sb-ext:quit :unix-status 0)
