# Miscellaneous Functions

See also [functional.md](functional.md) for higher-order functions like `identity` and `complement`.

## print                                                                *[function]*

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

## type                                                                 *[function]*

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

## make                                                         *[generic function]*

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

## str                                                                  *[function]*

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

## list                                                                 *[function]*

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

## append                                                               *[function]*

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

## reverse                                                              *[function]*

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

## parse-bool                                                           *[function]*

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

## parse-int                                                            *[function]*

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

## parse-double                                                         *[function]*

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

## parse-uuid                                                           *[function]*

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

## keyword                                                              *[function]*

```
(keyword name)
```

Creates a keyword from NAME.

### Arguments

- `name` - A string or symbol

### Behavior

- **Strings**: Converts to uppercase and interns as a keyword. Leading `:` is stripped if present.
- **Symbols**: Converts the symbol name to a keyword.
- **Keywords**: Returns the keyword unchanged.

### Examples

```fol
;; From strings
(keyword "foo")               ; => :FOO
(keyword "hello-world")       ; => :HELLO-WORLD
(keyword ":bar")              ; => :BAR (leading colon stripped)

;; Case insensitive
(keyword "FOO")               ; => :FOO
(keyword "Foo")               ; => :FOO

;; From symbols
(keyword 'baz)                ; => :BAZ

;; Keywords unchanged
(keyword :qux)                ; => :QUX
```

---

## find-keyword                                                         *[function]*

```
(find-keyword name)
```

Finds a keyword with NAME if it exists in the keyword package.

### Arguments

- `name` - A string or symbol

### Behavior

- **Strings**: Looks up the keyword (case-insensitive). Leading `:` is stripped if present.
- **Symbols**: Looks up a keyword with the same name.
- **Keywords**: Returns the keyword unchanged.

Returns the keyword if found, or `NIL` if no such keyword exists.

### Examples

```fol
;; Finding existing keywords
(find-keyword "foo")          ; => :FOO (if :FOO exists)
(find-keyword "FOO")          ; => :FOO (case-insensitive)
(find-keyword ":bar")         ; => :BAR (if :BAR exists)

;; Non-existent keyword
(find-keyword "nonexistent")  ; => NIL

;; From symbols
(find-keyword 'baz)           ; => :BAZ (if :BAZ exists)

;; Keywords unchanged
(find-keyword :qux)           ; => :QUX
```

---

## symbol                                                               *[function]*

```
(symbol name)
(symbol module-name symbol-name)
```

Creates a symbol and associates it with a module.

### Arguments

- `name` - A string, symbol, or keyword used as the symbol name
- `module-name` - (optional first arg) A string or symbol naming the module
- `symbol-name` - (optional second arg) A string or symbol used as the symbol name

### Behavior

- **One argument**: Creates a symbol from `name` and interns it in the current module (or the default module if no current module is set).
- **Two arguments**: The first argument is the module name, the second is the symbol name. Creates a symbol from the second argument and interns it in the module named by the first argument.

In both cases, the `module-name` slot on the resulting `<symbol>` is set to the module it was interned in.

### Examples

```fol
;; Create symbol in current/default module
(symbol "foo")                ; => user::FOO
(symbol "my-var")             ; => user::MY-VAR

;; Create symbol in a specific module
(symbol "math" "pi")          ; => math::PI
(symbol "utils" "helper")     ; => utils::HELPER

;; From existing symbols
(symbol 'bar)                 ; => user::BAR
(symbol 'math 'sqrt)          ; => math::SQRT
```

---

## gensym                                                               *[function]*

```
(gensym)
(gensym prefix)
(gensym prefix module)
```

Creates a unique symbol with an auto-generated name containing a monotonically increasing counter.

### Arguments

- `prefix` - (optional) A string or symbol used as the name prefix, or `nil`
- `module` - (optional) A string or symbol used as the name component and controlling interning behavior

### Behavior

- **No arguments**: Creates a symbol named `G__N` (where N is a unique number) and interns it in the current module.
- **Prefix only**: Creates a symbol named `PREFIX__N` and interns it in the current module.
- **Prefix and module**: Creates a symbol named `MODULE__N` and interns it in the module named by `prefix`.
- **Nil prefix with module**: Creates a symbol named `MODULE__N` that is not interned in any module (`module-name` is `nil`).

### Examples

```fol
;; No arguments - G__N in current module
(gensym)                      ; => user::G__1
(gensym)                      ; => user::G__2

;; With prefix - PREFIX__N in current module
(gensym "temp")               ; => user::TEMP__3

;; With prefix and module - MODULE__N in prefix's module
(gensym "math" "x")           ; => math::X__4

;; Nil prefix with module - MODULE__N, uninterned
(gensym nil "scratch")        ; => SCRATCH__5 (no module)
```

---

## int                                                                  *[function]*

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

## <double-float>                                                       *[function]*

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
