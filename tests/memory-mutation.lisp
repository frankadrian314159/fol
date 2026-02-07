;;; Memory Comparison: In-place Mutation vs Persistent Updates
;;; This test compares storage when you DON'T need to keep history
(in-package :cl-user)

;;; --- SBCL-specific size functions ---

(defun object-size (obj)
  "Return the size of OBJ in bytes (SBCL only)."
  (sb-ext:primitive-object-size obj))

(defun deep-size (obj &optional (seen (make-hash-table :test 'eq)))
  "Return total bytes for OBJ and all objects it references."
  (when (or (null obj) (gethash obj seen))
    (return-from deep-size 0))
  (setf (gethash obj seen) t)
  (let ((size (object-size obj)))
    (typecase obj
      (cons
       (+ size (deep-size (car obj) seen) (deep-size (cdr obj) seen)))
      (array
       (+ size (loop for i below (array-total-size obj)
                     sum (deep-size (row-major-aref obj i) seen))))
      (hash-table
       (+ size (loop for k being the hash-keys of obj using (hash-value v)
                     sum (+ (deep-size k seen) (deep-size v seen)))))
      ;; FSet collections
      (fset:wb-map
       (+ size (fset:reduce (lambda (acc k v)
                              (+ acc (deep-size k seen) (deep-size v seen)))
                            obj :initial-value 0)))
      (fset:wb-set
       (+ size (fset:reduce (lambda (acc v) (+ acc (deep-size v seen)))
                            obj :initial-value 0)))
      (fset::wb-seq
       (+ size (fset:reduce (lambda (acc v) (+ acc (deep-size v seen)))
                            obj :initial-value 0)))
      ;; CLOS objects
      (standard-object
       (+ size (loop for slot in (closer-mop:class-slots (class-of obj))
                     for name = (closer-mop:slot-definition-name slot)
                     when (slot-boundp obj name)
                       sum (deep-size (slot-value obj name) seen))))
      (t size))))

;;; --- Mutation Comparison (no history kept) ---

(defun compare-mutations (n mutations)
  "Compare memory for MUTATIONS mutations to a vector of size N.
   CL mutates in place; FOL creates new versions but only keeps the final one."
  (let ((env (fol.eval:make-standard-module))
        (rng (make-random-state t)))  ; Seed RNG for reproducibility within run

    ;; CL: mutate in place - only one array exists
    (let ((cl-array (make-array n :initial-element 0)))
      (dotimes (i mutations)
        (setf (aref cl-array (random n rng)) i))

      ;; FOL: persistent updates - create new version each time, keep only last
      (let ((fol-vec (fol.repl:fol-test (format nil "(vec (range ~D))" n) env)))
        (dotimes (i mutations)
          (let* ((idx (random n rng))
                 (update-env (fol.env:make-env env 'v fol-vec)))
            (setf fol-vec (fol.repl:fol-test
                           (format nil "(assoc v ~D ~D)" idx i)
                           update-env))))

        ;; Measure final state only
        (let ((cl-size (deep-size cl-array))
              (fol-size (deep-size fol-vec)))
          (format t "~%=== Single Vector After ~:D Mutations (size=~D) ===~%" mutations n)
          (format t "CL array:     ~:D bytes~%" cl-size)
          (format t "FOL vector:   ~:D bytes~%" fol-size)
          (format t "FOL/CL ratio: ~,2Fx~%" (/ (float fol-size) (float cl-size)))
          (values cl-size fol-size))))))

;;; Run the tests
(defun run-mutation-tests ()
  (format t "~%=============================================~%")
  (format t "Memory: In-Place Mutation vs Persistent Update~%")
  (format t "(Only final result kept - no history)~%")
  (format t "=============================================~%")

  ;; Test with vector size 1000 and varying mutation counts
  (compare-mutations 1000 10)
  (compare-mutations 1000 100)
  (compare-mutations 1000 1000)
  (compare-mutations 1000 10000)

  (format t "~%Done.~%"))

(run-mutation-tests)
