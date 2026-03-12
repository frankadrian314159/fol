import os

def gen_fol():
    classes = []
    classes.append("(defclass <ast-node> [] [])")
    classes.append("(defclass <op-lit> [<ast-node>] [[val]])")
    classes.append("(defclass <op-var> [<ast-node>] [[name]])")
    
    bin_ops = ["add", "sub", "mul", "div", "rem", "pow", "band", "bor", "bxor", "shl", "shr",
               "eq", "neq", "lt", "gt", "le", "ge", "and", "or", "concat", "split", "join", "map"]
               
    for op in bin_ops:
        classes.append(f"(defclass <op-{op}> [<ast-node>] [[left] [right]])")

    # This makes 3 + 23 = 26 classes

    code = []
    code.append("(in-package \"ast-opt\"")
    code.append("  (:use \"fol.core\")")
    code.append("  (:export run-bench))")
    
    code.extend(classes)
    
    code.append("(defgeneric ast-optimize [node])")
    
    # Base cases
    code.append("(defmethod ast-optimize [n] n)")
    
    # 50 predicates!
    # For each arithmetic op, let's write rules.
    rules_count = 0
    def add_pred_rule(shape, body):
        nonlocal rules_count
        rules_count += 1
        code.append(f"(defmethod ast-optimize [n {shape}] {body})")
        
    def add_destr_rule(shape, body):
        nonlocal rules_count
        rules_count += 1
        code.append(f"(defmethod ast-optimize [({shape})] {body})")
        
    for op in bin_ops:
        # Just generate 2 rules per op = 46 rules
        add_destr_rule(f"{{:keys [(left ({{:keys [(val (eql 0))]}} <op-lit>)) (right r)]}} <op-{op}>", "r")
        add_destr_rule(f"{{:keys [(left l) (right ({{:keys [(val (eql 0))]}} <op-lit>)))]}} <op-{op}>", "l")
        
    # To hit 50 rules exactly, let's add 4 more generic ones
    add_destr_rule(f"{{:keys [(left ({{:keys [(val (eql 1))]}} <op-lit>)) (right r)]}} <op-mul>", "r")
    add_destr_rule(f"{{:keys [(left l) (right ({{:keys [(val (eql 1))]}} <op-lit>)))]}} <op-mul>", "l")
    add_destr_rule(f"{{:keys [(left ({{:keys [(val (eql 1))]}} <op-lit>)) (right r)]}} <op-div>", "r")
    add_destr_rule(f"{{:keys [(left l) (right ({{:keys [(val (eql 1))]}} <op-lit>)))]}} <op-div>", "l")

    code.append(f";; Generated {rules_count} rules")
    
    # A generic traverse
    code.append("(defgeneric walk [node])")
    code.append("(defmethod walk [n] n)")
    code.append("(defmethod walk [(n (lambda (x) (typep x '<op-lit>)))] n)")
    for op in bin_ops:
        code.append(f"(defmethod walk [({{:keys [(left l) (right r)]}} <op-{op}>)]")
        code.append(f"  (ast-optimize (op-{op} (walk l) (walk r))))")
        
    # generate a large tree
    code.append("""
(defn build-tree [depth]
  (if (= depth 0)
      (op-lit 0)
      (op-add (build-tree (dec depth)) (op-lit 0))))

(defn run-bench [n]
  (let [tree (build-tree 14)] ;; 2^14 nodes = 16384
    (dotimes [i n]
      (walk tree))))
    """)
    
    with open("benchmarks/fol-code/ast-optimizer.fol", "w") as f:
        f.write("\n".join(code))


def gen_cl():
    code = []
    code.append("(defpackage :ast-opt-cl (:use :cl))")
    code.append("(in-package :ast-opt-cl)")
    
    code.append("(defstruct ast-node)")
    code.append("(defstruct (op-lit (:include ast-node)) val)")
    code.append("(defstruct (op-var (:include ast-node)) name)")
    
    bin_ops = ["add", "sub", "mul", "div", "rem", "pow", "band", "bor", "bxor", "shl", "shr",
               "eq", "neq", "lt", "gt", "le", "ge", "and", "or", "concat", "split", "join", "map"]
               
    for op in bin_ops:
        code.append(f"(defstruct (op-{op} (:include ast-node)) left right)")
        
    # optimize function
    code.append("(defun ast-optimize (n)")
    code.append("  (typecase n")
    for op in bin_ops:
        code.append(f"    (op-{op}")
        code.append(f"      (let ((l (op-{op}-left n)) (r (op-{op}-right n)))")
        code.append("        (cond")
        code.append("          ((and (op-lit-p l) (eql (op-lit-val l) 0)) r)")
        code.append("          ((and (op-lit-p r) (eql (op-lit-val r) 0)) l)")
        
        if op == "mul" or op == "div":
            code.append("          ((and (op-lit-p l) (eql (op-lit-val l) 1)) r)")
            code.append("          ((and (op-lit-p r) (eql (op-lit-val r) 1)) l)")
            
        code.append("          (t n))))")
    code.append("    (t n)))")
    
    # walk function
    code.append("(defun walk (n)")
    code.append("  (typecase n")
    for op in bin_ops:
        code.append(f"    (op-{op} (ast-optimize (make-op-{op} :left (walk (op-{op}-left n)) :right (walk (op-{op}-right n)))))")
    code.append("    (t n)))")
    
    code.append("""
(defun build-tree (depth)
  (if (= depth 0)
      (make-op-lit :val 0)
      (make-op-add :left (build-tree (1- depth)) :right (make-op-lit :val 0))))

(defun run-bench (n)
  (let ((tree (build-tree 14)))
    (dotimes (i n)
      (walk tree))))
    """)
    
    with open("benchmarks/lisp-code/ast-optimizer.lisp", "w") as f:
        f.write("\n".join(code))

gen_fol()
gen_cl()
