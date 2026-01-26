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
  ;; Import non-conflicting symbols from fol.compareop
  (:import-from :fol.compareop
                :%= :%/= :%< :%> :%<= :%>=)
  ;; Import non-conflicting symbols from fol.classes
  (:import-from :fol.classes
                :<bool> :<char> :<string> :<symbol> :<keyword>
                :<number> :<complex> :<real> :<float> :<single-float> :<double-float>
                :<rational> :<ratio> :<integer> :<fixnum> :<bignum>
                :val)
  ;; Import non-conflicting symbols from fol.logop
  (:import-from :fol.logop
                :xor
                :%and :%or :%xor
                :implies :nand :nor)
  ;; Import non-conflicting symbols from fol.bool
  (:import-from :fol.bool :<bool>?)
  ;; Shadow CL char functions
  (:shadowing-import-from :fol.char
                          :char-upcase :char-downcase)
  ;; Import non-conflicting symbols from fol.char
  (:import-from :fol.char
                :<char>?
                :alpha-char? :digit-char? :alphanumeric?
                :upper-case? :lower-case? :whitespace?)
  ;; Import non-conflicting symbols from fol.string
  (:import-from :fol.string :<string>?)
  ;; Import non-conflicting symbols from fol.symbol
  (:import-from :fol.symbol
                :<symbol>? :<keyword>?
                :symbol-name-str :symbol-package-str
                :get-symbol-value :set-symbol-value :symbol-bound?
                :as
                :+keyword-module+ :+default-module+ :*current-module*
                :fol-intern :parse-qualified-name)
  ;; Import non-conflicting symbols from fol.number
  (:import-from :fol.number
                :<number>? :<complex>?
                :<real>? :<float>? :<single-float>? :<double-float>?
                :<rational>? :<ratio>? :<integer>? :<fixnum>? :<bignum>?
                :odd? :even? :zero? :positive? :negative? :integral?)
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
                :<vector> :<list> :<dict> :<set> :<bag> :<array> :<lazy-seq>
                ;; Type predicates
                :<collection>? :<ordered-collection>? :<unordered-collection>?
                :<dict>? :<set>? :<bag>? :<vector>? :<array>? :<list>?
                :<lazy-seq>? :make-lazy-seq :realize-lazy-seq :lazy-seq-realized-p
                :make-dict :make-set :make-bag :make-vector
                :add :conj :contains? :size :empty? :seq
                :iterator :current :next :done?
                :nth-element :set-nth
                :list-first :list-rest :list-size
                ;; Reduced (for early termination in reduce)
                :<reduced> :<reduced>? :reduced :unreduced :reduced-value)
  ;; Shadow CL symbols that FOL redefines
  (:shadowing-import-from :fol.collection :remove :get :make-array :make-list :first :rest :second :third :nth)
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
                :str)
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
