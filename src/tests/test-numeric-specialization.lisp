;;; FOL Compiler Tests - Numeric type specialization (flow inference #1)
;;;
;;; The *numeric-specialization* pass infers loop-variable numeric types from
;;; literal initializers (propagated through arithmetic to a fixpoint), rewrites
;;; generic arithmetic on proven-number operands to CL operators, and declares
;;; float/integer loop variables. Tests: optimized == unoptimized on several loop
;;; shapes, the rewrite actually fires (CL ops + type declarations emitted), and
;;; it declines when operands are not provably numeric.

(in-package :fol.compiler.tests)

(def-suite numeric-specialization-suite
  :description "Numeric specialization: optimized == unoptimized, and it fires"
  :in compiler-tests)

(in-suite numeric-specialization-suite)

(defun ns-fol (source &key ns)
  "Read FOL SOURCE with the FOL readtable, compile each form with numeric
   specialization per NS, evaluate it, and return (values LAST-VALUE LAST-CODE)."
  (let ((fol.compiler.escape-analysis:*numeric-specialization* ns)
        (*readtable* fol.compiler.reader:*fol-readtable*)
        (*package* (find-package :fol.core))
        (val nil) (code nil))
    (with-input-from-string (in source)
      (loop for form = (read in nil :eof)
            until (eq form :eof)
            do (setf code (fol.compiler:compilation-result-code
                           (fol.compiler:compile-form form)))
               (setf val (eval code))))
    (values val code)))

(defun ns-code-has (code substring)
  (and (search substring (let ((*package* (find-package :keyword)))
                           (write-to-string code)))
       t))

;;; ============================================================================
;;; Correctness: specialized result == unspecialized result
;;; ============================================================================

(test ns-float-sum-correct
  "A single-float accumulator summed in a loop is bit-identical specialized."
  (let ((src "
(defn ns-fa [n] (loop [x 0.0 i 0] (if (< i n) (recur (+ x 0.5) (inc i)) x)))
(ns-fa 1000)"))
    (is (= 500.0 (ns-fol src :ns nil)))
    (is (eql (ns-fol src :ns nil) (ns-fol src :ns t)))))

(test ns-integer-correct
  "An integer accumulator (doubling) is identical specialized."
  (let ((src "
(defn ns-ib [n] (loop [a 1 i 0] (if (< i n) (recur (* a 2) (inc i)) a)))
(ns-ib 12)"))
    (is (= 4096 (ns-fol src :ns nil)))
    (is (eql (ns-fol src :ns nil) (ns-fol src :ns t)))))

(test ns-coupled-correct
  "A coupled two-field float recurrence (rotation-like) is identical."
  (let ((src "
(defn ns-rot [n]
  (loop [re 1.0 im 0.0 i 0]
    (if (< i n)
      (recur (- (* re 0.99) (* im 0.1)) (+ (* re 0.1) (* im 0.99)) (inc i))
      (+ re im))))
(ns-rot 100)"))
    (is (eql (ns-fol src :ns nil) (ns-fol src :ns t)))))

(test ns-division-and-bind-correct
  "Division and a bind-bound intermediate used in recur are identical."
  (let ((src "
(defn ns-dv [n]
  (loop [s 0.0 i 0]
    (if (< i n) (bind [d (/ 1.0 (+ i 1))] (recur (+ s d) (inc i))) s)))
(ns-dv 20)"))
    (is (eql (ns-fol src :ns nil) (ns-fol src :ns t)))))

;;; ============================================================================
;;; Application: the pass rewrites generic ops to CL ops and declares types
;;; ============================================================================

(test ns-fires-cl-ops-and-decls
  "With the flag on, the single-float accumulator loop emits CL:+ / CL:1+ and a
   SINGLE-FLOAT type declaration; with it off, the generic operators remain."
  (multiple-value-bind (val on-code)
      (ns-fol "
(defn ns-em [n] (loop [x 0.0 i 0] (if (< i n) (recur (+ x 0.5) (inc i)) x)))"
              :ns t)
    (declare (ignore val))
    (is (ns-code-has on-code "COMMON-LISP:+"))
    (is (ns-code-has on-code "COMMON-LISP:1+"))
    (is (ns-code-has on-code "SINGLE-FLOAT")))
  (multiple-value-bind (val off-code)
      (ns-fol "
(defn ns-em2 [n] (loop [x 0.0 i 0] (if (< i n) (recur (+ x 0.5) (inc i)) x)))"
              :ns nil)
    (declare (ignore val))
    ;; generic (array-functions) + remains; no CL:+ rewrite
    (is (ns-code-has off-code "ARRAY-FUNCTIONS:+"))
    (is (not (ns-code-has off-code "COMMON-LISP:1+")))))

;;; ============================================================================
;;; Conservatism: non-numeric operands are not rewritten
;;; ============================================================================

(test ns-declines-on-unknown-operand
  "An accumulator combined with an unknown-typed value (a collection element) is
   not proven numeric, so its arithmetic is left as the generic operator."
  (multiple-value-bind (val code)
      (ns-fol "
(defn ns-un [v] (loop [x 0.0 i 0] (if (< i 3) (recur (+ x (get v i)) (inc i)) x)))"
              :ns t)
    (declare (ignore val))
    ;; (get v i) is not provably numeric -> the + on it stays generic.
    (is (ns-code-has code "ARRAY-FUNCTIONS:+"))))
