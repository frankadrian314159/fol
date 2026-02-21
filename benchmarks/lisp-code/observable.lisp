;;; =============================================================================
;;; Observable Slots - Change notification in plain Common Lisp + CLOS
;;; Equivalent to fol-code/observable.fol
;;; =============================================================================

(defpackage :observable-cl
  (:use :cl)
  (:export #:sensor
           #:make-sensor
           #:sensor-name
           #:sensor-reading
           #:sensor-status
           #:update-sensor-slot
           #:on-change))

(in-package :observable-cl)

;;; ---------------------------------------------------------------------------
;;; 1. Domain class
;;; ---------------------------------------------------------------------------

(defclass sensor ()
  ((name    :initarg :name    :accessor sensor-name)
   (reading :initarg :reading :accessor sensor-reading :initform 0)
   (status  :initarg :status  :accessor sensor-status  :initform :normal)))

(defun make-sensor (&key name (reading 0) (status :normal))
  (make-instance 'sensor :name name :reading reading :status status))

;;; ---------------------------------------------------------------------------
;;; 2. Change event structure
;;; ---------------------------------------------------------------------------

(defstruct change-event
  object slot old-val new-val)

;;; ---------------------------------------------------------------------------
;;; 3. Update function - must manually construct change, copy object,
;;;    and set the slot.  No structural sharing; full object copy.
;;; ---------------------------------------------------------------------------

(defun copy-sensor (s)
  (make-instance 'sensor
    :name    (sensor-name s)
    :reading (sensor-reading s)
    :status  (sensor-status s)))

(defun update-sensor-slot (obj slot new-val)
  "Update a slot and return (values new-obj change-event).
   Manually copies the object and constructs a change record."
  (let* ((old-val (slot-value obj slot))
         (new-obj (copy-sensor obj)))
    (setf (slot-value new-obj slot) new-val)
    (values new-obj
            (make-change-event :object obj :slot slot
                               :old-val old-val :new-val new-val))))

;;; ---------------------------------------------------------------------------
;;; 4. Change notification - manual dispatch via cond
;;;    No predicate dispatch; must hand-code each condition and ordering.
;;; ---------------------------------------------------------------------------

(defun on-change (change)
  "Route change notifications by inspecting the change-event fields."
  (let ((slot    (change-event-slot change))
        (old-val (change-event-old-val change))
        (new-val (change-event-new-val change)))
    (cond
      ;; Spike detection: reading jumps by more than 50
      ((and (eq slot 'reading)
            (numberp old-val)
            (numberp new-val)
            (> (- new-val old-val) 50))
       (list :alert :spike
             :message (format nil "Spike detected: ~A -> ~A" old-val new-val)))

      ;; Status transition to :critical
      ((and (eq slot 'status)
            (eq new-val :critical))
       (list :alert :critical
             :message "Sensor entered critical state"))

      ;; Default: log the change
      (t
       (list :alert :info
             :message (format nil "Slot ~A changed: ~A -> ~A"
                              slot old-val new-val))))))
