(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(format t "~%Checking fol.compiler.seq-functions:reduce...~%")
(format t "Bound?: ~A~%"  (fboundp 'fol.compiler.seq-functions:reduce))
(format t "Function: ~A~%" (fdefinition 'fol.compiler.seq-functions:reduce))

;; Try calling it directly
(format t "~%Calling it directly with a vector...~%")
(let ((v (fol.compiler.collection-functions:vector 1 2 3)))
  (let ((result (fol.compiler.seq-functions:reduce #'+ 0 v)))
    (format t "Result: ~A~%"  result)))

(sb-ext:quit)
