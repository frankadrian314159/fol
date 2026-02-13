;;; Electrical Netlist DSL - Pure Common Lisp Implementation
;;; Translated from lsim.fol

(defpackage :lsim
  (:use :cl)
  (:shadow *modules* *primitives*)
  (:export
   ;; Registry functions
   #:register-module
   #:get-module
   #:register-primitive
   #:get-primitive
   ;; Classes
   #:<component>
   #:<module-def>
   #:<logic-component>
   ;; Accessors
   #:component-name
   #:component-type
   #:component-connections
   #:component-inputs
   #:component-outputs
   #:component-delays
   #:component-logic-fn
   #:module-name
   #:module-ports
   #:module-body
   ;; Functions
   #:compute-next-state
   #:expand-netlist
   #:make-component
   #:make-module-def
   #:make-logic-component
   ;; Simulation
   #:run-simulation
   #:monitor
   #:events
   #:run
   #:display
   ;; Macros
   #:defpart))

(in-package :lsim)

;;; ---------------------------------------------------------------------------
;;; Utility Functions
;;; ---------------------------------------------------------------------------

(defun hash-get (ht key &optional default)
  "Get value from hash table, return DEFAULT if not found."
  (gethash key ht default))

(defun hash-set (ht key value)
  "Set value in hash table, return the hash table."
  (setf (gethash key ht) value)
  ht)

(defun hash-keys (ht)
  "Return list of keys in hash table."
  (loop for k being the hash-keys of ht collect k))

(defun set-member? (item set)
  "Check if ITEM is in SET (represented as a list)."
  (member item set :test #'equal))

(defun set-add (item set)
  "Add ITEM to SET (returns new list)."
  (adjoin item set :test #'equal))

(defun plist-get (plist key &optional default)
  "Get value from property list."
  (getf plist key default))

;;; ---------------------------------------------------------------------------
;;; 1. Global Registry
;;; ---------------------------------------------------------------------------

(defvar *modules* (make-hash-table :test 'equal)
  "Registry of all defined modules.")

(defvar *primitives* (make-hash-table :test 'equal)
  "Registry of all primitive component factories.")

(defun register-module (name def)
  "Register a module definition."
  (hash-set *modules* name def))

(defun get-module (name)
  "Retrieve a module definition by name."
  (hash-get *modules* name))

(defun register-primitive (name factory)
  "Register a primitive component factory function."
  (hash-set *primitives* name factory))

(defun get-primitive (name)
  "Retrieve a primitive factory by name."
  (hash-get *primitives* name))

;;; ---------------------------------------------------------------------------
;;; 2. Domain Classes
;;; ---------------------------------------------------------------------------

(defclass <component> ()
  ((name :initarg :name :accessor component-name)
   (type :initarg :type :accessor component-type)
   (connections :initarg :connections :accessor component-connections))
  (:documentation "Base component class."))

(defclass <module-def> ()
  ((name :initarg :name :accessor module-name)
   (ports :initarg :ports :accessor module-ports)
   (body :initarg :body :accessor module-body))
  (:documentation "Module definition class."))

(defclass <logic-component> (<component>)
  ((inputs :initarg :inputs :accessor component-inputs)
   (outputs :initarg :outputs :accessor component-outputs)
   (delays :initarg :delays :accessor component-delays)
   (logic-fn :initarg :logic-fn :accessor component-logic-fn))
  (:documentation "Logic component with timing delays."))

(defun make-component (&key name type connections)
  "Create a component instance."
  (make-instance '<component>
                 :name name
                 :type type
                 :connections connections))

(defun make-module-def (&key name ports body)
  "Create a module definition."
  (make-instance '<module-def>
                 :name name
                 :ports ports
                 :body body))

(defun make-logic-component (&key name type connections inputs outputs delays logic-fn)
  "Create a logic component instance."
  (make-instance '<logic-component>
                 :name name
                 :type (or type 'logic)
                 :connections connections
                 :inputs inputs
                 :outputs outputs
                 :delays delays
                 :logic-fn logic-fn))

;;; ---------------------------------------------------------------------------
;;; compute-next-state generic function
;;; ---------------------------------------------------------------------------

(defgeneric compute-next-state (comp input-states changed-inputs)
  (:documentation "Compute next state for a component given input states and changed inputs."))

(defmethod compute-next-state ((comp <component>) input-states changed-inputs)
  "Default: components don't produce outputs."
  (declare (ignore input-states changed-inputs))
  nil)

(defmethod compute-next-state ((comp <logic-component>) input-states changed-inputs)
  "Compute next state for logic component."
  (let* ((logic-fn (component-logic-fn comp))
         (delays (component-delays comp))
         (new-states (funcall logic-fn input-states)))
    (loop for out-port in (component-inputs comp)
          for delay = (reduce (lambda (max-d in-port)
                                (let ((d (hash-get (hash-get delays in-port (make-hash-table))
                                                   out-port 0)))
                                  (if (and d (> d max-d)) d max-d)))
                              changed-inputs
                              :initial-value 0)
          collect (list :port out-port
                       :value (hash-get new-states out-port)
                       :delay delay))))

;;; ---------------------------------------------------------------------------
;;; 2.5 Primitives Registry & Standard Gates
;;; ---------------------------------------------------------------------------

(register-primitive 'not
  (lambda (name param conns)
    (declare (ignore param))
    (let ((delays (make-hash-table :test 'equal))
          (in-delays (make-hash-table :test 'equal)))
      (setf (gethash :out in-delays) 1)
      (setf (gethash :in delays) in-delays)
      (make-logic-component
       :name name :type 'not :connections conns
       :inputs '(:in) :outputs '(:out)
       :delays delays
       :logic-fn (lambda (s)
                   (let ((ht (make-hash-table :test 'equal)))
                     (setf (gethash :out ht) (not (hash-get s :in)))
                     ht))))))

(register-primitive 'nand
  (lambda (name param conns)
    (declare (ignore param))
    (let ((delays (make-hash-table :test 'equal))
          (in1-delays (make-hash-table :test 'equal))
          (in2-delays (make-hash-table :test 'equal)))
      (setf (gethash :out in1-delays) 2)
      (setf (gethash :out in2-delays) 2)
      (setf (gethash :in1 delays) in1-delays)
      (setf (gethash :in2 delays) in2-delays)
      (make-logic-component
       :name name :type 'nand :connections conns
       :inputs '(:in1 :in2) :outputs '(:out)
       :delays delays
       :logic-fn (lambda (s)
                   (let ((ht (make-hash-table :test 'equal)))
                     (setf (gethash :out ht)
                           (not (and (hash-get s :in1) (hash-get s :in2))))
                     ht))))))

(register-primitive 'nor
  (lambda (name param conns)
    (declare (ignore param))
    (let ((delays (make-hash-table :test 'equal))
          (in1-delays (make-hash-table :test 'equal))
          (in2-delays (make-hash-table :test 'equal)))
      (setf (gethash :out in1-delays) 2)
      (setf (gethash :out in2-delays) 2)
      (setf (gethash :in1 delays) in1-delays)
      (setf (gethash :in2 delays) in2-delays)
      (make-logic-component
       :name name :type 'nor :connections conns
       :inputs '(:in1 :in2) :outputs '(:out)
       :delays delays
       :logic-fn (lambda (s)
                   (let ((ht (make-hash-table :test 'equal)))
                     (setf (gethash :out ht)
                           (not (or (hash-get s :in1) (hash-get s :in2))))
                     ht))))))

(register-primitive 'and
  (lambda (name param conns)
    (declare (ignore param))
    (let ((delays (make-hash-table :test 'equal))
          (in1-delays (make-hash-table :test 'equal))
          (in2-delays (make-hash-table :test 'equal)))
      (setf (gethash :out in1-delays) 3)
      (setf (gethash :out in2-delays) 3)
      (setf (gethash :in1 delays) in1-delays)
      (setf (gethash :in2 delays) in2-delays)
      (make-logic-component
       :name name :type 'and :connections conns
       :inputs '(:in1 :in2) :outputs '(:out)
       :delays delays
       :logic-fn (lambda (s)
                   (let ((ht (make-hash-table :test 'equal)))
                     (setf (gethash :out ht)
                           (and (hash-get s :in1) (hash-get s :in2)))
                     ht))))))

(register-primitive 'or
  (lambda (name param conns)
    (declare (ignore param))
    (let ((delays (make-hash-table :test 'equal))
          (in1-delays (make-hash-table :test 'equal))
          (in2-delays (make-hash-table :test 'equal)))
      (setf (gethash :out in1-delays) 3)
      (setf (gethash :out in2-delays) 3)
      (setf (gethash :in1 delays) in1-delays)
      (setf (gethash :in2 delays) in2-delays)
      (make-logic-component
       :name name :type 'or :connections conns
       :inputs '(:in1 :in2) :outputs '(:out)
       :delays delays
       :logic-fn (lambda (s)
                   (let ((ht (make-hash-table :test 'equal)))
                     (setf (gethash :out ht)
                           (or (hash-get s :in1) (hash-get s :in2)))
                     ht))))))

(register-primitive 'xor
  (lambda (name param conns)
    (declare (ignore param))
    (let ((delays (make-hash-table :test 'equal))
          (in1-delays (make-hash-table :test 'equal))
          (in2-delays (make-hash-table :test 'equal)))
      (setf (gethash :out in1-delays) 3)
      (setf (gethash :out in2-delays) 3)
      (setf (gethash :in1 delays) in1-delays)
      (setf (gethash :in2 delays) in2-delays)
      (make-logic-component
       :name name :type 'xor :connections conns
       :inputs '(:in1 :in2) :outputs '(:out)
       :delays delays
       :logic-fn (lambda (s)
                   (let* ((a (hash-get s :in1))
                          (b (hash-get s :in2))
                          (ht (make-hash-table :test 'equal)))
                     (setf (gethash :out ht)
                           (or (and a (not b)) (and (not a) b)))
                     ht))))))

(register-primitive 'xnor
  (lambda (name param conns)
    (declare (ignore param))
    (let ((delays (make-hash-table :test 'equal))
          (in1-delays (make-hash-table :test 'equal))
          (in2-delays (make-hash-table :test 'equal)))
      (setf (gethash :out in1-delays) 4)
      (setf (gethash :out in2-delays) 4)
      (setf (gethash :in1 delays) in1-delays)
      (setf (gethash :in2 delays) in2-delays)
      (make-logic-component
       :name name :type 'xnor :connections conns
       :inputs '(:in1 :in2) :outputs '(:out)
       :delays delays
       :logic-fn (lambda (s)
                   (let* ((a (hash-get s :in1))
                          (b (hash-get s :in2))
                          (ht (make-hash-table :test 'equal)))
                     (setf (gethash :out ht)
                           (not (or (and a (not b)) (and (not a) b))))
                     ht))))))

(register-primitive 'delay
  (lambda (name param conns)
    (let* ((d (or param 0))
           (delays (make-hash-table :test 'equal))
           (in-delays (make-hash-table :test 'equal)))
      (setf (gethash :out in-delays) d)
      (setf (gethash :in delays) in-delays)
      (make-logic-component
       :name name :type 'delay :connections conns
       :inputs '(:in) :outputs '(:out)
       :delays delays
       :logic-fn (lambda (s)
                   (let ((ht (make-hash-table :test 'equal)))
                     (setf (gethash :out ht) (hash-get s :in))
                     ht))))))

;;; ---------------------------------------------------------------------------
;;; 3. DSL Macros
;;; ---------------------------------------------------------------------------

(defmacro defpart (name ports &body body)
  "Define a module."
  `(register-module ',name
                    (make-module-def
                     :name ',name
                     :ports ',ports
                     :body ',body)))

;;; ---------------------------------------------------------------------------
;;; 4. Expansion Logic
;;; ---------------------------------------------------------------------------

(defun qualify-name (prefix name)
  "Qualify NAME with PREFIX."
  (if prefix
      (intern (format nil "~A/~A" prefix name))
      name))

(defun resolve-node (node-sym prefix bindings)
  "Resolve a node symbol to its qualified name or binding."
  (let ((binding (hash-get bindings node-sym)))
    (if binding
        binding
        (qualify-name prefix node-sym))))

(defun parse-connections (args prefix bindings)
  "Parse connection arguments into a hash table mapping ports to nodes."
  (let ((result (make-hash-table :test 'equal)))
    (loop for (port node-sym) on args by #'cddr
          do (let ((resolved (resolve-node node-sym prefix bindings)))
               (setf (gethash port result) resolved)))
    result))

(defun expand-spec (spec prefix bindings)
  "Expand a component specification into a list of component instances."
  (let* ((type (first spec))
         (name (second spec))
         (raw-args (cddr spec))
         ;; Check for optional parameter
         (has-param? (and raw-args (not (keywordp (first raw-args)))))
         (param (if has-param? (first raw-args) nil))
         (args (if has-param? (rest raw-args) raw-args))
         (full-name (qualify-name prefix name))
         (resolved-conns (parse-connections args prefix bindings))
         (module-def (get-module type))
         (primitive-factory (get-primitive type)))

    (cond
      (module-def
       ;; Composite module: expand recursively
       (let ((result nil))
         (dolist (child-spec (module-body module-def))
           (setf result (append result (expand-spec child-spec full-name resolved-conns))))
         result))

      (primitive-factory
       (list (funcall primitive-factory full-name param resolved-conns)))

      (t
       (list (make-component
              :name full-name
              :type type
              :connections resolved-conns))))))

(defun expand-netlist (top-module-name)
  "Expand a top-level module into a flat netlist."
  (let ((def (get-module top-module-name)))
    (when (null def)
      (error "Module ~A not found" top-module-name))
    ;; Bind top-level ports to themselves
    (let ((top-bindings (make-hash-table :test 'equal)))
      (dolist (p (module-ports def))
        (setf (gethash p top-bindings) p))
      (let ((result nil))
        (dolist (spec (module-body def))
          (setf result (append result (expand-spec spec nil top-bindings))))
        result))))

;;; ---------------------------------------------------------------------------
;;; 5. Simulation Engine
;;; ---------------------------------------------------------------------------

(defgeneric register-connectivity (comp map)
  (:documentation "Register component's input connectivity in the map."))

(defmethod register-connectivity ((comp <component>) map)
  "Default: do nothing."
  map)

(defmethod register-connectivity ((comp <logic-component>) map)
  "Register logic component's inputs in connectivity map."
  (dolist (port (component-inputs comp) map)
    (let* ((node (hash-get (component-connections comp) port))
           (comps (hash-get map node)))
      (setf (gethash node map) (cons comp comps)))))

(defun insert-event (queue event)
  "Insert EVENT into QUEUE maintaining time order."
  (if (null queue)
      (list event)
      (let ((head (first queue)))
        (if (< (plist-get event :time) (plist-get head :time))
            (cons event queue)
            (cons head (insert-event (rest queue) event))))))

(defun merge-events (queue new-events)
  "Merge NEW-EVENTS into QUEUE maintaining time order."
  (reduce #'insert-event new-events :initial-value queue))

(defun get-input-states (comp node-values)
  "Get input states for COMP from NODE-VALUES."
  (let ((result (make-hash-table :test 'equal)))
    (dolist (port (component-inputs comp) result)
      (let ((node (hash-get (component-connections comp) port)))
        (setf (gethash port result) (hash-get node-values node))))))

(defun get-changed-ports (comp changed-nodes)
  "Get list of input ports whose nodes changed."
  (remove-if-not
   (lambda (port)
     (let ((node (hash-get (component-connections comp) port)))
       (set-member? node changed-nodes)))
   (component-inputs comp)))

(defun run-simulation (netlist initial-events max-time monitored-nodes)
  "Run event-driven simulation."
  ;; Build connectivity map
  (let ((connectivity (make-hash-table :test 'equal)))
    (dolist (c netlist)
      (register-connectivity c connectivity))

    ;; Sort initial events by time
    (let ((queue (sort (copy-list initial-events) #'< :key (lambda (e) (plist-get e :time))))
          (node-values (make-hash-table :test 'equal))
          (event-history (make-hash-table :test 'equal))
          (current-time 0))

      (loop
        (when (or (null queue) (> current-time max-time))
          (return event-history))

        ;; Process batch of events at same time
        (let* ((event-time (plist-get (first queue) :time))
               (batch nil)
               (remaining queue))

          ;; Collect batch
          (loop while (and remaining
                          (= (plist-get (first remaining) :time) event-time))
                do (push (first remaining) batch)
                   (setf remaining (rest remaining)))
          (setf batch (nreverse batch))

          ;; Update state
          (dolist (evt batch)
            (setf (gethash (plist-get evt :node) node-values)
                  (plist-get evt :value)))

          ;; Update history for monitored nodes
          (dolist (evt batch)
            (when (set-member? (plist-get evt :node) monitored-nodes)
              (let ((node (plist-get evt :node)))
                (setf (gethash node event-history)
                      (append (hash-get event-history node nil) (list evt))))))

          ;; Find affected components
          (let* ((changed-nodes (mapcar (lambda (e) (plist-get e :node)) batch))
                 (affected-comps nil))
            (dolist (node changed-nodes)
              (dolist (comp (hash-get connectivity node))
                (pushnew comp affected-comps)))

            ;; Compute new events
            (let ((new-events nil))
              (dolist (comp affected-comps)
                (let* ((input-states (get-input-states comp node-values))
                       (changed-ports (get-changed-ports comp changed-nodes))
                       (results (compute-next-state comp input-states changed-ports)))
                  (dolist (res results)
                    (push (list :time (+ event-time (plist-get res :delay))
                               :node (hash-get (component-connections comp)
                                              (plist-get res :port))
                               :value (plist-get res :value))
                          new-events))))

              ;; Update queue and time
              (setf queue (merge-events remaining new-events))
              (setf current-time event-time))))))))

;;; ---------------------------------------------------------------------------
;;; 6. Simulation Shell
;;; ---------------------------------------------------------------------------

(defvar *sim-context* (list :monitored nil :events nil :history nil)
  "Simulation context (property list).")

(defun monitor (&rest nodes)
  "Add nodes to monitoring list."
  (setf (getf *sim-context* :monitored)
        (union (getf *sim-context* :monitored) nodes :test #'equal)))

(defun events (&rest event-list)
  "Add events to simulation queue."
  (setf (getf *sim-context* :events)
        (append (getf *sim-context* :events) event-list)))

(defun run (module-name time)
  "Run simulation for MODULE-NAME up to TIME."
  (let* ((netlist (expand-netlist module-name))
         (initial-events (getf *sim-context* :events))
         (monitored (getf *sim-context* :monitored))
         (history (run-simulation netlist initial-events time monitored)))
    (setf (getf *sim-context* :history) history)
    :simulation-complete))

(defun display (&rest nodes)
  "Display simulation results for NODES."
  (let ((history (getf *sim-context* :history)))
    (dolist (node nodes)
      (format t "Events for ~A:~%" node)
      (let ((evts (hash-get history node)))
        (if (null evts)
            (format t "  (no events)~%")
            (dolist (e evts)
              (format t "  T=~A V=~A~%" (plist-get e :time) (plist-get e :value))))))))
