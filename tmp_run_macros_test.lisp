(require :asdf)
(push (truename "c:/Users/frank/Projects/FOL/fol/src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler/fol-tests)

(in-package :fol.compiler.fol-tests)

(format t "~%--- START MACROS TEST ---~%")
(load-and-run-fol-test "macros_test.fol")
(format t "~%--- END MACROS TEST ---~%")
