(require :asdf)
(pushnew #p"c:/Users/frank/Projects/FOL/fol/src/" asdf:*central-registry*)

;; Load dependencies
(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (if (probe-file quicklisp-init)
      (load quicklisp-init)
      (format t "Quicklisp not found.~%")))

(dolist (dep '(:fset :sycamore :closer-mop :uuid :bordeaux-threads :usocket :cl-ppcre :fiveam))
  (if (find-package :ql)
      (uiop:symbol-call :ql :quickload dep)
      (asdf:load-system dep)))

(asdf:load-system :fol-compiler)

;; Load Lisp version
(load "benchmarks/lisp-code/compliance.lisp")
;; Load Transpiled FOL version
(load "benchmarks/transpiled-fol-code/compliance.lisp")

(in-package :cl-user)

(defun run-benchmarks ()
  (format t "----------------------------------------------------~%")
  (format t "Benchmark: Trade Compliance Validation~%")
  (format t "Iterations: 1,000,000 checks (250 runs of 4,000)~%")

  (let ((n 250))
    ;; CL Run
    (format t "~%--- Common Lisp (Optimized) ---~%")
    (sb-ext:gc :full t)
    (let ((start-time (get-internal-real-time))
          (start-bytes (sb-ext:get-bytes-consed)))
      (dotimes (i n)
        (test-compliance-cl::run-bench))
      (let ((end-time (get-internal-real-time))
            (end-bytes (sb-ext:get-bytes-consed)))
        (let ((time (/ (- end-time start-time) (float internal-time-units-per-second)))
              (bytes (- end-bytes start-bytes)))
          (format t "  Real Time:    ~,3F s~%" time)
          (format t "  Bytes Consed: ~,2F MB~%" (/ bytes (* 1024.0 1024.0)))

          ;; FOL Run
          (format t "~%--- FOL (Transpiled) ---~%")
          (sb-ext:gc :full t)
          (let ((start-time2 (get-internal-real-time))
                (start-bytes2 (sb-ext:get-bytes-consed)))
            (dotimes (i n)
              (test-compliance::run-bench))
            (let ((end-time2 (get-internal-real-time))
                  (end-bytes2 (sb-ext:get-bytes-consed)))
              (let ((time2 (/ (- end-time2 start-time2) (float internal-time-units-per-second)))
                    (bytes2 (- end-bytes2 start-bytes2)))
                (format t "  Real Time:    ~,3F s~%" time2)
                (format t "  Bytes Consed: ~,2F MB~%" (/ bytes2 (* 1024.0 1024.0)))

                (format t "~%--- Comparison ---~%")
                (format t "  Time Ratio:   ~,2Fx~%" (if (> time 0) (/ time2 time) 0))
                (format t "  Memory Ratio: ~,2Fx~%" (if (> bytes 0) (/ bytes2 bytes) 0))))))))))

(run-benchmarks)
(sb-ext:exit :code 0)
