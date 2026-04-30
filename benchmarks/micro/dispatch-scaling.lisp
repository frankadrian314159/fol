;;; dispatch-scaling.lisp
;;;
;;; Dispatch scaling benchmark: N=5, 10, 20, 50 clauses, 5 trials each.
;;; Reports mean and range (max-min) for each dispatch method at each N.
;;; At N=20 this provides the statistical data for the paper's dispatch table;
;;; across N values it verifies the linear-scaling claim.
;;;
;;; Run from the fol/ project root:
;;;   sbcl --noinform --non-interactive \
;;;        --load benchmarks/micro/dispatch-scaling.lisp

(require :asdf)
(pushnew (truename "src/") asdf:*central-registry*)
(asdf:load-asd (merge-pathnames "src/fol-compiler.asd" (truename ".")))

(handler-bind ((warning #'muffle-warning))
  (asdf:load-system :fol-compiler/core :verbose nil))

(in-package :cl-user)

;;; ---------------------------------------------------------------------------
;;; Helpers
;;; ---------------------------------------------------------------------------

(defun ds/load-fol (s)
  (let ((*readtable* fol.compiler.reader:*fol-readtable*))
    (let* ((form (fol.compiler.reader:fol-read-from-string s))
           (compiled (fol.compiler:compile-form form))
           (code (fol.compiler:compilation-result-code compiled)))
      (eval code))))

(defun ds/measure-ns (fn iterations)
  "Returns mean ns/op over ITERATIONS calls."
  (sb-ext:gc :full t)
  (let ((t0 (get-internal-real-time)))
    (dotimes (i iterations) (funcall fn))
    (* 1d9 (/ (- (get-internal-real-time) t0)
              (* (float internal-time-units-per-second 1d0)
                 (float iterations 1d0))))))

(defun ds/mean (lst)
  (/ (reduce #'+ lst) (float (length lst) 1d0)))

(defun ds/range (lst)
  (- (reduce #'max lst) (reduce #'min lst)))

;;; ---------------------------------------------------------------------------
;;; Pre-define predicates DS-P0? ... DS-P49?  and classes DS-C0 ... DS-C49
;;; ---------------------------------------------------------------------------

(loop for i below 50
      do (eval `(defun ,(intern (format nil "DS-P~D?" i)) (x)
                  (and (numberp x) (= x ,i)))))

(loop for i below 50
      do (eval `(defclass ,(intern (format nil "DS-C~D" i)) () ())))

(defparameter *ds-all-instances*
  (coerce (loop for i below 50
                collect (make-instance (intern (format nil "DS-C~D" i))))
          'vector))

;;; ---------------------------------------------------------------------------
;;; Build all four dispatch variants for a given N
;;; Returns (clos-sym cond-sym fgen-sym fdfn-sym instances-vector)
;;; ---------------------------------------------------------------------------

(defun ds/setup (n)
  (let ((clos-sym  (intern (format nil "DS-CLOS-~D" n)))
        (cond-sym  (intern (format nil "DS-COND-~D" n)))
        (fgen-name (format nil "ds-fgen-~D" n))
        (fdfn-name (format nil "ds-fdfn-~D" n)))

    ;; 1. Standard CLOS type dispatch
    (eval `(defgeneric ,clos-sym (x)))
    (loop for i below n
          do (eval `(defmethod ,clos-sym
                        ((x ,(intern (format nil "DS-C~D" i))))
                      ,(intern (format nil "K~D" i) :keyword))))

    ;; 2. Manual CL cond cascade (simulates predicate dispatch)
    (eval `(defgeneric ,cond-sym (x)))
    (eval `(defmethod ,cond-sym (x)
             (cond
               ,@(loop for i below n
                       collect `((,(intern (format nil "DS-P~D?" i)) x)
                                 ,(intern (format nil "K~D" i) :keyword)))
               (t (error "no match")))))

    ;; 3. FOL defgeneric (open predicate dispatch)
    (ds/load-fol (format nil "(defgeneric ~A [x])" fgen-name))
    (let ((clauses (loop for i below n
                         collect `([ (x (,(intern (format nil "DS-P~D?" i))))
                                    ] ,(intern (format nil "K~D" i) :keyword)))))
      (ds/load-fol (format nil "(defmethod ~A ~{~S~^ ~})" fgen-name clauses)))

    ;; 4. FOL defn (closed predicate dispatch)
    (let ((clauses (loop for i below n
                         collect `([ (x (,(intern (format nil "DS-P~D?" i))))
                                    ] ,(intern (format nil "K~D" i) :keyword)))))
      (ds/load-fol (format nil "(defn ~A ~{~S~^ ~})" fdfn-name clauses)))

    (list clos-sym
          cond-sym
          (find-symbol (string-upcase fgen-name))
          (find-symbol (string-upcase fdfn-name))
          (subseq *ds-all-instances* 0 n))))

;;; ---------------------------------------------------------------------------
;;; Main
;;; ---------------------------------------------------------------------------

(defparameter *iterations* 1000000)
(defparameter *trials*     5)

(format t "~%FOL Dispatch Scaling Benchmark~%")
(format t "Iterations/trial: ~:D   Trials: ~D~%~%" *iterations* *trials*)
(format t "~5A  ~22A  ~8A  ~8A  ~6A~%"
         "N" "Method" "Mean(ns)" "Rng(ns)" "Ratio")
(format t "~60A~%" (make-string 60 :initial-element #\-))

(defparameter *results* '())

(dolist (n '(5 10 20 50))
  (format t "~%N = ~D  (setting up...)~%" n) (force-output)

  (destructuring-bind (clos-sym cond-sym fgen-sym fdfn-sym instances)
      (ds/setup n)

    ;; Warmup
    (dotimes (i 200)
      (funcall clos-sym (aref instances (mod i n)))
      (funcall cond-sym (random n))
      (funcall fgen-sym (random n))
      (funcall fdfn-sym (random n)))
    (sb-ext:gc :full t)

    (flet ((trials (fn)
             (loop repeat *trials* collect (ds/measure-ns fn *iterations*))))
      (let* ((clos-t (trials (lambda () (funcall clos-sym (aref instances (random n))))))
             (cond-t (trials (lambda () (funcall cond-sym (random n)))))
             (fgen-t (trials (lambda () (funcall fgen-sym (random n)))))
             (fdfn-t (trials (lambda () (funcall fdfn-sym (random n)))))
             (cm (ds/mean clos-t))
             (dm (ds/mean cond-t))
             (gm (ds/mean fgen-t))
             (fm (ds/mean fdfn-t)))

        (push (list n cm dm gm fm) *results*)

        (flet ((row (label mean ts)
                 (format t "~5D  ~22A  ~8,1F  ~8,1F  ~6,2Fx~%"
                         n label mean (ds/range ts) (/ mean (max 1d-9 cm)))))
          (row "CLOS Type"      cm clos-t)
          (row "Manual COND"    dm cond-t)
          (row "FOL defgeneric" gm fgen-t)
          (row "FOL defn"       fm fdfn-t))))
    (force-output)))

;;; Summary table for paper
(format t "~%~%=== Scaling Summary (mean ns/op) ===~%")
(format t "~5A  ~10A  ~10A  ~10A  ~10A  ~8A  ~8A  ~8A~%"
         "N" "CLOS" "COND" "FOL-defn" "FOL-gen" "COND/CL" "defn/CL" "gen/CL")
(format t "~80A~%" (make-string 80 :initial-element #\-))
(dolist (r (nreverse *results*))
  (destructuring-bind (n cm dm gm fm) r
    (format t "~5D  ~10,1F  ~10,1F  ~10,1F  ~10,1F  ~8,2Fx ~8,2Fx ~8,2Fx~%"
            n cm dm fm gm
            (/ dm (max 1d-9 cm))
            (/ fm (max 1d-9 cm))
            (/ gm (max 1d-9 cm)))))

(format t "~%Done.~%")
(sb-ext:exit :code 0)
