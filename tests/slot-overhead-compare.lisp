;;; Per-Slot Memory Overhead Comparison - CL vs FSet
;;; Compare memory overhead as number of slots varies
(in-package :cl-user)

(defvar *cl-instances* nil "Hold CL instances to prevent GC")
(defvar *fset-instances* nil "Hold FSet instances to prevent GC")

(defun measure-allocation (thunk)
  "Measure bytes allocated by executing THUNK."
  (sb-ext:gc :full t)
  (let ((before (sb-ext:get-bytes-consed)))
    (funcall thunk)
    (- (sb-ext:get-bytes-consed) before)))

;;; Generate slot names: aa, ab, ac, ...
(defun generate-slot-names (n)
  "Generate N slot names as 2-character symbols."
  (loop for i below n
        collect (intern (format nil "~C~C"
                                (code-char (+ (char-code #\A) (floor i 26)))
                                (code-char (+ (char-code #\A) (mod i 26)))))))

;;; Dynamically create a CLOS class with N slots
(defun make-cl-class-with-slots (n)
  "Create a CLOS class with N slots, return class name."
  (let* ((class-name (intern (format nil "TEST-CLASS-~D" n)))
         (slot-names (generate-slot-names n))
         (slot-defs (mapcar (lambda (name)
                              `(,name :initarg ,(intern (symbol-name name) :keyword)
                                      :initform 0))
                            slot-names)))
    (eval `(defclass ,class-name () ,slot-defs))
    (values class-name slot-names)))

;;; Create FSet map with N keys
(defun make-fset-map-with-keys (n slot-names value)
  "Create an FSet map with N keys, all set to VALUE."
  (let ((m (fset:empty-map)))
    (dolist (name slot-names)
      (setf m (fset:with m (intern (symbol-name name) :keyword) value)))
    m))

(defun compare-slot-overhead (num-slots num-instances)
  "Compare memory for NUM-INSTANCES objects with NUM-SLOTS slots each."
  (format t "~%=== ~D slots, ~:D instances ===~%" num-slots num-instances)

  ;; Create CL class and measure
  (multiple-value-bind (class-name slot-names)
      (make-cl-class-with-slots num-slots)
    (declare (ignore slot-names))

    ;; CL: standard CLOS instances
    (setf *cl-instances* nil)
    (let* ((initargs (loop for name in (generate-slot-names num-slots)
                           append (list (intern (symbol-name name) :keyword) 0)))
           (cl-alloc (measure-allocation
                      (lambda ()
                        (setf *cl-instances*
                              (loop for i below num-instances
                                    collect (apply #'make-instance class-name initargs)))))))
      (format t "CL CLOS:       ~:D bytes (~,1F bytes/instance, ~,1F bytes/slot)~%"
              cl-alloc
              (/ (float cl-alloc) (max 1 num-instances))
              (/ (float cl-alloc) (max 1 (* num-instances num-slots))))

      ;; FSet: persistent maps
      (setf *fset-instances* nil)
      (let* ((slot-names (generate-slot-names num-slots))
             (fset-alloc (measure-allocation
                          (lambda ()
                            (setf *fset-instances*
                                  (loop for i below num-instances
                                        collect (make-fset-map-with-keys num-slots slot-names 0)))))))
        (format t "FSet map:      ~:D bytes (~,1F bytes/instance, ~,1F bytes/slot)~%"
                fset-alloc
                (/ (float fset-alloc) (max 1 num-instances))
                (/ (float fset-alloc) (max 1 (* num-instances num-slots))))
        (format t "FSet/CL ratio: ~,2Fx~%"
                (/ (float fset-alloc) (max 1.0 (float cl-alloc))))))))

(defun run-slot-overhead-tests ()
  (format t "~%=============================================~%")
  (format t "Per-Slot Memory Overhead Comparison~%")
  (format t "CL CLOS class vs FSet persistent map~%")
  (format t "Slot names: AA, AB, AC, ... (2-char)~%")
  (format t "=============================================~%")

  ;; Warmup
  (format t "~%Warming up...~%")
  (compare-slot-overhead 2 100)

  (format t "~%--- Actual measurements (10,000 instances each) ---~%")
  (compare-slot-overhead 2 10000)
  (compare-slot-overhead 5 10000)
  (compare-slot-overhead 10 10000)
  (compare-slot-overhead 20 10000)
  (compare-slot-overhead 50 10000)
  (compare-slot-overhead 100 10000)

  (format t "~%Done.~%"))

(run-slot-overhead-tests)
