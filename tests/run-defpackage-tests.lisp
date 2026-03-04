;; tests/run-defpackage-tests.lisp
;; Simple automated test harness for defpackage transpilation
(in-package :cl-user)

(defparameter *project-root* #p"../")

(defun locate-and-load-compiler ()
  "Load the FOL compiler sources needed for the test. Adjust path as necessary." 
  (let ((src-dir (merge-pathnames #p"src/" *project-root*)))
    (load (merge-pathnames "package.lisp" src-dir))
    (load (merge-pathnames "compiler.lisp" src-dir))
    (load (merge-pathnames "ast.lisp" src-dir))))

(defun normalize-package-form (form)
  "Return a simple printed representation suitable for comparison." 
  (with-output-to-string (s)
    (pprint form s)))

(defun run-defpackage-test ()
  "Compile a sample defpackage and assert the emitted defpackage form contains expected pieces." 
  (locate-and-load-compiler)
  (let* ((test-form '(defpackage :my.test.pkg (:use :cl) (:export my-fn)))
         (res (fol.compiler:compile-form test-form))
         (errors (slot-value res 'errors))
         (emitted (slot-value res 'code)))
    (when errors
      (format t "Test failed: compile errors: ~S~%" errors)
      (return-from run-defpackage-test nil))
    (format t "Emitted form:~%~S~%~%" emitted)
    ;; Basic checks: emitted should be a CL:DEFPACKAGE form and include FOL.CORE and CL in :use
    (let ((printed (normalize-package-form emitted)))
      (unless (search "DEFPACKAGE" printed :test #'string-equal)
        (format t "FAIL: Emitted code is not a defpackage: ~%~S~%" printed)
        (return-from run-defpackage-test nil))
      (unless (or (search "FOL.CORE" printed :test #'string-equal)
                  (search "FOL.CORE" (string-upcase printed)))
        (format t "FAIL: FOL.CORE not present in :use: ~%~S~%" printed)
        (return-from run-defpackage-test nil))
      (unless (search "CL" printed :test #'string-equal)
        (format t "FAIL: CL not present in :use: ~%~S~%" printed)
        (return-from run-defpackage-test nil))
      (format t "PASS: defpackage emission looks reasonable.~%"))))

;; Run when loaded
(when (find-package :fol.compiler)
  ;; if already loaded, just run
  (run-defpackage-test))

(format t "Run-defpackage-tests.lisp loaded; call (run-defpackage-test) to execute.~%")
