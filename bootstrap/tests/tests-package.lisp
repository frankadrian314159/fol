(in-package :cl-user)

;; Delete package to ensure a clean slate and avoid variance warnings
(eval-when (:compile-toplevel :load-toplevel :execute)
  (when (find-package :fol.tests)
    (delete-package :fol.tests)))

(defpackage :fol.tests
  (:use :cl :fiveam)
  (:export :run-fol-tests)
  ;; Shadow CL symbols that FOL redefines
  (:shadowing-import-from :fol.arithop
                          :+ :- :* :/
                          :abs :sin :cos :tan :asin :acos :atan
                          :sinh :cosh :tanh :asinh :acosh :atanh
                          :exp :ln :expt :sqrt
                          :rationalize :numerator :denominator
                          :gcd :lcm)
  (:shadowing-import-from :fol.compareop
                          := :/= :< :> :<= :>=
                          :min :max)
  (:shadowing-import-from :fol.logop
                          :and :or :not)
  ;; Import non-conflicting symbols from fol.arithop
  (:import-from :fol.arithop
                :%+ :%- :%* :%/
                :atan2
                :real-part :imag-part :angle
                :%gcd :%lcm)
  ;; Shadow CL symbols that FOL bitop redefines
  (:shadowing-import-from :fol.bitop
                          :bit-nand :bit-nor :bit-andc1 :bit-andc2 :bit-orc1 :bit-orc2)
  ;; Import non-conflicting symbols from fol.bitop
  (:import-from :fol.bitop
                :bitnot :bitand :bitor :bitxor
                :bit-test :bit-set :bit-clear :bit-count
                :bit-shift :bit-rotate)
  ;; Import non-conflicting symbols from fol.compareop
  (:import-from :fol.compareop
                :%= :%/= :%< :%> :%<= :%>=)
  ;; Import non-conflicting symbols from fol.classes
  (:import-from :fol.classes
                :<bool> :<char> :<string> :<symbol> :<keyword>
                :<number> :<complex> :<real> :<float> :<single-float> :<double-float>
                :<rational> :<ratio> :<integer> :<fixnum> :<bignum>
                :<re-pattern> :<re-scanner>
                :scanner-function :scanner-register-names
                :<uuid>
                :val)
  ;; Import non-conflicting symbols from fol.logop
  (:import-from :fol.logop
                :xor
                :%and :%or :%xor
                :implies :nand :nor)
  ;; Import non-conflicting symbols from fol.bool
  (:import-from :fol.bool :<bool>? :parse-bool)
  ;; Shadow CL char functions
  (:shadowing-import-from :fol.char
                          :char-upcase :char-downcase)
  ;; Import non-conflicting symbols from fol.char
  (:import-from :fol.char
                :<char>?
                :alpha-char? :digit-char? :alphanumeric?
                :upper-case? :lower-case? :whitespace?
                :char-name-string)
  ;; Shadow CL string functions
  (:shadowing-import-from :fol.string
                          :trim :capitalize :replace)
  ;; Import non-conflicting symbols from fol.string
  (:import-from :fol.string
                :<string>?
                :blank? :triml :trimr :trim-newline
                :starts-with? :ends-with? :includes?
                ;; Replace operations (replace is shadowed above)
                :replace-first
                ;; Join and split operations
                :join :escape :split :split-lines
                :<re-pattern>? :wrap-re-pattern
                :<re-scanner>? :make-re-scanner
                :re-find :re-seq
                :<uuid>? :parse-uuid)
  ;; Import non-conflicting symbols from fol.symbol
  (:shadowing-import-from :fol.symbol :keyword :symbol :gensym)
  (:import-from :fol.symbol
                :<symbol>? :<keyword>?
                :symbol-name-str :symbol-package-str
                :get-symbol-value :set-symbol-value :symbol-bound?
                :as :find-keyword
                :+keyword-module+ :+default-module+ :*current-module*
                :fol-intern :parse-qualified-name)
  ;; Import non-conflicting symbols from fol.number
  (:import-from :fol.number
                :<number>? :<complex>? :<complex>
                :<real>? :<float>? :<single-float>? :<single-float> :<double-float>? :<double-float>
                :<rational>? :<ratio>? :<integer>? :<fixnum>? :<bignum>?
                :odd? :even? :zero? :positive? :negative? :integral?
                :nat-int? :pos-int? :NaN? :infinite?
                :rand :make-seeded-random-state :call-with-seed
                :parse-int :parse-double :int)
  ;; Import non-conflicting symbols from fol.wrappers
  (:import-from :fol.wrappers
                :fol-value :fol-type-of
                :wrap :unwrap
                :wrap-bool :unwrap-bool
                :wrap-char :unwrap-char
                :wrap-string :unwrap-string
                :wrap-symbol :unwrap-symbol
                :wrap-number :unwrap-number
                :fol-numberp :fol-integerp :fol-realp
                :fol-stringp :fol-characterp :fol-symbolp :fol-booleanp)
  ;; Import symbols from fol.collection
  (:import-from :fol.collection
                ;; Type symbols (for type function tests)
                :<vector> :<deque> :<list> :<dict> :<set> :<bag> :<array> :<lazy-seq>
                :<sorted-set> :<ordered-set> :<int-set> :<dense-int-set>
                :<sorted-set-by> :<sorted-set-by>? :sorted-set-by
                ;; Dict subclass types
                :<array-dict> :<sorted-dict> :<ordered-dict> :<priority-dict> :<int-dict>
                ;; Type predicates
                :<collection>? :<ordered-collection>? :<unordered-collection>?
                :<dict>? :<set>? :<bag>? :<vector>? :<deque>? :<array>? :<list>?
                :<sorted-set>? :<ordered-set>? :<int-set>? :<dense-int-set>?
                ;; Dict subclass predicates
                :<array-dict>? :<sorted-dict>? :<ordered-dict>? :<priority-dict>? :<int-dict>?
                :<lazy-seq>? :make-lazy-seq :realize-lazy-seq :lazy-seq-realized-p
                :make-dict :make-set :make-bag :make-vector :make-deque
                :make-sorted-set :make-ordered-set :make-int-set :make-dense-int-set
                ;; Dict subclass constructors
                :make-array-dict :array-dict :array-dict-with-limit
                :make-sorted-dict :sorted-dict :sorted-dict-by
                :make-ordered-dict :ordered-dict
                :make-priority-dict :priority-dict
                :make-int-dict :int-dict
                :iterator :current :next :done?
                :nth-element :set-nth
                :list-first :list-rest :list-size
                ;; Index operations
                :index-of :last-index-of
                ;; Reduced (for early termination in reduce)
                :<reduced> :<reduced>? :reduced :unreduced :reduced-value
                ;; Sizing and into
                :sized? :bounded-size :into
                ;; Eager vector operations
                :vec :mapv :filterv
                ;; Associative operations
                :assoc-in :sub
                ;; Reversed sequence
                :rseq
                ;; Update operations
                :update :update-in
                ;; Key-value reduce
                :reduce-kv)
  ;; Import symbols from fol.seqop
  (:import-from :fol.seqop
                :add :conj :contains? :size :empty? :seq :disj
                ;; Deque operations
                :peek-front :pop-front :push-front :peek-end :pop-end :push-end
                :set-union :select :subset? :superset?
                :subs :rsubs
                ;; Dict query operations
                :get-in :keys :vals :key :val
                ;; Dict modification operations
                :dissoc :merge-with
                ;; Dict transformation operations
                :select-keys :rename-keys :map-invert :update-keys :update-vals
                ;; Dict construction operations
                :freqs :group-by :index
                ;; Zipper operations
                :<zipper> :<zipper>?
                :zipper :seq-zip :vector-zip
                :node :branch? :children :make-node
                :path :lefts :rights
                :up :down :left :right
                :leftmost :rightmost
                :zip-replace :edit
                :insert-child :append-child
                :insert-left :insert-right
                :zip-remove
                :zip-next :prev :root :end?)
  ;; Shadow CL symbols that FOL redefines (sequence operations now in fol.seqop)
  (:shadowing-import-from :fol.seqop :remove :get :first :rest :nth :pop :push :peek :reverse :assoc
                          :set-difference :set-intersection :find :merge)
  ;; Shadow CL symbols that FOL redefines (collection-specific, remain in fol.collection)
  (:shadowing-import-from :fol.collection :make-array :make-list :second :third :vector)
  ;; Import symbols from fol.env
  (:import-from :fol.env
                :<env>? :make-env :lookup :env-previous
                :fol-unbound-variable :fol-unbound-variable-name :fol-unbound-variable-message)
  ;; Import symbols from fol.module
  (:import-from :fol.module
                :<module>? :make-module)
  ;; Import symbols from fol.persistent
  (:import-from :fol.persistent
                :persistent-class :<persistent-object> :<persistent-object>?
                :pslot-value :set-pslot-value :set-pslot-values :with-pslots)
  ;; Import symbols from fol.fol-mop
  (:import-from :fol.fol-mop
                :make
                :defgeneric* :defclass* :defmethod*
                :eval-defgeneric* :eval-defclass* :eval-defmethod*
                :vector-to-list :convert-slot-specifier :convert-specialized-param)
  ;; Import symbols from fol.mop
  (:import-from :fol.mop
                :class-name* :class-direct-superclasses* :class-direct-subclasses*
                :class-precedence-list* :class-direct-slots* :class-slots*
                :finalized-p :ensure-finalized
                :slot-definition-name* :slot-definition-type* :slot-definition-initargs*
                :slot-definition-initform* :slot-definition-initfunction*
                :slot-definition-allocation* :slot-definition-readers* :slot-definition-writers*
                :instance-class :instance-slots :slot-names :slot-exists-p* :slot-boundp* :slot-value*
                :all-persistent-classes :subclasses* :superclasses* :find-slot-definition
                :slot-properties :class-info :describe-class :describe-slot
                :persistent-class-p :persistent-object-p
                ;; Constructor generation protocol
                :class-name-string :bare-class-name :constructor-name
                :class-initargs :required-initargs :optional-initargs
                :make-instance* :define-constructor :define-constructors
                :generate-constructor-form :list-constructible-classes :describe-constructor)
  ;; Import symbols from fol.reader
  (:import-from :fol.reader
                :*clojure-readtable*
                :<readtable>? :<character-class-table>?
                :make-readtable :make-character-class-table
                :fol-read :fol-read-from-string
                :fol-get-macro-character :fol-set-macro-character
                :fol-get-dispatch-macro-character :fol-set-dispatch-macro-character
                :with-readtable)
  ;; Import symbols from fol.eval
  (:shadowing-import-from :fol.eval :macroexpand-1 :macroexpand
                          :identity :complement :type)
  (:import-from :fol.eval
                :fol-eval
                :eval-quote :eval-if :eval-do :eval-bind :eval-fn :eval-def
                :eval-loop :eval-recur :eval-throw :eval-try :eval-defmacro
                :eval-syntax-quote :eval-make-dynamic :eval-binding
                :fol-eval-error :fol-eval-error-message :fol-eval-error-form
                :fol-arity-error :fol-arity-error-expected :fol-arity-error-got
                :fol-type-error :fol-type-error-expected :fol-type-error-actual :fol-type-error-variable
                :make-function :apply-function
                :make-macro :expand-macro
                :expand-syntax-quote :unquote-form-p :unquote-splicing-form-p
                :auto-gensym-symbol-p
                :<dynamic-var> :<dynamic-var>? :make-dynamic-var
                :dynamic-var-name :dynamic-var-value :dynamic-var-root-value
                :dynamic-var-push :dynamic-var-pop
                :make-standard-env
                :<function> :<function>?
                :<macro> :<macro>? :macro-name :macro-params :macro-body
                :macro-env :macro-rest-param
                ;; Multi-pattern macro
                :<multi-macro> :<multi-macro>? :make-multi-macro :expand-multi-macro
                ;; Higher-order function combinators
                :disjoin :conjoin :partial :rpartial :juxt
                ;; Higher-order collection operations
                :filter :keep :mapcat :interleave :interpose
                ;; Lazy sequence generators
                :range :iterate :repeat :repeatedly :cycle
                ;; Lazy sequence operations
                :take :drop
                ;; Reduced (for early termination)
                :reduced?
                ;; Increment/decrement
                :inc :dec
                ;; String operations
                :str
                ;; Standard environment symbols (for macro form construction)
                :cl-cons :cl-list)
  ;; Import symbols from fol.stream
  (:shadowing-import-from :fol.stream
                          :open :close
                          :make-string-input-stream :make-string-output-stream
                          :get-output-stream-string
                          :with-open-stream)
  (:import-from :fol.stream
                :<stream>? :<input-stream>? :<output-stream>?
                :<string-input-stream>? :<file-input-stream>?
                :<string-output-stream>? :<file-output-stream>?
                :make-file-input-stream :make-file-output-stream
                :stream-open? :stream-closed?
                :read-char* :write-char* :write-string* :read-line*))

(in-package :fol.tests)

(def-suite fol-suite
  :description "Main test suite for FOL.")

(defun run-fol-tests ()
  (run! 'fol-suite))
