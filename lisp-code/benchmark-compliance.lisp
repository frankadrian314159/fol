;;; =============================================================================
;;; Benchmark: hand-written CL vs transpiled (unoptimized) vs transpiled (optimized)
;;;
;;; Loads all three modules, verifies results match, then times 10000
;;; iterations of validate-trade on the same set of 4 test trades.
;;; =============================================================================

;; Load all three modules
(load "lisp-code/compliance.lisp")
(load "lisp-code/compliance-transpiled.lisp")
(load "lisp-code/compliance-transpiled-optimized.lisp")

(defpackage :benchmark-compliance
  (:use :cl))

(in-package :benchmark-compliance)

(defparameter *iterations* 10000)

;;; ---------------------------------------------------------------------------
;;; Hand-written CL version (compliance package)
;;; ---------------------------------------------------------------------------

(defun run-handwritten ()
  (let ((t1 (compliance:make-trade :symbol :NU :amount 100 :price 18.00 :side :buy))
        (t2 (compliance:make-trade :symbol :GOOG :amount 50 :price 150.00 :side :sell))
        (t3 (compliance:make-trade :symbol :IBM :amount 10000 :price 150.00 :side :buy))
        (t4 (compliance:make-trade :symbol :PENNY :amount 1000 :price 1.00 :side :buy)))
    (dotimes (i *iterations*)
      (compliance:validate-trade t1)
      (compliance:validate-trade t2)
      (compliance:validate-trade t3)
      (compliance:validate-trade t4))))

;;; ---------------------------------------------------------------------------
;;; Transpiled unoptimized (&rest args) version
;;; ---------------------------------------------------------------------------

(defun run-transpiled ()
  (let ((t1 (compliance-transpiled:make-trade :symbol :NU :amount 100 :price 18.00 :side :buy))
        (t2 (compliance-transpiled:make-trade :symbol :GOOG :amount 50 :price 150.00 :side :sell))
        (t3 (compliance-transpiled:make-trade :symbol :IBM :amount 10000 :price 150.00 :side :buy))
        (t4 (compliance-transpiled:make-trade :symbol :PENNY :amount 1000 :price 1.00 :side :buy)))
    (dotimes (i *iterations*)
      (compliance-transpiled:validate-trade t1)
      (compliance-transpiled:validate-trade t2)
      (compliance-transpiled:validate-trade t3)
      (compliance-transpiled:validate-trade t4))))

;;; ---------------------------------------------------------------------------
;;; Transpiled optimized (fixed-arity) version
;;; ---------------------------------------------------------------------------

(defun run-optimized ()
  (let ((t1 (compliance-optimized:make-trade :symbol :NU :amount 100 :price 18.00 :side :buy))
        (t2 (compliance-optimized:make-trade :symbol :GOOG :amount 50 :price 150.00 :side :sell))
        (t3 (compliance-optimized:make-trade :symbol :IBM :amount 10000 :price 150.00 :side :buy))
        (t4 (compliance-optimized:make-trade :symbol :PENNY :amount 1000 :price 1.00 :side :buy)))
    (dotimes (i *iterations*)
      (compliance-optimized:validate-trade t1)
      (compliance-optimized:validate-trade t2)
      (compliance-optimized:validate-trade t3)
      (compliance-optimized:validate-trade t4))))

;;; ---------------------------------------------------------------------------
;;; Verify results match across all three versions
;;; ---------------------------------------------------------------------------

(defun verify-results ()
  (format t "~%--- Verifying results match ---~%")
  (let* ((hw1 (compliance:validate-trade
               (compliance:make-trade :symbol :NU :amount 100 :price 18.00 :side :buy)))
         (hw2 (compliance:validate-trade
               (compliance:make-trade :symbol :GOOG :amount 50 :price 150.00 :side :sell)))
         (hw3 (compliance:validate-trade
               (compliance:make-trade :symbol :IBM :amount 10000 :price 150.00 :side :buy)))
         (hw4 (compliance:validate-trade
               (compliance:make-trade :symbol :PENNY :amount 1000 :price 1.00 :side :buy)))
         (tr1 (compliance-transpiled:validate-trade
               (compliance-transpiled:make-trade :symbol :NU :amount 100 :price 18.00 :side :buy)))
         (tr2 (compliance-transpiled:validate-trade
               (compliance-transpiled:make-trade :symbol :GOOG :amount 50 :price 150.00 :side :sell)))
         (tr3 (compliance-transpiled:validate-trade
               (compliance-transpiled:make-trade :symbol :IBM :amount 10000 :price 150.00 :side :buy)))
         (tr4 (compliance-transpiled:validate-trade
               (compliance-transpiled:make-trade :symbol :PENNY :amount 1000 :price 1.00 :side :buy)))
         (op1 (compliance-optimized:validate-trade
               (compliance-optimized:make-trade :symbol :NU :amount 100 :price 18.00 :side :buy)))
         (op2 (compliance-optimized:validate-trade
               (compliance-optimized:make-trade :symbol :GOOG :amount 50 :price 150.00 :side :sell)))
         (op3 (compliance-optimized:validate-trade
               (compliance-optimized:make-trade :symbol :IBM :amount 10000 :price 150.00 :side :buy)))
         (op4 (compliance-optimized:validate-trade
               (compliance-optimized:make-trade :symbol :PENNY :amount 1000 :price 1.00 :side :buy))))
    (format t "  Hand-written:~%")
    (format t "    T1 (NU buy):    ~S~%" hw1)
    (format t "    T2 (GOOG sell): ~S~%" hw2)
    (format t "    T3 (IBM buy):   ~S~%" hw3)
    (format t "    T4 (PENNY buy): ~S~%" hw4)
    (format t "  Transpiled (unoptimized):~%")
    (format t "    T1 (NU buy):    ~S~%" tr1)
    (format t "    T2 (GOOG sell): ~S~%" tr2)
    (format t "    T3 (IBM buy):   ~S~%" tr3)
    (format t "    T4 (PENNY buy): ~S~%" tr4)
    (format t "  Transpiled (optimized):~%")
    (format t "    T1 (NU buy):    ~S~%" op1)
    (format t "    T2 (GOOG sell): ~S~%" op2)
    (format t "    T3 (IBM buy):   ~S~%" op3)
    (format t "    T4 (PENNY buy): ~S~%" op4)
    ;; Compare statuses (all three should match)
    (assert (eq (getf hw1 :status) (getf tr1 :status)))
    (assert (eq (getf hw1 :status) (getf op1 :status)))
    (assert (eq (getf hw2 :status) (getf tr2 :status)))
    (assert (eq (getf hw2 :status) (getf op2 :status)))
    (assert (eq (getf hw3 :status) (getf tr3 :status)))
    (assert (eq (getf hw3 :status) (getf op3 :status)))
    (assert (eq (getf hw4 :status) (getf tr4 :status)))
    (assert (eq (getf hw4 :status) (getf op4 :status)))
    ;; Compare reasons
    (assert (equal (getf hw2 :reason) (getf tr2 :reason)))
    (assert (equal (getf hw2 :reason) (getf op2 :reason)))
    (assert (equal (getf hw3 :reason) (getf tr3 :reason)))
    (assert (equal (getf hw3 :reason) (getf op3 :reason)))
    (assert (equal (getf hw4 :reason) (getf tr4 :reason)))
    (assert (equal (getf hw4 :reason) (getf op4 :reason)))
    (format t "  All results match!~%")))

;;; ---------------------------------------------------------------------------
;;; Benchmark harness
;;; ---------------------------------------------------------------------------

(defun run-timed (label fn)
  "Run FN 10 times, print timing stats, return elapsed seconds."
  (format t "--- ~A ---~%" label)
  (let ((start (get-internal-real-time)))
    (dotimes (run 10)
      (funcall fn))
    (let* ((end (get-internal-real-time))
           (elapsed (/ (- end start) internal-time-units-per-second)))
      (format t "  10 runs of ~D iterations: ~,6F seconds~%" *iterations* elapsed)
      (format t "  Average per run: ~,6F seconds~%" (/ elapsed 10))
      (format t "  Per call: ~,2F microseconds~%~%"
              (* (/ elapsed (* 10 *iterations* 4)) 1000000))
      elapsed)))

(defun benchmark ()
  "Run all three versions and compare timings."
  (verify-results)

  (format t "~%========================================~%")
  (format t "Compliance Benchmark: ~D iterations x 4 trades~%" *iterations*)
  (format t "========================================~%~%")

  ;; Warm up
  (run-handwritten)
  (run-transpiled)
  (run-optimized)

  (let* ((hw-elapsed  (run-timed "Hand-written CL (compliance.lisp)" #'run-handwritten))
         (tr-elapsed  (run-timed "Transpiled FOL - unoptimized (&rest)" #'run-transpiled))
         (opt-elapsed (run-timed "Transpiled FOL - optimized (fixed-arity)" #'run-optimized)))

    (format t "--- Comparison ---~%")
    (when (> hw-elapsed 0)
      (format t "  Unoptimized / hand-written:  ~,2Fx~%" (/ tr-elapsed hw-elapsed))
      (format t "  Optimized   / hand-written:  ~,2Fx~%" (/ opt-elapsed hw-elapsed)))
    (when (> opt-elapsed 0)
      (format t "  Unoptimized / optimized:     ~,2Fx~%" (/ tr-elapsed opt-elapsed)))
    (format t "========================================~%")))

(benchmark)
