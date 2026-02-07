;;; Debug deep-size measurement
(in-package :cl-user)

(defun object-size (obj)
  (sb-ext:primitive-object-size obj))

(defun debug-deep-size (obj &optional (seen (make-hash-table :test 'eq)) (depth 0))
  "Return total bytes with debug output."
  (let ((indent (make-string (* depth 2) :initial-element #\Space)))
    (when (gethash obj seen)
      (format t "~A[already seen]~%" indent)
      (return-from debug-deep-size 0))
    (when (null obj)
      (return-from debug-deep-size 0))
    (setf (gethash obj seen) t)
    (let ((size (object-size obj)))
      (format t "~A~A: shallow=~D~%" indent (type-of obj) size)
      (typecase obj
        (fset::wb-seq
         (format t "~A  -> WB-SEQ branch, reducing over ~D elements~%" indent (fset:size obj))
         (let ((total (+ size (fset:reduce (lambda (acc v)
                                             (+ acc (debug-deep-size v seen (1+ depth))))
                                           obj :initial-value 0))))
           (format t "~A  -> WB-SEQ total: ~D~%" indent total)
           total))
        (fset:wb-map
         (format t "~A  -> WB-MAP branch~%" indent)
         (+ size (fset:reduce (lambda (acc k v)
                                (+ acc (debug-deep-size k seen (1+ depth))
                                   (debug-deep-size v seen (1+ depth))))
                              obj :initial-value 0)))
        (standard-object
         (format t "~A  -> STANDARD-OBJECT branch, slots:~%" indent)
         (+ size (loop for slot in (closer-mop:class-slots (class-of obj))
                       for name = (closer-mop:slot-definition-name slot)
                       when (slot-boundp obj name)
                       do (format t "~A    slot ~A~%" indent name)
                       sum (debug-deep-size (slot-value obj name) seen (1+ depth)))))
        (t size)))))

;; Test it
(let ((v (fol.collection:vec '(1 2 3))))
  (format t "~%=== Measuring FOL vector [1 2 3] ===~%")
  (let ((total (debug-deep-size v)))
    (format t "~%TOTAL: ~D bytes~%" total)))
