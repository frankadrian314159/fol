# Type Predicates

Type predicates return true if the argument is of the specified type, false otherwise.

## <bool>?

```
(<bool>? x)
```

Returns true if x is a boolean (true or false).

### Examples

```fol
(<bool>? true)      ; => true
(<bool>? false)     ; => true
(<bool>? nil)       ; => true (nil is boolean false)
(<bool>? 0)         ; => false
(<bool>? "true")    ; => false
```

---

## <char>?

```
(<char>? x)
```

Returns true if x is a character.

### Examples

```fol
(<char>? \a)        ; => true
(<char>? \newline)  ; => true
(<char>? "a")       ; => false (string, not char)
(<char>? 65)        ; => false (integer, not char)
```

---

## <number>?

```
(<number>? x)
```

Returns true if x is any kind of number (integer, float, ratio, complex).

### Examples

```fol
(<number>? 42)      ; => true
(<number>? 3.14)    ; => true
(<number>? 1/2)     ; => true
(<number>? "42")    ; => false
```

---

## <integer>?

```
(<integer>? x)
```

Returns true if x is an integer (fixnum or bignum).

### Examples

```fol
(<integer>? 42)     ; => true
(<integer>? -5)     ; => true
(<integer>? 3.0)    ; => false
(<integer>? 1/2)    ; => false
```

---

## <fixnum>?

```
(<fixnum>? x)
```

Returns true if x is a fixnum (small integer that fits in a machine word).

### Examples

```fol
(<fixnum>? 42)                      ; => true
(<fixnum>? 1000000000000000000000)  ; => false (bignum)
```

---

## <bignum>?

```
(<bignum>? x)
```

Returns true if x is a bignum (arbitrary precision integer).

### Examples

```fol
(<bignum>? 42)                      ; => false (fixnum)
(<bignum>? 1000000000000000000000)  ; => true
```

---

## <float>?

```
(<float>? x)
```

Returns true if x is a floating-point number.

### Examples

```fol
(<float>? 3.14)     ; => true
(<float>? 42)       ; => false
(<float>? 1/2)      ; => false
```

---

## <single-float>?

```
(<single-float>? x)
```

Returns true if x is a single-precision float.

### Examples

```fol
(<single-float>? 3.14f0)  ; => true
(<single-float>? 3.14d0)  ; => false (double)
```

---

## <double-float>?

```
(<double-float>? x)
```

Returns true if x is a double-precision float.

### Examples

```fol
(<double-float>? 3.14d0)  ; => true
(<double-float>? 3.14f0)  ; => false (single)
(<double-float>? 3.14)    ; => true (default is double)
```

---

## <ratio>?

```
(<ratio>? x)
```

Returns true if x is a ratio (exact fraction).

### Examples

```fol
(<ratio>? 1/2)      ; => true
(<ratio>? 2/4)      ; => false (simplifies to 1/2)
(<ratio>? 4/2)      ; => false (simplifies to 2, an integer)
(<ratio>? 0.5)      ; => false (float)
```

---

## <rational>?

```
(<rational>? x)
```

Returns true if x is a rational number (integer or ratio).

### Examples

```fol
(<rational>? 42)    ; => true
(<rational>? 1/2)   ; => true
(<rational>? 3.14)  ; => false
```

---

## <complex>?

```
(<complex>? x)
```

Returns true if x is a complex number.

### Examples

```fol
(<complex>? #C(1 2))   ; => true
(<complex>? 42)        ; => false
(<complex>? 3.14)      ; => false
```

---

## <string>?

```
(<string>? x)
```

Returns true if x is a string.

### Examples

```fol
(<string>? "hello")    ; => true
(<string>? "")         ; => true
(<string>? 'hello)     ; => false
(<string>? 42)         ; => false
```

---

## <symbol>?

```
(<symbol>? x)
```

Returns true if x is a symbol (including keywords).

### Examples

```fol
(<symbol>? 'hello)     ; => true
(<symbol>? :keyword)   ; => true
(<symbol>? "hello")    ; => false
```

---

## <keyword>?

```
(<keyword>? x)
```

Returns true if x is a keyword (symbol starting with colon).

### Examples

```fol
(<keyword>? :foo)      ; => true
(<keyword>? :bar)      ; => true
(<keyword>? 'foo)      ; => false (regular symbol)
(<keyword>? "foo")     ; => false (string)
```
