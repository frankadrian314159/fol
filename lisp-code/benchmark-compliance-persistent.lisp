;;; =============================================================================
;;; Benchmark: Hand-written CL (mutable) vs Persistent Objects
;;;
;;; Loads both modules, verifies results match, then times 100,000
;;; iterations of validate-trade on 4 test trades.
;;; =============================================================================

(load "lisp-code/compliance.lisp")
(load "lisp-code/compliance-persistent.lisp")

(defpackage :benchmark-persistent
  (:use :cl))

(in-package :benchmark-persistent)

(defparameter *iterations* 100000)

;;; ---------------------------------------------------------------------------
;;; Hand-written CL version (mutable CLOS)
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
;;; Persistent CL version (FSet-backed)
;;; ---------------------------------------------------------------------------

(defun run-persistent ()
  (let ((t1 (compliance-persistent:make-trade :symbol :NU :amount 100 :price 18.00 :side :buy))
        (t2 (compliance-persistent:make-trade :symbol :GOOG :amount 50 :price 150.00 :side :sell))
        (t3 (compliance-persistent:make-trade :symbol :IBM :amount 10000 :price 150.00 :side :buy))
        (t4 (compliance-persistent:make-trade :symbol :PENNY :amount 1000 :price 1.00 :side :buy)))
    (dotimes (i *iterations*)
      (compliance-persistent:validate-trade t1)
      (compliance-persistent:validate-trade t2)
      (compliance-persistent:validate-trade t3)
      (compliance-persistent:validate-trade t4))))

;;; ---------------------------------------------------------------------------
;;; Verify results match
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
         (ps1 (compliance-persistent:validate-trade
               (compliance-persistent:make-trade :symbol :NU :amount 100 :price 18.00 :side :buy)))
         (ps2 (compliance-persistent:validate-trade
               (compliance-persistent:make-trade :symbol :GOOG :amount 50 :price 150.00 :side :sell)))
         (ps3 (compliance-persistent:validate-trade
               (compliance-persistent:make-trade :symbol :IBM :amount 10000 :price 150.00 :side :buy)))
         (ps4 (compliance-persistent:validate-trade
               (compliance-persistent:make-trade :symbol :PENNY :amount 1000 :price 1.00 :side :buy))))
    (format t "  Hand-written:~%")
    (format t "    T1 (NU buy):    ~S~%" hw1)
    (format t "    T2 (GOOG sell): ~S~%" hw2)
    (format t "    T3 (IBM buy):   ~S~%" hw3)
    (format t "    T4 (PENNY buy): ~S~%" hw4)
    (format t "  Persistent:~%")
    (format t "    T1 (NU buy):    ~S~%" ps1)
    (format t "    T2 (GOOG sell): ~S~%" ps2)
    (format t "    T3 (IBM buy):   ~S~%" ps3)
    (format t "    T4 (PENNY buy): ~S~%" ps4)
    ;; Compare statuses
    (assert (eq (getf hw1 :status) (getf ps1 :status)))
    (assert (eq (getf hw2 :status) (getf ps2 :status)))
    (assert (eq (getf hw3 :status) (getf ps3 :status)))
    (assert (eq (getf hw4 :status) (getf ps4 :status)))
    ;; Compare reasons
    (assert (equal (getf hw2 :reason) (getf ps2 :reason)))
    (assert (equal (getf hw3 :reason) (getf ps3 :reason)))
    (assert (equal (getf hw4 :reason) (getf ps4 :reason)))
    (format t "  All results match!~%")))

;;; ---------------------------------------------------------------------------
;;; Benchmark harness
;;; ---------------------------------------------------------------------------

(defun run-timed (label fn)
  "Run FN 5 times, report best timing."
  (format t "--- ~A ---~%" label)
  (let ((best most-positive-fixnum))
    (dotimes (run 5)
      (let ((start (get-internal-real-time)))
        (funcall fn)
        (let ((elapsed (- (get-internal-real-time) start)))
          (when (< elapsed best)
            (setf best elapsed)))))
    (let* ((elapsed-s (/ best internal-time-units-per-second))
           (per-call-us (* (/ elapsed-s (* *iterations* 4)) 1000000)))
      (format t "  Best of 5 runs (~D iterations x 4 trades):~%" *iterations*)
      (format t "  Total: ~,6F seconds~%" elapsed-s)
      (format t "  Per call: ~,2F microseconds~%~%" per-call-us)
      elapsed-s)))

(defun benchmark ()
  "Run both versions and compare."
  (verify-results)

  (format t "~%========================================~%")
  (format t "Persistent Objects Benchmark: ~D iterations~%" *iterations*)
  (format t "========================================~%~%")

  ;; Warm up
  (run-handwritten)
  (run-persistent)

  (let* ((hw-time  (run-timed "Hand-written CL (mutable CLOS)" #'run-handwritten))
         (ps-time  (run-timed "Persistent CL (FSet-backed)" #'run-persistent)))

    (format t "--- Comparison ---~%")
    (when (> hw-time 0)
      (format t "  Persistent / hand-written: ~,2Fx~%" (/ ps-time hw-time)))
    (format t "========================================~%")))

(benchmark)
