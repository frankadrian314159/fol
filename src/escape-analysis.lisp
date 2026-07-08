;;; FOL Compiler - Escape/Uniqueness Analysis (Step 2: audit mode)
;;;
;;; See docs/escape-analysis-design.md. This file implements the
;;; transient-client analysis -- uniqueness-at-death of loop accumulators and
;;; update chains, via flow- and tail-position-sensitive usage classification
;;; -- plus AUDIT MODE: when *ESCAPE-AUDIT* is non-nil, COMPILE-FORM calls
;;; AUDIT-NODE on every parsed top-level form and counters accumulate. No
;;; emitted code is ever changed by this file.
;;;
;;; Loop-accumulator qualification (the DVI/LSim pattern):
;;;   A loop parameter ACC qualifies for transient conversion iff every use is
;;;     :recur-update       -- root of a transient-safe chain feeding ACC's own
;;;                            recur position
;;;     :recur-passthrough  -- recur arg at ACC's position is ACC itself
;;;     :exit-bare          -- ACC in loop tail position (persistent! point)
;;;     :exit-update        -- tail-position transient-safe chain rooted at ACC
;;;   and at least one use is :recur-update. Any other use disqualifies,
;;;   because FOL transients are wrapper representations (see
;;;   [[transients-status]]) -- even reads break inside a converted region.
;;;   Disqualifying classifications (kept for the audit report):
;;;     :read             -- passed to a Tier-1 op that only reads it
;;;     :escape-call      -- passed to a Tier-0/retaining call
;;;     :captured         -- appears inside a closure body
;;;     :other-flow       -- any other flow (aliased into another recur slot,
;;;                          stored in a literal, returned mid-loop, ...)
;;;     :nested-loop-init -- threaded into a nested loop's initial bindings
;;;     :shadowed-bind    -- rebound by an inner bind (analysis stops there)
;;;
;;; v1 limitations (deliberate, documented in the design doc):
;;;   - closure parameter shadowing ignored (conservative: counts as capture)
;;;   - if-branched chains inside recur args not recognized (conservative)
;;;   - destructuring loop params skipped (counted as :pattern-param)

(in-package :fol.compiler.escape-analysis)

(defvar *escape-audit* nil
  "When non-nil, COMPILE-FORM feeds every parsed top-level form to AUDIT-NODE.")

;;; ============================================================================
;;; Generic AST traversal (SBCL struct introspection)
;;; ============================================================================

(defparameter +skipped-slots+ '("FORM" "POSITION" "%TYPE")
  "ast-node bookkeeping slots that never contain child AST nodes.")

(defun collect-ast-nodes (x collect)
  "Walk raw slot value X (conses, vectors), calling COLLECT on each AST node."
  (cond ((fol.compiler.ast:ast-node-p x) (funcall collect x))
        ((consp x)
         (collect-ast-nodes (car x) collect)
         (collect-ast-nodes (cdr x) collect))
        ((and (vectorp x) (not (stringp x)))
         (loop for e across x do (collect-ast-nodes e collect)))))

(defun node-children (node)
  "All direct child AST nodes of NODE, via struct slot introspection."
  (let ((kids '()))
    (dolist (slot (sb-mop:class-slots (class-of node)))
      (let ((slot-name (sb-mop:slot-definition-name slot)))
        (unless (member (symbol-name slot-name) +skipped-slots+ :test #'string=)
          (collect-ast-nodes (slot-value node slot-name)
                             (lambda (n) (push n kids))))))
    (nreverse kids)))

(defun operator-symbol (call-node)
  "The operator symbol of CALL-NODE, or NIL if the operator isn't a symbol ref."
  (let ((op (fol.compiler.ast:call-node-operator call-node)))
    (cond ((fol.compiler.ast:symbol-ref-node-p op)
           (fol.compiler.ast:symbol-ref-node-name op))
          ((symbolp op) op)
          (t nil))))

(defun keyword-operator-p (call-node)
  "True for keyword-as-accessor calls like (:key dict)."
  (let ((op (fol.compiler.ast:call-node-operator call-node)))
    (and (fol.compiler.ast:literal-node-p op)
         (keywordp (fol.compiler.ast:literal-node-value op)))))

(defun tree-contains-symbol-p (x sym)
  "True when raw form/pattern X mentions SYM (scans conses and vectors)."
  (cond ((eq x sym) t)
        ((consp x) (or (tree-contains-symbol-p (car x) sym)
                       (tree-contains-symbol-p (cdr x) sym)))
        ((and (vectorp x) (not (stringp x)))
         (some (lambda (e) (tree-contains-symbol-p e sym)) x))))

;;; ============================================================================
;;; Audit statistics
;;; ============================================================================

(defstruct audit-stats
  (functions 0)              ; defn/defn-/definline/defmethod definitions seen
  (loops 0)
  (loop-params 0)
  (candidates 0)             ; loop params with >=1 transient-safe recur update
  (qualified 0)              ; candidates whose every use is sanctioned
  (disqual-reasons (make-hash-table :test 'eq))   ; reason -> count
  (loop-details '())         ; list of (fn-hint param verdict reasons) capped
  (chains 0)                 ; thread-first runs of >=2 consecutive safe ops
  (chain-lengths '())
  (nested-chains 0)          ; nested direct-call chains (assoc (assoc x ..) ..)
  (calls 0)
  (calls-tier1 0)
  (calls-keyword 0)
  (calls-tier0 0)
  (tier0-names (make-hash-table :test 'equal))    ; symbol-name -> count
  (barriers 0))

(defvar *audit-stats* (make-audit-stats))

(defvar *audit-fn-hint* nil
  "Name of the defn currently being audited, for loop-detail reporting.")

(defparameter +loop-detail-cap+ 200)

(defun reset-audit ()
  "Zero all audit counters."
  (setf *audit-stats* (make-audit-stats))
  (values))

(defun %bump-reason (reason)
  (incf (gethash reason (audit-stats-disqual-reasons *audit-stats*) 0)))

(defparameter +barrier-names+ '("EVAL" "COMPILE-FORM" "COMPILE-STRING" "RUN-FOL-STRING"))

;;; ============================================================================
;;; Transient-safe chain recognition
;;; ============================================================================

(defvar *chain-ops* :unbound
  "When bound to a list during classification, CHAIN-KIND pushes the
   symbol-names of spine operators it accepts, so callers can check the op
   set against what a given transient representation supports. Failed probes
   may over-collect; that is conservative for the compatibility check.")

(defun %note-chain-op (op)
  (unless (eq *chain-ops* :unbound)
    (push (symbol-name op) *chain-ops*)))

(defvar *read-ops* :unbound
  "When bound to a list during classification, sanctioned :read-ok call sites
   push their operator names here (\"GET\" for keyword accessors), so
   conversions can register them as world assumptions.")

(defun %note-read-op (call-node)
  (unless (eq *read-ops* :unbound)
    (push (if (keyword-operator-p call-node)
              "GET"
              (symbol-name (operator-symbol call-node)))
          *read-ops*)))

(defun chain-kind (node name)
  "Classify NODE as a transient-safe chain rooted at variable NAME.
   Returns (values KIND OTHER-ARG-NODES) where KIND is
     :passthrough -- NODE is exactly a reference to NAME
     :update      -- NODE is >=1 nested transient-safe ops whose collection
                     argument bottoms out at NAME (direct calls or ->)
     NIL          -- not a recognized chain
   OTHER-ARG-NODES are the non-spine argument nodes (keys/values), which the
   caller must still scan for stray uses of NAME."
  (cond
    ;; Base: the variable itself
    ((and (fol.compiler.ast:symbol-ref-node-p node)
          (eq (fol.compiler.ast:symbol-ref-node-name node) name))
     (values :passthrough nil))
    ;; (assoc <chain> k v ...) or a reduce that threads the chain as init
    ((fol.compiler.ast:call-node-p node)
     (let ((op (operator-symbol node))
           (args (fol.compiler.ast:call-node-args node)))
       (cond
         ((and op args (fol.compiler.summaries:transient-safe-op-p op))
          (multiple-value-bind (kind others) (chain-kind (first args) name)
            (if kind
                (progn (%note-chain-op op)
                       (values :update (append (rest args) others)))
                (values nil nil))))
         ;; (reduce (fn [a x] <linear>) <chain> coll): the fold threads the
         ;; accumulator linearly when the lambda itself qualifies (step 5).
         ((%reduce-call-p node)
          (reduce-chain-kind node name))
         (t (values nil nil)))))
    ;; (-> <chain> (assoc ...) (conj ...) ...)
    ((fol.compiler.ast:thread-first-node-p node)
     (let ((forms (fol.compiler.ast:thread-first-node-forms node)))
       (multiple-value-bind (kind others) (chain-kind (first forms) name)
         (if (and kind
                  (every (lambda (f)
                           (and (fol.compiler.ast:call-node-p f)
                                (operator-symbol f)
                                (fol.compiler.summaries:transient-safe-op-p
                                 (operator-symbol f))))
                         (rest forms)))
             (progn
               (dolist (f (rest forms)) (%note-chain-op (operator-symbol f)))
               (values (if (rest forms) :update kind)
                       (append (mapcan (lambda (f)
                                         (copy-list (fol.compiler.ast:call-node-args f)))
                                       (rest forms))
                               others)))
             (values nil nil)))))
    ;; (if p <chain> <chain>): both branches must be chains; the test and any
    ;; non-final else forms become "others" the caller scans for stray uses.
    ((fol.compiler.ast:if-node-p node)
     (let ((else (fol.compiler.ast:if-node-else node)))
       (if (null else)
           (values nil nil)   ; missing else = nil result branch, not a chain
           (multiple-value-bind (k1 o1)
               (chain-kind (fol.compiler.ast:if-node-then node) name)
             (if (null k1)
                 (values nil nil)
                 (multiple-value-bind (k2 o2)
                     (chain-kind (car (last else)) name)
                   (if (null k2)
                       (values nil nil)
                       (values (if (or (eq k1 :update) (eq k2 :update))
                                   :update
                                   :passthrough)
                               (append (list (fol.compiler.ast:if-node-test node))
                                       (butlast else)
                                       o1 o2)))))))))
    (t (values nil nil))))

;;; ============================================================================
;;; Loop-accumulator classification
;;; ============================================================================

(defun call-arg-read-p (call-node index)
  "True when CALL-NODE's summary says argument INDEX is only read (:none),
   or the call is a keyword accessor. Distinguishes :read from :escape-call
   in the audit report."
  (or (keyword-operator-p call-node)
      (let* ((op (operator-symbol call-node))
             (summary (and op (fol.compiler.summaries:lookup-summary op))))
        (and summary
             (member (fol.compiler.summaries:effect-for-arg summary index)
                     '(:none :invoked))))))

(defparameter +transient-readable-ops+ '("GET" "NTH" "COUNT" "SIZE" "EMPTY?")
  "Read operators supported mid-session by the edit-tagged transient classes.
   Must stay in sync with the methods in collection-functions.lisp.")

(defun transient-readable-call-p (call-node)
  "True when CALL-NODE is a read the transient classes support: a keyword
   accessor, or a Tier-1 op in +TRANSIENT-READABLE-OPS+. Only sanctions the
   COLLECTION argument (position 0); the accumulator appearing as a key or
   default would change value semantics."
  (or (keyword-operator-p call-node)
      (let ((op (operator-symbol call-node)))
        (and op
             (member (symbol-name op) +transient-readable-ops+ :test #'string=)
             (fol.compiler.summaries:lookup-summary op)
             t))))

(defun classify-loop-param (name pos loop-node)
  "Classify every use of loop parameter NAME (at binding position POS) in
   LOOP-NODE's body. Returns the list of use classifications."
  (let ((uses '()))
    (labels
        ((record (kind) (push kind uses))
         (walk-last-tail (nodes tailp infn recurp &optional complexp)
           ;; Sequential body: only the last form is in tail position.
           (loop for rest on nodes
                 do (walk (car rest) (and tailp (null (cdr rest))) infn recurp
                          complexp)))
         (walk-chain-others (others infn recurp complexp)
           (dolist (n others) (walk n nil infn recurp complexp)))
         (shadows-p (pattern) (tree-contains-symbol-p pattern name))
         (walk (node tailp infn recurp &optional complexp)
           (cond
             ((null node) nil)
             ;; --- the variable itself ---
             ((fol.compiler.ast:symbol-ref-node-p node)
              (when (eq (fol.compiler.ast:symbol-ref-node-name node) name)
                (record (cond (infn :captured)
                              (tailp :exit-bare)
                              (t :other-flow)))))
             ;; --- recur: the special case this analysis exists for ---
             ((fol.compiler.ast:recur-node-p node)
              ;; A recur reachable only through node types the transient
              ;; rewriter shares verbatim cannot be rewritten -> disqualify.
              (when (and recurp complexp)
                (record :recur-in-complex-context))
              (if recurp
                  (loop for arg in (fol.compiler.ast:recur-node-args node)
                        for i from 0
                        do (if (= i pos)
                               (multiple-value-bind (kind others) (chain-kind arg name)
                                 (case kind
                                   (:passthrough (record :recur-passthrough))
                                   (:update (record :recur-update)
                                            (walk-chain-others others infn recurp complexp))
                                   ;; Not rooted at NAME: the param is being
                                   ;; RESET to an unrelated value -- the next
                                   ;; iteration would see a persistent value
                                   ;; where converted code expects a transient.
                                   (t (record :recur-reset)
                                      (walk arg nil infn recurp complexp))))
                               (walk arg nil infn recurp complexp)))
                  ;; recur belonging to an inner loop/fn: generic scan
                  (dolist (arg (fol.compiler.ast:recur-node-args node))
                    (walk arg nil infn recurp complexp))))
             ;; --- tail-position propagation ---
             ((fol.compiler.ast:if-node-p node)
              (walk (fol.compiler.ast:if-node-test node) nil infn recurp complexp)
              (walk (fol.compiler.ast:if-node-then node) tailp infn recurp complexp)
              (walk-last-tail (fol.compiler.ast:if-node-else node) tailp infn recurp complexp))
             ((fol.compiler.ast:do-node-p node)
              (walk-last-tail (fol.compiler.ast:do-node-body node) tailp infn recurp complexp))
             ((fol.compiler.ast:bind-node-p node)
              (let ((shadowed nil))
                (dolist (b (fol.compiler.ast:bind-node-bindings node))
                  (walk (cdr b) nil infn recurp complexp)
                  (when (shadows-p (car b)) (setf shadowed t)))
                (if shadowed
                    (record :shadowed-bind)
                    (walk-last-tail (fol.compiler.ast:bind-node-body node)
                                    tailp infn recurp complexp))))
             ((fol.compiler.ast:case-node-p node)
              (walk (fol.compiler.ast:case-node-expr node) nil infn recurp complexp)
              (dolist (clause (fol.compiler.ast:case-node-clauses node))
                (walk-last-tail (remove-if-not #'fol.compiler.ast:ast-node-p
                                               (if (listp (cdr clause)) (cdr clause) nil))
                                tailp infn recurp complexp)))
             ((fol.compiler.ast:cond-node-p node)
              (dolist (clause (fol.compiler.ast:cond-node-clauses node))
                (when (fol.compiler.ast:ast-node-p (car clause))
                  (walk (car clause) nil infn recurp complexp))
                (walk-last-tail (remove-if-not #'fol.compiler.ast:ast-node-p
                                               (if (listp (cdr clause)) (cdr clause) nil))
                                tailp infn recurp complexp)))
             ;; --- nested loop: its recur is not ours; init flows tagged ---
             ((fol.compiler.ast:loop-node-p node)
              (let ((inner-shadows nil))
                (dolist (b (fol.compiler.ast:loop-node-bindings node))
                  (let ((init (cdr b)))
                    (let ((found nil))
                      (collect-ast-nodes
                       init (lambda (n)
                              (when (and (fol.compiler.ast:symbol-ref-node-p n)
                                         (eq (fol.compiler.ast:symbol-ref-node-name n) name))
                                (setf found t))))
                      (when found (record :nested-loop-init))))
                  (when (shadows-p (car b)) (setf inner-shadows t)))
                (unless inner-shadows
                  (walk-last-tail (fol.compiler.ast:loop-node-body node)
                                  nil infn nil complexp))))
             ;; --- closures: captures disqualify ---
             ((fol.compiler.ast:fn-node-p node)
              (dolist (clause (fol.compiler.ast:fn-node-clauses node))
                (unless (shadows-p (car clause))
                  (walk-last-tail (cdr clause) nil t nil complexp))))
             ((fol.compiler.ast:letfn-node-p node)
              (dolist (b (fol.compiler.ast:letfn-node-bindings node))
                (collect-ast-nodes
                 b (lambda (n) (walk n nil t nil complexp))))
              (walk-last-tail (fol.compiler.ast:letfn-node-body node)
                              tailp infn recurp complexp))
             ;; --- thread-first: may be a tail-position exit chain ---
             ((fol.compiler.ast:thread-first-node-p node)
              (multiple-value-bind (kind others) (chain-kind node name)
                (cond ((and tailp (eq kind :update))
                       (record :exit-update)
                       (walk-chain-others others infn recurp complexp))
                      ((and tailp (eq kind :passthrough))
                       (record :exit-bare))
                      (t (walk-last-tail (fol.compiler.ast:thread-first-node-forms node)
                                         nil infn recurp complexp)))))
             ;; --- collection literals: a direct reference inside a
             ;; tail-position literal is an exit use (the persistent!
             ;; insertion point); anything deeper is conservative ---
             ((fol.compiler.ast:vector-node-p node)
              (dolist (el (fol.compiler.ast:vector-node-elements node))
                (if (and tailp
                         (fol.compiler.ast:symbol-ref-node-p el)
                         (eq (fol.compiler.ast:symbol-ref-node-name el) name))
                    (record :exit-in-literal)
                    (walk el nil infn recurp complexp))))
             ((fol.compiler.ast:set-node-p node)
              (dolist (el (fol.compiler.ast:set-node-elements node))
                (if (and tailp
                         (fol.compiler.ast:symbol-ref-node-p el)
                         (eq (fol.compiler.ast:symbol-ref-node-name el) name))
                    (record :exit-in-literal)
                    (walk el nil infn recurp complexp))))
             ((fol.compiler.ast:dict-node-p node)
              (dolist (entry (fol.compiler.ast:dict-node-entries node))
                (dolist (el (list (car entry) (cdr entry)))
                  (if (and tailp
                           (fol.compiler.ast:symbol-ref-node-p el)
                           (eq (fol.compiler.ast:symbol-ref-node-name el) name))
                      (record :exit-in-literal)
                      (walk el nil infn recurp complexp)))))
             ;; --- calls: tail exit chains, then per-arg classification ---
             ((fol.compiler.ast:call-node-p node)
              (multiple-value-bind (kind others) (chain-kind node name)
                (if (and tailp (eq kind :update))
                    (progn (record :exit-update)
                           (walk-chain-others others infn recurp complexp))
                    (progn
                      (walk (fol.compiler.ast:call-node-operator node) nil infn recurp complexp)
                      (loop for arg in (fol.compiler.ast:call-node-args node)
                            for i from 0
                            do (if (and (fol.compiler.ast:symbol-ref-node-p arg)
                                        (eq (fol.compiler.ast:symbol-ref-node-name arg) name))
                                   (record (cond (infn :captured)
                                                 ((and (= i 0)
                                                       (transient-readable-call-p node))
                                                  (%note-read-op node)
                                                  :read-ok)
                                                 ((call-arg-read-p node i) :read)
                                                 (t :escape-call)))
                                   (walk arg nil infn recurp complexp)))))))
             ;; --- everything else: generic descent; the transient rewriter
             ;; shares these node types verbatim, so a recur below them is
             ;; unrewritable (flagged sticky via COMPLEXP) ---
             (t (dolist (child (node-children node))
                  (walk child nil infn recurp t))))))
      (walk-last-tail (fol.compiler.ast:loop-node-body loop-node) t nil t nil)
      (nreverse uses))))

(defparameter +sanctioned-uses+
  '(:recur-update :recur-passthrough :exit-bare :exit-update :exit-in-literal
    :read-ok))

(defun param-verdict (uses)
  "Verdict for a loop param given its USES:
   (values :qualified|:not-accumulator|:disqualified bad-reasons)"
  (let ((candidate (member :recur-update uses))
        (bad (remove-duplicates
              (remove-if (lambda (u) (member u +sanctioned-uses+)) uses))))
    (cond ((not candidate) (values :not-accumulator bad))
          ((null bad) (values :qualified nil))
          (t (values :disqualified bad)))))

(defun audit-loop (loop-node)
  "Classify every parameter of LOOP-NODE and fold into *AUDIT-STATS*."
  (let ((stats *audit-stats*))
    (incf (audit-stats-loops stats))
    (loop for (pname . nil) in (fol.compiler.ast:loop-node-bindings loop-node)
          for pos from 0
          do (incf (audit-stats-loop-params stats))
             (if (not (symbolp pname))
                 (%bump-reason :pattern-param)
                 (let ((uses (classify-loop-param pname pos loop-node)))
                   (multiple-value-bind (verdict bad) (param-verdict uses)
                     (case verdict
                       (:qualified
                        (incf (audit-stats-candidates stats))
                        (incf (audit-stats-qualified stats)))
                       (:disqualified
                        (incf (audit-stats-candidates stats))
                        (dolist (r bad) (%bump-reason r))))
                     (when (and (not (eq verdict :not-accumulator))
                                (< (length (audit-stats-loop-details stats))
                                   +loop-detail-cap+))
                       (push (list *audit-fn-hint* pname verdict bad)
                             (audit-stats-loop-details stats)))))))))

;;; ============================================================================
;;; Chain and coverage audit (universal walk)
;;; ============================================================================

(defun audit-thread-first (node)
  "Count maximal runs of >=2 consecutive transient-safe forms in a -> chain."
  (let ((run 0))
    (flet ((flush ()
             (when (>= run 2)
               (incf (audit-stats-chains *audit-stats*))
               (push run (audit-stats-chain-lengths *audit-stats*)))
             (setf run 0)))
      (dolist (f (rest (fol.compiler.ast:thread-first-node-forms node)))
        (if (and (fol.compiler.ast:call-node-p f)
                 (operator-symbol f)
                 (fol.compiler.summaries:transient-safe-op-p (operator-symbol f)))
            (incf run)
            (flush)))
      (flush))))

(defun safe-call-p (node)
  (and (fol.compiler.ast:call-node-p node)
       (operator-symbol node)
       (fol.compiler.summaries:transient-safe-op-p (operator-symbol node))))

(defun audit-call (node in-safe-spine)
  "Coverage tally for one call node. IN-SAFE-SPINE is true when NODE is the
   collection argument of an enclosing transient-safe call (chain interior)."
  (let ((stats *audit-stats*)
        (op (operator-symbol node)))
    (incf (audit-stats-calls stats))
    (cond
      ((keyword-operator-p node) (incf (audit-stats-calls-keyword stats)))
      ((and op (fol.compiler.summaries:lookup-summary op))
       (incf (audit-stats-calls-tier1 stats)))
      (op
       (incf (audit-stats-calls-tier0 stats))
       (incf (gethash (symbol-name op) (audit-stats-tier0-names stats) 0)))
      (t (incf (audit-stats-calls-tier0 stats))))
    (when (and op (member (symbol-name op) +barrier-names+ :test #'string=))
      (incf (audit-stats-barriers stats)))
    ;; Nested direct-call chain head: (assoc (assoc x ...) ...) not itself
    ;; inside a larger safe spine.
    (when (and (not in-safe-spine)
               (safe-call-p node)
               (safe-call-p (first (fol.compiler.ast:call-node-args node))))
      (incf (audit-stats-nested-chains stats)))))

(defun audit-walk (node in-safe-spine)
  "Universal audit walk over NODE and its descendants."
  (cond
    ((fol.compiler.ast:defn-node-p node)
     (incf (audit-stats-functions *audit-stats*))
     (let ((*audit-fn-hint* (fol.compiler.ast:defn-node-name node)))
       (dolist (child (node-children node)) (audit-walk child nil))))
    ((fol.compiler.ast:defn-private-node-p node)
     (incf (audit-stats-functions *audit-stats*))
     (let ((*audit-fn-hint* (fol.compiler.ast:defn-private-node-name node)))
       (dolist (child (node-children node)) (audit-walk child nil))))
    ((fol.compiler.ast:definline-node-p node)
     (incf (audit-stats-functions *audit-stats*))
     (let ((*audit-fn-hint* (fol.compiler.ast:definline-node-name node)))
       (dolist (child (node-children node)) (audit-walk child nil))))
    ((fol.compiler.ast:defmethod-node-p node)
     (incf (audit-stats-functions *audit-stats*))
     (let ((*audit-fn-hint* (fol.compiler.ast:defmethod-node-name node)))
       (dolist (child (node-children node)) (audit-walk child nil))))
    ((fol.compiler.ast:loop-node-p node)
     (audit-loop node)
     (dolist (child (node-children node)) (audit-walk child nil)))
    ((fol.compiler.ast:thread-first-node-p node)
     (audit-thread-first node)
     (dolist (child (node-children node)) (audit-walk child nil)))
    ((fol.compiler.ast:call-node-p node)
     (audit-call node in-safe-spine)
     (let ((spine (and (safe-call-p node)
                       (first (fol.compiler.ast:call-node-args node)))))
       (audit-walk (fol.compiler.ast:call-node-operator node) nil)
       (dolist (arg (fol.compiler.ast:call-node-args node))
         (audit-walk arg (eq arg spine)))))
    (t (dolist (child (node-children node)) (audit-walk child nil)))))

(defun audit-node (ast)
  "Audit one parsed top-level AST node. Called by COMPILE-FORM when
   *ESCAPE-AUDIT* is non-nil."
  (audit-walk ast nil)
  (values))

;;; ============================================================================
;;; Reporting and file driver
;;; ============================================================================

(defun audit-report (&optional (stream *standard-output*))
  "Print the accumulated audit statistics."
  (let ((s *audit-stats*))
    (format stream "~&=== Escape-Analysis Audit Report ===~%")
    (format stream "Functions analyzed:        ~D~%" (audit-stats-functions s))
    (format stream "Loops seen:                ~D  (params: ~D)~%"
            (audit-stats-loops s) (audit-stats-loop-params s))
    (format stream "Accumulator candidates:    ~D~%" (audit-stats-candidates s))
    (format stream "  QUALIFIED for transient: ~D~%" (audit-stats-qualified s))
    (let ((reasons '()))
      (maphash (lambda (k v) (push (cons k v) reasons))
               (audit-stats-disqual-reasons s))
      (when reasons
        (format stream "  Disqualification reasons:~%")
        (dolist (r (sort reasons #'> :key #'cdr))
          (format stream "    ~(~A~): ~D~%" (car r) (cdr r)))))
    (format stream "Thread-first chains (>=2 safe ops): ~D~@[  lengths: ~A~]~%"
            (audit-stats-chains s)
            (and (audit-stats-chain-lengths s)
                 (sort (copy-list (audit-stats-chain-lengths s)) #'>)))
    (format stream "Nested direct-call chains: ~D~%" (audit-stats-nested-chains s))
    (format stream "Call sites: ~D total = Tier-1 ~D (~,1F%) + keyword ~D + Tier-0 ~D~%"
            (audit-stats-calls s) (audit-stats-calls-tier1 s)
            (if (zerop (audit-stats-calls s))
                0.0
                (* 100.0 (/ (audit-stats-calls-tier1 s) (audit-stats-calls s))))
            (audit-stats-calls-keyword s) (audit-stats-calls-tier0 s))
    (format stream "Barrier calls (eval etc.): ~D~%" (audit-stats-barriers s))
    (let ((names '()))
      (maphash (lambda (k v) (push (cons k v) names))
               (audit-stats-tier0-names s))
      (when names
        (format stream "Top Tier-0 (unsummarized) operators:~%")
        (loop for (name . count) in (sort names #'> :key #'cdr)
              for i below 15
              do (format stream "    ~A: ~D~%" name count))))
    (when (audit-stats-loop-details s)
      (format stream "Accumulator details (fn / param / verdict / reasons):~%")
      (dolist (d (reverse (audit-stats-loop-details s)))
        (format stream "    ~A / ~A / ~(~A~)~@[ / ~(~A~)~]~%"
                (or (first d) "top-level") (second d) (third d) (fourth d))))
    (values)))

(defun audit-file (path &key (reset t) (report t))
  "Transpile the FOL file at PATH with audit mode enabled (output goes to a
   throwaway file). Returns *AUDIT-STATS*; prints a report unless REPORT nil."
  (when reset (reset-audit))
  (let ((*escape-audit* t)
        (tmp (make-pathname :name (format nil "~A-audit" (pathname-name path))
                            :type "lisp"
                            :defaults (uiop:temporary-directory))))
    (funcall (or (find-symbol "COMPILE-FILE" :fol.compiler)
                 (error "fol.compiler:compile-file not found"))
             path :output tmp))
  (when report (audit-report))
  *audit-stats*)

;;; ============================================================================
;;; Transient loop conversion (step 3, emit-side client)
;;; ============================================================================
;;;
;;; MAYBE-TRANSIENT-LOOP is called by emit-loop. When *TRANSIENT-LOOPS* is
;;; enabled and a loop parameter (a) classifies as :qualified and (b) has a
;;; collection-literal initial value, the loop is rewritten:
;;;   init                     -> (transient init)
;;;   recur-position chains    -> bang ops (assoc -> assoc!, conj -> conj!, ...)
;;;   tail exits (bare/chain/in-literal) -> wrapped in (persistent! ...)
;;; The rewriter handles exactly the node set the classifier walks with tail
;;; awareness; recurs under any other node type were flagged
;;; :recur-in-complex-context by the classifier and never qualify, keeping
;;; the two walks aligned by construction.
;;;
;;; SOUNDNESS (batch mode): the rewrite is applied at transpile time from a
;;; single source snapshot; Tier-1 ops are name-resolved exactly as emit-call
;;; resolves them. Live-image guard machinery is step 4; until then the flag
;;; should be enabled only for whole-file transpiles.

(defvar *transient-loops* nil
  "When non-nil, emit-loop converts qualifying loop accumulators to the
   transient protocol. Opt-in; sound under batch-compilation assumptions.")

(defvar *scalar-replacement* nil
  "When non-nil, enables scalar replacement of non-escaping persistent objects.
   Opt-in; sound under batch-compilation assumptions until world guards are fully integrated.")

(defvar *numeric-specialization* nil
  "When non-nil, loops whose scalar variables have inferable numeric types get
   their generic arithmetic (+,-,*,/,inc,dec,<,>,...) rewritten to CL operators
   on the proven-number path, and float/integer-typed loop variables get CL type
   declarations so SBCL emits unboxed machine arithmetic. Opt-in; sound (an
   operator is rewritten only when every operand is proven numeric, and a
   variable is declared only when its type is proven and stable). Pairs with
   *scalar-replacement*, which exposes the scalars this pass then types.")

(defvar *loops-converted* 0)
(defvar *params-converted* 0)

(defparameter +collections-package+ "FOL.COMPILER.COLLECTIONS")

(defun %collections-symbol (name)
  (or (find-symbol name +collections-package+)
      (error "Transient protocol symbol ~A not found in ~A"
             name +collections-package+)))

(defun %ref (sym)
  (fol.compiler.ast:make-symbol-ref-node :name sym :form sym))

(defun %call1 (fn-name arg-node)
  (fol.compiler.ast:make-call-node
   :operator (%ref (%collections-symbol fn-name))
   :args (list arg-node)
   :form (fol.compiler.ast:ast-node-form arg-node)))

(defun transient-eligible-init-p (node)
  "True when the loop init is a collection literal ((dict ...), [..], #{..}),
   so (transient init) is guaranteed to produce a mutable wrapper."
  (or (fol.compiler.ast:vector-node-p node)
      (fol.compiler.ast:dict-node-p node)
      (fol.compiler.ast:set-node-p node)))

(defun init-supports-p (init-node chain-ops reads-p)
  "True when the transient representation behind INIT-NODE's collection type
   supports every spine op in CHAIN-OPS, and reads when READS-P.
   Dicts/vectors are edit-tagged (reads supported); sets remain wrapper
   transients (writes only)."
  (cond
    ((fol.compiler.ast:dict-node-p init-node)
     (subsetp chain-ops '("ASSOC" "DISSOC") :test #'string=))
    ((fol.compiler.ast:vector-node-p init-node)
     (subsetp chain-ops '("CONJ") :test #'string=))
    ((fol.compiler.ast:set-node-p init-node)
     (and (not reads-p)
          (subsetp chain-ops '("CONJ" "DISJ") :test #'string=)))
    (t nil)))

(defun %reads-present-p (uses)
  "Reads seen either directly in USES or collected from nested linear
   reduce lambdas via *READ-OPS*."
  (or (member :read-ok uses)
      (and (not (eq *read-ops* :unbound)) (consp *read-ops*))))

(defun rewrite-loop-body (body qnames pos-names &optional (mode :loop))
  "Rewrite BODY (list of nodes) converting the qualified accumulators QNAMES
   (POS-NAMES maps recur position -> qualified name or NIL) to transient ops.
   MODE :loop wraps tail exits in (persistent! ...); MODE :reduce leaves tail
   values as transients (the reduce wrapper applies persistent! once, outside)."
  (labels
      ((qref-p (n)
         (and (fol.compiler.ast:symbol-ref-node-p n)
              (member (fol.compiler.ast:symbol-ref-node-name n) qnames)))
       (bang-ref (call)
         (%ref (%collections-symbol
                (fol.compiler.summaries:transient-op-for (operator-symbol call)))))
       (rewrite-chain (n name)
         (cond
           ((fol.compiler.ast:symbol-ref-node-p n) n) ; the accumulator itself
           ;; Reduce chain link: rewrite the lambda body in :reduce mode (the
           ;; transient flows through with no inner boundaries) and thread
           ;; the init spine.
           ((and (fol.compiler.ast:call-node-p n) (%reduce-call-p n))
            (destructuring-bind (f init coll) (fol.compiler.ast:call-node-args n)
              (let* ((clause (first (fol.compiler.ast:fn-node-clauses f)))
                     (inner-acc (first (%param-names (car clause)))))
                (fol.compiler.ast:make-call-node
                 :operator (fol.compiler.ast:call-node-operator n)
                 :args (list (fol.compiler.ast:make-fn-node
                              :name (fol.compiler.ast:fn-node-name f)
                              :clauses (list (cons (car clause)
                                                   (rewrite-loop-body
                                                    (cdr clause) (list inner-acc)
                                                    #() :reduce)))
                              :docstring nil
                              :form (fol.compiler.ast:ast-node-form f))
                             (rewrite-chain init name)
                             (rw coll nil))
                 :form (fol.compiler.ast:ast-node-form n)))))
           ((fol.compiler.ast:call-node-p n)
            (let ((args (fol.compiler.ast:call-node-args n)))
              (fol.compiler.ast:make-call-node
               :operator (bang-ref n)
               :args (cons (rewrite-chain (first args) name)
                           (mapcar (lambda (a) (rw a nil)) (rest args)))
               :form (fol.compiler.ast:ast-node-form n))))
           ((fol.compiler.ast:thread-first-node-p n)
            (let ((forms (fol.compiler.ast:thread-first-node-forms n)))
              (fol.compiler.ast:make-thread-first-node
               :forms (cons (rewrite-chain (first forms) name)
                            (mapcar (lambda (f)
                                      (fol.compiler.ast:make-call-node
                                       :operator (bang-ref f)
                                       :args (mapcar (lambda (a) (rw a nil))
                                                     (fol.compiler.ast:call-node-args f))
                                       :form (fol.compiler.ast:ast-node-form f)))
                                    (rest forms)))
               :form (fol.compiler.ast:ast-node-form n))))
           ((fol.compiler.ast:if-node-p n)
            (let ((else (fol.compiler.ast:if-node-else n)))
              (fol.compiler.ast:make-if-node
               :test (rw (fol.compiler.ast:if-node-test n) nil)
               :then (rewrite-chain (fol.compiler.ast:if-node-then n) name)
               :else (append (mapcar (lambda (e) (rw e nil)) (butlast else))
                             (list (rewrite-chain (car (last else)) name)))
               :form (fol.compiler.ast:ast-node-form n))))
           (t (error "rewrite-chain: unexpected chain node ~S" n))))
       (rewrite-recur (n)
         (fol.compiler.ast:make-recur-node
          :args (loop for arg in (fol.compiler.ast:recur-node-args n)
                      for i from 0
                      for qname = (and (< i (length pos-names)) (aref pos-names i))
                      collect (if qname
                                  (case (chain-kind arg qname)
                                    (:update (rewrite-chain arg qname))
                                    (:passthrough arg)
                                    (t (rw arg nil)))
                                  (rw arg nil)))
          :form (fol.compiler.ast:ast-node-form n)))
       (finish (n)
         ;; What happens to a transient value leaving via a tail position.
         (if (eq mode :loop) (%call1 "PERSISTENT!" n) n))
       (try-tail-chain (n)
         (dolist (q qnames nil)
           (when (eq (chain-kind n q) :update)
             (return (finish (rewrite-chain n q))))))
       (wrap-if-qref (el tailp)
         (if (and tailp (qref-p el))
             (finish el)
             (rw el nil)))
       (rw-list (nodes tailp)
         (loop for rest on nodes
               collect (rw (car rest) (and tailp (null (cdr rest))))))
       (rw (n tailp)
         (cond
           ((null n) n)
           ((fol.compiler.ast:recur-node-p n) (rewrite-recur n))
           ((qref-p n) (if tailp (finish n) n))
           ((fol.compiler.ast:symbol-ref-node-p n) n)
           ((fol.compiler.ast:if-node-p n)
            (fol.compiler.ast:make-if-node
             :test (rw (fol.compiler.ast:if-node-test n) nil)
             :then (rw (fol.compiler.ast:if-node-then n) tailp)
             :else (rw-list (fol.compiler.ast:if-node-else n) tailp)
             :form (fol.compiler.ast:ast-node-form n)))
           ((fol.compiler.ast:do-node-p n)
            (fol.compiler.ast:make-do-node
             :body (rw-list (fol.compiler.ast:do-node-body n) tailp)
             :form (fol.compiler.ast:ast-node-form n)))
           ((fol.compiler.ast:bind-node-p n)
            (fol.compiler.ast:make-bind-node
             :bindings (mapcar (lambda (b) (cons (car b) (rw (cdr b) nil)))
                               (fol.compiler.ast:bind-node-bindings n))
             :body (rw-list (fol.compiler.ast:bind-node-body n) tailp)
             :form (fol.compiler.ast:ast-node-form n)))
           ((fol.compiler.ast:case-node-p n)
            (fol.compiler.ast:make-case-node
             :expr (rw (fol.compiler.ast:case-node-expr n) nil)
             :clauses (mapcar (lambda (c) (cons (car c) (rw-list (cdr c) tailp)))
                              (fol.compiler.ast:case-node-clauses n))
             :form (fol.compiler.ast:ast-node-form n)))
           ((fol.compiler.ast:cond-node-p n)
            (fol.compiler.ast:make-cond-node
             :clauses (mapcar (lambda (c)
                                (cons (if (fol.compiler.ast:ast-node-p (car c))
                                          (rw (car c) nil)
                                          (car c))
                                      (rw-list (cdr c) tailp)))
                              (fol.compiler.ast:cond-node-clauses n))
             :form (fol.compiler.ast:ast-node-form n)))
           ((fol.compiler.ast:letfn-node-p n)
            (fol.compiler.ast:make-letfn-node
             :bindings (fol.compiler.ast:letfn-node-bindings n)
             :body (rw-list (fol.compiler.ast:letfn-node-body n) tailp)
             :form (fol.compiler.ast:ast-node-form n)))
           ;; Nested loops and closures: qualification guarantees no
           ;; accumulator uses inside -- share verbatim.
           ((fol.compiler.ast:loop-node-p n) n)
           ((fol.compiler.ast:fn-node-p n) n)
           ((fol.compiler.ast:thread-first-node-p n)
            (or (and tailp (try-tail-chain n))
                (fol.compiler.ast:make-thread-first-node
                 :forms (mapcar (lambda (f) (rw f nil))
                                (fol.compiler.ast:thread-first-node-forms n))
                 :form (fol.compiler.ast:ast-node-form n))))
           ((fol.compiler.ast:call-node-p n)
            (or (and tailp (try-tail-chain n))
                (fol.compiler.ast:make-call-node
                 :operator (rw (fol.compiler.ast:call-node-operator n) nil)
                 :args (mapcar (lambda (a) (rw a nil))
                               (fol.compiler.ast:call-node-args n))
                 :form (fol.compiler.ast:ast-node-form n))))
           ((fol.compiler.ast:vector-node-p n)
            (fol.compiler.ast:make-vector-node
             :elements (mapcar (lambda (el) (wrap-if-qref el tailp))
                               (fol.compiler.ast:vector-node-elements n))
             :form (fol.compiler.ast:ast-node-form n)))
           ((fol.compiler.ast:set-node-p n)
            (fol.compiler.ast:make-set-node
             :elements (mapcar (lambda (el) (wrap-if-qref el tailp))
                               (fol.compiler.ast:set-node-elements n))
             :form (fol.compiler.ast:ast-node-form n)))
           ((fol.compiler.ast:dict-node-p n)
            (fol.compiler.ast:make-dict-node
             :entries (mapcar (lambda (entry)
                                (cons (wrap-if-qref (car entry) tailp)
                                      (wrap-if-qref (cdr entry) tailp)))
                              (fol.compiler.ast:dict-node-entries n))
             :form (fol.compiler.ast:ast-node-form n)))
           ;; Everything else: qualification guarantees no accumulator uses
           ;; or reachable recurs below (classifier's :recur-in-complex-context).
           (t n))))
    (rw-list body t)))

;;; --- Reduce-accumulator client -------------------------------------------
;;; (reduce (fn [acc x] <acc linearly updated>) <literal-init> coll)
;;;   => (persistent! (reduce (fn [acc x] <bang body>) (transient init) coll))

(defvar *reduces-converted* 0)

(defun %param-names (params)
  "Coerce a clause parameter vector (FOL <vector> or CL vector) to a list."
  (cond ((and (vectorp params) (not (stringp params))) (coerce params 'list))
        ((typep params 'fol.compiler.collections:<vector>)
         (fol.compiler.collections:collection-seq params))
        ((listp params) params)
        (t nil)))

(defun %contains-recur-p (node)
  (labels ((scan (n)
             (when (fol.compiler.ast:recur-node-p n)
               (return-from %contains-recur-p t))
             (dolist (c (node-children n)) (scan c))))
    (scan node)
    nil))

(defun reduce-acc-qualified-p (name body-nodes)
  "Qualification for a reduce lambda's accumulator NAME: every use is a
   tail-position transient-safe chain (>=1 update), tail passthrough, or a
   supported read. Returns (values qualified-p uses)."
  (let ((uses (classify-loop-param
               name 0
               (fol.compiler.ast:make-loop-node
                :bindings (list (cons name nil))
                :body body-nodes
                :form nil))))
    (values (and (member :exit-update uses)
                 (null (set-difference uses '(:exit-update :exit-bare :read-ok))))
            uses)))

(defun %reduce-call-p (node)
  (and (fol.compiler.ast:call-node-p node)
       (let ((op (operator-symbol node)))
         (and op
              (string= (symbol-name op) "REDUCE")
              (fol.compiler.summaries:lookup-summary op)
              (= 3 (length (fol.compiler.ast:call-node-args node)))))))

(defun %tree-refs-name-p (node name)
  "True when the AST subtree under NODE references variable NAME."
  (labels ((scan (n)
             (when (and (fol.compiler.ast:symbol-ref-node-p n)
                        (eq (fol.compiler.ast:symbol-ref-node-name n) name))
               (return-from %tree-refs-name-p t))
             (dolist (c (node-children n)) (scan c))))
    (scan node)
    nil))

(defun %linear-reduce-lambda (f name)
  "When F is a single-clause two-symbol-param lambda whose accumulator is
   linearly consumed (reduce-client rules) and which does not capture NAME
   (unless its own params shadow it), return the accumulator param symbol;
   else NIL."
  (and (fol.compiler.ast:fn-node-p f)
       (= 1 (length (fol.compiler.ast:fn-node-clauses f)))
       (let* ((clause (first (fol.compiler.ast:fn-node-clauses f)))
              (params (%param-names (car clause)))
              (acc (first params)))
         (and (= 2 (length params))
              (symbolp acc)
              (symbolp (second params))
              (not (eq acc (second params)))
              (not (%contains-recur-p f))
              (or (member name params)
                  (not (%tree-refs-name-p f name)))
              (reduce-acc-qualified-p acc (cdr clause))
              acc))))

(defun reduce-chain-kind (node name)
  "Chain-link classification for (reduce (fn [a x] <linear>) <chain> coll):
   the fold consumes the chained accumulator linearly, one lambda step at a
   time, and returns it -- so the whole reduce call is an :update link.
   The lambda's spine ops and reads flow into *CHAIN-OPS*/*READ-OPS* through
   its own classification, so the init-type gate sees them."
  (destructuring-bind (f init coll) (fol.compiler.ast:call-node-args node)
    (if (not (%linear-reduce-lambda f name))
        (values nil nil)
        (multiple-value-bind (kind others) (chain-kind init name)
          (if (null kind)
              (values nil nil)
              (values :update (cons coll others)))))))

(defun maybe-transient-reduce (node)
  "When *TRANSIENT-LOOPS* is enabled and NODE is a convertible reduce call,
   return the transient-protocol rewrite; otherwise NODE. Called by emit-call.
   Second value: the summarized operator names the conversion assumed.
   No recursion hazard: the rewritten reduce's init is a (transient ...) call,
   which fails the literal-init eligibility check on re-entry."
  (if (not (and *transient-loops* (%reduce-call-p node)))
      node
      (destructuring-bind (f init coll) (fol.compiler.ast:call-node-args node)
        (let* ((fn-ok (and (fol.compiler.ast:fn-node-p f)
                           (= 1 (length (fol.compiler.ast:fn-node-clauses f)))))
               (clause (and fn-ok (first (fol.compiler.ast:fn-node-clauses f))))
               (params (and clause (%param-names (car clause))))
               (acc (first params))
               (*chain-ops* '())
               (*read-ops* '()))
          (if (not (and fn-ok
                        (transient-eligible-init-p init)
                        (= 2 (length params))
                        (symbolp acc)
                        (symbolp (second params))
                        (not (eq acc (second params)))
                        (not (%contains-recur-p f))
                        (multiple-value-bind (ok uses)
                            (reduce-acc-qualified-p acc (cdr clause))
                          (and ok (init-supports-p init *chain-ops*
                                                   (%reads-present-p uses))))))
              node
              (progn
                (incf *reduces-converted*)
                (values
                 (%call1
                  "PERSISTENT!"
                  (fol.compiler.ast:make-call-node
                   :operator (fol.compiler.ast:call-node-operator node)
                   :args (list (fol.compiler.ast:make-fn-node
                                :name (fol.compiler.ast:fn-node-name f)
                                :clauses (list (cons (car clause)
                                                     (rewrite-loop-body
                                                      (cdr clause) (list acc)
                                                      #() :reduce)))
                                :docstring nil
                                :form (fol.compiler.ast:ast-node-form f))
                               (%call1 "TRANSIENT" init)
                               coll)
                   :form (fol.compiler.ast:ast-node-form node)))
                 (union (union *chain-ops* *read-ops* :test #'string=)
                        (list "REDUCE") :test #'string=))))))))

;;; --- Dynamic-extent closure client (step 5) --------------------------------
;;; (mapv (fn [x] ...) coll) allocates a fresh closure per call; when the
;;; callee provably invokes-without-retaining it (hand-verified eager HOFs,
;;; :invoked in Tier-1), the closure can be stack-allocated:
;;;   (let ((dx-fn-N (fn ...))) (declare (dynamic-extent dx-fn-N))
;;;     (mapv dx-fn-N coll))
;;; Emitted world-guarded (a redefinition that RETAINS the closure would
;;; leave a dangling stack object -- worse than a wrong answer).

(defvar *stack-closures* nil
  "When non-nil, closures passed to hand-verified non-retaining Tier-1 HOFs
   are stack-allocated via dynamic-extent. Opt-in, world-guarded.")

(defparameter +dx-invoked-ops+ '("MAPV" "FILTERV" "REDUCE" "EVERY" "SOME")
  "Eager stdlib HOFs verified to invoke their position-0 function argument
   during the call and never retain it. All take the function at position 0,
   so hoisting it preserves left-to-right evaluation order.")

(defun dx-call-p (node)
  "True when NODE is a call whose position-0 argument is a literal fn that
   the (whitelisted, Tier-1) callee invokes without retaining."
  (and *stack-closures*
       (fol.compiler.ast:call-node-p node)
       (let ((op (operator-symbol node))
             (args (fol.compiler.ast:call-node-args node)))
         (and op args
              (fol.compiler.ast:fn-node-p (first args))
              (member (symbol-name op) +dx-invoked-ops+ :test #'string=)
              (let ((summary (fol.compiler.summaries:lookup-summary op)))
                (and summary
                     (eq :invoked
                         (fol.compiler.summaries:effect-for-arg summary 0))))))))

(defun maybe-transient-loop (node)
  "When *TRANSIENT-LOOPS* is enabled, return a rewritten copy of loop NODE
   with qualifying accumulators converted to the transient protocol;
   otherwise return NODE unchanged. Called by emit-loop.
   Second value: the summarized operator names the conversion assumed.
   Third value: a profitability-check form to be emitted as a runtime guard,
   or NIL if no check is needed."
  (if (not *transient-loops*)
      node
      (let* ((bindings (fol.compiler.ast:loop-node-bindings node))
             (pos-names (make-array (length bindings) :initial-element nil))
             (qnames '())
             (assumptions '()))
        (loop for (pname . init) in bindings
              for i from 0
              for pos from 0
              do (when (and (symbolp pname)
                            (transient-eligible-init-p init))
                   (let* ((*chain-ops* '())
                          (*read-ops* '())
                          (uses (classify-loop-param pname pos node)))
                     (when (and (eq :qualified (param-verdict uses))
                                (init-supports-p init *chain-ops*
                                                 (%reads-present-p uses)))
                       (push pname qnames)
                       (setf (aref pos-names pos) pname)
                       (setf assumptions
                             (union (union *chain-ops* *read-ops* :test #'string=)
                                    assumptions :test #'string=))))))
        (if (null qnames)
            node
            (let* ((first-qname (first qnames))
                   (first-qpos (position first-qname (mapcar #'car bindings)))
                   (first-qinit (cdr (nth first-qpos bindings)))
                   ;; Profitability guard applies only to accumulators that
                   ;; START from a non-empty collection: for those, conversion
                   ;; pays only above an empirically-measured initial size
                   ;; (crossover 16 for dicts, 12 for vectors). A loop growing
                   ;; an accumulator from an EMPTY literal must not be guarded
                   ;; on initial size -- count(empty)=0 never exceeds the
                   ;; threshold, which would make the fast path unreachable for
                   ;; the most common (and most profitable) accumulation shape.
                   (threshold (cond
                                ((and (fol.compiler.ast:dict-node-p first-qinit)
                                      (fol.compiler.ast:dict-node-entries first-qinit))
                                 16)
                                ((and (fol.compiler.ast:vector-node-p first-qinit)
                                      (fol.compiler.ast:vector-node-elements first-qinit))
                                 12)
                                (t nil)))
                   (profit-check (when threshold
                                   `(< ,threshold (fol.compiler.collection-functions:count ,first-qname)))))
              (progn
                (incf *loops-converted*)
                (incf *params-converted* (length qnames))
                (values
                 (fol.compiler.ast:make-loop-node
                  :bindings (loop for (pname . init) in bindings
                                  collect (cons pname
                                                (if (member pname qnames)
                                                    (%call1 "TRANSIENT" init)
                                                    init)))
                  :body (rewrite-loop-body (fol.compiler.ast:loop-node-body node)
                                           qnames pos-names)
                  :form (fol.compiler.ast:ast-node-form node))
                 assumptions
                 profit-check
                 ;; When a profitability check is emitted it references the
                 ;; accumulator by name, but the accumulator is bound only
                 ;; *inside* each loop. Return (name . init-node) so emit-loop
                 ;; can bind it in an outer LET that scopes the guard.
                 (when profit-check (cons first-qname first-qinit)))))))))

;;; ============================================================================
;;; Tier-2 Summary Inference (step 6)
;;; ============================================================================

(defun %infer-summary-single-pass (fn-node)
  "The core single-pass analysis for inferring a function's summary.
   This is called repeatedly by the fixed-point iterator."
  (if (or (not (fol.compiler.ast:fn-node-p fn-node))
          (/= 1 (length (fol.compiler.ast:fn-node-clauses fn-node))))
      ;; For now, only handle single-clause functions. Multi-clause dispatch
      ;; would require joining summaries from each clause.
      (return-from %infer-summary-single-pass nil))

  (let* ((clause (first (fol.compiler.ast:fn-node-clauses fn-node)))
         (params (%param-names (car clause)))
         (body (cdr clause))
         (param-effects (make-array (length params) :initial-element :none))
         ;; A function returns a fresh (uniquely-owned) value unless it returns
         ;; one of its parameters in tail position. Default T; cleared below.
         (returns-fresh-p t)
         (barrier-p nil))

    (labels ((param-index (name)
               (position name params :test #'eq))
             (update-effect (index effect)
               (setf (svref param-effects index)
                     (fol.compiler.summaries:effect-join
                      (svref param-effects index) effect)))
             (walk (node tailp)
               (cond
                 ((null node) nil)
                 ;; A parameter returned directly is :shared-with-result, and
                 ;; means the function does not return a fresh value.
                 ((fol.compiler.ast:symbol-ref-node-p node)
                  (let ((idx (param-index (fol.compiler.ast:symbol-ref-node-name node))))
                    (when (and idx tailp)
                      (update-effect idx :shared-with-result)
                      (setf returns-fresh-p nil))))

                 ((fol.compiler.ast:call-node-p node)
                  (let* ((op (operator-symbol node))
                         (summary (and op (fol.compiler.summaries:lookup-summary op))))
                    (when (and op (member (symbol-name op) +barrier-names+ :test #'string=))
                      (setf barrier-p t))

                    (walk (fol.compiler.ast:call-node-operator node) nil)
                    (loop for arg in (fol.compiler.ast:call-node-args node)
                          for i from 0
                          do (if (fol.compiler.ast:symbol-ref-node-p arg)
                                 (let ((idx (param-index (fol.compiler.ast:symbol-ref-node-name arg))))
                                   (when idx
                                     (update-effect idx (if summary
                                                            (fol.compiler.summaries:effect-for-arg summary i)
                                                            :retained))))
                                 (walk arg nil)))))

                 ((fol.compiler.ast:if-node-p node)
                  (walk (fol.compiler.ast:if-node-test node) nil)
                  (walk (fol.compiler.ast:if-node-then node) tailp)
                  (dolist (form (fol.compiler.ast:if-node-else node))
                    (walk form tailp)))

                 ((fol.compiler.ast:do-node-p node)
                  (loop for rest on (fol.compiler.ast:do-node-body node)
                        do (walk (car rest) (and tailp (null (cdr rest))))))

                 ((fol.compiler.ast:bind-node-p node)
                  (dolist (b (fol.compiler.ast:bind-node-bindings node))
                    (walk (cdr b) nil))
                  (loop for rest on (fol.compiler.ast:bind-node-body node)
                        do (walk (car rest) (and tailp (null (cdr rest))))))

                 ;; For closures, any captured parameter is marked as :retained.
                 ;; A more precise analysis would track the closure's lifetime.
                 ((fol.compiler.ast:fn-node-p node)
                  (dolist (p params)
                    (when (%tree-refs-name-p node p)
                      (let ((idx (param-index p)))
                        (when idx (update-effect idx :retained))))))

                 ;; Default traversal
                 (t (dolist (child (node-children node))
                      (walk child nil))))))

      (loop for form in body
            for lastp = (eq form (car (last body)))
            do (walk form (and lastp t))))

    ;; If any parameter has a :retained effect, the function cannot guarantee
    ;; freshness of its return value if it's derived from that parameter.
    (loop for effect across param-effects
          for i from 0
          do (when (eq effect :retained)
               (setf returns-fresh-p nil)))

    (fol.compiler.summaries:make-escape-summary
     :name (let ((n (fol.compiler.ast:fn-node-name fn-node)))
             (if n (string n) "anonymous"))
     :param-effects param-effects
     :rest-effect nil ; Non-recursive version doesn't handle &rest
     :returns-fresh-p returns-fresh-p
     :barrier-p barrier-p)))


(defun infer-summary (fn-node)
  "Infer an escape-summary for a literal FN-NODE. This is the core of the
   Tier-2 interprocedural analysis.

   For recursive functions, this function iterates to a fixed point to find
   the most precise possible summary."
  (let ((name (fol.compiler.ast:fn-node-name fn-node)))
    ;; If the function is anonymous or contains loop/recur, we can't handle
    ;; recursion, so just do a single pass.
    (when (or (not name) (%contains-recur-p fn-node))
      (return-from infer-summary (%infer-summary-single-pass fn-node)))

    (let* ((params (%param-names (car (first (fol.compiler.ast:fn-node-clauses fn-node)))))
           (param-count (length params))
           ;; Start with the most optimistic summary: nothing escapes, returns fresh.
           (current-summary
             (fol.compiler.summaries:make-escape-summary
              :name (string name)
              :param-effects (make-array param-count :initial-element :none)
              :returns-fresh-p t))
           (iteration-count 0)
           (max-iterations 5)) ; Safety break

      (loop
        (when (> (incf iteration-count) max-iterations)
          (warn "infer-summary for ~S did not converge after ~D iterations." name max-iterations)
          ;; Return a conservative summary on failure to converge.
          (return (fol.compiler.summaries:make-escape-summary
                   :name (string name)
                   :param-effects (make-array param-count :initial-element :retained))))

        ;; Temporarily place the current assumption in the cache so recursive calls find it.
        (setf (gethash name fol.compiler.summaries:*inferred-summaries*) current-summary)

        (let* ((next-summary (%infer-summary-single-pass fn-node))
               (joined-summary (fol.compiler.summaries:summary-join current-summary next-summary)))
          (when (fol.compiler.summaries:summary<= joined-summary current-summary)
            (return joined-summary)) ; Fixed point reached.
          (setf current-summary joined-summary))))))
