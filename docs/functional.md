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
