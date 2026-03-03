(ql:quickload :fol-compiler)

(defpackage :fol.compiler.reader)

(defpackage :fol-repl-server (:use :cl :usocket))
(in-package :fol-repl-server)


(defun start-server (&optional (port 9010))
  (format t "~%[FOL REPL] Starting up on port ~A...~%" port)
  (let ((server (socket-listen "127.0.0.1" port :reuse-address t)))
    (unwind-protect
         (loop
           (let* ((connection (socket-accept server))
                  (stream (socket-stream connection)))
             (unwind-protect
                  (let ((output-capture (make-string-output-stream))
                        (last-result nil)
                        ;; Save the main terminal stream so we can still print debug logs
                        (console-out *standard-output*)) 
                    
                    ;; Bind the package, readtable, and capture stream for the whole file
                    (let ((*package* (find-package :fol.compiler))
                          (*readtable* fol.compiler.reader::*fol-readtable*)
                          (*standard-output* output-capture))
                      (handler-case
                          (loop
                            ;; Read one form at a time until the stream hits the FIN packet (:eof)
                            (let ((form (read stream nil :eof)))
                              (when (eq form :eof)
                                (return)) ;; Break the loop when all text is consumed
                              
                              (format console-out "[FOL REPL] Evaluating: ~S~%" form)
                              
                              ;; Evaluate and overwrite last-result
                              (setf last-result (eval (fol.compiler::compile-form form)))))
                        (error (e) 
                          (setf last-result (format nil "ERROR: ~A" e)))))
                    
                    ;; Send the combined captured output and the final result back to VS Code
                    (format stream "~A=> ~A~%"
                            (get-output-stream-string output-capture)
                            last-result)
                    (force-output stream))
               (socket-close connection))))
      (socket-close server))))
