;;; Snapshot Comparison
;;; CL saves array every 100 mutations, FSet keeps all versions
(in-package :cl-user)

(defvar *test-values* (vector nil 1 1.0d0 "abc" 'a)
  "Pool of random values to insert.")

(defun random-value ()
  (aref *test-values* (random (length *test-values*))))

(defun measure-allocation (thunk)
  (sb-ext:gc :full t)
  (let ((before (sb-ext:get-bytes-consed)))
    (funcall thunk)
    (- (sb-ext:get-bytes-consed) before)))

(defvar *cl-snapshots* nil)
(defvar *fset-versions* nil)

(defun compare-with-snapshots (n mutations snapshot-interval)
  "Compare CL (snapshots every SNAPSHOT-INTERVAL) vs FSet (all versions)."
  (let ((num-snapshots (1+ (floor mutations snapshot-interval))))
    (format t "~%=== size=~D, mutations=~D, snapshots=~D ===~%"
            n mutations num-snapshots)

    ;; CL: Save snapshot every snapshot-interval mutations
    (setf *cl-snapshots* nil)
    (let ((cl-alloc (measure-allocation
                     (lambda ()
                       (let ((v (make-array n :initial-element nil)))
                         ;; Initialize with random values
                         (dotimes (i n)
                           (setf (aref v i) (random-value)))
                         (push (copy-seq v) *cl-snapshots*)  ; Initial snapshot
                         (dotimes (i mutations)
                           (setf (aref v (random n)) (random-value))
                           (when (zerop (mod (1+ i) snapshot-interval))
                             (push (copy-seq v) *cl-snapshots*))))))))

      ;; FSet: Every update creates a new version (structural sharing)
      (setf *fset-versions* nil)
      (let ((fset-alloc (measure-allocation
                         (lambda ()
                           (let ((v (fset:convert 'fset:seq
                                     (loop for i below n collect (random-value)))))
                             (push v *fset-versions*)  ; Initial version
                             (dotimes (i mutations)
                               (setf v (fset:with v (random n) (random-value)))
                               (when (zerop (mod (1+ i) snapshot-interval))
                                 (push v *fset-versions*))))))))

        (format t "CL (~D snapshots):    ~:D bytes~%"
                (length *cl-snapshots*) cl-alloc)
        (format t "FSet (~D versions):   ~:D bytes~%"
                (length *fset-versions*) fset-alloc)
        (when (> cl-alloc 0)
          (format t "FSet/CL ratio:        ~,2F~%"
                  (/ (float fset-alloc) (float cl-alloc))))))))

(defun compare-all-versions (n mutations)
  "Compare CL (copy EVERY mutation) vs FSet (structural sharing)."
  (format t "~%=== Keep ALL ~D versions (size=~D) ===~%" (1+ mutations) n)

  ;; CL: Copy entire array for every mutation
  (setf *cl-snapshots* nil)
  (let ((cl-alloc (measure-allocation
                   (lambda ()
                     (let ((v (make-array n :initial-element nil)))
                       (dotimes (i n)
                         (setf (aref v i) (random-value)))
                       (push (copy-seq v) *cl-snapshots*)
                       (dotimes (i mutations)
                         (let ((new-v (copy-seq v)))
                           (setf (aref new-v (random n)) (random-value))
                           (push new-v *cl-snapshots*)
                           (setf v new-v))))))))

    ;; FSet: structural sharing
    (setf *fset-versions* nil)
    (let ((fset-alloc (measure-allocation
                       (lambda ()
                         (let ((v (fset:convert 'fset:seq
                                   (loop for i below n collect (random-value)))))
                           (push v *fset-versions*)
                           (dotimes (i mutations)
                             (setf v (fset:with v (random n) (random-value)))
                             (push v *fset-versions*)))))))

      (format t "CL (full copies):     ~:D bytes~%" cl-alloc)
      (format t "FSet (sharing):       ~:D bytes~%" fset-alloc)
      (when (> cl-alloc 0)
        (format t "FSet/CL ratio:        ~,2F~%"
                (/ (float fset-alloc) (float cl-alloc)))))))

(defun run-snapshot-tests ()
  (format t "~%==============================================~%")
  (format t "Snapshot Comparison: CL vs FSet~%")
  (format t "Values: nil, 1, 1.0d0, \"abc\", 'a~%")
  (format t "==============================================~%")

  (format t "~%--- SAME INTERVAL (save every 100) ---~%")
  (compare-with-snapshots 1000 10 100)
  (compare-with-snapshots 1000 100 100)
  (compare-with-snapshots 1000 1000 100)
  (compare-with-snapshots 1000 10000 100)

  (format t "~%~%--- KEEP ALL VERSIONS ---~%")
  (compare-all-versions 1000 10)
  (compare-all-versions 1000 100)
  (compare-all-versions 1000 1000)

  (format t "~%Done.~%"))

(run-snapshot-tests)
