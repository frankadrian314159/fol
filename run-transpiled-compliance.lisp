(push (truename "src/") asdf:*central-registry*)
(handler-bind ((style-warning #'muffle-warning)
               (warning #'muffle-warning))
  (asdf:load-system :fol-compiler))

(format t "Loading transpiled code...~%")
(handler-case
    (load "transpiled-fol-code/compliance.lisp")
  (error (c)
    (format t "~%LOAD ERROR: ~A~%" c)
    (sb-debug:print-backtrace)
    (sb-ext:exit :code 1)))

(format t "~%--- Debug: Package COMPLIANCE exists: ~S ---~%" (find-package "compliance"))
(format t "--- Debug: Symbol compliance::<trade> exists: ~S ---~%" (find-symbol "<TRADE>" "compliance"))
(let ((sym (find-symbol "<TRADE>" "compliance")))
  (when sym
        (format t "--- Debug: Class ~S exists: ~S ---~%" sym (find-class sym nil))))

(format t "~%--- Invoking (test-compliance::compliance) explicitly ---~%")
(handler-case
    (test-compliance::compliance)
  (error (c)
    (format t "~%EXECUTION ERROR: ~A~%" c)
    (sb-debug:print-backtrace)
    (sb-ext:exit :code 1)))

(terpri)
(sb-ext:quit)
