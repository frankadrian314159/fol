(require :asdf)
(let ((ql-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file ql-init) (load ql-init)))
(pushnew (truename "src/") asdf:*central-registry*)
(ql:quickload :fol-compiler :silent t)

(in-package :fol.core)

(handler-case
    (progn
      (format t "--- Testing dotimes ---~%")
      (let ((acc (atom 0)))
        (dotimes [i 3] (swap! acc inc))
        (format t "Acc (expected 3): ~A~%" (deref acc)))

      (format t "--- Testing dotimes with index ---~%")
      (let ((acc2 (atom 0)))
        (dotimes [i 5] (swap! acc2 (fn [a] (+ a i))))
        (format t "Acc2 (expected 10): ~A~%" (deref acc2)))

      (format t "--- Testing doseq ---~%")
      (let ((sum-vec (atom 0)))
        (doseq [x [1 2 3]] (swap! sum-vec (fn [a] (+ a x))))
        (format t "Sum-vec (expected 6): ~A~%" (deref sum-vec))))
  (error (e)
    (format t "Caught ERROR: ~A~%" e)
    (sb-ext:exit :code 1)))

(sb-ext:exit)
