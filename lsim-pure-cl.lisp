;;; Pure Common Lisp implementation of discrete event simulator
;;; Uses only CL hash-tables, vectors, and lists

(defpackage :lsim-pure-cl
  (:use :cl)
  (:export #:make-component #:make-event #:run-simulation #:run-benchmark))

(in-package :lsim-pure-cl)

;;; ===========================================================================
;;; Data Structures (using CL hash-tables)
;;; ===========================================================================

(defun make-component (name inputs outputs connections delays logic-fn)
  "Create a component as a CL hash-table."
  (let ((comp (make-hash-table :test 'eq)))
    (setf (gethash :name comp) name)
    (setf (gethash :inputs comp) inputs)      ; vector of port keywords
    (setf (gethash :outputs comp) outputs)    ; vector of port keywords
    (setf (gethash :connections comp) connections)  ; hash-table: port -> node
    (setf (gethash :delays comp) delays)      ; hash-table: in-port -> hash-table(out-port -> delay)
    (setf (gethash :logic-fn comp) logic-fn)  ; function: input-states -> output-states
    comp))

(defun make-event (time node value)
  "Create an event as a CL hash-table."
  (let ((evt (make-hash-table :test 'eq)))
    (setf (gethash :time evt) time)
    (setf (gethash :node evt) node)
    (setf (gethash :value evt) value)
    evt))

;;; ===========================================================================
;;; Component Logic
;;; ===========================================================================

(defun get-input-states (comp node-values)
  "Get current values for all component inputs."
  (let ((connections (gethash :connections comp))
        (inputs (gethash :inputs comp))
        (result (make-hash-table :test 'eq)))
    (loop for port across inputs
          do (let ((node (gethash port connections)))
               (setf (gethash port result) (gethash node node-values))))
    result))

(defun compute-next-state (comp input-states changed-ports)
  "Compute component outputs given input states."
  (let* ((logic-fn (gethash :logic-fn comp))
         (delays (gethash :delays comp))
         (outputs (gethash :outputs comp))
         (new-states (funcall logic-fn input-states))
         (results '()))

    ;; For each output port
    (loop for out-port across outputs
          do (let ((max-delay 0))
               ;; Find max delay from changed inputs to this output
               (loop for in-port across changed-ports
                     do (let ((port-delays (gethash in-port delays)))
                          (when port-delays
                            (let ((delay (gethash out-port port-delays)))
                              (when (and delay (> delay max-delay))
                                (setf max-delay delay))))))
               ;; Create output event
               (push (let ((res (make-hash-table :test 'eq)))
                       (setf (gethash :port res) out-port)
                       (setf (gethash :value res) (gethash out-port new-states))
                       (setf (gethash :delay res) max-delay)
                       res)
                     results)))
    (nreverse results)))

;;; ===========================================================================
;;; Connectivity
;;; ===========================================================================

(defun register-connectivity (comp connectivity-map)
  "Register component's input nodes in connectivity map."
  (let ((connections (gethash :connections comp))
        (inputs (gethash :inputs comp)))
    (loop for port across inputs
          do (let ((node (gethash port connections)))
               ;; Add comp to list of components connected to this node
               (push comp (gethash node connectivity-map))))
    connectivity-map))

(defun build-connectivity (netlist)
  "Build connectivity map from netlist."
  (let ((connectivity (make-hash-table :test 'eq)))
    (loop for comp across netlist
          do (register-connectivity comp connectivity))
    connectivity))

;;; ===========================================================================
;;; Main Simulation Loop
;;; ===========================================================================

(defun run-simulation (netlist initial-events max-time monitored-nodes)
  "Core discrete event simulation loop."
  (declare (optimize (speed 3) (safety 1)))

  ;; Build connectivity map
  (let ((connectivity (build-connectivity netlist)))

    ;; Sort initial events by time
    (let* ((sorted-events (stable-sort (copy-seq initial-events) #'<
                                      :key (lambda (e) (gethash :time e))))
           (queue (coerce sorted-events 'list)))

      ;; Main simulation loop
      (labels ((sim-loop (queue node-values event-history current-time)
                 (if (or (null queue) (> current-time max-time))
                     event-history
                     (let* ((first-event (first queue))
                            (event-time (gethash :time first-event)))

                       ;; Extract batch of events at same time
                       (multiple-value-bind (batch remaining)
                           (loop for evt in queue
                                 while (= (gethash :time evt) event-time)
                                 collect evt into batch-list
                                 finally (return (values batch-list
                                                        (nthcdr (length batch-list) queue))))

                         ;; Update node values
                         (let ((new-node-values (alexandria:copy-hash-table node-values)))
                           (dolist (evt batch)
                             (setf (gethash (gethash :node evt) new-node-values)
                                   (gethash :value evt)))

                           ;; Update event history for monitored nodes
                           (let ((new-event-history (alexandria:copy-hash-table event-history)))
                             (dolist (evt batch)
                               (let ((node (gethash :node evt)))
                                 (when (gethash node monitored-nodes)
                                   (push evt (gethash node new-event-history)))))

                             ;; Build set of changed nodes (CL hash-table as set)
                             (let ((changed-nodes (make-hash-table :test 'eq)))
                               (dolist (evt batch)
                                 (setf (gethash (gethash :node evt) changed-nodes) t))

                               ;; Find affected components
                               (let ((affected-comps (make-hash-table :test 'eq)))
                                 (loop for node being the hash-keys of changed-nodes
                                       do (let ((comps (gethash node connectivity)))
                                            (when comps
                                              (dolist (comp comps)
                                                (setf (gethash comp affected-comps) t)))))

                                 ;; Compute new events from affected components
                                 (let ((new-events '()))
                                   (loop for comp being the hash-keys of affected-comps
                                         do (let* ((input-states (get-input-states comp new-node-values))
                                                   ;; Get changed ports as vector
                                                   (changed-ports
                                                    (let ((ports '())
                                                          (connections (gethash :connections comp))
                                                          (inputs (gethash :inputs comp)))
                                                      (loop for port across inputs
                                                            do (let ((node (gethash port connections)))
                                                                 (when (gethash node changed-nodes)
                                                                   (push port ports))))
                                                      (coerce (nreverse ports) 'vector)))
                                                   (results (compute-next-state comp input-states changed-ports)))
                                              (dolist (res results)
                                                (let ((conn (gethash :connections comp))
                                                      (evt (make-hash-table :test 'eq)))
                                                  (setf (gethash :time evt)
                                                        (+ event-time (gethash :delay res)))
                                                  (setf (gethash :node evt)
                                                        (gethash (gethash :port res) conn))
                                                  (setf (gethash :value evt)
                                                        (gethash :value res))
                                                  (push evt new-events)))))

                                   ;; Merge new events into remaining queue (sorted insert)
                                   (let ((new-queue remaining))
                                     (dolist (evt new-events)
                                       (setf new-queue (insert-sorted evt new-queue)))
                                     (sim-loop new-queue
                                              new-node-values
                                              new-event-history
                                              event-time))))))))))))

        (sim-loop queue
                  (make-hash-table :test 'eq)
                  (make-hash-table :test 'eq)
                  0)))))

(defun insert-sorted (evt queue)
  "Insert event into queue maintaining time order."
  (let ((evt-time (gethash :time evt)))
    (cond
      ((null queue) (list evt))
      ((< evt-time (gethash :time (first queue)))
       (cons evt queue))
      (t (cons (first queue)
               (insert-sorted evt (rest queue)))))))

;;; ===========================================================================
;;; Test Netlist: Simple NOT Gate
;;; ===========================================================================

(defun make-not-gate (name input-node output-node)
  "Create a simple NOT gate component."
  (let ((connections (make-hash-table :test 'eq))
        (delays (make-hash-table :test 'eq)))
    ;; Set up connections
    (setf (gethash :in connections) input-node)
    (setf (gethash :out connections) output-node)

    ;; Set up delays: input change causes output change after 1 time unit
    (let ((in-delays (make-hash-table :test 'eq)))
      (setf (gethash :out in-delays) 1)
      (setf (gethash :in delays) in-delays))

    ;; Logic function: NOT the input
    (make-component name
                    (vector :in)
                    (vector :out)
                    connections
                    delays
                    (lambda (inputs)
                      (let ((out-states (make-hash-table :test 'eq)))
                        (setf (gethash :out out-states)
                              (not (gethash :in inputs)))
                        out-states)))))

;;; ===========================================================================
;;; Benchmark
;;; ===========================================================================

(defun run-benchmark ()
  "Run 100-iteration benchmark of pure CL simulator."
  (format t "~%=== 100-Iteration Benchmark (Pure CL) ===~%")

  ;; Create test netlist: simple NOT gate
  (let ((netlist (vector (make-not-gate 'not1 'a 'b)))
        (events (vector (make-event 0 'a t)
                       (make-event 5 'a nil)
                       (make-event 10 'a t)))
        (monitored (let ((m (make-hash-table :test 'eq)))
                    (setf (gethash 'b m) t)
                    m)))

    ;; Warmup
    (format t "Warming up...~%")
    (run-simulation netlist events 20 monitored)
    (sb-ext:gc :full t)

    ;; Benchmark 100 iterations
    (format t "Running 100 iterations...~%")
    (let ((times '())
          (start-bytes (sb-ext:get-bytes-consed)))
      (dotimes (i 100)
        (when (zerop (mod i 10))
          (format t "  Iteration ~D/100~%" i))
        (let ((start-time (get-internal-run-time)))
          (run-simulation netlist events 20 monitored)
          (let ((elapsed (/ (- (get-internal-run-time) start-time)
                           internal-time-units-per-second)))
            (push elapsed times))))

      (let* ((end-bytes (sb-ext:get-bytes-consed))
             (total-consed (- end-bytes start-bytes))
             (sorted-times (sort (copy-list times) #'<))
             (mean (/ (reduce #'+ sorted-times) (length sorted-times)))
             (median (nth (floor (length sorted-times) 2) sorted-times))
             (min-time (first sorted-times))
             (max-time (first (last sorted-times)))
             (std-dev (sqrt (/ (reduce #'+ (mapcar (lambda (x) (expt (- x mean) 2))
                                                   sorted-times))
                              (length sorted-times)))))

        (format t "~%Results (100 iterations, pure CL):~%")
        (format t "  Mean:   ~,3F ms~%" (* 1000 mean))
        (format t "  Median: ~,3F ms~%" (* 1000 median))
        (format t "  Min:    ~,3F ms~%" (* 1000 min-time))
        (format t "  Max:    ~,3F ms~%" (* 1000 max-time))
        (format t "  StdDev: ~,3F ms~%" (* 1000 std-dev))
        (format t "  Total consed: ~,2F MB~%" (/ total-consed 1024.0 1024.0))
        (format t "  Per iteration: ~,2F KB~%~%" (/ total-consed 100.0 1024.0))))))
