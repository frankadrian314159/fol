# Arithmetic Functions

## +                                                                  *[function]*

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

## -                                                                  *[function]*

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

## *                                                                  *[function]*

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

## /                                                                  *[function]*

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

## abs                                                                *[function]*

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

## sin                                                                *[function]*

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

## cos                                                                *[function]*

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

## tan                                                                *[function]*

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

## sqrt                                                               *[function]*

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

## expt                                                               *[function]*

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

## exp                                                                *[function]*

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

## ln                                                                 *[function]*

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

## mod                                                                *[function]*

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

## rem                                                                *[function]*

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

## floor                                                              *[function]*

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

## ceiling                                                            *[function]*

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

## truncate                                                           *[function]*

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

## round                                                              *[function]*

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

---

## inc                                                                *[function]*

```
(inc x)
```

Returns x + 1. Equivalent to `(+ x 1)`.

### Examples

```fol
(inc 0)        ; => 1
(inc 5)        ; => 6
(inc -1)       ; => 0
(inc 2.5)      ; => 3.5
```

---

## dec                                                                *[function]*

```
(dec x)
```

Returns x - 1. Equivalent to `(- x 1)`.

### Examples

```fol
(dec 5)        ; => 4
(dec 0)        ; => -1
(dec 1)        ; => 0
(dec 3.5)      ; => 2.5
```

---

# Type Conversion Functions

## \<complex\>                                                        *[function]*

```
(<complex> x)
```

Converts a real number to a complex number with imaginary part 0. If the number is already complex, returns it unchanged.

### Examples

```fol
(<complex> 42)       ; => #C(42.0 0.0)
(<complex> 3.14)     ; => #C(3.14 0.0)
(<complex> 1/2)      ; => #C(0.5 0.0)
(<complex> -5)       ; => #C(-5.0 0.0)
(<complex> #C(3 4))  ; => #C(3 4) (unchanged)
```

---

## \<single-float\>                                                   *[function]*

```
(<single-float> x)
```

Converts a real number to a single-precision floating point number. If the number is already a single-float, returns it unchanged.

### Examples

```fol
(<single-float> 42)      ; => 42.0
(<single-float> 1/2)     ; => 0.5
(<single-float> 3.14d0)  ; => 3.14 (converted from double)
(<single-float> -5)      ; => -5.0
```

---

## \<double-float\>                                                   *[function]*

```
(<double-float> x)
```

Converts a real number to a double-precision floating point number. If the number is already a double-float, returns it unchanged.

### Examples

```fol
(<double-float> 42)      ; => 42.0d0
(<double-float> 1/2)     ; => 0.5d0
(<double-float> 3.14)    ; => 3.14d0 (converted from single)
(<double-float> -5)      ; => -5.0d0
```

---

## rationalize                                                        *[function]*

```
(rationalize x)
(rationalize x tolerance)
```

Converts a real number to a rational approximation.

With one argument, returns a rational number that is mathematically equal to (or a close approximation of) the number. Integers and ratios are returned unchanged. Floats are converted to their closest rational representation.

With two arguments, returns the simplest rational number within `tolerance` of `x`. The "simplest" rational is defined as the one with the smallest denominator that falls within the interval [x - tolerance, x + tolerance]. This implements Scheme's rationalize semantics.

### Examples

```fol
;; One-argument form
(rationalize 1/2)        ; => 1/2 (unchanged)
(rationalize 5)          ; => 5 (unchanged)
(rationalize 0.5)        ; => 1/2

;; Two-argument form (Scheme-style)
(rationalize 0.3333333 0.0001)  ; => 1/3
(rationalize 0.3 0.1)           ; => 1/3
(rationalize 2.1 0.2)           ; => 2
(rationalize 3.14159 0.01)      ; => 22/7 (classic pi approximation)
```

---

# Integer Predicates

## nat-int?                                                           *[function]*

```
(nat-int? x)
```

Returns `t` if `x` is a non-negative integer (natural number, >= 0), `nil` otherwise.

This predicate returns `nil` for all non-integer types including floats, ratios, complex numbers, strings, and symbols.

### Examples

```fol
(nat-int? 0)         ; => t
(nat-int? 1)         ; => t
(nat-int? 42)        ; => t
(nat-int? -1)        ; => nil (negative)
(nat-int? 3.14)      ; => nil (not an integer)
(nat-int? 0.0)       ; => nil (float, not integer)
(nat-int? 1/2)       ; => nil (ratio)
```

---

## pos-int?                                                           *[function]*

```
(pos-int? x)
```

Returns `t` if `x` is a positive integer (> 0), `nil` otherwise.

This predicate returns `nil` for all non-integer types including floats, ratios, complex numbers, strings, and symbols. Note that `0` returns `nil` since it is not positive.

### Examples

```fol
(pos-int? 1)         ; => t
(pos-int? 42)        ; => t
(pos-int? 0)         ; => nil (not positive)
(pos-int? -1)        ; => nil (negative)
(pos-int? 3.14)      ; => nil (not an integer)
(pos-int? 1/2)       ; => nil (ratio)
```

---

# Float Special Value Predicates

## NaN?                                                               *[function]*

```
(NaN? x)
```

Returns `t` if `x` is a floating-point NaN (Not a Number), `nil` otherwise.

NaN values are produced by undefined operations such as dividing zero by zero, or taking the square root of a negative number (when not in complex mode). NaN is the only value that is not equal to itself, which is how this function detects it.

Non-float numbers (integers, ratios, complex) always return `nil`.

### Examples

```fol
(NaN? (/ 0.0 0.0))     ; => t
(NaN? 3.14)            ; => nil
(NaN? 0.0)             ; => nil
(NaN? 42)              ; => nil (integers are never NaN)
(NaN? 1/2)             ; => nil (ratios are never NaN)
```

---

## infinite?                                                          *[function]*

```
(infinite? x)
```

Returns `t` if `x` is a floating-point infinity (positive or negative), `nil` otherwise.

Infinity values are produced by operations that overflow, such as dividing a non-zero number by zero. Both positive and negative infinity return `t`.

Non-float numbers (integers, ratios, complex) always return `nil`.

### Examples

```fol
(infinite? (/ 1.0 0.0))   ; => t (positive infinity)
(infinite? (/ -1.0 0.0))  ; => t (negative infinity)
(infinite? 3.14)          ; => nil
(infinite? 0.0)           ; => nil
(infinite? 42)            ; => nil (integers are never infinite)
(infinite? (/ 0.0 0.0))   ; => nil (NaN is not infinite)
```

---

# Random Number Generation

## rand                                                                *[function]*

```
(rand)
(rand n)
```

Returns a random number.

With no argument, returns a random double-float in the half-open interval [0.0, 1.0).

With a positive integer argument `n`, returns a random integer in the half-open interval [0, n).

### Examples

```fol
(rand)              ; => 0.7234... (some double-float in [0.0, 1.0))
(rand 6)            ; => 3 (some integer from 0 to 5)
(rand 100)          ; => 42 (some integer from 0 to 99)
(rand 2)            ; => 0 or 1 (coin flip)
```

---

## with-seed                                                              *[macro]*

```
(with-seed seed form*)
```

Evaluates the forms with the random number generator seeded to `seed`, returning the value of the last form.

The seed must be a non-negative integer. Using the same seed will produce the same sequence of random numbers, making it useful for reproducible testing or simulations.

The seeded state is local to the body forms and does not affect the global random state.

### Examples

```fol
;; Reproducible random sequence
(with-seed 42
  (list (rand 100) (rand 100) (rand 100)))
; => (17 33 61) (same every time with seed 42)

;; Different seeds give different sequences
(with-seed 123
  (list (rand 100) (rand 100) (rand 100)))
; => (8 71 29) (different sequence)

;; Returns the last form's value
(with-seed 0
  (rand)
  (rand)
  (* 6 7))
; => 42
```
