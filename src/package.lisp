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
   fol-value

   ;; Type predicates
   <bool>? <char>? <string>? <re-pattern>? <symbol>? <keyword>?
   <number>? <complex>? <real>? <float>? <single-float>? <double-float>?
   <rational>? <ratio>? <integer>? <fixnum>? <bignum>?
   <uuid>?
   ;; Constructor generic
   make
   ;;
   truthy? falsy?
   true false))

(defpackage fol.compiler.primitive-functions
  (:use cl)
  (:shadow symbol keyword gensym)
  (:export
   ;; Nil and Boolean predicates
   nil? some? <bool>? true? false? instance?
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
   min max
   ;; Universal comparator
   %universal-comparator))

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
   defmethod-node defmethod-node-p defmethod-node-name defmethod-node-qualifier defmethod-node-clauses
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
   in-package-node in-package-node-p in-package-node-name in-package-node-options in-package-node-body make-in-package-node
   swap-node swap-node-p swap-node-atom-expr swap-node-fn-expr swap-node-args make-swap-node
   ;; Functional special forms
   defn-private-node defn-private-node-p defn-private-node-name defn-private-node-clauses make-defn-private-node
   definline-node definline-node-p definline-node-name definline-node-clauses make-definline-node
   as-thread-node as-thread-node-p as-thread-node-expr as-thread-node-name as-thread-node-forms make-as-thread-node
   some-thread-first-node some-thread-first-node-p some-thread-first-node-forms make-some-thread-first-node
   some-thread-last-node some-thread-last-node-p some-thread-last-node-forms make-some-thread-last-node
   ;; Local function definitions
   letfn-node letfn-node-p letfn-node-bindings letfn-node-body make-letfn-node
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
   convert-macro-param
   ;; Hooks
   *emit-predicate-hook*))

(defpackage fol.compiler.mutable
  (:use cl)
  (:shadow atom)
  (:export
   ;; Atom class
   <atom>
   <atom>?
   atom
   atom-validator atom-watches
   ;; Atom operations
   deref
   reset!
   swap!
   compare-and-set!
   ;; Ref (STM)
   <ref>
   <ref>?
   ref
   ref-validator ref-watches
   ;; Ref operations
   ref-set
   alter
   commute
   ensure
   dosync
   ;; Agent (async)
   <agent>
   <agent>?
   agent
   agent-validator agent-watches
   ;; Agent operations
   send
   send-off
   await
   agent-error
   restart-agent
   set-error-handler!
   set-error-mode!
   ;; Thread
   <thread>
   run
   start
   suspend
   resume
   halt
   thread-join
   ;; Thread Pool
   submit-work
   wait-for-work))

(defpackage fol.compiler.persistent
  (:use cl)
  (:export
   ;; Metaclass
   persistent-class
   ;; Base class
   <persistent-object> %persistent-storage
   ;; Metadata
   %persistent-metadata
   ;; Functional update API
   update-slot
   update-slots))

(defpackage fol.compiler.collection-primitives
  (:use cl)
  (:shadow assoc)
  (:export
   ;; Type constructors and predicates
   %vec-f64 %vec-f64? %make-vec-f64
   %vec-f32 %vec-f32? %make-vec-f32
   %vec-t %vec-t? %make-vec-t
   %vec-fix64 %vec-fix64? %make-vec-fix64
   ;; Constants
   +branch-factor+ +bit-mask+ +bit-shift+
   ;; Generic operations
   assoc conj count size ref empty?
   ;; Utility
   %clone-node %column-major-idx
   ;; Storage mixins
   <vec-t-storage-mixin>
   <vec-f64-storage-mixin>
   <vec-f32-storage-mixin>
   <vec-fix64-storage-mixin>
   <collection-storage>
   ;; Dict/sorted-dict mixins
   <dict-mixin> <sorted-dict-mixin>
   kv-conj
   ;; Empty instances
   %empty-vec-f64 %empty-vec-f32 %empty-vec-t %empty-vec-fix64))

(defpackage fol.compiler.collections
  (:use cl)
  (:shadow vector set list count array-dimension first rest get dissoc conj size merge)
  (:import-from fol.compiler.primitives make)
  (:import-from fol.compiler.persistent persistent-class)
  (:import-from fol.compiler.collection-primitives
                <vec-t-storage-mixin> <vec-f64-storage-mixin> <vec-f32-storage-mixin>
                <vec-fix64-storage-mixin> <collection-storage>
                <dict-mixin> <sorted-dict-mixin> kv-conj)
  (:shadowing-import-from fol.compiler.compareops < > %= %/=)
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
   first rest get dissoc conj size update merge
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
  (:import-from uuid make-uuid-from-string)
  (:export
   ;; String concatenation and manipulation
   str size subs split split-lines
   ;; Trimming (Clojure-style)
   trim triml trimr trim-newline
   ;; Case conversion (Clojure-style)
   upper-case lower-case capitalize
   ;; Search and replace (old-style)
   str-replace str-index-of str-last-index-of
   ;; Predicates (Clojure-style)
   starts-with? ends-with? includes? blank?
   ;; Comparison and formatting
   compare format
   ;; Character functions (Clojure-style)
   char char-name-string char-escape-string
   ;; Escaping
   escape
   ;; Generic Clojure-style functions (with regex support)
   replace-first reverse index-of last-index-of
   ;; Parsing
   parse-boolean parse-uuid
   ;; Regular expressions (Clojure-style)
   re-pattern re-find re-seq re-matches re-matcher re-quote-replacement
   ;; Other
   str-reverse))

(defpackage fol.compiler.merged-functions
  (:use cl)
  (:shadow replace map remove)
  (:export
   ;; Polymorphic functions
   join replace
   ;; Higher-order collection functions
   map mapcat filter remove keep
   take drop take-while drop-while
   ;; Indexed and deduplication
   map-indexed keep-indexed distinct dedupe
   ;; Partitioning, interpose, take-nth
   take-nth interpose partition-by partition-all
   ;; Reduced (transducer infrastructure)
   reduced reduced? unreduced ensure-reduced))

(defpackage fol.compiler.collection-functions
  (:use cl)
  (:shadow vector set list list* nth push pop union intersection difference subseq find assoc)
  (:shadowing-import-from fol.compiler.compareops %= %/=)
  (:shadowing-import-from fol.compiler.collections
                          ;; Import high-level accessors that are defined in collections
                          first rest get dissoc conj size empty? count update merge)
  (:import-from fol.compiler.collections
                ;; Constructor generic
                make
                ;; Base class (needed for method specializers)
                <collection>
                ;; Class name symbols (needed for make dispatch)
                <vector> <dict> <ordered-dict> <array-dict> <set> <bag>
                <ordered-set> <sorted-set> <sorted-dict> <int-dict> <priority-dict>
                <int-set> <dense-int-set> <deque> <list> <lazy-seq> <array>)
  (:import-from fol.compiler.string-functions
                index-of last-index-of)
  (:shadowing-import-from fol.compiler.merged-functions
                          replace)
  (:import-from fol.compiler.persistent
                <persistent-object> %persistent-storage update-slot)
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
   subvec rseq reduce-kv
   ;; Merged functions
   replace
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
  (:shadow reduce some every count sequence sort reverse cons butlast third second last)
  (:shadowing-import-from fol.compiler.merged-functions
                          map remove)
  (:import-from fol.compiler.merged-functions
                mapcat filter keep take drop take-while drop-while
                map-indexed keep-indexed distinct dedupe
                take-nth interpose partition-by partition-all
                reduced reduced? unreduced ensure-reduced)
  (:import-from fol.compiler.collections
                collection-seq collection-conj make
                <vector> <list> <lazy-seq> <collection>
                <dict> <ordered-dict> <sorted-dict> <priority-dict>
                storage-items ordered-dict-key-order
                list-first list-rest realize-lazy-seq lazy-seq-realized-p)
  (:shadowing-import-from fol.compiler.collection-functions
                          get)
  (:import-from fol.compiler.primitives truthy?)
  (:import-from fol.compiler.mutable
                agent send send-off <agent>)
  (:export
   ;; Core higher-order functions
   map mapv filter filterv reduce pmap
   ;; Mapping with index
   map-indexed
   ;; Concatenation and mapping variants
   mapcat pmapcat concat into
   ;; Filtering variants
   remove keep keep-indexed
   ;; Predicates
   some every
   ;; Partitioning and slicing
   partition partition-all partition-by
   take drop take-while drop-while take-last take-nth
   split-at split-with
   butlast drop-last
   ;; Building / prepending
   cons
   ;; Reordering
   sort sort-by reverse shuffle
   ;; Dict operations
   keys
   ;; Grouping and statistics
   group-by
   ;; Deduplication
   distinct dedupe
   ;; Flattening
   flatten
   ;; Traversal helpers
   next fnext nnext nthrest third second last ffirst nfirst nthnext
   ;; Collection utilities
   realized? dorun doall run! rand-nth
   ;; Key-based min/max
   max-key min-key
   ;; Zip and reductions
   zipmap reductions
   ;; Infinite generators
   cycle interleave interpose
   ;; Random
   random-sample
   ;; Buffered seq (simplified)
   seque
   ;; Sequence coercions
   seq sequence
   ;; Generative sequences
 repeat range repeatedly iterate iteration
   ;; I/O and tree sequences
   file-seq line-seq tree-seq iterator-seq enumeration-seq
   ;; Transducer infrastructure (shared with transducers)
   reduced reduced? unreduced ensure-reduced
   completing transduce))

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
  (:import-from fol.compiler.primitives <bool> <integer>)
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

(defpackage fol.compiler.reader
  (:use cl)
  (:export
   ;; Readtable
   *fol-readtable*
   ;; Reader entry points
   fol-read
   fol-read-from-string))

(defpackage fol.compiler
  (:use cl)
  (:shadow macroexpand-1 macroexpand macroexpand-all compile-file)
  (:import-from fol.compiler.reader
                fol-read fol-read-from-string *fol-readtable*)
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
   macroexpand-all
   ;; Special forms
   fn
   defn
   defmacro
   defclass
   defgeneric
   defmethod
   loop
   recur
   binding
   swap!
   def
   defdynamic
   definline
   letfn
   quote
   if
 do
   bind
   cond
   case))

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
   *in* *out* *err*))

(defpackage fol.macros
  (:use cl)
  (:shadow when assert time do dotimes)
  (:shadowing-import-from fol.compiler.collection-functions vector list first rest)
  (:import-from fol.compiler register-macro)
  (:import-from fol.compiler.streams
                stream-close *in* *out*)
  (:import-from fol.compiler.primitives truthy? true false)
  (:import-from fol.compiler.arithmetic-functions inc)
  (:import-from fol.compiler.collection-functions conj vec)
  (:import-from fol.compiler.seq-functions seq)
  (:export
   ;; Conditional macros
   when when-not if-not condp
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


(defpackage fol.compiler.io
  (:use cl)
  (:shadow read read-line print format close delete-file pprint)
  (:import-from fol.macros with-open with-in-str with-out-str)
  (:export
   ;; Core IO
   spit slurp
   ;; Printing
   pr prn print format printf println newline print-table
   pprint cl-format
   ;; String IO
   pr-str prn-str print-str println-str
   ;; Reading
   read-line read line-seq
   ;; Resource management
   flush close
   ;; File system
   file copy delete-file resource
   as-file as-url as-relative-path
   ;; Tap system
   tap> add-tap remove-tap
   ;; Macros (re-exported from fol.macros)
   with-open with-in-str with-out-str))


(defpackage fol.compiler.relational
  (:use cl)
  (:import-from fol.compiler.collections
                <set> <collection> <dict> <ordered-dict> <sorted-dict>
                collection-seq collection-conj make)
  (:shadowing-import-from fol.compiler.collection-functions
                          get assoc dissoc empty? conj empty vec size
                          select-keys rename-keys vals merge contains? first disj
                          union intersection difference)
  (:shadowing-import-from fol.compiler.seq-functions
                          reduce filter map keys sort into)
  (:export
   project index rename diff))

(defpackage fol.compiler.transducers
  (:use cl)
  (:shadow replace)
  ;; Re-export unified functions from seq-functions (same symbol objects)
  (:shadowing-import-from fol.compiler.seq-functions
                          map mapcat filter remove sequence
                          reduce)
  (:import-from fol.compiler.seq-functions
                take take-while take-nth drop drop-while
                partition-by partition-all keep keep-indexed map-indexed distinct
                interpose dedupe random-sample
              into
                reduced reduced? ensure-reduced unreduced completing transduce)
  (:import-from fol.compiler.primitives truthy?)
  (:export
   ;; Unified functions (re-exported from seq-functions)
   map mapcat filter remove take take-while take-nth drop drop-while
   partition-by partition-all keep keep-indexed map-indexed distinct
   interpose dedupe random-sample
 into sequence
   reduced reduced? ensure-reduced unreduced completing transduce
   ;; Transducer-only functions
   replace cat halt-when eduction))

(defpackage fol.compiler.misc-functions
  (:use cl)
  (:shadow intern)
  (:export
   ;; Definition once
   defonce
   ;; Symbol interning
   intern))

(defpackage fol.compiler.mutable-functions
  (:use cl)
  (:shadowing-import-from fol.compiler.mutable atom)
  (:import-from fol.compiler.mutable
                <atom> deref reset! swap! compare-and-set!
                atom-validator atom-watches
                <ref> ref ref-set alter commute ensure dosync
                ref-validator ref-watches
                <agent> agent send send-off await agent-error restart-agent
                set-error-handler! set-error-mode!
                agent-validator agent-watches)
  (:export
   ;; Re-export primitives
   atom deref reset! swap! compare-and-set!
   ref ref-set alter commute ensure dosync
   agent send send-off await agent-error restart-agent
   set-error-handler! set-error-mode!
   ;; Atom extensions
   swap-vals! reset-vals!
   ;; Futures
   future future-call future-done? future-cancel future-cancelled? future?
   ;; Promises
   promise deliver
   ;; Parallel processing
   pcalls pvalues pmap seque
   ;; Thread bindings
   bound-fn bound-fn* get-thread-bindings push-thread-bindings pop-thread-bindings thread-bound?
   ;; STM
   sync io!
   ;; Validators & Watchers
   set-validator! get-validator add-watch remove-watch
   ;; Ref History (stubs)
   ref-history-count ref-min-history ref-max-history
   ;; Agent Extensions
   send-via set-agent-send-executor! set-agent-send-off-executor!
   await-for shutdown-agents error-handler error-mode *agent* release-pending-sends))

(defpackage fol.lib.reducers
  (:use cl)
  (:shadow reduce)
  (:shadowing-import-from fol.compiler.collections
                          count size)
  (:import-from fol.compiler.mutable
                submit-work wait-for-work)
  (:import-from fol.compiler.collections
                collection-seq)
  (:export preduce fold))

(defpackage fol.repl
  (:use cl)
  (:import-from fol.compiler
                compile-string)
  (:shadowing-import-from fol.compiler
                          compile-file)
  (:import-from fol.compiler.reader
                fol-read-from-string
                *fol-readtable*)
  (:import-from fol.compiler.streams
                *in* *out*)
  (:export
   repl
   compile-fol-string
   compile-fol-file
   run-fol-string
   run-fol-file))


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

;;; ---------------------------------------------------------------------------
;;; FOL Core Package
;;;
;;; Unified namespace for FOL programming.  Uses CL and all FOL packages
;;; (except fol.compiler.ast and fol.compiler.tests).  All inter-package
;;; and CL symbol conflicts are resolved via shadowing imports.
;;; Symbols are re-exported programmatically in fol-core.lisp.
;;; ---------------------------------------------------------------------------

(defpackage fol.core

  ;; ---- Type predicates (prefer primitive-functions over both primitives
  ;;       and collections, which export overlapping predicate names) --------
  (:shadowing-import-from fol.compiler.primitive-functions
                          ;; NOTE: <re-pattern>? and <uuid>? are only in primitives (no conflict)
                          ;; Primitive type predicates (conflict with primitives)
                          <bool>? <char>? <string>? <symbol>? <keyword>?
                          <number>? <complex>? <real>? <float>? <single-float>? <double-float>?
                          <rational>? <ratio>? <integer>? <fixnum>? <bignum>?
                          ;; Collection type predicates (conflict with collections)
                          <collection>? <unordered-collection>? <ordered-collection>?
                          <dict>? <ordered-dict>? <array-dict>? <sorted-dict>? <int-dict>? <priority-dict>?
                          <set>? <ordered-set>? <sorted-set>? <int-set>? <dense-int-set>?
                          <vector>? <list>? <lazy-seq>? <deque>? <bag>?
                          ;; Symbol constructors (shadow cl:symbol cl:keyword cl:gensym)
                          symbol keyword gensym)

  ;; ---- Arithmetic & type conversions (shadow CL math) ---------------------
  (:shadowing-import-from fol.compiler.arithmetic-functions
                          ;; Type conversions (prefer over primitives)
                          <complex> <single-float> <double-float>
                          ;; Arithmetic operators
                          + - * /
                          ;; Math functions
                          abs sin cos tan asin acos atan
                          sinh cosh tanh asinh acosh atanh
                          exp sqrt expt inc dec
                          ;; Rational/complex
                          rationalize numerator denominator
                          ;; GCD/LCM
                          gcd lcm
                          ;; Predicates
                          odd? even? zero? positive? negative?)

  ;; ---- Primitive type constants & predicates -------------------------------
  (:import-from fol.compiler.primitives
                true false)
  (:import-from fol.compiler.primitive-functions
                instance? nil? some?)

  ;; ---- Comparison operators (shadow CL) -----------------------------------
  (:shadowing-import-from fol.compiler.compareops
                          < > <= >= = /= min max)

  ;; ---- Collection class symbols (shadow cl:array-dimension) ----------------
  (:shadowing-import-from fol.compiler.collections
                          array-dimension)

  ;; ---- Collection core ops (shadow CL; prefer over string-functions,
  ;;       transducers) ------------------------------------------------------
  (:shadowing-import-from fol.compiler.collection-functions
                          vector set list list* nth push pop
                          dict bag deque ordered-dict ordered-set sorted-set sorted-dict
                          int-set int-dict priority-dict dense-int-set
                          first rest get assoc count merge
                          find subseq
                          union intersection
                          size)

  ;; ---- Merged functions (shadow CL) ---------------------------------------
  (:shadowing-import-from fol.compiler.merged-functions
                          replace)

  ;; ---- Sequence ops (shadow CL; prefer over transducers,
  ;;       mutable-functions, io) --------------------------------------------
  (:shadowing-import-from fol.compiler.seq-functions
                          map reduce remove some every
                          sort cons butlast third second last
                          reverse sequence
                          filter mapcat
                          take take-while take-nth drop drop-while
                          partition-by partition-all
                          keep keep-indexed map-indexed
                          distinct interpose dedupe random-sample
                        into
                          pmap seque)

  ;; ---- Logic operators (shadow cl:not cl:and cl:or) -----------------------
  (:shadowing-import-from fol.compiler.logical-operation-functions
                          not and or)

  ;; ---- Function combinators (shadow CL) -----------------------------------
  (:shadowing-import-from fol.compiler.functional
                          identity constantly complement apply)

  ;; ---- Mutable operations (shadow cl:atom; prefer over fol.compiler) ------
  (:shadowing-import-from fol.compiler.mutable-functions
                          atom swap!)

  ;; ---- IO operations (shadow CL; prefer over string-functions for format) -
  (:shadowing-import-from fol.compiler.io
                          print pprint
                          read-line read line-seq
                          close delete-file)

  ;; ---- String functions (shadow cl:char; prefer over relational for join) -
  (:shadowing-import-from fol.compiler.string-functions
                          char format)

  ;; ---- Compiler special forms (shadow CL special operators) ---------------
  (:shadowing-import-from fol.compiler
                          compile-file macroexpand-1 macroexpand
                          defmacro defclass defgeneric defmethod
                          loop quote if do
                          cond case)

  ;; ---- User-facing macros (shadow CL; prefer over compiler for
  ;;       cond/case/binding, over metadata for doc) -------------------------
  (:shadowing-import-from fol.macros
                          when dotimes time assert
                          binding doc)

  ;; ---- Bitwise operations (shadow CL bit-array functions) -----------------
  (:shadowing-import-from fol.compiler.bitwise-operation-functions
                          bit-nand bit-nor bit-andc1 bit-andc2 bit-orc1 bit-orc2)

  ;; ---- Misc (shadow cl:intern) --------------------------------------------
  (:shadowing-import-from fol.compiler.misc-functions
                          intern)

  ;; ---- Use all FOL packages (conflicts resolved above) --------------------
  (:use cl
        fol.compiler.primitives
        fol.compiler.primitive-functions
        fol.compiler.compareops
        fol.compiler.destructure
        fol.compiler.mutable
        fol.compiler.persistent
        fol.compiler.collections
        fol.compiler.string-functions
        fol.compiler.collection-functions
        fol.compiler.seq-functions
        fol.compiler.arithmetic-functions
        fol.compiler.bitwise-operation-functions
        fol.compiler.logical-operation-functions
        fol.compiler.functional
        fol.compiler.metadata
        fol.compiler.cl-utils
        fol.compiler.reader
        fol.compiler
        fol.macros
        fol.compiler.streams
        fol.compiler.io
        fol.compiler.relational
        fol.compiler.transducers
        fol.compiler.merged-functions
        fol.compiler.misc-functions
        fol.compiler.mutable-functions
        fol.repl))
