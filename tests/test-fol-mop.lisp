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

(test convert-specialized-param-handles-vectors
  "Test that convert-specialized-param converts vector specializers to lists."
  (let ((param (make-vector 'a '<point>)))
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
  ;; Now add a method
  (eval `(fol.fol-mop:defmethod* compute-area ,(make-vector (make-vector 'shape '<test-point>))
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

(test fol-eval-defgeneric*
  "Test that defgeneric* works through FOL eval."
  (let ((env (make-standard-env)))
    ;; Use make-vector since CL reader doesn't understand [] syntax
    (fol-eval `(defgeneric* eval-test-generic ,(make-vector 'x 'y)) env)
    (is (fboundp 'eval-test-generic))
    ;; Cleanup
    (fmakunbound 'eval-test-generic)))

(test fol-eval-defclass*
  "Test that defclass* works through FOL eval."
  (let ((env (make-standard-env)))
    ;; Use make-vector since CL reader doesn't understand [] syntax
    (fol-eval `(defclass* <eval-test-class> ,(make-vector) ,(make-vector 'a 'b 'c)) env)
    (is (find-class '<eval-test-class> nil))))

(test fol-eval-defmethod*
  "Test that defmethod* works through FOL eval."
  (let ((env (make-standard-env)))
    ;; Create generic first
    (fol-eval `(defgeneric* eval-test-method ,(make-vector 'obj)) env)
    ;; Add method with specialized parameter
    (fol-eval `(defmethod* eval-test-method ,(make-vector (make-vector 'obj '<eval-test-class>))
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
  (let ((env (make-standard-env)))
    ;; Empty collection (quote the class name)
    (let ((vec (fol-eval '(fol.fol-mop:make (quote fol.collection:<vector>)) env)))
      (is (<vector>? vec))
      (is (= 0 (size vec))))
    ;; Collection with values
    (let ((vec (fol-eval '(fol.fol-mop:make (quote fol.collection:<vector>) 1 2 3) env)))
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
