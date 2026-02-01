# Primitive Types

FOL provides persistent wrapper classes for primitive values. All primitives inherit from `<persistent-object>` and can participate in FOL's persistent storage system.

## Boolean - `<bool>`                                                    *[class]*

The boolean class wraps native Lisp booleans.

### Literals

```fol
t       ; => true
nil     ; => false/nil
```

### Predicate

```fol
(<bool>? t)        ; => true
(<bool>? nil)      ; => true
(<bool>? 0)        ; => false
```

---

## Character - `<char>`                                                  *[class]*

The character class wraps native Lisp characters.

### Literals

```fol
\a            ; lowercase a
\A            ; uppercase A
\newline      ; newline character
\space        ; space character
\tab          ; tab character
\return       ; carriage return
\backspace    ; backspace
\formfeed     ; form feed
\u0041        ; Unicode character (A)
```

### Predicate

```fol
(<char>? \a)        ; => true
(<char>? \newline)  ; => true
(<char>? "a")       ; => false (string, not char)
```

### Functions

| Function | Description |
|----------|-------------|
| `char-name-string` | Returns the name of a character as a string |
| `int` | Converts a character to its character code |

### Examples

```fol
(char-name-string \newline)  ; => "NEWLINE"
(int \A)                     ; => 65
```

---

## String - `<string>`                                                   *[class]*

The string class wraps native Lisp strings. Strings are immutable sequences of characters.

### Literals

```fol
"hello"           ; simple string
"line1\nline2"    ; string with escape sequences
""                ; empty string
```

### Predicate

```fol
(<string>? "hello")  ; => true
(<string>? "")       ; => true
(<string>? 'hello)   ; => false
```

### String Functions

See [string.md](string.md) for comprehensive string operations.

| Function | Description |
|----------|-------------|
| `str` | Concatenate values into a string |
| `blank?` | Returns true if string is nil, empty, or only whitespace |
| `trim` | Remove leading and trailing whitespace |
| `triml` | Remove leading whitespace |
| `trimr` | Remove trailing whitespace |
| `trim-newline` | Remove trailing newlines |
| `capitalize` | Capitalize the first character |
| `starts-with?` | Check if string starts with prefix |
| `ends-with?` | Check if string ends with suffix |
| `includes?` | Check if string contains substring |
| `replace` | Replace all occurrences of a pattern |
| `replace-first` | Replace first occurrence of a pattern |
| `join` | Join collection elements with separator |
| `escape` | Escape special characters |
| `split` | Split string by pattern |
| `split-lines` | Split string into lines |

### Examples

```fol
(str "Hello, " "world!")        ; => "Hello, world!"
(blank? "  ")                   ; => true
(trim "  hello  ")              ; => "hello"
(starts-with? "hello" "he")     ; => true
(split "a,b,c" ",")             ; => ["a" "b" "c"]
```

---

## Regular Expression Pattern - `<re-pattern>`                           *[class]*

A regular expression pattern that inherits from `<string>`.

### Literal Syntax

```fol
#"pattern"        ; regex pattern literal
#"[a-z]+"         ; matches one or more lowercase letters
#"(?i)hello"      ; case-insensitive match
```

### Predicate

There is no specific `<re-pattern>?` predicate; use `<string>?` since patterns are strings.

### Functions

| Function | Description |
|----------|-------------|
| `re-pattern` | Create a regex pattern from a string |
| `re-find` | Find first match of pattern in string |
| `re-seq` | Return lazy sequence of all matches |
| `re-scanner` | Create a compiled scanner for repeated use |

### Examples

```fol
(re-find #"\d+" "abc123def")     ; => "123"
(re-seq #"\d+" "a1b2c3")         ; => ("1" "2" "3")
```

See [regex.md](regex.md) for comprehensive regex operations.

---

## Regular Expression Scanner - `<re-scanner>`                           *[class]*

A compiled regular expression scanner for efficient repeated matching. Unlike other primitives, scanners are **not** persistent objects because they hold stateful compiled scanner functions.

### Functions

| Function | Description |
|----------|-------------|
| `re-scanner` | Create a scanner from a pattern |

---

## Symbol - `<symbol>`                                                   *[class]*

The symbol class wraps Lisp symbols. Symbols have a name, an optional module name, and an optional associated value.

### Literals

```fol
foo           ; unquoted symbol (evaluated)
'foo          ; quoted symbol (literal)
my-var        ; hyphenated symbol name
+special+     ; symbols can include special characters
```

### Predicate

```fol
(<symbol>? 'hello)    ; => true
(<symbol>? :keyword)  ; => true (keywords are symbols)
(<symbol>? "hello")   ; => false
```

### Functions

| Function | Description |
|----------|-------------|
| `symbol` | Create a symbol from a string |
| `gensym` | Generate a unique symbol |

### Examples

```fol
(symbol "my-name")    ; => my-name
(gensym)              ; => G__1234 (unique each time)
(gensym "prefix")     ; => prefix1234
```

---

## Keyword - `<keyword>`                                                 *[class]*

Keywords are self-evaluating symbols that start with a colon. They inherit from `<symbol>`. Keywords are interned in the `keyword` module.

### Literals

```fol
:foo          ; simple keyword
:my-key       ; hyphenated keyword
```

### Predicate

```fol
(<keyword>? :foo)     ; => true
(<keyword>? 'foo)     ; => false (regular symbol)
(<keyword>? "foo")    ; => false
```

### Functions

| Function | Description |
|----------|-------------|
| `keyword` | Create a keyword from a string or symbol |
| `find-keyword` | Find an existing keyword (returns nil if not found) |

### Examples

```fol
(keyword "name")      ; => :name
(keyword 'name)       ; => :name
(find-keyword "name") ; => :name or nil
```

---

## Numbers                                                              *[classes]*

FOL provides a complete numeric tower with the following hierarchy:

```
<number>
├── <complex>
└── <real>
    ├── <float>
    │   ├── <single-float>
    │   └── <double-float>
    └── <rational>
        ├── <ratio>
        └── <integer>
            ├── <fixnum>
            └── <bignum>
```

### Number Literals

```fol
42              ; integer (fixnum)
-17             ; negative integer
3.14            ; double-float (default)
3.14f0          ; single-float
3.14d0          ; double-float (explicit)
1/2             ; ratio
#C(1 2)         ; complex number (1 + 2i)
##Inf           ; positive infinity
##-Inf          ; negative infinity
##NaN           ; not a number
```

### Type Predicates

| Predicate | Description |
|-----------|-------------|
| `<number>?` | Any number type |
| `<complex>?` | Complex number |
| `<real>?` | Real number (not complex) |
| `<float>?` | Floating-point number |
| `<single-float>?` | Single-precision float |
| `<double-float>?` | Double-precision float |
| `<rational>?` | Rational number (integer or ratio) |
| `<ratio>?` | Exact fraction |
| `<integer>?` | Integer (fixnum or bignum) |
| `<fixnum>?` | Small integer (machine word) |
| `<bignum>?` | Arbitrary precision integer |

### Numeric Predicates

| Predicate | Description |
|-----------|-------------|
| `zero?` | True if number equals zero |
| `positive?` | True if number > 0 |
| `negative?` | True if number < 0 |
| `even?` | True if integer is even |
| `odd?` | True if integer is odd |
| `nat-int?` | True if non-negative integer (>= 0) |
| `pos-int?` | True if positive integer (> 0) |
| `NaN?` | True if floating-point NaN |
| `infinite?` | True if floating-point infinity |

### Type Conversion Functions

| Function | Description |
|----------|-------------|
| `<complex>` | Convert to complex number |
| `<single-float>` | Convert to single-precision float |
| `<double-float>` | Convert to double-precision float |
| `int` | Convert to integer (chars, bools, integers) |
| `rationalize` | Convert to rational approximation |

### Parsing Functions

| Function | Description |
|----------|-------------|
| `parse-int` | Parse string to integer |
| `parse-double` | Parse string to double-float |

### Random Number Generation

| Function | Description |
|----------|-------------|
| `rand` | Random number: `(rand)` for [0,1), `(rand n)` for [0,n) |
| `call-with-seed` | Call function with seeded random state |

### Examples

```fol
(zero? 0)                ; => t
(positive? 5)            ; => t
(even? 4)                ; => t
(odd? 3)                 ; => t
(<double-float> 42)      ; => 42.0d0
(parse-int "123")        ; => 123
(parse-double "3.14")    ; => 3.14d0
(rand)                   ; => 0.7234... (random)
(rand 10)                ; => 7 (random integer 0-9)
```

See [arithmetic.md](arithmetic.md) for arithmetic operations.

---

## UUID - `<uuid>`                                                       *[class]*

A UUID (Universally Unique Identifier) wrapping the uuid library's UUID object.

### Functions

| Function | Description |
|----------|-------------|
| `parse-uuid` | Parse a UUID string |

### Examples

```fol
(parse-uuid "550e8400-e29b-41d4-a716-446655440000")
```

---

## Streams                                                              *[classes]*

Stream classes wrap native Lisp streams for I/O operations. Unlike other primitives, streams are **not** persistent objects because they are inherently stateful.

### Stream Classes

| Class | Description |
|-------|-------------|
| `<stream>` | Base stream class |
| `<input-stream>` | Base class for input streams |
| `<output-stream>` | Base class for output streams |
| `<string-input-stream>` | Read from a string |
| `<file-input-stream>` | Read from a file |
| `<string-output-stream>` | Write to a string |
| `<file-output-stream>` | Write to a file |

See the stream operations documentation for usage details.
