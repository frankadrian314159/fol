;; Common Lisp version: micro-benchmark without dispatch caching
;; Hand-written COND dispatch (no caching) for comparison

(defun dispatch-sum (x)
  "6-clause dispatcher without caching - pure COND evaluation"
  (cond
    ((< x 0) (- x))
    ((= x 0) 0)
    ((< x 1000) (1+ x))
    ((< x 10000) (+ x 1))
    ((< x 100000) (+ x 2))
    (t (+ x 3))))

(defun run-micro-bench (n-iterations)
  "Reduce over n integers using polymorphic dispatcher"
  (let ((data (coerce (loop for i from 0 below n-iterations collect i) 'vector)))
    (loop for i from 0 below n-iterations
          sum (dispatch-sum (aref data i)))))

(defun main ()
  (format t "~&CL Micro-benchmark: Polymorphic Dispatch (NO CACHING)~%")
  (format t "=====================================================~%")
  (let* ((n 1000000)
         (start (get-internal-real-time))
         (result (run-micro-bench n))
         (end (get-internal-real-time))
         (elapsed (/ (- end start) 1000.0)))  ;; Convert to ms
    (format t "Iterations: ~D~%" n)
    (format t "Result: ~D~%" result)
    (format t "Time: ~,1F ms~%" elapsed)
    (format t "Per-call: ~,6F µs~%" (/ elapsed n))))

(main)
(sb-ext:quit :unix-status 0)
