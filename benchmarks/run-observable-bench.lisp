(require :asdf)
(pushnew #p"c:/Users/frank/Projects/FOL/fol/src/" asdf:*central-registry*)

(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file quicklisp-init)
      (load quicklisp-init)
      (format t "Quicklisp not found.~%")))

(dolist (dep '(:fset :sycamore :closer-mop :uuid :bordeaux-threads :usocket :cl-ppcre :fiveam))
  (if (find-package :ql)
      (uiop:symbol-call :ql :quickload dep)
      (asdf:load-system dep)))

(asdf:load-system :fol-compiler)

(load "benchmarks/lisp-code/observable.lisp")
(load "benchmarks/transpiled-fol-code/observable.lisp")

(in-package :cl-user)

(defun cl-observable-bench (n)
  (let ((s (observable-cl:make-sensor :name "S1" :reading 0 :status :normal)))
    (dotimes (i n s)
      (let ((val (if (zerop (mod i 100)) 60 1)))
        (multiple-value-bind (new-s change)
            (observable-cl:update-sensor-slot s 'observable-cl::reading
                                              (+ (observable-cl:sensor-reading s) val))
          (observable-cl:on-change change)
          (setf s new-s))))))

(defun run-benchmarks ()
  (let ((n 1000000))
    (format t "----------------------------------------------------~%")
    (format t "Benchmark: Observable (N=~D)~%" n)

    (format t "~%--- Common Lisp (Optimized) ---~%")
    (sb-ext:gc :full t)
    (let ((s1 (get-internal-real-time))
          (b1 (sb-ext:get-bytes-consed)))
      (cl-observable-bench n)
      (let ((t1 (/ (- (get-internal-real-time) s1) (float internal-time-units-per-second)))
            (m1 (- (sb-ext:get-bytes-consed) b1)))
        (format t "  Real Time:    ~,3F s~%" t1)
        (format t "  Bytes Consed: ~,2F MB~%" (/ m1 1048576.0))

        (format t "~%--- FOL (Transpiled) ---~%")
        (sb-ext:gc :full t)
        (let ((s2 (get-internal-real-time))
              (b2 (sb-ext:get-bytes-consed)))
          (observable::run-bench n)
          (let ((t2 (/ (- (get-internal-real-time) s2) (float internal-time-units-per-second)))
                (m2 (- (sb-ext:get-bytes-consed) b2)))
            (format t "  Real Time:    ~,3F s~%" t2)
            (format t "  Bytes Consed: ~,2F MB~%" (/ m2 1048576.0))

            (format t "~%--- Comparison ---~%")
            (format t "  Time Ratio:   ~,2Fx~%" (if (> t1 0) (/ t2 t1) 0))
            (format t "  Memory Ratio: ~,2Fx~%" (if (> m1 0) (/ (float m2) (float m1)) 0))))))))

(run-benchmarks)
(sb-ext:exit :code 0)
