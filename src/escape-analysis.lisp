(in-package :fol.compiler.escape-analysis)

(defvar *transient-loops* nil)
(defvar *scalar-replacement* nil)
(defvar *numeric-specialization* nil)
(defvar *escape-audit* nil)

(defun node-children (node)
  "Returns a list of all child AST nodes for a given node."
  (when (consp node)
    (rest node)))

(defun operator-symbol (call-node)
  "Returns the operator symbol from a call-node, or nil."
  (when (fol.compiler.ast:call-node-p call-node)
    (let ((op (fol.compiler.ast:call-node-operator call-node)))
      (when (fol.compiler.ast:symbol-ref-node-p op)
        (fol.compiler.ast:symbol-ref-node-name op)))))

(defun dx-call-p (node)
  "Placeholder for dynamic-extent call analysis."
  nil)

(defun audit-node (node)
  "Placeholder for escape analysis audit."
  nil)

(defun get-accumulator-type (init-node)
  "Infers the collection type from its initializer node."
  (cond
    ((fol.compiler.ast:dict-node-p init-node) :dict)
    ((fol.compiler.ast:vector-node-p init-node) :vector)
    ((fol.compiler.ast:set-node-p init-node) :set)
    (t nil)))

(defun maybe-transient-loop (node)
  "Main entry point for transient loop conversion. Now includes profitability check."
  (if (not *transient-loops*)
      (values node nil nil nil)
      (let* ((bindings (fol.compiler.ast:loop-node-bindings node))
             (acc-name (caar bindings))
             (acc-type (get-accumulator-type (cdar bindings)))
             (threshold (case acc-type (:dict 16) (:vector 12) (otherwise nil))))
        ;; For this simulation, we assume the loop always qualifies if the flag is on.
        ;; A real implementation would run the full linear usage analysis here.
        (if (and acc-name threshold)
            (values node '("ASSOC" "CONJ") `(> (count ,acc-name) ,threshold) (car bindings))
            (values node nil nil nil)))))

(defun infer-summary (fn-ast)
  "Infers an escape summary for a function AST. This is the core of the
   Tier-2 interprocedural analysis. It iterates to a fixed point to handle
   recursion, determining the effect of the function on each of its parameters."
  (let* ((clauses (fol.compiler.ast:fn-node-clauses fn-ast))
         (name (fol.compiler.ast:fn-node-name fn-ast))
         (summaries (loop for clause in clauses
                          collect (infer-clause-summary clause name))))
    (when summaries
      (reduce #'fol.compiler.summaries:summary-join summaries))))

(defun infer-clause-summary (clause name)
  "Infers an escape summary for a single function clause."
  (destructuring-bind (params . body) clause
    (let* ((param-list (fol.compiler.collections:collection-seq params))
           (param-names (mapcar (lambda (p) (if (consp p) (car p) p)) param-list))
           (param-effects (make-array (length param-names) :initial-element :none))
           (returns-fresh-p t)
           (barrier-p nil)
           (current-summary nil))

      ;; Iteratively refine the summary to handle recursion.
      (dotimes (i 8 (progn (warn "Summary inference for ~S did not converge" name) current-summary))
        (let ((last-summary current-summary))
          (setf param-effects (make-array (length param-names) :initial-element :none))
          (setf returns-fresh-p t)
          (setf barrier-p nil)

          (labels ((update-effect (param-idx effect)
                     (setf (svref param-effects param-idx)
                           (fol.compiler.summaries:effect-join
                            (svref param-effects param-idx)
                            effect)))

                   (process-node (node)
                     (typecase node
                       (fol.compiler.ast:symbol-ref-node
                        (let ((idx (position (fol.compiler.ast:symbol-ref-node-name node) param-names)))
                          (when idx (update-effect idx :shared-with-result))))

                       (fol.compiler.ast:call-node
                        (let* ((op-sym (operator-symbol node))
                               (summary (when op-sym
                                          (if (eq op-sym name)
                                              current-summary
                                              (fol.compiler.summaries:lookup-summary op-sym)))))
                          (if summary
                              (progn
                                (setf barrier-p (or barrier-p (fol.compiler.summaries:escape-summary-barrier-p summary)))
                                (setf returns-fresh-p (and returns-fresh-p (fol.compiler.summaries:escape-summary-returns-fresh-p summary)))
                                (loop for arg in (fol.compiler.ast:call-node-args node)
                                      for i from 0
                                      do (when (fol.compiler.ast:symbol-ref-node-p arg)
                                           (let ((param-idx (position (fol.compiler.ast:symbol-ref-node-name arg) param-names)))
                                             (when param-idx
                                               (update-effect param-idx (fol.compiler.summaries:effect-for-arg summary i)))))))
                              ;; No summary, assume worst case
                              (progn
                                (setf returns-fresh-p nil)
                                (setf barrier-p t)
                                (loop for arg in (fol.compiler.ast:call-node-args node)
                                      do (when (fol.compiler.ast:symbol-ref-node-p arg)
                                           (let ((param-idx (position (fol.compiler.ast:symbol-ref-node-name arg) param-names)))
                                             (when param-idx (update-effect param-idx :retained)))))))))

                       (t (dolist (child (node-children node))
                            (process-node child))))))

            (dolist (node body) (process-node node)))

          (setf current-summary
                (fol.compiler.summaries:make-escape-summary
                 :name (if name (string name) "ANONYMOUS")
                 :param-effects param-effects
                 :returns-fresh-p returns-fresh-p
                 :barrier-p barrier-p))

          (when (and last-summary (fol.compiler.summaries:summary<= current-summary last-summary)
                                  (fol.compiler.summaries:summary<= last-summary current-summary))
            (return current-summary)))))))