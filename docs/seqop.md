# Sequence Operations

These functions operate on FOL sequences (vectors, lists, strings) and provide
associative updates, subsequence extraction, reversal, and index searching.

## assoc                                                                *[function]*

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

## assoc-in                                                             *[function]*

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

## sub                                                                  *[function]*

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

## reverse                                                              *[function]*

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

## index-of                                                             *[function]*

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

## last-index-of                                                        *[function]*

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

## peek                                                                 *[function]*

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

## pop                                                                  *[function]*

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

## push                                                                 *[function]*

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

## Deque Operations

Deques (double-ended queues) support efficient operations at both the front and back.
The `<deque>` class provides O(log n) operations at either end.

### peek-front                                                          *[function]*

```
(peek-front deque)
```

Returns the element at the front of the deque without removing it.
Returns nil if the deque is empty.

#### Examples

```fol
(peek-front (deque 1 2 3))    ; => 1
(peek-front (deque))          ; => nil
```

---

### pop-front                                                           *[function]*

```
(pop-front deque)
```

Returns a new deque with the front element removed.
Returns an empty deque if the input is empty.

#### Examples

```fol
(pop-front (deque 1 2 3))     ; => #Q[2 3]
(pop-front (deque 1))         ; => #Q[]
(pop-front (deque))           ; => #Q[]
```

---

### push-front                                                          *[function]*

```
(push-front item deque)
```

Returns a new deque with ITEM added at the front.

#### Examples

```fol
(push-front 0 (deque 1 2 3))  ; => #Q[0 1 2 3]
(push-front :a (deque))       ; => #Q[:a]
```

---

### peek-end                                                            *[function]*

```
(peek-end deque)
```

Returns the element at the end of the deque without removing it.
Returns nil if the deque is empty.

#### Examples

```fol
(peek-end (deque 1 2 3))      ; => 3
(peek-end (deque))            ; => nil
```

---

### pop-end                                                             *[function]*

```
(pop-end deque)
```

Returns a new deque with the end element removed.
Returns an empty deque if the input is empty.

#### Examples

```fol
(pop-end (deque 1 2 3))       ; => #Q[1 2]
(pop-end (deque 1))           ; => #Q[]
(pop-end (deque))             ; => #Q[]
```

---

### push-end                                                            *[function]*

```
(push-end item deque)
```

Returns a new deque with ITEM added at the end.

#### Examples

```fol
(push-end 4 (deque 1 2 3))    ; => #Q[1 2 3 4]
(push-end :a (deque))         ; => #Q[:a]
```

---

### Standard Operations on Deques

Deques also support the standard sequence operations. The `peek`, `pop`, and `push`
operations work on the back of the deque (like vectors), while `first` and `rest`
work on the front (like lists).

```fol
;; peek/pop/push work on the back (like vector)
(peek (deque 1 2 3))          ; => 3
(pop (deque 1 2 3))           ; => #Q[1 2]
(push 4 (deque 1 2 3))        ; => #Q[1 2 3 4]

;; first/rest work on the front (like list)
(first (deque 1 2 3))         ; => 1
(rest (deque 1 2 3))          ; => #Q[2 3]

;; conj adds to the end
(conj (deque 1 2) 3 4)        ; => #Q[1 2 3 4]

;; get by index
(get (deque 10 20 30) 1)      ; => 20

;; seq returns elements front to back
(seq (deque 1 2 3))           ; => (1 2 3)
```

---

## update                                                               *[function]*

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

## update-in                                                            *[function]*

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

## reduce-kv                                                            *[function]*

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

## rseq                                                                 *[function]*

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

## subs                                                                 *[function]*

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

## rsubs                                                                *[function]*

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

---

## Dictionary Operations

These functions provide comprehensive dictionary manipulation capabilities following Clojure semantics.

### get-in                                                              *[function]*

```
(get-in coll keys)
(get-in coll keys default)
```

Gets the value at a path in nested associative structures. KEYS is a sequence
of keys identifying the path. Returns the value at the path, or DEFAULT (or nil)
if not found.

#### Examples

```fol
(get-in {:a {:b {:c 42}}} [:a :b :c])        ; => 42
(get-in {:a {:b 1}} [:a :x])                 ; => nil
(get-in {:a {:b 1}} [:a :x] :not-found)      ; => :not-found
(get-in {:x [10 20 30]} [:x 1])              ; => 20
```

---

### find                                                                *[function]*

```
(find coll key)
```

Returns the key-value pair for KEY in dict COLL as a cons cell, or nil if not found.
Useful for distinguishing between a missing key and a key mapped to nil.

#### Examples

```fol
(find {:a 1 :b 2} :a)         ; => (:a . 1)
(find {:a nil} :a)            ; => (:a . nil)
(find {:a 1} :c)              ; => nil
```

---

### keys                                                                *[function]*

```
(keys dict)
```

Returns a sequence of all keys in the dictionary. For ordered dicts (array-dict,
ordered-dict), returns keys in insertion order. For sorted-dict, returns keys
in sorted order. For priority-dict, returns keys in priority (value) order.

#### Examples

```fol
(keys {:a 1 :b 2 :c 3})                  ; => (:a :b :c) or similar
(keys (sorted-dict :z 3 :a 1 :m 2))      ; => (:a :m :z)
(keys (ordered-dict :z 3 :a 1 :m 2))     ; => (:z :a :m)
(keys (priority-dict :low 10 :high 100 :mid 50))  ; => (:low :mid :high)
```

---

### vals                                                                *[function]*

```
(vals dict)
```

Returns a sequence of all values in the dictionary. The order corresponds to
the order of keys for the dict type.

#### Examples

```fol
(vals {:a 1 :b 2 :c 3})                  ; => (1 2 3) or similar
(vals (sorted-dict :z 3 :a 1 :m 2))      ; => (1 2 3)
(vals (priority-dict :low 10 :high 100 :mid 50))  ; => (10 50 100)
```

---

### key                                                                 *[function]*

```
(key entry)
```

Extracts the key from a map entry (cons cell). The entry is typically obtained
from `find` or when iterating over a dict.

#### Examples

```fol
(key (cons :a 1))             ; => :a
(key (find {:a 1} :a))        ; => :a
```

---

### val                                                                 *[function]*

```
(val entry)
```

Extracts the value from a map entry (cons cell). The entry is typically obtained
from `find` or when iterating over a dict.

#### Examples

```fol
(val (cons :a 1))             ; => 1
(val (find {:a 1} :a))        ; => 1
```

---

### dissoc                                                              *[function]*

```
(dissoc dict & keys)
```

Returns a new dictionary with the specified KEYS removed. For ordered dicts,
maintains the insertion order of remaining keys.

#### Examples

```fol
(dissoc {:a 1 :b 2 :c 3} :b)             ; => {:a 1 :c 3}
(dissoc {:a 1 :b 2 :c 3} :b :c)          ; => {:a 1}
(dissoc (ordered-dict :a 1 :b 2 :c 3) :b)  ; => {#:a 1 :c 3#}
```

---

### merge                                                               *[function]*

```
(merge & dicts)
```

Returns a new dictionary that combines all input dictionaries. When keys overlap,
later dictionaries' values win. The result type matches the first dict's type.

#### Examples

```fol
(merge {:a 1} {:b 2})                    ; => {:a 1 :b 2}
(merge {:a 1 :b 2} {:b 20 :c 3})         ; => {:a 1 :b 20 :c 3}
(merge {:a 1} {:b 2} {:c 3})             ; => {:a 1 :b 2 :c 3}
```

---

### merge-with                                                          *[function]*

```
(merge-with f & dicts)
```

Returns a new dictionary that combines all input dictionaries. When keys overlap,
the combining function F is called with the conflicting values to produce the
merged value.

#### Examples

```fol
(merge-with + {:a 1 :b 2} {:b 3 :c 4})   ; => {:a 1 :b 5 :c 4}
(merge-with * {:a 2} {:a 3})             ; => {:a 6}
(merge-with concat {:a [1]} {:a [2]})    ; => {:a [1 2]}
```

---

### select-keys                                                         *[function]*

```
(select-keys dict keyseq)
```

Returns a new dictionary containing only the entries for keys present in KEYSEQ.
Keys in KEYSEQ that don't exist in dict are ignored.

#### Examples

```fol
(select-keys {:a 1 :b 2 :c 3} [:a :c])   ; => {:a 1 :c 3}
(select-keys {:a 1 :b 2} [:a :x])        ; => {:a 1}
```

---

### rename-keys                                                         *[function]*

```
(rename-keys dict keymap)
```

Returns a new dictionary with keys renamed according to KEYMAP. KEYMAP is a
dictionary mapping old keys to new keys. Keys not in keymap are unchanged.

#### Examples

```fol
(rename-keys {:a 1 :b 2} {:a :x})        ; => {:x 1 :b 2}
(rename-keys {:a 1 :b 2} {:a :x :b :y})  ; => {:x 1 :y 2}
```

---

### map-invert                                                          *[function]*

```
(map-invert dict)
```

Returns a new dictionary with keys and values swapped. If multiple keys map to
the same value, only one key-value pair will be in the result (unspecified which).

#### Examples

```fol
(map-invert {:a 1 :b 2 :c 3})            ; => {1 :a 2 :b 3 :c}
(map-invert {:name "Alice" :age 30})     ; => {"Alice" :name 30 :age}
```

---

### update-keys                                                         *[function]*

```
(update-keys dict f)
```

Returns a new dictionary with function F applied to all keys. The values remain unchanged.

#### Examples

```fol
(update-keys {1 "a" 2 "b"} (fn [k] (* k 10)))  ; => {10 "a" 20 "b"}
(update-keys {:a 1 :b 2} name)                  ; => {"a" 1 "b" 2}
```

---

### update-vals                                                         *[function]*

```
(update-vals dict f)
```

Returns a new dictionary with function F applied to all values. The keys remain unchanged.

#### Examples

```fol
(update-vals {:a 1 :b 2 :c 3} (fn [v] (* v 10)))  ; => {:a 10 :b 20 :c 30}
(update-vals {:a 1 :b 2} inc)                      ; => {:a 2 :b 3}
```

---

### freqs                                                               *[function]*

```
(freqs coll)
```

Returns a dictionary mapping each unique element in COLL to the number of times
it occurs. Like Clojure's `frequencies`.

#### Examples

```fol
(freqs [1 2 3 1 2 1])                   ; => {1 3 2 2 3 1}
(freqs "hello")                         ; => {\h 1 \e 1 \l 2 \o 1}
(freqs [:a :b :a :c :b :a])             ; => {:a 3 :b 2 :c 1}
```

---

### group-by                                                            *[function]*

```
(group-by f coll)
```

Returns a dictionary mapping the result of applying F to each element to a
vector of all elements that produced that result.

#### Examples

```fol
(group-by odd? [1 2 3 4 5])             ; => {true [1 3 5] false [2 4]}
(group-by count ["a" "as" "asd" "aa"])  ; => {1 ["a"] 2 ["as" "aa"] 3 ["asd"]}
(group-by :type [{:type :a :val 1} {:type :b :val 2} {:type :a :val 3}])
; => {:a [{:type :a :val 1} {:type :a :val 3}] :b [{:type :b :val 2}]}
```

---

### index                                                               *[function]*

```
(index coll f)
```

Returns a dictionary mapping the result of applying F to each element to that element.
If multiple elements produce the same key, only one will be in the result (unspecified which).

#### Examples

```fol
(index [:a :b :c] identity)              ; => {:a :a :b :b :c :c}
(index [{:id 1 :name "Alice"} {:id 2 :name "Bob"}] :id)
; => {1 {:id 1 :name "Alice"} 2 {:id 2 :name "Bob"}}
```

---
