;;; Single run benchmark for baseline timing

(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

(defpackage :fol-sim
  (:use :cl)
  (:shadow *modules* *primitives* *sim-context* first rest empty?)
  (:shadowing-import-from :fol.compiler.mutable atom)
  (:shadowing-import-from :fol.compiler.collection-functions get assoc dissoc update conj merge)
  (:shadowing-import-from :fol.compiler.seq-functions map reduce filter concat into some every take-while drop-while mapcat keys sort-by)
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

;; Workaround for Lisp-2: bind functions to variable slot for first-class use
(setf (symbol-value 'conj) #'fol.compiler.collection-functions:conj)

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

(load "fol-code/lsim.lisp")
;; Bind lsim functions for first-class use
(setf (symbol-value 'insert-event) #'insert-event)

(defconstant <module-def> '<module-def>)
(defconstant <logic-component> '<logic-component>)
(defconstant <component> '<component>)
(load "fol-code/register-8bit.lisp")

(defun make-event (time node value)
  (fol.compiler.collection-functions:dict :time time :node node :value value))

(defun run-one-simulation ()
  (format t "  [A] Resetting context...~%") (force-output)
  (setf *sim-context*
        (atom (fol.compiler.collection-functions:dict
               :monitored (fol.compiler.collection-functions:set)
               :events (fol.compiler.collection-functions:vector)
               :history (fol.compiler.collection-functions:dict))))
  (format t "  [B] Context reset~%") (force-output)
  (funcall #'monitor 'out0 'out1 'out2 'out3 'out4 'out5 'out6 'out7)
  (format t "  [C] Monitored outputs~%") (force-output)
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
  (format t "  [D] Events set up~%") (force-output)
  (format t "  [D.1] About to funcall run...~%") (force-output)
  (format t "  [D.2] Run function bound: ~A~%" (fboundp 'run)) (force-output)
  (funcall #'run 'test-register-8bit 30)
  (format t "  [E] Run complete~%") (force-output))

(format t "~%=== Baseline Single Run ===~%")
(sb-ext:gc :full t)
(let ((start-time (get-internal-real-time))
      (start-run-time (get-internal-run-time)))
  (run-one-simulation)
  (let* ((end-time (get-internal-real-time))
         (end-run-time (get-internal-run-time))
         (real-seconds (/ (- end-time start-time) internal-time-units-per-second))
         (run-seconds (/ (- end-run-time start-run-time) internal-time-units-per-second)))
    (format t "Real time: ~,3F ms~%" (* 1000 real-seconds))
    (format t "CPU time:  ~,3F ms~%~%" (* 1000 run-seconds))))

(sb-ext:quit)
