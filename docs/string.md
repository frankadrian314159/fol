# String Operations

Functions for manipulating strings in FOL.

## substr

```
(substr s start)
(substr s start end)
```

Returns the substring of `s` beginning at `start` (inclusive) to `end` (exclusive). If `end` is not provided, returns from `start` to the end of the string.

This is equivalent to Clojure's `subs` function.

### Arguments

- `s` - The source string (can be raw or wrapped `<string>`)
- `start` - The starting index (0-based, inclusive)
- `end` - The ending index (0-based, exclusive). Defaults to the length of the string.

### Examples

```fol
(substr "hello world" 6)          ; => "world"
(substr "hello" 1 4)              ; => "ell"
(substr "hello world" 0 5)        ; => "hello"
(substr "hello" 5)                ; => "" (start at end)
```

---

## blank?

```
(blank? s)
```

Returns true if `s` is nil, empty, or contains only whitespace.

This is equivalent to Clojure's `clojure.string/blank?`.

### Examples

```fol
(blank? nil)                      ; => true
(blank? "")                       ; => true
(blank? "   ")                    ; => true
(blank? "\t\n")                   ; => true
(blank? "hello")                  ; => false
(blank? " hello ")                ; => false
```

---

## trim

```
(trim s)
```

Removes whitespace from both ends of string `s`.

This is equivalent to Clojure's `clojure.string/trim`.

### Examples

```fol
(trim "  hello  ")                ; => "hello"
(trim "\n  hello  \t")            ; => "hello"
(trim "hello")                    ; => "hello"
(trim "")                         ; => ""
```

---

## triml

```
(triml s)
```

Removes whitespace from the left (beginning) of string `s`.

This is equivalent to Clojure's `clojure.string/triml`.

### Examples

```fol
(triml "  hello  ")               ; => "hello  "
(triml "hello")                   ; => "hello"
(triml "   ")                     ; => ""
```

---

## trimr

```
(trimr s)
```

Removes whitespace from the right (end) of string `s`.

This is equivalent to Clojure's `clojure.string/trimr`.

### Examples

```fol
(trimr "  hello  ")               ; => "  hello"
(trimr "hello")                   ; => "hello"
(trimr "   ")                     ; => ""
```

---

## trim-newline

```
(trim-newline s)
```

Removes all trailing newline characters (`\n` and `\r`) from string `s`. Does not remove other whitespace.

This is equivalent to Clojure's `clojure.string/trim-newline`.

### Examples

```fol
(trim-newline "hello\n")          ; => "hello"
(trim-newline "hello\r\n")        ; => "hello"
(trim-newline "hello\n\n\n")      ; => "hello"
(trim-newline "\nhello\n")        ; => "\nhello" (preserves leading)
(trim-newline "hello  ")          ; => "hello  " (preserves spaces)
```

---

## capitalize

```
(capitalize s)
```

Converts the first character of `s` to uppercase and the rest to lowercase.

This is equivalent to Clojure's `clojure.string/capitalize`.

### Examples

```fol
(capitalize "hello")              ; => "Hello"
(capitalize "HELLO")              ; => "Hello"
(capitalize "hELLO wORLD")        ; => "Hello world"
(capitalize "a")                  ; => "A"
(capitalize "")                   ; => ""
```

---

## starts-with?

```
(starts-with? s substr)
```

Returns true if string `s` starts with `substr`.

This is equivalent to Clojure's `clojure.string/starts-with?`.

### Examples

```fol
(starts-with? "hello world" "hello")  ; => true
(starts-with? "hello" "hello")        ; => true
(starts-with? "hello" "h")            ; => true
(starts-with? "hello" "")             ; => true
(starts-with? "hello world" "world")  ; => false
(starts-with? "hello" "Hello")        ; => false (case-sensitive)
(starts-with? "" "a")                 ; => false
```

---

## ends-with?

```
(ends-with? s substr)
```

Returns true if string `s` ends with `substr`.

This is equivalent to Clojure's `clojure.string/ends-with?`.

### Examples

```fol
(ends-with? "hello world" "world")    ; => true
(ends-with? "hello" "hello")          ; => true
(ends-with? "hello" "o")              ; => true
(ends-with? "hello" "")               ; => true
(ends-with? "hello world" "hello")    ; => false
(ends-with? "hello" "Hello")          ; => false (case-sensitive)
(ends-with? "" "a")                   ; => false
```

---

## includes?

```
(includes? s substr)
```

Returns true if string `s` contains `substr`.

This is equivalent to Clojure's `clojure.string/includes?`.

### Examples

```fol
(includes? "hello world" "lo wo")     ; => true
(includes? "hello world" "hello")     ; => true
(includes? "hello world" "world")     ; => true
(includes? "hello" "")                ; => true
(includes? "hello" "foo")             ; => false
(includes? "hello" "Hello")           ; => false (case-sensitive)
(includes? "" "a")                    ; => false
```

---

## Notes

All string functions accept both raw CL strings and wrapped FOL `<string>` objects. They return raw CL strings.

String comparisons are case-sensitive. For case-insensitive operations, consider using regular expressions with the `:case-insensitive` option.

---

## See Also

- [Regular Expression Operations](regex.md) - Pattern matching with `re-find` and `re-seq`
- `str` - String concatenation function
