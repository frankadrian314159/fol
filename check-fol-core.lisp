(push (truename "src/") asdf:*central-registry*)
(handler-bind ((style-warning #'muffle-warning)
               (warning #'muffle-warning))
  (asdf:load-system :fol-compiler))

(format t "Checking symbols in FOL.CORE...~%")
(let ((sym (find-symbol "STR" :fol.core)))
  (if sym
      (let ((status (nth-value 1 (find-symbol "STR" :fol.core))))
        (format t "STR: ~S (status: ~A)~%" sym status))
      (format t "STR not found in FOL.CORE~%")))

(let ((sym (find-symbol "MAKE" :fol.core)))
  (if sym
      (let ((status (nth-value 1 (find-symbol "MAKE" :fol.core))))
        (format t "MAKE: ~S (status: ~A)~%" sym status))
      (format t "MAKE not found in FOL.CORE~%")))

(format t "All external symbols in FOL.CORE starting with S:~%")
(do-external-symbols (s :fol.core)
  (when (char= (char (symbol-name s) 0) #\S)
    (format t "  ~A~%" (symbol-name s))))

(sb-ext:quit)
