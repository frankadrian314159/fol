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

## iterate

```
(iterate f x)
```

Returns a lazy sequence of `x`, `(f x)`, `(f (f x))`, etc. The function `f` must be free of side-effects.

### Examples

```fol
;; Powers of 2
(iterate (fn [x] (* x 2)) 1)      ; => lazy-seq: 1, 2, 4, 8, 16, 32, ...

;; Fibonacci using iterate with pairs
(iterate (fn [[a b]] [b (+ a b)]) [0 1])
                                  ; => lazy-seq: [0 1], [1 1], [1 2], [2 3], ...

;; Take first 10
(map first (take 10 (iterate (fn [[a b]] [b (+ a b)]) [0 1])))
                                  ; => (0 1 1 2 3 5 8 13 21 34)

;; Incrementing sequence
(iterate (fn [x] (+ x 1)) 0)      ; => lazy-seq: 0, 1, 2, 3, ... (like (range))
```

---

## repeat

```
(repeat x)
(repeat n x)
```

Returns a lazy sequence of `x`s.

- `(repeat x)` - infinite sequence of `x`
- `(repeat n x)` - sequence of `x` repeated `n` times

### Examples

```fol
;; Infinite repetition (use with care!)
(repeat :a)                       ; => lazy-seq: :a, :a, :a, ...

;; Take first 5
(take 5 (repeat :a))              ; => (:a :a :a :a :a)

;; Fixed repetition
(repeat 3 "hello")                ; => lazy-seq: "hello", "hello", "hello"

;; Create padding
(reduce str "" (repeat 5 "-"))    ; => "-----"

;; Empty for n <= 0
(repeat 0 :x)                     ; => empty lazy-seq
```

---

## repeatedly

```
(repeatedly f)
(repeatedly n f)
```

Returns a lazy sequence of calls to `f`. Unlike `repeat`, the function is called each time, so `f` can have side effects (like generating random numbers).

- `(repeatedly f)` - infinite sequence of `(f)` calls
- `(repeatedly n f)` - sequence of `n` calls to `(f)`

### Examples

```fol
;; Infinite random numbers
(repeatedly random)               ; => lazy-seq: 0.42, 0.87, 0.13, ...

;; Generate 5 random numbers
(repeatedly 5 random)             ; => lazy-seq of 5 random values

;; Generate unique IDs
(def counter (atom 0))
(repeatedly 3 (fn [] (swap! counter inc)))
                                  ; => lazy-seq: 1, 2, 3

;; Create list of empty vectors
(repeatedly 3 (fn [] []))         ; => lazy-seq: [], [], []
```

---

## cycle

```
(cycle coll)
```

Returns a lazy (infinite!) sequence of repetitions of the items in `coll`.

### Examples

```fol
;; Cycle through elements
(cycle [1 2 3])                   ; => lazy-seq: 1, 2, 3, 1, 2, 3, 1, 2, 3, ...

;; Take first 10 from cycle
(take 10 (cycle [:a :b]))         ; => (:a :b :a :b :a :b :a :b :a :b)

;; Interleave with cycling separator
(interleave [1 2 3 4 5] (cycle [:odd :even]))
                                  ; => lazy-seq: 1, :odd, 2, :even, 3, :odd, ...

;; Empty collection produces empty sequence
(cycle [])                        ; => empty lazy-seq

;; Cycle a string (characters)
(take 6 (cycle "ab"))             ; => (#\a #\b #\a #\b #\a #\b)
```

---

## reduced / reduced?

```
(reduced value)
(reduced? x)
(unreduced x)
```

Functions for early termination in `reduce` operations.

- `(reduced value)` - wraps `value` to signal that reduction should stop
- `(reduced? x)` - returns true if `x` is a reduced value
- `(unreduced x)` - unwraps a reduced value, or returns `x` unchanged if not reduced

When `reduce` encounters a reduced value returned from the reducing function, it immediately stops iteration and returns the unwrapped value.

### Examples

```fol
;; Find first element matching predicate
(reduce (fn [acc x]
          (if (> x 5)
              (reduced x)
              acc))
        nil
        [1 2 3 7 8 9])            ; => 7 (stops at first > 5)

;; Short-circuit sum when limit reached
(reduce (fn [acc x]
          (let [new-sum (+ acc x)]
            (if (> new-sum 10)
                (reduced new-sum)
                new-sum)))
        0
        [1 2 3 4 5 6 7 8])        ; => 15 (1+2+3+4+5 = 15, stops)

;; Check if any element matches (like `some`)
(reduce (fn [_ x]
          (if (even? x)
              (reduced true)
              false))
        false
        [1 3 5 6 7])              ; => true (found 6)

;; Check reduced?
(reduced? (reduced 42))           ; => true
(reduced? 42)                     ; => false

;; Unreduced unwraps or passes through
(unreduced (reduced 42))          ; => 42
(unreduced 42)                    ; => 42
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
- `map`, `filter`, `remove`, `keep`, `mapcat`, `interleave`, `interpose`, `iterate`, `repeat`, `repeatedly`, and `cycle` return lazy sequences
- Lazy sequences are realized on demand, enabling efficient processing of large or infinite sequences
- Use `reduced` for early termination in `reduce` operations
- Transducers provide composable, efficient transformations without intermediate collections
- `reduce` is the fundamental operation that processes collections eagerly
- `iterate`, `repeat`, `repeatedly`, and `cycle` can produce infinite sequences - use with functions like `take` to limit consumption

---

## sequence

```
(sequence coll)
```

Coerces coll to a (possibly empty) sequence. Like `seq`, but returns an empty list `()` instead of `nil` for empty collections. Does not force lazy sequences.

### Examples

```fol
;; Non-empty collection
(sequence [1 2 3])            ; => (1 2 3)

;; Empty collection returns empty list, not nil
(sequence [])                 ; => ()

;; Contrast with seq
(seq [])                      ; => nil
(sequence [])                 ; => ()

;; Works with any collection
(sequence {:a 1 :b 2})        ; => ((:a . 1) (:b . 2))
```

---

## keep-indexed

```
(keep-indexed f)
(keep-indexed f coll)
```

Returns a lazy sequence of the non-nil results of `(f index item)`. Note that this means false return values will be included.

### Transducer Form (1 argument)

With one argument, returns a **transducer** that applies indexed keep.

### Collection Form (2 arguments)

With two arguments, returns a **lazy sequence** of non-nil `(f index item)` results.

### Examples

```fol
;; Keep elements at even indices
(keep-indexed (fn [i v] (when (even? i) v)) [:a :b :c :d :e])
                                  ; => lazy-seq: :a, :c, :e

;; Get indexed pairs for elements > 1
(keep-indexed (fn [i v] (when (> v 1) [i v])) [0 1 2 3])
                                  ; => lazy-seq: [2 2], [3 3]

;; Return index of first matching element
(first (keep-indexed (fn [i v] (when (= v :target) i)) [:a :b :target :c]))
                                  ; => 2
```

---

## map-indexed

```
(map-indexed f)
(map-indexed f coll)
```

Returns a lazy sequence of `(f index item)` for each item in coll. The function f receives two arguments: the zero-based index and the item.

### Transducer Form (1 argument)

With one argument, returns a **transducer** that maps with index.

### Collection Form (2 arguments)

With two arguments, returns a **lazy sequence** of `(f index item)` results.

### Examples

```fol
;; Pair each element with its index
(map-indexed (fn [i v] [i v]) [:a :b :c])
                                  ; => lazy-seq: [0 :a], [1 :b], [2 :c]

;; Add index to each value
(map-indexed + [10 20 30])        ; => lazy-seq: 10, 21, 32

;; Create indexed entries
(into {} (map-indexed (fn [i v] [v i]) [:a :b :c]))
                                  ; => {:a 0 :b 1 :c 2}
```

---

## iteration

```
(iteration step :initk key :somef pred :vf value-fn :kf key-fn)
```

Creates a lazy sequence from a step function. The step function takes a seed value and returns a map with iteration information. This is useful for paginated APIs or stateful iteration.

Options:
- `:initk key` - key to extract next seed from result (default `:next`)
- `:somef pred` - predicate to test if there's a value (default `some?`)
- `:vf fn` - function to extract value from result (default `:value`)
- `:kf fn` - function to extract next seed (default value of `:initk`)

### Examples

```fol
;; Simple counter
(take 5 (iteration (fn [x] {:value x :next (inc x)}) :initk :next :next 0))
                                  ; => (0 1 2 3 4)

;; Paginated API simulation
(defn fetch-page [cursor]
  (if (< cursor 3)
    {:items [cursor] :next-cursor (inc cursor)}
    nil))

(iteration fetch-page
  :initk :next-cursor
  :somef some?
  :vf :items
  :next-cursor 0)
                                  ; => lazy-seq of pages
```

---

## tree-seq

```
(tree-seq branch? children root)
```

Returns a lazy sequence of the nodes in a tree, via a depth-first walk.

- `branch?` - a function that returns true if a node can have children
- `children` - a function that returns the children of a node
- `root` - the root node of the tree

### Examples

```fol
;; Walk a nested vector structure
(tree-seq <vector>? seq [[1 2] [3 [4 5]]])
                                  ; => ([[1 2] [3 [4 5]]] [1 2] 1 2 [3 [4 5]] 3 [4 5] 4 5)

;; Walk a map structure
(tree-seq <dict>? vals {:a {:b 1 :c 2} :d {:e 3}})

;; Find all leaves (non-branches)
(filter (complement <vector>?) (tree-seq <vector>? seq [1 [2 [3]]]))
                                  ; => (1 2 3)
```
