;;;; SBCL Expensive Predicates Benchmark
;;;; Tests whether SBCL optimizes away expensive predicates like V8 does
;;;; Constraint solver: ~5300 ns baseline in V8; need to check SBCL

(defpackage :fol.expensive-predicates
  (:use :cl)
  (:export :run-benchmark))

(in-package :fol.expensive-predicates)

;;; Expensive constraint solver predicate (matches V8 version)
;;; Computes total = sum of (arg * i)^0.5 % 7 for i in 0..499
(defun constraint-solve (arg)
  "Expensive predicate: O(n) loop with floating-point operations."
  (let ((total 0.0d0))
    (dotimes (i 500)
      (let ((term (mod (expt (* arg i) 0.5d0) 7.0d0)))
        (incf total term)))
    (> total 1000.0d0)))

;;; Dispatch without caching
(defun dispatch-uncached (arg predicate-type)
  "Uncached dispatch: always evaluates predicate."
  (case predicate-type
    (:constraint (constraint-solve arg))
    (otherwise nil)))

;;; Dispatch with caching (simple hash table)
(defun dispatch-cached (arg predicate-type cache)
  "Cached dispatch using hash table."
  (let ((key (cons arg predicate-type)))
    (multiple-value-bind (result found-p) (gethash key cache)
      (if found-p
          result
          (let ((result (dispatch-uncached arg predicate-type)))
            (setf (gethash key cache) result)
            result)))))

;;; Test data (4-cycle pattern for high hit rate)
(defvar *test-args* #(10 20 30 40))

;;; Benchmark harness
(defun measure-dispatch (dispatch-fn num-iterations)
  "Measure dispatch performance over iterations, returning ns per call."
  (let ((start-time (get-internal-real-time)))
    (dotimes (i num-iterations)
      (let ((arg (aref *test-args* (mod i 4))))
        (funcall dispatch-fn arg :constraint)))
    (let* ((end-time (get-internal-real-time))
           (elapsed (/ (float (- end-time start-time))
                      (float internal-time-units-per-second)))
           (ns-per-call (* 1000000000 (/ elapsed num-iterations))))
      ns-per-call)))

;;; Main benchmark
(defun run-benchmark (&key (iterations-per-run 2000000) (warmup-iterations 200000))
  "Run expensive predicate benchmark on SBCL."
  (format t "SBCL Expensive Predicates Benchmark~%")
  (format t "SBCL ~a~%" (lisp-implementation-version))
  (format t "Constraint solver baseline: ~a ns (uncached)~%"
          "see results below")
  (format t "Test iterations: ~:d (after ~:d warmup)~%~%" iterations-per-run warmup-iterations)

  ;; Warmup (uncached)
  (format t "Warming up (~:d iterations)...~%" warmup-iterations)
  (dotimes (i warmup-iterations)
    (let ((arg (aref *test-args* (mod i 4))))
      (dispatch-uncached arg :constraint)))
  (format t "Warmup complete.~%~%")

  ;; Measure UNCACHED (3 runs)
  (format t "=== UNCACHED DISPATCH ===~%")
  (let ((uncached-times nil))
    (dotimes (run 3)
      (let ((ns-per-call (measure-dispatch
                          (lambda (arg predicate)
                            (dispatch-uncached arg predicate))
                          iterations-per-run)))
        (push ns-per-call uncached-times)
        (format t "Run ~d: ~,2f ns/call~%" (+ run 1) ns-per-call)))
    (let ((avg-uncached (/ (reduce #'+ uncached-times) 3)))
      (format t "Average uncached: ~,2f ns/call~%~%" avg-uncached)

      ;; Measure CACHED (3 runs)
      (format t "=== CACHED DISPATCH ===~%")
      (let ((cached-times nil)
            (cache (make-hash-table :test 'equal)))
        (dotimes (run 3)
          (let ((ns-per-call (measure-dispatch
                              (lambda (arg predicate)
                                (dispatch-cached arg predicate cache))
                              iterations-per-run)))
            (push ns-per-call cached-times)
            (format t "Run ~d: ~,2f ns/call~%" (+ run 1) ns-per-call)))
        (let ((avg-cached (/ (reduce #'+ cached-times) 3)))
          (format t "Average cached: ~,2f ns/call~%~%" avg-cached)

          ;; Report results
          (let ((speedup (/ avg-uncached avg-cached)))
            (format t "~%=== RESULTS ===~%")
            (format t "Uncached baseline: ~,2f ns/call~%" avg-uncached)
            (format t "Cached result:     ~,2f ns/call~%" avg-cached)
            (format t "Speedup ratio:     ~,2f×~%~%" speedup)

            ;; Interpretation
            (cond
              ((< speedup 0.1)
               (format t "RESULT: Optimizer specializes constraint solver to near-zero cost (like V8).~%")
               (format t "INTERPRETATION: SBCL defeats expensive predicates via specialization.~%")
               (format t "IMPLICATION: Design space is closed; expensive predicates do not enable caching viability.~%"))
              ((and (>= speedup 0.5) (<= speedup 1.5))
               (format t "RESULT: Cache provides marginal benefit or overhead dominates.~%")
               (format t "INTERPRETATION: SBCL partially preserves expensive predicate cost.~%")
               (format t "IMPLICATION: Design space partially exploitable; requires further investigation.~%"))
              ((> speedup 1.5)
               (format t "RESULT: Caching provides clear speedup.~%")
               (format t "INTERPRETATION: SBCL does NOT optimize away expensive predicates.~%")
               (format t "IMPLICATION: Design space remains open for compiled systems without JIT specialization.~%")))))))))

;;; Entry point
(defun main ()
  (handler-case
      (run-benchmark :warmup-iterations 200000 :iterations-per-run 2000000)
    (error (e)
      (format t "Error during benchmark: ~a~%" e))))

(main)
(sb-ext:exit)
