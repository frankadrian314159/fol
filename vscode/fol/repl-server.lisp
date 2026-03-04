(in-package :cl-user)

(defpackage :fol-repl-server
  (:use :cl :usocket :bordeaux-threads)
  (:export :start-server :stop-server))

(in-package :fol-repl-server)

(defvar *server-socket* nil)
(defvar *server-thread* nil)

(defun handle-client (client)
  "Handles an individual connection from the VS Code extension."
  (let* ((stream (socket-stream client))
         ;; Force the package to FOL.REPL so the reader finds FOL symbols
         (*package* (or (find-package :fol.repl) *package*)))
    (format t "~&--- [DEBUG] New connection. Using package: ~A ---~%" (package-name *package*))
    (force-output)
    (handler-case
        (loop
          (let ((form (read stream nil :eof)))
            (when (eq form :eof)
              (format t "~&--- [DEBUG] Client disconnected (EOF) ---~%")
              (return))
            
            (format t "~&--- [DEBUG] Received Form: ~S ---~%" form)
            (force-output)

            ;; Evaluate using the fol.repl logic defined in your system.
            ;; Errors are caught per-form and sent back as tagged responses
            ;; so the connection stays alive and the client sees the message.
            (handler-case
                (let ((result (uiop:symbol-call :fol.repl :run-fol-string
                                               (format nil "~S" form))))
                  (format t "~&--- [DEBUG] Evaluation Result: ~S ---~%" result)
                  (force-output)
                  (format stream "(:ok ~S)~%" (format nil "~S" result))
                  (finish-output stream))
              (error (c)
                (let ((msg (format nil "~A" c)))
                  (format t "~&--- [DEBUG] Eval Error: ~A ---~%" msg)
                  (force-output)
                  (format stream "(:error ~S)~%" msg)
                  (finish-output stream))))))
      (error (c)
        (format t "~&--- [DEBUG] Server Error during processing: ~A ---~%" c)
        (force-output)))
    (ignore-errors (socket-close client))))

(defun start-server (port)
  "Starts the REPL server on the specified port."
  (format t "~&--- [DEBUG] Attempting to start server on port ~A ---~%" port)
  (force-output)
  (setf *server-socket* (socket-listen "127.0.0.1" port :reuse-address t))
  (setf *server-thread* (bt:make-thread 
         (lambda ()
           (unwind-protect
                (loop
                  (let ((client (socket-accept *server-socket*)))
                    (bt:make-thread (lambda () (handle-client client))
                                    :name "FOL-Client-Handler")))
             (when *server-socket*
               (socket-close *server-socket*)
               (setf *server-socket* nil))))
         :name "FOL-REPL-Server-Main"))
  (format t "~&--- [DEBUG] Server thread running ---~%")
  (force-output))

(defun stop-server ()
  "Stops the running server."
  (when *server-socket*
    (socket-close *server-socket*)
    (setf *server-socket* nil)
    (format t "~&--- [DEBUG] Server stopped ---~%")
    (force-output)))