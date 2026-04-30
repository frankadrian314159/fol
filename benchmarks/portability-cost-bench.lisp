;;; benchmarks/portability-cost-bench.lisp
(require :asdf)
(pushnew (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(in-package :cl-user)

(defclass <standard-dev> ()
  ((x :initarg :x :initform 0)))

(defclass <persistent-dev> (fol.compiler.persistent:<persistent-object>)
  ((x :initarg :x :initform 0))
  (:metaclass fol.compiler.persistent:persistent-class))

;; Force a "truly portable" (non-optimized) path by overriding SVUC
(defclass <portable-class> (fol.compiler.persistent:persistent-class) ())
(defmethod closer-mop:slot-value-using-class ((class <portable-class>) obj slot-def)
  (closer-mop:standard-instance-access obj (closer-mop:slot-definition-location slot-def)))

(defclass <portable-dev> (fol.compiler.persistent:<persistent-object>)
  ((x :initarg :x :initform 0))
  (:metaclass <portable-class>))

(declaim (notinline bench-read))
(defun bench-read (obj n)
  (declare (optimize (speed 3) (safety 0)))
  (let ((sum 0))
    (declare (fixnum sum))
    (dotimes (i n)
      (setf sum (slot-value obj 'x)))
    sum))

(defun run-bench ()
  (let ((s-obj (make-instance '<standard-dev> :x 42))
        (p-obj (make-instance '<persistent-dev> :x 42))
        (port-obj (make-instance '<portable-dev> :x 42))
        (n 10000000))
    
    (closer-mop:finalize-inheritance (find-class '<standard-dev>))
    (closer-mop:finalize-inheritance (find-class '<persistent-dev>))
    (closer-mop:finalize-inheritance (find-class '<portable-dev>))
    
    (format t "~%Portability vs. Performance (~D iterations)~%" n)
    
    (format t "1. Native CLOS (standard-class):~%")
    (time (bench-read s-obj n))
    
    (format t "~%2. Native FOL (SBCL optimized fast-path):~%")
    (time (bench-read p-obj n))
    
    (format t "~%3. Portable FOL (forced slot-value-using-class):~%")
    (time (bench-read port-obj n))))

(run-bench)
(sb-ext:exit)
