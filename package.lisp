;;; Delete packages in reverse dependency order to ensure clean reload
;; (eval-when (:compile-toplevel :load-toplevel :execute)
;;   (dolist (pkg '(:fol.repl :fol.eval :fol.env :fol.module :fol.seqop :fol.collection
;;                  :fol.number :fol.symbol :fol.string :fol.char :fol.bool
;;                  :fol.compareop :fol.arithop :fol.bitop :fol.logop
;;                  :fol.wrappers :fol.reader :fol.stream :fol.classes :fol.mop :fol.fol-mop :fol.persistent))
;;     (when (find-package pkg)
;;       (delete-package pkg))))

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
   persistent-object-p
   ;; Constructor generation protocol
   class-name-string
   bare-class-name
   constructor-name
   class-initargs
   required-initargs
   optional-initargs
   make-instance*
   define-constructor
   define-constructors
   generate-constructor-form
   list-constructible-classes
   describe-constructor))

(defpackage fol.fol-mop
  (:use cl)
  (:export
   ;; Generic constructor
   make
   ;; FOL-style MOP macros
   defgeneric*
   defclass*
   defmethod*
   ;; Runtime evaluation functions
   eval-defgeneric*
   eval-defclass*
   eval-defmethod*
   ;; Helper functions
   vector-to-list
   convert-slot-specifier
   convert-specialized-param
   ;; Pattern analysis functions (for multi-pattern dispatch)
   pattern-expects-seq-p
   compute-pattern-signature
   pattern-more-specific-p
   generate-pattern-check
   generate-args-pattern-check
   make-pattern-name))

(defpackage fol.classes
  (:use cl)
  (:export <bool> <char> <string> <symbol> <keyword>
           <number> <complex> <real> <float>
           <single-float> <double-float> <rational>
           <integer> <fixnum> <bignum> <ratio>
           ;; Regex classes
           <re-pattern> <re-scanner>
           scanner-function scanner-register-names
           ;; UUID class
           <uuid>
           ;; Stream classes
           <stream> <input-stream> <output-stream>
           <string-input-stream> <file-input-stream>
           <string-output-stream> <file-output-stream>
           stream-open-p stream-source-string stream-file-path
           val -fol-value symbol-module-name symbol-val))

(defpackage fol.stream
  (:use cl fol.classes)
  (:shadow open close
           make-string-input-stream make-string-output-stream
           get-output-stream-string
           with-open-stream)
  (:export
   ;; Type predicates
   <stream>? <input-stream>? <output-stream>?
   <string-input-stream>? <file-input-stream>?
   <string-output-stream>? <file-output-stream>?
   ;; Constructors
   make-string-input-stream make-file-input-stream
   make-string-output-stream make-file-output-stream
   ;; Operations
   open close
   stream-open? stream-closed?
   get-output-stream-string
   ;; Reading/writing
   read-char* write-char* write-string* read-line*
   ;; Macro
   with-open-stream))

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
  (:shadow make-array make-list get remove first rest second third nth pop push reverse vector assoc)
  (:export <collection> <collection>?
           <unordered-collection> <unordered-collection>?
           <ordered-collection> <ordered-collection>?
           <dict> <dict>? make-dict
           <array-dict> <array-dict>? make-array-dict array-dict array-dict-with-limit
           <sorted-dict> <sorted-dict>? make-sorted-dict sorted-dict sorted-dict-by
           <ordered-dict> <ordered-dict>? make-ordered-dict ordered-dict
           <priority-dict> <priority-dict>? make-priority-dict priority-dict
           <int-dict> <int-dict>? make-int-dict int-dict
           <bag> <bag>? make-bag
           <set> <set>? make-set
           <sorted-set> <sorted-set>? make-sorted-set
           <ordered-set> <ordered-set>? make-ordered-set
           <int-set> <int-set>? make-int-set
           <dense-int-set> <dense-int-set>? make-dense-int-set
           <sorted-set-by> <sorted-set-by>? sorted-set-by
           <vector> <vector>? make-vector
           <list> <list>? make-list
           <lazy-seq> <lazy-seq>? make-lazy-seq
           realize-lazy-seq lazy-seq-realized-p
           <reduced> <reduced>? reduced unreduced reduced-value
           <array> <array>? make-array
           ;; GENERIC OPERATIONS
           get seq
           size empty? contains?
           add conj remove
           iterator next current done?
           ;; List-specific operations
           first rest second third nth
           list-first list-rest list-size
           ;; Additional operations
           nth-element set-nth
           ;; Index operations
           index-of last-index-of
           ;; Reverse
           reverse
           ;; Stack-like operations
           peek pop push
           ;; Disjoin (removal for unordered collections)
           disj
           ;; Sizing operations
           sized? bounded-size
           ;; Into
           into
           ;; Eager vector operations
           vector vec mapv filterv
           ;; Associative operations
           assoc assoc-in sub
           ;; Reversed sequence
           rseq
           ;; Update operations
           update update-in
           ;; Key-value reduce
           reduce-kv))

(defpackage fol.seqop
  (:use cl fol.wrappers fol.classes fol.collection fol.persistent)
  ;; Import symbols already shadowed by fol.collection to avoid creating duplicates
  (:shadowing-import-from fol.collection
                          assoc get rest first reverse remove pop push make-list
                          third second nth vector make-array)
  ;; Shadow CL functions to allow our own generic functions
  (:shadow set-difference set-intersection find merge)
  (:export
   ;; Collection accessors
    conj first rest peek pop push nth get
   ;; Collection info
    size empty? seq contains?
   ;; Collection modification
    add remove disj
   ;; Associative operations
    assoc assoc-in sub
   ;; Sequence operations
    reverse index-of last-index-of rseq
   ;; Update operations
    update update-in reduce-kv
   ;; Set operations
    set-union set-difference set-intersection
    select subset? superset?
    subs rsubs
   ;; Dict query operations
    get-in find keys vals key val
   ;; Dict modification operations
    dissoc merge merge-with
   ;; Dict transformation operations
    select-keys rename-keys map-invert update-keys update-vals
   ;; Dict construction operations
    freqs group-by index))

(defpackage fol.module
  (:use cl fol.persistent fol.collection)
  (:shadowing-import-from fol.collection
                          make-array
                          make-list
                          get
                          remove
                          first
                          rest
                          second
                          third
                          nth
                          pop
                          push
                          reverse
                          vector
                          assoc)
  (:export <module> <module>? make-module
           module-name module-exports module-export module-import
           find-module register-module +module-registry+
           ensure-standard-modules))

(defpackage fol.env
  (:use cl fol.persistent fol.collection)
  (:shadowing-import-from fol.collection
                          make-array
                          make-list
                          get
                          remove
                          first
                          rest
                          second
                          third
                          nth
                          pop
                          push
                          reverse
                          vector
                          assoc)
  (:export <env> <env>? make-env lookup env-previous unbound-variable fol-unbound-variable fol-unbound-variable-name fol-unbound-variable-message))

(defpackage fol.logop
  (:use cl fol.wrappers fol.classes)
  (:shadow not and or)
  (:export not and or xor implies nand nor
           ;; Binary primitives (for advanced use)
           %and %or %xor))

(defpackage fol.bitop
  (:use cl fol.wrappers fol.classes)
  ;; Shadow CL bit-array functions that we redefine for integers
  (:shadow bit-nand bit-nor bit-andc1 bit-andc2 bit-orc1 bit-orc2)
  (:export bitnot bitand bitor bitxor
           bit-nand bit-nor bit-andc1 bit-andc2 bit-orc1 bit-orc2
           bit-test bit-set bit-clear bit-count
           bit-shift bit-rotate))

(defpackage fol.arithop
  (:use cl fol.wrappers fol.classes)
  ;; Shadow both arithmetic and math functions
  (:shadow + - * /
           abs
           sin cos tan asin acos atan
           sinh cosh tanh asinh acosh atanh
           exp ln expt sqrt
           rationalize numerator denominator
           real-part imag-part angle
           gcd lcm
           rationalize)
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
  (:export <bool>? parse-bool))

(defpackage fol.char
  (:use cl fol.wrappers fol.classes)
  (:shadow char-upcase char-downcase)
  (:export <char>?
           char-upcase char-downcase
           alpha-char? digit-char? alphanumeric?
           upper-case? lower-case? whitespace?
           char-name-string))

(defpackage fol.string
  (:use cl fol.wrappers fol.classes)
  (:shadow trim capitalize replace)
  (:export <string>?
           ;; String manipulation
           blank? trim triml trimr trim-newline
           capitalize
           starts-with? ends-with? includes?
           ;; Replace operations
           replace replace-first
           ;; Join and split operations
           join escape split split-lines
           ;; Regex pattern
           <re-pattern>? wrap-re-pattern
           ;; Regex scanner
           <re-scanner>? make-re-scanner
           ;; Regex matching
           re-find re-seq
           ;; UUID
           <uuid>? parse-uuid))

(defpackage fol.symbol
  (:use cl fol.wrappers fol.classes)
  (:shadow keyword symbol gensym)
  (:export <symbol>? <keyword>?
           symbol-name-str
           symbol-package-str
           get-symbol-value
           set-symbol-value
           symbol-bound?
           as
           keyword
           find-keyword
           symbol
           gensym
           +symbol-unbound-sentinel+
           ;; Module constants and interning
           +keyword-module+
           +default-module+
           *current-module*
           fol-intern
           parse-qualified-name))

(defpackage fol.number
  (:use cl fol.wrappers fol.classes)
  (:export
   ;; Type predicates
   <number>? <complex>? <real>?
   <float>? <single-float>? <double-float>?
   <rational>? <ratio>? <integer>? <fixnum>? <bignum>?
   ;; Value predicates
   odd? even? zero? positive? negative? integral?
   nat-int? pos-int? NaN? infinite?
   ;; Type conversion functions
   <complex> <single-float> <double-float> int
   ;; Parsing functions
   parse-int parse-double
   ;; Random number generation
   rand make-seeded-random-state call-with-seed))

(defpackage fol.eval
  (:use cl fol.wrappers fol.classes fol.collection fol.env)
  (:shadow macroexpand macroexpand-1)
  (:shadowing-import-from fol.collection
                          make-array
                          make-list
                          get
                          remove
                          first
                          rest
                          second
                          third
                          nth
                          pop
                          push
                          reverse
                          vector
                          assoc)
  (:shadowing-import-from fol.logop
                          not and or)
  (:shadowing-import-from fol.arithop
                          + - * /
                          abs sin cos tan asin acos atan
                          sinh cosh tanh asinh acosh atanh
                          exp ln expt sqrt
                          rationalize numerator denominator
                          gcd lcm)
  (:shadowing-import-from fol.compareop
                          = /= < <= > >= min max)
  (:import-from fol.logop xor implies nand nor)
  (:import-from fol.arithop atan2 real-part imag-part angle)
  (:import-from fol.fol-mop make
                vector-to-list
                pattern-expects-seq-p
                compute-pattern-signature
                pattern-more-specific-p
                make-pattern-name)
  (:import-from fol.bool <bool>?)
  (:import-from fol.char <char>?)
  (:import-from fol.string <string>?)
  (:shadowing-import-from fol.symbol <symbol>? <keyword>?)
  (:import-from fol.number
                <number>? <complex>? <real>?
                <float>? <single-float>? <double-float>?
                <rational>? <ratio>? <integer>? <fixnum>? <bignum>?
                positive? negative? zero? even? odd?)
  (:export
   ;; Main evaluation function
   fol-eval
   ;; Special form evaluators (for extensibility)
   eval-quote eval-if eval-do eval-bind eval-fn eval-def eval-defn
   eval-loop eval-recur eval-throw eval-try eval-defmacro eval-syntax-quote
   eval-make-dynamic eval-binding eval-lazy-seq
   eval-thread-first eval-thread-last
   ;; Conditions
   fol-eval-error fol-eval-error-message fol-eval-error-form
   fol-arity-error fol-arity-error-expected fol-arity-error-got
   fol-type-error fol-type-error-expected fol-type-error-actual fol-type-error-variable
   ;; Utilities
   make-function apply-function
   ;; Macro utilities
   make-macro expand-macro macroexpand-1 macroexpand
   ;; Syntax-quote utilities
   expand-syntax-quote unquote-form-p unquote-splicing-form-p auto-gensym-symbol-p
   ;; Dynamic variable utilities
   <dynamic-var> <dynamic-var>? make-dynamic-var
   dynamic-var-name dynamic-var-value dynamic-var-root-value
   dynamic-var-push dynamic-var-pop
   ;; Standard environment
   make-standard-env
   ;; Function class and predicate
   <function> <function>?
   ;; Macro class, predicate, and accessors
   <macro> <macro>? macro-name macro-params macro-body macro-env macro-rest-param
   ;; Multi-pattern macro class, predicate, and functions
   <multi-macro> <multi-macro>? make-multi-macro expand-multi-macro
   ;; Higher-order function combinators (for use in standard env)
   disjoin conjoin partial rpartial juxt
   ;; Higher-order collection operations
   filter keep mapcat interleave interpose
   ;; Lazy sequence generators
   range iterate repeat repeatedly cycle
   ;; Lazy sequence operations
   take drop
   ;; Reduced (for early termination)
   reduced?
   ;; Increment/decrement
   inc dec
   ;; String operations
   str
   ;; Misc utilities
   identity complement type
   ;; Standard environment symbols (for macro form construction)
   cl-cons cl-list))

(defpackage fol.repl
  (:use cl)
  (:shadow * ** *** + ++ +++ / // ///)
  (:import-from fol.reader fol-read-from-string *clojure-readtable*)
  (:import-from fol.eval make-standard-env)
  (:export repl
           * ** ***
           + ++ +++
           / // ///
           fol-form
           fol-test))

;;; Define the symbol unbound sentinel constant early so it can be used in classes.lisp
(in-package fol.symbol)
(defparameter +symbol-unbound-sentinel+ '*unbound*
  "Sentinel value representing an unbound symbol. This distinguishes unbound symbols from symbols bound to NIL.")
