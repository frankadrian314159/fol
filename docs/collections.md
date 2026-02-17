# Collections

FOL provides a rich set of persistent, immutable collection types. All collections inherit from `<persistent-object>` and support structural sharing for efficient updates.

## Collection Hierarchy

```
<collection>
├── <ordered-collection>
│   ├── <vector>
│   │   ├── <array>
│   │   └── <deque>
│   ├── <list>
│   ├── <lazy-seq>
│   ├── <sorted-set>
│   ├── <ordered-set>
│   ├── <dense-int-set>
│   ├── <array-dict>
│   ├── <sorted-dict>
│   ├── <ordered-dict>
│   └── <priority-dict>
└── <unordered-collection>
    ├── <dict>
    ├── <set>
    └── <bag>
```

---

## Vector - `<vector>`                                                   *[class]*

A persistent ordered sequence with efficient random access. Vectors are the primary indexed collection type.

### Literal Syntax

```fol
[]              ; empty vector
[1 2 3]         ; vector of integers
[:a :b :c]      ; vector of keywords
[[1 2] [3 4]]   ; nested vectors
```

### Constructor

```fol
(<vector> 1 2 3)       ; => [1 2 3]
(vec '(1 2 3))         ; => [1 2 3] (from sequence)
(mapv inc [1 2 3])     ; => [2 3 4] (eager map to vector)
(filterv odd? [1 2 3]) ; => [1 3] (eager filter to vector)
```

### Predicate

```fol
(<vector>? [1 2 3])    ; => t
(<vector>? '(1 2 3))   ; => nil
```

---

## vec                                                                    *[function]*

```
(vec coll)
```

Coerces any collection or sequence to a `<vector>`.  If `coll` is already a
`<vector>`, returns it unchanged (identity).  Accepts FOL collections, CL lists,
CL vectors, and `nil`.

### Examples

```fol
(vec [1 2 3])              ; => [1 2 3]   (identity — same object)
(vec (list 1 2 3))         ; => [1 2 3]
(vec #{1 2 3})             ; => [1 2 3]   (order unspecified)
(vec {:a 1 :b 2})          ; => [(:a . 1) (:b . 2)]
(vec nil)                  ; => []
(vec '(4 5 6))             ; => [4 5 6]   (CL list)
```

---

## vector-of                                                             *[function]*

```
(vector-of type & args)
```

Creates a `<vector>` from `args`, validating that every element satisfies `type`.
`type` must be a FOL type symbol (e.g. `<number>`, `<string>`, `<integer>`).
Signals an error if any element does not match the type, or if the type is unknown.

### Examples

```fol
(vector-of '<number> 1 2 3)       ; => [1 2 3]
(vector-of '<string> "a" "b")     ; => ["a" "b"]
(vector-of '<number> 1 "x" 3)     ; => ERROR: element "x" is not of type <number>
(vector-of '<bogus> 1 2)           ; => ERROR: unknown type <bogus>
(vector-of '<number>)              ; => []
```

---

## Deque - `<deque>`                                                     *[class]*

A persistent double-ended queue supporting efficient O(log n) operations at
both ends. Inherits from `<vector>` and uses the same FSet seq storage.
Deques support standard queue operations (`peek`/`pop` from front,
`push`/`conj` to back) and reverse operations (`rpeek`/`rpop` from back,
`rpush`/`rconj` to front).

### Literal Syntax

```fol
#Q[]            ; empty deque
#Q[1 2 3]       ; deque with elements
```

### Constructor

```fol
(deque)         ; => #Q[]
(deque 1 2 3)   ; => #Q[1 2 3]
```

### Standard Operations (front read, back write)

| Function | Description |
|----------|-------------|
| `peek`   | Returns the front element |
| `pop`    | Returns deque without front element |
| `push`   | Returns deque with element added at back |
| `conj`   | Returns deque with element added at back |

### Reverse Operations (back read, front write)

| Function | Description |
|----------|-------------|
| `rpeek`  | Returns the back element |
| `rpop`   | Returns deque without back element |
| `rpush`  | Returns deque with element added at front |
| `rconj`  | Returns deque with element added at front |

### Examples

```fol
(def dq (deque 1 2 3))
(peek dq)              ; => 1
(pop dq)               ; => #Q[2 3]
(push dq 4)            ; => #Q[1 2 3 4]
(rpeek dq)             ; => 3
(rpop dq)              ; => #Q[1 2]
(rpush dq 0)           ; => #Q[0 1 2 3]
```

### Predicate

```fol
(<deque>? (deque 1 2)) ; => true
(<vector>? (deque 1))  ; => false  ; deque is not a vector for predicate purposes
```

---

## List - `<list>`                                                       *[class]*

A persistent singly-linked list with O(1) access to first element and O(1) cons (prepend) operations. Lists maintain their size for O(1) count access.

### Literal Syntax

```fol
()              ; empty list
'(1 2 3)        ; quoted list
```

### Constructor

```fol
(<list>)          ; => ()
(<list> 1 2 3)    ; => (1 2 3)
(list* 1 2 [3 4]) ; => (1 2 3 4) - prepends to sequence
```

### Operations

Lists support efficient prepend via `cons` or `conj`:

```fol
(cons 0 '(1 2 3))     ; => (0 1 2 3)
(conj '(1 2 3) 0)     ; => (0 1 2 3) - lists prepend
(first '(1 2 3))      ; => 1
(rest '(1 2 3))       ; => (2 3)
```

### Predicate

```fol
(<list>? '(1 2 3))    ; => t
(<list>? [1 2 3])     ; => nil
```

---

## Lazy Sequence - `<lazy-seq>`                                          *[class]*

A lazy sequence that delays computation until elements are accessed. Supports infinite sequences and efficient memory usage. Lazy sequences are created using the `lazy-seq` special form or functions that return lazy sequences (like `map`, `filter`, `range`).

### Special Form

```fol
(lazy-seq body...)
```

Creates a lazy sequence. The body is not evaluated until the sequence is accessed.

### Examples

```fol
;; Infinite sequence of integers
(def naturals (iterate inc 0))
(take 5 naturals)     ; => (0 1 2 3 4)

;; Lazy range
(range)               ; => infinite sequence 0, 1, 2, ...
(range 5)             ; => (0 1 2 3 4)
(range 1 10 2)        ; => (1 3 5 7 9)

;; Lazy transformations
(map inc [1 2 3])     ; => lazy sequence (2 3 4)
(filter odd? [1 2 3]) ; => lazy sequence (1 3)
```

### Forcing Evaluation

```fol
(doall coll)          ; realize entire lazy seq, return it
(dorun coll)          ; realize for side effects, return nil
(realized? lazy-seq)  ; check if already realized
```

### Predicate

```fol
(<lazy-seq>? (range 5))  ; => t
```

---

## Bag - `<bag>`                                                         *[class]*

A persistent multiset (bag) that counts occurrences of elements. Implemented as a dictionary where keys are elements and values are their counts.

### Literal Syntax

```fol
#M{}            ; empty bag
#M{1 1 2}       ; bag with two 1s and one 2
```

### Constructor

```fol
(<bag> 1 1 2 2 2)  ; bag with count: {1 -> 2, 2 -> 3}
```

### Predicate

```fol
(<bag>? (<bag> 1 2)) ; => t
```

---

## Array - `<array>`                                                     *[class]*

A multi-dimensional array stored as a flat vector with dimension information. Useful for matrix operations and multi-dimensional data.

### Constructor

```fol
(<array> [2 3] 1 2 3 4 5 6)  ; 2x3 array
```

### Predicate

```fol
(<array>? (<array> [2 2] 1 2 3 4)) ; => t
```

### Multi-dimensional Access

Arrays support access by a list of indices using column-major order
(first index varies fastest). The `get` function accepts either a single
linear index or a list of multi-dimensional indices.

```fol
(def a (<array> [3 2] 0 1 2 3 4 5))
;; Column-major layout: (0,0)=>0  (1,0)=>1  (2,0)=>2  (0,1)=>3  (1,1)=>4  (2,1)=>5

(get a '(1 0))     ; => 1
(get a '(0 1))     ; => 3
(get a '(2 1))     ; => 5
(get a 4)          ; => 4  (linear index still works)
```

Signals an error if the number of indices doesn't match the dimensions
or if any index is out of bounds.

### Dimension Validation

Array dimensions must be non-negative integers. Attempting to create an
array with a negative or non-integer dimension signals an error.

---

## %index                                                               *[function]*

```
(%index dimensions indices)
```

Computes a linear index in column-major order from a list of dimension
sizes and a list of indices. Both arguments must be lists of the same length.

Column-major order means the first index varies fastest. For dimensions
`(d0 d1 d2)` and indices `(i0 i1 i2)`:

```
linear = i0 + d0*i1 + d0*d1*i2
```

Signals an error if:
- The lengths of dimensions and indices differ
- Any index is negative
- Any index is >= its corresponding dimension

### Examples

```fol
(%index '(3 4) '(1 2))       ; => 7   (= 1 + 3*2)
(%index '(3 4 5) '(2 1 3))   ; => 41  (= 2 + 3*1 + 12*3)
(%index '(10) '(5))           ; => 5   (trivial 1D case)
```

---

## Dict - `<dict>`                                                       *[class]*

A persistent hash map with O(1) average lookup. The standard dictionary type.

### Literal Syntax

```fol
{}              ; empty dict
{:a 1 :b 2}     ; dict with keyword keys
{"name" "Alice" "age" 30}  ; dict with string keys
```

### Constructor

```fol
(<dict> :a 1 :b 2)   ; => {:a 1 :b 2}
```

See the specialized dict types below for ordered and sorted variants.

---

## Set - `<set>`                                                         *[class]*

A persistent hash set with O(1) average lookup.

### Literal Syntax

```fol
#{}             ; empty set
#{1 2 3}        ; set of integers
#{:a :b :c}     ; set of keywords
```

### Constructor

```fol
(<set> 1 2 3)        ; => #{1 2 3}
```

### Predicate

```fol
(<set>? #{1 2 3})    ; => t
```

---

# Collection Operations

These functions work on FOL collections (vectors, deques, lists, dicts, sets, bags, arrays)
and also on CL lists and strings.

## first                                                                *[function]*

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

## rest                                                                 *[function]*

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

## second                                                               *[function]*

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

## third                                                                *[function]*

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

## nth                                                                  *[generic]*

```
(nth coll index)
(nth coll index not-found)
```

Returns the element at index (0-indexed) in a collection. Signals an error
if index is out of bounds and not-found is not supplied. Returns not-found
when index is out of bounds and not-found is given.

For lists, walks the linked structure in O(n) time.

### Examples

```fol
(nth (list 10 20 30) 0)        ; => 10
(nth (list 10 20 30) 2)        ; => 30
(nth (list 10 20 30) 5 :nope)  ; => :nope
(nth (list 10 20 30) 5)        ; => error
```

---

## get                                                                  *[function]*

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

## size                                                                 *[function]*

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

## empty?                                                               *[function]*

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

## contains?                                                            *[function]*

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

## seq                                                                  *[function]*

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

## conj                                                                 *[function]*

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

## list*                                                                *[function]*

```
(list* & args)
```

Creates a list from args with the last argument used as the tail. The last
argument should be a collection or nil; preceding arguments are prepended
in order. With a single argument, returns that argument unchanged.

### Examples

```fol
(list* 1 2 3 (list 4 5))  ; => (1 2 3 4 5)
(list* 1 (list 2 3))      ; => (1 2 3)
(list* (list 1 2))         ; => (1 2)
(list* 1 2 nil)            ; => (1 2)
(list* 1 2 3)              ; => (1 2 3)
```

---

## peek                                                                 *[generic]*

```
(peek coll)
```

Returns the element that `pop` would remove, without modifying the collection.
For lists, returns the first element. For vectors, returns the last element.
Returns nil for empty collections.

### Examples

```fol
(peek (list 1 2 3))     ; => 1
(peek [10 20 30])        ; => 30
(peek [42])              ; => 42
(peek [])                ; => nil
(peek (list))            ; => nil
```

---

## push                                                                 *[generic]*

```
(push coll value)
```

Returns a new collection with value added at the natural insertion point.
For lists, prepends to the front (stack semantics).

### Examples

```fol
(push (list 2 3) 1)  ; => (1 2 3)
(push (list) 42)     ; => (42)
```

---

## pop                                                                  *[generic]*

```
(pop coll)
```

Returns a new collection without the element that `peek` would return.
For lists, removes the first element. For vectors, removes the last element.
Signals an error on empty collections.

### Examples

```fol
(pop (list 1 2 3))  ; => (2 3)
(pop [10 20 30])    ; => [10 20]
(pop [42])          ; => []
(pop (list))        ; => error
(pop [])            ; => error
```

---

## index-of                                                             *[generic]*

```
(index-of coll value)
(index-of coll value :from-index n)
```

Finds the first index of value in a collection. Returns nil if not found.
Works on lists, vectors, and strings. Compares with `eql`.

### Examples

```fol
(index-of [10 20 30 20] 20)                     ; => 1
(index-of [10 20 30 20] 20 :from-index 2)       ; => 3
(index-of (list 10 20 30) 99)                    ; => nil
(index-of [] 42)                                 ; => nil
```

---

## last-index-of                                                        *[generic]*

```
(last-index-of coll value)
```

Finds the last index of value in a collection. Returns nil if not found.
Works on lists, vectors, and strings. Compares with `eql`.

### Examples

```fol
(last-index-of [10 20 30 20] 20)   ; => 3
(last-index-of [10 20 30] 10)      ; => 0
(last-index-of (list 10 20 30) 99) ; => nil
```

---

## assoc-in                                                              *[generic]*

```
(assoc-in coll keys value)
```

Nested associative update. `keys` is a list of keys/indices forming a path into
a nested structure. Returns a new collection with the value at the nested path
set to `value`. Works on vectors (index-based) and dicts (key-based).

### Examples

```fol
(assoc-in [10 20 30] '(1) 99)                ; => [10 99 30]
(assoc-in [{:a 1}] '(0 :a) 42)               ; => [{:a 42}]
(assoc-in {:a {:x 1}} '(:a :x) 99)           ; => {:a {:x 99}}
```

---

## update-in                                                             *[generic]*

```
(update-in coll keys updater-fn)
```

Nested functional update. `keys` is a list of keys/indices forming a path.
Applies `updater-fn` to the value at the nested path.

### Examples

```fol
(update-in [10 20 30] '(1) inc)              ; => [10 21 30]
(update-in [{:a 1}] '(0 :a) inc)             ; => [{:a 2}]
(update-in {:a {:x 10}} '(:a :x) inc)        ; => {:a {:x 11}}
```

---

## subvec                                                                *[function]*

```
(subvec v start)
(subvec v start end)
```

Returns a new vector containing elements from `start` (inclusive) to `end`
(exclusive). If `end` is not supplied, returns elements from `start` to the end
of the vector. Signals an error if indices are out of bounds.

### Examples

```fol
(subvec [1 2 3 4 5] 1 3)   ; => [2 3]
(subvec [1 2 3 4 5] 2)     ; => [3 4 5]
(subvec [1 2 3 4 5] 0 0)   ; => []
```

---

## replace                                                               *[function]*

```
(replace smap coll)
```

Given a dict `smap` and a vector `coll`, returns a new vector with any elements
that are keys in `smap` replaced by the corresponding values. Elements not found
in `smap` are left unchanged.

### Examples

```fol
(replace {2 :two 4 :four} [4 2 3 4 5])   ; => [:four :two 3 :four 5]
(replace {99 :x} [1 2 3])                 ; => [1 2 3]  (no matches)
```

---

## rseq                                                                  *[generic]*

```
(rseq coll)
```

Returns the elements of a reversible collection in reverse order as a CL list.
Supported on vectors, sorted sets, and sorted dicts. Returns nil for empty collections.

### Examples

```fol
(rseq [10 20 30])   ; => (30 20 10)
(rseq [42])          ; => (42)
(rseq [])            ; => nil

;; Works on sorted sets:
(rseq (sorted-set nil 3 1 4 1 5))  ; => (5 4 3 1)
(rseq (int-set 10 30 20))          ; => (30 20 10)

;; Works on sorted dicts:
(rseq (<sorted-dict> :a 1 :b 2 :c 3))  ; => ((:c . 3) (:b . 2) (:a . 1))
```

---

## reduce-kv                                                             *[generic]*

```
(reduce-kv fn init coll)
```

Reduces a collection with a 3-argument function `(fn acc key val)`. For vectors,
`key` is the element index. For dicts, `key` is the dict key. Returns the
accumulated result.

### Examples

```fol
(reduce-kv (fn [acc i v] (+ acc (* i v))) 0 [10 20 30])
  ; => 80   (0*10 + 1*20 + 2*30)

(reduce-kv (fn [acc k v] (+ acc v)) 0 {:a 1 :b 2 :c 3})
  ; => 6
```

---

## bounded-size                                                        *[function]*

```
(bounded-size n coll)
```

If COLL has O(1) size (vectors, dicts, sets, FOL lists), returns its actual
size.  Otherwise counts at most N elements by traversing the sequence.  Useful
for checking whether a potentially lazy or expensive-to-count collection has at
least N elements without forcing a full traversal.

Based on Clojure's `bounded-count`.

### Examples

```fol
;; O(1) counted collections return actual size (even if > n)
(bounded-size 5 [1 2 3])           ; => 3
(bounded-size 3 [1 2 3 4 5 6 7])   ; => 7
(bounded-size 2 {:a 1 :b 2 :c 3})  ; => 3

;; Lazy sequences stop counting at n
(bounded-size 5 (lazy-seq ...))     ; => at most 5

;; CL lists stop counting at n
(bounded-size 3 '(a b c d e f g))  ; => 3

;; Nil returns 0
(bounded-size 10 nil)               ; => 0
```

---

## distinct?                                                           *[function]*

```
(distinct?)
(distinct? x)
(distinct? x y)
(distinct? x y & more)
```

Returns true if no two of the arguments are equal (via `equal`).  With zero or
one argument, always returns true.

### Examples

```fol
(distinct? 1 2 3)       ; => true
(distinct? 1 2 3 1)     ; => false
(distinct? "a" "b" "c") ; => true
(distinct? :a :b :a)    ; => false
(distinct? 1)            ; => true
(distinct?)              ; => true
```

---

## every?                                                              *[function]*

```
(every? pred coll)
```

Returns true if `(pred x)` is logically true for every element `x` in `coll`.
Returns true for empty collections (vacuous truth).

### Examples

```fol
(every? odd? [1 3 5])   ; => true
(every? odd? [1 2 3])   ; => false
(every? pos? [])         ; => true
(every? even? #{2 4 6})  ; => true
```

---

## not-every?                                                          *[function]*

```
(not-every? pred coll)
```

Returns true if `(pred x)` is logically false for at least one element `x` in
`coll`.  Complement of `every?`.

### Examples

```fol
(not-every? odd? [1 2 3])   ; => true
(not-every? odd? [1 3 5])   ; => false
(not-every? pos? [])          ; => false
```

---

## not-any?                                                            *[function]*

```
(not-any? pred coll)
```

Returns true if `(pred x)` is logically false for every element `x` in `coll`.
Returns false if the predicate is true for at least one element.

### Examples

```fol
(not-any? odd? [2 4 6])   ; => true
(not-any? odd? [1 2 3])   ; => false
(not-any? pos? [])          ; => true
```

---

## into                                                                *[generic function]*

```
(into to from)
```

Adds all elements from FROM into TO using conj semantics. Returns a new
collection of the same type as TO. Dispatches on the target collection type
with specialized methods for each collection class.

For dicts, FROM elements must be (key . value) pairs (as returned by seq on a dict).
For lists, elements are prepended one at a time (Clojure conj semantics), so the
order of FROM elements is reversed in the result.

### Examples

```fol
;; Vector targets - elements appended
(into [1 2] [3 4 5])           ; => [1 2 3 4 5]
(into [] #{1 2 3})             ; => [1 2 3] (order may vary)

;; Dict targets - entries merged
(into {:a 1} {:b 2 :c 3})     ; => {:a 1 :b 2 :c 3}
(into {:a 1} {:a 99 :b 2})    ; => {:a 99 :b 2} (later values win)

;; Set targets - duplicates dropped
(into #{1 2} [2 3 4])          ; => #{1 2 3 4}
(into #{} [1 1 2 2 3])         ; => #{1 2 3}

;; List targets - elements prepended (reversed)
(into '() [1 2 3])             ; => (3 2 1)

;; Sorted collections maintain order
(into (<sorted-set> nil) [5 3 1 4 2])  ; => #S{1 2 3 4 5}

;; Bag targets - counts accumulate
(into (<bag>) [1 1 2 3 3 3])  ; => bag with 1->2, 2->1, 3->3

;; Preserves target type
(into (<ordered-dict> :a 1) {:b 2})  ; => ordered-dict
(into (<int-dict> 1 :a) {2 :b})     ; => int-dict
```

### Specialized Methods

| Target Type | Behavior |
|-------------|----------|
| `<vector>` | Appends elements to end |
| `<array>` | Appends elements to end (CL array) |
| `<dict>` | Inserts (key . value) pairs |
| `<ordered-dict>` | Inserts pairs, maintaining insertion order |
| `<array-dict>` | Inserts pairs, maintaining insertion order |
| `<sorted-dict>` | Inserts pairs in comparator order |
| `<int-dict>` | Inserts pairs in numeric key order |
| `<priority-dict>` | Inserts (key . priority) pairs |
| `<set>` | Inserts elements, dropping duplicates |
| `<ordered-set>` | Inserts elements, maintaining insertion order |
| `<sorted-set>` | Inserts elements in comparator order |
| `<int-set>` | Inserts integers in numeric order |
| `<bag>` | Counts element occurrences |
| `<list>` | Prepends elements (conj semantics) |
| `<deque>` | Appends elements to back |
| Other `<collection>` | Uses base reduce/conj protocol |

---

## add                                                                  *[function]*

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

## remove                                                               *[function]*

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

## disj                                                                 *[function]*

```
(disj set & keys)
```

Returns a new set with the specified keys removed. Works on all set types.

### Examples

```fol
(disj #{1 2 3} 2)           ; => #{1 3}
(disj #{1 2 3} 2 3)         ; => #{1}
(disj (&lt;sorted-set&gt; 1 2 3) 2) ; => #S{1 3}
(disj #{1 2 3} 4)           ; => #{1 2 3} (no change if not present)
```

---

## Set Operations

FOL provides comprehensive set operations that work across all set types.

### union                                                               *[function]*

```
(union set1 set2 & more-sets)
```

Returns a new set containing all elements from all input sets.
The result type matches the type of the first set.

```fol
(union #{1 2} #{2 3})                  ; => #{1 2 3}
(union (<sorted-set> 1 2) #{3 4})        ; => #S{1 2 3 4}
(union #{1} #{2} #{3})                 ; => #{1 2 3}
```

---

### difference                                                          *[function]*

```
(difference set1 set2)
```

Returns a new set containing elements in set1 but not in set2.

```fol
(difference #{1 2 3} #{2})             ; => #{1 3}
(difference (<sorted-set> 1 2 3) #{2 3}) ; => #S{1}
(difference #{1 2} #{3 4})             ; => #{1 2}
```

---

### intersection                                                        *[function]*

```
(intersection set1 set2 & more-sets)
```

Returns a new set containing only elements present in all input sets.

```fol
(intersection #{1 2 3} #{2 3 4})       ; => #{2 3}
(intersection #{1 2} #{2 3} #{2 4})    ; => #{2}
(intersection (<sorted-set> 1 2 3) #{2}) ; => #S{2}
```

---

### select                                                              *[function]*

```
(select pred set)
```

Returns a new set containing only elements that satisfy the predicate.
Similar to `filter` but returns a set of the same type.

```fol
(select odd? #{1 2 3 4 5})             ; => #{1 3 5}
(select (fn [x] (> x 2)) (<sorted-set> 1 2 3 4)) ; => #S{3 4}
```

---

### subset?                                                             *[function]*

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

### superset?                                                           *[function]*

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

### subseq                                                              *[generic]*

```
(subseq sc test key)
(subseq sc start-test start-key end-test end-key)
```

Returns a CL list of elements from a sorted collection that satisfy the given
range tests, in sorted order. Supported on sorted sets (`<sorted-set>`,
`<int-set>`) and sorted dicts (`<sorted-dict>`, `<int-dict>`).

TEST and END-TEST are comparison operator symbols: `>=`, `>`, `<=`, `<`.

```fol
;; Sorted sets:
(subseq (sorted-set nil 1 2 3 4 5) >= 3)       ; => (3 4 5)
(subseq (sorted-set nil 1 2 3 4 5) > 3)        ; => (4 5)
(subseq (sorted-set nil 1 2 3 4 5) <= 3)       ; => (1 2 3)
(subseq (sorted-set nil 1 2 3 4 5) >= 2 < 5)   ; => (2 3 4)
(subseq (int-set 10 20 30 40 50) >= 30)         ; => (30 40 50)

;; Sorted dicts (returns (key . value) pairs):
(subseq (<sorted-dict> :a 1 :b 2 :c 3 :d 4) >= :b)       ; => ((:b . 2) (:c . 3) (:d . 4))
(subseq (<sorted-dict> :a 1 :b 2 :c 3 :d 4) >= :b < :d)  ; => ((:b . 2) (:c . 3))
```

---

### rsubseq                                                             *[generic]*

```
(rsubseq sc test key)
(rsubseq sc start-test start-key end-test end-key)
```

Like `subseq`, but returns elements in reverse sorted order. Supported on
sorted sets (`<sorted-set>`, `<int-set>`) and sorted dicts (`<sorted-dict>`,
`<int-dict>`).

```fol
;; Sorted sets:
(rsubseq (sorted-set nil 1 2 3 4 5) <= 3)      ; => (3 2 1)
(rsubseq (sorted-set nil 1 2 3 4 5) >= 2 < 5)  ; => (4 3 2)

;; Sorted dicts (returns (key . value) pairs in reverse order):
(rsubseq (<sorted-dict> :a 1 :b 2 :c 3 :d 4) <= :c)  ; => ((:c . 3) (:b . 2) (:a . 1))
```

---

## Specialized Set Types

FOL provides several specialized set implementations for different use cases.

### `<sorted-set>` - Sorted Set                                          *[class]*

A persistent set that maintains elements in natural sorted order.

```fol
(<sorted-set> 3 1 4 1 5 9 2)  ; => #S{1 2 3 4 5 9}
(seq (<sorted-set> 3 1 2))    ; => (1 2 3) - elements in sorted order
```

### `<ordered-set>` - Insertion-Order Set                                *[class]*

A persistent set that maintains elements in insertion order.

```fol
(<ordered-set> 3 1 4 1 5)     ; => #O{3 1 4 5} - preserves insertion order
(seq (<ordered-set> 3 1 4))   ; => (3 1 4) - first inserted first
```

### `<int-set>` - Integer Set                                            *[class]*

A sorted set optimized for integers. Only accepts integer elements.

```fol
(<int-set> 5 3 8 1)           ; => #S{1 3 5 8}
(<int-set> 1 2 "a")           ; ERROR: only integers allowed
```

### `<dense-int-set>` - Dense Integer Set                                *[class]*

A set optimized for dense integer ranges using bit vectors. Requires specifying the range bounds.

```fol
(make-dense-int-set 0 10 1 3 5 7 9)  ; => #D{1 3 5 7 9}
```

### `<sorted-set-by>` - Custom Comparator Sorted Set                     *[class]*

A sorted set that uses a custom comparator function to determine element ordering.

```fol
;; Sort by descending order
(<sorted-set-by> > 3 1 4 1 5 9)        ; => #S<cmp>{9 5 4 3 1}

;; Sort strings by length
(<sorted-set-by> (fn [a b] (< (size a) (size b))) "cat" "elephant" "dog")
                                     ; => #S<cmp>{"cat" "dog" "elephant"}
```

### Set Constructor Functions

| Function | Creates | Description |
|----------|---------|-------------|
| `<set>` | `<set>` | Hash set (unordered) |
| `<sorted-set>` | `<sorted-set>` | Sorted set (natural ordering) |
| `<sorted-set-by>` | `<sorted-set-by>` | Sorted set with custom comparator |
| `<ordered-set>` | `<ordered-set>` | Insertion-order set |
| `<int-set>` | `<int-set>` | Integer-only sorted set |
| `<dense-int-set>` | `<dense-int-set>` | Dense integer range set (requires min/max bounds) |

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

### rseq                                                                *[function]*

```
(rseq coll)
```

Returns a sequence of the collection's elements in reverse order.

```fol
(rseq [1 2 3])                  ; => (3 2 1)
(rseq (<sorted-set> 1 2 3 4 5))   ; => (5 4 3 2 1)
(rseq (<ordered-set> 3 1 4))      ; => (4 1 3)
(rseq [])                       ; => nil
```

---

### subs                                                                *[function]*

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
(subs (<sorted-set> 1 3 5 7 9) 3 7)  ; => (3 5) - elements >= 3 and < 7
```

---

### rsubs                                                               *[function]*

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
(rsubs (<sorted-set> 1 3 5 7 9) 3 8)  ; => (7 5 3) - elements >= 3 and < 8, reversed
```

---

## Deque (Double-Ended Queue)

The `<deque>` is a persistent double-ended queue that supports efficient O(log n)
operations at both the front and back. Inherits from `<vector>` and uses FSet seq
storage. Supports standard operations (`peek`/`pop` from front, `push`/`conj` to
back) and reverse operations (`rpeek`/`rpop` from back, `rpush`/`rconj` to front).

### Creating Deques

```fol
(deque)               ; => #Q[]
(deque 1 2 3)         ; => #Q[1 2 3]
#Q[1 2 3]             ; reader syntax
```

### Deque Operations

| Function | Description |
|----------|-------------|
| `peek`   | Returns the front element |
| `pop`    | Returns deque without front element |
| `push`   | Returns deque with element added at back |
| `conj`   | Returns deque with element added at back |
| `rpeek`  | Returns the back element |
| `rpop`   | Returns deque without back element |
| `rpush`  | Returns deque with element added at front |
| `rconj`  | Returns deque with element added at front |

### Examples

```fol
(def dq (deque 1 2 3))

;; Standard operations (front read, back write)
(peek dq)                ; => 1
(pop dq)                 ; => #Q[2 3]
(push dq 4)              ; => #Q[1 2 3 4]

;; Reverse operations (back read, front write)
(rpeek dq)               ; => 3
(rpop dq)                ; => #Q[1 2]
(rpush dq 0)             ; => #Q[0 1 2 3]

;; Other collection operations
(size dq)                 ; => 3
(empty? dq)               ; => false
(get dq 1)                ; => 2
(contains? dq 2)          ; => true
(seq dq)                  ; => (1 2 3)
(conj dq 4 5)             ; => #Q[1 2 3 4 5]
```

### When to Use Deques

- When you need efficient operations at both ends of a sequence
- Implementing queues (FIFO) or stacks (LIFO)
- Sliding window algorithms
- When you want vector-like indexing with efficient front insertion

---

## Specialized Dict Types

FOL provides several specialized dictionary implementations optimized for different use cases.

### `<array-dict>` - Small Insertion-Order Dict                          *[class]*

A persistent dictionary optimized for small maps (up to 1000 entries) that maintains
insertion order. Ideal for small configuration maps or data structures where order matters.

```fol
(<array-dict> :z 3 :a 1 :m 2)    ; => {|:z 3 :a 1 :m 2|}
(seq (<array-dict> :z 3 :a 1))   ; => ([:z 3] [:a 1]) - insertion order preserved

;; Limited to 1000 entries
(array-dict-with-limit 5 :a 1 :b 2 :c 3)  ; => {|:a 1 :b 2 :c 3|}
```

---

### `<sorted-dict>` - Sorted Dictionary                                  *[class]*

A persistent dictionary that maintains keys in sorted order using a SYCAMORE tree-map.
Provides efficient O(log n) lookup and maintains natural ordering of keys.

```fol
(<sorted-dict> :c 3 :a 1 :b 2)   ; => {<:a 1 :b 2 :c 3>}
(keys (<sorted-dict> :z 26 :a 1 :m 13))  ; => (:a :m :z) - sorted order
```

---

### `<ordered-dict>` - Insertion-Order Dictionary                        *[class]*

A persistent dictionary that maintains insertion order for any number of entries.
Like array-dict but without the size limit.

```fol
(<ordered-dict> :z 3 :a 1 :m 2)  ; => {#:z 3 :a 1 :m 2#}
(seq (<ordered-dict> :z 3 :a 1 :m 2))  ; => ([:z 3] [:a 1] [:m 2])
```

---

### `<priority-dict>` - Priority Queue Dictionary                        *[class]*

A persistent dictionary that maintains entries sorted by their values (priorities).
Useful as a priority queue where keys map to priorities.

```fol
(<priority-dict> :low 10 :high 100 :mid 50)  ; => {^:low 10 :mid 50 :high 100^}
(keys (<priority-dict> :low 10 :high 100 :mid 50))  ; => (:low :mid :high)
```

---

### `<int-dict>` - Integer-Key Dictionary                                *[class]*

A sorted dictionary optimized for integer keys. Only accepts integers as keys.
Maintains keys in numerically sorted order.

```fol
(<int-dict> 3 "c" 1 "a" 2 "b")   ; => {1 "a" 2 "b" 3 "c"}
(<int-dict> 42 "x" 7 "y")        ; => {7 "y" 42 "x"}
(<int-dict> :a 1)                ; ERROR: only integer keys allowed
```

---

### Dict Constructor Functions

| Function | Creates | Description |
|----------|---------|-------------|
| `<dict>` | `<dict>` | Standard hash map (unordered) |
| `<array-dict>` | `<array-dict>` | Small insertion-order map (≤1000 entries) |
| `array-dict-with-limit` | `<array-dict>` | Insertion-order map with custom size limit |
| `<sorted-dict>` | `<sorted-dict>` | Sorted map (natural key ordering) |
| `sorted-dict-by` | `<sorted-dict>` | Sorted map with custom comparator |
| `<ordered-dict>` | `<ordered-dict>` | Insertion-order map (unlimited size) |
| `<priority-dict>` | `<priority-dict>` | Priority queue map (sorted by values) |
| `<int-dict>` | `<int-dict>` | Integer-key sorted map |

---

## Dict Operations

These functions work specifically on dict types (`<dict>`, `<ordered-dict>`, `<sorted-dict>`, etc.).

### assoc                                                                *[generic]*

```
(assoc coll key value & kvs)
```

Returns a new collection with key-value pairs added or updated. For vectors,
key is an index. For dicts, key is the dict key. Accepts multiple key-value
pairs.

```fol
(assoc {:a 1 :b 2} :c 3)              ; => {:a 1 :b 2 :c 3}
(assoc {:a 1} :a 99)                   ; => {:a 99} (overwrites)
(assoc {:a 1} :b 2 :c 3)              ; => {:a 1 :b 2 :c 3}
(assoc [10 20 30] 1 99)               ; => [10 99 30]
```

---

### dissoc                                                               *[generic]*

```
(dissoc coll & keys)
```

Returns a new dict with the specified keys removed. Dict types only.

```fol
(dissoc {:a 1 :b 2 :c 3} :b)          ; => {:a 1 :c 3}
(dissoc {:a 1 :b 2 :c 3} :a :c)       ; => {:b 2}
(dissoc {:a 1} :z)                     ; => {:a 1} (no change if key absent)
```

---

### find                                                                 *[generic]*

```
(find coll key)
```

Returns the map entry `(key . value)` for KEY in COLL, or NIL if not found.

```fol
(find {:a 1 :b 2} :a)                 ; => (:a . 1)
(find {:a 1 :b 2} :c)                 ; => nil
(find (<sorted-dict> :a 1 :b 2) :b)   ; => (:b . 2)
```

---

### get-in                                                               *[generic]*

```
(get-in coll keys)
(get-in coll keys not-found)
```

Looks up a nested path of keys in COLL. Returns NOT-FOUND if the path does
not exist (defaults to NIL). Works on dicts and vectors.

```fol
(get-in {:a {:b 1}} '(:a :b))         ; => 1
(get-in {:a {:b 1}} '(:a :c) :nope)   ; => :nope
(get-in {:settings {:theme {:color "blue"}}} '(:settings :theme :color))
                                        ; => "blue"
(get-in [10 [20 30]] '(1 0))          ; => 20
```

---

### keys                                                                 *[function]*

```
(keys dict)
```

Returns a vector of all keys in DICT. Order depends on dict type:
ordered/sorted dicts maintain their respective order.

```fol
(keys {:a 1 :b 2 :c 3})               ; => [:a :b :c] (order may vary)
(keys (<sorted-dict> :c 3 :a 1 :b 2)) ; => [:a :b :c]
(keys (<ordered-dict> :z 3 :a 1))     ; => [:z :a]
```

---

### vals                                                                 *[function]*

```
(vals dict)
```

Returns a vector of all values in DICT. Order matches the dict's key order.

```fol
(vals {:a 1 :b 2})                     ; => [1 2] (order may vary)
(vals (<sorted-dict> :c 3 :a 1 :b 2)) ; => [1 2 3]
(vals (<ordered-dict> :z 3 :a 1))     ; => [3 1]
```

---

### key                                                                  *[function]*

```
(key entry)
```

Returns the key of a map entry (cons pair). Map entries are returned by
`find` and by iterating over dicts with `seq`.

```fol
(key (find {:a 1} :a))                ; => :a
(key (first (seq {:x 42})))           ; => :x
```

---

### val                                                                  *[function]*

```
(val entry)
```

Returns the value of a map entry (cons pair).

```fol
(val (find {:a 1} :a))                ; => 1
(val (first (seq {:x 42})))           ; => 42
```

---

### merge                                                                *[generic]*

```
(merge coll & colls)
```

Merges dicts together. Later values win on key conflicts. The result type
matches the first argument.

```fol
(merge {:a 1} {:b 2} {:c 3})          ; => {:a 1 :b 2 :c 3}
(merge {:a 1 :b 2} {:b 99 :c 3})      ; => {:a 1 :b 99 :c 3}
(merge (<sorted-dict> :a 1) {:b 2})   ; => sorted-dict {:a 1 :b 2}
```

---

### merge-with                                                           *[generic]*

```
(merge-with f coll & colls)
```

Merges dicts together. When a key exists in both, applies F to the existing
and new values: `(f val-in-result val-in-other)`. Keys unique to either dict
are included as-is.

```fol
(merge-with + {:a 1 :b 2} {:a 10 :c 3})   ; => {:a 11 :b 2 :c 3}
(merge-with str {:a "x"} {:a "y"} {:a "z"}) ; => {:a "xyz"}
(merge-with + (<sorted-dict> :a 1) {:a 2}) ; => sorted-dict {:a 3}
```

---

### update                                                               *[generic]*

```
(update coll key updater-fn)
```

Returns a new collection with the value at KEY transformed by applying
UPDATER-FN to its current value. Works on dicts and vectors.

```fol
(update {:a 1 :b 2} :a inc)           ; => {:a 2 :b 2}
(update [10 20 30] 1 inc)             ; => [10 21 30]
(update {:count 0} :count inc)        ; => {:count 1}
```

---

### select-keys                                                          *[function]*

```
(select-keys dict keys)
```

Returns a new dict containing only the entries whose keys are in KEYS.
Preserves the dict type.

```fol
(select-keys {:a 1 :b 2 :c 3} '(:a :c))      ; => {:a 1 :c 3}
(select-keys {:a 1 :b 2} '(:b :z))            ; => {:b 2}
(select-keys (<sorted-dict> :a 1 :b 2 :c 3) '(:a :c))
                                                ; => sorted-dict {:a 1 :c 3}
```

---

### rename-keys                                                          *[function]*

```
(rename-keys dict kmap)
```

Returns a new dict with keys renamed according to KMAP (a dict mapping old
keys to new keys). Keys not in KMAP are kept unchanged.

```fol
(rename-keys {:a 1 :b 2} {:a :x})             ; => {:x 1 :b 2}
(rename-keys {:a 1 :b 2 :c 3} {:a :x :b :y}) ; => {:x 1 :y 2 :c 3}
(rename-keys {:a 1} {:z :q})                  ; => {:a 1} (no matching keys)
```

---

### map-invert                                                           *[function]*

```
(map-invert dict)
```

Returns a new dict with keys and values swapped. If multiple keys map to
the same value, one will be arbitrarily chosen as the key.

```fol
(map-invert {:a 1 :b 2})              ; => {1 :a 2 :b}
(map-invert {1 :x 2 :y 3 :z})        ; => {:x 1 :y 2 :z 3}
```

---

### update-keys                                                          *[function]*

```
(update-keys dict f)
```

Returns a new dict with F applied to each key, values unchanged.

```fol
(update-keys {1 :a 2 :b} #'1+)        ; => {2 :a 3 :b}
```

---

### update-vals                                                          *[function]*

```
(update-vals dict f)
```

Returns a new dict with F applied to each value, keys unchanged.

```fol
(update-vals {:a 1 :b 2} inc)         ; => {:a 2 :b 3}
(update-vals {:a "hello" :b "world"} str-upper-case)
                                        ; => {:a "HELLO" :b "WORLD"}
(update-vals (<sorted-dict> :a 1 :b 2) inc) ; => sorted-dict {:a 2 :b 3}
```

---

