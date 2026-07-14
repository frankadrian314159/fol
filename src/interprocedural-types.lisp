;;; Interprocedural parameter-type / return-type inference
;;;
;;; INFER-TYPE-FROM-CONSTRUCTOR (compiler.lisp) only recognizes a literal
;;; (make-<T> ...) call sitting directly at the use site. This file proves a
;;; wider fact by looking at the whole compilation unit at once: for a
;;; single-clause user function F with plain positional parameters,
;;;
;;;   - PARAM-CLASS[F][i]   -- the persistent-object class every call site in
;;;                            the unit always passes as F's i-th argument,
;;;                            when every call site agrees and every argument
;;;                            expression is itself provably that class.
;;;   - RETURNS-CLASS[F]    -- the class F's single tail expression always
;;;                            evaluates to (a literal constructor call, or a
;;;                            call to another function whose own
;;;                            RETURNS-CLASS is already proven).
;;;
;;; Both are computed by one bounded fixed-point pass, INFER-INTERPROCEDURAL-
;;; TYPES, over the whole list of a compilation unit's top-level ASTs.
;;; INFER-TYPE-FROM-EXPR is the consumer-facing entry point: it tries the
;;; existing literal-constructor check first, then falls back to these two
;;; tables.
;;;
;;; Soundness notes:
;;;   - Only exact-arity positional calls to a tracked function count as
;;;     evidence. An argument expression that isn't itself provably a single
;;;     class (anything other than a literal constructor call, a call to an
;;;     already-proven function, or a reference to the enclosing function's
;;;     own already-proven parameter) forces that parameter permanently
;;;     unprovable -- it is never silently ignored.
;;;   - If a tracked function's name is ever referenced anywhere in the
;;;     compilation unit outside of a call-operator position (bound to a
;;;     var, passed to another function, funcall'd), its facts are forced
;;;     unprovable: an indirect call site cannot be enumerated by this walk,
;;;     so no per-call-site evidence can be trusted as exhaustive.
;;;   - Multi-clause functions are out of scope entirely (no single stable
;;;     positional-parameter identity to attach a fact to), matching
;;;     %INFER-RETURNS-KIND's existing precedent in escape-analysis.lisp.
;;;   - This is a whole-file, one-shot analysis: both tables are cleared and
;;;     recomputed by every call to INFER-INTERPROCEDURAL-TYPES, not
;;;     maintained incrementally across separate COMPILE-FORM calls.

(in-package :fol.compiler)

(defvar *inferred-param-types* (make-hash-table :test 'eq)
  "Function-name symbol -> simple-vector of (class-name-symbol or NIL), one
   slot per positional parameter, proven by INFER-INTERPROCEDURAL-TYPES. NIL
   means \"not proven\" (no evidence, or conflicting evidence).")

(defvar *inferred-returns-class* (make-hash-table :test 'eq)
  "Function-name symbol -> class-name symbol or NIL: see *INFERRED-PARAM-TYPES*.")

(defparameter *ip-max-iterations* 8
  "Cap on fixed-point rounds, mirroring INFER-SUMMARY's MAX-ITERATIONS
   (escape-analysis.lisp). A round only continues while some fact changed.")

;;; ---------------------------------------------------------------------
;;; Function table: eligible single-clause functions found in this unit
;;; ---------------------------------------------------------------------

(defstruct (%ip-fn-info (:conc-name %ip-fn-))
  name
  params      ; ordered list of parameter symbols
  tail-node   ; the function's single body expression, or NIL if its body
              ; isn't exactly one expression (still tracked for PARAM-CLASS;
              ; just ineligible for RETURNS-CLASS)
  (indirect-p nil))

(defun %ip-register (name clauses table)
  "Register NAME in TABLE when CLAUSES describe a single clause with a flat,
   unspecialized positional parameter list -- the same eligibility test
   %DEFN-CONTEXT-PARAM-INDEX (compiler.lisp) uses for emission-time context."
  (when (and name (= 1 (length clauses)))
    (let* ((clause (first clauses))
           (params (%sr-param-list (car clause)))
           (body (%sr-strip-docstring (cdr clause))))
      (when (%sr-symbol-list-p params)
        (setf (gethash name table)
              (make-%ip-fn-info :name name :params params
                                 :tail-node (when (= 1 (length body)) (first body))))))))

(defun %ip-collect (asts table)
  "Populate TABLE (name -> %IP-FN-INFO) from the top-level ASTS, recursing
   into DO wrappers -- the same top-level shapes SR-TRANSFORM-TOPLEVEL /
   TR-TRANSFORM-TOPLEVEL (compiler.lisp) already recurse into."
  (labels ((visit (n)
             (typecase n
               (fol.compiler.ast:defn-node
                (%ip-register (fol.compiler.ast:defn-node-name n)
                               (fol.compiler.ast:defn-node-clauses n) table))
               (fol.compiler.ast:defn-private-node
                (%ip-register (fol.compiler.ast:defn-private-node-name n)
                               (fol.compiler.ast:defn-private-node-clauses n) table))
               (fol.compiler.ast:definline-node
                (%ip-register (fol.compiler.ast:definline-node-name n)
                               (fol.compiler.ast:definline-node-clauses n) table))
               (fol.compiler.ast:do-node
                (mapc #'visit (fol.compiler.ast:do-node-body n))))))
    (dolist (a asts) (visit a))))

;;; ---------------------------------------------------------------------
;;; Whole-program walk: call sites + indirect-reference soundness guard
;;; ---------------------------------------------------------------------

(defun %ip-scan-defn (name clauses fn-table on-call)
  "Scan every clause's body of a top-level defn/defn-private/definline for
   call sites and indirect references, using that clause's own parameter
   list as caller context (available even for clauses NAME doesn't qualify
   for tracking as a callee -- caller-side context only needs a flat
   positional parameter list, independent of NAME's own eligibility)."
  (declare (ignore name))
  (dolist (clause clauses)
    (let* ((params (%sr-param-list (car clause)))
           (body (%sr-strip-docstring (cdr clause)))
           (ctx (when (%sr-symbol-list-p params)
                  (cons nil (loop for p in params for i from 0 collect (cons p i))))))
      (dolist (b body)
        (%ip-scan-node b fn-table ctx on-call)))))

(defun %ip-scan-node (node fn-table ctx on-call)
  "Walk NODE for calls to functions in FN-TABLE (invoking ON-CALL with
   (callee-info arg-nodes ctx) for each exact-arity call) and for bare
   references to their names outside of call-operator position (marking
   that entry's INDIRECT-P). CTX is (OWNER-NAME . PARAM-INDEX-ALIST) for the
   innermost enclosing single-clause caller, or NIL."
  (cond
    ((fol.compiler.ast:call-node-p node)
     (let ((operator (fol.compiler.ast:call-node-operator node))
           (args (fol.compiler.ast:call-node-args node)))
       (if (fol.compiler.ast:symbol-ref-node-p operator)
           (let* ((op-name (fol.compiler.ast:symbol-ref-node-name operator))
                  (callee (gethash op-name fn-table)))
             (when (and callee (= (length args) (length (%ip-fn-params callee))))
               (funcall on-call callee args ctx)))
           (%ip-scan-node operator fn-table ctx on-call))
       (dolist (a args) (%ip-scan-node a fn-table ctx on-call))))
    ((fol.compiler.ast:symbol-ref-node-p node)
     (let ((callee (gethash (fol.compiler.ast:symbol-ref-node-name node) fn-table)))
       (when callee (setf (%ip-fn-indirect-p callee) t))))
    ((or (fol.compiler.ast:defn-node-p node)
         (fol.compiler.ast:defn-private-node-p node)
         (fol.compiler.ast:definline-node-p node))
     (multiple-value-bind (name clauses)
         (typecase node
           (fol.compiler.ast:defn-node
            (values (fol.compiler.ast:defn-node-name node) (fol.compiler.ast:defn-node-clauses node)))
           (fol.compiler.ast:defn-private-node
            (values (fol.compiler.ast:defn-private-node-name node) (fol.compiler.ast:defn-private-node-clauses node)))
           (fol.compiler.ast:definline-node
            (values (fol.compiler.ast:definline-node-name node) (fol.compiler.ast:definline-node-clauses node))))
       (%ip-scan-defn name clauses fn-table on-call)))
    ((fol.compiler.ast:do-node-p node)
     (dolist (b (fol.compiler.ast:do-node-body node)) (%ip-scan-node b fn-table ctx on-call)))
    (t (dolist (c (fol.compiler.escape-analysis:node-children node))
         (%ip-scan-node c fn-table ctx on-call)))))

;;; ---------------------------------------------------------------------
;;; Lattice + argument-type resolution
;;; ---------------------------------------------------------------------

(defun %ip-join-evidence (current evidence)
  "CURRENT is a class symbol or :BOTTOM/:CONFLICT (a persisted table value).
   EVIDENCE is a class symbol, :PENDING (no new information this round -- a
   dependency hasn't resolved yet), or :CONFLICT (positively unprovable).
   Monotone: once :CONFLICT, always :CONFLICT."
  (cond
    ((eq evidence :pending) current)
    ((eq current :conflict) :conflict)
    ((eq evidence :conflict) :conflict)
    ((eq current :bottom) evidence)
    ((eq current evidence) current)
    (t :conflict)))

(defun %ip-arg-expr-type (node ctx fn-table)
  "Best currently-known type for NODE (an argument or tail expression), used
   as fixed-point EVIDENCE (see %IP-JOIN-EVIDENCE). CTX is (OWNER-NAME .
   PARAM-INDEX-ALIST) for NODE's enclosing single-clause function, or NIL."
  (let ((direct (infer-type-from-constructor node)))
    (cond
      (direct direct)
      ;; Call to another tracked function: use its RETURNS-CLASS if already
      ;; resolved; if it's tracked but still :BOTTOM, defer (may resolve
      ;; later); a call to an untracked function is unprovable.
      ((and (fol.compiler.ast:call-node-p node)
            (fol.compiler.ast:symbol-ref-node-p (fol.compiler.ast:call-node-operator node)))
       (let* ((callee-name (fol.compiler.ast:symbol-ref-node-name
                             (fol.compiler.ast:call-node-operator node))))
         (if (gethash callee-name fn-table)
             (let ((val (gethash callee-name *inferred-returns-class* :bottom)))
               (case val ((:bottom) :pending) ((:conflict) :conflict) (t val)))
             :conflict)))
      ;; Reference to the enclosing function's own parameter: use its
      ;; PARAM-CLASS if already resolved.
      ((and (fol.compiler.ast:symbol-ref-node-p node) ctx
            (assoc (fol.compiler.ast:symbol-ref-node-name node) (cdr ctx)))
       (let* ((owner (car ctx))
              (idx (cdr (assoc (fol.compiler.ast:symbol-ref-node-name node) (cdr ctx))))
              (vec (and owner (gethash owner *inferred-param-types*))))
         (if (and vec (< idx (length vec)))
             (let ((val (aref vec idx)))
               (case val ((:bottom) :pending) ((:conflict) :conflict) (t val)))
             :conflict)))
      (t :conflict))))

;;; ---------------------------------------------------------------------
;;; Driver
;;; ---------------------------------------------------------------------

(defun infer-interprocedural-types (asts)
  "Whole-compilation-unit fixed-point pass over the top-level parsed ASTS
   (already parsed, not yet emitted). Populates *INFERRED-PARAM-TYPES* and
   *INFERRED-RETURNS-CLASS*, clearing any previous contents first."
  (clrhash *inferred-param-types*)
  (clrhash *inferred-returns-class*)
  (let ((fn-table (make-hash-table :test 'eq)))
    (%ip-collect asts fn-table)
    (maphash (lambda (name info)
               (setf (gethash name *inferred-param-types*)
                     (make-array (length (%ip-fn-params info)) :initial-element :bottom))
               (setf (gethash name *inferred-returns-class*) :bottom))
             fn-table)
    (loop repeat *ip-max-iterations*
          for changed = nil
          do
             ;; 1. Call-site evidence -> param types.
             (dolist (a asts)
               (%ip-scan-node a fn-table nil
                              (lambda (callee args ctx)
                                (let ((vec (gethash (%ip-fn-name callee) *inferred-param-types*)))
                                  (loop for arg in args
                                        for i from 0
                                        for evidence = (%ip-arg-expr-type arg ctx fn-table)
                                        for old = (aref vec i)
                                        for new = (%ip-join-evidence old evidence)
                                        do (unless (eq new old)
                                             (setf (aref vec i) new changed t)))))))
             ;; 2. Tail-expression evidence -> return class.
             (maphash (lambda (name info)
                        (when (%ip-fn-tail-node info)
                          (let* ((ctx (cons name (loop for p in (%ip-fn-params info)
                                                        for i from 0 collect (cons p i))))
                                 (evidence (%ip-arg-expr-type (%ip-fn-tail-node info) ctx fn-table))
                                 (old (gethash name *inferred-returns-class*))
                                 (new (%ip-join-evidence old evidence)))
                            (unless (eq new old)
                              (setf (gethash name *inferred-returns-class*) new changed t)))))
                      fn-table)
             ;; 3. Indirect-reference soundness guard.
             (maphash (lambda (name info)
                        (when (%ip-fn-indirect-p info)
                          (let ((pvec (gethash name *inferred-param-types*)))
                            (dotimes (i (length pvec))
                              (unless (eq (aref pvec i) :conflict)
                                (setf (aref pvec i) :conflict changed t))))
                          (unless (eq (gethash name *inferred-returns-class*) :conflict)
                            (setf (gethash name *inferred-returns-class*) :conflict changed t))))
                      fn-table)
             (unless changed (return))))
  ;; Finalize: :BOTTOM (never observed) and :CONFLICT both collapse to NIL
  ;; for consumers; concrete class symbols pass through unchanged.
  (flet ((finalize (v) (if (or (eq v :bottom) (eq v :conflict)) nil v)))
    (maphash (lambda (name vec)
               (declare (ignore name))
               (dotimes (i (length vec)) (setf (aref vec i) (finalize (aref vec i)))))
             *inferred-param-types*)
    (maphash (lambda (name v) (setf (gethash name *inferred-returns-class*) (finalize v)))
             *inferred-returns-class*))
  (values))

;;; ---------------------------------------------------------------------
;;; Consumer-facing entry point
;;; ---------------------------------------------------------------------

(defun infer-type-from-expr (node)
  "Like INFER-TYPE-FROM-CONSTRUCTOR, but also consults the interprocedural
   facts above: a call to a function with a proven RETURNS-CLASS, or (via
   *CURRENT-DEFN-NAME*/*CURRENT-DEFN-PARAM-INDEX*, bound during emission of
   a single-clause function's body -- see compiler.lisp) a reference to the
   enclosing function's own proven parameter."
  (or (infer-type-from-constructor node)
      (when (and (fol.compiler.ast:call-node-p node)
                 (fol.compiler.ast:symbol-ref-node-p (fol.compiler.ast:call-node-operator node)))
        (gethash (fol.compiler.ast:symbol-ref-node-name (fol.compiler.ast:call-node-operator node))
                 *inferred-returns-class*))
      (when (and (fol.compiler.ast:symbol-ref-node-p node) *current-defn-param-index*)
        (let ((idx (cdr (assoc (fol.compiler.ast:symbol-ref-node-name node)
                                *current-defn-param-index*))))
          (when idx
            (let ((vec (and *current-defn-name*
                             (gethash *current-defn-name* *inferred-param-types*))))
              (when (and vec (< idx (length vec))) (aref vec idx))))))))
