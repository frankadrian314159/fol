;;; Persistent Object Overhead Benchmarks
;;; Compare FOL persistent-class objects vs standard mutable CLOS objects
;;; across various slot counts, measuring construction, read, and update costs.
;;;
;;; Usage (from src/ directory):
;;;   sbcl --noinform --non-interactive \
;;;     --eval "(require :asdf)" \
;;;     --eval "(push (truename \".\") asdf:*central-registry*)" \
;;;     --eval "(asdf:load-system :fol-compiler)" \
;;;     --eval "(load \"../benchmarks/boilerplate/boilerplate.lisp\")" \
;;;     --eval "(load \"../benchmarks/micro/persistence-overhead.lisp\")" \
;;;     --eval "(fol.benchmarks.persistence:run-persistence-benchmarks)"
;;;
;;; If the full system won't load, minimal deps:
;;;     --eval "(ql:quickload '(:fset :sycamore :closer-mop))" \
;;;     --eval "(load \"package.lisp\")" \
;;;     --eval "(load \"persistence.lisp\")" \
;;;     --eval "(load \"../benchmarks/boilerplate/boilerplate.lisp\")" \
;;;     --eval "(load \"../benchmarks/micro/persistence-overhead.lisp\")" \
;;;     --eval "(fol.benchmarks.persistence:run-persistence-benchmarks)"

(defpackage :fol.benchmarks.persistence
  (:use :cl)
  (:import-from :fol.compiler.persistent
                :persistent-class :<persistent-object> :update-slot)
  (:import-from :fol.benchmarks
                :measure-run :format-bytes :format-time)
  (:export :run-persistence-benchmarks))

(in-package :fol.benchmarks.persistence)

;;; ============================================================================
;;; Dynamic Class Generation
;;; ============================================================================

(defun slot-name (i)
  "Generate a slot name symbol for index I."
  (intern (format nil "SLOT-~D" i)))

(defun slot-keyword (i)
  "Generate a keyword for slot index I."
  (intern (format nil "SLOT-~D" i) :keyword))

(defun make-test-classes (n)
  "Create a pair of classes with N slots: persistent-test-N and mutable-test-N.
   Returns (values persistent-class-name mutable-class-name slot-names)."
  (let* ((p-name (intern (format nil "PERSISTENT-TEST-~D" n)))
         (m-name (intern (format nil "MUTABLE-TEST-~D" n)))
         (slot-names (loop for i below n collect (slot-name i)))
         (slot-defs (loop for name in slot-names
                          for i from 0
                          collect `(,name :initarg ,(slot-keyword i)
                                          :initform 0))))
    ;; Persistent class
    (eval `(defclass ,p-name (fol.compiler.persistent:<persistent-object>)
             ,slot-defs
             (:metaclass fol.compiler.persistent:persistent-class)))
    ;; Mutable class
    (eval `(defclass ,m-name ()
             ,slot-defs))
    (values p-name m-name slot-names)))

(defun make-initargs (n)
  "Build initargs list (:slot-0 0 :slot-1 1 ... :slot-(n-1) (n-1))."
  (loop for i below n
        append (list (slot-keyword i) i)))

;;; ============================================================================
;;; Measurement Helpers
;;; ============================================================================

(defvar *hold-refs* nil "Hold references to prevent GC during measurement.")

(defun measure-allocation (thunk)
  "Measure bytes allocated by executing THUNK."
  (sb-ext:gc :full t)
  (let ((before (sb-ext:get-bytes-consed)))
    (funcall thunk)
    (- (sb-ext:get-bytes-consed) before)))

;;; ============================================================================
;;; Construction Benchmarks
;;; ============================================================================

(defun bench-construct-memory (class-name initargs num-instances)
  "Measure memory for constructing NUM-INSTANCES objects. Returns bytes per object."
  (setf *hold-refs* nil)
  (let ((alloc (measure-allocation
                (lambda ()
                  (setf *hold-refs*
                        (loop for i below num-instances
                              collect (apply #'make-instance class-name initargs)))))))
    (/ (float alloc) (max 1 num-instances))))

(defun bench-construct-time (class-name initargs iterations)
  "Measure time for constructing objects. Returns seconds per operation."
  (multiple-value-bind (total-time total-bytes)
      (measure-run (lambda () (apply #'make-instance class-name initargs))
                   iterations)
    (declare (ignore total-bytes))
    (/ total-time iterations)))

;;; ============================================================================
;;; Read Benchmarks
;;; ============================================================================

(defun bench-read-time (obj slot-name iterations)
  "Measure time for reading a slot. Returns seconds per operation."
  (multiple-value-bind (total-time total-bytes)
      (measure-run (lambda () (slot-value obj slot-name))
                   iterations)
    (declare (ignore total-bytes))
    (/ total-time iterations)))

;;; ============================================================================
;;; Update Benchmarks
;;; ============================================================================

(defun bench-update-persistent-time (obj slot-kw iterations)
  "Measure time for functional update of a persistent object. Returns seconds per op."
  (multiple-value-bind (total-time total-bytes)
      (measure-run (lambda () (update-slot obj slot-kw 42))
                   iterations)
    (declare (ignore total-bytes))
    (/ total-time iterations)))

(defun bench-update-mutable-time (obj slot-name iterations)
  "Measure time for in-place mutation. Returns seconds per operation."
  (multiple-value-bind (total-time total-bytes)
      (measure-run (lambda () (setf (slot-value obj slot-name) 42))
                   iterations)
    (declare (ignore total-bytes))
    (/ total-time iterations)))

;;; ============================================================================
;;; Main Runner
;;; ============================================================================

(defun run-persistence-benchmarks ()
  "Run all persistence overhead benchmarks and print results."
  (let ((slot-counts '(2 4 8 16 32 48 64 128))
        (mem-instances 10000)
        (construct-iters 100000)
        (read-iters 1000000)
        (update-iters 100000)
        ;; Accumulators for summary table
        (results nil))

    (format t "~%================================================================~%")
    (format t "  FOL Persistent Object Overhead Benchmarks~%")
    (format t "  Persistent-class (hybrid layout) vs Standard CLOS~%")
    (format t "  Objects with <= 32 slots use native CLOS slots~%")
    (format t "  Objects with > 32 slots use 32 native + FSet overflow~%")
    (format t "================================================================~%")

    ;; Warmup: create a small class and do some operations
    (format t "~%Warming up...~%")
    (multiple-value-bind (p-name m-name slot-names)
        (make-test-classes 2)
      (declare (ignore slot-names))
      (let ((initargs (make-initargs 2)))
        (dotimes (i 1000)
          (apply #'make-instance p-name initargs)
          (apply #'make-instance m-name initargs))))

    (dolist (n slot-counts)
      (format t "~%--- ~D slots ~A ---~%" n
              (if (<= n 32) "(all native)" "(hybrid: 32 native + overflow)"))

      (multiple-value-bind (p-name m-name slot-names)
          (make-test-classes n)
        (let* ((initargs (make-initargs n))
               (p-obj (apply #'make-instance p-name initargs))
               (m-obj (apply #'make-instance m-name initargs))
               (first-slot (first slot-names))
               (first-kw (slot-keyword 0)))

          ;; A. Construction memory
          (let ((p-bytes (bench-construct-memory p-name initargs mem-instances))
                (m-bytes (bench-construct-memory m-name initargs mem-instances)))
            (format t "  Construction memory:  Persistent=~,1F B/obj  Mutable=~,1F B/obj  Ratio=~,2Fx~%"
                    p-bytes m-bytes (/ p-bytes (max 0.001 m-bytes)))

            ;; B. Construction time
            (let ((p-time (bench-construct-time p-name initargs construct-iters))
                  (m-time (bench-construct-time m-name initargs construct-iters)))
              (format t "  Construction time:    Persistent=~A/op  Mutable=~A/op  Ratio=~,2Fx~%"
                      (format-time p-time) (format-time m-time)
                      (/ p-time (max 1e-15 m-time)))

              ;; C. Read time (native slot)
              (let ((p-read (bench-read-time p-obj first-slot read-iters))
                    (m-read (bench-read-time m-obj first-slot read-iters)))
                (format t "  Read time (slot-0):   Persistent=~A/op  Mutable=~A/op  Ratio=~,2Fx~%"
                        (format-time p-read) (format-time m-read)
                        (/ p-read (max 1e-15 m-read)))

                ;; C2. Read time (overflow slot, only for > 32)
                (when (> n 32)
                  (let* ((overflow-slot (slot-name 33))
                         (p-read-ov (bench-read-time p-obj overflow-slot read-iters))
                         (m-read-ov (bench-read-time m-obj overflow-slot read-iters)))
                    (format t "  Read time (slot-33):  Persistent=~A/op  Mutable=~A/op  Ratio=~,2Fx~%"
                            (format-time p-read-ov) (format-time m-read-ov)
                            (/ p-read-ov (max 1e-15 m-read-ov)))))

                ;; D. Update time (native slot)
                (let ((p-update (bench-update-persistent-time p-obj first-kw update-iters))
                      (m-update (bench-update-mutable-time m-obj first-slot update-iters)))
                  (format t "  Update time (slot-0): Persistent=~A/op  Mutable=~A/op  Ratio=~,2Fx~%"
                          (format-time p-update) (format-time m-update)
                          (/ p-update (max 1e-15 m-update)))

                  ;; D2. Update time (overflow slot, only for > 32)
                  (when (> n 32)
                    (let* ((overflow-kw (slot-keyword 33))
                           (overflow-slot (slot-name 33))
                           (p-upd-ov (bench-update-persistent-time p-obj overflow-kw update-iters))
                           (m-upd-ov (bench-update-mutable-time m-obj overflow-slot update-iters)))
                      (format t "  Update time (s-33):   Persistent=~A/op  Mutable=~A/op  Ratio=~,2Fx~%"
                              (format-time p-upd-ov) (format-time m-upd-ov)
                              (/ p-upd-ov (max 1e-15 m-upd-ov)))))

                  ;; D3. Update time (native slot on wide object, specifically to test optimization)
                  (when (= n 64)
                    (let ((p-update-wide (bench-update-persistent-time p-obj first-kw update-iters))
                          (m-update-wide (bench-update-mutable-time m-obj first-slot update-iters)))
                      (format t "  Update (native slot on 64-slot obj): Persistent=~A/op  Mutable=~A/op  Ratio=~,2Fx~%"
                              (format-time p-update-wide) (format-time m-update-wide)
                              (/ p-update-wide (max 1e-15 m-update-wide)))))

                  ;; Collect for summary
                  (push (list n p-bytes m-bytes p-time m-time p-update m-update)
                        results))))))))

    ;; Summary table
    (setf results (nreverse results))
    (format t "~%~%================================================================~%")
    (format t "  SUMMARY TABLE~%")
    (format t "================================================================~%")
    (format t "~%~5A | ~14A ~14A ~6A | ~12A ~12A ~6A~%"
            "Slots" "Constr(P)" "Constr(M)" "Ratio" "Update(P)" "Update(M)" "Ratio")
    (format t "------+-----------------------------------------------+---------------------------------~%")
    (dolist (r results)
      (destructuring-bind (n p-bytes m-bytes p-time m-time p-update m-update) r
        (format t "~5D | ~10,1F B  ~10,1F B  ~5,2Fx | ~10A ~10A ~5,2Fx~%"
                n p-bytes m-bytes (/ p-bytes (max 0.001 m-bytes))
                (format-time p-update) (format-time m-update)
                (/ p-update (max 1e-15 m-update)))))

    (format t "~%Done.~%")
    (setf *hold-refs* nil)))
