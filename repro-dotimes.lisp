(require :asdf)
(let ((ql-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file ql-init) (load ql-init)))
(ql:quickload :fiveam :silent t)
(pushnew (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(in-package :fol.core)

(let* ((form '(do
                (def acc (atom 0))
                (dotimes (i 3) (swap! acc (fn (a) (+ a 1))))
                (@acc)))
       (result (fol.compiler:compile-form form))
       (code (fol.compiler:compilation-result-code result))
       (errors (fol.compiler:compilation-result-errors result)))
  (if errors
      (format t "Compilation Errors:~%~S~%" errors)
      (progn
        (format t "Transpiled code:~%~S~%" code)
        (let ((val (eval code)))
          (format t "Result: ~S~%" val)
          (if (= val 3)
              (format t "SUCCESS~%")
              (format t "FAILURE: expected 3, got ~S~%" val))))))

(in-package :cl-user)
(sb-ext:exit)
