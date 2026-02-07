;;; =============================================================================
;;; MOP Integration Example - Custom Metaclass for Persistent Objects
;;; Demonstrates FOL's synergy between CLOS MOP and persistent data structures
;;; =============================================================================

(defpackage :fol.mop-example
  (:use :cl)
  (:export #:versioned-class
           #:versioned-object
           #:object-version
           #:object-history
           #:with-versioned-slot
           #:rollback-to-version
           #:get-version))

(in-package :fol.mop-example)

;;; ============================================================
;;; 1. Custom Metaclass: versioned-class
;;;    Automatically tracks version history for persistent objects
;;; ============================================================

(defclass versioned-class (standard-class)
  ((version-counter :initform 0
                    :accessor class-version-counter
                    :documentation "Next version number for instances"))
  (:documentation "Metaclass that tracks version history of instances.
                   Each slot update creates a new version with automatic tracking."))

(defmethod closer-mop:validate-superclass ((class versioned-class)
                                           (superclass standard-class))
  t)

;;; ============================================================
;;; 2. Versioned Object Base Class
;;; ============================================================

(defclass versioned-object ()
  ((version :initform 0
            :reader object-version
            :documentation "Version number of this object snapshot")
   (previous :initform nil
             :reader object-previous
             :documentation "Reference to previous version (for history chain)")
   (slots-map :initform (fset:empty-map)
              :accessor object-slots-map
              :documentation "FSet map storing slot values persistently"))
  (:metaclass versioned-class)
  (:documentation "Base class for objects with automatic version tracking.
                   Uses FSet maps for persistent slot storage with history."))

;;; ============================================================
;;; 3. Persistent Slot Update with Version Tracking
;;; ============================================================

(defun with-versioned-slot (object slot-name new-value)
  "Create a new version of OBJECT with SLOT-NAME set to NEW-VALUE.
   Returns a new object that references the old as its predecessor.

   Example:
     (let* ((p1 (make-instance 'person :name \"Alice\" :age 30))
            (p2 (with-versioned-slot p1 'age 31)))
       ;; p1 still has age 30
       ;; p2 has age 31 and points to p1 as predecessor
       (object-history p2)) ; => list of all versions
   "
  (let* ((old-map (object-slots-map object))
         (new-map (fset:with old-map slot-name new-value))
         (new-version (1+ (object-version object)))
         ;; Create new instance sharing structure
         (new-object (allocate-instance (class-of object))))
    ;; Initialize the new version
    (setf (slot-value new-object 'version) new-version)
    (setf (slot-value new-object 'previous) object)
    (setf (slot-value new-object 'slots-map) new-map)
    new-object))

(defun object-history (object &optional (max-depth 100))
  "Return list of all versions of OBJECT, newest first.
   MAX-DEPTH limits traversal to prevent infinite loops."
  (loop for v = object then (object-previous v)
        for i from 0 below max-depth
        while v
        collect v))

(defun get-version (object version-number)
  "Find a specific version of OBJECT by version number.
   Returns NIL if version not found in history."
  (find version-number (object-history object)
        :key #'object-version))

(defun rollback-to-version (object version-number)
  "Create a new version that matches the state at VERSION-NUMBER.
   This creates a new head version, preserving all history."
  (let ((target (get-version object version-number)))
    (if target
        (let ((new-object (allocate-instance (class-of object))))
          (setf (slot-value new-object 'version)
                (1+ (object-version object)))
          (setf (slot-value new-object 'previous) object)
          (setf (slot-value new-object 'slots-map)
                (object-slots-map target))
          new-object)
        (error "Version ~A not found in history" version-number))))

;;; ============================================================
;;; 4. Convenience Macros for Slot Access
;;; ============================================================

(defmacro define-versioned-class (name slots &rest options)
  "Define a class with versioned slots using the MOP.

   Example:
     (define-versioned-class person
       ((name :type string)
        (age :type integer)))

   This generates:
   - A class inheriting from versioned-object
   - Readers that access slots from the FSet map
   - 'with-*' functions that create new versions
   "
  (let ((slot-names (mapcar #'car slots)))
    `(progn
       (defclass ,name (versioned-object)
         ()
         (:metaclass versioned-class)
         ,@options)

       ;; Generate readers
       ,@(loop for slot-name in slot-names
               collect `(defmethod ,slot-name ((obj ,name))
                          (fset:@ (object-slots-map obj) ',slot-name)))

       ;; Generate constructor
       (defmethod initialize-instance :after ((obj ,name) &key ,@slot-names)
         (let ((map (fset:empty-map)))
           ,@(loop for slot-name in slot-names
                   collect `(when ,slot-name
                              (setf map (fset:with map ',slot-name ,slot-name))))
           (setf (object-slots-map obj) map)))

       ;; Generate with-* updaters
       ,@(loop for slot-name in slot-names
               for with-name = (intern (format nil "WITH-~A" slot-name))
               collect `(defun ,with-name (obj value)
                          (with-versioned-slot obj ',slot-name value)))

       ',name)))

;;; ============================================================
;;; 5. Example Usage
;;; ============================================================

(define-versioned-class person
  ((name :type string)
   (age :type integer)
   (email :type string)))

(defun demonstrate-versioned-objects ()
  "Demonstrate the MOP integration with persistent versioned objects."
  (format t "~%=== MOP Persistent Versioning Demo ===~%~%")

  ;; Create initial person
  (let* ((p1 (make-instance 'person :name "Alice" :age 30 :email "alice@example.com")))
    (format t "Created p1: ~A, age ~A (version ~A)~%"
            (name p1) (age p1) (object-version p1))

    ;; Update age - creates new version
    (let ((p2 (with-age p1 31)))
      (format t "Created p2: ~A, age ~A (version ~A)~%"
              (name p2) (age p2) (object-version p2))
      (format t "  p1 still has age: ~A~%" (age p1))

      ;; Update email - creates another version
      (let ((p3 (with-email p2 "alice.new@example.com")))
        (format t "Created p3 with new email (version ~A)~%"
                (object-version p3))

        ;; Show version history
        (format t "~%Version history of p3:~%")
        (dolist (v (object-history p3))
          (format t "  v~A: age=~A, email=~A~%"
                  (object-version v) (age v) (email v)))

        ;; Rollback to version 1
        (let ((p4 (rollback-to-version p3 1)))
          (format t "~%After rollback to v1:~%")
          (format t "  p4 (v~A): age=~A (matches v1 state)~%"
                  (object-version p4) (age p4))
          (format t "  History preserved - p4 has ~A versions in history~%"
                  (length (object-history p4))))))))

;; To run: (fol.mop-example::demonstrate-versioned-objects)
