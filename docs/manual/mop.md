# Meta-Object Protocol (MOP)

FOL provides a Meta-Object Protocol built on top of Closer-MOP, offering introspection and reflection capabilities for the persistent-class system. The MOP is divided into two parts:

1. **Introspection API** (in `fol.mop`) - Functions for examining classes, slots, and instances
2. **Definition Forms** (in `fol.fol-mop`) - FOL-style definition forms with vector syntax

---

## Universal Constructor: `make`                                      *[function]*

The `make` function is a universal constructor that creates instances of any FOL class.

### Syntax

```fol
(make class-name value*)
```

### Collection Types (can be empty)

```fol
(make <vector>)           ; => []
(make <vector> 1 2 3)     ; => [1 2 3]
(make <list>)             ; => ()
(make <list> 1 2 3)       ; => (1 2 3)
(make <set> 1 2 3)        ; => #{1 2 3}
(make <dict> :a 1 :b 2)   ; => {:a 1 :b 2}
(make <bag> :a :a :b)     ; => bag with :a count 2, :b count 1
(make <array> 1 2 3)      ; => array containing 1 2 3
(make <lazy-seq> thunk)   ; => lazy sequence from thunk
```

### Wrapper Types (require exactly one value)

```fol
(make <string> "hello")   ; => "hello"
(make <bool> t)           ; => t
(make <char> \a)          ; => \a
(make <symbol> 'foo)      ; => foo
(make <keyword> :bar)     ; => :bar
```

### Number Types (require exactly one value)

```fol
(make <integer> 42)       ; => 42
(make <double-float> 3.14); => 3.14d0
(make <ratio> 1/2)        ; => 1/2
(make <complex> #C(1 2))  ; => #C(1 2)
```

### Stream Types

```fol
(make <string-input-stream> "hello")    ; => input stream reading from "hello"
(make <string-output-stream>)           ; => output stream writing to string
(make <file-input-stream> "path.txt")   ; => input stream reading from file
(make <file-output-stream> "path.txt")  ; => output stream writing to file
```

### Regex Types

```fol
(make <re-pattern> "\\d+")              ; => regex pattern
(make <re-scanner> pattern)             ; => compiled scanner
```

---

## Class Introspection                                       *[generic functions]*

Functions for examining class structure and relationships.

| Function | Description |
|----------|-------------|
| `class-name*` | Return the name of the class |
| `class-direct-superclasses*` | Return the list of direct superclasses |
| `class-direct-subclasses*` | Return the list of direct subclasses |
| `class-precedence-list*` | Return the full class precedence list |
| `class-direct-slots*` | Return direct slot definitions only |
| `class-slots*` | Return all slot definitions (including inherited) |
| `finalized-p` | Return t if the class has been finalized |
| `ensure-finalized` | Ensure the class is finalized, return the class |

### Examples

```fol
(class-name* <vector>)                  ; => <VECTOR>
(class-direct-superclasses* <vector>)   ; => (<PERSISTENT-OBJECT>)
(class-direct-subclasses* <number>)     ; => (<COMPLEX> <REAL>)
(class-precedence-list* <integer>)      ; => (<INTEGER> <RATIONAL> <REAL> ...)
```

---

## Slot Definition Introspection                             *[generic functions]*

Functions for examining slot properties.

| Function | Description |
|----------|-------------|
| `slot-definition-name*` | Return the name of the slot |
| `slot-definition-type*` | Return the type constraint of the slot |
| `slot-definition-initargs*` | Return the list of initialization keywords |
| `slot-definition-initform*` | Return the initform expression |
| `slot-definition-initfunction*` | Return the compiled initform function |
| `slot-definition-allocation*` | Return allocation type (`:instance` or `:class`) |
| `slot-definition-readers*` | Return the list of reader functions |
| `slot-definition-writers*` | Return the list of writer functions |

### Examples

```fol
(let ((slot (first (class-direct-slots* <string>))))
  (slot-definition-name* slot))         ; => VAL

(let ((slot (first (class-direct-slots* <string>))))
  (slot-definition-type* slot))         ; => STRING
```

---

## Instance Introspection                                    *[generic functions]*

Functions for examining object instances.

| Function | Description |
|----------|-------------|
| `instance-class` | Return the class of an instance |
| `instance-slots` | Return slot definitions for an instance's class |
| `slot-names` | Return a list of slot names for a class or instance |
| `slot-exists-p*` | Return t if the slot exists |
| `slot-boundp*` | Return t if the slot is bound in an instance |
| `slot-value*` | Return the value of a slot in an instance |

### Examples

```fol
(instance-class [1 2 3])                ; => #<PERSISTENT-CLASS <VECTOR>>
(slot-names <string>)                   ; => (VAL)
(slot-exists-p* <string> 'val)          ; => t
```

---

## Utility Functions                                              *[functions]*

Higher-level functions for common MOP operations.

| Function | Description |
|----------|-------------|
| `all-persistent-classes` | Return all classes with persistent-class metaclass |
| `subclasses*` | Return all subclasses (or direct only with `:direct-only t`) |
| `superclasses*` | Return all superclasses (or direct only with `:direct-only t`) |
| `find-slot-definition` | Find a specific slot definition by name |
| `slot-properties` | Return a property list describing a slot |
| `class-info` | Return a property list with detailed class information |
| `describe-class` | Print a human-readable class description |
| `describe-slot` | Print a human-readable slot description |
| `persistent-class-p` | Return t if argument is/names a persistent-class |
| `persistent-object-p` | Return t if argument is a persistent object instance |

### Examples

```fol
(subclasses* <number>)                  ; => all subclasses of <number>
(subclasses* <number> :direct-only t)   ; => (<COMPLEX> <REAL>)
(superclasses* <integer>)               ; => (<RATIONAL> <REAL> <NUMBER> ...)

(class-info <string>)
; => (:name <STRING>
;     :direct-superclasses (<PERSISTENT-OBJECT>)
;     :direct-subclasses (<RE-PATTERN> <SYMBOL>)
;     :precedence-list (<STRING> <PERSISTENT-OBJECT> ...)
;     :direct-slots (VAL)
;     :all-slots (VAL)
;     :finalized t)
```

---

## Constructor Generation Protocol                                *[functions]*

Functions for generating and examining constructors.

| Function | Description |
|----------|-------------|
| `class-name-string` | Return the class name as a string |
| `bare-class-name` | Return class name without angle brackets |
| `constructor-name` | Return the make-X constructor name |
| `class-initargs` | Return all initarg keywords for a class |
| `required-initargs` | Return initargs for slots without initforms |
| `optional-initargs` | Return initargs for slots with initforms |
| `make-instance*` | Generic constructor protocol |
| `define-constructor` | Macro to define a constructor function |
| `define-constructors` | Macro to define multiple constructors |
| `generate-constructor-form` | Return source form for a constructor |
| `list-constructible-classes` | Return all persistent classes |
| `describe-constructor` | Print constructor information |

### Examples

```fol
(bare-class-name '<string>)             ; => "STRING"
(constructor-name '<string>)            ; => MAKE-STRING
(class-initargs '<string>)              ; => (:VAL)

(describe-constructor '<string>)
; Constructor for <STRING>:
;   Function name: MAKE-STRING
;   Required initargs: :VAL
;   Optional initargs:
;   All initargs: :VAL
```

---

## FOL Definition Forms

FOL provides special definition forms that use vector syntax instead of lists, following FOL conventions.

### `defgeneric*`                                                       *[macro]*

Define a generic function with vector lambda list.

#### Syntax

```fol
; Single pattern
(defgeneric* name [lambda-list] option*)

; Multi-pattern (different arities or destructuring patterns)
(defgeneric* name ([lambda-list-1] [lambda-list-2] ...) option*)
```

#### Options

| Option | Description |
|--------|-------------|
| `:documentation` | Docstring for the generic function |
| `:generic-function-class` | Metaclass for the generic function |
| `:method-combination` | Method combination type |
| `:method-class` | Class for method objects |

#### Examples

```fol
; Single pattern generic function
(defgeneric* distance [a b]
  (:documentation "Calculate distance between two objects."))

; Multi-arity generic function
(defgeneric* process ([x] [x y] [x y z])
  (:documentation "Process 1, 2, or 3 arguments."))

; Multi-pattern with destructuring (same arity, different structure)
(defgeneric* handle-input ([x] [[a b]])
  (:documentation "Handle a single value or destructure a pair."))
```

---

### `defclass*`                                                         *[macro]*

Define a class with vector syntax for superclasses and slots.

#### Syntax

```fol
(defclass* name [superclasses] [slots] class-option*)
```

#### Slot Specification

Slots can be simple symbols or full specifications in a vector:

```fol
[slot-name :initarg :keyword :accessor accessor-name :type type ...]
```

#### Examples

```fol
(defclass* <point> [<persistent-object>]
  [[x :initarg :x :accessor point-x :type real]
   [y :initarg :y :accessor point-y :type real]]
  (:metaclass persistent-class)
  (:documentation "A 2D point."))

(defclass* <named-point> [<point>]
  [[name :initarg :name :accessor point-name :type string]]
  (:metaclass persistent-class)
  (:documentation "A named 2D point."))
```

---

### `defmethod*`                                                        *[macro]*

Define a method with vector syntax for the specialized lambda list.

#### Syntax

```fol
(defmethod* name qualifier* [specialized-lambda-list] body*)
```

#### Specialized Parameters

Parameters can be specialized using list syntax (not vector):

```fol
(var class-name)        ; Type specialization
(var (eql value))       ; EQL specialization
```

#### Qualifiers

Standard method qualifiers: `:before`, `:after`, `:around`

#### Examples

```fol
; Basic method
(defmethod* distance [(a <point>) (b <point>)]
  (sqrt (+ (expt (- (point-x b) (point-x a)) 2)
           (expt (- (point-y b) (point-y a)) 2))))

; Method with :around qualifier
(defmethod* distance :around [(a <point>) (b <point>)]
  (format t "Computing distance...~%")
  (call-next-method))

; Method for multi-arity generic
(defmethod* process [(x <integer>)]
  (* x 2))

(defmethod* process [(x <integer>) (y <integer>)]
  (+ x y))
```

---

## Multi-Pattern Generic Functions

FOL supports generic functions with multiple patterns, allowing different behavior based on both arity and argument structure.

### Pattern Matching

When a generic function is called, patterns are matched in order:

1. First by arity (number of arguments)
2. Then by specificity (destructuring patterns before `:any` patterns)

### Destructuring Patterns

Destructuring patterns expect sequential arguments:

```fol
(defgeneric* process-data ([x] [[a b]])
  (:documentation "Handle single value or pair."))

; Method for single value
(defmethod* process-data [(x <integer>)]
  (* x 2))

; Method for destructured pair
(defmethod* process-data [([a b] <list>)]
  (+ a b))

(process-data 5)        ; => 10 (matches [x])
(process-data '(3 4))   ; => 7  (matches [[a b]], destructured)
```

### Pattern Info Storage

Multi-pattern generic functions store pattern information on the function symbol's property list under `'multi-pattern-info`. This allows `defmethod*` to route methods to the correct pattern-specific internal generic function.

---

## Runtime Evaluation Functions                                   *[functions]*

For dynamic definition at runtime, the following functions are available:

| Function | Description |
|----------|-------------|
| `eval-defgeneric*` | Evaluate a defgeneric* form at runtime |
| `eval-defclass*` | Evaluate a defclass* form at runtime |
| `eval-defmethod*` | Evaluate a defmethod* form at runtime |

These are used internally by the FOL compiler when processing definition forms.
