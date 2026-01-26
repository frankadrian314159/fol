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
