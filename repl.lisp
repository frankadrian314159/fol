(in-package :fol.repl)

(defvar * nil)
(defvar ** nil)
(defvar *** nil)
(defvar + nil)
(defvar ++ nil)
(defvar +++ nil)
(defvar / nil)
(defvar // nil)
(defvar /// nil)

(defun repl (&optional (readtable fol.reader::*clojure-readtable*)
                       (stream *standard-input*)
                       (env (fol.eval:make-standard-env))
                       (eval-fn 'fol.eval:fol-eval)
                       (print-fn #'cl:print))
  "Read-Eval-Print Loop for FOL."
  (loop
    (format t "~&FOL> ")
    (force-output)
    (let ((form (fol.reader:fol-read stream nil 'eof readtable)))
      (if (eq form 'eof)
          (return)
          (progn
            ;; Update form history
            (shiftf +++ ++ + form)
            ;; Evaluate and get results (as a list to handle multiple values)
            (let ((results (multiple-value-list (funcall eval-fn form env))))
              ;; Update result history
              (shiftf /// // / results)
              (shiftf *** ** * (first results))
              ;; Print results
              (dolist (r results)
                (funcall print-fn r))))))))
