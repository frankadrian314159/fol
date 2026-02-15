;;; Hand-optimized Common Lisp simulation loop
;;; Uses CL hash-tables for local sets (keys = elements, presence = membership)

(in-package :fol-sim)

(defun run-simulation-optimized (netlist initial-events max-time monitored-nodes)
  "Hand-optimized discrete event simulation loop using CL hash-tables for sets."
  (declare (optimize (speed 3) (safety 1)))

  ;; Build connectivity map (FOL dict for compatibility with transpiled register-connectivity)
  (let ((connectivity (fol.compiler.collection-functions:dict)))
    (dolist (comp (fol.compiler.collections:collection-seq netlist))
      (setf connectivity (register-connectivity comp connectivity)))

    ;; Sort initial events by time
    (let* ((event-seq (fol.compiler.collections:collection-seq initial-events))
           (sorted-events (stable-sort (copy-list event-seq) #'<
                                       :key (lambda (e) (sycamore:hash-map-find e :time))))
           (queue (apply #'fol.compiler.collections:make
                        'fol.compiler.collections:<vector>
                        sorted-events)))

      ;; Main simulation loop
      (labels ((sim-loop (queue node-values event-history current-time)
                 (if (or (fol.compiler.collection-functions:empty? queue)
                         (> current-time max-time))
                     event-history
                     (let* ((queue-seq (fol.compiler.collections:collection-seq queue))
                            (first-event (first queue-seq))
                            (event-time (sycamore:hash-map-find first-event :time)))

                       ;; Extract batch of events at same time
                       (multiple-value-bind (batch remaining)
                           (loop with result = '()
                                 for evt in queue-seq
                                 while (= (sycamore:hash-map-find evt :time) event-time)
                                 do (push evt result)
                                 finally (return (values (nreverse result)
                                                        (nthcdr (length result) queue-seq))))

                         ;; Update node values
                         (let ((new-node-values node-values))
                           (dolist (evt batch)
                             (setf new-node-values
                                   (sycamore:hash-map-insert
                                    new-node-values
                                    (sycamore:hash-map-find evt :node)
                                    (sycamore:hash-map-find evt :value))))

                           ;; Update event history
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

                             ;; Build set of changed nodes (CL hash-table as set)
                             (let ((changed-nodes (make-hash-table :test 'eq)))
                               (dolist (evt batch)
                                 (setf (gethash (sycamore:hash-map-find evt :node) changed-nodes) t))

                               ;; Find affected components (CL hash-table as set)
                               (let ((affected-comps (make-hash-table :test 'eq)))
                                 ;; Iterate over changed nodes
                                 (loop for node being the hash-keys of changed-nodes
                                       do (let ((comps (fol.compiler.collection-functions:get connectivity node)))
                                            (when comps
                                              (dolist (comp (fol.compiler.collections:collection-seq comps))
                                                (setf (gethash comp affected-comps) t)))))

                                 ;; Compute new events from affected components
                                 (let ((new-events '()))
                                   (loop for comp being the hash-keys of affected-comps
                                         do (let* ((input-states (get-input-states comp new-node-values))
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
                                                            (nreverse new-events)))))
                                     (sim-loop new-queue
                                              new-node-values
                                              new-event-history
                                              event-time)))))))))))

        (sim-loop queue
                  (sycamore:make-hash-map)
                  (sycamore:make-hash-map)
                  0))))))

;; Helper: get-changed-ports adapted for CL hash-table set
(defun get-changed-ports (comp changed-nodes-table)
  "Filter component inputs to only those connected to changed nodes.
   changed-nodes-table is a CL hash-table where keys = changed nodes."
  (let ((connections (component-connections comp))
        (inputs (component-inputs comp))
        (result '()))
    (dolist (port (fol.compiler.collections:collection-seq inputs))
      (let ((node (sycamore:hash-map-find connections port)))
        (when (gethash node changed-nodes-table)
          (push port result))))
    (apply #'fol.compiler.collections:make
           'fol.compiler.collections:<vector>
           (nreverse result))))

;; Override only the core simulation functions (use transpiled monitor/events/run)
(setf (fdefinition 'run-simulation) #'run-simulation-optimized)
(setf (fdefinition 'get-changed-ports) #'get-changed-ports)

(format t "~%[Loaded hand-optimized CL simulation loop]~%")
