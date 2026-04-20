;;; =============================================================================
;;; Expression Interpreter — Adoption Cost Benchmark (Common Lisp baseline)
;;; Standard CLOS class hierarchy, generic-function dispatch, mutable hash-table
;;; environment.  Corresponds to fol-code/interpreter.fol.
;;;
;;; This benchmark is designed to answer the reviewer question:
;;;   "What is the adoption cost of porting a typical CLOS codebase to FOL?"
;;;
;;; Unlike the AST-optimizer benchmark (which uses defstruct, the fastest CL
;;; baseline), this file uses standard CLOS throughout — the realistic starting
;;; point for a practitioner who wants to adopt FOL.
;;; =============================================================================

(defpackage :interp-cl
  (:use :cl)
  (:export #:run-bench #:build-corpus))

(in-package :interp-cl)

;;; ---------------------------------------------------------------------------
;;; AST class hierarchy: 7 node types, standard mutable CLOS
;;; ---------------------------------------------------------------------------

(defclass expr () ())

(defclass num-expr (expr)
  ((val  :initarg :val  :reader num-val)))

(defclass var-expr (expr)
  ((name :initarg :name :reader var-name)))

(defclass add-expr (expr)
  ((left  :initarg :left  :reader add-left)
   (right :initarg :right :reader add-right)))

(defclass mul-expr (expr)
  ((left  :initarg :left  :reader mul-left)
   (right :initarg :right :reader mul-right)))

;;; let-expr: (let [bvar bval] body)
(defclass let-expr (expr)
  ((bvar :initarg :bvar :reader let-bvar)   ; keyword symbol naming the variable
   (bval :initarg :bval :reader let-bval)   ; expression producing the value
   (body :initarg :body :reader let-body))) ; expression using the variable

;;; if-expr: (if test consequent alternate)
(defclass if-expr (expr)
  ((test       :initarg :test       :reader if-test)
   (consequent :initarg :consequent :reader if-consequent)
   (alternate  :initarg :alternate  :reader if-alternate)))

(defclass neg-expr (expr)
  ((arg :initarg :arg :reader neg-arg)))

;;; ---------------------------------------------------------------------------
;;; eval-expr — evaluates an expression in a mutable hash-table environment
;;;
;;; let-expr uses the idiomatic CL shadow-and-restore pattern: mutate the
;;; hash-table in place to add the binding, recurse, then restore the old value.
;;; This is O(1) per binding vs. O(N) for copy-hash-table.
;;; ---------------------------------------------------------------------------

(defgeneric eval-expr (expr env))

(defmethod eval-expr ((e num-expr) env)
  (declare (ignore env))
  (num-val e))

(defmethod eval-expr ((e var-expr) env)
  (gethash (var-name e) env 0))

(defmethod eval-expr ((e add-expr) env)
  (+ (eval-expr (add-left  e) env)
     (eval-expr (add-right e) env)))

(defmethod eval-expr ((e mul-expr) env)
  (* (eval-expr (mul-left  e) env)
     (eval-expr (mul-right e) env)))

(defmethod eval-expr ((e let-expr) env)
  ;; Shadow-and-restore: mutate the env hash-table, recurse, undo.
  (let* ((var (let-bvar e))
         (v   (eval-expr (let-bval e) env))
         (old (multiple-value-list (gethash var env))))
    (setf (gethash var env) v)
    (prog1 (eval-expr (let-body e) env)
      (if (second old)
          (setf (gethash var env) (first old))
          (remhash var env)))))

(defmethod eval-expr ((e if-expr) env)
  (if (zerop (eval-expr (if-test e) env))
      (eval-expr (if-alternate  e) env)
      (eval-expr (if-consequent e) env)))

(defmethod eval-expr ((e neg-expr) env)
  (- (eval-expr (neg-arg e) env)))

;;; ---------------------------------------------------------------------------
;;; pretty — pretty-prints an expression to a string (second generic function)
;;; ---------------------------------------------------------------------------

(defgeneric pretty (expr))

(defmethod pretty ((e num-expr))
  (write-to-string (num-val e)))

(defmethod pretty ((e var-expr))
  (symbol-name (var-name e)))

(defmethod pretty ((e add-expr))
  (concatenate 'string "(+ " (pretty (add-left e)) " " (pretty (add-right e)) ")"))

(defmethod pretty ((e mul-expr))
  (concatenate 'string "(* " (pretty (mul-left e)) " " (pretty (mul-right e)) ")"))

(defmethod pretty ((e let-expr))
  (concatenate 'string
               "(let [" (symbol-name (let-bvar e)) " "
               (pretty (let-bval e)) "] "
               (pretty (let-body e)) ")"))

(defmethod pretty ((e if-expr))
  (concatenate 'string
               "(if " (pretty (if-test e)) " "
               (pretty (if-consequent e)) " "
               (pretty (if-alternate  e)) ")"))

(defmethod pretty ((e neg-expr))
  (concatenate 'string "(- " (pretty (neg-arg e)) ")"))

;;; ---------------------------------------------------------------------------
;;; free-vars — returns a list of free variable names (third generic function)
;;; Demonstrates "new operation" extensibility: this method was added later
;;; without modifying any class definitions.
;;; ---------------------------------------------------------------------------

(defgeneric free-vars (expr bound))

(defmethod free-vars ((e num-expr) bound)
  (declare (ignore bound))
  nil)

(defmethod free-vars ((e var-expr) bound)
  (unless (member (var-name e) bound) (list (var-name e))))

(defmethod free-vars ((e add-expr) bound)
  (union (free-vars (add-left  e) bound)
         (free-vars (add-right e) bound)))

(defmethod free-vars ((e mul-expr) bound)
  (union (free-vars (mul-left  e) bound)
         (free-vars (mul-right e) bound)))

(defmethod free-vars ((e let-expr) bound)
  (union (free-vars (let-bval e) bound)
         (free-vars (let-body e) (cons (let-bvar e) bound))))

(defmethod free-vars ((e if-expr) bound)
  (union (free-vars (if-test       e) bound)
         (union (free-vars (if-consequent e) bound)
                (free-vars (if-alternate  e) bound))))

(defmethod free-vars ((e neg-expr) bound)
  (free-vars (neg-arg e) bound))

;;; ---------------------------------------------------------------------------
;;; Benchmark infrastructure
;;; ---------------------------------------------------------------------------

(defun make-env (&rest pairs)
  (let ((ht (make-hash-table)))
    (loop for (k v) on pairs by #'cddr
          do (setf (gethash k ht) v))
    ht))

(defun build-expr (depth idx)
  "Build an expression tree of DEPTH levels.  IDX seeds the node-type cycle so
   that a corpus of 50 trees covers all 7 node types in realistic proportions."
  (if (<= depth 0)
      (if (evenp idx)
          (make-instance 'num-expr :val (mod idx 5))
          (make-instance 'var-expr
                         :name (case (mod idx 3)
                                 (0 :x) (1 :y) (t :z))))
      (let ((m (mod idx 5)))
        (if (= m 4)
            ;; neg-expr: single child
            (make-instance 'neg-expr
                           :arg (build-expr (1- depth) (* idx 2)))
            ;; all other node types: two children
            (let ((l (build-expr (1- depth) (* idx 2)))
                  (r (build-expr (1- depth) (1+ (* idx 2)))))
              (case m
                (0 (make-instance 'add-expr :left l :right r))
                (1 (make-instance 'mul-expr :left l :right r))
                (2 (make-instance 'let-expr :bvar :x :bval l :body r))
                (t (make-instance 'if-expr
                                  :test       (make-instance 'var-expr :name :x)
                                  :consequent l
                                  :alternate  r))))))))

(defun build-corpus (size depth)
  (loop for i from 0 below size collect (build-expr depth i)))

(defun run-bench (n)
  "N iterations over a 50-expression corpus of depth-5 trees.
   Each iteration calls eval-expr, pretty, and free-vars on every expression."
  (let ((corpus (build-corpus 50 5))
        (env    (make-env :x 3 :y 5 :z 2)))
    (dotimes (_ n)
      (dolist (expr corpus)
        (eval-expr  expr env)
        (pretty     expr)
        (free-vars  expr nil)))))
