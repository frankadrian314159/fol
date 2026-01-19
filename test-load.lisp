(require :asdf)
(load "~/quicklisp/setup.lisp")
(push (truename ".") asdf:*central-registry*)

(handler-bind ((warning #'muffle-warning))
  (handler-case
      (progn
        (ql:quickload :named-readtables :silent t)
        (ql:quickload :fset :silent t)
        (ql:quickload :closer-mop :silent t)
        (asdf:load-system :fol))
    (error (e)
      (format t "~%~%===== LOAD ERROR =====~%")
      (format t "~A~%~%" e)
      (describe e)
      (sb-ext:exit :code 1))))

(format t "~%~%===== SUCCESS =====~%")
(sb-ext:exit :code 0)
