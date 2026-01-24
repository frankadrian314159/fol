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
