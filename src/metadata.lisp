;;; FOL Compiler - Metadata System
;;;
;;; Provides Clojure-style metadata operations for symbols, persistent objects,
;;; and collections. Metadata is stored as a FOL dict (Sycamore hash-map).
;;;
;;; For symbols: metadata stored in the symbol's plist under :%metadata
;;; For persistent objects: stored in the %metadata slot (bypasses hash-map)
;;; For collections: stored in the metadata slot (standard-object slot)

(in-package :fol.compiler.metadata)

;;; ============================================================================
;;; Helper: Copy a collection with new metadata
;;; ============================================================================

(defun %copy-collection-with-meta (coll new-meta)
  "Create a shallow copy of COLL with its metadata set to NEW-META.
   Copies all slots via the MOP."
  (let* ((class (class-of coll))
         (new-obj (allocate-instance class)))
    (dolist (slot (closer-mop:class-slots class))
      (let ((name (closer-mop:slot-definition-name slot)))
        (when (slot-boundp coll name)
          (setf (slot-value new-obj name) (slot-value coll name)))))
    (setf (collection-metadata new-obj) new-meta)
    new-obj))

;;; ============================================================================
;;; meta - Retrieve metadata
;;; ============================================================================

(defgeneric meta (obj)
  (:documentation "Returns the metadata associated with OBJ, or NIL if none.
   Works on symbols (plist :%metadata), persistent objects (%metadata slot),
   and collections (metadata slot)."))

(defmethod meta ((obj symbol))
  (cl:get obj :%metadata))

(defmethod meta ((obj <persistent-object>))
  (%persistent-metadata obj))

(defmethod meta ((obj <collection>))
  (collection-metadata obj))

(defmethod meta (obj)
  (declare (ignore obj))
  nil)

;;; ============================================================================
;;; with-meta - Return object with new metadata
;;; ============================================================================

(defgeneric with-meta (obj m)
  (:documentation "Returns an object of the same type and value as OBJ,
   with its metadata set to M (a dict). For symbols, mutates the plist
   (symbols are mutable in CL). For persistent objects and collections,
   returns a new instance sharing structure."))

(defmethod with-meta ((obj symbol) m)
  (setf (cl:get obj :%metadata) m)
  obj)

(defmethod with-meta ((obj <persistent-object>) m)
  (let* ((class (class-of obj))
         (new-obj (allocate-instance class)))
    (let ((fol.compiler.persistent::*initializing-persistent-object* t))
      ;; Copy all slots (MOP will handle the hybrid strategy)
      (dolist (slot (closer-mop:class-slots class))
        (let ((name (closer-mop:slot-definition-name slot)))
          (unless (eq name '%metadata)
            (when (slot-boundp obj name)
              (setf (slot-value new-obj name) (slot-value obj name))))))
      (setf (%persistent-metadata new-obj) m))
    new-obj))

(defmethod with-meta ((obj <collection>) m)
  (%copy-collection-with-meta obj m))

;;; ============================================================================
;;; vary-meta - Apply function to metadata
;;; ============================================================================

(defun vary-meta (obj f &rest args)
  "Returns an object of the same type and value as OBJ, with
   (apply f (meta obj) args) as its metadata."
  (with-meta obj (cl:apply f (meta obj) args)))

;;; ============================================================================
;;; alter-meta! - Mutate metadata in-place (symbols and mutable refs)
;;; ============================================================================

(defgeneric alter-meta! (obj f &rest args)
  (:documentation "Atomically alters the metadata of OBJ by applying
   (apply f current-meta args). Works on symbols and mutable refs."))

(defmethod alter-meta! ((obj symbol) f &rest args)
  (setf (cl:get obj :%metadata)
        (cl:apply f (cl:get obj :%metadata) args))
  (cl:get obj :%metadata))

;;; ============================================================================
;;; reset-meta! - Replace metadata in-place (symbols and mutable refs)
;;; ============================================================================

(defgeneric reset-meta! (obj new-meta)
  (:documentation "Atomically resets the metadata of OBJ to NEW-META.
   Works on symbols and mutable refs."))

(defmethod reset-meta! ((obj symbol) new-meta)
  (setf (cl:get obj :%metadata) new-meta)
  new-meta)

;;; ============================================================================
;;; doc - Retrieve :doc from metadata
;;; ============================================================================

(defun doc (name)
  "Returns the :doc entry from the metadata of NAME."
  (let ((m (meta name)))
    (when m
      (if (typep m 'fol.compiler.collections:<dict>)
          (fol.compiler.collections:get m :doc)
          (cl:getf m :doc)))))

;;; ============================================================================
;;; find-doc - Search all symbols for matching :doc
;;; ============================================================================

(defun find-doc (re-string)
  "Searches all accessible symbols for those with :doc metadata
   matching RE-STRING (case-insensitive). Returns a list of (symbol . doc) pairs."
  (let ((results nil)
        (scanner (cl-ppcre:create-scanner re-string :case-insensitive-mode t)))
    (do-all-symbols (sym)
      (let ((d (doc sym)))
        (when (and d (stringp d) (cl-ppcre:scan scanner d))
          (pushnew (cons sym d) results :key #'car))))
    results))

;;; ============================================================================
;;; test - Retrieve :test from metadata
;;; ============================================================================

(defun test (name)
  "Returns the :test entry from the metadata of NAME."
  (let ((m (meta name)))
    (when m
      (if (typep m 'fol.compiler.collections:<dict>)
          (fol.compiler.collections:get m :test)
          (cl:getf m :test)))))
