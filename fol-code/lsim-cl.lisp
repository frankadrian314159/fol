;;; Hand-written Common Lisp version of lsim
;;; Electrical Netlist DSL - Native CL implementation for performance comparison

(in-package :fol-sim)

;;; ===========================================================================
;;; Global Registry
;;; ===========================================================================

(defvar *modules* (fol.compiler.mutable:atom (sycamore:make-hash-map)))

(defun register-module (name def)
  (fol.compiler.mutable:swap! *modules*
    (lambda (m) (sycamore:hash-map-insert m name def))))

(defun get-module (name)
  (sycamore:hash-map-find (fol.compiler.mutable:deref *modules*) name))

;;; ===========================================================================
;;; Domain Classes (using persistent-object system)
;;; ===========================================================================

(defclass <component> (fol.compiler.persistent:<persistent-object>)
  ((name :initarg :name :reader component-name)
   (type :initarg :type :reader component-type)
   (connections :initarg :connections :reader component-connections)))

(defclass <module-def> (fol.compiler.persistent:<persistent-object>)
  ((name :initarg :name :reader module-name)
   (ports :initarg :ports :reader module-ports)
   (body :initarg :body :reader module-body)))

(defclass <logic-component> (<component>)
  ((inputs :initarg :inputs :reader component-inputs)
   (outputs :initarg :outputs :reader component-outputs)
   (delays :initarg :delays :reader component-delays)
   (logic-fn :initarg :logic-fn :reader component-logic-fn)))

;;; ===========================================================================
;;; Component State Computation
;;; ===========================================================================

(defgeneric compute-next-state (comp input-states changed-inputs))

(defmethod compute-next-state ((comp <logic-component>) input-states changed-inputs)
  (let* ((logic-fn (component-logic-fn comp))
         (delays (component-delays comp))
         (new-states (funcall logic-fn input-states))
         (outputs (component-outputs comp)))
    ;; Convert FSet seq to list for iteration
    (let ((output-list (fol.compiler.collections:collection-seq outputs))
          (changed-list (fol.compiler.collections:collection-seq changed-inputs))
          (results '()))
      (dolist (out-port output-list)
        (let ((max-delay 0))
          ;; Compute max delay from changed inputs
          (dolist (in-port changed-list)
            (multiple-value-bind (port-delays found)
                (sycamore:hash-map-find delays in-port)
              (when found
                (multiple-value-bind (delay dfound)
                    (sycamore:hash-map-find port-delays out-port)
                  (when (and dfound (> delay max-delay))
                    (setf max-delay delay))))))
          ;; Create result dict
          (push (fol.compiler.collection-functions:dict
                 :port out-port
                 :value (sycamore:hash-map-find new-states out-port)
                 :delay max-delay)
                results)))
      ;; Return as FSet vector
      (apply #'fol.compiler.collections:make
             'fol.compiler.collections:<vector>
             (nreverse results)))))

;;; ===========================================================================
;;; Module Expansion
;;; ===========================================================================

(defgeneric register-connectivity (comp map))

(defmethod register-connectivity (comp map)
  (declare (ignore comp))
  map)

(defmethod register-connectivity ((comp <logic-component>) map)
  (let ((connections (component-connections comp))
        (inputs (component-inputs comp))
        (result map))
    (dolist (port (fol.compiler.collections:collection-seq inputs) result)
      (let ((node (sycamore:hash-map-find connections port)))
        (setf result
              (sycamore:hash-map-insert
               result node
               (fset:with-last
                (or (sycamore:hash-map-find result node)
                    (fset:empty-seq))
                comp)))))))

;;; ===========================================================================
;;; Event Queue Management
;;; ===========================================================================

(defun insert-event (queue event)
  "Insert event into sorted queue by time."
  (let ((event-time (sycamore:hash-map-find event :time)))
    (if (fol.compiler.collection-functions:empty? queue)
        (fol.compiler.collections:make 'fol.compiler.collections:<vector> event)
        (let* ((seq (fol.compiler.collections:collection-seq queue))
               (head (cl:first seq))
               (head-time (sycamore:hash-map-find head :time)))
          (if (< event-time head-time)
              (fol.compiler.collections:make 'fol.compiler.collections:<vector>
                                             event head)
              (apply #'fol.compiler.collections:make
                     'fol.compiler.collections:<vector>
                     head
                     (fol.compiler.collections:collection-seq
                      (insert-event
                       (apply #'fol.compiler.collections:make
                              'fol.compiler.collections:<vector>
                              (cl:rest seq))
                       event))))))))

(defun merge-events (queue new-events)
  "Merge new events into queue."
  (let ((result queue))
    (dolist (event (fol.compiler.collections:collection-seq new-events) result)
      (setf result (insert-event result event)))))

;;; ===========================================================================
;;; Component Input/Output Helpers
;;; ===========================================================================

(defun get-input-states (comp node-values)
  "Get current values for all component inputs."
  (let ((connections (component-connections comp))
        (inputs (component-inputs comp))
        (result (sycamore:make-hash-map)))
    (dolist (port (fol.compiler.collections:collection-seq inputs) result)
      (let ((node (sycamore:hash-map-find connections port)))
        (setf result
              (sycamore:hash-map-insert
               result port
               (sycamore:hash-map-find node-values node)))))))

(defun get-changed-ports (comp changed-nodes)
  "Filter component inputs to only those connected to changed nodes."
  (let ((connections (component-connections comp))
        (inputs (component-inputs comp))
        (result '()))
    (dolist (port (fol.compiler.collections:collection-seq inputs))
      (let ((node (sycamore:hash-map-find connections port)))
        (when (sycamore:hash-set-find changed-nodes node)
          (push port result))))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector>
           (nreverse result))))

;;; ===========================================================================
;;; Main Simulation Loop (HAND-OPTIMIZED)
;;; ===========================================================================

(defun run-simulation (netlist initial-events max-time monitored-nodes)
  "Core discrete event simulation loop - hand-optimized CL version."
  ;; Build connectivity map
  (let ((connectivity (sycamore:make-hash-map)))
    (dolist (comp (fol.compiler.collections:collection-seq netlist))
      (setf connectivity (register-connectivity comp connectivity)))

    ;; Sort initial events by time
    (let* ((event-seq (fol.compiler.collections:collection-seq initial-events))
           (sorted-events (cl:sort (cl:copy-list event-seq) #'<
                                   :key (lambda (e) (sycamore:hash-map-find e :time))))
           (queue (apply #'fol.compiler.collections:make
                        'fol.compiler.collections:<vector>
                        sorted-events)))

      ;; Main simulation loop
      (cl:labels ((sim-loop (queue node-values event-history current-time)
                    (if (or (fol.compiler.collection-functions:empty? queue)
                            (> current-time max-time))
                        event-history
                        (let* ((queue-seq (fol.compiler.collections:collection-seq queue))
                               (first-event (cl:first queue-seq))
                               (event-time (sycamore:hash-map-find first-event :time))

                               ;; Extract batch of events at same time
                               (batch '())
                               (remaining queue-seq))

                          ;; Collect batch
                          (loop while (and remaining
                                          (= (sycamore:hash-map-find (cl:first remaining) :time)
                                             event-time))
                                do (push (cl:first remaining) batch)
                                   (setf remaining (cl:rest remaining)))

                          (setf batch (nreverse batch))

                          ;; Update node values
                          (let ((updates (sycamore:make-hash-map)))
                            (dolist (evt batch)
                              (setf updates
                                    (sycamore:hash-map-insert
                                     updates
                                     (sycamore:hash-map-find evt :node)
                                     (sycamore:hash-map-find evt :value))))

                            (let ((new-node-values node-values))
                              ;; Merge updates into node-values
                              (sycamore:do-hash-map ((k v) updates)
                                (setf new-node-values
                                      (sycamore:hash-map-insert new-node-values k v)))

                              ;; Update history for monitored nodes
                              (let ((new-event-history event-history))
                                (dolist (evt batch)
                                  (let ((node (sycamore:hash-map-find evt :node)))
                                    (when (sycamore:hash-set-find monitored-nodes node)
                                      (let ((existing (or (sycamore:hash-map-find new-event-history node)
                                                         (fset:empty-seq))))
                                        (setf new-event-history
                                              (sycamore:hash-map-insert
                                               new-event-history node
                                               (fset:with-last existing evt)))))))

                                ;; Get changed nodes
                                (let ((changed-nodes (sycamore:make-hash-set)))
                                  (dolist (evt batch)
                                    (setf changed-nodes
                                          (sycamore:hash-set-insert
                                           changed-nodes
                                           (sycamore:hash-map-find evt :node))))

                                  ;; Find affected components (PARALLEL in pmapcat version)
                                  (let ((affected-comps (sycamore:make-hash-set)))
                                    (sycamore:do-hash-set (node changed-nodes)
                                      (let ((comps (sycamore:hash-map-find connectivity node)))
                                        (when comps
                                          (dolist (comp (fol.compiler.collections:collection-seq comps))
                                            (setf affected-comps
                                                  (sycamore:hash-set-insert affected-comps comp))))))

                                    ;; Compute new events from affected components
                                    (let ((new-events '()))
                                      (sycamore:do-hash-set (comp affected-comps)
                                        (let* ((input-states (get-input-states comp new-node-values))
                                               (changed-ports (get-changed-ports comp changed-nodes))
                                               (results (compute-next-state comp input-states changed-ports)))
                                          (dolist (res (fol.compiler.collections:collection-seq results))
                                            (let ((conn (component-connections comp)))
                                              (push (fol.compiler.collection-functions:dict
                                                     :time (+ event-time
                                                             (sycamore:hash-map-find res :delay))
                                                     :node (sycamore:hash-map-find
                                                            conn
                                                            (sycamore:hash-map-find res :port))
                                                     :value (sycamore:hash-map-find res :value))
                                                    new-events)))))

                                      ;; Merge new events into remaining queue
                                      (let ((new-queue (merge-events
                                                        (apply #'fol.compiler.collections:make
                                                               'fol.compiler.collections:<vector>
                                                               remaining)
                                                        (apply #'fol.compiler.collections:make
                                                               'fol.compiler.collections:<vector>
                                                               new-events))))
                                        (sim-loop new-queue
                                                 new-node-values
                                                 new-event-history
                                                 event-time))))))))))))))

        (sim-loop queue
                  (sycamore:make-hash-map)
                  (sycamore:make-hash-map)
                  0)))))

;;; ===========================================================================
;;; Top-level Run Interface
;;; ===========================================================================

(defvar *sim-context* nil)

(defun monitor (&rest nodes)
  "Mark nodes for monitoring."
  (fol.compiler.mutable:swap! *sim-context*
    (lambda (ctx)
      (let ((monitored (sycamore:hash-map-find ctx :monitored))
            (new-monitored monitored))
        (dolist (node nodes)
          (setf new-monitored (sycamore:hash-set-insert new-monitored node)))
        (sycamore:hash-map-insert ctx :monitored new-monitored)))))

(defun events (&rest evts)
  "Add events to simulation context."
  (fol.compiler.mutable:swap! *sim-context*
    (lambda (ctx)
      (let ((current-events (sycamore:hash-map-find ctx :events))
            (new-events current-events))
        (dolist (evt evts)
          (setf new-events (fset:with-last new-events evt)))
        (sycamore:hash-map-insert ctx :events new-events)))))

(defun run (module-name max-time)
  "Expand module and run simulation."
  (let* ((netlist (expand-netlist module-name))
         (ctx (fol.compiler.mutable:deref *sim-context*))
         (initial-events (sycamore:hash-map-find ctx :events))
         (monitored (sycamore:hash-map-find ctx :monitored))
         (history (run-simulation netlist initial-events max-time monitored)))
    ;; Update context with history
    (fol.compiler.mutable:swap! *sim-context*
      (lambda (c) (sycamore:hash-map-insert c :history history)))
    history))

;;; ===========================================================================
;;; Module Expansion (Native CL)
;;; ===========================================================================

(defun expand-netlist (top-module-name)
  "Expand a module into a flat netlist."
  (let ((def (get-module top-module-name)))
    (unless def
      (error "Module ~A not found" top-module-name))

    ;; Build top-level bindings (ports bound to themselves)
    (let ((top-bindings (sycamore:make-hash-map)))
      (dolist (p (fol.compiler.collections:collection-seq (module-ports def)))
        (setf top-bindings (sycamore:hash-map-insert top-bindings p p)))

      ;; Expand all specs in module body
      (let ((result '()))
        (dolist (spec (fol.compiler.collections:collection-seq (module-body def)))
          (let ((expanded (expand-spec spec nil top-bindings)))
            (dolist (comp (fol.compiler.collections:collection-seq expanded))
              (push comp result))))
        (apply #'fol.compiler.collections:make
               'fol.compiler.collections:<vector>
               (nreverse result))))))

(defun expand-spec (spec prefix bindings)
  "Expand a single spec into components (stub - would need full implementation)."
  ;; This is a simplified stub - full implementation would handle:
  ;; - Primitive components
  ;; - Hierarchical module instances
  ;; - Connection resolution
  ;; For benchmarking, we assume modules are already primitives
  (declare (ignore prefix bindings))
  (fol.compiler.collections:make 'fol.compiler.collections:<vector> spec))
