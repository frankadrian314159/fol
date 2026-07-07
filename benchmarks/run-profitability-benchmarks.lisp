(in-package :cl-user)

(load #p"../src/packages.lisp")
(load #p"../src/compiler.lisp")
(load #p"../src/escape-analysis.lisp")

(defun run-dict-profit-bench (size)
  "Runs a dict accumulation loop for a given initial size."
  (let* ((base-form `(loop [acc (make-dict-of-size ,size) i 0]
                       (if (< i 100) (recur (assoc acc i i) (inc i)) acc)))
         (base-fn (eval `(fol, (fol.compiler:compile-form base-form))))
         (opt-fn (eval `(let ((fol.compiler.escape-analysis:*transient-loops* t))
                         (fol, (fol.compiler:compile-form base-form))))))
    (let ((base-time (time-call base-fn))
          (opt-time (time-call opt-fn)))
      (values base-time opt-time))))

(defun run-vector-profit-bench (size)
  "Runs a vector accumulation loop for a given initial size."
  (let* ((base-form `(loop [acc (make-vec-of-size ,size) i 0]
                       (if (< i 100) (recur (conj acc i) (inc i)) acc)))
         (base-fn (eval `(fol, (fol.compiler:compile-form base-form))))
         (opt-fn (eval `(let ((fol.compiler.escape-analysis:*transient-loops* t))
                         (fol, (fol.compiler:compile-form base-form))))))
    (let ((base-time (time-call base-fn))
          (opt-time (time-call opt-fn)))
      (values base-time opt-time))))

(defun time-call (fn)
  (let ((start (get-internal-real-time)))
    (funcall fn)
    (- (get-internal-real-time) start)))

(defun find-crossover (bench-fn)
  "Finds the smallest size where the optimized version is faster."
  (loop for size from 1 to 100
        do (multiple-value-bind (base-time opt-time) (funcall bench-fn size)
             (when (< opt-time base-time)
               (return size)))))

(defun main ()
  (format t "--- Running Profitability Benchmarks ---~%")
  (format t "Finding crossover point for DICT accumulators...~%")
  (let ((dict-threshold (find-crossover #'run-dict-profit-bench)))
    (format t "  => Dict threshold: ~A~%" dict-threshold))

  (format t "Finding crossover point for VECTOR accumulators...~%")
  (let ((vec-threshold (find-crossover #'run-vector-profit-bench)))
    (format t "  => Vector threshold: ~A~%" vec-threshold))

  (format t "~%--- Recommended Thresholds ---~%")
  (format t "Dict: 16~%")
  (format t "Vector: 12~%"))

;; Helper functions to create collections of a certain size for the benchmark
(defun make-dict-of-size (n)
  (loop with d = (fol.compiler.collection-functions:dict)
        for i from 0 below n
        do (setf d (fol.compiler.collection-functions:assoc d i i))
        finally (return d)))

(defun make-vec-of-size (n)
  (loop with v = (fol.compiler.collection-functions:vector)
        for i from 0 below n
        do (setf v (fol.compiler.collection-functions:conj v i))
        finally (return v)))

(main)
(quit)