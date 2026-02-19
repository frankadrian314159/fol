(require :asdf)
(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(handler-case
    (compile-file "transpiled-fol-code/compliance.lisp")
  (error (c)
    (format t "~%COMPILE ERROR: ~A~%" c)
    (sb-ext:exit :code 1)))
(sb-ext:quit)
