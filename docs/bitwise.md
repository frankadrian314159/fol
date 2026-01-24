# Bitwise Functions

All bitwise functions operate on integers only.

## bitnot

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

## bitand

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

## bitor

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

## bitxor

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

## bit-nand

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

## bit-nor

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

## bit-andc1

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

## bit-andc2

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

## bit-orc1

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

## bit-orc2

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

## bit-test

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

## bit-set

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

## bit-clear

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

## bit-count

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
