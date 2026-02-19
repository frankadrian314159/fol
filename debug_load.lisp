(require :asdf)
(push #p"C:/Users/frank/Projects/FOL/fol/src/" asdf:*central-registry*)
(push #p"C:/Users/frank/Projects/FOL/fol/" asdf:*central-registry*)

(block main
  (handler-bind ((error (lambda (c)
                          (format t "~%FAILED TO LOAD: ~A~%" c)
                          (uiop:print-backtrace)
                          (return-from main (uiop:quit 1)))))
    (asdf:load-system :fol-compiler/all-tests)
    (format t "~%LOADED SUCCESSFULLY~%")
    (uiop:quit 0)))
