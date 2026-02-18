;;; FOL Compiler Library Tests - Package Definition

(defpackage fol.compiler.tests.lib
  (:use cl fiveam)
  (:import-from fol.compiler.collections
                <collection> <vector> <dict> <set> <list>
                collection-seq collection-size make)
  (:shadowing-import-from fol.compiler.collection-functions
                          get)
  ;; For test-zip which uses raw vector access for logic etc
  (:export run-lib-tests))

(in-package :fol.compiler.tests.lib)

(def-suite lib-tests
           :description "Tests for external libraries (walk, zip).")

(def-suite walk-tests
           :description "Tests for walk library."
           :in lib-tests)

(def-suite zip-tests
           :description "Tests for zip library."
           :in lib-tests)

(defun run-lib-tests ()
  (let ((results (run 'lib-tests)))
    (explain! results)))
