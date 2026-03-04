# Special Forms

Special forms are the primitive building blocks of FOL that have special evaluation rules. Unlike functions, their arguments are not necessarily evaluated before the form is processed.

---

## quote                                                          *[special form]*

```
(quote form)
'form
```

Returns the form unevaluated. The reader macro `'` is shorthand for `quote`.

### Examples

```fol
(quote (+ 1 2))           ; => (+ 1 2) - the list, not 3
'(+ 1 2)                  ; => (+ 1 2) - same as above

(quote x)                 ; => x - the symbol
'x                        ; => x

'[1 2 3]                  ; => [1 2 3] - quoted vector
'{:a 1 :b 2}              ; => {:a 1 :b 2} - quoted map
```

---

## if                                                             *[special form]*

```
(if test then)
(if test then else)
```

Evaluates `test`. If truthy, evaluates and returns `then`.
Otherwise, evaluates and returns `else` (or nil if not provided).

### Examples

```fol
(if true "yes" "no")      ; => "yes"
(if false "yes" "no")     ; => "no"
(if (> 5 3) "bigger")     ; => "bigger"
(if (< 5 3) "smaller")    ; => nil
```

---

## do                                                             *[special form]*

```
(do form0 form1 ... formN)
```

Evaluates all forms in sequence and returns the value of the last form.
Returns nil if no forms are provided.

### Examples

```fol
(do
  (print "step 1")
  (print "step 2")
  42)                     ; prints both, returns 42

(do)                      ; => nil
```

---

## bind / let                                                     *[special form]*

```
(bind [bindings] body...)
(let [bindings] body...)
```

Creates local bindings and evaluates body forms. Bindings are pairs of pattern and value.
Supports destructuring. `let` is an alias for `bind`.

### Examples

```fol
(bind [x 1
       y 2]
  (+ x y))                ; => 3

;; Destructuring
(bind [[a b] [1 2]]
  (+ a b))                ; => 3

;; Sequential bindings (each sees previous)
(bind [x 1
       y (+ x 1)]
  y)                      ; => 2
```

---

## fn / λ                                                         *[special form]*

```
(fn [params] body...)
(fn name [params] body...)
(λ [params] body...)
```

Creates an anonymous function. Optionally, a name can be provided for recursion.
The `λ` symbol is a synonym for `fn`.

Supports destructuring in parameters (see [destructuring](destructuring.md)).

### Examples

```fol
;; Simple anonymous function
((fn [x] (* x 2)) 5)      ; => 10

;; Named function (for recursion)
(def factorial
  (fn fact [n]
    (if (<= n 1)
        1
        (* n (fact (- n 1))))))
(factorial 5)             ; => 120

;; With destructuring
((fn [[a b]] (+ a b)) [3 4])  ; => 7

;; With rest parameter
((fn [x & more] (+ x (first more))) 1 2 3)  ; => 3

;; Using λ
((λ [x] (* x x)) 5)       ; => 25
```

---

## def                                                            *[special form]*

```
(def name value)
```

Defines a global variable with the given name and value.

### Examples

```fol
(def pi 3.14159)
(def greeting "Hello")
(def add-one (fn [x] (+ x 1)))
```

---

## defn                                                           *[special form]*

```
(defn name [params] body...)
(defn name
  ([params1] body1...)
  ([params2] body2...)
  ...)
```

Defines a named function. Sugar for `(def name (fn name [params] body...))`.

### Single Pattern

```fol
(defn double [x]
  (* x 2))

(defn add [a b]
  (+ a b))
```

### Multi-Pattern Dispatch

For functions that accept different arities or patterns:

```fol
;; Different arities
(defn greet
  ([name] (str "Hello, " name "!"))
  ([greeting name] (str greeting ", " name "!")))

(greet "World")           ; => "Hello, World!"
(greet "Hi" "Alice")      ; => "Hi, Alice!"
```

---

## defmacro                                                       *[special form]*

```
(defmacro name [params] body...)
(defmacro name
  ([params1] body1...)
  ([params2] body2...)
  ...)
```

Defines a macro. Macros receive unevaluated forms and return a new form to evaluate.

### Examples

```fol
(defmacro unless [test & body]
  `(if (not ~test) (do ~@body)))

(unless false (print "executed"))  ; prints "executed"
```

---

## cond                                                           *[special form]*

```
(cond test1 form1 test2 form2 ... testN formN)
```

Evaluates test/form pairs in order. When a test evaluates to a truthy value,
evaluates and returns the corresponding form. If no test is truthy, returns nil.

### Examples

```fol
(cond
  (< x 0) :negative
  (= x 0) :zero
  (> x 0) :positive)      ; returns based on value of x

;; Default case using t
(cond
  (= n 1) :one
  (= n 2) :two
  t :other)               ; returns :other if n is not 1 or 2
```

---

## case                                                           *[special form]*

```
(case target-form
  target1 form1
  target2 form2
  ...
  [default-form])
```

Evaluates `target-form` to get a value, then matches against targets.
Each target can be an atom or a vector of atoms.

### Examples

```fol
;; Simple matching
(case x
  1 :one
  2 :two
  3 :three
  :unknown)               ; default if x is not 1, 2, or 3

;; Vector of targets (matches any)
(case day
  [0 6] :weekend
  [1 2 3 4 5] :weekday)
```

---

## loop                                                           *[special form]*

```
(loop [bindings] body*)
```

Establishes a recursion point with initial bindings. Use `recur` to jump back
to the loop with new values.

### Examples

```fol
;; Sum numbers from 1 to n
(loop [i 1
       sum 0]
  (if (> i 10)
      sum
      (recur (+ i 1) (+ sum i))))  ; => 55

;; Factorial
(defn factorial [n]
  (loop [i n
         acc 1]
    (if (<= i 1)
        acc
        (recur (- i 1) (* acc i)))))
```

---

## recur                                                          *[special form]*

```
(recur arg*)
```

Jumps back to the enclosing `loop` with new values for the bindings.
The number of arguments must match the number of loop bindings.
`recur` must be in tail position.

---

## throw                                                          *[special form]*

```
(throw value)
```

Throws an exception with the given value.

### Examples

```fol
(throw "Something went wrong")

(defn divide [a b]
  (if (= b 0)
      (throw "Division by zero")
      (/ a b)))
```

---

## try                                                            *[special form]*

```
(try
  body*
  (catch var body*)
  (finally body*)?)
```

Exception handling. Evaluates body forms, catching any exceptions.

### Examples

```fol
(try
  (risky-operation)
  (catch e
    (print (str "Error: " e))
    :error)
  (finally
    (cleanup)))
```

---

## syntax-quote                                                   *[special form]*

```
`form
(syntax-quote form)
```

Quasiquote syntax for building code templates. Supports:
- `~` (unquote): evaluate and insert
- `~@` (unquote-splicing): evaluate and splice into list
- `#` suffix (auto-gensym): generate unique symbol

### Examples

```fol
(def x 42)
`(a ~x c)                 ; => (a 42 c)

(def xs [1 2 3])
`(a ~@xs b)               ; => (a 1 2 3 b)

`(bind [x# 1] x#)         ; => (bind [G123 1] G123)
```

---

## make-dynamic                                                   *[special form]*

```
(make-dynamic name)
(make-dynamic name initial-value)
```

Creates a dynamic variable with the given name and optional initial value.

### Examples

```fol
(def *debug* (make-dynamic *debug* false))
(def *output* (make-dynamic *output* nil))
```

---

## binding                                                        *[special form]*

```
(binding [bindings] body*)
```

Temporarily rebinds dynamic variables for the duration of body evaluation.

### Examples

```fol
(def *debug* (make-dynamic *debug* false))

(binding [*debug* true]
  (when *debug*
    (print "Debug mode enabled"))
  (do-something))

*debug*                   ; => false (restored)
```

---

## lazy-seq                                                       *[special form]*

```
(lazy-seq body)
```

Creates a lazy sequence that delays evaluation of body until realized.
The body should return a cons pair or nil.

### Examples

```fol
;; Infinite sequence of integers
(defn integers [n]
  (lazy-seq (cons n (integers (+ n 1)))))

(take 5 (integers 0))     ; => (0 1 2 3 4)
```

---

## -> (thread-first)                                                       *[macro]*

```
(-> x form*)
```

Threads value `x` through each form as the **first** argument.

### Examples

```fol
(-> 5
    (+ 3)
    (* 2))
; Expands to: (* (+ 5 3) 2)
; => 16

(-> {:a 1 :b 2}
    (assoc :c 3)
    keys)
```

---

## ->> (thread-last)                                                       *[macro]*

```
(->> x form*)
```

Threads value `x` through each form as the **last** argument.

### Examples

```fol
(->> [1 2 3 4 5]
     (filter odd?)
     (map (fn [x] (* x x)))
     (reduce +))
; => 35
```

---

## defgeneric                                                              *[macro]*

```
(defgeneric name [lambda-list] option*)
```

Defines a generic function with the given name and lambda list.

### Examples

```fol
(defgeneric area [shape]
  (:documentation "Calculate the area of a shape."))
```

---

## defclass                                                                *[macro]*

```
(defclass name [superclasses] [slots] option*)
```

Defines a persistent class with the given name, superclasses, and slots.
All FOL classes implicitly inherit from `<persistent-object>` and use the
`persistent-class` metaclass.  A `make-<name>` keyword constructor is
automatically generated.

### Slot Specification

Each slot can be a bare symbol or a vector with keyword options:

```
[slot-name :initarg :keyword :accessor accessor-fn]
```

### Options

| Option | Values | Description |
|--------|--------|-------------|
| `:abstract` | truthy / falsy | Prevents direct instantiation. Subclasses may still be instantiated. Enforced at **runtime**. |
| `:sealed` | truthy / falsy | Prevents use as a superclass. Enforced at **compile time**. |

Both options treat `false` and `nil` as falsy; any other value (including `true`) is truthy.

### Examples

```fol
;;; Basic class
(defclass <point> []
  [[x :initarg :x :accessor point-x]
   [y :initarg :y :accessor point-y]])

(bind [p (make-<point> :x 3 :y 4)]
  (point-x p))                          ; => 3

;;; Abstract base class — cannot be instantiated directly
(defclass <shape> [] [] :abstract true)

(defclass <circle> [<shape>]
  [[radius :initarg :radius :accessor circle-radius]])

(make-<shape>)                          ; ERROR: Cannot instantiate abstract class <SHAPE>
(make-<circle> :radius 5)              ; => ok

;;; Sealed class — cannot be used as a superclass
(defclass <value-type> []
  [[val :initarg :val]] :sealed true)

(defclass <sub> [<value-type>] [])      ; COMPILER ERROR: <sub> inherits from sealed class

;;; Combined: abstract and sealed
(defclass <abstract-sealed> [] [] :abstract true :sealed true)
```

---

## defmethod                                                               *[macro]*

```
(defmethod name qualifier* [specialized-lambda-list] body*)
```

Defines a method on a generic function.

### Examples

```fol
(defmethod area [(shape <circle>)]
  (* pi (expt (circle-radius shape) 2)))
```

---

## definline                                                               *[macro]*

```
(definline name [params] body)
```

Defines an inline function. The body is substituted at call sites during
macro expansion, which can improve performance for small functions.
Unlike Common Lisp's definline, this supports variadic and destructuring arguments.

### Examples

```fol
(definline square [x]
  (* x x))

(square 5)                ; expands to (* 5 5) => 25

;; With destructuring
(definline add-point [[x1 y1] [x2 y2]]
  [(+ x1 x2) (+ y1 y2)])

;; With variadic args
(definline sum-all [& nums]
  (reduce + 0 nums))
```

---

## trampoline                                                           *[function]*

```
(trampoline f & args)
```

Used for mutual recursion without stack overflow. Calls f with args and
repeatedly calls the result if it's a function, until a non-function value
is returned.

### Examples

```fol
;; Mutual recursion that would overflow without trampoline
(defn my-even? [n]
  (if (= n 0)
      true
      (fn [] (my-odd? (dec n)))))

(defn my-odd? [n]
  (if (= n 0)
      false
      (fn [] (my-even? (dec n)))))

(trampoline my-even? 1000000)  ; => true (no stack overflow)
```
