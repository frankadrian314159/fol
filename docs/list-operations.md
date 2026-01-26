# List Operations

These functions work with FOL lists and provide Clojure-style list operations.

Note: `first`, `rest`, `nth`, and `size` are generic collection functions
that work on all collection types (vectors, lists, dicts, sets, strings).
See [collections.md](collections.md) for their documentation.

## list

```
(list & args)
```

Creates a FOL `<list>` containing the given arguments. This is the primary way to create persistent lists in FOL.

### Examples

```fol
(list 1 2 3)         ; => (1 2 3) - a FOL <list>
(list)               ; => () - empty FOL <list>
(list 'a 'b 'c)      ; => (a b c)
(list [1 2] {:a 1})  ; => ([1 2] {:a 1})
```

---

## cons

```
(cons x coll)
```

Returns a new seq where x is the first element and coll is the rest. This is the Clojure-style cons that prepends to collections.

### Examples

```fol
(cons 1 (list 2 3))     ; => (1 2 3)
(cons 0 [1 2 3])        ; => (0 1 2 3)
(cons :a nil)           ; => (:a)
(cons 1 (cons 2 nil))   ; => (1 2)
```

---

## list*

```
(list* & args)
```

Creates a new list containing the items prepended to the rest, where the last argument is treated as a sequence. Similar to Clojure's `list*`.

### Examples

```fol
(list* 1 2 [3 4])       ; => (1 2 3 4)
(list* 1 [2 3])         ; => (1 2 3)
(list* [1 2 3])         ; => (1 2 3)
(list* 1 2 3 nil)       ; => (1 2 3)
```

---

## peek

```
(peek coll)
```

For a list, returns the first element. Returns nil if the collection is empty.

### Examples

```fol
(peek (list 1 2 3))     ; => 1
(peek (list))           ; => nil
(peek nil)              ; => nil
```

---

## pop

```
(pop coll)
```

Returns a new collection without one element. The element removed depends on the collection type:
- For lists: removes the first element (front)
- For vectors: removes the last element (end)

Returns nil for empty lists, empty vector for empty vectors.

### Examples

```fol
;; List examples (removes from front)
(pop (list 1 2 3))      ; => (2 3)
(pop (list 1))          ; => ()
(pop (list))            ; => nil
(pop nil)               ; => nil

;; Vector examples (removes from end)
(pop [1 2 3])           ; => [1 2]
(pop [1])               ; => []
(pop [])                ; => []
```

---

## push

```
(push item coll)
```

Returns a new collection with item added. The position depends on the collection type:
- For lists: adds to the front (like cons)
- For vectors: adds to the end (like conj)

### Examples

```fol
;; List examples (adds to front)
(push 0 (list 1 2 3))   ; => (0 1 2 3)
(push 1 (list))         ; => (1)
(push 1 nil)            ; => (1)

;; Vector examples (adds to end)
(push 4 [1 2 3])        ; => [1 2 3 4]
(push 1 [])             ; => [1]
```

---

## append

```
(append & lists)
```

Concatenates CL-style lists together. Returns a new list containing all elements.

### Examples

```fol
(append '(1 2) '(3 4))       ; => (1 2 3 4)
(append '(a) '(b) '(c d))    ; => (a b c d)
(append '() '(1 2))          ; => (1 2)
(append)                     ; => nil
```

---

## reverse

```
(reverse sequence)
```

Returns a new sequence with elements in reverse order.

### Examples

```fol
(reverse '(1 2 3))   ; => (3 2 1)
(reverse '())        ; => nil
(reverse "hello")    ; => "olleh"
```
