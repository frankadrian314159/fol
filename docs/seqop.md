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
