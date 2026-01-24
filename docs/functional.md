# Functional Programming

Higher-order functions for functional programming.

## identity

```
(identity x)
```

Returns x unchanged. Useful as a placeholder function or when a function is required but no transformation is needed.

### Examples

```fol
(identity 42)         ; => 42
(identity "hello")    ; => "hello"
(identity [1 2 3])    ; => [1 2 3]

;; Useful as a default transformation
(map identity [1 2 3])  ; => (1 2 3)
```

---

## complement

```
(complement f)
```

Takes a function f and returns a new function that takes the same arguments as f,
but returns the logical complement (negation) of f's result.

### Examples

```fol
;; Create a predicate for even numbers
(def even? (complement odd?))
(even? 4)                     ; => true
(even? 3)                     ; => false

;; Use with comparison functions
((complement >) 3 5)          ; => true (because (> 3 5) is false)
((complement =) 1 2)          ; => true (because (= 1 2) is false)

;; Useful for filtering
(def not-empty? (complement empty?))
(not-empty? [1 2 3])          ; => true
(not-empty? [])               ; => false
```

---

## disjoin

```
(disjoin predicate1 & more-predicates)
```

Returns a single function that is the disjunction (OR) of the predicate functions.
The returned function accepts any number of arguments and applies the predicates in order.
If any predicate returns a truthy value, the remaining predicates are not applied and
that truthy value is returned. If all predicates return falsy values, nil is returned.

A disjunction is similar to an `or` expression of calls to the predicates.

### Examples

```fol
;; Check if a number is either positive or zero
(def non-negative? (disjoin positive? zero?))
(non-negative? 5)             ; => true
(non-negative? 0)             ; => true
(non-negative? -3)            ; => nil

;; First truthy value is returned
(def find-type (disjoin
                 (fn [x] (if (<string>? x) :string nil))
                 (fn [x] (if (<integer>? x) :integer nil))
                 (fn [x] (if (<float>? x) :float nil))))
(find-type "hello")           ; => :string
(find-type 42)                ; => :integer
(find-type 3.14)              ; => :float

;; Empty disjoin returns a function that always returns nil
((disjoin) x)                 ; => nil
```

---

## conjoin

```
(conjoin predicate1 & more-predicates)
```

Returns a single function that is the conjunction (AND) of the predicate functions.
The returned function accepts any number of arguments and applies the predicates in order.
If any predicate returns nil, the remaining predicates are not applied and nil is
immediately returned. If all predicates return truthy values, the result of the last
predicate is returned.

A conjunction is similar to an `and` expression of calls to the predicates.

### Examples

```fol
;; Check if a number is both positive and even
(def positive-even? (conjoin positive? even?))
(positive-even? 4)            ; => true
(positive-even? 3)            ; => nil (odd)
(positive-even? -4)           ; => nil (negative)

;; Short-circuits on first nil
(def check-all (conjoin
                 (fn [x] (print "checking first") true)
                 (fn [x] nil)
                 (fn [x] (print "never reached") true)))
(check-all 1)                 ; prints "checking first", returns nil

;; Returns last value when all truthy
(def get-last (conjoin
                (fn [x] :first)
                (fn [x] :second)
                (fn [x] :last)))
(get-last 1)                  ; => :last

;; Empty conjoin returns a function that always returns true
((conjoin) x)                 ; => true

;; Validate multiple conditions
(def valid-user? (conjoin
                   (fn [u] (get u :name))
                   (fn [u] (get u :email))
                   (fn [u] (positive? (get u :age)))))
(valid-user? {:name "Alice" :email "a@b.com" :age 25})  ; => true
(valid-user? {:name "Bob" :age -5})                      ; => nil
```

---

## partial

```
(partial f & args)
```

Takes a function f and some arguments, returning a new function that, when called,
invokes f with the original args prepended to the new args. This is left-to-right
partial application.

### Examples

```fol
;; Create a function that adds 10 to its argument
(def add10 (partial + 10))
(add10 5)                     ; => 15
(add10 1 2 3)                 ; => 16 (+ 10 1 2 3)

;; Create a specialized comparison
(def at-least-5? (partial <= 5))
(at-least-5? 7)               ; => true  ((<= 5 7))
(at-least-5? 3)               ; => false ((<= 5 3))

;; Works with FOL functions
(def greet (fn [greeting name] (str greeting ", " name "!")))
(def say-hello (partial greet "Hello"))
(say-hello "World")           ; => "Hello, World!"

;; No bound args returns the function unchanged
((partial +) 1 2 3)           ; => 6
```

---

## rpartial

```
(rpartial f & args)
```

Takes a function f and some arguments, returning a new function that, when called,
invokes f with the new args prepended to the original args. This is right-to-left
partial application - the bound args are appended to the end.

### Examples

```fol
;; Create a function that subtracts 10 from its argument
(def sub10 (rpartial - 10))
(sub10 15)                    ; => 5  ((- 15 10))
(sub10 5)                     ; => -5 ((- 5 10))

;; Contrast with partial
(def partial-sub (partial - 10))
(def rpartial-sub (rpartial - 10))
(partial-sub 3)               ; => 7  ((- 10 3))
(rpartial-sub 3)              ; => -7 ((- 3 10))

;; Useful for division with a fixed divisor
(def halve (rpartial / 2))
(halve 10)                    ; => 5
(halve 7)                     ; => 7/2

;; Works with FOL functions
(def log-with-level (fn [level msg] (str "[" level "] " msg)))
(def log-info (rpartial log-with-level "INFO"))
(log-info "Server started")   ; => "[Server started] INFO"
;; Oops! For this use case, partial is better:
(def log-info (partial log-with-level "INFO"))
(log-info "Server started")   ; => "[INFO] Server started"
```

---

## juxt

```
(juxt f1 f2 ... fn)
```

Takes multiple functions and returns a new function that, when called, applies
each function to the arguments and returns the results as multiple values.

This is useful for computing multiple values from the same input in a single pass.

### Examples

```fol
;; Get multiple statistics at once
(def stats (juxt min max))
(stats 3 1 4 1 5 9 2 6)       ; => (values 1 9)

;; Apply arithmetic operations
(def arith (juxt + - *))
(arith 6 2)                   ; => (values 8 4 12)

;; Extract multiple properties
(def name-and-age (juxt :name :age))
(name-and-age {:name "Alice" :age 30 :city "NYC"})  ; => (values "Alice" 30)

;; Works with FOL functions
(def transforms (juxt
                  (fn [x] (* x 2))
                  (fn [x] (+ x 1))
                  (fn [x] (* x x))))
(transforms 5)                ; => (values 10 6 25)

;; Empty juxt returns no values
((juxt) 1 2 3)                ; => (values)

;; Practical: check multiple conditions and return results
(def validate (juxt
                (fn [x] (if (positive? x) :positive :not-positive))
                (fn [x] (if (even? x) :even :odd))))
(validate 4)                  ; => (values :positive :even)
(validate -3)                 ; => (values :not-positive :odd)
```
