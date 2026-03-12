(require :asdf)
(let ((ql-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file ql-init) (load ql-init)))
(pushnew (truename "src/") asdf:*central-registry*)
(ql:quickload :fol-compiler :silent t)

(in-package :cl-user)

(defun simulate-runner (filename)
  (let* ((path (asdf:system-relative-pathname :fol-compiler (format nil "tests/fol-code/~A" filename)))
         (*package* (find-package :fol.core)))
    (format t "Simulating runner for ~A...~%" path)
    (with-open-file (s path)
      (loop for form = (fol.compiler.reader:fol-read s nil :eof)
            while (not (eq form :eof))
            do (progn
                (format t "Form: ~S~%" form)
                (let* ((transpiled (fol.compiler:compile-form form))
                       (code (fol.compiler:compilation-result-code transpiled)))
                  (format t "Evaluating: ~S~%" code)
                  (eval code)))))))

(simulate-runner "macros_test.fol")
(sb-ext:exit)
