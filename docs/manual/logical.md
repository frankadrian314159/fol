# Logical Functions

## not                                                                  *[function]*

```
(not x)
```

Returns true if x is nil or false, false otherwise.

### Examples

```fol
(not false)    ; => true
(not nil)      ; => true
(not true)     ; => false
(not 1)        ; => false
(not "hello")  ; => false
```

---

## and                                                                     *[macro]*

```
(and & args)
```

Evaluates arguments left to right, returning the first falsey value (nil or false),
or the last value if all are truthy. With no arguments, returns true.

### Examples

```fol
(and true true)       ; => true
(and true false)      ; => false
(and 1 2 3)           ; => 3
(and 1 nil 3)         ; => nil
(and)                 ; => true
(and "a" "b" "c")     ; => "c"
```

---

## or                                                                      *[macro]*

```
(or & args)
```

Evaluates arguments left to right, returning the first truthy value,
or the last value if all are falsey. With no arguments, returns nil.

### Examples

```fol
(or true false)       ; => true
(or false true)       ; => true
(or nil nil)          ; => nil
(or nil 1 2)          ; => 1
(or)                  ; => nil
(or false false 3)    ; => 3
```

---

## xor                                                                  *[function]*

```
(xor & args)
```

Returns true if an odd number of arguments are truthy.
For two arguments, returns true if exactly one is truthy.

### Examples

```fol
(xor true false)      ; => true
(xor true true)       ; => false
(xor false false)     ; => false
(xor true false true) ; => false (two are true)
```

---

## implies                                                              *[function]*

```
(implies a b)
```

Logical implication (if a then b). Equivalent to `(or (not a) b)`.
Returns false only when a is true and b is false.

### Examples

```fol
(implies true true)   ; => true
(implies true false)  ; => false
(implies false true)  ; => true
(implies false false) ; => true
```

---

## nand                                                                 *[function]*

```
(nand & args)
```

Logical NAND (NOT AND). Returns the negation of AND.

### Examples

```fol
(nand true true)      ; => false
(nand true false)     ; => true
(nand false false)    ; => true
```

---

## nor                                                                  *[function]*

```
(nor & args)
```

Logical NOR (NOT OR). Returns the negation of OR.

### Examples

```fol
(nor false false)     ; => true
(nor true false)      ; => false
(nor true true)       ; => false
```
