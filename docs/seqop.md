# Sequence Operations

These functions operate on FOL sequences (vectors, lists, strings) and provide
associative updates, subsequence extraction, reversal, and index searching.

## assoc

```
(assoc coll key val)
```

Returns a new collection with KEY mapped to VAL.
For dicts, associates the key with the value.
For vectors, sets the element at index KEY to VAL (KEY must be a non-negative integer).

### Examples

```fol
(assoc {:a 1 :b 2} :c 3)    ; => {:a 1 :b 2 :c 3}
(assoc {:a 1} :a 100)       ; => {:a 100}
(assoc [10 20 30] 1 99)     ; => [10 99 30]
```

---

## assoc-in

```
(assoc-in coll keys val)
```

Associates VAL in a nested associative structure. KEYS is a sequence of keys
identifying the path to the value. Returns a new nested structure with the
value at the path set to VAL. Creates intermediate dicts as needed when the
path doesn't exist.

### Examples

```fol
(assoc-in {:a {:b 1}} [:a :b] 99)       ; => {:a {:b 99}}
(assoc-in {:a 1} [:b :c :d] 42)         ; => {:a 1 :b {:c {:d 42}}}
(assoc-in [{:a 1}] [0 :a] 100)          ; => [{:a 100}]
```

---

## sub

```
(sub coll start)
(sub coll start end)
```

Returns a subsequence of COLL from START to END (exclusive).
If END is not provided, returns from START to the end of the collection.
Supported for strings, vectors, and lists.
Returns an object of the same type as the input.

### Examples

```fol
(sub "hello" 1 4)           ; => "ell"
(sub "hello" 2)             ; => "llo"
(sub [1 2 3 4 5] 1 4)       ; => [2 3 4]
(sub [1 2 3 4 5] 3)         ; => [4 5]
(sub '(1 2 3 4 5) 1 3)      ; => (2 3)
```

---

## reverse

```
(reverse coll)
```

Returns a new collection with elements in reverse order.
Works on strings, vectors, lists, and CL sequences.

### Examples

```fol
(reverse [1 2 3])           ; => [3 2 1]
(reverse '(a b c))          ; => (c b a)
(reverse "hello")           ; => "olleh"
```

---

## index-of

```
(index-of coll value)
(index-of coll value start)
```

Returns the index of the first occurrence of VALUE in collection COLL, or nil if not found.
Searches from index START (default 0) to the end of the collection.
For strings, VALUE can be a character, string, or regex pattern.
For lists and vectors, VALUE is compared using EQL.

### Examples

```fol
(index-of [1 2 3 2] 2)           ; => 1
(index-of [1 2 3 2] 2 2)         ; => 3 (search from index 2)
(index-of '(a b c) 'b)           ; => 1
(index-of "hello" \l)            ; => 2
(index-of "hello" "ll")          ; => 2
(index-of "hello" #"l+")         ; => 2 (regex match)
(index-of [1 2 3] 5)             ; => nil
```

---

## last-index-of

```
(last-index-of coll value)
(last-index-of coll value end)
```

Returns the index of the last occurrence of VALUE in collection COLL, or nil if not found.
Searches from the start of the collection to index END (if provided) or the end.
For strings, VALUE can be a character or string.
For lists and vectors, VALUE is compared using EQL.

### Examples

```fol
(last-index-of [1 2 3 2] 2)       ; => 3
(last-index-of [1 2 3 2 1] 2 2)   ; => 1 (search up to index 2)
(last-index-of '(a b c b) 'b)     ; => 3
(last-index-of "hello" \l)        ; => 3
(last-index-of "hello world" "l") ; => 9
(last-index-of [1 2 3] 5)         ; => nil
```

---

## peek

```
(peek coll)
```

Returns the first element of a collection without removing it.
For vectors, returns the last element (top of stack).
For lists, returns the first element.
Returns nil if the collection is empty.

### Examples

```fol
(peek [1 2 3])            ; => 3 (last element of vector)
(peek '(1 2 3))           ; => 1 (first element of list)
(peek [])                 ; => nil
```

---

## pop

```
(pop coll)
```

Returns a new collection with the "top" element removed.
For vectors, removes the last element.
For lists, removes the first element.
Signals an error if the collection is empty.

### Examples

```fol
(pop [1 2 3])             ; => [1 2]
(pop '(1 2 3))            ; => (2 3)
(pop [1])                 ; => []
```

---

## push

```
(push coll item)
```

Returns a new collection with ITEM added at the "top" position.
For vectors, adds to the end.
For lists, adds to the front.
Equivalent to conj for these collection types.

### Examples

```fol
(push [1 2] 3)            ; => [1 2 3]
(push '(2 3) 1)           ; => (1 2 3)
```

---

## update

```
(update coll key f & args)
```

Returns a new collection with the value at KEY updated by applying
function F to the current value and any additional ARGS.
Equivalent to `(assoc coll key (f (get coll key) args...))`.

### Examples

```fol
(update {:a 1} :a inc)              ; => {:a 2}
(update {:a 1} :a + 10)             ; => {:a 11}
(update [10 20 30] 1 * 2)           ; => [10 40 30]
(update {:count 0} :count + 5)      ; => {:count 5}
```

---

## update-in

```
(update-in coll keys f & args)
```

Returns a new nested structure with the value at the path KEYS updated
by applying function F to the current value and any additional ARGS.
KEYS is a sequence of keys identifying the path to the value.

### Examples

```fol
(update-in {:a {:b 1}} [:a :b] inc)         ; => {:a {:b 2}}
(update-in {:a {:b 10}} [:a :b] * 2)        ; => {:a {:b 20}}
(update-in [{:x 1}] [0 :x] + 100)           ; => [{:x 101}]
```

---

## reduce-kv

```
(reduce-kv f init coll)
```

Reduces an associative collection using function F, which takes three
arguments: the accumulator, the key, and the value. INIT is the initial
accumulator value. Returns the final accumulated value.

For vectors, the "key" is the index.
For dicts, the key is the map key.

### Examples

```fol
;; Sum all values in a dict
(reduce-kv (fn [acc k v] (+ acc v)) 0 {:a 1 :b 2 :c 3})
; => 6

;; Build a dict of index -> doubled value from a vector
(reduce-kv (fn [acc idx val] (assoc acc idx (* val 2))) {} [10 20 30])
; => {0 20, 1 40, 2 60}

;; Collect keys where value > 5
(reduce-kv (fn [acc k v] (if (> v 5) (conj acc k) acc)) [] {:a 3 :b 7 :c 10})
; => [:b :c]
```

---

## rseq

```
(rseq coll)
```

Returns a sequence of the collection's elements in reverse order.
Works on vectors, sorted sets, and ordered sets.
Returns nil if the collection is empty.

### Examples

```fol
(rseq [1 2 3])                  ; => (3 2 1)
(rseq (sorted-set 1 2 3 4 5))   ; => (5 4 3 2 1)
(rseq (ordered-set 3 1 4))      ; => (4 1 3)
(rseq [])                       ; => nil
```

---

## subs

```
(subs coll start)
(subs coll start end)
```

Returns a subsequence of an ordered collection from START (inclusive)
to END (exclusive). For sorted sets, returns elements in the range
[start, end) according to the sort order.

### Examples

```fol
;; On vectors
(subs [0 1 2 3 4] 2)            ; => (2 3 4)
(subs [0 1 2 3 4] 1 3)          ; => (1 2)

;; On sorted sets (by value range)
(subs (sorted-set 1 3 5 7 9) 3 7)  ; => (3 5) - elements >= 3 and < 7
```

---

## rsubs

```
(rsubs coll start)
(rsubs coll start end)
```

Returns a reverse subsequence of an ordered collection. Like `subs` but
elements are returned in reverse order. Similar to Clojure's `rsubseq`.

### Examples

```fol
;; On vectors
(rsubs [0 1 2 3 4] 1 4)         ; => (3 2 1)

;; On sorted sets (by value range, reversed)
(rsubs (sorted-set 1 3 5 7 9) 3 8)  ; => (7 5 3) - elements >= 3 and < 8, reversed
```
