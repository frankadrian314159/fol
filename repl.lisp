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

(defun fol-form (string)
  "Parse STRING using the FOL reader and return the form.
   This allows tests to use FOL syntax like [1 2 3] and {:a 1} in test cases."
  (fol.reader:fol-read-from-string string))

(defun fol-test (form-string &optional env)
  "Evaluate FORM-STRING in the given ENV and return the result.
   FORM-STRING is parsed using the FOL reader."
  (let ((form (fol-form form-string))
        (active-env (or env (fol.eval:make-standard-env))))
    (fol.eval:fol-eval form active-env)))