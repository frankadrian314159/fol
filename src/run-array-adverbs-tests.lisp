;;; Run only array-functions and adverbs tests

(push (truename ".") asdf:*central-registry*)

(asdf:load-system :fol-compiler)
(asdf:load-system :fol-compiler/tests :force t)

(fiveam:run! :fol.compiler.tests::array-functions-suite)
(fiveam:run! :fol.compiler.tests::adverbs-suite)
