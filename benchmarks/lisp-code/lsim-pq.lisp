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
           #:*sim-monitored* #:*sim-events* #:*sim-history* #:*gate-evals*
           #:make-dict #:run-bench
           #:*last-netlist-ms* #:*last-sim-ms*))

(in-package :lsim-cl)

;; -----------------------------------------------------------------------------
;; Structs
;; -----------------------------------------------------------------------------

(defstruct (sim-event (:constructor make-sim-event (&key time node value)))
  (time  0   :type fixnum)
  (node  nil :type symbol)
  (value 0   :type fixnum))

(defstruct (gate-result (:constructor make-gate-result (&key port value delay)))
  (port  nil :type symbol)
  (value 0   :type fixnum)
  (delay 0   :type fixnum))

;; -----------------------------------------------------------------------------
;; Hash-table utilities
;; -----------------------------------------------------------------------------

(defun make-dict (&rest pairs)
  "Create an EQ hash table from alternating key-value pairs."
  (let ((ht (make-hash-table :test 'eq :size (max 4 (ceiling (length pairs) 2)))))
    (loop for (k v) on pairs by #'cddr do (setf (gethash k ht) v))
    ht))

;; -----------------------------------------------------------------------------
;; 1. Global registry
;; -----------------------------------------------------------------------------

(defvar *circuit-modules* (make-hash-table :test 'eq))
(defvar *primitives*       (make-hash-table :test 'eq))
(defvar *gate-evals*       0)
(defvar *last-netlist-ms*  0.0d0)
(defvar *last-sim-ms*      0.0d0)

(defun register-module (name def) (setf (gethash name *circuit-modules*) def))
(defun get-module      (name)     (gethash name *circuit-modules*))
(defun register-primitive (name f) (setf (gethash name *primitives*) f))
(defun get-primitive      (name)   (gethash name *primitives*))

;; -----------------------------------------------------------------------------
;; 2. Domain classes
;; -----------------------------------------------------------------------------

(defclass component ()
  ((name        :initarg :name        :accessor component-name)
   (ctype       :initarg :type        :accessor component-type)
   (connections :initarg :connections :accessor component-connections)))

(defclass module-def ()
  ((name  :initarg :name  :accessor module-name)
   (ports :initarg :ports :accessor module-ports)
   (body  :initarg :body  :accessor module-body)))

(defclass logic-component (component)
  ((inputs   :initarg :inputs   :accessor component-inputs)
   (outputs  :initarg :outputs  :accessor component-outputs)
   (delays   :initarg :delays   :accessor component-delays)
   (logic-fn :initarg :logic-fn :accessor component-logic-fn)))

(defgeneric compute-next-state (comp input-states changed-inputs))

(defmethod compute-next-state ((comp logic-component) input-states changed-inputs)
  (incf *gate-evals*)
  (let* ((logic-fn  (component-logic-fn comp))
         (delays    (component-delays comp))
         (new-states (funcall logic-fn input-states)))
    (loop for out-port in (component-outputs comp)
          collect
            (let ((delay (reduce (lambda (max-d in-port)
                                   (let* ((inner (gethash in-port delays))
                                          (d     (when inner (gethash out-port inner))))
                                     (if (and d (> d max-d)) d max-d)))
                                 changed-inputs :initial-value 0)))
              (make-gate-result :port  out-port
                                :value (gethash out-port new-states 0)
                                :delay delay)))))

;; -----------------------------------------------------------------------------
;; 2.5 Standard gates
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
                    (make-dict :out (logand (gethash :in1 s 0) (gethash :in2 s 0)))))))
  (register-primitive 'or
    (lambda (name param conns)
      (declare (ignore param))
      (make-instance 'logic-component
        :name name :type 'or :connections conns
        :inputs '(:in1 :in2) :outputs '(:out)
        :delays (make-dict :in1 (make-dict :out 3) :in2 (make-dict :out 3))
        :logic-fn (lambda (s)
                    (make-dict :out (logior (gethash :in1 s 0) (gethash :in2 s 0)))))))
  (register-primitive 'xor
    (lambda (name param conns)
      (declare (ignore param))
      (make-instance 'logic-component
        :name name :type 'xor :connections conns
        :inputs '(:in1 :in2) :outputs '(:out)
        :delays (make-dict :in1 (make-dict :out 3) :in2 (make-dict :out 3))
        :logic-fn (lambda (s)
                    (make-dict :out (logxor (gethash :in1 s 0) (gethash :in2 s 0)))))))
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
;; 4. Expansion logic
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
  (let* ((type      (first spec))
         (name      (second spec))
         (raw-args  (cddr spec))
         (has-param (and raw-args (not (keywordp (car raw-args)))))
         (param     (when has-param (car raw-args)))
         (args      (if has-param (cdr raw-args) raw-args))
         (full-name (qualify-name prefix name))
         (resolved-conns    (parse-connections args prefix bindings))
         (module-def        (get-module type))
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
;; 5a. Mutable leftist heap
;;
;; Node layout: (rank . (elem . (left . right)))
;; Using a simple cons-cell quad so no struct allocation overhead.
;;   car  = rank (fixnum)
;;   cadr = elem (sim-event)
;;   caddr= left child (node or nil)
;;   cadddr= right child (node or nil)
;;
;; lh-merge! is fully destructive: it reuses the winning node in place,
;; updating its right child and rank.  Only lh-insert! allocates (one cons
;; quad per inserted event).
;; -----------------------------------------------------------------------------

(declaim (inline lh-rank lh-elem lh-left lh-right
                 lh-set-rank! lh-set-right! lh-set-left!
                 lh-singleton lh-empty-p lh-peek))

(defun lh-rank  (node) (if (null node) 0 (the fixnum (car node))))
(defun lh-elem  (node) (cadr node))
(defun lh-left  (node) (caddr node))
(defun lh-right (node) (cadddr node))

(defun lh-set-rank!  (node r) (setf (car   node) r))
(defun lh-set-left!  (node c) (setf (caddr  node) c))
(defun lh-set-right! (node c) (setf (cadddr node) c))

(defun lh-singleton (event)
  "Allocate a fresh singleton heap node."
  (list 1 event nil nil))

(defun lh-empty-p (node) (null node))
(defun lh-peek    (node) (cadr node))

(defun lh-merge! (h1 h2)
  "Destructively merge two leftist heaps.
   IMPORTANT: after calling this, h1 and h2 may be structurally modified.
   Safe only when no other reference to the modified nodes is retained."
  (cond
    ((null h1) h2)
    ((null h2) h1)
    (t
     ;; Winner = node with smaller event time.
     (let* ((e1 (lh-elem h1)) (e2 (lh-elem h2))
            (winner (if (<= (sim-event-time e1) (sim-event-time e2)) h1 h2))
            (loser  (if (eq winner h1) h2 h1)))
       ;; Merge loser into winner's right spine.
       (lh-set-right! winner (lh-merge! (lh-right winner) loser))
       ;; Restore leftist property: left rank >= right rank.
       (when (< (lh-rank (lh-left winner)) (lh-rank (lh-right winner)))
         (let ((tmp (lh-left winner)))
           (lh-set-left!  winner (lh-right winner))
           (lh-set-right! winner tmp)))
       ;; Update rank = 1 + rank(right child).
       (lh-set-rank! winner (1+ (lh-rank (lh-right winner))))
       winner))))

(defun lh-insert! (h event)
  "Insert EVENT into heap H; returns the new heap root."
  (lh-merge! (lh-singleton event) h))

(defun lh-pop! (h)
  "Remove the minimum event from H; returns the new heap root."
  (lh-merge! (lh-left h) (lh-right h)))

(defun lh-pop-batch! (h)
  "Remove all events at the minimum time from H.
   Returns (values batch new-root) where batch is a list."
  (when (lh-empty-p h)
    (return-from lh-pop-batch! (values nil nil)))
  (let* ((t0     (sim-event-time (lh-peek h)))
         (result nil))
    (loop while (and (not (lh-empty-p h))
                     (= (sim-event-time (lh-peek h)) t0))
          do (push (lh-peek h) result)
             (setf h (lh-pop! h)))
    (values (nreverse result) h)))

;; -----------------------------------------------------------------------------
;; 5b. Simulation engine
;; -----------------------------------------------------------------------------

(defun build-connectivity (netlist)
  (let ((connectivity (make-hash-table :test 'eq)))
    (dolist (comp netlist)
      (when (typep comp 'logic-component)
        (dolist (port (component-inputs comp))
          (let ((node (gethash port (component-connections comp))))
            (push comp (gethash node connectivity))))))
    connectivity))

(defun get-input-states (comp node-values)
  (let ((states (make-hash-table :test 'eq :size (length (component-inputs comp)))))
    (dolist (port (component-inputs comp))
      (let ((node (gethash port (component-connections comp))))
        (setf (gethash port states) (gethash node node-values 0))))
    states))

(defun get-changed-ports (comp changed-nodes)
  (loop for port in (component-inputs comp)
        for node = (gethash port (component-connections comp))
        when (gethash node changed-nodes)
        collect port))

(defun run-simulation (netlist initial-events max-time monitored-nodes)
  "Run event-driven simulation with a mutable leftist-heap event queue.
   Returns hash table: node -> list of events (chronological)."
  (let ((connectivity  (build-connectivity netlist))
        (node-values   (make-hash-table :test 'eq))
        (event-history (make-hash-table :test 'eq))
        (queue         nil)
        (current-time  0))
    ;; Seed the heap (order doesn't matter; heap will sort).
    (dolist (e initial-events)
      (setf queue (lh-insert! queue e)))
    (loop while (and (not (lh-empty-p queue))
                     (<= current-time max-time))
          do (multiple-value-bind (batch new-queue)
                 (lh-pop-batch! queue)
               (setf queue new-queue)
               (let* ((event-time    (sim-event-time (car batch)))
                      (changed-nodes (make-hash-table :test 'eq)))
                 ;; Apply node updates.
                 (dolist (evt batch)
                   (setf (gethash (sim-event-node evt) node-values) (sim-event-value evt))
                   (setf (gethash (sim-event-node evt) changed-nodes) t))
                 ;; Record monitored history.
                 (dolist (evt batch)
                   (when (gethash (sim-event-node evt) monitored-nodes)
                     (push evt (gethash (sim-event-node evt) event-history))))
                 ;; Collect affected components.
                 (let ((affected (make-hash-table :test 'eq)))
                   (maphash (lambda (node _)
                               (declare (ignore _))
                               (dolist (comp (gethash node connectivity))
                                 (setf (gethash comp affected) t)))
                             changed-nodes)
                   ;; Evaluate and enqueue new events.
                   (maphash
                     (lambda (comp _)
                       (declare (ignore _))
                       (let* ((input-states  (get-input-states comp node-values))
                              (changed-ports (get-changed-ports comp changed-nodes))
                              (results       (compute-next-state comp input-states
                                                                 changed-ports)))
                         (dolist (res results)
                           (let* ((out-node    (gethash (gate-result-port res)
                                                        (component-connections comp)))
                                  (current-val (gethash out-node node-values -1))
                                  (new-val     (gate-result-value res)))
                             (when (/= new-val current-val)
                               (setf queue
                                     (lh-insert! queue
                                                 (make-sim-event
                                                  :time  (+ event-time
                                                            (gate-result-delay res))
                                                  :node  out-node
                                                  :value new-val))))))))
                     affected))
                 (setf current-time event-time))))
    ;; Reverse history lists (built with push).
    (maphash (lambda (k v) (setf (gethash k event-history) (nreverse v)))
             event-history)
    event-history))

;; -----------------------------------------------------------------------------
;; 6. Simulation shell
;; -----------------------------------------------------------------------------

(defvar *sim-monitored* (make-hash-table :test 'eq))
(defvar *sim-events*    nil)
(defvar *sim-history*   nil)

(defun monitor-nodes (&rest nodes)
  (dolist (n nodes) (setf (gethash n *sim-monitored*) t)))

(defun add-events (&rest events)
  (setf *sim-events* (nconc *sim-events* (copy-list events))))

(defun run-lsim (module-name time)
  (setf *gate-evals* 0)
  (let* ((t0      (get-internal-real-time))
         (netlist (expand-netlist module-name))
         (t1      (get-internal-real-time)))
    (setf *last-netlist-ms*
          (* 1000.0d0 (/ (- t1 t0)
                         (float internal-time-units-per-second 1.0d0))))
    (let* ((t2     (get-internal-real-time))
           (result (run-simulation netlist *sim-events* time *sim-monitored*))
           (t3     (get-internal-real-time)))
      (setf *last-sim-ms*
            (* 1000.0d0 (/ (- t3 t2)
                           (float internal-time-units-per-second 1.0d0))))
      (setf *sim-history* result)
      :simulation-complete)))

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

;; Initialise standard gates on load.
(register-standard-gates)
