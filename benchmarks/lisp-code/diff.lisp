;;; =============================================================================
;;; Structural Diff Pattern - Plain Common Lisp equivalent of diff.fol
;;;
;;; Demonstrates the boilerplate burden of manual diff tracking: to compare
;;; before and after a slot update, the caller must explicitly capture old
;;; values before the update and compare them afterwards.  In FOL, the
;;; :around assoc method has access to both the pre-update snapshot (its
;;; first argument) and the post-update snapshot (call-next-method result)
;;; simultaneously -- no explicit copy is ever needed.
;;; =============================================================================

(defpackage :diff-cl
  (:use :cl)
  (:export #:make-metric #:run-bench))

(in-package :diff-cl)

;;; Immutable metric struct -- READ-ONLY slots enforce value semantics.
;;; Each update produces a fresh struct, mirroring FOL's persistent objects.
(defstruct (metric (:constructor %make-metric) (:copier nil))
  (cpu     0.0 :read-only t)
  (memory  0.0 :read-only t)
  (disk    0.0 :read-only t)
  (net     0.0 :read-only t)
  (iops    0   :read-only t)
  ;; Explicit change counter.  In FOL this field lives on <diffable> and is
  ;; maintained automatically by the :around assoc method.  Here it must be
  ;; hand-computed and threaded through every update call.
  (changes 0   :read-only t))

(defun make-metric (&key (cpu 0.0) (memory 0.0) (disk 0.0) (net 0.0) (iops 0))
  (%make-metric :cpu cpu :memory memory :disk disk :net net :iops iops :changes 0))

;;; ---------------------------------------------------------------------------
;;; In CL there is no cross-cutting hook on slot updates.
;;;
;;; To detect which slots changed between two versions we must:
;;;   1. Capture the old field values explicitly BEFORE creating the new struct.
;;;   2. Compare each captured value against the corresponding new value.
;;;
;;; This snapshot + compare code is class-specific: it must be written (and
;;; kept in sync) for every struct that wants diff tracking.  In FOL a single
;;; :around assoc method on <diffable> handles all subclasses automatically
;;; with no per-class boilerplate.
;;; ---------------------------------------------------------------------------
(defun %update-all (m i)
  "Build a new metric struct with all five slots updated.
   Explicitly saves the old values, builds the new struct, then counts
   how many slots changed -- the before/after comparison that FOL's
   :around assoc performs automatically and centrally."
  (let* ((new-cpu    (+ 1.0 i))
         (new-memory (+ 2.0 i))
         (new-disk   (+ 3.0 i))
         (new-net    (+ 4.0 i))
         (new-iops   (1+ i))
         ;; Step 1: explicit before-snapshot (manual, class-specific)
         (old-cpu    (metric-cpu    m))
         (old-memory (metric-memory m))
         (old-disk   (metric-disk   m))
         (old-net    (metric-net    m))
         (old-iops   (metric-iops   m))
         ;; Step 2: count changes by comparing new vs saved old (manual, class-specific)
         (n 0))
    (when (/= old-cpu    new-cpu)    (incf n))
    (when (/= old-memory new-memory) (incf n))
    (when (/= old-disk   new-disk)   (incf n))
    (when (/= old-net    new-net)    (incf n))
    (when (/= old-iops   new-iops)   (incf n))
    ;; Step 3: build the new struct with the change count embedded
    (%make-metric :cpu new-cpu :memory new-memory :disk new-disk
                  :net new-net :iops new-iops :changes n)))

(defun run-bench (iterations)
  "Run ITERATIONS rounds of 5-slot updates, returning total detected changes.
   The expected result is 5 * ITERATIONS."
  (let ((m (make-metric))
        (total 0))
    (dotimes (i iterations total)
      (setf m (%update-all m i))
      (incf total (metric-changes m)))))
