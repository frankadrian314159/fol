;;; Benchmark: FOL transpiled (persistent/Sycamore) vs plain CL (mutable CLOS)
;;; Compares observable.fol transpilation vs lisp-code/observable.lisp

(ql:quickload '("fset" "sycamore" "closer-mop") :silent t)

;; Load the compiler's persistent object system
(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

;; Load both implementations
(load "lisp-code/observable.lisp")
(load "lisp-code/observable-transpiled.lisp")

(defpackage :bench-observable
  (:use :cl))

(in-package :bench-observable)

;;; ============================================================================
;;; Benchmark scenario: create sensor, do 3 updates, dispatch on each change
;;;   1. Reading spike (10 -> 100, delta > 50)
;;;   2. Status change to :critical
;;;   3. Name change (default handler)
;;; ============================================================================

(defun run-cl-scenario ()
  "Run the plain CL (mutable CLOS) scenario once."
  (let ((s (observable:make-sensor :name "temp-1" :reading 10 :status :normal)))
    ;; Update 1: reading spike (must use package-qualified slot names)
    (multiple-value-bind (s1 ch1) (observable:update-sensor-slot s 'observable::reading 100)
      (observable:on-change ch1)
      ;; Update 2: status to critical
      (multiple-value-bind (s2 ch2) (observable:update-sensor-slot s1 'observable::status :critical)
        (observable:on-change ch2)
        ;; Update 3: name change
        (multiple-value-bind (s3 ch3) (observable:update-sensor-slot s2 'observable::name "temp-2")
          (observable:on-change ch3)
          s3)))))

(defun run-fol-scenario ()
  "Run the FOL transpiled (persistent/Sycamore) scenario once."
  (let ((s (observable-transpiled:make-<sensor> :name "temp-1" :reading 10 :status :normal)))
    ;; Update 1: reading spike (must use package-qualified slot names)
    (let* ((result1 (observable-transpiled:updated s 'observable-transpiled::reading 100))
           (s1 (sycamore:hash-map-find result1 :object)))
      (observable-transpiled:on-change result1)
      ;; Update 2: status to critical
      (let* ((result2 (observable-transpiled:updated s1 'observable-transpiled::status :critical))
             (s2 (sycamore:hash-map-find result2 :object)))
        (observable-transpiled:on-change result2)
        ;; Update 3: name change
        (let* ((result3 (observable-transpiled:updated s2 'observable-transpiled::name "temp-2"))
               (s3 (sycamore:hash-map-find result3 :object)))
          (observable-transpiled:on-change result3)
          s3)))))

;;; ============================================================================
;;; Timing
;;; ============================================================================

(defun bench (fn iterations)
  "Time FN over ITERATIONS, return seconds."
  (let ((start (get-internal-real-time)))
    (dotimes (_ iterations)
      (funcall fn))
    (let ((end (get-internal-real-time)))
      (/ (- end start) (float internal-time-units-per-second)))))

(defun run-benchmarks ()
  (let ((counts '(100 1000 10000 100000 1000000)))
    ;; Warmup
    (dotimes (_ 100) (run-cl-scenario))
    (dotimes (_ 100) (run-fol-scenario))

    ;; Verify correctness first
    (format t "~%=== Correctness check ===~%")
    (let ((cl-s (run-cl-scenario))
          (fol-s (run-fol-scenario)))
      (format t "CL  final sensor name: ~A~%"
              (observable:sensor-name cl-s))
      (format t "FOL final sensor name: ~A~%"
              (observable-transpiled:sensor-name fol-s)))

    (format t "~%=== Observable Benchmark: FOL (persistent/Sycamore) vs CL (mutable CLOS) ===~%~%")
    (format t "~12A ~12A ~12A ~12A ~12A~%"
            "Iterations" "CL (s)" "FOL (s)" "FOL/CL" "Overhead")
    (format t "~12A ~12A ~12A ~12A ~12A~%"
            "----------" "------" "-------" "------" "--------")
    (dolist (n counts)
      (let* ((cl-time  (bench #'run-cl-scenario n))
             (fol-time (bench #'run-fol-scenario n))
             (ratio (/ fol-time cl-time))
             (overhead (format nil "~,1Fx" ratio)))
        (format t "~12:D ~12,4F ~12,4F ~12,2F ~12A~%"
                n cl-time fol-time ratio overhead)))
    (format t "~%FOL/CL < 1.0 = FOL faster, > 1.0 = CL faster~%")))

(run-benchmarks)
