;;; benchmarks/lisp-code/lsim-pq-hybrid-b.lisp
;;;
;;; Ablation Hybrid-B: FOL persistent leftist heap  +  mutable CL hash-tables
;;;
;;; Event queue  = FOL persistent leftist heap (each node is a <dict> with keys
;;;   :rank, :elem, :left, :right; identical algorithm to lsim-pq.fol)
;;; Simulation state (connectivity, node-values, event-history, changed-nodes,
;;;   affected-comps) = mutable CL hash-tables (identical to lsim-pq.lisp).
;;;
;;; Ablation hypothesis: if Hybrid-B runtime ≈ CL (all-mutable), the persistent
;;; heap is not the bottleneck; if Hybrid-B ≈ FOL (all-persistent), the heap
;;; drives the overhead.
;;;
;;; Requires lsim-pq.lisp (package LSIM-CL) and fol-compiler/core already loaded.

(defpackage :lsim-hybrid-b
  (:use :cl)
  (:export #:run-bench #:run-lsim
           #:*gate-evals* #:*last-netlist-ms* #:*last-sim-ms*))

(in-package :lsim-hybrid-b)

;;; ---------------------------------------------------------------------------
;;; Timing
;;; ---------------------------------------------------------------------------

(defvar *gate-evals*       0)
(defvar *last-netlist-ms*  0.0d0)
(defvar *last-sim-ms*      0.0d0)

(defun %now-ms ()
  (* 1000.0d0
     (/ (get-internal-real-time)
        (float internal-time-units-per-second 1.0d0))))

;;; ---------------------------------------------------------------------------
;;; FOL persistent leftist heap
;;;
;;; Each heap node is a FOL persistent <dict> with keys:
;;;   :rank  — fixnum, right-spine rank
;;;   :elem  — lsim-cl:sim-event struct (NOT a FOL dict, same as CL baseline)
;;;   :left  — left child heap node (dict or nil)
;;;   :right — right child heap node (dict or nil)
;;;
;;; Events are CL sim-event structs so the gate evaluation code path is
;;; identical to the CL baseline.  Only the heap structure is persistent.
;;; ---------------------------------------------------------------------------

(declaim (inline plh-rank plh-elem plh-left plh-right plh-empty-p plh-peek))

(defun plh-empty-p (h) (null h))
(defun plh-peek    (h) (fol.compiler.collections:collection-ref h :elem nil))
(defun plh-rank    (h) (if (null h) 0
                           (fol.compiler.collections:collection-ref h :rank 0)))
(defun plh-left    (h) (fol.compiler.collections:collection-ref h :left nil))
(defun plh-right   (h) (fol.compiler.collections:collection-ref h :right nil))

(defun plh-make-node (e left right)
  "Allocate a new persistent heap node, maintaining the leftist property."
  (if (>= (plh-rank left) (plh-rank right))
      (fol.compiler.collection-functions:dict
       :rank (1+ (plh-rank right)) :elem e :left left  :right right)
      (fol.compiler.collection-functions:dict
       :rank (1+ (plh-rank left))  :elem e :left right :right left)))

(defun plh-merge (h1 h2)
  "Functionally merge two persistent leftist heaps; returns new heap root."
  (cond
    ((null h1) h2)
    ((null h2) h1)
    (t
     (let ((e1 (plh-peek h1))
           (e2 (plh-peek h2)))
       (if (<= (lsim-cl:sim-event-time e1) (lsim-cl:sim-event-time e2))
           (plh-make-node e1 (plh-left h1)  (plh-merge (plh-right h1) h2))
           (plh-make-node e2 (plh-left h2)  (plh-merge h1 (plh-right h2))))))))

(defun plh-insert (h event)
  "Return a new persistent heap with EVENT inserted."
  (plh-merge (fol.compiler.collection-functions:dict
              :rank 1 :elem event :left nil :right nil)
             h))

(defun plh-pop (h)
  "Return a new persistent heap with the minimum element removed."
  (plh-merge (plh-left h) (plh-right h)))

(defun plh-pop-batch (h)
  "Remove all events at the minimum time; returns (values batch new-heap)."
  (when (plh-empty-p h)
    (return-from plh-pop-batch (values nil nil)))
  (let* ((t0     (lsim-cl:sim-event-time (plh-peek h)))
         (result nil))
    (loop while (and (not (plh-empty-p h))
                     (= (lsim-cl:sim-event-time (plh-peek h)) t0))
          do (push (plh-peek h) result)
             (setf h (plh-pop h)))
    (values (nreverse result) h)))

;;; ---------------------------------------------------------------------------
;;; Connectivity builder — mutable CL hash-table (identical to lsim-pq.lisp)
;;; ---------------------------------------------------------------------------

(defun build-connectivity (netlist)
  "Build connectivity as a CL hash-table: node-symbol -> list of components."
  (let ((connectivity (make-hash-table :test 'eq)))
    (dolist (comp netlist connectivity)
      (when (typep comp 'lsim-cl:logic-component)
        (dolist (port (lsim-cl:component-inputs comp))
          (let ((node (gethash port (lsim-cl:component-connections comp))))
            (push comp (gethash node connectivity))))))))

;;; ---------------------------------------------------------------------------
;;; Per-gate helpers — mutable hash-tables (identical to lsim-pq.lisp)
;;; ---------------------------------------------------------------------------

(defun get-input-states (comp node-values)
  "Build a CL hash-table of port -> value from mutable node-values hash-table."
  (let ((states (make-hash-table :test 'eq
                                 :size (max 2 (length (lsim-cl:component-inputs comp))))))
    (dolist (port (lsim-cl:component-inputs comp) states)
      (let ((node (gethash port (lsim-cl:component-connections comp))))
        (setf (gethash port states) (gethash node node-values 0))))))

(defun get-changed-ports (comp changed-nodes)
  "Return list of input ports whose backing node is in the changed-nodes hash-table."
  (loop for port in (lsim-cl:component-inputs comp)
        for node = (gethash port (lsim-cl:component-connections comp))
        when (gethash node changed-nodes)
        collect port))

;;; ---------------------------------------------------------------------------
;;; Main simulation engine: persistent heap + mutable hash-tables
;;; ---------------------------------------------------------------------------

(defun run-simulation (netlist initial-events max-time monitored-nodes)
  "Hybrid-B simulation:
     - Event queue   : FOL persistent leftist heap (<dict> nodes, O(log n) alloc per op)
     - connectivity  : mutable CL hash-table (built once, node -> list of comps)
     - node-values   : mutable CL hash-table (setf update each event)
     - event-history : mutable CL hash-table (push update)
     - changed-nodes : mutable CL hash-table (fresh each time step)
     - affected-comps: mutable CL hash-table (fresh each time step)"
  (let ((connectivity  (build-connectivity netlist))
        (node-values   (make-hash-table :test 'eq))
        (event-history (make-hash-table :test 'eq))
        (queue         nil)
        (current-time  0))
    ;; Seed the persistent heap.
    (dolist (e initial-events)
      (setf queue (plh-insert queue e)))
    (loop while (and (not (plh-empty-p queue))
                     (<= current-time max-time))
          do (multiple-value-bind (batch new-queue)
                 (plh-pop-batch queue)
               (setf queue new-queue)
               (let* ((event-time    (lsim-cl:sim-event-time (car batch)))
                      (changed-nodes (make-hash-table :test 'eq)))
                 ;; Step 1: apply node updates.
                 (dolist (evt batch)
                   (setf (gethash (lsim-cl:sim-event-node evt) node-values)
                         (lsim-cl:sim-event-value evt))
                   (setf (gethash (lsim-cl:sim-event-node evt) changed-nodes) t))
                 ;; Step 2: record monitored history.
                 (dolist (evt batch)
                   (when (gethash (lsim-cl:sim-event-node evt) monitored-nodes)
                     (push evt (gethash (lsim-cl:sim-event-node evt) event-history))))
                 ;; Step 3: collect affected components.
                 (let ((affected (make-hash-table :test 'eq)))
                   (maphash (lambda (node _)
                               (declare (ignore _))
                               (dolist (comp (gethash node connectivity))
                                 (setf (gethash comp affected) t)))
                             changed-nodes)
                   ;; Step 4: evaluate gates and enqueue into persistent heap.
                   (maphash
                     (lambda (comp _)
                       (declare (ignore _))
                       (incf *gate-evals*)
                       (let* ((logic-fn     (lsim-cl:component-logic-fn comp))
                              (delays       (lsim-cl:component-delays comp))
                              (input-states (get-input-states comp node-values))
                              (chg-ports    (get-changed-ports comp changed-nodes))
                              (new-states   (funcall logic-fn input-states)))
                         (dolist (out-port (lsim-cl:component-outputs comp))
                           (let* ((delay (reduce
                                           (lambda (max-d in-port)
                                             (let* ((inner (gethash in-port delays))
                                                    (d     (when inner
                                                             (gethash out-port inner))))
                                               (if (and d (> d max-d)) d max-d)))
                                           chg-ports :initial-value 0))
                                  (out-node    (gethash out-port
                                                        (lsim-cl:component-connections comp)))
                                  (current-val (gethash out-node node-values -1))
                                  (new-val     (gethash out-port new-states 0)))
                             (when (/= new-val current-val)
                               (setf queue
                                     (plh-insert queue
                                                 (lsim-cl:make-sim-event
                                                  :time  (+ event-time delay)
                                                  :node  out-node
                                                  :value new-val))))))))
                     affected))
                 (setf current-time event-time))))
    ;; Reverse history lists (built with push).
    (maphash (lambda (k v) (setf (gethash k event-history) (nreverse v)))
             event-history)
    event-history))

;;; ---------------------------------------------------------------------------
;;; Shell — reads circuit state from LSIM-CL globals
;;; ---------------------------------------------------------------------------

(defun run-lsim (module-name max-time)
  "Run the Hybrid-B simulation for MODULE-NAME up to MAX-TIME.
   Reads the netlist, events, and monitored nodes from LSIM-CL package globals."
  (setf *gate-evals* 0)
  (let* ((t0      (%now-ms))
         (netlist (lsim-cl:expand-netlist module-name))
         (t1      (%now-ms)))
    (setf *last-netlist-ms* (- t1 t0))
    (let* ((t2     (%now-ms))
           (result (run-simulation netlist
                                   lsim-cl:*sim-events*
                                   max-time
                                   lsim-cl:*sim-monitored*))
           (t3     (%now-ms)))
      (declare (ignore result))
      (setf *last-sim-ms* (- t3 t2))
      :simulation-complete)))

(defun run-bench ()
  "Run Hybrid-B for the top module registered by the most-recently loaded circuit.
   Uses max-time 99999; simulation terminates naturally when the queue empties."
  (run-lsim (cl:intern "TOP" :lsim-cl) 99999))
