#!/usr/bin/env sbcl --script
;;; Simple profiling of BFS and Quicksort
;;; Run: sbcl --noinform --script simple-profile.lisp

(require :asdf)
(pushnew #p"c:/Users/frank/Projects/FOL/fol/src/" asdf:*central-registry*)

(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file quicklisp-init) (load quicklisp-init)))

(dolist (dep '(:fset :sycamore :closer-mop :uuid :bordeaux-threads :usocket :cl-ppcre :fiveam))
  (if (find-package :ql)
      (uiop:symbol-call :ql :quickload dep)
      (asdf:load-system dep)))

(asdf:load-system :fol-compiler)
(require :sb-sprof)

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; CL Implementations
;;;; ─────────────────────────────────────────────────────────────────────────

(defun cl-bfs (n)
  "CL BFS with lazy distance initialization"
  (let ((graph (make-array n))
        (dists (make-hash-table :size n :test #'eql)))
    (dotimes (i (1- n)) (setf (svref graph i) (list (1+ i))))
    (setf (svref graph (1- n)) nil)
    (setf (gethash 0 dists) 0)
    (let ((q (list 0)))
      (loop while q do
        (let* ((u (pop q))
               (d (gethash u dists)))
          (dolist (v (svref graph u))
            (unless (gethash v dists)
              (setf (gethash v dists) (1+ d))
              (nconc q (list v)))))))
    dists))

(defun cl-qsort (arr low high)
  "CL quicksort"
  (when (< low high)
    (let ((pivot (aref arr high)) (i (1- low)))
      (loop for j from low below high do
        (when (<= (aref arr j) pivot)
          (incf i)
          (rotatef (aref arr i) (aref arr j))))
      (incf i)
      (rotatef (aref arr i) (aref arr high))
      (cl-qsort arr low (1- i))
      (cl-qsort arr (1+ i) high)))
  arr)

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; Benchmark Results
;;;; ─────────────────────────────────────────────────────────────────────────

(format t "~%=== BFS (N=20,000) ===~%")
(let ((n 20000))
  (format t "~%CL CPU Profile:~%")
  (sb-ext:gc :full t)
  (sb-sprof:with-profiling (:mode :cpu :sample-interval 0.001
                            :report :flat :loop nil :reset t)
    (dotimes (i 5) (cl-bfs n))))

(format t "~%=== Quicksort (N=5,000) ===~%")
(let ((n 5000))
  (let ((test-data (make-array n)))
    (dotimes (i n) (setf (aref test-data i) (random 100000)))
    (format t "~%CL CPU Profile:~%")
    (sb-ext:gc :full t)
    (sb-sprof:with-profiling (:mode :cpu :sample-interval 0.001
                              :report :flat :loop nil :reset t)
      (dotimes (i 5)
        (let ((arr (copy-seq test-data)))
          (cl-qsort arr 0 (1- n)))))))

(format t "~%Done.~%")
(sb-ext:exit)
