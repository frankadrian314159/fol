# CL List Compatibility Functions

These functions provide compatibility with Common Lisp list operations.

Note: `first`, `rest`, `nth`, and `size` are now generic collection functions
that work on all collection types (vectors, lists, dicts, sets, strings).
See [collections.md](collections.md) for their documentation.

## list

```
(list & args)
```

Creates a CL-style list (cons cell chain) containing the given arguments.

### Examples

```fol
(list 1 2 3)         ; => (1 2 3)
(list)               ; => nil
(list 'a 'b 'c)      ; => (a b c)
(list [1 2] {:a 1})  ; => ([1 2] {:a 1})
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
