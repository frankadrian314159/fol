(let ((ql-path (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file ql-path)
      (load ql-path)
      (error "Quicklisp not found at ~A" ql-path)))

(push (merge-pathnames "src/" (uiop:getcwd)) asdf:*central-registry*)

(defun safe-quickload (system)
  (format t "Quickloading ~A...~%" system)
  (ql:quickload system :silent t))

(safe-quickload :sycamore)
(safe-quickload :cl-ppcre)
(safe-quickload :uuid)
(safe-quickload :bordeaux-threads)
(safe-quickload :fiveam)
(safe-quickload :closer-mop)
(safe-quickload :usocket)

(asdf:load-system :fol-compiler)

(in-package :cl-user)

(defpackage fol.benchmarks.vector
  (:use :cl)
  (:shadowing-import-from :fol.compiler.collection-functions
                          vector set list list* nth push pop
                          dict bag deque ordered-dict ordered-set sorted-set sorted-dict
                          int-set int-dict priority-dict dense-int-set
                          array
                          first rest get assoc count merge
                          find subseq
                          union intersection
                          size conj)
  (:import-from :fol.compiler.collections collection-ref collection-assoc))

(in-package :fol.benchmarks.vector)

(defun get-time ()
  (/ (get-internal-run-time) (float internal-time-units-per-second)))

(defmacro with-timing (name &body body)
  `(let ((start (get-time)))
     (progn ,@body)
     (let ((end (get-time)))
       (format t "  ~30A: ~,4F seconds~%" ,name (- end start)))))

(defun run-benchmarks (&key (size 100000) (iters 10))
  (format t "Vector Microbenchmarks (Size: ~D, Iterations: ~D)~%" size iters)
  (format t "=========================================================~%")

  (let ((cl-vec (make-array size :initial-element 0))
        (fol-vec (vector)))
    (loop for i from 0 below size do (setf fol-vec (conj fol-vec 0)))

    ;; --- Access Benchmarks ---
    (format t "Access (Random):~%")
    (let ((indices (loop repeat size collect (random size))))
      (let ((total-sum 0))
        (with-timing "Common Lisp (AREF)"
                     (loop repeat iters do
                             (dolist (i indices)
                               (incf total-sum (aref cl-vec i)))))
        (format t "    [Checksum: ~D]~%" total-sum))

      (with-timing "FOL (COLLECTION-REF)"
                   (loop repeat iters do
                           (dolist (i indices)
                             (collection-ref fol-vec i))))

      (with-timing "FOL (NTH/GET)"
                   (loop repeat iters do
                           (dolist (i indices)
                             (get fol-vec i)))))

    (format t "~%Update (Sequential):~%")
    (let ((checksum 0))
      (with-timing "Common Lisp (SETF AREF) - In place"
                   (loop repeat iters do
                           (loop for i from 0 below size do
                                   (setf (aref cl-vec i) i)
                                   (incf checksum (aref cl-vec i)))))
      (format t "    [Checksum: ~D]~%" checksum))

    (with-timing "FOL (COLLECTION-ASSOC)"
                 (loop repeat iters do
                         (let ((tmp fol-vec))
                           (loop for i from 0 below size do
                                   (setf tmp (collection-assoc tmp i i))))))

    (with-timing "FOL (ASSOC)"
                 (loop repeat iters do
                         (let ((tmp fol-vec))
                           (loop for i from 0 below size do
                                   (setf tmp (assoc tmp i i))))))

    (format t "~%Creation (CONJ/WITH-LAST):~%")
    (with-timing "Common Lisp (VECTOR-PUSH-EXTEND)"
                 (loop repeat iters do
                         (let ((v (make-array 0 :fill-pointer 0 :adjustable t)))
                           (loop for i from 0 below size do
                                   (vector-push-extend i v)))))

    (with-timing "FOL (CONJ)"
                 (loop repeat iters do
                         (let ((tmp (vector)))
                           (loop for i from 0 below size do
                                   (setf tmp (conj tmp i))))))))

;; Execute if run as a script
(run-benchmarks :size 1000000 :iters 10)
