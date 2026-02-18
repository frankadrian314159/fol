(in-package :fol.user)
(defun test-reader ()
  (let ((*readtable* fol.compiler.reader:*fol-readtable*))
    (let ((v (read-from-string "[1 2 3]")))
      (format t "Read: ~SType: ~SVector-p: ~S" v (type-of v) (fol.compiler::fol-vector-p v)))))

(test-reader)
