# Control Flow

## if

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

## when

```
(when test form0 form1 ... formN)
```

Evaluates `test`. If truthy, evaluates all forms in order and returns the value
of the last form. If falsy, returns nil without evaluating any forms.

This is a macro that expands to `(if test (do form0 form1 ... formN) nil)`.

### Examples

```fol
(when true
  (print "hello")
  42)                     ; prints "hello", returns 42

(when false
  (print "hello")
  42)                     ; returns nil, nothing printed

(when (> x 0)
  (print "positive")
  x)                      ; if x > 0, prints "positive" and returns x

;; Useful for side effects when a condition is true
(when (empty? errors)
  (save-data data)
  (print "Saved successfully"))
```

---

## unless

```
(unless test form0 form1 ... formN)
```

Evaluates `test`. If falsy, evaluates all forms in order and returns the value
of the last form. If truthy, returns nil without evaluating any forms.

This is a macro that expands to `(if test nil (do form0 form1 ... formN))`.

### Examples

```fol
(unless false
  (print "hello")
  42)                     ; prints "hello", returns 42

(unless true
  (print "hello")
  42)                     ; returns nil, nothing printed

(unless (> x 0)
  (print "non-positive")
  0)                      ; if x <= 0, prints "non-positive" and returns 0

;; Useful for error handling when a condition is false
(unless (valid? input)
  (log-error "Invalid input")
  (throw-error "validation failed"))
```

---

## do

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

## bind

```
(bind [bindings] body...)
```

Creates local bindings and evaluates body forms. Bindings are pairs of pattern and value.
Supports destructuring.

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

## cond

```
(cond test1 form1 test2 form2 ... testN formN)
```

Evaluates test/form pairs in order. When a test evaluates to a truthy value,
evaluates and returns the corresponding form. If no test is truthy, returns nil.

Requires an even number of arguments (test/form pairs).

### Examples

```fol
(cond
  (< x 0) :negative
  (= x 0) :zero
  (> x 0) :positive)      ; returns based on value of x

(cond
  false :never
  nil :also-never
  true :always)           ; => :always

;; Default case using t
(cond
  (= n 1) :one
  (= n 2) :two
  t :other)               ; returns :other if n is not 1 or 2

;; No match returns nil
(cond
  false :a
  nil :b)                 ; => nil
```

---

## case

```
(case target-form
  target1 form1
  target2 form2
  ...
  [default-form])
```

Evaluates `target-form` to get a value, then matches against targets.
Each target can be an atom (number, string, keyword, symbol) or a vector of atoms.
When matched, evaluates and returns the corresponding form.

If no match is found:
- If a default form is provided (odd number of remaining args), evaluates and returns it
- Otherwise, signals an error

Duplicate targets cause an error at evaluation time.

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
  [1 2 3 4 5] :weekday)   ; 0 or 6 => :weekend, 1-5 => :weekday

;; String keys
(case major
  "engineering" (values 60000 :engineering)
  "business" (values 90000 :management)
  (values 20000 :production))  ; default

;; Game of Life neighbor rule
(case neighbor-count
  [0 1] :dies             ; underpopulation
  2 :survives             ; stable
  3 :births               ; reproduction
  [4 5 6 7 8] :dies)      ; overpopulation

;; No default - signals error if no match
(case status
  :active :process
  :pending :queue)        ; error if status is neither

;; Evaluates target expression
(case (+ 1 2)
  1 :one
  2 :two
  3 :three)               ; => :three
```

---

## fn

```
(fn [params] body...)
(fn name [params] body...)
```

Creates an anonymous function. Optionally, a name can be provided for recursion.

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
```

---

## def

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

## defn

```
(defn name [params] body...)
(defn name
  ([params1] body1...)
  ([params2] body2...)
  ...)
```

Defines a named function. Sugar for `(def name (fn name [params] body...))`.

### Single Pattern

For simple functions with fixed parameters:

```fol
(defn double [x]
  (* x 2))

(defn add [a b]
  (+ a b))

(defn greet [name]
  (str "Hello, " name "!"))
```

### Multi-Pattern Dispatch

For functions that accept different arities or patterns, provide multiple clauses:

```fol
;; Different arities
(defn greet
  ([name] (str "Hello, " name "!"))
  ([greeting name] (str greeting ", " name "!")))

(greet "World")           ; => "Hello, World!"
(greet "Hi" "Alice")      ; => "Hi, Alice!"

;; Multiple arities for numeric functions
(defn add-all
  ([x] x)
  ([x y] (+ x y))
  ([x y z] (+ x y z)))

(add-all 5)               ; => 5
(add-all 3 4)             ; => 7
(add-all 1 2 3)           ; => 6
```

### Pattern-Based Dispatch

Patterns can distinguish between simple parameters and destructuring patterns:

```fol
;; [x] matches any single argument
;; [[a b]] matches a single argument that IS a 2-element sequence
(defn process
  ([x] x)                         ; catches non-sequences
  ([[a b]] (+ a b)))              ; destructures pairs

(process 42)              ; => 42
(process [3 4])           ; => 7
```

More specific patterns (expecting sequences) are tried before catch-all patterns.

```fol
(defn classify
  ([x] :single)
  ([[a b]] :pair)
  ([[a b c]] :triple))

(classify 42)             ; => :single
(classify [1 2])          ; => :pair
(classify [1 2 3])        ; => :triple
```

### With Rest Parameters

Multi-pattern defn supports rest parameters:

```fol
(defn variadic
  ([x] x)
  ([x y & more] (+ x y (reduce + 0 more))))

(variadic 5)              ; => 5
(variadic 3 4)            ; => 7
(variadic 1 2 3 4 5)      ; => 15
```

### With Destructuring

All patterns support full destructuring:

```fol
(defn process-point
  ([[x y]] (str "2D: " x ", " y))
  ([[x y z]] (str "3D: " x ", " y ", " z)))

(defn handle-response
  ([{:keys [status body]}]
   (if (= status 200)
       body
       (throw (str "Error: " status)))))
```

---

## defmacro

```
(defmacro name [params] body...)
```

Defines a macro. Macros receive unevaluated forms and return a new form to evaluate.

### Examples

```fol
;; Simple macro
(defmacro unless [test & body]
  `(if (not ~test) (do ~@body)))

(unless false (print "executed"))  ; prints "executed"

;; With destructuring
(defmacro with-point [[x y] & body]
  `(bind [x ~x y ~y] ~@body))

(with-point [3 4]
  (+ x y))                ; => 7
```
