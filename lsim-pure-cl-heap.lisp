;;; Pure Common Lisp implementation with proper priority queue
;;; Uses cl-heap library for O(log n) event insertion (mutable heap)
;;; Uses cl-containers for set data structures

(ql:quickload :cl-heap :silent t)
(ql:quickload :alexandria :silent t)
(ql:quickload :cl-containers :silent t)

(defpackage :lsim-pure-cl-heap
  (:use :cl)
  (:export #:make-component #:make-event #:run-simulation #:run-benchmark))

(in-package :lsim-pure-cl-heap)

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
;;; Priority Queue Event Management
;;; ===========================================================================

(defun make-event-queue ()
  "Create a mutable priority queue for events (min-heap by time)."
  (make-instance 'cl-heap:binary-heap
                 :sort-fun (lambda (e1 e2)
                            (< (gethash :time e1) (gethash :time e2)))))

(defun queue-empty-p (queue)
  "Check if event queue is empty."
  (cl-heap:is-empty-heap-p queue))

(defun queue-insert (queue event)
  "Insert event into priority queue. O(log n). Mutates queue."
  (cl-heap:add-to-heap queue event))

(defun queue-pop (queue)
  "Remove and return earliest event from queue. O(log n). Mutates queue."
  (cl-heap:pop-heap queue))

(defun queue-peek (queue)
  "Return earliest event without removing it. O(1)"
  (cl-heap:peep-at-heap queue))

;;; ===========================================================================
;;; Main Simulation Loop (with Priority Queue)
;;; ===========================================================================

(defun run-simulation (netlist initial-events max-time monitored-nodes)
  "Core discrete event simulation loop using priority queue."
  (declare (optimize (speed 3) (safety 1)))

  ;; Build connectivity map
  (let ((connectivity (build-connectivity netlist)))

    ;; Initialize event queue
    (let ((queue (make-event-queue)))
      ;; Insert all initial events
      (loop for evt across initial-events
            do (queue-insert queue evt))

      ;; Main simulation loop
      (labels ((sim-loop (node-values event-history current-time)
                 (if (or (queue-empty-p queue) (> current-time max-time))
                     event-history
                     (let* ((first-event (queue-peek queue))
                            (event-time (gethash :time first-event)))

                       ;; Extract batch of events at same time
                       (let ((batch '()))
                         (loop while (and (not (queue-empty-p queue))
                                         (= (gethash :time (queue-peek queue)) event-time))
                               do (push (queue-pop queue) batch))
                         (setf batch (nreverse batch))

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

                             ;; Build set of changed nodes (cl-containers set)
                             (let ((changed-nodes (cl-containers:make-container 'cl-containers:set-container
                                                                                 :test 'eq)))
                               (dolist (evt batch)
                                 (cl-containers:insert-item changed-nodes (gethash :node evt)))

                               ;; Find affected components
                               (let ((affected-comps (cl-containers:make-container 'cl-containers:set-container
                                                                                    :test 'eq)))
                                 (cl-containers:iterate-elements
                                  changed-nodes
                                  (lambda (node)
                                    (let ((comps (gethash node connectivity)))
                                      (when comps
                                        (dolist (comp comps)
                                          (cl-containers:insert-item affected-comps comp))))))

                                 ;; Compute new events from affected components
                                 (cl-containers:iterate-elements
                                  affected-comps
                                  (lambda (comp)
                                    (let* ((input-states (get-input-states comp new-node-values))
                                           ;; Get changed ports as vector
                                           (changed-ports
                                            (let ((ports '())
                                                  (connections (gethash :connections comp))
                                                  (inputs (gethash :inputs comp)))
                                              (loop for port across inputs
                                                    do (let ((node (gethash port connections)))
                                                         (when (cl-containers:find-item changed-nodes node)
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
                                          ;; O(log n) insertion into priority queue
                                          (queue-insert queue evt))))))

                                 ;; Continue simulation
                                 (sim-loop new-node-values
                                          new-event-history
                                          event-time))))))))))

        (sim-loop (make-hash-table :test 'eq)
                  (make-hash-table :test 'eq)
                  0)))))

;;; ===========================================================================
;;; Primitive Logic Gates
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
  "Create a D-latch from NAND gates. Returns vector of gate components."
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

(defun make-nbit-register-from-gates (n)
  "Create an N-bit register built from NAND and NOT gates."
  (let ((components '()))
    (loop for i from 0 to (1- n)
          do (let* ((latch-name (intern (format nil "LATCH~D" i)))
                    (d-node (intern (format nil "IN~D" i)))
                    (q-node (intern (format nil "OUT~D" i)))
                    (latch-gates (make-d-latch-from-gates latch-name 'clk d-node q-node)))
               (loop for gate across latch-gates
                     do (push gate components))))
    (coerce (nreverse components) 'vector)))

(defun make-8bit-register-from-gates ()
  "Create an 8-bit register built from NAND and NOT gates."
  (make-nbit-register-from-gates 8))

(defun make-test-events (n-bits max-time)
  "Create test events for N-bit register up to max-time."
  (let ((events '()))
    ;; Initial values (alternating 0/1)
    (loop for i from 0 to (1- n-bits)
          do (push (make-event 0 (intern (format nil "IN~D" i)) (oddp i)) events))

    ;; Clock and data events
    (loop for time from 10 to (- max-time 5) by 10
          for pattern = (if (zerop (mod time 100)) #xAAAAAAAA #x55555555)
          do (progn
               (push (make-event time 'clk t) events)
               (push (make-event (+ time 5) 'clk nil) events)
               (when (zerop (mod time 50))
                 (loop for i from 0 to (1- n-bits)
                       do (push (make-event (+ time 2)
                                           (intern (format nil "IN~D" i))
                                           (logbitp i pattern))
                               events)))))

    (coerce (nreverse events) 'vector)))

(defun make-long-test-events ()
  "Create test events spanning to time 300 for 8-bit register."
  (make-test-events 8 300))

(defun run-heap-benchmark ()
  "Run 1000-iteration benchmark with heap-based priority queue."
  (format t "~%=== 1000-Iteration Benchmark (Pure CL with Heap, Gate-Level, 300 time units) ===~%")

  (let ((netlist (make-8bit-register-from-gates))
        (events (make-long-test-events))
        (monitored (let ((m (make-hash-table :test 'eq)))
                     (setf (gethash 'out0 m) t)
                     (setf (gethash 'out1 m) t)
                     (setf (gethash 'out2 m) t)
                     (setf (gethash 'out3 m) t)
                     (setf (gethash 'out4 m) t)
                     (setf (gethash 'out5 m) t)
                     (setf (gethash 'out6 m) t)
                     (setf (gethash 'out7 m) t)
                     m)))

    (format t "Number of components: ~D~%" (length netlist))
    (format t "Number of events: ~D~%" (length events))
    (format t "Using: cl-heap mutable binary heap (O(log n) operations)~%")

    (format t "Warming up...~%")
    (run-simulation netlist events 300 monitored)
    (sb-ext:gc :full t)

    (format t "Running 1000 iterations...~%")
    (let ((times '())
          (start-bytes (sb-ext:get-bytes-consed)))
      (dotimes (i 1000)
        (when (zerop (mod i 100))
          (format t "  Iteration ~D/1000~%" i))
        (let ((start-time (get-internal-run-time)))
          (run-simulation netlist events 300 monitored)
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

        (format t "~%Results (1000 iterations, heap-based priority queue):~%")
        (format t "  Mean:   ~,3F ms~%" (* 1000 mean))
        (format t "  Median: ~,3F ms~%" (* 1000 median))
        (format t "  Min:    ~,3F ms~%" (* 1000 min-time))
        (format t "  Max:    ~,3F ms~%" (* 1000 max-time))
        (format t "  StdDev: ~,3F ms~%" (* 1000 std-dev))
        (format t "  Total consed: ~,2F MB~%" (/ total-consed 1024.0 1024.0))
        (format t "  Per iteration: ~,2F KB~%~%" (/ total-consed 1000.0 1024.0))))))

(defun run-heap-32bit-benchmark ()
  "Run 100-iteration 32-bit benchmark with heap-based priority queue."
  (format t "~%=== 100-Iteration Benchmark (Pure CL with Heap, 32-bit, 1000 time units) ===~%")

  (let ((netlist (make-nbit-register-from-gates 32))
        (events (make-test-events 32 1000))
        (monitored (let ((m (make-hash-table :test 'eq)))
                     (loop for i from 0 to 31
                           do (setf (gethash (intern (format nil "OUT~D" i)) m) t))
                     m)))

    (format t "Number of components: ~D~%" (length netlist))
    (format t "Number of events: ~D~%" (length events))
    (format t "Using: cl-heap mutable binary heap (O(log n) operations)~%")

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

        (format t "~%Results (100 iterations, 32-bit, heap-based priority queue):~%")
        (format t "  Mean:   ~,3F ms~%" (* 1000 mean))
        (format t "  Median: ~,3F ms~%" (* 1000 median))
        (format t "  Min:    ~,3F ms~%" (* 1000 min-time))
        (format t "  Max:    ~,3F ms~%" (* 1000 max-time))
        (format t "  StdDev: ~,3F ms~%" (* 1000 std-dev))
        (format t "  Total consed: ~,2F MB~%" (/ total-consed 1024.0 1024.0))
        (format t "  Per iteration: ~,2F KB~%~%" (/ total-consed 100.0 1024.0))))))

(handler-case
    (progn
      (run-heap-benchmark)
      (run-heap-32bit-benchmark)
      (format t "~%All CL benchmarks completed successfully!~%"))
  (error (e)
    (format t "~%ERROR: ~A~%" e)
    (format t "Stacktrace:~%")
    (sb-debug:print-backtrace :stream *standard-output* :count 20)))

(sb-ext:quit)
