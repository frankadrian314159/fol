;;; Just compile ray-tracer without running
(in-package :cl-user)

(push (truename "src") asdf:*central-registry*)

;; Load compiler
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system :fol-compiler))

;; Compile FOL to Lisp
(format t "~&Compiling ray-tracer.fol...~%")
(let ((source-path (truename "benchmarks/ray-tracer.fol"))
      (lisp-path (make-pathname :name "ray-tracer-compiled" :type "lisp" :defaults (truename "benchmarks/"))))

  (fol.compiler:compile-file source-path :output lisp-path)
  (format t "~&Compiled to: ~A~%" lisp-path)
  (format t "~&First 50 lines of compiled output:~%")
  (with-open-file (f lisp-path)
    (loop for i below 50
          for line = (read-line f nil)
          while line
          do (format t "~3D: ~A~%" i line))))
