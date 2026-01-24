# Sequence Operations

Higher-order functions for processing sequences and collections.

## reduce

```
(reduce f coll)
(reduce f init coll)
```

Reduces a collection to a single value by repeatedly applying function `f`.

With two arguments, uses the first element of `coll` as the initial accumulator value.
With three arguments, uses `init` as the initial accumulator value.

The function `f` is called as `(f accumulator element)` for each element in `coll`.

Works with any collection that supports `seq`: vectors, lists, dicts, sets, bags, strings.

### Examples

```fol
;; Sum numbers
(reduce + [1 2 3 4])              ; => 10
(reduce + 0 [1 2 3 4])            ; => 10

;; With initial value
(reduce + 100 [1 2 3])            ; => 106

;; Multiply
(reduce * 1 [2 3 4])              ; => 24

;; String concatenation
(reduce str "" ["a" "b" "c"])     ; => "abc"

;; Build a collection
(reduce (fn [acc x] (conj acc (* x 2)))
        []
        [1 2 3])                  ; => [2 4 6]

;; With FOL function
(reduce (fn [acc x] (+ acc x)) 0 [1 2 3 4])  ; => 10

;; On a dict (pairs as (key . value))
(reduce (fn [acc pair] (+ acc (rest pair)))
        0
        {:a 1 :b 2 :c 3})         ; => 6

;; On a set
(reduce + 0 #{1 2 3})             ; => 6

;; On a string (characters)
(reduce (fn [acc _] (+ acc 1)) 0 "hello")  ; => 5

;; Empty collection with init returns init
(reduce + 42 [])                  ; => 42

;; Single element without init
(reduce + [42])                   ; => 42
```

---

## map

```
(map f coll)
```

Applies function `f` to each element of `coll`, returning a list of results.

Works with any collection that supports `seq`: vectors, lists, dicts, sets, bags, strings.

### Examples

```fol
;; Double each number
(map (fn [x] (* x 2)) [1 2 3])    ; => (2 4 6)

;; With built-in function
(map abs [-1 -2 -3])              ; => (1 2 3)

;; Transform strings
(map (fn [s] (str "Hello, " s)) ["World" "FOL"])
                                  ; => ("Hello, World" "Hello, FOL")

;; On a FOL list
(map (fn [x] (+ x 1)) (list 1 2 3))  ; => (2 3 4)

;; On a string (returns list of characters)
(map identity "abc")              ; => (#\a #\b #\c)

;; Empty collection
(map identity [])                 ; => ()

;; Extract from maps
(map (fn [pair] (first pair)) {:a 1 :b 2})  ; => (:a :b) or (:b :a)
```

---

## filter

```
(filter pred coll)
```

Returns a list of elements from `coll` for which predicate `pred` returns a truthy value.

Works with any collection that supports `seq`: vectors, lists, dicts, sets, bags, strings.

### Examples

```fol
;; Keep odd numbers
(filter odd? [1 2 3 4 5])         ; => (1 3 5)

;; Keep positive numbers
(filter positive? [-2 -1 0 1 2])  ; => (1 2)

;; With FOL predicate
(filter (fn [x] (> x 2)) [1 2 3 4 5])  ; => (3 4 5)

;; No matches returns empty list
(filter negative? [1 2 3])        ; => ()

;; All match returns all elements
(filter positive? [1 2 3])        ; => (1 2 3)

;; Empty collection
(filter identity [])              ; => ()

;; Filter dict entries (pairs as (key . value))
(filter (fn [pair] (positive? (rest pair)))
        {:a 1 :b -2 :c 3})        ; pairs where value is positive

;; Composing with map
(map (fn [x] (* x 2))
     (filter odd? [1 2 3 4 5]))   ; => (2 6 10)
```

---

## Composition

These functions compose naturally for data processing pipelines.

```fol
;; Process a list of numbers
(reduce +
  (map (fn [x] (* x x))
    (filter positive? [-2 -1 0 1 2 3])))  ; => 14 (1 + 4 + 9)

;; Thread-first makes pipelines readable
(-> [1 2 3 4 5 6 7 8 9 10]
    (filter even?)               ; (2 4 6 8 10)
    (map (fn [x] (* x x)))       ; (4 16 36 64 100)
    (reduce +))                  ; 220
```

---

## Implementation Notes

These functions are implemented using `seq` to provide a uniform view of any collection:

- `reduce` iterates through the seq using `first` and `rest`
- `map` and `filter` are built on top of `reduce`, collecting results
- All functions work with any type that implements the `seq` protocol
- Results from `map` and `filter` are always returned as FOL lists
