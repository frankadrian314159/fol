# Sequence Operations

Higher-order functions for processing sequences and collections. All sequence functions work with any collection that supports `seq`: vectors, lists, dicts, sets, bags, strings, and lazy-seqs.

## reduce

```
(reduce f)
(reduce f coll)
(reduce f init coll)
```

Multi-arity function for reducing collections.

### Transducer Form (1 argument)

With one argument, returns a **transducer** that applies `f` (as a unary function) to each
element before passing to the reducing function. This is equivalent to `(map f)` as a transducer.

```fol
;; Create a transducer that increments each element
(def inc-xf (reduce (fn [x] (+ x 1))))

;; Transducers can be composed and applied via transduce
(transduce inc-xf + 0 [1 2 3])    ; => 9 (sums 2+3+4)
```

### Reduction Forms (2-3 arguments)

With two arguments, reduces `coll` using `f` as a binary reducing function,
using the first element as the initial accumulator value.

With three arguments, uses `init` as the initial accumulator value.

The function `f` is called as `(f accumulator element)` for each element in `coll`.

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

;; On a dict (pairs as (key . value))
(reduce (fn [acc pair] (+ acc (rest pair)))
        0
        {:a 1 :b 2 :c 3})         ; => 6

;; Empty collection with init returns init
(reduce + 42 [])                  ; => 42

;; Single element without init
(reduce + [42])                   ; => 42
```

---

## map

```
(map f)
(map f coll)
```

Applies function `f` to each element of a collection.

### Transducer Form (1 argument)

With one argument, returns a **transducer** that applies `f` to each element.

```fol
;; Create a transducer that doubles each element
(def double-xf (map (fn [x] (* x 2))))
```

### Collection Form (2 arguments)

With two arguments, returns a **lazy sequence** of `(f elem)` for each element in `coll`.

### Examples

```fol
;; Double each number (returns lazy-seq)
(map (fn [x] (* x 2)) [1 2 3])    ; => lazy-seq: 2, 4, 6

;; With built-in function
(map abs [-1 -2 -3])              ; => lazy-seq: 1, 2, 3

;; Transform strings
(map (fn [s] (str "Hello, " s)) ["World" "FOL"])
                                  ; => lazy-seq: "Hello, World", "Hello, FOL"

;; On a string (returns lazy-seq of characters)
(map identity "abc")              ; => lazy-seq: #\a, #\b, #\c

;; Empty collection
(map identity [])                 ; => empty lazy-seq

;; Realize results with reduce
(reduce + 0 (map (fn [x] (* x x)) [1 2 3]))  ; => 14
```

---

## filter

```
(filter pred)
(filter pred coll)
```

Returns elements for which predicate returns truthy.

### Transducer Form (1 argument)

With one argument, returns a **transducer** that filters elements.

```fol
;; Create a transducer that keeps odd numbers
(def odd-xf (filter odd?))
```

### Collection Form (2 arguments)

With two arguments, returns a **lazy sequence** of elements where `(pred elem)` is truthy.

### Examples

```fol
;; Keep odd numbers (returns lazy-seq)
(filter odd? [1 2 3 4 5])         ; => lazy-seq: 1, 3, 5

;; Keep positive numbers
(filter positive? [-2 -1 0 1 2])  ; => lazy-seq: 1, 2

;; With custom predicate
(filter (fn [x] (> x 2)) [1 2 3 4 5])  ; => lazy-seq: 3, 4, 5

;; No matches returns empty lazy-seq
(filter negative? [1 2 3])        ; => empty lazy-seq

;; Filter dict entries (pairs as (key . value))
(filter (fn [pair] (positive? (rest pair)))
        {:a 1 :b -2 :c 3})        ; pairs where value is positive

;; Composing with map
(map (fn [x] (* x 2))
     (filter odd? [1 2 3 4 5]))   ; => lazy-seq: 2, 6, 10
```

---

## remove

```
(remove pred)
(remove pred coll)
```

Returns elements for which predicate returns falsy. The opposite of `filter`.

### Transducer Form (1 argument)

With one argument, returns a **transducer** that removes matching elements.

```fol
;; Create a transducer that removes nil values
(def compact-xf (remove nil?))
```

### Collection Form (2 arguments)

With two arguments, returns a **lazy sequence** of elements where `(pred elem)` is falsy.

### Examples

```fol
;; Remove odd numbers (keep even)
(remove odd? [1 2 3 4 5])         ; => lazy-seq: 2, 4

;; Remove negative numbers
(remove negative? [-2 -1 0 1 2])  ; => lazy-seq: 0, 1, 2

;; Remove nil values
(remove nil? [1 nil 2 nil 3])     ; => lazy-seq: 1, 2, 3

;; Equivalent to filter with complement
(remove odd? [1 2 3])             ; same as (filter (complement odd?) [1 2 3])
```

---

## keep

```
(keep f)
(keep f coll)
```

Applies `f` to each element, keeping non-nil results. Like `map` but filters out nil return values.

### Transducer Form (1 argument)

With one argument, returns a **transducer** that applies `f` and keeps non-nil results.

### Collection Form (2 arguments)

With two arguments, returns a **lazy sequence** of non-nil `(f elem)` results.

### Examples

```fol
;; Keep only successful parses
(keep (fn [s] (parse-int s)) ["1" "a" "2" "b" "3"])
                                  ; => lazy-seq: 1, 2, 3

;; Get values from a sparse structure
(keep (fn [k] (get {:a 1 :c 3} k)) [:a :b :c :d])
                                  ; => lazy-seq: 1, 3

;; Unlike map, nil results are excluded
(map (fn [x] (if (odd? x) x nil)) [1 2 3 4 5])   ; => 1, nil, 3, nil, 5
(keep (fn [x] (if (odd? x) x nil)) [1 2 3 4 5])  ; => 1, 3, 5
```

---

## mapcat

```
(mapcat f)
(mapcat f coll)
```

Applies `f` to each element (where `f` returns a collection), then concatenates all results.

### Transducer Form (1 argument)

With one argument, returns a **transducer** that maps and concatenates.

### Collection Form (2 arguments)

With two arguments, returns a **lazy sequence** of concatenated results.

### Examples

```fol
;; Expand each number into a range
(mapcat (fn [x] (range x)) [1 2 3])
                                  ; => lazy-seq: 0, 0, 1, 0, 1, 2

;; Split strings and flatten
(mapcat (fn [s] (split s " ")) ["a b" "c d e"])
                                  ; => lazy-seq: "a", "b", "c", "d", "e"

;; Duplicate each element
(mapcat (fn [x] [x x]) [1 2 3])   ; => lazy-seq: 1, 1, 2, 2, 3, 3

;; Flatten one level
(mapcat identity [[1 2] [3 4] [5]])
                                  ; => lazy-seq: 1, 2, 3, 4, 5
```

---

## interleave

```
(interleave coll1 coll2 ...)
```

Returns a lazy sequence of the first item in each collection, then the second item in each, etc.
Stops when any collection is exhausted.

### Examples

```fol
;; Interleave two collections
(interleave [1 2 3] [:a :b :c])   ; => lazy-seq: 1, :a, 2, :b, 3, :c

;; Interleave three collections
(interleave [1 2] [:a :b] ["x" "y"])
                                  ; => lazy-seq: 1, :a, "x", 2, :b, "y"

;; Stops at shortest collection
(interleave [1 2 3 4 5] [:a :b])  ; => lazy-seq: 1, :a, 2, :b

;; Create key-value pairs
(interleave [:a :b :c] [1 2 3])   ; => lazy-seq: :a, 1, :b, 2, :c, 3

;; With infinite sequences
(interleave (range) [:a :b :c])   ; => lazy-seq: 0, :a, 1, :b, 2, :c
```

---

## interpose

```
(interpose sep)
(interpose sep coll)
```

Returns elements of collection separated by `sep`.

### Transducer Form (1 argument)

With one argument, returns a **transducer** that interposes the separator.

### Collection Form (2 arguments)

With two arguments, returns a **lazy sequence** with `sep` between each element.

### Examples

```fol
;; Interpose comma between elements
(interpose "," [1 2 3])           ; => lazy-seq: 1, ",", 2, ",", 3

;; Join with separator (realize to string)
(reduce str "" (interpose "-" ["a" "b" "c"]))
                                  ; => "a-b-c"

;; Single element (no separator added)
(interpose "," [1])               ; => lazy-seq: 1

;; Empty collection
(interpose "," [])                ; => empty lazy-seq

;; With any separator value
(interpose 0 [1 2 3])             ; => lazy-seq: 1, 0, 2, 0, 3
```

---

## range

```
(range)
(range end)
(range start end)
(range start end step)
```

Returns a lazy sequence of numbers.

- `(range)` - infinite sequence starting from 0: 0, 1, 2, 3, ...
- `(range end)` - sequence from 0 to end-1
- `(range start end)` - sequence from start to end-1
- `(range start end step)` - sequence from start, incrementing by step, while in bounds

Returns an empty sequence when the range is invalid (e.g., start >= end with positive step).

### Examples

```fol
;; Basic range
(range 5)                         ; => lazy-seq: 0, 1, 2, 3, 4

;; With start and end
(range 2 5)                       ; => lazy-seq: 2, 3, 4

;; Even numbers
(range 0 10 2)                    ; => lazy-seq: 0, 2, 4, 6, 8

;; Counting down
(range 5 0 -1)                    ; => lazy-seq: 5, 4, 3, 2, 1

;; Infinite sequence (use with care!)
(range)                           ; => lazy-seq: 0, 1, 2, 3, ...

;; Empty ranges
(range 0)                         ; => empty lazy-seq
(range 5 5)                       ; => empty lazy-seq
(range 5 2)                       ; => empty lazy-seq (start > end)

;; With reduce - sum 0 to 9
(reduce + 0 (range 10))           ; => 45

;; With map - square numbers
(map (fn [x] (* x x)) (range 5))  ; => lazy-seq: 0, 1, 4, 9, 16

;; With filter - even numbers from range
(filter even? (range 10))         ; => lazy-seq: 0, 2, 4, 6, 8
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
    (filter even?)               ; lazy-seq: 2, 4, 6, 8, 10
    (map (fn [x] (* x x)))       ; lazy-seq: 4, 16, 36, 64, 100
    (reduce +))                  ; 220

;; Complex pipeline
(-> (range 100)
    (filter odd?)
    (map (fn [x] (* x x)))
    (filter (fn [x] (< x 50)))
    (reduce +))                  ; sum of squares of odd numbers < 50
```

---

## Transducers

Transducers are composable transformations that are independent of the input source and output target. The 1-arity versions of `map`, `filter`, `remove`, `keep`, `mapcat`, and `interpose` return transducers.

```fol
;; Create transducers
(def xf (comp (filter odd?)
              (map (fn [x] (* x x)))
              (filter (fn [x] (< x 100)))))

;; Apply to different contexts
(transduce xf + 0 [1 2 3 4 5 6 7 8 9 10])  ; => sum of squared odds < 100
(into [] xf [1 2 3 4 5])                   ; => collect into vector
```

---

## Implementation Notes

- All sequence functions work with any type that implements the `seq` protocol
- `map`, `filter`, `remove`, `keep`, `mapcat`, `interleave`, and `interpose` return lazy sequences
- Lazy sequences are realized on demand, enabling efficient processing of large or infinite sequences
- Transducers provide composable, efficient transformations without intermediate collections
- `reduce` is the fundamental operation that processes collections eagerly
