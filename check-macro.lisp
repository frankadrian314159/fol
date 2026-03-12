(require :asdf)
(let ((ql-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file ql-init) (load ql-init)))
(ql:quickload :fiveam :silent t)
(pushnew (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(in-package :fol.macros)

(format t "Macroexpansion of dotimes [i 3]:~%~S~%" 
        (macroexpand-1 '(dotimes [i 3] (swap! acc (fn [a] (+ a 1))))))

(in-package :cl-user)
(sb-ext:exit)
