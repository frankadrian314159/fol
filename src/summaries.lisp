;;; FOL Compiler - Escape Summaries (Tier-1 vocabulary)
;;;
;;; Step 1 of the escape/uniqueness analysis (see docs/escape-analysis-design.md).
;;;
;;; An ESCAPE-SUMMARY describes what a callee does with each argument, at
;;; ROOT granularity: persistent operations build fresh roots that reference
;;; the argument's *children*, never the argument's root object itself, so
;;; most stdlib operations retain nothing at the root level. Element-level
;;; sharing is deliberately untracked -- no client mutates elements, trie
;;; surgery replaces references only (design doc section 3.1).
;;;
;;; Effects (conservative linear order :none < :invoked < :shared-with-result
;;; < :retained):
;;;   :none               -- read only; not stored, not reachable via result
;;;   :invoked            -- called as a function, but not retained (HOF params)
;;;   :shared-with-result -- reachable through the return value only (stored as
;;;                          an element, or possibly returned itself)
;;;   :retained           -- may be reachable from anywhere after the call
;;;
;;; Arity rule: arguments beyond PARAM-EFFECTS use REST-EFFECT; with no
;;; REST-EFFECT they conservatively get :retained.
;;;
;;; Tier-1 soundness rests on these definitions being immutable at runtime.
;;; That is enforced by SBCL package locks on the implementation packages
;;; (LOCK-SUMMARY-PACKAGES), NOT on fol.core -- transpiled user code interns
;;; and defines symbols in fol.core, so fol.core must stay unlocked. Imports
;;; preserve home packages, so LOOKUP-SUMMARY's home-package guard is what
;;; keeps a user function merely *named* ASSOC from matching a Tier-1 entry.

(in-package :fol.compiler.summaries)

;;; ============================================================================
;;; Summary representation
;;; ============================================================================

(defstruct escape-summary
  (name "" :type string)
  (param-effects #() :type simple-vector)
  (rest-effect nil)          ; effect keyword or nil
  (returns-fresh-p nil)      ; result is a fresh root, uniquely owned by caller
  (returns-kind nil)         ; :dict/:vector/:set the result is built as, or NIL
                             ; if unrecognized; lets TRANSIENT-ELIGIBLE-INIT-P
                             ; and INIT-SUPPORTS-P (escape-analysis.lisp) treat
                             ; a summarized constructor CALL like a collection
                             ; literal for loop-init eligibility -- the
                             ; Qualification Rule's "constructor call" clause
                             ; (§sec:formal), not just RETURNS-FRESH-P alone,
                             ; since the op-gate check also needs the kind.
  (fresh-if-classes-trusted nil) ; list of class-name symbols, or NIL. When
                             ; non-NIL, the result is fresh PROVIDED each
                             ; listed class's MAKE has no non-primary-
                             ; qualified method -- re-checked live via
                             ; TIER1-METHODS-TRUSTED-P wherever this summary
                             ; is consulted, never cached as a bare boolean:
                             ; *INFERRED-SUMMARIES* has no transitive
                             ; invalidation (a helper's cached summary isn't
                             ; re-evaluated when a function IT called is
                             ; redefined), so baking a live MOP trust result
                             ; into RETURNS-FRESH-P would go stale silently
                             ; if MAKE were hijacked for that class after
                             ; this summary was cached.
  (barrier-p nil))           ; may eval/redefine -> full barrier at call sites

;;; ============================================================================
;;; Effect lattice
;;; ============================================================================

(defparameter +effect-order+ '(:none :invoked :shared-with-result :retained)
  "Conservative linear order on argument effects, weakest first.")

(defun %effect-rank (effect)
  (let ((rank (position effect +effect-order+)))
    (unless rank
      (error "Unknown escape effect: ~S" effect))
    rank))

(defun effect<= (e1 e2)
  "True when effect E1 is at most as escaping as E2."
  (cl:<= (%effect-rank e1) (%effect-rank e2)))

(defun effect-join (e1 e2)
  "Least upper bound of two effects."
  (if (effect<= e1 e2) e2 e1))

;;; ============================================================================
;;; Summary operations
;;; ============================================================================

(defun effect-for-arg (summary index)
  "Effect the callee applies to its INDEX-th (0-based) argument.
   Arguments beyond the declared effects use the rest effect; with no rest
   effect they conservatively escape (:retained)."
  (let ((effects (escape-summary-param-effects summary)))
    (cond ((cl:< index (length effects)) (svref effects index))
          ((escape-summary-rest-effect summary))
          (t :retained))))

(defun %max-param-count (s1 s2)
  (max (length (escape-summary-param-effects s1))
       (length (escape-summary-param-effects s2))))

(defun summary<= (new old)
  "True when NEW is compatible with every assumption a consumer of OLD made:
   pointwise no more escaping, freshness preserved where promised, and no new
   barrier where none was assumed. This is the monotonicity fast-path test
   used at redefinition time."
  (and (loop for i below (%max-param-count new old)
             always (effect<= (effect-for-arg new i) (effect-for-arg old i)))
       (effect<= (or (escape-summary-rest-effect new) :retained)
                 (or (escape-summary-rest-effect old) :retained))
       ;; A consumer that saw RETURNS-FRESH-P assumed a fresh root.
       (or (not (escape-summary-returns-fresh-p old))
           (escape-summary-returns-fresh-p new))
       ;; A consumer that saw no barrier assumed no barrier.
       (or (escape-summary-barrier-p old)
           (not (escape-summary-barrier-p new)))
       ;; FRESH-IF-CLASSES-TRUSTED is never trusted from a cached copy --
       ;; every consumer re-derives it from the CURRENT summary object and
       ;; re-verifies each listed class live (see the field's docstring).
       ;; So OLD's list carries no assumption that NEW could violate by
       ;; itself; only OLD's RETURNS-FRESH-P=T (checked above) is a bare
       ;; assumption a consumer could have taken without re-verifying.
       t))

(defun summary-join (s1 s2)
  "Least upper bound of two summaries (pointwise worst effects, fresh only if
   both are fresh, barrier if either is). Used to build generic-function
   summaries from method summaries. Positions absent from one summary take the
   other's effect; cross-arity GF joins are refined later (design doc sec. 9)."
  (let* ((n (%max-param-count s1 s2))
         (effects (make-array n)))
    (loop for i below n
          do (setf (svref effects i)
                   (effect-join
                    (if (cl:< i (length (escape-summary-param-effects s1)))
                        (svref (escape-summary-param-effects s1) i)
                        :none)
                    (if (cl:< i (length (escape-summary-param-effects s2)))
                        (svref (escape-summary-param-effects s2) i)
                        :none))))
    (multiple-value-bind (joined-fresh-p joined-classes)
        ;; RETURNS-FRESH-P/FRESH-IF-CLASSES-TRUSTED are joined together
        ;; (not independently) since a summary is fresh either
        ;; unconditionally (RETURNS-FRESH-P) or conditionally (a non-NIL
        ;; class list), never both -- see the field's docstring. Treat each
        ;; side as a 3-way fact: unconditionally fresh, conditionally fresh
        ;; pending trust of some classes, or never fresh. ANDing with a
        ;; never-fresh side makes the whole join never-fresh regardless of
        ;; the other side's classes; otherwise the join is conditional on
        ;; the union of whichever sides are themselves conditional (an
        ;; unconditionally-fresh side contributes no constraint).
        (let* ((f1 (escape-summary-returns-fresh-p s1))
               (f2 (escape-summary-returns-fresh-p s2))
               (c1 (escape-summary-fresh-if-classes-trusted s1))
               (c2 (escape-summary-fresh-if-classes-trusted s2))
               (never1 (and (not f1) (not c1)))
               (never2 (and (not f2) (not c2))))
          (cond
            ((or never1 never2) (values nil nil))
            ((and f1 f2) (values t nil))
            (t (values nil (union (if f1 nil c1) (if f2 nil c2))))))
      (make-escape-summary
       :name (escape-summary-name s1)
       :param-effects effects
       :rest-effect (let ((r1 (escape-summary-rest-effect s1))
                          (r2 (escape-summary-rest-effect s2)))
                      (cond ((and r1 r2) (effect-join r1 r2))
                            (t (or r1 r2))))
       :returns-fresh-p joined-fresh-p
       :fresh-if-classes-trusted joined-classes
       :returns-kind (and (eq (escape-summary-returns-kind s1)
                              (escape-summary-returns-kind s2))
                          (escape-summary-returns-kind s1))
       :barrier-p (or (escape-summary-barrier-p s1)
                      (escape-summary-barrier-p s2))))))

;;; ============================================================================
;;; Tier-1 table
;;; ============================================================================

(defvar *stdlib-summaries* (make-hash-table :test 'equal)
  "Symbol-name -> ESCAPE-SUMMARY for the trusted standard library (Tier 1).")

(defvar *inferred-summaries* (make-hash-table :test 'eq)
  "Symbol -> ESCAPE-SUMMARY for user functions (Tier 2), inferred by the
   compiler. Cleared on redefinition.")

(defparameter *fol-function-packages*
  '("FOL.COMPILER.COLLECTION-FUNCTIONS"
    "FOL.COMPILER.SEQ-FUNCTIONS"
    "FOL.COMPILER.ARRAY-FUNCTIONS"
    "FOL.COMPILER.ARITHMETIC-FUNCTIONS"
    "FOL.COMPILER.STRING-FUNCTIONS"
    "FOL.COMPILER.PRIMITIVE-FUNCTIONS"
    "FOL.COMPILER.MERGED-FUNCTIONS"
    "FOL.COMPILER.COMPAREOPS"
    "FOL.COMPILER.LOGICAL-OPERATION-FUNCTIONS"
    "FOL.COMPILER.FUNCTIONAL"
    "FOL.COMPILER.ADVERBS"
    "FOL.COMPILER.COLLECTIONS"
    "FOL.COMPILER.MISC-FUNCTIONS")
  "Home packages whose symbols may match Tier-1 summaries.")

(defun fol-stdlib-symbol-p (sym)
  "True when SYM's home package is one of the FOL implementation packages.
   Imports preserve home packages, so this holds for symbols seen via
   fol.core, and fails for user symbols that merely share a name."
  (and (symbolp sym)
       (symbol-package sym)
       (member (package-name (symbol-package sym))
               *fol-function-packages*
               :test #'string=)))

(defvar *resolve-by-name* t
  "When true, LOOKUP-SUMMARY falls back to symbol-name matching for symbols
   outside the implementation packages.

   Rationale: fol.core exports nothing, so in user packages stdlib calls read
   as CL symbols or fresh package-local symbols; the FOL compiler itself
   resolves them BY NAME at emit/load time (see emit-call's
   +standard-fol-functions+ string-equal check). Name matching therefore
   mirrors the language's actual resolution model. The homonym hazard --
   a user function that shares a stdlib name -- is exactly the hazard the
   compilation model already has, and is excluded per compilation unit via
   *NAME-EXCLUSIONS*.")

(defvar *name-exclusions* '()
  "Names (strings) defined by the current compilation unit; never matched
   against Tier-1 summaries by name. Bound from the compiler's
   *file-function-defs* during audited compiles.")

(defun %name-excluded-p (sym)
  (member (symbol-name sym) *name-exclusions* :test #'string=))

(defun lookup-summary (sym)
  "Return the Tier-1 summary for SYM, or NIL (= Tier 0, fully conservative).
   Checks for Tier-1 (stdlib), then Tier-2 (inferred), then falls back to
   name matching for Tier-1 per *RESOLVE-BY-NAME*."
  (when (and (symbolp sym) (not (keywordp sym)))
    (or (gethash sym *inferred-summaries*)
        (cond ((fol-stdlib-symbol-p sym)
               (gethash (symbol-name sym) *stdlib-summaries*))
              ((and *resolve-by-name* (not (%name-excluded-p sym)))
               (gethash (symbol-name sym) *stdlib-summaries*))))))

(defun clear-inferred-summary (sym)
  "Remove the inferred summary for SYM, if any. Called on redefinition."
  (when (symbolp sym)
    (remhash sym *inferred-summaries*))
  (values))

(defun define-stdlib-summary (name effects &key rest returns-fresh barrier)
  "Register a Tier-1 summary under NAME (case-insensitive)."
  (let ((key (string-upcase (string name))))
    (setf (gethash key *stdlib-summaries*)
          (make-escape-summary
           :name key
           :param-effects (coerce effects 'simple-vector)
           :rest-effect rest
           :returns-fresh-p returns-fresh
           :barrier-p barrier))))

;;; ----------------------------------------------------------------------------
;;; The table. Every entry is a hand-verified claim about the implementation;
;;; when a stdlib function changes, its entry must be re-audited.
;;; ----------------------------------------------------------------------------

;;; --- Collection accessors (read-only at root level) ---
(define-stdlib-summary "GET" '(:none :none :shared-with-result))         ; default may be returned
(define-stdlib-summary "GET-IN" '(:none :none :shared-with-result))
(define-stdlib-summary "NTH" '(:none :none :shared-with-result))
(define-stdlib-summary "FIRST" '(:none))
(define-stdlib-summary "SECOND" '(:none))
(define-stdlib-summary "THIRD" '(:none))
(define-stdlib-summary "LAST" '(:none))
(define-stdlib-summary "PEEK" '(:none))
(define-stdlib-summary "KEY" '(:none))
(define-stdlib-summary "VAL" '(:none))
(define-stdlib-summary "FIND" '(:none :none))
(define-stdlib-summary "COUNT" '(:none) :returns-fresh t)
(define-stdlib-summary "SIZE" '(:none) :returns-fresh t)
(define-stdlib-summary "EMPTY?" '(:none) :returns-fresh t)
(define-stdlib-summary "CONTAINS?" '(:none :none) :returns-fresh t)
(define-stdlib-summary "NOT-EMPTY" '(:shared-with-result))               ; returns its argument or nil

;;; --- Persistent updates (fresh root; argument's root not retained) ---
(define-stdlib-summary "ASSOC" '(:none :shared-with-result :shared-with-result)
  :rest :shared-with-result :returns-fresh t)
(define-stdlib-summary "DISSOC" '(:none :none) :rest :none :returns-fresh t)
(define-stdlib-summary "CONJ" '(:none :shared-with-result)
  :rest :shared-with-result :returns-fresh t)
(define-stdlib-summary "DISJ" '(:none :none) :rest :none :returns-fresh t)
(define-stdlib-summary "PUSH" '(:none :shared-with-result) :returns-fresh t)
(define-stdlib-summary "POP" '(:none) :returns-fresh t)
(define-stdlib-summary "REST" '(:none) :returns-fresh t)
(define-stdlib-summary "SUBVEC" '(:none :none :none) :returns-fresh t)
(define-stdlib-summary "ASSOC-IN" '(:none :none :shared-with-result) :returns-fresh t)
(define-stdlib-summary "MERGE" '(:none) :rest :none :returns-fresh t)
(define-stdlib-summary "SELECT-KEYS" '(:none :none) :returns-fresh t)
(define-stdlib-summary "KEYS" '(:none) :returns-fresh t)
(define-stdlib-summary "VALS" '(:none) :returns-fresh t)
;; UPDATE passes trailing args into the update function -> conservative rest.
(define-stdlib-summary "UPDATE" '(:none :none :invoked) :rest :retained :returns-fresh t)
(define-stdlib-summary "UPDATE-IN" '(:none :none :invoked) :rest :retained :returns-fresh t)

;;; --- Constructors ---
(define-stdlib-summary "VECTOR" '() :rest :shared-with-result :returns-fresh t)
(define-stdlib-summary "DICT" '() :rest :shared-with-result :returns-fresh t)
(define-stdlib-summary "SET" '() :rest :shared-with-result :returns-fresh t)
(define-stdlib-summary "LIST" '() :rest :shared-with-result :returns-fresh t)
(define-stdlib-summary "VEC" '(:shared-with-result))                     ; identity on vectors
(define-stdlib-summary "INTO" '(:shared-with-result :none))              ; may return TO
(define-stdlib-summary "RANGE" '(:none :none :none) :returns-fresh t)
(define-stdlib-summary "F64-ARRAY" '() :rest :shared-with-result :returns-fresh t)
(define-stdlib-summary "F32-ARRAY" '() :rest :shared-with-result :returns-fresh t)
(define-stdlib-summary "FIXNUM-ARRAY" '() :rest :shared-with-result :returns-fresh t)

;;; --- Sequence HOFs (function invoked, not retained; input roots read-only) ---
(define-stdlib-summary "MAPV" '(:invoked :none) :rest :none :returns-fresh t)
(define-stdlib-summary "MAP" '(:invoked :none) :rest :none :returns-fresh t)
(define-stdlib-summary "FILTER" '(:invoked :none) :returns-fresh t)
(define-stdlib-summary "FILTERV" '(:invoked :none) :returns-fresh t)
(define-stdlib-summary "REMOVE" '(:invoked :none) :returns-fresh t)
(define-stdlib-summary "KEEP" '(:invoked :none) :returns-fresh t)
(define-stdlib-summary "MAPCAT" '(:invoked :none) :rest :none :returns-fresh t)
;; FOL reduce signature is (fn init coll) -- Clojure order; result may BE init.
(define-stdlib-summary "REDUCE" '(:invoked :shared-with-result :none))
(define-stdlib-summary "EVERY" '(:invoked :none) :returns-fresh t)
(define-stdlib-summary "SOME" '(:invoked :none))                         ; returns pred's result
(define-stdlib-summary "TAKE" '(:none :none) :returns-fresh t)
(define-stdlib-summary "DROP" '(:none :none) :returns-fresh t)
(define-stdlib-summary "TAKE-WHILE" '(:invoked :none) :returns-fresh t)
(define-stdlib-summary "DROP-WHILE" '(:invoked :none) :returns-fresh t)
(define-stdlib-summary "CONCAT" '() :rest :none :returns-fresh t)
(define-stdlib-summary "REVERSE" '(:none) :returns-fresh t)
(define-stdlib-summary "SORT" '(:none) :returns-fresh t)
(define-stdlib-summary "SORT-BY" '(:invoked :none) :returns-fresh t)
(define-stdlib-summary "DISTINCT" '(:none) :returns-fresh t)
(define-stdlib-summary "PARTITION-ALL" '(:none :none) :returns-fresh t)
(define-stdlib-summary "PARTITION-BY" '(:invoked :none) :returns-fresh t)
(define-stdlib-summary "INTERPOSE" '(:shared-with-result :none) :returns-fresh t)

;;; --- Arithmetic, comparison, logic (scalars and vectorized; read-only) ---
(dolist (op '("+" "-" "*" "/" "INC" "DEC" "ABS" "MOD" "MIN" "MAX"
              "=" "<" ">" "<=" ">=" "NOT=" "/=" "NOT" "AND" "OR"))
  (define-stdlib-summary op '() :rest :none :returns-fresh t))

;;; --- Predicates ---
(dolist (pred '("NIL?" "SOME?" "ZERO?" "POSITIVE?" "NEGATIVE?" "ODD?" "EVEN?"
                "VECTOR?" "MAP?" "STRING?" "NUMBER?" "KEYWORD?" "SYMBOL?"
                "INTEGER?" "FN?" "COLL?" "SEQ?" "LIST?"))
  (define-stdlib-summary pred '(:none) :returns-fresh t))

;;; --- Strings & misc ---
(define-stdlib-summary "STR" '() :rest :none :returns-fresh t)
(define-stdlib-summary "SUBS" '(:none :none :none) :returns-fresh t)
(define-stdlib-summary "JOIN" '(:none :none) :returns-fresh t)
(define-stdlib-summary "SPLIT" '(:none :none) :returns-fresh t)
(define-stdlib-summary "PRINT" '() :rest :none)
(define-stdlib-summary "PRINTLN" '() :rest :none)
(define-stdlib-summary "IDENTITY" '(:shared-with-result))

;;; --- Escape hatches: args flow into an unknown function ---
(define-stdlib-summary "APPLY" '(:invoked) :rest :retained)
(define-stdlib-summary "FUNCALL" '(:invoked) :rest :retained)

;;; ============================================================================
;;; Transient counterparts
;;; ============================================================================

(defvar *transient-op-map*
  (let ((table (make-hash-table :test 'equal)))
    (loop for (op bang) in '(("ASSOC" "ASSOC!") ("CONJ" "CONJ!")
                             ("DISSOC" "DISSOC!") ("DISJ" "DISJ!")
                             ("POP" "POP!"))
          do (setf (gethash op table) bang))
    table)
  "Persistent op name -> destructive counterpart name, for the transient client.")

(defun transient-op-for (sym)
  "Name (string) of the transient counterpart of SYM, or NIL.
   Uses the same package-then-name resolution as LOOKUP-SUMMARY."
  (when (and (symbolp sym) (not (keywordp sym)))
    (when (or (fol-stdlib-symbol-p sym)
              (and *resolve-by-name* (not (%name-excluded-p sym))))
      (gethash (symbol-name sym) *transient-op-map*))))

(defun transient-safe-op-p (sym)
  "True when SYM is a stdlib op with a transient counterpart."
  (and (transient-op-for sym) t))

;;; ============================================================================
;;; Package locks (Tier-1 soundness)
;;; ============================================================================

(defparameter *summary-locked-packages* *fol-function-packages*
  "Packages locked to guarantee Tier-1 summaries cannot go stale.")

(defun lock-summary-packages (&optional (names *summary-locked-packages*))
  "Lock the implementation packages so summarized definitions cannot change.
   Returns the list of packages actually locked. Not called automatically;
   invoked when escape optimizations are enabled."
  #+sbcl
  (loop for name in names
        for pkg = (find-package name)
        when pkg
          collect (progn (sb-ext:lock-package pkg) pkg))
  #-sbcl
  (progn names nil))

(defun unlock-summary-packages (&optional (names *summary-locked-packages*))
  "Unlock previously locked packages (development/testing escape hatch)."
  #+sbcl
  (loop for name in names
        for pkg = (find-package name)
        when pkg
          collect (progn (sb-ext:unlock-package pkg) pkg))
  #-sbcl
  (progn names nil))
