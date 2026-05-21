;;; Micro-benchmark: heterogeneous types (where caching helps)

;; Uncached dispatcher
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

;; Test data: repeating pattern of different types
(defun make-hetero-sequence (n)
  (loop for i from 0 below n
        collect (case (mod i 5)
                  (0 42)
                  (1 "hello")
                  (2 '(a b c))
                  (3 #(1 2 3))
                  (4 'symbol))))

;; Benchmarks
(defun bench-uncached-hetero (data)
  (let ((start (get-internal-real-time)))
    (loop for x in data
          count (dispatch-hetero-uncached x) into result
          finally (return (values result (/ (- (get-internal-real-time) start) 1000.0))))))

(defun bench-cached-hetero (data)
  (setf (dispatch-cache-entries %-hetero-cache) (make-array +cache-size+ :initial-element nil))
  (setf (dispatch-cache-next %-hetero-cache) 0)
  (setf %-cache-hits 0)
  (setf %-cache-misses 0)
  (let ((start (get-internal-real-time)))
    (loop for x in data
          count (dispatch-hetero-cached x) into result
          finally (return (values result (/ (- (get-internal-real-time) start) 1000.0))))))

;; Run benchmark
(format t "~&Micro-benchmark: Polymorphic Dispatch with Heterogeneous Types~%")
(format t "================================================================~%~%")

(let* ((n 1000000)
       (data (make-hetero-sequence n)))
  (format t "Running with ~D iterations (repeating 5-type cycle)...~%~%" n)

  (multiple-value-bind (result-u time-u) (bench-uncached-hetero data)
    (format t "UNCACHED (pure COND):~%")
    (format t "  Result: ~D calls~%" result-u)
    (format t "  Time: ~,1F ms~%" time-u)
    (format t "  Per-call: ~,6F µs~%~%" (/ time-u n)))

  (multiple-value-bind (result-c time-c) (bench-cached-hetero data)
    (let* ((total (+ %-cache-hits %-cache-misses))
           (hit-rate (* 100.0 (/ %-cache-hits total))))
      (format t "CACHED (with 8-slot ring buffer):~%")
      (format t "  Result: ~D calls~%" result-c)
      (format t "  Time: ~,1F ms~%" time-c)
      (format t "  Per-call: ~,6F µs~%" (/ time-c n))
      (format t "  Cache hits: ~D / ~D (~,2F%)~%" %-cache-hits total hit-rate)
      (format t "  Cache misses: ~D~%~%" %-cache-misses)))

  (let ((speedup (/ (bench-uncached-hetero data) (bench-cached-hetero data))))
    (format t "SPEEDUP: ~,2Fx faster with caching~%" speedup)))

(format t "~%Benchmark complete.~%")
(sb-ext:quit :unix-status 0)
