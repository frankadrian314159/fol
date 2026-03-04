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

;;; --- Updated fol-compiler.asd ---

(defsystem "fol-compiler"
  :description "FOL Compiler - Compiles FOL to Common Lisp."
  :version "0.1.0"
  :author "Frank Adrian"
  :license "MIT"
  :depends-on ("closer-mop" "uuid" "bordeaux-threads" "usocket" "cl-ppcre")
  :components ((:file "package")
               (:file "compareops" :depends-on ("package"))
               (:file "primitives" :depends-on ("package"))
               (:file "collection-primitives" :depends-on ("package"))
               (:file "collections" :depends-on ("package" "collection-primitives"))
               (:file "transients" :depends-on ("package" "collections"))
               (:file "primitive-functions" :depends-on ("package" "collections"))
               (:file "ast" :depends-on ("package"))
               (:file "destructure" :depends-on ("package"))
               (:file "persistence" :depends-on ("package"))
               (:file "collection-functions" :depends-on ("package" "collections" "string-functions" "persistence" "destructure"))
               (:file "arithmetic-functions" :depends-on ("package" "primitives"))
               (:file "bitwise-operation-functions" :depends-on ("package" "primitives"))
               (:file "logical-operation-functions" :depends-on ("package" "primitives"))
               (:file "string-functions" :depends-on ("package"))
               (:file "cl-utils" :depends-on ("package"))
               (:file "seq-functions" :depends-on ("package" "primitives" "collections" "merged-functions"))
               (:file "reader" :depends-on ("package" "collections" "collection-functions"))
               (:file "mutable" :depends-on ("package"))
               (:file "mutable-functions" :depends-on ("package" "mutable"))
               (:file "streams" :depends-on ("package"))
               (:file "functional" :depends-on ("package"))
               (:file "relational" :depends-on ("package" "collections" "collection-functions" "seq-functions"))
               (:file "transducers" :depends-on ("package" "primitives" "collections" "collection-functions" "seq-functions"))
               (:file "metadata" :depends-on ("package" "persistence" "collections"))
               (:file "misc-functions" :depends-on ("package"))
               (:file "merged-functions" :depends-on ("package" "string-functions" "collections" "primitives" "collection-functions"))
               (:file "compiler" :depends-on ("package" "primitives" "ast" "destructure" "persistence" "collections" "collection-functions" "seq-functions" "reader"))
               (:file "macros" :depends-on ("compiler" "package" "primitives" "collections" "collection-functions" "seq-functions" "streams" "metadata" "mutable"))
               (:file "io" :depends-on ("package" "streams" "string-functions" "macros"))
               (:file "repl" :depends-on ("compiler" "reader" "package")))
  :in-order-to ((test-op (test-op "fol-compiler/all-tests"))))

;; --- The User-Facing Core System ---
(defsystem "fol-compiler/core"
  :depends-on ("fol-compiler")
  :components ((:file "fol-core")))

;; --- The Extension REPL Server System ---
(defsystem "fol-extension-server"
  :depends-on ("fol-compiler" "bordeaux-threads")
  :serial t
  :components ((:file "repl-server")))

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
                                  (:file "test-replace" :depends-on ("compiler-tests-package"))
                                  (:file "test-primitive-functions" :depends-on ("compiler-tests-package"))
                                  (:file "test-mutable-functions" :depends-on ("compiler-tests-package"))
                                  (:file "test-functional" :depends-on ("compiler-tests-package"))
                                  (:file "test-metadata" :depends-on ("compiler-tests-package"))
                                  (:file "test-relational" :depends-on ("compiler-tests-package"))
                                  (:file "test-transducers" :depends-on ("compiler-tests-package"))
                                  (:file "test-seq-functions" :depends-on ("compiler-tests-package"))
                                  (:file "test-io" :depends-on ("compiler-tests-package"))
                                  (:file "test-misc-functions" :depends-on ("compiler-tests-package"))
                                  (:file "fol-tests" :depends-on ("compiler-tests-package")))))
           :perform (test-op (o s) (symbol-call :fol.compiler.tests :run-compiler-tests)))

(defsystem "fol-compiler/tests/lib"
           :depends-on ("fol-compiler" "fiveam")
           :components ((:module "lib"
                                 :pathname "lib"
                                 :components ((:file "walk") (:file "zip") (:file "reducers") (:file "core-async") (:file "parallel")))
                        (:module "lib-tests"
                                 :pathname "tests/lib"
                                 :depends-on ("lib")
                                 :components ((:file "lib-tests-package")
                                              (:file "test-walk" :depends-on ("lib-tests-package"))
                                              (:file "test-zip" :depends-on ("lib-tests-package"))
                                              (:file "test-reducers" :depends-on ("lib-tests-package"))
                                              (:file "test-core-async" :depends-on ("lib-tests-package"))
                                              (:file "test-parallel" :depends-on ("lib-tests-package")))))
           :perform (test-op (o s) (symbol-call :fol.compiler.tests.lib :run-lib-tests)))

(defsystem "fol-compiler/fol-tests"
           :description "Standalone end-to-end tests written in FOL syntax."
           :depends-on ("fol-compiler" "fiveam")
           :components ((:module "fol-tests"
                                 :pathname "tests"
                                 :components
                                 ((:file "fol-tests-package")
                                  (:file "fol-tests-runner" :depends-on ("fol-tests-package")))))
           :perform (test-op (o s) (symbol-call :fol.compiler.fol-tests :run-fol-tests)))

(defsystem "fol-compiler/all-tests"
           :depends-on ("fol-compiler/tests" "fol-compiler/tests/lib" "fol-compiler/fol-tests")
           :perform (test-op (o s)
                             (uiop:symbol-call :fol.compiler.tests :run-compiler-tests)
                             (uiop:symbol-call :fol.compiler.tests.lib :run-lib-tests)
                             (uiop:symbol-call :fol.compiler.fol-tests :run-fol-tests)))
