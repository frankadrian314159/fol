;;; Debug vector types
(in-package :cl-user)

(let ((v (fol.collection:vec '(1 2 3 4 5))))
  (format t "~%Vec type: ~A~%" (type-of v))
  (format t "Slots:~%")
  (loop for slot in (closer-mop:class-slots (class-of v))
        for name = (closer-mop:slot-definition-name slot)
        when (slot-boundp v name)
        do (format t "  ~A: ~A~%" name (type-of (slot-value v name))))
  (let ((items (slot-value v 'fol.collection::items)))
    (format t "~%Items is wb-seq?: ~A~%" (typep items 'fset::wb-seq))
    (format t "Items size: ~A~%" (fset:size items))))
