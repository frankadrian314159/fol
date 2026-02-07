;;; Fair memory comparison - Direct FSet vs CL arrays
;;; Avoids interpreter overhead by using FSet directly
(in-package :cl-user)

(defun measure-allocation (thunk)
  "Measure bytes allocated by executing THUNK."
  (sb-ext:gc :full t)
  (let ((before (sb-ext:get-bytes-consed)))
    (funcall thunk)
    (- (sb-ext:get-bytes-consed) before)))

(defvar *result* nil "Hold result to prevent optimization")

(defun compare-direct (n mutations)
  "Compare CL array mutations vs FSet seq updates directly."
  (format t "~%=== Vector size=~D, mutations=~D ===~%" n mutations)

  ;; CL: in-place mutation (use floats to force heap allocation)
  (let ((cl-alloc (measure-allocation
                   (lambda ()
                     (let ((v (make-array n :element-type 'double-float
                                          :initial-element 0.0d0)))
                       (dotimes (i mutations)
                         (setf (aref v (mod i n)) (float i 1.0d0)))
                       (setf *result* v))))))
    (format t "CL in-place:      ~:D bytes~%" cl-alloc)

    ;; FSet: persistent updates (direct, no interpreter)
    (let ((fset-alloc (measure-allocation
                       (lambda ()
                         (let ((v (fset:convert 'fset:seq (loop for i below n collect (float i 1.0d0)))))
                           (dotimes (i mutations)
                             (setf v (fset:with v (mod i n) (float i 1.0d0))))
                           (setf *result* v))))))
      (format t "FSet persistent:  ~:D bytes~%" fset-alloc)
      (format t "FSet/CL ratio:    ~,2Fx~%" (/ (float fset-alloc) (max 1.0 (float cl-alloc)))))))

(defun run-direct-tests ()
  (format t "~%=============================================~%")
  (format t "Direct Comparison: CL Array vs FSet Seq~%")
  (format t "(No interpreter overhead)~%")
  (format t "=============================================~%")

  (compare-direct 1000 10)
  (compare-direct 1000 100)
  (compare-direct 1000 1000)
  (compare-direct 1000 10000)

  (format t "~%Done.~%"))

(run-direct-tests)
