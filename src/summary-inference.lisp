(in-package :fol.compiler)

(defvar *tier2-summary-cache* (make-hash-table)
  "Per-compilation cache for inferred Tier-2 summaries.")

(defun get-summary (function-name)
  "Get the summary for a function, checking Tier-2 then Tier-1."
  (or (gethash function-name *tier2-summary-cache*)
      (get-tier1-summary function-name)))

(defun infer-function-summary (fn-name params body)
  "Infer the usage summary for a single function.
  This is the core of the single-function analysis."
  (let ((param-usages (make-hash-table)))
    (dolist (p params) (setf (gethash p param-usages) :read-ok)) ; Start optimistically

    (labels ((walk (node)
               ;; A simplified walker that tracks parameter usage.
               ;; A real implementation would reuse the main uniqueness classifier.
               (cond
                 ((and (consp node) (symbolp (car node)))
                  (let ((callee (car node))
                        (args (cdr node)))
                    (let ((summary (get-summary callee)))
                      (loop for arg in args
                            for i from 0
                            do (when (symbolp arg)
                                 (let ((param-usage (get-param-usage-from-summary summary i)))
                                   ;; Update usage if it's more restrictive
                                   (when (is-more-restrictive-usage param-usage (gethash arg param-usages))
                                     (setf (gethash arg param-usages) param-usage))))))
                    (mapc #'walk args)))
                 (t ; handle other node types
                  nil))))
      (walk body))

    ;; Convert hash table to the final summary format
    (let ((summary `(:params ,@(loop for p in params collect (gethash p param-usages)))))
      summary)))

(defun analyze-scc (scc call-graph ast-map)
  "Analyze a Strongly Connected Component (SCC) of the call graph.
  Iterates to a fixpoint to handle mutual recursion."
  (let ((changed t))
    (loop while changed
          do (setf changed nil)
             (dolist (fn-name scc)
               (let* ((node (gethash fn-name ast-map))
                      (params (second node))
                      (body (cddr node))
                      (old-summary (gethash fn-name *tier2-summary-cache*
                                            ;; Start with most conservative assumption
                                            `(:params ,@(make-list (length params) :initial-element :retained))))
                      (new-summary (infer-function-summary fn-name params body)))
                 (unless (equal old-summary new-summary)
                   (setf (gethash fn-name *tier2-summary-cache*) new-summary
                         changed t)))))))

(defun build-call-graph (ast-map)
  "Build a simple call graph for all functions in the current compilation unit."
  (let ((graph (make-hash-table)))
    (maphash (lambda (fn-name ast)
               (let ((dependencies (make-hash-table :test 'equal)))
                 (labels ((walk (node)
                            (when (and (consp node) (symbolp (car node)) (gethash (car node) ast-map))
                              (setf (gethash (car node) dependencies) t))
                            (when (consp node) (mapc #'walk (cdr node)))))
                   (walk (cddr ast)))
                 (setf (gethash fn-name graph) (alexandria:hash-table-keys dependencies))))
             ast-map)
    graph))

(defun compute-sccs (graph)
  "Compute Strongly Connected Components of the call graph.
  A real implementation would use Tarjan's algorithm or similar."
  ;; Placeholder: treats each function as its own SCC if not recursive.
  (list (alexandria:hash-table-keys graph)))

(defun run-summary-inference-pass (file-ast-map)
  "Top-level entry point for the inter-procedural summary inference pass."
  ;; Clear cache for new compilation unit
  (clrhash *tier2-summary-cache*)

  ;; 1. Build call graph for the file
  (let ((call-graph (build-call-graph file-ast-map)))
    ;; 2. Compute SCCs
    (let ((sccs (compute-sccs call-graph)))
      ;; 3. Analyze SCCs in reverse topological order (simplified here)
      (dolist (scc (reverse sccs))
        (analyze-scc scc call-graph file-ast-map)))))

;;; Helper functions (placeholders)
(defun get-tier1-summary (fn-name)
  "Placeholder for getting a summary from the stdlib table."
  (gethash fn-name (load-time-value (alexandria:plist-hash-table '(:conj (:retained) :assoc (:retained)) :test 'eq))))

(defun get-param-usage-from-summary (summary index)
  "Placeholder for extracting param usage from a summary."
  (when summary
    (nth index (second summary))))

(defun is-more-restrictive-usage (usage1 usage2)
  "Placeholder for comparing usage lattice elements."
  (let ((lattice '(:read-ok :invoked :shared-with-result :retained)))
    (> (position usage1 lattice) (position usage2 lattice))))