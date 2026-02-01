# Functional Programming

Higher-order functions for functional programming.

## identity                                                             *[function]*

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

## complement                                                           *[function]*

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

## disjoin                                                              *[function]*

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

## conjoin                                                              *[function]*

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

## partial                                                              *[function]*

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

## rpartial                                                             *[function]*

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

## juxt                                                                 *[function]*

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

---

## constantly                                                           *[function]*

```
(constantly x)
```

Returns a function that takes any number of arguments and always returns x.
Useful when you need a function that ignores its arguments.

### Examples

```fol
(def always-42 (constantly 42))
(always-42)                   ; => 42
(always-42 1 2 3 :ignored)    ; => 42

;; Useful with map to fill a sequence
(map (constantly :default) [1 2 3])  ; => (:default :default :default)

;; Or as a default function
(def get-value-or-default
  (fn [m k default-fn]
    (or (get m k) (default-fn))))
(get-value-or-default {:a 1} :b (constantly 0))  ; => 0
```

---

## comp                                                                 *[function]*

```
(comp f1 f2 ... fn)
```

Takes a set of functions and returns a function that is the composition of those functions.
The returned function applies the rightmost function first, then applies the next function
(right-to-left) to the result, and so on.

With no arguments, returns identity.

### Examples

```fol
;; Compose two functions
(def inc-then-double (comp (fn [x] (* x 2)) inc))
(inc-then-double 5)           ; => 12 ((* (inc 5) 2) = (* 6 2))

;; Compose three functions
((comp inc inc inc) 0)        ; => 3

;; Apply multiple transformations to strings
(def clean-string (comp trim lower-case))
(clean-string "  HELLO  ")    ; => "hello"

;; No functions returns identity
((comp) x)                    ; => x

;; Rightmost function can take multiple args
((comp inc +) 1 2 3)          ; => 7 (inc (+ 1 2 3))
```

---

## memoize                                                              *[function]*

```
(memoize f)
```

Returns a memoized version of a referentially transparent function.
The memoized function keeps a cache of the mapping from arguments to results.
When calls with the same arguments are repeated, the cached result is returned
without calling f again.

Useful for expensive computations with repeated calls.

### Examples

```fol
;; Memoize a slow function
(def slow-fib
  (fn [n]
    (if (<= n 1)
        n
        (+ (slow-fib (- n 1)) (slow-fib (- n 2))))))

(def fast-fib (memoize slow-fib))
(fast-fib 35)                 ; Much faster on repeated calls

;; Works with multiple arguments
(def expensive-compute (memoize
  (fn [x y]
    (print "computing...")
    (+ x y))))
(expensive-compute 1 2)       ; prints "computing...", returns 3
(expensive-compute 1 2)       ; returns 3 (no print - cached)
(expensive-compute 2 3)       ; prints "computing...", returns 5
```

---

## fnil                                                                 *[function]*

```
(fnil f default1 & more-defaults)
```

Takes a function f and returns a function that calls f, replacing nil arguments
with the corresponding defaults. The first argument is replaced with default1
if nil, the second with the second default if nil, etc.

Useful for providing default values to functions.

### Examples

```fol
;; Replace nil first argument with 0
(def safe-add (fnil + 0))
(safe-add nil 10)             ; => 10 (+ 0 10)
(safe-add 5 10)               ; => 15 (+ 5 10)

;; Multiple defaults
(def safe-sub (fnil - 0 0))
(safe-sub nil nil)            ; => 0 (- 0 0)
(safe-sub 10 nil)             ; => 10 (- 10 0)
(safe-sub nil 5)              ; => -5 (- 0 5)

;; Useful with update
(def counts {:a 1})
(update counts :b (fnil inc 0))  ; => {:a 1 :b 1}
;; Without fnil: (update counts :b inc) would fail because (inc nil) errors
```

---

## fn?                                                                  *[function]*

```
(fn? x)
```

Returns true if x is a function (FOL function, macro, or Common Lisp function).

### Examples

```fol
(fn? +)                       ; => true
(fn? (fn [x] x))              ; => true
(fn? inc)                     ; => true
(fn? 42)                      ; => false
(fn? "hello")                 ; => false
(fn? :keyword)                ; => false
```

---

## trampoline                                                           *[function]*

```
(trampoline f & args)
```

Useful for converting algorithms requiring mutual recursion without stack consumption.
Calls f with supplied args. If f returns a function, calls that function with no arguments.
Continues calling returned functions until a non-function value is returned.

This allows deep mutual recursion without stack overflow.

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

;; Simple use - function that doesn't return a function
(trampoline + 1 2 3)          ; => 6
```
