(require :asdf)
(pushnew (truename "src/") asdf:*central-registry*)
(let ((ql (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (when (probe-file ql) (load ql)))
(dolist (dep '(:fset :sycamore :closer-mop :uuid :bordeaux-threads :usocket :cl-ppcre :fiveam))
  (if (find-package :ql)
      (uiop:symbol-call :ql :quickload dep :silent t)
      (asdf:load-system dep)))
(asdf:load-system :fol-compiler)

(handler-case
  (let ((*readtable* fol.compiler::*fol-readtable*)
        (*package* (find-package :fol.core)))
    (with-open-file (in (truename "benchmarks/fol-code/ast-optimizer.fol") :direction :input)
      (let ((form-count 0))
        (loop for form = (fol.compiler::fol-read in nil :eof)
              until (eq form :eof)
              do (progn
                   (incf form-count)
                   (handler-case
                     (let ((result (fol.compiler:compile-form form)))
                       (if (fol.compiler:compilation-result-errors result)
                           (progn
                             (format t "~%COMPILE ERROR at form ~D: ~A~%" form-count
                                     (fol.compiler:compilation-result-errors result))
                             (format t "Form was: ~S~%" form))
                           (format t "Form ~D OK~%" form-count)))
                     (error (e)
                       (format t "~%EXCEPTION at form ~D: ~A~%" form-count e)
                       (format t "Form was: ~S~%" form)
                       (sb-debug:print-backtrace :count 10)
                       (return))))))))
  (error (e)
    (format t "~%TOP-LEVEL ERROR: ~A~%" e)
    (sb-debug:print-backtrace :count 10)))

(sb-ext:exit :code 0)
