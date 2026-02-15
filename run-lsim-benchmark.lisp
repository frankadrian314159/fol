;;; Run benchmark for fol-code/lsim.fol (netlist DSL with pmapcat)
;;; Tests thread pool-based pmapcat with hierarchical component expansion

(in-package :cl-user)

;; Load FOL compiler
(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

;; Create a package for the FOL code
(defpackage :lsim
  (:use :cl)
  (:shadow list *modules* *primitives* *sim-context*)
  (:import-from :fol.compiler.collections
                make collection-conj collection-seq storage-items
                <vector> <dict> <set> <bag>)
  (:import-from :fol.compiler.persistent
                <persistent-object>)
  (:shadowing-import-from :fol.compiler.collection-functions
                vector dict set bag
                first rest get assoc dissoc conj size empty? count
                keys contains? update)
  (:shadowing-import-from :fol.compiler.seq-functions
                pmap pmapcat map reduce filter take-while drop-while sort-by
                concat into merge)
  (:shadowing-import-from :fol.compiler.primitive-functions
                zero? odd? even? symbol keyword nil? some?)
  (:import-from :fol.compiler.primitives
                truthy? falsy? make)
  (:import-from :fol.compiler.string-functions
                str)
  (:shadowing-import-from :fol.compiler.mutable
                <atom> atom swap! reset! deref)
  (:export run-simulation expand-netlist))

;; Define true and false constants
(in-package :lsim)
(defparameter true t)
(defparameter false nil)

(in-package :cl-user)

(defun compile-and-eval-fol-file (filepath)
  "Compile and evaluate a FOL file in the :lsim package."
  (with-open-file (stream filepath :direction :input)
    (let ((*package* (find-package :lsim)))
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

(format t "~%=== FOL Netlist DSL Benchmark (with pmapcat) ===~%~%")

(format t "Compiling and loading fol-code/lsim.fol...~%")
(compile-and-eval-fol-file "fol-code/lsim.fol")
(format t "FOL code loaded successfully!~%~%")

;; Load 32-bit register module definitions
(format t "Loading 32-bit register modules...~%")
(compile-and-eval-fol-file "fol-code/register-32bit.fol")
(format t "32-bit register modules loaded successfully!~%~%")

;; Helper function to create test events
(defun make-test-events-for-lsim (n-bits max-time)
  "Create test events for the lsim simulator."
  (let ((events '())
        (*package* (find-package :lsim)))
    ;; Initial values for all data inputs
    (loop for i from 0 to (1- n-bits)
          do (push (funcall (intern "DICT" :lsim)
                           :time 0
                           :node (intern (format nil "D~D" i) :keyword)
                           :value (oddp i))
                   events))

    ;; Clock edges and data changes
    (loop for time from 10 to (- max-time 5) by 10
          for pattern = (if (zerop (mod time 100)) #xAAAAAAAA #x55555555)
          do (progn
               ;; Clock high
               (push (funcall (intern "DICT" :lsim)
                             :time time
                             :node :clk
                             :value t)
                     events)
               ;; Clock low
               (push (funcall (intern "DICT" :lsim)
                             :time (+ time 5)
                             :node :clk
                             :value nil)
                     events)
               ;; Data changes every 50 time units
               (when (zerop (mod time 50))
                 (loop for i from 0 to (1- n-bits)
                       do (push (funcall (intern "DICT" :lsim)
                                        :time (+ time 2)
                                        :node (intern (format nil "D~D" i) :keyword)
                                        :value (logbitp i pattern))
                                events)))))
    (nreverse events)))

;; Create monitored nodes set
(defun make-monitored-nodes (n-bits)
  "Create set of monitored output nodes."
  (let ((nodes '())
        (*package* (find-package :lsim)))
    (loop for i from 0 to (1- n-bits)
          do (push (intern (format nil "Q~D" i) :keyword) nodes))
    (apply (intern "SET" :lsim) nodes)))

(defun run-lsim-32bit-benchmark ()
  "Benchmark 32-bit register with pmapcat parallelization."
  (format t "~%=== LSIM 32-Bit Register Benchmark (pmapcat) ===~%")

  (let* ((*package* (find-package :lsim))
         (netlist (funcall (intern "EXPAND-NETLIST" :lsim) 'register-32bit))
         (events (make-test-events-for-lsim 32 1000))
         (monitored (make-monitored-nodes 32))
         (netlist-size (length netlist))
         (events-size (length events)))

    (format t "Components (after expansion): ~D~%" netlist-size)
    (format t "Events: ~D~%" events-size)
    (format t "Time units: 1000~%")
    (format t "Using: pmapcat with thread pool (16 threads)~%~%")

    (format t "Warming up...~%")
    (funcall (intern "RUN-SIMULATION" :lsim) netlist events 1000 monitored)
    (sb-ext:gc :full t)

    (format t "Running 100 iterations...~%")
    (let ((times '())
          (start-bytes (sb-ext:get-bytes-consed)))
      (dotimes (i 100)
        (when (zerop (mod i 10))
          (format t "  Iteration ~D/100~%" i))
        (let ((start-time (get-internal-run-time)))
          (funcall (intern "RUN-SIMULATION" :lsim) netlist events 1000 monitored)
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

        (format t "~%Results (LSIM 32-bit with pmapcat, 100 iterations):~%")
        (format t "  Mean:   ~,3F ms~%" (* 1000 mean))
        (format t "  Median: ~,3F ms~%" (* 1000 median))
        (format t "  Min:    ~,3F ms~%" (* 1000 min-time))
        (format t "  Max:    ~,3F ms~%" (* 1000 max-time))
        (format t "  StdDev: ~,3F ms~%" (* 1000 std-dev))
        (format t "  Total consed: ~,2F MB~%" (/ total-consed 1024.0 1024.0))
        (format t "  Per iteration: ~,2F KB~%~%" (/ total-consed 100.0 1024.0))))))

;; Run benchmark
(handler-case
    (progn
      (run-lsim-32bit-benchmark)
      (format t "~%LSIM benchmark completed successfully!~%"))
  (error (e)
    (format t "~%ERROR: ~A~%" e)
    (format t "Stacktrace:~%")
    (sb-debug:print-backtrace :stream *standard-output* :count 20)))

(sb-ext:quit)
