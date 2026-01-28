# Miscellaneous Functions

See also [functional.md](functional.md) for higher-order functions like `identity` and `complement`.

## print

```
(print x)
```

Prints x to standard output with a newline, then returns x.

### Examples

```fol
(print "hello")       ; prints: "hello" and returns "hello"
(print 42)            ; prints: 42 and returns 42
```

---

## type

```
(type x)
```

Returns the FOL type of x as a symbol.

### Examples

```fol
(type 42)             ; => <integer>
(type 3.14)           ; => <double-float>
(type "hello")        ; => <string>
(type [1 2 3])        ; => <vector>
(type {:a 1})         ; => <dict>
(type 'foo)           ; => <symbol>
(type :bar)           ; => <keyword>
(type true)           ; => <bool>
(type \a)             ; => <char>
```

---

## make

```
(make class & args)
```

Generic constructor for FOL types. Creates an instance of the specified class
with the given arguments.

### Examples

```fol
;; Create collections
(make '<vector> 1 2 3)        ; => [1 2 3]
(make '<list> 1 2 3)          ; => (1 2 3)
(make '<dict> :a 1 :b 2)      ; => {:a 1 :b 2}
(make '<set> 1 2 3)           ; => #{1 2 3}

;; Create wrapped values
(make '<string> "hello")      ; => "hello"
(make '<integer> 42)          ; => 42
```

---

## str

```
(str & args)
```

Concatenates the string representations of all arguments into a single string.

### Examples

```fol
(str "hello" " " "world")     ; => "hello world"
(str "count: " 42)            ; => "count: 42"
(str)                         ; => ""
(str "a" "b" "c")             ; => "abc"
```

---

## list

```
(list & args)
```

Creates a CL-style list containing the given arguments.

### Examples

```fol
(list 1 2 3)                  ; => (1 2 3)
(list)                        ; => nil
(list 'a 'b 'c)               ; => (a b c)
```

---

## append

```
(append & lists)
```

Concatenates CL-style lists together. Returns a new list containing all elements.

### Examples

```fol
(append '(1 2) '(3 4))        ; => (1 2 3 4)
(append '(a) '(b) '(c d))     ; => (a b c d)
(append '() '(1 2))           ; => (1 2)
```

---

## reverse

```
(reverse sequence)
```

Returns a new sequence with elements in reverse order.

### Examples

```fol
(reverse '(1 2 3))            ; => (3 2 1)
(reverse "hello")             ; => "olleh"
(reverse '())                 ; => nil
```

---

## parse-bool

```
(parse-bool s)
```

Parses a boolean string and returns a `<bool>` instance. The input is case-insensitive.

### Arguments

- `s` - A string containing `t`, `nil`, or `()` (case-insensitive)

### Examples

```fol
(parse-bool "t")              ; => t
(parse-bool "T")              ; => t
(parse-bool "nil")            ; => nil
(parse-bool "NIL")            ; => nil
(parse-bool "()")             ; => nil
(parse-bool "true")           ; => ERROR: Expected t, nil, or () for boolean
```

---

## parse-int

```
(parse-int s)
```

Parses an integer string and returns an `<integer>` instance.

### Arguments

- `s` - A string containing a valid integer representation

### Examples

```fol
(parse-int "42")              ; => 42
(parse-int "-17")             ; => -17
(parse-int "999999999999")    ; => 999999999999 (bignum)
(parse-int "3.14")            ; => ERROR: Expected an integer
```

---

## parse-double

```
(parse-double s)
```

Parses a floating-point string and returns a `<double-float>` instance. Integers are automatically converted to double-float.

### Arguments

- `s` - A string containing a valid real number representation

### Examples

```fol
(parse-double "3.14")         ; => 3.14d0
(parse-double "42")           ; => 42.0d0
(parse-double "-1.5e10")      ; => -1.5d10
(parse-double "hello")        ; => ERROR: Expected a real number
```

---

## parse-uuid

```
(parse-uuid s)
```

Parses a UUID string and returns a `<uuid>` instance.

### Arguments

- `s` - A string in standard UUID format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

### Examples

```fol
(parse-uuid "6ba7b810-9dad-11d1-80b4-00c04fd430c8")
; => #uuid "6BA7B810-9DAD-11D1-80B4-00C04FD430C8"

(parse-uuid "invalid")        ; => ERROR
```

---

## int

```
(int x)
```

Converts a value to an integer.

### Arguments

- `x` - A character, boolean, or integer

### Behavior

- **Characters**: Returns the character code (Unicode code point)
- **Booleans**: Returns 1 for `t`, 0 for `nil`
- **Integers**: Returns the integer unchanged

### Examples

```fol
;; Characters to integer (character code)
(int #\A)                     ; => 65
(int #\a)                     ; => 97
(int #\Space)                 ; => 32
(int #\Newline)               ; => 10

;; Booleans to integer
(int t)                       ; => 1
(int nil)                     ; => 0

;; Integers unchanged
(int 42)                      ; => 42
(int -17)                     ; => -17

;; Invalid input
(int "hello")                 ; => ERROR
```

---

## <double-float>

```
(<double-float> x)
```

Converts a real number to a double-precision floating-point number.

### Arguments

- `x` - An integer, ratio, single-float, or double-float

### Behavior

- **Double-floats**: Returned unchanged
- **Single-floats**: Converted to double-float
- **Integers**: Converted to double-float with range checking
- **Ratios**: Converted to double-float with range checking

Signals an error if the number is out of range for double-float representation.

### Examples

```fol
;; Basic conversions
(<double-float> 42)           ; => 42.0d0
(<double-float> 1/2)          ; => 0.5d0
(<double-float> 3.14f0)       ; => 3.14d0

;; Already double-float
(<double-float> 3.14d0)       ; => 3.14d0

;; Out of range error (implementation dependent)
(<double-float> (expt 10 400)) ; => ERROR: out of range
```
