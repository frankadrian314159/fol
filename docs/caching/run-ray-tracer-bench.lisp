;;; Compile and run ray-tracer benchmark
(in-package :cl-user)

(push (truename "src") asdf:*central-registry*)

;; Load compiler
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system :fol-compiler))

;; Use FOL compiler's compile-file which handles reading with FOL readtable
(format t "~&Compiling ray-tracer.fol...~%")
(let* ((source-path (truename "benchmarks/ray-tracer.fol"))
       (lisp-path (make-pathname :name "ray-tracer-compiled" :type "lisp" :defaults source-path)))

  ;; Compile FOL to Lisp (using FOL readtable)
  (fol.compiler:compile-file source-path :output lisp-path)

  ;; Load compiled Lisp
  (format t "~&Loading compiled ray-tracer...~%")
  (load lisp-path)

  ;; Run benchmark
  (format t "~%Running benchmark...~%~%")
  (fol.core:ray-tracer:-main "10000"))
