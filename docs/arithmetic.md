# Arithmetic Functions

## +

```
(+ x)
(+ x y)
(+ x y & more)
```

Returns the sum of nums. (+) returns 0.

### Examples

```fol
(+ 1 2)        ; => 3
(+ 1 2 3 4)    ; => 10
(+ 10)         ; => 10
(+)            ; => 0
(+ 1.5 2.5)    ; => 4.0
```

---

## -

```
(- x)
(- x y)
(- x y & more)
```

If only one argument is supplied, returns the negation of x.
Otherwise, subtracts y and all subsequent values from x and returns the result.

### Examples

```fol
(- 10 3)       ; => 7
(- 10 3 2)     ; => 5
(- 5)          ; => -5
(- 10.5 0.5)   ; => 10.0
```

---

## *

```
(* x)
(* x y)
(* x y & more)
```

Returns the product of nums. (*) returns 1.

### Examples

```fol
(* 2 3)        ; => 6
(* 2 3 4)      ; => 24
(* 5)          ; => 5
(*)            ; => 1
(* 1.5 2)      ; => 3.0
```

---

## /

```
(/ x)
(/ x y)
(/ x y & more)
```

If only one argument is supplied, returns 1/x.
Otherwise, divides x by y and all subsequent values and returns the result.
Division of integers yields a ratio (exact fraction).

### Examples

```fol
(/ 10 2)       ; => 5
(/ 20 4 2)     ; => 5/2
(/ 4)          ; => 1/4
(/ 10.0 4)     ; => 2.5
(/ 1 3)        ; => 1/3
```

---

## abs

```
(abs x)
```

Returns the absolute value of x.

### Examples

```fol
(abs -5)       ; => 5
(abs 5)        ; => 5
(abs -3.14)    ; => 3.14
```

---

## sin

```
(sin x)
```

Returns the sine of x (x is in radians).

### Examples

```fol
(sin 0)        ; => 0.0
(sin 1.5708)   ; => ~1.0 (approximately pi/2)
```

---

## cos

```
(cos x)
```

Returns the cosine of x (x is in radians).

### Examples

```fol
(cos 0)        ; => 1.0
(cos 3.14159)  ; => ~-1.0 (approximately pi)
```

---

## tan

```
(tan x)
```

Returns the tangent of x (x is in radians).

### Examples

```fol
(tan 0)        ; => 0.0
(tan 0.7854)   ; => ~1.0 (approximately pi/4)
```

---

## sqrt

```
(sqrt x)
```

Returns the square root of x.

### Examples

```fol
(sqrt 4)       ; => 2.0
(sqrt 2)       ; => 1.4142135...
(sqrt 9)       ; => 3.0
```

---

## expt

```
(expt base power)
```

Returns base raised to the power.

### Examples

```fol
(expt 2 3)     ; => 8
(expt 2 10)    ; => 1024
(expt 10 -1)   ; => 1/10
(expt 2.0 0.5) ; => 1.4142135...
```

---

## exp

```
(exp x)
```

Returns e (Euler's number) raised to the power x.

### Examples

```fol
(exp 0)        ; => 1.0
(exp 1)        ; => 2.7182818... (e)
(exp 2)        ; => 7.389056...
```

---

## ln

```
(ln x)
```

Returns the natural logarithm of x.

### Examples

```fol
(ln 1)         ; => 0.0
(ln 2.71828)   ; => ~1.0
(ln 10)        ; => 2.302585...
(ln (exp 3))   ; => 3.0
```

---

## mod

```
(mod num div)
```

Returns the modulus of num and div. The result has the same sign as the divisor.

### Examples

```fol
(mod 10 3)     ; => 1
(mod -10 3)    ; => 2
(mod 10 -3)    ; => -2
```

---

## rem

```
(rem num div)
```

Returns the remainder of dividing num by div. The result has the same sign as the dividend.

### Examples

```fol
(rem 10 3)     ; => 1
(rem -10 3)    ; => -1
(rem 10 -3)    ; => 1
```

---

## floor

```
(floor x)
(floor x divisor)
```

Returns two values: the largest integer less than or equal to x, and the remainder.
With two arguments, returns the floor of x/divisor.

### Examples

```fol
(floor 3.7)    ; => 3, 0.7 (two values)
(floor -3.7)   ; => -4, 0.3 (two values)
(floor 10 3)   ; => 3, 1 (quotient and remainder)

;; Capturing multiple values with destructuring:
(bind [[q r] (floor 10 3)]
  (+ q r))     ; => 4
```

---

## ceiling

```
(ceiling x)
(ceiling x divisor)
```

Returns two values: the smallest integer greater than or equal to x, and the remainder.
With two arguments, returns the ceiling of x/divisor.

### Examples

```fol
(ceiling 3.2)  ; => 4, -0.8 (two values)
(ceiling -3.2) ; => -3, -0.2 (two values)
(ceiling 10 3) ; => 4, -2 (quotient and remainder)

;; Capturing multiple values with destructuring:
(bind [[q r] (ceiling 10 3)]
  q)           ; => 4
```

---

## truncate

```
(truncate x)
(truncate x divisor)
```

Returns two values: the integer part of x truncated toward zero, and the remainder.
With two arguments, returns the truncated quotient.

### Examples

```fol
(truncate 3.7)   ; => 3, 0.7 (two values)
(truncate -3.7)  ; => -3, -0.7 (two values)
(truncate 10 3)  ; => 3, 1 (quotient and remainder)

;; Capturing multiple values with destructuring:
(bind [[q r] (truncate -10 3)]
  [q r])         ; => [-3 -1]
```

---

## round

```
(round x)
(round x divisor)
```

Returns two values: the integer nearest to x, and the remainder.
Rounds to even when exactly halfway between two integers (banker's rounding).

### Examples

```fol
(round 3.4)    ; => 3, 0.4 (two values)
(round 3.5)    ; => 4, -0.5 (two values)
(round 2.5)    ; => 2, 0.5 (rounds to even)
(round -3.5)   ; => -4, 0.5 (two values)

;; Capturing multiple values with destructuring:
(bind [[n remainder] (round 7.3)]
  n)           ; => 7
```
