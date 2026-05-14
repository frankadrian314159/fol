;; Simple test to verify dispatch.lisp loads without errors
(push #p"c:/Users/frank/Projects/FOL/fol/src/" asdf:*central-registry*)
(format t "~&Loading fol-compiler system...~%")
(asdf:load-system :fol-compiler)
(format t "~&fol-compiler loaded successfully!~%")
(format t "~&Checking dispatch module...~%")
(format t "~&  make-dispatch-cache: ~S~%" (fol.compiler.dispatch:make-dispatch-cache))
(format t "~&Dispatch module OK!~%")
(sb-ext:quit :unix-status 0)
