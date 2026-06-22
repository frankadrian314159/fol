# Array Operations (Phase 1: Generic Operators)

Generic operators for element-wise operations on vectors and arrays in FOL. These operators extend Common Lisp's scalar operations to work on collections with automatic broadcasting.

## Overview

Phase 1 provides vectorized versions of arithmetic, comparison, and logical operators. All operators support:

- **Scalar operations**: Work on numbers as usual
- **Vector operations**: Apply element-wise to vector elements
- **Broadcasting**: Combine scalars and vectors element-wise
- **Varargs chains**: Chain multiple arguments with left-to-right reduction

---

## Arithmetic Operators

### +

```
(+ a b)
(+ a b c ...)
```

Addition with broadcasting support. When given vectors, applies element-wise addition.

- **Scalars**: Standard arithmetic: `(+ 1 2 3)` → `6`
- **Vectors**: Element-wise: `(+ [1 2 3] [4 5 6])` → `[5 7 9]`
- **Mixed**: Broadcasting: `(+ [1 2 3] 10)` → `[11 12 13]`
- **Varargs**: Left-to-right reduction: `(+ 1 2 3 4)` → `10`

### Examples

```fol
(+ 1 2 3)                           ; => 6
(+ [1 2 3] [4 5 6])                 ; => [5 7 9]
(+ [10 20 30] 5)                    ; => [15 25 35]
(+ 5 [10 20 30])                    ; => [15 25 35]
(+ [1 2] [3 4] [5 6])               ; => [9 12] (chains left-to-right)
```

---

### -

```
(- a)
(- a b)
(- a b c ...)
```

Subtraction with broadcasting support. Single argument returns negation.

- **Scalar negation**: `(- 5)` → `-5`
- **Scalar subtraction**: `(- 10 3)` → `7`
- **Vector subtraction**: `(- [5 7 9] [4 5 6])` → `[1 2 3]`
- **Broadcasting**: `(- [10 20 30] 5)` → `[5 15 25]`
- **Varargs**: `(- 100 10 20 5)` → `65`

### Examples

```fol
(- 5)                               ; => -5
(- 10 3)                            ; => 7
(- [5 7 9] [4 5 6])                 ; => [1 2 3]
(- [30 40 50] 5)                    ; => [25 35 45]
(- 100 10 20 5)                     ; => 65
```

---

### *

```
(* a b)
(* a b c ...)
```

Multiplication with broadcasting support.

- **Scalars**: `(* 3 4)` → `12`
- **Vectors**: Element-wise: `(* [1 2 3] [2 2 2])` → `[2 4 6]`
- **Broadcasting**: `(* [1 2 3] 5)` → `[5 10 15]`
- **Varargs**: `(* 2 3 4 5)` → `120`

### Examples

```fol
(* 3 4)                             ; => 12
(* [1 2 3] [2 2 2])                 ; => [2 4 6]
(* [2 3 4] 10)                      ; => [20 30 40]
(* 2 3 4 5)                         ; => 120
```

---

### /

```
(/ a b)
(/ a b c ...)
```

Division with broadcasting support.

- **Scalars**: `(/ 20 4)` → `5.0` (returns float)
- **Vectors**: Element-wise: `(/ [10 20 30] [2 2 2])` → `[5.0 10.0 15.0]`
- **Broadcasting**: `(/ [10 20 30] 2)` → `[5.0 10.0 15.0]`
- **Varargs**: `(/ 100 2 5)` → `10.0`

### Examples

```fol
(/ 20 4)                            ; => 5.0
(/ [10 20 30] [2 2 2])              ; => [5.0 10.0 15.0]
(/ [100 200 300] 10)                ; => [10.0 20.0 30.0]
(/ 100 2 5)                         ; => 10.0
```

---

## Comparison Operators

All comparison operators return boolean values (T/NIL for scalars, vectors of booleans for vectors).

### =

```
(= a b)
(= a b c ...)
```

Equality with broadcasting support.

- **Scalars**: `(= 5 5)` → `T`, `(= 5 3)` → `NIL`
- **Vectors**: Element-wise: `(= [1 2 3] [1 2 3])` → `[T T T]`
- **Mixed**: `(= [1 2 3] 2)` → `[NIL T NIL]`
- **Varargs**: All must be equal: `(= 5 5 5)` → `T`

### Examples

```fol
(= 5 5)                             ; => T
(= 5 3)                             ; => NIL
(= [1 2 3] [1 2 3])                 ; => [T T T]
(= [1 2 3] [1 2 4])                 ; => [T T NIL]
(= [5 5 5] 5)                       ; => [T T T]
(= 5 5 5)                           ; => T
```

---

### <

```
(< a b)
(< a b c ...)
```

Less-than comparison.

- **Scalars**: `(< 3 5)` → `T`
- **Vectors**: Element-wise: `(< [1 2 3] [2 3 4])` → `[T T T]`
- **Mixed**: `(< [1 2 3] 2)` → `[T NIL NIL]`

### Examples

```fol
(< 3 5)                             ; => T
(< 5 3)                             ; => NIL
(< [1 2 3] [2 3 4])                 ; => [T T T]
(< [1 2 3] 2)                       ; => [T NIL NIL]
(< 1 2 3)                           ; => T
```

---

### >

```
(> a b)
(> a b c ...)
```

Greater-than comparison.

### Examples

```fol
(> 5 3)                             ; => T
(> 3 5)                             ; => NIL
(> [4 5 6] [1 2 3])                 ; => [T T T]
(> [4 5 6] 5)                       ; => [NIL T T]
(> 3 2 1)                           ; => T
```

---

### <=

```
(<= a b)
(<= a b c ...)
```

Less-than-or-equal comparison.

### Examples

```fol
(<= 3 5)                            ; => T
(<= 5 5)                            ; => T
(<= 5 3)                            ; => NIL
(<= [1 2 3] [1 3 3])                ; => [T T T]
(= 1 2 3)                           ; => T (strict ordering)
```

---

### >=

```
(>= a b)
(>= a b c ...)
```

Greater-than-or-equal comparison.

### Examples

```fol
(>= 5 3)                            ; => T
(>= 5 5)                            ; => T
(>= 3 5)                            ; => NIL
(>= [3 3 3] [1 2 3])                ; => [T T T]
```

---

### not=

```
(not= a b)
```

Not-equal comparison (negation of `=`).

### Examples

```fol
(not= 5 3)                          ; => T
(not= 5 5)                          ; => NIL
(not= [1 2 3] [1 2 4])              ; => [NIL NIL T]
(not= [5 5 5] 5)                    ; => [NIL NIL NIL]
```

---

## Logical Operators

### and

```
(and a)
(and a b)
(and a b c ...)
```

Logical AND with proper falsy value semantics. Returns first falsy value or last value.

- **Scalars**: `(and T T)` → `T`, `(and T NIL)` → `NIL`
- **Vectors**: Element-wise: `(and [T T F] [T F T])` → `[T F F]`
- **Varargs**: `(and T 5 "hello")` → `"hello"` (returns last truthy)

### Examples

```fol
(and T T)                           ; => T
(and T NIL)                         ; => NIL
(and NIL T)                         ; => NIL
(and [T T F] [T F T])               ; => [T F F]
(and [T T T] T)                     ; => [T T T]
(and T 5 "hello")                   ; => "hello"
```

---

### or

```
(or a)
(or a b)
(or a b c ...)
```

Logical OR. Returns first truthy value or last value.

- **Scalars**: `(or NIL T)` → `T`
- **Vectors**: Element-wise: `(or [T F T] [F T F])` → `[T T T]`
- **Varargs**: `(or NIL NIL 5)` → `5`

### Examples

```fol
(or NIL T)                          ; => T
(or T NIL)                          ; => T
(or NIL NIL)                        ; => NIL
(or [T F T] [F T F])                ; => [T T T]
(or [F F F] [F T F])                ; => [F T F]
(or NIL NIL 5)                      ; => 5
```

---

### not

```
(not a)
```

Logical NOT with proper boolean semantics.

- **Scalar**: `(not T)` → `NIL`, `(not NIL)` → `T`
- **Vector**: Element-wise: `(not [T T F])` → `[NIL NIL T]`

### Examples

```fol
(not T)                             ; => NIL
(not NIL)                           ; => T
(not 5)                             ; => NIL (non-NIL is truthy)
(not [T F T])                       ; => [NIL T NIL]
(not [NIL NIL T])                   ; => [T T NIL]
```

---

## Broadcasting Rules

**Broadcasting** allows combining scalars and vectors:

1. **Scalar OP Vector**: Apply operation between scalar and each vector element
2. **Vector OP Scalar**: Apply operation between each vector element and scalar
3. **Vector OP Vector**: Apply element-wise (both vectors must have same length)

### Examples

```fol
(+ 10 [1 2 3])                      ; => [11 12 13]
(+ [1 2 3] 10)                      ; => [11 12 13]
(* [1 2 3] [2 2 2])                 ; => [2 4 6]
(< [1 2 3] 2)                       ; => [T NIL NIL]
```

---

## Varargs Reduction

All operators support multiple arguments, reducing left-to-right:

```fol
(+ 1 2 3 4)                         ; (((1 + 2) + 3) + 4) => 10
(* 2 3 4 5)                         ; (((2 * 3) * 4) * 5) => 120
(and T T T)                         ; ((T and T) and T) => T
```

---

## Performance Notes

- Vector operations are implemented using `mapv` for element-wise application
- Broadcasting leverages CLOS generic functions for type dispatch
- Mixed-arity operations chain via repeated binary application
- Comparison operators return vectors of booleans, not a single boolean

---

## See Also

- [[adverbs.md]] - Phase 2: Axis-aware operations (fold, scan, sum, mean, etc.)
- [[sequences.md]] - Sequence operations (map, filter, reduce, etc.)
- [[collections.md]] - Collection predicates and constructors
