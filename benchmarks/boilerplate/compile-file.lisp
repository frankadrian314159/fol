(in-package :cl-user)
(require :asdf)

;; Try to load Quicklisp
(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file quicklisp-init)
      (load quicklisp-init)
      (format t "Quicklisp not found at ~A~%" quicklisp-init)))

(defun load-dependency (dep)
  (format t "Loading dependency: ~A...~%" dep)
  (if (find-package :ql)
      (uiop:symbol-call :ql :quickload dep)
      (asdf:load-system dep)))

(defun compile-fol-file (source-path output-path)
  (let ((source (pathname source-path))
        (output (pathname output-path))
        ;; Explicitly load dependencies as requested
        (dependencies '(:fset :sycamore :closer-mop :uuid :bordeaux-threads :usocket :cl-ppcre :fiveam)))

    (pushnew #p"c:/Users/frank/Projects/FOL/fol/src/" asdf:*central-registry*)

    (handler-case
        (progn
         (dolist (dep dependencies)
           (load-dependency dep))

         (format t "Loading fol-compiler...~%")
         ;; Force reload to ensure latest compiler code is used
         (asdf:load-system :fol-compiler :force t))
      (error (c)
        (format *error-output* "Failed to load dependencies or system: ~A~%" c)
        (sb-ext:exit :code 1)))

    (format t "~%Compiling ~A to ~A...~%" source output)
    (handler-case
        (uiop:symbol-call :fol.compiler :compile-file source :output output)
      (error (c)
        (format *error-output* "Compilation failed: ~A~%" c)
        (sb-ext:exit :code 1)))

    (format t "~%Compilation finished.~%")))
