# Generic Functions

FOL provides a metaobject protocol (MOP) for defining generic functions and methods using vector syntax instead of traditional Lisp list syntax.

## defgeneric

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

## defmethod

```
(defmethod name qualifier* [specialized-lambda-list] body*)
```

Defines a method on a generic function. Parameters can be specialized to dispatch on type.

### Basic Methods

```fol
;; Unspecialized method (matches any argument)
(defmethod describe-object [obj]
  (str "An object: " obj))

;; Specialized method (matches specific type)
(defmethod describe-object [[obj <string>]]
  (str "A string of length " (size obj)))

(defmethod describe-object [[obj <integer>]]
  (str "An integer: " obj))
```

### Specialized Parameters

Use a vector `[var type]` to specialize on a type:

```fol
(defmethod distance [[a <point-2d>] [b <point-2d>]]
  (sqrt (+ (expt (- (point-x b) (point-x a)) 2)
           (expt (- (point-y b) (point-y a)) 2))))

(defmethod distance [[a <point-3d>] [b <point-3d>]]
  (sqrt (+ (expt (- (point-x b) (point-x a)) 2)
           (expt (- (point-y b) (point-y a)) 2)
           (expt (- (point-z b) (point-z a)) 2))))
```

### EQL Specializers

Specialize on a specific value using `[var [eql value]]`:

```fol
(defmethod factorial [[n [eql 0]]]
  1)

(defmethod factorial [[n <integer>]]
  (* n (factorial (- n 1))))
```

### Method Qualifiers

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
(defmethod combine [[a <number>] [b <number>]]
  (+ a b))

;; Two strings - concatenate
(defmethod combine [[a <string>] [b <string>]]
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

## defclass

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
(defmethod make-shape [[type [eql :circle]] radius]
  (make <circle> :radius radius))

;; Rectangle needs two dimensions
(defmethod make-shape [[type [eql :rectangle]] width height]
  (make <rectangle> :width width :height height))

;; Square is a rectangle with equal sides
(defmethod make-shape [[type [eql :square]] side]
  (make <rectangle> :width side :height side))

;; Generic for calculating area
(defgeneric area [shape])

(defmethod area [[shape <circle>]]
  (* 3.14159 (expt (circle-radius shape) 2)))

(defmethod area [[shape <rectangle>]]
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
```

---

## Implementation Notes

- Multi-pattern generics create internal functions named `name/PN` where N is the pattern index (0, 1, 2...)
- The dispatcher function with the original name routes calls by checking:
  1. Argument count (arity)
  2. For same-arity patterns: argument structure (is it a sequence?)
- Pattern signatures are computed at definition time to determine specificity
- More specific patterns (expecting sequences) are tried before catch-all patterns
- Single-pattern generics work exactly like standard CLOS generic functions
- All standard CLOS features (method combination, qualifiers, etc.) are available
