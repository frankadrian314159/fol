(in-package :cl-user)

(defpackage :fol.benchmarks
  (:use :cl)
  (:export :run-one :run-two :count-sloc))

(in-package :fol.benchmarks)

(defun get-bytes-consed ()
  "Returns total bytes consed so far (SBCL specific)."
  #+sbcl (cl:the (cl:unsigned-byte 64) (sb-ext:get-bytes-consed))
  #-sbcl 0) ;; Fallback to 0 if not SBCL

(defun count-sloc (file-path)
  "Counts Source Lines of Code (non-blank, non-comment) in a file."
  (if (probe-file file-path)
      (with-open-file (stream file-path)
        (loop for line = (read-line stream nil nil)
              while line
                count (let ((trimmed (string-trim '(#\Space #\Tab #\Newline #\Return) line)))
                        (and (not (zerop (length trimmed)))
                             (not (char= (char trimmed 0) #\;))))))
      0))

(defun measure-run (fn n)
  "Runs FN N times and returns (values total-time-seconds total-bytes-consed)."
  (sb-ext:gc :full t) ;; Force GC before run for cleaner stats
  (let ((start-time (get-internal-real-time))
        (start-bytes (get-bytes-consed)))
    (dotimes (i n)
      (funcall fn))
    (values (/ (- (get-internal-real-time) start-time) internal-time-units-per-second)
      (- (get-bytes-consed) start-bytes))))

(defun format-bytes (bytes)
  (cond ((< bytes 1024) (format nil "~D B" bytes))
        ((< bytes (* 1024 1024)) (format nil "~,2F KB" (/ bytes 1024.0)))
        ((< bytes (* 1024 1024 1024)) (format nil "~,2F MB" (/ bytes (* 1024.0 1024.0))))
        (t (format nil "~,2F GB" (/ bytes (* 1024.0 1024.0 1024.0))))))

(defun format-time (seconds)
  (cond ((< seconds 1e-6) (format nil "~,2F ns" (* seconds 1e9)))
        ((< seconds 1e-3) (format nil "~,2F us" (* seconds 1e6)))
        ((< seconds 1.0) (format nil "~,2F ms" (* seconds 1e3)))
        (t (format nil "~,2F s" seconds))))

(defun run-one (fn n &key (name "Benchmark") (loc 0))
  "Runs FN N times and reports stats."
  (format t "~&---------------------------------------------------~%")
  (format t "Benchmark: ~A~%" name)
  (format t "Iterations: ~D~%" n)
  (format t "Lines of Code (LOC): ~D~%" loc)

  (multiple-value-bind (total-time total-bytes)
      (measure-run fn n)
    (let ((avg-time (if (> n 0) (/ total-time n) 0))
          (avg-bytes (if (> n 0) (/ total-bytes n) 0)))
      (format t "Total Time: ~A~%" (format-time total-time))
      (format t "Amortized Time: ~A/op~%" (format-time avg-time))
      (format t "Total Memory: ~A~%" (format-bytes total-bytes))
      (format t "Amortized Memory: ~A/op~%" (format-bytes avg-bytes))
      (format t "---------------------------------------------------~%")
      (values total-time total-bytes avg-time avg-bytes))))

(defun run-two (fn1 fn2 n &key (name1 "Benchmark 1") (loc1 0) (name2 "Benchmark 2") (loc2 0))
  "Runs FN1 and FN2 N times each and reports stats and differences."
  (format t "~&===================================================~%")
  (format t "Comparing ~A vs ~A~%" name1 name2)
  (format t "Iterations: ~D~%" n)

  (format t "~&--- ~A ---~%" name1)
  (multiple-value-bind (t1 b1) (measure-run fn1 n)
    (let ((at1 (if (> n 0) (/ t1 n) 0))
          (ab1 (if (> n 0) (/ b1 n) 0)))
      (format t "LOC: ~D~%" loc1)
      (format t "Time: ~A (Total), ~A (Avg)~%" (format-time t1) (format-time at1))
      (format t "Memory: ~A (Total), ~A (Avg)~%" (format-bytes b1) (format-bytes ab1))

      (format t "~&--- ~A ---~%" name2)
      (multiple-value-bind (t2 b2) (measure-run fn2 n)
        (let ((at2 (if (> n 0) (/ t2 n) 0))
              (ab2 (if (> n 0) (/ b2 n) 0)))
          (format t "LOC: ~D~%" loc2)
          (format t "Time: ~A (Total), ~A (Avg)~%" (format-time t2) (format-time at2))
          (format t "Memory: ~A (Total), ~A (Avg)~%" (format-bytes b2) (format-bytes ab2))

          (format t "~&--- Comparison (~A vs ~A) ---~%" name1 name2)
          (let ((time-diff (- t1 t2))
                (time-ratio (if (> t2 0) (/ t1 t2) 0))
                (mem-diff (- b1 b2))
                (mem-ratio (if (> b2 0) (/ b1 b2) 0)))

            (format t "Time Diff: ~A (~,2fx)~%" (format-time (abs time-diff)) time-ratio)
            (if (< time-diff 0)
                (format t "  Result: ~A was faster by ~A~%" name1 (format-time (abs time-diff)))
                (format t "  Result: ~A was faster by ~A~%" name2 (format-time time-diff)))

            (format t "Memory Diff: ~A (~,2fx)~%" (format-bytes (abs mem-diff)) mem-ratio)
            (if (< mem-diff 0)
                (format t "  Result: ~A used less memory by ~A~%" name1 (format-bytes (abs mem-diff)))
                (format t "  Result: ~A used less memory by ~A~%" name2 (format-bytes mem-diff))))

          (format t "===================================================~%")
          (values t1 b1 t2 b2))))))
