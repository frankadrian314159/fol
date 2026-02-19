(in-package :cl-user)
(require :asdf)

;; Initialize Quicklisp
(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (when (probe-file quicklisp-init)
        (load quicklisp-init)))

;; Load dependencies
(defun load-deps ()
  (let ((deps '(:fset :sycamore :closer-mop :uuid :bordeaux-threads :usocket :cl-ppcre :fiveam)))
    (dolist (d deps)
      (if (find-package :ql)
          (uiop:symbol-call :ql :quickload d)
          (asdf:load-system d)))))

(load-deps)

;; Register and load FOL compiler system
(pushnew #p"c:/Users/frank/Projects/FOL/fol/src/" asdf:*central-registry*)
(format t "Loading fol-compiler...~%")
(asdf:load-system :fol-compiler :force t)

;; Load and run the transpiled file
(format t "~%--- Running compliance.lisp ---~%")
(handler-case
    (load "benchmarks/transpiled-fol-code/compliance.lisp")
  (error (c)
    (format *error-output* "~%Error running compliance.lisp: ~A~%" c)
    (sb-ext:exit :code 1)))

(format t "~%--- Done ---~%")
