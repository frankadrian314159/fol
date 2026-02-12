;;; FOL Compiler Tests - Package and Test Suite Definition

(in-package :fol.compiler.tests)

(def-suite compiler-tests
  :description "Tests for the FOL compiler.")

(def-suite ast-tests
  :description "Tests for AST node construction."
  :in compiler-tests)

(def-suite codegen-tests
  :description "Tests for code generation."
  :in compiler-tests)

(def-suite destructure-tests
  :description "Tests for destructuring, pattern signatures, and fn compilation."
  :in compiler-tests)

(def-suite oop-tests
  :description "Tests for defclass, defgeneric, and defmethod compilation."
  :in compiler-tests)

(def-suite collections-tests
  :description "Tests for collection base class and protocol."
  :in compiler-tests)

(def-suite reader-tests
  :description "Tests for the FOL reader and readtable."
  :in compiler-tests)

(def-suite mutable-tests
  :description "Tests for mutable references (atoms)."
  :in compiler-tests)

(def-suite streams-tests
  :description "Tests for stream classes and protocol."
  :in compiler-tests)

(def-suite persistence-tests
  :description "Tests for persistent object system (Sycamore hash-map backed)."
  :in compiler-tests)

(defun fol-form (form)
  "Recursively convert CL vectors in FORM to FOL <vector> instances.
   Allows tests to use the familiar #(...) syntax inside (fol-form '(...))."
  (cond
    ((and (cl:vectorp form) (not (stringp form)))
     (apply #'fol.compiler.collections:vector
            (map 'list #'fol-form form)))
    ((consp form)
     (cons (fol-form (car form)) (fol-form (cdr form))))
    (t form)))

(defun run-compiler-tests ()
  "Run all compiler tests. Returns T if all tests pass."
  (run! 'compiler-tests))
