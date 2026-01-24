# Comparison Functions

## =

```
(= x)
(= x y)
(= x y & more)
```

Returns true if all arguments are numerically equal. With one argument, always returns true.

### Examples

```fol
(= 1 1)        ; => true
(= 1 2)        ; => false
(= 1 1 1 1)    ; => true
(= 1 1 2)      ; => false
(= 1.0 1)      ; => true
(= 1/2 0.5)    ; => true
```

---

## /=

```
(/= x)
(/= x y)
(/= x y & more)
```

Returns true if no two arguments are equal. With one argument, always returns true.

### Examples

```fol
(/= 1 2)       ; => true
(/= 1 1)       ; => false
(/= 1 2 3)     ; => true
(/= 1 2 1)     ; => false (1 appears twice)
```

---

## <

```
(< x)
(< x y)
(< x y & more)
```

Returns true if arguments are in strictly increasing order.

### Examples

```fol
(< 1 2)        ; => true
(< 2 1)        ; => false
(< 1 2 3 4)    ; => true
(< 1 2 2 3)    ; => false (2 is not less than 2)
```

---

## >

```
(> x)
(> x y)
(> x y & more)
```

Returns true if arguments are in strictly decreasing order.

### Examples

```fol
(> 2 1)        ; => true
(> 1 2)        ; => false
(> 4 3 2 1)    ; => true
(> 3 2 2 1)    ; => false (2 is not greater than 2)
```

---

## <=

```
(<= x)
(<= x y)
(<= x y & more)
```

Returns true if arguments are in monotonically non-decreasing order.

### Examples

```fol
(<= 1 2)       ; => true
(<= 1 1)       ; => true
(<= 1 2 2 3)   ; => true
(<= 2 1)       ; => false
```

---

## >=

```
(>= x)
(>= x y)
(>= x y & more)
```

Returns true if arguments are in monotonically non-increasing order.

### Examples

```fol
(>= 2 1)       ; => true
(>= 1 1)       ; => true
(>= 3 2 2 1)   ; => true
(>= 1 2)       ; => false
```

---

## min

```
(min x)
(min x y)
(min x y & more)
```

Returns the minimum of its arguments.

### Examples

```fol
(min 3 1 2)    ; => 1
(min 5)        ; => 5
(min -1 0 1)   ; => -1
(min 1.5 2)    ; => 1.5
```

---

## max

```
(max x)
(max x y)
(max x y & more)
```

Returns the maximum of its arguments.

### Examples

```fol
(max 3 1 2)    ; => 3
(max 5)        ; => 5
(max -1 0 1)   ; => 1
(max 1.5 2)    ; => 2
```
