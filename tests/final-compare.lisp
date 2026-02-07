;;; Final Memory Comparison
;;; Compares allocation costs for two scenarios:
;;; 1. Single value (no history) - in-place wins
;;; 2. Keeping all versions (history) - persistent wins
(in-package :cl-user)

(defun measure-allocation (thunk)
  (sb-ext:gc :full t)
  (let ((before (sb-ext:get-bytes-consed)))
    (funcall thunk)
    (- (sb-ext:get-bytes-consed) before)))

(defvar *results* nil)

(defun compare-no-history (n mutations)
  "Scenario 1: Only need final value (no history)."
  (format t "~%--- No History Needed (size=~D, ops=~D) ---~%" n mutations)

  ;; CL: allocate once + mutate in place
  (setf *results* nil)
  (let ((cl-alloc (measure-allocation
                   (lambda ()
                     (let ((v (make-array n :initial-element 0)))
                       (dotimes (i mutations)
                         (setf (aref v (mod i n)) i))
                       (push v *results*))))))
    ;; FSet: allocate new structure each time (but discard old ones)
    (setf *results* nil)
    (let ((fset-alloc (measure-allocation
                       (lambda ()
                         (let ((v (fset:convert 'fset:seq (loop for i below n collect i))))
                           (dotimes (i mutations)
                             (setf v (fset:with v (mod i n) i)))
                           (push v *results*))))))
      (format t "  CL (mutate in place): ~:D bytes~%" cl-alloc)
      (format t "  FSet (persistent):    ~:D bytes~%" fset-alloc))))

(defun compare-with-history (n updates)
  "Scenario 2: Need all versions (undo, concurrent access, etc)."
  (format t "~%--- History Needed (size=~D, versions=~D) ---~%" n (1+ updates))

  ;; CL: must copy entire array for each version
  (setf *results* nil)
  (let ((cl-alloc (measure-allocation
                   (lambda ()
                     (let ((v (make-array n :initial-element 0)))
                       (push (copy-seq v) *results*)
                       (dotimes (i updates)
                         (let ((new-v (copy-seq v)))
                           (setf (aref new-v (mod i n)) i)
                           (push new-v *results*)
                           (setf v new-v))))))))
    ;; FSet: structural sharing means cheap versions
    (setf *results* nil)
    (let ((fset-alloc (measure-allocation
                       (lambda ()
                         (let ((v (fset:convert 'fset:seq (loop for i below n collect i))))
                           (push v *results*)
                           (dotimes (i updates)
                             (setf v (fset:with v (mod i n) i))
                             (push v *results*)))))))
      (format t "  CL (copy each time):  ~:D bytes~%" cl-alloc)
      (format t "  FSet (share struct):  ~:D bytes~%" fset-alloc)
      (when (> cl-alloc 0)
        (format t "  FSet/CL ratio:        ~,2F~%" (/ (float fset-alloc) (float cl-alloc)))))))

(defun run-comparison ()
  (format t "~%================================================~%")
  (format t "Memory Comparison: Mutable vs Persistent~%")
  (format t "================================================~%")

  (format t "~%== SCENARIO 1: No History (single final value) ==~%")
  (format t "(Persistent structures have overhead here)~%")
  (compare-no-history 1000 10)
  (compare-no-history 1000 100)
  (compare-no-history 1000 1000)

  (format t "~%~%== SCENARIO 2: History Required (keep all versions) ==~%")
  (format t "(Persistent structures win via structural sharing)~%")
  (compare-with-history 1000 10)
  (compare-with-history 1000 100)
  (compare-with-history 1000 1000)

  (format t "~%Done.~%"))

(run-comparison)
