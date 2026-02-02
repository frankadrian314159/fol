# FOL: A Functional Object Lisp 

**Frank Adrian**
*European Lisp Symposium 2026*

---

## Abstract

We present FOL (Functional Object Lisp), a new Lisp dialect that combines persistent functional data structures from Clojure with CLOS-style object-oriented programming and Dylan-inspired modules and naming conventions. FOL features a bootstrap implementation in Common Lisp, leveraging the FSet and Sycamore libraries for persistent collections. The language provides Clojure-compatible syntax and semantics for items like sequence operations and transducers while adding multiple destructuring pattern dispatch and maintaining full compatibility with CLOS's meta-object protocol. We demonstrate how FOL bridges concepts from multiple Lisp traditions and present a self-hosted meta-circular evaluator that showcases the language's metaprogramming capabilities.

**Keywords:** Functional programming, object-oriented programming, Lisp, persistent data structures, CLOS, MOP, transducers

---

## 1. Introduction

The Lisp family of languages has evolved along multiple paths, each emphasizing different aspects of the language's core philosophy. Common Lisp [1] provides a mature, standardized platform with powerful object-oriented features through CLOS [2] and metaprogramming through the MOP [3]. Clojure [4] introduced persistent data structures and functional programming idioms to the JVM ecosystem, emphasizing immutability and simplicity. Dylan [5] explored an object-oriented Lisp with a clear type system.

FOL (Functional Object Lisp) synthesizes ideas from these traditions to create a language that:

- Provides Clojure-style persistent data structures with structural sharing
- Maintains CLOS-style generic functions including multiple destructuring pattern dispatch
- Adopts Dylan's naming conventions (`<type>`) for clarity and its module structure which is simpler and more intuitive than Clojure's namespaces or Common Lisp's packages.
- Supports both functional and object-oriented programming paradigms

This paper describes FOL's design, implementation, and contributions to the Lisp ecosystem.

## 2. Language Design

### 2.1 Core Philosophy

FOL is built on the principle that persistent data structures and object-oriented programming are complementary, not antagonistic. While Clojure eschews traditional OOP in favor of protocols and multi-methods, FOL embraces CLOS's full power while maintaining Clojure's functional purity through persistence.

The language makes the following design commitments:

1. **Immutability by default**: All objects and collections are persistent
2. **Structural sharing**: Updates to objects and collections create new versions sharing structure with old
3. **Object identity**: Objects have identity separate from value equality
4. **Generic functions**: Multiple dispatch over destructuring patterns for polymorphism
5. **Meta-object protocol**: Full introspection and extension capabilities

### 2.2 Syntax and Readability

FOL adopts Clojure's reader syntax for consistency with functional programming conventions:

```clojure
;; Vectors
[1 2 3]

;; Maps (dictionaries)
{:name "Alice" :age 30}

;; Sets
#{1 2 3 4}

;; Function definition with pattern matching
(defn factorial
  ([(n (= 0))] 1)
  ([(n (= 1))] 1)
  ([n]
    (* n (factorial (dec n)))))

;; Destructuring with type constraints and :as
(defn summarize-person
  ([{:keys [name age] :as person}]
    (str name " is " age " years old")))

;; Rest parameters with &
(defn sum-and-product
  ([first & rest]
    {:sum (+ first (apply + rest))
     :product (* first (apply * rest))}))

;; Nested destructuring with :or for defaults
(defn process-config
  ([{:keys [server port]
     :or {port 8080}
     :as config}]
    (bind [{:keys [host timeout]
            :or {timeout 30}} server]
      {:host host
       :port port
       :timeout timeout})))

;; Vector destructuring
(defn point-distance
  ([[x1 y1] [x2 y2]]
    (sqrt (+ (expt (- x2 x1) 2)
             (expt (- y2 y1) 2)))))
```

These examples demonstrate FOL's rich destructuring capabilities, combining pattern matching with equality tests, default values, and nested destructuring. The use of angle brackets (`<>`) for type names, borrowed from Dylan, provides visual distinction between types and values.

### 2.3 Type System

FOL's type hierarchy begins with `<persistent-object>`, from which all types derive:

```
<persistent-object>
  ├─ <number>
  ├─ <string>
  ├─ <symbol>
  ├─ <collection>
  │   ├─ <vector>
  │   ├─ <list>
  │   ├─ <dict>
  │   └─ <set>
  └─ <user-defined-classes>
```

Primitive types wrap their Common Lisp equivalents in a `val` slot, accessed through the generic function `fol-val`. This allows primitives to participate in the persistent object protocol while maintaining compatibility with Common Lisp's numeric tower.

## 3. Architecture and Implementation

### 3.1 Bootstrap Implementation

FOL is implemented in Common Lisp, leveraging existing infrastructure:

- **FSet** [8]: Functional sets and maps with 2-3 finger trees
- **Sycamore**: Weight-balanced trees for sorted collections
- **CLOS/MOP**: Object system and metaprogramming
- **Closer-MOP**: Portable MOP interface

The implementation consists of approximately 6,000 lines of Common Lisp code organized into modules:

| Module          | LOC  | Purpose                          |
|-----------------|------|----------------------------------|
| persistent      | 250  | Base persistent object protocol  |
| classes         | 180  | Primitive type wrappers          |
| collection      | 890  | Persistent collections           |
| seqop           | 1420 | Sequence operations              |
| eval            | 1580 | Evaluator and special forms      |
| standard-names  | 1680 | Standard environment             |

### 3.2 Persistent Object Protocol

FOL extends CLOS with a persistent object protocol. All user-defined classes inherit from `<persistent-object>` and use `pslot-value` for slot access:

```clojure
(defclass* <person> (<persistent-object>)
  ((name :type <string>)
   (age :type <number>)))

(def alice (make <person> :name "Alice" :age 30))

;; Updates return new instances
(def older-alice
  (set-pslot-value alice 'age 31))

;; Original unchanged
(pslot-value alice 'age)  ; => 30
(pslot-value older-alice 'age)  ; => 31
```

The `defclass*` macro extends CLOS's `defclass` to create persistent classes. It ensures all instances inherit from `<persistent-object>` and automatically implements the persistent slot protocol. Like CLOS, it supports slot options including `:type`, `:initarg`, `:initform`, and `:reader`/`:writer` specifications.

Persistence is achieved through careful management of slot values and structural sharing. When a slot is updated, only the affected slots are copied; others are shared between instances.

### 3.3 Collection Implementation

FOL's collections are implemented as thin wrappers around FSet and Sycamore data structures:

```clojure
(defclass* <collection> (<persistent-object>)
  ((items :type fset:collection)))

(defclass* <vector> (<collection>) ())
(defclass* <dict> (<collection>) ())
(defclass* <set> (<collection>) ())
```

This design provides several benefits:
- Structural sharing inherent to FSet
- O(log n) updates for most operations
- Compatibility with Common Lisp sequence functions
- Extensibility through CLOS

## 4. Features

### 4.1 Transducers

FOL implements Clojure's transducer protocol [6], enabling composable algorithmic transformations:

```clojure
;; Compose transducers
(def xform
  (comp (filter even?)
        (map (fn [x] (* x x)))
        (take 5)))

;; Apply to different contexts
(transduce xform + 0 (range))  ; => 220
(into [] xform (range 20))     ; => [0 4 16 36 64]
```

Transducers separate the essence of transformation from the context of application. The same transducer works with reduction, sequence building, or channel processing.

### 4.2 Lazy Sequences

FOL provides lazy sequences that delay computation until needed:

```clojure
(defn fibonacci []
  (bind [fib-helper
         (fn [a b]
           (lazy-seq
             (cons a (fib-helper b (+ a b)))))]
    (fib-helper 0 1)))

;; Only computes as needed
(take 10 (fibonacci))
; => (0 1 1 2 3 5 8 13 21 34)
```

Lazy sequences enable infinite data structures and efficient pipeline processing. The implementation uses thunks that cache their results after first evaluation.

### 4.3 Generic Function Integration

FOL's generic functions fully integrate with persistent data. Methods dispatch on type predicates (e.g., `<vector>?`, `<dict>?`) which check both the specified type and all subtypes, providing flexible polymorphism:

```clojure
(defgeneric process [x])

(defmethod process [(<vector>? x)]
  (map process x))

(defmethod process [(<dict>? x)]
  (update-vals x process))

(defmethod process [(<number>? x)]
  (* x 2))

;; Works recursively on nested structures
(process [1 {:a 2 :b 3} [[4]]])
; => [2 {:a 4 :b 6} [[8]]]

;; Multiple dispatch with type predicates and destructuring
(defgeneric compute-total [items discount])

;; Dispatch on collection type with destructuring
(defmethod compute-total [(<vector>? items) (<number>? discount)]
  (* (reduce + items) (- 1.0 discount)))

;; Dispatch using both type and predicate
(defmethod compute-total
  [(<dict>? items)
   {:keys [rate type] :or {type :percentage}}]
  (bind [subtotal (reduce + (vals items))]
    (if (= type :percentage)
      (* subtotal (- 1.0 rate))
      (- subtotal rate))))

;; Multiple dispatch with nested patterns and rest args
(defgeneric merge-data [source target & options])

(defmethod merge-data
  [(<dict>? source)
   (<dict>? target)
   & {:keys [strategy overwrite?]
      :or {strategy :shallow overwrite? false}
      :as opts}]
  (cond
    (= strategy :deep)
      (deep-merge source target overwrite?)
    (= strategy :shallow)
      (if overwrite?
        (merge target source)
        (merge source target))))

;; Pattern matching with nested vectors and type predicates
(defgeneric transform-shape [shape transform])

(defmethod transform-shape
  [[(<keyword>? type)
    [(<number>? x) (<number>? y)]
    :as shape]
   {:keys [scale rotate translate]
    :or {scale 1.0 rotate 0 translate [0 0]}}]
  (bind [[[dx dy] translate]
         [rx ry] [(* x scale) (* y scale)]
         [tx ty] [(+ rx dx) (+ ry dy)]]
    [type [tx ty] :transformed true]))

This demonstrates how generic functions provide polymorphism through multiple dispatch while maintaining destructuring capabilities and functional purity.

### 4.4 Predicate Specializers

FOL extends pattern matching with general predicate specializers that allow functions to dispatch based on arbitrary predicate tests. The syntax `(var (fn arg0 arg1 ...))` applies the predicate function to the argument at runtime: `(apply fn var arg0 arg1 ...)`.

#### Basic Predicate Specialization

Predicates work with any function, providing flexible dispatch:

```clojure
;; Equality predicates
(defn check-value
  ([(n (= 0))] :zero)
  ([(n (= 1))] :one)
  ([n] :other))

;; Comparison predicates
(defn classify-number
  ([(n (< 0))] :negative)
  ([(n (= 0))] :zero)
  ([(n (> 0))] :positive))

;; Range checking
(defn age-group
  ([(age (< 13))] :child)
  ([(age (< 20))] :teen)
  ([(age (< 65))] :adult)
  ([age] :senior))

;; Symbol matching with quoted values
(defn dispatch-command
  ([(cmd (= 'start))] (start-system))
  ([(cmd (= 'stop))] (stop-system))
  ([(cmd (= 'restart))] (restart-system))
  ([cmd] (unknown-command cmd)))
```

#### Multiple Parameter Predicates

Predicate specializers support multiple parameters with independent predicates:

```clojure
(defn compare-signs
  ([(a (< 0)) (b (> 0))] :negative-positive)
  ([(a (> 0)) (b (< 0))] :positive-negative)
  ([(a (= 0)) (b (= 0))] :both-zero)
  ([a b] :other))

(compare-signs -5 10)  ; => :negative-positive
(compare-signs 10 -5)  ; => :positive-negative
```

#### Custom Predicates

Any function can serve as a predicate, enabling domain-specific dispatch:

```clojure
;; Type predicates
(defn process-value
  ([(<number>? x)] (* x 2))
  ([(<string>? x)] (str x x))
  ([(<vector>? x)] (map process-value x))
  ([x] x))

;; User-defined predicates
(defn even? [n] (= (mod n 2) 0))
(defn odd? [n] (= (mod n 2) 1))

(defn classify-parity
  ([(n (even?))] :even)
  ([(n (odd?))] :odd))
```

#### Predicate Specificity

Predicate specializers have the same specificity level as type specializers (level 4), higher than destructuring patterns (level 1) but allowing first-match semantics when multiple predicates could apply:

```clojure
(defn check
  ([(x (= 5))] :exactly-five)     ; Predicate (level 4)
  ([(x <number>)] :some-number)   ; Type (level 3)
  ([x] :anything))                ; Any (level 0)

(check 5)   ; => :exactly-five (predicate matches first)
(check 10)  ; => :some-number (type matches)
(check "x") ; => :anything (fallback)
```

#### Integration with `fn` and `lambda`

Predicate specializers work seamlessly in anonymous functions:

```clojure
;; Inline predicate dispatch
((fn ([(x (< 10))] :small)
     ([(x (>= 10))] :large)) 5)
; => :small

;; Lambda with predicates
(def classifier
  (λ ([(n (< 0))] :neg)
     ([(n (> 0))] :pos)
     ([n] :zero)))
```

#### Restrictions and Design Rationale

Predicate specializers are **not allowed** in macro parameter lists because macros receive unevaluated forms. A predicate needs to evaluate its argument, but macros work with raw syntax:

```clojure
;; This signals an error:
(defmacro bad-macro
  ([(x (= 0))] `0)
  ([x] `(inc ~x)))

; ERROR: Predicate specializers cannot be used in DEFMACRO
;        parameter lists (macros receive unevaluated forms)
```

This restriction prevents confusion between compile-time pattern matching (on syntax) and runtime value testing (on evaluated data). The error is detected immediately during macro definition, providing clear feedback.

#### Implementation

Predicate specializers are compiled to a signature format `(:pred fn-name (arg0 arg1 ...))` during function definition. At runtime, pattern matching evaluates `(apply fn-name actual-arg arg0 arg1 ...)` and dispatches to the clause when the result is truthy. The implementation maintains O(N) dispatch time where N is the number of patterns at a given arity, with patterns sorted by specificity for efficient matching.

This design provides powerful dispatch capabilities while maintaining simplicity and integration with FOL's existing pattern matching infrastructure.

## 5. Self-Hosted Evaluator

FOL includes a meta-circular evaluator written in FOL itself (approximately 350 lines):

```clojure
(defgeneric eval-form [form env])

(defmethod eval-form [(<number>? form) env]
  form)  ; Self-evaluating

(defmethod eval-form [(<symbol>? form) env]
  (lookup env form))

(defmethod eval-form [(<list>? form) env]
  (if (empty? form)
    form
    (bind [op (first form)
           args (rest form)]
      (if (special-form? op)
        ((get special-forms (name op)) args env)
        (bind [fn-val (eval-form op env)
               evaled-args (map #(eval-form % env) args)]
          (apply-function fn-val evaled-args))))))
```

The evaluator demonstrates several FOL features:
- Generic function dispatch on form types
- Pattern matching through method specialization
- First-class functions and lexical closures
- Special form handling through a dispatch table

Special form evaluators are defined as regular functions:

```clojure
(defn eval-if [args env]
  (bind [arg-count (size args)]
    (if (or (< arg-count 2) (> arg-count 3))
      (throw "if: expected 2 or 3 args")
      (bind [test (nth args 0)
             then-form (nth args 1)
             else-form (if (>= arg-count 3)
                         (nth args 2)
                         nil)]
        (if (fol-eval test env)
          (fol-eval then-form env)
          (fol-eval else-form env))))))
```

The self-hosted evaluator serves multiple purposes:

1. **Specification**: Defines FOL semantics precisely
2. **Metaprogramming**: Enables runtime code generation
3. **Extensibility**: Allows user-defined special forms

## 6. Evaluation

### 6.1 Performance Characteristics

FOL's performance characteristics reflect its implementation strategy:

| Operation      | Persistent | Mutable |
|----------------|------------|---------|
| Vector access  | O(log n)   | O(1)    |
| Vector update  | O(log n)   | O(1)    |
| Dict lookup    | O(log n)   | O(1)    |
| Dict insert    | O(log n)   | O(1)    |
| Set membership | O(log n)   | O(1)    |

While persistent structures incur a logarithmic factor, the constant factors are small due to high branching factors (32-64). For typical applications, the difference is negligible compared to I/O and algorithmic complexity.

### 6.2 Comparison with Related Languages

| Feature                         | FOL     | Clojure | Common Lisp |
|---------------------------------|---------|---------|-------------|
| Persistent colls                | ✓       | ✓       | ✗           |
| CLOS/MOP                        | ✓       | ✗       | ✓           |
| Transducers                     | ✓       | ✓       | ✗           |
| Lazy seqs                       | ✓       | ✓       | ✗           |
| Multiple destructuring dispatch | ✓       | ✓       | ✗           |
| Macros                          | ✓       | ✓       | ✓           |
| Reader syntax                   | Clojure | Clojure | CL          |

FOL occupies a unique position, providing both Clojure's functional features and Common Lisp's object system.

## 7. Future Work

Several extensions are planned for FOL:

- **Compilation**: Native code generation via SBCL
- **Class definition enhancements**: Abstract and sealed class definitions
- **Parallel collections**: Fork-join parallelism for sequence operations
- **Enhanced error system**: Condition classes, more powerful error-handling paradigms
- **Enhanced stream classes**: Additional stream classes, *in*/*out* streams

The most pressing need is compilation. Currently, all code is interpreted through the evaluator. Compiling to Common Lisp or native code would provide substantial performance improvements.

## 8. Related Work

### 8.1 Clojure

Clojure [4] pioneered persistent data structures in production Lisp. FOL adopts Clojure's sequence abstraction, transducer protocol and persistence while diverging in object system design. Where Clojure uses protocols and records, FOL uses CLOS generic functions and classes.

### 8.2 Common Lisp

FOL's object system is a direct descendant of CLOS [2]. The meta-object protocol [3] enables deep customization of class and generic function behavior. FOL extends this with persistent slot values.

### 8.3 Dylan

Dylan [5] influenced FOL's naming conventions and multiple dispatch semantics. The `<type>` notation improves code readability by clearly distinguishing types. In addition, FOL adopts Dylan's module system. Dylan modules provide a simplified way to package symbols when compared with Clojure's namespaces and Common Lisp's packages.

### 8.4 Persistent Data Structures

Okasaki's work [7] on purely functional data structures underpins modern implementations. FSet [8] and Sycamore provide production-quality persistent collections for Common Lisp.

## 9. Conclusion

FOL demonstrates that functional and object-oriented programming are synergistic. By combining Clojure's persistent data structures with CLOS's powerful object system, FOL enables new programming patterns unavailable in either parent language.

The language's key contributions include:

- Integration of persistent collections and objects with CLOS
- Self-hosted evaluator showcasing metaprogramming
- Unified syntax spanning multiple Lisp traditions
- Production-ready implementation in Common Lisp

FOL shows that the Lisp family's evolution need not be divergent. By thoughtfully combining ideas from different dialects, we can create languages that are more than the sum of their parts.

The complete FOL implementation, including 6,721 tests (6,144 bootstrap, 577 integration) and comprehensive documentation, is available at https://github.com/frankadrian/fol.

---

## References

[1] G. L. Steele Jr., *Common LISP: The Language*, 2nd ed. Digital Press, 1990.

[2] D. G. Bobrow, L. G. DeMichiel, R. P. Gabriel, S. E. Keene, G. Kiczales, and D. A. Moon, "Common lisp object system specification," *ACM Sigplan Notices*, vol. 23, no. SI, pp. 1-142, 1988.

[3] G. Kiczales, J. des Rivières, and D. G. Bobrow, *The Art of the Metaobject Protocol*. MIT Press, 1991.

[4] R. Hickey, "The Clojure programming language," in *Proceedings of the 2008 Symposium on Dynamic Languages*, 2008.

[5] Apple Computer, Inc., *Dylan Interim Reference Manual*. Apple Computer, Inc., 1993.

[6] R. Hickey, "Transducers," *Clojure Blog*, August 2014. Available: https://clojure.org/reference/transducers

[7] C. Okasaki, *Purely Functional Data Structures*. Cambridge University Press, 1999.

[8] S. L. Siskind, "FSet: A functional set-theoretic collections library for Common Lisp," *Quicklisp*, 2012. Available: https://common-lisp.net/project/fset/
