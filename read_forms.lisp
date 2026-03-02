(load "c:/Users/frank/Projects/FOL/fol/src/package.lisp")
(with-open-file (s "c:/Users/frank/Projects/FOL/fol/src/collection-primitives.lisp")
  (loop
   (let ((form (read s nil :eof)))
     (if (eq form :eof) (return (format t "Done reading all forms.~%"))
         (format t "Read form starting with: ~S~%" (if (listp form) (car form) form))))))
