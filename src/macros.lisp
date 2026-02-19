;;; FOL Macros - Clojure-style Macros
;;;
;;; Provides macro implementations of common Clojure control flow,
;;; binding, threading, and utility macros.
;;;
;;; These are FOL-level macros that expand during FOL compilation.

(in-package :fol.macros)

;;; ===========================================================================
;;; Conditional Macros
;;; ===========================================================================

(defmacro when (test &body body)
  "Evaluates test. If logical true, evaluates body in an implicit do."
  `(if ,test (do ,@body)))

(defmacro when-not (test &body body)
  "Evaluates test. If logical false, evaluates body in an implicit do."
  `(if ,test nil (do ,@body)))

(defmacro if-not (test then &optional else)
  "Evaluates test. If logical false, evaluates then; otherwise evaluates else."
  `(if ,test ,else ,then))

; (defmacro cond (&rest clauses)
;   "Takes a set of test/expr pairs. Evaluates each test one at a time.
;    If a test returns logical true, cond evaluates and returns the value
;    of the corresponding expr and doesn't evaluate any of the other tests
;    or exprs. If no test returns true, returns nil."
;   (cl:when clauses
;     (let ((clause (first clauses)))
;       (destructuring-bind (test expr) clause
;         `(if ,test
;              ,expr
;              ,(cl:when (rest clauses)
;                 `(cond ,@(rest clauses))))))))

; (defmacro case (expr &rest clauses)
;   "Takes an expression and a set of value/expr pairs.
;    Compares expr (an evaluated expression) to each value (unevaluated constants).
;    If they match, evaluates corresponding expr. If no clause matches,
;    evaluates the default clause (marked with :default or :else), or returns nil."
;   (let ((g (gensym "CASE-EXPR-"))
;         (result nil))
;     (loop for clause-pair on clauses by #'cddr
;           for value = (first clause-pair)
;           for body = (second clause-pair)
;           do (cond
;               ((or (eq value :default) (eq value :else))
;                 (setf result body))
;               (t
;                 (setf result `(if (=? ,g ,value) ,body ,result)))))
;     `(bind ,(list g expr) ,result)))

(defmacro condp (pred expr &rest clauses)
  "Takes a binary predicate, an expression, and a set of value/result pairs.
   Evaluates each value one at a time. If (pred value expr) returns logical true,
   condp evaluates and returns the corresponding result expression.
   A single default value can follow the clauses."
  (let ((gpred (gensym "PRED-"))
        (gexpr (gensym "EXPR-")))
    (labels ((build-condp (clauses)
                          (cond
                           ((null clauses) nil)
                           ((null (rest clauses))
                             (first clauses))
                           (t
                             (let ((test-val (first clauses))
                                   (result (second clauses)))
                               `(if (,gpred ,test-val ,gexpr)
                                    ,result
                                    ,(build-condp (cddr clauses))))))))
      `(bind ,(list gpred pred gexpr expr) ,(build-condp clauses)))))

;;; ===========================================================================
;;; Binding Macros
;;; ===========================================================================

(defmacro when-let (bindings &body body)
  "Evaluates test. If logical true, binds it to binding and evaluates body in implicit do."
  (destructuring-bind (binding test) (ensure-list bindings)
    `(bind ,(list binding test)
           (when ,binding ,@body))))

(defmacro if-let (bindings then &optional else)
  "Evaluates test. If logical true, binds it to binding and evaluates then;
   otherwise evaluates else."
  (destructuring-bind (binding test) (ensure-list bindings)
    `(bind ,(list binding test)
           (if ,binding ,then ,else))))

(defmacro when-some (bindings &body body)
  "Like when-let, but specifically checks that binding is not nil (using some?)."
  (destructuring-bind (binding test) (ensure-list bindings)
    (let ((g (gensym "SOME-")))
      `(bind ,(list g test)
             (when (fol.compiler.primitive-functions:some? ,g)
                   (bind ,(list binding g) ,@body))))))

(defmacro if-some (bindings then &optional else)
  "Like if-let, but specifically checks that binding is not nil (using some?)."
  (destructuring-bind (binding test) (ensure-list bindings)
    (let ((g (gensym "SOME-")))
      `(bind ,(list g test)
             (if (fol.compiler.primitive-functions:some? ,g)
                 (bind ,(list binding g) ,then)
                 ,else)))))

(defmacro when-first (bindings &body body)
  "Binds the first element of a sequence to binding and evaluates body if sequence is non-empty."
  (destructuring-bind (binding seq-expr) (ensure-list bindings)
    (let ((s (gensym "SEQ-")))
      `(bind ,(list s `(seq ,seq-expr))
             (when ,s
                   (bind ,(list binding `(first ,s))
                         ,@body))))))

;;; ===========================================================================
;;; Loop Macros
;;; ===========================================================================

(defmacro while (test &body body)
  "Repeatedly executes body while test expression is true."
  (let ((loop-name (gensym "WHILE-")))
    `(loop ,(vector loop-name nil)
           (when ,test ,@body (recur nil)))))

(defmacro dotimes (bindings &body body)
  "Executes body n times where n is an integer expression.
   bindings is [name n], where name is bound to integers from 0 to n-1."
  (destructuring-bind (name n) (ensure-list bindings)
    (let ((max (gensym "MAX-"))
          (i (gensym "I-")))
      `(bind ,(vector max n)
             (loop ,(vector i 0)
                   (when (< ,i ,max)
                         (bind ,(vector name i)
                               ,@body
                               (recur (inc ,i)))))))))

(defmacro doseq (bindings &body body)
  "Executes body for each element in a sequence.
   bindings is [name seq-expr], where name is bound to each element."
  (destructuring-bind (name seq-expr) (ensure-list bindings)
    (let ((s (gensym "SEQ-")))
      `(loop ,(vector s `(seq ,seq-expr))
             (when ,s
                   (bind ,(vector name `(first ,s))
                         ,@body
                         (recur (rest ,s))))))))

(defmacro for (bindings &body body)
  "List comprehension. Takes a binding form [name seq-expr] and a body.
   Returns a lazy sequence of the results of evaluating body for each element.
   Currently returns an eager vector (lazy-seq not yet implemented)."
  (destructuring-bind (name seq-expr) (ensure-list bindings)
    (let ((result (gensym "RESULT-"))
          (s (gensym "SEQ-"))
          (item (gensym "ITEM-")))
      `(bind ,(list result '(fol.compiler.collection-functions:vector))
             (loop ,(fol.compiler.collection-functions:vector
                     s `(fol.compiler.collection-functions:vec ,seq-expr)
                     result result)
                   (if ,s
                       (do
                        (bind ,(list item `(first ,s))
                              (bind ,(list name item)
                                    (recur (rest ,s)
                                           (conj ,result (do ,@body))))))
                       ,result))))))

;;; ===========================================================================
;;; Threading Macros
;;; ===========================================================================

(defmacro -> (x &rest forms)
  "Thread-first macro. Threads x through forms by inserting it as the
   second item in the first form, making the result the second item in
   the second form, etc."
  (if (null forms)
      x
      (let ((result x))
        (dolist (form forms result)
          (setf result
            (if (consp form)
                `(,(first form) ,result ,@(rest form))
                `(,form ,result)))))))

(defmacro ->> (x &rest forms)
  "Thread-last macro. Threads x through forms by inserting it as the
   last item in each form."
  (if (null forms)
      x
      (let ((result x))
        (dolist (form forms result)
          (setf result
            (if (consp form)
                `(,(first form) ,@(rest form) ,result)
                `(,form ,result)))))))

(defmacro as-> (expr name &rest forms)
  "Thread as named binding. Binds name to expr, then to the result of
   each form in sequence."
  (if (null forms)
      expr
      (let ((result expr))
        (dolist (form forms)
          (setf result `(bind ,(list name result) ,form)))
        result)))

(defmacro cond-> (expr &rest clauses)
  "Conditional thread-first. Takes an expression and a set of test/form pairs.
   Threads expr through each form for which the corresponding test is true."
  (let ((g (gensym "EXPR-"))
        (result expr))
    (loop for (test form) on clauses by #'cddr
          do (let ((threaded (if (consp form)
                                 `(,(first form) ,g ,@(rest form))
                                 `(,form ,g))))
               (setf result
                 `(bind ,(list g result)
                        (if ,test ,threaded ,g)))))
    result))

(defmacro cond->> (expr &rest clauses)
  "Conditional thread-last. Takes an expression and a set of test/form pairs.
   Threads expr through each form (as last arg) for which the corresponding test is true."
  (let ((g (gensym "EXPR-"))
        (result expr))
    (loop for (test form) on clauses by #'cddr
          do (let ((threaded (if (consp form)
                                 `(,(first form) ,@(rest form) ,g)
                                 `(,form ,g))))
               (setf result
                 `(bind ,(list g result)
                        (if ,test ,threaded ,g)))))
    result))

(defmacro some-> (expr &rest forms)
  "Nil-safe thread-first. Like ->, but returns nil as soon as any intermediate
   result is nil."
  (if (null forms)
      expr
      (let ((g (gensym "EXPR-"))
            (result expr))
        (dolist (form forms)
          (let ((threaded (if (consp form)
                              `(,(first form) ,g ,@(rest form))
                              `(,form ,g))))
            (setf result
              `(bind ,(list g result)
                     (when (fol.compiler.primitive-functions:some? ,g) ,threaded)))))
        result)))

(defmacro some->> (expr &rest forms)
  "Nil-safe thread-last. Like ->>, but returns nil as soon as any intermediate
   result is nil."
  (if (null forms)
      expr
      (let ((g (gensym "EXPR-"))
            (result expr))
        (dolist (form forms)
          (let ((threaded (if (consp form)
                              `(,(first form) ,@(rest form) ,g)
                              `(,form ,g))))
            (setf result
              `(bind ,(list g result)
                     (when (fol.compiler.primitive-functions:some? ,g) ,threaded)))))
        result)))

;;; Helper to convert bindings to list
(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun ensure-list (x)
    (cond
     ((listp x) x)
     ((vectorp x) (coerce x 'list))
     ((typep x 'fol.compiler.collections:<collection>)
       (fol.compiler.collections:collection-seq x))
     ;; Fallback: try to treat as collection if standard-object
     ((typep x 'standard-object)
       (handler-case
           (fol.compiler.collections:collection-seq x)
         (error (e)
           (error "ensure-list failed on standard-object ~S: ~A" x e))))
     (t (error "ensure-list: Expected a sequence, got ~S of type ~S" x (type-of x))))))

;;; ===========================================================================
;;; Dynamic Binding Macros
;;; ===========================================================================

;;; binding is a special form in the compiler, so no macro needed here.

(defmacro with-redefs (bindings &body body)
  "Temporarily redeclares Vars during the scope of body.
   bindings is a vector of [var value ...] pairs.
   Note: This is a simplified version that uses let binding."
  `(binding ,bindings ,@body))

(defmacro with-redefs-fn (bindings-fn &body body)
  "Like with-redefs but takes a function that returns the bindings map."
  (let ((bindings-var (gensym "BINDINGS-")))
    `(bind ,(list bindings-var `(,bindings-fn))
           (with-redefs ,bindings-var ,@body))))

;;; ===========================================================================
;;; Resource Management Macros
;;; ===========================================================================

(defmacro with-open (bindings &body body)
  "Evaluates body in a try expression with bindings (like let), and ensures
   that close is called on each binding at the end.
   Bindings are ((var expr) ...) like CL let."
  (if (null bindings)
      `(progn ,@body)
      (destructuring-bind (var expr) (first bindings)
        `(let ((,var ,expr))
           (unwind-protect
               (with-open ,(rest bindings) ,@body)
             (stream-close ,var))))))

(defmacro with-in-str (s &body body)
  "Evaluates body with *in* bound to a fresh string input stream initialized with string s."
  (let ((stream (gensym "STREAM-")))
    `(let ((,stream (fol.compiler.streams:string-input-stream ,s)))
       (let ((fol.compiler.streams:*in* ,stream))
         ,@body))))

(defmacro with-out-str (&body body)
  "Evaluates body with *out* bound to a fresh string output stream.
   Returns the string created by any output during body."
  (let ((stream (gensym "STREAM-")))
    `(let ((,stream (fol.compiler.streams:string-output-stream)))
       (let ((fol.compiler.streams:*out* ,stream))
         ,@body
         (fol.compiler.streams:get-output-string ,stream)))))

(defmacro with-precision (precision &body body)
  "Sets the precision for floating point operations within body.
   Note: This is a stub implementation."
  (declare (ignore precision))
  `(progn ,@body))

(defmacro with-local-vars (bindings &body body)
  "Creates local mutable variables for use within body.
   bindings is a list of [name initial-value ...] pairs."
  (let ((pairs (loop for (var val) on (coerce bindings 'list) by #'cddr
                     collect (list var val))))
    `(bind ,(apply #'list (mapcan (lambda (pair) (list (first pair) `(atom ,(second pair)))) pairs))
           ,@body)))

;;; ===========================================================================
;;; Utility Macros
;;; ===========================================================================

(defmacro time (&body body)
  "Evaluates body, prints the time it took to execute, and returns the result."
  (let ((start (gensym "START-"))
        (result (gensym "RESULT-"))
        (end (gensym "END-")))
    `(bind ,(list start '(cl:get-internal-real-time))
           (bind ,(list result `(do ,@body))
                 (bind ,(list end '(cl:get-internal-real-time))
                       (cl:format t "Elapsed time: ~,3f ms~%"
                         (cl:* (cl:/ (cl:- ,end ,start)
                                 cl:internal-time-units-per-second)
                           1000.0))
                       ,result)))))

(defmacro comment (&rest _)
  "Ignores body and returns nil. Used for commenting out forms."
  (declare (ignore _))
  nil)

(defmacro assert (test &optional message)
  "Evaluates test. If logical false, throws an error with optional message."
  (if message
      `(cl:when (cl:not (truthy? ,test))
         (error ,message))
      `(cl:when (cl:not (truthy? ,test))
         (error "Assertion failed: ~S" ',test))))

(defmacro doc (name)
  "Returns the documentation string for name (looks up metadata).
   Expands to a call to the doc function."
  `(fol.compiler.metadata:doc ',name))

(defmacro lazy-cat (&rest colls)
  "Returns a lazy sequence representing the concatenation of colls.
   Note: This is an eager implementation using apply/concat.
   Requires concat to be implemented."
  `(concat ,@colls))

(defmacro delay (&body body)
  "Creates a delay object that will evaluate body on first deref.
   Note: Requires delay support in mutable.lisp."
  `(<delay> (fol.compiler:fn ,(fol.compiler.collection-functions:vector) ,@body)))

;;; ===========================================================================
;;; Register Macros
;;; ===========================================================================

;; Register all macros in the FOL macro system
;; Each expander uses macro-function to get the expander function
(eval-when (:load-toplevel :execute)
  (fol.compiler:register-macro 'when (macro-function 'when))
  (fol.compiler:register-macro 'when-not (macro-function 'when-not))
  (fol.compiler:register-macro 'if-not (macro-function 'if-not))
  (fol.compiler:register-macro 'cond (macro-function 'cond))
  (fol.compiler:register-macro 'case (macro-function 'case))
  (fol.compiler:register-macro 'condp (macro-function 'condp))
  (fol.compiler:register-macro 'when-let (macro-function 'when-let))
  (fol.compiler:register-macro 'if-let (macro-function 'if-let))
  (fol.compiler:register-macro 'when-some (macro-function 'when-some))
  (fol.compiler:register-macro 'if-some (macro-function 'if-some))
  (fol.compiler:register-macro 'when-first (macro-function 'when-first))
  (fol.compiler:register-macro 'while (macro-function 'while))
  (fol.compiler:register-macro 'dotimes (macro-function 'dotimes))
  (fol.compiler:register-macro 'doseq (macro-function 'doseq))
  (fol.compiler:register-macro 'for (macro-function 'for))
  (fol.compiler:register-macro '-> (macro-function '->))
  (fol.compiler:register-macro '->> (macro-function '->>))
  (fol.compiler:register-macro 'as-> (macro-function 'as->))
  (fol.compiler:register-macro 'cond-> (macro-function 'cond->))
  (fol.compiler:register-macro 'cond->> (macro-function 'cond->>))
  (fol.compiler:register-macro 'some-> (macro-function 'some->))
  (fol.compiler:register-macro 'some->> (macro-function 'some->>))
  (fol.compiler:register-macro 'with-redefs (macro-function 'with-redefs))
  (fol.compiler:register-macro 'with-redefs-fn (macro-function 'with-redefs-fn))
  (fol.compiler:register-macro 'with-open (macro-function 'with-open))
  (fol.compiler:register-macro 'with-in-str (macro-function 'with-in-str))
  (fol.compiler:register-macro 'with-out-str (macro-function 'with-out-str))
  (fol.compiler:register-macro 'with-precision (macro-function 'with-precision))
  (fol.compiler:register-macro 'with-local-vars (macro-function 'with-local-vars))
  (fol.compiler:register-macro 'time (macro-function 'time))
  (fol.compiler:register-macro 'comment (macro-function 'comment))
  (fol.compiler:register-macro 'assert (macro-function 'assert))
  (fol.compiler:register-macro 'doc (macro-function 'doc))
  (fol.compiler:register-macro 'lazy-cat (macro-function 'lazy-cat))
  (fol.compiler:register-macro 'delay (macro-function 'delay)))
