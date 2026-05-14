;; FOL version with dispatch caching optimizations for realistic benchmark

(defconstant +cache-size+ 8)

(defstruct dispatch-cache
  (entries (make-array +cache-size+ :initial-element nil) :type simple-vector)
  (next 0 :type fixnum))

(defun make-dispatch-cache () (make-dispatch-cache))

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

;; Private clause functions
(defun %-process-value-clause-0 (x)
  (- (- x)))

(defun %-process-value-clause-1 (x)
  (- x))

(defun %-process-value-clause-2 (x)
  0)

(defun %-process-value-clause-3 (x)
  (1+ x))

(defun %-process-value-clause-4 (x)
  (+ x 10))

(defun %-process-value-clause-5 (x)
  (* x 2))

;; Cache variable
(defvar %-process-value-cache (make-dispatch-cache))

;; Cached dispatcher
(defun process-value-cached (x)
  "6-clause dispatcher WITH caching"
  (let* ((key (list (type-of x)))
         (hit (cache-lookup %-process-value-cache key)))
    (if hit
        (funcall hit x)
        (cond
          ((< x -1000)
           (cache-insert! %-process-value-cache key #'%-process-value-clause-0)
           (%-process-value-clause-0 x))
          ((< x 0)
           (cache-insert! %-process-value-cache key #'%-process-value-clause-1)
           (%-process-value-clause-1 x))
          ((= x 0)
           (cache-insert! %-process-value-cache key #'%-process-value-clause-2)
           (%-process-value-clause-2 x))
          ((< x 1000)
           (cache-insert! %-process-value-cache key #'%-process-value-clause-3)
           (%-process-value-clause-3 x))
          ((< x 100000)
           (cache-insert! %-process-value-cache key #'%-process-value-clause-4)
           (%-process-value-clause-4 x))
          (t
           (cache-insert! %-process-value-cache key #'%-process-value-clause-5)
           (%-process-value-clause-5 x))))))

(defun run-realistic-bench-cached ()
  "Process 1M values with cached dispatch"
  (loop for i from 0 below 1000000
        sum (process-value-cached (- i 500000))))

(defun main ()
  (format t "~&FOL Realistic Benchmark: Data Processing (WITH CACHING)~%")
  (format t "======================================================~%")
  (let* ((start (get-internal-real-time))
         (result (run-realistic-bench-cached))
         (end (get-internal-real-time))
         (elapsed (/ (- end start) 1000.0)))
    (format t "Iterations: 1M values~%")
    (format t "Result: ~D~%" result)
    (format t "Time: ~,1F ms~%" elapsed)))

(main)
(sb-ext:quit :unix-status 0)
