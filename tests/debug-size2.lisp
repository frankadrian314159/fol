;;; Debug deep-size measurement for larger vectors
(in-package :cl-user)

(defun object-size (obj)
  (sb-ext:primitive-object-size obj))

(defun deep-size (obj &optional (seen (make-hash-table :test 'eq)))
  "Return total bytes."
  (when (or (null obj) (gethash obj seen))
    (return-from deep-size 0))
  (setf (gethash obj seen) t)
  (let ((size (object-size obj)))
    (typecase obj
      (fset::wb-seq
       (+ size (fset:reduce (lambda (acc v)
                              (+ acc (deep-size v seen)))
                            obj :initial-value 0)))
      (fset:wb-map
       (+ size (fset:reduce (lambda (acc k v)
                              (+ acc (deep-size k seen)
                                 (deep-size v seen)))
                            obj :initial-value 0)))
      (fset:wb-set
       (+ size (fset:reduce (lambda (acc v) (+ acc (deep-size v seen)))
                            obj :initial-value 0)))
      (cons
       (+ size (deep-size (car obj) seen) (deep-size (cdr obj) seen)))
      (array
       (+ size (loop for i below (array-total-size obj)
                     sum (deep-size (row-major-aref obj i) seen))))
      (standard-object
       (+ size (loop for slot in (closer-mop:class-slots (class-of obj))
                     for name = (closer-mop:slot-definition-name slot)
                     when (slot-boundp obj name)
                     sum (deep-size (slot-value obj name) seen))))
      (t size))))

;; Compare sizes
(format t "~%=== Size Comparison ===~%")

;; CL array with 1000 elements
(let ((cl-arr (make-array 1000 :initial-element 0)))
  (format t "CL array (1000 elements): ~:D bytes~%" (deep-size cl-arr)))

;; FOL vector with 1000 elements
(let ((fol-vec (fol.collection:vec (loop for i below 1000 collect i))))
  (format t "FOL vector (1000 elements): ~:D bytes~%" (deep-size fol-vec)))

;; Raw FSet seq with 1000 elements
(let ((fset-seq (fset:convert 'fset:seq (loop for i below 1000 collect i))))
  (format t "Raw FSet seq (1000 elements): ~:D bytes~%" (deep-size fset-seq)))
