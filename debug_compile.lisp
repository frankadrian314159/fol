(in-package :cl-user)
(require :asdf)

(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (when (probe-file quicklisp-init)
        (load quicklisp-init)))

(defun load-deps ()
  (let ((deps '(:fset :sycamore :closer-mop :uuid :bordeaux-threads :usocket :cl-ppcre :fiveam)))
    (dolist (d deps)
      (if (find-package :ql)
          (uiop:symbol-call :ql :quickload d)
          (asdf:load-system d)))))

(load-deps)
(pushnew #p"c:/Users/frank/Projects/FOL/fol/src/" asdf:*central-registry*)
(asdf:load-system :fol-compiler :force t)

(defun test-compile (content)
  (with-open-file (out "test_snippet.fol" :direction :output :if-exists :supersede)
    (write-string content out))
  (format t "~%Compiling: ~A~%" content)
  (handler-case
      (fol.compiler:compile-file "test_snippet.fol" :output "test_snippet.lisp")
    (error (c) (format t "Compiler Error: ~A~%" c) (return-from test-compile)))
  (format t "--- Output Content ---~%")
  (with-open-file (in "test_snippet.lisp")
    (loop for line = (read-line in nil)
          while line do (write-line line)))
  (format t "----------------------~%"))

(format t "~%Test: Complex Dict~%")
(test-compile "{:status :approved :id (gensym \"TRD\")}")

(format t "~%Test: Method with Dict~%")
(test-compile "(defmethod foo [x] {:status :ok})")
