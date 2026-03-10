(require :asdf)
(let ((asd-path (merge-pathnames "src/fol-compiler.asd" (truename "."))))
  (asdf:load-asd asd-path))
(asdf:load-system :fol-compiler/core)

(defun cl-user::load-fol-file (path)
  (with-open-file (in path)
    (let ((cl:*readtable* fol.compiler.reader:*fol-readtable*))
      (handler-bind ((error (lambda (c)
                              (format t "Compilation Error: ~A~%" c)
                              (uiop:print-backtrace)
                              (sb-ext:exit :code 1))))
        (loop for form = (cl:read in nil :eof)
              until (eq form :eof)
              do (let* ((compiled (fol.compiler:compile-form form))
                        (code (fol.compiler:compilation-result-code compiled)))
                   (cl:eval code)))))))

(format t "Loading PLSim...~%")
(cl-user::load-fol-file "benchmarks/fol-code/plsim.fol")
(format t "Loading 8x32x32-9000.fol...~%")
;; We need to make sure 8x32x32-9000.fol loads into PLSIM package if it's designed that way, 
;; but the file has (in-package "lsim"). 
;; The run-all-benchmarks.lisp handles this by redefining the package or loading it twice.
;; In our case, we can just change the in-package in the file or temporarily shadow it.
(cl-user::load-fol-file "benchmarks/fol-code/8x32x32-9000.fol")

(format t "Running parallel simulation...~%")
(handler-bind ((error (lambda (c)
                        (format t "Runtime Error: ~A~%" c)
                        (uiop:print-backtrace)
                        (sb-ext:exit :code 1))))
  (funcall (find-symbol "RUN-BENCH" "PLSIM"))
  (format t "Done.~%"))
(sb-ext:exit :code 0)
