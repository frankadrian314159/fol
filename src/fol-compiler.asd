;;; FOL Compiler
;;;
;;; Compiles FOL source to Common Lisp, which SBCL then compiles to native code.
;;; Depends on the bootstrap system for the reader, class definitions, and
;;; persistent collection infrastructure.
;;;
;;; To load:
;;;   (push #p"/path/to/fol/src/" asdf:*central-registry*)
;;;   (asdf:load-system :fol-compiler)
;;;
;;; To run tests:
;;;   (asdf:test-system :fol-compiler)

(defsystem "fol-compiler"
  :description "FOL Compiler - Compiles FOL to Common Lisp."
  :version "0.1.0"
  :author "Frank Adrian"
  :license "MIT"
  :depends-on ("fset" "sycamore" "closer-mop" "uuid" "bordeaux-threads" "usocket" "cl-ppcre")
  :components ((:file "package")
               (:file "compareops" :depends-on ("package"))
               (:file "primitives" :depends-on ("package"))
               (:file "collections" :depends-on ("package"))
               (:file "primitive-functions" :depends-on ("package"  "collections"))
               (:file "ast" :depends-on ("package"))
               (:file "destructure" :depends-on ("package"))
               (:file "persistence" :depends-on ("package"))

               (:file "collection-functions" :depends-on ("package" "collections" "string-functions" "destructure"))
               (:file "arithmetic-functions" :depends-on ("package" "primitives"))
               (:file "bitwise-operation-functions" :depends-on ("package" "primitives"))
               (:file "logical-operation-functions" :depends-on ("package" "primitives"))
               (:file "string-functions" :depends-on ("package"))
               (:file "cl-utils" :depends-on ("package"))
               (:file "seq-functions" :depends-on ("package" "primitives" "collections"))
               (:file "reader" :depends-on ("package" "collections" "collection-functions"))
               (:file "mutable" :depends-on ("package"))
               (:file "streams" :depends-on ("package"))
               (:file "walk" :depends-on ("package" "collections" "collection-functions"))
               (:file "functional" :depends-on ("package"))
               (:file "relational" :depends-on ("package" "collections" "collection-functions" "seq-functions"))
               (:file "io" :depends-on ("package" "streams" "string-functions"))
               (:file "transducers" :depends-on ("package" "primitives" "collections"))
               (:file "metadata" :depends-on ("package" "persistence" "collections"))
               (:file "misc-functions" :depends-on ("package"))
               (:file "compiler" :depends-on ("package" "primitives" "ast" "destructure" "persistence" "collections" "collection-functions" "seq-functions"))
               (:file "macros" :depends-on ("compiler" "package" "primitives" "collections" "collection-functions" "seq-functions" "streams" "metadata" "mutable")))
  :in-order-to ((test-op (test-op "fol-compiler/tests"))))

(defsystem "fol-compiler/tests"
  :depends-on ("fol-compiler" "fiveam")
  :components ((:module "tests"
                 :components
                 ((:file "compiler-tests-package")
                  (:file "test-ast" :depends-on ("compiler-tests-package"))
                  (:file "test-compiler" :depends-on ("compiler-tests-package"))
                  (:file "test-destructure" :depends-on ("compiler-tests-package"))
                  (:file "test-oop" :depends-on ("compiler-tests-package"))
                  (:file "test-collections" :depends-on ("compiler-tests-package"))
                  (:file "test-reader" :depends-on ("compiler-tests-package"))
                  (:file "test-mutable" :depends-on ("compiler-tests-package"))
                  (:file "test-streams" :depends-on ("compiler-tests-package"))
                  (:file "test-persistence" :depends-on ("compiler-tests-package"))
                  (:file "test-string-functions" :depends-on ("compiler-tests-package"))
                  (:file "test-primitive-functions" :depends-on ("compiler-tests-package"))
                  (:file "test-walk" :depends-on ("compiler-tests-package"))
                  (:file "test-functional" :depends-on ("compiler-tests-package"))
                  (:file "test-metadata" :depends-on ("compiler-tests-package"))
                  (:file "test-relational" :depends-on ("compiler-tests-package"))
                  (:file "test-transducers" :depends-on ("compiler-tests-package"))
                  (:file "test-seq-functions" :depends-on ("compiler-tests-package"))
                  (:file "test-io" :depends-on ("compiler-tests-package"))
                  (:file "test-misc-functions" :depends-on ("compiler-tests-package")))))
  :perform (test-op (o s) (symbol-call :fol.compiler.tests :run-compiler-tests)))
