(in-package :fol.test-repl)

(defun test-repl ()
  "Test the FOL REPL using the standard environment.
   Feeds arithmetic and list operations to the REPL and captures output."
  (let* ((input-content (format nil "(+ 1 2)~%(* 10 20)~%(list 1 2 3)~%(+ * **)~%"))
         (output-stream (make-string-output-stream)))
    (with-input-from-string (input-stream input-content)
      (let ((*standard-output* output-stream)
            (*standard-input* input-stream))
        ;; Invoke the REPL.
        ;; We rely on the default arguments for readtable, env, and eval-fn
        ;; to use the standard environment as requested.
        (fol.repl:repl)))
    
    (let ((result (get-output-stream-string output-stream)))
      (format t "REPL Session Output:~%~A~%" result)
      result)))
