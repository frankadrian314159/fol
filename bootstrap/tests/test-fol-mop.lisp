(in-package :fol.tests)

(def-suite fol-mop-suite :in fol-suite)
(def-suite* :fol.fol-mop-tests :in fol-mop-suite)

;;; ============================================================================
;;; Helper Function Tests
;;; ============================================================================

(test vector-to-list-converts-fol-vectors
  "Test that vector-to-list converts FOL vectors to CL lists."
  (let ((vec (make-vector 1 2 3)))
    (is (equal '(1 2 3) (vector-to-list vec))))
  (let ((vec (make-vector 'a 'b 'c)))
    (is (equal '(a b c) (vector-to-list vec)))))

(test vector-to-list-returns-non-vectors-unchanged
  "Test that vector-to-list returns non-vectors unchanged."
  (is (eq 42 (vector-to-list 42)))
  (is (eq 'foo (vector-to-list 'foo)))
  (is (equal '(1 2 3) (vector-to-list '(1 2 3)))))

(test convert-slot-specifier-handles-symbols
  "Test that convert-slot-specifier handles simple symbol slot names."
  (is (eq 'x (convert-slot-specifier 'x)))
  (is (eq 'my-slot (convert-slot-specifier 'my-slot))))

(test convert-slot-specifier-handles-vectors
  "Test that convert-slot-specifier converts vector slot specs to lists."
  (let ((slot-spec (make-vector 'x :initarg :x :accessor 'point-x)))
    (is (listp (convert-slot-specifier slot-spec)))
    (is (eq 'x (first (convert-slot-specifier slot-spec))))))

(test convert-specialized-param-handles-symbols
  "Test that convert-specialized-param handles unspecialized params."
  (is (eq 'x (convert-specialized-param 'x)))
  (is (eq 'obj (convert-specialized-param 'obj))))

(test convert-specialized-param-passes-through-lists
  "Test that convert-specialized-param passes through list specializers unchanged.
   Type specialization uses list syntax: (var type)."
  (let ((param '(a <point>)))
    (is (listp (convert-specialized-param param)))
    (is (eq 'a (first (convert-specialized-param param))))
    (is (eq '<point> (second (convert-specialized-param param))))))

;;; ============================================================================
;;; defgeneric* Macro Tests
;;; ============================================================================

(test defgeneric*-creates-generic-function
  "Test that defgeneric* creates a generic function."
  (eval `(fol.fol-mop:defgeneric* test-generic-fn ,(make-vector 'a 'b)))
  (is (fboundp 'test-generic-fn))
  (is (typep (fdefinition 'test-generic-fn) 'generic-function))
  ;; Cleanup
  (fmakunbound 'test-generic-fn))

(test defgeneric*-with-documentation
  "Test that defgeneric* handles documentation option."
  (eval `(fol.fol-mop:defgeneric* test-documented-fn ,(make-vector 'x)
           (:documentation "A test generic function.")))
  (is (fboundp 'test-documented-fn))
  (is (string= "A test generic function."
               (documentation 'test-documented-fn 'function)))
  ;; Cleanup
  (fmakunbound 'test-documented-fn))

;;; ============================================================================
;;; Multi-pattern defgeneric* Tests
;;; ============================================================================
;;; Tests for pattern-based dispatch with destructuring vectors.
;;; Internal generics use /PN naming (P0, P1, P2...) instead of /N naming.

(test defgeneric*-multi-pattern-creates-dispatcher
  "Test that defgeneric* with multiple lambda lists creates a dispatcher."
  ;; Create a multi-pattern generic with 1, 2, and 3 argument versions
  (eval `(fol.fol-mop:defgeneric* test-multi-fn
           (,(make-vector 'a) ,(make-vector 'a 'b) ,(make-vector 'a 'b 'c))))
  ;; Main dispatcher should exist
  (is (fboundp 'test-multi-fn))
  ;; Pattern-specific generics should exist (P0, P1, P2 for each pattern)
  (is (fboundp 'test-multi-fn/p0))
  (is (fboundp 'test-multi-fn/p1))
  (is (fboundp 'test-multi-fn/p2))
  ;; Pattern-specific ones should be generic functions
  (is (typep (fdefinition 'test-multi-fn/p0) 'generic-function))
  (is (typep (fdefinition 'test-multi-fn/p1) 'generic-function))
  (is (typep (fdefinition 'test-multi-fn/p2) 'generic-function))
  ;; Cleanup
  (fmakunbound 'test-multi-fn)
  (fmakunbound 'test-multi-fn/p0)
  (fmakunbound 'test-multi-fn/p1)
  (fmakunbound 'test-multi-fn/p2)
  (cl:remprop 'test-multi-fn 'fol.fol-mop::multi-pattern-info))

(test defgeneric*-multi-pattern-stores-info
  "Test that multi-pattern defgeneric* stores pattern info for defmethod*."
  (eval `(fol.fol-mop:defgeneric* test-pattern-info
           (,(make-vector 'x) ,(make-vector 'x 'y))))
  ;; Should have pattern info with 2 entries
  (let ((info (cl:get 'test-pattern-info 'fol.fol-mop::multi-pattern-info)))
    (is (= 2 (length info)))
    ;; Each entry should have :index, :arity, :signature, :internal-name
    (is (every (lambda (p) (and (getf p :index) (getf p :arity))) info)))
  ;; Cleanup
  (fmakunbound 'test-pattern-info)
  (fmakunbound 'test-pattern-info/p0)
  (fmakunbound 'test-pattern-info/p1)
  (cl:remprop 'test-pattern-info 'fol.fol-mop::multi-pattern-info))

(test defmethod*-routes-to-correct-pattern
  "Test that defmethod* routes methods to the correct pattern-specific generic."
  ;; Create multi-pattern generic
  (eval `(fol.fol-mop:defgeneric* test-routed
           (,(make-vector 'x) ,(make-vector 'x 'y))))
  ;; Add methods
  (eval `(fol.fol-mop:defmethod* test-routed ,(make-vector 'x)
           :one-arg))
  (eval `(fol.fol-mop:defmethod* test-routed ,(make-vector 'x 'y)
           :two-args))
  ;; Test dispatcher routes correctly
  (is (eq :one-arg (test-routed 1)))
  (is (eq :two-args (test-routed 1 2)))
  ;; Cleanup
  (fmakunbound 'test-routed)
  (fmakunbound 'test-routed/p0)
  (fmakunbound 'test-routed/p1)
  (cl:remprop 'test-routed 'fol.fol-mop::multi-pattern-info))

(test defmethod*-with-specialization-and-multi-pattern
  "Test that defmethod* handles specialized params with multi-pattern generics."
  ;; Create multi-pattern generic
  (eval `(fol.fol-mop:defgeneric* test-specialized-multi
           (,(make-vector 'a) ,(make-vector 'a 'b))))
  ;; Add specialized methods for different patterns
  ;; Type specialization uses list syntax: (var type)
  (eval `(fol.fol-mop:defmethod* test-specialized-multi
           ,(make-vector '(a number))
           (cl:list :one-number a)))
  (eval `(fol.fol-mop:defmethod* test-specialized-multi
           ,(make-vector '(a number) '(b number))
           (cl:list :two-numbers a b)))
  ;; Test
  (is (equal '(:one-number 42) (test-specialized-multi 42)))
  (is (equal '(:two-numbers 1 2) (test-specialized-multi 1 2)))
  ;; Cleanup
  (fmakunbound 'test-specialized-multi)
  (fmakunbound 'test-specialized-multi/p0)
  (fmakunbound 'test-specialized-multi/p1)
  (cl:remprop 'test-specialized-multi 'fol.fol-mop::multi-pattern-info))

(test multi-pattern-dispatcher-signals-error-for-invalid-arity
  "Test that multi-pattern dispatcher signals error for unsupported arities."
  ;; Create generic with only 1 and 2 arg versions
  (eval `(fol.fol-mop:defgeneric* test-limited-arity
           (,(make-vector 'a) ,(make-vector 'a 'b))))
  (eval `(fol.fol-mop:defmethod* test-limited-arity ,(make-vector 'x) :one))
  (eval `(fol.fol-mop:defmethod* test-limited-arity ,(make-vector 'x 'y) :two))
  ;; Valid calls work
  (is (eq :one (test-limited-arity 1)))
  (is (eq :two (test-limited-arity 1 2)))
  ;; Invalid arity signals error
  (signals error (test-limited-arity))       ; 0 args
  (signals error (test-limited-arity 1 2 3)) ; 3 args
  ;; Cleanup
  (fmakunbound 'test-limited-arity)
  (fmakunbound 'test-limited-arity/p0)
  (fmakunbound 'test-limited-arity/p1)
  (cl:remprop 'test-limited-arity 'fol.fol-mop::multi-pattern-info))

(test multi-pattern-via-fol-eval
  "Test that multi-pattern generics work through FOL eval."
  (let ((env (make-standard-module)))
    ;; Define multi-pattern generic
    (fol-eval `(defgeneric test-eval-multi (,(make-vector 'x) ,(make-vector 'x 'y))) env)
    ;; Add methods
    (fol-eval `(defmethod test-eval-multi ,(make-vector 'x) "one") env)
    (fol-eval `(defmethod test-eval-multi ,(make-vector 'x 'y) "two") env)
    ;; Test through eval
    (is (fboundp 'test-eval-multi))
    (is (string= "one" (test-eval-multi 1)))
    (is (string= "two" (test-eval-multi 1 2)))
    ;; Cleanup
    (fmakunbound 'test-eval-multi)
    (fmakunbound 'test-eval-multi/p0)
    (fmakunbound 'test-eval-multi/p1)
    (cl:remprop 'test-eval-multi 'fol.fol-mop::multi-pattern-info)))

;;; ============================================================================
;;; Pattern-based Dispatch Tests
;;; ============================================================================
;;; Tests for dispatching based on patterns (same arity, different structure).
;;; Pattern dispatch works at the dispatcher level - methods use simple parameters.
;;; The dispatcher checks argument structure and routes to the appropriate generic.

(test pattern-dispatch-seq-vs-any
  "Test pattern dispatch: seq pattern [[a b]] vs simple [x]."
  ;; Create generic with two patterns for arity 1:
  ;; [x] - matches any single argument (pattern P0)
  ;; [[a b]] - expects argument that is a 2-element sequence (pattern P1)
  (eval `(fol.fol-mop:defgeneric* test-pattern-dispatch
           (,(make-vector 'x)                           ; P0: any single arg
            ,(make-vector (make-vector 'a 'b)))))       ; P1: expects pair
  ;; Add methods directly to internal generics using simple params
  ;; P0's method takes any argument
  (eval `(defmethod test-pattern-dispatch/p0 (x)
           (cl:list :single x)))
  ;; P1's method takes the sequence as a single arg
  (eval `(defmethod test-pattern-dispatch/p1 (arg)
           (cl:list :pair-seq arg)))
  ;; Test: vector [1 2] should match the seq pattern (P1)
  (let ((result (test-pattern-dispatch (make-vector 1 2))))
    (is (eq :pair-seq (cl:first result))))
  ;; Test: a number should match the :any pattern (P0)
  (is (equal '(:single 42) (test-pattern-dispatch 42)))
  ;; Test: a string should match the :any pattern (P0)
  (is (equal '(:single "hello") (test-pattern-dispatch "hello")))
  ;; Cleanup
  (fmakunbound 'test-pattern-dispatch)
  (fmakunbound 'test-pattern-dispatch/p0)
  (fmakunbound 'test-pattern-dispatch/p1)
  (cl:remprop 'test-pattern-dispatch 'fol.fol-mop::multi-pattern-info))

(test pattern-dispatch-specificity-order
  "Test that more specific patterns (seq) are tried before less specific (:any)."
  ;; The seq pattern should be tried first because it's more specific
  (eval `(fol.fol-mop:defgeneric* test-specificity
           (,(make-vector 'x)                           ; P0: any
            ,(make-vector (make-vector 'a 'b 'c)))))    ; P1: expects triple
  ;; Add methods directly to internal generics
  (eval `(defmethod test-specificity/p0 (x)
           :any))
  (eval `(defmethod test-specificity/p1 (arg)
           :triple))
  ;; Vector with 3 elements should match triple pattern
  (is (eq :triple (test-specificity (make-vector 1 2 3))))
  ;; Vector with 2 elements should fall through to :any (not enough elements)
  (is (eq :any (test-specificity (make-vector 1 2))))
  ;; Non-sequence should match :any
  (is (eq :any (test-specificity 42)))
  ;; Cleanup
  (fmakunbound 'test-specificity)
  (fmakunbound 'test-specificity/p0)
  (fmakunbound 'test-specificity/p1)
  (cl:remprop 'test-specificity 'fol.fol-mop::multi-pattern-info))

(test pattern-dispatch-with-fol-list
  "Test pattern dispatch works with FOL lists."
  (eval `(fol.fol-mop:defgeneric* test-list-pattern
           (,(make-vector 'x)
            ,(make-vector (make-vector 'a 'b)))))
  ;; Methods on internal generics
  (eval `(defmethod test-list-pattern/p0 (x)
           :single))
  (eval `(defmethod test-list-pattern/p1 (arg)
           :pair))
  ;; FOL list should match seq pattern
  (is (eq :pair (test-list-pattern (make-list 1 2))))
  ;; Atom should match :any
  (is (eq :single (test-list-pattern 99)))
  ;; Cleanup
  (fmakunbound 'test-list-pattern)
  (fmakunbound 'test-list-pattern/p0)
  (fmakunbound 'test-list-pattern/p1)
  (cl:remprop 'test-list-pattern 'fol.fol-mop::multi-pattern-info))

;;; ============================================================================
;;; defclass* Macro Tests
;;; ============================================================================

(test defclass*-creates-class
  "Test that defclass* creates a class."
  (eval `(fol.fol-mop:defclass* <test-point> ,(make-vector)
           ,(make-vector 'x 'y)))
  (is (find-class '<test-point> nil))
  ;; Test that we can create instances
  (let ((obj (make-instance '<test-point>)))
    (is (typep obj '<test-point>))))

(test defclass*-with-superclasses
  "Test that defclass* handles superclasses."
  (eval `(fol.fol-mop:defclass* <test-colored-point>
           ,(make-vector '<test-point>)
           ,(make-vector 'color)))
  (is (find-class '<test-colored-point> nil))
  ;; Check inheritance
  (let ((obj (make-instance '<test-colored-point>)))
    (is (typep obj '<test-point>))
    (is (typep obj '<test-colored-point>))))

(test defclass*-with-slot-options
  "Test that defclass* handles full slot specifications."
  (eval `(fol.fol-mop:defclass* <test-named>
           ,(make-vector)
           ,(make-vector (make-vector 'name :initarg :name :accessor 'test-named-name))))
  (is (find-class '<test-named> nil))
  ;; Test slot accessor
  (let ((obj (make-instance '<test-named> :name "Test")))
    (is (string= "Test" (test-named-name obj)))))

;;; ============================================================================
;;; defmethod* Macro Tests
;;; ============================================================================

(test defmethod*-creates-method
  "Test that defmethod* creates a method on an existing generic."
  ;; First create a generic function
  (eval `(fol.fol-mop:defgeneric* compute-area ,(make-vector 'shape)))
  ;; Now add a method - type specialization uses list syntax (var type)
  (eval `(fol.fol-mop:defmethod* compute-area ,(make-vector '(shape <test-point>))
           10))
  ;; Test the method
  (let ((pt (make-instance '<test-point>)))
    (is (= 10 (compute-area pt))))
  ;; Cleanup
  (fmakunbound 'compute-area))

(test defmethod*-with-qualifier
  "Test that defmethod* handles method qualifiers."
  ;; Create a generic function
  (eval `(fol.fol-mop:defgeneric* test-qualified ,(make-vector 'x)))
  ;; Add primary method
  (eval `(fol.fol-mop:defmethod* test-qualified ,(make-vector 'x)
           "primary"))
  ;; Add before method
  (eval `(fol.fol-mop:defmethod* test-qualified :before ,(make-vector 'x)
           (format nil "before")))
  ;; Test
  (is (string= "primary" (test-qualified 42)))
  ;; Cleanup
  (fmakunbound 'test-qualified))

;;; ============================================================================
;;; FOL Eval Integration Tests
;;; ============================================================================

(test fol-eval-defgeneric
  "Test that defgeneric works through FOL eval."
  (let ((env (make-standard-module)))
    ;; Use make-vector since CL reader doesn't understand [] syntax
    (fol-eval `(defgeneric eval-test-generic ,(make-vector 'x 'y)) env)
    (is (fboundp 'eval-test-generic))
    ;; Cleanup
    (fmakunbound 'eval-test-generic)))

(test fol-eval-defclass
  "Test that defclass works through FOL eval."
  (let ((env (make-standard-module)))
    ;; Use make-vector since CL reader doesn't understand [] syntax
    (fol-eval `(defclass <eval-test-class> ,(make-vector) ,(make-vector 'a 'b 'c)) env)
    (is (find-class '<eval-test-class> nil))))

(test fol-eval-defmethod
  "Test that defmethod works through FOL eval."
  (let ((env (make-standard-module)))
    ;; Create generic first
    (fol-eval `(defgeneric eval-test-method ,(make-vector 'obj)) env)
    ;; Add method with specialized parameter - type specialization uses list syntax
    (fol-eval `(defmethod eval-test-method ,(make-vector '(obj <eval-test-class>))
                 42) env)
    ;; Test
    (let ((obj (make-instance '<eval-test-class>)))
      (is (= 42 (eval-test-method obj))))
    ;; Cleanup
    (fmakunbound 'eval-test-method)))

;;; ============================================================================
;;; Generic Constructor (make) Tests
;;; ============================================================================

(test make-empty-collections
  "Test that make creates empty collections without initial values."
  (let ((vec (make 'fol.collection:<vector>)))
    (is (<vector>? vec))
    (is (= 0 (size vec))))
  (let ((lst (make 'fol.collection:<list>)))
    (is (<list>? lst))
    (is (= 0 (size lst))))
  (let ((s (make 'fol.collection:<set>)))
    (is (<set>? s))
    (is (= 0 (size s))))
  (let ((d (make 'fol.collection:<dict>)))
    (is (<dict>? d))
    (is (= 0 (size d)))))

(test make-collections-with-values
  "Test that make creates collections with initial values."
  (let ((vec (make 'fol.collection:<vector> 1 2 3)))
    (is (<vector>? vec))
    (is (= 3 (size vec))))
  (let ((lst (make 'fol.collection:<list> 'a 'b 'c)))
    (is (<list>? lst))
    (is (= 3 (size lst))))
  (let ((s (make 'fol.collection:<set> 1 2 3)))
    (is (<set>? s))
    (is (= 3 (size s)))))

(test make-wrapper-types
  "Test that make creates wrapper type instances."
  (let ((str (make 'fol.classes:<string> "hello")))
    (is (typep str 'fol.classes:<string>))
    (is (string= "hello" (fol.classes:-fol-value str))))
  (let ((b (make 'fol.classes:<bool> t)))
    (is (typep b 'fol.classes:<bool>))
    (is (eq t (fol.classes:-fol-value b))))
  (let ((c (make 'fol.classes:<char> #\X)))
    (is (typep c 'fol.classes:<char>))
    (is (char= #\X (fol.classes:-fol-value c)))))

(test make-requires-value-for-non-collections
  "Test that make errors when non-collection types have no initial value."
  (signals error (make 'fol.classes:<string>))
  (signals error (make 'fol.classes:<bool>))
  (signals error (make 'fol.classes:<integer>)))

(test make-via-fol-eval
  "Test that make works through FOL eval."
  (let ((env (make-standard-module)))
    ;; Empty collection (quote the class name)
    (let ((vec (fol-eval '(make (quote fol.collection:<vector>)) env)))
      (is (<vector>? vec))
      (is (= 0 (size vec))))
    ;; Collection with values
    (let ((vec (fol-eval '(make (quote fol.collection:<vector>) 1 2 3) env)))
      (is (<vector>? vec))
      (is (= 3 (size vec))))))

;;; Define a test class for user-defined class tests
(defclass <test-user-class> ()
  ((val :initarg :val :accessor test-user-val)
   (name :initarg :name :accessor test-user-name :initform "default")
   (count :initarg :count :accessor test-user-count :initform 0)))

(test make-user-defined-class-single-value
  "Test that make works with user-defined classes using a single value."
  (let ((obj (make '<test-user-class> 42)))
    (is (typep obj '<test-user-class>))
    (is (= 42 (test-user-val obj)))
    ;; Other slots should have defaults
    (is (string= "default" (test-user-name obj)))
    (is (= 0 (test-user-count obj)))))

(test make-user-defined-class-keyword-args
  "Test that make works with user-defined classes using keyword arguments."
  (let ((obj (make '<test-user-class> :val 100 :name "test" :count 5)))
    (is (typep obj '<test-user-class>))
    (is (= 100 (test-user-val obj)))
    (is (string= "test" (test-user-name obj)))
    (is (= 5 (test-user-count obj)))))

(test make-user-defined-class-requires-value
  "Test that make errors for user-defined classes without initial value."
  (signals error (make '<test-user-class>)))
