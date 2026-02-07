;;; Concurrent Benchmark: Locked Mutable vs Lock-Free Persistent
;;; 16 threads, each counting to 1000, storing in vec[i mod 100]
(in-package :cl-user)

(defparameter *num-threads* 16)
(defparameter *iterations* 10000)
(defparameter *vec-size* 100)

;;; ============================================================
;;; CL: Mutable vector with lock
;;; ============================================================

(defun benchmark-cl-locked ()
  "Benchmark mutable vector with lock protection."
  (let ((vec (make-array *vec-size* :initial-element 0))
        (lock (bt:make-lock "vec-lock"))
        (threads nil))

    (let ((start-time (get-internal-real-time)))
      ;; Spawn threads
      (dotimes (thread-id *num-threads*)
        (push (bt:make-thread
               (lambda ()
                 (dotimes (i *iterations*)
                   (bt:with-lock-held (lock)
                     (setf (aref vec (mod i *vec-size*)) i))))
               :name (format nil "cl-thread-~D" thread-id))
              threads))

      ;; Wait for all threads
      (dolist (thread threads)
        (bt:join-thread thread))

      (let ((end-time (get-internal-real-time)))
        (/ (- end-time start-time)
           (float internal-time-units-per-second))))))

;;; ============================================================
;;; FSet: Persistent vector with CAS (compare-and-swap)
;;; ============================================================

(defstruct atomic-ref
  "Simple atomic reference using a lock for CAS."
  (value nil)
  (lock (bt:make-lock "atomic-lock")))

(defun atomic-get (ref)
  (bt:with-lock-held ((atomic-ref-lock ref))
    (atomic-ref-value ref)))

(defun atomic-swap! (ref update-fn)
  "Atomically update REF by applying UPDATE-FN to current value."
  (bt:with-lock-held ((atomic-ref-lock ref))
    (setf (atomic-ref-value ref)
          (funcall update-fn (atomic-ref-value ref)))))

(defun benchmark-fset-atomic ()
  "Benchmark persistent vector with atomic updates."
  (let ((atom (make-atomic-ref
               :value (fset:convert 'fset:seq
                        (loop for i below *vec-size* collect 0))))
        (threads nil))

    (let ((start-time (get-internal-real-time)))
      ;; Spawn threads
      (dotimes (thread-id *num-threads*)
        (push (bt:make-thread
               (lambda ()
                 (dotimes (i *iterations*)
                   (atomic-swap! atom
                     (lambda (v)
                       (fset:with v (mod i *vec-size*) i)))))
               :name (format nil "fset-thread-~D" thread-id))
              threads))

      ;; Wait for all threads
      (dolist (thread threads)
        (bt:join-thread thread))

      (let ((end-time (get-internal-real-time)))
        (/ (- end-time start-time)
           (float internal-time-units-per-second))))))

;;; ============================================================
;;; Lock-free version: Each thread works on own copy
;;; (Shows persistent structure benefit: no coordination needed)
;;; ============================================================

(defun benchmark-fset-lockfree ()
  "Each thread works independently - no locks needed."
  (let ((threads nil)
        (results (make-array *num-threads*)))

    (let ((start-time (get-internal-real-time)))
      ;; Spawn threads - each has own vector
      (dotimes (thread-id *num-threads*)
        (let ((tid thread-id))
          (push (bt:make-thread
                 (lambda ()
                   (let ((v (fset:convert 'fset:seq
                              (loop for i below *vec-size* collect 0))))
                     (dotimes (i *iterations*)
                       (setf v (fset:with v (mod i *vec-size*) i)))
                     (setf (aref results tid) v)))
                 :name (format nil "fset-free-~D" thread-id))
                threads)))

      ;; Wait for all threads
      (dolist (thread threads)
        (bt:join-thread thread))

      (let ((end-time (get-internal-real-time)))
        (/ (- end-time start-time)
           (float internal-time-units-per-second))))))

;;; ============================================================
;;; Run benchmarks
;;; ============================================================

(defun run-concurrent-benchmarks ()
  (format t "~%=====================================================~%")
  (format t "Concurrent Benchmark: ~D threads × ~D iterations~%"
          *num-threads* *iterations*)
  (format t "Vector size: ~D elements~%"
          *vec-size*)
  (format t "=====================================================~%")

  ;; Warm up
  (format t "~%Warming up...~%")
  (benchmark-cl-locked)
  (benchmark-fset-atomic)
  (benchmark-fset-lockfree)

  ;; Run benchmarks multiple times
  (let ((cl-times nil)
        (fset-atomic-times nil)
        (fset-free-times nil))

    (format t "~%Running benchmarks (3 runs each)...~%")

    (dotimes (run 3)
      (push (benchmark-cl-locked) cl-times)
      (push (benchmark-fset-atomic) fset-atomic-times)
      (push (benchmark-fset-lockfree) fset-free-times))

    (let ((cl-avg (/ (reduce #'+ cl-times) (length cl-times)))
          (fset-atomic-avg (/ (reduce #'+ fset-atomic-times) (length fset-atomic-times)))
          (fset-free-avg (/ (reduce #'+ fset-free-times) (length fset-free-times))))

      (format t "~%=== Results (average of 3 runs) ===~%")
      (format t "CL (locked mutable):      ~,4F seconds~%" cl-avg)
      (format t "FSet (atomic persistent): ~,4F seconds~%" fset-atomic-avg)
      (format t "FSet (lock-free copies):  ~,4F seconds~%" fset-free-avg)

      (format t "~%=== Ratios ===~%")
      (format t "FSet atomic / CL locked:  ~,2Fx~%" (/ fset-atomic-avg cl-avg))
      (format t "FSet free / CL locked:    ~,2Fx~%" (/ fset-free-avg cl-avg))))

  (format t "~%Done.~%"))

(run-concurrent-benchmarks)
