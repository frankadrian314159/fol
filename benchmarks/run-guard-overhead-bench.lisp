;;; World-guard overhead benchmark (PLDI 2027 paper).
;;;
;;; The paper's contribution list claims "guards measure as free". RQ7's
;;; existing evidence for that only compares the optimization *disabled*
;;; entirely (no guard emitted at all, byte-stable vs. the pre-work
;;; compiler) against enabled -- it never isolates the guard's own marginal
;;; cost on an already-converted loop, and rests on a single 1.02x LSim data
;;; point. It also leaves ambiguous whether entry-check cost could scale
;;; with how many standard-library names a region depends on.
;;;
;;; This script isolates the guard directly: `fol.compiler.world:*sealed-world*`
;;; lets the SAME transient-converted loop body compile either with the
;;; dual-path world guard (`*sealed-world* = nil`, the normal, open-world
;;; case) or with the guard omitted entirely and only the fast path emitted
;;; (`*sealed-world* = t`, "batch/closed-world" mode) -- see emit-loop in
;;; src/compiler.lisp. Comparing guarded vs. sealed compilations of the
;;; identical body isolates exactly the guard's marginal cost, with no
;;; conversion-benefit or allocation difference to confound it.
;;;
;;; It also answers the scaling question directly from the mechanism
;;; (register-region, src/world.lisp): a region gets exactly ONE validity
;;; cell no matter how many names it assumed; the guard tests that one
;;; cell's CAR. Dependency-set size can only affect load-time registration
;;; (a one-time cost, not measured here), never the per-call check. To
;;; confirm this empirically rather than by code-reading alone, the
;;; benchmark contrasts a 1-dependency region against a 6-dependency region
;;; (two accumulators plus an inlined helper, unioning their assumption
;;; sets into one register-region call -- see maybe-transient-loop in
;;; src/escape-analysis.lisp).
;;;
;;; Since the guard is one CAR check, its absolute cost is expected to be
;;; far below a loop body's own work -- so each workload is called with
;;; n=0 (the loop body runs zero iterations) over many repetitions, so
;;; per-call overhead -- not loop-body work -- dominates what's measured.
;;;
;;; Run from the repository root:
;;;   sbcl --noinform --non-interactive --load benchmarks/run-guard-overhead-bench.lisp

(require :asdf)
(let* ((here (or *load-pathname* *compile-file-pathname*))
       (root (make-pathname :directory (butlast (pathname-directory here))))
       (src  (merge-pathnames "src/" root)))
  (pushnew (truename src) asdf:*central-registry* :test #'equal)
  (handler-bind ((warning #'muffle-warning))
    (asdf:load-system :fol-compiler)))

(defpackage :fol.benchmarks.guard-overhead (:use :cl))
(in-package :fol.benchmarks.guard-overhead)

(defparameter *reps* 20000000
  "Calls per timed trial. The guard is a single CAR check, so isolating it
   from call/loop-entry noise needs many repetitions of a near-empty body.")
(defparameter *trials* 5)

(defun compile-eval-fol* (src &key sealed)
  "Compile+eval every top-level form in FOL source SRC with transient
   conversion on, and fol.compiler.world:*sealed-world* bound to SEALED."
  (let ((fol.compiler.escape-analysis:*transient-loops* t)
        (fol.compiler.world:*sealed-world* sealed)
        (*readtable* fol.compiler.reader:*fol-readtable*)
        (*package* (find-package :fol.core)))
    (with-input-from-string (in src)
      (loop for f = (read in nil :eof) until (eq f :eof)
            do (eval (fol.compiler:compilation-result-code
                      (fol.compiler:compile-form f)))))))

(defun fol-fn (name) (fdefinition (find-symbol (string-upcase name) :fol.core)))

(defun mean (xs) (/ (reduce #'+ xs) (float (length xs))))
(defun sd (xs)
  (let ((m (mean xs)) (n (length xs)))
    (if (< n 2) 0.0
        (sqrt (/ (reduce #'+ (mapcar (lambda (x) (expt (- x m) 2)) xs))
                 (float (1- n)))))))

(defun time-calls (fn arg n)
  "Wall-clock seconds for N calls to FN with ARG (chosen so the loop body
   runs zero iterations: 0 for the few-deps functions, an empty vector for
   the many-deps functions, which index/count their argument)."
  (let ((t0 (get-internal-real-time)))
    (dotimes (_ n) (funcall fn arg))
    (/ (- (get-internal-real-time) t0) (float internal-time-units-per-second))))

(defun trials (fn arg)
  (funcall fn arg) ; warm-up
  (loop repeat *trials* collect (time-calls fn arg *reps*)))

;;; --- Few dependencies: one accumulator, one op, one assumption name ---
(compile-eval-fol* "
(defn build-few-guarded [n]
  (loop [acc {} i 0]
    (if (< i n)
      (recur (assoc acc i (* i i)) (inc i))
      acc)))"
 :sealed nil)

(compile-eval-fol* "
(defn build-few-sealed [n]
  (loop [acc {} i 0]
    (if (< i n)
      (recur (assoc acc i (* i i)) (inc i))
      acc)))"
 :sealed t)

;;; --- Many dependencies: two accumulators + an inlined helper, unioning
;;;     into a 6-name register-region call (dissoc, assoc, get, count,
;;;     conj, bump-or-drop-{guarded,sealed}) ---
(compile-eval-fol* "
(defn bump-or-drop-guarded [counts k]
  (if (> (count counts) 1000)
    (dissoc counts k)
    (assoc counts k (inc (get counts k 0)))))

(defn build-many-guarded [pairs]
  (loop [counts {} order [] i 0]
    (if (< i (count pairs))
      (bind [k (get (nth pairs i) :key)]
        (recur (bump-or-drop-guarded counts k) (conj order k) (inc i)))
      {:counts counts :order order})))"
 :sealed nil)

(compile-eval-fol* "
(defn bump-or-drop-sealed [counts k]
  (if (> (count counts) 1000)
    (dissoc counts k)
    (assoc counts k (inc (get counts k 0)))))

(defn build-many-sealed [pairs]
  (loop [counts {} order [] i 0]
    (if (< i (count pairs))
      (bind [k (get (nth pairs i) :key)]
        (recur (bump-or-drop-sealed counts k) (conj order k) (inc i)))
      {:counts counts :order order})))"
 :sealed t)

(format t "~&================================================================~%")
(format t "  World-guard overhead: guarded (dual-path) vs. sealed (fast-path only)~%")
(format t "  ~:D calls/trial x ~D trials, argument 0 (zero loop iterations)~%" *reps* *trials*)
(format t "================================================================~%")

(dolist (pair (list (list "few (1 dependency: ASSOC)" "build-few-guarded" "build-few-sealed" 0)
                     (list "many (6 dependencies)" "build-many-guarded" "build-many-sealed"
                           (funcall (fol-fn "vector")))))
  (destructuring-bind (label guarded-name sealed-name arg) pair
    (let* ((guarded (trials (fol-fn guarded-name) arg))
           (sealed (trials (fol-fn sealed-name) arg))
           (mg (mean guarded)) (sg (sd guarded))
           (ms (mean sealed)) (ss (sd sealed)))
      (format t "~%~A~%" label)
      (format t "  guarded: ~,4F +/- ~,4F s  (~,2F ns/call)~%" mg sg (* 1e9 (/ mg *reps*)))
      (format t "  sealed:  ~,4F +/- ~,4F s  (~,2F ns/call)~%" ms ss (* 1e9 (/ ms *reps*)))
      (format t "  guarded/sealed ratio: ~,3Fx  (per-call overhead: ~,2F ns)~%"
              (if (> ms 0) (/ mg ms) 0)
              (* 1e9 (/ (- mg ms) *reps*))))))

(sb-ext:exit :code 0)
