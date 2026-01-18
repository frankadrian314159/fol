(require :asdf)
(load "~/quicklisp/setup.lisp")
(push (truename ".") asdf:*central-registry*)

;; Suppress all warnings and notes during load
(let ((*standard-output* (make-broadcast-stream))
      (*error-output* (make-broadcast-stream)))
  (handler-bind ((warning #'muffle-warning))
    (ql:quickload :named-readtables :silent t)
    (ql:quickload :fset :silent t)
    (ql:quickload :closer-mop :silent t)
    (asdf:load-system :fol)))

;; Clear screen and start the REPL
(format t "~C[2J~C[H" #\Escape #\Escape)  ; ANSI clear screen (may not work on all terminals)
(fol.repl:start-repl)
