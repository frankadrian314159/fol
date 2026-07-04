;;; FOL Compiler - World Machinery (step 4)
;;;
;;; Soundness for escape-analysis optimizations in a LIVE image (see
;;; docs/escape-analysis-design.md section 5.2). A converted region (transient
;;; loop or reduce) is emitted dual-path:
;;;
;;;   (if (car (load-time-value (register-region '("ASSOC" "GET"))))
;;;       <optimized body>
;;;       <original body>)
;;;
;;; REGISTER-REGION runs once at load time, allocating a validity cell and
;;; indexing it under each summarized name the conversion assumed. When a
;;; definition executes at runtime (defn/defmethod -- hooked in compile-form),
;;; NOTE-REDEFINITION flips the cells of exactly the regions that assumed
;;; that name; their next entry takes the original path. In-flight loop
;;; iterations complete on the path they entered -- sound, because a converted
;;; region never calls user-redefinable functions on its accumulator (the
;;; classifier guarantees only compiler-owned transient ops and whitelisted
;;; reads touch it).
;;;
;;; The invalidation ladder implemented here:
;;;   rung 1 (panic switch): INVALIDATE-ALL-REGIONS
;;;   rung 2 (per-region cells + dependency map): REGISTER-REGION /
;;;          NOTE-REDEFINITION -- redefinitions of names no region assumed
;;;          invalidate nothing (the common case, measured in WORLD-STATS)
;;;   rung 3 (monotonic fast path): requires user-summary inference (L3);
;;;          not implemented -- redefinition of an assumed name always
;;;          invalidates its dependents
;;;   rung 4 (snapshot calls + tripwire recompilation): future work
;;;
;;; Batch transpiles may bind *SEALED-WORLD* to T to skip guard emission
;;; entirely (whole-program snapshot: nothing can be redefined afterwards).

(in-package :fol.compiler.world)

(defvar *world-lock* (bt:make-lock "fol-world"))

(defvar *sealed-world* nil
  "When true at emit time, converted regions are emitted WITHOUT guards.
   Only sound for batch-compiled, cold-loaded, non-self-modifying programs.")

;; name (string) -> list of region cells that assumed it.
;; A cell is (valid-p . assumption-names); regions live for the image
;; lifetime, so cells of dead code leak mildly -- acceptable at this scale.
(defvar *region-deps* (make-hash-table :test 'equal))

(defvar *regions-registered* 0)
(defvar *regions-invalidated* 0)
(defvar *redefinitions-noted* 0)
(defvar *redefinitions-invalidating* 0)

(defun register-region (assumption-names)
  "Allocate and index a validity cell for a converted region that assumed
   the summarized ASSUMPTION-NAMES (strings). Returns the cell; the emitted
   guard tests its CAR. Runs once per region at load time."
  (bt:with-lock-held (*world-lock*)
    (let ((cell (cons t assumption-names)))
      (incf *regions-registered*)
      (dolist (name assumption-names)
        (push cell (gethash (string-upcase (string name)) *region-deps*)))
      cell)))

(defun region-valid-p (cell)
  (car cell))

(defun note-redefinition (name)
  "Record that NAME was (re)defined at runtime. Invalidates exactly the
   regions whose conversion assumed NAME's Tier-1 meaning. Called from code
   emitted for defn/defmethod; cheap (one hash lookup) when no region
   depends on NAME."
  (bt:with-lock-held (*world-lock*)
    (incf *redefinitions-noted*)
    (let ((cells (gethash (string-upcase (string name)) *region-deps*)))
      (when cells
        (incf *redefinitions-invalidating*)
        (dolist (cell cells)
          (when (car cell)
            (setf (car cell) nil)
            (incf *regions-invalidated*)))
        (remhash (string-upcase (string name)) *region-deps*))))
  name)

(defun invalidate-all-regions ()
  "The panic switch (ladder rung 1): every converted region falls back to
   its original path at next entry."
  (bt:with-lock-held (*world-lock*)
    (maphash (lambda (name cells)
               (declare (ignore name))
               (dolist (cell cells)
                 (when (car cell)
                   (setf (car cell) nil)
                   (incf *regions-invalidated*))))
             *region-deps*)
    (clrhash *region-deps*))
  (values))

(defun reset-world ()
  "Testing helper: clear the registry and counters."
  (bt:with-lock-held (*world-lock*)
    (clrhash *region-deps*)
    (setf *regions-registered* 0
          *regions-invalidated* 0
          *redefinitions-noted* 0
          *redefinitions-invalidating* 0))
  (values))

(defun world-stats ()
  "Plist of counters: how many regions exist, how many were invalidated,
   and what fraction of redefinitions actually invalidated anything."
  (list :regions-registered *regions-registered*
        :regions-invalidated *regions-invalidated*
        :redefinitions-noted *redefinitions-noted*
        :redefinitions-invalidating *redefinitions-invalidating*))
