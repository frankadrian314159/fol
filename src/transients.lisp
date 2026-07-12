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
;;; Edit-tagged transient classes (step 3.5)
;;; ===========================================================================
;;; O(1)/O(32) boundaries: TRANSIENT shares structure with the source
;;; (copying only the vector tail), bang ops mutate only nodes owned by this
;;; session (token-checked copy-on-write in collection-primitives), and
;;; PERSISTENT! freezes in time proportional to the nodes actually edited.
;;; Reads (get/nth/count/size/empty?) are supported mid-session -- see the
;;; methods in collection-functions.lisp. <SET> is "backed by a HAMT"
;;; (collections.lisp) exactly like <DICT> -- the same underlying storage,
;;; key=element/val=T -- so it gets the identical edit-tagged treatment
;;; below, not a separate representation.

(defclass <transient-dict> (standard-object)
    ((th :initarg :th :accessor transient-dict-th
         :documentation "The underlying transient-hamt struct."))
  (:documentation "An edit-tagged in-place transient dict."))

(defclass <transient-vector> (standard-object)
    ((tv :initarg :tv :accessor transient-vector-tv
         :documentation "The underlying transient-%vec-t struct."))
  (:documentation "An edit-tagged in-place transient vector."))

(defclass <transient-set> (standard-object)
    ((th :initarg :th :accessor transient-set-th
         :documentation "The underlying transient-hamt struct (key=element,
          val=T, exactly <SET>'s own persistent storage convention)."))
  (:documentation "An edit-tagged in-place transient set."))

(defvar *wrapper-transients* nil
  "Ablation flag (PLDI 2027 paper, RQ5): when true, TRANSIENT on <dict>/
   <vector>/<set> constructs the legacy wrapper representation below (O(n)
   at both TRANSIENT and PERSISTENT!, no mid-session reads) instead of the
   edit-tagged one, so the two boundary-cost models can be compared on
   identical source under the identical classifier/rewriter -- the only
   variable is which representation TRANSIENT hands back. Off by default:
   normal builds always get edit-tagged transients for all three.")

(defmethod transient ((d <dict>))
  (if *wrapper-transients*
      (let ((tw (%make-transient-dict (make-hash-table :test 'equal))))
        (fol.compiler.collection-primitives:do-hamt (k v (dict-storage d))
          (setf (gethash k (cdr tw)) v))
        tw)
      (make-instance '<transient-dict>
        :th (fol.compiler.collection-primitives:api-transient-hamt (dict-storage d)))))

(defmethod transient ((v <vector>))
  (if *wrapper-transients*
      (let* ((n (collection-size v))
             (arr (make-array n :adjustable t :fill-pointer n)))
        (dotimes (i n) (setf (aref arr i) (ref v i)))
        (%make-transient-vector arr))
      (make-instance '<transient-vector>
        :tv (fol.compiler.collection-primitives:transient-%vec-t (storage v)))))

(defmethod persistent! ((td <transient-dict>))
  (make-instance '<dict>
    :dict-storage (fol.compiler.collection-primitives:hamt-persistent!
                   (transient-dict-th td))))

(defmethod persistent! ((tv <transient-vector>))
  (make-instance '<vector>
    :storage (fol.compiler.collection-primitives:transient-%vec-t-persistent!
              (transient-vector-tv tv))))

(defmethod assoc! ((td <transient-dict>) key val)
  (fol.compiler.collection-primitives:hamt-assoc! (transient-dict-th td) key val)
  td)

(defmethod dissoc! ((td <transient-dict>) key)
  (fol.compiler.collection-primitives:hamt-dissoc! (transient-dict-th td) key)
  td)

(defmethod conj! ((tv <transient-vector>) val)
  (fol.compiler.collection-primitives:transient-%vec-t-conj!
   (transient-vector-tv tv) val)
  tv)

(defmethod transient ((s <set>))
  (if *wrapper-transients*
      (let ((ts (%make-transient-set (make-hash-table :test 'equal))))
        (fol.compiler.collection-primitives:do-hamt (k v (dict-storage s))
          (declare (ignore v))
          (setf (gethash k (cdr ts)) t))
        ts)
      (make-instance '<transient-set>
        :th (fol.compiler.collection-primitives:api-transient-hamt (dict-storage s)))))

(defmethod persistent! ((ts <transient-set>))
  (make-instance '<set>
    :dict-storage (fol.compiler.collection-primitives:hamt-persistent!
                   (transient-set-th ts))))

(defmethod conj! ((ts <transient-set>) val)
  (fol.compiler.collection-primitives:hamt-assoc! (transient-set-th ts) val t)
  ts)

(defmethod disj! ((ts <transient-set>) val)
  (fol.compiler.collection-primitives:hamt-dissoc! (transient-set-th ts) val)
  ts)

;;; ===========================================================================
;;; Legacy wrapper transients (RQ5 ablation only -- fol.compiler.collections:
;;; *wrapper-transients*; see TRANSIENT ((s <set>)) above. Never reached by
;;; normal builds.)
;;; ===========================================================================

(defmethod persistent! ((tv cons))
  (case (car tv)
    (:transient-vector
     (make-instance '<vector>
       :storage (fol.compiler.collection-primitives:%build-vec-t-from-list (coerce (cdr tv) 'cl:list))))
    (:transient-dict
     (let ((flat-list nil))
       (maphash (lambda (k v)
                  (push k flat-list)
                  (push v flat-list))
                (cdr tv))
       (make-instance '<dict>
         :dict-storage (fol.compiler.collection-primitives:hamt-bulk-load (nreverse flat-list)))))
    (:transient-set
     (let ((flat-list nil))
       (maphash (lambda (k v)
                  (declare (ignore v))
                  (push k flat-list)
                  (push k flat-list))
                (cdr tv))
       (make-instance '<set>
         :dict-storage (fol.compiler.collection-primitives:hamt-bulk-load (nreverse flat-list)))))
    (t tv)))

(defmethod conj! ((tv cons) val)
  (case (car tv)
    (:transient-vector
     (vector-push-extend val (cdr tv)))
    (:transient-set
     (setf (gethash val (cdr tv)) t))
    (t (error "conj! not supported for transient ~A" (car tv))))
  tv)

(defmethod pop! ((tv cons))
  (case (car tv)
    (:transient-vector
     (if (> (length (cdr tv)) 0)
         (vector-pop (cdr tv))
         (error "pop! from empty transient vector")))
    (t (error "pop! not supported for transient ~A" (car tv))))
  tv)

(defmethod assoc! ((td cons) key val)
  (case (car td)
    (:transient-dict
     (setf (gethash key (cdr td)) val))
    (:transient-vector
     ;; Parity with persistent vector assoc: index == count appends.
     (if (= key (length (cdr td)))
         (vector-push-extend val (cdr td))
         (setf (aref (cdr td) key) val)))
    (t (error "assoc! not supported for transient ~A" (car td))))
  td)

(defmethod dissoc! ((td cons) key)
  (case (car td)
    (:transient-dict
     (remhash key (cdr td)))
    (t (error "dissoc! not supported for transient ~A" (car td))))
  td)

(defmethod disj! ((ts cons) val)
  (case (car ts)
    (:transient-set
     (remhash val (cdr ts)))
    (t (error "disj! not supported for transient ~A" (car ts))))
  ts)
