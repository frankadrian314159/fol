;;; Fibonacci Benchmark: CL eql specializers vs FOL predicate dispatch
;;; Compare dispatch overhead for base case pattern matching
(in-package :cl-user)

;;; ============================================================
;;; CL: Generic function with eql specializers (memoized)
;;; ============================================================

(defvar *cl-fib-cache* (make-hash-table))

(defgeneric cl-fib (n))

(defmethod cl-fib ((n (eql 0))) 0)
(defmethod cl-fib ((n (eql 1))) 1)
(defmethod cl-fib (n)
  (or (gethash n *cl-fib-cache*)
      (setf (gethash n *cl-fib-cache*)
            (+ (cl-fib (- n 1)) (cl-fib (- n 2))))))

(defun benchmark-cl-fib (max-n num-runs)
  "Benchmark CL fib with eql specializers for 0..MAX-N."
  (let ((times nil))
    (dotimes (run num-runs)
      (clrhash *cl-fib-cache*)
      (let ((start (get-internal-real-time)))
        (loop for i from 0 below max-n
              do (cl-fib i))
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

;;; ============================================================
;;; CL: Iterative (baseline, no dispatch overhead)
;;; ============================================================

(defun cl-fib-iter (n)
  "Iterative fibonacci - no dispatch overhead."
  (if (< n 2)
      n
      (loop with a = 0 and b = 1
            for i from 2 to n
            do (psetf a b b (+ a b))
            finally (return b))))

(defun benchmark-cl-fib-iter (max-n num-runs)
  "Benchmark iterative CL fib for 0..MAX-N."
  (let ((times nil))
    (dotimes (run num-runs)
      (let ((start (get-internal-real-time)))
        (loop for i from 0 below max-n
              do (cl-fib-iter i))
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

;;; ============================================================
;;; FOL: Predicate dispatch with = specializers
;;; ============================================================

(defun benchmark-fol-fib (max-n num-runs)
  "Benchmark FOL fib with = predicate specializers for 0..MAX-N."
  (let ((times nil))
    (dotimes (run num-runs)
      (let* ((env (fol.eval:make-standard-module))
             (start (get-internal-real-time)))
        ;; Define and run in single do block
        (fol.repl:fol-test
         (format nil "
           (do
             (def fib-cache (atom {}))
             (defn fib
               ([(n (= 0))] 0)
               ([(n (= 1))] 1)
               ([n]
                 (if-let [cached (get @fib-cache n)]
                   cached
                   (bind [result (+ (fib (- n 1)) (fib (- n 2)))]
                     (swap! fib-cache assoc n result)
                     result))))
             (vec (map fib (range ~D))))
         " max-n)
         env)
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

;;; ============================================================
;;; FOL: Without predicate specializers (if-based)
;;; ============================================================

(defun benchmark-fol-fib-if (max-n num-runs)
  "Benchmark FOL fib without specializers (plain if) for 0..MAX-N."
  (let ((times nil))
    (dotimes (run num-runs)
      (let* ((env (fol.eval:make-standard-module))
             (start (get-internal-real-time)))
        ;; Define and run in single do block
        (fol.repl:fol-test
         (format nil "
           (do
             (def fib-cache2 (atom {}))
             (defn fib2 [n]
               (cond
                 (= n 0) 0
                 (= n 1) 1
                 :else
                   (if-let [cached (get @fib-cache2 n)]
                     cached
                     (bind [result (+ (fib2 (- n 1)) (fib2 (- n 2)))]
                       (swap! fib-cache2 assoc n result)
                       result))))
             (vec (map fib2 (range ~D))))
         " max-n)
         env)
        (push (/ (- (get-internal-real-time) start)
                 (float internal-time-units-per-second))
              times)))
    (/ (reduce #'+ times) (length times))))

;;; ============================================================
;;; Run benchmarks
;;; ============================================================

(defun run-fib-benchmarks ()
  (format t "~%==============================================~%")
  (format t "Fibonacci Benchmark~%")
  (format t "CL eql specializers vs FOL = predicate dispatch~%")
  (format t "==============================================~%")

  (let ((sizes '(100 1000 10000))
        (num-runs 3))

    (format t "~%Warming up...~%")
    (benchmark-cl-fib 10 1)
    (benchmark-cl-fib-iter 10 1)
    (benchmark-fol-fib 10 1)
    (benchmark-fol-fib-if 10 1)

    (format t "~%~8A ~12A ~12A ~12A ~12A ~12A~%"
            "N" "CL iter" "CL eql" "FOL =" "FOL if" "FOL/CL ratio")
    (format t "~8A ~12A ~12A ~12A ~12A ~12A~%"
            "---" "--------" "--------" "--------" "--------" "------------")

    (dolist (n sizes)
      (format t "~%Running N=~D...~%" n)
      (let* ((cl-iter-time (benchmark-cl-fib-iter n num-runs))
             (cl-eql-time (benchmark-cl-fib n num-runs))
             (fol-pred-time (benchmark-fol-fib n num-runs))
             (fol-if-time (benchmark-fol-fib-if n num-runs))
             (ratio (if (> cl-eql-time 0)
                        (/ fol-pred-time cl-eql-time)
                        0)))
        (format t "~8D ~12,6F ~12,6F ~12,6F ~12,6F ~12,2Fx~%"
                n cl-iter-time cl-eql-time fol-pred-time fol-if-time ratio))))

  (format t "~%Done.~%"))

(run-fib-benchmarks)
