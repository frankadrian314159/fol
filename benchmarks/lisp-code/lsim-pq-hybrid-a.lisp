;;; benchmarks/lisp-code/lsim-pq-hybrid-a.lisp
;;;
;;; Ablation Hybrid-A: mutable CL leftist heap  +  FOL persistent HAMT maps
;;;
;;; Event queue  = mutable destructive cons-cell leftist heap (identical to lsim-pq.lisp)
;;; Simulation state (connectivity, node-values, event-history, changed-nodes,
;;;   affected-comps) = FOL persistent <dict>/<set> backed by hand-coded HAMT
;;;   (fol.compiler.collection-primitives).
;;;
;;; Ablation hypothesis: if Hybrid-A runtime ≈ FOL (all-persistent), the event
;;; queue is not the bottleneck; if Hybrid-A ≈ CL (all-mutable), persistent
;;; state maps drive the overhead.
;;;
;;; Requires lsim-pq.lisp (package LSIM-CL) and fol-compiler/core already loaded.

(defpackage :lsim-hybrid-a
  (:use :cl)
  (:export #:run-bench #:run-lsim
           #:*gate-evals* #:*last-netlist-ms* #:*last-sim-ms*))

(in-package :lsim-hybrid-a)

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
;;; Mutable leftist heap — identical to lsim-pq.lisp
;;; Reproduced here to avoid cross-package dispatch overhead in the hot path.
;;; ---------------------------------------------------------------------------

(declaim (inline lh-rank lh-elem lh-left lh-right
                 lh-set-rank! lh-set-left! lh-set-right!
                 lh-singleton lh-empty-p lh-peek))

(defun lh-rank  (node) (if (null node) 0 (the fixnum (car node))))
(defun lh-elem  (node) (cadr node))
(defun lh-left  (node) (caddr node))
(defun lh-right (node) (cadddr node))
(defun lh-set-rank!  (node r) (setf (car    node) r))
(defun lh-set-left!  (node c) (setf (caddr  node) c))
(defun lh-set-right! (node c) (setf (cadddr node) c))
(defun lh-singleton  (event)  (list 1 event nil nil))
(defun lh-empty-p    (node)   (null node))
(defun lh-peek       (node)   (cadr node))

(defun lh-merge! (h1 h2)
  "Destructively merge two leftist heaps; returns new root."
  (cond
    ((null h1) h2)
    ((null h2) h1)
    (t
     (let* ((e1 (lh-elem h1)) (e2 (lh-elem h2))
            (winner (if (<= (lsim-cl:sim-event-time e1)
                            (lsim-cl:sim-event-time e2))
                        h1 h2))
            (loser  (if (eq winner h1) h2 h1)))
       (lh-set-right! winner (lh-merge! (lh-right winner) loser))
       (when (< (lh-rank (lh-left winner)) (lh-rank (lh-right winner)))
         (let ((tmp (lh-left winner)))
           (lh-set-left!  winner (lh-right winner))
           (lh-set-right! winner tmp)))
       (lh-set-rank! winner (1+ (lh-rank (lh-right winner))))
       winner))))

(defun lh-insert! (h event) (lh-merge! (lh-singleton event) h))
(defun lh-pop!    (h)       (lh-merge! (lh-left h) (lh-right h)))

(defun lh-pop-batch! (h)
  "Remove all events at the minimum time; returns (values batch new-root)."
  (when (lh-empty-p h)
    (return-from lh-pop-batch! (values nil nil)))
  (let* ((t0 (lsim-cl:sim-event-time (lh-peek h)))
         (result nil))
    (loop while (and (not (lh-empty-p h))
                     (= (lsim-cl:sim-event-time (lh-peek h)) t0))
          do (push (lh-peek h) result)
             (setf h (lh-pop! h)))
    (values (nreverse result) h)))

;;; ---------------------------------------------------------------------------
;;; FOL persistent collection helpers
;;; ---------------------------------------------------------------------------
;;; We call directly into fol.compiler.* rather than going through the
;;; generic MAKE dispatch that compiled FOL code uses, to keep the comparison
;;; fair (no extra dispatch layers relative to what the FOL lsim actually does).

(declaim (inline pdict-empty pset-empty pdict-get pdict-put pset-add pset-has pseq))

(defun pdict-empty ()
  "Return an empty FOL persistent <dict> (HAMT-backed)."
  (fol.compiler.collection-functions:dict))

(defun pset-empty ()
  "Return an empty FOL persistent <set> (HAMT-backed)."
  (fol.compiler.collection-functions:set))

(defun pdict-get (d key &optional not-found)
  "Look up KEY in FOL persistent dict D."
  (fol.compiler.collections:collection-ref d key not-found))

(defun pdict-put (d key value)
  "Functionally associate KEY -> VALUE in FOL persistent dict D."
  (fol.core:assoc d key value))

(defun pset-add (s elem)
  "Return a new FOL persistent set with ELEM added."
  (fol.core:conj s elem))

(defun pset-has (s elem)
  "Return true if ELEM is a member of FOL persistent set S."
  (fol.core:contains? s elem))

(defun pseq (coll)
  "Return elements of FOL persistent collection COLL as a CL list.
   For <dict>, entries are (key . val) cons cells; for <set>, elements directly."
  (fol.compiler.collections:collection-seq coll))

;;; ---------------------------------------------------------------------------
;;; Connectivity builder — FOL persistent dict
;;; ---------------------------------------------------------------------------

(defun build-connectivity (netlist)
  "Build a FOL persistent dict mapping each node symbol to a CL list of
   logic-component objects that read from that node."
  (let ((conn (pdict-empty)))
    (dolist (comp netlist conn)
      (when (typep comp 'lsim-cl:logic-component)
        (dolist (port (lsim-cl:component-inputs comp))
          (let* ((node    (gethash port (lsim-cl:component-connections comp)))
                 (cur     (pdict-get conn node))
                 (updated (if cur (cons comp cur) (list comp))))
            (setf conn (pdict-put conn node updated))))))))

;;; ---------------------------------------------------------------------------
;;; Per-gate helpers that accept FOL persistent collections
;;; ---------------------------------------------------------------------------

(defun get-input-states (comp node-values)
  "Build a CL hash-table of port -> value, looking up node values in the
   FOL persistent node-values dict."
  (let ((states (make-hash-table :test 'eq
                                 :size (max 2 (length (lsim-cl:component-inputs comp))))))
    (dolist (port (lsim-cl:component-inputs comp) states)
      (let ((node (gethash port (lsim-cl:component-connections comp))))
        (setf (gethash port states) (or (pdict-get node-values node) 0))))))

(defun get-changed-ports (comp changed-nodes)
  "Return list of input ports whose backing node is in the FOL persistent
   changed-nodes set."
  (loop for port in (lsim-cl:component-inputs comp)
        for node = (gethash port (lsim-cl:component-connections comp))
        when (pset-has changed-nodes node)
        collect port))

;;; ---------------------------------------------------------------------------
;;; Main simulation engine: mutable heap + persistent maps
;;; ---------------------------------------------------------------------------

(defun run-simulation (netlist initial-events max-time monitored-nodes)
  "Hybrid-A simulation:
     - Event queue   : mutable CL leftist heap (cons cells, O(log n) destructive merge)
     - connectivity  : FOL persistent <dict> (built once, node -> CL list of comps)
     - node-values   : FOL persistent <dict> (functional update each event)
     - event-history : FOL persistent <dict> (functional update)
     - changed-nodes : FOL persistent <set>  (rebuilt each time step)
     - affected-comps: FOL persistent <set>  (rebuilt each time step)"
  (let ((connectivity (build-connectivity netlist))
        (node-values  (pdict-empty))
        (event-history (pdict-empty))
        (queue         nil)
        (current-time  0))
    ;; Seed the mutable heap.
    (dolist (e initial-events)
      (setf queue (lh-insert! queue e)))
    (loop while (and (not (lh-empty-p queue))
                     (<= current-time max-time))
          do (multiple-value-bind (batch new-queue)
                 (lh-pop-batch! queue)
               (setf queue new-queue)
               (let* ((event-time (lsim-cl:sim-event-time (car batch)))
                      ;; Step 1: apply node updates (functional) and collect changed nodes.
                      (changed-nodes
                        (let ((s (pset-empty)))
                          (dolist (evt batch)
                            (setf node-values
                                  (pdict-put node-values
                                             (lsim-cl:sim-event-node evt)
                                             (lsim-cl:sim-event-value evt)))
                            (setf s (pset-add s (lsim-cl:sim-event-node evt))))
                          s))
                      ;; Step 2: collect affected components (persistent set).
                      (affected
                        (let ((s (pset-empty)))
                          (dolist (node (pseq changed-nodes))
                            (let ((comps (pdict-get connectivity node)))
                              (when comps
                                (dolist (c comps)
                                  (setf s (pset-add s c))))))
                          s)))
                 ;; Step 3: record monitored history (persistent dict update).
                 (dolist (evt batch)
                   (when (gethash (lsim-cl:sim-event-node evt) monitored-nodes)
                     (let* ((node (lsim-cl:sim-event-node evt))
                            (cur  (pdict-get event-history node)))
                       (setf event-history
                             (pdict-put event-history node
                                        (if cur
                                            (append cur (list evt))
                                            (list evt)))))))
                 ;; Step 4: evaluate gates and enqueue new events into mutable heap.
                 (dolist (comp (pseq affected))
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
                              (current-val (or (pdict-get node-values out-node) -1))
                              (new-val     (gethash out-port new-states 0)))
                         (when (/= new-val current-val)
                           (setf queue
                                 (lh-insert! queue
                                             (lsim-cl:make-sim-event
                                              :time  (+ event-time delay)
                                              :node  out-node
                                              :value new-val))))))))
                 (setf current-time event-time))))
    event-history))

;;; ---------------------------------------------------------------------------
;;; Shell — reads circuit state from LSIM-CL globals
;;; ---------------------------------------------------------------------------

(defun run-lsim (module-name max-time)
  "Run the Hybrid-A simulation for MODULE-NAME up to MAX-TIME.
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
  "Run Hybrid-A for the top module registered by the most-recently loaded circuit.
   Uses max-time 99999; simulation terminates naturally when the queue empties."
  (run-lsim (cl:intern "TOP" :lsim-cl) 99999))
