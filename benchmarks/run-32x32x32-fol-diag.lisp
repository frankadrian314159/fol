(require :asdf)
(let ((asd-path (merge-pathnames "src/fol-compiler.asd" (truename "."))))
  (asdf:load-asd asd-path))
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system :fol-compiler/core :verbose nil))

(defun cl-user::load-fol-file (path)
  (with-open-file (in path)
    (let ((cl:*readtable* fol.compiler.reader:*fol-readtable*))
      (loop for form = (cl:read in nil :eof)
            until (eq form :eof)
            do (let* ((compiled (fol.compiler:compile-form form))
                      (code (fol.compiler:compilation-result-code compiled)))
                 (cl:eval code))))))

(cl-user::load-fol-file "benchmarks/fol-code/lsim.fol")
(cl-user::load-fol-file "benchmarks/fol-code/32x32x32-30000.fol")

(format t "~%--- Step 1: expand-netlist ---~%")
(force-output *standard-output*)

(let ((netlist (funcall (find-symbol "EXPAND-NETLIST" "LSIM")
                        (find-symbol "TOP32X32X32" "LSIM"))))
  (format t "expand-netlist OK, ~A components~%" (fol.compiler.collections:collection-size netlist))
  (force-output *standard-output*)

  (format t "~%--- Step 2: build connectivity ---~%")
  (force-output *standard-output*)
  (let* ((reg-fn   (find-symbol "REGISTER-CONNECTIVITY" "LSIM"))
         (red-fn   (find-symbol "REDUCE" "FOL.COMPILER.COLLECTION-FUNCTIONS"))
         (connectivity (funcall red-fn
                                (lambda (acc c) (funcall reg-fn c acc))
                                (make-hash-table)
                                netlist)))
    (format t "connectivity OK~%")
    (force-output *standard-output*)))

(format t "~%--- Diagnostic complete ---~%")
(sb-ext:exit :code 0)
