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

;;; ============================================================================
;;; Helper inlining ("the DVI gap")
;;;
;;; A loop that threads its accumulator through a user-defined helper, e.g.
;;; (recur (add-item cart price) ...) where
;;;   (defn add-item [cart price] (assoc cart price (inc (get cart price 0))))
;;; was previously an unconditional disqualifier: CHAIN-KIND only recognizes
;;; direct calls to summarized stdlib ops, ->  threads, if-branches, and
;;; linearly-threading REDUCE calls (see the module docstring at the top of
;;; this file, and the design doc's DVI case study). ADD-ITEM's own body,
;;; though, *is* one of those recognized shapes -- it just needs to be
;;; substituted in at the call site before CHAIN-KIND can see it.
;;;
;;; MAYBE-REGISTER-INLINABLE-HELPER (defined after CHAIN-KIND, since it calls
;;; it) checks, once per top-level defn, whether the defn's single-clause
;;; body is itself a chain rooted at exactly one of its parameters
;;; (referenced exactly once in the body, so substituting a call site's
;;; actual argument -- itself possibly a further chain -- never duplicates
;;; it). %TR-INLINE-ATTEMPT is the call-site side: given a call to a
;;; registered helper, and safe (symbol-ref or literal) arguments at every
;;; non-accumulator position, it substitutes actuals for formals and returns
;;; the result for CHAIN-KIND/REWRITE-CHAIN to recurse into -- so multi-level
;;; helper chains compose for free via that recursion, with no separate
;;; expansion machinery. Only backward references are inlinable (a helper
;;; can only inline helpers already registered when IT is compiled), mirroring
;;; how Tier-2 summary inference is also scoped to already-compiled forms in
;;; the same compilation unit; this rules out unbounded recursion by
;;; construction, not by an iteration-count fallback.
;;; ============================================================================

(defvar *tr-inlinable-fns* (make-hash-table :test 'eq)
  "Maps a defn name (symbol) to (PARAMS BODY-NODE ACC-POSITION): a
   single-clause helper whose body is one expression CHAIN-KIND recognizes as
   an update chain rooted at its ACC-POSITION-th parameter. Populated
   incrementally, in file order, by MAYBE-REGISTER-INLINABLE-HELPER.")

(defvar *inlined-helpers* :unbound
  "When bound to a list during classification/rewriting, each helper name
   inlined at a chain position pushes itself here (a symbol), so the
   region's world-guard assumptions include the helper -- a redefinition of
   the helper must invalidate the region exactly as a redefinition of ASSOC
   or CONJ already does, even though the helper is user code, not a Tier-1
   op. Kept separate from *CHAIN-OPS*, which specifically tracks
   representation-affecting op names for the per-representation op-gate
   check; a helper's own name must never appear there.")

(defun %note-inlined-helper (name)
  (unless (eq *inlined-helpers* :unbound)
    (pushnew name *inlined-helpers*)))

(defun %tr-strip-docstring (body-nodes)
  "Drop a leading string-literal docstring from a clause body, if present."
  (if (and (cdr body-nodes)
           (fol.compiler.ast:literal-node-p (car body-nodes))
           (stringp (fol.compiler.ast:literal-node-value (car body-nodes))))
      (cdr body-nodes)
      body-nodes))

(defun %tr-symbol-ref-count (node name)
  "Count of NODE's subtree references to variable NAME."
  (let ((n 0))
    (labels ((scan (x)
               (when (and (fol.compiler.ast:symbol-ref-node-p x)
                          (eq (fol.compiler.ast:symbol-ref-node-name x) name))
                 (incf n))
               (dolist (c (node-children x)) (scan c))))
      (scan node))
    n))

(defun %tr-inline-subst (node subst)
  "Copy NODE, substituting each formal parameter in SUBST (an alist of
   formal-symbol . actual-node) with its actual argument. Only descends
   through the node shapes CHAIN-KIND/REWRITE-CHAIN themselves recognize
   (symbol-ref, call, thread-first, if); a helper body using any other shape
   at a given point will simply fail re-classification after substitution,
   which is safe -- it just means that helper doesn't inline."
  (cond
    ((fol.compiler.ast:symbol-ref-node-p node)
     (let ((sub (assoc (fol.compiler.ast:symbol-ref-node-name node) subst)))
       (if sub (cdr sub) node)))
    ((fol.compiler.ast:call-node-p node)
     (fol.compiler.ast:make-call-node
      :operator (fol.compiler.ast:call-node-operator node)
      :args (mapcar (lambda (a) (%tr-inline-subst a subst))
                    (fol.compiler.ast:call-node-args node))
      :form (fol.compiler.ast:ast-node-form node)))
    ((fol.compiler.ast:thread-first-node-p node)
     (fol.compiler.ast:make-thread-first-node
      :forms (mapcar (lambda (f) (%tr-inline-subst f subst))
                     (fol.compiler.ast:thread-first-node-forms node))
      :form (fol.compiler.ast:ast-node-form node)))
    ((fol.compiler.ast:if-node-p node)
     (fol.compiler.ast:make-if-node
      :test (%tr-inline-subst (fol.compiler.ast:if-node-test node) subst)
      :then (%tr-inline-subst (fol.compiler.ast:if-node-then node) subst)
      :else (mapcar (lambda (e) (%tr-inline-subst e subst))
                    (fol.compiler.ast:if-node-else node))
      :form (fol.compiler.ast:ast-node-form node)))
    (t node)))

(defun %tr-inline-attempt (node)
  "If NODE is a call to a registered inlinable helper (see
   *TR-INLINABLE-FNS*), and every argument is safe to substitute in its
   position, return the helper's body with actual arguments substituted for
   its formals. Otherwise NIL. An argument at a non-accumulator position
   must be a symbol-ref or literal (cheap to relocate, and those positions
   are never referenced more than once by construction -- MAYBE-REGISTER-
   INLINABLE-HELPER only ever qualifies the accumulator position for
   repeated reference). The accumulator-position argument may be an
   arbitrary chain expression when the helper references its accumulator
   parameter exactly once (no duplication occurs); when the helper
   references it more than once (the read-heavy shape, e.g. \\(assoc cart
   price (inc (get cart price 0))\\)), the actual argument must ALSO be a
   symbol-ref or literal, or substitution would duplicate a possibly
   complex/effectful expression.
   Purely mechanical otherwise -- the caller is responsible for
   re-classifying the result (e.g. CHAIN-KIND on the substituted body
   against the name it cares about); that recursive re-check is what
   confirms the accumulator-position argument is actually rooted at the
   accumulator in question, and what makes multi-level helper chains
   compose without extra machinery. Shared by CHAIN-KIND and REWRITE-CHAIN
   so classification and rewriting stay in lock-step (the same discipline
   the rest of this file uses for direct chain ops)."
  (when (fol.compiler.ast:call-node-p node)
    (let ((op (operator-symbol node)))
      (when op
        (let ((entry (gethash op *tr-inlinable-fns*)))
          (when entry
            (destructuring-bind (params body acc-pos acc-ref-count) entry
              (let ((args (fol.compiler.ast:call-node-args node)))
                (when (and (= (length params) (length args))
                           (loop for a in args
                                 for i from 0
                                 always (or (and (= i acc-pos) (= acc-ref-count 1))
                                            (fol.compiler.ast:symbol-ref-node-p a)
                                            (fol.compiler.ast:literal-node-p a))))
                  (%note-inlined-helper op)
                  (%tr-inline-subst body (mapcar #'cons params args)))))))))))

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
         ;; (helper <chain> ...): a call to a registered inlinable helper --
         ;; substitute its body in and recurse (closes the "DVI gap").
         (t (let ((inlined (%tr-inline-attempt node)))
              (if inlined
                  (chain-kind inlined name)
                  (values nil nil)))))))
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

(defun maybe-register-inlinable-helper (name clauses)
  "If NAME is a single-clause function whose body qualifies exactly one
   parameter as a loop-accumulator-style user (REDUCE-ACC-QUALIFIED-P: its
   tail-position use is a real update chain, and every other use is a
   sanctioned read) -- the same bar a reduce lambda's own accumulator must
   clear -- register it in *TR-INLINABLE-FNS* so CHAIN-KIND/REWRITE-CHAIN
   can inline it at call sites (see the module comment above CHAIN-KIND).
   This deliberately allows the parameter to be referenced more than once
   (e.g. \\(assoc cart price (inc (get cart price 0))\\), the read-heavy
   shape edit-tagged transients exist for) -- %TR-INLINE-ATTEMPT is what
   keeps substitution sound when that happens, by requiring the call site's
   actual argument to be cheap to duplicate whenever the parameter is used
   more than once. Ambiguous helpers -- more than one parameter
   independently qualifying -- are conservatively not registered.
   Always clears any stale entry for NAME first: a helper recompiled into a
   non-qualifying shape must not leave its old (now-wrong) registration
   behind for later top-level forms to inline against. (Already-compiled
   *callers* of the old shape are separately protected by the world-guard,
   via *INLINED-HELPERS*; this only concerns code compiled after the
   redefinition.)"
  (remhash name *tr-inlinable-fns*)
  (when (and name (= 1 (length clauses)))
    (let* ((clause (first clauses))
           (params (%param-names (car clause)))
           (body (%tr-strip-docstring (cdr clause))))
      (when (and params (every #'symbolp params) (= 1 (length body)))
        (let ((expr (first body))
              (candidates '()))
          (loop for p in params
                for i from 0
                do (when (reduce-acc-qualified-p p body)
                     (push i candidates)))
          (when (= 1 (length candidates))
            (let ((acc-pos (first candidates)))
              (setf (gethash name *tr-inlinable-fns*)
                    (list params expr acc-pos
                          (%tr-symbol-ref-count expr (nth acc-pos params)))))))))))

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

(defun %fold-let-chain (bindings alias)
  "Validate that BINDINGS (a bind-node's (var . init) pairs, in order) forms
   an unbroken chain rooted at ALIAS: each binding's init must be a chain
   (CHAIN-KIND) rooted at the running alias -- ALIAS itself for the first
   binding, then each binding's own var in turn -- referencing that alias
   exactly once (so folding it in cannot duplicate a possibly-effectful
   expression, the same invariant %TR-INLINE-ATTEMPT enforces for helper
   inlining). A binding that is unrelated to the running alias, or touches
   it without extending the chain (e.g. a helper call that only READS it --
   DVI's actual shape, see the paper's Discussion), breaks the chain rather
   than being skipped: skipping it could drop an effectful binding's
   evaluation entirely once the BIND is eliminated by the caller.
   Returns (values final-alias folded-expr) on success, where FOLDED-EXPR
   is BINDINGS folded into one expression rooted at the original ALIAS by
   repeated substitution (%TR-INLINE-SUBST); (values nil nil) if any
   binding breaks the chain. Shared by CLASSIFY-LOOP-PARAM's TRY-LET-CHAIN
   and REWRITE-LOOP-BODY's TRY-LET-CHAIN-RW so classification and rewriting
   stay in lock-step."
  (let ((cur alias) (steps '()))
    (dolist (b bindings)
      (let ((var (car b)) (raw-init (cdr b)))
        (if (and (chain-kind raw-init cur)
                 (= 1 (%tr-symbol-ref-count raw-init cur)))
            (progn (push (cons var raw-init) steps) (setf cur var))
            (return-from %fold-let-chain (values nil nil)))))
    (let* ((ordered (reverse steps))
           (expanded (cdr (first ordered)))
           (prev-var (car (first ordered))))
      (dolist (s (rest ordered))
        (setf expanded (%tr-inline-subst (cdr s) (list (cons prev-var expanded))))
        (setf prev-var (car s)))
      (values cur expanded))))

(defun %safe-read-of-p (raw-init cur)
  "True when RAW-INIT is a call that references CUR exactly once, as a
   direct (bare) argument at a position CALL-ARG-READ-P proves is only
   read, never retained -- a Tier-1 primitive or keyword accessor, or a
   Tier-2-inferred user function (e.g. DVI's CART-TOTAL, whose CART
   parameter only flows through keyword-accessor reads and REDUCE, never
   retained). Used by %VALIDATE-READ-TOLERANT-CHAIN to recognize a BIND
   binding that reads the running alias without extending it."
  (and (fol.compiler.ast:call-node-p raw-init)
       (= 1 (%tr-symbol-ref-count raw-init cur))
       (loop for arg in (fol.compiler.ast:call-node-args raw-init)
             for i from 0
             thereis (and (fol.compiler.ast:symbol-ref-node-p arg)
                          (eq (fol.compiler.ast:symbol-ref-node-name arg) cur)
                          (call-arg-read-p raw-init i)))))

(defun %validate-read-tolerant-chain (bindings alias)
  "A more permissive sibling of %FOLD-LET-CHAIN: validates a BIND whose
   bindings mix chain-extending steps with plain reads of the running
   alias, or values wholly unrelated to it -- DVI's own shape, where
   CART-TOTAL reads the running alias (through a Tier-2-summarized helper)
   rather than extending it, and the next chain-extending step two
   bindings later still uses the SAME alias as its base, not the read's
   result. Where %FOLD-LET-CHAIN requires every binding to extend the
   chain (rejecting DVI's shape outright), this instead classifies each
   binding as:
     - chain-extending: identical criterion to %FOLD-LET-CHAIN (CHAIN-KIND
       rooted at the running alias, referenced exactly once) -- the alias
       advances to this binding's own var, exactly as before.
     - a safe read (%SAFE-READ-OF-P) or wholly unrelated to the running
       alias (does not reference it at all) -- always safe, and the alias
       does NOT advance.
   A binding that touches the running alias any other way -- a bare
   reference, a retaining call argument, or an unsummarized call -- still
   breaks the whole match rather than being silently skipped, for the same
   reason %FOLD-LET-CHAIN's stricter version gives: once the caller treats
   the BIND as a single classified unit, silently dropping a binding could
   drop or reorder an effectful evaluation.
   Unlike %FOLD-LET-CHAIN, this does NOT fold BINDINGS into one flattened
   expression: a read's result (e.g. DVI's T1) has no meaningful position
   in a chain expression, since it isn't itself an updated accumulator --
   it must remain its own BIND binding in the rewritten code. Returns
   (values final-alias extend-p-list) on success, where EXTEND-P-LIST has
   one boolean per binding (T for chain-extending, NIL for read/unrelated,
   in BINDINGS' order) telling REWRITE-LOOP-BODY's TRY-LET-CHAIN-RW which
   bindings need rewriting to their bang-op/dispatch-through form and
   which are emitted completely unchanged; (values nil nil) on failure."
  (let ((cur alias) (extend-flags '()))
    (dolist (b bindings)
      (let ((raw-init (cdr b)))
        (cond
          ((and (chain-kind raw-init cur)
                (= 1 (%tr-symbol-ref-count raw-init cur)))
           (push t extend-flags)
           (setf cur (car b)))
          ((or (zerop (%tr-symbol-ref-count raw-init cur))
               (%safe-read-of-p raw-init cur))
           (push nil extend-flags))
          (t (return-from %validate-read-tolerant-chain (values nil nil))))))
    (values cur (nreverse extend-flags))))

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
         (try-let-chain (node)
           ;; (bind [c1 (f acc x) c2 (g c1 y) ...] (recur ... c2 ...)) hides
           ;; a chain-of-chains behind named temporaries: NAME appears only
           ;; inside c1's binding (a non-tail call argument, ordinarily
           ;; :escape-call), each subsequent binding extends the PREVIOUS
           ;; temporary rather than NAME directly, and the final temporary
           ;; in the recur is a symbol the walk never ties back to NAME.
           ;; Walks the bindings in order, requiring EVERY one to be a
           ;; chain rooted at the running alias (initially NAME, then each
           ;; binding's own var in turn) with that alias referenced exactly
           ;; once (no duplication when substituted) -- a binding that is
           ;; unrelated to the alias, or touches it without extending the
           ;; chain (e.g. a helper call that only READS it, DVI's actual
           ;; shape, see §discussion), fails the whole match rather than
           ;; being silently skipped: skipping could drop an effectful
           ;; binding's evaluation entirely once the BIND is eliminated.
           ;; When every binding qualifies and the final alias is the sole
           ;; (single-referenced) content of one recur argument, folds the
           ;; chain into one expression rooted at NAME and classifies the
           ;; resulting recur -- exactly as safe as if that expression had
           ;; been written at the call site directly, since nothing in the
           ;; BIND is reordered, only relocated as a unit.
           ;; Returns the synthesized recur node, or NIL if the shape
           ;; doesn't match, in which case the caller falls back to
           ;; ordinary let handling. Mirrored by REWRITE-LOOP-BODY's
           ;; TRY-LET-CHAIN-RW so classification and rewriting stay in
           ;; lock-step (the same discipline %TR-INLINE-ATTEMPT documents
           ;; for helper inlining).
           (let ((bindings (fol.compiler.ast:bind-node-bindings node))
                 (body (fol.compiler.ast:bind-node-body node)))
             (when (and bindings
                        (= 1 (length body))
                        (fol.compiler.ast:recur-node-p (first body))
                        (every (lambda (b) (symbolp (car b))) bindings)
                        (notany (lambda (b) (eq (car b) name)) bindings))
               (multiple-value-bind (alias expanded) (%fold-let-chain bindings name)
                 (when alias
                   (let* ((rnode (first body))
                          (args (fol.compiler.ast:recur-node-args rnode))
                          (p (position-if
                              (lambda (a)
                                (and (fol.compiler.ast:symbol-ref-node-p a)
                                     (eq (fol.compiler.ast:symbol-ref-node-name a) alias)))
                              args)))
                     (when (and p (= 1 (%tr-symbol-ref-count rnode alias)))
                       (fol.compiler.ast:make-recur-node
                        :args (loop for a in args
                                    for i from 0
                                    collect (if (= i p) expanded a))
                        :form (fol.compiler.ast:ast-node-form rnode)))))))))
         (try-read-tolerant-chain (node infn recurp complexp)
           ;; Sibling of TRY-LET-CHAIN for %VALIDATE-READ-TOLERANT-CHAIN's
           ;; more permissive shape: chain-extending steps interleaved with
           ;; plain reads of the running alias (DVI's own shape, where
           ;; CART-TOTAL reads the alias rather than extending it). Unlike
           ;; TRY-LET-CHAIN, this does NOT fold BINDINGS into a synthesized
           ;; recur to re-walk -- a read's result has no place in a folded
           ;; expression, since it isn't itself an updated accumulator, and
           ;; must remain its own BIND binding. Consequently it can't reuse
           ;; the normal recur-node walk to pick up stray uses of NAME the
           ;; way TRY-LET-CHAIN's re-walk of its synthesized node does, so
           ;; it establishes that safety differently: requiring NAME to
           ;; appear EXACTLY ONCE across every binding's init (the one
           ;; chain-root reference the validator itself checks) rules out
           ;; NAME leaking into a chain-extending step's non-spine argument
           ;; or any other binding, and the recur's own non-accumulator
           ;; arguments are still walked explicitly below, matching what
           ;; the normal per-argument recur walk (WALK's RECUR-NODE-P case)
           ;; would do for them.
           ;; Records :RECUR-UPDATE directly (mirroring what the normal
           ;; recur-handling path would record for a plain, non-BIND
           ;; qualifying chain) and returns T on success, in which case the
           ;; caller must not fall through to ordinary BIND handling for
           ;; this node; NIL on failure, in which case it must.
           (let ((bindings (fol.compiler.ast:bind-node-bindings node))
                 (body (fol.compiler.ast:bind-node-body node)))
             (when (and bindings
                        (= 1 (length body))
                        (fol.compiler.ast:recur-node-p (first body))
                        (every (lambda (b) (symbolp (car b))) bindings)
                        (notany (lambda (b) (eq (car b) name)) bindings)
                        (= 1 (loop for b in bindings
                                   sum (%tr-symbol-ref-count (cdr b) name))))
               (multiple-value-bind (alias extend-flags)
                   (%validate-read-tolerant-chain bindings name)
                 (declare (ignore extend-flags))
                 (when alias
                   (let* ((rnode (first body))
                          (args (fol.compiler.ast:recur-node-args rnode))
                          (p (position-if
                              (lambda (a)
                                (and (fol.compiler.ast:symbol-ref-node-p a)
                                     (eq (fol.compiler.ast:symbol-ref-node-name a) alias)))
                              args)))
                     (when (and p (= 1 (%tr-symbol-ref-count rnode alias)))
                       (record :recur-update)
                       (loop for a in args
                             for i from 0
                             unless (= i p)
                             do (walk a nil infn recurp complexp))
                       t)))))))
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
              (let ((synth (try-let-chain node)))
                (cond
                  (synth (walk synth tailp infn recurp complexp))
                  ((try-read-tolerant-chain node infn recurp complexp) nil)
                  (t (let ((shadowed nil))
                       (dolist (b (fol.compiler.ast:bind-node-bindings node))
                         (walk (cdr b) nil infn recurp complexp)
                         (when (shadows-p (car b)) (setf shadowed t)))
                       (if shadowed
                           (record :shadowed-bind)
                           (walk-last-tail (fol.compiler.ast:bind-node-body node)
                                           tailp infn recurp complexp)))))))
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

(defvar *dict-scalar-replacement* nil
  "When non-nil, an intra-bind chain whose accumulator is a literal empty
   dict {} (rather than a defclass record) is also scalar-replaced: its
   fixed key set is discovered from usage -- every touch across the chain
   must be a literal-keyword GET/ASSOC, never a dynamic key -- instead of
   coming from a pre-registered *GLOBAL-TYPE-INFO* schema. Independent of
   *SCALAR-REPLACEMENT* (which this flag does not require) so the two
   mechanisms can be benchmarked/ablated separately. v1 scope: intra-bind
   chains only (not loop accumulators), and only the flat ASSOC-chain
   reconstruction shape (no if/cond/case branching, no helper inlining,
   no dissoc/update/merge) -- see %SR-INTRA-BIND-CHAIN in compiler.lisp.")

(defvar *reduce-literal-unroll* nil
  "When non-nil, a (reduce (fn [acc x] body) init coll) call where COLL is a
   literal vector/set -- written inline, or referenced by a top-level DEF
   whose own initializer is one -- is unrolled at compile time into a
   straight-line BIND chain over COLL's known elements, before scalar
   replacement or any other pass sees the code. Reduce's own iteration is
   otherwise opaque (hidden inside COLLECTION-REDUCE's generic dispatch),
   so this is the only way ASR's loop/intra-bind machinery ever gets a
   chance to see and unbox the accumulator. Independent of
   *SCALAR-REPLACEMENT*: the unrolled chain is ordinary code regardless,
   ASR just happens to be the pass that benefits most. v1 scope: the step
   function must be a literal single-clause two-param FN (mirrors
   %LINEAR-REDUCE-LAMBDA's shape), found in tail position of a top-level
   defn/defn-private/definline body through single-form bind/do peeling
   only (no if/cond/case branch recognition) -- see
   REDUCE-LITERAL-DESUGAR-TOPLEVEL in compiler.lisp.")

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

(defun %init-call-summary (node)
  "The escape-summary for a call-node's operator, or NIL. Shared by
   TRANSIENT-ELIGIBLE-INIT-P and INIT-SUPPORTS-P so both consult the same
   Tier-1-or-Tier-2 lookup for a constructor-call init."
  (and (fol.compiler.ast:call-node-p node)
       (let ((op (operator-symbol node)))
         (and op (fol.compiler.summaries:lookup-summary op)))))

(defun %quoted-symbol-value (node)
  "The symbol NODE evaluates to, when NODE is a quote-node wrapping a bare
   symbol ('x) or a literal-node whose value is a symbol/keyword. NIL
   otherwise."
  (cond
    ((and (fol.compiler.ast:quote-node-p node)
          (symbolp (fol.compiler.ast:quote-node-value node)))
     (fol.compiler.ast:quote-node-value node))
    ((and (fol.compiler.ast:literal-node-p node)
          (symbolp (fol.compiler.ast:literal-node-value node)))
     (fol.compiler.ast:literal-node-value node))
    (t nil)))

(defun %persistent-object-class-p (class-sym)
  "T when CLASS-SYM names an already-defined class deriving from
   FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT>. Shared by
   %PERSISTENT-OBJECT-MAKE-CLASS and %TIER2-CONSTRUCTOR-CLASS."
  (and class-sym
       (let ((c (find-class class-sym nil)))
         (and c (find-class 'fol.compiler.persistent:<persistent-object> nil)
              (subtypep c (find-class 'fol.compiler.persistent:<persistent-object>))
              t))))

(defun %persistent-object-make-class (node)
  "When NODE is (make 'X) -- a call to FOL's MAKE generic with exactly one
   argument, a quoted class-name symbol, where X names a class deriving
   from FOL.COMPILER.PERSISTENT:<PERSISTENT-OBJECT> -- return X. NIL
   otherwise. Deliberately narrow: no support for constructors passing
   initargs (make takes &rest args), which would need their own
   freshness/aliasing analysis, and X's class must already be defined (the
   same requirement Tier-2 inference has for a constructor it summarizes)."
  (when (fol.compiler.ast:call-node-p node)
    (let ((op (operator-symbol node))
          (args (fol.compiler.ast:call-node-args node)))
      (when (and op (string= (symbol-name op) "MAKE") (= 1 (length args)))
        (let ((class-sym (%quoted-symbol-value (first args))))
          (when (%persistent-object-class-p class-sym)
            class-sym))))))

(defun %tier2-constructor-class (node)
  "When NODE is a constructor call for a <persistent-object> subclass --
   either MAKE-<TYPE> literal-call syntax or (make 'TYPE ...) -- return
   TYPE. NIL otherwise. Unlike %PERSISTENT-OBJECT-MAKE-CLASS (used at the
   accumulator's own top-level init, where the op-gate check also needs
   MAKE checked as a spine op), this is Tier-2's tail-position freshness
   recognition: it only needs to know WHICH class's MAKE must later be
   verified untrusted-checked (%FRESH-TAIL-VALUE-P records it in
   FRESH-IF-CLASSES-TRUSTED; nothing here checks method-combination
   trust itself -- see TIER1-METHODS-TRUSTED-P, always consulted live at
   the point a summary carrying this fact is actually used). Mirrors
   INFER-TYPE-FROM-CONSTRUCTOR's two-shape recognition (compiler.lisp) but
   returns NIL rather than a bare type symbol for a class that isn't (yet)
   a defined <persistent-object> subtype, since an unrecognized/undefined
   class can't be given a freshness verdict at all here."
  (when (fol.compiler.ast:call-node-p node)
    (let ((op (operator-symbol node))
          (args (fol.compiler.ast:call-node-args node)))
      (when op
        (let* ((name-str (symbol-name op))
               (class-sym
                 (cond
                   ((and (>= (length name-str) 5)
                         (string-equal (subseq name-str 0 5) "MAKE-"))
                    (intern (subseq name-str 5) (symbol-package op)))
                   ((and (string-equal name-str "MAKE") (= 1 (length args)))
                    (%quoted-symbol-value (first args)))
                   (t nil))))
          (when (%persistent-object-class-p class-sym)
            class-sym))))))

(defun transient-eligible-init-p (node)
  "True when the loop init is guaranteed to produce a fresh, uniquely-owned
   root that (transient init) can safely wrap: a collection literal
   ([..], {..}, #{..}), a call to a function whose summary (Tier-1 or
   Tier-2) proves RETURNS-FRESH-P -- the same freshness guarantee licensing
   literals, generalized to summarized constructors per the Qualification
   Rule's \"a constructor call summarized as returning an unaliased root\"
   clause (§sec:formal), which the code previously left unimplemented: a
   loop initialized from a user-defined 0-ary constructor call was never
   eligible before, no matter how clean its update chain was -- or (make
   'X) for a <persistent-object> subclass X, since MAKE-INSTANCE always
   allocates a genuinely new instance (barring a hazard INIT-SUPPORTS-P's
   Trusted check below catches). Freshness alone doesn't establish which
   representation the result is (needed for the op-gate check);
   INIT-SUPPORTS-P below handles that separately via RETURNS-KIND (or
   %PERSISTENT-OBJECT-MAKE-CLASS for the persistent-object case),
   declining conversion when the kind is unknown.

   A summary whose RETURNS-FRESH-P is NIL may still qualify via
   FRESH-IF-CLASSES-TRUSTED: freshness that transitively depends on a
   constructor call inside a Tier-2-summarized helper (e.g. a 0-ary
   function whose tail position calls MAKE-<T> for some T) is never
   cached as a bare boolean -- TIER1-METHODS-TRUSTED-P is re-run live,
   here, against each listed class's CURRENT method table every time this
   function is consulted, since *INFERRED-SUMMARIES* has no transitive
   invalidation (a helper's cached summary is not re-checked when MAKE is
   later hijacked for a class it depends on -- see FRESH-IF-CLASSES-
   TRUSTED's docstring, summaries.lisp)."
  (or (fol.compiler.ast:vector-node-p node)
      (fol.compiler.ast:dict-node-p node)
      (fol.compiler.ast:set-node-p node)
      (and (%persistent-object-make-class node) t)
      (let ((summary (%init-call-summary node)))
        (and summary
             (or (fol.compiler.summaries:escape-summary-returns-fresh-p summary)
                 (let ((classes (fol.compiler.summaries:escape-summary-fresh-if-classes-trusted summary)))
                   (and classes
                        (every (lambda (cls)
                                 (tier1-methods-trusted-p (cons :persistent-object cls) '("MAKE")))
                               classes))))))))

;;; ============================================================================
;;; Method-combination trust check (Tier-1 soundness gap closed here)
;;; ============================================================================
;;; A1 (§sec:formal) trusts Tier-1 summaries to bound a name's effect "even
;;; if the library functions the table describes are redefined at runtime" --
;;; but that is a claim about REDEFINITION, protected by NOTE-REDEFINITION
;;; (world.lisp), which fires for every DEFMETHOD regardless of qualifier and
;;; so correctly invalidates a region if a :before/:after/:around method on
;;; an assumed name is added AFTER the region registers its dependency.
;;;
;;; What that leaves unprotected: a :before/:after/:around method on e.g.
;;; ASSOC, specialized on the accumulator's OWN representation class, that
;;; already existed BEFORE any region ever assumed ASSOC's meaning. There is
;;; no redefinition event for a not-yet-registered dependent to be notified
;;; of -- the region simply registers as valid from the start, unaware that
;;; calling ASSOC on this class already does more than the root-rebuild
;;; Tier-1's summary describes. ASSOC! (the bang counterpart) has no
;;; connection whatsoever to ASSOC's method combination, so any such
;;; extra behavior is silently dropped by the fast path -- a real
;;; correctness gap, confirmed by reproduction: attaching a logging
;;; :around method to ASSOC for <dict> BEFORE compiling a loop that
;;; converts it, the converted loop calls ASSOC! 0 times through the
;;; logger where the persistent path would have called ASSOC (and hence
;;; the logger) N times.
;;;
;;; The fix: before accepting a conversion, ask the LIVE generic function
;;; (via MOP) whether it already has any non-primary-qualified method
;;; applicable to the accumulator's concrete representation class. This is
;;; a compile-time check on ambient state, unlike every other check in this
;;; file which is purely syntactic -- necessarily so, since the hazard is
;;; ambient state (what methods already exist) that no AST walk can see.

(defparameter +repr-classes+
  '((:dict . fol.compiler.collections:<dict>)
    (:vector . fol.compiler.collections:<vector>)
    (:set . fol.compiler.collections:<set>))
  "Fixed representation kind -> the concrete FOL class its instances have.
   Persistent-object accumulators don't have a single fixed class -- every
   user DEFCLASS is its own representation -- so their kind is instead the
   cons (:PERSISTENT-OBJECT . class-name-symbol), handled directly by
   %REPR-CLASS below rather than added here.")

(defun %repr-class (kind)
  (if (and (consp kind) (eq (car kind) :persistent-object))
      (find-class (cdr kind) nil)
      (let ((sym (cdr (assoc kind +repr-classes+))))
        (and sym (find-class sym nil)))))

(defun %tier1-generic-function (op-name)
  "The CLOS generic function bound to Tier-1 operator OP-NAME (a string) in
   whichever FOL implementation package defines it, or NIL if not found or
   not a generic function. Mirrors LOOKUP-SUMMARY's own package search
   (summaries.lisp's *FOL-FUNCTION-PACKAGES*, exported under its
   *SUMMARY-LOCKED-PACKAGES* alias since the former isn't itself external),
   so this asks about the exact function the compiler itself would call."
  (dolist (pkg-name fol.compiler.summaries:*summary-locked-packages*)
    (let* ((pkg (find-package pkg-name))
           (sym (and pkg (find-symbol op-name pkg))))
      (when (and sym (fboundp sym))
        (let ((fn (fdefinition sym)))
          (when (typep fn 'standard-generic-function)
            (return-from %tier1-generic-function fn))))))
  nil)

(defun %class-applicable-p (specializer class &optional kind)
  "True when a method specialized on SPECIALIZER would fire for an instance
   of CLASS: SPECIALIZER is CLASS itself or one of its superclasses.
   Non-class specializers (EQL-specializers) are conservatively skipped --
   they only ever match one specific object's identity, not a whole
   representation, so they cannot silently intercept every accumulator of
   this kind the way a class-specialized method can; a known, narrow gap,
   noted rather than handled -- EXCEPT for KIND a (:persistent-object
   . class-name) cons (optional; only meaningful for MAKE): MAKE's own
   dispatch convention specializes its class-selecting parameter with
   (EQL '<name>), not a class specializer, and class-name symbols are how
   EVERY method on MAKE -- the class's own legitimate constructor method
   as much as a hostile customization -- selects a representation, so the
   general 'matches one object's identity' argument for skipping
   EQL-specializers doesn't hold here. Recognized as this one specific,
   well-defined shape rather than attempting to handle EQL-specializers in
   general. CLASS-PRECEDENCE-LIST is only valid on a finalized class;
   dict/vector/set are always finalized by the time this runs
   (long-instantiated builtins), but a user's <persistent-object> subclass
   may not be -- CLOS finalizes lazily, and this check can run at compile
   time, before the loop that would (make 'X) ever executes. Force it
   explicitly rather than have this signal an UNBOUND-SLOT error the first
   time a brand-new class is used."
  (when (typep class 'class) (closer-mop:ensure-finalized class))
  (or (and (typep specializer 'class)
           (member specializer (sb-mop:class-precedence-list class))
           t)
      (and (consp kind) (eq (car kind) :persistent-object)
           (typep specializer 'sb-mop:eql-specializer)
           (eql (sb-mop:eql-specializer-object specializer) (cdr kind))
           t)))

(defun tier1-op-customized-p (op-name kind)
  "True when the generic function named OP-NAME has a method, applicable to
   representation KIND's class, whose qualifiers are non-empty
   (:before/:after/:around/any user combination qualifier) -- i.e. Tier-1's
   summary for OP-NAME does not fully describe what calling it on this
   representation does."
  (let ((gf (%tier1-generic-function op-name))
        (class (%repr-class kind)))
    (and gf class
         (some (lambda (m)
                 (and (method-qualifiers m)
                      (let ((specs (sb-mop:method-specializers m)))
                        (and specs (%class-applicable-p (first specs) class kind)))))
               (sb-mop:generic-function-methods gf)))))

(defun tier1-methods-trusted-p (kind used-ops)
  "True when none of USED-OPS (Tier-1 operator name strings actually relied
   on by this conversion -- spine ops plus reads) has a method-combination
   surprise (TIER1-OP-CUSTOMIZED-P) on representation KIND. KIND NIL
   (unrecognized representation) is conservatively untrusted."
  (and kind (notany (lambda (op) (tier1-op-customized-p op kind)) used-ops)))

(defun %used-ops (chain-ops reads-p)
  "CHAIN-OPS plus, when READS-P, the full transient-read whitelist -- the
   set of Tier-1 operator names this conversion could actually invoke on
   the accumulator's representation, conservative in the read case since
   INIT-SUPPORTS-P's callers only pass a boolean (some read occurred), not
   which whitelisted op it was."
  (if reads-p (union chain-ops +transient-readable-ops+ :test #'string=) chain-ops))

(defun %reads-forbidden-p ()
  "True when the active transient representation for dicts/vectors cannot
   serve mid-session reads -- normally only true for sets, but also true
   for dicts/vectors under the RQ5 wrapper-transient ablation
   (fol.compiler.collections:*wrapper-transients*), which simulates a
   Clojure-style wrapper representation on the same classifier/rewriter."
  (and (find-symbol "*WRAPPER-TRANSIENTS*" :fol.compiler.collections)
       (symbol-value (find-symbol "*WRAPPER-TRANSIENTS*" :fol.compiler.collections))))

(defun init-supports-p (init-node chain-ops reads-p)
  "True when the transient representation behind INIT-NODE's collection type
   supports every spine op in CHAIN-OPS, and reads when READS-P.
   Dicts/vectors/sets are all edit-tagged (reads supported for all three;
   sets are HAMT-backed exactly like dicts) -- unless the RQ5 ablation
   forces the legacy wrapper representation (writes only), via
   %READS-FORBIDDEN-P. A constructor-call init (see
   TRANSIENT-ELIGIBLE-INIT-P) is supported only when its summary's
   RETURNS-KIND is known -- freshness alone doesn't say which op-gate
   applies, so an unrecognized-kind constructor is conservatively declined
   rather than guessed at. Also requires TIER1-METHODS-TRUSTED-P: Tier-1's
   summary must actually describe what the assumed ops do for this
   representation (see the method-combination trust check above).

   Second return value: T when conversion is supported only in
   'dispatch-through' mode -- currently only reachable for a
   <persistent-object> accumulator whose ASSOC (and no other used op) has a
   method-combination customization. Conversion is still allowed, but
   MAYBE-TRANSIENT-LOOP must route this accumulator's spine-op calls
   through the real ASSOC generic rather than the ASSOC! bypass, so the
   customization keeps firing (see *DISPATCH-THROUGH-NAMES* below).
   NIL (every other case, including the ordinary fully-trusted path) means
   the fast bypass is safe, exactly as before this exception existed.

   Third return value: (KIND . USED-OPS) when supported, NIL otherwise --
   the facts %KIND-TRUSTED-P needs to re-derive this same trust verdict
   live at load time (see its docstring for why the compile-time check
   alone isn't sound)."
  (let ((used-ops (%used-ops chain-ops reads-p)))
    (cond
      ((fol.compiler.ast:dict-node-p init-node)
       (and (not (and reads-p (%reads-forbidden-p)))
            (subsetp chain-ops '("ASSOC" "DISSOC") :test #'string=)
            (tier1-methods-trusted-p :dict used-ops)
            (values t nil (cons :dict used-ops))))
      ((fol.compiler.ast:vector-node-p init-node)
       (and (not (and reads-p (%reads-forbidden-p)))
            (subsetp chain-ops '("CONJ") :test #'string=)
            (tier1-methods-trusted-p :vector used-ops)
            (values t nil (cons :vector used-ops))))
      ((fol.compiler.ast:set-node-p init-node)
       (and (not (and reads-p (%reads-forbidden-p)))
            (subsetp chain-ops '("CONJ" "DISJ") :test #'string=)
            (tier1-methods-trusted-p :set used-ops)
            (values t nil (cons :set used-ops))))
      ;; (make 'X), X a <persistent-object> subclass -- see
      ;; %PERSISTENT-OBJECT-INIT-SUPPORTS-P below for the full rationale.
      ((%persistent-object-make-class init-node)
       (%persistent-object-init-supports-p
        (%persistent-object-make-class init-node) chain-ops used-ops))
      (t (let* ((summary (%init-call-summary init-node))
                (kind (and summary (fol.compiler.summaries:escape-summary-returns-kind summary)))
                (fresh-classes (and summary (fol.compiler.summaries:escape-summary-fresh-if-classes-trusted summary))))
           (cond
             ((eq kind :dict)
              (and (not (and reads-p (%reads-forbidden-p)))
                   (subsetp chain-ops '("ASSOC" "DISSOC") :test #'string=)
                   (tier1-methods-trusted-p :dict used-ops)
                   (values t nil (cons :dict used-ops))))
             ((eq kind :vector)
              (and (not (and reads-p (%reads-forbidden-p)))
                   (subsetp chain-ops '("CONJ") :test #'string=)
                   (tier1-methods-trusted-p :vector used-ops)
                   (values t nil (cons :vector used-ops))))
             ((eq kind :set)
              (and (not (and reads-p (%reads-forbidden-p)))
                   (subsetp chain-ops '("CONJ" "DISJ") :test #'string=)
                   (tier1-methods-trusted-p :set used-ops)
                   (values t nil (cons :set used-ops))))
             ;; A Tier-2-summarized 0-ary helper whose tail position calls
             ;; MAKE-<T>/(make 'T): %INFER-RETURNS-KIND only recognizes a
             ;; direct DICT/VECTOR/SET tail call, so KIND is NIL here even
             ;; though TRANSIENT-ELIGIBLE-INIT-P already live-verified this
             ;; class's MAKE is untrusted-checked. Declines if more than one
             ;; distinct class is possible (e.g. an IF choosing between two
             ;; different persistent-object constructors) -- op gates are
             ;; per-representation, so there is no single consistent gate
             ;; to check in that case.
             ((and (null kind) fresh-classes (= 1 (length fresh-classes)))
              (%persistent-object-init-supports-p (first fresh-classes) chain-ops used-ops))
             (t nil)))))))

(defun %persistent-object-init-supports-p (class-name chain-ops used-ops)
  "Shared by INIT-SUPPORTS-P's two persistent-object paths: a direct
   (make 'X) init, and a Tier-2-summarized helper whose tail position
   builds one. ASSOC is the only spine op (no DISSOC/CONJ/DISJ analogue for
   CLOS slots); reads are supported (GET on a persistent-object reads via
   plain SLOT-VALUE, which already sees in-place mutation once
   %TRANSIENT-OWNER is set -- no dirty-node traversal needed the way HAMT
   reads require). Freshness (TRANSIENT-ELIGIBLE-INIT-P) is purely
   structural/live-checked, so MAKE itself must be checked here for a
   method-combination hazard, same as any spine/read op -- otherwise a
   customized MAKE could silently hand back something other than a fresh
   instance. Only FOL's own MAKE generic is checked; a raw
   CL:INITIALIZE-INSTANCE/CL:ALLOCATE-INSTANCE :around method bypassing it
   is a known, unhandled gap, the same kind already noted for
   EQL-specializers elsewhere.

   ASSOC gets a narrower exception than MAKE/reads (Approach A): a
   method-combination customization on ASSOC alone doesn't have to refuse
   conversion outright. ASSOC's own PRIMARY method for <persistent-object>
   (collection-functions.lisp) already calls UPDATE-SLOT, whose in-place
   fast path (persistence.lisp) already branches on %TRANSIENT-OWNER
   regardless of caller -- it's the general update primitive, not
   something built only for the transient bypass. So routing the rewritten
   call through the REAL ASSOC generic instead of the ASSOC! bypass costs
   only CLOS dispatch (measured ~10ns/call over the bypass), not the
   in-place mutation itself: the customization's :before/:after/:around
   methods fire via ordinary method combination, and CALL-NEXT-METHOD
   still reaches the same ownership-aware primary.

   Second return value: T when conversion is supported only in
   'dispatch-through' mode -- see INIT-SUPPORTS-P's docstring.

   Third return value: (KIND . ALL-USED-OPS), the exact facts %KIND-
   TRUSTED-P needs to re-derive this same trust verdict later, live, at
   load time -- see that function's docstring for why a one-time
   compile-time check alone isn't enough."
  (let* ((kind (cons :persistent-object class-name))
         (all-used-ops (union used-ops '("MAKE") :test #'string=))
         (non-assoc-used-ops (remove "ASSOC" all-used-ops :test #'string=)))
    (and (subsetp chain-ops '("ASSOC") :test #'string=)
         (notany (lambda (op) (tier1-op-customized-p op kind)) non-assoc-used-ops)
         (values t (and (member "ASSOC" all-used-ops :test #'string=)
                        (tier1-op-customized-p "ASSOC" kind)
                        t)
                 (cons kind all-used-ops)))))

(defun %kind-trusted-p (kind used-ops)
  "Re-derive, from KIND and USED-OPS alone, exactly the method-combination
   trust verdict INIT-SUPPORTS-P/%PERSISTENT-OBJECT-INIT-SUPPORTS-P
   computed at compile time for this representation -- called again, live,
   at load time (see REGISTER-REGION's call sites in compiler.lisp).

   Why re-check at all: TRUSTED is checked via MOP introspection at
   conversion time (compile time), but the world-guard's actual protection
   (REGISTER-REGION) only starts at load time, a separate, later phase --
   confirmed by every call site being wrapped in CL:LOAD-TIME-VALUE. A
   :before/:after/:around method hijacking the representation, introduced
   after the compile-time check but before load time, is invisible to
   both: the compile-time snapshot is already stale, and NOTE-REDEFINITION
   has nothing registered yet to invalidate (no redefinition event fires
   for a method that already existed). Re-running the same check here, at
   the moment protection actually begins, closes that gap.

   Mirrors the two trust checks exactly, including persistent-object's
   Approach-A ASSOC exemption (a customization on ASSOC alone doesn't
   disqualify, since MAYBE-TRANSIENT-LOOP already routes it through
   dispatch-through rather than the bypass) -- but omits the chain-ops/
   reads-forbidden-p checks those functions also make: those are static
   facts about the AST and the wrapper-transient ablation flag, fixed at
   compile time, and cannot change between compile time and load time the
   way a live method table can."
  (if (and (consp kind) (eq (car kind) :persistent-object))
      (notany (lambda (op) (tier1-op-customized-p op kind))
              (remove "ASSOC" used-ops :test #'string=))
      (tier1-methods-trusted-p kind used-ops)))

(defun %init-call-name (init-node)
  "Operator name (string) of a constructor-call INIT-NODE, or NIL. Used to
   add the constructor to a converted region's world-guard dependencies:
   redefining it must invalidate the region exactly as redefining ASSOC or
   an inlined helper already does (see *INLINED-HELPERS*), since the
   conversion is only sound for as long as the constructor keeps returning
   a fresh root of the same kind."
  (and (fol.compiler.ast:call-node-p init-node)
       (let ((op (operator-symbol init-node)))
         (and op (symbol-name op)))))

(defun %init-fresh-dependency-names (init-node)
  "Extra assumed names a converted region's world-guard must depend on
   beyond %INIT-CALL-NAME's own operator name. When INIT-NODE's freshness
   was established unconditionally, or via a MAKE/MAKE-<T> call directly
   at INIT-NODE's own position, %INIT-CALL-NAME already covers it (that
   name IS \"MAKE\"/\"MAKE-<T>\"). But when freshness instead came from a
   Tier-2 helper's FRESH-IF-CLASSES-TRUSTED -- a constructor call buried
   inside the HELPER's own tail position, invisible to %INIT-CALL-NAME,
   which only inspects INIT-NODE itself -- the region has no dependency on
   \"MAKE\" at all today. Without this, a loop already compiled and
   running would not be invalidated by a LATER MAKE hijack for the class
   the helper's freshness claim depended on: TRANSIENT-ELIGIBLE-INIT-P's
   live TIER1-METHODS-TRUSTED-P check only protects the COMPILE-TIME
   decision for a region not yet emitted, not one already running."
  (let ((summary (%init-call-summary init-node)))
    (when (and summary
               (not (fol.compiler.summaries:escape-summary-returns-fresh-p summary))
               (fol.compiler.summaries:escape-summary-fresh-if-classes-trusted summary))
      (list "MAKE"))))

(defun %reads-present-p (uses)
  "Reads seen either directly in USES or collected from nested linear
   reduce lambdas via *READ-OPS*."
  (or (member :read-ok uses)
      (and (not (eq *read-ops* :unbound)) (consp *read-ops*))))

(defvar *dispatch-through-names* '()
  "Qualified accumulator names (a subset of MAYBE-TRANSIENT-LOOP's QNAMES)
   whose spine-op calls must be rewritten to the REAL Tier-1 generic
   function (e.g. ASSOC) rather than the transient bypass (e.g. ASSOC!).
   Populated when INIT-SUPPORTS-P's second return value is T for a given
   accumulator: a <persistent-object> class whose ASSOC has a legitimate
   method-combination customization (Approach A, see INIT-SUPPORTS-P's
   docstring). The rewritten call still lands on a transient (owned)
   object, so ASSOC's own primary method's existing ownership-aware fast
   path (persistence.lisp's UPDATE-SLOT) still does the in-place mutation
   -- real dispatch is used only so the customization keeps firing, not to
   give up in-place mutation. Bound per-loop by MAYBE-TRANSIENT-LOOP;
   empty (the ordinary case) means every accumulator in this loop uses the
   fast bypass exactly as before this exception existed.")

(defun rewrite-loop-body (body qnames pos-names &optional (mode :loop))
  "Rewrite BODY (list of nodes) converting the qualified accumulators QNAMES
   (POS-NAMES maps recur position -> qualified name or NIL) to transient ops.
   MODE :loop wraps tail exits in (persistent! ...); MODE :reduce leaves tail
   values as transients (the reduce wrapper applies persistent! once, outside).
   Names in *DISPATCH-THROUGH-NAMES* get their spine-op calls routed through
   the real generic function instead of the bypass; see that variable."
  (labels
      ((qref-p (n)
         (and (fol.compiler.ast:symbol-ref-node-p n)
              (member (fol.compiler.ast:symbol-ref-node-name n) qnames)))
       (bang-ref (call name)
         (if (member name *dispatch-through-names*)
             (fol.compiler.ast:call-node-operator call)
             (%ref (%collections-symbol
                    (fol.compiler.summaries:transient-op-for (operator-symbol call))))))
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
           ;; (helper <chain> ...): a call to a registered inlinable helper --
           ;; substitute its body in and recurse, mirroring CHAIN-KIND's own
           ;; case above so classification and rewriting never diverge.
           ((and (fol.compiler.ast:call-node-p n) (%tr-inline-attempt n))
            (rewrite-chain (%tr-inline-attempt n) name))
           ((fol.compiler.ast:call-node-p n)
            (let ((args (fol.compiler.ast:call-node-args n)))
              (fol.compiler.ast:make-call-node
               :operator (bang-ref n name)
               :args (cons (rewrite-chain (first args) name)
                           (mapcar (lambda (a) (rw a nil)) (rest args)))
               :form (fol.compiler.ast:ast-node-form n))))
           ((fol.compiler.ast:thread-first-node-p n)
            (let ((forms (fol.compiler.ast:thread-first-node-forms n)))
              (fol.compiler.ast:make-thread-first-node
               :forms (cons (rewrite-chain (first forms) name)
                            (mapcar (lambda (f)
                                      (fol.compiler.ast:make-call-node
                                       :operator (bang-ref f name)
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
       (try-let-chain-rw (n)
         ;; Mirrors CLASSIFY-LOOP-PARAM's TRY-LET-CHAIN via the shared
         ;; %FOLD-LET-CHAIN, so a loop that qualifies via that path always
         ;; has a matching rewrite here; see its comment for the safety
         ;; argument. Unlike the classifier (called once per known
         ;; parameter name), this tries each recur position with a
         ;; qualified name in turn, since any of them could be the chain's
         ;; root.
         (let ((bindings (fol.compiler.ast:bind-node-bindings n))
               (body (fol.compiler.ast:bind-node-body n)))
           (when (and bindings
                      (= 1 (length body))
                      (fol.compiler.ast:recur-node-p (first body))
                      (every (lambda (b) (symbolp (car b))) bindings))
             (let* ((rnode (first body))
                    (args (fol.compiler.ast:recur-node-args rnode)))
               (loop for i from 0 below (min (length args) (length pos-names))
                     for qname = (aref pos-names i)
                     when (and qname (notany (lambda (b) (eq (car b) qname)) bindings))
                       do (multiple-value-bind (alias expanded) (%fold-let-chain bindings qname)
                            (when (and alias
                                       (fol.compiler.ast:symbol-ref-node-p (nth i args))
                                       (eq (fol.compiler.ast:symbol-ref-node-name (nth i args)) alias)
                                       (= 1 (%tr-symbol-ref-count rnode alias)))
                              (return-from try-let-chain-rw
                                (rewrite-recur
                                 (fol.compiler.ast:make-recur-node
                                  :args (loop for a in args
                                              for j from 0
                                              collect (if (= j i) expanded a))
                                  :form (fol.compiler.ast:ast-node-form rnode)))))))))))
       (try-read-tolerant-chain-rw (n)
         ;; Mirrors CLASSIFY-LOOP-PARAM's TRY-READ-TOLERANT-CHAIN via the
         ;; shared %VALIDATE-READ-TOLERANT-CHAIN. Unlike TRY-LET-CHAIN-RW,
         ;; does not fold BINDINGS into one expression at the recur site --
         ;; a read's result (DVI's T1) has no place there, since it isn't
         ;; itself an updated accumulator. Instead rebuilds the BIND with
         ;; the SAME bindings in the SAME order: a chain-extending binding's
         ;; init is rewritten via REWRITE-CHAIN, rooted at whatever the
         ;; running alias was immediately before it (CUR, advanced after
         ;; each such binding); a read/unrelated binding's init is emitted
         ;; via RW, completely unchanged. The accumulator-position recur
         ;; argument becomes a bare reference to the final alias -- no
         ;; rewriting needed, since it's just a variable reference, not a
         ;; new call -- and every OTHER recur argument is rewritten via RW
         ;; as usual.
         ;; *DISPATCH-THROUGH-NAMES* is keyed on the loop's OWN qualified
         ;; name (QNAME, e.g. CART), but REWRITE-CHAIN/BANG-REF check
         ;; whatever LOCAL alias a given step is rooted at (e.g. C1 for
         ;; C2's binding) -- unlike TRY-LET-CHAIN-RW's folded expression,
         ;; where every nested call is still structurally reached via
         ;; QNAME itself (substitution never introduces a NEW loose
         ;; variable name), this BIND-preserving rewrite genuinely
         ;; introduces new local alias names BANG-REF must also recognize.
         ;; When QNAME itself needs dispatch-through, every chain-extending
         ;; binding's own var is added to a locally-rebound
         ;; *DISPATCH-THROUGH-NAMES* for the duration of rewriting this
         ;; BIND, so BANG-REF's membership check succeeds regardless of
         ;; which alias in the chain it's asked about.
         (let ((bindings (fol.compiler.ast:bind-node-bindings n))
               (body (fol.compiler.ast:bind-node-body n)))
           (when (and bindings
                      (= 1 (length body))
                      (fol.compiler.ast:recur-node-p (first body))
                      (every (lambda (b) (symbolp (car b))) bindings))
             (let* ((rnode (first body))
                    (args (fol.compiler.ast:recur-node-args rnode)))
               (loop for i from 0 below (min (length args) (length pos-names))
                     for qname = (aref pos-names i)
                     when (and qname (notany (lambda (b) (eq (car b) qname)) bindings))
                       do (multiple-value-bind (alias extend-flags)
                              (%validate-read-tolerant-chain bindings qname)
                            (when (and alias
                                       (fol.compiler.ast:symbol-ref-node-p (nth i args))
                                       (eq (fol.compiler.ast:symbol-ref-node-name (nth i args)) alias)
                                       (= 1 (%tr-symbol-ref-count rnode alias)))
                              (return-from try-read-tolerant-chain-rw
                                (let* ((cur qname)
                                       (extend-vars (loop for b in bindings
                                                           for e in extend-flags
                                                           when e collect (car b)))
                                       (*dispatch-through-names*
                                         (if (member qname *dispatch-through-names*)
                                             (append extend-vars *dispatch-through-names*)
                                             *dispatch-through-names*)))
                                  (fol.compiler.ast:make-bind-node
                                   :bindings (loop for b in bindings
                                                    for extend-p in extend-flags
                                                    collect (let ((rewritten
                                                                    (if extend-p
                                                                        (rewrite-chain (cdr b) cur)
                                                                        (rw (cdr b) nil))))
                                                              (when extend-p (setf cur (car b)))
                                                              (cons (car b) rewritten)))
                                   :body (list (fol.compiler.ast:make-recur-node
                                                :args (loop for a in args
                                                            for j from 0
                                                            collect (if (= j i) a (rw a nil)))
                                                :form (fol.compiler.ast:ast-node-form rnode)))
                                   :form (fol.compiler.ast:ast-node-form n)))))))))))
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
            (or (try-let-chain-rw n)
                (try-read-tolerant-chain-rw n)
                (fol.compiler.ast:make-bind-node
                 :bindings (mapcar (lambda (b) (cons (car b) (rw (cdr b) nil)))
                                   (fol.compiler.ast:bind-node-bindings n))
                 :body (rw-list (fol.compiler.ast:bind-node-body n) tailp)
                 :form (fol.compiler.ast:ast-node-form n))))
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
   its own classification, so the init-type gate sees them.

   Checks whether INIT actually roots at NAME \\emph{before} validating the
   lambda: %LINEAR-REDUCE-LAMBDA's call to REDUCE-ACC-QUALIFIED-P has the
   side effect of recording that reduce's own spine ops via %NOTE-CHAIN-OP
   (through a nested CLASSIFY-LOOP-PARAM call), regardless of whether this
   reduce turns out to be NAME's own chain link. When a loop has a second
   accumulator with an unrelated reduce-based update (e.g. two independent
   accumulators, one a vector grown via a nested reduce, the other a dict
   grown via direct ASSOC), classifying the dict accumulator's uses walks
   over the vector's reduce as an unrelated \"other\" node; without this
   ordering, that walk would validate the vector's lambda anyway and leak
   its ops (e.g. \"CONJ\") into the dict accumulator's *CHAIN-OPS*, wrongly
   failing its op-gate check for an op that was never actually part of its
   own chain. Checking the cheap, side-effect-free root test first (a bare
   symbol-ref match has none) avoids the validation, and the leak, whenever
   the reduce doesn't belong to NAME in the first place."
  (destructuring-bind (f init coll) (fol.compiler.ast:call-node-args node)
    (multiple-value-bind (kind others) (chain-kind init name)
      (if (or (null kind) (not (%linear-reduce-lambda f name)))
          (values nil nil)
          (values :update (cons coll others))))))

(defun maybe-transient-reduce (node)
  "When *TRANSIENT-LOOPS* is enabled and NODE is a convertible reduce call,
   return the transient-protocol rewrite; otherwise NODE. Called by emit-call.
   Second value: the summarized operator names the conversion assumed.
   Third value: a singleton list, ((KIND . USED-OPS)), or NIL -- passed to
   %KIND-TRUSTED-P at load time by the region's REGISTER-REGION call site
   (see %KIND-TRUSTED-P's docstring for why the compile-time TRUSTED check
   alone doesn't suffice).
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
               (*read-ops* '())
               (*inlined-helpers* '())
               (basic-ok (and fn-ok
                              (transient-eligible-init-p init)
                              (= 2 (length params))
                              (symbolp acc)
                              (symbolp (second params))
                              (not (eq acc (second params)))
                              (not (%contains-recur-p f))))
               (supports-p nil)
               (needs-dispatch-p nil)
               (kind-and-ops nil))
          (when basic-ok
            (multiple-value-bind (ok uses) (reduce-acc-qualified-p acc (cdr clause))
              (when ok
                (multiple-value-bind (sp ndp ko)
                    (init-supports-p init *chain-ops* (%reads-present-p uses))
                  (setf supports-p sp needs-dispatch-p ndp kind-and-ops ko)))))
          (if (not supports-p)
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
                                                     (let ((*dispatch-through-names*
                                                            (when needs-dispatch-p (list acc))))
                                                       (rewrite-loop-body
                                                        (cdr clause) (list acc)
                                                        #() :reduce))))
                                :docstring nil
                                :form (fol.compiler.ast:ast-node-form f))
                               (%call1 "TRANSIENT" init)
                               coll)
                   :form (fol.compiler.ast:ast-node-form node)))
                 (union (union (union (union *chain-ops* *read-ops* :test #'string=)
                                      (mapcar #'string *inlined-helpers*) :test #'string=)
                               (union (let ((n (%init-call-name init))) (and n (list n)))
                                      (%init-fresh-dependency-names init) :test #'string=)
                               :test #'string=)
                        (list "REDUCE") :test #'string=)
                 (and kind-and-ops (list kind-and-ops)))))))))

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
   or NIL if no check is needed.
   Fifth value: a list of (KIND . USED-OPS) pairs, one per qualifying
   accumulator (a loop may convert more than one at once) -- passed to
   %KIND-TRUSTED-P at load time by the region's REGISTER-REGION call site
   (see %KIND-TRUSTED-P's docstring for why the compile-time TRUSTED check
   alone doesn't suffice)."
  (if (not *transient-loops*)
      node
      (let* ((bindings (fol.compiler.ast:loop-node-bindings node))
             (pos-names (make-array (length bindings) :initial-element nil))
             (qnames '())
             (dispatch-qnames '())
             (assumptions '())
             (trust-checks '()))
        (loop for (pname . init) in bindings
              for i from 0
              for pos from 0
              do (when (and (symbolp pname)
                            (transient-eligible-init-p init))
                   (let* ((*chain-ops* '())
                          (*read-ops* '())
                          (*inlined-helpers* '())
                          (uses (classify-loop-param pname pos node)))
                     (when (eq :qualified (param-verdict uses))
                       (multiple-value-bind (supports-p needs-dispatch-p kind-and-ops)
                           (init-supports-p init *chain-ops* (%reads-present-p uses))
                         (when supports-p
                           (push pname qnames)
                           (setf (aref pos-names pos) pname)
                           (when needs-dispatch-p (push pname dispatch-qnames))
                           (when kind-and-ops (push kind-and-ops trust-checks))
                           (setf assumptions
                                 (union (union (union (union *chain-ops* *read-ops* :test #'string=)
                                                      (mapcar #'string *inlined-helpers*) :test #'string=)
                                              (union (let ((n (%init-call-name init))) (and n (list n)))
                                                     (%init-fresh-dependency-names init) :test #'string=)
                                              :test #'string=)
                                        assumptions :test #'string=))))))))
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
                   ;; A constructor-call init (TRANSIENT-ELIGIBLE-INIT-P's other
                   ;; case) falls through to NIL here, same as an empty literal:
                   ;; its runtime size isn't known statically, so it's treated as
                   ;; always-profitable rather than guessed at. Sound (freshness
                   ;; and kind are still checked separately), but a constructor
                   ;; that happens to build a large initial collection wouldn't
                   ;; get the size guard a literal of the same size would.
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
                  :body (let ((*dispatch-through-names* dispatch-qnames))
                          (rewrite-loop-body (fol.compiler.ast:loop-node-body node)
                                             qnames pos-names))
                  :form (fol.compiler.ast:ast-node-form node))
                 assumptions
                 profit-check
                 ;; When a profitability check is emitted it references the
                 ;; accumulator by name, but the accumulator is bound only
                 ;; *inside* each loop. Return (name . init-node) so emit-loop
                 ;; can bind it in an outer LET that scopes the guard.
                 (when profit-check (cons first-qname first-qinit))
                 trust-checks)))))))

;;; ============================================================================
;;; Tier-2 Summary Inference (step 6)
;;; ============================================================================

(defun %infer-returns-kind (body)
  "Best-effort collection-kind for a single-clause function's tail
   expression: :DICT/:VECTOR/:SET when it's a collection literal or a
   direct call to a Tier-1 DICT/VECTOR/SET constructor, else NIL. Feeds
   INIT-SUPPORTS-P's op-gate check when TRANSIENT-ELIGIBLE-INIT-P accepts
   a constructor-call loop init (§sec:formal's \"constructor call summarized
   as returning an unaliased root\" clause) -- RETURNS-FRESH-P alone proves
   the root is unaliased, not which representation it is, and picking the
   wrong op-gate would be unsound, not merely imprecise. Callers must treat
   NIL as \"unknown\", not \"none\", and decline conversion rather than
   guess -- deliberately narrow (no branching, no transitive constructor
   calls) for exactly that reason."
  (let ((tail (car (last body))))
    (cond
      ((fol.compiler.ast:dict-node-p tail) :dict)
      ((fol.compiler.ast:vector-node-p tail) :vector)
      ((fol.compiler.ast:set-node-p tail) :set)
      ((fol.compiler.ast:call-node-p tail)
       (let ((op (operator-symbol tail)))
         (and op
              (cond ((string= (symbol-name op) "DICT") :dict)
                    ((string= (symbol-name op) "VECTOR") :vector)
                    ((string= (symbol-name op) "SET") :set)))))
      (t nil))))

(defun %fresh-tail-value-p (node params local-fresh-env)
  "Two values: (FRESH-P DEPENDS-ON-CLASSES). Judges whether NODE, reached
   in tail position, is guaranteed to evaluate to a fresh, uniquely-owned
   value -- the recursive check %INFER-SUMMARY-SINGLE-PASS's RETURNS-FRESH-P
   used to skip, relying instead on two narrow side-effect conditions (a
   bare parameter returned, or a parameter marked :RETAINED) that leave a
   free/global variable reference or a non-fresh call result in tail
   position entirely unnoticed -- confirmed by direct evaluation: a 0-ary
   function returning a global collection was inferred RETURNS-FRESH-P T.

   PARAMS is this function's own parameter-name list (never fresh -- the
   caller retains its own reference to whatever it passed in).
   LOCAL-FRESH-ENV is an alist of BIND-local name -> (fresh-p . classes),
   extended as bindings are walked, so a bind-local returned bare in tail
   position (invisible to the old parameter-only check) resolves correctly.

   DEPENDS-ON-CLASSES is never itself trusted here -- it only names which
   classes' MAKE a *consumer* of the resulting summary must separately
   verify live (see FRESH-IF-CLASSES-TRUSTED's docstring, summaries.lisp)."
  (cond
    ;; Literal/atomic tail values can't alias a pre-existing mutable root,
    ;; so freshness is vacuously true for them -- includes numbers, strings,
    ;; booleans, nil, keywords, and quoted data.
    ((or (fol.compiler.ast:vector-node-p node)
         (fol.compiler.ast:dict-node-p node)
         (fol.compiler.ast:set-node-p node)
         (fol.compiler.ast:literal-node-p node)
         (fol.compiler.ast:quote-node-p node))
     (values t nil))

    ((fol.compiler.ast:symbol-ref-node-p node)
     (let ((name (fol.compiler.ast:symbol-ref-node-name node)))
       (cond
         ((member name params :test #'eq) (values nil nil))
         ((assoc name local-fresh-env :test #'eq)
          (let ((entry (cdr (assoc name local-fresh-env :test #'eq))))
            (values (car entry) (cdr entry))))
         ;; A free/global variable reference: conservatively not fresh.
         ;; This is the actual bug fix -- previously invisible entirely.
         (t (values nil nil)))))

    ((fol.compiler.ast:call-node-p node)
     (let ((class (%tier2-constructor-class node)))
       (if class
           ;; NOT unconditionally fresh -- MAKE is a hijackable generic
           ;; function. FRESH-P is NIL here deliberately: freshness holds
           ;; only if CLASS's MAKE is later verified untrusted-checked live
           ;; (TIER1-METHODS-TRUSTED-P), never cached as a bare T. See
           ;; FRESH-IF-CLASSES-TRUSTED's docstring, summaries.lisp.
           (values nil (list class))
           (let ((summary (%init-call-summary node)))
             (if summary
                 (values (fol.compiler.summaries:escape-summary-returns-fresh-p summary)
                         (fol.compiler.summaries:escape-summary-fresh-if-classes-trusted summary))
                 (values nil nil))))))

    ((fol.compiler.ast:if-node-p node)
     (multiple-value-bind (then-fresh then-classes)
         (%fresh-tail-value-p (fol.compiler.ast:if-node-then node) params local-fresh-env)
       (let ((else-fresh t) (else-classes nil))
         (dolist (form (fol.compiler.ast:if-node-else node))
           (multiple-value-bind (f c) (%fresh-tail-value-p form params local-fresh-env)
             (setf else-fresh (and else-fresh f)
                   else-classes (union else-classes c))))
         (values (and then-fresh else-fresh) (union then-classes else-classes)))))

    ((fol.compiler.ast:do-node-p node)
     (let ((body (fol.compiler.ast:do-node-body node)))
       (if body
           (%fresh-tail-value-p (car (last body)) params local-fresh-env)
           (values t nil))))

    ((fol.compiler.ast:bind-node-p node)
     (let ((env local-fresh-env))
       (dolist (b (fol.compiler.ast:bind-node-bindings node))
         (when (symbolp (car b))
           (multiple-value-bind (f c) (%fresh-tail-value-p (cdr b) params env)
             (push (cons (car b) (cons f c)) env))))
       (let ((body (fol.compiler.ast:bind-node-body node)))
         (if body
             (%fresh-tail-value-p (car (last body)) params env)
             (values t nil)))))

    ;; Unrecognized shape: conservative default.
    (t (values nil nil))))

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
                 ;; A parameter returned directly is :shared-with-result.
                 ;; Freshness of the overall return value is judged
                 ;; separately, after this walk, by %FRESH-TAIL-VALUE-P --
                 ;; this clause only needs the param-effect side of things.
                 ((fol.compiler.ast:symbol-ref-node-p node)
                  (let ((idx (param-index (fol.compiler.ast:symbol-ref-node-name node))))
                    (when (and idx tailp)
                      (update-effect idx :shared-with-result))))

                 ((fol.compiler.ast:call-node-p node)
                  (let* ((op (operator-symbol node))
                         (kw-p (keyword-operator-p node))
                         (summary (and op (fol.compiler.summaries:lookup-summary op))))
                    (when (and op (member (symbol-name op) +barrier-names+ :test #'string=))
                      (setf barrier-p t))

                    (walk (fol.compiler.ast:call-node-operator node) nil)
                    (loop for arg in (fol.compiler.ast:call-node-args node)
                          for i from 0
                          do (if (fol.compiler.ast:symbol-ref-node-p arg)
                                 (let ((idx (param-index (fol.compiler.ast:symbol-ref-node-name arg))))
                                   (when idx
                                     (update-effect
                                      idx
                                      (cond
                                        ;; (:key obj) / (:key obj default): a keyword
                                        ;; used as the operator is always a pure read
                                        ;; of its object argument (position 0) -- no
                                        ;; user-definable method-combination hazard on
                                        ;; a keyword literal the way a named generic
                                        ;; has, so this is unconditionally :none rather
                                        ;; than gated behind a summary lookup (there is
                                        ;; none: OPERATOR-SYMBOL returns NIL for a
                                        ;; keyword operator, which previously made this
                                        ;; default to :retained, the same trust
                                        ;; boundary CLASSIFY-LOOP-PARAM's own walker
                                        ;; and CALL-ARG-READ-P already extend to
                                        ;; keyword accessors).
                                        ((and kw-p (= i 0)) :none)
                                        (summary (fol.compiler.summaries:effect-for-arg summary i))
                                        (t :retained)))))
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

    (multiple-value-bind (returns-fresh-p fresh-if-classes-trusted)
        (if body
            (%fresh-tail-value-p (car (last body)) params nil)
            (values t nil))
      (fol.compiler.summaries:make-escape-summary
       :name (let ((n (fol.compiler.ast:fn-node-name fn-node)))
               (if n (string n) "anonymous"))
       :param-effects param-effects
       :rest-effect nil ; Non-recursive version doesn't handle &rest
       :returns-fresh-p returns-fresh-p
       :fresh-if-classes-trusted fresh-if-classes-trusted
       :returns-kind (%infer-returns-kind body)
       :barrier-p barrier-p))))


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

    (let* ((clause (first (fol.compiler.ast:fn-node-clauses fn-node)))
           (params (%param-names (car clause)))
           (param-count (length params))
           ;; RETURNS-KIND is a static fact about the tail form, not something
           ;; the iteration refines -- seed it here so it's identical on every
           ;; round. Otherwise the placeholder's NIL and the first round's
           ;; real answer (e.g. :dict) look like a genuine GF-method conflict
           ;; to SUMMARY-JOIN, and the join collapses a known kind to unknown.
           (returns-kind (%infer-returns-kind (cdr clause)))
           ;; Start with the most optimistic summary: nothing escapes, returns fresh.
           (current-summary
             (fol.compiler.summaries:make-escape-summary
              :name (string name)
              :param-effects (make-array param-count :initial-element :none)
              :returns-fresh-p t
              :returns-kind returns-kind))
           (iteration-count 0)
           (max-iterations 5)) ; Safety break

      (loop
        (when (> (incf iteration-count) max-iterations)
          (warn "infer-summary for ~S did not converge after ~D iterations." name max-iterations)
          ;; Return a conservative summary on failure to converge. RETURNS-KIND
          ;; is still reported (it's a static fact, independent of the
          ;; non-convergent param effects), but RETURNS-FRESH-P defaults to
          ;; NIL, so consumers checking freshness first won't act on it.
          (return (fol.compiler.summaries:make-escape-summary
                   :name (string name)
                   :param-effects (make-array param-count :initial-element :retained)
                   :returns-kind returns-kind)))

        ;; Temporarily place the current assumption in the cache so recursive calls find it.
        (setf (gethash name fol.compiler.summaries:*inferred-summaries*) current-summary)

        (let* ((next-summary (%infer-summary-single-pass fn-node))
               (joined-summary (fol.compiler.summaries:summary-join current-summary next-summary)))
          (when (fol.compiler.summaries:summary<= joined-summary current-summary)
            (return joined-summary)) ; Fixed point reached.
          (setf current-summary joined-summary))))))
