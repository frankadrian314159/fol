(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)
(format t "Compiler loaded successfully!~%")
