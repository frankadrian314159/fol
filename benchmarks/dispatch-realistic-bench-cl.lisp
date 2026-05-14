;; Common Lisp version: realistic benchmark without dispatch caching
;; Data processing with pure COND dispatch (no caching)

(defun process-value (x)
  "6-clause dispatcher without caching"
  (cond
    ((< x -1000) (- (- x)))
    ((< x 0) (- x))
    ((= x 0) 0)
    ((< x 1000) (1+ x))
    ((< x 100000) (+ x 10))
    (t (* x 2))))

(defun run-realistic-bench ()
  "Process 1M values with dispatch"
  (loop for i from 0 below 1000000
        sum (process-value (- i 500000))))

(defun main ()
  (format t "~&CL Realistic Benchmark: Data Processing (NO CACHING)~%")
  (format t "====================================================~%")
  (let* ((start (get-internal-real-time))
         (result (run-realistic-bench))
         (end (get-internal-real-time))
         (elapsed (/ (- end start) 1000.0)))
    (format t "Iterations: 1M values~%")
    (format t "Result: ~D~%" result)
    (format t "Time: ~,1F ms~%" elapsed)))

(main)
(sb-ext:quit :unix-status 0)
