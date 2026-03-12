(require :asdf)
(asdf:load-asd (truename "src/fol-compiler.asd"))
(handler-case
    (asdf:load-system :fol-compiler/core :verbose nil)
  (error (c)
    (format t "~%System load failed: ~A~%" c)
    (sb-ext:exit :code 1)))
(sb-ext:exit :code 0)
