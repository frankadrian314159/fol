;;; Heap-based memory comparison
;;; Measures actual heap allocation by forcing GC and comparing heap size
(in-package :cl-user)

(defun measure-allocation (thunk)
  "Measure bytes allocated by executing THUNK.
   Forces GC before and after to get accurate measurement."
  (sb-ext:gc :full t)
  (let ((before (sb-ext:get-bytes-consed)))
    (funcall thunk)
    (let ((after (sb-ext:get-bytes-consed)))
      (- after before))))

(defun compare-mutation-memory (n mutations)
  "Compare memory for in-place mutation vs persistent updates."
  (format t "~%=== Vector size=~D, mutations=~D ===~%" n mutations)

  ;; CL: in-place mutation (only one array exists)
  (let* ((cl-alloc (measure-allocation
                    (lambda ()
                      (let ((v (make-array n :initial-element 0)))
                        (dotimes (i mutations)
                          (setf (aref v (mod i n)) i))
                        v))))
         ;; FOL: persistent updates (new version each time, but only keep last)
         (env (fol.eval:make-standard-module))
         (fol-alloc (measure-allocation
                     (lambda ()
                       (let ((v (fol.repl:fol-test (format nil "(vec (range ~D))" n) env)))
                         (dotimes (i mutations)
                           (let* ((idx (mod i n))
                                  (update-env (fol.env:make-env env 'v v)))
                             (setf v (fol.repl:fol-test
                                      (format nil "(assoc v ~D ~D)" idx i)
                                      update-env))))
                         v)))))
    (format t "CL in-place:    ~:D bytes allocated~%" cl-alloc)
    (format t "FOL persistent: ~:D bytes allocated~%" fol-alloc)
    (format t "FOL/CL ratio:   ~,2Fx~%" (/ (float fol-alloc) (max 1.0 (float cl-alloc))))))

(defun run-heap-tests ()
  (format t "~%============================================~%")
  (format t "Heap Allocation: In-Place vs Persistent~%")
  (format t "============================================~%")

  (handler-case
      (progn
        (compare-mutation-memory 1000 10)
        (compare-mutation-memory 1000 100)
        (compare-mutation-memory 1000 1000)
        (compare-mutation-memory 1000 10000))
    (error (e)
      (format t "~%Error: ~A~%" e)))

  (format t "~%Done.~%"))

(run-heap-tests)
