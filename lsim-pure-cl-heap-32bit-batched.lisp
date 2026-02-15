;;; Pure CL 32-bit register simulation with batched event priority queue
;;; Priority queue holds (time . event-list) pairs for efficient batch processing

(ql:quickload :cl-heap :silent t)
(ql:quickload :alexandria :silent t)

(defpackage :lsim-pure-cl-heap-32bit
  (:use :cl)
  (:export #:run-32bit-benchmark))

(in-package :lsim-pure-cl-heap-32bit)

;;; ===========================================================================
;;; Data Structures
;;; ===========================================================================

(defun make-component (name inputs outputs connections delays logic-fn)
  "Create a component as a CL hash-table."
  (let ((comp (make-hash-table :test 'eq)))
    (setf (gethash :name comp) name)
    (setf (gethash :inputs comp) inputs)
    (setf (gethash :outputs comp) outputs)
    (setf (gethash :connections comp) connections)
    (setf (gethash :delays comp) delays)
    (setf (gethash :logic-fn comp) logic-fn)
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
    (loop for out-port across outputs
          do (let ((max-delay 0))
               (loop for in-port across changed-ports
                     do (let ((port-delays (gethash in-port delays)))
                          (when port-delays
                            (let ((delay (gethash out-port port-delays)))
                              (when (and delay (> delay max-delay))
                                (setf max-delay delay))))))
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
               (setf (gethash node connectivity-map)
                     (cons comp (gethash node connectivity-map)))))
    connectivity-map))

(defun build-connectivity (netlist)
  "Build connectivity map from netlist."
  (let ((connectivity (make-hash-table :test 'eq)))
    (loop for comp across netlist
          do (register-connectivity comp connectivity))
    connectivity))

;;; ===========================================================================
;;; Batched Priority Queue - stores (time . event-list) pairs
;;; ===========================================================================

(defun make-batched-queue ()
  "Create a priority queue that stores batches of events by time."
  (make-instance 'cl-heap:binary-heap
                 :sort-fun (lambda (batch1 batch2)
                            (< (car batch1) (car batch2)))))

(defun queue-empty-p (queue)
  "Check if queue is empty."
  (cl-heap:is-empty-heap-p queue))

(defun queue-insert-event (queue time event)
  "Insert event into queue, batching with other events at same time."
  ;; For simplicity, just add as new batch. Real optimization would merge batches.
  (cl-heap:add-to-heap queue (cons time (list event))))

(defun queue-pop-batch (queue)
  "Pop the earliest batch (time . event-list) from queue."
  (cl-heap:pop-heap queue))

(defun queue-peek-time (queue)
  "Return the time of the earliest batch without removing it."
  (car (cl-heap:peep-at-heap queue)))

;;; ===========================================================================
;;; Main Simulation Loop
;;; ===========================================================================

(defun run-simulation (netlist initial-events max-time monitored-nodes)
  "Discrete event simulation with batched priority queue."
  (declare (optimize (speed 3) (safety 1)))

  (let ((connectivity (build-connectivity netlist)))
    (let ((queue (make-batched-queue)))

      ;; Group initial events by time and insert as batches
      (let ((time-map (make-hash-table :test 'eql)))
        (loop for evt across initial-events
              do (let ((time (gethash :time evt)))
                   (push evt (gethash time time-map))))
        (loop for time being the hash-keys of time-map
              using (hash-value events)
              do (cl-heap:add-to-heap queue (cons time (nreverse events)))))

      ;; Main simulation loop
      (labels ((sim-loop (node-values event-history current-time)
                 (if (or (queue-empty-p queue) (> current-time max-time))
                     event-history
                     (let* ((batch-pair (queue-pop-batch queue))
                            (event-time (car batch-pair))
                            (batch (cdr batch-pair)))

                       ;; Merge with any other batches at same time
                       (loop while (and (not (queue-empty-p queue))
                                       (= (queue-peek-time queue) event-time))
                             do (let ((next-batch (queue-pop-batch queue)))
                                  (setf batch (append batch (cdr next-batch)))))

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
                                 (setf (gethash node new-event-history)
                                       (cons evt (gethash node new-event-history))))))

                           ;; Build set of changed nodes
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

                               ;; Compute new events, batch by time before inserting
                               (let ((new-events-by-time (make-hash-table :test 'eql)))
                                 (loop for comp being the hash-keys of affected-comps
                                       do (let* ((input-states (get-input-states comp new-node-values))
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
                                              (let* ((conn (gethash :connections comp))
                                                     (evt (make-hash-table :test 'eq))
                                                     (evt-time (+ event-time (gethash :delay res))))
                                                (setf (gethash :time evt) evt-time)
                                                (setf (gethash :node evt)
                                                      (gethash (gethash :port res) conn))
                                                (setf (gethash :value evt)
                                                      (gethash :value res))
                                                (push evt (gethash evt-time new-events-by-time))))))

                                 ;; Insert batched events into queue
                                 (loop for time being the hash-keys of new-events-by-time
                                       using (hash-value events)
                                       do (cl-heap:add-to-heap queue (cons time (nreverse events))))

                                 ;; Continue simulation
                                 (sim-loop new-node-values
                                          new-event-history
                                          event-time))))))))))

        (sim-loop (make-hash-table :test 'eq)
                  (make-hash-table :test 'eq)
                  0)))))

;;; ===========================================================================
;;; Gate Components
;;; ===========================================================================

(defun make-nand-gate (name in1-node in2-node out-node)
  "Create a NAND gate component."
  (let ((connections (make-hash-table :test 'eq))
        (delays (make-hash-table :test 'eq)))
    (setf (gethash :in1 connections) in1-node)
    (setf (gethash :in2 connections) in2-node)
    (setf (gethash :out connections) out-node)
    (let ((in1-delays (make-hash-table :test 'eq))
          (in2-delays (make-hash-table :test 'eq)))
      (setf (gethash :out in1-delays) 1)
      (setf (gethash :out in2-delays) 1)
      (setf (gethash :in1 delays) in1-delays)
      (setf (gethash :in2 delays) in2-delays))
    (make-component name
                    (vector :in1 :in2)
                    (vector :out)
                    connections
                    delays
                    (lambda (inputs)
                      (let ((out-states (make-hash-table :test 'eq)))
                        (setf (gethash :out out-states)
                              (not (and (gethash :in1 inputs)
                                       (gethash :in2 inputs))))
                        out-states)))))

(defun make-not-gate (name in-node out-node)
  "Create a NOT gate component."
  (let ((connections (make-hash-table :test 'eq))
        (delays (make-hash-table :test 'eq)))
    (setf (gethash :in connections) in-node)
    (setf (gethash :out connections) out-node)
    (let ((in-delays (make-hash-table :test 'eq)))
      (setf (gethash :out in-delays) 1)
      (setf (gethash :in delays) in-delays))
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

(defun make-d-latch-from-gates (name-prefix clk-node d-node q-node)
  "Create a D-latch from 5 gates (1 NOT + 4 NAND). Returns vector of components."
  (let ((components '())
        (d-not (intern (format nil "~A-D-NOT" name-prefix)))
        (s (intern (format nil "~A-S" name-prefix)))
        (r (intern (format nil "~A-R" name-prefix)))
        (q-not (intern (format nil "~A-Q-NOT" name-prefix))))

    (push (make-not-gate (intern (format nil "~A-NOT-D" name-prefix))
                        d-node d-not)
          components)
    (push (make-nand-gate (intern (format nil "~A-NAND-S" name-prefix))
                         d-node clk-node s)
          components)
    (push (make-nand-gate (intern (format nil "~A-NAND-R" name-prefix))
                         d-not clk-node r)
          components)
    (push (make-nand-gate (intern (format nil "~A-NAND-Q" name-prefix))
                         s q-not q-node)
          components)
    (push (make-nand-gate (intern (format nil "~A-NAND-Q-NOT" name-prefix))
                         r q-node q-not)
          components)

    (coerce (nreverse components) 'vector)))

(defun make-32bit-register-from-gates ()
  "Create a 32-bit register from D-latches (5 gates each = 160 total components)."
  (let ((components '()))
    (loop for i from 0 to 31
          do (let* ((latch-name (intern (format nil "LATCH~D" i)))
                    (d-node (intern (format nil "IN~D" i)))
                    (q-node (intern (format nil "OUT~D" i)))
                    (latch-gates (make-d-latch-from-gates latch-name 'clk d-node q-node)))
               (loop for gate across latch-gates
                     do (push gate components))))
    (coerce (nreverse components) 'vector)))

;;; ===========================================================================
;;; Test Events for 1000 Time Steps
;;; ===========================================================================

(defun make-1000-step-events ()
  "Create test events for 1000 time steps with alternating patterns."
  (let ((events '()))
    ;; Initial values at t=0
    (loop for i from 0 to 31
          do (push (make-event 0 (intern (format nil "IN~D" i))
                              (logbitp i #xAAAAAAAA))
                   events))

    ;; Clock pulses every 10 time units, data changes every 50 time units
    (loop for time from 10 below 1000 by 10
          for pattern = #xAAAAAAAA then (logxor pattern #xFFFFFFFF)
          do (progn
               ;; Clock rising edge
               (push (make-event time 'clk t) events)
               ;; Clock falling edge
               (push (make-event (+ time 5) 'clk nil) events)
               ;; Change data every 50 time units
               (when (zerop (mod time 50))
                 (loop for i from 0 to 31
                       do (push (make-event (+ time 2)
                                           (intern (format nil "IN~D" i))
                                           (logbitp i pattern))
                               events)))))

    (coerce (nreverse events) 'vector)))

;;; ===========================================================================
;;; Benchmark
;;; ===========================================================================

(defun run-32bit-benchmark ()
  "Run benchmark: 32-bit register, 160 components, 1000 time steps, 100 iterations."
  (format t "~%=== 32-Bit Register Benchmark (Batched Priority Queue) ===~%")
  (format t "Configuration: 160 components (32 latches × 5 gates), 1000 time steps~%")

  (let ((netlist (make-32bit-register-from-gates))
        (events (make-1000-step-events))
        (monitored (let ((m (make-hash-table :test 'eq)))
                     (loop for i from 0 to 31
                           do (setf (gethash (intern (format nil "OUT~D" i)) m) t))
                     m)))

    (format t "Number of components: ~D~%" (length netlist))
    (format t "Number of initial events: ~D~%" (length events))
    (format t "Simulation duration: 1000 time units~%")
    (format t "Using: cl-heap with batched events by timestamp~%~%")

    (format t "Warming up...~%")
    (run-simulation netlist events 1000 monitored)
    (sb-ext:gc :full t)

    (format t "Running 100 iterations...~%")
    (let ((times '())
          (start-bytes (sb-ext:get-bytes-consed)))
      (dotimes (i 100)
        (when (zerop (mod i 10))
          (format t "  Iteration ~D/100~%" i))
        (let ((start-time (get-internal-run-time)))
          (run-simulation netlist events 1000 monitored)
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

        (format t "~%Results (100 iterations, 32-bit register, batched queue):~%")
        (format t "  Mean:   ~,3F ms~%" (* 1000 mean))
        (format t "  Median: ~,3F ms~%" (* 1000 median))
        (format t "  Min:    ~,3F ms~%" (* 1000 min-time))
        (format t "  Max:    ~,3F ms~%" (* 1000 max-time))
        (format t "  StdDev: ~,3F ms~%" (* 1000 std-dev))
        (format t "  Total consed: ~,2F MB~%" (/ total-consed 1024.0 1024.0))
        (format t "  Per iteration: ~,2F KB~%~%" (/ total-consed 100.0 1024.0))))))

(run-32bit-benchmark)
(sb-ext:quit)
