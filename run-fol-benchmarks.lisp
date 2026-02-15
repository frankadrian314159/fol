;;; Run FOL discrete event simulator benchmarks
;;; Compiles FOL code and runs benchmarks

(in-package :cl-user)

;; Load FOL compiler
(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

;; Create a package for the FOL code that has access to FOL runtime functions
(defpackage :lsim-fol
  (:use :cl)
  (:shadow list)
  (:import-from :fol.compiler.collections
                make collection-conj collection-seq storage-items
                <vector> <dict> <set> <bag> <priority-dict>
                priority-dict-peek-min priority-dict-pop-min)
  (:shadowing-import-from :fol.compiler.collection-functions
                vector dict set bag
                first rest get assoc dissoc conj size empty? count)
  (:shadowing-import-from :fol.compiler.primitive-functions
                zero? odd? even? symbol keyword)
  (:import-from :fol.compiler.primitives
                truthy? falsy?)
  (:import-from :fol.compiler.string-functions
                str)
  (:export make-nbit-register-from-gates make-test-events run-simulation))

;; Define true and false constants
(in-package :lsim-fol)
(defparameter true t)
(defparameter false nil)

;; Define bit-test function
(defun bit-test (integer index)
  "Test if bit at INDEX in INTEGER is set."
  (logbitp index integer))

(in-package :cl-user)

(defun compile-and-eval-fol-file (filepath)
  "Compile and evaluate a FOL file in the :lsim-fol package."
  (with-open-file (stream filepath :direction :input)
    (let ((*package* (find-package :lsim-fol)))
      (loop for form = (let ((*readtable* fol.compiler.reader:*fol-readtable*))
                        (read stream nil :eof))
            until (eq form :eof)
            do (let ((result (fol.compiler:compile-form form)))
                 (when (fol.compiler:compilation-result-errors result)
                   (format t "~%COMPILATION ERRORS:~%")
                   (dolist (err (fol.compiler:compilation-result-errors result))
                     (format t "  ~A~%" err))
                   (error "FOL compilation failed"))
                 (let ((code (fol.compiler:compilation-result-code result)))
                   (eval code)))))))

(format t "~%=== FOL Discrete Event Simulator Benchmarks ===~%~%")

(format t "Compiling and loading FOL code...~%")
(compile-and-eval-fol-file "lsim-fol.fol")
(format t "~%FOL code loaded successfully!~%~%")

;; Now define benchmark functions in CL that call the FOL functions

(defun run-fol-8bit-benchmark ()
  "Benchmark 8-bit register (40 components, 300 time units, 1000 iterations)."
  (format t "~%=== FOL 8-Bit Register Benchmark ===~%")

  (let* ((netlist-fol (funcall (intern "MAKE-NBIT-REGISTER-FROM-GATES" :lsim-fol) 8))
         (events-fol (funcall (intern "MAKE-TEST-EVENTS" :lsim-fol) 8 300))
         (netlist-size (fol.compiler.collection-functions:size netlist-fol))
         (events-size (fol.compiler.collection-functions:size events-fol))
         (monitored (let ((m (make-hash-table :test 'eq)))
                      (loop for i from 0 to 7
                            do (setf (gethash (intern (format nil "OUT~D" i) :keyword) m) t))
                      m)))

    (format t "Components: ~D~%" netlist-size)
    (format t "Events: ~D~%" events-size)
    (format t "Time units: 300~%")
    (format t "Using: FOL persistent data structures~%~%")

    (format t "Warming up...~%")
    (funcall (intern "RUN-SIMULATION" :lsim-fol) netlist-fol events-fol 300 monitored)
    (sb-ext:gc :full t)

    (format t "Running 1000 iterations...~%")
    (let ((times '())
          (start-bytes (sb-ext:get-bytes-consed)))
      (dotimes (i 1000)
        (when (zerop (mod i 100))
          (format t "  Iteration ~D/1000~%" i))
        (let ((start-time (get-internal-run-time)))
          (funcall (intern "RUN-SIMULATION" :lsim-fol) netlist-fol events-fol 300 monitored)
          (let ((elapsed (/ (- (get-internal-run-time) start-time)
                           internal-time-units-per-second)))
            (push elapsed times))))

      (let* ((end-bytes (sb-ext:get-bytes-consed))
             (total-consed (- end-bytes start-bytes))
             (sorted-times (sort (copy-list times) #'<))
             (mean (/ (reduce #'+ sorted-times) (length sorted-times)))
             (median (nth (floor (length sorted-times) 2) sorted-times))
             (min-time (first sorted-times))
             (max-time (first (last sorted-times)))
             (std-dev (sqrt (/ (reduce #'+ (mapcar (lambda (x) (expt (- x mean) 2))
                                                   sorted-times))
                              (length sorted-times)))))

        (format t "~%Results (FOL 8-bit, 1000 iterations):~%")
        (format t "  Mean:   ~,3F ms~%" (* 1000 mean))
        (format t "  Median: ~,3F ms~%" (* 1000 median))
        (format t "  Min:    ~,3F ms~%" (* 1000 min-time))
        (format t "  Max:    ~,3F ms~%" (* 1000 max-time))
        (format t "  StdDev: ~,3F ms~%" (* 1000 std-dev))
        (format t "  Total consed: ~,2F MB~%" (/ total-consed 1024.0 1024.0))
        (format t "  Per iteration: ~,2F KB~%~%" (/ total-consed 1000.0 1024.0))))))

(defun run-fol-32bit-benchmark ()
  "Benchmark 32-bit register (160 components, 1000 time units, 100 iterations)."
  (format t "~%=== FOL 32-Bit Register Benchmark ===~%")

  (let* ((netlist-fol (funcall (intern "MAKE-NBIT-REGISTER-FROM-GATES" :lsim-fol) 32))
         (events-fol (funcall (intern "MAKE-TEST-EVENTS" :lsim-fol) 32 1000))
         (netlist-size (fol.compiler.collection-functions:size netlist-fol))
         (events-size (fol.compiler.collection-functions:size events-fol))
         (monitored (let ((m (make-hash-table :test 'eq)))
                      (loop for i from 0 to 31
                            do (setf (gethash (intern (format nil "OUT~D" i) :keyword) m) t))
                      m)))

    (format t "Components: ~D~%" netlist-size)
    (format t "Events: ~D~%" events-size)
    (format t "Time units: 1000~%")
    (format t "Using: FOL persistent data structures~%~%")

    (format t "Warming up...~%")
    (funcall (intern "RUN-SIMULATION" :lsim-fol) netlist-fol events-fol 1000 monitored)
    (sb-ext:gc :full t)

    (format t "Running 100 iterations...~%")
    (let ((times '())
          (start-bytes (sb-ext:get-bytes-consed)))
      (dotimes (i 100)
        (when (zerop (mod i 10))
          (format t "  Iteration ~D/100~%" i))
        (let ((start-time (get-internal-run-time)))
          (funcall (intern "RUN-SIMULATION" :lsim-fol) netlist-fol events-fol 1000 monitored)
          (let ((elapsed (/ (- (get-internal-run-time) start-time)
                           internal-time-units-per-second)))
            (push elapsed times))))

      (let* ((end-bytes (sb-ext:get-bytes-consed))
             (total-consed (- end-bytes start-bytes))
             (sorted-times (sort (copy-list times) #'<))
             (mean (/ (reduce #'+ sorted-times) (length sorted-times)))
             (median (nth (floor (length sorted-times) 2) sorted-times))
             (min-time (first sorted-times))
             (max-time (first (last sorted-times)))
             (std-dev (sqrt (/ (reduce #'+ (mapcar (lambda (x) (expt (- x mean) 2))
                                                   sorted-times))
                              (length sorted-times)))))

        (format t "~%Results (FOL 32-bit, 100 iterations):~%")
        (format t "  Mean:   ~,3F ms~%" (* 1000 mean))
        (format t "  Median: ~,3F ms~%" (* 1000 median))
        (format t "  Min:    ~,3F ms~%" (* 1000 min-time))
        (format t "  Max:    ~,3F ms~%" (* 1000 max-time))
        (format t "  StdDev: ~,3F ms~%" (* 1000 std-dev))
        (format t "  Total consed: ~,2F MB~%" (/ total-consed 1024.0 1024.0))
        (format t "  Per iteration: ~,2F KB~%~%" (/ total-consed 100.0 1024.0))))))

;; Run both benchmarks
(handler-case
    (progn
      (run-fol-8bit-benchmark)
      (run-fol-32bit-benchmark)
      (format t "~%All FOL benchmarks completed successfully!~%"))
  (error (e)
    (format t "~%ERROR: ~A~%" e)
    (format t "Stacktrace:~%")
    (sb-debug:print-backtrace :stream *standard-output* :count 20)))

(sb-ext:quit)
