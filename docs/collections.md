# Collection Operations

These functions work on FOL collections (vectors, lists, dicts, sets, bags, arrays)
and also on CL lists and strings.

## first

```
(first coll)
```

Returns the first element of a collection. Returns nil if empty.

### Examples

```fol
(first [1 2 3])       ; => 1
(first {:a 1 :b 2})   ; => [:a 1] (key-value pair)
(first "hello")       ; => \h
(first [])            ; => nil
(first '(a b c))      ; => a
```

---

## rest

```
(rest coll)
```

Returns a collection of all elements after the first.
For strings, returns the substring without the first character.

### Examples

```fol
(rest [1 2 3])        ; => (2 3)
(rest "hello")        ; => "ello"
(rest [1])            ; => nil
(rest '(a b c))       ; => (b c)
```

---

## second

```
(second coll)
```

Returns the second element of a collection. Equivalent to `(first (rest coll))`.

### Examples

```fol
(second [1 2 3])      ; => 2
(second '(a b c))     ; => b
(second [1])          ; => nil
```

---

## third

```
(third coll)
```

Returns the third element of a collection.

### Examples

```fol
(third [1 2 3])       ; => 3
(third '(a b c d))    ; => c
(third [1 2])         ; => nil
```

---

## nth

```
(nth coll n)
```

Returns the element at index n (0-indexed). Returns nil if index is out of bounds.

### Examples

```fol
(nth [10 20 30] 0)    ; => 10
(nth [10 20 30] 2)    ; => 30
(nth "hello" 1)       ; => \e
(nth [1 2 3] 10)      ; => nil
```

---

## get

```
(get coll key)
(get coll key default)
```

Retrieves the element at key from a collection.
For vectors and strings, key is an integer index.
For dicts, key is the lookup key.
Returns default (or nil) if not found.

### Examples

```fol
(get [10 20 30] 1)          ; => 20
(get {:a 1 :b 2} :a)        ; => 1
(get {:a 1} :c)             ; => nil
(get {:a 1} :c 0)           ; => 0 (default)
(get "hello" 0)             ; => \h
```

---

## size

```
(size coll)
```

Returns the number of elements in a collection.

### Examples

```fol
(size [1 2 3])        ; => 3
(size {:a 1 :b 2})    ; => 2
(size #{1 2 3 4})     ; => 4
(size "hello")        ; => 5
(size [])             ; => 0
```

---

## empty?

```
(empty? coll)
```

Returns true if the collection has no elements.

### Examples

```fol
(empty? [])           ; => true
(empty? [1])          ; => false
(empty? {})           ; => true
(empty? "")           ; => true
(empty? "hi")         ; => false
```

---

## contains?

```
(contains? coll item)
```

Returns true if the collection contains the item.
For dicts, checks if the key exists.
For sets/bags/vectors, checks if the item is present.
For strings, checks if the character is in the string.

### Examples

```fol
(contains? [1 2 3] 2)       ; => true
(contains? #{:a :b} :a)     ; => true
(contains? {:a 1} :a)       ; => true
(contains? {:a 1} :b)       ; => false
(contains? "hello" \e)      ; => true
(contains? "hello" \z)      ; => false
```

---

## seq

```
(seq coll)
```

Returns a sequential view of the collection as a FOL `<list>`.
Returns nil if the collection is empty.

### Examples

```fol
(seq [1 2 3])         ; => (1 2 3)
(seq {:a 1 :b 2})     ; => ([:a 1] [:b 2])
(seq #{1 2 3})        ; => (1 2 3)
(seq "abc")           ; => (\a \b \c)
(seq [])              ; => nil
```

---

## conj

```
(conj coll & items)
```

Returns a new collection with items added. The position where items are added
depends on the collection type:
- Vectors: items added at the end
- Lists: items added at the front
- Sets/Bags: items added to the collection
- Dicts: items should be key-value pairs

### Examples

```fol
(conj [1 2] 3)              ; => [1 2 3]
(conj [1 2] 3 4)            ; => [1 2 3 4]
(conj #{1 2} 3)             ; => #{1 2 3}
(conj {:a 1} [:b 2])        ; => {:a 1 :b 2}
```

---

## add

```
(add coll item)
(add coll key value)
```

Returns a new collection with the item added.
For dicts, requires both key and value.

### Examples

```fol
(add #{1 2} 3)              ; => #{1 2 3}
(add {:a 1} :b 2)           ; => {:a 1 :b 2}
```

---

## remove

```
(remove coll item)
```

Returns a new collection with the item removed.
For dicts, removes the key-value pair with the given key.

### Examples

```fol
(remove #{1 2 3} 2)         ; => #{1 3}
(remove {:a 1 :b 2} :a)     ; => {:b 2}
(remove [1 2 3 2] 2)        ; => [1 3 2] (removes first occurrence)
```

## disj

```
(disj set & keys)
```

Returns a new set with the specified keys removed. Works on all set types.

### Examples

```fol
(disj #{1 2 3} 2)           ; => #{1 3}
(disj #{1 2 3} 2 3)         ; => #{1}
(disj (sorted-set 1 2 3) 2) ; => #S{1 3}
(disj #{1 2 3} 4)           ; => #{1 2 3} (no change if not present)
```

---

## Set Operations

FOL provides comprehensive set operations that work across all set types.

### union

```
(union set1 set2 & more-sets)
```

Returns a new set containing all elements from all input sets.
The result type matches the type of the first set.

```fol
(union #{1 2} #{2 3})                  ; => #{1 2 3}
(union (sorted-set 1 2) #{3 4})        ; => #S{1 2 3 4}
(union #{1} #{2} #{3})                 ; => #{1 2 3}
```

---

### difference

```
(difference set1 set2)
```

Returns a new set containing elements in set1 but not in set2.

```fol
(difference #{1 2 3} #{2})             ; => #{1 3}
(difference (sorted-set 1 2 3) #{2 3}) ; => #S{1}
(difference #{1 2} #{3 4})             ; => #{1 2}
```

---

### intersection

```
(intersection set1 set2 & more-sets)
```

Returns a new set containing only elements present in all input sets.

```fol
(intersection #{1 2 3} #{2 3 4})       ; => #{2 3}
(intersection #{1 2} #{2 3} #{2 4})    ; => #{2}
(intersection (sorted-set 1 2 3) #{2}) ; => #S{2}
```

---

### select

```
(select pred set)
```

Returns a new set containing only elements that satisfy the predicate.
Similar to `filter` but returns a set of the same type.

```fol
(select odd? #{1 2 3 4 5})             ; => #{1 3 5}
(select (fn [x] (> x 2)) (sorted-set 1 2 3 4)) ; => #S{3 4}
```

---

### subset?

```
(subset? set1 set2)
```

Returns true if all elements of set1 are also in set2.

```fol
(subset? #{1 2} #{1 2 3})              ; => true
(subset? #{1 2 3} #{1 2})              ; => false
(subset? #{} #{1 2})                   ; => true (empty set is subset of all)
(subset? #{1 2} #{1 2})                ; => true (set is subset of itself)
```

---

### superset?

```
(superset? set1 set2)
```

Returns true if set1 contains all elements of set2.

```fol
(superset? #{1 2 3} #{1 2})            ; => true
(superset? #{1 2} #{1 2 3})            ; => false
(superset? #{1 2} #{})                 ; => true (all sets are supersets of empty)
```

---

## Specialized Set Types

FOL provides several specialized set implementations for different use cases.

### `<sorted-set>` - Sorted Set

A persistent set that maintains elements in natural sorted order.

```fol
(sorted-set 3 1 4 1 5 9 2)  ; => #S{1 2 3 4 5 9}
(seq (sorted-set 3 1 2))    ; => (1 2 3) - elements in sorted order
```

### `<ordered-set>` - Insertion-Order Set

A persistent set that maintains elements in insertion order.

```fol
(ordered-set 3 1 4 1 5)     ; => #O{3 1 4 5} - preserves insertion order
(seq (ordered-set 3 1 4))   ; => (3 1 4) - first inserted first
```

### `<int-set>` - Integer Set

A sorted set optimized for integers. Only accepts integer elements.

```fol
(int-set 5 3 8 1)           ; => #S{1 3 5 8}
(int-set 1 2 "a")           ; ERROR: only integers allowed
```

### `<dense-int-set>` - Dense Integer Set

A set optimized for dense integer ranges using bit vectors. Requires specifying the range bounds.

```fol
(make-dense-int-set 0 10 1 3 5 7 9)  ; => #D{1 3 5 7 9}
```

### `<sorted-set-by>` - Custom Comparator Sorted Set

A sorted set that uses a custom comparator function to determine element ordering.

```fol
;; Sort by descending order
(sorted-set-by > 3 1 4 1 5 9)        ; => #S<cmp>{9 5 4 3 1}

;; Sort strings by length
(sorted-set-by (fn [a b] (< (size a) (size b))) "cat" "elephant" "dog")
                                     ; => #S<cmp>{"cat" "dog" "elephant"}
```

### Set Constructor Functions

| Function | Creates | Description |
|----------|---------|-------------|
| `set` | `<set>` | Alias for hash set (unordered) |
| `hash-set` | `<set>` | Hash set (unordered) |
| `sorted-set` | `<sorted-set>` | Sorted set (natural ordering) |
| `sorted-set-by` | `<sorted-set-by>` | Sorted set with custom comparator |
| `ordered-set` | `<ordered-set>` | Insertion-order set |
| `int-set` | `<int-set>` | Integer-only sorted set |
| `dense-int-set` | `<dense-int-set>` | Dense integer range set (requires min/max bounds) |

## Get on Sets

For sets, `get` returns the element itself if present, or the default value otherwise.
This enables Clojure-style set membership testing.

```fol
(get #{:a :b :c} :b)           ; => :b
(get #{:a :b :c} :missing)     ; => nil
(get #{:a :b :c} :missing :default)  ; => :default
```

## Collections as Functions

Collections can be used as functions to access their elements (Clojure-style).

### Syntax

```fol
(coll key)           ; => (get coll key)
(coll key default)   ; => (get coll key default)
```

### Examples

```fol
;; Vectors as functions (index lookup)
(def v [10 20 30])
(v 0)                ; => 10
(v 2)                ; => 30

;; Dicts as functions (key lookup)
(def person {:name "Alice" :age 30})
(person :name)       ; => "Alice"
(person :missing :default)  ; => :default

;; Sets as functions (membership)
(def s #{:a :b :c})
(s :b)               ; => :b
(s :missing)         ; => nil
```

## Keywords as Functions on Sets

Keywords can be used as functions to access sets (extending existing dict support).

```fol
(:keyword set)       ; => (get set :keyword)
```

### Examples

```fol
(def colors #{:red :green :blue})
(:red colors)        ; => :red
(:yellow colors)     ; => nil
```

---

## Ordered Collection Operations

These operations work on ordered collections (vectors, lists, sorted-sets, ordered-sets).

### rseq

```
(rseq coll)
```

Returns a sequence of the collection's elements in reverse order.

```fol
(rseq [1 2 3])                  ; => (3 2 1)
(rseq (sorted-set 1 2 3 4 5))   ; => (5 4 3 2 1)
(rseq (ordered-set 3 1 4))      ; => (4 1 3)
(rseq [])                       ; => nil
```

---

### subs

```
(subs coll start)
(subs coll start end)
```

Returns a subsequence of an ordered collection from start index (inclusive)
to end index (exclusive). For sorted sets, returns elements in the range
[start, end) according to the sort order.

```fol
;; On vectors
(subs [0 1 2 3 4] 2)            ; => (2 3 4)
(subs [0 1 2 3 4] 1 3)          ; => (1 2)

;; On sorted sets (by value range)
(subs (sorted-set 1 3 5 7 9) 3 7)  ; => (3 5) - elements >= 3 and < 7
```

---

### rsubs

```
(rsubs coll start)
(rsubs coll start end)
```

Returns a reverse subsequence of an ordered collection. Like `subs` but
elements are returned in reverse order. Similar to Clojure's `rsubseq`.

```fol
;; On vectors
(rsubs [0 1 2 3 4] 1 4)         ; => (3 2 1)

;; On sorted sets (by value range, reversed)
(rsubs (sorted-set 1 3 5 7 9) 3 8)  ; => (7 5 3) - elements >= 3 and < 8, reversed
```

---

## Specialized Dict Types

FOL provides several specialized dictionary implementations optimized for different use cases.

### `<array-dict>` - Small Insertion-Order Dict

A persistent dictionary optimized for small maps (up to 1000 entries) that maintains
insertion order. Ideal for small configuration maps or data structures where order matters.

```fol
(array-dict :z 3 :a 1 :m 2)    ; => {|:z 3 :a 1 :m 2|}
(seq (array-dict :z 3 :a 1))   ; => ([:z 3] [:a 1]) - insertion order preserved

;; Limited to 1000 entries
(array-dict-with-limit 5 :a 1 :b 2 :c 3)  ; => {|:a 1 :b 2 :c 3|}
```

---

### `<sorted-dict>` - Sorted Dictionary

A persistent dictionary that maintains keys in sorted order using a SYCAMORE tree-map.
Provides efficient O(log n) lookup and maintains natural ordering of keys.

```fol
(sorted-dict :c 3 :a 1 :b 2)   ; => {<:a 1 :b 2 :c 3>}
(keys (sorted-dict :z 26 :a 1 :m 13))  ; => (:a :m :z) - sorted order
```

---

### `<ordered-dict>` - Insertion-Order Dictionary

A persistent dictionary that maintains insertion order for any number of entries.
Like array-dict but without the size limit.

```fol
(ordered-dict :z 3 :a 1 :m 2)  ; => {#:z 3 :a 1 :m 2#}
(seq (ordered-dict :z 3 :a 1 :m 2))  ; => ([:z 3] [:a 1] [:m 2])
```

---

### `<priority-dict>` - Priority Queue Dictionary

A persistent dictionary that maintains entries sorted by their values (priorities).
Useful as a priority queue where keys map to priorities.

```fol
(priority-dict :low 10 :high 100 :mid 50)  ; => {^:low 10 :mid 50 :high 100^}
(keys (priority-dict :low 10 :high 100 :mid 50))  ; => (:low :mid :high)
```

---

### `<int-dict>` - Integer-Key Dictionary

A sorted dictionary optimized for integer keys. Only accepts integers as keys.
Maintains keys in numerically sorted order.

```fol
(int-dict 3 "c" 1 "a" 2 "b")   ; => {1 "a" 2 "b" 3 "c"}
(int-dict 42 "x" 7 "y")        ; => {7 "y" 42 "x"}
(int-dict :a 1)                ; ERROR: only integer keys allowed
```

---

### Dict Constructor Functions

| Function | Creates | Description |
|----------|---------|-------------|
| `make-dict` / `dict` | `<dict>` | Standard hash map (unordered) |
| `array-dict` | `<array-dict>` | Small insertion-order map (≤1000 entries) |
| `array-dict-with-limit` | `<array-dict>` | Insertion-order map with custom size limit |
| `sorted-dict` | `<sorted-dict>` | Sorted map (natural key ordering) |
| `sorted-dict-by` | `<sorted-dict>` | Sorted map with custom comparator |
| `ordered-dict` | `<ordered-dict>` | Insertion-order map (unlimited size) |
| `priority-dict` | `<priority-dict>` | Priority queue map (sorted by values) |
| `int-dict` | `<int-dict>` | Integer-key sorted map |

---

