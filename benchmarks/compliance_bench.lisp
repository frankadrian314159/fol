(in-package :fol.benchmarks)

(defun run-transpiled-compliance ()
  (cl:let ((cl:*standard-output* (cl:make-broadcast-stream)))
    (cl:funcall (cl:find-symbol "COMPLIANCE" "test-compliance"))))

(defun run-cl-compliance ()
  (cl:funcall (cl:find-symbol "COMPLIANCE-TEST" "COMPLIANCE-CL")))
