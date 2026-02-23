(let ((ql-path (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file ql-path)
      (load ql-path)
      (error "Quicklisp not found at ~A" ql-path)))

(defun safe-quickload (system)
  (ql:quickload system :silent t))

(safe-quickload :uuid)
(safe-quickload :fset)
(safe-quickload :sycamore)
(safe-quickload :cl-ppcre)
(safe-quickload :bordeaux-threads)
(safe-quickload :fiveam)
(safe-quickload :closer-mop)
(safe-quickload :usocket)

(load "src/package.lisp")
(load "src/collection-primitives.lisp")

(in-package :fol.compiler.collection-primitives)

(handler-case
    (progn
     (format t "Testing primitive vectors...~%")

     ;; Test f64
     (let ((v %empty-vec-f64))
       (dotimes (i 100)
         (setf v (%vec-f64-conj v (float i 1.0d0))))
       (assert (= (%vec-f64-count v) 100))
       (assert (= (%vec-f64-ref v 50) 50.0d0))
       (setf v (%vec-f64-assoc v 50 123.456d0))
       (assert (= (%vec-f64-ref v 50) 123.456d0))
       (format t "f64 tests passed.~%"))

     ;; Test fix64
     (let ((v %empty-vec-fix64))
       (dotimes (i 100)
         (setf v (%vec-fix64-conj v i)))
       (assert (= (%vec-fix64-count v) 100))
       (assert (= (%vec-fix64-ref v 50) 50))
       (setf v (%vec-fix64-assoc v 50 999))
       (assert (= (%vec-fix64-ref v 50) 999))
       (format t "fix64 tests passed.~%"))

     ;; Test T
     (let ((v %empty-vec-t))
       (dotimes (i 100)
         (setf v (%vec-t-conj v (format nil "item-~A" i))))
       (assert (= (%vec-t-count v) 100))
       (assert (string= (%vec-t-ref v 50) "item-50"))
       (format t "T tests passed.~%"))

     ;; Test large collections (forcing shift change)
     (let ((v %empty-vec-f64))
       (dotimes (i 2000)
         (setf v (%vec-f64-conj v (float i 1.0d0))))
       (assert (= (%vec-f64-count v) 2000))
       (dotimes (i 2000)
         (unless (= (%vec-f64-ref v i) (float i 1.0d0))
           (error "Mismatch at index ~A: expected ~A, got ~A" i (float i 1.0d0) (%vec-f64-ref v i))))
       (format t "Large f64 tests passed.~%"))

     (format t "All primitive tests passed!~%"))
  (error (e)
    (format t "TEST FAILED: ~A~%" e)
    (sb-ext:exit :code 1)))

(sb-ext:exit :code 0)
