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

---

## quote

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

## syntax-quote

```
`form
(syntax-quote form)
```

Quasiquote syntax for building code templates. Unlike `quote`, allows selective evaluation
using `~` (unquote) and `~@` (unquote-splicing). Also supports auto-gensym with `#` suffix.

### Unquote (~)

Evaluates the form and inserts the result:

```fol
(def x 42)
`(a ~x c)                 ; => (a 42 c)

(def name 'foo)
`(def ~name 10)           ; => (def foo 10)
```

### Unquote-splicing (~@)

Evaluates the form (must return a sequence) and splices elements into the list:

```fol
(def xs [1 2 3])
`(a ~@xs b)               ; => (a 1 2 3 b)

(def args ['x 'y])
`(fn ~args body)          ; => (fn [x y] body)
```

### Auto-gensym (#)

Symbols ending with `#` generate unique symbols, consistent within the same syntax-quote:

```fol
`(bind [x# 1] x#)         ; => (bind [G123 1] G123) - same gensym for both x#

;; Useful for hygienic macros
(defmacro with-temp [& body]
  `(bind [temp# (create-temp)]
     (try
       ~@body
       (finally (cleanup temp#)))))
```

### Complete Example

```fol
;; Macro using all features
(defmacro when-let [[var expr] & body]
  `(bind [result# ~expr]
     (when result#
       (bind [~var result#]
         ~@body))))

(when-let [x (get-value)]
  (print x)
  (* x 2))
```

---

## loop

```
(loop [bindings] body*)
```

Establishes a recursion point with initial bindings. Use `recur` to jump back
to the loop with new values. This is FOL's primary iteration construct.

### Examples

```fol
;; Simple countdown
(loop [n 5]
  (if (= n 0)
      "done"
      (do
        (print n)
        (recur (- n 1)))))    ; prints 5, 4, 3, 2, 1, returns "done"

;; Sum numbers from 1 to n
(loop [i 1
       sum 0]
  (if (> i 10)
      sum
      (recur (+ i 1) (+ sum i))))  ; => 55

;; Factorial using loop
(defn factorial [n]
  (loop [i n
         acc 1]
    (if (<= i 1)
        acc
        (recur (- i 1) (* acc i)))))

(factorial 5)             ; => 120

;; Process a list
(loop [items [1 2 3 4 5]
       result []]
  (if (empty? items)
      result
      (recur (rest items)
             (conj result (* (first items) 2)))))
; => [2 4 6 8 10]
```

---

## recur

```
(recur arg*)
```

Jumps back to the enclosing `loop` with new values for the bindings.
The number of arguments must match the number of loop bindings.

`recur` must be in tail position (the last expression evaluated).

### Examples

```fol
;; recur with multiple bindings
(loop [a 0
       b 1
       n 10]
  (if (= n 0)
      a
      (recur b (+ a b) (- n 1))))  ; => 55 (10th Fibonacci number)

;; Building a result
(loop [nums [1 2 3 4 5]
       evens []]
  (if (empty? nums)
      evens
      (let [x (first nums)]
        (recur (rest nums)
               (if (even? x)
                   (conj evens x)
                   evens)))))
; => [2 4]
```

---

## throw

```
(throw value)
```

Throws an exception with the given value. The value is typically a string
describing the error. Use `try`/`catch` to handle thrown exceptions.

### Examples

```fol
(throw "Something went wrong")

(defn divide [a b]
  (if (= b 0)
      (throw "Division by zero")
      (/ a b)))

(defn validate [x]
  (when (< x 0)
    (throw (str "Invalid value: " x))))
```

---

## try

```
(try
  body*
  (catch var body*)
  (finally body*)?)
```

Exception handling construct. Evaluates body forms, catching any exceptions.
If an exception occurs and a `catch` clause is present, binds the exception
message to `var` and evaluates the catch body. The `finally` clause (optional)
is always executed, whether or not an exception occurred.

### Examples

```fol
;; Basic try/catch
(try
  (risky-operation)
  (catch e
    (print (str "Error: " e))
    :error))

;; With finally
(try
  (def file (open-file "data.txt"))
  (process file)
  (catch e
    (log-error e)
    nil)
  (finally
    (close file)))

;; Catching thrown exceptions
(try
  (when (invalid? input)
    (throw "Invalid input"))
  (process input)
  (catch msg
    (str "Failed: " msg)))

;; Nested try blocks
(try
  (try
    (dangerous-op)
    (catch e
      (throw (str "Inner error: " e))))
  (catch e
    (str "Outer caught: " e)))
```

---

## make-dynamic

```
(make-dynamic name)
(make-dynamic name initial-value)
```

Creates a dynamic variable with the given name and optional initial value.
Dynamic variables provide thread-local-like rebinding via `binding`.
The name is not evaluated (like `def`).

### Examples

```fol
;; Create dynamic variables
(def *debug* (make-dynamic *debug* false))
(def *output* (make-dynamic *output* nil))
(def *indent* (make-dynamic *indent* 0))

;; Access the value (auto-dereferenced)
*debug*                   ; => false
```

---

## binding

```
(binding [bindings] body*)
```

Temporarily rebinds dynamic variables for the duration of body evaluation.
Bindings are pairs: `[dvar1 val1 dvar2 val2 ...]`.
Original values are restored after body executes (even if an error occurs).

### Examples

```fol
(def *debug* (make-dynamic *debug* false))

;; Temporarily enable debugging
(binding [*debug* true]
  (when *debug*
    (print "Debug mode enabled"))
  (do-something))

*debug*                   ; => false (restored)

;; Multiple bindings
(def *indent* (make-dynamic *indent* 0))
(def *prefix* (make-dynamic *prefix* ""))

(defn log [msg]
  (print (str *prefix* (repeat-str " " *indent*) msg)))

(binding [*indent* 2
          *prefix* "[INFO] "]
  (log "Starting process")
  (binding [*indent* 4]
    (log "Nested operation"))
  (log "Done"))

;; Output:
;; [INFO]   Starting process
;; [INFO]     Nested operation
;; [INFO]   Done

;; Dynamic scope flows through function calls
(defn inner []
  (print *debug*))

(defn outer []
  (binding [*debug* true]
    (inner)))             ; prints true

(outer)
```

---

## lazy-seq

```
(lazy-seq body)
```

Creates a lazy sequence that delays evaluation of body until realized.
The body should return either:
- A cons pair `(cons head tail)` where tail is another seq or nil
- `nil` for end of sequence

Lazy sequences enable infinite sequences and avoid computing elements
until they're needed.

### Examples

```fol
;; Infinite sequence of integers starting from n
(defn integers [n]
  (lazy-seq (cons n (integers (+ n 1)))))

(first (integers 0))      ; => 0
(first (rest (integers 0))) ; => 1

;; Take first n elements
(defn take [n s]
  (if (or (= n 0) (empty? s))
      ()
      (cons (first s) (take (- n 1) (rest s)))))

(take 5 (integers 0))     ; => (0 1 2 3 4)

;; Infinite Fibonacci sequence
(defn fibs []
  (defn fib-seq [a b]
    (lazy-seq (cons a (fib-seq b (+ a b)))))
  (fib-seq 0 1))

(take 10 (fibs))          ; => (0 1 1 2 3 5 8 13 21 34)

;; Lazy filter
(defn lazy-filter [pred s]
  (lazy-seq
    (when-let [x (first s)]
      (if (pred x)
          (cons x (lazy-filter pred (rest s)))
          (lazy-filter pred (rest s))))))

;; Only computes what's needed
(take 5 (lazy-filter even? (integers 0)))
; => (0 2 4 6 8)
```

---

## -> (thread-first)

```
(-> x form*)
```

Threads value `x` through each form as the **first** argument.
For each form, `x` becomes the first argument (after the function).
If a form is a bare symbol, it's called as a function with `x` as the only argument.

### Examples

```fol
;; Basic threading
(-> 5
    (+ 3)
    (* 2))
; Expands to: (* (+ 5 3) 2)
; => 16

;; With bare symbols
(-> "hello"
    upper-case
    reverse)
; Expands to: (reverse (upper-case "hello"))
; => "OLLEH"

;; Collection operations
(-> {:a 1 :b 2 :c 3}
    (assoc :d 4)
    (dissoc :a)
    keys)
; => (:b :c :d)

;; Nested data access
(-> person
    :address
    :city
    upper-case)

;; No forms returns value unchanged
(-> 42)                   ; => 42
```

---

## ->> (thread-last)

```
(->> x form*)
```

Threads value `x` through each form as the **last** argument.
For each form, `x` becomes the last argument.
If a form is a bare symbol, it's called as a function with `x` as the only argument.

### Examples

```fol
;; Basic threading
(->> 5
     (+ 3)
     (* 2))
; Expands to: (* 2 (+ 3 5))
; => 16

;; Collection processing pipeline
(->> [1 2 3 4 5]
     (filter odd?)
     (map (fn [x] (* x x)))
     (reduce +))
; => 35 (1 + 9 + 25)

;; String processing
(->> ["a" "b" "c"]
     (map upper-case)
     (interpose "-")
     (reduce str))
; => "A-B-C"

;; With range
(->> (range 10)
     (filter even?)
     (map (fn [x] (* x 2)))
     (take 3))
; => (0 4 8)
```

### Choosing Between -> and ->>

Use `->` when working with:
- Objects/records (first arg is usually the object)
- Nested data access
- Builder patterns

Use `->>` when working with:
- Collections (last arg is usually the collection)
- Sequence pipelines
- Functional transformations
