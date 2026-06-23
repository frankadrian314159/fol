(require :asdf)
(pushnew (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

;; Load all benchmark transpiled code
(defparameter *benchmarks*
  '(("ast-optimizer-balanced" "benchmarks/transpiled-fol-code/ast-optimizer-balanced.lisp")
    ("compliance" "benchmarks/transpiled-fol-code/compliance.lisp")
    ("derived-value-invalidation" "benchmarks/transpiled-fol-code/derived-value-invalidation.lisp")
    ("eval" "benchmarks/transpiled-fol-code/eval.lisp")
    ("event-sourcing" "benchmarks/transpiled-fol-code/event-sourcing.lisp")
    ("interpreter" "benchmarks/transpiled-fol-code/interpreter.lisp")
    ("observable" "benchmarks/transpiled-fol-code/observable.lisp")))

(format t "~%========================================~%")
(format t "FOL Benchmark Hotspot Analysis~%")
(format t "========================================~%~%")

(dolist (bench *benchmarks*)
  (destructuring-bind (name path) bench
    (handler-case
        (progn
          (format t "Loading ~A...~%" name)
          (load path :verbose nil :print nil)
          (format t "  ~A loaded~%" name))
      (error (e)
        (format t "  ERROR loading ~A: ~A~%" name e)))))

(format t "~%========================================~%")
(format t "Running Benchmarks~%")
(format t "========================================~%~%")

;; Try to find and run benchmark functions
(let ((bench-results nil))
  (dolist (bench *benchmarks*)
    (destructuring-bind (name path) bench
      (let ((run-fn-name (intern (format nil "RUN-~:@(~A~)" name)))
            (bench-fn-name (intern (format nil "BENCH-~:@(~A~)" name))))
        (cond
          ((find-symbol (string-upcase name))
           (format t "~A: Package found~%" name))
          ((fboundp run-fn-name)
           (format t "~A: Running via ~A...~%" name run-fn-name)
           (let ((start (get-internal-run-time)))
             (funcall run-fn-name)
             (let ((elapsed (/ (- (get-internal-run-time) start)
                              (float internal-time-units-per-second))))
               (format t "  Time: ~,3F s~%" elapsed)
               (push (cons name elapsed) bench-results))))
          ((fboundp bench-fn-name)
           (format t "~A: Running via ~A...~%" name bench-fn-name)
           (let ((start (get-internal-run-time)))
             (funcall bench-fn-name)
             (let ((elapsed (/ (- (get-internal-run-time) start)
                              (float internal-time-units-per-second))))
               (format t "  Time: ~,3F s~%" elapsed)
               (push (cons name elapsed) bench-results))))
          (:else
           (format t "~A: No benchmark function found~%" name))))))

  (format t "~%========================================~%")
  (format t "Summary~%")
  (format t "========================================~%~%")
  (if bench-results
      (let ((total (reduce #'+ (mapcar #'cdr bench-results) :initial-value 0)))
        (format t "Benchmark Results:~%")
        (dolist (result (reverse bench-results))
          (format t "  ~20A: ~8,3F s~%" (car result) (cdr result)))
        (format t "~%Total Time: ~,3F s~%" total))
      (format t "No benchmarks executed~%")))

(sb-ext:exit :code 0)
