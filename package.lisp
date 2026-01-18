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
           val fol-value symbol-module-name symbol-val))

(defpackage fol.singleton
  (:use cl fol.classes)
  (:export *true-instance* *false-instance* return-t return-f))

(defpackage fol.wrappers
  (:use cl fol.classes)
  (:shadowing-import-from fol.singleton *true-instance* *false-instance*)
  (:export wrap unwrap 
           wrap-bool unwrap-bool 
           wrap-char unwrap-char 
           wrap-string unwrap-string 
           wrap-symbol unwrap-symbol
           wrap-number unwrap-number))

(defpackage fol.collection
  (:use cl fol.persistent fol.singleton)
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
           iterator next current done?))

(defpackage fol.module
  (:use cl fol.persistent fol.collection fol.singleton)
  (:shadowing-import-from fol.collection 
                          make-array 
                          get 
                          remove)
  (:export <module> <module>? make-module))

(defpackage fol.syntax
  (:use cl)
  (:shadowing-import-from named-readtables defreadtable)
  (:shadowing-import-from fol.collection make-dict make-vector)
  (:export fol-syntax))

(defpackage fol.logop
  (:use cl fol.wrappers fol.classes)
  (:shadow not and or)
  (:export not and or xor implies nand nor))

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
   + - * /
   abs 
   sin cos tan asin acos atan atan2
   sinh cosh tanh asinh acosh atanh
   exp log expt sqrt
   rationalize numerator denominator
   real-part imag-part angle
   gcd lcm))

(defpackage fol.compareop
  (:use cl fol.wrappers fol.classes fol.persistent)
  (:shadow = /= < <= > >= min max))

(defpackage fol.bool
  (:use cl fol.wrappers fol.classes fol.singleton)
  (:shadowing-import-from fol.wrappers unwrap-bool)
  (:export <bool>?))

(defpackage fol.char
  (:use cl fol.wrappers fol.classes fol.singleton)
  (:shadowing-import-from fol.wrappers unwrap-char)
  (:shadow char-upcase char-downcase)
  (:export <char>?
           char-upcase char-downcase
           alpha-char? digit-char? alphanumeric? 
           upper-case? lower-case? whitespace?))

(defpackage fol.string
  (:use cl fol.wrappers fol.classes fol.singleton)
  (:shadowing-import-from fol.wrappers unwrap-string)
  (:export <string>?))

(defpackage fol.symbol
  (:use cl fol.wrappers fol.classes fol.singleton)
  (:shadowing-import-from fol.wrappers unwrap-symbol wrap-string unwrap-string wrap-bool)
  (:export <symbol>? <keyword>?
           symbol-name-str
           symbol-package-str
           get-symbol-value
           set-symbol-value
           symbol-bound?
           as
           +symbol-unbound-sentinel+))

(defpackage fol.number
  (:use cl fol.wrappers fol.classes fol.singleton)
  (:shadowing-import-from fol.wrappers unwrap-number)
  ;; Remove all the :shadow for math functions
  (:export 
   ;; Type predicates
   <number>? <complex>? <real>? 
   <float>? <single-float>? <double-float>? 
   <rational>? <ratio>? <integer>? <fixnum>? <bignum>?
   ;; Value predicates only
   odd? even? zero? positive? negative? integral?))

;;; Define the symbol unbound sentinel constant early so it can be used in classes.lisp
(in-package fol.symbol)
(defparameter +symbol-unbound-sentinel+ '*unbound*
  "Sentinel value representing an unbound symbol. This distinguishes unbound symbols from symbols bound to NIL.")