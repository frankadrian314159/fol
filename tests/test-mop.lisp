(in-package :fol.integration-tests)

(def-suite mop-suite :in integration-suite)
(def-suite* :mop-tests :in mop-suite)

;;; ---------------------------------------------------------------------------
;;; Universal Constructor: make
;;; ---------------------------------------------------------------------------

(test make-vector
  "Test make for vectors."
  (fol-is-true "(<vector>? (make <vector>))")
  (fol-is 0 "(size (make <vector>))")
  (fol-is 3 "(size (make <vector> 1 2 3))")
  (fol-is 1 "(first (make <vector> 1 2 3))"))

(test make-list
  "Test make for lists."
  (fol-is-true "(<list>? (make <list>))")
  (fol-is 0 "(size (make <list>))")
  (fol-is 3 "(size (make <list> 1 2 3))")
  (fol-is 1 "(first (make <list> 1 2 3))"))

(test make-dict
  "Test make for dicts."
  (fol-is-true "(<dict>? (make <dict>))")
  (fol-is 0 "(size (make <dict>))")
  (fol-is 2 "(size (make <dict> :a 1 :b 2))")
  (fol-is 1 "(get (make <dict> :a 1 :b 2) :a)"))

(test make-set
  "Test make for sets."
  (fol-is-true "(<set>? (make <set>))")
  (fol-is 0 "(size (make <set>))")
  (fol-is 3 "(size (make <set> 1 2 3))")
  (fol-is-true "(contains? (make <set> 1 2 3) 2)"))

(test make-string
  "Test make for strings."
  ;; make <string> creates a wrapped object, test that it exists
  (fol-is-true "(make <string> \"hello\")")
  ;; The wrapped string should stringify correctly
  (fol-is "hello" "(str (make <string> \"hello\"))"))

(test make-numbers
  "Test make for number types."
  ;; make <integer> creates a wrapped object
  (fol-is-true "(make <integer> 42)")
  ;; Value comparison should work
  (fol-is-true "(= (make <integer> 42) 42)"))

;;; ---------------------------------------------------------------------------
;;; Type Function
;;; ---------------------------------------------------------------------------

(test type-function
  "Test type function returns type symbol."
  ;; Type returns a symbol naming the type
  (fol-is-true "(symbol? (type [1 2 3]))")
  (fol-is-true "(symbol? (type (list 1 2 3)))")
  (fol-is-true "(symbol? (type {:a 1}))")
  (fol-is-true "(symbol? (type #{1 2}))")
  (fol-is-true "(symbol? (type \"hello\"))")
  (fol-is-true "(symbol? (type 42))"))

;;; ---------------------------------------------------------------------------
;;; Class Introspection
;;; ---------------------------------------------------------------------------

(test class-name-introspection
  "Test class-name* function."
  (fol-is-true "(symbol? (class-name* <vector>))")
  (fol-is-true "(symbol? (class-name* <string>))"))

(test class-superclasses
  "Test class-direct-superclasses* function."
  (fol-is-true "(<list>? (class-direct-superclasses* <vector>))")
  (fol-is-true "(<list>? (class-direct-superclasses* <integer>))"))

(test class-slots-introspection
  "Test class-slots* function returns slot info."
  ;; class-slots* returns a list of slot definition objects
  ;; Just check that the function returns something
  (fol-is-true "(class-slots* <string>)"))

;;; ---------------------------------------------------------------------------
;;; Instance Introspection
;;; ---------------------------------------------------------------------------

(test instance-class-function
  "Test instance-class function returns a class."
  ;; instance-class returns the class of an object
  (fol-is-true "(eq (instance-class [1 2 3]) <vector>)")
  ;; For raw CL strings, instance-class returns the CL string class
  ;; which is different from FOL's <string> class
  (fol-is-true "(instance-class \"hello\")"))

;;; ---------------------------------------------------------------------------
;;; Slot Names
;;; ---------------------------------------------------------------------------

(test slot-names-function
  "Test slot-names function."
  (fol-is-true "(<list>? (slot-names <string>))"))

;;; ---------------------------------------------------------------------------
;;; Persistent Object Predicates
;;; ---------------------------------------------------------------------------

(test persistent-object-predicate
  "Test <persistent-object>? predicate."
  ;; Collections are persistent objects
  (fol-is-true "(<persistent-object>? [1 2 3])")
  (fol-is-true "(<persistent-object>? (list 1 2 3))")
  (fol-is-true "(<persistent-object>? {:a 1})")
  (fol-is-true "(<persistent-object>? #{1 2})")
  ;; Raw CL strings are not persistent objects (only wrapped <string> would be)
  (fol-is-false "(<persistent-object>? \"hello\")"))

;;; ---------------------------------------------------------------------------
;;; Defclass, Defgeneric, Defmethod
;;; ---------------------------------------------------------------------------

;; Note: defclass, defgeneric, defmethod are advanced features in fol-mop
;; The runtime version is eval-defclass* - test what actually exists
(test defclass-form
  "Test that MOP functions are recognized."
  ;; Check that the type function exists (a basic MOP function)
  (fol-is-true "(fn? type)")
  (fol-is-true "(fn? instance-class)")
  (fol-is-true "(fn? make)"))
