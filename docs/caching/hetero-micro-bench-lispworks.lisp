;;; Micro-benchmark: heterogeneous types (LispWorks version)
;;; Interactive benchmark for LispWorks Personal Edition IDE
;;;
;;; Instructions:
;;; 1. Select all code in the editor (Ctrl+A)
;;; 2. Evaluate the buffer (Ctrl+E)
;;; 3. In the REPL, type: (RUN-ALL-BENCHMARKS)
;;; 4. Copy results from the output pane into your notes

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
      (let ((result 0)
            (start-time (get-internal-run-time)))
        (dotimes (i (length *test-data*))
          (incf result (if (dispatch-hetero-uncached (nth i *test-data*)) 1 0)))
        (let ((elapsed (- (get-internal-run-time) start-time)))
          (format t "~&  Run ~D: ~,3F seconds~%" (1+ run) (/ elapsed internal-time-units-per-second))
          (push result times))))
    (format t "~&Uncached Dispatch Results:~%")
    (format t "  Iterations: ~D~%" iterations)
    (format t "  Total calls per iteration: ~D~%" (length *test-data*))
    times))

(defun benchmark-cached (&optional (iterations 3))
  "Benchmark cached dispatch"
  (let ((times nil))
    (dotimes (run iterations)
      (setf %-cache-hits 0 %-cache-misses 0)
      (let ((result 0)
            (start-time (get-internal-run-time)))
        (dotimes (i (length *test-data*))
          (incf result (if (dispatch-hetero-cached (nth i *test-data*)) 1 0)))
        (let ((elapsed (- (get-internal-run-time) start-time)))
          (format t "~&  Run ~D: ~,3F seconds~%" (1+ run) (/ elapsed internal-time-units-per-second))
          (push result times))))
    (format t "~&Cached Dispatch Results:~%")
    (format t "  Iterations: ~D~%" iterations)
    (format t "  Total calls per iteration: ~D~%" (length *test-data*))
    (format t "  Cache hits: ~D~%" %-cache-hits)
    (format t "  Cache misses: ~D~%" %-cache-misses)
    (format t "  Hit rate: ~,4F%~%" (* 100.0 (/ %-cache-hits (+ %-cache-hits %-cache-misses))))
    times))

(defun run-all-benchmarks ()
  "Run all benchmarks - MAIN ENTRY POINT"
  (format t "~&~%================================~%")
  (format t "LispWorks Heterogeneous Dispatch Caching Micro-Benchmark~%")
  (format t "================================~%")
  (format t "Implementation: ~A ~A~%" (lisp-implementation-type) (lisp-implementation-version))
  (format t "Test data: 200,000 calls over repeating 5-type cycle~%")
  (format t "  Type cycle: fixnum -> string -> list -> vector -> symbol~%~%")

  (format t "Warming up JIT compiler (10,000 calls)...~%")
  (dotimes (i 10000)
    (dispatch-hetero-uncached (nth (mod i (length *test-data*)) *test-data*)))
  (dotimes (i 10000)
    (setf %-cache-hits 0 %-cache-misses 0)
    (dispatch-hetero-cached (nth (mod i (length *test-data*)) *test-data*)))
  (format t "Warmup complete.~%~%")

  (format t "=== Uncached COND Dispatch (3 iterations) ===~%")
  (benchmark-uncached 3)

  (format t "~&=== Cached Dispatch (3 iterations) ===~%")
  (benchmark-cached 3)

  (format t "~&================================~%")
  (format t "Benchmark Complete~%")
  (format t "================================~%"))

;; Print instructions
(format t "~&~%LispWorks Dispatch Caching Benchmark~%")
(format t "====================================~%")
(format t "To run the benchmark, type: (RUN-ALL-BENCHMARKS)~%")
(format t "~%")
