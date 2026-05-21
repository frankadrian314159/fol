;; Run all FOL compiler tests
(push #p"c:/Users/frank/Projects/FOL/fol/src/" asdf:*central-registry*)
(format t "~&Loading and running FOL compiler test suite...~%~%")
(asdf:load-system :fol-compiler/tests)
(fol.compiler.tests:run-compiler-tests)
(sb-ext:quit :unix-status 0)
