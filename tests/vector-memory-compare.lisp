;;; Vector Memory Comparison - CL Array vs FSet Seq
;;; Compare storage for vectors of size N with element i = i
(in-package :cl-user)

(defvar *cl-vec* nil "Hold CL vector to prevent GC")
(defvar *fset-vec* nil "Hold FSet seq to prevent GC")

(defun measure-allocation (thunk)
  "Measure bytes allocated by executing THUNK."
  (sb-ext:gc :full t)
  (let ((before (sb-ext:get-bytes-consed)))
    (funcall thunk)
    (- (sb-ext:get-bytes-consed) before)))

(defun compare-vector-memory (n)
  "Compare memory for CL array vs FSet seq of size N, elements = indices."
  (format t "~%=== Vector size=~D, element[i] = i ===~%" n)

  ;; CL: simple array with fixnums
  (setf *cl-vec* nil)
  (let ((cl-alloc (measure-allocation
                   (lambda ()
                     (setf *cl-vec* (make-array n :initial-contents
                                                (loop for i below n collect i)))))))
    (format t "CL array:         ~:D bytes~%" cl-alloc)

    ;; FSet: persistent seq
    (setf *fset-vec* nil)
    (let ((fset-alloc (measure-allocation
                       (lambda ()
                         (setf *fset-vec* (fset:convert 'fset:seq
                                            (loop for i below n collect i)))))))
      (format t "FSet seq:         ~:D bytes~%" fset-alloc)
      (format t "FSet/CL ratio:    ~,2Fx~%" (/ (float fset-alloc) (max 1.0 (float cl-alloc)))))))

(defun run-vector-memory-tests ()
  (format t "~%=============================================~%")
  (format t "Vector Memory Comparison: CL Array vs FSet Seq~%")
  (format t "Element[i] = i (integer values)~%")
  (format t "=============================================~%")

  ;; Warmup - run once to initialize FSet internals
  (format t "~%Warming up...~%")
  (compare-vector-memory 10)
  (compare-vector-memory 100)

  (format t "~%--- Actual measurements ---~%")
  (compare-vector-memory 1000)
  (compare-vector-memory 10000)
  (compare-vector-memory 100000)
  (compare-vector-memory 1000000)
  (compare-vector-memory 10000000)

  (format t "~%Done.~%"))

(run-vector-memory-tests)
