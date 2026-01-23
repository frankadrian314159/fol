(in-package :fol.tests)

(def-suite mop-constructor-suite :in fol-suite)
(def-suite* :fol.mop-constructor-tests :in mop-constructor-suite)

;;; ============================================================================
;;; Bare Class Name Tests
;;; ============================================================================

(test bare-class-name-with-angle-brackets
  "Test extracting bare class name from angle-bracketed names."
  (is (string= "STRING" (bare-class-name 'fol.classes:<string>)))
  (is (string= "BOOL" (bare-class-name 'fol.classes:<bool>)))
  (is (string= "CHAR" (bare-class-name 'fol.classes:<char>)))
  (is (string= "INTEGER" (bare-class-name 'fol.classes:<integer>))))

(test class-name-string-basic
  "Test getting class name as a string."
  (is (string= "<STRING>" (class-name-string 'fol.classes:<string>)))
  (is (string= "<BOOL>" (class-name-string 'fol.classes:<bool>))))

;;; ============================================================================
;;; Constructor Name Tests
;;; ============================================================================

(test constructor-name-generation
  "Test generating constructor names from class names."
  (let ((ctor-name (constructor-name 'fol.classes:<string>)))
    (is (symbolp ctor-name))
    (is (string= "MAKE-STRING" (symbol-name ctor-name))))
  (let ((ctor-name (constructor-name 'fol.classes:<bool>)))
    (is (string= "MAKE-BOOL" (symbol-name ctor-name))))
  (let ((ctor-name (constructor-name 'fol.classes:<integer>)))
    (is (string= "MAKE-INTEGER" (symbol-name ctor-name)))))

;;; ============================================================================
;;; Initargs Introspection Tests
;;; ============================================================================

(test class-initargs-retrieval
  "Test retrieving initargs for a class."
  (let ((initargs (class-initargs 'fol.classes:<string>)))
    (is (listp initargs))
    (is (member :val initargs))))

(test required-initargs-retrieval
  "Test retrieving required initargs for a class."
  ;; <string> has :val with no initform, so it should be required
  (let ((required (required-initargs 'fol.classes:<string>)))
    (is (listp required))
    (is (member :val required))))

;;; ============================================================================
;;; make-instance* Tests
;;; ============================================================================

(test make-instance-star-with-symbol
  "Test make-instance* with a class symbol."
  (let ((obj (make-instance* 'fol.classes:<string> :val "hello")))
    (is (typep obj 'fol.classes:<string>))
    (is (string= "hello" (fol.classes:-fol-value obj)))))

(test make-instance-star-with-class
  "Test make-instance* with a class object."
  (let ((obj (make-instance* (find-class 'fol.classes:<bool>) :val t)))
    (is (typep obj 'fol.classes:<bool>))
    (is (eq t (fol.classes:-fol-value obj)))))

;;; ============================================================================
;;; Constructor Definition Tests
;;; ============================================================================

(test define-constructor-creates-function
  "Test that define-constructor creates a working function."
  ;; Define a constructor for a test purpose
  (eval '(fol.mop:define-constructor fol.classes:<char>))
  (let ((ctor-fn (symbol-function (find-symbol "MAKE-CHAR" :fol.classes))))
    (is (functionp ctor-fn)))
  ;; Use the constructor
  (let ((obj (funcall (find-symbol "MAKE-CHAR" :fol.classes) :val #\A)))
    (is (typep obj 'fol.classes:<char>))
    (is (char= #\A (fol.classes:-fol-value obj)))))

(test generate-constructor-form-structure
  "Test that generate-constructor-form returns correct structure."
  (let ((form (generate-constructor-form 'fol.classes:<string>)))
    (is (eq 'defun (first form)))
    (is (string= "MAKE-STRING" (symbol-name (second form))))
    ;; Check the parameter list structure (symbol names, not package-qualified)
    (is (eq '&rest (first (third form))))
    (is (string= "INITARGS" (symbol-name (second (third form)))))))

;;; ============================================================================
;;; Describe Constructor Tests
;;; ============================================================================

(test describe-constructor-returns-values
  "Test that describe-constructor returns meaningful values."
  (multiple-value-bind (ctor-name required optional)
      (describe-constructor 'fol.classes:<string> nil)
    (is (symbolp ctor-name))
    (is (string= "MAKE-STRING" (symbol-name ctor-name)))
    (is (listp required))
    (is (listp optional))))

;;; ============================================================================
;;; List Constructible Classes Tests
;;; ============================================================================

(test list-constructible-classes-returns-list
  "Test that list-constructible-classes returns a list of classes."
  (let ((classes (list-constructible-classes)))
    (is (listp classes))
    (is (> (length classes) 0))
    ;; All returned items should be persistent classes
    (dolist (class classes)
      (is (persistent-class-p class)))))

(test list-constructible-classes-with-filter
  "Test filtering constructible classes."
  (let ((string-classes (list-constructible-classes
                         (lambda (c)
                           (search "STRING" (symbol-name (class-name* c)))))))
    (is (listp string-classes))
    (dolist (class string-classes)
      (is (search "STRING" (symbol-name (class-name* class)))))))
