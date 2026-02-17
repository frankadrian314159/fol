;;; FOL Compiler - Package Definitions
;;;
;;; Defines the package hierarchy for the FOL-to-Common-Lisp compiler.
;;; The compiler reads FOL source (via the bootstrap reader), builds an AST,
;;; and emits Common Lisp code that SBCL compiles to native code.

(defpackage fol.compiler.primitives
  (:use cl)
  (:export
   ;; Primitive types
   <bool> <char> <string> <re-pattern>
   <symbol> <keyword>
   ;; Number hierarchy
   <number> <complex> <real> <float>
   <single-float> <double-float>
   <rational> <ratio> <integer> <fixnum> <bignum>
   ;; UUID
   <uuid>
   ;; Type mapping
   fol-type-class
   
   ;; Type predicates
   <bool>? <char>? <string>? <re-pattern>? <symbol>? <keyword>?
   <number>? <complex>? <real>? <float>? <single-float>? <double-float>?
   <rational>? <ratio>? <integer>? <fixnum>? <bignum>?
   <uuid>?
   ;; Constructor generic
   make
   ;; Value unwrapping
   fol-value
   ;;
   truthy? falsy?))

(defpackage fol.compiler.primitive-functions
  (:use cl)
  (:shadow symbol keyword gensym)
  (:export
   ;; Nil and Boolean predicates
   nil? some? <bool>? true? false?
   ;; Collection predicates
   <seq>? <collection>? <unordered-collection>? <ordered-collection>?
   <dict>? <ordered-dict>? <array-dict>? <sorted-dict>? <int-dict>? <priority-dict>?
   <set>? <ordered-set>? <sorted-set>? <int-set>? <dense-int-set>?
   <vector>? <list>? <lazy-seq>? <deque>? <bag>?
   ;; Collection category predicates
   sequential? associative? sorted? counted? reversible?
   ;; Map entry predicate
   map-entry?
   ;; Type checking
   <keyword>? <symbol>? <string>? <char>?
   <number>? <integer>? <float>? <rational>? <real>? <ratio>? <complex>?
   <single-float>? <double-float>? <fixnum>? <bignum>?
   <fn>?
   ;; Numeric predicates
   zero? odd? even?
   ;; Symbol construction
   symbol keyword find-keyword gensym
   ;; Equality
   identical? =?))

(defpackage fol.compiler.compareops
  (:use cl)
  (:shadow < > <= >= = /= min max)
  (:export
   ;; Binary primitives
   %< %> %<= %>= %= %/=
   ;; Variadic operators
   < > <= >= = /=
   ;; Min/Max
   min max))

(defpackage fol.compiler.ast
  (:use cl)
  (:export
   ;; AST node base
   ast-node ast-node-p
   ast-node-form ast-node-position
   ;; Literal nodes
   literal-node literal-node-p literal-node-value
   ;; Symbol reference
   symbol-ref-node symbol-ref-node-p symbol-ref-node-name
   ;; Function call
   call-node call-node-p call-node-operator call-node-args
   ;; Special forms
   if-node if-node-p if-node-test if-node-then if-node-else
   do-node do-node-p do-node-body
   bind-node bind-node-p bind-node-bindings bind-node-body
   fn-node fn-node-p fn-node-name fn-node-clauses
   def-node def-node-p def-node-name def-node-value
   defn-node defn-node-p defn-node-name defn-node-clauses
   loop-node loop-node-p loop-node-bindings loop-node-body
   recur-node recur-node-p recur-node-args
   quote-node quote-node-p quote-node-value
   ;; Threading
   thread-first-node thread-first-node-p thread-first-node-forms
   thread-last-node thread-last-node-p thread-last-node-forms
   ;; Condition handling
   handler-case-node handler-case-node-p handler-case-node-expr handler-case-node-clauses
   handler-bind-node handler-bind-node-p handler-bind-node-bindings handler-bind-node-body
   restart-case-node restart-case-node-p restart-case-node-expr restart-case-node-clauses
   signal-node signal-node-p signal-node-datum signal-node-args
   error-node error-node-p error-node-datum error-node-args
   warn-node warn-node-p warn-node-datum warn-node-args
   invoke-restart-node invoke-restart-node-p invoke-restart-node-name invoke-restart-node-args
   ;; Class system
   defclass-node defclass-node-p defclass-node-name defclass-node-superclasses defclass-node-slots
   defgeneric-node defgeneric-node-p defgeneric-node-name
   defgeneric-node-lambda-lists defgeneric-node-options
   defmethod-node defmethod-node-p defmethod-node-name defmethod-node-clauses
   ;; Collection literals
   vector-node vector-node-p vector-node-elements
   dict-node dict-node-p dict-node-entries
   set-node set-node-p set-node-elements
   ;; Dynamic variables
   defdynamic-node defdynamic-node-p defdynamic-node-name defdynamic-node-value
   make-defdynamic-node
   binding-node binding-node-p binding-node-bindings binding-node-body
   make-binding-node
   ;; Macro
   defmacro-node defmacro-node-p defmacro-node-name defmacro-node-params defmacro-node-body
   ;; Additional special forms
   cond-node cond-node-p cond-node-clauses make-cond-node
   cond-thread-first-node cond-thread-first-node-p cond-thread-first-node-expr cond-thread-first-node-clauses make-cond-thread-first-node
   cond-thread-last-node cond-thread-last-node-p cond-thread-last-node-expr cond-thread-last-node-clauses make-cond-thread-last-node
   syntax-quote-node syntax-quote-node-p syntax-quote-node-template make-syntax-quote-node
   unquote-node unquote-node-p unquote-node-expr make-unquote-node
   unquote-splicing-node unquote-splicing-node-p unquote-splicing-node-expr make-unquote-splicing-node
   case-node case-node-p case-node-expr case-node-clauses make-case-node
   env-node env-node-p make-env-node
   swap-node swap-node-p swap-node-atom-expr swap-node-fn-expr swap-node-args make-swap-node
   ;; Functional special forms
   defn-private-node defn-private-node-p defn-private-node-name defn-private-node-clauses make-defn-private-node
   definline-node definline-node-p definline-node-name definline-node-clauses make-definline-node
   as-thread-node as-thread-node-p as-thread-node-expr as-thread-node-name as-thread-node-forms make-as-thread-node
   some-thread-first-node some-thread-first-node-p some-thread-first-node-forms make-some-thread-first-node
   some-thread-last-node some-thread-last-node-p some-thread-last-node-forms make-some-thread-last-node
   ;; Constructors
   make-literal-node make-symbol-ref-node make-call-node make-if-node make-do-node make-bind-node
   make-fn-node make-def-node make-defn-node make-loop-node make-recur-node
   make-quote-node make-thread-first-node make-thread-last-node
   make-handler-case-node make-handler-bind-node make-restart-case-node
   make-signal-node make-error-node make-warn-node make-invoke-restart-node
   make-defclass-node make-defgeneric-node make-defmethod-node make-defmacro-node
   make-defdynamic-node make-binding-node
   make-vector-node make-dict-node make-set-node))

(defpackage fol.compiler.destructure
  (:use cl)
  (:export
   ;; Wildcard support
   wildcard-param-p
   replace-wildcards
   ;; Parameter parsing
   parse-params
   strip-specializers
   ;; Signature computation
   filter-as-bindings
   compute-element-signature
   compute-pattern-signature
   ;; Specificity comparison
   pattern-specificity-level
   pattern-more-specific-p
   ;; Type mapping
   fol-type-to-cl-type
   ;; Code emission
   emit-element-pattern-check
   emit-clause-pattern-check
   emit-param-bindings
   emit-single-param-binding
   emit-rest-param-binding
   ;; Fixed-arity optimization
   emit-fixed-arity-pattern-check
   emit-fixed-arity-param-bindings
   ;; Macro lambda list
   emit-macro-lambda-list
   convert-macro-param))

(defpackage fol.compiler.mutable
  (:use cl)
  (:shadow atom)
  (:export
   ;; Atom class
   <atom>
   <atom>?
   atom
   ;; Atom operations
   deref
   reset!
   swap!
   compare-and-set!
   ;; Ref (STM)
   <ref>
   <ref>?
   ref
   ref-set
   alter
   commute
   ensure
   dosync
   ;; Agent (async)
   <agent>
   <agent>?
   agent
   send
   send-off
   await
   agent-error
   restart-agent
   set-error-handler!
   set-error-mode!))

(defpackage fol.compiler.persistent
  (:use cl)
  (:export
   ;; Metaclass
   persistent-class
   ;; Base class
   <persistent-object>
   ;; Metadata
   %persistent-metadata
   ;; Functional update API
   update-slot
   update-slots))

(defpackage fol.compiler.collections
  (:use cl)
  (:shadow vector set list count array-dimension first rest get assoc dissoc conj size merge)
  (:import-from fol.compiler.primitives make)
  (:import-from fol.compiler.persistent persistent-class)
  (:shadowing-import-from fol.compiler.compareops < >)
  (:export
   ;; Base class
   <collection>
   ;; Storage base
   <collection-storage>
   storage-items
   ;; Type predicate
   <collection>?
   ;; Protocol generics
   collection-size
   collection-empty-p
   collection-conj
   collection-seq
   count
   empty?
   ;; High-level accessors
   first rest get assoc dissoc conj size update merge
   ;; Abstract subclasses
   <unordered-collection>
   <unordered-collection>?
   <ordered-collection>
   <ordered-collection>?
   ;; Re-export constructor generic
   make
   ;; Concrete: vector
   <vector>
   <vector>?
   ;; Concrete: dict
   <dict>
   <dict>?
   ;; Concrete: ordered-dict (subclass of dict)
   <ordered-dict>
   <ordered-dict>?
   ordered-dict-key-order
   ;; Concrete: sorted-dict
   <sorted-dict>
   <sorted-dict>?
   ;; Concrete: array-dict (subclass of dict, ordered)
   <array-dict>
   <array-dict>?
   array-dict-key-order
   ;; Concrete: priority-dict (subclass of dict)
   <priority-dict>
   <priority-dict>?
   priority-dict-tree
   priority-dict-compare
   priority-dict-peek-min
   priority-dict-pop-min
   ;; Concrete: set
   <set>
   <set>?
   ;; Concrete: array (subclass of vector)
   <array>
   <array>?
   array-dimension
   ;; Concrete: ordered-set
   <ordered-set>
   <ordered-set>?
   ;; Concrete: sorted-set
   <sorted-set>
   <sorted-set>?
   ;; Comparator
   <comparator>
   comparator-compare
   ;; Concrete: int-dict (subclass of sorted-dict)
   <int-dict>
   <int-dict>?
   ;; Concrete: int-set
   <int-set>
   <int-set>?
   ;; Concrete: dense-int-set
   <dense-int-set>
   <dense-int-set>?
   dense-int-set-offset
   dense-int-set-count
   ;; Concrete: bag
   <bag>
   <bag>?
   ;; Concrete: deque
   <deque>
   <deque>?
   ;; Concrete: list
   <list>
   <list>?
   list-first
   list-rest
   list-size
   ;; Concrete: lazy-seq
   <lazy-seq>
   <lazy-seq>?
   lazy-seq-thunk
   lazy-seq-realized-p
   lazy-seq-cached
   realize-lazy-seq
   ;; Metadata
   collection-metadata))

(defpackage fol.compiler.string-functions
  (:use cl)
  (:shadow format reverse replace char)
  (:import-from cl-ppcre)
  (:export
   ;; String concatenation and manipulation
   str subs join split split-lines
   ;; Trimming (Clojure-style)
   trim triml trimr trim-newline
   ;; Case conversion (Clojure-style)
   upper-case lower-case capitalize
   ;; Search and replace (old-style)
   str-replace str-index-of str-last-index-of
   ;; Predicates (Clojure-style)
   starts-with? ends-with? includes? blank?
   ;; Comparison and formatting
   compare size format
   ;; Character functions (Clojure-style)
   char char-name-string char-escape-string
   ;; Escaping
   escape
   ;; Generic Clojure-style functions (with regex support)
   replace replace-first reverse index-of last-index-of
   ;; Parsing
   parse-boolean parse-uuid
   ;; Regular expressions (Clojure-style)
   re-pattern re-find re-seq re-matches re-matcher re-quote-replacement
   ;; Other
   str-reverse))

(defpackage fol.compiler.collection-functions
  (:use cl)
  (:shadow vector set list list* nth push pop replace union intersection subseq find)
  (:shadowing-import-from fol.compiler.collections
                          ;; Import high-level accessors that are defined in collections
                          first rest get assoc dissoc conj size empty? count update merge)
  (:import-from fol.compiler.collections
                ;; Constructor generic
                make
                ;; Class name symbols (needed for make dispatch)
                <vector> <dict> <ordered-dict> <array-dict> <set> <bag>
                <ordered-set> <sorted-set> <sorted-dict> <int-dict> <priority-dict>
                <int-set> <dense-int-set> <deque> <list> <lazy-seq> <array> <deque>
                <lazy-seq> <ordered-set> <sorted-set> <int-set> <dense-int-set>)
  (:import-from fol.compiler.string-functions
                index-of last-index-of)
  (:import-from fol.compiler.destructure
                fol-type-to-cl-type)
  (:export
   vector vec vector-of
   dict
   ordered-dict
   array-dict
   set
   ordered-set
   sorted-set
   sorted-set-by
   sorted-dict
   sorted-dict-by
   int-dict
   int-dict-by
   priority-dict
   int-set
   dense-int-set
   bag
   deque
   list
   lazy-seq
   ;; High-level accessors
   first rest get assoc dissoc conj size empty? count update merge
   empty not-empty bounded-size
   ;; Array indexing
   %index
   ;; Collection predicates
   distinct? every? not-every? not-any?
   ;; Collection transfer
   into
   ;; List/vector operations
   list* nth peek push pop
   ;; Nested associative operations
   assoc-in update-in
   ;; Vector-specific
   subvec replace rseq reduce-kv
   ;; Search (re-exported from string-functions)
   index-of last-index-of
   ;; Set operations
   contains? disj union difference intersection select
   subset? superset? subseq rsubseq
   ;; Dict operations
   find get-in vals
   merge-with select-keys rename-keys map-invert
   update-keys update-vals key val
   ;; Deque operations
   rpeek rpop rpush rconj))

(defpackage fol.compiler.seq-functions
  (:use cl)
  (:shadow map reduce remove some every count)
  (:import-from fol.compiler.collections
                collection-seq collection-conj make
                <vector> <collection> <dict> <ordered-dict> <sorted-dict> <priority-dict>
                storage-items ordered-dict-key-order)
  (:shadowing-import-from fol.compiler.collection-functions
                get into)
  (:import-from fol.compiler.primitives truthy?)
  (:export
   ;; Core higher-order functions
   map mapv filter filterv reduce pmap
   ;; Concatenation and mapping variants
   mapcat pmapcat concat into
   ;; Filtering variants
   remove keep
   ;; Predicates
   some every
   ;; Partitioning and slicing
   partition take drop take-while drop-while
   ;; Dict operations
   keys
   ;; Sorting
   sort-by))

(defpackage fol.compiler.arithmetic-functions
  (:use cl)
  (:shadow + - * / abs exp sqrt min max gcd lcm
           sin cos tan asin acos atan sinh cosh tanh asinh acosh atanh
           expt rationalize numerator denominator)
  (:import-from fol.compiler.primitives <number> <integer> <float> <ratio> <bool> fol-value)
  (:export
   ;; Dyadic primitives
   %+ %- %* %/
   ;; Variadic operators
   + - * /
   ;; Increment/Decrement
   inc dec
   ;; Math functions
   abs sin cos tan asin acos atan atan2
   sinh cosh tanh asinh acosh atanh
   exp ln sqrt expt
   ;; Rational/complex
   rationalize numerator denominator
   real-part imag-part angle
   ;; GCD/LCM
   gcd lcm
   ;; Predicates
   odd? even? zero? positive? negative?
   integral? nat-int? pos-int? neg-int? NaN? infinite? Inf? -Inf?
   ;; Type conversion
   <complex> <single-float> <double-float>
   ;; Random
   rand make-seeded-random-state call-with-seed
   ;; Parsing
   parse-int parse-long parse-double
   ;; Conversion
   int))

(defpackage fol.compiler.bitwise-operation-functions
  (:use cl)
  (:shadow logand logior logxor lognot ash logbitp logcount
           bit-nand bit-nor bit-andc1 bit-andc2 bit-orc1 bit-orc2)
  (:import-from fol.compiler.primitives <integer> fol-value)
  (:export
   ;; Unary
   bitnot
   ;; Binary/variadic
   bitand bitor bitxor
   ;; Derived
   bit-nand bit-nor bit-andc1 bit-andc2 bit-orc1 bit-orc2
   ;; Bit manipulation
   bit-test bit-set bit-clear bit-flip bit-count
   ;; Shifting/rotation
   bit-shift bit-rotate))

(defpackage fol.compiler.logical-operation-functions
  (:use cl)
  (:shadow and or not)
  (:import-from fol.compiler.primitives <bool> <integer> fol-value)
  (:export
   ;; Dyadic primitives
   %and %or %xor
   ;; Unary
   not
   ;; Variadic
   and or xor
   ;; Derived
   implies nand nor))

(defpackage fol.compiler.functional
  (:use cl)
  (:shadow identity constantly complement apply)
  (:export
   ;; Core functions
   identity constantly comp complement partial juxt
   ;; Memoization and caching
   memoize fnil
   ;; Predicate combinators
   every-pred some-fn
   ;; Application
   apply trampoline))

(defpackage fol.compiler.metadata
  (:use cl)
  (:shadow test)
  (:import-from fol.compiler.persistent
                <persistent-object> %persistent-metadata)
  (:import-from fol.compiler.collections
                <collection> collection-metadata)
  (:export
   meta with-meta vary-meta
   alter-meta! reset-meta!
   doc find-doc test))

(defpackage fol.compiler.cl-utils
  (:use cl)
  (:export
   ;; CL data structure constructors for quoted forms
   make-cl-vector
   make-cl-dict
   make-cl-set))

(defpackage fol.compiler
  (:use cl)
  (:shadow macroexpand-1 macroexpand macroexpand-all)
  ; (:import-from fol.reader fol-read fol-read-from-string *fol-readtable*)
  ; (:import-from fol.wrappers wrap unwrap fol-value truthy?)
  ; (:import-from fol.classes val)
  ; (:import-from fol.collection
  ;               <vector> <dict> <set> <list>
  ;               size get seq)
  (:import-from fol.compiler.ast
                ast-node ast-node-p
                make-literal-node make-symbol-ref-node make-call-node
                make-if-node make-do-node make-bind-node)
  (:import-from fol.compiler.primitives
                truthy? falsy?)
  (:export
   ;; Main entry points
   compile-form
   compile-file
   compile-string
   ;; Compilation result
   compilation-result
   compilation-result-p
   compilation-result-code
   compilation-result-warnings
   compilation-result-errors
   ;; Macro system
   register-macro
   unregister-macro
   macro-p
   macroexpand-1
   macroexpand
   macroexpand-all))

(defpackage fol.macros
  (:use cl)
  (:shadow when case cond assert time do dotimes)
  (:import-from fol.compiler register-macro)
  (:export
   ;; Conditional macros
   when when-not if-not cond case condp
   ;; Binding macros
   when-let if-let when-some if-some when-first
   ;; Loop macros
   while dotimes doseq for
   ;; Threading macros
   -> ->> as-> cond-> cond->> some-> some->>
   ;; Dynamic binding
   binding with-redefs with-redefs-fn
   ;; Resource management
   with-open with-in-str with-out-str with-precision with-local-vars
   ;; Utilities
   time comment assert doc lazy-cat delay))

(defpackage fol.compiler.reader
  (:use cl)
  (:export
   ;; Readtable
   *fol-readtable*
   ;; Reader entry points
   fol-read
   fol-read-from-string))

(defpackage fol.compiler.streams
  (:use cl)
  (:export
   ;; Base classes
   <input-stream> <input-stream>?
   <output-stream> <output-stream>?
   ;; Mixin bases
   <string-base> <file-base> <socket-base>
   ;; Concrete classes
   <string-input-stream> <string-input-stream>?
   <string-output-stream> <string-output-stream>?
   <file-input-stream> <file-input-stream>?
   <file-output-stream> <file-output-stream>?
   <socket-input-stream> <socket-input-stream>?
   <socket-output-stream> <socket-output-stream>?
   ;; Constructors
   string-input-stream string-output-stream
   file-input-stream file-output-stream
   socket-input-stream socket-output-stream
   ;; Protocol
   stream-read-char stream-read-line
   stream-write-char stream-write-string stream-write-line
   stream-close stream-flush
   get-output-string
   ;; Global vars
   *in* *out*))

(defpackage fol.walk
  (:use cl)
  (:import-from fol.compiler.collections
                <collection> <vector> <dict> <set> <list>
                collection-seq storage-items make)
  (:export
   walk prewalk postwalk
   prewalk-demo prewalk-replace
   postwalk-demo postwalk-replace))

(defpackage fol.compiler.tests
  (:use cl fiveam)
  (:import-from fol.compiler.ast
                ast-node literal-node symbol-ref-node
                call-node if-node do-node bind-node binding-node
                fn-node def-node defdynamic-node defn-node
                literal-node-value)
  (:import-from fol.compiler
                compile-form compile-string)
  (:export run-compiler-tests))
