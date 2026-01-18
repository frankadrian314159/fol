(in-package fol.repl)

;;; ============================================================================
;;; FOL REPL - A Common Lisp-like REPL using FOL evaluator
;;; ============================================================================

;;; REPL Variables (mimicking Common Lisp's REPL)
;;; *v1 *v2 *v3     - last three values returned
;;; *f1 *f2 *f3     - last three forms read
;;; *l1 *l2 *l3     - last three lists of values returned (for multiple values)

(defvar *v1 nil "Most recent value")
(defvar *v2 nil "Second most recent value")
(defvar *v3 nil "Third most recent value")

(defvar *f1 nil "Most recent form")
(defvar *f2 nil "Second most recent form")
(defvar *f3 nil "Third most recent form")

(defvar *l1 nil "Most recent list of values")
(defvar *l2 nil "Second most recent list of values")
(defvar *l3 nil "Third most recent list of values")

;;; REPL environment
(defvar *repl-env* nil "The REPL environment for variable bindings")

(defun reset-repl-env ()
  "Reset the REPL environment to initial state with FOL primitives."
  (setf *repl-env* (fol.eval:make-initial-env)))

(defun update-repl-vars (form value)
  "Update REPL variables after evaluation."
  ;; Update form history
  (setf *f3 *f2
        *f2 *f1
        *f1 form)

  ;; Update value history
  (setf *v3 *v2
        *v2 *v1
        *v1 value)

  ;; Update value list history (for future multiple-value support)
  (setf *l3 *l2
        *l2 *l1
        *l1 (list value)))

(defun repl-read ()
  "Read a form using the FOL syntax readtable."
  (let ((*readtable* (named-readtables:find-readtable 'fol.syntax:fol-syntax)))
    (read)))

(defun repl-eval (form)
  "Evaluate a form using fol-eval in the REPL environment."
  (fol.eval:fol-eval form *repl-env*))

(defun repl-print (value)
  "Print the result of evaluation."
  (format t "~S~%" value))

(defun repl-prompt ()
  "Display the REPL prompt."
  (format t "~%FOL> ")
  (force-output))

(defun start-repl ()
  "Start the FOL REPL.

   Commands:
   - Type FOL expressions to evaluate them
   - Use :quit or :q to exit
   - Use :reset to reset the environment

   REPL Variables:
   - *v1, *v2, *v3    : Last three values
   - *f1, *f2, *f3    : Last three forms
   - *l1, *l2, *l3    : Last three value lists"

  ;; Initialize REPL environment
  (reset-repl-env)

  ;; Print welcome message
  (format t "~%===================================~%")
  (format t "Welcome to the FOL REPL~%")
  (format t "Type :help for commands, :quit to exit~%")
  (format t "===================================~%")

  ;; Main REPL loop
  (loop
    (handler-case
        (progn
          (repl-prompt)
          (let ((form (repl-read)))
            ;; Check for REPL commands
            (cond
              ;; Quit command
              ((or (eq form :quit) (eq form :q))
               (format t "~%Goodbye!~%")
               (return-from start-repl))

              ;; Reset environment
              ((eq form :reset)
               (reset-repl-env)
               (format t "Environment reset.~%"))

              ;; Help command
              ((or (eq form :help) (eq form :h))
               (format t "~%FOL REPL Commands:~%")
               (format t "  :quit, :q     - Exit the REPL~%")
               (format t "  :reset        - Reset the environment~%")
               (format t "  :help, :h     - Show this help~%")
               (format t "~%REPL Variables:~%")
               (format t "  *v1, *v2, *v3    - Last three values~%")
               (format t "  *f1, *f2, *f3    - Last three forms~%")
               (format t "  *l1, *l2, *l3    - Last three value lists~%"))

              ;; Evaluate form
              (t
               (let ((value (repl-eval form)))
                 (update-repl-vars form value)
                 (repl-print value))))))

      ;; Handle errors gracefully
      (fol.env:fol-unbound-variable (e)
        (format t "Error: ~A~%" e))

      (error (e)
        (format t "Error: ~A~%" e))

      ;; Handle EOF (Ctrl+D)
      (end-of-file ()
        (format t "~%Goodbye!~%")
        (return-from start-repl)))))

;;; Convenience function
(defun repl ()
  "Alias for start-repl."
  (start-repl))
