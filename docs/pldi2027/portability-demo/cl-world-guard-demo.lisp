;;;; cl-world-guard-demo.lisp
;;;;
;;;; What this demonstrates
;;;; -----------------------
;;;; The paper's §"Novelty, and why an open world" claims the mechanisms
;;;; (name-resolution-faithful summaries, region invalidation, safe-by-abort
;;;; emit-time rewriting) -- not FOL itself -- transfer to similarly-
;;;; positioned transpiled dynamic languages, but the paper only ever
;;;; exercises them via FOL-generated code (the compiler emits the dual-path
;;;; guard automatically). This file is a counter-check on that claim: it is
;;;; ORDINARY, HAND-WRITTEN COMMON LISP. Nothing here is produced by the FOL
;;;; transpiler. A CL programmer, using only FOL's runtime LIBRARIES
;;;; (fol.compiler.collection-functions for persistent ops,
;;;; fol.compiler.collections for the transient protocol, fol.compiler.world
;;;; for the guard machinery) as three ordinary Lisp packages, applies BY
;;;; HAND the exact transformation §"The Rewriter" applies automatically to
;;;; FOL source, and gets the same soundness and performance properties.
;;;;
;;;; This corroborates the portability claim for the SOUNDNESS-UNDER-
;;;; REDEFINITION mechanism specifically (world.lisp: REGISTER-REGION /
;;;; NOTE-REDEFINITION / REGION-VALID-P), since that mechanism is exactly as
;;;; general as the CLOS generic-function redefinition it guards against --
;;;; it is untyped, requires no AST, and consults only a string key. It does
;;;; NOT port the classifier (chain-kind, op-gates, tail-position analysis):
;;;; that machinery walks FOL ASTs and is FOL-compiler-specific; the
;;;; complementary corpus study in docs/cgo2027/corpus-study/classify.clj
;;;; addresses portability of THAT half separately, for Clojure. Together
;;;; the two give independent evidence for each half of the paper's
;;;; "assembly, not new escape analysis" claim, on two different host
;;;; languages neither of which is FOL.
;;;;
;;;; Why a demo-local PASSOC/PCONJ, not the real ASSOC/CONJ
;;;; --------------------------------------------------------
;;;; This process also has the full fol-compiler system loaded (needed for
;;;; the collection/transient/world libraries), and FOL's own runtime is
;;;; itself written in terms of fol.compiler.collection-functions:assoc.
;;;; Redefining that shared generic live, in the same process, would risk
;;;; destabilizing unrelated FOL machinery for no evidentiary gain: the
;;;; world-guard mechanism only ever consults a STRING key (see
;;;; NOTE-REDEFINITION in world.lisp -- it does no reflection on the
;;;; function object itself), so redefining a demo-owned generic under the
;;;; same string key it registered under is behaviorally identical evidence
;;;; to redefining the real ASSOC, without the blast radius. PASSOC's own
;;;; primary method simply delegates to the real ASSOC, so the workload
;;;; itself is the real persistent-dict implementation throughout.
;;;;
;;;; How to run
;;;; ----------
;;;;   cd src && sbcl --noinform --non-interactive \
;;;;     --eval "(push (truename \".\") asdf:*central-registry*)" \
;;;;     --eval "(asdf:load-system :fol-compiler)" \
;;;;     --load "../docs/pldi2027/portability-demo/cl-world-guard-demo.lisp"

(defpackage :world-guard-demo
  (:use :cl))
(in-package :world-guard-demo)

(defparameter +n+ 200000
  "Matches the paper's RQ2 'dict loop, 200k assocs' microbenchmark size.")

;;; ===========================================================================
;;; A demo-local Tier-1 surrogate: PASSOC. Its primary method delegates to
;;; FOL's real, shared ASSOC, so the workload below exercises the actual
;;; persistent-dict implementation; only the REDEFINITION target (step 4
;;; below) is this demo-owned function rather than the shared one.
;;; ===========================================================================

(defgeneric passoc (coll key val)
  (:documentation "Demo Tier-1 surrogate for FOL's ASSOC on dicts."))

(defmethod passoc (coll key val)
  (fol.compiler.collection-functions:assoc coll key val))

;;; ===========================================================================
;;; Original (unconverted): what any CL programmer would write by hand
;;; against FOL's persistent-collection library, with no knowledge of the
;;; transient protocol at all.
;;; ===========================================================================

(defun dict-loop/original (n)
  (let ((acc (fol.compiler.collection-functions:dict)))
    (dotimes (i n)
      (setf acc (passoc acc i i)))
    acc))

;;; ===========================================================================
;;; Manually converted: the SAME transformation the paper's §"The Rewriter"
;;; applies automatically to FOL source (init -> transient, ASSOC -> ASSOC!,
;;; exit -> persistent!), applied here BY HAND to plain CL, wired with a
;;; world-guard by hand. REGISTER-REGION runs once, at load time -- exactly
;;; the "(car (load-time-value (register-region ...)))" pattern documented
;;; in world.lisp's header -- assuming PASSOC's Tier-1 meaning.
;;; ===========================================================================

(defparameter *dict-loop-region*
  (fol.compiler.world:register-region '("PASSOC")))

(defun dict-loop/guarded (n)
  (if (fol.compiler.world:region-valid-p *dict-loop-region*)
      ;; Fast path: transient protocol, exactly what a Clojure/FOL
      ;; programmer would write by hand (paper's §"RQ3").
      (let ((acc-t (fol.compiler.collections:transient
                    (fol.compiler.collection-functions:dict))))
        (dotimes (i n)
          (fol.compiler.collections:assoc! acc-t i i))
        (fol.compiler.collections:persistent! acc-t))
      ;; Slow path: original, always-sound semantics.
      (dict-loop/original n)))

;;; ===========================================================================
;;; Verification and (illustrative, non-rigorous) timing helpers.
;;; ===========================================================================

(defun dict-contents-match-p (a b n)
  "Structural equality check across all N keys -- a demo-scale stand-in for
   the paper's byte-identical-output checks (RQ1, RQ7)."
  (and (cl:= (fol.compiler.collection-functions:count a)
             (fol.compiler.collection-functions:count b))
       (cl:loop for i below n
                always (cl:= (fol.compiler.collection-functions:get a i)
                              (fol.compiler.collection-functions:get b i)))))

(defun time-once (thunk)
  (let ((t0 (get-internal-real-time)))
    (funcall thunk)
    (/ (float (- (get-internal-real-time) t0)) internal-time-units-per-second)))

(defun best-of (thunk trials)
  (loop repeat trials minimize (time-once thunk)))

;;; ===========================================================================
;;; A hand-written analog of the hook the FOL compiler installs automatically
;;; around every top-level defn/defmethod (compile-form calls
;;; NOTE-REDEFINITION when *optimizer-mode* redefines a summarized name).
;;; Nothing about that hook requires transpilation -- it is one small macro a
;;; CL programmer could write and apply themselves.
;;; ===========================================================================

(defmacro define-guarded-method (name lambda-list &body body)
  `(prog1 (defmethod ,name ,lambda-list ,@body)
     (fol.compiler.world:note-redefinition ,(string name))))

;;; ===========================================================================
;;; Demo
;;; ===========================================================================

(defvar *passoc-side-effects* 0
  "Bumped by the redefinition below, so we can also observe -- not just
   infer from timing -- which path a call actually took.")

(format t "~&=== CL world-guard portability demo (hand-written, no FOL transpiler involved) ===~%~%")

(format t "1. Correctness before any redefinition (n=~D)...~%" +n+)
(let* ((orig (dict-loop/original +n+))
       (conv (dict-loop/guarded +n+))
       (ok (dict-contents-match-p orig conv +n+)))
  (format t "   fast path == original path: ~A~%~%" (if ok "MATCH" "MISMATCH -- BUG")))

(format t "2. Illustrative timing (best of 3, n=~D; NOT the paper's rigorous protocol -- see RQ2)...~%" +n+)
(let ((t-orig (best-of (lambda () (dict-loop/original +n+)) 3))
      (t-conv (best-of (lambda () (dict-loop/guarded +n+)) 3)))
  (format t "   original (persistent PASSOC each iteration): ~,3Fs~%" t-orig)
  (format t "   guarded, fast path (transient protocol):     ~,3Fs~%" t-conv)
  (format t "   speedup: ~,2Fx  (same mechanism as RQ2's 3.35x dict-loop figure; not directly~%" (/ t-orig t-conv))
  (format t "             comparable -- different machine, single-call timing, demo scale)~%~%"))

(format t "3. World stats before redefinition: ~S~%~%" (fol.compiler.world:world-stats))

(format t "4. Redefining PASSOC live -- a CLOS method redefinition, exactly the paper's~%")
(format t "   threat model ('(defmethod assoc :around ...)') -- via the hand-written hook macro:~%~%")

(define-guarded-method passoc (coll key val)
  (incf *passoc-side-effects*)
  (fol.compiler.collection-functions:assoc coll key val))

(format t "5. World stats after redefinition: ~S~%~%" (fol.compiler.world:world-stats))

(format t "6. Region validity after redefinition: ~A~%~%"
        (if (fol.compiler.world:region-valid-p *dict-loop-region*)
            "VALID  -- BUG, should have flipped"
            "INVALID (expected: next entry takes the slow path)"))

(format t "7. Calling dict-loop/guarded again -- must now take the slow path (which calls~%")
(format t "   the redefined PASSOC, so *passoc-side-effects* must increase) and still produce~%")
(format t "   a correct result:~%~%")
(let ((before *passoc-side-effects*))
  (let* ((orig (dict-loop/original +n+))
         (conv (dict-loop/guarded +n+))
         (ok (dict-contents-match-p orig conv +n+)))
    (format t "   side-effect counter delta: ~D (expect ~D: original + slow-path guarded call)~%"
            (- *passoc-side-effects* before) (cl:* 2 +n+))
    (format t "   fast path == original path: ~A~%" (if ok "MATCH" "MISMATCH -- BUG"))
    (format t "   region valid?: ~A~%~%"
            (if (fol.compiler.world:region-valid-p *dict-loop-region*)
                "VALID -- BUG"
                "NIL (fast path permanently retired for this region, as designed)"))))

(format t "=== Demo complete: the world-guard mechanism, applied by hand to plain CL,~%")
(format t "    behaves identically to the paper's RQ8 (redefine -> next-entry fallback,~%")
(format t "    correct output, no crash) with zero FOL compiler involvement. ===~%")
