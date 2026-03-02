(in-package :fol.compiler.collections)

;;; ===========================================================================
;;; Transient Protocol
;;; ===========================================================================

(defgeneric transient (collection)
  (:documentation "Returns a transient (mutable) version of the collection."))

(defmethod transient ((obj t))
  "Default: return a simple wrapper for mutable operations."
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

;;; ===========================================================================
;;; Transient Wrapper Classes
;;; ===========================================================================
;;; Transients are wrappers around mutable Lisp structures that can be
;;; converted back to persistent collections.

(defstruct (transient-wrapper (:constructor %make-transient-wrapper)
                             (:copier nil))
  "Base wrapper for transient collections."
  (data nil))

(defstruct (transient-vector (:include transient-wrapper)
                             (:constructor %make-transient-vector))
  "Transient wrapper for vectors (mutable list internally).")

(defstruct (transient-dict (:include transient-wrapper)
                           (:constructor %make-transient-dict))
  "Transient wrapper for dicts (mutable hash-table internally).")

(defstruct (transient-set (:include transient-wrapper)
                          (:constructor %make-transient-set))
  "Transient wrapper for sets (mutable hash-table internally).")

;;; ===========================================================================
;;; Vector Transients
;;; ===========================================================================

(defmethod transient ((v <vector>))
  (%make-transient-vector :data (nreverse (coerce v 'list))))

(defmethod conj! ((tv transient-vector) val)
  (push val (transient-wrapper-data tv))
  tv)

(defmethod pop! ((tv transient-vector))
  (when (transient-wrapper-data tv)
    (pop (transient-wrapper-data tv)))
  tv)

(defmethod persistent! ((tv transient-vector))
  ;; Create a new vector from the collected elements
  (let* ((elements (nreverse (transient-wrapper-data tv)))
         (storage (fol.compiler.collection-primitives:%build-vec-t-from-list elements)))
    (make-instance '<vector> :storage storage)))

;;; ===========================================================================
;;; Dict Transients
;;; ===========================================================================

(defmethod transient ((d <dict>))
  (let ((tv (%make-transient-dict :data (make-hash-table :test 'equal))))
    ;; Copy existing entries from dict to hash-table
    (fol.compiler.collection-primitives:do-hamt (k v (dict-storage d))
      (setf (gethash k (transient-wrapper-data tv)) v))
    tv))

(defmethod assoc! ((td transient-dict) key val)
  (setf (gethash key (transient-wrapper-data td)) val)
  td)

(defmethod dissoc! ((td transient-dict) key)
  (remhash key (transient-wrapper-data td))
  td)

(defmethod persistent! ((td transient-dict))
  ;; Build a flat k1 v1 k2 v2... list
  (let ((flat-list nil))
    (maphash (lambda (k v)
               (push v flat-list)
               (push k flat-list))
             (transient-wrapper-data td))
    (make-instance '<dict> :dict-storage (fol.compiler.collection-primitives:hamt-bulk-load flat-list))))

;;; ===========================================================================
;;; Set Transients
;;; ===========================================================================

(defmethod transient ((s <set>))
  (let ((ts (%make-transient-set :data (make-hash-table :test 'equal))))
    ;; Copy existing elements from set to hash-table
    (fol.compiler.collection-primitives:do-hamt (k v (dict-storage s))
      (declare (ignore v))
      (setf (gethash k (transient-wrapper-data ts)) t))
    ts))

(defmethod conj! ((ts transient-set) val)
  (setf (gethash val (transient-wrapper-data ts)) t)
  ts)

(defmethod disj! ((ts transient-set) val)
  (remhash val (transient-wrapper-data ts))
  ts)

(defmethod persistent! ((ts transient-set))
  ;; Build a flat k1 k1 k2 k2... list (sets store k -> k)
  (let ((flat-list nil))
    (maphash (lambda (k _)
               (push k flat-list)
               (push k flat-list))
             (transient-wrapper-data ts))
    (make-instance '<set> :dict-storage (fol.compiler.collection-primitives:hamt-bulk-load flat-list))))

;;; ===========================================================================
;;; Ownership Transfer (stub for now)
;;; ===========================================================================

(defgeneric transfer-ownership! (transient new-thread)
  (:documentation
   "Transfer ownership of TRANSIENT to NEW-THREAD.
    Currently a stub that just returns the transient unchanged."))

(defmethod transfer-ownership! ((obj t) new-thread)
  "Default: no-op for most transients."
  obj)
