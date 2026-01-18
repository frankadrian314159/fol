@echo off
REM Start the FOL REPL on Windows

sbcl --noinform ^
     --eval "(require :asdf)" ^
     --eval "(load \"~/quicklisp/setup.lisp\")" ^
     --eval "(push (truename \".\") asdf:*central-registry*)" ^
     --eval "(handler-bind ((warning #'muffle-warning)) (ql:quickload :fol :silent t))" ^
     --eval "(fol.repl:start-repl)"
