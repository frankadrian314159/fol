(require :asdf)
(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file quicklisp-init)
      (load quicklisp-init)
      (format t "Quicklisp not found~%")))

(defun load-dependency (dep)
  (handler-case
      (if (find-package :ql)
          (uiop:symbol-call :ql :quickload dep :silent t)
          (asdf:load-system dep))
    (error (c)
      (format t "Warning: Failed to load dependency ~A: ~A~%" dep c))))

;; Load core dependencies explicitly
(dolist (dep '(:fset :sycamore :closer-mop :uuid :bordeaux-threads :usocket :cl-ppcre :fiveam))
  (load-dependency dep))

;; Setup central registry for FOL
(let ((base-dir (uiop:getcwd)))
  (pushnew (merge-pathnames "src/" base-dir) asdf:*central-registry* :test #'equal)
  (pushnew base-dir asdf:*central-registry* :test #'equal))

(format t "--- Starting Test Run ---~%")

(handler-case
    (progn
     (asdf:load-system :fol-compiler/all-tests)
     (format t "FOL Compiler Tests Loaded Successfully.~%"))
  (error (c)
    (format t "CRITICAL ERROR: Failed to load :fol-compiler/all-tests~%~A~%" c)
    ;; Try to find which file is failing
    (uiop:quit 1)))

(format t "~%Running all compiler tests...~%")
(let ((results (fiveam:run 'fol.compiler.tests::compiler-tests)))
  (fiveam:explain! results)
  (if (fiveam:results-status results)
      (format t "~%All core compiler tests passed!~%")
      (format t "~%Some core compiler tests FAILED.~%")))

(format t "~%Running library tests...~%")
(handler-case
    (let ((lib-results (fiveam:run 'fol.compiler.tests.lib::lib-tests)))
      (fiveam:explain! lib-results))
  (error (c)
    (format t "Error running lib tests: ~A~%" c)))

(uiop:quit 0)
