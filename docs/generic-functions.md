# Generic Functions

FOL provides a metaobject protocol (MOP) for defining generic functions and methods using vector syntax instead of traditional Lisp list syntax. FOL's generic function system combines CLOS-style type dispatch with Clojure-style pattern matching and predicate-based specialization.

---

## Pattern Signature System

At the core of FOL's dispatch mechanism is the **pattern signature** system. Each parameter in a method definition is analyzed and classified into one of these categories, ordered from most to least specific:

| Level | Signature Type | Syntax Example | Description |
|-------|---------------|----------------|-------------|
| 4 | `:pred` | `(var (< 10))` | Predicate specialization (guard clause) |
| 3 | `:type` | `(var <number>)` | Type specialization |
| 2 | `:type-pred` | `(<integer>? var)` | Type predicate |
| 1 | `:seq` | `[[a b]]` | Sequence destructuring |
| 0 | `:any` | `var` | Matches anything (catch-all) |

When dispatching, more specific patterns are tried before less specific ones.

---

## defgeneric                                                              *[macro]*

```
(defgeneric name [lambda-list] option*)
(defgeneric name ([lambda-list-1] [lambda-list-2] ...) option*)
```

Defines a generic function. The lambda list specifies the parameters using destructuring vector syntax.

### Single Pattern

For functions with a fixed signature, use a single vector:

```fol
(defgeneric distance [a b]
  (:documentation "Calculate distance between two objects."))

(defgeneric describe-object [obj]
  (:documentation "Return a description of an object."))
```

### Multi-Pattern Dispatch

For functions that accept different patterns (different arities or different structures), provide a list of vectors:

```fol
;; Different arities
(defgeneric greet ([name] [greeting name])
  (:documentation "Greet someone, optionally with a custom greeting."))

(defgeneric make-point ([x y] [x y z])
  (:documentation "Create a 2D or 3D point."))

(defgeneric combine ([a] [a b] [a b c])
  (:documentation "Combine 1, 2, or 3 values."))
```

Multi-pattern `defgeneric` creates:
- Internal generic functions for each pattern (e.g., `greet/P0`, `greet/P1`)
- A dispatcher function with the original name that routes calls by pattern matching

### Pattern-Based Dispatch

Patterns can distinguish between simple parameters and sequence parameters (same arity, different structure):

```fol
;; [x] matches any single argument
;; [[a b]] matches a single argument that IS a 2-element sequence
(defgeneric process ([x] [[a b]])
  (:documentation "Process a value, or destructure a pair."))
```

When called, the dispatcher checks argument structure:
- If the argument is a sequence of at least 2 elements, routes to the `[[a b]]` pattern
- Otherwise, routes to the `[x]` pattern (catch-all)

More specific patterns (sequences) are tried before less specific patterns (:any).

### Options

Standard CLOS options are supported:

```fol
(defgeneric area [shape]
  (:documentation "Calculate the area of a shape.")
  (:method-combination standard))
```

---

## defmethod                                                               *[macro]*

```
(defmethod name qualifier* [specialized-lambda-list] body*)
```

Defines a method on a generic function. Parameters can be specialized to dispatch on type or predicates.

### Basic Methods

```fol
;; Unspecialized method (matches any argument)
(defmethod describe-object [obj]
  (str "An object: " obj))

;; Specialized method (matches specific type)
(defmethod describe-object [(obj <string>)]
  (str "A string of length " (size obj)))

(defmethod describe-object [(obj <integer>)]
  (str "An integer: " obj))
```

### Type Specializers

Use a list `(var type)` to specialize on a type:

```fol
(defmethod distance [(a <point-2d>) (b <point-2d>)]
  (sqrt (+ (expt (- (point-x b) (point-x a)) 2)
           (expt (- (point-y b) (point-y a)) 2))))

(defmethod distance [(a <point-3d>) (b <point-3d>)]
  (sqrt (+ (expt (- (point-x b) (point-x a)) 2)
           (expt (- (point-y b) (point-y a)) 2)
           (expt (- (point-z b) (point-z a)) 2))))
```

### = Specializers

Specialize on a specific value using `(var (= value))`:

```fol
(defmethod factorial [(n (= 0))]
  1)

(defmethod factorial [(n <integer>)]
  (* n (factorial (- n 1))))
```

---

## Predicate Specializers (Guard Clauses)

One of FOL's most powerful features is **predicate specialization**, which allows methods to dispatch based on arbitrary predicates (guard clauses). This enables pattern matching on value properties, not just types.

### Syntax

```
(var (predicate-fn arg*))
```

The parameter matches when `(predicate-fn var arg*)` returns truthy.

### Common Predicate Patterns

```fol
;; Equality check
(defmethod classify [(x (= 0))]
  :zero)

;; Comparison predicates
(defmethod classify [(x (< 0))]
  :negative)

(defmethod classify [(x (> 0))]
  :positive)

;; Range matching with multiple predicates
(defmethod temperature-feel [(temp (< 32))]
  :freezing)

(defmethod temperature-feel [(temp (< 60))]
  :cold)

(defmethod temperature-feel [(temp (< 80))]
  :comfortable)

(defmethod temperature-feel [temp]
  :hot)
```

### Multiple Parameter Predicates

Predicates can be combined across multiple parameters:

```fol
(defgeneric quadrant [x y])

(defmethod quadrant [(x (> 0)) (y (> 0))]
  :first)

(defmethod quadrant [(x (< 0)) (y (> 0))]
  :second)

(defmethod quadrant [(x (< 0)) (y (< 0))]
  :third)

(defmethod quadrant [(x (> 0)) (y (< 0))]
  :fourth)

(defmethod quadrant [x y]
  :on-axis)
```

### Predicates with Additional Arguments

Predicate specializers can include additional arguments:

```fol
;; (contains? coll value) - matches when collection contains value
(defmethod handle-response [(status (contains? #{200 201 204}))]
  :success)

(defmethod handle-response [(status (contains? #{400 401 403 404}))]
  :client-error)

(defmethod handle-response [(status (contains? #{500 502 503}))]
  :server-error)
```

### Custom Predicate Functions

Any function returning truthy/falsy can be used:

```fol
(defn prime? [n]
  ;; primality test implementation
  ...)

(defmethod classify-number [(n prime?)]
  :prime)

(defmethod classify-number [(n even?)]
  :even-composite)

(defmethod classify-number [n]
  :odd-composite)
```

### Predicate Specificity

When multiple predicate methods could match, they are tried in definition order. More specific predicates should be defined first:

```fol
;; Define from most specific to least specific
(defmethod age-group [(age (= 0))]
  :newborn)

(defmethod age-group [(age (< 13))]
  :child)

(defmethod age-group [(age (< 20))]
  :teen)

(defmethod age-group [(age (< 65))]
  :adult)

(defmethod age-group [age]
  :senior)
```

---

## Combining Types and Predicates

Type specializers and predicate specializers can be combined for precise matching:

```fol
(defgeneric process-value [val])

;; Type + predicate combination
(defmethod process-value [(n <integer>)]
  (if (< n 0)
      :negative-integer
      :non-negative-integer))

;; Or use predicates directly
(defmethod process-value [(n (< 0))]
  :negative)

(defmethod process-value [(s <string>)]
  (if (empty? s)
      :empty-string
      :non-empty-string))
```

### Precedence Rules

When both type and predicate specializers could match:
1. Predicate specializers (`:pred`) are checked first (level 4)
2. Type specializers (`:type`) are checked second (level 3)
3. Catch-all patterns (`:any`) are checked last (level 0)

```fol
(defgeneric classify [x])

;; This matches first for zero (predicate check)
(defmethod classify [(x (= 0))]
  :zero)

;; This matches for any integer (type check)
(defmethod classify [(x <integer>)]
  :integer)

;; This is the fallback (catch-all)
(defmethod classify [x]
  :unknown)

(classify 0)   ; => :zero (predicate matched first)
(classify 5)   ; => :integer (type matched)
(classify "x") ; => :unknown (catch-all)
```

---

## Method Qualifiers

Standard CLOS qualifiers are supported:

```fol
;; Primary method
(defmethod process [obj]
  (do-processing obj))

;; Before method - runs before the primary
(defmethod process :before [obj]
  (log "Starting to process" obj))

;; After method - runs after the primary
(defmethod process :after [obj]
  (log "Finished processing" obj))

;; Around method - wraps the primary
(defmethod process :around [obj]
  (with-timing
    (call-next-method)))
```

---

## Multi-Pattern Methods

When a generic function is defined with multiple patterns, `defmethod` routes methods to the correct internal generic function based on the pattern signature.

### Example: Greeting Function

```fol
;; Define a multi-pattern generic
(defgeneric greet ([name] [greeting name]))

;; Method for 1 argument - routes to greet/P0
(defmethod greet [name]
  (str "Hello, " name "!"))

;; Method for 2 arguments - routes to greet/P1
(defmethod greet [greeting name]
  (str greeting ", " name "!"))

;; Usage
(greet "World")              ; => "Hello, World!"
(greet "Bonjour" "World")    ; => "Bonjour, World!"
```

### Example: Specialized Multi-Pattern

```fol
;; Generic for combining values
(defgeneric combine ([a] [a b] [a b c]))

;; Single value - return as-is
(defmethod combine [a]
  a)

;; Two numbers - add them
(defmethod combine [(a <number>) (b <number>)]
  (+ a b))

;; Two strings - concatenate
(defmethod combine [(a <string>) (b <string>)]
  (str a b))

;; Three values - combine all
(defmethod combine [a b c]
  (combine (combine a b) c))

;; Usage
(combine 5)                  ; => 5
(combine 3 4)                ; => 7
(combine "foo" "bar")        ; => "foobar"
(combine 1 2 3)              ; => 6
```

### Example: Multi-Pattern with Predicates

```fol
;; Factorial using predicate dispatch
(defgeneric factorial [n])

(defmethod factorial [(n (= 0))]
  1)

(defmethod factorial [(n (= 1))]
  1)

(defmethod factorial [(n <integer>)]
  (* n (factorial (- n 1))))

;; Fibonacci using predicates for base cases
(defgeneric fib [n])

(defmethod fib [(n (< 2))]
  n)

(defmethod fib [(n <integer>)]
  (+ (fib (- n 1)) (fib (- n 2))))
```

### Pattern Dispatch Errors

Calling a multi-pattern function with an unsupported arity signals an error:

```fol
(defgeneric foo ([x] [x y]))

(foo 1)       ; OK
(foo 1 2)     ; OK
(foo 1 2 3)   ; Error: No matching arity 3 for foo (valid arities: 1, 2)
(foo)         ; Error: No matching arity 0 for foo (valid arities: 1, 2)
```

---

## Pattern-Based Dispatch Example

When patterns have the same arity but different structures:

```fol
;; Define generic that handles both atoms and pairs
(defgeneric handle ([x] [[a b]]))

;; Method for the catch-all pattern (any single argument)
;; Must define on internal generic handle/P0
(defmethod handle/P0 [x]
  (str "Got atom: " x))

;; Method for the sequence pattern
;; Must define on internal generic handle/P1
(defmethod handle/P1 [pair]
  (str "Got pair: " pair))

;; Usage
(handle 42)              ; => "Got atom: 42"
(handle "hello")         ; => "Got atom: hello"
(handle [1 2])           ; => "Got pair: [1 2]"
(handle (list 'a 'b))    ; => "Got pair: (a b)"
```

The dispatcher checks:
1. Arity (number of arguments)
2. For same-arity patterns, checks if arguments match structure requirements
3. More specific patterns (sequence expectations) are tried first

---

## Destructuring Patterns with Predicates

FOL supports nested predicates within destructuring patterns:

```fol
;; Destructure a pair and validate elements
(defgeneric process-pair [pair])

(defmethod process-pair [[[x (y (> 0))]]]
  (str "x=" x " with positive y=" y))

(defmethod process-pair [[[x y]]]
  (str "x=" x " y=" y))

;; Usage
(process-pair [1 5])   ; => "x=1 with positive y=5"
(process-pair [1 -3])  ; => "x=1 y=-3"
```

### Supported Destructuring Forms

```fol
[a b c]           ; Sequential destructuring
[a & rest]        ; Rest parameter
[a b :as whole]   ; Whole binding
{:keys [x y]}     ; Dict destructuring
[[x y]]           ; Nested sequence patterns
[x (y (< 10))]    ; Predicates within patterns
```

---

## Restrictions

### Macros Cannot Use Predicate Specializers

Predicate specializers are **not allowed in macros** because macros receive unevaluated forms, not values. Predicates need evaluated values to run:

```fol
;; This will signal an error
(defmacro bad-macro
  ([(x (= 0))] ...)  ; ERROR: Predicate specializers not allowed in macros
  ([x] ...))
```

Type specializers are also not supported in macros for the same reason.

---

## defclass                                                                *[macro]*

```
(defclass name [superclasses] [slots] class-option*)
```

Defines a class using vector syntax.

### Basic Class

```fol
(defclass <point> []
  [x y])
```

### With Superclasses

```fol
(defclass <colored-point> [<point>]
  [color])
```

### Full Slot Specifications

```fol
(defclass <person> [<persistent-object>]
  [[name :initarg :name :accessor person-name :type <string>]
   [age :initarg :age :accessor person-age :type <integer> :initform 0]]
  (:documentation "A person with a name and age."))
```

---

## Complete Example

```fol
;; Define a shape hierarchy
(defclass <shape> [] [])

(defclass <circle> [<shape>]
  [[radius :initarg :radius :accessor circle-radius]])

(defclass <rectangle> [<shape>]
  [[width :initarg :width :accessor rect-width]
   [height :initarg :height :accessor rect-height]])

;; Multi-pattern generic for creating shapes
(defgeneric make-shape ([type] [type a] [type a b]))

;; Circle needs one dimension (radius)
(defmethod make-shape [(type (eql :circle)) radius]
  (make <circle> :radius radius))

;; Rectangle needs two dimensions
(defmethod make-shape [(type (eql :rectangle)) width height]
  (make <rectangle> :width width :height height))

;; Square is a rectangle with equal sides
(defmethod make-shape [(type (eql :square)) side]
  (make <rectangle> :width side :height side))

;; Generic for calculating area
(defgeneric area [shape])

(defmethod area [(shape <circle>)]
  (* 3.14159 (expt (circle-radius shape) 2)))

(defmethod area [(shape <rectangle>)]
  (* (rect-width shape) (rect-height shape)))

;; Usage
(def c (make-shape :circle 5))
(def r (make-shape :rectangle 3 4))
(def s (make-shape :square 5))

(area c)  ; => 78.53975
(area r)  ; => 12
(area s)  ; => 25
```

---

## Advanced Example: Calculator with Predicate Dispatch

```fol
;; A calculator that handles special cases with predicates

(defgeneric calc [op a b])

;; Division by zero protection
(defmethod calc [(op (= :div)) a (b (= 0))]
  (error "Division by zero"))

;; Multiplication by zero optimization
(defmethod calc [(op (= :mul)) a (b (= 0))]
  0)

(defmethod calc [(op (= :mul)) (a (= 0)) b]
  0)

;; Multiplication by one optimization
(defmethod calc [(op (= :mul)) a (b (= 1))]
  a)

(defmethod calc [(op (= :mul)) (a (= 1)) b]
  b)

;; Standard operations
(defmethod calc [(op (= :add)) (a <number>) (b <number>)]
  (+ a b))

(defmethod calc [(op (= :sub)) (a <number>) (b <number>)]
  (- a b))

(defmethod calc [(op (= :mul)) (a <number>) (b <number>)]
  (* a b))

(defmethod calc [(op (= :div)) (a <number>) (b <number>)]
  (/ a b))

;; Usage
(calc :mul 5 0)    ; => 0 (optimized)
(calc :mul 1 42)   ; => 42 (optimized)
(calc :div 10 0)   ; => Error: Division by zero
(calc :add 3 4)    ; => 7
```

---

## Grammar

```
defgeneric-form ::= (defgeneric function-name [gf-lambda-declaration | (gf-lambda-declaration+)] generic-option*)

gf-lambda-declaration ::= gf-destructuring-vector method-option* method-description?

generic-option ::= (:documentation <string>) | (:generic-function-class <class-name>)

method-option ::= (:argument-precedence-order <parameter-name>+)
                | (declare gf-declaration+)
                | (:method-combination <method-combination-type>)
                | (:method-class <class-name>)

method-description ::= (:method method-qualifier* method-destructuring-vector method-option* form*)

gf-destructuring-vector ::= <destructuring-vector>

method-destructuring-vector ::= <destructuring-vector>

specialized-parameter ::= var                      ; Unspecialized (:any)
                       | (var type)                ; Type specializer (:type)
                       | (var (pred-fn arg*))      ; Predicate specializer (:pred)
                       | (type-pred? var)          ; Type predicate (:type-pred)
                       | [pattern-element*]        ; Sequence pattern (:seq)
```

---

## Implementation Notes

- Multi-pattern generics create internal functions named `name/PN` where N is the pattern index (0, 1, 2...)
- The dispatcher function with the original name routes calls by checking:
  1. Argument count (arity)
  2. For same-arity patterns: argument structure and predicate conditions
- Pattern signatures are computed at definition time by `compute-pattern-signature`
- Specificity levels determine dispatch order (predicates > types > sequences > catch-all)
- Runtime matching uses `args-match-pattern-p` which evaluates predicate specializers
- Single-pattern generics work exactly like standard CLOS generic functions (no dispatcher overhead)
- All standard CLOS features (method combination, qualifiers, etc.) are available

### Runtime Pattern Matching

At call time, the generated dispatcher:
1. Checks argument count against known arities
2. For each same-arity pattern (most specific first):
   - Evaluates each parameter's predicate/type check
   - Short-circuits on first failure
3. Routes to the first matching internal generic
4. Internal generic uses standard CLOS dispatch for additional type specialization

### Related Functions

| Function | Purpose |
|----------|---------|
| `compute-pattern-signature` | Analyzes parameters to determine signature |
| `args-match-pattern-p` | Runtime check if args match a signature |
| `element-matches-signature-p` | Recursive check for nested patterns |
| `type-conforms-p` | Check if value matches a type |
