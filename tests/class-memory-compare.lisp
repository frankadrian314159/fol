;;; Class Instance Memory Comparison - CL vs FOL
;;; Compare memory for allocating N instances of a 5-slot class
(in-package :cl-user)

(defvar *cl-instances* nil "Hold CL instances to prevent GC")
(defvar *fol-instances* nil "Hold FOL instances to prevent GC")

(defun measure-allocation (thunk)
  "Measure bytes allocated by executing THUNK."
  (sb-ext:gc :full t)
  (let ((before (sb-ext:get-bytes-consed)))
    (funcall thunk)
    (- (sb-ext:get-bytes-consed) before)))

;;; CL class with 5 slots
(defclass cl-test-class ()
  ((a :initarg :a :initform 0)
   (b :initarg :b :initform 0)
   (c :initarg :c :initform 0)
   (d :initarg :d :initform 0)
   (e :initarg :e :initform 0)))

(defun compare-class-memory (n)
  "Compare memory for N instances of 5-slot class in CL vs FOL."
  (format t "~%=== ~:D instances of 5-slot class ===~%" n)

  ;; CL: standard CLOS instances
  (setf *cl-instances* nil)
  (let ((cl-alloc (measure-allocation
                   (lambda ()
                     (setf *cl-instances*
                           (loop for i below n
                                 collect (make-instance 'cl-test-class
                                                        :a i :b i :c i :d i :e i)))))))
    (format t "CL CLOS:          ~:D bytes (~,2F bytes/instance)~%"
            cl-alloc (/ (float cl-alloc) (max 1 n)))

    ;; FOL: persistent class instances using direct FSet persistent maps
    ;; This avoids FOL interpreter overhead and measures the actual persistent object cost
    (setf *fol-instances* nil)
    (let ((fol-alloc (measure-allocation
                      (lambda ()
                        (setf *fol-instances*
                              (loop for i below n
                                    collect (fset:map (:a i) (:b i) (:c i) (:d i) (:e i))))))))
      (format t "FSet map (5 keys): ~:D bytes (~,2F bytes/instance)~%"
              fol-alloc (/ (float fol-alloc) (max 1 n)))
      (format t "FSet/CL ratio:    ~,2Fx~%"
              (/ (float fol-alloc) (max 1.0 (float cl-alloc)))))))

(defun run-class-memory-tests ()
  (format t "~%=============================================~%")
  (format t "Object Instance Memory Comparison~%")
  (format t "CL CLOS class vs FSet persistent map~%")
  (format t "5 slots/keys (a, b, c, d, e)~%")
  (format t "=============================================~%")

  ;; Warmup
  (format t "~%Warming up...~%")
  (compare-class-memory 100)

  (format t "~%--- Actual measurements ---~%")
  (compare-class-memory 10000)
  (compare-class-memory 100000)
  (compare-class-memory 1000000)

  (format t "~%Done.~%"))

(run-class-memory-tests)
