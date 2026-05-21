(push (truename ".") asdf:*central-registry*)
(asdf:load-system :fol-compiler)
(format t "~%Compiler loaded OK~%")