# Bitwise Functions

All bitwise functions operate on integers only.

## bitnot                                                               *[function]*

```
(bitnot x)
```

Returns the bitwise NOT (one's complement) of integer x.

### Examples

```fol
(bitnot 0)         ; => -1
(bitnot 1)         ; => -2
(bitnot -1)        ; => 0
(bitnot #b1010)    ; => -11
(bitnot #xFF)      ; => -256
```

---

## bitand                                                               *[function]*

```
(bitand & args)
```

Returns the bitwise AND of all arguments. With no arguments, returns -1 (all bits set).

### Examples

```fol
(bitand #b1100 #b1010)    ; => 8 (#b1000)
(bitand 15 7)              ; => 7
(bitand #xFF #x0F)         ; => 15
(bitand 255 128 64)        ; => 0
(bitand)                   ; => -1
```

---

## bitor                                                                *[function]*

```
(bitor & args)
```

Returns the bitwise OR of all arguments. With no arguments, returns 0.

### Examples

```fol
(bitor #b1100 #b1010)     ; => 14 (#b1110)
(bitor 8 4)                ; => 12
(bitor #xF0 #x0F)          ; => 255
(bitor 1 2 4 8)            ; => 15
(bitor)                    ; => 0
```

---

## bitxor                                                               *[function]*

```
(bitxor & args)
```

Returns the bitwise XOR of all arguments. With no arguments, returns 0.

### Examples

```fol
(bitxor #b1100 #b1010)    ; => 6 (#b0110)
(bitxor 15 5)              ; => 10
(bitxor #xFF #x0F)         ; => 240 (#xF0)
(bitxor 1 3 7)             ; => 5
(bitxor)                   ; => 0
```

---

## bit-nand                                                             *[function]*

```
(bit-nand & args)
```

Returns the bitwise NAND (NOT AND) of all arguments.

### Examples

```fol
(bit-nand #b1100 #b1010)  ; => -9 (complement of #b1000)
(bit-nand 15 7)            ; => -8
```

---

## bit-nor                                                              *[function]*

```
(bit-nor & args)
```

Returns the bitwise NOR (NOT OR) of all arguments.

### Examples

```fol
(bit-nor #b1100 #b1010)   ; => -15 (complement of #b1110)
(bit-nor 8 4)              ; => -13
```

---

## bit-andc1                                                            *[function]*

```
(bit-andc1 x y)
```

Returns bitwise AND of (NOT x) with y. Useful for clearing bits.

### Examples

```fol
(bit-andc1 #b0011 #b1111) ; => 12 (#b1100)
(bit-andc1 1 7)            ; => 6
```

---

## bit-andc2                                                            *[function]*

```
(bit-andc2 x y)
```

Returns bitwise AND of x with (NOT y). Useful for clearing bits.

### Examples

```fol
(bit-andc2 #b1111 #b0011) ; => 12 (#b1100)
(bit-andc2 7 1)            ; => 6
```

---

## bit-orc1                                                             *[function]*

```
(bit-orc1 x y)
```

Returns bitwise OR of (NOT x) with y.

### Examples

```fol
(bit-orc1 #b1100 #b0011)  ; => -13
(bit-orc1 0 0)             ; => -1
```

---

## bit-orc2                                                             *[function]*

```
(bit-orc2 x y)
```

Returns bitwise OR of x with (NOT y).

### Examples

```fol
(bit-orc2 #b0011 #b1100)  ; => -13
(bit-orc2 0 0)             ; => -1
```

---

## bit-test                                                             *[function]*

```
(bit-test integer position)
```

Returns true if the bit at position in integer is set (1). Position 0 is the least significant bit.

### Examples

```fol
(bit-test #b1010 1)       ; => true  (bit 1 is set)
(bit-test #b1010 0)       ; => false (bit 0 is not set)
(bit-test #b1010 3)       ; => true  (bit 3 is set)
(bit-test 8 3)            ; => true  (8 = #b1000)
```

---

## bit-set                                                              *[function]*

```
(bit-set integer position)
```

Returns integer with the bit at position set to 1.

### Examples

```fol
(bit-set 0 0)             ; => 1
(bit-set 0 3)             ; => 8
(bit-set #b1010 0)        ; => 11 (#b1011)
(bit-set #b1010 2)        ; => 14 (#b1110)
```

---

## bit-clear                                                            *[function]*

```
(bit-clear integer position)
```

Returns integer with the bit at position set to 0.

### Examples

```fol
(bit-clear #b1111 0)      ; => 14 (#b1110)
(bit-clear #b1111 3)      ; => 7  (#b0111)
(bit-clear 8 3)           ; => 0
(bit-clear 15 1)          ; => 13 (#b1101)
```

---

## bit-count                                                            *[function]*

```
(bit-count integer)
```

Returns the number of 1 bits in the two's complement representation of integer.
For non-negative integers, this is the population count (number of set bits).
For negative integers, this is the number of zero bits.

### Examples

```fol
(bit-count 0)             ; => 0
(bit-count 1)             ; => 1
(bit-count #b1010)        ; => 2
(bit-count 255)           ; => 8
(bit-count -1)            ; => 0 (all bits are 1, so 0 zeros)
(bit-count -2)            ; => 1 (one zero bit in ...11110)
```

---

## bit-shift                                                            *[function]*

```
(bit-shift integer count)
```

Shifts integer by count bit positions. Positive count shifts left, negative count shifts right. Right shift is arithmetic (sign-extending for negative numbers).

This is equivalent to multiplying or dividing by powers of 2:
- `(bit-shift x n)` where n > 0 is equivalent to `(* x (expt 2 n))`
- `(bit-shift x n)` where n < 0 is equivalent to `(floor x (expt 2 (- n)))`

### Examples

```fol
;; Shift left (positive count)
(bit-shift 1 2)           ; => 4    (1 << 2)
(bit-shift 1 8)           ; => 256  (1 << 8)
(bit-shift 5 3)           ; => 40   (5 * 8)

;; Shift right (negative count)
(bit-shift 16 -2)         ; => 4    (16 >> 2)
(bit-shift 255 -4)        ; => 15   (255 >> 4)
(bit-shift 1 -1)          ; => 0    (1 >> 1)

;; Arithmetic shift preserves sign for negative numbers
(bit-shift -1 2)          ; => -4   (-1 << 2)
(bit-shift -8 -2)         ; => -2   (-8 >> 2, sign-extended)

;; Zero count returns the value unchanged
(bit-shift 42 0)          ; => 42
```

---

## bit-rotate                                                           *[function]*

```
(bit-rotate integer count width)
```

Rotates integer by count bit positions within a width-bit field. Positive count rotates left, negative count rotates right. Bits that shift out one end wrap around to the other end.

The width parameter is required because rotation only makes sense for a fixed-size bit field. The result is always a non-negative integer with at most width bits.

### Examples

```fol
;; 8-bit rotate left
(bit-rotate #b00000001 1 8)   ; => 2   (#b00000010)
(bit-rotate #b00000001 4 8)   ; => 16  (#b00010000)
(bit-rotate #b10000000 1 8)   ; => 1   (#b00000001, wraps around)
(bit-rotate #b11000001 2 8)   ; => 7   (#b00000111)

;; 8-bit rotate right (negative count)
(bit-rotate #b00000001 -1 8)  ; => 128 (#b10000000)
(bit-rotate #b00010000 -4 8)  ; => 1   (#b00000001)

;; Full rotation returns same value
(bit-rotate #b10101010 8 8)   ; => 170 (#b10101010)
(bit-rotate #b10101010 -8 8)  ; => 170 (#b10101010)

;; Different bit widths
(bit-rotate #b0001 3 4)       ; => 8   (#b1000, 4-bit rotate)
(bit-rotate #xC000 1 16)      ; => #x8001 (16-bit rotate)
```
