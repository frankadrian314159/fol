;; FOL version with dispatch caching optimizations
;; Simulates the cache that FOL compiler generates for multi-clause defn

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
(defun %-dispatch-sum-clause-0 (x)
  (- x))

(defun %-dispatch-sum-clause-1 (x)
  0)

(defun %-dispatch-sum-clause-2 (x)
  (1+ x))

(defun %-dispatch-sum-clause-3 (x)
  (+ x 1))

(defun %-dispatch-sum-clause-4 (x)
  (+ x 2))

(defun %-dispatch-sum-clause-5 (x)
  (+ x 3))

;; Cache variable
(defvar %-dispatch-sum-cache (make-dispatch-cache))

;; Cached dispatcher
(defun dispatch-sum-cached (x)
  "6-clause dispatcher WITH caching"
  (let* ((key (list (type-of x)))
         (hit (cache-lookup %-dispatch-sum-cache key)))
    (if hit
        (funcall hit x)
        (cond
          ((< x 0)
           (cache-insert! %-dispatch-sum-cache key #'%-dispatch-sum-clause-0)
           (%-dispatch-sum-clause-0 x))
          ((= x 0)
           (cache-insert! %-dispatch-sum-cache key #'%-dispatch-sum-clause-1)
           (%-dispatch-sum-clause-1 x))
          ((< x 1000)
           (cache-insert! %-dispatch-sum-cache key #'%-dispatch-sum-clause-2)
           (%-dispatch-sum-clause-2 x))
          ((< x 10000)
           (cache-insert! %-dispatch-sum-cache key #'%-dispatch-sum-clause-3)
           (%-dispatch-sum-clause-3 x))
          ((< x 100000)
           (cache-insert! %-dispatch-sum-cache key #'%-dispatch-sum-clause-4)
           (%-dispatch-sum-clause-4 x))
          (t
           (cache-insert! %-dispatch-sum-cache key #'%-dispatch-sum-clause-5)
           (%-dispatch-sum-clause-5 x))))))

(defun run-micro-bench-cached (n-iterations)
  "Reduce over n integers using cached polymorphic dispatcher"
  (loop for i from 0 below n-iterations
        sum (dispatch-sum-cached i)))

(defun main ()
  (format t "~&FOL Micro-benchmark: Polymorphic Dispatch (WITH CACHING)~%")
  (format t "========================================================~%")
  (let* ((n 1000000)
         (start (get-internal-real-time))
         (result (run-micro-bench-cached n))
         (end (get-internal-real-time))
         (elapsed (/ (- end start) 1000.0)))
    (format t "Iterations: ~D~%" n)
    (format t "Result: ~D~%" result)
    (format t "Time: ~,1F ms~%" elapsed)
    (format t "Per-call: ~,6F µs~%" (/ elapsed n))))

(main)
(sb-ext:quit :unix-status 0)
