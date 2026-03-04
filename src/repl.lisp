(in-package :fol.repl)

;; We use CL standard variables *, **, ***, +, ++, +++, /, //, ///.
;; They are already available via (:use cl).

(defun repl (&key (in *in*) (out *out*))
  "A simple Read-Eval-Print Loop for FOL.
   Maintains standard CL REPL variables:
   * ** *** : Primary result history
   / // /// : Value list history
   + ++ +++ : Form history"
  (let ((*readtable* fol.compiler.reader:*fol-readtable*))
    (format out "~&Welcome to FOL REPL~%")
    (loop
     (format out "~&fol> ")
     (force-output out)
     (let ((input (read in nil :eof)))
       (when (eq input :eof)
             (return))

       ;; Update form history (+ ++ +++)
       (shiftf +++ ++ + input)
       ;; - is the form currently being evaluated
       (let ((- input))
         (handler-case
             (let* ((compiled (fol.compiler:compile-form input))
                    (code (fol.compiler:compilation-result-code compiled)))
               ;; Eval the compiled CL code
               (let ((values (multiple-value-list (eval code))))

                 ;; Update value history (/ // ///)
                 (shiftf /// // / values)

                 ;; Update primary result history (* ** ***)
                 (shiftf *** ** * (first values))

                 ;; Print primary result
                 (format out "~&~A~%" (first values))))

           (error (e)
             (format out "~&Error: ~A~%" e))))))))

;;; Compilation Functions

(defun compile-fol-string (string)
  "Compiles a string holding a FOL form. Returns the compiled CL form."
  (fol.compiler:compile-form (fol-read-from-string string)))

(defun compile-fol-file (path)
  "Compiles a file holding a FOL program. Returns the path to the compiled file."
  (fol.compiler:compile-file path))

;;; Execution Functions

(defun run-fol-string (string)
  "Compiles and runs a FOL string. Returns the result of evaluation.
   Signals an error if compilation failed."
  (let* ((compiled (compile-fol-string string))
         (errors (fol.compiler:compilation-result-errors compiled)))
    (when errors
      (error "~{~A~^~%~}" errors))
    (eval (fol.compiler:compilation-result-code compiled))))

(defun run-fol-file (path)
  "Compiles and runs a FOL file."
  (let ((compiled-file (compile-fol-file path)))
    (load compiled-file)))
