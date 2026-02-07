;;; Memory Comparison Tests for FOL vs Common Lisp
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
      ;; CLOS objects
      (standard-object
       (+ size (loop for slot in (closer-mop:class-slots (class-of obj))
                     for name = (closer-mop:slot-definition-name slot)
                     when (slot-boundp obj name)
                       sum (deep-size (slot-value obj name) seen))))
      (t size))))

;;; --- Vector Comparison (shows structural sharing benefit) ---

(defun compare-vector-updates (n updates)
  "Compare memory after UPDATES updates to a vector of size N."
  (let ((cl-vectors nil)
        (fol-vectors nil)
        (env (fol.eval:make-standard-module)))

    ;; CL: each update copies entire vector
    (let ((v (make-array n :initial-element 0)))
      (push (copy-seq v) cl-vectors)
      (dotimes (i updates)
        (let ((new-v (copy-seq v)))
          (setf (aref new-v (mod i n)) i)
          (push new-v cl-vectors)
          (setf v new-v))))

    ;; FOL: structural sharing via FSet
    (let ((v (fol.repl:fol-test (format nil "(vec (range ~D))" n) env)))
      (push v fol-vectors)
      (dotimes (i updates)
        (let* ((idx (mod i n))
               (update-env (fol.env:make-env env 'v v))
               (new-v (fol.repl:fol-test
                       (format nil "(assoc v ~D ~D)" idx i)
                       update-env)))
          (push new-v fol-vectors)
          (setf v new-v))))

    ;; Measure with fresh hash tables to avoid cross-contamination
    (let ((cl-total (loop for v in cl-vectors sum (deep-size v (make-hash-table :test 'eq))))
          (fol-total (loop for v in fol-vectors sum (deep-size v (make-hash-table :test 'eq)))))
      (format t "~%=== Vector Updates (size=~D, updates=~D) ===~%" n updates)
      (format t "CL total:     ~:D bytes~%" cl-total)
      (format t "FOL total:    ~:D bytes~%" fol-total)
      (format t "FOL/CL ratio: ~,3F~%" (/ (float fol-total) (float cl-total)))
      (values cl-total fol-total))))

;;; Run the tests
(defun run-memory-tests ()
  (format t "~%========================================~%")
  (format t "Memory Comparison: FOL vs Common Lisp~%")
  (format t "========================================~%")

  ;; Test with vector size 1000 and varying update counts
  (compare-vector-updates 1000 10)
  (compare-vector-updates 1000 100)
  (compare-vector-updates 1000 1000)

  (format t "~%Done.~%"))

(run-memory-tests)
