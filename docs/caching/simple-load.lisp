(asdf:load-system :fol-compiler :source-registry `((,(uiop:getcwd) "/src/" :recurse-subresources t)))
(format t "~%Compiler loaded successfully!~%")