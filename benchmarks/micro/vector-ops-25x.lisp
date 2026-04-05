;; Load the same setup as vector-ops.lisp
(let ((ql-path (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file ql-path)
      (load ql-path)
      (error "Quicklisp not found at ~A" ql-path)))

(push (merge-pathnames "src/" (uiop:getcwd)) asdf:*central-registry*)

(defun safe-quickload (system)
  (ql:quickload system :silent t))

(safe-quickload :fset)
(safe-quickload :sycamore)
(safe-quickload :cl-ppcre)
(safe-quickload :uuid)
(safe-quickload :bordeaux-threads)
(safe-quickload :fiveam)
(safe-quickload :closer-mop)
(safe-quickload :usocket)

(asdf:load-system :fol-compiler)

;;; ---------------------------------------------------------------
;;; Benchmark runner — lives in cl-user so NO FOL symbols are shadowed
;;; ---------------------------------------------------------------
(in-package :cl-user)

(defun get-time ()
  (/ (get-internal-run-time) (float internal-time-units-per-second)))

(defmacro measure-time (&body body)
  `(let ((start (get-time)))
     (progn ,@body)
     (- (get-time) start)))

;;; run-one returns an alist ((label . seconds) ...) using fully-qualified
;;; FOL symbols so we stay in cl-user and avoid all shadowing issues.
(defun vec-bench-run-one (size iters)
  (let* ((cl-vec (make-array size :initial-element 0))
         (fset-seq (fset:convert 'fset:seq (make-list size :initial-element 0)))
         (fol-vec (fol.compiler.collection-functions:vector))
         (indices (loop :repeat size :collect (random size))))
    ;; build fol vec
    (loop :for i :from 0 :below size
          :do (setf fol-vec (fol.compiler.collection-functions:conj fol-vec 0)))
    (cl:list
     ;; --- Random Access ---
     (cons "CL (AREF)"
           (measure-time
             (loop :repeat iters :do
               (dolist (i indices) (aref cl-vec i)))))
     (cons "FSet (LOOKUP)"
           (measure-time
             (loop :repeat iters :do
               (dolist (i indices) (fset:lookup fset-seq i)))))
     (cons "FOL (COLLECTION-REF)"
           (measure-time
             (loop :repeat iters :do
               (dolist (i indices)
                 (fol.compiler.collections:collection-ref fol-vec i)))))
     (cons "FOL (NTH/GET)"
           (measure-time
             (loop :repeat iters :do
               (dolist (i indices)
                 (fol.compiler.collection-functions:get fol-vec i)))))
     ;; --- Sequential Update ---
     (cons "CL (SETF AREF)"
           (measure-time
             (loop :repeat iters :do
               (loop :for i :from 0 :below size :do (setf (aref cl-vec i) i)))))
     (cons "FSet (WITH)"
           (measure-time
             (loop :repeat iters :do
               (let ((tmp fset-seq))
                 (loop :for i :from 0 :below size
                       :do (setf tmp (fset:with tmp i i)))))))
     (cons "FOL (COLLECTION-ASSOC)"
           (measure-time
             (loop :repeat iters :do
               (let ((tmp fol-vec))
                 (loop :for i :from 0 :below size
                       :do (setf tmp (fol.compiler.collections:collection-assoc tmp i i)))))))
     (cons "FOL (ASSOC)"
           (measure-time
             (loop :repeat iters :do
               (let ((tmp fol-vec))
                 (loop :for i :from 0 :below size
                       :do (setf tmp (fol.compiler.collection-functions:assoc tmp i i)))))))
     ;; --- Creation ---
     (cons "CL (VECTOR-PUSH-EXTEND)"
           (measure-time
             (loop :repeat iters :do
               (let ((v (make-array 0 :fill-pointer 0 :adjustable t)))
                 (loop :for i :from 0 :below size :do (vector-push-extend i v))))))
     (cons "FSet (WITH-LAST)"
           (measure-time
             (loop :repeat iters :do
               (let ((tmp (fset:empty-seq)))
                 (loop :for i :from 0 :below size
                       :do (setf tmp (fset:with-last tmp i)))))))
     (cons "FOL (CONJ)"
           (measure-time
             (loop :repeat iters :do
               (let ((tmp (fol.compiler.collection-functions:vector)))
                 (loop :for i :from 0 :below size
                       :do (setf tmp (fol.compiler.collection-functions:conj tmp i))))))))))

(defun vec-bench-run-25x (&key (size 100000) (iters 10) (runs 25))
  (format t "~%Running ~D benchmark runs (size=~D, iters=~D each)...~%"
          runs size iters)
  (let ((all-runs nil))
    ;; Warm-up (discarded)
    (vec-bench-run-one size iters)
    (format t "Warm-up done. Collecting ~D runs...~%" runs)
    (dotimes (r runs)
      (push (vec-bench-run-one size iters) all-runs)
      (when (zerop (mod (1+ r) 5))
        (format t "  completed ~D/~D~%" (1+ r) runs)))
    (format t "~%Done. Computing statistics...~%")

    ;; Aggregate into hash-table label -> list-of-times
    (let ((tbl (make-hash-table :test 'equal)))
      (dolist (run all-runs)
        (dolist (cell run)
          (setf (gethash (car cell) tbl)
                (cons (cdr cell) (gethash (car cell) tbl)))))

      (flet ((print-section (title label-list)
               (format t "~%--- ~A ---~%" title)
               (format t "~35A  ~10A  ~10A  ~10A~%"
                       "Implementation" "Mean(s)" "Min(s)" "Max(s)")
               (format t "~35A  ~10A  ~10A  ~10A~%"
                       (make-string 35 :initial-element #\-)
                       "----------" "----------" "----------")
               (dolist (lbl label-list)
                 (let* ((times (gethash lbl tbl))
                        (n     (length times))
                        (mean  (/ (reduce #'+ times) n))
                        (lo    (reduce #'min times))
                        (hi    (reduce #'max times)))
                   (format t "~35A  ~10,4F  ~10,4F  ~10,4F~%"
                           lbl mean lo hi)))))

        (format t "~%Vector Microbenchmarks — ~D runs, size=~D, iters=~D~%"
                runs size iters)
        (print-section "Random Access"
                       '("CL (AREF)" "FSet (LOOKUP)"
                         "FOL (COLLECTION-REF)" "FOL (NTH/GET)"))
        (print-section "Sequential Update (Persistent)"
                       '("CL (SETF AREF)" "FSet (WITH)"
                         "FOL (COLLECTION-ASSOC)" "FOL (ASSOC)"))
        (print-section "Creation (Append)"
                       '("CL (VECTOR-PUSH-EXTEND)" "FSet (WITH-LAST)" "FOL (CONJ)"))))))

(vec-bench-run-25x :size 100000 :iters 10 :runs 25)
