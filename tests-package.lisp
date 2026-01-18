(defpackage fol.tests
  (:use cl fiveam fol.syntax fol.singleton fol.classes fol.wrappers 
        named-readtables fol.bool fol.char fol.number fol.string
        fol.symbol fol.persistent fol.collection fol.mop)
  ;; Import logical operations INCLUDING nand and nor
  (:shadowing-import-from fol.logop not and or implies xor nand nor)
  ;; Import ALL functions from fol.arithop (arithmetic + math)
  (:shadowing-import-from fol.arithop 
                          + - * /                                  ; arithmetic
                          abs                                      ; basic math
                          sin cos tan asin acos atan atan2         ; trig
                          sinh cosh tanh asinh acosh atanh         ; hyperbolic
                          exp log expt sqrt                        ; exponentials
                          rationalize numerator denominator        ; scheme-type functions
                          real-part imag-part angle
                          gcd lcm)
  (:shadowing-import-from fol.compareop = /= < <= > >= min max)
  (:shadowing-import-from fol.char char-upcase char-downcase)
  (:shadowing-import-from fol.collection make-array get remove)
  (:import-from fol.char alpha-char? digit-char? alphanumeric?
                         upper-case? lower-case? whitespace?)
  (:export run-fol-tests))

(in-package fol.tests)

;;; Test suite definition
(def-suite fol-suite
  :description "Main test suite for FOL")

(defun run-fol-tests ()
  "Run all FOL tests."
  (run! 'fol-suite))