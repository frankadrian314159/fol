(require :asdf)
(let ((asd-path (merge-pathnames "src/fol-compiler.asd" (truename "."))))
  (unless (probe-file asd-path)
    (error "Could not find fol-compiler.asd at ~A" asd-path))
  (asdf:load-asd asd-path))

(handler-bind ((warning #'muffle-warning))
  (asdf:load-system :fol-compiler/core :verbose nil))

(load "benchmarks/boilerplate/boilerplate.lisp")

(defpackage :fol.benchmarks.dispatch
  (:use :cl)
  (:import-from :fol.benchmarks :measure-run :format-time :format-bytes :run-one :run-two)
  (:export :run-dispatch-benchmarks))

(in-package :fol.benchmarks.dispatch)

;;; ---------------------------------------------------------------------------
;;; Setup
;;; ---------------------------------------------------------------------------

;; Define predicates in CL
(loop for i below 20
      do (eval `(defun ,(intern (format nil "P~D?" i)) (x)
                  (and (numberp x) (= x ,i)))))

;; Define classes for CLOS type dispatch
(loop for i below 20
      do (eval `(defclass ,(intern (format nil "C~D" i)) () ())))

(defparameter *c-instances*
              (coerce (loop for i below 20
                            collect (make-instance (intern (format nil "C~D" i))))
                      'vector))

;;; ---------------------------------------------------------------------------
;;; FOL Implementations
;;; ---------------------------------------------------------------------------

(defun load-fol-string (s)
  (let ((cl:*readtable* fol.compiler.reader:*fol-readtable*))
    (let* ((form (fol.compiler.reader:fol-read-from-string s))
           (compiled (fol.compiler:compile-form form))
           (code (fol.compiler:compilation-result-code compiled)))
      (eval code))))

(format t "Compiling FOL dispatch benchmarks...~%")

;; 1. FOL Generic Function (Open Dispatch)
(load-fol-string
 "(defgeneric fol-generic [x])")

(let ((method-clauses
       (loop for i below 20
             collect `([ (x (,(intern (format nil "P~D?" i)))) ] ,(intern (format nil "K~D" i) :keyword)))))
  (load-fol-string
   (format nil "(defmethod fol-generic ~{~S~^ ~})" method-clauses)))

;; 2. FOL defn (Closed Dispatch)
(let ((defn-clauses
       (loop for i below 20
             collect `([ (x (,(intern (format nil "P~D?" i)))) ] ,(intern (format nil "K~D" i) :keyword)))))
  (load-fol-string
   (format nil "(defn fol-defn ~{~S~^ ~})" defn-clauses)))

;;; ---------------------------------------------------------------------------
;;; CL Implementations
;;; ---------------------------------------------------------------------------

;; 3. CL Generic + Cond (Equivalent to FOL Level 3 dispatch implementation)
(defgeneric cl-generic-cond (x))
(let ((cond-clauses
       (loop for i below 20
             collect `((,(intern (format nil "P~D?" i)) x) ,(intern (format nil "K~D" i) :keyword)))))
  (eval `(defmethod cl-generic-cond (x)
           (cond ,@cond-clauses
                 (t (error "No match"))))))

;; 4. Standard CLOS Type Dispatch (Level 2 equivalent)
(defgeneric cl-type-generic (x))
(loop for i below 20
      do (eval `(defmethod cl-type-generic ((x ,(intern (format nil "C~D" i))))
                  ,(intern (format nil "K~D" i) :keyword))))

;;; ---------------------------------------------------------------------------
;;; Benchmark Loop
;;; ---------------------------------------------------------------------------

(defun run-dispatch-benchmarks (&key (iterations 1000000))
  (format t "~%===================================================~%")
  (format t "FOL Dispatch Micro-benchmark (N=20 clauses)~%")
  (format t "Iterations: ~D~%" iterations)
  (format t "===================================================~%~%")

  ;; Warmup
  (dotimes (i 1000)
    (fol-generic (mod i 20))
    (fol-defn (mod i 20))
    (cl-generic-cond (mod i 20))
    (cl-type-generic (aref *c-instances* (mod i 20))))

  ;; 1. Standard CLOS (Type)
  (run-one (lambda ()
             (cl-type-generic (aref *c-instances* (cl:random 20))))
           iterations
           :name "1. Standard CLOS (Type Dispatch)")

  ;; 2. CL Generic + Cond (Simulation of FOL Predicate dispatch)
  (run-one (lambda ()
             (cl-generic-cond (cl:random 20)))
           iterations
           :name "2. CLOS + Manual COND (Predicate Simulation)")

  ;; 3. FOL Generic Function (Open Predicate)
  (run-one (lambda ()
             (fol-generic (cl:random 20)))
           iterations
           :name "3. FOL Generic (Predicate Dispatch)")

  ;; 4. FOL defn (Closed Predicate)
  (run-one (lambda ()
             (fol-defn (cl:random 20)))
           iterations
           :name "4. FOL defn (Closed Dispatch)")

  (format t "~%Comparison vs Standard CLOS:~%")
  (format t "---------------------------------------------------~%")

  (multiple-value-bind (t-clos) (measure-run (lambda () (cl-type-generic (aref *c-instances* (cl:random 20)))) iterations)
    (multiple-value-bind (t-fol-g) (measure-run (lambda () (fol-generic (cl:random 20))) iterations)
      (multiple-value-bind (t-fol-d) (measure-run (lambda () (fol-defn (cl:random 20))) iterations)
        (format t "FOL Generic vs CLOS: ~,2fx slower~%" (/ t-fol-g (max 1e-9 t-clos)))
        (format t "FOL defn vs CLOS:    ~,2fx slower~%" (/ t-fol-d (max 1e-9 t-clos)))
        (format t "FOL Generic vs defn: ~,2fx slower~%" (/ t-fol-g (max 1e-9 t-fol-d))))))

  (format t "===================================================~%"))

;; Run it
(run-dispatch-benchmarks)
(sb-ext:exit :code 0)
