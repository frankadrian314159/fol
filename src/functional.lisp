;;; FOL Compiler - Functional Operations
;;;
;;; Provides Clojure-style higher-order function utilities:
;;; identity, constantly, comp, complement, partial, juxt,
;;; memoize, fnil, every-pred, some-fn, apply, trampoline.

(in-package :fol.compiler.functional)

;;; ============================================================================
;;; Core Functions
;;; ============================================================================

(defun identity (x)
  "Returns its argument unchanged.

   Examples:
     (identity 42)       => 42
     (identity nil)      => NIL
     (identity \"hello\") => \"hello\""
  x)

(defun constantly (x)
  "Returns a function that always returns X, regardless of arguments.

   Examples:
     (funcall (constantly 42))       => 42
     (funcall (constantly 42) 1 2 3) => 42"
  (lambda (&rest args)
    (declare (ignore args))
    x))

(defun comp (&rest fns)
  "Returns a function that is the composition of FNS, right to left.
   The rightmost function can take any number of arguments; the rest
   take exactly one argument. With no arguments, returns identity.

   Examples:
     (funcall (comp inc inc) 0)           => 2
     (funcall (comp str inc) 42)          => \"43\"
     (funcall (comp) 42)                  => 42"
  (cond
    ((null fns) #'cl:identity)
    ((null (cdr fns)) (car fns))
    (t (let ((f (car fns))
             (g (cl:apply #'comp (cdr fns))))
         (lambda (&rest args)
           (funcall f (cl:apply g args)))))))

(defun complement (f)
  "Returns a function that takes the same arguments as F and returns
   the logical opposite of what F would return.

   Examples:
     (funcall (complement odd?) 2)  => T
     (funcall (complement odd?) 3)  => NIL"
  (lambda (&rest args)
    (not (cl:apply f args))))

(defun partial (f &rest bound-args)
  "Returns a function that calls F with BOUND-ARGS prepended to
   whatever arguments it receives.

   Examples:
     (funcall (partial + 10) 5)       => 15
     (funcall (partial + 10 20) 5)    => 35"
  (lambda (&rest args)
    (cl:apply f (append bound-args args))))

(defun juxt (&rest fns)
  "Returns a function that applies each of FNS to its arguments,
   returning a CL list of results.

   Examples:
     (funcall (juxt inc dec) 5)         => (6 4)
     (funcall (juxt first rest) '(1 2 3)) => (1 (2 3))"
  (lambda (&rest args)
    (mapcar (lambda (f) (cl:apply f args)) fns)))

;;; ============================================================================
;;; Memoization and Caching
;;; ============================================================================

(defun memoize (f)
  "Returns a memoized version of F. Results are cached using EQUAL
   comparison on the argument list.

   Examples:
     (def mf (memoize (fn [x] (* x x))))
     (funcall mf 5) => 25 (computed)
     (funcall mf 5) => 25 (cached)"
  (let ((cache (make-hash-table :test 'equal)))
    (lambda (&rest args)
      (multiple-value-bind (val found) (gethash args cache)
        (if found
            val
            (setf (gethash args cache) (cl:apply f args)))))))

(defun fnil (f &rest defaults)
  "Returns a function that calls F, replacing nil arguments with
   corresponding values from DEFAULTS. Extra arguments beyond
   DEFAULTS are passed through unchanged.

   Examples:
     (funcall (fnil + 0 0) nil 5)   => 5
     (funcall (fnil + 0 0) 3 nil)   => 3
     (funcall (fnil str \"N/A\") nil) => \"N/A\""
  (lambda (&rest args)
    (cl:apply f (let ((defs defaults))
                  (loop for arg in args
                        for default = (pop defs)
                        collect (if arg arg default))))))

;;; ============================================================================
;;; Predicate Combinators
;;; ============================================================================

(defun every-pred (&rest preds)
  "Returns a function that returns true when all PREDS return true
   for every argument passed to it.

   Examples:
     (funcall (every-pred number? positive?) 5)     => T
     (funcall (every-pred number? positive?) -1)    => NIL
     (funcall (every-pred number? positive?) 5 3 1) => T"
  (lambda (&rest args)
    (cl:every (lambda (pred)
                (cl:every (lambda (arg)
                            (funcall pred arg))
                          args))
              preds)))

(defun some-fn (&rest fns)
  "Returns a function that returns the first truthy value produced by
   applying any of FNS to any of its arguments.

   Examples:
     (funcall (some-fn even? odd?) 3)         => T
     (funcall (some-fn even? odd?) 2)         => T"
  (lambda (&rest args)
    (cl:some (lambda (f)
               (cl:some (lambda (arg)
                          (funcall f arg))
                        args))
             fns)))

;;; ============================================================================
;;; Application
;;; ============================================================================

(defun apply (f &rest args)
  "Applies F to the arguments. The last argument must be a sequence
   which is spread as individual arguments. Like CL apply.

   Examples:
     (apply + 1 2 '(3 4))  => 10
     (apply + '(1 2 3))    => 6"
  (cl:apply #'cl:apply f args))

(defun trampoline (f &rest args)
  "Calls F with ARGS, then repeatedly calls the result as long as
   it is a function. Returns the first non-function result. Use for
   mutual recursion without stack overflow.

   Examples:
     (trampoline (fn [] (fn [] (fn [] 42))))  => 42
     (trampoline + 1 2 3)                     => 6"
  (let ((result (cl:apply f args)))
    (loop while (functionp result)
          do (setf result (funcall result)))
    result))
