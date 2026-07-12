;;; RQ8 defmethod-invalidation benchmark (PLDI 2027 paper).
;;;
;;; RQ8's existing evidence (src/tests/test-transient-conversion.lisp:
;;; world-guarded-loop-falls-back-correctly / world-defn-emits-redefinition-note)
;;; only exercises invalidation triggered by a plain `defn` redefinition of a
;;; name a converted region assumed. The paper's Soundness section
;;; (Mechanism, item 3 / Invalidation) also claims the guard fires "whether
;;; a name is redefined outright or a generic function gains a new method
;;; ... both treated conservatively as invalidating" -- but until now no
;;; benchmark or test exercised the second case (see Threats to Validity:
;;; "no benchmark executes a defmethod against a name a converted region
;;; depends on, so that cost is untested, not shown small").
;;;
;;; This script closes that gap: it compiles and loads a transient-converted
;;; dict-accumulation loop that assumes `assoc`, then compiles and loads a
;;; `defmethod assoc :around` specialized on a *previously-unhandled class*
;;; -- a generic function gaining a new method, not a `defn` redefinition of
;;; `assoc` itself -- and confirms the same compiled loop closure falls back
;;; to its original path and keeps producing byte-identical results.
;;;
;;; Run from the repository root:
;;;   sbcl --noinform --non-interactive --load benchmarks/run-rq8-defmethod-bench.lisp

(require :asdf)
(let* ((here (or *load-pathname* *compile-file-pathname*))
       (root (make-pathname :directory (butlast (pathname-directory here))))
       (src  (merge-pathnames "src/" root)))
  (pushnew (truename src) asdf:*central-registry* :test #'equal)
  (handler-bind ((warning #'muffle-warning))
    (asdf:load-system :fol-compiler)))

(defpackage :fol.benchmarks.rq8-defmethod (:use :cl))
(in-package :fol.benchmarks.rq8-defmethod)

(defun compile-eval-fol* (src)
  "Compile+eval every top-level form in FOL source SRC, with transient
   conversion on, mirroring the established helper in run-transient-bench.lisp
   and src/tests/test-transient-conversion.lisp's compile-eval-fol-source."
  (let ((fol.compiler.escape-analysis:*transient-loops* t)
        (*readtable* fol.compiler.reader:*fol-readtable*)
        (*package* (find-package :fol.core)))
    (with-input-from-string (in src)
      (loop for f = (read in nil :eof) until (eq f :eof)
            do (eval (fol.compiler:compilation-result-code
                      (fol.compiler:compile-form f)))))))

(defun fol-fn (name) (fdefinition (find-symbol (string-upcase name) :fol.core)))

(fol.compiler.world:reset-world)

;; 1. A transient-converted dict-accumulation loop, wrapped in a named
;;    function so the SAME compiled closure can be called before and after.
(compile-eval-fol* "
(defn build-dict [n]
  (loop [acc {} i 0]
    (if (< i n)
      (recur (assoc acc i i) (inc i))
      acc)))")

(let* ((n 2000)
       (before (funcall (fol-fn "build-dict") n))
       (stats-before (fol.compiler.world:world-stats)))
  (format t "~&After registering build-dict: ~A~%" stats-before)
  (unless (plusp (getf stats-before :regions-registered))
    (format t "~&FAIL: expected build-dict's converted loop to register a region.~%")
    (sb-ext:exit :code 1))

  ;; 2. A *previously-unhandled class* gains a defmethod :around on
  ;;    `assoc` -- "a generic function gains a new method", not a plain
  ;;    `defn` redefinition of `assoc` itself. (Same pattern as the
  ;;    guards.fol case study, applied here to the invalidation mechanism
  ;;    rather than to CLOS-dispatch overhead.)
  (compile-eval-fol* "
(defclass <account> []
  [[owner   :initarg :owner]
   [balance :initarg :balance :initform 0]])

(defmethod assoc :around [(acc <account>) slot val]
  (bind [result (call-next-method)]
    (when (< (:balance result) 0)
      (error \"negative balance\"))
    result))")

  (let ((stats-after (fol.compiler.world:world-stats)))
    (format t "~&After defmethod assoc :around on <account>: ~A~%" stats-after)
    (unless (plusp (getf stats-after :redefinitions-noted))
      (format t "~&FAIL: expected the defmethod to notify the world.~%")
      (sb-ext:exit :code 1))
    (unless (plusp (getf stats-after :regions-invalidated))
      (format t "~&FAIL: expected build-dict's region to be invalidated by the defmethod.~%")
      (sb-ext:exit :code 1))

    ;; 3. Re-run the *same* compiled closure: must still produce identical
    ;;    results, now via the original (slow) path.
    (let ((after (funcall (fol-fn "build-dict") n)))
      (if (and (= (fol.compiler.collections:collection-size before)
                  (fol.compiler.collections:collection-size after))
               (loop for i below n
                     always (eql (fol.compiler.collection-functions:get before i)
                                 (fol.compiler.collection-functions:get after i))))
          (format t "~&PASS: defmethod-triggered invalidation -- a region depending ~
                     on ASSOC fell back correctly after a defmethod (not defn) ~
                     redefinition; ~D-entry dict byte-identical before/after.~%"
                  n)
          (progn
            (format t "~&FAIL: before/after dicts differ.~%")
            (sb-ext:exit :code 1))))))

(sb-ext:exit :code 0)
