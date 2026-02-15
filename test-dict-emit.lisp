;;; Test what {} compiles to

(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler :force t)

(format t "~%Testing empty dict {}:~%")
(let ((result (fol.compiler:compile-form
               (fol.compiler.reader:fol-read-from-string "{}"))))
  (prin1 (fol.compiler:compilation-result-code result))
  (terpri))

(format t "~%Testing dict {:a 1}:~%")
(let ((result (fol.compiler:compile-form
               (fol.compiler.reader:fol-read-from-string "{:a 1}"))))
  (prin1 (fol.compiler:compilation-result-code result))
  (terpri))

(sb-ext:quit)
