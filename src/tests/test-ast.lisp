;;; FOL Compiler Tests - AST Node Tests

(in-package :fol.compiler.tests)

(in-suite ast-tests)

(test make-literal-node
  "Literal nodes store their value."
  (let ((node (fol.compiler.ast:make-literal-node :value 42)))
    (is (fol.compiler.ast:literal-node-p node))
    (is (eql 42 (fol.compiler.ast:literal-node-value node)))))

(test make-symbol-ref-node
  "Symbol reference nodes store a name."
  (let ((node (fol.compiler.ast:make-symbol-ref-node :name 'x)))
    (is (fol.compiler.ast:symbol-ref-node-p node))
    (is (eq 'x (fol.compiler.ast:symbol-ref-node-name node)))))

(test make-call-node
  "Call nodes store an operator and arguments."
  (let* ((op (fol.compiler.ast:make-symbol-ref-node :name '+))
         (a1 (fol.compiler.ast:make-literal-node :value 1))
         (a2 (fol.compiler.ast:make-literal-node :value 2))
         (node (fol.compiler.ast:make-call-node :operator op :args (list a1 a2))))
    (is (fol.compiler.ast:call-node-p node))
    (is (fol.compiler.ast:symbol-ref-node-p (fol.compiler.ast:call-node-operator node)))
    (is (= 2 (length (fol.compiler.ast:call-node-args node))))))

(test make-if-node
  "If nodes store test, then, and else branches."
  (let* ((test-node (fol.compiler.ast:make-literal-node :value t))
         (then-node (fol.compiler.ast:make-literal-node :value 1))
         (else-node (fol.compiler.ast:make-literal-node :value 2))
         (node (fol.compiler.ast:make-if-node
                :test test-node :then then-node :else else-node)))
    (is (fol.compiler.ast:if-node-p node))
    (is (fol.compiler.ast:literal-node-p (fol.compiler.ast:if-node-test node)))
    (is (fol.compiler.ast:literal-node-p (fol.compiler.ast:if-node-then node)))
    (is (fol.compiler.ast:literal-node-p (fol.compiler.ast:if-node-else node)))))

(test ast-node-inheritance
  "All node types are also ast-nodes."
  (is (fol.compiler.ast:ast-node-p
       (fol.compiler.ast:make-literal-node :value 42)))
  (is (fol.compiler.ast:ast-node-p
       (fol.compiler.ast:make-call-node :operator nil :args nil)))
  (is (fol.compiler.ast:ast-node-p
       (fol.compiler.ast:make-if-node :test nil :then nil :else nil)))
  (is (fol.compiler.ast:ast-node-p
       (fol.compiler.ast:make-do-node :body nil)))
  (is (fol.compiler.ast:ast-node-p
       (fol.compiler.ast:make-def-node :name nil :value nil))))
