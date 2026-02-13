;;; Transpile register-8bit.fol to register-8bit.lisp

(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(defun transpile-fol-file (input-file output-file)
  "Read FOL source from INPUT-FILE, compile to CL, write to OUTPUT-FILE."
  (let* ((fol-code (with-open-file (in input-file :direction :input)
                     (let ((contents (make-string (file-length in))))
                       (read-sequence contents in)
                       contents)))
         (reader-stream (make-string-input-stream fol-code))
         (compiled-forms '()))

    ;; Read and compile each FOL form
    (loop
      (let ((form (handler-case
                      (fol.compiler.reader:fol-read reader-stream nil :eof)
                    (end-of-file () :eof))))
        (when (eq form :eof)
          (return))

        ;; Compile the form
        (let* ((result (fol.compiler:compile-form form))
               (cl-code (fol.compiler:compilation-result-code result)))
          (push cl-code compiled-forms))))

    ;; Write to output file
    (with-open-file (out output-file :direction :output :if-exists :supersede)
      (format out ";;; Transpiled from ~A by FOL compiler~%~%"
              (file-namestring input-file))
      (format out ";;; This file was automatically generated. Do not edit directly.~%~%")
      (format out ";;; Requires lsim.lisp to be loaded first for the base primitives and DSL.~%~%")
      (dolist (form (nreverse compiled-forms))
        (prin1 form out)
        (terpri out)
        (terpri out)))))

;; Run the transpilation
(transpile-fol-file "fol-code/register-8bit.fol" "fol-code/register-8bit.lisp")
(format t "~%Transpilation complete: fol-code/register-8bit.fol -> fol-code/register-8bit.lisp~%")
(quit)
