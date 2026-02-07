;;; Map vs Pmap Benchmark
;;; Compare sequential CL map vs parallel FOL pmap
;;; Function: (+ i (sqrt i) (log i))
(in-package :cl-user)

(defun compute-fn (i)
  "The computation function: i + sqrt(i) + log(i)"
  (let ((x (float i 1.0d0)))
    (if (> x 0)
        (+ x (sqrt x) (log x))
        x)))

(defun benchmark-cl-map (n num-runs)
  "Benchmark CL sequential map over vector of size N."
  (let ((vec (coerce (loop for i from 0 below n collect i) 'vector))
        (times nil))
    (dotimes (run num-runs)
      (let ((start (get-internal-real-time)))
        (map 'vector #'compute-fn vec)
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

(defun benchmark-fol-pmap (n num-runs)
  "Benchmark FOL pmap over vector of size N."
  (let ((env (fol.eval:make-standard-module))
        (times nil))
    ;; Define the computation function and vector in FOL
    ;; Simple inline fn that takes i directly
    (fol.repl:fol-test (format nil "(def v (vec (range ~D)))" n) env)

    (dotimes (run num-runs)
      (let ((start (get-internal-real-time)))
        ;; Use a lambda function inline to avoid closure scoping issues with lparallel
        (fol.repl:fol-test
         "(vec (pmap (fn [i] (if (> i 0) (+ i (sqrt i) (log i)) 0.0)) v))"
         env)
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

(defun benchmark-fol-map (n num-runs)
  "Benchmark FOL sequential map over vector of size N."
  (let ((env (fol.eval:make-standard-module))
        (times nil))
    ;; Define the vector in FOL
    (fol.repl:fol-test (format nil "(def v (vec (range ~D)))" n) env)

    (dotimes (run num-runs)
      (let ((start (get-internal-real-time)))
        ;; Use a lambda function inline
        (fol.repl:fol-test
         "(vec (map (fn [i] (if (> i 0) (+ i (sqrt i) (log i)) 0.0)) v))"
         env)
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

(defun run-map-benchmarks ()
  (format t "~%==============================================~%")
  (format t "Map vs Pmap Benchmark~%")
  (format t "Function: i + sqrt(i) + log(i)~%")
  (format t "==============================================~%")

  (let ((sizes '(9999 99999 999999))
        (num-runs 3))

    (format t "~%Warming up...~%")
    (benchmark-cl-map 10 1)
    (benchmark-fol-map 10 1)
    (benchmark-fol-pmap 10 1)

    (format t "~%~10A ~12A ~12A ~12A ~12A~%"
            "N" "CL map" "FOL map" "FOL pmap" "pmap speedup")
    (format t "~10A ~12A ~12A ~12A ~12A~%"
            "---" "--------" "--------" "--------" "------------")

    (dolist (n sizes)
      (format t "~%Running N=~D...~%" n)
      (let* ((cl-time (benchmark-cl-map n num-runs))
             (fol-map-time (benchmark-fol-map n num-runs))
             (fol-pmap-time (benchmark-fol-pmap n num-runs))
             (speedup (if (> fol-pmap-time 0)
                          (/ fol-map-time fol-pmap-time)
                          0)))
        (format t "~10D ~12,6F ~12,6F ~12,6F ~12,2Fx~%"
                n cl-time fol-map-time fol-pmap-time speedup))))

  (format t "~%Done.~%"))

(run-map-benchmarks)
