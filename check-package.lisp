(load "fol.asd")
(ql:quickload :fol-compiler)
(in-package :cl-user)
(format t "MAP in FOL.USER: ~A (Home: ~A)~%"
  (find-symbol "MAP" :fol.user)
  (package-name (symbol-package (find-symbol "MAP" :fol.user))))
(format t "REDUCE in FOL.USER: ~A (Home: ~A)~%"
  (find-symbol "REDUCE" :fol.user)
  (package-name (symbol-package (find-symbol "REDUCE" :fol.user))))
(format t "MAKE in FOL.USER: ~A (Home: ~A)~%"
  (find-symbol "MAKE" :fol.user)
  (when (find-symbol "MAKE" :fol.user)
        (package-name (symbol-package (find-symbol "MAKE" :fol.user)))))
(format t "GET in FOL.USER: ~A (Home: ~A)~%"
  (find-symbol "GET" :fol.user)
  (package-name (symbol-package (find-symbol "GET" :fol.user))))
