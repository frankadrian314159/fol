(push (truename ".") asdf:*central-registry*)
(asdf:load-system :fol-compiler/tests)
(fol.compiler.tests:run-compiler-tests)
