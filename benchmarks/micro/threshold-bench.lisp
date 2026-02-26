;;; Persistent Object Slot-Copy Threshold Analysis
;;;
;;; Benchmarks the cost of functional (copy-on-write) object updates at five
;;; candidate thresholds for the native-slot / persistent-vector switchover:
;;;   T ∈ { 8, 12, 16, 24, 32 }
;;;
;;; For an N-slot object updated at threshold T:
;;;   N ≤ T  →  all-native strategy: allocate + copy N slots via slot-value
;;;   N > T  →  hybrid strategy:     allocate + copy T native slots
;;;                                   + build persistent vector of (N-T) elements
;;;
;;; The benchmark decomposes update cost into three independently measured
;;; components, then assembles modeled hybrid costs for each (N, T) cell:
;;;
;;;   1. allocate-instance cost (constant overhead in every update)
;;;   2. native slot-copy cost per slot (measured across a range of K)
;;;   3. persistent-vector build cost per K-element overflow (measured separately)
;;;
;;; For cross-validation, update-slots is also timed directly at the current
;;; hardcoded threshold (T=32) for objects sized near the boundary.

(defpackage :fol.benchmarks.threshold
  (:use :cl)
  (:import-from :fol.benchmarks :measure-run :format-time)
  (:import-from :fol.compiler.collection-primitives :%build-vec-t-from-list)
  (:import-from :fol.compiler.persistent
                :persistent-class :<persistent-object>
                :update-slot :update-slots)
  (:export :run-threshold-benchmarks))

(in-package :fol.benchmarks.threshold)

;;;; ============================================================
;;;; Utilities
;;;; ============================================================

(defun slot-sym (i) (intern (format nil "SLOT-~D" i)))
(defun slot-kw  (i) (intern (format nil "SLOT-~D" i) :keyword))

(defun make-std-class (n)
  "Define a standard (mutable) CLOS class with N slots, returning the class object."
  (let* ((name (intern (format nil "BENCH-STD-~D" n)))
         (slots (loop for i below n
                      collect `(,(slot-sym i) :initarg ,(slot-kw i) :initform ,i))))
    (eval `(defclass ,name () ,slots))
    (find-class name)))

(defun make-std-instance (class n)
  "Construct an instance of CLASS with N slots set to their index values."
  (apply #'make-instance class
         (loop for i below n append (list (slot-kw i) i))))

(defun make-persistent-class (n)
  "Define a persistent-class with N slots and return the class object."
  (let* ((name (intern (format nil "BENCH-PERS-~D" n)))
         (slots (loop for i below n
                      collect `(,(slot-sym i) :initarg ,(slot-kw i) :initform ,i))))
    (eval `(defclass ,name (fol.compiler.persistent:<persistent-object>)
             ,slots
             (:metaclass fol.compiler.persistent:persistent-class)))
    (find-class name)))

(defun make-persistent-instance (class n)
  (apply #'make-instance class
         (loop for i below n append (list (slot-kw i) i))))

(defun timed (thunk iterations)
  "Run THUNK ITERATIONS times; return seconds/operation."
  (multiple-value-bind (total-sec _bytes)
      (measure-run thunk iterations)
    (declare (ignore _bytes))
    (/ total-sec iterations)))

(defun memsec (thunk iterations)
  "Run THUNK ITERATIONS times; return (values sec/op bytes/op)."
  (multiple-value-bind (total-sec total-bytes)
      (measure-run thunk iterations)
    (values (/ total-sec   iterations)
            (/ total-bytes iterations))))

;;;; ============================================================
;;;; Component 1 – allocate-instance cost
;;;; ============================================================

(defun bench-allocate (class iterations)
  "Cost of a bare allocate-instance (no slot init)."
  (timed (lambda () (allocate-instance class)) iterations))

;;;; ============================================================
;;;; Component 2 – native slot-copy cost (K slots)
;;;; ============================================================

(defun bench-native-copy (src class effective-slots k iterations)
  "Cost of allocating + copying exactly K slots via slot-value/setf.
   Uses the same slot-boundp pattern as update-slots."
  (let ((slots-to-copy (subseq effective-slots 0 k)))
    (timed
     (lambda ()
       (let ((dst (allocate-instance class)))
         (dolist (slot slots-to-copy)
           (let ((sname (closer-mop:slot-definition-name slot)))
             (when (slot-boundp src sname)
               (setf (slot-value dst sname) (slot-value src sname)))))
         dst))
     iterations)))

;;;; ============================================================
;;;; Component 3 – persistent vector build cost (K elements)
;;;; ============================================================

(defun build-persistent-vec (values)
  "Build a <vector> from a CL list of values – matches what update-slots does."
  (let ((storage (%build-vec-t-from-list values)))
    (make-instance 'fol.compiler.collections:<vector> :storage storage)))

(defun bench-vec-build (k iterations)
  "Cost of building a K-element persistent vector from a pre-built list."
  (let ((vals (loop for i below k collect i)))
    (timed (lambda () (build-persistent-vec vals)) iterations)))

;;;; ============================================================
;;;; Component 4 – hybrid copy at threshold T (direct measurement)
;;;; ============================================================

(defun bench-hybrid-copy (src class effective-slots n threshold iterations)
  "Directly measure: allocate + copy first T native slots
   + (when N>T) build persistent vector of (N-T) overflow slot values."
  (let* ((native-k  (min n threshold))
         (overflow-k (max 0 (- n threshold)))
         (native-slots   (subseq effective-slots 0 native-k))
         (overflow-slots (when (> overflow-k 0)
                           (subseq effective-slots threshold n))))
    (timed
     (lambda ()
       (let ((dst (allocate-instance class)))
         ;; Copy native slots
         (dolist (slot native-slots)
           (let ((sname (closer-mop:slot-definition-name slot)))
             (when (slot-boundp src sname)
               (setf (slot-value dst sname) (slot-value src sname)))))
         ;; Build overflow persistent vector
         (when overflow-slots
           (let ((vals (loop for slot in overflow-slots
                             for sname = (closer-mop:slot-definition-name slot)
                             collect (if (slot-boundp src sname)
                                         (slot-value src sname)
                                         :unbound))))
             (build-persistent-vec vals)))
         dst))
     iterations)))

;;;; ============================================================
;;;; Validation – actual update-slots at T=32
;;;; ============================================================

(defun bench-actual-update-slots (pobj n iterations)
  "Time update-slots (real implementation, T=32) on POBJ with N user slots."
  (declare (ignore n))
  (let ((kw (slot-kw 0)))
    (timed (lambda () (update-slots pobj kw 99)) iterations)))

;;;; ============================================================
;;;; Main runner
;;;; ============================================================

(defparameter *thresholds*   '(8 12 16 24 32))
(defparameter *slot-counts*  '(4 8 12 16 20 24 28 32 40 48))
(defparameter *iters-alloc*  500000)
(defparameter *iters-native* 200000)
(defparameter *iters-vec*    200000)
(defparameter *iters-update* 100000)

(defun run-threshold-benchmarks ()
  (format t "~%~%~
================================================================~%~
  Slot-Copy Threshold Analysis~%~
  Candidate switchover points: T = ~{~D~^, ~}~%~
================================================================~%"
          *thresholds*)

  ;;; ----------------------------------------------------------
  ;;; Warmup
  ;;; ----------------------------------------------------------
  (format t "~%Warming up...~%")
  (let ((wc (make-std-class 8)))
    (dotimes (_ 5000)
      (allocate-instance wc)))
  (bench-vec-build 4 2000)
  (format t "Done.~%")

  ;;; ----------------------------------------------------------
  ;;; Section 1: Component costs
  ;;; ----------------------------------------------------------
  (format t "~%--- Section 1: Component costs ---~%~%")

  ;; 1a. allocate-instance baseline
  (let* ((cls32 (make-std-class 32))
         (t-alloc (bench-allocate cls32 *iters-alloc*)))
    (format t "  allocate-instance (32-slot std class): ~A/op~%~%" (format-time t-alloc))

    ;; 1b. Native slot copy cost vs K
    (format t "  Native slot copy cost (allocate + copy K slots):~%")
    (format t "  ~6A  ~12A~%" "K slots" "Time/op")
    (format t "  ~6A  ~12A~%" "-------" "--------")
    (let* ((big-class (make-std-class 64))
           (big-inst  (make-std-instance big-class 64))
           (eff-slots (closer-mop:class-slots big-class)))
      (dolist (k '(2 4 8 12 16 20 24 28 32 40 48 64))
        (let ((t-native (bench-native-copy big-inst big-class eff-slots k *iters-native*)))
          (format t "  ~6D  ~12A~%" k (format-time t-native)))))

    ;; 1c. Persistent vector build cost vs K
    (format t "~%  Persistent vector build cost (K overflow elements):~%")
    (format t "  ~6A  ~12A~%" "K elems" "Time/op")
    (format t "  ~6A  ~12A~%" "-------" "--------")
    (dolist (k '(1 2 4 8 12 16 20 24 32 40))
      (let ((t-vec (bench-vec-build k *iters-vec*)))
        (format t "  ~6D  ~12A~%" k (format-time t-vec)))))

  ;;; ----------------------------------------------------------
  ;;; Section 2: Per-(N,T) hybrid update cost
  ;;; ----------------------------------------------------------
  (format t "~%--- Section 2: Update cost (µs/op) at each (object-size, threshold) ---~%~%")

  ;; Print header row
  (format t "  ~5A |" "N")
  (dolist (thresh *thresholds*)
    (format t " ~10@A |" (format nil "T=~D" thresh)))
  (format t " ~12A |~%" "actual T=32")

  (let ((sep (make-string 5 :initial-element #\-)))
    (format t "  ~A-+" sep)
    (dolist (_ *thresholds*)
      (format t "------------+"))
    (format t "-------------+~%"))

  (dolist (n *slot-counts*)
    (let* ((std-class  (make-std-class n))
           (std-inst   (make-std-instance std-class n))
           (eff-slots  (closer-mop:class-slots std-class))
           ;; For actual T=32 validation, use a persistent class
           (pers-class (when (<= n 48)
                         (make-persistent-class n)))
           (pers-inst  (when pers-class
                         (make-persistent-instance pers-class n))))

      (format t "  ~5D |" n)

      ;; Hybrid cost at each threshold
      (dolist (thresh *thresholds*)
        (let ((t-hybrid (bench-hybrid-copy std-inst std-class eff-slots
                                           n thresh *iters-update*)))
          (format t " ~10,2F |" (* t-hybrid 1e6))))

      ;; Actual update-slots at T=32
      (if pers-inst
          (let ((t-actual (bench-actual-update-slots pers-inst n *iters-update*)))
            (format t " ~12,2F |" (* t-actual 1e6)))
          (format t " ~12A |" "N/A"))

      ;; Annotate what regime each threshold produces for this N
      (format t " [~{~A~^,~}]~%"
              (mapcar (lambda (thresh)
                        (if (<= n thresh) "all-N" (format nil "~DN+~DV" thresh (- n thresh))))
                      *thresholds*))))

  ;;; ----------------------------------------------------------
  ;;; Section 3: Recommended threshold per object size
  ;;; ----------------------------------------------------------
  (format t "~%--- Section 3: Optimal threshold per object size ---~%~%")
  (format t "  ~5A | ~10A | ~12A~%" "N" "Best T" "Predicted µs/op")
  (format t "  ~5A-+-~10A-+~12A~%" "-----" "----------" "------------")

  (dolist (n *slot-counts*)
    (let* ((std-class (make-std-class n))
           (std-inst  (make-std-instance std-class n))
           (eff-slots (closer-mop:class-slots std-class))
           (best-thresh nil)
           (best-time   nil))
      (dolist (thresh *thresholds*)
        (let ((t-hybrid (bench-hybrid-copy std-inst std-class eff-slots
                                           n thresh *iters-update*)))
          (when (or (null best-time) (< t-hybrid best-time))
            (setf best-thresh thresh
                  best-time   t-hybrid))))
      (format t "  ~5D | ~10D | ~12,2F~%"
              n best-thresh (* best-time 1e6))))

  (format t "~%Done.~%"))
