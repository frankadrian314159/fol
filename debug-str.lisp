(require :asdf)
(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)
(load "transpiled-fol-code/compliance.lisp")

(format t "~%--- Testing STR in test-compliance ---~%")
(let ((str-sym (find-symbol "STR" "test-compliance")))
  (format t "STR sym: ~S~%" str-sym)
  (format t "FBOUNDP: ~S~%" (fboundp str-sym))
  (when (fboundp str-sym)
    (format t "Result: ~S~%" (funcall (symbol-function str-sym) "Hello " "World"))))

(sb-ext:quit)
