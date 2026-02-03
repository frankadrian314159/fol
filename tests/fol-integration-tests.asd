;;;; FOL Integration Tests System Definition

(asdf:defsystem #:fol-integration-tests
  :description "Integration tests for FOL using %test%"
  :author "FOL Team"
  :license "MIT"
  :version "1.0.0"
  :depends-on (#:fol #:fiveam)
  :serial t
  :pathname ""
  :components ((:file "package")
               (:file "test-arithmetic")
               (:file "test-comparison")
               (:file "test-collections")
               (:file "test-sequences")
               (:file "test-strings")
               (:file "test-functional")
               (:file "test-predicates")
               (:file "test-control-flow")
               (:file "test-mop")
               (:file "test-transducers")
               (:file "test-paper-examples")))
