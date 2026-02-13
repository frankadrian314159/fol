;;; Benchmark transpiled FOL simulator (fol-code/lsim.lisp)
;;; Runs the 8-bit register simulation 1000 times
;;; Updated for cl-utils (native CL data structures)

(push (truename "src/") asdf:*central-registry*)
(asdf:load-system :fol-compiler)

;; Create simulator package with FOL collection functions
(defpackage :fol-sim
  (:use :cl)
  (:shadow *modules* *primitives* *sim-context* first rest empty?)  ; Shadow CL and simulator vars
  (:shadowing-import-from :fol.compiler.mutable
                atom)
  (:shadowing-import-from :fol.compiler.collection-functions
                get assoc dissoc update conj)
  (:shadowing-import-from :fol.compiler.seq-functions
                map reduce filter concat into some every
                take-while drop-while mapcat keys sort-by)
  (:shadowing-import-from :fol.compiler.primitive-functions
                symbol)
  (:import-from :fol.compiler.mutable
                deref reset! swap! compare-and-set!
                <atom> <atom>? ref <ref> <ref>?)
  (:import-from :fol.compiler.primitives
                truthy? falsy? make)
  (:import-from :fol.compiler.primitive-functions
                nil? some? boolean? true? false? seq? coll? map? vector? list?
                keyword? symbol? string? char? number? integer? float? rational?
                fn? identical? =?)
  (:import-from :fol.compiler.string-functions
                str subs str-join str-split))

(in-package :fol-sim)
(sb-ext:unlock-package :cl)

;; Define wrappers for functions that need to handle both FOL collections and CL lists
;; These MUST be defined before loading the transpiled code
;; IMPORTANT: Declare as notinline to prevent SBCL from inlining them during compilation
;; (inlining breaks the lexical context of block/tagbody in loop/recur forms)

(declaim (notinline empty? first rest))

(defun empty? (coll)
  "Check if collection is empty. Handles both FOL collections and CL lists."
  (if (listp coll)
      (null coll)
      (fol.compiler.collection-functions:empty? coll)))

(defun first (coll)
  "Get first element. Handles both FOL collections and CL lists."
  (if (listp coll)
      (cl:first coll)
      (fol.compiler.collection-functions:first coll)))

(defun rest (coll)
  "Get rest of elements. Handles both FOL collections and CL lists."
  (if (listp coll)
      (cl:rest coll)
      (fol.compiler.collection-functions:rest coll)))

;; Wrapper for contains? - check if collection contains element
(defun contains? (coll element)
  "Check if collection contains element. For sets, checks membership.
   For dicts, checks if key exists. For sequences, searches for element."
  (typecase coll
    (fol.compiler.collections:<set>
     ;; For sets, use get which returns element if found, nil otherwise
     (not (null (get coll element))))
    (fol.compiler.collections:<dict>
     ;; For dicts, check if key exists
     (multiple-value-bind (value found)
         (get coll element)
       (declare (ignore value))
       found))
    (t
     ;; For other collections, convert to seq and search
     (let ((seq (fol.compiler.collections:collection-seq coll)))
       (not (null (cl:find element seq)))))))

;; Wrapper for into that handles CL lists
(defun into-wrapper (to from)
  "Add all elements from FROM into TO. Handles both FOL collections and CL lists."
  (if (listp from)
      ;; FROM is a CL list - reduce over it directly
      (cl:reduce #'fol.compiler.collections:collection-conj from :initial-value to)
      ;; FROM is a FOL collection - use the standard into
      (fol.compiler.seq-functions:into to from)))

;; Shadow the imported into with our wrapper
(setf (fdefinition 'into) #'into-wrapper)

;; Wrapper for concat that handles CL lists
(defun concat-wrapper (&rest colls)
  "Concatenate collections. Handles both FOL collections and CL lists."
  (let* ((seqs (mapcar (lambda (coll)
                         (if (listp coll)
                             coll  ; CL list - use as-is
                             (fol.compiler.collections:collection-seq coll)))  ; FOL collection - convert
                       colls))
         (combined (apply #'cl:append seqs)))
    (apply #'fol.compiler.collections:make 'fol.compiler.collections:<vector> combined)))

;; Shadow the imported concat with our wrapper
(setf (fdefinition 'concat) #'concat-wrapper)

;; Wrapper for reduce that handles CL lists
(defun reduce-wrapper (fn init coll)
  "Reduce collection with function and initial value. Handles both FOL collections and CL lists."
  (if (listp coll)
      ;; CL list - use directly
      (cl:reduce fn coll :initial-value init)
      ;; FOL collection - use the standard reduce
      (fol.compiler.seq-functions:reduce fn init coll)))

;; Shadow the imported reduce with our wrapper
(setf (fdefinition 'reduce) #'reduce-wrapper)

;; Load the transpiled simulator
(load "fol-code/lsim.lisp")

;; Workaround for defmacro transpilation bug:
;; The DEFPART macro has <MODULE-DEF> unquoted, so it's evaluated as a variable.
;; Define it as a constant holding the class symbol.
(defconstant <module-def> '<module-def>)
(defconstant <logic-component> '<logic-component>)
(defconstant <component> '<component>)

(load "fol-code/register-8bit.lisp")

;; Helper to create event (FOL dict)
(defun make-event (time node value)
  (fol.compiler.collection-functions:dict :time time :node node :value value))

(defun run-one-simulation ()
  "Run one instance of the 8-bit register simulation."
  ;; Reset simulation context (FOL data structures)
  (setf *sim-context*
        (atom (fol.compiler.collection-functions:dict
               :monitored (fol.compiler.collection-functions:set)
               :events (fol.compiler.collection-functions:vector)
               :history (fol.compiler.collection-functions:dict))))

  ;; Monitor output bits
  (funcall #'monitor 'out0 'out1 'out2 'out3 'out4 'out5 'out6 'out7)

  ;; Set up test events
  (funcall #'events
    (make-event 0 'in0 nil) (make-event 0 'in1 t)
    (make-event 0 'in2 nil) (make-event 0 'in3 t)
    (make-event 0 'in4 nil) (make-event 0 'in5 t)
    (make-event 0 'in6 nil) (make-event 0 'in7 t)
    (make-event 5 'clk t)
    (make-event 10 'clk nil)
    (make-event 15 'in0 t) (make-event 15 'in1 nil)
    (make-event 15 'in2 t) (make-event 15 'in3 nil)
    (make-event 15 'in4 t) (make-event 15 'in5 nil)
    (make-event 15 'in6 t) (make-event 15 'in7 nil)
    (make-event 20 'clk t)
    (make-event 25 'clk nil))

  ;; Run simulation
  (funcall #'run 'test-register-8bit 30))

(format t "~%=== Benchmarking Transpiled FOL Simulator ===~%")
(format t "Running 1000 simulations...~%~%")

;; Warm-up runs
(dotimes (i 10)
  (run-one-simulation))

(format t "Warm-up complete. Starting timed runs...~%~%")

;; Force GC before benchmark
(sb-ext:gc :full t)

(let ((start-time (get-internal-real-time))
      (start-run-time (get-internal-run-time))
      (initial-bytes (sb-ext:dynamic-space-size)))

  ;; Run 1000 simulations
  (dotimes (i 1000)
    (when (zerop (mod i 100))
      (format t "Progress: ~A/1000~%" i))
    (run-one-simulation))

  (let* ((end-time (get-internal-real-time))
         (end-run-time (get-internal-run-time))
         (final-bytes (sb-ext:dynamic-space-size))
         (real-seconds (/ (- end-time start-time)
                         internal-time-units-per-second))
         (run-seconds (/ (- end-run-time start-run-time)
                        internal-time-units-per-second))
         (bytes-allocated (- final-bytes initial-bytes))
         (mb-allocated (/ bytes-allocated 1048576.0)))

    (format t "~%=== Results ===~%")
    (format t "Total real time:     ~,3F seconds~%" real-seconds)
    (format t "Total CPU time:      ~,3F seconds~%" run-seconds)
    (format t "Average per run:     ~,3F ms (real time)~%"
            (* 1000 (/ real-seconds 1000)))
    (format t "Average per run:     ~,3F ms (CPU time)~%"
            (* 1000 (/ run-seconds 1000)))
    (format t "Memory allocated:    ~,2F MB~%" mb-allocated)
    (format t "Memory per run:      ~,2F KB~%"
            (/ mb-allocated 1000.0 1024))
    (format t "~%")))

(sb-ext:quit)
