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

(def-suite string-tests
  :description "Tests for string manipulation functions."
  :in compiler-tests)

(def-suite primitive-functions-tests
  :description "Tests for primitive functions (symbol, keyword, find-keyword, gensym)."
  :in compiler-tests)

(def-suite walk-tests
  :description "Tests for tree walking and transformation functions."
  :in compiler-tests)

(def-suite functional-tests
  :description "Tests for functional operations (identity, comp, partial, etc.) and special forms (defn-, definline, some->, some->>, as->)."
  :in compiler-tests)

(def-suite metadata-tests
  :description "Tests for metadata system (meta, with-meta, vary-meta, alter-meta!, reset-meta!, doc, test)."
  :in compiler-tests)

(def-suite relational-tests
  :description "Tests for relational algebra functions (join, select, project, etc.)."
  :in compiler-tests)

(def-suite transducers-tests
  :description "Tests for transducers (map, filter, transduce, etc.)."
  :in compiler-tests)

(def-suite seq-functions-tests
  :description "Tests for seq-functions (seq, sequence, range, repeat, iterate, etc.)."
  :in compiler-tests)

(defun fol-form (form)
  "Recursively convert CL vectors in FORM to FOL <vector> instances.
   Allows tests to use the familiar #(...) syntax inside (fol-form '(...))."
  (cond
    ((and (cl:vectorp form) (not (stringp form)))
     (apply #'fol.compiler.collection-functions:vector
            (map 'list #'fol-form form)))
    ((consp form)
     (cons (fol-form (car form)) (fol-form (cdr form))))
    (t form)))

(defun run-compiler-tests ()
  "Run all compiler tests. Returns T if all tests pass."
  (run! 'compiler-tests))
