;;; 100-iteration benchmark using hand-written Common Lisp lsim

(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(defpackage :fol-sim
  (:use :cl)
  (:shadow *modules* *primitives* *sim-context* first rest empty?)
  (:shadowing-import-from :fol.compiler.mutable atom)
  (:shadowing-import-from :fol.compiler.collection-functions get assoc dissoc update conj merge)
  (:shadowing-import-from :fol.compiler.seq-functions map pmap reduce filter concat into some every take-while drop-while mapcat pmapcat keys sort-by)
  (:shadowing-import-from :fol.compiler.primitive-functions symbol)
  (:import-from :fol.compiler.mutable deref reset! swap! compare-and-set! <atom> <atom>? ref <ref> <ref>?)
  (:import-from :fol.compiler.primitives truthy? falsy? make)
  (:import-from :fol.compiler.primitive-functions nil? some? boolean? true? false? seq? coll? map? vector? list? keyword? symbol? string? char? number? integer? float? rational? fn? identical? =?)
  (:import-from :fol.compiler.string-functions str subs str-join str-split))

(in-package :fol-sim)
(sb-ext:unlock-package :cl)

(declaim (notinline empty? first rest))

(defun empty? (coll)
  (if (listp coll) (null coll) (fol.compiler.collection-functions:empty? coll)))

(defun first (coll)
  (if (listp coll) (cl:first coll) (fol.compiler.collection-functions:first coll)))

(defun rest (coll)
  (if (listp coll) (cl:rest coll) (fol.compiler.collection-functions:rest coll)))

(defun contains? (coll element)
  (typecase coll
    (fol.compiler.collections:<set> (not (null (get coll element))))
    (fol.compiler.collections:<dict> (multiple-value-bind (value found) (get coll element) (declare (ignore value)) found))
    (t (let ((seq (fol.compiler.collections:collection-seq coll))) (not (null (cl:find element seq)))))))

(defun into-wrapper (to from)
  (if (listp from)
      (cl:reduce #'fol.compiler.collections:collection-conj from :initial-value to)
      (fol.compiler.seq-functions:into to from)))
(setf (fdefinition 'into) #'into-wrapper)

(defun concat-wrapper (&rest colls)
  (let* ((seqs (mapcar (lambda (coll) (if (listp coll) coll (fol.compiler.collections:collection-seq coll))) colls))
         (combined (apply #'cl:append seqs)))
    (apply #'fol.compiler.collections:make 'fol.compiler.collections:<vector> combined)))
(setf (fdefinition 'concat) #'concat-wrapper)

;; Save the original reduce function BEFORE overriding it
(let ((original-reduce (fdefinition 'reduce)))
  (defun reduce-wrapper (fn init coll)
    (if (listp coll)
        (cl:reduce fn coll :initial-value init)
        (funcall original-reduce fn init coll)))
  (setf (fdefinition 'reduce) #'reduce-wrapper))

;; Load transpiled lsim for module system and primitives
(load "fol-code/lsim.lisp")

;; Workaround for Lisp-2: bind functions to variable slot
(setf (symbol-value 'insert-event) #'insert-event)
(setf (symbol-value 'conj) #'fol.compiler.collection-functions:conj)

;; Override run-simulation with hand-optimized CL version
(load "fol-code/lsim-cl-optimized.lisp")

;; Load register definition
(defconstant <module-def> '<module-def>)
(defconstant <logic-component> '<logic-component>)
(defconstant <component> '<component>)
(load "fol-code/register-8bit.lisp")

(defun make-event (time node value)
  (fol.compiler.collection-functions:dict :time time :node node :value value))

(defun run-one-simulation ()
  (setf *sim-context*
        (atom (fol.compiler.collection-functions:dict
               :monitored (fol.compiler.collection-functions:set)
               :events (fol.compiler.collection-functions:vector)
               :history (fol.compiler.collection-functions:dict))))
  (funcall #'monitor 'out0 'out1 'out2 'out3 'out4 'out5 'out6 'out7)
  (funcall #'events
    (make-event 0 'in0 nil) (make-event 0 'in1 t)
    (make-event 0 'in2 nil) (make-event 0 'in3 t)
    (make-event 0 'in4 nil) (make-event 0 'in5 t)
    (make-event 0 'in6 nil) (make-event 0 'in7 t)
    (make-event 5 'clk t) (make-event 10 'clk nil)
    (make-event 15 'in0 t) (make-event 15 'in1 nil)
    (make-event 15 'in2 t) (make-event 15 'in3 nil)
    (make-event 15 'in4 t) (make-event 15 'in5 nil)
    (make-event 15 'in6 t) (make-event 15 'in7 nil)
    (make-event 20 'clk t) (make-event 25 'clk nil))
  (funcall #'run 'test-register-8bit 30))

(format t "~%=== 100-Iteration Benchmark (Hand-written CL) ===~%")
(format t "Warming up...~%")
(run-one-simulation)
(sb-ext:gc :full t)

(format t "Running 100 iterations...~%")
(let ((times '())
      (start-bytes (sb-ext:get-bytes-consed)))
  (dotimes (i 100)
    (when (zerop (mod i 10))
      (format t "  Iteration ~D/100~%" i))
    (let ((start-time (get-internal-run-time)))
      (run-one-simulation)
      (let ((elapsed (/ (- (get-internal-run-time) start-time)
                       internal-time-units-per-second)))
        (push elapsed times))))

  (let* ((end-bytes (sb-ext:get-bytes-consed))
         (total-consed (- end-bytes start-bytes))
         (sorted-times (sort (copy-list times) #'<))
         (mean (/ (cl:reduce #'+ sorted-times) (length sorted-times)))
         (median (nth (floor (length sorted-times) 2) sorted-times))
         (min-time (first sorted-times))
         (max-time (first (last sorted-times)))
         (std-dev (sqrt (/ (cl:reduce #'+ (mapcar (lambda (x) (expt (- x mean) 2))
                                                   sorted-times))
                          (length sorted-times)))))

    (format t "~%Results (100 iterations, hand-written CL):~%")
    (format t "  Mean:   ~,3F ms~%" (* 1000 mean))
    (format t "  Median: ~,3F ms~%" (* 1000 median))
    (format t "  Min:    ~,3F ms~%" (* 1000 min-time))
    (format t "  Max:    ~,3F ms~%" (* 1000 max-time))
    (format t "  StdDev: ~,3F ms~%" (* 1000 std-dev))
    (format t "  Total consed: ~,2F MB~%" (/ total-consed 1024.0 1024.0))
    (format t "  Per iteration: ~,2F KB~%~%" (/ total-consed 100.0 1024.0))))

(sb-ext:quit)
