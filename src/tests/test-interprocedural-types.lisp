;;; FOL Compiler Tests - Interprocedural Parameter-Type Inference
;;;
;;; Correctness and soundness tests for INFER-INTERPROCEDURAL-TYPES /
;;; INFER-TYPE-FROM-EXPR (interprocedural-types.lisp), Stage 1: the analysis
;;; is exercised directly (parse all forms, run the pass, then compile+eval
;;; each form via COMPILE-FORM) rather than through COMPILE-FILE, which is
;;; not yet wired to run it (Stage 2).
;;;
;;; Forms are read with the FOL readtable in :fol.core, matching
;;; test-scalar-replacement.lisp's convention. Each test uses distinct class
;;; names so world-guard invalidation in one test cannot disturb another.

(in-package :fol.compiler.tests)

(def-suite interprocedural-types-suite
  :description "Interprocedural parameter-type / return-class inference"
  :in compiler-tests)

(in-suite interprocedural-types-suite)

(defun ip-read-forms (source)
  (let ((*readtable* fol.compiler.reader:*fol-readtable*)
        (*package* (find-package :fol.core))
        (forms nil))
    (with-input-from-string (in source)
      (loop for form = (read in nil :eof)
            until (eq form :eof)
            do (push form forms)))
    (nreverse forms)))

(defun ip-fol (source)
  "Read FOL SOURCE (one or more forms), run INFER-INTERPROCEDURAL-TYPES over
   all of them, then compile+eval each form in order via COMPILE-FORM (which
   re-parses internally -- matches the eventual COMPILE-FILE integration).
   Returns (values LAST-VALUE LIST-OF-ALL-FORM-CODES)."
  (let* ((*readtable* fol.compiler.reader:*fol-readtable*)
         (*package* (find-package :fol.core))
         (raw-forms (ip-read-forms source))
         (asts (mapcar #'fol.compiler::parse-form raw-forms)))
    (fol.compiler::infer-interprocedural-types asts)
    (let ((val nil) (codes nil))
      (dolist (form raw-forms)
        (let ((code (fol.compiler:compilation-result-code (fol.compiler:compile-form form))))
          (push code codes)
          (setf val (eval code))))
      (values val (nreverse codes)))))

(defun ip-analyze (source)
  "Read FOL SOURCE and run INFER-INTERPROCEDURAL-TYPES, without compiling or
   evaluating anything. Callers inspect the tables directly afterward."
  (let* ((*readtable* fol.compiler.reader:*fol-readtable*)
         (*package* (find-package :fol.core))
         (asts (mapcar #'fol.compiler::parse-form (ip-read-forms source))))
    (fol.compiler::infer-interprocedural-types asts)))

(defun ip-param-type (fn-name index)
  (let ((vec (gethash fn-name fol.compiler::*inferred-param-types*)))
    (and vec (aref vec index))))

(defun ip-returns-class (fn-name)
  (gethash fn-name fol.compiler::*inferred-returns-class*))

(defun ip-any-code-has (codes substring)
  (some (lambda (c) (and (search substring (write-to-string c)) t)) codes))

;;; ============================================================================
;;; Positive: consistent call sites prove a type, and the GET-bypass fires
;;; ============================================================================

(test ip-single-call-site-proves-param-type
  "A single call site passing a literal constructor proves the callee's
   parameter type; the GET-bypass fires (direct SLOT-VALUE, not generic GET)."
  (let ((src "
(defclass <ip-a1> [] [[x] [y]])
(defn ip-a1-total [p] (+ (get p :x) (get p :y)))
(ip-a1-total (make-<ip-a1> :x 3 :y 4))"))
    (multiple-value-bind (val codes) (ip-fol src)
      (is (= val 7))
      (is (ip-any-code-has codes "SLOT-VALUE")))))

(test ip-multiple-consistent-call-sites-prove-param-type
  "Two call sites passing the same class still prove the parameter type."
  (let ((src "
(defclass <ip-a2> [] [[x] [y]])
(defn ip-a2-total [p] (+ (get p :x) (get p :y)))
(defn ip-a2-run []
  (+ (ip-a2-total (make-<ip-a2> :x 1 :y 2))
     (ip-a2-total (make-<ip-a2> :x 10 :y 20))))
(ip-a2-run)"))
    (ip-analyze src)
    (is (eq (ip-param-type (intern "IP-A2-TOTAL" :fol.core) 0) (intern "<IP-A2>" :fol.core)))
    (multiple-value-bind (val codes) (ip-fol src)
      (is (= val 33))
      (is (ip-any-code-has codes "SLOT-VALUE")))))

(test ip-wrapper-function-return-class-closes-the-gap
  "A one-line wrapper/factory function's return class is proven, so a call
   THROUGH the wrapper still proves the receiving parameter's type -- the
   gap INFER-TYPE-FROM-CONSTRUCTOR alone cannot see through."
  (let ((src "
(defclass <ip-a3> [] [[x] [y]])
(defn ip-a3-build [x y] (make-<ip-a3> :x x :y y))
(defn ip-a3-total [p] (+ (get p :x) (get p :y)))
(ip-a3-total (ip-a3-build 5 6))"))
    (ip-analyze src)
    (is (eq (ip-returns-class (intern "IP-A3-BUILD" :fol.core)) (intern "<IP-A3>" :fol.core)))
    (is (eq (ip-param-type (intern "IP-A3-TOTAL" :fol.core) 0) (intern "<IP-A3>" :fol.core)))
    (multiple-value-bind (val codes) (ip-fol src)
      (is (= val 11))
      (is (ip-any-code-has codes "SLOT-VALUE")))))

;;; ============================================================================
;;; Soundness: anything less than full proof must not optimize
;;; ============================================================================

(test ip-conflicting-call-sites-do-not-prove
  "Two call sites passing DIFFERENT classes must not prove a single type;
   the callee still compiles and runs correctly via the generic GET path."
  (let ((src "
(defclass <ip-b1> [] [[x]])
(defclass <ip-b2> [] [[x]])
(defn ip-b-get-x [p] (get p :x))
(defn ip-b-run []
  (+ (ip-b-get-x (make-<ip-b1> :x 1))
     (ip-b-get-x (make-<ip-b2> :x 2))))
(ip-b-run)"))
    (ip-analyze src)
    (is (null (ip-param-type (intern "IP-B-GET-X" :fol.core) 0)))
    (multiple-value-bind (val) (ip-fol src)
      (is (= val 3)))))

(test ip-unprovable-argument-does-not-prove
  "A call site whose argument is not itself provably a single class (a bare
   parameter of unknown type) must not prove the callee's parameter type,
   even though every OTHER call site passes a provable literal constructor."
  (let ((src "
(defclass <ip-b3> [] [[x]])
(defn ip-b3-get-x [p] (get p :x))
(defn ip-b3-passthrough [q] (ip-b3-get-x q))
(defn ip-b3-run []
  (+ (ip-b3-get-x (make-<ip-b3> :x 7))
     (ip-b3-passthrough (make-<ip-b3> :x 8))))
(ip-b3-run)"))
    (ip-analyze src)
    ;; IP-B3-PASSTHROUGH's own param Q is never proven (it is read, not
    ;; constructed, by its single caller's evidence chain -- Q's type is
    ;; never itself established), so the call (IP-B3-GET-X Q) inside it is
    ;; unprovable evidence for IP-B3-GET-X's own parameter.
    (is (null (ip-param-type (intern "IP-B3-GET-X" :fol.core) 0)))
    (multiple-value-bind (val) (ip-fol src)
      (is (= val 15)))))

(test ip-indirect-reference-forces-conflict
  "A tracked function's name used as a first-class value (not a direct call)
   forces its facts to CONFLICT -- call sites cannot be enumerated soundly."
  (let ((src "
(defclass <ip-b4> [] [[x]])
(defn ip-b4-get-x [p] (get p :x))
(defn ip-b4-run []
  (bind [f ip-b4-get-x]
    (funcall f (make-<ip-b4> :x 9))))
(ip-b4-run)"))
    (ip-analyze src)
    (is (null (ip-param-type (intern "IP-B4-GET-X" :fol.core) 0)))
    (multiple-value-bind (val) (ip-fol src)
      (is (= val 9)))))

;;; ============================================================================
;;; Robustness: recursion terminates the fixed point correctly
;;; ============================================================================

(test ip-self-recursive-function-terminates-and-stays-correct
  "A self-recursive single-clause function does not hang or crash the fixed
   point; results are unaffected either way."
  (let ((src "
(defclass <ip-c1> [] [[x]])
(defn ip-c1-count-down [p n]
  (if (< n 1)
      (get p :x)
      (ip-c1-count-down p (- n 1))))
(ip-c1-count-down (make-<ip-c1> :x 42) 5)"))
    (multiple-value-bind (val) (ip-fol src)
      (is (= val 42)))))

(test ip-mutually-recursive-functions-terminate-and-stay-correct
  "A mutually-recursive pair does not hang or crash the fixed point."
  (let ((src "
(defclass <ip-c2> [] [[x]])
(defn ip-c2-a [p n] (if (< n 1) (get p :x) (ip-c2-b p (- n 1))))
(defn ip-c2-b [p n] (if (< n 1) (get p :x) (ip-c2-a p (- n 1))))
(ip-c2-a (make-<ip-c2> :x 99) 6)"))
    (multiple-value-bind (val) (ip-fol src)
      (is (= val 99)))))

;;; ============================================================================
;;; Runtime safety: redefinition falls back correctly
;;; ============================================================================

(test ip-class-redefinition-falls-back-to-generic-get
  "After a proven-type GET-bypass is compiled and loaded, renaming the slot
   its fast path reads must not crash subsequent calls -- the world guard
   (REGISTER-REGION, invalidated by EMIT-DEFCLASS's NOTE-REDEFINITION call)
   must fall the already-compiled fast path back to generic GET, which
   tolerates a missing key, rather than signaling SLOT-VALUE's unbound/
   missing-slot condition on the renamed slot."
  (let ((src "
(defclass <ip-d1> [] [[x] [y]])
(defn ip-d1-get-x [p] (get p :x))
(ip-d1-get-x (make-<ip-d1> :x 1 :y 2))"))
    (multiple-value-bind (val1) (ip-fol src)
      (is (= val1 1)))
    ;; Rename :x's slot away; NOTE-REDEFINITION (EMIT-DEFCLASS) invalidates
    ;; every region REGISTER-REGION registered against "<IP-D1>".
    (let ((redef "(defclass <ip-d1> [] [[xrenamed] [y]])"))
      (eval (fol.compiler:compilation-result-code
             (fol.compiler:compile-form (first (ip-read-forms redef))))))
    ;; Without invalidation, the stale fast path's (SLOT-VALUE obj 'X) would
    ;; signal an error (the class no longer has a slot named X). With
    ;; invalidation, it falls back to generic GET, which tolerates the now-
    ;; missing :X key and returns NIL rather than crashing.
    (multiple-value-bind (val2)
        (ip-fol "(ip-d1-get-x (make-<ip-d1> :xrenamed 10 :y 20))")
      (is (null val2)))))

;;; ============================================================================
;;; (make 'TYPE ...) recognized alongside MAKE-<TYPE> ...) as a constructor
;;; ============================================================================

(test ip-quoted-make-recognized-by-infer-type-from-constructor
  "INFER-TYPE-FROM-CONSTRUCTOR recognizes both constructor call spellings:
   the MAKE-<TYPE> literal-call form and MAKE's own EQL-specialized-generic
   (make 'TYPE ...) form, on the same class. Purely syntactic -- the class
   need not exist for this recognition step itself."
  (flet ((ctor-type (source)
           (fol.compiler::infer-type-from-constructor
            (fol.compiler::parse-form (first (ip-read-forms source))))))
    (is (eq (ctor-type "(make-<ip-e1> :x 1 :y 2)") (intern "<IP-E1>" :fol.core)))
    (is (eq (ctor-type "(make (quote <ip-e1>) :x 1 :y 2)") (intern "<IP-E1>" :fol.core)))
    (is (eq (ctor-type "(make (quote <ip-e1>))") (intern "<IP-E1>" :fol.core)))
    ;; Not a constructor call at all -- must stay NIL, not misfire.
    (is (null (ctor-type "(make)")))
    (is (null (ctor-type "(some-other-fn (quote <ip-e1>))")))))

(test ip-quoted-make-direct-call-site-proves-param-type
  "A direct call site passing (make 'TYPE ...) proves the callee's parameter
   type exactly as a literal MAKE-<TYPE> call does, and the GET-bypass fires."
  (let ((src "
(defclass <ip-e2> [] [[x] [y]])
(defn ip-e2-total [p] (+ (get p :x) (get p :y)))
(ip-e2-total (make (quote <ip-e2>) :x 3 :y 4))"))
    (multiple-value-bind (val codes) (ip-fol src)
      (is (= val 7))
      (is (ip-any-code-has codes "SLOT-VALUE")))))

(test ip-quoted-make-wrapper-return-class-proven
  "A wrapper/factory function whose tail expression is (make 'TYPE ...) gets
   its RETURNS-CLASS proven, closing the same wrapper gap as MAKE-<TYPE>."
  (let ((src "
(defclass <ip-e3> [] [[x] [y]])
(defn ip-e3-build [x y] (make (quote <ip-e3>) :x x :y y))
(defn ip-e3-total [p] (+ (get p :x) (get p :y)))
(ip-e3-total (ip-e3-build 5 6))"))
    (ip-analyze src)
    (is (eq (ip-returns-class (intern "IP-E3-BUILD" :fol.core)) (intern "<IP-E3>" :fol.core)))
    (multiple-value-bind (val codes) (ip-fol src)
      (is (= val 11))
      (is (ip-any-code-has codes "SLOT-VALUE")))))

;;; ============================================================================
;;; End-to-end against the real order-totals benchmark files (not just a
;;; miniature reproduction), mirroring how DVI's own obstacles were verified
;;; against benchmarks/fol-code/derived-value-invalidation.fol directly.
;;; ============================================================================

(defun ip-compile-benchmark-file (relative-path)
  "Compile a real benchmark .fol file (RELATIVE-PATH under the project root)
   via FOL.COMPILER:COMPILE-FILE, to a scratch .lisp path, then LOAD the
   resulting fasl. Returns the transpiled code as a string (for SLOT-VALUE/
   GET presence checks)."
  (let* ((source (asdf:system-relative-pathname
                  :fol-compiler (concatenate 'string "../" relative-path)))
         (out (merge-pathnames (make-pathname :type "lisp" :name (pathname-name source))
                                (uiop:temporary-directory))))
    (load (fol.compiler:compile-file source :output out))
    (uiop:read-file-string out)))

(test ip-order-totals-benchmark-slot-value-fires
  "The real order-totals.fol benchmark file compiles ORDER-TOTAL's three
   keyword-accessor reads to SLOT-VALUE (not generic GET), and SUM-ORDERS
   produces the correct sum -- verified against the actual committed
   benchmark file, not a miniature reproduction of its shape."
  (let ((code (ip-compile-benchmark-file "benchmarks/fol-code/order-totals.fol")))
    ;; SLOT-VALUE is the fast path; (GET O :SUBTOTAL) legitimately still
    ;; appears too, as the guarded fallback for a redefined class -- both
    ;; belong in the SAME dual-path (IF guard (SLOT-VALUE ...) (GET ...)).
    (is (search "SLOT-VALUE" code))
    (is (search "REGISTER-REGION" code))
    (is (= (fol.core::sum-orders 100) (loop for i below 100 sum (+ (* i 3) (* i 1) 5))))))

(test ip-order-totals-unprovable-benchmark-stays-generic-get
  "The companion control file's multi-clause BUILD-ORDER2 is correctly
   invisible to the analysis: ORDER2-TOTAL's reads stay on generic GET, and
   SUM-ORDERS2 still produces the same correct sum as the provable variant."
  (let* ((code (ip-compile-benchmark-file "benchmarks/fol-code/order-totals-unprovable.fol"))
         ;; MAKE-<ORDER2>'s own constructor legitimately uses SLOT-VALUE
         ;; internally (field initialization) regardless of the GET-bypass;
         ;; isolate ORDER2-TOTAL's own body, which is what must stay generic.
         (start (search "(DEFUN ORDER2-TOTAL" code))
         (order2-total-body (subseq code start (+ start 200))))
    (is (search "(GET O :SUBTOTAL)" order2-total-body))
    (is (not (search "SLOT-VALUE" order2-total-body)))
    (is (not (search "REGISTER-REGION" order2-total-body)))
    (is (= (fol.core::sum-orders2 100) (loop for i below 100 sum (+ (* i 3) (* i 1) 5))))
    (is (= (fol.core::sum-orders2 100) (fol.core::sum-orders 100)))))
