(require :asdf)
(let ((ql-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file ql-init) (load ql-init)))
(ql:quickload :fiveam :silent t)
(pushnew (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(in-package :fol.core)

(format t "Starting compilation...~%")
(handler-case
    (let* ((form '(dotimes (i 3) (swap! acc inc)))
           (result (fol.compiler:compile-form form)))
      (format t "Transpiled: ~S~%" (fol.compiler:compilation-result-code result))
      (format t "Errors: ~S~%" (fol.compiler:compilation-result-errors result)))
  (error (e)
    (format t "CRASH: ~A~%" e)))

(sb-ext:exit)
