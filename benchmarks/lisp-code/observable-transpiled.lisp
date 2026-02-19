;;; =============================================================================
;;; Observable Slots - FOL transpiled output
;;; Hand-transpiled from fol-code/observable.fol following compiler emit patterns:
;;;   - defclass → persistent-class metaclass, Sycamore hash-map storage
;;;   - Dict literals → Sycamore hash-map
;;;   - defn → defvar + lambda
;;;   - update-slot for functional object updates (structural sharing)
;;;   - defmethod multi-clause → defun with cond dispatch
;;; =============================================================================

(defpackage :observable-transpiled
  (:use :cl)
  (:import-from :fol.compiler.persistent
                persistent-class <persistent-object>
                %persistent-storage update-slot)
  (:export #:<sensor>
           #:sensor-name
           #:sensor-reading
           #:sensor-status
           #:make-<sensor>
           #:updated
           #:on-change))

(in-package :observable-transpiled)

;;; ---------------------------------------------------------------------------
;;; 1. Domain class  (defclass <sensor> ...)
;;;    Compiler emit-defclass pattern: persistent metaclass + direct accessors
;;; ---------------------------------------------------------------------------

(defclass <sensor> (<persistent-object>)
  ((name    :initarg :name)
   (reading :initarg :reading :initform 0)
   (status  :initarg :status  :initform :normal))
  (:metaclass persistent-class))

;; Direct accessor functions (bypass MOP, read from Sycamore hash-map)
(defun sensor-name (object)
  (sycamore:hash-map-find (%persistent-storage object) :name))

(defun sensor-reading (object)
  (sycamore:hash-map-find (%persistent-storage object) :reading))

(defun sensor-status (object)
  (sycamore:hash-map-find (%persistent-storage object) :status))

;; Constructor
(defun make-<sensor> (&key name (reading 0) (status :normal))
  (make-instance '<sensor> :name name :reading reading :status status))

;;; ---------------------------------------------------------------------------
;;; 2. Change event as Sycamore hash-map (dict literal transpilation)
;;;    FOL: {:object obj :slot slot :old old-val :new new-val}
;;; ---------------------------------------------------------------------------

(defun make-change (obj slot old-val new-val)
  (let ((m (sycamore:make-hash-map)))
    (setf m (sycamore:hash-map-insert m :object obj))
    (setf m (sycamore:hash-map-insert m :slot slot))
    (setf m (sycamore:hash-map-insert m :old old-val))
    (setf m (sycamore:hash-map-insert m :new new-val))
    m))

;;; ---------------------------------------------------------------------------
;;; 3. Update function  (defn updated ...)
;;;    Uses update-slot for structural sharing (no manual copy)
;;; ---------------------------------------------------------------------------

(defun updated (obj slot new-val)
  (let* ((old-val (slot-value obj slot))
         (new-obj (update-slot obj slot new-val))
         (change (make-change obj slot old-val new-val)))
    ;; Return a dict with :object and :change keys
    (let ((m (sycamore:make-hash-map)))
      (setf m (sycamore:hash-map-insert m :object new-obj))
      (setf m (sycamore:hash-map-insert m :change change))
      m)))

;;; ---------------------------------------------------------------------------
;;; 4. Change notification  (defmethod on-change ...)
;;;    Predicate dispatch transpiled to cond with hash-map lookups
;;; ---------------------------------------------------------------------------

(defun on-change (event)
  "Route change notifications by inspecting the change hash-map."
  (let* ((change (sycamore:hash-map-find event :change))
         (slot   (sycamore:hash-map-find change :slot))
         (old-val (sycamore:hash-map-find change :old))
         (new-val (sycamore:hash-map-find change :new)))
    (cond
      ;; Spike detection: reading jumps by more than 50
      ((and (eq slot :reading)
            (numberp old-val)
            (numberp new-val)
            (> (- new-val old-val) 50))
       ;; Return a dict
       (let ((m (sycamore:make-hash-map)))
         (setf m (sycamore:hash-map-insert m :alert :spike))
         (setf m (sycamore:hash-map-insert m :message
                   (format nil "Spike detected: ~A -> ~A" old-val new-val)))
         m))

      ;; Status transition to :critical
      ((and (eq slot :status)
            (eq new-val :critical))
       (let ((m (sycamore:make-hash-map)))
         (setf m (sycamore:hash-map-insert m :alert :critical))
         (setf m (sycamore:hash-map-insert m :message
                   "Sensor entered critical state"))
         m))

      ;; Default: log the change
      (t
       (let ((m (sycamore:make-hash-map)))
         (setf m (sycamore:hash-map-insert m :alert :info))
         (setf m (sycamore:hash-map-insert m :message
                   (format nil "Slot ~A changed: ~A -> ~A"
                           slot old-val new-val)))
         m)))))
