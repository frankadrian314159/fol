(require :asdf)
(pushnew #p"c:/Users/frank/Projects/FOL/fol/src/" asdf:*central-registry*)
(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file quicklisp-init)
      (load quicklisp-init)
      (format t "Quicklisp not found.~%")))
(asdf:load-system :fol-compiler)

(format t "Package FOL.CORE: ~A~%" (find-package :fol.core))
(let ((ext-syms '()))
  (do-external-symbols (s :fol.core) (push s ext-syms))
  (format t "Ext count: ~D~%" (length ext-syms))
  (format t "Conflicting with CL: ~D~%" 
    (loop for s in ext-syms 
          when (find-symbol (symbol-name s) :cl)
          count 1)))

(sb-ext:exit)
