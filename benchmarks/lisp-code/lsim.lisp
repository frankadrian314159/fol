(defpackage :lsim-cl
  (:use :cl)
  (:export #:register-module #:get-module
           #:component #:module-def #:logic-component
           #:component-name #:component-type #:component-connections
           #:component-inputs #:component-outputs #:component-delays #:component-logic-fn
           #:module-name #:module-ports #:module-body
           #:compute-next-state #:register-primitive #:get-primitive
           #:expand-netlist #:expand-spec #:run-simulation
           #:sim-event #:make-sim-event #:sim-event-time #:sim-event-node #:sim-event-value
           #:gate-result #:make-gate-result
           #:monitor-nodes #:add-events #:run-lsim #:display-lsim
           #:*sim-monitored* #:*sim-events* #:*sim-history*
           #:make-dict #:run-bench))

(in-package :lsim-cl)

;; -----------------------------------------------------------------------------
;; Structs
;; -----------------------------------------------------------------------------

(defstruct (sim-event (:constructor make-sim-event (&key time node value)))
  (time 0 :type fixnum)
  (node nil :type symbol)
  (value 0 :type fixnum))

(defstruct (gate-result (:constructor make-gate-result (&key port value delay)))
  (port nil :type symbol)
  (value 0 :type fixnum)
  (delay 0 :type fixnum))

;; -----------------------------------------------------------------------------
;; Hash table utilities
;; -----------------------------------------------------------------------------

(defun make-dict (&rest pairs)
  "Create an EQ hash table from alternating key-value pairs."
  (let ((ht (make-hash-table :test 'eq :size (max 4 (ceiling (length pairs) 2)))))
    (loop for (k v) on pairs by #'cddr do (setf (gethash k ht) v))
    ht))

;; -----------------------------------------------------------------------------
;; 1. Global Registry
;; -----------------------------------------------------------------------------

(defvar *circuit-modules* (make-hash-table :test 'eq))
(defvar *primitives* (make-hash-table :test 'eq))

(defun register-module (name def)
  (setf (gethash name *circuit-modules*) def))

(defun get-module (name)
  (gethash name *circuit-modules*))

(defun register-primitive (name factory)
  (setf (gethash name *primitives*) factory))

(defun get-primitive (name)
  (gethash name *primitives*))

;; -----------------------------------------------------------------------------
;; 2. Domain Classes
;; -----------------------------------------------------------------------------

(defclass component ()
  ((name :initarg :name :accessor component-name)
   (ctype :initarg :type :accessor component-type)
   (connections :initarg :connections :accessor component-connections)))

(defclass module-def ()
  ((name :initarg :name :accessor module-name)
   (ports :initarg :ports :accessor module-ports)
   (body :initarg :body :accessor module-body)))

(defclass logic-component (component)
  ((inputs :initarg :inputs :accessor component-inputs)
   (outputs :initarg :outputs :accessor component-outputs)
   (delays :initarg :delays :accessor component-delays)
   (logic-fn :initarg :logic-fn :accessor component-logic-fn)))

(defgeneric compute-next-state (comp input-states changed-inputs))

(defmethod compute-next-state ((comp logic-component) input-states changed-inputs)
  (let* ((logic-fn (component-logic-fn comp))
         (delays (component-delays comp))
         (new-states (funcall logic-fn input-states)))
    (loop for out-port in (component-outputs comp)
          collect
          (let ((delay (reduce (lambda (max-d in-port)
                                 (let* ((inner (gethash in-port delays))
                                        (d (when inner (gethash out-port inner))))
                                   (if (and d (> d max-d)) d max-d)))
                               changed-inputs :initial-value 0)))
            (make-gate-result :port out-port
                              :value (gethash out-port new-states 0)
                              :delay delay)))))

;; -----------------------------------------------------------------------------
;; 2.5 Primitives Registry & Standard Gates
;; -----------------------------------------------------------------------------

(defun register-standard-gates ()
  (register-primitive 'not
    (lambda (name param conns)
      (declare (ignore param))
      (make-instance 'logic-component
        :name name :type 'not :connections conns
        :inputs '(:in) :outputs '(:out)
        :delays (make-dict :in (make-dict :out 1))
        :logic-fn (lambda (s) (make-dict :out (logxor (gethash :in s 0) 1))))))

  (register-primitive 'nand
    (lambda (name param conns)
      (declare (ignore param))
      (make-instance 'logic-component
        :name name :type 'nand :connections conns
        :inputs '(:in1 :in2) :outputs '(:out)
        :delays (make-dict :in1 (make-dict :out 2) :in2 (make-dict :out 2))
        :logic-fn (lambda (s)
                    (make-dict :out (logxor (logand (gethash :in1 s 0)
                                                   (gethash :in2 s 0)) 1))))))

  (register-primitive 'nor
    (lambda (name param conns)
      (declare (ignore param))
      (make-instance 'logic-component
        :name name :type 'nor :connections conns
        :inputs '(:in1 :in2) :outputs '(:out)
        :delays (make-dict :in1 (make-dict :out 2) :in2 (make-dict :out 2))
        :logic-fn (lambda (s)
                    (make-dict :out (logxor (logior (gethash :in1 s 0)
                                                   (gethash :in2 s 0)) 1))))))

  (register-primitive 'and
    (lambda (name param conns)
      (declare (ignore param))
      (make-instance 'logic-component
        :name name :type 'and :connections conns
        :inputs '(:in1 :in2) :outputs '(:out)
        :delays (make-dict :in1 (make-dict :out 3) :in2 (make-dict :out 3))
        :logic-fn (lambda (s)
                    (make-dict :out (logand (gethash :in1 s 0)
                                           (gethash :in2 s 0)))))))

  (register-primitive 'or
    (lambda (name param conns)
      (declare (ignore param))
      (make-instance 'logic-component
        :name name :type 'or :connections conns
        :inputs '(:in1 :in2) :outputs '(:out)
        :delays (make-dict :in1 (make-dict :out 3) :in2 (make-dict :out 3))
        :logic-fn (lambda (s)
                    (make-dict :out (logior (gethash :in1 s 0)
                                           (gethash :in2 s 0)))))))

  (register-primitive 'xor
    (lambda (name param conns)
      (declare (ignore param))
      (make-instance 'logic-component
        :name name :type 'xor :connections conns
        :inputs '(:in1 :in2) :outputs '(:out)
        :delays (make-dict :in1 (make-dict :out 3) :in2 (make-dict :out 3))
        :logic-fn (lambda (s)
                    (make-dict :out (logxor (gethash :in1 s 0)
                                           (gethash :in2 s 0)))))))

  (register-primitive 'xnor
    (lambda (name param conns)
      (declare (ignore param))
      (make-instance 'logic-component
        :name name :type 'xnor :connections conns
        :inputs '(:in1 :in2) :outputs '(:out)
        :delays (make-dict :in1 (make-dict :out 4) :in2 (make-dict :out 4))
        :logic-fn (lambda (s)
                    (make-dict :out (logxor (logxor (gethash :in1 s 0)
                                                   (gethash :in2 s 0)) 1))))))

  (register-primitive 'delay
    (lambda (name param conns)
      (let ((d (or param 0)))
        (make-instance 'logic-component
          :name name :type 'delay :connections conns
          :inputs '(:in) :outputs '(:out)
          :delays (make-dict :in (make-dict :out d))
          :logic-fn (lambda (s) (make-dict :out (gethash :in s 0))))))))

;; -----------------------------------------------------------------------------
;; 4. Expansion Logic
;; -----------------------------------------------------------------------------

(defun qualify-name (prefix name)
  (if (null prefix)
      name
      (intern (format nil "~A/~A" prefix name) :lsim-cl)))

(defun to-keyword (sym)
  (intern (symbol-name sym) :keyword))

(defun resolve-node (node-sym prefix bindings)
  (let ((kw (to-keyword node-sym)))
    (multiple-value-bind (val found) (gethash kw bindings)
      (if found val (qualify-name prefix node-sym)))))

(defun parse-connections (args prefix bindings)
  (let ((conns (make-hash-table :test 'eq :size (max 4 (ceiling (length args) 2)))))
    (loop for (port node-sym) on args by #'cddr
          do (setf (gethash port conns) (resolve-node node-sym prefix bindings)))
    conns))

(defun expand-spec (spec prefix bindings)
  (let* ((type (first spec))
         (name (second spec))
         (raw-args (cddr spec))
         (has-param (and raw-args (not (keywordp (car raw-args)))))
         (param (when has-param (car raw-args)))
         (args (if has-param (cdr raw-args) raw-args))
         (full-name (qualify-name prefix name))
         (resolved-conns (parse-connections args prefix bindings))
         (module-def (get-module type))
         (primitive-factory (get-primitive type)))
    (cond
      (module-def
       (loop for child-spec in (module-body module-def)
             nconc (expand-spec child-spec full-name resolved-conns)))
      (primitive-factory
       (list (funcall primitive-factory full-name param resolved-conns)))
      (t
       (list (make-instance 'component
               :name full-name :type type :connections resolved-conns))))))

(defun expand-netlist (top-module-name)
  (let ((def (get-module top-module-name)))
    (unless def (error "Module ~A not found" top-module-name))
    (let ((top-bindings (make-hash-table :test 'eq)))
      (dolist (p (module-ports def))
        (setf (gethash (to-keyword p) top-bindings) p))
      (loop for spec in (module-body def)
            nconc (expand-spec spec nil top-bindings)))))

;; -----------------------------------------------------------------------------
;; 5. Simulation Engine
;; -----------------------------------------------------------------------------

(defun build-connectivity (netlist)
  "Build hash table: node-symbol -> list of logic-components listening on that node."
  (let ((connectivity (make-hash-table :test 'eq)))
    (dolist (comp netlist)
      (when (typep comp 'logic-component)
        (dolist (port (component-inputs comp))
          (let ((node (gethash port (component-connections comp))))
            (push comp (gethash node connectivity))))))
    connectivity))

(defun insert-event (queue event)
  "Insert event into a time-sorted list."
  (if (null queue)
      (list event)
      (if (< (sim-event-time event) (sim-event-time (car queue)))
          (cons event queue)
          (cons (car queue) (insert-event (cdr queue) event)))))

(defun merge-events (queue new-events)
  "Merge a list of new events into a sorted queue."
  (reduce #'insert-event new-events :initial-value queue))

(defun get-input-states (comp node-values)
  "Build hash table: input-port -> current value from node-values."
  (let ((states (make-hash-table :test 'eq :size (length (component-inputs comp)))))
    (dolist (port (component-inputs comp))
      (let ((node (gethash port (component-connections comp))))
        (setf (gethash port states) (gethash node node-values 0))))
    states))

(defun get-changed-ports (comp changed-nodes)
  "Return list of input ports whose connected nodes are in changed-nodes set."
  (loop for port in (component-inputs comp)
        for node = (gethash port (component-connections comp))
        when (gethash node changed-nodes)
        collect port))

(defun run-simulation (netlist initial-events max-time monitored-nodes)
  "Run event-driven simulation. Returns hash table: node -> list of events (chronological)."
  (let ((connectivity (build-connectivity netlist))
        (node-values (make-hash-table :test 'eq))
        (event-history (make-hash-table :test 'eq))
        (queue (sort (copy-list initial-events) #'< :key #'sim-event-time))
        (current-time 0))
    (loop while (and queue (<= current-time max-time))
          do (let* ((event-time (sim-event-time (car queue)))
                    ;; Collect all events at this time
                    (batch (loop while (and queue
                                           (= (sim-event-time (car queue)) event-time))
                                collect (pop queue)))
                    (changed-nodes (make-hash-table :test 'eq)))
               ;; Apply updates to node values
               (dolist (evt batch)
                 (setf (gethash (sim-event-node evt) node-values) (sim-event-value evt))
                 (setf (gethash (sim-event-node evt) changed-nodes) t))
               ;; Record history for monitored nodes
               (dolist (evt batch)
                 (when (gethash (sim-event-node evt) monitored-nodes)
                   (push evt (gethash (sim-event-node evt) event-history))))
               ;; Find affected components
               (let ((affected (make-hash-table :test 'eq)))
                 (maphash (lambda (node _)
                            (declare (ignore _))
                            (dolist (comp (gethash node connectivity))
                              (setf (gethash comp affected) t)))
                          changed-nodes)
                 ;; Compute new events from affected components
                 (let ((new-events nil))
                   (maphash
                    (lambda (comp _)
                      (declare (ignore _))
                      (let* ((input-states (get-input-states comp node-values))
                             (changed-ports (get-changed-ports comp changed-nodes))
                             (results (compute-next-state comp input-states changed-ports)))
                        (dolist (res results)
                          (let* ((out-node (gethash (gate-result-port res)
                                                   (component-connections comp)))
                                 (current-val (gethash out-node node-values -1))
                                 (new-val (gate-result-value res)))
                            (when (/= new-val current-val)
                              (push (make-sim-event
                                     :time (+ event-time (gate-result-delay res))
                                     :node out-node
                                     :value new-val)
                                    new-events))))))
                    affected)
                   (setf queue (merge-events queue new-events))))
               (setf current-time event-time)))
    ;; Reverse history lists (built with push, need chronological order)
    (maphash (lambda (k v) (setf (gethash k event-history) (nreverse v)))
             event-history)
    event-history))

;; -----------------------------------------------------------------------------
;; 6. Simulation Shell
;; -----------------------------------------------------------------------------

(defvar *sim-monitored* (make-hash-table :test 'eq))
(defvar *sim-events* nil)
(defvar *sim-history* nil)

(defun monitor-nodes (&rest nodes)
  (dolist (n nodes)
    (setf (gethash n *sim-monitored*) t)))

(defun add-events (&rest events)
  (setf *sim-events* (merge-events *sim-events* events)))

(defun run-lsim (module-name time)
  (let ((netlist (expand-netlist module-name)))
    (setf *sim-history* (run-simulation netlist *sim-events* time *sim-monitored*))
    :simulation-complete))

(defun display-lsim ()
  (if (null *sim-history*)
      (format t "No simulation history found.~%")
      (progn
        (format t "Simulation Results:~%")
        (maphash (lambda (node _)
                   (declare (ignore _))
                   (let ((evts (gethash node *sim-history*)))
                     (format t "~%~A:~%" node)
                     (dolist (e evts)
                       (format t "  T=~3D  V=~A~%"
                               (sim-event-time e) (sim-event-value e)))))
                 *sim-monitored*))))

;; Initialize standard gates on load
(register-standard-gates)
