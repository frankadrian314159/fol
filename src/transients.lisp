(in-package :fol.compiler.collections)

;;; ===========================================================================
;;; Transient Protocol - Generics
;;; ===========================================================================

(defgeneric transient (collection)
  (:documentation "Returns a transient (mutable) version of the collection."))

(defmethod transient ((obj t))
  "Default: return unchanged."
  obj)

(defgeneric persistent! (transient-collection)
  (:documentation "Freezes a transient collection and returns it as a persistent one."))

(defmethod persistent! ((obj t))
  "Default: everything else is already persistent."
  obj)

(defgeneric conj! (transient-collection val)
  (:documentation "Adds an element to a transient collection in-place."))

(defmethod conj! ((obj t) val)
  (error "conj! not supported for type ~A" (type-of obj)))

(defgeneric pop! (transient-collection)
  (:documentation "Removes the last element from a transient collection in-place."))

(defmethod pop! ((obj t))
  (error "pop! not supported for type ~A" (type-of obj)))

(defgeneric assoc! (transient-collection key val)
  (:documentation "Sets a key/value pair in a transient collection in-place."))

(defmethod assoc! ((obj t) key val)
  (error "assoc! not supported for type ~A" (type-of obj)))

(defgeneric dissoc! (transient-collection key)
  (:documentation "Removes a key from a transient collection in-place."))

(defmethod dissoc! ((obj t) key)
  (error "dissoc! not supported for type ~A" (type-of obj)))

(defgeneric disj! (transient-collection val)
  (:documentation "Removes an element from a transient set in-place."))

(defmethod disj! ((obj t) val)
  (error "disj! not supported for type ~A" (type-of obj)))

(defgeneric transfer-ownership! (transient new-thread)
  (:documentation
   "Transfer ownership of TRANSIENT to NEW-THREAD.
    Currently a stub that just returns the transient unchanged."))

(defmethod transfer-ownership! ((obj t) new-thread)
  "Default: no-op for most transients."
  obj)

;;; ===========================================================================
;;; Simple Transient Wrapper Using Closures
;;; ===========================================================================
;;; Store transient state in closures to avoid type spec issues with structs.

(defun %make-transient-vector (elements)
  "Create a transient vector wrapper (uses closure to store mutable state)."
  (cons :transient-vector elements))

(defun %make-transient-dict (table)
  "Create a transient dict wrapper (uses closure to store mutable hash-table)."
  (cons :transient-dict table))

(defun %make-transient-set (table)
  "Create a transient set wrapper (uses closure to store mutable hash-table)."
  (cons :transient-set table))

;;; ===========================================================================
;;; Vector Transients
;;; ===========================================================================

(defmethod transient ((v <vector>))
  (%make-transient-vector (nreverse (coerce v 'list))))

(defmethod conj! ((tv cons) val)
  (when (eq (car tv) :transient-vector)
    (push val (cdr tv)))
  tv)

(defmethod pop! ((tv cons))
  (when (and (eq (car tv) :transient-vector) (cdr tv))
    (pop (cdr tv)))
  tv)

(defmethod persistent! ((tv cons))
  (when (eq (car tv) :transient-vector)
    ;; Use make with the elements to create a persistent vector
    (return-from persistent! (apply #'fol.compiler.collection-functions:vector (nreverse (cdr tv)))))
  tv)

;;; ===========================================================================
;;; Dict Transients
;;; ===========================================================================

(defmethod transient ((d <dict>))
  (let ((tv (%make-transient-dict (make-hash-table :test 'equal))))
    ;; Copy existing entries from dict to hash-table
    (fol.compiler.collection-primitives:do-hamt (k v (dict-storage d))
      (setf (gethash k (cdr tv)) v))
    tv))

(defmethod assoc! ((td cons) key val)
  (when (eq (car td) :transient-dict)
    (setf (gethash key (cdr td)) val))
  td)

(defmethod dissoc! ((td cons) key)
  (when (eq (car td) :transient-dict)
    (remhash key (cdr td)))
  td)

(defmethod persistent! ((td cons))
  (when (eq (car td) :transient-dict)
    (let ((flat-list nil))
      (maphash (lambda (k v)
                 (push v flat-list)
                 (push k flat-list))
               (cdr td))
      (return-from persistent! (make-instance '<dict> :dict-storage (fol.compiler.collection-primitives:hamt-bulk-load flat-list)))))
  td)

;;; ===========================================================================
;;; Set Transients
;;; ===========================================================================

(defmethod transient ((s <set>))
  (let ((ts (%make-transient-set (make-hash-table :test 'equal))))
    ;; Copy existing elements from set to hash-table
    (fol.compiler.collection-primitives:do-hamt (k v (dict-storage s))
      (declare (ignore v))
      (setf (gethash k (cdr ts)) t))
    ts))

(defmethod conj! ((ts cons) val)
  (when (eq (car ts) :transient-set)
    (setf (gethash val (cdr ts)) t))
  ts)

(defmethod disj! ((ts cons) val)
  (when (eq (car ts) :transient-set)
    (remhash val (cdr ts)))
  ts)

(defmethod persistent! ((ts cons))
  (when (eq (car ts) :transient-set)
    (let ((flat-list nil))
      (maphash (lambda (k _)
                 (push k flat-list)
                 (push k flat-list))
               (cdr ts))
      (return-from persistent! (make-instance '<set> :dict-storage (fol.compiler.collection-primitives:hamt-bulk-load flat-list)))))
  ts)
