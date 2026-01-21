(defpackage fol.persistent
  (:use cl)
  (:import-from closer-mop
                class-slots
                slot-definition-name
                slot-definition-initfunction
                validate-superclass
                standard-effective-slot-definition
                slot-value-using-class
                slot-boundp-using-class
                slot-makunbound-using-class)
  (:export persistent-class
           <persistent-object>
           pslot-value
           set-pslot-value
           set-pslot-values
           with-pslots
           <persistent-object>?
           %persistent-storage))

(defpackage fol.mop
  (:use cl fol.persistent)
  (:import-from closer-mop)
  (:export
   ;; Class introspection
   class-name*
   class-direct-superclasses*
   class-direct-subclasses*
   class-precedence-list*
   class-direct-slots*
   class-slots*
   finalized-p
   ensure-finalized
   ;; Slot definition introspection
   slot-definition-name*
   slot-definition-type*
   slot-definition-initargs*
   slot-definition-initform*
   slot-definition-initfunction*
   slot-definition-allocation*
   slot-definition-readers*
   slot-definition-writers*
   ;; Instance introspection
   instance-class
   instance-slots
   slot-names
   slot-exists-p*
   slot-boundp*
   slot-value*
   ;; Utility functions
   all-persistent-classes
   subclasses*
   superclasses*
   find-slot-definition
   slot-properties
   class-info
   describe-class
   describe-slot
   persistent-class-p
   persistent-object-p))

(defpackage fol.classes
  (:use cl)
  (:export <bool> <char> <string> <symbol> <keyword>
           <number> <complex> <real> <float>
           <single-float> <double-float> <rational>
           <integer> <fixnum> <bignum> <ratio>
           val -fol-value symbol-module-name symbol-val))

(defpackage fol.reader
  (:use cl fol.classes)
  (:export <readtable>
           make-readtable
           <readtable>?
           fol-set-macro-character
           fol-get-macro-character
           readtable-dispatch-table
           fol-set-dispatch-macro-character
           fol-get-dispatch-macro-character
           <character-class-table>
           make-character-class-table
           <character-class-table>?
           fol-read
           fol-read-from-string
           with-readtable
           *clojure-readtable*
           *fol-readtable*))

(defpackage fol.wrappers
  (:use cl fol.classes)
  (:export
   ;; Core protocol
   fol-value
   fol-type-of
   ;; Wrapping functions
   wrap unwrap
   wrap-bool unwrap-bool
   wrap-char unwrap-char
   wrap-string unwrap-string
   wrap-symbol unwrap-symbol
   wrap-number unwrap-number
   ;; Type checking utilities
   fol-numberp fol-integerp fol-realp
   fol-stringp fol-characterp fol-symbolp fol-booleanp))

(defpackage fol.collection
  (:use cl fol.persistent)
  (:shadow make-array get remove)
  (:export <collection> <collection>?
           <unordered-collection> <unordered-collection>?
           <ordered-collection> <ordered-collection>?
           <dict> <dict>? make-dict
           <bag> <bag>? make-bag
           <set> <set>? make-set
           <vector> <vector>? make-vector
           <array> <array>? make-array
           ;; GENERIC OPERATIONS
           get
           size empty? contains?
           add remove
           iterator next current done?
           ;; Additional operations
           nth-element set-nth))

(defpackage fol.module
  (:use cl fol.persistent fol.collection)
  (:shadowing-import-from fol.collection
                          make-array
                          get
                          remove)
  (:export <module> <module>? make-module))

(defpackage fol.env
  (:use cl fol.persistent fol.collection)
  (:shadowing-import-from fol.collection
                          make-array
                          get
                          remove)
  (:export <env> <env>? make-env lookup env-previous unbound-variable fol-unbound-variable fol-unbound-variable-name fol-unbound-variable-message))

(defpackage fol.logop
  (:use cl fol.wrappers fol.classes)
  (:shadow not and or)
  (:export not and or xor implies nand nor
           ;; Binary primitives (for advanced use)
           %and %or %xor))

(defpackage fol.arithop
  (:use cl fol.wrappers fol.classes)
  ;; Shadow both arithmetic and math functions
  (:shadow + - * /
           abs
           sin cos tan asin acos atan
           sinh cosh tanh asinh acosh atanh
           exp log expt sqrt
           rationalize numerator denominator
           real-part imag-part angle
           gcd lcm)
  (:export
   ;; Basic arithmetic
   + - * /
   ;; Math functions
   abs
   sin cos tan asin acos atan atan2
   sinh cosh tanh asinh acosh atanh
   exp log expt sqrt
   rationalize numerator denominator
   real-part imag-part angle
   gcd lcm
   ;; Binary primitives (for advanced use)
   %+ %- %* %/ %gcd %lcm))

(defpackage fol.compareop
  (:use cl fol.wrappers fol.classes fol.persistent)
  (:shadow = /= < <= > >= min max)
  (:export = /= < <= > >= min max
           ;; Binary primitives (for advanced use)
           %= %/= %< %<= %> %>=))

(defpackage fol.bool
  (:use cl fol.wrappers fol.classes)
  (:export <bool>?))

(defpackage fol.char
  (:use cl fol.wrappers fol.classes)
  (:shadow char-upcase char-downcase)
  (:export <char>?
           char-upcase char-downcase
           alpha-char? digit-char? alphanumeric?
           upper-case? lower-case? whitespace?))

(defpackage fol.string
  (:use cl fol.wrappers fol.classes)
  (:export <string>?))

(defpackage fol.symbol
  (:use cl fol.wrappers fol.classes)
  (:export <symbol>? <keyword>?
           symbol-name-str
           symbol-package-str
           get-symbol-value
           set-symbol-value
           symbol-bound?
           as
           +symbol-unbound-sentinel+))

(defpackage fol.number
  (:use cl fol.wrappers fol.classes)
  (:export
   ;; Type predicates
   <number>? <complex>? <real>?
   <float>? <single-float>? <double-float>?
   <rational>? <ratio>? <integer>? <fixnum>? <bignum>?
   ;; Value predicates
   odd? even? zero? positive? negative? integral?))

(defpackage fol.eval
  (:use cl fol.wrappers fol.classes fol.collection fol.env)
  (:shadowing-import-from fol.collection
                          make-array
                          get
                          remove)
  (:shadowing-import-from fol.logop
                          not and or)
  (:shadowing-import-from fol.arithop
                          + - * /
                          abs sin cos tan asin acos atan
                          sinh cosh tanh asinh acosh atanh
                          exp log expt sqrt
                          rationalize numerator denominator
                          gcd lcm)
  (:shadowing-import-from fol.compareop
                          = /= < <= > >= min max)
  (:import-from fol.logop xor implies nand nor)
  (:import-from fol.arithop atan2 real-part imag-part angle)
  (:shadowing-import-from fol.symbol <symbol>?)
  (:export
   ;; Main evaluation function
   fol-eval
   ;; Special form evaluators (for extensibility)
   eval-quote eval-if eval-do eval-let eval-let* eval-fn eval-def
   eval-loop eval-recur eval-throw eval-try
   ;; Conditions
   fol-eval-error fol-eval-error-message fol-eval-error-form
   fol-arity-error fol-arity-error-expected fol-arity-error-got
   ;; Utilities
   make-function apply-function
   ;; Standard environment
   make-standard-env
   ;; Function class and predicate
   <function> <function>?))

;;; Define the symbol unbound sentinel constant early so it can be used in classes.lisp
(in-package fol.symbol)
(defparameter +symbol-unbound-sentinel+ '*unbound*
  "Sentinel value representing an unbound symbol. This distinguishes unbound symbols from symbols bound to NIL.")
