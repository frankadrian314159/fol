(with-open-file (s "c:/Users/frank/Projects/FOL/fol/src/collection-primitives.lisp")
  (let ((count 0)
        (line 1)
        (col 0))
    (loop
     (let ((c (read-char s nil :eof)))
       (if (eq c :eof)
           (return (format t "Final Balance: ~D~%" count))
           (progn
            (incf col)
            (when (eq c #\Newline) (incf line) (setf col 0))
            (if (eq c #\() (incf count))
            (if (eq c #\)) (decf count))
            (when (< count 0) (return (format t "Unmatched ) at ~D:~D~%" line col)))))))))
